extends GutTest
## SP's probe P8 (SPEEDUP_PLAN.md §6.5): test_autopilot_300_turns.gd's drives, timed. Writes
## kind, seed, secs, turn_index, over, health to SP_OUT.
## On sp/prototype only, outside tests/, so GUT runs it only by name. Run it with Godot, not
## tools/ci/run_tests.sh, which stops at 900 s:
##   SP_OUT=p8.csv godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir= \
##   -gtest=res://tools/sp/test_sp_p8.gd -gexit

const Fixtures := preload("res://tests/helpers/road_fixtures.gd")
const DELTA := 1.0 / 60.0
const TURNS := 300
const MAX_STEPS := 60 * 60 * 40


func test_probe() -> void:
	var out := FileAccess.open(OS.get_environment("SP_OUT"), FileAccess.WRITE)
	for run_seed: int in 20:
		_drive(out, "endless", run_seed, RoadGenerator.new(run_seed, Fixtures.endless()))
	for run_seed: int in 5:
		var gen := RoadGenerator.new(run_seed, Fixtures.kinds_schedule(0.25, 0.25, 0.25))
		_drive(out, "kinds", run_seed, gen)
	out.close()
	pass_test("done")


func _drive(out: FileAccess, kind: String, run_seed: int, gen: RoadGenerator) -> void:
	var buffer := RoadBuffer.new(gen)
	buffer.start()
	var sim := CarSim.new(buffer)
	var pilot := Autopilot.new(sim)
	var steps := 0
	for i: int in MAX_STEPS:
		sim.step(DELTA, pilot.steer())
		steps += 1
		if sim.is_over() or sim.trigger.turn_index >= TURNS:
			break
	var line := "%s,%d,%.3f,%d,%d,%.1f"
	out.store_line(
		(
			line
			% [
				kind,
				run_seed,
				steps * DELTA,
				sim.trigger.turn_index,
				int(sim.is_over()),
				sim.health
			]
		)
	)
