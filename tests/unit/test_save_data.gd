extends GutTest
## SaveData (plan.md §9, IMPLEMENTATION_PLAN.md M5.4): the save's data, its JSON, migration from
## older versions, and what it makes of text it can't fully use (M5_PLAN.md L5, L6).

## plan.md §9's example, with no version: version 0 (Q8).
const V0 := """{
	"atlas": { "city": { "discovered": true, "best_distance": 12 } },
	"best": { "distance": 12, "turns": 3 },
	"disasters": { "sinkhole": { "seen": 3, "first_area": "city" } },
	"settings": {
		"music": 0.5, "sfx": 1.0, "ambient": 0.8, "haptics": false, "orientation": "portrait"
	}
}"""


func _stats(distance: float, turns: int, areas: Dictionary) -> Dictionary:
	return {"distance": distance, "turn_index": turns, "areas": areas}


func test_new_data_has_the_defaults() -> void:
	var data := SaveData.new()
	assert_eq(data.atlas, {} as Dictionary[String, Dictionary])
	assert_eq(data.best, {"distance": 0.0, "turns": 0})
	assert_eq(data.disasters, {} as Dictionary[String, Dictionary])
	assert_eq(data.settings, SaveData.DEFAULT_SETTINGS)
	assert_eq(data.tutorial, {"done": false})


func test_json_round_trip() -> void:
	var data := SaveData.new()
	data.tutorial["done"] = true
	data.record_run(_stats(40.5, 9, {&"city": {"distance": 30.25, "turns": 7}}))
	data.record_disaster(&"tornado", &"city", _stats(40.5, 9, {}))
	data.set_setting("music", 0.3)
	data.set_setting("orientation", "landscape")
	var again := SaveData.new()
	assert_eq(again.load_json(data.to_json()), SaveData.Status.LOADED)
	assert_eq(again.problems, PackedStringArray())
	assert_eq(again.atlas, data.atlas)
	assert_eq(again.best, data.best)
	assert_eq(again.disasters, data.disasters)
	assert_eq(again.settings, data.settings)
	assert_eq(again.tutorial, {"done": true})
	assert_typeof(again.best["turns"], TYPE_INT, "JSON reads every number as a float")
	assert_typeof(again.atlas["city"]["best_turns"], TYPE_INT)
	assert_true(data.to_json().contains('"version": 2'))


func test_a_v0_file_is_migrated_and_keeps_its_values() -> void:
	var data := SaveData.new()
	assert_eq(data.load_json(V0), SaveData.Status.LOADED)
	assert_eq(data.problems, PackedStringArray())
	assert_eq(data.atlas["city"], {"discovered": true, "best_distance": 12.0, "best_turns": 0})
	assert_eq(data.best, {"distance": 12.0, "turns": 3})
	assert_eq(data.disasters["sinkhole"]["seen"], 3)
	assert_eq(data.disasters["sinkhole"]["first_area"], "city")
	assert_eq(data.settings["music"], 0.5)
	assert_eq(data.settings["haptics"], false)
	assert_eq(data.settings["orientation"], "portrait")
	assert_eq(data.tutorial, {"done": true}, "it has a run (TUTORIAL_PLAN.md §5.6)")


## Copilot's review of #39: a load that read less than the last kept the last one's data, and its
## problems.
func test_each_load_starts_from_the_defaults() -> void:
	var data := SaveData.new()
	var loads := {
		"{}": SaveData.Status.LOADED,
		"not json": SaveData.Status.CORRUPT,
		'{"version": 3}': SaveData.Status.NEWER,
		'{"settings": {"music": 2}}': SaveData.Status.LOADED,
	}
	for text: String in loads:
		assert_eq(data.load_json(V0), SaveData.Status.LOADED)
		assert_eq(data.load_json(text), loads[text], text)
		assert_eq(data.atlas, {} as Dictionary[String, Dictionary], text)
		assert_eq(data.best, SaveData.BEST, text)
		assert_eq(data.disasters, {} as Dictionary[String, Dictionary], text)
		assert_eq(data.settings, SaveData.DEFAULT_SETTINGS, text)
		assert_eq(data.tutorial, SaveData.TUTORIAL, text)
	assert_eq(data.problems, PackedStringArray(["settings.music"]), "only the last load's")


func test_migrate_runs_each_step_in_order_and_sets_the_version() -> void:
	var table: Dictionary[int, Callable] = {
		0: func(d: Dictionary) -> Dictionary: return d.merged({"steps": "a"}),
		1: func(d: Dictionary) -> Dictionary: return d.merged({"steps": d["steps"] + "b"}, true),
	}
	assert_eq(SaveData.migrate({}, 0, 2, table), {"steps": "ab", "version": 2})
	assert_eq(SaveData.migrate({"steps": "a"}, 1, 2, table), {"steps": "ab", "version": 2})
	assert_eq(SaveData.migrate({"steps": "x"}, 2, 2, table), {"steps": "x"}, "already there")


func test_every_older_version_has_a_migration() -> void:
	for version: int in SaveData.VERSION:
		assert_has(SaveData.migrations(), version, "from version %d" % version)


func test_a_missing_migration_is_an_error() -> void:
	assert_eq(SaveData.migrate({"a": 1}, 0, 1, {} as Dictionary[int, Callable]), {})
	assert_push_error("no migration from version 0")


## TUTORIAL_PLAN.md §5.6: a version 1 save with a run, in the best distance or an area the atlas
## has discovered, has played without the tutorial and skips it; one with none gets it. A value of
## the wrong type counts as no run, and is no error.
func test_a_v1_file_has_done_the_tutorial_if_it_has_a_run() -> void:
	var files := {
		'{"version": 1}': false,
		'{"version": 1, "settings": {"music": 0.5}}': false,
		'{"version": 1, "best": {"distance": 0, "turns": 0}, "atlas": {}}': false,
		'{"version": 1, "best": {"distance": 0.5, "turns": 0}}': true,
		'{"version": 1, "atlas": {"city": {"discovered": true}}}': true,
		'{"version": 1, "atlas": {"city": {}, "rural": {"discovered": true}}}': true,
		'{"version": 1, "atlas": {"city": {"discovered": false}}}': false,
		'{"version": 1, "atlas": {"city": {"discovered": "yes"}}}': false,
		'{"version": 1, "atlas": {"city": []}}': false,
		'{"version": 1, "best": {"distance": "far"}, "atlas": []}': false,
		'{"version": 1, "best": [12], "atlas": "city"}': false,
	}
	for text: String in files:
		var data := SaveData.new()
		assert_eq(data.load_json(text), SaveData.Status.LOADED, text)
		assert_eq(data.tutorial, {"done": files[text]}, text)


func test_a_tutorial_of_the_wrong_type_is_not_done() -> void:
	var files := {
		'{"version": 2, "tutorial": "yes"}': "tutorial",
		'{"version": 2, "tutorial": {"done": 1}}': "tutorial.done",
	}
	for text: String in files:
		var data := SaveData.new()
		assert_eq(data.load_json(text), SaveData.Status.LOADED, text)
		assert_eq(data.tutorial, SaveData.TUTORIAL, text)
		assert_eq(data.problems, PackedStringArray([files[text]]), text)


func test_text_that_is_not_a_save_is_corrupt_without_errors() -> void:
	for text: String in ["", "{", "not json", "[1, 2]", "7", "null", '{"version": "1"}']:
		var data := SaveData.new()
		assert_eq(data.load_json(text), SaveData.Status.CORRUPT, text)
		assert_false(data.problems.is_empty(), text)
		assert_eq(data.settings, SaveData.DEFAULT_SETTINGS, text)


func test_values_of_the_wrong_type_get_their_defaults() -> void:
	var text := (
		JSON
		. stringify(
			{
				"version": 1,
				"atlas": {"city": {"discovered": "yes", "best_distance": -3, "best_turns": 2.5}},
				"best": {"distance": "far", "turns": 4},
				"disasters": {"flood": 3, "tornado": {"seen": 2, "first_area": 7}},
				"settings": {"music": 1.5, "sfx": "loud", "haptics": 1, "orientation": "upside"},
				"extra": true,
			}
		)
	)
	var data := SaveData.new()
	assert_eq(data.load_json(text), SaveData.Status.LOADED)
	assert_eq(data.atlas["city"], SaveData.ATLAS_ENTRY)
	assert_eq(data.best, {"distance": 0.0, "turns": 4})
	assert_does_not_have(data.disasters, "flood")
	assert_eq(data.disasters["tornado"]["seen"], 2)
	assert_eq(data.disasters["tornado"]["first_area"], "")
	assert_eq(data.settings, SaveData.DEFAULT_SETTINGS)
	var expected := [
		"atlas.city.discovered",
		"atlas.city.best_distance",
		"atlas.city.best_turns",
		"best.distance",
		"disasters.flood",
		"disasters.tornado.first_area",
		"settings.music",
		"settings.sfx",
		"settings.haptics",
		"settings.orientation",
	]
	for problem: String in expected:
		assert_has(data.problems, problem)
	assert_eq(data.problems.size(), expected.size(), str(data.problems))
	assert_false(data.to_json().contains("extra"), "unknown keys are dropped")


## Past 2^53 - 1, int() can't hold a count, and the HUD's metres overflow (L5).
func test_numbers_past_the_largest_exact_whole_number_get_their_defaults() -> void:
	var text := (
		'{"version": 1, "best": {"distance": 1e308, "turns": 9007199254740992},'
		+ ' "atlas": {"city": {"best_distance": 1e20, "best_turns": 9007199254740991}}}'
	)
	var data := SaveData.new()
	assert_eq(data.load_json(text), SaveData.Status.LOADED)
	assert_eq(data.best, SaveData.BEST)
	assert_eq(data.atlas["city"]["best_distance"], 0.0)
	assert_eq(data.atlas["city"]["best_turns"], 9007199254740991, "the largest is a count")
	var expected := PackedStringArray(["atlas.city.best_distance", "best.distance", "best.turns"])
	assert_eq(data.problems, expected)
	assert_eq(data.load_json('{"version": 1e20}'), SaveData.Status.CORRUPT)


func test_a_later_version_is_read_as_far_as_it_is_known() -> void:
	var data := SaveData.new()
	var text := JSON.stringify({"version": 3, "best": {"distance": 5, "turns": 1}, "new": 1})
	assert_eq(data.load_json(text), SaveData.Status.NEWER)
	assert_eq(data.best, {"distance": 5.0, "turns": 1})


func test_record_run_keeps_the_best_of_each_area_and_overall() -> void:
	var data := SaveData.new()
	var city := {"distance": 30.0, "turns": 7}
	data.record_run(_stats(40.0, 9, {&"city": city, &"rural": {"distance": 10.0, "turns": 2}}))
	data.record_run(_stats(35.0, 11, {&"city": {"distance": 35.0, "turns": 6}}))
	assert_eq(data.atlas["city"], {"discovered": true, "best_distance": 35.0, "best_turns": 7})
	assert_eq(data.atlas["rural"], {"discovered": true, "best_distance": 10.0, "best_turns": 2})
	assert_does_not_have(data.atlas, "meadows")
	assert_eq(data.best, {"distance": 40.0, "turns": 11}, "the best of each, not of one run")


func test_record_disaster_counts_and_keeps_the_first_sighting() -> void:
	var data := SaveData.new()
	data.record_disaster(&"sinkhole", &"city", _stats(12.5, 3, {}))
	data.record_disaster(&"sinkhole", &"village", _stats(99.0, 210, {}))
	var expected := {"seen": 2, "first_area": "city", "first_distance": 12.5, "first_turns": 3}
	assert_eq(data.disasters["sinkhole"], expected)


func test_set_setting_takes_only_what_the_setting_can_be() -> void:
	var data := SaveData.new()
	assert_true(data.set_setting("sfx", 0))
	assert_typeof(data.settings["sfx"], TYPE_FLOAT)
	assert_true(data.set_setting("haptics", false))
	var bad: Array[Array] = [["music", 2.0], ["music", "max"], ["orientation", "up"], ["zoom", 1.0]]
	for setting: Array in bad:
		assert_false(data.set_setting(setting[0], setting[1]), str(setting))
	assert_push_error_count(bad.size())
	assert_eq(data.settings["music"], SaveData.DEFAULT_SETTINGS["music"])
