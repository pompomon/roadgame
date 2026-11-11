extends GutTest
## Property tests over many seeds (plan.md §11): no two tiles share a cell, every junction keeps
## its wrong exits, and dead ends are 2 to DEAD_END_MAX_TILES tiles long. A straight-on one is
## never cut short, and one cut below DEAD_END_MIN_TILES stops at a taken cell (ROADGEN_PLAN.md R5).

const Fixtures := preload("res://tests/helpers/road_fixtures.gd")
const SEEDS := 200
const TURNS := 500
## The cells that an opposite-turn dead end always has free: a straight is at least 2 tiles (D7).
const ALWAYS_FREE := 2

## The dead ends that _check() has seen in this test, and those shorter than DEAD_END_MIN_TILES,
## whose end shows as the car enters their junction (ROADGEN_PLAN.md R4).
var _dead_ends := 0
var _short := 0


func before_each() -> void:
	_dead_ends = 0
	_short = 0


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
		for exit: int in lengths:
			var length: int = lengths[exit]
			_dead_ends += 1
			if length < ALWAYS_FREE or length > Tuning.DEAD_END_MAX_TILES:
				fail_test("%s: dead end of %d tiles" % [label, length])
			if exit == tile.heading and length < Tuning.DEAD_END_MIN_TILES:
				fail_test("%s: straight-on dead end of %d tiles" % [label, length])
			if length < Tuning.DEAD_END_MIN_TILES:
				_short += 1
				if gen.occupancy.is_free(tile.cell + Heading.VEC[exit] * (length + 1)):
					fail_test("%s: dead end of %d tiles before a free cell" % [label, length])
	# Every claim succeeded (a failed claim also fails the test with its push_error).
	assert_eq(gen.occupancy.size(), tiles, label)
	assert_eq(gen.dropped_count, 0, "%s: %d cells are always free" % [label, ALWAYS_FREE])


func test_no_shared_cells_over_200_seeds_and_500_turns() -> void:
	for run_seed: int in SEEDS:
		_check(RoadGenerator.new(run_seed, Fixtures.schedule()), TURNS, "seed %d" % run_seed)
	var share := 100.0 * _short / _dead_ends
	gut.p("%d dead ends, %d (%.1f%%) shorter than DEAD_END_MIN_TILES" % [_dead_ends, _short, share])
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


## A dead end with nothing in its way keeps the length it drew, and one that a taken cell cuts
## short stops right before that cell (ROADGEN_PLAN.md R5, E5). Every junction of
## kinds_schedule(0, 1, 0) is a side road, whose only wrong exit is straight on.
func test_a_dead_end_stops_right_before_the_first_taken_cell() -> void:
	var side_roads := Fixtures.kinds_schedule(0.0, 1.0, 0.0)
	var seed_of: Dictionary[int, int] = {}
	for run_seed: int in 100:
		var gen := RoadGenerator.new(run_seed, side_roads)
		var junction: RoadTile = Fixtures.path_until_turn(gen, 1)[-1]
		seed_of[junction.branches.size()] = run_seed
		assert_eq(gen.shortened_count + gen.dropped_count, 0, "seed %d: in its way" % run_seed)
	for length: int in range(Tuning.DEAD_END_MIN_TILES, Tuning.DEAD_END_MAX_TILES + 1):
		assert_has(seed_of, length, "a first dead end of %d tiles" % length)
	assert_eq(seed_of.size(), Tuning.DEAD_END_MAX_TILES - Tuning.DEAD_END_MIN_TILES + 1)
	if not seed_of.has(Tuning.DEAD_END_MAX_TILES):
		return
	var longest: int = seed_of[Tuning.DEAD_END_MAX_TILES]
	var first: RoadTile = Fixtures.path_until_turn(RoadGenerator.new(longest, side_roads), 1)[-1]
	var step: Vector2i = Heading.VEC[first.heading]
	for k: int in range(1, Tuning.DEAD_END_MAX_TILES + 2):
		var at := "a cell taken %d tiles past the junction" % k
		var gen := RoadGenerator.new(longest, side_roads)
		var taken := RoadTile.new(first.cell + step * k, RoadTile.Type.DEAD_END, first.heading, 0)
		assert_true(gen.occupancy.claim(taken), at)
		var junction: RoadTile = Fixtures.path_until_turn(gen, 1)[-1]
		var fits := mini(k - 1, Tuning.DEAD_END_MAX_TILES)
		if fits == 0:
			assert_push_error("no wrong exit", at)
		assert_eq(junction.cell, first.cell, at)
		assert_eq(junction.branches.size(), fits, at)
		for i: int in junction.branches.size():
			assert_eq(junction.branches[i].cell, first.cell + step * (i + 1), at)
		assert_eq(junction.has_exit(first.heading), fits > 0, at)
		assert_eq(gen.dropped_count, 1 if fits == 0 else 0, at)
		var short := fits > 0 and fits < Tuning.DEAD_END_MAX_TILES
		assert_eq(gen.shortened_count, 1 if short else 0, at)
