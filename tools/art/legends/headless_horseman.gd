extends RefCounted
## The Headless Horseman's sheets (docs/POOLS.md §5.4), drawn into
## assets/legends/headless_horseman/ by tools/art/make_legends.gd. `horseman.png`: a rider in a
## dark cloak on a black horse that faces the screen's right, his high collar open on nothing where
## his head should be; the horse gallops, its legs stretched and then gathered, and stands, as the
## rider raises his hand and then throws it out. `ghost_fire.png`: a ball of pale ghost-fire, and
## then its flames over a car, more and more. `hoofprints.png`: the scorched prints of the horse's
## hooves along the tile x axis, in pairs, the first 1 to 5 strides of them. The horse, the cloak
## and the prints are dark and the bridle, the collar and the fire pale, so they stand out from the
## fields by night (§5.6). There's no gore. Its sizes are the legend's (disasters/legends/
## headless_horseman.gd). No class_name: tools/ is not exported.

const LegendArt := preload("res://tools/art/legend_art.gd")
const HorsemanLegend := preload("res://disasters/legends/headless_horseman.gd")
## The horse, in px from the Horseman's foot: its barrel, chest and rump, ovals about their
## middles; its neck, its head and its ears; its eye, which glows; and its mane, along its neck.
const BARREL := Vector2(0.0, -24.0)
const BARREL_RADII := Vector2(13.0, 6.0)
const CHEST := Vector2(9.0, -25.0)
const RUMP := Vector2(-10.0, -25.0)
const ROUND_RADII := Vector2(6.0, 6.0)
const NECK: Array[Vector2] = [
	Vector2(6, -29), Vector2(13, -40), Vector2(18, -43), Vector2(21, -37), Vector2(15, -24)
]
const HEAD: Array[Vector2] = [
	Vector2(16, -43),
	Vector2(20, -45),
	Vector2(28, -37),
	Vector2(27, -33),
	Vector2(23, -33),
	Vector2(18, -37),
]
const EARS: Array[Vector2] = [Vector2(17, -44), Vector2(18, -48), Vector2(20, -44)]
const EYE := Vector2i(21, -41)
const MANE: Array[Vector2] = [Vector2(7, -31), Vector2(16, -44)]
## The horse's tail, by the Horseman's frame, a line from its root: streaming out behind as he
## gallops, and hanging as he stands.
const TAIL_GALLOP: Array[Vector2] = [Vector2(-15, -28), Vector2(-21, -27), Vector2(-26, -22)]
const TAIL_STAND: Array[Vector2] = [Vector2(-15, -28), Vector2(-18, -22), Vector2(-18, -13)]
## The horse's legs, by the Horseman's frame, each a line from its barrel by its knee or hock to its
## hoof, LEG_WIDTH px wide: the far fore and hind legs, in shade, and then the near ones. They
## stretch out and then gather under him as he gallops, a hoof on the ground in each, the near hind
## pushing off and then the near fore landing; he stands as he raises and hurls the fire.
const LEG_WIDTH := 2
const FAR_LEGS: Dictionary[int, Array] = {
	HorsemanLegend.Pose.GALLOP_A:
	[
		[Vector2(8, -20), Vector2(14, -12), Vector2(19, -7)],
		[Vector2(-12, -20), Vector2(-18, -13), Vector2(-25, -10)],
	],
	HorsemanLegend.Pose.GALLOP_B:
	[
		[Vector2(8, -20), Vector2(3, -13), Vector2(5, -7)],
		[Vector2(-12, -20), Vector2(-7, -13), Vector2(-5, -6)],
	],
	HorsemanLegend.Pose.STAND:
	[
		[Vector2(7, -20), Vector2(7, -11), Vector2(6, -2)],
		[Vector2(-12, -20), Vector2(-14, -11), Vector2(-13, -2)],
	],
}
const NEAR_LEGS: Dictionary[int, Array] = {
	HorsemanLegend.Pose.GALLOP_A:
	[
		[Vector2(11, -20), Vector2(18, -13), Vector2(24, -9)],
		[Vector2(-9, -20), Vector2(-13, -11), Vector2(-17, -2)],
	],
	HorsemanLegend.Pose.GALLOP_B:
	[
		[Vector2(10, -20), Vector2(8, -11), Vector2(11, -2)],
		[Vector2(-9, -20), Vector2(-4, -12), Vector2(-1, -5)],
	],
	HorsemanLegend.Pose.STAND:
	[
		[Vector2(10, -20), Vector2(10, -11), Vector2(10, -2)],
		[Vector2(-9, -20), Vector2(-11, -11), Vector2(-10, -2)],
	],
}
## The bridle, from the horse's poll by its cheek to its nose, and the reins, from its nose to the
## rider's hand, which holds them at REINS_HAND as he gallops and stands, and at REINS_LOW as he
## raises and hurls the fire with his other hand.
const BRIDLE: Array[Vector2] = [Vector2(19, -43), Vector2(24, -36), Vector2(27, -35)]
const BIT := Vector2(24, -35)
const REINS_HAND := Vector2(9, -38)
const REINS_LOW := Vector2(5, -37)
## The rider, in px from the Horseman's foot: his body, from his shoulders to his seat; his cloak,
## from his shoulders, billowing out behind him as he gallops and hanging as he stands, its hem
## ragged; his collar, a band over his shoulders, open on nothing, its rim and the dark of its
## hollow ovals about its middle, seen from a little above; his saddle; and his leg, his boot and
## its stirrup.
const BODY: Array[Vector2] = [
	Vector2(-4, -46),
	Vector2(3, -46),
	Vector2(5, -42),
	Vector2(4, -36),
	Vector2(6, -32),
	Vector2(-6, -32),
	Vector2(-5, -38),
	Vector2(-6, -43),
]
const CAPE_GALLOP: Array[Vector2] = [
	Vector2(-2, -46),
	Vector2(-12, -45),
	Vector2(-21, -41),
	Vector2(-26, -36),
	Vector2(-22, -37),
	Vector2(-19, -33),
	Vector2(-15, -36),
	Vector2(-11, -32),
	Vector2(-6, -38),
]
const CAPE_STAND: Array[Vector2] = [
	Vector2(-2, -46),
	Vector2(-8, -44),
	Vector2(-11, -37),
	Vector2(-12, -28),
	Vector2(-10, -30),
	Vector2(-8, -27),
	Vector2(-6, -31),
]
const COLLAR := Rect2i(-5, -48, 9, 2)
const RIM := Vector2(-0.5, -48.0)
const RIM_RADII := Vector2(4.5, 1.5)
const HOLLOW_RADII := Vector2(3.0, 0.9)
const SADDLE := Rect2i(-8, -33, 14, 2)
const LEG: Array[Vector2] = [Vector2(-1, -34), Vector2(4, -34), Vector2(5, -25), Vector2(1, -25)]
const BOOT := Rect2i(1, -26, 5, 3)
const STIRRUP := Rect2i(1, -23, 5, 1)
## His near arm, by the Horseman's frame, a line from his shoulder ARM_WIDTH px wide, and his hand:
## holding the reins as he gallops and stands, raised as he raises the fire, the hand about
## HorsemanLegend.HAND, and thrown out as he hurls it.
const ARM_WIDTH := 2
const SHOULDER := Vector2(2, -44)
const REACH: Dictionary[int, Vector2] = {
	HorsemanLegend.Pose.STAND: Vector2(8, -38),
	HorsemanLegend.Pose.RAISE: Vector2(9, -56),
	HorsemanLegend.Pose.HURL: Vector2(14, -43),
}
const HAND_AT: Dictionary[int, Rect2i] = {
	HorsemanLegend.Pose.STAND: Rect2i(8, -39, 3, 2),
	HorsemanLegend.Pose.RAISE: Rect2i(9, -59, 3, 3),
	HorsemanLegend.Pose.HURL: Rect2i(14, -44, 3, 2),
}
## The ghost-fire, in px from its frame's foot: the ball, about the frame's middle, its core and
## the flame that it tapers to, up to its tip; and the flames over the car, whose middle is the
## frame's middle, each by its foot, from the middle, and its height, the first KINDLED[frame] of
## them by the fire's frame, their feet ovals that run together, and the embers over them.
const MIDDLE := Vector2(0.0, -20.0)
const BALL_RADII := Vector2(5.0, 5.0)
const CORE_RADII := Vector2(2.5, 2.5)
const BALL_TIP: Array[Vector2] = [
	Vector2(-4.5, -22), Vector2(-2, -27), Vector2(0, -32), Vector2(2, -27), Vector2(4.5, -22)
]
const TONGUES: Array[Vector3] = [
	Vector3(0, 4, 11),
	Vector3(-4, 5, 8),
	Vector3(4, 3, 8),
	Vector3(-9, 6, 9),
	Vector3(9, 2, 9),
	Vector3(-1, -2, 7),
	Vector3(-14, 7, 6),
	Vector3(14, 1, 7),
	Vector3(-7, -1, 7),
	Vector3(7, -4, 6),
]
const TONGUE_HALF := 3.0
const TONGUE_FOOT_RADII := Vector2(3.5, 2.0)
const KINDLED: Dictionary[int, int] = {
	HorsemanLegend.Fire.KINDLE_A: 3,
	HorsemanLegend.Fire.KINDLE_B: 6,
	HorsemanLegend.Fire.KINDLE_C: 10,
}
const EMBERS: Array[Vector2i] = [
	Vector2i(-5, -33), Vector2i(3, -35), Vector2i(10, -31), Vector2i(-11, -29)
]
## The hoofprints, in tiles from the middle of the stretch that they lie on, along the tile x axis
## from the end where he halted: each stride's pair, either side of the road's middle, one a little
## ahead of the other; and in px, each print's radii, and its scorched middle's, set back towards
## its heel, so that its toe shows as a dark crescent, with an ember in it.
const PRINT_ACROSS := 0.07
const PRINT_AHEAD := 0.04
const PRINT_RADII := Vector2(3.5, 2.2)
const SCORCH_RADII := Vector2(2.2, 1.2)
const HEEL := Vector2(-1.0, -0.5)


static func make(dir: String) -> void:
	var horseman := LegendArt.new(HorsemanLegend.RIDER, HorsemanLegend.Pose.size())
	for pose: int in HorsemanLegend.Pose.size():
		horseman.frame = pose
		_draw_horseman(horseman, pose)
	horseman.save(dir.path_join("horseman.png"))
	var fire := LegendArt.new(HorsemanLegend.FIRE, HorsemanLegend.Fire.size())
	for kindled: int in HorsemanLegend.Fire.size():
		fire.frame = kindled
		_draw_fire(fire, kindled)
	fire.save(dir.path_join("ghost_fire.png"))
	var hoofprints := LegendArt.new(HorsemanLegend.PRINTS, HorsemanLegend.STRIDES)
	for strides: int in HorsemanLegend.STRIDES:
		hoofprints.frame = strides
		_draw_prints(hoofprints, strides + 1)
	hoofprints.save(dir.path_join("hoofprints.png"))


static func _draw_horseman(art: LegendArt, pose: int) -> void:
	var galloping := pose == HorsemanLegend.Pose.GALLOP_A or pose == HorsemanLegend.Pose.GALLOP_B
	var legs := pose if galloping else HorsemanLegend.Pose.STAND
	var arm := pose if pose >= HorsemanLegend.Pose.RAISE else HorsemanLegend.Pose.STAND
	for leg: Array in FAR_LEGS[legs]:
		_draw_leg(art, leg, "shadow")
	art.ellipse(BARREL, BARREL_RADII, "ink")
	art.ellipse(CHEST, ROUND_RADII, "ink")
	art.ellipse(RUMP, ROUND_RADII, "ink")
	art.poly(NECK, "ink")
	art.poly(HEAD, "ink")
	art.poly(EARS, "ink")
	art.line(MANE[0], MANE[1], "shadow", 2)
	_draw_leg(art, TAIL_GALLOP if galloping else TAIL_STAND, "ink")
	for leg: Array in NEAR_LEGS[legs]:
		_draw_leg(art, leg, "ink")
	art.plot(EYE, "wisp")
	for k: int in BRIDLE.size() - 1:
		art.line(BRIDLE[k], BRIDLE[k + 1], "line")
	art.line(BIT, REINS_HAND if arm == HorsemanLegend.Pose.STAND else REINS_LOW, "line")
	art.poly(CAPE_GALLOP if galloping else CAPE_STAND, "night")
	art.poly(BODY, "night")
	art.rect(SADDLE, "shadow")
	art.poly(LEG, "night")
	art.rect(BOOT, "shadow")
	art.rect(STIRRUP, "line")
	art.line(SHOULDER, REACH[arm], "night", ARM_WIDTH)
	art.rect(HAND_AT[arm], "line")
	art.rect(COLLAR, "night")
	art.ellipse(RIM, RIM_RADII, "shadow")
	art.ellipse(RIM, HOLLOW_RADII, "ink")
	art.outline()


## A leg or the tail, its points joined by lines LEG_WIDTH px wide.
static func _draw_leg(art: LegendArt, points: Array, color_name: String) -> void:
	for k: int in points.size() - 1:
		art.line(points[k], points[k + 1], color_name, LEG_WIDTH)


## The ball, or its flames over the car: pale, their cores white.
static func _draw_fire(art: LegendArt, kindled: int) -> void:
	if kindled == HorsemanLegend.Fire.BALL:
		art.poly(BALL_TIP, "wisp")
		art.ellipse(MIDDLE, BALL_RADII, "wisp")
		art.ellipse(MIDDLE + Vector2(0.0, 1.0), CORE_RADII, "white")
	else:
		for k: int in KINDLED[kindled]:
			_draw_tongue(art, TONGUES[k])
		if kindled == HorsemanLegend.Fire.KINDLE_C:
			for ember: Vector2i in EMBERS:
				art.plot(ember, "wisp")
	art.outline()


## A tongue of flame, `tongue` its foot's x and y from the middle and its height: pale, wavering to
## its tip from its round foot, a white core up its middle.
static func _draw_tongue(art: LegendArt, tongue: Vector3) -> void:
	var foot := MIDDLE + Vector2(tongue.x, tongue.y)
	var height := tongue.z
	var flame: Array[Vector2] = [
		foot + Vector2(-TONGUE_HALF, 0.0),
		foot + Vector2(-TONGUE_HALF + 1.0, -height * 0.6),
		foot + Vector2(-0.5, -height * 0.55),
		foot + Vector2(0.0, -height),
		foot + Vector2(TONGUE_HALF - 1.0, -height * 0.5),
		foot + Vector2(TONGUE_HALF, 0.0),
	]
	art.poly(flame, "wisp")
	art.ellipse(foot, TONGUE_FOOT_RADII, "wisp")
	art.line(foot + Vector2(0.0, -1.0), foot + Vector2(0.0, -height * 0.5), "white")


## The first `strides` strides of hoofprints, from the end where he halted.
static func _draw_prints(art: LegendArt, strides: int) -> void:
	var step := HorsemanLegend.PRINTS_TILES / HorsemanLegend.STRIDES
	for k: int in strides:
		var along := -HorsemanLegend.PRINTS_TILES / 2.0 + (k + 0.5) * step
		_draw_print(art, _at(along - PRINT_AHEAD, -PRINT_ACROSS))
		_draw_print(art, _at(along + PRINT_AHEAD, PRINT_ACROSS))


## A scorched hoofprint about `at`, dark, an ember in its middle.
static func _draw_print(art: LegendArt, at: Vector2) -> void:
	art.ellipse(at, PRINT_RADII, "ink")
	art.ellipse(at + HEEL, SCORCH_RADII, "shadow")
	art.plot(Vector2i((at + HEEL).floor()), "wisp")


## The point `along` and `across` tiles from the stretch's middle, in px from its frame's foot.
static func _at(along: float, across: float) -> Vector2:
	var middle := Vector2(0.0, -HorsemanLegend.PRINTS.y / 2.0)
	return middle + Iso.tile_to_world(Vector2(along, across))
