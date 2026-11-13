extends GutTest
## The grey-box HUD (IMPLEMENTATION_PLAN.md M2.6, M3.3) on its own: what it shows, the pause input,
## and the fresh start of each run. The integration test checks the Pause button inside the main
## scene, and the game-over screen has its own test.

const HUD_SCENE := preload("res://ui/hud.tscn")
const DELTA := 1.0 / 60.0
## The frames that add up to AREA_BANNER_SECONDS. Sums of 1/60 can fall short, so the name may stay
## a frame longer.
const BANNER_FRAMES := roundi(Tuning.AREA_BANNER_SECONDS / DELTA)


func after_each() -> void:
	GameState.quit_to_title()


func _hud() -> Hud:
	var hud: Hud = HUD_SCENE.instantiate()
	add_child_autofree(hud)
	return hud


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


func test_off_the_road_a_meter_under_the_health_shows_the_room_left() -> void:
	# The off-road limit ends a run as the health does, so the HUD shows both (HEALTH_BAR_PLAN.md
	# B1, E1). The meter hides by its alpha, so that the health bar above it never moves.
	var hud := _hud()
	var health: ProgressBar = hud.get_node("%Health")
	var meter: ProgressBar = hud.get_node("%Offroad")
	var red := (health.get_theme_stylebox("fill") as StyleBoxFlat).bg_color
	assert_ne((meter.get_theme_stylebox("fill") as StyleBoxFlat).bg_color, red, "not the health")
	GameState.start_run(1)
	assert_eq(meter.modulate.a, 0.0, "hidden on the road")
	assert_true(meter.visible, "but in its place")
	EventBus.car_offroad_changed.emit(true)
	assert_eq(meter.modulate.a, 1.0, "shown off the road")
	assert_eq(meter.value, meter.max_value, "full")
	EventBus.car_offroad_room_changed.emit(0.25)
	assert_eq(meter.value, 0.25)
	EventBus.car_offroad_changed.emit(false)
	assert_eq(meter.modulate.a, 0.0, "hidden back on the road")
	EventBus.car_offroad_changed.emit(true)
	assert_eq(meter.value, meter.max_value, "full again for the next time")


func test_the_meter_sits_under_the_health_bar_and_never_moves_it() -> void:
	# Hidden by `visible`, the meter would leave the health bar to be centred anew each time (E1).
	var hud := _hud()
	var health: ProgressBar = hud.get_node("%Health")
	var meter: ProgressBar = hud.get_node("%Offroad")
	GameState.start_run(1)
	await wait_process_frames(1)
	var bar := health.get_global_rect()
	assert_gt(meter.get_global_rect().position.y, bar.end.y, "under the health bar")
	assert_eq(meter.get_global_rect().size.x, bar.size.x, "as wide")
	EventBus.car_offroad_changed.emit(true)
	await wait_process_frames(1)
	assert_eq(health.get_global_rect(), bar, "shown, the meter moves nothing")
	EventBus.car_offroad_changed.emit(false)
	await wait_process_frames(1)
	assert_eq(health.get_global_rect(), bar, "nor hidden")


func test_a_run_that_ends_off_the_road_leaves_the_meter_as_it_was() -> void:
	# With the game-over screen, it shows why a car with health left was lost (E3).
	var hud := _hud()
	var meter: ProgressBar = hud.get_node("%Offroad")
	GameState.start_run(1)
	EventBus.car_offroad_changed.emit(true)
	EventBus.car_offroad_room_changed.emit(0.0)
	GameState.end_run(CarSim.OFFROAD)
	GameState.show_game_over()
	assert_eq(meter.modulate.a, 1.0, "shown")
	assert_eq(meter.value, 0.0, "empty")


func test_each_run_starts_the_hud_afresh() -> void:
	# A retry starts the next run without reloading the HUD (M3_PLAN.md J10).
	var hud := _hud()
	GameState.start_run(1)
	EventBus.turn_completed.emit(5)
	EventBus.health_changed.emit(10.0)
	EventBus.car_offroad_changed.emit(true)
	EventBus.car_offroad_room_changed.emit(0.0)
	GameState.end_run(CarSim.HEALTH)
	GameState.show_game_over()
	GameState.start_run(2)
	var version: String = ProjectSettings.get_setting("application/config/version")
	assert_eq(_text(hud, "Turns"), "turns 0")
	assert_eq((hud.get_node("%Health") as ProgressBar).value, Tuning.START_HEALTH)
	var meter: ProgressBar = hud.get_node("%Offroad")
	assert_eq(meter.modulate.a, 0.0, "the car starts on the road")
	assert_eq(meter.value, meter.max_value)
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
