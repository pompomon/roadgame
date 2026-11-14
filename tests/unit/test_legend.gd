extends GutTest
## The legend kit (docs/M6.md §5.3–§5.5), on the sample legend: the veil follows the view and
## darkens the world through the first beat, at night only what the night hasn't
## (docs/DAYNIGHT.md §5.6); the car, the props and the parts sort under it, and the glows over it;
## the standing parts and the car's double stand on the stage and leave it with the legend; and no
## frame shows both the car and its double, nor neither until it goes. test_view_veil.gd checks
## that the veil covers every view.

const Disasters := preload("res://tests/helpers/disaster_fixtures.gd")
const Sample := preload("res://tests/helpers/sample_legend.gd")
const DELTA := 1.0 / 60.0

var _stage: Node2D
var _car: CarController
var _camera: CameraRig


func before_each() -> void:
	_stage = Disasters.stage(self)
	_car = Disasters.car(self, 0.0, _stage)
	_camera = Disasters.camera(self)


## The sample legend, for the car, the camera and the stage. It doesn't play yet.
func _legend() -> Legend:
	var legend := Disasters.disaster(self, Disasters.SAMPLE, _car, _camera) as Legend
	legend.stage = _stage
	return legend


## The frames from play() to the end of `legend`'s beats.
static func _frames(with_params: DisasterParams) -> int:
	return ceili(Sample.duration(with_params) / DELTA)


static func _veil(legend: Legend) -> Polygon2D:
	return legend.get_node("Veil") as Polygon2D


## The car's double, once `legend` has taken the car, on the stage or else in the legend.
static func _double(legend: Legend) -> Sprite2D:
	for part: Sprite2D in legend.staged():
		if part.name == "Double":
			return part
	return legend.get_node_or_null("Double") as Sprite2D


func test_the_veil_follows_the_view_as_it_pans_and_shakes_also_after_the_end() -> void:
	# The camera may still shake once a legend has finished (N28). It steps first, as in the game.
	var legend := _legend()
	var params := Disasters.params()
	watch_signals(legend)
	legend.play(params)
	_camera.shake(1.0, Sample.duration(params) + 1.0)
	var off := 0.0
	var shook := 0
	for _frame: int in _frames(params) + 30:
		_camera.position += Vector2(90.0, -45.0)
		simulate(_camera, 1, DELTA)
		simulate(legend, 1, DELTA)
		var centre := _camera.global_position + _camera.offset
		off = maxf(off, _veil(legend).global_position.distance_to(centre))
		shook += int(_camera.offset != Vector2.ZERO)
	assert_signal_emit_count(legend, "finished", 1, "past the end")
	assert_gt(shook, 0, "with a shake")
	assert_almost_eq(off, 0.0, 1e-3, "the veil on the view's centre")


func test_in_the_games_frames_the_veil_follows_the_view_of_the_same_frame() -> void:
	# main.tscn has World, and the legend in it, before the camera in the tree, and the camera pans
	# and shakes in its own physics step. Real frames: each starts after the last has drawn (N41).
	var legend := _legend()
	var later := Disasters.camera(self)
	later.car = _car
	later.position = Vector2(-300.0, 200.0)
	legend.camera = later
	legend.play(Disasters.params())
	later.shake(1.0, 1.0)
	await get_tree().physics_frame
	var off := 0.0
	var moved := 0.0
	var was := later.global_position + later.offset
	for _frame: int in 10:
		await get_tree().physics_frame
		var centre := later.global_position + later.offset
		off = maxf(off, _veil(legend).global_position.distance_to(centre))
		moved = maxf(moved, centre.distance_to(was))
		was = centre
	assert_gt(moved, 1.0, "the view moves each frame")
	assert_almost_eq(off, 0.0, 1e-3, "the veil on the view's centre")


func test_the_veil_darkens_the_car_the_props_and_the_parts_but_not_the_glows() -> void:
	# The veil multiplies what is under it, and the glows add light over it (N27).
	var legend := _legend()
	var prop := Sprite2D.new()
	_stage.add_child(prop)
	var params := Disasters.params()
	legend.play(params)
	simulate(legend, _frames(params), DELTA)
	var veil := _veil(legend)
	var veil_z := Disasters.z(veil)
	assert_eq(veil_z, Tuning.VEIL_Z)
	assert_gt(Tuning.GLOW_Z, veil_z)
	var under: Array[CanvasItem] = [prop, _car.get_node("%Body"), _car.get_node("%Smoke")]
	var glows := 0
	for item: CanvasItem in Disasters.drawables(legend):
		var material := item.material as CanvasItemMaterial
		if material != null and material.blend_mode == CanvasItemMaterial.BLEND_MODE_ADD:
			glows += 1
			assert_eq(Disasters.z(item), Tuning.GLOW_Z, "%s: a glow, over the veil" % item.name)
		elif item != veil:
			under.append(item)
	under.append_array(Disasters.particles(legend))
	assert_eq(glows, 3, "the sample's glows")
	assert_has(under, _double(legend), "with the double")
	for item: CanvasItem in under:
		assert_lt(Disasters.z(item), veil_z, "%s: under the veil" % item.name)


func test_the_veil_darkens_the_world_through_the_first_beat() -> void:
	# A multiply ignores alpha, so the veil fades in by its colour (S4, N8).
	var legend := _legend()
	var params := Disasters.params()
	legend.play(params)
	var veil := _veil(legend)
	var worst := 0.0
	var at := 0
	for frame: int in range(1, _frames(params) + 2):
		simulate(legend, 1, DELTA)
		var share := clampf((frame * DELTA - params.delay) / Sample.BEATS[0], 0.0, 1.0)
		var expected := Color.WHITE.lerp(Tuning.VEIL_NIGHT, share)
		var tint := Disasters.veil_tint(veil)
		var off := maxf(
			absf(tint.r - expected.r), maxf(absf(tint.g - expected.g), absf(tint.b - expected.b))
		)
		if off > worst:
			worst = off
			at = frame
	assert_almost_eq(worst, 0.0, 1e-3, "the veil's colour, worst on frame %d" % at)


func test_at_night_a_veil_darkens_only_what_the_night_hasnt() -> void:
	# Under the night's veil, the world shows the darker of the light and the legend's own colour
	# in each channel at the end of the first beat. A veil with nothing left to darken isn't drawn
	# (docs/DAYNIGHT.md §5.6).
	var params := Disasters.params()
	var frames := ceili((params.delay + Sample.BEATS[0]) / DELTA) + 1
	var lights: Array[Color] = [
		Color.WHITE,
		Tuning.LIGHT_DAWN,
		Tuning.LIGHT_DUSK,
		Tuning.LIGHT_NIGHT,
		Tuning.LIGHT_DUSK.lerp(Tuning.LIGHT_NIGHT, 0.5),
	]
	for kind: Legend.Veil in [Legend.Veil.DUSK, Legend.Veil.NIGHT]:
		var own := Tuning.VEIL_DUSK if kind == Legend.Veil.DUSK else Tuning.VEIL_NIGHT
		for light: Color in lights:
			var why := "%s veil in %s" % [Legend.Veil.keys()[kind], light]
			var legend := _legend()
			legend.veil_kind = kind
			legend.ambient = light
			legend.play(params)
			var veil := _veil(legend)
			var drawn := 0
			for _frame: int in frames:
				simulate(legend, 1, DELTA)
				drawn += int(veil.modulate.a > 0.0)
			var tint := Disasters.veil_tint(veil)
			var world := light * tint
			var darker := Color(minf(light.r, own.r), minf(light.g, own.g), minf(light.b, own.b))
			var off := maxf(
				absf(world.r - darker.r), maxf(absf(world.g - darker.g), absf(world.b - darker.b))
			)
			assert_almost_eq(off, 0.0, 1e-6, why + ": the world shows the darker")
			assert_lte(maxf(tint.r, maxf(tint.g, tint.b)), 1.0, why + ": the veil only darkens")
			if light.r <= own.r and light.g <= own.g and light.b <= own.b:
				assert_eq(drawn, 0, why + ": frames with the veil drawn")
			else:
				assert_gt(drawn, 0, why + ": frames with the veil drawn")


func test_play_stands_the_standing_parts_on_the_stage_where_they_were() -> void:
	var legend := _legend()
	var params := Disasters.params()
	var totem := legend.standing[0]
	var at := params.origin_world + totem.position
	legend.play(params)
	assert_eq(totem.get_parent(), _stage, "on the stage")
	assert_eq(totem.global_position, at, "where it stood in the legend")
	assert_eq(legend.staged(), [totem] as Array[Sprite2D])
	assert_false(Disasters.shows(totem), "still hidden")


func test_freeing_the_legend_takes_its_parts_off_the_stage() -> void:
	var legend := _legend()
	var params := Disasters.params()
	legend.play(params)
	simulate(legend, _frames(params), DELTA)
	assert_eq(_stage.get_child_count(), 3, "the car, the totem and the double")
	legend.free()
	assert_eq(_stage.get_children(), [_car] as Array[Node], "only the car")
	assert_no_new_orphans()


func test_the_double_stands_where_the_car_stopped_as_it_rises() -> void:
	# It sorts with the props by its feet, so it rises by its offset (N7).
	var legend := _legend()
	var params := Disasters.params()
	legend.play(params)
	var moved := 0.0
	var rose := 0.0
	for _frame: int in _frames(params):
		simulate(legend, 1, DELTA)
		var made := _double(legend)
		if made != null:
			moved = maxf(moved, made.global_position.distance_to(_car.global_position))
			rose = maxf(rose, -CarController.FOOT.y - made.offset.y)
	assert_not_null(_double(legend), "the double came")
	assert_eq(moved, 0.0, "its feet on the car's")
	assert_almost_eq(rose, Sample.LIFT, 1e-4, "it rose")


func test_no_frame_shows_both_the_car_and_its_double_nor_neither_until_it_goes() -> void:
	# The double takes the car's place in the same frame (§5.4, N6).
	var legend := _legend()
	var params := Disasters.params()
	var body: Sprite2D = _car.get_node("%Body")
	var goes := params.delay + Sample.BEATS[0] + Sample.BEATS[1]
	legend.play(params)
	var both := 0
	var neither := 0
	for frame: int in range(1, _frames(params) + 1):
		simulate(legend, 1, DELTA)
		var made := _double(legend)
		var car_shows := Disasters.shows(body)
		var double_shows := made != null and Disasters.shows(made)
		both += int(car_shows and double_shows)
		neither += int(not car_shows and not double_shows and frame * DELTA < goes)
	assert_not_null(_double(legend), "the double came")
	assert_eq(both, 0, "frames with both")
	assert_eq(neither, 0, "frames with neither before the car goes")


func test_a_long_frame_still_shows_the_ends_of_the_beats_it_steps_over() -> void:
	# A hitch may step over beats; each still ends as it should (S7, N12).
	var legend := _legend()
	var params := Disasters.params()
	var totem := legend.standing[0]
	var ring: Polygon2D = legend.get_node("%Ring")
	legend.play(params)
	var into := params.delay + Sample.BEATS[0] + Sample.BEATS[1] + Sample.BEATS[2] * 0.5
	simulate(legend, 1, into)
	assert_eq(totem.modulate.a, 1.0, "the totem has risen")
	assert_eq(ring.scale, Vector2.ONE, "the ring has grown")
	assert_eq(_car.modulate.a, 0.0, "the car is taken")
	var made := _double(legend)
	assert_not_null(made, "by its double")
	if made != null:
		assert_eq(made.offset.y, -CarController.FOOT.y - Sample.LIFT, "which has risen")


func test_without_a_stage_the_parts_stay_in_the_legend() -> void:
	var legend := Disasters.disaster(self, Disasters.SAMPLE, _car, _camera) as Legend
	var params := Disasters.params()
	var totem := legend.standing[0]
	legend.play(params)
	simulate(legend, _frames(params), DELTA)
	assert_eq(totem.get_parent(), legend, "the totem")
	var made := _double(legend)
	assert_not_null(made, "the double")
	if made != null:
		assert_eq(made.get_parent(), legend, "the double")
	assert_eq(legend.staged(), [] as Array[Sprite2D], "nothing on a stage")


func test_without_a_car_there_is_nothing_to_take() -> void:
	var legend := Disasters.disaster(self, Disasters.SAMPLE, null, _camera) as Legend
	legend.stage = _stage
	assert_null(legend.take_car())
	assert_eq(legend.staged(), [] as Array[Sprite2D])


func test_a_car_that_shows_at_the_end_is_an_error() -> void:
	var legend := _legend()
	var params := Disasters.params()
	watch_signals(legend)
	legend.play(params)
	var taken := params.delay + Sample.BEATS[0] + Sample.BEATS[1]
	simulate(legend, ceili(taken / DELTA), DELTA)
	assert_eq(_car.modulate.a, 0.0, "taken")
	_car.modulate.a = 1.0
	simulate(legend, _frames(params), DELTA)
	assert_push_error("the car still shows at its end")
	assert_signal_emit_count(legend, "finished", 1, "it still ends")
