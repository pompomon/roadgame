extends GutTest
## CarController and the car scene (IMPLEMENTATION_PLAN.md M2.4, M3.3): the sprite frame for a
## heading, the row for its wheels' phase (VISUALS_PLAN.md §5.1), and the car's view of its CarSim.
## A legend's double of the car (docs/M6.md §5.4).

const Fixtures := preload("res://tests/helpers/road_fixtures.gd")
const CAR_SCENE := preload("res://car/car.tscn")
const Art := preload("res://tests/helpers/art_checks.gd")
## The least change of luminance that a puff of smoke must make to what it covers, so that it
## shows. Measured on the sRGB values, as the 2D renderer blends them.
const SMOKE_CONTRAST := 0.1
## The least share of a road sheet, ground or edge that one of its colours must have for a puff to
## count as being over it: a puff covers a few hundred pixels, more than any speck of the rest.
const MAIN_SHARE := 0.05
## The physics frames that each drawn frame comes after, in turn: steadily at 60, 30, 20, 15 and 10
## frames a second, and unevenly, as on a device that can't keep up.
const CADENCES: Array[Array] = [
	[1], [2], [3], [4], [6], [2, 3], [3, 2], [2, 2, 3], [3, 2, 4, 3, 5, 3, 2, 6]
]
## The speeds that a cruising car holds, in tiles a second. From 2.5, 3.75 and 5, it rolls a phase
## or more a drawn frame at 10, 15 and 20 drawn frames a second.
const SPEEDS: Array[float] = [1.5, 3.5, 5.5, 6.0, Tuning.GLOBAL_SPEED_CAP]
## How far float sums of a run's drive may fall short of a whole phase, or pass it.
const ROUNDING := 1e-6


## Drives straight on at a speed of its own, whatever the steering.
class Cruise:
	extends CarSim

	var cruise: float

	func _init(p_buffer: RoadBuffer, p_cruise: float) -> void:
		super(p_buffer)
		cruise = p_cruise

	func step(delta: float, _steering: float) -> void:
		speed = cruise
		pos += velocity() * delta


func _car() -> CarController:
	var buffer := RoadBuffer.new(RoadGenerator.new(1, Fixtures.schedule()))
	buffer.start()
	var car: CarController = CAR_SCENE.instantiate()
	car.sim = CarSim.new(buffer)
	car.input = InputRouter.new()
	add_child_autofree(car)
	car.add_child(car.input)
	return car


## A car whose sim drives straight on at `speed` tiles a second.
func _cruising(speed: float) -> CarController:
	var car := _car()
	car.sim = Cruise.new(car.sim.buffer, speed)
	return car


## Runs `frames` drawn frames of `car` as the engine does: the physics frames that are due, the next
## count of `cadence` in turn at 60 a second, then _process(). Returns how many phases on its wheels
## turned in each.
func _draw_frames(car: CarController, frames: int, cadence: Array) -> Array[int]:
	var body: Sprite2D = car.get_node("%Body")
	var turns: Array[int] = []
	for drawn: int in frames:
		var steps: int = cadence[drawn % cadence.size()]
		var phase := body.frame_coords.y
		for _step: int in steps:
			car._physics_process(1.0 / 60.0)
		car._process(steps / 60.0)
		turns.append(posmod(body.frame_coords.y - phase, CarController.PHASES))
	return turns


func test_the_grid_headings_get_the_nearest_of_16_frames() -> void:
	# The isometric axes are 63.4 degrees from screen up, so the arrow is 4.1 degrees off them.
	var frames: Array[int] = []
	for heading: Vector2 in [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]:
		frames.append(CarController.frame(heading))
	assert_eq(frames, [3, 5, 11, 13] as Array[int], "N, E, S and W")
	assert_eq(CarController.frame(Vector2(1.0, -1.0)), 4, "NE is screen right")
	assert_eq(CarController.frame(Vector2(-1.0, -1.0)), 0, "NW is screen up")


func test_it_steps_its_sim_with_the_input_and_moves_with_it() -> void:
	var car := _car()
	car.input.autopilot = Autopilot.new(car.sim)
	var start := car.sim.pos
	simulate(car, 60, 1.0 / 60.0)
	assert_gt(car.sim.pos.distance_to(start), 0.5, "a second of driving")
	assert_eq(car.position, Iso.tile_to_world(car.sim.pos))
	var body: Sprite2D = car.get_node("%Body")
	assert_eq(body.frame_coords.x, CarController.frame(car.sim.forward()))


func test_the_body_shows_the_frame_of_each_heading() -> void:
	var car := _car()
	var body: Sprite2D = car.get_node("%Body")
	car.input.enabled = false
	var frames: Array[int] = []
	for heading: int in 4:
		car.sim.angle = heading * PI / 2.0
		await wait_physics_frames(2)
		frames.append(body.frame_coords.x)
	assert_eq(frames, [3, 5, 11, 13] as Array[int], "N, E, S and W")


func test_its_wheels_turn_on_a_phase_each_wheel_roll_tiles_it_moves() -> void:
	# Never back, nor two phases at once, at the speeds it reaches; braking for a disaster, until it
	# stands, and then not at all.
	var car := _car()
	var body: Sprite2D = car.get_node("%Body")
	car.input.autopilot = Autopilot.new(car.sim)
	var moved := 0.0
	var turns := 0
	var jumps := 0
	var phase := body.frame_coords.y
	for step: int in 360:
		if step == 240:
			car.sim.state = CarSim.State.DISASTER
		var from := car.sim.pos
		simulate(car, 1, 1.0 / 60.0)
		moved += car.sim.pos.distance_to(from)
		var turned := posmod(body.frame_coords.y - phase, CarController.PHASES)
		jumps += 1 if turned > 1 else 0
		turns += turned
		phase = body.frame_coords.y
	assert_eq(car.sim.speed, 0.0, "it stands")
	assert_eq(jumps, 0, "a phase at a time, on")
	assert_gt(turns, 2 * CarController.PHASES, "round more than twice")
	var expected := moved / Tuning.WHEEL_ROLL_TILES
	assert_almost_eq(float(turns), expected, 1.0, "a phase each WHEEL_ROLL_TILES")


func test_a_drawn_frame_turns_the_wheels_a_phase_at_most_and_the_faster_the_more_often() -> void:
	# At GLOBAL_SPEED_CAP the car rolls 0.47 of a phase a physics frame, so below 30 drawn frames a
	# second, more than one from a drawn frame to the next. Two at once would be a half turn, which
	# reads as back as well as forward, and three a quarter turn back. So a drawn frame turns the
	# wheels a phase at most, and only forward: a phase each WHEEL_ROLL_TILES that the car drives,
	# counting a phase at most of each frame's drive, and on each frame that drives a phase or more.
	# So they show each phase while the car rolls less than one a frame, and turn no less often at a
	# higher speed, however unevenly the frames come (VISUALS_PLAN.md §5.1, W13).
	for cadence: Array in CADENCES:
		var fewest := 0
		for speed: float in SPEEDS:
			var what := "%s physics frames a drawn frame, at %.1f tiles a second" % [cadence, speed]
			var turns := _draw_frames(_cruising(speed), 120, cadence)
			var turned := turns.count(1)
			assert_eq(turns.max(), 1, what + ": a phase at most, forward")
			var phases := 0.0
			var stuck := 0
			for drawn: int in turns.size():
				var steps: int = cadence[drawn % cadence.size()]
				var drive := speed * steps / 60.0 / Tuning.WHEEL_ROLL_TILES
				phases += minf(drive, 1.0)
				stuck += 1 if drive >= 1.0 + ROUNDING and turns[drawn] == 0 else 0
			assert_almost_eq(float(turned), phases, 1.0 + ROUNDING, what + ": each phase it drives")
			assert_eq(stuck, 0, what + ": each frame that drives a phase turns them")
			assert_gte(turned, fewest, what + ": no fewer than slower")
			fewest = turned


func test_once_the_car_stands_its_wheels_stand_however_far_it_rolled_unshown() -> void:
	# Below 30 drawn frames a second, the car rolls further from one to the next than its wheels
	# show. They don't make that up later: whenever the car stands, so do they. So too where a sum
	# of floats, rounded up, leaves them a whole phase rolled, as after 45 frames of 2, 2 and 3
	# physics frames at 5.5 tiles a second (VISUALS_PLAN.md §5.1, W13).
	for cadence: Array in CADENCES:
		for speed: float in SPEEDS:
			var car := _cruising(speed)
			var sim := car.sim as Cruise
			var stood: Array[int] = []
			for drawn: int in 120:
				var steps: Array = [cadence[drawn % cadence.size()]]
				sim.cruise = speed
				_draw_frames(car, 1, steps)
				sim.cruise = 0.0
				stood.append_array(_draw_frames(car, 2, steps))
			var what := "%s physics frames a drawn frame, at %.1f tiles a second" % [cadence, speed]
			assert_eq(stood.max(), 0, what + ": they stand whenever it does")


func test_at_6_frames_a_second_the_wheels_turn_a_phase_at_most_and_stand_with_the_car() -> void:
	# A slow device draws a frame for several physics frames. The body shows the wheels' next phase
	# then at most, however far the car rolled, and not the rest once it brakes for a disaster
	# until it stands.
	var car := _car()
	car.input.autopilot = Autopilot.new(car.sim)
	var turns: Array[int] = []
	var stood: Array[int] = []
	var fast := 0
	for frame: int in 150:
		if frame == 120:
			car.sim.state = CarSim.State.DISASTER
		var from := car.sim.pos
		var turned: int = _draw_frames(car, 1, [10])[0]
		var moved := car.sim.pos.distance_to(from)
		fast += 1 if moved > 2.0 * Tuning.WHEEL_ROLL_TILES else 0
		if moved == 0.0:
			stood.append(turned)
		else:
			turns.append(turned)
	assert_gt(fast, 10, "frames where it rolls more than two phases")
	assert_eq(turns.max(), 1, "a phase at most, forward")
	assert_gt(turns.count(1), 60, "on most frames")
	assert_gt(stood.size(), 20, "it stands")
	assert_eq(stood.max(), 0, "and so do its wheels")


func test_its_double_shows_what_the_body_shows_where_it_shows_it() -> void:
	var car := _car()
	var body: Sprite2D = car.get_node("%Body")
	var sheet := body.texture.get_image()
	var frame_size := body.texture.get_size() / Vector2(body.hframes, body.vframes)
	car.input.enabled = false
	# Its wheels in a phase past the first, as most of the time.
	for _i: int in 120:
		if body.frame_coords.y != 0:
			break
		await wait_physics_frames(1)
	assert_ne(body.frame_coords.y, 0, "its wheels rolled")
	for heading: int in 4:
		car.sim.angle = heading * PI / 2.0
		await wait_physics_frames(2)
		var made := car.double()
		add_child(made)
		made.global_position = car.global_position
		var what := "frame %s" % body.frame_coords
		assert_eq(made.texture, body.texture, what + ": the body's sheet")
		assert_true(made.region_enabled, what + ": a part of it")
		assert_eq(
			made.get_global_transform() * made.get_rect(),
			body.get_global_transform() * body.get_rect(),
			what + ": where the body shows"
		)
		var shown := Rect2i(Vector2i(Vector2(body.frame_coords) * frame_size), Vector2i(frame_size))
		assert_eq(
			Art.pixels(sheet.get_region(Rect2i(made.region_rect))),
			Art.pixels(sheet.get_region(shown)),
			what + ": the body's frame"
		)
		made.free()


func test_dust_flies_only_while_the_car_is_off_the_road() -> void:
	var car := _car()
	var dust: CPUParticles2D = car.get_node("%Dust")
	assert_false(dust.emitting, "on the road")
	car.input.enabled = false
	car.sim.angle += PI / 2.0
	for _i: int in 120:
		simulate(car, 1, 1.0 / 60.0)
		if car.sim.state == CarSim.State.OFFROAD:
			break
	assert_eq(car.sim.state, CarSim.State.OFFROAD, "drove off sideways")
	assert_true(dust.emitting, "off the road")


func test_it_leaves_its_scale_and_modulate_to_a_disaster() -> void:
	# A disaster sinks the car by its scale and modulate, and the car keeps its position on the sim's
	# (docs/M3.md J3).
	var car := _car()
	car.sim.state = CarSim.State.DISASTER
	var sunk := Color(0.0, 0.0, 0.0, 0.5)
	car.scale = Vector2.ONE * 0.5
	car.modulate = sunk
	car.position = Vector2(1000.0, 1000.0)
	simulate(car, 2, 1.0 / 60.0)
	assert_eq(car.scale, Vector2.ONE * 0.5)
	assert_eq(car.modulate, sunk)
	assert_eq(car.position, Iso.tile_to_world(car.sim.pos), "the sim's position")


func test_a_crashed_car_shows_its_wreck_and_smokes() -> void:
	var car := _car()
	var body: Sprite2D = car.get_node("%Body")
	var smoke: CPUParticles2D = car.get_node("%Smoke")
	car.input.enabled = false
	await wait_physics_frames(2)
	assert_false(smoke.emitting, "driving")
	assert_ne(body.frame, CarController.WRECK_FRAME, "driving")
	# Its wheels in their second phase, so that the wreck must show its first row, whatever the
	# phase (VISUALS_PLAN.md §5.1): two frames don't roll them on to the first again.
	for _i: int in 120:
		if body.frame_coords.y == 1:
			break
		await wait_physics_frames(1)
	assert_eq(body.frame_coords.y, 1, "its wheels rolled")
	car.sim.state = CarSim.State.CRASHED
	await wait_physics_frames(2)
	assert_eq(body.frame, CarController.WRECK_FRAME, "the wreck")
	assert_true(smoke.emitting, "smokes")


func test_every_car_smokes_alike() -> void:
	# Godot gives each CPUParticles2D a random seed when it's made, so unless the scene fixes one,
	# the smoke differs from run to run, whatever the run's seed (IP §5.3, docs/M3.md J16). The
	# editor doesn't save a seed of 0, its default.
	var smokes: Array[CPUParticles2D] = []
	for _i: int in 2:
		smokes.append(_car().get_node("%Smoke"))
	assert_true(smokes[0].use_fixed_seed, "a fixed seed")
	assert_ne(smokes[0].seed, 0, "one that the scene keeps")
	assert_eq(smokes[0].seed, smokes[1].seed, "the same in every car")


func test_the_smoke_shows_over_everything_the_world_draws() -> void:
	# In every light of the day, under the night's veil (docs/DAYNIGHT.md §5.7).
	var smoke: CPUParticles2D = _car().get_node("%Smoke")
	for light: Color in _lights():
		for background: Color in _backgrounds():
			var puff := background.blend(smoke.color)
			assert_gte(
				absf((puff * light).get_luminance() - (background * light).get_luminance()),
				SMOKE_CONTRAST * light.get_luminance(),
				"a puff over %s in %s" % [background, light]
			)


func test_the_smoke_shows_through_a_tunnel() -> void:
	# A tunnel draws over the car (z_index 1), at TUNNEL_SEE_THROUGH while the car is in it
	# (Tunnel.opacity()): what it lets through of the smoke must still show, in every light.
	var smoke: CPUParticles2D = _car().get_node("%Smoke")
	var covers := _tunnel_covers()
	assert_eq(covers.size(), 4)
	for light: Color in _lights():
		for background: Color in _backgrounds():
			var puff := background.blend(smoke.color)
			for cover: Color in covers:
				var through := puff.blend(cover) * light
				var bare := background.blend(cover) * light
				assert_gte(
					absf(through.get_luminance() - bare.get_luminance()),
					SMOKE_CONTRAST * light.get_luminance(),
					"a puff over %s, through %s, in %s" % [background, cover, light]
				)


## The key lights of the day (docs/DAYNIGHT.md §5.7). The night's veil multiplies each colour by
## the light, and the eye takes a dimmer light's smaller contrast as the same, so the smoke needs
## SMOKE_CONTRAST times the light's luminance. Both sides are linear in the light, and the light
## shown is always a blend of the keys (DayCycle.advance()), so what holds in each key light holds
## in every light that the game shows.
static func _lights() -> Array[Color]:
	var lights: Array[Color] = []
	for light: Color in Tuning.LIGHT_COLORS:
		if light not in lights:
			lights.append(light)
	return lights


## What the world can draw under a puff of smoke. The smoke covers the wreck, and around it an
## area's road sheet, its ground, or the edge that blends it into the last area's ground: the
## colours that make up at least MAIN_SHARE of one of them (docs/M5.md §5.5, §5.7). The grey box's
## road, for an area without art, stays. The ground covers every view (WorldRenderer), so the clear
## colour no longer shows. On a bridge, it draws the river, its waves, the deck and the far railing
## (M4.4); the near railing and a tunnel draw over the car.
func _backgrounds() -> Array[Color]:
	var backgrounds: Array[Color] = [GreyboxAtlas.EDGE_COLOR]
	backgrounds.append_array(GreyboxAtlas.ROAD_COLORS)
	var body: Sprite2D = _car().get_node("%Body")
	var size := CarController.FRAME_SIZE
	var images: Array[Image] = [
		body.texture.get_image().get_region(
			Rect2i(Vector2i(CarController.WRECK_FRAME * size.x, 0), size)
		)
	]
	var schedule: AreaSchedule = load("res://areas/schedule.tres")
	for entry: AreaScheduleEntry in schedule.entries:
		var area := entry.area
		for texture: Texture2D in [area.road_sheet, area.ground, area.ground_edge]:
			images.append(texture.get_image())
	for image: Image in images:
		var shares := Art.shares(image)
		for color: Color in shares:
			if shares[color] >= MAIN_SHARE and color not in backgrounds:
				backgrounds.append(color)
	var under := 0
	for polygon: Polygon2D in _polygons(load("res://setpieces/bridge.tscn")):
		if polygon.z_index <= 0:
			backgrounds.append(polygon.color)
			under += 1
	assert_eq(under, 4, "the river, a wave, the deck and the far railing")
	return backgrounds


## The polygons of a set piece, as its scene has them.
func _polygons(scene: PackedScene) -> Array[Polygon2D]:
	var piece: Node2D = autofree(scene.instantiate())
	var polygons: Array[Polygon2D] = []
	for polygon: Node in piece.find_children("*", "Polygon2D"):
		polygons.append(polygon)
	return polygons


## The tunnel's polygons, as the car sees them while it's in the tunnel: at TUNNEL_SEE_THROUGH.
func _tunnel_covers() -> Array[Color]:
	var covers: Array[Color] = []
	for polygon: Polygon2D in _polygons(load("res://setpieces/tunnel.tscn")):
		covers.append(Color(polygon.color, polygon.color.a * Tuning.TUNNEL_SEE_THROUGH))
	return covers


func test_the_smoke_shows_in_a_shadow() -> void:
	# A shadow dims what the smoke shows over, but not the smoke, which draws above it. The eye takes
	# a shadow as a dimmer light, so there the smoke needs SMOKE_CONTRAST times the luminance of the
	# light that the shadow lets through, in the open and through a tunnel (docs/DAYNIGHT.md C22,
	# N103). The shadows are black, at the sun's or the moon's alpha, and the wreck's colours are
	# checked too, though the car draws above the shadows.
	var smoke: CPUParticles2D = _car().get_node("%Smoke")
	var covers: Array[Color] = [Color.TRANSPARENT]
	covers.append_array(_tunnel_covers())
	for alpha: float in [Tuning.SUN_SHADOW_ALPHA, Tuning.MOON_SHADOW_ALPHA]:
		for light: Color in _lights():
			var let_through := light.darkened(alpha)
			for background: Color in _backgrounds():
				var shaded := background.blend(Color(Color.BLACK, alpha))
				var puff := shaded.blend(smoke.color)
				for cover: Color in covers:
					var through := puff.blend(cover) * light
					var bare := shaded.blend(cover) * light
					assert_gte(
						absf(through.get_luminance() - bare.get_luminance()),
						SMOKE_CONTRAST * let_through.get_luminance(),
						(
							"a puff in a shadow of %s over %s, through %s, in %s"
							% [alpha, background, cover, light]
						)
					)


func test_only_a_crash_smokes() -> void:
	var car := _car()
	car.input.enabled = false
	car.sim.state = CarSim.State.DISASTER
	simulate(car, 1, 1.0 / 60.0)
	var body: Sprite2D = car.get_node("%Body")
	assert_false(car.get_node("%Smoke").emitting, "after a disaster")
	assert_ne(body.frame, CarController.WRECK_FRAME, "not the wreck")
