extends RefCounted
## Draws a sheet of a legend's part (M6_PLAN.md §5.7): one row of frames, each standing on its
## bottom row, its foot at the middle of that row's bottom edge, as a standing sprite shows it with
## `centered` off and the offset (-width / 2, -height). Points are in pixels from the foot of the
## frame being drawn, and nothing is drawn outside that frame. Colours go by their names in
## assets/palette.gpl, and nothing is blended: a pixel takes the last colour drawn on it. A legend's
## art script, tools/art/legends/<id>.gd, draws each of its parts with one and saves it. No
## class_name: tools/ is not exported.

const MakeArt := preload("res://tools/art/make_art.gd")
## The largest a frame may be (tests/unit/test_legend_art.gd).
const MAX_FRAME := Vector2i(96, 96)

## The sheet.
var image: Image
var frame_size: Vector2i
## The frame that drawing goes to, from 0.
var frame := 0
var _palette: Dictionary[String, Color] = {}


func _init(p_frame_size: Vector2i, frames := 1) -> void:
	frame_size = p_frame_size
	if frame_size.x > MAX_FRAME.x or frame_size.y > MAX_FRAME.y:
		push_error("legend_art: a frame of %s is larger than %s" % [frame_size, MAX_FRAME])
	image = Image.create_empty(frame_size.x * frames, frame_size.y, false, Image.FORMAT_RGBA8)
	_palette = MakeArt.palette()


## The palette's colour `color_name`.
func color(color_name: String) -> Color:
	if not _palette.has(color_name):
		push_error("legend_art: the palette has no %s" % color_name)
		return _palette["ink"]
	return _palette[color_name]


func plot(at: Vector2i, color_name: String) -> void:
	_put(at, color(color_name))


func rect(area: Rect2i, color_name: String) -> void:
	var paint := color(color_name)
	for y: int in range(area.position.y, area.end.y):
		for x: int in range(area.position.x, area.end.x):
			_put(Vector2i(x, y), paint)


## Fills the pixels whose centres are inside the ellipse.
func ellipse(centre: Vector2, radii: Vector2, color_name: String) -> void:
	var paint := color(color_name)
	for y: int in range(floori(centre.y - radii.y), ceili(centre.y + radii.y)):
		for x: int in range(floori(centre.x - radii.x), ceili(centre.x + radii.x)):
			if ((Vector2(x, y) + Vector2(0.5, 0.5) - centre) / radii).length_squared() <= 1.0:
				_put(Vector2i(x, y), paint)


## Fills the pixels whose centres are inside the polygon.
func poly(points: Array[Vector2], color_name: String) -> void:
	var paint := color(color_name)
	var polygon := PackedVector2Array(points)
	var box := Rect2(points[0], Vector2.ZERO)
	for point: Vector2 in points:
		box = box.expand(point)
	for y: int in range(floori(box.position.y), ceili(box.end.y)):
		for x: int in range(floori(box.position.x), ceili(box.end.x)):
			if Geometry2D.is_point_in_polygon(Vector2(x, y) + Vector2(0.5, 0.5), polygon):
				_put(Vector2i(x, y), paint)


func line(start: Vector2, end: Vector2, color_name: String, width := 1) -> void:
	var paint := color(color_name)
	var steps := maxi(1, ceili(maxf(absf(end.x - start.x), absf(end.y - start.y))))
	for k: int in steps + 1:
		var point := Vector2i(start.lerp(end, float(k) / steps).floor())
		for dy: int in width:
			for dx: int in width:
				_put(point + Vector2i(dx, dy), paint)


## Colours each clear pixel of the frame that is next to a drawn one, as the props are outlined.
func outline(color_name := "ink") -> void:
	var paint := color(color_name)
	var bounds := _bounds()
	var edge: Array[Vector2i] = []
	for y: int in range(bounds.position.y, bounds.end.y):
		for x: int in range(bounds.position.x, bounds.end.x):
			if image.get_pixel(x, y).a > 0.0:
				continue
			for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var near := Vector2i(x, y) + step
				if bounds.has_point(near) and image.get_pixelv(near).a > 0.0:
					edge.append(Vector2i(x, y))
					break
	for pixel: Vector2i in edge:
		image.set_pixelv(pixel, paint)


## Saves the sheet as a PNG at `path`, making its folder.
func save(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var error := image.save_png(path)
	if error != OK:
		push_error("legend_art: can't write %s (%s)" % [path, error_string(error)])
	else:
		print("legend_art: %s, %d × %d" % [path, image.get_width(), image.get_height()])


## Sets the pixel `at` pixels from the frame's foot, if it is inside the frame.
func _put(at: Vector2i, paint: Color) -> void:
	var pixel := Vector2i(frame * frame_size.x + (frame_size.x >> 1), frame_size.y) + at
	if _bounds().has_point(pixel):
		image.set_pixelv(pixel, paint)


## The frame being drawn, in the sheet's pixels.
func _bounds() -> Rect2i:
	return Rect2i(Vector2i(frame * frame_size.x, 0), frame_size)
