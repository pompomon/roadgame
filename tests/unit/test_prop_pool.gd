extends GutTest
## PropPool (IMPLEMENTATION_PLAN.md M5.2, docs/M5.md §5.6): a hidden sprite shows the next prop, so
## that a run makes nodes only while it warms up.

var _layer: Node2D
var _pool: PropPool


func before_each() -> void:
	_layer = add_child_autofree(Node2D.new())
	_pool = PropPool.new(_layer)


func _prop(id: StringName, frames: int, region: Rect2i, foot: Vector2i) -> PropDef:
	var image := Image.create_empty(64, 64, false, Image.FORMAT_RGBA8)
	var def := PropDef.new()
	def.id = id
	def.texture = ImageTexture.create_from_image(image)
	def.region = region
	def.frames = frames
	def.fps = 2.0 if frames > 1 else 0.0
	def.foot = foot
	return def


func test_a_sprite_shows_the_props_first_frame_with_its_foot_on_its_position() -> void:
	var def := _prop(&"mill", 3, Rect2i(4, 8, 10, 20), Vector2i(5, 18))
	var sprite := _pool.acquire(def)
	assert_eq(sprite.get_parent(), _layer)
	assert_true(sprite.visible)
	assert_eq(sprite.texture, def.texture)
	assert_true(sprite.region_enabled)
	assert_eq(sprite.region_rect, Rect2(4, 8, 30, 20), "the strip of all its frames")
	assert_eq(sprite.hframes, 3)
	assert_eq(sprite.frame, 0)
	assert_false(sprite.centered)
	sprite.position = Vector2(100, 50)
	assert_eq(sprite.get_rect(), Rect2(-5, -18, 10, 20), "its frame, around its foot")
	assert_eq(_pool.made, 1)


func test_a_released_sprite_shows_the_next_prop() -> void:
	var mill := _prop(&"mill", 4, Rect2i(0, 0, 8, 8), Vector2i(4, 8))
	var rock := _prop(&"rock", 1, Rect2i(40, 0, 12, 6), Vector2i(6, 5))
	var sprite := _pool.acquire(mill)
	sprite.frame = 3
	_pool.release(sprite)
	assert_false(sprite.visible)
	assert_eq(_pool.hidden(), 1)
	var again := _pool.acquire(rock)
	assert_same(again, sprite, "the same sprite")
	assert_true(again.visible)
	assert_eq([again.hframes, again.frame], [1, 0], "the last prop's frame is gone")
	assert_eq(again.region_rect, Rect2(40, 0, 12, 6))
	assert_eq(again.offset, Vector2(-6, -5))
	assert_eq([_pool.made, _pool.hidden()], [1, 0])


func test_a_thousand_rows_make_no_more_sprites_than_a_row_shows() -> void:
	var defs: Array[PropDef] = [
		_prop(&"a", 1, Rect2i(0, 0, 8, 8), Vector2i(4, 8)),
		_prop(&"b", 3, Rect2i(8, 0, 8, 8), Vector2i(4, 8)),
	]
	var nodes := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var shown: Array[Sprite2D] = []
	for row: int in 1000:
		for k: int in 20 + row % 7:
			shown.append(_pool.acquire(defs[(row + k) % 2]))
		for sprite: Sprite2D in shown:
			_pool.release(sprite)
		shown.clear()
	assert_eq(_pool.made, 26, "the most a row showed")
	assert_eq(_pool.hidden(), 26)
	assert_eq(_layer.get_child_count(), 26)
	assert_eq(Performance.get_monitor(Performance.OBJECT_NODE_COUNT), nodes + 26)
