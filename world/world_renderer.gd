class_name WorldRenderer
extends Node2D
## Draws the tiles of a RoadBuffer on the grey-box layers (IMPLEMENTATION_PLAN.md M1.6): one road
## cell and 4×4 ground cells per tile, erased when the buffer frees the tile.

## Tint dead ends. For debug views only: in a run they must look like real road.
@export var show_dead_ends := false

var _area_columns: Dictionary[StringName, int] = {}

@onready var _ground: TileMapLayer = %GroundLayer
@onready var _road: TileMapLayer = %RoadLayer


## Draws the tiles `buffer` has now and every later change. Call it once, when the node is ready.
func bind(buffer: RoadBuffer, schedule: AreaSchedule) -> void:
	var colors: Array[Color] = []
	for entry: AreaScheduleEntry in schedule.entries:
		if not _area_columns.has(entry.area.id):
			_area_columns[entry.area.id] = colors.size()
			colors.append(entry.area.id_color)
	_ground.tile_set = GreyboxAtlas.build_ground_tileset(colors)
	_road.tile_set = GreyboxAtlas.road_tileset()
	_ground.position = Iso.layer_offset(_ground, Iso.GROUND_PER_TILE)
	_road.position = Iso.layer_offset(_road, 1)
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
