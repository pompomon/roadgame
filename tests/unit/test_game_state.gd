extends GutTest
## A fresh GameState for each test, not the autoload: its state must not leak between tests.

const GameStateScript := preload("res://autoload/game_state.gd")

var _state: GameStateScript
## test_a_run_can_start_in_the_tutorial's: in_tutorial at each run_started.
var _tutorial_at_start: Array[bool] = []


func before_each() -> void:
	_state = GameStateScript.new()
	add_child_autofree(_state)
	watch_signals(EventBus)


func after_each() -> void:
	get_tree().paused = false


func test_starts_in_title() -> void:
	assert_eq(_state.state, GameStateScript.State.TITLE)


func test_start_run_resets_the_stats() -> void:
	_state.turn_index = 3
	_state.distance = 12.0
	_state.area_id = &"desert"
	_state.start_run(42)
	assert_eq(_state.state, GameStateScript.State.RUNNING)
	assert_eq(
		_state.stats(),
		{
			"run_seed": 42,
			"turn_index": 0,
			"distance": 0.0,
			"area_id": &"",
			"cause": &"",
			"areas": {},
		}
	)
	assert_signal_emitted_with_parameters(EventBus, "run_started", [42])


func test_pause_and_resume_pause_the_tree() -> void:
	_state.start_run(1)
	_state.pause()
	assert_eq(_state.state, GameStateScript.State.PAUSED)
	assert_true(get_tree().paused)
	assert_signal_emitted_with_parameters(EventBus, "paused_changed", [true])
	_state.resume()
	assert_eq(_state.state, GameStateScript.State.RUNNING)
	assert_false(get_tree().paused)
	assert_signal_emitted_with_parameters(EventBus, "paused_changed", [false])


func test_wrong_and_missed_turns_are_disasters() -> void:
	for cause: StringName in [CarSim.WRONG_TURN, CarSim.MISSED_TURN]:
		_state.start_run(1)
		_state.end_run(cause)
		assert_eq(_state.state, GameStateScript.State.DISASTER, cause)
		_state.quit_to_title()


func test_health_and_offroad_are_crashes() -> void:
	for cause: StringName in [CarSim.HEALTH, CarSim.OFFROAD]:
		_state.start_run(1)
		_state.end_run(cause)
		assert_eq(_state.state, GameStateScript.State.CRASH, cause)
		_state.quit_to_title()


func test_end_run_emits_the_cause_and_stats() -> void:
	_state.start_run(7)
	_state.turn_index = 2
	_state.distance = 30.5
	_state.enter_area(&"rural", 30.5, 2)
	_state.end_run(CarSim.WRONG_TURN)
	var stats := {
		"run_seed": 7,
		"turn_index": 2,
		"distance": 30.5,
		"area_id": &"rural",
		"cause": CarSim.WRONG_TURN,
		"areas": {&"rural": {"distance": 0.0, "turns": 0}},
	}
	assert_signal_emitted_with_parameters(EventBus, "run_ended", [CarSim.WRONG_TURN, stats])


func test_game_over_then_retry() -> void:
	_state.start_run(1)
	_state.end_run(CarSim.HEALTH)
	_state.show_game_over()
	assert_eq(_state.state, GameStateScript.State.GAME_OVER)
	_state.start_run(2)
	assert_eq(_state.state, GameStateScript.State.RUNNING)
	assert_eq(_state.run_seed, 2)


## docs/TUTORIAL.md §5.5: in_tutorial is set before run_started, on which the HUD reads it, and
## each run starts with it or without.
func test_a_run_can_start_in_the_tutorial() -> void:
	EventBus.run_started.connect(_record_tutorial)
	_state.start_run(1, true)
	_state.end_tutorial()
	_state.end_run(CarSim.HEALTH)
	_state.show_game_over()
	_state.start_run(2, true)
	_state.end_run(CarSim.HEALTH)
	_state.show_game_over()
	_state.start_run(3)
	EventBus.run_started.disconnect(_record_tutorial)
	assert_eq(_tutorial_at_start, [true, true, false] as Array[bool])
	assert_false(_state.in_tutorial)


func _record_tutorial(_run_seed: int) -> void:
	_tutorial_at_start.append(_state.in_tutorial)


func test_quit_to_title_unpauses() -> void:
	_state.start_run(1)
	_state.pause()
	_state.quit_to_title()
	assert_eq(_state.state, GameStateScript.State.TITLE)
	assert_false(get_tree().paused)
	assert_signal_emit_count(EventBus, "paused_changed", 2)


func test_quit_to_title_from_title_does_nothing() -> void:
	_state.quit_to_title()
	assert_eq(_state.state, GameStateScript.State.TITLE)


func test_invalid_changes_push_an_error_and_change_nothing() -> void:
	_state.pause()
	assert_push_error("GameState: TITLE to PAUSED is not allowed")
	assert_eq(_state.state, GameStateScript.State.TITLE)
	assert_false(get_tree().paused)
	_state.start_run(1)
	_state.start_run(2)
	assert_push_error("GameState: RUNNING to RUNNING is not allowed")
	assert_eq(_state.run_seed, 1)
	_state.end_run(CarSim.HEALTH)
	_state.end_run(CarSim.WRONG_TURN)
	assert_push_error("GameState: CRASH to DISASTER is not allowed")
	assert_eq(_state.end_cause, CarSim.HEALTH)
	assert_signal_emit_count(EventBus, "run_ended", 1)


func test_a_paused_run_cannot_start_again() -> void:
	_state.start_run(1)
	_state.turn_index = 2
	_state.distance = 8.5
	_state.pause()
	var stats := _state.stats()
	_state.start_run(2)
	assert_push_error("GameState: start_run() in PAUSED is not allowed")
	assert_eq(_state.state, GameStateScript.State.PAUSED)
	assert_eq(_state.stats(), stats)
	assert_true(get_tree().paused)
	assert_signal_emit_count(EventBus, "run_started", 1)
	assert_signal_emit_count(EventBus, "paused_changed", 1)


func test_only_a_paused_run_can_resume() -> void:
	_state.resume()
	assert_push_error("GameState: resume() in TITLE is not allowed")
	assert_eq(_state.state, GameStateScript.State.TITLE)
	_state.start_run(1)
	_state.end_run(CarSim.HEALTH)
	_state.show_game_over()
	var stats := _state.stats()
	_state.resume()
	assert_push_error("GameState: resume() in GAME_OVER is not allowed")
	assert_eq(_state.state, GameStateScript.State.GAME_OVER)
	assert_eq(_state.stats(), stats)
	assert_signal_emit_count(EventBus, "run_started", 1)
	assert_signal_not_emitted(EventBus, "paused_changed")


func test_a_paused_run_cannot_end() -> void:
	_state.start_run(1)
	_state.pause()
	_state.end_run(CarSim.WRONG_TURN)
	assert_push_error("GameState: PAUSED to DISASTER is not allowed")
	assert_eq(_state.state, GameStateScript.State.PAUSED)


func test_every_state_can_quit_to_title() -> void:
	var paths := {
		"RUNNING": [],
		"PAUSED": [_state.pause],
		"DISASTER": [_state.end_run.bind(CarSim.MISSED_TURN)],
		"CRASH": [_state.end_run.bind(CarSim.OFFROAD)],
		"GAME_OVER": [_state.end_run.bind(CarSim.OFFROAD), _state.show_game_over],
	}
	for state_name: String in paths:
		_state.start_run(1)
		for step: Callable in paths[state_name]:
			step.call()
		assert_eq(GameStateScript.State.keys()[_state.state], state_name)
		_state.quit_to_title()
		assert_eq(_state.state, GameStateScript.State.TITLE, "from %s" % state_name)
	assert_false(get_tree().paused)


func test_stats_have_the_distance_and_turns_made_in_each_area() -> void:
	_state.start_run(1)
	_state.enter_area(&"city", 0.0, 0)
	_state.distance = 40.0
	_state.turn_index = 34
	_state.enter_area(&"rural", 40.0, 34)
	assert_eq(_state.area_id, &"rural")
	_state.distance = 52.5
	_state.turn_index = 37
	var areas: Dictionary = _state.stats()["areas"]
	assert_eq(
		areas, {&"city": {"distance": 40.0, "turns": 34}, &"rural": {"distance": 12.5, "turns": 3}}
	)
	_state.end_run(CarSim.HEALTH)
	_state.show_game_over()
	_state.start_run(2)
	assert_eq(_state.stats()["areas"], {}, "a new run starts afresh")


## The car can reach an area's first tile before its turn at the junction behind is judged, and,
## off the road, before its distance gets there: those still count for the area before (L8).
func test_an_area_counts_from_its_first_tile_and_the_turns_after_it() -> void:
	_state.start_run(1)
	_state.enter_area(&"meadows", 0.0, 0)
	_state.distance = 39.9
	_state.turn_index = 33
	_state.enter_area(&"village", 40.5, 34)
	assert_eq(
		_state.stats()["areas"],
		{&"meadows": {"distance": 39.9, "turns": 33}, &"village": {"distance": 0.0, "turns": 0}},
		"before the turn is judged"
	)
	_state.distance = 41.0
	_state.turn_index = 34
	assert_eq(
		_state.stats()["areas"],
		{&"meadows": {"distance": 40.5, "turns": 34}, &"village": {"distance": 0.5, "turns": 0}},
		"after it"
	)
