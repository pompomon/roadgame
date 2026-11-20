extends GutTest
## Crossing an area (docs/ENDGAME.md §5.16, W32): as the car drives on the road from the last path
## tile of an area onto the next area's first, CarSim says that it crossed the area that it left,
## once. Through a set piece, whose tiles are the area before's, that is at the set piece's end;
## with none, at the exit of the area's last junction, where the trigger judged the turn right.

const Fixtures := preload("res://tests/helpers/road_fixtures.gd")
const DELTA := 1.0 / 60.0
## The turn after which the second area starts.
const TURN := 2
## The ways into the second area: a tunnel 6 tiles long, or none.
const KINDS: Array[Array] = [[&"tunnel", 6], [&"", 0]]


## The path index of the first tile of the area "after" on `sim`'s road, or -1.
static func _border(sim: CarSim) -> int:
	for index: int in range(sim.buffer.first_index(), sim.buffer.last_index() + 1):
		if sim.buffer.path_tile(index).area_id == &"after":
			return index
	return -1


func test_the_car_crosses_an_area_onto_the_next_areas_first_tile() -> void:
	for kind: Array in KINDS:
		var schedule := Fixtures.set_piece_schedule(TURN, kind[0], kind[1])
		var buffer := RoadBuffer.new(RoadGenerator.new(1, schedule))
		buffer.start()
		var sim := CarSim.new(buffer)
		watch_signals(sim)
		var border := _border(sim)
		assert_gt(border, 0, "%s: the second area is on the road" % [kind])
		var pilot := Autopilot.new(sim)
		# The path index of the car's tile before the step that crossed, or -1.
		var crossed_from := -1
		for i: int in 60 * 60:
			if sim.progress >= border + 1 or sim.is_over():
				break
			var before := sim.path_tile.path_index
			var count: int = get_signal_emit_count(sim, "area_crossed")
			sim.step(DELTA, pilot.steer())
			if get_signal_emit_count(sim, "area_crossed") > count and crossed_from < 0:
				crossed_from = before
		assert_eq(crossed_from, border - 1, "%s: from the area's last tile" % [kind])
		assert_signal_emit_count(sim, "area_crossed", 1, str(kind))
		assert_signal_emitted_with_parameters(sim, "area_crossed", [schedule.entries[0].area])
		assert_true(sim.state in [CarSim.State.DRIVING, CarSim.State.BRAKING], "on the road")
