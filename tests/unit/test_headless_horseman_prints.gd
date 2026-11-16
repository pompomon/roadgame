extends GutTest
## The Headless Horseman's hoofprints on the road (POOLS_PLAN.md §5.4): as he gallops off, they show
## for the strides that lie on the road, as far as it runs on, and for none past: strides_on()
## counts them. A review found them on the grass where the road ended short of them, which
## test_headless_horseman.gd plays.

const Fixtures := preload("res://tests/helpers/road_fixtures.gd")
## How many parts it splits each stride's share of the stretch into, along it and across it, to look
## at each point between them: finer than strides_on() looks, and through each point that it does.
const ALONG_PARTS := 20
const ACROSS_PARTS := 4
## Where he halts, in tiles: HALTS places along the road's middle, HALT_STEP apart, from
## FIRST_HALT, the middle of the cell (2, 0), so that the road runs on under all his strides' prints
## at first, and at last under one stride's.
const FIRST_HALT := Vector2(2.5, 0.5)
const HALTS := 100
const HALT_STEP := 0.01


## Whether each point of the parts of stride `k`'s share of the stretch from `from`, along the tile
## x axis and PRINTS_SPREAD to each side of its middle, lies on the road of `buffer`.
static func _on_road(buffer: RoadBuffer, from: Vector2, k: int) -> bool:
	var stride := HeadlessHorseman.PRINTS_TILES / HeadlessHorseman.STRIDES
	for along: int in ALONG_PARTS + 1:
		for across: int in ACROSS_PARTS + 1:
			var x := stride * (k + float(along) / ALONG_PARTS)
			var y := HeadlessHorseman.PRINTS_SPREAD * (2.0 * across / ACROSS_PARTS - 1.0)
			var point := from + Vector2(x, y)
			var cell := Vector2i(point.floor())
			if not RoadGeometry.is_on_road(buffer.tile_at(cell), point - Vector2(cell)):
				return false
	return true


func test_it_counts_the_strides_whose_prints_lie_on_the_road_wherever_he_halted() -> void:
	# On a road that ends short of his prints, with a strip of field and then a road across its line
	# beyond its end: wherever he halts on its middle, heading along it, strides_on() counts each
	# stride whose share of the stretch, PRINTS_SPREAD to each side of its middle, lies on the road,
	# up to the first that leaves it: all of them where he halts far enough from its end, and one
	# near it.
	var buffer := Fixtures.dead_end_short_of_a_road()
	var wrong: Array[String] = []
	var counts: Array[int] = []
	for n: int in HALTS:
		var from := FIRST_HALT + Vector2(n * HALT_STEP, 0.0)
		var counted := HeadlessHorseman.strides_on(from, Vector2.RIGHT, buffer)
		counts.append(counted)
		for k: int in mini(counted + 1, HeadlessHorseman.STRIDES):
			if _on_road(buffer, from, k) != (k < counted):
				wrong.append("halted at %s: stride %d" % [from, k])
	assert_eq(wrong, [] as Array[String], "each stride on the road, up to the first that leaves it")
	assert_eq([counts.max(), counts.min()], [HeadlessHorseman.STRIDES, 1], "all of them, then one")
