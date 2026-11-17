extends RefCounted
## The scarecrow's sheets (POOLS_PLAN.md §5.4), drawn into assets/legends/scarecrow/ by
## tools/art/make_legends.gd. `scarecrow.png`: a scarecrow on a plank pole, its arms out along a
## crossbar in the sleeves of a night-blue coat, straw at its cuffs and hem, a rope belt, a pale
## sack for a head and a shadow hat: its head turned away, then turned to the screen's right, then
## facing the viewer with two ink eyes and a stitched grin. It is the same on each side but for its
## face, which only the sack's line colour surrounds, so that tests/unit/test_scarecrow.gd finds
## it. `crow.png`: a crow in shadow, its wings up, level, down and level again. Both are outlined in
## ink, so that they show against the fields at night. Their sizes are the legend's
## (disasters/legends/scarecrow.gd). No class_name: tools/ is not exported.

const LegendArt := preload("res://tools/art/legend_art.gd")
const ScarecrowLegend := preload("res://disasters/legends/scarecrow.gd")
## Its pole, 2 px wide about its middle, and its crossbar along its arms, in px from its foot.
const POLE := Rect2i(-1, -40, 2, 40)
const BAR := Rect2i(-20, -36, 40, 2)
## Its coat: the body, from its shoulders to its hem, and its sleeves along the crossbar.
const COAT: Array[Vector2] = [
	Vector2(-9, -38), Vector2(9, -38), Vector2(12, -14), Vector2(-12, -14)
]
const SLEEVES := Rect2i(-18, -38, 36, 6)
const BELT := Rect2i(-11, -25, 22, 2)
## The straw, by pairs of points: a line from the first of each pair to the second. At its left cuff
## and its hem, the right ones their mirror images.
const STRAW: Array[Vector2] = [
	Vector2(-18, -37),
	Vector2(-21, -39),
	Vector2(-18, -35),
	Vector2(-22, -35),
	Vector2(-18, -33),
	Vector2(-21, -30),
	Vector2(-10, -14),
	Vector2(-11, -10),
	Vector2(-7, -14),
	Vector2(-7, -9),
	Vector2(-4, -14),
	Vector2(-3, -10),
]
## Its head, a sack tied at the neck, and its hat: the brim, the crown and its band.
const HEAD := Vector2(0.0, -43.0)
const HEAD_RADII := Vector2(5.0, 5.5)
const NECK := Rect2i(-3, -38, 6, 1)
const BRIM := Rect2i(-9, -49, 18, 2)
const CROWN := Rect2i(-5, -55, 10, 6)
const BAND := Rect2i(-5, -51, 10, 1)
## Its face, facing the viewer: its left eye, and its grin and a stitch across it, the right ones
## their mirror images. Turned to the screen's right, its eyes and grin, nearer together.
const EYE := Rect2i(-4, -46, 2, 2)
const GRIN := Rect2i(-3, -41, 3, 1)
const STITCH := Rect2i(-2, -40, 1, 1)
const TURNED_EYES: Array[Rect2i] = [Rect2i(-1, -46, 2, 2), Rect2i(3, -46, 1, 2)]
const TURNED_GRIN := Rect2i(0, -41, 4, 1)
const TURNED_STITCH := Rect2i(2, -40, 1, 1)
## The crow, in px from its foot: its body, and its left wing, a line from one point to the next,
## the right one its mirror image: up, level and down.
const BODY := Vector2(0.0, -4.5)
const BODY_RADII := Vector2(2.0, 2.5)
const WING_UP: Array[Vector2] = [Vector2(-2, -5), Vector2(-4, -7), Vector2(-6, -9)]
const WING_LEVEL: Array[Vector2] = [Vector2(-2, -5), Vector2(-4, -6), Vector2(-6, -6)]
const WING_DOWN: Array[Vector2] = [Vector2(-2, -5), Vector2(-4, -4), Vector2(-6, -2)]


static func make(dir: String) -> void:
	var scarecrow := LegendArt.new(ScarecrowLegend.FRAME, ScarecrowLegend.Head.size())
	for frame: int in ScarecrowLegend.Head.size():
		scarecrow.frame = frame
		_draw_scarecrow(scarecrow, frame)
	scarecrow.save(dir.path_join("scarecrow.png"))
	var crow := LegendArt.new(ScarecrowLegend.CROW, ScarecrowLegend.CROW_FRAMES)
	for frame: int in ScarecrowLegend.CROW_FRAMES:
		crow.frame = frame
		_draw_crow(crow, frame)
	crow.save(dir.path_join("crow.png"))


## The scarecrow in its sheet's `frame`: its left half, then the same mirrored, then its face.
static func _draw_scarecrow(art: LegendArt, frame: int) -> void:
	art.rect(POLE, "plank")
	art.rect(BAR, "plank")
	art.poly(COAT, "night")
	art.rect(SLEEVES, "night")
	art.rect(BELT, "plank")
	for k: int in range(0, STRAW.size() - 1, 2):
		art.line(STRAW[k], STRAW[k + 1], "yellow")
	art.ellipse(HEAD, HEAD_RADII, "line")
	art.rect(NECK, "plank")
	art.rect(BRIM, "shadow")
	art.rect(CROWN, "shadow")
	art.rect(BAND, "plank")
	if frame == ScarecrowLegend.Head.FACING:
		art.rect(EYE, "ink")
		art.rect(GRIN, "ink")
		art.rect(STITCH, "ink")
	art.mirror()
	if frame == ScarecrowLegend.Head.TURNED:
		for eye: Rect2i in TURNED_EYES:
			art.rect(eye, "ink")
		art.rect(TURNED_GRIN, "ink")
		art.rect(TURNED_STITCH, "ink")
	art.outline()


## The crow in its sheet's `frame`: its wings up, level, down, then level again.
static func _draw_crow(art: LegendArt, frame: int) -> void:
	art.ellipse(BODY, BODY_RADII, "shadow")
	var wing := WING_LEVEL
	if frame == 0:
		wing = WING_UP
	elif frame == 2:
		wing = WING_DOWN
	for k: int in wing.size() - 1:
		art.line(wing[k], wing[k + 1], "shadow", 2 if k == 0 else 1)
	art.mirror()
	art.outline()
