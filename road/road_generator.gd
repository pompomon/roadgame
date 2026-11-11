class_name RoadGenerator
extends RefCounted
## Streams the correct path one tile at a time (IMPLEMENTATION_PLAN.md D3, M1.4). A junction comes
## with its dead-end branches attached. Every tile is in `occupancy` when it is returned.
##
## Each junction is of a Kind that the area's chances pick (ROADGEN_PLAN.md R1, R2). A decoy
## doesn't offer the pattern's next turn, so straight on is its correct exit, and the turn waits
## for the next junction.
##
## The path heads N, then alternates W and N, so it moves only towards -x and -y. Wrong exits point
## E or S, or straight on (N or W) while the path turns. A dead end therefore never touches a past
## or future path cell, only other dead ends within twice DEAD_END_MAX_TILES path steps. Straights
## are at least 2 tiles (D7), so an opposite-turn dead end always has 2 free cells, and a
## straight-on dead end always fits whole: every junction keeps a wrong exit (ROADGEN_PLAN.md R5).

## The exits a junction offers besides its entry. T: the turn and the opposite turn. CROSSROADS:
## straight on as well. SIDE_ROAD: the turn and straight on. DECOY: straight on, which is correct,
## and the opposite turn.
enum Kind { T, CROSSROADS, SIDE_ROAD, DECOY }

var occupancy := OccupancyGrid.new()
var current_area: AreaDef
## Turns emitted so far, which is also the next junction's turn_number. A decoy is no turn.
var turn_count := 0
## Dead ends cut short by a taken cell, and wrong exits dropped because their first cell was taken.
var shortened_count := 0
var dropped_count := 0
## The seed of the run's props (M5_PLAN.md §5.6). They hash it with each ground cell and take no
## number from the road's stream, so they can't change the road (IMPLEMENTATION_PLAN.md §5.3).
var props_seed := 0

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
	var problems := PackedStringArray(["there is no schedule"])
	if schedule != null:
		problems = schedule.validate()
	for problem: String in problems:
		push_error("AreaSchedule: " + problem)
	# A broken schedule is never read: the road goes on in one area with the default rules.
	_schedule = schedule if problems.is_empty() else _fallback_schedule()
	current_area = _schedule.entries[0].area
	_rng_road.seed = hash("%d:road" % run_seed)
	props_seed = hash("%d:props" % run_seed)


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


## The kind of junction that `roll`, from 0 to 1, picks in `area`. The crossroads, side road and
## decoy chances take their parts of 0..1 in that order, and T the rest: one roll per junction, as
## M1 drew for a crossroads alone, so an area with no side roads or decoys keeps its road.
static func kind_for(roll: float, area: AreaDef) -> Kind:
	var bound := area.cross_junction_chance
	if roll < bound:
		return Kind.CROSSROADS
	bound += area.side_road_chance
	if roll < bound:
		return Kind.SIDE_ROAD
	bound += area.decoy_chance
	if roll < bound:
		return Kind.DECOY
	return Kind.T


## The schedule's area whose id is `id`. Every tile's area_id names one; for any other id, the
## first area.
func find_area(id: StringName) -> AreaDef:
	for entry: AreaScheduleEntry in _schedule.entries:
		if entry.area.id == id:
			return entry.area
	push_error("RoadGenerator: no area %s in the schedule" % id)
	return _schedule.entries[0].area


func _path_tile(type: RoadTile.Type) -> RoadTile:
	var exits := Heading.bit(Heading.opposite(_heading)) | Heading.bit(_heading)
	var tile := RoadTile.new(_cursor, type, _heading, exits)
	tile.path_index = _next_index
	tile.area_id = current_area.id
	occupancy.claim(tile)
	return tile


func _junction() -> RoadTile:
	var turn := Heading.turn_for(turn_count, _heading)
	var kind := kind_for(_rng_road.randf(), current_area)
	var junction := _path_tile(RoadTile.Type.T_JUNCTION)
	junction.turn_number = turn_count
	junction.expected_exit = _heading if kind == Kind.DECOY else turn
	junction.exits = Heading.bit(Heading.opposite(_heading)) | Heading.bit(junction.expected_exit)
	var wrong: Array[int] = []
	if kind != Kind.SIDE_ROAD:
		wrong.append(Heading.opposite(turn))
	if kind == Kind.CROSSROADS or kind == Kind.SIDE_ROAD:
		wrong.append(_heading)
	for exit: int in wrong:
		var length := _rng_road.randi_range(Tuning.DEAD_END_MIN_TILES, Tuning.DEAD_END_MAX_TILES)
		_place_dead_end(junction, exit, length)
	if junction.branches.is_empty():
		push_error("RoadGenerator: junction %d has no wrong exit" % junction.turn_number)
	if junction.exits == Heading.ALL:
		junction.type = RoadTile.Type.CROSS_JUNCTION
	if kind == Kind.DECOY:
		# No turn: the heading, the turn count and the schedule wait for the next junction.
		_straight_left = _sample_straight()
		return junction
	_heading = turn
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


## Adds a dead end of `length` tiles, or of the cells before the first taken one (plan.md §3.3,
## ROADGEN_PLAN.md R5).
func _place_dead_end(junction: RoadTile, exit: int, length: int) -> void:
	var fits := _free_run(junction.cell, exit, length)
	if fits == 0:
		dropped_count += 1
		return
	if fits < length:
		shortened_count += 1
	for k: int in range(1, fits + 1):
		var exits := Heading.bit(Heading.opposite(exit))
		if k < fits:
			exits |= Heading.bit(exit)
		var cell := junction.cell + Heading.VEC[exit] * k
		var tile := RoadTile.new(cell, RoadTile.Type.DEAD_END, exit, exits)
		tile.area_id = junction.area_id
		tile.junction_index = junction.path_index
		tile.branch_exit = exit
		occupancy.claim(tile)
		junction.branches.append(tile)
	junction.exits |= Heading.bit(exit)


## How many of the `length` cells past `from` towards `exit` are free, up to the first taken one.
func _free_run(from: Vector2i, exit: int, length: int) -> int:
	for k: int in range(1, length + 1):
		if not occupancy.is_free(from + Heading.VEC[exit] * k):
			return k - 1
	return length


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


static func _fallback_schedule() -> AreaSchedule:
	var area := AreaDef.new()
	area.id = &"fallback"
	var entry := AreaScheduleEntry.new()
	entry.area = area
	var schedule := AreaSchedule.new()
	schedule.entries = [entry]
	return schedule
