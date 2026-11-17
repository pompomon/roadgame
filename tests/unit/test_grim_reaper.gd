extends GutTest
## The Grim Reaper, the City's third legend (docs/POOLS.md §5.4). Dusk falls, and a hooded figure
## with a scythe steps out at the roadside ahead and beckons the car with one bony hand. The road
## opens into a grave in front of the car, and the car rolls forward into it and sinks, as the earth
## falls in on it. A gravestone rises at the grave's head, and the Reaper fades away. Its scythe
## never swings at the car (docs/M6.md Q8).

const Disasters := preload("res://tests/helpers/disaster_fixtures.gd")
const Art := preload("res://tests/helpers/art_checks.gd")
const GRIM_REAPER := preload("res://disasters/legends/grim_reaper.tscn")
const CITY := preload("res://areas/city.tres")
const DELTA := 1.0 / 60.0
## How near a place must be, in px.
const NEAR := Vector2(0.001, 0.001)
## How near a share of tiles must be: Iso maps tiles to px and back in 32-bit floats.
const NEAR_TILES := 1e-4
## The most of its full height, its way or its alpha that a part may change by in a frame: they
## move, they don't pop.
const MOST_A_FRAME := 0.25
## The most that the first and the last steps of a move may be, of its longest: it starts or stops
## slowly.
const SLOW_SHARE := 0.25
## How much of the double must still show halfway through its sinking, at least: it sinks faster
## and faster.
const HALF_SHOWS := 2.0 / 3.0
## How near the way that the earth is thrown must be to the way to the grave's middle: the cosine
## of the angle between them.
const ALONG_COS := 0.999
## How many px of the pit's depths may show above where the earth falls in, at most: it falls in
## just past the foot of the pit's far wall. Up the screen from there, the far wall, the rim and
## then the heap show.
const WALL_FOOT := 3
## The car's headings, as tile directions: the roads run along the tile axes.
const HEADINGS: Array[Vector2] = [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]
## How far the car may have stopped turned off its road, either way, in degrees in tile space: up
## to nearly 45°, past which its road is the other tile axis, for it straightens slowly once the
## player lets go (Tuning.STRAIGHTEN_RATE).
const TURNED_OFF: Array[float] = [0.0, -44.0, 44.0]
## The palette's colours that the scythe is drawn in, and nothing else of the Reaper: its shaft,
## its blade and the blade's edge.
const SCYTHE: Array[String] = ["plank", "asphalt light", "white"]
## The middle of a frame of the grave's sheet, from its top left corner.
const GRAVE_MIDDLE := Vector2i(GrimReaper.GRAVE.x >> 1, GrimReaper.GRAVE.y >> 1)

var _stage: Node2D
var _car: CarController
var _camera: CameraRig
var _params: DisasterParams
## Physics frames stepped since play().
var _frames := 0
var _reaper_sheet: Image
var _grave_sheet: Image
var _stone_sheet: Image
## The texels of the scythe in each frame of the Reaper's sheet, from its foot.
var _scythes: Array[Array] = []


func before_all() -> void:
	var legend := GRIM_REAPER.instantiate() as GrimReaper
	_reaper_sheet = (legend.get_node("%Reaper") as Sprite2D).texture.get_image()
	_grave_sheet = (legend.get_node("%Grave") as Sprite2D).texture.get_image()
	_stone_sheet = (legend.get_node("%Stone") as Sprite2D).texture.get_image()
	legend.free()
	var palette := Art.MakeArt.palette()
	var paints: Array[Color] = []
	for paint: String in SCYTHE:
		paints.append(palette[paint])
	for frame: int in GrimReaper.Pose.size():
		_scythes.append(_reaper_texels(frame, paints))


func before_each() -> void:
	_stage = Disasters.stage(self)
	_car = Disasters.car(self, 0.0, _stage)
	_camera = Disasters.camera(self)


## The Grim Reaper, playing for the car with the car's place as its origin, as the director gives
## it, the car heading `heading`, a tile direction, turned `turned` radians clockwise off it.
func _legend(heading := Vector2.UP, turned := 0.0) -> GrimReaper:
	_car.modulate.a = 1.0
	# CarSim.forward() is (sin a, -cos a).
	_car.sim.angle = atan2(heading.x, -heading.y) + turned
	var body := _car.get_node("%Body") as Sprite2D
	body.frame = CarController.frame(_car.sim.forward())
	var legend := Disasters.disaster(self, GRIM_REAPER, _car, _camera) as GrimReaper
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
	for length: float in Tuning.GRIM_REAPER_BEATS:
		sum += length
		ends.append(sum)
	return ends


## When `share` of `beat` is done, in seconds after the delay.
static func _at(beat: int, share: float) -> float:
	return _ends()[beat] - Tuning.GRIM_REAPER_BEATS[beat] * (1.0 - share)


## Steps `legend` on to `seconds` after its delay, and a frame or two past it: a clock that sums
## frames can fall short of the sum by a hair.
func _step_to(legend: GrimReaper, seconds: float) -> void:
	var target := ceili((_params.delay + seconds) / DELTA) + 1
	simulate(legend, target - _frames, DELTA)
	_frames = target


## Steps `legend` one frame.
func _step(legend: GrimReaper) -> void:
	simulate(legend, 1, DELTA)
	_frames += 1


## Whether `legend` has stepped on to `seconds` after its delay.
func _reached(seconds: float) -> bool:
	return _frames * DELTA >= _params.delay + seconds


## How far the steps have gone through `beat`, from 0 at its start to 1 at its end.
func _through(beat: int) -> float:
	return (_frames * DELTA - _params.delay - _at(beat, 0.0)) / Tuning.GRIM_REAPER_BEATS[beat]


## Whether a step from here stays half a frame short of `seconds` after the delay, so that the
## legend's clock and theirs agree that it has not got there.
func _short_of(seconds: float) -> bool:
	return (_frames + 1) * DELTA < _params.delay + seconds - DELTA / 2.0


## Whether the steps are more than a frame away from `share` of `beat`, so that the legend's clock
## and theirs agree on which side of it they are.
func _clear_of(beat: int, share: float) -> bool:
	return absf(_through(beat) - share) > DELTA / Tuning.GRIM_REAPER_BEATS[beat]


## Whether the steps are inside `beat`, more than a frame from its start and its end.
func _inside(beat: int) -> bool:
	var through := _through(beat)
	return through > 0.0 and through < 1.0 and _clear_of(beat, 0.0) and _clear_of(beat, 1.0)


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


## Its standing parts, which play() has put on the stage, out of reach of %names: the Reaper, then
## its gravestone.
static func _reaper(legend: GrimReaper) -> Sprite2D:
	return legend.standing[0]


static func _stone(legend: GrimReaper) -> Sprite2D:
	return legend.standing[1]


static func _grave(legend: GrimReaper) -> Sprite2D:
	return legend.get_node("%Grave") as Sprite2D


static func _earth(legend: GrimReaper) -> CPUParticles2D:
	return legend.get_node("%Earth") as CPUParticles2D


## The car's double, which the legend has put on the stage once it has taken the car, or null.
static func _double(legend: GrimReaper) -> Sprite2D:
	for part: Sprite2D in legend.staged():
		if part not in legend.standing:
			return part
	return null


## The frame of the car's sheet that `car_double` shows.
static func _frame_of(car_double: Sprite2D) -> int:
	return roundi(car_double.region_rect.position.x / CarController.FRAME_SIZE.x)


## Whether `frames`, which the car's double shows step by step, turn a frame at a time toward `way`,
## in px, and never past it: how far they have turned, summed so that it doesn't wrap round, stays
## between none and how far `way` is from the first, give or take half a frame, for frames round.
static func _turns_toward(frames: Array[int], way: Vector2) -> bool:
	var step := TAU / CarController.FRAMES
	var off := angle_difference(frames[0] * step, atan2(way.x, -way.y))
	var faced := 0.0
	for k: int in range(1, frames.size()):
		var turn := posmod(frames[k] - frames[k - 1] + 1, CarController.FRAMES) - 1
		if absi(turn) > 1:
			return false
		faced += turn * step
		if faced < minf(off, 0.0) - step / 2.0 or faced > maxf(off, 0.0) + step / 2.0:
			return false
	return true


## The lowest row of `frame` of the car's sheet `sheet` with an opaque texel, or -1.
static func _lowest_row(sheet: Image, frame: int) -> int:
	for row: int in range(CarController.FRAME_SIZE.y - 1, -1, -1):
		for x: int in CarController.FRAME_SIZE.x:
			if sheet.get_pixel(frame * CarController.FRAME_SIZE.x + x, row).a > 0.0:
				return row
	return -1


## Whether `texel` is one of `paints`.
static func _one_of(texel: Color, paints: Array[Color]) -> bool:
	for paint: Color in paints:
		if texel.a > 0.0 and texel.is_equal_approx(paint):
			return true
	return false


## The texels of `frame` of the Reaper's sheet in one of `paints`, or every opaque one if `paints`
## is empty, from its foot.
func _reaper_texels(frame: int, paints: Array[Color]) -> Array[Vector2i]:
	var size := GrimReaper.REAPER
	var found: Array[Vector2i] = []
	for y: int in size.y:
		for x: int in size.x:
			var texel := _reaper_sheet.get_pixel(frame * size.x + x, y)
			if _one_of(texel, paints) or (paints.is_empty() and texel.a > 0.0):
				found.append(Vector2i(x - (size.x >> 1), y - size.y))
	return found


## The texels in which frames `a` and `b` of the Reaper's sheet differ, from its foot: where either
## shows. The import bleeds the colours of what shows into the clear texels round it, across the
## frames' edges too, so what a clear texel holds doesn't count.
func _differences(a: int, b: int) -> Array[Vector2i]:
	var size := GrimReaper.REAPER
	var found: Array[Vector2i] = []
	for y: int in size.y:
		for x: int in size.x:
			var one := _reaper_sheet.get_pixel(a * size.x + x, y)
			var other := _reaper_sheet.get_pixel(b * size.x + x, y)
			if (one.a > 0.0 or other.a > 0.0) and not one.is_equal_approx(other):
				found.append(Vector2i(x - (size.x >> 1), y - size.y))
	return found


## Whether the scythe of `legend`'s Reaper, as its frame and its flip show it, lies wholly on the
## side of its foot away from each of the car, its double and the grave that shows, or the Reaper
## doesn't show (docs/M6.md Q8).
func _scythe_away(legend: GrimReaper) -> bool:
	var reaper := _reaper(legend)
	if not Disasters.shows(reaper):
		return true
	var least := INF
	var most := -INF
	for texel: Vector2i in _scythes[reaper.frame]:
		# A texel spans x to x + 1 from the foot, and mirrored, -x - 1 to -x.
		var left := float(-texel.x - 1) if reaper.flip_h else float(texel.x)
		least = minf(least, left)
		most = maxf(most, left + 1.0)
	# -1 for the screen's left, 1 for its right, and 0 if it reaches over the foot.
	var side := -1.0 if most <= 0.0 else (1.0 if least >= 0.0 else 0.0)
	for target: Node2D in [_car, _grave(legend), _double(legend)]:
		if target != null and Disasters.shows(target):
			if side * (target.global_position.x - reaper.global_position.x) >= 0.0:
				return false
	return true


## The texel of `frame` of the grave's sheet at `at` from its middle.
func _grave_texel(frame: int, at: Vector2i) -> Color:
	var middle := Vector2i(frame * GrimReaper.GRAVE.x, 0) + GRAVE_MIDDLE
	return _grave_sheet.get_pixelv(middle + at)


## The texels of `frame` of the grave's sheet in the palette's `paint`, from its middle.
func _grave_texels(frame: int, paint: String) -> Array[Vector2i]:
	var color: Color = Art.MakeArt.palette()[paint]
	var size := GrimReaper.GRAVE
	var found: Array[Vector2i] = []
	for y: int in size.y:
		for x: int in size.x:
			if _grave_sheet.get_pixel(frame * size.x + x, y).is_equal_approx(color):
				found.append(Vector2i(x, y) - GRAVE_MIDDLE)
	return found


## The texels of the open grave's pit, from its middle: the dark texels that its middle reaches
## without crossing others. The outline round the rim and the heap is just as dark.
func _pit() -> Array[Vector2i]:
	var ink: Color = Art.MakeArt.palette()["ink"]
	var bounds := Rect2i(-GRAVE_MIDDLE, GrimReaper.GRAVE)
	var seen: Dictionary[Vector2i, bool] = {}
	var found: Array[Vector2i] = []
	var todo: Array[Vector2i] = [Vector2i.ZERO]
	while not todo.is_empty():
		var at: Vector2i = todo.pop_back()
		if seen.has(at) or not bounds.has_point(at):
			continue
		seen[at] = true
		if not _grave_texel(GrimReaper.Dug.OPEN, at).is_equal_approx(ink):
			continue
		found.append(at)
		for way: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			todo.append(at + way)
	return found


## Where the middle of `texel` of the grave's sheet, from its middle, lies on the ground, in tiles
## from the car, as `grave`'s place and flip show it.
func _on_ground(grave: Sprite2D, texel: Vector2i) -> Vector2:
	var local := Vector2(texel) + Vector2(0.5, 0.5)
	if grave.flip_h:
		local.x = -local.x
	return Iso.world_to_tile(_from_car(grave) + local)


## The texel of `frame` of the grave's sheet that shows at `point`, in px from the car, as `grave`'s
## place and flip show it.
func _grave_under(grave: Sprite2D, frame: int, point: Vector2) -> Color:
	return _grave_texel(frame, _texel_under(grave, point))


## Which texel of the grave's sheet, from its middle, shows at `point`, in px from the car, as
## `grave`'s place and flip show it.
func _texel_under(grave: Sprite2D, point: Vector2) -> Vector2i:
	var local := point - _from_car(grave)
	if grave.flip_h:
		local.x = -local.x
	return Vector2i(floori(local.x), floori(local.y))


## What shows straight up the screen from `texel` of the open grave's sheet, from its middle, to
## the sheet's top, a letter a px: "p" over the pit, `pit`; "e" in the heap's browns, as its far
## walls are; "r" in the rim's grey; and "o" anything else.
func _up_from(texel: Vector2i, pit: Dictionary[Vector2i, bool]) -> String:
	var palette := Art.MakeArt.palette()
	var earth: Array[Color] = [palette["rural dark"], palette["rural dirt"]]
	var column := ""
	for y: int in range(texel.y, -GRAVE_MIDDLE.y - 1, -1):
		var at := Vector2i(texel.x, y)
		var color := _grave_texel(GrimReaper.Dug.OPEN, at)
		if pit.has(at):
			column += "p"
		elif _one_of(color, earth):
			column += "e"
		elif color.is_equal_approx(palette["asphalt light"]):
			column += "r"
		else:
			column += "o"
	return column


## `column`, each run of a letter as one.
static func _runs(column: String) -> String:
	var runs := ""
	for letter: String in column:
		if not runs.ends_with(letter):
			runs += letter
	return runs


## The paths of the earth's clods, as CPUParticles2D moves them, a frame at a time, adding its
## gravity to a clod's speed and then its speed to its place: from where it is thrown till it is
## gone, in px from the car. The slowest, at the least intensity, and the fastest, at the most,
## along the middle and both edges of its spread, from each corner of where it may be thrown.
func _clods(earth: CPUParticles2D) -> Array[Array]:
	var reach := Vector2.ZERO
	match earth.emission_shape:
		CPUParticles2D.EMISSION_SHAPE_RECTANGLE:
			reach = earth.emission_rect_extents
		CPUParticles2D.EMISSION_SHAPE_SPHERE, CPUParticles2D.EMISSION_SHAPE_SPHERE_SURFACE:
			reach = Vector2.ONE * earth.emission_sphere_radius
	var slowest := earth.initial_velocity_min / _params.intensity * Tuning.DISASTER_INTENSITY_MIN
	var fastest := earth.initial_velocity_max / _params.intensity * Tuning.DISASTER_INTENSITY_MAX
	var step := DELTA * earth.speed_scale
	var paths: Array[Array] = []
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		for speed: float in [slowest, fastest]:
			for angle: float in [-earth.spread, 0.0, earth.spread]:
				var velocity := earth.direction.normalized().rotated(deg_to_rad(angle)) * speed
				var point := _from_car(earth) + corner * reach
				var path: Array[Vector2] = []
				for frame: int in ceili(earth.lifetime / step) + 1:
					if frame > 0:
						velocity += earth.gravity * step
					point += velocity * step
					path.append(point)
				paths.append(path)
	return paths


## What of `legend` adds light: what it draws, what it has put on the stage, and its particles.
static func _glows(legend: GrimReaper) -> Array[CanvasItem]:
	var items := Disasters.drawables(legend)
	for emitter: CPUParticles2D in Disasters.particles(legend):
		items.append(emitter)
	var found: Array[CanvasItem] = []
	for item: CanvasItem in items:
		var material := Disasters.material_of(item) as CanvasItemMaterial
		if material != null and material.blend_mode == CanvasItemMaterial.BLEND_MODE_ADD:
			found.append(item)
	return found


func test_a_hooded_figure_with_a_scythe_steps_out_at_the_roadside_ahead() -> void:
	# Beside where the grave will open, off the car's road up the screen, with the props, for each
	# heading: from farther off the road, a step on each foot in turn, straight to its place, slower
	# and slower to a stop, showing as it comes. Each frame of its sheet stands on its bottom row.
	for frame: int in GrimReaper.Pose.size():
		var standing := false
		for texel: Vector2i in _reaper_texels(frame, []):
			standing = standing or texel.y == -1
		assert_true(standing, "frame %d: it stands on its bottom row" % frame)
	var ends := _ends()
	var strides: Array[int] = [
		GrimReaper.Pose.STEP_A,
		GrimReaper.Pose.STEP_B,
		GrimReaper.Pose.STEP_A,
		GrimReaper.Pose.STEP_B,
	]
	for heading: Vector2 in HEADINGS:
		var what := "heading %s" % heading
		var stand := GrimReaper.stand(heading)
		var from := GrimReaper.step_from(heading)
		var ahead := heading * Tuning.GRIM_REAPER_AHEAD_TILES
		var off_road := Iso.world_to_tile(stand) - ahead
		var farther := Iso.world_to_tile(from) - ahead
		var side := Tuning.GRIM_REAPER_SIDE_TILES
		var more := side + Tuning.GRIM_REAPER_STEP_TILES
		assert_almost_eq(off_road.dot(heading), 0.0, NEAR_TILES, "%s: beside the grave" % what)
		assert_almost_eq(off_road.length(), side, NEAR_TILES, "%s: off its road" % what)
		assert_gt(off_road.length(), Tuning.ROAD_HALF_WIDTH, "%s: at the roadside" % what)
		assert_lt(Iso.tile_to_world(off_road).y, 0.0, "%s: up the screen" % what)
		assert_almost_eq(farther.dot(heading), 0.0, NEAR_TILES, "%s: it steps across" % what)
		assert_almost_eq(farther.length(), more, NEAR_TILES, "%s: from farther off" % what)
		assert_gt(farther.dot(off_road), 0.0, "%s: on the same side" % what)
		var legend := _legend(heading)
		var reaper := _reaper(legend)
		assert_eq(reaper.get_parent(), _stage, "%s: it stands with the props" % what)
		var path: Array[Vector2] = [from]
		var alphas: Array[float] = [0.0]
		var frames: Array[int] = []
		var hidden := true
		var placed := true
		var shown := true
		while _short_of(ends[0]):
			_step(legend)
			if _through(0) < 0.0 and _clear_of(0, 0.0):
				hidden = hidden and not Disasters.shows(reaper)
			if _through(0) <= 0.0 or not _clear_of(0, 0.0):
				continue
			path.append(_from_car(reaper))
			alphas.append(reaper.modulate.a)
			if Disasters.shows(reaper):
				frames.append(reaper.frame)
			placed = placed and Disasters.z(reaper) == 0
			placed = placed and absf(_bottom(reaper) - path[-1].y) < NEAR.y
			placed = placed and absf(reaper.get_rect().get_center().x) < NEAR.x
			if _through(0) > GrimReaper.SHOW_SHARE and _clear_of(0, GrimReaper.SHOW_SHARE):
				shown = shown and reaper.modulate.a == 1.0
		_step_to(legend, ends[0])
		path.append(_from_car(reaper))
		var left: Array[float] = []
		for point: Vector2 in path:
			left.append(point.distance_to(stand))
		var steps := _strides(path)
		assert_true(hidden, "%s: unseen till it steps out" % what)
		assert_true(placed, "%s: on its foot, with the props" % what)
		assert_eq(alphas, Disasters.sorted(alphas), "%s: it shows as it comes" % what)
		assert_lte(_largest_step(alphas), MOST_A_FRAME, "%s: bit by bit" % what)
		assert_true(shown, "%s: all of it, from halfway" % what)
		assert_eq(_changes(frames), strides, "%s: a step on each foot in turn" % what)
		assert_true(_straight(path, from, stand), "%s: straight to its place" % what)
		assert_eq(left, Disasters.sorted(left, true), "%s: only nearer" % what)
		assert_eq(steps, Disasters.sorted(steps, true), "%s: slower and slower" % what)
		assert_lt(steps[-1], SLOW_SHARE * _largest(steps), "%s: to a stop" % what)
		assert_almost_eq(path[-1], stand, NEAR, "%s: at its place" % what)
		assert_eq(reaper.modulate.a, 1.0, "%s: in full" % what)


func test_it_beckons_with_one_bony_hand_its_scythe_held_still_away_from_the_car() -> void:
	# Its scythe is the same texels in every frame of its sheet, on its foot's left as drawn, and only
	# its other hand beckons: held out past its robe, its fingers curl in and out. It beckons twice
	# in its place, then holds its hand out as the road opens. In every frame, its scythe shows on
	# the side away from the car, its double and the grave (docs/M6.md Q8).
	var scythe: Array = _scythes[0]
	var held := not scythe.is_empty()
	for frame: int in GrimReaper.Pose.size():
		held = held and _scythes[frame] == scythe
	var left := true
	for texel: Vector2i in scythe:
		left = left and texel.x < 0
	assert_true(held, "its scythe is the same in every frame")
	assert_true(left, "on its left as drawn")
	var robe := -GrimReaper.REAPER.x
	for texel: Vector2i in _reaper_texels(GrimReaper.Pose.STAND, []):
		robe = maxi(robe, texel.x)
	var hand := _differences(GrimReaper.Pose.STAND, GrimReaper.Pose.BECKON)
	var one := not hand.is_empty()
	for texel: Vector2i in hand:
		one = one and texel.x > 0
	var fingers := _differences(GrimReaper.Pose.BECKON, GrimReaper.Pose.CURL)
	var out := not fingers.is_empty()
	for texel: Vector2i in fingers:
		out = out and texel.x > robe
	assert_true(one, "it beckons with its other hand")
	assert_true(out, "its fingers curl, held out past its robe")
	var beckons: Array[int] = [
		GrimReaper.Pose.BECKON,
		GrimReaper.Pose.CURL,
		GrimReaper.Pose.BECKON,
		GrimReaper.Pose.CURL,
		GrimReaper.Pose.BECKON,
	]
	for heading: Vector2 in HEADINGS:
		var what := "heading %s" % heading
		var stand := GrimReaper.stand(heading)
		var legend := _legend(heading)
		var reaper := _reaper(legend)
		var frames: Array[int] = []
		var still := true
		var away := true
		watch_signals(legend)
		while get_signal_emit_count(legend, "finished") == 0 and _frames < Disasters.MAX_FRAMES:
			_step(legend)
			away = away and _scythe_away(legend)
			if not Disasters.shows(reaper):
				continue
			if _inside(1) or _inside(2):
				frames.append(reaper.frame)
				still = still and _near(_from_car(reaper), stand)
		assert_signal_emit_count(legend, "finished", 1, "%s: it has finished" % what)
		assert_eq(_changes(frames), beckons, "%s: it beckons twice, then holds out its hand" % what)
		assert_true(still, "%s: in its place" % what)
		assert_true(away, "%s: its scythe away from the car, its double and the grave" % what)


func test_the_road_opens_into_a_grave_in_front_of_the_car() -> void:
	# Ahead along the car's road, flat under the props, as the Reaper holds out its hand: the road
	# cracks, then the grave is ajar, then open, darker each time. Its pit lies along the road, on
	# it, ahead of the car, as long and as wide as the grave.
	var inks: Array[int] = []
	for frame: int in [GrimReaper.Dug.CRACKED, GrimReaper.Dug.AJAR, GrimReaper.Dug.OPEN]:
		inks.append(_grave_texels(frame, "ink").size())
	assert_lt(inks[0], inks[1], "ajar, darker than cracked")
	assert_lt(inks[1], inks[2], "open, darker still")
	var ink: Color = Art.MakeArt.palette()["ink"]
	var deep := _grave_texel(GrimReaper.Dug.OPEN, Vector2i.ZERO)
	assert_true(deep.is_equal_approx(ink), "open, its middle is dark")
	var pit := _pit()
	var ends := _ends()
	var dug: Array[int] = [GrimReaper.Dug.CRACKED, GrimReaper.Dug.AJAR, GrimReaper.Dug.OPEN]
	var half := GrimReaper.GRAVE_TILES / 2.0 + Vector2.ONE * NEAR_TILES
	var near := Vector2.ONE * NEAR_TILES
	for heading: Vector2 in HEADINGS:
		var what := "heading %s" % heading
		var at := GrimReaper.grave(heading)
		var ahead := heading * Tuning.GRIM_REAPER_AHEAD_TILES
		assert_almost_eq(Iso.world_to_tile(at), ahead, near, "%s: ahead along its road" % what)
		var legend := _legend(heading)
		var grave := _grave(legend)
		assert_eq(grave.get_parent(), legend, "%s: flat, under the props" % what)
		var frames: Array[int] = []
		var hidden := true
		var there := true
		while _short_of(ends[2]):
			_step(legend)
			if _through(2) < 0.0 and _clear_of(2, 0.0):
				hidden = hidden and not Disasters.shows(grave)
			if Disasters.shows(grave):
				frames.append(grave.frame)
				there = there and _near(_from_car(grave), at)
		var across := PhantomBus.side(heading)
		var inside := true
		var on_road := true
		# Along the road and across it, in tiles from the car.
		var span := Rect2()
		for k: int in pit.size():
			var ground := _on_ground(grave, pit[k])
			var spot := Vector2(ground.dot(heading), ground.dot(across))
			span = Rect2(spot, Vector2.ZERO) if k == 0 else span.expand(spot)
			inside = inside and absf(spot.x - Tuning.GRIM_REAPER_AHEAD_TILES) <= half.x
			inside = inside and absf(spot.y) <= half.y
			on_road = on_road and spot.x > 0.0 and absf(spot.y) <= Tuning.ROAD_HALF_WIDTH
		assert_true(hidden, "%s: unseen till the Reaper has beckoned" % what)
		assert_eq(_changes(frames), dug, "%s: cracked, then ajar, then open" % what)
		assert_true(there, "%s: there" % what)
		assert_gt(span.size.x, span.size.y, "%s: its pit along the road" % what)
		assert_true(inside, "%s: no longer and no wider than the grave" % what)
		assert_true(on_road, "%s: on the road, ahead of the car" % what)


func test_the_car_rolls_forward_into_the_grave_however_it_had_turned() -> void:
	# Its double takes its place in the same frame, as the last beat starts, facing as the car
	# stopped, on the stage with the props. It rolls straight ahead into the grave's middle, slowly
	# at first and at the last, whole: each frame of the car ends above the grave's near lip. However
	# the car had turned off its road, as a review found, it turns toward the way it rolls, never
	# past it, to face it at the end, so it doesn't slide sideways.
	var sheet := (_car.get_node("%Body") as Sprite2D).texture.get_image()
	var lowest := -1
	for frame: int in CarController.FRAMES:
		lowest = maxi(lowest, _lowest_row(sheet, frame))
	var depth := CarController.FOOT.y + GrimReaper.LIP
	assert_lt(lowest, depth, "the car shows whole down to the grave's lip till it sinks")
	var ends := _ends()
	for heading: Vector2 in HEADINGS:
		var at := GrimReaper.grave(heading)
		for turned: float in TURNED_OFF:
			var what := "heading %s, turned %s° off it" % [heading, turned]
			var legend := _legend(heading, deg_to_rad(turned))
			var first := CarController.frame(_car.sim.forward())
			var there := true
			while _double(legend) == null and not _reached(ends[3]):
				there = there and _car.modulate.a == 1.0
				_step(legend)
			var car_double := _double(legend)
			if car_double == null:
				fail_test("%s: it took the car" % what)
				continue
			var into := _through(3) * Tuning.GRIM_REAPER_BEATS[3]
			assert_between(into, -DELTA, 2.0 * DELTA, "%s: as the last beat starts" % what)
			assert_true(there, "%s: the car stays where it stopped till then" % what)
			assert_eq(_car.modulate.a, 0.0, "%s: the double took the car's place" % what)
			assert_true(Disasters.shows(car_double), "%s: in the same frame" % what)
			assert_eq(car_double.get_parent(), _stage, "%s: on the stage" % what)
			assert_eq(Disasters.z(car_double), 0, "%s: with the props" % what)
			var staged: Array[Sprite2D] = [_reaper(legend), _stone(legend), car_double]
			assert_eq(legend.staged(), staged, "%s: it frees what it stands up" % what)
			var frames: Array[int] = [_frame_of(car_double)]
			assert_eq(frames[0], first, "%s: facing as the car stopped" % what)
			var path: Array[Vector2] = [Vector2.ZERO, _from_car(car_double)]
			var whole := true
			while _short_of(_at(3, GrimReaper.ROLL_SHARE)):
				_step(legend)
				path.append(_from_car(car_double))
				frames.append(_frame_of(car_double))
				whole = whole and Disasters.shows(car_double)
				whole = whole and car_double.offset == -Vector2(CarController.FOOT)
				whole = whole and car_double.region_rect.size.y > lowest
			_step_to(legend, _at(3, GrimReaper.ROLL_SHARE))
			path.append(_from_car(car_double))
			frames.append(_frame_of(car_double))
			var gone: Array[float] = []
			for point: Vector2 in path:
				gone.append(point.length())
			var steps := _strides(path)
			if steps.is_empty():
				fail_test("%s: it rolled" % what)
				continue
			var longest := _largest(steps)
			assert_true(_straight(path, Vector2.ZERO, at), "%s: straight ahead" % what)
			assert_eq(gone, Disasters.sorted(gone), "%s: forward only" % what)
			assert_lte(gone[-1], at.length() + NEAR.x, "%s: never past the grave's middle" % what)
			assert_lt(steps[0], SLOW_SHARE * longest, "%s: slowly at first" % what)
			assert_lt(steps[-1], SLOW_SHARE * longest, "%s: and at the last" % what)
			assert_lte(longest, MOST_A_FRAME * at.length(), "%s: bit by bit" % what)
			assert_true(whole, "%s: whole" % what)
			assert_almost_eq(path[-1], at, NEAR, "%s: into the grave's middle" % what)
			assert_true(_turns_toward(frames, at), "%s: turning toward the way it rolls" % what)
			assert_eq(frames[-1], CarController.frame(heading), "%s: to face that way" % what)


func test_it_sinks_as_the_earth_falls_in_on_it() -> void:
	# In the grave's middle, faster and faster, less and less of it showing, and none of it over the
	# road in front of the pit: its top rows show, cut off at the pit's near lip, which is dark
	# wherever the car is. The earth is thrown in on it from the foot of the pit's far wall, under
	# the heap, in front of it, from as it stops till it has sunk out of sight. Then the grave is
	# filled. Its clods are the heap's browns, so each stays over the pit's dark depths from where
	# it's thrown till it's gone, however fast it's thrown: the far wall and the heap would hide it.
	# Those still falling as the grave fills go with the earth: they would fall on over the mound,
	# which is in their browns too.
	var ink: Color = Art.MakeArt.palette()["ink"]
	var lip := true
	for x: int in range(-CarController.FOOT.x, CarController.FRAME_SIZE.x - CarController.FOOT.x):
		var texel := _grave_texel(GrimReaper.Dug.OPEN, Vector2i(x, GrimReaper.LIP - 1))
		lip = lip and texel.is_equal_approx(ink)
	assert_true(lip, "the pit's near lip is dark across the car")
	var pit: Dictionary[Vector2i, bool] = {}
	for texel: Vector2i in _pit():
		pit[texel] = true
	var ends := _ends()
	var depth := float(CarController.FOOT.y + GrimReaper.LIP)
	var rolled := GrimReaper.ROLL_SHARE
	var sunk := GrimReaper.SUNK_AT
	var halfway := (rolled + sunk) / 2.0
	for heading: Vector2 in HEADINGS:
		var what := "heading %s" % heading
		var at := GrimReaper.grave(heading)
		var legend := _legend(heading)
		var grave := _grave(legend)
		var earth := _earth(legend)
		var kept: Array[float] = [depth]
		var sinking := true
		var open := true
		var gone := true
		var falls := true
		var fell := false
		var buried := true
		# How much of the double shows halfway through its sinking.
		var half_kept := 0.0
		while _short_of(ends[3]):
			_step(legend)
			var through := _through(3)
			if _clear_of(3, rolled) and _clear_of(3, sunk):
				var falling := through > rolled and through < sunk
				falls = falls and earth.emitting == falling
				falls = falls and (Disasters.shows(earth) or not falling)
			fell = fell or earth.emitting
			if through <= 0.0 or not _clear_of(3, 0.0) or not _clear_of(3, sunk):
				continue
			var dug := GrimReaper.Dug.FILLED if through > sunk else GrimReaper.Dug.OPEN
			open = open and grave.frame == dug
			if through > sunk:
				buried = buried and not Disasters.shows(earth)
			var car_double := _double(legend)
			if car_double == null or through < rolled or not _clear_of(3, rolled):
				continue
			var shows := Disasters.shows(car_double)
			kept.append(car_double.region_rect.size.y if shows else 0.0)
			if through < halfway and _clear_of(3, halfway):
				half_kept = kept[-1]
			if through > sunk:
				gone = gone and not shows
			elif shows:
				sinking = sinking and _near(_from_car(car_double), at)
				sinking = sinking and car_double.region_rect.position.y == 0.0
				sinking = sinking and absf(_bottom(car_double) - at.y - GrimReaper.LIP) < NEAR.y
		_step_to(legend, ends[3])
		buried = buried and not Disasters.shows(earth)
		var last := _double(legend)
		kept.append(last.region_rect.size.y if last != null and Disasters.shows(last) else 0.0)
		assert_true(sinking, "%s: in the grave's middle, its top cut off at the near lip" % what)
		assert_eq(kept, Disasters.sorted(kept, true), "%s: less and less of it shows" % what)
		assert_lte(_largest_step(kept), MOST_A_FRAME * depth, "%s: bit by bit" % what)
		assert_gt(half_kept, HALF_SHOWS * depth, "%s: faster and faster" % what)
		assert_eq(kept[-1], 0.0, "%s: till none of it does" % what)
		assert_true(gone, "%s: out of sight once the grave is filled" % what)
		assert_true(open, "%s: the grave open till then, then filled" % what)
		assert_true(falls and fell, "%s: the earth falls in as it sinks" % what)
		assert_true(buried, "%s: the earth gone once the grave is filled" % what)
		assert_gt(Disasters.z(earth), 0, "%s: in front of it" % what)
		var place := _from_car(earth)
		var column := _up_from(_texel_under(grave, place), pit)
		var foot := _runs(column).begins_with("pere") and column.find("e") - 1 <= WALL_FOOT
		assert_true(foot, "%s: from the foot of the far wall, under the heap: %s" % [what, column])
		var way := earth.direction.normalized().dot((at - place).normalized())
		assert_gt(way, ALONG_COS, "%s: thrown towards its middle" % what)
		assert_gt(earth.gravity.y, 0.0, "%s: falling" % what)
		var over := true
		for path: Array in _clods(earth):
			for point: Vector2 in path:
				over = over and pit.has(_texel_under(grave, point))
		assert_true(over, "%s: each clod over the pit till it's gone" % what)


func test_a_gravestone_rises_at_its_head_and_the_reaper_fades_away() -> void:
	# At the grave's head, the end of its pit up the screen, along the car's road, with the props:
	# out of the ground as the car sinks, its top first, bit by bit, only up, till it stands whole,
	# on its bottom row. The Reaper lowers its hand, and once the car has sunk a while, fades away.
	# Neither starts while the car rolls into the grave whole. Once it has finished, the grave,
	# filled in, and its gravestone stay where they were, and the car is gone.
	var standing := false
	for x: int in GrimReaper.STONE.x:
		standing = standing or _stone_sheet.get_pixel(x, GrimReaper.STONE.y - 1).a > 0.0
	assert_true(standing, "the stone stands on its bottom row")
	var ink: Color = Art.MakeArt.palette()["ink"]
	var filled := _grave_texel(GrimReaper.Dug.FILLED, Vector2i.ZERO)
	assert_false(filled.is_equal_approx(ink), "filled, its middle is no longer dark")
	var out := GrimReaper.GRAVE_TILES.x / 2.0 + GrimReaper.STONE_OUT
	for heading: Vector2 in HEADINGS:
		var what := "heading %s" % heading
		var at := GrimReaper.grave(heading)
		var head := GrimReaper.head(heading)
		var past := Iso.world_to_tile(head - at)
		var across := PhantomBus.side(heading)
		assert_almost_eq(past.dot(across), 0.0, NEAR_TILES, "%s: along the road" % what)
		assert_almost_eq(past.length(), out, NEAR_TILES, "%s: past the end of the pit" % what)
		assert_lt(head.y, at.y, "%s: up the screen" % what)
		var legend := _legend(heading)
		var stone := _stone(legend)
		var reaper := _reaper(legend)
		var grave := _grave(legend)
		assert_eq(stone.get_parent(), _stage, "%s: it stands with the props" % what)
		var heights: Array[float] = [0.0]
		var alphas: Array[float] = []
		var hidden := true
		var rising := true
		var lowered := true
		var stays := true
		var rolling := 0
		watch_signals(legend)
		var end := Disasters.duration(legend, _params) - _params.delay
		while not _reached(end + 0.5):
			_step(legend)
			var through := _through(3)
			if through < GrimReaper.STONE_FROM and _clear_of(3, GrimReaper.STONE_FROM):
				hidden = hidden and not Disasters.shows(stone)
			if Disasters.shows(stone):
				heights.append(stone.region_rect.size.y)
				rising = rising and Disasters.z(stone) == 0 and _near(_from_car(stone), head)
				rising = rising and stone.region_rect.position.y == 0.0
				rising = rising and absf(_bottom(stone) - head.y) < NEAR.y
				var left := _from_car(stone).x + stone.get_rect().position.x
				rising = rising and absf(left - (head.x - GrimReaper.STONE.x / 2.0)) < NEAR.x
			if through <= 0.0 or not _clear_of(3, 0.0):
				continue
			lowered = lowered and reaper.frame == GrimReaper.Pose.STAND
			alphas.append(reaper.modulate.a)
			if through < GrimReaper.FADE_FROM and _clear_of(3, GrimReaper.FADE_FROM):
				stays = stays and reaper.modulate.a == 1.0
			# While the car's double rolls in whole, before it has sunk at all.
			var taken := _double(legend)
			if taken != null and taken.offset == -Vector2(CarController.FOOT):
				rolling += 1
				hidden = hidden and not Disasters.shows(stone)
				stays = stays and reaper.modulate.a == 1.0
		assert_signal_emit_count(legend, "finished", 1, "%s: it has finished" % what)
		assert_gt(rolling, 0, "%s: the car rolls in whole before it sinks" % what)
		assert_true(hidden, "%s: unseen till the car has sunk a while" % what)
		assert_true(rising, "%s: there, its top first, on its foot, with the props" % what)
		assert_eq(heights, Disasters.sorted(heights), "%s: only up" % what)
		var most := MOST_A_FRAME * GrimReaper.STONE.y
		assert_lte(_largest_step(heights), most, "%s: bit by bit" % what)
		assert_eq(heights[-1], float(GrimReaper.STONE.y), "%s: whole" % what)
		assert_true(Disasters.shows(stone), "%s: the gravestone stays" % what)
		assert_true(lowered, "%s: the Reaper lowers its hand" % what)
		assert_true(stays, "%s: and stays a while" % what)
		assert_eq(alphas, Disasters.sorted(alphas, true), "%s: then fades" % what)
		assert_lte(_largest_step(alphas), MOST_A_FRAME, "%s: bit by bit" % what)
		assert_false(Disasters.shows(reaper), "%s: away" % what)
		assert_true(Disasters.shows(grave), "%s: the grave stays" % what)
		assert_eq(grave.frame, GrimReaper.Dug.FILLED, "%s: filled in" % what)
		assert_almost_eq(_from_car(grave), at, NEAR, "%s: where it opened" % what)
		assert_false(_earth(legend).emitting, "%s: the earth has settled" % what)
		assert_eq(_car.modulate.a, 0.0, "%s: the car is gone" % what)
		var car_double := _double(legend)
		var buried := car_double == null or not Disasters.shows(car_double)
		assert_true(buried, "%s: and its double" % what)


func test_it_opens_on_the_road_wherever_across_it_the_car_stopped() -> void:
	# A wrong turn can leave the car off its road's middle, even in the next cell across, as a
	# review found. On a dead end of each heading, the car at each of STOPS: the grave opens on the
	# road's middle ahead, all of its pit on the road, with its gravestone and its earth. The Reaper
	# stands GRIM_REAPER_SIDE_TILES up-screen of the road's middle, or of the car if it stopped
	# further up the screen, its scythe away from the car, its double and the grave. The double
	# rolls straight into the grave, turning to face the way it rolls. With the car FAR_OFF_TILES to
	# either side, off any road, they lie by the car's line.
	var pit := _pit()
	var dead_ends := Disasters.dead_ends(_car.sim.buffer)
	assert_eq(dead_ends.size(), HEADINGS.size(), "a dead end of each heading")
	for branch: RoadTile in dead_ends:
		var heading := Vector2(Heading.VEC[branch.branch_exit])
		var down := PhantomBus.side(heading)
		for across: float in Disasters.STOPS:
			var what := "heading %s, %s tiles down-screen" % [heading, across]
			var at := Iso.cell_centre(branch.cell) + down * across
			var on_road := absf(across) != Disasters.FAR_OFF_TILES
			var middle := Iso.tile_to_world(-down * across) if on_road else Vector2.ZERO
			var into := middle + GrimReaper.grave(heading)
			var stand := (middle if across > 0.0 else Vector2.ZERO) + GrimReaper.stand(heading)
			_car.sim.pos = at
			_car.position = Iso.tile_to_world(at)
			var legend := _legend(heading)
			var path: Array[Vector2] = [Vector2.ZERO]
			var frames: Array[int] = []
			var still := true
			var away := true
			watch_signals(legend)
			while get_signal_emit_count(legend, "finished") == 0 and _frames < Disasters.MAX_FRAMES:
				_step(legend)
				away = away and _scythe_away(legend)
				if _inside(1) or _inside(2):
					still = still and _near(_from_car(_reaper(legend)), stand)
				# While the car's double rolls in whole, before it has sunk at all.
				var taken := _double(legend)
				if taken != null and taken.offset == -Vector2(CarController.FOOT):
					path.append(_from_car(taken))
					frames.append(_frame_of(taken))
			assert_signal_emit_count(legend, "finished", 1, "%s: it has finished" % what)
			var grave := _grave(legend)
			var off_road := 0
			for texel: Vector2i in pit:
				var ground := at + _on_ground(grave, texel)
				off_road += 0 if Disasters.on_road(_car.sim.buffer, ground) else 1
			var told := "%s: the grave opens on the road's middle ahead" % what
			assert_almost_eq(_from_car(grave), into, NEAR, told)
			if on_road:
				assert_eq(off_road, 0, "%s: all of its pit on the road" % what)
			var head := middle + GrimReaper.head(heading)
			assert_almost_eq(_from_car(_stone(legend)), head, NEAR, "%s: its gravestone" % what)
			var earth := middle + GrimReaper.earth(heading)
			assert_almost_eq(_from_car(_earth(legend)), earth, NEAR, "%s: its earth" % what)
			assert_true(still, "%s: the Reaper stands beside it" % what)
			assert_true(away, "%s: its scythe away from the car, its double and the grave" % what)
			if frames.is_empty():
				fail_test("%s: it took the car" % what)
				continue
			assert_true(_straight(path, Vector2.ZERO, into), "%s: the car rolls straight" % what)
			assert_almost_eq(path[-1], into, NEAR, "%s: into the grave's middle" % what)
			assert_eq(frames[0], CarController.frame(heading), "%s: facing as it stopped" % what)
			assert_true(_turns_toward(frames, into), "%s: turning toward the way it rolls" % what)
			var rolls := CarController.frame(Iso.world_to_tile(into))
			assert_eq(frames[-1], rolls, "%s: to face that way" % what)


func test_it_plays_at_dusk_with_no_glow() -> void:
	# Dusk falls as it steps out, and nothing of it adds light, its earth neither: a glow needs a
	# veil (docs/M6.md S10), and the Reaper has nothing that shines.
	var legend := _legend()
	assert_eq(legend.veil_kind, Legend.Veil.DUSK, "dusk falls")
	watch_signals(legend)
	var none := true
	var frames := 0
	while get_signal_emit_count(legend, "finished") == 0 and frames < Disasters.MAX_FRAMES:
		_step(legend)
		frames += 1
		none = none and _glows(legend).is_empty()
	assert_lt(frames, Disasters.MAX_FRAMES, "it finishes")
	assert_true(none, "no glow, the car taken or not")


func test_the_reaper_its_grave_and_its_gravestone_stand_out_from_the_city_by_night() -> void:
	# Each frame of each sheet, against the City's road and ground, in each key light, under its
	# dusk veil (docs/POOLS.md §5.6, V15).
	var legend := _legend()
	var parts: Dictionary[String, Sprite2D] = {
		"the Reaper": _reaper(legend),
		"its grave": _grave(legend),
		"its gravestone": _stone(legend),
	}
	for what: String in parts:
		var part := parts[what]
		var image := part.texture.get_image()
		var share := Art.night_share(image, part.hframes, CITY, legend.veil_kind)
		var told := "%s: %.0f%% of its least frame's pixels stand out" % [what, share * 100.0]
		assert_gte(share, Art.NIGHT_SHARE, told)
