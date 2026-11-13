extends GutTest
## Lamps (DAYNIGHT_PLAN.md §5.12): each prop's lights glow at night over the veil, adding no more
## light than the veil takes away, and by day they are out. They draw as one group that adds what
## it holds, and a prop in front hides the glows behind it.

const DELTA := 1.0 / 60.0

var _lamps: Lamps
## A layer that y-sorts its props' sprites, as World's Props does.
var _props: Node2D
var _pool: PropPool


func before_each() -> void:
	_lamps = add_child_autofree(Lamps.new())
	_props = add_child_autofree(Node2D.new())
	_props.y_sort_enabled = true
	_pool = PropPool.new(_props)


## A prop that stands, of `frames` 8 × 8-pixel frames, with no lights.
static func _def(id: StringName, frames := 1) -> PropDef:
	var def := PropDef.new()
	def.id = id
	var image := Image.create_empty(8 * frames, 8, false, Image.FORMAT_RGBA8)
	def.texture = ImageTexture.create_from_image(image)
	def.region = Rect2i(0, 0, 8, 8)
	def.frames = frames
	def.foot = Vector2i(4, 8)
	return def


## A prop with a light and a pool of light, as the City's lamp has.
static func _lamp() -> PropDef:
	var def := _def(&"lamp")
	def.lights.append(Rect2(0, -40, 12, 10))
	def.light_pools.append(Rect2(-26, -16, 64, 32))
	return def


## A sprite of `def` under _props with its foot on `foot`, as PropScatter shows a prop.
func _prop(def: PropDef, foot: Vector2) -> Sprite2D:
	var sprite := _pool.acquire(def)
	sprite.position = foot
	return sprite


## A zone's clock at `p_hour`, showing that hour's light.
static func _cycle(p_hour: float, day_seconds := 120.0) -> DayCycle:
	var cycle := DayCycle.new()
	cycle.start_hour = p_hour
	cycle.enter(day_seconds)
	cycle.snap()
	return cycle


## The render modes of `shader`.
static func _render_modes(shader: Shader) -> PackedStringArray:
	var modes := PackedStringArray()
	var found := RegEx.create_from_string("render_mode\\s+([^;]*);").search(shader.code)
	if found != null:
		for mode: String in found.get_string(1).split(","):
			modes.append(mode.strip_edges())
	return modes


## What a glow's centre adds to each channel of the pixel under it.
func _added() -> Color:
	return Tuning.LAMP_COLOR * _lamps.self_modulate.a


func test_the_lamps_draw_as_one_group_that_adds_over_the_veil() -> void:
	# They add light over the night's veil, as a legend's glow does (M6_PLAN.md §5.5), but as one
	# group: where glows overlap, it covers no more than one does (P10). What it holds draws in the
	# group, at its z and with no material of its own, and only the group's self_modulate lights it.
	# A group that y-sorts draws what it holds on its own (P10b).
	var def := _lamp()
	var lit := _lamps.add(def, _prop(def, Vector2(100, 50)))
	assert_eq(_lamps.z_index, Tuning.GLOW_Z)
	assert_false(_lamps.z_as_relative)
	assert_gt(Tuning.GLOW_Z, Tuning.VEIL_Z)
	assert_false(_lamps.y_sort_enabled)
	var adding := _lamps.material as ShaderMaterial
	assert_not_null(adding)
	if adding != null:
		assert_eq(adding.shader, Lamps.SHADER)
	assert_eq(_render_modes(Lamps.SHADER), PackedStringArray(["unshaded", "blend_add"]))
	assert_eq(_lamps.modulate, Color.WHITE)
	var items: Array[CanvasItem] = [lit.sprite]
	for glow: Sprite2D in lit.sprite.get_children():
		items.append(glow)
	assert_eq(items.size(), 3)
	for item: CanvasItem in items:
		assert_null(item.material, "%s: the group's blend" % item)
		assert_false(item.use_parent_material, "%s" % item)
		assert_eq(item.z_index, 0, "%s: in the group" % item)
		assert_true(item.z_as_relative, "%s" % item)
		assert_eq(item.modulate, Color.WHITE, "%s" % item)


func test_each_light_and_pool_glows_where_its_prop_puts_it() -> void:
	var def := _lamp()
	var prop := _prop(def, Vector2(100, 50))
	var lit := _lamps.add(def, prop)
	assert_same(lit.prop, prop)
	assert_eq(lit.sprite.position, Vector2(100, 50), "on the prop's foot")
	assert_eq(lit.sprite.texture, def.texture)
	assert_eq(lit.sprite.region_rect, prop.region_rect)
	assert_eq(lit.sprite.offset, prop.offset)
	assert_eq(lit.sprite.self_modulate, Color.BLACK, "a silhouette, which hides what is behind it")
	var glows := lit.sprite.get_children()
	assert_eq(glows.size(), 2)
	if glows.size() == 2:
		var light: Sprite2D = glows[0]
		var pool: Sprite2D = glows[1]
		assert_eq(light.position, Vector2(6, -35), "the light's centre, from the foot")
		assert_eq(light.scale, Vector2(12, 10) / 64.0, "it fills its box")
		assert_eq(light.self_modulate, Color.WHITE)
		assert_eq(pool.position, Vector2(6, 0), "the pool's centre")
		assert_eq(pool.scale, Vector2(1.0, 0.5))
		assert_almost_eq(pool.self_modulate.a, Tuning.LAMP_POOL_SHARE, 1e-6, "a pool is fainter")
		for glow: Sprite2D in [light, pool]:
			assert_eq(glow.texture, Lamps.GLOW)
	# A prop without lights hides the glows behind it. One that lies flat hides none, and has a
	# silhouette only for its lights.
	var dark := _def(&"dark", 4)
	var turning := _prop(dark, Vector2(0, 40))
	turning.frame = 2
	var shade := _lamps.add(dark, turning)
	assert_eq(shade.sprite.self_modulate, Color.BLACK)
	assert_eq(shade.sprite.get_child_count(), 0)
	assert_eq(shade.sprite.hframes, 4)
	assert_eq(shade.sprite.frame, 2, "in the prop's frame")
	var flat := _def(&"flat")
	flat.shadow = PropDef.Shadow.NONE
	assert_null(_lamps.add(flat, _prop(flat, Vector2.ZERO)), "a flat prop without lights")
	var lit_flat := _lamp()
	lit_flat.shadow = PropDef.Shadow.NONE
	var clear := _lamps.add(lit_flat, _prop(lit_flat, Vector2(0, 30)))
	assert_eq(clear.sprite.self_modulate.a, 0.0, "a flat prop hides nothing")
	assert_eq(clear.sprite.get_child_count(), 2, "but lights")
	assert_eq(_lamps.shown().size(), 3)


## The props whose silhouettes draw, in the order they draw: Lamps' children that show, in order.
func _drawn(silhouettes: Dictionary[Sprite2D, Sprite2D]) -> Array[Sprite2D]:
	var drawn: Array[Sprite2D] = []
	for child: Sprite2D in _lamps.get_children():
		if child.visible:
			drawn.append(silhouettes[child])
	return drawn


## The props of `shown` in the order Props draws them: by y, and if that is the same, in the order
## of its children (servers/rendering/renderer_canvas_cull.h:117, ItemYSort).
func _y_sorted(shown: Array[Sprite2D]) -> Array[Sprite2D]:
	var ys: Array[float] = []
	for prop: Sprite2D in shown:
		if prop.position.y not in ys:
			ys.append(prop.position.y)
	ys.sort()
	var y_sorted: Array[Sprite2D] = []
	for y: float in ys:
		for child: Node in _props.get_children():
			var prop := child as Sprite2D
			if prop != null and prop in shown and prop.position.y == y:
				y_sorted.append(prop)
	return y_sorted


func test_the_silhouettes_draw_in_the_order_props_draws_the_props() -> void:
	# So a prop in front hides the glows behind it, as it hides the prop behind it, and a prop's own
	# glows draw over it. Many props have the same y. The order holds as props come and go, and as
	# a node that has no silhouette, such as the car, comes and goes under Props.
	var defs: Array[PropDef] = [_lamp(), _def(&"dark")]
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var props: Array[Sprite2D] = []
	for i: int in 60:
		var foot := Vector2(rng.randi_range(-40, 40), 4 * rng.randi_range(0, 9))
		props.append(_prop(defs[i % 2], foot))
	var car := Node2D.new()
	_props.add_child(car)
	_props.move_child(car, 0)
	for i: int in range(props.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swapped := props[i]
		props[i] = props[j]
		props[j] = swapped
	var silhouettes: Dictionary[Sprite2D, Sprite2D] = {}
	var lits: Array[Lamps.Lit] = []
	for prop: Sprite2D in props:
		var lit := _lamps.add(defs[0] if prop.texture == defs[0].texture else defs[1], prop)
		silhouettes[lit.sprite] = prop
		lits.append(lit)
	var shown: Array[Sprite2D] = props.duplicate()
	assert_eq(_drawn(silhouettes), _y_sorted(shown), "as they came")
	car.free()
	for i: int in range(0, lits.size(), 3):
		_lamps.remove(lits[i])
		shown.erase(lits[i].prop)
	assert_eq(_drawn(silhouettes), _y_sorted(shown), "as some went")
	for i: int in range(0, lits.size(), 6):
		var prop := lits[i].prop
		prop.position.y = 4 * rng.randi_range(0, 9)
		var again := _lamps.add(defs[0] if prop.texture == defs[0].texture else defs[1], prop)
		silhouettes[again.sprite] = prop
		shown.append(prop)
	assert_eq(_drawn(silhouettes), _y_sorted(shown), "as some came again")
	var lamps: Array[Sprite2D] = []
	for lit: Lamps.Lit in _lamps.shown():
		lamps.append(lit.prop)
	assert_eq(lamps, _y_sorted(shown), "shown()")


func test_silhouettes_are_used_again_with_their_glows() -> void:
	var def := _lamp()
	var first := _lamps.add(def, _prop(def, Vector2.ZERO))
	var dark := _def(&"dark")
	_lamps.add(dark, _prop(dark, Vector2(0, 5)))
	_lamps.remove(first)
	_lamps.remove(first)
	_lamps.remove(null)
	assert_false(first.sprite.visible, "hidden")
	assert_eq(_lamps.shown().size(), 1, "once")
	var again := _lamps.add(def, _prop(def, Vector2(10, 10)))
	assert_same(again.sprite, first.sprite, "the lamp's again")
	assert_true(again.sprite.visible)
	assert_eq(again.sprite.position, Vector2(10, 10))
	assert_eq(again.sprite.get_child_count(), 2, "with its glows")
	assert_eq(_lamps.get_child_count(), 2)
	assert_ne(_lamps.add(dark, _prop(dark, Vector2(0, 20))).sprite, first.sprite, "another prop's")
	assert_eq(_lamps.get_child_count(), 3)


func test_out_by_day_and_without_a_clock_and_on_at_night() -> void:
	var def := _lamp()
	_lamps.add(def, _prop(def, Vector2.ZERO))
	_lamps.refresh(null)
	assert_false(_lamps.visible, "no clock")
	_lamps.refresh(_cycle(12.0))
	assert_false(_lamps.visible, "at noon")
	assert_eq(_lamps.self_modulate.a, 0.0)
	_lamps.refresh(_cycle(0.0))
	assert_true(_lamps.visible, "at midnight")
	assert_eq(_lamps.self_modulate, Color(Tuning.LAMP_COLOR, Tuning.LAMP_ALPHA))
	assert_eq(_lamps.modulate, Color.WHITE, "which the silhouettes and the glows would take too")
	# At dusk the light is still full in red, so they wait for the night; at dawn they are faint.
	assert_eq(Lamps.strength(Tuning.LIGHT_DUSK), 0.0, "at dusk")
	assert_between(Lamps.strength(Tuning.LIGHT_DAWN), 0.01, 0.25, "at dawn")
	assert_eq(Lamps.strength(Tuning.LIGHT_NIGHT), 1.0, "at night")


func test_a_glow_never_adds_more_than_the_veil_takes_away() -> void:
	# Over a white pixel the veil leaves the light, and the group adds to it at most what a glow's
	# centre adds: never past white (M6_PLAN.md S10), at every quarter hour and as a zone sets the
	# clock back at night.
	var over := PackedStringArray()
	var lit := 0
	for quarter: int in 96:
		var cycle := _cycle(quarter / 4.0)
		_lamps.refresh(cycle)
		lit += 1 if _lamps.visible else 0
		for channel: int in 3:
			if cycle.light[channel] + _added()[channel] > 1.0 + 1e-6:
				over.append("%.2f h, channel %d" % [quarter / 4.0, channel])
	var night := _cycle(23.0)
	night.start_hour = Tuning.DAY_START_HOUR
	night.enter(120.0)
	for step: int in 600:
		night.advance(DELTA)
		_lamps.refresh(night)
		for channel: int in 3:
			if night.light[channel] + _added()[channel] > 1.0 + 1e-6:
				over.append("step %d, channel %d" % [step, channel])
	assert_eq(over.slice(0, 3), PackedStringArray(), "%d too bright" % over.size())
	assert_between(lit, 30, 60, "quarter hours lit")
	assert_false(_lamps.visible, "out by day after the reset")


## How often the glows' alpha turns from rising to falling or back over `steps` steps of `cycle`,
## and how often it changes faster than the light shown lets it: by LIGHT_MAX_RATE a second over
## the faintest channel of the lamps' colour (§5.12).
func _turns(cycle: DayCycle, steps: int) -> Vector2i:
	var color := Tuning.LAMP_COLOR
	var most := Tuning.LIGHT_MAX_RATE * DELTA / minf(color.r, minf(color.g, color.b)) + 1e-6
	_lamps.refresh(cycle)
	var last := _lamps.self_modulate.a
	var rising := 0
	var turns := Vector2i.ZERO
	for step: int in steps:
		cycle.advance(DELTA)
		_lamps.refresh(cycle)
		var change := int(signf(_lamps.self_modulate.a - last))
		if change != 0 and rising != 0 and change != rising:
			turns.x += 1
		if change != 0:
			rising = change
		turns.y += int(absf(_lamps.self_modulate.a - last) > most)
		last = _lamps.self_modulate.a
	return turns


func test_the_lamps_fade_on_once_a_day_and_out_once() -> void:
	# Nothing flashes (WCAG 2.3.1, M6_PLAN.md §5.6), and nothing pops: through the least day and the
	# reference one, the glows' alpha rises at dusk and falls at dawn, turning only then, and no
	# faster than the light shown changes. As a zone sets the clock back at night, it falls, and
	# turns at dusk.
	for day_seconds: float in [DayCycle.least_day_seconds(), 120.0]:
		var cycle := _cycle(Tuning.DAY_START_HOUR, day_seconds)
		var day := "a day of %.1f s: turns, jumps" % day_seconds
		assert_eq(_turns(cycle, ceili(day_seconds / DELTA)), Vector2i(1, 0), day)
	var night := _cycle(23.0)
	night.start_hour = Tuning.DAY_START_HOUR
	night.enter(120.0)
	var back := "out as the clock goes back, on, out: turns, jumps"
	assert_eq(_turns(night, ceili(120.0 / DELTA)), Vector2i(2, 0), back)
