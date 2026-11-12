extends RefCounted
## The death worm's sheets (M6_PLAN.md §3.3), drawn into assets/legends/death_worm/ by
## tools/art/make_legends.gd. `worm.png`: a giant eyeless worm standing up out of the sand, a thick
## red tube creased into rings, wet and lit from the upper left, as the car is. Its blunt head shut,
## puckered at its top; its head opened into a round mouth, its lips flared round two rings of white
## teeth and a black throat; then shut again, with the swallow bulging its body just under its head,
## halfway down, and low. Nothing shows in its mouth but teeth and the dark (Q8). `mound.png`: a
## smooth mound of sand, then cracked open. `crater.png`: the crater it leaves, a dark pit in a rim
## of churned sand. Their sizes are the legend's (disasters/legends/death_worm.gd). No class_name:
## tools/ is not exported.

const LegendArt := preload("res://tools/art/legend_art.gd")
const DeathWormLegend := preload("res://disasters/legends/death_worm.gd")
## The body's half-width, in px; where its skin is lit, from the upper left, and where it is in
## shade, as a share of the half-width from the middle; and the wet gleam down its lit side.
const BODY := 21.0
const LIT := Vector2(-0.8, -0.25)
const GLEAM := Vector2(-0.62, -0.5)
const SHADE_FROM := 0.45
const DARK_FROM := 0.8
## The shut head's dome, in rows, and its puckered mouth round TIP: the radii of its lips and of its
## pucker, and how many creases draw it shut.
const DOME := 12.0
const PUCKER_LIPS := Vector2(11.0, 4.0)
const PUCKER := Vector2(7.0, 2.5)
const CREASES := 10
## The rings it is creased into: every RING rows, from the first at RING_FROM, each segment
## between them swelling by SWELL px, and each crease sagging by up to SAG px at the middle, as the
## front of a ring round a tube does.
const RING := 8
const RING_FROM := 18
const SWELL := 1.0
const SAG := 8.0
## The swallow: how far it swells the body on each side, in px, and over how many rows each way;
## and its middle, in rows from the top, in each frame that shows it.
const BULGE := 5.0
const BULGE_ROWS := 9.0
const SWALLOWS: Dictionary[int, float] = {
	DeathWormLegend.SHUT: 27.0,
	DeathWormLegend.SWALLOWING: 51.0,
	DeathWormLegend.DOWN: 75.0,
}
## The open mouth: its flared lips' radii, and its gums', where its outer teeth are rooted; how
## many of them there are, how wide each is at its root, as a share of the gap to the next, and how
## far in its tip reaches, as a share of the gums' radii; and the inner ring of teeth, rooted at the
## throat's edge.
const LIPS := Vector2(26.0, 9.0)
const GUMS := Vector2(22.0, 7.5)
const TEETH := 16
const TOOTH_WIDTH := 0.7
const TOOTH_TIP := 0.68
const INNER_TEETH := 12
const INNER_TIP := 0.7
## The mound: its radii, and its middle, from its frame's middle; and its cracks: how many, and how
## far they run, as a share of its radii.
const HUMP := Vector2(29.0, 9.5)
const HUMP_AT := Vector2(0.0, 1.0)
const CRACKS := 5
const CRACK_REACH := 0.85
## The crater: its churned rim's radii, its slope's, its pit's and its depths', and where the pit
## and the depths are, from its frame's middle.
const RIM := Vector2(30.5, 14.5)
const SLOPE := Vector2(26.0, 12.0)
const PIT := Vector2(22.0, 9.5)
const PIT_AT := Vector2(0.0, 1.0)
const DEPTHS := Vector2(15.0, 6.0)
const DEPTHS_AT := Vector2(0.0, 2.0)


static func make(dir: String) -> void:
	var worm := LegendArt.new(DeathWormLegend.WORM, DeathWormLegend.FRAMES)
	for frame: int in DeathWormLegend.FRAMES:
		worm.frame = frame
		_draw_worm(worm, frame)
	worm.save(dir.path_join("worm.png"))
	var mound := LegendArt.new(DeathWormLegend.MOUND, 2)
	for frame: int in 2:
		mound.frame = frame
		_draw_mound(mound, frame == 1)
	mound.save(dir.path_join("mound.png"))
	var crater := LegendArt.new(DeathWormLegend.CRATER)
	_draw_crater(crater)
	crater.save(dir.path_join("crater.png"))


static func _draw_worm(art: LegendArt, frame: int) -> void:
	var height := DeathWormLegend.WORM.y
	var swallow: float = SWALLOWS.get(frame, -INF)
	var open := frame == DeathWormLegend.OPEN
	var top := DeathWormLegend.MOUTH if open else 0
	for row: int in range(top, height):
		var half := _half(row + 0.5, swallow)
		if not open and row < DOME:
			half *= sqrt(1.0 - pow((DOME - row - 0.5) / DOME, 2.0))
		for x: int in range(-ceili(half), ceili(half)):
			var across := (x + 0.5) / half
			if absf(across) <= 1.0:
				art.plot(Vector2i(x, row - height), _skin(across, x + row))
	for ring: int in range(RING_FROM, height, RING):
		_draw_crease(art, ring, _half(ring, swallow))
	if open:
		_draw_mouth(art, Vector2(0.0, DeathWormLegend.MOUTH - height))
	else:
		_draw_pucker(art, Vector2(0.0, DeathWormLegend.TIP - height))
	art.outline()


## The body's half-width at `row`, from the frame's top: each segment swells between its creases,
## and a swallow at `swallow` swells it more.
static func _half(row: float, swallow: float) -> float:
	var segment := fposmod(row - RING_FROM, RING) / RING
	var off := absf(row - swallow) / BULGE_ROWS
	var bulge := BULGE * 0.5 * (1.0 + cos(PI * off)) if off < 1.0 else 0.0
	return BODY + SWELL * sin(PI * segment) + bulge


## The skin `across` the body, from -1 on its left to 1 on its right: lit on the left, with a wet
## gleam, and in shade on the right, dithered with `parity`.
static func _skin(across: float, parity: int) -> String:
	if across >= GLEAM.x and across < GLEAM.y:
		return "village light"
	if across >= LIT.x and across < LIT.y:
		return "red"
	if across >= DARK_FROM or across >= SHADE_FROM and parity % 2 == 0:
		return "shadow"
	return "village roof"


## A crease round the body at `ring`, `half` px each way: a dark fold sagging at the middle, and the
## next segment's lit edge under it.
static func _draw_crease(art: LegendArt, ring: int, half: float) -> void:
	var height := DeathWormLegend.WORM.y
	for x: int in range(-ceili(half) + 1, ceili(half) - 1):
		var across := (x + 0.5) / half
		var row := ring + floori(SAG * sqrt(maxf(0.0, 1.0 - across * across)))
		art.plot(Vector2i(x, row - height), "shadow")
		if across >= LIT.x and across < LIT.y:
			art.plot(Vector2i(x, row + 1 - height), "village light")


## The shut mouth on the head's top, puckered round `centre`: its lips, lit on the left, drawn in to
## a dark middle by creases.
static func _draw_pucker(art: LegendArt, centre: Vector2) -> void:
	art.ellipse(centre, PUCKER_LIPS, "village roof")
	art.ellipse(centre + Vector2(-2.0, -1.0), PUCKER_LIPS - Vector2(4.0, 1.5), "red")
	art.ellipse(centre, PUCKER, "shadow")
	for k: int in CREASES:
		var angle := TAU * (k + 0.5) / CREASES
		art.line(centre, centre + Vector2.from_angle(angle) * PUCKER_LIPS, "shadow")
	art.ellipse(centre, Vector2(2.5, 1.0), "ink")


## The open mouth about `centre`: lips flared over the body, lit on the left, round a ring of teeth
## rooted in its gums, a second ring rooted at the black throat, and the throat.
static func _draw_mouth(art: LegendArt, centre: Vector2) -> void:
	var throat := Vector2(DeathWormLegend.THROAT)
	art.ellipse(centre, LIPS, "village roof")
	art.ellipse(centre + Vector2(-3.0, -1.0), LIPS - Vector2(6.0, 2.5), "red")
	art.ellipse(centre, GUMS, "shadow")
	art.ellipse(centre, throat, "ink")
	_draw_teeth(art, centre, GUMS, TEETH, TOOTH_TIP, "white")
	_draw_teeth(art, centre, throat, INNER_TEETH, INNER_TIP, "line")


## `count` teeth in a ring rooted at `radii` round `centre`, each pointing in to `tip` of them.
static func _draw_teeth(
	art: LegendArt, centre: Vector2, radii: Vector2, count: int, tip: float, paint: String
) -> void:
	var half := PI / count * TOOTH_WIDTH
	for k: int in count:
		var angle := TAU * (k + 0.5) / count
		var tooth: Array[Vector2] = [
			centre + Vector2.from_angle(angle - half) * radii,
			centre + Vector2.from_angle(angle + half) * radii,
			centre + Vector2.from_angle(angle) * radii * tip,
		]
		art.poly(tooth, paint)


## The mound, smooth and lit from the upper left, or cracked open.
static func _draw_mound(art: LegendArt, cracked: bool) -> void:
	var middle := Vector2(0.0, -DeathWormLegend.MOUND.y / 2.0) + HUMP_AT
	for y: int in range(floori(middle.y - HUMP.y), ceili(middle.y + HUMP.y)):
		for x: int in range(floori(-HUMP.x), ceili(HUMP.x)):
			var at := (Vector2(x, y) + Vector2(0.5, 0.5) - middle) / HUMP
			if at.length_squared() > 1.0:
				continue
			var facing := at.x + at.y
			var shade := "desert ground"
			if facing < -0.5:
				shade = "desert light"
			elif facing > 0.6 or at.length_squared() > 0.8 and at.y > 0.0:
				shade = "desert dark"
			art.plot(Vector2i(x, y), shade)
	if not cracked:
		return
	for k: int in CRACKS:
		var angle := TAU * (k + 0.3) / CRACKS
		var bend := Vector2.from_angle(angle + 0.4) * HUMP * CRACK_REACH * 0.5
		var end := Vector2.from_angle(angle) * HUMP * CRACK_REACH
		art.line(middle, middle + bend, "shadow")
		art.line(middle + bend, middle + end, "shadow")
	art.ellipse(middle, Vector2(6.0, 2.5), "ink")


## The crater: a rim of churned sand, lit on its far side, round a dark pit.
static func _draw_crater(art: LegendArt) -> void:
	var middle := Vector2(0.0, -DeathWormLegend.CRATER.y / 2.0)
	art.ellipse(middle, RIM, "desert dark")
	art.ellipse(middle + Vector2(-3.0, -2.0), RIM - Vector2(6.0, 4.0), "desert light")
	art.ellipse(middle, SLOPE, "rural dark")
	art.ellipse(middle + PIT_AT, PIT, "shadow")
	art.ellipse(middle + DEPTHS_AT, DEPTHS, "ink")
