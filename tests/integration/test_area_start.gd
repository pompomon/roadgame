extends GutTest
## Each run starts by naming its area (IMPLEMENTATION_PLAN.md M4.3, docs/M4.md K4): main reports
## the first area as it reports each later one, to GameState and on EventBus, and the HUD shows its
## name. --area=<id> starts every run in that area (K10), and so does the title's Start button,
## which --area presets: in debug builds over every area (docs/ZONE_SELECT.md Z1, Z6), and in others
## over the areas discovered (ENDGAME_PLAN.md §5.11). SaveService keeps the save in memory.

const MainScene := preload("res://tests/helpers/main_scene.gd")
const Fixtures := preload("res://tests/helpers/road_fixtures.gd")
const RUNNING := GameState.State.RUNNING
const DISASTER := GameState.State.DISASTER


func before_each() -> void:
	SaveService.use_memory()
	# Play would start a run in the City with the tutorial (docs/TUTORIAL.md §5.6).
	SaveService.complete_tutorial()


func after_each() -> void:
	GameState.quit_to_title()
	SaveService.use_memory()


static func _banner(main: Node) -> Label:
	return main.get_node("%HUD/%AreaBanner")


static func _start(main: Node) -> Button:
	return main.get_node("%Title/%StartArea")


## The main scene on its title screen, with every area on the Start button, as a debug build
## offers them (Z4).
func _open_title(args: Array[String]) -> Node:
	var main := MainScene.open(self, args, false)
	var title: TitleScreen = main.get_node("%Title")
	title.every_area = true
	title.open()
	return main


## A tap on `button`, as the phone sends it.
static func _tap(main: Node, button: Button) -> void:
	var at := button.get_global_rect().get_center()
	MainScene.push(main, [MainScene.touch(at, true), MainScene.touch(at, false)])


## The sheets of the props that World's Props layer shows. Each area has its own (Z2, Z3). A hidden
## World or Props layer shows none.
static func _prop_sheets(main: Node) -> Array[String]:
	var sheets: Array[String] = []
	for node: Node in main.get_node("%World/%Props").get_children(true):
		var sprite := node as Sprite2D
		if (
			sprite != null
			and sprite.is_visible_in_tree()
			and not sheets.has(sprite.texture.resource_path)
		):
			sheets.append(sprite.texture.resource_path)
	return sheets


## The run's road so far, path tile by path tile.
static func _road(main: Node) -> Array[Array]:
	var buffer := MainScene.car(main).sim.buffer
	var road: Array[Array] = []
	for i: int in range(buffer.first_index(), buffer.last_index() + 1):
		road.append(Fixtures.signature(buffer.path_tile(i)))
	return road


## The path distance to the far edge of the junction of turn `turn_number`, not a decoy before it
## (docs/ROADGEN.md R2), or -1 if `buffer` doesn't hold it.
static func _far_edge_of_junction(buffer: RoadBuffer, turn_number: int) -> float:
	for i: int in range(buffer.first_index(), buffer.last_index() + 1):
		var tile := buffer.path_tile(i)
		if tile.is_turn() and tile.turn_number == turn_number:
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


func test_the_title_starts_the_runs_in_the_chosen_area_as_the_area_argument_does() -> void:
	var main := _open_title(["--seed=1"])
	await wait_process_frames(2)
	var start := _start(main)
	var play: Button = main.get_node("%Title/%Play")
	assert_eq(start.text, "Start in: City")
	for _press: int in 4:
		_tap(main, start)
	assert_eq(start.text, "Start in: Desert")
	assert_eq(GameState.state, GameState.State.TITLE, "the button only chooses")
	_tap(main, play)
	assert_eq(GameState.state, RUNNING)
	assert_eq(MainScene.car(main).sim.area.id, &"desert")
	assert_eq(GameState.area_id, &"desert")
	assert_eq(_banner(main).text, "Desert")
	var desert: Array[String] = ["res://assets/desert/props.png"]
	assert_eq(_prop_sheets(main), desert, "the desert's props, also below the start (Z3)")
	var road := _road(main)
	_retry_after_the_first_junction(main)
	assert_eq(MainScene.car(main).sim.area.id, &"desert", "and so does a retry")
	assert_eq(_road(main), road, "with the forced seed's road")
	MainScene.run_while(self, main, RUNNING, 3600)
	MainScene.run_while(self, main, DISASTER, 600)
	(main.get_node("%GameOver/%Title") as Button).pressed.emit()
	assert_eq(start.text, "Start in: Desert", "the title keeps the choice")
	_tap(main, start)
	assert_eq(start.text, "Start in: Coast", "after the Desert, the Coast (ENDGAME_PLAN.md §5.8)")
	_tap(main, start)
	_tap(main, play)
	assert_eq(MainScene.car(main).sim.area.id, &"city", "after the Coast, the City")
	var city: Array[String] = ["res://assets/city/props.png"]
	assert_eq(_prop_sheets(main), city)
	main.get_parent().free()
	main = MainScene.open(self, ["--seed=1", "--area=desert"])
	assert_eq(_road(main), road, "--area=desert's road, so that a seed seen on a phone replays")


func test_the_area_argument_presets_the_choice_and_the_world_has_every_area() -> void:
	var main := _open_title(["--seed=1", "--area=village"])
	await wait_process_frames(2)
	var start := _start(main)
	assert_eq(start.text, "Start in: Village")
	for area: int in 3:
		_tap(main, start)
	assert_eq(start.text, "Start in: City")
	_tap(main, main.get_node("%Title/%Play"))
	assert_eq(MainScene.car(main).sim.area.id, &"city")
	assert_eq(_banner(main).text, "City")
	var city: Array[String] = ["res://assets/city/props.png"]
	assert_eq(_prop_sheets(main), city, "the world has the City's props (Z2)")


func test_in_other_builds_the_area_argument_presets_only_an_area_discovered() -> void:
	# ENDGAME_PLAN.md §5.11: there the Start button offers the City and the areas discovered, and Play
	# starts in its choice. Until a run discovers the Village, --area=village gives way to the City.
	for discovered: bool in [false, true]:
		if discovered:
			SaveService.data().record_run({"areas": {&"village": {}}})
		var main := MainScene.open(self, ["--seed=1", "--area=village"], false)
		var title: TitleScreen = main.get_node("%Title")
		title.every_area = false
		title.open()
		var why := "discovered" if discovered else "not discovered"
		assert_eq(_start(main).visible, discovered, why)
		assert_eq(_start(main).text, "Start in: Village" if discovered else "Start in: City", why)
		MainScene.press_key(main, KEY_ENTER)
		var area := &"village" if discovered else &"city"
		assert_eq(MainScene.car(main).sim.area.id, area, why)
		main.get_parent().free()


## With no set piece between them, an area's first tile follows the junction that ends the area
## before, and the step that reaches it reports the area before it judges the turn there: that turn
## still counts for the area before, and the distance from the junction's far edge on for the next
## (docs/M5.md L8). Seed 1's Village meets the Desert after turn 20. The car crosses the Village on
## the road into the Desert, with no damage (ENDGAME_PLAN.md §5.16).
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
	var desert := {
		"distance": GameState.distance - boundary, "turns": 1, "damaged": false, "crossed": false
	}
	assert_gt(desert["distance"], 0.0)
	var village := {"distance": boundary, "turns": 20, "damaged": false, "crossed": true}
	assert_eq(GameState.stats()["areas"], {&"village": village, &"desert": desert})
