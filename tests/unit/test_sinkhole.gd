extends GutTest
## The sinkhole (plan.md §4.3, IMPLEMENTATION_PLAN.md M3.2): after its delay it opens under the
## car, throws debris and shakes the camera, and the car sinks; then it finishes, once. It grows by
## its scale and sinks the car by its scale and modulate, so that nothing is redrawn and the car's
## position is left to CarController (M3_PLAN.md J3).

const Fixtures := preload("res://tests/helpers/road_fixtures.gd")
const CAR_SCENE := preload("res://car/car.tscn")
const SINKHOLE := preload("res://disasters/sinkhole.tscn")
const DELTA := 1.0 / 60.0


static func _params() -> DisasterParams:
	var params := DisasterParams.new()
	params.direction = Vector2.RIGHT
	params.intensity = 0.8
	params.delay = 0.3
	params.particle_scale = 1.2
	params.particle_seed = 42
	params.origin_world = Vector2(100.0, 50.0)
	return params


## A car whose run ended at the start of the road for seed 1. Nothing steps it.
func _car() -> CarController:
	var buffer := RoadBuffer.new(RoadGenerator.new(1, Fixtures.schedule()))
	buffer.start()
	var car: CarController = CAR_SCENE.instantiate()
	car.sim = CarSim.new(buffer)
	car.sim.state = CarSim.State.DISASTER
	car.input = InputRouter.new()
	add_child_autofree(car)
	car.add_child(car.input)
	return car


func _sinkhole(car: CarController, camera: CameraRig) -> Sinkhole:
	var sinkhole: Sinkhole = SINKHOLE.instantiate()
	sinkhole.car = car
	sinkhole.camera = camera
	add_child_autofree(sinkhole)
	return sinkhole


func _camera() -> CameraRig:
	var camera := CameraRig.new()
	add_child_autofree(camera)
	return camera


func test_it_is_a_disaster_with_an_id() -> void:
	var sinkhole := _sinkhole(null, null)
	assert_true(sinkhole is DisasterBase)
	assert_eq(sinkhole.id, &"sinkhole")


func test_it_waits_for_play() -> void:
	var car := _car()
	var sinkhole := _sinkhole(car, _camera())
	watch_signals(sinkhole)
	simulate(sinkhole, 300, DELTA)
	assert_eq(sinkhole.phase, Sinkhole.Phase.WAITING)
	var hole: Polygon2D = sinkhole.get_node("%Hole")
	# Not 0: Node2D stores a zero scale as CMP_EPSILON (scene/2d/node_2d.cpp, set_scale).
	assert_almost_eq(hole.scale, Vector2.ZERO, Vector2.ONE * 1e-4, "closed")
	assert_false(sinkhole.get_node("%Debris").emitting)
	assert_eq(car.scale, Vector2.ONE)
	assert_signal_not_emitted(sinkhole, "finished")


func test_it_opens_sinks_the_car_and_finishes_once_after_its_duration() -> void:
	var car := _car()
	var at := car.position
	var sinkhole := _sinkhole(car, _camera())
	var params := _params()
	watch_signals(sinkhole)
	sinkhole.play(params)
	assert_eq(sinkhole.position, params.origin_world, "where the car stopped")
	var phases: Array[Sinkhole.Phase] = [sinkhole.phase]
	var frames := 0
	while sinkhole.phase != Sinkhole.Phase.DONE and frames < 600:
		simulate(sinkhole, 1, DELTA)
		frames += 1
		if sinkhole.phase != phases.back():
			phases.append(sinkhole.phase)
	var order: Array[Sinkhole.Phase] = [
		Sinkhole.Phase.DELAY,
		Sinkhole.Phase.GROW,
		Sinkhole.Phase.SINK,
		Sinkhole.Phase.HOLD,
		Sinkhole.Phase.DONE,
	]
	assert_eq(phases, order, "every phase, in order")
	assert_almost_eq(frames * DELTA, Sinkhole.duration(params), DELTA * 1.01, "its duration")
	simulate(sinkhole, 120, DELTA)
	assert_signal_emit_count(sinkhole, "finished", 1)
	var hole: Polygon2D = sinkhole.get_node("%Hole")
	var rim: Polygon2D = sinkhole.get_node("%Rim")
	assert_almost_eq(hole.scale, Vector2.ONE * params.intensity, Vector2.ONE * 1e-6, "open")
	assert_eq(rim.scale, hole.scale)
	assert_almost_eq(car.scale, Vector2.ONE * Sinkhole.SUNK_SCALE, Vector2.ONE * 1e-6, "sunk")
	assert_eq(car.modulate.a, 0.0, "out of sight")
	assert_eq(car.position, at, "CarController keeps the position")


func test_it_grows_while_it_opens_and_the_car_sinks_after() -> void:
	var car := _car()
	var sinkhole := _sinkhole(car, null)
	var params := _params()
	sinkhole.play(params)
	var hole: Polygon2D = sinkhole.get_node("%Hole")
	var sizes: Array[float] = []
	var car_scales: Array[float] = []
	while sinkhole.phase != Sinkhole.Phase.DONE:
		simulate(sinkhole, 1, DELTA)
		if sinkhole.phase == Sinkhole.Phase.GROW:
			sizes.append(hole.scale.x)
			assert_eq(car.scale, Vector2.ONE, "the car waits for the hole")
		elif sinkhole.phase == Sinkhole.Phase.SINK:
			car_scales.append(car.scale.x)
	assert_gt(sizes.size(), 30, "the hole grows for a while")
	assert_eq(sizes, _sorted(sizes), "the hole only grows")
	assert_lt(sizes[0], 0.1, "from closed")
	assert_gt(car_scales.size(), 30, "the car sinks for a while")
	assert_eq(car_scales, _sorted(car_scales, true), "the car only shrinks")


static func _sorted(values: Array[float], descending := false) -> Array[float]:
	var sorted: Array[float] = values.duplicate()
	sorted.sort()
	if descending:
		sorted.reverse()
	return sorted


func test_the_debris_follows_its_params_and_flies_while_the_hole_opens() -> void:
	var sinkhole := _sinkhole(_car(), null)
	var debris: CPUParticles2D = sinkhole.get_node("%Debris")
	var velocity := debris.initial_velocity_max
	var size := debris.scale_amount_max
	var params := _params()
	sinkhole.play(params)
	assert_true(debris.use_fixed_seed, "seeded")
	assert_eq(debris.seed, params.particle_seed)
	assert_almost_eq(debris.initial_velocity_max, velocity * params.intensity, 1e-3)
	assert_almost_eq(debris.scale_amount_max, size * params.particle_scale, 1e-3)
	# The params' direction, right in tile space, is down and right on screen.
	assert_gt(debris.direction.x, 0.0, "leans right")
	assert_lt(debris.direction.y, 0.0, "but flies up")
	var flying := {}
	while sinkhole.phase != Sinkhole.Phase.DONE:
		simulate(sinkhole, 1, DELTA)
		flying[sinkhole.phase] = flying.get(sinkhole.phase, false) or debris.emitting
	assert_eq(
		flying,
		{
			Sinkhole.Phase.DELAY: false,
			Sinkhole.Phase.GROW: true,
			Sinkhole.Phase.SINK: true,
			Sinkhole.Phase.HOLD: false,
			Sinkhole.Phase.DONE: false,
		}
	)


func test_it_shakes_the_camera_as_it_opens() -> void:
	var camera := _camera()
	var sinkhole := _sinkhole(_car(), camera)
	sinkhole.play(_params())
	while sinkhole.phase == Sinkhole.Phase.DELAY:
		assert_eq(camera.offset, Vector2.ZERO, "still")
		simulate(sinkhole, 1, DELTA)
	assert_ne(camera.offset, Vector2.ZERO, "shakes")


func test_it_grows_and_sinks_the_car_without_redrawing() -> void:
	# Every redraw of a Polygon2D after its first raises WebGL errors on the Web (M2_PLAN.md §5.7).
	var car := _car()
	var sinkhole := _sinkhole(car, null)
	await wait_physics_frames(2)
	var draws: Array[int] = [0]
	for polygon: Polygon2D in [
		sinkhole.get_node("%Hole"), sinkhole.get_node("%Rim"), car.get_node("%Arrow")
	]:
		polygon.draw.connect(_count.bind(draws))
	sinkhole.play(_params())
	simulate(sinkhole, 300, DELTA)
	assert_eq(sinkhole.phase, Sinkhole.Phase.DONE)
	await wait_physics_frames(2)
	assert_eq(draws[0], 0, "no redraws")


func _count(draws: Array[int]) -> void:
	draws[0] += 1


func test_it_finishes_without_a_car_or_a_camera() -> void:
	var sinkhole := _sinkhole(null, null)
	watch_signals(sinkhole)
	sinkhole.play(_params())
	simulate(sinkhole, 300, DELTA)
	assert_signal_emit_count(sinkhole, "finished", 1)


func test_with_the_stop_it_takes_2_to_4_seconds() -> void:
	# The director starts it once the car has stopped, which takes up to STOP_SECONDS (J4).
	var quickest := DisasterParams.new()
	quickest.delay = Tuning.DISASTER_DELAY_MIN
	var slowest := DisasterParams.new()
	slowest.delay = Tuning.DISASTER_DELAY_MAX
	assert_gte(Sinkhole.duration(quickest), 2.0)
	assert_lte(Sinkhole.duration(slowest) + Tuning.STOP_SECONDS, 4.0)
