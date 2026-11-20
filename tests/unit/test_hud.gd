extends GutTest
## The grey-box HUD (IMPLEMENTATION_PLAN.md M2.6, M3.3) on its own: what it shows, the pause input,
## the route strip (docs/ENDGAME.md §5.14), and the fresh start of each run. The integration test
## checks the Pause button inside the main scene, and the game-over screen has its own test.
## SaveService keeps the save in memory.

const HUD_SCENE := preload("res://ui/hud.tscn")
const ROAD := preload("res://areas/schedule.tres")
const HOME_ROAD := preload("res://areas/schedule_home.tres")
const DELTA := 1.0 / 60.0
## The frames that add up to AREA_BANNER_SECONDS. Sums of 1/60 can fall short, so the name may stay
## a frame longer.
const BANNER_FRAMES := roundi(Tuning.AREA_BANNER_SECONDS / DELTA)
## A HUD this tall has a route strip 100 pixels long: a pixel for each of the roads' turns.
const PIXEL_A_TURN := 250.0
## The heights of the reference screens (docs/M2.md §6.5): most of them, the phone's and the Fold4
## cover's.
const SCREEN_HEIGHTS: Array[float] = [640.0, 800.0, 922.0]


func before_each() -> void:
	SaveService.use_memory()


func after_each() -> void:
	GameState.quit_to_title()
	SaveService.use_memory()


func _hud() -> Hud:
	var hud: Hud = HUD_SCENE.instantiate()
	add_child_autofree(hud)
	return hud


## A HUD that fills a screen: a Control that _strip() resizes. Resizing the HUD itself, whose
## anchors fill its parent, would warn in the frame of its _ready().
func _hud_on_screen() -> Hud:
	var screen := Control.new()
	add_child_autofree(screen)
	var hud: Hud = HUD_SCENE.instantiate()
	screen.add_child(hud)
	return hud


## The route strip of a HUD from _hud_on_screen(), on a screen 360 pixels wide and `height` tall.
static func _strip(hud: Hud, height := PIXEL_A_TURN) -> RouteStrip:
	(hud.get_parent() as Control).size = Vector2(360.0, height)
	return hud.get_node("%RouteStrip")


static func _text(hud: Hud, label: String) -> String:
	return hud.get_node("%" + label).text


static func _area(display_name: String) -> AreaDef:
	var area := AreaDef.new()
	area.display_name = display_name
	return area


static func _key(keycode: Key, pressed: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = pressed
	return event


func test_it_shows_the_version_and_the_seed_of_the_run() -> void:
	var hud := _hud()
	GameState.start_run(1234)
	var version: String = ProjectSettings.get_setting("application/config/version")
	assert_eq(_text(hud, "Info"), "Road Roguelike %s\nseed 1234" % version)


func test_it_shows_turns_health_and_distance_in_metres() -> void:
	var hud := _hud()
	var health: ProgressBar = hud.get_node("%Health")
	assert_eq(health.max_value, Tuning.START_HEALTH)
	assert_eq(health.value, Tuning.START_HEALTH)
	EventBus.turn_completed.emit(3)
	EventBus.health_changed.emit(42.5)
	GameState.distance = 12.34
	simulate(hud, 1, 1.0 / 60.0)
	assert_eq(_text(hud, "Turns"), "turns 3")
	assert_eq(health.value, 42.5)
	assert_eq(_text(hud, "Distance"), "123 m")
	GameState.distance = 0.0


func test_the_pause_action_pauses_and_resumes_a_running_game() -> void:
	var hud := _hud()
	hud._unhandled_input(_key(KEY_ESCAPE, true))
	assert_eq(GameState.state, GameState.State.TITLE, "no run to pause")
	GameState.start_run(1)
	hud._unhandled_input(_key(KEY_ESCAPE, true))
	assert_eq(GameState.state, GameState.State.PAUSED)
	assert_true(get_tree().paused)
	assert_eq(_text(hud, "Message"), Hud.PAUSED_MESSAGE)
	hud._unhandled_input(_key(KEY_P, true))
	assert_eq(GameState.state, GameState.State.RUNNING)
	assert_false(get_tree().paused)
	assert_eq(_text(hud, "Message"), "")


func test_the_pause_button_pauses_and_resumes() -> void:
	var hud := _hud()
	var pause: Button = hud.get_node("%Pause")
	GameState.start_run(1)
	pause.pressed.emit()
	assert_eq(GameState.state, GameState.State.PAUSED)
	pause.pressed.emit()
	assert_eq(GameState.state, GameState.State.RUNNING)


func test_the_distance_is_in_whole_metres() -> void:
	assert_eq(Hud.distance_text(0.0), "0 m")
	assert_eq(Hud.distance_text(12.34), "123 m")
	assert_eq(Hud.distance_text(12.36), "124 m")


func test_the_end_of_a_run_hides_the_pause_button_and_leaves_the_message_alone() -> void:
	var hud := _hud()
	GameState.start_run(1)
	GameState.end_run(CarSim.WRONG_TURN)
	assert_false(hud.get_node("%Pause").visible, "no pausing after the end")
	assert_eq(_text(hud, "Message"), "", "the game-over screen says why")


func test_each_run_starts_the_hud_afresh() -> void:
	# A retry starts the next run without reloading the HUD (docs/M3.md J10).
	var hud := _hud()
	GameState.start_run(1)
	EventBus.turn_completed.emit(5)
	EventBus.health_changed.emit(10.0)
	GameState.end_run(CarSim.HEALTH)
	GameState.show_game_over()
	GameState.start_run(2)
	var version: String = ProjectSettings.get_setting("application/config/version")
	assert_eq(_text(hud, "Turns"), "turns 0")
	assert_eq((hud.get_node("%Health") as ProgressBar).value, Tuning.START_HEALTH)
	assert_true(hud.get_node("%Pause").visible, "Pause is back")
	assert_eq(_text(hud, "Message"), "")
	assert_eq(_text(hud, "Info"), "Road Roguelike %s\nseed 2" % version)


func test_it_names_the_area_the_car_enters_for_a_while() -> void:
	var hud := _hud()
	var banner: Label = hud.get_node("%AreaBanner")
	GameState.start_run(1)
	assert_false(banner.visible, "no name before an area")
	EventBus.area_changed.emit(_area("Rural"))
	assert_true(banner.visible)
	assert_eq(banner.text, "Rural")
	simulate(hud, BANNER_FRAMES - 1, DELTA)
	assert_true(banner.visible, "a frame before the end")
	simulate(hud, 2, DELTA)
	assert_false(banner.visible, "gone")


func test_the_area_name_waits_while_the_game_is_paused() -> void:
	# GUT's simulate() steps the HUD while the tree is paused, as the HUD processes then too.
	var hud := _hud()
	var banner: Label = hud.get_node("%AreaBanner")
	GameState.start_run(1)
	EventBus.area_changed.emit(_area("Village"))
	simulate(hud, 60, DELTA)
	GameState.pause()
	simulate(hud, BANNER_FRAMES * 2, DELTA)
	assert_true(banner.visible, "the pause doesn't count")
	GameState.resume()
	simulate(hud, BANNER_FRAMES - 61, DELTA)
	assert_true(banner.visible, "a frame before the end")
	simulate(hud, 2, DELTA)
	assert_false(banner.visible, "gone")


func test_a_new_area_replaces_the_name_and_starts_its_time_again() -> void:
	var hud := _hud()
	var banner: Label = hud.get_node("%AreaBanner")
	GameState.start_run(1)
	EventBus.area_changed.emit(_area("Meadows"))
	@warning_ignore("integer_division")
	simulate(hud, BANNER_FRAMES / 2, DELTA)
	EventBus.area_changed.emit(_area("Village"))
	assert_eq(banner.text, "Village")
	simulate(hud, BANNER_FRAMES - 1, DELTA)
	assert_true(banner.visible, "a frame before the end")
	simulate(hud, 2, DELTA)
	assert_false(banner.visible, "gone")


func test_the_end_of_a_run_and_a_new_run_hide_the_area_name() -> void:
	var hud := _hud()
	var banner: Label = hud.get_node("%AreaBanner")
	GameState.start_run(1)
	EventBus.area_changed.emit(_area("Desert"))
	GameState.end_run(CarSim.WRONG_TURN)
	assert_false(banner.visible, "the game-over screen names the area")
	simulate(hud, 1, DELTA)
	assert_false(banner.visible, "and it stays hidden")
	GameState.quit_to_title()
	GameState.start_run(2)
	EventBus.area_changed.emit(_area("City"))
	GameState.quit_to_title()
	GameState.start_run(3)
	assert_false(banner.visible, "a new run starts without the last one's name")
	simulate(hud, 1, DELTA)
	assert_false(banner.visible, "and it stays hidden")


## docs/TUTORIAL.md §5.4: in the tutorial, the turns in a row of TUTORIAL_STREAK for the turns, no
## distance, and its goal, which fits the narrowest reference screen (docs/M2.md §6.5), for the
## area's name. Once it is done, the City's turns, distance and name; a run without it starts so.
func test_the_tutorial_shows_its_streak_and_goal_until_it_is_done() -> void:
	var hud := _hud()
	var distance: Label = hud.get_node("%Distance")
	var banner: Label = hud.get_node("%AreaBanner")
	GameState.start_run(1, true)
	EventBus.area_changed.emit(_area("City"))
	assert_eq(_text(hud, "Turns"), "turns 0/%d" % Tuning.TUTORIAL_STREAK)
	assert_false(distance.visible)
	assert_eq(banner.text, "Tutorial\n%d turns in a row" % Tuning.TUTORIAL_STREAK)
	assert_lte(banner.get_combined_minimum_size().x, 360.0)
	EventBus.streak_changed.emit(3)
	assert_eq(_text(hud, "Turns"), "turns 3/%d" % Tuning.TUTORIAL_STREAK)
	EventBus.streak_changed.emit(0)
	assert_eq(_text(hud, "Turns"), "turns 0/%d" % Tuning.TUTORIAL_STREAK)
	GameState.end_tutorial()
	EventBus.tutorial_completed.emit()
	EventBus.area_changed.emit(_area("City"))
	assert_eq(_text(hud, "Turns"), "turns 0")
	assert_true(distance.visible)
	assert_eq(banner.text, "City")
	GameState.quit_to_title()
	GameState.start_run(2, true)
	GameState.quit_to_title()
	GameState.start_run(3)
	assert_eq(_text(hud, "Turns"), "turns 0")
	assert_true(distance.visible)


## docs/ENDGAME.md §5.14, E12: on a road with a finish, a strip up the HUD's right edge, 6 pixels
## wide and 40% of its height, with a tick at each area's first turn, the Coast's at the finish; the
## car, which climbs a few pixels a turn on each reference screen, evenly, and never more than half
## its mark's height (SPEEDUP_PLAN.md §5.4); and the best run, the road's farthest turn as the run
## starts. A run from a later area starts at its area's tick, and in the tutorial the car waits at
## the foot.
func test_the_route_strip_marks_each_area_the_car_and_the_best() -> void:
	var hud := _hud_on_screen()
	var strip := _strip(hud)
	hud.road = ROAD
	GameState.start_run(1, false, true, &"pier")
	assert_true(strip.visible)
	var rect := strip.get_rect()
	assert_true(rect.is_equal_approx(Rect2(342.0, 75.0, 6.0, 100.0)), str(rect))
	assert_eq(strip.tick_heights(), [0, 34, 58, 76, 84, 100], "the City's to the Coast's")
	assert_eq([strip.car_height(), strip.best_height()], [0, -1], "at the foot, and no best yet")
	EventBus.turn_completed.emit(34)
	assert_eq(strip.car_height(), 34, "at Rural's tick")
	for screen_height: float in SCREEN_HEIGHTS:
		_strip(hud, screen_height)
		EventBus.turn_completed.emit(0)
		var climbs: Array[int] = []
		for turn: int in range(1, ROAD.finish_turn + 1):
			var before := strip.car_height()
			EventBus.turn_completed.emit(turn)
			climbs.append(strip.car_height() - before)
		var why := "%d pixels high" % screen_height
		var even := roundf(strip.size.y) / ROAD.finish_turn
		assert_between(climbs.min(), floori(even), ceili(even), why)
		assert_between(climbs.max(), floori(even), ceili(even), why)
		assert_lte(climbs.max(), RouteStrip.CAR_HEIGHT / 2.0, why + ": half the car's mark")
		assert_eq(strip.car_height(), roundi(strip.size.y), why + ": at the top")
	_strip(hud)
	GameState.turn_index = 40
	GameState.end_run(CarSim.WRONG_TURN)
	GameState.show_game_over()
	GameState.start_run(2, false, true, &"pier")
	assert_eq([strip.car_height(), strip.best_height()], [0, 40], "the next run, after turn 40")
	watch_signals(strip)
	await wait_process_frames(1)
	assert_signal_emitted(strip, "draw", "each mark, with no error")
	hud.start_turn = 84
	GameState.quit_to_title()
	GameState.start_run(3, false, false)
	assert_eq(strip.car_height(), 84, "a run from the Desert")
	EventBus.turn_completed.emit(10)
	assert_eq(strip.car_height(), 94)
	hud.start_turn = 0
	GameState.quit_to_title()
	GameState.start_run(4, true, true, &"pier")
	EventBus.streak_changed.emit(3)
	assert_eq(strip.car_height(), 0, "the tutorial")
	GameState.end_tutorial()
	EventBus.tutorial_completed.emit()
	assert_eq(strip.car_height(), 0, "the City's run")
	EventBus.turn_completed.emit(1)
	assert_eq(strip.car_height(), 1)


## docs/ENDGAME.md §5.13, §5.14: the strip shows each road with a finish, with its own areas and
## best run: the Road Home's from the Desert, and --finish's short road, where the road's best run
## is past its finish, at the top. Keep Driving's endless road has none, nor has a HUD with no road.
func test_the_route_strip_shows_only_on_a_road_with_a_finish() -> void:
	var hud := _hud_on_screen()
	var strip := _strip(hud)
	assert_false(strip.visible, "before a run")
	GameState.start_run(1)
	assert_false(strip.visible, "no road")
	SaveService.data().record_run({"road": &"home", "turn_index": 30})
	hud.road = HOME_ROAD
	GameState.quit_to_title()
	GameState.start_run(2, false, true, &"home")
	assert_true(strip.visible, "the Road Home")
	assert_eq(strip.tick_heights(), [0, 16, 24, 42, 66], "the Desert's to the City's")
	assert_eq(strip.best_height(), 30)
	hud.road = ROAD.endless()
	GameState.quit_to_title()
	GameState.start_run(3)
	assert_false(strip.visible, "Keep Driving")
	hud.road = ROAD
	GameState.quit_to_title()
	GameState.start_run(4, false, true, &"pier")
	assert_true(strip.visible, "the road to the sea")
	assert_eq(strip.best_height(), -1, "the Road Home's best run is its own")
	SaveService.data().record_run({"road": &"pier", "turn_index": 40})
	hud.road = ROAD.ending_at(3, &"pier")
	GameState.quit_to_title()
	GameState.start_run(5, false, true, &"pier")
	assert_true(strip.visible, "--finish=3")
	assert_eq(strip.tick_heights(), [0], "the City alone")
	assert_eq(strip.best_height(), 100, "turn 40, past the finish")
	EventBus.turn_completed.emit(3)
	assert_eq(strip.car_height(), 100, "at the finish")
