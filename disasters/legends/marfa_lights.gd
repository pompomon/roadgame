class_name MarfaLights
extends Legend
## The Desert's second legend (POOLS_PLAN.md §5.4), from the lights seen at night near Marfa,
## Texas: night falls, and three lights, white and amber, glimmer far off over the desert, one after
## another, up the screen from the car and to one side. They dance, drifting back across as they
## bob, then come close round the car, which turns to face up the screen after them. It leaves the
## road and follows them into the desert, smaller and smaller, its tyres throwing up sand, until it
## is gone with them. Its tyre tracks stay: two grooves that meet where it went, which show from the
## bottom up as it drives, so that they follow its back wheels. Its figure is its lights, which are
## glows: each keeps one brightness as it moves, and none is red. Each glides, and bobs at most
## MARFA_LIGHTS_DANCE_HZ times a second, and their glows keep apart, so that the light at each
## point of the world rises at most twice and never flashes (§5.6).
## tools/art/legends/marfa_lights.gd draws its sheet with these constants.

## How many lights there are; how far apart they glimmer, in px across the screen; and how large
## they are, as a share of glow.tres, far off and close round the car.
const LIGHTS := 3
const SPREAD_PX := 36.0
const FAR_SCALE := 0.25
const NEAR_SCALE := 0.45
## Where they gather round the car, in px from its ground point: one at each side and one over it.
## The side ones stand far enough out that, as they close in round the dwindling car, their glows
## miss where the middle one's has just shone: at 28 px, a few points by its path lit up thrice.
const RING: Array[Vector2] = [Vector2(-36.0, -10.0), Vector2(0.0, -30.0), Vector2(36.0, -10.0)]
## The shares of the glimmer: after which each light in turn starts to show, and that it takes to
## show at its brightness.
const STAGGER := 0.3
const FADE_SHARE := 0.4
## The car's tyre tracks, which its frame facing up the screen, frame 0, shows GAUGE px each side
## of its middle and REAR px under its ground point, under its back wheels. It follows the lights
## FOLLOW_PX up the screen, to where its tracks meet. Their sheet, TRACKS px, stands on its bottom
## row under the back wheels, and its top row is where the car goes.
const GAUGE := 7
const REAR := 7
const FOLLOW_PX := 88
const TRACKS := Vector2i(2 * GAUGE + 2, FOLLOW_PX + REAR)
## The share of the follow that the tyres throw up sand for.
const SAND_SHARE := 0.5

## 1 if the lights glimmer to the right of the screen, -1 to the left.
var _side := 1.0
var _taken := false
var _double: Sprite2D
## The car's frame as its double took its place, and where it stood, in the World.
var _first := 0
var _from := Vector2.ZERO

@onready var _lights: Array[Sprite2D] = [%Left, %Middle, %Right]
@onready var _sand: CPUParticles2D = %Sand
@onready var _tracks: Sprite2D = %Tracks


static func duration(params: DisasterParams) -> float:
	return params.delay + Beats.total(Tuning.MARFA_LIGHTS_BEATS)


## Where light `k` glimmers, from the car's ground point, the lights to the side `to_side`, 1 for
## the screen's right: far off up the screen, SPREAD_PX from the next, from left to right.
static func far(k: int, to_side: float) -> Vector2:
	var at := Tuning.MARFA_LIGHTS_FAR_PX
	return Vector2(to_side * at.x + (k - 1) * SPREAD_PX, at.y)


## How far light `k` has moved from where it glimmered, `seconds` into its dance, the lights to the
## side `to_side`: it drifts back across, steadily, as it bobs, the middle one down as the others
## go up.
static func dance(k: int, to_side: float, seconds: float) -> Vector2:
	var drift := Tuning.MARFA_LIGHTS_DRIFT_PX * seconds / Tuning.MARFA_LIGHTS_BEATS[1]
	var bob := Tuning.MARFA_LIGHTS_BOB_PX * sin(TAU * Tuning.MARFA_LIGHTS_DANCE_HZ * seconds)
	return Vector2(-to_side * drift, bob if k % 2 == 1 else -bob)


## Where light `k` is, `t` of the beckon done, from `from`, where its dance left it: it glides to
## its place round the car, slow at each end.
static func beckon(k: int, from: Vector2, t: float) -> Vector2:
	return from.lerp(RING[k], smoothstep(0.0, 1.0, t))


## The car's frame, `t` of the beckon done: it turns from `first`, the frame it stopped in, the
## shorter way, to face up the screen after the lights, frame 0. Frame k faces k steps of
## TAU / CarController.FRAMES clockwise from up the screen.
static func turn(first: int, t: float) -> int:
	var step := TAU / CarController.FRAMES
	var angle := lerp_angle(first * step, 0.0, smoothstep(0.0, 1.0, t))
	return posmod(roundi(angle / step), CarController.FRAMES)


## How far the car has followed the lights, from 0 to 1, `t` of the follow done: it pulls away
## slowly, and dwindles slowly into the distance. It is 1 less this the size it was.
static func gone(t: float) -> float:
	return smoothstep(0.0, 1.0, t)


## How many rows of the tracks' frame show, from its bottom, the car `followed` of the way gone: up
## to its back wheels, which leave its ground point, smaller and smaller, for the top row.
static func rows(followed: float) -> int:
	return clampi(roundi(TRACKS.y * followed), 0, TRACKS.y)


func _ready() -> void:
	super()
	for light: Sprite2D in _lights:
		light.scale = Vector2.ONE * FAR_SCALE
	_sand.position = Vector2(0.0, REAR)
	_show_tracks(0)


func play(params: DisasterParams) -> void:
	super(params)
	_side = Mothman.side(params.direction)
	for k: int in LIGHTS:
		_lights[k].position = far(k, _side)


func _beats() -> Array[float]:
	return Tuning.MARFA_LIGHTS_BEATS


func _pose(beat: int, t: float) -> void:
	match beat:
		0:
			_glimmer(t)
		1:
			var seconds := Tuning.MARFA_LIGHTS_BEATS[1] * t
			for k: int in LIGHTS:
				_lights[k].position = far(k, _side) + dance(k, _side, seconds)
		2:
			_beckon(t)
		3:
			_follow(t)


## The lights show one after another far off, `t` of the glimmer done.
func _glimmer(t: float) -> void:
	for k: int in LIGHTS:
		var shown := clampf((t - k * STAGGER) / FADE_SHARE, 0.0, 1.0)
		_lights[k].modulate.a = Tuning.MARFA_LIGHTS_ALPHA * shown


## The lights come close round the car, growing, `t` of the beckon done, and its double takes its
## place, once, and turns to face up the screen after them.
func _beckon(t: float) -> void:
	if not _taken:
		_taken = true
		_double = take_car()
		if _double != null:
			_from = _double.global_position
			_first = roundi(_double.region_rect.position.x / CarController.FRAME_SIZE.x)
	var danced := Tuning.MARFA_LIGHTS_BEATS[1]
	for k: int in LIGHTS:
		var from := far(k, _side) + dance(k, _side, danced)
		_lights[k].position = beckon(k, from, t)
		_lights[k].scale = Vector2.ONE * lerpf(FAR_SCALE, NEAR_SCALE, smoothstep(0.0, 1.0, t))
	if _double != null:
		_double.region_rect.position.x = CarController.FRAME_SIZE.x * turn(_first, t)


## The car follows the lights up the screen, `t` of the follow done, smaller and smaller till it is
## gone: they lead it, closing in as it dwindles. Its tyres throw up sand at first, from between its
## back wheels, and its tracks show up to them.
func _follow(t: float) -> void:
	var followed := gone(t)
	var size := 1.0 - followed
	var at := Vector2(0.0, -FOLLOW_PX * followed)
	for k: int in LIGHTS:
		_lights[k].position = at + RING[k] * size
		_lights[k].scale = Vector2.ONE * NEAR_SCALE * size
	_sand.position = at + Vector2(0.0, REAR * size)
	# Scaled, it throws the sand from between the dwindling wheels, and slower, as far off as they
	# are. Its grains keep their size: particles in the world's coordinates do.
	_sand.scale = Vector2.ONE * size
	_sand.emitting = t < SAND_SHARE
	_show_tracks(rows(followed))
	if _double != null:
		_double.global_position = _from + at
		_double.scale = Vector2.ONE * size
		_double.modulate.a = 1.0 if t < 1.0 else 0.0


## Shows the bottom `shown` rows of the tracks' frame, standing under the car's back wheels.
func _show_tracks(shown: int) -> void:
	_tracks.modulate.a = 1.0 if shown > 0 else 0.0
	_tracks.region_rect = Rect2(0, TRACKS.y - shown, TRACKS.x, shown)
	_tracks.offset = Vector2(-TRACKS.x / 2.0, REAR - shown)
