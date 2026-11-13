extends GutTest
## Day and night in the game (DAYNIGHT_PLAN.md §5.4–§5.9): each run starts in the morning at once;
## each zone starts its clock again, and the light catches up no faster than the rate; the clock
## runs only with the run; --hour= sets the hour that zones start at; a disaster plays in the light
## that the run ended in; the night's veil darkens the world but not the glows or the UI; and the
## light changes nothing but the view.

const MainScene := preload("res://tests/helpers/main_scene.gd")
const Disasters := preload("res://tests/helpers/disaster_fixtures.gd")
const RUNNING := GameState.State.RUNNING
const DISASTER := GameState.State.DISASTER
const GAME_OVER := GameState.State.GAME_OVER


func after_each() -> void:
	GameState.quit_to_title()


static func _daylight(main: Node) -> Daylight:
	return main.get_node("%Daylight")


## Sets the clock of `main`'s zone to `hour`, with the light of that hour shown at once.
static func _set_hour(main: Node, hour: float) -> void:
	var daylight := _daylight(main)
	var cycle := daylight.cycle
	cycle.seconds = fposmod(hour - cycle.start_hour, 24.0) / 24.0 * cycle.day_seconds
	cycle.snap()
	daylight.refresh()


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
	# A new run is a cut, also after a night (N23).
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
	# From 17:00, 600 frames are 10 s of the City's 120 s day: two hours, into the dusk (N22).
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
	# and the light catches up with the morning's at the rate, without a jump (N22).
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


func test_the_clock_stops_when_the_run_ends_and_while_paused() -> void:
	# simulate() steps a paused tree too, so here only the state can stop the clock (N21). The
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
	# The clock stops with the run, and the director gives the disaster its light (§5.6, N24).
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
	# The same run by day and by night: the road, the car, the run and the sound end the same
	# (§5.1). The first is freed before the second opens.
	var ends: Array[Dictionary] = []
	for hour: String in ["--hour=7", "--hour=19"]:
		var main := MainScene.open(self, ["--seed=1", "--autopilot", hour])
		simulate(main, 1200, MainScene.DELTA)
		var sim := MainScene.car(main).sim
		var volumes: Array[float] = []
		for bus: int in AudioServer.bus_count:
			volumes.append(AudioServer.get_bus_volume_db(bus))
		var end := {
			"tile": sim.buffer.path_tile(sim.buffer.car_index()).path_index,
			"turns": GameState.turn_index,
			"distance": GameState.distance,
			"health": sim.health,
			"area": GameState.area_id,
			"state": GameState.state,
			"tracks": AudioDirector.tracks(),
			"volumes": volumes,
		}
		ends.append(end)
		main.get_parent().free()
	assert_ne(ends[0]["area"], &"", "a run")
	assert_eq(ends[1], ends[0])


func test_the_veil_darkens_the_world_but_not_the_glows_or_the_ui() -> void:
	# Once seed 1's disaster shows, at night: nothing in World but a glow draws above the night's
	# veil, and a legend's veil draws at its z, since two multiplies commute (§5.5, P1, N26). The
	# set pieces are checked under World's SetPieces. The HUD and the menus are on the UI's layer.
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


## `node` and every canvas item under it.
static func _items(node: Node) -> Array[CanvasItem]:
	var found: Array[CanvasItem] = []
	if node is CanvasItem:
		found.append(node)
	for child: Node in node.get_children():
		found.append_array(_items(child))
	return found


static func _blends(item: CanvasItem, mode: CanvasItemMaterial.BlendMode) -> bool:
	var material := item.material as CanvasItemMaterial
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
