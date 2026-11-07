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
