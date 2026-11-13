extends Autopilot
## Drives like the autopilot, but takes the wrong exit at each junction whose turn number is in
## `wrong_at`, and follows the road from there: in the tutorial, round the loop and back onto the
## path, through the junction where the loop comes back (TUTORIAL_PLAN.md §5.7). No class_name:
## tests/ is not exported.

const WrongTurnPilot := preload("res://tests/helpers/wrong_turn_pilot.gd")

## The turn numbers of the junctions where it goes wrong. Each goes once the car has gone wrong
## there: a loop can bring the car back to the junction before.
var wrong_at: Array[int] = []
## The cell centres the car follows off the path: from the path tile before the junction, round
## the loop, to the path tile after the junction it comes back to. Empty while it follows the path.
var _route: Array[Vector2] = []
## The route's segment the car is on.
var _segment := 0
## The path index of the route's last tile.
var _end_index := -1


func steer() -> float:
	if _route.is_empty():
		_plan()
	elif _sim.path_tile.path_index == _end_index:
		_route.clear()
	if _route.is_empty():
		return super()
	return _towards(_aim())


## Plans the route once the car is within a tile of a junction where it goes wrong.
func _plan() -> void:
	var junction := _sim.trigger.next_junction
	if junction == null or junction.turn_number not in wrong_at:
		return
	if junction.path_index - _sim.progress > 1.0:
		return
	wrong_at.erase(junction.turn_number)
	var heading := WrongTurnPilot.wrong_exit(junction)
	var cells: Array[Vector2i] = [junction.cell - Heading.VEC[junction.heading], junction.cell]
	var cell := junction.cell + Heading.VEC[heading]
	var tile := _sim.buffer.tile_at(cell)
	while tile != null and tile.path_index < 0:
		cells.append(cell)
		heading = _onward(tile, heading)
		cell += Heading.VEC[heading]
		tile = _sim.buffer.tile_at(cell)
	# Straight through the junction the loop comes back to, out of its correct exit.
	cells.append_array([cell, cell + Heading.VEC[heading]] as Array[Vector2i])
	var last := _sim.buffer.tile_at(cells[-1])
	_end_index = -1 if last == null else last.path_index
	_route.clear()
	for k: int in cells.size():
		_route.append(Iso.cell_centre(cells[k]))
	_segment = 0


## The exit of the loop's `tile` that the car, heading `heading` into it, leaves by.
static func _onward(tile: RoadTile, heading: int) -> int:
	for exit: int in [Heading.left(heading), Heading.right(heading), heading]:
		if tile.has_exit(exit):
			return exit
	return heading


## The point LOOKAHEAD along the route past the car's nearest point on its segment.
func _aim() -> Vector2:
	while _segment < _route.size() - 2 and _along(_segment) >= 1.0:
		_segment += 1
	var at := _route[_segment].lerp(_route[_segment + 1], clampf(_along(_segment), 0.0, 1.0))
	var left := LOOKAHEAD
	for k: int in range(_segment + 1, _route.size()):
		var step := at.distance_to(_route[k])
		if step >= left:
			return at.move_toward(_route[k], left)
		left -= step
		at = _route[k]
	return at


## Where the car is along the route's segment `k`: 0 at its start, 1 at its end.
func _along(k: int) -> float:
	var a := _route[k]
	var b := _route[k + 1]
	return (_sim.pos - a).dot(b - a) / a.distance_squared_to(b)


func _towards(point: Vector2) -> float:
	var aim := point - _sim.pos
	if aim.is_zero_approx():
		return 0.0
	var error := wrapf(atan2(aim.x, -aim.y) - _sim.angle, -PI, PI)
	return clampf(error * GAIN, -1.0, 1.0)
