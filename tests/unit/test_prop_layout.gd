extends GutTest
## PropLayout (docs/M5.md §5.6): where each row's props stand. The brute-force tests place each row
## as PropScatter does, once the road has rows_needed() path tiles past the row's, and check the
## props against the whole road made by the end, with geometry of their own.

const Fixtures := preload("res://tests/helpers/road_fixtures.gd")
const CITY := preload("res://areas/city.tres")
## Of the eight ground cells around a cell, the four after it: each pair of neighbours once.
const NEXT_CELLS: Array[Vector2i] = [
	Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)
]
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


## A prop with a box as wide as a building's, on a lot of 2 × 2 cells: its foot on the lot's front
## cell, and its box reaching back over the rest (docs/VISUALS.md §5.4).
func _block(density: float) -> PropDef:
	var def := _prop(&"block", Vector2i(42, 58), Vector2i(21, 57), density)
	def.lot = 2
	return def


## A block that may rise over the road behind it, as the City's building may (§5.9), with its box's
## base, whose middle its shadow falls from, in its lot; on a lot by a street at `street_density`
## (§5.8), unless that is -1.
func _see_through(density: float, street_density: float) -> PropDef:
	var def := _block(density)
	def.id = &"see_through"
	def.shadow_rise = 10
	def.see_through = true
	def.street_density = street_density
	return def


## The ground cell that `placement`'s foot stands on.
static func _ground_cell(placement: PropLayout.Placement) -> Vector2i:
	return Vector2i((Iso.world_to_tile(placement.foot) * Iso.GROUND_PER_TILE).floor())


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


func test_a_lot_shows_one_prop_on_its_front_cell_and_no_other_stands_on_it() -> void:
	# The lots of a tile start at its corner, and a prop stands on the centre of its lot's front
	# cell, the one nearest the bottom of the screen. The larger lots go first, so neither a block
	# nor a post stands on a square's tile. A lot whose prop would touch the road stays free for the
	# props of its cells.
	var block := _block(0.3)
	var square := _prop(&"square", Vector2i(64, 40), Vector2i(32, 39), 0.2)
	square.lot = 4
	var props: Array[PropDef] = [block, square, _prop(&"post", Vector2i(8, 8), Vector2i(4, 8), 0.3)]
	var problems := PackedStringArray()
	var counts: Dictionary[StringName, int] = {&"square": 0, &"block": 0, &"post": 0, &"freed": 0}
	for run_seed: int in [1, 2]:
		var road := _road(Fixtures.schedule(), run_seed, props)
		var taken: Dictionary[Vector2i, StringName] = {}
		var props_seed := road.buffer.generator.props_seed
		for k: int in road.rows:
			for placement: PropLayout.Placement in road.rows[k]:
				var front := _ground_cell(placement)
				var lot := placement.def.lot
				var what := "row %d: %s on %s" % [k, placement.def.id, front]
				if posmod(front.x, lot) != lot - 1 or posmod(front.y, lot) != lot - 1:
					problems.append(what + " isn't its lot's front cell")
				if placement.foot != PropLayout.ground_centre(front):
					problems.append(what + " is off its centre")
				for b: int in lot:
					for a: int in lot:
						var cell := front - Vector2i(a, b)
						if taken.has(cell):
							problems.append(what + " stands on %s's lot" % taken[cell])
						taken[cell] = placement.def.id
				counts[placement.def.id] += 1
				var around := (
					front - Vector2i(posmod(front.x, 2), posmod(front.y, 2)) + Vector2i.ONE
				)
				var hashed := PropLayout.lot_hash(props_seed, around, 2)
				if lot == 1 and PropLayout.pick([block], hashed) != null:
					counts[&"freed"] += 1
	assert_eq(problems.slice(0, 5), PackedStringArray(), "%d props astray" % problems.size())
	assert_gt(counts[&"square"], 250, "enough tiles to tell")
	assert_gt(counts[&"block"], 1000, "enough lots to tell")
	assert_gt(counts[&"post"], 1000, "enough cells to tell")
	assert_gt(counts[&"freed"], 20, "posts on lots whose block would touch the road")


func test_each_size_of_lot_takes_its_density_and_a_free_lots_cells_their_own() -> void:
	# On ground with no road. The larger lots go first, so each size takes its density of the lots
	# that a larger one left free. A lot that shows nothing leaves each of its cells its own chance:
	# its front cell's too, though that cell's hash is its lot's but for LOT_SALT.
	var square := _prop(&"square", Vector2i(64, 40), Vector2i(32, 39), 0.2)
	square.lot = 4
	var props: Array[PropDef] = [
		_block(0.3), square, _prop(&"post", Vector2i(8, 8), Vector2i(4, 8), 0.2)
	]
	var buffer := RoadBuffer.new(RoadGenerator.new(1, Fixtures.schedule()))
	var rows := 100
	var counts: Dictionary[StringName, int] = {&"square": 0, &"block": 0, &"post": 0, &"front": 0}
	for k: int in rows:
		for placement: PropLayout.Placement in PropLayout.row(Vector2i(0, -k), props, 7, buffer):
			counts[placement.def.id] += 1
			var cell := _ground_cell(placement)
			if placement.def.lot == 1 and posmod(cell.x, 2) == 1 and posmod(cell.y, 2) == 1:
				counts[&"front"] += 1
	var tiles := rows * (2 * Tuning.PROP_SPREAD + 1)
	# The lots of 2 × 2 cells in the tiles that no square took.
	@warning_ignore("integer_division")
	var lots := (tiles - counts[&"square"]) * Iso.GROUND_PER_TILE * Iso.GROUND_PER_TILE / 4
	var free := lots - counts[&"block"]
	# Within four standard deviations of each density.
	for share: Array in [
		[&"square", tiles, 0.2],
		[&"block", lots, 0.3],
		[&"post", 4 * free, 0.2],
		[&"front", free, 0.2]
	]:
		var expected: float = share[1] * share[2]
		var spread := 4.0 * sqrt(expected * (1.0 - share[2]))
		assert_almost_eq(float(counts[share[0]]), expected, spread, String(share[0]))


func test_props_of_one_cell_stand_where_they_stood_before_lots() -> void:
	# On ground with no road, each cell of a row's tiles shows the prop that its own hash picks, or
	# none, tile by tile and cell by cell: so an area whose props all take one cell shows each where,
	# and in the order, it did before lots (docs/VISUALS.md A6).
	var props: Array[PropDef] = [
		_prop(&"a", Vector2i(8, 8), Vector2i(4, 8), 0.2),
		_prop(&"b", Vector2i(8, 8), Vector2i(4, 8), 0.05),
	]
	var buffer := RoadBuffer.new(RoadGenerator.new(1, Fixtures.schedule()))
	var moved: Array[int] = []
	var shown := 0
	for k: int in 20:
		var anchor := Vector2i(0, -k)
		var expected: Array[Array] = []
		for j: int in range(-Tuning.PROP_SPREAD, Tuning.PROP_SPREAD + 1):
			for b: int in Iso.GROUND_PER_TILE:
				for a: int in Iso.GROUND_PER_TILE:
					var cell := (anchor + Vector2i(j, -j)) * Iso.GROUND_PER_TILE + Vector2i(a, b)
					var def := PropLayout.pick(props, PropLayout.cell_hash(7, cell))
					if def != null:
						expected.append([def.id, PropLayout.ground_centre(cell)])
		var placed: Array[Array] = []
		for placement: PropLayout.Placement in PropLayout.row(anchor, props, 7, buffer):
			placed.append([placement.def.id, placement.foot])
		if placed != expected:
			moved.append(k)
		shown += placed.size()
	assert_eq(moved, [] as Array[int], "rows whose props moved")
	assert_gt(shown, 1000, "enough props to tell")


func test_a_row_spreads_across_the_view_from_each_path_tile_below_it() -> void:
	# The car drives the PROP_AHEAD path tiles below a row while the row may show ahead, and a long
	# straight runs them farther across the screen than PROP_SPREAD. So a row's span() reaches,
	# in half tiles across, PROP_SPREAD and a half either side of its path tile and PROP_VIEW_SPREAD
	# and a half either side of each of those, and a tile less wouldn't; and its props stand on the
	# span's tiles that are neither road nor by a set piece (docs/SPEEDUP.md §4.3). A dot on every
	# ground cell shows the tiles. The Desert's decoys join straights into long ones.
	var props: Array[PropDef] = [_prop(&"dot", Vector2i(2, 2), Vector2i(1, 2), 1.0)]
	var spread := Vector2i(-Tuning.PROP_SPREAD, Tuning.PROP_SPREAD)
	var reach := 2 * Tuning.PROP_VIEW_SPREAD + 1
	var wider := 0
	for run_seed: int in [1, 2, 3]:
		var road := _road(Fixtures.endless().starting_at(&"desert"), run_seed, props)
		var below_start := PropLayout.span(Vector2i.ONE, road.buffer)
		assert_eq(below_start, spread, "seed %d: below the start" % run_seed)
		for k: int in road.rows:
			var anchor := road.path[k].cell
			var span := PropLayout.span(anchor, road.buffer)
			var need := 2 * spread + Vector2i(-1, 1)
			for below: int in range(maxi(k - Tuning.PROP_AHEAD, 0), k):
				var cell := road.path[below].cell
				var across := cell.x - cell.y - anchor.x + anchor.y
				need = Vector2i(mini(need.x, across - reach), maxi(need.y, across + reach))
			var what := "seed %d, row %d: span %s for %s" % [run_seed, k, span, need]
			assert_true(2 * span.x - 1 <= need.x and 2 * span.y + 1 >= need.y, "reaches, " + what)
			assert_true(2 * span.x + 1 > need.x and 2 * span.y - 1 < need.y, "no farther, " + what)
			wider += int(span != spread)
			var shown: Array[Vector2i] = []
			for placement: PropLayout.Placement in road.rows[k]:
				var tile := Vector2i(Iso.world_to_tile(placement.foot).floor())
				if not shown.has(tile):
					shown.append(tile)
			shown.sort()
			var ground: Array[Vector2i] = []
			for j: int in range(span.x, span.y + 1):
				var tile := anchor + Vector2i(j, -j)
				if (
					road.buffer.tile_at(tile) == null
					and not PropLayout.near_set_piece(tile, road.buffer)
				):
					ground.append(tile)
			assert_eq(shown, ground, "tiles with props, " + what)
	assert_gt(wider, 0, "rows that a long straight spreads wider")


func test_the_meadows_grass_takes_only_ground_that_showed_nothing() -> void:
	# The grass is the Meadows' last prop (docs/HEADLIGHTS.md §5.6), so it takes the share of the
	# hashes past the others': each other prop stands where it stood without the grass, in the same
	# phase, and the grass only where nothing stood.
	var props := (load("res://areas/meadows.tres") as AreaDef).props
	assert_eq(props[-1].id, &"grass", "the last prop")
	var others: Array[PropDef] = props.slice(0, -1)
	var with_grass := _road(Fixtures.schedule(), 5, props)
	var without := _road(Fixtures.schedule(), 5, others)
	var moved: Array[int] = []
	var grass := 0
	for k: int in ROWS:
		var kept: Array[Array] = []
		for placement: PropLayout.Placement in with_grass.rows[k]:
			if placement.def.id == &"grass":
				grass += 1
			else:
				kept.append([placement.def.id, placement.foot, placement.phase])
		var before: Array[Array] = []
		for placement: PropLayout.Placement in without.rows[k]:
			before.append([placement.def.id, placement.foot, placement.phase])
		if kept != before:
			moved.append(k)
	assert_eq(moved, [] as Array[int], "rows whose other props moved")
	assert_gt(grass, ROWS * 10, "the grass shows")


func test_the_city_shows_many_buildings_and_none_stand_in_each_other() -> void:
	# A building's box is 40 px wide and a ground cell 32 px, so two buildings on cells side by side,
	# or corner to corner, stand in each other (docs/VISUALS.md A3). On lots of 2 × 2 cells they
	# never do. And the City is dense: these roads show 4,951 buildings at 0.35 a lot and 0.6 by a
	# street, see-through (§5.3, §5.8, §5.9). Without its street density they show 4,427, and not
	# see-through 3,256, as no lot by a street then shows one (A16); main's 0.01 a cell showed 402.
	var props := (CITY as AreaDef).props
	var problems := PackedStringArray()
	var shown := 0
	for run_seed: int in [1, 2]:
		var road := _road(Fixtures.schedule(), run_seed, props)
		var cells: Dictionary[Vector2i, bool] = {}
		for k: int in road.rows:
			for placement: PropLayout.Placement in road.rows[k]:
				if placement.def.id == &"building":
					cells[_ground_cell(placement)] = true
		shown += cells.size()
		for cell: Vector2i in cells:
			for step: Vector2i in NEXT_CELLS:
				if cells.has(cell + step):
					problems.append("seed %d: on %s and %s" % [run_seed, cell, cell + step])
	assert_eq(problems.slice(0, 5), PackedStringArray(), "%d pairs of buildings" % problems.size())
	assert_gt(shown, 4600, "buildings on two roads of ROWS rows")


func test_see_through_props_rise_over_the_road_behind_them_but_never_stand_on_it() -> void:
	# A prop that may not rise over the road is left out where its frame would touch a road tile's
	# diamond. A see-through one isn't (§5.9), but its box's base, a diamond from its foot back to
	# twice its shadow_rise above it, lies in its lot, and so on no road tile.
	var plain: Array[int] = [0]
	var counted: Array[int] = [0]
	var over := PackedStringArray()
	var on := PackedStringArray()
	for run_seed: int in [1, 2]:
		var blocks: Array[PropDef] = [_block(0.5)]
		var kept := _road_problems(_road(Fixtures.schedule(), run_seed, blocks), plain)
		assert_eq(kept.slice(0, 5), PackedStringArray(), "seed %d: blocks on the road" % run_seed)
		var props: Array[PropDef] = [_see_through(0.5, -1.0)]
		var road := _road(Fixtures.schedule(), run_seed, props)
		over.append_array(_road_problems(road, counted))
		for k: int in road.rows:
			for placement: PropLayout.Placement in road.rows[k]:
				for corner: Vector2 in _base(placement):
					var tile := Vector2i(Iso.world_to_tile(corner).floor())
					if road.buffer.tile_at(tile) != null:
						on.append("row %d: %s on %s" % [k, corner, tile])
	assert_eq(on.slice(0, 5), PackedStringArray(), "%d bases on the road" % on.size())
	assert_gt(over.size(), 200, "frames that rise over the road")
	assert_gt(counted[0], plain[0], "more than the blocks that keep off the road")


## The corners of the base of `placement`'s box, in world pixels: the box's shadow falls from the
## middle of that diamond, shadow_rise above its foot.
static func _base(placement: PropLayout.Placement) -> Array[Vector2]:
	var rise := 2.0 * placement.def.shadow_rise
	var foot := placement.foot
	return [
		foot,
		foot + Vector2(-rise, -rise * 0.5),
		foot + Vector2(0.0, -rise),
		foot + Vector2(rise, -rise * 0.5),
	]


## Whether the lot of `side` × `side` ground cells from `corner` has a side on a road tile's side: a
## cell across one of its sides, not just a corner, is on a road tile of `buffer`.
static func _by_street(corner: Vector2i, side: int, buffer: RoadBuffer) -> bool:
	var lot := Rect2i(corner, Vector2i(side, side))
	for b: int in side:
		for a: int in side:
			for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var next := corner + Vector2i(a, b) + step
				var tile := Vector2i((Vector2(next) / Iso.GROUND_PER_TILE).floor())
				if not lot.has_point(next) and buffer.tile_at(tile) != null:
					return true
	return false


func test_lots_by_a_street_take_its_street_density_and_the_others_its_density() -> void:
	# A lot with a side on a road tile's side, not just a corner, is by a street, and shows a prop at
	# its street density, and the others at its density (§5.8): Q2's 0.6 and 0.35 on lots of 2 × 2,
	# and a dot's 0.5 and 0.2 on the cells that no prop of 2 × 2 takes, within four standard
	# deviations. The dot is too small to touch the road from a cell by it. A row sees the road
	# across its tiles' sides when it's placed: placed again on the whole road, the rows are the same.
	var dot := _prop(&"dot", Vector2i(2, 2), Vector2i(1, 2), 0.2)
	dot.street_density = 0.5
	var props: Array[PropDef] = [_see_through(0.35, 0.6), dot]
	# Lots of 2 × 2, then free cells, and those that show their prop: by a street, then not.
	var lots: Array[int] = [0, 0, 0, 0]
	var shown: Array[int] = [0, 0, 0, 0]
	for run_seed: int in [1, 2, 3]:
		var road := _road(Fixtures.schedule(), run_seed, props)
		var again := _placed_again(road, road.buffer.generator.props_seed, props)
		assert_eq(_described(again), _described(road.rows), "seed %d on the whole road" % run_seed)
		for k: int in road.rows:
			var fronts: Dictionary[Vector2i, StringName] = {}
			for placement: PropLayout.Placement in road.rows[k]:
				fronts[_ground_cell(placement)] = placement.def.id
			var span := PropLayout.span(road.path[k].cell, road.buffer)
			for j: int in range(span.x, span.y + 1):
				var tile: Vector2i = road.path[k].cell + Vector2i(j, -j)
				if (
					road.buffer.tile_at(tile) != null
					or PropLayout.near_set_piece(tile, road.buffer)
				):
					continue
				for b: int in range(0, Iso.GROUND_PER_TILE, 2):
					for a: int in range(0, Iso.GROUND_PER_TILE, 2):
						var corner := tile * Iso.GROUND_PER_TILE + Vector2i(a, b)
						var inside := 0 if _by_street(corner, 2, road.buffer) else 1
						var built: bool = fronts.get(corner + Vector2i.ONE, &"") == &"see_through"
						lots[inside] += 1
						shown[inside] += int(built)
						if built:
							continue
						for d: int in 4:
							var cell := corner + Vector2i(d & 1, d >> 1)
							var free := 2 if _by_street(cell, 1, road.buffer) else 3
							lots[free] += 1
							shown[free] += int(fronts.get(cell, &"") == &"dot")
	assert_gt(lots.min(), 1000, "enough of each to tell: %s" % [lots])
	var shares: Array[Array] = [
		["lots by a street", 0.6],
		["lots inside", 0.35],
		["free cells by a street", 0.5],
		["free cells inside", 0.2],
	]
	for i: int in shares.size():
		var chance: float = shares[i][1]
		var expected := lots[i] * chance
		var spread := 4.0 * sqrt(expected * (1.0 - chance))
		assert_almost_eq(float(shown[i]), expected, spread, String(shares[i][0]))


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
	# See-through props too, which may rise over the road (§5.9): set_piece_margin() alone keeps
	# them clear.
	var problems := PackedStringArray()
	var near := 0
	for see_through: bool in [false, true]:
		var props := _largest()
		for def: PropDef in props:
			def.see_through = see_through
		for run_seed: int in [4, 5]:
			var road := _road(_set_piece_schedule(80), run_seed, props)
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
					var what := "row %d: %s" % [k, placement.def.id]
					problems.append_array(_in_set_pieces(placement, rivers, rocks, what))
					var at := Iso.world_to_tile(placement.foot)
					for river: Rect2 in rivers:
						near += 1 if river.grow(1.0).has_point(at) else 0
	assert_eq(problems.slice(0, 5), PackedStringArray(), "%d props in set pieces" % problems.size())
	assert_gt(near, 40, "props near enough to the rivers to tell")


## What `placement` does that it mustn't: stand in a river of `rivers`, or show over a tunnel's rock
## of `rocks`.
static func _in_set_pieces(
	placement: PropLayout.Placement,
	rivers: Array[Rect2],
	rocks: Array[PackedVector2Array],
	what: String
) -> PackedStringArray:
	var problems := PackedStringArray()
	var at := Iso.world_to_tile(placement.foot)
	for river: Rect2 in rivers:
		if river.has_point(at):
			problems.append("%s is in the river %s at %s" % [what, river, at])
	var frame := _frame(placement)
	var polygon := PackedVector2Array(
		[frame.position, Vector2(frame.end.x, frame.position.y), frame.end]
	)
	polygon.append(Vector2(frame.position.x, frame.end.y))
	for rock: PackedVector2Array in rocks:
		if not Geometry2D.intersect_polygons(polygon, rock).is_empty():
			problems.append("%s shows over a tunnel at %s" % [what, frame])
	return problems


## Last Gas's straight after every other turn (docs/ENDGAME.md §5.15), on an area of T-junctions,
## whose dead ends keep off the straights' far sides, where it stands.
func _pit_stop_schedule(turns: int) -> AreaSchedule:
	var area := AreaDef.new()
	area.id = &"plain"
	area.cross_junction_chance = 0.0
	var built := AreaSchedule.new()
	for turn: int in range(0, turns + 1, 2):
		var entry := AreaScheduleEntry.new()
		entry.turn = turn
		entry.area = area
		entry.pit_stop = turn > 0
		built.entries.append(entry)
	return built


## The runs of pit-stop path tiles of `road`.
func _pit_stop_runs(road: Road) -> Array[Array]:
	var runs: Array[Array] = []
	var run: Array[RoadTile] = []
	for tile: RoadTile in road.path:
		if tile.pit_stop:
			run.append(tile)
		elif not run.is_empty():
			runs.append(run)
			run = []
	return runs


## Where Last Gas may show by `run`, a pit stop's straight, in tile space: between the straight's
## ends, on its far side, from the road's edge out to where the nearest props' frames may show
## (test_last_gas.gd).
static func _last_gas_region(run: Array) -> Rect2:
	var first: RoadTile = run[0]
	var last: RoadTile = run[-1]
	var cells := Rect2(Vector2(first.cell), Vector2.ONE).merge(
		Rect2(Vector2(last.cell), Vector2.ONE)
	)
	var reach := PropLayout.set_piece_margin() + 0.5 - Tuning.PROP_MAX_SIZE.x * 0.5 / Iso.TILE_W
	reach -= float(Tuning.PROP_BELOW) / Iso.TILE_H
	var width := reach - Tuning.ROAD_HALF_WIDTH
	if Heading.VEC[first.heading].x != 0:
		return Rect2(cells.position.x, cells.get_center().y - reach, cells.size.x, width)
	return Rect2(cells.get_center().x - reach, cells.position.y, width, cells.size.y)


func test_no_prop_shows_where_last_gas_may() -> void:
	# See-through props too: set_piece_margin() of a pit stop's tiles alone keeps them clear.
	var problems := PackedStringArray()
	var near := 0
	for see_through: bool in [false, true]:
		var props := _largest()
		for def: PropDef in props:
			def.see_through = see_through
		for run_seed: int in [4, 5]:
			var road := _road(_pit_stop_schedule(80), run_seed, props)
			var regions: Array[Rect2] = []
			for run: Array in _pit_stop_runs(road):
				regions.append(_last_gas_region(run))
			assert_gt(regions.size(), 10, "pit stops to keep clear of")
			for k: int in road.rows:
				for placement: PropLayout.Placement in road.rows[k]:
					var frame := _frame(placement)
					var polygon := PackedVector2Array(
						[frame.position, Vector2(frame.end.x, frame.position.y), frame.end]
					)
					polygon.append(Vector2(frame.position.x, frame.end.y))
					var at := Iso.world_to_tile(placement.foot)
					for region: Rect2 in regions:
						var shown := SetPiece.corners(region)
						if not Geometry2D.intersect_polygons(polygon, shown).is_empty():
							problems.append("row %d: %s shows over %s" % [k, frame, region])
						near += 1 if region.grow(1.0).has_point(at) else 0
	assert_eq(problems.slice(0, 5), PackedStringArray(), "%d props by Last Gas" % problems.size())
	assert_gt(near, 40, "props near enough to Last Gas to tell")


## A seed places the same props whenever its rows are placed, as the road is made or once it's all
## made, and another seed places others on the same road.
func test_a_seed_places_the_same_props_and_another_seed_others() -> void:
	var first := _road(Fixtures.schedule(), 7, _largest())
	var again := _road(Fixtures.schedule(), 7, _largest())
	var props_seed := first.buffer.generator.props_seed
	assert_eq(again.buffer.generator.props_seed, props_seed)
	var placed := _described(first.rows)
	assert_eq(_described(again.rows), placed, "the same seed")
	assert_eq(_described(_placed_again(first, props_seed, _largest())), placed, "on the whole road")
	var other := RoadGenerator.new(8, Fixtures.schedule()).props_seed
	assert_ne(other, props_seed, "each run's own seed")
	var moved := _described(_placed_again(first, other, _largest()))
	var differ := 0
	for k: int in ROWS:
		differ += 1 if moved[k] != placed[k] else 0
	@warning_ignore("integer_division")
	assert_gt(differ, ROWS * 9 / 10, "another props seed places other props on the same road")


## The rows of `road`, placed again from `props` with `props_seed` on the whole road.
func _placed_again(road: Road, props_seed: int, props: Array[PropDef]) -> Dictionary[int, Array]:
	var rows: Dictionary[int, Array] = {}
	for k: int in ROWS:
		rows[k] = PropLayout.row(road.path[k].cell, props, props_seed, road.buffer)
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
