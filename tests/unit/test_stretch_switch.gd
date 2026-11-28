extends GutTest

var _saved_mode: Window.ContentScaleMode
var _saved_max_fps := 0


func before_each() -> void:
	_saved_mode = get_tree().root.content_scale_mode
	_saved_max_fps = Engine.max_fps


func after_each() -> void:
	get_tree().root.content_scale_mode = _saved_mode
	Engine.max_fps = _saved_max_fps


func test_named_modes_override_and_other_values_keep_the_project_mode() -> void:
	for project_mode: Window.ContentScaleMode in [
		Window.CONTENT_SCALE_MODE_CANVAS_ITEMS, Window.CONTENT_SCALE_MODE_VIEWPORT
	]:
		assert_eq(
			StretchSwitch.mode("canvas_items", project_mode), Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		)
		assert_eq(StretchSwitch.mode("viewport", project_mode), Window.CONTENT_SCALE_MODE_VIEWPORT)
		for other: String in ["", "unknown", "CANVAS_ITEMS"]:
			assert_eq(StretchSwitch.mode(other, project_mode), project_mode)


func test_main_applies_each_switch_to_the_actual_root() -> void:
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	assert_eq(_main_mode("canvas_items"), Window.CONTENT_SCALE_MODE_CANVAS_ITEMS)
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	assert_eq(_main_mode("viewport"), Window.CONTENT_SCALE_MODE_VIEWPORT)


func test_main_uses_viewport_by_default() -> void:
	assert_eq(_main_mode(""), Window.CONTENT_SCALE_MODE_VIEWPORT)


func _main_mode(value: String) -> Window.ContentScaleMode:
	var main: Node = load("res://ui/main.tscn").instantiate()
	main.args = (
		PackedStringArray() if value.is_empty() else PackedStringArray(["--stretch=" + value])
	)
	add_child(main)
	var selected := get_tree().root.content_scale_mode
	main.free()
	return selected
