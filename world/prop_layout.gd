class_name PropLayout
extends RefCounted
## Where the props of one screen row stand (docs/M5.md §5.6): a pure function of the run's
## props_seed, the area's props and the road around the row, so that a seed shows the same props
## on every run, at every frame rate and on every screen.
##
## Path tile k lies on screen row -k: the tiles whose cells add up to -k, side by side across the
## screen. Row k's props stand on the ground of the PROP_SPREAD tiles either side of path tile k,
## of those that are neither road nor within set_piece_margin() tiles of a set piece's road. Each
## such tile's ground cells make lots of each size that its props take (PropDef.lot), the largest
## first. Each lot that no larger prop stands on shows one prop of its size or none: its hash with
## props_seed picks one by their densities, or by a street by their street densities (§5.8). A lot
## of one cell has the cell's own hash, so props that take one cell stand where they stood before
## lots (VISUALS_PLAN.md §5.4). A prop whose frame would touch a road tile's diamond is left out,
## and its lot stays free, so that no prop hides the road or the car on it; but for a see-through
## one, which may rise over the road behind it, and fades where it would hide the car (§5.9).


## A prop of a row: which, where its foot stands, in world pixels, and where its animation starts,
## as a share of a cycle.
class Placement:
	extends RefCounted
	var def: PropDef
	var foot: Vector2
	var phase: float


const MASK := 0xFFFFFFFF
## Mixed into the hash of a lot larger than a cell, so that a cell whose lot shows nothing picks
## its own prop by a hash unlike its lot's.
const LOT_SALT := 0x9E3779B9
## The y of the highest foot on a row, below the top corner of its tiles: the centre of a tile's
## top ground cell.
const TOP_FOOT := Iso.TILE_H / (2.0 * Iso.GROUND_PER_TILE)
## The sides of a tile, a bit each, and the step to the tile across each: x-, x+, y- and y+.
const SIDES: Array[Vector2i] = [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]


## The props of the row whose path tile is on `anchor`, from `props`, beside the road of `buffer`.
## The buffer must have every tile that rows_needed() counts.
static func row(
	anchor: Vector2i, props: Array[PropDef], props_seed: int, buffer: RoadBuffer
) -> Array[Placement]:
	var placed: Array[Placement] = []
	if props.is_empty():
		return placed
	var sizes := by_lot(props)
	var singles: Array[PropDef] = sizes.get(1, [] as Array[PropDef])
	# Only an area with a street density looks for streets, so the others' rows cost as before.
	var streets := false
	for def: PropDef in props:
		streets = streets or def.street_density >= 0.0
	for j: int in range(-Tuning.PROP_SPREAD, Tuning.PROP_SPREAD + 1):
		var tile := anchor + Vector2i(j, -j)
		if buffer.tile_at(tile) != null or near_set_piece(tile, buffer):
			continue
		var origin := tile * Iso.GROUND_PER_TILE
		var roads := street_sides(tile, buffer) if streets else 0
		# The tile's cells that a larger lot's prop takes, a bit each.
		var taken := 0
		for lot: int in sizes:
			if lot == 1:
				continue
			var sized: Array[PropDef] = sizes[lot]
			for b: int in range(0, Iso.GROUND_PER_TILE, lot):
				for a: int in range(0, Iso.GROUND_PER_TILE, lot):
					var cells := lot_cells(Vector2i(a, b), lot)
					if taken & cells != 0:
						continue
					var front := origin + Vector2i(a, b) + Vector2i.ONE * (lot - 1)
					var hashed := lot_hash(props_seed, front, lot)
					var by_street := roads & lot_sides(Vector2i(a, b), lot) != 0
					var def := pick(sized, hashed, by_street)
					if def != null and _place(def, front, hashed, buffer, placed):
						taken |= cells
		if singles.is_empty():
			continue
		# The lots of one cell, as before lots, and as fast: most rows have no larger lots.
		for b: int in Iso.GROUND_PER_TILE:
			for a: int in Iso.GROUND_PER_TILE:
				if taken & (1 << (b * Iso.GROUND_PER_TILE + a)) != 0:
					continue
				var cell := origin + Vector2i(a, b)
				var hashed := cell_hash(props_seed, cell)
				var by_street := roads & lot_sides(Vector2i(a, b), 1) != 0
				var def := pick(singles, hashed, by_street)
				if def != null:
					_place(def, cell, hashed, buffer, placed)
	return placed


## Adds to `placed` a placement of `def` with its foot on ground cell `cell`, which `hashed` picked,
## unless its frame would touch the road of `buffer` and it isn't see-through. Returns whether it
## added it.
static func _place(
	def: PropDef, cell: Vector2i, hashed: int, buffer: RoadBuffer, placed: Array[Placement]
) -> bool:
	var placement := Placement.new()
	placement.def = def
	placement.foot = ground_centre(cell)
	placement.phase = float(_mix(hashed ^ 0x2545F491) & 0xFFFF) / 65536.0
	if not def.see_through and touches_road(def, placement.foot, buffer):
		return false
	placed.append(placement)
	return true


## The sides of `tile` that a road tile of `buffer` is across, a bit each, in SIDES' order.
static func street_sides(tile: Vector2i, buffer: RoadBuffer) -> int:
	var sides := 0
	for side: int in SIDES.size():
		if buffer.tile_at(tile + SIDES[side]) != null:
			sides |= 1 << side
	return sides


## The sides of a tile that the lot of `lot` cells a side whose back cell is `corner` lies along,
## a bit each, in SIDES' order.
static func lot_sides(corner: Vector2i, lot: int) -> int:
	var sides := 0
	if corner.x == 0:
		sides |= 1
	if corner.x + lot == Iso.GROUND_PER_TILE:
		sides |= 2
	if corner.y == 0:
		sides |= 4
	if corner.y + lot == Iso.GROUND_PER_TILE:
		sides |= 8
	return sides


## The props of `props` by the size of lot they take, largest first, each in their order. A prop
## whose lot doesn't divide a tile takes none: PropDef.validate() reports it.
static func by_lot(props: Array[PropDef]) -> Dictionary[int, Array]:
	var sizes: Dictionary[int, Array] = {}
	for lot: int in range(Iso.GROUND_PER_TILE, 0, -1):
		if Iso.GROUND_PER_TILE % lot != 0:
			continue
		var sized: Array[PropDef] = []
		for def: PropDef in props:
			if def.lot == lot:
				sized.append(def)
		if not sized.is_empty():
			sizes[lot] = sized
	return sizes


## The cells of a tile in the lot of `lot` cells a side whose back cell is `corner`, a bit each:
## cell (a, b) is bit b * GROUND_PER_TILE + a.
static func lot_cells(corner: Vector2i, lot: int) -> int:
	var cells := 0
	for b: int in range(corner.y, corner.y + lot):
		for a: int in range(corner.x, corner.x + lot):
			cells |= 1 << (b * Iso.GROUND_PER_TILE + a)
	return cells


## The hash of the lot of `lot` cells a side whose front cell is `cell`: the cell's own for a lot
## of one cell.
static func lot_hash(props_seed: int, cell: Vector2i, lot: int) -> int:
	var hashed := cell_hash(props_seed, cell)
	return hashed if lot == 1 else _mix(hashed ^ (LOT_SALT * lot & MASK))


## The path tiles past a row's own that must be made before it gets its props: the tiles whose
## diamonds its props' frames can reach, and those across its tiles' sides (street_sides()), are on
## the rows_above() rows above it and the one below, and a dead end can come down to them from
## DEAD_END_MAX_TILES rows higher; the set pieces they must keep away from are up to twice
## set_piece_margin() rows away.
static func rows_needed() -> int:
	return maxi(rows_above() + Tuning.DEAD_END_MAX_TILES, 2 * set_piece_margin())


## The rows above a row whose tiles' diamonds its props can reach: a frame reaches
## PROP_MAX_SIZE.y above a foot, which is at least TOP_FOOT below the row's top corner, and a
## diamond reaches TILE_H below its own.
static func rows_above() -> int:
	var reach := Tuning.PROP_MAX_SIZE.y - TOP_FOOT + Iso.TILE_H
	return ceili(reach / (Iso.TILE_H * 0.5)) - 1


## How far from a set piece's road its scene draws, in tiles: the river reaches RIVER_REACH tiles
## across the run from its centreline (Bridge.river()).
static func set_piece_margin() -> int:
	return ceili(Tuning.RIVER_REACH)


## Whether a set-piece tile is within set_piece_margin() tiles of `tile` along each axis.
static func near_set_piece(tile: Vector2i, buffer: RoadBuffer) -> bool:
	var margin := set_piece_margin()
	for y: int in range(-margin, margin + 1):
		for x: int in range(-margin, margin + 1):
			var near := buffer.tile_at(tile + Vector2i(x, y))
			if near != null and near.type == RoadTile.Type.SET_PIECE:
				return true
	return false


## Whether `def`'s frame, with its foot on `foot`, touches the inside of a road tile's diamond.
static func touches_road(def: PropDef, foot: Vector2, buffer: RoadBuffer) -> bool:
	var rect := Rect2(foot - Vector2(def.foot), Vector2(def.region.size))
	var half := Vector2(Iso.TILE_W, Iso.TILE_H) * 0.5
	# A tile's centre is at (u * half.x, (v + 1) * half.y) for u = x - y and v = x + y. Only the
	# tiles whose centres are within half a diamond of the frame can touch it.
	var u0 := floori(rect.position.x / half.x) - 1
	var u1 := ceili(rect.end.x / half.x) + 1
	var v0 := floori(rect.position.y / half.y) - 2
	var v1 := ceili(rect.end.y / half.y)
	for v: int in range(v0, v1 + 1):
		for u: int in range(u0, u1 + 1):
			if (u + v) & 1 != 0 or buffer.tile_at(Vector2i((u + v) >> 1, (v - u) >> 1)) == null:
				continue
			var centre := Vector2(u * half.x, (v + 1) * half.y)
			var dx := maxf(0.0, maxf(rect.position.x - centre.x, centre.x - rect.end.x))
			var dy := maxf(0.0, maxf(rect.position.y - centre.y, centre.y - rect.end.y))
			if dx / half.x + dy / half.y < 1.0:
				return true
	return false


## The prop of `props` that a lot with hash `hashed` shows, or null: each takes its chance's share
## of the hashes, in order, its street density's on a lot by a street (PropDef.chance()).
static func pick(props: Array[PropDef], hashed: int, by_street := false) -> PropDef:
	var share := float(hashed) / 4294967296.0
	for def: PropDef in props:
		share -= def.chance(by_street)
		if share < 0.0:
			return def
	return null


## The centre of ground cell `cell`, in world pixels.
static func ground_centre(cell: Vector2i) -> Vector2:
	return Iso.tile_to_world((Vector2(cell) + Vector2(0.5, 0.5)) / Iso.GROUND_PER_TILE)


## A 32-bit hash of ground cell `cell` and `props_seed`.
static func cell_hash(props_seed: int, cell: Vector2i) -> int:
	return _mix(_mix((props_seed ^ cell.x) & MASK) ^ (cell.y & MASK))


## Mixes the bits of a 32-bit value. Its products stay below 2^59, so they never overflow.
static func _mix(value: int) -> int:
	var x := (((value >> 16) ^ value) * 0x45d9f3b) & MASK
	x = (((x >> 16) ^ x) * 0x45d9f3b) & MASK
	return (x >> 16) ^ x
