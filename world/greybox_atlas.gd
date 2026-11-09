class_name GreyboxAtlas
## Grey-box TileSets, drawn at run time from RoadGeometry so that the road on screen is exactly
## the road the off-road test sees. Road atlas: column = exits bitmask - 1, which covers all 15
## road tiles of plan.md §5.3 (caps, straights, corners, T-junctions, crossroads); row = Row.
## Ground atlas: one column per area, with two checker shades as rows, and after them one column
## per transition between two areas, with the two areas' colours as rows (IMPLEMENTATION_PLAN.md
## M4.3).

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
static var _road_tileset: TileSet


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


static func ground_coords(area_column: int, ground_cell: Vector2i) -> Vector2i:
	return Vector2i(area_column, posmod(ground_cell.x + ground_cell.y, 2))


## The road TileSet, shared by every WorldRenderer.
static func road_tileset() -> TileSet:
	if _road_tileset != null:
		return _road_tileset
	var size := Vector2i(Iso.TILE_W, Iso.TILE_H)
	var grid := Vector2i(Heading.ALL, Row.size())
	var image := Image.create_empty(grid.x * size.x, grid.y * size.y, false, Image.FORMAT_RGBA8)
	var inner := Tuning.ROAD_HALF_WIDTH - EDGE_WIDTH
	for y: int in size.y:
		for x: int in size.x:
			var local := _local(Vector2i(x, y), size)
			if not _inside(local, size):
				continue
			for exits: int in range(1, Heading.ALL + 1):
				var distance := RoadGeometry.distance_to_centreline(exits, local)
				if distance > Tuning.ROAD_HALF_WIDTH:
					continue
				for row: int in grid.y:
					var color := ROAD_COLORS[row] if distance <= inner else EDGE_COLOR
					image.set_pixel((exits - 1) * size.x + x, row * size.y + y, color)
	_road_tileset = _tileset(image, size, grid)
	return _road_tileset


## `colors` are the areas' colours. Each transition is a pair of indices into them: from, to.
static func build_ground_tileset(
	colors: Array[Color], transitions: Array[Vector2i] = []
) -> TileSet:
	var size := Vector2i(Iso.TILE_W, Iso.TILE_H) / Iso.GROUND_PER_TILE
	var grid := Vector2i(colors.size() + transitions.size(), 2)
	var image := Image.create_empty(grid.x * size.x, grid.y * size.y, false, Image.FORMAT_RGBA8)
	for column: int in grid.x:
		for shade: int in grid.y:
			var color: Color
			if column < colors.size():
				color = colors[column].darkened(GROUND_SHADE * shade)
			else:
				color = colors[transitions[column - colors.size()][shade]]
			_draw_diamond(image, Vector2i(column, shade) * size, size, color)
	return _tileset(image, size, grid)


## Tile-local position of the centre of pixel (x, y) of a tile image.
static func _local(pixel: Vector2i, size: Vector2i) -> Vector2:
	var w := Vector2(pixel) + Vector2(0.5 - size.x * 0.5, 0.5)
	return Iso.world_to_tile(w * float(Iso.TILE_W) / size.x)


static func _inside(local: Vector2, size: Vector2i) -> bool:
	# Opposite diamond edges are size.x * size.y / |size| pixels apart: one tile-local unit.
	var m := BLEED_PX * Vector2(size).length() / (size.x * size.y)
	return local.x >= -m and local.x < 1.0 + m and local.y >= -m and local.y < 1.0 + m


static func _draw_diamond(image: Image, origin: Vector2i, size: Vector2i, color: Color) -> void:
	for y: int in size.y:
		for x: int in size.x:
			if _inside(_local(Vector2i(x, y), size), size):
				image.set_pixel(origin.x + x, origin.y + y, color)


static func _tileset(image: Image, size: Vector2i, grid: Vector2i) -> TileSet:
	var tile_set := TileSet.new()
	tile_set.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	tile_set.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	tile_set.tile_size = size
	var source := TileSetAtlasSource.new()
	source.texture = ImageTexture.create_from_image(image)
	source.texture_region_size = size
	for y: int in grid.y:
		for x: int in grid.x:
			source.create_tile(Vector2i(x, y))
	tile_set.add_source(source, 0)
	return tile_set
