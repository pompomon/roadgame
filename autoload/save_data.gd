class_name SaveData
extends RefCounted
## What the save file holds (plan.md §9, IMPLEMENTATION_PLAN.md M5.4): the atlas of areas, the best
## run, the disaster collection and the settings. SaveService reads and writes the file; this class
## only turns text into data and back, and records runs. load_json() takes any text and keeps what
## it can: it migrates an older version, and a value of the wrong type or out of range falls back to
## its default with a note in problems (M5_PLAN.md L5). Distances are in tiles, as in GameState.

## What load_json() made of the text.
enum Status { LOADED, CORRUPT, NEWER }

const VERSION := 1
const ORIENTATIONS: Array[String] = ["sensor", "portrait", "landscape"]
const DEFAULT_SETTINGS := {
	"music": 0.8,
	"sfx": 1.0,
	"ambient": 0.8,
	"haptics": true,
	"orientation": "sensor",
}
## The settings that are volumes, from 0 to 1.
const VOLUMES: Array[String] = ["music", "sfx", "ambient"]
## An area of the atlas: whether a run has reached it, and the most distance and turns a run made
## in it (M5_PLAN.md L8).
const ATLAS_ENTRY := {"discovered": false, "best_distance": 0.0, "best_turns": 0}
## A disaster of the collection: how often it was seen, and where and in which run it was first
## seen (plan.md §2.6).
const DISASTER_ENTRY := {"seen": 0, "first_area": "", "first_distance": 0.0, "first_turns": 0}
const BEST := {"distance": 0.0, "turns": 0}
## The largest number a count or an amount can be: 2^53 - 1, the largest whole number that a JSON
## number holds exactly. Past it, int() can't hold a count, and the HUD's metres overflow (L5). An
## int: Godot reads the float literal 9007199254740991.0 as 9007199254740990.0.
const MAX_NUMBER := 9007199254740991

## By area id.
var atlas: Dictionary[String, Dictionary] = {}
var best: Dictionary = BEST.duplicate()
## By disaster id.
var disasters: Dictionary[String, Dictionary] = {}
var settings: Dictionary = DEFAULT_SETTINGS.duplicate()
## What load_json() could not read and replaced with defaults.
var problems := PackedStringArray()


## How each older version of the file becomes the next: {from_version: Callable(Dictionary) ->
## Dictionary}. migrate() then sets the version.
static func migrations() -> Dictionary[int, Callable]:
	return {0: _v0_to_v1}


## Version 0 is a file with no "version" (M5_PLAN.md Q8). It has plan.md §9's keys, and the keys
## version 1 adds come from the defaults, so it needs no change.
static func _v0_to_v1(data: Dictionary) -> Dictionary:
	return data


## `data` of version `from`, brought to version `to` by the migrations in `table`, one version at
## a time. A version that has no migration is an error: the data is then dropped.
static func migrate(
	data: Dictionary, from: int, to: int, table: Dictionary[int, Callable]
) -> Dictionary:
	var out := data.duplicate(true)
	for version: int in range(from, to):
		if not table.has(version):
			push_error("SaveData: no migration from version %d" % version)
			return {}
		out = table[version].call(out)
		out["version"] = version + 1
	return out


## Reads `text`, which may be anything. On CORRUPT the data stays at its defaults. NEWER (a file
## written by a later version) is read as far as this version knows it.
func load_json(text: String) -> Status:
	var json := JSON.new()
	# Not JSON.parse_string(), which logs an error for bad text (M5_PLAN.md L6).
	if json.parse(text) != OK:
		problems.append("line %d: %s" % [json.get_error_line(), json.get_error_message()])
		return Status.CORRUPT
	if not json.data is Dictionary:
		problems.append("the file is not an object")
		return Status.CORRUPT
	var root: Dictionary = json.data
	var version: Variant = root.get("version", 0)
	if not _is_count(version):
		problems.append("version: %s" % str(version))
		return Status.CORRUPT
	if version > VERSION:
		_read(root)
		return Status.NEWER
	_read(migrate(root, int(version), VERSION, migrations()))
	return Status.LOADED


func to_json() -> String:
	var data := {
		"version": VERSION,
		"atlas": atlas,
		"best": best,
		"disasters": disasters,
		"settings": settings,
	}
	return JSON.stringify(data, "\t")


## Records a finished run's GameState.stats(): the areas it reached, the distance and turns it made
## in each, and its distance and turns overall.
func record_run(stats: Dictionary) -> void:
	var areas: Dictionary = stats.get("areas", {})
	for id: StringName in areas:
		var made: Dictionary = areas[id]
		var entry: Dictionary = atlas.get(String(id), ATLAS_ENTRY.duplicate())
		entry["discovered"] = true
		entry["best_distance"] = maxf(entry["best_distance"], made.get("distance", 0.0))
		entry["best_turns"] = maxi(entry["best_turns"], made.get("turns", 0))
		atlas[String(id)] = entry
	best["distance"] = maxf(best["distance"], stats.get("distance", 0.0))
	best["turns"] = maxi(best["turns"], stats.get("turn_index", 0))


## Records that the disaster `id` was seen in the area `area_id`, in the run of `stats`.
func record_disaster(id: StringName, area_id: StringName, stats: Dictionary) -> void:
	var entry: Dictionary = disasters.get(String(id), DISASTER_ENTRY.duplicate())
	entry["seen"] += 1
	if entry["seen"] == 1:
		entry["first_area"] = String(area_id)
		entry["first_distance"] = float(stats.get("distance", 0.0))
		entry["first_turns"] = int(stats.get("turn_index", 0))
	disasters[String(id)] = entry


## Sets a setting. An unknown key, or a value it can't take, is an error and changes nothing.
func set_setting(key: String, value: Variant) -> bool:
	if not DEFAULT_SETTINGS.has(key) or not _setting_ok(key, value):
		push_error("SaveData: %s can't be %s" % [key, str(value)])
		return false
	settings[key] = float(value) if key in VOLUMES else value
	return true


func _read(root: Dictionary) -> void:
	for id: String in _section(root, "atlas"):
		var entry := _entry(root["atlas"][id], ATLAS_ENTRY, "atlas." + id)
		if not entry.is_empty():
			atlas[id] = entry
	best = _entry(root.get("best", {}), BEST, "best")
	if best.is_empty():
		best = BEST.duplicate()
	for id: String in _section(root, "disasters"):
		var entry := _entry(root["disasters"][id], DISASTER_ENTRY, "disasters." + id)
		if not entry.is_empty():
			disasters[id] = entry
	var stored: Variant = root.get("settings", {})
	if not stored is Dictionary:
		problems.append("settings")
		return
	for key: String in DEFAULT_SETTINGS:
		if stored.has(key):
			if _setting_ok(key, stored[key]):
				settings[key] = float(stored[key]) if key in VOLUMES else stored[key]
			else:
				problems.append("settings.%s" % key)


## The keys of root[name], if that is an object.
func _section(root: Dictionary, name: String) -> Array:
	var section: Variant = root.get(name, {})
	if not section is Dictionary:
		problems.append(name)
		return []
	return section.keys()


## `stored` read as an entry like `defaults`: each value of the wrong type is a problem and gets its
## default, and keys `defaults` doesn't have are dropped. Empty if `stored` is not an object.
func _entry(stored: Variant, defaults: Dictionary, where: String) -> Dictionary:
	if not stored is Dictionary:
		problems.append(where)
		return {}
	var entry := defaults.duplicate()
	for key: String in defaults:
		if not stored.has(key):
			continue
		var value: Variant = stored[key]
		var default: Variant = defaults[key]
		if default is bool and value is bool or default is String and value is String:
			entry[key] = value
		elif default is int and _is_count(value):
			entry[key] = int(value)
		elif default is float and _is_amount(value):
			entry[key] = float(value)
		else:
			problems.append("%s.%s" % [where, key])
	return entry


static func _setting_ok(key: String, value: Variant) -> bool:
	if key in VOLUMES:
		return _is_amount(value) and value <= 1.0
	if key == "orientation":
		return value is String and value in ORIENTATIONS
	return value is bool


## A whole number, 0 or more. JSON reads every number as a float.
static func _is_count(value: Variant) -> bool:
	return _is_amount(value) and value == floorf(value)


## A number from 0 to MAX_NUMBER.
static func _is_amount(value: Variant) -> bool:
	return (value is float or value is int) and value >= 0 and value <= MAX_NUMBER
