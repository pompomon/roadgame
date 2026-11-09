extends Autopilot
## Drives like the autopilot, except at the junction with turn number `wrong_at`: past that
## junction's centre it follows a wrong exit instead of the correct one (IMPLEMENTATION_PLAN.md M3
## tests). No class_name: tests/ is not exported.

## The 0-based turn number of the junction where it goes wrong: 2 is the third junction.
var wrong_at := 2


func steer() -> float:
	var junction := _sim.trigger.next_junction
	if junction == null or junction.turn_number != wrong_at:
		return super()
	var ahead := _sim.progress + LOOKAHEAD - junction.path_index
	if ahead <= 0.0:
		return super()
	var exit := wrong_exit(junction)
	var aim := Iso.cell_centre(junction.cell) + Vector2(Heading.VEC[exit]) * ahead - _sim.pos
	var error := wrapf(atan2(aim.x, -aim.y) - _sim.angle, -PI, PI)
	return clampf(error * GAIN, -1.0, 1.0)


## A wrong exit of `junction`: the other side, or straight on.
static func wrong_exit(junction: RoadTile) -> int:
	var heading := junction.heading
	for exit: int in [Heading.left(heading), Heading.right(heading), heading]:
		if junction.has_exit(exit) and exit != junction.expected_exit:
			return exit
	push_error("WrongTurnPilot: junction %d has no wrong exit" % junction.path_index)
	return junction.expected_exit
