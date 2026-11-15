extends RefCounted
## Checks of the art (docs/M5.md §5.5) that work on whole images natively: a test that looped over
## every pixel in GDScript would take seconds. No class_name: tests/ is not exported.

const MakeArt := preload("res://tools/art/make_art.gd")
## The period of an edge's dither, in rows (GreyboxAtlas.bayer()).
const DITHER_ROWS := 8
## A legend's figure stands out at night (POOLS_PLAN.md §5.6, night_share()) if NIGHT_SHARE of its
## pixels differ from its area's main colours by NIGHT_CONTRAST of the light's luminance: less than
## M6's five legends, 29-47%. A main colour is one of at least MAIN_SHARE of a sheet's pixels.
const NIGHT_SHARE := 0.25
const NIGHT_CONTRAST := 0.1
const MAIN_SHARE := 0.05


## The pixels of `image` as RGBA8 integers, each transparent one 0, as pixel() packs a colour.
## Premultiplying keeps every opaque pixel as it is: Image.premultiply_alpha() gives
## (c * 255 + 255) >> 8 = c.
static func pixels(image: Image) -> PackedInt32Array:
	var copy := image.duplicate() as Image
	copy.convert(Image.FORMAT_RGBA8)
	copy.premultiply_alpha()
	return copy.get_data().to_int32_array()


## `color` as pixels() has it.
static func pixel(color: Color) -> int:
	var value := color.r8 | color.g8 << 8 | color.b8 << 16 | color.a8 << 24
	return value - (1 << 32) if value >= 1 << 31 else value


## The palette's colours, opaque.
static func palette() -> Array[Color]:
	var colors: Array[Color] = []
	colors.assign(MakeArt.palette().values())
	return colors


## The colours of `image` that its opaque pixels are in, by their share of them: those of the
## palette, and, as Color(), all the rest.
static func shares(image: Image) -> Dictionary[Color, float]:
	var all := pixels(image)
	var opaque := all.size() - all.count(0)
	var found: Dictionary[Color, float] = {}
	var counted := 0
	for color: Color in palette():
		var count := all.count(pixel(color))
		if count > 0:
			found[color] = float(count) / opaque
			counted += count
	if counted < opaque:
		found[Color()] = float(opaque - counted) / opaque
	return found


## An image of `image`'s size, white where it is opaque and clear elsewhere.
static func mask(image: Image) -> Image:
	var white := Image.create_empty(
		image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8
	)
	white.fill(Color.WHITE)
	var masked := Image.create_empty(
		image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8
	)
	masked.blit_rect_mask(white, image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i.ZERO)
	return masked


## The first pixel where `a` and `b`, of the same size, differ, or (-1, -1).
static func first_difference(a: Image, b: Image) -> Vector2i:
	var pa := pixels(a)
	var pb := pixels(b)
	if pa == pb:
		return Vector2i(-1, -1)
	for k: int in pa.size():
		if pa[k] != pb[k]:
			@warning_ignore("integer_division")
			return Vector2i(k % a.get_width(), k / a.get_width())
	return Vector2i(-1, -1)


## What is wrong with `edge` as the edge of `ground`, or "". It is as wide as the ground and
## edge_rows() tall; each pixel it shows is the ground's; the first row shows nearly all of them and
## the last nearly none; and any DITHER_ROWS rows show no more of them than the rows just above. Not
## each row: an ordered dither spreads the pixels it shows over its period, so a row can show more
## than the one above it (in Bayer's matrix, row 3 has none of the lowest 20 thresholds).
static func edge_problem(ground: Image, edge: Image) -> String:
	var size := Vector2i(ground.get_width(), GreyboxAtlas.edge_rows())
	if edge.get_size() != size:
		return "it is %s, not %s" % [edge.get_size(), size]
	var under := pixels(ground.get_region(Rect2i(Vector2i.ZERO, size)))
	var shown := pixels(edge)
	var counts: Array[int] = []
	for y: int in size.y:
		var count := 0
		for x: int in size.x:
			var k := y * size.x + x
			if shown[k] == 0:
				continue
			if shown[k] != under[k]:
				return "pixel (%d, %d) isn't the ground's" % [x, y]
			count += 1
		counts.append(count)
		# Rows y - DITHER_ROWS + 1 to y against the rows one above: they share all rows but these two.
		if y >= DITHER_ROWS and count > counts[y - DITHER_ROWS]:
			return "rows %d to %d show more pixels than the rows above" % [y - DITHER_ROWS + 1, y]
	if counts[0] < 0.9 * size.x:
		return "the first row shows only %d of %d pixels" % [counts[0], size.x]
	if counts[-1] > 0.1 * size.x:
		return "the last row shows %d of %d pixels" % [counts[-1], size.x]
	return ""


## The share of `figure`'s opaque pixels that stand out from `area`'s road and ground through the
## veil `veil_kind`, in the key light of the day where it is least (POOLS_PLAN.md §5.6, V15). The
## light that reaches them is, in each channel, the less of the key light's and the veil's own
## colour, as Daylight and the veil both darken; with no veil, the key light. A pixel stands out if
## its colour, so lit, differs in luminance from each main colour of the area's road, ground and
## ground edge, so lit, by NIGHT_CONTRAST of the light's: so the smoke is checked
## (tests/unit/test_car_controller.gd). A pixel not in the palette never does. The road is the road
## sheet's ROAD row: a run draws its dead ends' row only in a debug view, its tunnel's under the
## tunnel, and its bridge's on a bridge (GreyboxAtlas.road_coords()).
static func night_share(figure: Image, area: AreaDef, veil_kind: Legend.Veil) -> float:
	var veil := Color.WHITE
	if veil_kind == Legend.Veil.DUSK:
		veil = Tuning.VEIL_DUSK
	elif veil_kind == Legend.Veil.NIGHT:
		veil = Tuning.VEIL_NIGHT
	var mains: Array[Color] = []
	for sheet: Image in _road_and_ground(area):
		var found := shares(sheet)
		for color: Color in found:
			if color != Color() and found[color] >= MAIN_SHARE and color not in mains:
				mains.append(color)
	var colors := shares(figure)
	var least := 1.0
	for key: Color in Tuning.LIGHT_COLORS:
		var light := Color(minf(key.r, veil.r), minf(key.g, veil.g), minf(key.b, veil.b))
		var share := 0.0
		for color: Color in colors:
			if color != Color() and _stands_out(color, mains, light):
				share += colors[color]
		least = minf(least, share)
	return least


## `area`'s road as a run draws it, its ground and its ground edge, those it has.
static func _road_and_ground(area: AreaDef) -> Array[Image]:
	var sheets: Array[Image] = []
	if area.road_sheet != null:
		var road := area.road_sheet.get_image()
		@warning_ignore("integer_division")
		var rows := road.get_height() / GreyboxAtlas.Row.size()
		sheets.append(
			road.get_region(Rect2i(0, GreyboxAtlas.Row.ROAD * rows, road.get_width(), rows))
		)
	for sheet: Texture2D in [area.ground, area.ground_edge]:
		if sheet != null:
			sheets.append(sheet.get_image())
	return sheets


## Whether `color`, lit by `light`, differs in luminance from each of `mains`, so lit, by
## NIGHT_CONTRAST of the light's.
static func _stands_out(color: Color, mains: Array[Color], light: Color) -> bool:
	var lit := (color * light).get_luminance()
	for main: Color in mains:
		if absf(lit - (main * light).get_luminance()) < NIGHT_CONTRAST * light.get_luminance():
			return false
	return true
