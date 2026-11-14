class_name PropPool
extends RefCounted
## The props' sprites (IMPLEMENTATION_PLAN.md M5.2), under one layer: acquire() shows a sprite that
## release() hid, or makes one, so that once a run has warmed up, a new row of props makes no
## nodes. A sprite shows its prop's frame with the prop's foot on the sprite's position. The layer
## frees the sprites. A layer whose sprites are its own parts holds them as internal children, which
## get_children() leaves out: so does GUT's simulate(), which walks every node each frame
## (docs/DAYNIGHT.md C20).

## Sprites made so far, shown or hidden.
var made := 0

var _layer: Node
var _internal: Node.InternalMode
var _hidden: Array[Sprite2D] = []


func _init(layer: Node, internal := Node.INTERNAL_MODE_DISABLED) -> void:
	_layer = layer
	_internal = internal


## A sprite that shows `def`'s first frame.
func acquire(def: PropDef) -> Sprite2D:
	var sprite: Sprite2D
	if _hidden.is_empty():
		sprite = Sprite2D.new()
		sprite.centered = false
		sprite.region_enabled = true
		_layer.add_child(sprite, false, _internal)
		made += 1
	else:
		sprite = _hidden.pop_back()
		sprite.show()
	sprite.texture = def.texture
	# The frame first: hframes mustn't leave the last prop's frame out of range.
	sprite.frame = 0
	sprite.hframes = def.frames
	sprite.region_rect = Rect2(def.region.position, def.region.size * Vector2i(def.frames, 1))
	sprite.offset = -Vector2(def.foot)
	return sprite


## Hides `sprite`, for acquire() to show again.
func release(sprite: Sprite2D) -> void:
	sprite.hide()
	_hidden.append(sprite)


## How many sprites are hidden.
func hidden() -> int:
	return _hidden.size()
