class_name FairyRing
extends Legend
## The Meadows' legend (M6_PLAN.md §3.3, Q2): dusk falls on the meadow, and ten pale toadstools
## sprout one by one in a ring round the car. A sickly glow swells over each in turn and stays lit.
## Pairs of yellow eyes open one by one in the grass beyond the ring and watch, and sparkles circle
## inside it. The car's double is made to dance: it spins through its headings, faster and faster,
## shrinks to a point and is gone. The eyes close together, and the ring stays, glowing. Its glows
## light one by one and stay lit, and the eyes close once, at the end, so each point that they light
## rises once and falls at most once (§5.6). tools/art/legends/fairy_ring.gd draws its sheets with
## these constants.

## A toadstool's sheet: frames as it grows, a button, half grown, then full. TOADSTOOLS of them
## stand on an ellipse of RING px radii about the car's ground point.
const TOADSTOOL := Vector2i(10, 10)
const TOADSTOOL_FRAMES := 3
const TOADSTOOLS := 10
const RING := Vector2(44.0, 22.0)
## Each toadstool's glow, glow.tres at GLOW_SCALE, swells about GLOW_AT px from its foot, its cap.
const GLOW_AT := Vector2(0.0, -6.0)
const GLOW_SCALE := 0.5
## A pair of eyes' sheet: frames as they open, a slit, half open, then open. Pairs watch from
## WATCHERS, in px from the car's ground point and in the order they open: beyond the ring, at its
## sides and behind it.
const EYES := Vector2i(14, 6)
const EYE_FRAMES := 3
const WATCHERS: Array[Vector2] = [
	Vector2(-86.0, -6.0),
	Vector2(-64.0, -34.0),
	Vector2(-22.0, -48.0),
	Vector2(30.0, -46.0),
	Vector2(70.0, -28.0),
	Vector2(90.0, 4.0),
]
## The shares: of the sprout that each toadstool takes to grow, and of the glow beat that each glow
## takes to swell and each pair of eyes to open, the rest of the beat spread over the waits between
## them; of the dance that the double takes to shrink and go, at its end; and of the hold that the
## eyes take to close, at its start.
const GROW_SHARE := 0.4
const SWELL_SHARE := 0.3
const OPEN_SHARE := 0.4
const SHRINK_SHARE := 0.35
const CLOSE_SHARE := 0.5
## The double's turns as it dances, faster and faster, and its scale once it's gone.
const TURNS := 2
const GONE_SCALE := 0.05

## The toadstools' glows, in the order they swell, and the pairs of eyes, in the order they open.
var _glows: Array[Sprite2D] = []
var _eyes: Array[Sprite2D] = []
var _taken := false
var _double: Sprite2D
## The double's frame when it took the car's place.
var _first := 0

@onready var _sparkles: CPUParticles2D = %Sparkles


static func duration(params: DisasterParams) -> float:
	return params.delay + Beats.total(Tuning.FAIRY_RING_BEATS)


## Where toadstool `k` stands, from the car's ground point: the first half a step clockwise from
## the top of the ring, and each next one a step on, clockwise.
static func toadstool_at(k: int) -> Vector2:
	return Vector2.from_angle(TAU * (k + 0.5) / TOADSTOOLS - PI / 2.0) * RING


## When `part` of `count` parts starts its turn in a beat, as a share of the beat: each takes
## `share` of it, and the rest spreads their starts evenly, the first's at 0 and the last's so that
## it ends with the beat.
static func turn_start(part: int, count: int, share: float) -> float:
	return (1.0 - share) * part / maxi(count - 1, 1)


## How far `part` of `count` parts is through its turn, `t` of the beat done, from 0 to 1.
static func in_turn(t: float, part: int, count: int, share: float) -> float:
	return clampf((t - turn_start(part, count, share)) / share, 0.0, 1.0)


func _ready() -> void:
	super()
	if standing.is_empty():
		push_error("%s: it needs a toadstool" % id)
		return
	standing = _copies(standing[0], TOADSTOOLS)
	_glows = _copies(%Glow as Sprite2D, TOADSTOOLS)
	_eyes = _copies(%Eyes as Sprite2D, WATCHERS.size())
	for k: int in TOADSTOOLS:
		standing[k].position = toadstool_at(k)
		_glows[k].position = toadstool_at(k) + GLOW_AT
	for k: int in WATCHERS.size():
		_eyes[k].position = WATCHERS[k]


## The toadstools' glows, in the order they swell.
func glows() -> Array[Sprite2D]:
	return _glows.duplicate()


## The pairs of eyes, in the order they open.
func eyes() -> Array[Sprite2D]:
	return _eyes.duplicate()


func _beats() -> Array[float]:
	return Tuning.FAIRY_RING_BEATS


func _pose(beat: int, t: float) -> void:
	match beat:
		0:
			for k: int in standing.size():
				_show(standing[k], in_turn(t, k, standing.size(), GROW_SHARE))
		1:
			for k: int in _glows.size():
				var swell := in_turn(t, k, _glows.size(), SWELL_SHARE)
				_glows[k].scale = Vector2.ONE * GLOW_SCALE * swell
				_glows[k].modulate.a = Tuning.FAIRY_RING_GLOW_ALPHA * swell
			for k: int in _eyes.size():
				_show(_eyes[k], in_turn(t, k, _eyes.size(), OPEN_SHARE))
			_sparkles.emitting = true
		2:
			_dance(t)
		3:
			for eye: Sprite2D in _eyes:
				_show(eye, 1.0 - minf(t / CLOSE_SHARE, 1.0))
			_sparkles.emitting = false


## `part` and `count` - 1 copies of it, beside it under the legend.
func _copies(part: Sprite2D, count: int) -> Array[Sprite2D]:
	var made: Array[Sprite2D] = [part]
	for k: int in range(1, count):
		var copy := part.duplicate() as Sprite2D
		copy.unique_name_in_owner = false
		copy.name = "%s%d" % [part.name, k + 1]
		add_child(copy)
		made.append(copy)
	return made


## Shows `part` `share` of the way through its sheet's frames: hidden at 0, then frame by frame.
static func _show(part: Sprite2D, share: float) -> void:
	part.modulate.a = 1.0 if share > 0.0 else 0.0
	part.frame = mini(floori(share * part.hframes), part.hframes - 1)


## The car's double spins where the car stopped, through its headings, faster and faster, `t` of
## the dance done, then shrinks to a point about its middle and is gone. Its foot stays where the
## car stopped, so it sorts there.
func _dance(t: float) -> void:
	if not _taken:
		_taken = true
		_double = take_car()
		if _double != null:
			_first = roundi(_double.region_rect.position.x / CarController.FRAME_SIZE.x)
	if _double == null:
		return
	var size := Vector2(CarController.FRAME_SIZE)
	var turned := roundi(TURNS * CarController.FRAMES * t * t)
	_double.region_rect.position.x = size.x * posmod(_first + turned, CarController.FRAMES)
	var going := clampf((t - 1.0 + SHRINK_SHARE) / SHRINK_SHARE, 0.0, 1.0)
	var shrink := lerpf(1.0, GONE_SCALE, going)
	# Its offset keeps its middle, half its frame from its corner, where the car's was.
	var middle := size / 2.0 - Vector2(CarController.FOOT)
	_double.scale = Vector2.ONE * shrink
	_double.offset = middle / shrink - size / 2.0
	_double.modulate.a = 1.0 - going
