extends GutTest
## The tutorial's road over many seeds (TUTORIAL_PLAN.md §5.1): its junctions are T-junctions whose
## wrong exits loop round to the junction two on, each loop tile belongs to the nearer end and is of
## its area, a loop turns no sooner than the path does, no road touches a loop's side, and a loop
## stays within DEAD_END_MAX_TILES rows of the junction that frees it, as a dead end does. After
## end_tutorial(), the group's last junctions close their loops, and the road goes on as the seed's
## road does from its first junction, with the schedule counted from the turn base (§5.5).

const Fixtures := preload("res://tests/helpers/road_fixtures.gd")
const SEEDS := 100
## Twelve groups of four.
const TURNS := 48


func test_wrong_exits_loop_round_to_the_junction_two_on() -> void:
	var gen: RoadGenerator
	for run_seed: int in SEEDS:
		gen = RoadGenerator.new(run_seed, Fixtures.schedule(), true)
		var path := Fixtures.path_until_turn(gen, TURNS)
		_check_tutorial(gen, path, TURNS, "seed %d" % run_seed)
		# Every claim succeeded (a failed claim also fails the test with its push_error).
		assert_eq(gen.occupancy.size(), _count(path), "seed %d" % run_seed)
		if is_failing():
			return
	assert_true(gen.tutorial, "the tutorial goes on until end_tutorial()")


func test_the_tutorial_ends_with_its_group_and_the_seed_road_follows() -> void:
	var rural := Fixtures.schedule().entries[1].turn
	for run_seed: int in SEEDS:
		var label := "seed %d" % run_seed
		var gen := RoadGenerator.new(run_seed, Fixtures.schedule(), true)
		# The streak may end at any turn, with the generator up to a buffer's worth of road ahead.
		var turn_base := 1 + run_seed % 20
		var path := Fixtures.path_until_turn(gen, turn_base + run_seed % 7)
		gen.end_tutorial(turn_base)
		var first_city := ceili(gen.turn_count / 4.0) * 4
		var tile := gen.next_tile()
		while tile.type != RoadTile.Type.SET_PIECE:
			path.append(tile)
			tile = gen.next_tile()
		assert_false(gen.tutorial, label)
		assert_eq(gen.turn_count - turn_base, rural, label + ": the schedule counts from the base")
		_check_tutorial(gen, path, first_city, label)
		var pure := Fixtures.path_until_turn(
			RoadGenerator.new(run_seed, Fixtures.schedule()), rural
		)
		var city := path.slice(
			path.find_custom(func(t: RoadTile) -> bool: return t.turn_number == first_city)
		)
		var seed_road := pure.slice(
			Tuning.START_STRAIGHT_TILES, Tuning.START_STRAIGHT_TILES + city.size()
		)
		var got: Array = city.map(func(t: RoadTile) -> Array: return _relative(t, city[0]))
		var want: Array = seed_road.map(
			func(t: RoadTile) -> Array: return _relative(t, seed_road[0])
		)
		assert_eq(got, want, label + ": the road after the tutorial is the seed's")
		if is_failing():
			return


## `tile` from `origin`: its cells, indices and turn relative to origin's.
func _relative(tile: RoadTile, origin: RoadTile) -> Array:
	var turn := tile.turn_number - origin.turn_number if tile.is_junction() else 0
	var sig: Array = [
		tile.cell - origin.cell,
		tile.type,
		tile.exits,
		tile.area_id,
		tile.path_index - origin.path_index,
		turn,
		tile.expected_exit,
	]
	for branch: RoadTile in tile.branches:
		(
			sig
			. append_array(
				[
					branch.cell - origin.cell,
					branch.type,
					branch.exits,
					branch.junction_index - origin.path_index,
					branch.branch_exit,
				]
			)
		)
	return sig


## The tiles of `path`, with their branches.
func _count(path: Array[RoadTile]) -> int:
	var tiles := 0
	for tile: RoadTile in path:
		tiles += 1 + tile.branches.size()
	return tiles


## Checks the tutorial's junctions of `path`, those before turn `end`, and their loops. It checks
## nothing once the test fails, so that a broken rule fails once (ROADGEN_PLAN.md §6.2, N7).
func _check_tutorial(gen: RoadGenerator, path: Array[RoadTile], end: int, label: String) -> void:
	if is_failing():
		return
	var junctions: Dictionary[int, RoadTile] = {}
	for tile: RoadTile in path:
		if tile.is_junction():
			junctions[tile.turn_number] = tile
	for turn: int in end:
		var junction: RoadTile = junctions.get(turn)
		if junction == null or junction.type != RoadTile.Type.T_JUNCTION:
			fail_test("%s: turn %d isn't a T-junction" % [label, turn])
			return
		var wrong := Heading.opposite(junction.expected_exit)
		var entry := Heading.opposite(junction.heading)
		var exits := Heading.bit(entry) | Heading.bit(junction.expected_exit) | Heading.bit(wrong)
		if junction.exits != exits or not junction.is_turn():
			fail_test("%s: turn %d has exits %d" % [label, turn, junction.exits])
			return
		for branch: RoadTile in junction.branches:
			if (
				absi(-(branch.cell.x + branch.cell.y) - junction.path_index)
				> Tuning.DEAD_END_MAX_TILES
			):
				fail_test("%s: a loop tile of turn %d is too far from it" % [label, turn])
				return
		if turn % 4 < 2:
			_check_loop(gen, junction, junctions.get(turn + 2), label)
			if is_failing():
				return


## Walks the loop from `start`'s wrong exit to `end`'s, and checks each of its tiles.
func _check_loop(gen: RoadGenerator, start: RoadTile, end: RoadTile, label: String) -> void:
	var name := "%s: the loop from turn %d" % [label, start.turn_number]
	if end == null:
		fail_test(name + " has no junction two on")
		return
	var loop := _walk_loop(gen, start, end, name)
	if is_failing():
		return
	for k: int in loop.size():
		var tile := loop[k]
		var near_start := k + 1 <= loop.size() - k
		var owner := start if near_start else end
		if (
			tile.type != RoadTile.Type.DEAD_END
			or tile.junction_index != owner.path_index
			or tile.branch_exit != Heading.opposite(owner.expected_exit)
		):
			fail_test(name + ": its tile %d doesn't belong to the nearer end" % k)
			return
		# The road sheet and the props come from the tile's area: the tutorial is the City's road.
		if tile.area_id != owner.area_id:
			fail_test(name + ": its tile %d isn't of its junction's area" % k)
			return
		for h: int in Heading.VEC.size():
			var touches := not gen.occupancy.is_free(tile.cell + Heading.VEC[h])
			if touches != tile.has_exit(h):
				fail_test(name + ": its tile %d touches a road at %s" % [k, Heading.NAMES[h]])
				return


## The tiles of the loop from `start`'s wrong exit to `end`'s, in order. Fails the test if it
## breaks, comes back anywhere but into `end` heading its turn, or turns sooner after a junction or
## a corner than the path does.
func _walk_loop(
	gen: RoadGenerator, start: RoadTile, end: RoadTile, name: String
) -> Array[RoadTile]:
	var loop: Array[RoadTile] = []
	var cell := start.cell
	var step := Heading.opposite(start.expected_exit)
	# The straights since the junction or the last corner.
	var straights := 0
	for i: int in 2 * Tuning.DEAD_END_MAX_TILES + 1:
		cell += Heading.VEC[step]
		var tile := gen.occupancy.get_tile(cell)
		if tile == null or not tile.has_exit(Heading.opposite(step)):
			fail_test(name + " breaks at %s" % cell)
			return loop
		if tile.path_index >= 0:
			# Into `end` through its wrong exit, the opposite of its turn: so heading its turn.
			if tile != end or step != end.expected_exit:
				fail_test(name + " comes back at path tile %d" % tile.path_index)
			return loop
		loop.append(tile)
		var onward := _only(tile.exits & ~Heading.bit(Heading.opposite(step)))
		if onward < 0:
			fail_test(name + " has a tile at %s with exits %d" % [cell, tile.exits])
			return loop
		if onward != step and straights < gen.current_area.min_straight:
			fail_test(name + " turns at %s after %d straights" % [cell, straights])
			return loop
		straights = straights + 1 if onward == step else 0
		step = onward
	fail_test(name + " doesn't come back")
	return loop


## The heading of the one bit of `exits`, or -1.
func _only(exits: int) -> int:
	for h: int in Heading.VEC.size():
		if exits == Heading.bit(h):
			return h
	return -1
