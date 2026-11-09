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
		elif entry.area != null and gap(entry) > Tuning.BUFFER_REFILL_AT:
			problems.append(
				(
					"turn %d: the next junction can be %d tiles away, above BUFFER_REFILL_AT (%d)"
					% [entry.turn, gap(entry), Tuning.BUFFER_REFILL_AT]
				)
			)
	return problems


## The most path tiles from a junction to the next in `entry`'s area, counting the next: the set
## piece that leads into the area, the area's longest straight, and the junction's own tile. The
## JunctionTrigger looks for the next junction as the car enters the tile after a junction, when
## the buffer is sure to hold only BUFFER_REFILL_AT tiles past that tile (M2_PLAN.md H31).
## validate() keeps one of them spare, so that it doesn't rest on CarSim moving the buffer on
## before the trigger looks (M4_PLAN.md K2).
static func gap(entry: AreaScheduleEntry) -> int:
	return entry.set_piece_length + entry.area.max_straight + 1


## A copy that starts in the area `id`, for tests and manual checks (main.gd's --area): the entries
## from that area's on, with their turns moved so that it is turn 0, and without its set piece.
## The entries share their areas with this schedule. For an id it lacks: an error, and this one.
func starting_at(id: StringName) -> AreaSchedule:
	var start := -1
	for k: int in entries.size():
		if entries[k] != null and entries[k].area != null and entries[k].area.id == id:
			start = k
			break
	if start == -1:
		push_error("AreaSchedule: no area %s" % id)
		return self
	var schedule := AreaSchedule.new()
	for entry: AreaScheduleEntry in entries.slice(start):
		if entry == null:
			# validate() reports it.
			schedule.entries.append(null)
			continue
		var copy := AreaScheduleEntry.new()
		copy.turn = entry.turn - entries[start].turn
		copy.area = entry.area
		if copy.turn > 0:
			copy.set_piece = entry.set_piece
			copy.set_piece_length = entry.set_piece_length
		schedule.entries.append(copy)
	return schedule
