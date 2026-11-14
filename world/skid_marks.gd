class_name SkidMarks
extends RefCounted
## Skid marks (plan.md §5.3, docs/M5.md §5.7). While the car brakes for a junction, its rear wheels
## leave a mark on the road every SKID_SPACING tiles. A wheel over the road's edge leaves none, also
## while the car's centre is on the road (docs/M5.md R12). A mark is a Sprite2D on World's Skids
## layer, placed once where it lands, so nothing redraws (docs/M2.md §5.7). Marks come from a pool,
## and go back to it when the buffer frees their tile, or the oldest first once `limit` show.
## WorldRenderer makes it, binds it with itself and updates it every physics frame.

const TEXTURE := preload("res://assets/car/skid.png")

var _layer: Node2D
var _limit: int
var _buffer: RoadBuffer
var _pool: Array[Sprite2D] = []
## The marks that show, oldest first, and the cell of each.
var _laid: Array[Sprite2D] = []
var _cells: Dictionary[Sprite2D, Vector2i] = {}
## Where the car was at the last pair of marks, or INF after none.
var _last := Vector2.INF


func _init(layer: Node2D, limit := Tuning.SKID_MARKS) -> void:
	_layer = layer
	_limit = limit


## Lays marks on `buffer`'s road from now on, instead of the last buffer's, whose marks go.
func bind(buffer: RoadBuffer) -> void:
	if _buffer != null:
		_buffer.tiles_freed.disconnect(_on_tiles_freed)
	for mark: Sprite2D in _laid:
		mark.hide()
		_pool.append(mark)
	_laid.clear()
	_cells.clear()
	_last = Vector2.INF
	_buffer = buffer
	buffer.tiles_freed.connect(_on_tiles_freed)


## Lays a pair of marks while `sim`'s car brakes for a junction, SKID_SPACING tiles or more after
## the last pair: one under each rear wheel that is on the road.
func update(sim: CarSim) -> void:
	if sim.state != CarSim.State.BRAKING or sim.speed <= sim.target_speed():
		_last = Vector2.INF
		return
	if _last != Vector2.INF and sim.pos.distance_to(_last) < Tuning.SKID_SPACING:
		return
	_last = sim.pos
	var forward := sim.forward()
	var across := Vector2(-forward.y, forward.x) * Tuning.SKID_TRACK / 2.0
	var rear := sim.pos - forward * Tuning.SKID_REAR
	_lay(rear - across, forward)
	_lay(rear + across, forward)


## The marks that show, oldest first.
func marks() -> Array[Sprite2D]:
	return _laid.duplicate()


## The cell of a mark that shows.
func cell_of(mark: Sprite2D) -> Vector2i:
	return _cells[mark]


func _lay(at: Vector2, forward: Vector2) -> void:
	var cell := Vector2i(at.floor())
	if not RoadGeometry.is_on_road(_buffer.tile_at(cell), at - Vector2(cell)):
		return
	var mark: Sprite2D
	if not _pool.is_empty():
		mark = _pool.pop_back()
	elif _laid.size() >= _limit:
		mark = _laid.pop_front()
		_cells.erase(mark)
	else:
		mark = Sprite2D.new()
		mark.texture = TEXTURE
		mark.self_modulate.a = Tuning.SKID_ALPHA
		_layer.add_child(mark)
	mark.position = Iso.tile_to_world(at)
	mark.rotation = Iso.tile_to_world(forward).angle()
	mark.show()
	_laid.append(mark)
	_cells[mark] = cell


func _on_tiles_freed(tiles: Array[RoadTile]) -> void:
	var freed: Dictionary[Vector2i, bool] = {}
	for tile: RoadTile in tiles:
		freed[tile.cell] = true
	var kept: Array[Sprite2D] = []
	for mark: Sprite2D in _laid:
		if freed.has(_cells[mark]):
			mark.hide()
			_cells.erase(mark)
			_pool.append(mark)
		else:
			kept.append(mark)
	_laid = kept
