extends GutTest

const NS := 0b0101
const EW := 0b1010
const CAP_S := 0b0100

var _road: TileSet
var _image: Image


func before_all() -> void:
	var start := Time.get_ticks_usec()
	_road = GreyboxAtlas.road_tileset()
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
	assert_eq(GreyboxAtlas.ground_coords(2, Vector2i(3, 4)), Vector2i(2, 1))
	assert_eq(GreyboxAtlas.ground_coords(2, Vector2i(-3, 5)), Vector2i(2, 0))


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


func test_ground_tileset() -> void:
	var colors: Array[Color] = [Color.RED, Color.BLUE]
	var ground := GreyboxAtlas.build_ground_tileset(colors)
	var size := Vector2i(Iso.TILE_W, Iso.TILE_H) / Iso.GROUND_PER_TILE
	assert_eq(ground.tile_size, size)
	var source: TileSetAtlasSource = ground.get_source(0)
	var image := source.texture.get_image()
	assert_true(_near(image.get_pixelv(Vector2i(1, 0) * size + size / 2), Color.BLUE))
	var dark := Color.BLUE.darkened(GreyboxAtlas.GROUND_SHADE)
	assert_true(_near(image.get_pixelv(Vector2i(1, 1) * size + size / 2), dark))
	assert_eq(image.get_pixel(0, 0).a, 0.0, "outside the diamond")
