class_name Autopilot
extends RefCounted
## Drives a CarSim along the correct-path centreline by pure pursuit: it steers towards the point
## LOOKAHEAD tiles further along the path (IMPLEMENTATION_PLAN.md M2.1). The simulation tests and
## the CI smoke run (`-- --autopilot`) use it.

## How far ahead along the path to aim, in tiles, and the steering per radian of heading error.
const LOOKAHEAD := 0.9
const GAIN := 4.0

var _sim: CarSim


func _init(sim: CarSim) -> void:
	_sim = sim


## Steering intent, -1 (left) to 1 (right).
func steer() -> float:
	var aim := _sim.buffer.centreline_point(_sim.progress + LOOKAHEAD) - _sim.pos
	if aim.is_zero_approx():
		return 0.0
	var error := wrapf(atan2(aim.x, -aim.y) - _sim.angle, -PI, PI)
	return clampf(error * GAIN, -1.0, 1.0)
