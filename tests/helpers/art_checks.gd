extends RefCounted
## Checks of the art (docs/M5.md §5.5) that work on whole images natively: a test that looped over
## every pixel in GDScript would take seconds. No class_name: tests/ is not exported.

const MakeArt := preload("res://tools/art/make_art.gd")
## The period of an edge's dither, in rows (GreyboxAtlas.bayer()).
const DITHER_ROWS := 8


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
