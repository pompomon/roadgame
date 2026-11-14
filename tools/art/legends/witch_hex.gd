extends RefCounted
## The witch's hex's sheets (docs/M6.md §3.3), drawn into assets/legends/witch_hex/ by
## tools/art/make_legends.gd. `witch.png`: a hunched witch on a broomstick, facing right, flying
## with a hand on the broom, then pointing a long pale finger: a violet cloak and a pointed hat
## with an ink band, a face in shadow with wisp eyes, on a plank broom with straw bristles. She is
## drawn in flat colours, with no side lit, so that flip_h may face her left. `pumpkin.png`: a
## jack-o'-lantern with an ink grin, then the same grin lit yellow from within: a fire pumpkin with
## village roof ribs, in shade on its right and below, as the car is lit from the upper left, under
## a desert cactus stalk. Their sizes are the legend's (disasters/legends/witch_hex.gd). No
## class_name: tools/ is not exported.

const LegendArt := preload("res://tools/art/legend_art.gd")
const WitchHexLegend := preload("res://disasters/legends/witch_hex.gd")
## The witch's parts, in px from her foot: her broom's bristles, her cloak billowing behind her as
## she flies, and her hat, its tip bent back.
const BRISTLES: Array[Vector2] = [
	Vector2(-9, -8), Vector2(-15, -11), Vector2(-15, -2), Vector2(-9, -5)
]
const CLOAK: Array[Vector2] = [
	Vector2(-12, -10),
	Vector2(-8, -13),
	Vector2(-4, -16),
	Vector2(1, -17),
	Vector2(5, -14),
	Vector2(6, -7),
	Vector2(-6, -6),
]
const HAT: Array[Vector2] = [Vector2(0, -20), Vector2(7, -20), Vector2(-3, -24)]
## Where her shoulder is: her arm starts there.
const SHOULDER := Vector2(3.0, -13.0)
## The jack-o'-lantern's body: its centre, from its foot, and radii; its lit part's, the rest in
## shade. Its eyes and its jagged grin.
const BODY := Vector2(0.0, -8.0)
const BODY_RADII := Vector2(10.5, 7.5)
const LIT := Vector2(-1.5, -9.0)
const LIT_RADII := Vector2(8.5, 6.0)
const LEFT_EYE: Array[Vector2] = [Vector2(-7, -10), Vector2(-2, -10), Vector2(-5, -14)]
const RIGHT_EYE: Array[Vector2] = [Vector2(2, -10), Vector2(7, -10), Vector2(4, -14)]
const GRIN: Array[Vector2] = [
	Vector2(-8, -7),
	Vector2(-4, -6),
	Vector2(0, -7),
	Vector2(4, -6),
	Vector2(8, -7),
	Vector2(6, -3),
	Vector2(0, -2),
	Vector2(-6, -3),
]


static func make(dir: String) -> void:
	var witch := LegendArt.new(WitchHexLegend.WITCH, 2)
	for frame: int in 2:
		witch.frame = frame
		_draw_witch(witch, frame == 1)
	witch.save(dir.path_join("witch.png"))
	var pumpkin := LegendArt.new(WitchHexLegend.PUMPKIN, 2)
	for frame: int in 2:
		pumpkin.frame = frame
		_draw_pumpkin(pumpkin, "yellow" if frame == 1 else "ink")
	pumpkin.save(dir.path_join("pumpkin.png"))


## The witch on her broom, her hand on it, or `pointing` with a long finger, its tip at the
## legend's FINGER.
static func _draw_witch(art: LegendArt, pointing: bool) -> void:
	art.poly(BRISTLES, "rural dark")
	art.line(Vector2(-14, -8), Vector2(-10, -7), "rural dirt")
	art.line(Vector2(-14, -4), Vector2(-10, -6), "rural dirt")
	art.line(Vector2(-9, -6), Vector2(12, -8), "plank")
	art.poly(CLOAK, "violet")
	art.ellipse(Vector2(3.5, -17.0), Vector2(2.5, 2.5), "shadow")
	art.line(Vector2(5, -17), Vector2(7, -15), "shadow")
	art.plot(Vector2i(4, -18), "wisp")
	art.plot(Vector2i(2, -18), "wisp")
	art.poly(HAT, "violet")
	art.rect(Rect2i(-1, -20, 9, 1), "violet")
	art.rect(Rect2i(0, -21, 6, 1), "ink")
	if pointing:
		var finger := Vector2(WitchHexLegend.FINGER)
		var hand := finger - Vector2(5.0, 0.0)
		art.line(SHOULDER, hand - Vector2(1.0, 0.0), "violet", 2)
		art.rect(Rect2i(Vector2i(hand) + Vector2i(0, -1), Vector2i(2, 2)), "line")
		art.line(hand + Vector2(2.0, 0.0), finger, "line")
	else:
		art.line(SHOULDER, Vector2(7, -9), "violet", 2)
		art.rect(Rect2i(7, -9, 2, 2), "line")
	art.outline()


## The jack-o'-lantern, its eyes and grin in `face`.
static func _draw_pumpkin(art: LegendArt, face: String) -> void:
	art.ellipse(BODY, BODY_RADII, "village roof")
	art.ellipse(LIT, LIT_RADII, "fire")
	for rib: float in [-4.0, 3.0]:
		art.line(Vector2(rib, -15), Vector2(rib - 1.0, -9), "village roof")
		art.line(Vector2(rib - 1.0, -9), Vector2(rib, -2), "village roof")
	art.poly(LEFT_EYE, face)
	art.poly(RIGHT_EYE, face)
	art.poly(GRIN, face)
	# Two teeth: one hangs from the top of the grin, one stands on its bottom.
	art.rect(Rect2i(-3, -6, 2, 1), "fire")
	art.rect(Rect2i(2, -4, 2, 1), "fire")
	art.rect(Rect2i(-1, -18, 2, 3), "desert cactus")
	art.plot(Vector2i(1, -19), "desert cactus")
	art.outline()
