extends GutTest
## Beats (M6_PLAN.md S7, §5.2): a legend's beats on one clock, which ends when their lengths say,
## whatever steps it takes, and lists each beat's end once, even one that a step skipped.

const DELTA := 1.0 / 60.0


func test_the_index_and_the_progress_follow_the_beats() -> void:
	var beats := Beats.new([0.5, 0.25] as Array[float], 0.125)
	assert_eq(beats.index(), -1, "before the start")
	assert_eq(beats.progress(0), 0.0)
	beats.advance(0.125)
	assert_eq(beats.index(), 0, "at the start")
	assert_eq(beats.progress(0), 0.0)
	beats.advance(0.25)
	assert_eq([beats.index(), beats.progress(0), beats.progress(1)], [0, 0.5, 0.0], "halfway")
	beats.advance(0.375)
	assert_eq([beats.index(), beats.progress(0), beats.progress(1)], [1, 1.0, 0.5], "the second")
	assert_false(beats.done())
	beats.advance(0.125)
	assert_eq([beats.index(), beats.progress(1)], [2, 1.0], "all of them")
	assert_true(beats.done())


func test_beats_at_60_hz_end_within_a_frame_of_their_total() -> void:
	# A beat that starts on the frame after its start would add up a frame's lag per beat (N11).
	var lengths: Array[float] = [0.6, 0.41, 0.63, 0.57, 0.33]
	for start: float in [0.1, 0.27, 0.5]:
		var beats := Beats.new(lengths, start)
		var frames := 0
		while not beats.done() and frames < 600:
			beats.advance(DELTA)
			frames += 1
		var why := "from %.2f s" % start
		assert_almost_eq(frames * DELTA, start + Beats.total(lengths), DELTA * 1.01, why)


func test_a_clock_with_long_steps_ends_on_the_step_that_reaches_the_total() -> void:
	var beats := Beats.new([0.5, 0.25, 0.4] as Array[float], 0.1)
	var steps := 0
	while not beats.done() and steps < 100:
		beats.advance(0.07)
		steps += 1
	assert_eq(steps, 18, "1.26 s, the first step past 1.25")


func test_ended_lists_each_beat_once_in_order_even_one_skipped() -> void:
	# A legend shows each beat's end, so a step must not lose one (N12).
	var beats := Beats.new([0.125, 0.125, 0.125, 0.125] as Array[float], 0.25)
	beats.advance(0.125)
	assert_eq(beats.ended(), [] as Array[int], "before the start")
	beats.advance(0.375)
	assert_eq(beats.ended(), [0, 1] as Array[int], "a step over the first two")
	assert_eq(beats.ended(), [] as Array[int], "once")
	beats.advance(0.0625)
	assert_eq(beats.ended(), [] as Array[int], "within the third")
	beats.advance(1.0)
	assert_eq(beats.ended(), [2, 3] as Array[int], "a step past the end")
	assert_eq(beats.ended(), [] as Array[int], "once")


func test_beats_of_no_length_and_no_beats() -> void:
	var beats := Beats.new([0.0, 0.5, 0.0] as Array[float], 0.25)
	beats.advance(0.25)
	assert_eq([beats.index(), beats.progress(0)], [1, 1.0], "the first beat is over at once")
	assert_eq(beats.ended(), [0] as Array[int])
	beats.advance(0.5)
	assert_eq([beats.index(), beats.progress(2)], [3, 1.0], "and the last")
	assert_eq(beats.ended(), [1, 2] as Array[int])
	assert_true(beats.done())
	var none := Beats.new([] as Array[float], 0.25)
	assert_eq(Beats.total([] as Array[float]), 0.0)
	none.advance(0.125)
	assert_false(none.done(), "before the start")
	none.advance(0.125)
	assert_true(none.done(), "at the start")
	assert_eq(none.ended(), [] as Array[int])


func test_the_beats_are_done_exactly_at_their_total() -> void:
	var lengths: Array[float] = [0.5, 0.25]
	var at_end := Beats.new(lengths, 0.125)
	at_end.advance(0.875)
	assert_true(at_end.done(), "at 0.875 s")
	var before := Beats.new(lengths, 0.125)
	before.advance(0.875 - 1e-9)
	assert_false(before.done(), "just before")
	assert_eq(before.index(), 1)
