extends GutTest

const Art := preload("res://tests/helpers/art_checks.gd")
const NS := 0b0101
const EW := 0b1010
const CAP_S := 0b0100

var _road: TileSet
var _image: Image


func before_all() -> void:
	var start := Time.get_ticks_usec()
	_road = GreyboxAtlas.road_tileset([null])
	gut.p("road atlas built in %d ms" % ((Time.get_ticks_usec() - start) / 1000))
	var source: TileSetAtlasSource = _road.get_source(0)
	_image = source.texture.get_image()


func _near(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) + absf(a.a - b.a) < 0.02


## The road atlas pixel at tile-local point `local` of tile (exits, row).
func _pixel(exits: int, row: int, local: Vector2) -> Color:
	var w := Iso.tile_to_world(local) + Vector2(Iso.TILE_W * 0.5, 0)
	var origin := Vector2i(exits - 1, row) * Vector2i(Iso.TILE_W, Iso.TILE_H)
	return _image.get_pixelv(origin + Vector2i(w.floor()))


func test_road_atlas_layout() -> void:
	assert_eq(_road.tile_shape, TileSet.TILE_SHAPE_ISOMETRIC)
	assert_eq(_road.tile_layout, TileSet.TILE_LAYOUT_DIAMOND_DOWN)
	assert_eq(_road.tile_size, Vector2i(Iso.TILE_W, Iso.TILE_H))
	var source: TileSetAtlasSource = _road.get_source(0)
	assert_eq(source.get_tiles_count(), 15 * GreyboxAtlas.Row.size())
	assert_eq(_image.get_size(), Vector2i(15 * Iso.TILE_W, GreyboxAtlas.Row.size() * Iso.TILE_H))


func test_road_coords() -> void:
	var tile := RoadTile.new(Vector2i.ZERO, RoadTile.Type.DEAD_END, Heading.E, 0b1000)
	assert_eq(GreyboxAtlas.road_coords(tile, false), Vector2i(7, GreyboxAtlas.Row.ROAD), "in a run")
	assert_eq(GreyboxAtlas.road_coords(tile, true), Vector2i(7, GreyboxAtlas.Row.DEAD_END))
	tile.type = RoadTile.Type.SET_PIECE
	tile.exits = NS
	tile.set_piece = &"tunnel"
	assert_eq(GreyboxAtlas.road_coords(tile, true), Vector2i(4, GreyboxAtlas.Row.TUNNEL))
	tile.set_piece = &"bridge"
	assert_eq(GreyboxAtlas.road_coords(tile, false), Vector2i(4, GreyboxAtlas.Row.BRIDGE))


func test_every_tile_has_road_in_the_centre_and_none_in_the_corners() -> void:
	var corners: Array[Vector2] = [Vector2(0.03, 0.03), Vector2(0.97, 0.03), Vector2(0.03, 0.97)]
	for row: int in GreyboxAtlas.Row.size():
		for exits: int in range(1, 16):
			var centre := _pixel(exits, row, Vector2(0.5, 0.5))
			if not _near(centre, GreyboxAtlas.ROAD_COLORS[row]):
				fail_test("exits %d row %d: centre is %s" % [exits, row, centre])
			for corner: Vector2 in corners:
				if _pixel(exits, row, corner).a != 0.0:
					fail_test("exits %d row %d: corner %s is drawn" % [exits, row, corner])
	pass_test("15 × %d tiles" % GreyboxAtlas.Row.size())


func test_road_pixels_follow_the_road_geometry() -> void:
	var road := GreyboxAtlas.ROAD_COLORS[GreyboxAtlas.Row.ROAD]
	var w := Tuning.ROAD_HALF_WIDTH
	assert_true(_near(_pixel(NS, 0, Vector2(0.5, 0.04)), road), "N|S: N end")
	assert_true(_near(_pixel(NS, 0, Vector2(0.5, -0.008)), road), "N|S: bleeds into the next tile")
	assert_eq(_pixel(NS, 0, Vector2(0.12, 0.5)).a, 0.0, "N|S: beside the road, ground shows")
	assert_true(_near(_pixel(NS, 0, Vector2(0.5 + w - 0.01, 0.5)), GreyboxAtlas.EDGE_COLOR))
	assert_true(_near(_pixel(EW, 0, Vector2(0.04, 0.5)), road), "E|W: W end")
	assert_eq(_pixel(EW, 0, Vector2(0.5, 0.1)).a, 0.0, "E|W: no road to the N")
	assert_true(_near(_pixel(CAP_S, 0, Vector2(0.5, 0.9)), road), "cap: road to the S")
	assert_eq(_pixel(CAP_S, 0, Vector2(0.5, 0.1)).a, 0.0, "cap: nothing past the end")


func test_a_road_tileset_has_a_source_for_each_sheet() -> void:
	# Each area's road sheet, or the grey box's for an area that has none (M5_PLAN.md §5.5).
	var sheet := ImageTexture.create_from_image(GreyboxAtlas.road_image())
	var road := GreyboxAtlas.road_tileset([null, sheet])
	assert_eq(road.get_source_count(), 2)
	var grey: TileSetAtlasSource = road.get_source(0)
	var art: TileSetAtlasSource = road.get_source(1)
	assert_eq(grey.texture, GreyboxAtlas.road_texture())
	assert_eq(art.texture, sheet)
	assert_eq(art.get_tiles_count(), 15 * GreyboxAtlas.Row.size())


func test_the_grey_box_ground_repeats_a_checker_of_ground_cells() -> void:
	# Wherever the texture repeats from, the centre of each ground cell shows its shade.
	var image := GreyboxAtlas.ground_texture(Color.RED).get_image()
	var size := image.get_size()
	assert_eq(size % GreyboxAtlas.ground_period(), Vector2i.ZERO)
	for y: int in range(-6, 6):
		for x: int in range(-6, 6):
			var at := Iso.tile_to_world((Vector2(x, y) + Vector2(0.5, 0.5)) / Iso.GROUND_PER_TILE)
			var pixel := Vector2i(at.floor())
			var got := image.get_pixel(posmod(pixel.x, size.x), posmod(pixel.y, size.y))
			var want := Color.RED.darkened(GreyboxAtlas.GROUND_SHADE * posmod(x + y, 2))
			assert_true(_near(got, want), "ground cell (%d, %d): %s, not %s" % [x, y, got, want])


func test_the_grey_box_edge_is_its_grounds_first_rows_thinning_out() -> void:
	var ground := GreyboxAtlas.ground_texture(Color.RED).get_image()
	var edge := GreyboxAtlas.edge_texture(Color.RED).get_image()
	assert_eq(Art.edge_problem(ground, edge), "")
