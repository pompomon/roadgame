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
