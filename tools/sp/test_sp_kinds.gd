extends GutTest
## SP's probe of U13 (SPEEDUP_PLAN.md §2). Counts each area's junctions by kind on the road to
## the sea, laid to turn 99, for seed 4993 and, on average, for seeds 0-999.
## On sp/prototype only, outside tests/, so GUT runs it only by name. Run it with Godot, not
## tools/ci/run_tests.sh, which stops at 900 s:
##   godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir= \
##   -gtest=res://tools/sp/test_sp_kinds.gd -gexit

const Fixtures := preload("res://tests/helpers/road_fixtures.gd")


func test_kinds() -> void:
	gut.p("4993: %s" % [_count(4993)])
	var totals := {}
	var decoys := []
	for run_seed: int in 1000:
		var counts := _count(run_seed)
		decoys.append(counts.get("meadows_DECOY", 0))
		for key: String in counts:
			totals[key] = totals.get(key, 0) + counts[key]
	for key: String in totals:
		totals[key] = totals[key] / 1000.0
	gut.p("mean of 0-999: %s" % [totals])
	decoys.sort()
	gut.p(
		(
			"meadows decoys: max %d, p99 %d, at least 15 in %d"
			% [decoys[-1], decoys[989], decoys.filter(func(n: int) -> bool: return n >= 15).size()]
		)
	)
	pass_test("done")


func _count(run_seed: int) -> Dictionary:
	var gen := RoadGenerator.new(run_seed, Fixtures.schedule())
	var counts := {}
	for tile: RoadTile in Fixtures.path_until_turn(gen, 99):
		if tile.expected_exit < 0:
			continue
		var key := "%s_%s" % [tile.area_id, RoadGenerator.Kind.keys()[Fixtures.kind(tile)]]
		counts[key] = counts.get(key, 0) + 1
	return counts
