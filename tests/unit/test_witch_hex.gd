extends GutTest
## The witch's hex, the Village's legend (docs/M6.md §3.3). Dusk falls on the village, and a
## hunched witch on a broomstick swoops in out of the dark. She circles the car once and points a
## long finger at it, and a trail of violet sparkles runs from her finger to the car. A puff of
## black smoke hides the car, and a jack-o'-lantern pops up where it stood. Its grin lights from
## within as the witch flies off, and it stays on the road, lit.

const Disasters := preload("res://tests/helpers/disaster_fixtures.gd")
const Art := preload("res://tests/helpers/art_checks.gd")
const WITCH_HEX := preload("res://disasters/legends/witch_hex.tscn")
const GLOW := preload("res://disasters/glow.tres")
const DELTA := 1.0 / 60.0
## How near a place must be, in px.
const NEAR := Vector2(0.001, 0.001)
## How near an alpha must be: a colour holds 32-bit floats.
const NEAR_ALPHA := 1e-6
## How far she must move sideways in a frame, in px, for the way she faces to count.
const SIDEWAYS := 0.01
## How many texels light up with the grin, at least.
const LIT_TEXELS := 20

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


## The witch's hex, playing for the car with the car's place as its origin, as the director gives
## it, its direction `direction`.
func _hex(direction := Vector2(0.6, -0.8)) -> WitchHex:
	_car.modulate.a = 1.0
	var hex := Disasters.disaster(self, WITCH_HEX, _car, _camera) as WitchHex
	hex.stage = _stage
	_params = Disasters.params()
	_params.direction = direction
	_params.origin_world = _car.global_position
	_frames = 0
	hex.play(_params)
	return hex


## When each beat ends, in seconds after the delay.
static func _ends() -> Array[float]:
	var ends: Array[float] = []
	var sum := 0.0
	for length: float in Tuning.WITCH_HEX_BEATS:
		sum += length
		ends.append(sum)
	return ends


## When she has swooped in, and when she has circled the car, in seconds after the delay.
static func _swooped() -> float:
	return Tuning.WITCH_HEX_BEATS[0] * WitchHex.SWOOP_SHARE


static func _circled() -> float:
	return Tuning.WITCH_HEX_BEATS[0] + Tuning.WITCH_HEX_BEATS[1] * WitchHex.CIRCLE_SHARE


## Steps `hex` on to `seconds` after its delay, and a frame or two past it: a clock that sums
## frames can fall short of the sum by a hair.
func _step_to(hex: WitchHex, seconds: float) -> void:
	var target := ceili((_params.delay + seconds) / DELTA) + 1
	simulate(hex, target - _frames, DELTA)
	_frames = target


## Steps `hex` one frame.
func _step(hex: WitchHex) -> void:
	simulate(hex, 1, DELTA)
	_frames += 1


## Whether `hex` has stepped on to `seconds` after its delay.
func _reached(seconds: float) -> bool:
	return _frames * DELTA >= _params.delay + seconds


## How far the steps have gone through `beat`, from 0 at its start to 1 at its end.
func _through(beat: int) -> float:
	var start := _ends()[beat] - Tuning.WITCH_HEX_BEATS[beat]
	return (_frames * DELTA - _params.delay - start) / Tuning.WITCH_HEX_BEATS[beat]


## Where `part` is, in px from the car.
func _from_car(part: Node2D) -> Vector2:
	return part.global_position - _car.global_position


static func _witch(hex: WitchHex) -> Sprite2D:
	return hex.get_node("%Witch") as Sprite2D


## Where the middle of the texel `texel` px from the foot of `sprite`'s frame shows, in px from the
## car: flip_h mirrors the frame.
func _shown(sprite: Sprite2D, texel: Vector2i) -> Vector2:
	var size := Vector2(sprite.texture.get_size()) / Vector2(sprite.hframes, sprite.vframes)
	var in_frame := Vector2(texel) + Vector2(size.x / 2.0, size.y) + Vector2(0.5, 0.5)
	if sprite.flip_h:
		in_frame.x = size.x - in_frame.x
	return _from_car(sprite) + sprite.offset + in_frame


## The colour of the texel `texel` px from the foot of `frame` of `size` px in `sheet`.
static func _texel(sheet: Image, size: Vector2i, frame: int, texel: Vector2i) -> Color:
	return sheet.get_pixelv(Vector2i(frame * size.x + (size.x >> 1), size.y) + texel)


## Whether `item` adds light.
static func _adds_light(item: CanvasItem) -> bool:
	var material := item.material as CanvasItemMaterial
	return material != null and material.blend_mode == CanvasItemMaterial.BLEND_MODE_ADD


## Whether `ramp` gives each particle one of `colors`, with nothing in between.
func _assert_two_colors(ramp: Gradient, colors: Array[Color], what: String) -> void:
	if ramp == null or ramp.get_point_count() != colors.size():
		fail_test("%s: each one colour or the other" % what)
		return
	var mode := ramp.interpolation_mode
	assert_eq(mode, Gradient.GRADIENT_INTERPOLATE_CONSTANT, "%s: nothing in between" % what)
	for k: int in colors.size():
		assert_true(ramp.get_color(k).is_equal_approx(colors[k]), "%s: colour %d" % [what, k])


func test_she_swoops_in_out_of_the_dark_and_slows_to_hover_beside_the_car() -> void:
	var ends := _ends()
	var hex := _hex()
	var witch := _witch(hex)
	var side := WitchHex.side(_params.direction)
	var hover := WitchHex.hover(-side)
	assert_eq(Disasters.z(witch), Tuning.SKY_Z, "in the sky, in the dusk")
	assert_false(witch.z_as_relative, "over the props, wherever they sort")
	var alphas: Array[float] = []
	var gaps: Array[float] = []
	var strides: Array[float] = []
	var start := Vector2.ZERO
	var last := Vector2.ZERO
	var facing := true
	var flying := true
	while not _reached(_swooped()):
		_step(hex)
		if witch.modulate.a == 0.0:
			continue
		var at := _from_car(witch)
		if alphas.is_empty():
			start = at
		else:
			strides.append((at - last).length())
			facing = facing and witch.flip_h == (at.x < last.x)
		alphas.append(witch.modulate.a)
		gaps.append((at - hover).length())
		flying = flying and witch.frame == 0
		last = at
	assert_gt(alphas.size(), 1, "she swoops in over frames")
	assert_lt(start.y, hover.y, "from high above")
	assert_lt(start.x * side, hover.x * side, "from beyond where she hovers")
	assert_lt(alphas[0], 1.0, "out of the dark")
	assert_eq(alphas, Disasters.sorted(alphas), "she only shows more")
	assert_eq(witch.modulate.a, 1.0, "in full by the time she hovers")
	assert_eq(gaps, Disasters.sorted(gaps, true), "straight to where she hovers")
	assert_eq(strides, Disasters.sorted(strides, true), "slowing")
	assert_true(facing, "facing the way she flies")
	assert_true(flying, "her hand on her broom")
	var shown := true
	while not _reached(ends[2] + Tuning.WITCH_HEX_BEATS[3] * WitchHex.FADE_FROM):
		shown = shown and Disasters.shows(witch) and witch.modulate.a == 1.0
		_step(hex)
	assert_true(shown, "in full until she fades as she flies off")


func test_she_circles_the_car_once_in_front_of_it_first_facing_the_way_she_flies() -> void:
	var centre := Vector2(0.0, -WitchHex.HEIGHT)
	var paths: Array[PackedVector2Array] = []
	for direction: Vector2 in [Vector2(0.6, -0.8), Vector2(-0.6, 0.8)]:
		var hex := _hex(direction)
		var witch := _witch(hex)
		var from_side := -WitchHex.side(direction)
		var radii := WitchHex.CIRCLE * Vector2(from_side, 1.0)
		while not _reached(_swooped()):
			_step(hex)
		var path := PackedVector2Array()
		var on_ellipse := true
		var facing := true
		var turned := 0.0
		var backwards := false
		var angle := 0.0
		while not _reached(_circled()):
			_step(hex)
			var at := _from_car(witch)
			var on := (at - centre) / radii
			on_ellipse = on_ellipse and absf(on.length() - 1.0) < 0.001
			var step := angle_difference(angle, on.angle())
			backwards = backwards or step < 0.0
			turned += step
			angle = on.angle()
			# The way she flies as the frame shows her: along the ellipse, the way she goes round
			# it. A frame can step over the point where she turns back.
			var tangent := Vector2(-on.y, on.x) * radii
			if absf(tangent.x) > SIDEWAYS:
				facing = facing and witch.flip_h == (tangent.x < 0.0)
			path.append(at)
		var lowest := 0
		var highest := 0
		for k: int in path.size():
			lowest = k if path[k].y > path[lowest].y else lowest
			highest = k if path[k].y < path[highest].y else highest
		var what := "from %s" % ("the left" if from_side < 0.0 else "the right")
		assert_true(on_ellipse, "%s: round the car, over it" % what)
		assert_almost_eq(turned, TAU, 0.001, "%s: once round, back to where she hovers" % what)
		assert_false(backwards, "%s: never back" % what)
		assert_lt(lowest, highest, "%s: in front of the car, then behind it" % what)
		assert_true(facing, "%s: facing the way she flies" % what)
		paths.append(path)
	assert_eq(paths[0].size(), paths[1].size(), "as long from either side")
	for k: int in mini(paths[0].size(), paths[1].size()):
		var mirrored := Vector2(-paths[0][k].x, paths[0][k].y)
		assert_almost_eq(paths[1][k], mirrored, NEAR, "frame %d: mirrored" % k)


func test_she_points_at_the_car_from_where_she_hovers_once_she_has_circled_it() -> void:
	var ends := _ends()
	var middle := WitchHex.car_middle()
	for direction: Vector2 in [Vector2(0.6, -0.8), Vector2(-0.6, 0.8)]:
		var hex := _hex(direction)
		var witch := _witch(hex)
		var hover := WitchHex.hover(-WitchHex.side(direction))
		var early := false
		while not _reached(_circled()):
			early = early or witch.frame != 0
			_step(hex)
		# A frame past it: a clock that sums frames can fall short by a hair.
		_step(hex)
		var pointing := true
		var still := true
		var facing := true
		var at_car := true
		while not _reached(ends[2]):
			var at := _from_car(witch)
			pointing = pointing and witch.frame == 1
			still = still and at.is_equal_approx(hover)
			facing = facing and witch.flip_h == (middle.x < at.x)
			var tip := _shown(witch, WitchHex.FINGER)
			at_car = at_car and (tip - middle).length() < (at - middle).length()
			_step(hex)
		var what := "from %s" % hover
		assert_false(early, "%s: her hand on her broom until she has circled the car" % what)
		assert_true(pointing, "%s: she points through the hex and the puff" % what)
		assert_true(still, "%s: where she hovers" % what)
		assert_true(facing, "%s: facing the car" % what)
		assert_true(at_car, "%s: her finger at it" % what)


func test_a_trail_of_violet_sparkles_runs_from_her_fingertip_to_the_car() -> void:
	var ends := _ends()
	var palette := Art.MakeArt.palette()
	var hex := _hex()
	var witch := _witch(hex)
	var trail := hex.get_node("%Trail") as CPUParticles2D
	var middle := WitchHex.car_middle()
	assert_false(_adds_light(trail), "not glows")
	assert_lt(Disasters.z(trail), Tuning.VEIL_Z, "in the dusk")
	assert_eq(trail.emission_shape, CPUParticles2D.EMISSION_SHAPE_POINTS, "born on her line")
	assert_eq(trail.gravity, Vector2.ZERO, "they hang in the air")
	_assert_two_colors(trail.color_initial_ramp, [palette["violet"], palette["lilac"]], "trail")
	var sheet := witch.texture.get_image()
	var tip := _texel(sheet, WitchHex.WITCH, 1, WitchHex.FINGER)
	var past := _texel(sheet, WitchHex.WITCH, 1, WitchHex.FINGER + Vector2i.RIGHT)
	assert_true(tip.is_equal_approx(palette["line"]), "the texel at FINGER: her pale finger")
	assert_false(past.is_equal_approx(palette["line"]), "and its tip")
	var early := false
	while not _reached(_circled()):
		early = early or trail.emitting
		_step(hex)
	assert_false(early, "none until she points")
	var reaches: Array[float] = []
	var emitting := true
	var counted := true
	var from_finger := true
	var on_line := true
	var heading := true
	var done := false
	while not done:
		_step(hex)
		done = _reached(ends[1])
		var from := _shown(witch, WitchHex.FINGER)
		var line := middle - from
		var points := trail.emission_points
		# The puff stops it as it starts, on the frame that reaches it.
		emitting = emitting and (done or trail.emitting)
		counted = counted and points.size() == WitchHex.TRAIL_POINTS
		if points.is_empty():
			continue
		var first := trail.to_global(points[0]) - _car.global_position
		from_finger = from_finger and (first - from).length() < NEAR.x
		for point: Vector2 in points:
			var along := trail.to_global(point) - _car.global_position - from
			var share := along.dot(line) / line.length_squared()
			on_line = on_line and absf(along.cross(line)) / line.length() < NEAR.x
			on_line = on_line and share >= -1e-4 and share <= 1.0 + 1e-4
		var last := trail.to_global(points[points.size() - 1]) - _car.global_position
		reaches.append((last - from).length() / line.length())
		heading = heading and trail.direction.normalized().is_equal_approx(line.normalized())
	assert_true(emitting, "from when she points to the puff")
	assert_true(counted, "born at its points")
	assert_true(from_finger, "from her fingertip as it shows")
	assert_true(on_line, "on the line from it to the middle of the car")
	assert_true(heading, "drifting toward the car")
	assert_eq(reaches, Disasters.sorted(reaches), "it only reaches further")
	assert_almost_eq(reaches[reaches.size() - 1], 1.0, 1e-5, "to the car")
	_step_to(hex, ends[1] + Tuning.WITCH_HEX_BEATS[2] * WitchHex.HIDE_FROM)
	assert_false(trail.emitting, "none once the smoke bursts")


func test_a_puff_of_black_smoke_hides_the_car() -> void:
	var ends := _ends()
	var palette := Art.MakeArt.palette()
	var hex := _hex()
	var smoke := hex.get_node("%Smoke") as CPUParticles2D
	assert_false(_adds_light(smoke), "dark: no light")
	assert_gt(Disasters.z(smoke), Disasters.z(_car), "over the car")
	assert_lt(Disasters.z(smoke), Tuning.VEIL_Z, "in the dusk")
	assert_almost_eq(_from_car(smoke), WitchHex.car_middle(), NEAR, "about the car's middle")
	_assert_two_colors(smoke.color_initial_ramp, [palette["ink"], palette["violet"]], "smoke")
	var early := false
	while not _reached(ends[1]):
		early = early or smoke.emitting
		_step(hex)
	assert_false(early, "none before the puff")
	var b2: float = Tuning.WITCH_HEX_BEATS[2]
	var frame := DELTA / b2
	var whole := true
	var hidden := true
	var puffing := true
	var poured := true
	var alphas: Array[float] = []
	while not _reached(ends[2]):
		_step(hex)
		var t := _through(2)
		if t <= WitchHex.HIDE_FROM:
			whole = whole and _car.modulate.a == 1.0
		else:
			alphas.append(_car.modulate.a)
		if t >= WitchHex.HIDE_TO + frame:
			hidden = hidden and _car.modulate.a == 0.0
		if t <= WitchHex.SMOKE_SHARE - frame:
			puffing = puffing and smoke.emitting
		elif t >= WitchHex.SMOKE_SHARE + frame:
			poured = poured and not smoke.emitting
	assert_true(whole, "the car shows in full till the smoke gathers")
	assert_eq(alphas, Disasters.sorted(alphas, true), "then fades in it")
	assert_true(hidden, "gone in it")
	assert_true(puffing, "it pours out")
	assert_true(poured, "and stops")
	assert_eq(hex.staged(), hex.standing, "nothing takes the car's place but the jack-o'-lantern")


func test_a_jack_o_lantern_pops_up_where_the_car_stood() -> void:
	var ends := _ends()
	var palette := Art.MakeArt.palette()
	var hex := _hex()
	assert_eq(hex.standing.size(), 1, "a jack-o'-lantern")
	var pumpkin := hex.standing[0]
	var glow := hex.get_node("%Glow") as Sprite2D
	assert_eq(pumpkin.get_parent(), _stage, "on the stage, where it sorts")
	assert_almost_eq(_from_car(pumpkin), Vector2.ZERO, NEAR, "its foot where the car stopped")
	var sheet := pumpkin.texture.get_image()
	var lit := 0
	var unlike: Array[Vector2i] = []
	for y: int in range(-WitchHex.PUMPKIN.y, 0):
		for x: int in range(-(WitchHex.PUMPKIN.x >> 1), WitchHex.PUMPKIN.x >> 1):
			var dark := _texel(sheet, WitchHex.PUMPKIN, 0, Vector2i(x, y))
			var bright := _texel(sheet, WitchHex.PUMPKIN, 1, Vector2i(x, y))
			if dark.is_equal_approx(bright):
				continue
			if dark.is_equal_approx(palette["ink"]) and bright.is_equal_approx(palette["yellow"]):
				lit += 1
			else:
				unlike.append(Vector2i(x, y))
	assert_eq(pumpkin.hframes, 2, "dark, then lit")
	assert_eq(unlike, [] as Array[Vector2i], "lit, only its ink face turns yellow")
	assert_gt(lit, LIT_TEXELS, "its eyes and grin")
	var early := false
	while not _reached(ends[2]):
		early = early or Disasters.shows(pumpkin)
		_step(hex)
	assert_false(early, "not until the smoke clears")
	var sizes: Array[float] = []
	var square := true
	var stays_dark := true
	var done := false
	while not done:
		_step(hex)
		done = _reached(ends[2] + Tuning.WITCH_HEX_BEATS[3] * WitchHex.POP_SHARE)
		sizes.append(pumpkin.scale.x)
		square = square and pumpkin.scale.x == pumpkin.scale.y
		# Its grin lights from the pop's end, which the last frame can step past.
		stays_dark = stays_dark and (done or pumpkin.frame == 0)
	var peak: int = sizes.find(sizes.max())
	var growing := sizes.slice(0, peak + 1)
	var settling := sizes.slice(peak)
	assert_true(square, "it keeps its shape")
	assert_true(stays_dark, "dark as it pops up")
	assert_eq(growing, Disasters.sorted(growing), "it grows")
	assert_almost_eq(sizes[peak], WitchHex.OVERSHOOT, 0.02, "past its full size")
	assert_eq(settling, Disasters.sorted(settling, true), "then settles")
	assert_almost_eq(pumpkin.scale, Vector2.ONE, NEAR, "to its full size")
	var matched := true
	while not _reached(ends[3]):
		_step(hex)
		matched = matched and pumpkin.frame == (1 if glow.modulate.a > 0.0 else 0)
	assert_true(matched, "its face lit as its glow is")
	assert_eq(pumpkin.frame, 1, "lit")


func test_its_grin_lights_from_within_and_stays_lit() -> void:
	var ends := _ends()
	var palette := Art.MakeArt.palette()
	var hex := _hex()
	var pumpkin := hex.standing[0]
	var glow := hex.get_node("%Glow") as Sprite2D
	var found: Array[CanvasItem] = []
	for item: CanvasItem in Disasters.drawables(hex):
		if _adds_light(item):
			found.append(item)
	assert_eq(found, [glow] as Array[CanvasItem], "its only glow")
	assert_eq(glow.texture, GLOW, "a soft glow")
	assert_true(glow.self_modulate.is_equal_approx(palette["yellow"]), "yellow")
	assert_eq(Disasters.z(glow), Tuning.GLOW_Z, "over the dusk")
	assert_almost_eq(glow.scale, Vector2.ONE * WitchHex.GLOW_SCALE, NEAR, "small")
	var at := _from_car(glow) - _from_car(pumpkin)
	assert_almost_eq(at, WitchHex.GRIN_AT, NEAR, "in the jack-o'-lantern")
	var sheet := pumpkin.texture.get_image()
	var face := Rect2()
	var seen := false
	for y: int in range(-WitchHex.PUMPKIN.y, 0):
		for x: int in range(-(WitchHex.PUMPKIN.x >> 1), WitchHex.PUMPKIN.x >> 1):
			if _texel(sheet, WitchHex.PUMPKIN, 1, Vector2i(x, y)).is_equal_approx(
				palette["yellow"]
			):
				var texel := Rect2(Vector2(x, y), Vector2.ONE)
				face = face.merge(texel) if seen else texel
				seen = true
	assert_true(face.has_point(at), "amid its lit face, %s" % face)
	var early := false
	while not _reached(ends[2] + Tuning.WITCH_HEX_BEATS[3] * WitchHex.POP_SHARE):
		early = early or glow.modulate.a > 0.0
		_step(hex)
	assert_false(early, "dark until the jack-o'-lantern has popped up")
	var alphas: Array[float] = []
	while not _reached(ends[3]):
		_step(hex)
		alphas.append(glow.modulate.a)
	assert_eq(alphas, Disasters.sorted(alphas), "it only brightens")
	assert_almost_eq(glow.modulate.a, Tuning.WITCH_HEX_GLOW_ALPHA, NEAR_ALPHA, "lit")


func test_she_flies_off_to_the_side_its_direction_picks_and_the_jack_o_lantern_stays_lit() -> void:
	# What it leaves behind still shows once it has finished (N31). Tile directions down-screen and
	# to the right show to the right of the car; with none, she goes right. She comes in from the
	# other side.
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
		var side := sides[direction]
		var hex := _hex(direction)
		var witch := _witch(hex)
		var pumpkin := hex.standing[0]
		var glow := hex.get_node("%Glow") as Sprite2D
		watch_signals(hex)
		while witch.modulate.a == 0.0 and not _reached(ends[0]):
			_step(hex)
		assert_lt(_from_car(witch).x * side, 0.0, "%s: in from the other side" % direction)
		_step_to(hex, ends[2])
		var start := _from_car(witch)
		var alphas: Array[float] = []
		var facing := true
		while not _reached(ends[3]):
			_step(hex)
			alphas.append(witch.modulate.a)
			facing = facing and witch.frame == 0 and witch.flip_h == (side < 0.0)
		var end := _from_car(witch)
		assert_gt((end.x - start.x) * side, 0.0, "%s: off to her side" % direction)
		assert_lt(end.y, start.y, "%s: up into the dark" % direction)
		assert_true(facing, "%s: facing the way she flies, her hand on her broom" % direction)
		assert_eq(alphas, Disasters.sorted(alphas, true), "%s: she only fades" % direction)
		_step_to(hex, Disasters.duration(hex, _params) - _params.delay + 0.5)
		assert_signal_emit_count(hex, "finished", 1, "%s: it has finished" % direction)
		assert_false(Disasters.shows(witch), "%s: she's gone" % direction)
		assert_true(Disasters.shows(pumpkin), "%s: the jack-o'-lantern stays" % direction)
		assert_almost_eq(pumpkin.scale, Vector2.ONE, NEAR, "%s: full size" % direction)
		assert_eq(pumpkin.frame, 1, "%s: lit" % direction)
		var alpha := glow.modulate.a
		var what := "%s: its grin still glows" % direction
		assert_almost_eq(alpha, Tuning.WITCH_HEX_GLOW_ALPHA, NEAR_ALPHA, what)
		assert_eq(_car.modulate.a, 0.0, "%s: the car is gone" % direction)
