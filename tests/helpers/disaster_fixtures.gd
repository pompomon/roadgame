extends RefCounted
## Disasters under test outside the main scene, for the M4 disaster tests: a stopped car, a camera,
## params, and the director that plays a disaster after a turn. No class_name: tests/ is not
## exported.

const Fixtures := preload("res://tests/helpers/road_fixtures.gd")
const CAR_SCENE := preload("res://car/car.tscn")
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
## the main scene's order, which is the order of their physics steps.
static func director_seconds(
	test: GutTest, scene: PackedScene, run_seed: int, speed: float
) -> float:
	var root := Node.new()
	test.add_child_autofree(root)
	var layer := Node2D.new()
	root.add_child(layer)
	var stopping := car(test, speed, root)
	var rig := CameraRig.new()
	root.add_child(rig)
	var director := DisasterDirector.new()
	director.layer = layer
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


## The particles of `node` and its descendants.
static func particles(node: Node) -> Array[CPUParticles2D]:
	var found: Array[CPUParticles2D] = []
	for child: Node in node.find_children("*", "CPUParticles2D", true, false):
		found.append(child as CPUParticles2D)
	return found


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
