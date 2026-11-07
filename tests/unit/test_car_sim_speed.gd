extends GutTest
## CarSim's speed model (plan.md §2.3, IMPLEMENTATION_PLAN.md M2.2) on a real road.

const Fixtures := preload("res://tests/helpers/road_fixtures.gd")
const DELTA := 1.0 / 60.0


## Autopilot, but the line it follows goes on through `exit` past the next junction's centre.
class ExitPilot:
	extends Autopilot

	var _junction: RoadTile
	var _exit: int

	func _init(sim: CarSim, exit: int) -> void:
		super(sim)
		_junction = sim.trigger.next_junction
		_exit = exit

	func steer() -> float:
		var ahead := _sim.progress + LOOKAHEAD - _junction.path_index
		if ahead <= 0.0:
			return super()
		var aim := Iso.cell_centre(_junction.cell) + Vector2(Heading.VEC[_exit]) * ahead - _sim.pos
		var error := wrapf(atan2(aim.x, -aim.y) - _sim.angle, -PI, PI)
		return clampf(error * GAIN, -1.0, 1.0)


func _sim(run_seed: int) -> CarSim:
	var buffer := RoadBuffer.new(RoadGenerator.new(run_seed, Fixtures.schedule()))
	buffer.start()
	return CarSim.new(buffer)


## Drives until the next junction is decided or the run ends. Returns the distance to the junction
## at the step where braking began, and the speed on entering the junction tile.
func _approach(sim: CarSim, pilot: Autopilot) -> Dictionary:
	var junction := sim.trigger.next_junction
	var result := {"onset": -1.0, "entry_speed": -1.0}
	for i: int in 600:
		var before := sim.distance_to_junction()
		sim.step(DELTA, pilot.steer())
		if sim.state == CarSim.State.BRAKING and result.onset < 0.0:
			result.onset = before
		if Vector2i(sim.pos.floor()) == junction.cell and result.entry_speed < 0.0:
			result.entry_speed = sim.speed
		if sim.is_over() or sim.trigger.next_junction != junction:
			break
	return result


func test_speed_rises_from_zero_on_the_first_straight() -> void:
	var sim := _sim(1)
	assert_eq(sim.speed, 0.0)
	sim.step(DELTA, 0.0)
	assert_almost_eq(sim.speed, Tuning.ACCEL * DELTA, 1e-9)
	for i: int in 59:
		sim.step(DELTA, 0.0)
	assert_almost_eq(sim.speed, Tuning.ACCEL * 60 * DELTA, 1e-6)
	assert_eq(sim.state, CarSim.State.DRIVING)


func test_the_target_speed_rises_along_a_straight() -> void:
	var sim := _sim(1)
	assert_eq(sim.target_speed(), sim.area.junction_speed)
	sim.dist_on_straight = 2.0
	var rise := 2.0 * sim.area.straight_accel
	assert_almost_eq(sim.target_speed(), sim.area.junction_speed + rise, 1e-9)


func test_the_top_speed_grows_with_the_run_up_to_the_cap() -> void:
	var sim := _sim(1)
	sim.dist_on_straight = 1e6
	assert_eq(sim.target_speed(), Tuning.BASE_TOP_SPEED)
	sim.dist_total = 1000.0
	var grown := Tuning.BASE_TOP_SPEED + 1000.0 * Tuning.TOP_SPEED_GROWTH
	assert_lt(grown, Tuning.GLOBAL_SPEED_CAP)
	assert_almost_eq(sim.target_speed(), grown, 1e-9)
	sim.dist_total = 1e6
	assert_eq(sim.target_speed(), Tuning.GLOBAL_SPEED_CAP)


func test_brakes_at_the_brake_distance_whichever_exit_it_takes() -> void:
	var correct := _sim(1)
	var wrong := _sim(1)
	var junction := wrong.trigger.next_junction
	var wrong_exit: int = junction.branches[0].branch_exit
	watch_signals(correct.trigger)
	watch_signals(wrong.trigger)
	var results := [
		_approach(correct, Autopilot.new(correct)),
		_approach(wrong, ExitPilot.new(wrong, wrong_exit)),
	]
	var brake_distance := correct.area.junction_brake_distance
	for result: Dictionary in results:
		assert_between(result.onset, brake_distance - Tuning.BASE_TOP_SPEED * DELTA, brake_distance)
		assert_between(result.entry_speed, 0.0, correct.area.junction_speed + 1e-6)
	assert_signal_emitted_with_parameters(correct.trigger, "turn_completed", [1])
	var wrong_choice := [junction, wrong_exit]
	assert_signal_emitted_with_parameters(wrong.trigger, "disaster_triggered", wrong_choice)
	assert_eq(wrong.state, CarSim.State.DISASTER)


func test_enters_the_junction_at_junction_speed_from_the_speed_cap() -> void:
	for run_seed: int in 10:
		var sim := _sim(run_seed)
		sim.dist_total = 1e6
		sim.dist_on_straight = 1e6
		sim.speed = Tuning.GLOBAL_SPEED_CAP
		var result := _approach(sim, Autopilot.new(sim))
		var entry: float = result.entry_speed
		assert_lte(entry, sim.area.junction_speed + 1e-6, "seed %d" % run_seed)
		assert_eq(sim.trigger.turn_index, 1, "seed %d" % run_seed)


func test_speeds_up_again_after_a_turn() -> void:
	var sim := _sim(1)
	var pilot := Autopilot.new(sim)
	_approach(sim, pilot)
	assert_eq(sim.trigger.turn_index, 1)
	assert_eq(sim.dist_on_straight, 0.0)
	var fastest := 0.0
	for i: int in 600:
		sim.step(DELTA, pilot.steer())
		if sim.state == CarSim.State.BRAKING:
			break
		fastest = maxf(fastest, sim.speed)
	assert_gt(fastest, sim.area.junction_speed + 0.1)
