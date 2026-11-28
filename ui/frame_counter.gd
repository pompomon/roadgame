class_name FrameCounter
extends CanvasLayer
## An opt-in counter of the game's frames, including while paused (docs/PERF.md §5.1).
## Only --fps or ?fps adds the PERF and EVENT lines used by tools/perf/.

var _stats := FrameStats.new()
var _forced := false
var _last_usec := 0
var _game_over := false

@onready var _label: Label = %Label


func _ready() -> void:
	SaveService.settings_changed.connect(_on_settings_changed)
	EventBus.area_changed.connect(_on_area_changed)
	EventBus.disaster_started.connect(_on_disaster_started)
	EventBus.run_ended.connect(_on_run_ended)
	_on_settings_changed("")


func configure(forced: bool) -> void:
	_forced = forced
	_game_over = GameState.state == GameState.State.GAME_OVER
	_on_settings_changed("")


func _process(_delta: float) -> void:
	var over := GameState.state == GameState.State.GAME_OVER
	if over and not _game_over:
		_print_event("game_over")
	_game_over = over
	var now := Time.get_ticks_usec()
	if _last_usec > 0:
		_sample_frame(now - _last_usec)
	_last_usec = now


static func text(stats: FrameStats) -> String:
	return "%s FPS\nP95 %d MS" % [_rate_text(stats), _p95(stats)]


static func report(stats: FrameStats, draws: int) -> String:
	return (
		"PERF fps=%s n=%d us=%d med=%.1f p95=%d max=%.1f early=%d draws=%d"
		% [
			_rate_text(stats),
			stats.count(),
			stats.usec(),
			stats.median_ms(),
			_p95(stats),
			stats.longest_ms(),
			stats.early(),
			draws,
		]
	)


static func _rate_text(stats: FrameStats) -> String:
	var rate := stats.fps()
	# Rounding away from 60 cannot turn a failed E1/E6 window into a passing reading (N24).
	var tenths := ceilf(rate * 10.0) if rate > Tuning.FPS_REFERENCE else floorf(rate * 10.0)
	return "%.1f" % (tenths / 10.0)


static func _p95(stats: FrameStats) -> int:
	return mini(ceili(stats.p95_ms()), Tuning.FPS_MAX_P95_MS)


func _sample_frame(interval_usec: int) -> void:
	if not _stats.add(interval_usec):
		return
	_label.text = text(_stats)
	if _forced:
		_print_line(
			report(
				_stats,
				RenderingServer.get_rendering_info(
					RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME
				)
			)
		)


func _on_settings_changed(key: String) -> void:
	if key not in ["", "fps"]:
		return
	var on: bool = _forced or SaveService.setting("fps")
	if visible != on:
		_stats = FrameStats.new()
		_last_usec = 0
		_label.text = text(_stats)
	visible = on
	set_process(on)


func _on_area_changed(area: AreaDef) -> void:
	_print_event("area %s" % area.id)


func _on_disaster_started(id: StringName, _area: AreaDef) -> void:
	_print_event("disaster_started %s" % id)


func _on_run_ended(cause: StringName, _run_stats: Dictionary) -> void:
	_print_event("run_ended %s" % cause)


func _print_event(event: String) -> void:
	if _forced:
		_print_line("EVENT %s frames=%d" % [event, Engine.get_frames_drawn()])


func _print_line(line: String) -> void:
	print(line)
