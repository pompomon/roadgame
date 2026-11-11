extends GutTest
## The UFO, Rural's legend (M6_PLAN.md §3.3). Out of the night a dark saucer drops and hovers over
## the car. The lights round its rim come on and turn, and its beam opens once, from the port under
## it to a pool of light round the car. Three greys stand at the beam's edge and tilt their heads.
## The car's double shudders, floats up the beam, turning, and is gone into the port. The beam
## closes once, the greys are gone, and the saucer zips off to the side that its direction picks,
## leaving a crop circle where the car stood.

const Disasters := preload("res://tests/helpers/disaster_fixtures.gd")
const UFO := preload("res://disasters/legends/ufo.tscn")
const DELTA := 1.0 / 60.0
## How near a place must be, in px.
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


## The UFO, playing for the car with `direction` in its params and the car's place as its origin,
## as the director gives them.
func _ufo(direction := Vector2.UP) -> Ufo:
	_car.modulate.a = 1.0
	var ufo := Disasters.disaster(self, UFO, _car, _camera) as Ufo
	ufo.stage = _stage
	_params = Disasters.params()
	_params.direction = direction
	_params.origin_world = _car.global_position
	_frames = 0
	ufo.play(_params)
	return ufo


## When each beat ends, in seconds after the delay.
static func _ends() -> Array[float]:
	var ends: Array[float] = []
	var sum := 0.0
	for length: float in Tuning.UFO_BEATS:
		sum += length
		ends.append(sum)
	return ends


## The middle of `beat`, in seconds after the delay: two frames or more from either end.
static func _middle(beat: int) -> float:
	return _ends()[beat] - Tuning.UFO_BEATS[beat] / 2.0


## Steps `ufo` on to `seconds` after its delay, and a frame or two past it: a clock that sums
## frames can fall short of the sum by a hair.
func _step_to(ufo: Ufo, seconds: float) -> void:
	var target := ceili((_params.delay + seconds) / DELTA) + 1
	simulate(ufo, target - _frames, DELTA)
	_frames = target


## Steps `ufo` one frame.
func _step(ufo: Ufo) -> void:
	simulate(ufo, 1, DELTA)
	_frames += 1


## Whether `ufo` has stepped on to `seconds` after its delay.
func _reached(seconds: float) -> bool:
	return _frames * DELTA >= _params.delay + seconds


## The car's double, which the UFO has put on the stage once it has taken the car, or null.
static func _double(ufo: Ufo) -> Sprite2D:
	for part: Sprite2D in ufo.staged():
		if part not in ufo.standing:
			return part
	return null


## Where the middle of the double shows, in px from the car: its offset keeps it there as it
## shrinks about its foot.
func _centre(double: Sprite2D) -> Vector2:
	var middle := double.offset + Vector2(CarController.FRAME_SIZE) / 2.0
	return double.global_position + double.scale * middle - _car.global_position


## Where `part` is, in px from the car.
func _from_car(part: Node2D) -> Vector2:
	return part.global_position - _car.global_position


func test_it_drops_out_of_the_night_and_hovers_over_the_car() -> void:
	var ends := _ends()
	var ufo := _ufo()
	var saucer := ufo.get_node("%Saucer") as Sprite2D
	var hover := Vector2(0.0, -Ufo.HOVER)
	_step_to(ufo, _middle(0))
	assert_eq(saucer.modulate.a, 0.0, "night falls first")
	assert_eq(Disasters.z(saucer), Tuning.SKY_Z, "in the sky, over the props")
	var heights: Array[float] = []
	while not _reached(ends[1]):
		_step(ufo)
		heights.append(-_from_car(saucer).y)
	_step(ufo)
	assert_gt(heights.max(), float(Ufo.HOVER), "it drops from above")
	assert_eq(heights, Disasters.sorted(heights, true), "it only drops")
	assert_almost_eq(_from_car(saucer), hover, NEAR, "it hovers over the car")
	assert_eq(saucer.modulate.a, 1.0, "dark and whole")
	_step_to(ufo, ends[3])
	assert_almost_eq(_from_car(saucer), hover, NEAR, "it stays till the zip")


func test_its_beam_opens_once_from_the_port_to_a_pool_round_the_car_and_closes_once() -> void:
	# One rise and one fall at each point (M6_PLAN.md §5.6), from the saucer's foot to the bottom of
	# its pool.
	var ends := _ends()
	var ufo := _ufo()
	var beam := ufo.get_node("%Beam") as Sprite2D
	var widths: Array[float] = []
	var clear_when_shut := true
	var lit_when_open := true
	while not _reached(ends[4]):
		_step(ufo)
		if widths.is_empty() or widths[-1] != beam.scale.x:
			widths.append(beam.scale.x)
		clear_when_shut = clear_when_shut and (beam.scale.x > Ufo.SLIVER or beam.modulate.a == 0.0)
		if beam.scale.x == 1.0:
			lit_when_open = lit_when_open and beam.modulate.a == Tuning.UFO_BEAM_ALPHA
	_step(ufo)
	assert_true(clear_when_shut, "shut, it is clear too")
	if not widths.has(1.0):
		fail_test("it opens all the way")
		return
	assert_true(lit_when_open, "open, it shines")
	var opening := widths.slice(0, widths.find(1.0) + 1)
	assert_eq(opening, Disasters.sorted(opening), "it opens without closing")
	var closing := widths.slice(widths.find(1.0))
	assert_eq(closing, Disasters.sorted(closing, true), "then it closes, once")
	assert_almost_eq(closing[-1], 0.0, Ufo.SLIVER, "shut at the end")
	var top := beam.global_position.y + beam.offset.y - _car.global_position.y
	assert_almost_eq(top, -float(Ufo.HOVER), 0.001, "it hangs from the saucer's foot")
	var bottom := beam.offset.y + beam.texture.get_height()
	assert_almost_eq(bottom, Ufo.POOL.y, 0.001, "to the bottom of its pool")
	assert_almost_eq(_from_car(beam).x, 0.0, 0.001, "over the car")
	assert_almost_eq(beam.offset.x, -Ufo.POOL.x, 0.001, "its pool round the car")


func test_the_lights_round_its_rim_come_on_with_the_beam_and_turn_until_it_closes() -> void:
	var ends := _ends()
	var ufo := _ufo()
	var rim := ufo.get_node("%Rim") as Sprite2D
	var beam := ufo.get_node("%Beam") as Sprite2D
	_step_to(ufo, _middle(1))
	assert_eq(rim.modulate.a, 0.0, "dark as it drops")
	var steps := 0
	var frame := rim.frame
	var lit_as_open := true
	var brightest := 0.0
	var one_at_a_time := true
	while not _reached(ends[3]):
		_step(ufo)
		lit_as_open = lit_as_open and absf(rim.modulate.a - beam.scale.x) < Ufo.SLIVER
		brightest = maxf(brightest, rim.modulate.a)
		if rim.frame != frame:
			one_at_a_time = one_at_a_time and rim.frame == (frame + 1) % Ufo.RIM_FRAMES
			steps += 1
			frame = rim.frame
	assert_true(lit_as_open, "lit as the beam opens")
	assert_eq(brightest, 1.0, "all lit once it's open")
	assert_true(one_at_a_time, "one step at a time")
	var expected := (ends[3] - ends[1]) * Tuning.UFO_RIM_HZ * Ufo.RIM_FRAMES
	assert_almost_eq(float(steps), expected, 1.0, "at UFO_RIM_HZ")
	_step_to(ufo, ends[4])
	assert_eq(rim.modulate.a, 0.0, "dark as it zips")
	assert_eq(rim.get_parent(), ufo.get_node("%Saucer"), "on the saucer")


func test_each_point_of_its_rim_lights_at_most_once_a_turn() -> void:
	# A turn is RIM_FRAMES frames, in which each light steps to the next one's place, so a point lit
	# once a turn rises UFO_RIM_HZ times a second, which the flash test keeps under 3. The saucer
	# stays still while its rim is lit, so each point of the world shows one texel of each frame.
	# The flash test reads the light FLASH_GRID px apart and can miss a texel, as it missed those
	# where lights on the far half of the rim met those on the near half at its ends, and rose twice
	# a turn (M6_PLAN.md §5.6).
	var rim := _ufo().get_node("%Rim") as Sprite2D
	var sheet := rim.texture.get_image()
	var lit := 0
	var twice: Array[Vector2i] = []
	for y: int in Ufo.SAUCER.y:
		for x: int in Ufo.SAUCER.x:
			var rises := 0
			for k: int in Ufo.RIM_FRAMES:
				var before := posmod(k - 1, Ufo.RIM_FRAMES)
				var now := sheet.get_pixel(k * Ufo.SAUCER.x + x, y).a > 0.0
				if now:
					lit += 1
				if now and not sheet.get_pixel(before * Ufo.SAUCER.x + x, y).a > 0.0:
					rises += 1
			if rises > 1:
				twice.append(Vector2i(x, y))
	assert_gt(lit, 0, "it has lights")
	assert_eq(twice, [] as Array[Vector2i], "texels lit twice a turn")


func test_three_greys_stand_at_the_edge_of_the_beam_and_tilt_their_heads() -> void:
	var ends := _ends()
	var ufo := _ufo()
	assert_eq(ufo.standing.size(), 3, "three greys")
	var cone_top := Ufo.PORT / 2.0
	for grey: Sprite2D in ufo.standing:
		assert_eq(grey.get_parent(), _stage, "%s: on the stage" % grey.name)
		var foot := _from_car(grey)
		assert_gt((foot / Ufo.POOL).length(), 1.0, "%s: outside the pool" % grey.name)
		# The cone widens from the port to the pool: no part of the grey is in it.
		var area := Rect2(foot + grey.offset, Vector2(Ufo.GREY))
		var nearest := maxf(area.position.x, -area.end.x)
		var low := clampf(area.end.y, -Ufo.HOVER, 0.0)
		var cone := lerpf(cone_top, Ufo.POOL.x, (low + Ufo.HOVER) / Ufo.HOVER)
		assert_gt(nearest, cone, "%s: outside the cone" % grey.name)
		assert_eq(grey.flip_h, foot.x > 0.0, "%s: its lit side faces the beam" % grey.name)
	_step_to(ufo, _middle(2))
	for grey: Sprite2D in ufo.standing:
		assert_eq(grey.modulate.a, 0.0, "%s: not there yet" % grey.name)
	_step_to(ufo, ends[2])
	for grey: Sprite2D in ufo.standing:
		assert_eq(grey.modulate.a, 1.0, "%s: there" % grey.name)
		assert_eq(grey.frame, 0, "%s: facing" % grey.name)
	_step_to(ufo, _middle(3))
	for grey: Sprite2D in ufo.standing:
		assert_eq(grey.frame, 1, "%s: its head tilted" % grey.name)
	_step_to(ufo, ends[3] + Tuning.UFO_BEATS[4] * Ufo.CLOSE_SHARE)
	for grey: Sprite2D in ufo.standing:
		assert_eq(grey.modulate.a, 0.0, "%s: gone as the beam closes" % grey.name)


func test_the_double_shudders_then_floats_up_the_beam_turning_and_is_gone_into_the_port() -> void:
	var ends := _ends()
	var ufo := _ufo()
	_step_to(ufo, _middle(2))
	assert_null(_double(ufo), "the car is still there")
	assert_eq(_car.modulate.a, 1.0, "the car shows")
	_step_to(ufo, ends[2])
	var double := _double(ufo)
	if double == null:
		fail_test("it took the car")
		return
	assert_eq(_car.modulate.a, 0.0, "the double took the car's place")
	var shudder: Array[float] = []
	var heights: Array[float] = []
	var frames: Array[int] = []
	var alphas: Array[float] = []
	var foot_stays := true
	var shown := true
	while not _reached(ends[3]):
		foot_stays = foot_stays and _from_car(double).is_equal_approx(Vector2.ZERO)
		if not _reached(_middle(3)):
			shown = shown and Disasters.shows(double) and double.modulate.a == 1.0
		alphas.append(double.modulate.a)
		var centre := _centre(double)
		if centre.x != 0.0 and centre.x not in shudder:
			shudder.append(centre.x)
		heights.append(-centre.y)
		var frame := roundi(double.region_rect.position.x / CarController.FRAME_SIZE.x)
		if frame not in frames:
			frames.append(frame)
		_step(ufo)
	_step(ufo)
	alphas.append(double.modulate.a)
	assert_true(foot_stays, "its foot stays where the car was, so it sorts there")
	assert_true(shown, "it shows in full through the first half of the lift")
	assert_eq(alphas, Disasters.sorted(alphas, true), "it only fades")
	shudder.sort()
	assert_eq(shudder, [-Ufo.SHUDDER_PX, Ufo.SHUDDER_PX] as Array[float], "it shudders")
	assert_eq(heights, Disasters.sorted(heights), "it only rises")
	assert_eq(frames.size(), CarController.FRAMES, "turning through every heading")
	assert_almost_eq(_centre(double), Vector2(0.0, -Ufo.HOVER), NEAR, "into the port")
	var entered := Vector2.ONE * Ufo.ENTERED_SCALE
	assert_almost_eq(double.scale, entered, NEAR, "shrunk")
	assert_eq(double.modulate.a, 0.0, "gone in")


func test_it_zips_off_to_the_side_its_direction_picks_and_leaves_a_crop_circle() -> void:
	# What it leaves behind still shows once it has finished (N31). Tile directions down-screen and
	# to the right show to the right of the car; with none, it goes right.
	var ends := _ends()
	var sides: Dictionary[Vector2, float] = {
		Vector2.UP: 1.0,
		Vector2.RIGHT: 1.0,
		Vector2.ONE: 1.0,
		Vector2.ZERO: 1.0,
		Vector2.DOWN: -1.0,
		Vector2.LEFT: -1.0,
		Vector2(-1.0, 0.5): -1.0,
	}
	for direction: Vector2 in sides:
		var ufo := _ufo(direction)
		var saucer := ufo.get_node("%Saucer") as Sprite2D
		var circle := ufo.get_node("%CropCircle") as Sprite2D
		var sparkles := ufo.get_node("%Sparkles") as CPUParticles2D
		_step_to(ufo, _middle(3))
		assert_true(sparkles.emitting, "%s: sparkles rise in the beam" % direction)
		assert_eq(circle.modulate.a, 0.0, "%s: no circle yet" % direction)
		_step_to(ufo, ends[4] + 0.5)
		var zip := Vector2(sides[direction] * Tuning.UFO_ZIP_PX.x, Tuning.UFO_ZIP_PX.y)
		var gone := Vector2(0.0, -Ufo.HOVER) + zip
		assert_almost_eq(_from_car(saucer), gone, NEAR, "%s: zipped off" % direction)
		assert_eq(saucer.modulate.a, 0.0, "%s: out of sight" % direction)
		assert_false(sparkles.emitting, "%s: no sparkles" % direction)
		assert_eq(circle.modulate.a, 1.0, "%s: its crop circle shows" % direction)
		assert_almost_eq(_from_car(circle), Vector2.ZERO, NEAR, "%s: where the car was" % direction)
		assert_eq(circle.get_parent(), ufo, "%s: flat, under the props" % direction)


func test_its_two_glows_are_its_beam_and_the_lights_on_the_saucers_rim() -> void:
	var ufo := _ufo()
	var saucer := ufo.get_node("%Saucer") as Sprite2D
	var glows: Array[String] = []
	for item: CanvasItem in Disasters.drawables(ufo):
		var material := item.material as CanvasItemMaterial
		if material != null and material.blend_mode == CanvasItemMaterial.BLEND_MODE_ADD:
			glows.append(String(item.name))
	glows.sort()
	assert_eq(glows, ["Beam", "Rim"] as Array[String])
	var rim := ufo.get_node("%Rim") as Sprite2D
	assert_eq(rim.offset, saucer.offset, "its frames lie over the saucer's")
	var width := saucer.texture.get_width() * rim.hframes
	assert_eq(rim.texture.get_width(), width, "frames as wide as the saucer")
	assert_eq(rim.hframes, Ufo.RIM_FRAMES)
