extends GutTest
## The autopilot drives the whole road to its end (docs/ENDGAME.md E1, E7, E9): the game's own road,
## ending at the pier past the Coast after 100 turns, and the Road Home, mirrored, ending at home
## after 100 turns, on SEEDS seeds each, with no disaster, crash or damage, in at most MOST_SECONDS
## of game time (SPEEDUP_PLAN.md E1). Each zone of NIGHT_AREAS that the car leaves lasted into its
## night (E3). Prints the game time each took (P1).

const Fixtures := preload("res://tests/helpers/road_fixtures.gd")
const DELTA := 1.0 / 60.0
const TURNS := 100
const SEEDS := 10
## The longest a drive to the end may take: 5 minutes (SPEEDUP_PLAN.md E1).
const MOST_SECONDS := 300.0
## The areas whose zones show their night (docs/DAYNIGHT.md §5.8, SPEEDUP_PLAN.md E3).
const NIGHT_AREAS: Array[StringName] = [&"rural", &"meadows", &"desert"]
## Twice MOST_SECONDS.
const MAX_STEPS := 60 * 60 * 10


func test_the_autopilot_drives_to_the_pier() -> void:
	_drive_all(Fixtures.schedule(), &"coast", "pier")


func test_the_autopilot_drives_the_road_home() -> void:
	_drive_all(Fixtures.schedule_home(), &"city", "home")


func _drive_all(road: AreaSchedule, last_area: StringName, where: String) -> void:
	var minutes: Array[String] = []
	for run_seed: int in SEEDS:
		var gen := RoadGenerator.new(run_seed, road)
		var seconds := _drive(gen, last_area, "%s seed %d" % [where, run_seed])
		minutes.append("%.1f" % (seconds / 60.0))
	gut.p("P1: %s: %s min" % [where, ", ".join(minutes)])


## Drives to the end of the road. Returns the game time to the arrival.
func _drive(gen: RoadGenerator, last_area: StringName, why: String) -> float:
	var buffer := RoadBuffer.new(gen)
	buffer.start()
	var sim := CarSim.new(buffer)
	var pilot := Autopilot.new(sim)
	var steps := 0
	var zone := sim.area
	var entered := 0
	var nights := 0
	while steps < MAX_STEPS and not sim.is_over():
		sim.step(DELTA, pilot.steer())
		steps += 1
		if sim.area != zone:
			nights += _check_night(zone, (steps - entered) * DELTA, why)
			zone = sim.area
			entered = steps
	assert_eq(sim.state, CarSim.State.ARRIVED, why)
	assert_eq(sim.trigger.turn_index, TURNS, why)
	assert_eq(sim.health, Tuning.START_HEALTH, why)
	assert_eq(sim.area.id, last_area, why)
	assert_eq(gen.dropped_count, 0, why + ": no junction dropped")
	assert_lte(steps * DELTA, MOST_SECONDS, why + ": the time to the end")
	assert_eq(nights, NIGHT_AREAS.size(), why + ": each of NIGHT_AREAS left")
	return steps * DELTA


## Checks that a zone of NIGHT_AREAS that the car left after `seconds` lasted past the hour at which
## the night starts, LIGHT_HOURS' last, on its clock, which starts at DAY_START_HOUR as the car
## enters it. Returns 1 for such a zone, and 0 for another.
func _check_night(area: AreaDef, seconds: float, why: String) -> int:
	if not NIGHT_AREAS.has(area.id):
		return 0
	var to_night := fposmod(Tuning.LIGHT_HOURS[-1] - Tuning.DAY_START_HOUR, 24.0)
	assert_gt(seconds, to_night / 24.0 * area.day_seconds, "%s: %s's night" % [why, area.id])
	return 1
