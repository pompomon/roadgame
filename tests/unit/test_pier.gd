extends GutTest
## The ends of the road (ENDGAME_PLAN.md §5.8, E7). The pier: a deck on the finish's tiles, on piles
## and between railings, and the sea over every cell at or past its first tile, out past the view's
## edge, with waves that roll in to the shore; on an arrival, the legends collected welcome the car
## over the sea past its end. Home, the Road Home's end: a fence across the drive's end, with a
## gate, and a house past it.

const Fixtures := preload("res://tests/helpers/road_fixtures.gd")
const PIER := preload("res://setpieces/pier.tscn")
const HOME := preload("res://setpieces/home.tscn")
const DELTA := 1.0 / 60.0
const FIRST := Vector2i(10, 20)
const HEADINGS: Array[int] = [Heading.N, Heading.W]
## How far apart, in screen pixels, the points are that sample the view around each of the pier's
## cells.
const SAMPLE_PX := 128.0


func _piece(scene: PackedScene, heading: int) -> SetPiece:
	var piece: SetPiece = add_child_autofree(scene.instantiate())
	piece.setup(_tile(FIRST, heading), Tuning.FINISH_TILES)
	return piece


static func _tile(cell: Vector2i, heading: int) -> RoadTile:
	var exits := Heading.bit(heading) | Heading.bit(Heading.opposite(heading))
	return RoadTile.new(cell, RoadTile.Type.SET_PIECE, heading, exits)


## The tile-space points of `polygon`'s first `count` points, or all of them.
static func _points(polygon: Polygon2D, count := -1) -> Array[Vector2]:
	var points: Array[Vector2] = []
	for point: Vector2 in polygon.polygon.slice(0, count if count >= 0 else polygon.polygon.size()):
		points.append(Iso.world_to_tile(point + polygon.position))
	return points


## The tile-space rectangle that `polygon`'s points span.
static func _span(polygon: Polygon2D) -> Rect2:
	var points := _points(polygon)
	var spanned := Rect2(points[0], Vector2.ZERO)
	for point: Vector2 in points:
		spanned = spanned.expand(point)
	return spanned


func test_the_sea_lies_past_the_shore_where_the_pier_begins() -> void:
	var length := float(Tuning.FINISH_TILES)
	var out := length + Pier.SEA_REACH
	var reach := Pier.SEA_REACH + 0.5
	var north := _piece(PIER, Heading.N) as Pier
	# The first tile is (10, 20): its back edge, the shore, is y 21, and the pier heads up from it.
	assert_eq(north.water, Rect2(10.5 - reach, 21.0 - out, reach * 2.0, out))
	var west := _piece(PIER, Heading.W) as Pier
	assert_eq(west.water, Rect2(11.0 - out, 20.5 - reach, out, reach * 2.0))
	for pier: Pier in [north, west]:
		var run := Heading.NAMES[pier.heading]
		var drawn := _span(pier.get_node("%Sea") as Polygon2D)
		var within := Vector2.ONE * 1e-3
		assert_almost_eq(drawn.position, pier.water.position, within, "%s: drawn" % run)
		assert_almost_eq(drawn.end, pier.water.end, within, "%s: drawn" % run)
		var foam := _span(pier.get_node("%Foam") as Polygon2D)
		var shore := pier.point(0.0, 0.0).dot(pier.forward())
		assert_almost_eq(foam.get_center().dot(pier.forward()), shore + Pier.FOAM_WIDTH / 2, 1e-3)
		assert_true(pier.water.encloses(foam.grow(-1e-3)), "%s: the foam is on the sea" % run)


func test_the_sea_covers_every_cell_at_sea_as_far_as_the_ground_reaches() -> void:
	# Each part of the world that a view near the pier can show: the ground reaches GROUND_MARGIN
	# pixels each way past the road (WorldRenderer). There, the sea covers the cells at sea, and
	# only them.
	var margin := WorldRenderer.GROUND_MARGIN
	var steps := roundi(margin / SAMPLE_PX)
	for heading: int in HEADINGS:
		var pier := _piece(PIER, heading) as Pier
		var first := _tile(FIRST, heading)
		var wrong := PackedStringArray()
		var at_sea := 0
		for k: int in Tuning.FINISH_TILES:
			var cell := FIRST + Heading.VEC[heading] * k
			var centre := Iso.tile_to_world(Iso.cell_centre(cell))
			for i: int in range(-steps, steps + 1):
				for j: int in range(-steps, steps + 1):
					var point := Iso.world_to_tile(centre + Vector2(i, j) * SAMPLE_PX)
					var sea := Pier.at_sea(Vector2i(point.floor()), first)
					at_sea += 1 if sea else 0
					if pier.water.has_point(point) != sea:
						wrong.append("%s from %s: %s" % [Vector2(i, j) * SAMPLE_PX, cell, sea])
		var run := Heading.NAMES[heading]
		assert_gt(at_sea, 0, run)
		assert_eq(wrong.slice(0, 3), PackedStringArray(), "%s: %d wrong" % [run, wrong.size()])


func test_at_sea_is_every_cell_at_or_past_the_piers_first_tile() -> void:
	for heading: int in HEADINGS:
		var first := _tile(FIRST, heading)
		var ahead := Heading.VEC[heading]
		var across := Vector2i(ahead.y, ahead.x)
		var run := Heading.NAMES[heading]
		for k: int in Tuning.FINISH_TILES:
			assert_true(Pier.at_sea(FIRST + ahead * k, first), "%s: the pier's tile %d" % [run, k])
		assert_true(Pier.at_sea(FIRST + across * 30, first), "%s: along the shore" % run)
		assert_true(Pier.at_sea(FIRST + ahead * 60 - across * 9, first), "%s: far out" % run)
		assert_false(Pier.at_sea(FIRST - ahead, first), "%s: the road before it" % run)
		assert_false(Pier.at_sea(FIRST - ahead - across * 30, first), "%s: the beach" % run)


func test_the_deck_stands_on_piles_between_railings_out_to_its_end() -> void:
	var length := float(Tuning.FINISH_TILES)
	for heading: int in HEADINGS:
		var pier := _piece(PIER, heading) as Pier
		var run := Heading.NAMES[heading]
		var within := Vector2.ONE * 1e-3
		var deck := _span(pier.get_node("%Deck") as Polygon2D)
		var planks := pier.grown(Pier.DECK_HALF_WIDTH - 0.5, 0.0)
		assert_almost_eq(deck.position, planks.position, within, "%s: the deck" % run)
		assert_almost_eq(deck.end, planks.end, within, "%s: the deck" % run)
		var railings := {
			&"FarRailing": [pier.point(0.0, -Pier.RAILING), pier.point(length, -Pier.RAILING)],
			&"NearRailing": [pier.point(0.0, Pier.RAILING), pier.point(length, Pier.RAILING)],
			&"EndRailing": [pier.point(length, -Pier.RAILING), pier.point(length, Pier.RAILING)],
		}
		for railing: StringName in railings:
			var base := _points(pier.get_node("%" + railing) as Polygon2D, 2)
			assert_almost_eq(base[0], railings[railing][0], within, "%s: %s" % [run, railing])
			assert_almost_eq(base[1], railings[railing][1], within, "%s: %s" % [run, railing])
		# The fascia hangs from the deck's near edge, from the shore to the end.
		var fascia := (pier.get_node("%Fascia") as Polygon2D).polygon
		var edge := pier.point(0.0, Pier.DECK_HALF_WIDTH)
		assert_almost_eq(Iso.world_to_tile(fascia[3]), edge, within, "%s: the fascia" % run)
		edge = pier.point(length, Pier.DECK_HALF_WIDTH)
		assert_almost_eq(Iso.world_to_tile(fascia[2]), edge, within, "%s: the fascia" % run)
		var drop := Vector2(0.0, Pier.FASCIA_PX)
		assert_almost_eq(fascia[0] - fascia[3], drop, within, "%s: below it" % run)
		var piles: Array[Node] = pier.get_node("%Piles").get_children()
		assert_eq(piles.size(), Tuning.FINISH_TILES, "%s: a pile under each tile" % run)
		for k: int in piles.size():
			var at := Iso.world_to_tile((piles[k] as Node2D).position)
			var under := pier.point(k + 0.5, Pier.DECK_HALF_WIDTH)
			assert_almost_eq(at, under, within, "%s: pile %d" % [run, k])


func test_the_deck_draws_over_the_sea_and_its_near_railing_over_the_car() -> void:
	# The car is under World/Props at z 0 (docs/M3.md J5), and the pier under World/SetPieces, below
	# the road.
	var pier := _piece(PIER, Heading.N)
	assert_eq(pier.z_index, 0)
	for node: Node in pier.get_children():
		var expected := 1 if node.name == &"NearRailing" else 0
		assert_eq((node as Node2D).z_index, expected, node.name)
	var order: Array[StringName] = []
	for node: Node in pier.get_children():
		order.append(node.name)
	assert_eq(order.slice(0, 3), [&"Sea", &"Foam", &"Waves"] as Array[StringName], "the sea first")
	assert_gt(order.find(&"Deck"), order.find(&"Piles"), "the deck over its piles")
	assert_gt(order.find(&"Deck"), order.find(&"Fascia"), "and its fascia")


func test_the_waves_roll_in_to_the_shore_and_fade_in() -> void:
	for heading: int in HEADINGS:
		var pier := _piece(PIER, heading) as Pier
		var run := Heading.NAMES[heading]
		var count := pier.get_node("%Waves").get_child_count()
		assert_eq(count, 2 * Pier.LANES_PER_SIDE * Pier.WAVES_PER_LANE)
		var reach := Pier.SEA_REACH + 0.5
		var surf := pier.span(0.0, Pier.SURF_REACH, -reach, reach).grow(1e-4)
		var foam := pier.span(0.0, Pier.FOAM_WIDTH, -reach, reach).grow(1e-4)
		var deck := pier.grown(Pier.DECK_HALF_WIDTH - 0.5, 0.0)
		var wrong := PackedStringArray()
		var nearest := INF
		var farthest := -INF
		var restarts := 0
		var brightest_restart := 0.0
		for frame: int in ceili(Pier.SURF_REACH / Tuning.WAVE_SPEED / DELTA) + 1:
			var time := frame * DELTA
			for index: int in count:
				var wave := pier.wave_rect(index, time)
				var out := pier.wave_out(index, time)
				var next_out := pier.wave_out(index, time + DELTA)
				nearest = minf(nearest, out)
				farthest = maxf(farthest, out + Pier.WAVE_WIDTH)
				if not surf.encloses(wave):
					wrong.append("wave %d at %.2f s: off the surf" % [index, time])
				if wave.intersects(deck):
					wrong.append("wave %d at %.2f s: on the deck" % [index, time])
				if next_out < out:
					if pier.wave_alpha(index, time + DELTA) <= pier.wave_alpha(index, time):
						wrong.append("wave %d at %.2f s: fades as it comes in" % [index, time])
					continue
				# It reached the shore, under the foam, and starts again out at sea, faint.
				restarts += 1
				var alpha := pier.wave_alpha(index, time + DELTA)
				brightest_restart = maxf(brightest_restart, alpha)
				if not foam.encloses(wave):
					wrong.append("wave %d at %.2f s: starts again off the shore" % [index, time])
		assert_eq(wrong.slice(0, 3), PackedStringArray(), "%s: %d wrong" % [run, wrong.size()])
		var step := Tuning.WAVE_SPEED * DELTA
		assert_almost_eq(nearest, 0.0, step, "%s: in to the shore" % run)
		assert_almost_eq(farthest, Pier.SURF_REACH, step, "%s: from the surf's edge" % run)
		assert_gte(restarts, count, "%s: each wave starts again" % run)
		assert_lt(brightest_restart, 0.05, "%s: faint where it starts" % run)


func test_no_two_waves_of_a_lane_or_of_lanes_side_by_side_line_up() -> void:
	# A lane's waves never touch, and lanes side by side roll in out of step, so that the surf
	# never lines up into one long wave: each lane's neighbour on its side of the pier, and the lane
	# across the pier from it.
	var pier := _piece(PIER, Heading.W) as Pier
	var lanes := 2 * Pier.LANES_PER_SIDE
	var room := Pier.SURF_REACH - Pier.WAVE_WIDTH
	var closest := INF
	for frame: int in ceili(room / Tuning.WAVE_SPEED / DELTA):
		var time := frame * DELTA
		for lane: int in lanes:
			var others: Array[int] = [lane]
			if lane + 2 < lanes:
				others.append(lane + 2)
			if lane % 2 == 0:
				others.append(lane + 1)
			for a: int in Pier.WAVES_PER_LANE:
				var out := pier.wave_out(lane * Pier.WAVES_PER_LANE + a, time)
				for other: int in others:
					for b: int in Pier.WAVES_PER_LANE:
						if other != lane or b > a:
							var beside := pier.wave_out(other * Pier.WAVES_PER_LANE + b, time)
							closest = minf(closest, absf(out - beside))
	assert_gt(closest, Pier.WAVE_WIDTH)
	for lane: int in lanes:
		var inner := absf(pier.lane_centre(lane)) - Pier.WAVE_LENGTH / 2
		assert_gt(inner, Pier.DECK_HALF_WIDTH, "lane %d is off the deck" % lane)


func test_each_wave_is_drawn_where_its_rectangle_is() -> void:
	for heading: int in HEADINGS:
		var pier := _piece(PIER, heading) as Pier
		var run := Heading.NAMES[heading]
		simulate(pier, 90, DELTA)
		var waves: Array[Node] = pier.get_node("%Waves").get_children()
		for index: int in waves.size():
			var wave := waves[index] as Polygon2D
			var drawn := _span(wave)
			var expected := pier.wave_rect(index, 90 * DELTA)
			var where := "%s: wave %d" % [run, index]
			assert_almost_eq(drawn.position, expected.position, Vector2.ONE * 1e-3, where)
			assert_almost_eq(drawn.size, expected.size, Vector2.ONE * 1e-3, where + "'s size")
			assert_almost_eq(wave.self_modulate.a, pier.wave_alpha(index, 90 * DELTA), 1e-4, where)


func test_the_pier_is_never_redrawn() -> void:
	# The waves move and fade; their polygons are drawn once (docs/M2.md §5.7).
	var pier := _piece(PIER, Heading.W)
	await wait_process_frames(2)
	var draws: Array[int] = [0]
	# The waves and piles after the first are copies, which the scene doesn't own.
	var polygons: Array[Node] = pier.find_children("*", "Polygon2D", true, false)
	var waves := 2 * Pier.LANES_PER_SIDE * Pier.WAVES_PER_LANE
	assert_eq(polygons.size(), 7 + Tuning.FINISH_TILES + waves)
	for polygon: Node in polygons:
		(polygon as Polygon2D).draw.connect(func() -> void: draws[0] += 1)
	var wave: Polygon2D = pier.get_node("%Waves").get_child(0)
	var before := [wave.position, wave.self_modulate]
	await wait_physics_frames(20)
	await wait_process_frames(2)
	assert_ne([wave.position, wave.self_modulate], before, "the waves moved and faded")
	assert_eq(draws[0], 0, "no redraws")


## The welcome's stills, in the order they fade in.
static func _stills(pier: Pier) -> Array[LegendStill]:
	var stills: Array[LegendStill] = []
	for node: Node in pier.get_children():
		if node is LegendStill:
			stills.append(node)
	return stills


## The ids of the legends in `schedule`'s pools, in the Book's order.
static func _book(schedule: AreaSchedule) -> Array[StringName]:
	var ids: Array[StringName] = []
	for disaster: Dictionary in CollectionScreen.disasters(schedule):
		ids.append(disaster["id"])
	return ids


func test_the_welcome_stands_the_legends_collected_in_the_books_grid() -> void:
	# A row for each area with a pool, five, as the Coast has none, and a column for each of their
	# three legends, in the Book's order. A legend not collected leaves its place empty, and an id
	# of no legend is ignored.
	var schedule := Fixtures.schedule()
	var book := _book(schedule)
	assert_eq(book.size(), 15, "five pools of three")
	var collected: Array[StringName] = []
	for k: int in range(0, book.size(), 2):
		collected.append(book[k])
	for heading: int in HEADINGS:
		var pier := _piece(PIER, heading) as Pier
		var run := Heading.NAMES[heading]
		pier.welcome(schedule, collected + ([&"no_such_legend"] as Array[StringName]))
		var grid := pier.welcome_rect
		assert_eq(grid.size, Vector2(3.0, 5.0) * Tuning.WELCOME_CELL, run + ": the grid")
		var ids: Array[StringName] = []
		for still: LegendStill in _stills(pier):
			ids.append(still.id)
			var k := book.find(still.id)
			var place := Vector2(k % 3, floorf(k / 3.0)) + Vector2(0.5, 0.5)
			var at := grid.position + place * Tuning.WELCOME_CELL
			var where := "%s: %s" % [run, still.id]
			assert_almost_eq(still.position, at, Vector2.ONE * 1e-3, where)
		assert_eq(ids, collected, run + ": the legends collected, in the Book's order")


func test_the_welcome_stands_over_the_sea_past_the_piers_end_and_clear_of_it() -> void:
	var schedule := Fixtures.schedule()
	for heading: int in HEADINGS:
		var pier := _piece(PIER, heading) as Pier
		var run := Heading.NAMES[heading]
		pier.welcome(schedule, _book(schedule))
		var centre := Iso.world_to_tile(pier.welcome_rect.get_center())
		var past := (centre - pier.point(pier.run_length(), 0.0)).dot(pier.forward())
		assert_gt(past, 0.0, run + ": the grid's centre is past the pier's end")
		var parts: Array[Polygon2D] = []
		for part: StringName in [&"Deck", &"FarRailing", &"NearRailing", &"EndRailing", &"Fascia"]:
			parts.append(pier.get_node("%" + part) as Polygon2D)
		for pile: Node in pier.get_node("%Piles").get_children():
			parts.append(pile as Polygon2D)
		var stills := _stills(pier)
		assert_eq(stills.size(), 15, run)
		var inland := PackedStringArray()
		var on_pier := PackedStringArray()
		for still: LegendStill in stills:
			var drawn := still.get_transform() * still.get_rect()
			var corners := PackedVector2Array(
				[
					drawn.position,
					Vector2(drawn.end.x, drawn.position.y),
					drawn.end,
					Vector2(drawn.position.x, drawn.end.y)
				]
			)
			for corner: Vector2 in corners:
				if not pier.water.has_point(Iso.world_to_tile(corner)):
					inland.append("%s at %s" % [still.id, corner])
			for part: Polygon2D in parts:
				var polygon := part.get_transform() * part.polygon
				if not Geometry2D.intersect_polygons(corners, polygon).is_empty():
					on_pier.append("%s over %s" % [still.id, part.name])
		assert_eq(inland, PackedStringArray(), run + ": over the sea")
		assert_eq(on_pier, PackedStringArray(), run + ": clear of the pier")


func test_the_stills_fade_in_one_after_another_once_the_view_is_there() -> void:
	# The camera's pan takes 1 / ARRIVAL_PAN_RATE seconds. Then each still fades in, in the Book's
	# order, over WELCOME_FADE seconds, WELCOME_STEP after the one before, and the last of the
	# fifteen is in before the arrival's ARRIVAL_SECONDS end.
	var pan := 1.0 / Tuning.ARRIVAL_PAN_RATE
	var rate := DELTA / Tuning.WELCOME_FADE + 1e-6
	for k: int in 15:
		var shown := 0.0
		var early := 0
		var too_fast := 0
		var out_of_step := 0
		for frame: int in ceili(Tuning.ARRIVAL_SECONDS / DELTA) + 1:
			var time := frame * DELTA
			var alpha := Pier.welcome_alpha(k, time)
			early += int(time <= pan and alpha > 0.0)
			too_fast += int(alpha < shown or alpha - shown > rate)
			shown = alpha
			if k > 0:
				var before := Pier.welcome_alpha(k - 1, time - Tuning.WELCOME_STEP)
				out_of_step += int(absf(alpha - before) > 1e-6)
		assert_eq(early, 0, "%d: frames it shows before the pan ends" % k)
		assert_eq(too_fast, 0, "%d: frames that fade it out, or in too fast" % k)
		assert_eq(out_of_step, 0, "%d: frames not WELCOME_STEP after the one before" % k)
		assert_eq(shown, 1.0, "%d: in by the arrival's end" % k)
	var schedule := Fixtures.schedule()
	var pier := _piece(PIER, Heading.N) as Pier
	pier.welcome(schedule, _book(schedule))
	var stills := _stills(pier)
	for still: LegendStill in stills:
		assert_eq(still.modulate.a, 0.0, "%s: unseen at first" % still.id)
	simulate(pier, 90, DELTA)
	for k: int in stills.size():
		var alpha := Pier.welcome_alpha(k, 90 * DELTA)
		assert_almost_eq(stills[k].modulate.a, alpha, 1e-4, "%s after 1.5 s" % stills[k].id)


func test_a_new_welcome_replaces_the_last() -> void:
	var schedule := Fixtures.schedule()
	var book := _book(schedule)
	var pier := _piece(PIER, Heading.W) as Pier
	pier.welcome(schedule, book)
	var first := _stills(pier)
	simulate(pier, 120, DELTA)
	pier.welcome(schedule, book.slice(0, 2))
	for still: LegendStill in first:
		assert_false(is_instance_valid(still), "the last welcome's stills are gone")
	var stills := _stills(pier)
	assert_eq(stills.size(), 2)
	for still: LegendStill in stills:
		assert_eq(still.modulate.a, 0.0, "%s: fades in anew" % still.id)


func test_a_legend_in_two_pools_stands_in_the_first() -> void:
	# The Book has it once, in the first area's pool, and so does the welcome.
	var city: AreaDef = load("res://areas/city.tres")
	var rural := (load("res://areas/rural.tres") as AreaDef).duplicate() as AreaDef
	var pool: Array[PackedScene] = [city.disasters[1], rural.disasters[0]]
	rural.disasters = pool
	var schedule := AreaSchedule.new()
	for area: AreaDef in [city, rural]:
		var entry := AreaScheduleEntry.new()
		entry.turn = schedule.entries.size() * 10
		entry.area = area
		schedule.entries.append(entry)
	var book := _book(schedule)
	assert_eq(book.size(), 4)
	var pier := _piece(PIER, Heading.N) as Pier
	pier.welcome(schedule, [book[1], book[3]] as Array[StringName])
	var grid := pier.welcome_rect
	assert_eq(grid.size, Vector2(3.0, 2.0) * Tuning.WELCOME_CELL)
	var stills := _stills(pier)
	assert_eq(stills.size(), 2)
	if stills.size() == 2:
		assert_eq([stills[0].id, stills[1].id], [book[1], book[3]])
		var cell := Tuning.WELCOME_CELL
		var within := Vector2.ONE * 1e-3
		assert_almost_eq(stills[0].position, grid.position + Vector2(1.5, 0.5) * cell, within)
		assert_almost_eq(stills[1].position, grid.position + Vector2(1.5, 1.5) * cell, within)


func test_home_fences_the_drives_end_and_stands_past_it() -> void:
	var length := float(Tuning.FINISH_TILES)
	for heading: int in HEADINGS:
		var home := _piece(HOME, heading) as Home
		var run := Heading.NAMES[heading]
		var within := Vector2.ONE * 1e-3
		var lines := {
			&"Fence":
			[
				home.point(length, -Home.FENCE_HALF_LENGTH),
				home.point(length, Home.FENCE_HALF_LENGTH)
			],
			&"Gate":
			[home.point(length, -Home.GATE_HALF_WIDTH), home.point(length, Home.GATE_HALF_WIDTH)],
		}
		for line: StringName in lines:
			var base := _points(home.get_node("%" + line) as Polygon2D, 2)
			assert_almost_eq(base[0], lines[line][0], within, "%s: %s" % [run, line])
			assert_almost_eq(base[1], lines[line][1], within, "%s: %s" % [run, line])
		var drive := home.rect
		assert_false(home.house.intersects(drive), "%s: the house is off the drive" % run)
		var past := home.house.get_center() - home.point(length, 0.0)
		assert_almost_eq(past.dot(home.sideways()), 0.0, 1e-4, "%s: on the drive's line" % run)
		var gap := Home.HOUSE_GAP + Home.HOUSE_SIDE / 2
		assert_almost_eq(past.dot(home.forward()), gap, 1e-4, "%s: past the fence" % run)
		# Its faces towards the viewer show: the +x and +y ones. The door is in the one towards the
		# drive, which the path, heading only N or W, comes up to from +y or +x.
		var face_x := _points(home.get_node("%FaceX") as Polygon2D, 2)
		var face_y := _points(home.get_node("%FaceY") as Polygon2D, 2)
		assert_almost_eq(face_x[0].x, home.house.end.x, 1e-3, "%s: the +x face" % run)
		assert_almost_eq(face_y[0].y, home.house.end.y, 1e-3, "%s: the +y face" % run)
		var door := _points(home.get_node("%Door") as Polygon2D, 2)
		var front := home.house.end.y if heading == Heading.N else home.house.end.x
		var door_at := door[0].y if heading == Heading.N else door[0].x
		assert_almost_eq(door_at, front, 1e-3, "%s: the door faces the drive" % run)
		for node: Node in home.get_children():
			assert_eq((node as Node2D).z_index, 0, "%s: %s under the car" % [run, node.name])
