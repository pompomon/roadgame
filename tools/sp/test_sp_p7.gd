extends GutTest
## SP's probe P7 (SPEEDUP_PLAN.md §6.5): each road for seeds 0-199, digested with its dead ends
## up to the junction of each turn of TURNS. Writes road, seed, turn, md5 to SP_OUT.
## On sp/prototype only, outside tests/, so GUT runs it only by name. Run it with Godot, not
## tools/ci/run_tests.sh, which stops at 900 s:
##   SP_OUT=p7.csv godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir= \
##   -gtest=res://tools/sp/test_sp_p7.gd -gexit

const Fixtures := preload("res://tests/helpers/road_fixtures.gd")
const TURNS: Array[int] = [1, 10, 16, 19, 20, 21, 22, 24, 34]


func test_probe() -> void:
	var out := FileAccess.open(OS.get_environment("SP_OUT"), FileAccess.WRITE)
	for road_name: String in ["pier", "home"]:
		var road := Fixtures.schedule() if road_name == "pier" else Fixtures.schedule_home()
		for run_seed: int in 200:
			var gen := RoadGenerator.new(run_seed, road)
			var lines := PackedStringArray()
			for turn: int in TURNS:
				for tile: RoadTile in Fixtures.path_until_turn(gen, turn):
					lines.append(str(Fixtures.signature(tile)))
				var md5 := "\n".join(lines).md5_text()
				out.store_line("%s,%d,%d,%s" % [road_name, run_seed, turn, md5])
	out.close()
	pass_test("done")
