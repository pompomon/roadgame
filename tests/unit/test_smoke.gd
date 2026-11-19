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
	# numbers, the areas' and the disasters' names, the disasters' fates and lore (docs/M6.md S8,
	# S12), the Book's initials of the names (ENDGAME_PLAN.md §5.10), the Vanishing Hitchhiker's
	# words (§5.17), the title's start area in debug builds (docs/ZONE_SELECT.md Z8) and its road
	# (ENDGAME_PLAN.md §5.12), the arrival's line when the pools are full (§5.5), and messages they
	# keep in constants.
	var main := _main()
	var shown: Array[Control] = []
	shown.append_array(main.find_children("*", "Label", true, false))
	shown.append_array(main.find_children("*", "Button", true, false))
	assert_gt(shown.size(), 8, "labels and buttons")
	var texts: Array[String] = ["-0123456789", Hud.PAUSED_MESSAGE, GameOver.FALLBACK_MESSAGE]
	# The tutorial's (docs/TUTORIAL.md §5.4).
	texts.append(Hud.TUTORIAL_BANNER % Tuning.TUTORIAL_STREAK)
	texts.append(Hud.STREAK_TEXT % [Tuning.TUTORIAL_STREAK, Tuning.TUTORIAL_STREAK])
	texts.append_array(GameOver.END_MESSAGES.values())
	texts.append_array([AtlasScreen.UNKNOWN, AtlasScreen.NOT_REACHED])
	texts.append_array([BookScreen.NOT_SEEN, BookScreen.UNLOCKED])
	texts.append_array(SettingsScreen.ORIENTATION_NAMES)
	texts.append(AtlasScreen.best_text({"distance": 1.0, "turns": 1}))
	texts.append(AtlasScreen.area_text(SaveData.ATLAS_ENTRY))
	for road: String in TitleScreen.ROAD_NAMES.values():
		texts.append(TitleScreen.ROAD_TEXT % road)
	var schedule: AreaSchedule = load("res://areas/schedule.tres")
	for entry: AreaScheduleEntry in schedule.entries:
		var stats := {"distance": 1.0, "turn_index": 1, "run_seed": 1}
		texts.append(GameOver.stats_text(stats, entry.area))
		texts.append(TitleScreen.START_TEXT % entry.area.display_name)
		for seen: int in [1, 2]:
			var first := {"seen": seen, "first_distance": 1.0, "first_turns": 1}
			texts.append(BookScreen.seen_text(first, entry.area))
	var legends := BookScreen.disasters(schedule)
	texts.append(BookScreen.HEADING % [legends.size(), legends.size()])
	var hitchhiker: Hitchhiker = autofree(BookScreen.HITCHHIKER_SCENE.instantiate())
	legends.append({"name": hitchhiker.display_name, "fate": "", "lore": hitchhiker.lore})
	for legend: Dictionary in legends:
		var display: String = legend["name"]
		texts.append_array([display, BookScreen.initials(display), legend["fate"], legend["lore"]])
	texts.append(LegendUnlock.BOOK_FULL)
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
