extends GutTest


func test_left_right_opposite() -> void:
	assert_eq(Heading.left(Heading.N), Heading.W)
	assert_eq(Heading.right(Heading.N), Heading.E)
	assert_eq(Heading.left(Heading.W), Heading.S)
	assert_eq(Heading.right(Heading.W), Heading.N)
	for h: int in 4:
		assert_eq(Heading.opposite(Heading.opposite(h)), h)
		assert_eq(Heading.left(Heading.right(h)), h)
		assert_eq(Heading.VEC[Heading.opposite(h)], -Heading.VEC[h])


func test_turns_alternate_left_and_right_from_left() -> void:
	assert_eq(Heading.turn_for(0, Heading.N), Heading.W, "turn 0 is a left turn")
	assert_eq(Heading.turn_for(1, Heading.W), Heading.N, "turn 1 is a right turn")
	assert_eq(Heading.turn_for(2, Heading.N), Heading.W)
	assert_eq(Heading.turn_for(3, Heading.W), Heading.N)


func test_bits_and_steps() -> void:
	var all := 0
	for h: int in 4:
		all |= Heading.bit(h)
		assert_eq(Heading.from_vec(Heading.VEC[h]), h)
	assert_eq(all, Heading.ALL)
	assert_eq(Heading.from_vec(Vector2i(1, 1)), -1)
	assert_eq(Heading.VEC[Heading.N], Vector2i(0, -1))
	assert_eq(Heading.VEC[Heading.W], Vector2i(-1, 0))
