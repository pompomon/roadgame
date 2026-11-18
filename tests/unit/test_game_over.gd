extends GutTest
## The game-over screen (plan.md §2.1, IMPLEMENTATION_PLAN.md M3.3) on its own: why the run ended,
## the disaster's fate (docs/M6.md S8), its stats, the seed, Retry, and Title (M5.5); NEW LEGEND!
## and the next goal (ENDGAME_PLAN.md §5.9). It runs in a SubViewport, so that Retry can take the
## focus.

const GAME_OVER_SCENE := preload("res://ui/game_over.tscn")
const Fixtures := preload("res://tests/helpers/road_fixtures.gd")
## The SubViewport's, the game's portrait view.
const VIEW := Rect2(0, 0, 360, 640)


func _game_over() -> GameOver:
	var view := SubViewport.new()
	view.size = Vector2i(VIEW.size)
	add_child_autofree(view)
	var game_over: GameOver = GAME_OVER_SCENE.instantiate()
	view.add_child(game_over)
	return game_over


## Stats as GameState.stats() gives them.
static func _stats(cause: StringName) -> Dictionary:
	return {
		"run_seed": 1234,
		"turn_index": 7,
		"distance": 12.34,
		"seconds": 512.9,
		"clean": true,
		"area_id": &"rural",
		"cause": cause,
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
		CarSim.WRONG_TURN, CarSim.MISSED_TURN, CarSim.HEALTH, CarSim.OFFROAD, CarSim.ARRIVAL
	]
	assert_eq(GameOver.END_MESSAGES.size(), causes.size(), "a message for each of CarSim's causes")
	var game_over := _game_over()
	for cause: StringName in causes:
		game_over.open(_stats(cause), _rural())
		assert_eq(_text(game_over, "Cause"), GameOver.END_MESSAGES[cause])
		var stats := "Distance: 123 m\nTurns: 7\nArea reached: Rural"
		if cause == CarSim.ARRIVAL:
			stats += "\nTime: 8:32"
		assert_eq(_text(game_over, "Stats"), stats, cause)
		game_over.close()


## ENDGAME_PLAN.md §5.3: an arrival's time, in whole minutes and seconds.
func test_the_time_is_in_minutes_and_seconds() -> void:
	var times := {0.0: "0:00", 59.99: "0:59", 60.0: "1:00", 512.9: "8:32", 3725.0: "62:05"}
	for seconds: float in times:
		assert_eq(GameOver.time_text(seconds), times[seconds], str(seconds))


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


## ENDGAME_PLAN.md §5.9 (Q16): NEW LEGEND!, above the fate, in large letters that stay still, as its
## jingle's signal goes out once. With every line the screen may show, it all fits the view. A run
## with no new legend shows neither.
func test_a_first_sighting_or_an_unlock_shows_new_legend() -> void:
	var game_over := _game_over()
	game_over.show_seed = true
	var news: Label = game_over.get_node("%NewLegend")
	assert_eq(news.get_parent(), game_over.get_node("%Cause").get_parent())
	assert_eq(news.get_index(), 0, "above the cause and the fate")
	assert_false(news.visible)
	watch_signals(EventBus)
	var fate := LegendUnlock.UNLOCKED % "Headless Horseman"
	game_over.open(_stats(CarSim.ARRIVAL), _rural(), fate, true, GameOver.GOAL_CLEAN)
	assert_true(news.visible)
	assert_eq(news.text, "NEW LEGEND!")
	assert_signal_emit_count(EventBus, "new_legend_shown", 1)
	await wait_process_frames(2)
	var still := [news.global_position, news.scale, news.modulate, news.self_modulate, news.visible]
	await wait_process_frames(30)
	assert_eq(
		[news.global_position, news.scale, news.modulate, news.self_modulate, news.visible],
		still,
		"it stays still"
	)
	assert_gt((game_over.get_node("%Fate") as Label).get_line_count(), 1, "a fate of two lines")
	for control: Control in game_over.get_node("%Cause").get_parent().get_children():
		assert_true(control.visible, control.name)
		assert_true(VIEW.encloses(control.get_global_rect()), "%s in the view" % control.name)
	game_over.close()
	game_over.open(_stats(CarSim.WRONG_TURN), _rural(), "A ghost took you.")
	assert_false(news.visible, "no new legend")
	assert_signal_emit_count(EventBus, "new_legend_shown", 1, "and no jingle")


## ENDGAME_PLAN.md §5.9: the first goal that holds, from the player's progress alone: the sea, with
## the best turn; the legends still missing; a clean arrival; the best time.
func test_the_next_goal_follows_the_players_progress() -> void:
	var schedule := Fixtures.schedule()
	assert_eq(schedule.finish, GameOver.SEA, "the game's road ends at the sea")
	var turns := schedule.finish_turn
	var data := SaveData.new()
	assert_eq(GameOver.next_goal(data, schedule), GameOver.GOAL_SEA % [0, turns], "a new save")
	data.record_run({"turn_index": 212, "distance": 900.0})
	assert_eq(GameOver.next_goal(data, schedule), GameOver.GOAL_SEA % [212, turns])
	data.record_arrival(&"home", {"seconds": 400.0, "clean": true})
	assert_eq(GameOver.next_goal(data, schedule), GameOver.GOAL_SEA % [212, turns], "home isn't")
	data.record_arrival(GameOver.SEA, {"seconds": 581.0, "clean": false})
	var none: Array[StringName] = []
	var legends := LegendUnlock.locked(schedule, none)
	assert_gt(legends.size(), 2)
	var missing := GameOver.GOAL_LEGENDS % legends.size()
	assert_eq(GameOver.next_goal(data, schedule), missing, "arrived")
	data.record_disaster(legends[0], &"city", {})
	for id: StringName in legends.slice(1, legends.size() - 2):
		data.unlock_disaster(id)
	assert_eq(GameOver.next_goal(data, schedule), GameOver.GOAL_LEGENDS % 2, "seen or unlocked")
	data.unlock_disaster(legends[-2])
	assert_eq(GameOver.next_goal(data, schedule), GameOver.GOAL_LAST_LEGEND)
	data.record_disaster(legends[-1], &"desert", {})
	assert_eq(GameOver.next_goal(data, schedule), GameOver.GOAL_CLEAN, "every legend found")
	data.record_arrival(GameOver.SEA, {"seconds": 600.0, "clean": true})
	assert_eq(GameOver.next_goal(data, schedule), GameOver.GOAL_TIME % "9:41", "the best time")
	# A save from before the road had an end may hold a best past it.
	var endless := SaveData.new()
	endless.record_run({"turn_index": turns + 50})
	assert_eq(GameOver.next_goal(endless, schedule), GameOver.GOAL_SEA % [turns, turns])


## ENDGAME_PLAN.md §5.9: each goal, with the largest numbers it may show, is one line of the font's
## glyphs that fits the view.
func test_the_next_goal_is_one_line_of_the_fonts_glyphs() -> void:
	var game_over := _game_over()
	var goal: Label = game_over.get_node("%Goal")
	var font := goal.get_theme_font("font")
	var schedule := Fixtures.schedule()
	var none: Array[StringName] = []
	var lines: Array[String] = [
		GameOver.GOAL_SEA % [schedule.finish_turn, schedule.finish_turn],
		GameOver.GOAL_LEGENDS % LegendUnlock.locked(schedule, none).size(),
		GameOver.GOAL_LAST_LEGEND,
		GameOver.GOAL_CLEAN,
		GameOver.GOAL_TIME % GameOver.time_text(5999.0),
	]
	for line: String in lines:
		for c: String in line:
			assert_true(font.has_char(c.unicode_at(0)), "%s: '%s'" % [line, c])
		game_over.open(_stats(CarSim.ARRIVAL), _rural(), "", true, line)
		await wait_process_frames(2)
		assert_true(goal.visible, line)
		assert_eq(goal.text, line)
		assert_eq(goal.get_line_count(), 1, line)
		assert_true(VIEW.encloses(goal.get_global_rect()), "%s: in the view" % line)
		game_over.close()
	game_over.open(_stats(CarSim.WRONG_TURN), _rural())
	assert_false(goal.visible, "no goal, no line")
