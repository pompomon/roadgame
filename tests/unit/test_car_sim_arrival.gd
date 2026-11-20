extends GutTest
## The car at the end of the road (docs/ENDGAME.md §5.2): it arrives as it enters the finish, and
## rolls to a stop on it, steering onto its centreline, ARRIVE_STOP_SHORT before the centre of its
## last tile, however fast it came.

const Fixtures := preload("res://tests/helpers/road_fixtures.gd")
const DELTA := 1.0 / 60.0
const SEEDS: Array[int] = [1, 2, 3, 42, 12345]

## The car's speed as it arrived.
var _arrival_speed := -1.0
## The steps from the arrival to the stop.
var _roll_steps := 0


## The autopilot on the game's road, ending at the pier after `turns` turns, until the car stops
## after the run is over. With `at_speed`, the car is at that speed from `before` tiles before the
## finish: at the speed cap, as a long run's car can be at the end of a long last straight, or
## slow, as after a rejoin.
func _drive(run_seed: int, turns: int, at_speed := -1.0, before := 2.0) -> CarSim:
	var schedule := Fixtures.schedule().ending_at(turns, &"pier")
	var buffer := RoadBuffer.new(RoadGenerator.new(run_seed, schedule))
	buffer.start()
	var sim := CarSim.new(buffer)
	watch_signals(sim)
	_arrival_speed = -1.0
	_roll_steps = 0
	sim.arrived.connect(func() -> void: _arrival_speed = sim.speed)
	var pilot := Autopilot.new(sim)
	for i: int in 60 * 60 * 5:
		var finish := buffer.generator.finish_index
		if at_speed >= 0.0 and finish != -1 and sim.progress >= finish - before:
			sim.dist_total = 1e6
			sim.dist_on_straight = 1e6
			sim.speed = at_speed
			at_speed = -1.0
		sim.step(DELTA, pilot.steer())
		if sim.state == CarSim.State.ARRIVED and sim.speed > 0.0:
			_roll_steps += 1
		if sim.is_over() and sim.speed == 0.0:
			break
	return sim


## The autopilot on the game's road, ending at the pier after 2 turns, until the car is in the tile
## before the finish; then the car is put `along` tiles along the road from the centre of the
## finish's first tile and `across` to its right, turned by `turn` from the road's heading, at
## `at_speed`, and drives on with no steering until it stops. Returns the car, and the largest
## distance from the finish's centreline and the least and the most along it while it rolled.
func _come_onto_finish(
	run_seed: int, along: float, across: float, turn: float, at_speed: float
) -> Array:
	var schedule := Fixtures.schedule().ending_at(2, &"pier")
	var buffer := RoadBuffer.new(RoadGenerator.new(run_seed, schedule))
	buffer.start()
	var sim := CarSim.new(buffer)
	var pilot := Autopilot.new(sim)
	for i: int in 60 * 60 * 5:
		var index := buffer.generator.finish_index
		if index != -1 and sim.progress >= index - 1.2:
			break
		sim.step(DELTA, pilot.steer())
	var finish := buffer.path_tile(buffer.generator.finish_index)
	if finish == null:
		fail_test("seed %d: the road ends" % run_seed)
		return [sim, INF, Vector2(-INF, INF)]
	var axis := Vector2(Heading.VEC[finish.heading])
	var side := Vector2(-axis.y, axis.x)
	var centre := Iso.cell_centre(finish.cell)
	sim.pos = centre + axis * along + side * across
	sim.angle = finish.heading * PI / 2.0 + turn
	sim.dist_total = 1e6
	sim.dist_on_straight = 1e6
	sim.speed = at_speed
	var widest := 0.0
	var span := Vector2(INF, -INF)
	for i: int in 60 * 10:
		sim.step(DELTA, 0.0)
		if sim.state == CarSim.State.ARRIVED:
			var rel := sim.pos - centre
			widest = maxf(widest, absf(rel.dot(side)))
			span = Vector2(minf(span.x, rel.dot(axis)), maxf(span.y, rel.dot(axis)))
		if sim.is_over() and sim.speed == 0.0:
			break
	return [sim, widest, span]


## How far short of the centre of the finish's last tile the car stopped, along the road.
static func _short(sim: CarSim) -> float:
	var last := sim.buffer.path_tile(sim.buffer.generator.finish_index + Tuning.FINISH_TILES - 1)
	return (Iso.cell_centre(last.cell) - sim.pos).dot(Vector2(Heading.VEC[last.heading]))


func test_the_car_arrives_and_rolls_to_a_stop_on_the_finish() -> void:
	for run_seed: int in SEEDS:
		var why := "seed %d" % run_seed
		var sim := _drive(run_seed, 6)
		assert_eq(sim.state, CarSim.State.ARRIVED, why)
		assert_signal_emit_count(sim, "arrived", 1, why)
		assert_eq(sim.trigger.turn_index, 6, why)
		assert_eq(sim.health, Tuning.START_HEALTH, why)
		assert_eq(sim.speed, 0.0, why)
		assert_almost_eq(_short(sim), Tuning.ARRIVE_STOP_SHORT, 0.1, why + ": where it stops")
		var last := sim.buffer.path_tile(sim.buffer.generator.finish_index + 7)
		var axis := Vector2(Heading.VEC[last.heading])
		assert_almost_eq(sim.forward(), axis, Vector2.ONE * 1e-3, why + ": straight")


## However fast the car comes, the finish is room enough to stop on, no harder than BRAKE.
func test_the_car_stops_on_the_finish_from_the_speed_cap() -> void:
	for run_seed: int in SEEDS:
		var why := "seed %d" % run_seed
		var sim := _drive(run_seed, 2, Tuning.GLOBAL_SPEED_CAP)
		assert_eq(sim.state, CarSim.State.ARRIVED, why)
		assert_almost_eq(_arrival_speed, Tuning.GLOBAL_SPEED_CAP, 1e-6, why + ": at the cap")
		assert_almost_eq(_short(sim), Tuning.ARRIVE_STOP_SHORT, 0.1, why + ": where it stops")
	var room := Tuning.FINISH_TILES - 1 - Tuning.ARRIVE_STOP_SHORT + 0.5
	assert_lte(Tuning.GLOBAL_SPEED_CAP ** 2 / (2.0 * room), Tuning.BRAKE, "no harder than BRAKE")


## A slow car stops sooner, within ARRIVE_ROLL_SECONDS, on the finish: the arrival screen, which
## shows ARRIVAL_SECONDS after the arrival, finds it stopped.
func test_a_slow_car_stops_on_the_finish_within_arrive_roll_seconds() -> void:
	for run_seed: int in SEEDS:
		var why := "seed %d" % run_seed
		var sim := _drive(run_seed, 2, 0.2, 0.6)
		assert_eq(sim.state, CarSim.State.ARRIVED, why)
		assert_lt(_arrival_speed, 1.0, why + ": it came slowly")
		assert_lte(_roll_steps * DELTA, Tuning.ARRIVE_ROLL_SECONDS + DELTA, why)
		var finish := sim.buffer.path_tile(sim.buffer.generator.finish_index)
		var past := (sim.pos - Iso.cell_centre(finish.cell)).dot(
			Vector2(Heading.VEC[finish.heading])
		)
		assert_between(past, -0.5, Tuning.FINISH_TILES - 1.0, why + ": on the finish")
	assert_lt(Tuning.ARRIVE_ROLL_SECONDS, Tuning.ARRIVAL_SECONDS, "stopped before the screen")


## However the car comes onto the finish, at an angle and heading for its edge, or across it from
## the side after leaving the road, it steers itself onto the centreline as the autopilot does, and
## stops on the finish: never past its road's edges or its ends. With room, it stops centred and
## straight; from the side onto its last tile, it stops at once, still on it.
func test_the_car_stops_on_the_finish_however_it_comes_onto_it() -> void:
	# Where the car is put, from the centre of the finish's first tile, along and to its right, how
	# far it turns from the road's heading, in degrees, and its speed.
	var cases := [
		[-0.55, 0.25, 17.0, Tuning.GLOBAL_SPEED_CAP],
		[-0.55, -0.25, -17.0, Tuning.GLOBAL_SPEED_CAP],
		[1.0, 0.6, -90.0, 3.5],
		[1.0, -0.6, 60.0, 3.5],
		[Tuning.FINISH_TILES - 1.0, 0.6, -90.0, 3.5],
	]
	for run_seed: int in [1, 2]:
		for case: Array in cases:
			var why := "seed %d, %s" % [run_seed, case]
			var roll := _come_onto_finish(run_seed, case[0], case[1], deg_to_rad(case[2]), case[3])
			var sim: CarSim = roll[0]
			assert_eq(sim.state, CarSim.State.ARRIVED, why)
			assert_eq(sim.speed, 0.0, why)
			assert_lte(roll[1], Tuning.ROAD_HALF_WIDTH + 1e-6, why + ": within the road's edges")
			var span: Vector2 = roll[2]
			assert_gte(span.x, -0.5 - 1e-6, why + ": past the finish's start")
			assert_lte(span.y, Tuning.FINISH_TILES - 0.5 + 1e-6, why + ": short of its end")
			if case[0] < Tuning.FINISH_TILES - 1.0:
				var finish := sim.buffer.path_tile(sim.buffer.generator.finish_index)
				var axis := Vector2(Heading.VEC[finish.heading])
				var across := (sim.pos - Iso.cell_centre(finish.cell)).dot(Vector2(-axis.y, axis.x))
				assert_almost_eq(across, 0.0, 0.05, why + ": centred")
				assert_almost_eq(sim.forward(), axis, Vector2.ONE * 0.035, why + ": straight")
