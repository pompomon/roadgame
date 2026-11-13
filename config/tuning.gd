class_name Tuning
## Global tuning constants (IMPLEMENTATION_PLAN.md D11). Per-area values live in areas/*.tres.

## Half-width of the road capsules, in tiles (D4).
const ROAD_HALF_WIDTH := 0.32
## Correct-path tiles kept generated ahead of the car's tile after start() and every refill.
const BUFFER_AHEAD := 55
## Refill when fewer correct-path tiles than this are left ahead of the car's tile. At least
## PROP_AHEAD + PropLayout.rows_needed(), 36, so that each row of props has the road it must avoid.
## 37 makes the refill cycle, BUFFER_AHEAD - BUFFER_REFILL_AT + 1 tiles, a prime 19, so junctions
## at AreaSchedule's limit meet every point of it: test_area_schedule.gd's check that one then has
## only M4_PLAN.md K1's spare tile past the next needs that (ROADGEN_PLAN.md R6).
const BUFFER_REFILL_AT := 37
## Correct-path tiles kept behind the car's tile. Older tiles are freed with their branches, and a
## set piece with its last tile. With BUFFER_REFILL_AT and PROP_AHEAD, enough that no reference
## screen sees a tile, a set piece or a prop come or go (M5_PLAN.md L2). What reaches highest above
## a freed path tile is a straight-on dead end, DEAD_END_MAX_TILES rows above it: at
## GLOBAL_SPEED_CAP, 19 would leave its end 13 px below the tallest view, and 20 leaves 45
## (test_camera_rig.gd, ROADGEN_PLAN.md R6).
const BUFFER_BEHIND := 20
## Straight tiles before the first junction: path indices 0 to START_STRAIGHT_TILES - 1.
const START_STRAIGHT_TILES := 4
## Length range of a dead-end branch, in tiles (plan.md §3.3). With at least DEAD_END_MIN_TILES,
## its end is out of view on every reference screen as the car enters its junction, so that it
## looks like a road (ROADGEN_PLAN.md R4). Another dead end can cut it shorter (RoadGenerator).
const DEAD_END_MIN_TILES := 6
const DEAD_END_MAX_TILES := 9
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
## centreline (M4_PLAN.md K7). How fast the waves drift down the river, in tiles/s.
const BRIDGE_BANK := 0.5
const RIVER_REACH := 2.0
const WAVE_SPEED := 0.6
## Props (M5_PLAN.md §5.6). The screen row of each path tile gets its props once the car is
## PROP_AHEAD path tiles before it, on the ground of PROP_SPREAD road tiles either side of the path
## tile. A prop's frame reaches at most PROP_MAX_SIZE.y pixels above its foot, PROP_MAX_SIZE.x / 2
## either side of it and PROP_BELOW below it.
const PROP_AHEAD := 24
const PROP_SPREAD := 9
const PROP_MAX_SIZE := Vector2i(64, 72)
const PROP_BELOW := 8

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
## Skid marks (M5_PLAN.md §5.7): while the car brakes for a junction, a pair every SKID_SPACING
## tiles, SKID_REAR tiles behind its centre and SKID_TRACK tiles apart, at SKID_ALPHA. At most
## SKID_MARKS show.
const SKID_SPACING := 0.08
const SKID_REAR := 0.09
const SKID_TRACK := 0.18
const SKID_ALPHA := 0.5
const SKID_MARKS := 256

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

## Audio (IMPLEMENTATION_PLAN.md M5.3): the cross-fade between two areas' music and ambient loops,
## in seconds; the engine's pitch scale from a standing car to GLOBAL_SPEED_CAP; and the damage
## sound, which plays each time the health falls past a multiple of DAMAGE_SOUND_STEP.
const CROSS_FADE_SECONDS := 1.5
const ENGINE_PITCH_MIN := 0.8
const ENGINE_PITCH_MAX := 1.6
const DAMAGE_SOUND_STEP := 10.0
## The loudest sample, from 0 to 1, of each kind of sound: an area's music, its ambient loop, the
## car's loops (AudioDirector.LOOPS) and the one-shot sounds (AudioDirector.EFFECTS). Godot clamps
## the mix at full scale, so the sounds that play together must leave each other room: at the
## default volumes, the music, the ambience, the engine and one effect add up to 1 (M5_PLAN.md L29,
## P12). Measure the mix again before raising one.
const MUSIC_PEAK := 0.5
const AMBIENT_PEAK := 0.25
const LOOP_PEAK := 0.15
const EFFECT_PEAK := 0.25

## HUD distance: metres shown per road tile (IMPLEMENTATION_PLAN.md M2.6).
const METRES_PER_TILE := 10
## How long the HUD shows the name of the area the car enters, in seconds of the run: the time
## while the game is paused doesn't count (IMPLEMENTATION_PLAN.md M4.3).
const AREA_BANNER_SECONDS := 2.0

## The tutorial (TUTORIAL_PLAN.md §5): the City's road, where every wrong exit loops back to the
## path and nothing ends the run. It ends after TUTORIAL_STREAK correct turns in a row. In it, the
## car heals to START_HEALTH in TUTORIAL_HEAL_SECONDS of driving on the road, and once it drives
## TUTORIAL_RESCUE_TILES off the road in one go, it is put back on the path.
const TUTORIAL_STREAK := 12
const TUTORIAL_HEAL_SECONDS := 2.0
const TUTORIAL_RESCUE_TILES := 6.0

## The save file (IMPLEMENTATION_PLAN.md M5.4): a changed setting is written this many seconds
## after the last change.
const SETTINGS_SAVE_DELAY := 0.5

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
## Where a legend's parts draw (M6_PLAN.md §5.5): a part in the sky, such as the UFO's saucer, over
## the props and the car; the veil over them all; and the glows over the veil, which they light.
const SKY_Z := 1
const VEIL_Z := 2
const GLOW_Z := 3
## The veil is a square this many px from its centre to each side: wherever it is centred in the
## view, it covers the widest view of the world, 3278 × 1280 px at the smallest zoom.
const VEIL_HALF_SIZE := 4096.0
## What a legend's veil multiplies the world's colours by, at dusk and at night (Q5, Q8).
const VEIL_DUSK := Color8(170, 130, 190)
const VEIL_NIGHT := Color8(70, 80, 150)
## No flashing (M6_PLAN.md §5.6, E6, after WCAG 2.3.1). Light changes once it rises or falls by
## more than FLASH_CHANGE of white's light, or of pure red's for red light, as WCAG counts, even
## where glows add up past white. Where a glow glides past a point at its faint edge, the light
## there steps by less, as the canvas draws the nearest texel (S19). At no point of the world may it
## rise and fall more than FLASH_MAX times in FLASH_SECONDS, nor more than FLASH_RED_MAX times in
## all in saturated red, whose share of the colour is at least FLASH_RED_SHARE. No glow may cover
## FLASH_AREA px² of the world, a quarter of a 360 × 640 screen at zoom 1. The test reads the light
## every FLASH_GRID px.
const FLASH_CHANGE := 0.1
const FLASH_MAX := 3
const FLASH_SECONDS := 1.0
const FLASH_RED_SHARE := 0.8
const FLASH_RED_MAX := 1
const FLASH_AREA := 57600.0
const FLASH_GRID := 4
## Screen shake (CameraRig.shake): the offset at intensity 1, in screen pixels, which fades out over
## the shake, and its frequencies across and up the screen, in rad/s. They differ, so the camera
## moves in a figure rather than along a line.
const SHAKE_PX := 6.0
const SHAKE_FREQ_X := 47.0
const SHAKE_FREQ_Y := 31.0
## A crash's shake.
const CRASH_SHAKE := 0.5
const CRASH_SHAKE_SECONDS := 0.4

# The City's legends.
## The phantom bus (M6_PLAN.md §3.3): its beats, in s: the fog rolls in, the bus comes, the car
## boards it, the bus leaves. How far back it comes from, along the road, how far on it goes and
## how far from the car it stops, in tiles; and how much of it shows, as it's half see-through.
const PHANTOM_BUS_BEATS: Array[float] = [0.5, 0.9, 0.4, 0.7]
const PHANTOM_BUS_APPROACH_TILES := 3.0
const PHANTOM_BUS_LEAVE_TILES := 2.5
const PHANTOM_BUS_GAP_TILES := 0.4
const PHANTOM_BUS_ALPHA := 0.7

# Rural's legends.
## The UFO (M6_PLAN.md §3.3): its beats, in s: night falls, the saucer drops, its beam opens, the
## car floats up into it, and it zips off. How far it drops to its hover and where it zips to, in
## px, the zip to the side that the params' direction picks; how many times a second its rim's
## lights pass each point of its rim; and how much light its beam adds.
const UFO_BEATS: Array[float] = [0.5, 0.5, 0.4, 0.8, 0.4]
const UFO_DROP_PX := 160.0
const UFO_ZIP_PX := Vector2(240.0, -360.0)
const UFO_RIM_HZ := 2.0
const UFO_BEAM_ALPHA := 0.5

# The Meadows' legends.
## The fairy ring (M6_PLAN.md §3.3): its beats, in s: the toadstools sprout, their glows swell and
## the eyes open, the car dances, and the ring holds; and how much light each toadstool's glow adds.
const FAIRY_RING_BEATS: Array[float] = [0.6, 0.5, 0.9, 0.4]
const FAIRY_RING_GLOW_ALPHA := 0.6

# The Village's legends.
## The witch's hex (M6_PLAN.md §3.3): its beats, in s: the witch swoops in and circles the car,
## cackling; she points and hexes it; a puff of smoke hides it; and a jack-o'-lantern pops up where
## it stood as she flies off. Where she swoops in from and flies off to, in px from where she
## hovers, for a hex whose params' direction points to the right of the screen, mirrored for the
## left; and how much light the lantern's grin adds.
const WITCH_HEX_BEATS: Array[float] = [0.5, 0.5, 0.6, 0.8]
const WITCH_HEX_SWOOP_PX := Vector2(-140.0, -200.0)
const WITCH_HEX_FLY_OFF_PX := Vector2(260.0, -220.0)
const WITCH_HEX_GLOW_ALPHA := 0.7

# The Desert's legends.
## The death worm (M6_PLAN.md §3.3): its beats, in s: the ground trembles and ripples run through
## the sand to the car; a mound swells under it; the worm bursts up and swallows it; it dives back;
## and its crater stays. How far the ripples run from, in tiles; and what share of the params'
## intensity the trembling and the burst shake the camera with.
const DEATH_WORM_BEATS: Array[float] = [0.6, 0.4, 0.6, 0.6, 0.3]
const DEATH_WORM_BURROW_TILES := 1.75
const DEATH_WORM_TREMOR := 0.35
const DEATH_WORM_BURST := 1.0
