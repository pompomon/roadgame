extends GutTest
## The autopilot drives the whole road to its end (docs/ENDGAME.md E1, E7, E9): the game's own road,
## ending at the pier past the Coast after 100 turns, and the Road Home, mirrored, ending at home
## after 100 turns, with no disaster, crash or damage: on SEEDS seeds each, in at most MOST_SECONDS
## of game time, and on the slowest seed known for it, in at most SLOWEST_SECONDS
## (SPEEDUP_PLAN.md E1). Each zone of NIGHT_AREAS that the car leaves lasted into its night (E3).
## Prints the game time of each drive (P1).

const Fixtures := preload("res://tests/helpers/road_fixtures.gd")
const DELTA := 1.0 / 60.0
const TURNS := 100
const SEEDS := 10
## The seed whose drive took longest, of the 5,000 of each road that P1 drove.
const SLOWEST_TO_THE_PIER := 4993
const SLOWEST_HOME := 352
## The longest a drive to the end may take: 5 minutes (SPEEDUP_PLAN.md E1).
const MOST_SECONDS := 300.0
## The longest the drive of a road's slowest seed may take. Five minutes is a target, not a cap on
## every seed (SPEEDUP_PLAN.md Q15): pier seed 4993 took 306.4 s, the only one of P1's 10,000 runs
## to take longer.
const SLOWEST_SECONDS := 310.0
## The areas whose zones show their night (docs/DAYNIGHT.md §5.8, SPEEDUP_PLAN.md E3).
const NIGHT_AREAS: Array[StringName] = [&"rural", &"meadows", &"desert"]
## Twice MOST_SECONDS.
const MAX_STEPS := 60 * 60 * 10

## The times the car was damaged on the drive.
var _damage := 0


func test_the_autopilot_drives_to_the_pier() -> void:
	_drive_all(Fixtures.schedule(), &"coast", "pier", SLOWEST_TO_THE_PIER)


func test_the_autopilot_drives_the_road_home() -> void:
	_drive_all(Fixtures.schedule_home(), &"city", "home", SLOWEST_HOME)


## Drives `road` on SEEDS seeds, each in at most MOST_SECONDS, and on `slowest`, in at most
## SLOWEST_SECONDS.
func _drive_all(road: AreaSchedule, last_area: StringName, where: String, slowest: int) -> void:
	var minutes: Array[String] = []
	for run_seed: int in SEEDS:
		var gen := RoadGenerator.new(run_seed, road)
		var seconds := _drive(gen, last_area, "%s seed %d" % [where, run_seed], MOST_SECONDS)
		minutes.append("%.1f" % (seconds / 60.0))
	gut.p("P1: %s: %s min" % [where, ", ".join(minutes)])
	var why := "%s seed %d" % [where, slowest]
	var slow_gen := RoadGenerator.new(slowest, road)
	gut.p("P1: %s: %.2f s" % [why, _drive(slow_gen, last_area, why, SLOWEST_SECONDS)])


## Drives to the end of the road, in at most `most_seconds`. Returns the game time to the arrival.
func _drive(gen: RoadGenerator, last_area: StringName, why: String, most_seconds: float) -> float:
	var buffer := RoadBuffer.new(gen)
	buffer.start()
	var sim := CarSim.new(buffer)
	sim.damaged.connect(_on_damaged)
	_damage = 0
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
	assert_eq(_damage, 0, why + ": no damage")
	assert_eq(sim.area.id, last_area, why)
	assert_eq(gen.dropped_count, 0, why + ": no junction dropped")
	assert_lte(steps * DELTA, most_seconds, why + ": the time to the end")
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


## Counts each time the car is damaged.
func _on_damaged(_area: AreaDef) -> void:
	_damage += 1
