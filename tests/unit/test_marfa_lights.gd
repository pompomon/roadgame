extends GutTest
## The Marfa Lights, the Desert's second legend (docs/POOLS.md §5.4). Night falls, and three
## lights, white and amber, glimmer far off over the desert, one after another. They dance, then
## come close round the car, which turns to face up the screen after them. It follows them off the
## road into the desert, smaller and smaller, its tyres throwing up sand, until it is gone with
## them. Its tyre tracks stay.

const Disasters := preload("res://tests/helpers/disaster_fixtures.gd")
const Art := preload("res://tests/helpers/art_checks.gd")
const MARFA_LIGHTS := preload("res://disasters/legends/marfa_lights.tscn")
const DESERT := preload("res://areas/desert.tres")
const GLOW := preload("res://disasters/glow.tres")
const DELTA := 1.0 / 60.0
## How near a place must be, in px.
const NEAR := Vector2(0.001, 0.001)
## How near an alpha must be: a colour holds 32-bit floats.
const NEAR_ALPHA := 1e-6
## How far from where they gather round the car they may be on the last frame of the beckon, in px,
## and how far short of their size there, as a share of how much they grow: a frame short of its
## end, slowing.
const STOPPED_PX := 1.0
const STOPPED_SHARE := 0.01
## How much further than its average stride over the beckon a light may go in a frame of it, and
## the car over the follow, or how much more it may shrink, or its tracks grow: slow at each end, at
## its fastest each goes half as far again.
const GLIDE := 2.0
## How far a light may bob short of BOB_PX, in px: a frame may fall either side of its highest.
const BOB_SHORT := 0.1
## How far the top of the tracks may be from the car's back wheels, in px: they show whole rows.
const ROW_SHORT := 0.5
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


## The Marfa Lights, playing for the car with the car's place as its origin, as the director gives
## them, their direction `direction`, the car heading `heading`, a tile direction.
func _marfa(direction := Vector2(0.6, -0.8), heading := Vector2.UP) -> MarfaLights:
	_car.modulate.a = 1.0
	# CarSim.forward() is (sin a, -cos a). The car's body shows the frame for its heading only once
	# it steps, which it doesn't here.
	_car.sim.angle = atan2(heading.x, -heading.y)
	(_car.get_node("%Body") as Sprite2D).frame = CarController.frame(heading)
	var marfa := Disasters.disaster(self, MARFA_LIGHTS, _car, _camera) as MarfaLights
	marfa.stage = _stage
	_params = Disasters.params()
	_params.direction = direction
	_params.origin_world = _car.global_position
	_frames = 0
	marfa.play(_params)
	return marfa


## Directions in the params, and the side of the screen that each sends the lights to, 1 for the
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
	for length: float in Tuning.MARFA_LIGHTS_BEATS:
		sum += length
		ends.append(sum)
	return ends


## When `share` of `beat` is done, in seconds after the delay.
static func _at(beat: int, share: float) -> float:
	return _ends()[beat] - Tuning.MARFA_LIGHTS_BEATS[beat] * (1.0 - share)


## Steps `marfa` on to `seconds` after its delay, and a frame or two past it: a clock that sums
## frames can fall short of the sum by a hair.
func _step_to(marfa: MarfaLights, seconds: float) -> void:
	var target := ceili((_params.delay + seconds) / DELTA) + 1
	simulate(marfa, target - _frames, DELTA)
	_frames = target


## Steps `marfa` one frame.
func _step(marfa: MarfaLights) -> void:
	simulate(marfa, 1, DELTA)
	_frames += 1


## Whether `marfa` has stepped on to `seconds` after its delay.
func _reached(seconds: float) -> bool:
	return _frames * DELTA >= _params.delay + seconds


## How far the steps have gone through `beat`, from 0 at its start to 1 at its end.
func _through(beat: int) -> float:
	return (_frames * DELTA - _params.delay - _at(beat, 0.0)) / Tuning.MARFA_LIGHTS_BEATS[beat]


## Whether a step from here stays half a frame short of `seconds` after the delay, so that the
## legend's clock and theirs agree that it has not got there.
func _short_of(seconds: float) -> bool:
	return (_frames + 1) * DELTA < _params.delay + seconds - DELTA / 2.0


## Whether the steps are more than a frame away from `share` of `beat`, so that the legend's clock
## and theirs agree on which side of it they are.
func _clear_of(beat: int, share: float) -> bool:
	return absf(_through(beat) - share) > DELTA / Tuning.MARFA_LIGHTS_BEATS[beat]


## Where `part` is, in px from the car.
func _from_car(part: Node2D) -> Vector2:
	return part.global_position - _car.global_position


## Where `lights` are, in px from the car.
func _places(lights: Array[Sprite2D]) -> Array[Vector2]:
	var found: Array[Vector2] = []
	for light: Sprite2D in lights:
		found.append(_from_car(light))
	return found


## Whether `a` is within NEAR of `b`.
static func _near(a: Vector2, b: Vector2) -> bool:
	return absf(a.x - b.x) <= NEAR.x and absf(a.y - b.y) <= NEAR.y


## Its lights, from left to right.
static func _lights(marfa: MarfaLights) -> Array[Sprite2D]:
	var found: Array[Sprite2D] = []
	for light: String in ["%Left", "%Middle", "%Right"]:
		found.append(marfa.get_node(light) as Sprite2D)
	return found


static func _tracks(marfa: MarfaLights) -> Sprite2D:
	return marfa.get_node("%Tracks") as Sprite2D


## The car's double, which the legend has put on the stage once it has taken the car, or null.
static func _double(marfa: MarfaLights) -> Sprite2D:
	for part: Sprite2D in marfa.staged():
		if part not in marfa.standing:
			return part
	return null


## The frame of the car's sheet that `car_double` shows.
static func _frame_of(car_double: Sprite2D) -> int:
	return roundi(car_double.region_rect.position.x / CarController.FRAME_SIZE.x)


## What of `marfa` adds light: what it draws, what it has put on the stage, and its particles.
static func _glows(marfa: MarfaLights) -> Array[CanvasItem]:
	var items := Disasters.drawables(marfa)
	for emitter: CPUParticles2D in Disasters.particles(marfa):
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


## The frames that the car turns through from `first` to face up the screen, frame 0: the shorter
## way, one at a time.
static func _turning(first: int) -> Array[int]:
	var frames := CarController.FRAMES
	var steps := posmod(frames - first + (frames >> 1), frames) - (frames >> 1)
	var found: Array[int] = []
	for k: int in absi(steps) + 1:
		found.append(posmod(first + k * signi(steps), frames))
	return found


## The frames of `values` where they turn, from rising to falling or back.
static func _turns(values: Array[float]) -> Array[int]:
	var found: Array[int] = []
	var heading := 0.0
	for k: int in range(1, values.size()):
		var now := signf(values[k] - values[k - 1])
		if now != 0.0:
			if heading != 0.0 and now != heading:
				found.append(k - 1)
			heading = now
	return found


## The runs of opaque texels in row `y` of `sheet`, each as its first and last x.
static func _runs(sheet: Image, y: int) -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	for x: int in sheet.get_width():
		if sheet.get_pixel(x, y).a <= 0.0:
			continue
		if not found.is_empty() and found[-1].y == x - 1:
			found[-1].y = x
		else:
			found.append(Vector2i(x, x))
	return found


func test_night_falls_and_three_lights_glimmer_far_off_one_after_another() -> void:
	# Up the screen from the car, to the side that its direction picks, small, from left to right:
	# each STAGGER of the glimmer after the last, and as bright as it shows by FADE_SHARE after that.
	var ends := _ends()
	var sides := _sides()
	for direction: Vector2 in sides:
		var what := str(direction)
		var marfa := _marfa(direction)
		var lights := _lights(marfa)
		assert_eq(marfa.veil_kind, Legend.Veil.NIGHT, "%s: night falls" % what)
		var places: Array[Vector2] = []
		for k: int in MarfaLights.LIGHTS:
			var place := _from_car(lights[k])
			var which := "%s, light %d" % [what, k]
			assert_lt(place.y, 0.0, "%s: up the screen" % which)
			assert_gt(place.x * sides[direction], 0.0, "%s: to its side" % which)
			assert_gt(place.length(), 2.0 * MarfaLights.RING[k].length(), "%s: far off" % which)
			if k > 0:
				var apart := Vector2(MarfaLights.SPREAD_PX, 0.0)
				assert_almost_eq(
					place - places[k - 1], apart, NEAR, "%s: right of the last" % which
				)
			places.append(place)
		var still := true
		var small := true
		var dark := true
		var lit := true
		var there := true
		var alphas: Array[PackedFloat32Array] = []
		while not _reached(ends[0]):
			var shut: Array[bool] = []
			for k: int in MarfaLights.LIGHTS:
				shut.append(_short_of(_at(0, k * MarfaLights.STAGGER)))
			_step(marfa)
			var row := PackedFloat32Array()
			for k: int in MarfaLights.LIGHTS:
				var light := lights[k]
				still = still and _near(_from_car(light), places[k])
				small = small and _near(light.scale, Vector2.ONE * MarfaLights.FAR_SCALE)
				dark = dark and (not shut[k] or light.modulate.a == 0.0)
				var shown := minf(k * MarfaLights.STAGGER + MarfaLights.FADE_SHARE, 1.0)
				if _reached(_at(0, shown) + DELTA / 2.0):
					lit = lit and absf(light.modulate.a - Tuning.MARFA_LIGHTS_ALPHA) <= NEAR_ALPHA
				row.append(light.modulate.a)
			alphas.append(row)
			there = there and _double(marfa) == null and _car.modulate.a == 1.0
		assert_true(still, "%s: where they glimmer" % what)
		assert_true(small, "%s: small" % what)
		assert_true(dark, "%s: each dark till STAGGER after the last" % what)
		assert_true(lit, "%s: and as bright as it shows by FADE_SHARE after" % what)
		assert_true(there, "%s: the car still there" % what)
		for k: int in MarfaLights.LIGHTS:
			var mine := _column(alphas, k)
			var which := "%s, light %d" % [what, k]
			assert_eq(mine, Disasters.sorted(mine), "%s: it only brightens" % which)
			var bright := Tuning.MARFA_LIGHTS_ALPHA
			assert_almost_eq(mine[-1], bright, NEAR_ALPHA, "%s: as bright as it shows" % which)


func test_they_dance_drifting_back_across_as_they_bob_at_most_once_a_second() -> void:
	# All together, so that each keeps to its own path: SPREAD_PX apart, the middle one bobbing
	# down as the others go up, as bright and as small as they glimmered.
	var ends := _ends()
	var sides := _sides()
	var drift_a_frame := Tuning.MARFA_LIGHTS_DRIFT_PX * DELTA / Tuning.MARFA_LIGHTS_BEATS[1]
	var bob := Tuning.MARFA_LIGHTS_BOB_PX
	for direction: Vector2 in sides:
		var what := str(direction)
		var marfa := _marfa(direction)
		var lights := _lights(marfa)
		var places: Array[Vector2] = []
		for light: Sprite2D in lights:
			places.append(_from_car(light))
		while _short_of(ends[0]):
			_step(marfa)
		var across: Array[float] = []
		var bobs: Array[float] = []
		var together := true
		var steady := true
		while _short_of(ends[1]):
			_step(marfa)
			var moved: Array[Vector2] = []
			for k: int in MarfaLights.LIGHTS:
				moved.append(_from_car(lights[k]) - places[k])
				var alpha := lights[k].modulate.a
				steady = steady and absf(alpha - Tuning.MARFA_LIGHTS_ALPHA) <= NEAR_ALPHA
				steady = steady and _near(lights[k].scale, Vector2.ONE * MarfaLights.FAR_SCALE)
			across.append(moved[0].x * sides[direction])
			bobs.append(moved[0].y)
			together = together and _near(moved[1], Vector2(moved[0].x, -moved[0].y))
			together = together and _near(moved[2], moved[0])
		assert_eq(across, Disasters.sorted(across, true), "%s: drifting back across" % what)
		var drift := Tuning.MARFA_LIGHTS_DRIFT_PX
		assert_almost_eq(across[-1], -drift, 2.0 * drift_a_frame, "%s: DRIFT_PX" % what)
		assert_almost_eq(bobs.min(), -bob, BOB_SHORT, "%s: bobbing up" % what)
		assert_almost_eq(bobs.max(), bob, BOB_SHORT, "%s: and down" % what)
		var turns := _turns(bobs)
		assert_gt(turns.size(), 0, "%s: it bobs" % what)
		for k: int in range(1, turns.size()):
			var apart := (turns[k] - turns[k - 1]) * DELTA
			assert_gte(apart, 0.5 - DELTA, "%s: at most once a second" % what)
		assert_true(together, "%s: together, the middle one bobbing the other way" % what)
		assert_true(steady, "%s: as bright and as small as they glimmered" % what)


func test_they_come_close_round_the_car_which_turns_to_face_up_the_screen_after_them() -> void:
	# Its double takes its place as they beckon, and turns, a frame at a time, the shorter way, as
	# they glide round it, nearer and larger each frame, slowing to a stop.
	var ends := _ends()
	var span := MarfaLights.NEAR_SCALE - MarfaLights.FAR_SCALE
	for heading: Vector2 in HEADINGS:
		for direction: Vector2 in [Vector2.RIGHT, Vector2.LEFT]:
			var what := "heading %s, lights %s" % [heading, direction]
			var marfa := _marfa(direction, heading)
			var lights := _lights(marfa)
			var there := true
			var last: Array[Vector2] = _places(lights)
			while _short_of(ends[1]):
				last = _places(lights)
				_step(marfa)
				there = there and _double(marfa) == null and _car.modulate.a == 1.0
			assert_true(there, "%s: the car is there till they beckon" % what)
			while _double(marfa) == null and not _reached(ends[2]):
				last = _places(lights)
				_step(marfa)
			var car_double := _double(marfa)
			if car_double == null:
				fail_test("%s: its double took its place" % what)
				continue
			var first := CarController.frame(heading)
			assert_lt(
				_through(2), 2.0 * DELTA / Tuning.MARFA_LIGHTS_BEATS[2], "%s: as they beckon" % what
			)
			assert_eq(_car.modulate.a, 0.0, "%s: the double took the car's place" % what)
			assert_true(Disasters.shows(car_double), "%s: in the same frame" % what)
			assert_eq(_frame_of(car_double), first, "%s: facing as the car did" % what)
			assert_eq(car_double.get_parent(), _stage, "%s: with the props" % what)
			assert_eq(Disasters.z(car_double), 0, "%s: sorting with them" % what)
			assert_eq(marfa.staged(), [car_double] as Array[Sprite2D], "%s: it frees it" % what)
			var distances: Array[PackedFloat32Array] = []
			var strides: Array[PackedFloat32Array] = []
			var scales: Array[float] = []
			# `last` holds where they were on the dance's last frame: each light's way runs from
			# there to its place round the car, and the beckon's first frame is a stride of it.
			var strides_most: Array[float] = []
			var glide := true
			for k: int in MarfaLights.LIGHTS:
				var way := last[k].distance_to(MarfaLights.RING[k])
				strides_most.append(GLIDE * way * DELTA / Tuning.MARFA_LIGHTS_BEATS[2])
				var now := _from_car(lights[k])
				glide = glide and now.distance_to(last[k]) <= strides_most[k]
				last[k] = now
			var frames: Array[int] = [_frame_of(car_double)]
			var put := true
			while not _reached(ends[2]):
				var beckoning := _short_of(ends[2])
				_step(marfa)
				frames.append(_frame_of(car_double))
				if not beckoning:
					continue
				put = put and _near(_from_car(car_double), Vector2.ZERO)
				put = put and _near(car_double.scale, Vector2.ONE)
				var row := PackedFloat32Array()
				var stride := PackedFloat32Array()
				for k: int in MarfaLights.LIGHTS:
					var now := _from_car(lights[k])
					row.append(now.distance_to(MarfaLights.RING[k]))
					stride.append(now.distance_to(last[k]))
					glide = glide and stride[k] <= strides_most[k]
					last[k] = now
				distances.append(row)
				if _through(2) >= 0.5:
					strides.append(stride)
				scales.append(lights[0].scale.x)
			assert_eq(_changes(frames), _turning(first), "%s: it turns the shorter way" % what)
			assert_true(put, "%s: where the car stood" % what)
			assert_true(glide, "%s: they glide there from where they danced" % what)
			for k: int in MarfaLights.LIGHTS:
				var which := "%s, light %d" % [what, k]
				var nearing := _column(distances, k)
				assert_eq(nearing, Disasters.sorted(nearing, true), "%s: nearer" % which)
				var slowing := _column(strides, k)
				assert_eq(slowing, Disasters.sorted(slowing, true), "%s: slowing" % which)
				assert_lt(nearing[-1], STOPPED_PX, "%s: to a stop round the car" % which)
			assert_eq(scales, Disasters.sorted(scales), "%s: they grow" % what)
			var near := MarfaLights.NEAR_SCALE
			assert_almost_eq(scales[-1], near, span * STOPPED_SHARE, "%s: to NEAR_SCALE" % what)


func test_it_follows_them_off_the_road_smaller_and_smaller_till_it_is_gone() -> void:
	# Straight up the screen, facing them, a little further and smaller each frame, its tyres
	# throwing up sand at first: they lead it, closing in as it dwindles, until nothing shows where
	# it has gone.
	var ends := _ends()
	for heading: Vector2 in HEADINGS:
		var what := "heading %s" % heading
		var marfa := _marfa(Vector2(0.6, -0.8), heading)
		var lights := _lights(marfa)
		var sand := marfa.get_node("%Sand") as CPUParticles2D
		var still := true
		while _short_of(ends[2]):
			_step(marfa)
			still = still and not sand.emitting
		assert_true(still, "%s: no sand till it follows them" % what)
		var car_double := _double(marfa)
		if car_double == null:
			fail_test("%s: its double took its place" % what)
			continue
		var ys: Array[float] = []
		var sizes: Array[float] = []
		var facing := true
		var led := true
		var wheels := true
		var throws := true
		var follow := Tuning.MARFA_LIGHTS_BEATS[3]
		var stride_most := GLIDE * MarfaLights.FOLLOW_PX * DELTA / follow
		var shrink_most := GLIDE * DELTA / follow
		var last := _from_car(car_double)
		var last_size := car_double.scale.x
		var gradual := true
		while not _reached(ends[3]):
			_step(marfa)
			var at := _from_car(car_double)
			var size := car_double.scale.x
			gradual = gradual and at.distance_to(last) <= stride_most
			gradual = gradual and last_size - size <= shrink_most
			last = at
			last_size = size
			ys.append(at.y)
			sizes.append(size)
			facing = facing and _frame_of(car_double) == 0 and absf(at.x) <= NEAR.x
			for k: int in MarfaLights.LIGHTS:
				led = led and _near(_from_car(lights[k]) - at, MarfaLights.RING[k] * size)
				var scale := Vector2.ONE * MarfaLights.NEAR_SCALE * size
				led = led and _near(lights[k].scale, scale)
			# The emitter throws the sand from its rect, as it stands in the world: from wheel to
			# wheel, GAUGE px each side of the car's middle at its size.
			var reach := Vector2(sand.emission_rect_extents.x, 0.0)
			var left := sand.global_transform * -reach - _car.global_position
			var right := sand.global_transform * reach - _car.global_position
			var rear := at + Vector2(0.0, MarfaLights.REAR * size)
			var gauge := Vector2(MarfaLights.GAUGE * size, 0.0)
			wheels = wheels and _near(left, rear - gauge) and _near(right, rear + gauge)
			if _clear_of(3, 0.0) and _clear_of(3, MarfaLights.SAND_SHARE):
				throws = throws and sand.emitting == (_through(3) < MarfaLights.SAND_SHARE)
		# One frame more: the legend's clock sums its frames, so it can end the follow a frame later.
		_step(marfa)
		var went := _from_car(car_double)
		gradual = gradual and went.distance_to(last) <= stride_most
		gradual = gradual and last_size - car_double.scale.x <= shrink_most
		assert_almost_eq(
			went, Vector2(0.0, -MarfaLights.FOLLOW_PX), NEAR, "%s: up the screen" % what
		)
		# The car stopped on its road, within ROAD_HALF_WIDTH of its middle.
		var off := absf(Iso.world_to_tile(went).dot(Vector2(-heading.y, heading.x)))
		assert_gt(off, 2.0 * Tuning.ROAD_HALF_WIDTH, "%s: off the road" % what)
		assert_true(facing, "%s: straight up the screen, facing them" % what)
		assert_eq(ys, Disasters.sorted(ys, true), "%s: only going on" % what)
		assert_eq(sizes, Disasters.sorted(sizes, true), "%s: smaller and smaller" % what)
		assert_true(gradual, "%s: a little further and smaller each frame" % what)
		assert_true(led, "%s: they lead it, closing in as it dwindles" % what)
		assert_true(wheels, "%s: the sand from between its back wheels" % what)
		assert_true(throws, "%s: thrown up as it pulls away" % what)
		assert_false(sand.emitting, "%s: and no more" % what)
		assert_lt(Disasters.z(sand), Tuning.VEIL_Z, "%s: the sand under the night" % what)
		assert_false(Disasters.shows(car_double), "%s: it is gone" % what)
		for light: Sprite2D in lights:
			assert_false(Disasters.shows(light), "%s: with %s" % [what, light.name])
		assert_eq(_car.modulate.a, 0.0, "%s: the car too" % what)


func test_its_tyre_tracks_stay_two_grooves_that_meet_where_it_went() -> void:
	# They show from the bottom up as it goes, up to its back wheels, under the props and the car,
	# and stay whole once it has finished. The World draws its DisasterLayer, where a legend plays,
	# under its Props, where the car is (world/world.tscn).
	var ends := _ends()
	var marfa := _marfa()
	var tracks := _tracks(marfa)
	watch_signals(marfa)
	var hidden := true
	while _short_of(ends[2]):
		_step(marfa)
		hidden = hidden and not Disasters.shows(tracks)
	assert_true(hidden, "none till it follows the lights")
	var car_double := _double(marfa)
	if car_double == null:
		fail_test("its double took its place")
		return
	var rows: Array[float] = []
	var cropped := true
	var behind := true
	var standing := true
	# No frame shows more new rows than GLIDE times their average over the follow, and one for the
	# rounding to whole rows.
	var rows_most := GLIDE * MarfaLights.TRACKS.y * DELTA / Tuning.MARFA_LIGHTS_BEATS[3] + 1.0
	var shown := 0.0
	var gradual := true
	while not _reached(ends[3]):
		_step(marfa)
		var rect := tracks.get_rect()
		gradual = gradual and rect.size.y - shown <= rows_most
		shown = rect.size.y
		rows.append(shown)
		var region := tracks.region_rect
		cropped = cropped and tracks.region_enabled and region.end.y == MarfaLights.TRACKS.y
		cropped = cropped and region.position.x == 0.0 and region.size.x == MarfaLights.TRACKS.x
		var top := _from_car(tracks).y + rect.position.y
		var wheels := _from_car(car_double).y + MarfaLights.REAR * car_double.scale.y
		behind = behind and absf(top - wheels) <= ROW_SHORT + NEAR.y
		standing = standing and absf(_from_car(tracks).y + rect.end.y - MarfaLights.REAR) <= NEAR.y
	# One frame more: the legend's clock sums its frames, so it can end the follow a frame later.
	_step(marfa)
	gradual = gradual and tracks.get_rect().size.y - shown <= rows_most
	assert_eq(rows, Disasters.sorted(rows), "they only grow")
	assert_true(gradual, "a few rows at a time, as it goes")
	assert_true(cropped, "the bottom rows of their frame")
	assert_true(behind, "up to its back wheels")
	assert_true(standing, "from under them where it stood")
	_step_to(marfa, Disasters.duration(marfa, _params) - _params.delay + 0.5)
	assert_signal_emit_count(marfa, "finished", 1, "it has finished")
	var stayed := tracks.get_rect()
	assert_true(Disasters.shows(tracks), "the tracks stay")
	assert_eq(stayed.size, Vector2(MarfaLights.TRACKS), "whole")
	var meet := _from_car(tracks) + stayed.position + Vector2(stayed.size.x / 2.0, 0.0)
	assert_almost_eq(meet, Vector2(0.0, -MarfaLights.FOLLOW_PX), NEAR, "to where it went")
	assert_eq(tracks.get_parent(), marfa, "with the legend, under the props")
	assert_eq(Disasters.z(tracks), 0, "under the car")
	# Two grooves from under its back wheels, the bottom row of frame 0 of the car's sheet, that only
	# close in, row by row, till they meet in the top row, in its middle.
	var sheet := tracks.texture.get_image()
	var car_sheet := (_car.get_node("%Body") as Sprite2D).texture.get_image()
	var foot := CarController.FOOT
	var lowest := -1
	for y: int in CarController.FRAME_SIZE.y:
		for x: int in CarController.FRAME_SIZE.x:
			if car_sheet.get_pixel(x, y).a > 0.0:
				lowest = y
	assert_eq(lowest - foot.y, MarfaLights.REAR - 1, "frame 0 stands on its bottom row")
	var half := MarfaLights.TRACKS.x >> 1
	var bottom := _runs(sheet, MarfaLights.TRACKS.y - 1)
	assert_eq(bottom.size(), 2, "two grooves")
	for run: Vector2i in bottom:
		for x: int in range(run.x, run.y + 1):
			var wheel := Vector2i(x - half, MarfaLights.REAR - 1) + foot
			assert_gt(car_sheet.get_pixelv(wheel).a, 0.0, "x %d: under the car" % (x - half))
	var gaps: Array[float] = []
	for y: int in range(MarfaLights.TRACKS.y - 1, -1, -1):
		var runs := _runs(sheet, y)
		if runs.is_empty() or runs.size() > 2:
			fail_test("row %d: %d grooves" % [y, runs.size()])
			return
		gaps.append(runs[-1].x - runs[0].y - 1 if runs.size() == 2 else 0)
	assert_eq(gaps, Disasters.sorted(gaps, true), "closing in")
	assert_eq(
		_runs(sheet, 0), [Vector2i(half - 1, half)] as Array[Vector2i], "meeting in the middle"
	)


func test_its_glows_are_its_lights_white_amber_and_white_which_keep_their_brightness() -> void:
	# They brighten as they glimmer, then keep that brightness as they move, as they come close
	# and as they go, and none is red (§5.6).
	var ends := _ends()
	var palette := Art.MakeArt.palette()
	var marfa := _marfa()
	var lights := _lights(marfa)
	var glows: Array[CanvasItem] = []
	glows.assign(lights)
	assert_eq(_glows(marfa), glows, "its only glows")
	var tints: Array[String] = ["white", "yellow", "white"]
	for k: int in MarfaLights.LIGHTS:
		var light := lights[k]
		var which := "light %d" % k
		assert_eq(light.texture, GLOW, "%s: a soft glow" % which)
		assert_true(
			light.self_modulate.is_equal_approx(palette[tints[k]]), "%s: %s" % [which, tints[k]]
		)
		var tint := light.self_modulate
		var red := tint.r >= Tuning.FLASH_RED_SHARE * (tint.r + tint.g + tint.b)
		assert_false(red, "%s: not red" % which)
		assert_eq(Disasters.z(light), Tuning.GLOW_Z, "%s: over the night" % which)
	var alphas: Array[PackedFloat32Array] = []
	while not _reached(ends[3]):
		_step(marfa)
		var row := PackedFloat32Array()
		for light: Sprite2D in lights:
			row.append(light.modulate.a)
		alphas.append(row)
	for k: int in MarfaLights.LIGHTS:
		var mine := _column(alphas, k)
		var which := "light %d" % k
		assert_eq(mine, Disasters.sorted(mine), "%s: it only brightens" % which)
		var bright := Tuning.MARFA_LIGHTS_ALPHA
		assert_almost_eq(mine[-1], bright, NEAR_ALPHA, "%s: and keeps its brightness" % which)
	assert_eq(_glows(marfa), glows, "still its only glows, the car taken")


func test_their_light_rises_at_each_point_at_most_twice_on_either_side() -> void:
	# test_none_flashes plays them one way. They glimmer on either side, and take another path from
	# each. On each, their light rises at each point of the world, by more than FLASH_CHANGE of
	# white's, at most twice in all, below FLASH_MAX in any second: their glows keep apart, even as
	# they close in round the dwindling car (§5.6).
	var change := Tuning.FLASH_CHANGE * Color.WHITE.get_luminance()
	for direction: Vector2 in [Vector2.RIGHT, Vector2.LEFT]:
		var what := "lights %s" % direction
		var marfa := _marfa(direction)
		watch_signals(marfa)
		var lights: Array[Dictionary] = []
		var reds: Array[Dictionary] = []
		var images: Dictionary[Texture2D, Image] = {}
		while get_signal_emit_count(marfa, "finished") == 0:
			if lights.size() >= Disasters.MAX_FRAMES:
				fail_test("%s: it finishes" % what)
				break
			_step(marfa)
			var light: Dictionary[Vector2i, float] = {}
			var red: Dictionary[Vector2i, float] = {}
			for glow: CanvasItem in _glows(marfa):
				Disasters.shine(glow as Sprite2D, light, red, images)
			lights.append(light)
			reds.append(red)
		var points: Dictionary[Vector2i, bool] = {}
		for light: Dictionary in lights:
			for point: Vector2i in light:
				points[point] = true
		assert_gt(points.size(), 0, "%s: they light the world" % what)
		var most := 0
		for point: Vector2i in points:
			var values := PackedFloat32Array()
			for light: Dictionary in lights:
				values.append(light.get(point, 0.0))
			most = maxi(most, Disasters._turns(values, change)[0].size())
		assert_lte(most, 2, "%s: at most twice at a point" % what)
		assert_eq(Disasters.flashing(lights, reds), "", what)


func test_its_lights_and_tracks_stand_out_from_the_desert_by_night() -> void:
	# Its figure is its lights, glows that add light over the night (docs/POOLS.md §5.6, V15,
	# P13b), each drawn as bright as it shows. Its tracks lie on the road and the sand under it.
	var marfa := _marfa()
	for light: Sprite2D in _lights(marfa):
		var tint := Color(light.self_modulate, Tuning.MARFA_LIGHTS_ALPHA)
		var lit := Art.glow_share(light.texture.get_image(), tint, DESERT, marfa.veil_kind)
		var told := "%s: %.0f%% of its pixels stand out" % [light.name, lit * 100.0]
		assert_gte(lit, Art.NIGHT_SHARE, told)
	var tracks := _tracks(marfa)
	var share := Art.night_share(tracks.texture.get_image(), 1, DESERT, marfa.veil_kind)
	var what := "the tracks: %.0f%% of their pixels stand out" % (share * 100.0)
	assert_gte(share, Art.NIGHT_SHARE, what)
