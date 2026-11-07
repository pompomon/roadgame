class_name RoadGenerator
extends RefCounted
## Streams the correct path one tile at a time (IMPLEMENTATION_PLAN.md D3, M1.4). A junction comes
## with its dead-end branches attached. Every tile is in `occupancy` when it is returned.
##
## The path heads N, then alternates W and N, so it moves only towards -x and -y. Wrong exits point
## E or S, or straight on (N or W) while the path turns. A dead end therefore never touches a past
## or future path cell, only other dead ends within 6 path steps. The opposite-turn stub of one
## tile always fits, so every junction keeps a wrong exit.

var occupancy := OccupancyGrid.new()
var current_area: AreaDef
## Junctions emitted so far, which is also the next junction's turn_number.
var turn_count := 0
## Dead ends shortened to 1 tile, and wrong exits dropped, because their cells were taken.
var shortened_count := 0
var dropped_count := 0

var _schedule: AreaSchedule
var _schedule_index := 1
var _pending_area: AreaDef
var _set_piece := &""
var _set_piece_left := 0
var _straight_left := Tuning.START_STRAIGHT_TILES
var _cursor := Vector2i.ZERO
var _heading: int = Heading.N
var _next_index := 0
var _rng_road := RandomNumberGenerator.new()


func _init(run_seed: int, schedule: AreaSchedule) -> void:
	for problem: String in schedule.validate():
		push_error("AreaSchedule: " + problem)
	_schedule = schedule
	current_area = schedule.entries[0].area
	_rng_road.seed = hash("%d:road" % run_seed)


## Returns the next correct-path tile.
func next_tile() -> RoadTile:
	var tile: RoadTile
	if _set_piece_left > 0:
		tile = _path_tile(RoadTile.Type.SET_PIECE)
		tile.set_piece = _set_piece
		_set_piece_left -= 1
		if _set_piece_left == 0:
			_enter_area(_pending_area)
	elif _straight_left > 0:
		tile = _path_tile(RoadTile.Type.STRAIGHT)
		_straight_left -= 1
	else:
		tile = _junction()
	_cursor += Heading.VEC[_heading]
	_next_index += 1
	return tile


func _path_tile(type: RoadTile.Type) -> RoadTile:
	var exits := Heading.bit(Heading.opposite(_heading)) | Heading.bit(_heading)
	var tile := RoadTile.new(_cursor, type, _heading, exits)
	tile.path_index = _next_index
	tile.area_id = current_area.id
	occupancy.claim(tile)
	return tile


func _junction() -> RoadTile:
	var expected := Heading.turn_for(turn_count, _heading)
	var junction := _path_tile(RoadTile.Type.T_JUNCTION)
	junction.exits = Heading.bit(Heading.opposite(_heading)) | Heading.bit(expected)
	junction.turn_number = turn_count
	junction.expected_exit = expected
	var wrong: Array[int] = [Heading.opposite(expected)]
	if _rng_road.randf() < current_area.cross_junction_chance:
		wrong.append(_heading)
	for exit: int in wrong:
		var length := _rng_road.randi_range(Tuning.DEAD_END_MIN_TILES, Tuning.DEAD_END_MAX_TILES)
		_place_dead_end(junction, exit, length)
	if junction.branches.is_empty():
		push_error("RoadGenerator: junction %d has no wrong exit" % junction.turn_number)
	if junction.exits == Heading.ALL:
		junction.type = RoadTile.Type.CROSS_JUNCTION
	_heading = expected
	turn_count += 1
	var entry := _due_entry()
	if entry == null:
		_straight_left = _sample_straight()
	elif entry.set_piece_length > 0:
		_pending_area = entry.area
		_set_piece = entry.set_piece
		_set_piece_left = entry.set_piece_length
	else:
		_enter_area(entry.area)
	return junction


## Adds a dead end of `length` tiles, or of 1 tile if a cell is taken (plan.md §3.3).
func _place_dead_end(junction: RoadTile, exit: int, length: int) -> void:
	if not _is_free_run(junction.cell, exit, length):
		if length == 1 or not _is_free_run(junction.cell, exit, 1):
			dropped_count += 1
			return
		length = 1
		shortened_count += 1
	for k: int in range(1, length + 1):
		var exits := Heading.bit(Heading.opposite(exit))
		if k < length:
			exits |= Heading.bit(exit)
		var cell := junction.cell + Heading.VEC[exit] * k
		var tile := RoadTile.new(cell, RoadTile.Type.DEAD_END, exit, exits)
		tile.area_id = junction.area_id
		tile.junction_index = junction.path_index
		tile.branch_exit = exit
		occupancy.claim(tile)
		junction.branches.append(tile)
	junction.exits |= Heading.bit(exit)


func _is_free_run(from: Vector2i, exit: int, length: int) -> bool:
	for k: int in range(1, length + 1):
		if not occupancy.is_free(from + Heading.VEC[exit] * k):
			return false
	return true


func _due_entry() -> AreaScheduleEntry:
	if _schedule_index >= _schedule.entries.size():
		return null
	var entry := _schedule.entries[_schedule_index]
	if entry.turn != turn_count:
		return null
	_schedule_index += 1
	return entry


func _enter_area(area: AreaDef) -> void:
	current_area = area
	_pending_area = null
	_straight_left = _sample_straight()


func _sample_straight() -> int:
	return _rng_road.randi_range(current_area.min_straight, current_area.max_straight)
