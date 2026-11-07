extends Node
## The game, the main scene (IMPLEMENTATION_PLAN.md M2): drive along the generated road and take
## the right exit at every junction. It builds the run from its seed, relays the road's and the
## car's signals to EventBus and GameState, and reloads itself for the next run. User arguments
## (after "--"): --seed=<int> picks the road (D8); --autopilot drives by itself (the CI smoke run).

const CAR_SCENE := preload("res://car/car.tscn")

## The user arguments. Tests set them before adding the scene to the tree.
var args := OS.get_cmdline_user_args()

var _autopilot := false
var _buffer: RoadBuffer
var _sim: CarSim
var _car: CarController

@onready var _world: WorldRenderer = %World
@onready var _input: InputRouter = %InputRouter
@onready var _camera: CameraRig = %Camera
@onready var _hud: Hud = %HUD


func _ready() -> void:
	_autopilot = args.has("--autopilot")
	var run_seed := _parse_seed(args)
	var schedule: AreaSchedule = load("res://areas/schedule.tres")
	_buffer = RoadBuffer.new(RoadGenerator.new(run_seed, schedule))
	_buffer.tiles_generated.connect(EventBus.tiles_generated.emit)
	_buffer.tiles_freed.connect(EventBus.tiles_freed.emit)
	var start := Time.get_ticks_usec()
	_world.bind(_buffer, schedule)
	# Read on devices (browser console, adb logcat): the grey-box atlas is drawn at run time.
	print("grey box: tilesets built in %d ms" % ((Time.get_ticks_usec() - start) / 1000))
	_buffer.start()
	_sim = CarSim.new(_buffer)
	_sim.trigger.turn_completed.connect(_on_turn_completed)
	_sim.trigger.disaster_triggered.connect(_on_disaster_triggered)
	_sim.crashed.connect(_end_run)
	_sim.health_changed.connect(EventBus.health_changed.emit)
	_sim.offroad_changed.connect(EventBus.car_offroad_changed.emit)
	_sim.area_changed.connect(_on_area_changed)
	if _autopilot:
		_input.autopilot = Autopilot.new(_sim)
	_car = CAR_SCENE.instantiate() as CarController
	_car.sim = _sim
	_car.input = _input
	_world.get_node("%Props").add_child(_car)
	_camera.car = _car
	_camera.snap_to_target()
	_hud.retry_requested.connect(get_tree().reload_current_scene)
	GameState.start_run(run_seed)
	GameState.area_id = _sim.area.id


func _exit_tree() -> void:
	if _autopilot:
		# tools/ci/smoke.sh requires this line with a tile above 0 (M1_PLAN.md G17).
		var tile := _buffer.path_tile(_buffer.car_index())
		print(
			(
				"autopilot: tile %d, turns %d, area %s"
				% [tile.path_index, GameState.turn_index, tile.area_id]
			)
		)
	GameState.quit_to_title()


func _physics_process(_delta: float) -> void:
	if GameState.state == GameState.State.RUNNING:
		GameState.distance = maxf(GameState.distance, _sim.progress)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and GameState.state == GameState.State.RUNNING:
		GameState.pause()


func _on_turn_completed(turn_index: int) -> void:
	GameState.turn_index = turn_index
	EventBus.turn_completed.emit(turn_index)


func _on_disaster_triggered(junction: RoadTile, choice: int) -> void:
	EventBus.disaster_triggered.emit(_buffer.generator.find_area(junction.area_id), junction)
	_end_run(CarSim.MISSED_TURN if choice == -1 else CarSim.WRONG_TURN)


func _on_area_changed(area: AreaDef) -> void:
	GameState.area_id = area.id
	EventBus.area_changed.emit(area)


## Until M3 adds the disaster and crash sequences, the game is over at once.
func _end_run(cause: StringName) -> void:
	GameState.distance = maxf(GameState.distance, _sim.progress)
	_input.enabled = false
	GameState.end_run(cause)
	GameState.show_game_over()
	if _autopilot:
		push_error("main: the autopilot's run ended: %s" % cause)


static func _parse_seed(p_args: PackedStringArray) -> int:
	for arg: String in p_args:
		if arg.begins_with("--seed="):
			return arg.trim_prefix("--seed=").to_int()
	return RandomNumberGenerator.new().randi()
