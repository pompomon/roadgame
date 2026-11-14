extends RefCounted
## The main scene under test, and input for it as a device sends it, through the viewport, for the
## M3 integration tests. No class_name: tests/ is not exported.

const MAIN_SCENE := preload("res://ui/main.tscn")
const DELTA := 1.0 / 60.0


## The main scene with user arguments `args`, in a portrait SubViewport that `test` frees. With
## `play`, it starts a run at once (--play), without the title screen (M5.5).
static func open(test: GutTest, args: Array[String], play := true) -> Node:
	var view := SubViewport.new()
	view.size = Vector2i(360, 640)
	test.add_child_autofree(view)
	var main: Node = MAIN_SCENE.instantiate()
	main.args = PackedStringArray(args + (["--play"] as Array[String] if play else []))
	view.add_child(main)
	return main


## Steps `main` while GameState is in `state`, for at most `frames` frames. Returns the frames.
static func run_while(test: GutTest, main: Node, state: int, frames: int) -> int:
	for frame: int in frames:
		if GameState.state != state:
			return frame
		test.simulate(main, 1, DELTA)
	return frames


## The run's car, which World's Props layer holds among the props (docs/M5.md L12).
static func car(main: Node) -> CarController:
	return (main.get_node("%World") as WorldRenderer).car as CarController


## The cars on World's Props layer.
static func cars(main: Node) -> Array[CarController]:
	var found: Array[CarController] = []
	for node: Node in main.get_node("%World/%Props").get_children():
		if node is CarController:
			found.append(node)
	return found


static func key(keycode: Key, pressed: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = pressed
	return event


static func touch(at: Vector2, pressed: bool) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.position = at
	event.pressed = pressed
	return event


## A left click as a desktop browser sends it with emulate_touch_from_mouse: an emulated touch
## first, then the mouse button.
static func click(at: Vector2, pressed: bool) -> Array[InputEvent]:
	var emulated := touch(at, pressed)
	emulated.device = InputEvent.DEVICE_ID_EMULATION
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	if pressed:
		mouse.button_mask = MOUSE_BUTTON_MASK_LEFT
	mouse.position = at
	mouse.global_position = at
	mouse.pressed = pressed
	return [emulated, mouse]


static func push(main: Node, events: Array[InputEvent]) -> void:
	for event: InputEvent in events:
		main.get_viewport().push_input(event, true)


## Presses and releases `keycode`.
static func press_key(main: Node, keycode: Key) -> void:
	push(main, [key(keycode, true), key(keycode, false)])
