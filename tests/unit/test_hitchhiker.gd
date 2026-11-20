extends GutTest
## The Vanishing Hitchhiker (docs/ENDGAME.md §5.17, E15) on her own: she shows only on the Road
## Home, with every legend of the pools collected, until a run finds her; she stands by the last
## plain straight before the junction of the player's farthest turn there, or before its finish once
## they have arrived home, on the road's far side, facing it; the car's passing finds her, while the
## run goes on, and she fades away. She is in no pool, so an arrival never unlocks her, and her art
## stands out by night beside each area of the Road Home.

const Fixtures := preload("res://tests/helpers/road_fixtures.gd")
const Art := preload("res://tests/helpers/art_checks.gd")
const LegendArt := preload("res://tools/art/legend_art.gd")
const HITCHHIKER := preload("res://world/hitchhiker.tscn")
const DELTA := 1.0 / 60.0
const SEED := 1
## A turn that set_piece_schedule()'s second area never comes before, and a finish that no road of
## these tests reaches.
const NEVER := 99
## How near to 0 her place's offset along the road must be, in tiles.
const NEAR := 1e-5


## Fixtures.set_piece_schedule()'s road with one area: its straights are 3 tiles long, so that
## junction k is path tile 4 + 4k, and the straight before it ends at 3 + 4k.
static func _road() -> AreaSchedule:
	return Fixtures.set_piece_schedule(NEVER, &"", 0)


static func _buffer(schedule: AreaSchedule) -> RoadBuffer:
	var buffer := RoadBuffer.new(RoadGenerator.new(SEED, schedule))
	buffer.start()
	return buffer


## Her scene, in the tree, watching `buffer` for her place before turn `turn` of a road that ends
## after `finish_turn` turns.
func _watching(buffer: RoadBuffer, turn: int, finish_turn := NEVER) -> Hitchhiker:
	var hitchhiker: Hitchhiker = HITCHHIKER.instantiate()
	add_child_autofree(hitchhiker)
	hitchhiker.watch(buffer, turn, finish_turn)
	return hitchhiker


## Her, standing by path tile 3, before turn 0's junction, with a car on her road.
func _standing() -> Hitchhiker:
	var buffer := _buffer(_road())
	var hitchhiker := _watching(buffer, 0)
	hitchhiker.sim = CarSim.new(buffer)
	return hitchhiker


func test_she_shows_only_on_the_road_home_with_the_pools_collected_until_she_is_found() -> void:
	var schedule := Fixtures.schedule()
	var data := SaveData.new()
	assert_false(Hitchhiker.shows(data, Hitchhiker.ROAD, schedule), "a new save")
	var none: Array[StringName] = []
	var legends := LegendUnlock.locked(schedule, none)
	for id: StringName in legends.slice(0, legends.size() - 1):
		data.unlock_disaster(id)
	assert_false(Hitchhiker.shows(data, Hitchhiker.ROAD, schedule), "a legend missing")
	data.record_disaster(legends[-1], &"desert", {})
	assert_true(Hitchhiker.shows(data, Hitchhiker.ROAD, schedule), "seen or unlocked, every one")
	assert_eq(Fixtures.schedule_home().finish, Hitchhiker.ROAD, "the Road Home's finish")
	assert_false(Hitchhiker.shows(data, schedule.finish, schedule), "not on the road to the sea")
	assert_false(Hitchhiker.shows(data, &"", schedule), "nor on Keep Driving's")
	data.record_disaster(Hitchhiker.ID, &"desert", {})
	assert_false(Hitchhiker.shows(data, Hitchhiker.ROAD, schedule), "found")


func test_her_turn_is_the_players_farthest_on_the_road_home_or_its_finish_once_home() -> void:
	var data := SaveData.new()
	assert_eq(Hitchhiker.road_turn(data, 280), 0, "a new save: the first junction")
	data.record_run({"road": Hitchhiker.ROAD, "turn_index": 7})
	data.record_run({"road": Hitchhiker.ROAD, "turn_index": 3})
	assert_eq(Hitchhiker.road_turn(data, 280), 7, "the first junction that no run has passed")
	assert_eq(Hitchhiker.road_turn(data, 5), 5, "no farther than the finish")
	data.record_run({"road": &"pier", "turn_index": 40})
	data.record_arrival(&"pier", {"seconds": 900.0, "turn_index": 50})
	assert_eq(Hitchhiker.road_turn(data, 280), 7, "the road to the sea's runs count for none")
	# An arrival on --finish's road of 9 turns, whose farthest is 9: home all the same.
	data.record_arrival(Hitchhiker.ROAD, {"seconds": 90.0, "turn_index": 9})
	assert_eq(Hitchhiker.road_turn(data, 280), 280, "once home, by the finish")


func test_she_stands_by_the_last_straight_before_her_turns_junction() -> void:
	for turn: int in [0, 2]:
		var buffer := _buffer(_road())
		var hitchhiker := _watching(buffer, turn)
		var junction := buffer.path_tile(4 + 4 * turn)
		assert_true(
			junction.is_turn() and junction.turn_number == turn, "turn %d's junction" % turn
		)
		assert_eq(hitchhiker.index, 3 + 4 * turn, "turn %d" % turn)
		assert_eq(buffer.path_tile(hitchhiker.index).type, RoadTile.Type.STRAIGHT)
		assert_true(hitchhiker.visible, "turn %d" % turn)
		assert_eq(hitchhiker.modulate.a, 1.0)


func test_a_place_past_the_buffer_waits_until_the_buffer_lays_it() -> void:
	var buffer := _buffer(_road())
	var hitchhiker := _watching(buffer, 20)
	assert_lt(buffer.last_index(), 84, "turn 20's junction, path tile 84, isn't laid yet")
	assert_eq(hitchhiker.index, -1)
	assert_false(hitchhiker.visible)
	buffer.on_car_path_index(40)
	assert_eq(hitchhiker.index, 83)
	assert_true(hitchhiker.visible)


func test_at_the_finish_she_stands_by_the_last_straight_before_it() -> void:
	# The road ends after junctions 0 to 2, at path tiles 4, 8 and 12, and straights 13 to 15.
	var schedule := _road().ending_at(3, Hitchhiker.ROAD)
	for turn: int in [3, 5]:
		var buffer := _buffer(schedule)
		var hitchhiker := _watching(buffer, turn, 3)
		assert_eq(buffer.generator.finish_index, 16)
		assert_eq(hitchhiker.index, 15, "turn %d" % turn)
		assert_true(hitchhiker.visible)


func test_a_finish_past_the_buffer_waits_until_the_buffer_lays_it_not_by_a_dead_end() -> void:
	# The road ends after junctions 0 to 19, at path tiles 4 to 80, and straights 81 to 83. Until
	# the finish is laid, its index is -1, as each dead end's path index is.
	var buffer := _buffer(_road().ending_at(20, Hitchhiker.ROAD))
	var hitchhiker := _watching(buffer, 20, 20)
	assert_eq(buffer.generator.finish_index, -1, "the finish isn't laid yet")
	assert_false(buffer.path_tile(4).branches.is_empty(), "junction 0 has a dead end")
	assert_eq(hitchhiker.index, -1)
	assert_false(hitchhiker.visible)
	buffer.on_car_path_index(40)
	assert_eq(buffer.generator.finish_index, 84)
	assert_eq(hitchhiker.index, 83)
	assert_true(hitchhiker.visible)


func test_she_stands_before_her_turns_junction_not_before_a_decoy_with_its_number() -> void:
	# A decoy's correct exit is straight on: it has the number of the turn after it, but it isn't
	# that turn's junction (docs/ROADGEN.md R1).
	var buffer := _buffer(Fixtures.kinds_schedule(0.0, 0.0, 0.5))
	var decoy: RoadTile = null
	var junction: RoadTile = null
	for index: int in range(buffer.first_index(), buffer.last_index() + 1):
		var tile := buffer.path_tile(index)
		if decoy == null and tile.is_junction() and not tile.is_turn():
			decoy = tile
		elif decoy != null and tile.is_turn():
			junction = tile
			break
	assert_not_null(junction, "a decoy, then a turn")
	if junction == null:
		return
	assert_eq(decoy.turn_number, junction.turn_number)
	var hitchhiker := _watching(buffer, junction.turn_number)
	var last := junction.path_index - 1
	while buffer.path_tile(last).type != RoadTile.Type.STRAIGHT:
		last -= 1
	assert_gt(last, decoy.path_index, "a straight between them")
	assert_eq(hitchhiker.index, last)


func test_she_never_stands_by_a_pit_stop() -> void:
	# The second area's way in, after junction 1, is a pit stop: straights 9 to 11 (docs/ENDGAME.md
	# §5.15). She stands by the straight before junction 1 instead.
	var schedule := Fixtures.set_piece_schedule(2, &"", 0)
	schedule.entries[1].pit_stop = true
	var buffer := _buffer(schedule)
	assert_true(buffer.path_tile(11).pit_stop, "the straight before junction 2")
	assert_eq(_watching(buffer, 2).index, 7)


func test_a_place_with_no_plain_straight_before_it_is_an_error() -> void:
	# Every road starts with plain straights: only a buffer that has freed them has none.
	var buffer := _buffer(_road())
	buffer.on_car_path_index(40)
	assert_eq(buffer.first_index(), 20, "turn 4's junction is the buffer's first tile")
	var hitchhiker := _watching(buffer, 4)
	assert_push_error("no plain straight before path tile 20")
	assert_eq(hitchhiker.index, -1)
	assert_false(hitchhiker.visible)


func test_she_stands_on_the_roads_far_side_facing_it() -> void:
	# Off the road, across from her straight's centre, and behind it on the screen. Her art holds her
	# thumb out to the screen's right, so she is flipped right of the road.
	var buffer := _buffer(_road())
	var headings: Dictionary[int, bool] = {}
	for turn: int in 12:
		var hitchhiker := _watching(buffer, turn)
		var tile := buffer.path_tile(hitchhiker.index)
		var what := "turn %d, heading %s" % [turn, Heading.NAMES[tile.heading]]
		headings[tile.heading] = true
		var centre := Iso.cell_centre(tile.cell)
		var aside := Iso.world_to_tile(hitchhiker.position) - centre
		assert_almost_eq(aside.dot(Vector2(Heading.VEC[tile.heading])), 0.0, NEAR, what)
		assert_between(aside.length(), Tuning.ROAD_HALF_WIDTH, 0.5, what + ": by the road")
		var drawn := Iso.tile_to_world(centre)
		assert_lt(hitchhiker.position.y, drawn.y, what + ": on the far side")
		assert_eq(hitchhiker.flip_h, hitchhiker.position.x > drawn.x, what + ": facing the road")
	var up := headings.has(Heading.N) or headings.has(Heading.S)
	var across := headings.has(Heading.E) or headings.has(Heading.W)
	assert_true(up and across, "both ways: headings %s" % [headings.keys()])


func test_the_car_passing_her_finds_her_once_and_she_fades_away() -> void:
	var hitchhiker := _standing()
	watch_signals(hitchhiker)
	for progress: float in [0.0, 2.9, 3.0]:
		hitchhiker.sim.progress = progress
		simulate(hitchhiker, 1, DELTA)
		assert_signal_not_emitted(hitchhiker, "passed", "the car at %.1f" % progress)
	assert_eq(hitchhiker.modulate.a, 1.0, "she stands")
	hitchhiker.sim.progress = 3.01
	simulate(hitchhiker, 1, DELTA)
	assert_signal_emit_count(hitchhiker, "passed", 1, "past the centre of her straight")
	var half := roundi(Tuning.HITCHHIKER_FADE_SECONDS / 2.0 / DELTA)
	simulate(hitchhiker, half, DELTA)
	assert_almost_eq(hitchhiker.modulate.a, 0.5, 0.01, "half faded")
	assert_true(hitchhiker.visible)
	simulate(hitchhiker, half - 1, DELTA)
	assert_true(hitchhiker.visible, "until the fade's last frame")
	# One frame more for the float sum, which may fall short.
	simulate(hitchhiker, 2, DELTA)
	assert_false(hitchhiker.visible, "gone")
	assert_false(hitchhiker.is_physics_processing())
	assert_signal_emit_count(hitchhiker, "passed", 1, "once")


func test_a_run_that_is_over_never_finds_her() -> void:
	for state: CarSim.State in [CarSim.State.DISASTER, CarSim.State.CRASHED, CarSim.State.ARRIVED]:
		var hitchhiker := _standing()
		watch_signals(hitchhiker)
		hitchhiker.sim.state = state
		hitchhiker.sim.progress = 10.0
		simulate(hitchhiker, 2, DELTA)
		assert_signal_not_emitted(hitchhiker, "passed", CarSim.State.keys()[state])
		assert_true(hitchhiker.visible, CarSim.State.keys()[state])


func test_before_she_stands_no_car_finds_her() -> void:
	var buffer := _buffer(_road())
	var hitchhiker := _watching(buffer, 20)
	hitchhiker.sim = CarSim.new(buffer)
	hitchhiker.sim.progress = 50.0
	watch_signals(hitchhiker)
	simulate(hitchhiker, 2, DELTA)
	assert_signal_not_emitted(hitchhiker, "passed")


func test_she_is_in_no_pool_so_no_arrival_unlocks_her() -> void:
	var none: Array[StringName] = []
	for schedule: AreaSchedule in [Fixtures.schedule(), Fixtures.schedule_home()]:
		var legends := LegendUnlock.locked(schedule, none)
		assert_gt(legends.size(), 0)
		assert_does_not_have(legends, Hitchhiker.ID)
		assert_eq(LegendUnlock.pick(schedule, legends, SEED), &"", "every legend: none to unlock")


func test_her_art_is_one_frame_that_stands_out_by_night_beside_the_road_home() -> void:
	# As each legend's figure does (docs/POOLS.md §5.6), in each area's key lights, with no veil.
	var hitchhiker: Hitchhiker = autofree(HITCHHIKER.instantiate())
	var image := hitchhiker.texture.get_image()
	assert_string_starts_with(hitchhiker.texture.resource_path, "res://assets/legends/hitchhiker/")
	assert_eq(Vector2i(image.get_size()), Hitchhiker.FRAME)
	assert_eq([hitchhiker.hframes, hitchhiker.vframes], [1, 1])
	assert_lte(Hitchhiker.FRAME.x, LegendArt.MAX_FRAME.x)
	assert_lte(Hitchhiker.FRAME.y, LegendArt.MAX_FRAME.y)
	var feet := Vector2(-Hitchhiker.FRAME.x / 2.0, -Hitchhiker.FRAME.y)
	assert_eq([hitchhiker.centered, hitchhiker.offset], [false, feet], "her feet where she stands")
	for area: AreaDef in Fixtures.schedule_home().areas():
		var share := Art.night_share(image, 1, area, Legend.Veil.NONE)
		var what := "%s: %.0f%% of her pixels stand out" % [area.id, share * 100.0]
		assert_gte(share, Art.NIGHT_SHARE, what)
