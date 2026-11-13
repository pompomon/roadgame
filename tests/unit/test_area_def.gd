extends GutTest
## AreaDef's junction chances (ROADGEN_PLAN.md R3) and its day (DAYNIGHT_PLAN.md C7).
## test_area_schedule.gd tests the rest of validate(), through the schedule that reports it.


static func _problems(area: AreaDef) -> String:
	return " | ".join(area.validate())


static func _area(id: StringName) -> AreaDef:
	var area := AreaDef.new()
	area.id = id
	return area


func test_validate_reports_junction_chances_that_cannot_be() -> void:
	# A junction is of one kind, so the chances of the kinds other than the T are each 0..1, and
	# they add up to 1 at most.
	for field: String in ["cross_junction_chance", "side_road_chance", "decoy_chance"]:
		var area := _area(&"bad")
		area.cross_junction_chance = 0.0
		area.set(field, -0.1)
		assert_eq(_problems(area), "bad: %s is outside 0..1" % field, field)
		area.set(field, 1.1)
		var both := "bad: %s is outside 0..1 | bad: the junction chances add up to more than 1"
		assert_eq(_problems(area), both % field, field)
		area.set(field, 1.0)
		assert_eq(_problems(area), "", field + " can be 1")
	var full := _area(&"full")
	full.cross_junction_chance = 0.34
	full.side_road_chance = 0.56
	full.decoy_chance = 0.1
	assert_gt(full.cross_junction_chance + full.side_road_chance + full.decoy_chance, 1.0)
	assert_eq(_problems(full), "", "1 but for rounding")
	full.decoy_chance = 0.11
	assert_eq(_problems(full), "full: the junction chances add up to more than 1")


func test_validate_reports_a_day_too_short_to_follow() -> void:
	# The light can't follow a shorter day at LIGHT_MAX_RATE (DAYNIGHT_PLAN.md C7).
	var area := _area(&"short")
	area.day_seconds = DayCycle.least_day_seconds()
	assert_eq(_problems(area), "", "the least day")
	area.day_seconds = DayCycle.least_day_seconds() - 0.01
	var expected := "short: day_seconds is below %.2f" % DayCycle.least_day_seconds()
	assert_eq(_problems(area), expected)
	area.day_seconds = 0.0
	assert_eq(_problems(area), expected, "no day")
