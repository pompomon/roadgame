extends GutTest
## CameraRig (IMPLEMENTATION_PLAN.md M2.5): the zoom steps and where the camera heads, in a
## SubViewport of the size under test.

const Fixtures := preload("res://tests/helpers/road_fixtures.gd")
const CAR_SCENE := preload("res://car/car.tscn")


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
