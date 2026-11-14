extends GutTest
## JunctionTrigger on a real road buffer, called the way CarSim calls it.

const Fixtures := preload("res://tests/helpers/road_fixtures.gd")

var _buffer: RoadBuffer
var _trigger: JunctionTrigger


## Starts on the road of `run_seed` and `schedule`, by default the game's.
func _start(run_seed: int, schedule: AreaSchedule = null) -> void:
	var road := schedule if schedule != null else Fixtures.schedule()
	_buffer = RoadBuffer.new(RoadGenerator.new(run_seed, road))
	_buffer.start()
	_restart()


## A new trigger on the same buffer, which starts again at the first junction.
func _restart() -> void:
	_trigger = JunctionTrigger.new(_buffer)
	watch_signals(_trigger)


## Starts the first seed whose first junction passes `check`, and returns that junction.
func _start_where(check: Callable, schedule: AreaSchedule = null) -> RoadTile:
	for run_seed: int in range(1, 100):
		_start(run_seed, schedule)
		if check.call(_junctions()[0]):
			return _junctions()[0]
	fail_test("no seed from 1 to 99 has such a first junction")
	return null


## A check for _start_where(): the junction is of `kind`.
static func _of_kind(kind: int) -> Callable:
	return func(j: RoadTile) -> bool: return Fixtures.kind(j) == kind


## The buffer's junctions, in path order.
func _junctions() -> Array[RoadTile]:
	var found: Array[RoadTile] = []
	for i: int in range(_buffer.first_index(), _buffer.last_index() + 1):
		if _buffer.path_tile(i).is_junction():
			found.append(_buffer.path_tile(i))
	return found


## Crosses from `junction` through its edge with heading `exit`.
func _leave(junction: RoadTile, exit: int, on_road := true) -> void:
	_trigger.on_cell_crossed(junction.cell, junction.cell + Heading.VEC[exit], on_road)


func _assert_nothing_decided(first: RoadTile) -> void:
	assert_signal_not_emitted(_trigger, "turn_completed")
	assert_signal_not_emitted(_trigger, "disaster_triggered")
	assert_eq(_trigger.next_junction, first)
	assert_eq(_trigger.turn_index, 0)


func test_starts_at_the_first_junction() -> void:
	for run_seed: int in 20:
		_start(run_seed)
		assert_eq(_trigger.next_junction, _junctions()[0], "seed %d" % run_seed)
		assert_eq(_trigger.turn_index, 0)


func test_the_correct_exit_completes_the_turn() -> void:
	_start(1)
	var junctions := _junctions()
	_leave(junctions[0], junctions[0].expected_exit)
	assert_signal_emitted_with_parameters(_trigger, "turn_completed", [1])
	assert_eq(_trigger.next_junction, junctions[1])
	_leave(junctions[1], junctions[1].expected_exit)
	assert_signal_emitted_with_parameters(_trigger, "turn_completed", [2])
	assert_eq(_trigger.turn_index, 2)
	assert_eq(_trigger.next_junction, junctions[2])
	assert_signal_not_emitted(_trigger, "disaster_triggered")


## Each exit of the first junction of each kind, from a new trigger each time: the correct one
## completes a turn, or no turn at a decoy (docs/ROADGEN.md R2), and every other is a disaster.
func test_each_kind_of_junction_has_one_correct_exit() -> void:
	for kind: int in RoadGenerator.Kind.values():
		var junction := _start_where(_of_kind(kind), Fixtures.kinds_schedule(0.25, 0.25, 0.25))
		if junction == null:
			return
		var after := _junctions()[1]
		var exits := 0
		for exit: int in 4:
			if exit != Heading.opposite(junction.heading) and junction.has_exit(exit):
				_restart()
				_leave(junction, exit)
				_assert_decided(junction, exit, after)
				exits += 1
		assert_eq(exits, 3 if kind == RoadGenerator.Kind.CROSSROADS else 2, "kind %d" % kind)


## What leaving `junction`, the first, through `exit` decided. `after` is the junction after it.
func _assert_decided(junction: RoadTile, exit: int, after: RoadTile) -> void:
	var where := "kind %d exit %d" % [Fixtures.kind(junction), exit]
	if exit != junction.expected_exit:
		assert_signal_emitted_with_parameters(_trigger, "disaster_triggered", [junction, exit])
		assert_signal_not_emitted(_trigger, "turn_completed", where)
		assert_null(_trigger.next_junction, where)
		assert_eq(_trigger.turn_index, 0, where)
		return
	var turns := 1 if junction.is_turn() else 0
	assert_signal_emitted_with_parameters(_trigger, "turn_completed", [turns])
	assert_signal_not_emitted(_trigger, "disaster_triggered", where)
	assert_eq(_trigger.turn_index, turns, where)
	assert_eq(_trigger.next_junction, after, where)


func test_nothing_is_decided_after_a_disaster() -> void:
	_start(1)
	var junctions := _junctions()
	_trigger.on_offroad_limit()
	_leave(junctions[0], junctions[0].expected_exit)
	_trigger.on_rejoin(_buffer.path_tile(junctions[1].path_index + 1))
	_trigger.on_offroad_limit()
	assert_signal_emit_count(_trigger, "disaster_triggered", 1)
	assert_signal_not_emitted(_trigger, "turn_completed")


func test_going_back_out_of_the_entry_edge_decides_nothing() -> void:
	_start(1)
	var first := _junctions()[0]
	_leave(first, Heading.opposite(first.heading))
	_assert_nothing_decided(first)


func test_an_edge_without_road_decides_nothing() -> void:
	var t := _start_where(func(j: RoadTile) -> bool: return not j.has_exit(j.heading))
	_leave(t, t.heading)
	_assert_nothing_decided(t)


func test_crossings_off_the_road_decide_nothing() -> void:
	_start(1)
	var first := _junctions()[0]
	_leave(first, first.expected_exit, false)
	_leave(first, Heading.opposite(first.expected_exit), false)
	_assert_nothing_decided(first)


func test_crossings_from_other_tiles_decide_nothing() -> void:
	_start(1)
	var first := _junctions()[0]
	var before := _buffer.path_tile(first.path_index - 1)
	_trigger.on_cell_crossed(before.cell, first.cell, true)
	var after := _buffer.path_tile(first.path_index + 1)
	_trigger.on_cell_crossed(after.cell, after.cell + Heading.VEC[after.heading], true)
	var branch := first.branches[0]
	_trigger.on_cell_crossed(branch.cell, branch.cell + Heading.VEC[branch.branch_exit], true)
	_assert_nothing_decided(first)


func test_rejoining_on_a_dead_end_is_a_disaster() -> void:
	_start(1)
	var first := _junctions()[0]
	var tip: RoadTile = first.branches[-1]
	_trigger.on_rejoin(tip)
	assert_signal_emitted_with_parameters(_trigger, "disaster_triggered", [first, tip.branch_exit])
	assert_signal_not_emitted(_trigger, "turn_completed")
	assert_null(_trigger.next_junction)


func test_rejoining_past_the_junction_completes_the_turn() -> void:
	_start(1)
	var junctions := _junctions()
	_trigger.on_rejoin(_buffer.path_tile(junctions[0].path_index + 1))
	assert_signal_emitted_with_parameters(_trigger, "turn_completed", [1])
	assert_signal_not_emitted(_trigger, "disaster_triggered")
	assert_eq(_trigger.next_junction, junctions[1])


func test_rejoining_before_or_on_the_junction_decides_nothing() -> void:
	_start(1)
	var first := _junctions()[0]
	_trigger.on_rejoin(_buffer.path_tile(first.path_index - 1))
	_trigger.on_rejoin(first)
	_assert_nothing_decided(first)


func test_rejoining_past_two_junctions_completes_both_turns() -> void:
	_start(1)
	var junctions := _junctions()
	_trigger.on_rejoin(_buffer.path_tile(junctions[1].path_index + 1))
	assert_signal_emit_count(_trigger, "turn_completed", 2)
	assert_signal_emitted_with_parameters(_trigger, "turn_completed", [2])
	assert_eq(_trigger.next_junction, junctions[2])


func test_rejoining_past_a_decoy_counts_only_the_turns() -> void:
	_start_where(_of_kind(RoadGenerator.Kind.DECOY), Fixtures.kinds_schedule(0.25, 0.25, 0.25))
	var junctions := _junctions()
	var turns := 1 if junctions[1].is_turn() else 0
	_trigger.on_rejoin(_buffer.path_tile(junctions[1].path_index + 1))
	assert_signal_emit_count(_trigger, "turn_completed", 2)
	assert_signal_emitted_with_parameters(_trigger, "turn_completed", [turns])
	assert_eq(_trigger.turn_index, turns)
	assert_eq(_trigger.next_junction, junctions[2])
	assert_signal_not_emitted(_trigger, "disaster_triggered")


func test_rejoining_on_a_later_dead_end_completes_the_turn_then_fails() -> void:
	_start(1)
	var junctions := _junctions()
	var branch: RoadTile = junctions[1].branches[0]
	_trigger.on_rejoin(branch)
	assert_signal_emitted_with_parameters(_trigger, "turn_completed", [1])
	assert_signal_emitted_with_parameters(
		_trigger, "disaster_triggered", [junctions[1], branch.branch_exit]
	)


func test_the_offroad_limit_is_a_missed_turn() -> void:
	_start(1)
	var first := _junctions()[0]
	_trigger.on_offroad_limit()
	assert_signal_emitted_with_parameters(_trigger, "disaster_triggered", [first, -1])
	assert_null(_trigger.next_junction)


## On the game's road, and through every kind of junction, where decoys add junctions but no
## turns (docs/ROADGEN.md R2).
func test_finds_the_next_junction_for_300_turns() -> void:
	var kinds := Fixtures.kinds_schedule(0.25, 0.25, 0.25)
	for schedule: AreaSchedule in [Fixtures.schedule(), kinds]:
		_start(3, schedule)
		var junctions := 0
		while _trigger.turn_index < 300 and junctions < 1000:
			var junction := _trigger.next_junction
			if junction == null or not junction.is_junction():
				fail_test("no junction after %d junctions" % junctions)
				return
			_buffer.on_car_path_index(junction.path_index)
			_leave(junction, junction.expected_exit)
			junctions += 1
		assert_eq(_trigger.turn_index, 300)
		assert_signal_emit_count(_trigger, "turn_completed", junctions)
		assert_signal_not_emitted(_trigger, "disaster_triggered")
