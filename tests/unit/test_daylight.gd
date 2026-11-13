extends GutTest
## Daylight (DAYNIGHT_PLAN.md §5.5): the night's veil shows its clock's light over the view of the
## frame that the camera moved in, hides while the light is white, and is never redrawn.
## test_daylight_run.gd checks it in the main scene.

const Disasters := preload("res://tests/helpers/disaster_fixtures.gd")
const DELTA := 1.0 / 60.0


## A Daylight in the tree, for `camera`.
func _daylight(camera: Camera2D = null) -> Daylight:
	var made := Daylight.new()
	made.camera = camera
	add_child_autofree(made)
	return made


## Sets `daylight`'s clock to `hour` of a 120 s day, with the light of that hour shown.
static func _show_hour(daylight: Daylight, hour: float) -> void:
	daylight.cycle.start_hour = fposmod(hour, 24.0)
	daylight.cycle.enter(120.0)
	daylight.cycle.snap()
	daylight.refresh()


func test_by_day_the_veil_is_transparent_and_by_night_it_shows_the_light() -> void:
	# At each key hour, and halfway to the next (N35).
	var daylight := _daylight()
	var keys := Tuning.LIGHT_HOURS
	var days := 0
	var nights := 0
	for k: int in keys.size():
		var next := keys[(k + 1) % keys.size()] + (24.0 if k + 1 == keys.size() else 0.0)
		for hour: float in [keys[k], (keys[k] + next) / 2.0]:
			_show_hour(daylight, hour)
			var why := "at %.2f h" % fposmod(hour, 24.0)
			if daylight.cycle.light == Color.WHITE:
				days += 1
				assert_eq(daylight.modulate.a, 0.0, why + ": hidden")
			else:
				nights += 1
				assert_eq(Disasters.veil_tint(daylight), daylight.cycle.light, why + ": the light")
	assert_gt(days, 0, "hours of the day")
	assert_gt(nights, 0, "hours of dusk, night and dawn")


func test_in_the_games_frames_the_veil_follows_the_view_of_the_same_frame() -> void:
	# main.tscn steps Daylight after the camera, but its priority alone must do: here it enters the
	# tree first, so the tree's order would step it a frame late. Real frames (N23).
	var daylight := _daylight()
	var camera := Disasters.camera(self)
	daylight.camera = camera
	var car := Disasters.car(self)
	camera.car = car
	camera.position = Vector2(-300.0, 200.0)
	_show_hour(daylight, 22.0)
	camera.shake(1.0, 1.0)
	await get_tree().physics_frame
	var off := 0.0
	var moved := 0.0
	var was := camera.global_position + camera.offset
	for _frame: int in 10:
		await get_tree().physics_frame
		var centre := camera.global_position + camera.offset
		off = maxf(off, daylight.global_position.distance_to(centre))
		moved = maxf(moved, centre.distance_to(was))
		was = centre
	assert_gt(moved, 1.0, "the view moves each frame")
	assert_almost_eq(off, 0.0, 1e-3, "the veil on the view's centre")


func test_daylight_is_never_redrawn() -> void:
	# Each redraw of a Polygon2D after its first raises WebGL errors on the Web (M2_PLAN.md §5.7,
	# N34).
	# Over a day, a tenth of an hour each frame, it shows, changes its light at dusk and dawn, and
	# hides again, by its modulates alone. Headless, a frame sleeps as if it had drawn nothing: not
	# here.
	var sleep := OS.low_processor_usage_mode_sleep_usec
	OS.low_processor_usage_mode_sleep_usec = 0
	var daylight := _daylight(Disasters.camera(self))
	await wait_physics_frames(2)
	var draws: Array[int] = [0]
	daylight.draw.connect(_count.bind(draws))
	var shown := 0
	var changes := 0
	var was := daylight.self_modulate
	for step: int in 241:
		_show_hour(daylight, Tuning.DAY_START_HOUR + step * 0.1)
		await get_tree().physics_frame
		await get_tree().process_frame
		shown += int(daylight.modulate.a > 0.0)
		changes += int(daylight.self_modulate != was)
		was = daylight.self_modulate
	OS.low_processor_usage_mode_sleep_usec = sleep
	assert_between(shown, 1, 240, "frames with the veil shown")
	assert_gt(changes, 2, "frames with a new light")
	assert_eq(daylight.modulate.a, 0.0, "hidden again in the morning")
	assert_eq(draws[0], 0, "no redraws")


func _count(draws: Array[int]) -> void:
	draws[0] += 1
