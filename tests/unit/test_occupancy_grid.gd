extends GutTest


func _tile(cell: Vector2i) -> RoadTile:
	return RoadTile.new(cell, RoadTile.Type.STRAIGHT, Heading.N, 0b0101)


func test_claim_and_release() -> void:
	var grid := OccupancyGrid.new()
	var tile := _tile(Vector2i(2, -3))
	assert_true(grid.is_free(tile.cell))
	assert_true(grid.claim(tile))
	assert_false(grid.is_free(tile.cell))
	assert_eq(grid.get_tile(tile.cell), tile)
	assert_eq(grid.size(), 1)
	grid.release(tile)
	assert_true(grid.is_free(tile.cell))
	assert_null(grid.get_tile(tile.cell))
	assert_eq(grid.size(), 0)


func test_claiming_a_taken_cell_is_an_error() -> void:
	var grid := OccupancyGrid.new()
	var first := _tile(Vector2i(1, 1))
	var second := _tile(Vector2i(1, 1))
	grid.claim(first)
	assert_false(grid.claim(second))
	assert_push_error("already taken")
	assert_eq(grid.get_tile(first.cell), first, "the first tile keeps the cell")
	grid.release(second)
	assert_eq(grid.get_tile(first.cell), first, "only the owner can release a cell")
