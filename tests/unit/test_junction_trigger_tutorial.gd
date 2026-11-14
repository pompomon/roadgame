extends GutTest
## JunctionTrigger in the tutorial (docs/TUTORIAL.md §5.2), on a real tutorial road, called the way
## CarSim calls it: a mistake ends the streak and loses the car, never the run; the car is found
## when it drives on along the path; and the streak's last turn ends the tutorial.

const Fixtures := preload("res://tests/helpers/road_fixtures.gd")

var _buffer: RoadBuffer
var _trigger: JunctionTrigger


func before_each() -> void:
	_buffer = RoadBuffer.new(RoadGenerator.new(1, Fixtures.schedule(), true))
	_buffer.start()
	_trigger = JunctionTrigger.new(_buffer)
	watch_signals(_trigger)


## The buffer's junctions, in path order.
func _junctions() -> Array[RoadTile]:
	var found: Array[RoadTile] = []
	for i: int in range(_buffer.first_index(), _buffer.last_index() + 1):
		if _buffer.path_tile(i).is_junction():
			found.append(_buffer.path_tile(i))
	return found


## The buffer's junction with turn number `turn`.
func _junction(turn: int) -> RoadTile:
	for junction: RoadTile in _junctions():
		if junction.turn_number == turn:
			return junction
	fail_test("no junction with turn %d in the buffer" % turn)
	return null


## Takes the correct exit of the next `count` junctions, each once the car has reached it.
func _take(count: int) -> void:
	for i: int in count:
		var junction := _trigger.next_junction
		_buffer.on_car_path_index(junction.path_index)
		_leave(junction, junction.expected_exit)


## Crosses from `junction` through its edge with heading `exit`.
func _leave(junction: RoadTile, exit: int, on_road := true) -> void:
	_trigger.on_cell_crossed(junction.cell, junction.cell + Heading.VEC[exit], on_road)


## Crosses on the road from each of `cells` into the next.
func _drive(cells: Array[Vector2i]) -> void:
	for k: int in range(1, cells.size()):
		_trigger.on_cell_crossed(cells[k - 1], cells[k], true)


## The cells from `junction` along the loop from its wrong exit, up to the path tile where the loop
## comes back: the junction two on.
func _loop(junction: RoadTile) -> Array[Vector2i]:
	var cells: Array[Vector2i] = [junction.cell]
	var step := Heading.opposite(junction.expected_exit)
	while cells.size() < 4 * Tuning.DEAD_END_MAX_TILES:
		cells.append(cells[-1] + Heading.VEC[step])
		var tile := _buffer.tile_at(cells[-1])
		if tile.path_index >= 0:
			return cells
		for h: int in Heading.VEC.size():
			if h != Heading.opposite(step) and tile.has_exit(h):
				step = h
				break
	fail_test("the loop from turn %d doesn't come back" % junction.turn_number)
	return cells


## The car is lost, the streak ended `resets` times, and the run goes on.
func _assert_lost(resets: int) -> void:
	assert_null(_trigger.next_junction, "lost")
	assert_eq(_trigger.streak, 0)
	assert_eq(_resets(), resets, "streak resets")
	assert_true(_trigger.tutorial)
	assert_signal_not_emitted(_trigger, "disaster_triggered")
	assert_signal_not_emitted(_trigger, "turn_completed")


## How many streak_changed signals ended the streak.
func _resets() -> int:
	var resets := 0
	for k: int in get_signal_emit_count(_trigger, "streak_changed"):
		if get_signal_parameters(_trigger, "streak_changed", k)[0] == 0:
			resets += 1
	return resets


func test_correct_turns_build_the_streak_but_count_no_turns() -> void:
	var junctions := _junctions()
	assert_true(_trigger.tutorial)
	assert_eq(_trigger.next_junction, junctions[0])
	_take(3)
	assert_eq(_trigger.streak, 3)
	assert_signal_emit_count(_trigger, "streak_changed", 3)
	assert_signal_emitted_with_parameters(_trigger, "streak_changed", [3])
	assert_eq(_trigger.next_junction, junctions[3])
	assert_signal_not_emitted(_trigger, "turn_completed")
	assert_eq(_trigger.turn_index, 0)


func test_the_streak_ends_the_tutorial_and_the_city_rules_follow() -> void:
	_take(Tuning.TUTORIAL_STREAK - 1)
	assert_signal_not_emitted(_trigger, "tutorial_completed")
	var last := _trigger.next_junction
	_take(1)
	assert_signal_emitted_with_parameters(_trigger, "tutorial_completed", [last])
	assert_false(_trigger.tutorial)
	assert_signal_not_emitted(_trigger, "turn_completed")
	_take(1)
	assert_signal_emitted_with_parameters(_trigger, "turn_completed", [1])
	var junction := _trigger.next_junction
	var wrong := Heading.opposite(junction.expected_exit)
	_leave(junction, wrong)
	assert_signal_emitted_with_parameters(_trigger, "disaster_triggered", [junction, wrong])
	assert_eq(_trigger.streak, Tuning.TUTORIAL_STREAK, "the streak ends no more")


func test_a_wrong_exit_ends_the_streak_and_loses_the_car() -> void:
	_take(2)
	var junction := _trigger.next_junction
	_leave(junction, Heading.opposite(junction.expected_exit))
	_assert_lost(1)


func test_the_loop_finds_the_car_after_the_junction_two_on() -> void:
	var junctions := _junctions()
	_drive(_loop(junctions[0]))
	_assert_lost(0)
	assert_eq(_buffer.tile_at(_loop(junctions[0])[-1]), junctions[2])
	_leave(junctions[2], junctions[2].expected_exit)
	assert_eq(_trigger.next_junction, junctions[3], "found, but its turn doesn't count")
	assert_signal_not_emitted(_trigger, "streak_changed")
	_take(1)
	assert_eq(_trigger.streak, 1)


func test_a_u_turn_ends_the_streak() -> void:
	_take(1)
	var tile := _buffer.path_tile(_junctions()[1].path_index - 1)
	var back := _buffer.path_tile(tile.path_index - 1)
	_trigger.on_cell_crossed(tile.cell, back.cell, true)
	_assert_lost(1)
	_trigger.on_cell_crossed(back.cell, tile.cell, true)
	assert_eq(_trigger.next_junction, _junctions()[1], "found again")


func test_going_back_out_of_a_junction_ends_the_streak() -> void:
	_take(1)
	var junction := _trigger.next_junction
	_leave(junction, Heading.opposite(junction.heading))
	_assert_lost(1)


func test_the_offroad_limit_ends_the_streak() -> void:
	_take(1)
	_trigger.on_offroad_limit()
	_assert_lost(1)


func test_a_rejoin_off_the_path_ends_the_streak() -> void:
	_take(1)
	_trigger.on_rejoin(_trigger.next_junction.branches[0])
	_assert_lost(1)


func test_a_rejoin_past_the_junction_counts_its_turn() -> void:
	var junctions := _junctions()
	_trigger.on_rejoin(_buffer.path_tile(junctions[0].path_index + 1))
	assert_eq(_trigger.streak, 1)
	assert_eq(_trigger.next_junction, junctions[1])


func test_only_driving_on_along_the_path_finds_the_lost_car() -> void:
	var junctions := _junctions()
	_trigger.on_offroad_limit()
	var after := _buffer.path_tile(junctions[0].path_index + 1)
	_trigger.on_rejoin(after)
	var onward := _buffer.path_tile(after.path_index + 1)
	_trigger.on_cell_crossed(after.cell, onward.cell, false)
	_trigger.on_cell_crossed(onward.cell, after.cell, true)
	_trigger.on_cell_crossed(junctions[0].branches[0].cell, junctions[0].cell, true)
	_assert_lost(0)
	_trigger.on_cell_crossed(after.cell, onward.cell, true)
	assert_eq(_trigger.next_junction, junctions[1])


func test_a_rescue_ends_the_streak_and_finds_the_car_on_its_tile() -> void:
	_take(2)
	var junctions := _junctions()
	_trigger.on_rescued(_buffer.path_tile(junctions[1].path_index - 1))
	assert_eq(_trigger.streak, 0)
	assert_eq(_resets(), 1)
	assert_eq(_trigger.next_junction, junctions[1])
	assert_signal_not_emitted(_trigger, "disaster_triggered")


## After a tutorial whose last turn starts a loop, a car that turns back and drives that loop comes
## back past the next junction: a missed turn. A loop that comes back before it decides nothing.
func test_after_the_tutorial_a_loop_past_the_next_junction_is_a_missed_turn() -> void:
	# The streak starts at the junction that makes its last turn the first of a group of four.
	var first := posmod(1 - Tuning.TUTORIAL_STREAK, 4)
	_trigger.on_rescued(_buffer.path_tile(_junctions()[first].path_index - 1))
	_take(Tuning.TUTORIAL_STREAK)
	var last: RoadTile = get_signal_parameters(_trigger, "tutorial_completed")[0]
	assert_eq(last.turn_number % 4, 0, "the streak ended where a loop starts")
	_drive(_loop(_junction(last.turn_number - 3)))
	assert_signal_not_emitted(_trigger, "disaster_triggered")
	var next := _trigger.next_junction
	_drive(_loop(last))
	assert_signal_emitted_with_parameters(_trigger, "disaster_triggered", [next, -1])
