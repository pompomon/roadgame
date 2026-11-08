extends GutTest
## A car that cuts the inside corner of a turn leaves the road next to the junction and rejoins on
## the correct exit within the off-road limit: the turn counts and the car takes damage
## (plan.md §2.4, §4.1, IMPLEMENTATION_PLAN.md D5, D6).

const Fixtures := preload("res://tests/helpers/road_fixtures.gd")
const DELTA := 1.0 / 60.0


## Pure pursuit that aims further ahead than Autopilot, so it cuts corners.
class CornerCutter:
	extends Autopilot

	var _lookahead: float

	func _init(sim: CarSim, lookahead: float) -> void:
		super(sim)
		_lookahead = lookahead

	func steer() -> float:
		var aim := _sim.buffer.centreline_point(_sim.progress + _lookahead) - _sim.pos
		var error := wrapf(atan2(aim.x, -aim.y) - _sim.angle, -PI, PI)
		return clampf(error * GAIN, -1.0, 1.0)


func test_cutting_the_corner_completes_the_turn_with_damage() -> void:
	var rejoined_on: Array[int] = []
	for lookahead: float in [2.0, 2.5]:
		for run_seed: int in 8:
			var buffer := RoadBuffer.new(RoadGenerator.new(run_seed, Fixtures.schedule()))
			buffer.start()
			var sim := CarSim.new(buffer)
			var junction := sim.trigger.next_junction
			var pilot := CornerCutter.new(sim, lookahead)
			var left_near := false
			var turned_on_rejoin := false
			for i: int in 600:
				var was_offroad := sim.state == CarSim.State.OFFROAD
				sim.step(DELTA, pilot.steer())
				left_near = left_near or sim.offroad_junction == junction
				if sim.trigger.turn_index > 0 or sim.is_over():
					turned_on_rejoin = was_offroad and sim.state == CarSim.State.DRIVING
					break
			var where := "lookahead %.1f, seed %d" % [lookahead, run_seed]
			assert_eq(sim.trigger.turn_index, 1, where)
			assert_true(left_near, where + ": left the road next to the junction")
			assert_true(turned_on_rejoin, where + ": the rejoin decided the turn")
			assert_between(sim.health, 1.0, Tuning.START_HEALTH - 1.0, where)
			var tile := buffer.tile_at(Vector2i(sim.pos.floor()))
			if not tile.path_index - junction.path_index in rejoined_on:
				rejoined_on.append(tile.path_index - junction.path_index)
	rejoined_on.sort()
	assert_eq(rejoined_on, [1, 2] as Array[int], "rejoined on the first and second exit tiles")
