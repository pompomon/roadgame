class_name Shadows
extends CanvasGroup
## The shadows of the props and the car (DAYNIGHT_PLAN.md §5.11): a black copy of each one's frame,
## laid on the ground away from the sun by day and the moon by night. They are drawn as one group,
## at the clock's shadow alpha, so where two overlap the ground is no darker than under one. They
## lie on the ground, the road and the skid marks, under the props, the car and the disasters.
## PropScatter adds and removes the props' shadows with their sprites, and shows their frames.
## WorldRenderer refreshes them every frame: they turn with the clock's shadow, and the car's
## follows the car. A prop's shadow stays where it falls from, and its kind's material lays it, so
## that as the clock turns two materials change, not every sprite (C20). Only sprites' transforms,
## frames and modulate change, so nothing is redrawn on the Web (M2_PLAN.md §5.7). The legends and
## the set pieces cast none.

const LAY := preload("res://world/shadows.gdshader")
## The slope on screen of a wall along the tile y axis, as PropDef.Shadow.WALL's are.
const WALL_SLOPE := -float(Iso.TILE_H) / Iso.TILE_W
## The longest the clock's shadow is, in screen pixels a pixel of height: SHADOW_LONGEST pixels of
## ground, at most WIDTH_PX / HEIGHT_PX screen pixels each.
const FALL_MOST := Tuning.SHADOW_LONGEST * Iso.WIDTH_PX / Iso.HEIGHT_PX
## The longest a pixel of a frame's width lies in a shadow: an upright prop's lies a pixel of
## ground across it, at most 1, and a wall's along the wall, and with it as it leans.
const UPRIGHT_ACROSS_MOST := 1.0
const WALL_ACROSS_MOST := sqrt(1.0 + WALL_SLOPE * WALL_SLOPE) + absf(WALL_SLOPE) * FALL_MOST


## The shadow of a prop, or of the car.
class Cast:
	extends RefCounted
	var sprite: Sprite2D
	var def: PropDef
	## Where the prop's foot is, and how the car is scaled and turned.
	var foot := Vector2.ZERO
	var basis := Transform2D.IDENTITY


## Its sprites are its own parts, so internal children (C20).
var _pool := PropPool.new(self, Node.INTERNAL_MODE_BACK)
var _casts: Dictionary[Cast, bool] = {}
## The clock's shadow that the casts lie along.
var _fall := Vector2.ZERO
## The car's shadow, once there is a car.
var _car_cast: Cast
## The materials that lay upright props' shadows and walls'.
var _upright := _material()
var _wall := _material()


func _init() -> void:
	_lay()


## Lays a shadow of `def`'s first frame for a prop whose foot is at `foot`, or returns null for a
## prop that casts none.
func add(def: PropDef, foot: Vector2) -> Cast:
	var cast := _cast(def, foot)
	if cast == null:
		return null
	cast.sprite.material = _upright if def.shadow == PropDef.Shadow.UPRIGHT else _wall
	cast.sprite.transform = Transform2D(0.0, _from(cast))
	# Godot culls a sprite, and fits the group around its sprites, by the frame as it stands, which
	# the material lays beyond: so by its reach (renderer_canvas_cull.cpp:192–262 and :333).
	RenderingServer.canvas_item_set_custom_rect(cast.sprite.get_canvas_item(), true, reach(def))
	return cast


## Takes away a shadow that add() laid.
func remove(cast: Cast) -> void:
	if cast != null and _casts.erase(cast):
		_pool.release(cast.sprite)


## How many shadows add() has laid that remove() hasn't taken away.
func count() -> int:
	return _casts.size()


## Shows the shadows that `cycle` shows, and `car`'s, which may be null.
func refresh(cycle: DayCycle, car: CarController) -> void:
	var alpha := 0.0 if cycle == null else cycle.shadow_alpha
	self_modulate.a = alpha
	visible = alpha > 0.0
	if not visible:
		return
	if cycle.shadow != _fall:
		_fall = cycle.shadow
		_lay()
	_follow(car)


## The car's shadow, or null before the first car.
func car_cast() -> Cast:
	return _car_cast


## How `cast` lays its frame on the ground: a point `p` of the frame, from the sprite's position as
## its offset is, lies at laid(cast) * p.
static func laid(cast: Cast) -> Transform2D:
	var lay := cast.sprite.material as ShaderMaterial
	if lay == null:
		return cast.sprite.transform
	var lay_x: Vector2 = lay.get_shader_parameter(&"lay_x")
	var lay_y: Vector2 = lay.get_shader_parameter(&"lay_y")
	return cast.sprite.transform * Transform2D(lay_x, lay_y, Vector2.ZERO)


## As far from where it falls from as a shadow of `def`'s frame reaches, at any hour.
static func reach(def: PropDef) -> Rect2:
	var frame := _frame(def)
	var across := UPRIGHT_ACROSS_MOST
	if def.shadow == PropDef.Shadow.WALL:
		across = WALL_ACROSS_MOST
	var wide := maxf(absf(frame.position.x), absf(frame.end.x))
	var tall := maxf(absf(frame.position.y), absf(frame.end.y))
	var most := across * wide + FALL_MOST * tall
	return Rect2(-most, -most, 2.0 * most, 2.0 * most)


## Lays the car's shadow under the car, in its frame, scale and turn. A car that is hidden, or that
## a legend has made clear (M6_PLAN.md §5.4), casts as faint a shadow as it shows.
func _follow(car: CarController) -> void:
	var shows := car != null and car.is_visible_in_tree() and car.modulate.a > 0.0
	if not shows:
		if _car_cast != null:
			_car_cast.sprite.hide()
		return
	if _car_cast == null or _car_cast.def.texture != car.body_texture():
		remove(_car_cast)
		_car_cast = _cast(_car_def(car), car.position)
		# Laid here, as it turns and is scaled, and measured by its frame: it may be a prop's sprite.
		_car_cast.sprite.material = null
		RenderingServer.canvas_item_set_custom_rect(_car_cast.sprite.get_canvas_item(), false)
	_car_cast.sprite.show()
	_car_cast.foot = car.position
	_car_cast.basis = car.transform
	_car_cast.basis.origin = Vector2.ZERO
	_car_cast.sprite.frame = car.body_frame()
	_car_cast.sprite.self_modulate.a = car.modulate.a
	var lay := Transform2D(_across(_fall), -_fall, _from(_car_cast))
	_car_cast.sprite.transform = lay * _car_cast.basis


## A black copy of `def`'s first frame for a shadow from `foot`, without its lay, or null for a
## prop that casts none.
func _cast(def: PropDef, foot: Vector2) -> Cast:
	if def.shadow == PropDef.Shadow.NONE:
		return null
	var cast := Cast.new()
	cast.def = def
	cast.foot = foot
	cast.sprite = _pool.acquire(def)
	var frame := _frame(def)
	cast.sprite.region_rect.size.y = frame.size.y
	cast.sprite.offset = frame.position
	cast.sprite.self_modulate = Color.BLACK
	_casts[cast] = true
	return cast


## Lays the props' shadows along the clock's shadow. Each kind's material lays its frames, so
## turning them all sets two materials' parameters (C20).
func _lay() -> void:
	_upright.set_shader_parameter(&"lay_x", _across(_fall))
	_upright.set_shader_parameter(&"lay_y", -_fall)
	_wall.set_shader_parameter(&"lay_x", Vector2(1.0, WALL_SLOPE) + WALL_SLOPE * _fall)
	_wall.set_shader_parameter(&"lay_y", -_fall)


## Where `cast`'s shadow falls from: shadow_rise above its foot.
static func _from(cast: Cast) -> Vector2:
	return cast.foot - Vector2(0.0, cast.def.shadow_rise)


## The rows of `def`'s frame that cast its shadow, from where it falls from: an upright prop's
## above that, and all of a wall's.
static func _frame(def: PropDef) -> Rect2:
	var rows := def.foot.y - def.shadow_rise
	if def.shadow == PropDef.Shadow.WALL:
		rows = def.region.size.y
	var corner := Vector2(-def.foot.x, def.shadow_rise - def.foot.y)
	return Rect2(corner, Vector2(def.region.size.x, rows))


static func _material() -> ShaderMaterial:
	var lay := ShaderMaterial.new()
	lay.shader = LAY
	return lay


## Where an upright prop's frame lays its width in its shadow `fall`: across the shadow, on the
## ground, so it is as wide whichever way the light comes from. As the light is on the far side,
## the frame's left side stays on the left: like a flat sprite's, the shadow is the frame turned
## upside down, never round.
static func _across(fall: Vector2) -> Vector2:
	var away := Iso.world_to_tile(fall).normalized()
	if away == Vector2.ZERO:
		return Vector2.RIGHT
	return Iso.tile_to_world(Vector2(away.y, -away.x)) / Iso.WIDTH_PX


## A PropDef of the car's sheet, so that its shadow is laid as an upright prop's.
static func _car_def(car: CarController) -> PropDef:
	var def := PropDef.new()
	def.id = &"car"
	def.texture = car.body_texture()
	def.region = Rect2i(Vector2i.ZERO, CarController.FRAME_SIZE)
	def.frames = CarController.WRECK_FRAME + 1
	def.foot = CarController.FOOT
	return def
