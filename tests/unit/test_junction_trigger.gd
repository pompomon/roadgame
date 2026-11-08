extends GutTest
## JunctionTrigger on a real road buffer, called the way CarSim calls it.

const Fixtures := preload("res://tests/helpers/road_fixtures.gd")

var _buffer: RoadBuffer
var _trigger: JunctionTrigger


func _start(run_seed: int) -> void:
	_buffer = RoadBuffer.new(RoadGenerator.new(run_seed, Fixtures.schedule()))
	_buffer.start()
	_restart()


## A new trigger on the same buffer, which starts again at the first junction.
func _restart() -> void:
	_trigger = JunctionTrigger.new(_buffer)
	watch_signals(_trigger)


## Starts the first seed whose first junction passes `check`, and returns that junction.
func _start_where(check: Callable) -> RoadTile:
	for run_seed: int in range(1, 100):
		_start(run_seed)
		if check.call(_junctions()[0]):
			return _junctions()[0]
	fail_test("no seed from 1 to 99 has such a first junction")
	return null


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


func test_every_wrong_exit_of_a_crossroads_is_a_disaster() -> void:
	var cross := _start_where(
		func(j: RoadTile) -> bool: return j.type == RoadTile.Type.CROSS_JUNCTION
	)
	for exit: int in [Heading.opposite(cross.expected_exit), cross.heading]:
		_restart()
		_leave(cross, exit)
		assert_signal_emitted_with_parameters(_trigger, "disaster_triggered", [cross, exit])
		assert_signal_not_emitted(_trigger, "turn_completed")
		assert_null(_trigger.next_junction)
		assert_eq(_trigger.turn_index, 0)


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


func test_finds_the_next_junction_for_300_turns() -> void:
	_start(3)
	for turn: int in 300:
		var junction := _trigger.next_junction
		if junction == null or not junction.is_junction():
			fail_test("no junction after turn %d" % turn)
			return
		_buffer.on_car_path_index(junction.path_index)
		_leave(junction, junction.expected_exit)
	assert_eq(_trigger.turn_index, 300)
	assert_signal_not_emitted(_trigger, "disaster_triggered")
