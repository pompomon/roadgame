extends GutTest
## LegendStill (ENDGAME_PLAN.md §5.8): the frame of its figure that each legend's scene names, whole
## and in full view, whatever its rest pose hides, drawn as the figure draws, and centred, and the
## Vanishing Hitchhiker's (§5.17); and a glow's light, bounded by the ground under it.

const Disasters := preload("res://tests/helpers/disaster_fixtures.gd")
const PIER := preload("res://setpieces/pier.tscn")
const HITCHHIKER := preload("res://world/hitchhiker.tscn")
## The least share of a still's frame that its pixels more opaque than half cover: a frame that
## shows the legend, not a blank one.
const DRAWN_SHARE := 0.1


## The share of the pixels of `still`'s frame that are more opaque than half.
static func _drawn_share(still: LegendStill) -> float:
	var size := Vector2i(still.get_rect().size)
	var image := still.texture.get_image().get_region(Rect2i(still.frame_coords * size, size))
	image.convert(Image.FORMAT_RGBA8)
	var data := image.get_data()
	var drawn := 0
	for i: int in range(3, data.size(), 4):
		drawn += int(data[i] > 127)
	return float(drawn) / (size.x * size.y)


func test_each_legend_has_a_still_of_its_figure_in_full_view() -> void:
	# The Death Worm rests transparent and cropped to nothing, and the Kelpie's horse and Frau
	# Holle's well cropped to nothing: their stills show them whole.
	for scene: PackedScene in Disasters.scenes():
		var legend: Legend = autofree(scene.instantiate())
		var figure := legend.figure
		var still := LegendStill.of(scene)
		var at := String(legend.id)
		assert_not_null(figure, at + ": names its figure")
		assert_not_null(still, at)
		if figure == null or still == null:
			continue
		autofree(still)
		assert_eq(still.id, legend.id, at)
		assert_eq(still.texture, figure.texture, at)
		assert_eq([still.hframes, still.vframes], [figure.hframes, figure.vframes], at)
		assert_eq(still.frame, legend.figure_frame, at + ": its frame")
		assert_false(still.region_enabled, at + ": the whole frame")
		var frame := figure.texture.get_size() / Vector2(figure.hframes, figure.vframes)
		assert_eq(still.get_rect(), Rect2(-frame / 2.0, frame), at + ": centred")
		assert_gte(_drawn_share(still), DRAWN_SHARE, at + ": shows the legend")
		assert_eq([still.modulate, still.visible], [Color.WHITE, true], at + ": in full view")
		var drawn := [
			still.self_modulate,
			still.material,
			still.flip_h,
			still.flip_v,
			still.z_index,
			still.z_as_relative
		]
		var figures := [
			figure.self_modulate,
			figure.material,
			figure.flip_h,
			figure.flip_v,
			figure.z_index,
			figure.z_as_relative
		]
		assert_eq(drawn, figures, at + ": drawn as the figure")


func test_a_small_still_is_scaled_up_by_the_least_whole_number_that_makes_it_large_enough() -> void:
	# The Fairy Ring's toadstool is 10 px high: three times that is STILL_MIN_SIDE. Every other
	# frame is as large already.
	var scaled: Array[StringName] = []
	for scene: PackedScene in Disasters.scenes():
		var still: LegendStill = autofree(LegendStill.of(scene))
		var side := maxf(still.get_rect().size.x, still.get_rect().size.y)
		var by := still.scale.x
		var at := "%s, %.0f px, scaled by %.2f" % [still.id, side, by]
		assert_eq(still.scale.y, by, at + ": square pixels")
		assert_eq(by, roundf(by), at + ": a whole number")
		assert_gte(side * by, Tuning.STILL_MIN_SIDE, at + ": large enough")
		if by > 1.0:
			assert_lt(side * (by - 1.0), Tuning.STILL_MIN_SIDE, at + ": the least such")
			scaled.append(still.id)
	assert_eq(scaled, [&"fairy_ring"] as Array[StringName])


func test_a_glows_still_adds_no_more_light_than_its_ground_leaves_below_white() -> void:
	# The Will-o'-the-Wisp's and the Marfa Lights' figures add light, which their legends' veils
	# and alphas keep from clipping, and a still has neither (docs/M6.md S10). Over each ground, a
	# white texel of a glow's still adds to no channel more than the ground leaves below white: over
	# black it shows whole, over the sea a part, and over white none. Every other still shows whole.
	var pier: Pier = autofree(PIER.instantiate())
	var sea := (pier.get_node("%Sea") as Polygon2D).color
	var grounds: Array[Color] = [Color.BLACK, sea, Color.WHITE]
	var glows: Array[StringName] = []
	for scene: PackedScene in Disasters.scenes():
		var still: LegendStill = autofree(LegendStill.of(scene))
		var blend := still.material as CanvasItemMaterial
		if blend == null or blend.blend_mode != CanvasItemMaterial.BLEND_MODE_ADD:
			for ground: Color in grounds:
				assert_eq(still.strength(ground), 1.0, "%s over %s: whole" % [still.id, ground])
			continue
		glows.append(still.id)
		var tint := still.self_modulate
		for ground: Color in grounds:
			var shown := still.strength(ground)
			var lit := ground + Color(tint.r, tint.g, tint.b) * (tint.a * shown)
			var most := maxf(lit.r, maxf(lit.g, lit.b))
			assert_lte(
				most, 1.0 + 1e-6, "%s over %s, %.3f shown: no clip" % [still.id, ground, shown]
			)
		assert_eq(still.strength(Color.BLACK), 1.0, "%s: whole over black" % still.id)
		assert_between(still.strength(sea), 0.1, 0.9, "%s: a part over the sea" % still.id)
		assert_eq(still.strength(Color.WHITE), 0.0, "%s: none over white" % still.id)
	assert_eq(glows, [&"will_o_wisp", &"marfa_lights"] as Array[StringName])


## ENDGAME_PLAN.md §5.17: her scene is her figure, which waits hidden until she stands.
func test_the_hitchhikers_still_is_her_figure_in_full_view() -> void:
	var hitchhiker: Hitchhiker = autofree(HITCHHIKER.instantiate())
	var still: LegendStill = autofree(LegendStill.of(HITCHHIKER))
	assert_eq(still.id, Hitchhiker.ID)
	assert_eq(still.texture, hitchhiker.texture)
	assert_eq([still.hframes, still.vframes, still.frame], [1, 1, 0])
	assert_eq([still.flip_h, still.flip_v], [hitchhiker.flip_h, hitchhiker.flip_v])
	assert_eq(still.scale, Vector2.ONE, "large enough")
	var frame := Vector2(Hitchhiker.FRAME)
	assert_eq(still.get_rect(), Rect2(-frame / 2.0, frame), "centred")
	assert_eq([still.modulate, still.visible], [Color.WHITE, true], "in full view")
	assert_gte(_drawn_share(still), DRAWN_SHARE, "shows her")


func test_a_scene_that_isnt_a_legend_or_names_no_figure_has_no_still() -> void:
	assert_null(LegendStill.of(PIER))
	assert_push_error("LegendStill: res://setpieces/pier.tscn isn't a legend")
	assert_null(LegendStill.of(null))
	assert_push_error("LegendStill: <null> isn't a legend")
	# The sample legend, a contract tests' fixture, names none.
	assert_null(LegendStill.of(Disasters.SAMPLE))
	assert_push_error("LegendStill: sample_legend names no figure")
