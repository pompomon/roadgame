extends GutTest
## SkidMarks (M5_PLAN.md §5.7): the rear wheels mark the road, and not beside it, while the car
## brakes for a junction, and the marks go with their tiles, past the limit and with the run.

const Fixtures := preload("res://tests/helpers/road_fixtures.gd")
const DELTA := 1.0 / 60.0


class Drive:
	extends RefCounted
	var layer: Node2D
	var skids: SkidMarks
	var sim: CarSim
	var autopilot: Autopilot

	func _init(p_layer: Node2D, limit: int, run_seed: int) -> void:
		layer = p_layer
		skids = SkidMarks.new(layer, limit)
		var buffer := RoadBuffer.new(RoadGenerator.new(run_seed, Fixtures.schedule()))
		skids.bind(buffer)
		buffer.start()
		sim = CarSim.new(buffer)
		autopilot = Autopilot.new(sim)

	func braking() -> bool:
		return sim.state == CarSim.State.BRAKING and sim.speed > sim.target_speed()


func _drive(limit := Tuning.SKID_MARKS, run_seed := 1) -> Drive:
	return Drive.new(add_child_autofree(Node2D.new()), limit, run_seed)


## A tile of the buffer that runs straight north to south or east to west, or null.
static func _straight(buffer: RoadBuffer) -> RoadTile:
	var north_south := Heading.bit(Heading.N) | Heading.bit(Heading.S)
	var east_west := Heading.bit(Heading.E) | Heading.bit(Heading.W)
	for tile: RoadTile in buffer.tiles():
		if tile.exits == north_south or tile.exits == east_west:
			return tile
	return null


func test_the_rear_wheels_mark_the_road_only_while_the_car_brakes_for_a_junction() -> void:
	var drive := _drive()
	var laid := 0
	var braking_frames := 0
	var stray := 0
	var off_road := 0
	for _frame: int in 1800:
		drive.sim.step(DELTA, drive.autopilot.steer())
		var before := drive.skids.marks().size()
		drive.skids.update(drive.sim)
		var added := drive.skids.marks().size() - before
		laid += added
		if drive.braking():
			braking_frames += 1
		elif added > 0:
			stray += 1
		for mark: Sprite2D in drive.skids.marks():
			if drive.sim.buffer.tile_at(drive.skids.cell_of(mark)) == null:
				off_road += 1
	assert_gt(braking_frames, 0, "the car brakes for junctions")
	assert_gt(laid, 20, "marks")
	assert_eq(stray, 0, "marks laid while not braking")
	assert_eq(off_road, 0, "marks on cells the buffer doesn't have")


func test_a_wheel_over_the_roads_edge_leaves_no_mark() -> void:
	# R12: braking on a straight 0.3 tiles right of its centreline, the car is on the road, which
	# is ROAD_HALF_WIDTH (0.32) wide on each side, and its right rear wheel 0.09 further is not.
	var drive := _drive()
	var tile := _straight(drive.sim.buffer)
	assert_not_null(tile, "a straight")
	if tile == null:
		return
	var heading := Heading.N if tile.exits & Heading.bit(Heading.N) != 0 else Heading.E
	var forward := Vector2(Heading.VEC[heading])
	var right := Vector2(-forward.y, forward.x)
	var local := RoadGeometry.CENTRE + right * 0.3 + forward * 0.1
	var rear := local - forward * Tuning.SKID_REAR
	var wheel := right * Tuning.SKID_TRACK / 2.0
	assert_true(RoadGeometry.is_on_road(tile, local), "the car on the road")
	assert_true(RoadGeometry.is_on_road(tile, rear - wheel), "the left rear wheel on it")
	assert_false(RoadGeometry.is_on_road(tile, rear + wheel), "the right rear wheel over its edge")
	var origin := Vector2(tile.cell)
	drive.sim.pos = origin + local
	drive.sim.angle = atan2(forward.x, -forward.y)
	drive.sim.state = CarSim.State.BRAKING
	drive.sim.speed = drive.sim.target_speed() + 1.0
	drive.skids.update(drive.sim)
	var marks := drive.skids.marks()
	assert_eq(marks.size(), 1, "one mark")
	if marks.size() == 1:
		var at := Iso.tile_to_world(origin + rear - wheel)
		assert_almost_eq(marks[0].position, at, Vector2.ONE * 0.001, "the left wheel's")


func test_past_the_limit_the_oldest_marks_go_first() -> void:
	var drive := _drive(4)
	var newest: Array[Vector2] = []
	while newest.size() < 10:
		drive.sim.step(DELTA, drive.autopilot.steer())
		var before := drive.skids.marks()
		drive.skids.update(drive.sim)
		var after := drive.skids.marks()
		if after != before:
			newest.append(after[-2].position)
			newest.append(after[-1].position)
	assert_lte(drive.layer.get_child_count(), 4, "sprites")
	var kept: Array[Vector2] = []
	for mark: Sprite2D in drive.skids.marks():
		kept.append(mark.position)
	assert_eq(kept, newest.slice(-4), "the newest four")


func test_a_new_buffer_takes_the_marks_of_the_last() -> void:
	var drive := _drive()
	while drive.skids.marks().size() < 6:
		drive.sim.step(DELTA, drive.autopilot.steer())
		drive.skids.update(drive.sim)
	var sprites := drive.layer.get_child_count()
	drive.skids.bind(RoadBuffer.new(RoadGenerator.new(2, Fixtures.schedule())))
	assert_eq(drive.skids.marks().size(), 0, "no marks")
	for mark: Node2D in drive.layer.get_children():
		assert_false(mark.visible, "%s hidden" % mark.name)
	assert_eq(drive.layer.get_child_count(), sprites, "kept to use again")
