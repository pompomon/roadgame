extends GutTest
## DisasterPicks (POOLS_PLAN.md §5.1): each area's disaster for a run, drawn once from the area's
## pool on a stream of the run's seed and the area's id. A seen disaster weighs
## Tuning.SEEN_DISASTER_WEIGHT against 1 for one not seen yet (Q2), so the same seed and the same
## collection give the same disasters, whenever and in whatever order the areas are picked (V1).

const TimedDisaster := preload("res://tests/helpers/timed_disaster.gd")
## Run seeds for the shares. With 3000, a share of 0.2 is off by more than SHARE_OFF one time in
## about 20000 (4 standard deviations); each seed's pick is the same on every run of the test.
const SEEDS := 3000
const SHARE_OFF := 0.03


## A scene whose root is a disaster with the id `id`, as a legend's .tscn sets it.
static func _scene(id: StringName) -> PackedScene:
	var node := Node2D.new()
	node.set_script(TimedDisaster)
	node.set("id", id)
	var scene := PackedScene.new()
	scene.pack(node)
	node.free()
	return scene


static func _area(id: StringName, pool: Array[PackedScene]) -> AreaDef:
	var area := AreaDef.new()
	area.id = id
	area.disasters = pool
	return area


static func _pool(ids: Array[StringName]) -> Array[PackedScene]:
	var pool: Array[PackedScene] = []
	for id: StringName in ids:
		pool.append(_scene(id))
	return pool


## The share of SEEDS run seeds whose pick in `area` is each scene of its pool, with `seen` seen.
static func _shares(area: AreaDef, seen: Array[StringName]) -> Array[float]:
	var counts: Array[int] = []
	counts.resize(area.disasters.size())
	for run_seed: int in SEEDS:
		counts[area.disasters.find(DisasterPicks.new(run_seed, seen).pick(area))] += 1
	var shares: Array[float] = []
	for count: int in counts:
		shares.append(float(count) / SEEDS)
	return shares


func test_a_seen_disaster_is_half_as_likely_as_each_unseen_one() -> void:
	var ids: Array[StringName] = [&"bus", &"moth", &"reaper"]
	var area := _area(&"city", _pool(ids))
	var even := [1 / 3.0, 1 / 3.0, 1 / 3.0]
	var cases := {
		"none seen": [[] as Array[StringName], even],
		"one seen": [[&"bus"] as Array[StringName], [0.2, 0.4, 0.4]],
		"two seen": [[&"bus", &"moth"] as Array[StringName], [0.25, 0.25, 0.5]],
		"all seen": [ids, even],
		"seen elsewhere": [[&"ufo"] as Array[StringName], even],
	}
	for what: String in cases:
		var shares := _shares(area, cases[what][0])
		var expected: Array = cases[what][1]
		for i: int in expected.size():
			assert_almost_eq(shares[i], float(expected[i]), SHARE_OFF, "%s: scene %d" % [what, i])


func test_the_same_seed_and_collection_pick_the_same_whenever_and_in_any_order() -> void:
	var city := _area(&"city", _pool([&"bus", &"moth", &"reaper"]))
	var rural := _area(&"rural", _pool([&"ufo", &"crow", &"rider"]))
	var seen: Array[StringName] = [&"moth"]
	var differs := false
	for run_seed: int in 20:
		var in_order := DisasterPicks.new(run_seed, seen)
		var first := [in_order.pick(city), in_order.pick(rural)]
		var reversed := DisasterPicks.new(run_seed, seen)
		var rural_first := reversed.pick(rural)
		assert_eq([reversed.pick(city), rural_first], first, "seed %d: in any order" % run_seed)
		assert_eq([in_order.pick(city), in_order.pick(rural)], first, "seed %d: kept" % run_seed)
		differs = differs or first[0] != DisasterPicks.new(run_seed + 1, seen).pick(city)
	assert_true(differs, "another seed picks another disaster for some seeds")


func test_each_area_draws_on_its_own_stream() -> void:
	# The same pool in two areas: were the stream the run's alone, both would pick alike.
	var pool := _pool([&"a", &"b", &"c"])
	var same := 0
	for run_seed: int in 60:
		var picks := DisasterPicks.new(run_seed)
		if picks.pick(_area(&"city", pool)) == picks.pick(_area(&"rural", pool)):
			same += 1
	assert_between(same, 5, 40, "about a third alike, as chance has it")


func test_picked_lists_the_areas_asked_for_once_each() -> void:
	var picks := DisasterPicks.new(1)
	assert_eq(picks.picked(), [] as Array[StringName], "none before a zone is reached")
	var meadows := _area(&"meadows", _pool([&"ring"]))
	picks.pick(meadows)
	picks.pick(_area(&"village", _pool([&"hex"])))
	picks.pick(meadows)
	assert_eq(picks.picked(), [&"meadows", &"village"] as Array[StringName])


func test_an_empty_pool_picks_nothing() -> void:
	assert_null(DisasterPicks.new(1).pick(_area(&"city", [])))


func test_no_weight_above_zero_is_an_error_and_picks_the_first() -> void:
	var pool := _pool([&"a", &"b"])
	var rng := DisasterPicks.stream(1, &"city")
	assert_eq(DisasterPicks.draw(pool, PackedFloat32Array([0.0, 0.0]), rng), pool[0])
	assert_push_error("no scene of the pool has a weight above 0")


func test_the_id_comes_from_the_scene_without_instancing_it() -> void:
	assert_eq(DisasterPicks.id_of(_scene(&"bus")), &"bus")
	assert_eq(DisasterPicks.id_of(_scene(&"")), &"", "a root that sets no id")
	assert_eq(DisasterPicks.id_of(PackedScene.new()), &"", "an empty scene")
