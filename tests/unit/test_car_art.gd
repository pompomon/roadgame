extends GutTest
## The car's sheet (plan.md §5.3, M5_PLAN.md §5.7): a frame for each of CarController's directions
## and the wreck, each whole within its frame. test_area_art.gd checks its colours.

const CAR_SCENE := preload("res://car/car.tscn")


func _body() -> Sprite2D:
	var car: Node2D = autofree(CAR_SCENE.instantiate())
	return car.get_node("%Body")


func _frame(image: Image, f: int) -> Image:
	var size := CarController.FRAME_SIZE
	return image.get_region(Rect2i(Vector2i(f * size.x, 0), size))


func test_the_sheet_has_a_frame_for_each_direction_and_the_wreck() -> void:
	var body := _body()
	var frames := CarController.FRAMES + 1
	assert_eq(CarController.WRECK_FRAME, frames - 1, "the wreck is the last")
	assert_eq(body.hframes, frames)
	assert_eq(body.vframes, 1)
	var size := CarController.FRAME_SIZE
	assert_eq(Vector2i(body.texture.get_size()), Vector2i(size.x * frames, size.y))
	assert_false(body.centered)
	assert_eq(body.offset, -Vector2(CarController.FOOT), "the foot at the car's position")


func test_each_frame_is_whole_and_stands_on_its_foot() -> void:
	var image := _body().texture.get_image()
	var size := CarController.FRAME_SIZE
	for f: int in CarController.FRAMES + 1:
		var frame := _frame(image, f)
		var used := frame.get_used_rect()
		var inside := Rect2i(Vector2i.ONE, size - Vector2i(2, 2))
		assert_true(inside.encloses(used), "frame %d: %s clear of the edge" % [f, used])
		assert_gt(frame.get_pixelv(CarController.FOOT).a, 0.0, "frame %d: over its foot" % f)


func test_every_frame_is_drawn_differently() -> void:
	var image := _body().texture.get_image()
	var seen: Dictionary[PackedByteArray, int] = {}
	for f: int in CarController.FRAMES + 1:
		var data := _frame(image, f).get_data()
		assert_false(seen.has(data), "frame %d is frame %d" % [f, seen.get(data, -1)])
		seen[data] = f
