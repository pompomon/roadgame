extends GutTest
## Pit stops (ENDGAME_PLAN.md §5.15, E13): as the car drives out of a pit stop's tiles on the road,
## onto the path tile after their last, PIT_STOP_HEAL repairs it, up to START_HEALTH, once for each
## pit stop in a run; never off the road, on entering the pit stop's area alone, or once the run has
## ended. A pit stop is the way into its area: its set piece, or with none its first straight, by
## which Last Gas stands.

const Fixtures := preload("res://tests/helpers/road_fixtures.gd")
const DELTA := 1.0 / 60.0
## The turn after which the pit stop's area starts.
const TURN := 2
## The pit stops: a tunnel 6 tiles long, and Last Gas's straight, its area's first, which is
## STRAIGHT tiles long.
const KINDS: Array[Array] = [[&"tunnel", 6], [&"", 0]]
const STRAIGHT := 3
## The car's health as it comes to the pit stop.
const HURT := 40.0


## Fixtures.set_piece_schedule()'s road, whose second area's way in, after turn TURN, is a pit
## stop: `set_piece`, `length` tiles long, or with none the area's first straight.
static func _schedule(set_piece: StringName, length: int) -> AreaSchedule:
	var schedule := Fixtures.set_piece_schedule(TURN, set_piece, length, STRAIGHT)
	schedule.entries[1].pit_stop = true
	return schedule


## The car on `schedule`'s road, at HURT.
func _sim(schedule: AreaSchedule) -> CarSim:
	var buffer := RoadBuffer.new(RoadGenerator.new(1, schedule))
	buffer.start()
	var sim := CarSim.new(buffer)
	sim.health = HURT
	watch_signals(sim)
	return sim


## The path indices of the first and the last tile of the first pit stop on `sim`'s road, or
## (-1, -1).
static func _pit_stop(sim: CarSim) -> Vector2i:
	var found := Vector2i(-1, -1)
	for index: int in range(sim.buffer.first_index(), sim.buffer.last_index() + 1):
		if sim.buffer.path_tile(index).pit_stop:
			found = Vector2i(index if found.x < 0 else found.x, index)
		elif found.x >= 0:
			break
	return found


## Drives the autopilot until the car is `past` tiles past the centre of path tile `index`, or the
## run is over. Returns the path index of the car's tile before the first step that raised its
## health, or -1.
func _drive_past(sim: CarSim, index: int, past := 1.0) -> int:
	var pilot := Autopilot.new(sim)
	var raised_from := -1
	for i: int in 60 * 60:
		if sim.progress >= index + past or sim.is_over():
			break
		var before := sim.path_tile.path_index
		var health := sim.health
		sim.step(DELTA, pilot.steer())
		if sim.health > health and raised_from < 0:
			raised_from = before
	return raised_from


func test_driving_out_of_a_pit_stop_on_the_road_repairs_the_car() -> void:
	for kind: Array in KINDS:
		var sim := _sim(_schedule(kind[0], kind[1]))
		var stop := _pit_stop(sim)
		assert_eq(
			stop.y - stop.x + 1, kind[1] if kind[1] > 0 else STRAIGHT, "%s: its tiles" % [kind]
		)
		# In its first tile, the car is in the area if the pit stop is Last Gas's straight, and
		# still unrepaired.
		assert_eq(_drive_past(sim, stop.x, 0.0), -1, str(kind))
		assert_eq(sim.area.id, &"after" if kind[1] == 0 else &"before", str(kind))
		assert_eq(_drive_past(sim, stop.y + 1), stop.y, "%s: as it leaves the last tile" % [kind])
		assert_eq(sim.health, HURT + Tuning.PIT_STOP_HEAL, str(kind))
		assert_signal_emit_count(sim, "repaired", 1, str(kind))
		assert_signal_emitted_with_parameters(sim, "health_changed", [HURT + Tuning.PIT_STOP_HEAL])
		assert_eq(sim.state, CarSim.State.DRIVING, str(kind))


func test_a_repair_stops_at_start_health() -> void:
	# At full health, the car passes the pit stop by.
	for health: float in [Tuning.START_HEALTH - 10.0, Tuning.START_HEALTH]:
		var sim := _sim(_schedule(&"tunnel", 6))
		sim.health = health
		_drive_past(sim, _pit_stop(sim).y + 1)
		assert_eq(sim.health, Tuning.START_HEALTH, "from %s" % health)
		var repairs := 1 if health < Tuning.START_HEALTH else 0
		assert_signal_emit_count(sim, "repaired", repairs, "from %s" % health)


func test_each_pit_stop_repairs_the_car_once() -> void:
	var sim := _sim(_schedule(&"", 0))
	var stop := _pit_stop(sim)
	_drive_past(sim, stop.y + 1)
	assert_signal_emit_count(sim, "repaired", 1)
	# Back in the middle of the last tile, facing along it, hurt again: driving out of it again
	# repairs nothing.
	var last := sim.buffer.path_tile(stop.y)
	sim.pos = Iso.cell_centre(last.cell)
	sim.angle = last.heading * PI / 2.0
	sim.path_tile = last
	sim.progress = CarSim.path_progress(last, sim.pos)
	sim.health = HURT
	assert_eq(_drive_past(sim, stop.y + 1), -1)
	assert_eq(sim.health, HURT)
	assert_signal_emit_count(sim, "repaired", 1)


func test_turning_back_out_of_a_pit_stop_repairs_nothing() -> void:
	# The car can turn round. Back out of a pit stop's first tile, on the road, onto the path tile
	# before it, it isn't repaired; and driving out of its last tile afterwards repairs it once.
	for kind: Array in KINDS:
		var sim := _sim(_schedule(kind[0], kind[1]))
		var stop := _pit_stop(sim)
		_drive_past(sim, stop.x, 0.0)
		var first := sim.buffer.path_tile(stop.x)
		var before := sim.buffer.path_tile(stop.x - 1)
		sim.pos = Iso.cell_centre(first.cell)
		sim.angle = Heading.opposite(first.heading) * PI / 2.0
		for i: int in 60:
			if Vector2i(sim.pos.floor()) == before.cell or sim.is_over():
				break
			sim.step(DELTA, 0.0)
		assert_eq(Vector2i(sim.pos.floor()), before.cell, "%s: back out of it" % [kind])
		assert_eq(sim.state, CarSim.State.DRIVING, "%s: on the road" % [kind])
		assert_eq(sim.health, HURT, str(kind))
		assert_signal_not_emitted(sim, "repaired", str(kind))
		# Then along the road again, from the middle of its first tile.
		sim.pos = Iso.cell_centre(first.cell)
		sim.angle = first.heading * PI / 2.0
		sim.path_tile = first
		sim.progress = CarSim.path_progress(first, sim.pos)
		assert_eq(_drive_past(sim, stop.y + 1), stop.y, str(kind))
		assert_eq(sim.health, HURT + Tuning.PIT_STOP_HEAL, str(kind))
		assert_signal_emit_count(sim, "repaired", 1, str(kind))


func test_a_pit_stop_left_off_the_road_repairs_nothing() -> void:
	for kind: Array in KINDS:
		var sim := _sim(_schedule(kind[0], kind[1]))
		var stop := _pit_stop(sim)
		_drive_past(sim, stop.y, 0.0)
		# Then off the road beside the middle of the last tile, facing along it: the car drives
		# out of it off the road.
		var last := sim.buffer.path_tile(stop.y)
		var right := Vector2(Heading.VEC[Heading.right(last.heading)])
		sim.pos = Iso.cell_centre(last.cell) + right * 0.45
		sim.angle = last.heading * PI / 2.0
		for i: int in 60:
			if sim.path_tile.path_index > stop.y or sim.is_over():
				break
			sim.step(DELTA, 0.0)
		assert_eq(sim.path_tile.path_index, stop.y + 1, "%s: out of it" % [kind])
		assert_eq(sim.state, CarSim.State.OFFROAD, str(kind))
		assert_lt(sim.health, HURT, "%s: hurt off the road" % [kind])
		assert_signal_not_emitted(sim, "repaired", str(kind))


func test_a_pit_stop_that_runs_into_the_finish_repairs_nothing() -> void:
	# Last Gas's straight leads to the finish: the car arrives as it drives out of it, so the run
	# is over.
	var schedule := _schedule(&"", 0)
	schedule.finish = &"pier"
	schedule.finish_turn = TURN
	assert_eq(schedule.validate(), PackedStringArray())
	var sim := _sim(schedule)
	var stop := _pit_stop(sim)
	assert_eq(sim.buffer.path_tile(stop.y + 1).set_piece, &"pier")
	assert_eq(_drive_past(sim, stop.y + 1), -1)
	assert_eq(sim.state, CarSim.State.ARRIVED)
	assert_eq(sim.health, HURT)
	assert_signal_not_emitted(sim, "repaired")


func test_a_departure_keeps_the_pit_stops_after_its_first_area() -> void:
	# Three areas, the third's way in a pit stop, Last Gas's straight. Starting in the second keeps
	# it; starting in the third, as a Departure from it does, leaves out its way in, and with it
	# the pit stop (AreaSchedule.starting_at()).
	var road := Fixtures.set_piece_schedule(TURN, &"", 0, STRAIGHT)
	var third := AreaScheduleEntry.new()
	third.turn = TURN * 2
	third.area = AreaDef.new()
	third.area.id = &"third"
	third.area.min_straight = STRAIGHT
	third.area.max_straight = STRAIGHT
	third.area.cross_junction_chance = 0.0
	third.pit_stop = true
	road.entries.append(third)
	var middle := _sim(road.starting_at(&"after"))
	var stop := _pit_stop(middle)
	assert_eq(stop.y - stop.x + 1, STRAIGHT, "from the second area")
	assert_eq(_drive_past(middle, stop.y + 1), stop.y, "from the second area")
	assert_signal_emit_count(middle, "repaired", 1, "from the second area")
	var start := _sim(road.starting_at(&"third"))
	assert_eq(_pit_stop(start), Vector2i(-1, -1), "from the third area")
	assert_eq(_drive_past(start, stop.y + 1), -1, "from the third area")
	assert_signal_not_emitted(start, "repaired", "from the third area")
