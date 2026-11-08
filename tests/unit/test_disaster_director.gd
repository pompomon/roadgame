extends GutTest
## DisasterDirector (plan.md §4.2, IMPLEMENTATION_PLAN.md M3.1, M3.3): after a wrong or missed turn
## it waits for the car to stop and plays a disaster from the area's pool, drawn with the run's
## disaster stream; after a crash it shakes the camera for CRASH_SECONDS. Every sequence ends once
## and in time, even one that is stuck.

const Fixtures := preload("res://tests/helpers/road_fixtures.gd")
const StuckDisaster := preload("res://tests/helpers/stuck_disaster.gd")
const CAR_SCENE := preload("res://car/car.tscn")
const SINKHOLE := preload("res://disasters/sinkhole.tscn")
const DELTA := 1.0 / 60.0

## In the main scene's order, which is the order of their physics steps: the disaster layer, the
## car, the camera and the director.
var _root: Node
var _layer: Node2D
var _car: CarController
var _camera: CameraRig
var _director: DisasterDirector


func before_each() -> void:
	_root = Node.new()
	add_child_autofree(_root)
	_layer = Node2D.new()
	_root.add_child(_layer)
	_car = null
	_new_car()
	_camera = CameraRig.new()
	_root.add_child(_camera)
	_director = DisasterDirector.new()
	_director.layer = _layer
	_root.add_child(_director)
	_director.start_run(1)


## A car whose run just ended in `state`, at `speed`, in place of the last one.
func _new_car(state := CarSim.State.DISASTER, speed := 0.0) -> void:
	if is_instance_valid(_car):
		_car.free()
	var buffer := RoadBuffer.new(RoadGenerator.new(1, Fixtures.schedule()))
	buffer.start()
	_car = CAR_SCENE.instantiate()
	_car.sim = CarSim.new(buffer)
	_car.sim.state = state
	_car.sim.speed = speed
	_car.input = InputRouter.new()
	_root.add_child(_car)
	_root.move_child(_car, 1)
	_car.add_child(_car.input)


static func _area(pool: Array[PackedScene]) -> AreaDef:
	var area := AreaDef.new()
	area.id = &"test"
	area.disasters = pool
	return area


## A scene whose root is a Node2D with `script`.
static func _scene(script: Script) -> PackedScene:
	var node := Node2D.new()
	node.set_script(script)
	var scene := PackedScene.new()
	scene.pack(node)
	node.free()
	return scene


## Steps everything until the sequence ends, for at most `frames` frames. Returns the frames run.
func _run(frames: int) -> int:
	for frame: int in frames:
		if _director.sequence == DisasterDirector.Sequence.FINISHED:
			return frame
		simulate(_root, 1, DELTA)
	return frames


func test_pick_draws_every_scene_of_the_pool_with_the_stream() -> void:
	assert_null(DisasterDirector.pick([] as Array[PackedScene], DisasterDirector.stream(1)))
	var pool: Array[PackedScene] = [PackedScene.new(), PackedScene.new(), PackedScene.new()]
	var picks: Array[int] = []
	var again: Array[int] = []
	var rng := DisasterDirector.stream(1)
	var same := DisasterDirector.stream(1)
	for _i: int in 60:
		picks.append(pool.find(DisasterDirector.pick(pool, rng)))
		again.append(pool.find(DisasterDirector.pick(pool, same)))
	for i: int in pool.size():
		assert_has(picks, i, "scene %d" % i)
	assert_does_not_have(picks, -1)
	assert_eq(picks, again, "the same stream picks the same scenes")


func test_a_disaster_waits_for_the_car_to_stop() -> void:
	_new_car(CarSim.State.DISASTER, 2.0)
	_director.play_disaster(_area([SINKHOLE]), _car, _camera)
	assert_eq(_director.sequence, DisasterDirector.Sequence.STOPPING)
	var early := false
	var frames := 0
	while _car.sim.speed > 0.0 and frames < 120:
		early = early or _director.disaster != null
		simulate(_root, 1, DELTA)
		frames += 1
	assert_false(early, "nothing before the car stops")
	assert_eq(_car.sim.speed, 0.0, "stopped")
	assert_eq(_director.sequence, DisasterDirector.Sequence.PLAYING, "from the frame it stops")
	assert_true(_director.disaster is Sinkhole, "a sinkhole")
	assert_eq(_director.disaster.get_parent(), _layer, "on the layer")
	assert_eq(_director.disaster.car, _car)
	assert_eq(_director.disaster.camera, _camera)
	assert_eq(_director.params.origin_world, _car.position, "where the car stopped")


func test_the_sinkhole_ends_the_sequence_2_to_4_seconds_after_the_turn() -> void:
	var times: Array[float] = []
	for run_seed: int in 10:
		for speed: float in [2.0, Tuning.GLOBAL_SPEED_CAP]:
			_director.start_run(run_seed)
			_new_car(CarSim.State.DISASTER, speed)
			clear_signal_watcher()
			watch_signals(_director)
			_director.play_disaster(_area([SINKHOLE]), _car, _camera)
			times.append(_run(600) * DELTA)
			assert_signal_emit_count(_director, "sequence_finished", 1)
	assert_between(times.min(), 2.0, 4.0, "the quickest")
	assert_between(times.max(), 2.0, 4.0, "the slowest")
	assert_gt(times.max() - times.min(), 0.2, "the delay and the stop vary")


func test_a_crash_shakes_the_camera_and_ends_after_crash_seconds() -> void:
	_new_car(CarSim.State.CRASHED, 5.0)
	watch_signals(_director)
	_director.play_crash(_car, _camera)
	assert_eq(_director.sequence, DisasterDirector.Sequence.CRASH)
	simulate(_root, 1, DELTA)
	assert_ne(_camera.offset, Vector2.ZERO, "the camera shakes")
	var frames := 1 + _run(600)
	assert_almost_eq(frames * DELTA, Tuning.CRASH_SECONDS, DELTA * 1.01)
	simulate(_root, 60, DELTA)
	assert_signal_emit_count(_director, "sequence_finished", 1)
	assert_eq(_layer.get_child_count(), 0, "no disaster")
	assert_eq(_car.sim.speed, 0.0, "the car stopped")


func test_a_car_that_never_stops_times_out_with_an_error() -> void:
	_new_car(CarSim.State.DISASTER, 2.0)
	watch_signals(_director)
	_director.play_disaster(_area([SINKHOLE]), _car, _camera)
	var frames := 0
	while _director.sequence != DisasterDirector.Sequence.FINISHED and frames < 600:
		simulate(_director, 1, DELTA)
		frames += 1
	assert_almost_eq(frames * DELTA, Tuning.DISASTER_TIMEOUT, DELTA * 1.01)
	assert_push_error("the sequence did not end")
	assert_signal_emit_count(_director, "sequence_finished", 1)


func test_a_disaster_that_never_finishes_times_out_with_an_error() -> void:
	watch_signals(_director)
	_director.play_disaster(_area([_scene(StuckDisaster)]), _car, _camera)
	var frames := _run(600)
	assert_almost_eq(frames * DELTA, Tuning.DISASTER_TIMEOUT, DELTA * 1.01)
	assert_push_error("the sequence did not end")
	simulate(_root, 60, DELTA)
	assert_signal_emit_count(_director, "sequence_finished", 1)


func test_an_empty_pool_is_an_error_and_ends_the_sequence() -> void:
	_director.play_disaster(_area([]), _car, _camera)
	simulate(_root, 1, DELTA)
	assert_push_error("the area's pool has no disaster")
	assert_eq(_director.sequence, DisasterDirector.Sequence.FINISHED)
	assert_eq(_layer.get_child_count(), 0)


func test_a_scene_that_is_not_a_disaster_is_an_error_and_is_freed() -> void:
	_director.play_disaster(_area([_scene(null)]), _car, _camera)
	simulate(_root, 1, DELTA)
	assert_push_error("the area's pool has no disaster")
	assert_eq(_director.sequence, DisasterDirector.Sequence.FINISHED)
	assert_eq(_layer.get_child_count(), 0)
	assert_no_new_orphans()


func test_clear_frees_the_disaster_at_once_and_forgets_the_sequence() -> void:
	watch_signals(_director)
	_director.play_disaster(_area([SINKHOLE]), _car, _camera)
	simulate(_root, 1, DELTA)
	var disaster := _director.disaster
	assert_not_null(disaster, "playing")
	_director.clear()
	assert_false(is_instance_valid(disaster), "freed, not queued")
	assert_eq(_layer.get_child_count(), 0)
	assert_eq(_director.sequence, DisasterDirector.Sequence.NONE)
	assert_null(_director.params)
	simulate(_root, 420, DELTA)
	assert_signal_not_emitted(_director, "sequence_finished")


func test_a_second_sequence_is_an_error() -> void:
	_director.play_crash(_car, _camera)
	_director.play_disaster(_area([SINKHOLE]), _car, _camera)
	assert_push_error("a sequence is already playing")
	assert_eq(_director.sequence, DisasterDirector.Sequence.CRASH)


func test_the_run_seed_decides_the_disaster() -> void:
	var rolls: Array[Array] = []
	for run_seed: int in [7, 7, 8]:
		_director.start_run(run_seed)
		_new_car()
		_director.play_disaster(_area([SINKHOLE]), _car, _camera)
		simulate(_root, 1, DELTA)
		var params := _director.params
		rolls.append([params.direction, params.intensity, params.delay, params.particle_seed])
	assert_eq(rolls[0], rolls[1], "the same seed")
	assert_ne(rolls[0], rolls[2], "another seed")


func test_every_area_of_the_game_has_a_pool_of_disasters() -> void:
	# Until M4.5 adds the others, every pool is the sinkhole (M3_PLAN.md Q2).
	var areas := 0
	for entry: AreaScheduleEntry in Fixtures.schedule().entries:
		var area := entry.area
		areas += 1
		assert_false(area.disasters.is_empty(), "%s has a pool" % area.id)
		for scene: PackedScene in area.disasters:
			var node := scene.instantiate()
			var disaster := node as DisasterBase
			assert_not_null(disaster, "%s: %s is a disaster" % [area.id, scene.resource_path])
			if disaster != null:
				assert_ne(disaster.id, &"", "%s: %s has an id" % [area.id, scene.resource_path])
			node.free()
	assert_eq(areas, 5, "the five areas")
	var city: AreaDef = load("res://areas/city.tres")
	assert_eq(city.disasters, [SINKHOLE] as Array[PackedScene], "the City's sinkhole")
