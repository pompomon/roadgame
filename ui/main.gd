extends Node
## M1 road viewer, the main scene until M2: the camera follows the correct path through the
## generated road. Hold the up arrow, the mouse button or a touch to fast-forward. User
## arguments (after "--"):
## --seed=<int> picks the road (D8); --autopilot always fast-forwards (the CI smoke run).

## Viewer speeds, in tiles per second.
const SPEED := 3.0
const FAST_SPEED := 24.0

var _buffer: RoadBuffer
var _distance := 0.0
var _seed := 0
var _turns := 0
var _always_fast := false
var _mouse_held := false
## Indices of the touches that are down.
var _touches: Dictionary[int, bool] = {}

@onready var _world: WorldRenderer = %World
@onready var _camera: Camera2D = %Camera
@onready var _ghost: Node2D = %Ghost
@onready var _label: Label = %Label


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	_always_fast = args.has("--autopilot")
	_seed = _parse_seed(args)
	var schedule: AreaSchedule = load("res://areas/schedule.tres")
	_buffer = RoadBuffer.new(RoadGenerator.new(_seed, schedule))
	_world.show_dead_ends = true
	var start := Time.get_ticks_usec()
	_world.bind(_buffer, schedule)
	# Read on devices (browser console, adb logcat): the grey-box atlas is drawn at run time.
	print("grey box: tilesets built in %d ms" % ((Time.get_ticks_usec() - start) / 1000))
	_buffer.start()
	_update_view()


func _exit_tree() -> void:
	if _always_fast:
		# tools/ci/smoke.sh requires this line with a tile above 0: the viewer drove the buffer.
		var tile := _buffer.path_tile(_buffer.car_index())
		print("autopilot: tile %d, turns %d, area %s" % [tile.path_index, _turns, tile.area_id])


func _unhandled_input(event: InputEvent) -> void:
	var touch := event as InputEventScreenTouch
	if touch != null:
		if touch.pressed:
			_touches[touch.index] = true
		else:
			_touches.erase(touch.index)
	var click := event as InputEventMouseButton
	if click != null and click.button_index == MOUSE_BUTTON_LEFT:
		_mouse_held = click.pressed


func _physics_process(delta: float) -> void:
	_distance += (FAST_SPEED if is_fast_forwarding() else SPEED) * delta
	_buffer.on_car_path_index(roundi(_distance))
	_update_view()


## True with --autopilot, or while the up arrow, the left mouse button or any touch is held.
func is_fast_forwarding() -> bool:
	return (
		_always_fast or _mouse_held or not _touches.is_empty() or Input.is_action_pressed("ui_up")
	)


func _update_view() -> void:
	_ghost.position = Iso.tile_to_world(_buffer.centreline_point(_distance))
	_camera.position = _ghost.position
	var tile := _buffer.path_tile(roundi(_distance))
	if tile.is_junction():
		_turns = maxi(_turns, tile.turn_number + 1)
	var version: String = ProjectSettings.get_setting("application/config/version", "dev")
	_label.text = (
		(
			"Road Roguelike %s\nseed %d\ntile %d  turns %d  %s\nlookahead %d\n"
			+ "hold up arrow, click or touch: faster"
		)
		% [version, _seed, tile.path_index, _turns, tile.area_id, _buffer.lookahead()]
	)


static func _parse_seed(args: PackedStringArray) -> int:
	for arg: String in args:
		if arg.begins_with("--seed="):
			return arg.trim_prefix("--seed=").to_int()
	return RandomNumberGenerator.new().randi()
