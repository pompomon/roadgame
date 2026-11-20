extends GutTest
## Nothing comes or goes in view (docs/M5.md L2, E6). While the autopilot drives, no road tile, set
## piece or row of props is added or freed where the camera shows it, nor where the camera heads,
## which is where it comes to rest when a disaster stops the car; and the props of each row in view
## reach past both sides of it, also along the long straights of the Meadows and the Desert
## (SPEEDUP_PLAN.md §4.3). The camera lags behind its target the same way on every screen, so every
## reference screen (docs/M2.md §6.5) shows a part of the world that the tallest or the widest of
## them shows, and the drives run on those two. Each drive takes one seed at the speeds it reaches,
## and the worst case over seeds and speeds comes up to 16 px nearer, or 27 px farther across, as
## the camera lags behind the car at GLOBAL_SPEED_CAP; so each thing must stay MARGIN away, and the
## props must reach MARGIN past the view. But for a dead end freed with its junction: its worst
## case comes only where the path ran the dead end's way, so test_camera_rig.gd checks it
## (docs/ROADGEN.md R6).

const MainScene := preload("res://tests/helpers/main_scene.gd")
## The reference screens' viewports, after the stretch (docs/M2.md §6.5).
const SCREENS: Array[Vector2i] = [
	Vector2i(360, 640),
	Vector2i(360, 922),
	Vector2i(1639, 640),
	Vector2i(532, 640),
	Vector2i(768, 640),
	Vector2i(360, 800),
	Vector2i(1137, 640),
]
const TALLEST := Vector2i(360, 922)
const WIDEST := Vector2i(1639, 640)
const RUN_SEED := 3
## A screen row. With BUFFER_BEHIND 19, a dead end freed with its junction would come 13 px from
## the tallest view at worst (docs/M5.md L2, docs/ROADGEN.md R6).
const MARGIN := Iso.TILE_H / 2.0
## Frames that each drive along long straights takes, from the start of its area. Seed 3's first
## view past PROP_SPREAD comes at frame 203 in the Meadows and 785 in the Desert.
const STRAIGHTS_FRAMES := 1800

var _generated: Array[RoadTile] = []
var _freed: Array[RoadTile] = []
## The nearest that each kind of thing came to a view, in pixels, as it came or went.
var _nearest: Dictionary[String, float] = {}
## The farthest that a view went past the PROP_SPREAD tiles either side of a row in it, in pixels:
## above 0 where only the row's span() reached across it.
var _past_spread := -INF
## The props that rows showed past the PROP_SPREAD tiles either side of their path tile.
var _props_past_spread := 0


func before_each() -> void:
	EventBus.tiles_generated.connect(_on_tiles_generated)
	EventBus.tiles_freed.connect(_on_tiles_freed)
	_nearest.clear()
	_past_spread = -INF
	_props_past_spread = 0


func after_each() -> void:
	EventBus.tiles_generated.disconnect(_on_tiles_generated)
	EventBus.tiles_freed.disconnect(_on_tiles_freed)
	GameState.quit_to_title()


func _on_tiles_generated(tiles: Array[RoadTile]) -> void:
	_generated.append_array(tiles)


func _on_tiles_freed(tiles: Array[RoadTile]) -> void:
	_freed.append_array(tiles)


## The main scene in a viewport of `size`, which the autopilot drives from the start of `area`.
func _open(size: Vector2i, area := "") -> Node:
	var view := SubViewport.new()
	view.size = size
	add_child_autofree(view)
	var main: Node = MainScene.MAIN_SCENE.instantiate()
	var args: Array[String] = ["--autopilot", "--seed=%d" % RUN_SEED]
	if area != "":
		args.append("--area=%s" % area)
	main.args = PackedStringArray(args)
	view.add_child(main)
	return main


## What `camera` shows, in World pixels, when it is at `at`.
static func _view(camera: CameraRig, at: Vector2) -> Rect2:
	var size := camera.get_viewport_rect().size / camera.zoom
	return Rect2(at + camera.offset - size / 2.0, size)


## What the camera shows around the car, which is where it heads, at the start of a run.
static func _view_around_car(main: Node) -> Rect2:
	var camera: CameraRig = main.get_node("%Camera")
	var view := _view(camera, camera.position)
	view.position -= MainScene.car(main).position
	return view


static func _diamond(cell: Vector2i) -> Rect2:
	var top := Iso.tile_to_world(cell)
	return Rect2(top - Vector2(Iso.TILE_W / 2.0, 0.0), Vector2(Iso.TILE_W, Iso.TILE_H))


## The World pixels that `node`'s polygons and sprites draw on.
static func _bounds(node: Node) -> Rect2:
	var points := PackedVector2Array()
	for part: Node in [node] + node.find_children("*", "", true, false):
		if part is Polygon2D:
			var polygon := part as Polygon2D
			var at := polygon.get_global_transform().translated_local(polygon.offset)
			points.append_array(at * polygon.polygon)
		elif part is Sprite2D:
			var sprite := part as Sprite2D
			var rect := sprite.get_global_transform() * sprite.get_rect()
			points.append(rect.position)
			points.append(rect.end)
	if points.is_empty():
		return Rect2()
	var bounds := Rect2(points[0], Vector2.ZERO)
	for point: Vector2 in points:
		bounds = bounds.expand(point)
	return bounds


## How far `rect` is outside `view`, in pixels: below 0 if they overlap.
static func _gap(rect: Rect2, view: Rect2) -> float:
	return maxf(
		maxf(view.position.x - rect.end.x, rect.position.x - view.end.x),
		maxf(view.position.y - rect.end.y, rect.position.y - view.end.y)
	)


## The rectangles of the sprites of row `k` of props.
static func _row(scatter: PropScatter, k: int) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for sprite: Sprite2D in scatter.sprites(k):
		rects.append(sprite.get_global_transform() * sprite.get_rect())
	return rects


## The road tiles that the buffer made or freed in the last frame, each as its kind, what it is and
## its rectangle.
func _road_changes() -> Array[Array]:
	var changes: Array[Array] = []
	for pair: Array in [[_generated, "road tile made"], [_freed, "road tile freed"]]:
		for tile: RoadTile in pair[0]:
			var what := "path tile %d's %s" % [tile.path_index, tile.cell]
			changes.append([pair[1], what, _diamond(tile.cell)])
	return changes


## Brings `known`, the rectangles of what is shown by its key, up to `now`, and adds to `changes`
## what came or went, as `kind`, " shown" or " hidden", its key and its rectangle.
static func _follow(
	known: Dictionary, now: Dictionary, changes: Array[Array], kind: String
) -> void:
	for key: int in now:
		if not known.has(key):
			for rect: Rect2 in now[key]:
				changes.append([kind + " shown", str(key), rect])
	for key: int in known.keys():
		if not now.has(key):
			for rect: Rect2 in known[key]:
				changes.append([kind + " hidden", str(key), rect])
			known.erase(key)
	for key: int in now:
		known[key] = now[key]


## Whether the rows whose ground shows in `view` get props MARGIN past both sides of it: a row has
## props on the tiles of its span, from `spans`.
func _spread_gap(scatter: PropScatter, view: Rect2, spans: Dictionary[int, Vector2i]) -> String:
	var base := (Tuning.PROP_SPREAD + 0.5) * Iso.TILE_W
	for k: int in scatter.rows():
		var top := Iso.tile_to_world(scatter.anchor(k))
		if top.y > view.end.y or top.y + Iso.TILE_H < view.position.y:
			continue
		var past := maxf(top.x - base - view.position.x, view.end.x - (top.x + base))
		_past_spread = maxf(_past_spread, past)
		var left := top.x + (spans[k].x - 0.5) * Iso.TILE_W
		var right := top.x + (spans[k].y + 0.5) * Iso.TILE_W
		if left > view.position.x - MARGIN or right < view.end.x + MARGIN:
			return (
				"row %d's props reach %s to %s, not %s px past %s" % [k, left, right, MARGIN, view]
			)
	return ""


## Adds to `spans` the span() of each row of `scatter` that it lacks, as PropLayout placed the row:
## the buffer frees the path tiles below a row while the row still shows. Counts the props that the
## row shows past PROP_SPREAD, as PropScatter shows each of them.
func _add_spans(scatter: PropScatter, buffer: RoadBuffer, spans: Dictionary[int, Vector2i]) -> void:
	for k: int in scatter.rows():
		if spans.has(k):
			continue
		var anchor := scatter.anchor(k)
		spans[k] = PropLayout.span(anchor, buffer)
		for sprite: Sprite2D in scatter.sprites(k):
			var tile := Vector2i(Iso.world_to_tile(sprite.global_position).floor())
			_props_past_spread += int(absi(tile.x - anchor.x) > Tuning.PROP_SPREAD)


## Drives `main` for `frames` frames, and fails at the first thing that comes or goes in view, or
## the first row of props that doesn't reach across it. Returns the path tile the car got to.
func _drive(main: Node, frames: int) -> int:
	var camera: CameraRig = main.get_node("%Camera")
	var world: WorldRenderer = main.get_node("%World")
	var set_pieces: Node = world.get_node("%SetPieces")
	var scatter := world.prop_scatter()
	var buffer := MainScene.car(main).sim.buffer
	var rows: Dictionary[int, Array] = {}
	var pieces: Dictionary[int, Array] = {}
	var spans: Dictionary[int, Vector2i] = {}
	_follow(rows, _shown_rows(scatter, rows), [], "")
	_follow(pieces, _shown_pieces(set_pieces, pieces), [], "")
	_add_spans(scatter, buffer, spans)
	_generated.clear()
	_freed.clear()
	for frame: int in frames:
		simulate(main, 1, MainScene.DELTA)
		# The engine runs every node's _physics_process before any _process, which simulate()
		# runs node by node: World's ran before the car moved.
		scatter.update(0.0)
		_add_spans(scatter, buffer, spans)
		var changes := _road_changes()
		_follow(rows, _shown_rows(scatter, rows), changes, "prop")
		_follow(pieces, _shown_pieces(set_pieces, pieces), changes, "set piece")
		_generated.clear()
		_freed.clear()
		var views: Array[Rect2] = [_view(camera, camera.position), _view(camera, camera.target())]
		for change: Array in changes:
			for view: Rect2 in views:
				var gap := _gap(change[2], view)
				_nearest[change[0]] = minf(_nearest.get(change[0], INF), gap)
				if gap < MARGIN:
					fail_test(
						(
							"frame %d: %s %s %.0f px from view %s"
							% [frame, change[0], change[1], gap, view]
						)
					)
					return buffer.car_index()
		for view: Rect2 in views:
			var spread := _spread_gap(scatter, view, spans)
			if spread != "":
				fail_test("frame %d: %s" % [frame, spread])
				return buffer.car_index()
	return buffer.car_index()


## The rows of props, by their path tile, with their sprites' rectangles: from `known` for the rows
## it has.
static func _shown_rows(scatter: PropScatter, known: Dictionary[int, Array]) -> Dictionary:
	var shown := {}
	for k: int in scatter.rows():
		shown[k] = known[k] if known.has(k) else _row(scatter, k)
	return shown


## The set pieces, by their instance ids, with their bounds: from `known` for those it has.
static func _shown_pieces(set_pieces: Node, known: Dictionary[int, Array]) -> Dictionary:
	var shown := {}
	for piece: Node in set_pieces.get_children():
		var id := piece.get_instance_id()
		shown[id] = known[id] if known.has(id) else [_bounds(piece)]
	return shown


## The path tile the car got to, and the nearest that each kind of change came to a view.
func _report(index: int) -> String:
	var nearest := PackedStringArray()
	for kind: String in _nearest:
		nearest.append("%s %d px" % [kind, _nearest[kind]])
	return "to path tile %d; nearest: %s" % [index, ", ".join(nearest)]


func test_the_tallest_or_the_widest_view_holds_every_reference_view() -> void:
	var held: Array[Rect2] = []
	for size: Vector2i in [TALLEST, WIDEST]:
		held.append(_view_around_car(_open(size)))
		GameState.quit_to_title()
	for size: Vector2i in SCREENS:
		var view := _view_around_car(_open(size))
		GameState.quit_to_title()
		assert_true(held[0].encloses(view) or held[1].encloses(view), "%s: %s" % [size, view])


## Into the rural area at turn 20: past the tunnel, whose roof rises above its last tile, and the
## cross junctions' dead ends of the city, which reach above the junction they are freed with.
func test_nothing_comes_or_goes_in_the_tallest_view() -> void:
	var index := _drive(_open(TALLEST), 4800)
	assert_true(_nearest.has("set piece hidden"), "past the tunnel: %s" % _report(index))
	assert_true(_nearest.has("prop hidden"), "rows of props hidden")
	pass_test(_report(index))


func test_nothing_comes_or_goes_in_the_widest_view() -> void:
	var index := _drive(_open(WIDEST), 1800)
	assert_true(_nearest.has("road tile freed"), "road tiles freed: %s" % _report(index))
	assert_true(_nearest.has("prop hidden"), "rows of props hidden")
	pass_test(_report(index))


## Drives the tallest view along the long straights of `area`, where a decoy joins two straights
## into one that runs farther across the screen than PROP_SPREAD reaches (SPEEDUP_PLAN.md §4.3).
func _drive_straights(area: String) -> void:
	var index := _drive(_open(TALLEST, area), STRAIGHTS_FRAMES)
	var report := (
		"%s; %.0f px past PROP_SPREAD, %d props past it"
		% [_report(index), _past_spread, _props_past_spread]
	)
	assert_gt(_past_spread, 0.0, "a view past PROP_SPREAD: %s" % report)
	assert_gt(_props_past_spread, 0, "props shown past PROP_SPREAD: %s" % report)
	pass_test(report)


func test_props_reach_across_the_tallest_view_in_the_meadows() -> void:
	_drive_straights("meadows")


func test_props_reach_across_the_tallest_view_in_the_desert() -> void:
	_drive_straights("desert")
