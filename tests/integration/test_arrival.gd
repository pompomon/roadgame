extends GutTest
## The end of the road (ENDGAME_PLAN.md §5.3, §5.5, E1, E5): the autopilot drives a short road,
## --finish's, to its finish. The run ends in an arrival, the car rolls to a stop, and the end
## screen shows ARRIVAL_SECONDS later, with the run's time. A run that drove the whole road counts
## the arrival and unlocks a legend that the player hasn't collected; one from a later area doesn't.

const MainScene := preload("res://tests/helpers/main_scene.gd")
const Fixtures := preload("res://tests/helpers/road_fixtures.gd")
const ARRIVED := GameState.State.ARRIVED
const RUNNING := GameState.State.RUNNING
## Long enough for a few turns, and short enough to fail fast.
const FRAMES := 60 * 90


func before_each() -> void:
	SaveService.use_memory()


func after_each() -> void:
	GameState.quit_to_title()


## The legends the save holds as unlocked and not seen.
static func _unlocked(save: SaveData) -> Array[StringName]:
	var found: Array[StringName] = []
	for id: String in save.disasters:
		if save.disasters[id]["unlocked"] and save.disasters[id]["seen"] == 0:
			found.append(StringName(id))
	return found


func test_the_autopilot_reaches_the_finish_and_unlocks_a_legend() -> void:
	watch_signals(EventBus)
	var main := MainScene.open(self, ["--autopilot", "--seed=12345", "--finish=3"])
	var car := MainScene.car(main)
	var frames := MainScene.run_while(self, main, RUNNING, FRAMES)
	assert_eq(GameState.state, ARRIVED)
	assert_eq(GameState.end_cause, CarSim.ARRIVAL)
	assert_eq(GameState.turn_index, 3)
	assert_almost_eq(GameState.seconds, frames * MainScene.DELTA, MainScene.DELTA * 2.01)
	assert_signal_emit_count(EventBus, "run_ended", 1)
	assert_signal_not_emitted(EventBus, "disaster_triggered")
	var save := SaveService.data()
	var arrival: Dictionary = save.arrivals.get("pier", {})
	assert_eq(arrival.get("count"), 1)
	assert_almost_eq(arrival.get("best_seconds", 0.0), GameState.seconds, 1e-6)
	assert_eq(arrival.get("clean"), GameState.clean)
	var unlocked := _unlocked(save)
	assert_eq(unlocked.size(), 1, "one legend")
	var game_over: GameOver = main.get_node("%GameOver")
	var shown := MainScene.run_while(self, main, ARRIVED, 600)
	assert_almost_eq(shown * MainScene.DELTA, Tuning.ARRIVAL_SECONDS, MainScene.DELTA * 1.01)
	assert_eq(car.sim.speed, 0.0, "the car stopped")
	assert_true(game_over.visible)
	assert_eq(game_over.get_node("%Cause").text, GameOver.END_MESSAGES[CarSim.ARRIVAL])
	var schedule := Fixtures.schedule()
	var fate: Label = game_over.get_node("%Fate")
	assert_eq(fate.text, LegendUnlock.text(schedule, unlocked[0]))
	assert_string_contains(fate.text, "A new legend for your book: ")
	assert_string_contains(game_over.get_node("%Stats").text, "\nTime: ")
	assert_eq(main.get_node("%World/%DisasterLayer").get_child_count(), 0, "no disaster")


func test_with_every_legend_collected_the_book_is_full() -> void:
	var save := SaveService.data()
	for legend: Dictionary in CollectionScreen.disasters(Fixtures.schedule()):
		save.unlock_disaster(legend["id"])
	var before := save.disasters.duplicate(true)
	var main := MainScene.open(self, ["--autopilot", "--seed=7", "--finish=1"])
	MainScene.run_while(self, main, RUNNING, FRAMES)
	MainScene.run_while(self, main, ARRIVED, 600)
	var game_over: GameOver = main.get_node("%GameOver")
	assert_eq(game_over.get_node("%Fate").text, LegendUnlock.BOOK_FULL)
	assert_eq(save.disasters, before, "nothing new")
	assert_eq(save.arrival_count(), 1)


## A run that starts in a later area (--area, the title's Start, Departures) reaches the finish,
## but it hasn't driven the whole road: no arrival is counted, and no legend unlocked (Q4).
func test_a_run_from_a_later_area_arrives_but_counts_nothing() -> void:
	var main := MainScene.open(self, ["--autopilot", "--seed=12345", "--area=rural", "--finish=36"])
	MainScene.run_while(self, main, RUNNING, FRAMES)
	assert_eq(GameState.state, ARRIVED)
	assert_eq(GameState.turn_index, 2)
	MainScene.run_while(self, main, ARRIVED, 600)
	var save := SaveService.data()
	assert_eq(save.arrivals, {} as Dictionary[String, Dictionary])
	assert_eq(_unlocked(save), [] as Array[StringName])
	var game_over: GameOver = main.get_node("%GameOver")
	assert_false(game_over.get_node("%Fate").visible, "no line")


## ENDGAME_PLAN.md §5.3: the run's clock stops while the run pauses. simulate() steps a paused tree
## too, so only the state can stop it.
func test_the_runs_clock_stops_while_it_pauses() -> void:
	var main := MainScene.open(self, ["--autopilot", "--seed=12345", "--finish=3"])
	simulate(main, 60, MainScene.DELTA)
	GameState.pause()
	var seconds := GameState.seconds
	assert_almost_eq(seconds, 60 * MainScene.DELTA, MainScene.DELTA * 1.01, "it ran")
	simulate(main, 60, MainScene.DELTA)
	assert_eq(GameState.seconds, seconds, "paused")
	GameState.resume()
	var frames := MainScene.run_while(self, main, RUNNING, FRAMES)
	assert_eq(GameState.state, ARRIVED)
	assert_almost_eq(GameState.seconds, seconds + frames * MainScene.DELTA, MainScene.DELTA * 2.01)


## ENDGAME_PLAN.md W11: an area that starts at the finish's turn, as the Coast does, has no
## junction, so every turn of the road is behind the car as it enters it. --finish=34 makes Rural
## one.
func test_an_area_without_a_junction_has_every_turn_behind_it() -> void:
	var main := MainScene.open(self, ["--autopilot", "--seed=12345", "--finish=34"])
	MainScene.run_while(self, main, RUNNING, FRAMES)
	assert_eq(GameState.state, ARRIVED)
	assert_eq(GameState.turn_index, 34)
	assert_eq(GameState.area_id, &"rural")
	var areas: Dictionary = GameState.stats()["areas"]
	assert_eq(areas[&"city"]["turns"], 34)
	assert_eq(areas[&"rural"]["turns"], 0, "no turn in it")
	assert_eq(SaveService.data().arrival_count(), 1)


## ENDGAME_PLAN.md §5.7: --finish= takes a number of turns. Anything else is an error, and the run
## drives the game's road.
func test_a_bad_finish_argument_is_an_error_and_the_road_is_the_games() -> void:
	for arg: String in ["--finish=", "--finish=pier", "--finish=-3"]:
		var main := MainScene.open(self, ["--seed=1", arg])
		assert_push_error("--finish= needs a number of turns", arg)
		assert_same(main.get("_schedule"), main.get("_whole_schedule"), arg)
		main.get_parent().free()


## ENDGAME_PLAN.md §5.6: the Road Home starts in the Desert, heading west, with no tutorial, and
## ends at home.
func test_the_road_home_starts_west_and_ends_at_home() -> void:
	var main := MainScene.open(self, ["--autopilot", "--seed=12345", "--home", "--finish=2"])
	var car := MainScene.car(main)
	var buffer := car.sim.buffer
	assert_eq(buffer.path_tile(buffer.first_index()).heading, Heading.W)
	assert_eq(buffer.path_tile(buffer.first_index()).area_id, &"desert")
	assert_false(GameState.in_tutorial)
	MainScene.run_while(self, main, RUNNING, FRAMES)
	assert_eq(GameState.state, ARRIVED)
	assert_eq(SaveService.data().arrivals.get("home", {}).get("count"), 1)
	assert_eq(_unlocked(SaveService.data()).size(), 1)


## ENDGAME_PLAN.md W10: the tutorial's loops are laid for a road that starts heading N, so the Road
## Home has none, even when --tutorial asks for it.
func test_the_road_home_has_no_tutorial() -> void:
	var main := MainScene.open(self, ["--seed=1", "--home", "--tutorial"])
	assert_eq(GameState.state, RUNNING)
	assert_false(GameState.in_tutorial)
	var buffer := MainScene.car(main).sim.buffer
	assert_eq(buffer.path_tile(buffer.first_index()).heading, Heading.W)


## ENDGAME_PLAN.md §5.4: a clean arrival never left the road.
func test_leaving_the_road_spoils_a_clean_run() -> void:
	var main := MainScene.open(self, ["--autopilot", "--seed=12345", "--finish=1"])
	var sim := MainScene.car(main).sim
	assert_true(GameState.clean)
	sim.offroad_changed.emit(true)
	sim.offroad_changed.emit(false)
	assert_false(GameState.clean)
	MainScene.run_while(self, main, RUNNING, FRAMES)
	assert_eq(GameState.state, ARRIVED)
	assert_false(SaveService.data().arrivals["pier"]["clean"])
