extends GutTest

const Fixtures := preload("res://tests/helpers/road_fixtures.gd")
const SEEDS: Array[int] = [1, 2, 3, 42, 12345]


func test_path_starts_north_with_a_straight_run_up() -> void:
	var gen := RoadGenerator.new(1, Fixtures.schedule())
	for i: int in Tuning.START_STRAIGHT_TILES:
		var tile := gen.next_tile()
		assert_eq(tile.cell, Vector2i(0, -i))
		assert_eq(tile.type, RoadTile.Type.STRAIGHT)
		assert_eq(tile.heading, Heading.N)
		assert_eq(tile.path_index, i)
	assert_true(gen.next_tile().is_junction(), "the first junction follows the start straight")


func test_expected_exits_alternate_left_and_right() -> void:
	for run_seed: int in SEEDS:
		var gen := RoadGenerator.new(run_seed, Fixtures.schedule())
		var turn := 0
		for tile: RoadTile in Fixtures.path_until_turn(gen, 300):
			if not tile.is_junction():
				continue
			assert_eq(tile.turn_number, turn)
			var expected := (
				Heading.left(tile.heading) if turn % 2 == 0 else Heading.right(tile.heading)
			)
			assert_eq(tile.expected_exit, expected, "seed %d turn %d" % [run_seed, turn])
			turn += 1


func test_path_is_a_connected_north_west_staircase() -> void:
	for run_seed: int in SEEDS:
		var path := Fixtures.path_until_turn(RoadGenerator.new(run_seed, Fixtures.schedule()), 300)
		for i: int in range(1, path.size()):
			var prev := path[i - 1]
			var tile := path[i]
			assert_true(tile.heading == Heading.N or tile.heading == Heading.W)
			assert_eq(
				tile.cell, prev.cell + Heading.VEC[tile.heading], "seed %d tile %d" % [run_seed, i]
			)
			assert_eq(tile.path_index, i)
			var leaving := prev.expected_exit if prev.is_junction() else prev.heading
			assert_eq(tile.heading, leaving, "the path leaves a junction by its expected exit")
			assert_true(tile.has_exit(Heading.opposite(tile.heading)), "entry edge")
			assert_true(prev.has_exit(tile.heading), "exit edge")


func test_junctions_have_the_expected_exit_and_one_or_two_wrong_exits() -> void:
	for run_seed: int in SEEDS:
		var gen := RoadGenerator.new(run_seed, Fixtures.schedule())
		for tile: RoadTile in Fixtures.path_until_turn(gen, 300):
			if not tile.is_junction():
				assert_eq(tile.branches.size(), 0)
				continue
			assert_true(tile.has_exit(Heading.opposite(tile.heading)))
			assert_true(tile.has_exit(tile.expected_exit))
			var count := 0
			for h: int in 4:
				count += 1 if tile.has_exit(h) else 0
			var expected_type := (
				RoadTile.Type.CROSS_JUNCTION if count == 4 else RoadTile.Type.T_JUNCTION
			)
			assert_eq(tile.type, expected_type)
			assert_gt(count, 2, "at least one wrong exit")


func test_straights_between_junctions_follow_the_area_rules() -> void:
	var schedule := Fixtures.schedule()
	var areas: Dictionary[StringName, AreaDef] = {}
	for entry: AreaScheduleEntry in schedule.entries:
		areas[entry.area.id] = entry.area
	for run_seed: int in SEEDS:
		var run := 0
		var started := false
		for tile: RoadTile in Fixtures.path_until_turn(RoadGenerator.new(run_seed, schedule), 300):
			if tile.type == RoadTile.Type.STRAIGHT:
				run += 1
			elif tile.is_junction():
				if started:
					var area := areas[tile.area_id]
					assert_between(run, area.min_straight, area.max_straight, "seed %d" % run_seed)
				started = true
				run = 0


func test_dead_ends_run_straight_out_of_wrong_exits_and_end_in_a_cap() -> void:
	for run_seed: int in SEEDS:
		var gen := RoadGenerator.new(run_seed, Fixtures.schedule())
		for tile: RoadTile in Fixtures.path_until_turn(gen, 300):
			var runs: Dictionary[int, Array] = {}
			for branch: RoadTile in tile.branches:
				if not runs.has(branch.branch_exit):
					runs[branch.branch_exit] = []
				runs[branch.branch_exit].append(branch)
			for h: int in 4:
				var wrong := (
					tile.is_junction()
					and tile.has_exit(h)
					and h != tile.expected_exit
					and h != Heading.opposite(tile.heading)
				)
				assert_eq(
					runs.has(h), wrong, "seed %d tile %d exit %d" % [run_seed, tile.path_index, h]
				)
			for exit: int in runs:
				var run: Array = runs[exit]
				assert_between(run.size(), 1, Tuning.DEAD_END_MAX_TILES)
				for k: int in run.size():
					var branch: RoadTile = run[k]
					var exits := Heading.bit(Heading.opposite(exit))
					if k < run.size() - 1:
						exits |= Heading.bit(exit)
					assert_eq(branch.cell, tile.cell + Heading.VEC[exit] * (k + 1))
					assert_eq(branch.type, RoadTile.Type.DEAD_END)
					assert_eq(branch.heading, exit)
					assert_eq(branch.exits, exits, "a straight run that ends in a cap")
					assert_eq(branch.path_index, -1)
					assert_eq(branch.junction_index, tile.path_index)
					assert_eq(branch.area_id, tile.area_id)
