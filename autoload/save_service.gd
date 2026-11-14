extends Node
## Keeps the save file, user://save.json (plan.md §9, IMPLEMENTATION_PLAN.md M5.4). It reads the
## file the first time something asks for data(), so that tests and an autopilot run can switch it
## to memory first (docs/M5.md L1): tests/gut_pre_run.gd does, and so does --autopilot. It records
## every run when it ends and every disaster when it starts, and writes the file at once. A changed
## setting is written SETTINGS_SAVE_DELAY after the last change, or at once on flush(), which also
## comes when the app is closed, paused or loses focus.
##
## A write goes to a .tmp file which, once it reads back whole, replaces the file (M5.4), in one
## frame, so that the Web build's IndexedDB sync sees both (docs/M5.md L11). A file that can't be
## read is kept as .bak and replaced with the defaults at once, or, if it can't be kept, never
## written over. A file from a later version is read but never written over.

## A setting changed, or the save was read: `key` is the setting, or "" for all of them.
signal settings_changed(key: String)

const PATH := "user://save.json"

## The file, or "" to keep the save in memory only.
var path := PATH

var _data: SaveData
## False after reading a file from a later version, or one that can't be read or kept as .bak: this
## one must not write over it.
var _writable := true
## Whether data() has changes that are not written yet.
var _dirty := false
## Seconds until changed settings are written, while above 0.
var _settings_left := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.run_ended.connect(_on_run_ended)
	EventBus.disaster_started.connect(_on_disaster_started)
	if OS.get_cmdline_user_args().has("--autopilot"):
		use_memory()
		# smoke.sh checks it: until a run reads a setting, nothing else shows it (docs/M5.md L1).
		print("autopilot: the save is in %s" % ("memory" if path == "" else path))


func _process(delta: float) -> void:
	if _settings_left > 0.0:
		_settings_left -= delta
		if _settings_left <= 0.0:
			flush()


func _notification(what: int) -> void:
	# The Web sends only the window's focus out (main.gd).
	var leaving := [
		NOTIFICATION_WM_CLOSE_REQUEST,
		NOTIFICATION_APPLICATION_PAUSED,
		NOTIFICATION_APPLICATION_FOCUS_OUT,
		NOTIFICATION_WM_WINDOW_FOCUS_OUT,
		NOTIFICATION_EXIT_TREE,
	]
	if what in leaving:
		flush()


## The save, read from the file when first asked for.
func data() -> SaveData:
	if _data == null:
		_load()
	return _data


## Whether data() has been read.
func is_loaded() -> bool:
	return _data != null


## Keeps the save in memory from now on, starting from the defaults.
func use_memory() -> void:
	use_file("")


## Uses the file at `p_path`, read when next asked for, or memory for "". Tests use their own files.
func use_file(p_path: String) -> void:
	path = p_path
	_data = SaveData.new() if p_path == "" else null
	_writable = true
	_dirty = false
	_settings_left = 0.0


func setting(key: String) -> Variant:
	return data().settings[key]


## Sets a setting and writes it soon. The Settings screen calls flush() when it closes.
func set_setting(key: String, value: Variant) -> void:
	if data().settings.get(key) == value or not data().set_setting(key, value):
		return
	_dirty = true
	_settings_left = Tuning.SETTINGS_SAVE_DELAY
	settings_changed.emit(key)


## Writes what has changed, at once. Returns the error, or OK when there was nothing to write.
func flush() -> Error:
	_settings_left = 0.0
	if not _dirty:
		return OK
	_dirty = false
	if path == "":
		return OK
	if not _writable:
		return ERR_FILE_NO_PERMISSION
	var error := _write(data().to_json())
	_dirty = error != OK
	return error


## The player finished the tutorial: it is written at once (docs/TUTORIAL.md §5.6).
func complete_tutorial() -> void:
	if data().tutorial["done"]:
		return
	data().tutorial["done"] = true
	_dirty = true
	flush()


func _load() -> void:
	_data = SaveData.new()
	if path == "":
		return
	var tmp := path + ".tmp"
	# Left by a write that never finished: the file itself is whole.
	if FileAccess.file_exists(tmp):
		DirAccess.remove_absolute(tmp)
	if not FileAccess.file_exists(path):
		return
	var status := _data.load_json(FileAccess.get_file_as_string(path))
	var problems := ", ".join(_data.problems)
	if status == SaveData.Status.CORRUPT:
		_data = SaveData.new()
		if DirAccess.rename_absolute(path, path + ".bak") != OK:
			# Writing the defaults would lose the file (docs/M5.md L11).
			push_warning(
				(
					"SaveService: %s can't be read (%s) or kept as .bak: it won't be written"
					% [path, problems]
				)
			)
			_writable = false
		else:
			push_warning(
				"SaveService: %s can't be read (%s), it is kept as .bak" % [path, problems]
			)
			# Also schedules the Web build's sync of the rename (docs/M5.md L11).
			_dirty = true
			flush()
	elif status == SaveData.Status.NEWER:
		push_warning("SaveService: %s is from a later version: it won't be written" % path)
		_writable = false
	elif not problems.is_empty():
		push_warning("SaveService: %s had values it can't use: %s" % [path, problems])
	settings_changed.emit("")


func _write(text: String) -> Error:
	var tmp := path + ".tmp"
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		push_warning("SaveService: can't write %s" % tmp)
		return FileAccess.get_open_error()
	# A buffered write that fails as the file closes, on a full disk, is never reported: Godot
	# ignores what fclose() returns. So the file must read back whole before it replaces the save.
	if not _store(file, text) or FileAccess.get_file_as_string(tmp) != text:
		push_warning("SaveService: writing %s failed" % tmp)
		DirAccess.remove_absolute(tmp)
		return ERR_FILE_CANT_WRITE
	var error := DirAccess.rename_absolute(tmp, path)
	if error != OK:
		push_warning("SaveService: can't replace %s" % path)
	return error


## Writes `text` to `file` and closes it. Returns false if Godot reports that the write failed.
func _store(file: FileAccess, text: String) -> bool:
	var stored := file.store_string(text)
	file.close()
	return stored


func _on_run_ended(_cause: StringName, stats: Dictionary) -> void:
	data().record_run(stats)
	_dirty = true
	flush()


func _on_disaster_started(id: StringName, area: AreaDef) -> void:
	data().record_disaster(id, area.id, GameState.stats())
	_dirty = true
	flush()
