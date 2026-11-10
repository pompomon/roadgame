extends GutTest
## PropLayout (M5_PLAN.md §5.6): where each row's props stand. The brute-force tests place each row
## as PropScatter does, once the road has rows_needed() path tiles past the row's, and check the
## props against the whole road made by the end, with geometry of their own.

const Fixtures := preload("res://tests/helpers/road_fixtures.gd")
## Rows placed on each road.
const ROWS := 100
## Path tiles made past the last row's needs, which its props must keep clear of too.
const EXTRA_TILES := 10
## Screen rows either side of a prop's own to look for road in: more than a frame can reach.
const ROW_WINDOW := 8


## A road, and the props of its first ROWS rows, by row.
class Road:
	extends RefCounted
	var buffer: RoadBuffer
	var path: Array[RoadTile] = []
	var rows: Dictionary[int, Array] = {}


func _prop(id: StringName, size: Vector2i, foot: Vector2i, density: float) -> PropDef:
	var def := PropDef.new()
	def.id = id
	var image := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	def.texture = ImageTexture.create_from_image(image)
	def.region = Rect2i(Vector2i.ZERO, size)
	def.foot = foot
	def.density = density
	return def


## The largest frames the contract allows: as wide and tall as PROP_MAX_SIZE and PROP_BELOW let a
## frame be, and as wide but low.
func _largest() -> Array[PropDef]:
	var size := Tuning.PROP_MAX_SIZE + Vector2i(0, Tuning.PROP_BELOW)
	@warning_ignore("integer_division")
	var half := Tuning.PROP_MAX_SIZE.x / 2
	return [
		_prop(&"tall", size, Vector2i(half, Tuning.PROP_MAX_SIZE.y), 0.1),
		_prop(&"low", Vector2i(Tuning.PROP_MAX_SIZE.x, 12), Vector2i(half, 6), 0.05),
	]


## The road of `schedule` from `run_seed`, with its rows placed from `props`.
func _road(schedule: AreaSchedule, run_seed: int, props: Array[PropDef]) -> Road:
	var road := Road.new()
	road.buffer = RoadBuffer.new(RoadGenerator.new(run_seed, schedule))
	var props_seed := road.buffer.generator.props_seed
	for k: int in ROWS:
		_extend(road, k + PropLayout.rows_needed())
		road.rows[k] = PropLayout.row(road.path[k].cell, props, props_seed, road.buffer)
	_extend(road, ROWS + PropLayout.rows_needed() + EXTRA_TILES)
	return road


## Makes the path tiles of `road` up to `last`. The generator claims them, and their branches, in
## its occupancy grid, where the buffer finds them.
func _extend(road: Road, last: int) -> void:
	while road.path.size() <= last:
		road.path.append(road.buffer.generator.next_tile())


## Every tile of `road`, path and branch, by screen row: the sum of its cell's coordinates.
func _tiles_by_row(road: Road) -> Dictionary[int, Array]:
	var by_row: Dictionary[int, Array] = {}
	for tile: RoadTile in road.path:
		for any: RoadTile in [tile] + tile.branches:
			var row := any.cell.x + any.cell.y
			if not by_row.has(row):
				by_row[row] = []
			by_row[row].append(any)
	return by_row


static func _frame(placement: PropLayout.Placement) -> Rect2:
	return Rect2(placement.foot - Vector2(placement.def.foot), Vector2(placement.def.region.size))


static func _foot_cell(placement: PropLayout.Placement) -> Vector2i:
	return Vector2i(Iso.world_to_tile(placement.foot).floor())


## Whether `rect` reaches inside the diamond of the tile on `cell`: its point nearest the diamond's
## centre does.
static func _in_diamond(rect: Rect2, cell: Vector2i) -> bool:
	var centre := Iso.tile_to_world(Iso.cell_centre(cell))
	var gap := (centre.clamp(rect.position, rect.end) - centre).abs()
	return gap.x / (Iso.TILE_W * 0.5) + gap.y / (Iso.TILE_H * 0.5) < 1.0


## What the props of `road` that break the rules do, against all of its road. Also counts them
## all in `counted[0]`.
func _road_problems(road: Road, counted: Array[int]) -> PackedStringArray:
	var problems := PackedStringArray()
	var by_row := _tiles_by_row(road)
	for k: int in road.rows:
		for placement: PropLayout.Placement in road.rows[k]:
			counted[0] += 1
			var rect := _frame(placement)
			var cell := _foot_cell(placement)
			var own := cell.x + cell.y
			for row: int in range(own - ROW_WINDOW, own + ROW_WINDOW + 1):
				for tile: RoadTile in by_row.get(row, []):
					if _in_diamond(rect, tile.cell):
						problems.append(
							"row %d: %s at %s on %s" % [k, placement.def.id, rect, tile.cell]
						)
	return problems


func test_the_largest_props_keep_off_the_road_made_before_and_after_their_row() -> void:
	for def: PropDef in _largest():
		assert_eq(def.validate(), PackedStringArray(), "%s keeps the contract" % def.id)
	var counted: Array[int] = [0]
	var problems := PackedStringArray()
	for schedule: AreaSchedule in [Fixtures.schedule(), Fixtures.dense_schedule()]:
		for run_seed: int in [1, 2, 3]:
			problems.append_array(_road_problems(_road(schedule, run_seed, _largest()), counted))
	assert_eq(problems.slice(0, 5), PackedStringArray(), "%d props on the road" % problems.size())
	assert_gt(counted[0], 10000, "enough props to tell")


## The tallest frame, on the highest foot of row 0, reaches the diamonds of the rows_above() rows
## above it, and no higher.
func test_rows_above_counts_the_rows_the_tallest_frame_reaches() -> void:
	var tall := _largest()[0]
	var foot := PropLayout.ground_centre(Vector2i.ZERO)
	assert_eq(foot.y, PropLayout.TOP_FOOT, "the highest foot of a row")
	var highest := 0
	for up: int in range(1, 8):
		var buffer := RoadBuffer.new(RoadGenerator.new(1, Fixtures.schedule()))
		for j: int in range(-6, 7):
			var cell := Vector2i(j, -up - j)
			buffer.generator.occupancy.claim(
				RoadTile.new(cell, RoadTile.Type.STRAIGHT, Heading.N, 0)
			)
		if PropLayout.touches_road(tall, foot, buffer):
			highest = up
	assert_eq(highest, PropLayout.rows_above())


## A run of set pieces after every turn, bridges and tunnels in turn, on the dense area.
func _set_piece_schedule(turns: int) -> AreaSchedule:
	var built := Fixtures.dense_schedule()
	for turn: int in range(1, turns + 1):
		var entry := AreaScheduleEntry.new()
		entry.turn = turn
		entry.area = built.entries[0].area
		entry.set_piece = &"bridge" if turn % 2 == 1 else &"tunnel"
		entry.set_piece_length = 2 + turn % 5
		built.entries.append(entry)
	return built


## The runs of set-piece path tiles of `road`.
func _runs(road: Road) -> Array[Array]:
	var runs: Array[Array] = []
	var run: Array[RoadTile] = []
	for tile: RoadTile in road.path:
		if not run.is_empty() and tile.set_piece != run[0].set_piece:
			runs.append(run)
			run = []
		if tile.set_piece != &"":
			run.append(tile)
	return runs


## What a set piece on `run` draws that a prop mustn't stand on or show over: the river under a
## bridge, in tile space, or the tunnel's rock, in World pixels.
func _keep_clear(run: Array) -> Dictionary:
	var first: RoadTile = run[0]
	var last: RoadTile = run[-1]
	var rect := Rect2(Vector2(first.cell), Vector2.ONE).merge(
		Rect2(Vector2(last.cell), Vector2.ONE)
	)
	var axis := Vector2.AXIS_X if Heading.VEC[first.heading].x != 0 else Vector2.AXIS_Y
	if first.set_piece == &"bridge":
		return {"river": Bridge.river(rect, axis)}
	var across := Tunnel.HALF_WIDTH - 0.5
	var box := rect.grow_individual(0.0, across, 0.0, across)
	if axis == Vector2.AXIS_Y:
		box = rect.grow_individual(across, 0.0, across, 0.0)
	var hull := SetPiece.corners(box) + SetPiece.corners(box, Tuning.TUNNEL_HEIGHT_PX)
	return {"rock": Geometry2D.convex_hull(hull)}


func test_props_keep_off_the_river_and_out_of_the_tunnels_rock() -> void:
	var problems := PackedStringArray()
	var near := 0
	for run_seed: int in [4, 5]:
		var road := _road(_set_piece_schedule(80), run_seed, _largest())
		var rivers: Array[Rect2] = []
		var rocks: Array[PackedVector2Array] = []
		for run: Array in _runs(road):
			var clear := _keep_clear(run)
			if clear.has("river"):
				rivers.append(clear["river"])
			else:
				rocks.append(clear["rock"])
		assert_gt(mini(rivers.size(), rocks.size()), 5, "set pieces to keep clear of")
		for k: int in road.rows:
			for placement: PropLayout.Placement in road.rows[k]:
				var at := Iso.world_to_tile(placement.foot)
				for river: Rect2 in rivers:
					near += 1 if river.grow(1.0).has_point(at) else 0
					if river.has_point(at):
						problems.append("row %d: %s is in the river %s" % [k, at, river])
				var frame := _frame(placement)
				var polygon := PackedVector2Array(
					[frame.position, Vector2(frame.end.x, frame.position.y), frame.end]
				)
				polygon.append(Vector2(frame.position.x, frame.end.y))
				for rock: PackedVector2Array in rocks:
					if not Geometry2D.intersect_polygons(polygon, rock).is_empty():
						problems.append("row %d: %s shows over a tunnel" % [k, frame])
	assert_eq(problems.slice(0, 5), PackedStringArray(), "%d props in set pieces" % problems.size())
	assert_gt(near, 20, "props near enough to the rivers to tell")


## A seed places the same props whenever its rows are placed, as the road is made or once it's all
## made, and another seed places others on the same road.
func test_a_seed_places_the_same_props_and_another_seed_others() -> void:
	var first := _road(Fixtures.schedule(), 7, _largest())
	var again := _road(Fixtures.schedule(), 7, _largest())
	var props_seed := first.buffer.generator.props_seed
	assert_eq(again.buffer.generator.props_seed, props_seed)
	var placed := _described(first.rows)
	assert_eq(_described(again.rows), placed, "the same seed")
	assert_eq(_described(_placed_again(first, props_seed)), placed, "on the whole road")
	var other := RoadGenerator.new(8, Fixtures.schedule()).props_seed
	assert_ne(other, props_seed, "each run's own seed")
	var moved := _described(_placed_again(first, other))
	var differ := 0
	for k: int in ROWS:
		differ += 1 if moved[k] != placed[k] else 0
	@warning_ignore("integer_division")
	assert_gt(differ, ROWS * 9 / 10, "another props seed places other props on the same road")


## The rows of `road`, placed again with `props_seed` on the whole road.
func _placed_again(road: Road, props_seed: int) -> Dictionary[int, Array]:
	var rows: Dictionary[int, Array] = {}
	for k: int in ROWS:
		rows[k] = PropLayout.row(road.path[k].cell, _largest(), props_seed, road.buffer)
	return rows


## Each prop of `rows` as an id, a foot and a phase, row by row.
func _described(rows: Dictionary[int, Array]) -> Array[Array]:
	var described: Array[Array] = []
	for k: int in ROWS:
		var row := []
		for placement: PropLayout.Placement in rows[k]:
			row.append([placement.def.id, placement.foot, placement.phase])
		described.append(row)
	return described


func test_each_prop_takes_its_density_of_the_ground_with_no_pattern() -> void:
	var props: Array[PropDef] = [
		_prop(&"a", Vector2i(8, 8), Vector2i(4, 8), 0.2),
		_prop(&"b", Vector2i(8, 8), Vector2i(4, 8), 0.05),
		_prop(&"c", Vector2i(8, 8), Vector2i(4, 8), 0.01),
	]
	var side := 200
	var counts: Dictionary[StringName, int] = {&"a": 0, &"b": 0, &"c": 0, &"": 0}
	var picked: Dictionary[Vector2i, StringName] = {}
	for y: int in side:
		for x: int in side:
			@warning_ignore("integer_division")
			var cell := Vector2i(x - side / 2, y - side / 2)
			var def := PropLayout.pick(props, PropLayout.cell_hash(20261120, cell))
			picked[cell] = def.id if def != null else &""
			counts[picked[cell]] += 1
	var cells := float(side * side)
	for def: PropDef in props:
		# Within four standard deviations of the density.
		var spread := 4.0 * sqrt(cells * def.density * (1.0 - def.density))
		assert_almost_eq(float(counts[def.id]), cells * def.density, spread, String(def.id))
	# Neither a row nor a column repeats: two neighbours show a's as often as two cells anywhere.
	for step: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.ONE]:
		var pairs := 0
		for cell: Vector2i in picked:
			if picked[cell] == &"a" and picked.get(cell + step, &"") == &"a":
				pairs += 1
		var expected := cells * 0.2 * 0.2
		assert_almost_eq(float(pairs), expected, 4.0 * sqrt(expected), "a's in pairs %s" % step)
