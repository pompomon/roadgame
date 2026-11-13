class_name ViewVeil
extends Polygon2D
## A square over the view that multiplies what is drawn under it by its self_modulate: a legend's
## veil (M6_PLAN.md §5.5) and the night's (DAYNIGHT_PLAN.md §5.5). It covers the widest view at the
## smallest zoom. It is built once: its polygon, colour and offset never change, since on the Web
## each redraw of a Polygon2D after its first raises WebGL errors (M2_PLAN.md §5.7). It shows and
## hides by modulate.a, which needs no redraw, and waits transparent, which the canvas skips: a
## multiply ignores the alpha it draws with (M6_PLAN.md P10).

## A veil's physics step comes after those at the default priority, 0, such as the camera's, so
## that it follows the view of the same frame.
const PHYSICS_PRIORITY := 1


func _init() -> void:
	var half := Tuning.VEIL_HALF_SIZE
	polygon = PackedVector2Array(
		[Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half)]
	)
	var multiply := CanvasItemMaterial.new()
	multiply.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	material = multiply
	z_index = Tuning.VEIL_Z
	z_as_relative = false
	modulate.a = 0.0


## Centres the veil on `p_camera`'s view, shake included.
func follow(p_camera: Camera2D) -> void:
	global_position = p_camera.global_position + p_camera.offset


## Multiplies what is under the veil by `p_light`. White changes nothing, so the veil then hides,
## and isn't drawn.
func shade(p_light: Color) -> void:
	if p_light == Color.WHITE:
		modulate.a = 0.0
		return
	self_modulate = p_light
	modulate.a = 1.0
