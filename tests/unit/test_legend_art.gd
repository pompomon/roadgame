extends GutTest
## The legends' art (docs/M6.md §5.7): each sheet, a particle sheet too, is one row of whole frames,
## none larger than MAX_FRAME; a legend of the pools draws only its own sheets, from
## assets/legends/<id>/; legend_art.gd draws the same pixels on every run, in the palette's colours;
## and so does each legend's art script (POOLS_PLAN.md §5.6).

const Disasters := preload("res://tests/helpers/disaster_fixtures.gd")
const Sample := preload("res://tests/helpers/sample_legend.gd")
const LegendArt := preload("res://tools/art/legend_art.gd")
const Art := preload("res://tests/helpers/art_checks.gd")
const GLOW := preload("res://disasters/glow.tres")
## The legends' art scripts, as tools/art/make_legends.gd runs them.
const SCRIPTS := "res://tools/art/legends"
## Where the bytes test draws each script's sheets, once into each.
const RUNS: Array[String] = ["user://legend_art_a", "user://legend_art_b"]


## A sheet that a part of a legend draws, and the frames across and down that it is cut into.
class Sheet:
	extends RefCounted
	var node: CanvasItem
	var texture: Texture2D
	var frames: Vector2i


func after_each() -> void:
	for run: String in RUNS:
		_remove(run)


## The sheets that `legend`'s sprites and particles draw, but the glow (POOLS_PLAN.md §5.6). A
## CPUParticles2D's sheet is cut as the material it draws with animates particles, or is one frame.
## A shader may cut a sheet any way, so a part drawn with one gives no frames.
static func _sheets(legend: Legend) -> Array[Sheet]:
	var found: Array[Sheet] = []
	for child: Node in legend.find_children("*", "", true, false):
		var sheet := Sheet.new()
		sheet.node = child as CanvasItem
		sheet.frames = Vector2i.ONE
		var sprite := child as Sprite2D
		var emitter := child as CPUParticles2D
		if sprite != null:
			sheet.texture = sprite.texture
			sheet.frames = Vector2i(sprite.hframes, sprite.vframes)
		elif emitter != null:
			sheet.texture = emitter.texture
			var animated := Disasters.material_of(emitter) as CanvasItemMaterial
			if animated != null and animated.particles_animation:
				sheet.frames = Vector2i(
					animated.particles_anim_h_frames, animated.particles_anim_v_frames
				)
		if sheet.texture == null or sheet.texture == GLOW:
			continue
		if Disasters.material_of(sheet.node) is ShaderMaterial:
			sheet.frames = Vector2i.ZERO
		found.append(sheet)
	return found


## Removes `dir` and all in it, if it is there.
static func _remove(dir: String) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	for sub: String in DirAccess.get_directories_at(dir):
		_remove(dir.path_join(sub))
	for file: String in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(file))
	DirAccess.remove_absolute(dir)


## The bytes of each file in `dir`, by its name.
static func _files(dir: String) -> Dictionary[String, PackedByteArray]:
	var found: Dictionary[String, PackedByteArray] = {}
	if DirAccess.dir_exists_absolute(dir):
		for file: String in DirAccess.get_files_at(dir):
			found[file] = FileAccess.get_file_as_bytes(dir.path_join(file))
	return found


func test_each_sheet_is_one_row_of_whole_frames_none_too_large() -> void:
	# A sheet cut into frames of the wrong width shows a sliver of the next frame (docs/M6.md N16),
	# a particle sheet too (POOLS_PLAN.md N29). The legends are in the tree, where a legend may draw
	# its sheets as it starts.
	var sheets := 0
	for scene: PackedScene in Disasters.contract_scenes():
		var node := scene.instantiate()
		var legend := node as Legend
		if legend == null:
			node.free()
			continue
		add_child_autofree(legend)
		for sheet: Sheet in _sheets(legend):
			sheets += 1
			var size := Vector2i(sheet.texture.get_size())
			var across := sheet.frames.x
			var what := "%s: %s" % [legend.id, sheet.node.name]
			assert_eq(sheet.frames.y, 1, what + ": one row")
			assert_true(across > 0 and size.x % across == 0, what + ": whole frames")
			assert_lte(float(size.x) / maxi(across, 1), float(LegendArt.MAX_FRAME.x), what)
			assert_lte(size.y, LegendArt.MAX_FRAME.y, what)
	assert_gt(sheets, 0, "the sample's totem at least")


func test_each_legend_of_the_pools_draws_only_its_own_art() -> void:
	# tools/art/legends/<id>.gd draws its sheets into assets/legends/<id>/ (docs/M6.md §5.7), its
	# particle sheets too (POOLS_PLAN.md N30).
	var checked := 0
	for scene: PackedScene in Disasters.scenes():
		var node := scene.instantiate()
		var legend := node as Legend
		if legend != null:
			for sheet: Sheet in _sheets(legend):
				checked += 1
				assert_string_starts_with(
					sheet.texture.resource_path,
					"res://assets/legends/%s/" % legend.id,
					"%s: %s" % [legend.id, sheet.node.name]
				)
		node.free()
	if checked == 0:
		pass_test("no pool has a legend yet")


func test_each_legends_script_draws_the_same_bytes_every_time() -> void:
	# As tools/art/make_legends.gd:6-7 says, though CI never runs it (POOLS_PLAN.md §5.6, N28). Two
	# runs, not a run and the committed sheets, which an artist may replace (:5-6).
	var scripts := 0
	for file: String in DirAccess.get_files_at(SCRIPTS):
		if file.get_extension() != "gd":
			continue
		scripts += 1
		var script := load(SCRIPTS.path_join(file)) as Script
		var drawn: Array[Dictionary] = []
		for run: String in RUNS:
			var dir := run.path_join(file.get_basename())
			script.call(&"make", dir)
			drawn.append(_files(dir))
		assert_gt(drawn[0].size(), 0, file + ": some sheets")
		assert_eq(drawn[1].keys(), drawn[0].keys(), file + ": the same sheets")
		for sheet: String in drawn[0]:
			# Not assert_eq, which would print each sheet's bytes.
			var same: bool = drawn[1].get(sheet, PackedByteArray()) == drawn[0][sheet]
			assert_true(same, "%s: %s, the same bytes" % [file, sheet])
	assert_gt(scripts, 0, "the legends' scripts")


func test_mirror_copies_a_frames_left_half_onto_its_right() -> void:
	var art := LegendArt.new(Vector2i(8, 4), 2)
	art.frame = 1
	art.plot(Vector2i(-4, -1), "red")
	art.plot(Vector2i(-1, -4), "wisp")
	art.plot(Vector2i(2, -2), "ink")
	art.mirror()
	var drawn := art.image.get_region(Rect2i(8, 0, 8, 4))
	var flipped := drawn.duplicate() as Image
	flipped.flip_x()
	assert_eq(Art.first_difference(drawn, flipped), Vector2i(-1, -1), "the same on each side")
	assert_eq(drawn.get_pixel(7, 3), art.color("red"), "-x - 1 pixels from the foot")
	assert_eq(drawn.get_pixel(4, 0), art.color("wisp"), "the pixel at -1 to the one at 0")
	assert_eq(drawn.get_pixel(6, 2).a, 0.0, "the right half's own pixels gone")
	assert_true(art.image.get_region(Rect2i(0, 0, 8, 4)).is_invisible(), "the other frame clear")


func test_a_sheet_is_drawn_the_same_every_time_in_the_palettes_colours() -> void:
	var sheet := Sample.sheet()
	assert_eq(sheet.get_data(), Sample.sheet().get_data(), "the same bytes")
	var shares := Art.shares(sheet)
	assert_false(shares.has(Color()), "no colour but the palette's")
	assert_gt(shares.size(), 4, "several of them")
