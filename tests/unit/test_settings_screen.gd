extends GutTest
## The settings (plan.md §2.6, IMPLEMENTATION_PLAN.md M5.5) on their own: they show the saved
## settings, each control changes its setting in SaveService, and closing the screen writes them at
## once. SaveService keeps the save in memory, except where a test gives it a file of its own.

const SETTINGS_SCENE := preload("res://ui/settings_screen.tscn")
const DIR := "user://save_tests"
const FILE := DIR + "/settings.json"


func before_each() -> void:
	SaveService.use_memory()


func after_each() -> void:
	SaveService.use_memory()
	if FileAccess.file_exists(FILE):
		DirAccess.remove_absolute(FILE)
	DirAccess.remove_absolute(DIR)


func _settings() -> SettingsScreen:
	var view := SubViewport.new()
	view.size = Vector2i(360, 640)
	add_child_autofree(view)
	var settings: SettingsScreen = SETTINGS_SCENE.instantiate()
	view.add_child(settings)
	return settings


static func _slider(settings: SettingsScreen, key: String) -> HSlider:
	return settings.get_node("%" + {"music": "Music", "sfx": "Sfx", "ambient": "Ambient"}[key])


func test_it_names_each_orientation_in_order() -> void:
	var orientation: OptionButton = _settings().get_node("%Orientation")
	assert_eq(orientation.item_count, SaveData.ORIENTATIONS.size())
	for index: int in orientation.item_count:
		assert_eq(orientation.get_item_text(index), SettingsScreen.ORIENTATION_NAMES[index])


func test_it_shows_the_saved_settings_and_changes_nothing() -> void:
	SaveService.set_setting("music", 0.25)
	SaveService.set_setting("haptics", false)
	SaveService.set_setting("orientation", "landscape")
	var settings := _settings()
	watch_signals(SaveService)
	settings.open()
	assert_true(settings.visible)
	assert_eq(_slider(settings, "music").value, 0.25)
	assert_eq(_slider(settings, "sfx").value, 1.0)
	assert_eq(_slider(settings, "ambient").value, 0.8)
	assert_false((settings.get_node("%Haptics") as CheckButton).button_pressed)
	assert_eq((settings.get_node("%Orientation") as OptionButton).selected, 2)
	assert_true(_slider(settings, "music").has_focus())
	assert_signal_not_emitted(SaveService, "settings_changed", "opening changes nothing")


func test_each_control_changes_its_setting() -> void:
	var settings := _settings()
	settings.open()
	for key: String in SaveData.VOLUMES:
		_slider(settings, key).value = 0.5
		assert_eq(SaveService.setting(key), 0.5, key)
	(settings.get_node("%Haptics") as CheckButton).button_pressed = false
	assert_eq(SaveService.setting("haptics"), false)
	var orientation: OptionButton = settings.get_node("%Orientation")
	for index: int in [1, 2, 0]:
		orientation.select(index)
		orientation.item_selected.emit(index)
		assert_eq(SaveService.setting("orientation"), SaveData.ORIENTATIONS[index])


func test_closing_writes_the_changes_at_once() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	SaveService.use_file(FILE)
	var settings := _settings()
	settings.open()
	_slider(settings, "music").value = 0.75
	assert_false(FileAccess.file_exists(FILE), "not before SETTINGS_SAVE_DELAY")
	settings.close()
	assert_false(settings.visible)
	var saved := SaveData.new()
	saved.load_json(FileAccess.get_file_as_string(FILE))
	assert_eq(saved.settings["music"], 0.75)


func test_back_asks_to_close() -> void:
	var settings := _settings()
	settings.open()
	watch_signals(settings)
	(settings.get_node("%Back") as Button).pressed.emit()
	assert_signal_emit_count(settings, "back_requested", 1)
