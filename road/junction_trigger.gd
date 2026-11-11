class_name JunctionTrigger
extends RefCounted
## Decides which exit the car took at each junction and checks it against the L/R pattern
## (plan.md §4.1, IMPLEMENTATION_PLAN.md D5, M2.3). Pure logic: CarSim reports cell crossings,
## rejoins and the off-road limit, and the run's owner relays the signals to EventBus.

## A correct exit: the pattern's turn, or straight on at a decoy, which leaves `turn_index`, the
## number of correct turns so far, as it was (ROADGEN_PLAN.md R2).
signal turn_completed(turn_index: int)
## A wrong exit, whose heading is `choice`, or a missed turn (`choice` -1). The trigger then stops.
signal disaster_triggered(junction: RoadTile, choice: int)

## Correct turns so far.
var turn_index := 0
## The first unresolved junction ahead, or null after a disaster.
var next_junction: RoadTile

var _buffer: RoadBuffer


## `buffer` must have started.
func _init(buffer: RoadBuffer) -> void:
	_buffer = buffer
	next_junction = _junction_after(buffer.first_index() - 1)


## The car crossed from `from_cell` into the neighbouring `to_cell`, on the road if `on_road`.
## Leaving the next junction's tile on the road through one of its exits decides that exit; going
## back out of the entry edge decides nothing.
func on_cell_crossed(from_cell: Vector2i, to_cell: Vector2i, on_road: bool) -> void:
	var junction := next_junction
	if junction == null or not on_road or from_cell != junction.cell:
		return
	var exit := Heading.from_vec(to_cell - from_cell)
	if exit != -1 and exit != Heading.opposite(junction.heading) and junction.has_exit(exit):
		_resolve(exit)


## The car came back onto the road on `tile`. A dead end of the next junction decides that wrong
## exit. A correct-path tile past the junction, or a later junction's dead end, decides the correct
## exit, and is then checked against the following junction. Anything else decides nothing.
func on_rejoin(tile: RoadTile) -> void:
	while next_junction != null:
		var index := next_junction.path_index
		if tile.junction_index == index:
			_resolve(tile.branch_exit)
			return
		if tile.path_index <= index and tile.junction_index < index:
			return
		_resolve(next_junction.expected_exit)


## The car reached the off-road limit after leaving the road near the next junction.
func on_offroad_limit() -> void:
	if next_junction != null:
		_fail(-1)


func _resolve(choice: int) -> void:
	if choice != next_junction.expected_exit:
		_fail(choice)
		return
	if next_junction.is_turn():
		turn_index += 1
	next_junction = _junction_after(next_junction.path_index)
	turn_completed.emit(turn_index)


func _fail(choice: int) -> void:
	var junction := next_junction
	next_junction = null
	disaster_triggered.emit(junction, choice)


## The first junction after path index `index`. The buffer always has one: junctions are at most
## a set piece and a straight apart, well under its 25-tile lookahead.
func _junction_after(index: int) -> RoadTile:
	for i: int in range(maxi(index + 1, _buffer.first_index()), _buffer.last_index() + 1):
		var tile := _buffer.path_tile(i)
		if tile.is_junction():
			return tile
	push_error("JunctionTrigger: no junction after path index %d" % index)
	return null
