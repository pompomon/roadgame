class_name AreaDef
extends Resource
## The rules of one area (plan.md §3.7). M1 added the fields the generator and the grey-box renderer
## use, M2 the driving fields CarSim reads; M4 adds the prop, disaster and audio fields. The driving
## defaults are the City's values (IMPLEMENTATION_PLAN.md M4.2).

@export var id := &""
@export var display_name := ""
## Grey-box colour of the area's ground (IMPLEMENTATION_PLAN.md M4.1).
@export var id_color := Color.GRAY
## Straight tiles between two junctions. Both are at least 2 (D7).
@export_range(2, 20) var min_straight := 2
@export_range(2, 20) var max_straight := 5
## Chance that a junction also offers "straight on" as a wrong exit (a crossroads).
@export_range(0.0, 1.0) var cross_junction_chance := 0.3

@export_group("Driving")
## Target-speed gain per tile driven since the last junction, in tiles/s (plan.md §2.3).
@export_range(0.0, 2.0, 0.05) var straight_accel := 0.5
## Auto-braking starts this many tiles before the centre of the next junction, whichever exit the
## player is about to take.
@export_range(1.0, 3.0, 0.05) var junction_brake_distance := 1.25
## The speed the car brakes to by the junction tile, in tiles/s.
@export_range(0.5, 4.0, 0.1) var junction_speed := 2.0
## Off the road, the target speed is multiplied by this (plan.md §2.4).
@export_range(0.1, 1.0, 0.05) var offroad_speed_mult := 0.5
@export_range(0.0, 100.0, 1.0) var offroad_damage_per_sec := 30.0
## The farthest the car may drive off the road, in tiles: 2.0 in the MVP.
@export_range(0.5, 5.0, 0.1) var offroad_limit_tiles := 2.0


## Returns what breaks the generator's rules, or nothing.
func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if id == &"":
		problems.append("an area has no id")
	if min_straight < 2:
		problems.append("%s: min_straight %d is below 2 (D7)" % [id, min_straight])
	if max_straight < min_straight:
		problems.append("%s: max_straight %d is below min_straight" % [id, max_straight])
	if cross_junction_chance < 0.0 or cross_junction_chance > 1.0:
		problems.append("%s: cross_junction_chance is outside 0..1" % id)
	if straight_accel < 0.0:
		problems.append("%s: straight_accel is negative" % id)
	if junction_brake_distance < least_brake_distance():
		problems.append("%s: junction_brake_distance is below %.3f" % [id, least_brake_distance()])
	# Above the lowest top speed, the car would speed up for some junctions instead of braking.
	if junction_speed <= 0.0 or junction_speed > Tuning.BASE_TOP_SPEED:
		problems.append("%s: junction_speed is outside 0..BASE_TOP_SPEED" % id)
	if offroad_speed_mult <= 0.0 or offroad_speed_mult > 1.0:
		problems.append("%s: offroad_speed_mult is outside 0..1" % id)
	if offroad_damage_per_sec < 0.0:
		problems.append("%s: offroad_damage_per_sec is negative" % id)
	if offroad_limit_tiles <= 0.0:
		problems.append("%s: offroad_limit_tiles must be above 0" % id)
	return problems


## The least junction_brake_distance validate() allows. The car must start braking before it enters
## the junction tile, half a tile from its centre, and one physics step at GLOBAL_SPEED_CAP moves it
## up to GLOBAL_SPEED_CAP / physics_ticks_per_second tiles. With less, a step could carry it from
## outside the brake distance into the junction tile without braking.
static func least_brake_distance() -> float:
	return 0.5 + Tuning.GLOBAL_SPEED_CAP / Engine.physics_ticks_per_second
