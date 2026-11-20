extends GutTest

const Fixtures := preload("res://tests/helpers/road_fixtures.gd")
## The least share of an area's junctions that stay T's (docs/ROADGEN.md E8, Q2).
const LEAST_T_SHARE := 0.25


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
	assert_eq(turns, [0, 20, 44, 68, 78, 100] as Array[int])


## The City, where a run learns the pattern, has no side roads or decoys. Every later area has
## both, and keeps at least LEAST_T_SHARE of its junctions as T's (docs/ROADGEN.md E8, §5.5). The
## Coast, the home stretch, has no junction (docs/ENDGAME.md §5.8), and the endless road leaves it
## out.
func test_side_roads_and_decoys_skip_the_city_and_leave_a_quarter_of_t_junctions() -> void:
	for area: AreaDef in Fixtures.endless().areas():
		if area.id == &"city":
			assert_eq(area.side_road_chance, 0.0, "the City has no side roads")
			assert_eq(area.decoy_chance, 0.0, "the City has no decoys")
		else:
			assert_gt(area.side_road_chance, 0.0, "%s has side roads" % area.id)
			assert_gt(area.decoy_chance, 0.0, "%s has decoys" % area.id)
		var t_share := 1.0 - area.cross_junction_chance - area.side_road_chance - area.decoy_chance
		assert_true(
			t_share > LEAST_T_SHARE or is_equal_approx(t_share, LEAST_T_SHARE),
			"%s: %.2f of its junctions are T's" % [area.id, t_share]
		)


## SPEEDUP_PLAN.md E2: past the City and Rural the road turns less and runs straighter. From the
## Meadows on, each area's shortest and longest straights are longer than Rural's, the home
## stretch's too.
func test_from_the_meadows_on_the_straights_are_longer_than_rurals() -> void:
	var road := Fixtures.schedule()
	var rural: AreaDef = road.entries[1].area
	assert_eq(rural.id, &"rural")
	for entry: AreaScheduleEntry in road.entries.slice(2):
		var area := entry.area
		assert_gt(area.min_straight, rural.min_straight, "%s's shortest straight" % area.id)
		assert_gt(area.max_straight, rural.max_straight, "%s's longest straight" % area.id)


func test_areas_lists_each_area_once_in_the_order_a_run_reaches_them() -> void:
	# The Atlas's cards and the Book of Legends' rows (M5.5, docs/ENDGAME.md §5.10).
	var ids: Array[StringName] = []
	for area: AreaDef in Fixtures.schedule().areas():
		ids.append(area.id)
	assert_eq(
		ids, [&"city", &"rural", &"meadows", &"village", &"desert", &"coast"] as Array[StringName]
	)
	var city := _area(&"city")
	var rural := _area(&"rural")
	var schedule := AreaSchedule.new()
	schedule.entries = [_entry(0, city), _entry(5, rural), _entry(9, city), _entry(12, null)]
	assert_eq(schedule.areas(), [city, rural] as Array[AreaDef], "once each, and no null")


func test_every_area_of_the_game_has_a_pool_of_disasters() -> void:
	# A wrong turn in any area ends in a disaster (docs/M3.md J6). The Coast, a home stretch, has no
	# junction and no pool (docs/ENDGAME.md Q1, W19).
	var areas := 0
	for entry: AreaScheduleEntry in Fixtures.endless().entries:
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


func test_validate_reports_broken_schedules() -> void:
	var city := _area(&"city")
	assert_string_contains(_problems([]), "no entries")
	assert_string_contains(_problems([_entry(3, city)]), "not 0")
	assert_string_contains(_problems([_entry(0, city, &"tunnel", 4)]), "has a set piece")
	var stop := _entry(0, city)
	stop.pit_stop = true
	assert_string_contains(_problems([stop]), "has a pit stop")
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


func test_areas_and_set_pieces_switch_at_20_44_68_and_78() -> void:
	for run_seed: int in [1, 2, 3]:
		var path := Fixtures.path_until_turn(RoadGenerator.new(run_seed, Fixtures.schedule()), 90)
		assert_eq(_check_switch(path, 20, &"city", &"rural"), 6, "6 tunnel tiles")
		assert_eq(_check_switch(path, 44, &"rural", &"meadows"), 5, "5 bridge tiles")
		assert_eq(_check_switch(path, 68, &"meadows", &"village"), 0)
		assert_eq(_check_switch(path, 78, &"village", &"desert"), 0)
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


func test_a_pit_stop_is_its_areas_set_piece_or_else_its_first_straight() -> void:
	# docs/ENDGAME.md §5.15: the way into the area. min_straight == max_straight, as above.
	var schedule := AreaSchedule.new()
	schedule.entries = [
		_entry(0, _area(&"a", 2, 2)),
		_entry(2, _area(&"b", 3, 3)),
		_entry(4, _area(&"c", 4, 4), &"tunnel", 3),
		_entry(6, _area(&"d", 2, 2)),
	]
	schedule.entries[1].pit_stop = true
	schedule.entries[2].pit_stop = true
	var stops := ""
	for tile: RoadTile in Fixtures.path_until_turn(RoadGenerator.new(1, schedule), 8):
		stops += "P" if tile.pit_stop else ("J" if tile.is_junction() else "-")
	assert_eq(stops, "----J" + "--J" + "PPPJ" + "---J" + "PPP" + "----J" + "----J" + "--J" + "--J")


func test_the_last_area_goes_on_forever() -> void:
	var gen := RoadGenerator.new(4, Fixtures.endless())
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
	# docs/M2.md H31: the set piece, the longest straight after it and the next junction's own
	# tile. Straights of BUFFER_REFILL_AT - 5 tiles and a 4-tile tunnel put the next junction
	# BUFFER_REFILL_AT tiles on, the most allowed.
	var straight := Tuning.BUFFER_REFILL_AT - 5
	for piece: int in [2, 3, 4, 5, 6]:
		var gap := piece + straight + 1
		var schedule := _gap_schedule(piece, straight, 60)
		var problems := " | ".join(schedule.validate())
		if gap > Tuning.BUFFER_REFILL_AT:
			assert_string_contains(problems, "can be %d tiles away" % gap)
			continue
		assert_eq(problems, "", "gap %d" % gap)
		assert_gte(_least_margin(schedule, 60), 0, "gap %d: the trigger found every junction" % gap)
	# The limit leaves one tile spare: the next junction is sometimes the buffer's last but one (K1).
	assert_eq(_least_margin(_gap_schedule(4, straight, 60), 60), 1)
	var long := _area(&"long", 2, Tuning.BUFFER_REFILL_AT - 1)
	assert_eq(_problems([_entry(0, long)]), "", "the longest straight and the junction")
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
			[20, &"rural", &"tunnel", 6],
			[44, &"meadows", &"bridge", 5],
			[68, &"village", &"", 0],
			[78, &"desert", &"", 0],
			[100, &"coast", &"", 0],
		],
		&"rural":
		[
			[0, &"rural", &"", 0],
			[24, &"meadows", &"bridge", 5],
			[48, &"village", &"", 0],
			[58, &"desert", &"", 0],
			[80, &"coast", &"", 0],
		],
		&"meadows":
		[
			[0, &"meadows", &"", 0],
			[24, &"village", &"", 0],
			[34, &"desert", &"", 0],
			[56, &"coast", &"", 0],
		],
		&"village": [[0, &"village", &"", 0], [10, &"desert", &"", 0], [32, &"coast", &"", 0]],
		&"desert": [[0, &"desert", &"", 0], [22, &"coast", &"", 0]],
		&"coast": [[0, &"coast", &"", 0]],
	}
	for id: StringName in expected:
		var start := schedule.starting_at(id)
		assert_eq(_problems(start.entries), "", id)
		var got: Array = []
		for entry: AreaScheduleEntry in start.entries:
			got.append([entry.turn, entry.area.id, entry.set_piece, entry.set_piece_length])
			assert_same(entry.area, areas[entry.area.id], "%s: the same %s" % [id, entry.area.id])
		assert_eq(got, expected[id], id)
	assert_eq(schedule.entries[1].turn, 20, "the schedule itself stays")
	assert_eq(schedule.entries[1].set_piece, &"tunnel")


## The turn, the area and the set piece of each of `schedule`'s pit stops.
static func _pit_stops(schedule: AreaSchedule) -> Array:
	var stops: Array = []
	for entry: AreaScheduleEntry in schedule.entries:
		if entry.pit_stop:
			stops.append([entry.turn, entry.area.id, entry.set_piece])
	return stops


func test_the_games_pit_stops() -> void:
	# docs/ENDGAME.md §5.15, E13: on the way out, the tunnel, the bridge, and Last Gas as the Desert
	# starts; on the Road Home, Last Gas as the Village starts, the bridge and the tunnel. A road
	# that starts in a later area, as a Departure does, keeps those after its first area.
	var out := Fixtures.schedule()
	var outs: Array = [[20, &"rural", &"tunnel"], [44, &"meadows", &"bridge"], [78, &"desert", &""]]
	assert_eq(_pit_stops(out), outs)
	var home := Fixtures.schedule_home()
	var homes: Array = [[22, &"village", &""], [56, &"rural", &"bridge"], [80, &"city", &"tunnel"]]
	assert_eq(_pit_stops(home), homes)
	var later: Array = [[24, &"meadows", &"bridge"], [58, &"desert", &""]]
	assert_eq(_pit_stops(out.starting_at(&"rural")), later)
	assert_eq(_pit_stops(out.starting_at(&"desert")), [])
	later = [[34, &"rural", &"bridge"], [58, &"city", &"tunnel"]]
	assert_eq(_pit_stops(home.starting_at(&"village")), later)
	assert_eq(_pit_stops(out.endless()), outs, "Keep Driving's road")
	assert_eq(_pit_stops(out), outs, "the schedule itself stays")


func test_a_schedule_cannot_start_in_an_area_it_lacks() -> void:
	var schedule := Fixtures.schedule()
	assert_same(schedule.starting_at(&"moon"), schedule)
	assert_push_error("no area moon")


## docs/ENDGAME.md §5.1: a road with a finish ends in its last area, at a turn the last area has
## reached.
func test_validate_reports_a_finish_that_cannot_be_reached() -> void:
	var schedule := Fixtures.endless()
	schedule.finish_turn = 300
	assert_eq(" | ".join(schedule.validate()), "finish_turn is 300, but there is no finish")
	schedule.finish = &"pier"
	assert_eq(schedule.validate(), PackedStringArray())
	schedule.finish_turn = 77
	assert_eq(
		" | ".join(schedule.validate()), "the finish (turn 77) comes before the last area (turn 78)"
	)
	schedule.finish_turn = 78
	assert_eq(schedule.validate(), PackedStringArray(), "a finish as the last area starts")


func test_a_road_can_end_early_or_never_and_keep_its_areas() -> void:
	var schedule := Fixtures.endless()
	var short := schedule.ending_at(60, &"pier")
	assert_eq(short.validate(), PackedStringArray())
	assert_eq([short.finish, short.finish_turn], [&"pier", 60])
	assert_eq(short.entries, schedule.entries.slice(0, 3), "the areas it reaches")
	assert_false(schedule.has_finish(), "the schedule itself stays")
	var endless := short.endless()
	assert_false(endless.has_finish())
	assert_eq(endless.finish_turn, 0)
	assert_eq(endless.entries, short.entries)
	var home := Fixtures.schedule_home()
	assert_true(home.ending_at(3, &"pier").mirrored, "the mirror stays")
	assert_true(home.endless().mirrored)


func test_a_road_that_starts_in_a_later_area_ends_as_many_turns_sooner() -> void:
	var schedule := Fixtures.schedule().ending_at(90, &"pier")
	var rural := schedule.starting_at(&"rural")
	assert_eq([rural.finish, rural.finish_turn], [&"pier", 70])
	assert_eq(schedule.starting_at(&"desert").finish_turn, 12)
	assert_eq(rural.validate(), PackedStringArray())
	assert_false(Fixtures.endless().starting_at(&"rural").has_finish())


## docs/ENDGAME.md W17: a home stretch, a last area that starts at the finish's turn, has no
## junction and no legend, so an endless road leaves it out, and the area before it goes on.
func test_an_endless_road_leaves_out_the_home_stretch() -> void:
	var road := Fixtures.set_piece_schedule(3, &"tunnel", 3)
	road.finish = &"pier"
	road.finish_turn = 3
	var endless := road.endless()
	assert_false(endless.has_finish())
	assert_eq(endless.entries, road.entries.slice(0, 1), "without the home stretch")
	assert_eq(endless.validate(), PackedStringArray())
	road.finish_turn = 4
	assert_eq(road.endless().entries, road.entries, "a last area with junctions stays")
	road.finish_turn = 0
	road.entries[1].turn = 0
	assert_eq(road.endless().entries, road.entries.slice(0, 1), "never without an area")


## docs/ENDGAME.md §5.6: the Road Home is the road back, from the Desert to the City, mirrored.
func test_the_road_home_is_valid_and_runs_the_other_way() -> void:
	var home := Fixtures.schedule_home()
	assert_eq(home.validate(), PackedStringArray())
	assert_true(home.mirrored)
	assert_eq([home.finish, home.finish_turn], [&"home", 100])
	var areas: Array[StringName] = []
	for area: AreaDef in home.areas():
		areas.append(area.id)
	# The game's road backwards, without its home stretch, the Coast.
	var forward: Array[StringName] = []
	for area: AreaDef in Fixtures.endless().areas():
		forward.push_front(area.id)
	assert_eq(areas, forward)


## docs/ENDGAME.md §5.8, E7: the game's road ends at the pier after its 100th turn (SPEEDUP_PLAN.md
## E1). The Coast starts at that turn, a home stretch: one straight, as long as the Inspector allows
## (AreaDef), and no set piece before it or junction in it, so no pool. The endless road leaves it
## out (W17).
func test_the_games_road_ends_at_the_pier_after_its_100th_turn() -> void:
	var road := Fixtures.schedule()
	assert_eq([road.finish, road.finish_turn], [&"pier", 100])
	var coast: AreaScheduleEntry = road.entries[-1]
	assert_eq([coast.area.id, coast.turn, coast.set_piece_length], [&"coast", 100, 0])
	assert_eq([coast.area.min_straight, coast.area.max_straight], [20, 20])
	assert_eq(coast.area.disasters.size(), 0, "no junction, so no legend")
	assert_eq(road.endless().entries, road.entries.slice(0, -1), "the endless road leaves it out")
