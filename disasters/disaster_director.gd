class_name DisasterDirector
extends Node
## Plays the end of a run (plan.md §4.2, IMPLEMENTATION_PLAN.md M3.1, M3.3). After a wrong or
## missed turn it waits for the car to stop, and plays the area's disaster for the run, which its
## picks drew as the car reached the area (POOLS_PLAN.md §5.1), on World's DisasterLayer, with
## params from the run's disaster stream. After a crash it shakes the camera and
## waits CRASH_SECONDS while the car stops and smokes. Either way it then emits sequence_finished,
## once, and DISASTER_TIMEOUT after the end of the run at the latest. Its time comes from
## _physics_process, as a disaster's must (docs/M3.md J2).

signal sequence_finished
## The disaster from `area`'s pool started to play.
signal disaster_started(disaster: DisasterBase, area: AreaDef)
## The disaster shows: the delay in its params is over, on its own clock from play() (docs/M6.md
## S18). Its sound starts now, with its first beat.
signal disaster_appeared(disaster: DisasterBase, area: AreaDef)

enum Sequence { NONE, STOPPING, PLAYING, CRASH, FINISHED }

## Where disasters go: World's DisasterLayer, above the road and below the car (J5).
var layer: Node2D
## Where a legend stands its parts: World's Props (docs/M6.md S2).
var stage: Node2D
var sequence := Sequence.NONE
## This run's disaster for each area that the car has reached.
var picks := DisasterPicks.new()
## The disaster playing, or null, and its params.
var disaster: DisasterBase
var params: DisasterParams

var _rng := RandomNumberGenerator.new()
var _area: AreaDef
var _car: CarController
var _camera: CameraRig
## The light that the run ended in, for the disaster (docs/DAYNIGHT.md §5.6).
var _ambient := Color.WHITE
## Seconds since the run ended.
var _time := 0.0
## Seconds since play(), as the disaster counts them, and whether disaster_appeared came.
var _play_time := 0.0
var _shown := false


## Clears the last run's sequence and takes this run's disaster stream and picks, in which the
## disasters with ids in `seen` weigh less (POOLS_PLAN.md Q2).
func start_run(run_seed: int, seen: Array[StringName] = []) -> void:
	clear()
	_rng = stream(run_seed)
	picks = DisasterPicks.new(run_seed, seen)


## The car reached `area`: its disaster for the run is picked now (POOLS_PLAN.md Q4). A pick is
## the same whenever it's made, so a wrong turn in an area that this missed plays the same one.
func enter_area(area: AreaDef) -> void:
	picks.pick(area)


## The disaster stream of the run with `run_seed`, for the disaster's params, apart from the
## road's and the picks', so that the same seed gives the same road, and the same params for the
## same disaster (plan.md §3.5, IMPLEMENTATION_PLAN.md §5.3).
static func stream(run_seed: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:disaster" % run_seed)
	return rng


## After a wrong or missed turn: a disaster from `area`'s pool, once `car` has stopped, in the
## `ambient` light that the run ended in.
func play_disaster(
	area: AreaDef, car: CarController, camera: CameraRig, ambient := Color.WHITE
) -> void:
	if _begin(car, camera):
		_area = area
		_ambient = ambient
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
	_area = null
	_car = null
	_camera = null
	_ambient = Color.WHITE
	_time = 0.0
	_play_time = 0.0
	_shown = false


func _physics_process(delta: float) -> void:
	if sequence == Sequence.NONE or sequence == Sequence.FINISHED:
		return
	_time += delta
	if sequence == Sequence.PLAYING and not _shown:
		_play_time += delta
		if _play_time >= params.delay:
			_shown = true
			disaster_appeared.emit(disaster, _area)
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
	var scene := picks.pick(_area)
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
	disaster.stage = stage
	disaster.ambient = _ambient
	disaster.finished.connect(_on_disaster_finished)
	layer.add_child(disaster)
	sequence = Sequence.PLAYING
	_play_time = 0.0
	_shown = false
	params = DisasterParams.roll(_rng, _car.position)
	disaster.play(params)
	disaster_started.emit(disaster, _area)


func _on_disaster_finished() -> void:
	if sequence == Sequence.PLAYING:
		_finish()


func _finish() -> void:
	sequence = Sequence.FINISHED
	sequence_finished.emit()
