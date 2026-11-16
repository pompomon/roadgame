extends GutTest
## The scarecrow, Rural's second legend (POOLS_PLAN.md §5.4). A scarecrow by the road ahead turns
## its head to the car, and crows rise from its arms. They fly to the car and settle on its roof,
## then carry it off low over the fields and out of sight, in the light of the hour. The scarecrow
## stays, its head turned after the car.

const Disasters := preload("res://tests/helpers/disaster_fixtures.gd")
const Art := preload("res://tests/helpers/art_checks.gd")
const SCARECROW := preload("res://disasters/legends/scarecrow.tscn")
const CROW := preload("res://assets/legends/scarecrow/crow.png")
const RURAL := preload("res://areas/rural.tres")
const DELTA := 1.0 / 60.0
## How near a place must be, in px.
const NEAR := Vector2(0.001, 0.001)
## How near a share of tiles must be: Iso maps tiles to px and back in 32-bit floats.
const NEAR_TILES := 1e-4
## How far from where they settle the crows may be on the last frame of their flight, in px.
const STOPPED_PX := 1.0
## The car's headings, as tile directions: the roads run along the tile axes.
const HEADINGS: Array[Vector2] = [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]

var _stage: Node2D
var _car: CarController
var _camera: CameraRig
var _params: DisasterParams
## Physics frames stepped since play().
var _frames := 0
var _sheet: Image


func before_all() -> void:
	var scarecrow := SCARECROW.instantiate() as Scarecrow
	_sheet = (scarecrow.get_node("%Figure") as Sprite2D).texture.get_image()
	scarecrow.free()


func before_each() -> void:
	_stage = Disasters.stage(self)
	_car = Disasters.car(self, 0.0, _stage)
	_camera = Disasters.camera(self)


## The scarecrow, playing for the car with the car's place as its origin, as the director gives it,
## its direction `direction`, the car heading `heading`, a tile direction.
func _scarecrow(direction := Vector2(0.6, -0.8), heading := Vector2.UP) -> Scarecrow:
	_car.modulate.a = 1.0
	# CarSim.forward() is (sin a, -cos a).
	_car.sim.angle = atan2(heading.x, -heading.y)
	var scarecrow := Disasters.disaster(self, SCARECROW, _car, _camera) as Scarecrow
	scarecrow.stage = _stage
	_params = Disasters.params()
	_params.direction = direction
	_params.origin_world = _car.global_position
	_frames = 0
	scarecrow.play(_params)
	return scarecrow


## Directions in the params, and the side of the screen that each sends the car off to, 1 for the
## right, as the Mothman's do: a tile direction that shows to the right of the car, or none, sends
## it right.
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
	for length: float in Tuning.SCARECROW_BEATS:
		sum += length
		ends.append(sum)
	return ends


## When `share` of `beat` is done, in seconds after the delay.
static func _at(beat: int, share: float) -> float:
	return _ends()[beat] - Tuning.SCARECROW_BEATS[beat] * (1.0 - share)


## Steps `scarecrow` on to `seconds` after its delay, and a frame or two past it: a clock that sums
## frames can fall short of the sum by a hair.
func _step_to(scarecrow: Scarecrow, seconds: float) -> void:
	var target := ceili((_params.delay + seconds) / DELTA) + 1
	simulate(scarecrow, target - _frames, DELTA)
	_frames = target


## Steps `scarecrow` one frame.
func _step(scarecrow: Scarecrow) -> void:
	simulate(scarecrow, 1, DELTA)
	_frames += 1


## Whether `scarecrow` has stepped on to `seconds` after its delay.
func _reached(seconds: float) -> bool:
	return _frames * DELTA >= _params.delay + seconds


## How far the steps have gone through `beat`, from 0 at its start to 1 at its end.
func _through(beat: int) -> float:
	return (_frames * DELTA - _params.delay - _at(beat, 0.0)) / Tuning.SCARECROW_BEATS[beat]


## Whether a step from here stays half a frame short of `seconds` after the delay, so that the
## legend's clock and theirs agree that it has not got there.
func _short_of(seconds: float) -> bool:
	return (_frames + 1) * DELTA < _params.delay + seconds - DELTA / 2.0


## Whether the steps are more than a frame away from `share` of `beat`, so that the legend's clock
## and theirs agree on which side of it they are.
func _clear_of(beat: int, share: float) -> bool:
	return absf(_through(beat) - share) > DELTA / Tuning.SCARECROW_BEATS[beat]


## Where `part` is, in px from the car.
func _from_car(part: Node2D) -> Vector2:
	return part.global_position - _car.global_position


## Whether `a` is within NEAR of `b`.
static func _near(a: Vector2, b: Vector2) -> bool:
	return absf(a.x - b.x) <= NEAR.x and absf(a.y - b.y) <= NEAR.y


## Whether there are two of `values` at least, and each is more than the one before it, or less if
## `falling`: a move at a steady speed is neither faster nor slower.
static func _strictly(values: Array[float], falling := false) -> bool:
	if values.size() < 2:
		return false
	for k: int in range(1, values.size()):
		var change := values[k] - values[k - 1]
		if change == 0.0 or (change < 0.0) != falling:
			return false
	return true


## The scarecrow itself, which play() has put on the stage, out of reach of %names.
static func _figure(scarecrow: Scarecrow) -> Sprite2D:
	return scarecrow.standing[0]


static func _crows(scarecrow: Scarecrow) -> CPUParticles2D:
	return scarecrow.get_node("%Crows") as CPUParticles2D


## The car's double, which the crows have taken once they have the car, or null.
static func _double(scarecrow: Scarecrow) -> Sprite2D:
	for part: Sprite2D in scarecrow.staged():
		if part not in scarecrow.standing:
			return part
	return null


## What of `scarecrow` adds light: what it draws, what it has put on the stage, and its particles.
static func _glows(scarecrow: Scarecrow) -> Array[CanvasItem]:
	var items := Disasters.drawables(scarecrow)
	for emitter: CPUParticles2D in Disasters.particles(scarecrow):
		items.append(emitter)
	var found: Array[CanvasItem] = []
	for item: CanvasItem in items:
		var material := Disasters.material_of(item) as CanvasItemMaterial
		if material != null and material.blend_mode == CanvasItemMaterial.BLEND_MODE_ADD:
			found.append(item)
	return found


## The texels of its face in `frame` of its sheet `sheet`, as a rect from its foot: in each row,
## those between two of the sack's colour that aren't of it. An empty rect if there are none.
static func _face(sheet: Image, frame: int) -> Rect2:
	var sack: Color = Art.MakeArt.palette()["line"]
	var half := Scarecrow.FRAME.x >> 1
	var foot := Vector2i(frame * Scarecrow.FRAME.x + half, Scarecrow.FRAME.y)
	var found := Rect2()
	var seen := false
	for y: int in range(-Scarecrow.FRAME.y, 0):
		var sacks: Array[int] = []
		for x: int in range(-half, half):
			if sheet.get_pixelv(foot + Vector2i(x, y)).is_equal_approx(sack):
				sacks.append(x)
		if sacks.is_empty():
			continue
		for x: int in range(sacks[0] + 1, sacks[-1]):
			if x not in sacks:
				var texel := Rect2(Vector2(x, y), Vector2.ONE)
				found = found.merge(texel) if seen else texel
				seen = true
	return found


## Which way `figure` faces on the screen: the x of its face's middle from its foot, right of it if
## above 0, as its frame and flip show it.
func _facing(figure: Sprite2D) -> float:
	var x := _face(_sheet, figure.frame).get_center().x
	return -x if figure.flip_h else x


func test_a_scarecrow_by_the_road_ahead_turns_its_head_to_the_car() -> void:
	# Ahead along the car's road, and off it up the screen, for each heading. It shows, its head
	# turned away, then turned to the side, its face towards the car, then facing the viewer.
	assert_false(_face(_sheet, Scarecrow.Head.AWAY).has_area(), "no face, turned away")
	var turned := _face(_sheet, Scarecrow.Head.TURNED)
	assert_gt(turned.get_center().x, 0.0, "turned to the screen's right in its sheet, %s" % turned)
	var facing := _face(_sheet, Scarecrow.Head.FACING)
	assert_true(facing.has_area(), "a face, facing the viewer")
	assert_almost_eq(facing.get_center().x, 0.0, NEAR.x, "in the middle, %s" % facing)
	var heads: Array[int] = [Scarecrow.Head.AWAY, Scarecrow.Head.TURNED, Scarecrow.Head.FACING]
	var ends := _ends()
	for heading: Vector2 in HEADINGS:
		var what := "heading %s" % heading
		var stand := Scarecrow.stand(heading)
		var off_road := Iso.world_to_tile(stand) - heading * Tuning.SCARECROW_AHEAD_TILES
		assert_almost_eq(off_road.dot(heading), 0.0, NEAR_TILES, "%s: beside the road" % what)
		var off := off_road.length()
		assert_almost_eq(off, Tuning.SCARECROW_SIDE_TILES, NEAR_TILES, "%s: off it" % what)
		assert_lt(Iso.tile_to_world(off_road).y, 0.0, "%s: up the screen from it" % what)
		var scarecrow := _scarecrow(Vector2(0.6, -0.8), heading)
		var figure := _figure(scarecrow)
		assert_eq(figure.get_parent(), _stage, "%s: it stands with the props" % what)
		var standing := true
		var alphas: Array[float] = []
		var frames: Array[int] = []
		var to_car := true
		while not _reached(ends[0]):
			_step(scarecrow)
			standing = standing and _near(_from_car(figure), stand) and Disasters.z(figure) == 0
			alphas.append(figure.modulate.a)
			if frames.is_empty() or frames[-1] != figure.frame:
				frames.append(figure.frame)
			if figure.frame == Scarecrow.Head.TURNED:
				to_car = to_car and _facing(figure) * stand.x < 0.0
		_step(scarecrow)
		assert_true(standing, "%s: it stands there, sorting with the props" % what)
		assert_eq(alphas, Disasters.sorted(alphas), "%s: it only shows more" % what)
		assert_eq(figure.modulate.a, 1.0, "%s: whole" % what)
		assert_eq(frames, heads, "%s: its head turns once, from away to the viewer" % what)
		assert_true(to_car, "%s: turned to the side, towards the car" % what)


func test_crows_rise_from_its_arms_and_into_the_sky() -> void:
	# They burst out once, beating their wings, over the props and the car, as it faces the viewer.
	var ends := _ends()
	var scarecrow := _scarecrow()
	var figure := _figure(scarecrow)
	var crows := _crows(scarecrow)
	assert_eq(crows.texture, CROW, "crows")
	var material := crows.material as CanvasItemMaterial
	assert_not_null(material, "drawn with a CanvasItemMaterial")
	if material == null:
		return
	assert_true(material.particles_animation, "each crow animated")
	assert_eq(material.particles_anim_h_frames, Scarecrow.CROW_FRAMES, "through its wingbeats")
	assert_eq(material.particles_anim_v_frames, 1, "one row")
	assert_true(material.particles_anim_loop, "again and again")
	assert_gt(crows.anim_speed_min, 0.0, "as it flies")
	assert_eq(Disasters.z(crows), Tuning.SKY_Z, "in the sky, over the props and the car")
	# These tests follow the emitter, which stands for the crows only if they fly in its space, all
	# rise in the caw, and live through the carry (the internal review).
	assert_true(crows.local_coords, "they go where it goes")
	var life := crows.lifetime / crows.speed_scale
	assert_lte(life * (1.0 - crows.explosiveness), Tuning.SCARECROW_BEATS[1], "all in the caw")
	assert_gte(life, ends[3] - ends[0], "and live till the carry is over")
	var still := true
	while _short_of(ends[0]):
		_step(scarecrow)
		still = still and not crows.emitting
	assert_true(still, "none till it has turned to the car")
	var rising := true
	var from_arms := true
	var facing := true
	while _short_of(ends[1]):
		_step(scarecrow)
		if _clear_of(1, 0.0):
			rising = rising and crows.emitting
			facing = facing and figure.frame == Scarecrow.Head.FACING
		from_arms = from_arms and _near(_from_car(crows), _from_car(figure) + Scarecrow.ARMS)
	assert_true(rising, "they rise")
	assert_true(from_arms, "from its arms")
	assert_true(facing, "as it faces the viewer")
	var once := true
	_step_to(scarecrow, ends[1])
	while not _reached(ends[3]):
		_step(scarecrow)
		once = once and not crows.emitting
	assert_true(once, "once")


func test_they_fly_to_the_car_slowing_to_a_stop_on_its_roof() -> void:
	# Nearer each frame, and slower, from wherever it stands; the car stays where it stopped.
	var ends := _ends()
	for heading: Vector2 in HEADINGS:
		var what := "heading %s" % heading
		var scarecrow := _scarecrow(Vector2(0.6, -0.8), heading)
		var crows := _crows(scarecrow)
		while _short_of(ends[1]):
			_step(scarecrow)
		var last := _from_car(crows)
		var distances: Array[float] = [last.distance_to(Scarecrow.ROOST)]
		var strides: Array[float] = []
		var inside := false
		var there := true
		while _short_of(ends[2]):
			_step(scarecrow)
			var now := _from_car(crows)
			distances.append(now.distance_to(Scarecrow.ROOST))
			# A beat's first frame may come with any share of a frame done.
			if inside:
				strides.append(now.distance_to(last))
			inside = _through(2) > 0.0 and _clear_of(2, 0.0)
			last = now
			there = there and _double(scarecrow) == null and _car.modulate.a == 1.0
		assert_eq(distances, Disasters.sorted(distances, true), "%s: nearer each frame" % what)
		assert_true(_strictly(strides, true), "%s: slower each frame" % what)
		assert_lt(distances[-1], STOPPED_PX, "%s: to a stop over its roof" % what)
		assert_true(there, "%s: the car is still there" % what)


func test_they_carry_the_car_off_low_over_the_fields_and_out_of_sight() -> void:
	# Faster and faster, off to the side that its direction picks and up the screen, held a little
	# off the ground. The double stays on the stage, so it sorts with the props by its foot.
	var ends := _ends()
	var sides := _sides()
	var rest := -Vector2(CarController.FOOT)
	for direction: Vector2 in sides:
		var what := str(direction)
		var side := sides[direction]
		var scarecrow := _scarecrow(direction)
		var figure := _figure(scarecrow)
		var crows := _crows(scarecrow)
		while _double(scarecrow) == null and not _reached(ends[3]):
			_step(scarecrow)
		var car_double := _double(scarecrow)
		if car_double == null:
			fail_test("%s: they took the car" % what)
			continue
		assert_eq(_car.modulate.a, 0.0, "%s: the double took the car's place" % what)
		assert_true(Disasters.shows(car_double), "%s: in the same frame" % what)
		assert_eq(car_double.get_parent(), _stage, "%s: on the stage" % what)
		assert_eq(Disasters.z(car_double), 0, "%s: with the props" % what)
		var staged: Array[Sprite2D] = [figure, car_double]
		assert_eq(scarecrow.staged(), staged, "%s: it frees what it stands up" % what)
		var last := _from_car(car_double)
		var strides: Array[float] = []
		var heights: Array[float] = []
		var alphas: Array[float] = []
		var held := true
		var after := true
		while not _reached(ends[3]):
			_step(scarecrow)
			var now := _from_car(car_double)
			if _clear_of(3, 1.0):
				strides.append(now.distance_to(last))
			last = now
			heights.append(rest.y - car_double.offset.y)
			alphas.append(car_double.modulate.a)
			var roof := Scarecrow.ROOST + car_double.offset - rest
			held = held and _near(_from_car(crows) - now, roof)
			held = held and crows.modulate.a == car_double.modulate.a
			if _clear_of(3, Scarecrow.FOLLOW_AT):
				var turned := _through(3) > Scarecrow.FOLLOW_AT
				var head := Scarecrow.Head.TURNED if turned else Scarecrow.Head.FACING
				after = after and figure.frame == head
				if turned:
					after = after and _facing(figure) * side > 0.0
		_step(scarecrow)
		var carried := _from_car(car_double)
		assert_almost_eq(carried, Scarecrow.carry(side, 1.0), NEAR, "%s: off to its side" % what)
		assert_gt(carried.x * side, 0.0, "%s: to its side" % what)
		assert_lt(carried.y, 0.0, "%s: up the screen, over the fields" % what)
		assert_true(_strictly(strides), "%s: faster each frame" % what)
		assert_eq(heights, Disasters.sorted(heights), "%s: they lift it" % what)
		var lift := Tuning.SCARECROW_LIFT_PX
		assert_almost_eq(heights[-1], lift, NEAR.y, "%s: a little off the ground" % what)
		assert_true(held, "%s: the crows hold it, on its roof" % what)
		assert_eq(alphas, Disasters.sorted(alphas, true), "%s: it only fades" % what)
		assert_false(Disasters.shows(car_double), "%s: out of sight" % what)
		assert_false(Disasters.particles_show(crows), "%s: with the crows" % what)
		assert_true(after, "%s: the scarecrow's head turns after it" % what)


func test_the_scarecrow_stays_its_head_turned_after_the_car() -> void:
	# What it leaves still shows once it has finished (docs/M6.md N31).
	var sides := _sides()
	for direction: Vector2 in sides:
		var what := str(direction)
		var scarecrow := _scarecrow(direction)
		var figure := _figure(scarecrow)
		var stand := _from_car(figure)
		watch_signals(scarecrow)
		_step_to(scarecrow, Disasters.duration(scarecrow, _params) - _params.delay + 0.5)
		assert_signal_emit_count(scarecrow, "finished", 1, "%s: it has finished" % what)
		assert_true(Disasters.shows(figure), "%s: the scarecrow stays" % what)
		assert_eq(figure.modulate.a, 1.0, "%s: whole" % what)
		assert_eq(figure.get_parent(), _stage, "%s: with the props" % what)
		assert_almost_eq(_from_car(figure), stand, NEAR, "%s: where it stood" % what)
		assert_eq(figure.frame, Scarecrow.Head.TURNED, "%s: its head turned" % what)
		assert_gt(_facing(figure) * sides[direction], 0.0, "%s: after the car" % what)
		assert_eq(_car.modulate.a, 0.0, "%s: the car is gone" % what)


func test_it_plays_in_the_light_of_the_hour_with_no_veil_and_no_glow() -> void:
	# A glow needs a veil (docs/M6.md S10): nothing of it adds light, its crows neither.
	var scarecrow := _scarecrow()
	assert_eq(scarecrow.veil_kind, Legend.Veil.NONE, "no veil")
	watch_signals(scarecrow)
	var none := true
	var frames := 0
	while get_signal_emit_count(scarecrow, "finished") == 0 and frames < Disasters.MAX_FRAMES:
		_step(scarecrow)
		frames += 1
		none = none and _glows(scarecrow).is_empty()
	assert_lt(frames, Disasters.MAX_FRAMES, "it finishes")
	assert_true(none, "no glow, the car taken or not")


func test_it_and_its_crows_stand_out_from_the_fields_by_night() -> void:
	# Each frame of each sheet, against Rural's road and ground, in each key light (POOLS_PLAN.md
	# §5.6, V15): the crows carry the car by night too.
	var scarecrow := _scarecrow()
	var figure := _figure(scarecrow)
	var crows := _crows(scarecrow)
	var material := crows.material as CanvasItemMaterial
	var sheets: Dictionary[String, Array] = {
		"the scarecrow": [figure.texture, figure.hframes],
		"its crows": [crows.texture, material.particles_anim_h_frames if material != null else 1],
	}
	for what: String in sheets:
		var texture: Texture2D = sheets[what][0]
		var frames: int = sheets[what][1]
		var share := Art.night_share(texture.get_image(), frames, RURAL, scarecrow.veil_kind)
		var told := "%s: %.0f%% of its least frame's pixels stand out" % [what, share * 100.0]
		assert_gte(share, Art.NIGHT_SHARE, told)
