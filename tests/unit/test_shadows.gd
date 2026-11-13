extends GutTest
## Shadows (DAYNIGHT_PLAN.md §5.11): a black copy of each prop's frame and of the car's, laid on the
## ground along the clock's shadow, all in one group at the clock's shadow alpha.

const CAR_SCENE := preload("res://car/car.tscn")
const Fixtures := preload("res://tests/helpers/road_fixtures.gd")
const FOOT := Vector2(300.0, 200.0)
const AREAS: Array[StringName] = [&"city", &"rural", &"meadows", &"village", &"desert"]

var _shadows: Shadows


func before_each() -> void:
	_shadows = add_child_autofree(Shadows.new())


## A prop of `frames` 16 × 24-pixel frames that stands at (8, 20), whose shadow is `shadow`.
static func _prop(shadow: PropDef.Shadow, rise := 0, frames := 1) -> PropDef:
	var def := PropDef.new()
	def.id = &"prop"
	var image := Image.create_empty(16 * frames, 24, false, Image.FORMAT_RGBA8)
	def.texture = ImageTexture.create_from_image(image)
	def.region = Rect2i(0, 0, 16, 24)
	def.frames = frames
	def.fps = 4.0 if frames > 1 else 0.0
	def.foot = Vector2i(8, 20)
	def.shadow = shadow
	def.shadow_rise = rise
	return def


## The clock at `hour`, its shadows shown.
static func _clock(hour: float) -> DayCycle:
	var cycle := DayCycle.new()
	cycle.start_hour = hour
	cycle.enter(120.0)
	cycle.snap()
	return cycle


## Where `cast` lays the texel `texel` of its frame, from the frame's top left.
static func _laid(cast: Shadows.Cast, texel: Vector2) -> Vector2:
	return Shadows.laid(cast) * (texel + cast.sprite.offset)


static func _corners(rect: Rect2) -> Array[Vector2]:
	var top_right := Vector2(rect.end.x, rect.position.y)
	var bottom_left := Vector2(rect.position.x, rect.end.y)
	return [rect.position, top_right, rect.end, bottom_left]


func _car() -> CarController:
	var buffer := RoadBuffer.new(RoadGenerator.new(1, Fixtures.schedule()))
	buffer.start()
	var car: CarController = CAR_SCENE.instantiate()
	car.sim = CarSim.new(buffer)
	car.input = InputRouter.new()
	add_child_autofree(car)
	car.add_child(car.input)
	car.input.enabled = false
	return car


func test_an_upright_props_shadow_falls_from_its_foot_across_the_light() -> void:
	# A texel h pixels above the foot casts its shadow h times the clock's shadow from the foot. The
	# frame's width lies across the shadow on the ground, a pixel of it a pixel's width of ground.
	# As the light is on the far side, its left stays on the left: the shadow is the frame upside
	# down, as a flat sprite's would be, never turned round (N44).
	var cast := _shadows.add(_prop(PropDef.Shadow.UPRIGHT), FOOT)
	assert_eq(cast.sprite.region_rect, Rect2(0, 0, 16, 20), "the rows above its foot")
	assert_eq(cast.sprite.self_modulate, Color.BLACK)
	var wrong := PackedStringArray()
	var shown := 0
	for quarter: int in 96:
		var cycle := _clock(quarter / 4.0)
		_shadows.refresh(cycle, null)
		if not _shadows.visible:
			continue
		shown += 1
		# A texel to the right on the foot's row. Vector2 is single precision, so not measured as
		# the difference of two points 300 pixels out.
		var right := Shadows.laid(cast).x
		var across := Iso.world_to_tile(right)
		var along := Iso.world_to_tile(cycle.shadow).normalized()
		if not _laid(cast, Vector2(8.0, 8.0)).is_equal_approx(FOOT + 12.0 * cycle.shadow):
			wrong.append("%.2f: the top" % cycle.hour())
		if absf(across.normalized().dot(along)) > 1e-5:
			wrong.append("%.2f: not across" % cycle.hour())
		if not is_equal_approx(across.length() * Iso.WIDTH_PX, 1.0):
			wrong.append("%.2f: not a pixel wide" % cycle.hour())
		if right.x <= 0.0:
			wrong.append("%.2f: turned round" % cycle.hour())
	assert_gt(shown, 80, "quarter hours with shadows")
	assert_eq(wrong, PackedStringArray())


func test_a_walls_shadow_falls_from_its_base_line() -> void:
	# A wall along the tile y axis stands on a line up-right across its frame, shadow_rise above its
	# foot in the foot's column. A texel on that line lies on the ground, where it is; one h pixels
	# above it casts its shadow h times the clock's shadow from there.
	var def := _prop(PropDef.Shadow.WALL, 2)
	var cast := _shadows.add(def, FOOT)
	assert_eq(cast.sprite.region_rect, Rect2(0, 0, 16, 24), "all its rows")
	var wrong := PackedStringArray()
	for hour: float in [7.0, 12.0, 15.0, 17.0, 0.0]:
		var cycle := _clock(hour)
		_shadows.refresh(cycle, null)
		for x: float in [0.0, 5.0, 8.0, 16.0]:
			var base := Vector2(x, def.foot.y - def.shadow_rise - (x - def.foot.x) / 2.0)
			var ground := FOOT + base - Vector2(def.foot)
			if not _laid(cast, base).is_equal_approx(ground):
				wrong.append("%.0f:00, x %.0f: the base" % [hour, x])
			var up := _laid(cast, base - Vector2(0.0, 6.0))
			if not up.is_equal_approx(ground + 6.0 * cycle.shadow):
				wrong.append("%.0f:00, x %.0f: 6 px up" % [hour, x])
	assert_eq(wrong, PackedStringArray())


func test_flat_props_cast_none() -> void:
	assert_null(_shadows.add(_prop(PropDef.Shadow.NONE), FOOT))
	_shadows.remove(null)
	assert_eq(_shadows.count(), 0)
	assert_eq(_shadows.get_child_count(true), 0, "no sprite")


func test_the_shadows_show_at_the_clocks_alpha_as_one() -> void:
	# Each cast is opaque black, and the group shows them at the clock's alpha, so that where two
	# overlap the ground is no darker than under one (P8). Without a clock, or with no shadow,
	# the group hides, and costs nothing.
	var cast := _shadows.add(_prop(PropDef.Shadow.UPRIGHT), FOOT)
	_shadows.refresh(null, null)
	assert_false(_shadows.visible, "without a clock")
	var noon := _clock((Tuning.SUN_RISE_HOUR + Tuning.SUN_SET_HOUR) / 2.0)
	_shadows.refresh(noon, null)
	assert_true(_shadows.visible, "at noon")
	assert_almost_eq(_shadows.self_modulate.a, Tuning.SUN_SHADOW_ALPHA, 1e-6)
	assert_eq(cast.sprite.self_modulate, Color.BLACK)
	_shadows.refresh(_clock(Tuning.SUN_SET_HOUR), null)
	assert_false(_shadows.visible, "as the moon takes over")


func test_the_shadows_turn_with_the_clock() -> void:
	var cast := _shadows.add(_prop(PropDef.Shadow.UPRIGHT), FOOT)
	var cycle := _clock(9.0)
	_shadows.refresh(cycle, null)
	var morning := _laid(cast, Vector2(8.0, 8.0))
	# Six hours on, in one step that the shadow can follow.
	cycle.advance(30.0)
	_shadows.refresh(cycle, null)
	assert_almost_eq(cycle.hour(), 15.0, 1e-6)
	var afternoon := _laid(cast, Vector2(8.0, 8.0))
	assert_gt(morning.x, FOOT.x, "in the morning, to the right")
	assert_lt(afternoon.x, FOOT.x, "in the afternoon, to the left")
	assert_almost_eq(afternoon, FOOT + 12.0 * cycle.shadow, Vector2.ONE * 1e-3)


func test_removed_shadows_give_their_sprites_back() -> void:
	var def := _prop(PropDef.Shadow.UPRIGHT)
	var casts: Array[Shadows.Cast] = []
	for i: int in 3:
		casts.append(_shadows.add(def, FOOT + Vector2(10.0 * i, 0.0)))
	assert_eq(_shadows.count(), 3)
	_shadows.remove(casts[1])
	_shadows.remove(casts[1])
	assert_eq(_shadows.count(), 2, "once")
	assert_false(casts[1].sprite.visible, "hidden")
	var again := _shadows.add(def, FOOT)
	assert_same(again.sprite, casts[1].sprite, "the same sprite again")
	assert_eq(_shadows.get_child_count(true), 3)
	assert_eq(_shadows.get_child_count(), 0, "its own parts, which simulate() walks past (C20)")


func test_the_cars_shadow_follows_its_frame_and_fades_with_it() -> void:
	# The car's shadow is an upright prop's, from its foot, in its frame. A legend that shrinks the
	# car shrinks its shadow, and one that makes it clear makes its shadow as clear; a hidden car
	# casts none (M6_PLAN.md §5.4). It is laid by its sprite's transform, and measured by its frame,
	# though its sprite was a prop's.
	var used := _shadows.add(_prop(PropDef.Shadow.UPRIGHT), FOOT)
	_shadows.remove(used)
	var car := _car()
	var body: Sprite2D = car.get_node("%Body")
	var cycle := _clock(9.0)
	car.sim.angle = PI / 2.0
	await wait_physics_frames(2)
	_shadows.refresh(cycle, car)
	var cast := _shadows.car_cast()
	assert_not_null(cast)
	assert_same(cast.sprite, used.sprite, "a prop's sprite again")
	assert_null(cast.sprite.material, "laid by its transform")
	assert_true(cast.sprite.visible)
	assert_eq(cast.sprite.texture, body.texture)
	assert_eq(cast.sprite.frame, body.frame, "the body's frame")
	var first := cast.sprite.frame
	assert_eq(cast.sprite.region_rect.size.y, float(CarController.FOOT.y), "rows above its foot")
	var top := Vector2(CarController.FOOT) - Vector2(0.0, 6.0)
	assert_almost_eq(_laid(cast, top), car.position + 6.0 * cycle.shadow, Vector2.ONE * 1e-3)
	car.sim.angle = 0.0
	await wait_physics_frames(2)
	car.scale = Vector2.ONE * 0.5
	car.modulate.a = 0.4
	_shadows.refresh(cycle, car)
	assert_eq(cast.sprite.frame, body.frame, "its new frame")
	assert_ne(cast.sprite.frame, first, "turned")
	assert_almost_eq(_laid(cast, top), car.position + 3.0 * cycle.shadow, Vector2.ONE * 1e-3)
	assert_almost_eq(cast.sprite.self_modulate.a, 0.4, 1e-6, "as clear as the car")
	car.modulate.a = 0.0
	_shadows.refresh(cycle, car)
	assert_false(cast.sprite.visible, "a car made clear")
	car.modulate.a = 1.0
	car.hide()
	_shadows.refresh(cycle, car)
	assert_false(cast.sprite.visible, "a hidden car")
	car.show()
	_shadows.refresh(cycle, car)
	assert_true(cast.sprite.visible, "shown again")
	assert_same(_shadows.car_cast(), cast, "the same shadow")
	await wait_process_frames(1)
	var measured := RenderingServer.debug_canvas_item_get_rect(cast.sprite.get_canvas_item())
	assert_eq(measured, cast.sprite.get_rect(), "measured by its frame")


func test_the_clock_turns_the_props_shadows_but_no_sprite() -> void:
	# Each kind's material lays its props' shadows, so that as the clock turns, every frame, no
	# sprite changes, however many there are (C20).
	var upright := _shadows.add(_prop(PropDef.Shadow.UPRIGHT, 2), FOOT)
	var wall := _shadows.add(_prop(PropDef.Shadow.WALL, 2), FOOT + Vector2(40.0, 0.0))
	var from := Transform2D(0.0, FOOT - Vector2(0.0, 2.0))
	assert_eq(upright.sprite.transform, from, "where it falls from")
	var placed: Array[Transform2D] = [upright.sprite.transform, wall.sprite.transform]
	var cycle := _clock(9.0)
	_shadows.refresh(cycle, null)
	var morning: Array[Transform2D] = [Shadows.laid(upright), Shadows.laid(wall)]
	cycle.advance(30.0)
	_shadows.refresh(cycle, null)
	var after: Array[Transform2D] = [upright.sprite.transform, wall.sprite.transform]
	assert_eq(after, placed, "the sprites stay")
	assert_ne(Shadows.laid(upright), morning[0], "an upright prop's shadow turns")
	assert_ne(Shadows.laid(wall), morning[1], "a wall's turns")


func test_each_props_shadow_is_drawn_wherever_it_falls() -> void:
	# Godot culls a sprite, and fits the group around its sprites, by the rect it measures each by,
	# and a prop's material lays its shadow beyond its frame. So each prop's shadow is measured by
	# its reach, which holds its frame however it lies: at each quarter hour, and as long as a
	# shadow can be, every way round (C20, P11).
	var casts: Array[Shadows.Cast] = []
	for area: StringName in AREAS:
		for def: PropDef in (load("res://areas/%s.tres" % area) as AreaDef).props:
			var cast := _shadows.add(def, FOOT)
			if cast != null:
				casts.append(cast)
	var cycles: Array[DayCycle] = []
	var longest := 0.0
	for minute: int in 24 * 60:
		longest = maxf(longest, DayCycle.shadow_at(minute / 60.0).length())
		if minute % 15 == 0:
			cycles.append(_clock(minute / 60.0))
	for turn: int in 64:
		var cycle := DayCycle.new()
		cycle.shadow = Vector2.from_angle(TAU * turn / 64.0) * longest
		cycle.shadow_alpha = 1.0
		cycles.append(cycle)
	var wrong := PackedStringArray()
	for cycle: DayCycle in cycles:
		_shadows.refresh(cycle, null)
		for cast: Shadows.Cast in casts:
			var rid := cast.sprite.get_canvas_item()
			var measured := RenderingServer.debug_canvas_item_get_rect(rid).grow(1e-3)
			var lay := cast.sprite.transform.affine_inverse() * Shadows.laid(cast)
			for corner: Vector2 in _corners(cast.sprite.get_rect()):
				if not measured.has_point(lay * corner):
					wrong.append("%s, %s: %s" % [cast.def.id, cycle.shadow, corner])
	assert_gt(casts.size(), 20, "the props that cast")
	assert_eq(wrong.slice(0, 3), PackedStringArray(), "%d corners out" % wrong.size())


func test_the_shader_lays_each_corner_where_laid_puts_it() -> void:
	# The other tests measure the shadows by laid(), and no test can draw: headless, the shader never
	# runs. So its vertex() runs here, as written, in each kind's material as the clock turns. Drawn,
	# the shader and laid() lay every prop alike within 1 px (P11).
	var code := Shadows.LAY.code
	var start := code.find("VERTEX =", code.find("void vertex()"))
	var lay := "VERTEX"
	if start >= 0:
		start += "VERTEX =".length()
		lay = code.substr(start, code.find(";", start) - start)
	var vertex := Expression.new()
	var names := PackedStringArray(["lay_x", "lay_y", "VERTEX"])
	assert_eq(vertex.parse(lay.replace("vec2(", "Vector2("), names), OK, lay)
	var casts: Array[Shadows.Cast] = [
		_shadows.add(_prop(PropDef.Shadow.UPRIGHT), FOOT),
		_shadows.add(_prop(PropDef.Shadow.WALL, 2), FOOT),
	]
	var wrong := PackedStringArray()
	for hour: int in 24:
		_shadows.refresh(_clock(hour), null)
		for cast: Shadows.Cast in casts:
			var material := cast.sprite.material as ShaderMaterial
			var lays: Array = [
				material.get_shader_parameter(&"lay_x"), material.get_shader_parameter(&"lay_y")
			]
			for corner: Vector2 in _corners(cast.sprite.get_rect()):
				var drawn: Variant = vertex.execute(lays + [corner])
				if (
					vertex.has_execute_failed()
					or not drawn is Vector2
					or not (cast.sprite.transform * (drawn as Vector2)).is_equal_approx(
						Shadows.laid(cast) * corner
					)
				):
					var kind: String = PropDef.Shadow.find_key(cast.def.shadow)
					wrong.append("%s at %d h: %s" % [kind, hour, corner])
	assert_eq(wrong.slice(0, 3), PackedStringArray(), "%d corners laid elsewhere" % wrong.size())
