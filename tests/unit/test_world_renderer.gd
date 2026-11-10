extends GutTest

const Art := preload("res://tests/helpers/art_checks.gd")
const Fixtures := preload("res://tests/helpers/road_fixtures.gd")
## Screens, in pixels: the Fold4 folded and unfolded, a phone, a 4K and a 32:9 monitor, each both
## ways round, and a browser window four times as tall as it is wide.
const SCREENS: Array[Vector2] = [
	Vector2(904, 2316),
	Vector2(1812, 2176),
	Vector2(1080, 2400),
	Vector2(3840, 2160),
	Vector2(5120, 1440),
	Vector2(400, 1600),
]

var _world: WorldRenderer
var _buffer: RoadBuffer
var _areas: Dictionary[StringName, AreaDef] = {}
var _images: Dictionary[Texture2D, Image] = {}


func before_each() -> void:
	var scene: PackedScene = load("res://world/world.tscn")
	_world = add_child_autofree(scene.instantiate())
	_buffer = RoadBuffer.new(RoadGenerator.new(11, Fixtures.schedule()))
	for entry: AreaScheduleEntry in Fixtures.schedule().entries:
		_areas[entry.area.id] = entry.area


## Counts the buffered tiles drawn wrongly on the road layer: each must be its area's road sheet's.
func _wrong_cells() -> int:
	var road: TileMapLayer = _world.get_node("%RoadLayer")
	var tiles := _buffer.tiles()
	var wrong := absi(road.get_used_cells().size() - tiles.size())
	for tile: RoadTile in tiles:
		if road.get_cell_atlas_coords(tile.cell) != GreyboxAtlas.road_coords(tile, false):
			wrong += 1
		var id := road.get_cell_source_id(tile.cell)
		var source := road.tile_set.get_source(id) if road.tile_set.has_source(id) else null
		if (
			source == null
			or (source as TileSetAtlasSource).texture != _areas[tile.area_id].road_sheet
		):
			wrong += 1
	return wrong


## How many runs of path tiles in one area the buffer has.
func _area_runs() -> int:
	var runs := 1
	for index: int in range(_buffer.first_index() + 1, _buffer.last_index() + 1):
		if _buffer.path_tile(index).area_id != _buffer.path_tile(index - 1).area_id:
			runs += 1
	return runs


func test_draws_the_buffer_and_follows_refills_and_frees() -> void:
	_buffer.start()
	_world.build(Fixtures.schedule())
	_world.bind(_buffer)
	assert_eq(_wrong_cells(), 0, "tiles generated before bind()")
	for i: int in range(1, 400):
		_buffer.on_car_path_index(i)
	assert_gt(_buffer.first_index(), 300)
	assert_eq(_wrong_cells(), 0, "after refills and frees")


func test_a_new_buffer_replaces_the_last_one() -> void:
	# A retry binds the next run's buffer to the same renderer (M3_PLAN.md J11).
	var last := RoadBuffer.new(RoadGenerator.new(5, Fixtures.schedule()))
	last.start()
	_world.build(Fixtures.schedule())
	_world.bind(last)
	for i: int in range(1, 40):
		last.on_car_path_index(i)
	_buffer.start()
	_world.bind(_buffer)
	assert_eq(_wrong_cells(), 0, "only the new buffer's tiles")
	var bands := _world.get_node("%Ground").get_child_count()
	assert_eq(bands, _area_runs(), "and its areas' ground")
	for i: int in range(40, 100):
		last.on_car_path_index(i)
	assert_eq(_wrong_cells(), 0, "the last buffer's refills and frees change nothing")
	assert_eq(_world.get_node("%Ground").get_child_count(), bands)
	for i: int in range(1, 100):
		_buffer.on_car_path_index(i)
	assert_eq(_wrong_cells(), 0, "the new buffer's do")


func test_each_area_shows_its_ground_and_blends_it_into_the_last_ones() -> void:
	# plan.md §5.3 and IMPLEMENTATION_PLAN.md M4.3, with bands (M5_PLAN.md §5.5): across the screen,
	# each area's ground shows from the centre of its path tile TRANSITION_TILES on, and below it
	# its edge, over the last area's ground. The edge's pixels are its ground's, where they would be.
	_world.build(Fixtures.schedule())
	_world.bind(_buffer)
	_buffer.start()
	var changes: Array[StringName] = []
	var last := _areas[_buffer.path_tile(0).area_id]
	var area := last
	var first := 0
	var index := 0
	while changes.size() < 4 or index - first <= Tuning.TRANSITION_TILES:
		index += 1
		_buffer.on_car_path_index(index)
		var tile := _buffer.path_tile(index)
		if tile.area_id != area.id:
			last = area
			area = _areas[tile.area_id]
			first = index
			changes.append(area.id)
			var edge_problem := _edge_problem(_centre(tile.cell).y - GreyboxAtlas.edge_rows())
			if edge_problem != "":
				fail_test("%s: %s" % [area.id, edge_problem])
				return
		var row := _shown_across(_centre(tile.cell) - Vector2(0.0, 0.5))
		var own: int = row.get(area.ground, 0)
		if first > 0 and index - first < Tuning.TRANSITION_TILES:
			own = row.get(area.ground_edge, 0)
			var under: int = row.get(last.ground, 0)
			if own + under != 128 or index == first and own > 12:
				fail_test("%s's path tile %d of its first: %s" % [area.id, index - first, row])
				return
		elif own != 128:
			fail_test("%s's path tile %d: %s" % [area.id, index - first, row])
			return
	assert_eq(changes, [&"rural", &"meadows", &"village", &"desert"] as Array[StringName])
	var bands := _world.get_node("%Ground").get_child_count()
	assert_lt(bands, changes.size() + 1, "the bands that can't show again are gone")


func test_the_ground_stays_put() -> void:
	# A band's region grows as the buffer does, and the oldest goes, but no pixel in view changes.
	_world.build(Fixtures.schedule())
	_world.bind(_buffer)
	_buffer.start()
	var seen: Dictionary[Vector2, Color] = {}
	var compared := 0
	for index: int in range(1, 400):
		_buffer.on_car_path_index(index)
		for k: int in range(maxi(_buffer.first_index(), index - Tuning.BUFFER_BEHIND), index + 16):
			var centre := _centre(_buffer.path_tile(k).cell)
			for x: float in [-224.5, -96.5, 0.5, 32.5, 160.5]:
				var at := centre + Vector2(x, 8.5)
				var color := _color_at(at)
				if seen.has(at):
					compared += 1
					if seen[at] != color:
						fail_test(
							"path tile %d: %s turned from %s to %s" % [index, at, seen[at], color]
						)
						return
				seen[at] = color
	assert_gt(compared, 10000)


func test_the_ground_covers_every_view_on_a_long_drive() -> void:
	_world.build(Fixtures.schedule())
	_world.bind(_buffer)
	_buffer.start()
	var view := _largest_view()
	for index: int in range(0, 400):
		if index > 0:
			_buffer.on_car_path_index(index)
		var car := _centre(_buffer.path_tile(index).cell)
		var gap := _gap(Rect2(car + view.position, view.size))
		if gap != "":
			fail_test("path tile %d: %s" % [index, gap])
			return
	pass_test("%s around the car" % view)


func test_an_area_without_art_gets_a_checker_of_its_colour() -> void:
	# The grey box (IMPLEMENTATION_PLAN.md M4.3): the ground cells in two shades of id_color, which
	# line up with tile space, and the same over the area's first path tiles, thinning out.
	var schedule := Fixtures.set_piece_schedule(3, &"", 0)
	schedule.entries[0].area.id_color = Color.RED
	schedule.entries[1].area.id_color = Color.BLUE
	_buffer = RoadBuffer.new(RoadGenerator.new(11, schedule))
	_world.build(schedule)
	_world.bind(_buffer)
	_buffer.start()
	var first := 0
	var index := 0
	while first == 0 or index <= first + Tuning.TRANSITION_TILES + 2:
		index += 1
		_buffer.on_car_path_index(index)
		var tile := _buffer.path_tile(index)
		if first == 0 and tile.area_id == &"after":
			first = index
		if first > 0 and index == first + 1:
			var line := _centre(_buffer.path_tile(first).cell).y - GreyboxAtlas.edge_rows()
			assert_eq(_edge_problem(line), "", "the edge continues the ground")
			var row := _shown_across(_centre(tile.cell) - Vector2(0.0, 0.5))
			var blend: int = row.get(GreyboxAtlas.edge_texture(Color.BLUE), 0)
			assert_between(blend, 26, 102, "a blend halfway: %s" % row)
		# Around the first path tiles of "after", and the one after them, both checkers show.
		var blended := first > 0 and index - first <= Tuning.TRANSITION_TILES
		var color := Color.RED if tile.area_id == &"before" else Color.BLUE
		var rows := Iso.GROUND_PER_TILE
		for y: int in rows:
			for x: int in rows:
				var cell := tile.cell * rows + Vector2i(x, y)
				var at := Iso.tile_to_world((Vector2(cell) + Vector2(0.5, 0.5)) / rows)
				var shade := GreyboxAtlas.GROUND_SHADE * posmod(cell.x + cell.y, 2)
				# As 8-bit values, as the texture has them.
				var got := Art.pixel(_color_at(at))
				if blended and got == Art.pixel(Color.RED.darkened(shade)):
					continue
				if got != Art.pixel(color.darkened(shade)):
					fail_test("path tile %d, ground cell %s: %s" % [index, cell, got])
					return
		if index > 100:
			fail_test("no change of area")
			return


func _centre(cell: Vector2i) -> Vector2:
	return Iso.tile_to_world(Iso.cell_centre(cell))


## The ground's sprites, as they draw: each band, then its edge.
func _ground_sprites() -> Array[Sprite2D]:
	var sprites: Array[Sprite2D] = []
	for band: Sprite2D in _world.get_node("%Ground").get_children():
		sprites.append(band)
		for edge: Sprite2D in band.get_children():
			sprites.append(edge)
	return sprites


## The pixel of `sprite` at world point `at`, as Sprite2D draws it: over its get_rect(), its region
## of its texture or the whole texture, repeated if its own texture_repeat is ENABLED and clamped
## otherwise. Clear outside its rect, unless `anywhere`.
func _texel(sprite: Sprite2D, at: Vector2, anywhere := false) -> Color:
	var rect := sprite.get_rect()
	var local := sprite.get_global_transform().affine_inverse() * at
	if not anywhere and not rect.has_point(local):
		return Color(0, 0, 0, 0)
	if not _images.has(sprite.texture):
		_images[sprite.texture] = sprite.texture.get_image()
	var image := _images[sprite.texture]
	var origin := sprite.region_rect.position if sprite.region_enabled else Vector2.ZERO
	var texel := Vector2i((origin + local - rect.position).floor())
	var size := image.get_size()
	if sprite.texture_repeat == CanvasItem.TEXTURE_REPEAT_ENABLED:
		return image.get_pixel(posmod(texel.x, size.x), posmod(texel.y, size.y))
	texel = texel.clamp(Vector2i.ZERO, size - Vector2i.ONE)
	return image.get_pixel(texel.x, texel.y)


## The part of the world that `sprite` draws over.
static func _drawn(sprite: Sprite2D) -> Rect2:
	return sprite.get_global_transform() * sprite.get_rect()


## The ground's sprite whose pixel shows at world point `at`, or null.
func _shown(at: Vector2) -> Sprite2D:
	var sprites := _ground_sprites()
	for k: int in range(sprites.size() - 1, -1, -1):
		if _texel(sprites[k], at).a > 0.0:
			return sprites[k]
	return null


func _color_at(at: Vector2) -> Color:
	var sprite := _shown(at)
	return _texel(sprite, at) if sprite != null else Color(0, 0, 0, 0)


## How many of the 128 pixels across from `at` each texture shows: 8 periods of the edges' dither.
func _shown_across(at: Vector2) -> Dictionary[Texture2D, int]:
	var counts: Dictionary[Texture2D, int] = {}
	for x: int in range(-64, 64):
		var sprite := _shown(at + Vector2(x, 0.0))
		var texture: Texture2D = sprite.texture if sprite != null else null
		counts[texture] = counts.get(texture, 0) + 1
	return counts


## What is wrong with the edge whose rows begin at `line`, or "": it continues its band's ground,
## where its pixels are, over 128 pixels across.
func _edge_problem(line: float) -> String:
	for band: Sprite2D in _world.get_node("%Ground").get_children():
		for edge: Sprite2D in band.get_children():
			if _drawn(edge).position.y != line:
				continue
			var x0 := _drawn(band).get_center().x
			for y: int in GreyboxAtlas.edge_rows():
				for x: int in 128:
					var at := Vector2(x0 + x + 0.5, line + y + 0.5)
					var pixel := _texel(edge, at)
					if pixel.a > 0.0 and pixel != _texel(band, at, true):
						return (
							"at %s, %s isn't the ground's %s" % [at, pixel, _texel(band, at, true)]
						)
			return ""
	return "no edge at %s" % line


## The first gap in the ground's cover of `view`, or "": what the bands cover, not their edges.
func _gap(view: Rect2) -> String:
	var rects: Array[Rect2] = []
	for band: Sprite2D in _world.get_node("%Ground").get_children():
		rects.append(_drawn(band))
	rects.sort_custom(func(a: Rect2, b: Rect2) -> bool: return a.position.y < b.position.y)
	var y := view.position.y
	for rect: Rect2 in rects:
		if rect.end.y <= y:
			continue
		if rect.position.y > y:
			return "nothing from y %s to %s in %s" % [y, rect.position.y, view]
		if rect.position.x > view.position.x or rect.end.x < view.end.x:
			return "%s doesn't reach across %s" % [rect, view]
		y = rect.end.y
		if y >= view.end.y:
			return ""
	return "nothing below y %s in %s" % [y, view]


## The largest part of the world, around the car, that the camera shows on any of SCREENS. The
## project stretches its canvas items to keep 360 by 640 pixels and expand the longer side
## (Window._update_viewport_size()); CameraRig zooms by the viewport's shorter side, and raises
## its view on a portrait screen. Its lookahead, and its smoothing's lag at the top speed, may move
## the view any way.
static func _largest_view() -> Rect2:
	var base := Vector2(
		ProjectSettings.get_setting("display/window/size/viewport_width"),
		ProjectSettings.get_setting("display/window/size/viewport_height")
	)
	var tile_step := Iso.tile_to_world(Vector2.RIGHT).length()
	var lag := Tuning.GLOBAL_SPEED_CAP * tile_step / Tuning.CAMERA_SMOOTHING
	var largest := Rect2()
	for screen: Vector2 in SCREENS:
		for size: Vector2 in [screen, Vector2(screen.y, screen.x)]:
			var viewport := Vector2(base.x, base.x * size.y / size.x).floor()
			if size.aspect() > base.aspect():
				viewport = Vector2(base.y * size.x / size.y, base.y).floor()
			var shown := viewport / CameraRig.zoom_for(viewport)
			var bias := Tuning.PORTRAIT_BIAS * shown.y if shown.y > shown.x else 0.0
			var view := Rect2(-shown / 2.0 - Vector2(0.0, bias), shown)
			largest = largest.merge(view.grow(Tuning.LOOKAHEAD_PX + lag))
	return largest


func test_debug_view_tints_dead_ends() -> void:
	_world.show_dead_ends = true
	_world.build(Fixtures.schedule())
	_world.bind(_buffer)
	_buffer.start()
	var road: TileMapLayer = _world.get_node("%RoadLayer")
	var dead_ends := 0
	for tile: RoadTile in _buffer.tiles():
		if tile.type == RoadTile.Type.DEAD_END:
			dead_ends += 1
			assert_eq(road.get_cell_atlas_coords(tile.cell).y, GreyboxAtlas.Row.DEAD_END)
	assert_gt(dead_ends, 0)


func test_layers_line_up_with_tile_space() -> void:
	_world.build(Fixtures.schedule())
	_world.bind(_buffer)
	_buffer.start()
	var road: TileMapLayer = _world.get_node("%RoadLayer")
	var cell := _buffer.path_tile(30).cell
	var centre := Iso.tile_to_world(Iso.cell_centre(cell))
	assert_almost_eq(road.position + road.map_to_local(cell), centre, Vector2(1e-3, 1e-3))


func test_disasters_draw_above_the_road_and_below_the_car() -> void:
	# World draws its children in order, and only Props sorts by y (M3_PLAN.md J5).
	var names: Array[StringName] = []
	for node: Node in _world.get_children():
		names.append(node.name)
	var order: Array[StringName] = [
		&"Ground", &"SetPieces", &"RoadLayer", &"DisasterLayer", &"Props"
	]
	assert_eq(names, order)
	var layer: Node2D = _world.get_node("%DisasterLayer")
	assert_false(layer.y_sort_enabled)
	assert_eq(layer.z_index, 0)


func test_set_pieces_draw_above_the_ground_and_below_the_road() -> void:
	# A river runs under the road; what must cover the car sets its own z_index (M4.4).
	var layer: Node2D = _world.get_node("%SetPieces")
	assert_eq(layer.get_index(), _world.get_node("%Ground").get_index() + 1)
	assert_false(layer.y_sort_enabled)
	assert_eq(layer.z_index, 0)
	assert_eq(_world.set_piece_scenes.keys(), [&"bridge", &"tunnel"])


func test_a_set_piece_comes_once_its_run_is_made_and_goes_with_its_last_tile() -> void:
	# Junction 12 is path tile 52, so the tunnel's run is tiles 53 to 56, and the buffer's first
	# batch ends at tile 55 (BUFFER_AHEAD): the run comes in two batches.
	var schedule := Fixtures.set_piece_schedule(13, &"tunnel", 4)
	_buffer = RoadBuffer.new(RoadGenerator.new(3, schedule))
	_world.build(schedule)
	_world.bind(_buffer)
	var car: Node2D = add_child_autofree(Node2D.new())
	_world.car = car
	_buffer.start()
	var pieces: Node2D = _world.get_node("%SetPieces")
	assert_eq(_buffer.last_index(), Tuning.BUFFER_AHEAD)
	assert_eq(_buffer.path_tile(53).set_piece, &"tunnel", "the run has begun")
	assert_eq(pieces.get_child_count(), 0, "but the buffer hasn't made all of it")
	_buffer.on_car_path_index(Tuning.BUFFER_AHEAD - Tuning.BUFFER_REFILL_AT + 1)
	assert_eq(pieces.get_child_count(), 1, "now it has")
	var tunnel := pieces.get_child(0) as Tunnel
	assert_eq(tunnel.car, car, "it follows the run's car")
	var cells := Rect2(_buffer.path_tile(53).cell, Vector2.ONE)
	assert_eq(tunnel.rect, cells.merge(Rect2(_buffer.path_tile(56).cell, Vector2.ONE)))
	assert_eq(_buffer.path_tile(57).set_piece, &"", "the run ends at 56")
	_buffer.on_car_path_index(56 + Tuning.BUFFER_BEHIND)
	assert_eq(_buffer.first_index(), 56, "its first tiles are gone")
	assert_eq(pieces.get_child_count(), 1, "but not its last")
	_buffer.on_car_path_index(57 + Tuning.BUFFER_BEHIND)
	assert_eq(pieces.get_child_count(), 0, "it goes with its last tile")


func test_a_new_buffer_drops_the_last_runs_set_pieces_and_car() -> void:
	var schedule := Fixtures.set_piece_schedule(1, &"bridge", 5)
	_buffer = RoadBuffer.new(RoadGenerator.new(3, schedule))
	_world.build(schedule)
	_world.bind(_buffer)
	_buffer.start()
	var car: Node2D = add_child_autofree(Node2D.new())
	_world.car = car
	var pieces: Node2D = _world.get_node("%SetPieces")
	assert_eq(pieces.get_child_count(), 1)
	assert_eq((pieces.get_child(0) as SetPiece).car, car, "the set piece follows the car")
	var next := RoadBuffer.new(RoadGenerator.new(4, schedule))
	_world.bind(next)
	assert_eq(pieces.get_child_count(), 0, "the last run's set pieces are gone")
	assert_null(_world.car, "and its car")
	next.start()
	assert_eq(pieces.get_child_count(), 1, "the new run's")
	assert_null((pieces.get_child(0) as SetPiece).car, "no car until main gives it one")
	_world.car = car
	assert_eq((pieces.get_child(0) as SetPiece).car, car)


func test_a_new_buffer_drops_the_last_runs_unfinished_set_piece() -> void:
	var schedule := Fixtures.set_piece_schedule(13, &"tunnel", 4)
	var last := RoadBuffer.new(RoadGenerator.new(3, schedule))
	_world.build(schedule)
	_world.bind(last)
	last.start()
	assert_eq(last.path_tile(Tuning.BUFFER_AHEAD).set_piece, &"tunnel", "a run is unfinished")
	_buffer = RoadBuffer.new(RoadGenerator.new(3, Fixtures.dense_schedule()))
	_world.bind(_buffer)
	_buffer.start()
	assert_eq(_world.get_node("%SetPieces").get_child_count(), 0, "no tunnel on the new road")


func test_a_set_piece_without_a_scene_is_an_error() -> void:
	var schedule := Fixtures.set_piece_schedule(1, &"ferris_wheel", 5)
	_world.build(schedule)
	assert_push_error("no scene for set piece ferris_wheel")
	_buffer = RoadBuffer.new(RoadGenerator.new(3, schedule))
	_world.bind(_buffer)
	_buffer.start()
	assert_eq(_buffer.path_tile(5).set_piece, &"ferris_wheel")
	assert_eq(_world.get_node("%SetPieces").get_child_count(), 0, "it draws only the road")


func test_a_set_piece_whose_scene_is_null_is_an_error() -> void:
	var scenes: Dictionary[StringName, PackedScene] = {&"ferris_wheel": null}
	_world.set_piece_scenes = scenes
	var schedule := Fixtures.set_piece_schedule(1, &"ferris_wheel", 5)
	_world.build(schedule)
	assert_push_error("no scene for set piece ferris_wheel")
	_buffer = RoadBuffer.new(RoadGenerator.new(3, schedule))
	_world.bind(_buffer)
	_buffer.start()
	assert_eq(_world.get_node("%SetPieces").get_child_count(), 0, "it draws only the road")


func test_a_set_piece_scene_whose_root_isnt_a_set_piece_is_an_error() -> void:
	var scene := PackedScene.new()
	var root := Node2D.new()
	assert_eq(scene.pack(root), OK)
	root.free()
	var scenes: Dictionary[StringName, PackedScene] = {&"ferris_wheel": scene}
	_world.set_piece_scenes = scenes
	var schedule := Fixtures.set_piece_schedule(1, &"ferris_wheel", 5)
	_world.build(schedule)
	_buffer = RoadBuffer.new(RoadGenerator.new(3, schedule))
	_world.bind(_buffer)
	_buffer.start()
	# It frees the node it made: run_tests.sh fails on a leak.
	assert_push_error("the scene for set piece ferris_wheel isn't a SetPiece")
	assert_eq(_world.get_node("%SetPieces").get_child_count(), 0, "it draws only the road")


func test_an_empty_set_piece_scene_is_an_error() -> void:
	var scenes: Dictionary[StringName, PackedScene] = {&"ferris_wheel": PackedScene.new()}
	_world.set_piece_scenes = scenes
	var schedule := Fixtures.set_piece_schedule(1, &"ferris_wheel", 5)
	_world.build(schedule)
	_buffer = RoadBuffer.new(RoadGenerator.new(3, schedule))
	_world.bind(_buffer)
	_buffer.start()
	# It has no root to instantiate, and so nothing to free.
	assert_push_error("the scene for set piece ferris_wheel isn't a SetPiece")
	assert_eq(_world.get_node("%SetPieces").get_child_count(), 0, "it draws only the road")
