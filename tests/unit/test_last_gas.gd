extends GutTest
## Last Gas (ENDGAME_PLAN.md §5.15): the filling station by a pit stop's straight, which has no set
## piece of its own. It stands on the straight's far side, between its ends, where no road paints
## over it and no prop shows over it, and draws under the car.

const SCENE := preload("res://setpieces/last_gas.tscn")
const FIRST := Vector2i(10, 20)
const HEADINGS: Array[int] = [Heading.N, Heading.W]
## The shortest straight the rules allow (AreaDef.min_straight), two of the Desert's, and the
## Coast's.
const LENGTHS: Array[int] = [2, 3, 8, 20]


func _piece(heading: int, length: int) -> LastGas:
	var piece: LastGas = add_child_autofree(SCENE.instantiate())
	piece.setup(_tile(FIRST, heading), length)
	return piece


static func _tile(cell: Vector2i, heading: int) -> RoadTile:
	var exits := Heading.bit(heading) | Heading.bit(Heading.opposite(heading))
	return RoadTile.new(cell, RoadTile.Type.STRAIGHT, heading, exits)


## Where `polygon`'s point `index` shows, as the point of the ground that shows there: how far along
## the straight from its start, and across it from its centreline, towards its near side, in tiles.
## A point raised h screen pixels shows where the ground does h / TILE_H tiles farther along and as
## much farther across, towards the far side.
static func _shown(piece: LastGas, polygon: Polygon2D, index: int) -> Vector2:
	var at := Iso.world_to_tile(polygon.polygon[index] + polygon.position) - piece.point(0.0, 0.0)
	return Vector2(at.dot(piece.forward()), at.dot(piece.sideways()))


static func _polygons(piece: LastGas) -> Array[Polygon2D]:
	var polygons: Array[Polygon2D] = []
	for child: Node in piece.get_children():
		polygons.append(child as Polygon2D)
	return polygons


func test_it_shows_beside_the_straight_between_its_ends_clear_of_the_road_and_the_props() -> void:
	# The road paints ROAD_HALF_WIDTH either side of its centreline, and the junctions at the
	# straight's ends, and the road the next turn takes, past them. The nearest props stand past
	# set_piece_margin() tiles of the straight (PropLayout.near_set_piece()), at the edge of a tile,
	# and a prop's frame shows as far towards the road as the ground PROP_MAX_SIZE.x / 2 pixels
	# beside its foot and PROP_BELOW below it.
	var margin := PropLayout.set_piece_margin() + 0.5
	var prop_reach := Tuning.PROP_MAX_SIZE.x * 0.5 / Iso.TILE_W
	prop_reach += float(Tuning.PROP_BELOW) / Iso.TILE_H
	var far := -margin + prop_reach
	assert_almost_eq(far, -2.125, 1e-6, "the props' reach")
	for heading: int in HEADINGS:
		for length: int in LENGTHS:
			var piece := _piece(heading, length)
			var count := 0
			for polygon: Polygon2D in _polygons(piece):
				for index: int in polygon.polygon.size():
					var shown := _shown(piece, polygon, index)
					var where := (
						"%s %d: %s %d at %s"
						% [Heading.NAMES[heading], length, polygon.name, index, shown]
					)
					assert_between(shown.x, 0.0, float(length), where)
					assert_gt(shown.y, far, where + ", clear of the props")
					assert_lt(shown.y, -Tuning.ROAD_HALF_WIDTH, where + ", clear of the road")
					count += 1
			assert_gt(count, 70, "every point of every part")


func test_the_shacks_door_and_window_face_the_road() -> void:
	# Each stands in the shack's front, the face towards the road, which shows (§5.15).
	var lows: Dictionary[StringName, float] = {&"Door": 0.0, &"Window": LastGas.WINDOW_PX.x}
	for heading: int in HEADINGS:
		var piece := _piece(heading, 3)
		var middle := piece.run_length() * 0.5
		for part: StringName in lows:
			var polygon: Polygon2D = piece.get_node("%" + part)
			for index: int in 2:
				# Its foot, `low` pixels up, shows where the ground does low / TILE_H tiles along
				# and across from it.
				var low := lows[part]
				var on := _shown(piece, polygon, index) + Vector2(-low, low) / Iso.TILE_H
				var where := "%s: %s %d at %s" % [Heading.NAMES[heading], part, index, on]
				assert_almost_eq(on.y, LastGas.SHACK.end.y, 1e-5, where + ", in its front")
				assert_between(on.x - middle, LastGas.SHACK.position.x, LastGas.SHACK.end.x, where)


func test_it_draws_under_the_car() -> void:
	var piece := _piece(Heading.N, 3)
	assert_eq(piece.z_index, 0)
	for polygon: Polygon2D in _polygons(piece):
		assert_eq(polygon.z_index, 0, polygon.name)
		assert_true(polygon.z_as_relative, polygon.name)
	assert_eq(_polygons(piece).size(), 19)


func test_it_is_never_redrawn() -> void:
	var piece := _piece(Heading.W, 3)
	await wait_process_frames(2)
	var draws: Array[int] = [0]
	for polygon: Polygon2D in _polygons(piece):
		polygon.draw.connect(func() -> void: draws[0] += 1)
	await wait_physics_frames(10)
	await wait_process_frames(2)
	assert_eq(draws[0], 0, "no redraws")
