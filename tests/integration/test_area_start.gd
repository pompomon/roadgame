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
