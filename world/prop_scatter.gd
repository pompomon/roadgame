class_name PropScatter
extends RefCounted
## Scatters each area's props beside the road (plan.md §5.2, M5_PLAN.md §5.6) on World's Props
## layer, which y-sorts them with the car. Each screen row of the path gets its props from
## PropLayout once the car is PROP_AHEAD path tiles before the row's path tile, so a row at a time
## as the car drives, and loses them when the buffer frees that tile. With BUFFER_BEHIND and
## BUFFER_REFILL_AT, neither shows on the reference screens (M5_PLAN.md L2). The BUFFER_BEHIND rows
## below the first path tile get the props of its area at the start, and lose them with it.
## WorldRenderer makes it, binds it with itself and updates it every frame.


## A prop that shows.
class Shown:
	extends RefCounted
	var sprite: Sprite2D
	var def: PropDef
	var phase: float


## The props of a row, and those of them that animate.
class Row:
	extends RefCounted
	var shown: Array[Shown] = []
	var animated: Array[Shown] = []


var pool: PropPool

## The props of each area of the schedule that keep the contract, by the area's id.
var _props: Dictionary[StringName, Array] = {}
## The area of the bound road's first path tile. A run can start in any area of the schedule
## (ZONE_SELECT_PLAN.md Z3).
var _first_area := &""
var _buffer: RoadBuffer
## The rows that have their props, by their path tile's index.
var _rows: Dictionary[int, Row] = {}
## The next row to get its props, and the lowest row that may still have them.
var _next_row := 0
var _lowest_row := 0
## Seconds of animation since bind().
var _clock := 0.0


## Scatters the props of `schedule`'s areas on `layer`. A prop that breaks the contract is an
## error, and doesn't show.
func _init(layer: Node2D, schedule: AreaSchedule) -> void:
	pool = PropPool.new(layer)
	for entry: AreaScheduleEntry in schedule.entries:
		if not _props.has(entry.area.id):
			_props[entry.area.id] = _valid_props(entry.area)


## Shows the props beside `buffer`'s road from now on, instead of the last buffer's.
func bind(buffer: RoadBuffer) -> void:
	if _buffer != null:
		_buffer.tiles_generated.disconnect(_on_tiles_generated)
		_buffer.tiles_freed.disconnect(_on_tiles_freed)
	for k: int in _rows.keys():
		_hide_row(k)
	_buffer = buffer
	_first_area = buffer.generator.first_area().id
	_lowest_row = -Tuning.BUFFER_BEHIND if buffer.first_index() == 0 else buffer.first_index()
	_next_row = _lowest_row
	_clock = 0.0
	buffer.tiles_generated.connect(_on_tiles_generated)
	buffer.tiles_freed.connect(_on_tiles_freed)
	_show_rows()


## Shows the rows the car has come near, and animates the props. Call it every frame.
func update(delta: float) -> void:
	if _buffer == null:
		return
	_show_rows()
	_clock += delta
	for row: Row in _rows.values():
		for shown: Shown in row.animated:
			_set_frame(shown)


## The path tile indices of the rows that have their props, lowest first.
func rows() -> Array[int]:
	var keys: Array[int] = []
	keys.assign(_rows.keys())
	keys.sort()
	return keys


## The sprites of the props of row `k`.
func sprites(k: int) -> Array[Sprite2D]:
	var found: Array[Sprite2D] = []
	if _rows.has(k):
		for shown: Shown in _rows[k].shown:
			found.append(shown.sprite)
	return found


func _on_tiles_generated(_tiles: Array[RoadTile]) -> void:
	_show_rows()


func _on_tiles_freed(_tiles: Array[RoadTile]) -> void:
	while _lowest_row < _buffer.first_index():
		_hide_row(_lowest_row)
		_lowest_row += 1


## Gives their props to the rows up to PROP_AHEAD path tiles past the car's whose road is made,
## from the lowest row the buffer still has.
func _show_rows() -> void:
	var last := mini(
		_buffer.car_index() + Tuning.PROP_AHEAD, _buffer.last_index() - PropLayout.rows_needed()
	)
	_next_row = maxi(_next_row, _lowest_row)
	while _next_row <= last:
		_show_row(_next_row)
		_next_row += 1


## The cell of row `k` that its props spread either side of: its path tile's, or below the start,
## the cell of the row that is closest to below path tile 0's, on (0, 0).
func anchor(k: int) -> Vector2i:
	if k >= 0:
		return _buffer.path_tile(k).cell
	var below := -k
	return Vector2i(below >> 1, below - (below >> 1))


func _show_row(k: int) -> void:
	var area := _first_area if k < 0 else _buffer.path_tile(k).area_id
	var props: Array[PropDef] = []
	if _props.has(area):
		props = _props[area]
	var row := Row.new()
	for placement: PropLayout.Placement in PropLayout.row(
		anchor(k), props, _buffer.generator.props_seed, _buffer
	):
		var shown := Shown.new()
		shown.def = placement.def
		shown.phase = placement.phase
		shown.sprite = pool.acquire(placement.def)
		shown.sprite.position = placement.foot
		row.shown.append(shown)
		if placement.def.frames > 1:
			row.animated.append(shown)
			_set_frame(shown)
	_rows[k] = row


func _hide_row(k: int) -> void:
	if _rows.has(k):
		for shown: Shown in _rows[k].shown:
			pool.release(shown.sprite)
		_rows.erase(k)


func _set_frame(shown: Shown) -> void:
	var cycle := _clock * shown.def.fps / shown.def.frames + shown.phase
	var frame := int((cycle - floorf(cycle)) * shown.def.frames) % shown.def.frames
	if shown.sprite.frame != frame:
		shown.sprite.frame = frame


static func _valid_props(area: AreaDef) -> Array[PropDef]:
	var valid: Array[PropDef] = []
	var density := 0.0
	for prop: PropDef in area.props:
		var problems := PackedStringArray(["a prop is null"]) if prop == null else prop.validate()
		if problems.is_empty() and density + prop.density > 1.0:
			problems.append("prop %s takes the densities past 1" % prop.id)
		for problem: String in problems:
			push_error("PropScatter: %s: %s" % [area.id, problem])
		if problems.is_empty():
			valid.append(prop)
			density += prop.density
	return valid
