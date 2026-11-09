extends GutTest
## The tunnel (IMPLEMENTATION_PLAN.md M4.4) and what it shares with every SetPiece: a block over its
## run, with a mouth on the end face that shows, which draws over the car and fades while the car
## is near (M4_PLAN.md K12).

const SCENE := preload("res://setpieces/tunnel.tscn")
const DELTA := 1.0 / 60.0
## The run's first cell in these tests.
const FIRST := Vector2i(10, 20)


func _tunnel(heading: int, length := 6) -> Tunnel:
	var tunnel: Tunnel = add_child_autofree(SCENE.instantiate())
	var exits := Heading.bit(heading) | Heading.bit(Heading.opposite(heading))
	tunnel.setup(RoadTile.new(FIRST, RoadTile.Type.SET_PIECE, heading, exits), length)
	return tunnel


## Tile-space points of `polygon`'s points that are `height` screen pixels above the ground.
static func _ground_points(polygon: PackedVector2Array, height: float) -> Array[Vector2]:
	var points: Array[Vector2] = []
	for point: Vector2 in polygon:
		points.append(Iso.world_to_tile(point + Vector2(0.0, height)))
	return points


func test_a_set_piece_covers_the_cells_of_its_run() -> void:
	var north := _tunnel(Heading.N)
	assert_eq(north.rect, Rect2(10, 15, 1, 6), "from (10, 20) up to (10, 15)")
	assert_eq(north.axis(), Vector2.AXIS_Y)
	var west := _tunnel(Heading.W, 3)
	assert_eq(west.rect, Rect2(8, 20, 3, 1), "from (10, 20) back to (8, 20)")
	assert_eq(west.axis(), Vector2.AXIS_X)
	assert_eq(west.grown(0.25, 0.5), Rect2(7.5, 19.75, 4, 1.5), "across is y, along is x")


func test_the_rock_covers_the_run_and_a_little_more_across_it() -> void:
	var tunnel := _tunnel(Heading.N)
	var roof_polygon: Polygon2D = tunnel.get_node("%Roof")
	var roof := _ground_points(roof_polygon.polygon, Tuning.TUNNEL_HEIGHT_PX)
	var box := Rect2(roof[0], Vector2.ZERO)
	for point: Vector2 in roof:
		box = box.expand(point)
	var expected := Rect2(10.5 - Tunnel.HALF_WIDTH, 15, Tunnel.HALF_WIDTH * 2, 6)
	assert_almost_eq(box.position, expected.position, Vector2(1e-4, 1e-4))
	assert_almost_eq(box.size, expected.size, Vector2(1e-4, 1e-4))
	assert_between(box.size.x, 1.05, 1.5, "a little wider than the run's cells")


func test_the_mouth_is_in_the_end_face_that_shows() -> void:
	# The faces that show are the +x and +y ones, so the end with the larger coordinate on the run's
	# axis: the entrance of a N or W run.
	for heading: int in [Heading.N, Heading.W]:
		var tunnel := _tunnel(heading)
		var mouth_polygon: Polygon2D = tunnel.get_node("%Mouth")
		var mouth := mouth_polygon.polygon
		var base := _ground_points(mouth.slice(0, 2), 0.0)
		var end := 21.0 if heading == Heading.N else 11.0
		for point: Vector2 in base:
			var along := point.y if heading == Heading.N else point.x
			assert_almost_eq(along, end, 1e-4, "%s: on the end face" % Heading.NAMES[heading])
		assert_almost_eq(base[0].distance_to(base[1]), Tunnel.MOUTH_HALF_WIDTH * 2, 1e-4)
		var top := mouth[3].y - mouth[0].y
		assert_almost_eq(top, -Tuning.TUNNEL_HEIGHT_PX * Tunnel.MOUTH_HEIGHT, 1e-3, "its height")


func test_the_tunnel_draws_over_the_car() -> void:
	# The car is under World/Props at z 0 (M3_PLAN.md J5).
	assert_gt(_tunnel(Heading.N).z_index, 0)


func test_the_tunnel_fades_while_the_car_is_near() -> void:
	var tunnel := _tunnel(Heading.N)
	simulate(tunnel, 1, DELTA)
	assert_almost_eq(tunnel.modulate.a, 1.0, 1e-6, "no car")
	var car: Node2D = add_child_autofree(Node2D.new())
	tunnel.car = car
	var opacities: Array[float] = []
	# Inside, at the mouth, and further and further south of it.
	for at: Vector2 in [Vector2(10.5, 18.0), Vector2(10.5, 21.0), Vector2(10.5, 21.75)]:
		car.position = Iso.tile_to_world(at)
		simulate(tunnel, 1, DELTA)
		opacities.append(tunnel.modulate.a)
	for distance: float in [1.5, Tuning.TUNNEL_FADE_FAR, 4.0]:
		car.position = Iso.tile_to_world(Vector2(10.5, 21.0 + distance))
		simulate(tunnel, 1, DELTA)
		opacities.append(tunnel.modulate.a)
	assert_almost_eq(opacities[0], Tuning.TUNNEL_SEE_THROUGH, 1e-4, "in the tunnel")
	assert_almost_eq(opacities[1], Tuning.TUNNEL_SEE_THROUGH, 1e-4, "at the mouth")
	assert_almost_eq(opacities[2], Tuning.TUNNEL_SEE_THROUGH, 1e-4, "FADE_NEAR away")
	assert_between(opacities[3], Tuning.TUNNEL_SEE_THROUGH + 0.01, 0.99, "on the way")
	assert_almost_eq(opacities[4], 1.0, 1e-6, "FADE_FAR away")
	assert_almost_eq(opacities[5], 1.0, 1e-6, "further")


func test_the_tunnel_is_never_redrawn() -> void:
	# Its polygons are drawn once; it fades by its modulate (M2_PLAN.md §5.7).
	var tunnel := _tunnel(Heading.W)
	var car: Node2D = add_child_autofree(Node2D.new())
	tunnel.car = car
	await wait_process_frames(2)
	var draws: Array[int] = [0]
	for polygon: Node in tunnel.get_children():
		(polygon as Polygon2D).draw.connect(func() -> void: draws[0] += 1)
	for step: int in 12:
		car.position = Iso.tile_to_world(Vector2(13.0 - step * 0.5, 20.5))
		await wait_physics_frames(1)
	await wait_process_frames(2)
	assert_lt(tunnel.modulate.a, 1.0, "it faded")
	assert_eq(draws[0], 0, "no redraws")
