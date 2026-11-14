extends GutTest
## The fairy ring, the Meadows' legend (docs/M6.md §3.3). Dusk falls on the meadow, and ten pale
## toadstools sprout one by one in a ring round the car. A sickly glow swells over each in turn and
## stays lit. Pairs of yellow eyes open one by one in the grass beyond the ring and watch, and
## sparkles circle inside it. The car's double is made to dance: it spins through its headings,
## faster and faster, shrinks to a point and is gone. The eyes close together, and the ring stays,
## glowing.

const Disasters := preload("res://tests/helpers/disaster_fixtures.gd")
const Art := preload("res://tests/helpers/art_checks.gd")
const FAIRY_RING := preload("res://disasters/legends/fairy_ring.tscn")
const GLOW := preload("res://disasters/glow.tres")
const DELTA := 1.0 / 60.0
## How near a place must be, in px.
const NEAR := Vector2(0.001, 0.001)
## How near an alpha must be: a colour holds 32-bit floats.
const NEAR_ALPHA := 1e-6

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


## The fairy ring, playing for the car with the car's place as its origin, as the director gives it.
func _ring() -> FairyRing:
	_car.modulate.a = 1.0
	var ring := Disasters.disaster(self, FAIRY_RING, _car, _camera) as FairyRing
	ring.stage = _stage
	_params = Disasters.params()
	_params.origin_world = _car.global_position
	_frames = 0
	ring.play(_params)
	return ring


## When each beat ends, in seconds after the delay.
static func _ends() -> Array[float]:
	var ends: Array[float] = []
	var sum := 0.0
	for length: float in Tuning.FAIRY_RING_BEATS:
		sum += length
		ends.append(sum)
	return ends


## The middle of `beat`, in seconds after the delay: two frames or more from either end.
static func _middle(beat: int) -> float:
	return _ends()[beat] - Tuning.FAIRY_RING_BEATS[beat] / 2.0


## Steps `ring` on to `seconds` after its delay, and a frame or two past it: a clock that sums
## frames can fall short of the sum by a hair.
func _step_to(ring: FairyRing, seconds: float) -> void:
	var target := ceili((_params.delay + seconds) / DELTA) + 1
	simulate(ring, target - _frames, DELTA)
	_frames = target


## Steps `ring` one frame.
func _step(ring: FairyRing) -> void:
	simulate(ring, 1, DELTA)
	_frames += 1


## Whether `ring` has stepped on to `seconds` after its delay.
func _reached(seconds: float) -> bool:
	return _frames * DELTA >= _params.delay + seconds


## How far the steps have gone through `beat`, from 0 at its start to 1 at its end.
func _through(beat: int) -> float:
	var start := _ends()[beat] - Tuning.FAIRY_RING_BEATS[beat]
	return (_frames * DELTA - _params.delay - start) / Tuning.FAIRY_RING_BEATS[beat]


## The car's double, which the ring has put on the stage once it has taken the car, or null.
static func _double(ring: FairyRing) -> Sprite2D:
	for part: Sprite2D in ring.staged():
		if part not in ring.standing:
			return part
	return null


## Where the middle of the double shows, in px from the car: its offset keeps it there as it
## shrinks about its foot.
func _centre(car_double: Sprite2D) -> Vector2:
	var middle := car_double.offset + Vector2(CarController.FRAME_SIZE) / 2.0
	return car_double.global_position + car_double.scale * middle - _car.global_position


## Where `part` is, in px from the car.
func _from_car(part: Node2D) -> Vector2:
	return part.global_position - _car.global_position


## The frame of the car's sheet that `car_double` shows.
static func _heading(car_double: Sprite2D) -> int:
	return roundi(car_double.region_rect.position.x / CarController.FRAME_SIZE.x)


## Whether `item` adds light.
static func _adds_light(item: CanvasItem) -> bool:
	var material := item.material as CanvasItemMaterial
	return material != null and material.blend_mode == CanvasItemMaterial.BLEND_MODE_ADD


## Whether `now` lights less than `before` in any channel, where each adds its colour times its
## alpha.
static func _darker(now: Color, before: Color) -> bool:
	return (
		now.r * now.a < before.r * before.a
		or now.g * now.a < before.g * before.a
		or now.b * now.a < before.b * before.a
	)


## `values` in order, each after the one before.
static func _rising(values: Array[int]) -> bool:
	for k: int in range(1, values.size()):
		if values[k] <= values[k - 1]:
			return false
	return true


func test_ten_toadstools_sprout_one_by_one_in_a_ring_round_the_car() -> void:
	var ends := _ends()
	var ring := _ring()
	var toadstools := ring.standing
	assert_eq(toadstools.size(), FairyRing.TOADSTOOLS, "ten toadstools")
	var body := Rect2(-Vector2(CarController.FOOT), Vector2(CarController.FRAME_SIZE))
	for k: int in toadstools.size():
		var toadstool := toadstools[k]
		var foot := _from_car(toadstool)
		assert_eq(toadstool.get_parent(), _stage, "%d: on the stage, where it sorts" % k)
		assert_almost_eq((foot / FairyRing.RING).length(), 1.0, 0.001, "%d: on the ring" % k)
		var next := _from_car(toadstools[(k + 1) % toadstools.size()]) / FairyRing.RING
		var step := angle_difference((foot / FairyRing.RING).angle(), next.angle())
		var turn := TAU / FairyRing.TOADSTOOLS
		assert_almost_eq(step, turn, 0.001, "%d: the next a step on, clockwise" % k)
		var area := Rect2(foot + toadstool.offset, Vector2(FairyRing.TOADSTOOL))
		assert_false(area.intersects(body), "%d: clear of the car" % k)
	var sprouted: Array[int] = []
	sprouted.resize(toadstools.size())
	sprouted.fill(-1)
	var frames: Array[int] = []
	frames.resize(toadstools.size())
	var only_grow := true
	while not _reached(ends[0]):
		_step(ring)
		for k: int in toadstools.size():
			var toadstool := toadstools[k]
			if sprouted[k] < 0 and toadstool.modulate.a > 0.0:
				sprouted[k] = _frames
			if sprouted[k] >= 0:
				only_grow = only_grow and toadstool.modulate.a == 1.0
				only_grow = only_grow and toadstool.frame >= frames[k]
				frames[k] = toadstool.frame
	_step(ring)
	assert_true(only_grow, "once sprouted, each only grows")
	assert_true(_rising(sprouted), "one by one, round the ring: %s" % [sprouted])
	for k: int in toadstools.size():
		assert_eq(toadstools[k].frame, FairyRing.TOADSTOOL_FRAMES - 1, "%d: full grown" % k)
		assert_eq(toadstools[k].modulate.a, 1.0, "%d: there" % k)


func test_a_glow_swells_over_each_toadstool_in_turn_and_stays_lit() -> void:
	var ends := _ends()
	var ring := _ring()
	var glows := ring.glows()
	assert_eq(glows.size(), FairyRing.TOADSTOOLS, "one over each toadstool")
	for k: int in glows.size():
		var cap := _from_car(ring.standing[k]) + FairyRing.GLOW_AT
		assert_almost_eq(_from_car(glows[k]), cap, NEAR, "%d: over its toadstool's cap" % k)
	_step_to(ring, _middle(0))
	for k: int in glows.size():
		assert_eq(glows[k].modulate.a, 0.0, "%d: dark as they sprout" % k)
	var lit: Array[int] = []
	lit.resize(glows.size())
	lit.fill(-1)
	var alphas: Array[float] = []
	alphas.resize(glows.size())
	var sizes: Array[float] = []
	sizes.resize(glows.size())
	var only_swell := true
	while not _reached(ends[1]):
		_step(ring)
		for k: int in glows.size():
			# Dark, a glow waits at any scale.
			var glow := glows[k]
			if lit[k] < 0 and glow.modulate.a > 0.0:
				lit[k] = _frames
			elif lit[k] >= 0:
				only_swell = (
					only_swell and glow.modulate.a >= alphas[k] and glow.scale.x >= sizes[k]
				)
			alphas[k] = glow.modulate.a
			sizes[k] = glow.scale.x
	_step(ring)
	assert_true(only_swell, "none dims as it swells")
	assert_true(_rising(lit), "in turn, round the ring: %s" % [lit])
	var full := Vector2.ONE * FairyRing.GLOW_SCALE
	for k: int in glows.size():
		var alpha := glows[k].modulate.a
		assert_almost_eq(alpha, Tuning.FAIRY_RING_GLOW_ALPHA, NEAR_ALPHA, "%d: lit" % k)
		assert_almost_eq(glows[k].scale, full, NEAR, "%d: swollen" % k)
	var dimmed: Array[int] = []
	while not _reached(ends[3]):
		_step(ring)
		for k: int in glows.size():
			var alpha := glows[k].modulate.a
			var lit_now := absf(alpha - Tuning.FAIRY_RING_GLOW_ALPHA) <= NEAR_ALPHA
			var swollen := (glows[k].scale - full).length() < NEAR.x
			if not (lit_now and swollen) and k not in dimmed:
				dimmed.append(k)
	assert_eq(dimmed, [] as Array[int], "they stay lit as the car dances and the eyes close")


func test_pairs_of_eyes_open_one_by_one_beyond_the_ring_and_close_together() -> void:
	var ends := _ends()
	var ring := _ring()
	var eyes := ring.eyes()
	var glows := ring.glows()
	assert_eq(eyes.size(), FairyRing.WATCHERS.size(), "a pair at each place")
	var glow_size := Vector2(GLOW.get_size()) * FairyRing.GLOW_SCALE
	for k: int in eyes.size():
		var area := Rect2i(Vector2i((_from_car(eyes[k]) + eyes[k].offset).round()), FairyRing.EYES)
		var inside: Array[Vector2i] = []
		for y: int in range(area.position.y, area.end.y):
			for x: int in range(area.position.x, area.end.x):
				if ((Vector2(x, y) + Vector2.ONE / 2.0) / FairyRing.RING).length() <= 1.0:
					inside.append(Vector2i(x, y))
		assert_eq(inside, [] as Array[Vector2i], "%d: beyond the ring" % k)
		# A point that a glow lit and then a pair of eyes would rise twice.
		for glow: Sprite2D in glows:
			var lit := Rect2(_from_car(glow) - glow_size / 2.0, glow_size)
			assert_false(Rect2(area).intersects(lit), "%d: clear of %s" % [k, glow.name])
	_step_to(ring, _middle(0))
	for k: int in eyes.size():
		assert_eq(eyes[k].modulate.a, 0.0, "%d: shut as the toadstools sprout" % k)
	var opened: Array[int] = []
	opened.resize(eyes.size())
	opened.fill(-1)
	var frames: Array[int] = []
	frames.resize(eyes.size())
	var only_open := true
	while not _reached(ends[1]):
		_step(ring)
		for k: int in eyes.size():
			var pair := eyes[k]
			if opened[k] < 0 and pair.modulate.a > 0.0:
				opened[k] = _frames
			if opened[k] >= 0:
				only_open = only_open and pair.modulate.a == 1.0 and pair.frame >= frames[k]
				frames[k] = pair.frame
	_step(ring)
	assert_true(only_open, "once open, they only open wider")
	assert_true(_rising(opened), "one by one: %s" % [opened])
	var watching := true
	while not _reached(ends[2]):
		for pair: Sprite2D in eyes:
			watching = watching and pair.modulate.a == 1.0
			watching = watching and pair.frame == FairyRing.EYE_FRAMES - 1
		_step(ring)
	assert_true(watching, "wide open as the car dances")
	var together := true
	var only_close := true
	var frame := FairyRing.EYE_FRAMES - 1
	var alpha := 1.0
	while not _reached(ends[2] + Tuning.FAIRY_RING_BEATS[3] * FairyRing.CLOSE_SHARE):
		_step(ring)
		for pair: Sprite2D in eyes:
			together = together and pair.modulate.a == eyes[0].modulate.a
			together = together and pair.frame == eyes[0].frame
		only_close = only_close and eyes[0].modulate.a <= alpha
		only_close = only_close and (eyes[0].modulate.a == 0.0 or eyes[0].frame <= frame)
		frame = eyes[0].frame
		alpha = eyes[0].modulate.a
	_step(ring)
	assert_true(together, "they close together")
	assert_true(only_close, "without opening again")
	for k: int in eyes.size():
		assert_eq(eyes[k].modulate.a, 0.0, "%d: shut" % k)


func test_each_point_of_a_pair_of_eyes_only_lightens_as_they_open() -> void:
	# They open once and close once, through the same frames, so each point of the World that they
	# light rises once and falls once (docs/M6.md §5.6), if each texel of each frame is at least as
	# light as in the frame before. The flash test reads the light FLASH_GRID px apart and can miss a
	# texel.
	var pair := _ring().eyes()[0]
	var sheet := pair.texture.get_image()
	var width := FairyRing.EYES.x
	var darker: Array[Vector3i] = []
	var lit := 0
	for y: int in FairyRing.EYES.y:
		for x: int in width:
			for k: int in range(1, FairyRing.EYE_FRAMES):
				var now := sheet.get_pixel(k * width + x, y)
				if _darker(now, sheet.get_pixel((k - 1) * width + x, y)):
					darker.append(Vector3i(x, y, k))
			if sheet.get_pixel((FairyRing.EYE_FRAMES - 1) * width + x, y).a > 0.0:
				lit += 1
	assert_eq(pair.hframes, FairyRing.EYE_FRAMES, "a frame for each step as they open")
	assert_gt(lit, 0, "open, they shine")
	assert_eq(darker, [] as Array[Vector3i], "texels darker than in the frame before")


func test_the_double_dances_faster_and_faster_then_shrinks_to_a_point_and_is_gone() -> void:
	var ends := _ends()
	var ring := _ring()
	_step_to(ring, _middle(1))
	assert_null(_double(ring), "the car is still there")
	assert_eq(_car.modulate.a, 1.0, "the car shows")
	_step_to(ring, ends[1])
	var car_double := _double(ring)
	if car_double == null:
		fail_test("it took the car")
		return
	assert_eq(_car.modulate.a, 0.0, "the double took the car's place")
	assert_eq(car_double.get_parent(), _stage, "on the stage, where it sorts with the toadstools")
	var middle := Vector2(CarController.FRAME_SIZE) / 2.0 - Vector2(CarController.FOOT)
	var heading := _heading(car_double)
	var headings: Array[int] = [heading]
	var quarters: Array[int] = [0, 0, 0, 0]
	var sizes: Array[float] = []
	var alphas: Array[float] = []
	var foot_stays := true
	var middle_stays := true
	var shown := true
	var done := false
	while not done:
		done = _reached(ends[2])
		if not _reached(_middle(2)):
			shown = shown and Disasters.shows(car_double) and car_double.modulate.a == 1.0
		alphas.append(car_double.modulate.a)
		_step(ring)
		var now := _heading(car_double)
		quarters[clampi(floori(_through(2) * quarters.size()), 0, quarters.size() - 1)] += posmod(
			now - heading, CarController.FRAMES
		)
		heading = now
		if now not in headings:
			headings.append(now)
		sizes.append(car_double.scale.x)
		foot_stays = foot_stays and _from_car(car_double).is_equal_approx(Vector2.ZERO)
		middle_stays = middle_stays and (_centre(car_double) - middle).length() < NEAR.x
	alphas.append(car_double.modulate.a)
	assert_true(foot_stays, "its foot stays where the car stopped, so it sorts there")
	assert_true(middle_stays, "it spins and shrinks about its middle")
	assert_true(shown, "it shows in full through the first half of the dance")
	assert_eq(alphas, Disasters.sorted(alphas, true), "it only fades")
	assert_eq(headings.size(), CarController.FRAMES, "through every heading")
	var turned := 0
	for steps: int in quarters:
		turned += steps
	assert_eq(turned, FairyRing.TURNS * CarController.FRAMES, "%d whole turns" % FairyRing.TURNS)
	# Spun evenly, the quarters would turn alike, give or take a step.
	for k: int in range(1, quarters.size()):
		assert_gt(quarters[k], quarters[k - 1], "faster and faster: %s" % [quarters])
	assert_eq(sizes, Disasters.sorted(sizes, true), "it only shrinks")
	assert_almost_eq(car_double.scale, Vector2.ONE * FairyRing.GONE_SCALE, NEAR, "to a point")
	assert_eq(car_double.modulate.a, 0.0, "gone")


func test_sparkles_circle_inside_the_ring_while_the_eyes_watch() -> void:
	var ends := _ends()
	var ring := _ring()
	var sparkles := ring.get_node("%Sparkles") as CPUParticles2D
	var palette := Art.MakeArt.palette()
	assert_false(_adds_light(sparkles), "not glows")
	assert_lt(Disasters.z(sparkles), Tuning.VEIL_Z, "in the dusk")
	assert_gt(sparkles.orbit_velocity_min, 0.0, "they circle")
	var shape := sparkles.emission_shape
	assert_eq(shape, CPUParticles2D.EMISSION_SHAPE_SPHERE_SURFACE, "born on a circle")
	for k: int in CarController.FRAMES:
		var on := Vector2.from_angle(TAU * k / CarController.FRAMES)
		var born := sparkles.position + on * sparkles.emission_sphere_radius
		assert_lt((born / FairyRing.RING).length(), 1.0, "%d: inside the ring" % k)
	var ramp := sparkles.color_initial_ramp
	if ramp == null or ramp.get_point_count() != 2:
		fail_test("each sparkle is one colour or the other")
		return
	var mode := ramp.interpolation_mode
	assert_eq(mode, Gradient.GRADIENT_INTERPOLATE_CONSTANT, "nothing in between")
	assert_true(ramp.get_color(0).is_equal_approx(palette["lilac"]), "lilac")
	assert_true(ramp.get_color(1).is_equal_approx(palette["wisp"]), "and wisp")
	_step_to(ring, _middle(0))
	assert_false(sparkles.emitting, "none as the toadstools sprout")
	_step_to(ring, ends[0])
	assert_true(sparkles.emitting, "as the glows swell")
	_step_to(ring, _middle(2))
	assert_true(sparkles.emitting, "as the car dances")
	_step_to(ring, ends[2])
	assert_false(sparkles.emitting, "none as the eyes close")


func test_the_ring_stays_glowing_where_the_car_danced() -> void:
	# What it leaves behind still shows once it has finished (N31).
	var ring := _ring()
	watch_signals(ring)
	_step_to(ring, Disasters.duration(ring, _params) - _params.delay + 0.5)
	assert_signal_emit_count(ring, "finished", 1, "it has finished")
	for k: int in ring.standing.size():
		var toadstool := ring.standing[k]
		assert_eq(toadstool.modulate.a, 1.0, "%d: the toadstool stays" % k)
		assert_eq(toadstool.frame, FairyRing.TOADSTOOL_FRAMES - 1, "%d: full grown" % k)
	for glow: Sprite2D in ring.glows():
		var alpha := glow.modulate.a
		var what := "%s: still glowing" % glow.name
		assert_almost_eq(alpha, Tuning.FAIRY_RING_GLOW_ALPHA, NEAR_ALPHA, what)
	for pair: Sprite2D in ring.eyes():
		assert_eq(pair.modulate.a, 0.0, "%s: shut" % pair.name)
	var car_double := _double(ring)
	assert_true(car_double != null and car_double.modulate.a == 0.0, "the car is gone")
	assert_eq(_car.modulate.a, 0.0, "and stays gone")


func test_its_glows_are_the_toadstools_wisp_glows_and_the_yellow_eyes() -> void:
	var ring := _ring()
	var palette := Art.MakeArt.palette()
	var glows := ring.glows()
	var eyes := ring.eyes()
	var found := 0
	for item: CanvasItem in Disasters.drawables(ring):
		if _adds_light(item):
			found += 1
			assert_true(item in glows or item in eyes, "%s: a toadstool's glow or eyes" % item.name)
			assert_eq(Disasters.z(item), Tuning.GLOW_Z, "%s: over the dusk" % item.name)
	assert_eq(found, glows.size() + eyes.size(), "each adds light")
	for glow: Sprite2D in glows:
		assert_eq(glow.texture, GLOW, "%s: a soft glow" % glow.name)
		assert_true(glow.self_modulate.is_equal_approx(palette["wisp"]), "%s: wisp" % glow.name)
	for pair: Sprite2D in eyes:
		var yellow := pair.self_modulate.is_equal_approx(palette["yellow"])
		assert_true(yellow, "%s: yellow" % pair.name)
