extends GutTest
## The car's sheet (plan.md §5.3, docs/M5.md §5.7): a frame for each of CarController's directions
## and the wreck, each whole within its frame, in a row for each phase of the wheels
## (VISUALS_PLAN.md §5.1). test_area_art.gd checks its colours.

const Art := preload("res://tests/helpers/art_checks.gd")
const CAR_SCENE := preload("res://car/car.tscn")


func _body() -> Sprite2D:
	var car: Node2D = autofree(CAR_SCENE.instantiate())
	return car.get_node("%Body")


func _frame(image: Image, f: int, phase := 0) -> Image:
	var size := CarController.FRAME_SIZE
	return image.get_region(Rect2i(Vector2i(f, phase) * size, size))


## The alpha of each pixel of `image`, row by row.
static func _silhouette(image: Image) -> PackedByteArray:
	var data := image.get_data()
	var alpha := PackedByteArray()
	for k: int in range(3, data.size(), 4):
		alpha.append(data[k])
	return alpha


func test_the_sheet_has_a_frame_for_each_direction_and_the_wreck() -> void:
	var body := _body()
	var frames := CarController.FRAMES + 1
	assert_eq(CarController.WRECK_FRAME, frames - 1, "the wreck is the last")
	assert_eq(body.hframes, frames)
	assert_eq(body.vframes, CarController.PHASES, "a row for each phase of the wheels")
	var size := CarController.FRAME_SIZE
	var sheet := size * Vector2i(frames, CarController.PHASES)
	assert_eq(Vector2i(body.texture.get_size()), sheet)
	assert_false(body.centered)
	assert_eq(body.offset, -Vector2(CarController.FOOT), "the foot at the car's position")


func test_each_frame_is_whole_and_stands_on_its_foot() -> void:
	var image := _body().texture.get_image()
	var size := CarController.FRAME_SIZE
	for phase: int in CarController.PHASES:
		for f: int in CarController.FRAMES + 1:
			var frame := _frame(image, f, phase)
			var what := "frame %d, phase %d" % [f, phase]
			var used := frame.get_used_rect()
			var inside := Rect2i(Vector2i.ONE, size - Vector2i(2, 2))
			assert_true(inside.encloses(used), "%s: %s clear of the edge" % [what, used])
			assert_gt(frame.get_pixelv(CarController.FOOT).a, 0.0, what + ": over its foot")


func test_every_frame_is_drawn_differently() -> void:
	var image := _body().texture.get_image()
	var seen: Dictionary[PackedByteArray, int] = {}
	for f: int in CarController.FRAMES + 1:
		var data := _frame(image, f).get_data()
		assert_false(seen.has(data), "frame %d is frame %d" % [f, seen.get(data, -1)])
		seen[data] = f


func test_each_phase_turns_the_wheels_in_the_same_outline() -> void:
	# The car's shadow casts the first row's frame (docs/DAYNIGHT.md §5.11), so every row keeps its
	# outline. On the straights, each phase shows; seen from ahead or behind, the wheels' faces are
	# edge on and show fewer. The wreck's wheels turn no more.
	var image := _body().texture.get_image()
	var straights: Array[int] = []
	for heading: Vector2 in [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]:
		straights.append(CarController.frame(heading))
	for f: int in CarController.FRAMES + 1:
		var outline := _silhouette(_frame(image, f))
		var drawn: Dictionary[PackedInt32Array, int] = {}
		for phase: int in CarController.PHASES:
			var frame := _frame(image, f, phase)
			assert_eq(_silhouette(frame), outline, "frame %d, phase %d: the outline" % [f, phase])
			drawn[Art.pixels(frame)] = phase
		if f == CarController.WRECK_FRAME:
			assert_eq(drawn.size(), 1, "the wreck's phases drawn alike")
		elif f in straights:
			assert_eq(drawn.size(), CarController.PHASES, "frame %d: phases drawn apart" % f)
		else:
			assert_gt(drawn.size(), 1, "frame %d: its wheels turn" % f)
