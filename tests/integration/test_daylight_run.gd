extends GutTest
## Day and night in the game (DAYNIGHT_PLAN.md §5.4–§5.9): each run starts in the morning at once;
## each zone starts its clock again, runs it at its own pace, and the light catches up no faster
## than the rate; the clock runs only with the run; --hour= sets the hour that zones start at; a
## disaster plays in the light that the run ended in; the night's veil darkens the world but not
## the glows or the UI; and the light changes nothing but the view.

const MainScene := preload("res://tests/helpers/main_scene.gd")
const Disasters := preload("res://tests/helpers/disaster_fixtures.gd")
const RUNNING := GameState.State.RUNNING
const DISASTER := GameState.State.DISASTER
const GAME_OVER := GameState.State.GAME_OVER


func after_each() -> void:
	GameState.quit_to_title()
	AudioDirector.stop_all()


static func _daylight(main: Node) -> Daylight:
	return main.get_node("%Daylight")


## Sets the clock of `main`'s zone to `hour`, with the light of that hour shown at once. A clock
## that no zone has started stands at the start hour, so this checks that it moved (N26).
func _set_hour(main: Node, hour: float) -> void:
	var daylight := _daylight(main)
	var cycle := daylight.cycle
	cycle.seconds = fposmod(hour - cycle.start_hour, 24.0) / 24.0 * cycle.day_seconds
	cycle.snap()
	daylight.refresh()
	assert_almost_eq(cycle.hour(), hour, 1e-9, "the zone's clock is at %.1f" % hour)


## The largest change in a channel from `a` to `b`.
static func _change(a: Color, b: Color) -> float:
	return maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b)))


func _assert_morning(main: Node, when: String) -> void:
	var daylight := _daylight(main)
	assert_eq(daylight.cycle.hour(), Tuning.DAY_START_HOUR, when + ": the hour")
	assert_eq(daylight.cycle.light, Color.WHITE, when + ": the light")
	assert_eq(daylight.modulate.a, 0.0, when + ": the veil hides")


## Steps `main` for `frames` frames, and asserts that neither the hour nor the light changed.
func _assert_still(main: Node, frames: int, when: String) -> void:
	var cycle := _daylight(main).cycle
	var hour := cycle.hour()
	var light := cycle.light
	simulate(main, frames, MainScene.DELTA)
	assert_eq(cycle.hour(), hour, when + ": the hour")
	assert_eq(cycle.light, light, when + ": the light")


func test_each_run_starts_at_once_in_the_morning() -> void:
	# A new run is a cut, also after a night (N27, N28).
	var main := MainScene.open(self, ["--seed=1"])
	_assert_morning(main, "the first run")
	MainScene.run_while(self, main, RUNNING, 3600)
	_set_hour(main, 22.0)
	MainScene.run_while(self, main, DISASTER, 600)
	assert_eq(GameState.state, GAME_OVER)
	assert_eq(_daylight(main).cycle.light, Tuning.LIGHT_NIGHT, "game over at night")
	assert_eq(_daylight(main).modulate.a, 1.0, "under the night's veil")
	MainScene.press_key(main, KEY_ENTER)
	assert_eq(GameState.state, RUNNING, "retried")
	_assert_morning(main, "the retry")


func test_the_light_follows_the_clock_while_the_car_drives() -> void:
	# From 17:00, 600 frames are 10 s of the City's 120 s day: two hours, into the dusk (N24).
	var main := MainScene.open(self, ["--seed=1", "--autopilot", "--hour=17"])
	var daylight := _daylight(main)
	var camera: CameraRig = main.get_node("%Camera")
	simulate(main, 600, MainScene.DELTA)
	assert_eq(GameState.state, RUNNING)
	assert_eq(GameState.area_id, &"city", "still in the first zone")
	var cycle := daylight.cycle
	var step := 24.0 * MainScene.DELTA / cycle.day_seconds
	assert_almost_eq(cycle.hour(), 19.0, step, "the hour")
	assert_eq(cycle.light, DayCycle.light_at(cycle.hour()), "the light of the hour")
	assert_eq(Disasters.veil_tint(daylight), cycle.light, "shown")
	var centre := camera.global_position + camera.offset
	assert_almost_eq(daylight.global_position.distance_to(centre), 0.0, 1e-3, "on the view")


func test_each_new_zone_starts_its_clock_again() -> void:
	# At 22:00 the car reaches Rural, as test_area_start.gd sends it: its clock starts at 07:00,
	# and the light catches up with the morning's at the rate, without a jump (N26).
	var main := MainScene.open(self, ["--seed=1", "--autopilot"])
	var daylight := _daylight(main)
	_set_hour(main, 22.0)
	var night := daylight.cycle.light
	var sim := MainScene.car(main).sim
	sim.area_changed.emit(sim.buffer.generator.find_area(&"rural"))
	assert_eq(daylight.cycle.hour(), Tuning.DAY_START_HOUR, "the zone's clock starts")
	assert_eq(daylight.cycle.light, night, "the light doesn't jump")
	var fastest := 0.0
	var frames := 0
	var was := night
	while daylight.cycle.light != Color.WHITE and frames < 600:
		simulate(main, 1, MainScene.DELTA)
		frames += 1
		fastest = maxf(fastest, _change(was, daylight.cycle.light))
		was = daylight.cycle.light
	assert_eq(GameState.state, RUNNING)
	assert_lte(fastest, Tuning.LIGHT_MAX_RATE * MainScene.DELTA + 1e-6, "no faster than the rate")
	assert_lte(frames * MainScene.DELTA, 2.4, "seconds to the morning's light")
	assert_eq(Disasters.veil_tint(daylight), Color.WHITE, "the veil hides")


func test_each_zone_runs_its_clock_at_its_own_pace() -> void:
	# Every zone's day lasts 120 s for now, so the car enters one of 60 s here. From 17:00, 600
	# frames are 10 s of it: four hours, into the night, where 120 s would give two (N39).
	var main := MainScene.open(self, ["--seed=1", "--autopilot", "--hour=17"])
	var sim := MainScene.car(main).sim
	var quick := sim.buffer.generator.find_area(&"rural").duplicate() as AreaDef
	quick.day_seconds = 60.0
	sim.area_changed.emit(quick)
	var cycle := _daylight(main).cycle
	assert_eq(cycle.day_seconds, 60.0, "the zone's day")
	simulate(main, 600, MainScene.DELTA)
	assert_eq(GameState.state, RUNNING)
	assert_almost_eq(cycle.hour(), 21.0, 24.0 * MainScene.DELTA / 60.0, "the hour")
	assert_eq(cycle.light, Tuning.LIGHT_NIGHT, "the night's light")


func test_the_clock_stops_when_the_run_ends_and_while_paused() -> void:
	# simulate() steps a paused tree too, so here only the state can stop the clock (N25). The
	# engine doesn't step a paused tree: real frames.
	var main := MainScene.open(self, ["--seed=1", "--hour=19"])
	simulate(main, 60, MainScene.DELTA)
	GameState.pause()
	var cycle := _daylight(main).cycle
	var hour := cycle.hour()
	for _frame: int in 30:
		await get_tree().physics_frame
	assert_eq(cycle.hour(), hour, "paused")
	GameState.resume()
	MainScene.run_while(self, main, RUNNING, 3600)
	assert_eq(GameState.state, DISASTER)
	_assert_still(main, 60, "in the disaster")
	MainScene.run_while(self, main, DISASTER, 600)
	assert_eq(GameState.state, GAME_OVER)
	_assert_still(main, 120, "game over")


func test_the_hour_argument_starts_every_zone_at_that_hour() -> void:
	# Any finite hour, round the clock; anything else is an error, and zones start at 07:00 (N30,
	# N31).
	var hours: Dictionary[String, float] = {
		"--hour=22": 22.0, "--hour=26": 2.0, "--hour=-1.5": 22.5
	}
	for arg: String in hours:
		var main := MainScene.open(self, ["--seed=1", "--autopilot", arg])
		var cycle := _daylight(main).cycle
		assert_eq(cycle.hour(), hours[arg], arg)
		assert_eq(cycle.light, DayCycle.light_at(hours[arg]), arg + ": its light at once")
		simulate(main, 60, MainScene.DELTA)
		var sim := MainScene.car(main).sim
		sim.area_changed.emit(sim.buffer.generator.find_area(&"rural"))
		assert_eq(cycle.hour(), hours[arg], arg + ": and a new zone")
		main.get_parent().free()
	for arg: String in ["--hour=noon", "--hour=", "--hour=1e999"]:
		var main := MainScene.open(self, ["--seed=1", arg])
		assert_push_error("--hour= needs an hour", arg)
		if arg == "--hour=1e999":
			assert_engine_error("Exponent too high", "Godot's own parser says so too")
		_assert_morning(main, arg)
		main.get_parent().free()


func test_at_night_the_disaster_plays_in_the_light_the_run_ended_in() -> void:
	# The clock stops with the run, and the director gives the disaster its light (§5.6, N29).
	var main := MainScene.open(self, ["--seed=1", "--hour=22"])
	var director: DisasterDirector = main.get_node("%Director")
	MainScene.run_while(self, main, RUNNING, 3600)
	assert_eq(GameState.state, DISASTER)
	var light := _daylight(main).cycle.light
	assert_ne(light, Color.WHITE, "at night")
	var frames := 0
	while director.disaster == null and frames < 600:
		simulate(main, 1, MainScene.DELTA)
		frames += 1
	assert_not_null(director.disaster, "a disaster plays")
	assert_eq(director.disaster.ambient, light, "in the light that the run ended in")


func test_the_light_changes_nothing_but_the_view() -> void:
	# The same run by day and by night: the road, the car and the run end the same, with the same
	# sounds played, and the sound is the same on every frame (§5.1, N33, N40–N43). simulate()
	# steps only the main scene, so AudioDirector is stepped with it, first, as the engine steps
	# autoloads. Each run starts in silence, and the first is freed before the second opens.
	watch_signals(AudioDirector)
	var ends: Array[Dictionary] = []
	var sounds: Array[Array] = []
	for hour: String in ["--hour=7", "--hour=19"]:
		AudioDirector.stop_all()
		var before: int = get_signal_emit_count(AudioDirector, "effect_played")
		var main := MainScene.open(self, ["--seed=1", "--autopilot", hour])
		var frames: Array[Array] = []
		for _frame: int in 1200:
			AudioDirector._physics_process(MainScene.DELTA)
			simulate(main, 1, MainScene.DELTA)
			AudioDirector.advance(MainScene.DELTA)
			var sound := _sound()
			sound.append(get_signal_emit_count(AudioDirector, "effect_played") - before)
			frames.append(sound)
		var heard: Array[StringName] = []
		for k: int in range(before, get_signal_emit_count(AudioDirector, "effect_played")):
			heard.append(get_signal_parameters(AudioDirector, "effect_played", k)[0])
		var sim := MainScene.car(main).sim
		var end := {
			"tile": sim.buffer.path_tile(sim.buffer.car_index()).path_index,
			"turns": GameState.turn_index,
			"distance": GameState.distance,
			"health": sim.health,
			"area": GameState.area_id,
			"state": GameState.state,
			"heard": heard,
		}
		ends.append(end)
		sounds.append(frames)
		main.get_parent().free()
	assert_ne(ends[0]["area"], &"", "a run")
	assert_gt((ends[0]["heard"] as Array).size(), 0, "with sounds")
	assert_eq(ends[1], ends[0])
	var same := 0
	while same < sounds[0].size() and sounds[1][same] == sounds[0][same]:
		same += 1
	assert_eq(same, sounds[0].size(), "the frames that sound the same")
	if same < sounds[0].size():
		assert_eq(sounds[1][same], sounds[0][same], "the first that doesn't")


## What AudioDirector plays, the one node with players: each bus's volume, mute, solo, bypass and
## effects; each cross-fade's tracks, weights and deck; the loops that are on; and each player's
## bus, pitch and whether it plays, with its gain and stream. Not those that AudioDirector leaves
## from the last run until it uses the player again: a deck's with no track, and an effect
## player's stream, as the effects played are counted. On the Dummy driver none plays
## (AudioDirector.can_play).
static func _sound() -> Array:
	var sound := []
	for bus: int in AudioServer.bus_count:
		sound.append(AudioServer.get_bus_volume_db(bus))
		sound.append(AudioServer.is_bus_mute(bus))
		sound.append(AudioServer.is_bus_solo(bus))
		sound.append(AudioServer.is_bus_bypassing_effects(bus))
		for effect: int in AudioServer.get_bus_effect_count(bus):
			sound.append(AudioServer.is_bus_effect_enabled(bus, effect))
	var fades: Array[CrossFade] = [AudioDirector._music, AudioDirector._ambient]
	var decks: Array[Array] = [AudioDirector._music_players, AudioDirector._ambient_players]
	for f: int in fades.size():
		var fade := fades[f]
		sound.append_array([fade.tracks.duplicate(), fade.weights.duplicate(), fade.current])
		for deck: int in 2:
			var used := fade.tracks[deck] != null
			sound.append_array(_player(decks[f][deck], used, used))
	for id: StringName in AudioDirector.LOOPS:
		sound.append(AudioDirector.is_loop_on(id))
		sound.append_array(_player(AudioDirector._loop_players[id], true, true))
	for player: AudioStreamPlayer in AudioDirector._effects:
		sound.append_array(_player(player, true, false))
	return sound


## `player`'s bus, pitch and whether it plays, and its gain and stream if asked.
static func _player(player: AudioStreamPlayer, gain: bool, stream: bool) -> Array:
	var state: Array = [player.bus, player.pitch_scale, player.playing]
	if gain:
		state.append(player.volume_db)
	if stream:
		state.append(player.stream)
	return state


func test_the_veil_darkens_the_world_but_not_the_glows_or_the_ui() -> void:
	# Once seed 1's disaster shows, at night: nothing in World but what adds, a glow or the lamps'
	# group, draws above the night's veil, and a legend's veil draws at its z, since two multiplies
	# commute (§5.5, §5.12, P1, N32). The set pieces are checked under World's SetPieces. The HUD
	# and the menus are on the UI's layer.
	watch_signals(EventBus)
	var main := MainScene.open(self, ["--seed=1", "--hour=22"])
	var daylight := _daylight(main)
	var veil_z := Disasters.z(daylight)
	assert_eq(veil_z, Tuning.VEIL_Z, "Daylight's z")
	assert_false(daylight.z_as_relative, "absolute")
	MainScene.run_while(self, main, RUNNING, 3600)
	var frames := 0
	while get_signal_emit_count(EventBus, "disaster_appeared") == 0 and frames < 600:
		simulate(main, 1, MainScene.DELTA)
		frames += 1
	simulate(main, 30, MainScene.DELTA)
	assert_signal_emitted(EventBus, "disaster_appeared")
	var world: WorldRenderer = main.get_node("%World")
	var set_pieces: Node2D = world.get_node("%SetPieces")
	var items: Array[Array] = []
	for item: CanvasItem in _items(world):
		items.append([item, Disasters.z(item)])
	var pieces: Array[Node] = []
	for scene: PackedScene in world.set_piece_scenes.values():
		var piece := scene.instantiate()
		pieces.append(piece)
		for item: CanvasItem in _items(piece):
			items.append([item, _z_under(item, set_pieces)])
	assert_gt(items.size(), 100, "World's items")
	for pair: Array in items:
		var item: CanvasItem = pair[0]
		var z: int = pair[1]
		if _blends(item, CanvasItemMaterial.BLEND_MODE_MUL):
			assert_eq(z, veil_z, "%s: a veil, with the night's" % item.name)
		elif not _blends(item, CanvasItemMaterial.BLEND_MODE_ADD):
			assert_lt(z, veil_z, "%s: under the night's veil" % item.name)
	for piece: Node in pieces:
		piece.free()
	assert_null(daylight.get_canvas_layer_node(), "Daylight is on the world's canvas")
	for ui: String in ["%HUD", "%GameOver", "%Title"]:
		var layer := (main.get_node(ui) as CanvasItem).get_canvas_layer_node()
		assert_not_null(layer, ui)
		if layer != null:
			assert_gt(layer.layer, 0, ui + ": over the world's canvas")


## `node` and every canvas item under it, with the nodes' own parts: their internal children, as
## the shadows' and the lamps' sprites are (C20).
static func _items(node: Node) -> Array[CanvasItem]:
	var found: Array[CanvasItem] = []
	if node is CanvasItem:
		found.append(node)
	for child: Node in node.get_children(true):
		found.append_array(_items(child))
	return found


## Whether `item` blends by `mode`, by its material. A canvas group draws what it holds as one, by
## its own material, as the lamps' group adds (DAYNIGHT_PLAN.md §5.12). But only what draws at its
## own z, and nothing if it y-sorts (P10b): Godot 4.7.2 groups the items that its children add to
## its z's list (servers/rendering/renderer_canvas_cull.cpp:197–257 and :438–492).
static func _blends(item: CanvasItem, mode: CanvasItemMaterial.BlendMode) -> bool:
	var by := item
	var node := item.get_parent()
	while node is CanvasItem:
		var group := node as CanvasGroup
		if group != null and not group.y_sort_enabled and Disasters.z(group) == Disasters.z(item):
			by = group
		node = node.get_parent()
	if by.material is ShaderMaterial:
		var modes := ["blend_mix", "blend_add", "blend_sub", "blend_mul", "blend_premul_alpha"]
		var pattern := "render_mode[^;]*\\b%s\\b" % modes[mode]
		var code := (by.material as ShaderMaterial).shader.code
		return RegEx.create_from_string(pattern).search(code) != null
	var material := by.material as CanvasItemMaterial
	return material != null and material.blend_mode == mode


## The z that `item`, in a scene that isn't in the tree yet, draws at once under `parent`.
static func _z_under(item: CanvasItem, parent: CanvasItem) -> int:
	var total := 0
	var node: Node = item
	while node is CanvasItem:
		total += (node as CanvasItem).z_index
		if not (node as CanvasItem).z_as_relative:
			return total
		node = node.get_parent()
	return total + Disasters.z(parent)


func test_the_lamps_light_by_the_zones_clock() -> void:
	# World lights the props' lamps by the clock that Daylight keeps for the zone
	# (DAYNIGHT_PLAN.md §5.12): in the City at night they glow, and by day they are out.
	var main := MainScene.open(self, ["--area=city", "--hour=22"])
	simulate(main, 2, MainScene.DELTA)
	var world: WorldRenderer = main.get_node("%World")
	var daylight := _daylight(main)
	assert_same(world.cycle, daylight.cycle, "the zone's clock")
	var lamps: Lamps = world.get_node("%Lamps")
	var glows := 0
	for lit: Lamps.Lit in lamps.shown():
		glows += lit.sprite.get_child_count()
	assert_gt(glows, 20, "the City's lit windows and lamps")
	assert_true(lamps.visible, "at night")
	var strength := Lamps.strength(daylight.cycle.light)
	assert_gt(strength, 0.0)
	assert_almost_eq(lamps.self_modulate.a, Tuning.LAMP_ALPHA * strength, 1e-6)
	_set_hour(main, 12.0)
	simulate(main, 1, MainScene.DELTA)
	assert_false(lamps.visible, "by day")
