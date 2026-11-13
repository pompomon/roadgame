extends GutTest
## A crash ends the run without a disaster (plan.md §2.1, IMPLEMENTATION_PLAN.md M3.3): the car
## turns to its crash frame and smokes, the camera shakes, the car stops within STOP_SECONDS, and
## the game-over screen shows CRASH_SECONDS after the crash.

const MainScene := preload("res://tests/helpers/main_scene.gd")


func after_each() -> void:
	GameState.quit_to_title()


func test_a_crash_smokes_shakes_and_ends_the_game_after_crash_seconds() -> void:
	watch_signals(EventBus)
	var main := MainScene.open(self, ["--seed=1"])
	var car := MainScene.car(main)
	# Sideways off the first straight, and on until the off-road limit or the health runs out.
	car.sim.angle += PI / 2.0
	MainScene.run_while(self, main, GameState.State.RUNNING, 1200)
	assert_eq(GameState.state, GameState.State.CRASH)
	assert_has([CarSim.OFFROAD, CarSim.HEALTH], GameState.end_cause)
	assert_signal_not_emitted(EventBus, "disaster_triggered")
	var body: Sprite2D = car.get_node("%Body")
	assert_eq(body.frame, CarController.WRECK_FRAME, "the wreck")
	assert_true(car.get_node("%Smoke").emitting, "smoke")
	var camera: CameraRig = main.get_node("%Camera")
	assert_ne(camera.offset, Vector2.ZERO, "the camera shakes")
	var director: DisasterDirector = main.get_node("%Director")
	assert_eq(director.sequence, DisasterDirector.Sequence.CRASH)
	var game_over: GameOver = main.get_node("%GameOver")
	var stopped := -1
	var shown_early := false
	var frames := 0
	while GameState.state == GameState.State.CRASH and frames < 600:
		shown_early = shown_early or game_over.visible
		simulate(main, 1, MainScene.DELTA)
		frames += 1
		if car.sim.speed == 0.0 and stopped < 0:
			stopped = frames
	assert_false(shown_early, "the game-over screen waits for the crash")
	assert_eq(GameState.state, GameState.State.GAME_OVER)
	assert_almost_eq(frames * MainScene.DELTA, Tuning.CRASH_SECONDS, MainScene.DELTA * 1.01)
	assert_between(stopped * MainScene.DELTA, 0.0, Tuning.STOP_SECONDS + 0.01, "the car stopped")
	assert_eq(main.get_node("%World/%DisasterLayer").get_child_count(), 0, "no disaster")
	assert_eq(camera.offset, Vector2.ZERO, "the shake is over")
	assert_true(game_over.visible)
	assert_eq(game_over.get_node("%Cause").text, GameOver.END_MESSAGES[GameState.end_cause])
	assert_signal_emit_count(EventBus, "run_ended", 1)


func test_a_car_lost_off_the_road_shows_its_health_left_and_an_empty_meter() -> void:
	# As in the screenshot of HEALTH_BAR_PLAN.md B1, the off-road limit ends the run with health
	# left. The HUD shows why, up to the game-over screen and under it (E3).
	var main := MainScene.open(self, ["--seed=1"])
	var car := MainScene.car(main)
	var health: ProgressBar = main.get_node("%HUD/%Health")
	var meter: ProgressBar = main.get_node("%HUD/%Offroad")
	car.sim.angle += PI / 2.0
	MainScene.run_while(self, main, GameState.State.RUNNING, 1200)
	assert_eq(GameState.end_cause, CarSim.OFFROAD)
	assert_gt(car.sim.health, 0.0, "the limit came first, with health left")
	assert_almost_eq(health.value, car.sim.health, health.step, "on the health bar")
	assert_eq(meter.modulate.a, 1.0, "the meter shows")
	assert_true(meter.is_visible_in_tree(), "and is drawn")
	assert_eq(meter.value, 0.0, "empty")
	MainScene.run_while(self, main, GameState.State.CRASH, 600)
	assert_eq(GameState.state, GameState.State.GAME_OVER)
	assert_eq(meter.modulate.a, 1.0, "under the game-over screen too")
	assert_true(meter.is_visible_in_tree())
	assert_eq(meter.value, 0.0)
