extends GutTest
## Lamps (DAYNIGHT_PLAN.md §5.12): each prop's lights glow at night over the veil, adding no more
## light than the veil takes away, and by day they are out.

const DELTA := 1.0 / 60.0

var _lamps: Lamps


func before_each() -> void:
	_lamps = add_child_autofree(Lamps.new())


## A prop with a light and a pool of light, as the City's lamp has.
static func _lamp() -> PropDef:
	var def := PropDef.new()
	def.id = &"lamp"
	def.lights.append(Rect2(0, -40, 12, 10))
	def.light_pools.append(Rect2(-26, -16, 64, 32))
	return def


## A zone's clock at `p_hour`, showing that hour's light.
static func _cycle(p_hour: float, day_seconds := 120.0) -> DayCycle:
	var cycle := DayCycle.new()
	cycle.start_hour = p_hour
	cycle.enter(day_seconds)
	cycle.snap()
	return cycle


## What a glow's centre adds to each channel of the pixel under it.
func _added() -> Color:
	return Tuning.LAMP_COLOR * _lamps.modulate.a


func test_each_light_and_pool_glows_where_its_prop_puts_it() -> void:
	var glows := _lamps.add(_lamp(), Vector2(100, 50))
	assert_eq(glows.size(), 2)
	assert_eq(_lamps.count(), 2)
	assert_eq(glows[0].position, Vector2(106, 15), "the light's centre")
	assert_eq(glows[0].scale, Vector2(12, 10) / 64.0, "it fills its box")
	assert_eq(glows[0].self_modulate.a, 1.0)
	assert_eq(glows[1].position, Vector2(106, 50), "the pool's centre")
	assert_eq(glows[1].scale, Vector2(1.0, 0.5))
	assert_almost_eq(glows[1].self_modulate.a, Tuning.LAMP_POOL_SHARE, 1e-6, "a pool is fainter")
	# Each adds light over the veil, which it lights, as a legend's glow does (M6_PLAN.md §5.5).
	for glow: Sprite2D in glows:
		assert_eq(glow.texture, Lamps.GLOW)
		assert_eq(glow.material, Lamps.GLOW_MATERIAL)
		assert_eq(glow.z_index, Tuning.GLOW_Z)
		assert_false(glow.z_as_relative)
	assert_eq(Lamps.GLOW_MATERIAL.blend_mode, CanvasItemMaterial.BLEND_MODE_ADD)
	assert_gt(Tuning.GLOW_Z, Tuning.VEIL_Z)
	assert_eq(_lamps.add(PropDef.new(), Vector2.ZERO).size(), 0, "a prop without lights")
	assert_eq(_lamps.count(), 2)


func test_glows_are_reused() -> void:
	var first := _lamps.add(_lamp(), Vector2.ZERO)
	_lamps.remove(first)
	assert_eq(_lamps.count(), 0)
	for glow: Sprite2D in first:
		assert_false(glow.visible)
	var again := _lamps.add(_lamp(), Vector2(10, 10))
	assert_eq(_lamps.get_child_count(), 2, "no new glows")
	assert_eq(_lamps.count(), 2)
	for glow: Sprite2D in again:
		assert_true(glow.visible)
	# The light takes the pool's glow, the last hidden, and is as bright as a light.
	assert_eq(again[0], first[1])
	assert_eq(again[0].self_modulate.a, 1.0)


func test_out_by_day_and_without_a_clock_and_on_at_night() -> void:
	_lamps.add(_lamp(), Vector2.ZERO)
	_lamps.refresh(null)
	assert_false(_lamps.visible, "no clock")
	_lamps.refresh(_cycle(12.0))
	assert_false(_lamps.visible, "at noon")
	assert_eq(_lamps.modulate.a, 0.0)
	_lamps.refresh(_cycle(0.0))
	assert_true(_lamps.visible, "at midnight")
	assert_eq(_lamps.modulate, Color(Tuning.LAMP_COLOR, Tuning.LAMP_ALPHA))
	# At dusk the light is still full in red, so they wait for the night; at dawn they are faint.
	assert_eq(Lamps.strength(Tuning.LIGHT_DUSK), 0.0, "at dusk")
	assert_between(Lamps.strength(Tuning.LIGHT_DAWN), 0.01, 0.25, "at dawn")
	assert_eq(Lamps.strength(Tuning.LIGHT_NIGHT), 1.0, "at night")


func test_a_glow_never_adds_more_than_the_veil_takes_away() -> void:
	# Over a white pixel the veil leaves the light, and a glow's centre adds to it: never past white
	# (M6_PLAN.md S10), at every quarter hour and as a zone sets the clock back at night.
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
	var last := _lamps.modulate.a
	var rising := 0
	var turns := Vector2i.ZERO
	for step: int in steps:
		cycle.advance(DELTA)
		_lamps.refresh(cycle)
		var change := int(signf(_lamps.modulate.a - last))
		if change != 0 and rising != 0 and change != rising:
			turns.x += 1
		if change != 0:
			rising = change
		turns.y += int(absf(_lamps.modulate.a - last) > most)
		last = _lamps.modulate.a
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
