class_name Flood
extends DisasterBase
## The Meadows' disaster, and one of the Village's (plan.md §4.3, IMPLEMENTATION_PLAN.md M4.5), in
## grey box. After the delay in its params, water rolls in along the params' direction and spreads
## around the stopped car. Then it rises over the car, faster in a stronger flood, with spray, and
## the car goes under: it takes the water's colour and fades. The water spreads by its position and
## scale, and rises as a surface that grows over the car (z_index 1), so nothing is redrawn
## (M2_PLAN.md §5.7).

enum Phase { WAITING, DELAY, SPREAD, RISE, HOLD, DONE }

## The surface's radius, as a share of the water's.
const SURFACE := 0.6
## The colour the car takes under the water.
const UNDERWATER := Color(0.2, 0.36, 0.62, 0.0)

var phase := Phase.WAITING

var _params: DisasterParams
## Seconds since play().
var _time := 0.0
## Where the water comes from, from the car, in world pixels.
var _from := Vector2.ZERO

@onready var _water: Polygon2D = %Water
@onready var _surface: Polygon2D = %Surface
@onready var _spray: CPUParticles2D = %Spray


func _ready() -> void:
	_water.polygon = outline(Tuning.FLOOD_RADIUS)
	_surface.polygon = outline(Tuning.FLOOD_RADIUS * SURFACE)
	_surface.scale = Vector2.ZERO
	_spread(0.0)


func play(params: DisasterParams) -> void:
	_params = params
	position = params.origin_world
	apply_params(_spray, params)
	_from = Iso.tile_to_world(-params.direction * Tuning.FLOOD_RADIUS)
	_spread(0.0)
	phase = Phase.DELAY


## The seconds the water takes to rise over the car: fewer, the stronger the flood.
static func rise_seconds(params: DisasterParams) -> float:
	return Tuning.FLOOD_RISE_SECONDS / maxf(params.intensity, Tuning.DISASTER_INTENSITY_MIN)


## The seconds from play() to finished: the delay and the three phases.
static func duration(params: DisasterParams) -> float:
	return (
		params.delay
		+ Tuning.FLOOD_SPREAD_SECONDS
		+ rise_seconds(params)
		+ Tuning.FLOOD_HOLD_SECONDS
	)


func _physics_process(delta: float) -> void:
	if phase == Phase.WAITING or phase == Phase.DONE:
		return
	_time += delta
	var t := _time - _params.delay
	if phase == Phase.DELAY and t >= 0.0:
		phase = Phase.SPREAD
	if phase == Phase.SPREAD:
		_spread(t / Tuning.FLOOD_SPREAD_SECONDS)
		if t >= Tuning.FLOOD_SPREAD_SECONDS:
			phase = Phase.RISE
			_spray.emitting = true
	t -= Tuning.FLOOD_SPREAD_SECONDS
	var rise := rise_seconds(_params)
	if phase == Phase.RISE:
		_rise(t / rise)
		if t >= rise:
			phase = Phase.HOLD
			_spray.emitting = false
	t -= rise
	if phase == Phase.HOLD and t >= Tuning.FLOOD_HOLD_SECONDS:
		phase = Phase.DONE
		finished.emit()


## Rolls the water in for `progress` from 0 (none, against the params' direction) to 1 (around the
## car).
func _spread(progress: float) -> void:
	var spread := smoothstep(0.0, 1.0, progress)
	_water.position = _from.lerp(Vector2.ZERO, spread)
	_water.scale = Vector2.ONE * spread


## Raises the water over the car for `progress` from 0 (the car on the surface) to 1 (under it).
func _rise(progress: float) -> void:
	var risen := smoothstep(0.0, 1.0, progress)
	_surface.scale = Vector2.ONE * risen
	if car != null:
		car.modulate = Color.WHITE.lerp(UNDERWATER, risen)
