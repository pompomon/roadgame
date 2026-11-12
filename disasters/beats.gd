class_name Beats
extends RefCounted
## A legend's beats on one clock (M6_PLAN.md S7, §5.2). Beat i starts when the beats before it have
## ended, and the first `start` seconds after the clock does. Each end is measured from the clock's
## start, so the last ends at start + total(), whatever steps the clock took, as a legend's
## duration() says. A frame that steps over a beat still lists its end in ended(), so that a legend
## can show it.

## When each beat ends, in seconds from the clock's start.
var _ends: Array[float] = []
var _start := 0.0
var _clock := 0.0
## How many beats' ends ended() has listed.
var _listed := 0


func _init(lengths: Array[float], start: float) -> void:
	_start = start
	for i: int in lengths.size():
		_ends.append(start + total(lengths.slice(0, i + 1)))


## The seconds that `lengths` add up to.
static func total(lengths: Array[float]) -> float:
	var sum := 0.0
	for length: float in lengths:
		sum += length
	return sum


func advance(delta: float) -> void:
	_clock += delta


## The beat playing: -1 before the start, and the number of beats once they have all ended.
func index() -> int:
	if _clock < _start:
		return -1
	for i: int in _ends.size():
		if _clock < _ends[i]:
			return i
	return _ends.size()


## How much of beat `i` is done: 0 until it starts, 1 once it has ended.
func progress(i: int) -> float:
	var begin := _start if i == 0 else _ends[i - 1]
	if _clock < begin:
		return 0.0
	if _clock >= _ends[i]:
		return 1.0
	return (_clock - begin) / (_ends[i] - begin)


func done() -> bool:
	return _clock >= (_ends[-1] if not _ends.is_empty() else _start)


## The beats that have ended since the last call, in order.
func ended() -> Array[int]:
	var found: Array[int] = []
	var now := clampi(index(), 0, _ends.size())
	while _listed < now:
		found.append(_listed)
		_listed += 1
	return found
