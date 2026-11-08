@abstract class_name DisasterBase
extends Node2D
## A disaster (plan.md §4.3, IMPLEMENTATION_PLAN.md M3.1): a scene whose root extends this class.
## The DisasterDirector adds it to World's DisasterLayer once the car has stopped, sets car and
## camera, and calls play() once. It must then emit finished, once: 2 to 4 s after the wrong or
## missed turn, counting the car's stop and the delay in its params. The director ends the
## sequence anyway DISASTER_TIMEOUT after the turn. Its time must come from _physics_process: no
## Tween or timer moves in GUT's simulate() (M3_PLAN.md J2).

signal finished

## What the disaster collection will record it as (plan.md §9), such as &"sinkhole".
@export var id := &""

## The stopped car. A disaster may change its scale and modulate, but not its position, which
## CarController sets every physics frame (J3).
var car: CarController
var camera: CameraRig

@abstract func play(params: DisasterParams) -> void
