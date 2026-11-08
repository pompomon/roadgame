extends GutTest
## The grey-box HUD (IMPLEMENTATION_PLAN.md M2.6) on its own: what it shows, and the pause and
## retry input. The integration test checks the Pause button inside the main scene.

const HUD_SCENE := preload("res://ui/hud.tscn")


func after_each() -> void:
	GameState.quit_to_title()


func _hud() -> Hud:
	var hud: Hud = HUD_SCENE.instantiate()
	add_child_autofree(hud)
	return hud


static func _text(hud: Hud, label: String) -> String:
	return hud.get_node("%" + label).text


static func _key(keycode: Key, pressed: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = pressed
	return event


static func _touch(pressed: bool) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.position = Vector2(100.0, 300.0)
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


func test_the_end_of_a_run_shows_why_and_how_to_retry() -> void:
	for cause: StringName in Hud.END_MESSAGES:
		var hud := _hud()
		GameState.start_run(1)
		GameState.end_run(cause)
		assert_eq(_text(hud, "Message"), "%s\n%s" % [Hud.END_MESSAGES[cause], Hud.RETRY_MESSAGE])
		assert_false(hud.get_node("%Pause").visible, "no pausing after the end")
		GameState.quit_to_title()


func test_a_tap_or_enter_retries_only_once_the_game_is_over() -> void:
	var hud := _hud()
	watch_signals(hud)
	GameState.start_run(1)
	var events: Array[InputEvent] = [_touch(true), _key(KEY_ENTER, true)]
	for event: InputEvent in events:
		hud._unhandled_input(event)
	GameState.end_run(CarSim.WRONG_TURN)
	for event: InputEvent in events:
		hud._unhandled_input(event)
	assert_signal_emit_count(hud, "retry_requested", 0, "running, then in the disaster state")
	GameState.show_game_over()
	hud._unhandled_input(_touch(false))
	assert_signal_emit_count(hud, "retry_requested", 0, "a touch release")
	for event: InputEvent in events:
		hud._unhandled_input(event)
	assert_signal_emit_count(hud, "retry_requested", 2)


func test_a_retry_may_take_the_hud_out_of_the_tree() -> void:
	# The main scene's retry reloads the scene, and Godot takes the old one out of the tree at once.
	var hud := _hud()
	hud.retry_requested.connect(func() -> void: hud.get_parent().remove_child(hud))
	GameState.start_run(1)
	GameState.end_run(CarSim.WRONG_TURN)
	GameState.show_game_over()
	hud._unhandled_input(_key(KEY_ENTER, true))
	assert_false(hud.is_inside_tree(), "the retry went ahead")
