extends DisasterBase
## A disaster with only its words, for the screens that show them, apart from the game's pools
## (docs/M6.md S15): Disasters.packed() sets them. It plays nothing. No class_name: tests/ is not
## exported, and the name doesn't start with test_, which GUT would take for a test script.


func play(_params: DisasterParams) -> void:
	pass
