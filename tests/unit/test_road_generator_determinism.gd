extends GutTest

const Fixtures := preload("res://tests/helpers/road_fixtures.gd")
const TILES := 2000


func _signatures(gen: RoadGenerator, count: int) -> Array:
	var sigs: Array = []
	for i: int in count:
		sigs.append(Fixtures.signature(gen.next_tile()))
	return sigs


func test_same_seed_same_road() -> void:
	var a := _signatures(RoadGenerator.new(12345, Fixtures.schedule()), TILES)
	var b := _signatures(RoadGenerator.new(12345, Fixtures.schedule()), TILES)
	assert_eq(a.size(), TILES)
	assert_true(a == b, "2,000 tiles with their dead ends are identical")


func test_different_seed_different_road() -> void:
	var a := _signatures(RoadGenerator.new(1, Fixtures.schedule()), 200)
	var b := _signatures(RoadGenerator.new(2, Fixtures.schedule()), 200)
	assert_false(a == b)


func test_buffer_refills_and_frees_do_not_change_the_road() -> void:
	# Freed dead ends release their cells. The road stays the same only because they are at least
	# 30 path tiles behind the tiles being generated, and dead ends only collide within 6.
	var expected := _signatures(RoadGenerator.new(7, Fixtures.schedule()), TILES)
	var buffer := RoadBuffer.new(RoadGenerator.new(7, Fixtures.schedule()))
	var got: Array = []
	buffer.tiles_generated.connect(
		func(tiles: Array[RoadTile]) -> void:
			for tile: RoadTile in tiles:
				if tile.path_index >= 0:
					got.append(Fixtures.signature(tile))
	)
	buffer.start()
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	while got.size() < TILES:
		buffer.on_car_path_index(buffer.car_index() + rng.randi_range(0, 30))
	assert_true(got.slice(0, TILES) == expected)
