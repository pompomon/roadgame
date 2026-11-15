extends RefCounted
## Disasters under test outside the main scene, for the M4 disaster tests: a stopped car, a camera,
## params, and the director that plays a disaster after a turn. For the legends (docs/M6.md §4 PR
## 2): a stage, what a disaster draws, and whether it flashes. No class_name: tests/ is not
## exported.

const Fixtures := preload("res://tests/helpers/road_fixtures.gd")
const CAR_SCENE := preload("res://car/car.tscn")
## A legend that uses every part of the legend kit.
const SAMPLE := preload("res://tests/helpers/sample_legend.tscn")
const DELTA := 1.0 / 60.0
## More physics frames than a disaster takes, so that a test that waits for a phase fails instead
## of hanging.
const MAX_FRAMES := 600


## Every disaster in the game's pools, once each, in the schedule's order.
static func scenes() -> Array[PackedScene]:
	var found: Array[PackedScene] = []
	for entry: AreaScheduleEntry in Fixtures.schedule().entries:
		for scene: PackedScene in entry.area.disasters:
			if not found.has(scene):
				found.append(scene)
	return found


## What the contract tests play: the pools' disasters, and the sample legend, so that each part of
## the kit is checked before a pool has a legend.
static func contract_scenes() -> Array[PackedScene]:
	var found := scenes()
	found.append(SAMPLE)
	return found


## Params with `intensity`, and a direction, delay, particle scale and seed that are fixed.
static func params(intensity := 1.0) -> DisasterParams:
	var made := DisasterParams.new()
	made.direction = Vector2(0.6, -0.8)
	made.intensity = intensity
	made.delay = 0.3
	made.particle_scale = 1.2
	made.particle_seed = 42
	made.origin_world = Vector2(100.0, 50.0)
	return made


## A car whose run ended at the start of the road for seed 1, at `speed`, under `parent` or else
## `test`. Only a simulate() of its parent steps it.
static func car(test: GutTest, speed := 0.0, parent: Node = null) -> CarController:
	var buffer := RoadBuffer.new(RoadGenerator.new(1, Fixtures.schedule()))
	buffer.start()
	var made: CarController = CAR_SCENE.instantiate()
	made.sim = CarSim.new(buffer)
	made.sim.state = CarSim.State.DISASTER
	made.sim.speed = speed
	made.input = InputRouter.new()
	if parent == null:
		test.add_child_autofree(made)
	else:
		parent.add_child(made)
	made.add_child(made.input)
	return made


static func camera(test: GutTest) -> CameraRig:
	var made := CameraRig.new()
	test.add_child_autofree(made)
	return made


## `scene`'s disaster, for `car` and `camera`, which may be null, under `test`.
static func disaster(
	test: GutTest, scene: PackedScene, for_car: CarController, for_camera: CameraRig
) -> DisasterBase:
	var made: DisasterBase = scene.instantiate()
	made.car = for_car
	made.camera = for_camera
	test.add_child_autofree(made)
	return made


## The seconds from play() to finished of `disaster` with `with_params`: every disaster's script
## has a static duration(params).
static func duration(of: DisasterBase, with_params: DisasterParams) -> float:
	return of.get_script().call(&"duration", with_params)


## Seconds from the end of a run with the car at `speed` until the director has played `scene`:
## the stop, then the disaster with the params of `run_seed`'s disaster stream. The nodes are in
## the main scene's order, which is the order of their physics steps, and the car is on the stage,
## as it is in World's Props. A legend's steps come last in a frame (Legend.PHYSICS_PRIORITY),
## which changes no count: added in one frame, it first steps in the next either way.
static func director_seconds(
	test: GutTest, scene: PackedScene, run_seed: int, speed: float
) -> float:
	var root := Node.new()
	test.add_child_autofree(root)
	var layer := Node2D.new()
	root.add_child(layer)
	var props := Node2D.new()
	props.y_sort_enabled = true
	root.add_child(props)
	var stopping := car(test, speed, props)
	var rig := CameraRig.new()
	root.add_child(rig)
	var director := DisasterDirector.new()
	director.layer = layer
	director.stage = props
	root.add_child(director)
	director.start_run(run_seed)
	var area := AreaDef.new()
	area.disasters = [scene]
	director.play_disaster(area, stopping, rig)
	var frames := 0
	while director.sequence != DisasterDirector.Sequence.FINISHED and frames < MAX_FRAMES:
		test.simulate(root, 1, DELTA)
		frames += 1
	var played := director.disaster.scene_file_path if director.disaster != null else ""
	test.assert_eq(played, scene.resource_path, "the director played it")
	return frames * DELTA


## The polygons of `node` and its descendants.
static func polygons(node: Node) -> Array[Polygon2D]:
	var found: Array[Polygon2D] = []
	for child: Node in node.find_children("*", "Polygon2D", true, false):
		found.append(child as Polygon2D)
	return found


## The particles of `node` and its descendants, and of what a legend has put on the stage.
static func particles(node: Node) -> Array[CPUParticles2D]:
	var found: Array[CPUParticles2D] = []
	for root: Node in _roots(node):
		for child: Node in root.find_children("*", "CPUParticles2D", true, false):
			found.append(child as CPUParticles2D)
	return found


## What `of` draws, but its particles: its polygons and sprites, and what a legend has put on the
## stage, with what hangs under it (docs/M6.md S1).
static func drawables(of: DisasterBase) -> Array[CanvasItem]:
	var found: Array[CanvasItem] = []
	for root: Node in _roots(of):
		if root != of:
			found.append(root as CanvasItem)
		for kind: String in ["Polygon2D", "Sprite2D"]:
			for child: Node in root.find_children("*", kind, true, false):
				found.append(child as CanvasItem)
	return found


## `node`, and what it has put on the stage if it's a legend: the parts may take children along.
static func _roots(node: Node) -> Array[Node]:
	var found: Array[Node] = [node]
	if node is Legend:
		found.append_array((node as Legend).staged())
	return found


## A stage for a legend's standing parts, which y-sorts them as World's Props does.
static func stage(test: GutTest) -> Node2D:
	var made := Node2D.new()
	made.name = "Stage"
	made.y_sort_enabled = true
	test.add_child_autofree(made)
	return made


## Why the disaster of `scene` flashes with `with_params`, or "" if it doesn't (docs/M6.md §5.6,
## E6). It plays the disaster frame by frame with a car, a camera and a stage, and adds up the light
## of its glows, the sprites that add light, at the points of a grid fixed in the World,
## FLASH_GRID px apart. So glows that overlap add up, and the camera's shake moves nothing.
static func flashes(test: GutTest, scene: PackedScene, with_params: DisasterParams) -> String:
	var limit := Tuning.FLASH_MAX / Tuning.FLASH_SECONDS
	var constants := (load("res://config/tuning.gd") as Script).get_script_constant_map()
	for constant: StringName in constants:
		if constant.ends_with("_HZ") and float(constants[constant]) > limit:
			return "Tuning.%s is above %.1f Hz" % [constant, limit]
	var staging := stage(test)
	var played := disaster(test, scene, car(test, 0.0, staging), camera(test))
	played.stage = staging
	test.watch_signals(played)
	played.play(with_params)
	var lights: Array[Dictionary] = []
	var reds: Array[Dictionary] = []
	var images: Dictionary[Texture2D, Image] = {}
	var veil := 1.0
	while test.get_signal_emit_count(played, "finished") == 0 and lights.size() < MAX_FRAMES:
		test.simulate(played, 1, DELTA)
		var light: Dictionary[Vector2i, float] = {}
		var red: Dictionary[Vector2i, float] = {}
		for item: CanvasItem in drawables(played):
			if not _blends(item, CanvasItemMaterial.BLEND_MODE_ADD):
				continue
			var glow := item as Sprite2D
			if glow == null:
				return "%s adds light, but isn't a sprite" % item.name
			var area := glow.get_rect().get_area() * absf(glow.get_global_transform().determinant())
			if area >= Tuning.FLASH_AREA:
				return "%s covers %d px²" % [glow.name, roundi(area)]
			shine(glow, light, red, images)
		lights.append(light)
		reds.append(red)
		var now := _veil_light(played)
		if now > veil + 1e-6:
			return "the veil brightens from %.3f to %.3f" % [veil, now]
		veil = now
	return flashing(lights, reds)


## Why the light that glows add up to at each point of the World, frame by frame, flashes: `lights`,
## and `reds`, its saturated red share. "" if it doesn't.
static func flashing(lights: Array[Dictionary], reds: Array[Dictionary]) -> String:
	var window := roundi(Tuning.FLASH_SECONDS / DELTA)
	return (
		_flashing(lights, Tuning.FLASH_MAX, window, "light", Color.WHITE.get_luminance())
		+ _flashing(
			reds, Tuning.FLASH_RED_MAX, lights.size() + 1, "red light", Color.RED.get_luminance()
		)
	)


static func _blends(item: CanvasItem, mode: CanvasItemMaterial.BlendMode) -> bool:
	var material := material_of(item) as CanvasItemMaterial
	return material != null and material.blend_mode == mode


## The material that `item` draws with: its own, or, while it uses its parent's, that of the
## CanvasItem that it draws under, as the renderer resolves it. A top-level item draws under none.
static func material_of(item: CanvasItem) -> Material:
	var source := item
	var parent := item.get_parent() as CanvasItem
	while source.use_parent_material and not source.top_level and parent != null:
		source = parent
		parent = source.get_parent() as CanvasItem
	return source.material


## `item`'s modulate, times its parents'.
static func _modulate(item: CanvasItem) -> Color:
	var tint := Color.WHITE
	var node: Node = item
	while node is CanvasItem:
		tint *= (node as CanvasItem).modulate
		node = node.get_parent()
	return tint


## Adds the light of `glow` to `light` at each point of the grid that it covers, and to `red` where
## its colour is saturated red.
static func shine(
	glow: Sprite2D,
	light: Dictionary[Vector2i, float],
	red: Dictionary[Vector2i, float],
	images: Dictionary[Texture2D, Image]
) -> void:
	var tint := glow.self_modulate * _modulate(glow)
	if tint.a <= 0.0 or glow.texture == null or not glow.is_visible_in_tree():
		return
	if not images.has(glow.texture):
		images[glow.texture] = glow.texture.get_image()
	var image := images[glow.texture]
	var last := image.get_size() - Vector2i.ONE
	# As Sprite2D does, the frames split the region, or else the whole texture.
	var whole := (
		glow.region_rect if glow.region_enabled else Rect2(Vector2.ZERO, glow.texture.get_size())
	)
	var cell := whole.size / Vector2(glow.hframes, glow.vframes)
	var source := Rect2(whole.position + Vector2(glow.frame_coords) * cell, cell)
	var rect := glow.get_rect()
	var to_world := glow.get_global_transform()
	var to_local := to_world.affine_inverse()
	var box := to_world * rect
	var grid := Tuning.FLASH_GRID
	for y: int in range(ceili(box.position.y / grid), floori(box.end.y / grid) + 1):
		for x: int in range(ceili(box.position.x / grid), floori(box.end.x / grid) + 1):
			var local := to_local * Vector2(x * grid, y * grid)
			if not rect.has_point(local):
				continue
			var uv := (local - rect.position) / rect.size
			if glow.flip_h:
				uv.x = 1.0 - uv.x
			if glow.flip_v:
				uv.y = 1.0 - uv.y
			var texel := image.get_pixelv(
				Vector2i((source.position + uv * source.size).floor()).clamp(Vector2i.ZERO, last)
			)
			var color := Color(texel.r * tint.r, texel.g * tint.g, texel.b * tint.b)
			var value := color.get_luminance() * texel.a * tint.a
			if value <= 0.0:
				continue
			var at := Vector2i(x, y)
			light[at] = light.get(at, 0.0) + value
			if color.r >= Tuning.FLASH_RED_SHARE * (color.r + color.g + color.b):
				red[at] = red.get(at, 0.0) + value


## What `veil`, a polygon that multiplies, multiplies the world by: its colour, whatever its alpha,
## unless it's so clear that the canvas skips it (docs/M6.md S4). Opaque.
static func veil_tint(veil: Polygon2D) -> Color:
	const DRAWN_ALPHA := 0.007
	var chain := _modulate(veil)
	if not veil.is_visible_in_tree() or chain.a < DRAWN_ALPHA:
		return Color.WHITE
	var tint := veil.color * veil.self_modulate * chain
	return Color(tint.r, tint.g, tint.b)


## How light the world shows under the veils of `of`, from 1 without one.
static func _veil_light(of: DisasterBase) -> float:
	var light := 1.0
	for polygon: Polygon2D in polygons(of):
		if _blends(polygon, CanvasItemMaterial.BLEND_MODE_MUL):
			light *= veil_tint(polygon).get_luminance()
	return light


## Why the light of `frames` flashes at a point: whether it rises, or falls, by more than
## FLASH_CHANGE of `brightest`, the light of white or of pure red, more than `most` times in
## `window` frames. "" if it doesn't. Where glows add up past white, the change that counts stays
## the same, so dimmer pulses after them still flash.
static func _flashing(
	frames: Array[Dictionary], most: int, window: int, what: String, brightest: float
) -> String:
	var points: Dictionary[Vector2i, bool] = {}
	for light: Dictionary in frames:
		for point: Vector2i in light:
			points[point] = true
	var threshold := Tuning.FLASH_CHANGE * brightest
	for point: Vector2i in points:
		var values := PackedFloat32Array()
		for light: Dictionary in frames:
			values.append(light.get(point, 0.0))
		var turns := _turns(values, threshold)
		for k: int in turns.size():
			if _too_many(turns[k], most, window):
				return (
					"the %s %s more than %d times in %d frames at %s"
					% [what, ["rises", "falls"][k], most, window, point * Tuning.FLASH_GRID]
				)
	return ""


## The frames where `values` rise, and those where they fall, by more than `threshold` from their
## last low or high.
static func _turns(values: PackedFloat32Array, threshold: float) -> Array[PackedInt32Array]:
	var rises := PackedInt32Array()
	var falls := PackedInt32Array()
	var heading := 0
	var high := 0.0
	var low := 0.0
	for k: int in values.size():
		var value := values[k]
		if heading >= 0:
			high = maxf(high, value)
		if heading <= 0:
			low = minf(low, value)
		if heading <= 0 and value - low > threshold:
			rises.append(k)
			heading = 1
			high = value
		elif heading >= 0 and high - value > threshold:
			falls.append(k)
			heading = -1
			low = value
	return [rises, falls]


## Whether more than `most` of `frames` fall in some `window` frames in a row.
static func _too_many(frames: PackedInt32Array, most: int, window: int) -> bool:
	for k: int in frames.size() - most:
		if frames[k + most] - frames[k] < window:
			return true
	return false


## Whether `item` shows: it is visible, and neither transparent nor shrunk to nothing, counting its
## parents' modulate and scale.
static func shows(item: CanvasItem) -> bool:
	if not item.is_visible_in_tree():
		return false
	var alpha := item.self_modulate.a
	var size := 1.0
	var node: Node = item
	while node != null:
		if node is CanvasItem:
			alpha *= (node as CanvasItem).modulate.a
		if node is Node2D:
			size *= absf((node as Node2D).scale.x * (node as Node2D).scale.y)
		node = node.get_parent()
	return alpha > 0.01 and size > 1e-4


## Whether `emitter` shows what it emits: it show()s, and its particles live a while, at a size
## over nothing, in colours that aren't all clear. (`particles` would shadow particles().)
static func particles_show(emitter: CPUParticles2D) -> bool:
	return (
		shows(emitter)
		and emitter.amount > 0
		and emitter.lifetime > 0.0
		and emitter.scale_amount_max > 0.0
		and emitter.color.a > 0.01
		and _some_opaque(emitter.color_ramp)
		and _some_opaque(emitter.color_initial_ramp)
	)


## Whether `ramp` is none, or has a colour that isn't clear.
static func _some_opaque(ramp: Gradient) -> bool:
	if ramp == null:
		return true
	for color: Color in ramp.colors:
		if color.a > 0.01:
			return true
	return false


## The z_index that `item` draws at, adding its parents' while it is relative to them.
static func z(item: CanvasItem) -> int:
	var total := 0
	var node: Node = item
	while node is CanvasItem:
		total += (node as CanvasItem).z_index
		if not (node as CanvasItem).z_as_relative:
			break
		node = node.get_parent()
	return total


static func sorted(values: Array[float], descending := false) -> Array[float]:
	var copy: Array[float] = values.duplicate()
	copy.sort()
	if descending:
		copy.reverse()
	return copy


## The value in the middle of `values`.
static func middle(values: Array[float]) -> float:
	return values[floori(values.size() * 0.5)]


## A scene of a disaster with only its words, which plays nothing, for the screens that show them
## apart from the game's pools (docs/M6.md S15).
static func packed(id: StringName, display_name: String, fate := "", lore := "") -> PackedScene:
	const WORDS_DISASTER := preload("res://tests/helpers/words_disaster.gd")
	var made: DisasterBase = WORDS_DISASTER.new()
	made.id = id
	made.display_name = display_name
	made.fate = fate
	made.lore = lore
	var scene := PackedScene.new()
	scene.pack(made)
	made.free()
	return scene
