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
