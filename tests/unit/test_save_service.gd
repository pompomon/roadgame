extends GutTest
## SaveService (plan.md §9, IMPLEMENTATION_PLAN.md M5.4): the save file on disk. Each test uses a
## fresh service on its own file under user://save_tests/, never the player's save (M5_PLAN.md L1).

const SaveServiceScript := preload("res://autoload/save_service.gd")
const DIR := "user://save_tests"
const FILE := DIR + "/save.json"
const DELTA := 1.0 / 60.0

var _service: SaveServiceScript


## Loses all but the start of each write as the file closes, as a full disk does to a buffered
## write, and Godot reports nothing (M5_PLAN.md L11).
class LossySave:
	extends "res://autoload/save_service.gd"

	func _store(file: FileAccess, text: String) -> bool:
		var stored := file.store_string(text.left(8))
		file.close()
		return stored


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	_clean()
	_service = _new_service()


func after_each() -> void:
	_service.use_memory()
	_clean()
	DirAccess.remove_absolute(DIR)


func _new_service() -> SaveServiceScript:
	var service := SaveServiceScript.new()
	add_child_autofree(service)
	service.use_file(FILE)
	return service


static func _clean() -> void:
	for suffix: String in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(FILE + suffix):
			DirAccess.remove_absolute(FILE + suffix)
	# test_a_corrupt_file_that_cant_be_kept_is_never_written_over's.
	if DirAccess.dir_exists_absolute(FILE + ".bak"):
		DirAccess.remove_absolute(FILE + ".bak")


static func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


static func _read() -> SaveData:
	var data := SaveData.new()
	data.load_json(FileAccess.get_file_as_string(FILE))
	return data


static func _area(id: StringName) -> AreaDef:
	var area := AreaDef.new()
	area.id = id
	return area


func test_the_tests_never_touch_the_players_save() -> void:
	assert_eq(SaveService.path, "", "tests/gut_pre_run.gd")


func test_a_missing_file_gives_the_defaults_and_is_not_written() -> void:
	assert_false(_service.is_loaded(), "read when first asked for")
	assert_eq(_service.data().settings, SaveData.DEFAULT_SETTINGS)
	assert_true(_service.is_loaded())
	assert_eq(_service.flush(), OK)
	assert_false(FileAccess.file_exists(FILE))


func test_a_run_is_written_when_it_ends_and_read_back() -> void:
	var stats := {
		"distance": 20.0, "turn_index": 4, "areas": {&"city": {"distance": 20.0, "turns": 4}}
	}
	EventBus.run_ended.emit(CarSim.WRONG_TURN, stats)
	assert_true(FileAccess.file_exists(FILE), "at once")
	assert_false(FileAccess.file_exists(FILE + ".tmp"), "the .tmp file replaced the file")
	var again := _new_service()
	assert_eq(again.data().best, {"distance": 20.0, "turns": 4})
	assert_eq(again.data().atlas["city"]["best_turns"], 4)


func test_a_disaster_is_written_when_it_starts() -> void:
	EventBus.disaster_started.emit(&"flood", _area(&"meadows"))
	assert_eq(_read().disasters["flood"]["seen"], 1)
	assert_eq(_read().disasters["flood"]["first_area"], "meadows")


func test_a_tmp_file_left_by_a_write_is_removed_when_the_save_is_read() -> void:
	_write(FILE, SaveData.new().to_json())
	_write(FILE + ".tmp", '{"best": ')
	_service.data()
	assert_false(FileAccess.file_exists(FILE + ".tmp"))
	assert_eq(_service.data().problems, PackedStringArray())


func test_a_corrupt_file_is_kept_as_bak_and_replaced_with_the_defaults_at_once() -> void:
	_write(FILE, '{"version": 1, "best": ')
	assert_eq(_service.data().best, SaveData.BEST)
	assert_push_warning("can't be read")
	assert_eq(FileAccess.get_file_as_string(FILE + ".bak"), '{"version": 1, "best": ')
	var data := SaveData.new()
	assert_eq(data.load_json(FileAccess.get_file_as_string(FILE)), SaveData.Status.LOADED)


## Writing the defaults over a file that can't be kept as .bak would lose it (L11).
func test_a_corrupt_file_that_cant_be_kept_is_never_written_over() -> void:
	var text := '{"version": 1, "best": '
	_write(FILE, text)
	DirAccess.make_dir_absolute(FILE + ".bak")
	assert_eq(_service.data().best, SaveData.BEST)
	assert_push_warning("or kept as .bak")
	assert_eq(FileAccess.get_file_as_string(FILE), text)
	_service.set_setting("music", 0.1)
	assert_eq(_service.flush(), ERR_FILE_NO_PERMISSION)
	assert_eq(FileAccess.get_file_as_string(FILE), text)
	assert_eq(_service.setting("music"), 0.1, "kept in memory")


func test_values_it_cant_use_are_a_warning() -> void:
	_write(FILE, '{"version": 1, "settings": {"music": "loud"}}')
	assert_eq(_service.setting("music"), SaveData.DEFAULT_SETTINGS["music"])
	assert_push_warning("settings.music")


func test_a_file_from_a_later_version_is_never_written_over() -> void:
	var text := '{"version": 99, "best": {"distance": 7, "turns": 2}}'
	_write(FILE, text)
	assert_eq(_service.data().best, {"distance": 7.0, "turns": 2})
	assert_push_warning("later version")
	_service.set_setting("music", 0.1)
	assert_eq(_service.flush(), ERR_FILE_NO_PERMISSION)
	assert_eq(FileAccess.get_file_as_string(FILE), text)


func test_settings_are_written_half_a_second_after_the_last_change() -> void:
	watch_signals(_service)
	_service.set_setting("music", 0.2)
	assert_signal_emitted_with_parameters(_service, "settings_changed", ["music"])
	simulate(_service, 20, DELTA)
	_service.set_setting("music", 0.3)
	var frames := 0
	while not FileAccess.file_exists(FILE) and frames < 120:
		simulate(_service, 1, DELTA)
		frames += 1
	assert_almost_eq(frames * DELTA, Tuning.SETTINGS_SAVE_DELAY, DELTA * 1.01, "after the last")
	assert_eq(_read().settings["music"], 0.3)


func test_flush_and_leaving_the_app_write_the_settings_at_once() -> void:
	var leaving := [
		Node.NOTIFICATION_WM_CLOSE_REQUEST,
		Node.NOTIFICATION_APPLICATION_PAUSED,
		Node.NOTIFICATION_APPLICATION_FOCUS_OUT,
		Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT,
	]
	for what: int in leaving:
		_service.set_setting("sfx", what / 10000.0)
		_service.notification(what)
		assert_eq(_read().settings["sfx"], what / 10000.0, str(what))
	_service.set_setting("ambient", 0.0)
	assert_eq(_service.flush(), OK)
	assert_eq(_read().settings["ambient"], 0.0)


func test_a_file_that_cant_be_written_is_a_warning() -> void:
	_service.use_file(DIR + "/missing/save.json")
	_service.set_setting("haptics", false)
	assert_ne(_service.flush(), OK)
	assert_push_warning("can't write")
	assert_eq(_service.setting("haptics"), false, "kept in memory")


func test_a_write_that_fails_as_the_file_closes_keeps_the_last_save() -> void:
	_service.set_setting("music", 0.5)
	assert_eq(_service.flush(), OK)
	var last := FileAccess.get_file_as_string(FILE)
	var lossy := LossySave.new()
	add_child_autofree(lossy)
	lossy.use_file(FILE)
	lossy.set_setting("music", 0.25)
	assert_eq(lossy.flush(), ERR_FILE_CANT_WRITE)
	assert_eq(FileAccess.get_file_as_string(FILE), last, "the last save stays whole")
	assert_false(FileAccess.file_exists(FILE + ".tmp"))
	assert_eq(lossy.flush(), ERR_FILE_CANT_WRITE, "the change waits for the next write")
	assert_push_warning_count(2)
	lossy.use_memory()


func test_memory_writes_nothing() -> void:
	_service.use_memory()
	_service.set_setting("music", 0.0)
	EventBus.run_ended.emit(CarSim.HEALTH, {"distance": 3.0, "turn_index": 0, "areas": {}})
	assert_eq(_service.flush(), OK)
	assert_false(FileAccess.file_exists(FILE))
	assert_eq(_service.data().best["distance"], 3.0)
