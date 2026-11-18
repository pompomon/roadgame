class_name BookRow
extends HBoxContainer
## A row of the Book of Legends (ENDGAME_PLAN.md §5.10): an area's seal, then a cell for each slot
## of its pool. The seal, an eight-pointed star of two squares, is whole in the area's colour once
## every legend of the row is found, and hollow until then, the star's outline in a grey, so that
## the two differ by their shapes too (ENDGAME_PLAN.md W26). Only a screen reader's focus stops on
## the row, which BookScreen names.

## Whether every legend of the row is found.
var sealed := false

@onready var _square: ColorRect = %Square
@onready var _diamond: ColorRect = %Diamond
@onready var _hollow: Control = %Hollow


## Colours the seal `color`, and marks the row `p_sealed`: until then, the seal is hollow. The row
## must be in the tree.
func seal(color: Color, p_sealed: bool) -> void:
	sealed = p_sealed
	_square.color = color
	_diamond.color = color
	_hollow.visible = not p_sealed


## The seal's colour.
func seal_color() -> Color:
	return _square.color


## Whether the seal is hollow, only its outline drawn.
func hollow() -> bool:
	return _hollow.visible


## The row's cells, in the order of its pool.
func cells() -> Array[BookCell]:
	var found: Array[BookCell] = []
	for child: Node in get_children():
		if child is BookCell:
			found.append(child)
	return found
