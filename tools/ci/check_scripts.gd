extends SceneTree
## Loads every project script so Godot prints parse errors. Run by check_scripts.sh.

const SKIP_DIRS: Array[String] = ["res://addons", "res://android", "res://build"]


func _initialize() -> void:
	var paths: Array[String] = []
	_collect("res://", paths)
	for path: String in paths:
		if load(path) == null:
			printerr("ERROR: Failed to load script %s" % path)
	print("check_scripts: loaded %d scripts" % paths.size())
	quit()


func _collect(dir: String, out: Array[String]) -> void:
	if dir in SKIP_DIRS or FileAccess.file_exists(dir.path_join(".gdignore")):
		return
	for file: String in DirAccess.get_files_at(dir):
		if file.get_extension() == "gd":
			out.append(dir.path_join(file))
	for sub: String in DirAccess.get_directories_at(dir):
		if not sub.begins_with("."):
			_collect(dir.path_join(sub), out)
