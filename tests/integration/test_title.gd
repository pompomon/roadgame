extends GutTest
## The title screen in the game (plan.md §2.6, IMPLEMENTATION_PLAN.md M5.5): the game starts on it,
## Play starts a run, and the game-over screen's Title goes back to it, where the Atlas and the
## collection show what the run found. Android's back button leaves each screen, and quits only
## from the title (M5_PLAN.md L13). SaveService keeps the save in memory.

const MainScene := preload("res://tests/helpers/main_scene.gd")
const WrongTurnPilot := preload("res://tests/helpers/wrong_turn_pilot.gd")
const TITLE := GameState.State.TITLE
const RUNNING := GameState.State.RUNNING
const PAUSED := GameState.State.PAUSED
const DISASTER := GameState.State.DISASTER
const GAME_OVER := GameState.State.GAME_OVER


func before_each() -> void:
	SaveService.use_memory()
	# Play would start the tutorial, which has no disasters (TUTORIAL_PLAN.md §5.6).
	SaveService.complete_tutorial()


func after_each() -> void:
	GameState.quit_to_title()
	SaveService.use_memory()


## The main scene with no --play, which must not quit the tests on the back button.
func _open(args: Array[String] = ["--seed=1"]) -> Node:
	var main := MainScene.open(self, args, false)
	main.quit_requested.disconnect(get_tree().quit)
	return main


static func _title(main: Node) -> TitleScreen:
	return main.get_node("%Title")


## The cars in World's Props layer, which y-sorts them with the props (M5_PLAN.md §5.6).
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


func test_the_atlas_and_the_collection_show_a_wrong_turn() -> void:
	var main := _open()
	MainScene.press_key(main, KEY_ENTER)
	_to_game_over(main)
	var distance := Hud.distance_text(GameState.distance)
	var seen := (main.get_node("%Director") as DisasterDirector).disaster.display_name
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
	cards = title.get_node("%Collection/%Cards").get_children()
	assert_eq((cards[0].get_node("%Title") as Label).text, seen, "the City's disaster")
	assert_eq(
		(cards[0].get_node("%Details") as Label).text,
		"Seen once\nFirst: City, %s, 2 turns" % distance
	)


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


func test_the_back_button_does_not_quit_on_its_own() -> void:
	# Godot quits from every screen unless quit_on_go_back is off (M5_PLAN.md L13).
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
