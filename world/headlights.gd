class_name Headlights
extends RefCounted
## The car's headlights (docs/HEADLIGHTS.md §5.1–§5.3). From dusk until the sun rises
## (DayCycle.night_at()), while the car drives, they light the road in a cone ahead of it, and
## nothing else: their material, the road's (headlights.gdshader), draws the road in the cone
## brighter, under all that is drawn on the road, so that the night's veil leaves it lighter. They
## give back at most HEADLIGHT_SHARE of the light that the veil takes away, so the road is never
## lighter than by day, and by day they draw it as before. They turn on and off in
## HEADLIGHT_SWITCH_SECONDS, stay on into a zone's morning until its light has come, and are off
## once the run is over. WorldRenderer puts the material on RoadLayer and updates them every frame.
## Only the material's parameters change, so nothing is redrawn on the Web (docs/M2.md §5.7).

const SHADER := preload("res://world/headlights.gdshader")

## How far on they are, from 0, off, to 1.
var level := 0.0
## The road's material, which holds the parameters given to it.
var material := ShaderMaterial.new()


func _init() -> void:
	material.shader = SHADER
	_show(&"origin", Vector2.ZERO)
	_show(&"along", Vector2.ZERO)
	_show(&"across", Vector2.ZERO)
	_show(&"reach", Tuning.HEADLIGHT_REACH)
	_show(&"half_width", Tuning.HEADLIGHT_HALF_WIDTH)
	_show(&"spread", Tuning.HEADLIGHT_SPREAD)
	_show(&"dim_from", Tuning.HEADLIGHT_DIM_FROM)
	_show(&"edge", Tuning.HEADLIGHT_EDGE)
	_show(&"gain", Vector3.ZERO)


## Turns them on or off for `delta` seconds, by `cycle`'s hour and whether `sim`'s run is on, and
## aims them along `sim`'s car, which `to_canvas` takes from World's pixels to the canvas's. Once
## on, they stay on while the light shown catches up with the hour's: a zone starts its clock in
## the morning, and entered by night its light comes over seconds (docs/DAYNIGHT.md §5.3, §5.4),
## so the road in the cone lightens with the rest, and they turn off only once they light nothing.
## Without a clock or a car they turn off.
func update(cycle: DayCycle, sim: CarSim, to_canvas: Transform2D, delta: float) -> void:
	var on := cycle != null and sim != null and not sim.is_over()
	if on:
		var catching_up := level > 0.0 and cycle.light != cycle.target()
		on = DayCycle.night_at(cycle.hour()) or catching_up
	level = move_toward(level, 1.0 if on else 0.0, delta / Tuning.HEADLIGHT_SWITCH_SECONDS)
	var light := Color.WHITE if cycle == null else cycle.light
	_show(&"gain", gain(light, level))
	if level > 0.0 and sim != null:
		aim(sim, to_canvas)


## Aims the cone along `sim`'s car, which `to_canvas` takes from World's pixels to the canvas's.
func aim(sim: CarSim, to_canvas: Transform2D) -> void:
	var ahead := sim.forward()
	var aside := Vector2(-ahead.y, ahead.x)
	_show(&"origin", to_canvas * Iso.tile_to_world(sim.pos + ahead * Tuning.HEADLIGHT_FRONT))
	# The canvas's pixels to tiles, then along the car and across it, as rows.
	var to_tiles := (
		Transform2D(Iso.world_to_tile(Vector2.RIGHT), Iso.world_to_tile(Vector2.DOWN), Vector2.ZERO)
		* to_canvas.affine_inverse()
	)
	_show(&"along", Vector2(to_tiles.x.dot(ahead), to_tiles.y.dot(ahead)))
	_show(&"across", Vector2(to_tiles.x.dot(aside), to_tiles.y.dot(aside)))


## How much they light canvas point `point`, from 0 to 1, as the shader works it out from the
## material's parameters.
func lit(point: Vector2) -> float:
	var offset := point - (shown(&"origin") as Vector2)
	var ahead := (shown(&"along") as Vector2).dot(offset)
	var aside := absf((shown(&"across") as Vector2).dot(offset))
	var width := Tuning.HEADLIGHT_HALF_WIDTH + Tuning.HEADLIGHT_SPREAD * maxf(ahead, 0.0)
	var reach := Tuning.HEADLIGHT_REACH
	var shine := 0.0 if ahead < 0.0 else 1.0
	shine *= 1.0 - smoothstep(Tuning.HEADLIGHT_DIM_FROM * reach, reach, ahead)
	return shine * (1.0 - smoothstep(Tuning.HEADLIGHT_EDGE * width, width, aside))


## What the shader multiplies the road's colour by, less 1, in each channel, where the cone is
## brightest and they are `p_level` on, under the veil's `light`: so that the veil leaves the road
## lit HEADLIGHT_SHARE of the way back to what it shows by day, in HEADLIGHT_COLOR. A channel that
## the veil takes nothing from, or all, gets none.
static func gain(light: Color, p_level: float) -> Vector3:
	var gains := Vector3.ZERO
	for channel: int in 3:
		var kept: float = light[channel]
		if kept > 0.0 and kept < 1.0:
			var given: float = Tuning.HEADLIGHT_SHARE * Tuning.HEADLIGHT_COLOR[channel]
			gains[channel] = p_level * given * (1.0 - kept) / kept
	return gains


## The parameter `parameter_name` that the material holds, which the shader draws with.
func shown(parameter_name: StringName) -> Variant:
	return material.get_shader_parameter(parameter_name)


func _show(parameter_name: StringName, value: Variant) -> void:
	if shown(parameter_name) == value:
		return
	material.set_shader_parameter(parameter_name, value)
