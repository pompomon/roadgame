class_name Kelpie
extends Legend
## The Meadows' second legend (POOLS_PLAN.md §5.4): a dark pool wells up by the road ahead, and a
## black horse with weed in its mane rises out of it in a splash. It stands, dripping, and looks at
## the car, which turns off the road and rolls up to its side, as a rider mounts. It plunges back
## into the pool with the car in another splash, and the water closes over them. The still pool
## stays, and waterweed that the splash threw onto the road. The horse rises and sinks, and the car
## sinks, by showing only the top rows of their frames, as the death worm does (docs/M6.md §5.4).
## It has no veil and no glow: it plays in the light of the hour (§5.6).
## tools/art/legends/kelpie.gd draws its sheets with these constants.

## The horse's frames: its head high as it rises, lowered to the car as it waits, and plunging head
## first.
enum Pose { RISING, WAITING, PLUNGING }

## The horse's sheet: frames of HORSE px, each standing on its bottom row, the water line, for it
## stands in its pool to its knees. It faces the screen's right. It stands STAND px from the pool's
## middle, a little up-screen, so that the car's double sorts in front of it at MOUNT, by its side.
const HORSE := Vector2i(56, 48)
const STAND := Vector2(0.0, -3.0)
const MOUNT := Vector2(0.0, 2.0)
## The pool's sheet, centred on its middle: its still water, then a ring that spreads from where the
## horse stands, RINGS[k] of the deep water's radii across in frame k + 1.
const POOL := Vector2i(64, 32)
const RINGS: Array[float] = [0.35, 0.6, 0.85]
## The weed's sheet, centred where it lies.
const WEED := Vector2i(32, 16)
## The car's water line, in px under its ground point: under the lowest pixel of each of its frames,
## so that the car shows whole until it sinks.
const WATERLINE := 8
## Where the water drips from as the horse waits, from its foot: its belly.
const DRIPS := Vector2(0.0, -12.0)
## The shares of the rise: that the pool takes to well up, after which the horse rises out of it;
## and of the horse's rise, that the water splashes for. Of the plunge: that the water splashes for,
## that the horse and the car take to sink, and from which the weed shows. How many rings spread one
## after another as the horse rises, and as it plunges.
const POOL_SHARE := 0.3
const SPLASH_SHARE := 0.4
const PLUNGE_SPLASH_SHARE := 0.25
const SINK_SHARE := 0.85
const WEED_FROM := 0.3
const RISE_RINGS := 1
const PLUNGE_RINGS := 2

## Where the pool lies, and the road beside it, from the legend's origin.
var _pool_at := Vector2.ZERO
var _beside := Vector2.ZERO
var _taken := false
var _double: Sprite2D
## Where the double stood as it took the car's place, in the World, and the frame it faced in.
var _from := Vector2.ZERO
var _first := 0

@onready var _horse: Sprite2D = %Horse
@onready var _pool: Sprite2D = %Pool
@onready var _weed: Sprite2D = %Weed
@onready var _splash: CPUParticles2D = %Splash
@onready var _drips: CPUParticles2D = %Drips


static func duration(params: DisasterParams) -> float:
	return params.delay + Beats.total(Tuning.KELPIE_BEATS)


## Where the pool lies, from the car's ground point, the car heading `heading`, in tile space: by
## the road ahead, KELPIE_AHEAD_TILES along the car's road, the tile axis nearest to its heading,
## and KELPIE_SIDE_TILES up-screen of the road's middle, as the scarecrow stands.
static func pool(heading: Vector2) -> Vector2:
	var forward := PhantomBus.road(heading)
	var across := PhantomBus.side(forward)
	return Iso.tile_to_world(
		forward * Tuning.KELPIE_AHEAD_TILES - across * Tuning.KELPIE_SIDE_TILES
	)


## The middle of the road beside the pool, from the car's ground point, the car heading `heading`:
## where the car turns off the road for the pool, and where the weed lies.
static func beside(heading: Vector2) -> Vector2:
	return Iso.tile_to_world(PhantomBus.road(heading) * Tuning.KELPIE_AHEAD_TILES)


## Where the car is, `t` of its roll done from `from`, where it stopped, to `to`, the horse's side:
## on a curve that sets off toward `by`, the road beside the pool, and turns off it, slow at each
## end.
static func roll(from: Vector2, by: Vector2, to: Vector2, t: float) -> Vector2:
	var s := smoothstep(0.0, 1.0, t)
	return from.lerp(by, s).lerp(by.lerp(to, s), s)


## The car's frame, `t` of its roll done from `from` by `by` to `to`: it turns from `first`, the
## frame it stopped in, to face the way it rolls, so that it turns off the road for the pool and
## ends facing into it. Frame k faces k steps of TAU / CarController.FRAMES clockwise from up the
## screen.
static func steer(first: int, from: Vector2, by: Vector2, to: Vector2, t: float) -> int:
	var s := smoothstep(0.0, 1.0, t)
	var rolling := (by - from).lerp(to - by, s)
	var step := TAU / CarController.FRAMES
	var angle := lerp_angle(first * step, atan2(rolling.x, -rolling.y), s)
	return posmod(roundi(angle / step), CarController.FRAMES)


## How many rows of its frame the horse shows, `risen` of the way out of the water, from 0 to 1.
static func rows(risen: float) -> int:
	return clampi(roundi(HORSE.y * risen), 0, HORSE.y)


## The pool's frame, `t` of `spreads` rings done, which spread one after another: still water before
## and after them.
static func ripple(t: float, spreads: int) -> int:
	if t <= 0.0 or t >= 1.0:
		return 0
	return 1 + floori(t * spreads * RINGS.size()) % RINGS.size()


func play(params: DisasterParams) -> void:
	super(params)
	var heading := car.sim.forward() if car != null else params.direction
	_pool_at = pool(heading)
	_beside = beside(heading)
	_pool.position = _pool_at
	_weed.position = _beside
	_splash.position = _pool_at + STAND
	_drips.position = _pool_at + STAND + DRIPS
	_horse.global_position = to_global(_pool_at + STAND)
	# It faces the screen's right in its sheet, so to the left, to the car, if its pool is to the
	# right of the car.
	_horse.flip_h = _pool_at.x > 0.0


func _beats() -> Array[float]:
	return Tuning.KELPIE_BEATS


func _pose(beat: int, t: float) -> void:
	match beat:
		0:
			_rise(t)
		1:
			_horse.frame = Pose.WAITING
			_drips.emitting = t < 1.0
		2:
			_mount(t)
		3:
			_plunge(t)


## The pool wells up, and the horse rises out of it in a splash, `t` of the rise done.
func _rise(t: float) -> void:
	var welled := minf(t / POOL_SHARE, 1.0)
	_pool.scale = Vector2.ONE * (1.0 - (1.0 - welled) * (1.0 - welled))
	var risen := clampf((t - POOL_SHARE) / (1.0 - POOL_SHARE), 0.0, 1.0)
	_horse.frame = Pose.RISING
	_show_horse(rows(1.0 - (1.0 - risen) * (1.0 - risen)))
	_splash.emitting = risen > 0.0 and risen < SPLASH_SHARE
	_pool.frame = ripple(risen, RISE_RINGS)


## The car turns off the road and rolls up to the horse's side, `t` of the mount done: its double
## takes its place, once.
func _mount(t: float) -> void:
	if not _taken:
		_taken = true
		_double = take_car()
		if _double != null:
			_from = _double.global_position
			_first = roundi(_double.region_rect.position.x / CarController.FRAME_SIZE.x)
	if _double == null:
		return
	var by := to_global(_beside)
	var to := to_global(_pool_at + MOUNT)
	_double.global_position = roll(_from, by, to, t)
	var frame := steer(_first, _from, by, to, t)
	_double.region_rect.position.x = CarController.FRAME_SIZE.x * frame


## The horse plunges back into the pool with the car in a splash, `t` of the plunge done: they sink,
## faster and faster, as the rings spread, and the water closes over them. The weed that the splash
## threw onto the road shows.
func _plunge(t: float) -> void:
	_horse.frame = Pose.PLUNGING
	var sunk := minf(t / SINK_SHARE, 1.0)
	sunk *= sunk
	_show_horse(rows(1.0 - sunk))
	_sink(sunk)
	_splash.emitting = t < PLUNGE_SPLASH_SHARE
	_pool.frame = ripple(t, PLUNGE_RINGS)
	_weed.modulate.a = clampf((t - WEED_FROM) / (1.0 - WEED_FROM), 0.0, 1.0)


## Shows the top `shown` rows of the horse's frame, standing on its water line.
func _show_horse(shown: int) -> void:
	_horse.modulate.a = 1.0 if shown > 0 else 0.0
	_horse.region_rect = Rect2(0, 0, HORSE.x * Pose.size(), shown)
	_horse.offset = Vector2(-HORSE.x / 2.0, -shown)


## Sinks the double `sunk` of the way under its water line, from 0 to 1: it moves down, and shows
## only what is over the line. It is gone once nothing is.
func _sink(sunk: float) -> void:
	if _double == null:
		return
	var depth := CarController.FOOT.y + WATERLINE
	var down := roundi(depth * sunk)
	_double.offset = Vector2(-CarController.FOOT.x, down - CarController.FOOT.y)
	_double.region_rect.size.y = depth - down
	_double.modulate.a = 1.0 if down < depth else 0.0
