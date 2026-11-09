extends GutTest
## The set pieces on the road (IMPLEMENTATION_PLAN.md M4.4): the autopilot drives through the tunnel
## and over the bridge, each drawn while the car is on it, and a river keeps BRIDGE_BANK clear of
## every other road (M4_PLAN.md K15).

const Fixtures := preload("res://tests/helpers/road_fixtures.gd")
const DELTA := 1.0 / 60.0
## Seed 1 meets the bridge after turn 100 (test_area_order.gd), and has left it by turn 105.
const TURNS := 105
## A run to turn 105 takes about 3 minutes of game time.
const MAX_STEPS := 60 * 60 * 6
const SEEDS := 10
## The bridges of Fixtures.bridge_every_turn().
const BRIDGES := 100
## The class of each set piece in the schedule.
const CLASSES := {&"tunnel": &"Tunnel", &"bridge": &"Bridge"}


func test_the_autopilot_drives_through_the_tunnel_and_over_the_bridge() -> void:
	var schedule := Fixtures.schedule()
	var buffer := RoadBuffer.new(RoadGenerator.new(1, schedule))
	var scene: PackedScene = load("res://world/world.tscn")
	var world: WorldRenderer = add_child_autofree(scene.instantiate())
	world.build(schedule)
	world.bind(buffer)
	buffer.start()
	var sim := CarSim.new(buffer)
	var pilot := Autopilot.new(sim)
	var layer: Node2D = world.get_node("%SetPieces")
	var seen: Array[int] = []
	var met: Array[StringName] = []
	var steps_on := {&"tunnel": 0, &"bridge": 0}
	var undrawn := 0
	for i: int in MAX_STEPS:
		sim.step(DELTA, pilot.steer())
		for piece: Node in layer.get_children():
			if not seen.has(piece.get_instance_id()):
				seen.append(piece.get_instance_id())
				var global_name: StringName = piece.get_script().get_global_name()
				met.append(global_name)
		var tile := sim.path_tile
		if tile.type == RoadTile.Type.SET_PIECE:
			steps_on[tile.set_piece] += 1
			if _piece_on(layer, tile) == null:
				undrawn += 1
		if sim.is_over() or sim.trigger.turn_index >= TURNS:
			break
	assert_eq(sim.trigger.turn_index, TURNS)
	assert_false(sim.is_over())
	assert_eq(met, [&"Tunnel", &"Bridge"] as Array[StringName])
	assert_gt(steps_on[&"tunnel"], 0, "the car drove through the tunnel")
	assert_gt(steps_on[&"bridge"], 0, "and over the bridge")
	assert_eq(undrawn, 0, "each was drawn while the car was on it")
	assert_eq(layer.get_child_count(), 0, "and went once the car had left it")


func test_rivers_keep_a_bank_clear_of_every_other_road() -> void:
	# The bank at each end of the river keeps it off the junction before the bridge and the
	# straight after it. Across the run, RIVER_REACH keeps it off the dead end of the junction
	# before last, which can be min_straight + 1 tiles away (D7).
	var nearest := INF
	var nearest_across := INF
	var rivers := 0
	var schedules: Array[AreaSchedule] = [Fixtures.schedule(), Fixtures.bridge_every_turn(BRIDGES)]
	for schedule: AreaSchedule in schedules:
		var last_turn := schedule.entries[-1].turn + 2
		for run_seed: int in SEEDS:
			var gen := RoadGenerator.new(run_seed, schedule)
			var path := Fixtures.path_until_turn(gen, last_turn)
			for run: Array[RoadTile] in _bridge_runs(path):
				rivers += 1
				var gaps := _gaps(gen.occupancy, run)
				nearest = minf(nearest, gaps.x)
				nearest_across = minf(nearest_across, gaps.y)
	assert_eq(rivers, SEEDS * (1 + BRIDGES))
	assert_gte(nearest, Tuning.BRIDGE_BANK, "the nearest road to a river")
	assert_gte(nearest_across, Tuning.BRIDGE_BANK, "the nearest road beside one")
	gut.p(
		(
			"%d rivers; the nearest road %.2f tiles away, beside one %.2f"
			% [rivers, nearest, nearest_across]
		)
	)


## The set piece drawn on `tile`, or null.
static func _piece_on(layer: Node2D, tile: RoadTile) -> SetPiece:
	var centre := Vector2(tile.cell) + Vector2(0.5, 0.5)
	for piece: SetPiece in layer.get_children():
		var global_name: StringName = piece.get_script().get_global_name()
		if piece.rect.has_point(centre) and global_name == CLASSES[tile.set_piece]:
			return piece
	return null


## Each run of bridge tiles on `path`.
static func _bridge_runs(path: Array[RoadTile]) -> Array[Array]:
	var runs: Array[Array] = []
	var run: Array[RoadTile] = []
	for tile: RoadTile in path:
		if tile.set_piece == &"bridge":
			run.append(tile)
		elif not run.is_empty():
			runs.append(run)
			run = []
	return runs


## The gap from the river under `run` to the nearest other road tile in `occupancy`, and to the
## nearest beside the river (level with some of it along the run), in tiles.
static func _gaps(occupancy: OccupancyGrid, run: Array[RoadTile]) -> Vector2:
	var cells := Rect2(run[0].cell, Vector2.ONE).merge(Rect2(run[-1].cell, Vector2.ONE))
	var run_axis := Vector2.AXIS_Y if Heading.VEC[run[0].heading].x == 0 else Vector2.AXIS_X
	var water := Bridge.river(cells, run_axis)
	var area := water.grow(2.0)
	var gaps := Vector2(INF, INF)
	for y: int in range(floori(area.position.y), ceili(area.end.y)):
		for x: int in range(floori(area.position.x), ceili(area.end.x)):
			var tile := occupancy.get_tile(Vector2i(x, y))
			if tile == null or run.has(tile):
				continue
			var gap := _distance(water, Rect2(x, y, 1, 1))
			gaps.x = minf(gaps.x, gap.length())
			if gap[run_axis] == 0.0:
				gaps.y = minf(gaps.y, gap.length())
	return gaps


## How far apart `a` and `b` are along each axis: 0 where they overlap.
static func _distance(a: Rect2, b: Rect2) -> Vector2:
	return Vector2(
		maxf(0.0, maxf(a.position.x - b.end.x, b.position.x - a.end.x)),
		maxf(0.0, maxf(a.position.y - b.end.y, b.position.y - a.end.y))
	)
