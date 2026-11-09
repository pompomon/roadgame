class_name DisasterDirector
extends Node
## Plays the end of a run (plan.md §4.2, IMPLEMENTATION_PLAN.md M3.1, M3.3). After a wrong or
## missed turn it waits for the car to stop, picks a disaster from the area's pool with the run's
## disaster stream, and plays it on World's DisasterLayer. After a crash it shakes the camera and
## waits CRASH_SECONDS while the car stops and smokes. Either way it then emits sequence_finished,
## once, and DISASTER_TIMEOUT after the end of the run at the latest. Its time comes from
## _physics_process, as a disaster's must (M3_PLAN.md J2).

signal sequence_finished

enum Sequence { NONE, STOPPING, PLAYING, CRASH, FINISHED }

## Where disasters go: World's DisasterLayer, above the road and below the car (J5).
var layer: Node2D
var sequence := Sequence.NONE
## The disaster playing, or null, and its params.
var disaster: DisasterBase
var params: DisasterParams

var _rng := RandomNumberGenerator.new()
var _pool: Array[PackedScene] = []
var _car: CarController
var _camera: CameraRig
## Seconds since the run ended.
var _time := 0.0


## Clears the last run's sequence and takes this run's disaster stream.
func start_run(run_seed: int) -> void:
	clear()
	_rng = stream(run_seed)


## The disaster stream of the run with `run_seed`, apart from the road's, so that the same seed
## gives the same road and the same disasters (plan.md §3.5, IMPLEMENTATION_PLAN.md §5.3).
static func stream(run_seed: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:disaster" % run_seed)
	return rng


## After a wrong or missed turn: a disaster from `area`'s pool, once `car` has stopped.
func play_disaster(area: AreaDef, car: CarController, camera: CameraRig) -> void:
	if _begin(car, camera):
		_pool = area.disasters
		sequence = Sequence.STOPPING


## After a crash: CRASH_SECONDS with a shake.
func play_crash(car: CarController, camera: CameraRig) -> void:
	if _begin(car, camera):
		sequence = Sequence.CRASH
		camera.shake(Tuning.CRASH_SHAKE, Tuning.CRASH_SHAKE_SECONDS)


## Frees the disaster at once, so that a retry leaves no node behind (J13), and forgets the
## sequence.
func clear() -> void:
	if disaster != null:
		disaster.free()
	disaster = null
	params = null
	sequence = Sequence.NONE
	_pool = []
	_car = null
	_camera = null
	_time = 0.0


## The scene `rng` draws from `pool`, or null if the pool is empty.
static func pick(pool: Array[PackedScene], rng: RandomNumberGenerator) -> PackedScene:
	if pool.is_empty():
		return null
	return pool[rng.randi_range(0, pool.size() - 1)]


func _physics_process(delta: float) -> void:
	if sequence == Sequence.NONE or sequence == Sequence.FINISHED:
		return
	_time += delta
	if sequence == Sequence.STOPPING and _car.sim.speed == 0.0:
		_start_disaster()
	elif sequence == Sequence.CRASH and _time >= Tuning.CRASH_SECONDS:
		_finish()
	if sequence != Sequence.FINISHED and _time >= Tuning.DISASTER_TIMEOUT:
		push_error("DisasterDirector: the sequence did not end in %.1f s" % Tuning.DISASTER_TIMEOUT)
		_finish()


func _begin(car: CarController, camera: CameraRig) -> bool:
	if sequence != Sequence.NONE:
		push_error("DisasterDirector: a sequence is already playing")
		return false
	_car = car
	_camera = camera
	_time = 0.0
	return true


func _start_disaster() -> void:
	var scene := pick(_pool, _rng)
	var node: Node = scene.instantiate() if scene != null else null
	disaster = node as DisasterBase
	if disaster == null:
		push_error("DisasterDirector: the area's pool has no disaster to play")
		if node != null:
			node.free()
		_finish()
		return
	disaster.car = _car
	disaster.camera = _camera
	disaster.finished.connect(_on_disaster_finished)
	layer.add_child(disaster)
	sequence = Sequence.PLAYING
	params = DisasterParams.roll(_rng, _car.position)
	disaster.play(params)


func _on_disaster_finished() -> void:
	if sequence == Sequence.PLAYING:
		_finish()


func _finish() -> void:
	sequence = Sequence.FINISHED
	sequence_finished.emit()
