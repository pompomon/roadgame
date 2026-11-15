extends GutTest
## The end of the road and the Road Home (ENDGAME_PLAN.md §5.1, §5.6): a schedule with a finish
## ends the road after its last turn, at the finish's set piece and the BEYOND tiles after it, and
## a mirrored one starts heading W and turns right first.

const Fixtures := preload("res://tests/helpers/road_fixtures.gd")
const SEEDS: Array[int] = [1, 2, 3, 42, 12345]
## Tiles to generate past the finish.
const PAST := 40


## Fixtures.set_piece_schedule()'s road, whose second area starts at `turn` after a tunnel 3 tiles
## long, ending at the pier after `finish_turn` turns. Every straight is 3 tiles.
static func _finish_schedule(turn: int, finish_turn: int, mirrored := false) -> AreaSchedule:
	var built := Fixtures.set_piece_schedule(turn, &"tunnel", 3)
	built.finish = &"pier"
	built.finish_turn = finish_turn
	built.mirrored = mirrored
	return built


## `gen`'s path tiles up to the finish, and PAST more.
static func _path_to_finish(gen: RoadGenerator) -> Array[RoadTile]:
	var path: Array[RoadTile] = []
	while not gen.finished():
		path.append(gen.next_tile())
		if path.size() > 10000:
			return path
	for i: int in PAST:
		path.append(gen.next_tile())
	return path


func test_the_road_ends_at_the_finish_after_its_last_turn() -> void:
	var gen := RoadGenerator.new(1, _finish_schedule(2, 4))
	var path := _path_to_finish(gen)
	var junctions := path.filter(func(tile: RoadTile) -> bool: return tile.is_junction())
	assert_eq(junctions.size(), 4, "a junction for each turn, and none after")
	assert_eq(gen.turn_count, 4)
	var last: RoadTile = junctions[-1]
	# The last turn's straight, 3 tiles, then the pier.
	assert_eq(gen.finish_index, last.path_index + 4)
	for tile: RoadTile in path.slice(last.path_index + 1):
		assert_eq(tile.heading, last.expected_exit, "straight on from the last turn")
		assert_eq(tile.area_id, &"after")
		var past := tile.path_index - gen.finish_index
		if past < 0:
			assert_eq(tile.type, RoadTile.Type.STRAIGHT)
		elif past < Tuning.FINISH_TILES:
			assert_eq(tile.type, RoadTile.Type.SET_PIECE)
			assert_eq(tile.set_piece, &"pier")
		else:
			assert_eq(tile.set_piece, RoadGenerator.BEYOND)
	assert_eq(gen.occupancy.size(), _cells(path), "every tile has a cell of its own")


## The Coast's home stretch (ENDGAME_PLAN.md §5.1): the last area starts at the finish's turn, so
## its set piece and a straight lead to the finish, with no junction in it.
func test_a_last_area_at_the_finish_turn_is_a_home_stretch() -> void:
	var gen := RoadGenerator.new(1, _finish_schedule(3, 3))
	var path := _path_to_finish(gen)
	var last_junction := -1
	for tile: RoadTile in path:
		if tile.is_junction():
			last_junction = tile.path_index
	assert_eq(gen.turn_count, 3)
	var stretch := path.slice(last_junction + 1, gen.finish_index)
	var kinds: Array = stretch.map(func(tile: RoadTile) -> Array: return [tile.type, tile.area_id])
	var tunnel := [RoadTile.Type.SET_PIECE, &"before"]
	var straight := [RoadTile.Type.STRAIGHT, &"after"]
	assert_eq(kinds, [tunnel, tunnel, tunnel, straight, straight, straight])
	assert_eq(path[gen.finish_index].area_id, &"after")


## As the areas do: the finish 9 turns after the last area's 3 is 9 after the tutorial's 4 turns.
func test_the_finish_counts_its_turns_from_the_end_of_the_tutorial() -> void:
	var gen := RoadGenerator.new(1, _finish_schedule(3, 9), true)
	while gen.turn_count < 4:
		gen.next_tile()
	assert_false(gen.finished(), "no finish in the tutorial")
	gen.end_tutorial(4)
	var path := _path_to_finish(gen)
	assert_eq(gen.turn_count, 4 + 9, "the schedule's 9 turns after the tutorial's 4")
	assert_true(path.any(func(tile: RoadTile) -> bool: return tile.area_id == &"after"))


## ENDGAME_PLAN.md E1: a finish changes nothing before it. Up to the finish's first tile, the road
## is the endless road's, tile for tile, dead ends too, so a run is the seed's run until the end.
func test_the_road_before_the_finish_is_the_endless_roads() -> void:
	for run_seed: int in SEEDS:
		var road := Fixtures.schedule().ending_at(40, &"pier")
		var gen := RoadGenerator.new(run_seed, road)
		var endless := RoadGenerator.new(run_seed, road.endless())
		var path := _path_to_finish(gen)
		assert_gt(gen.finish_index, 0, "seed %d: the road ends" % run_seed)
		for tile: RoadTile in path.slice(0, gen.finish_index):
			var other := endless.next_tile()
			assert_eq(_shape(tile), _shape(other), "seed %d, tile %d" % [run_seed, tile.path_index])
		assert_true(
			endless.next_tile().is_junction(), "the endless road turns where the pier begins"
		)


func test_a_road_without_a_finish_never_ends() -> void:
	var gen := RoadGenerator.new(1, _finish_schedule(2, 4).endless())
	Fixtures.path_until_turn(gen, 300)
	assert_false(gen.finished())
	assert_eq(gen.finish_index, -1)


func test_a_mirrored_road_starts_west_and_turns_right_first() -> void:
	for run_seed: int in SEEDS:
		var gen := RoadGenerator.new(run_seed, Fixtures.schedule_home().endless())
		var path := Fixtures.path_until_turn(gen, 300)
		assert_eq(path[0].heading, Heading.W, "seed %d" % run_seed)
		assert_eq(path[0].cell, Vector2i.ZERO)
		var turn := 0
		for tile: RoadTile in path:
			assert_true(tile.heading in [Heading.N, Heading.W], "only N and W")
			if not tile.is_junction() or tile.expected_exit == tile.heading:
				continue
			# Right, then left, then right: W to N, N to W.
			var right := turn % 2 == 0
			assert_eq(tile.expected_exit, Heading.N if right else Heading.W, "turn %d" % turn)
			turn += 1
		assert_eq(turn, 300)


func test_a_mirrored_road_has_no_tutorial() -> void:
	var gen := RoadGenerator.new(1, Fixtures.schedule_home(), true)
	assert_push_error("a mirrored road has no tutorial")
	assert_false(gen.tutorial)


func test_the_road_home_ends_at_home_after_280_turns() -> void:
	for run_seed: int in SEEDS:
		var gen := RoadGenerator.new(run_seed, Fixtures.schedule_home())
		var path := _path_to_finish(gen)
		assert_eq(gen.turn_count, 280, "seed %d" % run_seed)
		assert_eq(path[gen.finish_index].set_piece, &"home")
		assert_eq(path[gen.finish_index].area_id, &"city", "home is in the City")
		assert_eq(gen.occupancy.size(), _cells(path), "seed %d: every tile has a cell" % run_seed)
		assert_eq(gen.dropped_count, 0)


## What a tile is, to compare two roads: where it is and leads, its kind, and its dead ends.
static func _shape(tile: RoadTile) -> Array:
	var ends: Array = tile.branches.map(func(branch: RoadTile) -> Vector2i: return branch.cell)
	return [
		tile.cell,
		tile.type,
		tile.heading,
		tile.exits,
		tile.area_id,
		tile.set_piece,
		tile.turn_number,
		tile.expected_exit,
		ends,
	]


## The cells of `path`'s tiles and their branches.
static func _cells(path: Array[RoadTile]) -> int:
	var cells := 0
	for tile: RoadTile in path:
		cells += 1 + tile.branches.size()
	return cells
