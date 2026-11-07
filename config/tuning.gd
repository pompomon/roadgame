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
