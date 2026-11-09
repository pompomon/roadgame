extends GutTest
## The tornado (plan.md §4.3, IMPLEMENTATION_PLAN.md M4.5): after its delay it comes at the stopped
## car along its params' direction, whirling dust and shaking the camera; it carries the car off,
## spinning, shrinking and fading it; then it goes on its way and fades.
## tests/unit/test_disasters.gd checks what every disaster does.

const Disasters := preload("res://tests/helpers/disaster_fixtures.gd")
const TORNADO := preload("res://disasters/tornado.tscn")
const DELTA := Disasters.DELTA
const MAX_FRAMES := Disasters.MAX_FRAMES


func _tornado(car: CarController, camera: CameraRig) -> Tornado:
	return Disasters.disaster(self, TORNADO, car, camera) as Tornado


func test_it_comes_along_its_direction_carries_the_car_off_and_goes_on() -> void:
	var car := Disasters.car(self)
	var tornado := _tornado(car, Disasters.camera(self))
	var funnel: Node2D = tornado.get_node("%Funnel")
	var params := Disasters.params()
	tornado.play(params)
	var from := Iso.tile_to_world(-params.direction * Tuning.TORNADO_APPROACH_TILES)
	var to := Iso.tile_to_world(params.direction * Tuning.TORNADO_LEAVE_TILES)
	assert_eq(funnel.position, from, "it comes from behind its direction")
	var phases: Array[Tornado.Phase] = [tornado.phase]
	var lifted_at := Vector2.INF
	var frames := 0
	while tornado.phase != Tornado.Phase.DONE and frames < MAX_FRAMES:
		simulate(tornado, 1, DELTA)
		frames += 1
		if tornado.phase != phases.back():
			phases.append(tornado.phase)
			if tornado.phase == Tornado.Phase.LIFT:
				lifted_at = funnel.position
		if tornado.phase == Tornado.Phase.DELAY or tornado.phase == Tornado.Phase.APPROACH:
			assert_eq(car.scale, Vector2.ONE, "the car waits for the funnel")
	var order: Array[Tornado.Phase] = [
		Tornado.Phase.DELAY,
		Tornado.Phase.APPROACH,
		Tornado.Phase.LIFT,
		Tornado.Phase.LEAVE,
		Tornado.Phase.DONE,
	]
	assert_eq(phases, order, "every phase, in order")
	assert_eq(lifted_at, Vector2.ZERO, "it reaches the car")
	assert_almost_eq(funnel.position, to, Vector2.ONE * 1e-3, "and goes on along its direction")
	assert_almost_eq(car.scale, Vector2.ONE * Tornado.LIFTED_SCALE, Vector2.ONE * 1e-6, "carried")
	assert_eq(car.modulate.a, 0.0, "off")


func test_the_funnel_moves_straight_and_fades_in_and_out() -> void:
	var tornado := _tornado(null, null)
	var funnel: Node2D = tornado.get_node("%Funnel")
	var params := Disasters.params()
	tornado.play(params)
	var line := Iso.tile_to_world(params.direction).normalized()
	var alphas := {}
	var frames := 0
	while tornado.phase != Tornado.Phase.DONE and frames < MAX_FRAMES:
		simulate(tornado, 1, DELTA)
		frames += 1
		assert_almost_eq(line.cross(funnel.position), 0.0, 1e-3, "on one line through the car")
		var seen: Array = alphas.get(tornado.phase, [])
		seen.append(funnel.modulate.a)
		alphas[tornado.phase] = seen
	assert_eq(alphas[Tornado.Phase.DELAY].max(), 0.0, "unseen in its delay")
	assert_eq(alphas[Tornado.Phase.APPROACH].max(), 1.0, "it fades in as it comes")
	assert_eq(alphas[Tornado.Phase.LIFT].min(), 1.0, "and shows as it lifts the car")
	assert_eq(alphas[Tornado.Phase.DONE].max(), 0.0, "then fades out")


func test_the_car_spins_shrinks_and_fades_as_it_lifts() -> void:
	var car := Disasters.car(self)
	var tornado := _tornado(car, null)
	var params := Disasters.params()
	tornado.play(params)
	var spins: Array[float] = []
	var scales: Array[float] = []
	var alphas: Array[float] = []
	var frames := 0
	while tornado.phase != Tornado.Phase.DONE and frames < MAX_FRAMES:
		simulate(tornado, 1, DELTA)
		frames += 1
		if tornado.phase == Tornado.Phase.LIFT:
			spins.append(car.rotation)
			scales.append(car.scale.x)
			alphas.append(car.modulate.a)
	assert_gt(spins.size(), 30, "it lifts the car for a while")
	assert_eq(spins, Disasters.sorted(spins), "the car only spins one way")
	assert_eq(scales, Disasters.sorted(scales, true), "only shrinks")
	assert_eq(alphas, Disasters.sorted(alphas, true), "and only fades")
	var full := Tornado.spin(params, Tuning.TORNADO_LIFT_SECONDS)
	assert_almost_eq(car.rotation, full, 1e-4, "the whole spin")
	assert_gt(full, TAU, "more than a turn")
	# Halfway through the lift, each change is about halfway done.
	assert_between(Disasters.middle(spins), 0.25 * full, 0.75 * full, "half spun")
	var shrunk := lerpf(1.0, Tornado.LIFTED_SCALE, 0.75)
	assert_between(
		Disasters.middle(scales), shrunk, lerpf(1.0, Tornado.LIFTED_SCALE, 0.25), "half shrunk"
	)
	assert_between(Disasters.middle(alphas), 0.25, 0.75, "half faded")


func test_a_stronger_tornado_is_bigger_and_spins_the_car_faster() -> void:
	var spins: Array[float] = []
	for intensity: float in [Tuning.DISASTER_INTENSITY_MIN, Tuning.DISASTER_INTENSITY_MAX]:
		var tornado := _tornado(null, null)
		var params := Disasters.params(intensity)
		tornado.play(params)
		var funnel: Node2D = tornado.get_node("%Funnel")
		assert_eq(funnel.scale, Vector2.ONE * intensity, "its size")
		spins.append(Tornado.spin(params, 1.0))
	assert_gt(spins[1], spins[0], "a faster spin")


func test_the_dust_whirls_while_it_comes_and_lifts_the_car() -> void:
	var tornado := _tornado(null, null)
	var dust: CPUParticles2D = tornado.get_node("%Dust")
	tornado.play(Disasters.params())
	var flying := {}
	var frames := 0
	while tornado.phase != Tornado.Phase.DONE and frames < MAX_FRAMES:
		simulate(tornado, 1, DELTA)
		frames += 1
		flying[tornado.phase] = flying.get(tornado.phase, false) or dust.emitting
	assert_eq(
		flying,
		{
			Tornado.Phase.DELAY: false,
			Tornado.Phase.APPROACH: true,
			Tornado.Phase.LIFT: true,
			Tornado.Phase.LEAVE: false,
			Tornado.Phase.DONE: false,
		}
	)


func test_it_shakes_the_camera_as_it_comes() -> void:
	var camera := Disasters.camera(self)
	var tornado := _tornado(null, camera)
	tornado.play(Disasters.params())
	var frames := 0
	while tornado.phase == Tornado.Phase.DELAY and frames < MAX_FRAMES:
		assert_eq(camera.offset, Vector2.ZERO, "still")
		simulate(tornado, 1, DELTA)
		frames += 1
	assert_ne(camera.offset, Vector2.ZERO, "shakes")


func test_the_funnel_draws_over_the_car_and_its_shadow_under() -> void:
	# World's DisasterLayer comes before Props, which holds the car at z_index 0 (M3_PLAN.md J5).
	var car := Disasters.car(self)
	var tornado := _tornado(car, null)
	assert_eq(Disasters.z(car), 0)
	for part: String in ["%Body", "%Core", "%Dust"]:
		assert_gt(Disasters.z(tornado.get_node(part)), Disasters.z(car), "%s over the car" % part)
	assert_eq(Disasters.z(tornado.get_node("%Shadow")), 0, "the shadow on the ground")
