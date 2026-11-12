extends GutTest

const Fixtures := preload("res://tests/helpers/road_fixtures.gd")
const TILES := 2000
## The game's road for seeds 0 to 19 up to turn 300, as MD5 digests: of its path tiles alone, and
## of its path tiles with their dead ends. A change that is meant to change the road updates them,
## and its commit says why (ROADGEN_PLAN.md §6.1).
const PATH_DIGEST := "811569241f55e1fce2a50331fe4c3e7d"
const ROAD_DIGEST := "3135d6c1c4c1b505121ff96b02dc202b"
const DIGEST_SEEDS := 20
const DIGEST_TURNS := 300


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
	# Freed dead ends release their cells. The road stays the same only because they are more than
	# BUFFER_REFILL_AT + BUFFER_BEHIND path tiles behind the tiles being generated, and dead ends
	# only collide within twice DEAD_END_MAX_TILES (RoadGenerator).
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


func test_the_game_road_matches_its_digests() -> void:
	var path_lines := PackedStringArray()
	var road_lines := PackedStringArray()
	for run_seed: int in DIGEST_SEEDS:
		var gen := RoadGenerator.new(run_seed, Fixtures.schedule())
		for tile: RoadTile in Fixtures.path_until_turn(gen, DIGEST_TURNS):
			var sig := Fixtures.signature(tile)
			path_lines.append(str(sig.slice(0, 7)))
			road_lines.append(str(sig))
	gut.p("digest tiles: %d" % path_lines.size())
	assert_eq("\n".join(path_lines).md5_text(), PATH_DIGEST, "the path tiles")
	assert_eq("\n".join(road_lines).md5_text(), ROAD_DIGEST, "the path tiles and their dead ends")
