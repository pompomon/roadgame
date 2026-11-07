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
	_world.bind(_buffer, Fixtures.schedule())
	assert_eq(_wrong_cells(), 0, "tiles generated before bind()")
	for i: int in range(1, 400):
		_buffer.on_car_path_index(i)
	assert_gt(_buffer.first_index(), 300)
	assert_eq(_wrong_cells(), 0, "after refills and frees")


func test_debug_view_tints_dead_ends() -> void:
	_world.show_dead_ends = true
	_world.bind(_buffer, Fixtures.schedule())
	_buffer.start()
	var road: TileMapLayer = _world.get_node("%RoadLayer")
	var dead_ends := 0
	for tile: RoadTile in _buffer.tiles():
		if tile.type == RoadTile.Type.DEAD_END:
			dead_ends += 1
			assert_eq(road.get_cell_atlas_coords(tile.cell).y, GreyboxAtlas.Row.DEAD_END)
	assert_gt(dead_ends, 0)


func test_layers_line_up_with_tile_space() -> void:
	_world.bind(_buffer, Fixtures.schedule())
	_buffer.start()
	var road: TileMapLayer = _world.get_node("%RoadLayer")
	var ground: TileMapLayer = _world.get_node("%GroundLayer")
	var cell := _buffer.path_tile(30).cell
	var centre := Iso.tile_to_world(Iso.cell_centre(cell))
	assert_almost_eq(road.position + road.map_to_local(cell), centre, Vector2(1e-3, 1e-3))
	var g := cell * Iso.GROUND_PER_TILE
	var g_centre := Iso.tile_to_world((Vector2(g) + Vector2(0.5, 0.5)) / Iso.GROUND_PER_TILE)
	assert_almost_eq(ground.position + ground.map_to_local(g), g_centre, Vector2(1e-3, 1e-3))
