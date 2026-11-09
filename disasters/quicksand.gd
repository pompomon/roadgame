class_name Quicksand
extends DisasterBase
## The Desert's disaster (plan.md §4.3, IMPLEMENTATION_PLAN.md M4.5), in grey box. After the delay
## in its params, a pit of sand spreads under the stopped car, with ripples. Then the car sinks,
## faster in stronger quicksand: it rocks from side to side less and less, shrinks and fades, and
## sand flies. The pit and its ripple grow by their scale and fade by their modulate, so nothing is
## redrawn (M2_PLAN.md §5.7).

enum Phase { WAITING, DELAY, SPREAD, SINK, HOLD, DONE }

## Ripples per second, each growing from the centre to the pit's edge as it fades.
const RIPPLE_HZ := 1.5
## The car's scale once it has sunk.
const SUNK_SCALE := 0.3

var phase := Phase.WAITING

var _params: DisasterParams
## Seconds since play().
var _time := 0.0

@onready var _pit: Polygon2D = %Pit
@onready var _ripple: Polygon2D = %Ripple
@onready var _grains: CPUParticles2D = %Grains


func _ready() -> void:
	_pit.polygon = outline(Tuning.QUICKSAND_RADIUS)
	_ripple.polygon = outline(Tuning.QUICKSAND_RADIUS)
	_spread(0.0)
	_ripple_at(0.0)


func play(params: DisasterParams) -> void:
	_params = params
	position = params.origin_world
	apply_params(_grains, params)
	phase = Phase.DELAY


## The seconds the car takes to sink: fewer, the stronger the quicksand.
static func sink_seconds(params: DisasterParams) -> float:
	return Tuning.QUICKSAND_SINK_SECONDS / maxf(params.intensity, Tuning.DISASTER_INTENSITY_MIN)


## The seconds from play() to finished: the delay and the three phases.
static func duration(params: DisasterParams) -> float:
	return (
		params.delay
		+ Tuning.QUICKSAND_SPREAD_SECONDS
		+ sink_seconds(params)
		+ Tuning.QUICKSAND_HOLD_SECONDS
	)


## The car's rotation `seconds` into its sinking, in radians: it rocks QUICKSAND_WOBBLE_HZ times a
## second, less as it sinks, and is level once it has sunk.
static func wobble(params: DisasterParams, seconds: float) -> float:
	var sunk := clampf(seconds / sink_seconds(params), 0.0, 1.0)
	return sin(seconds * Tuning.QUICKSAND_WOBBLE_HZ * TAU) * Tuning.QUICKSAND_WOBBLE * (1.0 - sunk)


func _physics_process(delta: float) -> void:
	if phase == Phase.WAITING or phase == Phase.DONE:
		return
	_time += delta
	var t := _time - _params.delay
	if phase == Phase.DELAY and t >= 0.0:
		phase = Phase.SPREAD
	if phase == Phase.SPREAD:
		_spread(t / Tuning.QUICKSAND_SPREAD_SECONDS)
		if t >= Tuning.QUICKSAND_SPREAD_SECONDS:
			phase = Phase.SINK
			_grains.emitting = true
	if phase != Phase.DELAY:
		_ripple_at(t)
	t -= Tuning.QUICKSAND_SPREAD_SECONDS
	var sink := sink_seconds(_params)
	if phase == Phase.SINK:
		_sink(t)
		if t >= sink:
			phase = Phase.HOLD
			_grains.emitting = false
	t -= sink
	if phase == Phase.HOLD and t >= Tuning.QUICKSAND_HOLD_SECONDS:
		phase = Phase.DONE
		finished.emit()


## Spreads the pit for `progress` from 0 (none) to 1 (its full size, by the intensity).
func _spread(progress: float) -> void:
	var size := smoothstep(0.0, 1.0, progress)
	if _params != null:
		size *= _params.intensity
	_pit.scale = Vector2.ONE * size


## Grows and fades the ripple, `seconds` after the pit began to spread, within the pit.
func _ripple_at(seconds: float) -> void:
	var ripple := fposmod(seconds * RIPPLE_HZ, 1.0)
	_ripple.scale = _pit.scale * ripple
	_ripple.modulate.a = 1.0 - ripple


## Rocks, shrinks and fades the car `seconds` into its sinking.
func _sink(seconds: float) -> void:
	if car == null:
		return
	var sunk := clampf(seconds / sink_seconds(_params), 0.0, 1.0)
	car.rotation = wobble(_params, seconds)
	car.scale = Vector2.ONE * lerpf(1.0, SUNK_SCALE, sunk)
	car.modulate = Color.WHITE.lerp(Color(0.0, 0.0, 0.0, 0.0), sunk)
