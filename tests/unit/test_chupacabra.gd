extends GutTest
## The Chupacabra, the Desert's third legend (POOLS_PLAN.md §5.4). A grey, spined beast creeps out
## of the scrub down the screen from the car, slower and slower, and crouches by it. It leaps onto
## the car's roof and perches there, and the car's colours drain to grey as grey dust flakes off
## it: the car's grey husk is left. The beast turns, hops down and slinks off the way it came,
## faster and faster, and fades; the husk stays.

const Disasters := preload("res://tests/helpers/disaster_fixtures.gd")
const Art := preload("res://tests/helpers/art_checks.gd")
const CHUPACABRA := preload("res://disasters/legends/chupacabra.tscn")
const DESERT := preload("res://areas/desert.tres")
const DELTA := 1.0 / 60.0
## How near a place must be, in px.
const NEAR := Vector2(0.001, 0.001)
## The most of its full alpha that a part may change by in a frame, and of its way that it may move
## by: it shows, moves and fades, it doesn't pop.
const MOST_A_FRAME := 0.25
## The most that the last step of its creep in may be, of its longest: it slows to a stop.
const SLOW_SHARE := 0.25
## How many strides it takes, at least, as it creeps in and as it slinks off.
const LEAST_STRIDES := 4
## The most saturated that a grey may be, in HSV: the palette's greys and its blue-grey shade.
const GREY_SATURATION := 0.25
## The car's headings, as tile directions: the roads run along the tile axes.
const HEADINGS: Array[Vector2] = [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]
## How far the car may have stopped off its heading mid-turn, in radians.
const TILTS: Array[float] = [0.0, 0.6]
## Where across its dead end a wrong turn can leave the car, in tiles down-screen of its middle, as
## it brakes straight on from mid-turn, as test_headless_horseman.gd finds: on its middle; off the
## road, in the dead end's cell; in the next cell across; a hair short of that cell's middle; each
## to either side; and two cells across, off any road (FAR_OFF_TILES).
const FAR_OFF_TILES := 1.67
const STOPS: Array[float] = [
	0.0, -0.47, 0.47, -0.67, 0.67, -0.99, 0.99, -FAR_OFF_TILES, FAR_OFF_TILES
]

var _stage: Node2D
var _car: CarController
var _camera: CameraRig
var _params: DisasterParams
## Physics frames stepped since play().
var _frames := 0
var _beast_sheet: Image
var _husk_sheet: Image


func before_all() -> void:
	var legend := CHUPACABRA.instantiate() as Chupacabra
	_beast_sheet = (legend.get_node("%Beast") as Sprite2D).texture.get_image()
	_husk_sheet = (legend.get_node("%Husk") as Sprite2D).texture.get_image()
	legend.free()


func before_each() -> void:
	_stage = Disasters.stage(self)
	_car = Disasters.car(self, 0.0, _stage)
	_camera = Disasters.camera(self)


## The Chupacabra, playing for the car with the car's place as its origin, as the director gives
## it, the car heading `heading`.
func _legend(heading := Vector2.UP) -> Chupacabra:
	_car.modulate.a = 1.0
	# CarSim.forward() is (sin a, -cos a).
	_car.sim.angle = atan2(heading.x, -heading.y)
	var body := _car.get_node("%Body") as Sprite2D
	body.frame = CarController.frame(heading)
	var legend := Disasters.disaster(self, CHUPACABRA, _car, _camera) as Chupacabra
	legend.stage = _stage
	_params = Disasters.params()
	_params.origin_world = _car.global_position
	_frames = 0
	legend.play(_params)
	return legend


## One tile across the road of a car heading `heading`, a tile direction, down the screen, in px:
## the way that it creeps in against and slinks off along.
static func _down(heading: Vector2) -> Vector2:
	var across := Iso.tile_to_world(Vector2(-heading.y, heading.x))
	return across if across.y > 0.0 else -across


## When each beat ends, in seconds after the delay.
static func _ends() -> Array[float]:
	var ends: Array[float] = []
	var sum := 0.0
	for length: float in Tuning.CHUPACABRA_BEATS:
		sum += length
		ends.append(sum)
	return ends


## When `share` of `beat` is done, in seconds after the delay.
static func _at(beat: int, share: float) -> float:
	return _ends()[beat] - Tuning.CHUPACABRA_BEATS[beat] * (1.0 - share)


## Steps `legend` on to `seconds` after its delay, and a frame or two past it: a clock that sums
## frames can fall short of the sum by a hair.
func _step_to(legend: Chupacabra, seconds: float) -> void:
	var target := ceili((_params.delay + seconds) / DELTA) + 1
	simulate(legend, target - _frames, DELTA)
	_frames = target


## Steps `legend` one frame.
func _step(legend: Chupacabra) -> void:
	simulate(legend, 1, DELTA)
	_frames += 1


## Whether `legend` has stepped on to `seconds` after its delay.
func _reached(seconds: float) -> bool:
	return _frames * DELTA >= _params.delay + seconds


## How far the steps have gone through `beat`, from 0 at its start to 1 at its end.
func _through(beat: int) -> float:
	var length: float = Tuning.CHUPACABRA_BEATS[beat]
	return (_frames * DELTA - _params.delay - _at(beat, 0.0)) / length


## Whether a step from here stays half a frame short of `seconds` after the delay, so that the
## legend's clock and theirs agree that it has not got there.
func _short_of(seconds: float) -> bool:
	return (_frames + 1) * DELTA < _params.delay + seconds - DELTA / 2.0


## Whether the steps are more than a frame away from `share` of `beat`, so that the legend's clock
## and theirs agree on which side of it they are.
func _clear_of(beat: int, share: float) -> bool:
	return absf(_through(beat) - share) > DELTA / Tuning.CHUPACABRA_BEATS[beat]


## Whether the steps are clear of each of `shares` of `beat`.
func _clear_of_each(beat: int, shares: Array[float]) -> bool:
	for share: float in shares:
		if not _clear_of(beat, share):
			return false
	return true


## Where `part` is, in px from the car.
func _from_car(part: Node2D) -> Vector2:
	return part.global_position - _car.global_position


## How far down from the car the bottom edge of what shows of `sprite` is, in px: of the rect that
## it draws, which its offset, its frames and its centring place.
func _bottom(sprite: Sprite2D) -> float:
	return _from_car(sprite).y + sprite.get_rect().end.y


## How high the beast's feet are over the point that it sorts by, in px.
static func _lift(beast: Sprite2D) -> float:
	return -beast.get_rect().end.y


## Whether the beast's foot, as `beast` shows it, is at `at` px from the car, its feet `lift` px up,
## its frame centred on it.
func _placed(beast: Sprite2D, at: Vector2, lift: float) -> bool:
	var centred := absf(beast.get_rect().get_center().x) < NEAR.x
	return _near(_from_car(beast), at) and absf(_lift(beast) - lift) < NEAR.y and centred


static func _near(a: Vector2, b: Vector2) -> bool:
	return absf(a.x - b.x) <= NEAR.x and absf(a.y - b.y) <= NEAR.y


## The first tile of the first dead end of each heading in `buffer`, of those with no road in the
## two cells to either side of it, across its road, as test_headless_horseman.gd finds them.
static func _dead_ends(buffer: RoadBuffer) -> Array[RoadTile]:
	var found: Array[RoadTile] = []
	var headings: Array[int] = []
	for index: int in range(buffer.first_index(), buffer.last_index() + 1):
		var junction := buffer.path_tile(index)
		for branch: RoadTile in junction.branches:
			var exit := branch.branch_exit
			var across := Vector2i(absi(Heading.VEC[exit].y), absi(Heading.VEC[exit].x))
			var clear := branch.cell == junction.cell + Heading.VEC[exit] and exit not in headings
			for k: int in [-2, -1, 1, 2]:
				clear = clear and buffer.tile_at(branch.cell + across * k) == null
			if clear:
				found.append(branch)
				headings.append(exit)
	return found


## Whether `point`, in tiles, is on the road of the car's buffer.
func _on_road(point: Vector2) -> bool:
	var cell := Vector2i(point.floor())
	return RoadGeometry.is_on_road(_car.sim.buffer.tile_at(cell), point - Vector2(cell))


## The largest change between one of `values` and the next.
static func _largest_step(values: Array[float]) -> float:
	var most := 0.0
	for k: int in range(1, values.size()):
		most = maxf(most, absf(values[k] - values[k - 1]))
	return most


## The largest of `values`, or 0 if there are none.
static func _largest(values: Array[float]) -> float:
	var most := 0.0
	for value: float in values:
		most = maxf(most, value)
	return most


## Whether `values` rise to their largest and then fall, never the other way: an arc.
static func _arcs(values: Array[float]) -> bool:
	var peak := values.find(_largest(values))
	for k: int in range(1, values.size()):
		var change := values[k] - values[k - 1]
		if (k <= peak and change < -NEAR.y) or (k > peak and change > NEAR.y):
			return false
	return true


## `values`, each once until it changes.
static func _changes(values: Array[int]) -> Array[int]:
	var found: Array[int] = []
	for value: int in values:
		if found.is_empty() or found[-1] != value:
			found.append(value)
	return found


## Its legs taking turns, `count` frames of its sheet: its near legs forward, then its far ones.
static func _creeping(count: int) -> Array[int]:
	var found: Array[int] = []
	for k: int in count:
		found.append(Chupacabra.Pose.CREEP_A if k % 2 == 0 else Chupacabra.Pose.CREEP_B)
	return found


## The lengths of the steps along `path`, but those of none.
static func _strides(path: Array[Vector2]) -> Array[float]:
	var found: Array[float] = []
	for k: int in range(1, path.size()):
		var stride := path[k].distance_to(path[k - 1])
		if stride > NEAR.x:
			found.append(stride)
	return found


## Whether each point of `path` lies on the straight way from `from` to `to`.
static func _straight(path: Array[Vector2], from: Vector2, to: Vector2) -> bool:
	for point: Vector2 in path:
		var nearest := Geometry2D.get_closest_point_to_segment(point, from, to)
		if point.distance_to(nearest) > NEAR.x:
			return false
	return true


## Its standing parts, which play() has put on the stage, out of reach of %names.
static func _husk(legend: Chupacabra) -> Sprite2D:
	return legend.standing[0]


static func _beast(legend: Chupacabra) -> Sprite2D:
	return legend.standing[1]


static func _dust(legend: Chupacabra) -> CPUParticles2D:
	return legend.get_node("%Dust") as CPUParticles2D


## The car's double, which the legend has put on the stage once it has taken the car, or null.
static func _double(legend: Chupacabra) -> Sprite2D:
	for part: Sprite2D in legend.staged():
		if part not in legend.standing:
			return part
	return null


## The frame of the car's sheet that `car_double` shows.
static func _frame_of(car_double: Sprite2D) -> int:
	return roundi(car_double.region_rect.position.x / CarController.FRAME_SIZE.x)


## What of `legend` adds light: what it draws, what it has put on the stage, and its particles.
static func _glows(legend: Chupacabra) -> Array[CanvasItem]:
	var items := Disasters.drawables(legend)
	for emitter: CPUParticles2D in Disasters.particles(legend):
		items.append(emitter)
	var found: Array[CanvasItem] = []
	for item: CanvasItem in items:
		var material := Disasters.material_of(item) as CanvasItemMaterial
		if material != null and material.blend_mode == CanvasItemMaterial.BLEND_MODE_ADD:
			found.append(item)
	return found


func test_a_grey_spined_beast_creeps_out_of_the_scrub_slower_and_slower_to_the_car() -> void:
	# Each frame of its sheet stands on its bottom row. For each heading, the car stopped on its
	# road or mid-turn off it: from CHUPACABRA_FROM_TILES down the screen, across the car's road,
	# out of the scrub, it creeps straight to CHUPACABRA_BY_TILES from the car, only nearer, slower
	# and slower to a stop, facing the way it creeps, its legs taking turns, and shows as it comes.
	# It stands with the props, on its foot, in front of the car all the while.
	for frame: int in Chupacabra.Pose.size():
		var standing := false
		for x: int in Chupacabra.BEAST.x:
			var texel := Vector2i(frame * Chupacabra.BEAST.x + x, Chupacabra.BEAST.y - 1)
			standing = standing or _beast_sheet.get_pixelv(texel).a > 0.0
		assert_true(standing, "frame %d: it stands on its bottom row" % frame)
	var ends := _ends()
	for heading: Vector2 in HEADINGS:
		for tilt: float in TILTS:
			var what := "heading %s, turned %s" % [heading, tilt]
			var way := _down(heading)
			var from := way * Tuning.CHUPACABRA_FROM_TILES
			var by := way * Tuning.CHUPACABRA_BY_TILES
			var legend := _legend(heading.rotated(tilt))
			var beast := _beast(legend)
			assert_eq(beast.get_parent(), _stage, "%s: it stands with the props" % what)
			var path: Array[Vector2] = [from]
			var alphas: Array[float] = [0.0]
			var frames: Array[int] = []
			var hidden := true
			var placed := true
			var facing := true
			var shown := true
			var in_front := true
			while _short_of(ends[0]):
				_step(legend)
				if _through(0) < 0.0 and _clear_of(0, 0.0):
					hidden = hidden and not Disasters.shows(beast)
				if _through(0) <= 0.0 or not _clear_of(0, 0.0):
					continue
				path.append(_from_car(beast))
				alphas.append(beast.modulate.a)
				frames.append(beast.frame)
				placed = placed and Disasters.z(beast) == 0 and _placed(beast, path[-1], 0.0)
				facing = facing and beast.flip_h == (way.x > 0.0)
				in_front = in_front and path[-1].y > 0.0
				if _through(0) > Chupacabra.SHOW_SHARE and _clear_of(0, Chupacabra.SHOW_SHARE):
					shown = shown and beast.modulate.a == 1.0
			_step_to(legend, ends[0])
			path.append(_from_car(beast))
			var left: Array[float] = []
			for point: Vector2 in path:
				left.append(point.distance_to(by))
			var steps := _strides(path)
			var strides := _changes(frames)
			assert_true(hidden, "%s: unseen till it creeps in" % what)
			assert_true(placed, "%s: on its foot, with the props" % what)
			assert_true(facing, "%s: facing the way it creeps" % what)
			assert_true(in_front, "%s: in front of the car" % what)
			assert_eq(alphas, Disasters.sorted(alphas), "%s: it shows as it comes" % what)
			assert_lte(_largest_step(alphas), MOST_A_FRAME, "%s: bit by bit" % what)
			assert_true(shown, "%s: all of it, from SHOW_SHARE" % what)
			assert_eq(strides, _creeping(strides.size()), "%s: its legs take turns" % what)
			assert_gte(strides.size(), LEAST_STRIDES, "%s: creeping" % what)
			assert_true(_straight(path, from, by), "%s: straight across the road" % what)
			assert_eq(left, Disasters.sorted(left, true), "%s: only nearer" % what)
			assert_eq(steps, Disasters.sorted(steps, true), "%s: slower and slower" % what)
			assert_lt(steps[-1], SLOW_SHARE * _largest(steps), "%s: to a stop" % what)
			assert_almost_eq(path[-1], by, NEAR, "%s: by the car" % what)


func test_it_crouches_by_the_car_and_leaps_onto_its_roof_where_it_perches() -> void:
	# Where it perches, its feet are on the car's roof in each frame of the car's sheet: over the
	# car where its foot is, and above the car's middle. For each heading, the car stopped on its
	# road or mid-turn off it: it crouches where it stopped, on the ground, facing as it came. Then
	# it leaps, from its crouch straight over the ground to PERCH, only nearer, bit by bit, its feet
	# in an arc up over the roof and down onto it, and from LEAP_SHARE it perches there, hunched,
	# till the pounce ends. It sorts in front of the car all the while.
	var car_sheet := (_car.get_node("%Body") as Sprite2D).texture.get_image()
	var size := CarController.FRAME_SIZE
	var feet := CarController.FOOT.y + roundi(Chupacabra.PERCH.y - Chupacabra.ROOF_PX) - 1
	var up := float(feet - CarController.FOOT.y)
	assert_lt(up, WitchHex.car_middle().y, "its feet above the middle")
	for frame: int in CarController.WRECK_FRAME + 1:
		var under := car_sheet.get_pixel(frame * size.x + CarController.FOOT.x, feet)
		assert_gt(under.a, 0.0, "the car's frame %d: its feet on the car" % frame)
	var ends := _ends()
	var poses: Array[int] = [Chupacabra.Pose.LEAP, Chupacabra.Pose.PERCH]
	for heading: Vector2 in HEADINGS:
		for tilt: float in TILTS:
			var what := "heading %s, turned %s" % [heading, tilt]
			var way := _down(heading)
			var by := way * Tuning.CHUPACABRA_BY_TILES
			var legend := _legend(heading.rotated(tilt))
			var beast := _beast(legend)
			_step_to(legend, ends[0])
			var facing := beast.flip_h
			var crouched := true
			var path: Array[Vector2] = [_from_car(beast)]
			var lifts: Array[float] = [_lift(beast)]
			var frames: Array[int] = []
			var in_time := true
			var over := true
			var perched := true
			var in_front := true
			while _short_of(ends[2]):
				_step(legend)
				in_front = in_front and _from_car(beast).y > 0.0
				in_front = in_front and beast.flip_h == facing and beast.modulate.a == 1.0
				if not _clear_of(2, 0.0):
					continue
				if _through(2) < 0.0:
					crouched = crouched and beast.frame == Chupacabra.Pose.CROUCH
					crouched = crouched and _placed(beast, by, 0.0)
					continue
				path.append(_from_car(beast))
				lifts.append(_lift(beast))
				frames.append(beast.frame)
				var done := (
					1.0 - path[-1].distance_to(Chupacabra.PERCH) / by.distance_to(Chupacabra.PERCH)
				)
				over = over and lifts[-1] >= Chupacabra.ROOF_PX * done - NEAR.y
				if _clear_of(2, Chupacabra.LEAP_SHARE):
					var leaping := _through(2) < Chupacabra.LEAP_SHARE
					in_time = in_time and beast.frame == poses[0 if leaping else 1]
					if not leaping:
						perched = perched and _placed(beast, Chupacabra.PERCH, Chupacabra.ROOF_PX)
			_step_to(legend, ends[2])
			var left: Array[float] = []
			for point: Vector2 in path:
				left.append(point.distance_to(Chupacabra.PERCH))
			assert_true(crouched, "%s: it crouches by the car, on the ground" % what)
			assert_eq(_changes(frames), poses, "%s: it leaps, then perches" % what)
			assert_true(in_time, "%s: from LEAP_SHARE" % what)
			assert_true(_straight(path, by, Chupacabra.PERCH), "%s: straight to it" % what)
			assert_eq(left, Disasters.sorted(left, true), "%s: only nearer" % what)
			var most := MOST_A_FRAME * by.distance_to(Chupacabra.PERCH)
			assert_lte(_largest(_strides(path)), most, "%s: bit by bit" % what)
			assert_true(_arcs(lifts), "%s: its feet in an arc" % what)
			assert_gt(_largest(lifts), Chupacabra.ROOF_PX, "%s: up over the roof" % what)
			assert_true(over, "%s: never under the way up" % what)
			assert_true(perched, "%s: then it perches on the roof" % what)
			assert_true(_placed(beast, Chupacabra.PERCH, Chupacabra.ROOF_PX), "%s: still" % what)
			assert_eq(beast.frame, Chupacabra.Pose.PERCH, "%s: hunched" % what)
			assert_true(in_front, "%s: in front of the car, facing as it came" % what)


func test_the_cars_colours_drain_to_grey_as_dust_flakes_off_it_leaving_its_husk() -> void:
	# The husk's sheet is the first row of the car's, frame by frame, each pixel where the car's is,
	# drained to greys; the dust's colours are greys. For each heading, the car stopped on its road
	# or mid-turn off it: the car is there till the drain, and so is no husk. Then its double takes
	# its place, in the same frame, where it stood, facing as it did, with the props; and the car's
	# husk shows under it, whole, in its frame and place. The double fades from the start of the
	# drain to nothing by DRAIN_SHARE, bit by bit, so the car's colours drain to the husk's greys;
	# and dust flakes off the car's middle while it fades, and stops once it has. All the while it
	# fades, the beast perches on it, in front of them: it hops down only once the car has drained.
	var car_sheet := (_car.get_node("%Body") as Sprite2D).texture.get_image()
	var size := CarController.FRAME_SIZE
	for frame: int in CarController.WRECK_FRAME + 1:
		var same := true
		var grey := true
		for y: int in size.y:
			for x: int in size.x:
				var husk_texel := _husk_sheet.get_pixel(frame * size.x + x, y)
				var car_texel := car_sheet.get_pixel(frame * size.x + x, y)
				same = same and (husk_texel.a > 0.0) == (car_texel.a > 0.0)
				if husk_texel.a > 0.0:
					grey = grey and husk_texel.s <= GREY_SATURATION
		assert_true(same, "frame %d: the husk is the car's shape" % frame)
		assert_true(grey, "frame %d: in greys" % frame)
	var probe := _legend()
	for color: Color in _dust(probe).color_initial_ramp.colors:
		assert_lte(color.s, GREY_SATURATION, "grey dust: %s" % color)
	var ends := _ends()
	for heading: Vector2 in HEADINGS:
		for tilt: float in TILTS:
			var what := "heading %s, turned %s" % [heading, tilt]
			var first := CarController.frame(heading.rotated(tilt))
			var legend := _legend(heading.rotated(tilt))
			var husk := _husk(legend)
			var beast := _beast(legend)
			var dust := _dust(legend)
			var there := true
			while _short_of(ends[2]):
				_step(legend)
				there = there and _double(legend) == null and _car.modulate.a == 1.0
				there = there and not Disasters.shows(husk) and not dust.emitting
			assert_true(there, "%s: the car is there till the drain, and no husk" % what)
			while _double(legend) == null and not _reached(ends[3]):
				_step(legend)
			var car_double := _double(legend)
			if car_double == null:
				fail_test("%s: its double took its place" % what)
				continue
			var beat: float = Tuning.CHUPACABRA_BEATS[3]
			assert_lt(_through(3), 2.0 * DELTA / beat, "%s: as the drain starts" % what)
			assert_eq(_car.modulate.a, 0.0, "%s: the double took the car's place" % what)
			assert_eq(_frame_of(car_double), first, "%s: in the same frame" % what)
			assert_almost_eq(_from_car(car_double), Vector2.ZERO, NEAR, "%s: where it was" % what)
			assert_eq(car_double.get_parent(), _stage, "%s: with the props" % what)
			assert_eq(Disasters.z(car_double), 0, "%s: sorting with them" % what)
			var staged: Array[Sprite2D] = [husk, beast, car_double]
			assert_eq(legend.staged(), staged, "%s: it frees it" % what)
			assert_eq(husk.get_parent(), _stage, "%s: the husk with the props" % what)
			assert_eq(Disasters.z(husk), 0, "%s: sorting with them" % what)
			var under := husk.get_index() < car_double.get_index()
			assert_true(under, "%s: the husk under the double, drawn first at its place" % what)
			var alphas: Array[float] = [1.0, car_double.modulate.a]
			var whole := true
			var drained := true
			var dusty := true
			var perched := true
			while _short_of(ends[3]):
				_step(legend)
				alphas.append(car_double.modulate.a)
				whole = whole and Disasters.shows(husk) and husk.modulate.a == 1.0
				whole = whole and husk.frame == first and husk.offset == car_double.offset
				whole = whole and _near(_from_car(husk), _from_car(car_double))
				var through := _through(3)
				if _clear_of(3, Chupacabra.DRAIN_SHARE):
					var draining := through < Chupacabra.DRAIN_SHARE
					drained = drained and Disasters.shows(car_double) == draining
					dusty = dusty and dust.emitting == draining
					dusty = dusty and (Disasters.particles_show(dust) or not draining)
					if draining:
						perched = perched and _placed(beast, Chupacabra.PERCH, Chupacabra.ROOF_PX)
						perched = perched and beast.frame == Chupacabra.Pose.PERCH
						perched = perched and beast.global_position.y > car_double.global_position.y
				dusty = dusty and _near(_from_car(dust), WitchHex.car_middle())
			assert_true(whole, "%s: the husk shows whole in the car's frame and place" % what)
			assert_eq(alphas, Disasters.sorted(alphas, true), "%s: the double fades" % what)
			assert_lte(_largest_step(alphas), MOST_A_FRAME, "%s: bit by bit" % what)
			assert_true(drained, "%s: to nothing by DRAIN_SHARE" % what)
			assert_true(dusty, "%s: dust flakes off its middle while it drains" % what)
			assert_true(perched, "%s: the beast perched on it while it drains, in front" % what)


func test_it_turns_hops_down_and_slinks_off_the_way_it_came_faster_and_faster_and_fades() -> void:
	# For each heading, the car stopped on its road or mid-turn off it: it stays perched till
	# HOP_FROM of the drain, facing as it came; then it turns back, and hops down to where it
	# crouched, straight, bit by bit, its feet in an arc up off the roof and down to the ground;
	# from SLINK_FROM it slinks off along the way it came, straight, only farther, faster and
	# faster, its legs taking turns, to where it came from. It shows whole as it perches and hops
	# down, and till FADE_FROM, and then fades, bit by bit, to nothing. It sorts in front of the
	# car all the while.
	var ends := _ends()
	var shares: Array[float] = [Chupacabra.HOP_FROM, Chupacabra.SLINK_FROM]
	for heading: Vector2 in HEADINGS:
		for tilt: float in TILTS:
			var what := "heading %s, turned %s" % [heading, tilt]
			var way := _down(heading)
			var by := way * Tuning.CHUPACABRA_BY_TILES
			var from := way * Tuning.CHUPACABRA_FROM_TILES
			var legend := _legend(heading.rotated(tilt))
			var beast := _beast(legend)
			_step_to(legend, ends[2])
			var waited := true
			var hop: Array[Vector2] = [Chupacabra.PERCH]
			var lifts: Array[float] = [Chupacabra.ROOF_PX]
			var moves: Array[Vector2] = [_from_car(beast)]
			var hopping := true
			var slink: Array[Vector2] = []
			var frames: Array[int] = []
			var on_ground := true
			var facing := true
			var alphas: Array[float] = [beast.modulate.a]
			var whole := true
			var unfaded := true
			var in_front := true
			while _short_of(ends[3]):
				_step(legend)
				var through := _through(3)
				alphas.append(beast.modulate.a)
				in_front = in_front and _from_car(beast).y > 0.0
				if through < Chupacabra.SLINK_FROM:
					moves.append(_from_car(beast))
				if _clear_of(3, Chupacabra.SLINK_FROM) and through < Chupacabra.SLINK_FROM:
					unfaded = unfaded and beast.modulate.a == 1.0
				if _clear_of(3, Chupacabra.FADE_FROM) and through < Chupacabra.FADE_FROM:
					whole = whole and beast.modulate.a == 1.0
				if not _clear_of_each(3, shares):
					continue
				if through < Chupacabra.HOP_FROM:
					waited = waited and beast.flip_h == (way.x > 0.0)
					waited = waited and _placed(beast, Chupacabra.PERCH, Chupacabra.ROOF_PX)
					waited = waited and beast.frame == Chupacabra.Pose.PERCH
					continue
				facing = facing and beast.flip_h == (way.x < 0.0)
				if through < Chupacabra.SLINK_FROM:
					hop.append(_from_car(beast))
					lifts.append(_lift(beast))
					hopping = hopping and beast.frame == Chupacabra.Pose.LEAP
					continue
				slink.append(_from_car(beast))
				frames.append(beast.frame)
				on_ground = on_ground and _lift(beast) == 0.0
			_step_to(legend, ends[3])
			hop.append(by)
			lifts.append(0.0)
			slink.push_front(by)
			slink.append(_from_car(beast))
			alphas.append(beast.modulate.a)
			var gone: Array[float] = []
			for point: Vector2 in slink:
				gone.append(point.distance_to(by))
			var steps := _strides(slink)
			var strides := _changes(frames)
			assert_true(waited, "%s: perched till HOP_FROM, facing as it came" % what)
			assert_true(facing, "%s: then it turns back" % what)
			assert_true(hopping, "%s: and hops down" % what)
			assert_true(_straight(hop, Chupacabra.PERCH, by), "%s: to its crouch" % what)
			var most := MOST_A_FRAME * by.distance_to(Chupacabra.PERCH)
			assert_lte(_largest(_strides(moves)), most, "%s: down bit by bit" % what)
			assert_gt(_largest(lifts), Chupacabra.ROOF_PX, "%s: up off the roof first" % what)
			assert_true(_arcs(lifts), "%s: its feet in an arc" % what)
			assert_true(on_ground, "%s: then it slinks off on the ground" % what)
			assert_true(_straight(slink, by, from), "%s: the way it came" % what)
			assert_eq(gone, Disasters.sorted(gone), "%s: only farther" % what)
			assert_eq(steps, Disasters.sorted(steps), "%s: faster and faster" % what)
			assert_eq(strides, _creeping(strides.size()), "%s: its legs take turns" % what)
			assert_gte(strides.size(), LEAST_STRIDES, "%s: slinking" % what)
			assert_almost_eq(slink[-1], from, NEAR, "%s: to where it came from" % what)
			assert_true(unfaded, "%s: all of it as it perches and hops down" % what)
			assert_true(whole, "%s: all of it till FADE_FROM" % what)
			assert_eq(alphas, Disasters.sorted(alphas, true), "%s: then it fades" % what)
			assert_lte(_largest_step(alphas), MOST_A_FRAME, "%s: bit by bit" % what)
			assert_false(Disasters.shows(beast), "%s: to nothing" % what)
			assert_true(in_front, "%s: in front of the car" % what)


func test_the_cars_grey_husk_stays_where_it_stood() -> void:
	# For each heading, the car stopped on its road or mid-turn off it: at its end and after it,
	# the husk shows, whole, in the car's frame and place, with the props; the beast, the car's
	# double and the dust are gone, and so is the car.
	var ends := _ends()
	for heading: Vector2 in HEADINGS:
		for tilt: float in TILTS:
			var what := "heading %s, turned %s" % [heading, tilt]
			var legend := _legend(heading.rotated(tilt))
			var husk := _husk(legend)
			for after: float in [0.0, 1.0]:
				_step_to(legend, ends[3] + after)
				var told := "%s, %s s after its end" % [what, after]
				assert_true(Disasters.shows(husk), "%s: the husk stays" % told)
				assert_eq(husk.modulate.a, 1.0, "%s: whole" % told)
				assert_eq(husk.frame, CarController.frame(heading.rotated(tilt)), "%s: so" % told)
				assert_almost_eq(_from_car(husk), Vector2.ZERO, NEAR, "%s: where it was" % told)
				assert_eq(husk.get_parent(), _stage, "%s: with the props" % told)
				assert_false(Disasters.shows(_beast(legend)), "%s: the beast is gone" % told)
				assert_false(Disasters.shows(_double(legend)), "%s: the double too" % told)
				assert_false(_dust(legend).emitting, "%s: the dust has settled" % told)
				assert_eq(_car.modulate.a, 0.0, "%s: the car is gone" % told)


func test_it_creeps_out_of_the_scrub_wherever_across_the_road_the_car_stopped() -> void:
	# A wrong turn can leave the car off its road's middle, even in the next cell across, as a
	# review of the kelpie found. On a dead end of each heading, the car at each of STOPS: the beast
	# creeps out from CHUPACABRA_FROM_TILES down-screen of the road's middle, or of the car where it
	# stopped down-screen of the middle; so off the road. With the car FAR_OFF_TILES to either
	# side, off any road, it creeps out from as far down-screen of the car, as the kelpie's pool
	# lies by the car's line. It perches on the car, in front of it all the while, and slinks off
	# whence it came.
	var ends := _ends()
	var dead_ends := _dead_ends(_car.sim.buffer)
	assert_eq(dead_ends.size(), HEADINGS.size(), "a dead end of each heading")
	for branch: RoadTile in dead_ends:
		var heading := Vector2(Heading.VEC[branch.branch_exit])
		var down := PhantomBus.side(heading)
		for across: float in STOPS:
			var what := "heading %s, %s tiles down-screen" % [heading, across]
			var at := Iso.cell_centre(branch.cell) + down * across
			var on_road := absf(across) != FAR_OFF_TILES
			var middle := -across if on_road else 0.0
			# Down-screen of the middle, or of the car if further down-screen.
			var line := maxf(middle, 0.0) + Tuning.CHUPACABRA_FROM_TILES
			_car.sim.pos = at
			_car.position = Iso.tile_to_world(at)
			var legend := _legend(heading)
			var beast := _beast(legend)
			var from := Iso.tile_to_world(down * line)
			assert_almost_eq(_from_car(beast), from, NEAR, "%s: it creeps out from" % what)
			if on_road:
				assert_false(_on_road(at + down * line), "%s: off the road" % what)
			var in_front := true
			while _short_of(ends[3]):
				_step(legend)
				in_front = in_front and _from_car(beast).y > 0.0
				if _reached(ends[2]) and not _reached(_at(3, Chupacabra.HOP_FROM)):
					in_front = in_front and _near(_from_car(beast), Chupacabra.PERCH)
			_step_to(legend, ends[3])
			assert_true(in_front, "%s: it perches on the car, in front of it" % what)
			assert_almost_eq(_from_car(beast), from, NEAR, "%s: and slinks off there" % what)


func test_it_plays_in_the_light_of_the_hour_with_no_veil_and_no_glow() -> void:
	# A glow needs a veil (docs/M6.md S10): nothing of it adds light, its dust neither, so its red
	# eyes are pixels of its sheet, in each frame.
	var red: Color = Art.MakeArt.palette()["red"]
	var frames := Chupacabra.Pose.size()
	for frame: int in frames:
		var eyes := 0
		for y: int in Chupacabra.BEAST.y:
			for x: int in Chupacabra.BEAST.x:
				var texel := _beast_sheet.get_pixel(frame * Chupacabra.BEAST.x + x, y)
				eyes += int(texel.is_equal_approx(red))
		assert_gt(eyes, 0, "frame %d: its red eyes" % frame)
	var legend := _legend()
	assert_eq(legend.veil_kind, Legend.Veil.NONE, "no veil")
	watch_signals(legend)
	var none := true
	while get_signal_emit_count(legend, "finished") == 0 and _frames < Disasters.MAX_FRAMES:
		_step(legend)
		none = none and _glows(legend).is_empty()
	assert_lt(_frames, Disasters.MAX_FRAMES, "it finishes")
	assert_true(none, "no glow, the car taken or not")


func test_the_beast_and_the_husk_stand_out_from_the_desert_by_night() -> void:
	# Each frame of each sheet, against the Desert's road and ground, in each key light
	# (POOLS_PLAN.md §5.6, V15): the beast is dark, and the husk grey.
	var legend := _legend()
	var parts: Dictionary[String, Sprite2D] = {
		"the beast": _beast(legend),
		"the husk": _husk(legend),
	}
	for what: String in parts:
		var part := parts[what]
		var image := part.texture.get_image()
		var share := Art.night_share(image, part.hframes, DESERT, legend.veil_kind)
		var told := "%s: %.0f%% of its least frame's pixels stand out" % [what, share * 100.0]
		assert_gte(share, Art.NIGHT_SHARE, told)
