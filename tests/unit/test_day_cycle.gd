extends GutTest
## DayCycle (DAYNIGHT_PLAN.md §5.1–§5.3): a zone's clock, the light of each hour, and the light
## shown, which follows it no faster than LIGHT_MAX_RATE.

const DELTA := 1.0 / 60.0


static func _distance(a: Color, b: Color) -> float:
	return maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b)))


## A zone's clock with a day of `day_seconds`, from `start_hour`, in its light.
static func _cycle(day_seconds: float, start_hour := Tuning.DAY_START_HOUR) -> DayCycle:
	var cycle := DayCycle.new()
	cycle.start_hour = start_hour
	cycle.enter(day_seconds)
	cycle.snap()
	return cycle


func test_the_hour_runs_round_the_clock_in_day_seconds() -> void:
	for start: float in [Tuning.DAY_START_HOUR, 22.0]:
		var cycle := _cycle(120.0, start)
		assert_eq(cycle.hour(), start, "%.0f:00 at the start" % start)
		var frames := 0
		for quarters: int in [1, 2, 4, 7]:
			while frames < quarters * 1800:
				cycle.advance(DELTA)
				frames += 1
			var expected := fposmod(start + 6.0 * quarters, 24.0)
			assert_almost_eq(
				cycle.hour(), expected, 1e-6, "%d quarters from %.0f:00" % [quarters, start]
			)


func test_entering_a_zone_starts_its_clock_at_the_start_hour() -> void:
	var cycle := _cycle(120.0)
	for _frame: int in 1000:
		cycle.advance(DELTA)
	assert_gt(cycle.hour(), Tuning.DAY_START_HOUR + 1.0, "the clock ran")
	cycle.enter(60.0)
	assert_eq(cycle.seconds, 0.0, "seconds")
	assert_eq(cycle.day_seconds, 60.0, "the zone's day")
	assert_eq(cycle.hour(), Tuning.DAY_START_HOUR, "the hour")
	cycle.advance(15.0)
	assert_almost_eq(cycle.hour(), Tuning.DAY_START_HOUR + 6.0, 1e-9, "a quarter of its day")


func test_each_key_hour_has_its_light() -> void:
	var hours := Tuning.LIGHT_HOURS
	assert_eq(hours.size(), Tuning.LIGHT_COLORS.size(), "a colour for each key")
	for k: int in hours.size():
		assert_true(hours[k] >= 0.0 and hours[k] < 24.0, "%.1f within the day" % hours[k])
		if k > 0:
			assert_gt(hours[k], hours[k - 1], "the hours rise")
		assert_eq(DayCycle.light_at(hours[k]), Tuning.LIGHT_COLORS[k], "at %.1f" % hours[k])
	# The night runs on past midnight.
	assert_eq(DayCycle.light_at(0.0), Tuning.LIGHT_NIGHT, "midnight")
	assert_eq(DayCycle.light_at(24.0), Tuning.LIGHT_NIGHT, "24:00")


func test_the_day_is_exactly_white_from_seven_to_five() -> void:
	var off := 0
	for k: int in range(700, 1701):
		off += int(DayCycle.light_at(k / 100.0) != Color.WHITE)
	assert_eq(off, 0, "hundredths of an hour of day that aren't white")
	assert_ne(DayCycle.light_at(6.99), Color.WHITE, "dawn before")
	assert_ne(DayCycle.light_at(17.01), Color.WHITE, "dusk after")


func test_between_keys_the_light_eases_in_and_out() -> void:
	# Each channel moves one way from a key to the next. In the first and the last hundredth of the
	# way, the light moves by less than a tenth of a straight blend's step: it leaves and reaches
	# each key gently.
	const STEPS := 100
	var hours := Tuning.LIGHT_HOURS
	for i: int in hours.size():
		var j := (i + 1) % hours.size()
		var span := fposmod(hours[j] - hours[i], 24.0)
		var from := Tuning.LIGHT_COLORS[i]
		var to := Tuning.LIGHT_COLORS[j]
		var back := 0
		var last := from
		for s: int in range(1, STEPS + 1):
			var now := DayCycle.light_at(hours[i] + span * s / STEPS)
			for c: int in 3:
				back += int((now[c] - last[c]) * signf(to[c] - from[c]) < -1e-9)
			last = now
		assert_eq(back, 0, "%.1f to %.1f: steps against the way" % [hours[i], hours[j]])
		var straight := _distance(from, to) / STEPS
		if straight == 0.0:
			continue
		var leaves := _distance(from, DayCycle.light_at(hours[i] + span / STEPS))
		var reaches := _distance(to, DayCycle.light_at(hours[i] + span * (STEPS - 1) / STEPS))
		assert_lt(leaves, 0.1 * straight, "%.1f: leaves it gently" % hours[i])
		assert_lt(reaches, 0.1 * straight, "%.1f: reaches it gently" % hours[j])


func test_the_light_shown_never_changes_faster_than_the_max_rate() -> void:
	# Zones of every length from half an hour to 23 and a half, so that the clock goes back to the
	# morning from every hour of the day, in days of 120 s and of the least. Each frame's light is
	# compared with the last frame's, across each new zone's enter() too (N4, N5).
	var reach := Tuning.LIGHT_MAX_RATE * DELTA
	for day: float in [120.0, DayCycle.least_day_seconds()]:
		var cycle := _cycle(day)
		var was := cycle.light
		var worst := 0.0
		for zone: int in 24:
			for _frame: int in ceili((zone + 0.5) / 24.0 * day / DELTA):
				cycle.advance(DELTA)
				worst = maxf(worst, _distance(was, cycle.light))
				was = cycle.light
			cycle.enter(day)
		assert_lte(worst, reach + 1e-6, "days of %.2f s" % day)


func test_after_a_reset_the_light_catches_up_and_then_follows_exactly() -> void:
	# From the night at 22:00, a new zone's clock is back at 07:00: the light shown takes the
	# largest channel difference over the rate to get there. A sum of 1/60 s may fall short of it,
	# so it may take a frame more. It goes the straight way, within float rounding, so that every
	# light shown is a blend of the key lights, where the smoke shows (DAYNIGHT_PLAN.md §5.7).
	var cycle := _cycle(120.0, 22.0)
	var from := cycle.light
	cycle.start_hour = Tuning.DAY_START_HOUR
	cycle.enter(120.0)
	var steps := _distance(from, Color.WHITE) / (Tuning.LIGHT_MAX_RATE * DELTA)
	var frames := 0
	var astray := 0.0
	while cycle.light != Color.WHITE and frames <= ceili(steps) + 1:
		cycle.advance(DELTA)
		frames += 1
		var low := INF
		var high := -INF
		for c: int in 3:
			var share: float = (cycle.light[c] - from[c]) / (1.0 - from[c])
			low = minf(low, share)
			high = maxf(high, share)
		astray = maxf(astray, high - low)
	assert_between(frames, floori(steps), ceili(steps) + 1, "frames to the morning's light")
	assert_almost_eq(astray, 0.0, 1e-4, "off the straight way")
	var off := 0
	for _frame: int in ceili(120.0 / DELTA):
		cycle.advance(DELTA)
		off += int(cycle.light != cycle.target())
	assert_eq(off, 0, "frames off the light of the hour, a day long")


func test_snap_shows_the_light_of_the_hour_at_once() -> void:
	for start: float in [0.0, 5.0, 6.5, 12.0, 18.0, 19.0, 22.0]:
		var cycle := DayCycle.new()
		cycle.start_hour = start
		cycle.enter(120.0)
		cycle.snap()
		assert_eq(cycle.light, DayCycle.light_at(start), "at %.1f" % start)


func test_least_day_seconds_is_the_shortest_day_the_rate_can_follow() -> void:
	# At the least day, the light of the hour changes by no more than the rate allows in a frame;
	# in a shorter day it changes by more.
	var reach := Tuning.LIGHT_MAX_RATE * DELTA
	var least := DayCycle.least_day_seconds()
	for scale: float in [1.0, 0.95]:
		var day := least * scale
		var cycle := _cycle(day)
		var steepest := 0.0
		for _frame: int in ceili(day / DELTA):
			var was := cycle.target()
			cycle.advance(DELTA)
			steepest = maxf(steepest, _distance(was, cycle.target()))
		if scale == 1.0:
			assert_lte(steepest, reach + 1e-6, "at the least day, %.2f s" % day)
		else:
			assert_gt(steepest, reach, "in %.2f s" % day)


func test_a_day_of_no_seconds_is_an_error_and_stops_the_clock() -> void:
	# Nor of seconds that aren't finite: with NaN the light would be NaN, and with INF the clock
	# would stand still unreported (N8, N36).
	for day: float in [0.0, -5.0, NAN, INF, -INF]:
		var cycle := _cycle(day)
		assert_push_error("DayCycle: a day of %.2f s" % day)
		cycle.advance(10.0)
		assert_eq(cycle.hour(), Tuning.DAY_START_HOUR, "%.0f s: the clock stands still" % day)


## How far a pixel of height casts its shadow on the ground, in pixels of height: the screen
## foreshortens the ground, so measured in tiles.
static func _ground_length(shadow: Vector2) -> float:
	return Iso.world_to_tile(shadow).length() * Iso.HEIGHT_PX


func test_shadows_sweep_from_the_right_to_the_left_in_front_of_what_casts_them() -> void:
	# The sun by day and the moon by night cross the sky from the screen's left, through its top, to
	# its right (DAYNIGHT_PLAN.md §5.11). So the shadows sweep from the right, through straight
	# down, to the left, and never fall up the screen, behind what casts them, where they'd hide.
	var rises: Array[float] = [Tuning.SUN_RISE_HOUR, Tuning.SUN_SET_HOUR]
	var sets: Array[float] = [Tuning.SUN_SET_HOUR, Tuning.SUN_RISE_HOUR + 24.0]
	for i: int in 2:
		var span := sets[i] - rises[i]
		var was := INF
		var astray := PackedStringArray()
		for step: int in range(1, 96):
			var hour := rises[i] + span * step / 96.0
			var shadow := DayCycle.shadow_at(hour)
			if shadow.y < 0.0 or shadow.x >= was:
				astray.append("%.2f" % hour)
			was = shadow.x
		assert_eq(astray, PackedStringArray(), "hours that turn back or fall behind")
		assert_gt(DayCycle.shadow_at(rises[i] + 1.0).x, 0.0, "an hour after %.0f, right" % rises[i])
		assert_almost_eq(DayCycle.shadow_at(rises[i] + span / 2.0).x, 0.0, 1e-6, "highest, down")
		assert_lt(DayCycle.shadow_at(sets[i] - 1.0).x, 0.0, "an hour before %.0f, left" % sets[i])


func test_a_shadow_is_as_long_as_the_light_is_low_up_to_the_longest() -> void:
	# A pixel of height casts its shadow 1 / tan(h) pixels away, h being how high the sun or the
	# moon stands: at its highest at noon and midnight, and SHADOW_LONGEST as it rises and sets.
	var noon := (Tuning.SUN_RISE_HOUR + Tuning.SUN_SET_HOUR) / 2.0
	var noon_length := _ground_length(DayCycle.shadow_at(noon))
	assert_almost_eq(noon_length, 1.0 / tan(Tuning.SUN_HIGHEST), 1e-5, "at noon")
	var midnight_length := _ground_length(DayCycle.shadow_at(noon + 12.0))
	assert_almost_eq(midnight_length, 1.0 / tan(Tuning.MOON_HIGHEST), 1e-5, "at midnight")
	var longest := 0.0
	for step: int in 24 * 16:
		longest = maxf(longest, _ground_length(DayCycle.shadow_at(step / 16.0)))
	assert_almost_eq(longest, Tuning.SHADOW_LONGEST, 1e-5, "the longest")
	for hour: float in [Tuning.SUN_RISE_HOUR + 0.1, Tuning.SUN_SET_HOUR + 0.1]:
		var low := _ground_length(DayCycle.shadow_at(hour))
		assert_almost_eq(low, Tuning.SHADOW_LONGEST, 1e-5, "%.1f" % hour)


func test_shadows_fade_out_as_the_sun_sets_and_in_as_the_moon_rises() -> void:
	# Where the moon takes over from the sun, and back, both stand on the ground and cast none, so
	# the shadows jump from the left to the right unseen. The moon's are fainter.
	var noon := (Tuning.SUN_RISE_HOUR + Tuning.SUN_SET_HOUR) / 2.0
	assert_almost_eq(DayCycle.shadow_alpha_at(noon), Tuning.SUN_SHADOW_ALPHA, 1e-6, "noon")
	assert_almost_eq(DayCycle.shadow_alpha_at(noon + 12.0), Tuning.MOON_SHADOW_ALPHA, 1e-6)
	for hour: float in [Tuning.SUN_RISE_HOUR, Tuning.SUN_SET_HOUR]:
		for near: float in [-0.1, 0.0, 0.1]:
			assert_eq(DayCycle.shadow_alpha_at(hour + near), 0.0, "at %.1f" % (hour + near))
	assert_gt(DayCycle.shadow_alpha_at(Tuning.SUN_RISE_HOUR + 1.0), 0.0, "an hour after sunrise")
	assert_gt(DayCycle.shadow_alpha_at(Tuning.SUN_SET_HOUR + 1.0), 0.0, "an hour after moonrise")


func test_the_shadows_shown_follow_the_hour_exactly_in_the_least_day_too() -> void:
	# In a day of least_day_seconds() too, the sun and the moon move them by no more than
	# SHADOW_MAX_RATE a frame, and their alpha by no more than SHADOW_ALPHA_RATE, so the shadows
	# shown are the hour's from the snap on. They jump only where they are unseen.
	var sweep := Tuning.SHADOW_MAX_RATE * DELTA
	for day: float in [120.0, DayCycle.least_day_seconds()]:
		var cycle := _cycle(day)
		var off := 0
		var seen_jumps := 0
		for _frame: int in ceili(day / DELTA):
			var was := cycle.shadow
			var was_alpha := cycle.shadow_alpha
			cycle.advance(DELTA)
			var hour := cycle.hour()
			var fall := DayCycle.shadow_at(hour)
			off += int(cycle.shadow != fall or cycle.shadow_alpha != DayCycle.shadow_alpha_at(hour))
			seen_jumps += int(was.distance_to(cycle.shadow) > sweep and was_alpha > 0.0)
		assert_eq(off, 0, "frames off the hour's shadows, in %.2f s" % day)
		assert_eq(seen_jumps, 0, "jumps that show, in %.2f s" % day)


func test_after_a_reset_the_shadows_fade_out_jump_unseen_and_fade_in() -> void:
	# At 17:00 the shadows fall far to the left. A new zone's clock is back at 07:00, where they
	# fall far to the right: too far to sweep. They fade out at SHADOW_ALPHA_RATE as they turn
	# toward the hour's at SHADOW_MAX_RATE, jump to it unseen, fade in, and then follow it.
	var start := 7.0
	var cycle := _cycle(120.0, start)
	for _frame: int in ceili(120.0 * 10.0 / 24.0 / DELTA):
		cycle.advance(DELTA)
	assert_lt(cycle.shadow.x, -1.0, "at 17:00, far to the left")
	cycle.enter(120.0)
	assert_gt(DayCycle.shadow_at(cycle.hour()).x, 1.0, "at 07:00, far to the right")
	var fade := Tuning.SHADOW_ALPHA_RATE * DELTA + 1e-9
	# Vector2 is single precision: a shadow 2.7 pixels long is stored to within 2.4e-7.
	var sweep := Tuning.SHADOW_MAX_RATE * DELTA + 1e-5
	var frames := 0
	var unseen := false
	var too_fast := 0
	while frames < 600:
		var hour := cycle.hour()
		if cycle.shadow == DayCycle.shadow_at(hour) and unseen:
			if cycle.shadow_alpha == DayCycle.shadow_alpha_at(hour):
				break
		var was := cycle.shadow
		var was_alpha := cycle.shadow_alpha
		cycle.advance(DELTA)
		frames += 1
		too_fast += int(absf(cycle.shadow_alpha - was_alpha) > fade)
		too_fast += int(was.distance_to(cycle.shadow) > sweep and was_alpha > 0.0)
		unseen = unseen or cycle.shadow_alpha == 0.0
	assert_true(unseen, "they faded out")
	assert_eq(too_fast, 0, "frames that change too fast, or jump where they show")
	assert_lt(frames, ceili(2.0 * Tuning.SUN_SHADOW_ALPHA / fade) + 1, "frames to catch up")
	var off := 0
	for _frame: int in ceili(120.0 / DELTA):
		cycle.advance(DELTA)
		off += int(cycle.shadow != DayCycle.shadow_at(cycle.hour()))
	assert_eq(off, 0, "frames off the hour's shadow, a day long")
