extends GutTest
## CarController and the car scene (IMPLEMENTATION_PLAN.md M2.4, M3.3): the sprite frame for a
## heading, and the car's view of its CarSim. A legend's double of the car (M6_PLAN.md §5.4).

const Fixtures := preload("res://tests/helpers/road_fixtures.gd")
const CAR_SCENE := preload("res://car/car.tscn")
const Art := preload("res://tests/helpers/art_checks.gd")
## The least change of luminance that a puff of smoke must make to what it covers, so that it
## shows. Measured on the sRGB values, as the 2D renderer blends them.
const SMOKE_CONTRAST := 0.1
## The least share of a road sheet, ground or edge that one of its colours must have for a puff to
## count as being over it: a puff covers a few hundred pixels, more than any speck of the rest.
const MAIN_SHARE := 0.05


func _car() -> CarController:
	var buffer := RoadBuffer.new(RoadGenerator.new(1, Fixtures.schedule()))
	buffer.start()
	var car: CarController = CAR_SCENE.instantiate()
	car.sim = CarSim.new(buffer)
	car.input = InputRouter.new()
	add_child_autofree(car)
	car.add_child(car.input)
	return car


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
	assert_eq(body.frame, CarController.frame(car.sim.forward()))


func test_the_body_shows_the_frame_of_each_heading() -> void:
	var car := _car()
	var body: Sprite2D = car.get_node("%Body")
	car.input.enabled = false
	var frames: Array[int] = []
	for heading: int in 4:
		car.sim.angle = heading * PI / 2.0
		await wait_physics_frames(2)
		frames.append(body.frame)
	assert_eq(frames, [3, 5, 11, 13] as Array[int], "N, E, S and W")


func test_its_double_shows_what_the_body_shows_where_it_shows_it() -> void:
	var car := _car()
	var body: Sprite2D = car.get_node("%Body")
	var sheet := body.texture.get_image()
	var frame_size := body.texture.get_size() / Vector2(body.hframes, body.vframes)
	car.input.enabled = false
	for heading: int in 4:
		car.sim.angle = heading * PI / 2.0
		await wait_physics_frames(2)
		var made := car.double()
		add_child(made)
		made.global_position = car.global_position
		var what := "frame %d" % body.frame
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
	# (M3_PLAN.md J3).
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
	car.sim.state = CarSim.State.CRASHED
	await wait_physics_frames(2)
	assert_eq(body.frame, CarController.WRECK_FRAME, "the wreck")
	assert_true(smoke.emitting, "smokes")


func test_every_car_smokes_alike() -> void:
	# Godot gives each CPUParticles2D a random seed when it's made, so unless the scene fixes one,
	# the smoke differs from run to run, whatever the run's seed (IP §5.3, M3_PLAN.md J16). The
	# editor doesn't save a seed of 0, its default.
	var smokes: Array[CPUParticles2D] = []
	for _i: int in 2:
		smokes.append(_car().get_node("%Smoke"))
	assert_true(smokes[0].use_fixed_seed, "a fixed seed")
	assert_ne(smokes[0].seed, 0, "one that the scene keeps")
	assert_eq(smokes[0].seed, smokes[1].seed, "the same in every car")


func test_the_smoke_shows_over_everything_the_world_draws() -> void:
	# In every light of the day, under the night's veil (DAYNIGHT_PLAN.md §5.7).
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


## The key lights of the day (DAYNIGHT_PLAN.md §5.7). The night's veil multiplies each colour by
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
## colours that make up at least MAIN_SHARE of one of them (M5_PLAN.md §5.5, §5.7). The grey box's
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
	# light that the shadow lets through, in the open and through a tunnel (DAYNIGHT_PLAN.md C22,
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
