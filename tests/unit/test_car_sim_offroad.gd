extends GutTest
## CarSim off the road (plan.md §2.4, IMPLEMENTATION_PLAN.md D6, M2.2) on a real road.

const Fixtures := preload("res://tests/helpers/road_fixtures.gd")
const DELTA := 1.0 / 60.0
## How far from the road's edge _put_by_the_edge() puts the car: less than one step at speed 1.
const EDGE_GAP := 0.005
## Two areas, the second with less off-road damage than the first.
const DESERT: AreaDef = preload("res://areas/desert.tres")
const MEADOWS: AreaDef = preload("res://areas/meadows.tres")


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


## Puts the car at `p` as if it had driven there. `tile` is the correct-path tile whose cell it was
## in last: by default, the one in p's cell.
func _place(sim: CarSim, p: Vector2, tile: RoadTile = null) -> void:
	sim.pos = p
	sim.path_tile = tile if tile != null else sim.buffer.tile_at(Vector2i(p.floor()))
	sim.buffer.on_car_path_index(sim.path_tile.path_index)
	sim.progress = CarSim.path_progress(sim.path_tile, p)


## The share of the move from `from` to the car that is off the road, from 2000 points along it.
func _offroad_share(sim: CarSim, from: Vector2) -> float:
	var off := 0
	for i: int in 2000:
		var p := from.lerp(sim.pos, (i + 0.5) / 2000.0)
		var cell := Vector2i(p.floor())
		if not RoadGeometry.is_on_road(sim.buffer.tile_at(cell), p - Vector2(cell)):
			off += 1
	return off / 2000.0


## A schedule with area `first` up to the first junction and `second` from its exit tile on.
func _two_areas(first: AreaDef, second: AreaDef) -> AreaSchedule:
	var schedule := AreaSchedule.new()
	for k: int in 2:
		var entry := AreaScheduleEntry.new()
		entry.turn = k
		entry.area = first if k == 0 else second
		schedule.entries.append(entry)
	return schedule


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


func test_off_the_road_the_car_brakes_for_the_junction_too() -> void:
	# At the speed cap, 0.6 tiles before the first junction's centre and just off the road's right
	# edge: whether it turns back onto the road before the junction tile or stays off the road, the
	# car enters that tile at junction_speed at most.
	for turn_in: float in [0.2, 0.0]:
		var sim := _sim(1)
		var junction := sim.trigger.next_junction
		var along := Vector2(Heading.VEC[junction.heading])
		var right := Vector2(Heading.VEC[Heading.right(junction.heading)])
		var side := right * (Tuning.ROAD_HALF_WIDTH + EDGE_GAP)
		_place(sim, Iso.cell_centre(junction.cell) - along * 0.6 + side)
		sim.angle = junction.heading * PI / 2.0 - turn_in
		sim.speed = Tuning.GLOBAL_SPEED_CAP
		sim.state = CarSim.State.OFFROAD
		sim.offroad_junction = junction
		for i: int in 60:
			sim.step(DELTA, 0.0)
			if Vector2i(sim.pos.floor()) == junction.cell or sim.is_over():
				break
		var why := "turning in by %.1f rad" % turn_in
		assert_eq(Vector2i(sim.pos.floor()), junction.cell, why)
		assert_eq(sim.state != CarSim.State.OFFROAD, turn_in > 0.0, why + ": back on the road")
		assert_lte(sim.speed, sim.area.junction_speed, why)


func test_a_path_tile_that_a_step_passes_through_counts_as_reached() -> void:
	# Off the road, the car steps across the outer corner of the first junction's turn: into the exit
	# tile, the first of the second area, and on into the cell beside it, which is off the path.
	var areas := Fixtures.schedule().entries
	var buffer := RoadBuffer.new(RoadGenerator.new(1, _two_areas(areas[0].area, areas[1].area)))
	buffer.start()
	var sim := CarSim.new(buffer)
	watch_signals(sim)
	var junction := sim.trigger.next_junction
	var exit_tile := buffer.path_tile(junction.path_index + 1)
	assert_ne(exit_tile.area_id, sim.area.id, "the exit tile is the first of the second area")
	var beside := exit_tile.cell + Heading.VEC[junction.heading]
	assert_null(buffer.tile_at(beside), "the cell beside the exit tile is off the road")
	var out := Vector2(Heading.VEC[junction.expected_exit])
	var on := Vector2(Heading.VEC[junction.heading])
	var corner := Iso.cell_centre(junction.cell) + (out + on) * 0.5
	_place(sim, corner - out * 0.003 - on * 0.01)
	var move := out * 0.013 + on * 0.02
	sim.angle = atan2(move.x, -move.y)
	sim.speed = move.length() / DELTA
	sim.state = CarSim.State.OFFROAD
	var from := sim.pos
	sim.step(DELTA, 0.0)
	var cells: Array[Vector2i] = [exit_tile.cell, beside]
	assert_eq(CarSim.cells_crossed(from, sim.pos), cells)
	assert_eq(sim.path_tile, exit_tile)
	assert_eq(buffer.car_index(), exit_tile.path_index)
	assert_almost_eq(sim.progress, CarSim.path_progress(exit_tile, sim.pos), 1e-9)
	assert_eq(sim.area.id, exit_tile.area_id)
	assert_signal_emitted_with_parameters(sim, "area_changed", [sim.area])
	assert_eq(sim.state, CarSim.State.OFFROAD)


func test_off_the_road_the_time_before_a_new_area_counts_at_the_old_areas_rates() -> void:
	# Off the road beside the first junction's exit, the car steps straight on into the exit tile,
	# the first of an area with less damage, halfway through the step. The first half counts at the
	# old area's rate, so with health for a whole step in the new area but not for this one, the
	# car still runs out. Whether it runs out after the new area or before it, the end of the run
	# sees the car where the step ends: on the exit tile, in the new area, with progress past any
	# the junction's tile can give.
	var old_area := DESERT
	var new_area := MEADOWS
	var old_damage := old_area.offroad_damage_per_sec
	var new_damage := new_area.offroad_damage_per_sec
	assert_gt(old_damage, new_damage)
	var schedule := _two_areas(old_area, new_area)
	var cost := (old_damage + new_damage) / 2.0 * DELTA
	var before_new_area := old_damage * DELTA / 4.0
	for health: float in [Tuning.START_HEALTH, (cost + new_damage * DELTA) / 2.0, before_new_area]:
		var buffer := RoadBuffer.new(RoadGenerator.new(1, schedule))
		buffer.start()
		var sim := CarSim.new(buffer)
		watch_signals(sim)
		var junction := sim.trigger.next_junction
		var exit_tile := buffer.path_tile(junction.path_index + 1)
		assert_eq(exit_tile.area_id, new_area.id, "the exit tile is the first of the new area")
		var out := Vector2(Heading.VEC[junction.expected_exit])
		var side := Vector2(Heading.VEC[Heading.right(junction.expected_exit)])
		var edge := Iso.cell_centre(junction.cell) + out * 0.5
		# At the speed it drives at off the road by a junction, half a step before the exit edge.
		sim.speed = old_area.junction_speed * old_area.offroad_speed_mult
		_place(sim, edge - out * sim.speed * DELTA / 2.0 + side * 0.45)
		sim.angle = junction.expected_exit * PI / 2.0
		sim.state = CarSim.State.OFFROAD
		sim.health = health
		var seen := []
		# Through a WeakRef: a handler that held the car would form a cycle with it, which leaks.
		var car: WeakRef = weakref(sim)
		var see := func() -> void:
			var at_end := car.get_ref() as CarSim
			seen.append([at_end.progress, at_end.path_tile.path_index, at_end.area.id])
		sim.crashed.connect(see.unbind(1))
		var from := sim.pos
		sim.step(DELTA, 0.0)
		var why := "health %.3f" % health
		var cells: Array[Vector2i] = [exit_tile.cell]
		assert_eq(CarSim.cells_crossed(from, sim.pos), cells, why)
		assert_eq(_offroad_share(sim, from), 1.0, why + ": all off the road")
		var t := (edge - from).dot(out) / (sim.pos - from).dot(out)
		assert_almost_eq(t, 0.5, 0.01, why + ": into the new area halfway")
		if health == Tuning.START_HEALTH:
			var expected := health - (old_damage * t + new_damage * (1.0 - t)) * DELTA
			assert_almost_eq(sim.health, expected, 1e-9, why)
			assert_eq(sim.area.id, new_area.id, why)
			assert_eq(sim.state, CarSim.State.OFFROAD, why)
			assert_eq(seen, [], why)
		else:
			assert_eq(sim.state, CarSim.State.CRASHED, why)
			assert_signal_emitted_with_parameters(sim, "crashed", [CarSim.HEALTH])
			var progress := CarSim.path_progress(exit_tile, sim.pos)
			assert_gt(progress, junction.path_index + 0.5, why + ": on into the exit tile")
			assert_eq(seen, [[progress, exit_tile.path_index, new_area.id]], why)
			assert_signal_emitted_with_parameters(sim, "area_changed", [new_area])


func test_a_rejoin_that_ends_the_run_sees_the_car_where_the_step_ends() -> void:
	# Off the road beside the first junction's exit, the car steps back onto the road about a
	# quarter of the way through the step, still in the junction's tile, and on into the exit tile
	# about halfway, the first of a new area. Unless the time off the road before the rejoin ends
	# the run, it counts at the old area's rate, and the car crosses into the exit tile on the road
	# and completes the turn. If it ends the run, by health or by the off-road limit, the end of the
	# run sees the car where the step ends: on the exit tile, in the new area.
	var old_area := DESERT
	var new_area := MEADOWS
	var schedule := _two_areas(old_area, new_area)
	for ending: StringName in [&"", CarSim.HEALTH, CarSim.MISSED_TURN]:
		var buffer := RoadBuffer.new(RoadGenerator.new(1, schedule))
		buffer.start()
		var sim := CarSim.new(buffer)
		watch_signals(sim)
		watch_signals(sim.trigger)
		var junction := sim.trigger.next_junction
		var exit_tile := buffer.path_tile(junction.path_index + 1)
		assert_eq(exit_tile.area_id, new_area.id, "the exit tile is the first of the new area")
		var out := Vector2(Heading.VEC[junction.expected_exit])
		var side := Vector2(Heading.VEC[Heading.right(junction.expected_exit)])
		var edge := Iso.cell_centre(junction.cell) + out * 0.5
		# At the speed it drives at off the road by a junction, towards the road at 30 degrees.
		sim.speed = old_area.junction_speed * old_area.offroad_speed_mult
		var move := (out * cos(PI / 6.0) - side * sin(PI / 6.0)) * sim.speed * DELTA
		var start := edge - out * move.dot(out) / 2.0
		start += side * (Tuning.ROAD_HALF_WIDTH - move.dot(side) / 4.0)
		_place(sim, start, junction)
		sim.angle = atan2(move.x, -move.y)
		sim.state = CarSim.State.OFFROAD
		sim.offroad_junction = junction
		if ending == CarSim.HEALTH:
			sim.health = old_area.offroad_damage_per_sec * DELTA / 8.0
		elif ending == CarSim.MISSED_TURN:
			sim.offroad_dist = old_area.offroad_limit_tiles - sim.speed * DELTA / 8.0
		var seen := []
		# Through a WeakRef: a handler that held the car would form a cycle with it, which leaks.
		var car: WeakRef = weakref(sim)
		var see := func() -> void:
			var at_end := car.get_ref() as CarSim
			seen.append([at_end.progress, at_end.path_tile.path_index, at_end.area.id])
		sim.crashed.connect(see.unbind(1))
		sim.trigger.disaster_triggered.connect(see.unbind(2))
		var from := sim.pos
		sim.step(DELTA, 0.0)
		var why := "ending %s" % ending
		var cells: Array[Vector2i] = [exit_tile.cell]
		assert_eq(CarSim.cells_crossed(from, sim.pos), cells, why)
		var t := (edge - from).dot(out) / (sim.pos - from).dot(out)
		assert_between(t, 0.45, 0.55, why + ": into the exit tile about halfway")
		var off := _offroad_share(sim, from)
		assert_between(off, 0.2, 0.3, why + ": back on the road about a quarter of the way")
		assert_eq(sim.path_tile, exit_tile, why)
		assert_eq(sim.area.id, new_area.id, why)
		assert_signal_emitted_with_parameters(sim, "area_changed", [new_area])
		var progress := CarSim.path_progress(exit_tile, sim.pos)
		assert_gt(progress, junction.path_index + 0.5, why + ": on into the exit tile")
		assert_eq(sim.progress, progress, why)
		if ending == &"":
			assert_eq(sim.state, CarSim.State.DRIVING, why)
			assert_signal_emitted_with_parameters(sim.trigger, "turn_completed", [1])
			var damage := old_area.offroad_damage_per_sec * DELTA * off
			assert_almost_eq(sim.health, Tuning.START_HEALTH - damage, 1e-3, why)
			assert_eq(seen, [], why)
			continue
		assert_eq(seen, [[progress, exit_tile.path_index, new_area.id]], why)
		if ending == CarSim.HEALTH:
			assert_eq(sim.state, CarSim.State.CRASHED, why)
			assert_signal_emitted_with_parameters(sim, "crashed", [CarSim.HEALTH])
		else:
			assert_eq(sim.state, CarSim.State.DISASTER, why)
			assert_signal_emitted_with_parameters(sim.trigger, "disaster_triggered", [junction, -1])


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


func test_near_is_measured_from_the_cell_after_the_step_that_leaves_the_road() -> void:
	# The car steps off the road's right edge by the edge between the two tiles before the first
	# junction, then across that edge: forwards from 2 steps away to 1, or backwards from 1 to 2.
	for forward: bool in [true, false]:
		var sim := _sim_where(
			func(j: RoadTile, buffer: RoadBuffer) -> bool:
				var before := j.cell - Heading.VEC[j.heading] * 2
				return j.path_index >= 2 and buffer.path_tile(j.path_index - 2).cell == before
		)
		var junction := sim.trigger.next_junction
		var along := Vector2(Heading.VEC[junction.heading])
		var right := Vector2(Heading.VEC[Heading.right(junction.heading)])
		var edge := Iso.cell_centre(junction.cell) - along * 1.5
		var way := 1.0 if forward else -1.0
		sim.pos = edge - along * way * 0.006 + right * (Tuning.ROAD_HALF_WIDTH - 0.002)
		var heading := along * way + right
		sim.angle = atan2(heading.x, -heading.y)
		sim.speed = 1.0
		sim.step(DELTA, 0.0)
		var why := "forwards" if forward else "backwards"
		var end_cell := junction.cell - Heading.VEC[junction.heading] * (1 if forward else 2)
		assert_eq(Vector2i(sim.pos.floor()), end_cell, why)
		assert_eq(sim.state, CarSim.State.OFFROAD, why)
		var expected: RoadTile = junction if forward else null
		assert_eq(sim.offroad_junction, expected, why)
		sim.offroad_dist = sim.area.offroad_limit_tiles - 0.001
		sim.step(DELTA, 0.0)
		if forward:
			assert_eq(sim.state, CarSim.State.DISASTER, why)
			assert_signal_emitted_with_parameters(sim.trigger, "disaster_triggered", [junction, -1])
			assert_signal_not_emitted(sim, "crashed", why)
		else:
			assert_eq(sim.state, CarSim.State.CRASHED, why)
			assert_signal_emitted_with_parameters(sim, "crashed", [CarSim.OFFROAD])
			assert_signal_not_emitted(sim.trigger, "disaster_triggered", why)


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


func test_a_step_that_ends_the_run_measures_the_progress_first() -> void:
	# Off the road in the dead end on the right of the first junction, the car steps along the
	# junction's heading back onto the dead end's road, a wrong turn. With almost no health left, it
	# crashes on the way there instead. Either way, the end of the run sees the progress after the
	# step, though the step enters no other cell.
	for health: float in [Tuning.START_HEALTH, 0.001]:
		var sim := _sim(1)
		var junction := sim.trigger.next_junction
		var exit := Heading.right(junction.heading)
		assert_true(junction.has_exit(exit) and exit != junction.expected_exit, "a wrong exit")
		var along := Vector2(Heading.VEC[junction.heading])
		var into_dead_end := Vector2(Heading.VEC[exit]) * 0.75
		var behind := along * (Tuning.ROAD_HALF_WIDTH + EDGE_GAP)
		_place(sim, Iso.cell_centre(junction.cell) + into_dead_end - behind, junction)
		sim.angle = junction.heading * PI / 2.0
		sim.speed = 3.0
		sim.health = health
		sim.state = CarSim.State.OFFROAD
		sim.offroad_junction = junction
		var seen := []
		# Through a WeakRef: a handler that held the car would form a cycle with it, which leaks.
		var car: WeakRef = weakref(sim)
		var see := func() -> void: seen.append((car.get_ref() as CarSim).progress)
		sim.crashed.connect(see.unbind(1))
		sim.trigger.disaster_triggered.connect(see.unbind(2))
		var before := sim.progress
		sim.step(DELTA, 0.0)
		var why := "health %.3f" % health
		var after := CarSim.path_progress(junction, sim.pos)
		assert_gt(after, before + 0.04, why + ": the step moved the car on")
		assert_eq(seen, [after], why)
		if health == Tuning.START_HEALTH:
			assert_eq(sim.state, CarSim.State.DISASTER, why)
			assert_signal_emitted_with_parameters(
				sim.trigger, "disaster_triggered", [junction, exit]
			)
		else:
			assert_eq(sim.state, CarSim.State.CRASHED, why)
			assert_signal_emitted_with_parameters(sim, "crashed", [CarSim.HEALTH])
