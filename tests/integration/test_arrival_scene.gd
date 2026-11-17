extends GutTest
## The arrival's scene in the game (ENDGAME_PLAN.md §5.8, E7), through the main scene's
## _physics_process(): as the car rolls to a stop at the pier, the sun sets, never faster than the
## light's rate, and the legends collected, the one that the arrival unlocks too, wait in view, at
## zoom 1 on every screen, faded in by the time the end screen shows. A retry starts the zone's
## clock again from its own hour, and the camera follows the car again.

const MainScene := preload("res://tests/helpers/main_scene.gd")
const Fixtures := preload("res://tests/helpers/road_fixtures.gd")
const ARRIVED := GameState.State.ARRIVED
const RUNNING := GameState.State.RUNNING
const GAME_OVER := GameState.State.GAME_OVER
## Long enough for a few turns, and short enough to fail fast.
const FRAMES := 60 * 90


func before_each() -> void:
	SaveService.use_memory()


func after_each() -> void:
	GameState.quit_to_title()
	AudioDirector.stop_all()


## The autopilot on a short road, which the car drives to the finish in about 8 s.
static func _args(extra: Array[String] = []) -> Array[String]:
	var args: Array[String] = ["--autopilot", "--seed=12345", "--finish=3"]
	args.append_array(extra)
	return args


## The largest change in a channel from `a` to `b`.
static func _change(a: Color, b: Color) -> float:
	return maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b)))


## The pier at the end of `main`'s road.
static func _pier(main: Node) -> Pier:
	for node: Node in main.get_node("%World/%SetPieces").get_children():
		if node is Pier:
			return node
	return null


static func _stills(pier: Pier) -> Array[LegendStill]:
	var stills: Array[LegendStill] = []
	for node: Node in pier.get_children():
		if node is LegendStill:
			stills.append(node)
	return stills


## `rect`, in `item`'s coordinates, on the screen.
static func _on_screen(item: CanvasItem, rect: Rect2) -> Rect2:
	return item.get_global_transform_with_canvas() * rect


## Drives to the finish with the zone's clock starting at `start`, and checks the light on each
## frame of the arrival, then a retry.
func _assert_sunset(start: float) -> void:
	var when := "from %02d:00" % roundi(start)
	var main := MainScene.open(self, _args(["--hour=%d" % roundi(start)]))
	var cycle: DayCycle = (main.get_node("%Daylight") as Daylight).cycle
	MainScene.run_while(self, main, RUNNING, FRAMES)
	assert_eq(GameState.state, ARRIVED, when + ": the car reached the finish")
	assert_ne(cycle.light, Tuning.LIGHT_DUSK, when + ": the light isn't the sunset's yet")
	var off_hour := 0
	var too_fast := 0
	var frames := 0
	while GameState.state == ARRIVED and frames < 600:
		if cycle.hour() != Tuning.ARRIVAL_HOUR:
			off_hour += 1
		var light := cycle.light
		simulate(main, 1, MainScene.DELTA)
		frames += 1
		if _change(light, cycle.light) > Tuning.LIGHT_MAX_RATE * MainScene.DELTA + 1e-6:
			too_fast += 1
	assert_eq(GameState.state, GAME_OVER, when + ": the end screen shows")
	assert_eq(off_hour, 0, when + ": the clock stands at the sunset's hour")
	assert_eq(too_fast, 0, when + ": the light changes no faster than the rate")
	assert_eq(cycle.light, Tuning.LIGHT_DUSK, when + ": the sun has set by the end screen")
	var camera: CameraRig = main.get_node("%Camera")
	MainScene.press_key(main, KEY_ENTER)
	assert_eq(GameState.state, RUNNING, when + ": Retry")
	assert_eq(cycle.hour(), start, when + ": the next run's clock starts at its own hour")
	simulate(main, 60, MainScene.DELTA)
	assert_gt(cycle.hour(), start, when + ": and runs")
	var target := camera.target()
	camera.end_arrival()
	assert_eq(camera.target(), target, when + ": the camera follows the car again")


func test_the_sun_sets_as_the_car_arrives_and_a_retry_starts_the_day_again() -> void:
	_assert_sunset(Tuning.DAY_START_HOUR)


func test_the_sun_sets_on_an_arrival_at_night_too() -> void:
	_assert_sunset(0.0)


## Drives to the finish on a screen of `size` with every other legend collected, and checks that
## the car stays in view as it rolls to a stop, and then each legend collected, the arrival's too,
## waits in view, at zoom 1 and below the HUD's top bar, and has faded in by the end screen.
func _assert_stills_in_view(size: Vector2i) -> void:
	var save := SaveService.data()
	var book := CollectionScreen.disasters(Fixtures.schedule())
	for k: int in range(0, book.size(), 2):
		save.unlock_disaster(book[k]["id"])
	var main := MainScene.open(self, _args(), true, size)
	var car := MainScene.car(main)
	var camera: CameraRig = main.get_node("%Camera")
	MainScene.run_while(self, main, RUNNING, FRAMES)
	assert_eq(GameState.state, ARRIVED)
	var seen := save.seen_disasters()
	var collected: Array[StringName] = []
	for legend: Dictionary in book:
		if legend["id"] in seen:
			collected.append(legend["id"])
	var every_other := ceili(book.size() / 2.0)
	assert_eq(collected.size(), every_other + 1, "every other legend, and the arrival's")
	var pier := _pier(main)
	assert_not_null(pier, "the road ends at a pier")
	if pier == null:
		return
	var stills := _stills(pier)
	var ids: Array[StringName] = []
	for still: LegendStill in stills:
		ids.append(still.id)
	assert_eq(ids, collected, "a still of each legend collected, in the Book's order, and no other")
	var screen := main.get_viewport().get_visible_rect()
	assert_eq(screen.size, Vector2(size), "the screen")
	var hidden := 0
	while GameState.state == ARRIVED and car.sim.speed > 0.0:
		simulate(main, 1, MainScene.DELTA)
		# The camera moves the view as the engine flushes its transform's change, which simulate()
		# doesn't: so it moves it now.
		camera.force_update_scroll()
		hidden += int(not screen.encloses(_on_screen(car.get_parent(), car.body_rect())))
	assert_eq(GameState.state, ARRIVED)
	assert_eq(car.sim.speed, 0.0, "the car stopped")
	assert_eq(hidden, 0, "frames of the arrival without the car in view")
	assert_eq(camera.zoom, Vector2.ONE, "at zoom 1")
	var top := (main.get_node("%HUD/Top") as Control).get_global_rect().end.y
	for still: LegendStill in stills:
		var rect := _on_screen(still, still.get_rect())
		assert_true(screen.encloses(rect), "%s is in view, at %s" % [still.id, rect])
		assert_gte(rect.position.y, top, "%s is below the HUD's top bar" % still.id)
	MainScene.run_while(self, main, ARRIVED, 600)
	assert_eq(GameState.state, GAME_OVER)
	for still: LegendStill in stills:
		assert_eq(still.modulate.a, 1.0, "%s has faded in by the end screen" % still.id)


func test_each_legend_collected_waits_in_view_as_the_car_stops() -> void:
	_assert_stills_in_view(Vector2i(360, 640))


## The Fold4's inner screen in portrait shows 320 px high at zoom 2, too small for the welcome and
## the car: the arrival zooms out a step.
func test_on_the_fold4s_inner_screen_the_arrival_zooms_out_to_show_them() -> void:
	_assert_stills_in_view(Vector2i(532, 640))


## And so it does on the widest reference screen, the Fold4's cover screen in landscape.
func test_on_the_widest_screen_the_arrival_zooms_out_to_show_them() -> void:
	_assert_stills_in_view(Vector2i(1639, 640))
