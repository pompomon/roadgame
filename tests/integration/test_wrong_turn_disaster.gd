extends GutTest
## A wrong turn ends the run with a disaster (plan.md §2.1, IMPLEMENTATION_PLAN.md M3 tests): the
## autopilot takes a wrong exit at the third junction, the input stops, the car stops, a disaster
## of the City's pool takes it, and the game-over screen shows 2 to 4 s after the turn. Its sound
## starts as it shows (docs/M6.md S18).

const MainScene := preload("res://tests/helpers/main_scene.gd")
const WrongTurnPilot := preload("res://tests/helpers/wrong_turn_pilot.gd")
const CITY := preload("res://areas/city.tres")
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


func test_the_citys_disaster_takes_the_car_and_then_the_game_is_over() -> void:
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
	var city: AreaDef = CITY
	var pool := city.disasters.map(func(scene: PackedScene) -> String: return scene.resource_path)
	assert_has(pool, disaster.scene_file_path, "from the City's pool")
	assert_eq(disaster.get_parent(), main.get_node("%World/%DisasterLayer"))
	assert_eq(car.sim.speed, 0.0, "the car stopped")
	assert_eq(car.modulate.a, 0.0, "and is out of sight")
	assert_signal_emit_count(EventBus, "run_ended", 1, "once")
	assert_true(game_over.visible)
	assert_eq(game_over.get_node("%Cause").text, GameOver.END_MESSAGES[CarSim.WRONG_TURN])
	var fate: Label = game_over.get_node("%Fate")
	assert_true(fate.visible, "the disaster's fate (docs/M6.md S8)")
	assert_eq(fate.text, disaster.fate)
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


func test_the_run_and_its_disaster_are_saved() -> void:
	SaveService.use_memory()
	watch_signals(EventBus)
	var main := _wrong_turn()
	var director: DisasterDirector = main.get_node("%Director")
	var save := SaveService.data()
	var city: Dictionary = save.atlas["city"]
	assert_true(city["discovered"])
	assert_eq(city["best_turns"], 2)
	assert_almost_eq(city["best_distance"], GameState.distance, 1e-6, "all of it in the City")
	assert_eq(save.best, {"distance": GameState.distance, "turns": 2}, "when it ended")
	assert_eq(save.disasters, {} as Dictionary[String, Dictionary], "not before it shows")
	MainScene.run_while(self, main, DISASTER, 600)
	var id := director.disaster.id
	assert_signal_emitted_with_parameters(EventBus, "disaster_started", [id, CITY])
	var expected := {
		"seen": 1, "first_area": "city", "first_distance": GameState.distance, "first_turns": 2
	}
	assert_eq(save.disasters[String(id)], expected)


func test_the_disasters_sound_starts_as_it_shows() -> void:
	# On the frame its delay is over, not as it starts to play (docs/M6.md S18, E8).
	watch_signals(EventBus)
	watch_signals(AudioDirector)
	var main := _wrong_turn()
	var director: DisasterDirector = main.get_node("%Director")
	var started := -1
	var played := -1
	var frames := 0
	while GameState.state == DISASTER and frames < 600:
		simulate(main, 1, MainScene.DELTA)
		frames += 1
		if started < 0 and get_signal_emit_count(EventBus, "disaster_started") > 0:
			started = frames
		if played < 0 and started > 0 and _played(director.disaster.id):
			played = frames
	assert_gt(started, 0, "a disaster played")
	assert_gt(played, 0, "and its sound")
	assert_almost_eq(
		(played - started) * MainScene.DELTA,
		director.params.delay,
		MainScene.DELTA * 1.01,
		"its delay after it started"
	)


## Whether AudioDirector played the sound `id`.
func _played(id: StringName) -> bool:
	for k: int in get_signal_emit_count(AudioDirector, "effect_played"):
		if get_signal_parameters(AudioDirector, "effect_played", k) == [id]:
			return true
	return false
