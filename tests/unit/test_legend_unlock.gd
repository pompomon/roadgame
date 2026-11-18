extends GutTest
## LegendUnlock (ENDGAME_PLAN.md §5.5): an arrival unlocks one legend that the player hasn't
## collected, each as likely as the others, from the pools of all the road's areas, on a stream of
## the run's seed.

const Fixtures := preload("res://tests/helpers/road_fixtures.gd")
const TimedDisaster := preload("res://tests/helpers/timed_disaster.gd")
## Run seeds for the shares. With 4000, a share of 1/3 is off by more than SHARE_OFF one time in
## about 10000 (3.9 standard deviations); each seed's pick is the same on every run of the test.
const SEEDS := 4000
const SHARE_OFF := 0.029


## A scene whose root is a disaster with the id `id` and the name `title`.
static func _scene(id: StringName, title := "") -> PackedScene:
	var node := Node2D.new()
	node.set_script(TimedDisaster)
	node.set("id", id)
	node.set("display_name", title)
	var scene := PackedScene.new()
	scene.pack(node)
	node.free()
	return scene


## A road of two areas, whose pools hold `first` and `second`, and the City's bus in both.
static func _schedule(first: Array[StringName], second: Array[StringName]) -> AreaSchedule:
	var schedule := AreaSchedule.new()
	var turn := 0
	for ids: Array[StringName] in [first, second]:
		var area := AreaDef.new()
		area.id = &"area_%d" % turn
		var pool: Array[PackedScene] = []
		for id: StringName in ids:
			pool.append(_scene(id, String(id).capitalize()))
		area.disasters = pool
		var entry := AreaScheduleEntry.new()
		entry.area = area
		entry.turn = turn
		schedule.entries.append(entry)
		turn += 10
	return schedule


func test_the_locked_legends_are_those_not_collected_in_the_collections_order() -> void:
	var schedule := _schedule([&"bus", &"moth"], [&"ufo", &"bus", &"crow"])
	var none: Array[StringName] = []
	assert_eq(LegendUnlock.locked(schedule, none), [&"bus", &"moth", &"ufo", &"crow"], "each once")
	var collected: Array[StringName] = [&"moth", &"crow", &"elsewhere"]
	assert_eq(LegendUnlock.locked(schedule, collected), [&"bus", &"ufo"] as Array[StringName])


## One legend is locked in the first area and two in the second: each is a third, as a pick of an
## area first would make the first's a half.
func test_each_locked_legend_is_as_likely_as_the_others() -> void:
	var schedule := _schedule([&"bus", &"moth", &"reaper"], [&"ufo", &"crow"])
	var collected: Array[StringName] = [&"moth", &"reaper"]
	var counts := {}
	for run_seed: int in SEEDS:
		var id := LegendUnlock.pick(schedule, collected, run_seed)
		counts[id] = counts.get(id, 0) + 1
	assert_eq(counts.keys().size(), 3, "never a collected one: %s" % [counts])
	for id: StringName in counts:
		assert_almost_eq(float(counts[id]) / SEEDS, 1.0 / 3.0, SHARE_OFF, String(id))


func test_the_same_seed_and_collection_unlock_the_same_legend() -> void:
	var schedule := _schedule([&"bus", &"moth", &"reaper"], [&"ufo", &"crow"])
	var collected: Array[StringName] = [&"ufo"]
	var ids := {}
	for run_seed: int in 50:
		var id := LegendUnlock.pick(schedule, collected, run_seed)
		assert_eq(LegendUnlock.pick(schedule, collected, run_seed), id)
		ids[id] = true
	assert_eq(ids.size(), 4, "and the seeds unlock each of them")


func test_with_every_legend_collected_none_is_unlocked() -> void:
	var schedule := _schedule([&"bus"], [&"ufo"])
	var collected: Array[StringName] = [&"bus", &"ufo"]
	assert_eq(LegendUnlock.pick(schedule, collected, 1), &"")
	assert_eq(LegendUnlock.text(schedule, &""), LegendUnlock.BOOK_FULL)


func test_the_arrival_screen_names_the_unlocked_legend() -> void:
	var schedule := _schedule([&"bus"], [&"crow"])
	assert_eq(LegendUnlock.text(schedule, &"crow"), LegendUnlock.UNLOCKED % "Crow")
	assert_eq(LegendUnlock.pool_area(schedule, &"crow").id, &"area_10")
	assert_no_new_orphans("the scene it read the name from is freed")


## Every legend of the game's road can be unlocked, and only once each.
func test_every_legend_of_the_game_can_be_unlocked() -> void:
	var schedule := Fixtures.schedule()
	var collected: Array[StringName] = []
	var expected: Array[StringName] = []
	for legend: Dictionary in BookScreen.disasters(schedule):
		expected.append(legend["id"])
	for run_seed: int in expected.size():
		var id := LegendUnlock.pick(schedule, collected, run_seed)
		assert_false(collected.has(id), "a legend that wasn't collected")
		collected.append(id)
	assert_eq(LegendUnlock.pick(schedule, collected, 99), &"")
	collected.sort()
	expected.sort()
	assert_eq(collected, expected)
