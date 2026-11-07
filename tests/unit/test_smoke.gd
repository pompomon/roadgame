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
	for c in label.text.replace("\n", ""):
		if not font.has_char(c.unicode_at(0)):
			missing += c
	assert_eq(missing, "", "characters missing from the default font")


func _main_label() -> Label:
	var scene: PackedScene = load("res://ui/main.tscn")
	var main: Node = scene.instantiate()
	add_child_autofree(main)
	return main.get_node("%Label")
