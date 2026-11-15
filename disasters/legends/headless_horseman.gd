class_name HeadlessHorseman
extends Legend
## Rural's third legend (POOLS_PLAN.md §5.4): the headless rider of Sleepy Hollow. Dusk falls,
## and a rider in a dark cloak, with no head above his collar, gallops along the road to the car on
## a black horse, the dust flying from its hooves, and halts in front of it. He raises a ball of
## pale ghost-fire, not a pumpkin (§5.4 Δ), and hurls it at the car. Pale flames run over the car,
## which pales to a ghost of itself, see-through and green, and fades as he wheels round and
## gallops off the way he came. His horse's hooves scorch the road behind him, and the hoofprints
## stay. Its one glow, the ghost-fire's, rises once and fades: it lights in his hand, flies in a
## shallow arc to the car and fades there, so its light rises at each point at most once (§5.6).
## There's no gore.
## tools/art/legends/headless_horseman.gd draws its sheets with these constants.

## His frames: galloping, his horse's legs stretched and then gathered; standing; raising the
## ghost-fire; and hurling it.
enum Pose { GALLOP_A, GALLOP_B, STAND, RAISE, HURL }
## The ghost-fire's frames: a ball of it, then its flames running over the car, more and more.
enum Fire { BALL, KINDLE_A, KINDLE_B, KINDLE_C }

## His sheet: frames of RIDER px, each standing on its bottom row, his horse facing the screen's
## right; flip_h faces it left. As he raises the ghost-fire, he holds it at the texel HAND px from
## his foot.
const RIDER := Vector2i(64, 64)
const HAND := Vector2i(10, -58)
## The ghost-fire's sheet: frames of FIRE px, centred on the ball, and on the car's middle as its
## flames run over the car. Its glow, glow.tres at GLOW_SCALE, lights where it is.
const FIRE := Vector2i(40, 40)
const GLOW_SCALE := 0.5
## The hoofprints' sheet: frames of PRINTS px, centred on the middle of the stretch of road that his
## horse's hooves scorch as he gallops off, PRINTS_TILES long from where he halted. It is drawn for
## a road along the tile x axis that he gallops off down the screen; flip_h and flip_v lay it along
## the others. Its frames show the first 1 to STRIDES of its strides, from where he halted, each a
## pair of prints.
const PRINTS := Vector2i(96, 48)
const PRINTS_TILES := 1.25
const STRIDES := 5
## His horse's legs stretch and gather once each STRIDE_TILES that he gallops.
const STRIDE_TILES := 0.4
## The shares: of the gallop that he takes to show; of the kindle that he takes to wheel round,
## that the flames take to run over the car, and that the car takes to pale to a ghost of itself,
## tinted GHOST, GHOST_ALPHA of it showing; and from which he, the flames, their glow and the ghost
## fade.
const SHOW_SHARE := 0.4
const WHEEL_SHARE := 0.2
const SPREAD_SHARE := 0.3
const GHOST_SHARE := 0.4
const GHOST := Color(0.8, 1.0, 0.9)
const GHOST_ALPHA := 0.6
const FADE_FROM := 0.6

## One tile ahead of the car along its road; where he gallops in from and off to, and where he
## halts, from the legend's origin; and where he holds the ghost-fire.
var _ahead := Vector2.ZERO
var _far := Vector2.ZERO
var _halt := Vector2.ZERO
var _held := Vector2.ZERO
## Whether he faces the screen's left as he gallops in.
var _left := false
var _taken := false
var _double: Sprite2D

@onready var _rider: Sprite2D = %Horseman
@onready var _fire: Sprite2D = %Fire
@onready var _glow: Sprite2D = %Glow
@onready var _dust: CPUParticles2D = %Dust
@onready var _prints: Sprite2D = %Prints


static func duration(params: DisasterParams) -> float:
	return params.delay + Beats.total(Tuning.HEADLESS_HORSEMAN_BEATS)


## One tile ahead of the car's ground point, the car heading `heading`, in tile space, along its
## road, the tile axis nearest to its heading, as the phantom bus finds it.
static func ahead(heading: Vector2) -> Vector2:
	return Iso.tile_to_world(PhantomBus.road(heading))


## Where he gallops in from and off to, from the car's ground point: HEADLESS_HORSEMAN_FROM_TILES
## ahead, on the road's middle.
static func far(heading: Vector2) -> Vector2:
	return ahead(heading) * Tuning.HEADLESS_HORSEMAN_FROM_TILES


## Where he halts in front of the car: HEADLESS_HORSEMAN_STOP_TILES ahead.
static func halt(heading: Vector2) -> Vector2:
	return ahead(heading) * Tuning.HEADLESS_HORSEMAN_STOP_TILES


## Whether he faces the screen's left as he gallops in, towards the car. He gallops off facing the
## other way.
static func faces_left(heading: Vector2) -> bool:
	return ahead(heading).x > 0.0


## How far he gallops in, and off, in tiles.
static func gallop_tiles() -> float:
	return Tuning.HEADLESS_HORSEMAN_FROM_TILES - Tuning.HEADLESS_HORSEMAN_STOP_TILES


## His frame `galloped` tiles into a gallop: his horse's legs stretched, then gathered, in turn.
static func stride(galloped: float) -> int:
	return Pose.GALLOP_A if floori(galloped / STRIDE_TILES) % 2 == 0 else Pose.GALLOP_B


## Where he holds the ghost-fire, from his foot, facing the screen's left or right: the middle of
## the texel HAND, mirrored with him.
static func hand(left: bool) -> Vector2:
	var centre := Vector2(HAND) + Vector2(0.5, 0.5)
	return Vector2(-centre.x if left else centre.x, centre.y)


## Where the ghost-fire is, from the car's ground point, `t` of the hurl done: on its way from
## `from` to the car's middle, HEADLESS_HORSEMAN_ARC_PX over the straight way at its middle.
static func flight(from: Vector2, t: float) -> Vector2:
	var arc := Tuning.HEADLESS_HORSEMAN_ARC_PX * 4.0 * t * (1.0 - t)
	return from.lerp(WitchHex.car_middle(), t) - Vector2(0.0, arc)


## The ghost-fire's frame `t` of the kindle done: its flames run over the car, more and more, and
## have run over all of it at SPREAD_SHARE.
static func kindled(t: float) -> int:
	var spread := floori(t / SPREAD_SHARE * (Fire.KINDLE_C - Fire.KINDLE_A))
	return mini(Fire.KINDLE_A + spread, Fire.KINDLE_C)


## Where the hoofprints' middle is, from the car's ground point: PRINTS_TILES / 2 on from where he
## halted, the way he gallops off.
static func prints_at(heading: Vector2) -> Vector2:
	return halt(heading) + ahead(heading) * (PRINTS_TILES / 2.0)


## How many strides of prints he has left, `past` tiles on from where he halted: each once he has
## passed its end.
static func laid(past: float) -> int:
	return clampi(floori(past / PRINTS_TILES * STRIDES), 0, STRIDES)


## What shows of him, the flames, their glow and the ghost, `t` of the kindle done: all, then less
## and less from FADE_FROM.
static func fading(t: float) -> float:
	return 1.0 - clampf((t - FADE_FROM) / (1.0 - FADE_FROM), 0.0, 1.0)


func _ready() -> void:
	super()
	_glow.scale = Vector2.ONE * GLOW_SCALE


func play(params: DisasterParams) -> void:
	super(params)
	var heading := car.sim.forward() if car != null else params.direction
	_ahead = ahead(heading)
	_far = far(heading)
	_halt = halt(heading)
	_left = faces_left(heading)
	_held = _halt + hand(_left)
	_rider.flip_h = _left
	_place(_far)
	_prints.position = prints_at(heading)
	_prints.flip_h = _ahead.x < 0.0
	_prints.flip_v = _ahead.y < 0.0


func _beats() -> Array[float]:
	return Tuning.HEADLESS_HORSEMAN_BEATS


func _pose(beat: int, t: float) -> void:
	match beat:
		0:
			_gallop_in(t)
		1:
			_raise(t)
		2:
			_hurl(t)
		3:
			_kindle(t)
			_gallop_off(t)


## Puts his foot `at`, from the legend's origin, wherever he stands, and the dust at his horse's
## hooves.
func _place(at: Vector2) -> void:
	_rider.global_position = to_global(at)
	_dust.position = at


## He gallops in to where he halts, `t` of the gallop done, slower and slower to a stop, and shows.
## The dust flies from his horse's hooves till he halts.
func _gallop_in(t: float) -> void:
	_rider.modulate.a = minf(t / SHOW_SHARE, 1.0)
	var eased := 1.0 - (1.0 - t) * (1.0 - t)
	_rider.frame = stride(eased * gallop_tiles())
	_place(_far.lerp(_halt, eased))
	_dust.emitting = t < 1.0


## He raises the ghost-fire, `t` of the raise done: a ball of it grows in his hand, and its glow
## lights.
func _raise(t: float) -> void:
	_rider.frame = Pose.RAISE
	_fire.frame = Fire.BALL
	_fire.position = _held
	_fire.scale = Vector2.ONE * t
	_fire.modulate.a = 1.0
	_glow.position = _held
	_glow.modulate.a = Tuning.HEADLESS_HORSEMAN_GLOW_ALPHA * t


## He hurls it at the car, `t` of the hurl done: it flies from his hand to the car's middle, its
## glow with it.
func _hurl(t: float) -> void:
	_rider.frame = Pose.HURL
	var at := flight(_held, t)
	_fire.frame = Fire.BALL
	_fire.position = at
	_fire.scale = Vector2.ONE
	_fire.modulate.a = 1.0
	_glow.position = at
	_glow.modulate.a = Tuning.HEADLESS_HORSEMAN_GLOW_ALPHA


## It kindles the car, `t` of the kindle done: the car's double takes its place, once, and its
## flames run over it as it pales to a ghost of itself; then they, their glow and the ghost fade.
func _kindle(t: float) -> void:
	if not _taken:
		_taken = true
		_double = take_car()
	var shown := fading(t)
	_fire.frame = kindled(t)
	_fire.position = WitchHex.car_middle()
	_fire.scale = Vector2.ONE
	_fire.modulate.a = shown
	_glow.position = WitchHex.car_middle()
	_glow.modulate.a = Tuning.HEADLESS_HORSEMAN_GLOW_ALPHA * shown
	if _double == null:
		return
	var paled := minf(t / GHOST_SHARE, 1.0)
	_double.self_modulate = Color.WHITE.lerp(GHOST, paled)
	_double.modulate.a = lerpf(1.0, GHOST_ALPHA, paled) * shown


## He wheels round and gallops off the way he came, `t` of the kindle done, faster and faster, and
## fades. The dust flies from his horse's hooves, which scorch the road behind him: each stride's
## prints show once he has passed them, and stay.
func _gallop_off(t: float) -> void:
	_rider.flip_h = not _left
	_rider.modulate.a = fading(t)
	var off := clampf((t - WHEEL_SHARE) / (1.0 - WHEEL_SHARE), 0.0, 1.0)
	var past := off * off * gallop_tiles()
	_rider.frame = stride(past) if off > 0.0 else Pose.STAND
	_place(_halt + _ahead * past)
	_dust.emitting = off > 0.0 and t < 1.0
	var strides := laid(past)
	_prints.modulate.a = 1.0 if strides > 0 else 0.0
	_prints.frame = maxi(strides - 1, 0)
