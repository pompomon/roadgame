class_name WitchHex
extends Legend
## The Village's legend (docs/M6.md §3.3, Q2): dusk falls on the village, and a hunched witch on a
## broomstick swoops in out of the dark. She circles the car once, then points a long finger at it,
## and a trail of violet sparkles runs from her finger to the car. A puff of black smoke hides the
## car, and as it clears, a jack-o'-lantern pops up where the car stood. Its grin lights from within
## as the witch flies off, and it stays, lit, on the road. There's no double: the car fades in the
## smoke (§5.4). Its one glow, the grin's, lights once and stays lit (§5.6).
## tools/art/legends/witch_hex.gd draws its sheets with these constants.

## The witch's sheet: frames of WITCH px, flying, then pointing, facing right; flip_h faces her
## left. She flies HEIGHT px over the car's ground point, on an ellipse of CIRCLE px radii about the
## point there: she hovers at its end on the side she came from, away from the one she flies off to.
## In the pointing frame her fingertip is the texel FINGER px from her foot, the middle of the
## frame's bottom row.
const WITCH := Vector2i(32, 24)
const HEIGHT := 40.0
const CIRCLE := Vector2(60.0, 30.0)
const FINGER := Vector2i(14, -13)
## The jack-o'-lantern's sheet: frames of PUMPKIN px, its grin dark, then lit. It stands where the
## car stopped. Its grin's glow, glow.tres at GLOW_SCALE, lights GRIN_AT px from its foot.
const PUMPKIN := Vector2i(24, 20)
const GRIN_AT := Vector2(0.0, -8.0)
const GLOW_SCALE := 0.5
## The trail's sparkles are born at TRAIL_POINTS points from her fingertip toward the car.
const TRAIL_POINTS := 12
## The shares: of the cackle that she takes to swoop in, and of that to show; of the hex by which
## she has circled the car once and points; of the puff that the smoke pours out for, and that the
## car fades over, from HIDE_FROM to HIDE_TO; of the last beat that the jack-o'-lantern takes to pop
## up, OVERSHOOT times its size PEAK_SHARE of the way; by which its grin is lit, from the pop's end;
## and after which the witch fades as she flies off.
const SWOOP_SHARE := 0.4
const SHOW_SHARE := 0.5
const CIRCLE_SHARE := 0.4
const SMOKE_SHARE := 0.5
const HIDE_FROM := 0.2
const HIDE_TO := 0.5
const POP_SHARE := 0.3
const PEAK_SHARE := 0.6
const OVERSHOOT := 1.25
const LIGHT_TO := 0.6
const FADE_FROM := 0.5

## 1 if she flies off to the right of the screen, -1 to the left.
var _side := 1.0
var _pumpkin: Sprite2D

@onready var _witch: Sprite2D = %Witch
@onready var _trail: CPUParticles2D = %Trail
@onready var _smoke: CPUParticles2D = %Smoke
@onready var _glow: Sprite2D = %Glow


static func duration(params: DisasterParams) -> float:
	return params.delay + Beats.total(Tuning.WITCH_HEX_BEATS)


## 1 if the witch flies off to the right of the screen, where `direction`, in tile space, points,
## or for none; -1 to the left. She comes in from the other side.
static func side(direction: Vector2) -> float:
	return 1.0 if Iso.tile_to_world(direction).x >= 0.0 else -1.0


## Where she hovers, from the car's ground point, as she starts and ends her circle and points: on
## the side she came from, `from_side` -1 for the left.
static func hover(from_side: float) -> Vector2:
	return Vector2(from_side * CIRCLE.x, -HEIGHT)


## Where she is on her circle, from the car's ground point, `turned` of the way round from where she
## hovers on `from_side`: in front of the car, round to its other side, then behind it and back.
static func on_circle(from_side: float, turned: float) -> Vector2:
	var angle := TAU * turned
	return Vector2(from_side * CIRCLE.x * cos(angle), -HEIGHT + CIRCLE.y * sin(angle))


## Where her fingertip's texel shows as she points, from her foot, facing the car from `from_side`.
static func fingertip(from_side: float) -> Vector2:
	var centre := Vector2(FINGER) + Vector2(0.5, 0.5)
	return Vector2(-from_side * centre.x, centre.y)


## The middle of the car, from its ground point.
static func car_middle() -> Vector2:
	return Vector2(CarController.FRAME_SIZE) / 2.0 - Vector2(CarController.FOOT)


## The jack-o'-lantern's scale `popped` of the way through its pop: it grows to OVERSHOOT times its
## size, then settles back to it.
static func pop_scale(popped: float) -> float:
	if popped < PEAK_SHARE:
		return OVERSHOOT * sin(PI / 2.0 * popped / PEAK_SHARE)
	return lerpf(OVERSHOOT, 1.0, smoothstep(PEAK_SHARE, 1.0, popped))


func _ready() -> void:
	super()
	_smoke.position = car_middle()
	_glow.position = GRIN_AT
	_glow.scale = Vector2.ONE * GLOW_SCALE
	if standing.is_empty():
		push_error("%s: it needs a jack-o'-lantern" % id)
		return
	_pumpkin = standing[0]


func play(params: DisasterParams) -> void:
	super(params)
	_side = side(params.direction)
	var from := hover(-_side) + fingertip(-_side)
	_trail.direction = (car_middle() - from).normalized()


func _beats() -> Array[float]:
	return Tuning.WITCH_HEX_BEATS


func _pose(beat: int, t: float) -> void:
	var beats := Tuning.WITCH_HEX_BEATS
	match beat:
		0:
			_fly(t * beats[0])
		1:
			_fly(beats[0] + t * beats[1])
			_hex(t)
		2:
			_trail.emitting = false
			_smoke.emitting = t < SMOKE_SHARE
			if car != null:
				car.modulate.a = 1.0 - clampf((t - HIDE_FROM) / (HIDE_TO - HIDE_FROM), 0.0, 1.0)
		3:
			_fly_off(t)
			_pop(t)


## The witch `seconds` into her flight: she swoops in to where she hovers, slowing, then circles the
## car once, facing the way she flies, and points at it.
func _fly(seconds: float) -> void:
	var beats := Tuning.WITCH_HEX_BEATS
	var swooped: float = beats[0] * SWOOP_SHARE
	var circled: float = beats[0] + beats[1] * CIRCLE_SHARE
	var from_side := -_side
	_witch.modulate.a = 1.0
	_witch.frame = 0
	_witch.flip_h = _side < 0.0
	if seconds <= swooped:
		var t := seconds / swooped
		var swoop := Vector2(_side * Tuning.WITCH_HEX_SWOOP_PX.x, Tuning.WITCH_HEX_SWOOP_PX.y)
		_witch.position = hover(from_side) + swoop * (1.0 - t) * (1.0 - t)
		_witch.modulate.a = minf(t / SHOW_SHARE, 1.0)
	elif seconds < circled:
		# She speeds up from where she hovers and slows back to it.
		var turned := smoothstep(0.0, 1.0, (seconds - swooped) / (circled - swooped))
		_witch.position = on_circle(from_side, turned)
		_witch.flip_h = from_side * sin(TAU * turned) > 0.0
	else:
		_witch.position = hover(from_side)
		_witch.frame = 1


## The trail of sparkles from her fingertip to the car once she points, `t` of the hex done: they
## are born on the line from her fingertip, which reaches the car by the hex's end.
func _hex(t: float) -> void:
	if t < CIRCLE_SHARE:
		return
	var from := hover(-_side) + fingertip(-_side)
	var to := from.lerp(car_middle(), (t - CIRCLE_SHARE) / (1.0 - CIRCLE_SHARE))
	var points := PackedVector2Array()
	for k: int in TRAIL_POINTS:
		points.append(from.lerp(to, float(k) / (TRAIL_POINTS - 1)))
	# Before it emits: with no points, it would emit nothing.
	_trail.emission_points = points
	_trail.emitting = true


## She flies off, faster and faster, to the side that the params' direction picks, and fades, `t` of
## the last beat done.
func _fly_off(t: float) -> void:
	var away := Vector2(_side * Tuning.WITCH_HEX_FLY_OFF_PX.x, Tuning.WITCH_HEX_FLY_OFF_PX.y)
	_witch.position = hover(-_side) + away * t * t
	_witch.frame = 0
	_witch.flip_h = _side < 0.0
	_witch.modulate.a = 1.0 - clampf((t - FADE_FROM) / (1.0 - FADE_FROM), 0.0, 1.0)


## The jack-o'-lantern pops up where the car stood, `t` of the last beat done, and its grin lights.
func _pop(t: float) -> void:
	var lit := clampf((t - POP_SHARE) / (LIGHT_TO - POP_SHARE), 0.0, 1.0)
	_glow.modulate.a = Tuning.WITCH_HEX_GLOW_ALPHA * lit
	if _pumpkin == null:
		return
	_pumpkin.scale = Vector2.ONE * pop_scale(minf(t / POP_SHARE, 1.0))
	_pumpkin.frame = 1 if lit > 0.0 else 0
