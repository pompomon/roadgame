extends GutTest

const Fixtures := preload("res://tests/helpers/road_fixtures.gd")
const SEEDS: Array[int] = [1, 2, 3, 42, 12345]
const TURNS := 300


## The game's road, and a road with every kind of junction (ROADGEN_PLAN.md R1).
static func _schedules() -> Dictionary[String, AreaSchedule]:
	var schedules: Dictionary[String, AreaSchedule] = {
		"game": Fixtures.schedule(), "kinds": Fixtures.kinds_schedule(0.25, 0.25, 0.25)
	}
	return schedules


## A generator for each seed on each of _schedules(), by what to call it in a failure.
static func _generators() -> Dictionary[String, RoadGenerator]:
	var gens: Dictionary[String, RoadGenerator] = {}
	var schedules := _schedules()
	for road: String in schedules:
		for run_seed: int in SEEDS:
			var gen := RoadGenerator.new(run_seed, schedules[road])
			gens["%s road, seed %d" % [road, run_seed]] = gen
	return gens


## The exits of a junction of `kind` that is entered with `heading` and whose next turn is `turn`.
static func _exits_of(kind: RoadGenerator.Kind, heading: int, turn: int) -> int:
	var exits := Heading.bit(Heading.opposite(heading))
	match kind:
		RoadGenerator.Kind.T:
			exits |= Heading.bit(turn) | Heading.bit(Heading.opposite(turn))
		RoadGenerator.Kind.CROSSROADS:
			exits = Heading.ALL
		RoadGenerator.Kind.SIDE_ROAD:
			exits |= Heading.bit(turn) | Heading.bit(heading)
		RoadGenerator.Kind.DECOY:
			exits |= Heading.bit(heading) | Heading.bit(Heading.opposite(turn))
	return exits


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
	var gens := _generators()
	for where: String in gens:
		var turn := 0
		for tile: RoadTile in Fixtures.path_until_turn(gens[where], TURNS):
			if not tile.is_junction():
				continue
			assert_eq(tile.turn_number, turn, where)
			var expected := (
				Heading.left(tile.heading) if turn % 2 == 0 else Heading.right(tile.heading)
			)
			if tile.is_turn():
				assert_eq(tile.expected_exit, expected, "%s turn %d" % [where, turn])
				turn += 1
			else:
				# A decoy shares the number of the turn that it hides (R2).
				assert_false(tile.has_exit(expected), "%s: a decoy hides turn %d" % [where, turn])


func test_path_is_a_connected_north_west_staircase() -> void:
	var gens := _generators()
	for where: String in gens:
		var path := Fixtures.path_until_turn(gens[where], TURNS)
		for i: int in range(1, path.size()):
			var prev := path[i - 1]
			var tile := path[i]
			assert_true(tile.heading == Heading.N or tile.heading == Heading.W)
			assert_eq(tile.cell, prev.cell + Heading.VEC[tile.heading], "%s tile %d" % [where, i])
			assert_eq(tile.path_index, i)
			var leaving := prev.expected_exit if prev.is_junction() else prev.heading
			assert_eq(tile.heading, leaving, "the path leaves a junction by its expected exit")
			assert_true(tile.has_exit(Heading.opposite(tile.heading)), "entry edge")
			assert_true(prev.has_exit(tile.heading), "exit edge")


func test_junctions_have_the_expected_exit_and_one_or_two_wrong_exits() -> void:
	var gens := _generators()
	for where: String in gens:
		for tile: RoadTile in Fixtures.path_until_turn(gens[where], TURNS):
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
			assert_eq(tile.type, expected_type, where)
			assert_gt(count, 2, "%s: at least one wrong exit" % where)


func test_junctions_offer_the_exits_of_their_kind_as_often_as_its_chance() -> void:
	# The kinds' chances all differ, so a kind that took another's part of the roll would show.
	var chances: Dictionary[int, float] = {
		RoadGenerator.Kind.T: 0.4,
		RoadGenerator.Kind.CROSSROADS: 0.1,
		RoadGenerator.Kind.SIDE_ROAD: 0.2,
		RoadGenerator.Kind.DECOY: 0.3,
	}
	var seen: Dictionary[int, int] = {}
	var junctions := 0
	for run_seed: int in SEEDS:
		var gen := RoadGenerator.new(run_seed, Fixtures.kinds_schedule(0.1, 0.2, 0.3))
		for tile: RoadTile in Fixtures.path_until_turn(gen, TURNS):
			if not tile.is_junction():
				continue
			var kind := Fixtures.kind(tile)
			var turn := Heading.turn_for(tile.turn_number, tile.heading)
			var where := "seed %d tile %d" % [run_seed, tile.path_index]
			assert_eq(tile.exits, _exits_of(kind, tile.heading, turn), where)
			var correct := tile.heading if kind == RoadGenerator.Kind.DECOY else turn
			assert_eq(tile.expected_exit, correct, where)
			seen[kind] = seen.get(kind, 0) + 1
			junctions += 1
	for kind: int in chances:
		var share := float(seen.get(kind, 0)) / junctions
		assert_almost_eq(share, chances[kind], 0.04, "kind %d of %d junctions" % [kind, junctions])


func test_one_roll_picks_the_kind_from_the_chances_in_order() -> void:
	var area := AreaDef.new()
	area.cross_junction_chance = 0.25
	area.side_road_chance = 0.25
	area.decoy_chance = 0.25
	var picks: Dictionary[float, int] = {
		0.0: RoadGenerator.Kind.CROSSROADS,
		0.24: RoadGenerator.Kind.CROSSROADS,
		0.25: RoadGenerator.Kind.SIDE_ROAD,
		0.5: RoadGenerator.Kind.DECOY,
		0.75: RoadGenerator.Kind.T,
		1.0: RoadGenerator.Kind.T,
	}
	for roll: float in picks:
		assert_eq(RoadGenerator.kind_for(roll, area), picks[roll], "roll %.2f" % roll)
	# As M1's `randf() < cross_junction_chance`, so that an area without side roads or decoys
	# keeps its road: a roll of 1 is a T-junction even where every junction is a crossroads.
	area.cross_junction_chance = 1.0
	area.side_road_chance = 0.0
	area.decoy_chance = 0.0
	assert_eq(RoadGenerator.kind_for(0.99, area), RoadGenerator.Kind.CROSSROADS)
	assert_eq(RoadGenerator.kind_for(1.0, area), RoadGenerator.Kind.T)


func test_straights_between_junctions_follow_the_area_rules() -> void:
	var areas: Dictionary[StringName, AreaDef] = {}
	var schedules := _schedules()
	for road: String in schedules:
		for entry: AreaScheduleEntry in schedules[road].entries:
			areas[entry.area.id] = entry.area
	var gens := _generators()
	for where: String in gens:
		var run := 0
		var started := false
		for tile: RoadTile in Fixtures.path_until_turn(gens[where], TURNS):
			if tile.type == RoadTile.Type.STRAIGHT:
				run += 1
			elif tile.is_junction():
				if started:
					var area := areas[tile.area_id]
					assert_between(run, area.min_straight, area.max_straight, where)
				started = true
				run = 0


func test_dead_ends_run_straight_out_of_wrong_exits_and_end_in_a_cap() -> void:
	var gens := _generators()
	for where: String in gens:
		for tile: RoadTile in Fixtures.path_until_turn(gens[where], TURNS):
			_check_dead_ends(tile, where)


func _check_dead_ends(tile: RoadTile, where: String) -> void:
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
		assert_eq(runs.has(h), wrong, "%s tile %d exit %d" % [where, tile.path_index, h])
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
