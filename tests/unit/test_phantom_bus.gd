extends GutTest
## The phantom bus, the City's legend (M6_PLAN.md §3.3). Out of its fog it glides along the car's
## road, from the end that its direction picks, to a stop beside the car, up-screen of it, so that
## the car and its double draw over it. Its doors open on the dark, the double slides into them and
## shrinks away, the doors shut, and it glides on and fades, leaving its ticket at the doors. Its
## lamps glow on the end of it that the viewer sees, where its sheet draws them.

const Disasters := preload("res://tests/helpers/disaster_fixtures.gd")
const BUS := preload("res://disasters/legends/phantom_bus.tscn")
const DELTA := 1.0 / 60.0
## The tile axes, as the car's headings.
const HEADINGS: Array[Vector2] = [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]
## How near a place must be, in tiles or px.
const NEAR := Vector2(0.001, 0.001)

var _stage: Node2D
var _car: CarController
var _camera: CameraRig
var _params: DisasterParams
## Physics frames stepped since play().
var _frames := 0


func before_each() -> void:
	_stage = Disasters.stage(self)
	_car = Disasters.car(self, 0.0, _stage)
	_camera = Disasters.camera(self)


## The bus, playing for the car, which heads `car_heading` in tile space, with `direction` in its
## params and the car's place as its origin, as the director gives them.
func _bus(car_heading: Vector2, direction: Vector2) -> PhantomBus:
	_car.sim.angle = atan2(car_heading.x, -car_heading.y)
	_car.modulate.a = 1.0
	var bus := Disasters.disaster(self, BUS, _car, _camera) as PhantomBus
	bus.stage = _stage
	_params = Disasters.params()
	_params.direction = direction
	_params.origin_world = _car.global_position
	_frames = 0
	bus.play(_params)
	return bus


## When each beat ends, in seconds after the delay.
static func _ends() -> Array[float]:
	var ends: Array[float] = []
	var sum := 0.0
	for length: float in Tuning.PHANTOM_BUS_BEATS:
		sum += length
		ends.append(sum)
	return ends


## The middle of `beat`, in seconds after the delay: two frames or more from either end.
static func _middle(beat: int) -> float:
	return _ends()[beat] - Tuning.PHANTOM_BUS_BEATS[beat] / 2.0


## Steps `bus` on to `seconds` after its delay, and a frame or two past it: a clock that sums
## frames can fall short of the sum by a hair.
func _step_to(bus: PhantomBus, seconds: float) -> void:
	var target := ceili((_params.delay + seconds) / DELTA) + 1
	simulate(bus, target - _frames, DELTA)
	_frames = target


## Steps `bus` one frame.
func _step(bus: PhantomBus) -> void:
	simulate(bus, 1, DELTA)
	_frames += 1


## Whether `bus` has stepped on to `seconds` after its delay.
func _reached(seconds: float) -> bool:
	return _frames * DELTA >= _params.delay + seconds


## The bus's sprite, which play() has put on the stage.
static func _sprite(bus: PhantomBus) -> Sprite2D:
	return bus.standing[0]


## The car's double, which the bus has put on the stage once it has taken the car, or null.
static func _double(bus: PhantomBus) -> Sprite2D:
	for part: Sprite2D in bus.staged():
		if part not in bus.standing:
			return part
	return null


## Where the bus is, in tiles from the car.
func _where(bus: PhantomBus) -> Vector2:
	return Iso.world_to_tile(_sprite(bus).global_position - _car.global_position)


## Where its doors are, in px from the car, once it has stopped facing `forward`.
func _doors(forward: Vector2) -> Vector2:
	var across := PhantomBus.WIDTH / 2.0 - Tuning.PHANTOM_BUS_GAP_TILES
	return _car.global_position + Iso.tile_to_world(PhantomBus.side(forward) * across)


func test_it_glides_along_the_cars_road_from_the_end_that_its_direction_picks() -> void:
	# The car may stop mid-turn, 0.6 rad off its road. 1.3 rad off the road, the direction is
	# nearer the other tile axis: a bus that kept to that axis would cross the road.
	var ends := _ends()
	for heading: Vector2 in HEADINGS:
		for tilt: float in [0.0, 0.6]:
			for turn: float in [0.0, 1.3, PI, PI + 1.3]:
				var direction := heading.rotated(turn)
				var forward := heading if direction.dot(heading) >= 0.0 else -heading
				var beside := -PhantomBus.side(forward) * Tuning.PHANTOM_BUS_GAP_TILES
				var bus := _bus(heading.rotated(tilt), direction)
				var what := "car %s, direction %s" % [heading.rotated(tilt), direction]
				_step_to(bus, ends[0] / 2.0)
				var from := beside - forward * Tuning.PHANTOM_BUS_APPROACH_TILES
				assert_almost_eq(_where(bus), from, NEAR, "%s: in the fog" % what)
				_step_to(bus, ends[1])
				assert_almost_eq(_where(bus), beside, NEAR, "%s: stops beside the car" % what)
				_step_to(bus, ends[3])
				var to := beside + forward * Tuning.PHANTOM_BUS_LEAVE_TILES
				assert_almost_eq(_where(bus), to, NEAR, "%s: glides on" % what)


func test_the_car_and_its_double_draw_over_the_bus_as_they_board() -> void:
	# The stage sorts by y: the bus stops up-screen of the car, and the double stays down-screen of
	# it all the way into its doors.
	var ends := _ends()
	for heading: Vector2 in HEADINGS:
		for direction: Vector2 in [heading, -heading]:
			var bus := _bus(heading, direction)
			var what := "car %s, direction %s" % [heading, direction]
			_step_to(bus, ends[1])
			var sprite := _sprite(bus)
			var car_double := _double(bus)
			assert_lt(sprite.global_position.y, _car.global_position.y, "%s: up-screen" % what)
			if car_double == null:
				fail_test("%s: the bus took the car" % what)
				continue
			assert_eq(car_double.get_parent(), sprite.get_parent(), "%s: on one stage" % what)
			var least := INF
			while _frames <= ceili((_params.delay + ends[2]) / DELTA):
				least = minf(least, car_double.global_position.y - sprite.global_position.y)
				simulate(bus, 1, DELTA)
				_frames += 1
			assert_gt(least, 0.0, "%s: the double stays down-screen of the bus" % what)


func test_its_doors_open_on_the_dark_and_the_double_shrinks_into_them() -> void:
	var ends := _ends()
	var bus := _bus(Vector2.RIGHT, Vector2.RIGHT)
	var sprite := _sprite(bus)
	var first := PhantomBus.first_frame(Vector2.RIGHT)
	_step_to(bus, _middle(1))
	assert_eq(sprite.frame, first, "shut as it comes")
	assert_null(_double(bus), "the car is still there")
	_step_to(bus, ends[1])
	var car_double := _double(bus)
	if car_double == null:
		fail_test("the bus took the car")
		return
	assert_eq(_car.modulate.a, 0.0, "the double has taken the car's place")
	var shown := true
	var alphas: Array[float] = []
	while not _reached(_middle(2)):
		shown = shown and Disasters.shows(car_double) and car_double.modulate.a == 1.0
		alphas.append(car_double.modulate.a)
		_step(bus)
	assert_true(shown, "it shows in full through the first half of the beat")
	assert_eq(sprite.frame, first + PhantomBus.DOORS - 1, "open")
	var done := false
	while not done:
		done = _reached(ends[2])
		alphas.append(car_double.modulate.a)
		_step(bus)
	alphas.append(car_double.modulate.a)
	assert_eq(alphas, Disasters.sorted(alphas, true), "it only fades")
	assert_almost_eq(car_double.global_position, _doors(Vector2.RIGHT), NEAR, "at the doors")
	var boarded := Vector2.ONE * PhantomBus.BOARDED_SCALE
	assert_almost_eq(car_double.scale, boarded, NEAR, "shrunk")
	assert_eq(car_double.modulate.a, 0.0, "gone in")


func test_it_glides_off_and_fades_and_leaves_its_ticket_at_the_doors() -> void:
	# What it leaves behind still shows once it has finished (N31).
	var ends := _ends()
	var bus := _bus(Vector2.DOWN, Vector2.DOWN)
	var sprite := _sprite(bus)
	var ticket := bus.get_node("%Ticket") as Sprite2D
	var fog := bus.get_node("%Fog") as CPUParticles2D
	_step_to(bus, ends[0] / 2.0)
	assert_true(fog.emitting, "the fog rolls in")
	assert_eq(sprite.modulate.a, 0.0, "the bus is still in it")
	_step_to(bus, _middle(2))
	assert_almost_eq(sprite.modulate.a, Tuning.PHANTOM_BUS_ALPHA, 0.001, "half see-through")
	assert_eq(ticket.modulate.a, 0.0, "no ticket yet")
	_step_to(bus, ends[3] + 0.5)
	assert_eq(sprite.modulate.a, 0.0, "faded")
	assert_eq(sprite.frame, PhantomBus.first_frame(Vector2.DOWN), "its doors shut")
	assert_false(fog.emitting, "the fog lifts")
	assert_eq(ticket.modulate.a, 1.0, "its ticket shows")
	assert_almost_eq(ticket.global_position, _doors(Vector2.DOWN), NEAR, "at the doors")


func test_its_two_lamps_glow_on_the_end_that_the_viewer_sees_where_its_sheet_draws_them() -> void:
	# The glows hang under the bus, so they go with it. The end that the viewer sees is its front as
	# it comes toward the viewer and its back as it goes away: down-screen of its foot.
	for heading: Vector2 in HEADINGS:
		var bus := _bus(heading, heading)
		var sprite := _sprite(bus)
		var glows: Array[Sprite2D] = []
		for item: CanvasItem in Disasters.drawables(bus):
			var material := item.material as CanvasItemMaterial
			if material != null and material.blend_mode == CanvasItemMaterial.BLEND_MODE_ADD:
				glows.append(item as Sprite2D)
		assert_eq(glows.size(), 2, "%s: two glows" % heading)
		var sheet := sprite.texture.get_image()
		for glow: Sprite2D in glows:
			var what := "%s: %s" % [heading, glow.name]
			assert_eq(glow.get_parent(), sprite, "%s: under the bus" % what)
			assert_gt(glow.position.y, 0.0, "%s: on the near end" % what)
			for doors: int in PhantomBus.DOORS:
				var frame := PhantomBus.first_frame(heading) + doors
				var pixel := Vector2i((glow.position - sprite.offset).floor())
				var lamp := sheet.get_pixelv(pixel + Vector2i(PhantomBus.FRAME.x * frame, 0))
				var tint := glow.self_modulate.to_html()
				assert_eq(lamp.to_html(), tint, "%s: on a lamp of frame %d" % [what, frame])
