extends GutTest
## The main scene (IMPLEMENTATION_PLAN.md M2 tests): it boots, drives, ends a run, and routes input.
## It runs in a SubViewport, and input goes in through the viewport as on a device, so the HUD's
## Pause button gets the first look at touches and clicks. What follows the end of a run, the
## disaster or the crash, the game-over screen and Retry, has its own tests (M3).

const MAIN_SCENE := preload("res://ui/main.tscn")
const DELTA := 1.0 / 60.0


func after_each() -> void:
	GameState.quit_to_title()


## The main scene with user arguments `args`, in a portrait SubViewport.
func _main(args: Array[String]) -> Node:
	var view := SubViewport.new()
	view.size = Vector2i(360, 640)
	add_child_autofree(view)
	var main: Node = MAIN_SCENE.instantiate()
	main.args = PackedStringArray(args)
	view.add_child(main)
	return main


## Steps the scene until the run ends, for at most `frames` frames.
func _drive(main: Node, frames: int) -> void:
	for _i: int in frames:
		simulate(main, 1, DELTA)
		if GameState.state != GameState.State.RUNNING:
			return


static func _router(main: Node) -> InputRouter:
	return main.get_node("%InputRouter")


static func _pause_button_centre(main: Node) -> Vector2:
	var pause: Button = main.get_node("%HUD/%Pause")
	return pause.get_global_rect().get_center()


static func _key(keycode: Key, pressed: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = pressed
	return event


static func _touch(at: Vector2, pressed: bool) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.position = at
	event.pressed = pressed
	return event


## A left click as a desktop browser sends it with emulate_touch_from_mouse: an emulated touch
## first, then the mouse button.
static func _click(at: Vector2, pressed: bool) -> Array[InputEvent]:
	var touch := _touch(at, pressed)
	touch.device = InputEvent.DEVICE_ID_EMULATION
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	if pressed:
		mouse.button_mask = MOUSE_BUTTON_MASK_LEFT
	mouse.position = at
	mouse.global_position = at
	mouse.pressed = pressed
	return [touch, mouse]


static func _push(main: Node, events: Array[InputEvent]) -> void:
	for event: InputEvent in events:
		main.get_viewport().push_input(event, true)


func test_with_the_autopilot_it_drives_600_frames_without_errors() -> void:
	var main := _main(["--seed=1", "--autopilot"])
	assert_eq(GameState.state, GameState.State.RUNNING)
	assert_eq(GameState.run_seed, 1)
	_drive(main, 600)
	assert_eq(GameState.state, GameState.State.RUNNING, "still driving")
	assert_gt(GameState.turn_index, 2, "turns")
	assert_gt(GameState.distance, 20.0, "tiles")
	var distance: Label = main.get_node("%HUD/%Distance")
	assert_eq(distance.text, "%d m" % roundi(GameState.distance * Tuning.METRES_PER_TILE))
	var turns: Label = main.get_node("%HUD/%Turns")
	assert_eq(turns.text, "turns %d" % GameState.turn_index)


func test_the_distance_is_the_farthest_point_reached() -> void:
	var main := _main(["--seed=1", "--autopilot"])
	_drive(main, 60)
	var car: CarController = main.get_node("%World/%Props").get_child(0)
	var farthest := car.sim.progress
	assert_gt(farthest, 0.5, "it drove")
	_router(main).autopilot = null
	car.sim.angle += PI
	_drive(main, 30)
	assert_lt(car.sim.progress, farthest - 0.5, "it drove back")
	assert_eq(GameState.distance, farthest)


func test_a_rejoin_that_ends_the_run_counts_its_last_step() -> void:
	# As in test_car_sim_offroad.gd's test_a_step_that_ends_the_run_measures_the_progress_first:
	# off the road in the dead end on the right of the first junction, the car steps along the
	# junction's heading back onto the dead end's road, a wrong turn. It is fast enough for the step
	# to add a metre to the HUD.
	watch_signals(EventBus)
	var main := _main(["--seed=1"])
	var car: CarController = main.get_node("%World/%Props").get_child(0)
	var sim := car.sim
	var junction := sim.trigger.next_junction
	var exit := Heading.right(junction.heading)
	var along := Vector2(Heading.VEC[junction.heading])
	var behind := along * (Tuning.ROAD_HALF_WIDTH + 0.005)
	sim.pos = Iso.cell_centre(junction.cell) + Vector2(Heading.VEC[exit]) * 0.75 - behind
	sim.path_tile = junction
	sim.buffer.on_car_path_index(junction.path_index)
	sim.progress = CarSim.path_progress(junction, sim.pos)
	sim.angle = junction.heading * PI / 2.0
	sim.speed = 6.0
	sim.state = CarSim.State.OFFROAD
	sim.offroad_junction = junction
	var before := sim.progress
	_drive(main, 1)
	assert_eq(GameState.state, GameState.State.DISASTER)
	assert_eq(GameState.end_cause, CarSim.WRONG_TURN)
	var after := CarSim.path_progress(junction, sim.pos)
	var metres := roundi(after * Tuning.METRES_PER_TILE)
	assert_gt(metres, roundi(before * Tuning.METRES_PER_TILE), "the step adds a metre")
	assert_eq(GameState.distance, after, "the distance counts the last step")
	var stats: Dictionary = get_signal_parameters(EventBus, "run_ended")[1]
	assert_eq(stats["distance"], after, "and so do the run's stats")
	var distance: Label = main.get_node("%HUD/%Distance")
	assert_eq(distance.text, "%d m" % metres, "and so does the HUD")


func test_with_no_input_the_first_junction_ends_the_run() -> void:
	watch_signals(EventBus)
	var main := _main(["--seed=1"])
	_drive(main, 600)
	assert_eq(GameState.state, GameState.State.DISASTER)
	assert_has([CarSim.WRONG_TURN, CarSim.MISSED_TURN], GameState.end_cause)
	assert_eq(GameState.turn_index, 0)
	assert_signal_emitted_with_parameters(
		EventBus, "run_ended", [GameState.end_cause, GameState.stats()]
	)
	var disaster: Array = get_signal_parameters(EventBus, "disaster_triggered")
	var junction: RoadTile = disaster[1]
	assert_eq(junction.path_index, Tuning.START_STRAIGHT_TILES, "the first junction")
	assert_eq((disaster[0] as AreaDef).id, junction.area_id)
	assert_false(_router(main).enabled, "the input is off")
	assert_false(main.get_node("%HUD/%Pause").visible, "no pausing after the end")


func test_with_the_autopilot_the_end_of_a_run_is_an_error() -> void:
	# The CI smoke run drives with the autopilot and fails on any error.
	var main := _main(["--seed=1", "--autopilot"])
	_router(main).enabled = false
	_drive(main, 600)
	assert_eq(GameState.state, GameState.State.DISASTER)
	assert_push_error("main: the autopilot's run ended")


func test_a_key_released_while_paused_is_not_missed() -> void:
	var main := _main(["--seed=1"])
	_push(main, [_key(KEY_RIGHT, true)])
	assert_eq(_router(main).steer(), 1.0)
	_push(main, [_key(KEY_ESCAPE, true), _key(KEY_ESCAPE, false)])
	assert_eq(GameState.state, GameState.State.PAUSED)
	_push(main, [_key(KEY_RIGHT, false), _key(KEY_ESCAPE, true), _key(KEY_ESCAPE, false)])
	assert_eq(GameState.state, GameState.State.RUNNING)
	assert_eq(_router(main).steer(), 0.0, "the release during the pause counted")


func test_losing_focus_pauses_the_run_and_releases_the_keys() -> void:
	var main := _main(["--seed=1"])
	for what: int in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT]:
		_push(main, [_key(KEY_LEFT, true)])
		assert_eq(_router(main).steer(), -1.0, "before notification %d" % what)
		main.propagate_notification(what)
		assert_eq(GameState.state, GameState.State.PAUSED, "after notification %d" % what)
		assert_eq(_router(main).steer(), 0.0, "after notification %d" % what)
		GameState.resume()


func test_a_tap_on_the_pause_button_pauses_without_steering() -> void:
	var main := _main(["--seed=1"])
	await wait_process_frames(2)
	var pause := _pause_button_centre(main)
	_push(main, [_touch(pause, true)])
	assert_eq(_router(main).steer(), 0.0, "the button kept the touch")
	_push(main, [_touch(pause, false)])
	assert_eq(GameState.state, GameState.State.PAUSED)
	_push(main, [_touch(pause, true), _touch(pause, false)])
	assert_eq(GameState.state, GameState.State.RUNNING)
	_push(main, [_touch(Vector2(40.0, 400.0), true)])
	assert_eq(_router(main).steer(), -1.0, "a touch on the left half")


func test_a_click_works_like_a_tap_and_leaves_enter_alone() -> void:
	assert_true(ProjectSettings.get_setting("input_devices/pointing/emulate_touch_from_mouse"))
	var main := _main(["--seed=1"])
	await wait_process_frames(2)
	var pause := _pause_button_centre(main)
	_push(main, _click(pause, true))
	assert_eq(_router(main).steer(), 0.0, "the button kept the emulated touch")
	_push(main, _click(pause, false))
	assert_eq(GameState.state, GameState.State.PAUSED, "one click, one press")
	_push(main, [_key(KEY_ENTER, true), _key(KEY_ENTER, false)])
	assert_eq(GameState.state, GameState.State.PAUSED, "the button took no focus for Enter")
	_push(main, _click(pause, true))
	_push(main, _click(pause, false))
	assert_eq(GameState.state, GameState.State.RUNNING)
	_push(main, _click(Vector2(320.0, 400.0), true))
	assert_eq(_router(main).steer(), 1.0, "a click on the right half")
	_push(main, _click(Vector2(320.0, 400.0), false))
	assert_eq(_router(main).steer(), 0.0)
