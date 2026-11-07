class_name AreaSchedule
extends Resource
## Areas keyed by correct-turn count (plan.md §3.6). The last area continues forever.

@export var entries: Array[AreaScheduleEntry] = []


## Returns what breaks the schedule rules, or nothing.
func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if entries.is_empty():
		problems.append("the schedule has no entries")
		return problems
	# A null slot, such as an entry added in the Inspector but never assigned.
	var missing := entries.find(null)
	if missing != -1:
		problems.append("entry %d is missing" % missing)
		return problems
	if entries[0].turn != 0:
		problems.append("the first entry is turn %d, not 0" % entries[0].turn)
	if entries[0].set_piece_length != 0:
		problems.append("the first entry has a set piece")
	var last_turn := -1
	for entry: AreaScheduleEntry in entries:
		if entry.turn <= last_turn:
			problems.append("turn %d does not come after turn %d" % [entry.turn, last_turn])
		last_turn = entry.turn
		if entry.area == null:
			problems.append("turn %d has no area" % entry.turn)
		else:
			problems.append_array(entry.area.validate())
		if entry.set_piece_length < 0:
			problems.append("turn %d: set_piece_length is negative" % entry.turn)
		elif (entry.set_piece == &"") != (entry.set_piece_length == 0):
			problems.append("turn %d: set_piece and set_piece_length disagree" % entry.turn)
	return problems
