class_name Scarecrow
extends Legend
## Rural's second legend (docs/POOLS.md §5.4): a scarecrow stands by the road ahead and turns its
## head to the car. Crows rise from its arms, settle over the car, and carry it off low over the
## fields and out of sight. The scarecrow stays, its head turned after it. It has no veil and no
## glow: it plays in the light of the hour, and its crows add no light (§5.6).
## tools/art/legends/scarecrow.gd draws its sheets with these constants.

## Its sheet's frames: its head turned away, turned to the screen's right, and facing the viewer.
enum Head { AWAY, TURNED, FACING }

## Its sheet: frames of FRAME px, its foot at the foot of its pole. Its arms, a crossbar, are ARMS
## px above its foot at their middle, where its crows rise from.
const FRAME := Vector2i(48, 60)
const ARMS := Vector2(0.0, -36.0)
## The crow's sheet: CROW_FRAMES frames of CROW px, its wings up, level, down and level again, which
## each crow loops through as it flies. The crows hover a little over where they rose from, so their
## emitter settles ROOST px from the car's ground point for them to perch on its roof.
const CROW := Vector2i(14, 10)
const CROW_FRAMES := 4
const ROOST := Vector2(0.0, -10.0)
## The shares: of the turn that it takes to show, and by which its head has turned to the screen's
## side and then to face the viewer; and of the carry that the crows take to lift the car, from
## which its head turns after the car, and from which the car and the crows fade.
const SHOW_SHARE := 0.4
const TURNED_AT := 0.5
const FACING_AT := 0.8
const LIFT_SHARE := 0.2
const FOLLOW_AT := 0.3
const FADE_FROM := 0.6

## 1 if the crows carry the car off to the right of the screen, -1 to the left.
var _side := 1.0
## Where it stands, from the legend's origin.
var _stand := Vector2.ZERO
var _taken := false
var _double: Sprite2D
## Where the double stood, and its offset there.
var _from := Vector2.ZERO
var _rest := Vector2.ZERO

@onready var _figure: Sprite2D = %Figure
@onready var _crows: CPUParticles2D = %Crows


static func duration(params: DisasterParams) -> float:
	return params.delay + Beats.total(Tuning.SCARECROW_BEATS)


## Where it stands, from the car's ground point, the car heading `heading`, in tile space: by the
## road ahead, SCARECROW_AHEAD_TILES along the car's road, the tile axis nearest to its heading,
## and SCARECROW_SIDE_TILES up-screen of the road's middle, as the phantom bus finds them.
static func stand(heading: Vector2) -> Vector2:
	var forward := PhantomBus.road(heading)
	var across := PhantomBus.side(forward)
	return Iso.tile_to_world(
		forward * Tuning.SCARECROW_AHEAD_TILES - across * Tuning.SCARECROW_SIDE_TILES
	)


## Its head, `t` of the turn done: turned away, then to the screen's side, then facing the viewer.
static func head(t: float) -> Head:
	if t >= FACING_AT:
		return Head.FACING
	return Head.TURNED if t >= TURNED_AT else Head.AWAY


## Where the crows are, from the car's ground point, `t` of their flight done from its arms, at
## `arms`, to the car: they slow to a stop over its roof.
static func flock(arms: Vector2, t: float) -> Vector2:
	return arms.lerp(ROOST, 1.0 - (1.0 - t) * (1.0 - t))


## How far the crows have carried the car from where it stood, `t` of the carry done: faster and
## faster, to the side `to_side`, 1 for the right, and up the screen, over the fields.
static func carry(to_side: float, t: float) -> Vector2:
	return Vector2(to_side * Tuning.SCARECROW_CARRY_PX.x, Tuning.SCARECROW_CARRY_PX.y) * t * t


## How high the crows hold the car off the ground, in px, `t` of the carry done.
static func lift(t: float) -> float:
	return Tuning.SCARECROW_LIFT_PX * minf(t / LIFT_SHARE, 1.0)


func play(params: DisasterParams) -> void:
	super(params)
	var heading := car.sim.forward() if car != null else params.direction
	_stand = stand(heading)
	# The Mothman's rule, from the same direction.
	_side = Mothman.side(params.direction)
	_figure.global_position = to_global(_stand)
	# Its head turns to the screen's right in its sheet, so to the left, to the car, if it stands to
	# the right of the car.
	_figure.flip_h = _stand.x > 0.0
	_crows.position = _stand + ARMS


func _beats() -> Array[float]:
	return Tuning.SCARECROW_BEATS


func _pose(beat: int, t: float) -> void:
	match beat:
		0:
			_figure.modulate.a = minf(t / SHOW_SHARE, 1.0)
			_figure.frame = head(t)
		1:
			_crows.emitting = t < 1.0
		2:
			_crows.position = flock(_stand + ARMS, t)
		3:
			_carry(t)


## The crows lift the car and carry it off, faster and faster, and fade with it, `t` of the carry
## done. The double stays on the stage, so it sorts with the props by its foot, on the ground: only
## its offset rises. The scarecrow's head turns after it.
func _carry(t: float) -> void:
	if not _taken:
		_taken = true
		_double = take_car()
		if _double != null:
			_from = _double.global_position
			_rest = _double.offset
	var carried := carry(_side, t)
	var held := Vector2(0.0, -lift(t))
	var shown := 1.0 - clampf((t - FADE_FROM) / (1.0 - FADE_FROM), 0.0, 1.0)
	if _double != null:
		_double.global_position = _from + carried
		_double.offset = _rest + held
		_double.modulate.a = shown
	_crows.position = ROOST + carried + held
	_crows.modulate.a = shown
	if t >= FOLLOW_AT:
		_figure.frame = Head.TURNED
		_figure.flip_h = _side < 0.0
