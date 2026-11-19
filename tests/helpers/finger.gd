extends RefCounted
## A finger on a touch screen, for the tests of a screen that a drag scrolls (ENDGAME_PLAN.md W28,
## W33). No class_name: tests/ is not exported.


## A finger that touches the middle of `control`, moves by each of `moves` and lifts, all in one
## frame. Android sends each touch and move as Input's emulated mouse event first, then as itself.
static func drag(control: Control, moves: Array[Vector2]) -> void:
	var view := control.get_viewport()
	var at := control.get_global_rect().get_center()
	view.push_input(_mouse_button(at, true), true)
	view.push_input(_touch(at, true), true)
	for move: Vector2 in moves:
		at += move
		var motion := InputEventMouseMotion.new()
		motion.device = InputEvent.DEVICE_ID_EMULATION
		motion.position = at
		motion.global_position = at
		motion.relative = move
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		view.push_input(motion, true)
		var drag_event := InputEventScreenDrag.new()
		drag_event.position = at
		drag_event.relative = move
		view.push_input(drag_event, true)
	view.push_input(_mouse_button(at, false), true)
	view.push_input(_touch(at, false), true)


static func _mouse_button(at: Vector2, pressed: bool) -> InputEventMouseButton:
	var button := InputEventMouseButton.new()
	button.device = InputEvent.DEVICE_ID_EMULATION
	button.button_index = MOUSE_BUTTON_LEFT
	button.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	button.pressed = pressed
	button.position = at
	button.global_position = at
	return button


static func _touch(at: Vector2, pressed: bool) -> InputEventScreenTouch:
	var touch := InputEventScreenTouch.new()
	touch.pressed = pressed
	touch.position = at
	return touch
