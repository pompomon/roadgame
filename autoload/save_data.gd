class_name SaveData
extends RefCounted
## What the save file holds (plan.md §9, IMPLEMENTATION_PLAN.md M5.4): the atlas of areas, the best
## run, the disaster collection, the arrivals at each road's finish (docs/ENDGAME.md §5.4), the
## settings and whether the tutorial is done. SaveService reads and writes the file; this class
## only turns text into data and back, and records runs.
## load_json() takes any text and keeps what it can: it migrates an older version, and a value of
## the wrong type or out of range falls back to its default with a note in problems (docs/M5.md
## L5). Distances are in tiles, as in GameState.

## What load_json() made of the text.
enum Status { LOADED, CORRUPT, NEWER }

const VERSION := 5
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
## An area of the atlas: whether a run has reached it, the most distance and turns a run made in it
## (docs/M5.md L8), and whether a run crossed it with no damage, which stamps its postcard
## (docs/ENDGAME.md §5.16).
const ATLAS_ENTRY := {"discovered": false, "best_distance": 0.0, "best_turns": 0, "stamped": false}
## A disaster of the collection: how often it was seen, where and in which run it was first seen
## (plan.md §2.6), and whether an arrival unlocked it (docs/ENDGAME.md §5.5).
const DISASTER_ENTRY := {
	"seen": 0, "first_area": "", "first_distance": 0.0, "first_turns": 0, "unlocked": false
}
## The arrivals at a road's finish, by the finish's id (docs/ENDGAME.md §5.4): how many runs that
## drove the whole road arrived, the least seconds one took, 0 before the first, and whether one
## never left the road; and the farthest turn that such a run reached on the road, arrived or not
## (§5.12).
const ARRIVAL_ENTRY := {"count": 0, "best_seconds": 0.0, "clean": false, "farthest": 0}
const BEST := {"distance": 0.0, "turns": 0}
## Whether the player has finished the tutorial, which runs start with until then
## (docs/TUTORIAL.md §5.6).
const TUTORIAL := {"done": false}
## The largest number a count or an amount can be: 2^53 - 1, the largest whole number that a JSON
## number holds exactly. Past it, int() can't hold a count, and the HUD's metres overflow (L5). An
## int: Godot reads the float literal 9007199254740991.0 as 9007199254740990.0.
const MAX_NUMBER := 9007199254740991
## The finish of the road to the sea, the only road whose runs counted in "best" in version 3, the
## debug flags aside (docs/ENDGAME.md §5.12).
const V3_SEA := "pier"
## The turns of both roads in version 3, to the sea and home.
const V3_FINISH_TURN := 280

## By area id.
var atlas: Dictionary[String, Dictionary] = {}
var best: Dictionary = BEST.duplicate()
## By disaster id.
var disasters: Dictionary[String, Dictionary] = {}
## By the finish's id.
var arrivals: Dictionary[String, Dictionary] = {}
var settings: Dictionary = DEFAULT_SETTINGS.duplicate()
var tutorial: Dictionary = TUTORIAL.duplicate()
## What load_json() could not read and replaced with defaults.
var problems := PackedStringArray()


## How each older version of the file becomes the next: {from_version: Callable(Dictionary) ->
## Dictionary}. migrate() then sets the version.
static func migrations() -> Dictionary[int, Callable]:
	return {0: _v0_to_v1, 1: _v1_to_v2, 2: _v2_to_v3, 3: _v3_to_v4, 4: _v4_to_v5}


## Version 0 is a file with no "version" (docs/M5.md Q8). It has plan.md §9's keys, and the keys
## version 1 adds come from the defaults, so it needs no change.
static func _v0_to_v1(data: Dictionary) -> Dictionary:
	return data


## Version 2 adds the tutorial (docs/TUTORIAL.md §5.6). A player whose save has a run has played
## without it, and doesn't get it: a run leaves a best distance above 0, and marks each area it
## reaches discovered in the atlas (record_run()). A value of the wrong type counts as no run:
## _read() then reports it.
static func _v1_to_v2(data: Dictionary) -> Dictionary:
	var old_best: Variant = data.get("best")
	var old_atlas: Variant = data.get("atlas")
	var ran: bool = old_best is Dictionary and _is_amount(old_best.get("distance"))
	ran = ran and old_best["distance"] > 0
	if old_atlas is Dictionary:
		for entry: Variant in old_atlas.values():
			var discovered: Variant = entry.get("discovered") if entry is Dictionary else null
			ran = ran or discovered is bool and discovered
	data["tutorial"] = {"done": ran}
	return data


## Version 3 adds the arrivals and the disasters' "unlocked" (docs/ENDGAME.md §5.4, §5.5). Both
## come from the defaults: no run has arrived, and no disaster was unlocked.
static func _v2_to_v3(data: Dictionary) -> Dictionary:
	return data


## Version 4 adds each road's farthest turn to its arrival entry (docs/ENDGAME.md §5.12). A road
## with an arrival was driven to its finish, V3_FINISH_TURN. Otherwise the road to the sea's is the
## best turns, at most that, as no other road counted in "best", and the others' 0. A value of the
## wrong type counts as none: _read() then reports it, and an "arrivals" that isn't an object stays.
static func _v3_to_v4(data: Dictionary) -> Dictionary:
	var old_arrivals: Variant = data.get("arrivals", {})
	if not old_arrivals is Dictionary:
		return data
	var old_best: Variant = data.get("best")
	var turns: Variant = old_best.get("turns") if old_best is Dictionary else null
	if not _is_count(turns):
		turns = 0
	if turns > 0 and not old_arrivals.has(V3_SEA):
		old_arrivals[V3_SEA] = {}
	for id: String in old_arrivals:
		var entry: Variant = old_arrivals[id]
		var count: Variant = entry.get("count") if entry is Dictionary else null
		if _is_count(count) and count > 0:
			entry["farthest"] = V3_FINISH_TURN
		elif id == V3_SEA and entry is Dictionary:
			entry["farthest"] = mini(int(turns), V3_FINISH_TURN)
	data["arrivals"] = old_arrivals
	return data


## Version 5 adds each atlas entry's "stamped" (docs/ENDGAME.md §5.16), from the defaults: no run
## has stamped an area. Each road's "farthest" stays as version 4 left it.
static func _v4_to_v5(data: Dictionary) -> Dictionary:
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


## Reads `text`, which may be anything, over the defaults: nothing an earlier load read stays, nor
## its problems. On CORRUPT the data stays at its defaults. NEWER (a file written by a later
## version) is read as far as this version knows it.
func load_json(text: String) -> Status:
	atlas = {}
	best = BEST.duplicate()
	disasters = {}
	arrivals = {}
	settings = DEFAULT_SETTINGS.duplicate()
	tutorial = TUTORIAL.duplicate()
	problems = PackedStringArray()
	var json := JSON.new()
	# Not JSON.parse_string(), which logs an error for bad text (docs/M5.md L6).
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
		"arrivals": arrivals,
		"settings": settings,
		"tutorial": tutorial,
	}
	return JSON.stringify(data, "\t")


## Records a finished run's GameState.stats(): the areas it reached, the distance and turns it made
## in each, and a stamp for each it crossed with no damage (docs/ENDGAME.md §5.16); its turns as its
## road's farthest, if it drove a road with a finish whole, the "road" of the stats (§5.12); and its
## distance and turns overall, if it drove the whole road. A departure from a later area sets
## neither (W22), but stamps what it crossed. Stats without "whole_road" count as a whole road's,
## and without "road" as one without a finish.
func record_run(stats: Dictionary) -> void:
	var areas: Dictionary = stats.get("areas", {})
	for id: StringName in areas:
		var made: Dictionary = areas[id]
		var entry: Dictionary = atlas.get(String(id), ATLAS_ENTRY.duplicate())
		entry["discovered"] = true
		entry["best_distance"] = maxf(entry["best_distance"], made.get("distance", 0.0))
		entry["best_turns"] = maxi(entry["best_turns"], made.get("turns", 0))
		var clean_crossing: bool = made.get("crossed", false) and not made.get("damaged", false)
		entry["stamped"] = entry["stamped"] or clean_crossing
		atlas[String(id)] = entry
	var road: StringName = stats.get("road", &"")
	if road != &"":
		var progress: Dictionary = arrivals.get(String(road), ARRIVAL_ENTRY.duplicate())
		progress["farthest"] = maxi(progress["farthest"], stats.get("turn_index", 0))
		arrivals[String(road)] = progress
	if not stats.get("whole_road", true):
		return
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


## The ids of the disasters seen at least once, or unlocked: those that the Book of Legends
## shows as found (plan.md §2.6, docs/ENDGAME.md W14), and that weigh less in a run's picks
## (docs/POOLS.md Q2, Q3).
func seen_disasters() -> Array[StringName]:
	var ids: Array[StringName] = []
	for id: String in disasters:
		if disasters[id]["seen"] > 0 or disasters[id]["unlocked"]:
			ids.append(StringName(id))
	return ids


## Records that a run that drove the whole road reached the finish `finish` with `stats`, from
## GameState.stats(): one more arrival, the best time and the clean run, and its turns, the
## finish's, as the road's farthest (docs/ENDGAME.md §5.12).
func record_arrival(finish: StringName, stats: Dictionary) -> void:
	var entry: Dictionary = arrivals.get(String(finish), ARRIVAL_ENTRY.duplicate())
	var seconds: float = stats.get("seconds", 0.0)
	entry["count"] += 1
	if entry["best_seconds"] == 0.0 or seconds < entry["best_seconds"]:
		entry["best_seconds"] = seconds
	entry["clean"] = entry["clean"] or bool(stats.get("clean", false))
	entry["farthest"] = maxi(entry["farthest"], int(stats.get("turn_index", 0)))
	arrivals[String(finish)] = entry


## Whether an arrival at the finish `finish` in `seconds` beats the best time there. The first
## arrival has none to beat: a finish's best time is 0 until then, which no arrival beats
## (docs/ENDGAME.md §5.16).
func beats_best_time(finish: StringName, seconds: float) -> bool:
	var best_seconds: float = arrivals.get(String(finish), ARRIVAL_ENTRY)["best_seconds"]
	return seconds < best_seconds


## Unlocks the disaster `id`: the Book of Legends shows it, "Not seen yet" until a run meets it,
## and the picks weigh it as seen (docs/ENDGAME.md §5.5, §5.10).
func unlock_disaster(id: StringName) -> void:
	var entry: Dictionary = disasters.get(String(id), DISASTER_ENTRY.duplicate())
	entry["unlocked"] = true
	disasters[String(id)] = entry


## The arrivals at the finish `finish`, or at every finish without one.
func arrival_count(finish := &"") -> int:
	if finish != &"":
		return arrivals.get(String(finish), ARRIVAL_ENTRY)["count"]
	var count := 0
	for entry: Dictionary in arrivals.values():
		count += entry["count"]
	return count


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
	for id: String in _section(root, "arrivals"):
		var entry := _entry(root["arrivals"][id], ARRIVAL_ENTRY, "arrivals." + id)
		if not entry.is_empty():
			arrivals[id] = entry
	tutorial = _entry(root.get("tutorial", {}), TUTORIAL, "tutorial")
	if tutorial.is_empty():
		tutorial = TUTORIAL.duplicate()
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
