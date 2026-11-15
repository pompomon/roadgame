extends RefCounted
## The Mothman's sheets (POOLS_PLAN.md §5.4), drawn into assets/legends/mothman/ by
## tools/art/make_legends.gd. `mothman.png`: a tall dark figure with a great moth's wings, feathered
## feelers and two red eyes, facing the viewer, the same on each side: perched with its wings folded
## about it like a cloak, then standing with them spread, then flying with them raised and its legs
## hanging, then beating them down with its talons closed. It is shadow outlined in ink, with city
## dark veins on its wings, so that at night it shows dark against the city's greys, as its red eyes
## alone would not (tests/unit/test_mothman.gd). `feather.png`: a pale grey feather, city light
## with a shadow quill, tilted left, then right, as it sways down, then lying on the road. Their
## sizes are the legend's (disasters/legends/mothman.gd). No class_name: tools/ is not exported.

const LegendArt := preload("res://tools/art/legend_art.gd")
const MothmanLegend := preload("res://disasters/legends/mothman.gd")
## Its body, in px from its foot: its torso, its head, and the base and tip of its left feeler. The
## eyes are 2 px square, on each side of the legend's EYES, so that their glow lights between them.
const TORSO: Array[Vector2] = [Vector2(-6, -36), Vector2(6, -36), Vector2(4, -11), Vector2(-4, -11)]
const HEAD := Vector2(0.0, -41.0)
const HEAD_RADII := Vector2(5.0, 6.0)
const FEELER: Array[Vector2] = [Vector2(-2, -46), Vector2(-6, -52)]
const EYE := Rect2i(-4, -1, 2, 2)
## Its left wings in each frame, the right ones their mirror images, and their veins, by pairs of
## points: a line from the first of each pair to the second. Folded about it as it perches; spread
## as it stands, the forewing over the hindwing; raised as it flies; and beating down as it carries
## the car off.
const FOLDED: Array[Vector2] = [
	Vector2(-3, -36),
	Vector2(-9, -47),
	Vector2(-13, -38),
	Vector2(-12, -16),
	Vector2(-7, -5),
	Vector2(-3, -9),
]
const FOLDED_VEINS: Array[Vector2] = [
	Vector2(-9, -44), Vector2(-10, -17), Vector2(-5, -37), Vector2(-6, -10)
]
const SPREAD_FORE: Array[Vector2] = [
	Vector2(-5, -37),
	Vector2(-14, -47),
	Vector2(-28, -52),
	Vector2(-34, -46),
	Vector2(-31, -36),
	Vector2(-6, -29),
]
const SPREAD_HIND: Array[Vector2] = [
	Vector2(-6, -30), Vector2(-27, -31), Vector2(-29, -22), Vector2(-20, -14), Vector2(-6, -20)
]
const SPREAD_VEINS: Array[Vector2] = [
	Vector2(-6, -34),
	Vector2(-28, -49),
	Vector2(-6, -32),
	Vector2(-31, -39),
	Vector2(-7, -26),
	Vector2(-26, -24),
]
const RAISED_FORE: Array[Vector2] = [
	Vector2(-5, -36),
	Vector2(-11, -47),
	Vector2(-20, -55),
	Vector2(-27, -54),
	Vector2(-25, -43),
	Vector2(-7, -30),
]
const RAISED_HIND: Array[Vector2] = [
	Vector2(-6, -31), Vector2(-21, -39), Vector2(-25, -31), Vector2(-15, -22), Vector2(-6, -23)
]
const RAISED_VEINS: Array[Vector2] = [
	Vector2(-6, -35),
	Vector2(-22, -52),
	Vector2(-7, -32),
	Vector2(-24, -44),
	Vector2(-7, -28),
	Vector2(-21, -32),
]
const BEATING_FORE: Array[Vector2] = [
	Vector2(-5, -36),
	Vector2(-19, -37),
	Vector2(-33, -31),
	Vector2(-34, -22),
	Vector2(-22, -23),
	Vector2(-6, -29),
]
const BEATING_HIND: Array[Vector2] = [
	Vector2(-6, -29), Vector2(-22, -21), Vector2(-25, -11), Vector2(-14, -9), Vector2(-6, -19)
]
const BEATING_VEINS: Array[Vector2] = [
	Vector2(-6, -34),
	Vector2(-31, -28),
	Vector2(-6, -31),
	Vector2(-28, -23),
	Vector2(-7, -25),
	Vector2(-22, -13),
]
## Its left leg in each frame, a line from one point to the next, down to its talons on its foot's
## row: standing, hanging as it flies, and bent to grip.
const STANDING_LEG: Array[Vector2] = [Vector2(-4, -11), Vector2(-4, -1)]
const HANGING_LEG: Array[Vector2] = [Vector2(-4, -11), Vector2(-6, -1)]
const GRIPPING_LEG: Array[Vector2] = [Vector2(-4, -11), Vector2(-8, -6), Vector2(-6, -1)]
## The feather, tilted left, in px from its foot: its vane, and its quill from the end that it hangs
## from. Tilted right, it is the same with x turned about.
const VANE: Array[Vector2] = [Vector2(5, -2), Vector2(1.5, -8), Vector2(-5, -10), Vector2(-1.5, -4)]
const QUILL: Array[Vector2] = [Vector2(5, -1), Vector2(-4, -9)]
## The feather lying on the road.
const LYING_VANE: Array[Vector2] = [
	Vector2(-7, -2), Vector2(-2, -4.5), Vector2(6, -3.5), Vector2(1, -1)
]
const LYING_QUILL: Array[Vector2] = [Vector2(-7, -1), Vector2(6, -3)]


static func make(dir: String) -> void:
	var mothman := LegendArt.new(MothmanLegend.FRAME, 4)
	for frame: int in 4:
		mothman.frame = frame
		_draw_mothman(mothman, frame)
	mothman.save(dir.path_join("mothman.png"))
	var feather := LegendArt.new(MothmanLegend.FEATHER, 3)
	for frame: int in 3:
		feather.frame = frame
		_draw_feather(feather, frame)
	feather.save(dir.path_join("feather.png"))


## The Mothman in its sheet's `frame`: its left half, then the same mirrored.
static func _draw_mothman(art: LegendArt, frame: int) -> void:
	art.poly(TORSO, "shadow")
	match frame:
		0:
			_draw_wing(art, FOLDED, FOLDED_VEINS)
			_draw_lines(art, STANDING_LEG, "shadow", 2)
		1:
			_draw_wing(art, SPREAD_HIND, [])
			_draw_wing(art, SPREAD_FORE, SPREAD_VEINS)
			_draw_lines(art, STANDING_LEG, "shadow", 2)
		2:
			_draw_wing(art, RAISED_HIND, [])
			_draw_wing(art, RAISED_FORE, RAISED_VEINS)
			_draw_lines(art, HANGING_LEG, "shadow", 2)
		3:
			_draw_wing(art, BEATING_HIND, [])
			_draw_wing(art, BEATING_FORE, BEATING_VEINS)
			_draw_lines(art, GRIPPING_LEG, "shadow", 2)
	art.ellipse(HEAD, HEAD_RADII, "shadow")
	_draw_lines(art, FEELER, "shadow")
	art.rect(Rect2i(Vector2i(MothmanLegend.EYES) + EYE.position, EYE.size), "red")
	art.mirror()
	art.outline()


## A wing, and its veins.
static func _draw_wing(art: LegendArt, wing: Array[Vector2], veins: Array[Vector2]) -> void:
	art.poly(wing, "shadow")
	for k: int in range(0, veins.size() - 1, 2):
		art.line(veins[k], veins[k + 1], "city dark")


## Lines from each of `points` to the next.
static func _draw_lines(
	art: LegendArt, points: Array[Vector2], color_name: String, width := 1
) -> void:
	for k: int in points.size() - 1:
		art.line(points[k], points[k + 1], color_name, width)


## The feather in its sheet's `frame`: tilted left, tilted right, or lying.
static func _draw_feather(art: LegendArt, frame: int) -> void:
	if frame == 2:
		art.poly(LYING_VANE, "city light")
		_draw_lines(art, LYING_QUILL, "shadow")
	else:
		var turn := Vector2(-1.0 if frame == 1 else 1.0, 1.0)
		art.poly(_turned(VANE, turn), "city light")
		_draw_lines(art, _turned(QUILL, turn), "shadow")
	art.outline()


## `points`, each multiplied by `turn`.
static func _turned(points: Array[Vector2], turn: Vector2) -> Array[Vector2]:
	var made: Array[Vector2] = []
	for point: Vector2 in points:
		made.append(point * turn)
	return made
