extends SceneTree
## Makes each area's props (M5_PLAN.md §5.6): assets/<area>/props.png, a sheet of their frames, and
## areas/props/<area>/<id>.tres, a PropDef for each. Like tools/art/make_art.gd's art, they are
## placeholders that an artist may replace, file by file, with art that keeps the contract
## tests/unit/test_prop_art.gd checks: each PropDef validates, its region fits its frames' pixels
## tightly, and every pixel is clear or a colour of assets/palette.gpl. Each frame is drawn on a
## canvas as large as PropDef.validate() allows, with the foot where it allows, and then cut to the
## pixels the prop's frames use. The output is the same on every run. From the repository root:
##   godot --headless -s tools/art/make_props.gd
## then tools/ci/import.sh, and commit the PNG and .import files and the PropDefs. The script
## prints the lines that list the props in each area's .tres.

const MakeArt := preload("res://tools/art/make_art.gd")
## Colours that several props share.
const TREE := ["meadows ground", "meadows dark", "meadows light", "plank"]
const GREY_ROCK := ["asphalt light", "city light", "asphalt"]
const HOUSE := ["white", "line", "village roof", "city brick", "plank", "meadows water"]
const COTTAGE := ["village light", "village dark", "rural dark", "plank", "plank", "yellow"]
const TRAFFIC_LIGHT := ["asphalt", "shadow", "asphalt light", "red", "yellow", "meadows light"]
## Each area's props, in the order PropLayout picks them, by id: frames, frames per second,
## density, and colours, by their names in the palette. A prop's id names its _paint_ function.
const PROPS := {
	&"city":
	{
		&"building": [1, 0.0, 0.01, ["city light", "city dark", "asphalt light", "yellow"]],
		&"tree": [1, 0.0, 0.01, TREE],
		&"lamp": [1, 0.0, 0.01, ["asphalt", "yellow"]],
		&"bin": [1, 0.0, 0.006, ["asphalt light", "city light", "asphalt"]],
		&"hydrant": [1, 0.0, 0.005, ["red", "city brick"]],
		&"traffic_light": [3, 1.0, 0.004, TRAFFIC_LIGHT],
	},
	&"rural":
	{
		&"tree": [1, 0.0, 0.014, TREE],
		&"hay_bale": [1, 0.0, 0.01, ["rural light", "yellow", "rural dark"]],
		&"fence": [1, 0.0, 0.008, ["plank", "rural dirt"]],
		&"barn": [1, 0.0, 0.004, ["red", "village roof", "shadow", "asphalt", "plank", "yellow"]],
		&"rock": [1, 0.0, 0.008, GREY_ROCK],
		&"windmill": [3, 6.0, 0.003, ["white", "line", "village roof", "plank"]],
	},
	&"meadows":
	{
		&"tree": [1, 0.0, 0.012, TREE],
		&"pine": [1, 0.0, 0.01, ["meadows ground", "meadows dark", "plank"]],
		&"bush": [1, 0.0, 0.012, ["meadows ground", "meadows light", "meadows dark"]],
		&"flowers": [1, 0.0, 0.016, ["meadows dark", "yellow", "white", "red"]],
		&"rock": [1, 0.0, 0.006, GREY_ROCK],
		&"pond": [3, 2.0, 0.003, ["meadows dark", "meadows water", "foam", "meadows light"]],
	},
	&"village":
	{
		&"house": [1, 0.0, 0.008, HOUSE],
		&"cottage": [1, 0.0, 0.008, COTTAGE],
		&"tree": [1, 0.0, 0.012, TREE],
		&"well": [1, 0.0, 0.004, ["asphalt light", "meadows water", "plank", "village roof"]],
		&"fence": [1, 0.0, 0.01, ["white", "white"]],
		&"smoky_house": [4, 4.0, 0.004, HOUSE + ["asphalt light", "city light"]],
	},
	&"desert":
	{
		&"cactus": [1, 0.0, 0.01, ["desert cactus", "meadows dark", "meadows ground"]],
		&"barrel": [1, 0.0, 0.012, ["desert cactus", "meadows dark", "red"]],
		&"rock": [1, 0.0, 0.01, ["rural dirt", "desert dark", "plank"]],
		&"bones": [1, 0.0, 0.004, ["white", "line"]],
		&"dry_bush": [1, 0.0, 0.012, ["rural dirt", "plank"]],
		&"tumbleweed": [4, 6.0, 0.004, ["rural dirt", "plank"]],
	},
}
## Props drawn without an ink outline: flat ones, which it would make look like holes.
const FLAT: Array[StringName] = [&"flowers", &"pond"]

var _palette: Dictionary[String, Color] = {}


func _initialize() -> void:
	_palette = MakeArt.palette()
	for area: StringName in PROPS:
		_make_area(area)
	quit()


## The canvas that each frame is drawn on: as large as PropDef.validate() allows.
static func canvas_size() -> Vector2i:
	return Vector2i(Tuning.PROP_MAX_SIZE.x, Tuning.PROP_MAX_SIZE.y + Tuning.PROP_BELOW)


## Where the foot stands on the canvas.
static func canvas_foot() -> Vector2i:
	return Vector2i(Tuning.PROP_MAX_SIZE.x >> 1, Tuning.PROP_MAX_SIZE.y)


func _make_area(area: StringName) -> void:
	var sheet_path := "res://assets/%s/props.png" % area
	var defs: Array[PropDef] = []
	var strips: Array[Image] = []
	var props: Dictionary = PROPS[area]
	for id: StringName in props:
		var spec: Array = props[id]
		var frames := _frames(id, spec)
		var used := frames[0].get_used_rect()
		for frame: Image in frames:
			used = used.merge(frame.get_used_rect())
		var strip := Image.create_empty(
			used.size.x * frames.size(), used.size.y, false, Image.FORMAT_RGBA8
		)
		for k: int in frames.size():
			strip.blit_rect(frames[k], used, Vector2i(used.size.x * k, 0))
		var def := PropDef.new()
		def.id = id
		def.frames = spec[0]
		def.fps = spec[1]
		def.density = spec[2]
		def.region = Rect2i(Vector2i.ZERO, used.size)
		def.foot = canvas_foot() - used.position
		defs.append(def)
		strips.append(strip)
	var sheet := _sheet(defs, strips)
	if sheet.save_png(sheet_path) != OK:
		push_error("make_props: can't write %s" % sheet_path)
	print("make_props: %s, %d × %d" % [sheet_path, sheet.get_width(), sheet.get_height()])
	var texture := ImageTexture.create_from_image(sheet)
	var dir := "res://areas/props/%s/" % area
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	for def: PropDef in defs:
		def.texture = texture
		for problem: String in def.validate():
			push_error("make_props: %s: %s" % [area, problem])
		_write_def(def, sheet_path, dir + "%s.tres" % def.id)
	_print_listing(area, defs)


## The props' strips side by side, a pixel apart, top-aligned. Sets each PropDef's region.
static func _sheet(defs: Array[PropDef], strips: Array[Image]) -> Image:
	var width := -1
	var height := 0
	for strip: Image in strips:
		width += strip.get_width() + 1
		height = maxi(height, strip.get_height())
	var sheet := Image.create_empty(width, height, false, Image.FORMAT_RGBA8)
	var x := 0
	for k: int in strips.size():
		sheet.blit_rect(strips[k], Rect2i(Vector2i.ZERO, strips[k].get_size()), Vector2i(x, 0))
		defs[k].region.position = Vector2i(x, 0)
		x += strips[k].get_width() + 1
	return sheet


func _frames(id: StringName, spec: Array) -> Array[Image]:
	var colors: Array[Color] = []
	for color_name: String in spec[3]:
		colors.append(_palette[color_name])
	var frames: Array[Image] = []
	for frame: int in spec[0]:
		var image := Image.create_empty(canvas_size().x, canvas_size().y, false, Image.FORMAT_RGBA8)
		var shadow: float = call("_paint_%s" % id, image, colors, frame)
		if id not in FLAT:
			_outline(image)
		if shadow > 0.0:
			_shadow(image, shadow)
		frames.append(image)
	return frames


static func _write_def(def: PropDef, sheet_path: String, path: String) -> void:
	var lines := PackedStringArray(
		[
			'[gd_resource type="Resource" script_class="PropDef" format=3]',
			"",
			'[ext_resource type="Script" path="res://areas/prop_def.gd" id="1_script"]',
			'[ext_resource type="Texture2D" path="%s" id="2_sheet"]' % sheet_path,
			"",
			"[resource]",
			'script = ExtResource("1_script")',
			'id = &"%s"' % def.id,
			'texture = ExtResource("2_sheet")',
			(
				"region = Rect2i(%d, %d, %d, %d)"
				% [
					def.region.position.x,
					def.region.position.y,
					def.region.size.x,
					def.region.size.y
				]
			),
		]
	)
	if def.frames > 1:
		lines.append("frames = %d" % def.frames)
		lines.append("fps = %s" % str(def.fps))
	lines.append("foot = Vector2i(%d, %d)" % [def.foot.x, def.foot.y])
	lines.append("density = %s" % str(def.density))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("make_props: can't write %s" % path)
		return
	file.store_string("\n".join(lines) + "\n")
	print("make_props: %s" % path)


static func _print_listing(area: StringName, defs: Array[PropDef]) -> void:
	print("make_props: areas/%s.tres lists them with:" % area)
	print('[ext_resource type="Script" path="res://areas/prop_def.gd" id="props_script"]')
	var refs := PackedStringArray()
	for def: PropDef in defs:
		print(
			(
				'[ext_resource type="Resource" path="res://areas/props/%s/%s.tres" id="prop_%s"]'
				% [area, def.id, def.id]
			)
		)
		refs.append('ExtResource("prop_%s")' % def.id)
	print('props = Array[ExtResource("props_script")]([%s])' % ", ".join(refs))


## Inks each clear pixel next to one that `image` has.
func _outline(image: Image) -> void:
	var ink: Color = _palette["ink"]
	var edge: Array[Vector2i] = []
	var bounds := Rect2i(Vector2i.ZERO, image.get_size())
	for y: int in image.get_height():
		for x: int in image.get_width():
			if image.get_pixel(x, y).a > 0.0:
				continue
			for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var near := Vector2i(x, y) + step
				if bounds.has_point(near) and image.get_pixelv(near).a > 0.0:
					edge.append(Vector2i(x, y))
					break
	for pixel: Vector2i in edge:
		image.set_pixelv(pixel, ink)


## A flat shadow on the clear pixels around the foot, `half_width` wide either side.
func _shadow(image: Image, half_width: float) -> void:
	var shade: Color = _palette["shadow"]
	var centre := Vector2(canvas_foot())
	var radii := Vector2(half_width, 2.5)
	for y: int in range(floori(centre.y - radii.y), ceili(centre.y + radii.y)):
		for x: int in range(floori(centre.x - radii.x), ceili(centre.x + radii.x)):
			var d := (Vector2(x, y) + Vector2(0.5, 0.5) - centre) / radii
			if d.length_squared() <= 1.0 and image.get_pixel(x, y).a == 0.0:
				image.set_pixel(x, y, shade)


# The props. Each draws a frame with its foot at canvas_foot(), and returns its shadow's
# half-width, or 0 for none.


func _paint_tree(image: Image, c: Array[Color], _frame: int) -> float:
	_rect(image, Rect2i(-2, -14, 4, 14), c[3])
	_ellipse(image, Vector2(0, -24), Vector2(11, 10.5), c[1])
	_ellipse(image, Vector2(-1.5, -25.5), Vector2(9.5, 9), c[0])
	_ellipse(image, Vector2(-4, -29), Vector2(4, 3.5), c[2])
	return 8.0


func _paint_pine(image: Image, c: Array[Color], _frame: int) -> float:
	_rect(image, Rect2i(-2, -8, 4, 8), c[2])
	for k: int in 3:
		var base := -6.0 - 10.0 * k
		var half := 12.0 - 2.5 * k
		var apex := base - 20.0 + k
		_poly(image, [Vector2(-half, base), Vector2(half, base), Vector2(0, apex)], c[0])
		_poly(image, [Vector2(0, base), Vector2(half, base), Vector2(0, apex)], c[1])
	return 8.0


func _paint_bush(image: Image, c: Array[Color], _frame: int) -> float:
	_ellipse(image, Vector2(-4, -5), Vector2(6, 5), c[2])
	_ellipse(image, Vector2(4, -5), Vector2(6, 5), c[2])
	_ellipse(image, Vector2(0, -8), Vector2(6.5, 5.5), c[0])
	_ellipse(image, Vector2(-3, -10), Vector2(3, 2), c[1])
	return 9.0


func _paint_flowers(image: Image, c: Array[Color], _frame: int) -> float:
	var spots: Array[Vector2] = [
		Vector2(-7, -3), Vector2(-3, -6), Vector2(1, -2), Vector2(4, -5), Vector2(7, -3)
	]
	for k: int in spots.size():
		_line(image, Vector2(spots[k].x, 0), spots[k], c[0])
		_rect(image, Rect2i(Vector2i(spots[k]) + Vector2i(-1, -1), Vector2i(2, 2)), c[1 + k % 3])
	return 0.0


func _paint_rock(image: Image, c: Array[Color], _frame: int) -> float:
	_poly(
		image,
		[
			Vector2(-8, 0),
			Vector2(-9, -4),
			Vector2(-5, -9),
			Vector2(1, -10),
			Vector2(7, -7),
			Vector2(9, -2),
			Vector2(6, 0)
		],
		c[0]
	)
	_poly(image, [Vector2(4, -7), Vector2(9, -2), Vector2(6, 0), Vector2(3, 0)], c[2])
	_poly(image, [Vector2(-5, -8), Vector2(1, -9), Vector2(4, -7), Vector2(-1, -5)], c[1])
	return 10.0


func _paint_building(image: Image, c: Array[Color], _frame: int) -> float:
	var half := 20
	var height := 36
	_box(image, half, height, c[0], c[1])
	_poly(image, _top(half, height), c[2])
	for face: int in [-1, 1]:
		for col: int in 3:
			for row: int in 4:
				var lit := (col + 2 * row + face) % 3 == 0
				_window(
					image, face * (4 + 6 * col), 6 + 8 * row, c[3] if lit else _palette["shadow"]
				)
	return 0.0


func _paint_house(image: Image, c: Array[Color], _frame: int) -> float:
	_house(image, c, 16, 14, 13)
	return 0.0


func _paint_cottage(image: Image, c: Array[Color], _frame: int) -> float:
	_house(image, c, 13, 12, 11)
	return 0.0


func _paint_barn(image: Image, c: Array[Color], _frame: int) -> float:
	_house(image, c, 22, 20, 16)
	return 0.0


## A house with smoke from its chimney: three puffs, which rise a quarter of their spacing a frame.
func _paint_smoky_house(image: Image, c: Array[Color], frame: int) -> float:
	_house(image, c, 16, 14, 13)
	var apex := -8.0 - 14.0 - 13.0
	_rect(image, Rect2i(6, int(apex) + 1, 3, 8), c[3])
	for k: int in 3:
		var rise := 2.5 * frame + 10.0 * k
		var centre := Vector2(7.5 + rise * 0.3, apex - 2.0 - rise)
		var radius := 1.5 + rise / 12.0
		_ellipse(image, centre, Vector2(radius, radius), c[6])
		_ellipse(image, centre + Vector2(-0.5, -0.5), Vector2(radius, radius) * 0.5, c[7])
	return 0.0


func _paint_lamp(image: Image, c: Array[Color], _frame: int) -> float:
	_rect(image, Rect2i(-1, -38, 2, 38), c[0])
	_rect(image, Rect2i(-2, -3, 4, 3), c[0])
	_rect(image, Rect2i(1, -38, 6, 2), c[0])
	_rect(image, Rect2i(4, -36, 4, 2), c[1])
	return 3.0


func _paint_bin(image: Image, c: Array[Color], _frame: int) -> float:
	_rect(image, Rect2i(-4, -10, 8, 10), c[0])
	_rect(image, Rect2i(1, -10, 3, 10), c[2])
	_rect(image, Rect2i(-5, -12, 10, 2), c[1])
	return 5.0


func _paint_hydrant(image: Image, c: Array[Color], _frame: int) -> float:
	_rect(image, Rect2i(-2, -8, 5, 8), c[0])
	_ellipse(image, Vector2(0.5, -8), Vector2(2.5, 2), c[0])
	_rect(image, Rect2i(-4, -6, 9, 2), c[1])
	_rect(image, Rect2i(-3, -1, 7, 1), c[1])
	return 4.0


## Red on top, then yellow and green. The frames light green, yellow and red, the order in which a
## real light changes, so the loop never goes from yellow to green.
func _paint_traffic_light(image: Image, c: Array[Color], frame: int) -> float:
	_rect(image, Rect2i(-1, -28, 2, 28), c[0])
	_rect(image, Rect2i(-3, -42, 6, 15), c[1])
	var lit := 2 - frame
	for k: int in 3:
		_ellipse(
			image, Vector2(0, -38.5 + 4 * k), Vector2(1.6, 1.6), c[3 + k] if k == lit else c[2]
		)
	return 3.0


func _paint_hay_bale(image: Image, c: Array[Color], _frame: int) -> float:
	_ellipse(image, Vector2(1, -7), Vector2(9, 7), c[0])
	_ellipse(image, Vector2(-4, -7), Vector2(5, 7), c[1])
	_ellipse(image, Vector2(-4, -7), Vector2(3, 4.5), c[2])
	_ellipse(image, Vector2(-4, -7), Vector2(2, 3), c[1])
	return 9.0


## Four posts and two rails, along a road's diagonal.
func _paint_fence(image: Image, c: Array[Color], _frame: int) -> float:
	for k: int in 4:
		_rect(image, Rect2i(-13 + 8 * k, -6 - 4 * k, 2, 10), c[0])
	for rail: int in [3, 7]:
		_line(image, Vector2(-13, 4 - rail), Vector2(13, -9 - rail), c[1])
	return 0.0


## The sails turn a third of a quarter turn a frame.
func _paint_windmill(image: Image, c: Array[Color], frame: int) -> float:
	_poly(image, [Vector2(-6, 0), Vector2(6, 0), Vector2(3, -34), Vector2(-3, -34)], c[0])
	_poly(image, [Vector2(0, 0), Vector2(6, 0), Vector2(3, -34), Vector2(0, -34)], c[1])
	_rect(image, Rect2i(-2, -6, 4, 6), c[3])
	_ellipse(image, Vector2(0, -36), Vector2(4.5, 3.5), c[2])
	for k: int in 4:
		var angle := deg_to_rad(15.0 + 30.0 * frame + 90.0 * k)
		_line(image, Vector2(0, -36), Vector2(0, -36) + Vector2.from_angle(angle) * 19.0, c[3], 2)
	return 6.0


## Glints that drift across the water and start again.
func _paint_pond(image: Image, c: Array[Color], frame: int) -> float:
	_ellipse(image, Vector2(0, -5), Vector2(17, 6.5), c[0])
	_ellipse(image, Vector2(0, -5), Vector2(15, 5), c[1])
	_ellipse(image, Vector2(7, -6), Vector2(2.5, 1.2), c[3])
	var glints: Array[Vector2i] = [Vector2i(-10, -7), Vector2i(-3, -4), Vector2i(1, -8)]
	for k: int in glints.size():
		_rect(image, Rect2i(glints[k] + Vector2i(2 * ((frame + k) % 3), 0), Vector2i(3, 1)), c[2])
	return 0.0


func _paint_well(image: Image, c: Array[Color], _frame: int) -> float:
	_ellipse(image, Vector2(0, -4), Vector2(8, 4.5), c[0])
	_ellipse(image, Vector2(0, -5.5), Vector2(5.5, 2.5), c[1])
	_rect(image, Rect2i(-8, -22, 2, 18), c[2])
	_rect(image, Rect2i(6, -22, 2, 18), c[2])
	_line(image, Vector2(-7, -18), Vector2(7, -18), c[2])
	_poly(image, [Vector2(-11, -20), Vector2(11, -20), Vector2(0, -29)], c[3])
	return 9.0


func _paint_cactus(image: Image, c: Array[Color], _frame: int) -> float:
	_rect(image, Rect2i(-3, -28, 6, 28), c[0])
	_ellipse(image, Vector2(0, -28), Vector2(3, 3), c[0])
	_rect(image, Rect2i(-9, -15, 6, 3), c[0])
	_rect(image, Rect2i(-9, -22, 3, 9), c[0])
	_ellipse(image, Vector2(-7.5, -22), Vector2(1.5, 1.5), c[0])
	_rect(image, Rect2i(3, -19, 6, 3), c[0])
	_rect(image, Rect2i(6, -26, 3, 9), c[0])
	_ellipse(image, Vector2(7.5, -26), Vector2(1.5, 1.5), c[0])
	_rect(image, Rect2i(1, -28, 2, 28), c[1])
	_rect(image, Rect2i(-2, -27, 1, 24), c[2])
	return 5.0


func _paint_barrel(image: Image, c: Array[Color], _frame: int) -> float:
	_ellipse(image, Vector2(0, -5), Vector2(5, 5.5), c[0])
	_rect(image, Rect2i(1, -9, 1, 8), c[1])
	_rect(image, Rect2i(3, -8, 1, 6), c[1])
	_rect(image, Rect2i(-1, -12, 2, 2), c[2])
	return 5.0


func _paint_bones(image: Image, c: Array[Color], _frame: int) -> float:
	_line(image, Vector2(-6, -4), Vector2(6, -2), c[0], 2)
	_line(image, Vector2(-3, -1), Vector2(4, -6), c[1], 2)
	for end: Vector2 in [Vector2(-6.5, -4), Vector2(6.5, -1.5)]:
		_ellipse(image, end, Vector2(1.6, 1.6), c[0])
	return 0.0


func _paint_dry_bush(image: Image, c: Array[Color], _frame: int) -> float:
	for k: int in 7:
		var twig := Vector2.from_angle(deg_to_rad(-160.0 + 23.0 * k)) * (7.0 + (k * 5) % 4)
		_line(image, Vector2(0, -1), Vector2(0, -1) + twig, c[k % 2])
	return 6.0


## A ball of twigs that turns a quarter of its symmetry and bobs a frame.
func _paint_tumbleweed(image: Image, c: Array[Color], frame: int) -> float:
	var bobs: Array[float] = [0.0, 2.0, 3.0, 2.0]
	var centre := Vector2(0, -7 - bobs[frame])
	for k: int in 12:
		var angle := TAU * k / 12.0 + TAU / 6.0 * frame / 4.0
		var chord := Vector2.from_angle(angle + 2.2) * 6.0
		_line(image, centre + Vector2.from_angle(angle) * 6.0, centre + chord, c[k % 2])
	return 6.0


# Shapes, in pixels from the foot.


## A house: walls `half` wide either side of its front corner and `height` tall, under a hipped
## roof `roof` tall, with a door and a window.
func _house(image: Image, c: Array[Color], half: int, height: int, roof: int) -> void:
	_box(image, half, height, c[0], c[1])
	var eave_y := -half * 0.5 - height + 0.5
	var front := Vector2(0, -height + 1)
	var apex := Vector2(0, -half * 0.5 - height - roof)
	_poly(image, [Vector2(-half - 1, eave_y), front, apex], c[2])
	_poly(image, [front, Vector2(half + 1, eave_y), apex], c[3])
	for x: int in range(-7, -3):
		_rect(image, Rect2i(x, -7 - _face_rise(x), 1, 7), c[4])
	_window(image, 7, height - 6, c[5])


## The walls of a box whose footprint's front corner is on the foot: its left face, then its right.
func _box(image: Image, half: int, height: int, left: Color, right: Color) -> void:
	var side := Vector2(half, -half * 0.5)
	var up := Vector2(0, -height)
	_poly(image, [Vector2(-side.x, side.y), Vector2.ZERO, up, Vector2(-side.x, side.y) + up], left)
	_poly(image, [Vector2.ZERO, side, side + up, up], right)


## A box's flat top.
static func _top(half: int, height: int) -> Array[Vector2]:
	var y := -half * 0.5 - height
	return [
		Vector2(-half, y), Vector2(0, y - half * 0.5), Vector2(half, y), Vector2(0, y + half * 0.5)
	]


## How far a box's bottom edge rises above the foot at `x`, half a pixel a pixel.
static func _face_rise(x: int) -> int:
	return absi(x) >> 1


## A window 3 pixels wide and 4 tall, on the face that `x` is on, its bottom `rise` above the
## face's bottom edge.
func _window(image: Image, x: int, rise: int, color: Color) -> void:
	for dx: int in 3:
		var column := x + dx if x > 0 else x - dx
		_rect(image, Rect2i(column, -rise - 4 - _face_rise(column), 1, 4), color)


func _rect(image: Image, rect: Rect2i, color: Color) -> void:
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			_plot(image, Vector2i(x, y), color)


## Fills the pixels whose centres are inside the ellipse.
func _ellipse(image: Image, centre: Vector2, radii: Vector2, color: Color) -> void:
	for y: int in range(floori(centre.y - radii.y), ceili(centre.y + radii.y)):
		for x: int in range(floori(centre.x - radii.x), ceili(centre.x + radii.x)):
			if ((Vector2(x, y) + Vector2(0.5, 0.5) - centre) / radii).length_squared() <= 1.0:
				_plot(image, Vector2i(x, y), color)


## Fills the pixels whose centres are inside the polygon.
func _poly(image: Image, points: Array[Vector2], color: Color) -> void:
	var polygon := PackedVector2Array(points)
	var box := Rect2(points[0], Vector2.ZERO)
	for point: Vector2 in points:
		box = box.expand(point)
	for y: int in range(floori(box.position.y), ceili(box.end.y)):
		for x: int in range(floori(box.position.x), ceili(box.end.x)):
			if Geometry2D.is_point_in_polygon(Vector2(x, y) + Vector2(0.5, 0.5), polygon):
				_plot(image, Vector2i(x, y), color)


func _line(image: Image, start: Vector2, end: Vector2, color: Color, width := 1) -> void:
	var steps := maxi(1, ceili(maxf(absf(end.x - start.x), absf(end.y - start.y))))
	for k: int in steps + 1:
		var point := Vector2i(start.lerp(end, float(k) / steps).floor())
		_rect(image, Rect2i(point, Vector2i(width, width)), color)


## Sets a pixel, in pixels from the foot, if it is on the canvas.
static func _plot(image: Image, pixel: Vector2i, color: Color) -> void:
	var at := canvas_foot() + pixel
	if Rect2i(Vector2i.ZERO, image.get_size()).has_point(at):
		image.set_pixelv(at, color)
