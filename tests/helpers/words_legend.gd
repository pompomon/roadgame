extends Legend
## A legend with only its words and a figure, for the screens that show them apart from the game's
## pools, such as the Book (docs/ENDGAME.md §5.10): Disasters.packed_legend() sets them. It plays
## one empty beat. No class_name: tests/ is not exported, and the name doesn't start with test_,
## which GUT would take for a test script.


func _beats() -> Array[float]:
	return [0.0]


func _pose(_beat: int, _t: float) -> void:
	pass
