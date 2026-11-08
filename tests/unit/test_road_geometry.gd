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


## 1 if `t` is in one of `spans`, 0 if not, -1 if it is too near the end of a span to tell.
func _in_spans(spans: Array[Vector2], t: float) -> int:
	for span: Vector2 in spans:
		if absf(t - span.x) < 1e-4 or absf(t - span.y) < 1e-4:
			return -1
		if span.x < t and t < span.y:
			return 1
	return 0


func test_on_road_spans_are_the_parts_of_a_move_on_the_road() -> void:
	# Random moves in and around the tile, for every set of exits: a point of the move is on the road
	# just when it is in a span, and the spans are in order and apart.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var wrong: Array[String] = []
	for exits: int in range(0, Heading.ALL + 1):
		for i: int in 100:
			var from := Vector2(rng.randf_range(-0.2, 1.2), rng.randf_range(-0.2, 1.2))
			var to := from + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.01, 1.0)
			var spans := RoadGeometry.on_road_spans(exits, from, to)
			var move := "exits %d, %s to %s" % [exits, from, to]
			var last_end := -1.0
			for span: Vector2 in spans:
				if not (last_end < span.x and span.x <= span.y and span.x >= 0.0 and span.y <= 1.0):
					wrong.append("%s: spans %s" % [move, spans])
				last_end = span.y
			for k: int in 51:
				var t := k / 50.0
				var inside := _in_spans(spans, t)
				if inside != -1 and (inside == 1) != _on(exits, from.lerp(to, t)):
					wrong.append("%s: t %.2f" % [move, t])
	assert_eq(wrong.size(), 0, ", ".join(wrong.slice(0, 5)))


func test_a_move_that_cuts_a_corner_of_the_road_has_two_spans() -> void:
	# Across the inside corner of a W/E/S junction, from the W arm to the S arm: 0.001 tiles inside
	# the road at each end, and 0.011 tiles across each way.
	var wes := _exits([Heading.W, Heading.E, Heading.S])
	var spans := RoadGeometry.on_road_spans(wes, Vector2(0.170, 0.819), Vector2(0.181, 0.830))
	assert_eq(spans.size(), 2)
	if spans.size() == 2:
		assert_eq(spans[0].x, 0.0)
		assert_almost_eq(spans[0].y, 1.0 / 11.0, 1e-4)
		assert_almost_eq(spans[1].x, 10.0 / 11.0, 1e-4)
		assert_eq(spans[1].y, 1.0)


func test_a_move_of_no_length_is_on_the_road_or_off_it() -> void:
	var ns := _exits([Heading.N, Heading.S])
	var on := RoadGeometry.on_road_spans(ns, Vector2(0.5, 0.3), Vector2(0.5, 0.3))
	assert_eq(on, [Vector2(0.0, 1.0)] as Array[Vector2])
	assert_eq(RoadGeometry.on_road_spans(ns, Vector2(0.9, 0.3), Vector2(0.9, 0.3)).size(), 0)
