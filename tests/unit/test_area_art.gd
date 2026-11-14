extends GutTest
## Each area's art (docs/M5.md §5.5): the contract that tools/art/make_art.gd's placeholders keep,
## and that any art which replaces them must keep too.

const Art := preload("res://tests/helpers/art_checks.gd")
const Fixtures := preload("res://tests/helpers/road_fixtures.gd")
const MakeArt := preload("res://tools/art/make_art.gd")


func _areas() -> Array[AreaDef]:
	var areas: Array[AreaDef] = []
	for entry: AreaScheduleEntry in Fixtures.schedule().entries:
		if entry.area not in areas:
			areas.append(entry.area)
	return areas


## Every PNG file under `dir`, recursively.
static func _pngs(dir: String) -> Array[String]:
	var found: Array[String] = []
	for file: String in DirAccess.get_files_at(dir):
		if file.get_extension() == "png":
			found.append(dir.path_join(file))
	for sub: String in DirAccess.get_directories_at(dir):
		found.append_array(_pngs(dir.path_join(sub)))
	return found


func test_every_area_has_its_art() -> void:
	for area: AreaDef in _areas():
		for texture: Texture2D in [area.road_sheet, area.ground, area.ground_edge]:
			assert_not_null(texture, "%s: road sheet, ground and edge" % area.id)


func test_a_road_sheet_is_opaque_exactly_where_the_road_is() -> void:
	# The car is off the road where RoadGeometry says, so the road must show just there (M1.6).
	var road := Art.mask(GreyboxAtlas.road_image())
	for area: AreaDef in _areas():
		var sheet := area.road_sheet.get_image()
		assert_eq(sheet.get_size(), road.get_size(), "%s: the grey box's layout" % area.id)
		if sheet.get_size() == road.get_size():
			var at := Art.first_difference(Art.mask(sheet), road)
			assert_eq(at, Vector2i(-1, -1), "%s: the road's pixels and no others" % area.id)


func test_a_ground_repeats_with_the_ground_cells_and_covers_everything() -> void:
	var period := GreyboxAtlas.ground_period()
	for area: AreaDef in _areas():
		var ground := area.ground.get_image()
		var size := ground.get_size()
		assert_eq(size % period, Vector2i.ZERO, "%s: %s repeats every %s" % [area.id, size, period])
		assert_gte(size.y, GreyboxAtlas.edge_rows(), "%s: tall enough for its edge" % area.id)
		assert_eq(ground.detect_alpha(), Image.ALPHA_NONE, "%s: opaque" % area.id)


## Copilot's review of #42: the desert's ripples jumped where its ground repeats.
func test_a_placeholder_grounds_pattern_goes_on_where_it_repeats() -> void:
	# What the pattern would draw just past each edge is what the opposite edge shows.
	var size := MakeArt.GROUND_SIZE
	var local := Vector2(0.5, 0.5)
	for style: Array in MakeArt.AREAS.values():
		var kind: String = style[4]
		var seams: Array[Vector2i] = []
		for k: int in 2:
			for y: int in size.y:
				var at := Vector2i(k, y)
				if (
					MakeArt._pattern(kind, 0, local, at + Vector2i(size.x, 0))
					!= MakeArt._pattern(kind, 0, local, at)
				):
					seams.append(at)
			for x: int in size.x:
				var at := Vector2i(x, k)
				if (
					MakeArt._pattern(kind, 0, local, at + Vector2i(0, size.y))
					!= MakeArt._pattern(kind, 0, local, at)
				):
					seams.append(at)
		assert_eq(seams, [] as Array[Vector2i], "%s: no seam" % kind)


func test_an_edge_is_its_grounds_first_rows_thinning_out() -> void:
	for area: AreaDef in _areas():
		var problem := Art.edge_problem(area.ground.get_image(), area.ground_edge.get_image())
		assert_eq(problem, "", "%s's edge" % area.id)


func test_art_is_in_the_palettes_colours() -> void:
	# A pixel is either clear or a palette colour: no blends, no half-transparent pixels.
	var files := _pngs("res://assets")
	assert_gte(files.size(), 15, "the 5 areas' art at least")
	for path: String in files:
		var shares := Art.shares((load(path) as Texture2D).get_image())
		assert_false(
			shares.has(Color()), "%s: %s of it off the palette" % [path, shares.get(Color())]
		)


func test_art_is_imported_lossless_and_without_mipmaps() -> void:
	# IMPLEMENTATION_PLAN.md M5.1: pixel art keeps its pixels, and the palette test sees them.
	for path: String in _pngs("res://assets"):
		var config := ConfigFile.new()
		assert_eq(config.load(path + ".import"), OK, path)
		assert_eq(config.get_value("params", "compress/mode", -1), 0, "%s: lossless" % path)
		assert_false(config.get_value("params", "mipmaps/generate", true), "%s: no mipmaps" % path)
