extends GutTest
## The autopilot drives the whole road to its end (docs/ENDGAME.md E1, E7, E9): the game's own road,
## ending at the pier past the Coast after 280 turns, and the Road Home, mirrored, ending at home
## after 280 turns, on SEEDS seeds each, with no disaster, crash or damage. Prints the game time
## each took (P1).

const Fixtures := preload("res://tests/helpers/road_fixtures.gd")
const DELTA := 1.0 / 60.0
const TURNS := 280
const SEEDS := 5
## A run to the end takes about 9 minutes of game time.
const MAX_STEPS := 60 * 60 * 20


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
	while steps < MAX_STEPS and not sim.is_over():
		sim.step(DELTA, pilot.steer())
		steps += 1
	assert_eq(sim.state, CarSim.State.ARRIVED, why)
	assert_eq(sim.trigger.turn_index, TURNS, why)
	assert_eq(sim.health, Tuning.START_HEALTH, why)
	assert_eq(sim.area.id, last_area, why)
	assert_eq(gen.dropped_count, 0, why + ": no junction dropped")
	return steps * DELTA
