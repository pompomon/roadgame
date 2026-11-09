@abstract class_name SetPiece
extends Node2D
## A set piece (plan.md §3.6, IMPLEMENTATION_PLAN.md M4.4): a scene drawn over a run of straight
## path tiles with no junction. The WorldRenderer adds it once the buffer has made the whole run,
## calls setup() at once, and frees it with the run's last tile. Its polygons get their points in
## setup(), before their first draw, and are never redrawn: they move and fade only by their
## transforms and modulate (M2_PLAN.md §5.7). Their points are World pixels, so the root stays at
## the origin. It may follow the car, and must work without one.

## The run's car, or null. The WorldRenderer sets it.
var car: Node2D
## The run's cells, in tile space.
var rect := Rect2()
## The run's heading (Heading).
var heading := -1


## Builds the set piece on the `length` path tiles from `first_tile` on, which all head the same
## way. Call it once, in the frame that adds the set piece to the tree.
func setup(first_tile: RoadTile, length: int) -> void:
	heading = first_tile.heading
	var last := first_tile.cell + Heading.VEC[heading] * (length - 1)
	rect = Rect2(Vector2(first_tile.cell), Vector2.ONE).merge(Rect2(Vector2(last), Vector2.ONE))
	_build()


## The run's axis in tile space: Vector2.AXIS_X for E and W, Vector2.AXIS_Y for N and S.
func axis() -> int:
	return Vector2.AXIS_X if Heading.VEC[heading].x != 0 else Vector2.AXIS_Y


## `rect` grown by `across` tiles on both sides across the run and by `along` tiles at both ends.
func grown(across: float, along: float) -> Rect2:
	if axis() == Vector2.AXIS_X:
		return rect.grow_individual(along, across, along, across)
	return rect.grow_individual(across, along, across, along)


## How far the car is from the run's cells, in tiles: 0 on them, and INF without a car.
func car_distance() -> float:
	if car == null:
		return INF
	var at := Iso.world_to_tile(car.position)
	return at.distance_to(at.clamp(rect.position, rect.end))


## The World pixels of the corners of tile-space rectangle `r`, raised by `height` screen pixels,
## in screen order: top, right, bottom, left.
static func corners(r: Rect2, height := 0.0) -> PackedVector2Array:
	var up := Vector2(0.0, -height)
	return PackedVector2Array(
		[
			Iso.tile_to_world(r.position) + up,
			Iso.tile_to_world(Vector2(r.end.x, r.position.y)) + up,
			Iso.tile_to_world(r.end) + up,
			Iso.tile_to_world(Vector2(r.position.x, r.end.y)) + up,
		]
	)


## The World pixels of an upright face on the tile-space line from `from` to `to`, from `low` to
## `high` screen pixels above the ground.
static func face(from: Vector2, to: Vector2, low: float, high: float) -> PackedVector2Array:
	return PackedVector2Array(
		[
			Iso.tile_to_world(from) + Vector2(0.0, -low),
			Iso.tile_to_world(to) + Vector2(0.0, -low),
			Iso.tile_to_world(to) + Vector2(0.0, -high),
			Iso.tile_to_world(from) + Vector2(0.0, -high),
		]
	)


## Gives the set piece's polygons their points, for `rect` and `heading`.
@abstract func _build() -> void
