extends GutTest
## Retry (IMPLEMENTATION_PLAN.md M3.3, M3 tests): the game-over screen's Retry starts the next run
## in place, without reloading the scene. Nothing of the last run is left: not its state, its car,
## its disaster, its road or its shake, and no orphan nodes (M3_PLAN.md J10 to J13).

const MainScene := preload("res://tests/helpers/main_scene.gd")
const WrongTurnPilot := preload("res://tests/helpers/wrong_turn_pilot.gd")
const RUNNING := GameState.State.RUNNING
const DISASTER := GameState.State.DISASTER
const GAME_OVER := GameState.State.GAME_OVER


func after_each() -> void:
	GameState.quit_to_title()


## Drives `main` on to the game-over screen: through a wrong turn at the third junction, or with no
## input, which on any road ends the run at the first junction.
func _to_game_over(main: Node, wrong_turn := true) -> void:
	if wrong_turn:
		var router: InputRouter = main.get_node("%InputRouter")
		router.autopilot = WrongTurnPilot.new(MainScene.car(main).sim)
	MainScene.run_while(self, main, RUNNING, 3600)
	MainScene.run_while(self, main, DISASTER, 600)
	assert_eq(GameState.state, GAME_OVER, "game over")


static func _retry_centre(main: Node) -> Vector2:
	var retry: Button = main.get_node("%GameOver/%Retry")
	return retry.get_global_rect().get_center()


func test_retry_starts_the_next_run_afresh() -> void:
	var main := MainScene.open(self, ["--seed=1"])
	var first_junction := MainScene.car(main).sim.trigger.next_junction.cell
	_to_game_over(main)
	var old_car := MainScene.car(main)
	var old_sim: WeakRef = weakref(old_car.sim)
	var old_buffer: WeakRef = weakref(old_car.sim.buffer)
	var director: DisasterDirector = main.get_node("%Director")
	var old_disaster := director.disaster
	EventBus.health_changed.emit(10.0)
	assert_gt(GameState.distance, 5.0, "the last run went some way")
	watch_signals(EventBus)
	MainScene.press_key(main, KEY_ENTER)
	assert_signal_emit_count(EventBus, "run_started", 1, "Enter pressed Retry")
	assert_eq(GameState.state, RUNNING)
	assert_eq(GameState.turn_index, 0)
	assert_eq(GameState.distance, 0.0)
	assert_eq(GameState.end_cause, &"")
	assert_eq(GameState.run_seed, 1, "--seed stays")
	var game_over: GameOver = main.get_node("%GameOver")
	assert_false(game_over.visible)
	var props: Node = main.get_node("%World/%Props")
	assert_eq(props.get_child_count(), 1, "one car")
	var car := MainScene.car(main)
	assert_false(is_instance_valid(old_car), "the last car is freed at once")
	assert_false(is_instance_valid(old_disaster), "and so is its disaster")
	assert_null(old_sim.get_ref(), "and its sim")
	assert_null(old_buffer.get_ref(), "and its road")
	assert_eq(main.get_node("%World/%DisasterLayer").get_child_count(), 0)
	assert_eq(director.sequence, DisasterDirector.Sequence.NONE)
	assert_eq(car.sim.state, CarSim.State.DRIVING)
	assert_eq(car.sim.speed, 0.0)
	assert_eq(car.sim.health, Tuning.START_HEALTH)
	assert_eq(car.scale, Vector2.ONE, "a car that has not sunk")
	assert_eq(car.modulate, Color.WHITE)
	assert_eq(car.sim.buffer.car_index(), 0, "at the start of a new road")
	assert_eq(car.sim.trigger.next_junction.cell, first_junction, "the same road")
	var camera: CameraRig = main.get_node("%Camera")
	assert_eq(camera.car, car)
	assert_eq(camera.offset, Vector2.ZERO, "no shake")
	var router: InputRouter = main.get_node("%InputRouter")
	assert_true(router.enabled, "the input is on")
	assert_null(router.autopilot, "no autopilot without --autopilot")
	var hud: Hud = main.get_node("%HUD")
	assert_eq((hud.get_node("%Turns") as Label).text, "turns 0")
	assert_eq((hud.get_node("%Health") as ProgressBar).value, Tuning.START_HEALTH)
	assert_true(hud.get_node("%Pause").visible, "Pause is back")
	simulate(main, 1, MainScene.DELTA)
	assert_eq((hud.get_node("%Distance") as Label).text, "0 m")


func test_after_retry_the_arrow_keys_steer_and_enter_does_nothing() -> void:
	# Retry had the focus, which takes the arrow keys for itself; hiding it gives them back.
	var main := MainScene.open(self, ["--seed=1"])
	_to_game_over(main, false)
	MainScene.press_key(main, KEY_ENTER)
	assert_eq(GameState.state, RUNNING)
	var router: InputRouter = main.get_node("%InputRouter")
	MainScene.push(main, [MainScene.key(KEY_LEFT, true)])
	assert_eq(router.steer(), -1.0, "Left steers")
	MainScene.push(main, [MainScene.key(KEY_LEFT, false), MainScene.key(KEY_RIGHT, true)])
	assert_eq(router.steer(), 1.0, "Right steers")
	MainScene.push(main, [MainScene.key(KEY_RIGHT, false)])
	watch_signals(EventBus)
	MainScene.press_key(main, KEY_ENTER)
	MainScene.press_key(main, KEY_SPACE)
	assert_signal_not_emitted(EventBus, "run_started", "no retry while running")


func test_a_tap_or_a_click_on_retry_retries_once() -> void:
	var main := MainScene.open(self, ["--seed=1"])
	for click: bool in [false, true]:
		_to_game_over(main, false)
		await wait_process_frames(2)
		var at := _retry_centre(main)
		var events: Array[InputEvent] = []
		if click:
			events.append_array(MainScene.click(at, true))
			events.append_array(MainScene.click(at, false))
		else:
			events.append_array([MainScene.touch(at, true), MainScene.touch(at, false)])
		clear_signal_watcher()
		watch_signals(EventBus)
		MainScene.push(main, events)
		var why := "a click" if click else "a tap"
		assert_signal_emit_count(EventBus, "run_started", 1, why + ": one press, one retry")
		assert_eq(GameState.state, RUNNING, why)


func test_three_runs_in_a_row() -> void:
	watch_signals(EventBus)
	var main := MainScene.open(self, [])
	var seeds: Array[int] = [GameState.run_seed]
	for _retry: int in 2:
		_to_game_over(main, false)
		MainScene.press_key(main, KEY_ENTER)
		seeds.append(GameState.run_seed)
		assert_eq(main.get_node("%World/%Props").get_child_count(), 1, "one car")
	assert_signal_emit_count(EventBus, "run_started", 3)
	assert_signal_emit_count(EventBus, "run_ended", 2)
	assert_ne(seeds[1], seeds[0], "a new seed without --seed")
	assert_ne(seeds[2], seeds[1], "a new seed without --seed")


func test_a_retry_leaves_no_orphan_nodes() -> void:
	var main := MainScene.open(self, ["--seed=1"])
	_to_game_over(main, false)
	MainScene.press_key(main, KEY_ENTER)
	assert_eq(GameState.state, RUNNING)
	assert_no_new_orphans()


func test_a_retry_while_the_run_goes_on_is_an_error() -> void:
	var main := MainScene.open(self, ["--seed=1"])
	var car := MainScene.car(main)
	var game_over: GameOver = main.get_node("%GameOver")
	game_over.retry_requested.emit()
	assert_push_error("a retry is only allowed after game over")
	assert_eq(GameState.state, RUNNING)
	assert_eq(MainScene.car(main), car, "the same run")
