extends GutTest
## The legends' art (M6_PLAN.md §5.7): each sheet is one row of whole frames, none larger than
## MAX_FRAME; a legend of the pools draws only its own sheets, from assets/legends/<id>/; and
## legend_art.gd draws the same pixels on every run, in the palette's colours.

const Disasters := preload("res://tests/helpers/disaster_fixtures.gd")
const Sample := preload("res://tests/helpers/sample_legend.gd")
const LegendArt := preload("res://tools/art/legend_art.gd")
const Art := preload("res://tests/helpers/art_checks.gd")
const GLOW := preload("res://disasters/glow.tres")


static func _sprites(legend: Legend) -> Array[Sprite2D]:
	var found: Array[Sprite2D] = []
	for child: Node in legend.find_children("*", "Sprite2D", true, false):
		found.append(child as Sprite2D)
	return found


func test_each_sheet_is_one_row_of_whole_frames_none_too_large() -> void:
	# A sheet cut into frames of the wrong width shows a sliver of the next frame (N16). The
	# legends are in the tree, where a legend may draw its sheets as it starts.
	var sheets := 0
	for scene: PackedScene in Disasters.contract_scenes():
		var node := scene.instantiate()
		var legend := node as Legend
		if legend == null:
			node.free()
			continue
		add_child_autofree(legend)
		for sprite: Sprite2D in _sprites(legend):
			if sprite.texture == null or sprite.texture == GLOW:
				continue
			sheets += 1
			var size := Vector2i(sprite.texture.get_size())
			var what := "%s: %s" % [legend.id, sprite.name]
			assert_eq(sprite.vframes, 1, what + ": one row")
			assert_eq(size.x % sprite.hframes, 0, what + ": whole frames")
			assert_lte(float(size.x) / sprite.hframes, float(LegendArt.MAX_FRAME.x), what)
			assert_lte(size.y, LegendArt.MAX_FRAME.y, what)
	assert_gt(sheets, 0, "the sample's totem at least")


func test_each_legend_of_the_pools_draws_only_its_own_art() -> void:
	# tools/art/legends/<id>.gd draws its sheets into assets/legends/<id>/ (§5.7).
	var checked := 0
	for scene: PackedScene in Disasters.scenes():
		var node := scene.instantiate()
		var legend := node as Legend
		if legend != null:
			for sprite: Sprite2D in _sprites(legend):
				if sprite.texture != null and sprite.texture != GLOW:
					checked += 1
					assert_string_starts_with(
						sprite.texture.resource_path,
						"res://assets/legends/%s/" % legend.id,
						"%s: %s" % [legend.id, sprite.name]
					)
		node.free()
	if checked == 0:
		pass_test("no pool has a legend yet")


func test_a_sheet_is_drawn_the_same_every_time_in_the_palettes_colours() -> void:
	var sheet := Sample.sheet()
	assert_eq(sheet.get_data(), Sample.sheet().get_data(), "the same bytes")
	var shares := Art.shares(sheet)
	assert_false(shares.has(Color()), "no colour but the palette's")
	assert_gt(shares.size(), 4, "several of them")
