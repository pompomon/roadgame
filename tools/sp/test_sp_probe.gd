extends GutTest
## SP's probe P1 (SPEEDUP_PLAN.md §6.5), also run for P5, P6 and P10. Drives seeds SP_FIRST to
## SP_FIRST + SP_SEEDS - 1 of the road SP_ROAD (pier or home) with the autopilot and writes to
## SP_OUT a row per zone and a TOTAL row per seed.
## Zone rows: road, seed, area, enter_s, enter_turn, enter_tile, secs, tiles, max_speed, end_cap.
## TOTAL rows: road, seed, TOTAL, 0, turn_index, 0, secs, progress, arrived, damage + 10 * dropped,
## then the game time at turns 49 and 90.
## On sp/prototype only, outside tests/, so GUT runs it only by name. Run it with Godot, not
## tools/ci/run_tests.sh, which stops at 900 s:
##   SP_FIRST=0 SP_SEEDS=5000 SP_ROAD=pier SP_OUT=p1_pier.csv \
##   godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir= \
##   -gtest=res://tools/sp/test_sp_probe.gd -gexit

const Fixtures := preload("res://tests/helpers/road_fixtures.gd")
const DELTA := 1.0 / 60.0
const MAX_STEPS := 60 * 60 * 20

var _damage := 0


func test_probe() -> void:
	var first := OS.get_environment("SP_FIRST").to_int()
	var count := OS.get_environment("SP_SEEDS").to_int()
	var road_name := OS.get_environment("SP_ROAD")
	var road := Fixtures.schedule() if road_name == "pier" else Fixtures.schedule_home()
	var out := FileAccess.open(OS.get_environment("SP_OUT"), FileAccess.WRITE)
	out.store_line("road,seed,area,enter_s,enter_turn,enter_tile,secs,tiles,max_speed,end_cap")
	for run_seed: int in range(first, first + count):
		_drive(out, road_name, run_seed, RoadGenerator.new(run_seed, road))
	out.close()
	pass_test("done")


func _drive(out: FileAccess, road_name: String, run_seed: int, gen: RoadGenerator) -> void:
	var buffer := RoadBuffer.new(gen)
	buffer.start()
	var sim := CarSim.new(buffer)
	sim.damaged.connect(_on_damaged)
	_damage = 0
	var pilot := Autopilot.new(sim)
	var steps := 0
	var zone := sim.area
	var entered := 0
	var enter_turn := 0
	var enter_tile := 0.0
	var top := 0.0
	var at := {49: -1.0, 90: -1.0}
	while steps < MAX_STEPS and not sim.is_over():
		sim.step(DELTA, pilot.steer())
		steps += 1
		top = maxf(top, sim.speed)
		for turn: int in at:
			if at[turn] < 0.0 and sim.trigger.turn_index >= turn:
				at[turn] = steps * DELTA
		if sim.area != zone:
			_row(
				out,
				[road_name, run_seed, zone.id, entered, enter_turn, enter_tile],
				steps,
				sim,
				top
			)
			zone = sim.area
			entered = steps
			enter_turn = sim.trigger.turn_index
			enter_tile = sim.progress
			top = 0.0
	_row(out, [road_name, run_seed, zone.id, entered, enter_turn, enter_tile], steps, sim, top)
	var arrived := 1 if sim.state == CarSim.State.ARRIVED else 0
	var bad := _damage + 10 * gen.dropped_count
	out.store_line(
		(
			"%s,%d,TOTAL,0,%d,0,%.4f,%.3f,%d,%d,%.4f,%.4f"
			% [
				road_name,
				run_seed,
				sim.trigger.turn_index,
				steps * DELTA,
				sim.progress,
				arrived,
				bad,
				at[49],
				at[90]
			]
		)
	)


func _row(out: FileAccess, head: Array, steps: int, sim: CarSim, top: float) -> void:
	var cap := minf(
		Tuning.GLOBAL_SPEED_CAP, Tuning.BASE_TOP_SPEED + sim.dist_total * Tuning.TOP_SPEED_GROWTH
	)
	out.store_line(
		(
			"%s,%d,%s,%.4f,%d,%.3f,%.4f,%.3f,%.4f,%.4f"
			% [
				head[0],
				head[1],
				head[2],
				head[3] * DELTA,
				head[4],
				head[5],
				(steps - head[3]) * DELTA,
				sim.progress - head[5],
				top,
				cap
			]
		)
	)


func _on_damaged(_area: AreaDef) -> void:
	_damage += 1
