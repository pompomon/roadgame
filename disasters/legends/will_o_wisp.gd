class_name WillOWisp
extends Legend
## The Meadows' third legend (docs/POOLS.md §5.4), from the lights over marshes that lead
## travellers astray: night falls, and four pale wisps glimmer out over the meadow round the car,
## one after another. They circle it, closing in, and it shrinks into a light at its middle, a fifth
## wisp, as tufts of bog cotton sprout where it stood and their seeds blow up. The five drift off
## together, up the screen, and fade; the bog cotton stays. Its figure is its wisps, which are
## glows: pale blue-green, never red, each the same size throughout, which brighten once and fade
## once. They circle at most WILL_O_WISP_CIRCLE_HZ turns a second, a quarter turn apart, so as
## they circle the light at each point of the world rises at most twice a second. Drifting off,
## they can light a point a third time within the second: as many times as §5.6 allows, no more.
## tools/art/legends/will_o_wisp.gd draws its sheet with these constants.

## How many wisps circle the car, and the ellipse, of RING px radii about the car's middle, that
## they close in to from FAR times as far out. The first stands START radians clockwise from the
## screen's right, and each next one a quarter turn on; they circle anticlockwise.
const WISPS := 4
const RING := Vector2(44.0, 22.0)
const FAR := 1.6
const START := TAU / 8.0
## Each wisp is glow.tres at GLOW_SCALE, the fifth too.
const GLOW_SCALE := 0.35
## The shares: of the glimmer that each wisp takes to show, the rest spread over the waits between
## them; of the circle over which they speed up, evenly, to WILL_O_WISP_CIRCLE_HZ; of the shrink
## that each tuft of bog cotton takes to sprout, the rest spread over the waits between them, and
## from which their seeds blow up; and of the drift from which the wisps fade.
const SHOW_SHARE := 0.4
const RAMP_SHARE := 0.5
const SPROUT_SHARE := 0.5
const SEED_SHARE := 0.4
const FADE_FROM := 0.3
## The double's scale once it has shrunk into the light.
const GONE_SCALE := 0.05
## The bog cotton's sheet: frames of TUFT px, each standing on its bottom row, as a tuft sprouts:
## shoots, buds, then white heads. Its tufts stand at TUFTS, in px from the car's ground point, in
## the order they sprout.
const TUFT := Vector2i(12, 14)
const TUFT_FRAMES := 3
const TUFTS: Array[Vector2] = [Vector2(-10.0, -1.0), Vector2(8.0, -4.0), Vector2(3.0, 5.0)]

## 1 if they drift off to the right of the screen, -1 to the left.
var _side := 1.0
var _taken := false
var _double: Sprite2D

@onready var _wisps: Array[Sprite2D] = [%Wisp1, %Wisp2, %Wisp3, %Wisp4]
@onready var _fifth: Sprite2D = %Fifth
@onready var _seeds: CPUParticles2D = %Seeds


static func duration(params: DisasterParams) -> float:
	return params.delay + Beats.total(Tuning.WILL_O_WISP_BEATS)


## How many turns they have circled, `seconds` after they began: they speed up evenly over the
## first RAMP_SHARE of the circle to WILL_O_WISP_CIRCLE_HZ, then keep that speed.
static func swept(seconds: float) -> float:
	var ramp := RAMP_SHARE * Tuning.WILL_O_WISP_BEATS[1]
	var hz := Tuning.WILL_O_WISP_CIRCLE_HZ
	var since := maxf(seconds, 0.0)
	if since <= ramp:
		return hz * since * since / (2.0 * ramp)
	return hz * (since - ramp / 2.0)


## Where wisp `k` is, from the middle of the ring, `turned` turns on, `spread` times RING out.
static func on_ring(k: int, turned: float, spread: float) -> Vector2:
	return Vector2.from_angle(START + TAU * k / WISPS - TAU * turned) * RING * spread


## How far they have drifted, `t` of the drift done, to the side `to_side`, 1 for the screen's
## right: slow at each end.
static func drift(t: float, to_side: float) -> Vector2:
	var way := Tuning.WILL_O_WISP_DRIFT_PX
	return Vector2(to_side * way.x, way.y) * smoothstep(0.0, 1.0, t)


## The share of their light left, `t` of the drift done: all of it till FADE_FROM, then less and
## less, evenly, till none.
static func left(t: float) -> float:
	return 1.0 - clampf((t - FADE_FROM) / (1.0 - FADE_FROM), 0.0, 1.0)


func _ready() -> void:
	super()
	for wisp: Sprite2D in _wisps:
		wisp.scale = Vector2.ONE * GLOW_SCALE
	_fifth.scale = Vector2.ONE * GLOW_SCALE
	_fifth.position = WitchHex.car_middle()
	_circle(0.0, FAR, Vector2.ZERO)
	if standing.size() != TUFTS.size():
		push_error("%s: it needs %d tufts of bog cotton" % [id, TUFTS.size()])
	for k: int in mini(standing.size(), TUFTS.size()):
		standing[k].position = TUFTS[k]


func play(params: DisasterParams) -> void:
	super(params)
	_side = Mothman.side(params.direction)


func _beats() -> Array[float]:
	return Tuning.WILL_O_WISP_BEATS


func _pose(beat: int, t: float) -> void:
	var beats := Tuning.WILL_O_WISP_BEATS
	match beat:
		0:
			for k: int in WISPS:
				var shown := FairyRing.in_turn(t, k, WISPS, SHOW_SHARE)
				_wisps[k].modulate.a = Tuning.WILL_O_WISP_ALPHA * shown
		1:
			_circle(beats[1] * t, lerpf(FAR, 1.0, smoothstep(0.0, 1.0, t)), Vector2.ZERO)
		2:
			_circle(beats[1] + beats[2] * t, 1.0, Vector2.ZERO)
			_shrink(t)
		3:
			var moved := drift(t, _side)
			_circle(beats[1] + beats[2] + beats[3] * t, 1.0, moved)
			_fifth.position = WitchHex.car_middle() + moved
			_fifth.modulate.a = Tuning.WILL_O_WISP_ALPHA * left(t)
			for wisp: Sprite2D in _wisps:
				wisp.modulate.a = _fifth.modulate.a
			_seeds.emitting = false


## Puts the wisps `seconds` into their circling, `spread` times RING out round the car's middle,
## and `moved` px on from it.
func _circle(seconds: float, spread: float, moved: Vector2) -> void:
	var turned := swept(seconds)
	for k: int in WISPS:
		_wisps[k].position = WitchHex.car_middle() + moved + on_ring(k, turned, spread)


## The car's double takes its place, once, and shrinks into a light at its middle, `t` of the
## shrink done, paling to the wisps' colour as it fades and the fifth wisp brightens. Tufts of bog
## cotton sprout one after another where it stood, and their seeds blow up. Its foot stays where
## the car stopped, so it sorts there.
func _shrink(t: float) -> void:
	if not _taken:
		_taken = true
		_double = take_car()
	var shrunk := smoothstep(0.0, 1.0, t)
	_fifth.modulate.a = Tuning.WILL_O_WISP_ALPHA * shrunk
	for k: int in standing.size():
		_sprout(standing[k], FairyRing.in_turn(t, k, standing.size(), SPROUT_SHARE))
	_seeds.emitting = t >= SEED_SHARE
	if _double == null:
		return
	var frame_size := Vector2(CarController.FRAME_SIZE)
	var size_now := lerpf(1.0, GONE_SCALE, shrunk)
	# Its offset keeps its middle, half its frame from its corner, where the car's was.
	_double.scale = Vector2.ONE * size_now
	_double.offset = WitchHex.car_middle() / size_now - frame_size / 2.0
	_double.self_modulate = Color.WHITE.lerp(_fifth.self_modulate, shrunk)
	_double.modulate.a = 1.0 - shrunk


## Shows `tuft` `share` of the way through its sheet's frames: hidden at 0, then frame by frame.
static func _sprout(tuft: Sprite2D, share: float) -> void:
	tuft.modulate.a = 1.0 if share > 0.0 else 0.0
	tuft.frame = mini(floori(share * tuft.hframes), tuft.hframes - 1)
