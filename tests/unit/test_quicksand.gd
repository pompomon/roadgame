extends GutTest
## The quicksand (plan.md §4.3, IMPLEMENTATION_PLAN.md M4.5): after its delay a pit spreads under
## the stopped car, as big as the quicksand is strong, with ripples; then the car sinks, faster in
## stronger quicksand, rocking less and less, and sand flies. tests/unit/test_disasters.gd checks
## what every disaster does.

const Disasters := preload("res://tests/helpers/disaster_fixtures.gd")
const QUICKSAND := preload("res://disasters/quicksand.tscn")
const DELTA := Disasters.DELTA
const MAX_FRAMES := Disasters.MAX_FRAMES


func _quicksand(car: CarController) -> Quicksand:
	return Disasters.disaster(self, QUICKSAND, car, null) as Quicksand


func test_the_pit_spreads_under_the_car_as_big_as_the_quicksand_is_strong() -> void:
	for intensity: float in [Tuning.DISASTER_INTENSITY_MIN, Tuning.DISASTER_INTENSITY_MAX]:
		var car := Disasters.car(self)
		var quicksand := _quicksand(car)
		var pit: Polygon2D = quicksand.get_node("%Pit")
		quicksand.play(Disasters.params(intensity))
		var phases: Array[Quicksand.Phase] = [quicksand.phase]
		var sizes: Array[float] = []
		var frames := 0
		while quicksand.phase != Quicksand.Phase.DONE and frames < MAX_FRAMES:
			simulate(quicksand, 1, DELTA)
			frames += 1
			if quicksand.phase != phases.back():
				phases.append(quicksand.phase)
			if quicksand.phase == Quicksand.Phase.SPREAD:
				sizes.append(pit.scale.x)
				assert_eq(car.scale, Vector2.ONE, "the car waits for the pit")
		var order: Array[Quicksand.Phase] = [
			Quicksand.Phase.DELAY,
			Quicksand.Phase.SPREAD,
			Quicksand.Phase.SINK,
			Quicksand.Phase.HOLD,
			Quicksand.Phase.DONE,
		]
		assert_eq(phases, order, "every phase, in order")
		assert_gt(sizes.size(), 20, "it spreads for a while")
		assert_lt(sizes[0], 0.05, "from nothing")
		assert_eq(sizes, Disasters.sorted(sizes), "and only grows")
		assert_almost_eq(pit.scale, Vector2.ONE * intensity, Vector2.ONE * 1e-6, "by its intensity")


func test_ripples_grow_and_fade_within_the_pit() -> void:
	var quicksand := _quicksand(null)
	var pit: Polygon2D = quicksand.get_node("%Pit")
	var ripple: Polygon2D = quicksand.get_node("%Ripple")
	quicksand.play(Disasters.params())
	var restarts := 0
	var last := 0.0
	var frames := 0
	while quicksand.phase != Quicksand.Phase.DONE and frames < MAX_FRAMES:
		simulate(quicksand, 1, DELTA)
		frames += 1
		if quicksand.phase == Quicksand.Phase.DELAY:
			assert_false(Disasters.shows(ripple), "no ripple yet")
			continue
		# Node2D keeps a scale near zero at CMP_EPSILON (scene/2d/node_2d.cpp, set_scale).
		if pit.scale.x < 0.05:
			continue
		var share := ripple.scale.x / pit.scale.x
		assert_between(share, 0.0, 1.0, "within the pit")
		assert_almost_eq(ripple.modulate.a, 1.0 - share, 1e-4, "fading as it grows")
		if share < last:
			restarts += 1
		last = share
	assert_gte(restarts, 2, "one after another")


func test_the_car_rocks_less_and_less_as_it_sinks() -> void:
	var car := Disasters.car(self)
	var quicksand := _quicksand(car)
	var params := Disasters.params()
	quicksand.play(params)
	var sink := Quicksand.sink_seconds(params)
	var scales: Array[float] = []
	var alphas: Array[float] = []
	var sides := 0
	var side := 0.0
	var frames := 0
	var sinking := 0
	while quicksand.phase != Quicksand.Phase.DONE and frames < MAX_FRAMES:
		simulate(quicksand, 1, DELTA)
		frames += 1
		if quicksand.phase != Quicksand.Phase.SINK:
			continue
		sinking += 1
		var sunk := clampf(sinking * DELTA / sink, 0.0, 1.0)
		var limit := Tuning.QUICKSAND_WOBBLE * (1.0 - sunk) + 0.02
		assert_lte(absf(car.rotation), limit, "less and less")
		if signf(car.rotation) != 0.0 and signf(car.rotation) != side:
			sides += 1
			side = signf(car.rotation)
		scales.append(car.scale.x)
		alphas.append(car.modulate.a)
	assert_gte(sides, 3, "from side to side")
	assert_eq(scales, Disasters.sorted(scales, true), "the car only shrinks")
	assert_eq(alphas, Disasters.sorted(alphas, true), "and only fades")
	assert_almost_eq(car.rotation, 0.0, 1e-6, "level once it has sunk")
	assert_almost_eq(car.scale, Vector2.ONE * Quicksand.SUNK_SCALE, Vector2.ONE * 1e-6, "sunk")


func test_stronger_quicksand_sinks_the_car_faster() -> void:
	var frames: Array[int] = []
	for intensity: float in [Tuning.DISASTER_INTENSITY_MIN, Tuning.DISASTER_INTENSITY_MAX]:
		var quicksand := _quicksand(null)
		var params := Disasters.params(intensity)
		quicksand.play(params)
		var sinking := 0
		var steps := 0
		while quicksand.phase != Quicksand.Phase.DONE and steps < MAX_FRAMES:
			simulate(quicksand, 1, DELTA)
			steps += 1
			if quicksand.phase == Quicksand.Phase.SINK:
				sinking += 1
		assert_almost_eq(sinking * DELTA, Quicksand.sink_seconds(params), DELTA * 1.01, "its sink")
		frames.append(sinking)
	assert_lt(frames[1], frames[0], "faster")


func test_the_sand_flies_while_the_car_sinks() -> void:
	var quicksand := _quicksand(null)
	var grains: CPUParticles2D = quicksand.get_node("%Grains")
	quicksand.play(Disasters.params())
	var flying := {}
	var frames := 0
	while quicksand.phase != Quicksand.Phase.DONE and frames < MAX_FRAMES:
		simulate(quicksand, 1, DELTA)
		frames += 1
		flying[quicksand.phase] = flying.get(quicksand.phase, false) or grains.emitting
	assert_eq(
		flying,
		{
			Quicksand.Phase.DELAY: false,
			Quicksand.Phase.SPREAD: false,
			Quicksand.Phase.SINK: true,
			Quicksand.Phase.HOLD: false,
			Quicksand.Phase.DONE: false,
		}
	)
