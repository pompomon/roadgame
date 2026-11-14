class_name AreaDef
extends Resource
## The rules of one area (plan.md §3.7). M1 added the fields the generator and the grey-box renderer
## use, M2 the driving fields CarSim reads, M3 the disaster pool. The art, prop and audio fields
## come with what reads them, in M5 (docs/M4.md K3). The driving defaults are the City's values
## (IMPLEMENTATION_PLAN.md M4.2).

@export var id := &""
@export var display_name := ""
## The colour of the area's ground: the main colour of its art, and the grey box's for an area that
## has none (IMPLEMENTATION_PLAN.md M4.1). The Atlas shows it too.
@export var id_color := Color.GRAY
## Straight tiles between two junctions. Both are at least 2 (D7).
@export_range(2, 20) var min_straight := 2
@export_range(2, 20) var max_straight := 5
## Chance that a junction also offers "straight on" as a wrong exit (a crossroads).
@export_range(0.0, 1.0) var cross_junction_chance := 0.3
## Chance that a junction offers the turn and straight on, a wrong exit, but not the opposite turn
## (a side road, docs/ROADGEN.md R1).
@export_range(0.0, 1.0) var side_road_chance := 0.0
## Chance that a junction offers straight on and the opposite turn, a wrong exit, but not the turn
## (a decoy, R1): straight on is correct there, and the turn waits for the next junction. The three
## chances add up to 1 at most; T-junctions take the rest.
@export_range(0.0, 1.0) var decoy_chance := 0.0

@export_group("Art")
## The road sheet (docs/M5.md §5.5): GreyboxAtlas's layout, opaque exactly where its road is. With
## none, the grey box's.
@export var road_sheet: Texture2D
## A seamless ground, which repeats across the screen, and its edge, which blends it into the last
## area's ground over the area's first TRANSITION_TILES path tiles. With no ground, a checker in
## id_color; with no edge, the ground begins at a straight line.
@export var ground: Texture2D
@export var ground_edge: Texture2D

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

@export_group("Props")
## What PropScatter scatters beside the road here (docs/M5.md §5.6). Their densities add up to 1 at
## most: the chance that a ground cell shows a prop.
@export var props: Array[PropDef] = []

@export_group("Disasters")
## What a wrong or missed turn here may end in (plan.md §4.3): scenes whose root is a DisasterBase.
## The DisasterDirector picks one with the run's disaster stream.
@export var disasters: Array[PackedScene] = []

@export_group("Audio")
## Loops that AudioDirector cross-fades to when the car enters the area (plan.md §6). With none, the
## last area's fade out.
@export var music: AudioStream
@export var ambient_loop: AudioStream

@export_group("Light")
## Seconds for a full day of 24 hours in this area, whose clock starts again as the car enters it
## (docs/DAYNIGHT.md §5.1). Finite, and at least DayCycle.least_day_seconds(), so that the light
## never changes faster than Tuning.LIGHT_MAX_RATE.
@export_range(10.0, 600.0, 0.5, "or_greater") var day_seconds := 120.0


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
	if side_road_chance < 0.0 or side_road_chance > 1.0:
		problems.append("%s: side_road_chance is outside 0..1" % id)
	if decoy_chance < 0.0 or decoy_chance > 1.0:
		problems.append("%s: decoy_chance is outside 0..1" % id)
	var chances := cross_junction_chance + side_road_chance + decoy_chance
	if chances > 1.0 and not is_equal_approx(chances, 1.0):
		problems.append("%s: the junction chances add up to more than 1" % id)
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
	if not is_finite(day_seconds):
		problems.append("%s: day_seconds isn't finite" % id)
	elif day_seconds < DayCycle.least_day_seconds():
		# In hundredths, rounded up, so that the day the message names is long enough.
		var least := ceilf(DayCycle.least_day_seconds() * 100.0) / 100.0
		problems.append("%s: day_seconds is below %.2f" % [id, least])
	return problems


## The least junction_brake_distance validate() allows. The car must start braking before it enters
## the junction tile, half a tile from its centre, and one physics step at GLOBAL_SPEED_CAP moves it
## up to GLOBAL_SPEED_CAP / physics_ticks_per_second tiles. With less, a step could carry it from
## outside the brake distance into the junction tile without braking.
static func least_brake_distance() -> float:
	return 0.5 + Tuning.GLOBAL_SPEED_CAP / Engine.physics_ticks_per_second
