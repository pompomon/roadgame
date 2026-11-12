extends RefCounted
## The fairy ring's sheets (M6_PLAN.md §3.3), drawn into assets/legends/fairy_ring/ by
## tools/art/make_legends.gd. `toadstool.png`: a pale toadstool as it grows, a button, half grown,
## then full: a white cap with dark spots, its rim in shade, on a short stem, lit from the upper
## left, as the car is. `eyes.png`: a pair of slanted eyes with no pupils as they open, a slit, half
## open, then open, a glow drawn in white and grey, which its tint colours. Each frame's eyes cover
## the last's and their halo, so each point of them only gets lighter as they open, and darker as
## they close (test_fairy_ring.gd). Their sizes are the legend's (disasters/legends/fairy_ring.gd).
## No class_name: tools/ is not exported.

const LegendArt := preload("res://tools/art/legend_art.gd")
const FairyRingLegend := preload("res://disasters/legends/fairy_ring.gd")


static func make(dir: String) -> void:
	var toadstool := LegendArt.new(FairyRingLegend.TOADSTOOL, FairyRingLegend.TOADSTOOL_FRAMES)
	for frame: int in FairyRingLegend.TOADSTOOL_FRAMES:
		toadstool.frame = frame
		_draw_toadstool(toadstool, frame)
	toadstool.save(dir.path_join("toadstool.png"))
	var eyes := LegendArt.new(FairyRingLegend.EYES, FairyRingLegend.EYE_FRAMES)
	for frame: int in FairyRingLegend.EYE_FRAMES:
		eyes.frame = frame
		_draw_eyes(eyes, frame)
	eyes.save(dir.path_join("eyes.png"))


## A toadstool `grown` frames on from a button: its cap's rows, from the top, as spans of x, its
## stem's height and its spots.
static func _draw_toadstool(art: LegendArt, grown: int) -> void:
	var caps: Array[Array] = [
		[Vector2i(-1, 0), Vector2i(-2, 1)],
		[Vector2i(-1, 0), Vector2i(-2, 1), Vector2i(-3, 2)],
		[Vector2i(-2, 1), Vector2i(-3, 2), Vector2i(-4, 3), Vector2i(-4, 3)],
	]
	var stems: Array[int] = [0, 3, 4]
	var spots: Array[Array] = [[], [Vector2i(-1, -5)], [Vector2i(-2, -7), Vector2i(1, -7)]]
	var rows: Array = caps[grown]
	var top := -stems[grown] - rows.size()
	for k: int in rows.size():
		var span: Vector2i = rows[k]
		var y := top + k
		# Its rim, the bottom row, is in shade, and so is the right end of each row above it.
		var lit := span.y - 1 if k < rows.size() - 1 else span.x - 1
		for x: int in range(span.x, span.y + 1):
			art.plot(Vector2i(x, y), "white" if x <= lit else "line")
	for spot: Vector2i in spots[grown]:
		art.plot(spot, "shadow")
	for y: int in range(-stems[grown], 0):
		art.plot(Vector2i(-1, y), "white")
		art.plot(Vector2i(0, y), "line")
	art.outline()


## A pair of eyes `opened` frames on from a slit: the left eye's core, white, as rows of spans of
## x, each frame's covering the last's; the right eye mirrors it. A grey halo rings each core.
static func _draw_eyes(art: LegendArt, opened: int) -> void:
	var cores: Array[Rect2i] = [Rect2i(-5, -3, 3, 1)]
	if opened >= 1:
		cores.append_array([Rect2i(-6, -3, 5, 1), Rect2i(-5, -4, 2, 1)])
	if opened >= 2:
		cores.append_array([Rect2i(-6, -4, 1, 1), Rect2i(-3, -2, 2, 1)])
	for core: Rect2i in cores:
		art.rect(core, "white")
		art.rect(Rect2i(-core.end.x, core.position.y, core.size.x, core.size.y), "white")
	art.outline("asphalt light")
