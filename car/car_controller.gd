class_name CarController
extends Node2D
## Steps a CarSim every physics frame with the InputRouter's steering, and draws it
## (IMPLEMENTATION_PLAN.md M2.4). The grey box is an arrow in one of 16 directions, with a hue per
## direction, and dust while the car is off the road. After a crash the arrow turns grey, its crash
## frame, and smokes (M3.3). It lives under World/Props, which y-sorts it. It sets its position
## every frame, so a disaster may change only its scale and modulate (M3_PLAN.md J3).

## Sprite frames: the screen directions the car can face, clockwise from straight up.
const FRAMES := 16

var sim: CarSim
var input: InputRouter

@onready var _arrow: Polygon2D = %Arrow
@onready var _dust: CPUParticles2D = %Dust
@onready var _smoke: CPUParticles2D = %Smoke


func _ready() -> void:
	_update_view()


func _physics_process(delta: float) -> void:
	sim.step(delta, input.steer())
	_update_view()


## The frame for heading `forward`, in tile space: the nearest of FRAMES screen directions.
static func frame(forward: Vector2) -> int:
	var screen := Iso.tile_to_world(forward)
	return posmod(roundi(atan2(screen.x, -screen.y) / (TAU / FRAMES)), FRAMES)


func _update_view() -> void:
	position = Iso.tile_to_world(sim.pos)
	var f := frame(sim.forward())
	_arrow.rotation = f * TAU / FRAMES
	var crashed := sim.state == CarSim.State.CRASHED
	# Not the polygon's color: setting that redraws the Polygon2D, and on the Web every redraw after
	# the first raises WebGL errors (godotengine/godot#124726, fixed in 4.8).
	_arrow.self_modulate = (
		Tuning.CRASH_TINT if crashed else Color.from_hsv(float(f) / FRAMES, 0.6, 1.0)
	)
	_dust.emitting = sim.state == CarSim.State.OFFROAD
	_smoke.emitting = crashed
