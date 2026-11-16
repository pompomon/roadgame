extends GutTest
## SeeThrough (docs/VISUALS.md §5.9): a see-through prop, such as the City's building, shows
## PROP_SEE_THROUGH of itself where it would hide the car, as the tunnel does (docs/M4.md K5), and
## comes back as they part, with no jump as the car comes in front of it.

const Fixtures := preload("res://tests/helpers/road_fixtures.gd")
## A building's frame, with its foot on (0, 0).
const FRAME := Rect2(-21, -57, 42, 58)
const ROUNDING := 1e-6


## A rect of the car's body's size, 36 × 28 pixels, with its top left corner on `at`.
static func _body(at: Vector2) -> Rect2:
	return Rect2(at, Vector2(36, 28))


func test_a_prop_shows_little_of_itself_over_the_car_and_comes_back_as_they_part() -> void:
	# The car up the screen behind the prop, then sliding out to its right a pixel at a time.
	var behind := -32.0
	var over := SeeThrough.opacity(FRAME, 0.0, _body(Vector2(-18, -50)), behind)
	assert_almost_eq(over, Tuning.PROP_SEE_THROUGH, ROUNDING, "over the car")
	var last := over
	var rising := 0
	for gap: int in range(1, int(Tuning.PROP_FADE_PX) + 1):
		var alpha := SeeThrough.opacity(FRAME, 0.0, _body(Vector2(FRAME.end.x + gap, -50)), behind)
		rising += int(alpha > last)
		last = alpha
	assert_eq(rising, int(Tuning.PROP_FADE_PX), "more of it at each pixel apart")
	assert_almost_eq(last, 1.0, ROUNDING, "whole PROP_FADE_PX apart")
	var half := Tuning.PROP_FADE_PX * 0.5
	var midway := lerpf(Tuning.PROP_SEE_THROUGH, 1.0, 0.5)
	var across := SeeThrough.opacity(FRAME, 0.0, _body(Vector2(FRAME.end.x + half, -50)), behind)
	assert_almost_eq(across, midway, ROUNDING, "half of that apart, smoothly")
	# Apart across and up together: the two gaps add up.
	var quarter := half * 0.5
	var corner := FRAME.position - Vector2(quarter, quarter) - _body(Vector2.ZERO).size
	var diagonal := SeeThrough.opacity(FRAME, 0.0, _body(corner), corner.y)
	assert_almost_eq(diagonal, midway, ROUNDING, "a quarter across and a quarter up")


func test_it_changes_little_as_the_car_comes_in_front_and_is_whole_once_well_in_front() -> void:
	# Props y-sorts: the prop draws over an actor while the actor's y is above its foot's, and the
	# actor over it after (docs/VISUALS.md A9). An actor as tall as a legend's standing part comes
	# down past the prop's foot a pixel at a time: the prop shows as much of itself either side of
	# the tie, and is whole once the actor is PROP_FADE_PX in front, though their rects still meet.
	var steps := PackedFloat32Array()
	var largest := 0.0
	var last := -1.0
	for y: int in range(-20, int(Tuning.PROP_FADE_PX) + 11):
		var standing := Rect2(-18, y - 76, 36, 80)
		var alpha := SeeThrough.opacity(FRAME, 0.0, standing, float(y))
		steps.append(alpha)
		if last >= 0.0:
			largest = maxf(largest, absf(alpha - last))
		last = alpha
		assert_true(standing.intersects(FRAME), "their rects meet at y %d" % y)
	assert_almost_eq(steps[19], Tuning.PROP_SEE_THROUGH, ROUNDING, "a pixel behind")
	assert_almost_eq(steps[20 + int(Tuning.PROP_FADE_PX)], 1.0, ROUNDING, "well in front")
	assert_lt(largest, 0.1, "no jump at the tie, nor anywhere")


func test_the_rows_it_names_hold_every_prop_that_may_fade() -> void:
	# The tallest and lowest frames that the contract allows (PROP_MAX_SIZE, PROP_BELOW), on every
	# ground cell of each row near x 0, against rects that cover x 0, wherever they sort.
	var size := Tuning.PROP_MAX_SIZE + Vector2i(0, Tuning.PROP_BELOW)
	var tallest := PropDef.new()
	tallest.region = Rect2i(Vector2i.ZERO, size)
	@warning_ignore("integer_division")
	tallest.foot = Vector2i(size.x / 2, Tuning.PROP_MAX_SIZE.y)
	tallest.density = 1.0
	var props: Array[PropDef] = [tallest]
	var buffer := RoadBuffer.new(RoadGenerator.new(1, Fixtures.schedule()))
	var frames: Dictionary[int, Array] = {}
	for k: int in range(-20, 21):
		frames[k] = []
		for placement: PropLayout.Placement in PropLayout.row(Vector2i(0, -k), props, 1, buffer):
			if absf(placement.foot.x) < 100.0:
				frames[k].append(Rect2(placement.foot - Vector2(tallest.foot), Vector2(size)))
	var missed := PackedStringArray()
	var widest := 0
	for y: int in range(-300, 301, 11):
		for height: int in [1, 28, 90]:
			var rect := Rect2(-10, y, 20, height)
			var near := SeeThrough.rows(rect)
			var fading := 0
			for k: int in frames:
				var fades := false
				for frame: Rect2 in frames[k]:
					var foot_y := frame.position.y + tallest.foot.y
					fades = fades or SeeThrough.opacity(frame, foot_y, rect, -INF) < 1.0
				fading += int(fades)
				if fades and (k < near.x or k > near.y):
					missed.append("%s: row %d, not in %s" % [rect, k, near])
			widest = maxi(widest, near.y - near.x + 1 - fading)
	assert_eq(missed.slice(0, 5), PackedStringArray(), "%d rows missed" % missed.size())
	assert_lte(widest, 2, "a row more than needed at either end at most")
