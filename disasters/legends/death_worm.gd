class_name DeathWorm
extends Legend
## The Desert's legend (M6_PLAN.md §3.3, Q2): in the glare of the desert, the ground trembles, and
## ripples run through the sand to the car from where its direction points. A mound swells under
## the car and lifts it. A giant eyeless worm bursts up out of it in a spray of sand, under the
## car's double, and carries it up on its blunt head. Its head opens into a round mouth ringed with
## white teeth, and the double drops in and sinks down its throat. The mouth shuts, the swallow
## bulges its body as it goes down, and the worm dives back into the sand, leaving a crater where
## the car stood. The worm rises and dives, and the double sinks into its throat, by showing only
## the top rows of their frames (§5.4). It has no veil, so no glows (§5.5).
## tools/art/legends/death_worm.gd draws its sheets with these constants.

## The worm's sheet: FRAMES frames of WORM px, each standing on its bottom row: RISING, its head
## shut; OPEN, its mouth open; then, its mouth shut again, the swallow bulging its body: SHUT, just
## under its head, SWALLOWING, halfway down, and DOWN, low. It stands BEHIND px up-screen of the
## car's ground point, so that the double sorts in front of it, and shows its bottom row there.
const WORM := Vector2i(56, 96)
const FRAMES := 5
const RISING := 0
const OPEN := 1
const SHUT := 2
const SWALLOWING := 3
const DOWN := 4
const BEHIND := 1
## In rows from the top of the worm's frame: where the double's foot rests on its shut head, TIP;
## and the middle of its open mouth, MOUTH, where the double drops in. THROAT is the radii, in px,
## of the black throat inside its ring of teeth; under its front edge, LIP, the double is cut off as
## it sinks.
const TIP := 6
const MOUTH := 10
const THROAT := Vector2i(17, 6)
const LIP := MOUTH + THROAT.y
## The mound's sheet, centred on the car's ground point: swelling, then cracked open. The double
## rides MOUND_LIFT px up on it.
const MOUND := Vector2i(64, 24)
const MOUND_LIFT := 4.0
## The crater's sheet, centred on the car's ground point.
const CRATER := Vector2i(64, 32)
## The double's shudder on the mound: how far each way, in px, and how many times it moves.
const SHUDDER_PX := 1.0
const SHUDDER_STEPS := 6
## The shares of the eruption: that the worm takes to rise, with the double on its head, before its
## mouth opens; and from SWALLOW_FROM to SWALLOW_TO, when its mouth shuts, over which the double
## sinks into its throat; and that the sand sprays for. Of the dive: before which the swallow is
## halfway down, after which the worm goes under; and after which the sand sprays again.
const RISE_SHARE := 0.35
const SWALLOW_FROM := 0.55
const SWALLOW_TO := 0.85
const SPRAY_SHARE := 0.3
const DIVE_FROM := 0.3
const SPLASH_FROM := 0.8

var _trembled := false
var _burst := false
var _taken := false
var _double: Sprite2D
var _worm: Sprite2D

@onready var _burrow: CPUParticles2D = %Burrow
@onready var _mound: Sprite2D = %Mound
@onready var _spray: CPUParticles2D = %Spray
@onready var _crater: Sprite2D = %Crater


static func duration(params: DisasterParams) -> float:
	return params.delay + Beats.total(Tuning.DEATH_WORM_BEATS)


## Where the ripples start, in px from the car's ground point: DEATH_WORM_BURROW_TILES tiles away
## where `direction`, in tile space, points, or to the right in tile space for none.
static func burrow_from(direction: Vector2) -> Vector2:
	var toward := Vector2.RIGHT if direction.is_zero_approx() else direction.normalized()
	return Iso.tile_to_world(toward * Tuning.DEATH_WORM_BURROW_TILES)


## How many rows of its frame the worm shows `risen` of the way up, from 0 to 1.
static func rows(risen: float) -> int:
	return clampi(roundi(WORM.y * risen), 0, WORM.y)


func _ready() -> void:
	super()
	if standing.is_empty():
		push_error("%s: it needs a worm" % id)
		return
	_worm = standing[0]
	_worm.position = Vector2(0.0, -BEHIND)
	_show_worm(0)


func _beats() -> Array[float]:
	return Tuning.DEATH_WORM_BEATS


func _pose(beat: int, t: float) -> void:
	var beats := Tuning.DEATH_WORM_BEATS
	match beat:
		0:
			if not _trembled:
				_trembled = true
				_shake(Tuning.DEATH_WORM_TREMOR, beats[0] + beats[1])
			_burrow.position = burrow_from(_params.direction).lerp(Vector2.ZERO, t)
			_burrow.emitting = t < 1.0
		1:
			_burrow.emitting = false
			_take()
			var swell := 1.0 - (1.0 - t) * (1.0 - t)
			_mound.scale = Vector2.ONE * swell
			var shudder := 0.0
			if t < 1.0:
				shudder = SHUDDER_PX if floori(t * SHUDDER_STEPS) % 2 == 0 else -SHUDDER_PX
			_ride(MOUND_LIFT * swell, shudder)
		2:
			if not _burst:
				_burst = true
				_shake(Tuning.DEATH_WORM_BURST, beats[2])
			_erupt(t)
		3:
			_dive(t)
		4:
			_spray.emitting = false


## Shakes the camera for `seconds`, `share` of the params' intensity.
func _shake(share: float, seconds: float) -> void:
	if camera != null:
		camera.shake(share * _params.intensity, seconds)


## Takes the car's place with its double, once.
func _take() -> void:
	if not _taken:
		_taken = true
		_double = take_car()


## The worm bursts up out of the cracked mound, which becomes a crater, `t` of the eruption done:
## it carries the double up on its shut head, then opens its mouth, and the double sinks into it.
func _erupt(t: float) -> void:
	var risen := minf(t / RISE_SHARE, 1.0)
	_mound.scale = Vector2.ONE
	_mound.frame = 1
	_mound.modulate.a = 1.0 - risen
	_crater.modulate.a = risen
	_spray.emitting = t < SPRAY_SHARE
	var shown := rows(1.0 - (1.0 - risen) * (1.0 - risen))
	_show_worm(shown)
	if t < RISE_SHARE:
		_worm.frame = RISING
		_ride(maxf(MOUND_LIFT, shown - TIP))
		return
	_worm.frame = OPEN if t < SWALLOW_TO else SHUT
	var sunk := clampf((t - SWALLOW_FROM) / (SWALLOW_TO - SWALLOW_FROM), 0.0, 1.0)
	var depth := CarController.FOOT.y + LIP - MOUTH
	_ride(shown - MOUTH - depth * sunk * sunk, 0.0, shown - LIP)


## The swallow goes down the worm, and it dives back into the sand, `t` of the dive done.
func _dive(t: float) -> void:
	var dived := clampf((t - DIVE_FROM) / (1.0 - DIVE_FROM), 0.0, 1.0)
	_worm.frame = SWALLOWING if t < DIVE_FROM else DOWN
	_show_worm(rows(1.0 - dived * dived))
	_spray.emitting = t >= SPLASH_FROM and t < 1.0


## Shows the top `shown` rows of the worm's frame, standing on the car's ground point.
func _show_worm(shown: int) -> void:
	if _worm == null:
		return
	_worm.modulate.a = 1.0 if shown > 0 else 0.0
	_worm.region_rect = Rect2(0, 0, WORM.x * FRAMES, shown)
	_worm.offset = Vector2(-WORM.x / 2.0, BEHIND - shown)


## Stands the double with its foot `lift` px over the car's ground point and `shudder` px to its
## right, showing only what is over `lip` px over the ground point, all of it for a lip under it: it
## is gone once nothing is.
func _ride(lift: float, shudder := 0.0, lip := -INF) -> void:
	if _double == null:
		return
	var size := CarController.FRAME_SIZE
	var bottom := lift - (size.y - CarController.FOOT.y)
	var kept := size.y - clampi(roundi(maxf(lip, bottom) - bottom), 0, size.y)
	_double.offset = Vector2(shudder - CarController.FOOT.x, -CarController.FOOT.y - lift)
	_double.region_rect.size.y = kept
	_double.modulate.a = 1.0 if kept > 0 else 0.0
