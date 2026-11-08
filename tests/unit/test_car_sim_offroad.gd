extends GutTest
## CarSim off the road (plan.md §2.4, IMPLEMENTATION_PLAN.md D6, M2.2) on a real road.

const Fixtures := preload("res://tests/helpers/road_fixtures.gd")
const DELTA := 1.0 / 60.0
## How far from the road's edge _put_by_the_edge() puts the car: less than one step at speed 1.
const EDGE_GAP := 0.005


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


## Puts the car EDGE_GAP from the road's edge, on the right of the centre of straight path tile
## `index`, at speed 1. On the road, it faces away from the road; off it, towards the road. Either
## way, its next step crosses the edge.
func _put_by_the_edge(sim: CarSim, index: int, on_road: bool) -> void:
	var tile := sim.buffer.path_tile(index)
	assert_eq(tile.exits, Heading.bit(tile.heading) | Heading.bit(Heading.opposite(tile.heading)))
	var right := Vector2(Heading.VEC[Heading.right(tile.heading)])
	var side := Tuning.ROAD_HALF_WIDTH + (-EDGE_GAP if on_road else EDGE_GAP)
	sim.pos = Iso.cell_centre(tile.cell) + right * side
	var facing := Heading.right(tile.heading) if on_road else Heading.left(tile.heading)
	sim.angle = facing * PI / 2.0
	sim.speed = 1.0
	if not on_road:
		sim.state = CarSim.State.OFFROAD


## The share of the move from `from` to the car that is off the road, from 2000 points along it.
func _offroad_share(sim: CarSim, from: Vector2) -> float:
	var off := 0
	for i: int in 2000:
		var p := from.lerp(sim.pos, (i + 0.5) / 2000.0)
		var cell := Vector2i(p.floor())
		if not RoadGeometry.is_on_road(sim.buffer.tile_at(cell), p - Vector2(cell)):
			off += 1
	return off / 2000.0


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


func test_a_step_that_leaves_the_road_counts_only_from_the_edge() -> void:
	var sim := _sim(1)
	_put_by_the_edge(sim, 0, true)
	sim.step(DELTA, 0.0)
	assert_eq(sim.state, CarSim.State.OFFROAD)
	var seconds_off := DELTA - EDGE_GAP / sim.speed
	assert_almost_eq(sim.offroad_dist, sim.speed * seconds_off, 1e-6)
	var damage := sim.area.offroad_damage_per_sec * seconds_off
	assert_almost_eq(sim.health, Tuning.START_HEALTH - damage, 1e-4)


func test_a_rejoin_counts_only_if_the_car_reaches_the_road_within_the_limit() -> void:
	# The car cut the first junction's corner and comes back to the road on the path tile after it,
	# with a little more, or a little less, than EDGE_GAP to go to the off-road limit.
	for left: float in [EDGE_GAP + 0.001, EDGE_GAP - 0.001]:
		var sim := _sim(1)
		var junction := sim.trigger.next_junction
		_put_by_the_edge(sim, junction.path_index + 1, false)
		sim.offroad_junction = junction
		var limit := sim.area.offroad_limit_tiles
		sim.offroad_dist = limit - left
		sim.step(DELTA, 0.0)
		var why := "%.3f tiles to the limit" % left
		assert_almost_eq(sim.offroad_dist, limit - left + EDGE_GAP, 1e-6, why)
		if left > EDGE_GAP:
			assert_eq(sim.state, CarSim.State.DRIVING, why)
			assert_signal_emitted_with_parameters(sim.trigger, "turn_completed", [1])
			var damage := sim.area.offroad_damage_per_sec * EDGE_GAP / sim.speed
			assert_almost_eq(sim.health, Tuning.START_HEALTH - damage, 1e-4, why)
		else:
			assert_eq(sim.state, CarSim.State.DISASTER, why)
			assert_signal_emitted_with_parameters(sim.trigger, "disaster_triggered", [junction, -1])
			assert_signal_not_emitted(sim.trigger, "turn_completed", why)
			assert_signal_not_emitted(sim, "offroad_changed", why)


func test_a_step_that_leaves_the_road_before_a_junction_edge_decides_nothing_there() -> void:
	# On the road by each exit edge of the first junction but its entry, the car steps across the
	# road's edge and then the tile's: it leaves the junction off the road.
	for exit: int in 4:
		var sim := _sim(1)
		var junction := sim.trigger.next_junction
		if exit == Heading.opposite(junction.heading) or not junction.has_exit(exit):
			continue
		var out := Vector2(Heading.VEC[exit])
		var side := Vector2(Heading.VEC[Heading.right(exit)])
		var edge := Vector2(junction.cell) + RoadGeometry.EDGE_MID[exit]
		sim.pos = edge - out * 0.006 + side * (Tuning.ROAD_HALF_WIDTH - 0.002)
		sim.angle = exit * PI / 2.0 + PI / 4.0
		sim.speed = 1.0
		var from := sim.pos
		sim.step(DELTA, 0.0)
		var why := "exit %s" % Heading.NAMES[exit]
		assert_eq(Vector2i(sim.pos.floor()), junction.cell + Heading.VEC[exit], why)
		assert_eq(sim.state, CarSim.State.OFFROAD, why)
		assert_eq(sim.offroad_junction, junction, why)
		assert_eq(sim.trigger.next_junction, junction, why)
		assert_signal_not_emitted(sim.trigger, "turn_completed", why)
		assert_signal_not_emitted(sim.trigger, "disaster_triggered", why)
		var share := _offroad_share(sim, from)
		assert_almost_eq(sim.offroad_dist, sim.speed * DELTA * share, 1e-4, why)


func test_a_step_that_cuts_a_corner_of_the_road_counts_the_time_off_it() -> void:
	# The car cuts the inside corner of the first junction's turn within one step, from the entry
	# arm to the exit arm: both ends of the step are on the road, and most of it is off.
	var sim := _sim(1)
	var junction := sim.trigger.next_junction
	var back := Vector2(Heading.VEC[Heading.opposite(junction.heading)])
	var out := Vector2(Heading.VEC[junction.expected_exit])
	var corner := (
		Vector2(junction.cell) + RoadGeometry.CENTRE + (back + out) * Tuning.ROAD_HALF_WIDTH
	)
	var reach := DELTA / sqrt(2.0)
	sim.pos = corner + back * 0.9 * reach - out * 0.1 * reach
	var heading := out - back
	sim.angle = atan2(heading.x, -heading.y)
	sim.speed = 1.0
	var from := sim.pos
	sim.step(DELTA, 0.0)
	var share := _offroad_share(sim, from)
	assert_between(share, 0.7, 0.9, "most of the step is off the road")
	assert_eq(sim.state, CarSim.State.DRIVING)
	assert_signal_emit_count(sim, "offroad_changed", 2)
	assert_eq(get_signal_parameters(sim, "offroad_changed", 0), [true])
	assert_eq(get_signal_parameters(sim, "offroad_changed", 1), [false])
	assert_almost_eq(sim.offroad_dist, sim.speed * DELTA * share, 1e-4)
	var damage := sim.area.offroad_damage_per_sec * DELTA * share
	assert_almost_eq(sim.health, Tuning.START_HEALTH - damage, 1e-3)
	assert_signal_not_emitted(
		sim.trigger, "turn_completed", "a rejoin on the junction decides nothing"
	)
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
