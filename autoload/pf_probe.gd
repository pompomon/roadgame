class_name PfProbe
extends Node
## PF prototype only: measures each frame and prints a PERF line every second, to the browser's
## console on the Web. User arguments: --pf-hide=<layers> hides layers for A/B (props, shadows,
## lamps, veil, ground, road, skids, ui, setpieces, disasters), --pf-nosort turns off Props' y-sort.

const REPORT_USEC := 1000000
## --pf-gate=<cap>: the engine's frames run once n refreshes less half of one have passed, where
## n = max(1, floor(1.05 * refresh rate / cap)), so that the rate stays at or above cap / 1.05. The
## refresh is the median of the last 30 steps between distinct timestamps that are under 1.5 times
## their 10th percentile, which frames that miss refreshes can't lengthen, nor jitter shorten. A
## frame that comes late isn't followed early: the game moves in 60 Hz steps, so an early frame
## would show no more of them. Only the engine's chain is gated: the first callback asked for once
## the gate is in, as Godot runs every _ready() before emscripten_set_main_loop() asks for its first
## frame (web_main.cpp :165-178). Its handles follow each wait, for cancelAnimationFrame. A cap of
## 0 installs nothing.
const GATE_JS := """
(function (cap) {
	if (window.__pfGate) { window.__pfGate.cap = cap; return; }
	if (!(cap > 0)) return;
	const g = { cap: cap, runner: null, last: -1, prev: -1, steps: [], refresh: 0, skipped: 0,
		native: new Map(), next: -1 };
	window.__pfGate = g;
	const raf = window.requestAnimationFrame.bind(window);
	const caf = window.cancelAnimationFrame.bind(window);
	const refresh = function (a) {
		const s = a.slice().sort(function (x, y) { return x - y; });
		const short = s.filter(function (d) { return d < 1.5 * s[Math.floor(s.length / 10)]; });
		return short[short.length >> 1];
	};
	window.requestAnimationFrame = function (cb) {
		if (g.runner === null) g.runner = cb;
		if (cb !== g.runner) return raf(cb);
		const handle = g.next--;
		const step = function (t) {
			if (t > g.prev) {
				if (g.prev >= 0 && t - g.prev >= 2) {
					g.steps.push(t - g.prev);
					if (g.steps.length > 30) g.steps.shift();
					g.refresh = refresh(g.steps);
				}
				g.prev = t;
			}
			const n = g.cap > 0 && g.steps.length >= 8
				? Math.max(1, Math.floor(1.05 * 1000 / g.refresh / g.cap)) : 1;
			if (n > 1 && g.last >= 0 && t - g.last < (n - 0.5) * g.refresh) {
				g.skipped++;
				g.native.set(handle, raf(step));
				return;
			}
			g.native.delete(handle);
			g.last = t;
			cb(t);
		};
		g.native.set(handle, raf(step));
		return handle;
	};
	window.cancelAnimationFrame = function (id) {
		if (g.native.has(id)) { caf(g.native.get(id)); g.native.delete(id); return; }
		caf(id);
	};
})(%d);
"""

## Microseconds that instrumented code adds up by key, since the last report.
static var spent: Dictionary[StringName, int] = {}
## The most microseconds of a key in one frame, since the last report.
static var worst: Dictionary[StringName, int] = {}
static var _frame_spent: Dictionary[StringName, int] = {}
## Prototype switches that Lamps reads: --pf-lamps=noglow,nosil.
static var lamps_noglow := false
static var lamps_nosil := false
static var lamps_atlas := false
## --pf-lamps=rs draws the silhouettes and glows as RenderingServer items, cull hides the group
## when no glow is in view.
static var lamps_rs := false
static var lamps_cull := false
## --pf-hide-budget=<n> hides at most n rows a frame, 0 for all at once. --pf-maxfps=<n> sets
## Engine.max_fps. --pf-overlay shows each report on screen, for a phone without a console.
static var hide_budget := 0

var _hide: PackedStringArray = []
var _nogroup: PackedStringArray = []
var _nosort := false
var _end: Node
var _phys_end: Node
var _frame_start := 0
var _last_frame_start := 0
var _proc_end := 0
var _phys_start := 0
var _pre_draw := 0
var _report_start := 0
var _frames := 0
## Frames that show a 60 Hz step that the frame before didn't, since the last report.
var _shown := 0
var _last_physics := -1
var _intervals: Array[int] = []
var _proc_sum := 0
var _phys_sum := 0
var _draw_sum := 0
var _draw_max := 0
var _render_cpu_sum := 0.0
var _setup_cpu_sum := 0.0
var _overlay: Label
var _stretch := ""


static func add(key: StringName, usec: int) -> void:
	spent[key] = spent.get(key, 0) + usec
	_frame_spent[key] = _frame_spent.get(key, 0) + usec


class Edge:
	extends Node
	var on_process: Callable
	var on_physics: Callable

	func _process(_delta: float) -> void:
		if on_process.is_valid():
			on_process.call()

	func _physics_process(_delta: float) -> void:
		if on_physics.is_valid():
			on_physics.call()


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--pf-hide="):
			_hide = arg.trim_prefix("--pf-hide=").split(",")
		elif arg == "--pf-nosort":
			_nosort = true
		elif arg == "--pf-direct":
			RenderingServer.viewport_set_render_direct_to_screen(
				get_viewport().get_viewport_rid(), true
			)
		elif arg == "--pf-stretch=viewport":
			get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
			_stretch = "VIEWPORT"
		elif arg == "--pf-stretch=fold":
			_stretch = "FOLD"
			# Viewport stretch, with the camera's zoom step folded into the stretch: the root
			# renders at art resolution, and the camera then picks zoom 1. The UI scales with it.
			get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
			get_viewport().size_changed.connect(_fold_zoom)
			_fold_zoom.call_deferred()
		elif arg.begins_with("--pf-nogroup="):
			_nogroup = arg.trim_prefix("--pf-nogroup=").split(",")
		elif arg.begins_with("--pf-lamps="):
			var parts := arg.trim_prefix("--pf-lamps=").split(",")
			lamps_noglow = parts.has("noglow")
			lamps_nosil = parts.has("nosil")
			lamps_atlas = parts.has("atlas")
			lamps_rs = parts.has("rs")
			lamps_cull = parts.has("cull")
		elif arg.begins_with("--pf-hide-budget="):
			hide_budget = int(arg.trim_prefix("--pf-hide-budget="))
		elif arg.begins_with("--pf-maxfps="):
			Engine.max_fps = int(arg.trim_prefix("--pf-maxfps="))
		elif arg.begins_with("--pf-gate=") and OS.has_feature("web"):
			# Caps by the vsync-aligned timestamps of requestAnimationFrame instead of Godot's
			# limiter, which compares the callback's own time and so skips by its jitter.
			Engine.max_fps = 0
			JavaScriptBridge.eval(GATE_JS % int(arg.trim_prefix("--pf-gate=")), true)
		elif arg == "--pf-overlay":
			_add_overlay()
	process_priority = -1000000
	process_physics_priority = -1000000
	process_mode = Node.PROCESS_MODE_ALWAYS
	_end = Edge.new()
	_end.process_priority = 1000000
	_end.process_mode = Node.PROCESS_MODE_ALWAYS
	(_end as Edge).on_process = _on_process_end
	add_child(_end)
	_phys_end = Edge.new()
	_phys_end.process_physics_priority = 1000000
	_phys_end.process_mode = Node.PROCESS_MODE_ALWAYS
	(_phys_end as Edge).on_physics = _on_physics_end
	add_child(_phys_end)
	RenderingServer.frame_pre_draw.connect(_on_pre_draw)
	RenderingServer.frame_post_draw.connect(_on_post_draw)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	_report_start = Time.get_ticks_usec()


func _process(_delta: float) -> void:
	_frame_start = Time.get_ticks_usec()
	if _last_frame_start > 0:
		_intervals.append(_frame_start - _last_frame_start)
	_last_frame_start = _frame_start
	_frames += 1
	var physics := Engine.get_physics_frames()
	if physics != _last_physics:
		_shown += 1
		_last_physics = physics


func _physics_process(_delta: float) -> void:
	_phys_start = Time.get_ticks_usec()


func _on_physics_end() -> void:
	_phys_sum += Time.get_ticks_usec() - _phys_start
	_apply_hides()


func _on_process_end() -> void:
	_proc_end = Time.get_ticks_usec()
	_proc_sum += _proc_end - _frame_start
	_apply_hides()
	for key: StringName in _frame_spent:
		worst[key] = maxi(worst.get(key, 0), _frame_spent[key])
	_frame_spent.clear()


func _on_pre_draw() -> void:
	_pre_draw = Time.get_ticks_usec()


func _on_post_draw() -> void:
	var drawn := Time.get_ticks_usec() - _pre_draw
	_draw_sum += drawn
	_draw_max = maxi(_draw_max, drawn)
	var vp := get_viewport().get_viewport_rid()
	_render_cpu_sum += RenderingServer.viewport_get_measured_render_time_cpu(vp)
	_setup_cpu_sum += RenderingServer.get_frame_setup_time_cpu()
	var now := Time.get_ticks_usec()
	if now - _report_start >= REPORT_USEC and _frames > 0:
		_report(now)


## A label at the bottom left, over the UI, that _report() fills in. Its text keeps to the
## game font's glyphs: capitals, digits, the point and spaces.
func _add_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_overlay = Label.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.0, 0.0, 0.0, 0.6)
	back.set_content_margin_all(2.0)
	_overlay.add_theme_stylebox_override("normal", back)
	_overlay.text = "PF"
	layer.add_child(_overlay)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_overlay.grow_vertical = Control.GROW_DIRECTION_BEGIN


## The switches in use, for the overlay: MAIN when none is.
func _switches() -> String:
	var on: PackedStringArray = []
	if lamps_rs:
		on.append("RS")
	if lamps_cull:
		on.append("CULL")
	if _stretch != "":
		on.append(_stretch)
	if hide_budget > 0:
		on.append("HIDE %d" % hide_budget)
	if Engine.max_fps > 0:
		on.append("CAP %d" % Engine.max_fps)
	return "MAIN" if on.is_empty() else " ".join(on)


func _fold_zoom() -> void:
	var root := get_tree().root
	var full := root.get_visible_rect().size * root.content_scale_factor
	var step := maxf(CameraRig.zoom_for(full), 1.0)
	if step != root.content_scale_factor:
		root.content_scale_factor = step


func _scene_node(path: String) -> Node:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	return scene.get_node_or_null(path)


func _world_node(unique: String) -> Node:
	var world := _scene_node("%World")
	if world == null:
		return null
	return world.get_node_or_null(unique)


func _apply_hides() -> void:
	for key: String in _nogroup:
		var group := _world_node("%Shadows" if key == "shadows" else "%Lamps") as CanvasItem
		if group != null:
			RenderingServer.canvas_item_set_canvas_group_mode(
				group.get_canvas_item(), RenderingServer.CANVAS_GROUP_MODE_DISABLED
			)
	if _hide.is_empty() and not _nosort:
		return
	var names := {
		"props": "%Props",
		"shadows": "%Shadows",
		"lamps": "%Lamps",
		"ground": "%Ground",
		"road": "%RoadLayer",
		"skids": "%Skids",
		"setpieces": "%SetPieces",
		"disasters": "%DisasterLayer",
	}
	for key: String in _hide:
		var node: CanvasItem = null
		if names.has(key):
			node = _world_node(names[key]) as CanvasItem
		elif key == "veil":
			node = _scene_node("%Daylight") as CanvasItem
		elif key == "ui":
			var ui := _scene_node("UI") as CanvasLayer
			if ui != null:
				ui.visible = false
		elif key.begins_with("hud_"):
			node = _scene_node("UI/HUD/" + key.trim_prefix("hud_")) as CanvasItem
		if node != null:
			node.visible = false
	if _nosort:
		var props := _world_node("%Props") as Node2D
		if props != null:
			props.y_sort_enabled = false


func _visible_children(node: Node) -> Vector2i:
	if node == null:
		return Vector2i.ZERO
	var shown := 0
	var glows := 0
	for child: Node in node.get_children(true):
		var item := child as CanvasItem
		if item != null and item.visible:
			shown += 1
			glows += item.get_child_count()
	return Vector2i(shown, glows)


func _report(now: int) -> void:
	var span := now - _report_start
	_intervals.sort()
	var p95 := (
		_intervals[mini(_intervals.size() - 1, int(_intervals.size() * 0.95))]
		if not _intervals.is_empty()
		else 0
	)
	if _overlay != null:
		var most: int = _intervals[-1] if not _intervals.is_empty() else 0
		var cpu := (_proc_sum + _phys_sum + _draw_sum) / 1000.0 / _frames
		var draws_now := RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME
		)
		_overlay.text = (
			"%.1f FPS\nP95 %.1f MAX %.1f MS\nCPU %.1f MS DRAWS %d\n%s"
			% [_frames * 1000000.0 / span, p95 / 1000.0, most / 1000.0, cpu, draws_now, _switches()]
		)
	var props := _visible_children(_world_node("%Props"))
	var shadows := _visible_children(_world_node("%Shadows"))
	var lamps := _visible_children(_world_node("%Lamps"))
	var lamps_on := false
	var lamps_node := _world_node("%Lamps") as CanvasItem
	if lamps_node != null:
		lamps_on = lamps_node.visible
	var shadows_on := false
	var shadows_node := _world_node("%Shadows") as CanvasItem
	if shadows_node != null:
		shadows_on = shadows_node.visible
	var vp := get_viewport().get_viewport_rid()
	var objects := RenderingServer.viewport_get_render_info(
		vp,
		RenderingServer.VIEWPORT_RENDER_INFO_TYPE_CANVAS,
		RenderingServer.VIEWPORT_RENDER_INFO_OBJECTS_IN_FRAME
	)
	var draws := RenderingServer.viewport_get_render_info(
		vp,
		RenderingServer.VIEWPORT_RENDER_INFO_TYPE_CANVAS,
		RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME
	)
	var draws_total := RenderingServer.get_rendering_info(
		RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME
	)
	var keys := ""
	var sorted_keys: Array = spent.keys()
	sorted_keys.sort()
	for key: StringName in sorted_keys:
		keys += " %s=%.2f/%.2f" % [key, spent[key] / 1000.0 / _frames, worst.get(key, 0) / 1000.0]
	# Frame intervals by vsyncs of a 120 Hz display: 1, 2, 3, and 4 or more.
	var vsyncs: Array[int] = [0, 0, 0, 0]
	for interval: int in _intervals:
		vsyncs[clampi(int(interval / 8333.3 - 0.5), 0, 3)] += 1
	keys += " iv8=%d iv17=%d iv25=%d iv33=%d" % vsyncs
	keys += " shown=%.1f" % (_shown * 1000000.0 / span)
	print(
		(
			(
				"PERF fps=%.1f frame=%.2f p95=%.2f proc=%.2f phys=%.2f draw=%.2f/%.2f rcpu=%.2f"
				+ " setup=%.2f nodes=%d props=%d shadows=%d%s lamps=%d+%d%s objs=%d draws=%d/%d"
				+ " vp=%s%s"
			)
			% [
				_frames * 1000000.0 / span,
				span / 1000.0 / _frames,
				p95 / 1000.0,
				_proc_sum / 1000.0 / _frames,
				_phys_sum / 1000.0 / _frames,
				_draw_sum / 1000.0 / _frames,
				_draw_max / 1000.0,
				_render_cpu_sum / _frames,
				_setup_cpu_sum / _frames,
				Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
				props.x,
				shadows.x,
				"" if shadows_on else "(off)",
				lamps.x,
				lamps.y,
				"" if lamps_on else "(off)",
				objects,
				draws,
				draws_total,
				get_viewport().get_visible_rect().size,
				keys,
			]
		)
	)
	_report_start = now
	_frames = 0
	_shown = 0
	_intervals.clear()
	_proc_sum = 0
	_phys_sum = 0
	_draw_sum = 0
	_draw_max = 0
	_render_cpu_sum = 0.0
	_setup_cpu_sum = 0.0
	spent.clear()
	worst.clear()
