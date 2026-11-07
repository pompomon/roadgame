extends GutTest

const TOLERANCE := Vector2(1e-3, 1e-3)


func test_tile_to_world() -> void:
	assert_eq(Iso.tile_to_world(Vector2.ZERO), Vector2.ZERO)
	assert_eq(Iso.tile_to_world(Vector2(1, 0)), Vector2(64, 32))
	assert_eq(Iso.tile_to_world(Vector2(0, 1)), Vector2(-64, 32))
	assert_eq(Iso.tile_to_world(Vector2(Heading.VEC[Heading.N])), Vector2(64, -32), "N: up-right")
	assert_eq(Iso.tile_to_world(Vector2(Heading.VEC[Heading.W])), Vector2(-64, -32), "W: up-left")


func test_world_to_tile_inverts_tile_to_world() -> void:
	for p: Vector2 in [Vector2(0.5, 0.5), Vector2(-3.25, 7.0), Vector2(120.5, -480.75)]:
		assert_almost_eq(Iso.world_to_tile(Iso.tile_to_world(p)), p, TOLERANCE)


func _layer(size: Vector2i) -> TileMapLayer:
	var tile_set := TileSet.new()
	tile_set.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	tile_set.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	tile_set.tile_size = size
	var layer: TileMapLayer = autofree(TileMapLayer.new())
	layer.tile_set = tile_set
	return layer


func test_road_layer_cells_line_up_with_tile_space() -> void:
	var layer := _layer(Vector2i(Iso.TILE_W, Iso.TILE_H))
	# Godot 4.7 draws cell (0, 0) half a tile right of tile_to_world((0.5, 0.5)) = (0, 32).
	assert_eq(layer.map_to_local(Vector2i.ZERO), Vector2(64, 32))
	layer.position = Iso.layer_offset(layer, 1)
	assert_eq(layer.position, Vector2(-64, 0))
	for cell: Vector2i in [Vector2i.ZERO, Vector2i(3, -7), Vector2i(-40, -55)]:
		var drawn := layer.position + layer.map_to_local(cell)
		assert_almost_eq(drawn, Iso.tile_to_world(Iso.cell_centre(cell)), TOLERANCE, str(cell))


func test_ground_layer_cells_line_up_with_tile_space() -> void:
	var per := Iso.GROUND_PER_TILE
	var layer := _layer(Vector2i(Iso.TILE_W, Iso.TILE_H) / per)
	layer.position = Iso.layer_offset(layer, per)
	assert_eq(layer.position, Vector2(-16, 0))
	for cell: Vector2i in [Vector2i.ZERO, Vector2i(5, -2), Vector2i(-161, -220)]:
		var centre := (Vector2(cell) + Vector2(0.5, 0.5)) / per
		var drawn := layer.position + layer.map_to_local(cell)
		assert_almost_eq(drawn, Iso.tile_to_world(centre), TOLERANCE, str(cell))
