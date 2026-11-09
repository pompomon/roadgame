extends GutTest
## A wrong turn ends the run with a disaster (plan.md §2.1, IMPLEMENTATION_PLAN.md M3 tests): the
## autopilot takes a wrong exit at the third junction, the input stops, the car stops, the City's
## sinkhole swallows it, and the game-over screen shows 2 to 4 s after the turn.

const MainScene := preload("res://tests/helpers/main_scene.gd")
const WrongTurnPilot := preload("res://tests/helpers/wrong_turn_pilot.gd")
const RUNNING := GameState.State.RUNNING
const DISASTER := GameState.State.DISASTER


func after_each() -> void:
	GameState.quit_to_title()


## The main scene for seed 1, driven by a WrongTurnPilot until the run ends.
func _wrong_turn() -> Node:
	var main := MainScene.open(self, ["--seed=1"])
	var router: InputRouter = main.get_node("%InputRouter")
	router.autopilot = WrongTurnPilot.new(MainScene.car(main).sim)
	MainScene.run_while(self, main, RUNNING, 3600)
	return main


func test_a_wrong_turn_at_the_third_junction_triggers_one_disaster_in_the_city() -> void:
	watch_signals(EventBus)
	var main := _wrong_turn()
	assert_eq(GameState.state, DISASTER)
	assert_eq(GameState.end_cause, CarSim.WRONG_TURN)
	assert_eq(GameState.turn_index, 2, "two turns, then the wrong one")
	assert_signal_emit_count(EventBus, "disaster_triggered", 1)
	var triggered: Array = get_signal_parameters(EventBus, "disaster_triggered")
	var junction: RoadTile = triggered[1]
	assert_eq(junction.turn_number, 2, "the third junction")
	assert_eq((triggered[0] as AreaDef).id, &"city")
	assert_signal_emit_count(EventBus, "run_ended", 1, "at the turn")
	assert_false(main.get_node("%InputRouter").enabled, "the input is off")
	assert_false(main.get_node("%HUD/%Pause").visible, "no pausing")
	assert_false(main.get_node("%GameOver").visible, "not yet")


func test_the_citys_sinkhole_swallows_the_car_and_then_the_game_is_over() -> void:
	watch_signals(EventBus)
	var main := _wrong_turn()
	var car := MainScene.car(main)
	var director: DisasterDirector = main.get_node("%Director")
	var game_over: GameOver = main.get_node("%GameOver")
	var disaster: DisasterBase = null
	var shown_early := false
	var paused := false
	var frames := 0
	while GameState.state == DISASTER and frames < 600:
		MainScene.press_key(main, KEY_ESCAPE)
		paused = paused or GameState.state != DISASTER
		simulate(main, 1, MainScene.DELTA)
		frames += 1
		if director.disaster != null:
			disaster = director.disaster
		shown_early = shown_early or (game_over.visible and GameState.state == DISASTER)
	assert_false(paused, "Esc does not pause the disaster")
	assert_eq(GameState.state, GameState.State.GAME_OVER)
	assert_between(frames * MainScene.DELTA, 2.0, 4.0, "2 to 4 s after the turn")
	assert_false(shown_early, "the game-over screen waits for the disaster")
	assert_not_null(disaster, "a disaster played")
	var city: AreaDef = load("res://areas/city.tres")
	var pool := city.disasters.map(func(scene: PackedScene) -> String: return scene.resource_path)
	assert_has(pool, disaster.scene_file_path, "from the City's pool")
	assert_eq(disaster.get_parent(), main.get_node("%World/%DisasterLayer"))
	assert_eq(car.sim.speed, 0.0, "the car stopped")
	assert_almost_eq(car.scale, Vector2.ONE * Sinkhole.SUNK_SCALE, Vector2.ONE * 1e-6, "and sank")
	assert_signal_emit_count(EventBus, "run_ended", 1, "once")
	assert_true(game_over.visible)
	assert_eq(game_over.get_node("%Cause").text, GameOver.END_MESSAGES[CarSim.WRONG_TURN])
	var stats: Label = game_over.get_node("%Stats")
	assert_eq(stats.text, GameOver.stats_text(GameState.stats(), city))
	assert_string_contains(stats.text, "Turns: 2")


func test_the_same_seed_plays_the_same_disaster() -> void:
	var rolls: Array[Array] = []
	for _run: int in 2:
		var main := _wrong_turn()
		var director: DisasterDirector = main.get_node("%Director")
		MainScene.run_while(self, main, DISASTER, 600)
		var params := director.params
		rolls.append([params.direction, params.intensity, params.delay, params.origin_world])
		GameState.quit_to_title()
	assert_eq(rolls[0], rolls[1])
