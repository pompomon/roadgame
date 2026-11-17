extends RefCounted
## The Will-o'-the-Wisp's sheet (docs/POOLS.md §5.4), drawn into assets/legends/will_o_wisp/ by
## tools/art/make_legends.gd. `bog_cotton.png`: a tuft of bog cotton as it sprouts, in frames of
## the legend's TUFT px, each standing on its bottom row: three short green shoots; taller stalks,
## a white bud on each; then full grown, a white head of cotton on each, in shade low on its right,
## as the car is lit from the upper left. Its wisps are glows, glow.tres
## (disasters/legends/will_o_wisp.gd). No class_name: tools/ is not exported.

const LegendArt := preload("res://tools/art/legend_art.gd")
const WillOWispLegend := preload("res://disasters/legends/will_o_wisp.gd")

## Where its stalks stand, x px from the frame's foot, and where each one's top is in each frame,
## from the shoots to the full-grown tuft: the outer two lean out as they grow.
const ROOTS: Array[int] = [-3, 0, 2]
const TOPS: Array[Array] = [
	[Vector2i(-3, -3), Vector2i(0, -4), Vector2i(2, -3)],
	[Vector2i(-4, -6), Vector2i(0, -7), Vector2i(3, -5)],
	[Vector2i(-4, -8), Vector2i(0, -9), Vector2i(3, -7)],
]
## A head of cotton's radii, about its stalk, over the 4 px above its top: rounded, its corners cut.
const HEAD := Vector2(1.5, 2.0)
## From a pixel's corner to its centre: a stalk runs between its ends' centres, so that it leans
## halfway up, not at its foot (LegendArt.line rounds its points down).
const HALF := Vector2(0.5, 0.5)


static func make(dir: String) -> void:
	var tuft := LegendArt.new(WillOWispLegend.TUFT, WillOWispLegend.TUFT_FRAMES)
	for frame: int in WillOWispLegend.TUFT_FRAMES:
		tuft.frame = frame
		_draw_tuft(tuft, frame)
	tuft.save(dir.path_join("bog_cotton.png"))


## A tuft `grown` frames on from its shoots: a stalk from each root up to its top, and over each top
## a white bud, or once full grown a white head of cotton.
static func _draw_tuft(art: LegendArt, grown: int) -> void:
	var tops: Array = TOPS[grown]
	for k: int in ROOTS.size():
		var top: Vector2i = tops[k]
		art.line(Vector2(ROOTS[k], -1) + HALF, Vector2(top) + HALF, "meadows dark")
		if grown == 1:
			art.rect(Rect2i(top.x, top.y - 2, 1, 2), "white")
		elif grown == 2:
			art.ellipse(Vector2(top.x + 0.5, top.y - 2.0), HEAD, "white")
			art.plot(Vector2i(top.x + 1, top.y - 2), "line")
	art.outline()
