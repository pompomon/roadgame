class_name Mothman
extends Legend
## The City's second legend (POOLS_PLAN.md §5.4): night falls, and two red eyes open in a grey
## shape that perches at the roadside ahead. It spreads its wings, glides over to the car and takes
## it in its talons, and its wingbeats whirl the dust up off the road as it carries the car up and
## out of the top of the view. A grey feather drifts down to the road where the car stood, and
## stays. Its one glow, its eyes', lights once and stays lit. Its swoop leaves the perch straight up
## or down and comes in level, and its lift leaves steeply: so its eyes pass no point twice, and
## their light rises at each point at most once (§5.6).
## tools/art/legends/mothman.gd draws its sheets with these constants.

## Its sheet: frames of FRAME px, perched, unfurled, flying and carrying, facing the viewer, its
## foot between its talons. In every frame its eyes are about EYES px from its foot, where their
## glow, glow.tres at GLOW_SCALE, lights. It hovers HOVER_PX over the car's ground point as it takes
## the car, its talons on the car's roof.
const FRAME := Vector2i(72, 56)
const EYES := Vector2(0.0, -40.0)
const GLOW_SCALE := 0.3
const HOVER_PX := 12.0
## The feather's sheet: frames of FEATHER px, tilted left, tilted right, then lying on the road. It
## falls from FALL_PX over the car's ground point, swaying out SWAY_PX and back SWAYS times, to one
## side and then the other. A whole number: so it lands where it would have without the sway.
const FEATHER := Vector2i(16, 12)
const FALL_PX := 56.0
const SWAY_PX := 6.0
const SWAYS := 2
## The shares: of the perch that it takes to show, and from which its eyes open; of the unfurl by
## which it has spread its wings; and of the lift that the dust whirls up for, from which the
## feather falls, by which it lies on the road, and from which the Mothman fades with the car.
const SHOW_SHARE := 0.6
const EYES_FROM := 0.6
const UNFURL_AT := 0.3
const DUST_SHARE := 0.4
const FEATHER_FROM := 0.2
const LAND_AT := 0.85
const FADE_FROM := 0.7

## 1 if it carries the car off to the right of the screen, -1 to the left.
var _side := 1.0
## Where it perches, from the legend's origin.
var _perch := Vector2.ZERO
var _taken := false
var _double: Sprite2D

@onready var _moth: Sprite2D = %Moth
@onready var _eyes: Sprite2D = %Eyes
@onready var _dust: CPUParticles2D = %Dust
@onready var _feather: Sprite2D = %Feather


static func duration(params: DisasterParams) -> float:
	return params.delay + Beats.total(Tuning.MOTHMAN_BEATS)


## Where it perches, from the car's ground point, the car heading `heading`, in tile space: at the
## roadside ahead, MOTHMAN_AHEAD_TILES along the car's road, the tile axis nearest to its heading,
## and MOTHMAN_SIDE_TILES up-screen of the road's middle, as the phantom bus finds them.
static func perch(heading: Vector2) -> Vector2:
	var forward := PhantomBus.road(heading)
	var across := PhantomBus.side(forward)
	return Iso.tile_to_world(
		forward * Tuning.MOTHMAN_AHEAD_TILES - across * Tuning.MOTHMAN_SIDE_TILES
	)


## 1 if it carries the car off to the right of the screen, where `direction`, in tile space,
## points, or for none; -1 to the left.
static func side(direction: Vector2) -> float:
	return 1.0 if Iso.tile_to_world(direction).x >= 0.0 else -1.0


## Where it hovers as it takes the car, from the car's ground point.
static func hover() -> Vector2:
	return Vector2(0.0, -HOVER_PX)


## Where it is on its swoop from `from`, where it perched, to where it hovers, `t` of the swoop
## done: on a curve that leaves `from` straight up or down and comes in level, slowing to a stop.
static func swoop(from: Vector2, t: float) -> Vector2:
	var to := hover()
	var bend := Vector2(from.x, to.y)
	var s := 1.0 - (1.0 - t) * (1.0 - t)
	return from.lerp(bend, s).lerp(bend.lerp(to, s), s)


## How far it carries the car from where it hovers, up and to the side `to_side`, 1 for the right.
static func lift(to_side: float) -> Vector2:
	return Vector2(to_side * Tuning.MOTHMAN_LIFT_PX.x, Tuning.MOTHMAN_LIFT_PX.y)


## Where the feather shows its foot, from the car's ground point, `fallen` of its fall done: it
## sways from side to side as it falls, and comes to rest where the car stood.
static func drift(fallen: float) -> Vector2:
	return Vector2(SWAY_PX * sin(PI * SWAYS * fallen), -FALL_PX * (1.0 - fallen))


## The feather's frame `fallen` of its fall done: tilted the way it sways, then lying.
static func feather_frame(fallen: float) -> int:
	if fallen >= 1.0:
		return 2
	return 1 if cos(PI * SWAYS * fallen) >= 0.0 else 0


func _ready() -> void:
	super()
	_eyes.position = EYES
	_eyes.scale = Vector2.ONE * GLOW_SCALE


func play(params: DisasterParams) -> void:
	super(params)
	var heading := car.sim.forward() if car != null else params.direction
	_perch = perch(heading)
	_side = side(params.direction)
	_place(_perch)


func _beats() -> Array[float]:
	return Tuning.MOTHMAN_BEATS


func _pose(beat: int, t: float) -> void:
	match beat:
		0:
			_moth.modulate.a = minf(t / SHOW_SHARE, 1.0)
			var opened := clampf((t - EYES_FROM) / (1.0 - EYES_FROM), 0.0, 1.0)
			_eyes.modulate.a = Tuning.MOTHMAN_EYES_ALPHA * opened
		1:
			_moth.frame = 1 if t >= UNFURL_AT else 0
		2:
			_moth.frame = 2
			_moth.z_index = Tuning.SKY_Z
			_place(swoop(_perch, t))
		3:
			_carry(t)
			_fall(t)


## Puts its foot `at`, from the legend's origin, wherever it stands.
func _place(at: Vector2) -> void:
	_moth.global_position = to_global(at)


## It takes the car in its talons and carries it up and off, faster and faster, and fades with it,
## `t` of the lift done. Its wingbeats whirl up the dust as it rises.
func _carry(t: float) -> void:
	if not _taken:
		_taken = true
		_double = take_car()
		if _double != null:
			# It flies in the Mothman's talons, behind it, at its z. On the stage it would sort by
			# its foot, under the Mothman's, and draw over it.
			_double.reparent(_moth)
			_double.show_behind_parent = true
	_moth.frame = 3
	_place(hover() + lift(_side) * t * t)
	_moth.modulate.a = 1.0 - clampf((t - FADE_FROM) / (1.0 - FADE_FROM), 0.0, 1.0)
	_dust.emitting = t < DUST_SHARE


## The feather drifts down to where the car stood, from FEATHER_FROM of the lift, `t` of it done,
## and lies there. Only its offset falls, so it sorts by its foot, where the car stood.
func _fall(t: float) -> void:
	if t < FEATHER_FROM:
		return
	var fallen := minf((t - FEATHER_FROM) / (LAND_AT - FEATHER_FROM), 1.0)
	_feather.modulate.a = 1.0
	_feather.offset = Vector2(-FEATHER.x / 2.0, -FEATHER.y) + drift(fallen)
	_feather.frame = feather_frame(fallen)
