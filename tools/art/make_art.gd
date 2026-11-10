extends SceneTree
## Makes each area's art (M5_PLAN.md §5.5): its road sheet, its ground and the ground's edge, in
## the master palette. They are placeholders that an artist may replace, file by file, with art
## that keeps the contract tests/unit/test_area_art.gd checks: the road sheet is opaque exactly
## where GreyboxAtlas.road_image() is; the ground tiles seamlessly, with a size that is a multiple
## of the ground cells' period; the edge is the ground's first rows, thinning out further down; and
## every pixel is a colour of assets/palette.gpl. The output is the same on every run: the ground's
## variants come from one seeded generator. From the repository root:
##   godot --headless -s tools/art/make_art.gd
## then tools/ci/import.sh, and commit the PNG files with their .import files.

const PALETTE := "res://assets/palette.gpl"
## Each area's colours, by their names in the palette: its ground, a dark and a light shade, and an
## accent; then its road's surface, speckles and edge; and how its ground is drawn.
const AREAS := {
	&"city": ["city", "asphalt", "asphalt light", "line", "paving"],
	&"rural": ["rural", "rural dirt", "plank", "rural dark", "furrows"],
	&"meadows": ["meadows", "asphalt", "asphalt light", "line", "grass"],
	&"village": ["village", "asphalt light", "asphalt", "white", "grass"],
	&"desert": ["desert", "asphalt", "asphalt light", "desert light", "ripples"],
}
## The other rows of a road sheet (GreyboxAtlas.Row): surface, speckles and edge.
const ROWS := {
	GreyboxAtlas.Row.DEAD_END: ["red", "shadow", "white"],
	GreyboxAtlas.Row.TUNNEL: ["tunnel road", "shadow", "asphalt"],
	GreyboxAtlas.Row.BRIDGE: ["plank", "shadow", "line"],
}
## One period of each ground: 16 × 16 road tiles' worth of ground cells, of which each shows one of
## 4 variants: plain, a dark tuft, a light tuft, or the accent. Their weights:
const GROUND_SIZE := Vector2i(512, 256)
const VARIANT_WEIGHTS: Array[float] = [0.55, 0.2, 0.2, 0.05]

var _rng := RandomNumberGenerator.new()
var _palette: Dictionary[String, Color] = {}


func _initialize() -> void:
	_rng.seed = 7
	_palette = palette()
	var silhouette := GreyboxAtlas.road_image()
	for area: StringName in AREAS:
		var style: Array = AREAS[area]
		var dir := "res://assets/%s/" % area
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
		var ground := _ground(style)
		_save(_road(silhouette, style), dir + "road.png")
		_save(ground, dir + "ground.png")
		_save(GreyboxAtlas.edge_image(ground), dir + "edge.png")
	quit()


## The palette's colours by name.
static func palette() -> Dictionary[String, Color]:
	var colors: Dictionary[String, Color] = {}
	for line: String in FileAccess.get_file_as_string(PALETTE).split("\n"):
		var fields := line.split("\t")
		var rgb := fields[0].split(" ", false)
		if fields.size() == 2 and rgb.size() == 3 and rgb[0].is_valid_int():
			colors[fields[1]] = Color8(rgb[0].to_int(), rgb[1].to_int(), rgb[2].to_int())
	return colors


func _road(silhouette: Image, style: Array) -> Image:
	var image := Image.create_empty(
		silhouette.get_width(), silhouette.get_height(), false, Image.FORMAT_RGBA8
	)
	var size := Vector2i(Iso.TILE_W, Iso.TILE_H)
	var inner := Tuning.ROAD_HALF_WIDTH - GreyboxAtlas.EDGE_WIDTH
	for row: int in GreyboxAtlas.Row.size():
		var colors: Array = ROWS.get(row, [style[1], style[2], style[3]])
		var surface := _palette[colors[0]]
		var speckle := _palette[colors[1]]
		var edge := _palette[colors[2]]
		for exits: int in range(1, Heading.ALL + 1):
			var origin := Vector2i(exits - 1, row) * size
			for y: int in size.y:
				for x: int in size.x:
					if silhouette.get_pixel(origin.x + x, origin.y + y).a == 0.0:
						continue
					var local := GreyboxAtlas.tile_local(Vector2i(x, y), size)
					var color := surface
					if RoadGeometry.distance_to_centreline(exits, local) > inner:
						color = edge
					elif row == GreyboxAtlas.Row.BRIDGE and y % 6 == 0:
						color = speckle
					elif _noise(x, y, row) < 0.08:
						color = speckle
					image.set_pixel(origin.x + x, origin.y + y, color)
	return image


func _ground(style: Array) -> Image:
	var name: String = style[0]
	var shades: Array[Color] = [
		_palette[name + " ground"], _palette[name + " dark"], _palette[name + " light"]
	]
	var accent: Color = _palette[_accent(name)]
	@warning_ignore("integer_division")
	var period := GROUND_SIZE / GreyboxAtlas.ground_period()
	# The variant of each ground cell of the period, by its row and its column on screen.
	var variants: Dictionary[Vector2i, int] = {}
	for s: int in period.y * 2:
		for t: int in period.x * 2:
			if (s + t) % 2 == 0:
				variants[Vector2i(s, t)] = _rng.rand_weighted(PackedFloat32Array(VARIANT_WEIGHTS))
	var image := Image.create_empty(GROUND_SIZE.x, GROUND_SIZE.y, false, Image.FORMAT_RGBA8)
	for y: int in GROUND_SIZE.y:
		for x: int in GROUND_SIZE.x:
			var g := Iso.world_to_tile(Vector2(x, y) + Vector2(0.5, 0.5)) * Iso.GROUND_PER_TILE
			var cell := Vector2i(g.floor())
			var key := Vector2i(
				posmod(cell.x + cell.y, period.y * 2), posmod(cell.x - cell.y, period.x * 2)
			)
			var local := g - Vector2(cell)
			image.set_pixel(
				x, y, _ground_pixel(style[4], variants[key], local, Vector2i(x, y), shades, accent)
			)
	return image


func _ground_pixel(
	kind: String, variant: int, local: Vector2, pixel: Vector2i, shades: Array[Color], accent: Color
) -> Color:
	var shade := _pattern(kind, variant, local, pixel)
	if shade < 0:
		shade = _tuft(variant, local, pixel)
	return accent if shade == 3 else shades[shade]


## The shade (0 to 2) or, as 3, the accent, that the area's pattern gives a ground pixel, or -1.
static func _pattern(kind: String, variant: int, local: Vector2, pixel: Vector2i) -> int:
	match kind:
		"paving":
			if local.x < 0.07 or local.y < 0.07:
				return 1
			if variant == 3:
				return 3
		"furrows":
			if posmod(pixel.y - (pixel.x >> 1), 8) == 0:
				return 1
		"ripples":
			if posmod(pixel.y * 3 + int(8.0 * sin(pixel.x * 0.09)), 24) == 0:
				return 2
	return -1


## The shade or accent of a ground pixel off the pattern: a tuft in the cell's variant, or speckles.
static func _tuft(variant: int, local: Vector2, pixel: Vector2i) -> int:
	var middle := (local - Vector2(0.5, 0.5)).length()
	if variant in [1, 2] and middle < 0.3 and (pixel.x + pixel.y) % 2 == 0:
		return variant
	if variant == 3 and middle < 0.12:
		return 3
	return 1 if _noise(pixel.x, pixel.y, 9) < 0.03 else 0


func _accent(area: String) -> String:
	for name: String in _palette:
		if (
			name.begins_with(area + " ")
			and not name.ends_with(" ground")
			and not name.ends_with(" dark")
			and not name.ends_with(" light")
		):
			return name
	return area + " dark"


## A value in [0, 1) that depends only on its arguments.
static func _noise(x: int, y: int, salt: int) -> float:
	var h := (x * 73856093) ^ (y * 19349663) ^ (salt * 83492791)
	h = (h ^ (h >> 13)) * 1274126177
	return float(posmod(h ^ (h >> 16), 1024)) / 1024.0


static func _save(image: Image, path: String) -> void:
	var error := image.save_png(path)
	if error != OK:
		push_error("make_art: can't write %s (%s)" % [path, error_string(error)])
	else:
		print("make_art: %s, %d × %d" % [path, image.get_width(), image.get_height()])
