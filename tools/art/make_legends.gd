extends SceneTree
## Makes the legends' sheets (M6_PLAN.md §5.7): runs each tools/art/legends/<id>.gd, whose
## `static func make(dir: String) -> void` draws the legend's parts with tools/art/legend_art.gd and
## saves them in `dir`, res://assets/legends/<id>/. So a legend's PR adds its script, and this one
## never changes. Like tools/art/make_art.gd's art, the sheets are placeholders that an artist may
## replace, file by file, keeping what tests/unit/test_legend_art.gd checks. The output is the same
## on every run. From the repository root:
##   godot --headless -s tools/art/make_legends.gd
## then tools/ci/import.sh, and commit the PNG and .import files.

const SCRIPTS := "res://tools/art/legends"
const SHEETS := "res://assets/legends"


func _initialize() -> void:
	var names: Array[String] = []
	if DirAccess.dir_exists_absolute(SCRIPTS):
		for file: String in DirAccess.get_files_at(SCRIPTS):
			if file.get_extension() == "gd":
				names.append(file)
	names.sort()
	for file: String in names:
		var script := load(SCRIPTS.path_join(file)) as Script
		if script == null:
			push_error("make_legends: can't load %s" % file)
			continue
		script.call(&"make", SHEETS.path_join(file.get_basename()))
	print("make_legends: %d legends" % names.size())
	quit()
