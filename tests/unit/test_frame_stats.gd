extends GutTest


func test_even_frames_and_the_next_window() -> void:
	var stats := FrameStats.new()
	for index: int in 50:
		assert_eq(stats.add(20004), index == 49)
	assert_almost_eq(stats.fps(), 49.990002, 0.000001)
	assert_eq(stats.usec(), 1000200)
	assert_eq(stats.count(), 50)
	assert_eq(stats.median_ms(), 20.004)
	assert_eq(stats.p95_ms(), 20.004)
	assert_eq(stats.longest_ms(), 20.004)
	assert_false(stats.add(16667))
	assert_eq(stats.count(), 1)
	assert_eq(stats.usec(), 16667)


func test_p95_is_the_nearest_rank_with_five_then_six_long_frames() -> void:
	for long_frames: int in [5, 6]:
		var stats := FrameStats.new()
		for index: int in 100:
			stats.add(5000 if index < 100 - long_frames else 100000)
		assert_eq(stats.p95_ms(), 5.0 if long_frames == 5 else 100.0)
		assert_eq(stats.median_ms(), 5.0)
		assert_eq(stats.longest_ms(), 100.0)


func test_early_frames_use_a_strict_boundary_and_the_median_can_be_between_frames() -> void:
	var stats := FrameStats.new()
	for interval: int in [12499, 12500, 12501, 20000]:
		stats.add(interval)
	assert_eq(stats.early(), 1)
	assert_eq(stats.median_ms(), 12.5005)


func test_an_invalid_interval_reports_the_error_and_keeps_the_window() -> void:
	var stats := FrameStats.new()
	stats.add(20000)
	assert_false(stats.add(-1))
	assert_false(stats.add(-2))
	assert_push_error_count(2)
	assert_eq(stats.count(), 1)
	assert_eq(stats.usec(), 20000)


func test_equal_frame_starts_are_counted_with_their_zero_interval() -> void:
	var stats := FrameStats.new()
	stats.add(0)
	for index: int in 50:
		stats.add(20000)
	assert_eq(stats.count(), 51)
	assert_eq(stats.usec(), 1000000)
	assert_eq(stats.fps(), 51.0)
	assert_eq(stats.early(), 1)
