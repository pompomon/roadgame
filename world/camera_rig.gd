class_name CameraRig
extends Camera2D
## Follows the car (IMPLEMENTATION_PLAN.md M2.5): smoothly, a little ahead along its heading, and,
## on a portrait screen, with the car in the lower part. The zoom shows about VISIBLE_TILES tiles
## across the screen's shorter side, in the steps of CAMERA_ZOOMS, which keep pixels crisp. A shake
## (M3.2) moves the view by its offset, which leaves the position and the smoothing alone.

var car: CarController

## The shake's offset at its start, in screen pixels; its length and its age, in seconds.
var _shake_px := 0.0
var _shake_seconds := 0.0
var _shake_time := 0.0


func _ready() -> void:
	get_viewport().size_changed.connect(_on_size_changed)
	_on_size_changed()


func _physics_process(delta: float) -> void:
	if car != null:
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


## Where the camera heads: ahead of the car, and above it on a portrait screen.
func target() -> Vector2:
	var ahead := Iso.tile_to_world(car.sim.forward()).normalized() * Tuning.LOOKAHEAD_PX
	var size := get_viewport_rect().size
	var bias := Tuning.PORTRAIT_BIAS * size.y / zoom.y if size.y > size.x else 0.0
	return car.position + ahead + Vector2(0.0, -bias)


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
