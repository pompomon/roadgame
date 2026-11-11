@abstract class_name Legend
extends DisasterBase
## A disaster from a legend (M6_PLAN.md §5.3): beats on one clock (Beats), a veil that darkens the
## world, glows that light it (§5.5), standing parts that sort with the props, and a double that
## takes the car's place (§5.4).
##
## Nothing shows before the delay in its params: each part waits in the scene, hidden by its
## modulate's alpha or its scale. play() moves the standing parts onto the stage, still hidden.
## Polygons and particles stay under the legend, and a polygon's visible, color, polygon and offset
## never change: each change would redraw it (M2_PLAN.md §5.7, S6). A legend's script poses its
## beats in _pose(), and has a `static func duration(params: DisasterParams) -> float`, its delay
## and Beats.total() of its beats. Legend steps them in _physics_process(), which a legend leaves
## alone; a legend's _ready() calls super() first.

enum Veil { NONE, DUSK, NIGHT }

## Its physics steps come after those at the default priority, 0, such as the camera's, so the veil
## follows the view of the same frame: main.tscn steps World, with the legend, before the camera.
const PHYSICS_PRIORITY := 1

## How dark the world gets while it plays (Q5).
@export var veil_kind := Veil.NONE
## Sprites that stand up: play() moves them onto the stage, where they sort with the props and the
## car by their feet (S2).
@export var standing: Array[Sprite2D] = []

var _params: DisasterParams
var _clock: Beats
## How many beats there are.
var _count := 0
## What play() and take_car() put on the stage, which _exit_tree() frees.
var _staged: Array[Sprite2D] = []
var _veil: Polygon2D
var _shown := false
var _done := false


func _ready() -> void:
	process_physics_priority = PHYSICS_PRIORITY
	if veil_kind != Veil.NONE:
		_veil = _made_veil()
		add_child(_veil)


func play(params: DisasterParams) -> void:
	_params = params
	position = params.origin_world
	var lengths := _beats()
	if lengths.is_empty():
		push_error("%s: a legend needs a beat" % id)
		lengths = [0.0]
	_count = lengths.size()
	_clock = Beats.new(lengths, params.delay)
	for particles: Node in find_children("*", "CPUParticles2D", true, false):
		apply_params(particles as CPUParticles2D, params)
	if stage != null:
		for part: Sprite2D in standing:
			part.reparent(stage)
			_staged.append(part)


## What play() and take_car() have put on the stage.
func staged() -> Array[Sprite2D]:
	return _staged.duplicate()


## Hides the car and stands its double where the car stopped, facing as it did, in the same frame,
## so that no frame shows both or neither (§5.4). Null without a car.
func take_car() -> Sprite2D:
	if car == null:
		return null
	var made := car.double()
	if stage != null:
		stage.add_child(made)
		_staged.append(made)
	else:
		add_child(made)
	made.global_position = car.global_position
	car.modulate.a = 0.0
	return made


## The beats' lengths, in seconds: Tuning.<ID>_BEATS.
@abstract func _beats() -> Array[float]

## Shows `beat` with `t` of it done, from 0 to 1. A beat's first pose may come with any t below 1,
## and its end, t 1, comes once, before the next beat's first pose, even when a frame steps over the
## beat (S7).
@abstract func _pose(beat: int, t: float) -> void


func _physics_process(delta: float) -> void:
	_follow_camera()
	if _clock == null or _done:
		return
	_clock.advance(delta)
	var now := _clock.index()
	if now < 0:
		return
	if not _shown:
		_shown = true
		if _veil != null:
			_veil.modulate.a = 1.0
	for beat: int in _clock.ended():
		_pose(beat, 1.0)
	if now < _count:
		_pose(now, _clock.progress(now))
	if _veil != null:
		_veil.self_modulate = Color.WHITE.lerp(_veil_color(), _clock.progress(0))
	if _clock.done():
		_done = true
		if car != null and car.modulate.a > 0.0:
			push_error("%s: the car still shows at its end" % id)
		finished.emit()


func _exit_tree() -> void:
	for k: int in _staged.size():
		if is_instance_valid(_staged[k]):
			_staged[k].free()
	_staged.clear()


## A white square that multiplies what is under it by its colour. It waits transparent, which the
## canvas skips: a multiply ignores the alpha it draws with (P10).
func _made_veil() -> Polygon2D:
	var half := Tuning.VEIL_HALF_SIZE
	var made := Polygon2D.new()
	made.name = "Veil"
	made.polygon = PackedVector2Array(
		[Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half)]
	)
	var multiply := CanvasItemMaterial.new()
	multiply.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	made.material = multiply
	made.z_index = Tuning.VEIL_Z
	made.z_as_relative = false
	made.modulate.a = 0.0
	return made


func _veil_color() -> Color:
	return Tuning.VEIL_DUSK if veil_kind == Veil.DUSK else Tuning.VEIL_NIGHT


## Centres the veil on the view, also after the end: the camera may still shake.
func _follow_camera() -> void:
	if _veil != null and camera != null:
		_veil.global_position = camera.global_position + camera.offset
