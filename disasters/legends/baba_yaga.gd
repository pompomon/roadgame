class_name BabaYaga
extends Legend
## The Village's third legend (POOLS_PLAN.md §5.4), from the Russian tales of Baba Yaga: dusk
## falls, and her log hut on chicken legs stomps along beside the road to the car, the dust flying
## from its feet, and stops beside it, up-screen of the car and off the road, wherever across the
## road the car stopped. It turns its front to the car, crouches, and its door opens on the dark.
## The car turns to the door and rolls in, smaller and smaller, and the door shuts behind it; the
## hut rises, turns back the way it was going, and stomps off, faster and faster, and fades. Its
## chicken feet leave prints behind it as it goes, which stay. The car's double rolls to the hut's
## door, a pixel down-screen of the hut's foot, so that it sorts in front of the hut. The hut's
## window is painted yellow, not lit: it has no glow (§5.4 Δ), so no light moves about with its
## stomps, only its dusk veil. tools/art/legends/baba_yaga.gd draws its sheets with these constants.

## The hut's frames: stomping, its near leg raised and then its far one, and standing, in profile;
## turned three-quarters to the car; its front to the car, the door shut; squatting, half down; and
## crouched on its folded legs, its door shut and then open on the dark.
enum Pose { STOMP_A, STOMP_B, STAND, TURN, FRONT, SQUAT, CROUCH, OPEN }

## The hut's sheet: frames of HUT px, each standing on its bottom row, in profile facing the
## screen's right; flip_h faces it left. Where the car's double rolls to, from the hut's foot: a
## pixel down-screen of it, at the door as the hut crouches.
const HUT := Vector2i(64, 64)
const DOOR := Vector2(0.0, 1.0)
## The prints' sheet: frames of PRINTS px, centred on the middle of the stretch that the hut stomps
## off along, PRINTS_TILES long from where it stopped. It is drawn for a way along the tile x axis,
## down the screen; flip_h and flip_v lay it along the others. Its frames show the first 1 to
## STRIDES of the hut's strides, a print each, in its share of the stretch.
const PRINTS := Vector2i(96, 48)
const PRINTS_TILES := 1.25
const STRIDES := 4
## The hut's legs take turns, raised, once each STRIDE_TILES that it stomps: a print's share.
const STRIDE_TILES := PRINTS_TILES / STRIDES
## The shares: of the stomp in that the hut takes to show; of the turn from which it shows three
## quarters, and then its front; of the open from which it squats, crouches, and its door opens; of
## the swallow that the car takes to roll in, shrinking to BOARDED_SCALE, its last FADE_SHARE
## fading; from which the hut rises, half up and then turning; from which it stomps off; from which
## it fades; and till which its dust flies, while it still shows, so that none of it is born unseen.
const SHOW_SHARE := 0.4
const THREE_QUARTER_FROM := 1.0 / 3.0
const FRONT_FROM := 2.0 / 3.0
const SQUAT_FROM := 0.2
const CROUCH_FROM := 0.4
const OPEN_FROM := 0.6
const ROLL_SHARE := 0.3
const BOARDED_SCALE := 0.3
const FADE_SHARE := 0.4
const RISE_FROM := 0.38
const RISEN_FROM := 0.46
const OFF_FROM := 0.55
const FADE_FROM := 0.75
const DUST_SHARE := 0.9

## Where the hut stops, from the legend's origin, and one tile along the way that it stomps, in px.
var _stop := Vector2.ZERO
var _way := Vector2.ZERO
var _taken := false
var _double: Sprite2D
## Where the double stood as it took the car's place, in the World, and the frame it faced in.
var _from := Vector2.ZERO
var _first := 0

@onready var _hut: Sprite2D = %Hut
@onready var _prints: Sprite2D = %Prints
@onready var _dust: CPUParticles2D = %Dust


static func duration(params: DisasterParams) -> float:
	return params.delay + Beats.total(Tuning.BABA_YAGA_BEATS)


## Where the hut stops, in px from the car's ground point, were the car on its road's middle and
## heading `heading`, in tile space: beside the car, BABA_YAGA_SIDE_TILES up-screen of the middle
## of its road, the tile axis nearest to its heading, as Frau Holle's well stands.
static func stop(heading: Vector2) -> Vector2:
	return Iso.tile_to_world(
		-PhantomBus.side(PhantomBus.road(heading)) * Tuning.BABA_YAGA_SIDE_TILES
	)


## How far across its road the hut stops from stop(), in tiles, the car's ground point at `at`, in
## tile space, heading `heading`, on `buffer`'s road. A wrong turn can leave the car off the middle
## of the road ahead that it stopped on or beside (HeadlessHorseman.to_middle()). Where it stopped
## down-screen of it, up-screen as far as the middle, so that the hut stops beside the road, not on
## it; where up-screen of it, none, so that the hut stops up-screen of the car, off the road too,
## and the car still rolls up-screen to its door. With no road ahead, none.
static func shift(at: Vector2, heading: Vector2, buffer: RoadBuffer) -> Vector2:
	var road := PhantomBus.road(heading)
	var middle := HeadlessHorseman.to_middle(at, road, buffer)
	return middle if middle.dot(PhantomBus.side(road)) < 0.0 else Vector2.ZERO


## Its frame `walked` tiles into a stomp: its near leg raised, then its far one, in turn.
static func stride(walked: float) -> int:
	return Pose.STOMP_A if floori(walked / STRIDE_TILES) % 2 == 0 else Pose.STOMP_B


## Its frame, `t` of the turn done: in profile, then turned three-quarters, then its front to the
## car.
static func turned(t: float) -> int:
	if t >= FRONT_FROM:
		return Pose.FRONT
	return Pose.TURN if t >= THREE_QUARTER_FROM else Pose.STAND


## Its frame, `t` of the open done: its front to the car, then squatting, crouched, and its door
## open.
static func opened(t: float) -> int:
	if t >= OPEN_FROM:
		return Pose.OPEN
	if t >= CROUCH_FROM:
		return Pose.CROUCH
	return Pose.SQUAT if t >= SQUAT_FROM else Pose.FRONT


## How far it has stomped off from where it stopped, `t` of the swallow done, in tiles: none till
## OFF_FROM, then faster and faster, BABA_YAGA_OFF_TILES in all.
static func stomped(t: float) -> float:
	var off := clampf((t - OFF_FROM) / (1.0 - OFF_FROM), 0.0, 1.0)
	return off * off * Tuning.BABA_YAGA_OFF_TILES


## Its frame, `t` of the swallow done: its door open as the car rolls in, then shut, crouched; it
## rises, half up and then turning back the way it was going, and stomps off.
static func leaving(t: float) -> int:
	if t < ROLL_SHARE:
		return Pose.OPEN
	if t < RISE_FROM:
		return Pose.CROUCH
	if t < RISEN_FROM:
		return Pose.SQUAT
	return Pose.TURN if t < OFF_FROM else stride(stomped(t))


## How many strides of prints it has left, `past` tiles on from where it stopped: each once it has
## passed its end.
static func laid(past: float) -> int:
	return clampi(floori(past / STRIDE_TILES), 0, STRIDES)


## What shows of it, `t` of the swallow done: all, then less and less from FADE_FROM.
static func fading(t: float) -> float:
	return 1.0 - clampf((t - FADE_FROM) / (1.0 - FADE_FROM), 0.0, 1.0)


## The car's frame, `t` of its roll done the way `toward`, from where it stopped to the door: it
## turns from `first`, the frame it stopped in, to face the door. Frame k faces k steps of
## TAU / CarController.FRAMES clockwise from up the screen.
static func steer(first: int, toward: Vector2, t: float) -> int:
	var step := TAU / CarController.FRAMES
	var angle := lerp_angle(first * step, atan2(toward.x, -toward.y), smoothstep(0.0, 1.0, t))
	return posmod(roundi(angle / step), CarController.FRAMES)


func play(params: DisasterParams) -> void:
	super(params)
	var heading := car.sim.forward() if car != null else params.direction
	_stop = stop(heading)
	if car != null:
		var at := Iso.world_to_tile(params.origin_world)
		_stop += Iso.tile_to_world(shift(at, heading, car.sim.buffer))
	_way = Iso.tile_to_world(PhantomBus.way(heading, params.direction))
	_hut.flip_h = _way.x < 0.0
	_place(_stop - _way * Tuning.BABA_YAGA_FROM_TILES)
	_prints.position = _stop + _way * (PRINTS_TILES / 2.0)
	_prints.flip_h = _way.x < 0.0
	_prints.flip_v = _way.y < 0.0


func _beats() -> Array[float]:
	return Tuning.BABA_YAGA_BEATS


func _pose(beat: int, t: float) -> void:
	match beat:
		0:
			_stomp_in(t)
		1:
			_hut.frame = turned(t)
		2:
			_hut.frame = opened(t)
		3:
			_roll_in(t)
			_stomp_off(t)


## Puts the hut's foot `at`, from the legend's origin, and the dust at its feet, as faint as it is:
## the dust shows as it does, and once it has gone none of it shows.
func _place(at: Vector2) -> void:
	_hut.global_position = to_global(at)
	_dust.position = at
	_dust.modulate.a = _hut.modulate.a


## It stomps in to where it stops, `t` of the stomp done, slower and slower, and shows, and stands.
## The dust flies from its feet till it stops.
func _stomp_in(t: float) -> void:
	_hut.modulate.a = minf(t / SHOW_SHARE, 1.0)
	var eased := 1.0 - (1.0 - t) * (1.0 - t)
	_hut.frame = stride(eased * Tuning.BABA_YAGA_FROM_TILES) if t < 1.0 else Pose.STAND
	_place(_stop - _way * Tuning.BABA_YAGA_FROM_TILES * (1.0 - eased))
	_dust.emitting = t < 1.0


## The car turns to the door and rolls in, `t` of the swallow done, shrinking, and fades: its double
## takes its place, once.
func _roll_in(t: float) -> void:
	if not _taken:
		_taken = true
		_double = take_car()
		if _double != null:
			_from = _double.global_position
			_first = roundi(_double.region_rect.position.x / CarController.FRAME_SIZE.x)
	if _double == null:
		return
	var door := to_global(_stop + DOOR)
	var rolled := minf(t / ROLL_SHARE, 1.0)
	_double.global_position = _from.lerp(door, smoothstep(0.0, 1.0, rolled))
	_double.scale = Vector2.ONE * lerpf(1.0, BOARDED_SCALE, rolled)
	_double.modulate.a = minf((1.0 - rolled) / FADE_SHARE, 1.0)
	var frame := steer(_first, door - _from, rolled)
	_double.region_rect.position.x = CarController.FRAME_SIZE.x * frame


## The door shuts behind the car, and the hut rises, turning back the way it was going, and stomps
## off, `t` of the swallow done, faster and faster, and fades, its dust with it: the dust flies from
## its feet till DUST_SHARE. Each stride's print shows once it has passed it, and stays.
func _stomp_off(t: float) -> void:
	var past := stomped(t)
	_hut.frame = leaving(t)
	_hut.modulate.a = fading(t)
	_place(_stop + _way * past)
	_dust.emitting = t > OFF_FROM and t < DUST_SHARE
	var strides := laid(past)
	_prints.modulate.a = 1.0 if strides > 0 else 0.0
	_prints.frame = maxi(strides - 1, 0)
