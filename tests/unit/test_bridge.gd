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
	# The car is under World/Props at z 0 (docs/M3.md J5), and the bridge under World/SetPieces,
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


func test_the_waves_of_a_row_are_spread_down_the_river() -> void:
	# Waves that touch show as one long line: a row's waves stay a wave's length apart or more, all
	# the way down. And the nine start evenly spread down the river, no two level.
	for heading: int in [Heading.N, Heading.W]:
		var bridge := _bridge(heading)
		var run := Heading.NAMES[heading]
		var count := Bridge.WAVE_ROWS * Bridge.WAVES_PER_ROW
		var room := bridge.water.size.dot(bridge.across()) - Bridge.WAVE_LENGTH
		var closest := INF
		for frame: int in ceili(room / Tuning.WAVE_SPEED / DELTA):
			for row: int in Bridge.WAVE_ROWS:
				var first := row * Bridge.WAVES_PER_ROW
				for index: int in range(first, first + Bridge.WAVES_PER_ROW):
					for other: int in range(index + 1, first + Bridge.WAVES_PER_ROW):
						var apart := _down(bridge, index, frame) - _down(bridge, other, frame)
						closest = minf(closest, absf(apart) - Bridge.WAVE_LENGTH)
		assert_gte(closest, Bridge.WAVE_LENGTH, "%s: the gap between a row's waves" % run)
		var starts: Array[float] = []
		for index: int in count:
			starts.append(_down(bridge, index, 0))
		starts.sort()
		for k: int in range(1, count):
			var step := starts[k] - starts[k - 1]
			assert_almost_eq(step, room / count, 1e-4, "%s: start %d" % [run, k])


## How far down the river wave `index` is after `frame` physics frames, in tiles.
static func _down(bridge: Bridge, index: int, frame: int) -> float:
	return bridge.wave_rect(index, frame * DELTA).position.dot(bridge.across())


func test_each_wave_is_where_its_rectangle_is() -> void:
	# The waves as drawn: each polygon, back in tile space, is its wave_rect(), and stays in the
	# river all the way down and back to the top.
	for heading: int in [Heading.N, Heading.W]:
		var bridge := _bridge(heading)
		var run := Heading.NAMES[heading]
		var waves: Node2D = bridge.get_node("%Waves")
		simulate(bridge, 90, DELTA)
		for index: int in waves.get_child_count():
			var drawn := _drawn(bridge, waves.get_child(index) as Polygon2D)
			var expected := bridge.wave_rect(index, 90 * DELTA)
			var where := "%s: wave %d" % [run, index]
			assert_almost_eq(drawn.position, expected.position, Vector2(1e-3, 1e-3), where)
			assert_almost_eq(drawn.size, expected.size, Vector2(1e-3, 1e-3), where + "'s size")
		var river := bridge.water.grow(1e-3)
		var outside := 0
		for _frame: int in ceili(Tuning.RIVER_REACH * 2 / Tuning.WAVE_SPEED / DELTA):
			simulate(bridge, 1, DELTA)
			for wave: Node in waves.get_children():
				if not river.encloses(_drawn(bridge, wave as Polygon2D)):
					outside += 1
		assert_eq(outside, 0, "%s: drawn inside the river" % run)


## A wave's polygon as it is drawn, in the bridge's tile space: with its offset, and every
## transform between the wave and the bridge.
static func _drawn(bridge: Bridge, wave: Polygon2D) -> Rect2:
	var to_bridge := bridge.get_global_transform().affine_inverse() * wave.get_global_transform()
	var drawn := Rect2(Iso.world_to_tile(to_bridge * (wave.polygon[0] + wave.offset)), Vector2.ZERO)
	for point: Vector2 in wave.polygon:
		drawn = drawn.expand(Iso.world_to_tile(to_bridge * (point + wave.offset)))
	return drawn


func test_the_bridge_is_never_redrawn() -> void:
	# The waves move; their polygons are drawn once (docs/M2.md §5.7).
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
