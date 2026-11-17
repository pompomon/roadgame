extends RefCounted
## The chupacabra's sheets (POOLS_PLAN.md §5.4), drawn into assets/legends/chupacabra/ by
## tools/art/make_legends.gd. `beast.png`: a hairless grey beast that faces the screen's right, a
## ridge of pale spines down its back, its eyes red: creeping, its near legs forward and then its
## far ones; crouched to spring, its spines up; leaping, stretched out; and perched, hunched. The
## beast is dark, so it stands out from the desert by night (§5.6). `husk.png`: the first row of the
## car's sheet, assets/car/car.png, each frame and the wreck drained to greys, so it is drawn again
## if the car's sheet changes. There's no blood. Its sizes are the legend's (disasters/legends/
## chupacabra.gd) and the car's (car/car_controller.gd). No class_name: tools/ is not exported.

const LegendArt := preload("res://tools/art/legend_art.gd")
const ChupacabraLegend := preload("res://disasters/legends/chupacabra.gd")
const CAR_SHEET := "res://assets/car/car.png"
## What each of the car's colours drains to: its paint and its glass to greys, and its lights and
## tyres to shade. Its darkest stay as they are.
const DRAINED: Dictionary[String, String] = {
	"red": "city dark",
	"village roof": "shadow",
	"foam": "city light",
	"white": "city light",
	"fire": "shadow",
	"yellow": "shadow",
	"asphalt": "shadow",
	"asphalt light": "shadow",
	"ink": "ink",
	"tunnel road": "tunnel road",
	"shadow": "shadow",
}
## The beast, by its pose, in px from its foot; both creeping poses have the body of CREEP_A. Its
## haunch and its chest, ovals, each its middle and its radii.
const HAUNCH: Dictionary[int, Array] = {
	ChupacabraLegend.Pose.CREEP_A: [Vector2(-8, -13), Vector2(7, 6)],
	ChupacabraLegend.Pose.CROUCH: [Vector2(-8, -11), Vector2(7, 6)],
	ChupacabraLegend.Pose.LEAP: [Vector2(-8, -17), Vector2(6, 5)],
	ChupacabraLegend.Pose.PERCH: [Vector2(-5, -9), Vector2(7, 7)],
}
const CHEST: Dictionary[int, Array] = {
	ChupacabraLegend.Pose.CREEP_A: [Vector2(3, -12), Vector2(8, 5)],
	ChupacabraLegend.Pose.CROUCH: [Vector2(3, -9), Vector2(8, 4.5)],
	ChupacabraLegend.Pose.LEAP: [Vector2(4, -18), Vector2(9, 4.5)],
	ChupacabraLegend.Pose.PERCH: [Vector2(1, -15), Vector2(6, 7.5)],
}
## Its back, between them; its head, its snout to the right; and its ear.
const BACK: Dictionary[int, Array] = {
	ChupacabraLegend.Pose.CREEP_A:
	[Vector2(-8, -19), Vector2(3, -17), Vector2(3, -11), Vector2(-8, -11)],
	ChupacabraLegend.Pose.CROUCH:
	[Vector2(-8, -17), Vector2(3, -13), Vector2(3, -9), Vector2(-8, -9)],
	ChupacabraLegend.Pose.LEAP:
	[Vector2(-8, -22), Vector2(4, -22), Vector2(4, -14), Vector2(-8, -13)],
	ChupacabraLegend.Pose.PERCH:
	[Vector2(-10, -13), Vector2(-4, -20), Vector2(1, -22), Vector2(1, -10), Vector2(-5, -8)],
}
const HEAD: Dictionary[int, Array] = {
	ChupacabraLegend.Pose.CREEP_A:
	[
		Vector2(8, -16),
		Vector2(13, -17),
		Vector2(19, -14),
		Vector2(21, -11),
		Vector2(17, -10),
		Vector2(12, -9),
		Vector2(8, -10),
	],
	ChupacabraLegend.Pose.CROUCH:
	[
		Vector2(8, -13),
		Vector2(13, -13),
		Vector2(19, -10),
		Vector2(21, -7),
		Vector2(17, -6),
		Vector2(12, -5),
		Vector2(8, -7),
	],
	ChupacabraLegend.Pose.LEAP:
	[
		Vector2(10, -22),
		Vector2(15, -24),
		Vector2(21, -23),
		Vector2(23, -20),
		Vector2(19, -18),
		Vector2(14, -18),
		Vector2(10, -19),
	],
	ChupacabraLegend.Pose.PERCH:
	[
		Vector2(3, -24),
		Vector2(8, -26),
		Vector2(13, -22),
		Vector2(16, -18),
		Vector2(12, -17),
		Vector2(8, -19),
		Vector2(3, -20),
	],
}
const EAR: Dictionary[int, Array] = {
	ChupacabraLegend.Pose.CREEP_A: [Vector2(11, -16), Vector2(10, -22), Vector2(14, -17)],
	ChupacabraLegend.Pose.CROUCH: [Vector2(11, -13), Vector2(9, -19), Vector2(14, -14)],
	ChupacabraLegend.Pose.LEAP: [Vector2(12, -23), Vector2(8, -27), Vector2(14, -24)],
	ChupacabraLegend.Pose.PERCH: [Vector2(5, -25), Vector2(2, -31), Vector2(8, -26)],
}
## Its eye's left pixel; the eye is EYE_SIZE.
const EYE: Dictionary[int, Vector2i] = {
	ChupacabraLegend.Pose.CREEP_A: Vector2i(16, -14),
	ChupacabraLegend.Pose.CROUCH: Vector2i(16, -10),
	ChupacabraLegend.Pose.LEAP: Vector2i(17, -22),
	ChupacabraLegend.Pose.PERCH: Vector2i(9, -23),
}
const EYE_SIZE := Vector2i(2, 1)
## Its spines, each from its foot on its back to its tip, SPINE_HALF px each side of its foot: up as
## it crouches, flat as it leaps.
const SPINES: Dictionary[int, Array] = {
	ChupacabraLegend.Pose.CREEP_A:
	[
		[Vector2(-12, -18), Vector2(-13, -22)],
		[Vector2(-8, -19), Vector2(-9, -24)],
		[Vector2(-4, -18), Vector2(-5, -23)],
		[Vector2(0, -17), Vector2(-1, -21)],
		[Vector2(4, -17), Vector2(3, -20)],
	],
	ChupacabraLegend.Pose.CROUCH:
	[
		[Vector2(-12, -16), Vector2(-13, -22)],
		[Vector2(-8, -17), Vector2(-9, -24)],
		[Vector2(-4, -16), Vector2(-5, -23)],
		[Vector2(0, -14), Vector2(-1, -20)],
		[Vector2(4, -13), Vector2(3, -18)],
	],
	ChupacabraLegend.Pose.LEAP:
	[
		[Vector2(-11, -21), Vector2(-13, -24)],
		[Vector2(-7, -22), Vector2(-9, -25)],
		[Vector2(-3, -22), Vector2(-5, -25)],
		[Vector2(1, -22), Vector2(-1, -25)],
		[Vector2(5, -22), Vector2(3, -24)],
	],
	ChupacabraLegend.Pose.PERCH:
	[
		[Vector2(-11, -12), Vector2(-15, -14)],
		[Vector2(-9, -15), Vector2(-13, -18)],
		[Vector2(-6, -18), Vector2(-9, -22)],
		[Vector2(-2, -21), Vector2(-4, -26)],
		[Vector2(2, -22), Vector2(1, -27)],
	],
}
const SPINE_HALF := 1.5
## Its tail, a line through these points: low as it creeps, raised as it crouches, streaming as it
## leaps, and curled as it perches.
const TAIL: Dictionary[int, Array] = {
	ChupacabraLegend.Pose.CREEP_A: [Vector2(-14, -14), Vector2(-19, -11), Vector2(-23, -12)],
	ChupacabraLegend.Pose.CROUCH: [Vector2(-14, -12), Vector2(-19, -14), Vector2(-22, -18)],
	ChupacabraLegend.Pose.LEAP: [Vector2(-13, -18), Vector2(-19, -20), Vector2(-23, -19)],
	ChupacabraLegend.Pose.PERCH:
	[Vector2(-11, -6), Vector2(-16, -3), Vector2(-20, -5), Vector2(-21, -9)],
}
## Its legs, by its pose, each a line from its hip or shoulder by its hock or elbow to its foot,
## LEG_WIDTH px wide, a foot on the bottom row in each: the far hind and fore legs, in shade, and
## then the near ones. They take turns as it creeps, fold as it crouches and perches, and stretch as
## it leaps, its hind feet pushing off.
const LEG_WIDTH := 2
const FAR_LEGS: Dictionary[int, Array] = {
	ChupacabraLegend.Pose.CREEP_A:
	[
		[Vector2(-8, -9), Vector2(-9, -5), Vector2(-6, -2)],
		[Vector2(4, -9), Vector2(3, -5), Vector2(2, -2)],
	],
	ChupacabraLegend.Pose.CREEP_B:
	[
		[Vector2(-8, -9), Vector2(-13, -6), Vector2(-15, -2)],
		[Vector2(4, -9), Vector2(8, -5), Vector2(11, -2)],
	],
	ChupacabraLegend.Pose.CROUCH:
	[
		[Vector2(-8, -7), Vector2(-14, -4), Vector2(-11, -2)],
		[Vector2(4, -7), Vector2(7, -4), Vector2(8, -2)],
	],
	ChupacabraLegend.Pose.LEAP:
	[
		[Vector2(-8, -14), Vector2(-12, -8), Vector2(-16, -2)],
		[Vector2(7, -16), Vector2(12, -12), Vector2(17, -11)],
	],
	ChupacabraLegend.Pose.PERCH:
	[
		[Vector2(-5, -6), Vector2(-11, -3), Vector2(-7, -2)],
		[Vector2(2, -12), Vector2(5, -7), Vector2(5, -2)],
	],
}
const NEAR_LEGS: Dictionary[int, Array] = {
	ChupacabraLegend.Pose.CREEP_A:
	[
		[Vector2(-7, -9), Vector2(-13, -6), Vector2(-15, -2)],
		[Vector2(5, -9), Vector2(9, -5), Vector2(12, -2)],
	],
	ChupacabraLegend.Pose.CREEP_B:
	[
		[Vector2(-7, -9), Vector2(-8, -5), Vector2(-5, -2)],
		[Vector2(5, -9), Vector2(4, -5), Vector2(3, -2)],
	],
	ChupacabraLegend.Pose.CROUCH:
	[
		[Vector2(-7, -7), Vector2(-13, -4), Vector2(-8, -2)],
		[Vector2(5, -7), Vector2(9, -4), Vector2(11, -2)],
	],
	ChupacabraLegend.Pose.LEAP:
	[
		[Vector2(-9, -14), Vector2(-14, -8), Vector2(-19, -2)],
		[Vector2(8, -16), Vector2(14, -14), Vector2(20, -13)],
	],
	ChupacabraLegend.Pose.PERCH:
	[
		[Vector2(-4, -6), Vector2(-10, -4), Vector2(-4, -2)],
		[Vector2(3, -12), Vector2(7, -7), Vector2(8, -2)],
	],
}


static func make(dir: String) -> void:
	var beast := LegendArt.new(ChupacabraLegend.BEAST, ChupacabraLegend.Pose.size())
	for pose: int in ChupacabraLegend.Pose.size():
		beast.frame = pose
		_draw_beast(beast, pose)
	beast.save(dir.path_join("beast.png"))
	var car := (load(CAR_SHEET) as Texture2D).get_image()
	var husk := LegendArt.new(CarController.FRAME_SIZE, CarController.WRECK_FRAME + 1)
	for frame: int in CarController.WRECK_FRAME + 1:
		husk.frame = frame
		_drain(husk, car)
	husk.save(dir.path_join("husk.png"))


static func _draw_beast(art: LegendArt, pose: int) -> void:
	var body := ChupacabraLegend.Pose.CREEP_A if pose == ChupacabraLegend.Pose.CREEP_B else pose
	for leg: Array in FAR_LEGS[pose]:
		_draw_line(art, leg, "tunnel road")
	_draw_line(art, TAIL[body], "shadow")
	art.ellipse(HAUNCH[body][0], HAUNCH[body][1], "shadow")
	art.ellipse(CHEST[body][0], CHEST[body][1], "shadow")
	_poly(art, BACK[body], "shadow")
	_poly(art, HEAD[body], "shadow")
	_poly(art, EAR[body], "shadow")
	for spine: Array in SPINES[body]:
		_draw_spine(art, spine[0], spine[1])
	for leg: Array in NEAR_LEGS[pose]:
		_draw_line(art, leg, "shadow")
	art.rect(Rect2i(EYE[body], EYE_SIZE), "red")
	art.outline()


## A leg or the tail, its points joined by lines LEG_WIDTH px wide.
static func _draw_line(art: LegendArt, points: Array, color_name: String) -> void:
	for k: int in points.size() - 1:
		art.line(points[k], points[k + 1], color_name, LEG_WIDTH)


static func _poly(art: LegendArt, points: Array, color_name: String) -> void:
	var typed: Array[Vector2] = []
	typed.assign(points)
	art.poly(typed, color_name)


## A pale spine from its foot to its tip.
static func _draw_spine(art: LegendArt, foot: Vector2, tip: Vector2) -> void:
	var side := (tip - foot).orthogonal().normalized() * SPINE_HALF
	art.poly([foot - side, tip, foot + side], "city light")


## The frame of `car`'s first row that the husk's sheet is drawing, its colours drained, each pixel
## where it is in the car's frame: the car's foot is the husk's.
static func _drain(art: LegendArt, car: Image) -> void:
	var size := CarController.FRAME_SIZE
	var names: Dictionary[String, String] = {}
	var palette := LegendArt.MakeArt.palette()
	for color_name: String in palette:
		names[palette[color_name].to_html(false)] = color_name
	var foot := Vector2i(size.x >> 1, size.y)
	for y: int in size.y:
		for x: int in size.x:
			var paint := car.get_pixel(art.frame * size.x + x, y)
			if paint.a == 0.0:
				continue
			var car_name: String = names.get(paint.to_html(false), "")
			if not DRAINED.has(car_name):
				push_error("chupacabra: the car's %s has no grey" % paint.to_html(false))
			art.plot(Vector2i(x, y) - foot, DRAINED.get(car_name, "shadow"))
