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
## refreshes them every frame. RenderingServer items share one texture per atlas, and the group
## hides while no glow is near the view (PERF_PLAN.md §5.2). Rects may be redrawn on the Web; only
## polygons must not be (docs/M2.md §5.7). A see-through prop's silhouette fades with it
## (docs/VISUALS.md §5.9), so that it hides as little of the glows behind it as the prop does of
## what is behind it, and its own glows dim with it.

const GLOW := preload("res://disasters/glow.tres")
const SHADER := preload("res://world/lamps.gdshader")
const ATLAS_Y := 64
const KEY_GAP := 1 << 16
const KEY_MOST := 1 << 30


## The last commands and state issued to an item, shared when its RID is reused.
class Drawn:
	extends RefCounted
	var item: RID
	var parent: RID
	var transform := Transform2D.IDENTITY
	var index := 0
	var rect := Rect2()
	var region := Rect2()
	var color := Color.WHITE
	var modulate := Color.WHITE
	var visible := true

	func part() -> Dictionary:
		return {
			"item": item,
			"parent": parent,
			"transform": transform,
			"draw_index": index,
			"rect": rect,
			"region": region,
			"color": color,
			"modulate": modulate,
			"visible": visible,
		}


## A prop's silhouette, with its glows over it.
class Lit:
	extends RefCounted
	## The prop's sprite under Props, whose place in Props' order the silhouette keeps.
	var prop: Sprite2D
	var def: PropDef
	var item: RID
	var parent: RID
	var glow_items: Array[RID] = []
	var drawn: Drawn
	var glow_drawn: Array[Drawn] = []
	var atlas: Texture2D
	var position: Vector2
	var key := 0
	var frame := 0
	## The source rect last issued to the renderer, not merely the requested frame (N7).
	var region: Rect2:
		get:
			return drawn.region
	var alpha: float:
		get:
			return drawn.modulate.a
	var glows := Rect2()


## Removed items keep their children and texture; add() returns a new handle to a reused item.
var _pools: Dictionary[PropDef, Array] = {}
var _order: Array[Lit] = []
var _glowing: Dictionary[Lit, bool] = {}
var _items: Array[RID] = []
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
	if not _pools.has(def):
		_pools[def] = [] as Array[Lit]
	var pool: Array[Lit] = _pools[def]
	var lit := Lit.new()
	lit.def = def
	lit.prop = prop
	lit.parent = get_canvas_item()
	lit.position = prop.position
	lit.frame = prop.frame
	lit.atlas = _atlas(def.texture)
	if pool.is_empty():
		lit.drawn = _item(lit.parent)
		lit.item = lit.drawn.item
		for index: int in def.lights.size() + def.light_pools.size():
			var glow := _item(lit.item)
			lit.glow_items.append(glow.item)
			lit.glow_drawn.append(glow)
		_draw_glows(lit)
	else:
		var old: Lit = pool.pop_back()
		lit.item = old.item
		lit.drawn = old.drawn
		lit.glow_items = old.glow_items.duplicate()
		lit.glow_drawn = old.glow_drawn.duplicate()
		_visibility(lit.drawn, true)
		_modulate_item(lit.drawn, Color.WHITE)
	_transform_item(lit.drawn, Transform2D(0.0, lit.position))
	_draw_silhouette(lit)
	var at := _order.bsearch_custom(lit, _draws_before)
	_order.insert(at, lit)
	_key(at)
	_note_glows(lit)
	return lit


## Takes away a silhouette that add() showed, with its glows.
func remove(lit: Lit) -> void:
	var at := _order.find(lit)
	if at < 0:
		return
	_order.remove_at(at)
	_glowing.erase(lit)
	_visibility(lit.drawn, false)
	_pools[lit.def].append(lit)


## The silhouettes that show, in the order they draw.
func shown() -> Array[Lit]:
	return _order.duplicate()


## The rect commands and transforms the items draw (PERF_PLAN.md §5.2).
static func parts(lit: Lit) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	if lit.def.shadow != PropDef.Shadow.NONE:
		found.append(lit.drawn.part())
	for glow: Drawn in lit.glow_drawn:
		found.append(glow.part())
	return found


static func show_frame(lit: Lit, frame: int) -> void:
	if frame < 0 or frame >= lit.def.frames:
		push_error("Lamps: frame %d is outside the prop's frames" % frame)
		return
	if lit.frame == frame:
		return
	lit.frame = frame
	if lit.def.shadow != PropDef.Shadow.NONE:
		_draw_silhouette(lit)


static func fade(lit: Lit, alpha: float) -> void:
	_modulate_item(lit.drawn, Color(1.0, 1.0, 1.0, alpha))


func _item(parent_item: RID) -> Drawn:
	var drawn := Drawn.new()
	drawn.item = RenderingServer.canvas_item_create()
	drawn.parent = parent_item
	RenderingServer.canvas_item_set_parent(drawn.item, parent_item)
	_items.append(drawn.item)
	return drawn


static func _visibility(drawn: Drawn, on: bool) -> void:
	drawn.visible = on
	RenderingServer.canvas_item_set_visible(drawn.item, on)


static func _modulate_item(drawn: Drawn, tint: Color) -> void:
	drawn.modulate = tint
	RenderingServer.canvas_item_set_modulate(drawn.item, tint)


static func _transform_item(drawn: Drawn, at: Transform2D) -> void:
	drawn.transform = at
	RenderingServer.canvas_item_set_transform(drawn.item, at)


static func _index_item(drawn: Drawn, index: int) -> void:
	drawn.index = index
	RenderingServer.canvas_item_set_draw_index(drawn.item, index)


static func _texture_rect(
	drawn: Drawn, texture: Texture2D, rect: Rect2, region: Rect2, color: Color
) -> void:
	drawn.rect = rect
	drawn.region = region
	drawn.color = color
	RenderingServer.canvas_item_add_texture_rect_region(
		drawn.item, rect, texture.get_rid(), region, color
	)


static func _draw_silhouette(lit: Lit) -> void:
	RenderingServer.canvas_item_clear(lit.item)
	var def := lit.def
	var size := Vector2(def.region.size)
	var region := Rect2(Vector2(def.region.position) + Vector2(lit.frame * size.x, ATLAS_Y), size)
	if def.shadow != PropDef.Shadow.NONE:
		_texture_rect(lit.drawn, lit.atlas, Rect2(-Vector2(def.foot), size), region, Color.BLACK)


static func _draw_glows(lit: Lit) -> void:
	var boxes: Array[Rect2] = []
	boxes.append_array(lit.def.lights)
	boxes.append_array(lit.def.light_pools)
	for index: int in boxes.size():
		var box := boxes[index]
		var share := 1.0 if index < lit.def.lights.size() else Tuning.LAMP_POOL_SHARE
		var drawn := lit.glow_drawn[index]
		_transform_item(drawn, Transform2D(0.0, box.size / GLOW.get_size(), 0.0, box.get_center()))
		_index_item(drawn, index)
		_texture_rect(
			drawn,
			lit.atlas,
			Rect2((-GLOW.get_size() / 2.0).round(), GLOW.get_size()),
			Rect2(Vector2.ZERO, GLOW.get_size()),
			Color(1.0, 1.0, 1.0, share)
		)


func _note_glows(lit: Lit) -> void:
	var rect := Rect2()
	for part: Dictionary in parts(lit):
		if part["item"] == lit.item:
			continue
		var glow_transform: Transform2D = part["transform"]
		glow_transform.origin = (glow_transform.origin + Vector2(0.5, 0.5)).floor()
		var glow: Rect2 = glow_transform * part["rect"]
		rect = glow if not rect.has_area() else rect.merge(glow)
	if rect.has_area():
		rect.position += (lit.position + Vector2(0.5, 0.5)).floor()
		lit.glows = rect
		_glowing[lit] = true


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
		@warning_ignore("integer_division")
		key = (low + high) / 2
	if absi(key) > KEY_MOST:
		_relabel()
		return
	lit.key = key
	_index_item(lit.drawn, key)


func _relabel() -> void:
	@warning_ignore("integer_division")
	var first := -(_order.size() / 2) * KEY_GAP
	for index: int in _order.size():
		_order[index].key = first + index * KEY_GAP
		_index_item(_order[index].drawn, _order[index].key)


## Powers of two keep the original glow's texels exact when it shares the prop atlas's texture.
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


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for item: RID in _items:
			RenderingServer.free_rid(item)


## Lights the glows as brightly as `cycle`'s light allows, or puts them out without a clock.
func refresh(cycle: DayCycle) -> void:
	var on := 0.0 if cycle == null else strength(cycle.light)
	# Not modulate, which the silhouettes and the glows would take too.
	self_modulate = Color(Tuning.LAMP_COLOR, Tuning.LAMP_ALPHA * on)
	visible = on > 0.0 and _glow_in_view()


func _glow_in_view() -> bool:
	if _glowing.is_empty():
		return false
	var view := (
		get_global_transform_with_canvas().affine_inverse()
		* get_viewport_rect().grow(Tuning.LAMP_CULL_MARGIN_PX)
	)
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
