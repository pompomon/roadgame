extends GutTest
## The bridge (IMPLEMENTATION_PLAN.md M4.4): a river under its run, between banks, a deck and two
## railings, and waves that drift down the river without leaving it.

const SCENE := preload("res://setpieces/bridge.tscn")
const DELTA := 1.0 / 60.0
const FIRST := Vector2i(10, 20)


func _bridge(heading: int, length := 5) -> Bridge:
	var bridge: Bridge = add_child_autofree(SCENE.instantiate())
	var exits := Heading.bit(heading) | Heading.bit(Heading.opposite(heading))
	bridge.setup(RoadTile.new(FIRST, RoadTile.Type.SET_PIECE, heading, exits), length)
	return bridge


func test_the_river_flows_across_the_run_between_its_banks() -> void:
	var north := _bridge(Heading.N)
	var bank := Tuning.BRIDGE_BANK
	var reach := Tuning.RIVER_REACH
	assert_eq(north.water, Rect2(10.5 - reach, 16 + bank, reach * 2, 5 - bank * 2))
	assert_eq(north.across(), Vector2.RIGHT, "towards the viewer")
	var west := _bridge(Heading.W)
	assert_eq(west.water, Rect2(6 + bank, 20.5 - reach, 5 - bank * 2, reach * 2))
	assert_eq(west.across(), Vector2.DOWN)
	for bridge: Bridge in [north, west]:
		var river: Polygon2D = bridge.get_node("%River")
		assert_eq(river.polygon.size(), 4)
		var drawn := Rect2(Iso.world_to_tile(river.polygon[0]), Vector2.ZERO)
		for point: Vector2 in river.polygon:
			drawn = drawn.expand(Iso.world_to_tile(point))
		var run := Heading.NAMES[bridge.heading]
		var within := Vector2.ONE * 1e-4
		assert_almost_eq(drawn.position, bridge.water.position, within, "%s: drawn" % run)
		assert_almost_eq(drawn.end, bridge.water.end, within, "%s: drawn" % run)
		assert_true(river.visible and bridge.get_node("%Waves").visible, "%s: shown" % run)


func test_a_run_too_short_for_the_river_is_an_error() -> void:
	# The banks take a whole tile: the waves' rows need WAVE_ROWS * WAVE_WIDTH more.
	var short := _bridge(Heading.N, 1)
	assert_push_error("no room for the river between the banks of a 1-tile run")
	assert_false(short.get_node("%River").visible, "no river")
	assert_false(short.get_node("%Waves").visible, "and no waves")
	assert_true(short.get_node("%Deck").visible, "only the deck and the railings")
	var shortest := _bridge(Heading.N, 2)
	assert_gte(shortest.water.size.y, Bridge.WAVE_ROWS * Bridge.WAVE_WIDTH, "2 tiles have room")
	assert_true(shortest.get_node("%River").visible)


func test_the_near_railing_draws_over_the_car_and_the_rest_under_it() -> void:
	# The car is under World/Props at z 0 (M3_PLAN.md J5), and the bridge under World/SetPieces,
	# below the road.
	var bridge := _bridge(Heading.N)
	assert_eq(bridge.z_index, 0)
	for node: Node in bridge.get_children():
		var expected := 1 if node.name == &"NearRailing" else 0
		assert_eq((node as Node2D).z_index, expected, node.name)
	var near: Polygon2D = bridge.get_node("%NearRailing")
	var far: Polygon2D = bridge.get_node("%FarRailing")
	assert_almost_eq(Iso.world_to_tile(near.polygon[0]).x, 10.5 + Bridge.RAILING, 1e-4, "east")
	assert_almost_eq(Iso.world_to_tile(far.polygon[0]).x, 10.5 - Bridge.RAILING, 1e-4, "west")


func test_the_waves_drift_down_the_river_and_never_leave_it() -> void:
	for heading: int in [Heading.N, Heading.W]:
		var bridge := _bridge(heading, 2)
		var waves: Node2D = bridge.get_node("%Waves")
		assert_eq(waves.get_child_count(), Bridge.WAVE_ROWS * Bridge.WAVES_PER_ROW)
		var outside := 0
		var lowest := INF
		var highest := -INF
		for frame: int in 600:
			for index: int in waves.get_child_count():
				var wave := bridge.wave_rect(index, frame * DELTA)
				if not bridge.water.encloses(wave):
					outside += 1
				var down := wave.position.dot(bridge.across())
				lowest = minf(lowest, down)
				highest = maxf(highest, down + Bridge.WAVE_LENGTH)
		var top := bridge.water.position.dot(bridge.across())
		var run := Heading.NAMES[heading]
		assert_eq(outside, 0, "%s: inside the river" % run)
		assert_almost_eq(lowest, top, 0.02, "%s: from its top" % run)
		assert_almost_eq(highest, top + Tuning.RIVER_REACH * 2, 0.02, "%s: to its bottom" % run)


func test_each_wave_is_where_its_rectangle_is() -> void:
	var bridge := _bridge(Heading.N)
	simulate(bridge, 90, DELTA)
	var waves: Node2D = bridge.get_node("%Waves")
	for index: int in waves.get_child_count():
		var at := Iso.world_to_tile((waves.get_child(index) as Node2D).position)
		var expected := bridge.wave_rect(index, 90 * DELTA).position
		assert_almost_eq(at, expected, Vector2(1e-3, 1e-3), "wave %d" % index)


func test_the_bridge_is_never_redrawn() -> void:
	# The waves move; their polygons are drawn once (M2_PLAN.md §5.7).
	var bridge := _bridge(Heading.W)
	await wait_process_frames(2)
	var draws: Array[int] = [0]
	# The waves after the first are copies, which the scene doesn't own.
	var polygons: Array[Node] = bridge.find_children("*", "Polygon2D", true, false)
	assert_eq(polygons.size(), 4 + Bridge.WAVE_ROWS * Bridge.WAVES_PER_ROW)
	for polygon: Node in polygons:
		(polygon as Polygon2D).draw.connect(func() -> void: draws[0] += 1)
	var wave: Node2D = bridge.get_node("%Waves").get_child(0)
	var before := wave.position
	await wait_physics_frames(20)
	await wait_process_frames(2)
	assert_ne(wave.position, before, "the waves moved")
	assert_eq(draws[0], 0, "no redraws")
