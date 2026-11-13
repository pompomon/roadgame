class_name WorldRenderer
extends Node2D
## Draws the tiles of a RoadBuffer (IMPLEMENTATION_PLAN.md M1.6): one road cell per tile, from its
## area's road sheet, erased when the buffer frees the tile. The ground isn't drawn per tile: each
## area the path goes through gets a band of its ground across the screen (M5_PLAN.md §5.5). The
## path heads only N or W, up the screen, so an area's path tiles lie between two screen rows: its
## band reaches from its first path tiles up to where the next area's begins. Its edge blends it
## into the last area's ground over its first TRANSITION_TILES path tiles (M4.3). Each run of
## set-piece tiles gets its scene once the buffer has made the whole run, which may take two
## batches, and loses it with the run's last tile (M4.4). build() makes the tileset once; bind()
## draws a run's buffer, and a retry binds the next run's (M3_PLAN.md J11).

## How far the ground reaches past the buffered tiles, in world pixels: farther than any view can
## show past them. The camera follows the car, which stays between the buffer's oldest and newest
## path tiles, and shows about VISIBLE_TILES tiles across the screen's shorter side: some 1,000 px
## across, or 1,400 px above the car, on the longest screens.
const GROUND_MARGIN := 2048.0


## The ground of one stretch of the path in one area: a sprite whose region repeats the area's
## ground, and the edge as its child, below its line.
class Band:
	extends RefCounted
	var area_id: StringName
	var sprite: Sprite2D
	## Null for the first area of a run, below which there is nothing to blend into.
	var edge: Sprite2D
	## The screen y where the edge ends and the solid ground begins: the centre of the area's path
	## tile TRANSITION_TILES on. The ground's first row is there, and the edge's.
	var line: float


## Tint dead ends. For debug views only: in a run they must look like real road.
@export var show_dead_ends := false
## The scene of each set piece, by its id in the schedule (RoadTile.set_piece). Its root is a
## SetPiece.
@export var set_piece_scenes: Dictionary[StringName, PackedScene] = {}

## The run's car, which the set pieces follow, or null. bind() clears it.
var car: Node2D:
	set = set_car
## The zone's clock, whose shadows the props and the car cast (DAYNIGHT_PLAN.md §5.11), or null for
## none. main.gd sets it to Daylight's.
var cycle: DayCycle

## The schedule's areas, and the source of each one's road sheet in the tileset, by id.
var _areas: Dictionary[StringName, AreaDef] = {}
var _road_sources: Dictionary[StringName, int] = {}
## The buffer it draws, or null before the first bind().
var _buffer: RoadBuffer
## The ground bands, oldest first. Each draws over the last.
var _bands: Array[Band] = []
## The car's skid marks (M5_PLAN.md §5.7), on the Skids layer. build() makes it.
var _skids: SkidMarks
## The tiles so far of a run of set-piece tiles that the buffer hasn't finished.
var _open_run: Array[RoadTile] = []
## The set pieces, by the path index of their run's last tile.
var _set_pieces_by_end: Dictionary[int, SetPiece] = {}
## The props beside the road (M5_PLAN.md §5.6), on the Props layer. build() makes it.
var _scatter: PropScatter

@onready var _ground: Node2D = %Ground
@onready var _shadows: Shadows = %Shadows
@onready var _road: TileMapLayer = %RoadLayer
@onready var _set_pieces: Node2D = %SetPieces


func _physics_process(_delta: float) -> void:
	var controller := car as CarController
	if _skids != null and controller != null:
		_skids.update(controller.sim)


## Builds the road tileset for the areas of `schedule`. Call it once, when the node is ready.
func build(schedule: AreaSchedule) -> void:
	var sheets: Array[Texture2D] = []
	for entry: AreaScheduleEntry in schedule.entries:
		if not _areas.has(entry.area.id):
			_areas[entry.area.id] = entry.area
			_road_sources[entry.area.id] = sheets.size()
			sheets.append(entry.area.road_sheet)
	_road.tile_set = GreyboxAtlas.road_tileset(sheets)
	_road.position = Iso.layer_offset(_road, 1)
	_skids = SkidMarks.new(%Skids as Node2D)
	for entry: AreaScheduleEntry in schedule.entries:
		if entry.set_piece != &"" and set_piece_scenes.get(entry.set_piece) == null:
			push_error("WorldRenderer: no scene for set piece %s" % entry.set_piece)
	_scatter = PropScatter.new(%Props as Node2D, schedule)
	_scatter.shadows = _shadows


## Draws the tiles `buffer` has now and every later change, instead of the last buffer's, which it
## erases and stops following. Call build() first.
func bind(buffer: RoadBuffer) -> void:
	if _buffer != null:
		_buffer.tiles_generated.disconnect(_on_tiles_generated)
		_buffer.tiles_freed.disconnect(_on_tiles_freed)
	_road.clear()
	_skids.bind(buffer)
	for band: Band in _bands:
		band.sprite.free()
	_bands.clear()
	for piece: SetPiece in _set_pieces_by_end.values():
		piece.free()
	_set_pieces_by_end.clear()
	_open_run.clear()
	car = null
	_buffer = buffer
	buffer.tiles_generated.connect(_on_tiles_generated)
	buffer.tiles_freed.connect(_on_tiles_freed)
	_on_tiles_generated(buffer.tiles())
	_scatter.bind(buffer)


## Sets the car and gives it to the set pieces.
func set_car(value: Node2D) -> void:
	car = value
	for piece: SetPiece in _set_pieces_by_end.values():
		piece.car = value


func _process(delta: float) -> void:
	_shadows.refresh(cycle, car as CarController)
	if _scatter != null:
		_scatter.update(delta)


## The props beside the road, or null before build().
func prop_scatter() -> PropScatter:
	return _scatter


func _on_tiles_generated(tiles: Array[RoadTile]) -> void:
	for tile: RoadTile in tiles:
		var source: int = _road_sources.get(tile.area_id, 0)
		_road.set_cell(tile.cell, source, GreyboxAtlas.road_coords(tile, show_dead_ends))
		if tile.path_index >= 0:
			if _bands.is_empty() or _bands[-1].area_id != tile.area_id:
				_add_band(tile)
			_follow_set_pieces(tile)
	if not tiles.is_empty():
		_fit_bands()


func _on_tiles_freed(tiles: Array[RoadTile]) -> void:
	for tile: RoadTile in tiles:
		_road.erase_cell(tile.cell)
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
	var node: Node = scene.instantiate() if scene.can_instantiate() else null
	if node is not SetPiece:
		push_error("WorldRenderer: the scene for set piece %s isn't a SetPiece" % run[0].set_piece)
		if node != null:
			node.free()
		return
	var piece := node as SetPiece
	piece.car = car
	_set_pieces.add_child(piece)
	piece.setup(run[0], run.size())
	_set_pieces_by_end[run[-1].path_index] = piece


## Begins the ground of the area of path tile `tile`, the area's first. An area the schedule hasn't
## got looks like its first area, as its road does.
func _add_band(tile: RoadTile) -> void:
	var area: AreaDef = _areas.get(tile.area_id, _areas.values()[0])
	var band := Band.new()
	band.area_id = tile.area_id
	band.line = _centre_y(tile.cell)
	var ground := area.ground if area.ground != null else GreyboxAtlas.ground_texture(area.id_color)
	band.sprite = _band_sprite(ground)
	_ground.add_child(band.sprite)
	if not _bands.is_empty():
		band.line -= GreyboxAtlas.edge_rows()
		var edge := area.ground_edge
		if area.ground == null:
			edge = GreyboxAtlas.edge_texture(area.id_color)
		if edge != null:
			band.edge = _band_sprite(edge)
			band.sprite.add_child(band.edge)
	_bands.append(band)


## Fits the bands to the buffer: each reaches GROUND_MARGIN past the buffered tiles on either side,
## from its line up to the next band's, the newest GROUND_MARGIN past the newest path tile and the
## oldest as far below its line. A band whose next band begins GROUND_MARGIN below the oldest path
## tile can't show again, and goes. A region keeps the texture's columns where the world's are and
## its first row at the band's line, so that the ground stays put as its band grows.
func _fit_bands() -> void:
	var oldest := _centre_y(_buffer.path_tile(_buffer.first_index()).cell)
	while _bands.size() > 1 and _bands[1].line >= oldest + GROUND_MARGIN:
		_bands.pop_front().sprite.free()
	var left := INF
	var right := -INF
	for tile: RoadTile in _buffer.tiles():
		var x := Iso.tile_to_world(Iso.cell_centre(tile.cell)).x
		left = minf(left, x)
		right = maxf(right, x)
	var top := _centre_y(_buffer.path_tile(_buffer.last_index()).cell) - GROUND_MARGIN
	for k: int in range(_bands.size() - 1, -1, -1):
		var band := _bands[k]
		var bottom := band.line + (GROUND_MARGIN if k == 0 else 0.0)
		var period := float(band.sprite.texture.get_width())
		var x0 := floorf((left - GROUND_MARGIN) / period) * period
		var x1 := ceilf((right + GROUND_MARGIN) / period) * period
		band.sprite.position = Vector2(x0, top)
		band.sprite.region_rect = Rect2(x0, top - band.line, x1 - x0, bottom - top)
		if band.edge != null:
			band.edge.position = Vector2(0.0, band.line - top)
			band.edge.region_rect = Rect2(x0, 0.0, x1 - x0, band.edge.texture.get_height())
		top = band.line


static func _band_sprite(texture: Texture2D) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = false
	sprite.region_enabled = true
	sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	return sprite


static func _centre_y(cell: Vector2i) -> float:
	return Iso.tile_to_world(Iso.cell_centre(cell)).y
