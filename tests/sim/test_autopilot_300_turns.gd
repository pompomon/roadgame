extends GutTest
## Autopilot drives 300 turns on each of 20 seeds at the game's fixed delta, with no disaster, crash
## or damage (IMPLEMENTATION_PLAN.md D2, M2 tests), and on 5 seeds of a road with every kind of
## junction. Auto-braking has the car at junction_speed whenever it enters a junction tile.

const Fixtures := preload("res://tests/helpers/road_fixtures.gd")
const DELTA := 1.0 / 60.0
const TURNS := 300
const SEEDS := 20
const KINDS_SEEDS := 5
## A run takes about 9 minutes of game time.
const MAX_STEPS := 60 * 60 * 20


func test_300_turns_on_20_seeds() -> void:
	for run_seed: int in SEEDS:
		_drive(RoadGenerator.new(run_seed, Fixtures.schedule()), "seed %d" % run_seed)


## Straight on at each decoy, and the turn at each side road (ROADGEN_PLAN.md R1).
func test_300_turns_through_every_kind_of_junction() -> void:
	for run_seed: int in KINDS_SEEDS:
		var gen := RoadGenerator.new(run_seed, Fixtures.kinds_schedule(0.25, 0.25, 0.25))
		_drive(gen, "kinds seed %d" % run_seed)


func _drive(gen: RoadGenerator, where: String) -> void:
	var buffer := RoadBuffer.new(gen)
	buffer.start()
	var sim := CarSim.new(buffer)
	var pilot := Autopilot.new(sim)
	var junction := sim.trigger.next_junction
	var entered := false
	var worst_entry := -INF
	for i: int in MAX_STEPS:
		sim.step(DELTA, pilot.steer())
		if sim.is_over() or sim.trigger.turn_index >= TURNS:
			break
		if sim.trigger.next_junction != junction:
			junction = sim.trigger.next_junction
			entered = false
		elif not entered and Vector2i(sim.pos.floor()) == junction.cell:
			entered = true
			var junction_speed := buffer.generator.find_area(junction.area_id).junction_speed
			worst_entry = maxf(worst_entry, sim.speed - junction_speed)
	assert_eq(sim.trigger.turn_index, TURNS, where)
	assert_false(sim.is_over(), where)
	assert_eq(sim.health, Tuning.START_HEALTH, where)
	assert_lte(worst_entry, 1e-6, where + ": entered a junction above junction_speed")
