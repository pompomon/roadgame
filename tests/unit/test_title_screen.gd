extends GutTest
## The title screen (plan.md §2.6, IMPLEMENTATION_PLAN.md M5.5) on its own: Play, the best run, and
## the Atlas, the collection and the settings, each left for the title by its Back button or Esc.
## SaveService keeps the save in memory.

const TITLE_SCENE := preload("res://ui/title_screen.tscn")
const MainScene := preload("res://tests/helpers/main_scene.gd")
## Each screen, and the title's button that opens it.
const SCREENS := {
	"Atlas": "AtlasButton", "Collection": "DisastersButton", "Settings": "SettingsButton"
}


func before_each() -> void:
	SaveService.use_memory()


func after_each() -> void:
	SaveService.use_memory()


func _title() -> TitleScreen:
	var view := SubViewport.new()
	view.size = Vector2i(360, 640)
	add_child_autofree(view)
	var title: TitleScreen = TITLE_SCENE.instantiate()
	title.schedule = load("res://areas/schedule.tres")
	view.add_child(title)
	return title


static func _button(title: TitleScreen, name_of: String) -> Button:
	return title.get_node("%" + name_of)


func test_open_shows_the_best_run_and_focuses_play() -> void:
	var title := _title()
	title.open()
	assert_true(title.visible)
	assert_eq((title.get_node("%Best") as Label).text, "", "no run yet")
	assert_true(_button(title, "Play").has_focus())
	SaveService.data().record_run({"distance": 12.34, "turn_index": 2})
	title.open()
	assert_eq((title.get_node("%Best") as Label).text, "Best: 123 m, 2 turns")


func test_each_button_opens_its_screen_and_back_returns_with_its_focus() -> void:
	var title := _title()
	title.open()
	var page: Control = title.get_node("%MainPage")
	for screen_name: String in SCREENS:
		var screen: MenuScreen = title.get_node("%" + screen_name)
		var button := _button(title, SCREENS[screen_name])
		button.pressed.emit()
		assert_true(screen.visible, screen_name)
		assert_false(page.visible, screen_name + ": the title page hides")
		assert_eq(title.open_screen(), screen)
		(screen.get_node("%Back") as Button).pressed.emit()
		assert_false(screen.visible, screen_name + ": Back")
		assert_true(page.visible)
		assert_true(button.has_focus(), screen_name + ": the focus goes back to its button")
	assert_null(title.open_screen())
	assert_false(title.go_back(), "nothing to leave on the title page")


func test_esc_leaves_a_screen_but_not_the_title() -> void:
	var title := _title()
	title.open()
	_button(title, "AtlasButton").pressed.emit()
	var view := title.get_viewport()
	view.push_input(MainScene.key(KEY_ESCAPE, true), true)
	assert_true(view.is_input_handled(), "Esc closed the Atlas")
	view.push_input(MainScene.key(KEY_ESCAPE, false), true)
	assert_null(title.open_screen())
	assert_true(title.visible)
	view.push_input(MainScene.key(KEY_ESCAPE, true), true)
	assert_false(view.is_input_handled(), "Esc on the title page is left to others")
	assert_true(title.visible)


func test_play_asks_to_play_only_from_the_title_page() -> void:
	var title := _title()
	var play := _button(title, "Play")
	watch_signals(title)
	play.pressed.emit()
	assert_signal_not_emitted(title, "play_requested", "the title is hidden")
	title.open()
	_button(title, "SettingsButton").pressed.emit()
	play.pressed.emit()
	assert_signal_not_emitted(title, "play_requested", "a screen is open")
	title.go_back()
	play.grab_focus()
	title.get_viewport().push_input(MainScene.key(KEY_ENTER, true), true)
	title.get_viewport().push_input(MainScene.key(KEY_ENTER, false), true)
	assert_signal_emit_count(title, "play_requested", 1, "Enter pressed Play")


func test_close_closes_the_open_screen() -> void:
	var title := _title()
	title.open()
	_button(title, "AtlasButton").pressed.emit()
	title.close()
	assert_false(title.visible)
	assert_false((title.get_node("%Atlas") as Control).visible)
	title.open()
	assert_true((title.get_node("%MainPage") as Control).visible)
	assert_null(title.open_screen())


func test_the_start_button_shows_in_debug_builds_only() -> void:
	# ZONE_SELECT_PLAN.md Z4: GUT runs a debug build, so the release default is a device check.
	var title := _title()
	assert_eq(title.area_choice, OS.is_debug_build())
	var start := _button(title, "StartArea")
	for choice: bool in [true, false]:
		title.area_choice = choice
		title.open()
		assert_eq(start.visible, choice)
		assert_eq(start.text, "Start in: City", "the schedule's first area")
		assert_true(_button(title, "Play").has_focus())


func test_the_start_button_steps_through_the_areas_and_open_keeps_the_last() -> void:
	var title := _title()
	title.area_choice = true
	title.open()
	var start := _button(title, "StartArea")
	watch_signals(title)
	var texts: Array[String] = []
	for _press: int in 6:
		start.pressed.emit()
		texts.append(start.text)
	assert_eq(
		texts,
		[
			"Start in: Rural",
			"Start in: Meadows",
			"Start in: Village",
			"Start in: Desert",
			"Start in: City",
			"Start in: Rural",
		]
	)
	assert_eq(title.start_area.id, &"rural")
	assert_signal_not_emitted(title, "play_requested")
	title.close()
	title.open()
	assert_eq(start.text, "Start in: Rural")
	title.start_area = AreaDef.new()
	title.open()
	assert_eq(title.start_area.id, &"city", "an area the schedule lacks: its first")


func test_the_title_page_fits_a_portrait_screen_with_each_start_area() -> void:
	# The Start button keeps its width as it steps, so that each tap lands on it (Z9).
	SaveService.data().record_run({"distance": 9999.9, "turn_index": 999})
	var title := _title()
	title.area_choice = true
	var bounds := Rect2(Vector2.ZERO, Vector2(title.get_viewport().size))
	var start := _button(title, "StartArea")
	var widths: Array[float] = []
	for area: AreaDef in title.schedule.areas():
		title.start_area = area
		title.open()
		await wait_process_frames(2)
		for control: Control in title.find_children("*", "Control", true, false):
			if control.is_visible_in_tree():
				var rect := control.get_global_rect()
				assert_true(bounds.encloses(rect), "%s: %s at %s" % [area.id, control.name, rect])
		assert_eq(start.size.x, start.custom_minimum_size.x, "%s: no text widens it" % area.id)
		widths.append(start.size.x)
	assert_eq(widths.count(widths[0]), widths.size(), "one width for each area: %s" % [widths])


func test_every_screen_fits_a_portrait_screen_with_the_longest_texts() -> void:
	# 360 x 640 is the smallest the game's window shows (project.godot's stretch settings). Every
	# disaster of the pools is seen, so that each card shows its lore (M6_PLAN.md S15).
	var data := SaveService.data()
	var areas := {}
	for id: StringName in [&"city", &"rural", &"meadows", &"village", &"desert"]:
		areas[id] = {"distance": 9999.9, "turns": 999}
	data.record_run({"areas": areas, "distance": 9999.9, "turn_index": 999})
	var title := _title()
	for disaster: Dictionary in CollectionScreen.disasters(title.schedule):
		for _seen: int in 5:
			data.record_disaster(
				disaster["id"], &"meadows", {"distance": 9999.9, "turn_index": 999}
			)
	title.open()
	var bounds := Rect2(Vector2.ZERO, Vector2(title.get_viewport().size))
	# The collection's cards may run below the screen, as its scroll scrolls to them (S16).
	var cards: Control = title.get_node("%Collection/%Cards")
	var scroll: ScrollContainer = cards.get_parent()
	for button: String in ["", "AtlasButton", "DisastersButton", "SettingsButton"]:
		if button != "":
			_button(title, button).pressed.emit()
		await wait_process_frames(2)
		for control: Control in title.find_children("*", "Control", true, false):
			if control.is_visible_in_tree():
				var rect := control.get_global_rect()
				var fits := bounds.encloses(rect)
				if scroll.is_ancestor_of(control):
					fits = rect.position.x >= bounds.position.x and rect.end.x <= bounds.end.x
				assert_true(fits, "%s: %s at %s" % [button, control.name, rect])
		title.go_back()
	_button(title, "DisastersButton").pressed.emit()
	await wait_process_frames(2)
	var last: Control = cards.get_child(cards.get_child_count() - 1)
	scroll.ensure_control_visible(last)
	await wait_process_frames(2)
	assert_true(
		scroll.get_global_rect().encloses(last.get_global_rect()), "the last card scrolls in"
	)
