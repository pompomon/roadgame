extends GutTest

const W := Tuning.ROAD_HALF_WIDTH
const CORNERS: Array[Vector2] = [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]


func _exits(headings: Array[int]) -> int:
	var exits := 0
	for h: int in headings:
		exits |= Heading.bit(h)
	return exits


func _on(exits: int, local: Vector2) -> bool:
	return RoadGeometry.is_on_road_exits(exits, local)


func test_centre_is_on_road_for_every_tile() -> void:
	for exits: int in range(1, Heading.ALL + 1):
		assert_true(_on(exits, Vector2(0.5, 0.5)), "exits %d" % exits)


func test_straight() -> void:
	var ns := _exits([Heading.N, Heading.S])
	assert_true(_on(ns, Vector2(0.5, 0.0)))
	assert_true(_on(ns, Vector2(0.5, 1.0)))
	assert_true(_on(ns, Vector2(0.5 + W - 0.001, 0.0)), "the road is 2 × ROAD_HALF_WIDTH wide")
	assert_false(_on(ns, Vector2(0.5 + W + 0.001, 0.0)))
	assert_false(_on(ns, Vector2(0.0, 0.5)), "no road on the W edge")
	for corner: Vector2 in CORNERS:
		assert_false(_on(ns, corner), "corner %s" % corner)


func test_dead_end_cap_is_rounded_at_the_centre() -> void:
	var cap := _exits([Heading.S])
	assert_true(_on(cap, Vector2(0.5, 1.0)))
	assert_true(_on(cap, Vector2(0.5, 0.5 - W + 0.001)))
	assert_false(_on(cap, Vector2(0.5, 0.5 - W - 0.001)))
	assert_false(_on(cap, Vector2(0.5 + 0.3, 0.5 - 0.2)), "outside the round end")
	assert_true(_on(cap, Vector2(0.5 + 0.3, 0.6)), "beside the straight part")


func test_t_junction_and_crossroads() -> void:
	var t := _exits([Heading.S, Heading.N, Heading.W])
	assert_true(_on(t, Vector2(0.0, 0.5)))
	assert_false(_on(t, Vector2(1.0, 0.5)), "no road on the E edge of this T")
	var cross := Heading.ALL
	for h: int in 4:
		assert_true(_on(cross, RoadGeometry.EDGE_MID[h]))
	for corner: Vector2 in CORNERS:
		assert_false(_on(cross, corner), "corner %s" % corner)


func test_neighbouring_tiles_meet_at_the_same_width() -> void:
	var ns := _exits([Heading.N, Heading.S])
	for dx: float in [0.0, 0.2, W - 0.001, W + 0.001]:
		assert_eq(_on(ns, Vector2(0.5 + dx, 0.0)), _on(ns, Vector2(0.5 + dx, 1.0)), "dx %f" % dx)


func test_tile_overload() -> void:
	var tile := RoadTile.new(Vector2i.ZERO, RoadTile.Type.STRAIGHT, Heading.N, _exits([0, 2]))
	assert_true(RoadGeometry.is_on_road(tile, Vector2(0.5, 0.5)))
	assert_false(RoadGeometry.is_on_road(tile, Vector2(0.05, 0.5)))
	assert_false(RoadGeometry.is_on_road(null, Vector2(0.5, 0.5)), "no tile: off road")
