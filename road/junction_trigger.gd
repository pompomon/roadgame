class_name JunctionTrigger
extends RefCounted
## Decides which exit the car took at each junction and checks it against the L/R pattern
## (plan.md §4.1, IMPLEMENTATION_PLAN.md D5, M2.3). Pure logic: CarSim reports cell crossings,
## rejoins and the off-road limit, and the run's owner relays the signals to EventBus.
##
## In the tutorial (TUTORIAL_PLAN.md §5.2), a mistake ends no run: it ends the streak of correct
## turns, and the trigger loses the car until it drives on along the path from one path tile to
## the next. A wrong exit, a U-turn on the path, a rejoin off the path and the off-road limit are
## mistakes. Once the streak reaches TUTORIAL_STREAK, the City's rules hold.

## A correct exit: the pattern's turn, or straight on at a decoy, which leaves `turn_index`, the
## number of correct turns so far, as it was (ROADGEN_PLAN.md R2).
signal turn_completed(turn_index: int)
## A wrong exit, whose heading is `choice`, or a missed turn (`choice` -1). The trigger then stops.
signal disaster_triggered(junction: RoadTile, choice: int)
## The tutorial's correct turns in a row are now `streak`: one more, or none after a mistake.
signal streak_changed(streak: int)
## The tutorial's last correct turn was at `junction`. The trigger now plays by the City's rules.
signal tutorial_completed(junction: RoadTile)

## Correct turns so far, after the tutorial.
var turn_index := 0
## The first unresolved junction ahead, or null after a disaster, or in the tutorial while the car
## is lost.
var next_junction: RoadTile
## Whether the tutorial's rules hold: from the start of a tutorial run until its streak is done.
var tutorial := false
## The tutorial's correct turns in a row.
var streak := 0

var _buffer: RoadBuffer


## `buffer` must have started.
func _init(buffer: RoadBuffer) -> void:
	_buffer = buffer
	tutorial = buffer.generator.tutorial
	next_junction = _junction_after(buffer.first_index() - 1)


## The car crossed from `from_cell` into the neighbouring `to_cell`, on the road if `on_road`.
## Leaving the next junction's tile on the road through one of its exits decides that exit; going
## back out of the entry edge decides nothing. Entering a path tile on the road may be a mistake or
## find the lost car in the tutorial, and is a missed turn if it skips the next junction after it.
func on_cell_crossed(from_cell: Vector2i, to_cell: Vector2i, on_road: bool) -> void:
	if not on_road:
		return
	var junction := next_junction
	if junction != null and from_cell == junction.cell:
		var exit := Heading.from_vec(to_cell - from_cell)
		if exit != -1 and exit != Heading.opposite(junction.heading) and junction.has_exit(exit):
			_resolve(exit)
			return
	var to := _buffer.tile_at(to_cell)
	if to == null or to.path_index < 0:
		return
	var from := _buffer.tile_at(from_cell)
	var on_path := from != null and from.path_index >= 0
	if tutorial:
		if not on_path or from.path_index != to.path_index - 1:
			_lose()
		elif next_junction == null:
			next_junction = _junction_after(from.path_index)
	elif not on_path and junction != null:
		# Only a tutorial's loop leads from a branch to a path tile past its own junction, so only
		# the road just after the tutorial can come here (TUTORIAL_PLAN.md §5.5). A car is on the
		# road at a crossing only within a road tile, so `from` is one.
		if to.path_index >= junction.path_index:
			_fail(-1)


## The car came back onto the road on `tile`. A dead end of the next junction decides that wrong
## exit. A correct-path tile past the junction, or a later junction's dead end, decides the correct
## exit, and is then checked against the following junction. Anything else decides nothing. In the
## tutorial, a rejoin off the path is a mistake, and one while the car is lost decides nothing.
func on_rejoin(tile: RoadTile) -> void:
	if tutorial and next_junction != null and tile.path_index < 0:
		_lose()
	while next_junction != null:
		var index := next_junction.path_index
		if tile.junction_index == index:
			_resolve(tile.branch_exit)
			return
		if tile.path_index <= index and tile.junction_index < index:
			return
		_resolve(next_junction.expected_exit)


## The car reached the off-road limit: after leaving the road near the next junction, or anywhere
## in the tutorial.
func on_offroad_limit() -> void:
	if tutorial:
		_lose()
	elif next_junction != null:
		_fail(-1)


## The car was put back on path tile `tile` in the tutorial: the streak starts again, from the next
## junction after it.
func on_rescued(tile: RoadTile) -> void:
	_lose()
	next_junction = _junction_after(tile.path_index)


func _resolve(choice: int) -> void:
	var junction := next_junction
	if choice != junction.expected_exit:
		if tutorial:
			_lose()
		else:
			_fail(choice)
		return
	next_junction = _junction_after(junction.path_index)
	if tutorial:
		streak += 1
		streak_changed.emit(streak)
		if streak >= Tuning.TUTORIAL_STREAK:
			tutorial = false
			tutorial_completed.emit(junction)
		return
	if junction.is_turn():
		turn_index += 1
	turn_completed.emit(turn_index)


## A mistake in the tutorial: the streak ends, and the car is lost until it drives on along the
## path.
func _lose() -> void:
	next_junction = null
	if streak != 0:
		streak = 0
		streak_changed.emit(streak)


func _fail(choice: int) -> void:
	var junction := next_junction
	next_junction = null
	disaster_triggered.emit(junction, choice)


## The first junction after path index `index`. The buffer always has one: junctions are at most
## a set piece and a straight apart, which AreaSchedule.validate() keeps within BUFFER_REFILL_AT.
func _junction_after(index: int) -> RoadTile:
	for i: int in range(maxi(index + 1, _buffer.first_index()), _buffer.last_index() + 1):
		var tile := _buffer.path_tile(i)
		if tile.is_junction():
			return tile
	push_error("JunctionTrigger: no junction after path index %d" % index)
	return null
