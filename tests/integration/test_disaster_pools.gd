extends GutTest
## A forced wrong turn in each area plays a disaster from that area's pool only
## (IMPLEMENTATION_PLAN.md M4 tests): the main scene starts in the area (--area, docs/M4.md K10),
## the pilot takes a wrong exit at the junction of turn number 2, the third turn's or a decoy
## before it (docs/ROADGEN.md R2), and the area's disaster takes the car before the game-over
## screen, 2 to 4 s after the turn. Every disaster of every pool plays, with a seed that picks it
## (docs/M6.md S13), and each area's disaster is picked as the car reaches the area
## (POOLS_PLAN.md §5.1, Q4).

const MainScene := preload("res://tests/helpers/main_scene.gd")
const Fixtures := preload("res://tests/helpers/road_fixtures.gd")
const WrongTurnPilot := preload("res://tests/helpers/wrong_turn_pilot.gd")
const RUNNING := GameState.State.RUNNING
const DISASTER := GameState.State.DISASTER
## The run seeds among which to look for one that picks a disaster.
const PICK_SEEDS := 100


func before_each() -> void:
	watch_signals(EventBus)


func after_each() -> void:
	GameState.quit_to_title()


## The id of the disaster that a wrong turn in `area` plays for `run_seed`, after checking that it
## came from that area's pool and took 2 to 4 s.
func _wrong_turn_in(area: AreaDef, run_seed: int) -> StringName:
	var triggers: int = get_signal_emit_count(EventBus, "disaster_triggered")
	var main := MainScene.open(self, ["--seed=%d" % run_seed, "--area=%s" % area.id])
	var router: InputRouter = main.get_node("%InputRouter")
	router.autopilot = WrongTurnPilot.new(MainScene.car(main).sim)
	MainScene.run_while(self, main, RUNNING, 3600)
	var what := "%s, seed %d" % [area.id, run_seed]
	assert_eq(GameState.state, DISASTER, "%s: the run ended in a disaster" % what)
	if get_signal_emit_count(EventBus, "disaster_triggered") != triggers + 1:
		fail_test("%s: one disaster_triggered" % what)
		return &""
	var triggered: Array = get_signal_parameters(EventBus, "disaster_triggered")
	assert_eq(triggered[0], area, "%s: in the area" % what)
	assert_eq((triggered[1] as RoadTile).turn_number, 2, "%s: at turn number 2" % what)
	var director: DisasterDirector = main.get_node("%Director")
	var played: DisasterBase = null
	var frames := 0
	while GameState.state == DISASTER and frames < 600:
		simulate(main, 1, MainScene.DELTA)
		frames += 1
		if director.disaster != null:
			played = director.disaster
	assert_eq(GameState.state, GameState.State.GAME_OVER, "%s: then the game is over" % what)
	assert_between(frames * MainScene.DELTA, 2.0, 4.0, "%s: 2 to 4 s after the turn" % what)
	if played == null:
		fail_test("%s: no disaster played" % what)
		return &""
	var pool := area.disasters.map(func(scene: PackedScene) -> String: return scene.resource_path)
	assert_has(pool, played.scene_file_path, "%s: from the area's pool" % what)
	var id := played.id
	GameState.quit_to_title()
	return id


func test_a_wrong_turn_in_each_area_plays_a_disaster_from_its_pool() -> void:
	var schedule: AreaSchedule = load("res://areas/schedule.tres")
	var played: Array[StringName] = []
	for entry: AreaScheduleEntry in schedule.entries:
		played.append(_wrong_turn_in(entry.area, 1))
	assert_eq(played.size(), 5, "the five areas")
	assert_does_not_have(played, &"", "each played one of its pool")


func test_every_disaster_of_every_pool_plays() -> void:
	# Each in a run of its own, with the first seed that picks it while the collection is empty, as
	# each run adds the disaster it shows to the collection, where it weighs less (Q2).
	for area: AreaDef in Fixtures.schedule().areas():
		for scene: PackedScene in area.disasters:
			var id := DisasterPicks.id_of(scene)
			var run_seed := _seed_for(area, scene)
			if run_seed == -1:
				fail_test("%s: none of %d seeds picks %s" % [area.id, PICK_SEEDS, id])
				continue
			SaveService.use_memory()
			var what := "%s: %s, seed %d" % [area.id, id, run_seed]
			assert_eq(_wrong_turn_in(area, run_seed), id, what)
	SaveService.use_memory()


func test_each_area_is_picked_as_the_car_reaches_it() -> void:
	# As the run starts in it, with --area too, and as the car crosses into the next (Q4).
	var main := MainScene.open(self, ["--seed=1"])
	var director: DisasterDirector = main.get_node("%Director")
	assert_eq(director.picks.picked(), [&"city"] as Array[StringName], "as the run starts")
	var sim := MainScene.car(main).sim
	sim.area_changed.emit(sim.buffer.generator.find_area(&"rural"))
	assert_eq(director.picks.picked(), [&"city", &"rural"] as Array[StringName], "then Rural")
	GameState.quit_to_title()
	main = MainScene.open(self, ["--seed=1", "--area=village"])
	director = main.get_node("%Director")
	assert_eq(director.picks.picked(), [&"village"] as Array[StringName], "with --area")


## The first of PICK_SEEDS run seeds whose pick in `area` is `scene` while nothing has been seen, or
## -1.
static func _seed_for(area: AreaDef, scene: PackedScene) -> int:
	for run_seed: int in PICK_SEEDS:
		if DisasterPicks.new(run_seed).pick(area) == scene:
			return run_seed
	return -1
