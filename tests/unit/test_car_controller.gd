extends GutTest
## CarController and the car scene (IMPLEMENTATION_PLAN.md M2.4, M3.3): the sprite frame for a
## heading, and the car's view of its CarSim.

const Fixtures := preload("res://tests/helpers/road_fixtures.gd")
const CAR_SCENE := preload("res://car/car.tscn")
## The least change of luminance that a puff of smoke must make to what it covers, so that it
## shows. Measured on the sRGB values, as the 2D renderer blends them.
const SMOKE_CONTRAST := 0.1


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


func test_it_leaves_its_scale_and_modulate_to_a_disaster() -> void:
	# A disaster sinks the car by its scale and modulate, and the car keeps its position on the sim's
	# (M3_PLAN.md J3).
	var car := _car()
	car.sim.state = CarSim.State.DISASTER
	var sunk := Color(0.0, 0.0, 0.0, 0.5)
	car.scale = Vector2.ONE * 0.5
	car.modulate = sunk
	car.position = Vector2(1000.0, 1000.0)
	simulate(car, 2, 1.0 / 60.0)
	assert_eq(car.scale, Vector2.ONE * 0.5)
	assert_eq(car.modulate, sunk)
	assert_eq(car.position, Iso.tile_to_world(car.sim.pos), "the sim's position")


func test_a_crashed_car_turns_grey_and_smokes_without_being_redrawn() -> void:
	var car := _car()
	var arrow: Polygon2D = car.get_node("%Arrow")
	var smoke: CPUParticles2D = car.get_node("%Smoke")
	car.input.enabled = false
	await wait_physics_frames(2)
	assert_false(smoke.emitting, "driving")
	var draws: Array[int] = [0]
	arrow.draw.connect(func() -> void: draws[0] += 1)
	car.sim.state = CarSim.State.CRASHED
	await wait_physics_frames(2)
	assert_eq(arrow.self_modulate, Tuning.CRASH_TINT, "the crash frame")
	assert_true(smoke.emitting, "smokes")
	assert_eq(arrow.color, Color.WHITE, "the polygon itself stays white")
	assert_eq(draws[0], 0, "no redraws")


func test_every_car_smokes_alike() -> void:
	# Godot gives each CPUParticles2D a random seed when it's made, so unless the scene fixes one,
	# the smoke differs from run to run, whatever the run's seed (IP §5.3, M3_PLAN.md J16). The
	# editor doesn't save a seed of 0, its default.
	var smokes: Array[CPUParticles2D] = []
	for _i: int in 2:
		smokes.append(_car().get_node("%Smoke"))
	assert_true(smokes[0].use_fixed_seed, "a fixed seed")
	assert_ne(smokes[0].seed, 0, "one that the scene keeps")
	assert_eq(smokes[0].seed, smokes[1].seed, "the same in every car")


func test_the_smoke_shows_over_everything_the_grey_box_draws() -> void:
	var smoke: CPUParticles2D = _car().get_node("%Smoke")
	for background: Color in _backgrounds():
		var puff := background.blend(smoke.color)
		assert_gte(
			absf(puff.get_luminance() - background.get_luminance()),
			SMOKE_CONTRAST,
			"a puff over %s" % background
		)


func test_the_smoke_shows_through_a_tunnel() -> void:
	# A tunnel draws over the car (z_index 1), at TUNNEL_SEE_THROUGH while the car is in it
	# (Tunnel.opacity()): what it lets through of the smoke must still show.
	var smoke: CPUParticles2D = _car().get_node("%Smoke")
	var covers: Array[Color] = []
	for polygon: Polygon2D in _polygons(load("res://setpieces/tunnel.tscn")):
		covers.append(Color(polygon.color, polygon.color.a * Tuning.TUNNEL_SEE_THROUGH))
	assert_eq(covers.size(), 4)
	for background: Color in _backgrounds():
		var puff := background.blend(smoke.color)
		for cover: Color in covers:
			assert_gte(
				absf(puff.blend(cover).get_luminance() - background.blend(cover).get_luminance()),
				SMOKE_CONTRAST,
				"a puff over %s, through %s" % [background, cover]
			)


## What the grey box can draw under a puff of smoke. The smoke covers the grey arrow, and around it
## the road, its edge lines, or the ground under a road tile, in the area's two shades
## (GreyboxAtlas.build_ground_tileset()), or their transitions. Further from the road the grey box
## draws nothing, so the clear colour shows: a car lost off the road ends there. On a bridge, it
## draws the river, its waves, the deck and the far railing (M4.4); the near railing and a tunnel
## draw over the car.
func _backgrounds() -> Array[Color]:
	var backgrounds: Array[Color] = [Tuning.CRASH_TINT, GreyboxAtlas.EDGE_COLOR]
	backgrounds.append_array(GreyboxAtlas.ROAD_COLORS)
	backgrounds.append(
		ProjectSettings.get_setting("rendering/environment/defaults/default_clear_color")
	)
	var schedule: AreaSchedule = load("res://areas/schedule.tres")
	for entry: AreaScheduleEntry in schedule.entries:
		for shade: int in 2:
			backgrounds.append(entry.area.id_color.darkened(GreyboxAtlas.GROUND_SHADE * shade))
	var under := 0
	for polygon: Polygon2D in _polygons(load("res://setpieces/bridge.tscn")):
		if polygon.z_index <= 0:
			backgrounds.append(polygon.color)
			under += 1
	assert_eq(under, 4, "the river, a wave, the deck and the far railing")
	return backgrounds


## The polygons of a set piece, as its scene has them.
func _polygons(scene: PackedScene) -> Array[Polygon2D]:
	var piece: Node2D = autofree(scene.instantiate())
	var polygons: Array[Polygon2D] = []
	for polygon: Node in piece.find_children("*", "Polygon2D"):
		polygons.append(polygon)
	return polygons


func test_only_a_crash_smokes() -> void:
	var car := _car()
	car.input.enabled = false
	car.sim.state = CarSim.State.DISASTER
	simulate(car, 1, 1.0 / 60.0)
	var arrow: Polygon2D = car.get_node("%Arrow")
	assert_false(car.get_node("%Smoke").emitting, "after a disaster")
	assert_ne(arrow.self_modulate, Tuning.CRASH_TINT, "not grey")
