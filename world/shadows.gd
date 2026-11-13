class_name Shadows
extends CanvasGroup
## The shadows of the props and the car (DAYNIGHT_PLAN.md §5.11): a black copy of each one's frame,
## laid on the ground away from the sun by day and the moon by night. They are drawn as one group,
## at the clock's shadow alpha, so where two overlap the ground is no darker than under one. They
## lie on the ground, the road and the skid marks, under the props, the car and the disasters.
## PropScatter adds and removes the props' shadows with their sprites, and shows their frames.
## WorldRenderer refreshes them every frame: they turn with the clock's shadow, and the car's
## follows the car. Only sprites' transforms, frames and modulate change, so nothing is redrawn on
## the Web (M2_PLAN.md §5.7). The legends and the set pieces cast none.

## The slope on screen of a wall along the tile y axis, as PropDef.Shadow.WALL's are.
const WALL_SLOPE := -float(Iso.TILE_H) / Iso.TILE_W


## The shadow of a prop, or of the car.
class Cast:
	extends RefCounted
	var sprite: Sprite2D
	var def: PropDef
	## Where the prop's foot is, and how the car is scaled and turned.
	var foot := Vector2.ZERO
	var basis := Transform2D.IDENTITY


var _pool := PropPool.new(self)
var _casts: Dictionary[Cast, bool] = {}
## The clock's shadow that the casts lie along.
var _fall := Vector2.ZERO
## The car's shadow, once there is a car.
var _car_cast: Cast


## Lays a shadow of `def`'s first frame for a prop whose foot is at `foot`, or returns null for a
## prop that casts none.
func add(def: PropDef, foot: Vector2) -> Cast:
	if def.shadow == PropDef.Shadow.NONE:
		return null
	var cast := Cast.new()
	cast.def = def
	cast.foot = foot
	cast.sprite = _pool.acquire(def)
	var rows := def.foot.y - def.shadow_rise
	if def.shadow == PropDef.Shadow.WALL:
		rows = def.region.size.y
	cast.sprite.region_rect.size.y = rows
	cast.sprite.offset = Vector2(-def.foot.x, def.shadow_rise - def.foot.y)
	cast.sprite.self_modulate = Color.BLACK
	_casts[cast] = true
	_place(cast)
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
		for cast: Cast in _casts:
			_place(cast)
	_follow(car)


## The car's shadow, or null before the first car.
func car_cast() -> Cast:
	return _car_cast


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
		_car_cast = add(_car_def(car), car.position)
	_car_cast.sprite.show()
	_car_cast.foot = car.position
	_car_cast.basis = car.transform
	_car_cast.basis.origin = Vector2.ZERO
	_car_cast.sprite.frame = car.body_frame()
	_car_cast.sprite.self_modulate.a = car.modulate.a
	_place(_car_cast)


## Lays `cast` along the clock's shadow, from the point its shadow falls from.
func _place(cast: Cast) -> void:
	var from := cast.foot - Vector2(0.0, cast.def.shadow_rise)
	var across := Vector2(1.0, WALL_SLOPE) + WALL_SLOPE * _fall
	if cast.def.shadow == PropDef.Shadow.UPRIGHT:
		across = _across(_fall)
	cast.sprite.transform = Transform2D(across, -_fall, from) * cast.basis


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
