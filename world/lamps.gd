class_name Lamps
extends Node2D
## The props' lights at night (DAYNIGHT_PLAN.md §5.12): a glow on each box that a prop's PropDef
## lights, such as a lamp's head or a lit window, and a fainter one on the ground that a lamp
## lights. They draw over the night's veil and add light, as the legends' glows do (M6_PLAN.md
## §5.5): in each channel as much as the veil takes away from it at most, so that nothing they
## light clips to white. They come on as the light fades, and by day they are off, so that the
## day's frames are the same as before. PropScatter adds and removes the props' glows with their
## sprites. WorldRenderer refreshes them every frame. Only the node's modulate and visible change,
## and each glow's transform and alpha as it is added, so nothing is redrawn on the Web
## (M2_PLAN.md §5.7).

const GLOW := preload("res://disasters/glow.tres")
const GLOW_MATERIAL := preload("res://disasters/glow_material.tres")

## The glows that remove() hid, for add() to show again.
var _hidden: Array[Sprite2D] = []
## How many glows add() has shown that remove() hasn't hidden.
var _shown := 0


func _init() -> void:
	visible = false


## Shows the glows of a prop of `def` whose foot is at `foot`, and returns them.
func add(def: PropDef, foot: Vector2) -> Array[Sprite2D]:
	var glows: Array[Sprite2D] = []
	for box: Rect2 in def.lights:
		glows.append(_glow(foot, box, 1.0))
	for box: Rect2 in def.light_pools:
		glows.append(_glow(foot, box, Tuning.LAMP_POOL_SHARE))
	return glows


## Hides glows that add() showed.
func remove(glows: Array[Sprite2D]) -> void:
	for glow: Sprite2D in glows:
		glow.hide()
		_hidden.append(glow)
	_shown -= glows.size()


## How many glows add() has shown that remove() hasn't hidden.
func count() -> int:
	return _shown


## Lights the glows as brightly as `cycle`'s light allows, or puts them out without a clock.
func refresh(cycle: DayCycle) -> void:
	var on := 0.0 if cycle == null else strength(cycle.light)
	modulate = Color(Tuning.LAMP_COLOR, Tuning.LAMP_ALPHA * on)
	visible = on > 0.0


## How brightly the lamps glow in `light`, from 0 to 1: as brightly as they can while adding to no
## channel more than `light` takes away from white.
static func strength(light: Color) -> float:
	var on := 1.0
	for channel: int in 3:
		var glow: float = Tuning.LAMP_ALPHA * Tuning.LAMP_COLOR[channel]
		on = minf(on, (1.0 - light[channel]) / glow)
	return maxf(on, 0.0)


## A glow that fills `box` of a prop whose foot is at `foot`, `share` as bright as a light.
func _glow(foot: Vector2, box: Rect2, share: float) -> Sprite2D:
	var glow: Sprite2D
	if _hidden.is_empty():
		glow = Sprite2D.new()
		glow.texture = GLOW
		glow.material = GLOW_MATERIAL
		glow.z_index = Tuning.GLOW_Z
		glow.z_as_relative = false
		add_child(glow)
	else:
		glow = _hidden.pop_back()
		glow.show()
	glow.position = foot + box.get_center()
	glow.scale = box.size / GLOW.get_size()
	glow.self_modulate.a = share
	_shown += 1
	return glow
