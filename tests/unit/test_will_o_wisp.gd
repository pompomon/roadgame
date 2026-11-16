extends GutTest
## The Will-o'-the-Wisp, the Meadows' third legend (POOLS_PLAN.md §5.4). Night falls, and four pale
## wisps glimmer out over the meadow round the car, one after another. They circle it, closing in,
## and it shrinks into a light at its middle, a fifth wisp, as tufts of bog cotton sprout where it
## stood and their seeds blow up. The five drift off together, up the screen, and fade. The bog
## cotton stays.

const Disasters := preload("res://tests/helpers/disaster_fixtures.gd")
const Art := preload("res://tests/helpers/art_checks.gd")
const WILL_O_WISP := preload("res://disasters/legends/will_o_wisp.tscn")
const MEADOWS := preload("res://areas/meadows.tres")
const GLOW := preload("res://disasters/glow.tres")
const DELTA := 1.0 / 60.0
## How near a place must be, in px.
const NEAR := Vector2(0.001, 0.001)
## How near an alpha must be: a colour holds 32-bit floats.
const NEAR_ALPHA := 1e-6
## How near a share of the ring's radii must be, and an angle round it, in radians.
const NEAR_SPREAD := 1e-4
const NEAR_ANGLE := 1e-4
## How much further than its average stride over a beat a part may go in a frame of it, or how much
## more it may shrink: slow at each end, at its fastest each goes half as far again.
const GLIDE := 2.0
## The most turns a second that the plan lets them circle (§5.4).
const CIRCLE_MOST_HZ := 0.5
## How many times the light at a point may rise in any FLASH_SECONDS as they circle: four pass
## each point of their ring each turn, at most half a turn a second (§5.4, §5.6).
const RISES_MOST := 2
## The car's headings, as tile directions: the roads run along the tile axes.
const HEADINGS: Array[Vector2] = [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]

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


## The Will-o'-the-Wisp, playing for the car with the car's place as its origin, as the director
## gives it, its direction `direction`, the car heading `heading`, a tile direction.
func _wisp(direction := Vector2(0.6, -0.8), heading := Vector2.UP) -> WillOWisp:
	_car.modulate.a = 1.0
	# CarSim.forward() is (sin a, -cos a). The car's body shows the frame for its heading only once
	# it steps, which it doesn't here.
	_car.sim.angle = atan2(heading.x, -heading.y)
	(_car.get_node("%Body") as Sprite2D).frame = CarController.frame(heading)
	var wisp := Disasters.disaster(self, WILL_O_WISP, _car, _camera) as WillOWisp
	wisp.stage = _stage
	_params = Disasters.params()
	_params.direction = direction
	_params.origin_world = _car.global_position
	_frames = 0
	wisp.play(_params)
	return wisp


## Directions in the params, and the side of the screen that each sends them off to, 1 for the
## right: a tile direction that shows to the right of the car, or none, sends them right.
static func _sides() -> Dictionary[Vector2, float]:
	return {
		Vector2.UP: 1.0,
		Vector2.RIGHT: 1.0,
		Vector2.ONE: 1.0,
		Vector2.ZERO: 1.0,
		Vector2.DOWN: -1.0,
		Vector2.LEFT: -1.0,
		Vector2(-1.0, 0.5): -1.0,
	}


## When each beat ends, in seconds after the delay.
static func _ends() -> Array[float]:
	var ends: Array[float] = []
	var sum := 0.0
	for length: float in Tuning.WILL_O_WISP_BEATS:
		sum += length
		ends.append(sum)
	return ends


## When `share` of `beat` is done, in seconds after the delay.
static func _at(beat: int, share: float) -> float:
	return _ends()[beat] - Tuning.WILL_O_WISP_BEATS[beat] * (1.0 - share)


## The share of a beat at which the `k`th of `count` parts starts its turn, each taking `share` of
## the beat, the rest spread evenly over the waits between them.
static func _turn_start(k: int, count: int, share: float) -> float:
	return (1.0 - share) * k / (count - 1)


## Steps `wisp` on to `seconds` after its delay, and a frame or two past it: a clock that sums
## frames can fall short of the sum by a hair.
func _step_to(wisp: WillOWisp, seconds: float) -> void:
	var target := ceili((_params.delay + seconds) / DELTA) + 1
	simulate(wisp, target - _frames, DELTA)
	_frames = target


## Steps `wisp` one frame.
func _step(wisp: WillOWisp) -> void:
	simulate(wisp, 1, DELTA)
	_frames += 1


## Whether `wisp` has stepped on to `seconds` after its delay.
func _reached(seconds: float) -> bool:
	return _frames * DELTA >= _params.delay + seconds


## How far the steps have gone through `beat`, from 0 at its start to 1 at its end.
func _through(beat: int) -> float:
	return (_frames * DELTA - _params.delay - _at(beat, 0.0)) / Tuning.WILL_O_WISP_BEATS[beat]


## Whether a step from here stays half a frame short of `seconds` after the delay, so that the
## legend's clock and theirs agree that it has not got there.
func _short_of(seconds: float) -> bool:
	return (_frames + 1) * DELTA < _params.delay + seconds - DELTA / 2.0


## Whether the steps are more than a frame away from `share` of `beat`, so that the legend's clock
## and theirs agree on which side of it they are.
func _clear_of(beat: int, share: float) -> bool:
	return absf(_through(beat) - share) > DELTA / Tuning.WILL_O_WISP_BEATS[beat]


## Where `part` is, in px from the car.
func _from_car(part: Node2D) -> Vector2:
	return part.global_position - _car.global_position


## Where `light` is from the middle of the ring, `moved` px from the car's middle, as a share of
## RING: its length is how many times RING out it is, and its angle how far round.
func _round(light: Sprite2D, moved := Vector2.ZERO) -> Vector2:
	return (_from_car(light) - WitchHex.car_middle() - moved) / WillOWisp.RING


## Whether `a` is within NEAR of `b`.
static func _near(a: Vector2, b: Vector2) -> bool:
	return absf(a.x - b.x) <= NEAR.x and absf(a.y - b.y) <= NEAR.y


## Its four circling wisps, in the order they glimmer.
static func _wisps(wisp: WillOWisp) -> Array[Sprite2D]:
	var found: Array[Sprite2D] = []
	for k: int in WillOWisp.WISPS:
		found.append(wisp.get_node("%%Wisp%d" % (k + 1)) as Sprite2D)
	return found


## The fifth wisp, which the car shrinks into.
static func _fifth(wisp: WillOWisp) -> Sprite2D:
	return wisp.get_node("%Fifth") as Sprite2D


## All five.
static func _lights(wisp: WillOWisp) -> Array[Sprite2D]:
	var found := _wisps(wisp)
	found.append(_fifth(wisp))
	return found


## The car's double, which the legend has put on the stage once it has taken the car, or null.
static func _double(wisp: WillOWisp) -> Sprite2D:
	for part: Sprite2D in wisp.staged():
		if part not in wisp.standing:
			return part
	return null


## The frame of the car's sheet that `car_double` shows.
static func _frame_of(car_double: Sprite2D) -> int:
	return roundi(car_double.region_rect.position.x / CarController.FRAME_SIZE.x)


## The share of the opaque pixels of frame `frame` of `tuft`'s sheet that are white.
static func _white(tuft: Sprite2D, frame: int) -> float:
	var size := WillOWisp.TUFT
	var image := tuft.texture.get_image().get_region(Rect2i(frame * size.x, 0, size.x, size.y))
	var share: float = Art.shares(image).get(Art.MakeArt.palette()["white"], 0.0)
	return share


## What of `wisp` adds light: what it draws, what it has put on the stage, and its particles.
static func _glows(wisp: WillOWisp) -> Array[CanvasItem]:
	var items := Disasters.drawables(wisp)
	for emitter: CPUParticles2D in Disasters.particles(wisp):
		items.append(emitter)
	var found: Array[CanvasItem] = []
	for item: CanvasItem in items:
		var material := Disasters.material_of(item) as CanvasItemMaterial
		if material != null and material.blend_mode == CanvasItemMaterial.BLEND_MODE_ADD:
			found.append(item)
	return found


## `values`, each once until it changes.
static func _changes(values: Array[int]) -> Array[int]:
	var found: Array[int] = []
	for value: int in values:
		if found.is_empty() or found[-1] != value:
			found.append(value)
	return found


## The `k`th value of each of `rows`.
static func _column(rows: Array[PackedFloat32Array], k: int) -> Array[float]:
	var found: Array[float] = []
	for row: PackedFloat32Array in rows:
		found.append(row[k])
	return found


## The most of `frames`, in order, that fall in any `window` frames in a row.
static func _most_in(frames: PackedInt32Array, window: int) -> int:
	var most := 0
	var first := 0
	for k: int in frames.size():
		while frames[k] - frames[first] >= window:
			first += 1
		most = maxi(most, k - first + 1)
	return most


func test_night_falls_and_four_wisps_glimmer_round_the_car_one_after_another() -> void:
	# Round its middle, FAR times as far out as they will circle, each a quarter turn on from the
	# last, clockwise. Each is dark till its turn, then brightens over SHOW_SHARE of the glimmer to
	# as bright as it shows, the turns spread over the glimmer. The car is still there.
	var ends := _ends()
	var wisp := _wisp()
	var wisps := _wisps(wisp)
	assert_eq(wisp.veil_kind, Legend.Veil.NIGHT, "night falls")
	var places: Array[Vector2] = []
	for k: int in WillOWisp.WISPS:
		var round_now := _round(wisps[k])
		var which := "wisp %d" % k
		assert_almost_eq(round_now.length(), WillOWisp.FAR, NEAR_SPREAD, "%s: FAR out" % which)
		if k > 0:
			var turned := wrapf(round_now.angle() - _round(wisps[k - 1]).angle(), -PI, PI)
			assert_almost_eq(turned, TAU / 4.0, NEAR_ANGLE, "%s: a quarter turn on" % which)
		places.append(_from_car(wisps[k]))
	var still := true
	var dark := true
	var lit := true
	var one_size := true
	var there := true
	var alphas: Array[PackedFloat32Array] = []
	while not _reached(ends[0]):
		var shut: Array[bool] = []
		for k: int in WillOWisp.WISPS:
			shut.append(_short_of(_at(0, _turn_start(k, WillOWisp.WISPS, WillOWisp.SHOW_SHARE))))
		_step(wisp)
		var row := PackedFloat32Array()
		for k: int in WillOWisp.WISPS:
			var light := wisps[k]
			still = still and _near(_from_car(light), places[k])
			one_size = one_size and light.scale == Vector2.ONE * WillOWisp.GLOW_SCALE
			dark = dark and (not shut[k] or light.modulate.a == 0.0)
			var start := _turn_start(k, WillOWisp.WISPS, WillOWisp.SHOW_SHARE)
			if _reached(_at(0, start + WillOWisp.SHOW_SHARE) + DELTA / 2.0):
				lit = lit and absf(light.modulate.a - Tuning.WILL_O_WISP_ALPHA) <= NEAR_ALPHA
			row.append(light.modulate.a)
		alphas.append(row)
		there = there and _double(wisp) == null and _car.modulate.a == 1.0
	assert_true(still, "where they glimmer")
	assert_true(one_size, "small")
	assert_true(dark, "each dark till its turn")
	assert_true(lit, "and as bright as it shows by SHOW_SHARE after")
	assert_true(there, "the car still there")
	var bright := Tuning.WILL_O_WISP_ALPHA
	var glimmer_most := GLIDE * bright * DELTA / (WillOWisp.SHOW_SHARE * ends[0])
	for k: int in WillOWisp.WISPS:
		var mine := _column(alphas, k)
		assert_eq(mine, Disasters.sorted(mine), "wisp %d: it only brightens" % k)
		var gradual := true
		var last := 0.0
		for alpha: float in mine:
			gradual = gradual and alpha - last <= glimmer_most
			last = alpha
		assert_true(gradual, "wisp %d: a little each frame" % k)
		assert_almost_eq(mine[-1], bright, NEAR_ALPHA, "wisp %d: as bright as it shows" % k)


func test_they_circle_it_closing_in_and_speed_up_to_at_most_half_a_turn_a_second() -> void:
	# All together, a quarter turn apart, anticlockwise. A little nearer each frame of the circle,
	# till they are RING round its middle, and no nearer as the car shrinks. They speed up evenly
	# to WILL_O_WISP_CIRCLE_HZ, then keep to it, as bright as they glimmered and one size.
	assert_lte(Tuning.WILL_O_WISP_CIRCLE_HZ, CIRCLE_MOST_HZ, "at most half a turn a second")
	var ends := _ends()
	var beats := Tuning.WILL_O_WISP_BEATS
	var wisp := _wisp()
	var wisps := _wisps(wisp)
	while not _reached(ends[0]):
		_step(wisp)
	var last := _round(wisps[0]).angle()
	var spreads: Array[float] = [_round(wisps[0]).length()]
	var steps: Array[float] = []
	var apart := true
	var on_ring := true
	var steady := true
	var most := Tuning.WILL_O_WISP_CIRCLE_HZ * DELTA * (1.0 + 1e-3)
	while _short_of(ends[2]):
		_step(wisp)
		var spread := _round(wisps[0]).length()
		for k: int in range(1, WillOWisp.WISPS):
			var round_now := _round(wisps[k])
			var turned := wrapf(round_now.angle() - _round(wisps[k - 1]).angle(), -PI, PI)
			apart = apart and absf(turned - TAU / 4.0) <= NEAR_ANGLE
			apart = apart and absf(round_now.length() - spread) <= NEAR_SPREAD
		for light: Sprite2D in wisps:
			steady = steady and absf(light.modulate.a - Tuning.WILL_O_WISP_ALPHA) <= NEAR_ALPHA
			steady = steady and light.scale == Vector2.ONE * WillOWisp.GLOW_SCALE
		var now := _round(wisps[0]).angle()
		# Anticlockwise on the screen, where y runs down: the angle falls.
		steps.append(wrapf(last - now, -PI, PI) / TAU)
		last = now
		if _through(1) <= 1.0:
			spreads.append(spread)
		else:
			on_ring = on_ring and absf(spread - 1.0) <= NEAR_SPREAD
	assert_true(apart, "together, a quarter turn apart")
	assert_true(steady, "as bright as they glimmered, and one size")
	assert_eq(spreads, Disasters.sorted(spreads, true), "closing in")
	var nearer_most := GLIDE * (WillOWisp.FAR - 1.0) * DELTA / beats[1]
	var gradual := true
	for k: int in range(1, spreads.size()):
		gradual = gradual and spreads[k - 1] - spreads[k] <= nearer_most
	assert_true(gradual, "a little each frame")
	assert_almost_eq(spreads[-1], 1.0, nearer_most, "to RING round its middle")
	assert_true(on_ring, "and no nearer as it shrinks")
	assert_gt(steps.min(), 0.0, "anticlockwise, every frame")
	assert_lte(steps.max(), most, "at most WILL_O_WISP_CIRCLE_HZ")
	var speeding := true
	for k: int in range(1, steps.size()):
		speeding = speeding and steps[k] >= steps[k - 1] - NEAR_ANGLE / TAU
	assert_true(speeding, "speeding up, never slowing")
	var full := Tuning.WILL_O_WISP_CIRCLE_HZ * DELTA
	assert_almost_eq(steps[-1], full, NEAR_ANGLE / TAU, "to it")
	var ramp := roundi(WillOWisp.RAMP_SHARE * beats[1] / DELTA)
	assert_almost_eq(steps[ramp], full, NEAR_ANGLE / TAU, "by RAMP_SHARE of the circle")
	assert_lt(steps[ramp - 1], full - NEAR_ANGLE / TAU, "not before")


func test_the_car_shrinks_into_a_fifth_wisp_at_its_middle_paling_to_its_colour() -> void:
	# Its double takes its place as the shrink starts, in the same frame, facing as it did, with
	# the props. Its middle stays at the car's middle as it shrinks, a little each frame, to
	# GONE_SCALE, paling to the wisps' colour as it fades out. The fifth wisp brightens there as it
	# fades, to as bright as the others.
	var ends := _ends()
	var beats := Tuning.WILL_O_WISP_BEATS
	var palette := Art.MakeArt.palette()
	for heading: Vector2 in HEADINGS:
		var what := "heading %s" % heading
		var wisp := _wisp(Vector2(0.6, -0.8), heading)
		var fifth := _fifth(wisp)
		var there := true
		var dark := true
		while _short_of(ends[1]):
			_step(wisp)
			there = there and _double(wisp) == null and _car.modulate.a == 1.0
			dark = dark and fifth.modulate.a == 0.0
		assert_true(there, "%s: the car is there till it shrinks" % what)
		assert_true(dark, "%s: no fifth wisp till then" % what)
		while _double(wisp) == null and not _reached(ends[2]):
			_step(wisp)
		var car_double := _double(wisp)
		if car_double == null:
			fail_test("%s: its double took its place" % what)
			continue
		assert_lt(_through(2), 2.0 * DELTA / beats[2], "%s: as it starts to shrink" % what)
		assert_eq(_car.modulate.a, 0.0, "%s: the double took the car's place" % what)
		assert_true(Disasters.shows(car_double), "%s: in the same frame" % what)
		var facing := CarController.frame(heading)
		assert_eq(_frame_of(car_double), facing, "%s: facing as it did" % what)
		assert_eq(car_double.get_parent(), _stage, "%s: with the props" % what)
		assert_eq(Disasters.z(car_double), 0, "%s: sorting with them" % what)
		assert_true(_near(_from_car(car_double), Vector2.ZERO), "%s: its foot stays" % what)
		var staged: Array[Sprite2D] = wisp.standing.duplicate()
		staged.append(car_double)
		assert_eq(wisp.staged(), staged, "%s: it frees it" % what)
		var middle := WitchHex.car_middle()
		var sizes: Array[float] = [car_double.scale.x]
		var fades: Array[float] = [car_double.modulate.a]
		var tint: Color = palette["wisp"]
		var paling: Array[float] = [_distance(car_double.self_modulate, tint)]
		var brightens: Array[float] = [fifth.modulate.a]
		var kept := _near(_centre(car_double), middle)
		var shrink_most := GLIDE * (1.0 - WillOWisp.GONE_SCALE) * DELTA / beats[2]
		var gradual := 1.0 - car_double.scale.x <= shrink_most
		while not _reached(ends[2]):
			_step(wisp)
			gradual = gradual and sizes[-1] - car_double.scale.x <= shrink_most
			sizes.append(car_double.scale.x)
			fades.append(car_double.modulate.a)
			paling.append(_distance(car_double.self_modulate, tint))
			brightens.append(fifth.modulate.a)
			kept = kept and _near(_centre(car_double), middle)
			kept = kept and _near(_from_car(car_double), Vector2.ZERO)
			kept = kept and _near(_from_car(fifth), middle)
			kept = kept and fifth.scale == Vector2.ONE * WillOWisp.GLOW_SCALE
		assert_true(kept, "%s: at the car's middle, the fifth wisp too, one size" % what)
		assert_true(gradual, "%s: a little each frame" % what)
		assert_eq(sizes, Disasters.sorted(sizes, true), "%s: smaller and smaller" % what)
		var gone := WillOWisp.GONE_SCALE
		assert_almost_eq(sizes[-1], gone, NEAR_ALPHA, "%s: to GONE_SCALE" % what)
		assert_eq(fades, Disasters.sorted(fades, true), "%s: fading" % what)
		assert_false(Disasters.shows(car_double), "%s: till it is gone" % what)
		assert_eq(paling, Disasters.sorted(paling, true), "%s: paling" % what)
		assert_almost_eq(paling[-1], 0.0, NEAR_ALPHA, "%s: to the wisps' colour" % what)
		assert_eq(brightens, Disasters.sorted(brightens), "%s: the fifth brightens" % what)
		var bright := Tuning.WILL_O_WISP_ALPHA
		assert_almost_eq(brightens[-1], bright, NEAR_ALPHA, "%s: as bright as the others" % what)
		assert_eq(_car.modulate.a, 0.0, "%s: the car is gone" % what)


## Where the middle of the double shows, in px from the car: its offset keeps it there as it
## shrinks about its foot. Not by get_rect(), which rounds the offset to whole px, as the project
## snaps 2D transforms to them.
func _centre(car_double: Sprite2D) -> Vector2:
	var middle := car_double.offset + Vector2(CarController.FRAME_SIZE) / 2.0
	return car_double.global_position + car_double.scale * middle - _car.global_position


## How far apart `a` and `b` are, in colour.
static func _distance(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()


func test_bog_cotton_sprouts_where_it_stood_tuft_after_tuft_and_its_seeds_blow_up() -> void:
	# The tufts stand with the props, where play() put them, hidden till the car shrinks. Then each
	# takes SPROUT_SHARE of the shrink to grow, from shoots to buds to white heads, the turns spread
	# over the shrink: more and more of its frame is white. The seeds blow up from over the tufts,
	# under the night, from SEED_SHARE of the shrink till they drift off.
	var ends := _ends()
	var wisp := _wisp()
	var tufts := wisp.standing
	var seeds := wisp.get_node("%Seeds") as CPUParticles2D
	assert_eq(tufts.size(), WillOWisp.TUFTS.size(), "its tufts")
	var white: Array[float] = []
	for frame: int in WillOWisp.TUFT_FRAMES:
		white.append(_white(tufts[0], frame))
	assert_eq(white[0], 0.0, "shoots, with no white")
	assert_gt(white[1], 0.0, "then white buds")
	assert_gt(white[2], white[1], "then white heads, whiter")
	for k: int in tufts.size():
		var which := "tuft %d" % k
		assert_eq(tufts[k].get_parent(), _stage, "%s: with the props" % which)
		assert_eq(Disasters.z(tufts[k]), 0, "%s: sorting with them" % which)
		assert_true(_near(_from_car(tufts[k]), WillOWisp.TUFTS[k]), "%s: where it stood" % which)
		assert_eq(tufts[k].hframes, WillOWisp.TUFT_FRAMES, "%s: its frames" % which)
		var reach := seeds.emission_rect_extents.x
		assert_lte(absf(WillOWisp.TUFTS[k].x - seeds.position.x), reach, "%s: seeds" % which)
	assert_lt(seeds.direction.y, 0.0, "the seeds blow up")
	assert_lt(seeds.gravity.y, 0.0, "and float")
	assert_lt(Disasters.z(seeds), Tuning.VEIL_Z, "under the night")
	var hidden := true
	var still := true
	while _short_of(ends[1]):
		_step(wisp)
		for tuft: Sprite2D in tufts:
			hidden = hidden and not Disasters.shows(tuft)
		still = still and not seeds.emitting
	assert_true(hidden, "no bog cotton till it shrinks")
	assert_true(still, "and no seeds")
	var frames: Array[Array] = []
	for tuft: Sprite2D in tufts:
		frames.append([-1])
	var in_turn := true
	var blows := true
	while not _reached(ends[2]):
		var waiting: Array[bool] = []
		for k: int in tufts.size():
			var start := _turn_start(k, tufts.size(), WillOWisp.SPROUT_SHARE)
			waiting.append(_short_of(_at(2, start)))
		_step(wisp)
		for k: int in tufts.size():
			var tuft := tufts[k]
			frames[k].append(tuft.frame if Disasters.shows(tuft) else -1)
			in_turn = in_turn and (not waiting[k] or not Disasters.shows(tuft))
		if _short_of(ends[2]) and _clear_of(2, WillOWisp.SEED_SHARE):
			blows = blows and seeds.emitting == (_through(2) > WillOWisp.SEED_SHARE)
	assert_true(in_turn, "each in its turn")
	assert_true(blows, "the seeds blow up from SEED_SHARE of the shrink")
	for k: int in tufts.size():
		var grown: Array[int] = []
		grown.assign(frames[k])
		assert_eq(_changes(grown), [-1, 0, 1, 2] as Array[int], "tuft %d: frame by frame" % k)
	assert_true(Disasters.particles_show(seeds), "the seeds show")
	_step(wisp)
	assert_false(seeds.emitting, "till they drift off")


func test_the_five_drift_off_together_up_the_screen_and_fade_and_the_bog_cotton_stays() -> void:
	# To the side that its direction picks, slow at each end, still circling, the fifth among them.
	# As bright as they were till FADE_FROM of the drift, then dimmer each frame till none shows.
	# The tufts stay, full grown, where they sprouted, once it has finished.
	var ends := _ends()
	var sides := _sides()
	var beats := Tuning.WILL_O_WISP_BEATS
	var way := Tuning.WILL_O_WISP_DRIFT_PX
	var stride_most := GLIDE * way.length() * DELTA / beats[3]
	for direction: Vector2 in sides:
		var what := str(direction)
		var side := sides[direction]
		var wisp := _wisp(direction)
		var wisps := _wisps(wisp)
		var fifth := _fifth(wisp)
		watch_signals(wisp)
		while _short_of(ends[2]):
			_step(wisp)
		var last := Vector2.ZERO
		var turned_last := _round(wisps[0]).angle()
		var across: Array[float] = []
		var ups: Array[float] = []
		var strides: Array[float] = []
		var gradual := true
		var together := true
		var turning := true
		var bright := true
		var fading: Array[float] = []
		while not _reached(ends[3]):
			_step(wisp)
			var moved := _from_car(fifth) - WitchHex.car_middle()
			strides.append(moved.distance_to(last))
			gradual = gradual and strides[-1] <= stride_most
			last = moved
			across.append(moved.x * side)
			ups.append(moved.y)
			var alpha := fifth.modulate.a
			for light: Sprite2D in wisps:
				var round_now := _round(light, moved)
				together = together and absf(round_now.length() - 1.0) <= NEAR_SPREAD
				together = together and absf(light.modulate.a - alpha) <= NEAR_ALPHA
			# Anticlockwise on the screen, where y runs down: the angle falls.
			var turned_now := _round(wisps[0], moved).angle()
			turning = turning and wrapf(turned_last - turned_now, -PI, PI) > 0.0
			turned_last = turned_now
			if _short_of(_at(3, WillOWisp.FADE_FROM)):
				bright = bright and absf(alpha - Tuning.WILL_O_WISP_ALPHA) <= NEAR_ALPHA
			elif _clear_of(3, WillOWisp.FADE_FROM):
				fading.append(alpha)
		# One frame more: the legend's clock sums its frames, so it can end the drift a frame later.
		_step(wisp)
		var went := _from_car(fifth) - WitchHex.car_middle()
		assert_almost_eq(went, Vector2(side * way.x, way.y), NEAR, "%s: DRIFT_PX" % what)
		assert_eq(across, Disasters.sorted(across), "%s: to its side" % what)
		assert_eq(ups, Disasters.sorted(ups, true), "%s: up the screen" % what)
		assert_true(gradual, "%s: a little each frame" % what)
		var mean := way.length() / strides.size()
		# The first frame stepped leaves them where they were: it is the shrink's last, or the
		# drift's start, as the legend's clock sums its frames. So the first that moves them.
		var first := 0
		while first < strides.size() - 1 and strides[first] <= NEAR.length():
			first += 1
		assert_gt(strides[first], NEAR.length(), "%s: they drift" % what)
		assert_lt(strides[first], mean / 2.0, "%s: slow as it starts" % what)
		assert_lt(strides[-1], mean / 2.0, "%s: and as it ends" % what)
		assert_true(together, "%s: together, round the fifth" % what)
		assert_true(turning, "%s: still circling" % what)
		assert_true(bright, "%s: as bright till FADE_FROM" % what)
		var dimmer := true
		for k: int in range(1, fading.size()):
			dimmer = dimmer and fading[k] < fading[k - 1]
		assert_true(dimmer, "%s: then dimmer each frame" % what)
		for light: Sprite2D in _lights(wisp):
			assert_false(Disasters.shows(light), "%s: %s is gone" % [what, light.name])
		_step_to(wisp, Disasters.duration(wisp, _params) - _params.delay + 0.5)
		assert_signal_emit_count(wisp, "finished", 1, "%s: it has finished" % what)
		for k: int in wisp.standing.size():
			var tuft := wisp.standing[k]
			var which := "%s, tuft %d" % [what, k]
			assert_true(Disasters.shows(tuft), "%s: the bog cotton stays" % which)
			assert_eq(tuft.frame, WillOWisp.TUFT_FRAMES - 1, "%s: full grown" % which)
			assert_true(_near(_from_car(tuft), WillOWisp.TUFTS[k]), "%s: where it grew" % which)
		assert_eq(_car.modulate.a, 0.0, "%s: the car is gone" % what)


func test_its_glows_are_its_five_wisps_pale_green_and_steady_each_rising_and_falling_once() -> void:
	# Never red, over the night, one size throughout. Each brightens, then keeps its brightness,
	# then fades, once (§5.4, §5.6). Its seeds don't glow.
	var palette := Art.MakeArt.palette()
	var wisp := _wisp()
	watch_signals(wisp)
	var lights := _lights(wisp)
	var glows: Array[CanvasItem] = []
	glows.assign(lights)
	assert_eq(_glows(wisp), glows, "its only glows")
	for light: Sprite2D in lights:
		var which := str(light.name)
		assert_eq(light.texture, GLOW, "%s: a soft glow" % which)
		assert_true(light.self_modulate.is_equal_approx(palette["wisp"]), "%s: wisp" % which)
		var tint := light.self_modulate
		var red := tint.r >= Tuning.FLASH_RED_SHARE * (tint.r + tint.g + tint.b)
		assert_false(red, "%s: not red" % which)
		assert_eq(Disasters.z(light), Tuning.GLOW_Z, "%s: over the night" % which)
	var alphas: Array[PackedFloat32Array] = []
	var one_size := true
	while get_signal_emit_count(wisp, "finished") == 0 and alphas.size() < Disasters.MAX_FRAMES:
		_step(wisp)
		var row := PackedFloat32Array()
		for light: Sprite2D in lights:
			row.append(light.modulate.a)
			one_size = one_size and light.scale == Vector2.ONE * WillOWisp.GLOW_SCALE
		alphas.append(row)
	assert_true(one_size, "one size")
	for k: int in lights.size():
		var mine := _column(alphas, k)
		var which := str(lights[k].name)
		var peak := mine.find(mine.max())
		var rising := mine.slice(0, peak + 1)
		var falling := mine.slice(peak)
		assert_eq(rising, Disasters.sorted(rising), "%s: it brightens" % which)
		assert_eq(falling, Disasters.sorted(falling, true), "%s: then only fades" % which)
		var bright := Tuning.WILL_O_WISP_ALPHA
		assert_almost_eq(mine[peak], bright, NEAR_ALPHA, "%s: as bright as it shows" % which)
		assert_eq(mine[-1], 0.0, "%s: till it is gone" % which)
	assert_eq(_glows(wisp), glows, "still its only glows, the car taken")


func test_as_they_circle_their_light_rises_at_each_point_at_most_twice_a_second() -> void:
	# test_none_flashes plays them one way, with the car on a point of the grid that the light is
	# added up at. They drift off either way, and a car stops anywhere, so they play with it at each
	# px of a cell of the grid: which points the ring passes over turns on where it is. On each, as
	# they glimmer, circle and close in, their light rises at each point of the world, by more than
	# FLASH_CHANGE of white's, at most twice in any FLASH_SECONDS, though four pass each point of
	# their ring each turn. Drifting off, the ring sweeps points that they passed as they circled,
	# so the light there can rise a third time within the second: as many times as §5.6 allows, and
	# no more.
	var home := _car.position
	for direction: Vector2 in [Vector2.RIGHT, Vector2.LEFT]:
		for y: int in Tuning.FLASH_GRID:
			for x: int in Tuning.FLASH_GRID:
				_car.position = home + Vector2(x, y)
				_check_rises(direction, "drifting %s, the car (%d, %d) px on" % [direction, x, y])


## Plays them for test 7, drifting off to `direction`, and checks how often the light at each point
## rises. `what` says which play.
func _check_rises(direction: Vector2, what: String) -> void:
	var change := Tuning.FLASH_CHANGE * Color.WHITE.get_luminance()
	var window := roundi(Tuning.FLASH_SECONDS / DELTA)
	var wisp := _wisp(direction)
	watch_signals(wisp)
	var lights: Array[Dictionary] = []
	var reds: Array[Dictionary] = []
	var images: Dictionary[Texture2D, Image] = {}
	while get_signal_emit_count(wisp, "finished") == 0:
		if lights.size() >= Disasters.MAX_FRAMES:
			fail_test("%s: it finishes" % what)
			break
		_step(wisp)
		var light: Dictionary[Vector2i, float] = {}
		var red: Dictionary[Vector2i, float] = {}
		for glow: CanvasItem in _glows(wisp):
			Disasters.shine(glow as Sprite2D, light, red, images)
		lights.append(light)
		reds.append(red)
	var points: Dictionary[Vector2i, bool] = {}
	for light: Dictionary in lights:
		for point: Vector2i in light:
			points[point] = true
	assert_gt(points.size(), 0, "%s: they light the world" % what)
	# The frame that lights[k] shows is the (k + 1)th since play().
	var drift_from := _params.delay + _ends()[2] - DELTA / 2.0
	var circling := 0
	for point: Vector2i in points:
		var values := PackedFloat32Array()
		for light: Dictionary in lights:
			values.append(light.get(point, 0.0))
		var before := PackedInt32Array()
		for frame: int in Disasters._turns(values, change)[0]:
			if (frame + 1) * DELTA < drift_from:
				before.append(frame)
		circling = maxi(circling, _most_in(before, window))
	assert_lte(circling, RISES_MOST, "%s: at most twice a second as they circle" % what)
	assert_eq(Disasters.flashing(lights, reds), "", "%s: never flashing" % what)


func test_its_wisps_and_bog_cotton_stand_out_from_the_meadows_by_night() -> void:
	# Its figure is its wisps, glows that add light over the night (POOLS_PLAN.md §5.6, V15, P13b),
	# each drawn as bright as it shows. Its bog cotton stands on the road and the grass, every frame
	# of it as it sprouts.
	var wisp := _wisp()
	for light: Sprite2D in _lights(wisp):
		var tint := Color(light.self_modulate, Tuning.WILL_O_WISP_ALPHA)
		var lit := Art.glow_share(light.texture.get_image(), tint, MEADOWS, wisp.veil_kind)
		var told := "%s: %.0f%% of its pixels stand out" % [light.name, lit * 100.0]
		assert_gte(lit, Art.NIGHT_SHARE, told)
	var tuft := wisp.standing[0]
	var sheet := tuft.texture.get_image()
	var share := Art.night_share(sheet, tuft.hframes, MEADOWS, wisp.veil_kind)
	var what := "the bog cotton: %.0f%% of its pixels stand out" % (share * 100.0)
	assert_gte(share, Art.NIGHT_SHARE, what)
