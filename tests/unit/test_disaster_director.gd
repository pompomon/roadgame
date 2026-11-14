extends GutTest
## DisasterDirector (plan.md §4.2, IMPLEMENTATION_PLAN.md M3.1, M3.3): after a wrong or missed turn
## it waits for the car to stop and plays a disaster from the area's pool, drawn with the run's
## disaster stream; after a crash it shakes the camera for CRASH_SECONDS. Every sequence ends once
## and in time, even one that is stuck. The disasters here are test ones;
## test_wrong_turn_disaster.gd plays the City's legend through the game's director. A disaster gets
## the stage for a legend's parts, and disaster_appeared comes when its delay is over (docs/M6.md
## S2, S18).

const Fixtures := preload("res://tests/helpers/road_fixtures.gd")
const StuckDisaster := preload("res://tests/helpers/stuck_disaster.gd")
const TimedDisaster := preload("res://tests/helpers/timed_disaster.gd")
const CAR_SCENE := preload("res://car/car.tscn")
const DELTA := 1.0 / 60.0
## The run seeds among which test_disaster_appeared_comes_once_when_the_delay_is_over looks for
## delays near the bounds.
const SEEDS := 100

## In the main scene's order, which is the order of their physics steps: the disaster layer, the
## car, the stage, the camera and the director.
var _root: Node
var _layer: Node2D
var _stage: Node2D
var _car: CarController
var _camera: CameraRig
var _director: DisasterDirector


func before_each() -> void:
	_root = Node.new()
	add_child_autofree(_root)
	_layer = Node2D.new()
	_root.add_child(_layer)
	_stage = Node2D.new()
	_root.add_child(_stage)
	_car = null
	_new_car()
	_camera = CameraRig.new()
	_root.add_child(_camera)
	_director = DisasterDirector.new()
	_director.layer = _layer
	_director.stage = _stage
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


## An area whose pool is a TimedDisaster.
static func _timed() -> AreaDef:
	return _area([_scene(TimedDisaster)])


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
	_director.play_disaster(_timed(), _car, _camera, Tuning.LIGHT_NIGHT)
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
	var disaster := _director.disaster as TimedDisaster
	assert_not_null(disaster, "the pool's disaster")
	assert_eq(disaster.get_parent(), _layer, "on the layer")
	assert_eq(disaster.car, _car)
	assert_eq(disaster.camera, _camera)
	assert_eq(disaster.stage, _stage, "with the stage for a legend's parts")
	assert_eq(disaster.ambient, Tuning.LIGHT_NIGHT, "in the light the run ended in")
	assert_eq(disaster.params, _director.params, "played with the params")
	assert_eq(_director.params.origin_world, _car.position, "where the car stopped")


func test_the_sequence_ends_once_when_the_disaster_finishes() -> void:
	# The stop takes speed / BRAKE, but at most STOP_SECONDS (J4); then the disaster plays.
	for speed: float in [2.0, Tuning.GLOBAL_SPEED_CAP]:
		var why := "from %.1f tiles/s" % speed
		_director.start_run(1)
		_new_car(CarSim.State.DISASTER, speed)
		clear_signal_watcher()
		watch_signals(_director)
		_director.play_disaster(_timed(), _car, _camera)
		var seconds := _run(600) * DELTA
		var stop := minf(speed / Tuning.BRAKE, Tuning.STOP_SECONDS)
		assert_almost_eq(seconds, stop + TimedDisaster.SECONDS, DELTA * 2.01, why)
		var disaster := _director.disaster
		simulate(_root, 60, DELTA)
		assert_signal_emit_count(_director, "sequence_finished", 1, why)
		assert_eq(_director.sequence, DisasterDirector.Sequence.FINISHED, why)
		assert_true(is_instance_valid(disaster), why + ": it stays for the game-over screen")
		assert_eq(disaster.get_parent(), _layer, why)


func test_disaster_started_comes_once_when_the_disaster_plays() -> void:
	var area := _timed()
	watch_signals(_director)
	_new_car(CarSim.State.DISASTER, 2.0)
	_director.play_disaster(area, _car, _camera)
	simulate(_root, 1, DELTA)
	assert_signal_not_emitted(_director, "disaster_started", "not before the car stops")
	_run(600)
	assert_signal_emit_count(_director, "disaster_started", 1)
	assert_signal_emitted_with_parameters(_director, "disaster_started", [_director.disaster, area])


func test_disaster_appeared_comes_once_when_the_delay_is_over() -> void:
	# The sound starts as the disaster shows, not as it starts to play (docs/M6.md S18). The
	# disaster counts its delay from play(), frame by frame as the director does.
	for delay: float in [Tuning.DISASTER_DELAY_MIN, Tuning.DISASTER_DELAY_MAX]:
		var area := _timed()
		_director.start_run(_seed_near(delay))
		_new_car()
		clear_signal_watcher()
		watch_signals(_director)
		_director.play_disaster(area, _car, _camera)
		simulate(_root, 1, DELTA)
		assert_signal_emit_count(_director, "disaster_started", 1, "it plays")
		var params := _director.params
		var why := "after a delay of %.3f s" % params.delay
		assert_almost_eq(params.delay, delay, 0.05, why + ": near the bound")
		var frames := 0
		while get_signal_emit_count(_director, "disaster_appeared") == 0 and frames < 120:
			simulate(_root, 1, DELTA)
			frames += 1
		assert_between(frames * DELTA, params.delay - 1e-6, params.delay + DELTA * 1.01, why)
		simulate(_root, 120, DELTA)
		assert_signal_emit_count(_director, "disaster_appeared", 1, why + ": once")
		assert_signal_emitted_with_parameters(
			_director, "disaster_appeared", [_director.disaster, area]
		)


## The first of SEEDS run seeds whose disaster, the first of the run, has the delay nearest
## `delay`. It draws as the director does.
func _seed_near(delay: float) -> int:
	var pool := _timed().disasters
	var nearest := 0
	var off := INF
	for run_seed: int in SEEDS:
		var rng := DisasterDirector.stream(run_seed)
		DisasterDirector.pick(pool, rng)
		var rolled := DisasterParams.roll(rng, Vector2.ZERO).delay
		if absf(rolled - delay) < off:
			off = absf(rolled - delay)
			nearest = run_seed
	return nearest


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
	assert_signal_not_emitted(_director, "disaster_started")
	assert_eq(_layer.get_child_count(), 0, "no disaster")
	assert_eq(_car.sim.speed, 0.0, "the car stopped")


func test_a_car_that_never_stops_times_out_with_an_error() -> void:
	_new_car(CarSim.State.DISASTER, 2.0)
	watch_signals(_director)
	_director.play_disaster(_timed(), _car, _camera)
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
	# The game is over by then, so a disaster that finishes late ends nothing.
	_director.disaster.finished.emit()
	assert_signal_emit_count(_director, "sequence_finished", 1, "a late finish")


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
	_director.play_disaster(_timed(), _car, _camera)
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
	assert_signal_not_emitted(_director, "disaster_appeared", "a cleared disaster never shows")


func test_a_second_sequence_is_an_error() -> void:
	_director.play_crash(_car, _camera)
	_director.play_disaster(_timed(), _car, _camera)
	assert_push_error("a sequence is already playing")
	assert_eq(_director.sequence, DisasterDirector.Sequence.CRASH)


func test_the_run_seed_decides_the_disaster() -> void:
	var rolls: Array[Array] = []
	for run_seed: int in [7, 7, 8]:
		_director.start_run(run_seed)
		_new_car()
		_director.play_disaster(_timed(), _car, _camera)
		simulate(_root, 1, DELTA)
		var params := _director.params
		rolls.append([params.direction, params.intensity, params.delay, params.particle_seed])
	assert_eq(rolls[0], rolls[1], "the same seed")
	assert_ne(rolls[0], rolls[2], "another seed")
