@abstract class_name DisasterBase
extends Node2D
## A disaster (plan.md §4.3, IMPLEMENTATION_PLAN.md M3.1): a scene whose root extends this class.
## The DisasterDirector adds it to World's DisasterLayer once the car has stopped, sets car and
## camera, and calls play() once. It must then emit finished, once: 2 to 4 s after the wrong or
## missed turn, counting the car's stop and the delay in its params. The director ends the
## sequence anyway DISASTER_TIMEOUT after the turn. Its time must come from _physics_process: no
## Tween or timer moves in GUT's simulate() (M3_PLAN.md J2). Its script has a
## `static func duration(params: DisasterParams) -> float`, the seconds from play() to finished,
## which tests/unit/test_disasters.gd checks for every disaster in a pool (M4_PLAN.md K20).

# Emitted by the disasters, so the editor would warn that this class never uses it.
@warning_ignore("unused_signal")
signal finished

## Points on an outline().
const OUTLINE_POINTS := 32

## What the disaster collection will record it as (plan.md §9), such as &"sinkhole".
@export var id := &""
## What the disaster collection calls it, such as "Sinkhole" (M5.5).
@export var display_name := ""
## What the game-over screen says it did to the car, such as "The ground opened under you.", in at
## most 40 characters (M6_PLAN.md S8).
@export var fate := ""
## A line of its lore, which the collection shows on its card once it's seen, in at most 80
## characters (M6_PLAN.md S12).
@export_multiline var lore := ""

## The stopped car. A disaster may change its scale, modulate and rotation, but not its position,
## which CarController sets every physics frame (J3, M4_PLAN.md K19).
var car: CarController
var camera: CameraRig
## Where a legend stands its parts, so that they sort with the props and the car: World's Props
## (M6_PLAN.md S2). Null in tests that need no stage.
var stage: Node2D

@abstract func play(params: DisasterParams) -> void


## Seeds `particles` from `params`, as Godot gives each CPUParticles2D a random seed when it's made
## (M3_PLAN.md J16), and scales their speed by the intensity and their size by particle_scale.
static func apply_params(particles: CPUParticles2D, params: DisasterParams) -> void:
	particles.use_fixed_seed = true
	particles.seed = params.particle_seed
	particles.initial_velocity_min *= params.intensity
	particles.initial_velocity_max *= params.intensity
	particles.scale_amount_min *= params.particle_scale
	particles.scale_amount_max *= params.particle_scale


## The ellipse that a circle of `radius` tiles around the origin makes on screen, in world pixels.
static func outline(radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i: int in OUTLINE_POINTS:
		points.append(Iso.tile_to_world(Vector2.from_angle(TAU * i / OUTLINE_POINTS) * radius))
	return points
