class_name FrauHolle
extends Legend
## The Village's second legend (POOLS_PLAN.md §5.4), from the Grimms' tale: snow starts to fall
## round the car, and a stone well rises out of the ground by the road, beside it. The car tips over
## towards it, on its wheels on the well's side, then falls in: it hops over the rim into the well's
## mouth, turning over and over, smaller and smaller, as the snow settles on the well. The well
## stays, capped with snow. It rises by showing only the top rows of its frame, as the kelpie's
## horse does. The car's double stays where the car stopped, as the fairy ring's does, and its
## offset carries it: so it sorts there, in front of the well, which stands up-screen of it. It has
## no veil and no glow: it plays in the light of the hour (§5.6). tools/art/legends/frau_holle.gd
## draws its sheet with these constants.

## The well's frames: bare stone as it rises, dusted with snow, and capped with it.
enum Cap { BARE, DUSTED, CAPPED }

## The well's sheet: frames of WELL px, each standing on its bottom row, and the middle of its
## mouth, in px from its foot, where the car falls in.
const WELL := Vector2i(56, 60)
const MOUTH := Vector2(0.0, -25.0)
## Points of the car's double, in px from its ground point in its frame: the one that it tips over
## on, low on the well's side, for a well to the screen's right, mirrored for the left; and its
## middle, which it turns and shrinks about as it falls.
const PIVOT := Vector2(14.0, 8.0)
const MIDDLE := Vector2(CarController.FRAME_SIZE) / 2.0 - Vector2(CarController.FOOT)
## The shares of the fall: that the car takes to hop into the well's mouth, from which the snow
## dusts the well, and from which it caps it. How small the car is as it's gone.
const ARRIVE_SHARE := 0.6
const DUSTED_FROM := 0.3
const CAPPED_FROM := 0.7
const FALLEN_SCALE := 0.1

## Where the well stands, from the legend's origin, and which way the car tips: 1 for the screen's
## right, -1 for its left.
var _well_at := Vector2.ZERO
var _side := 1.0
var _taken := false
var _double: Sprite2D
## Where the double stood as it took the car's place, in the World.
var _from := Vector2.ZERO

@onready var _well: Sprite2D = %Well
@onready var _snow: CPUParticles2D = %Snow


static func duration(params: DisasterParams) -> float:
	return params.delay + Beats.total(Tuning.FRAU_HOLLE_BEATS)


## Where the well stands, from the car's ground point, the car heading `heading`, in tile space:
## beside the car, FRAU_HOLLE_SIDE_TILES up-screen of the middle of its road, the tile axis nearest
## to its heading.
static func well(heading: Vector2) -> Vector2:
	return Iso.tile_to_world(
		-PhantomBus.side(PhantomBus.road(heading)) * Tuning.FRAU_HOLLE_SIDE_TILES
	)


## How many rows of its frame the well shows, `risen` of the way out of the ground, from 0 to 1.
static func rows(risen: float) -> int:
	return clampi(roundi(WELL.y * risen), 0, WELL.y)


## The well's frame, `t` of the fall done: the snow settles on it as the car falls.
static func cap(t: float) -> int:
	if t >= CAPPED_FROM:
		return Cap.CAPPED
	return Cap.DUSTED if t >= DUSTED_FROM else Cap.BARE


func play(params: DisasterParams) -> void:
	super(params)
	_well_at = well(car.sim.forward() if car != null else params.direction)
	_side = -1.0 if _well_at.x < 0.0 else 1.0
	_well.global_position = to_global(_well_at)


func _beats() -> Array[float]:
	return Tuning.FRAU_HOLLE_BEATS


func _pose(beat: int, t: float) -> void:
	match beat:
		0:
			_snow.emitting = true
		1:
			_well.frame = Cap.BARE
			_show_well(rows(1.0 - (1.0 - t) * (1.0 - t)))
		2:
			_tip(t)
		3:
			_fall(t)


## The car tips over towards the well, on its pivot, faster and faster, `t` of the tip done: its
## double takes its place, once.
func _tip(t: float) -> void:
	if not _taken:
		_taken = true
		_double = take_car()
		if _double != null:
			_from = _double.global_position
	if _double == null:
		return
	var pivot := _pivot()
	_hold(pivot, _from + pivot, _side * Tuning.FRAU_HOLLE_TIP * t * t, 1.0)


## The car falls into the well, `t` of the fall done: its middle hops from where the tip left it
## over the rim into the mouth, then it sinks there, turning on and shrinking till it's gone. The
## snow settles on the well, and stops.
func _fall(t: float) -> void:
	_well.frame = cap(t)
	_snow.emitting = t < 1.0
	if _double == null:
		return
	var pivot := _pivot()
	var tipped := _side * Tuning.FRAU_HOLLE_TIP
	var start := _from + pivot + (MIDDLE - pivot).rotated(tipped)
	var hop := minf(t / ARRIVE_SHARE, 1.0)
	var lift := Vector2(0.0, -Tuning.FRAU_HOLLE_HOP_PX * 4.0 * hop * (1.0 - hop))
	var at := start.lerp(_well.global_position + MOUTH, hop) + lift
	var angle := tipped + _side * Tuning.FRAU_HOLLE_TUMBLE * t
	_hold(MIDDLE, at, angle, lerpf(1.0, FALLEN_SCALE, t))
	_double.modulate.a = 1.0 if t < 1.0 else 0.0


## The pivot, mirrored for a well to the screen's left.
func _pivot() -> Vector2:
	return Vector2(PIVOT.x * _side, PIVOT.y)


## Turns the double by `angle` and scales it by `size` so that `point` of it, in px from its ground
## point in its frame, shows at `at` in the World, to within the half pixel each way, turned and
## scaled, that the snap to pixels rounds its offset by. Its node stays where the car stopped, so
## it sorts there. The stage is neither turned nor scaled.
func _hold(point: Vector2, at: Vector2, angle: float, size: float) -> void:
	_double.rotation = angle
	_double.scale = Vector2.ONE * size
	_double.offset = (at - _from).rotated(-angle) / size - point - Vector2(CarController.FOOT)


## Shows the top `shown` rows of the well's frame, standing on its foot.
func _show_well(shown: int) -> void:
	_well.modulate.a = 1.0 if shown > 0 else 0.0
	_well.region_rect = Rect2(0, 0, WELL.x * Cap.size(), shown)
	_well.offset = Vector2(-WELL.x / 2.0, -shown)
