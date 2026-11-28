class_name FrameStats
extends RefCounted
## Raw frame intervals, not Godot's smoothed delta (docs/PERF.md §5.1).

const USEC_PER_SECOND := 1000000

var _intervals: Array[int] = []
var _sorted: Array[int] = []
var _usec := 0
var _complete := false


## Closes a window once its intervals cover FPS_WINDOW_SECONDS. The next interval starts anew.
func add(interval_usec: int) -> bool:
	# A coarse clock may repeat a start; count its zero interval (test_frame_stats.gd).
	if interval_usec < 0:
		push_error("FrameStats: a frame interval cannot be negative")
		return false
	if _complete:
		_intervals.clear()
		_usec = 0
		_complete = false
	_intervals.append(interval_usec)
	_sorted.clear()
	_usec += interval_usec
	_complete = _usec >= Tuning.FPS_WINDOW_SECONDS * USEC_PER_SECOND
	return _complete


func count() -> int:
	return _intervals.size()


func usec() -> int:
	return _usec


func fps() -> float:
	return count() * float(USEC_PER_SECOND) / _usec if _usec > 0 else 0.0


func median_ms() -> float:
	var ordered := _ordered()
	if ordered.is_empty():
		return 0.0
	var middle := ordered.size() >> 1
	if ordered.size() % 2 == 0:
		return (ordered[middle - 1] + ordered[middle]) / 2000.0
	return ordered[middle] / 1000.0


func p95_ms() -> float:
	var ordered := _ordered()
	return ordered[ceili(0.95 * ordered.size()) - 1] / 1000.0 if not ordered.is_empty() else 0.0


func longest_ms() -> float:
	var ordered := _ordered()
	return ordered[-1] / 1000.0 if not ordered.is_empty() else 0.0


func early() -> int:
	var total := 0
	for interval: int in _intervals:
		if interval < Tuning.FPS_EARLY_MS * 1000.0:
			total += 1
	return total


func _ordered() -> Array[int]:
	if _sorted.size() != _intervals.size():
		_sorted = _intervals.duplicate()
		_sorted.sort()
	return _sorted
