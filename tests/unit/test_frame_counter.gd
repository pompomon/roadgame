extends GutTest

const COUNTER_SCENE := preload("res://ui/frame_counter.tscn")
const HUD_SCENE := preload("res://ui/hud.tscn")
const SETTINGS_SCENE := preload("res://ui/settings_screen.tscn")
const CITY := preload("res://areas/city.tres")


class RecordingCounter:
	extends FrameCounter
	var lines: Array[String] = []

	func _print_line(line: String) -> void:
		lines.append(line)


func before_each() -> void:
	SaveService.use_memory()
	GameState.quit_to_title()


func after_each() -> void:
	GameState.quit_to_title()
	SaveService.use_memory()


func _counter(forced := false) -> RecordingCounter:
	var view := SubViewport.new()
	view.size = Vector2i(360, 640)
	add_child_autofree(view)
	var node := COUNTER_SCENE.instantiate()
	node.set_script(RecordingCounter)
	var counter := node as RecordingCounter
	view.add_child(counter)
	counter.configure(forced)
	counter.set_process(false)
	return counter


func test_the_setting_shows_it_and_hiding_starts_a_fresh_window() -> void:
	var counter := _counter()
	assert_false(counter.visible)
	assert_false(counter.is_processing())
	SaveService.set_setting("fps", true)
	assert_true(counter.visible)
	assert_true(counter.is_processing())
	counter.set_process(false)
	counter._sample_frame(500000)
	SaveService.set_setting("fps", false)
	assert_false(counter.visible)
	assert_false(counter.is_processing())
	SaveService.set_setting("fps", true)
	counter.set_process(false)
	counter._sample_frame(500000)
	assert_eq((counter.get_node("%Label") as Label).text, "0.0 FPS\nP95 0 MS")
	assert_eq(counter.lines, [] as Array[String])


func test_the_switch_forces_it_on_and_reports_the_actual_window() -> void:
	var counter := _counter(true)
	assert_true(counter.visible)
	SaveService.set_setting("fps", true)
	SaveService.set_setting("fps", false)
	assert_true(counter.visible)
	counter.set_process(false)
	for index: int in 50:
		counter._sample_frame(20004)
	assert_eq(counter.lines.size(), 1)
	assert_true(
		counter.lines[0].begins_with(
			"PERF fps=49.9 n=50 us=1000200 med=20.0 p95=21 max=20.0 early=0 draws="
		)
	)


func test_only_the_switch_prints_events_with_the_frames_drawn() -> void:
	var counter := _counter(true)
	EventBus.area_changed.emit(CITY)
	EventBus.disaster_started.emit(&"grim_reaper", CITY)
	GameState.start_run(1)
	GameState.end_run(CarSim.MISSED_TURN)
	GameState.show_game_over()
	counter._process(0.0)
	counter._process(0.0)
	var frames := Engine.get_frames_drawn()
	assert_eq(
		counter.lines,
		(
			[
				"EVENT area city frames=%d" % frames,
				"EVENT disaster_started grim_reaper frames=%d" % frames,
				"EVENT run_ended missed_turn frames=%d" % frames,
				"EVENT game_over frames=%d" % frames,
			]
			as Array[String]
		)
	)


func test_the_setting_alone_prints_nothing() -> void:
	SaveService.set_setting("fps", true)
	var counter := _counter()
	for index: int in 50:
		counter._sample_frame(20004)
	EventBus.area_changed.emit(CITY)
	EventBus.disaster_started.emit(&"grim_reaper", CITY)
	EventBus.run_ended.emit(CarSim.MISSED_TURN, {})
	assert_eq(counter.lines, [] as Array[String])


func test_it_counts_while_paused_and_ignores_the_mouse() -> void:
	var counter := _counter(true)
	assert_eq(counter.process_mode, Node.PROCESS_MODE_ALWAYS)
	GameState.start_run(1)
	GameState.pause()
	counter.set_process(true)
	await wait_process_frames(2)
	assert_gt(counter._last_usec, 0)
	for control: Control in counter.find_children("*", "Control", true, false):
		assert_eq(control.mouse_filter, Control.MOUSE_FILTER_IGNORE, control.name)


func test_the_longest_text_avoids_the_hud_and_settings_back() -> void:
	var counter := _counter(true)
	var view := counter.get_viewport()
	var hud: Hud = HUD_SCENE.instantiate()
	var settings: SettingsScreen = SETTINGS_SCENE.instantiate()
	view.add_child(hud)
	view.add_child(settings)
	settings.open()
	counter._sample_frame(86400000000)
	await wait_process_frames(2)
	var label: Label = counter.get_node("%Label")
	assert_eq(label.text, "0.0 FPS\nP95 999 MS")
	assert_false(
		label.get_global_rect().intersects((hud.get_node("%Info") as Control).get_global_rect())
	)
	assert_false(
		label.get_global_rect().intersects(
			(hud.get_node("%RouteStrip") as Control).get_global_rect()
		)
	)
	assert_false(
		label.get_global_rect().intersects(
			(settings.get_node("%Back") as Control).get_global_rect()
		)
	)
	assert_true(Rect2(Vector2.ZERO, Vector2(360, 640)).encloses(label.get_global_rect()))


func test_the_text_has_every_digit_and_only_the_fonts_glyphs() -> void:
	var counter := _counter()
	var font := (counter.get_node("%Label") as Label).get_theme_font("font")
	var stats := FrameStats.new()
	stats.add(86400000000)
	for c: String in (FrameCounter.text(stats) + "0123456789").replace("\n", ""):
		assert_true(font.has_char(c.unicode_at(0)), "'%s'" % c)


func test_text_and_reports_never_round_a_failed_bound_into_a_pass() -> void:
	var cases: Array[Array] = [
		[50, 1000000, "50.0"],
		[55, 1100000, "50.0"],
		[50, 1000200, "49.9"],
		[59, 1000000, "59.0"],
		[59, 1000001, "58.9"],
		[60, 1000000, "60.0"],
		[61, 1000000, "61.0"],
		[61, 999999, "61.1"],
	]
	for reading: Array in cases:
		var stats := FrameStats.new()
		var count: int = reading[0]
		var total: int = reading[1]
		@warning_ignore("integer_division")
		var interval := total / count
		for index: int in count:
			stats.add(interval if index < count - 1 else total - interval * (count - 1))
		assert_true(FrameCounter.text(stats).begins_with("%s FPS\n" % reading[2]), str(reading))
		assert_true(
			FrameCounter.report(stats, 0).begins_with("PERF fps=%s " % reading[2]), str(reading)
		)
	for interval: int in [25000, 25001]:
		var stats := FrameStats.new()
		stats.add(interval)
		var expected := 25 if interval == 25000 else 26
		assert_true(FrameCounter.text(stats).ends_with("P95 %d MS" % expected))
		assert_true(FrameCounter.report(stats, 0).contains(" p95=%d " % expected))
