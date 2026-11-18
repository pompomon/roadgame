extends GutTest
## The title screen in the game (plan.md §2.6, IMPLEMENTATION_PLAN.md M5.5): the game starts on it,
## Play starts a run, on the road chosen (ENDGAME_PLAN.md §5.12), and the game-over screen's Title
## goes back to it, where the Atlas and the Book of Legends show what the run found. --collected
## fills the Book (§5.7, §5.10).
## Android's back button leaves a legend's page, then each screen, and quits only from the title
## (docs/M5.md L13). SaveService keeps the save in memory, except where a test gives it a file.

const MainScene := preload("res://tests/helpers/main_scene.gd")
const WrongTurnPilot := preload("res://tests/helpers/wrong_turn_pilot.gd")
const TITLE := GameState.State.TITLE
const RUNNING := GameState.State.RUNNING
const PAUSED := GameState.State.PAUSED
const ARRIVED := GameState.State.ARRIVED
const DISASTER := GameState.State.DISASTER
const GAME_OVER := GameState.State.GAME_OVER
const DIR := "user://save_tests"
const FILE := DIR + "/collected.json"


func before_each() -> void:
	SaveService.use_memory()
	# Play would start the tutorial, which has no disasters (docs/TUTORIAL.md §5.6).
	SaveService.complete_tutorial()


func after_each() -> void:
	GameState.quit_to_title()
	SaveService.use_memory()
	if FileAccess.file_exists(FILE):
		DirAccess.remove_absolute(FILE)
	DirAccess.remove_absolute(DIR)


## The main scene with no --play, which must not quit the tests on the back button.
func _open(args: Array[String] = ["--seed=1"]) -> Node:
	var main := MainScene.open(self, args, false)
	main.quit_requested.disconnect(get_tree().quit)
	return main


static func _title(main: Node) -> TitleScreen:
	return main.get_node("%Title")


## The Book's rows, once it is open.
static func _rows(main: Node) -> Array[BookRow]:
	var rows: Array[BookRow] = []
	rows.assign(_title(main).get_node("%Book/%Grid").get_children())
	return rows


## The Book's first cell of the legend `id`, or null. The cells follow the pools: in the City, not
## always the first (docs/POOLS.md V7).
static func _cell_of(main: Node, id: StringName) -> BookCell:
	for row: BookRow in _rows(main):
		for cell: BookCell in row.cells():
			if cell.legend["id"] == id:
				return cell
	return null


## The cars in World's Props layer, which y-sorts them with the props (docs/M5.md §5.6).
static func _cars(main: Node) -> int:
	var cars := 0
	for child: Node in main.get_node("%World/%Props").get_children():
		if child is CarController:
			cars += 1
	return cars


## Android's back button, as the window sends it to the scene.
static func _back(main: Node) -> void:
	main.get_parent().propagate_notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)


## Drives `main` on to the game-over screen: through a wrong turn into the City's phantom bus at the
## third junction, or with no input, which ends the run at the first junction.
func _to_game_over(main: Node, wrong_turn := true) -> void:
	if wrong_turn:
		var router: InputRouter = main.get_node("%InputRouter")
		router.autopilot = WrongTurnPilot.new(MainScene.car(main).sim)
	MainScene.run_while(self, main, RUNNING, 3600)
	MainScene.run_while(self, main, DISASTER, 600)
	assert_eq(GameState.state, GAME_OVER, "game over")


func test_the_game_starts_on_the_title_with_no_run() -> void:
	watch_signals(EventBus)
	var main := _open()
	assert_eq(GameState.state, TITLE)
	assert_true(_title(main).visible)
	assert_true((main.get_node("%Title/%Play") as Button).has_focus())
	assert_false((main.get_node("%HUD") as Control).visible)
	assert_false((main.get_node("%InputRouter") as InputRouter).enabled)
	assert_eq(_cars(main), 0, "no car")
	simulate(main, 60, MainScene.DELTA)
	assert_eq(GameState.state, TITLE)
	assert_signal_not_emitted(EventBus, "run_started")


func test_enter_or_a_tap_on_play_starts_one_run_that_does_not_steer() -> void:
	for tap: bool in [false, true]:
		var main := _open()
		watch_signals(EventBus)
		if tap:
			await wait_process_frames(2)
			var at := (main.get_node("%Title/%Play") as Button).get_global_rect().get_center()
			MainScene.push(main, [MainScene.touch(at, true), MainScene.touch(at, false)])
		else:
			MainScene.press_key(main, KEY_ENTER)
		var why := "a tap" if tap else "Enter"
		assert_signal_emit_count(EventBus, "run_started", 1, why)
		assert_eq(GameState.state, RUNNING, why)
		assert_false(_title(main).visible, why)
		assert_true((main.get_node("%HUD") as Control).visible, why)
		assert_eq(_cars(main), 1, why + ": one car")
		assert_eq((main.get_node("%InputRouter") as InputRouter).steer(), 0.0, why)
		main.get_parent().free()
		clear_signal_watcher()


func test_esc_leaves_a_screen_of_the_title_before_the_hud_sees_it() -> void:
	# The HUD takes Esc for its pause, so the title must come after it in the tree (L13).
	var main := _open()
	var title := _title(main)
	(title.get_node("%AtlasButton") as Button).pressed.emit()
	MainScene.press_key(main, KEY_ESCAPE)
	assert_null(title.open_screen())
	assert_true((title.get_node("%MainPage") as Control).visible)
	assert_eq(GameState.state, TITLE)


func test_after_play_the_arrow_keys_steer() -> void:
	var main := _open()
	MainScene.press_key(main, KEY_ENTER)
	MainScene.push(main, [MainScene.key(KEY_RIGHT, true)])
	assert_eq((main.get_node("%InputRouter") as InputRouter).steer(), 1.0, "not the focus")


func test_title_after_game_over_then_play_starts_afresh() -> void:
	var main := _open()
	MainScene.press_key(main, KEY_ENTER)
	_to_game_over(main, false)
	(main.get_node("%GameOver/%Title") as Button).pressed.emit()
	assert_eq(GameState.state, TITLE)
	assert_true(_title(main).visible)
	assert_false((main.get_node("%GameOver") as Control).visible)
	assert_false((main.get_node("%HUD") as Control).visible)
	assert_false((main.get_node("%InputRouter") as InputRouter).enabled)
	assert_eq(_cars(main), 0, "the car is gone")
	assert_null((main.get_node("%Camera") as CameraRig).car)
	assert_null((main.get_node("%World") as WorldRenderer).car)
	assert_no_new_orphans()
	watch_signals(EventBus)
	MainScene.press_key(main, KEY_ENTER)
	assert_signal_emit_count(EventBus, "run_started", 1)
	assert_eq(GameState.turn_index, 0)
	assert_eq(GameState.distance, 0.0)
	assert_eq(_cars(main), 1, "one car")


func test_the_atlas_and_the_book_show_a_wrong_turn() -> void:
	var main := _open()
	MainScene.press_key(main, KEY_ENTER)
	_to_game_over(main)
	var distance := Hud.distance_text(GameState.distance)
	var seen := (main.get_node("%Director") as DisasterDirector).disaster
	var seen_id := seen.id
	var seen_name := seen.display_name
	(main.get_node("%GameOver/%Title") as Button).pressed.emit()
	var title := _title(main)
	assert_eq((title.get_node("%Best") as Label).text, "Best: %s, 2 turns" % distance)
	(title.get_node("%AtlasButton") as Button).pressed.emit()
	var cards := title.get_node("%Atlas/%Cards").get_children()
	assert_eq((cards[0].get_node("%Title") as Label).text, "City")
	assert_eq(
		(cards[0].get_node("%Details") as Label).text, "Best distance: %s\nBest turns: 2" % distance
	)
	assert_eq((cards[1].get_node("%Title") as Label).text, AtlasScreen.UNKNOWN)
	title.go_back()
	(title.get_node("%DisastersButton") as Button).pressed.emit()
	assert_eq((title.get_node("%Book/%Heading") as Label).text, "Legends 1/15")
	var cell := _cell_of(main, seen_id)
	assert_eq((cell.get_node("%Name") as Label).text, seen_name, "the City's disaster")
	assert_true(_rows(main)[0].cells().has(cell), "in the City's row")
	cell.pressed.emit()
	assert_eq((title.get_node("%Book/%PageName") as Label).text, seen_name)
	assert_eq(
		(title.get_node("%Book/%Details") as Label).text,
		"Seen once\nFirst: City, %s, 2 turns" % distance
	)


func test_departures_offer_only_the_areas_discovered() -> void:
	# ENDGAME_PLAN.md §5.11, W22: other builds than debug offer the City alone, until a run discovers
	# a later area; the Coast is a home stretch, with no junction. A run from the Desert then records
	# the Desert's best and its legend, but no overall best.
	var main := _open()
	var title := _title(main)
	title.every_area = false
	title.open()
	var start: Button = title.get_node("%StartArea")
	assert_false(start.visible, "the City alone")
	var areas := {&"rural": {}, &"desert": {}, &"coast": {}}
	SaveService.data().record_run({"areas": areas, "whole_road": false})
	title.open()
	assert_true(start.visible)
	var texts: Array[String] = []
	for _press: int in 3:
		start.pressed.emit()
		texts.append(start.text)
	assert_eq(texts, ["Start in: Rural", "Start in: Desert", "Start in: City"])
	start.pressed.emit()
	start.pressed.emit()
	MainScene.press_key(main, KEY_ENTER)
	assert_eq(MainScene.car(main).sim.area.id, &"desert")
	assert_false(GameState.whole_road)
	_to_game_over(main, false)
	var save := SaveService.data()
	assert_eq(save.best, SaveData.BEST)
	assert_gt(save.atlas["desert"]["best_distance"], 0.0)
	assert_eq(save.seen_disasters().size(), 1, "the Desert's legend")
	(main.get_node("%GameOver/%Title") as Button).pressed.emit()
	assert_eq((title.get_node("%Best") as Label).text, "", "no overall best")
	assert_eq(start.text, "Start in: Desert", "the last choice")


## ENDGAME_PLAN.md §5.12, E9: once the road to the sea has an arrival, the title offers the Road
## Home too, and Play drives it whole, from the Desert, heading west. An arrival home alone, which
## only --home makes, offers nothing.
func test_the_road_home_is_offered_after_the_first_arrival() -> void:
	var main := _open()
	var title := _title(main)
	var road: Button = title.get_node("%Road")
	assert_false(road.visible, "the road to the sea alone")
	SaveService.data().record_arrival(&"home", {"seconds": 600.0})
	title.open()
	assert_false(road.visible, "an arrival home")
	SaveService.data().record_arrival(&"pier", {"seconds": 600.0})
	title.open()
	assert_true(road.visible)
	assert_eq(road.text, "Road: To the sea")
	road.pressed.emit()
	assert_eq(road.text, "Road: Home")
	assert_eq((title.get_node("%StartArea") as Button).text, "Start in: Desert")
	MainScene.press_key(main, KEY_ENTER)
	assert_eq(GameState.state, RUNNING)
	var buffer := MainScene.car(main).sim.buffer
	var first := buffer.path_tile(buffer.first_index())
	assert_eq([first.heading, first.area_id], [Heading.W, &"desert"])
	assert_eq([GameState.whole_road, GameState.road], [true, &"home"])


## ENDGAME_PLAN.md §5.12, E9: a run on the Road Home, from the title, counts its arrival under home,
## not the sea's, and unlocks a legend. Its farthest turn is the finish's. The title keeps the road
## chosen until the game closes.
func test_the_road_home_counts_under_home() -> void:
	SaveService.data().record_arrival(&"pier", {"seconds": 600.0, "turn_index": 280})
	var main := _open(["--seed=12345", "--finish=2"])
	var road: Button = _title(main).get_node("%Road")
	road.pressed.emit()
	MainScene.press_key(main, KEY_ENTER)
	var router: InputRouter = main.get_node("%InputRouter")
	router.autopilot = Autopilot.new(MainScene.car(main).sim)
	MainScene.run_while(self, main, RUNNING, 60 * 90)
	assert_eq(GameState.state, ARRIVED)
	var save := SaveService.data()
	assert_eq([save.arrival_count(&"home"), save.arrival_count(&"pier")], [1, 1])
	assert_eq([save.arrivals["home"]["farthest"], save.arrivals["pier"]["farthest"]], [2, 280])
	var unlocked := 0
	for entry: Dictionary in save.disasters.values():
		unlocked += int(entry["unlocked"])
	assert_eq(unlocked, 1, "a legend")
	MainScene.run_while(self, main, ARRIVED, 600)
	(main.get_node("%GameOver/%Title") as Button).pressed.emit()
	assert_eq(GameState.state, TITLE)
	assert_eq(road.text, "Road: Home", "the last choice")


## ENDGAME_PLAN.md §5.13, E11: after the first arrival, the title also offers Keep Driving, the
## game's road with no end, endless(), where the Desert goes on as on main. Play drives it whole,
## from the City, and its runs count as main's did, for the overall bests, the areas and the
## legends, but for no road's farthest turn, as none can arrive.
func test_keep_driving_is_the_endless_road_after_the_first_arrival() -> void:
	var main := _open()
	var title := _title(main)
	var road: Button = title.get_node("%Road")
	SaveService.data().record_arrival(&"pier", {"seconds": 600.0})
	title.open()
	road.pressed.emit()
	road.pressed.emit()
	assert_eq(road.text, "Road: Endless")
	assert_eq((title.get_node("%StartArea") as Button).text, "Start in: City")
	var areas := title.schedule.areas()
	assert_eq(title.road.areas(), areas.slice(0, -1), "the Coast's home stretch left out")
	# Past the sea's finish, the road goes on in the Desert.
	var generator := RoadGenerator.new(1, title.road)
	while generator.turn_count < title.schedule.finish_turn + 20 and not generator.finished():
		generator.next_tile()
	assert_eq([generator.finished(), generator.current_area.id], [false, &"desert"])
	MainScene.press_key(main, KEY_ENTER)
	assert_eq(GameState.state, RUNNING)
	assert_eq([GameState.whole_road, GameState.road], [true, &""])
	_to_game_over(main)
	var save := SaveService.data()
	assert_eq(save.best["turns"], GameState.turn_index, "the overall best")
	assert_gt(save.best["distance"], 0.0)
	assert_gt(save.atlas["city"]["best_distance"], 0.0)
	assert_eq(save.seen_disasters().size(), 1, "the City's legend")
	assert_eq(save.arrivals.keys(), ["pier"], "no road's farthest turn")
	assert_eq(save.arrivals["pier"]["farthest"], 0)
	(main.get_node("%GameOver/%Title") as Button).pressed.emit()
	assert_ne((title.get_node("%Best") as Label).text, "")
	assert_eq(road.text, "Road: Endless", "the last choice")


func test_androids_back_button_in_each_state() -> void:
	var main := _open()
	watch_signals(main)
	var title := _title(main)
	(title.get_node("%SettingsButton") as Button).pressed.emit()
	_back(main)
	assert_null(title.open_screen(), "a screen of the title: back to the title")
	assert_eq(GameState.state, TITLE)
	assert_signal_not_emitted(main, "quit_requested")
	_back(main)
	assert_signal_emit_count(main, "quit_requested", 1, "the title: quit")
	(title.get_node("%Play") as Button).pressed.emit()
	_back(main)
	assert_eq(GameState.state, PAUSED, "running: pause")
	_back(main)
	assert_eq(GameState.state, PAUSED, "paused: stay paused")
	GameState.resume()
	MainScene.run_while(self, main, RUNNING, 3600)
	_back(main)
	assert_eq(GameState.state, DISASTER, "the disaster plays on")
	MainScene.run_while(self, main, DISASTER, 600)
	_back(main)
	assert_eq(GameState.state, TITLE, "game over: the title")
	assert_true(title.visible)
	assert_eq(_cars(main), 0)
	assert_signal_emit_count(main, "quit_requested", 1)


func test_androids_back_button_closes_a_legends_page_before_the_book() -> void:
	var main := _open(["--seed=1", "--collected=city"])
	watch_signals(main)
	var title := _title(main)
	(title.get_node("%DisastersButton") as Button).pressed.emit()
	var book: BookScreen = title.get_node("%Book")
	var cell := _rows(main)[0].cells()[0]
	cell.pressed.emit()
	assert_eq(book.open_cell(), cell, "its page")
	_back(main)
	assert_null(book.open_cell(), "the page closes")
	assert_eq(title.open_screen(), book, "the Book stays open")
	assert_true(cell.has_focus(), "on the legend's cell")
	_back(main)
	assert_null(title.open_screen(), "then the Book closes")
	assert_true((title.get_node("%DisastersButton") as Button).has_focus())
	assert_signal_not_emitted(main, "quit_requested")


func test_collected_city_fills_and_seals_the_citys_row() -> void:
	var main := _open(["--seed=1", "--collected=city"])
	var title := _title(main)
	(title.get_node("%DisastersButton") as Button).pressed.emit()
	assert_eq((title.get_node("%Book/%Heading") as Label).text, "Legends 3/15")
	var rows := _rows(main)
	assert_eq(rows.size(), 5, "the five pools")
	for k: int in rows.size():
		assert_eq(rows[k].sealed, k == 0, "only the City's row is sealed: row %d" % k)
		for cell: BookCell in rows[k].cells():
			assert_eq(cell.found, k == 0, "%s found" % cell.legend["id"])
	var cell := rows[0].cells()[0]
	cell.pressed.emit()
	assert_eq(
		(title.get_node("%Book/%Details") as Label).text,
		"Seen once\nFirst: City, %s, 0 turns" % Hud.distance_text(0.0)
	)
	assert_eq(GameState.state, TITLE, "with no run")


func test_collected_all_fills_the_book() -> void:
	var main := _open(["--seed=1", "--collected=all"])
	var title := _title(main)
	(title.get_node("%DisastersButton") as Button).pressed.emit()
	assert_eq((title.get_node("%Book/%Heading") as Label).text, "Legends 15/15")
	for row: BookRow in _rows(main):
		assert_true(row.sealed, "every row is sealed")
	var data := SaveService.data()
	for area: AreaDef in title.schedule.areas():
		for scene: PackedScene in area.disasters:
			var entry: Dictionary = data.disasters[String(DisasterPicks.id_of(scene))]
			assert_eq(entry["first_area"], String(area.id), "in its own area")


func test_collected_writes_the_save_and_keeps_what_was_seen() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	SaveService.use_file(FILE)
	SaveService.data().record_disaster(&"mothman", &"rural", {"distance": 12.0, "turn_index": 3})
	var main := _open(["--seed=1", "--collected=city"])
	main.get_parent().free()
	SaveService.use_file(FILE)
	var seen := SaveService.data().seen_disasters()
	assert_eq(seen.size(), 3, "read back: %s" % [seen])
	for id: StringName in [&"phantom_bus", &"mothman", &"grim_reaper"]:
		assert_has(seen, id, "read back")
	var mothman: Dictionary = SaveService.data().disasters["mothman"]
	assert_eq(mothman["first_area"], "rural", "a legend seen keeps its entry")
	assert_eq(int(mothman["seen"]), 1, "seen once, not twice")


func test_collected_with_no_legends_is_an_error_and_collects_none() -> void:
	for id: String in ["moon", "coast", ""]:
		var main := _open(["--seed=1", "--collected=" + id])
		assert_push_error("--collected= needs all or an area with legends", id)
		assert_eq(SaveService.data().seen_disasters().size(), 0, id)
		main.get_parent().free()


func test_the_back_button_does_not_quit_on_its_own() -> void:
	# Godot quits from every screen unless quit_on_go_back is off (docs/M5.md L13).
	assert_false(ProjectSettings.get_setting("application/config/quit_on_go_back"))
	assert_false(get_tree().quit_on_go_back)


func test_the_autopilot_and_play_skip_the_title() -> void:
	var runs: Array[Array] = [["--autopilot", "--seed=1"], ["--play"]]
	for run: Array in runs:
		var args: Array[String] = []
		args.assign(run)
		var main := MainScene.open(self, args, false)
		assert_eq(GameState.state, RUNNING, " ".join(args))
		assert_false(_title(main).visible, " ".join(args))
		main.get_parent().free()


func test_play_and_title_are_errors_in_other_states() -> void:
	var main := _open()
	(main.get_node("%GameOver") as GameOver).title_requested.emit()
	assert_push_error("the title screen is only reachable from game over")
	MainScene.press_key(main, KEY_ENTER)
	_title(main).play_requested.emit()
	assert_push_error("Play is only allowed on the title screen")
	assert_eq(GameState.state, RUNNING)
	assert_eq(_cars(main), 1, "the same run")
