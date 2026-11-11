extends GutTest
## A forced wrong turn in each area plays a disaster from that area's pool only
## (IMPLEMENTATION_PLAN.md M4 tests): the main scene starts in the area (--area, M4_PLAN.md K10),
## the pilot takes a wrong exit at its third junction, and the area's disaster takes the car before
## the game-over screen, 2 to 4 s after the turn. Every disaster of every pool plays for some seed
## (M6_PLAN.md S13).

const MainScene := preload("res://tests/helpers/main_scene.gd")
const Fixtures := preload("res://tests/helpers/road_fixtures.gd")
const WrongTurnPilot := preload("res://tests/helpers/wrong_turn_pilot.gd")
const RUNNING := GameState.State.RUNNING
const DISASTER := GameState.State.DISASTER
## Seeds to try until an area has played every disaster of its pool.
const SEEDS := 8


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
	assert_eq((triggered[1] as RoadTile).turn_number, 2, "%s: at the third junction" % what)
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
	for area: AreaDef in Fixtures.schedule().areas():
		var pool := _ids(area)
		var played: Array[StringName] = []
		for run_seed: int in SEEDS:
			var id := _wrong_turn_in(area, run_seed)
			if id not in played:
				played.append(id)
			if pool.all(func(of: StringName) -> bool: return of in played):
				break
		for id: StringName in pool:
			assert_has(played, id, "%s: %s plays for one of %d seeds" % [area.id, id, SEEDS])


## The ids of the disasters of `area`'s pool.
static func _ids(area: AreaDef) -> Array[StringName]:
	var found: Array[StringName] = []
	for scene: PackedScene in area.disasters:
		var disaster := scene.instantiate() as DisasterBase
		found.append(disaster.id)
		disaster.free()
	return found
