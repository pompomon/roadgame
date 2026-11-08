class_name WorldRenderer
extends Node2D
## Draws the tiles of a RoadBuffer on the grey-box layers (IMPLEMENTATION_PLAN.md M1.6): one road
## cell and 4×4 ground cells per tile, erased when the buffer frees the tile. build() makes the
## tilesets once; bind() draws a run's buffer, and a retry binds the next run's (M3_PLAN.md J11).

## Tint dead ends. For debug views only: in a run they must look like real road.
@export var show_dead_ends := false

var _area_columns: Dictionary[StringName, int] = {}
## The buffer it draws, or null before the first bind().
var _buffer: RoadBuffer

@onready var _ground: TileMapLayer = %GroundLayer
@onready var _road: TileMapLayer = %RoadLayer


## Builds the tilesets for the areas of `schedule`. Call it once, when the node is ready.
func build(schedule: AreaSchedule) -> void:
	var colors: Array[Color] = []
	for entry: AreaScheduleEntry in schedule.entries:
		if not _area_columns.has(entry.area.id):
			_area_columns[entry.area.id] = colors.size()
			colors.append(entry.area.id_color)
	_ground.tile_set = GreyboxAtlas.build_ground_tileset(colors)
	_road.tile_set = GreyboxAtlas.road_tileset()
	_ground.position = Iso.layer_offset(_ground, Iso.GROUND_PER_TILE)
	_road.position = Iso.layer_offset(_road, 1)


## Draws the tiles `buffer` has now and every later change, instead of the last buffer's, which it
## erases and stops following. Call build() first.
func bind(buffer: RoadBuffer) -> void:
	if _buffer != null:
		_buffer.tiles_generated.disconnect(_on_tiles_generated)
		_buffer.tiles_freed.disconnect(_on_tiles_freed)
	_ground.clear()
	_road.clear()
	_buffer = buffer
	buffer.tiles_generated.connect(_on_tiles_generated)
	buffer.tiles_freed.connect(_on_tiles_freed)
	_on_tiles_generated(buffer.tiles())


func _on_tiles_generated(tiles: Array[RoadTile]) -> void:
	for tile: RoadTile in tiles:
		_road.set_cell(tile.cell, 0, GreyboxAtlas.road_coords(tile, show_dead_ends))
		var column: int = _area_columns.get(tile.area_id, 0)
		for ground: Vector2i in _ground_cells(tile.cell):
			_ground.set_cell(ground, 0, GreyboxAtlas.ground_coords(column, ground))


func _on_tiles_freed(tiles: Array[RoadTile]) -> void:
	for tile: RoadTile in tiles:
		_road.erase_cell(tile.cell)
		for ground: Vector2i in _ground_cells(tile.cell):
			_ground.erase_cell(ground)


static func _ground_cells(cell: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y: int in Iso.GROUND_PER_TILE:
		for x: int in Iso.GROUND_PER_TILE:
			cells.append(cell * Iso.GROUND_PER_TILE + Vector2i(x, y))
	return cells
