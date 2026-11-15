extends RefCounted
## The kelpie's sheets (POOLS_PLAN.md §5.4), drawn into assets/legends/kelpie/ by
## tools/art/make_legends.gd. `kelpie.png`: a black water horse standing in its pool to its knees,
## wet, a sheen of the night on its back, weed in its ink mane and tail, facing the screen's right:
## its head high as it rises, lowered to the car as it waits, then plunging head first into the
## water, its rump up and its tail flying. `pool.png`: a dark pool in a bank of weed, still, then a
## ring of foam spreading from where the horse stands. `weed.png`: waterweed on a wet patch of road.
## The horse is outlined in ink, so that it shows against the meadows at night; the pool and the
## weed lie on the ground, as the death worm's crater does. Their sizes are the legend's
## (disasters/legends/kelpie.gd). No class_name: tools/ is not exported.

const LegendArt := preload("res://tools/art/legend_art.gd")
const KelpieLegend := preload("res://disasters/legends/kelpie.gd")
## The horse, in px from its foot, standing: its barrel, rump and chest, ovals about their middles
## of these radii, the night's sheen along their tops SHEEN px deep; its legs, from its body down
## under the water, each TAPER px narrower at its foot than at its top: the far ones, in the
## night's shade, then the near.
const BARREL := Vector2(-2.0, -17.0)
const BARREL_RADII := Vector2(15.0, 7.0)
const RUMP := Vector2(-13.0, -19.0)
const RUMP_RADII := Vector2(8.0, 8.0)
const CHEST := Vector2(9.0, -19.0)
const CHEST_RADII := Vector2(7.0, 8.0)
const SHEEN := 2.0
const FAR_LEGS: Array[Rect2] = [Rect2(-13, -14, 4, 26), Rect2(5, -14, 4, 26)]
const NEAR_LEGS: Array[Rect2] = [Rect2(-20, -15, 6, 27), Rect2(10, -15, 5, 27)]
const TAPER := 2.0
## Its neck and head, and its ear, its eye and its nostril: its head high as it rises, and lowered
## to the car as it waits.
const HIGH_NECK: Array[Vector2] = [
	Vector2(1, -25),
	Vector2(6, -32),
	Vector2(11, -38),
	Vector2(15, -41),
	Vector2(20, -37),
	Vector2(18, -28),
	Vector2(16, -18),
	Vector2(8, -18),
]
const HIGH_HEAD: Array[Vector2] = [
	Vector2(14, -42),
	Vector2(18, -44),
	Vector2(21, -40),
	Vector2(26, -31),
	Vector2(26, -28),
	Vector2(23, -27),
	Vector2(20, -31),
	Vector2(17, -35),
]
const HIGH_EAR: Array[Vector2] = [Vector2(15, -42), Vector2(17, -47), Vector2(19, -42)]
const HIGH_EYE := Vector2i(19, -39)
const HIGH_NOSTRIL := Vector2i(24, -29)
const LOW_NECK: Array[Vector2] = [
	Vector2(1, -25),
	Vector2(8, -29),
	Vector2(14, -31),
	Vector2(19, -32),
	Vector2(22, -26),
	Vector2(19, -21),
	Vector2(16, -15),
	Vector2(8, -18),
]
const LOW_HEAD: Array[Vector2] = [
	Vector2(17, -32),
	Vector2(21, -33),
	Vector2(24, -27),
	Vector2(26, -18),
	Vector2(25, -15),
	Vector2(22, -15),
	Vector2(21, -20),
	Vector2(19, -26),
]
const LOW_EAR: Array[Vector2] = [Vector2(18, -32), Vector2(22, -36), Vector2(21, -31)]
const LOW_EYE := Vector2i(21, -28)
const LOW_NOSTRIL := Vector2i(24, -17)
## Its mane along its crest, a line from one point to the next, MANE px wide, and its tail.
const HIGH_MANE: Array[Vector2] = [
	Vector2(14, -42), Vector2(10, -38), Vector2(6, -32), Vector2(1, -26)
]
const LOW_MANE: Array[Vector2] = [
	Vector2(18, -32),
	Vector2(14, -31),
	Vector2(8, -29),
	Vector2(1, -26),
]
const MANE := 2
const TAIL: Array[Vector2] = [
	Vector2(-19, -26),
	Vector2(-23, -23),
	Vector2(-26, -15),
	Vector2(-26, -6),
	Vector2(-24, 0),
	Vector2(-21, 0),
	Vector2(-22, -8),
	Vector2(-21, -17),
	Vector2(-17, -24),
]
## Weed in its mane and tail, by pairs of points: a line from the first of each pair to the second.
const WEED_STRANDS: Array[Vector2] = [
	Vector2(-24, -20),
	Vector2(-25, -10),
	Vector2(-22, -14),
	Vector2(-23, -5),
]
const STRAND_COLORS: Array[String] = ["meadows light", "meadows dark", "meadows light"]
## The water at its knees: foam each side of each near leg, FOAM px wide.
const FOAM := 2
## Plunging, head first: the horse as it waits, turned by TILT about its barrel's middle and dropped
## by DROP, its head going under and its rump up, its near hind leg kicked back by KICK more and
## its tail flying.
const TILT := 0.65
const DROP := Vector2(0.0, 4.0)
const KICK := 0.4
const FLYING_TAIL: Array[Vector2] = [
	Vector2(-9, -31),
	Vector2(-12, -37),
	Vector2(-16, -41),
	Vector2(-22, -45),
	Vector2(-26, -45),
	Vector2(-23, -41),
	Vector2(-19, -37),
	Vector2(-15, -31),
	Vector2(-13, -27),
]
const FLYING_STRANDS: Array[Vector2] = [
	Vector2(-14, -36),
	Vector2(-22, -43),
	Vector2(-15, -32),
	Vector2(-21, -39),
]
## The pool: its bank's radii about its frame's middle, its water's, its deep water's and where
## they lie from it; the glint on its far side, a line; and its rings' middle, where the horse
## stands.
const BANK := Vector2(31.5, 15.5)
const WATER := Vector2(29.0, 13.5)
const WATER_AT := Vector2(0.0, 0.5)
const DEEP := Vector2(25.0, 11.0)
const DEEP_AT := Vector2(1.0, 1.5)
const GLINT: Array[Vector2] = [Vector2(-17, -7), Vector2(-10, -9)]
## The weed: a wet patch of these radii about its frame's middle, and its strands, by pairs of
## points from it.
const PATCH := Vector2(13.0, 5.5)
const LYING: Array[Vector2] = [
	Vector2(-11, -1),
	Vector2(-3, -3),
	Vector2(-8, 2),
	Vector2(2, 0),
	Vector2(-2, -3),
	Vector2(9, -2),
	Vector2(1, 2),
	Vector2(10, 1),
	Vector2(-6, 0),
	Vector2(5, 3),
]
const LYING_COLORS: Array[String] = [
	"meadows dark", "meadows light", "desert cactus", "meadows dark", "meadows light"
]


static func make(dir: String) -> void:
	var horse := LegendArt.new(KelpieLegend.HORSE, KelpieLegend.Pose.size())
	for frame: int in KelpieLegend.Pose.size():
		horse.frame = frame
		_draw_horse(horse, frame)
	horse.save(dir.path_join("kelpie.png"))
	var pool := LegendArt.new(KelpieLegend.POOL, KelpieLegend.RINGS.size() + 1)
	for frame: int in KelpieLegend.RINGS.size() + 1:
		pool.frame = frame
		_draw_pool(pool, frame)
	pool.save(dir.path_join("pool.png"))
	var weed := LegendArt.new(KelpieLegend.WEED)
	_draw_weed(weed)
	weed.save(dir.path_join("weed.png"))


## The horse in its sheet's `frame`, a Pose.
static func _draw_horse(art: LegendArt, frame: int) -> void:
	var plunging := frame == KelpieLegend.Pose.PLUNGING
	var high := frame == KelpieLegend.Pose.RISING
	if plunging:
		art.poly(FLYING_TAIL, "ink")
		_draw_strands(art, FLYING_STRANDS)
	for leg: Rect2 in FAR_LEGS:
		art.poly(_placed(_leg(leg, 0.0), plunging), "night")
	if not plunging:
		art.poly(TAIL, "ink")
		_draw_strands(art, WEED_STRANDS)
	var angle := TILT if plunging else 0.0
	for paint: String in ["night", "shadow"]:
		# The night's sheen along their tops, under the shadow of the rest, a little lower.
		var down := Vector2(0.0, SHEEN / 2.0) if paint == "shadow" else Vector2.ZERO
		_oval(art, _place(RUMP, plunging) + down, RUMP_RADII - down, angle, paint)
		_oval(art, _place(BARREL, plunging) + down, BARREL_RADII - down, angle, paint)
		_oval(art, _place(CHEST, plunging) + down, CHEST_RADII - down, angle, paint)
	for leg: Rect2 in NEAR_LEGS:
		art.poly(_placed(_leg(leg, KICK if plunging else 0.0), plunging), "shadow")
		if not plunging:
			art.rect(Rect2i(int(leg.position.x) - FOAM, -1, FOAM, 1), "foam")
			art.rect(Rect2i(int(leg.end.x), -1, FOAM, 1), "white")
	art.poly(_placed(HIGH_NECK if high else LOW_NECK, plunging), "shadow")
	art.poly(_placed(HIGH_HEAD if high else LOW_HEAD, plunging), "shadow")
	art.poly(_placed(HIGH_EAR if high else LOW_EAR, plunging), "shadow")
	_draw_mane(art, _placed(HIGH_MANE if high else LOW_MANE, plunging))
	art.plot(Vector2i(_place(Vector2(HIGH_EYE if high else LOW_EYE), plunging)), "white")
	art.plot(Vector2i(_place(Vector2(HIGH_NOSTRIL if high else LOW_NOSTRIL), plunging)), "ink")
	art.outline()


## Where `point` of the standing horse is, plunging or not.
static func _place(point: Vector2, plunging: bool) -> Vector2:
	if not plunging:
		return point
	return BARREL + (point - BARREL).rotated(TILT) + DROP


static func _placed(points: Array[Vector2], plunging: bool) -> Array[Vector2]:
	var placed: Array[Vector2] = []
	for point: Vector2 in points:
		placed.append(_place(point, plunging))
	return placed


## A leg's corners, narrower at its foot: a hind leg kicked back by `kick` about its top.
static func _leg(leg: Rect2, kick: float) -> Array[Vector2]:
	var foot := TAPER / 2.0
	var corners: Array[Vector2] = [
		leg.position,
		Vector2(leg.end.x, leg.position.y),
		Vector2(leg.end.x - foot, leg.end.y),
		Vector2(leg.position.x + foot, leg.end.y),
	]
	if leg.get_center().x < BARREL.x:
		var top := Vector2(leg.get_center().x, leg.position.y)
		for k: int in corners.size():
			corners[k] = top + (corners[k] - top).rotated(kick)
	return corners


## Its mane, along `crest`, with weed in it.
static func _draw_mane(art: LegendArt, crest: Array[Vector2]) -> void:
	for k: int in crest.size() - 1:
		art.line(crest[k], crest[k + 1], "ink", MANE)
	for k: int in range(1, crest.size()):
		var hang := crest[k] + Vector2(-2.0, 4.0)
		art.line(crest[k], hang, STRAND_COLORS[k % STRAND_COLORS.size()])


## Weed by pairs of points.
static func _draw_strands(art: LegendArt, strands: Array[Vector2]) -> void:
	for k: int in range(0, strands.size() - 1, 2):
		art.line(strands[k], strands[k + 1], STRAND_COLORS[(k >> 1) % STRAND_COLORS.size()])


## Fills the pixels whose centres are inside the ellipse of `radii` about `centre`, turned by
## `angle`.
static func _oval(
	art: LegendArt, centre: Vector2, radii: Vector2, angle: float, paint: String
) -> void:
	var reach := ceili(maxf(radii.x, radii.y))
	for y: int in range(floori(centre.y) - reach, floori(centre.y) + reach + 1):
		for x: int in range(floori(centre.x) - reach, floori(centre.x) + reach + 1):
			var at := (Vector2(x, y) + Vector2(0.5, 0.5) - centre).rotated(-angle) / radii
			if at.length_squared() <= 1.0:
				art.plot(Vector2i(x, y), paint)


## The pool in its sheet's `frame`: still water in a bank of weed, then a ring spreading from where
## the horse stands, RINGS[frame - 1] of the deep water's radii across.
static func _draw_pool(art: LegendArt, frame: int) -> void:
	var middle := Vector2(0.0, -KelpieLegend.POOL.y / 2.0)
	art.ellipse(middle, BANK, "meadows dark")
	art.ellipse(middle + WATER_AT, WATER, "meadows water")
	art.ellipse(middle + DEEP_AT, DEEP, "night")
	art.line(middle + GLINT[0], middle + GLINT[1], "foam")
	if frame == 0:
		return
	var centre := middle + KelpieLegend.STAND
	var radii := DEEP * KelpieLegend.RINGS[frame - 1]
	var steps := ceili(TAU * maxf(radii.x, radii.y))
	for k: int in steps:
		var at := centre + Vector2.from_angle(TAU * k / steps) * radii
		if ((at - middle - WATER_AT) / WATER).length_squared() <= 1.0:
			art.plot(Vector2i(at.floor()), "foam")


## The weed: a wet patch of road, with strands of weed lying on it.
static func _draw_weed(art: LegendArt) -> void:
	var middle := Vector2(0.0, -KelpieLegend.WEED.y / 2.0)
	art.ellipse(middle, PATCH, "tunnel road")
	for k: int in range(0, LYING.size() - 1, 2):
		var paint := LYING_COLORS[(k >> 1) % LYING_COLORS.size()]
		art.line(middle + LYING[k], middle + LYING[k + 1], paint)
