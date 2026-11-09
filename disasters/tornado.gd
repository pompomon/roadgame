class_name Tornado
extends DisasterBase
## The Rural disaster, and one of the Village's (plan.md §4.3, IMPLEMENTATION_PLAN.md M4.5), in grey
## box. After the delay in its params, a funnel comes at the stopped car along the params'
## direction, whirling dust, and shakes the camera. It carries the car off, which spins, shrinks and
## fades, then goes on its way and fades out. The funnel draws over the car, and its shadow under
## it. Its polygons move, sway and fade by their transforms and modulate, which never redraws them
## (M2_PLAN.md §5.7).

enum Phase { WAITING, DELAY, APPROACH, LIFT, LEAVE, DONE }

## The funnel's half-widths at the ground and at the top, in screen pixels at intensity 1. Its core
## is narrower by CORE.
const BASE_HALF_WIDTH := 6.0
const TOP_HALF_WIDTH := 30.0
const CORE := 0.5
## Points on the funnel's top edge.
const TOP_POINTS := 12
## How far the core sways from side to side, in screen pixels, and how often, in Hz.
const SWAY_PX := 5.0
const SWAY_HZ := 2.5
## The shadow's radius, in tiles at intensity 1.
const SHADOW_RADIUS := 0.35
## The share of its approach over which the funnel fades in, and of its leaving over which it fades
## out.
const FADE := 0.3
## The car's scale once the tornado has carried it off.
const LIFTED_SCALE := 0.3

var phase := Phase.WAITING

var _params: DisasterParams
## Seconds since play().
var _time := 0.0
## Where the funnel comes from and where it goes, from the car, in world pixels.
var _from := Vector2.ZERO
var _to := Vector2.ZERO

@onready var _funnel: Node2D = %Funnel
@onready var _body: Polygon2D = %Body
@onready var _core: Polygon2D = %Core
@onready var _shadow: Polygon2D = %Shadow
@onready var _dust: CPUParticles2D = %Dust


func _ready() -> void:
	_body.polygon = funnel(BASE_HALF_WIDTH, TOP_HALF_WIDTH)
	_core.polygon = funnel(BASE_HALF_WIDTH * CORE, TOP_HALF_WIDTH * CORE)
	_shadow.polygon = outline(SHADOW_RADIUS)
	_funnel.modulate.a = 0.0


func play(params: DisasterParams) -> void:
	_params = params
	position = params.origin_world
	apply_params(_dust, params)
	_from = Iso.tile_to_world(-params.direction * Tuning.TORNADO_APPROACH_TILES)
	_to = Iso.tile_to_world(params.direction * Tuning.TORNADO_LEAVE_TILES)
	_funnel.position = _from
	_funnel.scale = Vector2.ONE * params.intensity
	phase = Phase.DELAY


## A funnel standing on the origin, in world pixels: it widens from `base` either side at the
## ground to `top` at TORNADO_HEIGHT_PX, under the far half of an ellipse.
static func funnel(base: float, top: float) -> PackedVector2Array:
	var height := Tuning.TORNADO_HEIGHT_PX
	var points := PackedVector2Array([Vector2(-base, 0.0), Vector2(base, 0.0)])
	for i: int in TOP_POINTS + 1:
		var angle := PI * i / TOP_POINTS
		points.append(Vector2(top * cos(angle), -height - top * 0.5 * sin(angle)))
	return points


## The seconds from play() to finished: the delay and the three phases.
static func duration(params: DisasterParams) -> float:
	return (
		params.delay
		+ Tuning.TORNADO_APPROACH_SECONDS
		+ Tuning.TORNADO_LIFT_SECONDS
		+ Tuning.TORNADO_LEAVE_SECONDS
	)


## The car's rotation `seconds` into the lift, in radians: it spins faster in a stronger tornado.
static func spin(params: DisasterParams, seconds: float) -> float:
	return Tuning.TORNADO_SPIN * TAU * params.intensity * seconds


func _physics_process(delta: float) -> void:
	if phase == Phase.WAITING or phase == Phase.DONE:
		return
	_time += delta
	_core.position.x = sin(_time * SWAY_HZ * TAU) * SWAY_PX
	var t := _time - _params.delay
	if phase == Phase.DELAY and t >= 0.0:
		phase = Phase.APPROACH
		_dust.emitting = true
		if camera != null:
			camera.shake(
				_params.intensity, Tuning.TORNADO_APPROACH_SECONDS + Tuning.TORNADO_LIFT_SECONDS
			)
	if phase == Phase.APPROACH:
		var approached := t / Tuning.TORNADO_APPROACH_SECONDS
		_funnel.position = _from.lerp(Vector2.ZERO, minf(approached, 1.0))
		_funnel.modulate.a = clampf(approached / FADE, 0.0, 1.0)
		if t >= Tuning.TORNADO_APPROACH_SECONDS:
			phase = Phase.LIFT
	t -= Tuning.TORNADO_APPROACH_SECONDS
	if phase == Phase.LIFT:
		_lift(t)
		if t >= Tuning.TORNADO_LIFT_SECONDS:
			phase = Phase.LEAVE
			_dust.emitting = false
	t -= Tuning.TORNADO_LIFT_SECONDS
	if phase == Phase.LEAVE:
		var left := t / Tuning.TORNADO_LEAVE_SECONDS
		_funnel.position = _to * minf(left, 1.0)
		_funnel.modulate.a = clampf((1.0 - left) / FADE, 0.0, 1.0)
		if t >= Tuning.TORNADO_LEAVE_SECONDS:
			phase = Phase.DONE
			finished.emit()


## Spins, shrinks and fades the car `seconds` into the lift.
func _lift(seconds: float) -> void:
	if car == null:
		return
	var lifted := clampf(seconds / Tuning.TORNADO_LIFT_SECONDS, 0.0, 1.0)
	car.rotation = spin(_params, minf(seconds, Tuning.TORNADO_LIFT_SECONDS))
	car.scale = Vector2.ONE * lerpf(1.0, LIFTED_SCALE, lifted)
	car.modulate.a = 1.0 - lifted
