class_name RoadBuffer
extends RefCounted
## Keeps Tuning.BUFFER_REFILL_AT to BUFFER_AHEAD correct-path tiles generated ahead of the car's
## tile and BUFFER_BEHIND behind it (plan.md §3.4, IMPLEMENTATION_PLAN.md M1.5, docs/M5.md L2).
## Lookahead = last generated path index minus the car's path index. Dead ends come and go with
## their junction.

## New tiles: each correct-path tile, followed by its dead-end tiles.
signal tiles_generated(tiles: Array[RoadTile])
## Freed tiles, in the same order. Their cells are already released.
signal tiles_freed(tiles: Array[RoadTile])

var generator: RoadGenerator

var _path: Array[RoadTile] = []
var _first_index := 0
var _car_index := 0


func _init(p_generator: RoadGenerator) -> void:
	generator = p_generator


## Generates path indices 0 to Tuning.BUFFER_AHEAD.
func start() -> void:
	_generate_to(Tuning.BUFFER_AHEAD)


## Call when the car enters a correct-path tile. A lower index than before (the car rejoined
## behind) changes nothing.
func on_car_path_index(index: int) -> void:
	if index <= _car_index:
		return
	_car_index = index
	if lookahead() < Tuning.BUFFER_REFILL_AT:
		_generate_to(_car_index + Tuning.BUFFER_AHEAD)
	_free_before(_car_index - Tuning.BUFFER_BEHIND)


func car_index() -> int:
	return _car_index


func lookahead() -> int:
	return last_index() - _car_index


func first_index() -> int:
	return _first_index


func last_index() -> int:
	return _first_index + _path.size() - 1


## The correct-path tile at `index`, or null if it is not in the buffer.
func path_tile(index: int) -> RoadTile:
	if index < _first_index or index > last_index():
		return null
	return _path[index - _first_index]


## The tile on `cell` (correct path or dead end), or null.
func tile_at(cell: Vector2i) -> RoadTile:
	return generator.occupancy.get_tile(cell)


## Every tile in the buffer, in tiles_generated order.
func tiles() -> Array[RoadTile]:
	var all: Array[RoadTile] = []
	for tile: RoadTile in _path:
		all.append(tile)
		all.append_array(tile.branches)
	return all


## A point on the correct-path centreline, in tile space. `distance` is in tiles from the centre
## of path tile 0; the line runs straight between neighbouring tile centres.
func centreline_point(distance: float) -> Vector2:
	var index := clampi(floori(distance), _first_index, maxi(_first_index, last_index() - 1))
	var from := path_tile(index)
	var to := path_tile(index + 1)
	if from == null or to == null:
		push_error("RoadBuffer: no centreline at distance %.2f" % distance)
		return Vector2.ZERO
	var t := clampf(distance - index, 0.0, 1.0)
	return (Vector2(from.cell) + Vector2(0.5, 0.5)).lerp(Vector2(to.cell) + Vector2(0.5, 0.5), t)


func _generate_to(last: int) -> void:
	var created: Array[RoadTile] = []
	while last_index() < last:
		var tile := generator.next_tile()
		_path.append(tile)
		created.append(tile)
		created.append_array(tile.branches)
	if not created.is_empty():
		tiles_generated.emit(created)


func _free_before(index: int) -> void:
	var freed: Array[RoadTile] = []
	while not _path.is_empty() and _first_index < index:
		var tile: RoadTile = _path.pop_front()
		_first_index += 1
		generator.occupancy.release(tile)
		freed.append(tile)
		for branch: RoadTile in tile.branches:
			generator.occupancy.release(branch)
			freed.append(branch)
	if not freed.is_empty():
		tiles_freed.emit(freed)
