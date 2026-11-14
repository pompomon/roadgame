class_name Lamps
extends CanvasGroup
## The props' lights at night (docs/DAYNIGHT.md §5.12): a glow on each box that a prop's PropDef
## lights, such as a lamp's head or a lit window, and a fainter one on the ground that a lamp
## lights. They draw over the night's veil and add light, as the legends' glows do (docs/M6.md
## §5.5): in each channel as much as the veil takes away from it at most, so that nothing they
## light clips to white. They come on as the light fades, and by day they are off, so that the
## day's frames are the same as before.
##
## They draw as one group, which adds what it holds (P10): where glows overlap, they cover no more
## than one does. A prop in front hides the glows behind it: the group holds a black silhouette of
## each prop that stands, and the prop's glows over its own silhouette, in the order that Props
## draws the props. Props y-sorts them, but a canvas group that y-sorts draws nothing as a group
## (P10b), so the group keeps that order itself. A prop that lies flat hides nothing, and the car
## and the legends hide no glows.
##
## PropScatter adds and removes the props with their sprites, and shows their frames. WorldRenderer
## refreshes them every frame. Only the group's self_modulate and visible change, and each
## silhouette's position, frame and order as it is added, so no polygon is redrawn on the Web
## (docs/M2.md §5.7).

const GLOW := preload("res://disasters/glow.tres")
const SHADER := preload("res://world/lamps.gdshader")


## A prop's silhouette, with its glows over it.
class Lit:
	extends RefCounted
	var sprite: Sprite2D
	## The prop's sprite under Props, whose place in Props' order the silhouette keeps.
	var prop: Sprite2D
	var def: PropDef


## The silhouettes of each PropDef, so that one that remove() hid still has its glows. They are
## Lamps' own parts, so internal children (C20).
var _pools: Dictionary[PropDef, PropPool] = {}
## The silhouettes that show, in the order they draw. They are Lamps' first children.
var _order: Array[Lit] = []


func _init() -> void:
	visible = false
	z_index = Tuning.GLOW_Z
	z_as_relative = false
	var adding := ShaderMaterial.new()
	adding.shader = SHADER
	material = adding


## Shows the silhouette of `prop`, a sprite of `def` under Props, with the prop's glows over it,
## and returns it. A prop that lies flat and has no lights neither hides nor lights: null.
func add(def: PropDef, prop: Sprite2D) -> Lit:
	var stands := def.shadow != PropDef.Shadow.NONE
	if not stands and def.lights.is_empty() and def.light_pools.is_empty():
		return null
	if not _pools.has(def):
		_pools[def] = PropPool.new(self, Node.INTERNAL_MODE_BACK)
	var pool: PropPool = _pools[def]
	var made := pool.made
	var lit := Lit.new()
	lit.def = def
	lit.prop = prop
	lit.sprite = pool.acquire(def)
	if pool.made > made:
		_light(lit.sprite, def)
	lit.sprite.position = prop.position
	lit.sprite.frame = prop.frame
	lit.sprite.self_modulate = Color(0.0, 0.0, 0.0, 1.0 if stands else 0.0)
	var at := _order.bsearch_custom(lit, _draws_before)
	_order.insert(at, lit)
	move_child(lit.sprite, at)
	return lit


## Takes away a silhouette that add() showed, with its glows.
func remove(lit: Lit) -> void:
	var at := _order.find(lit)
	if at < 0:
		return
	_order.remove_at(at)
	move_child(lit.sprite, -1)
	_pools[lit.def].release(lit.sprite)


## The silhouettes that show, in the order they draw.
func shown() -> Array[Lit]:
	return _order.duplicate()


## Lights the glows as brightly as `cycle`'s light allows, or puts them out without a clock.
func refresh(cycle: DayCycle) -> void:
	var on := 0.0 if cycle == null else strength(cycle.light)
	# Not modulate, which the silhouettes and the glows would take too.
	self_modulate = Color(Tuning.LAMP_COLOR, Tuning.LAMP_ALPHA * on)
	visible = on > 0.0


## How brightly the lamps glow in `light`, from 0 to 1: as brightly as they can while adding to no
## channel more than `light` takes away from white.
static func strength(light: Color) -> float:
	var on := 1.0
	for channel: int in 3:
		var glow: float = Tuning.LAMP_ALPHA * Tuning.LAMP_COLOR[channel]
		on = minf(on, (1.0 - light[channel]) / glow)
	return maxf(on, 0.0)


## Whether Props draws `a`'s prop before `b`'s. As Godot y-sorts: by y, and if that is the same,
## in the order of Props' children (servers/rendering/renderer_canvas_cull.h:117, ItemYSort).
## Props only adds sprites after the others and frees them, so that order stays as it is.
static func _draws_before(a: Lit, b: Lit) -> bool:
	if is_equal_approx(a.prop.position.y, b.prop.position.y):
		return a.prop.get_index() < b.prop.get_index()
	return a.prop.position.y < b.prop.position.y


## Puts `def`'s glows over a new silhouette of it: a light's, and a pool's, fainter.
static func _light(sprite: Sprite2D, def: PropDef) -> void:
	for box: Rect2 in def.lights:
		sprite.add_child(_glow(box, 1.0))
	for box: Rect2 in def.light_pools:
		sprite.add_child(_glow(box, Tuning.LAMP_POOL_SHARE))


## A glow that fills `box`, around a prop's foot, `share` as bright as a light.
static func _glow(box: Rect2, share: float) -> Sprite2D:
	var glow := Sprite2D.new()
	glow.texture = GLOW
	glow.position = box.get_center()
	glow.scale = box.size / GLOW.get_size()
	glow.self_modulate.a = share
	return glow
