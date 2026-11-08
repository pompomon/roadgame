class_name CameraRig
extends Camera2D
## Follows the car (IMPLEMENTATION_PLAN.md M2.5): smoothly, a little ahead along its heading, and,
## on a portrait screen, with the car in the lower part. The zoom shows about VISIBLE_TILES tiles
## across the screen's shorter side, in the steps of CAMERA_ZOOMS, which keep pixels crisp.

var car: CarController


func _ready() -> void:
	get_viewport().size_changed.connect(_on_size_changed)
	_on_size_changed()


func _physics_process(delta: float) -> void:
	if car != null:
		position = position.lerp(target(), 1.0 - exp(-Tuning.CAMERA_SMOOTHING * delta))


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


func _on_size_changed() -> void:
	var step := zoom_for(get_viewport_rect().size)
	zoom = Vector2(step, step)
