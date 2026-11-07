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
