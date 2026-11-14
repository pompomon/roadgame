class_name DayCycle
extends RefCounted
## A zone's clock and its light (docs/DAYNIGHT.md §5.1–§5.3). The hour runs from start_hour round
## the clock in day_seconds. The light shown follows the light of the hour, no faster than
## Tuning.LIGHT_MAX_RATE a second in any channel, so that it never jumps, also when a zone sets the
## clock back. The shadows shown follow the sun by day and the moon by night (§5.11), as gradually.

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
## The shadows shown (§5.11): where a pixel of height casts its shadow, in screen pixels from its
## foot, and how dark they are.
var shadow := Vector2.ZERO
var shadow_alpha := 0.0


## Starts the clock of a zone whose day lasts `p_day_seconds`, at start_hour. The light shown
## doesn't jump: advance() moves it to the new hour's at the rate.
func enter(p_day_seconds: float) -> void:
	seconds = 0.0
	day_seconds = p_day_seconds
	if not is_finite(p_day_seconds) or p_day_seconds <= 0.0:
		push_error("DayCycle: a day of %.2f s; the clock stands still" % p_day_seconds)
		day_seconds = 0.0


## Shows the light and the shadows of the hour at once: a new run is a cut.
func snap() -> void:
	light = target()
	shadow = shadow_at(hour())
	shadow_alpha = shadow_alpha_at(hour())


## Runs the clock for `delta` seconds, and moves the light shown toward the hour's, its farthest
## channel by at most the rate. The shadows shown follow the hour's while it moves no faster than
## SHADOW_MAX_RATE, as it does all day but where the moon takes over from the sun, or the sun from
## the moon, both on the ground and casting none. Shadows that would have to move faster, as when
## a zone sets the clock back, turn toward the hour's as they fade out, jump to it unseen, and fade
## in.
func advance(delta: float) -> void:
	seconds += delta
	var goal := target()
	var far := _distance(light, goal)
	var reach := Tuning.LIGHT_MAX_RATE * delta
	light = goal if far <= reach else light.lerp(goal, reach / far)
	var fall := shadow_at(hour())
	var sweep := Tuning.SHADOW_MAX_RATE * delta
	var follows := shadow.distance_to(fall) <= sweep or is_zero_approx(shadow_alpha)
	shadow = fall if follows else shadow.move_toward(fall, sweep)
	var dark := shadow_alpha_at(hour()) if follows else 0.0
	shadow_alpha = move_toward(shadow_alpha, dark, Tuning.SHADOW_ALPHA_RATE * delta)


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


## Where the shadows of `p_hour` fall: the screen pixels from its foot at which a pixel of height
## casts its shadow, away from the sun by day and the moon by night (§5.11). Each crosses the
## sky from the screen's left, through its top, to its right.
static func shadow_at(p_hour: float) -> Vector2:
	var length := Tuning.SHADOW_LONGEST
	var steep := tan(_height(p_hour))
	if steep * length > 1.0:
		length = 1.0 / steep
	var toward := Vector2.from_angle(Tuning.SKY_RISE_ANGLE + PI * _across(p_hour))
	return Iso.tile_to_world(-toward) * length / Iso.HEIGHT_PX


## How dark the shadows of `p_hour` are: the sun's or the moon's alpha, faded where it stands low.
static func shadow_alpha_at(p_hour: float) -> float:
	var alpha := Tuning.SUN_SHADOW_ALPHA if _sun_up(p_hour) else Tuning.MOON_SHADOW_ALPHA
	var fade := smoothstep(Tuning.SHADOW_FADE_FROM, Tuning.SHADOW_FADE_TO, _height(p_hour))
	return alpha * fade


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


static func _sun_up(p_hour: float) -> bool:
	var day := Tuning.SUN_SET_HOUR - Tuning.SUN_RISE_HOUR
	return fposmod(p_hour - Tuning.SUN_RISE_HOUR, 24.0) < day


## How far across the sky the sun is at `p_hour`, or the moon while the sun is down: 0 as it rises,
## ½ at its highest, and 1 as it sets.
static func _across(p_hour: float) -> float:
	var day := Tuning.SUN_SET_HOUR - Tuning.SUN_RISE_HOUR
	var since := fposmod(p_hour - Tuning.SUN_RISE_HOUR, 24.0)
	return since / day if since < day else (since - day) / (24.0 - day)


## How high the sun or the moon stands at `p_hour`, in radians above the ground.
static func _height(p_hour: float) -> float:
	var highest := Tuning.SUN_HIGHEST if _sun_up(p_hour) else Tuning.MOON_HIGHEST
	return highest * sin(PI * _across(p_hour))


## The largest difference between `a` and `b` in a channel.
static func _distance(a: Color, b: Color) -> float:
	return maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b)))
