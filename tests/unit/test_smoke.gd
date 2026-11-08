extends GutTest


func after_each() -> void:
	GameState.quit_to_title()


func test_project_name() -> void:
	assert_eq(ProjectSettings.get_setting("application/config/name"), "Road Roguelike")


func test_main_scene_shows_the_version_and_the_seed() -> void:
	var info: Label = _main().get_node("%HUD/%Info")
	var version: String = ProjectSettings.get_setting("application/config/version")
	assert_eq(info.text, "Road Roguelike %s\nseed 1" % version)


func test_main_scene_text_has_every_glyph_in_the_default_font() -> void:
	# The Web build has no system fonts to fall back on: a glyph missing from the default
	# font shows as a box. The HUD also shows numbers, and messages it keeps in constants.
	var main := _main()
	var shown: Array[Control] = []
	shown.append_array(main.find_children("*", "Label", true, false))
	shown.append_array(main.find_children("*", "Button", true, false))
	assert_gt(shown.size(), 4, "labels and buttons")
	var texts: Array[String] = ["-0123456789", Hud.RETRY_MESSAGE, Hud.PAUSED_MESSAGE]
	texts.append_array(Hud.END_MESSAGES.values())
	var missing := ""
	for control: Control in shown:
		var font := control.get_theme_font("font")
		for text: String in texts + [control.get("text") as String]:
			for c: String in text.replace("\n", ""):
				if not font.has_char(c.unicode_at(0)) and not missing.contains(c):
					missing += c
	assert_eq(missing, "", "characters missing from the default font")


func _main() -> Node:
	var scene: PackedScene = load("res://ui/main.tscn")
	var main: Node = scene.instantiate()
	main.args = PackedStringArray(["--seed=1"])
	add_child_autofree(main)
	return main
