extends GutTest
## The Vanishing Hitchhiker in the game (docs/ENDGAME.md §5.17, E15, E16): with every legend of the
## pools collected, she stands beside the Road Home before the junction of the player's farthest
## turn there, also on a departure from a later area that starts before it, or before its finish
## once they have arrived home. The car's passing finds her: the save keeps her at once, and the end
## screen shows NEW LEGEND! for her. She stands on no other road, nor with a legend missing, nor
## once found. A run that ends before her doesn't find her, and a retry places her anew.

const MainScene := preload("res://tests/helpers/main_scene.gd")
const RUNNING := GameState.State.RUNNING
const DISASTER := GameState.State.DISASTER
const ARRIVED := GameState.State.ARRIVED
const GAME_OVER := GameState.State.GAME_OVER
## Long enough for a few turns, and short enough to fail fast.
const FRAMES := 60 * 90

## The car's progress each time a Hitchhiker's `passed` reached the test, which hears it after
## main does, in the same step.
var _passed_at: Array[float] = []


func before_each() -> void:
	SaveService.use_memory()
	_passed_at.clear()


func after_each() -> void:
	GameState.quit_to_title()


## The Hitchhikers on World's Props layer, where she stands among the props.
static func _hitchhikers(main: Node) -> Array[Hitchhiker]:
	var found: Array[Hitchhiker] = []
	for node: Node in main.get_node("%World/%Props").get_children():
		if node is Hitchhiker:
			found.append(node)
	return found


## The run's Hitchhiker, or null if she doesn't stand on its road.
static func _hitchhiker(main: Node) -> Hitchhiker:
	var found := _hitchhikers(main)
	return found[0] if found.size() == 1 else null


## The path index of the last plain straight, not a pit stop's, before the path tile `place`.
static func _last_plain(buffer: RoadBuffer, place: int) -> int:
	var index := place - 1
	while index >= buffer.first_index():
		var tile := buffer.path_tile(index)
		if tile.type == RoadTile.Type.STRAIGHT and not tile.pit_stop:
			return index
		index -= 1
	return -1


## The path index of the junction of the run's turn `turn`, or -1 if the buffer holds none.
static func _junction(buffer: RoadBuffer, turn: int) -> int:
	for index: int in range(buffer.first_index(), buffer.last_index() + 1):
		var tile := buffer.path_tile(index)
		if tile.is_turn() and tile.turn_number == turn:
			return index
	return -1


## Drives `main` on to the game-over screen with no input, which ends the run at the first junction.
func _to_game_over(main: Node) -> void:
	MainScene.run_while(self, main, RUNNING, FRAMES)
	MainScene.run_while(self, main, DISASTER, 600)
	assert_eq(GameState.state, GAME_OVER, "game over")


## Keeps the progress of `sim`, the run's car, as a Hitchhiker's `passed` reaches the test.
func _on_passed(sim: CarSim) -> void:
	_passed_at.append(sim.progress)


func test_she_stands_before_the_junction_of_the_players_farthest_turn_on_the_road_home() -> void:
	SaveService.data().record_run({"road": Hitchhiker.ROAD, "turn_index": 2})
	var main := MainScene.open(self, ["--seed=1", "--home", "--collected=all"])
	var hitchhiker := _hitchhiker(main)
	assert_not_null(hitchhiker, "on the Road Home, with the pools collected")
	if hitchhiker == null:
		return
	var sim := MainScene.car(main).sim
	var junction := _junction(sim.buffer, 2)
	assert_gt(junction, 0, "the third turn's junction")
	assert_eq(hitchhiker.index, _last_plain(sim.buffer, junction))
	assert_true(hitchhiker.visible)
	assert_eq(hitchhiker.sim, sim, "the run's car passes her")
	assert_does_not_have(SaveService.data().seen_disasters(), Hitchhiker.ID, "not found yet")


func test_a_departure_that_starts_before_her_turn_has_her_too() -> void:
	# The Village starts at the Road Home's turn 16, so her turn 18 is the departure's turn 2. The
	# Meadows start at turn 24, past her.
	for area: String in ["village", "meadows"]:
		SaveService.use_memory()
		SaveService.data().record_run({"road": Hitchhiker.ROAD, "turn_index": 18})
		var main := MainScene.open(
			self, ["--seed=1", "--home", "--collected=all", "--area=" + area]
		)
		var hitchhiker := _hitchhiker(main)
		if area == "meadows":
			assert_null(hitchhiker, "a departure past her turn")
		else:
			assert_not_null(hitchhiker, area)
		if hitchhiker != null:
			var buffer := MainScene.car(main).sim.buffer
			assert_eq(hitchhiker.index, _last_plain(buffer, _junction(buffer, 2)), area)
			assert_true(hitchhiker.visible, area)
		main.get_parent().free()


func test_passing_her_finds_her_and_the_end_screen_shows_a_new_legend() -> void:
	# Arrived home before, so she stands by the finish of --finish's road of 3 turns, in the Desert.
	var save := SaveService.data()
	save.record_arrival(&"pier", {"seconds": 600.0, "clean": false, "turn_index": 280})
	save.record_arrival(Hitchhiker.ROAD, {"seconds": 900.0, "clean": false, "turn_index": 280})
	var args: Array[String] = ["--autopilot", "--seed=12345", "--home", "--collected=all"]
	var main := MainScene.open(self, args + (["--finish=3"] as Array[String]))
	var hitchhiker := _hitchhiker(main)
	assert_not_null(hitchhiker)
	if hitchhiker == null:
		return
	var sim := MainScene.car(main).sim
	var buffer := sim.buffer
	assert_eq(hitchhiker.index, _last_plain(buffer, buffer.generator.finish_index), "the finish")
	watch_signals(hitchhiker)
	watch_signals(EventBus)
	hitchhiker.passed.connect(_on_passed.bind(sim))
	MainScene.run_while(self, main, RUNNING, FRAMES)
	assert_eq(GameState.state, ARRIVED)
	assert_signal_emit_count(hitchhiker, "passed", 1)
	var entry: Dictionary = save.disasters.get(String(Hitchhiker.ID), {})
	assert_eq(entry.get("seen"), 1, "found")
	assert_eq(entry.get("first_area"), "desert")
	assert_eq(entry.get("first_turns"), 3, "past the last junction")
	# The run starts at the road's start, so its distance is the car's progress: the step's that
	# passed her, not the step's before.
	assert_eq(_passed_at.size(), 1, "passed once")
	if _passed_at.size() == 1:
		assert_gt(_passed_at[0], float(hitchhiker.index), "past her tile's centre")
		assert_eq(entry.get("first_distance"), _passed_at[0], "the distance as the car passed her")
	MainScene.run_while(self, main, ARRIVED, 600)
	assert_false(hitchhiker.visible, "she vanished")
	var game_over: GameOver = main.get_node("%GameOver")
	assert_true(game_over.visible)
	assert_eq(game_over.get_node("%Fate").text, LegendUnlock.BOOK_FULL, "no legend to unlock")
	assert_true(game_over.get_node("%NewLegend").visible, "she is the run's new legend")
	assert_signal_emit_count(EventBus, "new_legend_shown", 1)
	assert_eq(game_over.get_node("%Goal").text, GameOver.GOAL_CLEAN, "every legend, her too")


func test_she_stands_on_no_other_road_nor_with_a_legend_missing_nor_once_found() -> void:
	var cases: Dictionary[String, Array] = {
		"the road to the sea": ["--seed=1", "--collected=all"],
		"a legend missing": ["--seed=1", "--home", "--collected=city"],
		"found": ["--seed=1", "--home", "--collected=all"],
	}
	for what: String in cases:
		SaveService.use_memory()
		if what == "found":
			SaveService.data().record_disaster(Hitchhiker.ID, &"desert", {})
		var args: Array[String] = []
		args.assign(cases[what])
		var main := MainScene.open(self, args)
		assert_eq(_hitchhikers(main).size(), 0, what)
		main.get_parent().free()


func test_a_run_that_ends_before_her_doesnt_find_her_and_a_retry_places_her_anew() -> void:
	SaveService.data().record_run({"road": Hitchhiker.ROAD, "turn_index": 2})
	var main := MainScene.open(self, ["--seed=1", "--home", "--collected=all"])
	var hitchhiker := _hitchhiker(main)
	assert_not_null(hitchhiker)
	if hitchhiker == null:
		return
	watch_signals(hitchhiker)
	_to_game_over(main)
	assert_signal_not_emitted(hitchhiker, "passed")
	assert_true(hitchhiker.visible, "still there")
	assert_does_not_have(SaveService.data().seen_disasters(), Hitchhiker.ID)
	MainScene.press_key(main, KEY_ENTER)
	assert_eq(GameState.state, RUNNING, "Enter pressed Retry")
	assert_false(is_instance_valid(hitchhiker), "the last run's is freed")
	assert_eq(_hitchhikers(main).size(), 1, "one Hitchhiker")
	var again := _hitchhiker(main)
	if again == null:
		return
	var sim := MainScene.car(main).sim
	assert_eq(again.sim, sim, "the new run's car")
	assert_eq(again.index, _last_plain(sim.buffer, _junction(sim.buffer, 2)))
	assert_true(again.visible)
