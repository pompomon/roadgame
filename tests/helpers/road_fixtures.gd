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


## Two areas whose straights are all `straight` tiles, with no crossroads, so that junction k is
## path tile START_STRAIGHT_TILES + k * (straight + 1) until the second area: it starts at `turn`,
## after a set piece `length` tiles long.
static func set_piece_schedule(
	turn: int, set_piece: StringName, length: int, straight := 3
) -> AreaSchedule:
	var built := AreaSchedule.new()
	for id: StringName in [&"before", &"after"]:
		var area := AreaDef.new()
		area.id = id
		area.min_straight = straight
		area.max_straight = straight
		area.cross_junction_chance = 0.0
		var entry := AreaScheduleEntry.new()
		entry.area = area
		if id == &"after":
			entry.turn = turn
			entry.set_piece = set_piece
			entry.set_piece_length = length
		built.entries.append(entry)
	return built


## dense_schedule()'s area, with a bridge after every junction up to `turns`, 2 to 6 tiles long.
static func bridge_every_turn(turns: int) -> AreaSchedule:
	var dense := dense_schedule()
	for turn: int in range(1, turns + 1):
		var entry := AreaScheduleEntry.new()
		entry.turn = turn
		entry.area = dense.entries[0].area
		entry.set_piece = &"bridge"
		entry.set_piece_length = 2 + turn % 5
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
