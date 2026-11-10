extends GutTest
## PropScatter (M5_PLAN.md §5.6, L2): each row of the path gets its props PROP_AHEAD path tiles
## before the car, and loses them with its path tile. The rows below the start get theirs at once.

const Fixtures := preload("res://tests/helpers/road_fixtures.gd")
const DELTA := 1.0 / 60.0

var _layer: Node2D


func before_each() -> void:
	_layer = add_child_autofree(Node2D.new())


func _buffer(run_seed: int, schedule: AreaSchedule) -> RoadBuffer:
	return RoadBuffer.new(RoadGenerator.new(run_seed, schedule))


## The rows from `first` to `last`.
func _rows(first: int, last: int) -> Array[int]:
	var rows: Array[int] = []
	rows.assign(range(first, last + 1))
	return rows


## A prop of 8 × 8-pixel frames, side by side on a sheet of its own.
func _prop(id: StringName, frames: int, fps: float, density: float) -> PropDef:
	var def := PropDef.new()
	def.id = id
	var image := Image.create_empty(8 * frames, 8, false, Image.FORMAT_RGBA8)
	def.texture = ImageTexture.create_from_image(image)
	def.region = Rect2i(0, 0, 8, 8)
	def.frames = frames
	def.fps = fps
	def.foot = Vector2i(4, 8)
	def.density = density
	return def


## The schedule of one area with `props`, which a test may change.
func _schedule(props: Array[PropDef]) -> AreaSchedule:
	var schedule := Fixtures.dense_schedule()
	schedule.entries[0].area.props = props
	return schedule


func _shown(scatter: PropScatter) -> int:
	var shown := 0
	for k: int in scatter.rows():
		shown += scatter.sprites(k).size()
	return shown


## Each row's props, as their sprites show them, but for their frame.
func _described(scatter: PropScatter) -> Array:
	var described := []
	for k: int in scatter.rows():
		var row := [k]
		for sprite: Sprite2D in scatter.sprites(k):
			row.append([sprite.texture, sprite.region_rect, sprite.hframes, sprite.position])
		described.append(row)
	return described


func test_the_rows_below_the_start_show_first_and_the_roads_rows_with_it() -> void:
	var schedule := Fixtures.schedule()
	var scatter := PropScatter.new(_layer, schedule)
	var buffer := _buffer(3, schedule)
	scatter.bind(buffer)
	assert_eq(scatter.rows(), _rows(-Tuning.BUFFER_BEHIND, -1 - PropLayout.rows_needed()))
	buffer.start()
	assert_eq(scatter.rows(), _rows(-Tuning.BUFFER_BEHIND, Tuning.PROP_AHEAD))
	assert_gt(_shown(scatter), 10 * scatter.rows().size(), "the city's props")
	assert_eq(scatter.pool.made, _shown(scatter))


func test_rows_show_props_ahead_of_the_car_and_lose_them_with_their_path_tile() -> void:
	var schedule := Fixtures.schedule()
	var scatter := PropScatter.new(_layer, schedule)
	var buffer := _buffer(5, schedule)
	scatter.bind(buffer)
	buffer.start()
	var wrong := PackedStringArray()
	var most_shown := 0
	var largest_row := 0
	for index: int in range(1, 700):
		buffer.on_car_path_index(index)
		scatter.update(DELTA)
		# While the buffer has path tile 0, it has the rows below it too.
		var lowest := buffer.first_index()
		if lowest == 0:
			lowest = -Tuning.BUFFER_BEHIND
		if scatter.rows() != _rows(lowest, index + Tuning.PROP_AHEAD):
			wrong.append("car on %d: rows %s" % [index, scatter.rows()])
		most_shown = maxi(most_shown, _shown(scatter))
		for k: int in scatter.rows():
			largest_row = maxi(largest_row, scatter.sprites(k).size())
	assert_eq(wrong.slice(0, 3), PackedStringArray(), "%d steps wrong" % wrong.size())
	assert_gt(buffer.generator.turn_count, 100, "past the tunnel and the bridge")
	# A step shows a row before it hides one, so the pool needs one row more than ever shows.
	assert_lte(scatter.pool.made, most_shown + largest_row, "the sprites are reused")
	assert_eq(scatter.pool.hidden() + _shown(scatter), scatter.pool.made, "none lost")
	assert_eq(_layer.get_child_count(), scatter.pool.made)


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
	assert_eq(jumped.rows(), stepped.rows())
	assert_eq(_described(jumped), _described(stepped))


func test_a_new_buffer_takes_the_sprites_of_the_last() -> void:
	var schedule := Fixtures.schedule()
	var scatter := PropScatter.new(_layer, schedule)
	var old := _buffer(1, schedule)
	scatter.bind(old)
	old.start()
	for index: int in range(1, 40):
		old.on_car_path_index(index)
		scatter.update(DELTA)
	var made := scatter.pool.made
	var fresh := _buffer(2, schedule)
	scatter.bind(fresh)
	var below_start := _rows(-Tuning.BUFFER_BEHIND, -1 - PropLayout.rows_needed())
	assert_eq(scatter.rows(), below_start)
	assert_eq(scatter.pool.made, made, "no new sprites")
	assert_eq(scatter.pool.hidden(), made - _shown(scatter), "the old rows' sprites are hidden")
	assert_eq(old.tiles_generated.get_connections().size(), 0)
	assert_eq(old.tiles_freed.get_connections().size(), 0)
	old.on_car_path_index(80)
	scatter.update(DELTA)
	assert_eq(scatter.rows(), below_start, "the old road changes nothing")
	fresh.start()
	assert_eq(scatter.rows(), _rows(-Tuning.BUFFER_BEHIND, Tuning.PROP_AHEAD))


func test_animated_props_step_through_their_frames_at_their_fps() -> void:
	var props: Array[PropDef] = [_prop(&"still", 1, 0.0, 0.05), _prop(&"turning", 4, 4.0, 0.1)]
	var schedule := _schedule(props)
	var scatter := PropScatter.new(_layer, schedule)
	var buffer := _buffer(1, schedule)
	scatter.bind(buffer)
	buffer.start()
	var turning: Array[Sprite2D] = []
	var still: Array[Sprite2D] = []
	for k: int in scatter.rows():
		for sprite: Sprite2D in scatter.sprites(k):
			if sprite.hframes == 4:
				turning.append(sprite)
			else:
				still.append(sprite)
	assert_gt(mini(turning.size(), still.size()), 20, "props of each")
	var first: Array[int] = []
	for sprite: Sprite2D in turning:
		first.append(sprite.frame)
	assert_eq(_distinct(first), 4, "each starts on a frame of its own")
	for step: int in range(1, 9):
		# A quarter of a second: a frame at 4 fps.
		scatter.update(0.25)
		var wrong := 0
		for i: int in turning.size():
			wrong += 0 if turning[i].frame == (first[i] + step) % 4 else 1
		for sprite: Sprite2D in still:
			wrong += 0 if sprite.frame == 0 else 1
		assert_eq(wrong, 0, "frames after %d steps" % step)


static func _distinct(values: Array[int]) -> int:
	var seen: Dictionary[int, bool] = {}
	for value: int in values:
		seen[value] = true
	return seen.size()


func test_props_that_break_the_contract_are_errors_and_do_not_show() -> void:
	var good := _prop(&"good", 1, 0.0, 0.6)
	var blank := _prop(&"blank", 1, 0.0, 0.1)
	blank.texture = null
	# Copilot's review of #43: no frames fitted in any texture, and gave its sprites hframes = 0.
	var frameless := _prop(&"frameless", 1, 0.0, 0.1)
	frameless.frames = 0
	var crowding := _prop(&"crowding", 1, 0.0, 0.5)
	var props: Array[PropDef] = [good, null, blank, frameless, crowding]
	var schedule := _schedule(props)
	var scatter := PropScatter.new(_layer, schedule)
	assert_push_error("PropScatter: dense: a prop is null")
	assert_push_error("PropScatter: dense: prop blank has no texture")
	assert_push_error("PropScatter: dense: prop frameless has 0 frames")
	assert_push_error("PropScatter: dense: prop crowding takes the densities past 1")
	var buffer := _buffer(1, schedule)
	scatter.bind(buffer)
	buffer.start()
	var others := 0
	for k: int in scatter.rows():
		for sprite: Sprite2D in scatter.sprites(k):
			others += 0 if sprite.texture == good.texture else 1
	assert_gt(_shown(scatter), 100, "the good prop shows")
	assert_eq(others, 0, "and no other")


func test_the_props_take_nothing_from_the_road() -> void:
	var schedule := Fixtures.schedule()
	var plain := _buffer(6, schedule)
	plain.start()
	var scattered := _buffer(6, schedule)
	var scatter := PropScatter.new(_layer, schedule)
	scatter.bind(scattered)
	scattered.start()
	for index: int in range(1, 150):
		plain.on_car_path_index(index)
		scattered.on_car_path_index(index)
		scatter.update(DELTA)
	var expected := []
	for tile: RoadTile in plain.tiles():
		expected.append(Fixtures.signature(tile))
	var found := []
	for tile: RoadTile in scattered.tiles():
		found.append(Fixtures.signature(tile))
	assert_eq(found, expected)
	assert_eq(scattered.generator.turn_count, plain.generator.turn_count)
