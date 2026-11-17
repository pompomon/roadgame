extends GutTest
## CameraRig (IMPLEMENTATION_PLAN.md M2.5, M3.2): the zoom steps, where the camera heads, and its
## shake, in a SubViewport of the size under test.

const Fixtures := preload("res://tests/helpers/road_fixtures.gd")
const CAR_SCENE := preload("res://car/car.tscn")
## The reference screens' viewports, after the stretch (docs/M2.md §6.5).
const SCREENS: Array[Vector2i] = [
	Vector2i(360, 640),
	Vector2i(360, 922),
	Vector2i(1639, 640),
	Vector2i(532, 640),
	Vector2i(768, 640),
	Vector2i(360, 800),
	Vector2i(1137, 640),
]
## How near the view something may come or go: a screen row, as in test_props_in_view.gd.
const MARGIN := Iso.TILE_H / 2.0
## Where the game's welcome stands as the car stops, from the centre of the car's body, as seed
## 12345 has it: its bounds, the grid with the stills that stand out of it, up and to the left on a
## pier heading W, and up and to the right on one heading N.
const WELCOMES: Array[Rect2] = [
	Rect2(-321.3, -290.3, 216.0, 338.0),
	Rect2(105.3, -290.3, 216.0, 338.0),
]


func _view(size: Vector2i) -> SubViewport:
	var view := SubViewport.new()
	view.size = size
	add_child_autofree(view)
	return view


## A car at the start of the road for seed 1. Nothing steps it.
func _car(view: SubViewport) -> CarController:
	var buffer := RoadBuffer.new(RoadGenerator.new(1, Fixtures.schedule()))
	buffer.start()
	var car: CarController = CAR_SCENE.instantiate()
	car.sim = CarSim.new(buffer)
	view.add_child(car)
	return car


func _rig(view: SubViewport) -> CameraRig:
	var rig := CameraRig.new()
	rig.car = _car(view)
	view.add_child(rig)
	return rig


static func _ahead(rig: CameraRig) -> Vector2:
	return Iso.tile_to_world(rig.car.sim.forward()).normalized() * Tuning.LOOKAHEAD_PX


func test_the_zoom_step_shows_about_five_tiles_across_the_shorter_side() -> void:
	assert_eq(CameraRig.zoom_for(Vector2(360, 640)), 1.0, "the base portrait size")
	assert_eq(CameraRig.zoom_for(Vector2(640, 360)), 1.0, "landscape")
	assert_eq(CameraRig.zoom_for(Vector2(1920, 1080)), 2.0, "full HD")
	assert_eq(CameraRig.zoom_for(Vector2(200, 200)), 0.5, "tiny")
	assert_eq(CameraRig.zoom_for(Vector2(500, 500)), 1.0, "1.4 is nearer to 1 than to 2 by ratio")


func test_the_zoom_follows_the_viewport_size() -> void:
	var view := _view(Vector2i(360, 640))
	var rig := _rig(view)
	assert_eq(rig.zoom, Vector2.ONE)
	view.size = Vector2i(1920, 1080)
	assert_eq(rig.zoom, Vector2(2.0, 2.0))
	view.size = Vector2i(200, 300)
	assert_eq(rig.zoom, Vector2(0.5, 0.5))


func test_it_looks_ahead_and_in_portrait_keeps_the_car_low() -> void:
	var view := _view(Vector2i(360, 640))
	var rig := _rig(view)
	var car := rig.car.position
	var bias := Vector2(0.0, -Tuning.PORTRAIT_BIAS * 640.0)
	assert_almost_eq(rig.target(), car + _ahead(rig) + bias, Vector2(0.01, 0.01), "portrait")
	view.size = Vector2i(1080, 1920)
	assert_almost_eq(
		rig.target(), car + _ahead(rig) + bias * 3.0 / 2.0, Vector2(0.01, 0.01), "zoom 2"
	)
	view.size = Vector2i(640, 360)
	assert_almost_eq(rig.target(), car + _ahead(rig), Vector2(0.01, 0.01), "landscape")


func test_it_catches_up_with_its_target_smoothly() -> void:
	var rig := _rig(_view(Vector2i(360, 640)))
	rig.snap_to_target()
	assert_eq(rig.position, rig.target(), "snapped")
	rig.position += Vector2(300.0, 0.0)
	simulate(rig, 1, 1.0 / 60.0)
	var gap := rig.position.distance_to(rig.target())
	assert_almost_eq(gap, 300.0 * exp(-Tuning.CAMERA_SMOOTHING / 60.0), 0.01, "one frame")
	simulate(rig, 59, 1.0 / 60.0)
	assert_lt(rig.position.distance_to(rig.target()), 1.0, "after a second")


## The offsets of `rig` over `frames` frames.
func _offsets(rig: CameraRig, frames: int) -> Array[Vector2]:
	var offsets: Array[Vector2] = []
	for _i: int in frames:
		simulate(rig, 1, 1.0 / 60.0)
		offsets.append(rig.offset)
	return offsets


func test_a_shake_moves_the_view_and_fades_out() -> void:
	var rig := _rig(_view(Vector2i(360, 640)))
	rig.snap_to_target()
	rig.shake(1.0, 0.5)
	# 30 frames, and 2 more in case they add up to a hair under 0.5 s.
	var offsets := _offsets(rig, 32)
	var biggest := 0.0
	var moved := 0
	for offset: Vector2 in offsets:
		biggest = maxf(biggest, offset.length())
		if offset != Vector2.ZERO:
			moved += 1
	assert_gt(moved, 25, "shakes")
	assert_lte(biggest, Tuning.SHAKE_PX * sqrt(2.0), "by up to SHAKE_PX on each axis")
	var early := 0.0
	var late := 0.0
	for i: int in 8:
		early = maxf(early, offsets[i].length())
		late = maxf(late, offsets[22 + i].length())
	assert_lt(late, early / 2.0, "fades out")
	assert_eq(offsets.back(), Vector2.ZERO, "over after 0.5 s")
	assert_eq(_offsets(rig, 30).count(Vector2.ZERO), 30, "and stays over")
	assert_eq(rig.position, rig.target(), "the position follows the car alone")


func test_a_shake_is_the_same_every_time() -> void:
	var view := _view(Vector2i(360, 640))
	var rigs: Array[CameraRig] = [_rig(view), _rig(view)]
	for rig: CameraRig in rigs:
		rig.shake(0.7, 1.0)
	assert_eq(_offsets(rigs[0], 50), _offsets(rigs[1], 50))


func test_stop_shake_ends_it_and_a_new_shake_replaces_the_last() -> void:
	var rig := _rig(_view(Vector2i(360, 640)))
	rig.shake(1.0, 2.0)
	_offsets(rig, 10)
	rig.stop_shake()
	assert_eq(rig.offset, Vector2.ZERO, "stopped")
	assert_eq(_offsets(rig, 10).count(Vector2.ZERO), 10, "and stays stopped")
	rig.shake(1.0, 2.0)
	_offsets(rig, 10)
	rig.shake(0.5, 0.2)
	assert_eq(rig.offset, Vector2(0.0, 0.5 * Tuning.SHAKE_PX), "the new one starts")
	var offsets := _offsets(rig, 13)
	assert_eq(offsets.back(), Vector2.ZERO, "and ends after 0.2 s")


func test_the_shake_is_in_screen_pixels() -> void:
	var view := _view(Vector2i(1920, 1080))
	var rig := _rig(view)
	assert_eq(rig.zoom, Vector2(2.0, 2.0))
	rig.shake(1.0, 1.0)
	assert_eq(rig.offset, Vector2(0.0, Tuning.SHAKE_PX / 2.0), "half the world pixels at zoom 2")


## A dead end's end is out of view as the car enters its junction (docs/ROADGEN.md R4): on every
## reference screen, the round end of a dead end DEAD_END_MIN_TILES long is off the view as the car
## enters the junction's tile, with the camera on its target, as far ahead as it gets. The correct
## path heads N or W, and a dead end goes straight on or the other way to the turn.
func test_a_dead_end_ends_out_of_view_as_the_car_enters_its_junction() -> void:
	var dead_ends: Dictionary[int, Array] = {
		Heading.N: [Heading.N, Heading.E],
		Heading.W: [Heading.W, Heading.S],
	}
	var centre := Vector2(0.5, 0.5)
	var end_size := Vector2(Iso.TILE_W, Iso.TILE_H) * Tuning.ROAD_HALF_WIDTH * sqrt(2.0)
	for size: Vector2i in SCREENS:
		var rig := _rig(_view(size))
		var shown := Vector2(size) / rig.zoom
		for heading: int in dead_ends:
			rig.car.sim.angle = heading * PI / 2.0
			rig.car.position = Iso.tile_to_world(centre - Vector2(Heading.VEC[heading]) / 2.0)
			rig.snap_to_target()
			var view := Rect2(rig.position - shown / 2.0, shown)
			var at := "%s, heading %s" % [size, Heading.NAMES[heading]]
			for exit: int in dead_ends[heading]:
				var tip := centre + Vector2(Heading.VEC[exit]) * Tuning.DEAD_END_MIN_TILES
				var cap := Rect2(Iso.tile_to_world(tip) - end_size / 2.0, end_size)
				assert_false(view.intersects(cap), "%s, dead end %s" % [at, Heading.NAMES[exit]])


## A dead end freed with its junction is out of view (docs/ROADGEN.md R6, docs/M5.md L2). The
## buffer frees a junction and its dead ends as the car enters the path tile BUFFER_BEHIND + 1 past
## it. Each path tile is a row above the last, so the end of a straight-on dead end
## DEAD_END_MAX_TILES long is BUFFER_BEHIND + 1 - DEAD_END_MAX_TILES rows below the car's tile,
## whichever way the path ran. Where the path ran the dead end's way, that end is under the view,
## the worst case, which a drive meets only now and then: so only heights count. On every reference
## screen, with the car entering its tile on the centreline at GLOBAL_SPEED_CAP and the camera
## trailing it as far as it does at that speed, the end stays MARGIN below the view.
func test_a_dead_end_freed_with_its_junction_stays_below_the_view_at_top_speed() -> void:
	var delta := 1.0 / 60.0
	var frames := 180
	var rows := Tuning.BUFFER_BEHIND + 1 - Tuning.DEAD_END_MAX_TILES
	var end_top := rows * Iso.TILE_H / 2.0
	for size: Vector2i in SCREENS:
		var rig := _rig(_view(size))
		var shown := Vector2(size) / rig.zoom
		for heading: int in [Heading.N, Heading.W]:
			var step := Vector2(Heading.VEC[heading])
			var velocity := Iso.tile_to_world(step) * Tuning.GLOBAL_SPEED_CAP
			rig.car.sim.angle = heading * PI / 2.0
			rig.car.position = Iso.tile_to_world(Vector2(0.5, 0.5) - step / 2.0)
			rig.car.position -= velocity * delta * frames
			rig.snap_to_target()
			for _i: int in frames:
				rig.car.position += velocity * delta
				simulate(rig, 1, delta)
			var view := Rect2(rig.position - shown / 2.0, shown)
			var gap := end_top - view.end.y
			assert_gte(gap, MARGIN, "%s, heading %s: %.1f px" % [size, Heading.NAMES[heading], gap])


## What `rig` shows, in World pixels.
static func _shown(rig: CameraRig) -> Rect2:
	var size := rig.get_viewport_rect().size / rig.zoom
	return Rect2(rig.position - size / 2.0, size)


## The distances of `points` from the first.
static func _distances(points: Array[Vector2]) -> Array[float]:
	var path: Array[float] = []
	for point: Vector2 in points:
		path.append(points[0].distance_to(point))
	return path


## Checks that `path`, how far something has gone on each frame of a pan, eases as a smoothstep
## over 1 / ARRIVAL_PAN_RATE seconds does: in slowly, never faster than its steepest, never back,
## and to a rest.
func _assert_eases(path: Array[float], what: String) -> void:
	var linear := path[-1] * Tuning.ARRIVAL_PAN_RATE / 60.0
	var steepest := 0.0
	var back := 0
	for i: int in range(1, path.size()):
		steepest = maxf(steepest, path[i] - path[i - 1])
		back += int(path[i] < path[i - 1] - 1e-4)
	assert_lte(path[1], linear / 2.0, what + ": eases in")
	assert_lte(steepest, 1.5 * linear + 1e-3, what + ": no faster than a smoothstep")
	assert_eq(back, 0, what + ": frames back")
	assert_eq(path[-2], path[-1], what + ": and comes to rest")


## Runs an arrival on a viewport of `size`, with the car still, to `rect` placed from the centre of
## the car's body, and checks the pan: the target and the view's size ease together from the car to
## the arrival's view, with no jump as they start, the target along a line. The car's body, with
## ARRIVAL_MARGIN_PX round it, stays in view on every frame, and in the end the rect is in view
## too. end_arrival() brings the camera back to the car, at the zoom for following it. Returns the
## arrival's zoom.
func _assert_arrival(size: Vector2i, rect: Rect2) -> float:
	var delta := 1.0 / 60.0
	var pan := ceili(1.0 / (Tuning.ARRIVAL_PAN_RATE * delta))
	var rig := _rig(_view(size))
	var follow := rig.zoom
	rig.snap_to_target()
	var on_car := rig.target()
	var framed := rig.car.body_rect().grow(Tuning.ARRIVAL_MARGIN_PX)
	var welcome := Rect2(framed.get_center() + rect.position, rect.size)
	var at := "%s, %s" % [size, rect]
	rig.arrive(welcome)
	assert_eq(rig.target(), on_car, at + ": no jump as it starts")
	assert_eq(rig.zoom, follow, at + ": nor a zoom")
	var targets: Array[Vector2] = [on_car]
	var widths: Array[float] = [0.0]
	var hidden := 0
	# The pan, a frame more for a sum of 1/60 s that falls short and one at rest, then the camera
	# catching up.
	for frame: int in pan * 3:
		simulate(rig, 1, delta)
		if frame < pan + 2:
			targets.append(rig.target())
			widths.append(_shown(rig).size.x - size.x / follow.x)
		hidden += int(not _shown(rig).grow(0.5).encloses(framed))
	var line := (targets[-1] - on_car).normalized()
	var off_line := 0.0
	for target: Vector2 in targets:
		off_line = maxf(off_line, absf((target - on_car).cross(line)))
	assert_gt(on_car.distance_to(targets[-1]), 50.0, at + ": it pans")
	assert_lt(off_line, 0.01, at + ": along a line")
	_assert_eases(_distances(targets), at + ": the target")
	_assert_eases(widths, at + ": the view's width")
	assert_eq(hidden, 0, at + ": frames without the car's body, and its margin, in view")
	assert_true(_shown(rig).grow(0.5).encloses(welcome), at + ": and in the end, the rect")
	var zoom := rig.zoom.x
	rig.end_arrival()
	assert_eq(rig.target(), on_car, at + ": back on the car")
	assert_eq(rig.zoom, follow, at + ": at the zoom for following it")
	return zoom


## The arrival's view (ENDGAME_PLAN.md §5.8), on every reference screen, as _assert_arrival()
## checks it. It zooms out only where the view can't hold the rect and the car's body at the zoom
## for following the car: on the Fold4's inner screen in portrait, 266 px across at zoom 2, by a
## step.
func test_an_arrival_eases_the_view_to_show_the_welcome_and_the_car() -> void:
	for size: Vector2i in SCREENS:
		var follow := CameraRig.zoom_for(Vector2(size))
		var step := follow / 2.0 if size == Vector2i(532, 640) else follow
		var zoom := _assert_arrival(size, Rect2(-260.0, -260.0, 200.0, 200.0))
		assert_eq(zoom, step, "%s: the arrival's zoom" % size)


## The game's welcome shows at zoom 1 with the car on every reference screen: where the view is
## 320 px high at zoom 2, too small for them, the arrival zooms out a step.
func test_the_welcome_shows_at_zoom_1_on_every_screen() -> void:
	for size: Vector2i in SCREENS:
		for welcome: Rect2 in WELCOMES:
			assert_eq(_assert_arrival(size, welcome), 1.0, "%s, %s" % [size, welcome])


func test_an_arrivals_zoom_is_the_largest_step_whose_view_holds_it_but_never_in() -> void:
	var welcome := Vector2(284.0, 398.0)
	assert_eq(CameraRig.arrival_zoom_for(Vector2(360, 640), welcome), 1.0, "the base view")
	assert_eq(CameraRig.arrival_zoom_for(Vector2(1137, 640), welcome), 1.0, "a step out from 2")
	assert_eq(CameraRig.arrival_zoom_for(Vector2(1920, 1080), welcome), 2.0, "full HD keeps 2")
	assert_eq(CameraRig.arrival_zoom_for(Vector2(360, 640), Vector2(10, 10)), 1.0, "never in")
	var wide := Vector2(800.0, 100.0)
	assert_eq(CameraRig.arrival_zoom_for(Vector2(360, 640), wide), 0.5, "else the smallest step")


## A resize during an arrival, as a fold's or a window's, gives the zoom the new screen's steps at
## once: the arrival's, and after end_arrival(), the one for following the car.
func test_a_resize_during_an_arrival_takes_the_new_screens_steps() -> void:
	var view := _view(Vector2i(1137, 640))
	var rig := _rig(view)
	rig.snap_to_target()
	var welcome := WELCOMES[0]
	rig.arrive(Rect2(rig.car.body_rect().get_center() + welcome.position, welcome.size))
	simulate(rig, 120, 1.0 / 60.0)
	assert_eq(rig.zoom, Vector2.ONE, "a step out from 2")
	view.size = Vector2i(1920, 1080)
	assert_eq(rig.zoom, Vector2(2.0, 2.0), "full HD holds the welcome at 2")
	view.size = Vector2i(1137, 640)
	assert_eq(rig.zoom, Vector2.ONE, "and back, out again")
	rig.end_arrival()
	assert_eq(rig.zoom, Vector2(2.0, 2.0), "and back to following the car")


## A car that came slowly stops short on the pier, too far from the welcome to show both: the view
## goes toward the welcome as far as it can with the car's body, and its margin, still in view.
func test_an_arrival_too_far_to_show_keeps_the_car_in_view() -> void:
	var delta := 1.0 / 60.0
	for size: Vector2i in SCREENS:
		var rig := _rig(_view(size))
		rig.snap_to_target()
		var body := rig.car.body_rect()
		rig.arrive(Rect2(body.get_center() - Vector2(2000.0, 1500.0), Vector2(200.0, 200.0)))
		simulate(rig, ceili(3.0 / (Tuning.ARRIVAL_PAN_RATE * delta)), delta)
		var view := _shown(rig)
		var framed := body.grow(Tuning.ARRIVAL_MARGIN_PX)
		assert_true(view.grow(0.5).encloses(framed), "%s: the car's body in view" % size)
		assert_almost_eq(view.end, framed.end, Vector2.ONE, "%s: at the view's corner" % size)
