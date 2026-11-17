class_name Chupacabra
extends Legend
## The Desert's third legend (POOLS_PLAN.md §5.4), from the goat-sucker of Puerto Rico, 1995: a
## grey, spined beast creeps out of the scrub, across the car's road and down the screen from it,
## slower and slower, and crouches by the car. It leaps onto the car's roof and perches there,
## hunched, and the car's colours drain to grey as grey dust flakes off it: the car's double fades,
## and the car's grey husk shows under it, in its frame and place. The beast turns, hops down and
## slinks off the way it came, faster and faster, and fades; the husk stays. No blood: only the
## colour goes (docs/M6.md Q8). It has no veil, so its red eyes are pixels of its sheet, not glows.
## Down-screen of the car, it sorts in front of it all the while. tools/art/legends/chupacabra.gd
## draws its sheets with these constants.

## The beast's frames: creeping, its near legs forward and then its far ones; crouched to spring;
## leaping, stretched out; and perched, hunched over what it drains.
enum Pose { CREEP_A, CREEP_B, CROUCH, LEAP, PERCH }

## The beast's sheet: frames of BEAST px, each standing on its bottom row, in profile facing the
## screen's right; flip_h faces it left.
const BEAST := Vector2i(48, 40)
## Where it perches on the car, from the car's ground point: a pixel down the screen, so that it
## sorts in front of the car, its feet ROOF_PX up, on the car's roof.
const PERCH := Vector2(0.0, 1.0)
const ROOF_PX := 10.0
## Its legs take turns once each STEP_TILES that it creeps.
const STEP_TILES := 0.15
## The shares: of the creep that it takes to show; of the pounce that it leaps in, and then perches;
## of the drain that the car's colours take to drain, the dust flaking off it; from which it hops
## down to where it crouched, once they have; from which it slinks off; and from which it fades.
const SHOW_SHARE := 0.3
const LEAP_SHARE := 0.6
const DRAIN_SHARE := 0.5
const HOP_FROM := 0.5
const SLINK_FROM := 0.65
const FADE_FROM := 0.7

## Where it creeps out from and slinks off to, and where it crouches, from the legend's origin, in
## px; and how many tiles it creeps between them.
var _far := Vector2.ZERO
var _by := Vector2.ZERO
var _creep_tiles := 0.0
var _taken := false
var _double: Sprite2D

@onready var _beast: Sprite2D = %Beast
@onready var _husk: Sprite2D = %Husk
@onready var _dust: CPUParticles2D = %Dust


static func duration(params: DisasterParams) -> float:
	return params.delay + Beats.total(Tuning.CHUPACABRA_BEATS)


## One tile across the road of a car heading `heading`, in tile space, down the screen, in px: the
## tile axis nearest to its heading is its road (PhantomBus.road()).
static func across(heading: Vector2) -> Vector2:
	return Iso.tile_to_world(PhantomBus.side(PhantomBus.road(heading)))


## How far across its road, down the screen, it creeps out from and slinks off to, in tiles from the
## car's ground point at `at`, in tile space, heading `heading`, on `buffer`'s road. A wrong turn
## can leave the car off the middle of the road ahead (Kelpie.to_middle()). Where it
## stopped up-screen of the middle, CHUPACABRA_FROM_TILES down-screen of the middle, so that the
## beast comes out of the scrub, not off the road; where down-screen of it, or off any road, as far
## from the car.
static func far(at: Vector2, heading: Vector2, buffer: RoadBuffer) -> float:
	var road := PhantomBus.road(heading)
	var middle := Kelpie.to_middle(at, road, buffer).dot(PhantomBus.side(road))
	return Tuning.CHUPACABRA_FROM_TILES + maxf(middle, 0.0)


## Its frame `walked` tiles into a creep: its near legs forward, then its far ones, in turn.
static func stride(walked: float) -> int:
	return Pose.CREEP_A if floori(walked / STEP_TILES) % 2 == 0 else Pose.CREEP_B


## How high its feet are over the straight way, `t` of a leap from the ground onto the car's roof
## done, in px: up to the roof, and CHUPACABRA_LEAP_PX higher still at the leap's middle.
static func arc(t: float) -> float:
	return ROOF_PX * t + 4.0 * Tuning.CHUPACABRA_LEAP_PX * t * (1.0 - t)


## What shows of it, `t` of the drain done: all, then less and less from FADE_FROM.
static func fading(t: float) -> float:
	return 1.0 - clampf((t - FADE_FROM) / (1.0 - FADE_FROM), 0.0, 1.0)


func play(params: DisasterParams) -> void:
	super(params)
	var heading := car.sim.forward() if car != null else params.direction
	var far_tiles := Tuning.CHUPACABRA_FROM_TILES
	if car != null:
		far_tiles = far(Iso.world_to_tile(params.origin_world), heading, car.sim.buffer)
	var way := across(heading)
	_far = way * far_tiles
	_by = way * Tuning.CHUPACABRA_BY_TILES
	_creep_tiles = far_tiles - Tuning.CHUPACABRA_BY_TILES
	_beast.flip_h = _far.x > 0.0
	_place(_far, 0.0)


func _beats() -> Array[float]:
	return Tuning.CHUPACABRA_BEATS


func _pose(beat: int, t: float) -> void:
	match beat:
		0:
			_creep_in(t)
		1:
			_beast.frame = Pose.CROUCH
		2:
			_pounce(t)
		3:
			_drain(t)
			_slink_off(t)


## Puts its foot `at`, from the legend's origin, where it sorts, and its feet `lift` px above it.
func _place(at: Vector2, lift: float) -> void:
	_beast.global_position = to_global(at)
	_beast.offset = Vector2(-BEAST.x / 2.0, -BEAST.y - lift)


## It creeps in from the scrub to where it crouches, `t` of the creep done, slower and slower,
## facing the way it goes, its legs taking turns, and shows as it comes.
func _creep_in(t: float) -> void:
	_beast.modulate.a = minf(t / SHOW_SHARE, 1.0)
	var eased := 1.0 - (1.0 - t) * (1.0 - t)
	_beast.frame = stride(eased * _creep_tiles)
	_place(_far.lerp(_by, eased), 0.0)


## It leaps onto the car's roof, `t` of the pounce done, in an arc, and perches there, hunched.
func _pounce(t: float) -> void:
	var leapt := minf(t / LEAP_SHARE, 1.0)
	_beast.frame = Pose.LEAP if leapt < 1.0 else Pose.PERCH
	_place(_by.lerp(PERCH, leapt), arc(leapt))


## The car's colours drain to grey, `t` of the drain done: its double takes its place, once, and
## fades by DRAIN_SHARE, bit by bit, over its grey husk, which shows in the double's frame and place
## from then on, and the dust flakes off it from its middle while it fades.
func _drain(t: float) -> void:
	if not _taken:
		_taken = true
		_double = take_car()
		if _double != null:
			_husk.global_position = _double.global_position
			_husk.frame = car.body_frame()
			_husk.modulate.a = 1.0
			_dust.position = to_local(_double.global_position) + WitchHex.car_middle()
	if _double == null:
		return
	var drained := minf(t / DRAIN_SHARE, 1.0)
	_double.modulate.a = 1.0 - drained
	_dust.emitting = drained < 1.0


## It stays perched till HOP_FROM, `t` of the drain done; then it turns and hops down to where it
## crouched, and from SLINK_FROM it slinks off the way it came, faster and faster, its legs taking
## turns. It fades from FADE_FROM to nothing.
func _slink_off(t: float) -> void:
	_beast.modulate.a = fading(t)
	if t < HOP_FROM:
		_beast.frame = Pose.PERCH
		_place(PERCH, ROOF_PX)
		return
	_beast.flip_h = _far.x < 0.0
	if t < SLINK_FROM:
		var down := (t - HOP_FROM) / (SLINK_FROM - HOP_FROM)
		_beast.frame = Pose.LEAP
		_place(PERCH.lerp(_by, down), arc(1.0 - down))
		return
	var off := (t - SLINK_FROM) / (1.0 - SLINK_FROM)
	var eased := off * off
	_beast.frame = stride(eased * _creep_tiles)
	_place(_by.lerp(_far, eased), 0.0)
