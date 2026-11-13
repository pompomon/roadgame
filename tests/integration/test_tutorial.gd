extends GutTest
## The tutorial in the game (TUTORIAL_PLAN.md §5.4 to §5.6). Play starts a run in the City with it
## until the player has finished it, and --tutorial always does. The HUD shows the streak, and the
## goal for the distance and the area's name. The streak's end starts the City's run there: its
## distance, turns and areas count from the junction, and the save marks the tutorial done. A car
## left alone is put back on the path with the camera on it at once. SaveService keeps the save in
## memory.

const MainScene := preload("res://tests/helpers/main_scene.gd")
const RUNNING := GameState.State.RUNNING
## The autopilot finishes the tutorial in about 18 s (§6.5, P1).
const TUTORIAL_FRAMES := 60 * 40


func before_each() -> void:
	SaveService.use_memory()


func after_each() -> void:
	GameState.quit_to_title()
	SaveService.use_memory()


static func _label(main: Node, unique_name: String) -> Label:
	return main.get_node("%HUD/%" + unique_name)


func test_play_starts_the_tutorial_until_the_player_has_finished_it() -> void:
	for done: bool in [false, true]:
		SaveService.use_memory()
		if done:
			SaveService.complete_tutorial()
		var main := MainScene.open(self, ["--seed=1"], false)
		MainScene.press_key(main, KEY_ENTER)
		var why := "done" if done else "a fresh save"
		assert_eq(GameState.state, RUNNING, why)
		assert_eq(GameState.in_tutorial, not done, why)
		assert_eq(_label(main, "Distance").visible, done, why)
		main.get_parent().free()
		GameState.quit_to_title()


## Tests and checks start runs with --play or --autopilot: those get no tutorial, even with a fresh
## save, so they drive the road that they always have.
func test_the_play_and_autopilot_arguments_skip_the_tutorial() -> void:
	for arg: String in ["--play", "--autopilot"]:
		SaveService.use_memory()
		var main := MainScene.open(self, ["--seed=1", arg], false)
		assert_eq(GameState.state, RUNNING, arg)
		assert_false(GameState.in_tutorial, arg)
		main.get_parent().free()
		GameState.quit_to_title()


func test_the_streak_ends_the_tutorial_and_the_city_run_counts_from_there() -> void:
	watch_signals(EventBus)
	var main := MainScene.open(self, ["--seed=1", "--tutorial"])
	var sim := MainScene.car(main).sim
	watch_signals(sim.trigger)
	assert_true(GameState.in_tutorial)
	assert_false(_label(main, "Distance").visible)
	assert_eq(_label(main, "Turns").text, "turns 0/%d" % Tuning.TUTORIAL_STREAK)
	assert_eq(_label(main, "AreaBanner").text, Hud.TUTORIAL_BANNER % Tuning.TUTORIAL_STREAK)
	(main.get_node("%InputRouter") as InputRouter).autopilot = Autopilot.new(sim)
	for frame: int in TUTORIAL_FRAMES:
		if not GameState.in_tutorial:
			break
		simulate(main, 1, MainScene.DELTA)
	assert_false(GameState.in_tutorial)
	assert_true(SaveService.data().tutorial["done"], "done for good")
	assert_signal_emit_count(EventBus, "streak_changed", Tuning.TUTORIAL_STREAK)
	assert_signal_emit_count(EventBus, "tutorial_completed", 1)
	assert_signal_not_emitted(EventBus, "turn_completed")
	assert_eq(GameState.distance, 0.0)
	assert_true(_label(main, "Distance").visible)
	assert_eq(_label(main, "Turns").text, "turns 0")
	assert_eq(_label(main, "AreaBanner").text, "City")
	assert_signal_emit_count(EventBus, "area_changed", 2)
	var junction: RoadTile = get_signal_parameters(sim.trigger, "tutorial_completed")[0]
	for frame: int in 60 * 30:
		if GameState.turn_index >= 2:
			break
		simulate(main, 1, MainScene.DELTA)
	assert_eq(GameState.turn_index, 2)
	assert_eq(_label(main, "Turns").text, "turns 2")
	# The main scene takes the distance before the car steps.
	var distance := sim.progress - (junction.path_index + 0.5)
	simulate(main, 1, MainScene.DELTA)
	assert_almost_eq(GameState.distance, distance, 1e-6)
	var areas: Dictionary = GameState.stats()["areas"]
	assert_eq(areas.size(), 1, "only the City")
	assert_eq(areas.get(&"city"), {"distance": GameState.distance, "turns": 2})
	# The schedule counts from the City's first turn, too: Rural comes after its turns there.
	var schedule: AreaSchedule = load("res://areas/schedule.tres")
	var rural := schedule.entries[1].turn
	for frame: int in 60 * 120:
		if GameState.turn_index > rural:
			break
		simulate(main, 1, MainScene.DELTA)
	assert_eq(GameState.area_id, &"rural")
	areas = GameState.stats()["areas"]
	assert_eq(areas[&"city"]["turns"], rural, "the City's turns")
	assert_eq(areas[&"rural"]["turns"], 1, "Rural's first")
	var distance_sum: float = areas[&"city"]["distance"] + areas[&"rural"]["distance"]
	assert_almost_eq(distance_sum, GameState.distance, 1e-6, "the areas' distances")
	assert_gt(areas[&"rural"]["distance"], 0.0, "Rural's distance")
	assert_eq(GameState.state, RUNNING)
	# The stats count the turns that the road has: check the road too.
	var first_rural: RoadTile = null
	for i: int in range(sim.buffer.first_index(), sim.buffer.last_index() + 1):
		var tile := sim.buffer.path_tile(i)
		if tile.is_junction() and tile.area_id == &"rural":
			first_rural = tile
			break
	assert_not_null(first_rural, "Rural's first junction")
	if first_rural != null:
		assert_eq(
			first_rural.turn_number - (junction.turn_number + 1), rural, "the City's junctions"
		)


## TUTORIAL_PLAN.md §5.3: with no input, the car drives on off the road at the first junction, with
## no health, until it is put back before the junction, with the camera on it.
func test_a_car_left_alone_is_put_back_with_the_camera_on_it() -> void:
	var main := MainScene.open(self, ["--seed=1", "--tutorial"])
	var sim := MainScene.car(main).sim
	var camera: CameraRig = main.get_node("%Camera")
	watch_signals(sim)
	var lowest := sim.health
	for frame: int in 60 * 30:
		simulate(main, 1, MainScene.DELTA)
		lowest = minf(lowest, sim.health)
		if get_signal_emit_count(sim, "rescued") > 0:
			break
	assert_signal_emit_count(sim, "rescued", 1)
	assert_eq(lowest, 0.0, "it drove on with no health")
	assert_eq(GameState.state, RUNNING)
	assert_true(GameState.in_tutorial)
	var behind := camera.position.distance_to(camera.target())
	# The snap is deferred to the end of the frame, once the car's node has moved. Real frames would
	# step the car and the camera too: stop them, so that only the snap moves the camera.
	main.process_mode = Node.PROCESS_MODE_DISABLED
	await wait_process_frames(1)
	var off := camera.position.distance_to(camera.target())
	assert_lt(off, 1.0, "%.0f px from the car, %.0f px before the frame ended" % [off, behind])


## Also when the title's Start button chooses the area, in debug builds (ZONE_SELECT_PLAN.md Z1).
func test_only_a_run_that_starts_in_the_city_has_the_tutorial() -> void:
	for chosen: bool in [false, true]:
		var main: Node
		if chosen:
			main = MainScene.open(self, ["--seed=1"], false)
			var title: TitleScreen = main.get_node("%Title")
			title.area_choice = true
			title.start_area = title.schedule.areas()[1]
			MainScene.press_key(main, KEY_ENTER)
		else:
			main = MainScene.open(self, ["--seed=1", "--tutorial", "--area=rural"])
		var why := "the Start button" if chosen else "--area"
		assert_eq(GameState.state, RUNNING, why)
		assert_false(GameState.in_tutorial, why)
		assert_eq(GameState.area_id, &"rural", why)
		main.get_parent().free()
		GameState.quit_to_title()
