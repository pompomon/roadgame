extends GutTest
## CarSim off the road (plan.md §2.4, IMPLEMENTATION_PLAN.md D6, M2.2) on a real road.

const Fixtures := preload("res://tests/helpers/road_fixtures.gd")
const DELTA := 1.0 / 60.0


func _sim(run_seed: int) -> CarSim:
	var buffer := RoadBuffer.new(RoadGenerator.new(run_seed, Fixtures.schedule()))
	buffer.start()
	var sim := CarSim.new(buffer)
	watch_signals(sim)
	watch_signals(sim.trigger)
	return sim


## Puts the car beside the centre of path tile `index`, off the road and facing along the tile, at
## speed 1: its next step leaves the road there.
func _put_off_road(sim: CarSim, index: int) -> void:
	var tile := sim.buffer.path_tile(index)
	sim.angle = tile.heading * PI / 2.0
	sim.pos = Iso.cell_centre(tile.cell) + _right(sim) * 0.45
	sim.speed = 1.0


func _right(sim: CarSim) -> Vector2:
	return Vector2(cos(sim.angle), sin(sim.angle))


## Steps straight on for up to `seconds`, until the run ends.
func _drive(sim: CarSim, seconds: float) -> void:
	for i: int in roundi(seconds / DELTA):
		sim.step(DELTA, 0.0)
		if sim.is_over():
			return


## Starts the first seed from 1 whose first junction passes `check`.
func _sim_where(check: Callable) -> CarSim:
	for run_seed: int in range(1, 100):
		var sim := _sim(run_seed)
		if check.call(sim.trigger.next_junction, sim.buffer):
			return sim
	fail_test("no seed from 1 to 99 has such a first junction")
	return null


func test_leaving_the_road_does_damage_every_step() -> void:
	var sim := _sim(1)
	var damage := sim.area.offroad_damage_per_sec
	_put_off_road(sim, 0)
	sim.step(DELTA, 0.0)
	assert_eq(sim.state, CarSim.State.OFFROAD)
	assert_signal_emitted_with_parameters(sim, "offroad_changed", [true])
	assert_almost_eq(sim.health, Tuning.START_HEALTH - damage * DELTA, 1e-6)
	_drive(sim, 59 * DELTA)
	assert_almost_eq(sim.health, Tuning.START_HEALTH - damage, 1e-4)
	assert_signal_emit_count(sim, "health_changed", 60)
	assert_signal_emitted_with_parameters(sim, "health_changed", [sim.health])
	assert_signal_emit_count(sim, "offroad_changed", 1)


func test_the_speed_drops_off_the_road() -> void:
	var sim := _sim(1)
	sim.dist_on_straight = 3.0
	var on_road := sim.target_speed()
	_put_off_road(sim, 0)
	sim.step(DELTA, 0.0)
	assert_almost_eq(sim.target_speed(), on_road * sim.area.offroad_speed_mult, 0.01)


func test_rejoining_stops_the_damage() -> void:
	var sim := _sim(1)
	_put_off_road(sim, 0)
	_drive(sim, 0.5)
	var health := sim.health
	sim.pos -= _right(sim) * 0.45
	sim.step(DELTA, 0.0)
	assert_eq(sim.state, CarSim.State.DRIVING)
	assert_signal_emitted_with_parameters(sim, "offroad_changed", [false])
	assert_null(sim.offroad_junction)
	_drive(sim, 0.5)
	assert_eq(sim.health, health)
	assert_signal_not_emitted(sim.trigger, "turn_completed")
	assert_signal_not_emitted(sim.trigger, "disaster_triggered")


func test_the_offroad_limit_on_a_straight_is_a_crash() -> void:
	var sim := _sim(1)
	_put_off_road(sim, 0)
	sim.step(DELTA, 0.0)
	assert_null(sim.offroad_junction, "the first junction is 4 tiles on")
	_drive(sim, 10.0)
	assert_eq(sim.state, CarSim.State.CRASHED)
	assert_signal_emitted_with_parameters(sim, "crashed", [CarSim.OFFROAD])
	assert_gte(sim.offroad_dist, sim.area.offroad_limit_tiles)
	assert_gt(sim.health, 0.0)
	assert_signal_not_emitted(sim.trigger, "disaster_triggered")


func test_running_out_of_health_is_a_crash() -> void:
	var sim := _sim(1)
	sim.health = 5.0
	_put_off_road(sim, 0)
	_drive(sim, 10.0)
	assert_eq(sim.state, CarSim.State.CRASHED)
	assert_signal_emitted_with_parameters(sim, "crashed", [CarSim.HEALTH])
	assert_eq(sim.health, 0.0)
	assert_lt(sim.offroad_dist, sim.area.offroad_limit_tiles)


func test_near_is_at_most_one_step_from_the_junction() -> void:
	for back: int in [1, 2]:
		var sim := _sim(1)
		var junction := sim.trigger.next_junction
		_put_off_road(sim, junction.path_index - back)
		sim.step(DELTA, 0.0)
		assert_eq(sim.state, CarSim.State.OFFROAD)
		var expected: RoadTile = junction if back == 1 else null
		assert_eq(sim.offroad_junction, expected, "%d tiles before the junction" % back)


func test_the_offroad_limit_near_a_junction_is_a_missed_turn() -> void:
	# Straight on at a T-junction with no straight exit, and nothing beyond it.
	var sim := _sim_where(
		func(j: RoadTile, buffer: RoadBuffer) -> bool:
			for k: int in range(1, 4):
				if buffer.tile_at(j.cell + Heading.VEC[j.heading] * k) != null:
					return false
			return true
	)
	var junction := sim.trigger.next_junction
	sim.pos = Iso.cell_centre(junction.cell)
	sim.angle = junction.heading * PI / 2.0
	sim.speed = sim.area.junction_speed
	_drive(sim, 10.0)
	assert_eq(sim.state, CarSim.State.DISASTER)
	assert_signal_emitted_with_parameters(sim.trigger, "disaster_triggered", [junction, -1])
	assert_signal_not_emitted(sim, "crashed")
	assert_gte(sim.offroad_dist, sim.area.offroad_limit_tiles)


func test_rejoining_on_a_dead_end_is_a_disaster_and_the_car_stops() -> void:
	var sim := _sim(1)
	var junction := sim.trigger.next_junction
	var tip: RoadTile = junction.branches[-1]
	_put_off_road(sim, 0)
	sim.step(DELTA, 0.0)
	sim.pos = Iso.cell_centre(tip.cell)
	sim.step(DELTA, 0.0)
	assert_eq(sim.state, CarSim.State.DISASTER, "the rejoin does not overwrite the disaster")
	assert_signal_emitted_with_parameters(
		sim.trigger, "disaster_triggered", [junction, tip.branch_exit]
	)
	for i: int in 30:
		sim.step(DELTA, 0.0)
	assert_eq(sim.speed, 0.0, "stopped")
	assert_eq(sim.state, CarSim.State.DISASTER)
