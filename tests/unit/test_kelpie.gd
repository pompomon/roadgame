extends GutTest
## The kelpie, the Meadows' second legend (POOLS_PLAN.md §5.4). A dark pool wells up by the road
## ahead, and a black horse with weed in its mane rises out of it in a splash. It stands, dripping,
## and looks at the car, which turns off the road and rolls up to its side, as a rider mounts. It
## plunges back into the pool with the car in another splash, and the water closes over them, in
## the light of the hour. The still pool stays, and the waterweed that the splash threw onto the
## road.

const Disasters := preload("res://tests/helpers/disaster_fixtures.gd")
const Art := preload("res://tests/helpers/art_checks.gd")
const KELPIE := preload("res://disasters/legends/kelpie.tscn")
const MEADOWS := preload("res://areas/meadows.tres")
const DELTA := 1.0 / 60.0
## How near a place must be, in px.
const NEAR := Vector2(0.001, 0.001)
## How near a share of tiles must be: Iso maps tiles to px and back in 32-bit floats.
const NEAR_TILES := 1e-4
## The most of its full size the pool may grow by in a frame, and of their heights the horse and
## the car may rise or sink by: they move, they don't pop.
const MOST_A_FRAME := 0.25
## How far the car may roll in the first and the last frames of its roll, at most: a share of its
## longest stride.
const SLOW_SHARE := 0.25
## How much of the horse and the car still shows halfway through their sinking, at least: more than
## half, for they sink faster and faster.
const HALF_SHOWS := 2.0 / 3.0
## How near the ways the car sets off and ends its roll must be to the road's and to the way off it
## to the pool: the cosine of the angle between them.
const ALONG_COS := 0.999
## The car's headings, as tile directions: the roads run along the tile axes.
const HEADINGS: Array[Vector2] = [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]
## How many frames of its sheet the car may have stopped turned off its road, either way: up to
## 45°, for it straightens slowly once the player lets go (Tuning.STRAIGHTEN_RATE).
const TURNED_OFF: Array[int] = [0, -2, 2]
## How far across its dead end from the road's middle a wrong turn can leave the car, in tiles, as
## it brakes straight on from mid-turn: off the road, in the dead end's cell (OFF_ROAD_TILES), or in
## the next cell across (BESIDE_TILES), if the steering was let go mid-turn, as far as a hair short
## of that cell's middle (NEXT_MIDDLE_TILES). FAR_OFF_TILES is two cells across, off any road.
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
var _pool_sheet: Image


func before_all() -> void:
	var kelpie := KELPIE.instantiate() as Kelpie
	_sheet = (kelpie.get_node("%Horse") as Sprite2D).texture.get_image()
	_pool_sheet = (kelpie.get_node("%Pool") as Sprite2D).texture.get_image()
	kelpie.free()


func before_each() -> void:
	_stage = Disasters.stage(self)
	_car = Disasters.car(self, 0.0, _stage)
	_camera = Disasters.camera(self)


## The kelpie, playing for the car with the car's place as its origin, as the director gives it, the
## car heading `heading`, a tile direction, and showing `frame` of its sheet, or its heading's if
## below 0.
func _kelpie(heading := Vector2.UP, frame := -1) -> Kelpie:
	_car.modulate.a = 1.0
	# CarSim.forward() is (sin a, -cos a).
	_car.sim.angle = atan2(heading.x, -heading.y)
	var body := _car.get_node("%Body") as Sprite2D
	body.frame = CarController.frame(heading) if frame < 0 else frame
	var kelpie := Disasters.disaster(self, KELPIE, _car, _camera) as Kelpie
	kelpie.stage = _stage
	_params = Disasters.params()
	_params.origin_world = _car.global_position
	_frames = 0
	kelpie.play(_params)
	return kelpie


## When each beat ends, in seconds after the delay.
static func _ends() -> Array[float]:
	var ends: Array[float] = []
	var sum := 0.0
	for length: float in Tuning.KELPIE_BEATS:
		sum += length
		ends.append(sum)
	return ends


## When `share` of `beat` is done, in seconds after the delay.
static func _at(beat: int, share: float) -> float:
	return _ends()[beat] - Tuning.KELPIE_BEATS[beat] * (1.0 - share)


## Steps `kelpie` on to `seconds` after its delay, and a frame or two past it: a clock that sums
## frames can fall short of the sum by a hair.
func _step_to(kelpie: Kelpie, seconds: float) -> void:
	var target := ceili((_params.delay + seconds) / DELTA) + 1
	simulate(kelpie, target - _frames, DELTA)
	_frames = target


## Steps `kelpie` one frame.
func _step(kelpie: Kelpie) -> void:
	simulate(kelpie, 1, DELTA)
	_frames += 1


## Whether `kelpie` has stepped on to `seconds` after its delay.
func _reached(seconds: float) -> bool:
	return _frames * DELTA >= _params.delay + seconds


## How far the steps have gone through `beat`, from 0 at its start to 1 at its end.
func _through(beat: int) -> float:
	return (_frames * DELTA - _params.delay - _at(beat, 0.0)) / Tuning.KELPIE_BEATS[beat]


## Whether a step from here stays half a frame short of `seconds` after the delay, so that the
## legend's clock and theirs agree that it has not got there.
func _short_of(seconds: float) -> bool:
	return (_frames + 1) * DELTA < _params.delay + seconds - DELTA / 2.0


## Whether the steps are more than a frame away from `share` of `beat`, so that the legend's clock
## and theirs agree on which side of it they are.
func _clear_of(beat: int, share: float) -> bool:
	return absf(_through(beat) - share) > DELTA / Tuning.KELPIE_BEATS[beat]


## Where `part` is, in px from the car.
func _from_car(part: Node2D) -> Vector2:
	return part.global_position - _car.global_position


## How far down from the car the bottom edge of what shows of `sprite` is, in px: of the rect that
## it draws, which its offset, its region, its frames and its centring place.
func _bottom(sprite: Sprite2D) -> float:
	return _from_car(sprite).y + sprite.get_rect().end.y


## Whether `a` is within NEAR of `b`.
static func _near(a: Vector2, b: Vector2) -> bool:
	return absf(a.x - b.x) <= NEAR.x and absf(a.y - b.y) <= NEAR.y


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


## The horse, which play() has put on the stage, out of reach of %names.
static func _horse(kelpie: Kelpie) -> Sprite2D:
	return kelpie.standing[0]


static func _pool(kelpie: Kelpie) -> Sprite2D:
	return kelpie.get_node("%Pool") as Sprite2D


static func _weed(kelpie: Kelpie) -> Sprite2D:
	return kelpie.get_node("%Weed") as Sprite2D


static func _splash(kelpie: Kelpie) -> CPUParticles2D:
	return kelpie.get_node("%Splash") as CPUParticles2D


static func _drips(kelpie: Kelpie) -> CPUParticles2D:
	return kelpie.get_node("%Drips") as CPUParticles2D


## The car's double, which the kelpie has put on the stage once it has taken the car, or null.
static func _double(kelpie: Kelpie) -> Sprite2D:
	for part: Sprite2D in kelpie.staged():
		if part not in kelpie.standing:
			return part
	return null


## The frame of the car's sheet that `car_double` shows.
static func _frame_of(car_double: Sprite2D) -> int:
	return roundi(car_double.region_rect.position.x / CarController.FRAME_SIZE.x)


## What of `kelpie` adds light: what it draws, what it has put on the stage, and its particles.
static func _glows(kelpie: Kelpie) -> Array[CanvasItem]:
	var items := Disasters.drawables(kelpie)
	for emitter: CPUParticles2D in Disasters.particles(kelpie):
		items.append(emitter)
	var found: Array[CanvasItem] = []
	for item: CanvasItem in items:
		var material := Disasters.material_of(item) as CanvasItemMaterial
		if material != null and material.blend_mode == CanvasItemMaterial.BLEND_MODE_ADD:
			found.append(item)
	return found


## The horse's eyes in `frame` of its sheet, from its foot: its white texels over its bottom row,
## where the foam at its legs is white too.
func _eyes(frame: int) -> Array[Vector2i]:
	var white: Color = Art.MakeArt.palette()["white"]
	var half := Kelpie.HORSE.x >> 1
	var foot := Vector2i(frame * Kelpie.HORSE.x + half, Kelpie.HORSE.y)
	var found: Array[Vector2i] = []
	for y: int in range(-Kelpie.HORSE.y, -1):
		for x: int in range(-half, half):
			if _sheet.get_pixelv(foot + Vector2i(x, y)).is_equal_approx(white):
				found.append(Vector2i(x, y))
	return found


## Which way `horse` faces on the screen: the x of its eye from its foot, right of it if above 0, as
## its frame and flip show it. 0 if its frame hasn't one eye.
func _facing(horse: Sprite2D) -> float:
	var eyes := _eyes(horse.frame)
	var x := float(eyes[0].x) if eyes.size() == 1 else 0.0
	return -x if horse.flip_h else x


## The lowest row of `frame` of the car's sheet `sheet` with an opaque texel, or -1.
static func _lowest_row(sheet: Image, frame: int) -> int:
	for row: int in range(CarController.FRAME_SIZE.y - 1, -1, -1):
		for x: int in CarController.FRAME_SIZE.x:
			if sheet.get_pixel(frame * CarController.FRAME_SIZE.x + x, row).a > 0.0:
				return row
	return -1


## The first tile of the first dead end of each heading in `buffer`, of those with no road in the
## two cells to either side of it, across its road.
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


## How many of the opaque texels of `water`'s still pool lie on the road of the car's buffer, each
## by its middle, the car's ground point being `at`, in tiles.
func _pool_on_road(water: Sprite2D, at: Vector2) -> int:
	var half := Vector2(Kelpie.POOL) / 2.0
	var count := 0
	for y: int in Kelpie.POOL.y:
		for x: int in Kelpie.POOL.x:
			if _pool_sheet.get_pixel(x, y).a == 0.0:
				continue
			var local := (Vector2(x, y) + Vector2(0.5, 0.5) - half) * water.scale
			if _on_road(at + Iso.world_to_tile(_from_car(water) + local)):
				count += 1
	return count


func test_a_dark_pool_wells_up_by_the_road_ahead_and_a_black_horse_rises_out_of_it() -> void:
	# Ahead along the car's road, and off it up the screen, for each heading. The pool wells up to
	# its full size, under the props; then the horse rises out of it in a splash, bit by bit,
	# standing in it with the props, as a ring spreads from where it stands.
	for frame: int in Kelpie.Pose.size():
		var wet := false
		for x: int in Kelpie.HORSE.x:
			wet = wet or _sheet.get_pixel(frame * Kelpie.HORSE.x + x, Kelpie.HORSE.y - 1).a > 0.0
		assert_true(wet, "frame %d: it stands in the water, on its bottom row" % frame)
	var ends := _ends()
	var splash_to := Kelpie.POOL_SHARE + Kelpie.SPLASH_SHARE * (1.0 - Kelpie.POOL_SHARE)
	var ring: Array[int] = [0, 1, 2, 3, 0]
	for heading: Vector2 in HEADINGS:
		var what := "heading %s" % heading
		var pool := Kelpie.pool(heading)
		var off_road := Iso.world_to_tile(pool) - heading * Tuning.KELPIE_AHEAD_TILES
		assert_almost_eq(off_road.dot(heading), 0.0, NEAR_TILES, "%s: beside the road" % what)
		var off := off_road.length()
		assert_almost_eq(off, Tuning.KELPIE_SIDE_TILES, NEAR_TILES, "%s: off it" % what)
		assert_lt(Iso.tile_to_world(off_road).y, 0.0, "%s: up the screen from it" % what)
		var kelpie := _kelpie(heading)
		var horse := _horse(kelpie)
		var water := _pool(kelpie)
		var splash := _splash(kelpie)
		var stand := pool + Kelpie.STAND
		assert_eq(water.get_parent(), kelpie, "%s: the pool lies under the props" % what)
		assert_eq(horse.get_parent(), _stage, "%s: the horse stands with them" % what)
		var sizes: Array[float] = [0.0]
		var heights: Array[float] = [0.0]
		var rings: Array[int] = [water.frame]
		var lying := true
		var welling := true
		var splashes := true
		var splashed := false
		var standing := true
		while _short_of(ends[0]):
			_step(kelpie)
			lying = lying and _near(_from_car(water), pool)
			sizes.append(water.scale.x)
			rings.append(water.frame)
			var welled := _through(0) > Kelpie.POOL_SHARE
			if _clear_of(0, Kelpie.POOL_SHARE):
				welling = welling and Disasters.shows(horse) == welled
				if _clear_of(0, splash_to):
					splashes = splashes and splash.emitting == (welled and _through(0) < splash_to)
			splashed = splashed or splash.emitting
			if not Disasters.shows(horse):
				continue
			heights.append(horse.region_rect.size.y)
			standing = standing and horse.frame == Kelpie.Pose.RISING
			standing = standing and _near(_from_car(horse), stand) and Disasters.z(horse) == 0
			standing = standing and absf(_bottom(horse) - stand.y) < NEAR.y
			var left := _from_car(horse).x + horse.get_rect().position.x
			standing = standing and is_equal_approx(left, stand.x - Kelpie.HORSE.x / 2.0)
		_step_to(kelpie, ends[0])
		rings.append(water.frame)
		heights.append(horse.region_rect.size.y)
		assert_true(lying, "%s: the pool lies there" % what)
		assert_eq(sizes, Disasters.sorted(sizes), "%s: it only grows" % what)
		assert_lte(_largest_step(sizes), MOST_A_FRAME, "%s: it wells up" % what)
		assert_eq(water.scale, Vector2.ONE, "%s: to its full size" % what)
		assert_true(welling, "%s: then the horse rises out of it" % what)
		assert_true(splashes and splashed, "%s: in a splash" % what)
		assert_true(_near(_from_car(splash), stand), "%s: at its feet" % what)
		assert_true(standing, "%s: standing in it, with the props" % what)
		assert_eq(heights, Disasters.sorted(heights), "%s: only up" % what)
		var most := MOST_A_FRAME * Kelpie.HORSE.y
		assert_lte(_largest_step(heights), most, "%s: bit by bit" % what)
		assert_eq(heights[-1], float(Kelpie.HORSE.y), "%s: all of it" % what)
		assert_eq(horse.modulate.a, 1.0, "%s: whole" % what)
		assert_eq(_changes(rings), ring, "%s: a ring spreads from it" % what)


func test_it_stands_dripping_and_looks_at_the_car() -> void:
	# Whole, its head lowered and turned to the car, on whichever side of the road its pool lies.
	# Water drips from its belly only as it waits. The car stays where it stopped till then.
	for frame: int in Kelpie.Pose.size():
		var eyes := _eyes(frame)
		assert_eq(eyes.size(), 1, "frame %d: an eye" % frame)
		if eyes.size() == 1:
			assert_gt(eyes[0].x, 0, "frame %d: it faces the screen's right in its sheet" % frame)
	var high := _eyes(Kelpie.Pose.RISING)
	var low := _eyes(Kelpie.Pose.WAITING)
	if high.size() == 1 and low.size() == 1:
		assert_gt(low[0].y, high[0].y, "its head lowered as it waits")
	var ends := _ends()
	for heading: Vector2 in HEADINGS:
		var what := "heading %s" % heading
		var kelpie := _kelpie(heading)
		var horse := _horse(kelpie)
		var drips := _drips(kelpie)
		var stand := Kelpie.pool(heading) + Kelpie.STAND
		var waiting := true
		var looking := true
		var dripping := true
		var dripped := false
		var there := true
		while _short_of(ends[2]):
			_step(kelpie)
			var waits := _through(1) > 0.0 and _through(1) < 1.0
			if _clear_of(1, 0.0) and _clear_of(1, 1.0):
				dripping = dripping and drips.emitting == waits
				if waits:
					waiting = waiting and horse.frame == Kelpie.Pose.WAITING
					waiting = waiting and horse.region_rect.size.y == Kelpie.HORSE.y
					waiting = waiting and horse.modulate.a == 1.0
					looking = looking and _facing(horse) * stand.x < 0.0
				if _through(1) < 1.0:
					there = there and _double(kelpie) == null and _car.modulate.a == 1.0
			dripped = dripped or drips.emitting
		assert_true(waiting, "%s: it stands, whole, its head lowered" % what)
		assert_true(looking, "%s: and looks at the car" % what)
		assert_true(dripping and dripped, "%s: dripping only as it waits" % what)
		assert_true(_near(_from_car(drips), stand + Kelpie.DRIPS), "%s: from its belly" % what)
		assert_true(there, "%s: the car stays where it stopped till then" % what)


func test_the_car_turns_off_the_road_and_rolls_up_to_its_side_as_a_rider_mounts() -> void:
	# Its double takes its place in the same frame, as the mount starts. It sets off along the road
	# and turns off it for the pool, slow at each end, turning a frame at a time from the frame the
	# car stopped in, however the car had turned, toward the way it rolls and never past it, to face
	# that way at the end. It ends by the horse's side, in front of it, on the stage with the props.
	var ends := _ends()
	for heading: Vector2 in HEADINGS:
		var beside := Kelpie.beside(heading)
		var mount := Kelpie.pool(heading) + Kelpie.MOUNT
		var faces := CarController.frame(Iso.world_to_tile(mount - beside))
		for off: int in TURNED_OFF:
			var what := "heading %s, %d frames off it" % [heading, off]
			var first := posmod(CarController.frame(heading) + off, CarController.FRAMES)
			var kelpie := _kelpie(heading, first)
			var horse := _horse(kelpie)
			while _double(kelpie) == null and not _reached(ends[3]):
				_step(kelpie)
			var car_double := _double(kelpie)
			if car_double == null:
				fail_test("%s: it took the car" % what)
				continue
			var into := _through(2) * Tuning.KELPIE_BEATS[2]
			assert_between(into, -DELTA, 2.0 * DELTA, "%s: as the mount starts" % what)
			assert_eq(_car.modulate.a, 0.0, "%s: the double took the car's place" % what)
			assert_true(Disasters.shows(car_double), "%s: in the same frame" % what)
			assert_eq(car_double.get_parent(), _stage, "%s: on the stage" % what)
			assert_eq(Disasters.z(car_double), 0, "%s: with the props" % what)
			var staged: Array[Sprite2D] = [horse, car_double]
			assert_eq(kelpie.staged(), staged, "%s: it frees what it stands up" % what)
			var path: Array[Vector2] = [Vector2.ZERO, _from_car(car_double)]
			var frames: Array[int] = [_frame_of(car_double)]
			while _short_of(ends[2]):
				_step(kelpie)
				path.append(_from_car(car_double))
				frames.append(_frame_of(car_double))
			_step_to(kelpie, ends[2])
			path.append(_from_car(car_double))
			frames.append(_frame_of(car_double))
			var strides: Array[float] = []
			var ways: Array[Vector2] = []
			for k: int in range(1, path.size()):
				var stride := path[k] - path[k - 1]
				if stride != Vector2.ZERO:
					strides.append(stride.length())
					ways.append(stride.normalized())
			if strides.size() < 3:
				fail_test("%s: it rolls" % what)
				continue
			var longest: float = strides.max()
			assert_lt(strides[0], SLOW_SHARE * longest, "%s: it sets off slowly" % what)
			assert_lt(strides[-1], SLOW_SHARE * longest, "%s: and stops slowly" % what)
			var along := ways[0].dot(beside.normalized())
			assert_gt(along, ALONG_COS, "%s: along the road" % what)
			var turned := ways[-1].dot((mount - beside).normalized())
			assert_gt(turned, ALONG_COS, "%s: turning off it for the pool" % what)
			assert_almost_eq(path[-1], mount, NEAR, "%s: to the horse's side" % what)
			assert_gt(path[-1].y, _from_car(horse).y, "%s: in front of it" % what)
			assert_eq(frames[0], first, "%s: facing as the car stopped" % what)
			# At each step, how far clockwise it has turned from the frame it stopped in, and how
			# far from that frame the way it rolls is, each summed step by step so that neither
			# wraps round. It faces between the two, give or take half a frame: its frames round.
			var step := TAU / CarController.FRAMES
			var faced := 0.0
			var rolls := 0.0
			var last := first * step
			var turning := true
			var toward := true
			for k: int in range(1, frames.size()):
				var turn := posmod(frames[k] - frames[k - 1] + 1, CarController.FRAMES) - 1
				turning = turning and absi(turn) <= 1
				faced += turn * step
				var way := path[k + 1] - path[k]
				if way == Vector2.ZERO:
					continue
				var angle := atan2(way.x, -way.y)
				rolls += angle_difference(last, angle)
				last = angle
				var low := minf(rolls, 0.0) - step / 2.0
				toward = toward and faced >= low and faced <= maxf(rolls, 0.0) + step / 2.0
			assert_true(turning, "%s: it turns a frame at a time" % what)
			assert_true(toward, "%s: toward the way it rolls, never past it" % what)
			assert_eq(frames[-1], faces, "%s: to face the way it rolls" % what)


func test_it_plunges_back_into_the_pool_with_the_car_and_the_water_closes_over_them() -> void:
	# Head first, in a splash: the horse and the car sink in their places, faster and faster, each
	# showing less of itself over the water till nothing does, as two rings spread from it, one
	# after the other. Then the water is still.
	var body := _car.get_node("%Body") as Sprite2D
	var depth := CarController.FOOT.y + Kelpie.WATERLINE
	var lowest := -1
	for frame: int in CarController.FRAMES:
		lowest = maxi(lowest, _lowest_row(body.texture.get_image(), frame))
	assert_lt(lowest, depth, "the car shows whole down to its water line till it sinks")
	var ends := _ends()
	var halfway := Kelpie.SINK_SHARE / 2.0
	var splash_to := Kelpie.PLUNGE_SPLASH_SHARE
	var two_rings: Array[int] = [0, 1, 2, 3, 1, 2, 3, 0]
	for heading: Vector2 in HEADINGS:
		var what := "heading %s" % heading
		var kelpie := _kelpie(heading)
		var horse := _horse(kelpie)
		var water := _pool(kelpie)
		var splash := _splash(kelpie)
		var stand := Kelpie.pool(heading) + Kelpie.STAND
		var mount := Kelpie.pool(heading) + Kelpie.MOUNT
		while _short_of(ends[2]):
			_step(kelpie)
		var car_double := _double(kelpie)
		if car_double == null:
			fail_test("%s: it took the car" % what)
			continue
		var horses: Array[float] = [float(Kelpie.HORSE.y)]
		var cars: Array[float] = [car_double.region_rect.size.y]
		var rings: Array[int] = [water.frame]
		var plunging := true
		var sinking := true
		var splashes := true
		var splashed := false
		# How much of each shows halfway through their sinking.
		var horse_half := 0.0
		var car_half := 0.0
		while _short_of(ends[3]):
			_step(kelpie)
			rings.append(water.frame)
			var through := _through(3)
			if _clear_of(3, splash_to):
				splashes = splashes and splash.emitting == (through > 0.0 and through < splash_to)
			splashed = splashed or (through > 0.0 and splash.emitting)
			if through <= 0.0 or not _clear_of(3, 0.0):
				continue
			horses.append(horse.region_rect.size.y if Disasters.shows(horse) else 0.0)
			cars.append(car_double.region_rect.size.y if Disasters.shows(car_double) else 0.0)
			if through < halfway and _clear_of(3, halfway):
				horse_half = horses[-1]
				car_half = cars[-1]
			if Disasters.shows(horse):
				plunging = plunging and horse.frame == Kelpie.Pose.PLUNGING
				plunging = plunging and _near(_from_car(horse), stand)
				plunging = plunging and absf(_bottom(horse) - stand.y) < NEAR.y
			if Disasters.shows(car_double):
				sinking = sinking and _near(_from_car(car_double), mount)
				var line := mount.y + Kelpie.WATERLINE
				sinking = sinking and absf(_bottom(car_double) - line) < NEAR.y
		_step_to(kelpie, ends[3])
		rings.append(water.frame)
		horses.append(horse.region_rect.size.y if Disasters.shows(horse) else 0.0)
		cars.append(car_double.region_rect.size.y if Disasters.shows(car_double) else 0.0)
		assert_true(plunging, "%s: it plunges head first, in its place" % what)
		assert_true(sinking, "%s: the car sinks in its place, under its water line" % what)
		assert_true(splashes and splashed, "%s: in a splash" % what)
		assert_eq(horses, Disasters.sorted(horses, true), "%s: the horse only sinks" % what)
		assert_eq(cars, Disasters.sorted(cars, true), "%s: and the car" % what)
		var most := MOST_A_FRAME * Kelpie.HORSE.y
		assert_lte(_largest_step(horses), most, "%s: the horse, bit by bit" % what)
		assert_lte(_largest_step(cars), MOST_A_FRAME * depth, "%s: and the car" % what)
		var faster := "%s: the horse, faster and faster" % what
		assert_gt(horse_half, HALF_SHOWS * Kelpie.HORSE.y, faster)
		assert_gt(car_half, HALF_SHOWS * depth, "%s: and the car" % what)
		assert_false(Disasters.shows(horse), "%s: the water closes over the horse" % what)
		assert_false(Disasters.shows(car_double), "%s: and the car" % what)
		assert_eq(_changes(rings), two_rings, "%s: two rings spread, and the water is still" % what)
		assert_false(splash.emitting, "%s: the splash is over" % what)


func test_the_still_pool_stays_and_the_weed_the_splash_threw_onto_the_road() -> void:
	# What it leaves still shows once it has finished (docs/M6.md N31): the pool where it lay, its
	# water still, and the weed on the road beside it, which shows only as the splash throws it.
	for heading: Vector2 in HEADINGS:
		var what := "heading %s" % heading
		var kelpie := _kelpie(heading)
		var water := _pool(kelpie)
		var weed := _weed(kelpie)
		var alphas: Array[float] = []
		var thrown := true
		watch_signals(kelpie)
		var end := Disasters.duration(kelpie, _params) - _params.delay
		while not _reached(end + 0.5):
			_step(kelpie)
			alphas.append(weed.modulate.a)
			if _through(3) < Kelpie.WEED_FROM and _clear_of(3, Kelpie.WEED_FROM):
				thrown = thrown and weed.modulate.a == 0.0
		assert_signal_emit_count(kelpie, "finished", 1, "%s: it has finished" % what)
		assert_true(thrown, "%s: no weed till the splash throws it" % what)
		assert_eq(alphas, Disasters.sorted(alphas), "%s: then it only shows more" % what)
		assert_true(Disasters.shows(water), "%s: the pool stays" % what)
		assert_eq(water.scale, Vector2.ONE, "%s: whole" % what)
		assert_eq(water.frame, 0, "%s: its water still" % what)
		assert_almost_eq(_from_car(water), Kelpie.pool(heading), NEAR, "%s: where it lay" % what)
		assert_true(Disasters.shows(weed), "%s: the weed stays" % what)
		assert_eq(weed.modulate.a, 1.0, "%s: in full" % what)
		var on_road := Iso.world_to_tile(_from_car(weed))
		var ahead := heading * Tuning.KELPIE_AHEAD_TILES
		var near := Vector2.ONE * NEAR_TILES
		assert_almost_eq(on_road, ahead, near, "%s: on the road beside it" % what)
		assert_eq(water.get_parent(), kelpie, "%s: the pool, flat, under the props" % what)
		assert_eq(weed.get_parent(), kelpie, "%s: and the weed" % what)
		assert_false(Disasters.shows(_horse(kelpie)), "%s: the horse is gone" % what)
		assert_false(_splash(kelpie).emitting, "%s: the water has settled" % what)
		assert_false(_drips(kelpie).emitting, "%s: and dripped" % what)
		assert_eq(_car.modulate.a, 0.0, "%s: the car is gone" % what)


func test_it_lies_by_the_road_ahead_wherever_across_it_the_car_stopped() -> void:
	# A wrong turn can leave the car off its road's middle, even in the next cell across, as it
	# brakes straight on from mid-turn, as a review found. On a dead end of each heading, the car
	# at each of STOPS: the pool lies by the road ahead, KELPIE_SIDE_TILES up-screen of its middle,
	# all of it off the road; the car rolls up to the horse's side; and the weed lies on the road's
	# middle beside the pool. With the car FAR_OFF_TILES to either side, off any road, they lie by
	# the car's line.
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
			var middle := Iso.tile_to_world(-down * across) if on_road else Vector2.ZERO
			_car.sim.pos = at
			_car.position = Iso.tile_to_world(at)
			var kelpie := _kelpie(heading)
			_step_to(kelpie, ends[2])
			var car_double := _double(kelpie)
			if car_double == null:
				fail_test("%s: it took the car" % what)
				continue
			var mount := middle + Kelpie.pool(heading) + Kelpie.MOUNT
			assert_almost_eq(_from_car(car_double), mount, NEAR, "%s: to the horse's side" % what)
			_step_to(kelpie, ends[3])
			var water := _pool(kelpie)
			var weed := _weed(kelpie)
			var by := middle + Kelpie.pool(heading)
			assert_almost_eq(_from_car(water), by, NEAR, "%s: the pool lies by the road" % what)
			var beside := middle + Kelpie.beside(heading)
			assert_almost_eq(_from_car(weed), beside, NEAR, "%s: the weed beside it" % what)
			if on_road:
				assert_eq(_pool_on_road(water, at), 0, "%s: the pool, off the road" % what)
				var lying := at + Iso.world_to_tile(_from_car(weed))
				assert_true(_on_road(lying), "%s: the weed, on it" % what)


func test_it_plays_in_the_light_of_the_hour_with_no_veil_and_no_glow() -> void:
	# A glow needs a veil (docs/M6.md S10): nothing of it adds light, its splash and drips neither.
	var kelpie := _kelpie()
	assert_eq(kelpie.veil_kind, Legend.Veil.NONE, "no veil")
	watch_signals(kelpie)
	var none := true
	var frames := 0
	while get_signal_emit_count(kelpie, "finished") == 0 and frames < Disasters.MAX_FRAMES:
		_step(kelpie)
		frames += 1
		none = none and _glows(kelpie).is_empty()
	assert_lt(frames, Disasters.MAX_FRAMES, "it finishes")
	assert_true(none, "no glow, the car taken or not")


func test_the_horse_its_pool_and_the_weed_stand_out_from_the_meadows_by_night() -> void:
	# Each frame of each sheet, against the Meadows' road and ground, in each key light
	# (POOLS_PLAN.md §5.6, V15): the horse is black, and its pool dark.
	var kelpie := _kelpie()
	var parts: Dictionary[String, Sprite2D] = {
		"the horse": _horse(kelpie),
		"its pool": _pool(kelpie),
		"the weed": _weed(kelpie),
	}
	for what: String in parts:
		var part := parts[what]
		var image := part.texture.get_image()
		var share := Art.night_share(image, part.hframes, MEADOWS, kelpie.veil_kind)
		var told := "%s: %.0f%% of its least frame's pixels stand out" % [what, share * 100.0]
		assert_gte(share, Art.NIGHT_SHARE, told)
