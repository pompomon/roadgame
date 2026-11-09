extends GutTest
## The autopilot drives to turn 230 through the five areas in the schedule's order
## (IMPLEMENTATION_PLAN.md M4 tests): CarSim reports each new area once, as the car reaches it after
## its turn and its set piece.

const Fixtures := preload("res://tests/helpers/road_fixtures.gd")
const DELTA := 1.0 / 60.0
const TURNS := 230
## A run to turn 230 takes about 7 minutes of game time.
const MAX_STEPS := 60 * 60 * 15


func test_the_autopilot_meets_the_areas_and_set_pieces_in_order() -> void:
	var buffer := RoadBuffer.new(RoadGenerator.new(1, Fixtures.schedule()))
	buffer.start()
	var sim := CarSim.new(buffer)
	var pilot := Autopilot.new(sim)
	watch_signals(sim)
	assert_eq(sim.area.id, &"city", "it starts in the City")
	var changes: Array = []
	var pieces: Array[StringName] = []
	for i: int in MAX_STEPS:
		var area := sim.area
		sim.step(DELTA, pilot.steer())
		if sim.area != area:
			changes.append([sim.trigger.turn_index, sim.area.id])
		var piece := sim.path_tile.set_piece
		if piece != &"" and not pieces.has(piece):
			pieces.append(piece)
		if sim.is_over() or sim.trigger.turn_index >= TURNS:
			break
	assert_eq(sim.trigger.turn_index, TURNS)
	assert_false(sim.is_over())
	var expected: Array = [[34, &"rural"], [100, &"meadows"], [200, &"village"], [220, &"desert"]]
	assert_eq(changes, expected)
	assert_signal_emit_count(sim, "area_changed", expected.size())
	for k: int in expected.size():
		var area: AreaDef = get_signal_parameters(sim, "area_changed", k)[0]
		assert_eq(area.id, expected[k][1], "area_changed %d" % k)
	assert_eq(pieces, [&"tunnel", &"bridge"] as Array[StringName])
