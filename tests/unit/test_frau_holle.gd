extends GutTest
## Frau Holle's Well, the Village's second legend (POOLS_PLAN.md §5.4). Snow starts to fall round
## the car, and a stone well rises out of the ground beside the road. The car tips over towards it,
## then falls in, turning over and over, smaller and smaller, as the snow settles on the well, in
## the light of the hour. The well stays, capped with snow.

const Disasters := preload("res://tests/helpers/disaster_fixtures.gd")
const Art := preload("res://tests/helpers/art_checks.gd")
const FRAU_HOLLE := preload("res://disasters/legends/frau_holle.tscn")
const VILLAGE := preload("res://areas/village.tres")
const DELTA := 1.0 / 60.0
## How near a place must be, in px.
const NEAR := Vector2(0.001, 0.001)
## How near a share of tiles must be: Iso maps tiles to px and back in 32-bit floats.
const NEAR_TILES := 1e-4
## The most of its full height the well may rise by in a frame, of their full turns the car may
## tip and turn by, and of its size it may shrink by: they move, they don't pop. Also how near the
## car must have tipped and turned all the way in the last frame of each: a frame short of the end.
const MOST_A_FRAME := 0.25
## How far the car may have tipped halfway through the tip, at most: a third of the way, for it tips
## faster and faster.
const HALF_TIPPED := 1.0 / 3.0
## The car's headings, as tile directions: the roads run along the tile axes.
const HEADINGS: Array[Vector2] = [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]
## How far across its dead end from the road's middle a wrong turn can leave the car, in tiles, as
## it brakes straight on from mid-turn, as test_kelpie.gd finds: off the road, in the dead end's
## cell (OFF_ROAD_TILES), or in the next cell across (BESIDE_TILES), as far as a hair short of that
## cell's middle (NEXT_MIDDLE_TILES). FAR_OFF_TILES is two cells across, off any road.
const OFF_ROAD_TILES := 0.47
const BESIDE_TILES := 0.67
const NEXT_MIDDLE_TILES := 0.99
const FAR_OFF_TILES := 1.67
## Where the car stops on a dead end, in tiles down-screen of its first cell's middle: on the road's
## middle, and each of the above to either side of it.
const STOPS: Array[float] = [
	0.0,
	-OFF_ROAD_TILES,
	OFF_ROAD_TILES,
	-BESIDE_TILES,
	BESIDE_TILES,
	-NEXT_MIDDLE_TILES,
	NEXT_MIDDLE_TILES,
	-FAR_OFF_TILES,
	FAR_OFF_TILES,
]

var _stage: Node2D
var _car: CarController
var _camera: CameraRig
var _params: DisasterParams
## Physics frames stepped since play().
var _frames := 0
var _sheet: Image


func before_all() -> void:
	var holle := FRAU_HOLLE.instantiate() as FrauHolle
	_sheet = (holle.get_node("%Well") as Sprite2D).texture.get_image()
	holle.free()


func before_each() -> void:
	_stage = Disasters.stage(self)
	_car = Disasters.car(self, 0.0, _stage)
	_camera = Disasters.camera(self)


## Frau Holle's Well, playing for the car with the car's place as its origin, as the director gives
## it, the car heading `heading`, a tile direction.
func _holle(heading := Vector2.UP) -> FrauHolle:
	_car.modulate.a = 1.0
	# CarSim.forward() is (sin a, -cos a).
	_car.sim.angle = atan2(heading.x, -heading.y)
	var body := _car.get_node("%Body") as Sprite2D
	body.frame = CarController.frame(heading)
	var holle := Disasters.disaster(self, FRAU_HOLLE, _car, _camera) as FrauHolle
	holle.stage = _stage
	_params = Disasters.params()
	_params.origin_world = _car.global_position
	_frames = 0
	holle.play(_params)
	return holle


## When each beat ends, in seconds after the delay.
static func _ends() -> Array[float]:
	var ends: Array[float] = []
	var sum := 0.0
	for length: float in Tuning.FRAU_HOLLE_BEATS:
		sum += length
		ends.append(sum)
	return ends


## When `share` of `beat` is done, in seconds after the delay.
static func _at(beat: int, share: float) -> float:
	return _ends()[beat] - Tuning.FRAU_HOLLE_BEATS[beat] * (1.0 - share)


## Steps `holle` on to `seconds` after its delay, and a frame or two past it: a clock that sums
## frames can fall short of the sum by a hair.
func _step_to(holle: FrauHolle, seconds: float) -> void:
	var target := ceili((_params.delay + seconds) / DELTA) + 1
	simulate(holle, target - _frames, DELTA)
	_frames = target


## Steps `holle` one frame.
func _step(holle: FrauHolle) -> void:
	simulate(holle, 1, DELTA)
	_frames += 1


## Whether `holle` has stepped on to `seconds` after its delay.
func _reached(seconds: float) -> bool:
	return _frames * DELTA >= _params.delay + seconds


## How far the steps have gone through `beat`, from 0 at its start to 1 at its end.
func _through(beat: int) -> float:
	return (_frames * DELTA - _params.delay - _at(beat, 0.0)) / Tuning.FRAU_HOLLE_BEATS[beat]


## Whether a step from here stays half a frame short of `seconds` after the delay, so that the
## legend's clock and theirs agree that it has not got there.
func _short_of(seconds: float) -> bool:
	return (_frames + 1) * DELTA < _params.delay + seconds - DELTA / 2.0


## Whether the steps are more than a frame away from `share` of `beat`, so that the legend's clock
## and theirs agree on which side of it they are.
func _clear_of(beat: int, share: float) -> bool:
	return absf(_through(beat) - share) > DELTA / Tuning.FRAU_HOLLE_BEATS[beat]


## Where `part` is, in px from the car.
func _from_car(part: Node2D) -> Vector2:
	return part.global_position - _car.global_position


## How far down from the car the bottom edge of what shows of `sprite` is, in px: of the rect that
## it draws, which its offset, its region, its frames and its centring place.
func _bottom(sprite: Sprite2D) -> float:
	return _from_car(sprite).y + sprite.get_rect().end.y


## Where `point` of the car's double, in px from its ground point in its frame, shows, in px from
## the car: as the double's offset, rounded to whole pixels as it's drawn, its turn and its size
## place it.
func _drawn(car_double: Sprite2D, point: Vector2) -> Vector2:
	var texel := car_double.get_rect().position + Vector2(CarController.FOOT) + point
	return car_double.get_global_transform() * texel - _car.global_position


## Whether `a` is within NEAR of `b`.
static func _near(a: Vector2, b: Vector2) -> bool:
	return absf(a.x - b.x) <= NEAR.x and absf(a.y - b.y) <= NEAR.y


## Whether `drawn`, a point of the car's double as _drawn() gives it, shows where the legend puts
## it, at `want`: the project snaps 2D transforms to pixels, so Sprite2D draws its offset, and
## get_rect() gives it, rounded to whole pixels. Once the double turns about a point, its offset is
## a fraction, so a point may show up to half a pixel off each way in its frame, as its turn and its
## size carry that.
static func _snapped_near(car_double: Sprite2D, drawn: Vector2, want: Vector2) -> bool:
	return drawn.distance_to(want) <= _snap(car_double) + NEAR.x


## How far that rounding may carry a point of `car_double` from where the legend puts it, in px.
static func _snap(car_double: Sprite2D) -> float:
	return Vector2(0.5, 0.5).length() * car_double.scale.x


## The largest change between one of `values` and the next.
static func _largest_step(values: Array[float]) -> float:
	var most := 0.0
	for k: int in range(1, values.size()):
		most = maxf(most, absf(values[k] - values[k - 1]))
	return most


## `values`, each once until it changes.
static func _changes(values: Array[int]) -> Array[int]:
	var found: Array[int] = []
	for value: int in values:
		if found.is_empty() or found[-1] != value:
			found.append(value)
	return found


## The well, which play() has put on the stage, out of reach of %names.
static func _well(holle: FrauHolle) -> Sprite2D:
	return holle.standing[0]


static func _snow(holle: FrauHolle) -> CPUParticles2D:
	return holle.get_node("%Snow") as CPUParticles2D


## The car's double, which the legend has put on the stage once it has taken the car, or null.
static func _double(holle: FrauHolle) -> Sprite2D:
	for part: Sprite2D in holle.staged():
		if part not in holle.standing:
			return part
	return null


## The frame of the car's sheet that `car_double` shows.
static func _frame_of(car_double: Sprite2D) -> int:
	return roundi(car_double.region_rect.position.x / CarController.FRAME_SIZE.x)


## Which way the car tips for `heading`, towards the well: 1 for the screen's right, -1 for its
## left. Its pivot, mirrored to that side.
static func _side(heading: Vector2) -> float:
	return signf(FrauHolle.well(heading).x)


static func _pivot(heading: Vector2) -> Vector2:
	return Vector2(FrauHolle.PIVOT.x * _side(heading), FrauHolle.PIVOT.y)


## What of `holle` adds light: what it draws, what it has put on the stage, and its particles.
static func _glows(holle: FrauHolle) -> Array[CanvasItem]:
	var items := Disasters.drawables(holle)
	for emitter: CPUParticles2D in Disasters.particles(holle):
		items.append(emitter)
	var found: Array[CanvasItem] = []
	for item: CanvasItem in items:
		var material := Disasters.material_of(item) as CanvasItemMaterial
		if material != null and material.blend_mode == CanvasItemMaterial.BLEND_MODE_ADD:
			found.append(item)
	return found


## The texel of `frame` of the well's sheet at `at` px from its foot.
func _texel(frame: int, at: Vector2i) -> Color:
	var foot := Vector2i(frame * FrauHolle.WELL.x + (FrauHolle.WELL.x >> 1), FrauHolle.WELL.y)
	return _sheet.get_pixelv(foot + at)


## How many texels of `frame` of the well's sheet are the palette's `paint`.
func _count(frame: int, paint: String) -> int:
	var color: Color = Art.MakeArt.palette()[paint]
	var count := 0
	for y: int in FrauHolle.WELL.y:
		for x: int in FrauHolle.WELL.x:
			if _sheet.get_pixel(frame * FrauHolle.WELL.x + x, y).is_equal_approx(color):
				count += 1
	return count


## The first tile of the first dead end of each heading in `buffer`, of those with no road in the
## two cells to either side of it, across its road, as test_kelpie.gd finds them.
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


## How many of the opaque texels of the bottom row of `well`'s frame, where it stands on the
## ground, lie on the road of the car's buffer, each by its middle, the car's ground point being
## `at`, in tiles.
func _foot_on_road(well: Sprite2D, at: Vector2) -> int:
	var half := FrauHolle.WELL.x >> 1
	var count := 0
	for x: int in FrauHolle.WELL.x:
		var texel := Vector2i(x - half, -1)
		if _texel(well.frame, texel).a == 0.0:
			continue
		var ground := _from_car(well) + Vector2(texel) + Vector2(0.5, 0.5)
		if _on_road(at + Iso.world_to_tile(ground)):
			count += 1
	return count


## Checks that the snow of `holle` falls on the car and on the well, which stands `well_at` from
## the car, in px: from a rect over them both, from either side of their frames, from over the
## well's top, down, in front of them.
func _assert_snows_on_them(holle: FrauHolle, well_at: Vector2, what: String) -> void:
	var snow := _snow(holle)
	var over := _from_car(snow)
	var extents := snow.emission_rect_extents
	var rect := CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	var half := FrauHolle.WELL.x / 2.0
	var left := minf(-CarController.FOOT.x, well_at.x - half)
	var right := maxf(CarController.FRAME_SIZE.x - CarController.FOOT.x, well_at.x + half)
	assert_eq(snow.emission_shape, rect, "%s: from a rect" % what)
	assert_lte(over.x - extents.x, left, "%s: over the car and the well" % what)
	assert_gte(over.x + extents.x, right, "%s: from either side of them" % what)
	assert_lte(over.y - extents.y, well_at.y - FrauHolle.WELL.y, "%s: from over them" % what)
	assert_gt(snow.direction.y, 0.0, "%s: down" % what)
	assert_gt(Disasters.z(snow), 0, "%s: in front of them" % what)


func test_snow_starts_to_fall_round_the_car() -> void:
	# From the start, over the car and over where the well rises, in front of all that stands: it
	# falls on them. It falls till the car has fallen in.
	var ends := _ends()
	for heading: Vector2 in HEADINGS:
		var what := "heading %s" % heading
		var holle := _holle(heading)
		var snow := _snow(holle)
		var well_at := FrauHolle.well(heading)
		var falling := true
		var fell := false
		while _short_of(ends[3]):
			_step(holle)
			if _clear_of(0, 0.0):
				falling = falling and snow.emitting == (_through(0) > 0.0)
			fell = fell or snow.emitting
		assert_true(falling and fell, "%s: it falls from the start till the end" % what)
		_assert_snows_on_them(holle, well_at, what)


func test_a_stone_well_rises_out_of_the_ground_beside_the_road() -> void:
	# Beside the car, off its road up the screen, with the props, once the snow has fallen a while:
	# bare, bit by bit, only up, till it stands whole. Each frame stands on its bottom row, and its
	# mouth, where the car falls in, is dark.
	var ink: Color = Art.MakeArt.palette()["ink"]
	for frame: int in FrauHolle.Cap.size():
		var standing := false
		for x: int in FrauHolle.WELL.x:
			standing = standing or _texel(frame, Vector2i(x - (FrauHolle.WELL.x >> 1), -1)).a > 0.0
		assert_true(standing, "frame %d: it stands on its bottom row" % frame)
		var mouth := _texel(frame, Vector2i(FrauHolle.MOUTH))
		assert_true(mouth.is_equal_approx(ink), "frame %d: its mouth is dark" % frame)
	var ends := _ends()
	for heading: Vector2 in HEADINGS:
		var what := "heading %s" % heading
		var well_at := FrauHolle.well(heading)
		var off_road := Iso.world_to_tile(well_at)
		assert_almost_eq(off_road.dot(heading), 0.0, NEAR_TILES, "%s: beside the car" % what)
		var off := off_road.length()
		assert_almost_eq(off, Tuning.FRAU_HOLLE_SIDE_TILES, NEAR_TILES, "%s: off its road" % what)
		assert_lt(well_at.y, 0.0, "%s: up the screen from it" % what)
		var holle := _holle(heading)
		var well := _well(holle)
		assert_eq(well.get_parent(), _stage, "%s: it stands with the props" % what)
		var heights: Array[float] = [0.0]
		var hidden := true
		var rising := true
		while _short_of(ends[1]):
			_step(holle)
			if _through(1) < 0.0 and _clear_of(1, 0.0):
				hidden = hidden and not Disasters.shows(well)
			if not Disasters.shows(well):
				continue
			heights.append(well.region_rect.size.y)
			rising = rising and well.frame == FrauHolle.Cap.BARE and Disasters.z(well) == 0
			rising = rising and _near(_from_car(well), well_at)
			rising = rising and absf(_bottom(well) - well_at.y) < NEAR.y
			var left := _from_car(well).x + well.get_rect().position.x
			rising = rising and is_equal_approx(left, well_at.x - FrauHolle.WELL.x / 2.0)
		_step_to(holle, ends[1])
		heights.append(well.region_rect.size.y)
		assert_true(hidden, "%s: once the snow has fallen a while" % what)
		assert_true(rising, "%s: bare, there, with the props" % what)
		assert_eq(heights, Disasters.sorted(heights), "%s: only up" % what)
		var most := MOST_A_FRAME * FrauHolle.WELL.y
		assert_lte(_largest_step(heights), most, "%s: bit by bit" % what)
		assert_eq(heights[-1], float(FrauHolle.WELL.y), "%s: all of it" % what)
		assert_eq(well.modulate.a, 1.0, "%s: whole" % what)


func test_the_car_tips_over_towards_the_well() -> void:
	# Its double takes its place in the same frame, as the tip starts, facing as the car stopped, on
	# the stage with the props, where the car stopped: so it sorts in front of the well. It tips on
	# its low corner on the well's side, which stays put, its top towards the well, faster and
	# faster, till it leans FRAU_HOLLE_TIP over.
	var ends := _ends()
	var tip := Tuning.FRAU_HOLLE_TIP
	for heading: Vector2 in HEADINGS:
		var what := "heading %s" % heading
		var holle := _holle(heading)
		var well := _well(holle)
		var side := _side(heading)
		var pivot := _pivot(heading)
		var there := true
		while _double(holle) == null and not _reached(ends[3]):
			there = there and _car.modulate.a == 1.0
			_step(holle)
		var car_double := _double(holle)
		if car_double == null:
			fail_test("%s: it took the car" % what)
			continue
		var into := _through(2) * Tuning.FRAU_HOLLE_BEATS[2]
		assert_between(into, -DELTA, 2.0 * DELTA, "%s: as the tip starts" % what)
		assert_true(there, "%s: the car stays where it stopped till then" % what)
		assert_eq(_car.modulate.a, 0.0, "%s: the double took the car's place" % what)
		assert_true(Disasters.shows(car_double), "%s: in the same frame" % what)
		assert_eq(car_double.get_parent(), _stage, "%s: on the stage" % what)
		assert_eq(Disasters.z(car_double), 0, "%s: with the props" % what)
		var staged: Array[Sprite2D] = [well, car_double]
		assert_eq(holle.staged(), staged, "%s: it frees what it stands up" % what)
		var faces := CarController.frame(heading)
		assert_eq(_frame_of(car_double), faces, "%s: facing as the car stopped" % what)
		var angles: Array[float] = [0.0, car_double.rotation * side]
		var steady := _snapped_near(car_double, _drawn(car_double, pivot), pivot)
		var stays := true
		var half := 0.0
		while _short_of(ends[2]):
			_step(holle)
			angles.append(car_double.rotation * side)
			steady = steady and _snapped_near(car_double, _drawn(car_double, pivot), pivot)
			stays = stays and _near(_from_car(car_double), Vector2.ZERO)
			stays = stays and car_double.scale == Vector2.ONE
			if _through(2) < 0.5 and _clear_of(2, 0.5):
				half = angles[-1]
		var middle := _drawn(car_double, FrauHolle.MIDDLE)
		assert_true(steady, "%s: on its corner on the well's side, which stays put" % what)
		assert_true(stays, "%s: where the car stopped, at its size" % what)
		assert_gt(_from_car(car_double).y, _from_car(well).y, "%s: in front of the well" % what)
		assert_eq(angles, Disasters.sorted(angles), "%s: one way" % what)
		assert_gt((middle - FrauHolle.MIDDLE).x * side, 0.0, "%s: its top towards the well" % what)
		assert_lte(_largest_step(angles), MOST_A_FRAME * tip, "%s: bit by bit" % what)
		assert_lt(half, HALF_TIPPED * tip, "%s: faster and faster" % what)
		assert_lte(angles[-1], tip, "%s: never past its lean" % what)
		assert_almost_eq(angles[-1], tip, MOST_A_FRAME * tip, "%s: till it leans over" % what)


func test_it_falls_into_the_well_turning_over_and_over() -> void:
	# From where the tip left it, its middle hops up over the rim, higher than the mouth however the
	# snap rounds it, and drops into the well's mouth by ARRIVE_SHARE of the fall, and sinks there,
	# the car turning on all the while, smaller and smaller, till it's gone. It sorts where the car
	# stopped, in front of the well, all the while.
	var ends := _ends()
	var tumble := Tuning.FRAU_HOLLE_TUMBLE
	var tip := Tuning.FRAU_HOLLE_TIP
	for heading: Vector2 in HEADINGS:
		var what := "heading %s" % heading
		var holle := _holle(heading)
		var well := _well(holle)
		var side := _side(heading)
		var mouth := FrauHolle.well(heading) + FrauHolle.MOUTH
		while _short_of(ends[2]):
			_step(holle)
		var car_double := _double(holle)
		if car_double == null:
			fail_test("%s: it took the car" % what)
			continue
		var path: Array[Vector2] = [_drawn(car_double, FrauHolle.MIDDLE)]
		var angles: Array[float] = [car_double.rotation * side]
		var sizes: Array[float] = [car_double.scale.x]
		var stays := true
		var arrived := true
		var falling := true
		# The highest that its middle can be on its way to the mouth, wherever the snap drew it.
		var highest := INF
		while _short_of(ends[3]):
			_step(holle)
			path.append(_drawn(car_double, FrauHolle.MIDDLE))
			angles.append(car_double.rotation * side)
			sizes.append(car_double.scale.x)
			stays = stays and _near(_from_car(car_double), Vector2.ZERO)
			falling = falling and Disasters.shows(car_double)
			var share := FrauHolle.ARRIVE_SHARE
			if not _clear_of(3, share):
				continue
			if _through(3) < share:
				highest = minf(highest, path[-1].y + _snap(car_double))
			else:
				arrived = arrived and _snapped_near(car_double, path[-1], mouth)
		var stride := 0.0
		for k: int in range(1, path.size()):
			stride = maxf(stride, path[k].distance_to(path[k - 1]))
		var hop := path[0].distance_to(mouth)
		assert_true(stays, "%s: it sorts where the car stopped" % what)
		assert_gt(_from_car(car_double).y, _from_car(well).y, "%s: in front of the well" % what)
		assert_lte(stride, MOST_A_FRAME * hop, "%s: it moves, it doesn't pop" % what)
		assert_lt(highest, mouth.y, "%s: it hops up over the rim" % what)
		assert_true(arrived, "%s: then drops into the mouth, where it sinks" % what)
		assert_true(falling, "%s: in sight till the end" % what)
		assert_eq(angles, Disasters.sorted(angles), "%s: turning on, one way" % what)
		assert_lte(_largest_step(angles), MOST_A_FRAME * tumble, "%s: bit by bit" % what)
		var most := tip + tumble
		assert_almost_eq(angles[-1], most, MOST_A_FRAME * tumble, "%s: over and over" % what)
		assert_eq(sizes, Disasters.sorted(sizes, true), "%s: it only shrinks" % what)
		assert_lte(_largest_step(sizes), MOST_A_FRAME, "%s: bit by bit" % what)
		var small := FrauHolle.FALLEN_SCALE
		assert_almost_eq(sizes[-1], small, MOST_A_FRAME * (1.0 - small), "%s: to a speck" % what)
		_step_to(holle, ends[3])
		assert_false(Disasters.shows(car_double), "%s: then it's gone" % what)


func test_the_snow_settles_on_the_well_which_stays() -> void:
	# Bare till the car falls, then dusted with snow, then capped with it: more and more of its
	# frame is snow. Once the legend has finished, the well stays, whole, where it rose, the snow
	# has stopped falling, and the car is gone.
	var white: Array[int] = []
	for frame: int in FrauHolle.Cap.size():
		white.append(_count(frame, "white"))
	assert_eq(white[FrauHolle.Cap.BARE], 0, "bare, it has no snow")
	assert_gt(white[FrauHolle.Cap.DUSTED], 0, "dusted, some")
	assert_gt(white[FrauHolle.Cap.CAPPED], white[FrauHolle.Cap.DUSTED], "capped, more")
	var caps: Array[int] = [FrauHolle.Cap.BARE, FrauHolle.Cap.DUSTED, FrauHolle.Cap.CAPPED]
	for heading: Vector2 in HEADINGS:
		var what := "heading %s" % heading
		var holle := _holle(heading)
		var well := _well(holle)
		var frames: Array[int] = []
		var bare := true
		watch_signals(holle)
		var end := Disasters.duration(holle, _params) - _params.delay
		while not _reached(end + 0.5):
			_step(holle)
			if Disasters.shows(well):
				frames.append(well.frame)
			if _through(3) < 0.0 and _clear_of(3, 0.0):
				bare = bare and well.frame == FrauHolle.Cap.BARE
		assert_signal_emit_count(holle, "finished", 1, "%s: it has finished" % what)
		assert_true(bare, "%s: bare till the car falls" % what)
		assert_eq(_changes(frames), caps, "%s: then dusted, then capped" % what)
		assert_true(Disasters.shows(well), "%s: the well stays" % what)
		assert_eq(well.region_rect.size.y, float(FrauHolle.WELL.y), "%s: whole" % what)
		var where := FrauHolle.well(heading)
		assert_almost_eq(_from_car(well), where, NEAR, "%s: where it rose" % what)
		assert_false(_snow(holle).emitting, "%s: the snow has stopped" % what)
		assert_eq(_car.modulate.a, 0.0, "%s: the car is gone" % what)
		var car_double := _double(holle)
		var gone := car_double == null or not Disasters.shows(car_double)
		assert_true(gone, "%s: and its double" % what)


func test_it_rises_beside_the_road_wherever_across_it_the_car_stopped() -> void:
	# A wrong turn can leave the car off its road's middle, even in the next cell across, as it
	# brakes straight on from mid-turn, as a review found. On a dead end of each heading, the car at
	# each of STOPS: the well rises beside the car, FRAU_HOLLE_SIDE_TILES up-screen of the road's
	# middle, or of the car, if it stopped further up the screen, all of its foot off the road; the
	# snow falls on them both; and the car's double, in front of the well, hops up over its rim and
	# drops into its mouth. With the car FAR_OFF_TILES to either side, off any road, the well rises
	# FRAU_HOLLE_SIDE_TILES up-screen of the car.
	var ends := _ends()
	var dead_ends := _dead_ends(_car.sim.buffer)
	assert_eq(dead_ends.size(), HEADINGS.size(), "a dead end of each heading")
	for branch: RoadTile in dead_ends:
		var heading := Vector2(Heading.VEC[branch.branch_exit])
		var down := PhantomBus.side(heading)
		for across: float in STOPS:
			var what := "heading %s, %s tiles down-screen" % [heading, across]
			var at := Iso.cell_centre(branch.cell) + down * across
			var below := across > 0.0 and absf(across) != FAR_OFF_TILES
			var from := Iso.tile_to_world(-down * across) if below else Vector2.ZERO
			var well_at := from + FrauHolle.well(heading)
			var mouth := well_at + FrauHolle.MOUTH
			_car.sim.pos = at
			_car.position = Iso.tile_to_world(at)
			var holle := _holle(heading)
			var well := _well(holle)
			_step_to(holle, ends[1])
			assert_almost_eq(_from_car(well), well_at, NEAR, "%s: where it rises" % what)
			assert_eq(_foot_on_road(well, at), 0, "%s: its foot, off the road" % what)
			_assert_snows_on_them(holle, well_at, what)
			_step_to(holle, ends[2])
			var car_double := _double(holle)
			if car_double == null:
				fail_test("%s: it took the car" % what)
				continue
			var highest := INF
			var arrived := true
			while _short_of(ends[3]):
				_step(holle)
				var share := FrauHolle.ARRIVE_SHARE
				if not _clear_of(3, share):
					continue
				var middle := _drawn(car_double, FrauHolle.MIDDLE)
				if _through(3) < share:
					highest = minf(highest, middle.y + _snap(car_double))
				else:
					arrived = arrived and _snapped_near(car_double, middle, mouth)
			assert_gt(_from_car(car_double).y, _from_car(well).y, "%s: in front of the well" % what)
			assert_lt(highest, mouth.y, "%s: it hops up over the rim" % what)
			assert_true(arrived, "%s: and drops into the mouth" % what)


func test_it_plays_in_the_light_of_the_hour_with_no_veil_and_no_glow() -> void:
	# A glow needs a veil (docs/M6.md S10): nothing of it adds light, its snow neither.
	var holle := _holle()
	assert_eq(holle.veil_kind, Legend.Veil.NONE, "no veil")
	watch_signals(holle)
	var none := true
	var frames := 0
	while get_signal_emit_count(holle, "finished") == 0 and frames < Disasters.MAX_FRAMES:
		_step(holle)
		frames += 1
		none = none and _glows(holle).is_empty()
	assert_lt(frames, Disasters.MAX_FRAMES, "it finishes")
	assert_true(none, "no glow, the car taken or not")


func test_the_well_stands_out_from_the_village_by_night() -> void:
	# Each frame of its sheet, against the Village's road and ground, in each key light
	# (POOLS_PLAN.md §5.6, V15): its stone is about as bright as they are, and its outline, its
	# mortar, its mouth, its windlass's shade and its snow show.
	var holle := _holle()
	var well := _well(holle)
	var share := Art.night_share(_sheet, well.hframes, VILLAGE, holle.veil_kind)
	var told := "%.0f%% of its least frame's pixels stand out" % (share * 100.0)
	assert_gte(share, Art.NIGHT_SHARE, told)
