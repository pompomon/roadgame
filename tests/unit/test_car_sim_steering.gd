extends GutTest
## CarSim's steering and moves (plan.md §2.2, IMPLEMENTATION_PLAN.md M2.2): it turns at STEER_RATE,
## with no input it straightens up to the nearest grid direction at STRAIGHTEN_RATE, and a move
## reports every cell it enters.

const Fixtures := preload("res://tests/helpers/road_fixtures.gd")


func _sim() -> CarSim:
	var buffer := RoadBuffer.new(RoadGenerator.new(1, Fixtures.schedule()))
	buffer.start()
	return CarSim.new(buffer)


func test_it_turns_at_the_steer_rate_and_moves_where_it_faces() -> void:
	var sim := _sim()
	var start := sim.angle
	sim.step(0.1, 1.0)
	assert_almost_eq(angle_difference(start, sim.angle), Tuning.STEER_RATE * 0.1, 1e-6, "right")
	sim.step(0.1, -3.0)
	assert_almost_eq(angle_difference(start, sim.angle), 0.0, 1e-6, "left, at most full lock")
	sim.step(0.1, -0.5)
	assert_almost_eq(angle_difference(start, sim.angle), -Tuning.STEER_RATE * 0.05, 1e-6, "half")
	var heading := Vector2(sin(sim.angle), -cos(sim.angle))
	assert_almost_eq(sim.velocity(), heading * sim.speed, Vector2(1e-6, 1e-6))


func test_with_no_input_it_straightens_up_to_the_nearest_grid_direction() -> void:
	var sim := _sim()
	var start := sim.angle
	sim.step(0.1, 1.0)
	sim.step(0.1, 0.0)
	var eased := Tuning.STEER_RATE * 0.1 - Tuning.STRAIGHTEN_RATE * 0.1
	assert_almost_eq(angle_difference(start, sim.angle), eased, 1e-6, "eased back")
	sim.step(0.3, 0.0)
	assert_almost_eq(angle_difference(start, sim.angle), 0.0, 1e-6, "straight, and no further")
	sim.angle = start + PI / 4.0 + 0.1
	sim.step(0.05, 0.0)
	var on := PI / 4.0 + 0.1 + Tuning.STRAIGHTEN_RATE * 0.05
	assert_almost_eq(angle_difference(start, sim.angle), on, 1e-6, "past 45 degrees, the next one")


func test_a_move_enters_each_cell_it_crosses_in_order() -> void:
	assert_eq(CarSim.cells_crossed(Vector2(0.2, 0.5), Vector2(0.8, 0.5)).size(), 0, "same cell")
	var east := CarSim.cells_crossed(Vector2(0.9, 0.5), Vector2(1.1, 0.5))
	assert_eq(east, [Vector2i(1, 0)] as Array[Vector2i], "one edge")
	# Across a cell corner, the neighbour behind the edge the move reaches first comes first.
	var x_first := CarSim.cells_crossed(Vector2(0.9, 0.95), Vector2(1.05, 1.02))
	assert_eq(x_first, [Vector2i(1, 0), Vector2i(1, 1)] as Array[Vector2i], "x edge first")
	var y_first := CarSim.cells_crossed(Vector2(0.95, 0.9), Vector2(1.02, 1.05))
	assert_eq(y_first, [Vector2i(0, 1), Vector2i(1, 1)] as Array[Vector2i], "y edge first")
	var back := CarSim.cells_crossed(Vector2(0.05, 0.15), Vector2(-0.05, -0.05))
	assert_eq(back, [Vector2i(-1, 0), Vector2i(-1, -1)] as Array[Vector2i], "towards -x and -y")
