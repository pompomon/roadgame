extends GutTest
## SP's probe P9 (SPEEDUP_PLAN.md §6.5): a first run, the autopilot through the tutorial and on
## to the pier, seeds 0-99. Writes seed, tutorial_end_s, arrival_s, state, turns, damage to SP_OUT.
## On sp/prototype only, outside tests/, so GUT runs it only by name. Run it with Godot, not
## tools/ci/run_tests.sh, which stops at 900 s:
##   SP_OUT=p9.csv godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir= \
##   -gtest=res://tools/sp/test_sp_p9.gd -gexit

const Fixtures := preload("res://tests/helpers/road_fixtures.gd")
const DELTA := 1.0 / 60.0
const MAX_STEPS := 60 * 60 * 20

var _sim: CarSim
var _ended_step := -1
var _step := 0
var _damage := 0


func test_probe() -> void:
	var out := FileAccess.open(OS.get_environment("SP_OUT"), FileAccess.WRITE)
	for run_seed: int in 100:
		var buffer := RoadBuffer.new(RoadGenerator.new(run_seed, Fixtures.schedule(), true))
		buffer.start()
		_sim = CarSim.new(buffer)
		_sim.trigger.tutorial_completed.connect(_on_tutorial_completed)
		_sim.damaged.connect(_on_damaged)
		_ended_step = -1
		_damage = 0
		var pilot := Autopilot.new(_sim)
		_step = 0
		while _step < MAX_STEPS and not _sim.is_over():
			_step += 1
			_sim.step(DELTA, pilot.steer())
		var line := "%d,%.3f,%.3f,%d,%d,%d"
		out.store_line(
			(
				line
				% [
					run_seed,
					_ended_step * DELTA,
					_step * DELTA,
					_sim.state,
					_sim.trigger.turn_index,
					_damage
				]
			)
		)
	out.close()
	pass_test("done")


## What main.gd does (docs/TUTORIAL.md §5.5).
func _on_tutorial_completed(junction: RoadTile) -> void:
	_ended_step = _step
	_sim.buffer.generator.end_tutorial(junction.turn_number + 1)


func _on_damaged(_area: AreaDef) -> void:
	_damage += 1
