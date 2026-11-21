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
## refreshes them every frame. Only the group's self_modulate and visible change, each silhouette's
## position, frame and order as it is added, and its modulate's alpha as its prop fades, so no
## polygon is redrawn on the Web (docs/M2.md §5.7). A see-through prop's silhouette fades with it
## (docs/VISUALS.md §5.9), so that it hides as little of the glows behind it as the prop does of
## what is behind it, and its own glows dim with it.

const GLOW := preload("res://disasters/glow.tres")
const SHADER := preload("res://world/lamps.gdshader")
## PF prototype (--pf-lamps=rs): where a props atlas lies in its combined texture, under GLOW's
## image, which lies at the top left so that its UVs scale by a power of two (exact).
const ATLAS_Y := 64
## Draw index keys: spaced KEY_GAP apart when relabelled, and kept within KEY_MOST of 0 (the
## RenderingServer takes a 32-bit int).
const KEY_GAP := 1 << 16
const KEY_MOST := 1 << 30


## A prop's silhouette, with its glows over it.
class Lit:
	extends RefCounted
	var sprite: Sprite2D
	## The prop's sprite under Props, whose place in Props' order the silhouette keeps.
	var prop: Sprite2D
	var def: PropDef
	## PF prototype: its canvas item, draw index key, frame and combined texture, if rs.
	var item: RID
	var key := 0
	var frame := 0
	var atlas: Texture2D
	## Where its glows light, on Lamps, or an empty rect.
	var glows := Rect2()


## The silhouettes of each PropDef, so that one that remove() hid still has its glows. They are
## Lamps' own parts, so internal children (C20).
var _pools: Dictionary[PropDef, PropPool] = {}
## The silhouettes that show, in the order they draw. They are Lamps' first children.
var _order: Array[Lit] = []
## PF prototype: the silhouettes that have glows, and the rs canvas items, made and free.
var _glowing: Dictionary[Lit, bool] = {}
var _items: Array[RID] = []
var _free: Array[RID] = []
var _atlases: Dictionary[Texture2D, ImageTexture] = {}


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
	if PfProbe.lamps_rs:
		return _add_rs(def, prop)
	if not _pools.has(def):
		_pools[def] = PropPool.new(self, Node.INTERNAL_MODE_BACK)
	var pool: PropPool = _pools[def]
	var made := pool.made
	var lit := Lit.new()
	lit.def = def
	lit.prop = prop
	lit.sprite = pool.acquire(def)
	if pool.made > made and not PfProbe.lamps_noglow:
		_light(lit.sprite, def)
		if PfProbe.lamps_atlas:
			# Cost test only: the glows draw a corner of the props' atlas, so they batch.
			for glow: Node in lit.sprite.get_children():
				var sprite := glow as Sprite2D
				sprite.texture = def.texture
				sprite.region_enabled = true
				sprite.region_rect = Rect2(def.region.position, Vector2(16, 16))
				sprite.scale = sprite.scale * GLOW.get_size() / 16.0
	if PfProbe.lamps_nosil:
		lit.sprite.texture = null
	lit.sprite.position = prop.position
	lit.sprite.frame = prop.frame
	lit.sprite.self_modulate = Color(0.0, 0.0, 0.0, 1.0 if stands else 0.0)
	var at := _order.bsearch_custom(lit, _draws_before)
	_order.insert(at, lit)
	move_child(lit.sprite, at)
	_note_glows(lit)
	return lit


func _add_rs(def: PropDef, prop: Sprite2D) -> Lit:
	var lit := Lit.new()
	lit.def = def
	lit.prop = prop
	if _free.is_empty():
		lit.item = RenderingServer.canvas_item_create()
		RenderingServer.canvas_item_set_parent(lit.item, get_canvas_item())
		_items.append(lit.item)
	else:
		lit.item = _free.pop_back()
		RenderingServer.canvas_item_set_visible(lit.item, true)
		RenderingServer.canvas_item_set_modulate(lit.item, Color.WHITE)
	RenderingServer.canvas_item_set_transform(lit.item, Transform2D(0.0, prop.position))
	lit.atlas = _atlas(def.texture)
	lit.frame = prop.frame
	_draw_rs(lit)
	var at := _order.bsearch_custom(lit, _draws_before)
	_order.insert(at, lit)
	_key(at)
	_note_glows(lit)
	return lit


func _note_glows(lit: Lit) -> void:
	var rect := Rect2()
	for box: Rect2 in lit.def.lights + lit.def.light_pools:
		var glow := Rect2(_glow_at(box), box.size)
		rect = glow if not rect.has_area() else rect.merge(glow)
	if rect.has_area():
		lit.glows = Rect2(rect.position + lit.prop.position, rect.size)
		_glowing[lit] = true


## Gives the silhouette at `at` in _order a draw index key between its neighbours', or relabels
## them all if there is none.
func _key(at: int) -> void:
	var lit := _order[at]
	var key := 0
	if _order.size() == 1:
		key = 0
	elif at == 0:
		key = _order[1].key - KEY_GAP
	elif at == _order.size() - 1:
		key = _order[at - 1].key + KEY_GAP
	else:
		var low := _order[at - 1].key
		var high := _order[at + 1].key
		if high - low < 2:
			_relabel()
			return
		key = (low + high) / 2
	if absi(key) > KEY_MOST:
		_relabel()
		return
	lit.key = key
	RenderingServer.canvas_item_set_draw_index(lit.item, key)


func _relabel() -> void:
	var first := -(_order.size() / 2) * KEY_GAP
	for i: int in _order.size():
		_order[i].key = first + i * KEY_GAP
		RenderingServer.canvas_item_set_draw_index(_order[i].item, _order[i].key)


## A props atlas with GLOW's image over it, in a texture whose sides are powers of two, so that
## the glows and the silhouettes draw from one texture and batch.
func _atlas(texture: Texture2D) -> ImageTexture:
	if _atlases.has(texture):
		return _atlases[texture]
	var glow := GLOW.get_image()
	var art := texture.get_image()
	glow.convert(Image.FORMAT_RGBA8)
	art.convert(Image.FORMAT_RGBA8)
	var width := nearest_po2(maxi(glow.get_width(), art.get_width()))
	var height := nearest_po2(ATLAS_Y + art.get_height())
	var image := Image.create_empty(width, height, false, Image.FORMAT_RGBA8)
	image.blit_rect(glow, Rect2i(Vector2i.ZERO, glow.get_size()), Vector2i.ZERO)
	image.blit_rect(art, Rect2i(Vector2i.ZERO, art.get_size()), Vector2i(0, ATLAS_Y))
	var combined := ImageTexture.create_from_image(image)
	_atlases[texture] = combined
	return combined


## Draws `lit`'s silhouette in its frame and its glows over it, as the Sprite2D nodes would.
static func _draw_rs(lit: Lit) -> void:
	var item := lit.item
	RenderingServer.canvas_item_clear(item)
	var def := lit.def
	var texture := lit.atlas.get_rid()
	if def.shadow != PropDef.Shadow.NONE:
		var size := Vector2(def.region.size)
		var at := Vector2(def.region.position) + Vector2(lit.frame * size.x, ATLAS_Y)
		RenderingServer.canvas_item_add_texture_rect_region(
			item, Rect2(-Vector2(def.foot), size), texture, Rect2(at, size), Color.BLACK
		)
	var whole := Rect2(Vector2.ZERO, GLOW.get_size())
	for box: Rect2 in def.lights:
		RenderingServer.canvas_item_add_texture_rect_region(
			item, Rect2(_glow_at(box), box.size), texture, whole, Color.WHITE
		)
	for box: Rect2 in def.light_pools:
		RenderingServer.canvas_item_add_texture_rect_region(
			item,
			Rect2(_glow_at(box), box.size),
			texture,
			whole,
			Color(1.0, 1.0, 1.0, Tuning.LAMP_POOL_SHARE)
		)


## Where a glow that fills `box` draws from: a glow sprite on the box's centre, snapped as Godot
## snaps a child's position (renderer_canvas_cull.cpp:361).
static func _glow_at(box: Rect2) -> Vector2:
	return (box.get_center() + Vector2(0.5, 0.5)).floor() - box.size / 2.0


## Shows `lit`'s silhouette in `frame`.
static func show_frame(lit: Lit, frame: int) -> void:
	if lit.sprite != null:
		lit.sprite.frame = frame
	elif lit.frame != frame:
		lit.frame = frame
		if lit.def.shadow != PropDef.Shadow.NONE:
			_draw_rs(lit)


## Fades `lit`'s silhouette and glows to `alpha`.
static func fade(lit: Lit, alpha: float) -> void:
	if lit.sprite != null:
		lit.sprite.modulate.a = alpha
	else:
		RenderingServer.canvas_item_set_modulate(lit.item, Color(1.0, 1.0, 1.0, alpha))


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for item: RID in _items:
			RenderingServer.free_rid(item)


## Takes away a silhouette that add() showed, with its glows.
func remove(lit: Lit) -> void:
	var at := _order.find(lit)
	if at < 0:
		return
	_order.remove_at(at)
	_glowing.erase(lit)
	if lit.sprite == null:
		RenderingServer.canvas_item_set_visible(lit.item, false)
		_free.append(lit.item)
		return
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
	visible = on > 0.0 and (not PfProbe.lamps_cull or _glow_in_view())


## Whether a glow of a silhouette that shows is in the viewport.
func _glow_in_view() -> bool:
	if _glowing.is_empty():
		return false
	var view := get_global_transform_with_canvas().affine_inverse() * get_viewport_rect()
	for lit: Lit in _glowing:
		if view.intersects(lit.glows):
			return true
	return false


## How brightly the lamps glow in `light`, from 0 to 1: as brightly as they can while adding to no
## channel more than `light` takes away from white.
static func strength(light: Color) -> float:
	var on := 1.0
	for channel: int in 3:
		var glow: float = Tuning.LAMP_ALPHA * Tuning.LAMP_COLOR[channel]
		on = minf(on, (1.0 - light[channel]) / glow)
	return maxf(on, 0.0)


## Whether Props draws `a`'s prop before `b`'s. As Godot y-sorts: by y, and if that is the same,
## in the order of Props' children, internal ones included (servers/rendering/
## renderer_canvas_cull.h:117, ItemYSort). Props only adds sprites after the others and frees them,
## so that order stays as it is.
static func _draws_before(a: Lit, b: Lit) -> bool:
	if is_equal_approx(a.prop.position.y, b.prop.position.y):
		return a.prop.get_index(true) < b.prop.get_index(true)
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
