class_name DayCycle
extends RefCounted
## A zone's clock and its light (DAYNIGHT_PLAN.md §5.1–§5.3). The hour runs from start_hour round
## the clock in day_seconds. The light shown follows the light of the hour, no faster than
## Tuning.LIGHT_MAX_RATE a second in any channel, so that it never jumps, also when a zone sets the
## clock back.

## smoothstep()'s steepest slope, at its middle, against a straight line's.
const STEEPEST := 1.5

## The hour that each zone's clock starts at: Tuning.DAY_START_HOUR, or --hour= (§5.9).
var start_hour := Tuning.DAY_START_HOUR
## Seconds for 24 hours in this zone: its AreaDef.day_seconds. 0 before the first zone and after an
## error, when the clock stands at start_hour.
var day_seconds := 0.0
## Seconds since the car entered the zone, while the run was on.
var seconds := 0.0
## The light shown: what Daylight multiplies the world by.
var light := Color.WHITE


## Starts the clock of a zone whose day lasts `p_day_seconds`, at start_hour. The light shown
## doesn't jump: advance() moves it to the new hour's at the rate.
func enter(p_day_seconds: float) -> void:
	seconds = 0.0
	day_seconds = p_day_seconds
	if not is_finite(p_day_seconds) or p_day_seconds <= 0.0:
		push_error("DayCycle: a day of %.2f s; the clock stands still" % p_day_seconds)
		day_seconds = 0.0


## Shows the light of the hour at once: a new run is a cut.
func snap() -> void:
	light = target()


## Runs the clock for `delta` seconds, and moves the light shown toward the hour's, its farthest
## channel by at most the rate.
func advance(delta: float) -> void:
	seconds += delta
	var goal := target()
	var far := _distance(light, goal)
	var reach := Tuning.LIGHT_MAX_RATE * delta
	light = goal if far <= reach else light.lerp(goal, reach / far)


func hour() -> float:
	if day_seconds <= 0.0:
		return start_hour
	return fposmod(start_hour + 24.0 * seconds / day_seconds, 24.0)


## The light of the hour, which the light shown follows.
func target() -> Color:
	return light_at(hour())


## The light at `p_hour`, eased between the keys before and after it.
static func light_at(p_hour: float) -> Color:
	var hours := Tuning.LIGHT_HOURS
	var h := fposmod(p_hour, 24.0)
	# Before the first key, the last key's segment runs on past midnight.
	var i := hours.size() - 1
	for k: int in hours.size():
		if hours[k] <= h:
			i = k
	var j := (i + 1) % hours.size()
	var span := fposmod(hours[j] - hours[i], 24.0)
	var t := fposmod(h - hours[i], 24.0) / span
	return Tuning.LIGHT_COLORS[i].lerp(Tuning.LIGHT_COLORS[j], smoothstep(0.0, 1.0, t))


## The shortest day whose light changes no faster than LIGHT_MAX_RATE, so that the light shown
## follows it exactly. A segment of `span` hours whose largest change in a channel is `change` is
## steepest at its middle, STEEPEST × change / (span × day_seconds / 24) a second (§5.3).
## AreaDef.validate() reports a shorter day_seconds.
static func least_day_seconds() -> float:
	var hours := Tuning.LIGHT_HOURS
	var least := 0.0
	for i: int in hours.size():
		var j := (i + 1) % hours.size()
		var span := fposmod(hours[j] - hours[i], 24.0)
		var change := _distance(Tuning.LIGHT_COLORS[i], Tuning.LIGHT_COLORS[j])
		least = maxf(least, STEEPEST * 24.0 * change / (span * Tuning.LIGHT_MAX_RATE))
	return least


## The largest difference between `a` and `b` in a channel.
static func _distance(a: Color, b: Color) -> float:
	return maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b)))
