class_name PhantomBus
extends Legend
## The City's legend (docs/M6.md §3.3, Q2): a cold fog rolls over the road under a dusk veil, and a
## red double-decker glides out of it, half see-through, with no one at the wheel and pale faces at
## its windows. It stops beside the car and opens its doors on the dark. The car's double slides to
## them and shrinks into the bus, the doors shut, and the bus glides on and fades, leaving a ticket
## on the road. It keeps to the car's road, the tile axis nearest to the car's heading, coming from
## the end that its params' direction picks, and stops up-screen of the car, so that the car and its
## double draw over it. tools/art/legends/phantom_bus.gd draws its sheets with these constants.

## The bus's sheet: frames of FRAME px, DOORS of them for each of FACINGS, from shut to open, with
## the bus's ground centre at FOOT. A facing of its own for each, as a flip would light it from the
## right.
const FRAME := Vector2i(64, 56)
const DOORS := 3
const FACINGS: Array[Vector2] = [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]
const FOOT := Vector2i(32, 42)
## Its length and width, in tiles, and its height, in px.
const LENGTH := 0.6
const WIDTH := 0.25
const HEIGHT := 26
## Its lamps: how far apart, as a share of its width, and how high, in px.
const LAMP_SPREAD := 0.6
const LAMP_HEIGHT := 4.0
## The double's scale once it has boarded.
const BOARDED_SCALE := 0.3
## The shares of a beat that the doors take to open or shut, and that a fade takes.
const DOOR_SHARE := 0.25
const FADE_SHARE := 0.4
## Where the fog lies on the bus's way to its stop, as a share of the way.
const FOG_AT := 0.35

## Where it comes from, stops and goes to, and where its doors are, from the legend's origin.
var _from := Vector2.ZERO
var _stop := Vector2.ZERO
var _to := Vector2.ZERO
var _door := Vector2.ZERO
## Its frame with the doors shut, for its facing.
var _first := 0
var _taken := false
var _double: Sprite2D
## Where the double starts to board from, from the legend's origin.
var _boarding_from := Vector2.ZERO

@onready var _fog: CPUParticles2D = %Fog
@onready var _bus: Sprite2D = %Bus
@onready var _lamp_a: Sprite2D = %LampA
@onready var _lamp_b: Sprite2D = %LampB
@onready var _ticket: Sprite2D = %Ticket


static func duration(params: DisasterParams) -> float:
	return params.delay + Beats.total(Tuning.PHANTOM_BUS_BEATS)


## The way it drives: along the tile axis nearest to `heading`, the car's, toward the end that
## `direction` points to.
static func way(heading: Vector2, direction: Vector2) -> Vector2:
	var axis := road(heading)
	return axis if direction.dot(axis) >= 0.0 else -axis


## The tile axis nearest to `direction`, and RIGHT for none.
static func road(direction: Vector2) -> Vector2:
	if direction.is_zero_approx():
		return Vector2.RIGHT
	if absf(direction.x) >= absf(direction.y):
		return Vector2(signf(direction.x), 0.0)
	return Vector2(0.0, signf(direction.y))


## The tile axis across `forward`, a tile axis, that points down-screen: the long side that the
## viewer sees, with the doors.
static func side(forward: Vector2) -> Vector2:
	return Vector2(absf(forward.y), absf(forward.x))


## Its frame with the doors shut, facing `forward`, a tile axis.
static func first_frame(forward: Vector2) -> int:
	return DOORS * maxi(FACINGS.find(forward), 0)


## Its lamps, from its ground centre, facing `forward`, a tile axis: on the end that the viewer
## sees, its front as it comes toward the viewer and its back as it goes away.
static func lamps(forward: Vector2) -> Array[Vector2]:
	var shown := forward if forward.x + forward.y > 0.0 else -forward
	var across := side(forward) * WIDTH / 2.0 * LAMP_SPREAD
	var found: Array[Vector2] = []
	for k: float in [-1.0, 1.0]:
		var at := Iso.tile_to_world(shown * LENGTH / 2.0 + across * k)
		found.append(at - Vector2(0.0, LAMP_HEIGHT))
	return found


func play(params: DisasterParams) -> void:
	super(params)
	var car_heading := car.sim.forward() if car != null else params.direction
	var forward := way(car_heading, params.direction)
	var heading := Iso.tile_to_world(forward)
	_stop = Iso.tile_to_world(-side(forward) * Tuning.PHANTOM_BUS_GAP_TILES)
	_from = _stop - heading * Tuning.PHANTOM_BUS_APPROACH_TILES
	_to = _stop + heading * Tuning.PHANTOM_BUS_LEAVE_TILES
	_door = _stop + Iso.tile_to_world(side(forward) * WIDTH / 2.0)
	_first = first_frame(forward)
	_bus.frame = _first
	var spots := lamps(forward)
	_lamp_a.position = spots[0]
	_lamp_b.position = spots[1]
	_place(_from)
	_ticket.position = _door
	_fog.position = _from.lerp(_stop, FOG_AT)
	_fog.direction = heading.normalized()


func _beats() -> Array[float]:
	return Tuning.PHANTOM_BUS_BEATS


func _pose(beat: int, t: float) -> void:
	match beat:
		0:
			_fog.emitting = true
		1:
			_place(_from.lerp(_stop, 1.0 - (1.0 - t) * (1.0 - t)))
			_bus.modulate.a = Tuning.PHANTOM_BUS_ALPHA * minf(t / FADE_SHARE, 1.0)
		2:
			_bus.frame = _first + _doors(t / DOOR_SHARE)
			_board(t)
		3:
			_bus.frame = _first + _doors(1.0 - t / DOOR_SHARE)
			_place(_stop.lerp(_to, t * t))
			_bus.modulate.a = Tuning.PHANTOM_BUS_ALPHA * minf((1.0 - t) / FADE_SHARE, 1.0)
			_ticket.modulate.a = minf(t / FADE_SHARE, 1.0)
			_fog.emitting = false


## The frame of the doors, from shut to open, when they are `share` of the way open.
static func _doors(share: float) -> int:
	return clampi(floori(share * DOORS), 0, DOORS - 1)


## Puts the bus at `at`, from the legend's origin, on the stage or under the legend.
func _place(at: Vector2) -> void:
	_bus.global_position = to_global(at)


## The car's double slides from where the car stopped to the doors, `t` of the way, and shrinks and
## fades into them.
func _board(t: float) -> void:
	if not _taken:
		_taken = true
		_double = take_car()
		if _double != null:
			_boarding_from = to_local(_double.global_position)
	if _double == null:
		return
	_double.global_position = to_global(_boarding_from.lerp(_door, smoothstep(0.0, 1.0, t)))
	_double.scale = Vector2.ONE * lerpf(1.0, BOARDED_SCALE, t)
	_double.modulate.a = minf((1.0 - t) / FADE_SHARE, 1.0)
