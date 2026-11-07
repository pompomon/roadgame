class_name AreaDef
extends Resource
## The rules of one area (plan.md §3.7). M1 has the fields the generator and the grey-box renderer
## use; M2 and M4 add the driving, prop, disaster and audio fields.

@export var id := &""
@export var display_name := ""
## Grey-box colour of the area's ground (IMPLEMENTATION_PLAN.md M4.1).
@export var id_color := Color.GRAY
## Straight tiles between two junctions. Both are at least 2 (D7).
@export_range(2, 20) var min_straight := 2
@export_range(2, 20) var max_straight := 5
## Chance that a junction also offers "straight on" as a wrong exit (a crossroads).
@export_range(0.0, 1.0) var cross_junction_chance := 0.3


## Returns what breaks the generator's rules, or nothing.
func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if id == &"":
		problems.append("an area has no id")
	if min_straight < 2:
		problems.append("%s: min_straight %d is below 2 (D7)" % [id, min_straight])
	if max_straight < min_straight:
		problems.append("%s: max_straight %d is below min_straight" % [id, max_straight])
	if cross_junction_chance < 0.0 or cross_junction_chance > 1.0:
		problems.append("%s: cross_junction_chance is outside 0..1" % id)
	return problems
