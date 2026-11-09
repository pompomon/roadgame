class_name Sinkhole
extends DisasterBase
## The City's disaster (plan.md §4.3, IMPLEMENTATION_PLAN.md M3.2), in grey box. After the delay in
## its params, a hole opens under the stopped car, throws debris and shakes the camera, and the
## car sinks into it: it shrinks and darkens. The hole and its rim are Polygon2Ds that grow by
## their scale, which never redraws them (M2_PLAN.md §5.7). The shader and the clip mask of
## IMPLEMENTATION_PLAN.md M3.2 come with M5's art (M3_PLAN.md Q3).

enum Phase { WAITING, DELAY, GROW, SINK, HOLD, DONE }

## The rim's radius, as a multiple of the hole's.
const RIM := 1.25
## How far the debris leans from straight up towards the params' direction.
const LEAN := 0.5
## The car's scale once it has sunk: it shrinks as it fades out, so it seems to drop into the hole.
const SUNK_SCALE := 0.2

var phase := Phase.WAITING

var _params: DisasterParams
## Seconds since play().
var _time := 0.0

@onready var _rim: Polygon2D = %Rim
@onready var _hole: Polygon2D = %Hole
@onready var _debris: CPUParticles2D = %Debris


func _ready() -> void:
	_rim.polygon = outline(Tuning.SINKHOLE_RADIUS * RIM)
	_hole.polygon = outline(Tuning.SINKHOLE_RADIUS)
	_grow(0.0)


func play(params: DisasterParams) -> void:
	_params = params
	position = params.origin_world
	apply_params(_debris, params)
	var lean := Iso.tile_to_world(params.direction).normalized() * LEAN
	_debris.direction = (Vector2.UP + lean).normalized()
	phase = Phase.DELAY


## The seconds from play() to finished: the delay and the three phases.
static func duration(params: DisasterParams) -> float:
	return (
		params.delay
		+ Tuning.SINKHOLE_GROW_SECONDS
		+ Tuning.SINKHOLE_SINK_SECONDS
		+ Tuning.SINKHOLE_HOLD_SECONDS
	)


func _physics_process(delta: float) -> void:
	if phase == Phase.WAITING or phase == Phase.DONE:
		return
	_time += delta
	var t := _time - _params.delay
	if phase == Phase.DELAY and t >= 0.0:
		phase = Phase.GROW
		_debris.emitting = true
		if camera != null:
			camera.shake(
				_params.intensity, Tuning.SINKHOLE_GROW_SECONDS + Tuning.SINKHOLE_SINK_SECONDS
			)
	if phase == Phase.GROW:
		_grow(t / Tuning.SINKHOLE_GROW_SECONDS)
		if t >= Tuning.SINKHOLE_GROW_SECONDS:
			phase = Phase.SINK
	t -= Tuning.SINKHOLE_GROW_SECONDS
	if phase == Phase.SINK:
		_sink(t / Tuning.SINKHOLE_SINK_SECONDS)
		if t >= Tuning.SINKHOLE_SINK_SECONDS:
			phase = Phase.HOLD
			_debris.emitting = false
	t -= Tuning.SINKHOLE_SINK_SECONDS
	if phase == Phase.HOLD and t >= Tuning.SINKHOLE_HOLD_SECONDS:
		phase = Phase.DONE
		finished.emit()


## Sizes the hole and its rim for `progress` from 0 (closed) to 1 (open).
func _grow(progress: float) -> void:
	var size := smoothstep(0.0, 1.0, progress)
	if _params != null:
		size *= _params.intensity
	_rim.scale = Vector2(size, size)
	_hole.scale = Vector2(size, size)


## Shrinks and darkens the car for `progress` from 0 (on the surface) to 1 (sunk).
func _sink(progress: float) -> void:
	if car == null:
		return
	var sunk := clampf(progress, 0.0, 1.0)
	car.scale = Vector2.ONE * lerpf(1.0, SUNK_SCALE, sunk)
	car.modulate = Color.WHITE.lerp(Color(0.0, 0.0, 0.0, 0.0), sunk)
