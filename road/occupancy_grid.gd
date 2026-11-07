class_name OccupancyGrid
extends RefCounted
## The road tile on each cell. A cell holds at most one tile (IMPLEMENTATION_PLAN.md M1.3).

var _cells: Dictionary[Vector2i, RoadTile] = {}


func is_free(cell: Vector2i) -> bool:
	return not _cells.has(cell)


func get_tile(cell: Vector2i) -> RoadTile:
	return _cells.get(cell)


## Puts `tile` on its cell. A taken cell is a generator bug: it reports an error, keeps the old
## tile and returns false. `assert` is not used because release builds remove it.
func claim(tile: RoadTile) -> bool:
	if _cells.has(tile.cell):
		push_error("OccupancyGrid: cell %s is already taken" % tile.cell)
		return false
	_cells[tile.cell] = tile
	return true


## Frees the cell of `tile` if `tile` holds it.
func release(tile: RoadTile) -> void:
	if _cells.get(tile.cell) == tile:
		_cells.erase(tile.cell)


func size() -> int:
	return _cells.size()
