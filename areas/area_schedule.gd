class_name AreaSchedule
extends Resource
## Areas keyed by correct-turn count (plan.md §3.6). Without a finish, the last area continues
## forever. With one, the road ends in the last area: after finish_turn turns, the straight leads to
## the finish's set piece, and no junction comes after it (ENDGAME_PLAN.md §5.1).

@export var entries: Array[AreaScheduleEntry] = []
## The set piece that ends the road, such as &"pier", or &"" for a road with no end.
@export var finish := &""
## The turns after which the road ends. At least the last entry's turn: equal to it when the last
## area is a home stretch, with no junction.
@export var finish_turn := 0
## Whether the road is the mirror image of the first: it starts heading W, and its first turn is a
## right, so that it still heads only N and W (ENDGAME_PLAN.md §5.6, W9).
@export var mirrored := false


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
	if finish == &"" and finish_turn != 0:
		problems.append("finish_turn is %d, but there is no finish" % finish_turn)
	elif finish != &"" and finish_turn < last_turn:
		problems.append(
			"the finish (turn %d) comes before the last area (turn %d)" % [finish_turn, last_turn]
		)
	return problems


## Whether the road has an end.
func has_finish() -> bool:
	return finish != &""


## A copy with no end, whose last area goes on forever: the road of Keep Driving and of the tests
## that drive past the finish (ENDGAME_PLAN.md W6). It leaves out a home stretch, a last area that
## starts at the finish's turn, as such an area has no junction and no legend (W17): the area
## before it goes on instead, as the Desert does on main. It shares this one's entries.
func endless() -> AreaSchedule:
	var schedule := AreaSchedule.new()
	for entry: AreaScheduleEntry in entries:
		var stretch := has_finish() and entry != null and entry.turn >= finish_turn
		if not stretch or schedule.entries.is_empty():
			schedule.entries.append(entry)
	schedule.mirrored = mirrored
	return schedule


## A copy whose road ends at `p_finish` after `turns` turns, with the entries up to there: a short
## road for tests and manual checks (main.gd's --finish, ENDGAME_PLAN.md §5.7). It shares this
## one's entries.
func ending_at(turns: int, p_finish: StringName) -> AreaSchedule:
	var schedule := AreaSchedule.new()
	for entry: AreaScheduleEntry in entries:
		if entry == null or entry.turn <= turns:
			schedule.entries.append(entry)
	schedule.mirrored = mirrored
	schedule.finish = p_finish
	schedule.finish_turn = turns
	return schedule


## Each area of the schedule once, in the order a run reaches them: the Atlas's cards and the
## Book of Legends' rows (IMPLEMENTATION_PLAN.md M5.5, ENDGAME_PLAN.md §5.10).
func areas() -> Array[AreaDef]:
	var found: Array[AreaDef] = []
	for entry: AreaScheduleEntry in entries:
		if entry != null and entry.area != null and not found.has(entry.area):
			found.append(entry.area)
	return found


## The most path tiles from a junction to the next in `entry`'s area, counting the next: the set
## piece that leads into the area, the area's longest straight, and the junction's own tile. The
## JunctionTrigger looks for the next junction as the car enters the tile after a junction, when
## the buffer is sure to hold only BUFFER_REFILL_AT tiles past that tile (docs/M2.md H31).
## validate() keeps one of them spare, so that it doesn't rest on CarSim moving the buffer on
## before the trigger looks (docs/M4.md K1).
static func gap(entry: AreaScheduleEntry) -> int:
	return entry.set_piece_length + entry.area.max_straight + 1


## A copy that starts in the area `id`, for tests and manual checks (main.gd's --area, and the
## title's Start button in debug builds): the entries from that area's on, with their turns moved so
## that it is turn 0, and without its set piece, and the finish as many turns before. The entries
## share their areas with this schedule. For an id it lacks: an error, and this one.
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
	schedule.mirrored = mirrored
	if has_finish():
		schedule.finish = finish
		schedule.finish_turn = finish_turn - entries[start].turn
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
