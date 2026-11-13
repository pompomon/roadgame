extends GutTest
## The tutorial on the road (TUTORIAL_PLAN.md §6.1). The autopilot finishes it in TUTORIAL_STREAK
## turns and drives on through the City's schedule as a run without it would. A wrong turn loops
## back onto the path and starts the streak again, and a car left alone is put back on the path,
## and neither ends the run. Past the tutorial, the road it laid ahead plays by the City's rules.

const Fixtures := preload("res://tests/helpers/road_fixtures.gd")
const RoutePilot := preload("res://tests/helpers/route_pilot.gd")
const DELTA := 1.0 / 60.0
const TURNS := 230
## The tutorial and a run to turn 230 take about 8 minutes of game time.
const MAX_STEPS := 60 * 60 * 16
## A tutorial with a few mistakes takes well under 2 minutes.
const TUTORIAL_STEPS := 60 * 120

var _sim: CarSim
## The turn number and path index of the junction where the tutorial ended, the step it ended on,
## and then the path index of the last tile and the turns the generator had laid.
var _ended_at := -1
var _ended_index := -1
var _ended_step := -1
var _lead_end := -1
var _lead_turns := -1
var _step := 0


func _start(run_seed: int) -> void:
	var buffer := RoadBuffer.new(RoadGenerator.new(run_seed, Fixtures.schedule(), true))
	buffer.start()
	_sim = CarSim.new(buffer)
	_sim.trigger.tutorial_completed.connect(_on_tutorial_completed)
	_ended_at = -1
	_ended_index = -1
	_ended_step = -1
	_lead_end = -1
	_lead_turns = -1
	watch_signals(_sim)
	watch_signals(_sim.trigger)


## What main.gd does (TUTORIAL_PLAN.md §5.5).
func _on_tutorial_completed(junction: RoadTile) -> void:
	_ended_at = junction.turn_number
	_ended_index = junction.path_index
	_ended_step = _step
	_lead_end = _sim.buffer.last_index()
	_lead_turns = _sim.buffer.generator.turn_count
	_sim.buffer.generator.end_tutorial(junction.turn_number + 1)


## Steps `steps` frames, steered by `pilot`, or with no input if it is null, until `done` says so.
func _drive(pilot: Autopilot, steps: int, done: Callable) -> void:
	for i: int in steps:
		_step = i
		_sim.step(DELTA, 0.0 if pilot == null else pilot.steer())
		if _sim.is_over() or done.call():
			return


func _streaks() -> Array:
	var streaks := []
	for k: int in get_signal_emit_count(_sim.trigger, "streak_changed"):
		streaks.append(get_signal_parameters(_sim.trigger, "streak_changed", k)[0])
	return streaks


func _tutorial_over() -> bool:
	return _ended_at >= 0


func test_the_autopilot_finishes_the_tutorial_and_drives_on_through_the_schedule() -> void:
	_start(1)
	var pilot := Autopilot.new(_sim)
	var changes: Array = []
	var pieces: Array[StringName] = []
	for i: int in MAX_STEPS:
		_step = i
		var area := _sim.area
		_sim.step(DELTA, pilot.steer())
		if _sim.area != area:
			changes.append([_sim.trigger.turn_index, _sim.area.id])
		var piece := _sim.path_tile.set_piece
		if piece != &"" and not pieces.has(piece):
			pieces.append(piece)
		if _sim.is_over() or _sim.trigger.turn_index >= TURNS:
			break
	assert_eq(_ended_at, Tuning.TUTORIAL_STREAK - 1, "the streak's last turn")
	assert_eq(_streaks(), range(1, Tuning.TUTORIAL_STREAK + 1))
	assert_eq(_sim.trigger.turn_index, TURNS)
	assert_false(_sim.is_over())
	var expected: Array = [[34, &"rural"], [100, &"meadows"], [200, &"village"], [220, &"desert"]]
	assert_eq(changes, expected, "the City's turns count from the tutorial's end")
	assert_eq(pieces, [&"tunnel", &"bridge"] as Array[StringName])
	assert_signal_not_emitted(_sim, "rescued")
	var measured := [
		_ended_step * DELTA, _ended_index, _lead_end - _ended_index, _lead_turns - _ended_at - 1
	]
	gut.p("P1: %.1f s to path tile %d, with %d tiles and %d turns laid past it" % measured)


## TUTORIAL_PLAN.md §5.2: a wrong exit at A (turn 0) or B (5) loops on to C or D, and the streak
## starts again at the junction after it. One at C (2) or D (3) loops back to A or B, and the streak
## starts again at the junction after that one. The car never leaves the road.
func test_a_wrong_turn_starts_the_streak_again_where_its_loop_comes_back() -> void:
	# The turns it goes wrong at, the streaks before the last streak, and the turn that ends that.
	# A wrong turn at 0 ends no streak; the streak after one at 5 starts at 8, and ends at 9.
	var cases: Array[Array] = [
		[[0], [], 14],
		[[5], [1, 2, 3, 4, 5, 0], 19],
		[[2], [1, 2, 0], 12],
		[[3], [1, 2, 3, 0], 13],
		[[5, 9], [1, 2, 3, 4, 5, 0, 1, 0], 23],
	]
	for case: Array in cases:
		_start(1)
		var pilot := RoutePilot.new(_sim)
		pilot.wrong_at.assign(case[0])
		_drive(pilot, TUTORIAL_STEPS, _tutorial_over)
		var at := str(case[0])
		assert_eq(_ended_at, case[2], at)
		assert_eq(_streaks(), case[1] + range(1, Tuning.TUTORIAL_STREAK + 1), at)
		assert_false(_sim.is_over(), at)
		assert_signal_not_emitted(_sim, "offroad_changed", at)
		assert_signal_not_emitted(_sim, "rescued", at)


## TUTORIAL_PLAN.md §5.3: with no input the car drives straight off the road at the first junction,
## takes damage down to 0 and drives on, and is put back before the junction, again and again. The
## run never ends.
func test_a_car_left_alone_is_put_back_on_the_path_again_and_again() -> void:
	_start(1)
	var junction := _sim.trigger.next_junction
	var lowest := Tuning.START_HEALTH
	for i: int in 60 * 60:
		_sim.step(DELTA, 0.0)
		lowest = minf(lowest, _sim.health)
		if _sim.is_over():
			break
	assert_false(_sim.is_over())
	assert_eq(lowest, 0.0, "it drove on at 0 health")
	assert_gt(get_signal_emit_count(_sim, "rescued"), 3)
	assert_signal_not_emitted(_sim.trigger, "streak_changed")
	assert_lte(_sim.buffer.car_index(), junction.path_index, "it never got past the junction")


## TUTORIAL_PLAN.md §5.5: the road the tutorial laid past the junction where it ended plays by the
## City's rules: a wrong exit there is a disaster, though its loop leads back.
func test_a_wrong_turn_on_the_road_the_tutorial_laid_ends_the_run() -> void:
	_start(1)
	var pilot := RoutePilot.new(_sim)
	pilot.wrong_at = [Tuning.TUTORIAL_STREAK + 1] as Array[int]
	_drive(pilot, TUTORIAL_STEPS, func() -> bool: return false)
	assert_eq(_ended_at, Tuning.TUTORIAL_STREAK - 1)
	assert_true(_sim.is_over())
	assert_signal_emitted(_sim.trigger, "disaster_triggered")
	var junction: RoadTile = get_signal_parameters(_sim.trigger, "disaster_triggered")[0]
	assert_eq(junction.turn_number, Tuning.TUTORIAL_STREAK + 1)
	assert_lt(junction.path_index, _lead_end, "the tutorial laid it")
