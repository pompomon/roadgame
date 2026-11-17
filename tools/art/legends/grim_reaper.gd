extends RefCounted
## The Grim Reaper's sheets (POOLS_PLAN.md §5.4), drawn into assets/legends/grim_reaper/ by
## tools/art/make_legends.gd. `reaper.png`: a hooded figure in a dark robe, a skull in its hood,
## holding a scythe upright in its hand away from the grave, its blade curving away above it; it
## steps on one bony foot and then the other, stands, and beckons with its other bony hand, its
## fingers held out and then curled in. The scythe is the same in every frame, so it never swings
## (docs/M6.md Q8). `grave.png`: the grave, flat on the road along the tile x axis: a crack; a
## narrow pit; the open pit, its far walls of earth over its dark depths, its rim of broken asphalt,
## its earth heaped beside it up the screen; and the pit filled in. `gravestone.png`: an arched
## stone, two lines cut in it, on a plinth. The robe is dark, so it and the outline stand out from
## the City's grey road and ground by night (§5.6). Its sizes are the legend's (disasters/legends/
## grim_reaper.gd). No class_name: tools/ is not exported.

const LegendArt := preload("res://tools/art/legend_art.gd")
const GrimReaperLegend := preload("res://disasters/legends/grim_reaper.gd")
## The robe, in px from the Reaper's foot: its neck, shoulders, waist and hem, the hem zigzagging
## up HEM_UP px every HEM_STEP px; and its folds, lines from and to.
const NECK := Vector2(6.0, -50.0)
const SHOULDER := Vector2(10.0, -44.0)
const WAIST := Vector2(12.0, -30.0)
const HEM := Vector2(14.0, -2.0)
const HEM_UP := 2.0
const HEM_STEP := 3
const FOLDS: Array[Array] = [
	[Vector2(-4, -38), Vector2(-6, -5)],
	[Vector2(3, -36), Vector2(5, -5)],
	[Vector2(0, -28), Vector2(0, -5)],
]
## The hood, the dark of its opening, and the skull in it, ovals about their middles; the skull's
## eyes, its nose and its teeth.
const HOOD := Vector2(0.0, -56.0)
const HOOD_RADII := Vector2(8.0, 10.0)
const FACE := Vector2(0.0, -54.0)
const FACE_RADII := Vector2(5.0, 6.0)
const SKULL_RADII := Vector2(3.5, 4.5)
const EYES: Array[Rect2i] = [Rect2i(-3, -57, 2, 2), Rect2i(1, -57, 2, 2)]
const NOSE := Rect2i(-1, -54, 2, 1)
const TEETH: Array[Vector2i] = [Vector2i(-2, -51), Vector2i(0, -51)]
## The scythe: its snath, upright from its foot to its top, SNATH_WIDTH px wide; its blade, from
## the snath's top, away from the grave, between its outer and its inner curves, its edge the inner
## curve; and the hand that holds it, over the snath, with its knuckles.
const SNATH: Array[Vector2] = [Vector2(-13, -62), Vector2(-13, -3)]
const SNATH_WIDTH := 2
const BLADE_OUTER: Array[Vector2] = [
	Vector2(-12, -64), Vector2(-17, -65), Vector2(-22, -63), Vector2(-25, -60), Vector2(-27, -55)
]
const BLADE_INNER: Array[Vector2] = [
	Vector2(-12, -61), Vector2(-17, -62), Vector2(-21, -60), Vector2(-24, -57), Vector2(-27, -55)
]
const GRIP := Rect2i(-15, -38, 5, 3)
const KNUCKLES: Array[Vector2] = [Vector2(-15, -37), Vector2(-11, -37)]
## The far sleeve, from the shoulder to the hand on the snath.
const FAR_SLEEVE: Array[Vector2] = [
	Vector2(-7, -46), Vector2(-11, -44), Vector2(-14, -38), Vector2(-10, -37), Vector2(-7, -40)
]
## The near arm, by the Reaper's frame: its sleeve, the bony hand at its end, and the hand's
## fingers or toes, pixels.
const NEAR_SLEEVE: Dictionary[int, Array] = {
	GrimReaperLegend.Pose.STAND:
	[Vector2(7, -46), Vector2(11, -44), Vector2(13, -31), Vector2(9, -31), Vector2(8, -40)],
	GrimReaperLegend.Pose.BECKON:
	[Vector2(7, -47), Vector2(18, -46), Vector2(18, -41), Vector2(10, -40), Vector2(7, -42)],
}
const NEAR_HAND: Dictionary[int, Rect2i] = {
	GrimReaperLegend.Pose.STAND: Rect2i(10, -31, 3, 3),
	GrimReaperLegend.Pose.BECKON: Rect2i(18, -46, 3, 4),
}
const FINGERS: Dictionary[int, Array] = {
	GrimReaperLegend.Pose.STAND: [Vector2i(10, -28), Vector2i(12, -28)],
	GrimReaperLegend.Pose.BECKON:
	[
		Vector2i(21, -46),
		Vector2i(22, -47),
		Vector2i(23, -48),
		Vector2i(21, -45),
		Vector2i(22, -45),
		Vector2i(23, -45),
		Vector2i(24, -45),
		Vector2i(21, -43),
		Vector2i(22, -43),
		Vector2i(23, -43),
	],
	GrimReaperLegend.Pose.CURL:
	[
		Vector2i(21, -46),
		Vector2i(22, -47),
		Vector2i(23, -46),
		Vector2i(21, -45),
		Vector2i(22, -45),
		Vector2i(22, -44),
		Vector2i(21, -43),
		Vector2i(22, -43),
		Vector2i(22, -42),
	],
}
## A bony foot under the hem, by the step's frame.
const FEET: Dictionary[int, Rect2i] = {
	GrimReaperLegend.Pose.STEP_A: Rect2i(-7, -3, 4, 2),
	GrimReaperLegend.Pose.STEP_B: Rect2i(3, -3, 4, 2),
}
## The grave, in tiles about its middle: its rim, RIM_TILES wider than its pit all round; the far
## walls of its pit, the lit rows under its far edges and then the rest, in px; the pit's width
## ajar; the crack, by its points along and across the pit; and the mound of the filled grave, its
## top's share of the pit and how high it is, and its clods.
const RIM_TILES := 0.04
const WALL_LIT := 2
const WALL := 5
const AJAR_TILES := 0.12
const CRACK: Array[Vector2] = [
	Vector2(-0.3, 0.0),
	Vector2(-0.21, 0.04),
	Vector2(-0.1, -0.02),
	Vector2(0.0, 0.03),
	Vector2(0.09, -0.04),
	Vector2(0.2, 0.01),
	Vector2(0.3, -0.02),
]
const MOUND_SHARE := Vector2(0.8, 0.7)
const MOUND_PX := 3.0
const CLODS: Array[Vector2] = [
	Vector2(-0.15, -0.1), Vector2(-0.05, 0.08), Vector2(0.08, -0.05), Vector2(0.18, 0.06)
]
## The gravestone, in px from its foot: its slab, its arched top's middle and radii, the shaded
## side SHADE px wide, the lines cut in it, and the plinth.
const SLAB := Rect2i(-7, -21, 14, 17)
const ARCH := Vector2(0.0, -20.0)
const ARCH_RADII := Vector2(7.0, 6.0)
const SHADE := 3
const CUTS: Array[Rect2i] = [Rect2i(-4, -18, 7, 1), Rect2i(-4, -15, 7, 1), Rect2i(-3, -12, 5, 1)]
const PLINTH := Rect2i(-9, -4, 18, 3)


static func make(dir: String) -> void:
	var reaper := LegendArt.new(GrimReaperLegend.REAPER, GrimReaperLegend.Pose.size())
	for pose: int in GrimReaperLegend.Pose.size():
		reaper.frame = pose
		_draw_reaper(reaper, pose)
	reaper.save(dir.path_join("reaper.png"))
	var grave := LegendArt.new(GrimReaperLegend.GRAVE, GrimReaperLegend.Dug.size())
	for dug: int in GrimReaperLegend.Dug.size():
		grave.frame = dug
		_draw_grave(grave, dug)
	grave.save(dir.path_join("grave.png"))
	var stone := LegendArt.new(GrimReaperLegend.STONE)
	_draw_stone(stone)
	stone.save(dir.path_join("gravestone.png"))


static func _draw_reaper(art: LegendArt, pose: int) -> void:
	art.poly(_robe(), "shadow")
	for fold: Array in FOLDS:
		art.line(fold[0], fold[1], "ink")
	art.ellipse(HOOD, HOOD_RADII, "shadow")
	art.ellipse(FACE, FACE_RADII, "ink")
	art.ellipse(FACE, SKULL_RADII, "line")
	for eye: Rect2i in EYES:
		art.rect(eye, "ink")
	art.rect(NOSE, "ink")
	for tooth: Vector2i in TEETH:
		art.plot(tooth, "ink")
	if FEET.has(pose):
		art.rect(FEET[pose], "line")
	_draw_scythe(art)
	var arm := GrimReaperLegend.Pose.STAND if pose < GrimReaperLegend.Pose.BECKON else pose
	var held := GrimReaperLegend.Pose.BECKON if arm == GrimReaperLegend.Pose.CURL else arm
	var sleeve: Array[Vector2] = []
	sleeve.assign(NEAR_SLEEVE[held])
	art.poly(sleeve, "shadow")
	art.rect(NEAR_HAND[held], "line")
	for finger: Vector2i in FINGERS[arm]:
		art.plot(finger, "line")
	art.outline()


## The robe's outline, from the neck round by the shoulders and the waist to its zigzag hem.
static func _robe() -> Array[Vector2]:
	var points: Array[Vector2] = [
		Vector2(-NECK.x, NECK.y), NECK, SHOULDER, WAIST, Vector2(HEM.x, HEM.y)
	]
	var x := HEM.x
	var up := true
	while x > -HEM.x:
		x -= HEM_STEP
		points.append(Vector2(maxf(x, -HEM.x), HEM.y - (HEM_UP if up else 0.0)))
		up = not up
	points.append(Vector2(-HEM.x, HEM.y))
	points.append(Vector2(-WAIST.x, WAIST.y))
	points.append(Vector2(-SHOULDER.x, SHOULDER.y))
	return points


## The scythe and the hand that holds it, the same in every frame.
static func _draw_scythe(art: LegendArt) -> void:
	art.poly(FAR_SLEEVE, "shadow")
	art.line(SNATH[0], SNATH[1], "plank", SNATH_WIDTH)
	var blade: Array[Vector2] = BLADE_OUTER.duplicate()
	var inner := BLADE_INNER.duplicate()
	inner.reverse()
	blade.append_array(inner)
	art.poly(blade, "asphalt light")
	for k: int in BLADE_INNER.size() - 1:
		art.line(BLADE_INNER[k], BLADE_INNER[k + 1], "white")
	art.rect(GRIP, "line")
	art.line(KNUCKLES[0], KNUCKLES[1], "ink")


static func _draw_grave(art: LegendArt, dug: int) -> void:
	var half := GrimReaperLegend.GRAVE_TILES / 2.0
	if dug == GrimReaperLegend.Dug.CRACKED:
		_draw_crack(art)
		return
	var pit := Vector2(half.x, AJAR_TILES) if dug == GrimReaperLegend.Dug.AJAR else half
	art.poly(_diamond(pit + Vector2.ONE * RIM_TILES), "asphalt light")
	if dug == GrimReaperLegend.Dug.FILLED:
		_draw_mound(art, half)
	else:
		_draw_pit(art, pit)
		if dug == GrimReaperLegend.Dug.OPEN:
			_draw_heap(art, half)
	art.outline()


## A crack along the pit's length, dark, its lower lip lit.
static func _draw_crack(art: LegendArt) -> void:
	for k: int in CRACK.size() - 1:
		var from := _at(CRACK[k].x, CRACK[k].y)
		var to := _at(CRACK[k + 1].x, CRACK[k + 1].y)
		art.line(from + Vector2.DOWN, to + Vector2.DOWN, "asphalt light")
		art.line(from, to, "ink")


## The pit, `half` tiles from its middle along and across: its far walls lit, then shaded, under its
## far edges, and its depths dark.
static func _draw_pit(art: LegendArt, half: Vector2) -> void:
	var box := _box(_diamond(half))
	for y: int in range(box.position.y, box.end.y):
		for x: int in range(box.position.x, box.end.x):
			var centre := Vector2(x, y) + Vector2(0.5, 0.5)
			if not _inside(centre, half):
				continue
			var below := 1
			while below <= WALL and _inside(centre - Vector2(0.0, below), half):
				below += 1
			var paint := "ink"
			if below <= WALL_LIT:
				paint = "rural dark"
			elif below <= WALL:
				paint = "rural dirt"
			art.plot(Vector2i(x, y), paint)


## The mound of the filled grave, `half` tiles from its middle along and across: its far slopes,
## its near slopes down the screen in shade, and its top, MOUND_PX higher, lit, with its clods. The
## shade stands out from the City's road and ground by night (POOLS_PLAN.md §5.6, V15), as its
## browns don't.
static func _draw_mound(art: LegendArt, half: Vector2) -> void:
	var foot := _diamond(half)
	art.poly(foot, "rural dirt")
	var top := _diamond(half * MOUND_SHARE)
	for k: int in top.size():
		top[k].y -= MOUND_PX
	# The corners of each, left, near and right: _diamond()'s last three, reversed for the top.
	var near: Array[Vector2] = [foot[3], foot[2], foot[1], top[1], top[2], top[3]]
	art.poly(near, "shadow")
	art.poly(top, "rural dark")
	for clod: Vector2 in CLODS:
		art.plot(Vector2i((_at(clod.x, clod.y) + Vector2(0.0, -MOUND_PX)).floor()), "rural dirt")


## The heap of earth dug out of the pit, beside its side up the screen: its sides and then its top,
## HEAP_PX higher.
static func _draw_heap(art: LegendArt, half: Vector2) -> void:
	var along := half.x * GrimReaperLegend.HEAP_ALONG
	var near := -half.y - GrimReaperLegend.HEAP_TILES.x
	var far := -half.y - GrimReaperLegend.HEAP_TILES.y
	var base: Array[Vector2] = [
		_at(-along, near), _at(along, near), _at(along, far), _at(-along, far)
	]
	var lift := Vector2(0.0, -GrimReaperLegend.HEAP_PX)
	var middle := _at(0.0, (near + far) / 2.0) + lift
	var top: Array[Vector2] = []
	for corner: Vector2 in base:
		top.append(middle + (corner - _at(0.0, (near + far) / 2.0)) * 0.6)
	var hull := Geometry2D.convex_hull(PackedVector2Array(base + top))
	var sides: Array[Vector2] = []
	sides.assign(Array(hull))
	art.poly(sides, "rural dirt")
	art.poly(top, "rural dark")


## The stone, shaded on its right and round its arch's right, and lit on the rest. The shade stands
## out from the City's road and ground by night (POOLS_PLAN.md §5.6, V15), as the light greys don't.
static func _draw_stone(art: LegendArt) -> void:
	art.rect(SLAB, "shadow")
	art.ellipse(ARCH, ARCH_RADII, "shadow")
	art.rect(Rect2i(SLAB.position, SLAB.size - Vector2i(SHADE, 0)), "line")
	var lit := Vector2(SHADE / 2.0, 0.0)
	art.ellipse(ARCH - lit, ARCH_RADII - lit, "line")
	for cut: Rect2i in CUTS:
		art.rect(cut, "asphalt light")
	art.rect(PLINTH, "asphalt light")
	art.outline()


## The point `along` and `across` tiles from the grave's middle, in px from its frame's foot.
static func _at(along: float, across: float) -> Vector2:
	var middle := Vector2(0.0, -GrimReaperLegend.GRAVE.y / 2.0)
	return middle + Iso.tile_to_world(Vector2(along, across))


## The corners of the oblong `half` tiles from the grave's middle along and across.
static func _diamond(half: Vector2) -> Array[Vector2]:
	return [_at(-half.x, -half.y), _at(half.x, -half.y), _at(half.x, half.y), _at(-half.x, half.y)]


## Whether the point `at`, in px from the frame's foot, is inside the oblong `half` tiles from the
## grave's middle along and across.
static func _inside(at: Vector2, half: Vector2) -> bool:
	var tile := Iso.world_to_tile(at - _at(0.0, 0.0))
	return absf(tile.x) <= half.x and absf(tile.y) <= half.y


static func _box(points: Array[Vector2]) -> Rect2i:
	var box := Rect2(points[0], Vector2.ZERO)
	for point: Vector2 in points:
		box = box.expand(point)
	return Rect2i(box.position.floor(), box.size.ceil() + Vector2.ONE)
