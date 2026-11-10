extends GutTest
## Each run starts by naming its area (IMPLEMENTATION_PLAN.md M4.3, M4_PLAN.md K4): main reports
## the first area as it reports each later one, to GameState and on EventBus, and the HUD shows its
## name. --area=<id> starts every run in that area (K10).

const MainScene := preload("res://tests/helpers/main_scene.gd")
const RUNNING := GameState.State.RUNNING
const DISASTER := GameState.State.DISASTER


func after_each() -> void:
	GameState.quit_to_title()


static func _banner(main: Node) -> Label:
	return main.get_node("%HUD/%AreaBanner")


## The path distance to the far edge of the junction with turn number `turn_number`, or -1 if
## `buffer` doesn't hold it.
static func _far_edge_of_junction(buffer: RoadBuffer, turn_number: int) -> float:
	for i: int in range(buffer.first_index(), buffer.last_index() + 1):
		var tile := buffer.path_tile(i)
		if tile.is_junction() and tile.turn_number == turn_number:
			return tile.path_index + 0.5
	return -1.0


## With no input, the first junction ends the run. Then Retry starts the next.
func _retry_after_the_first_junction(main: Node) -> void:
	MainScene.run_while(self, main, RUNNING, 3600)
	MainScene.run_while(self, main, DISASTER, 600)
	assert_eq(GameState.state, GameState.State.GAME_OVER, "game over")
	MainScene.press_key(main, KEY_ENTER)
	assert_eq(GameState.state, RUNNING, "retried")


func test_each_run_starts_by_naming_its_area() -> void:
	watch_signals(EventBus)
	var main := MainScene.open(self, ["--seed=1"])
	assert_signal_emit_count(EventBus, "area_changed", 1)
	var area: AreaDef = get_signal_parameters(EventBus, "area_changed")[0]
	assert_eq(area.id, &"city")
	assert_eq(GameState.area_id, &"city")
	assert_true(_banner(main).visible)
	assert_eq(_banner(main).text, "City")
	_retry_after_the_first_junction(main)
	assert_signal_emit_count(EventBus, "area_changed", 2)
	assert_eq(GameState.area_id, &"city")
	assert_true(_banner(main).visible, "the next run names it again")


func test_main_reports_each_new_area_of_the_car() -> void:
	watch_signals(EventBus)
	var main := MainScene.open(self, ["--seed=1"])
	var sim := MainScene.car(main).sim
	var rural := sim.buffer.generator.find_area(&"rural")
	sim.area_changed.emit(rural)
	assert_signal_emit_count(EventBus, "area_changed", 2)
	assert_same(get_signal_parameters(EventBus, "area_changed", 1)[0], rural)
	assert_eq(GameState.area_id, &"rural")
	assert_eq(_banner(main).text, "Rural")


func test_the_area_argument_starts_every_run_in_that_area() -> void:
	var main := MainScene.open(self, ["--seed=1", "--area=village"])
	var sim := MainScene.car(main).sim
	assert_eq(sim.area.id, &"village")
	assert_eq(sim.trigger.next_junction.area_id, &"village")
	assert_eq(GameState.area_id, &"village")
	assert_eq(_banner(main).text, "Village")
	_retry_after_the_first_junction(main)
	assert_eq(MainScene.car(main).sim.area.id, &"village", "and so does a retry")
	assert_eq(_banner(main).text, "Village")


func test_an_unknown_area_argument_starts_in_the_first_area() -> void:
	var main := MainScene.open(self, ["--seed=1", "--area=moon"])
	assert_push_error("no area moon")
	assert_eq(MainScene.car(main).sim.area.id, &"city")


func test_an_empty_area_argument_starts_in_the_first_area() -> void:
	var main := MainScene.open(self, ["--seed=1", "--area="])
	assert_push_error("--area= needs the id of an area")
	assert_eq(MainScene.car(main).sim.area.id, &"city")


## With no set piece between them, an area's first tile follows the junction that ends the area
## before, and the step that reaches it reports the area before it judges the turn there: that turn
## still counts for the area before, and the distance from the junction's far edge on for the next
## (M5_PLAN.md L8). Seed 1's Village meets the Desert after turn 20.
func test_each_area_counts_from_its_first_tile() -> void:
	var main := MainScene.open(self, ["--seed=1", "--area=village", "--autopilot"])
	var buffer := MainScene.car(main).sim.buffer
	var boundary := -1.0
	for frame: int in 60 * 60:
		if boundary < 0.0:
			boundary = _far_edge_of_junction(buffer, 19)
		if GameState.turn_index > 20 or GameState.state != RUNNING:
			break
		simulate(main, 1, MainScene.DELTA)
	assert_eq(GameState.state, RUNNING)
	assert_eq(GameState.turn_index, 21)
	assert_gt(boundary, 0.0)
	var desert := {"distance": GameState.distance - boundary, "turns": 1}
	assert_gt(desert["distance"], 0.0)
	assert_eq(
		GameState.stats()["areas"],
		{&"village": {"distance": boundary, "turns": 20}, &"desert": desert}
	)
