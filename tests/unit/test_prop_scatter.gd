extends GutTest
## PropScatter (docs/M5.md §5.6, L2): each row of the path gets its props PROP_AHEAD path tiles
## before the car, and loses them with its path tile. The rows below the start get theirs at once.

const Fixtures := preload("res://tests/helpers/road_fixtures.gd")
const CAR_SCENE := preload("res://car/car.tscn")
const DELTA := 1.0 / 60.0
## Alphas are 32-bit floats.
const ROUNDING := 1e-5

var _layer: Node2D


func before_each() -> void:
	_layer = add_child_autofree(Node2D.new())


func _buffer(run_seed: int, schedule: AreaSchedule) -> RoadBuffer:
	return RoadBuffer.new(RoadGenerator.new(run_seed, schedule))


## The rows from `first` to `last`.
func _rows(first: int, last: int) -> Array[int]:
	var rows: Array[int] = []
	rows.assign(range(first, last + 1))
	return rows


## A prop of 8 × 8-pixel frames, side by side on a sheet of its own.
func _prop(id: StringName, frames: int, fps: float, density: float) -> PropDef:
	var def := PropDef.new()
	def.id = id
	var image := Image.create_empty(8 * frames, 8, false, Image.FORMAT_RGBA8)
	def.texture = ImageTexture.create_from_image(image)
	def.region = Rect2i(0, 0, 8, 8)
	def.frames = frames
	def.fps = fps
	def.foot = Vector2i(4, 8)
	def.density = density
	return def


## A prop with a building's frame, a box on a lot of 2 × 2 cells, on a sheet of its own:
## see-through, so that it may rise over the road behind it, unless `see_through` is false.
func _building(id: StringName, density: float, see_through: bool) -> PropDef:
	var def := PropDef.new()
	def.id = id
	var image := Image.create_empty(42, 58, false, Image.FORMAT_RGBA8)
	def.texture = ImageTexture.create_from_image(image)
	def.region = Rect2i(0, 0, 42, 58)
	def.foot = Vector2i(21, 57)
	def.density = density
	def.lot = 2
	def.shadow_rise = 10
	def.see_through = see_through
	return def


## The schedule of one area with `props`, which a test may change.
func _schedule(props: Array[PropDef]) -> AreaSchedule:
	var schedule := Fixtures.dense_schedule()
	schedule.entries[0].area.props = props
	return schedule


func _shown(scatter: PropScatter) -> int:
	var shown := 0
	for k: int in scatter.rows():
		shown += scatter.sprites(k).size()
	return shown


## Each row's props, as their sprites show them, but for their frame.
func _described(scatter: PropScatter) -> Array:
	var described := []
	for k: int in scatter.rows():
		var row := [k]
		for sprite: Sprite2D in scatter.sprites(k):
			row.append([sprite.texture, sprite.region_rect, sprite.hframes, sprite.position])
		described.append(row)
	return described


func test_the_rows_below_the_start_show_first_and_the_roads_rows_with_it() -> void:
	var schedule := Fixtures.schedule()
	var scatter := PropScatter.new(_layer, schedule)
	var buffer := _buffer(3, schedule)
	scatter.bind(buffer)
	assert_eq(scatter.rows(), _rows(-Tuning.BUFFER_BEHIND, -1 - PropLayout.rows_needed()))
	buffer.start()
	assert_eq(scatter.rows(), _rows(-Tuning.BUFFER_BEHIND, Tuning.PROP_AHEAD))
	assert_gt(_shown(scatter), 10 * scatter.rows().size(), "the city's props")
	assert_eq(scatter.pool.made, _shown(scatter))


func test_the_rows_below_the_start_show_the_area_the_road_starts_in() -> void:
	# The world scatters the whole schedule's props, and a run can start in any of its areas
	# (docs/ZONE_SELECT.md Z3): the rows below a Desert start, after a City run, show the Desert's
	# props, as a scatter of the Desert's schedule alone shows them.
	var schedule := Fixtures.schedule()
	var desert := schedule.starting_at(&"desert")
	var scatter := PropScatter.new(_layer, schedule)
	scatter.bind(_buffer(1, schedule))
	scatter.bind(_buffer(1, desert))
	var alone := PropScatter.new(add_child_autofree(Node2D.new()), desert)
	alone.bind(_buffer(1, desert))
	assert_gt(_shown(scatter), 0, "the desert's props")
	assert_eq(_described(scatter), _described(alone))


func test_rows_show_props_ahead_of_the_car_and_lose_them_with_their_path_tile() -> void:
	var schedule := Fixtures.schedule()
	var scatter := PropScatter.new(_layer, schedule)
	var buffer := _buffer(5, schedule)
	scatter.bind(buffer)
	buffer.start()
	var wrong := PackedStringArray()
	var most_shown := 0
	var largest_row := 0
	for index: int in range(1, 700):
		buffer.on_car_path_index(index)
		scatter.update(DELTA)
		# While the buffer has path tile 0, it has the rows below it too.
		var lowest := buffer.first_index()
		if lowest == 0:
			lowest = -Tuning.BUFFER_BEHIND
		if scatter.rows() != _rows(lowest, index + Tuning.PROP_AHEAD):
			wrong.append("car on %d: rows %s" % [index, scatter.rows()])
		most_shown = maxi(most_shown, _shown(scatter))
		for k: int in scatter.rows():
			largest_row = maxi(largest_row, scatter.sprites(k).size())
	assert_eq(wrong.slice(0, 3), PackedStringArray(), "%d steps wrong" % wrong.size())
	assert_gt(buffer.generator.turn_count, 44, "past the tunnel and the bridge")
	# A step shows a row before it hides one, so the pool needs one row more than ever shows.
	assert_lte(scatter.pool.made, most_shown + largest_row, "the sprites are reused")
	assert_eq(scatter.pool.hidden() + _shown(scatter), scatter.pool.made, "none lost")
	assert_eq(_layer.get_child_count(true), scatter.pool.made)
	assert_eq(_layer.get_child_count(), 0, "internal children, which simulate() walks past (A7)")


func test_the_layers_own_children_draw_over_the_props_on_their_y() -> void:
	# Godot y-sorts by y, then by the order of the layer's children, internal ones included
	# (servers/rendering/renderer_canvas_cull.h:117, ItemYSort). main.gd adds the car once the
	# first rows show, and the pool makes sprites after that: each still goes before the car, so
	# that the car draws over a prop on its y (docs/VISUALS.md A9).
	var schedule := Fixtures.schedule()
	var scatter := PropScatter.new(_layer, schedule)
	var buffer := _buffer(5, schedule)
	scatter.bind(buffer)
	buffer.start()
	var made_first := scatter.pool.made
	var car := Node2D.new()
	_layer.add_child(car)
	for index: int in range(1, 200):
		buffer.on_car_path_index(index)
		scatter.update(DELTA)
	assert_gt(made_first, 0, "sprites made before the car")
	assert_gt(scatter.pool.made, made_first, "and after it")
	assert_eq(car.get_index(true), scatter.pool.made, "each sprite before the car")


func test_a_seed_shows_the_same_props_however_the_car_got_there() -> void:
	var schedule := Fixtures.schedule()
	var stepped := PropScatter.new(_layer, schedule)
	var stepped_buffer := _buffer(9, schedule)
	stepped.bind(stepped_buffer)
	stepped_buffer.start()
	for index: int in range(1, 121):
		stepped_buffer.on_car_path_index(index)
		stepped.update(DELTA)
	var jumped := PropScatter.new(add_child_autofree(Node2D.new()), schedule)
	var jumped_buffer := _buffer(9, schedule)
	jumped.bind(jumped_buffer)
	jumped_buffer.start()
	jumped_buffer.on_car_path_index(120)
	jumped.update(1.0)
	assert_eq(jumped.rows(), stepped.rows())
	assert_eq(_described(jumped), _described(stepped))


func test_a_new_buffer_takes_the_sprites_of_the_last() -> void:
	var schedule := Fixtures.schedule()
	var scatter := PropScatter.new(_layer, schedule)
	var old := _buffer(1, schedule)
	scatter.bind(old)
	old.start()
	for index: int in range(1, 40):
		old.on_car_path_index(index)
		scatter.update(DELTA)
	var made := scatter.pool.made
	var fresh := _buffer(2, schedule)
	scatter.bind(fresh)
	var below_start := _rows(-Tuning.BUFFER_BEHIND, -1 - PropLayout.rows_needed())
	assert_eq(scatter.rows(), below_start)
	assert_eq(scatter.pool.made, made, "no new sprites")
	assert_eq(scatter.pool.hidden(), made - _shown(scatter), "the old rows' sprites are hidden")
	assert_eq(old.tiles_generated.get_connections().size(), 0)
	assert_eq(old.tiles_freed.get_connections().size(), 0)
	old.on_car_path_index(80)
	scatter.update(DELTA)
	assert_eq(scatter.rows(), below_start, "the old road changes nothing")
	fresh.start()
	assert_eq(scatter.rows(), _rows(-Tuning.BUFFER_BEHIND, Tuning.PROP_AHEAD))


func test_animated_props_step_through_their_frames_at_their_fps() -> void:
	var props: Array[PropDef] = [_prop(&"still", 1, 0.0, 0.05), _prop(&"turning", 4, 4.0, 0.1)]
	var schedule := _schedule(props)
	var scatter := PropScatter.new(_layer, schedule)
	var buffer := _buffer(1, schedule)
	scatter.bind(buffer)
	buffer.start()
	var turning: Array[Sprite2D] = []
	var still: Array[Sprite2D] = []
	for k: int in scatter.rows():
		for sprite: Sprite2D in scatter.sprites(k):
			if sprite.hframes == 4:
				turning.append(sprite)
			else:
				still.append(sprite)
	assert_gt(mini(turning.size(), still.size()), 20, "props of each")
	var first: Array[int] = []
	for sprite: Sprite2D in turning:
		first.append(sprite.frame)
	assert_eq(_distinct(first), 4, "each starts on a frame of its own")
	for step: int in range(1, 9):
		# A quarter of a second: a frame at 4 fps.
		scatter.update(0.25)
		var wrong := 0
		for i: int in turning.size():
			wrong += 0 if turning[i].frame == (first[i] + step) % 4 else 1
		for sprite: Sprite2D in still:
			wrong += 0 if sprite.frame == 0 else 1
		assert_eq(wrong, 0, "frames after %d steps" % step)


static func _distinct(values: Array[int]) -> int:
	var seen: Dictionary[int, bool] = {}
	for value: int in values:
		seen[value] = true
	return seen.size()


## Where each glow of `lamps` that shows is, sorted.
static func _glowing(lamps: Lamps) -> PackedStringArray:
	var glowing := PackedStringArray()
	for lit: Lamps.Lit in lamps.shown():
		for glow: Sprite2D in lit.sprite.get_children():
			glowing.append(str(lit.sprite.position + glow.position))
	glowing.sort()
	return glowing


## Where each silhouette of `lamps` that shows is, and its frame, sorted.
static func _silhouettes(lamps: Lamps) -> PackedStringArray:
	var silhouettes := PackedStringArray()
	for lit: Lamps.Lit in lamps.shown():
		silhouettes.append("%s %d" % [lit.sprite.position, lit.sprite.frame])
	silhouettes.sort()
	return silhouettes


func test_each_prop_lights_its_lamps_while_it_shows() -> void:
	# PropScatter adds a prop's silhouette as it shows the prop, shows it in the prop's frame, with
	# the prop's glows where its lights and its pools of light are, and takes them away with the
	# prop (docs/DAYNIGHT.md §5.12). A prop without lights has none. One that lies flat and has none
	# neither hides nor lights. As sparse as the props of the other tests, as it checks each one at
	# each step (C20).
	var lit := _prop(&"lit", 1, 0.0, 0.03)
	lit.lights.append(Rect2(-3, -7, 6, 4))
	lit.light_pools.append(Rect2(-8, -2, 16, 8))
	var flat := _prop(&"flat", 1, 0.0, 0.02)
	flat.shadow = PropDef.Shadow.NONE
	var props: Array[PropDef] = [lit, _prop(&"turning", 4, 4.0, 0.03), flat]
	var schedule := _schedule(props)
	var scatter := PropScatter.new(_layer, schedule)
	var lamps: Lamps = add_child_autofree(Lamps.new())
	scatter.lamps = lamps
	var buffer := _buffer(1, schedule)
	scatter.bind(buffer)
	buffer.start()
	var wrong := PackedStringArray()
	var lighting := 0
	var turning := 0
	for index: int in range(1, 120):
		buffer.on_car_path_index(index)
		scatter.update(0.1)
		var glows := PackedStringArray()
		var standing := PackedStringArray()
		for k: int in scatter.rows():
			for sprite: Sprite2D in scatter.sprites(k):
				if sprite.texture == lit.texture:
					glows.append(str(sprite.position + Vector2(0, -5)))
					glows.append(str(sprite.position + Vector2(0, 2)))
				if sprite.texture != flat.texture:
					standing.append("%s %d" % [sprite.position, sprite.frame])
				turning += int(sprite.frame > 0)
		glows.sort()
		standing.sort()
		if _glowing(lamps) != glows or _silhouettes(lamps) != standing:
			wrong.append("car on %d" % index)
		lighting = maxi(lighting, glows.size() >> 1)
	assert_gt(lighting, 20, "props that light")
	assert_gt(turning, 100, "frames past the first")
	assert_eq(wrong.slice(0, 3), PackedStringArray(), "%d steps wrong" % wrong.size())


func test_props_that_break_the_contract_are_errors_and_do_not_show() -> void:
	var good := _prop(&"good", 1, 0.0, 0.6)
	var blank := _prop(&"blank", 1, 0.0, 0.1)
	blank.texture = null
	# Copilot's review of #43: no frames fitted in any texture, and gave its sprites hframes = 0.
	var frameless := _prop(&"frameless", 1, 0.0, 0.1)
	frameless.frames = 0
	var crowding := _prop(&"crowding", 1, 0.0, 0.5)
	# A shadow that falls from the frame's top or below its foot, or that is no shape at all.
	var sunk := _prop(&"sunk", 1, 0.0, 0.1)
	sunk.shadow_rise = sunk.foot.y
	var shapeless := _prop(&"shapeless", 1, 0.0, 0.1)
	shapeless.set(&"shadow", PropDef.Shadow.size())
	# A lot that doesn't divide a tile, and one of 2 × 2 cells, whose densities add up apart
	# (docs/VISUALS.md §5.4).
	var odd := _prop(&"odd", 1, 0.0, 0.1)
	odd.lot = 3
	var block := _prop(&"block", 1, 0.0, 0.5)
	block.lot = 2
	# A street density outside 0..1, and one that takes a size's street densities past 1 though its
	# density doesn't (§5.8). A see-through prop that isn't a box, one whose box reaches out of its
	# lot, and one whose box just fits (§5.9).
	var streets := _prop(&"streets", 1, 0.0, 0.1)
	streets.street_density = 1.5
	var lining := _prop(&"lining", 1, 0.0, 0.0)
	lining.lot = 2
	lining.street_density = 0.6
	var wall := _prop(&"wall", 1, 0.0, 0.01)
	wall.see_through = true
	wall.shadow = PropDef.Shadow.WALL
	var deep := _prop(&"deep", 1, 0.0, 0.01)
	deep.see_through = true
	deep.shadow_rise = 5
	var fitting := _prop(&"fitting", 1, 0.0, 0.1)
	fitting.see_through = true
	fitting.shadow_rise = 4
	var props: Array[PropDef] = [
		good,
		null,
		blank,
		frameless,
		crowding,
		sunk,
		shapeless,
		odd,
		block,
		streets,
		lining,
		wall,
		deep,
		fitting
	]
	var schedule := _schedule(props)
	var scatter := PropScatter.new(_layer, schedule)
	assert_push_error("PropScatter: dense: a prop is null")
	assert_push_error("PropScatter: dense: prop blank has no texture")
	assert_push_error("PropScatter: dense: prop frameless has 0 frames")
	assert_push_error("PropScatter: dense: prop crowding takes the densities past 1")
	assert_push_error("PropScatter: dense: prop sunk: its shadow rises outside its frame")
	assert_push_error("PropScatter: dense: prop shapeless: its shadow is 3")
	assert_push_error("PropScatter: dense: prop odd: a lot of 3 cells doesn't divide a tile")
	assert_push_error("PropScatter: dense: prop streets: street_density is outside 0..1")
	assert_push_error("PropScatter: dense: prop lining takes the densities past 1")
	assert_push_error("PropScatter: dense: prop wall is see-through, but not a box on its lot")
	assert_push_error("PropScatter: dense: prop deep is see-through, but not a box on its lot")
	var buffer := _buffer(1, schedule)
	scatter.bind(buffer)
	buffer.start()
	var shown: Dictionary[Texture2D, int] = {good.texture: 0, block.texture: 0, fitting.texture: 0}
	var others := 0
	for k: int in scatter.rows():
		for sprite: Sprite2D in scatter.sprites(k):
			if shown.has(sprite.texture):
				shown[sprite.texture] += 1
			else:
				others += 1
	assert_gt(shown[good.texture], 100, "the good prop shows")
	assert_gt(shown[block.texture], 20, "the block shows")
	assert_gt(shown[fitting.texture], 20, "the box that fits shows")
	assert_eq(others, 0, "and no other")


## The code review of VIS PR 2: a Vector2's 32 bits took ten densities of 0.1 past 1, so the tenth
## prop of a size, inside or by a street, was an error and didn't show. And its second: floats add
## 0.33, 0.56 and 0.11 up to 1.0000000000000002, which took the third past 1 as well.
func test_densities_that_add_up_to_1_are_valid() -> void:
	var props: Array[PropDef] = []
	for k: int in 10:
		props.append(_prop(StringName("single%d" % k), 1, 0.0, 0.1))
		var lining := _prop(StringName("lining%d" % k), 1, 0.0, 0.0)
		lining.lot = 2
		lining.street_density = 0.1
		props.append(lining)
	var schedule := _schedule(props)
	var scatter := PropScatter.new(_layer, schedule)
	# In an area of their own: densities that add up to 1 leave no cell to a smaller lot.
	var thirds: Array[PropDef] = []
	var shares: Array[float] = [0.33, 0.56, 0.11]
	for k: int in shares.size():
		thirds.append(_prop(StringName("third%d" % k), 1, 0.0, shares[k]))
	var rounded := _schedule(thirds)
	var rounding := PropScatter.new(_layer, rounded)
	assert_push_error_count(0, "no prop takes the densities past 1")
	assert_gt(_times_shown(scatter, schedule, props[18]), 20, "the tenth single shows")
	assert_gt(_times_shown(rounding, rounded, thirds[2]), 20, "the third shows")


## How many times `def` shows once `scatter` is bound to a buffer of `schedule`.
func _times_shown(scatter: PropScatter, schedule: AreaSchedule, def: PropDef) -> int:
	var buffer := _buffer(1, schedule)
	scatter.bind(buffer)
	buffer.start()
	var shown := 0
	for k: int in scatter.rows():
		for sprite: Sprite2D in scatter.sprites(k):
			shown += int(sprite.texture == def.texture)
	return shown


func test_the_props_take_nothing_from_the_road() -> void:
	var schedule := Fixtures.schedule()
	var plain := _buffer(6, schedule)
	plain.start()
	var scattered := _buffer(6, schedule)
	var scatter := PropScatter.new(_layer, schedule)
	scatter.bind(scattered)
	scattered.start()
	for index: int in range(1, 150):
		plain.on_car_path_index(index)
		scattered.on_car_path_index(index)
		scatter.update(DELTA)
	var expected := []
	for tile: RoadTile in plain.tiles():
		expected.append(Fixtures.signature(tile))
	var found := []
	for tile: RoadTile in scattered.tiles():
		found.append(Fixtures.signature(tile))
	assert_eq(found, expected)
	assert_eq(scattered.generator.turn_count, plain.generator.turn_count)


## Each prop's shadow, and each prop that casts one, as where its shadow falls from and its frame.
static func _falls(sprites: Array[Sprite2D]) -> PackedStringArray:
	var falls := PackedStringArray()
	for sprite: Sprite2D in sprites:
		if sprite.visible:
			falls.append("%s %d" % [sprite.transform.origin, sprite.frame])
	falls.sort()
	return falls


func test_each_prop_casts_its_shadow_while_it_shows_in_its_frame() -> void:
	# PropScatter lays a prop's shadow as it shows the prop, shows it in the prop's frame, and takes
	# it away with the prop (docs/DAYNIGHT.md §5.11). A flat prop casts none. As sparse as the props
	# of the other tests, as it checks each one at each step (C20).
	var flat := _prop(&"flat", 1, 0.0, 0.02)
	flat.shadow = PropDef.Shadow.NONE
	var props: Array[PropDef] = [_prop(&"turning", 4, 4.0, 0.03), flat]
	var schedule := _schedule(props)
	var scatter := PropScatter.new(_layer, schedule)
	var shadows: Shadows = add_child_autofree(Shadows.new())
	scatter.shadows = shadows
	var buffer := _buffer(1, schedule)
	scatter.bind(buffer)
	buffer.start()
	var wrong := PackedStringArray()
	var casting := 0
	for index: int in range(1, 120):
		buffer.on_car_path_index(index)
		scatter.update(0.1)
		var turning: Array[Sprite2D] = []
		for k: int in scatter.rows():
			for sprite: Sprite2D in scatter.sprites(k):
				if sprite.hframes == 4:
					turning.append(sprite)
		var casts: Array[Sprite2D] = []
		casts.assign(shadows.get_children(true))
		if _falls(casts) != _falls(turning) or shadows.count() != turning.size():
			wrong.append("car on %d" % index)
		casting = maxi(casting, turning.size())
	assert_gt(casting, 20, "props that cast")
	assert_eq(wrong.slice(0, 3), PackedStringArray(), "%d steps wrong" % wrong.size())


## `count` sprites of `texture` that `scatter` shows, each 400 pixels or more from `from` and from
## each other.
static func _apart(
	scatter: PropScatter, texture: Texture2D, from: Vector2, count: int
) -> Array[Sprite2D]:
	var picked: Array[Sprite2D] = []
	var taken: Array[Vector2] = [from]
	for k: int in scatter.rows():
		for sprite: Sprite2D in scatter.sprites(k):
			var far := sprite.texture == texture and picked.size() < count
			for at: Vector2 in taken:
				far = far and sprite.position.distance_to(at) >= 400.0
			if far:
				picked.append(sprite)
				taken.append(sprite.position)
	return picked


func test_see_through_props_fade_where_they_would_hide_the_car_or_a_legends_sprite() -> void:
	# A see-through prop shows as much of itself as SeeThrough.opacity() gives for the actor on the
	# layer that it would hide most: the car's body, or a sprite that a legend stood there, such as
	# the car's double (docs/VISUALS.md §5.9). Its silhouette, with its glows, fades with it. Other
	# props, and sprites that don't show, fade nothing, and each prop comes back whole as the actors
	# go.
	var building := _building(&"building", 0.5, true)
	var props: Array[PropDef] = [building, _building(&"plain", 0.5, false)]
	var schedule := _schedule(props)
	var scatter := PropScatter.new(_layer, schedule)
	var lamps: Lamps = add_child_autofree(Lamps.new())
	scatter.lamps = lamps
	var buffer := _buffer(1, schedule)
	scatter.bind(buffer)
	buffer.start()
	var car: CarController = CAR_SCENE.instantiate()
	car.sim = CarSim.new(buffer)
	car.input = InputRouter.new()
	_layer.add_child(car)
	car.add_child(car.input)
	# On the road, where the buildings beside it rise over it.
	car.position = Iso.tile_to_world(Vector2(buffer.path_tile(4).cell) + Vector2.ONE * 0.5)
	# The car's double up the screen behind a building, and three sprites that don't show behind
	# others: two hidden as a legend's part waits, by their alpha and by their scale, which Node2D
	# stores as CMP_EPSILON, and one not visible.
	var targets := _apart(scatter, building.texture, car.position, 4)
	assert_eq(targets.size(), 4, "buildings away from the car")
	var stand_in := car.double()
	var waiting := car.double()
	waiting.modulate.a = 0.0
	var shrunk := car.double()
	shrunk.scale = Vector2.ZERO
	var unseen := car.double()
	unseen.visible = false
	var sprites: Array[Sprite2D] = [stand_in, waiting, shrunk, unseen]
	for i: int in sprites.size():
		_layer.add_child(sprites[i])
		sprites[i].position = targets[i].position + Vector2(0, -30)
	scatter.update(DELTA)
	var actors: Array[Rect2] = [car.body_rect(), stand_in.get_transform() * stand_in.get_rect()]
	var sorts: Array[float] = [car.position.y, stand_in.position.y]
	var wrong := PackedStringArray()
	var faded := 0
	var plain_near := 0
	for k: int in scatter.rows():
		for sprite: Sprite2D in scatter.sprites(k):
			var frame := Rect2(sprite.position - Vector2(21, 57), Vector2(42, 58))
			var expected := 1.0
			for i: int in actors.size():
				var alpha := SeeThrough.opacity(frame, sprite.position.y, actors[i], sorts[i])
				expected = minf(expected, alpha)
			if sprite.texture != building.texture:
				plain_near += int(expected < 1.0)
				expected = 1.0
			faded += int(sprite.modulate.a < 1.0)
			if absf(sprite.modulate.a - expected) > ROUNDING:
				wrong.append("%s: %.3f, not %.3f" % [sprite.position, sprite.modulate.a, expected])
	assert_eq(wrong.slice(0, 3), PackedStringArray(), "%d props wrong" % wrong.size())
	assert_almost_eq(targets[0].modulate.a, Tuning.PROP_SEE_THROUGH, ROUNDING, "over the double")
	var hidden := [targets[1].modulate.a, targets[2].modulate.a, targets[3].modulate.a]
	assert_eq(hidden, [1.0, 1.0, 1.0], "the hidden fade none")
	assert_gt(faded, 2, "buildings by the car and the double")
	assert_gt(plain_near, 2, "and plain props, which don't fade")
	assert_eq(_unlike(lamps), 0, "each silhouette shows as much of itself as its prop")
	car.position = Vector2(1e5, 1e5)
	stand_in.free()
	scatter.update(DELTA)
	var whole := 0
	for k: int in scatter.rows():
		for sprite: Sprite2D in scatter.sprites(k):
			whole += int(sprite.modulate.a == 1.0)
	assert_eq(whole, _shown(scatter), "whole again once the actors go")
	assert_eq(_unlike(lamps), 0, "and their silhouettes")


## How many silhouettes of `lamps` show another alpha than their props.
static func _unlike(lamps: Lamps) -> int:
	var unlike := 0
	for lit: Lamps.Lit in lamps.shown():
		unlike += int(lit.sprite.modulate.a != lit.prop.modulate.a)
	return unlike


## How many props of `scatter`'s rows stand on the sea past `pier`'s shore (Pier.at_sea()).
static func _on_the_sea(scatter: PropScatter, pier: RoadTile) -> int:
	var on_the_sea := 0
	for k: int in scatter.rows():
		for sprite: Sprite2D in scatter.sprites(k):
			var cell := Vector2i(Iso.world_to_tile(sprite.position).floor())
			on_the_sea += int(Pier.at_sea(cell, pier))
	return on_the_sea


## docs/ENDGAME.md §5.8: no prop stands on the sea, past the shore where the pier begins. On a
## short road, a row that reaches the sea can show before the pier is made: it loses those props
## then, and their sprites go back to the pool. Roads that end heading N and W, and one whose rows
## all show after its pier is made.
func test_no_prop_stands_on_the_sea() -> void:
	var scatter := PropScatter.new(_layer, Fixtures.schedule())
	for road: Array in [[12, 5, true], [11, 8, true], [12, 2, false]]:
		var schedule := Fixtures.schedule().ending_at(road[0], &"pier")
		var ahead := RoadGenerator.new(road[1], schedule)
		var pier := ahead.next_tile()
		while not ahead.finished():
			pier = ahead.next_tile()
		var buffer := _buffer(road[1], schedule)
		scatter.bind(buffer)
		buffer.start()
		var early := 0
		var wrong := PackedStringArray()
		for index: int in range(1, pier.path_index + 30):
			var on_the_sea := _on_the_sea(scatter, pier)
			if not buffer.generator.finished():
				early = maxi(early, on_the_sea)
			elif on_the_sea > 0:
				wrong.append("car on %d: %d" % [buffer.car_index(), on_the_sea])
			buffer.on_car_path_index(index)
			scatter.update(DELTA)
		var road_name := "%d turns, seed %d, heading %d" % [road[0], road[1], pier.heading]
		assert_eq(early > 0, road[2], "%s: props on the sea before the pier is made" % road_name)
		assert_eq(
			wrong.slice(0, 3), PackedStringArray(), "%s: %d steps wrong" % [road_name, wrong.size()]
		)
		assert_eq(
			scatter.pool.hidden() + _shown(scatter), scatter.pool.made, "%s: none lost" % road_name
		)
	assert_eq(_layer.get_child_count(true), scatter.pool.made)
