extends GutTest
## The game-over screen (plan.md §2.1, IMPLEMENTATION_PLAN.md M3.3) on its own: why the run ended,
## the disaster's fate (docs/M6.md S8), its stats, the seed, Retry, and Title (M5.5). It runs in a
## SubViewport, so that Retry can take the focus.

const GAME_OVER_SCENE := preload("res://ui/game_over.tscn")


func _game_over() -> GameOver:
	var view := SubViewport.new()
	view.size = Vector2i(360, 640)
	add_child_autofree(view)
	var game_over: GameOver = GAME_OVER_SCENE.instantiate()
	view.add_child(game_over)
	return game_over


## Stats as GameState.stats() gives them.
static func _stats(cause: StringName) -> Dictionary:
	return {
		"run_seed": 1234, "turn_index": 7, "distance": 12.34, "area_id": &"rural", "cause": cause
	}


static func _rural() -> AreaDef:
	return load("res://areas/rural.tres")


static func _text(game_over: GameOver, label: String) -> String:
	return (game_over.get_node("%" + label) as Label).text


static func _key(keycode: Key, pressed: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = pressed
	return event


func test_it_is_hidden_until_it_opens() -> void:
	var game_over := _game_over()
	assert_false(game_over.visible)
	game_over.open(_stats(CarSim.WRONG_TURN), _rural())
	assert_true(game_over.visible)


func test_it_shows_why_the_run_ended_and_its_stats() -> void:
	var causes: Array[StringName] = [
		CarSim.WRONG_TURN, CarSim.MISSED_TURN, CarSim.HEALTH, CarSim.OFFROAD
	]
	assert_eq(GameOver.END_MESSAGES.size(), causes.size(), "a message for each of CarSim's causes")
	var game_over := _game_over()
	for cause: StringName in causes:
		game_over.open(_stats(cause), _rural())
		assert_eq(_text(game_over, "Cause"), GameOver.END_MESSAGES[cause])
		assert_eq(_text(game_over, "Stats"), "Distance: 123 m\nTurns: 7\nArea reached: Rural")
		game_over.close()


func test_a_cause_with_no_message_is_an_error_and_shows_game_over() -> void:
	var game_over := _game_over()
	game_over.open(_stats(&"meteor"), _rural())
	assert_push_error("no message for the cause 'meteor'")
	assert_eq(_text(game_over, "Cause"), GameOver.FALLBACK_MESSAGE)
	assert_true(game_over.visible)


func test_the_seed_shows_in_debug_builds_only() -> void:
	var game_over := _game_over()
	assert_eq(game_over.show_seed, OS.is_debug_build())
	var seed_label: Label = game_over.get_node("%Seed")
	for show: bool in [true, false]:
		game_over.show_seed = show
		game_over.open(_stats(CarSim.WRONG_TURN), _rural())
		assert_eq(seed_label.visible, show)
		assert_eq(seed_label.text, "seed 1234")
		game_over.close()


func test_retry_takes_the_focus_and_enter_or_space_presses_it() -> void:
	var game_over := _game_over()
	var retry: Button = game_over.get_node("%Retry")
	for keycode: Key in [KEY_ENTER, KEY_SPACE]:
		var why := OS.get_keycode_string(keycode)
		game_over.open(_stats(CarSim.WRONG_TURN), _rural())
		assert_true(retry.has_focus(), why + ": focus")
		clear_signal_watcher()
		watch_signals(game_over)
		game_over.get_viewport().push_input(_key(keycode, true), true)
		assert_signal_not_emitted(game_over, "retry_requested", why + ": on the release")
		game_over.get_viewport().push_input(_key(keycode, false), true)
		assert_signal_emit_count(game_over, "retry_requested", 1, why)
		game_over.close()


func test_close_drops_the_focus_and_retry_does_nothing_while_closed() -> void:
	var game_over := _game_over()
	var retry: Button = game_over.get_node("%Retry")
	watch_signals(game_over)
	retry.pressed.emit()
	game_over.open(_stats(CarSim.WRONG_TURN), _rural())
	game_over.close()
	assert_false(game_over.visible)
	assert_false(retry.has_focus(), "the arrow keys go back to the game")
	retry.pressed.emit()
	assert_signal_not_emitted(game_over, "retry_requested")


func test_title_asks_for_the_title_screen_only_while_open() -> void:
	var game_over := _game_over()
	var title: Button = game_over.get_node("%Title")
	watch_signals(game_over)
	title.pressed.emit()
	assert_signal_not_emitted(game_over, "title_requested", "closed")
	game_over.open(_stats(CarSim.WRONG_TURN), _rural())
	title.pressed.emit()
	assert_signal_emit_count(game_over, "title_requested", 1)
	assert_signal_not_emitted(game_over, "retry_requested")


func test_it_shows_the_fate_of_the_disaster_that_ended_the_run_under_the_cause() -> void:
	# docs/M6.md S8: what the disaster did to the car, from DisasterBase.fate.
	var game_over := _game_over()
	var fate: Label = game_over.get_node("%Fate")
	var cause: Label = game_over.get_node("%Cause")
	assert_eq(fate.get_parent(), cause.get_parent())
	assert_eq(fate.get_index(), cause.get_index() + 1, "under the cause")
	game_over.open(_stats(CarSim.WRONG_TURN), _rural(), "A ghost took you.")
	assert_true(fate.visible)
	assert_eq(fate.text, "A ghost took you.")
	game_over.close()
	game_over.open(_stats(CarSim.OFFROAD), _rural())
	assert_false(fate.visible, "no fate after a crash")
	assert_eq(fate.text, "")
