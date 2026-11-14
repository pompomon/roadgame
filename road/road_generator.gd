class_name RoadGenerator
extends RefCounted
## Streams the correct path one tile at a time (IMPLEMENTATION_PLAN.md D3, M1.4). A junction comes
## with its dead-end branches attached. Every tile is in `occupancy` when it is returned.
##
## Each junction is of a Kind that the area's chances pick (docs/ROADGEN.md R1, R2). A decoy
## doesn't offer the pattern's next turn, so straight on is its correct exit, and the turn waits
## for the next junction.
##
## The path heads N, then alternates W and N, so it moves only towards -x and -y. Wrong exits point
## E or S, or straight on (N or W) while the path turns. A dead end therefore never touches a past
## or future path cell, only other dead ends within twice DEAD_END_MAX_TILES path steps. Straights
## are at least 2 tiles (D7), so an opposite-turn dead end always has 2 free cells, and a
## straight-on dead end always fits whole: every junction keeps a wrong exit (docs/ROADGEN.md R5).
##
## A run may start with the tutorial (docs/TUTORIAL.md §5.1): T junctions in groups of four, A to D,
## whose wrong exits don't end but loop back to the path. A's wrong exit (E) loops round to C's
## (E), and B's (S) to D's (S), so a car that goes wrong comes back onto the path two junctions on,
## and one that goes the wrong way round a loop comes back where it went in. A loop turns no sooner
## after a junction or a corner than the path does, and touches no other road but at its ends. The
## tutorial's straights come from their own stream, so the road after it is the seed's road.
## end_tutorial() ends it after the group it is in.

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
## The seed of the run's props (docs/M5.md §5.6). They hash it with each ground cell and take no
## number from the road's stream, so they can't change the road (IMPLEMENTATION_PLAN.md §5.3).
var props_seed := 0
## Whether the next junction is the tutorial's (docs/TUTORIAL.md §5.1).
var tutorial := false

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
## The tutorial's straights, so that the road's stream starts afresh after it.
var _rng_tutorial := RandomNumberGenerator.new()
## Set by end_tutorial(): the tutorial ends with its group of four junctions.
var _ending := false
## The turns before the City's first turn after the tutorial: the schedule counts from there.
var _turn_base := 0
## The cell and path index of the tutorial's last junction, whose loop the next one finishes.
var _loop_start := Vector2i.ZERO
var _loop_start_index := -1


func _init(run_seed: int, schedule: AreaSchedule, p_tutorial := false) -> void:
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
	_rng_tutorial.seed = hash("%d:tutorial" % run_seed)
	tutorial = p_tutorial


## Ends the tutorial after the junctions of its group that are still to come, and counts the
## schedule's turns from `turn_base`, the turns before the City's first (docs/TUTORIAL.md §5.5).
func end_tutorial(turn_base: int) -> void:
	_ending = true
	_turn_base = turn_base


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


## The area that the road starts in, path tile 0's: the schedule's first.
func first_area() -> AreaDef:
	return _schedule.entries[0].area


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
	if tutorial and _ending and turn_count % 4 == 0:
		tutorial = false
	if tutorial:
		return _tutorial_junction()
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


## A junction of the tutorial (docs/TUTORIAL.md §5.1): a T whose wrong exit loops back. With A the
## group's first junction and s1 to s3 the straights after A to C, B = A + W(s1 + 1),
## C = B + N(s2 + 1) and D = C + W(s3 + 1). Each loop starts with a leg of L cells: the area's
## shortest straight, then a corner. A lays the leg from its E exit, and B, once it knows s2, the
## rest: up the column L E of A, then along C's row to C's E exit. B also lays the leg from its S
## exit, and C, once it knows s3, the rest: along the row L S of B, then up D's column to D's S
## exit.
func _tutorial_junction() -> RoadTile:
	var part := turn_count % 4
	var turn := Heading.turn_for(turn_count, _heading)
	var wrong := Heading.opposite(turn)
	var junction := _path_tile(RoadTile.Type.T_JUNCTION)
	junction.turn_number = turn_count
	junction.expected_exit = turn
	junction.exits = (
		Heading.bit(Heading.opposite(_heading)) | Heading.bit(turn) | Heading.bit(wrong)
	)
	var straight := _rng_tutorial.randi_range(current_area.min_straight, current_area.max_straight)
	var cell := junction.cell
	var index := junction.path_index
	var leg := current_area.min_straight + 1
	match part:
		0:
			_lay_leg(junction, Heading.E, Heading.N, leg)
		1:
			var c := cell + Heading.VEC[Heading.N] * (straight + 1)
			var cells := _leg(_loop_start, Heading.E, leg)
			var corner := cells[-1]
			for y: int in range(corner.y - 1, c.y - 1, -1):
				cells.append(Vector2i(corner.x, y))
			for x: int in range(corner.x - 1, c.x, -1):
				cells.append(Vector2i(x, c.y))
			_lay_loop(junction, _loop_start, _loop_start_index, cells, leg, c, index + straight + 1)
			_lay_leg(junction, Heading.S, Heading.W, leg)
		2:
			var d := cell + Heading.VEC[Heading.W] * (straight + 1)
			var cells := _leg(_loop_start, Heading.S, leg)
			var corner := cells[-1]
			for x: int in range(corner.x - 1, d.x - 1, -1):
				cells.append(Vector2i(x, corner.y))
			for y: int in range(corner.y - 1, d.y, -1):
				cells.append(Vector2i(d.x, y))
			_lay_loop(junction, _loop_start, _loop_start_index, cells, leg, d, index + straight + 1)
	_loop_start = cell
	_loop_start_index = index
	_heading = turn
	turn_count += 1
	_straight_left = straight
	return junction


## Lays the leg of `leg` cells from `junction`'s wrong exit `exit`: straights, then a corner
## towards `onward`. A loop is longer than twice its leg, so its leg is nearer its own junction.
func _lay_leg(junction: RoadTile, exit: int, onward: int, leg: int) -> void:
	var points: Array[Vector2i] = [junction.cell]
	points.append_array(_leg(junction.cell, exit, leg))
	points.append(points[-1] + Heading.VEC[onward])
	for k: int in range(1, leg + 1):
		_lay_loop_tile(junction, points[k], points[k - 1], points[k + 1], junction.path_index, exit)


## The `leg` cells past `from` towards `exit`.
static func _leg(from: Vector2i, exit: int, leg: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for k: int in range(1, leg + 1):
		cells.append(from + Heading.VEC[exit] * k)
	return cells


## Lays the loop on `cells` for `owner`, but its leg of `leg` cells, which the junction at `start`,
## with path index `start_index`, laid. The loop ends next to the junction at `end`, with
## `end_index`. Each tile belongs to the nearer of the two (the start if they are as near), as a
## part of that junction's wrong exit, so that a car that rejoins the road on it went wrong there.
func _lay_loop(
	owner: RoadTile,
	start: Vector2i,
	start_index: int,
	cells: Array[Vector2i],
	leg: int,
	end: Vector2i,
	end_index: int
) -> void:
	var points: Array[Vector2i] = [start]
	points.append_array(cells)
	points.append(end)
	var start_exit := Heading.from_vec(cells[0] - start)
	var end_exit := Heading.from_vec(cells[-1] - end)
	for k: int in range(leg, cells.size()):
		var near_start := k + 1 <= cells.size() - k
		var junction_index := start_index if near_start else end_index
		var exit := start_exit if near_start else end_exit
		_lay_loop_tile(owner, cells[k], points[k], points[k + 2], junction_index, exit)


## Lays a loop's tile on `cell`, between the cells `before` and `after`, for `owner`. It belongs to
## the junction with path index `junction_index`, whose wrong exit `branch_exit` the loop continues.
func _lay_loop_tile(
	owner: RoadTile,
	cell: Vector2i,
	before: Vector2i,
	after: Vector2i,
	junction_index: int,
	branch_exit: int
) -> void:
	var exits := Heading.bit(Heading.from_vec(before - cell))
	exits |= Heading.bit(Heading.from_vec(after - cell))
	var tile := RoadTile.new(cell, RoadTile.Type.DEAD_END, Heading.from_vec(cell - before), exits)
	tile.area_id = owner.area_id
	tile.junction_index = junction_index
	tile.branch_exit = branch_exit
	occupancy.claim(tile)
	owner.branches.append(tile)


## Adds a dead end of `length` tiles, or of the cells before the first taken one (plan.md §3.3,
## docs/ROADGEN.md R5).
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
	# Past the tutorial, the schedule counts from the City's first turn. The tutorial's junctions
	# don't come here, so an entry may be due when they are over (docs/TUTORIAL.md §5.5).
	if entry.turn > turn_count - _turn_base:
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
