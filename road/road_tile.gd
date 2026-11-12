class_name RoadTile
extends RefCounted
## One road cell (IMPLEMENTATION_PLAN.md M1.2). Correct-path tiles have a path_index; dead-end
## tiles belong to a junction, which owns them in `branches` and frees them with itself.

enum Type { STRAIGHT, CORNER, T_JUNCTION, CROSS_JUNCTION, DEAD_END, SET_PIECE }

var cell: Vector2i
var type: Type
## Direction of travel when entering this tile.
var heading: int
## Bitmask of Heading.bit() for every edge with road, including the entry edge.
var exits: int
## Index on the correct path, or -1 for dead-end tiles.
var path_index := -1
var area_id := &""
## Junctions only: the turns before it, which is the 0-based number of the next turn. Turn 0 expects
## a left turn. A decoy shares it with the junction after it.
var turn_number := -1
## Junctions only: the heading of the correct exit, which is the next turn, or straight on at a
## decoy.
var expected_exit := -1
## Dead-end tiles only: path_index of their junction. An index, not a reference, so tiles never
## form a reference cycle (RefCounted cycles are never freed).
var junction_index := -1
## Dead-end tiles only: the junction exit this branch continues.
var branch_exit := -1
## Junctions only: the dead-end tiles of every wrong exit, nearest first.
var branches: Array[RoadTile] = []
## &"tunnel", &"bridge" or &"".
var set_piece := &""


func _init(p_cell: Vector2i, p_type: Type, p_heading: int, p_exits: int) -> void:
	cell = p_cell
	type = p_type
	heading = p_heading
	exits = p_exits


func is_junction() -> bool:
	return type == Type.T_JUNCTION or type == Type.CROSS_JUNCTION


## A junction whose correct exit turns: every junction but a decoy.
func is_turn() -> bool:
	return is_junction() and expected_exit != heading


func has_exit(h: int) -> bool:
	return exits & Heading.bit(h) != 0
