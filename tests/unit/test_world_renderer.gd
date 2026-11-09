extends GutTest

const Fixtures := preload("res://tests/helpers/road_fixtures.gd")

var _world: WorldRenderer
var _buffer: RoadBuffer


func before_each() -> void:
	var scene: PackedScene = load("res://world/world.tscn")
	_world = add_child_autofree(scene.instantiate())
	_buffer = RoadBuffer.new(RoadGenerator.new(11, Fixtures.schedule()))


## Counts the buffered tiles drawn wrongly on the road and ground layers.
func _wrong_cells() -> int:
	var road: TileMapLayer = _world.get_node("%RoadLayer")
	var ground: TileMapLayer = _world.get_node("%GroundLayer")
	var tiles := _buffer.tiles()
	var wrong := absi(road.get_used_cells().size() - tiles.size())
	wrong += absi(ground.get_used_cells().size() - tiles.size() * Iso.GROUND_PER_TILE ** 2)
	for tile: RoadTile in tiles:
		if road.get_cell_atlas_coords(tile.cell) != GreyboxAtlas.road_coords(tile, false):
			wrong += 1
		if ground.get_cell_source_id(tile.cell * Iso.GROUND_PER_TILE) != 0:
			wrong += 1
	return wrong


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
	for i: int in range(40, 100):
		last.on_car_path_index(i)
	assert_eq(_wrong_cells(), 0, "the last buffer's refills and frees change nothing")
	for i: int in range(1, 100):
		_buffer.on_car_path_index(i)
	assert_eq(_wrong_cells(), 0, "the new buffer's do")


func test_the_first_tiles_of_an_area_blend_its_ground_with_the_last_one() -> void:
	# plan.md §5.3 and IMPLEMENTATION_PLAN.md M4.3: the first TRANSITION_TILES path tiles of an area
	# show both areas' colours in a checker; every other tile, dead ends too, its own area's shades.
	var schedule := Fixtures.schedule()
	_world.build(schedule)
	_world.bind(_buffer)
	_buffer.start()
	var colors: Dictionary[StringName, Color] = {}
	for entry: AreaScheduleEntry in schedule.entries:
		colors[entry.area.id] = entry.area.id_color
	var ground: TileMapLayer = _world.get_node("%GroundLayer")
	var source: TileSetAtlasSource = ground.tile_set.get_source(0)
	var image := source.texture.get_image()
	var size := ground.tile_set.tile_size
	@warning_ignore("integer_division")
	var middle := size / 2
	var last_area := &"city"
	var in_area := 0
	var blended: Array[StringName] = []
	var index := 0
	while last_area != &"desert" or in_area < Tuning.TRANSITION_TILES + 1:
		index += 1
		_buffer.on_car_path_index(index)
		var tile := _buffer.path_tile(index)
		var from := last_area
		in_area = in_area + 1 if tile.area_id == last_area else 1
		last_area = tile.area_id
		var blend := in_area <= Tuning.TRANSITION_TILES and index > in_area
		if blend:
			from = _buffer.path_tile(index - in_area).area_id
			blended.append(tile.area_id)
		for each: RoadTile in [tile] + tile.branches:
			for cell: Vector2i in WorldRenderer._ground_cells(each.cell):
				# The checker's row from the cell's parity, not from the layer, which may have none.
				var row := posmod(cell.x + cell.y, 2)
				var want := colors[each.area_id].darkened(GreyboxAtlas.GROUND_SHADE * row)
				if blend and each == tile:
					want = colors[from] if row == 0 else colors[tile.area_id]
				var got := image.get_pixelv(ground.get_cell_atlas_coords(cell) * size + middle)
				if not _near(got, want):
					fail_test("path index %d, %s: %s, not %s" % [index, each.cell, got, want])
					return
	var expected: Array[StringName] = []
	for id: StringName in [&"rural", &"meadows", &"village", &"desert"]:
		for k: int in Tuning.TRANSITION_TILES:
			expected.append(id)
	assert_eq(blended, expected, "TRANSITION_TILES tiles at each change of area")


static func _near(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) + absf(a.a - b.a) < 0.02


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
	var ground: TileMapLayer = _world.get_node("%GroundLayer")
	var cell := _buffer.path_tile(30).cell
	var centre := Iso.tile_to_world(Iso.cell_centre(cell))
	assert_almost_eq(road.position + road.map_to_local(cell), centre, Vector2(1e-3, 1e-3))
	var g := cell * Iso.GROUND_PER_TILE
	var g_centre := Iso.tile_to_world((Vector2(g) + Vector2(0.5, 0.5)) / Iso.GROUND_PER_TILE)
	assert_almost_eq(ground.position + ground.map_to_local(g), g_centre, Vector2(1e-3, 1e-3))


func test_disasters_draw_above_the_road_and_below_the_car() -> void:
	# World draws its children in order, and only Props sorts by y (M3_PLAN.md J5).
	var names: Array[StringName] = []
	for node: Node in _world.get_children():
		names.append(node.name)
	var order: Array[StringName] = [
		&"GroundLayer", &"SetPieces", &"RoadLayer", &"DisasterLayer", &"Props"
	]
	assert_eq(names, order)
	var layer: Node2D = _world.get_node("%DisasterLayer")
	assert_false(layer.y_sort_enabled)
	assert_eq(layer.z_index, 0)


func test_set_pieces_draw_above_the_ground_and_below_the_road() -> void:
	# A river runs under the road; what must cover the car sets its own z_index (M4.4).
	var layer: Node2D = _world.get_node("%SetPieces")
	assert_eq(layer.get_index(), _world.get_node("%GroundLayer").get_index() + 1)
	assert_false(layer.y_sort_enabled)
	assert_eq(layer.z_index, 0)
	assert_eq(_world.set_piece_scenes.keys(), [&"bridge", &"tunnel"])


func test_a_set_piece_comes_once_its_run_is_made_and_goes_with_its_last_tile() -> void:
	# Junction 11 is path tile 48, so the tunnel's run is tiles 49 to 52, and the buffer's first
	# batch ends at tile 50 (BUFFER_AHEAD): the run comes in two batches.
	var schedule := Fixtures.set_piece_schedule(12, &"tunnel", 4)
	_buffer = RoadBuffer.new(RoadGenerator.new(3, schedule))
	_world.build(schedule)
	_world.bind(_buffer)
	var car: Node2D = add_child_autofree(Node2D.new())
	_world.car = car
	_buffer.start()
	var pieces: Node2D = _world.get_node("%SetPieces")
	assert_eq(_buffer.last_index(), Tuning.BUFFER_AHEAD)
	assert_eq(_buffer.path_tile(49).set_piece, &"tunnel", "the run has begun")
	assert_eq(pieces.get_child_count(), 0, "but the buffer hasn't made all of it")
	_buffer.on_car_path_index(Tuning.BUFFER_AHEAD - Tuning.BUFFER_REFILL_AT + 1)
	assert_eq(pieces.get_child_count(), 1, "now it has")
	var tunnel := pieces.get_child(0) as Tunnel
	assert_eq(tunnel.car, car, "it follows the run's car")
	var cells := Rect2(_buffer.path_tile(49).cell, Vector2.ONE)
	assert_eq(tunnel.rect, cells.merge(Rect2(_buffer.path_tile(52).cell, Vector2.ONE)))
	assert_eq(_buffer.path_tile(53).set_piece, &"", "the run ends at 52")
	_buffer.on_car_path_index(52 + Tuning.BUFFER_BEHIND)
	assert_eq(_buffer.first_index(), 52, "its first tiles are gone")
	assert_eq(pieces.get_child_count(), 1, "but not its last")
	_buffer.on_car_path_index(53 + Tuning.BUFFER_BEHIND)
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
	var schedule := Fixtures.set_piece_schedule(12, &"tunnel", 4)
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
