class_name Tuning
## Global tuning constants (IMPLEMENTATION_PLAN.md D11). Per-area values live in areas/*.tres.

## Half-width of the road capsules, in tiles (D4).
const ROAD_HALF_WIDTH := 0.32
## Correct-path tiles kept generated ahead of the car's tile after start() and every refill.
const BUFFER_AHEAD := 50
## Refill when fewer correct-path tiles than this are left ahead of the car's tile.
const BUFFER_REFILL_AT := 25
## Correct-path tiles kept behind the car's tile. Older tiles are freed with their branches.
const BUFFER_BEHIND := 5
## Straight tiles before the first junction: path indices 0 to START_STRAIGHT_TILES - 1.
const START_STRAIGHT_TILES := 4
## Length range of a dead-end branch, in tiles (plan.md §3.3).
const DEAD_END_MIN_TILES := 2
const DEAD_END_MAX_TILES := 3
## The first path tiles of an area, whose ground blends with the last area's (plan.md §5.3,
## IMPLEMENTATION_PLAN.md M4.3).
const TRANSITION_TILES := 2
## Set pieces (IMPLEMENTATION_PLAN.md M4.4). The tunnel's height, in screen pixels. Its opacity
## while the car is within FADE_NEAR tiles of the tunnel's road, which rises to 1 by FADE_FAR.
const TUNNEL_HEIGHT_PX := 40.0
const TUNNEL_SEE_THROUGH := 0.2
const TUNNEL_FADE_NEAR := 0.75
const TUNNEL_FADE_FAR := 2.5
## The bridge's banks, at each end of its road, and how far its river reaches across the road
## from its centreline, in tiles. With min_straight 2, other road can come within 2.5 tiles of the
## centreline (M4_PLAN.md K15). How fast the waves drift down the river, in tiles/s.
const BRIDGE_BANK := 0.5
const RIVER_REACH := 2.0
const WAVE_SPEED := 0.6

## Car (IMPLEMENTATION_PLAN.md M4.2). Speeds are in tiles/s, accelerations in tiles/s².
const BASE_TOP_SPEED := 4.0
## Top-speed gain per tile driven in the run.
const TOP_SPEED_GROWTH := 0.002
const GLOBAL_SPEED_CAP := 7.0
const ACCEL := 2.0
## The least braking. Braking for a junction is harder when it must be, so that the car is down to
## junction_speed when it enters the junction tile.
const BRAKE := 4.0
## Turn rate while steering, and the rate at which the car straightens up to the nearest grid
## direction with no input, in rad/s.
const STEER_RATE := 3.0
const STRAIGHTEN_RATE := 1.0
const START_HEALTH := 100.0

## Camera (IMPLEMENTATION_PLAN.md M2.5). Road tiles to show across the smaller screen side.
const VISIBLE_TILES := 5.0
## Zoom levels the camera snaps to, so that pixels stay crisp.
const CAMERA_ZOOMS: Array[float] = [0.5, 1.0, 2.0]
## Look-ahead along the car's heading, in screen pixels at zoom 1.
const LOOKAHEAD_PX := 48.0
## In portrait, the view moves up by this share of its height, so the car sits in the lower third.
const PORTRAIT_BIAS := 0.2
## How fast the camera catches up with its target: the gap shrinks by a factor of e every
## 1 / CAMERA_SMOOTHING seconds.
const CAMERA_SMOOTHING := 6.0

## HUD distance: metres shown per road tile (IMPLEMENTATION_PLAN.md M2.6).
const METRES_PER_TILE := 10
## How long the HUD shows the name of the area the car enters, in seconds of the run: the time
## while the game is paused doesn't count (IMPLEMENTATION_PLAN.md M4.3).
const AREA_BANNER_SECONDS := 2.0

## The end of a run (IMPLEMENTATION_PLAN.md M3). After a disaster or a crash, the car brakes at
## BRAKE, or harder if it must, so that it stops within STOP_SECONDS.
const STOP_SECONDS := 0.6
## From a crash to the game-over screen.
const CRASH_SECONDS := 1.2
## From a wrong or missed turn, the latest the game-over screen may come: the director then ends a
## sequence that has not finished.
const DISASTER_TIMEOUT := 6.0
## The ranges of DisasterParams (plan.md §4.2): the seconds before a disaster shows, how strong it
## is, and the scale of its particles.
const DISASTER_DELAY_MIN := 0.1
const DISASTER_DELAY_MAX := 0.5
const DISASTER_INTENSITY_MIN := 0.5
const DISASTER_INTENSITY_MAX := 1.0
const PARTICLE_SCALE_MIN := 0.75
const PARTICLE_SCALE_MAX := 1.25
## Screen shake (CameraRig.shake): the offset at intensity 1, in screen pixels, which fades out over
## the shake, and its frequencies across and up the screen, in rad/s. They differ, so the camera
## moves in a figure rather than along a line.
const SHAKE_PX := 6.0
const SHAKE_FREQ_X := 47.0
const SHAKE_FREQ_Y := 31.0
## A crash's shake.
const CRASH_SHAKE := 0.5
const CRASH_SHAKE_SECONDS := 0.4
## The crashed car's tint (its grey-box crash frame).
const CRASH_TINT := Color(0.4, 0.4, 0.4)
## The sinkhole (IMPLEMENTATION_PLAN.md M3.2): the hole's radius at intensity 1, in tiles; how long
## it grows, how long the car takes to sink into it, and how long the scene then holds, in seconds.
const SINKHOLE_RADIUS := 0.8
const SINKHOLE_GROW_SECONDS := 0.8
const SINKHOLE_SINK_SECONDS := 1.0
const SINKHOLE_HOLD_SECONDS := 0.6
## The tornado (IMPLEMENTATION_PLAN.md M4.5): how far away it starts, along the params' direction,
## and how far it goes on, in tiles; its height at intensity 1, in screen pixels; how long it takes
## to reach the car, to carry it off and to leave, in seconds; and the car's turns per second as it
## goes, at intensity 1.
const TORNADO_APPROACH_TILES := 2.5
const TORNADO_LEAVE_TILES := 1.5
const TORNADO_HEIGHT_PX := 72.0
const TORNADO_APPROACH_SECONDS := 1.0
const TORNADO_LIFT_SECONDS := 1.0
const TORNADO_LEAVE_SECONDS := 0.6
const TORNADO_SPIN := 2.0
## The flood (M4.5): its water's radius, in tiles, and where it comes from, that far against the
## params' direction; how long it takes to roll in, to rise over the car at intensity 1 (faster when
## stronger) and to hold, in seconds.
const FLOOD_RADIUS := 1.4
const FLOOD_SPREAD_SECONDS := 0.6
const FLOOD_RISE_SECONDS := 0.7
const FLOOD_HOLD_SECONDS := 0.7
## The quicksand (M4.5): the pit's radius at intensity 1, in tiles; how long it takes to spread, to
## swallow the car at intensity 1 (faster when stronger) and to hold, in seconds; and how far the
## car rocks as it sinks, in radians, how often, in Hz.
const QUICKSAND_RADIUS := 0.9
const QUICKSAND_SPREAD_SECONDS := 0.6
const QUICKSAND_SINK_SECONDS := 0.75
const QUICKSAND_HOLD_SECONDS := 0.6
const QUICKSAND_WOBBLE := 0.3
const QUICKSAND_WOBBLE_HZ := 3.0
