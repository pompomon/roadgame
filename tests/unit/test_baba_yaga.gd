extends GutTest
## Baba Yaga's Hut, the Village's third legend (POOLS_PLAN.md §5.4). Dusk falls, and a log hut on
## chicken legs stomps along beside the road to the car, the dust flying from its feet, and stops
## up-screen of it. It turns its front to the car, squats, crouches, and its door opens on the
## dark. The car turns to the door and rolls in, smaller and smaller, and fades; the door shuts, and
## the hut rises, turns back the way it was going, and stomps off, faster and faster, and fades.
## Its chicken feet leave prints behind it, which stay.

const Disasters := preload("res://tests/helpers/disaster_fixtures.gd")
const Art := preload("res://tests/helpers/art_checks.gd")
const BABA_YAGA := preload("res://disasters/legends/baba_yaga.tscn")
const VILLAGE := preload("res://areas/village.tres")
const DELTA := 1.0 / 60.0
## How near a place must be, in px.
const NEAR := Vector2(0.001, 0.001)
## How near a share of tiles must be: Iso maps tiles to px and back in 32-bit floats.
const NEAR_TILES := 1e-4
## The most of its full alpha or size that a part may change by in a frame, and of its way that it
## may move by: it shows, shrinks, moves and fades, it doesn't pop.
const MOST_A_FRAME := 0.25
## The most that the last step of its stomp in may be, of its longest: it slows to a stop.
const SLOW_SHARE := 0.25
## How many strides it takes, at least, as it stomps in and as it stomps off.
const LEAST_STRIDES := 4
## The car's headings, as tile directions: the roads run along the tile axes.
const HEADINGS: Array[Vector2] = [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]
## How far the car may have stopped off its heading mid-turn, in radians.
const TILTS: Array[float] = [0.0, 0.6]
## How far the params' direction is turned from the car's heading, in radians: along its road,
## 1.3 rad off it, nearer the other tile axis, and the other way along it, and off it.
const TURNS: Array[float] = [0.0, 1.3, PI, PI + 1.3]
## The middle of a frame of the prints' sheet, from its top left corner.
const PRINTS_MIDDLE := Vector2i(BabaYaga.PRINTS.x >> 1, BabaYaga.PRINTS.y >> 1)
## How far its prints lie across the line that it stomps along, at most, in tiles: by turns to
## either side of it, their toes splayed.
const PRINTS_SPREAD := 0.2
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
var _hut_sheet: Image
## The opaque texels of each frame of the prints' sheet, from its middle.
var _prints_texels: Array[Array] = []


func before_all() -> void:
	var legend := BABA_YAGA.instantiate() as BabaYaga
	_hut_sheet = (legend.get_node("%Hut") as Sprite2D).texture.get_image()
	var prints_sheet := (legend.get_node("%Prints") as Sprite2D).texture.get_image()
	legend.free()
	var size := BabaYaga.PRINTS
	for frame: int in BabaYaga.STRIDES:
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


## Baba Yaga's hut, playing for the car with the car's place as its origin, as the director gives
## it, the car heading `heading`, and its params' direction turned `turn` from it, which picks the
## end of the car's road that the hut stomps in from.
func _legend(heading := Vector2.UP, turn := 0.0) -> BabaYaga:
	_car.modulate.a = 1.0
	# CarSim.forward() is (sin a, -cos a).
	_car.sim.angle = atan2(heading.x, -heading.y)
	var body := _car.get_node("%Body") as Sprite2D
	body.frame = CarController.frame(heading)
	var legend := Disasters.disaster(self, BABA_YAGA, _car, _camera) as BabaYaga
	legend.stage = _stage
	_params = Disasters.params()
	_params.origin_world = _car.global_position
	_params.direction = heading.rotated(turn)
	_frames = 0
	legend.play(_params)
	return legend


## The way that it stomps, the car heading `heading`, a tile direction, its params' direction
## turned `turn` from it: along the car's road, toward the end that the direction points to, in px
## a tile.
static func _way(heading: Vector2, turn: float) -> Vector2:
	return Iso.tile_to_world(heading if cos(turn) > 0.0 else -heading)


## When each beat ends, in seconds after the delay.
static func _ends() -> Array[float]:
	var ends: Array[float] = []
	var sum := 0.0
	for length: float in Tuning.BABA_YAGA_BEATS:
		sum += length
		ends.append(sum)
	return ends


## When `share` of `beat` is done, in seconds after the delay.
static func _at(beat: int, share: float) -> float:
	return _ends()[beat] - Tuning.BABA_YAGA_BEATS[beat] * (1.0 - share)


## Steps `legend` on to `seconds` after its delay, and a frame or two past it: a clock that sums
## frames can fall short of the sum by a hair.
func _step_to(legend: BabaYaga, seconds: float) -> void:
	var target := ceili((_params.delay + seconds) / DELTA) + 1
	simulate(legend, target - _frames, DELTA)
	_frames = target


## Steps `legend` one frame.
func _step(legend: BabaYaga) -> void:
	simulate(legend, 1, DELTA)
	_frames += 1


## Whether `legend` has stepped on to `seconds` after its delay.
func _reached(seconds: float) -> bool:
	return _frames * DELTA >= _params.delay + seconds


## How far the steps have gone through `beat`, from 0 at its start to 1 at its end.
func _through(beat: int) -> float:
	var length: float = Tuning.BABA_YAGA_BEATS[beat]
	return (_frames * DELTA - _params.delay - _at(beat, 0.0)) / length


## Whether a step from here stays half a frame short of `seconds` after the delay, so that the
## legend's clock and theirs agree that it has not got there.
func _short_of(seconds: float) -> bool:
	return (_frames + 1) * DELTA < _params.delay + seconds - DELTA / 2.0


## Whether the steps are more than a frame away from `share` of `beat`, so that the legend's clock
## and theirs agree on which side of it they are.
func _clear_of(beat: int, share: float) -> bool:
	return absf(_through(beat) - share) > DELTA / Tuning.BABA_YAGA_BEATS[beat]


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


## The texel of `frame` of the hut's sheet at `at` px from its foot.
func _texel(frame: int, at: Vector2i) -> Color:
	var foot := Vector2i(frame * BabaYaga.HUT.x + (BabaYaga.HUT.x >> 1), BabaYaga.HUT.y)
	return _hut_sheet.get_pixelv(foot + at)


## Where the prints that show lie on the ground, in tiles: as x and y, the least and the most of the
## way along `along`, a tile direction, past `stopped`, where the hut stopped, in tiles from the
## car; and as z, the most across that way from its line.
func _reach(footprints: Sprite2D, stopped: Vector2, along: Vector2) -> Vector3:
	var across := Vector2(-along.y, along.x)
	var reach := Vector3(INF, -INF, 0.0)
	for lying: Vector2 in _lying(footprints, footprints.frame):
		var on_line := lying - stopped
		reach.x = minf(reach.x, on_line.dot(along))
		reach.y = maxf(reach.y, on_line.dot(along))
		reach.z = maxf(reach.z, absf(on_line.dot(across)))
	return reach


## Where the opaque texels of `frame` of the prints' sheet lie on the ground, in tiles from the car:
## each by its middle, as the prints' place and flips show it.
func _lying(footprints: Sprite2D, frame: int) -> Array[Vector2]:
	var found: Array[Vector2] = []
	for texel: Vector2i in _prints_texels[frame]:
		var local := Vector2(texel) + Vector2(0.5, 0.5)
		if footprints.flip_h:
			local.x = -local.x
		if footprints.flip_v:
			local.y = -local.y
		found.append(Iso.world_to_tile(_from_car(footprints) + local))
	return found


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


## `values`, each once until it changes.
static func _changes(values: Array[int]) -> Array[int]:
	var found: Array[int] = []
	for value: int in values:
		if found.is_empty() or found[-1] != value:
			found.append(value)
	return found


## The pose of `poses` that is due `through` of a beat: the first, and then each from its share in
## `froms` on.
static func _due(poses: Array[int], froms: Array[float], through: float) -> int:
	var due := poses[0]
	for k: int in froms.size():
		if through >= froms[k]:
			due = poses[k + 1]
	return due


## Its legs raised in turn, `count` frames of its sheet: its near leg, then its far one.
static func _stomping(count: int) -> Array[int]:
	var found: Array[int] = []
	for k: int in count:
		found.append(BabaYaga.Pose.STOMP_A if k % 2 == 0 else BabaYaga.Pose.STOMP_B)
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


## Its standing part, which play() has put on the stage, out of reach of %names.
static func _hut(legend: BabaYaga) -> Sprite2D:
	return legend.standing[0]


static func _dust(legend: BabaYaga) -> CPUParticles2D:
	return legend.get_node("%Dust") as CPUParticles2D


static func _prints(legend: BabaYaga) -> Sprite2D:
	return legend.get_node("%Prints") as Sprite2D


## The car's double, which the legend has put on the stage once it has taken the car, or null.
static func _double(legend: BabaYaga) -> Sprite2D:
	for part: Sprite2D in legend.staged():
		if part not in legend.standing:
			return part
	return null


## The frame of the car's sheet that `car_double` shows.
static func _frame_of(car_double: Sprite2D) -> int:
	return roundi(car_double.region_rect.position.x / CarController.FRAME_SIZE.x)


## What of `legend` adds light: what it draws, what it has put on the stage, and its particles.
static func _glows(legend: BabaYaga) -> Array[CanvasItem]:
	var items := Disasters.drawables(legend)
	for emitter: CPUParticles2D in Disasters.particles(legend):
		items.append(emitter)
	var found: Array[CanvasItem] = []
	for item: CanvasItem in items:
		var material := Disasters.material_of(item) as CanvasItemMaterial
		if material != null and material.blend_mode == CanvasItemMaterial.BLEND_MODE_ADD:
			found.append(item)
	return found


## Plays the hut for the car heading `heading` turned `tilt`, its params' direction turned `turn`
## further, and checks its stomp in, as
## test_a_hut_on_chicken_legs_stomps_in_beside_the_road_and_stops_up_screen_of_it tells.
func _assert_stomps_in(heading: Vector2, tilt: float, turn: float) -> void:
	var what := "heading %s, turned %s, direction turned %s" % [heading, tilt, turn]
	var ends := _ends()
	var way := _way(heading, tilt + turn)
	var stop := BabaYaga.stop(heading)
	var from := stop - way * Tuning.BABA_YAGA_FROM_TILES
	var legend := _legend(heading.rotated(tilt), turn)
	var hut := _hut(legend)
	var dust := _dust(legend)
	assert_eq(hut.get_parent(), _stage, "%s: it stands with the props" % what)
	var path: Array[Vector2] = [from]
	var alphas: Array[float] = [0.0]
	var frames: Array[int] = []
	var hidden := true
	var placed := true
	var facing := true
	var shown := true
	var dusty := true
	var with_it := true
	while _short_of(ends[0]):
		_step(legend)
		if _through(0) < 0.0 and _clear_of(0, 0.0):
			hidden = hidden and not Disasters.shows(hut) and not dust.emitting
		if _through(0) <= 0.0 or not _clear_of(0, 0.0):
			continue
		path.append(_from_car(hut))
		alphas.append(hut.modulate.a)
		frames.append(hut.frame)
		placed = placed and Disasters.z(hut) == 0
		placed = placed and absf(_bottom(hut) - path[-1].y) < NEAR.y
		placed = placed and absf(hut.get_rect().get_center().x) < NEAR.x
		facing = facing and hut.flip_h == (way.x < 0.0)
		dusty = dusty and dust.emitting and Disasters.particles_show(dust)
		dusty = dusty and _near(_from_car(dust), path[-1])
		with_it = with_it and is_equal_approx(dust.modulate.a, hut.modulate.a)
		if _through(0) > BabaYaga.SHOW_SHARE and _clear_of(0, BabaYaga.SHOW_SHARE):
			shown = shown and hut.modulate.a == 1.0
	_step_to(legend, ends[0])
	path.append(_from_car(hut))
	var left: Array[float] = []
	for point: Vector2 in path:
		left.append(point.distance_to(stop))
	var steps := _strides(path)
	var strides := _changes(frames)
	assert_true(hidden, "%s: unseen till it stomps in" % what)
	assert_true(placed, "%s: on its foot, with the props" % what)
	assert_true(facing, "%s: facing the way it stomps" % what)
	assert_eq(alphas, Disasters.sorted(alphas), "%s: it shows as it comes" % what)
	assert_lte(_largest_step(alphas), MOST_A_FRAME, "%s: bit by bit" % what)
	assert_true(shown, "%s: all of it, from SHOW_SHARE" % what)
	assert_eq(strides, _stomping(strides.size()), "%s: stride after stride" % what)
	assert_gte(strides.size(), LEAST_STRIDES, "%s: stomping" % what)
	assert_true(_straight(path, from, stop), "%s: straight along the road" % what)
	assert_eq(left, Disasters.sorted(left, true), "%s: only nearer" % what)
	assert_eq(steps, Disasters.sorted(steps, true), "%s: slower and slower" % what)
	assert_lt(steps[-1], SLOW_SHARE * _largest(steps), "%s: to a stop" % what)
	assert_almost_eq(path[-1], stop, NEAR, "%s: where it stops" % what)
	assert_eq(hut.frame, BabaYaga.Pose.STAND, "%s: and stands" % what)
	assert_true(dusty, "%s: the dust flies from its feet" % what)
	assert_false(dust.emitting, "%s: till it stops" % what)
	assert_true(with_it, "%s: as faint as it is" % what)


func test_a_hut_on_chicken_legs_stomps_in_beside_the_road_and_stops_up_screen_of_it() -> void:
	# Each frame of its sheet stands on its bottom row. It stops beside the car, off its road's
	# middle up the screen. For each heading, the car stopped on its road or mid-turn off it, and the
	# params' direction along the car's road, off it, and the other way: from BABA_YAGA_FROM_TILES
	# back along the car's road, the end that the direction picks, straight on to where it stops,
	# slower and slower, facing the way it stomps, its legs raised in turn, showing as it comes, the
	# dust flying from its feet till it stops, as faint as it is. It stands with the props, on its
	# foot, and once it has stopped it stands.
	var half := BabaYaga.HUT.x >> 1
	for frame: int in BabaYaga.Pose.size():
		var standing := false
		for x: int in BabaYaga.HUT.x:
			standing = standing or _texel(frame, Vector2i(x - half, -1)).a > 0.0
		assert_true(standing, "frame %d: it stands on its bottom row" % frame)
	for heading: Vector2 in HEADINGS:
		var what := "heading %s" % heading
		var stop := BabaYaga.stop(heading)
		var beside := Iso.world_to_tile(stop)
		assert_almost_eq(beside.dot(heading), 0.0, NEAR_TILES, "%s: beside the car" % what)
		var off := beside.length()
		assert_almost_eq(off, Tuning.BABA_YAGA_SIDE_TILES, NEAR_TILES, "%s: off its road" % what)
		assert_gt(off, Tuning.ROAD_HALF_WIDTH, "%s: beside the road" % what)
		assert_lt(stop.y, 0.0, "%s: up the screen from it" % what)
		for tilt: float in TILTS:
			for turn: float in TURNS:
				_assert_stomps_in(heading, tilt, turn)


func test_it_turns_its_front_to_the_car_crouches_and_its_door_opens_on_the_dark() -> void:
	# Its door is dark at its sill, just up-screen of DOOR, where the car's double rolls in, only
	# once open: shut, it shows the door's leaf, or the ground between the hut's legs. For each
	# heading, where it stopped, facing as it came: it turns in profile, then three-quarters to the
	# car, then its front to it, each from its share of the turn; then it squats, crouches, and its
	# door opens on the dark, each from its share of the open.
	var ink: Color = Art.MakeArt.palette()["ink"]
	var fronts: Array[int] = [
		BabaYaga.Pose.FRONT, BabaYaga.Pose.SQUAT, BabaYaga.Pose.CROUCH, BabaYaga.Pose.OPEN
	]
	for frame: int in fronts:
		var dark := true
		for x: int in [-1, 0]:
			dark = dark and _texel(frame, Vector2i(x, -1)).is_equal_approx(ink)
		assert_eq(dark, frame == BabaYaga.Pose.OPEN, "frame %d: its door dark once open" % frame)
	var ends := _ends()
	var turning: Array[int] = [BabaYaga.Pose.STAND, BabaYaga.Pose.TURN, BabaYaga.Pose.FRONT]
	var turn_froms: Array[float] = [BabaYaga.THREE_QUARTER_FROM, BabaYaga.FRONT_FROM]
	var open_froms: Array[float] = [BabaYaga.SQUAT_FROM, BabaYaga.CROUCH_FROM, BabaYaga.OPEN_FROM]
	for heading: Vector2 in HEADINGS:
		var what := "heading %s" % heading
		var stop := BabaYaga.stop(heading)
		var legend := _legend(heading)
		var hut := _hut(legend)
		_step_to(legend, ends[0])
		var facing := hut.flip_h
		var turns: Array[int] = [hut.frame]
		var opens: Array[int] = []
		var stays := true
		var in_time := true
		while _short_of(ends[2]):
			_step(legend)
			stays = stays and _near(_from_car(hut), stop) and hut.modulate.a == 1.0
			stays = stays and hut.flip_h == facing
			if _through(1) < 1.0:
				turns.append(hut.frame)
				if _clear_of_each(1, turn_froms):
					in_time = in_time and hut.frame == _due(turning, turn_froms, _through(1))
			else:
				opens.append(hut.frame)
				if _clear_of_each(2, open_froms):
					in_time = in_time and hut.frame == _due(fronts, open_froms, _through(2))
		_step_to(legend, ends[2])
		opens.append(hut.frame)
		assert_true(stays, "%s: where it stopped, facing as it came" % what)
		assert_eq(_changes(turns), turning, "%s: it turns its front to the car" % what)
		assert_eq(_changes(opens), fronts, "%s: it squats, crouches, and its door opens" % what)
		assert_true(in_time, "%s: each from its share" % what)


func test_the_car_turns_to_the_door_and_rolls_in_smaller_and_smaller_and_fades() -> void:
	# For each heading, the car stopped on its road or mid-turn off it: the car is there till the
	# swallow. Then its double takes its place, in the same frame, where it stood, facing as it did,
	# with the props. By ROLL_SHARE of the swallow, it rolls straight to the door, DOOR from the
	# hut's foot, only nearer, bit by bit; it turns the short way to face the door, a frame at a
	# time; it shrinks to BOARDED_SCALE, bit by bit; and in its last FADE_SHARE it fades to nothing.
	# All the while, it sorts in front of the hut, whose door stays open till it has gone in.
	var ends := _ends()
	var half := CarController.FRAMES >> 1
	var boarded := Vector2.ONE * BabaYaga.BOARDED_SCALE
	var fade_from := (1.0 - BabaYaga.FADE_SHARE) * BabaYaga.ROLL_SHARE
	for heading: Vector2 in HEADINGS:
		for tilt: float in TILTS:
			var what := "heading %s, turned %s" % [heading, tilt]
			var door := BabaYaga.stop(heading) + BabaYaga.DOOR
			var first := CarController.frame(heading.rotated(tilt))
			var legend := _legend(heading.rotated(tilt))
			var hut := _hut(legend)
			var there := true
			while _short_of(ends[2]):
				_step(legend)
				there = there and _double(legend) == null and _car.modulate.a == 1.0
			assert_true(there, "%s: the car is there till the swallow" % what)
			while _double(legend) == null and not _reached(ends[3]):
				_step(legend)
			var car_double := _double(legend)
			if car_double == null:
				fail_test("%s: its double took its place" % what)
				continue
			var beat: float = Tuning.BABA_YAGA_BEATS[3]
			assert_lt(_through(3), 2.0 * DELTA / beat, "%s: as the swallow starts" % what)
			assert_eq(_car.modulate.a, 0.0, "%s: the double took the car's place" % what)
			assert_true(Disasters.shows(car_double), "%s: in the same frame" % what)
			assert_eq(_frame_of(car_double), first, "%s: facing as it did" % what)
			assert_eq(car_double.get_parent(), _stage, "%s: with the props" % what)
			assert_eq(Disasters.z(car_double), 0, "%s: sorting with them" % what)
			var staged: Array[Sprite2D] = [hut, car_double]
			assert_eq(legend.staged(), staged, "%s: it frees it" % what)
			var path: Array[Vector2] = [Vector2.ZERO, _from_car(car_double)]
			var sizes: Array[float] = [1.0, car_double.scale.x]
			var alphas: Array[float] = [1.0, car_double.modulate.a]
			var frames: Array[int] = [first, _frame_of(car_double)]
			var even := true
			var whole := true
			var in_front := true
			var open := true
			var arrived := true
			while _short_of(ends[3]):
				_step(legend)
				path.append(_from_car(car_double))
				sizes.append(car_double.scale.x)
				alphas.append(car_double.modulate.a)
				frames.append(_frame_of(car_double))
				even = even and car_double.scale.x == car_double.scale.y
				if Disasters.shows(car_double):
					in_front = in_front and car_double.global_position.y > hut.global_position.y
					open = open and hut.frame == BabaYaga.Pose.OPEN
				if _clear_of(3, fade_from) and _through(3) < fade_from:
					whole = whole and car_double.modulate.a == 1.0
				if _clear_of(3, BabaYaga.ROLL_SHARE) and _through(3) > BabaYaga.ROLL_SHARE:
					arrived = arrived and _near(_from_car(car_double), door)
					arrived = arrived and car_double.scale.is_equal_approx(boarded)
					arrived = arrived and not Disasters.shows(car_double)
			var left: Array[float] = []
			for point: Vector2 in path:
				left.append(point.distance_to(door))
			var facing_door := CarController.frame(Iso.world_to_tile(door))
			var short := posmod(facing_door - first + half, CarController.FRAMES) - half
			var turns := _changes(frames)
			var one_way := true
			for k: int in range(1, turns.size()):
				var turned := turns[k] - turns[k - 1] - signi(short)
				one_way = one_way and posmod(turned, CarController.FRAMES) == 0
			assert_true(_straight(path, Vector2.ZERO, door), "%s: it rolls to the door" % what)
			assert_eq(left, Disasters.sorted(left, true), "%s: only nearer" % what)
			var most := MOST_A_FRAME * door.length()
			assert_lte(_largest(_strides(path)), most, "%s: bit by bit" % what)
			assert_true(arrived, "%s: and by ROLL_SHARE it has gone in" % what)
			assert_eq(turns[-1], facing_door, "%s: it turns to face the door" % what)
			assert_true(one_way, "%s: a frame at a time, one way" % what)
			assert_eq(turns.size() - 1, absi(short), "%s: the short way" % what)
			assert_true(even, "%s: it keeps its shape" % what)
			assert_eq(sizes, Disasters.sorted(sizes, true), "%s: smaller and smaller" % what)
			assert_lte(_largest_step(sizes), MOST_A_FRAME, "%s: bit by bit" % what)
			assert_true(whole, "%s: all of it till its last FADE_SHARE" % what)
			assert_eq(alphas, Disasters.sorted(alphas, true), "%s: then it fades" % what)
			assert_lte(_largest_step(alphas), MOST_A_FRAME, "%s: bit by bit" % what)
			assert_true(in_front, "%s: in front of the hut" % what)
			assert_true(open, "%s: whose door stays open till it has gone in" % what)


func test_the_door_shuts_and_the_hut_rises_and_stomps_off_faster_and_faster_and_fades() -> void:
	# For each heading and each end of the car's road that the params' direction picks: where it
	# stopped, its door shuts once the car has rolled in, and the hut rises, half up and then
	# turning back the way it was going, each from its share of the swallow; from OFF_FROM it stomps
	# on along its way, straight, faster and faster, its legs raised in turn, BABA_YAGA_OFF_TILES; it
	# fades from FADE_FROM to nothing, bit by bit; and the dust flies from its feet from OFF_FROM
	# till DUST_SHARE, as faint as it is, and none of it shows once the hut has gone.
	var ends := _ends()
	var leaving: Array[int] = [
		BabaYaga.Pose.OPEN, BabaYaga.Pose.CROUCH, BabaYaga.Pose.SQUAT, BabaYaga.Pose.TURN
	]
	var froms: Array[float] = [BabaYaga.ROLL_SHARE, BabaYaga.RISE_FROM, BabaYaga.RISEN_FROM]
	for heading: Vector2 in HEADINGS:
		for turn: float in [0.0, PI]:
			var what := "heading %s, direction turned %s" % [heading, turn]
			var way := _way(heading, turn)
			var stop := BabaYaga.stop(heading)
			var off := stop + way * Tuning.BABA_YAGA_OFF_TILES
			var legend := _legend(heading, turn)
			var hut := _hut(legend)
			var dust := _dust(legend)
			_step_to(legend, ends[2])
			var path: Array[Vector2] = [_from_car(hut)]
			var alphas: Array[float] = [hut.modulate.a]
			var poses: Array[int] = []
			var strides: Array[int] = []
			var waited := true
			var in_time := true
			var facing := true
			var whole := true
			var dusty := true
			var with_it := true
			while _short_of(ends[3]):
				_step(legend)
				var through := _through(3)
				path.append(_from_car(hut))
				alphas.append(hut.modulate.a)
				facing = facing and hut.flip_h == (way.x < 0.0)
				with_it = with_it and is_equal_approx(dust.modulate.a, hut.modulate.a)
				if _clear_of(3, BabaYaga.FADE_FROM) and through < BabaYaga.FADE_FROM:
					whole = whole and hut.modulate.a == 1.0
				if not _clear_of(3, BabaYaga.OFF_FROM):
					continue
				if through < BabaYaga.OFF_FROM:
					poses.append(hut.frame)
					waited = waited and _near(path[-1], stop) and not dust.emitting
					if _clear_of_each(3, froms):
						in_time = in_time and hut.frame == _due(leaving, froms, through)
					continue
				strides.append(hut.frame)
				dusty = dusty and _near(_from_car(dust), path[-1])
				if _clear_of(3, BabaYaga.DUST_SHARE):
					var flying := through < BabaYaga.DUST_SHARE
					dusty = dusty and dust.emitting == flying
					dusty = dusty and (Disasters.particles_show(dust) or not flying)
			var steps := _strides(path)
			_step_to(legend, ends[3])
			path.append(_from_car(hut))
			alphas.append(hut.modulate.a)
			var gone: Array[float] = []
			for point: Vector2 in path:
				gone.append(point.distance_to(stop))
			var stomps := _changes(strides)
			assert_eq(_changes(poses), leaving, "%s: the door shuts, and it rises" % what)
			assert_true(in_time, "%s: each from its share" % what)
			assert_true(waited, "%s: where it stopped" % what)
			assert_true(facing, "%s: back the way it was going" % what)
			assert_true(_straight(path, stop, off), "%s: it stomps off along its way" % what)
			assert_eq(gone, Disasters.sorted(gone), "%s: only farther" % what)
			assert_eq(steps, Disasters.sorted(steps), "%s: faster and faster" % what)
			assert_almost_eq(path[-1], off, NEAR, "%s: BABA_YAGA_OFF_TILES" % what)
			assert_eq(stomps, _stomping(stomps.size()), "%s: stride after stride" % what)
			assert_gte(stomps.size(), LEAST_STRIDES, "%s: stomping" % what)
			assert_true(whole, "%s: all of it till FADE_FROM" % what)
			assert_eq(alphas, Disasters.sorted(alphas, true), "%s: then it fades" % what)
			assert_lte(_largest_step(alphas), MOST_A_FRAME, "%s: bit by bit" % what)
			assert_false(Disasters.shows(hut), "%s: to nothing" % what)
			assert_true(dusty, "%s: the dust flies from its feet till DUST_SHARE" % what)
			assert_true(with_it, "%s: as faint as it is" % what)
			assert_false(Disasters.particles_show(dust), "%s: none once it has gone" % what)


func test_its_chicken_feet_leave_prints_behind_it_which_stay() -> void:
	# Frame k of the prints' sheet shows the first k + 1 of them, more and more. For each heading
	# and each end of the car's road that the params' direction picks: none till the hut stomps
	# off; then each stride's print once the hut has passed it, between where it stopped and where
	# it is, in its share of the stretch, along the line that it stomps along, under the props. It
	# has left all of them before it is gone, and they stay.
	for k: int in range(1, BabaYaga.STRIDES):
		var more := _prints_texels[k].size() > _prints_texels[k - 1].size()
		assert_true(more, "frame %d: more prints than frame %d" % [k, k - 1])
	var ends := _ends()
	var stride := BabaYaga.STRIDE_TILES
	var all_strides := BabaYaga.STRIDES - 1
	for heading: Vector2 in HEADINGS:
		for turn: float in [0.0, PI]:
			var what := "heading %s, direction turned %s" % [heading, turn]
			var along := heading if cos(turn) > 0.0 else -heading
			var stopped := Iso.world_to_tile(BabaYaga.stop(heading))
			var legend := _legend(heading, turn)
			var hut := _hut(legend)
			var footprints := _prints(legend)
			assert_eq(footprints.get_parent(), legend, "%s: they lie under the props" % what)
			assert_eq(Disasters.z(footprints), 0, "%s: on the ground" % what)
			var unprinted := true
			var behind := true
			var in_share := true
			var left_all := -1.0
			while _short_of(ends[3]):
				_step(legend)
				if not Disasters.shows(footprints):
					continue
				unprinted = unprinted and _through(3) > BabaYaga.OFF_FROM
				var past := (Iso.world_to_tile(_from_car(hut)) - stopped).dot(along)
				var lying := _reach(footprints, stopped, along)
				behind = behind and lying.x >= -NEAR_TILES and lying.y <= past + NEAR_TILES
				in_share = in_share and lying.y <= (footprints.frame + 1) * stride + NEAR_TILES
				in_share = in_share and lying.z <= PRINTS_SPREAD
				if left_all < 0.0 and footprints.frame == all_strides:
					left_all = hut.modulate.a
			_step_to(legend, ends[3])
			var reach := _reach(footprints, stopped, along)
			assert_true(unprinted, "%s: none till it stomps off" % what)
			assert_true(behind, "%s: each stride's print once it has passed it" % what)
			assert_true(in_share, "%s: in its share of the stretch, along its line" % what)
			assert_gt(left_all, 0.0, "%s: all of them before it is gone" % what)
			assert_true(Disasters.shows(footprints), "%s: the prints stay" % what)
			assert_eq(footprints.frame, all_strides, "%s: all of them" % what)
			assert_gt(reach.y, all_strides * stride, "%s: all its strides' prints" % what)
			_step_to(legend, ends[3] + 1.0)
			assert_true(Disasters.shows(footprints), "%s: they stay after its end" % what)


func test_it_stops_beside_the_road_wherever_across_it_the_car_stopped() -> void:
	# A wrong turn can leave the car off its road's middle, even in the next cell across, as a
	# review found. On a dead end of each heading, the car at each of STOPS: the hut stops beside
	# the car, BABA_YAGA_SIDE_TILES up-screen of the road's middle, or of the car where it stopped
	# up-screen of the middle, or off any road; so off the road. The car rolls in to its door, in
	# front of it all the while, and its prints lie off the road.
	var ends := _ends()
	var dead_ends := _dead_ends(_car.sim.buffer)
	assert_eq(dead_ends.size(), HEADINGS.size(), "a dead end of each heading")
	for branch: RoadTile in dead_ends:
		var heading := Vector2(Heading.VEC[branch.branch_exit])
		var down := PhantomBus.side(heading)
		for across: float in STOPS:
			var what := "heading %s, %s tiles down-screen" % [heading, across]
			var at := Iso.cell_centre(branch.cell) + down * across
			var middle := 0.0 if absf(across) == FAR_OFF_TILES else -across
			# Down-screen of the car: up-screen of the middle, or of the car if further up-screen.
			var line := minf(middle, 0.0) - Tuning.BABA_YAGA_SIDE_TILES
			_car.sim.pos = at
			_car.position = Iso.tile_to_world(at)
			var legend := _legend(heading)
			var hut := _hut(legend)
			_step_to(legend, ends[2])
			var stopped := _from_car(hut)
			var in_front := true
			while _short_of(ends[3]):
				_step(legend)
				var car_double := _double(legend)
				if car_double != null and Disasters.shows(car_double):
					in_front = in_front and car_double.global_position.y > hut.global_position.y
			_step_to(legend, ends[3])
			var footprints := _prints(legend)
			var off_road := Disasters.shows(footprints)
			for lying: Vector2 in _lying(footprints, footprints.frame):
				off_road = off_road and not _on_road(at + lying)
			var beside := Iso.tile_to_world(down * line)
			assert_almost_eq(stopped, beside, NEAR, "%s: it stops beside the road" % what)
			assert_false(_on_road(at + Iso.world_to_tile(stopped)), "%s: off it" % what)
			assert_not_null(_double(legend), "%s: it takes the car" % what)
			assert_true(in_front, "%s: which rolls in, in front of it" % what)
			assert_true(off_road, "%s: its prints lie off the road" % what)


func test_dusk_falls_and_nothing_of_it_glows() -> void:
	# Its window is painted, not lit (POOLS_PLAN.md §5.4 Δ): nothing of it adds light, its dust
	# neither, the car taken or not. It finishes once, the car and the hut gone.
	var legend := _legend()
	assert_eq(legend.veil_kind, Legend.Veil.DUSK, "dusk falls")
	watch_signals(legend)
	var none := true
	while get_signal_emit_count(legend, "finished") == 0 and _frames < Disasters.MAX_FRAMES:
		_step(legend)
		none = none and _glows(legend).is_empty()
	assert_lt(_frames, Disasters.MAX_FRAMES, "it finishes")
	assert_true(none, "no glow, the car taken or not")
	_step_to(legend, Disasters.duration(legend, _params) - _params.delay + 0.5)
	assert_signal_emit_count(legend, "finished", 1, "once")
	assert_false(Disasters.shows(_hut(legend)), "the hut is gone")
	assert_eq(_car.modulate.a, 0.0, "and the car")


func test_the_hut_and_its_prints_stand_out_from_the_village_by_night() -> void:
	# Each frame of each sheet, against the Village's road and ground, in each key light, under its
	# dusk veil (POOLS_PLAN.md §5.6, V15).
	var legend := _legend()
	var parts: Dictionary[String, Sprite2D] = {
		"the hut": _hut(legend),
		"its prints": _prints(legend),
	}
	for what: String in parts:
		var part := parts[what]
		var image := part.texture.get_image()
		var share := Art.night_share(image, part.hframes, VILLAGE, legend.veil_kind)
		var told := "%s: %.0f%% of its least frame's pixels stand out" % [what, share * 100.0]
		assert_gte(share, Art.NIGHT_SHARE, told)
