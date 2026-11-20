extends RefCounted
## The Vanishing Hitchhiker's sheet (docs/ENDGAME.md §5.17), drawn into assets/legends/hitchhiker/
## by tools/art/make_legends.gd. `hitchhiker.png`: a girl in a white dress, her long hair in shadow,
## her left arm down and her right held out to the screen's right, its thumb up, as a hitchhiker
## asks for a ride. She is outlined in ink, and her hair, her eyes and her shoes are dark, so that
## she shows by the road at night. Her one frame's size is hers (world/hitchhiker.gd). No
## class_name: tools/ is not exported.

const LegendArt := preload("res://tools/art/legend_art.gd")
const HitchhikerScript := preload("res://world/hitchhiker.gd")
## Her hair, behind her head and down to her shoulders, in px from her foot.
const HAIR := Vector2(0.0, -32.0)
const HAIR_RADII := Vector2(4.5, 5.0)
const LOCKS: Array[Rect2i] = [Rect2i(-5, -32, 2, 8), Rect2i(3, -32, 2, 8)]
## Her arms, each a line 2 px wide from her shoulder: the left one down, the right one held out, its
## fist and its thumb up.
const ARM_DOWN: Array[Vector2] = [Vector2(-6, -24), Vector2(-8, -15)]
const ARM_OUT: Array[Vector2] = [Vector2(4, -24), Vector2(10, -22)]
const FIST := Rect2i(10, -24, 2, 3)
const THUMB := Rect2i(11, -27, 1, 3)
## Her dress, from her shoulders to her knees, and its folds, by pairs of points.
const DRESS: Array[Vector2] = [Vector2(-4, -25), Vector2(4, -25), Vector2(7, -9), Vector2(-7, -9)]
const FOLDS: Array[Vector2] = [Vector2(-2, -18), Vector2(-3, -10), Vector2(2, -18), Vector2(3, -10)]
## Her legs and her shoes.
const LEGS: Array[Rect2i] = [Rect2i(-3, -9, 2, 7), Rect2i(1, -9, 2, 7)]
const SHOES: Array[Rect2i] = [Rect2i(-4, -2, 3, 2), Rect2i(1, -2, 3, 2)]
## Her neck, her face and her eyes.
const NECK := Rect2i(-1, -27, 2, 2)
const FACE := Vector2(0.0, -30.5)
const FACE_RADII := Vector2(3.0, 3.5)
const EYES: Array[Vector2i] = [Vector2i(-2, -31), Vector2i(1, -31)]


static func make(dir: String) -> void:
	var art := LegendArt.new(HitchhikerScript.FRAME)
	art.ellipse(HAIR, HAIR_RADII, "shadow")
	for lock: Rect2i in LOCKS:
		art.rect(lock, "shadow")
	art.line(ARM_DOWN[0], ARM_DOWN[1], "village light", 2)
	art.line(ARM_OUT[0], ARM_OUT[1], "village light", 2)
	art.rect(FIST, "village light")
	art.rect(THUMB, "village light")
	art.poly(DRESS, "white")
	for k: int in range(0, FOLDS.size() - 1, 2):
		art.line(FOLDS[k], FOLDS[k + 1], "line")
	for leg: Rect2i in LEGS:
		art.rect(leg, "village light")
	for shoe: Rect2i in SHOES:
		art.rect(shoe, "shadow")
	art.rect(NECK, "village light")
	art.ellipse(FACE, FACE_RADII, "village light")
	for eye: Vector2i in EYES:
		art.plot(eye, "ink")
	art.outline()
	art.save(dir.path_join("hitchhiker.png"))
