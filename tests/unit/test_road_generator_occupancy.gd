extends GutTest
## Property tests over many seeds (plan.md §11): no two tiles share a cell, every junction keeps a
## wrong exit, and dead ends are 1 to 3 tiles long.

const Fixtures := preload("res://tests/helpers/road_fixtures.gd")
const SEEDS := 200
const TURNS := 500


func _check(gen: RoadGenerator, turns: int, label: String) -> void:
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
		for length: int in lengths.values():
			if length < 1 or length > Tuning.DEAD_END_MAX_TILES:
				fail_test("%s: dead end of %d tiles" % [label, length])
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
