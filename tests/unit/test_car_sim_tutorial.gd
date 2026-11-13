extends GutTest
## CarSim in the tutorial (TUTORIAL_PLAN.md §5.3), on a real tutorial road: off the road it takes
## damage but never crashes; it heals on the road; it is put back on the path once it has driven
## TUTORIAL_RESCUE_TILES off the road; and while the trigger has lost it, it brakes for the turns of
## the road it is on. The end of the tutorial starts the City's run, with its rules.

const Fixtures := preload("res://tests/helpers/road_fixtures.gd")
const RoutePilot := preload("res://tests/helpers/route_pilot.gd")
const DELTA := 1.0 / 60.0

var _sim: CarSim


func before_each() -> void:
	var buffer := RoadBuffer.new(RoadGenerator.new(1, Fixtures.schedule(), true))
	buffer.start()
	_sim = CarSim.new(buffer)
	watch_signals(_sim)
	watch_signals(_sim.trigger)


## Puts the car on the centre of path tile `index`, as if it had driven there, facing `heading`, at
## speed 1.
func _put(index: int, heading: int) -> void:
	_sim.path_tile = _sim.buffer.path_tile(index)
	_sim.progress = index
	_place(_sim.path_tile.cell, heading)


## Puts the car on the centre of `cell`, facing `heading`, at speed 1.
func _place(cell: Vector2i, heading: int) -> void:
	_sim.pos = Iso.cell_centre(cell)
	_sim.angle = heading * PI / 2.0
	_sim.speed = 1.0


## Steps for `seconds`, or until the car is rescued: straight on, or as `pilot` steers.
func _drive(seconds: float, pilot: Autopilot = null) -> void:
	for i: int in roundi(seconds / DELTA):
		_sim.step(DELTA, 0.0 if pilot == null else pilot.steer())
		if get_signal_emit_count(_sim, "rescued") > 0:
			return


## Steps straight on until the car has driven `tiles` off the road, for at most 10 s.
func _drive_off(tiles: float) -> void:
	for i: int in roundi(10.0 / DELTA):
		_sim.step(DELTA, 0.0)
		if _sim.offroad_dist >= tiles:
			return


## Takes the next junction's correct exit, as the car's crossing would.
func _take_next() -> void:
	var junction := _sim.trigger.next_junction
	var exit := junction.cell + Heading.VEC[junction.expected_exit]
	_sim.trigger.on_cell_crossed(junction.cell, exit, true)


## East of the start straight, no road is nearer than the rescue's distance. With a little health,
## the car comes to 0 well before the rescue, whatever TUTORIAL_RESCUE_TILES is (P2d).
func test_the_car_drives_on_with_no_health() -> void:
	_sim.health = 1.0
	_put(1, Heading.E)
	_drive_off(_sim.area.offroad_limit_tiles + 0.5)
	assert_eq(_sim.health, 0.0)
	assert_eq(_sim.state, CarSim.State.OFFROAD)
	assert_gt(_sim.speed, 0.0)
	assert_lt(_sim.offroad_dist, Tuning.TUTORIAL_RESCUE_TILES)
	assert_signal_not_emitted(_sim, "crashed")
	assert_signal_not_emitted(_sim.trigger, "disaster_triggered")


func test_the_offroad_limit_ends_the_streak() -> void:
	_sim.trigger.streak = 3
	_put(1, Heading.E)
	_drive_off(_sim.area.offroad_limit_tiles)
	assert_eq(_sim.trigger.streak, 0)
	assert_signal_emit_count(_sim.trigger, "streak_changed", 1)
	assert_true(_sim.is_lost())


## Within TUTORIAL_HEAL_SECONDS, and a frame, for the sum of steps falls a little short. The
## autopilot keeps the car on the road through the junctions, however long the heal takes (P2c).
func test_the_car_heals_on_the_road() -> void:
	var pilot := Autopilot.new(_sim)
	_sim.health = 0.0
	_drive(Tuning.TUTORIAL_HEAL_SECONDS / 2.0, pilot)
	assert_almost_eq(_sim.health, Tuning.START_HEALTH / 2.0, 1e-3)
	_drive(Tuning.TUTORIAL_HEAL_SECONDS / 2.0 + DELTA, pilot)
	assert_eq(_sim.health, Tuning.START_HEALTH)
	assert_signal_emitted_with_parameters(_sim, "health_changed", [Tuning.START_HEALTH])
	assert_signal_not_emitted(_sim, "offroad_changed", "on the road all along")


func test_a_rescue_puts_the_car_back_on_its_path_tile() -> void:
	_put(1, Heading.E)
	_drive(10.0)
	assert_signal_emit_count(_sim, "rescued", 1)
	var tile := _sim.buffer.path_tile(1)
	assert_eq(_sim.pos, Iso.cell_centre(tile.cell))
	assert_eq(_sim.angle, tile.heading * PI / 2.0)
	assert_eq(_sim.speed, 0.0)
	assert_eq(_sim.state, CarSim.State.DRIVING)
	assert_eq(_sim.offroad_dist, 0.0)
	assert_eq(_sim.path_tile, tile)
	assert_almost_eq(_sim.progress, 1.0, 1e-6)
	assert_signal_emitted_with_parameters(_sim, "offroad_changed", [false])
	assert_eq(_sim.trigger.next_junction, _sim.buffer.path_tile(Tuning.START_STRAIGHT_TILES))
	assert_false(_sim.is_lost())
	assert_signal_not_emitted(_sim, "crashed")


## From a junction, the car goes back to the tile before it, to take its turn again. It is off the
## road SE of the junction, between the start straight and the leg of the junction's loop.
func test_a_rescue_from_a_junction_puts_the_car_before_it() -> void:
	var junction := _sim.trigger.next_junction
	_sim.path_tile = junction
	_sim.buffer.on_car_path_index(junction.path_index)
	_sim.pos = Iso.cell_centre(junction.cell) + Vector2(2.0, 2.0)
	_sim.angle = Heading.E * PI / 2.0
	_sim.speed = 1.0
	_sim.state = CarSim.State.OFFROAD
	_sim.offroad_dist = Tuning.TUTORIAL_RESCUE_TILES - 0.001
	_sim.step(DELTA, 0.0)
	var before := _sim.buffer.path_tile(junction.path_index - 1)
	assert_signal_emit_count(_sim, "rescued", 1)
	assert_eq(_sim.pos, Iso.cell_centre(before.cell))
	assert_eq(_sim.path_tile, before)
	assert_eq(_sim.trigger.next_junction, junction)


## On the start straight, lost, the car has no junction to brake for, but A, the first, is a T that
## it enters from its foot: a turn (TUTORIAL_PLAN.md §5.3).
func test_a_lost_car_brakes_for_a_t_it_enters_from_its_foot() -> void:
	var a := _sim.trigger.next_junction
	_sim.trigger.on_offroad_limit()
	assert_true(_sim.is_lost())
	_put(a.path_index - 3, a.heading)
	_sim.dist_on_straight = 4.0
	assert_eq(_sim.distance_to_turn(), INF)
	assert_gt(_sim.target_speed(), _sim.area.junction_speed, "no cap while lost")
	_put(a.path_index - 1, a.heading)
	assert_eq(_sim.distance_to_turn(), 1.0)
	assert_eq(_sim.target_speed(), _sim.area.junction_speed)


## A's loop leaves its wrong exit and turns at its third tile. From that loop, the car drives back
## straight through A, out of A's correct exit: no turn.
func test_a_lost_car_brakes_for_the_corners_of_a_loop() -> void:
	var a := _sim.trigger.next_junction
	var wrong := Heading.opposite(a.expected_exit)
	assert_true(a.has_exit(wrong), "a T entered from its foot")
	_sim.trigger.on_offroad_limit()
	_place(a.cell + Heading.VEC[wrong] * 2, wrong)
	assert_eq(_sim.distance_to_turn(), 1.0, "the corner")
	_place(a.cell + Heading.VEC[wrong], wrong)
	assert_eq(_sim.distance_to_turn(), INF)
	_place(a.cell + Heading.VEC[wrong], a.expected_exit)
	assert_eq(_sim.distance_to_turn(), INF, "straight through A")


## A wrong exit at A loops on to C, along legs of 3, 3 and 6 tiles. The lost car speeds up along
## them, and enters each corner at junction_speed at most, as it enters a junction. It never leaves
## the road, and is found past C.
func test_a_lost_car_speeds_up_along_a_loop_and_slows_for_its_corners() -> void:
	var pilot := RoutePilot.new(_sim)
	pilot.wrong_at = [0] as Array[int]
	var lost_steps := 0
	var top := 0.0
	var cornering := 0.0
	for i: int in roundi(20.0 / DELTA):
		_sim.step(DELTA, pilot.steer())
		if not _sim.is_lost():
			if lost_steps > 0:
				break
			continue
		lost_steps += 1
		top = maxf(top, _sim.speed)
		if _sim.distance_to_turn() <= 0.5:
			cornering = maxf(cornering, _sim.speed)
	assert_gt(lost_steps, 0)
	assert_false(_sim.is_lost(), "found")
	assert_gt(top, _sim.area.junction_speed + 1.0)
	assert_gt(cornering, 0.0)
	assert_lte(cornering, _sim.area.junction_speed + 1e-6)
	assert_signal_not_emitted(_sim, "offroad_changed")
	assert_signal_not_emitted(_sim, "rescued")
	gut.p("lost for %.2f s, top %.3f, cornering %.6f" % [lost_steps * DELTA, top, cornering])


## The straight starts again as the car brakes for a junction, so that a mistake starts it as a
## correct exit does, even one that ends no streak.
func test_the_straight_starts_again_as_the_car_brakes_for_a_junction() -> void:
	var a := _sim.trigger.next_junction
	_put(a.path_index - 1, a.heading)
	_sim.dist_on_straight = 4.0
	_sim.step(DELTA, 0.0)
	assert_eq(_sim.state, CarSim.State.BRAKING)
	assert_false(_sim.is_lost())
	assert_eq(_sim.dist_on_straight, 0.0)


## Off the road, the straight goes on, as in the City, until the car is lost. Then it starts again,
## so that the car drives to the rescue at junction_speed, slowed, and loses all its health on the
## way (P2d).
func test_a_lost_car_off_the_road_heads_for_junction_speed() -> void:
	_put(1, Heading.E)
	_sim.dist_on_straight = 4.0
	_drive_off(_sim.area.offroad_limit_tiles / 2.0)
	assert_false(_sim.is_lost())
	assert_gt(_sim.dist_on_straight, 4.0)
	_drive_off(_sim.area.offroad_limit_tiles + 0.5)
	assert_true(_sim.is_lost())
	assert_eq(_sim.distance_to_turn(), INF)
	assert_eq(_sim.dist_on_straight, 0.0)
	var slowed := _sim.area.junction_speed * _sim.area.offroad_speed_mult
	assert_eq(_sim.target_speed(), slowed)
	_drive(2.0)
	assert_almost_eq(_sim.speed, slowed, 1e-6)


func test_the_streak_restarts_the_straight() -> void:
	_sim.dist_on_straight = 4.0
	_take_next()
	assert_eq(_sim.trigger.streak, 1)
	assert_eq(_sim.dist_on_straight, 0.0)


func test_the_end_of_the_tutorial_starts_the_city_run() -> void:
	_sim.health = 40.0
	_sim.dist_total = 30.0
	_sim.trigger.streak = Tuning.TUTORIAL_STREAK - 1
	_take_next()
	assert_signal_emit_count(_sim.trigger, "tutorial_completed", 1)
	assert_eq(_sim.health, Tuning.START_HEALTH)
	assert_signal_emitted_with_parameters(_sim, "health_changed", [Tuning.START_HEALTH])
	assert_eq(_sim.dist_total, 0.0)
	_sim.health = 40.0
	_drive(1.0)
	assert_eq(_sim.health, 40.0, "no more healing")
	_sim.health = Tuning.START_HEALTH
	_put(1, Heading.E)
	_drive(4.0)
	assert_signal_emitted_with_parameters(_sim, "crashed", [CarSim.OFFROAD])
	assert_signal_not_emitted(_sim, "rescued")
