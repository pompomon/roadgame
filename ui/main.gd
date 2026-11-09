extends Node
## The game, the main scene (IMPLEMENTATION_PLAN.md M2, M3): drive along the generated road and take
## the right exit at every junction. It builds each run from its seed and relays the road's and the
## car's signals to EventBus and GameState. When the run ends, the DisasterDirector plays its end,
## and then the game-over screen shows; Retry builds the next run in place, without reloading the
## scene (M3.3). User arguments (after "--"): --seed=<int> picks the road (D8); --autopilot drives
## by itself (the CI smoke run); --area=<id> starts every run in that area, for tests and manual
## checks (M4_PLAN.md K10).

const CAR_SCENE := preload("res://car/car.tscn")

## The user arguments. Tests set them before adding the scene to the tree.
var args := OS.get_cmdline_user_args()

var _autopilot := false
var _schedule: AreaSchedule
var _buffer: RoadBuffer
var _sim: CarSim
var _car: CarController

@onready var _world: WorldRenderer = %World
@onready var _input: InputRouter = %InputRouter
@onready var _camera: CameraRig = %Camera
@onready var _director: DisasterDirector = %Director
@onready var _game_over: GameOver = %GameOver


func _ready() -> void:
	_autopilot = args.has("--autopilot")
	_schedule = load("res://areas/schedule.tres")
	var area := _parse_area(args)
	if area != &"":
		_schedule = _schedule.starting_at(area)
	var start := Time.get_ticks_usec()
	_world.build(_schedule)
	# Read on devices (browser console, adb logcat): the grey-box atlas is drawn at run time.
	print("grey box: tilesets built in %d ms" % ((Time.get_ticks_usec() - start) / 1000))
	_director.layer = _world.get_node("%DisasterLayer")
	_director.sequence_finished.connect(_on_sequence_finished)
	_game_over.retry_requested.connect(_retry)
	_start_run(_parse_seed(args))


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
	# The Web sends only the window one, when the canvas loses focus.
	var focus_out := what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT]
	if focus_out and GameState.state == GameState.State.RUNNING:
		GameState.pause()


## Builds a run: a road from `run_seed`, a car on it, and a fresh start for the world, the input,
## the camera, the director and GameState. The first run and every retry come through here.
func _start_run(run_seed: int) -> void:
	_buffer = RoadBuffer.new(RoadGenerator.new(run_seed, _schedule))
	_buffer.tiles_generated.connect(EventBus.tiles_generated.emit)
	_buffer.tiles_freed.connect(EventBus.tiles_freed.emit)
	_world.bind(_buffer)
	_buffer.start()
	_sim = CarSim.new(_buffer)
	_sim.trigger.turn_completed.connect(_on_turn_completed)
	_sim.trigger.disaster_triggered.connect(_on_disaster_triggered)
	_sim.crashed.connect(_on_crashed)
	_sim.health_changed.connect(EventBus.health_changed.emit)
	_sim.offroad_changed.connect(EventBus.car_offroad_changed.emit)
	_sim.area_changed.connect(_on_area_changed)
	_input.autopilot = Autopilot.new(_sim) if _autopilot else null
	_input.enabled = true
	_car = CAR_SCENE.instantiate() as CarController
	_car.sim = _sim
	_car.input = _input
	_world.get_node("%Props").add_child(_car)
	_camera.car = _car
	_camera.snap_to_target()
	_world.car = _car
	_director.start_run(run_seed)
	GameState.start_run(run_seed)
	# Every run starts in an area too: the HUD names it, and M5's music starts with it (M4.3).
	_on_area_changed(_sim.area)


## Retry on the game-over screen: the next run, on the same nodes. The last run's car and disaster
## are freed at once, not queued, so that no frame shows two cars (M3_PLAN.md J13). A forced --seed
## stays; otherwise the run gets a new random seed (M2_PLAN.md H28).
func _retry() -> void:
	if GameState.state != GameState.State.GAME_OVER:
		push_error("main: a retry is only allowed after game over")
		return
	_game_over.close()
	_director.clear()
	_camera.stop_shake()
	_car.free()
	_start_run(_parse_seed(args))


func _on_turn_completed(turn_index: int) -> void:
	GameState.turn_index = turn_index
	EventBus.turn_completed.emit(turn_index)


func _on_disaster_triggered(junction: RoadTile, choice: int) -> void:
	var area := _buffer.generator.find_area(junction.area_id)
	EventBus.disaster_triggered.emit(area, junction)
	_end_run(CarSim.MISSED_TURN if choice == -1 else CarSim.WRONG_TURN)
	_director.play_disaster(area, _car, _camera)


func _on_crashed(cause: StringName) -> void:
	_end_run(cause)
	_director.play_crash(_car, _camera)


func _on_area_changed(area: AreaDef) -> void:
	GameState.area_id = area.id
	EventBus.area_changed.emit(area)


## The run is over the moment it ends (M3_PLAN.md J1): the input stops, and GameState reports the
## cause and the stats. The director then plays the disaster or the crash.
func _end_run(cause: StringName) -> void:
	GameState.distance = maxf(GameState.distance, _sim.progress)
	_input.enabled = false
	GameState.end_run(cause)
	if _autopilot:
		push_error("main: the autopilot's run ended: %s" % cause)


## The disaster or the crash has played: game over.
func _on_sequence_finished() -> void:
	GameState.show_game_over()
	_game_over.open(GameState.stats(), _buffer.generator.find_area(GameState.area_id))


static func _parse_seed(p_args: PackedStringArray) -> int:
	for arg: String in p_args:
		if arg.begins_with("--seed="):
			return arg.trim_prefix("--seed=").to_int()
	return RandomNumberGenerator.new().randi()


static func _parse_area(p_args: PackedStringArray) -> StringName:
	for arg: String in p_args:
		if arg.begins_with("--area="):
			return StringName(arg.trim_prefix("--area="))
	return &""
