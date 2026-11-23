extends GutTest
## Deferred row retirement (PERF_PLAN.md §5.3).

const Fixtures := preload("res://tests/helpers/road_fixtures.gd")
const DELTA := 1.0 / 60.0

var _layer: Node2D


func before_each() -> void:
	_layer = add_child_autofree(Node2D.new())


func _buffer(run_seed: int, schedule: AreaSchedule) -> RoadBuffer:
	return RoadBuffer.new(RoadGenerator.new(run_seed, schedule))


func _rows(first: int, last: int) -> Array[int]:
	var rows: Array[int] = []
	rows.assign(range(first, last + 1))
	return rows


func _waiting(scatter: PropScatter, first: int) -> Array[int]:
	var waiting: Array[int] = []
	for k: int in scatter.rows():
		if k < first:
			waiting.append(k)
	return waiting


func _described(scatter: PropScatter) -> Array:
	var described := []
	for k: int in scatter.rows():
		var row := [k]
		for sprite: Sprite2D in scatter.sprites(k):
			row.append([sprite.texture, sprite.region_rect, sprite.hframes, sprite.position])
		described.append(row)
	return described


func test_a_seed_shows_the_same_props_however_the_car_got_there() -> void:
	var schedule := Fixtures.schedule()
	var stepped := PropScatter.new(_layer, schedule)
	var stepped_buffer := _buffer(9, schedule)
	stepped.bind(stepped_buffer)
	stepped_buffer.start()
	for index: int in range(1, 121):
		stepped_buffer.on_car_path_index(index)
		stepped.update(DELTA)
	var jumped := PropScatter.new(add_child_autofree(Node2D.new()), schedule)
	var jumped_buffer := _buffer(9, schedule)
	jumped.bind(jumped_buffer)
	jumped_buffer.start()
	jumped_buffer.on_car_path_index(120)
	jumped.update(1.0)
	for step: int in jumped.rows().size() + 1:
		if jumped._lowest_row >= jumped._hide_below:
			break
		jumped.update(DELTA)
	assert_eq(jumped.rows(), stepped.rows())
	assert_eq(_described(jumped), _described(stepped))


func test_a_free_waits_for_updates_and_retires_at_most_two_rows_each() -> void:
	var schedule := Fixtures.schedule()
	var scatter := PropScatter.new(_layer, schedule)
	var buffer := _buffer(5, schedule)
	scatter.bind(buffer)
	buffer.start()
	buffer.on_car_path_index(Tuning.BUFFER_BEHIND + 1)
	var waiting := _waiting(scatter, buffer.first_index())
	assert_eq(waiting, _rows(-Tuning.BUFFER_BEHIND, 0), "none retired in the free handler")
	assert_gt(waiting.size(), Tuning.HIDE_ROWS_PER_FRAME)
	for step: int in ceili(float(waiting.size()) / Tuning.HIDE_ROWS_PER_FRAME):
		var before := _waiting(scatter, buffer.first_index())
		scatter.update(DELTA)
		var removed := mini(Tuning.HIDE_ROWS_PER_FRAME, before.size())
		assert_eq(_waiting(scatter, buffer.first_index()), before.slice(removed))
	assert_eq(_waiting(scatter, buffer.first_index()), [])


func test_freed_rows_go_lowest_first_within_their_bound_when_frees_overlap() -> void:
	var schedule := Fixtures.schedule()
	var scatter := PropScatter.new(_layer, schedule)
	var buffer := _buffer(5, schedule)
	scatter.bind(buffer)
	buffer.start()
	buffer.on_car_path_index(Tuning.BUFFER_BEHIND + 1)
	var due: Dictionary[int, int] = {}
	for frame: int in range(1, 17):
		if frame == 3:
			buffer.on_car_path_index(Tuning.BUFFER_BEHIND + 5)
		var waiting := _waiting(scatter, buffer.first_index())
		for index: int in waiting.size():
			var k := waiting[index]
			if not due.has(k):
				due[k] = frame - 1 + ceili(float(index + 1) / Tuning.HIDE_ROWS_PER_FRAME)
		scatter.update(DELTA)
		assert_eq(
			_waiting(scatter, buffer.first_index()),
			waiting.slice(mini(waiting.size(), Tuning.HIDE_ROWS_PER_FRAME)),
			"lowest first, frame %d" % frame
		)
		for k: int in due:
			if due[k] <= frame:
				assert_false(scatter.rows().has(k), "row %d due by frame %d" % [k, due[k]])
	assert_eq(due.size(), Tuning.BUFFER_BEHIND + 5, "the overlapping frees were counted")


func test_rows_below_zero_stay_while_the_buffer_holds_tile_zero() -> void:
	var schedule := Fixtures.schedule()
	var scatter := PropScatter.new(_layer, schedule)
	var buffer := _buffer(5, schedule)
	scatter.bind(buffer)
	buffer.start()
	buffer.on_car_path_index(Tuning.BUFFER_BEHIND)
	for frame: int in 12:
		scatter.update(DELTA)
		assert_eq(_waiting(scatter, 0), _rows(-Tuning.BUFFER_BEHIND, -1))


func test_a_waiting_row_keeps_its_anchor_after_its_path_tile_is_freed() -> void:
	var schedule := Fixtures.schedule()
	var scatter := PropScatter.new(_layer, schedule)
	var buffer := _buffer(5, schedule)
	scatter.bind(buffer)
	buffer.start()
	var at := scatter.anchor(0)
	buffer.on_car_path_index(Tuning.BUFFER_BEHIND + 1)
	scatter.update(DELTA)
	assert_gt(buffer.first_index(), 0)
	assert_true(scatter.rows().has(0), "the row still waits")
	assert_eq(scatter.anchor(0), at, "without reading its freed tile")


func test_rebinding_a_nonzero_buffer_resets_the_retirement_target() -> void:
	var schedule := Fixtures.schedule()
	var scatter := PropScatter.new(_layer, schedule)
	var old := _buffer(5, schedule)
	scatter.bind(old)
	old.start()
	old.on_car_path_index(120)
	var fresh := _buffer(6, schedule)
	fresh.start()
	fresh.on_car_path_index(50)
	scatter.bind(fresh)
	var shown := scatter.rows()
	scatter.update(DELTA)
	assert_eq(scatter.rows(), shown, "none of the fresh buffer's rows is freed")
	assert_eq(shown[0], fresh.first_index())
