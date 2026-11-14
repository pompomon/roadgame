extends GutTest

const Fixtures := preload("res://tests/helpers/road_fixtures.gd")

var _live: Dictionary[RoadTile, bool] = {}
var _freed_twice := 0


func _buffer(run_seed: int) -> RoadBuffer:
	_live.clear()
	_freed_twice = 0
	var buffer := RoadBuffer.new(RoadGenerator.new(run_seed, Fixtures.schedule()))
	buffer.tiles_generated.connect(_on_generated)
	buffer.tiles_freed.connect(_on_freed)
	return buffer


func _on_generated(tiles: Array[RoadTile]) -> void:
	for tile: RoadTile in tiles:
		_live[tile] = true


func _on_freed(tiles: Array[RoadTile]) -> void:
	for tile: RoadTile in tiles:
		if not _live.erase(tile):
			_freed_twice += 1


func test_start_generates_buffer_ahead() -> void:
	var buffer := _buffer(1)
	buffer.start()
	assert_eq(buffer.first_index(), 0)
	assert_eq(buffer.last_index(), Tuning.BUFFER_AHEAD)
	assert_eq(buffer.lookahead(), Tuning.BUFFER_AHEAD)
	assert_eq(_live.size(), buffer.tiles().size())


func test_lookahead_stays_between_refill_and_ahead_fuzzed() -> void:
	var rng := RandomNumberGenerator.new()
	for run_seed: int in 20:
		rng.seed = run_seed
		var buffer := _buffer(run_seed)
		buffer.start()
		var car := 0
		for step: int in 400:
			# Mostly small steps, sometimes a big jump or a step back (rejoining behind).
			car = maxi(0, car + rng.randi_range(-2, 3 if step % 50 else 40))
			buffer.on_car_path_index(car)
			var look := buffer.lookahead()
			if look < Tuning.BUFFER_REFILL_AT or look > Tuning.BUFFER_AHEAD:
				fail_test("seed %d step %d: lookahead %d" % [run_seed, step, look])
				return
			var behind := buffer.car_index() - buffer.first_index()
			if behind > Tuning.BUFFER_BEHIND:
				fail_test("seed %d step %d: %d tiles behind" % [run_seed, step, behind])
				return
	pass_test("lookahead stayed in BUFFER_REFILL_AT..BUFFER_AHEAD")


func test_freed_tiles_leave_with_their_dead_ends() -> void:
	var buffer := _buffer(3)
	buffer.start()
	var old := buffer.tiles()
	for i: int in range(1, 300):
		buffer.on_car_path_index(i)
	assert_eq(_freed_twice, 0)
	var now := buffer.tiles()
	assert_eq(_live.size(), now.size(), "signals add up to the buffer content")
	for tile: RoadTile in now:
		assert_true(_live.has(tile))
		assert_eq(buffer.tile_at(tile.cell), tile)
	for tile: RoadTile in old:
		assert_null(buffer.tile_at(tile.cell), "freed cells are released")
	assert_eq(buffer.generator.occupancy.size(), now.size(), "no stale cells")


func test_path_tile_and_centreline() -> void:
	var buffer := _buffer(5)
	buffer.start()
	assert_null(buffer.path_tile(-1))
	assert_null(buffer.path_tile(Tuning.BUFFER_AHEAD + 1))
	for i: int in 10:
		var centre := Iso.cell_centre(buffer.path_tile(i).cell)
		assert_eq(buffer.centreline_point(i), centre)
	var a := Iso.cell_centre(buffer.path_tile(6).cell)
	var b := Iso.cell_centre(buffer.path_tile(7).cell)
	assert_almost_eq(buffer.centreline_point(6.25), a.lerp(b, 0.25), Vector2(1e-5, 1e-5))


## GUT fails a test on any push_error, so these clamped points also report none.
func test_centreline_clamps_to_the_buffer_ends() -> void:
	var buffer := _buffer(5)
	buffer.start()
	assert_eq(buffer.centreline_point(-3.0), Iso.cell_centre(buffer.path_tile(0).cell))
	for i: int in range(1, 40):
		buffer.on_car_path_index(i)
	var first := buffer.first_index()
	var last := buffer.last_index()
	assert_gt(first, 0, "the buffer has freed tiles behind the car")
	var first_centre := Iso.cell_centre(buffer.path_tile(first).cell)
	var last_centre := Iso.cell_centre(buffer.path_tile(last).cell)
	assert_eq(buffer.centreline_point(0.0), first_centre)
	assert_eq(buffer.centreline_point(first - 0.5), first_centre)
	assert_eq(buffer.centreline_point(last), last_centre)
	assert_eq(buffer.centreline_point(last + 2.5), last_centre)


func test_centreline_before_start_is_an_error() -> void:
	var buffer := _buffer(5)
	assert_eq(buffer.centreline_point(0.0), Vector2.ZERO)
	assert_push_error("no centreline at distance 0.00")


func test_dropping_the_buffer_frees_every_tile() -> void:
	var buffer := RoadBuffer.new(RoadGenerator.new(9, Fixtures.schedule()))
	buffer.start()
	for i: int in range(1, 120):
		buffer.on_car_path_index(i)
	var probes: Array[WeakRef] = [weakref(buffer.generator)]
	for tile: RoadTile in buffer.tiles():
		probes.append(weakref(tile))
	buffer = null
	for probe: WeakRef in probes:
		assert_null(probe.get_ref(), "no reference cycle keeps road objects alive")
