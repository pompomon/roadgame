extends GutTest
## The death worm, the Desert's legend (docs/M6.md §3.3). In the glare of the desert, the ground
## trembles, and ripples run through the sand to the car. A mound swells under the car and lifts
## it. A giant eyeless worm bursts up out of it in a spray of sand, carrying the car's double up on
## its head. Its mouth opens, ringed with white teeth, and the double sinks down its black throat.
## The mouth shuts, the swallow goes down its body, and it dives back into the sand, leaving a
## crater where the car stood.

const Disasters := preload("res://tests/helpers/disaster_fixtures.gd")
const Art := preload("res://tests/helpers/art_checks.gd")
const DEATH_WORM := preload("res://disasters/legends/death_worm.tscn")
const DELTA := 1.0 / 60.0
## How near a place must be, in px.
const NEAR := Vector2(0.001, 0.001)
## How far the edge of what shows of the double may be from the worm's lip, in px: the double is
## cut at whole texels as it sinks by fractions of a px.
const HALF_TEXEL := 0.5
## How much the swallow must widen the body, in px, to show.
const BULGE_PX := 4
## The most of its height the worm may rise or sink by in a frame: it moves, it doesn't pop.
const MOST_A_FRAME := 0.25

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


## The death worm, playing for the car with the car's place as its origin, as the director gives
## it, its direction `direction`.
func _legend(direction := Vector2(0.6, -0.8)) -> DeathWorm:
	_car.modulate.a = 1.0
	var legend := Disasters.disaster(self, DEATH_WORM, _car, _camera) as DeathWorm
	legend.stage = _stage
	_params = Disasters.params()
	_params.direction = direction
	_params.origin_world = _car.global_position
	_frames = 0
	legend.play(_params)
	return legend


## When each beat ends, in seconds after the delay.
static func _ends() -> Array[float]:
	var ends: Array[float] = []
	var sum := 0.0
	for length: float in Tuning.DEATH_WORM_BEATS:
		sum += length
		ends.append(sum)
	return ends


## When `share` of `beat` is done, in seconds after the delay.
static func _at(beat: int, share: float) -> float:
	return _ends()[beat] - Tuning.DEATH_WORM_BEATS[beat] * (1.0 - share)


## The middle of `beat`, in seconds after the delay: two frames or more from either end.
static func _middle(beat: int) -> float:
	return _at(beat, 0.5)


## Steps `legend` on to `seconds` after its delay, and a frame or two past it: a clock that sums
## frames can fall short of the sum by a hair.
func _step_to(legend: DeathWorm, seconds: float) -> void:
	var target := ceili((_params.delay + seconds) / DELTA) + 1
	simulate(legend, target - _frames, DELTA)
	_frames = target


## Steps `legend` one frame.
func _step(legend: DeathWorm) -> void:
	simulate(legend, 1, DELTA)
	_frames += 1


## Whether `legend` has stepped on to `seconds` after its delay.
func _reached(seconds: float) -> bool:
	return _frames * DELTA >= _params.delay + seconds


## How far the steps have gone through `beat`, from 0 at its start to 1 at its end.
func _through(beat: int) -> float:
	return (_frames * DELTA - _params.delay - _at(beat, 0.0)) / Tuning.DEATH_WORM_BEATS[beat]


## Whether a step from here stays half a frame short of `seconds` after the delay, so that the
## legend's clock and theirs agree that it has not got there.
func _short_of(seconds: float) -> bool:
	return (_frames + 1) * DELTA < _params.delay + seconds - DELTA / 2.0


## Whether the steps are more than a frame away from `share` of `beat`, so that the legend's clock
## and theirs agree on which side of it they are.
func _clear_of(beat: int, share: float) -> bool:
	return absf(_through(beat) - share) > DELTA / Tuning.DEATH_WORM_BEATS[beat]


## Where `part` is, in px from the car.
func _from_car(part: Node2D) -> Vector2:
	return part.global_position - _car.global_position


static func _worm(legend: DeathWorm) -> Sprite2D:
	return legend.standing[0]


## The car's double, which the legend has put on the stage once it has taken the car, or null.
static func _double(legend: DeathWorm) -> Sprite2D:
	for part: Sprite2D in legend.staged():
		if part not in legend.standing:
			return part
	return null


## Where the double's foot shows, in px from the car.
func _foot(car_double: Sprite2D) -> Vector2:
	return _from_car(car_double) + car_double.offset + Vector2(CarController.FOOT)


## How far down from the car the bottom edge of what shows of the double is, in px.
func _double_bottom(car_double: Sprite2D) -> float:
	return _from_car(car_double).y + car_double.offset.y + car_double.region_rect.size.y


## How far down from the car the top and the bottom edges of what shows of the worm are, in px.
func _worm_top(worm: Sprite2D) -> float:
	return _from_car(worm).y + worm.offset.y


func _worm_bottom(worm: Sprite2D) -> float:
	return _worm_top(worm) + worm.region_rect.size.y


## The largest change between one of `heights` and the next.
static func _largest_step(heights: Array[float]) -> float:
	var most := 0.0
	for k: int in range(1, heights.size()):
		most = maxf(most, absf(heights[k] - heights[k - 1]))
	return most


## How far `offset` moves the view, in world px, for a shake of `share` of the params' intensity.
func _shake_px(share: float) -> float:
	return share * _params.intensity * Tuning.SHAKE_PX / _camera.zoom.x


## How many opaque texels the row `row` of `frame` of the worm's sheet has.
static func _width(sheet: Image, frame: int, row: int) -> int:
	var count := 0
	for x: int in DeathWorm.WORM.x:
		if sheet.get_pixel(frame * DeathWorm.WORM.x + x, row).a > 0.0:
			count += 1
	return count


## Whether `color` is one of `colors`.
static func _one_of(color: Color, colors: Array[Color]) -> bool:
	for each: Color in colors:
		if each.is_equal_approx(color):
			return true
	return false


## Whether `item` adds light.
static func _adds_light(item: CanvasItem) -> bool:
	var material := item.material as CanvasItemMaterial
	return material != null and material.blend_mode == CanvasItemMaterial.BLEND_MODE_ADD


func test_the_ground_trembles_and_ripples_run_through_the_sand_to_the_car() -> void:
	# From DEATH_WORM_BURROW_TILES tiles away, where the direction points in tile space, or from the
	# right for none. In the glare of the desert: no veil, and so no glows (docs/M6.md §5.5).
	var froms: Dictionary[Vector2, Vector2] = {
		Vector2(0.6, -0.8): Vector2(0.6, -0.8),
		Vector2(-2.0, 0.0): Vector2.LEFT,
		Vector2.ZERO: Vector2.RIGHT,
	}
	for direction: Vector2 in froms:
		var tiles := Iso.world_to_tile(DeathWorm.burrow_from(direction))
		var expected := froms[direction] * Tuning.DEATH_WORM_BURROW_TILES
		assert_almost_eq(tiles, expected, NEAR, "%s: where they start" % direction)
	var ends := _ends()
	var legend := _legend()
	assert_eq(legend.veil_kind, Legend.Veil.NONE, "no veil")
	for item: CanvasItem in Disasters.drawables(legend):
		assert_false(_adds_light(item), "%s: no glow" % item.name)
	var burrow := legend.get_node("%Burrow") as CPUParticles2D
	var from := DeathWorm.burrow_from(_params.direction)
	_step_to(legend, -2.0 * DELTA)
	assert_eq(_camera.offset, Vector2.ZERO, "still through the delay")
	assert_false(burrow.emitting, "no ripples yet")
	var distances: Array[float] = []
	var on_the_way := true
	var trembling := true
	var tremor := _shake_px(Tuning.DEATH_WORM_TREMOR)
	while _short_of(ends[1]):
		# The camera steps first, as in the game (Legend.PHYSICS_PRIORITY): unstepped, it would
		# hold a shake's first offset however short the shake.
		simulate(_camera, 1, DELTA)
		_step(legend)
		var shake := maxf(absf(_camera.offset.x), absf(_camera.offset.y))
		trembling = trembling and shake > 0.0 and shake <= tremor + NEAR.x
		if burrow.emitting:
			var at := _from_car(burrow)
			distances.append(at.length())
			on_the_way = on_the_way and absf(at.cross(from.normalized())) < NEAR.x
			on_the_way = on_the_way and at.dot(from) >= 0.0
	assert_true(trembling, "the ground trembles until the worm bursts out")
	if distances.is_empty():
		fail_test("ripples run")
		return
	assert_gt(distances[0], from.length() * 0.9, "from there")
	assert_true(on_the_way, "straight to the car")
	assert_eq(distances, Disasters.sorted(distances, true), "only nearer")
	assert_false(burrow.emitting, "gone under the car")
	assert_almost_eq(_from_car(burrow), Vector2.ZERO, NEAR, "under it")


func test_a_mound_swells_under_the_car_and_lifts_it_shuddering() -> void:
	var ends := _ends()
	var legend := _legend()
	var mound := legend.get_node("%Mound") as Sprite2D
	_step_to(legend, _middle(0))
	assert_null(_double(legend), "the car is still there")
	assert_eq(_car.modulate.a, 1.0, "the car shows")
	assert_false(Disasters.shows(mound), "no mound yet")
	_step_to(legend, ends[0])
	var car_double := _double(legend)
	if car_double == null:
		fail_test("it took the car")
		return
	assert_eq(_car.modulate.a, 0.0, "the double took the car's place")
	var sizes: Array[float] = []
	var lifts: Array[float] = []
	var shudder: Array[float] = []
	var riding := true
	var whole := true
	var smooth := true
	while not _reached(ends[1]):
		sizes.append(mound.scale.x)
		var foot := _foot(car_double)
		lifts.append(-foot.y)
		if foot.x != 0.0 and foot.x not in shudder:
			shudder.append(foot.x)
		riding = riding and is_equal_approx(-foot.y, DeathWorm.MOUND_LIFT * mound.scale.x)
		whole = whole and car_double.region_rect.size.y == CarController.FRAME_SIZE.y
		whole = whole and car_double.modulate.a == 1.0
		smooth = smooth and mound.frame == 0
		_step(legend)
	# The step that ends the beat starts the burst.
	_step(legend)
	var short := 2.0 * DELTA / Tuning.DEATH_WORM_BEATS[1]
	assert_lt(sizes[0], 0.25, "from nothing")
	assert_eq(sizes, Disasters.sorted(sizes), "it only swells")
	assert_gte(sizes[-1], 1.0 - short * short, "to its full size")
	assert_true(smooth, "smooth as it swells")
	assert_almost_eq(_from_car(mound), Vector2.ZERO, NEAR, "under the car")
	assert_eq(mound.get_parent(), legend, "flat, under the props")
	assert_true(riding, "the double rides up on it")
	assert_true(whole, "whole")
	assert_eq(lifts, Disasters.sorted(lifts), "only up")
	shudder.sort()
	var px := DeathWorm.SHUDDER_PX
	assert_eq(shudder, [-px, px] as Array[float], "it shudders")
	assert_eq(_foot(car_double).x, 0.0, "then stills")
	assert_lte(_foot(car_double).y, -DeathWorm.MOUND_LIFT, "on top")


func test_the_worm_bursts_up_out_of_the_cracked_mound_carrying_the_double_on_its_head() -> void:
	var ends := _ends()
	var legend := _legend()
	var worm := _worm(legend)
	var mound := legend.get_node("%Mound") as Sprite2D
	var crater := legend.get_node("%Crater") as Sprite2D
	var spray := legend.get_node("%Spray") as CPUParticles2D
	var risen := _at(2, DeathWorm.RISE_SHARE)
	_step_to(legend, _middle(1))
	assert_false(Disasters.shows(worm), "under the sand")
	assert_false(spray.emitting, "no spray yet")
	while _short_of(ends[1]):
		_step(legend)
	assert_false(Disasters.shows(worm), "still under the sand")
	var car_double := _double(legend)
	if car_double == null:
		fail_test("it took the car")
		return
	assert_eq(worm.get_parent(), _stage, "on the stage")
	assert_eq(Disasters.z(worm), Disasters.z(car_double), "with the double")
	assert_lt(_from_car(worm).y, _from_car(car_double).y, "behind it, so the double sorts in front")
	# From none of it.
	var tops: Array[float] = [0.0]
	var riding := true
	var standing := true
	var cracked := true
	var sprays := true
	while _short_of(risen):
		_step(legend)
		cracked = cracked and mound.frame == 1
		cracked = cracked and is_equal_approx(mound.modulate.a + crater.modulate.a, 1.0)
		if _clear_of(2, DeathWorm.SPRAY_SHARE):
			sprays = sprays and spray.emitting == (_through(2) < DeathWorm.SPRAY_SHARE)
		if not Disasters.shows(worm):
			continue
		tops.append(-_worm_top(worm))
		standing = standing and worm.frame == DeathWorm.RISING
		standing = standing and absf(_worm_bottom(worm)) < NEAR.y
		var left := _from_car(worm).x + worm.offset.x
		standing = standing and is_equal_approx(left, -DeathWorm.WORM.x / 2.0)
		var on_head := minf(-DeathWorm.MOUND_LIFT, _worm_top(worm) + DeathWorm.TIP)
		riding = riding and is_equal_approx(_foot(car_double).y, on_head)
		riding = riding and car_double.region_rect.size.y == CarController.FRAME_SIZE.y
	# The camera isn't stepped, so it holds the last shake's first offset.
	assert_gt(_camera.offset.length(), _shake_px(Tuning.DEATH_WORM_TREMOR), "it bursts out")
	assert_true(cracked, "the mound cracks open, and the crater shows as it goes")
	assert_true(sprays, "the sand sprays as it bursts out")
	assert_true(standing, "it rises, shut, standing on the ground")
	assert_true(riding, "the double rides on its head, whole")
	_step_to(legend, risen)
	tops.append(-_worm_top(worm))
	assert_eq(tops, Disasters.sorted(tops), "only up")
	assert_lte(_largest_step(tops), MOST_A_FRAME * DeathWorm.WORM.y, "bit by bit")
	assert_eq(tops[-1], float(DeathWorm.WORM.y), "up to its full height")
	assert_eq(crater.modulate.a, 1.0, "the crater shows")
	assert_false(Disasters.shows(mound), "the mound is gone")


func test_its_mouth_opens_and_the_double_sinks_down_its_throat() -> void:
	var legend := _legend()
	var worm := _worm(legend)
	var shut := _at(2, DeathWorm.SWALLOW_TO)
	_step_to(legend, _at(2, DeathWorm.RISE_SHARE))
	var car_double := _double(legend)
	if car_double == null:
		fail_test("it took the car")
		return
	var mouth := float(DeathWorm.MOUTH - DeathWorm.WORM.y)
	var lip := float(DeathWorm.LIP - DeathWorm.WORM.y)
	var open := true
	var dropped_in := true
	var at_the_lip := true
	# The least of the double that showed, in px of its height.
	var least := INF
	var lifts: Array[float] = []
	var kept: Array[float] = []
	var alphas: Array[float] = []
	while not _reached(shut - DELTA):
		open = open and worm.frame == DeathWorm.OPEN
		if _through(2) < DeathWorm.SWALLOW_FROM and _clear_of(2, DeathWorm.SWALLOW_FROM):
			dropped_in = dropped_in and is_equal_approx(_foot(car_double).y, mouth)
		if car_double.region_rect.size.y > 0.0:
			at_the_lip = at_the_lip and Disasters.shows(car_double)
			at_the_lip = at_the_lip and absf(_double_bottom(car_double) - lip) <= HALF_TEXEL
			if Disasters.shows(car_double):
				least = minf(least, car_double.region_rect.size.y)
		lifts.append(-_foot(car_double).y)
		kept.append(car_double.region_rect.size.y)
		alphas.append(car_double.modulate.a)
		_step(legend)
	_step_to(legend, shut)
	lifts.append(-_foot(car_double).y)
	kept.append(car_double.region_rect.size.y)
	alphas.append(car_double.modulate.a)
	assert_true(open, "its mouth opens")
	assert_true(dropped_in, "the double drops into it")
	assert_true(at_the_lip, "and what is left of it shows, down to its front lip")
	assert_lte(least, CarController.FRAME_SIZE.y / 2.0, "in sight till most of it has sunk")
	assert_eq(lifts, Disasters.sorted(lifts, true), "it only sinks")
	assert_lt(lifts[-1], lifts[0], "it sinks")
	assert_eq(kept, Disasters.sorted(kept, true), "less of it shows")
	assert_eq(alphas, Disasters.sorted(alphas, true), "it only goes")
	assert_eq(car_double.region_rect.size.y, 0.0, "down its throat")
	assert_eq(car_double.modulate.a, 0.0, "gone")
	assert_eq(worm.frame, DeathWorm.SHUT, "its mouth shuts")


func test_the_swallow_goes_down_its_body_as_it_dives_back_into_the_sand() -> void:
	var ends := _ends()
	var legend := _legend()
	var worm := _worm(legend)
	var spray := legend.get_node("%Spray") as CPUParticles2D
	var frames: Array[int] = []
	var heights: Array[float] = []
	var standing := true
	var splash := true
	var splashed := false
	while _short_of(ends[3]):
		_step(legend)
		if Disasters.shows(worm):
			if frames.is_empty() or frames[-1] != worm.frame:
				frames.append(worm.frame)
			standing = standing and absf(_worm_bottom(worm)) < NEAR.y
		if not _reached(ends[2]):
			continue
		heights.append(worm.region_rect.size.y)
		if _through(3) < DeathWorm.DIVE_FROM and _clear_of(3, DeathWorm.DIVE_FROM):
			standing = standing and heights[-1] == DeathWorm.WORM.y
		if _clear_of(3, DeathWorm.SPLASH_FROM):
			splash = splash and spray.emitting == (_through(3) > DeathWorm.SPLASH_FROM)
		splashed = splashed or spray.emitting
	var expected: Array[int] = [
		DeathWorm.RISING, DeathWorm.OPEN, DeathWorm.SHUT, DeathWorm.SWALLOWING, DeathWorm.DOWN
	]
	assert_eq(frames, expected, "shut, open, then the swallow lower and lower")
	assert_true(standing, "standing on the ground, at its full height till it dives")
	assert_true(splash and splashed, "the sand sprays again as it goes under")
	_step_to(legend, ends[3])
	assert_false(Disasters.shows(worm), "gone under")
	heights.append(worm.region_rect.size.y)
	assert_eq(heights, Disasters.sorted(heights, true), "it only goes down")
	assert_eq(heights[-1], 0.0, "all of it")
	assert_lte(_largest_step(heights), MOST_A_FRAME * DeathWorm.WORM.y, "bit by bit")
	_step_to(legend, _middle(4))
	assert_false(spray.emitting, "the sand settles")


func test_it_leaves_a_crater_where_the_car_stood() -> void:
	# What it leaves behind still shows once it has finished (N31).
	var legend := _legend()
	var crater := legend.get_node("%Crater") as Sprite2D
	_step_to(legend, _middle(1))
	assert_eq(crater.modulate.a, 0.0, "no crater yet")
	_step_to(legend, _ends()[4] + 0.5)
	assert_true(Disasters.shows(crater), "its crater shows")
	assert_eq(crater.modulate.a, 1.0, "in full")
	assert_almost_eq(_from_car(crater), Vector2.ZERO, NEAR, "where the car was")
	assert_eq(crater.get_parent(), legend, "flat, under the props")
	assert_false(Disasters.shows(legend.get_node("%Mound") as Sprite2D), "the mound is gone")
	assert_false(Disasters.shows(_worm(legend)), "the worm is gone")
	assert_false((legend.get_node("%Spray") as CPUParticles2D).emitting, "the sand has settled")


func test_its_open_mouth_shows_only_teeth_round_a_black_throat() -> void:
	# Q8: scary, with no gore. Nothing of its flesh shows inside its gums: only its throat, black,
	# the gums, dark, and white teeth, which ring it all round. The throat's front edge is LIP.
	var sheet := _worm(_legend()).texture.get_image()
	var palette := Art.MakeArt.palette()
	var allowed: Array[Color] = [
		palette["ink"], palette["line"], palette["shadow"], palette["white"]
	]
	var centre := Vector2(DeathWorm.WORM.x / 2.0, DeathWorm.MOUTH)
	var throat := Vector2(DeathWorm.THROAT)
	var gums := throat * 1.25
	var flesh: Array[Vector2i] = []
	var black := 0
	var teeth: Dictionary[Vector2i, bool] = {}
	for y: int in DeathWorm.WORM.y:
		for x: int in DeathWorm.WORM.x:
			var at := Vector2(x, y) + Vector2(0.5, 0.5) - centre
			if (at / gums).length_squared() > 1.0:
				continue
			var color := sheet.get_pixel(DeathWorm.OPEN * DeathWorm.WORM.x + x, y)
			if not _one_of(color, allowed):
				flesh.append(Vector2i(x, y))
			if (at / throat).length_squared() <= 1.0 and color.is_equal_approx(palette["ink"]):
				black += 1
			if color.is_equal_approx(palette["white"]):
				teeth[Vector2i(signi(int(at.x)), signi(int(at.y)))] = true
	assert_eq(flesh, [] as Array[Vector2i], "texels of flesh in its mouth")
	assert_gt(black, roundi(PI * throat.x * throat.y / 2.0), "a black throat")
	assert_eq(teeth.size(), 4, "white teeth all round it")
	var middle := DeathWorm.OPEN * DeathWorm.WORM.x + (DeathWorm.WORM.x >> 1)
	var inside := sheet.get_pixel(middle, DeathWorm.LIP - 1)
	assert_true(inside.is_equal_approx(palette["ink"]), "black down to its front edge")
	assert_false(sheet.get_pixel(middle, DeathWorm.LIP).is_equal_approx(palette["ink"]), "at LIP")


func test_it_stands_on_its_bottom_row_and_the_swallow_goes_down_its_body() -> void:
	var sheet := _worm(_legend()).texture.get_image()
	var bottom := DeathWorm.WORM.y - 1
	for frame: int in DeathWorm.FRAMES:
		assert_gt(_width(sheet, frame, bottom), 0, "%d: on its bottom row" % frame)
	var swallows: Array[int] = []
	for frame: int in [DeathWorm.SHUT, DeathWorm.SWALLOWING, DeathWorm.DOWN]:
		var widest := 0
		var at := -1
		for row: int in DeathWorm.WORM.y:
			var wider := _width(sheet, frame, row) - _width(sheet, DeathWorm.RISING, row)
			if wider > widest:
				widest = wider
				at = row
		assert_gte(widest, BULGE_PX, "%d: the swallow bulges its body" % frame)
		swallows.append(at)
	assert_lt(swallows[0], swallows[1], "SWALLOWING's under SHUT's")
	assert_lt(swallows[1], swallows[2], "DOWN's under SWALLOWING's")
