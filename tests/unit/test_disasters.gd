extends GutTest
## What every disaster in an area's pool does (plan.md §4.2, IMPLEMENTATION_PLAN.md M3.1 and M4.5):
## it shows nothing until play() and its delay; then it finishes once, after its static
## duration(params), with the car out of sight where it stopped; and with the car's stop it takes 2
## to 4 s from the turn. It seeds its particles from its params and never redraws a polygon
## (M2_PLAN.md §5.7). The pools come from the game's schedule, so a new disaster is checked too.

const Fixtures := preload("res://tests/helpers/road_fixtures.gd")
const Disasters := preload("res://tests/helpers/disaster_fixtures.gd")
const DELTA := Disasters.DELTA
const MAX_FRAMES := Disasters.MAX_FRAMES


func test_each_area_has_its_pool_of_disasters() -> void:
	# plan.md §4.3 and IMPLEMENTATION_PLAN.md M4.2.
	var pools := {
		# The City's.
		&"city": [&"sinkhole"],
		# Rural's.
		&"rural": [&"tornado"],
		# The Meadows'.
		&"meadows": [&"flood"],
		# The Village's.
		&"village": [&"flood", &"tornado"],
		# The Desert's.
		&"desert": [&"quicksand"],
	}
	var areas: Array = []
	for entry: AreaScheduleEntry in Fixtures.schedule().entries:
		var area := entry.area
		areas.append(area.id)
		var ids: Array = []
		for scene: PackedScene in area.disasters:
			var disaster := Disasters.disaster(self, scene, null, null)
			ids.append(disaster.id)
			assert_eq(
				scene.resource_path,
				"res://disasters/%s.tscn" % disaster.id,
				"%s: the scene is named after its id" % area.id
			)
		assert_eq(ids, pools.get(area.id, []), "%s's pool" % area.id)
	assert_eq(areas, pools.keys(), "the five areas")
	var all: Array[StringName] = []
	for scene: PackedScene in Disasters.scenes():
		all.append(Disasters.disaster(self, scene, null, null).id)
	assert_eq(all, [&"sinkhole", &"tornado", &"flood", &"quicksand"] as Array[StringName])


func test_each_shows_nothing_until_its_delay_is_over() -> void:
	for scene: PackedScene in Disasters.scenes():
		var car := Disasters.car(self)
		var camera := Disasters.camera(self)
		var disaster := Disasters.disaster(self, scene, car, camera)
		watch_signals(disaster)
		simulate(disaster, 300, DELTA)
		_assert_hidden(disaster, car, camera, "%s before play()" % disaster.id)
		var params := Disasters.params()
		disaster.play(params)
		assert_eq(disaster.position, params.origin_world, "%s: where the car stopped" % disaster.id)
		simulate(disaster, floori(params.delay / DELTA) - 1, DELTA)
		_assert_hidden(disaster, car, camera, "%s in its delay" % disaster.id)
		simulate(disaster, roundi(1.0 / DELTA), DELTA)
		var shown := Disasters.polygons(disaster).filter(Disasters.shows)
		assert_false(shown.is_empty(), "%s shows a second after its delay" % disaster.id)
		assert_signal_not_emitted(disaster, "finished", disaster.id)


func _assert_hidden(
	disaster: DisasterBase, car: CarController, camera: CameraRig, when: String
) -> void:
	for polygon: Polygon2D in Disasters.polygons(disaster):
		assert_false(Disasters.shows(polygon), "%s: %s is hidden" % [when, polygon.name])
	for particles: CPUParticles2D in Disasters.particles(disaster):
		assert_false(particles.emitting, "%s: %s waits" % [when, particles.name])
	assert_eq(car.scale, Vector2.ONE, "%s: the car's scale" % when)
	assert_eq(car.rotation, 0.0, "%s: the car's rotation" % when)
	assert_eq(car.modulate, Color.WHITE, "%s: the car's modulate" % when)
	assert_eq(camera.offset, Vector2.ZERO, "%s: the camera is still" % when)


func test_each_finishes_once_after_its_duration_with_the_car_out_of_sight() -> void:
	for scene: PackedScene in Disasters.scenes():
		for intensity: float in [Tuning.DISASTER_INTENSITY_MIN, Tuning.DISASTER_INTENSITY_MAX]:
			var car := Disasters.car(self)
			var at := car.position
			var disaster := Disasters.disaster(self, scene, car, Disasters.camera(self))
			var params := Disasters.params(intensity)
			var what := "%s at intensity %.1f" % [disaster.id, intensity]
			watch_signals(disaster)
			disaster.play(params)
			var frames := 0
			while get_signal_emit_count(disaster, "finished") == 0 and frames < MAX_FRAMES:
				simulate(disaster, 1, DELTA)
				frames += 1
			assert_almost_eq(
				frames * DELTA,
				Disasters.duration(disaster, params),
				DELTA * 1.01,
				"%s: its duration" % what
			)
			simulate(disaster, 120, DELTA)
			assert_signal_emit_count(disaster, "finished", 1, "%s: once" % what)
			assert_eq(car.position, at, "%s: it leaves the car where it stopped" % what)
			assert_eq(car.modulate.a, 0.0, "%s: the car is out of sight" % what)


func test_each_finishes_without_a_car_or_a_camera() -> void:
	for scene: PackedScene in Disasters.scenes():
		var disaster := Disasters.disaster(self, scene, null, null)
		watch_signals(disaster)
		disaster.play(Disasters.params())
		simulate(disaster, MAX_FRAMES, DELTA)
		assert_signal_emit_count(disaster, "finished", 1, disaster.id)


func test_each_seeds_its_particles_from_its_params_and_scales_them() -> void:
	# Godot gives each CPUParticles2D a random seed when it's made (M3_PLAN.md J16).
	for scene: PackedScene in Disasters.scenes():
		var disaster := Disasters.disaster(self, scene, null, null)
		var particles := Disasters.particles(disaster)
		assert_false(particles.is_empty(), "%s has particles" % disaster.id)
		var before: Array[Vector4] = []
		for emitter: CPUParticles2D in particles:
			before.append(_amounts(emitter))
		var params := Disasters.params(1.2)
		disaster.play(params)
		var scaled := Vector4(
			params.intensity, params.intensity, params.particle_scale, params.particle_scale
		)
		for k: int in particles.size():
			var what := "%s: %s" % [disaster.id, particles[k].name]
			assert_true(particles[k].use_fixed_seed, "%s is seeded" % what)
			assert_eq(particles[k].seed, params.particle_seed, "%s's seed" % what)
			assert_almost_eq(_amounts(particles[k]), before[k] * scaled, Vector4.ONE * 1e-3, what)


## The speeds and sizes of `particles`.
static func _amounts(particles: CPUParticles2D) -> Vector4:
	return Vector4(
		particles.initial_velocity_min,
		particles.initial_velocity_max,
		particles.scale_amount_min,
		particles.scale_amount_max
	)


func test_an_outline_is_a_circle_of_its_radius_on_the_ground() -> void:
	# The sinkhole, the flood and the quicksand draw their ground with it.
	for radius: float in [Tuning.SINKHOLE_RADIUS, Tuning.FLOOD_RADIUS]:
		var points := DisasterBase.outline(radius)
		assert_eq(points.size(), DisasterBase.OUTLINE_POINTS)
		for point: Vector2 in points:
			var distance := Iso.world_to_tile(point).length()
			assert_almost_eq(distance, radius, 1e-4, "%.1f tiles from its centre" % radius)


func test_none_redraws_a_polygon() -> void:
	# Every redraw of a Polygon2D after its first raises WebGL errors on the Web (M2_PLAN.md §5.7).
	for scene: PackedScene in Disasters.scenes():
		var car := Disasters.car(self)
		var disaster := Disasters.disaster(self, scene, car, null)
		await wait_physics_frames(2)
		var draws: Array[int] = [0]
		for polygon: Polygon2D in Disasters.polygons(disaster):
			polygon.draw.connect(_count.bind(draws))
		disaster.play(Disasters.params())
		simulate(disaster, MAX_FRAMES, DELTA)
		await wait_physics_frames(2)
		assert_eq(draws[0], 0, "%s: no redraws" % disaster.id)


func _count(draws: Array[int]) -> void:
	draws[0] += 1


func test_with_the_stop_each_takes_2_to_4_seconds() -> void:
	# The director starts it once the car has stopped, which takes up to STOP_SECONDS (M3_PLAN.md
	# J4). The stop and the disaster's clock each add up steps of DELTA, and each sum can fall just
	# short of its time and take a frame more (M3_PLAN.md P10).
	var middle := (Tuning.DISASTER_INTENSITY_MIN + Tuning.DISASTER_INTENSITY_MAX) * 0.5
	for scene: PackedScene in Disasters.scenes():
		var disaster := Disasters.disaster(self, scene, null, null)
		var durations: Array[float] = []
		for delay: float in [Tuning.DISASTER_DELAY_MIN, Tuning.DISASTER_DELAY_MAX]:
			for intensity: float in [
				Tuning.DISASTER_INTENSITY_MIN, middle, Tuning.DISASTER_INTENSITY_MAX
			]:
				var params := DisasterParams.new()
				params.delay = delay
				params.intensity = intensity
				durations.append(Disasters.duration(disaster, params))
		assert_gte(durations.min(), 2.0, "%s: the quickest" % disaster.id)
		assert_lte(
			durations.max() + Tuning.STOP_SECONDS + 2 * DELTA, 4.0, "%s: the slowest" % disaster.id
		)


func test_after_a_wrong_turn_the_director_plays_each_in_2_to_4_seconds() -> void:
	# IMPLEMENTATION_PLAN.md M3.1, from the end of the run: the car stops, within STOP_SECONDS
	# (M3_PLAN.md J4), and the disaster plays, with the delay of its params.
	for scene: PackedScene in Disasters.scenes():
		var times: Array[float] = []
		for run_seed: int in 10:
			for speed: float in [2.0, Tuning.GLOBAL_SPEED_CAP]:
				times.append(Disasters.director_seconds(self, scene, run_seed, speed))
		var what := scene.resource_path.get_file()
		assert_between(times.min(), 2.0, 4.0, "%s: the quickest" % what)
		assert_between(times.max(), 2.0, 4.0, "%s: the slowest" % what)


func test_each_has_a_fate_for_game_over_and_a_lore_for_its_card() -> void:
	# M6_PLAN.md S8 and S12: short enough for game over's and a card's lines at 360 x 640 (P13).
	const MAX_FATE := 40
	const MAX_LORE := 80
	for scene: PackedScene in Disasters.scenes():
		var disaster := Disasters.disaster(self, scene, null, null)
		assert_between(disaster.fate.length(), 1, MAX_FATE, "%s's fate" % disaster.id)
		assert_between(disaster.lore.length(), 1, MAX_LORE, "%s's lore" % disaster.id)
