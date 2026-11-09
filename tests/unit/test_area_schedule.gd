extends GutTest

const Fixtures := preload("res://tests/helpers/road_fixtures.gd")


func _area(id: StringName, min_straight := 2, max_straight := 5) -> AreaDef:
	var area := AreaDef.new()
	area.id = id
	area.min_straight = min_straight
	area.max_straight = max_straight
	return area


func _entry(turn: int, area: AreaDef, set_piece := &"", length := 0) -> AreaScheduleEntry:
	var entry := AreaScheduleEntry.new()
	entry.turn = turn
	entry.area = area
	entry.set_piece = set_piece
	entry.set_piece_length = length
	return entry


func _problems(entries: Array[AreaScheduleEntry]) -> String:
	var schedule := AreaSchedule.new()
	schedule.entries = entries
	return " | ".join(schedule.validate())


func test_the_game_schedule_is_valid() -> void:
	var schedule := Fixtures.schedule()
	assert_eq(_problems(schedule.entries), "")
	var turns: Array[int] = []
	for entry: AreaScheduleEntry in schedule.entries:
		turns.append(entry.turn)
	assert_eq(turns, [0, 34, 100, 200, 220] as Array[int])


func test_every_area_of_the_game_has_a_pool_of_disasters() -> void:
	# A wrong turn in any area ends in a disaster (M3_PLAN.md J6).
	var areas := 0
	for entry: AreaScheduleEntry in Fixtures.schedule().entries:
		var area := entry.area
		areas += 1
		assert_false(area.disasters.is_empty(), "%s has a pool" % area.id)
		for scene: PackedScene in area.disasters:
			var node := scene.instantiate()
			var disaster := node as DisasterBase
			assert_not_null(disaster, "%s: %s is a disaster" % [area.id, scene.resource_path])
			if disaster != null:
				assert_ne(disaster.id, &"", "%s: %s has an id" % [area.id, scene.resource_path])
			node.free()
	assert_eq(areas, 5, "the five areas")
	var city: AreaDef = load("res://areas/city.tres")
	var sinkhole: PackedScene = load("res://disasters/sinkhole.tscn")
	assert_eq(city.disasters, [sinkhole] as Array[PackedScene], "the City's sinkhole")


func test_validate_reports_broken_schedules() -> void:
	var city := _area(&"city")
	assert_string_contains(_problems([]), "no entries")
	assert_string_contains(_problems([_entry(3, city)]), "not 0")
	assert_string_contains(_problems([_entry(0, city, &"tunnel", 4)]), "has a set piece")
	assert_string_contains(_problems([_entry(0, city), _entry(0, city)]), "does not come after")
	assert_string_contains(_problems([_entry(0, null)]), "no area")
	assert_eq(_problems([null]), "entry 0 is missing")
	assert_eq(_problems([_entry(0, city), null, _entry(9, city)]), "entry 1 is missing")
	assert_string_contains(_problems([_entry(0, city), _entry(5, city, &"bridge", -1)]), "negative")
	assert_string_contains(_problems([_entry(0, city), _entry(5, city, &"bridge")]), "disagree")
	assert_string_contains(_problems([_entry(0, _area(&"short", 1, 5))]), "below 2")
	assert_string_contains(_problems([_entry(0, _area(&"flipped", 6, 5))]), "below min_straight")
	assert_eq(_problems([_entry(0, city), _entry(5, city, &"bridge", 3)]), "")


func test_validate_reports_driving_values_the_car_cannot_use() -> void:
	var least_brake := AreaDef.least_brake_distance()
	var cases := {
		"straight_accel": [-0.1, "straight_accel is negative"],
		"junction_brake_distance":
		[least_brake - 0.001, "junction_brake_distance is below %.3f" % least_brake],
		"junction_speed": [0.0, "junction_speed is outside 0..BASE_TOP_SPEED"],
		"offroad_speed_mult": [0.0, "offroad_speed_mult is outside 0..1"],
		"offroad_damage_per_sec": [-1.0, "offroad_damage_per_sec is negative"],
		"offroad_limit_tiles": [0.0, "offroad_limit_tiles must be above 0"],
	}
	for field: String in cases:
		var area := _area(&"bad")
		area.set(field, cases[field][0])
		assert_eq(_problems([_entry(0, area)]), "bad: %s" % cases[field][1], field)
	var fast := _area(&"fast")
	fast.junction_speed = Tuning.BASE_TOP_SPEED + 0.1
	assert_string_contains(_problems([_entry(0, fast)]), "junction_speed is outside")
	var loose := _area(&"loose")
	loose.offroad_speed_mult = 1.1
	assert_string_contains(_problems([_entry(0, loose)]), "offroad_speed_mult is outside")
	var edge := _area(&"edge")
	edge.junction_speed = Tuning.BASE_TOP_SPEED
	edge.offroad_speed_mult = 1.0
	edge.junction_brake_distance = least_brake
	assert_eq(_problems([_entry(0, edge)]), "", "the limits themselves are allowed")


func test_the_generator_finds_each_area_by_id() -> void:
	var schedule := Fixtures.schedule()
	var generator := RoadGenerator.new(1, schedule)
	for entry: AreaScheduleEntry in schedule.entries:
		assert_same(generator.find_area(entry.area.id), entry.area, entry.area.id)
	assert_same(generator.find_area(&"nowhere"), schedule.entries[0].area, "the first area")
	assert_push_error("no area nowhere")


func test_a_broken_schedule_is_reported_by_the_generator() -> void:
	var schedule := AreaSchedule.new()
	schedule.entries = [_entry(0, _area(&"short", 1, 5))]
	RoadGenerator.new(1, schedule)
	assert_push_error("below 2")


func test_the_generator_replaces_a_broken_schedule_with_one_default_area() -> void:
	var empty := AreaSchedule.new()
	var no_area := AreaSchedule.new()
	no_area.entries = [_entry(0, null)]
	for schedule: AreaSchedule in [null, empty, no_area]:
		var generator := RoadGenerator.new(1, schedule)
		var elsewhere := 0
		for i: int in 200:
			if generator.next_tile().area_id != &"fallback":
				elsewhere += 1
		assert_eq(elsewhere, 0, "tiles outside the fallback area")
	assert_push_error("there is no schedule")
	assert_push_error("no entries")
	assert_push_error("no area")


## Junction `turn - 1` and the set-piece tiles after it keep `old`; the next tile starts `new`.
func _check_switch(path: Array[RoadTile], turn: int, old: StringName, new: StringName) -> int:
	var at := -1
	for tile: RoadTile in path:
		if tile.turn_number == turn - 1:
			at = tile.path_index
	assert_eq(path[at].area_id, old, "junction before turn %d" % turn)
	var k := at + 1
	while path[k].type == RoadTile.Type.SET_PIECE:
		assert_eq(path[k].area_id, old, "set piece before turn %d" % turn)
		k += 1
	assert_eq(path[k].type, RoadTile.Type.STRAIGHT)
	assert_eq(path[k].area_id, new, "first tile of turn %d" % turn)
	assert_eq(path[k - 1].area_id, old)
	return k - at - 1


func test_areas_and_set_pieces_switch_at_34_100_200_and_220() -> void:
	for run_seed: int in [1, 2, 3]:
		var path := Fixtures.path_until_turn(RoadGenerator.new(run_seed, Fixtures.schedule()), 230)
		assert_eq(_check_switch(path, 34, &"city", &"rural"), 6, "6 tunnel tiles")
		assert_eq(_check_switch(path, 100, &"rural", &"meadows"), 5, "5 bridge tiles")
		assert_eq(_check_switch(path, 200, &"meadows", &"village"), 0)
		assert_eq(_check_switch(path, 220, &"village", &"desert"), 0)
		var at := 0
		for tile: RoadTile in path:
			if tile.type == RoadTile.Type.SET_PIECE:
				at = tile.path_index
		assert_eq(path[at].set_piece, &"bridge")


func test_the_straight_after_a_switch_uses_the_new_area() -> void:
	# min_straight == max_straight, so every straight length is known.
	var schedule := AreaSchedule.new()
	schedule.entries = [
		_entry(0, _area(&"a", 2, 2)),
		_entry(2, _area(&"b", 9, 9)),
		_entry(4, _area(&"c", 4, 4), &"tunnel", 3)
	]
	var types := ""
	var areas := ""
	for tile: RoadTile in Fixtures.path_until_turn(RoadGenerator.new(1, schedule), 6):
		types += "J" if tile.is_junction() else ("T" if tile.set_piece != &"" else "S")
		areas += tile.area_id
	var s9 := "SSSSSSSSS"
	assert_eq(types, "SSSSJ" + "SSJ" + s9 + "J" + s9 + "J" + "TTT" + "SSSSJ" + "SSSSJ")
	assert_eq(areas, "aaaaa" + "aaa" + "bbbbbbbbbb" + "bbbbbbbbbb" + "bbb" + "ccccc" + "ccccc")


func test_the_last_area_goes_on_forever() -> void:
	var gen := RoadGenerator.new(4, Fixtures.schedule())
	var path := Fixtures.path_until_turn(gen, 1000)
	assert_eq(path[-1].turn_number, 999)
	assert_eq(path[-1].area_id, &"desert")
	assert_eq(gen.current_area.id, &"desert")


## A schedule that changes area at every junction, through a set piece of `piece` tiles and then a
## straight of exactly `straight` tiles: every junction is as far from the last as it allows.
func _gap_schedule(piece: int, straight: int, turns: int) -> AreaSchedule:
	var areas: Array[AreaDef] = [_area(&"a", straight, straight), _area(&"b", straight, straight)]
	var schedule := AreaSchedule.new()
	schedule.entries.append(_entry(0, areas[0]))
	for turn: int in range(1, turns):
		schedule.entries.append(_entry(turn, areas[turn % 2], &"tunnel", piece))
	return schedule


## Takes the path a tile at a time and the right exit at each junction, in CarSim's order: the
## buffer moves on, then the trigger judges. Returns the fewest buffer tiles there were past the
## next junction when the trigger found it, or -1 if it lost it.
static func _least_margin(schedule: AreaSchedule, turns: int) -> int:
	var buffer := RoadBuffer.new(RoadGenerator.new(1, schedule))
	buffer.start()
	var trigger := JunctionTrigger.new(buffer)
	var least := Tuning.BUFFER_AHEAD
	var index := 0
	while trigger.turn_index < turns:
		var junction := trigger.next_junction
		if junction == null:
			return -1
		index += 1
		buffer.on_car_path_index(index)
		if buffer.path_tile(index - 1) != junction:
			continue
		trigger.on_cell_crossed(junction.cell, buffer.path_tile(index).cell, true)
		if trigger.next_junction != null:
			least = mini(least, buffer.last_index() - trigger.next_junction.path_index)
	return least


func test_validate_allows_only_schedules_whose_next_junction_is_in_the_buffer() -> void:
	# H31: the set piece, the longest straight after it and the next junction's own tile. Straights
	# of 20 tiles and a 4-tile tunnel put the next junction 25 tiles on, the most allowed.
	for piece: int in [2, 3, 4, 5, 6]:
		var gap := piece + 20 + 1
		var schedule := _gap_schedule(piece, 20, 60)
		var problems := " | ".join(schedule.validate())
		if gap > Tuning.BUFFER_REFILL_AT:
			assert_string_contains(problems, "can be %d tiles away" % gap)
			continue
		assert_eq(problems, "", "gap %d" % gap)
		assert_gte(_least_margin(schedule, 60), 0, "gap %d: the trigger found every junction" % gap)
	# The limit leaves one tile spare: the next junction is sometimes the buffer's last but one (K1).
	assert_eq(_least_margin(_gap_schedule(4, 20, 60), 60), 1)
	var long := _area(&"long", 2, Tuning.BUFFER_REFILL_AT - 1)
	assert_eq(_problems([_entry(0, long)]), "", "a straight of 24 and the junction")
	long.max_straight += 1
	assert_string_contains(_problems([_entry(0, long)]), "above BUFFER_REFILL_AT")


func test_a_schedule_can_start_in_any_of_its_areas() -> void:
	# For main.gd's --area (K10): the run starts in that area, without the set piece that leads in.
	var schedule := Fixtures.schedule()
	var areas := {}
	for entry: AreaScheduleEntry in schedule.entries:
		areas[entry.area.id] = entry.area
	var expected := {
		&"city":
		[
			[0, &"city", &"", 0],
			[34, &"rural", &"tunnel", 6],
			[100, &"meadows", &"bridge", 5],
			[200, &"village", &"", 0],
			[220, &"desert", &"", 0],
		],
		&"rural":
		[
			[0, &"rural", &"", 0],
			[66, &"meadows", &"bridge", 5],
			[166, &"village", &"", 0],
			[186, &"desert", &"", 0],
		],
		&"meadows": [[0, &"meadows", &"", 0], [100, &"village", &"", 0], [120, &"desert", &"", 0]],
		&"village": [[0, &"village", &"", 0], [20, &"desert", &"", 0]],
		&"desert": [[0, &"desert", &"", 0]],
	}
	for id: StringName in expected:
		var start := schedule.starting_at(id)
		assert_eq(_problems(start.entries), "", id)
		var got: Array = []
		for entry: AreaScheduleEntry in start.entries:
			got.append([entry.turn, entry.area.id, entry.set_piece, entry.set_piece_length])
			assert_same(entry.area, areas[entry.area.id], "%s: the same %s" % [id, entry.area.id])
		assert_eq(got, expected[id], id)
	assert_eq(schedule.entries[1].turn, 34, "the schedule itself stays")
	assert_eq(schedule.entries[1].set_piece, &"tunnel")


func test_a_schedule_cannot_start_in_an_area_it_lacks() -> void:
	var schedule := Fixtures.schedule()
	assert_same(schedule.starting_at(&"moon"), schedule)
	assert_push_error("no area moon")
