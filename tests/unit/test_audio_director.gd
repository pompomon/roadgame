extends GutTest
## AudioDirector (plan.md §6, IMPLEMENTATION_PLAN.md M5.3, M5_PLAN.md L15): the buses, the volume
## settings, the engine's pitch, the tunnel's reverb, the area's music and ambient sound, and the
## sounds of a run's events. Each test has its own AudioDirector, which it steps by hand.

const AudioDirectorScript := preload("res://autoload/audio_director.gd")
const Disasters := preload("res://tests/helpers/disaster_fixtures.gd")
const Fixtures := preload("res://tests/helpers/road_fixtures.gd")
const PitchSpy := preload("res://tests/helpers/pitch_spy.gd")
const CITY := preload("res://areas/city.tres")
const RURAL := preload("res://areas/rural.tres")
const DELTA := 1.0 / 60.0
const FADE := Tuning.CROSS_FADE_SECONDS

var _audio: AudioDirectorScript


func before_each() -> void:
	_audio = AudioDirectorScript.new()
	add_child_autofree(_audio)
	_audio.set_process(false)
	_audio.set_physics_process(false)


func after_each() -> void:
	_audio.stop_all()
	# The signals reach the game's AudioDirector too.
	AudioDirector.stop_all()
	SaveService.use_memory()
	_audio.apply_volumes()
	AudioServer.set_bus_effect_enabled(_bus("sfx"), AudioDirectorScript.TUNNEL_REVERB, false)


func _bus(key: String) -> int:
	return AudioServer.get_bus_index(AudioDirectorScript.VOLUME_BUSES[key])


func _sim() -> CarSim:
	var buffer := RoadBuffer.new(RoadGenerator.new(1, Fixtures.schedule()))
	buffer.start()
	return CarSim.new(buffer)


func _reverb_on() -> bool:
	return AudioServer.is_bus_effect_enabled(_bus("sfx"), AudioDirectorScript.TUNNEL_REVERB)


func _playing() -> Array[AudioStreamPlayer]:
	var playing: Array[AudioStreamPlayer] = []
	for player: AudioStreamPlayer in _audio._players():
		if player.playing:
			playing.append(player)
	return playing


func _areas() -> Array[AreaDef]:
	var areas: Array[AreaDef] = []
	for entry: AreaScheduleEntry in Fixtures.schedule().entries:
		if entry.area not in areas:
			areas.append(entry.area)
	return areas


## The loudest sample of the 16-bit WAV file at `path`, from 0 to 1, or -1 if it has no "data"
## chunk. The file's, as the import's compressed data can't be read here.
func _peak(path: String) -> float:
	var bytes := FileAccess.get_file_as_bytes(path)
	var at := 12
	while at + 8 <= bytes.size():
		var size := bytes.decode_u32(at + 4)
		if bytes.slice(at, at + 4).get_string_from_ascii() == "data":
			var top := 0
			for i: int in range(at + 8, mini(at + 8 + size, bytes.size() - 1), 2):
				top = maxi(top, absi(bytes.decode_s16(i)))
			return top / 32768.0
		at += 8 + size + size % 2
	return -1.0


func test_each_volume_has_a_bus_that_sends_to_the_master_bus() -> void:
	assert_eq(AudioDirectorScript.VOLUME_BUSES.keys(), SaveData.VOLUMES)
	for key: String in SaveData.VOLUMES:
		assert_gt(_bus(key), 0, key)
		assert_eq(AudioServer.get_bus_send(_bus(key)), &"Master", key)


func test_the_sfx_bus_has_a_reverb_for_tunnels_that_starts_off() -> void:
	var reverb := AudioServer.get_bus_effect(_bus("sfx"), AudioDirectorScript.TUNNEL_REVERB)
	assert_is(reverb, AudioEffectReverb)
	assert_false(_reverb_on())


## The editor, and a new checkout's first import, save the bus layout because of its reverb. So the
## file must be just what Godot writes, with the uid that they would otherwise write in (L28). The
## header is read here, as ResourceLoader.get_resource_uid() also answers from the import's cache.
func test_the_bus_layout_is_as_the_editor_saves_it() -> void:
	var path := "res://default_bus_layout.tres"
	var copy := "user://bus_layout_test.tres"
	var layout := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	assert_eq(ResourceSaver.save(layout, copy), OK)
	var saved := FileAccess.get_file_as_string(copy)
	DirAccess.remove_absolute(copy)
	var text := FileAccess.get_file_as_string(path)
	var uid := RegEx.create_from_string(' uid="uid://[0-9a-z]+"').search(text.get_slice("\n", 0))
	assert_not_null(uid, "a uid in its header")
	if uid != null:
		assert_eq(text.erase(uid.get_start(), uid.get_string().length()), saved)


func test_each_player_plays_on_the_bus_of_its_volume() -> void:
	for player: AudioStreamPlayer in _audio._music_players:
		assert_eq(player.bus, &"Music")
	for player: AudioStreamPlayer in _audio._ambient_players:
		assert_eq(player.bus, &"Ambient")
	for player: AudioStreamPlayer in _audio._effects + _audio._loop_players.values():
		assert_eq(player.bus, &"SFX")


func test_a_volume_setting_sets_its_bus_and_zero_mutes_it() -> void:
	for key: String in SaveData.VOLUMES:
		SaveService.set_setting(key, 0.5)
		assert_almost_eq(AudioServer.get_bus_volume_linear(_bus(key)), 0.5, 1e-4, key)
		assert_false(AudioServer.is_bus_mute(_bus(key)), key)
		SaveService.set_setting(key, 0.0)
		assert_true(AudioServer.is_bus_mute(_bus(key)), key + " is muted at 0")
		SaveService.set_setting(key, 0.25)
		assert_false(AudioServer.is_bus_mute(_bus(key)), key + " is heard again")
		assert_almost_eq(AudioServer.get_bus_volume_linear(_bus(key)), 0.25, 1e-4, key)


func test_a_run_starts_with_the_saved_volumes() -> void:
	# As a save read from its file sets them: with no settings_changed.
	SaveService.data().settings["sfx"] = 0.4
	SaveService.data().settings["music"] = 0.0
	EventBus.run_started.emit(1)
	assert_almost_eq(AudioServer.get_bus_volume_linear(_bus("sfx")), 0.4, 1e-4)
	assert_true(AudioServer.is_bus_mute(_bus("music")))


func test_the_engines_pitch_rises_with_the_speed_up_to_the_cap() -> void:
	var low := Tuning.ENGINE_PITCH_MIN
	var high := Tuning.ENGINE_PITCH_MAX
	assert_eq(AudioDirectorScript.engine_pitch(0.0), low)
	var half := AudioDirectorScript.engine_pitch(Tuning.GLOBAL_SPEED_CAP / 2.0)
	assert_almost_eq(half, (low + high) / 2.0, 1e-6)
	assert_eq(AudioDirectorScript.engine_pitch(Tuning.GLOBAL_SPEED_CAP), high)
	assert_eq(AudioDirectorScript.engine_pitch(Tuning.GLOBAL_SPEED_CAP * 2.0), high, "no higher")
	assert_eq(AudioDirectorScript.engine_pitch(-1.0), low, "no lower")


func test_the_engine_follows_the_cars_speed() -> void:
	var sim := _sim()
	var engine: AudioStreamPlayer = _audio._loop_players[&"engine"]
	_audio.follow(sim)
	sim.speed = Tuning.GLOBAL_SPEED_CAP
	_audio._physics_process(DELTA)
	assert_almost_eq(engine.pitch_scale, Tuning.ENGINE_PITCH_MAX, 1e-6)
	sim.speed = 0.0
	_audio._physics_process(DELTA)
	assert_almost_eq(engine.pitch_scale, Tuning.ENGINE_PITCH_MIN, 1e-6)


## On the Web, each new round of the engine's loop starts at the sound's own pitch, until the next
## assignment: so one comes every frame, also when the speed stays the same (L27).
func test_the_engines_pitch_is_set_every_frame() -> void:
	var engine: AudioStreamPlayer = _audio._loop_players[&"engine"]
	engine.set_script(PitchSpy)
	_audio.follow(_sim())
	for frame: int in 3:
		_audio._physics_process(DELTA)
	assert_eq(engine.get(&"pitch_sets"), 3)
	assert_almost_eq(engine.pitch_scale, Tuning.ENGINE_PITCH_MIN, 1e-6, "and passes them on")


func test_the_sfx_reverb_is_on_while_the_car_is_in_a_tunnel() -> void:
	var sim := _sim()
	_audio.follow(sim)
	_audio._physics_process(DELTA)
	assert_false(_reverb_on(), "not on a plain road")
	var tile := sim.buffer.tile_at(Vector2i(sim.pos.floor()))
	tile.set_piece = &"tunnel"
	_audio._physics_process(DELTA)
	assert_true(_reverb_on(), "in a tunnel")
	tile.set_piece = &""
	_audio._physics_process(DELTA)
	assert_false(_reverb_on(), "out of it")
	tile.set_piece = &"tunnel"
	_audio._physics_process(DELTA)
	_audio.follow(null)
	assert_false(_reverb_on(), "off once the car is gone")


func test_the_engine_runs_from_a_runs_start_to_its_end() -> void:
	EventBus.run_started.emit(1)
	assert_true(_audio.is_loop_on(&"engine"))
	assert_false(_audio.is_loop_on(&"rumble"))
	EventBus.run_ended.emit(CarSim.WRONG_TURN, {})
	assert_false(_audio.is_loop_on(&"engine"))


func test_leaving_the_road_screeches_and_rumbles_until_the_car_is_back() -> void:
	watch_signals(_audio)
	EventBus.run_started.emit(1)
	EventBus.car_offroad_changed.emit(true)
	assert_signal_emitted_with_parameters(_audio, "effect_played", [&"screech"])
	assert_true(_audio.is_loop_on(&"rumble"))
	EventBus.car_offroad_changed.emit(false)
	assert_false(_audio.is_loop_on(&"rumble"))
	assert_signal_emit_count(_audio, "effect_played", 1, "no screech back on the road")


func test_a_sound_never_plays_twice_at_once() -> void:
	# Its copies would add up past full scale (M5_PLAN.md L29): when the car crosses the road's
	# edge again and again, the screech starts over.
	_audio.can_play = true
	EventBus.run_started.emit(1)
	for k: int in AudioDirectorScript.EFFECT_PLAYERS + 1:
		EventBus.car_offroad_changed.emit(true)
		EventBus.car_offroad_changed.emit(false)
	EventBus.turn_completed.emit(0)
	var streams: Array[AudioStream] = []
	for player: AudioStreamPlayer in _playing():
		streams.append(player.stream)
	assert_eq(streams.count(AudioDirectorScript.EFFECTS[&"screech"]), 1, "one screech")
	assert_eq(streams.count(AudioDirectorScript.EFFECTS[&"junction"]), 1, "beside another sound")
	_audio.stop_all()
	# The audio server must let go of each sound before the tests end, or it leaks (L15).
	await wait_seconds(0.25)


func test_when_the_car_is_gone_its_sounds_stop() -> void:
	_audio.follow(_sim())
	EventBus.run_started.emit(1)
	EventBus.car_offroad_changed.emit(true)
	_audio.follow(null)
	assert_false(_audio.is_loop_on(&"engine"))
	assert_false(_audio.is_loop_on(&"rumble"))


func test_each_turn_made_chimes() -> void:
	watch_signals(_audio)
	EventBus.turn_completed.emit(0)
	assert_signal_emitted_with_parameters(_audio, "effect_played", [&"junction"])


func test_each_turn_of_the_tutorials_streak_chimes_and_a_mistake_is_silent() -> void:
	watch_signals(_audio)
	EventBus.streak_changed.emit(1)
	assert_signal_emitted_with_parameters(_audio, "effect_played", [&"junction"])
	EventBus.streak_changed.emit(0)
	assert_signal_emit_count(_audio, "effect_played", 1, "the streak ended")


func test_damage_thumps_each_time_the_health_falls_past_a_step() -> void:
	watch_signals(_audio)
	EventBus.run_started.emit(1)
	var health := Tuning.START_HEALTH
	while health > 0.0:
		health -= 1.0
		EventBus.health_changed.emit(health)
	var steps := roundi(Tuning.START_HEALTH / Tuning.DAMAGE_SOUND_STEP)
	assert_signal_emit_count(_audio, "effect_played", steps, "one per step")
	assert_signal_emitted_with_parameters(_audio, "effect_played", [&"damage"])
	EventBus.run_started.emit(2)
	EventBus.health_changed.emit(Tuning.START_HEALTH - Tuning.DAMAGE_SOUND_STEP / 2.0)
	assert_signal_emit_count(_audio, "effect_played", steps, "the next run starts at full health")


func test_a_crash_sounds_only_when_the_car_is_wrecked_or_lost_off_the_road() -> void:
	watch_signals(_audio)
	for cause: StringName in [CarSim.WRONG_TURN, CarSim.MISSED_TURN]:
		EventBus.run_ended.emit(cause, {})
	assert_signal_not_emitted(_audio, "effect_played", "a disaster has its own sound")
	for cause: StringName in [CarSim.HEALTH, CarSim.OFFROAD]:
		EventBus.run_ended.emit(cause, {})
	assert_signal_emit_count(_audio, "effect_played", 2)
	assert_signal_emitted_with_parameters(_audio, "effect_played", [&"crash"])


func test_every_disaster_of_every_area_has_its_sound() -> void:
	var ids := _disaster_ids()
	assert_eq(ids.size(), Disasters.scenes().size(), "each disaster of the pools has its own id")
	watch_signals(_audio)
	for id: StringName in ids:
		assert_has(AudioDirectorScript.EFFECTS, id)
		EventBus.disaster_appeared.emit(id, CITY)
		assert_signal_emitted_with_parameters(_audio, "effect_played", [id])


func test_a_disaster_sounds_as_it_shows_not_as_it_starts_to_play() -> void:
	# Its delay may be up to DISASTER_DELAY_MAX (M6_PLAN.md S18).
	watch_signals(_audio)
	for id: StringName in _disaster_ids():
		EventBus.disaster_started.emit(id, CITY)
	assert_signal_not_emitted(_audio, "effect_played")


## The ids of the disasters of every area's pool, once each.
func _disaster_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for area: AreaDef in _areas():
		for scene: PackedScene in area.disasters:
			var disaster: DisasterBase = scene.instantiate()
			if disaster.id not in ids:
				ids.append(disaster.id)
			disaster.free()
	return ids


func test_an_unknown_sound_is_an_error() -> void:
	watch_signals(_audio)
	_audio.play_effect(&"kazoo")
	assert_push_error("no sound for kazoo")
	assert_signal_not_emitted(_audio, "effect_played")


func test_every_area_has_its_own_music_and_ambient_loop() -> void:
	var tracks: Array[AudioStream] = []
	for area: AreaDef in _areas():
		for track: AudioStream in [area.music, area.ambient_loop]:
			assert_is(track, AudioStreamWAV, area.id)
			if track is AudioStreamWAV:
				var wav: AudioStreamWAV = track
				assert_eq(wav.loop_mode, AudioStreamWAV.LOOP_FORWARD, track.resource_path)
				assert_gt(wav.loop_end, wav.loop_begin, track.resource_path)
			assert_does_not_have(tracks, track, track.resource_path if track != null else "")
			tracks.append(track)
	assert_eq(tracks.size(), 10)


func test_the_loops_loop_and_the_one_shot_sounds_do_not() -> void:
	for id: StringName in AudioDirectorScript.LOOPS:
		var wav: AudioStreamWAV = AudioDirectorScript.LOOPS[id]
		assert_eq(wav.loop_mode, AudioStreamWAV.LOOP_FORWARD, id)
	for id: StringName in AudioDirectorScript.EFFECTS:
		var wav: AudioStreamWAV = AudioDirectorScript.EFFECTS[id]
		assert_eq(wav.loop_mode, AudioStreamWAV.LOOP_DISABLED, id)


## Godot clamps the mix at full scale, so each kind of sound has a budget that leaves the others
## room (L29). A sound that replaces one (Q1) must keep to it too.
func test_no_sound_peaks_above_its_kinds_budget() -> void:
	var budgets: Dictionary[String, float] = {}
	for area: AreaDef in _areas():
		budgets[area.music.resource_path] = Tuning.MUSIC_PEAK
		budgets[area.ambient_loop.resource_path] = Tuning.AMBIENT_PEAK
	for id: StringName in AudioDirectorScript.LOOPS:
		budgets[AudioDirectorScript.LOOPS[id].resource_path] = Tuning.LOOP_PEAK
	for id: StringName in AudioDirectorScript.EFFECTS:
		budgets[AudioDirectorScript.EFFECTS[id].resource_path] = Tuning.EFFECT_PEAK
	var files := 2 * _areas().size() + AudioDirectorScript.LOOPS.size()
	files += AudioDirectorScript.EFFECTS.size()
	assert_eq(
		budgets.size(), files, "each area's music and ambient loop, the loops and the effects"
	)
	for path: String in budgets:
		assert_between(_peak(path), 0.0, budgets[path], path)


func test_an_area_change_cross_fades_its_music_and_ambient_sound() -> void:
	EventBus.area_changed.emit(CITY)
	assert_eq(_audio.tracks(), [CITY.music, CITY.ambient_loop] as Array[AudioStream])
	_audio.advance(FADE)
	var city: Array[AudioStreamPlayer] = []
	for players: Array[AudioStreamPlayer] in [_audio._music_players, _audio._ambient_players]:
		for player: AudioStreamPlayer in players:
			if player.stream in [CITY.music, CITY.ambient_loop]:
				city.append(player)
				assert_almost_eq(player.volume_linear, 1.0, 1e-4)
	assert_eq(city.size(), 2)
	EventBus.area_changed.emit(RURAL)
	assert_eq(_audio.tracks(), [RURAL.music, RURAL.ambient_loop] as Array[AudioStream])
	_audio.advance(FADE / 2.0)
	for player: AudioStreamPlayer in city:
		assert_almost_eq(player.volume_linear, CrossFade.gain(0.5), 1e-4, "half way")


func test_a_deck_stops_once_it_has_faded_out() -> void:
	_audio.can_play = true
	EventBus.area_changed.emit(CITY)
	_audio.advance(FADE)
	assert_eq(_playing().size(), 2, "the City's music and ambient sound")
	EventBus.area_changed.emit(RURAL)
	_audio.advance(FADE / 2.0)
	assert_eq(_playing().size(), 4, "both areas', mid-fade")
	_audio.advance(FADE / 2.0)
	assert_eq(_playing().size(), 2, "the Rural's only")
	_audio.stop_all()
	assert_eq(_playing().size(), 0)
	# The audio server must let go of each sound before the tests end, or it leaks (L15).
	await wait_seconds(0.25)


## Copilot's review of #41: an area with no sound, mid-fade, cut the quieter area's at once.
func test_an_area_with_no_sound_mid_fade_fades_both_areas_out() -> void:
	var quiet := RURAL.duplicate() as AreaDef
	quiet.music = null
	quiet.ambient_loop = null
	_audio.can_play = true
	EventBus.area_changed.emit(CITY)
	_audio.advance(FADE)
	EventBus.area_changed.emit(RURAL)
	_audio.advance(FADE / 4.0)
	EventBus.area_changed.emit(quiet)
	assert_eq(_audio.tracks(), [null, null] as Array[AudioStream], "nothing fades in")
	_audio.advance(DELTA)
	assert_eq(_playing().size(), 4, "both areas' fade out")
	_audio.advance(FADE / 4.0)
	assert_eq(_playing().size(), 2, "the City's, which was louder, only")
	_audio.advance(FADE / 2.0)
	assert_eq(_playing().size(), 0)
	# The audio server must let go of each sound before the tests end, or it leaks (L15).
	await wait_seconds(0.25)


func test_nothing_plays_unless_it_can() -> void:
	_audio.can_play = false
	EventBus.run_started.emit(1)
	EventBus.area_changed.emit(CITY)
	_audio.play_effect(&"crash")
	assert_eq(_playing().size(), 0)


func test_music_and_ambient_sound_go_on_while_paused_but_the_cars_sounds_pause() -> void:
	var decks: Array = _audio._music_players + _audio._ambient_players
	var car: Array = _audio._effects + _audio._loop_players.values()
	get_tree().paused = true
	var going := decks.filter(func(player: Node) -> bool: return player.can_process())
	var paused := car.filter(func(player: Node) -> bool: return not player.can_process())
	get_tree().paused = false
	assert_eq(going.size(), 4)
	assert_eq(paused.size(), AudioDirectorScript.EFFECT_PLAYERS + 2)
