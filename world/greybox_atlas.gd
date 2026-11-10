class_name GreyboxAtlas
## The road TileSet, and the grey box: art drawn at run time for an area that has none. The road
## comes from RoadGeometry, so that the road on screen is exactly the road the off-road test sees.
## A road sheet has one column per exits bitmask - 1, which covers all 15 road tiles of plan.md
## §5.3 (caps, straights, corners, T-junctions, crossroads), and one row per Row. An area's art has
## the same layout, with opaque pixels exactly where the grey box's are (M5_PLAN.md §5.5). The
## grey-box ground is a checker of 32×16 diamonds in two shades of the area's colour, and its edge
## the same with fewer pixels further down (IMPLEMENTATION_PLAN.md M4.3).

enum Row { ROAD, DEAD_END, TUNNEL, BRIDGE }

const ROAD_COLORS: Array[Color] = [
	Color(0.33, 0.34, 0.38), Color(0.62, 0.24, 0.24), Color(0.16, 0.16, 0.2), Color(0.5, 0.36, 0.22)
]
const EDGE_COLOR := Color(0.86, 0.86, 0.8)
## Width of the road edge line, in tiles.
const EDGE_WIDTH := 0.035
const GROUND_SHADE := 0.07
## Each diamond also covers the pixels this close to it, so neighbours overlap and no seam shows
## when the camera zooms out.
const BLEED_PX := 1.0
## Drawn on first use and kept until the game quits.
static var _road_texture: Texture2D
static var _grounds: Dictionary[Color, Texture2D] = {}
static var _edges: Dictionary[Color, Texture2D] = {}


## Atlas coordinates of `tile`. Dead ends get their own tint only when `show_dead_ends` is set;
## in a run they must look like real road (plan.md §3.3).
static func road_coords(tile: RoadTile, show_dead_ends: bool) -> Vector2i:
	var row := Row.ROAD
	if show_dead_ends and tile.type == RoadTile.Type.DEAD_END:
		row = Row.DEAD_END
	elif tile.set_piece == &"tunnel":
		row = Row.TUNNEL
	elif tile.set_piece == &"bridge":
		row = Row.BRIDGE
	return Vector2i(tile.exits - 1, row)


## A road TileSet with one atlas source per sheet, whose id is the sheet's index. A null sheet gets
## the grey-box road.
static func road_tileset(sheets: Array[Texture2D]) -> TileSet:
	var tile_set := TileSet.new()
	tile_set.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	tile_set.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	tile_set.tile_size = Vector2i(Iso.TILE_W, Iso.TILE_H)
	for k: int in sheets.size():
		var source := TileSetAtlasSource.new()
		source.texture = sheets[k] if sheets[k] != null else road_texture()
		source.texture_region_size = tile_set.tile_size
		for y: int in Row.size():
			for x: int in Heading.ALL:
				source.create_tile(Vector2i(x, y))
		tile_set.add_source(source, k)
	return tile_set


## The grey-box road sheet.
static func road_texture() -> Texture2D:
	if _road_texture == null:
		_road_texture = ImageTexture.create_from_image(road_image())
	return _road_texture


## The grey-box road sheet's image, which an area's road sheet must match in size and in where its
## pixels are opaque.
static func road_image() -> Image:
	var size := Vector2i(Iso.TILE_W, Iso.TILE_H)
	var grid := Vector2i(Heading.ALL, Row.size())
	var image := Image.create_empty(grid.x * size.x, grid.y * size.y, false, Image.FORMAT_RGBA8)
	var inner := Tuning.ROAD_HALF_WIDTH - EDGE_WIDTH
	for y: int in size.y:
		for x: int in size.x:
			var local := tile_local(Vector2i(x, y), size)
			if not in_diamond(local, size):
				continue
			for exits: int in range(1, Heading.ALL + 1):
				var distance := RoadGeometry.distance_to_centreline(exits, local)
				if distance > Tuning.ROAD_HALF_WIDTH:
					continue
				for row: int in grid.y:
					var color := ROAD_COLORS[row] if distance <= inner else EDGE_COLOR
					image.set_pixel((exits - 1) * size.x + x, row * size.y + y, color)
	return image


## A grey-box ground in `color`: one period of a checker of ground cells, tall enough for its edge.
static func ground_texture(color: Color) -> Texture2D:
	if not _grounds.has(color):
		_grounds[color] = ImageTexture.create_from_image(_ground_image(color))
	return _grounds[color]


## The edge of ground_texture(color).
static func edge_texture(color: Color) -> Texture2D:
	if not _edges.has(color):
		_edges[color] = ImageTexture.create_from_image(edge_image(_ground_image(color)))
	return _edges[color]


## The edge of a ground: its first edge_rows() rows, with fewer pixels further down. The bottom row
## shows almost none of it, so that the ground below shows through.
static func edge_image(ground: Image) -> Image:
	var edge := ground.get_region(Rect2i(0, 0, ground.get_width(), edge_rows()))
	edge.convert(Image.FORMAT_RGBA8)
	for y: int in edge.get_height():
		var cover := 64.0 * (1.0 - (y + 0.5) / edge.get_height())
		for x: int in edge.get_width():
			if bayer(x, y) >= cover:
				edge.set_pixel(x, y, Color(0, 0, 0, 0))
	return edge


## The threshold of pixel (x, y), from 0 to 63, in Bayer's 8 × 8 ordered dither: any n pixels of
## the 64 with the lowest thresholds lie as evenly spread as can be. The bits of x xor y and of y,
## interleaved and in reverse order.
static func bayer(x: int, y: int) -> int:
	var threshold := 0
	for bit: int in 3:
		threshold = threshold << 2 | ((x ^ y) >> bit & 1) << 1 | y >> bit & 1
	return threshold


## The height of a ground's edge, in pixels: the screen rows of the first TRANSITION_TILES path
## tiles of an area, whose centres are TILE_H / 2 apart. An area's ground must be at least this
## tall.
static func edge_rows() -> int:
	@warning_ignore("integer_division")
	return Tuning.TRANSITION_TILES * Iso.TILE_H / 2


## The ground cells' period, in pixels: a ground must tile with a multiple of it.
static func ground_period() -> Vector2i:
	return Vector2i(Iso.TILE_W, Iso.TILE_H) / Iso.GROUND_PER_TILE


## Tile-local position of the centre of pixel (x, y) of a tile image of `size`.
static func tile_local(pixel: Vector2i, size: Vector2i) -> Vector2:
	var w := Vector2(pixel) + Vector2(0.5 - size.x * 0.5, 0.5)
	return Iso.world_to_tile(w * float(Iso.TILE_W) / size.x)


## Whether tile-local point `local` is in the tile's diamond, or within BLEED_PX of it.
static func in_diamond(local: Vector2, size: Vector2i) -> bool:
	# Opposite diamond edges are size.x * size.y / |size| pixels apart: one tile-local unit.
	var m := BLEED_PX * Vector2(size).length() / (size.x * size.y)
	return local.x >= -m and local.x < 1.0 + m and local.y >= -m and local.y < 1.0 + m


static func _ground_image(color: Color) -> Image:
	var period := ground_period()
	var size := Vector2i(period.x, edge_rows())
	var image := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	for y: int in size.y:
		for x: int in size.x:
			var cell := Iso.world_to_tile(Vector2(x, y) + Vector2(0.5, 0.5)) * Iso.GROUND_PER_TILE
			var shade := posmod(floori(cell.x) + floori(cell.y), 2)
			image.set_pixel(x, y, color.darkened(GROUND_SHADE * shade))
	return image
