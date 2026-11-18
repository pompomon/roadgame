extends Node
## The game, the main scene (IMPLEMENTATION_PLAN.md M2, M3): drive along the generated road and take
## the right exit at every junction. It starts on the title screen (M5.5), and Play builds a run
## from its seed and relays the road's and the car's signals to EventBus and GameState. When the run
## ends, the DisasterDirector plays its end, and then the game-over screen shows; Retry builds the
## next run in place, without reloading the scene (M3.3), and Title goes back to the title screen.
## User arguments (after "--"): --play starts a run at once, without the title screen;
## --seed=<int> picks the road (D8); --autopilot drives by itself (the CI smoke run), and implies
## --play; --area=<id> starts every run in that area, for tests and manual checks (docs/M4.md K10).
## --hour=<h> starts every zone's clock at hour h instead of the morning (docs/DAYNIGHT.md §5.9).
## A phone can't take them (docs/M4.md P4), so the title's Start button chooses the area that Play
## starts in instead, which --area presets: in debug builds any area (docs/ZONE_SELECT.md Z1, Z6),
## and in others the first or one that the player has discovered (ENDGAME_PLAN.md §5.11). --tutorial
## starts every run that starts in the City with the tutorial, which otherwise only Play starts,
## until the player has finished it (docs/TUTORIAL.md §5.6). --finish=<turns> ends the road after
## that many turns, at most its own, with the areas before it, for tests and manual checks of the
## end of the road (ENDGAME_PLAN.md §5.7). --home drives the Road Home, and presets the title's Road
## choice, which offers it after the first arrival at the sea, and Keep Driving's endless road too
## (§5.12, §5.13). --collected=<id> marks each legend of that area's pool seen, in the save in use,
## and --collected=all every pool's, for checks of the Book's seals and of a full Book (§5.7).

## Android's back button on the title screen. _ready() connects it to quitting the game.
signal quit_requested

const CAR_SCENE := preload("res://car/car.tscn")
## The game's road, to the sea, and the Road Home (ENDGAME_PLAN.md §5.12).
const ROAD := "res://areas/schedule.tres"
const HOME_ROAD := "res://areas/schedule_home.tres"
## The finish of --finish's road, on a schedule with none, such as Keep Driving's.
const DEBUG_FINISH := &"pier"

## The user arguments. Tests set them before adding the scene to the tree.
var args := OS.get_cmdline_user_args()

var _autopilot := false
## The game's schedule. The world, the Atlas and the Book show all of its areas, which the Road Home
## shares.
var _whole_schedule: AreaSchedule
## The Road Home's.
var _home_schedule: AreaSchedule
## Keep Driving's: the game's road with no end, where the Desert goes on (ENDGAME_PLAN.md §5.13).
## Its runs count as the game's did before the road had one, and none can arrive.
var _endless_schedule: AreaSchedule
## The road that the runs drive: the game's, or with --home or the title's choice the Road Home, or
## with the title's, Keep Driving's.
var _road: AreaSchedule
## The run's: the road, or a copy that starts in --area's area or the title's choice, or that ends
## after --finish's turns.
var _schedule: AreaSchedule
## --finish's turns, or -1.
var _finish_turns := -1
## In a run with the tutorial, where the City's run began (docs/TUTORIAL.md §5.5): the path distance
## where the car left the tutorial's last junction, and the turns before the next junction. The
## run's distance and turns count from there. 0 in a run without the tutorial.
var _origin := 0.0
var _turn_base := 0
var _buffer: RoadBuffer
var _sim: CarSim
var _car: CarController
## What the disaster that ended the run did to the car, for the game-over screen (docs/M6.md S8), or
## the legend that an arrival unlocked (ENDGAME_PLAN.md §5.5).
var _fate := ""
## The legends collected as the run started, which its picks were made with (docs/POOLS.md V2), and
## those that it met or unlocked that weren't among them: its new legends (ENDGAME_PLAN.md §5.9).
var _collected: Array[StringName] = []
var _new_legends: Array[StringName] = []

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
	_whole_schedule = load(ROAD)
	_home_schedule = load(HOME_ROAD)
	_endless_schedule = _whole_schedule.endless()
	_road = _home_schedule if args.has("--home") else _whole_schedule
	var collected := _parse_collected(args, _whole_schedule)
	if not collected.is_empty():
		SaveService.collect(collected)
	_finish_turns = _parse_finish(args, _road)
	_schedule = _run_schedule(_parse_area(args))
	var start := Time.get_ticks_usec()
	# Every area's, whichever a run starts in (docs/ZONE_SELECT.md Z2).
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
	# The Atlas and the Book show the whole schedule, also with --area or --home.
	_title.schedule = _whole_schedule
	_title.roads = [_whole_schedule, _home_schedule, _endless_schedule]
	_title.road = _road
	_title.start_area = _schedule.areas()[0]
	_title.play_requested.connect(_play)
	quit_requested.connect(get_tree().quit)
	if _autopilot or args.has("--play"):
		_start_run(_parse_seed(args))
	else:
		_show_title()


func _exit_tree() -> void:
	if _autopilot:
		# tools/ci/smoke.sh requires this line with a tile above 0 (docs/M1.md G17).
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
	var running := GameState.state == GameState.State.RUNNING
	if running and not GameState.in_tutorial:
		GameState.distance = maxf(GameState.distance, _sim.progress - _origin)
		# The run's clock, which stops while it pauses (ENDGAME_PLAN.md §5.3).
		GameState.seconds += delta
	# The zone's clock runs with the run, the tutorial's too, and stops when it ends or pauses
	# (docs/DAYNIGHT.md §5.4). On an arrival it stands at the sunset, and the light goes on toward
	# it (ENDGAME_PLAN.md §5.8). Daylight shows the light after the camera has moved.
	if running or GameState.state == GameState.State.ARRIVED:
		_daylight.cycle.advance(delta)


func _notification(what: int) -> void:
	# The Web sends only the window one, when the canvas loses focus.
	var focus_out := what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT]
	if focus_out and GameState.state == GameState.State.RUNNING:
		GameState.pause()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		go_back()


## Android's back button (docs/M5.md L13): it leaves a screen of the title for the title, and
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
	_sim.arrived.connect(_on_arrived)
	_sim.health_changed.connect(EventBus.health_changed.emit)
	_sim.repaired.connect(EventBus.car_repaired.emit)
	_sim.offroad_changed.connect(EventBus.car_offroad_changed.emit)
	_sim.offroad_changed.connect(_on_offroad_changed)
	_sim.area_changed.connect(_on_area_changed)
	_input.autopilot = Autopilot.new(_sim) if _autopilot else null
	_input.enabled = true
	_hud.show()
	# The route strip shows the road whole, from where the run starts on it: a run from a later area
	# has its finish as many turns closer (ENDGAME_PLAN.md §5.14).
	var route := _run_schedule(&"")
	_hud.road = route
	_hud.start_turn = route.finish_turn - _schedule.finish_turn
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
	# The disasters that the player has seen weigh less in each area's pick (docs/POOLS.md V2).
	_collected = SaveService.data().seen_disasters()
	_director.start_run(run_seed, _collected)
	var whole := _drives_whole_road()
	GameState.start_run(run_seed, tutorial, whole, _schedule.finish if whole else &"")
	# Every run starts in an area too: the HUD names it, and M5's music starts with it (M4.3).
	_on_area_changed(_sim.area)
	# A new run is a cut: it shows the morning, or --hour's light, at once (docs/DAYNIGHT.md §5.4).
	_daylight.cycle.snap()
	_daylight.refresh()


## Retry on the game-over screen: the next run, on the same nodes. A forced --seed stays; otherwise
## the run gets a new random seed (docs/M2.md H28).
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


## Play on the title screen: a run, as with --play, on the title's choice of road, and from its
## choice of area, as --home and --area would start it, and so do its retries
## (docs/ZONE_SELECT.md Z6, ENDGAME_PLAN.md §5.11, §5.12).
func _play() -> void:
	if GameState.state != GameState.State.TITLE:
		push_error("main: Play is only allowed on the title screen")
		return
	_title.close()
	_road = _title.road
	_schedule = _run_schedule(_title.start_area.id)
	_start_run(_parse_seed(args))


## The run's schedule: the road's, from the area `id` on unless it's &"", and ending after
## --finish's turns if there are any.
func _run_schedule(id: StringName) -> AreaSchedule:
	var schedule := _road
	if _finish_turns >= 0:
		var finish := schedule.finish if schedule.has_finish() else DEBUG_FINISH
		schedule = schedule.ending_at(_finish_turns, finish)
	if id != &"":
		schedule = schedule.starting_at(id)
	return schedule


func _show_title() -> void:
	_hud.hide()
	_input.enabled = false
	_title.open()


## Frees the last run's car and disaster at once, not queued, so that no frame shows two cars
## (docs/M3.md J13).
func _clear_run() -> void:
	_game_over.close()
	_director.clear()
	_camera.stop_shake()
	_camera.end_arrival()
	_camera.car = null
	_world.car = null
	_car.free()
	_car = null
	_fate = ""
	_new_legends.clear()


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


## The car reached the finish (ENDGAME_PLAN.md §5.3): the run ends in an arrival, and the car rolls
## to a stop. A run that drove the whole road, from the route's first area, counts the arrival, and
## unlocks a legend that the player hasn't collected, at random (§5.5). Then the scene (§5.8).
func _on_arrived() -> void:
	_end_run(CarSim.ARRIVAL)
	if GameState.whole_road:
		var data := SaveService.data()
		var id := LegendUnlock.pick(_whole_schedule, data.seen_disasters(), GameState.run_seed)
		SaveService.record_arrival(_schedule.finish, GameState.stats(), id)
		_fate = LegendUnlock.text(_whole_schedule, id)
		_found(id)
	_welcome()
	_director.play_arrival(_car, _camera)


## The arrival's scene (ENDGAME_PLAN.md §5.8): the sun sets, and at the pier the legends collected,
## the one just unlocked too, welcome the car, as the camera eases to show them.
func _welcome() -> void:
	_daylight.cycle.hold(Tuning.ARRIVAL_HOUR)
	var pier := _world.set_piece_at(_buffer.generator.finish_index) as Pier
	if pier != null:
		pier.welcome(_whole_schedule, SaveService.data().seen_disasters())
		_camera.arrive(pier.welcome_bounds)


## Whether the run starts in the road's first area: not a run from a later area, chosen with
## --area or on the title (ZS, and Departures, ENDGAME_PLAN.md Q4, W22).
func _drives_whole_road() -> bool:
	return _schedule.entries[0].area == _road.entries[0].area


## A clean run never leaves the road (ENDGAME_PLAN.md §5.4). The tutorial's mistakes don't count.
func _on_offroad_changed(is_offroad: bool) -> void:
	if is_offroad and not GameState.in_tutorial:
		GameState.clean = false


## The car reached `area`. GameState counts the area's distance and turns from its first tile, which
## the car may have passed, off the road. In the step that reaches it, CarSim reports the area
## before the trigger judges the turn behind it (docs/M5.md L8). After a tutorial, both count from
## where the City's run began.
func _on_area_changed(area: AreaDef) -> void:
	var first := _buffer.car_index()
	while first > _buffer.first_index() and _buffer.path_tile(first - 1).area_id == area.id:
		first -= 1
	# A run starts at the centre of its first tile, at distance 0.
	var start := maxf(first - 0.5 - _origin, 0.0)
	GameState.enter_area(area.id, start, _turns_before(first) - _turn_base)
	# Each zone starts its clock again, at its own pace (docs/DAYNIGHT.md §5.4).
	_daylight.cycle.enter(area.day_seconds)
	# Its disaster for the run, now that the car reached it (docs/POOLS.md Q4).
	_director.enter_area(area)
	EventBus.area_changed.emit(area)


## The tutorial's streak is done at `junction` (docs/TUTORIAL.md §5.5): the run goes on in the City,
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
	# The City's day starts here too, as its distance and turns do (docs/DAYNIGHT.md §5.4).
	_daylight.cycle.enter(_sim.area.day_seconds)
	EventBus.tutorial_completed.emit()
	EventBus.area_changed.emit(_sim.area)


## The turns before path index `index`: the turn number of the first junction from there on, as a
## junction's turn number counts the turns before it, and a decoy is no turn (docs/ROADGEN.md R1).
func _turns_before(index: int) -> int:
	for i: int in range(index, _buffer.last_index() + 1):
		var tile := _buffer.path_tile(i)
		if tile.is_junction():
			return tile.turn_number
	# Past the last junction, before the finish, every turn is behind.
	if _buffer.generator.finished():
		return _buffer.generator.turn_count
	# The buffer always holds the next junction (JunctionTrigger._junction_after()).
	push_error("main: no junction after path index %d" % index)
	return GameState.turn_index


func _on_disaster_appeared(disaster: DisasterBase, area: AreaDef) -> void:
	EventBus.disaster_appeared.emit(disaster.id, area)


func _on_disaster_started(disaster: DisasterBase, area: AreaDef) -> void:
	EventBus.disaster_started.emit(disaster.id, area)
	_fate = disaster.fate
	_found(disaster.id)


## The run met or unlocked the legend `id`, if it isn't &"": a new legend, unless it was collected
## as the run started (ENDGAME_PLAN.md §5.9).
func _found(id: StringName) -> void:
	if id != &"" and id not in _collected and id not in _new_legends:
		_new_legends.append(id)


## The run is over the moment it ends (docs/M3.md J1): the input stops, and GameState reports the
## cause and the stats. The director then plays the disaster or the crash.
func _end_run(cause: StringName) -> void:
	GameState.distance = maxf(GameState.distance, _sim.progress - _origin)
	_input.enabled = false
	GameState.end_run(cause)
	if _autopilot and cause != CarSim.ARRIVAL:
		push_error("main: the autopilot's run ended: %s" % cause)


## The disaster, the crash or the arrival has played: game over. The next goal counts what the run
## did, which the save already holds.
func _on_sequence_finished() -> void:
	GameState.show_game_over()
	var area := _buffer.generator.find_area(GameState.area_id)
	var goal := GameOver.next_goal(SaveService.data(), _whole_schedule)
	_game_over.open(GameState.stats(), area, _fate, not _new_legends.is_empty(), goal)


## Whether the next run starts with the tutorial (docs/TUTORIAL.md §5.6): only one that starts in
## the City, the whole schedule's first area, also when --area or the title's Start button chooses
## it. --tutorial asks for it. Otherwise Play does, until the player has finished it, but not --play
## or --autopilot, which tests and checks use.
func _tutorial_wanted() -> bool:
	if _schedule.entries[0].area != _whole_schedule.entries[0].area:
		return false
	# Its loops are laid for a road that starts heading N (ENDGAME_PLAN.md W10).
	if _schedule.mirrored:
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


## The turns of --finish=<turns> in `p_args`, after which the road ends; -1 without it. The road can
## end sooner than `schedule`'s, not later: past its finish, a home stretch would get junctions,
## with no pool to play a disaster from (ENDGAME_PLAN.md W17).
static func _parse_finish(p_args: PackedStringArray, schedule: AreaSchedule) -> int:
	for arg: String in p_args:
		if arg.begins_with("--finish="):
			var text := arg.trim_prefix("--finish=")
			if not text.is_valid_int() or text.to_int() < 0:
				push_error("main: --finish= needs a number of turns, such as --finish=3")
			elif schedule.has_finish() and text.to_int() > schedule.finish_turn:
				push_error(
					"main: --finish= needs at most %d turns, the road's own" % schedule.finish_turn
				)
			else:
				return text.to_int()
	return -1


## The legends of --collected=<id> in `p_args`, those of the pool of the area `id` of `schedule`, or
## with --collected=all, of every pool, each with the first area whose pool has it: {} without it.
## An id that isn't an area of `schedule` with a pool is an error, and marks none (ENDGAME_PLAN.md
## §5.7).
static func _parse_collected(
	p_args: PackedStringArray, schedule: AreaSchedule
) -> Dictionary[StringName, StringName]:
	var legends: Dictionary[StringName, StringName] = {}
	for arg: String in p_args:
		if arg.begins_with("--collected="):
			var id := StringName(arg.trim_prefix("--collected="))
			for area: AreaDef in schedule.areas():
				if id == &"all" or area.id == id:
					for scene: PackedScene in area.disasters:
						var legend := DisasterPicks.id_of(scene)
						if legend != &"" and not legends.has(legend):
							legends[legend] = area.id
			if legends.is_empty():
				push_error(
					"main: --collected= needs all or an area with legends, such as --collected=city"
				)
			return legends
	return legends


## The hour of --hour=<h> in `p_args`, round the clock, which every zone's clock starts at
## (docs/DAYNIGHT.md §5.9). Tuning.DAY_START_HOUR without it, or with an h that isn't a number.
static func _parse_hour(p_args: PackedStringArray) -> float:
	for arg: String in p_args:
		if arg.begins_with("--hour="):
			var text := arg.trim_prefix("--hour=")
			if text.is_valid_float() and is_finite(text.to_float()):
				return fposmod(text.to_float(), 24.0)
			push_error("main: --hour= needs an hour, such as --hour=20.5")
	return Tuning.DAY_START_HOUR
