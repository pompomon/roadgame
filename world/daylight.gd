class_name Daylight
extends ViewVeil
## The light of the zone's hour (docs/DAYNIGHT.md §5.5): a veil over the view that multiplies the
## world by the light that its clock shows. The legends' glows draw above it, and the UI on its own
## layer, so they stay as bright. By day the light is white and the veil hidden, so the frame is the
## same as before the day had hours. main.gd runs the clock: it starts it again in each zone, and
## stops it with the run.

## The zone's clock, and the light shown.
var cycle := DayCycle.new()
## The camera whose view the veil covers. main.gd sets it.
var camera: Camera2D


func _ready() -> void:
	process_physics_priority = PHYSICS_PRIORITY


func _physics_process(_delta: float) -> void:
	refresh()


## Covers the camera's view with the clock's light, at once.
func refresh() -> void:
	if camera != null:
		follow(camera)
	shade(cycle.light)
