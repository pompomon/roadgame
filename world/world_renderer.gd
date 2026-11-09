class_name WorldRenderer
extends Node2D
## Draws the tiles of a RoadBuffer on the grey-box layers (IMPLEMENTATION_PLAN.md M1.6): one road
## cell and 4×4 ground cells per tile, erased when the buffer frees the tile. The ground of the
## first TRANSITION_TILES path tiles of an area blends with the last area's (M4.3). Each run of
## set-piece tiles gets its scene once the buffer has made the whole run, which may take two
## batches, and loses it with the run's last tile (M4.4). build() makes the tilesets once; bind()
## draws a run's buffer, and a retry binds the next run's (M3_PLAN.md J11).

## Tint dead ends. For debug views only: in a run they must look like real road.
@export var show_dead_ends := false
## The scene of each set piece, by its id in the schedule (RoadTile.set_piece).
@export var set_piece_scenes: Dictionary[StringName, PackedScene] = {}

## The run's car, which the set pieces follow, or null. bind() clears it.
var car: Node2D:
	set = set_car

var _area_columns: Dictionary[StringName, int] = {}
## Ground columns of the transitions between the schedule's areas, by _transition_key().
var _transition_columns: Dictionary[String, int] = {}
## The buffer it draws, or null before the first bind().
var _buffer: RoadBuffer
## The tiles so far of a run of set-piece tiles that the buffer hasn't finished.
var _open_run: Array[RoadTile] = []
## The set pieces, by the path index of their run's last tile.
var _set_pieces_by_end: Dictionary[int, SetPiece] = {}

@onready var _ground: TileMapLayer = %GroundLayer
@onready var _road: TileMapLayer = %RoadLayer
@onready var _set_pieces: Node2D = %SetPieces


## Builds the tilesets for the areas of `schedule`. Call it once, when the node is ready.
func build(schedule: AreaSchedule) -> void:
	var colors: Array[Color] = []
	for entry: AreaScheduleEntry in schedule.entries:
		if not _area_columns.has(entry.area.id):
			_area_columns[entry.area.id] = colors.size()
			colors.append(entry.area.id_color)
	var transitions: Array[Vector2i] = []
	for k: int in range(1, schedule.entries.size()):
		var from := schedule.entries[k - 1].area.id
		var to := schedule.entries[k].area.id
		var key := _transition_key(from, to)
		if from != to and not _transition_columns.has(key):
			_transition_columns[key] = colors.size() + transitions.size()
			transitions.append(Vector2i(_area_columns[from], _area_columns[to]))
	_ground.tile_set = GreyboxAtlas.build_ground_tileset(colors, transitions)
	_road.tile_set = GreyboxAtlas.road_tileset()
	_ground.position = Iso.layer_offset(_ground, Iso.GROUND_PER_TILE)
	_road.position = Iso.layer_offset(_road, 1)
	for entry: AreaScheduleEntry in schedule.entries:
		if entry.set_piece != &"" and not set_piece_scenes.has(entry.set_piece):
			push_error("WorldRenderer: no scene for set piece %s" % entry.set_piece)


## Draws the tiles `buffer` has now and every later change, instead of the last buffer's, which it
## erases and stops following. Call build() first.
func bind(buffer: RoadBuffer) -> void:
	if _buffer != null:
		_buffer.tiles_generated.disconnect(_on_tiles_generated)
		_buffer.tiles_freed.disconnect(_on_tiles_freed)
	_ground.clear()
	_road.clear()
	for piece: SetPiece in _set_pieces_by_end.values():
		piece.free()
	_set_pieces_by_end.clear()
	_open_run.clear()
	car = null
	_buffer = buffer
	buffer.tiles_generated.connect(_on_tiles_generated)
	buffer.tiles_freed.connect(_on_tiles_freed)
	_on_tiles_generated(buffer.tiles())


## Sets the car and gives it to the set pieces.
func set_car(value: Node2D) -> void:
	car = value
	for piece: SetPiece in _set_pieces_by_end.values():
		piece.car = value


func _on_tiles_generated(tiles: Array[RoadTile]) -> void:
	for tile: RoadTile in tiles:
		_road.set_cell(tile.cell, 0, GreyboxAtlas.road_coords(tile, show_dead_ends))
		var column := _ground_column(tile)
		for ground: Vector2i in _ground_cells(tile.cell):
			_ground.set_cell(ground, 0, GreyboxAtlas.ground_coords(column, ground))
		if tile.path_index >= 0:
			_follow_set_pieces(tile)


func _on_tiles_freed(tiles: Array[RoadTile]) -> void:
	for tile: RoadTile in tiles:
		_road.erase_cell(tile.cell)
		for ground: Vector2i in _ground_cells(tile.cell):
			_ground.erase_cell(ground)
		if tile.path_index >= 0 and _set_pieces_by_end.has(tile.path_index):
			_set_pieces_by_end[tile.path_index].free()
			_set_pieces_by_end.erase(tile.path_index)


## Adds path tile `tile` to the open run of set-piece tiles, or ends that run with it: the next
## path tile after a run is the first that isn't one of its set-piece tiles.
func _follow_set_pieces(tile: RoadTile) -> void:
	if not _open_run.is_empty() and tile.set_piece != _open_run[0].set_piece:
		_add_set_piece(_open_run)
		_open_run = []
	if tile.type == RoadTile.Type.SET_PIECE:
		_open_run.append(tile)


func _add_set_piece(run: Array[RoadTile]) -> void:
	var scene: PackedScene = set_piece_scenes.get(run[0].set_piece)
	if scene == null:
		return
	var piece := scene.instantiate() as SetPiece
	piece.car = car
	_set_pieces.add_child(piece)
	piece.setup(run[0], run.size())
	_set_pieces_by_end[run[-1].path_index] = piece


## The ground column of `tile`: its area's, or the transition's on the first TRANSITION_TILES path
## tiles of an area. Those are straights, as min_straight is at least 2 (D7), so no dead end needs
## one. The tiles before them are still in the buffer: it keeps 5 behind the car and makes new tiles
## 25 ahead.
func _ground_column(tile: RoadTile) -> int:
	var column: int = _area_columns.get(tile.area_id, 0)
	if tile.path_index < 0:
		return column
	for k: int in range(1, Tuning.TRANSITION_TILES + 1):
		var before := _buffer.path_tile(tile.path_index - k)
		if before != null and before.area_id != tile.area_id:
			return _transition_columns.get(_transition_key(before.area_id, tile.area_id), column)
	return column


static func _transition_key(from: StringName, to: StringName) -> String:
	return "%s>%s" % [from, to]


static func _ground_cells(cell: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y: int in Iso.GROUND_PER_TILE:
		for x: int in Iso.GROUND_PER_TILE:
			cells.append(cell * Iso.GROUND_PER_TILE + Vector2i(x, y))
	return cells
