class_name CameraRig
extends Camera2D
## Follows the car (IMPLEMENTATION_PLAN.md M2.5): smoothly, a little ahead along its heading, and,
## on a portrait screen, with the car in the lower part. The zoom shows about VISIBLE_TILES tiles
## across the screen's shorter side, in the steps of CAMERA_ZOOMS, which keep pixels crisp. A shake
## (M3.2) moves the view by its offset, which leaves the position and the smoothing alone. On an
## arrival, the target eases to the arrival's view (ENDGAME_PLAN.md §5.8), and the zoom stays.

var car: CarController

## The shake's offset at its start, in screen pixels; its length and its age, in seconds.
var _shake_px := 0.0
var _shake_seconds := 0.0
var _shake_time := 0.0
## What the arrival's view shows besides the car, in World pixels, and how far the target has eased
## to it, from 0 to 1; -1 without an arrival.
var _arrival_rect := Rect2()
var _pan := -1.0


func _ready() -> void:
	get_viewport().size_changed.connect(_on_size_changed)
	_on_size_changed()


func _physics_process(delta: float) -> void:
	if car != null:
		if _pan >= 0.0:
			_pan = minf(_pan + Tuning.ARRIVAL_PAN_RATE * delta, 1.0)
		position = position.lerp(target(), 1.0 - exp(-Tuning.CAMERA_SMOOTHING * delta))
	if _shake_seconds > 0.0:
		_shake_time += delta
		_update_shake()


## Shakes the view for `seconds`, by up to `intensity` × SHAKE_PX screen pixels, fading out. It
## replaces a shake that is still going. No randomness: the offset follows two sine waves.
func shake(intensity: float, seconds: float) -> void:
	_shake_px = intensity * Tuning.SHAKE_PX
	_shake_seconds = seconds
	_shake_time = 0.0
	_update_shake()


## Ends a shake at once.
func stop_shake() -> void:
	_shake_seconds = 0.0
	offset = Vector2.ZERO


## Eases the target, over 1 / ARRIVAL_PAN_RATE seconds, from the car to the arrival's view, which
## shows `rect`, in World pixels, as well as the car, until end_arrival() (ENDGAME_PLAN.md §5.8).
func arrive(rect: Rect2) -> void:
	_arrival_rect = rect
	_pan = 0.0


## Follows the car again, as before arrive().
func end_arrival() -> void:
	_pan = -1.0


## Where the camera heads: ahead of the car, and above it on a portrait screen; on an arrival, on
## the way to the arrival's view.
func target() -> Vector2:
	var ahead := Iso.tile_to_world(car.sim.forward()).normalized() * Tuning.LOOKAHEAD_PX
	var size := get_viewport_rect().size
	var bias := Tuning.PORTRAIT_BIAS * size.y / zoom.y if size.y > size.x else 0.0
	var on_car := car.position + ahead + Vector2(0.0, -bias)
	if _pan < 0.0:
		return on_car
	return on_car.lerp(_arrival_view(), smoothstep(0.0, 1.0, _pan))


## The arrival's view: centred on the arrival's rect and the car's body together, but always with
## the body, and ARRIVAL_MARGIN_PX round it, in view. A car that came slowly stops short on the
## pier, too far from the rect to show both.
func _arrival_view() -> Vector2:
	var body := car.body_rect().grow(Tuning.ARRIVAL_MARGIN_PX)
	var half := get_viewport_rect().size / zoom * 0.5
	return _arrival_rect.merge(body).get_center().clamp(body.end - half, body.position + half)


## Jumps to target(), without smoothing.
func snap_to_target() -> void:
	position = target()


## The step of CAMERA_ZOOMS nearest, by ratio, to showing VISIBLE_TILES tile steps across the
## shorter side of a viewport of `size`.
static func zoom_for(size: Vector2) -> float:
	var tile_step := Iso.tile_to_world(Vector2.RIGHT).length()
	var ideal := minf(size.x, size.y) / (Tuning.VISIBLE_TILES * tile_step)
	var best := Tuning.CAMERA_ZOOMS[0]
	for step: float in Tuning.CAMERA_ZOOMS:
		if absf(log(step / ideal)) < absf(log(best / ideal)):
			best = step
	return best


func _update_shake() -> void:
	if _shake_time >= _shake_seconds:
		stop_shake()
		return
	var fade := 1.0 - _shake_time / _shake_seconds
	var wave := Vector2(
		sin(_shake_time * Tuning.SHAKE_FREQ_X), cos(_shake_time * Tuning.SHAKE_FREQ_Y)
	)
	# The offset is in world pixels, which the zoom scales.
	offset = wave * _shake_px * fade / zoom.x


func _on_size_changed() -> void:
	var step := zoom_for(get_viewport_rect().size)
	zoom = Vector2(step, step)
