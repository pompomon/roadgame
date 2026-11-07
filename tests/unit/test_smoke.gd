extends GutTest


func test_project_name() -> void:
	assert_eq(ProjectSettings.get_setting("application/config/name"), "Road Roguelike")


func test_main_scene_shows_version() -> void:
	assert_string_contains(_main_label().text, "Road Roguelike")


func test_main_scene_text_has_every_glyph_in_the_default_font() -> void:
	# The Web build has no system fonts to fall back on: a glyph missing from the default
	# font shows as a box.
	var label := _main_label()
	var font := label.get_theme_font("font")
	var missing := ""
	for c: String in label.text.replace("\n", ""):
		if not font.has_char(c.unicode_at(0)):
			missing += c
	assert_eq(missing, "", "characters missing from the default font")


func test_fast_forward_lasts_while_any_touch_or_the_mouse_button_is_held() -> void:
	var main := _main()
	assert_false(main.is_fast_forwarding())
	var events: Array[InputEvent] = [
		_touch(0, true), _touch(1, true), _touch(1, false), _mouse(true), _mouse(false)
	]
	for event: InputEvent in events:
		main._unhandled_input(event)
	assert_true(main.is_fast_forwarding(), "touch 0 is still down")
	main._unhandled_input(_touch(0, false))
	assert_false(main.is_fast_forwarding())


func _main() -> Node:
	var scene: PackedScene = load("res://ui/main.tscn")
	var main: Node = scene.instantiate()
	add_child_autofree(main)
	return main


func _main_label() -> Label:
	return _main().get_node("%Label")


static func _touch(index: int, pressed: bool) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.pressed = pressed
	return event


static func _mouse(pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	return event
