extends RefCounted
## Shared builders for the road tests. No class_name: tests/ is not exported.


static func schedule() -> AreaSchedule:
	return load("res://areas/schedule.tres")


## One area with the shortest straights and the most dead ends the rules allow, so that dead ends
## collide as often as possible.
static func dense_schedule() -> AreaSchedule:
	var area := AreaDef.new()
	area.id = &"dense"
	area.min_straight = 2
	area.max_straight = 2
	area.cross_junction_chance = 1.0
	var entry := AreaScheduleEntry.new()
	entry.area = area
	var dense := AreaSchedule.new()
	dense.entries.append(entry)
	return dense


## What a test compares to decide that two tiles are the same: a path tile and its branches.
static func signature(tile: RoadTile) -> Array:
	var sig: Array = [
		tile.cell, tile.type, tile.exits, tile.area_id, tile.path_index, tile.expected_exit
	]
	sig.append(tile.set_piece)
	for branch: RoadTile in tile.branches:
		sig.append_array([branch.cell, branch.type, branch.exits, branch.junction_index])
	return sig


## Path tiles from a fresh generator until it has emitted `turns` junctions.
static func path_until_turn(gen: RoadGenerator, turns: int) -> Array[RoadTile]:
	var path: Array[RoadTile] = []
	while gen.turn_count < turns:
		path.append(gen.next_tile())
	return path
