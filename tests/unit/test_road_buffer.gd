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


func test_start_generates_50_ahead() -> void:
	var buffer := _buffer(1)
	buffer.start()
	assert_eq(buffer.first_index(), 0)
	assert_eq(buffer.last_index(), Tuning.BUFFER_AHEAD)
	assert_eq(buffer.lookahead(), Tuning.BUFFER_AHEAD)
	assert_eq(_live.size(), buffer.tiles().size())


func test_lookahead_stays_between_25_and_50_fuzzed() -> void:
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
	pass_test("lookahead stayed in 25..50")


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
