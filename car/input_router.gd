class_name InputRouter
extends Node
## Steering intent from -1 (left) to 1 (right) (IMPLEMENTATION_PLAN.md M2.1), from the steer_left
## and steer_right actions, from touches, or from an Autopilot. Of the inputs held, the last one
## pressed wins. A touch steers by the half of the screen where it started, until it lifts. Touches
## on the HUD's buttons never get here, because a Button consumes them. With no touchscreen, a left
## click is a touch too (project.godot turns on emulate_touch_from_mouse). It processes while the
## game is paused, so that a release during the pause is not missed.

## The steering of each action.
const ACTIONS: Dictionary[String, float] = {"steer_left": -1.0, "steer_right": 1.0}

## When set, it steers instead of the player: the tests and `-- --autopilot`.
var autopilot: Autopilot
## While false, steer() is 0 and input is ignored. The end of the run turns it off.
var enabled := true:
	set(value):
		enabled = value
		_held.clear()

## The held inputs, oldest first, and the steering of each.
var _held: Dictionary[String, float] = {}


func steer() -> float:
	if not enabled:
		return 0.0
	if autopilot != null:
		return autopilot.steer()
	if _held.is_empty():
		return 0.0
	var last: float = _held.values().back()
	return last


func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	var touch := event as InputEventScreenTouch
	if touch != null:
		var key := "touch %d" % touch.index
		if touch.pressed:
			var middle := get_viewport().get_visible_rect().get_center().x
			_press(key, -1.0 if touch.position.x < middle else 1.0)
		else:
			_held.erase(key)
		return
	for action: String in ACTIONS:
		if event.is_action_pressed(action):
			_press(action, ACTIONS[action])
		elif event.is_action_released(action):
			_held.erase(action)


func _notification(what: int) -> void:
	# Releases that happen while the window is out of focus never arrive.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_held.clear()


func _press(key: String, value: float) -> void:
	# Erase first, so that the key moves to the end.
	_held.erase(key)
	_held[key] = value
