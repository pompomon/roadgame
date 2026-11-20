extends GutTest
## Headlights (HEADLIGHTS_PLAN.md §5.1–§5.3): from dusk until the sun rises, while the car drives,
## they light the road in a cone ahead of it, giving back a share of the light that the veil takes
## away. By day, without a clock or a car, and once the run is over, they are off; by night into a
## zone's morning, they stay on until its light has come.

const Fixtures := preload("res://tests/helpers/road_fixtures.gd")
const DELTA := 1.0 / 60.0
## The time the headlights take to switch, and a frame: sums of 1/60 s steps can fall short.
const SWITCH := Tuning.HEADLIGHT_SWITCH_SECONDS + DELTA

var _headlights: Headlights
var _sim: CarSim


func before_each() -> void:
	_headlights = Headlights.new()
	var buffer := RoadBuffer.new(RoadGenerator.new(1, Fixtures.schedule()))
	buffer.start()
	_sim = CarSim.new(buffer)


## A zone's clock at `p_hour`, showing that hour's light.
static func _cycle(p_hour: float) -> DayCycle:
	var cycle := DayCycle.new()
	cycle.start_hour = p_hour
	cycle.enter(120.0)
	cycle.snap()
	return cycle


## Updates the headlights frame by frame for `seconds` by `cycle`, with World at `to_canvas`.
func _run(cycle: DayCycle, seconds: float, to_canvas := Transform2D.IDENTITY) -> void:
	for step: int in roundi(seconds / DELTA):
		_headlights.update(cycle, _sim, to_canvas, DELTA)


func test_on_from_dusk_until_sunrise() -> void:
	var wrong := PackedStringArray()
	for hour: float in [Tuning.DUSK_HOUR, 21.0, 0.0, 3.0, Tuning.SUN_RISE_HOUR - 0.01]:
		_headlights.level = 0.0
		_run(_cycle(hour), SWITCH)
		if _headlights.level != 1.0:
			wrong.append("off at %.2f h" % hour)
	for hour: float in [Tuning.SUN_RISE_HOUR, 7.0, 12.0, Tuning.DUSK_HOUR - 0.01]:
		_headlights.level = 1.0
		_run(_cycle(hour), SWITCH)
		if _headlights.level != 0.0:
			wrong.append("on at %.2f h" % hour)
	assert_eq(wrong, PackedStringArray())


func test_they_turn_on_and_off_in_the_switch_time() -> void:
	var night := _cycle(22.0)
	_run(night, Tuning.HEADLIGHT_SWITCH_SECONDS / 2.0)
	assert_almost_eq(_headlights.level, 0.5, 0.02, "half on halfway")
	_run(night, SWITCH - Tuning.HEADLIGHT_SWITCH_SECONDS / 2.0)
	assert_eq(_headlights.level, 1.0, "on")
	var gain := _headlights.shown(&"gain") as Vector3
	assert_eq(gain, Headlights.gain(night.light, 1.0), "the material's gain")
	_sim.state = CarSim.State.CRASHED
	_run(night, Tuning.HEADLIGHT_SWITCH_SECONDS / 2.0)
	assert_almost_eq(_headlights.level, 0.5, 0.02, "half off halfway, once the run is over")
	_run(night, SWITCH - Tuning.HEADLIGHT_SWITCH_SECONDS / 2.0)
	assert_eq(_headlights.level, 0.0, "off")
	assert_eq(_headlights.shown(&"gain"), Vector3.ZERO, "the road drawn as by day")


func test_into_a_zones_morning_they_stay_as_they_were_until_its_light_has_come() -> void:
	# A zone starts its clock at DAY_START_HOUR (docs/DAYNIGHT.md §5.4), so a car that enters one by
	# night is in its morning at once, while the light shown takes seconds to catch up (§5.3). The
	# headlights stay on until it has: the road in the cone lightens with the rest and never dims,
	# and they turn off only once they light nothing. Entered before dusk, they stay off.
	var cycle := _cycle(22.0)
	_run(cycle, SWITCH)
	_enter_a_zone(cycle)
	var road := _shown_road(cycle)
	var dimmed := PackedStringArray()
	var least := 1.0
	var steps := 0
	while cycle.light != cycle.target() and steps < 600:
		cycle.advance(DELTA)
		_headlights.update(cycle, _sim, Transform2D.IDENTITY, DELTA)
		steps += 1
		var shown := _shown_road(cycle)
		for channel: int in 3:
			if shown[channel] < road[channel] - 1e-6:
				dimmed.append(
					"%d: %d, %.4f to %.4f" % [steps, channel, road[channel], shown[channel]]
				)
		road = shown
		if cycle.light != cycle.target():
			least = minf(least, _headlights.level)
	assert_gt(steps, 60, "the light takes seconds to come")
	assert_eq(cycle.light, Color.WHITE, "the day's")
	assert_eq(least, 1.0, "on while it comes")
	assert_eq(dimmed, PackedStringArray(), "the road in the cone never dims")
	_run(cycle, SWITCH)
	assert_eq(_headlights.level, 0.0, "then off")
	cycle = _cycle(Tuning.DUSK_HOUR - 0.5)
	assert_ne(cycle.light, Color.WHITE, "the evening's light")
	_run(cycle, SWITCH)
	_enter_a_zone(cycle)
	var most := 0.0
	steps = 0
	while cycle.light != cycle.target() and steps < 600:
		cycle.advance(DELTA)
		_headlights.update(cycle, _sim, Transform2D.IDENTITY, DELTA)
		steps += 1
		most = maxf(most, _headlights.level)
	assert_gt(steps, 60, "the light takes seconds to come, before dusk too")
	assert_eq(most, 0.0, "entered before dusk, off while the light comes")


## Takes the car into a new zone, whose clock starts in the morning.
static func _enter_a_zone(cycle: DayCycle) -> void:
	cycle.start_hour = Tuning.DAY_START_HOUR
	cycle.enter(120.0)


## What the road shows of its day colour where the cone is brightest, by channel: 1 + the
## material's gain, times the light that `cycle`'s veil shows.
func _shown_road(cycle: DayCycle) -> Vector3:
	var gain := _headlights.shown(&"gain") as Vector3
	var light := Vector3(cycle.light.r, cycle.light.g, cycle.light.b)
	return (Vector3.ONE + gain) * light


func test_off_without_a_clock_or_a_car_and_once_the_run_is_over() -> void:
	# Each from on. The run is over after a disaster, a crash or the arrival, which holds the clock
	# at dusk (docs/ENDGAME.md §5.8); braking and off the road, the car drives on.
	var night := _cycle(22.0)
	var over: Array[CarSim.State] = [
		CarSim.State.DISASTER, CarSim.State.CRASHED, CarSim.State.ARRIVED
	]
	for state: CarSim.State in CarSim.State.values():
		_sim.state = CarSim.State.DRIVING
		_run(night, SWITCH)
		var named: String = CarSim.State.find_key(state)
		assert_eq(_headlights.level, 1.0, "on before " + named)
		_sim.state = state
		_run(night, SWITCH)
		assert_eq(_headlights.level, 0.0 if state in over else 1.0, named)
	_sim.state = CarSim.State.DRIVING
	_run(night, SWITCH)
	_run(null, SWITCH)
	assert_eq(_headlights.level, 0.0, "no clock")
	_run(night, SWITCH)
	assert_eq(_headlights.level, 1.0, "on again")
	for step: int in roundi(SWITCH / DELTA):
		_headlights.update(night, null, Transform2D.IDENTITY, DELTA)
	assert_eq(_headlights.level, 0.0, "no car")


func test_the_road_in_the_cone_shows_a_share_of_its_day_light() -> void:
	# Under the veil the road shows its colour times the light, and in the cone's brightest part
	# times (1 + gain): HEADLIGHT_SHARE of the way back to its day colour, in HEADLIGHT_COLOR. So
	# never lighter than by day, and by day just as before.
	for light: Color in [Tuning.LIGHT_NIGHT, Tuning.LIGHT_DUSK, Tuning.LIGHT_DAWN, Color.WHITE]:
		var gain := Headlights.gain(light, 1.0)
		for channel: int in 3:
			var kept: float = light[channel]
			var lit: float = (
				kept + (Tuning.HEADLIGHT_SHARE * Tuning.HEADLIGHT_COLOR[channel] * (1.0 - kept))
			)
			assert_almost_eq((1.0 + gain[channel]) * kept, lit, 1e-5, "%s, %d" % [light, channel])
			assert_lte(lit, 1.0)
		assert_eq(Headlights.gain(light, 0.0), Vector3.ZERO, "off")
	assert_eq(Headlights.gain(Color.WHITE, 1.0), Vector3.ZERO, "by day")
	assert_eq(Headlights.gain(Color(0.0, 0.5, 0.5), 1.0).x, 0.0, "a channel the veil blacks out")


## The canvas point `tiles` along the car's axis and `aside` across it from its lamps, with World
## at `to_canvas`.
func _point(tiles: float, aside: float, to_canvas: Transform2D) -> Vector2:
	var ahead := _sim.forward()
	var lamps := _sim.pos + ahead * Tuning.HEADLIGHT_FRONT
	return to_canvas * Iso.tile_to_world(lamps + ahead * tiles + Vector2(-ahead.y, ahead.x) * aside)


func test_the_cone_lights_the_road_ahead_of_the_car() -> void:
	# Whichever way the car heads, and wherever World is on the canvas: brightest ahead of the
	# lamps, dimming towards its reach, and nothing behind them, past the reach or outside the cone.
	var night := _cycle(22.0)
	var reach := Tuning.HEADLIGHT_REACH
	var dim := Tuning.HEADLIGHT_DIM_FROM * reach
	for to_canvas: Transform2D in [
		Transform2D.IDENTITY, Transform2D(0.0, Vector2(2.0, 2.0), 0.0, Vector2(-300, 40))
	]:
		for angle: float in [0.0, -PI / 2.0, 0.3, 2.0]:
			_sim.angle = angle
			_run(night, DELTA, to_canvas)
			var heading := "at %.1f rad, %s" % [angle, to_canvas]
			assert_almost_eq(_headlights.lit(_point(0.05, 0.0, to_canvas)), 1.0, 1e-4, heading)
			assert_almost_eq(_headlights.lit(_point(dim, 0.0, to_canvas)), 1.0, 1e-4, heading)
			var far := _headlights.lit(_point((dim + reach) / 2.0, 0.0, to_canvas))
			assert_between(far, 0.1, 0.9, heading + ": dimming")
			assert_eq(_headlights.lit(_point(reach + 0.01, 0.0, to_canvas)), 0.0, heading)
			assert_eq(_headlights.lit(_point(-0.05, 0.0, to_canvas)), 0.0, heading + ": behind")
			var width := Tuning.HEADLIGHT_HALF_WIDTH + Tuning.HEADLIGHT_SPREAD
			assert_eq(_headlights.lit(_point(1.0, width + 0.01, to_canvas)), 0.0, heading)
			assert_eq(_headlights.lit(_point(1.0, -width - 0.01, to_canvas)), 0.0, heading)
			assert_gt(_headlights.lit(_point(1.0, width * Tuning.HEADLIGHT_EDGE, to_canvas)), 0.99)


func test_the_material_shows_the_cone_as_lit_works_it_out() -> void:
	# The shader can't run headless, so its parameters are checked: lit() reads them as the
	# shader does, and they are the tunings' (P1 checks the frames).
	_run(_cycle(22.0), DELTA)
	var material := _headlights.material
	assert_eq(material.shader, Headlights.SHADER)
	for parameter: StringName in [&"origin", &"along", &"across", &"gain"]:
		assert_eq(material.get_shader_parameter(parameter), _headlights.shown(parameter), parameter)
	assert_eq(material.get_shader_parameter(&"reach"), Tuning.HEADLIGHT_REACH)
	assert_eq(material.get_shader_parameter(&"half_width"), Tuning.HEADLIGHT_HALF_WIDTH)
	assert_eq(material.get_shader_parameter(&"spread"), Tuning.HEADLIGHT_SPREAD)
	assert_eq(material.get_shader_parameter(&"dim_from"), Tuning.HEADLIGHT_DIM_FROM)
	assert_eq(material.get_shader_parameter(&"edge"), Tuning.HEADLIGHT_EDGE)
