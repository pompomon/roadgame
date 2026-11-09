extends GutTest
## The flood (plan.md §4.3, IMPLEMENTATION_PLAN.md M4.5): after its delay the water rolls in along
## its params' direction and spreads around the stopped car; then it rises over the car, faster in
## a stronger flood, with spray, and the car goes under. tests/unit/test_disasters.gd checks what
## every disaster does.

const Disasters := preload("res://tests/helpers/disaster_fixtures.gd")
const FLOOD := preload("res://disasters/flood.tscn")
const DELTA := Disasters.DELTA
const MAX_FRAMES := Disasters.MAX_FRAMES


func _flood(car: CarController) -> Flood:
	return Disasters.disaster(self, FLOOD, car, null) as Flood


func test_the_water_rolls_in_along_its_direction_and_spreads_around_the_car() -> void:
	var car := Disasters.car(self)
	var flood := _flood(car)
	var water: Polygon2D = flood.get_node("%Water")
	var params := Disasters.params()
	flood.play(params)
	var from := Iso.tile_to_world(-params.direction * Tuning.FLOOD_RADIUS)
	var phases: Array[Flood.Phase] = [flood.phase]
	var distances: Array[float] = []
	var sizes: Array[float] = []
	var frames := 0
	while flood.phase != Flood.Phase.DONE and frames < MAX_FRAMES:
		simulate(flood, 1, DELTA)
		frames += 1
		if flood.phase != phases.back():
			phases.append(flood.phase)
		if flood.phase == Flood.Phase.SPREAD:
			distances.append(water.position.distance_to(from))
			sizes.append(water.scale.x)
			assert_eq(car.modulate, Color.WHITE, "the car waits for the water")
	var order: Array[Flood.Phase] = [
		Flood.Phase.DELAY, Flood.Phase.SPREAD, Flood.Phase.RISE, Flood.Phase.HOLD, Flood.Phase.DONE
	]
	assert_eq(phases, order, "every phase, in order")
	assert_gt(sizes.size(), 20, "it spreads for a while")
	assert_lt(distances[0], 1.0, "from behind its direction")
	assert_lt(sizes[0], 0.05, "from nothing")
	assert_eq(distances, Disasters.sorted(distances), "it only comes on")
	assert_eq(sizes, Disasters.sorted(sizes), "and only grows")
	assert_eq(water.position, Vector2.ZERO, "around the car")
	assert_eq(water.scale, Vector2.ONE, "all of it")


func test_then_it_rises_over_the_car() -> void:
	var car := Disasters.car(self)
	var flood := _flood(car)
	var surface: Polygon2D = flood.get_node("%Surface")
	flood.play(Disasters.params())
	var sizes: Array[float] = []
	var alphas: Array[float] = []
	var frames := 0
	while flood.phase != Flood.Phase.DONE and frames < MAX_FRAMES:
		simulate(flood, 1, DELTA)
		frames += 1
		if flood.phase == Flood.Phase.DELAY or flood.phase == Flood.Phase.SPREAD:
			assert_false(Disasters.shows(surface), "no surface yet")
		elif flood.phase == Flood.Phase.RISE:
			sizes.append(surface.scale.x)
			alphas.append(car.modulate.a)
	assert_gt(sizes.size(), 20, "it rises for a while")
	assert_eq(sizes, Disasters.sorted(sizes), "the surface only grows")
	assert_eq(alphas, Disasters.sorted(alphas, true), "and the car only fades")
	assert_between(Disasters.middle(alphas), 0.25, 0.75, "halfway, half under")
	assert_eq(surface.scale, Vector2.ONE, "over the car")
	assert_true(car.modulate.is_equal_approx(Flood.UNDERWATER), "which is under the water")


func test_a_stronger_flood_rises_faster() -> void:
	# Its rise lasts rise_seconds(), and the surface and the car follow it: half risen halfway.
	var frames: Array[int] = []
	for intensity: float in [Tuning.DISASTER_INTENSITY_MIN, Tuning.DISASTER_INTENSITY_MAX]:
		var car := Disasters.car(self)
		var flood := _flood(car)
		var surface: Polygon2D = flood.get_node("%Surface")
		var params := Disasters.params(intensity)
		flood.play(params)
		var rise := Flood.rise_seconds(params)
		var rising := 0
		var half := 0
		var steps := 0
		while flood.phase != Flood.Phase.DONE and steps < MAX_FRAMES:
			simulate(flood, 1, DELTA)
			steps += 1
			if flood.phase == Flood.Phase.RISE:
				rising += 1
				if half == 0 and surface.scale.x >= 0.5:
					half = rising
					var tint := Color.WHITE.lerp(Flood.UNDERWATER, surface.scale.x)
					assert_true(car.modulate.is_equal_approx(tint), "the car goes under with it")
		assert_almost_eq(rising * DELTA, rise, DELTA * 1.01, "its rise")
		assert_almost_eq(half * DELTA, rise / 2.0, DELTA * 2.0, "half risen halfway")
		frames.append(rising)
	assert_lt(frames[1], frames[0], "faster")


func test_the_spray_flies_while_it_rises() -> void:
	var flood := _flood(null)
	var spray: CPUParticles2D = flood.get_node("%Spray")
	flood.play(Disasters.params())
	var flying := {}
	var frames := 0
	while flood.phase != Flood.Phase.DONE and frames < MAX_FRAMES:
		simulate(flood, 1, DELTA)
		frames += 1
		flying[flood.phase] = flying.get(flood.phase, false) or spray.emitting
	assert_eq(
		flying,
		{
			Flood.Phase.DELAY: false,
			Flood.Phase.SPREAD: false,
			Flood.Phase.RISE: true,
			Flood.Phase.HOLD: false,
			Flood.Phase.DONE: false,
		}
	)


func test_the_water_lies_under_the_car_and_its_surface_over_it() -> void:
	# World's DisasterLayer comes before Props, which holds the car at z_index 0 (M3_PLAN.md J5).
	var car := Disasters.car(self)
	var flood := _flood(car)
	assert_eq(Disasters.z(flood.get_node("%Water")), Disasters.z(car), "under the car")
	assert_gt(Disasters.z(flood.get_node("%Surface")), Disasters.z(car), "over it")
	assert_gt(Disasters.z(flood.get_node("%Spray")), Disasters.z(car), "and the spray")
