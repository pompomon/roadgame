extends DisasterBase
## A disaster that finishes SECONDS after play(), for the director's tests. No class_name: tests/ is
## not exported.

const SECONDS := 1.0

## What play() was given.
var params: DisasterParams
## Seconds since play(), or -1 before it and after the end.
var _time := -1.0


func play(p_params: DisasterParams) -> void:
	params = p_params
	_time = 0.0


func _physics_process(delta: float) -> void:
	if _time < 0.0:
		return
	_time += delta
	if _time >= SECONDS:
		_time = -1.0
		finished.emit()
