extends GutTest


func test_project_name() -> void:
	assert_eq(ProjectSettings.get_setting("application/config/name"), "Road Roguelike")


func test_main_scene_shows_version() -> void:
	var scene: PackedScene = load("res://ui/main.tscn")
	var main: Control = scene.instantiate()
	add_child_autofree(main)
	var label: Label = main.get_node("%Label")
	assert_string_contains(label.text, "Road Roguelike")
