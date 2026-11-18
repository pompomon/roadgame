extends GutTest
## The end of the road (ENDGAME_PLAN.md §5.3, §5.5, E1, E5): the autopilot drives a short road,
## --finish's, to its finish. The run ends in an arrival, the car rolls to a stop, and the end
## screen shows ARRIVAL_SECONDS later, with the run's time. A run that drove the whole road counts
## the arrival and unlocks a legend that the player hasn't collected; one from a later area doesn't.
## The unlock shows NEW LEGEND!, and the end screen the next goal (§5.9). An arrival crosses the
## road's last area, which a run with no damage there stamps, and may beat the best time (§5.16).

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
	for legend: Dictionary in BookScreen.disasters(Fixtures.schedule()):
		save.unlock_disaster(legend["id"])
	var before := save.disasters.duplicate(true)
	watch_signals(EventBus)
	var main := MainScene.open(self, ["--autopilot", "--seed=7", "--finish=1"])
	MainScene.run_while(self, main, RUNNING, FRAMES)
	MainScene.run_while(self, main, ARRIVED, 600)
	var game_over: GameOver = main.get_node("%GameOver")
	assert_eq(game_over.get_node("%Fate").text, LegendUnlock.BOOK_FULL)
	assert_eq(save.disasters, before, "nothing new")
	assert_eq(save.arrival_count(), 1)
	assert_true(game_over.visible)
	assert_false(game_over.get_node("%NewLegend").visible, "no new legend (ENDGAME_PLAN.md §5.9)")
	assert_signal_not_emitted(EventBus, "new_legend_shown")


## A run that starts in a later area (--area, the title's Start, Departures) reaches the finish,
## but it hasn't driven the whole road: no arrival is counted, no legend unlocked (Q4), and no
## overall best set, only its area's (W22), and the stamp of the area that it crossed with no
## damage (§5.16). The sea is still the next goal (ENDGAME_PLAN.md §5.9).
func test_a_run_from_a_later_area_arrives_but_counts_nothing() -> void:
	watch_signals(EventBus)
	var main := MainScene.open(self, ["--autopilot", "--seed=12345", "--area=rural", "--finish=36"])
	MainScene.run_while(self, main, RUNNING, FRAMES)
	assert_eq(GameState.state, ARRIVED)
	assert_eq(GameState.turn_index, 2)
	MainScene.run_while(self, main, ARRIVED, 600)
	var save := SaveService.data()
	assert_eq(save.arrivals, {} as Dictionary[String, Dictionary])
	assert_eq(_unlocked(save), [] as Array[StringName])
	assert_eq(save.best, SaveData.BEST)
	assert_eq(save.atlas["rural"]["best_turns"], 2)
	assert_true(save.atlas["rural"]["stamped"], "Rural, crossed by the arrival")
	var game_over: GameOver = main.get_node("%GameOver")
	assert_false(game_over.get_node("%Fate").visible, "no line")
	assert_false(game_over.get_node("%NewLegend").visible, "no new legend")
	assert_signal_not_emitted(EventBus, "new_legend_shown")
	var turns := Fixtures.schedule().finish_turn
	assert_eq(game_over.get_node("%Goal").text, GameOver.GOAL_SEA % [0, turns], "no best yet")


## ENDGAME_PLAN.md §5.9: an arrival that unlocks a legend shows NEW LEGEND!, and its jingle plays
## once. The next goal is then to find the legends still missing, one fewer, once the Road Home has
## an arrival too (§5.12).
func test_an_arrival_that_unlocks_shows_new_legend() -> void:
	SaveService.data().record_arrival(GameOver.HOME, {"seconds": 900.0})
	watch_signals(EventBus)
	watch_signals(AudioDirector)
	var main := MainScene.open(self, ["--autopilot", "--seed=12345", "--finish=1"])
	MainScene.run_while(self, main, RUNNING, FRAMES)
	assert_eq(GameState.state, ARRIVED)
	var game_over: GameOver = main.get_node("%GameOver")
	MainScene.run_while(self, main, ARRIVED, 600)
	assert_true(game_over.visible)
	assert_true(game_over.get_node("%NewLegend").visible)
	assert_signal_emit_count(EventBus, "new_legend_shown", 1)
	var jingles := 0
	for k: int in get_signal_emit_count(AudioDirector, "effect_played"):
		if get_signal_parameters(AudioDirector, "effect_played", k)[0] == &"new_legend":
			jingles += 1
	assert_eq(jingles, 1, "the jingle, once")
	var none: Array[StringName] = []
	var missing := LegendUnlock.locked(Fixtures.schedule(), none).size() - 1
	assert_eq(game_over.get_node("%Goal").text, GameOver.GOAL_LEGENDS % missing)


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


## Copilot's review of #103: a --finish past the road's own end kept the Coast at turn 280 and laid
## junctions on it, a home stretch with no pool (W17), so a wrong exit there had no disaster to
## play. Such a number is an error too, and the road is the game's: from the Coast, the pier with no
## junction before it. The road's own end is a number like any other.
func test_a_finish_past_the_roads_own_end_is_an_error_and_the_road_is_the_games() -> void:
	var own := Fixtures.schedule().finish_turn
	var past := "--finish=%d" % (own + 1)
	var error := "--finish= needs at most %d turns" % own
	var main := MainScene.open(self, ["--seed=1", past])
	assert_push_error(error)
	assert_same(main.get("_schedule"), main.get("_whole_schedule"))
	main.get_parent().free()
	var coast := MainScene.open(self, ["--seed=1", "--area=coast", past])
	assert_push_error(error, "from the Coast")
	var generator := MainScene.car(coast).sim.buffer.generator
	assert_true(generator.finished(), "the pier is laid")
	assert_eq(generator.turn_count, 0, "with no junction before it")
	coast.get_parent().free()
	var whole := MainScene.open(self, ["--seed=1", "--finish=%d" % own])
	var schedule: AreaSchedule = whole.get("_schedule")
	assert_eq(schedule.finish_turn, own, "the road's own end")
	assert_eq(schedule.entries.size(), Fixtures.schedule().entries.size(), "with every area")


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


## ENDGAME_PLAN.md §5.16: an arrival crosses the road's last area, which it stamps if the car took
## no damage there. --finish=1 keeps the whole road in the City.
func test_an_arrival_with_no_damage_stamps_the_last_area() -> void:
	for damaged: bool in [true, false]:
		var why := "damaged" if damaged else "no damage"
		var main := MainScene.open(self, ["--autopilot", "--seed=12345", "--finish=1"])
		var sim := MainScene.car(main).sim
		if damaged:
			sim.damaged.emit(sim.area)
		MainScene.run_while(self, main, RUNNING, FRAMES)
		assert_eq(GameState.state, ARRIVED, why)
		assert_eq(GameState.area_id, &"city", why)
		var city: Dictionary = GameState.stats()["areas"][&"city"]
		assert_eq([city["damaged"], city["crossed"]], [damaged, true], why)
		assert_eq(SaveService.data().atlas["city"]["stamped"], not damaged, why)
		main.get_parent().free()
		GameState.quit_to_title()


## ENDGAME_PLAN.md §5.16: the end screen says "New best time!" under an arrival's time when it beat
## the best time at its finish: not on the first arrival, which has none to beat, nor on a slower
## one.
func test_an_arrival_that_beats_the_best_time_says_so() -> void:
	var bests := {0.0: false, 9999.0: true, 1.0: false}
	for best: float in bests:
		SaveService.use_memory()
		if best > 0.0:
			SaveService.data().record_arrival(&"pier", {"seconds": best})
		var main := MainScene.open(self, ["--autopilot", "--seed=12345", "--finish=1"])
		MainScene.run_while(self, main, RUNNING, FRAMES)
		MainScene.run_while(self, main, ARRIVED, 600)
		var game_over: GameOver = main.get_node("%GameOver")
		assert_true(game_over.visible, "best %s" % best)
		var stats: String = (game_over.get_node("%Stats") as Label).text
		assert_string_contains(stats, "\nTime: ")
		assert_eq(stats.ends_with("\n" + GameOver.NEW_BEST_TIME), bests[best], "best %s" % best)
		main.get_parent().free()
		GameState.quit_to_title()


## ENDGAME_PLAN.md §5.16: a retry forgets that the last arrival beat the best time. An arrival that
## didn't drive the whole road, as a departure's, counts nothing (W22), so it beats no best time:
## here the retry is made one by hand, as the title's Start would.
func test_a_retry_forgets_the_new_best_time() -> void:
	SaveService.data().record_arrival(&"pier", {"seconds": 9999.0})
	var main := MainScene.open(self, ["--autopilot", "--seed=12345", "--finish=1"])
	MainScene.run_while(self, main, RUNNING, FRAMES)
	MainScene.run_while(self, main, ARRIVED, 600)
	var stats: Label = main.get_node("%GameOver/%Stats")
	assert_true(stats.text.ends_with("\n" + GameOver.NEW_BEST_TIME), "the first arrival")
	MainScene.press_key(main, KEY_ENTER)
	assert_eq(GameState.state, RUNNING, "Enter pressed Retry")
	GameState.whole_road = false
	MainScene.run_while(self, main, RUNNING, FRAMES)
	MainScene.run_while(self, main, ARRIVED, 600)
	assert_true((main.get_node("%GameOver") as Control).visible)
	assert_string_contains(stats.text, "\nTime: ")
	assert_false(stats.text.ends_with("\n" + GameOver.NEW_BEST_TIME), "the departure's")
