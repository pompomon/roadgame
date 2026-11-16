class_name GrimReaper
extends Legend
## The City's third legend (POOLS_PLAN.md §5.4): Death of the plague years. Dusk falls, and a
## hooded figure with a scythe steps out at the roadside ahead and beckons the car with one bony
## hand. The road opens into a grave in front of the car: a crack, then a pit, its earth heaped
## beside it. The car rolls forward into the grave and sinks, as the earth falls in on it, and a
## gravestone rises at the grave's head. The Reaper fades away; the filled grave and its gravestone
## stay. Its scythe never moves, and never swings at the car (docs/M6.md Q8): in every frame its
## blade points away from the car. The grave lies flat under the legend, along the car's road, on
## its middle wherever across it the car stopped; the car's double rolls into it from where the car
## stopped, turning to face its way. It sinks into it by showing only the top rows of its frame, cut
## off at the pit's near lip, as the death worm's throat cuts it; the gravestone rises by showing
## only the top rows of its frame, as Frau Holle's well does. It has a dusk veil and no glow (§5.6).
## tools/art/legends/grim_reaper.gd draws its sheets with these constants.

## The Reaper's frames: stepping, on one foot and then the other; standing; beckoning, its fingers
## held out; and curling them in.
enum Pose { STEP_A, STEP_B, STAND, BECKON, CURL }
## The grave's frames: the road cracked, ajar, open with its earth heaped beside it, and filled in.
enum Dug { CRACKED, AJAR, OPEN, FILLED }

## The Reaper's sheet: frames of REAPER px, each standing on its bottom row, facing the viewer, its
## scythe on the screen's left and the hand that beckons on its right, towards the grave: mirrored
## for a grave to its left.
const REAPER := Vector2i(56, 68)
## The grave's sheet: frames of GRAVE px, centred on the middle of its pit, for a grave along the
## tile x axis, and mirrored for one along the tile y axis. GRAVE_TILES is its pit's length along
## the road and its width across it; HEAP_TILES, how far its heap of earth reaches past the pit's
## side up the screen, from and to, in tiles; HEAP_ALONG, how long the heap is, as a share of the
## pit's length; and HEAP_PX, how high it is.
const GRAVE := Vector2i(96, 60)
const GRAVE_TILES := Vector2(0.6, 0.52)
const HEAP_TILES := Vector2(0.03, 0.15)
const HEAP_ALONG := 0.6
const HEAP_PX := 5.0
## The earth falls in from EARTH_PX below the middle of the pit's side up the screen: under the
## heap, just past the foot of the pit's far wall, over its dark depths. The clods are the heap's
## browns, so they show only once they are over the depths, and they go as the grave fills.
const EARTH_PX := 7.0
## Under LIP px below the grave's middle, the car's double is cut off as it sinks: the highest that
## the pit's near lip comes across the car, so that nothing of the double shows over the road in
## front of the pit. Each frame of the car ends above it, so the whole double shows till it sinks.
const LIP := 8
## The gravestone's sheet: one frame of STONE px, standing on its bottom row at the grave's head,
## STONE_OUT tiles past the end of its pit up the screen.
const STONE := Vector2i(20, 28)
const STONE_OUT := 0.04
## The shares: of the step that it takes to show, and how many steps it takes; how many times it
## beckons; of the opening from which the grave is ajar, and open; and of the sink that the car
## takes to roll into the grave's middle, by which it has sunk out of sight and the grave is
## filled, from which the gravestone rises, and from which the Reaper fades.
const SHOW_SHARE := 0.5
const STEPS := 4
const BECKONS := 2
const AJAR_FROM := 0.3
const OPEN_FROM := 0.6
const ROLL_SHARE := 0.35
const SUNK_AT := 0.8
const STONE_FROM := 0.5
const FADE_FROM := 0.6
## How far the double sinks, in px: till none of it shows.
const SINK_PX := LIP + CarController.FOOT.y

## Where the grave, the Reaper, the gravestone and the earth are, from the legend's origin; where
## the Reaper steps out from; and 1 if the grave is to the screen's right of the Reaper, -1 to its
## left.
var _grave_at := Vector2.ZERO
var _stand_at := Vector2.ZERO
var _step_from := Vector2.ZERO
var _side := 1.0
var _taken := false
var _double: Sprite2D
## Where the double stood as it took the car's place, in the World, and the frame it showed.
var _from := Vector2.ZERO
var _first := 0

@onready var _reaper: Sprite2D = %Reaper
@onready var _grave: Sprite2D = %Grave
@onready var _stone: Sprite2D = %Stone
@onready var _earth: CPUParticles2D = %Earth


static func duration(params: DisasterParams) -> float:
	return params.delay + Beats.total(Tuning.GRIM_REAPER_BEATS)


## Where the grave's middle is, from the car's ground point, the car heading `heading`, in tile
## space, and the middle of the road ahead `middle` from it, in tiles, as Kelpie.to_middle() finds
## it: on the road's middle, GRIM_REAPER_AHEAD_TILES ahead along its road, the tile axis nearest to
## its heading.
static func grave(heading: Vector2, middle := Vector2.ZERO) -> Vector2:
	return _beside(heading, middle, 0.0)


## Whether the grave lies along the tile y axis, so that its sheet is mirrored.
static func mirrored(heading: Vector2) -> bool:
	return absf(PhantomBus.road(heading).y) > 0.5


## Where the Reaper stands, from the car's ground point, `middle` as for grave(): beside the grave's
## middle, GRIM_REAPER_SIDE_TILES up-screen of the road's middle, or of the car, if it stopped
## further up the screen than that. So the car is on the grave's side of it, and its double rolls
## into the grave on that side too, away from the scythe.
static func stand(heading: Vector2, middle := Vector2.ZERO) -> Vector2:
	return _beside(heading, _higher(heading, middle), Tuning.GRIM_REAPER_SIDE_TILES)


## Where it steps out from: GRIM_REAPER_STEP_TILES farther off the road.
static func step_from(heading: Vector2, middle := Vector2.ZERO) -> Vector2:
	var out := Tuning.GRIM_REAPER_SIDE_TILES + Tuning.GRIM_REAPER_STEP_TILES
	return _beside(heading, _higher(heading, middle), out)


## 1 if the grave is to the screen's right of where the Reaper stands, -1 to its left, wherever
## across the road the car stopped: the Reaper stands up-screen of the grave's middle.
static func side(heading: Vector2) -> float:
	return 1.0 if grave(heading).x >= stand(heading).x else -1.0


## Where the gravestone stands, from the car's ground point: at the grave's head, the end of its pit
## up the screen.
static func head(heading: Vector2, middle := Vector2.ZERO) -> Vector2:
	var up_road := -PhantomBus.road(heading).abs()
	var out := up_road * (GRAVE_TILES.x / 2.0 + STONE_OUT)
	return grave(heading, middle) + Iso.tile_to_world(out)


## Where the earth falls in from, from the car's ground point: EARTH_PX below the middle of the
## pit's side up the screen, under the heap.
static func earth(heading: Vector2, middle := Vector2.ZERO) -> Vector2:
	return _beside(heading, middle, GRAVE_TILES.y / 2.0) + Vector2(0.0, EARTH_PX)


## How many rows of its frame the car's double shows, sunk `sunk` px into the grave.
static func kept(sunk: int) -> int:
	return clampi(LIP + CarController.FOOT.y - sunk, 0, CarController.FRAME_SIZE.y)


## How many rows of its frame the gravestone shows, `risen` of the way out of the ground.
static func stone_rows(risen: float) -> int:
	return clampi(roundi(STONE.y * risen), 0, STONE.y)


## The Reaper's frame, `t` of its step done: a step on each foot in turn, then it stands.
static func stride(t: float) -> int:
	if t >= 1.0:
		return Pose.STAND
	return Pose.STEP_A if floori(t * STEPS) % 2 == 0 else Pose.STEP_B


## Its frame, `t` of the beckon done: its fingers held out, then curled in, BECKONS times, and held
## out at the end.
static func beckon(t: float) -> int:
	return Pose.CURL if t < 1.0 and fposmod(t * BECKONS, 1.0) >= 0.5 else Pose.BECKON


## The grave's frame, `t` of the opening done.
static func dug(t: float) -> int:
	if t >= OPEN_FROM:
		return Dug.OPEN
	return Dug.AJAR if t >= AJAR_FROM else Dug.CRACKED


## A point beside the grave's middle, `out` tiles up-screen of `from`, from the car's ground point,
## in tiles: of the road's middle, or of where else across it.
static func _beside(heading: Vector2, from: Vector2, out: float) -> Vector2:
	var forward := PhantomBus.road(heading)
	var across := PhantomBus.side(forward)
	return Iso.tile_to_world(from + forward * Tuning.GRIM_REAPER_AHEAD_TILES - across * out)


## Across the road from the car's ground point, in tiles, to the road's middle, `middle` from it,
## or to the car itself, if it stopped further up the screen.
static func _higher(heading: Vector2, middle: Vector2) -> Vector2:
	var up := -PhantomBus.side(PhantomBus.road(heading))
	return up * maxf(middle.dot(up), 0.0)


func play(params: DisasterParams) -> void:
	super(params)
	var heading := car.sim.forward() if car != null else params.direction
	# A wrong turn can leave the car off its road's middle, even in the next cell across: the grave
	# opens on the road all the same, and the car rolls into it from where it stopped.
	var middle := Vector2.ZERO
	if car != null:
		var at := Iso.world_to_tile(params.origin_world)
		middle = Kelpie.to_middle(at, PhantomBus.road(heading), car.sim.buffer)
	_grave_at = grave(heading, middle)
	_stand_at = stand(heading, middle)
	_step_from = step_from(heading, middle)
	_side = side(heading)
	_grave.position = _grave_at
	_grave.flip_h = mirrored(heading)
	_reaper.flip_h = _side < 0.0
	_reaper.global_position = to_global(_step_from)
	_stone.global_position = to_global(head(heading, middle))
	var earth_at := earth(heading, middle)
	_earth.position = earth_at
	_earth.direction = (_grave_at - earth_at).normalized()


func _beats() -> Array[float]:
	return Tuning.GRIM_REAPER_BEATS


func _pose(beat: int, t: float) -> void:
	match beat:
		0:
			_step(t)
		1:
			_reaper.frame = beckon(t)
		2:
			_reaper.frame = Pose.BECKON
			_grave.modulate.a = 1.0
			_grave.frame = dug(t)
		3:
			_sink(t)


## It steps out to its place at the roadside, `t` of the step done, slowing to a stop, and shows.
func _step(t: float) -> void:
	_reaper.modulate.a = minf(t / SHOW_SHARE, 1.0)
	_reaper.frame = stride(t)
	var eased := 1.0 - (1.0 - t) * (1.0 - t)
	_reaper.global_position = to_global(_step_from.lerp(_stand_at, eased))


## The car rolls into the grave and sinks, `t` of the sink done: its double takes its place, once,
## rolls to the grave's middle, turning to face it, and sinks, faster and faster, as the earth falls
## in on it. The grave fills, and the earth goes, the gravestone rises, and the Reaper lowers its
## hand and fades away.
func _sink(t: float) -> void:
	if not _taken:
		_taken = true
		_double = take_car()
		if _double != null:
			_from = _double.global_position
			_first = roundi(_double.region_rect.position.x / CarController.FRAME_SIZE.x)
	_reaper.frame = Pose.STAND
	_reaper.modulate.a = 1.0 - clampf((t - FADE_FROM) / (1.0 - FADE_FROM), 0.0, 1.0)
	var filled := t >= SUNK_AT
	_earth.emitting = t >= ROLL_SHARE and not filled
	# The clods still falling would fall on over the mound, which is in their browns: they have
	# filled the grave.
	_earth.visible = not filled
	_grave.frame = Dug.FILLED if filled else Dug.OPEN
	var risen := clampf((t - STONE_FROM) / (1.0 - STONE_FROM), 0.0, 1.0)
	_show_stone(stone_rows(1.0 - (1.0 - risen) * (1.0 - risen)))
	if _double == null:
		return
	var rolled := minf(t / ROLL_SHARE, 1.0)
	var sinking := clampf((t - ROLL_SHARE) / (SUNK_AT - ROLL_SHARE), 0.0, 1.0)
	var to := to_global(_grave_at)
	_double.global_position = _from.lerp(to, smoothstep(0.0, 1.0, rolled))
	# It rolls straight, so it turns from the frame that it stopped in to face the way to the grave,
	# as the kelpie's mount turns it: a wrong turn can leave it turned off its road, or off its
	# middle.
	var frame := Kelpie.steer(_first, _from, _from, to, rolled)
	_double.region_rect.position.x = CarController.FRAME_SIZE.x * frame
	var sunk := roundi(SINK_PX * sinking * sinking)
	var shown := kept(sunk)
	_double.offset = Vector2(-CarController.FOOT.x, sunk - CarController.FOOT.y)
	_double.region_rect.size.y = shown
	_double.modulate.a = 1.0 if shown > 0 else 0.0


## Shows the top `shown` rows of the gravestone's frame, standing on its foot.
func _show_stone(shown: int) -> void:
	_stone.modulate.a = 1.0 if shown > 0 else 0.0
	_stone.region_rect = Rect2(0, 0, STONE.x, shown)
	_stone.offset = Vector2(-STONE.x / 2.0, -shown)
