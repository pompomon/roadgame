extends GutTest
## CarController and the car scene (IMPLEMENTATION_PLAN.md M2.4): the sprite frame for a heading,
## and the car's view of its CarSim.

const Fixtures := preload("res://tests/helpers/road_fixtures.gd")
const CAR_SCENE := preload("res://car/car.tscn")


func _car() -> CarController:
	var buffer := RoadBuffer.new(RoadGenerator.new(1, Fixtures.schedule()))
	buffer.start()
	var car: CarController = CAR_SCENE.instantiate()
	car.sim = CarSim.new(buffer)
	car.input = InputRouter.new()
	add_child_autofree(car)
	car.add_child(car.input)
	return car


func test_the_grid_headings_get_the_nearest_of_16_frames() -> void:
	# The isometric axes are 63.4 degrees from screen up, so the arrow is 4.1 degrees off them.
	var frames: Array[int] = []
	for heading: Vector2 in [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]:
		frames.append(CarController.frame(heading))
	assert_eq(frames, [3, 5, 11, 13] as Array[int], "N, E, S and W")
	assert_eq(CarController.frame(Vector2(1.0, -1.0)), 4, "NE is screen right")
	assert_eq(CarController.frame(Vector2(-1.0, -1.0)), 0, "NW is screen up")


func test_it_steps_its_sim_with_the_input_and_moves_with_it() -> void:
	var car := _car()
	car.input.autopilot = Autopilot.new(car.sim)
	var start := car.sim.pos
	simulate(car, 60, 1.0 / 60.0)
	assert_gt(car.sim.pos.distance_to(start), 0.5, "a second of driving")
	assert_eq(car.position, Iso.tile_to_world(car.sim.pos))
	var frame := CarController.frame(car.sim.forward())
	var arrow: Polygon2D = car.get_node("%Arrow")
	assert_almost_eq(arrow.rotation, frame * TAU / CarController.FRAMES, 1e-6)


func test_the_arrow_turns_and_changes_hue_without_being_redrawn() -> void:
	# On the Web, every redraw of a Polygon2D after the first raises WebGL errors
	# (godotengine/godot#124726), so the car must not redraw it as it turns.
	var car := _car()
	var arrow: Polygon2D = car.get_node("%Arrow")
	car.input.enabled = false
	await wait_physics_frames(2)
	var draws: Array[int] = [0]
	arrow.draw.connect(func() -> void: draws[0] += 1)
	var hues: Array[Color] = []
	for heading: int in 4:
		car.sim.angle = heading * PI / 2.0
		await wait_physics_frames(2)
		hues.append(arrow.self_modulate)
	var expected: Array[Color] = []
	for frame: int in [3, 5, 11, 13]:
		expected.append(Color.from_hsv(float(frame) / CarController.FRAMES, 0.6, 1.0))
	assert_eq(hues, expected, "a hue per frame: N, E, S and W")
	assert_eq(arrow.color, Color.WHITE, "the polygon itself stays white")
	assert_eq(draws[0], 0, "no redraws")


func test_dust_flies_only_while_the_car_is_off_the_road() -> void:
	var car := _car()
	var dust: CPUParticles2D = car.get_node("%Dust")
	assert_false(dust.emitting, "on the road")
	car.input.enabled = false
	car.sim.angle += PI / 2.0
	for _i: int in 120:
		simulate(car, 1, 1.0 / 60.0)
		if car.sim.state == CarSim.State.OFFROAD:
			break
	assert_eq(car.sim.state, CarSim.State.OFFROAD, "drove off sideways")
	assert_true(dust.emitting, "off the road")
