extends GutTest
## The Headless Horseman, Rural's third legend (POOLS_PLAN.md §5.4). Dusk falls, and a rider with no
## head gallops along the road to the car on a black horse and halts in front of it. He raises a
## ball of ghost-fire, not a pumpkin, and hurls it at the car. Pale flames run over the car, which
## pales to a ghost of itself and fades, as he wheels round and gallops off the way he came. His
## horse's hooves scorch the road behind him, and the hoofprints stay.

const Disasters := preload("res://tests/helpers/disaster_fixtures.gd")
const Art := preload("res://tests/helpers/art_checks.gd")
const HEADLESS_HORSEMAN := preload("res://disasters/legends/headless_horseman.tscn")
const RURAL := preload("res://areas/rural.tres")
const GLOW := preload("res://disasters/glow.tres")
const DELTA := 1.0 / 60.0
## How near a place must be, in px.
const NEAR := Vector2(0.001, 0.001)
## How near an alpha or a colour must be: a colour holds 32-bit floats.
const NEAR_ALPHA := 1e-6
## How near a share of tiles must be: Iso maps tiles to px and back in 32-bit floats.
const NEAR_TILES := 1e-4
## The most of its full alpha or size that a part may change by in a frame: it shows, grows and
## fades, it doesn't pop.
const MOST_A_FRAME := 0.25
## The most that the last step of his gallop in may be, of its longest: he slows to a stop.
const SLOW_SHARE := 0.25
## How many strides his horse takes, at least, as he gallops in and as he gallops off.
const LEAST_STRIDES := 4
## The least share of HEADLESS_HORSEMAN_ARC_PX that the ghost-fire rises to over the straight way.
const ARC_SHARE := 0.9
## The car's headings, as tile directions: the roads run along the tile axes.
const HEADINGS: Array[Vector2] = [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]
## The middle of a frame of the hoofprints' sheet, from its top left corner.
const PRINTS_MIDDLE := Vector2i(HeadlessHorseman.PRINTS.x >> 1, HeadlessHorseman.PRINTS.y >> 1)

var _stage: Node2D
var _car: CarController
var _camera: CameraRig
var _params: DisasterParams
## Physics frames stepped since play().
var _frames := 0
var _rider_sheet: Image
var _fire_sheet: Image
## The opaque texels of each frame of the hoofprints' sheet, from its middle.
var _prints_texels: Array[Array] = []


func before_all() -> void:
	var legend := HEADLESS_HORSEMAN.instantiate() as HeadlessHorseman
	_rider_sheet = (legend.get_node("%Horseman") as Sprite2D).texture.get_image()
	_fire_sheet = (legend.get_node("%Fire") as Sprite2D).texture.get_image()
	var prints_sheet := (legend.get_node("%Prints") as Sprite2D).texture.get_image()
	legend.free()
	var size := HeadlessHorseman.PRINTS
	for frame: int in HeadlessHorseman.STRIDES:
		var found: Array[Vector2i] = []
		for y: int in size.y:
			for x: int in size.x:
				if prints_sheet.get_pixel(frame * size.x + x, y).a > 0.0:
					found.append(Vector2i(x, y) - PRINTS_MIDDLE)
		_prints_texels.append(found)


func before_each() -> void:
	_stage = Disasters.stage(self)
	_car = Disasters.car(self, 0.0, _stage)
	_camera = Disasters.camera(self)


## The Headless Horseman, playing for the car with the car's place as its origin, as the director
## gives it, the car heading `heading`, a tile direction.
func _legend(heading := Vector2.UP) -> HeadlessHorseman:
	_car.modulate.a = 1.0
	# CarSim.forward() is (sin a, -cos a).
	_car.sim.angle = atan2(heading.x, -heading.y)
	var body := _car.get_node("%Body") as Sprite2D
	body.frame = CarController.frame(heading)
	var legend := Disasters.disaster(self, HEADLESS_HORSEMAN, _car, _camera) as HeadlessHorseman
	legend.stage = _stage
	_params = Disasters.params()
	_params.origin_world = _car.global_position
	_frames = 0
	legend.play(_params)
	return legend


## When each beat ends, in seconds after the delay.
static func _ends() -> Array[float]:
	var ends: Array[float] = []
	var sum := 0.0
	for length: float in Tuning.HEADLESS_HORSEMAN_BEATS:
		sum += length
		ends.append(sum)
	return ends


## When `share` of `beat` is done, in seconds after the delay.
static func _at(beat: int, share: float) -> float:
	return _ends()[beat] - Tuning.HEADLESS_HORSEMAN_BEATS[beat] * (1.0 - share)


## Steps `legend` on to `seconds` after its delay, and a frame or two past it: a clock that sums
## frames can fall short of the sum by a hair.
func _step_to(legend: HeadlessHorseman, seconds: float) -> void:
	var target := ceili((_params.delay + seconds) / DELTA) + 1
	simulate(legend, target - _frames, DELTA)
	_frames = target


## Steps `legend` one frame.
func _step(legend: HeadlessHorseman) -> void:
	simulate(legend, 1, DELTA)
	_frames += 1


## Whether `legend` has stepped on to `seconds` after its delay.
func _reached(seconds: float) -> bool:
	return _frames * DELTA >= _params.delay + seconds


## How far the steps have gone through `beat`, from 0 at its start to 1 at its end.
func _through(beat: int) -> float:
	var length: float = Tuning.HEADLESS_HORSEMAN_BEATS[beat]
	return (_frames * DELTA - _params.delay - _at(beat, 0.0)) / length


## Whether a step from here stays half a frame short of `seconds` after the delay, so that the
## legend's clock and theirs agree that it has not got there.
func _short_of(seconds: float) -> bool:
	return (_frames + 1) * DELTA < _params.delay + seconds - DELTA / 2.0


## Whether the steps are more than a frame away from `share` of `beat`, so that the legend's clock
## and theirs agree on which side of it they are.
func _clear_of(beat: int, share: float) -> bool:
	return absf(_through(beat) - share) > DELTA / Tuning.HEADLESS_HORSEMAN_BEATS[beat]


## Where `part` is, in px from the car.
func _from_car(part: Node2D) -> Vector2:
	return part.global_position - _car.global_position


## How far down from the car the bottom edge of what shows of `sprite` is, in px: of the rect that
## it draws, which its offset, its frames and its centring place.
func _bottom(sprite: Sprite2D) -> float:
	return _from_car(sprite).y + sprite.get_rect().end.y


## How far `part` is past where he halts, in tiles along the car's road, the car heading `heading`.
func _past(part: Node2D, heading: Vector2) -> float:
	var halted := heading * Tuning.HEADLESS_HORSEMAN_STOP_TILES
	return (Iso.world_to_tile(_from_car(part)) - halted).dot(heading)


## Where the middle of his hand's texel, HAND, is, in px from the car, as his place and his flip
## show it.
func _hand(rider: Sprite2D) -> Vector2:
	var hand := Vector2(HeadlessHorseman.HAND) + Vector2(0.5, 0.5)
	if rider.flip_h:
		hand.x = -hand.x
	return _from_car(rider) + hand


## Where the hoofprints that show lie on the ground, the car heading `heading`, in tiles: as x and
## y, the least and the most of the way along its road past where he halted, and as z, the most
## from the road's middle. Each texel counts by its middle, as the prints' place and flips show it.
func _reach(hoofprints: Sprite2D, heading: Vector2) -> Vector3:
	var halted := heading * Tuning.HEADLESS_HORSEMAN_STOP_TILES
	var across := Vector2(-heading.y, heading.x)
	var reach := Vector3(INF, -INF, 0.0)
	for texel: Vector2i in _prints_texels[hoofprints.frame]:
		var local := Vector2(texel) + Vector2(0.5, 0.5)
		if hoofprints.flip_h:
			local.x = -local.x
		if hoofprints.flip_v:
			local.y = -local.y
		var on_road := Iso.world_to_tile(_from_car(hoofprints) + local) - halted
		reach.x = minf(reach.x, on_road.dot(heading))
		reach.y = maxf(reach.y, on_road.dot(heading))
		reach.z = maxf(reach.z, absf(on_road.dot(across)))
	return reach


## How far `color` is from GHOST, the ghost's tint.
static func _from_ghost(color: Color) -> float:
	var ghost := HeadlessHorseman.GHOST
	return Vector3(color.r - ghost.r, color.g - ghost.g, color.b - ghost.b).length()


static func _near(a: Vector2, b: Vector2) -> bool:
	return absf(a.x - b.x) <= NEAR.x and absf(a.y - b.y) <= NEAR.y


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


## The smallest of `values`, or 0 if there are none.
static func _smallest(values: Array[float]) -> float:
	var least := 0.0 if values.is_empty() else values[0]
	for value: float in values:
		least = minf(least, value)
	return least


## Whether `values` only rise to their largest, and then only fall.
static func _peaked(values: Array[float]) -> bool:
	var top := values.find(_largest(values))
	for k: int in range(1, top + 1):
		if values[k] < values[k - 1]:
			return false
	for k: int in range(top + 1, values.size()):
		if values[k] > values[k - 1]:
			return false
	return true


## `values`, each once until it changes.
static func _changes(values: Array[int]) -> Array[int]:
	var found: Array[int] = []
	for value: int in values:
		if found.is_empty() or found[-1] != value:
			found.append(value)
	return found


## His horse's legs stretched and gathered in turn, `count` frames of his sheet.
static func _galloping(count: int) -> Array[int]:
	var found: Array[int] = []
	for k: int in count:
		var stretched := k % 2 == 0
		found.append(
			HeadlessHorseman.Pose.GALLOP_A if stretched else HeadlessHorseman.Pose.GALLOP_B
		)
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


## The opaque texels of `frame` of `sheet`, frames of `size` px.
static func _opaque(sheet: Image, size: Vector2i, frame: int) -> int:
	var count := 0
	for y: int in size.y:
		for x: int in size.x:
			if sheet.get_pixel(frame * size.x + x, y).a > 0.0:
				count += 1
	return count


## His standing part, which play() has put on the stage, out of reach of %names.
static func _rider(legend: HeadlessHorseman) -> Sprite2D:
	return legend.standing[0]


static func _fire(legend: HeadlessHorseman) -> Sprite2D:
	return legend.get_node("%Fire") as Sprite2D


static func _glow(legend: HeadlessHorseman) -> Sprite2D:
	return legend.get_node("%Glow") as Sprite2D


static func _dust(legend: HeadlessHorseman) -> CPUParticles2D:
	return legend.get_node("%Dust") as CPUParticles2D


static func _prints(legend: HeadlessHorseman) -> Sprite2D:
	return legend.get_node("%Prints") as Sprite2D


## The car's double, which the legend has put on the stage once it has taken the car, or null.
static func _double(legend: HeadlessHorseman) -> Sprite2D:
	for part: Sprite2D in legend.staged():
		if part not in legend.standing:
			return part
	return null


## The frame of the car's sheet that `car_double` shows.
static func _frame_of(car_double: Sprite2D) -> int:
	return roundi(car_double.region_rect.position.x / CarController.FRAME_SIZE.x)


## What of `legend` adds light: what it draws, what it has put on the stage, and its particles.
static func _glows(legend: HeadlessHorseman) -> Array[CanvasItem]:
	var items := Disasters.drawables(legend)
	for emitter: CPUParticles2D in Disasters.particles(legend):
		items.append(emitter)
	var found: Array[CanvasItem] = []
	for item: CanvasItem in items:
		var material := Disasters.material_of(item) as CanvasItemMaterial
		if material != null and material.blend_mode == CanvasItemMaterial.BLEND_MODE_ADD:
			found.append(item)
	return found


func test_a_headless_rider_gallops_along_the_road_and_halts_in_front_of_the_car() -> void:
	# From HEADLESS_HORSEMAN_FROM_TILES ahead along the car's road, on its middle, for each heading:
	# straight to HEADLESS_HORSEMAN_STOP_TILES ahead, slower and slower to a stop, facing the way he
	# gallops, his horse's legs stretching and gathering in turn, showing as he comes, the dust
	# flying from its hooves till he halts. He stands with the props, on his foot. Each frame of his
	# sheet stands on its bottom row.
	var size := HeadlessHorseman.RIDER
	for frame: int in HeadlessHorseman.Pose.size():
		var standing := false
		for x: int in size.x:
			standing = standing or _rider_sheet.get_pixel(frame * size.x + x, size.y - 1).a > 0.0
		assert_true(standing, "frame %d: he stands on its bottom row" % frame)
	var ends := _ends()
	var show_share := HeadlessHorseman.SHOW_SHARE
	for heading: Vector2 in HEADINGS:
		var what := "heading %s" % heading
		var far := HeadlessHorseman.far(heading)
		var halt := HeadlessHorseman.halt(heading)
		var from := heading * Tuning.HEADLESS_HORSEMAN_FROM_TILES
		var to := heading * Tuning.HEADLESS_HORSEMAN_STOP_TILES
		var tiles := Vector2.ONE * NEAR_TILES
		assert_almost_eq(Iso.world_to_tile(far), from, tiles, "%s: from far up its road" % what)
		assert_almost_eq(Iso.world_to_tile(halt), to, tiles, "%s: to in front of it" % what)
		var legend := _legend(heading)
		var rider := _rider(legend)
		var dust := _dust(legend)
		assert_eq(rider.get_parent(), _stage, "%s: he stands with the props" % what)
		var path: Array[Vector2] = [far]
		var alphas: Array[float] = [0.0]
		var frames: Array[int] = []
		var hidden := true
		var placed := true
		var facing := true
		var shown := true
		var dusty := true
		while _short_of(ends[0]):
			_step(legend)
			if _through(0) < 0.0 and _clear_of(0, 0.0):
				hidden = hidden and not Disasters.shows(rider) and not dust.emitting
			if _through(0) <= 0.0 or not _clear_of(0, 0.0):
				continue
			path.append(_from_car(rider))
			alphas.append(rider.modulate.a)
			frames.append(rider.frame)
			placed = placed and Disasters.z(rider) == 0
			placed = placed and absf(_bottom(rider) - path[-1].y) < NEAR.y
			placed = placed and absf(rider.get_rect().get_center().x) < NEAR.x
			facing = facing and rider.flip_h == (halt.x < far.x)
			dusty = dusty and dust.emitting and Disasters.particles_show(dust)
			dusty = dusty and _near(_from_car(dust), path[-1])
			if _through(0) > show_share and _clear_of(0, show_share):
				shown = shown and rider.modulate.a == 1.0
		_step_to(legend, ends[0])
		path.append(_from_car(rider))
		var left: Array[float] = []
		for point: Vector2 in path:
			left.append(point.distance_to(halt))
		var steps := _strides(path)
		var strides := _changes(frames)
		assert_true(hidden, "%s: unseen till he gallops in" % what)
		assert_true(placed, "%s: on his foot, with the props" % what)
		assert_true(facing, "%s: facing the way he gallops" % what)
		assert_eq(alphas, Disasters.sorted(alphas), "%s: he shows as he comes" % what)
		assert_lte(_largest_step(alphas), MOST_A_FRAME, "%s: bit by bit" % what)
		assert_true(shown, "%s: all of him, from SHOW_SHARE" % what)
		assert_eq(strides, _galloping(strides.size()), "%s: stride after stride" % what)
		assert_gte(strides.size(), LEAST_STRIDES, "%s: galloping" % what)
		assert_true(_straight(path, far, halt), "%s: straight along the road" % what)
		assert_eq(left, Disasters.sorted(left, true), "%s: only nearer" % what)
		assert_eq(steps, Disasters.sorted(steps, true), "%s: slower and slower" % what)
		assert_lt(steps[-1], SLOW_SHARE * _largest(steps), "%s: to a stop" % what)
		assert_almost_eq(path[-1], halt, NEAR, "%s: where he halts" % what)
		assert_true(dusty, "%s: the dust flies from his horse's hooves" % what)
		assert_false(dust.emitting, "%s: till he halts" % what)


func test_he_raises_a_ball_of_ghost_fire_that_grows_in_his_hand() -> void:
	# Once he has halted, for each heading: he raises his hand, the texel HAND of his frame RAISE,
	# in the palette's line, mirrored with him; and a ball of ghost-fire grows in it, a frame at a
	# time, to its full size, as its glow lights with it.
	var ends := _ends()
	var size := HeadlessHorseman.RIDER
	var foot := Vector2i(HeadlessHorseman.Pose.RAISE * size.x + (size.x >> 1), size.y)
	var raised_hand := _rider_sheet.get_pixelv(foot + HeadlessHorseman.HAND)
	var line: Color = Art.MakeArt.palette()["line"]
	assert_true(raised_hand.is_equal_approx(line), "his raised hand: %s" % raised_hand)
	for heading: Vector2 in HEADINGS:
		var what := "heading %s" % heading
		var legend := _legend(heading)
		var rider := _rider(legend)
		var fire := _fire(legend)
		var glow := _glow(legend)
		var unlit := true
		while _short_of(ends[0]):
			_step(legend)
			unlit = unlit and not Disasters.shows(fire) and not Disasters.shows(glow)
		_step_to(legend, ends[0])
		var held := _hand(rider)
		var raised := true
		var in_hand := true
		var sizes: Array[float] = [fire.scale.x]
		var lights: Array[float] = [glow.modulate.a]
		while _short_of(ends[1]):
			_step(legend)
			raised = raised and rider.frame == HeadlessHorseman.Pose.RAISE
			in_hand = in_hand and fire.frame == HeadlessHorseman.Fire.BALL
			in_hand = in_hand and _near(_from_car(fire), held) and _near(_from_car(glow), held)
			in_hand = in_hand and Disasters.shows(fire) and fire.scale.x == fire.scale.y
			sizes.append(fire.scale.x)
			lights.append(glow.modulate.a)
		_step_to(legend, ends[1])
		sizes.append(fire.scale.x)
		lights.append(glow.modulate.a)
		assert_true(unlit, "%s: no fire till he halts" % what)
		assert_true(raised, "%s: he raises his hand" % what)
		assert_true(in_hand, "%s: a ball of ghost-fire in it" % what)
		assert_lt(sizes[0], MOST_A_FRAME, "%s: from nothing" % what)
		assert_eq(sizes, Disasters.sorted(sizes), "%s: it grows" % what)
		assert_lte(_largest_step(sizes), MOST_A_FRAME, "%s: a frame at a time" % what)
		assert_eq(sizes[-1], 1.0, "%s: to its full size" % what)
		assert_eq(lights, Disasters.sorted(lights), "%s: its glow lights with it" % what)
		var most := MOST_A_FRAME * Tuning.HEADLESS_HORSEMAN_GLOW_ALPHA
		assert_lte(_largest_step(lights), most, "%s: bit by bit" % what)
		var bright := Tuning.HEADLESS_HORSEMAN_GLOW_ALPHA
		assert_almost_eq(lights[-1], bright, NEAR_ALPHA, "%s: as bright as it gets" % what)


func test_he_hurls_it_at_the_car_in_a_shallow_arc() -> void:
	# From his hand to the car's middle, for each heading, its glow with it: only nearer to the
	# car's middle, over the straight way there, never by more than HEADLESS_HORSEMAN_ARC_PX, rising
	# and then falling back to it. His arm is thrown out after it.
	var ends := _ends()
	var middle := WitchHex.car_middle()
	var arc := Tuning.HEADLESS_HORSEMAN_ARC_PX
	for heading: Vector2 in HEADINGS:
		var what := "heading %s" % heading
		var legend := _legend(heading)
		var rider := _rider(legend)
		var fire := _fire(legend)
		var glow := _glow(legend)
		_step_to(legend, ends[1])
		var from := _hand(rider)
		var hurled := true
		var with_it := true
		var left: Array[float] = [from.distance_to(middle)]
		var heights: Array[float] = [0.0]
		while _short_of(ends[2]):
			_step(legend)
			var at := _from_car(fire)
			hurled = hurled and rider.frame == HeadlessHorseman.Pose.HURL
			hurled = hurled and fire.frame == HeadlessHorseman.Fire.BALL
			hurled = hurled and fire.scale == Vector2.ONE and Disasters.shows(fire)
			with_it = with_it and _near(_from_car(glow), at)
			var bright := Tuning.HEADLESS_HORSEMAN_GLOW_ALPHA
			with_it = with_it and absf(glow.modulate.a - bright) <= NEAR_ALPHA
			left.append(at.distance_to(middle))
			var straight := from.lerp(middle, (at.x - from.x) / (middle.x - from.x))
			heights.append(straight.y - at.y)
		assert_true(hurled, "%s: he hurls a ball of ghost-fire" % what)
		assert_true(with_it, "%s: its glow with it" % what)
		assert_eq(left, Disasters.sorted(left, true), "%s: only nearer the car" % what)
		assert_lte(left[-1], 2.0 * _largest_step(left), "%s: to the car's middle" % what)
		assert_gte(_smallest(heights), -NEAR.y, "%s: over the straight way" % what)
		assert_lte(_largest(heights), arc + NEAR.y, "%s: a shallow arc" % what)
		assert_gte(_largest(heights), ARC_SHARE * arc, "%s: an arc" % what)
		assert_true(_peaked(heights), "%s: rising and falling" % what)


func test_its_flames_run_over_the_car_which_pales_to_a_ghost_of_itself_and_fades() -> void:
	# For each heading: the car is there till the ghost-fire strikes it. Then its double takes its
	# place, in the same frame, where it stood and facing as it did, with the props, and pale
	# flames run over it, more and more, on its middle, as it pales to a see-through ghost of
	# itself, tinted GHOST. Then the flames and the ghost fade to nothing.
	var ends := _ends()
	var middle := WitchHex.car_middle()
	var fire_size := HeadlessHorseman.FIRE
	var flames: Array[float] = []
	for frame: int in range(HeadlessHorseman.Fire.KINDLE_A, HeadlessHorseman.Fire.size()):
		flames.append(float(_opaque(_fire_sheet, fire_size, frame)))
	for k: int in range(1, flames.size()):
		assert_gt(flames[k], flames[k - 1], "kindling %d: more flames than before" % k)
	var kindling: Array[int] = [
		HeadlessHorseman.Fire.KINDLE_A,
		HeadlessHorseman.Fire.KINDLE_B,
		HeadlessHorseman.Fire.KINDLE_C,
	]
	for heading: Vector2 in HEADINGS:
		var what := "heading %s" % heading
		var legend := _legend(heading)
		var fire := _fire(legend)
		var there := true
		while _short_of(ends[2]):
			_step(legend)
			there = there and _double(legend) == null and _car.modulate.a == 1.0
		assert_true(there, "%s: the car is there till the fire strikes it" % what)
		while _double(legend) == null and not _reached(ends[3]):
			_step(legend)
		var car_double := _double(legend)
		if car_double == null:
			fail_test("%s: its double took its place" % what)
			continue
		var beat: float = Tuning.HEADLESS_HORSEMAN_BEATS[3]
		assert_lt(_through(3), 2.0 * DELTA / beat, "%s: as the fire strikes" % what)
		assert_eq(_car.modulate.a, 0.0, "%s: the double took the car's place" % what)
		assert_true(Disasters.shows(car_double), "%s: in the same frame" % what)
		assert_almost_eq(_from_car(car_double), Vector2.ZERO, NEAR, "%s: where it stood" % what)
		assert_eq(_frame_of(car_double), CarController.frame(heading), "%s: facing so" % what)
		assert_eq(car_double.get_parent(), _stage, "%s: with the props" % what)
		assert_eq(Disasters.z(car_double), 0, "%s: sorting with them" % what)
		var staged: Array[Sprite2D] = [_rider(legend), car_double]
		assert_eq(legend.staged(), staged, "%s: it frees it" % what)
		var frames: Array[int] = [fire.frame]
		var fading: Array[float] = [fire.modulate.a]
		var paling: Array[float] = [_from_ghost(car_double.self_modulate)]
		var ghostly: Array[float] = [car_double.modulate.a]
		var on_car := _near(_from_car(fire), middle) and fire.scale == Vector2.ONE
		var spread_share := HeadlessHorseman.SPREAD_SHARE
		var in_time := true
		var see_through := -1.0
		while _short_of(ends[3]):
			_step(legend)
			frames.append(fire.frame)
			fading.append(fire.modulate.a)
			paling.append(_from_ghost(car_double.self_modulate))
			ghostly.append(car_double.modulate.a)
			on_car = on_car and _near(_from_car(fire), middle) and fire.scale == Vector2.ONE
			if _clear_of(3, spread_share):
				var all_over := fire.frame == HeadlessHorseman.Fire.KINDLE_C
				in_time = in_time and all_over == (_through(3) > spread_share)
			var ghosted := car_double.self_modulate.is_equal_approx(HeadlessHorseman.GHOST)
			if ghosted and see_through < 0.0:
				see_through = car_double.modulate.a
		_step_to(legend, ends[3])
		fading.append(fire.modulate.a)
		ghostly.append(car_double.modulate.a)
		assert_eq(_changes(frames), kindling, "%s: its flames run over the car" % what)
		assert_true(on_car, "%s: on its middle" % what)
		assert_true(in_time, "%s: all over it from SPREAD_SHARE" % what)
		assert_almost_eq(paling[0], _from_ghost(Color.WHITE), MOST_A_FRAME, "%s: as it was" % what)
		assert_eq(paling, Disasters.sorted(paling, true), "%s: it pales" % what)
		assert_almost_eq(paling[-1], 0.0, NEAR_ALPHA, "%s: to a ghost of itself" % what)
		var ghost := HeadlessHorseman.GHOST_ALPHA
		assert_almost_eq(see_through, ghost, NEAR_ALPHA, "%s: see-through" % what)
		assert_eq(ghostly, Disasters.sorted(ghostly, true), "%s: it only fades" % what)
		assert_lte(_largest_step(ghostly), MOST_A_FRAME, "%s: bit by bit" % what)
		assert_eq(fading, Disasters.sorted(fading, true), "%s: the flames only fade" % what)
		assert_lte(_largest_step(fading), MOST_A_FRAME, "%s: bit by bit" % what)
		assert_false(Disasters.shows(car_double), "%s: to nothing" % what)
		assert_false(Disasters.shows(fire), "%s: the flames too" % what)
		assert_eq(_car.modulate.a, 0.0, "%s: the car is gone" % what)


func test_he_wheels_round_and_gallops_off_the_way_he_came_and_his_hoofprints_stay() -> void:
	# As the fire strikes, for each heading, he turns to face the way he came, and waits where he
	# halted; then he gallops off along the road, straight back to where he came from, faster and
	# faster, his horse's legs stretching and gathering in turn, the dust flying from its hooves,
	# fading to nothing as he goes. His horse's hooves scorch the road behind him: the prints of
	# each stride show only once he has passed them, on the road between where he halted and where
	# he is, under the props. He has left all of them before he is gone, and they stay.
	var ends := _ends()
	var stride_tiles := HeadlessHorseman.PRINTS_TILES / HeadlessHorseman.STRIDES
	var all_strides := HeadlessHorseman.STRIDES - 1
	for heading: Vector2 in HEADINGS:
		var what := "heading %s" % heading
		var far := HeadlessHorseman.far(heading)
		var halt := HeadlessHorseman.halt(heading)
		var legend := _legend(heading)
		var rider := _rider(legend)
		var dust := _dust(legend)
		var hoofprints := _prints(legend)
		assert_eq(hoofprints.get_parent(), legend, "%s: the prints lie under the props" % what)
		assert_eq(Disasters.z(hoofprints), 0, "%s: on the ground" % what)
		var unprinted := true
		while _short_of(ends[2]):
			_step(legend)
			unprinted = unprinted and not Disasters.shows(hoofprints)
		_step_to(legend, ends[2])
		var path: Array[Vector2] = [_from_car(rider)]
		var alphas: Array[float] = [rider.modulate.a]
		var frames: Array[int] = []
		var facing := rider.flip_h == (far.x < halt.x)
		var waited := _near(path[0], halt)
		var stood := 0
		var dusty := true
		var behind := true
		var on_road := true
		var left_all := -1.0
		while _short_of(ends[3]):
			_step(legend)
			path.append(_from_car(rider))
			alphas.append(rider.modulate.a)
			facing = facing and rider.flip_h == (far.x < halt.x)
			var past := _past(rider, heading)
			if rider.frame == HeadlessHorseman.Pose.STAND:
				stood += 1
				waited = waited and frames.is_empty() and _near(path[-1], halt)
				waited = waited and not dust.emitting
			else:
				frames.append(rider.frame)
				dusty = dusty and dust.emitting and Disasters.particles_show(dust)
				dusty = dusty and _near(_from_car(dust), path[-1])
			if not Disasters.shows(hoofprints):
				continue
			var lying := _reach(hoofprints, heading)
			behind = behind and lying.x >= -NEAR_TILES and lying.y <= past + NEAR_TILES
			on_road = on_road and lying.z <= Tuning.ROAD_HALF_WIDTH
			if left_all < 0.0 and hoofprints.frame == all_strides:
				left_all = rider.modulate.a
		var steps := _strides(path)
		_step_to(legend, ends[3])
		path.append(_from_car(rider))
		alphas.append(rider.modulate.a)
		var gone: Array[float] = []
		for point: Vector2 in path:
			gone.append(point.distance_to(halt))
		var strides := _changes(frames)
		var reach := _reach(hoofprints, heading)
		assert_true(unprinted, "%s: no hoofprints till he gallops off" % what)
		assert_true(facing, "%s: he wheels round to face the way he came" % what)
		assert_true(waited, "%s: and stands where he halted" % what)
		assert_gt(stood, 0, "%s: a moment" % what)
		assert_true(_straight(path, halt, far), "%s: straight along the road" % what)
		assert_eq(gone, Disasters.sorted(gone), "%s: only farther" % what)
		assert_eq(steps, Disasters.sorted(steps), "%s: faster and faster" % what)
		assert_almost_eq(path[-1], far, NEAR, "%s: to where he came from" % what)
		assert_eq(strides, _galloping(strides.size()), "%s: stride after stride" % what)
		assert_gte(strides.size(), LEAST_STRIDES, "%s: galloping" % what)
		assert_true(dusty, "%s: the dust flies from his horse's hooves" % what)
		assert_false(dust.emitting, "%s: till he is gone" % what)
		assert_eq(alphas, Disasters.sorted(alphas, true), "%s: he fades" % what)
		assert_lte(_largest_step(alphas), MOST_A_FRAME, "%s: bit by bit" % what)
		assert_false(Disasters.shows(rider), "%s: to nothing" % what)
		assert_true(behind, "%s: each stride's prints once he has passed them" % what)
		assert_true(on_road, "%s: on the road" % what)
		assert_gt(left_all, 0.0, "%s: all of them before he is gone" % what)
		assert_true(Disasters.shows(hoofprints), "%s: the prints stay" % what)
		var last := (HeadlessHorseman.STRIDES - 1) * stride_tiles
		assert_gt(reach.y, last, "%s: all his strides' prints" % what)
		_step_to(legend, ends[3] + 1.0)
		assert_true(Disasters.shows(hoofprints), "%s: they stay after its end" % what)


func test_its_one_glow_is_the_ghost_fire_which_lights_in_his_hand_and_fades_on_the_car() -> void:
	# Dusk falls as he gallops in. The ghost-fire's glow, pale green, lights as the ball grows in
	# his hand, flies with it, and fades with its flames on the car: it only brightens, then only
	# fades, and it shows only with the fire, where the fire is (§5.6).
	var ends := _ends()
	var palette := Art.MakeArt.palette()
	var legend := _legend()
	var fire := _fire(legend)
	var glow := _glow(legend)
	assert_eq(legend.veil_kind, Legend.Veil.DUSK, "dusk falls")
	assert_eq(_glows(legend), [glow] as Array[CanvasItem], "its only glow")
	assert_eq(glow.texture, GLOW, "a soft glow")
	assert_true(glow.self_modulate.is_equal_approx(palette["wisp"]), "pale green")
	var tint := glow.self_modulate
	assert_lt(tint.r, Tuning.FLASH_RED_SHARE * (tint.r + tint.g + tint.b), "not red")
	assert_eq(Disasters.z(glow), Tuning.GLOW_Z, "over the dusk")
	var small := Vector2.ONE * HeadlessHorseman.GLOW_SCALE
	assert_almost_eq(glow.scale, small, NEAR, "small")
	var rising: Array[float] = []
	var fading: Array[float] = []
	var with_it := true
	watch_signals(legend)
	while get_signal_emit_count(legend, "finished") == 0 and _frames < Disasters.MAX_FRAMES:
		_step(legend)
		if _reached(ends[2]):
			fading.append(glow.modulate.a)
		else:
			rising.append(glow.modulate.a)
		if Disasters.shows(glow):
			with_it = with_it and Disasters.shows(fire)
			with_it = with_it and _near(_from_car(glow), _from_car(fire))
	assert_lt(_frames, Disasters.MAX_FRAMES, "it finishes")
	assert_eq(rising, Disasters.sorted(rising), "it only brightens")
	var bright := Tuning.HEADLESS_HORSEMAN_GLOW_ALPHA
	assert_almost_eq(rising[-1], bright, NEAR_ALPHA, "to its brightest")
	assert_eq(fading, Disasters.sorted(fading, true), "then only fades")
	assert_eq(fading[-1], 0.0, "to nothing")
	assert_true(with_it, "it shows only with the fire, where it is")
	assert_eq(_glows(legend), [glow] as Array[CanvasItem], "still its only glow, the car taken")


func test_its_light_rises_at_each_point_at_most_once_whichever_way_the_car_heads() -> void:
	# test_none_flashes plays it one way. For each heading, the ghost-fire takes another path; on
	# each, its light rises at each point of the world by more than FLASH_CHANGE of white's at most
	# once, so it never flashes (§5.6).
	var change := Tuning.FLASH_CHANGE * Color.WHITE.get_luminance()
	for heading: Vector2 in HEADINGS:
		var what := "heading %s" % heading
		var legend := _legend(heading)
		watch_signals(legend)
		var lights: Array[Dictionary] = []
		var reds: Array[Dictionary] = []
		var images: Dictionary[Texture2D, Image] = {}
		while get_signal_emit_count(legend, "finished") == 0:
			if lights.size() >= Disasters.MAX_FRAMES:
				fail_test("%s: it finishes" % what)
				break
			_step(legend)
			var light: Dictionary[Vector2i, float] = {}
			var red: Dictionary[Vector2i, float] = {}
			for glow: CanvasItem in _glows(legend):
				Disasters.shine(glow as Sprite2D, light, red, images)
			lights.append(light)
			reds.append(red)
		var points: Dictionary[Vector2i, bool] = {}
		for light: Dictionary in lights:
			for point: Vector2i in light:
				points[point] = true
		assert_gt(points.size(), 0, "%s: its glow lights the world" % what)
		var twice: Array[Vector2i] = []
		for point: Vector2i in points:
			var values := PackedFloat32Array()
			for light: Dictionary in lights:
				values.append(light.get(point, 0.0))
			if Disasters._turns(values, change)[0].size() > 1:
				twice.append(point * Tuning.FLASH_GRID)
		assert_eq(twice, [] as Array[Vector2i], "%s: lit twice" % what)
		assert_eq(Disasters.flashing(lights, reds), "", what)


func test_he_his_ghost_fire_and_his_hoofprints_stand_out_from_rural_at_dusk() -> void:
	# Each frame of each sheet, against Rural's road and ground, in each key light, under his dusk
	# veil; and the ghost-fire's glow, added over them as bright as it gets (POOLS_PLAN.md §5.6,
	# V15, P13b).
	var legend := _legend()
	var parts: Dictionary[String, Sprite2D] = {
		"the Horseman": _rider(legend),
		"his ghost-fire": _fire(legend),
		"his hoofprints": _prints(legend),
	}
	for what: String in parts:
		var part := parts[what]
		var image := part.texture.get_image()
		var share := Art.night_share(image, part.hframes, RURAL, legend.veil_kind)
		var told := "%s: %.0f%% of its least frame's pixels stand out" % [what, share * 100.0]
		assert_gte(share, Art.NIGHT_SHARE, told)
	var glow := _glow(legend)
	var tint := Color(glow.self_modulate, Tuning.HEADLESS_HORSEMAN_GLOW_ALPHA)
	var lit := Art.glow_share(glow.texture.get_image(), tint, RURAL, legend.veil_kind)
	assert_gte(lit, Art.NIGHT_SHARE, "its glow: %.0f%% of its pixels stand out" % (lit * 100.0))
