extends Node
## The game, the main scene (IMPLEMENTATION_PLAN.md M2, M3): drive along the generated road and take
## the right exit at every junction. It starts on the title screen (M5.5), and Play builds a run
## from its seed and relays the road's and the car's signals to EventBus and GameState. When the run
## ends, the DisasterDirector plays its end, and then the game-over screen shows; Retry builds the
## next run in place, without reloading the scene (M3.3), and Title goes back to the title screen.
## User arguments (after "--"): --play starts a run at once, without the title screen;
## --seed=<int> picks the road (D8); --autopilot drives by itself (the CI smoke run), and implies
## --play; --area=<id> starts every run in that area, for tests and manual checks (M4_PLAN.md K10).
## --hour=<h> starts every zone's clock at hour h instead of the morning (DAYNIGHT_PLAN.md §5.9).
## A phone can't take them (M4_PLAN.md P4), so in debug builds the title's Start button chooses the
## area that Play starts in instead, which --area presets (ZONE_SELECT_PLAN.md Z1, Z6). --tutorial
## starts every run that starts in the City with the tutorial, which otherwise only Play starts,
## until the player has finished it (TUTORIAL_PLAN.md §5.6).

## Android's back button on the title screen. _ready() connects it to quitting the game.
signal quit_requested

const CAR_SCENE := preload("res://car/car.tscn")

## The user arguments. Tests set them before adding the scene to the tree.
var args := OS.get_cmdline_user_args()

var _autopilot := false
## The game's schedule. The world, the Atlas and the collection show all of its areas.
var _whole_schedule: AreaSchedule
## The run's: the game's, or a copy that starts in --area's area or the title's choice.
var _schedule: AreaSchedule
## In a run with the tutorial, where the City's run began (TUTORIAL_PLAN.md §5.5): the path distance
## where the car left the tutorial's last junction, and the turns before the next junction. The
## run's distance and turns count from there. 0 in a run without the tutorial.
var _origin := 0.0
var _turn_base := 0
var _buffer: RoadBuffer
var _sim: CarSim
var _car: CarController
## What the disaster that ended the run did to the car, for the game-over screen (M6_PLAN.md S8).
var _fate := ""

@onready var _world: WorldRenderer = %World
@onready var _input: InputRouter = %InputRouter
@onready var _camera: CameraRig = %Camera
@onready var _daylight: Daylight = %Daylight
@onready var _director: DisasterDirector = %Director
@onready var _game_over: GameOver = %GameOver
@onready var _hud: Hud = %HUD
@onready var _title: TitleScreen = %Title


func _ready() -> void:
	_autopilot = args.has("--autopilot")
	_whole_schedule = load("res://areas/schedule.tres")
	_schedule = _whole_schedule
	var area := _parse_area(args)
	if area != &"":
		_schedule = _whole_schedule.starting_at(area)
	var start := Time.get_ticks_usec()
	# Every area's, whichever a run starts in (ZONE_SELECT_PLAN.md Z2).
	_world.build(_whole_schedule)
	_world.cycle = _daylight.cycle
	# Read on devices (browser console, adb logcat): the grey-box atlas is drawn at run time.
	print("grey box: tilesets built in %d ms" % ((Time.get_ticks_usec() - start) / 1000))
	_director.layer = _world.get_node("%DisasterLayer")
	_director.stage = _world.get_node("%Props")
	_daylight.camera = _camera
	_daylight.cycle.start_hour = _parse_hour(args)
	_director.sequence_finished.connect(_on_sequence_finished)
	_director.disaster_started.connect(_on_disaster_started)
	_director.disaster_appeared.connect(_on_disaster_appeared)
	_game_over.retry_requested.connect(_retry)
	_game_over.title_requested.connect(_to_title)
	# The Atlas and the collection show the whole schedule, also with --area.
	_title.schedule = _whole_schedule
	_title.start_area = _schedule.areas()[0]
	_title.play_requested.connect(_play)
	quit_requested.connect(get_tree().quit)
	if _autopilot or args.has("--play"):
		_start_run(_parse_seed(args))
	else:
		_show_title()


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
	AudioDirector.follow(null)
	GameState.quit_to_title()


func _physics_process(delta: float) -> void:
	if GameState.state == GameState.State.RUNNING:
		if not GameState.in_tutorial:
			GameState.distance = maxf(GameState.distance, _sim.progress - _origin)
		# The zone's clock runs with the run, the tutorial's too, and stops when it ends or pauses
		# (DAYNIGHT_PLAN.md §5.4). Daylight shows the light after the camera has moved.
		_daylight.cycle.advance(delta)


func _notification(what: int) -> void:
	# The Web sends only the window one, when the canvas loses focus.
	var focus_out := what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT]
	if focus_out and GameState.state == GameState.State.RUNNING:
		GameState.pause()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		go_back()


## Android's back button (M5_PLAN.md L13): it leaves a screen of the title for the title, and
## quits from the title itself. It pauses a running game, and leaves game over for the title. While
## the game is paused, and while the disaster or the crash plays, it does nothing. project.godot
## turns off quit_on_go_back, which would quit from every screen.
func go_back() -> void:
	match GameState.state:
		GameState.State.TITLE:
			if not _title.go_back():
				quit_requested.emit()
		GameState.State.RUNNING:
			GameState.pause()
		GameState.State.GAME_OVER:
			_to_title()


## Builds a run: a road from `run_seed`, a car on it, and a fresh start for the world, the input,
## the camera, the director and GameState. The first run and every retry come through here.
func _start_run(run_seed: int) -> void:
	var tutorial := _tutorial_wanted()
	_origin = 0.0
	_turn_base = 0
	_buffer = RoadBuffer.new(RoadGenerator.new(run_seed, _schedule, tutorial))
	_buffer.tiles_generated.connect(EventBus.tiles_generated.emit)
	_buffer.tiles_freed.connect(EventBus.tiles_freed.emit)
	_world.bind(_buffer)
	_buffer.start()
	_sim = CarSim.new(_buffer)
	_sim.trigger.turn_completed.connect(_on_turn_completed)
	_sim.trigger.disaster_triggered.connect(_on_disaster_triggered)
	_sim.trigger.streak_changed.connect(EventBus.streak_changed.emit)
	_sim.trigger.tutorial_completed.connect(_on_tutorial_completed)
	_sim.crashed.connect(_on_crashed)
	_sim.health_changed.connect(EventBus.health_changed.emit)
	_sim.offroad_changed.connect(EventBus.car_offroad_changed.emit)
	_sim.area_changed.connect(_on_area_changed)
	_input.autopilot = Autopilot.new(_sim) if _autopilot else null
	_input.enabled = true
	_hud.show()
	_car = CAR_SCENE.instantiate() as CarController
	_car.sim = _sim
	_car.input = _input
	_world.get_node("%Props").add_child(_car)
	_camera.car = _car
	_camera.snap_to_target()
	# Deferred: the car's node moves to the rescued car after the step that rescued it.
	_sim.rescued.connect(_camera.snap_to_target, CONNECT_DEFERRED)
	_world.car = _car
	AudioDirector.follow(_sim)
	_director.start_run(run_seed)
	GameState.start_run(run_seed, tutorial)
	# Every run starts in an area too: the HUD names it, and M5's music starts with it (M4.3).
	_on_area_changed(_sim.area)
	# A new run is a cut: it shows the morning, or --hour's light, at once (DAYNIGHT_PLAN.md §5.4).
	_daylight.cycle.snap()
	_daylight.refresh()


## Retry on the game-over screen: the next run, on the same nodes. A forced --seed stays; otherwise
## the run gets a new random seed (M2_PLAN.md H28).
func _retry() -> void:
	if GameState.state != GameState.State.GAME_OVER:
		push_error("main: a retry is only allowed after game over")
		return
	_clear_run()
	_start_run(_parse_seed(args))


## Title on the game-over screen. The last run's road stays behind the title screen until the next
## run replaces it.
func _to_title() -> void:
	if GameState.state != GameState.State.GAME_OVER:
		push_error("main: the title screen is only reachable from game over")
		return
	_clear_run()
	GameState.quit_to_title()
	_show_title()


## Play on the title screen: a run, as with --play. With the title's choice of area, it starts in
## that area, as --area would start it, and so do its retries (ZONE_SELECT_PLAN.md Z6).
func _play() -> void:
	if GameState.state != GameState.State.TITLE:
		push_error("main: Play is only allowed on the title screen")
		return
	_title.close()
	if _title.area_choice:
		_schedule = _whole_schedule.starting_at(_title.start_area.id)
	_start_run(_parse_seed(args))


func _show_title() -> void:
	_hud.hide()
	_input.enabled = false
	_title.open()


## Frees the last run's car and disaster at once, not queued, so that no frame shows two cars
## (M3_PLAN.md J13).
func _clear_run() -> void:
	_game_over.close()
	_director.clear()
	_camera.stop_shake()
	_camera.car = null
	_world.car = null
	_car.free()
	_car = null
	_fate = ""


func _on_turn_completed(turn_index: int) -> void:
	GameState.turn_index = turn_index
	EventBus.turn_completed.emit(turn_index)


func _on_disaster_triggered(junction: RoadTile, choice: int) -> void:
	var area := _buffer.generator.find_area(junction.area_id)
	EventBus.disaster_triggered.emit(area, junction)
	_end_run(CarSim.MISSED_TURN if choice == -1 else CarSim.WRONG_TURN)
	_director.play_disaster(area, _car, _camera, _daylight.cycle.light)


func _on_crashed(cause: StringName) -> void:
	_end_run(cause)
	_director.play_crash(_car, _camera)


## The car reached `area`. GameState counts the area's distance and turns from its first tile, which
## the car may have passed, off the road. In the step that reaches it, CarSim reports the area
## before the trigger judges the turn behind it (M5_PLAN.md L8). After a tutorial, both count from
## where the City's run began.
func _on_area_changed(area: AreaDef) -> void:
	var first := _buffer.car_index()
	while first > _buffer.first_index() and _buffer.path_tile(first - 1).area_id == area.id:
		first -= 1
	# A run starts at the centre of its first tile, at distance 0.
	var start := maxf(first - 0.5 - _origin, 0.0)
	GameState.enter_area(area.id, start, _turns_before(first) - _turn_base)
	# Each zone starts its clock again, at its own pace (DAYNIGHT_PLAN.md §5.4).
	_daylight.cycle.enter(area.day_seconds)
	EventBus.area_changed.emit(area)


## The tutorial's streak is done at `junction` (TUTORIAL_PLAN.md §5.5): the run goes on in the City,
## under its rules, from where the car left the junction, and the tutorial is done for good. The
## road ahead is still the tutorial's, to the end of its group of four junctions. The City's entry
## in GameState, from the run's start, is at distance 0 and turn 0, which the tutorial never passed:
## it counts from here.
func _on_tutorial_completed(junction: RoadTile) -> void:
	_origin = junction.path_index + 0.5
	_turn_base = junction.turn_number + 1
	_buffer.generator.end_tutorial(_turn_base)
	SaveService.complete_tutorial()
	GameState.end_tutorial()
	EventBus.tutorial_completed.emit()
	EventBus.area_changed.emit(_sim.area)


## The turns before path index `index`: the turn number of the first junction from there on, as a
## junction's turn number counts the turns before it, and a decoy is no turn (ROADGEN_PLAN.md R1).
func _turns_before(index: int) -> int:
	for i: int in range(index, _buffer.last_index() + 1):
		var tile := _buffer.path_tile(i)
		if tile.is_junction():
			return tile.turn_number
	# The buffer always holds the next junction (JunctionTrigger._junction_after()).
	push_error("main: no junction after path index %d" % index)
	return GameState.turn_index


func _on_disaster_appeared(disaster: DisasterBase, area: AreaDef) -> void:
	EventBus.disaster_appeared.emit(disaster.id, area)


func _on_disaster_started(disaster: DisasterBase, area: AreaDef) -> void:
	EventBus.disaster_started.emit(disaster.id, area)
	_fate = disaster.fate


## The run is over the moment it ends (M3_PLAN.md J1): the input stops, and GameState reports the
## cause and the stats. The director then plays the disaster or the crash.
func _end_run(cause: StringName) -> void:
	GameState.distance = maxf(GameState.distance, _sim.progress - _origin)
	_input.enabled = false
	GameState.end_run(cause)
	if _autopilot:
		push_error("main: the autopilot's run ended: %s" % cause)


## The disaster or the crash has played: game over.
func _on_sequence_finished() -> void:
	GameState.show_game_over()
	_game_over.open(GameState.stats(), _buffer.generator.find_area(GameState.area_id), _fate)


## Whether the next run starts with the tutorial (TUTORIAL_PLAN.md §5.6): only one that starts in
## the City, the whole schedule's first area, also when --area or the title's Start button chooses
## it. --tutorial asks for it. Otherwise Play does, until the player has finished it, but not --play
## or --autopilot, which tests and checks use.
func _tutorial_wanted() -> bool:
	if _schedule.entries[0].area != _whole_schedule.entries[0].area:
		return false
	if args.has("--tutorial"):
		return true
	if _autopilot or args.has("--play"):
		return false
	return not SaveService.data().tutorial["done"]


static func _parse_seed(p_args: PackedStringArray) -> int:
	for arg: String in p_args:
		if arg.begins_with("--seed="):
			return arg.trim_prefix("--seed=").to_int()
	return RandomNumberGenerator.new().randi()


static func _parse_area(p_args: PackedStringArray) -> StringName:
	for arg: String in p_args:
		if arg.begins_with("--area="):
			var id := arg.trim_prefix("--area=")
			if id.is_empty():
				push_error("main: --area= needs the id of an area")
			return StringName(id)
	return &""


## The hour of --hour=<h> in `p_args`, round the clock, which every zone's clock starts at
## (DAYNIGHT_PLAN.md §5.9). Tuning.DAY_START_HOUR without it, or with an h that isn't a number.
static func _parse_hour(p_args: PackedStringArray) -> float:
	for arg: String in p_args:
		if arg.begins_with("--hour="):
			var text := arg.trim_prefix("--hour=")
			if text.is_valid_float() and is_finite(text.to_float()):
				return fposmod(text.to_float(), 24.0)
			push_error("main: --hour= needs an hour, such as --hour=20.5")
	return Tuning.DAY_START_HOUR
