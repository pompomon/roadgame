extends GutTest
## The UI's theme and pixel font (plan.md §5.3, M5_PLAN.md §5.8).

const Art := preload("res://tests/helpers/art_checks.gd")
const TITLE_SCENE := preload("res://ui/title_screen.tscn")
## Pixel Operator 8 draws its glyphs on a grid of 8 pixels a font size of 8: a size that isn't a
## multiple of it blurs or bunches them.
const FONT_GRID := 8


func after_each() -> void:
	GameState.quit_to_title()


func _theme() -> Theme:
	return load(ProjectSettings.get_setting("gui/theme/custom"))


func test_the_project_theme_loads_without_an_import() -> void:
	# Godot loads the project theme before it imports anything, so on a fresh checkout an imported
	# font isn't there yet and the import fails (M5_PLAN.md L17).
	var path: String = ProjectSettings.get_setting("gui/theme/custom")
	assert_eq(path.get_extension(), "tres")
	var dependencies := ResourceLoader.get_dependencies(path)
	assert_gt(dependencies.size(), 0)
	for dependency: String in dependencies:
		var file := dependency.get_slice("::", dependency.get_slice_count("::") - 1)
		assert_eq(file.get_extension(), "tres", "%s loads unimported" % file)


func test_the_font_draws_crisp_pixels() -> void:
	var font := _theme().default_font as FontFile
	assert_not_null(font)
	assert_eq(font.antialiasing, TextServer.FONT_ANTIALIASING_NONE)
	assert_eq(font.hinting, TextServer.HINTING_NONE)
	assert_eq(font.subpixel_positioning, TextServer.SUBPIXEL_POSITIONING_DISABLED)
	assert_false(font.allow_system_fallback, "no system fonts on the Web")
	assert_eq(_theme().default_font_size % FONT_GRID, 0)


func test_every_text_is_on_the_fonts_grid() -> void:
	var main: Node = load("res://ui/main.tscn").instantiate()
	main.args = PackedStringArray(["--seed=1", "--play"])
	add_child_autofree(main)
	var title: Node = add_child_autofree(TITLE_SCENE.instantiate())
	var shown: Array[Node] = []
	for root: Node in [main, title]:
		shown.append_array(root.find_children("*", "Label", true, false))
		shown.append_array(root.find_children("*", "Button", true, false))
	assert_gt(shown.size(), 20, "labels and buttons")
	for control: Control in shown:
		var size := control.get_theme_font_size("font_size")
		assert_eq(size % FONT_GRID, 0, "%s: %d" % [control.get_path(), size])


func test_the_themes_colours_are_the_palettes() -> void:
	var theme := _theme()
	var colors: Array[Color] = []
	for type: String in theme.get_color_type_list():
		for color_name: String in theme.get_color_list(type):
			colors.append(theme.get_color(color_name, type))
	for type: String in theme.get_stylebox_type_list():
		for style_name: String in theme.get_stylebox_list(type):
			var flat := theme.get_stylebox(style_name, type) as StyleBoxFlat
			if flat == null:
				continue
			if flat.draw_center:
				colors.append(flat.bg_color)
			var border := Vector4i(
				flat.border_width_left,
				flat.border_width_top,
				flat.border_width_right,
				flat.border_width_bottom
			)
			if border != Vector4i.ZERO:
				colors.append(flat.border_color)
	assert_gt(colors.size(), 10)
	var palette := Art.palette()
	for color: Color in colors:
		assert_has(palette, Color(color, 1.0), "%s" % color)
