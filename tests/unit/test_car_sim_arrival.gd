extends GutTest
## The car at the end of the road (ENDGAME_PLAN.md §5.2): it arrives as it enters the finish, and
## rolls to a stop on it, straightening up, ARRIVE_STOP_SHORT before the centre of its last tile,
## however fast it came.

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
