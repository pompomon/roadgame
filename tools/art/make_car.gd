extends SceneTree
## Makes the car's sheet (plan.md §5.3, docs/M5.md §5.7): assets/car/car.png, FRAMES frames of
## FRAME_SIZE in a row, and its skid mark, assets/car/skid.png. Frame f faces the direction f of
## CarController.frame(), clockwise from straight up; the last is the wreck. Each frame has the
## car's ground centre at FOOT. Row k has the wheels a quarter turn on from row k - 1, as they roll
## forward (docs/VISUALS.md §5.1): CarController.PHASES rows, with the same silhouette. They are
## placeholders an artist may replace with art that keeps that layout and the master palette
## (tests/unit/test_car_art.gd). The car is boxes and wheels, splatted in fine steps into a depth
## buffer and shaded by the side they are on. The output is the same on every run. From the
## repository root:
##   godot --headless -s tools/art/make_car.gd
## then tools/ci/import.sh, and commit the PNG files with their .import files.

const MakeArt := preload("res://tools/art/make_art.gd")
const PATH := "res://assets/car/car.png"
## A skid mark (SkidMarks), along +x.
const SKID_PATH := "res://assets/car/skid.png"
const SKID_SIZE := Vector2i(6, 2)
const FRAMES := CarController.FRAMES + 1
const PHASES := CarController.PHASES
const FRAME_SIZE := CarController.FRAME_SIZE
const FOOT := CarController.FOOT
## The boxes, in the car's own axes: along it (tiles, forward is +), across it (tiles, right is +)
## and up (screen pixels). Each has its colours on the top, the lit sides and the shaded sides.
const BOXES := [
	[Vector2(-0.15, 0.15), Vector2(-0.09, 0.09), Vector2(1.0, 5.0), ["red", "red", "village roof"]],
	[
		Vector2(-0.1, 0.05),
		Vector2(-0.075, 0.075),
		Vector2(5.0, 8.0),
		["red", "foam", "tunnel road"]
	],
	# The lights stand a little proud of the body, so that they are nearer than it.
	[Vector2(0.14, 0.16), Vector2(-0.08, -0.05), Vector2(2.0, 4.0), ["yellow", "yellow", "yellow"]],
	[Vector2(0.14, 0.16), Vector2(0.05, 0.08), Vector2(2.0, 4.0), ["yellow", "yellow", "yellow"]],
	[Vector2(-0.16, -0.14), Vector2(-0.08, -0.05), Vector2(2.0, 4.0), ["fire", "fire", "fire"]],
	[Vector2(-0.16, -0.14), Vector2(0.05, 0.08), Vector2(2.0, 4.0), ["fire", "fire", "fire"]],
]
## The wheels: a cylinder each side of each axle, WHEEL_RADIUS screen pixels round, with its axle
## WHEEL_RADIUS up. The axles are WHEEL_ALONG tiles along the car, the rear one where the skid
## marks start (Tuning.SKID_REAR), and each wheel reaches across the car from WHEEL_ACROSS.x tiles
## to WHEEL_ACROSS.y, a little proud of the body. Its tyre is ink, and its outer face's hub, the
## part within HUB of the radius, HUB_COLOR. A quarter of the wheel is marked, MARK_COLOR on the hub
## and TREAD_MARK on the tread, and turns a quarter of the way round each row as the wheel rolls
## forward: its top towards the front.
const WHEEL_RADIUS := 2.5
const WHEEL_ALONG: Array[float] = [0.09, -0.09]
const WHEEL_ACROSS := Vector2(0.07, 0.1)
const HUB := 0.6
const HUB_COLOR := "asphalt light"
const MARK_COLOR := "white"
const TREAD_MARK := "asphalt"
## The wreck's colours for each of the car's, and its outline's. It is burnt grey, but none of its
## main colours is ink: the smoke over it must show (test_car_controller.gd).
const WRECK := {
	"red": "asphalt",
	"village roof": "shadow",
	"foam": "tunnel road",
	"tunnel road": "shadow",
	"yellow": "shadow",
	"fire": "fire",
	"ink": "tunnel road",
	"asphalt light": "shadow",
	"white": "shadow",
	"asphalt": "tunnel road",
}
const WRECK_OUTLINE := "tunnel road"
## The splats' step, in screen pixels.
const STEP := 0.2
## The light comes from the screen's upper left: a side lit when its normal's screen direction
## points up or left of this.
const LIGHT := Vector2(-1.0, -0.6)

var _palette: Dictionary[String, Color] = {}


func _initialize() -> void:
	_palette = MakeArt.palette()
	var sheet := Image.create_empty(
		FRAME_SIZE.x * FRAMES, FRAME_SIZE.y * PHASES, false, Image.FORMAT_RGBA8
	)
	for phase: int in PHASES:
		for f: int in FRAMES:
			var wreck := f == FRAMES - 1
			# The wreck lies across the road, as the crash leaves it, and its wheels turn no more.
			var image := _frame(heading(3 if wreck else f), wreck, 0 if wreck else phase)
			var at := Vector2i(f, phase) * FRAME_SIZE
			sheet.blit_rect(image, Rect2i(Vector2i.ZERO, FRAME_SIZE), at)
	DirAccess.make_dir_recursive_absolute(PATH.get_base_dir())
	_save(sheet, PATH)
	var skid := Image.create_empty(SKID_SIZE.x, SKID_SIZE.y, false, Image.FORMAT_RGBA8)
	skid.fill(_palette["ink"])
	_save(skid, SKID_PATH)
	quit()


static func _save(image: Image, path: String) -> void:
	var error := image.save_png(path)
	if error != OK:
		push_error("make_car: can't write %s (%s)" % [path, error_string(error)])
	else:
		print("make_car: %s, %d × %d" % [path, image.get_width(), image.get_height()])


## The heading in tile space whose screen direction is frame f's.
static func heading(f: int) -> Vector2:
	var angle := f * TAU / CarController.FRAMES
	var screen := Vector2(sin(angle), -cos(angle))
	# The inverse of Iso.tile_to_world() for a direction.
	var along := screen.x / (Iso.TILE_W * 0.5)
	var down := screen.y / (Iso.TILE_H * 0.5)
	return Vector2(along + down, down - along).normalized()


func _frame(forward: Vector2, wreck: bool, phase: int) -> Image:
	var image := Image.create_empty(FRAME_SIZE.x, FRAME_SIZE.y, false, Image.FORMAT_RGBA8)
	var depth := PackedFloat32Array()
	depth.resize(FRAME_SIZE.x * FRAME_SIZE.y)
	depth.fill(-INF)
	var right := Vector2(-forward.y, forward.x)
	for box: Array in BOXES:
		_splat_box(image, depth, box, forward, right, wreck)
	for along: float in WHEEL_ALONG:
		for side: float in [-1.0, 1.0]:
			_splat_wheel(image, depth, along, side, forward, right, wreck, phase)
	_outline(image, _palette[WRECK_OUTLINE if wreck else "ink"])
	return image


## Splats the six sides of `box`, each splat drawn unless a nearer one took its pixel.
func _splat_box(
	image: Image,
	depth: PackedFloat32Array,
	box: Array,
	forward: Vector2,
	right: Vector2,
	wreck: bool
) -> void:
	var along: Vector2 = box[0]
	var across: Vector2 = box[1]
	var up: Vector2 = box[2]
	var names: Array = box[3]
	var tile_step := STEP / (Iso.TILE_W * 0.5)
	var u := along.x
	while u <= along.y + 1e-6:
		var v := across.x
		while v <= across.y + 1e-6:
			var w := up.x
			while w <= up.y + 1e-6:
				var normal := _normal(u, v, w, along, across, up, tile_step, forward, right)
				if normal != Vector3.ZERO:
					var ground := Iso.tile_to_world(forward * u + right * v)
					_plot(image, depth, ground, w, _shade(names, normal, wreck))
				w += STEP
			v += tile_step
		u += tile_step


## Splats the wheel on side `side` (1 right, -1 left) of the axle `along` tiles along the car: its
## tread and both its faces, each splat drawn unless a nearer one took its pixel.
func _splat_wheel(
	image: Image,
	depth: PackedFloat32Array,
	along: float,
	side: float,
	forward: Vector2,
	right: Vector2,
	wreck: bool,
	phase: int
) -> void:
	var tile_step := STEP / (Iso.TILE_W * 0.5)
	# The wheel is round as the 2:1 view shows a length across the screen.
	var radius := WHEEL_RADIUS / Iso.WIDTH_PX
	var u := along - radius
	while u <= along + radius + 1e-6:
		var v := WHEEL_ACROSS.x
		while v <= WHEEL_ACROSS.y + 1e-6:
			var w := 0.0
			while w <= 2.0 * WHEEL_RADIUS + 1e-6:
				# Where the point is on the wheel's side, with the radius 1: forward, then up.
				var spoke := Vector2((u - along) / radius, (w - WHEEL_RADIUS) / WHEEL_RADIUS)
				var color_name := _wheel_color(spoke, v, tile_step, phase)
				if color_name != "":
					var ground := Iso.tile_to_world(forward * u + right * v * side)
					_plot(
						image,
						depth,
						ground,
						w,
						_palette[WRECK[color_name] if wreck else color_name]
					)
				w += STEP
			v += tile_step
		u += tile_step


## The colour of the point of a wheel at `spoke` on its side, `v` tiles across the car, or "" inside
## it or outside it. A quarter of the wheel is marked, as if painted across it, at the angle of
## `phase`: on its outer face, the hub's mark shows it, and on its tread, which shows from ahead
## and behind, TREAD_MARK.
static func _wheel_color(spoke: Vector2, v: float, tile_step: float, phase: int) -> String:
	var reach := spoke.length()
	if reach > 1.0:
		return ""
	# The mark starts at the top and turns towards the front: clockwise, seen from the right.
	var mark := TAU / 4.0 - phase * TAU / PHASES
	var marked := absf(wrapf(spoke.angle() - mark, -PI, PI)) < PI / PHASES
	if v > WHEEL_ACROSS.y - tile_step:
		if reach > HUB:
			return "ink"
		return MARK_COLOR if marked else HUB_COLOR
	if reach > 1.0 - STEP / WHEEL_RADIUS:
		return TREAD_MARK if marked else "ink"
	if v < WHEEL_ACROSS.x + tile_step:
		return "ink"
	return ""


## Draws the splat `w` pixels above the point `ground` of the car's ground, in screen pixels from
## its ground centre, unless a nearer splat took its pixel.
func _plot(
	image: Image, depth: PackedFloat32Array, ground: Vector2, w: float, color: Color
) -> void:
	var at := Vector2(FOOT) + ground - Vector2(0.0, w)
	var pixel := Vector2i(at.floor())
	if Rect2i(Vector2i.ZERO, FRAME_SIZE).has_point(pixel):
		# Nearer the viewer: further down the screen on the ground, or higher up.
		var near := 1.732 * ground.y + 0.577 * w
		var k := pixel.y * FRAME_SIZE.x + pixel.x
		if near > depth[k]:
			depth[k] = near
			image.set_pixelv(pixel, color)


## The outward normal of the side the point (u, v, w) of a box is on, as (screen x, screen y, up),
## or zero inside the box.
static func _normal(
	u: float,
	v: float,
	w: float,
	along: Vector2,
	across: Vector2,
	up: Vector2,
	tile_step: float,
	forward: Vector2,
	right: Vector2
) -> Vector3:
	if w > up.y - STEP:
		return Vector3(0.0, 0.0, 1.0)
	var side := Vector2.ZERO
	if u < along.x + tile_step:
		side = -forward
	elif u > along.y - tile_step:
		side = forward
	elif v < across.x + tile_step:
		side = -right
	elif v > across.y - tile_step:
		side = right
	else:
		return Vector3.ZERO
	var screen := Iso.tile_to_world(side).normalized()
	return Vector3(screen.x, screen.y, 0.0)


func _shade(names: Array, normal: Vector3, wreck: bool) -> Color:
	var color_name: String = names[0]
	if normal.z == 0.0:
		var lit := Vector2(normal.x, normal.y).dot(LIGHT) > 0.0
		color_name = names[1] if lit else names[2]
	return _palette[WRECK[color_name] if wreck else color_name]


func _outline(image: Image, ink: Color) -> void:
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
