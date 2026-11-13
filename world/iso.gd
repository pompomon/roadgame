class_name Iso
## Tile space (1.0 = one road tile, D1) to isometric world pixels: each road tile is a 128×64
## diamond whose top corner is tile-space point `cell` (IMPLEMENTATION_PLAN.md M1.6). Grid N goes
## up-right on screen and W up-left, so the N/W staircase runs up the screen.

const TILE_W := 128
const TILE_H := 64
## Ground cells per road tile along each axis: 32×16 ground diamonds (plan.md §5.2).
const GROUND_PER_TILE := 4
## Screen pixels that a tile of length shows as across the screen, where the 2:1 view shortens
## nothing, and upright, where it shortens heights by cos 30° (DAYNIGHT_PLAN.md §5.11).
const WIDTH_PX := TILE_W * sqrt(0.5)
const HEIGHT_PX := sqrt((TILE_W * TILE_W - TILE_H * TILE_H) * 0.5)


static func tile_to_world(p: Vector2) -> Vector2:
	return Vector2((p.x - p.y) * TILE_W * 0.5, (p.x + p.y) * TILE_H * 0.5)


static func world_to_tile(w: Vector2) -> Vector2:
	return Vector2(w.x / TILE_W + w.y / TILE_H, w.y / TILE_H - w.x / TILE_W)


static func cell_centre(cell: Vector2i) -> Vector2:
	return Vector2(cell) + Vector2(0.5, 0.5)


## Position for a TileMapLayer so that its cell centres land on tile_to_world(): in Godot 4.7
## DIAMOND_DOWN puts the centre of cell (0, 0) at (tile_size.x / 2, tile_size.y / 2), half a
## tile right of tile_to_world((0.5, 0.5)).
static func layer_offset(layer: TileMapLayer, cells_per_tile: int) -> Vector2:
	var centre := Vector2(0.5, 0.5) / cells_per_tile
	return tile_to_world(centre) - layer.map_to_local(Vector2i.ZERO)
