extends GutTest
## The Mothman, the City's second legend (POOLS_PLAN.md §5.4). Night falls, and two red eyes open in
## a grey shape that perches at the roadside ahead. It spreads its wings, glides over to the car and
## takes it in its talons, and its wingbeats whirl the dust up off the road as it carries the car up
## and out of sight. A grey feather drifts down to the road where the car stood, and stays.

const Disasters := preload("res://tests/helpers/disaster_fixtures.gd")
const Art := preload("res://tests/helpers/art_checks.gd")
const MOTHMAN := preload("res://disasters/legends/mothman.tscn")
const CITY := preload("res://areas/city.tres")
const GLOW := preload("res://disasters/glow.tres")
const DELTA := 1.0 / 60.0
## How near a place must be, in px.
const NEAR := Vector2(0.001, 0.001)
## How near an alpha must be: a colour holds 32-bit floats.
const NEAR_ALPHA := 1e-6
## How near a share of tiles must be: Iso maps tiles to px and back in 32-bit floats.
const NEAR_TILES := 1e-4
## How far from where it hovers it may be on the last frame of its swoop, in px.
const STOPPED_PX := 1.0
## How far the feather may sway short of SWAY_PX, in px: a frame may fall either side of its widest.
const SWAY_SHORT := 0.1
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


## The Mothman, playing for the car with the car's place as its origin, as the director gives it,
## its direction `direction`, the car heading `heading`, a tile direction.
func _mothman(direction := Vector2(0.6, -0.8), heading := Vector2.UP) -> Mothman:
	_car.modulate.a = 1.0
	# CarSim.forward() is (sin a, -cos a).
	_car.sim.angle = atan2(heading.x, -heading.y)
	var mothman := Disasters.disaster(self, MOTHMAN, _car, _camera) as Mothman
	mothman.stage = _stage
	_params = Disasters.params()
	_params.direction = direction
	_params.origin_world = _car.global_position
	_frames = 0
	mothman.play(_params)
	return mothman


## Directions in the params, and the side of the screen that each sends it off to, 1 for the right:
## a tile direction that shows to the right of the car, or none, sends it right.
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
	for length: float in Tuning.MOTHMAN_BEATS:
		sum += length
		ends.append(sum)
	return ends


## When `share` of `beat` is done, in seconds after the delay.
static func _at(beat: int, share: float) -> float:
	return _ends()[beat] - Tuning.MOTHMAN_BEATS[beat] * (1.0 - share)


## Steps `mothman` on to `seconds` after its delay, and a frame or two past it: a clock that sums
## frames can fall short of the sum by a hair.
func _step_to(mothman: Mothman, seconds: float) -> void:
	var target := ceili((_params.delay + seconds) / DELTA) + 1
	simulate(mothman, target - _frames, DELTA)
	_frames = target


## Steps `mothman` one frame.
func _step(mothman: Mothman) -> void:
	simulate(mothman, 1, DELTA)
	_frames += 1


## Whether `mothman` has stepped on to `seconds` after its delay.
func _reached(seconds: float) -> bool:
	return _frames * DELTA >= _params.delay + seconds


## How far the steps have gone through `beat`, from 0 at its start to 1 at its end.
func _through(beat: int) -> float:
	return (_frames * DELTA - _params.delay - _at(beat, 0.0)) / Tuning.MOTHMAN_BEATS[beat]


## Whether a step from here stays half a frame short of `seconds` after the delay, so that the
## legend's clock and theirs agree that it has not got there.
func _short_of(seconds: float) -> bool:
	return (_frames + 1) * DELTA < _params.delay + seconds - DELTA / 2.0


## Whether the steps are more than a frame away from `share` of `beat`, so that the legend's clock
## and theirs agree on which side of it they are.
func _clear_of(beat: int, share: float) -> bool:
	return absf(_through(beat) - share) > DELTA / Tuning.MOTHMAN_BEATS[beat]


## Where `part` is, in px from the car.
func _from_car(part: Node2D) -> Vector2:
	return part.global_position - _car.global_position


## Whether `a` is within NEAR of `b`.
static func _near(a: Vector2, b: Vector2) -> bool:
	return absf(a.x - b.x) <= NEAR.x and absf(a.y - b.y) <= NEAR.y


## Its standing parts, which play() has put on the stage, out of reach of %names, and where the
## stage renames them if an earlier Mothman's are there: the feather, then the Mothman.
static func _feather(mothman: Mothman) -> Sprite2D:
	return mothman.standing[0]


static func _moth(mothman: Mothman) -> Sprite2D:
	return mothman.standing[1]


static func _eyes(moth: Sprite2D) -> Sprite2D:
	return moth.get_node("Eyes") as Sprite2D


## The car's double, which it has taken once it has the car, or null.
static func _double(mothman: Mothman) -> Sprite2D:
	for part: Sprite2D in mothman.staged():
		if part not in mothman.standing:
			return part
	return null


## What of `mothman` adds light.
static func _glows(mothman: Mothman) -> Array[CanvasItem]:
	var found: Array[CanvasItem] = []
	for item: CanvasItem in Disasters.drawables(mothman):
		var material := Disasters.material_of(item) as CanvasItemMaterial
		if material != null and material.blend_mode == CanvasItemMaterial.BLEND_MODE_ADD:
			found.append(item)
	return found


## The texels of `frame` of the Mothman's sheet `sheet` in `color`, as a rect from its foot.
static func _texels(sheet: Image, frame: int, color: Color) -> Rect2:
	var foot := Vector2i(frame * Mothman.FRAME.x + (Mothman.FRAME.x >> 1), Mothman.FRAME.y)
	var found := Rect2()
	var seen := false
	for y: int in range(-Mothman.FRAME.y, 0):
		for x: int in range(-(Mothman.FRAME.x >> 1), Mothman.FRAME.x >> 1):
			if sheet.get_pixelv(foot + Vector2i(x, y)).is_equal_approx(color):
				var texel := Rect2(Vector2(x, y), Vector2.ONE)
				found = found.merge(texel) if seen else texel
				seen = true
	return found


## How wide `frame` of the Mothman's sheet `sheet` spreads, in opaque texels from side to side.
static func _span(sheet: Image, frame: int) -> int:
	var left := Mothman.FRAME.x
	var right := -1
	for y: int in Mothman.FRAME.y:
		for x: int in Mothman.FRAME.x:
			if sheet.get_pixel(frame * Mothman.FRAME.x + x, y).a > 0.0:
				left = mini(left, x)
				right = maxi(right, x)
	return right - left + 1


func test_night_falls_and_two_red_eyes_open_in_a_grey_shape_perched_at_the_roadside_ahead() -> void:
	# Ahead along the car's road, and off it on the side away from the viewer, for each heading.
	var ends := _ends()
	for heading: Vector2 in HEADINGS:
		var perch := Mothman.perch(heading)
		var off_road := Iso.world_to_tile(perch) - heading * Tuning.MOTHMAN_AHEAD_TILES
		assert_almost_eq(off_road.dot(heading), 0.0, NEAR_TILES, "%s: beside the road" % heading)
		var off := off_road.length()
		assert_almost_eq(off, Tuning.MOTHMAN_SIDE_TILES, NEAR_TILES, "%s: off it" % heading)
		assert_lt(Iso.tile_to_world(off_road).y, 0.0, "%s: away from the viewer" % heading)
		var mothman := _mothman(Vector2(0.6, -0.8), heading)
		var moth := _moth(mothman)
		var eyes := _eyes(moth)
		assert_eq(mothman.veil_kind, Legend.Veil.NIGHT, "night falls")
		assert_eq(moth.get_parent(), _stage, "%s: it stands with the props" % heading)
		var perched := true
		var alphas: Array[float] = []
		var shut := true
		var opening: Array[float] = []
		while not _reached(ends[0]):
			var short := _short_of(_at(0, Mothman.EYES_FROM))
			_step(mothman)
			perched = perched and _near(_from_car(moth), perch) and moth.frame == 0
			perched = perched and Disasters.z(moth) == 0
			alphas.append(moth.modulate.a)
			if short:
				shut = shut and eyes.modulate.a == 0.0
			opening.append(eyes.modulate.a)
		_step(mothman)
		assert_true(perched, "%s: perched there, folded, sorting with the props" % heading)
		assert_eq(alphas, Disasters.sorted(alphas), "%s: it only shows more" % heading)
		assert_eq(moth.modulate.a, 1.0, "%s: whole" % heading)
		assert_true(shut, "%s: its eyes shut till it shows" % heading)
		assert_eq(opening, Disasters.sorted(opening), "%s: then only opening" % heading)
		var open := eyes.modulate.a
		assert_almost_eq(open, Tuning.MOTHMAN_EYES_ALPHA, NEAR_ALPHA, "%s: open" % heading)


func test_it_spreads_its_wings_where_it_perches() -> void:
	var ends := _ends()
	var mothman := _mothman()
	var moth := _moth(mothman)
	var sheet := moth.texture.get_image()
	assert_gt(_span(sheet, 1), _span(sheet, 0), "its wings spread wider than it stands folded")
	while _short_of(ends[0]):
		_step(mothman)
	var perch := _from_car(moth)
	var frames: Array[int] = []
	var folded := true
	var still := true
	while _short_of(ends[1]):
		var short := _short_of(_at(1, Mothman.UNFURL_AT))
		_step(mothman)
		if short:
			folded = folded and moth.frame == 0
		if frames.is_empty() or frames[-1] != moth.frame:
			frames.append(moth.frame)
		still = still and _near(_from_car(moth), perch) and Disasters.z(moth) == 0
	assert_true(folded, "folded at first")
	assert_eq(frames, [0, 1] as Array[int], "then its wings spread, once, before it flies")
	assert_true(still, "where it perched, with the props")


func test_it_glides_from_its_perch_to_hover_over_the_car_slowing_to_a_stop() -> void:
	# It nears the car with every frame, and slows from the middle of its swoop: for a heading
	# towards the viewer, it first rises off its perch, as fast as it then glides level.
	var ends := _ends()
	var hover := Mothman.hover()
	for heading: Vector2 in HEADINGS:
		var mothman := _mothman(Vector2(0.6, -0.8), heading)
		var moth := _moth(mothman)
		while _short_of(ends[1]):
			_step(mothman)
		var last := _from_car(moth)
		var distances: Array[float] = [last.distance_to(hover)]
		var strides: Array[float] = []
		var flying := true
		while _short_of(ends[2]):
			_step(mothman)
			var now := _from_car(moth)
			distances.append(now.distance_to(hover))
			if _through(2) >= 0.5:
				strides.append(now.distance_to(last))
			if _clear_of(2, 0.0):
				flying = flying and moth.frame == 2 and Disasters.z(moth) == Tuning.SKY_Z
			last = now
		var what := "heading %s" % heading
		assert_true(flying, "%s: wings spread, in the sky, over the props" % what)
		assert_eq(distances, Disasters.sorted(distances, true), "%s: nearer each frame" % what)
		assert_eq(strides, Disasters.sorted(strides, true), "%s: slowing" % what)
		assert_lt(distances[-1], STOPPED_PX, "%s: to a stop over the car" % what)


func test_it_takes_the_car_in_its_talons_and_carries_it_up_and_out_of_sight() -> void:
	# Faster and faster, off to the side that its direction picks.
	var ends := _ends()
	var sides := _sides()
	for direction: Vector2 in sides:
		var what := str(direction)
		var mothman := _mothman(direction)
		var moth := _moth(mothman)
		var dust := mothman.get_node("%Dust") as CPUParticles2D
		var there := true
		var still := true
		while _short_of(ends[2]):
			_step(mothman)
			there = there and _double(mothman) == null and _car.modulate.a == 1.0
			still = still and not dust.emitting
		assert_true(there, "%s: the car is there till it lifts" % what)
		assert_true(still, "%s: no dust till then" % what)
		while _double(mothman) == null and not _reached(ends[3]):
			_step(mothman)
		var car_double := _double(mothman)
		if car_double == null:
			fail_test("%s: it took the car" % what)
			continue
		assert_eq(_car.modulate.a, 0.0, "%s: the double took the car's place" % what)
		assert_true(Disasters.shows(car_double), "%s: in the same frame" % what)
		assert_eq(car_double.get_parent(), moth, "%s: in its talons" % what)
		assert_true(car_double.show_behind_parent, "%s: behind it" % what)
		assert_lt(Disasters.z(car_double), Tuning.VEIL_Z, "%s: under the night" % what)
		var staged: Array[Sprite2D] = [_feather(mothman), moth, car_double]
		assert_eq(mothman.staged(), staged, "%s: it frees what it stands up" % what)
		assert_almost_eq(_from_car(dust), Vector2.ZERO, NEAR, "%s: off the road" % what)
		assert_lt(Disasters.z(dust), Tuning.VEIL_Z, "%s: the dust under the night" % what)
		var start := _from_car(moth)
		var last := start
		var strides: Array[float] = []
		var alphas: Array[float] = []
		var held := true
		var carrying := true
		var whirls := true
		while not _reached(ends[3]):
			_step(mothman)
			var now := _from_car(moth)
			strides.append(now.distance_to(last))
			alphas.append(moth.modulate.a)
			last = now
			held = held and _near(_from_car(car_double) - now, -Mothman.hover())
			carrying = carrying and moth.frame == 3
			if _clear_of(3, Mothman.DUST_SHARE):
				whirls = whirls and dust.emitting == (_through(3) < Mothman.DUST_SHARE)
		_step(mothman)
		var lifted := _from_car(moth) - Mothman.hover()
		var to := Mothman.lift(sides[direction])
		assert_almost_eq(lifted, to, NEAR, "%s: up and off to its side" % what)
		assert_lt(to.y, 0.0, "%s: up" % what)
		assert_gt(to.x * sides[direction], 0.0, "%s: to its side" % what)
		assert_true(held, "%s: it holds the double, its talons on the roof" % what)
		assert_true(carrying, "%s: carrying it" % what)
		assert_eq(strides, Disasters.sorted(strides), "%s: faster and faster" % what)
		assert_eq(alphas, Disasters.sorted(alphas, true), "%s: it only fades" % what)
		assert_false(Disasters.shows(moth), "%s: out of sight" % what)
		assert_false(Disasters.shows(car_double), "%s: with the double" % what)
		assert_true(whirls, "%s: its wingbeats whirl the dust up as it lifts off" % what)
		assert_false(dust.emitting, "%s: and no more" % what)


func test_a_grey_feather_drifts_down_to_where_the_car_stood_and_stays() -> void:
	# It sways out and back SWAYS times, to one side and then the other, each time tilted the way it
	# goes, and lies on the road. What it leaves still shows once it has finished (N31).
	var ends := _ends()
	var rest := Vector2(-Mothman.FEATHER.x / 2.0, -Mothman.FEATHER.y)
	var tilts: Array[int] = []
	for k: int in Mothman.SWAYS + 1:
		tilts.append(1 if k % 2 == 0 else 0)
	tilts.append(2)
	for direction: Vector2 in _sides():
		var what := str(direction)
		var mothman := _mothman(direction)
		var feather := _feather(mothman)
		watch_signals(mothman)
		var hidden := true
		while _short_of(_at(3, Mothman.FEATHER_FROM)):
			_step(mothman)
			hidden = hidden and not Disasters.shows(feather)
		assert_true(hidden, "%s: none till the Mothman lifts the car" % what)
		var heights: Array[float] = []
		var sways: Array[float] = []
		var frames: Array[int] = []
		var tilted := true
		var foot := true
		while not _reached(ends[3]):
			var before := feather.offset.x
			var tilt := feather.frame
			_step(mothman)
			if not Disasters.shows(feather):
				continue
			foot = foot and _near(_from_car(feather), Vector2.ZERO) and Disasters.z(feather) == 0
			heights.append(rest.y - feather.offset.y)
			sways.append(feather.offset.x - rest.x)
			if frames.is_empty() or frames[-1] != feather.frame:
				frames.append(feather.frame)
			elif feather.frame == tilt and tilt < 2:
				var moved := feather.offset.x - before
				tilted = tilted and (moved >= 0.0 if tilt == 1 else moved <= 0.0)
		var fall := Tuning.MOTHMAN_BEATS[3] * (Mothman.LAND_AT - Mothman.FEATHER_FROM)
		var from := Mothman.FALL_PX
		assert_almost_eq(heights[0], from, from * DELTA / fall, "%s: from where it flies" % what)
		assert_eq(heights, Disasters.sorted(heights, true), "%s: it only falls" % what)
		assert_almost_eq(sways.max(), Mothman.SWAY_PX, SWAY_SHORT, "%s: out to one side" % what)
		assert_almost_eq(sways.min(), -Mothman.SWAY_PX, SWAY_SHORT, "%s: then the other" % what)
		assert_eq(frames, tilts, "%s: tilted each way in turn, then lying" % what)
		assert_true(tilted, "%s: tilted the way it sways" % what)
		assert_true(foot, "%s: its foot where the car stood, with the props" % what)
		_step_to(mothman, Disasters.duration(mothman, _params) - _params.delay + 0.5)
		assert_signal_emit_count(mothman, "finished", 1, "%s: it has finished" % what)
		assert_true(Disasters.shows(feather), "%s: the feather stays" % what)
		assert_eq(feather.frame, 2, "%s: lying" % what)
		assert_almost_eq(feather.offset, rest, NEAR, "%s: on the road" % what)
		assert_almost_eq(_from_car(feather), Vector2.ZERO, NEAR, "%s: where the car was" % what)
		assert_eq(_car.modulate.a, 0.0, "%s: the car is gone" % what)


func test_its_one_glow_is_its_red_eyes_which_light_once_and_stay_lit() -> void:
	var ends := _ends()
	var palette := Art.MakeArt.palette()
	var mothman := _mothman()
	var moth := _moth(mothman)
	var eyes := _eyes(moth)
	assert_eq(_glows(mothman), [eyes] as Array[CanvasItem], "its only glow")
	assert_eq(eyes.texture, GLOW, "a soft glow")
	assert_true(eyes.self_modulate.is_equal_approx(palette["red"]), "red")
	assert_eq(Disasters.z(eyes), Tuning.GLOW_Z, "over the night")
	assert_almost_eq(eyes.scale, Vector2.ONE * Mothman.GLOW_SCALE, NEAR, "small")
	assert_almost_eq(eyes.position, Mothman.EYES, NEAR, "where its eyes are")
	var sheet := moth.texture.get_image()
	for frame: int in moth.hframes:
		var red := _texels(sheet, frame, palette["red"])
		assert_true(red.has_point(eyes.position), "frame %d: amid its red eyes, %s" % [frame, red])
	var alphas: Array[float] = []
	var with_it := true
	while not _reached(ends[3]):
		_step(mothman)
		alphas.append(eyes.modulate.a)
		with_it = with_it and (Disasters.shows(moth) or not Disasters.shows(eyes))
	_step(mothman)
	assert_eq(alphas, Disasters.sorted(alphas), "they only brighten")
	assert_almost_eq(eyes.modulate.a, Tuning.MOTHMAN_EYES_ALPHA, NEAR_ALPHA, "and stay lit")
	assert_true(with_it, "they show only with it")
	assert_false(Disasters.shows(eyes), "and go with it")
	assert_eq(_glows(mothman), [eyes] as Array[CanvasItem], "still its only glow, the car taken")


func test_its_eyes_light_each_point_at_most_once_whichever_way_it_flies() -> void:
	# test_none_flashes plays it one way. Its eyes take another path for each heading of the car and
	# each side that it carries the car off to; on each, their light rises at each point of the
	# world by more than FLASH_CHANGE of white's at most once, so they never flash (§5.6).
	var change := Tuning.FLASH_CHANGE * Color.WHITE.get_luminance()
	for heading: Vector2 in HEADINGS:
		for direction: Vector2 in [Vector2.RIGHT, Vector2.LEFT]:
			var what := "heading %s, off %s" % [heading, direction]
			var mothman := _mothman(direction, heading)
			watch_signals(mothman)
			var lights: Array[Dictionary] = []
			var reds: Array[Dictionary] = []
			var images: Dictionary[Texture2D, Image] = {}
			while get_signal_emit_count(mothman, "finished") == 0:
				if lights.size() >= Disasters.MAX_FRAMES:
					fail_test("%s: it finishes" % what)
					break
				_step(mothman)
				var light: Dictionary[Vector2i, float] = {}
				var red: Dictionary[Vector2i, float] = {}
				for glow: CanvasItem in _glows(mothman):
					Disasters.shine(glow as Sprite2D, light, red, images)
				lights.append(light)
				reds.append(red)
			var points: Dictionary[Vector2i, bool] = {}
			for light: Dictionary in lights:
				for point: Vector2i in light:
					points[point] = true
			assert_gt(points.size(), 0, "%s: its eyes light the world" % what)
			var twice: Array[Vector2i] = []
			for point: Vector2i in points:
				var values := PackedFloat32Array()
				for light: Dictionary in lights:
					values.append(light.get(point, 0.0))
				if Disasters._turns(values, change)[0].size() > 1:
					twice.append(point * Tuning.FLASH_GRID)
			assert_eq(twice, [] as Array[Vector2i], "%s: lit twice" % what)
			assert_eq(Disasters.flashing(lights, reds), "", what)


func test_it_stands_out_from_the_city_by_night() -> void:
	# Every frame of its sheet, against the City's road and ground, in each key light, under its
	# veil (POOLS_PLAN.md §5.6, V15).
	var mothman := _mothman()
	var sheet := _moth(mothman).texture.get_image()
	var share := Art.night_share(sheet, CITY, mothman.veil_kind)
	assert_gte(share, Art.NIGHT_SHARE, "%.0f%% of its pixels stand out" % (share * 100.0))
