extends GutTest
## Property tests over many seeds (plan.md §11): no two tiles share a cell, every junction keeps
## its wrong exits, dead ends are 1 to 3 tiles long, and a straight-on one is never cut short.

const Fixtures := preload("res://tests/helpers/road_fixtures.gd")
const SEEDS := 200
const TURNS := 500


## Checks the road up to turn `turns`. It stops at the first junction that fails, and checks nothing
## once the test fails: a broken rule fails at nearly every junction, GUT keeps the text of each
## failure, and one for each junction of 200 seeds ran out of memory (ROADGEN_PLAN.md §6.2, N7).
func _check(gen: RoadGenerator, turns: int, label: String) -> void:
	if is_failing():
		return
	var tiles := 0
	var junctions := 0
	for tile: RoadTile in Fixtures.path_until_turn(gen, turns):
		tiles += 1 + tile.branches.size()
		if not tile.is_junction():
			continue
		junctions += 1
		if tile.branches.is_empty():
			fail_test("%s: junction %d has no wrong exit" % [label, tile.turn_number])
		var lengths: Dictionary[int, int] = {}
		for branch: RoadTile in tile.branches:
			lengths[branch.branch_exit] = lengths.get(branch.branch_exit, 0) + 1
			if branch.junction_index != tile.path_index or branch.path_index != -1:
				fail_test(
					"%s: branch of junction %d is not linked to it" % [label, tile.turn_number]
				)
		for exit: int in lengths:
			var length: int = lengths[exit]
			if length < 1 or length > Tuning.DEAD_END_MAX_TILES:
				fail_test("%s: dead end of %d tiles" % [label, length])
			if exit == tile.heading and length < Tuning.DEAD_END_MIN_TILES:
				fail_test("%s: straight-on dead end of %d tiles" % [label, length])
		if is_failing():
			return
	# Every claim succeeded (a failed claim also fails the test with its push_error).
	assert_eq(gen.occupancy.size(), tiles, label)
	assert_eq(gen.dropped_count, 0, "%s: a 1-tile stub always fits" % label)


func test_no_shared_cells_over_200_seeds_and_500_turns() -> void:
	for run_seed: int in SEEDS:
		_check(RoadGenerator.new(run_seed, Fixtures.schedule()), TURNS, "seed %d" % run_seed)
	pass_test("checked %d seeds × %d turns" % [SEEDS, TURNS])


func test_densest_rules_shorten_dead_ends_but_never_drop_them() -> void:
	var shortened := 0
	for run_seed: int in 50:
		var gen := RoadGenerator.new(run_seed, Fixtures.dense_schedule())
		_check(gen, TURNS, "dense seed %d" % run_seed)
		shortened += gen.shortened_count
	assert_gt(shortened, 0, "collisions happen, and the generator shortens those dead ends")


## Side roads and decoys too (ROADGEN_PLAN.md R1): a straight-on dead end always fits whole.
func test_every_kind_of_junction_keeps_its_wrong_exits() -> void:
	for run_seed: int in 50:
		var gen := RoadGenerator.new(run_seed, Fixtures.kinds_schedule(0.25, 0.25, 0.25))
		_check(gen, TURNS, "kinds seed %d" % run_seed)
