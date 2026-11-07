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


func test_validate_reports_broken_schedules() -> void:
	var city := _area(&"city")
	assert_string_contains(_problems([]), "no entries")
	assert_string_contains(_problems([_entry(3, city)]), "not 0")
	assert_string_contains(_problems([_entry(0, city, &"tunnel", 4)]), "has a set piece")
	assert_string_contains(_problems([_entry(0, city), _entry(0, city)]), "does not come after")
	assert_string_contains(_problems([_entry(0, null)]), "no area")
	assert_string_contains(_problems([_entry(0, city), _entry(5, city, &"bridge")]), "disagree")
	assert_string_contains(_problems([_entry(0, _area(&"short", 1, 5))]), "below 2")
	assert_string_contains(_problems([_entry(0, _area(&"flipped", 6, 5))]), "below min_straight")
	assert_eq(_problems([_entry(0, city), _entry(5, city, &"bridge", 3)]), "")


func test_a_broken_schedule_is_reported_by_the_generator() -> void:
	var schedule := AreaSchedule.new()
	schedule.entries = [_entry(0, _area(&"short", 1, 5))]
	RoadGenerator.new(1, schedule)
	assert_push_error("below 2")


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
