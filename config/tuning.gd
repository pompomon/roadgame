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
## only docs/M4.md K1's spare tile past the next needs that (docs/ROADGEN.md R6).
const BUFFER_REFILL_AT := 37
## Correct-path tiles kept behind the car's tile. Older tiles are freed with their branches, and a
## set piece with its last tile. With BUFFER_REFILL_AT and PROP_AHEAD, enough that no reference
## screen sees a tile, a set piece or a prop come or go (docs/M5.md L2). What reaches highest above
## a freed path tile is a straight-on dead end, DEAD_END_MAX_TILES rows above it: at
## GLOBAL_SPEED_CAP, 19 would leave its end 13 px below the tallest view, and 20 leaves 45
## (test_camera_rig.gd, docs/ROADGEN.md R6).
const BUFFER_BEHIND := 20
## Straight tiles before the first junction: path indices 0 to START_STRAIGHT_TILES - 1.
const START_STRAIGHT_TILES := 4
## Length range of a dead-end branch, in tiles (plan.md §3.3). With at least DEAD_END_MIN_TILES,
## its end is out of view on every reference screen as the car enters its junction, so that it
## looks like a road (docs/ROADGEN.md R4). Another dead end can cut it shorter (RoadGenerator).
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
## centreline (docs/M4.md K7). How fast the waves drift down the river, in tiles/s.
const BRIDGE_BANK := 0.5
const RIVER_REACH := 2.0
const WAVE_SPEED := 0.6
## Props (docs/M5.md §5.6). The screen row of each path tile gets its props once the car is
## PROP_AHEAD path tiles before it, on the ground of PROP_SPREAD road tiles either side of the path
## tile, and of PROP_VIEW_SPREAD either side of each of the PROP_AHEAD path tiles below it
## (PropLayout.span()). A prop's frame reaches at most PROP_MAX_SIZE.y pixels above its foot,
## PROP_MAX_SIZE.x / 2 either side of it and PROP_BELOW below it.
const PROP_AHEAD := 24
const PROP_SPREAD := 9
## The car is on one of those path tiles while the row may show ahead of it, and the tallest view
## reaches about 300 px across from the car: half its 360 px, LOOKAHEAD_PX's 43 across, and the
## camera's lag at GLOBAL_SPEED_CAP, 75. 3 tiles and a half reach 448 px. A long straight runs
## farther than PROP_SPREAD across the screen (SPEEDUP_PLAN.md §4.3).
const PROP_VIEW_SPREAD := 3
const PROP_MAX_SIZE := Vector2i(64, 72)
const PROP_BELOW := 8
## A see-through prop, such as the City's building (docs/VISUALS.md §5.9): its opacity where it
## would hide the car or a legend, as the tunnel's, which rises to 1 as their frames part by
## PROP_FADE_PX screen pixels, or as the car comes that far in front of it.
const PROP_SEE_THROUGH := 0.2
const PROP_FADE_PX := 48.0
## The props' lights (docs/DAYNIGHT.md §5.12): at night they glow LAMP_COLOR over the veil, which
## they light, LAMP_ALPHA at their centres, and the ground below a lamp LAMP_POOL_SHARE as brightly.
## They add to no channel more than the veil takes away from it, so they come on as the light
## fades, and nothing that they light clips to white.
const LAMP_COLOR := Color(1.0, 0.8, 0.45)
const LAMP_ALPHA := 0.55
const LAMP_POOL_SHARE := 0.4

## Car (IMPLEMENTATION_PLAN.md M4.2). Speeds are in tiles/s, accelerations in tiles/s².
const BASE_TOP_SPEED := 4.0
## Top-speed gain per tile driven in the run.
const TOP_SPEED_GROWTH := 0.0035
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
## What a pit stop repairs (docs/ENDGAME.md §5.15): half the car's health, what 1.4 to 2 seconds
## off the road cost, at the areas' 35 to 25 a second.
const PIT_STOP_HEAL := 50.0
## Skid marks (docs/M5.md §5.7): while the car brakes for a junction, a pair every SKID_SPACING
## tiles, SKID_REAR tiles behind its centre and SKID_TRACK tiles apart, at SKID_ALPHA. At most
## SKID_MARKS show.
const SKID_SPACING := 0.08
const SKID_REAR := 0.09
const SKID_TRACK := 0.18
const SKID_ALPHA := 0.5
const SKID_MARKS := 256
## The car's wheels (docs/VISUALS.md §5.1) show its sheet's next phase, a quarter turn on, each
## WHEEL_ROLL_TILES tiles it drives: at GLOBAL_SPEED_CAP, less than a phase a frame at 30 frames a
## second, so that down to 30 they show each phase. Below, a drawn frame rolls them a phase at most,
## and drops the rest of its drive (CarController._process()).
const WHEEL_ROLL_TILES := 0.25

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
## default volumes, the music, the ambience, the engine and one effect add up to 1 (docs/M5.md L29,
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
## The Book of Legends (docs/ENDGAME.md §5.10): a drag scrolls it once the finger has gone further
## than this many pixels of the view, so that a tap that wobbles less still opens a legend's page.
## Near Android's touch slop, 8 dp.
const BOOK_SCROLL_DEADZONE := 8
## How far an arrow key scrolls the Book, a legend's page or the Atlas, where the focus has nowhere
## to go that way: this share of what shows of it (MenuScreen.scroll_by_key()). A mouse wheel's
## notch scrolls an eighth too, in Godot 4.7.2's ScrollContainer (docs/ENDGAME.md W28).
const BOOK_KEY_SCROLL := 0.125

## The tutorial (docs/TUTORIAL.md §5): a road in the City's look, where every wrong exit loops back
## to the path and nothing ends the run. It ends after TUTORIAL_STREAK correct turns in a row. In
## it, the car heals to START_HEALTH in TUTORIAL_HEAL_SECONDS of driving on the road, and once it
## drives TUTORIAL_RESCUE_TILES off the road in one go, it is put back on the path.
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
## How much a disaster that the player has seen, which the Book of Legends shows as found, weighs
## in its area's pick, against 1 for one not seen yet (docs/POOLS.md Q2): half as likely as each
## unseen one.
const SEEN_DISASTER_WEIGHT := 0.5
## The end of the road (docs/ENDGAME.md §5.1, §5.2): the finish's set piece, such as the pier, is
## FINISH_TILES path tiles long. A car that reaches it rolls to a stop ARRIVE_STOP_SHORT tiles
## before the centre of its last tile, or sooner, within ARRIVE_ROLL_SECONDS, if it came slowly.
## The arrival screen shows ARRIVAL_SECONDS after it reached the finish: after the car has stopped,
## as CRASH_SECONDS is after STOP_SECONDS.
const FINISH_TILES := 8
const ARRIVE_STOP_SHORT := 0.5
const ARRIVE_ROLL_SECONDS := 4.0
const ARRIVAL_SECONDS := 5.0
## The arrival's scene (docs/ENDGAME.md §5.8). The sun sets: the clock stands at ARRIVAL_HOUR,
## LIGHT_DUSK's key. The camera's target eases from the car to the welcome, in 1 / ARRIVAL_PAN_RATE
## seconds, and keeps the car's body in view with ARRIVAL_MARGIN_PX round it. The welcome is a grid
## of the legends' stills, an area a row and a slot of its pool a column, as the Book has them,
## WELCOME_CELL px apart and centred WELCOME_AHEAD tiles past the pier's end and WELCOME_ASIDE tiles
## across it, as SetPiece.point() measures: below 0, toward its far side. The 96-px worm stands
## clear of the still above it, and the grid with the car fits the base view, 360 × 640; where the
## view is smaller, 320 px high at zoom 2, the camera zooms out (CameraRig.arrive()). Once the pan
## has ended, each still collected fades in over WELCOME_FADE seconds, WELCOME_STEP after the one
## before. A still whose frame is smaller than STILL_MIN_SIDE px, such as the Fairy Ring's
## toadstool, is scaled up by a whole number, to read at 360 × 640.
const ARRIVAL_HOUR := 18.5
const ARRIVAL_PAN_RATE := 1.0
const ARRIVAL_MARGIN_PX := 16.0
const WELCOME_CELL := Vector2(72.0, 64.0)
const WELCOME_AHEAD := 2.7
const WELCOME_ASIDE := -0.4
const WELCOME_DELAY := 1.0 / ARRIVAL_PAN_RATE
const WELCOME_FADE := 0.5
const WELCOME_STEP := 0.1
const STILL_MIN_SIDE := 30.0
## The Vanishing Hitchhiker (docs/ENDGAME.md §5.17) stands HITCHHIKER_ASIDE tiles across from the
## centre of the straight that she stands by, as SetPiece.point() measures: below 0, toward its far
## side, just off the road, whose half width is ROAD_HALF_WIDTH. Once the car has passed her, she
## fades away in HITCHHIKER_FADE_SECONDS.
const HITCHHIKER_ASIDE := -0.42
const HITCHHIKER_FADE_SECONDS := 0.5
## Where a legend's parts draw (docs/M6.md §5.5): a part in the sky, such as the UFO's saucer, over
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
## No flashing (docs/M6.md §5.6, E6, after WCAG 2.3.1). Light changes once it rises or falls by
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

## Day and night (docs/DAYNIGHT.md §5.2): what Daylight multiplies the world by at the key hours of
## a zone's day, LIGHT_HOURS, from 0 to 24, in LIGHT_COLORS. Between two keys each channel eases
## from one to the other, and from the last key the light runs on past midnight to the first. A
## zone's clock starts at DAY_START_HOUR as the car enters it. The light shown changes by at most
## LIGHT_MAX_RATE a second in each channel, also when a zone sets the clock back (§5.3).
const DAY_START_HOUR := 7.0
const LIGHT_DAWN := Color(0.92, 0.74, 0.78)
const LIGHT_DUSK := Color(1.0, 0.72, 0.52)
const LIGHT_NIGHT := Color(0.42, 0.48, 0.72)
const LIGHT_HOURS: Array[float] = [4.5, 6.0, 7.0, 17.0, 18.5, 20.0]
const LIGHT_COLORS: Array[Color] = [
	LIGHT_NIGHT, LIGHT_DAWN, Color.WHITE, Color.WHITE, LIGHT_DUSK, LIGHT_NIGHT
]
const LIGHT_MAX_RATE := 0.25
## Shadows (docs/DAYNIGHT.md §5.11). The sun is up from SUN_RISE_HOUR to SUN_SET_HOUR, and the moon
## the rest of the day. Each rises on the screen's left, SKY_RISE_ANGLE being the way toward it in
## tile space, stands highest at the screen's top, SUN_HIGHEST or MOON_HIGHEST above the ground,
## and sets on its right: so shadows fall beside what casts them or in front of it, where they
## show, never behind it. They are black, SUN_SHADOW_ALPHA or MOON_SHADOW_ALPHA, and fade in as the
## sun or the moon rises from SHADOW_FADE_FROM to SHADOW_FADE_TO above the ground, and out as it
## sets. A shadow is at most SHADOW_LONGEST times as long as what casts it is tall. The shadows
## shown move by at most SHADOW_MAX_RATE a second, in screen pixels a pixel of height, and their
## alpha changes by at most SHADOW_ALPHA_RATE a second: shadows that must move faster, as when a
## zone sets the clock back, fade out and in.
const SUN_RISE_HOUR := 6.0
const SUN_SET_HOUR := 18.0
const SKY_RISE_ANGLE := deg_to_rad(135.0)
const SUN_HIGHEST := deg_to_rad(60.0)
const MOON_HIGHEST := deg_to_rad(45.0)
const SUN_SHADOW_ALPHA := 0.3
const MOON_SHADOW_ALPHA := 0.15
const SHADOW_FADE_FROM := deg_to_rad(3.0)
const SHADOW_FADE_TO := deg_to_rad(20.0)
const SHADOW_LONGEST := 2.5
const SHADOW_MAX_RATE := 1.5
const SHADOW_ALPHA_RATE := 0.25

# The City's legends.
## The phantom bus (docs/M6.md §3.3): its beats, in s: the fog rolls in, the bus comes, the car
## boards it, the bus leaves. How far back it comes from, along the road, how far on it goes and
## how far from the car it stops, in tiles; and how much of it shows, as it's half see-through.
const PHANTOM_BUS_BEATS: Array[float] = [0.5, 0.9, 0.4, 0.7]
const PHANTOM_BUS_APPROACH_TILES := 3.0
const PHANTOM_BUS_LEAVE_TILES := 2.5
const PHANTOM_BUS_GAP_TILES := 0.4
const PHANTOM_BUS_ALPHA := 0.7
## The Mothman (docs/POOLS.md §5.4): its beats, in s: it perches, it unfurls its wings, it swoops
## over to the car, and it lifts the car out of view. How far ahead of the car it perches, along
## the car's road, and how far off the road's middle, in tiles; how far it lifts the car, in px, up
## and to the side that the params' direction picks; and how much light its eyes add.
const MOTHMAN_BEATS: Array[float] = [0.5, 0.5, 0.6, 0.8]
const MOTHMAN_AHEAD_TILES := 1.5
const MOTHMAN_SIDE_TILES := 0.6
const MOTHMAN_LIFT_PX := Vector2(80.0, -480.0)
const MOTHMAN_EYES_ALPHA := 0.8
## The Grim Reaper (docs/POOLS.md §5.4): its beats, in s: it steps out at the roadside, it beckons,
## the road opens into a grave, and the car sinks into it. How far ahead of the car the grave
## opens, to its middle, along the car's road; how far off the road's middle the Reaper stands,
## beside the grave; and how much farther off it steps out from, in tiles.
const GRIM_REAPER_BEATS: Array[float] = [0.6, 0.5, 0.6, 0.7]
const GRIM_REAPER_AHEAD_TILES := 0.55
const GRIM_REAPER_SIDE_TILES := 0.75
const GRIM_REAPER_STEP_TILES := 0.4

# Rural's legends.
## The UFO (docs/M6.md §3.3): its beats, in s: night falls, the saucer drops, its beam opens, the
## car floats up into it, and it zips off. How far it drops to its hover and where it zips to, in
## px, the zip to the side that the params' direction picks; how many times a second its rim's
## lights pass each point of its rim; and how much light its beam adds.
const UFO_BEATS: Array[float] = [0.5, 0.5, 0.4, 0.8, 0.4]
const UFO_DROP_PX := 160.0
const UFO_ZIP_PX := Vector2(240.0, -360.0)
const UFO_RIM_HZ := 2.0
const UFO_BEAM_ALPHA := 0.5
## The scarecrow (docs/POOLS.md §5.4): its beats, in s: it turns its head to the car, its crows
## rise from its arms, they flock over the car, and they carry it off. How far ahead of the car it
## stands, along the car's road, and how far off the road's middle, in tiles; how far its crows
## carry the car, in px, to the side that the params' direction picks and up the screen, over the
## fields; and how high they hold it off the ground, in px.
const SCARECROW_BEATS: Array[float] = [0.6, 0.4, 0.8, 0.7]
const SCARECROW_AHEAD_TILES := 1.25
const SCARECROW_SIDE_TILES := 0.75
const SCARECROW_CARRY_PX := Vector2(320.0, -80.0)
const SCARECROW_LIFT_PX := 10.0
## The Headless Horseman (docs/POOLS.md §5.4): his beats, in s: he gallops along the road to the
## car, he raises a ball of ghost-fire, he hurls it at the car, and it kindles the car as he gallops
## off. How far ahead of the car, along the car's road, he gallops in from and off to, and where he
## stops, on the road's middle, in tiles; how high the ghost-fire arcs on its way to the car, in px,
## and at most, on a short throw, what share of the way; and how much light it adds.
const HEADLESS_HORSEMAN_BEATS: Array[float] = [0.6, 0.4, 0.5, 0.9]
const HEADLESS_HORSEMAN_FROM_TILES := 4.0
const HEADLESS_HORSEMAN_STOP_TILES := 1.5
const HEADLESS_HORSEMAN_ARC_PX := 16.0
const HEADLESS_HORSEMAN_ARC_SHARE := 0.2
const HEADLESS_HORSEMAN_GLOW_ALPHA := 0.8

# The Meadows' legends.
## The fairy ring (docs/M6.md §3.3): its beats, in s: the toadstools sprout, their glows swell and
## the eyes open, the car dances, and the ring holds; and how much light each toadstool's glow adds.
const FAIRY_RING_BEATS: Array[float] = [0.6, 0.5, 0.9, 0.4]
const FAIRY_RING_GLOW_ALPHA := 0.6
## The kelpie (docs/POOLS.md §5.4): its beats, in s: it rises from its pool, it waits, dripping, the
## car rolls up to its side, and it plunges back in with the car. How far ahead of the car its pool
## lies, along the car's road, and how far off the road's middle, in tiles.
const KELPIE_BEATS: Array[float] = [0.6, 0.5, 0.5, 0.8]
const KELPIE_AHEAD_TILES := 1.0
const KELPIE_SIDE_TILES := 0.8
## The Will-o'-the-Wisp (docs/POOLS.md §5.4): its beats, in s: night falls and the wisps glimmer
## round the car, they circle it, closing in, it shrinks into a light, and it drifts off with them
## as they fade. How many turns a second they circle at most; how far they drift, in px, up the
## screen and to the side that the params' direction picks; and how much light each adds.
const WILL_O_WISP_BEATS: Array[float] = [0.6, 0.8, 0.5, 0.6]
const WILL_O_WISP_CIRCLE_HZ := 0.4
const WILL_O_WISP_DRIFT_PX := Vector2(40.0, -56.0)
const WILL_O_WISP_ALPHA := 0.7

# The Village's legends.
## The witch's hex (docs/M6.md §3.3): its beats, in s: the witch swoops in and circles the car,
## cackling; she points and hexes it; a puff of smoke hides it; and a jack-o'-lantern pops up where
## it stood as she flies off. Where she swoops in from and flies off to, in px from where she
## hovers, for a hex whose params' direction points to the right of the screen, mirrored for the
## left; and how much light the lantern's grin adds.
const WITCH_HEX_BEATS: Array[float] = [0.5, 0.5, 0.6, 0.8]
const WITCH_HEX_SWOOP_PX := Vector2(-140.0, -200.0)
const WITCH_HEX_FLY_OFF_PX := Vector2(260.0, -220.0)
const WITCH_HEX_GLOW_ALPHA := 0.7
## Frau Holle's well (docs/POOLS.md §5.4): its beats, in s: snow starts to fall round the car, a
## stone well rises by the road, the car tips towards it, and it falls in as the snow settles on the
## well. How far off the road's middle the well stands, beside the car, in tiles; how far the car
## tips over, and turns on as it falls, in radians; and how high it hops over the well's rim, in px.
const FRAU_HOLLE_BEATS: Array[float] = [0.6, 0.5, 0.6, 0.7]
const FRAU_HOLLE_SIDE_TILES := 0.75
const FRAU_HOLLE_TIP := 0.5
const FRAU_HOLLE_TUMBLE := 1.5
const FRAU_HOLLE_HOP_PX := 24.0
## Baba Yaga's hut (docs/POOLS.md §5.4): its beats, in s: it stomps along the road to the car on its
## chicken legs, it turns its front to the car, it crouches and its door opens, and the car rolls in
## as the door shuts behind it and the hut stomps off. How far off the road's middle it stops,
## beside the car, in tiles; and how far along the road it stomps in from, and stomps off, in tiles:
## eight strides in, and five off, a stride past its prints, so that it has left them all before it
## is gone (BabaYaga.STRIDE_TILES).
const BABA_YAGA_BEATS: Array[float] = [0.6, 0.5, 0.5, 0.8]
const BABA_YAGA_SIDE_TILES := 0.75
const BABA_YAGA_FROM_TILES := 2.5
const BABA_YAGA_OFF_TILES := 1.5625

# The Desert's legends.
## The death worm (docs/M6.md §3.3): its beats, in s: the ground trembles and ripples run through
## the sand to the car; a mound swells under it; the worm bursts up and swallows it; it dives back;
## and its crater stays. How far the ripples run from, in tiles; and what share of the params'
## intensity the trembling and the burst shake the camera with.
const DEATH_WORM_BEATS: Array[float] = [0.6, 0.4, 0.6, 0.6, 0.3]
const DEATH_WORM_BURROW_TILES := 1.75
const DEATH_WORM_TREMOR := 0.35
const DEATH_WORM_BURST := 1.0
## The Marfa Lights (docs/POOLS.md §5.4): their beats, in s: they glimmer far off over the desert,
## they dance, they come close round the car, and the car follows them off the road until it's
## gone. Where they glimmer, in px from the car's ground point, up-screen of it and to the side that
## the params' direction picks; how far they drift back across as they dance, in px; how high they
## bob each way, in px, and how many times a second; and how much light each adds.
const MARFA_LIGHTS_BEATS: Array[float] = [0.6, 0.8, 0.5, 0.6]
const MARFA_LIGHTS_FAR_PX := Vector2(48.0, -160.0)
const MARFA_LIGHTS_DRIFT_PX := 28.0
const MARFA_LIGHTS_BOB_PX := 6.0
const MARFA_LIGHTS_DANCE_HZ := 1.0
const MARFA_LIGHTS_ALPHA := 0.8
## The chupacabra (docs/POOLS.md §5.4): its beats, in s: it creeps out of the scrub, it crouches by
## the car, it pounces onto it, and it drains it and slinks off. How far down-screen across the
## car's road it creeps out from and slinks off to, in tiles: from the road's middle, or from the
## car if it stopped down-screen of the middle or off any road (Chupacabra.far()); and where it
## crouches, in tiles from the car's ground point, the same way. How much higher than the straight
## way it leaps, at the leap's middle, in px.
const CHUPACABRA_BEATS: Array[float] = [0.6, 0.4, 0.5, 0.9]
const CHUPACABRA_FROM_TILES := 1.2
const CHUPACABRA_BY_TILES := 0.6
const CHUPACABRA_LEAP_PX := 14.0
