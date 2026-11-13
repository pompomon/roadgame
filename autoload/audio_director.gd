extends Node
## The game's sound (plan.md §6, IMPLEMENTATION_PLAN.md M5.3): each area's music and ambient loop,
## cross-faded on EventBus.area_changed; the engine, whose pitch follows the car's speed; and the
## sounds of the run's events. Buses (default_bus_layout.tres): Master → Music, SFX, Ambient. The
## SFX bus's reverb is on while the car is in a tunnel. The volumes are the settings' (M5.4): they
## apply when a run starts and when they change, never in _ready(), which mustn't read the save
## (M5_PLAN.md L1). Music and ambient sound go on while the game is paused; the car's sounds pause.

## A one-shot sound started, or would have if can_play were on.
signal effect_played(id: StringName)

## The bus of each volume setting (SaveData.VOLUMES).
const VOLUME_BUSES: Dictionary[String, StringName] = {
	"music": &"Music",
	"sfx": &"SFX",
	"ambient": &"Ambient",
}
## The SFX bus's effect that is on in a tunnel (default_bus_layout.tres).
const TUNNEL_REVERB := 0
## One-shot sounds play on this many players, so that a few different ones can overlap.
const EFFECT_PLAYERS := 4
## Loops on the SFX bus, which play while their condition holds.
const LOOPS: Dictionary[StringName, AudioStream] = {
	&"engine": preload("res://assets/audio/sfx/engine.wav"),
	&"rumble": preload("res://assets/audio/sfx/rumble.wav"),
}
## One-shot sounds (plan.md §6), and each disaster's by its id (DisasterBase.id).
const EFFECTS: Dictionary[StringName, AudioStream] = {
	&"screech": preload("res://assets/audio/sfx/screech.wav"),
	&"damage": preload("res://assets/audio/sfx/damage.wav"),
	&"crash": preload("res://assets/audio/sfx/crash.wav"),
	&"junction": preload("res://assets/audio/sfx/junction.wav"),
	# The City's legends.
	&"phantom_bus": preload("res://assets/audio/sfx/phantom_bus.wav"),
	# Rural's legends.
	&"ufo": preload("res://assets/audio/sfx/ufo.wav"),
	# The Meadows' legends.
	&"fairy_ring": preload("res://assets/audio/sfx/fairy_ring.wav"),
	# The Village's legends.
	&"witch_hex": preload("res://assets/audio/sfx/witch_hex.wav"),
	# The Desert's legends.
	&"death_worm": preload("res://assets/audio/sfx/death_worm.wav"),
}

## Off on the Dummy driver, which headless runs use (the tests and smoke.sh): a sound that still
## plays when the game quits leaks (M5_PLAN.md L15). Everything else works as it would. A test may
## turn it on, and must then call stop_all() and wait 0.25 s before the run ends.
var can_play := AudioServer.get_driver_name() != "Dummy"

var _music := CrossFade.new(Tuning.CROSS_FADE_SECONDS)
var _ambient := CrossFade.new(Tuning.CROSS_FADE_SECONDS)
var _music_players: Array[AudioStreamPlayer] = []
var _ambient_players: Array[AudioStreamPlayer] = []
var _loop_players: Dictionary[StringName, AudioStreamPlayer] = {}
var _loops_on: Dictionary[StringName, bool] = {}
var _effects: Array[AudioStreamPlayer] = []
var _next_effect := 0
var _sim: CarSim
var _health := Tuning.START_HEALTH


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for deck: int in 2:
		_music_players.append(_add_player(VOLUME_BUSES["music"], PROCESS_MODE_INHERIT))
		_ambient_players.append(_add_player(VOLUME_BUSES["ambient"], PROCESS_MODE_INHERIT))
	for id: StringName in LOOPS:
		_loop_players[id] = _add_player(VOLUME_BUSES["sfx"], PROCESS_MODE_PAUSABLE)
		_loop_players[id].stream = LOOPS[id]
		_loops_on[id] = false
	for k: int in EFFECT_PLAYERS:
		_effects.append(_add_player(VOLUME_BUSES["sfx"], PROCESS_MODE_PAUSABLE))
	EventBus.run_started.connect(_on_run_started)
	EventBus.area_changed.connect(_on_area_changed)
	EventBus.turn_completed.connect(_on_turn_completed)
	EventBus.streak_changed.connect(_on_streak_changed)
	EventBus.car_offroad_changed.connect(_on_offroad_changed)
	EventBus.health_changed.connect(_on_health_changed)
	EventBus.run_ended.connect(_on_run_ended)
	EventBus.disaster_appeared.connect(_on_disaster_appeared)
	SaveService.settings_changed.connect(_on_settings_changed)


func _process(delta: float) -> void:
	advance(delta)


func _physics_process(_delta: float) -> void:
	if _sim == null:
		return
	# Every frame, also when it's the same: on the Web, each new round of a loop starts at the
	# sound's own pitch until the next assignment (M5_PLAN.md L27).
	_loop_players[&"engine"].pitch_scale = engine_pitch(_sim.speed)
	var tile := _sim.buffer.tile_at(Vector2i(_sim.pos.floor()))
	_set_reverb(tile != null and tile.set_piece == &"tunnel")


## The engine's pitch at `speed` tiles/s (IMPLEMENTATION_PLAN.md M5.3).
static func engine_pitch(speed: float) -> float:
	var t := clampf(speed / Tuning.GLOBAL_SPEED_CAP, 0.0, 1.0)
	return lerpf(Tuning.ENGINE_PITCH_MIN, Tuning.ENGINE_PITCH_MAX, t)


## Follows `sim`: the engine's pitch and the tunnel's reverb. The main scene gives it each run's
## car, and null when it leaves. The last run's car stays followed behind the title screen, as its
## road stays shown, until the next run's replaces it.
func follow(sim: CarSim) -> void:
	_sim = sim
	if sim == null:
		for id: StringName in LOOPS:
			set_loop(id, false)
		_set_reverb(false)


## Moves the cross-fades on by `delta` seconds, and stops a deck once it is silent.
func advance(delta: float) -> void:
	_advance(_music, _music_players, delta)
	_advance(_ambient, _ambient_players, delta)


## Applies the volume settings to the buses. Muted at 0, as linear_to_db(0) is -inf.
func apply_volumes() -> void:
	for key: String in VOLUME_BUSES:
		_apply_volume(key)


func set_loop(id: StringName, on: bool) -> void:
	_loops_on[id] = on
	if not on:
		_loop_players[id].stop()
	elif not _loop_players[id].playing:
		_start(_loop_players[id])


func is_loop_on(id: StringName) -> bool:
	return _loops_on.get(id, false)


## Plays the one-shot sound `id` (EFFECTS). A sound plays on one player at a time: copies of it
## would add up past full scale (M5_PLAN.md L29), as when the car crosses the road's edge again
## and again. So it starts over on the player that last played it, if no other sound has taken
## that one since; if not, it goes on the next of EFFECT_PLAYERS players, which stops whatever that
## one still played.
func play_effect(id: StringName) -> void:
	var stream: AudioStream = EFFECTS.get(id)
	if stream == null:
		push_error("AudioDirector: no sound for %s" % id)
		return
	var player := _effect_player(stream)
	player.stream = stream
	_start(player)
	effect_played.emit(id)


## The track each cross-fade plays or fades in: [music, ambient].
func tracks() -> Array[AudioStream]:
	return [_music.current_track(), _ambient.current_track()]


## Stops every sound at once, and forgets the area's tracks.
func stop_all() -> void:
	for fade: CrossFade in [_music, _ambient]:
		fade.stop()
	for player: AudioStreamPlayer in _players():
		player.stop()
	for id: StringName in LOOPS:
		_loops_on[id] = false


func _add_player(bus: StringName, mode: ProcessMode) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = bus
	player.process_mode = mode
	add_child(player)
	return player


func _players() -> Array[AudioStreamPlayer]:
	var all: Array[AudioStreamPlayer] = []
	all.append_array(_music_players)
	all.append_array(_ambient_players)
	all.append_array(_loop_players.values())
	all.append_array(_effects)
	return all


## The effect player that last played `stream`, or else the next one.
func _effect_player(stream: AudioStream) -> AudioStreamPlayer:
	for player: AudioStreamPlayer in _effects:
		if player.stream == stream:
			return player
	var next := _effects[_next_effect]
	_next_effect = (_next_effect + 1) % _effects.size()
	return next


func _start(player: AudioStreamPlayer) -> void:
	if can_play and player.stream != null:
		player.play()


func _fade(fade: CrossFade, players: Array[AudioStreamPlayer], track: AudioStream) -> void:
	var deck := fade.fade_to(track)
	if deck >= 0:
		players[deck].stream = track
		players[deck].volume_linear = 0.0
		_start(players[deck])


## Sets each deck's gain only when its weight moved: on the Web, each change is a call into the
## browser's audio.
func _advance(fade: CrossFade, players: Array[AudioStreamPlayer], delta: float) -> void:
	var before := fade.weights.duplicate()
	fade.advance(delta)
	for deck: int in 2:
		if fade.weights[deck] != before[deck]:
			players[deck].volume_linear = CrossFade.gain(fade.weights[deck])
		if fade.tracks[deck] == null and players[deck].playing:
			players[deck].stop()


func _apply_volume(key: String) -> void:
	var bus := AudioServer.get_bus_index(VOLUME_BUSES[key])
	var volume: float = SaveService.setting(key)
	AudioServer.set_bus_mute(bus, volume <= 0.0)
	if volume > 0.0:
		AudioServer.set_bus_volume_linear(bus, volume)


func _set_reverb(on: bool) -> void:
	var bus := AudioServer.get_bus_index(VOLUME_BUSES["sfx"])
	if AudioServer.is_bus_effect_enabled(bus, TUNNEL_REVERB) != on:
		AudioServer.set_bus_effect_enabled(bus, TUNNEL_REVERB, on)


func _on_run_started(_run_seed: int) -> void:
	apply_volumes()
	_health = Tuning.START_HEALTH
	set_loop(&"engine", true)
	set_loop(&"rumble", false)


func _on_area_changed(area: AreaDef) -> void:
	_fade(_music, _music_players, area.music)
	_fade(_ambient, _ambient_players, area.ambient_loop)


func _on_turn_completed(_turn_index: int) -> void:
	play_effect(&"junction")


## A correct turn in the tutorial chimes as one does after it. A mistake, which ends the streak, has
## no sound of its own (TUTORIAL_PLAN.md Q11).
func _on_streak_changed(streak: int) -> void:
	if streak > 0:
		play_effect(&"junction")


func _on_offroad_changed(is_offroad: bool) -> void:
	if is_offroad:
		play_effect(&"screech")
	set_loop(&"rumble", is_offroad)


## A thump each time the health falls past a multiple of DAMAGE_SOUND_STEP.
func _on_health_changed(value: float) -> void:
	if ceili(value / Tuning.DAMAGE_SOUND_STEP) < ceili(_health / Tuning.DAMAGE_SOUND_STEP):
		play_effect(&"damage")
	_health = value


func _on_run_ended(cause: StringName, _stats: Dictionary) -> void:
	for id: StringName in LOOPS:
		set_loop(id, false)
	if cause in [CarSim.HEALTH, CarSim.OFFROAD]:
		play_effect(&"crash")


## A disaster's sound starts as it shows, with its first beat, not as it starts to play: its delay
## may be up to DISASTER_DELAY_MAX (M6_PLAN.md S18).
func _on_disaster_appeared(id: StringName, _area: AreaDef) -> void:
	play_effect(id)


func _on_settings_changed(key: String) -> void:
	if VOLUME_BUSES.has(key):
		_apply_volume(key)
