extends GutTest

const Disasters := preload("res://tests/helpers/disaster_fixtures.gd")


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
	# font shows as a box. The HUD, the game-over screen and the title's screens (M5.5) also show
	# numbers, the areas' and the disasters' names, the disasters' fates and lore (M6_PLAN.md S8,
	# S12), and messages they keep in constants.
	var main := _main()
	var shown: Array[Control] = []
	shown.append_array(main.find_children("*", "Label", true, false))
	shown.append_array(main.find_children("*", "Button", true, false))
	assert_gt(shown.size(), 8, "labels and buttons")
	var texts: Array[String] = ["-0123456789", Hud.PAUSED_MESSAGE, GameOver.FALLBACK_MESSAGE]
	texts.append_array(GameOver.END_MESSAGES.values())
	texts.append_array([AtlasScreen.UNKNOWN, AtlasScreen.NOT_REACHED, CollectionScreen.NOT_SEEN])
	texts.append_array(SettingsScreen.ORIENTATION_NAMES)
	texts.append(AtlasScreen.best_text({"distance": 1.0, "turns": 1}))
	texts.append(AtlasScreen.area_text(SaveData.ATLAS_ENTRY))
	var schedule: AreaSchedule = load("res://areas/schedule.tres")
	for entry: AreaScheduleEntry in schedule.entries:
		var stats := {"distance": 1.0, "turn_index": 1, "run_seed": 1}
		texts.append(GameOver.stats_text(stats, entry.area))
		for seen: int in [1, 2]:
			var first := {"seen": seen, "first_distance": 1.0, "first_turns": 1}
			texts.append(CollectionScreen.seen_text(first, entry.area))
	for disaster: Dictionary in CollectionScreen.disasters(schedule):
		texts.append_array([disaster["name"], disaster["lore"]])
	for scene: PackedScene in Disasters.scenes():
		texts.append(Disasters.disaster(self, scene, null, null).fate)
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
	main.args = PackedStringArray(["--seed=1", "--play"])
	add_child_autofree(main)
	return main
