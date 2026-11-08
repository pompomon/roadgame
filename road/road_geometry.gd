class_name RoadGeometry
## The road surface of a tile is the union of capsules from the tile centre to the midpoint of each
## exit edge, Tuning.ROAD_HALF_WIDTH wide (IMPLEMENTATION_PLAN.md D4). Positions are tile-local,
## in [0, 1]².

const CENTRE := Vector2(0.5, 0.5)
## Edge midpoints by heading: N, E, S, W.
const EDGE_MID: Array[Vector2] = [
	Vector2(0.5, 0.0), Vector2(1.0, 0.5), Vector2(0.5, 1.0), Vector2(0.0, 0.5)
]


static func is_on_road(tile: RoadTile, local: Vector2) -> bool:
	return tile != null and is_on_road_exits(tile.exits, local)


static func is_on_road_exits(exits: int, local: Vector2) -> bool:
	return distance_to_centreline(exits, local) <= Tuning.ROAD_HALF_WIDTH


## Distance from `local` to the nearest centre-to-exit segment, or INF if `exits` is 0. The grey-box
## atlas draws the road and its edge line from this.
static func distance_to_centreline(exits: int, local: Vector2) -> float:
	var best := INF
	for h: int in 4:
		if exits & Heading.bit(h) != 0:
			var closest := Geometry2D.get_closest_point_to_segment(local, CENTRE, EDGE_MID[h])
			best = minf(best, local.distance_to(closest))
	return best


## The parts of the straight move from `from` to `to` (tile-local, and it may leave the tile) that
## are on the road of a tile with `exits`: [start, end] fractions of the move, in order and apart.
## Exact, so a move that cuts a corner of the road has two, however short the cut.
static func on_road_spans(exits: int, from: Vector2, to: Vector2) -> Array[Vector2]:
	var spans: Array[Vector2] = []
	for h: int in 4:
		if exits & Heading.bit(h) != 0:
			var span := _capsule_span(EDGE_MID[h], from, to)
			if span.x <= span.y:
				spans.append(span)
	spans.sort()
	var merged: Array[Vector2] = []
	for span: Vector2 in spans:
		if not merged.is_empty() and span.x <= merged[-1].y:
			merged[-1] = Vector2(merged[-1].x, maxf(merged[-1].y, span.y))
		else:
			merged.append(span)
	return merged


## The fractions of the move from `from` to `to`, within [0, 1], that are on the capsule from the
## centre to `end`, or a span whose start is past its end if none are. The capsule is the rectangle
## along its segment and the discs at the segment's ends. Each of those meets the move's line in
## one span, and the capsule is convex, so their spans join into one.
static func _capsule_span(end: Vector2, from: Vector2, to: Vector2) -> Vector2:
	var move := to - from
	var rel := from - CENTRE
	var along := (end - CENTRE).normalized()
	var across := along.orthogonal()
	var span := _intersect(
		_between(rel.dot(along), move.dot(along), 0.0, CENTRE.distance_to(end)),
		_between(rel.dot(across), move.dot(across), -Tuning.ROAD_HALF_WIDTH, Tuning.ROAD_HALF_WIDTH)
	)
	for point: Vector2 in [CENTRE, end]:
		var disc := _in_circle(from - point, move, Tuning.ROAD_HALF_WIDTH)
		if span.x > span.y:
			span = disc
		elif disc.x <= disc.y:
			span = Vector2(minf(span.x, disc.x), maxf(span.y, disc.y))
	return _intersect(span, Vector2(0.0, 1.0))


## The fractions t with `low` <= `start` + `rate` * t <= `high`.
static func _between(start: float, rate: float, low: float, high: float) -> Vector2:
	if rate == 0.0:
		return Vector2(-INF, INF) if low <= start and start <= high else Vector2(INF, -INF)
	var a := (low - start) / rate
	var b := (high - start) / rate
	return Vector2(minf(a, b), maxf(a, b))


## The fractions t with |`rel` + `move` * t| <= `radius`.
static func _in_circle(rel: Vector2, move: Vector2, radius: float) -> Vector2:
	var a := move.length_squared()
	var c := rel.length_squared() - radius * radius
	if a == 0.0:
		return Vector2(-INF, INF) if c <= 0.0 else Vector2(INF, -INF)
	var b := rel.dot(move)
	var discriminant := b * b - a * c
	if discriminant < 0.0:
		return Vector2(INF, -INF)
	var root := sqrt(discriminant)
	return Vector2((-b - root) / a, (-b + root) / a)


static func _intersect(a: Vector2, b: Vector2) -> Vector2:
	return Vector2(maxf(a.x, b.x), minf(a.y, b.y))
