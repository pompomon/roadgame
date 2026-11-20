# Headlights, Resting Windmills and the Meadows' Grass — Detailed Plan

Status: proposed. This plan's PR waits for the owner, who answers Q1–Q12 or takes their defaults, and approves the plan by merging it (§3, §7) · 2026-11-20 · Scope: from dusk until sunrise the car's headlights light the road ahead of it, and nothing else; the windmills' sails rest at night; grass sways in the Meadows. Nothing else that shows changes, but the Meadows' frames by day, by their grass (P2). This plan calls the work HL. It comes after EG (#84, #101–#115), beside SP's plan (#116), and before M7.

The owner asked: "Explore the codebase and create a detailed implementation plan for visual improvements: 1. Add headlights to the car, which turn on from dusk till sunrise. They highlight the road, but not the objects around. 2. Stop windmills at night. 3. Add animated grass to the Meadows. Ask clarifying questions if needed". The plan was written while nobody could answer, so each question that it raised is a Q# in §3, with the default that the prototype follows. The owner answers them on this plan's PR.

**The headlights.** The car has none, and at night `Daylight`'s veil darkens the road as it darkens the rest (B1; docs/DAYNIGHT.md Q5). PR 1 gives the road a material of its own, `Headlights`. From dusk, the light's 18:30 key, until the sun rises at 06:00 (`DayCycle.night_at()`, B2), while the car drives, it draws the road brighter in a cone ahead of the car's lamps, so that the veil leaves the road there lighter: at most `HEADLIGHT_SHARE`, 0.6, of the way back to its day colour, in a warm white (§5.3). All that is drawn on the road after it, the car, the props, the skid marks and the legends, hides the light under it where it is opaque, and the ground beside the road isn't the road: so only the road is lit (B3, B4). They turn on and off in half a second, stay on into a zone's morning until its light has come (B7), and go out once the run is over (B10). Only the material's parameters change, so nothing is redrawn on the Web (B17).

**The windmills.** Every animated prop turns by one clock, day and night (B5). PR 2 gives `PropDef` a flag, `rests_at_night`, which only the windmill sets. Such a prop animates by a clock of its own, which slows to a stop over `PROP_REST_SECONDS`, 3 s, as the night falls, and comes back up to speed as the sun rises. A run that starts at night starts with the sails still (§5.5).

**The grass.** The Meadows have trees, pines, bushes, flowers, rocks and ponds, but no grass (B6). PR 3 adds a tuft of six blades, 14 × 9 px in the Meadows' two greens, that sways in 4 frames at 3 a second. It is the Meadows' last prop, at 0.05, so it stands only on ground cells that showed nothing, and the other props stand where they stood (B14): 12.6 to 13.0 tufts a view on average, 22 at most (P4).

**The cost.** The Meadows' rows hold about 650 animated props, where `main`'s hold about 33. `PropScatter.update()` worked out each one's frame every frame: 616 µs a frame, against `main`'s 94. PR 3 looks at a prop's frame only once its next frame has come: 184 µs (B12, P4). Movie Maker's render times, where each build ran more than once, differ from `main`'s by less than one build's runs differ from each other (P3), and GUT, run alone locally, takes 140.5 s on average against `main`'s 133.7 s, 5% more (P10).

**Verified locally and in CI.** Every file of PRs 1–3 was built first on branch `hl/prototype`, from `main` at 4a50bb2, which never gets a PR: the headlights, 3d40104, the windmills' rest, 9b4d908, and the grass, c0ea19a, then §4.6's six fixes. It passed the five checks with Godot 4.7.2, locally and in CI, and so did each PR's tree, rebuilt as §4.1 says, locally (§6.1), with the warnings check (§6.3). Each negative case, with the whole suite, failed the tests it names and nothing else (§6.2). Probes measured the frames by day and at night, the lit pixels against the road's mask, the cost, the Web, and the merges with SP's prototype and after each squash (§6.5).

- Godot 4.7.2-stable (4.7.2.stable.official.ed1daf0bf), in CI's image and locally
- GUT 9.7.1
- gdtoolkit 4.5.0 on Python 3.12.3, in CI's `lint` job and locally; shellcheck only in CI (§6.1)
- Playwright 1.66.0-alpha-2026-11-09 for the Web (§6.4)

**Precedence.** For HL, this document replaces docs/DAYNIGHT.md Q5's "no headlights" (:42), the Light rule of `AGENTS.md` (:52) and of `.github/instructions/light.instructions.md` (:9), and docs/M5.md §5.6 (:102) on how props animate, wherever it marks a difference with **Δ** and its finding (B#, §2). This plan's PR amends the two rules (Q11, §5.7). PR 4 replaces this plan with `docs/HEADLIGHTS.md`, and notes the changes in DAYNIGHT and M5 (§4.4).

**Reference code.** This plan has no appendices. Each PR cherry-picks its commits from `hl/prototype`, at 8c02110: PR 1 3d40104 and d4fc744; PR 2 9b4d908, e12562a, 8e82633 and b337183; PR 3 c0ea19a, eac39f8 and 8c02110 (§4.1). With them each PR's tree is this plan's branch with the prototype's files. Its code tree, the PR's tree but for this plan's three files, is 90be123, 003c32b, and 8c02110's own, 7f2fd4c.

**Prerequisites.** M0–M6 and the seven plans of their own that `AGENTS.md` §1 lists are merged, and so are EG's summary and learnings (#114, #115); `main` is at 4a50bb2. SP's plan, #116, is open. Its prototype, `sp/prototype` at 98ffdd5, changes 4 of HL's files, `config/tuning.gd`, `areas/meadows.tres`, `test_daylight_run.gd` and `test_prop_scatter.gd`, at other lines: it merges with 8c02110 cleanly, and the five checks pass on the merge (P8). Its days of 60 s bring the night sooner (§8). M7 hasn't started; §9 has notes for it. No repository settings change.

Contents:
1. Goal and exit criteria
2. Review findings
3. Decisions and open questions
4. Work breakdown (4 PRs)
5. Design
6. Verification
7. Owner actions
8. Risks
9. Notes for later work

---

## 1. Goal and exit criteria

Goal: from dusk until sunrise the car's headlights light the road ahead of it, and nothing else; the windmills' sails stand still at night; grass sways in the Meadows. Nothing else changes: the road by day, the other props, how the car drives, the disasters, the screens, and what a seed plays. The light stays visual only: no gameplay or audio code reads `DayCycle`.

| # | Exit criterion | Checked by |
|---|---|---|
| E1 | The night (B2; Q2). `DayCycle.night_at(hour)` is true from `DUSK_HOUR`, 18.5, the light's dusk key, until `SUN_RISE_HOUR`, 6, round midnight, for any hour, past 24 or below 0 | `test_day_cycle.gd`: `test_the_night_is_from_dusk_until_sunrise` (*night* below) |
| E2 | On and off (B7, B10; Q2, Q3). While a zone's clock is in the night and the run is on, the headlights turn on, from 0 to 1 in `HEADLIGHT_SWITCH_SECONDS`, 0.5 s, and otherwise off as fast. Once on, they stay on while the light shown catches up with the hour's, and turn off once it has come outside the night; entered before dusk, they stay off. So a zone entered by night whose clock starts by day, at 07:00 as each does unless `--hour=` sets it, never dims the road in the cone; one that `--hour=` starts at 06:00–07:00 or 17:00–18:30, in a tinted light, can dim it to that light, if the light comes outside the night, as each sunrise does (§5.4). They are off without a clock or a car, and once the run is over, after a disaster, a crash or the arrival; braking and off the road they stay on | `test_headlights.gd`: `test_on_from_dusk_until_sunrise` (*on*), `test_they_turn_on_and_off_in_the_switch_time` (*switch*), `test_into_a_zones_morning_they_stay_as_they_were_until_its_light_has_come` (*hold*), `test_off_without_a_clock_or_a_car_and_once_the_run_is_over` (*off*) |
| E3 | The light given back (B1, B8; Q6). With the headlights on, where the cone is brightest, under the veil's light `kept`, the road is drawn at `1 + gain` times its colour, so that the veil leaves `kept + HEADLIGHT_SHARE × HEADLIGHT_COLOR × (1 − kept)` of it in each channel, but where the colour so brightened passes 1 and clips (B8): never lighter than by day, and by day, when the veil keeps all, just as before. Off, the gain is 0. A channel that the veil keeps whole or blacks out gets nothing | `test_headlights.gd`: `test_the_road_in_the_cone_shows_a_share_of_its_day_light` (*share*); *switch*'s gain |
| E4 | The cone (B11, B13; Q5). Its apex is at the car's lamps, `HEADLIGHT_FRONT` tiles ahead of its centre. It lights 1 from there to `HEADLIGHT_DIM_FROM` of `HEADLIGHT_REACH`, 2.5 tiles, dims to 0 at the reach, and lights nothing behind the lamps or outside its half width, `HEADLIGHT_HALF_WIDTH` plus `HEADLIGHT_SPREAD` a tile ahead; whichever way the car heads and wherever World is on the canvas. The shader's parameters are those that `lit()` reads | `test_headlights.gd`: `test_the_cone_lights_the_road_ahead_of_the_car` (*cone*), `test_the_material_shows_the_cone_as_lit_works_it_out` (*material*) |
| E5 | The road alone (B3, B4; Q1, Q4). In the main scene the road's material is the headlights', and nothing else in World has it. At 22:00 they are on, with the light's gain, and aimed at the car's lamps; by day off, with no gain; on again at night; off once the run is over. In Movie Maker's frames at 22:00, each pixel that the headlights change is within the road's footprint, none is darker, and by day no frame of the City or Rural changes (P1, P2) | `test_daylight_run.gd`: `test_the_headlights_light_the_road_from_dusk_until_the_run_ends` (*lights*); P1, P2 |
| E6 | Visual only (B9). No gameplay or audio code reads `DayCycle`; a run plays the same at any hour; `smoke.sh` prints `main`'s line | `test_daylight_run.gd`: `test_the_light_changes_nothing_but_the_view` (*view*), `main`'s; `smoke.sh`: `autopilot: tile 165, turns 35, area rural` |
| E7 | The windmills rest (B5; Q8, Q9). A `PropDef` with `rests_at_night` animates by the scatter's rest clock, which runs at 1 by day and 0 at night, by `night_at()`, and moves between them over `PROP_REST_SECONDS`, 3 s: its frames change less each second, a frame at a time, then not at all, and start again as gently. A run that starts at night starts with them still; without a clock they never rest. The other animated props go on. Only the windmill rests, and only a prop that animates may | `test_prop_scatter.gd`: `test_props_that_rest_at_night_slow_to_a_stop_and_start_again_by_day` (*rest*), `test_props_that_break_the_contract_are_errors_and_do_not_show` (*contract*); `test_daylight_run.gd`: `test_the_windmills_rest_by_the_zones_clock` (*windmills*) |
| E8 | Frames by their clock (B12, B16). `update()` looks at a prop's frame again only once its next frame starts, yet each prop shows its clock's frame, at odd times and frame rates; an update sets no prop's frame before its next starts, by day or at rest; the props that the pier takes away stop animating, resting or not | `test_prop_scatter.gd`: `test_each_prop_shows_the_frame_of_its_clock_though_updates_look_only_at_frames_that_start` (*frames*), `test_an_update_sets_no_frame_before_the_next_starts` (*guard*), `test_the_props_that_the_pier_takes_away_stop_animating` (*pier*) |
| E9 | The grass (B6, B14; Q10). The Meadows' last prop, `grass`, sways: each frame other than the one before. Its 4 frames at 3 a second, its density, 0.05, and that it has no outline and no shadow are values in `grass.tres` and `make_props.gd`. Last in the Meadows' picker, it takes a 0.05-wide band of the hashes past the others': on average 0.05 of the one-cell lots pick it, only lots where nothing stood, and it shows on each where a tuft wouldn't touch the road; each other prop stands where it stood without it, in the same phase | `test_prop_art.gd`: `test_the_meadows_grass_sways` (*sways*), `test_each_frame_is_cropped_to_its_props_pixels_apart_from_the_others` (*crop*), `test_each_area_has_six_to_ten_props_some_animated` (*sums*); `test_prop_layout.gd`: `test_the_meadows_grass_takes_only_ground_that_showed_nothing` (*grass layout*); review, for the values |
| E10 | Everything else stands (B14). By day Movie Maker's frames of the City and Rural are `main`'s bytes, and the Meadows' differ by their grass and the sheet's new width (P2). PR 3's fix changes no frame (P5) | P2, P5; *view*; `smoke.sh` |
| E11 | The cost (B12). In the Meadows, `PropScatter.update()` takes at most about twice `main`'s time a frame (P4); Movie Maker's render times differ from `main`'s by less than one build's runs differ from each other: in the Meadows by day, on average 0.7 ms a frame more on the CPU and 0.6 on the GPU, where the head's three runs differ by 1.1 and 1.4 ms (P3); GUT's time, run alone locally, on average within 7% of `main`'s (5.1% in P10), and in CI, where `main`'s two runs differ by 51 s, no longer than the longer (P10). On the Fold4, the frame rate in the Meadows is read, from an APK that prints it, not a blocker (IP :203; §6.4) | P3, P4, P10; E12 |
| E12 | Manual, on the Web in Chrome and Firefox and on both of the Fold4's screens and through a fold (§6.4): at night the cone lights the road ahead of the car through turns, the tunnel and the bridge, and nothing else; it fades on at dusk, stays on into a zone's morning until its light has come, and fades out as the run ends; the windmills slow to a stop at dusk, and turn again at dawn; pausing and leaving the app keep both as they were; the grass sways in the Meadows, by day and at night; nothing flickers; no error. The APK reaches the tunnel only at dusk and the bridge by day, so on the Fold4 they are seen at night in its Chrome | §6.4: the Web on each PR's build, by an agent; the Fold4 is the owner's |
| E13 | Docs (B9). This plan's PR: `AGENTS.md`'s and the light instructions' Light rules (§5.7). PR 4: `docs/HEADLIGHTS.md` replaces this plan, with its row in `docs/README.md`; the "now" notes in docs/DAYNIGHT.md Q5 and docs/M5.md §5.6; `AGENTS.md`'s IDs and state; IP's M7 notes; the learnings (docs/agents/planning.md §7) | Review |
| E14 | All five required checks are green on each PR, with §4's counts, and `smoke.sh` prints no error line. Each negative case makes the tests it names fail, and nothing else (§6.2), and the warnings check finds no new warning (§6.3) | PR checks; §6.2 and §6.3, run locally with Godot 4.7.2 on each PR's head |

---

## 2. Review findings

DN gave the world its light, a veil that multiplies all below it by the hour's colour (docs/DAYNIGHT.md §5.5), and M5 its props (docs/M5.md §5.6); nothing since has changed either as HL does. **High:** what the owner asked for can't show, or shows wrong. **Medium:** fragile, or missing from the tests. **Low:** clarity, cost or polish. Line numbers are `main`'s, at 4a50bb2, unless they say otherwise.

### High

| # | Finding | Evidence | Fix |
|---|---|---|---|
| B1 | The car has no headlights, and DN chose none | docs/DAYNIGHT.md:42, Q5: "no headlights". `Daylight`'s veil, a `ViewVeil` drawn with `BLEND_MODE_MUL` at `VEIL_Z` (`view_veil.gd`:21–23), multiplies all of World by the hour's light: at night by `LIGHT_NIGHT`, (0.42, 0.48, 0.72) (`tuning.gd`:250), the road as the rest | `Headlights`, the road's material (§5.2, §5.3) **Δ docs/DAYNIGHT.md Q5** |
| B2 | Nothing says when the night is | `DayCycle` has `light_at()` (:90) and a private `_sun_up()` (:138), 06:00 to 18:00. The light's keys (`tuning.gd`:249–253) put dusk at 18.5, and the night's light comes at 20 | `DayCycle.night_at()`: from `DUSK_HOUR`, the dusk key, until `SUN_RISE_HOUR`, round midnight (§5.1) |
| B3 | The ways that light a 2D scene would light the props too, or break the light's rule | `.github/instructions/light.instructions.md`:9: no `CanvasModulate`, `Light2D` or World's `modulate`, and above `VEIL_Z` only ADD glows. A `Light2D` lights each node in its cull mask, and the road shares World's canvas with the props and the car; an ADD glow above the veil lights all below it in its shape, props included | The road's own material, under the veil (Q4, §5.2) |
| B4 | The road, but not the objects around | `world.tscn` draws `Ground` (:22), `SetPieces` (:25), `RoadLayer` (:28), `Skids` (:31), `Shadows` (:34), `DisasterLayer` (:39), `Props` (:42), with the car, and `Lamps` (:46), in that order; the tunnel's rock and the near railings of the bridge and the pier draw over the car, at `z_index` 1 (`tunnel.gd`:6, `bridge.gd`:6–7, `pier.gd`:10). A light drawn with the road, before the rest, is hidden wherever something stands on it | The material lights only `RoadLayer`'s own pixels; what is drawn after it hides the light under it, and the ground stays dark (§5.2, §5.4; P1) |
| B5 | The windmills turn all night | `PropScatter.update()` animates every prop by one `_clock` (`prop_scatter.gd`:102–110; `_set_frame()`, :296), and World's `_process()` gives it no hour (`world_renderer.gd`:133–137) | `PropDef.rests_at_night`, and a rest clock that the zone's night stops (§5.5) **Δ docs/M5.md §5.6** |
| B6 | The Meadows have no grass | `make_props.gd`:45–53 gives them a tree, a pine, a bush, flowers, a rock and a pond. Its `dune_grass` (:74) is the Coast's. `plan.md`:122: "Green meadows and pastures" | A tuft that sways, the Meadows' last prop (§5.6) |

### Medium

| # | Finding | Evidence | Fix |
|---|---|---|---|
| B7 | Into a zone's morning the cone would dim before the light came | Each zone starts its clock at `DAY_START_HOUR`, 07:00 (docs/DAYNIGHT.md §5.4), and the light shown catches up with the hour's at `LIGHT_MAX_RATE`, 0.25 a second (§5.3): from the night's to white in about 2.3 s. The City's 34 turns take the autopilot 58–59 s (`smoke.sh`'s seed), so it enters Rural at about 18:40, by night. Off at once, the road in the cone would fall from 0.768 of its red to 0.545 in 0.5 s, while the light rose 0.125, then lighten again (P7) | Once on, they stay on while the light catches up; entered before dusk they stay off (§5.4). d4fc744 |
| B8 | The road's lines clip | The shader multiplies the road's colour by 1 + gain, and the canvas is 8-bit, so before the veil a channel above 1 / (1 + gain) clips at 1: under the veil no pixel shows more than the light `kept`. At `LIGHT_NIGHT` the lines, 11.25% of the `ROAD` row's opaque pixels, clip in the cone, and show less than meant, by up to 80 levels a channel, and bluer (§5.3, P6) | Accepted for a cone that shows (Q6): a clipped line is still lit, and never lighter than by day. Only a share of 0.0326 or less clips nothing in a run, and it barely shows (§5.3) |
| B9 | The rules forbid it as they stand | `AGENTS.md`:52: "Draw the world as by day: `Daylight` darkens it by the zone's hour." The light instructions (:9) say the same, and docs/DAYNIGHT.md Q5 chose no headlights | This plan's PR amends both rules (Q11, §5.7); PR 4 notes Q5's change |
| B10 | The arrival holds the clock at dusk | `ARRIVAL_HOUR` is 18.5 (`tuning.gd`:190), `DUSK_HOUR`, which `night_at()` counts as night: at the pier the cone would light the road, and the windmills' clock would rest (`ui/main.gd`:339, docs/ENDGAME.md §5.8) | Off once the run is over, whatever the hour (Q3; §5.1). The Coast has no windmills |
| B11 | GUT can't see the shader | Headless, Godot draws nothing, so no test reads a lit pixel | `Headlights.lit()` works out the cone as the shader does, from the parameters given to it; *material* checks that the shader has them. P1 checks real frames (§5.2) |
| B12 | The grass's cost | c0ea19a's grass took the Meadows' animated props in the rows from about 33 to about 650, 972 at most, and `update()` from 94 µs a frame to 616 µs (P4) | `update()` looks at a prop's frame only once its next frame has come: 184 µs (§5.6). eac39f8, and 8c02110's test |
| B13 | The shader works in canvas pixels, the car in tiles | `MODEL_MATRIX` takes the road's vertices to the canvas, and the car's position and heading are in tiles: a cone worked out in World's pixels would be off by World's place on the canvas | `aim()` turns the car's axis into rows that take a canvas offset to tiles, through World's global transform and `Iso.world_to_tile()` (§5.2) |
| B14 | The grass must not move the other props | `PropLayout.pick()` (`prop_layout.gd`:225) takes a cell's hash as a share of 2³², less each prop's `chance()` in the area's order: a prop put before the others would change which cells show them | The grass goes last, so it takes only the hashes that showed nothing (§5.6) |
| B15 | A resource's shallow copy shares its arrays | `Resource.duplicate()` shares a copy's `Array` properties with the original (Godot 4.7.2 `doc/classes/Resource.xml`:63). e12562a's pier test assigned its two props into a copied City's array, which was the cached City's own: the scripts after it saw a City of a flag and sails, and in CI `test_world_renderer.gd`'s `test_the_lamps_glow_over_the_veil_at_night` (*glow*) failed (run 44770512924) | The test gives its copy an array of its own (`test_prop_scatter.gd`:856–866 on the prototype). 8e82633 |
| B16 | The props that the pier takes away must stop animating | `_find_pier()` (`prop_scatter.gd`:215–228) releases each prop at sea and erases it from its row's lists. A prop left in a list would have its frame set after its sprite went back to the pool | The resting props are a list of their own, which the pier erases too (§5.5). e12562a |
| B17 | The Web redraws | In Godot 4.7.2 each redraw of a `Polygon2D` after its first raises WebGL errors (godotengine/godot#124726; docs/M2.md §5.7) | Only the material's parameters change, each only when its value does; Chrome and Firefox log no error (P9) |

### Low

| # | Finding | Evidence | Fix |
|---|---|---|---|
| B18 | The car's painted lamps | `make_car.gd`:33–37 paints its headlamps "yellow" and its tail lamps "fire", under the veil: at night they darken with the car | As now (Q7). A glow for them is a note (§9) |
| B19 | The set pieces | The tunnel's and the bridge's rows are `RoadLayer`'s too, so the cone lights their decks: in the tunnel a faint warm wedge on its floor, and the rock over it dark (P11). The tunnel's pixels never clip (P6) | As is |
| B20 | Aimed after the physics steps | World's `_process()` aims the cone after the frame's physics steps, at the car as it is drawn. In GUT a test may step the car once more before it reads the cone | *lights* allows its apex within `Iso.TILE_H` / 4 of the lamps: "no more than 5 px at its top speed" |

---

## 3. Decisions and open questions

Nobody answered while the plan was written: each question has the default that the prototype follows, and the owner answers on this plan's PR, or takes the defaults by merging it (docs/agents/planning.md §5). A changed answer changes the PR that it names, and its tests and counts.

| # | Question | Default | Not taken |
|---|---|---|---|
| Q1 | What do the headlights light? "They highlight the road, but not the objects around" | **The road's tiles in a cone ahead of the car: the asphalt, the lane marks, and the decks of the tunnel and the bridge. Not the ground beside the road, and nothing that stands on the road (§5.2)** | The ground in the cone too: grass and sand by the road would light, as a real lamp's would. The ground's band sprites would take the road's material too (`world_renderer.gd` `_add_band()`); the props stay unlit (§9) |
| Q2 | When? "from dusk till sunrise" | **From 18:30, the light's dusk key, until 06:00, the sunrise; on and off over 0.5 s; held on into a zone's morning until its light has come (§5.1, §5.4)** | From 18:00, the sunset (docs/DAYNIGHT.md:113): half an hour sooner, in a light most of the way to dusk's |
| Q3 | Once the run is over? | **Off: after a disaster, a crash or the arrival, over 0.5 s (§5.1)** | On until the end screen: at the arrival, held at dusk, they would light the pier |
| Q4 | How? | **The road's own material, under the veil: `RoadLayer` draws itself brighter in the cone (§5.2)** | A `Light2D`, which the light's rule forbids and which lights the props; an ADD glow above the veil, which lights the props too; the cone drawn into a `SubViewport` masked by the road, a second pass of the road each frame (B3) |
| Q5 | The cone's shape? | **2.5 tiles long, whole to 1 tile, then dimming; 0.07 tile either side at the lamps, 0.14 wider a tile on; soft at its sides from 0.6 of its half width (§5.2)** | Longer or wider: `HEADLIGHT_*` in `config/tuning.gd` |
| Q6 | How bright, and what colour? | **0.6 of the way back to the road's day colour, in a warm white (1, 0.92, 0.75), accepting that the road's lines, 11% of its pixels, clip at night, and show dimmer and of another hue than meant (B8, §5.3)** | 0.0326 or less, which clips nothing in a run but lifts the night's red only from 0.42 to 0.44 (§5.3); white light |
| Q7 | Do the car's painted lamps glow? | **No: they stay as painted, under the veil (B18)** | A glow for each lamp in `Lamps`, above the veil (§9) |
| Q8 | How do the windmills stop? | **Their sails slow to a stop over 3 s from dusk, 18:30, and come back up to speed over 3 s from the sunrise, 06:00, by the night of the headlights; a run that starts at night starts with them still (§5.5)** | Stop at once; stop at sunset |
| Q9 | Which props rest? | **The windmill alone. The traffic lights, the chimneys' smoke, the tumbleweed, the pond and both grasses go on at night (§5.5)** | Others too: one line each in `make_props.gd`'s `RESTS` |
| Q10 | What grass? | **Tufts of six blades, 14 × 9 px, in the Meadows' two greens, that sway in 4 frames at 3 a second; at a density of 0.05, last in the Meadows' picker: on average 0.05 of the one-cell lots pick it, each one that showed nothing, and it shows where a tuft wouldn't touch the road; the other props keep their cells and phases; no outline and no shadow (§5.6)** | A denser carpet, which costs a sprite each (B12, §9); grass painted into the ground's tiles, which sways only if their `TileSet` animates it (§9) |
| Q11 | Where do the rules change? | **In this plan's PR, which the owner lands: PR 1's base and head both then have them, so Copilot reviews it by the amended rules (§5.7)** | In PR 1, which would then be the owner's to land (`AGENTS.md` §5 step 4) |
| Q12 | How do the PRs land? | **A stack of three, one for each ask, then the docs from `main` once the third has merged (§4)** | One PR for all three, or three on `hl/plan` side by side: PR 2 and PR 3 change their predecessor's lines (§4.5) |

---

## 4. Work breakdown

Four PRs after this plan's (Q12): PR 1, the headlights, with base `hl/plan`; PR 2, the windmills, with base PR 1's branch; PR 3, the grass, with base PR 2's; then PR 4, the docs, from `main` once PR 3 has merged (§4.4). Each leaves CI green (E14).

```
plan PR ──▶ PR 1 the headlights ──▶ PR 2 the windmills ──▶ PR 3 the grass
 (docs,      (B1–B4, B7, B8, B10,     (B5, B15, B16)         (B6, B12, B14)
  rules)      B11, B13, B17–B20)                                    │
                                                                    ▼  once PR 3 has merged, from main
                                                                  PR 4 docs (B9)
```

- **One PR for each of the owner's three asks**, so each can be reviewed, tried and stopped on its own.
- **The headlights first.** The windmills rest by PR 1's `night_at()`, and PR 2 adds to three of PR 1's files: `world/world_renderer.gd`, `config/tuning.gd` and `test_daylight_run.gd`.
- **The grass last.** It changes only the Meadows, and its cost is fixed in the loop that PR 2 gives `PropScatter.update()` (B12): PR 3 adds to three of PR 2's files, `world/prop_scatter.gd`, `tools/art/make_props.gd` and `test_prop_scatter.gd`.
- **Stacked** (`AGENTS.md` §4): each is checked on what it lands on, and PR 3's head has the prototype's tree (§4.1).
- **The docs last**, once all three are on `main` (docs/agents/planning.md §6).

### 4.1 Building the PRs from the prototype

Each PR cherry-picks its commits from `hl/prototype` without committing them, then commits them as one, with its subject (§4.2–§4.4). From `main` at 4a50bb2, the cherry-picks give exactly the PRs' code trees, 90be123, 003c32b and 7f2fd4c: each PR's tree but for this plan's three files, which the prototype doesn't have. §6 checked them. Only 7f2fd4c, 8c02110's own, is a pushed commit's tree, so step 1 builds the other two first. These steps were tried in a fresh clone, and gave the three trees, and the three diffs that step 1 names.

1. Fetch the branches, build the code trees, and create and fill PR 1's branch:
   ```bash
   git fetch origin main '+refs/heads/hl/*:refs/remotes/origin/hl/*'
   git worktree add --detach ../hl-trees 4a50bb2
   cd ../hl-trees
   git cherry-pick -n 3d40104 d4fc744 && git write-tree                  # 90be1231c0…
   git cherry-pick -n 9b4d908 e12562a 8e82633 b337183 && git write-tree  # 003c32b32e…
   git cherry-pick -n c0ea19a eac39f8 8c02110 && git write-tree          # 7f2fd4cf6b…
   cd - && git worktree remove --force ../hl-trees  # the trees stay in the repository
   git worktree add -b hl/1-headlights ../hl-1 origin/hl/plan  # origin/main, if the plan's PR has merged
   cd ../hl-1
   git cherry-pick -n 3d40104 d4fc744
   git diff --name-only 90be123   # only HEADLIGHTS_PLAN.md, AGENTS.md and the light instructions
   git commit                     # §4.2's subject, and AGENTS.md §4's trailer
   ```
   PR 2 starts with `git worktree add -b hl/2-windmills ../hl-2 hl/1-headlights` and `cd ../hl-2`, then `git cherry-pick -n 9b4d908 e12562a 8e82633 b337183` and `git diff --name-only 003c32b`; PR 3 with `git worktree add -b hl/3-grass ../hl-3 hl/2-windmills` and `cd ../hl-3`, then `git cherry-pick -n c0ea19a eac39f8 8c02110` and `git diff --name-only 7f2fd4c`. Each diff lists this plan's three files and no others; and, once the branch has `main`'s changes since 4a50bb2, those of `git diff --name-only 4a50bb2 origin/main` too. If a cherry-pick then conflicts, resolve it by hand, keeping what `main` and the prototype each meant, and run §6 again: the trees then differ from these by `main`'s changes, and so may the counts and the smoke line.
2. For PRs 2 and 3, which change `make_props.gd`, run `tools/ci/import.sh`, then `godot --headless -s tools/art/make_props.gd`, then `import.sh` again: `git diff --exit-code` must print nothing, as it does on both trees, since the script draws the same bytes on every run. In a new worktree the first import is needed.
3. Leave `HEADLIGHTS_PLAN.md`, `AGENTS.md` and the light instructions alone on the PRs' branches: they change only on `hl/plan`, which is merged up (§4.5). A change to the plan on a PR's branch would make the merge of `main` after the plan's squash an add/add conflict.
4. Run §6.1's checks and §6.3's warnings on the PR's head, and compare the counts with the PR's "Expect" line. Then run §6.2's negative cases, the PR's own and those of the PRs below it, as its changes may make one of theirs fail otherwise: 12 on PR 1, 23 on PR 2 and 28 on PR 3. Before it opens, each with the test scripts that it names; with the whole suite as its last round is pushed, and again if a later commit changes more than docs (docs/agents/planning.md §4).
5. Have a model of another family review it (`AGENTS.md` §5). Then push, and open the PR with its base.

### 4.2 PR 1: World: the car's headlights **Δ B1–B4, B7, B8, B10, B11, B13, B17–B20**

Branch `hl/1-headlights`, from `hl/plan`: `world: the car's headlights light the road from dusk until sunrise (HL PR 1)`, the prototype's 3d40104 with d4fc744's fix (B7, §4.6).

| Area | Files |
|---|---|
| World | `world/headlights.gd`, new: `Headlights`, a `RefCounted` that holds the road's `ShaderMaterial`. `update()` turns them on and off (§5.1, §5.4), gives the light back (§5.3) and aims the cone (§5.2); `lit()` and `gain()` work out the cone and the light as the shader does; `shown()` reads a parameter back. `world/headlights.gdshader`, new: the road's shader (§5.2). `world/world_renderer.gd`: `build()` gives the road the headlights' material, `_process()` updates them after the lamps, and `headlights()` returns them. `world/day_cycle.gd`: `night_at()` (§5.1) |
| Config | `config/tuning.gd`: `DUSK_HOUR`; `HEADLIGHT_FRONT`, `_HALF_WIDTH`, `_SPREAD`, `_REACH`, `_DIM_FROM` and `_EDGE`, the cone (§5.2); `HEADLIGHT_COLOR` and `_SHARE`, the light (§5.3); `HEADLIGHT_SWITCH_SECONDS` (§5.1) |
| Tests | `test_headlights.gd`, new: 7 (E2–E4). `test_day_cycle.gd`: *night* (E1). `test_daylight_run.gd`: *lights* (E5) |

11 files, 6 of them new, 3 of those `.uid`s; +448 −2. Expect, on `hl/plan`: `check_scripts: loaded 223 scripts`, 2 more than `main`'s 221; `GUT: 912 tests passed`, 9 more than `main`'s, in 104 test scripts, with 456,700 asserts, 159 more; `autopilot: tile 165, turns 35, area rural`, as on `main`. Negative cases N1–N10, N20 and N21.

**Acceptance:** E1–E6, E14, and E12's part for PR 1.

### 4.3 PR 2: World: the windmills rest at night **Δ B5, B15, B16**

Branch `hl/2-windmills`, from `hl/1-headlights`: `world: the windmills' sails rest at night (HL PR 2)`, the prototype's 9b4d908 with the fixes e12562a (B16), 8e82633 (B15) and b337183 (§4.6).

| Area | Files |
|---|---|
| Areas | `areas/prop_def.gd`: `rests_at_night`, and `validate()`'s rule that only a prop that animates may rest (§5.5). `areas/props/rural/windmill.tres`: `rests_at_night = true`. The windmill is the Rural's alone |
| Art | `tools/art/make_props.gd`: `RESTS`, which only the windmill is in, written to each `.tres` that rests. It draws the same sheets as on `main` |
| World | `world/prop_scatter.gd`: the rest clock and its rate, the rows' `resting` lists, which the pier erases too, and `update(delta, cycle)` (§5.5). `world/world_renderer.gd`: `_process()` gives `update()` the zone's clock |
| Config | `config/tuning.gd`: `PROP_REST_SECONDS` |
| Tests | `test_prop_scatter.gd`: *rest* and *pier*, new (E7, E8); *contract* adds a prop that rests but doesn't animate. `test_daylight_run.gd`: *windmills*, new (E7) |

8 files; +252 −12. Expect, on `hl/1-headlights`: `check_scripts: loaded 223 scripts`, as PR 1's; `GUT: 915 tests passed`, 3 more than PR 1's, in 104 test scripts, with 456,722 asserts, 22 more; `main`'s smoke line. Negative cases N11–N16 and N23–N27, and PR 1's on its head too.

**Acceptance:** E6, E7, E8's part for PR 2 (*pier*), E14, and E12's part for PR 2.

### 4.4 PR 3: Props: grass in the Meadows **Δ B6, B12, B14**

Branch `hl/3-grass`, from `hl/2-windmills`: `props: grass sways in the Meadows (HL PR 3)`, the prototype's c0ea19a with eac39f8's fix and 8c02110's test (B12, §4.6).

| Area | Files |
|---|---|
| Areas | `areas/props/meadows/grass.tres`, new: 4 frames at 3 a second, a density of 0.05, no shadow (§5.6). `areas/meadows.tres`: the grass, last (B14) |
| Art | `tools/art/make_props.gd`: `_paint_grass()`, and the grass in `PROPS`, `FLAT` (no outline) and `SHADOWS` (none). `assets/meadows/props.png`: the grass's 4 frames, 56 × 9 px, at (216, 0); 1,624 B, where PR 2's is 1,426 |
| World | `world/prop_scatter.gd`: `Shown.next_frame_at`, and `update()` looks at an animated prop only once its next frame has come (§5.6) |
| Tests | `test_prop_scatter.gd`: *frames* and *guard*, new (E8). `test_prop_art.gd`: *sways*, new (E9). `test_prop_layout.gd`: *grass layout*, new (E9) |

8 files, 1 of them new; +213 −7. Expect, on `hl/2-windmills`: `check_scripts: loaded 223 scripts`; `GUT: 919 tests passed`, 4 more than PR 2's, in 104 test scripts, with 456,809 asserts, 87 more; `main`'s smoke line. Negative cases N17–N19, N22 and N28, and PRs 1 and 2's on its head too.

PR 3 is the stack's last code PR: it gathers the device checks of all three (§6.4) into one list, with a build of its branch, and mentions @pompomon; the owner lands it once they pass (docs/agents/planning.md §5). It carries the plan's final sync: its status, §4.6's rows, the counts and the device results.

**Acceptance:** E6, E8's part for PR 3 (*frames*, *guard*), E9–E11, E14, and E12 for all three.

**PR 4: Docs: docs/HEADLIGHTS.md.** Branch `hl/4-docs`, from `main` once PR 3 has merged (docs/agents/planning.md §6). Not before, as it rewrites cites in PRs 1–3's files (docs/agents/stacks.md step 2).

| Area | Files |
|---|---|
| Docs | `docs/HEADLIGHTS.md`, new, at most about 15 KB, which replaces this plan (§5.7), and its row in `docs/README.md`. `HEADLIGHTS_PLAN.md`, deleted, and each cite of it in code, tests and the rules rewritten as `docs/HEADLIGHTS.md`, as long, so no line reflows |
| | docs/DAYNIGHT.md Q5 (:42) and docs/M5.md §5.6 (:102) each end with "now …" and the B# that changed them, as docs/M5.md §5.6 does for VIS's A5 |
| | IP §4 M7: the device checks still open, with E12, and §9's notes. `AGENTS.md`: the IDs (:18), with B# (HEADLIGHTS), and the state (:20) |
| Learnings | What HL's PRs and sessions taught, in the guidelines (docs/agents/planning.md §7) |

No code, so PR 3's counts. It changes `AGENTS.md` and `docs/README.md`, so the owner lands it. Its owner actions end with the branches (§7). **Acceptance:** E13.

### 4.5 Landing (Q12)

This plan's PR targets `main`, PR 1 `hl/plan`, PR 2 `hl/1-headlights` and PR 3 `hl/2-windmills`. Only a PR whose base is `main` merges (`AGENTS.md` §5). The owner squashes the plan's PR, which approves the plan and brings in the amended rules (Q11). Then agents land PR 1 and PR 2 with `tools/agent/land_pr.sh`, bottom up, each once its gate passes (docs/agents/stacks.md step 4): neither changes a path that the owner lands. Three PRs are the owner's, and each has the `needs-owner` label from the start, with a comment that says why: this plan's PR, which changes `AGENTS.md` and `.github/`; PR 3, the stack's last, once the device checks pass; and PR 4, which changes `AGENTS.md`. If the plan's PR is squashed before PR 1 opens, PR 1 branches from `main` and targets it (§4.1 step 1). The plan changes only on `hl/plan` until its PR merges; after that each PR keeps its results and its review fixes in its body, and PR 3 carries the plan's final sync (§4.4). PR 4 deletes it.

A review fix goes on the branch of the PR that adds the file, then merges up (`AGENTS.md` §4): PR 1's six new files on PR 1's branch, PR 3's `grass.tres` on PR 3's, and a fix to a file that two PRs change on the branch of the PR whose part it fixes. The plan's fixes go on `hl/plan`, and merge into PR 1's branch with `git merge --no-ff --no-edit`, then into PR 2's, then PR 3's.

After each squash, retarget the next PR to `main` before anyone deletes the merged branch: deleting it closes each open PR based on it, unless GitHub has retargeted it first (docs/agents/stacks.md step 6). `land_pr.sh` retargets them as soon as it has merged. Then, in the next PR's worktree, stacks.md step 5:

```bash
git fetch origin main '+refs/heads/hl/*:refs/remotes/origin/hl/*'
cd <next PR's worktree>
git merge origin/<merged PR's branch>  # its last fixes, in case one wasn't merged up yet
git merge origin/main                  # the squash
git diff --name-only origin/main       # must list only the next PR's files
git push
gh pr edit <next PR> --base main       # unless GitHub or land_pr.sh retargeted it
gh pr edit <next PR> --add-reviewer @copilot
```

If the merged PR's branch is already deleted, merge its last state with `git fetch origin pull/<merged PR>/head && git merge FETCH_HEAD` instead (stacks.md step 5).

**Two of these merges conflict** (P12), as simulated with `git merge-tree` on the PRs' trees. After PR 1's squash, PR 2's merge of `main` conflicts in `test_daylight_run.gd`: PR 2 changes again the header's lines that PR 1 changes, and its *windmills* follows the lines that PR 1's *lights* adds at the file's end. After PR 2's squash, PR 3's conflicts in `prop_scatter.gd`, whose loop in `update()` and `_set_frame()` PR 3 changes after PR 2 does (B12), and in `test_prop_scatter.gd`, where PR 3's *frames*, *guard* and `_animated()` go just before PR 2's *rest* and `_changes()`; with or without PR 2's merge-up first. These are the conflicts that stacks.md step 3 warns of, and PR 3 can't avoid its first: it changes PR 2's loop. Each time nothing else had landed since the PR below, so `main`'s tree was that PR's head, and stacks.md step 5's `-X ours`, with its two checks, gave exactly the PR's code tree, 003c32b and then 7f2fd4c. If anything else lands in between, as SP's PRs may, resolve the conflicts by hand instead, and run the five checks on the merge. PR 1's merge of `main` after the plan's squash is clean once it has merged `hl/plan`'s last state: both sides then add the same files.

SP's prototype changes 4 of HL's files at other lines, and merges with 8c02110 cleanly (P8); simulate each merge of `main` with `git merge-tree --write-tree` first. A merge-up that changes no file in the PR's diff may start no Copilot review: request one with `gh pr edit <n> --add-reviewer @copilot`. Don't register the PRs as a GitHub stack: agents land PRs 1 and 2, and `land_pr.sh` merges directly (stacks.md step 7).

### 4.6 Review fixes

Fixes found while the prototype was built and by the internal reviews (§4.7), each with its tests (short names in §6.2) and its negative case. Copilot's findings get rows below them.

| PR | Change | Tests | Negative case |
|---|---|---|---|
| 1 | B7: off as soon as a zone's clock left the night, the cone dimmed before the morning's light came, then the road lightened again. d4fc744 keeps them on while the light catches up, once on | *hold* | N20, N21 |
| 2 | B16: 9b4d908 chose each animated prop's clock in `_set_frame()`, every frame: about 60 µs of `update()`'s 616 in the Meadows with the grass. And no test checked that the props that the pier takes away stop animating. e12562a gives the resting props a list of their own, which the pier erases too, with *pier* | *pier*, *rest*, *windmills* | N23–N26 |
| 2 | B15: in CI, e12562a's pier test left the cached City with a flag and sails, and *glow* failed (run 44770512924). 8e82633 gives the test's City an array of its own | *pier* | N27 |
| 2 | The editor's warnings (§6.3): 8e82633's test read a variable before it was given a value (`UNASSIGNED_VARIABLE`, `test_prop_scatter.gd`:810, :868 on 8c02110). b337183 gives it one | *pier* | Without the value, §6.3 reports the warning again |
| 3 | B12: c0ea19a's grass took `update()` from 94 µs a frame to 616 µs in the Meadows. eac39f8 looks at an animated prop only once its next frame has come: 184 µs | *frames* | N22 |
| 3 | The plan's review (F7, §4.7): no test checked eac39f8's guards, which change only when a frame is worked out, so *frames* passed without them. 8c02110 adds *guard* | *guard* | N28 |

### 4.7 Internal review

gpt-6.2-sol, a model of another family, reviewed the prototype's diff, 4a50bb2..b337183 (`code-review`): the shader and `lit()`, the cone's transforms, the gain and the hold at their edges, the rest clock, `next_frame_at`, and the tests. It found one issue: the road's lightest texels clip (B8). Q6 holds that choice, so it is declined as a change to the code: only light added over the veil passes the cap, and it lights the props too (§5.3, Q4). P6 measured it.

gpt-6.2-sol also reviewed this plan and its amendments (`rubber-duck`), against the prototype and the repository. It confirmed the trees, the counts, the smoke lines and the negative cases' logs, and found 12 issues, each fixed: F1, §4.1 diffed against code trees that no pushed commit has, so step 1 builds them; F2, the Web's check of the hold couldn't show it, as `--hour=` sets every zone's clock (§6.4); F3, E2's "never dims" held only for a clock that starts at 07:00 (E2, §5.4, §8); F4, a share of 0.12 clips the Village's lines, so §5.3 and P6 give the bound, 0.0326; F5, P1's first mask missed the City's road under a see-through building; F6, N8 changes no pixel, so §6.2, Q1 and §9 say so; F7, nothing tested eac39f8's guards, so 8c02110 adds *guard* (§4.6); F8, the negative cases ran on 8e82633, so all 28 ran again on 8c02110, and each PR runs its own and those below (§4.1 step 4); F9, §4.5 lacked the retarget, the fallback for a deleted branch and the owner's labels; F10, the Fold4's checks had no route to the tunnel, the bridge, the run's end or a pause, nor an APK that prints its frame rate, and §5.1 said the pier shows no cone (§6.4); F11, the amendments read as about the final image, and as if `night_at()` alone switched the lights and the sails (§5.7); F12, Q10 and E9 called the grass's density a share of the empty cells. It then checked the fixes, and found 10 more points, each fixed: among them, N11 and N23 now fail *guard* too, the Fold4's hold should last about 1.9 s, and §4.1 gives each branch a worktree and runs the whole suite's cases at a PR's last round. Two last checks of the changes found 7 more, each fixed.

---

## 5. Design

### 5.1 The night and the switch (B2, B10; Q2, Q3; E1, E2) **Δ docs/DAYNIGHT.md Q5**

docs/DAYNIGHT.md Q5 chose lamps and windows that glow at night, and no headlights (:42). **Δ** The car has headlights, which light the road from dusk until sunrise, while it drives.

**The night.** Nothing on `main` says when the night is: `DayCycle` eases the light between its keys, and its sun is up from `SUN_RISE_HOUR` to `SUN_SET_HOUR`, 06:00 to 18:00 (`tuning.gd`:266–267), in a private `_sun_up()` that the shadows use. `DayCycle` gets:

```gdscript
static func night_at(p_hour: float) -> bool:
	var night := fposmod(Tuning.SUN_RISE_HOUR - Tuning.DUSK_HOUR, 24.0)
	return fposmod(p_hour - Tuning.DUSK_HOUR, 24.0) < night
```

`DUSK_HOUR`, 18.5, is the light's dusk key (`LIGHT_HOURS`, :251), where it is `LIGHT_DUSK`, (1.0, 0.72, 0.52), on its way from the day's white at 17:00 to the night's at 20:00. So the night is from 18:30 until 06:00, 11.5 hours round midnight, for any hour, 30 or −1 too: *night* checks hours either side of both ends, and past 24 and below 0 (N9, N10). "From dusk" names the light's key, not the sunset, 18:00, which the light has no key for (Q2). A zone's day lasts 120 s, 5 s an hour from 07:00 (docs/DAYNIGHT.md §5.4), so the headlights come on 57.5 s into a zone. The windmills rest by the same night (§5.5).

**The switch.** `Headlights.update()`, each frame:

```gdscript
var on := cycle != null and sim != null and not sim.is_over()
if on:
	var catching_up := level > 0.0 and cycle.light != cycle.target()
	on = DayCycle.night_at(cycle.hour()) or catching_up
level = move_toward(level, 1.0 if on else 0.0, delta / Tuning.HEADLIGHT_SWITCH_SECONDS)
```

`level` goes from 0 to 1 in `HEADLIGHT_SWITCH_SECONDS`, 0.5 s, and back as fast, so they fade on and off rather than flash (N2); the light that they give scales with it (§5.3, N4). *on* steps a clock through the day; *switch* times both fades. `catching_up` is §5.4's hold.

- **Off once the run is over (Q3, B10).** `CarSim.is_over()` is true after a disaster, a crash or the arrival, and they go out over 0.5 s: *off* checks each, and that braking and leaving the road keep them on (N1). The arrival holds the clock at `ARRIVAL_HOUR`, 18.5 (`ui/main.gd`:339, docs/ENDGAME.md §5.8), which is `DUSK_HOUR`: night by `night_at()`, but the run is over, so a cone lit as the car reaches the pier fades out in 0.5 s, and none comes on.
- **Without a clock or a car**, as in a test that builds World alone, they are off (*off*).
- **By the zone's clock.** World holds the `Headlights`, gives the road their material (§5.2), and updates them each frame with its `cycle`, the clock that `Daylight` keeps for the zone (docs/DAYNIGHT.md §5.4). So they follow `--hour=` and each zone's new morning as the lamps do. Nothing in the simulation reads them.

### 5.2 The cone (B3, B4, B11, B13, B20; Q1, Q4, Q5; E4, E5)

**Why the road's material (Q4).** The light's rule forbids a `Light2D` (B3), which would light every node in its mask, the props and the car among them: they share World's canvas with the road. An ADD glow above the veil, as `Lamps` draws, lights all below it in its shape, props too. A cone drawn into a `SubViewport` and masked by the road would draw the road twice each frame. The road's own material lights the road's own pixels, and nothing else, and needs no pass of its own.

**The shader**, `world/headlights.gdshader`, on `RoadLayer` alone:

```glsl
void vertex() {
	canvas = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 offset = canvas - origin;
	float ahead = dot(along, offset);
	float aside = abs(dot(across, offset));
	float width = half_width + spread * max(ahead, 0.0);
	float lit = step(0.0, ahead) * (1.0 - smoothstep(dim_from * reach, reach, ahead));
	lit *= 1.0 - smoothstep(edge * width, width, aside);
	COLOR.rgb *= 1.0 + gain * lit;
}
```

`ahead` and `aside` are in tiles, along the car's axis and across it, from the cone's apex at the car's lamps. The cone lights 1 from the lamps to `dim_from` of its `reach`, and fades to 0 at the reach; it is `half_width` either side of the axis at the lamps and `spread` wider each tile on, and fades from `edge` of its half width to the edge. Behind the lamps it lights nothing.

**Its shape (Q5).** `HEADLIGHT_FRONT`, 0.16 tile ahead of the car's centre: the painted headlamps' front (`make_car.gd`:33–37, B18). `HEADLIGHT_HALF_WIDTH`, 0.07 tile, as the lamps are 0.05–0.08 tile either side; `HEADLIGHT_SPREAD`, 0.14 wider a tile on, so 0.42 either side at the reach; `HEADLIGHT_REACH`, 2.5 tiles, whole to 1 tile, as `HEADLIGHT_DIM_FROM` is 0.4; soft from `HEADLIGHT_EDGE`, 0.6, of its half width. So the cone is 0.14 tile across at the lamps and 0.84 at its reach. All are in `config/tuning.gd` (IP D11).

**Aimed in tiles, drawn in canvas pixels (B13).** `MODEL_MATRIX` takes `RoadLayer`'s vertices to the canvas, before the camera; the car is in tiles. `aim()` takes World's global transform, `to_canvas`, puts the apex at `to_canvas * Iso.tile_to_world(sim.pos + sim.forward() * HEADLIGHT_FRONT)`, and turns the car's axis into the two rows that take a canvas offset to tiles:

```gdscript
var to_tiles := (
	Transform2D(Iso.world_to_tile(Vector2.RIGHT), Iso.world_to_tile(Vector2.DOWN), Vector2.ZERO)
	* to_canvas.affine_inverse()
)
_show(&"along", Vector2(to_tiles.x.dot(ahead), to_tiles.y.dot(ahead)))
_show(&"across", Vector2(to_tiles.x.dot(aside), to_tiles.y.dot(aside)))
```

`Iso.world_to_tile()` is linear (`iso.gd`:20–21), so its images of the two axes are its matrix. Wherever World is on the canvas, however scaled or turned, the shader then measures in tiles along the car: *cone* checks two transforms, World's own and one that scales by 2 and moves, each at four headings (N5, N6).

**The road, but not the objects around (Q1, B4).** `WorldRenderer.build()` gives `RoadLayer` the material, and nothing else in World has it (N7, N8). The road's tiles are its asphalt and lane marks, and the decks of the tunnel and the bridge (§5.4). `Ground` (`world.tscn`:22) and `SetPieces` (:25) are drawn before the road, and stay dark. All that is drawn after it, `Skids` (:31), `Shadows` (:34), `DisasterLayer` (:39), `Props` (:42), with the car (`ui/main.gd`:211), and `Lamps` (:46), draws over the lit road, as do the tunnel's rock and the near railings of the bridge and the pier, at `z_index` 1: where it is opaque, the light under it doesn't show, and it isn't lit itself. So a prop or a legend in the cone stays as dark as the night makes it. *lights* checks it in the main scene, as E5 says (N1, N7, N8), and Movie Maker's frames show it: at 22:00 every pixel that the headlights change is within the road's footprint, and none is darker (P1). A see-through building, faded where it would hide the car (docs/VISUALS.md §5.9), shows the lit road through it, as it shows the road by day.

**GUT can't see it (B11).** Headless, Godot draws nothing. `Headlights.lit(point)` works out the cone from the parameters last given to the material, as the shader does, and *cone* checks it: 1 at the lamps and at the dimming's start, between 0.1 and 0.9 half way to the reach, 0 past the reach, behind the lamps and outside the half width, more than 0.99 at its edge's start. *material* checks that the shader's parameters are those that `lit()` reads, and the tuning's. P1 checks the shader itself, in real frames.

**Each frame (B20).** World's `_process()` updates the shadows, the scatter, the lamps, then the headlights, after the frame's physics steps, so the cone follows the car that is drawn. *lights* reads the cone half a second into the run, and allows its apex `Iso.TILE_H` / 4, 16 px, from the lamps: GUT may step the car once more before the test reads it, which moves it no more than 5 px at `BASE_TOP_SPEED`.

### 5.3 The light given back (B1, B8, B17; Q6; E3)

The veil multiplies each pixel below it by `kept`, the light shown, channel by channel (docs/DAYNIGHT.md §5.5). The shader multiplies the road's colour `c` by `1 + gain × lit` before it. Where the cone is brightest the road shows `c × (1 + gain) × kept`, and `gain()` chooses each channel's gain so that it shows a share of the light that the veil takes away:

```gdscript
static func gain(light: Color, p_level: float) -> Vector3:
	var gains := Vector3.ZERO
	for channel: int in 3:
		var kept: float = light[channel]
		if kept > 0.0 and kept < 1.0:
			var given: float = Tuning.HEADLIGHT_SHARE * Tuning.HEADLIGHT_COLOR[channel]
			gains[channel] = p_level * given * (1.0 - kept) / kept
	return gains
```

So the road shows `c × (kept + level × HEADLIGHT_SHARE × HEADLIGHT_COLOR × (1 − kept))`, but where `c × (1 + gain)` passes 1 and clips (below): from the night's `kept` towards the day's 1, by the share at most, so never lighter than by day (N3). A channel that the veil keeps whole, as by day or `LIGHT_DUSK`'s red, gets nothing, and one that it blacks out has nothing to give back. By day the gain is 0, and the road is drawn as before: by day Movie Maker's frames of the City and Rural are `main`'s bytes in 600 of 600 (P2). *share* checks the road's light in the cone with them full on, at the night's light, at dusk, at dawn and by day, and that off they give nothing; *switch*, the material's gain on and off. In between, as they switch for 0.5 s, the gain goes with the level, which *switch* checks at half (E2); no test reads the gain there.

**How bright, and what colour (Q6).** `HEADLIGHT_SHARE`, 0.6, in `HEADLIGHT_COLOR`, a warm white, (1, 0.92, 0.75). At `LIGHT_NIGHT`, (0.42, 0.48, 0.72), the road in the cone shows (0.77, 0.77, 0.85) of its day colour where it doesn't clip, against the rest's (0.42, 0.48, 0.72): lighter, and less blue than the night around it, as a lamp's light is.

**Clipping (B8).** The road is drawn into the 8-bit canvas before the veil multiplies it, so a channel above `1 / (1 + gain)` clips at 1: under the veil no pixel shows more than `kept`, (107, 122, 184) of 255 at `LIGHT_NIGHT`. There the gains are (0.83, 0.60, 0.18), so channels above (139.5, 159.6, 217) clip. On the `ROAD` row, the lines clip, 11.25% of its opaque pixels, and nothing else; on `BRIDGE`, the bridge's and the pier's planks, the same; on `TUNNEL` nothing (P6). The `DEAD_END` row clips on most, but only the `show_dead_ends` view shows it, never a run (`greybox_atlas.gd`:36). A clipped line shows less than meant, by up to 80 levels a channel, and bluer, since the channels that the veil darkens most reach the cap first (P6). It still shows more than outside the cone, and never more than by day. At `LIGHT_DUSK`, (1, 0.72, 0.52), the gains are (0, 0.21, 0.42), and the same lines clip, but on Rural's road. Only a share of 0.0326 or less clips nothing in a run, as the Desert's lines' red is 244 of 255 (P6). At 0.0326 the night's red in the cone rises only from 0.42 to 0.44: a cone that barely shows. Lines lit as meant need the light added over the veil, as Q4's ADD glow adds it, lighting the props in the cone too: a `Light2D` lights the road before the veil, and meets the same cap. Q6's default takes the clipping for a cone that shows (§4.7).

**On the Web (B17).** `_show()` sets a parameter only when its value changes, and only the material's parameters change: no node is redrawn for them, so godotengine/godot#124726's errors can't come of it. In Chrome and Firefox the game logged no error (P9).

**Cost.** Movie Maker's render times at 22:00, in the City and Rural, are within or below the range of `main`'s two runs (P3).

### 5.4 Into a zone's morning, and the set pieces (B7, B18, B19; E2)

**The hold (B7).** Each zone starts its clock at 07:00 as the car enters it (docs/DAYNIGHT.md §5.4), and the light shown catches up with the hour's at `LIGHT_MAX_RATE`, 0.25 a second a channel (docs/DAYNIGHT.md §5.3; `tuning.gd`:255): from the night's to white in about 2.3 s. The City's 34 turns take the autopilot 58–59 s (`smoke.sh`'s seed), so it enters Rural at about 18:40, after dusk, with its headlights on. Turned off as soon as the clock leaves the night, the cone would dim before the light came: entered at the night's light, the road's red in the cone would fall from 0.768 of its day's to 0.545 in 0.5 s, while the light rose 0.125, then lighten again with the rest (P7). So, once on, they stay on while the light shown differs from the hour's (`catching_up`, §5.1), and turn off only once it has come, when they light nothing more than the day does. Entered before dusk, they are off, and stay off while the light comes: `level > 0.0`. *hold* checks both, with the clock's 07:00 start: the road in the cone never dims while the light comes, and they are off once it has (N20, N21). A zone that `--hour=` starts at 06:00–07:00 or 17:00–18:30 has a tinted light to come: if it comes outside the night they turn off, and the road in the cone can dim to it in 0.5 s, as it dims to dawn's at each sunrise, the less the nearer that light is to white.

**The painted lamps (B18; Q7).** `make_car.gd` paints the car's headlamps "yellow", and its tail lamps "fire", 0.14–0.16 tile ahead of and behind its centre. They are part of the car's sheet, drawn under the veil, so at night they darken with the car, while the cone shines from them. A glow of their own, in `Lamps`, is a note for later (§9).

**The set pieces (B19).** The tunnel's and the bridge's decks are rows of `RoadLayer`'s sheet, so the cone lights them. In the tunnel, where the veil and the tunnel's dark keep little, it shows as a faint warm wedge on the floor, and the rock stays dark, as it draws over the road and the car, at `z_index` 1, and fades as the car nears (`tunnel.gd`:6; P11). The bridge's deck clips as the road does (P6).

### 5.5 The windmills' rest (B5, B16; Q8, Q9; E7, E8) **Δ docs/M5.md §5.6**

On `main` every animated prop turns by one clock, `_clock`, the seconds since `bind()` (`prop_scatter.gd`:102–110), and World gives `update()` no hour (`world_renderer.gd`:133–137). **Δ** A `PropDef` that `rests_at_night` animates by a rest clock of its own, which the zone's night stops.

**The flag.** `PropDef.rests_at_night`, false by default. `validate()` adds "prop %s rests at night, but doesn't animate" for a prop of one frame that sets it (*contract*, N15). `make_props.gd`'s new `RESTS`, `[&"windmill"]`, writes it to the windmill's `.tres` (N16): Rural's, the windmill's only area. Nothing else rests (Q9): the City's traffic lights, the Village's chimney smoke, the Desert's tumbleweed, the Meadows' pond and grass and the Coast's dune grass go on at night, as wind, water and lamps would.

**The rest clock.** `PropScatter.update(delta, cycle)`:

```gdscript
_clock += delta
var rate := 0.0 if cycle != null and DayCycle.night_at(cycle.hour()) else 1.0
if _rest_rate < 0.0:
	_rest_rate = rate
_rest_rate = move_toward(_rest_rate, rate, delta / Tuning.PROP_REST_SECONDS)
_rest_clock += delta * _rest_rate
```

The rate moves from 1 to 0 over `PROP_REST_SECONDS`, 3 s, as the night falls, so the sails turn more slowly, a frame at a time, then stand where they stopped; from the sunrise it moves back as gently, and they start from there (Q8; N11, N12). `bind()` sets the rate to −1, so the first `update()` takes the hour's rate at once: a run that starts at night starts with the sails still (N13). Without a clock the rate is 1, so they never rest. World passes its clock, `_scatter.update(delta, cycle)` (N14), the zone's, so they rest by the same night as the headlights (§5.1). The arrival holds the Coast at dusk (B10), but it has no windmills.

**The rows' lists.** `_show_row()` puts a prop that rests in its row's `resting` list, and frames it by the rest clock; any other that animates goes in `animated`, by `_clock`, as before (N23, N24). `update()` frames each list by its clock (N11). `_find_pier()` erases a prop at sea from `resting` too (B16, N25), as from `animated` (N26), so no prop's frame is set after its sprite has gone back to the pool. 9b4d908 chose each animated prop's clock in `_set_frame()`, every frame; e12562a's lists save that choice, about 60 µs of a frame's 616 in the Meadows with the grass (§4.6).

**The tests.** *rest* runs a scatter with sails that rest and props that don't, by day and by night: a turn a second by day; as the night falls, the sails' changes in each second fall, by more than half from the first second of the dusk to the third, but not to none at once; none in two seconds of night, while the others turn as by day; back to a turn a second once `PROP_REST_SECONDS` of day have passed; still from the start in a run that starts at night; never resting without a clock. *windmills* opens the main scene in Rural at 22:00: its windmills stand for 60 frames, and turn again by day. *pier* counts the flags and sails that the pier takes away, and no sprite's frame changes after that (N25–N27).

### 5.6 The grass and its cost (B6, B12, B14; Q10; E8–E11)

**The tuft (Q10).** `make_props.gd` draws it with `_paint_grass()`: six blades, 2 px apart, 4–8 px tall (`[4, 7, 5, 8, 6, 4]`), in the Meadows' two greens in turn. Each leans out from the middle, and sways by 0, 1, 2 and 1 px at the tallest's tip in its 4 frames, in proportion to its height, so the tips move a pixel a frame and the tallest most. It is in `PROPS` with 4 frames at 3 a second and a density of 0.05; in `FLAT`, as an outline would fill in its blades; and in `SHADOWS` as `NONE`. Its frames are 14 × 9 px, at (216, 0) of `assets/meadows/props.png`, with its foot at (6, 8). *sways* checks that each frame differs from the one before (N18, N19), and *crop* that each is cropped to its pixels (N18). The Meadows have 7 props, 6 to 10 as each area must, some animated (*sums*).

**Last (B14).** `PropLayout.pick()` (`prop_layout.gd`:225) takes a cell's hash as a share of 2³², less each prop's `chance()` in the area's order, and shows the prop that takes it below 0. The grass is the Meadows' last prop, so it takes the 0.05-wide band of hashes just past the others': on average 0.05 of the one-cell lots pick it, only lots that showed nothing, and `_place()` leaves out each tuft that would touch the road. Each other prop stands where it stood without it, in the same phase. *grass layout* lays rows with and without it (N17). At 0.05 a cell, a view of the Meadows shows 12.6–13.0 tufts on average, 22 at most (P4).

**The cost (B12).** With the grass the Meadows' rows hold 619–667 animated props on average, against `main`'s 32.5–33.7 (P4), and `update()` worked out each one's frame every frame: 616 µs a frame on average, where `main`'s took 94. So each prop now notes when its next frame starts, and `update()` looks at it only then:

```gdscript
for shown: Shown in row.animated:
	if _clock >= shown.next_frame_at:
		_set_frame(shown, _clock)
```

`_set_frame()` works the frame out as before, from the clock, the prop's frames, its fps and its phase, and notes `next_frame_at = clock + (floorf(at) + 1.0 - at) / fps - NEXT_FRAME_EARLY`: when the frame after it starts, less 1e-6 s, so that rounding never makes a prop a frame late. A prop looked at early is framed again, as nothing changes until its frame does. The resting props do the same by the rest clock, which never runs faster than `_clock`. That took `update()` to 184 µs, about twice `main`'s, and a headless frame to 306–328 µs, against `main`'s 192–204 (P4). *frames* steps a scatter of sails, grass and flags by uneven deltas, 1/60 s, half that, 1.7 times it, 0 and 0.31 s, and checks each prop's frame against a new scatter's at the same clock: none a frame behind or ahead (N22). The guards change only when a frame is worked out, not which, so *frames* passes without them: *guard* sets each prop's frame by hand, and finds it as set until the prop's next frame is due, through a short step for each tuft not yet due and all night for the sails at rest, and each tuft at its clock's frame once due (N11, N22, N23, N28). Movie Maker's frames are the same with and without the fix, 600 of 600 (P5).

**What else it costs.** Render times in the Meadows by day are on average 0.7 ms a frame more than `main`'s on the CPU and 0.6 on the GPU, less than the head's three runs differ from each other, 1.1 and 1.4 ms (P3); World has about 900 more nodes there (P4). On the Web, P9 read the Meadows' frames a second against `main`'s, in Chrome and Firefox, by day and at night. The Fold4's frame rate in the Meadows is read on the device (§6.4, §8).

### 5.7 The rules and the docs (B9; Q11; E13)

The light's rule says to draw the world as by day, and to brighten nothing but with ADD glows over the veil; DN chose no headlights. This plan's PR amends both rules, so that PR 1 is reviewed by them (Q11):

- **`AGENTS.md`:52**, the Light rule, gets after its first sentence: "The one exception is the car's headlights, whose material brightens the road in their cone while they are on, before the veil darkens it (HEADLIGHTS_PLAN.md §5.2)."
- **`.github/instructions/light.instructions.md`:9**, the Light bullet, ends with: "Only the car's headlights brighten anything before the veil darkens it: `Headlights`' material, on `RoadLayer` alone, raises the road's colour in their cone while they are on, so that it shows at most `HEADLIGHT_SHARE` of the way back to its day colour (HEADLIGHTS_PLAN.md §5.2, §5.3). `DayCycle.night_at()` gives the night that the headlights' switch and the props' rest clock follow (HEADLIGHTS_PLAN.md §5.1, §5.4, §5.5)." Its § are otherwise DAYNIGHT's (:7), so each cite names the plan.

The Lamps bullet's "never clips" is about the ADD glows, and stays. PR 4 notes the changes where they were made: docs/DAYNIGHT.md Q5 and docs/M5.md §5.6 each end with "now …" and their B#, and the rules' cites become `docs/HEADLIGHTS.md` (§4.4).

---

## 6. Verification

### 6.1 Checks and counts

The checks are `AGENTS.md` §3's five. `ci.yml` runs on pull requests, on pushes to `main` and by hand, so a push to an `hl/` branch starts none: each of the prototype's runs was started by hand, with `upload-builds`, to keep its Web build and APK, but for b337183's and 8c02110's, which change only tests. Each of HL's states marked Local ran all five with Godot 4.7.2, and every check passed: `lint.sh` printed `Success: no problems found`; `smoke.sh` printed `main`'s smoke line, `autopilot: tile 165, turns 35, area rural`, and no error line; and `git status --porcelain` printed nothing after. Shellcheck isn't installed locally; HL changes no shell script. `main`'s Local runs are GUT's alone; its CI runs passed all five. On PR 2's and PR 3's trees `make_props.gd` drew the bytes committed (§4.1 step 2). HL's states have 104 test scripts, where `main` has 103: `test_headlights.gd` is new.

| State | Where | Scripts | Tests | Asserts | GUT time | `test` job |
|---|---|---|---|---|---|---|
| `main` (4a50bb2) | Runs 44744015047, on its push, and 44760745838, by hand; Local, twice | 221 | 903 | 456,541 | 134.3 s, 185.1 s; 134.4 s, 135.9 s | 3 min 15 s, 4 min 10 s |
| The three, as first built (c0ea19a) | Run 44759598171 | 223 | 915 | 456,729 | 129.4 s | 3 min 24 s |
| B7's fix (d4fc744) | Run 44762833776 | 223 | 916 | 456,737 | 189.6 s | 4 min 20 s |
| B16's and B12's fixes (eac39f8) | Run 44770512924, which failed on *glow* (B15) | 223 | 918, 1 failing | 456,802, 1 failing | 235.3 s | 4 min 56 s |
| B15's fix (8e82633) | Run 44772810741; Local | 223 | 918 | 456,803 | 138.5 s; 146.7 s | 3 min 33 s |
| A value for *pier*'s variable (b337183) | Run 44781138441; Local | 223 | 918 | 456,803 | 125.3 s; 141.0 s | 3 min 16 s |
| *guard*'s test (8c02110), PR 3's code tree (7f2fd4c) | Run 44801072534; Local | 223 | 919 | 456,809 | 139.9 s; 141.6 s | 3 min 24 s |
| PR 1's tree (90be123) | Local | 223 | 912 | 456,700 | 161.4 s | |
| PR 2's tree (003c32b) | Local | 223 | 915 | 456,722 | 140.3 s | |

PR 1's and PR 2's trees were built as §4.1 says, as the commits ab44e26 and 778fa7e, which aren't pushed. GUT's time varies from run to run: in CI over HL's runs from 125.3 s to 235.3 s, and locally with what else runs. Run alone, one tree after another, it took 136.2 s and 134.5 s on `main`, 135.6 s on PR 1's tree, 140.3 s on PR 2's and 142.0 s and 140.1 s on b337183's; then, `main`'s and PR 3's in turn, 133.7 s, 140.2 s, 133.7 s and 140.9 s: 5.1% more than `main`'s (P10).

### 6.2 Negative cases

Each change below makes the tests named fail, and nothing else. A script, not committed, applied each to a clean worktree of 8c02110, whose tree is PR 3's, ran `tools/ci/run_tests.sh`, read GUT's summary, and wrote the file back as it was; N19, which changes the sheet, ran `import.sh` before the suite and after the restore. They ran two at a time, each lane in a worktree of its own (docs/agents/planning.md §4): GUT took 141.1–176.7 s. After each lane `git status --porcelain` printed nothing. Each PR's head runs its cases again (§4.1 step 4; E14).

**Short names.** `test_headlights.gd`: *on* `test_on_from_dusk_until_sunrise`, *switch* `test_they_turn_on_and_off_in_the_switch_time`, *hold* `test_into_a_zones_morning_they_stay_as_they_were_until_its_light_has_come`, *off* `test_off_without_a_clock_or_a_car_and_once_the_run_is_over`, *share* `test_the_road_in_the_cone_shows_a_share_of_its_day_light`, *cone* `test_the_cone_lights_the_road_ahead_of_the_car` and *material* `test_the_material_shows_the_cone_as_lit_works_it_out`. *night*: `test_day_cycle.gd`'s `test_the_night_is_from_dusk_until_sunrise`. `test_daylight_run.gd`: *lights* `test_the_headlights_light_the_road_from_dusk_until_the_run_ends`, *windmills* `test_the_windmills_rest_by_the_zones_clock` and *view* `test_the_light_changes_nothing_but_the_view`. `test_prop_scatter.gd`: *rest* `test_props_that_rest_at_night_slow_to_a_stop_and_start_again_by_day`, *pier* `test_the_props_that_the_pier_takes_away_stop_animating`, *frames* `test_each_prop_shows_the_frame_of_its_clock_though_updates_look_only_at_frames_that_start`, *guard* `test_an_update_sets_no_frame_before_the_next_starts` and *contract* `test_props_that_break_the_contract_are_errors_and_do_not_show`. `test_prop_art.gd`: *sways* `test_the_meadows_grass_sways`, *crop* `test_each_frame_is_cropped_to_its_props_pixels_apart_from_the_others` and *sums* `test_each_area_has_six_to_ten_props_some_animated`. *grass layout*: `test_prop_layout.gd`'s `test_the_meadows_grass_takes_only_ground_that_showed_nothing`. *glow*: `test_world_renderer.gd`'s `test_the_lamps_glow_over_the_veil_at_night`.

**PR 1's** (§4.2). `world/headlights.gd` unless named:

| N# | Change | Fails |
|---|---|---|
| N1 | On once the run is over: `update()` without `not sim.is_over()` | *lights*, *off*, *switch* |
| N2 | On and off at once, `level = 1.0 if on else 0.0` | *switch* |
| N3 | The gain without what the veil takes, `p_level * given` | *hold*, *share* |
| N4 | The gain whole while they switch, `given * (1.0 - kept) / kept` | *lights*, *share*, *switch* |
| N5 | The cone as if World were at the canvas's origin, `Transform2D.IDENTITY` for `to_canvas.affine_inverse()` | *cone* |
| N6 | The cone along the car's side, `aside` for `ahead` in `along` | *cone* |
| N7 | `world_renderer.gd`: the road without the headlights' material | *lights* |
| N8 | `world_renderer.gd`: `Ground` given it too, which its band sprites don't inherit, so no pixel changes: *lights* finds it on a node other than the road | *lights* |
| N9 | `day_cycle.gd`: `night_at()` without `fposmod()`, so that every hour past 24 or below 0 is night | *night* |
| N10 | `day_cycle.gd`: the night from `SUN_SET_HOUR`, not `DUSK_HOUR` | *hold*, *night*, *on* |
| N20 | Off as soon as the clock leaves the night: no `or catching_up` | *hold* |
| N21 | `catching_up` without `level > 0.0`, so that a zone entered before dusk turns them on while its light comes | *hold* |

**PR 2's** (§4.3). `world/prop_scatter.gd` unless named:

| N# | Change | Fails |
|---|---|---|
| N11 | The rest clock never slows, `_rest_clock += delta` | *rest*, *windmills*; on PR 3 *guard* too |
| N12 | They stop and start at once, `_rest_rate = rate` | *rest* |
| N13 | A run that starts at night starts them turning: the first rate 1 | *rest*, *windmills* |
| N14 | `world_renderer.gd`: `update()` without the zone's clock | *windmills* |
| N15 | `prop_def.gd`: `validate()` without its rule that only a prop that animates may rest | *contract* |
| N16 | `windmill.tres` without `rests_at_night` | *windmills* |
| N23 | No prop rests, `if false:` for `if placement.def.rests_at_night:` | *rest*, *windmills*; on PR 3 *guard* too |
| N24 | `update()` leaves the resting props as they are, `for shown: Shown in []:` | *rest*, *windmills* |
| N25 | The pier's props stay in the row's `resting` list | *pier*: they still change frames |
| N26 | The pier's props stay in the row's `animated` list | *pier*, as N25 |
| N27 | `test_prop_scatter.gd`: *pier*'s copy of the City given its props with `assign()`, as at e12562a, which changes the cached City's array too (B15) | *pier*, *glow* |

**PR 3's** (§4.4):

| N# | Change | Fails |
|---|---|---|
| N17 | `meadows.tres`: the grass first in the props list | *grass layout* |
| N18 | `grass.tres` without `frames = 4` and `fps = 3.0` | *crop*, *sways* |
| N19 | `assets/meadows/props.png`: the grass's fourth frame a copy of its third | *sways* |
| N22 | `prop_scatter.gd`: a prop's next frame a whole frame after `update()` looks at it, `clock + 1.0 / fps - NEXT_FRAME_EARLY` | *frames*, *guard*, *rest* |
| N28 | `prop_scatter.gd`: `update()` sets every animated prop's frame each frame, without its two `next_frame_at` guards (:131, :134). Each alone fails it too: without the first, by `_clock`, 1,141 frames set before their next started; without the second, by the rest clock, 35,640 mismatches over 60 steps | *guard* |

### 6.3 Editor warnings

The five checks report no GDScript warnings, and shadowing shows only in the editor (`AGENTS.md` §2). As docs/agents/checks.md §1 says, a temporary `override.cfg` raised the 37 warnings at level 1 to 2, errors, and `check_scripts.sh` loaded every script. On 8e82633 it found that *pier* read `scatter` before giving it a value (`UNASSIGNED_VARIABLE`, `test_prop_scatter.gd`:810): b337183 gives it one (§4.6), and without it 8c02110 has the warning again, at :868. On `main`, PR 1's and PR 2's trees, b337183 and 8c02110 it found only `main`'s: 4 `INTEGER_DIVISION`, in `world/greybox_atlas.gd`, `ui/main.gd`, `test_greybox_atlas.gd` and `test_iso.gd`, and 1 `UNUSED_VARIABLE`, in `test_road_generator_occupancy.gd`. As Godot reports only a script's first error, it ran again without `integer_division`, and found only the `UNUSED_VARIABLE`. The file was deleted after, and `git status --porcelain` printed nothing.

### 6.4 Verified only in CI or on devices

- **CI.** The five required checks on each PR, and the `test` job's time (§6.1).
- **The Web** (E12), by an agent, on each PR's build, served with M4's patch, which passes the URL's `arg`s to the game (docs/agents/checks.md §4):
  ```bash
  gh workflow run ci.yml -R pompomon/roadgame --ref <branch> -f upload-builds=true
  rm -rf /tmp/roadgame-web
  gh run download <run id> -R pompomon/roadgame -n web -D /tmp/roadgame-web
  sed -i 's/"args":\[\]/"args":["--"].concat(new URLSearchParams(location.search).getAll("arg"))/' \
    /tmp/roadgame-web/index.html
  python3 -m http.server -d /tmp/roadgame-web 8000
  ```
  Open `http://localhost:8000/?arg=--autopilot&arg=--seed=1&arg=--area=rural&arg=--hour=22`, and the others below, in Chrome and Firefox, driven by Playwright, headed under Xvfb, at 360 × 640, each run in a new context. A day lasts 120 s, so an hour 5 s. The times below are the game's, which steps at most 8 physics steps a frame: where Chrome on software GL draws under 7.5 frames a second, as in the City at night, at about 3 (P9), it runs behind the wall clock, so time a route from its zone's crossing. These times are `main`'s: if SP has landed, its 60 s days in Rural, the Meadows and the Desert, and its tunnel at turn 20 and bridge at 44, change them, here and on the Fold4, so work them out again. `--hour` starts every zone's clock at its hour (docs/DAYNIGHT.md §5.9), where without it each starts at 07:00 (docs/DAYNIGHT.md §5.4); `--area` starts without the area's set piece (docs/ZONE_SELECT.md Q4). Post what each shows and the console's errors, by browser, in a PR comment.
  - **PR 1.** That Rural run, about 150 s: the cone lights the road ahead from the start, through the turns, and nothing else; it fades off at 06:00, about 40 s in, and on at dusk, about 102.5 s in; 130–134 s in, just after 00:00, it lights the bridge's deck into the Meadows, whose clock starts at 22:00 too, so it stays on. The tunnel and the hold: `--seed=12345 --hour=11`, without `--area`: the City's dusk 37.5 s in; its tunnel into Rural about 58 s in, at about 22:36, a faint warm wedge on its floor under dark rock (B19); then Rural's clock starts at 11:00, and the cone stays on while the light comes, about 2.3 s, and fades off (B7). With `--play --hour=22` for `--autopilot`: the car misses its first turn, the run ends, and the cone fades out.
  - **PR 2.** The same Rural run: the windmills stand still from the start, as a run that starts at night starts them still (Q8); they start turning at about 40 s, over 3 s, and slow to a stop over 3 s from about 102.5 s.
  - **PR 3.** The Meadows, `--seed=1 --area=meadows`, with `--hour=12` and `--hour=22`: the grass sways, and nothing flickers; and the frames a second against `main`'s build, as P9 read them.

  A PR's build stays current while `git diff --name-only <built> HEAD -- . ':!tests' ':!addons/gut' ':!*.md'` prints nothing, so a fix to tests or words needs no new one: 8e82633's build, of run 44772810741, is current for PR 3's tree.
- **The Fold4** (E11, E12), by the owner, on the cover screen and the inner one, and through a fold. PR 3's debug APK has all three, so one check does for all: `rm -rf /tmp/roadgame-apk && gh run download <run id> -R pompomon/roadgame -n "android-Android APK" -D /tmp/roadgame-apk`, then `adb install -r /tmp/roadgame-apk/roadgame-debug.apk`. The APK takes no arguments: in a debug build, the title's Start button chooses the area (docs/ZONE_SELECT.md; IP :178). Until the save says it's done, Play starts a run with the tutorial (docs/TUTORIAL.md §5.6): if the banner reads "Tutorial", finish it, 12 correct turns in a row. Each zone's clock starts at 07:00 as the car enters it, so its night comes 57.5 s later and lasts until 115 s. Each route on both screens:
  1. **Rural.** Start in Rural: by day the windmills turn. At 57.5 s the cone fades on and lights the road ahead through the turns, and not the props or the ground; the windmills slow to a stop over 3 s. Fold or unfold the phone: the cone stays with the car. At 115 s, 06:00, the cone fades off and the windmills start again.
  2. **Pause and leave.** At night, with the cone on and the windmills still, pause and resume, then leave the app and come back: the cone and the sails are as they were.
  3. **The run's end.** At night, take a wrong turn: the run ends, and the cone fades out in 0.5 s.
  4. **Into the morning.** Start in the City, and drive into Rural just after its dusk, at about 58 s and 18:36, through the tunnel: the cone stays on until Rural's 07:00 light has come, about 1.9 s, then fades off (B7).
  5. **The Meadows.** Start in the Meadows: the grass sways, and nothing flickers, by day and from 57.5 s at night. Read the frame rate there by day and at night, from the APK below, with `adb logcat -s godot | grep "Project FPS"`: not a blocker (E11; IP :203).

  These routes reach the tunnel only at dusk, and the bridge, about 130 s into Rural, by day. See them at night in PR 3's Web build, served as above, in the Fold4's Chrome after `adb reverse tcp:8000 tcp:8000` (docs/agents/checks.md:67): `&arg=--seed=12345&arg=--hour=11` for the tunnel, at about 22:36, and `&arg=--area=rural&arg=--hour=22` for the bridge, just after 00:00. A browser's frame rate isn't the APK's, so it is a hint.

  **An APK that prints its frame rate** (IP :203). An agent builds it from PR 3's head, on a branch that never gets a PR: in a worktree of `hl/3-grass`, add `settings/stdout/print_fps=true` under `[debug]` in `project.godot`, commit it on a new branch `hl/fps`, push, and run `gh workflow run ci.yml -R pompomon/roadgame --ref hl/fps -f upload-builds=true`. PR 3 links the run, whose APK logs `Project FPS: <n> (<ms> mspf)` once a second, after its first few (Godot 4.7.2 `main/main.cpp`:5121–5129), under logcat's `godot` tag.

### 6.5 Measurements

The probes ran with Godot 4.7.2, headless unless they say otherwise; they aren't committed. "The head" is 8e82633, whose files are PR 3's but for b337183's and 8c02110's changes to `test_prop_scatter.gd`. Movie Maker ran `xvfb-run godot --write-movie <dir>/f.png --fixed-fps 60 --quit-after 600 -- --autopilot --seed=1 --area=<area> --hour=<hour>`: 600 frames, 10 s, at 360 × 640, with software GL on 2 CPUs.

| P# | What | Result | Used by |
|---|---|---|---|
| P1 | The road alone: Movie Maker at 22:00 in Rural and the City, with the head (a), with `HEADLIGHT_SHARE` 0 (b), and as b with the road drawn over all else, at `z_index` 4000 and in magenta through `self_modulate` (c). A pixel lit is one where a and b differ; the road's, one where c and b do | Rural: 600 of 600 frames lit, 3,584 px a frame on average, 4,721 at most, 2.05% of the view; no lit pixel darker; the largest step 49 of 255; none off the road. The City: 600 of 600, 2,656 px, 4,375 at most, 1.90%; none darker; the largest step 39; none off the road. A first mask missed 118 of the City's road pixels, under see-through buildings (§4.7 F5). Runs are repeatable: `main` twice, the same bytes in both areas. b against `main`: the City's 600 frames the same bytes, and Rural's 188, as its windmills rest | §5.2, B4, B11, E5 |
| P2 | By day: Movie Maker at 12:00 in the City, Rural and the Meadows, the head against `main` | The City and Rural: `main`'s bytes in 600 of 600 frames. The Meadows: none of 600, by up to 1,533 px; without the grass, 598, the others by 1 and 3 px. `main`'s code with the head's sheet gives the no-grass frames in 600 of 600, and differs from `main` in those two: the sheet's new width | §5.3, E5, E10, the header |
| P3 | Render times: Movie Maker's average CPU and GPU ms a frame, at 22:00 in the City and Rural and at 12:00 in all three, on `main` and the head, most of them twice | CPU/GPU, `main`'s runs, then the head's. At 22:00, the City 26.16/25.02 and 22.78/21.88, then 22.51/21.73 and 22.14/21.33; Rural 11.21/12.51 and 12.27/13.63, then 11.91/13.30 and 11.70/12.99. At 12:00, the Meadows 5.68/7.46 and 5.79/7.52, then 6.45/7.99, 6.93/8.79 and 5.81/7.41; the City 9.80/12.13, then 10.67/13.33; Rural 7.49/9.76, then 7.06/9.10. No error line | §5.3, §5.6, E11, the header |
| P4 | The Meadows' props: the main scene with the autopilot at `--fixed-fps 60`, seeds 1–3, twice each; World's `_process()` timed line by line, and the props counted every 30 frames from 2 s to 40 s | `PropScatter.update()` a frame: `main` 92–97 µs, 94.3 on average; with the grass, c0ea19a's loop, 585–636, 615.8; e12562a's 528–572; with `next_frame_at` but not e12562a's lists, 235–248; eac39f8's, both, 178–193, 184.2. A headless frame's whole time: `main` 192–204 µs, c0ea19a's loop 727–786, eac39f8's 306–328. In view, 12.6–13.0 grass tufts on average, 22 at most. In the rows, 619–667 animated props on average, 972 at most, against `main`'s 32.5–33.7 and 50; 1,264–1,302 props shown, against 667–682; World's nodes 3,322–3,426, against 2,395–2,552 | §5.6, B12, E11, the header |
| P5 | Whether e12562a's and eac39f8's changes change a frame: Movie Maker on d4fc744 and on the head, in the Meadows at 12:00 and in Rural at 18:00, through its dusk | 600 of 600 frames the same bytes in each | §5.6, E10 |
| P6 | Clipping: the gains at `LIGHT_NIGHT` and `LIGHT_DUSK`, against each area's road sheet, texel by texel; and the largest share that clips nothing | Gains (0.83, 0.60, 0.18): channels above (139.5, 159.6, 217) of 255 clip. In the `ROAD` and `BRIDGE` rows, 11.25% of the opaque pixels, exactly the lines'; in `TUNNEL`'s none; in `DEAD_END`'s, a debug view, 92.76%. A clipped line falls short by up to 61 levels a channel in the City, 23 in Rural, 61 in the Meadows, 77 in the Village, 80 in the Desert and 61 on the Coast. The City's lines, (219, 219, 204), show (107, 122, 173) in the cone, where (168, 168, 173) was meant, and (92, 105, 147) outside it; the Village's, (240, 240, 232), show (107, 122, 184), and (101, 115, 167) outside. At `LIGHT_DUSK` the gains are (0, 0.21, 0.42), and the same lines clip, but on Rural's road. A share of 0.0326 or less clips nothing that a run shows, at any light; above it the Desert's road lines' red, 244, clips at `LIGHT_NIGHT`, above 0.0453 the Village's, 240, above 0.119 the other roads' lines and each bridge's, and above 0.362 Rural's road's. At 0.0326 the night's red in the cone is 0.44 of its day's, and green 0.50 | §5.3, §5.4, B8, B19 |
| P7 | Into a zone's morning: the road's red in the cone, entered at the night's light, were the headlights off at once; and when the autopilot leaves the City on `smoke.sh`'s seed | From 0.768 of its day's to 0.545 in 0.5 s, while the light rose 0.125 at `LIGHT_MAX_RATE`, then up again with the light. The City left 58–59 s in, at about 18:40 | §5.4, B7 |
| P8 | Whether HL merges with SP's prototype: 8c02110 merged with `sp/prototype`'s 98ffdd5, and the five checks on the merge | Clean: Git merges `areas/meadows.tres`, `config/tuning.gd`, `test_daylight_run.gd` and `test_prop_scatter.gd`, tree a65b957. All five checks passed: 223 scripts, 920 tests, 523,429 asserts, GUT in 141.8 s; `smoke.sh` printed SP's own line, `autopilot: tile 177, turns 32, area rural`. SP's days in Rural, the Meadows and the Desert last 60 s | §4.5, the header |
| P9 | The Web: the head's build (run 44772810741) and `main`'s (run 44760745838), served as §6.4 says, with Playwright 1.66 and `--autopilot --seed=12345`; frames a second over 10 s from `requestAnimationFrame`, after 15 s, one run each | Chrome on software GL, the head's, then `main`'s: Rural at 22:00 10.4 and 11.9; the City at 22:00 3.1 and 2.9; the Meadows at 12:00 7.8 and 9.4, at 22:00 6.9 and 6.5. Firefox: 59.0 and 58.8; 50.4 and 51.1; 58.8 and 58.7; 58.8 and 58.5. No error from the game; both builds' runs logged only the software GL's and the browsers' usual notes (docs/M4.md §6.6) | §5.3, §5.6, B17 |
| P10 | GUT's time: CI's `test` job, and `run_tests.sh` locally in each tree's worktree alone, one after another, the load under 2: `main`, PR 1's and PR 2's trees and b337183, then `main` and b337183 again; later `main` and PR 3's tree in turn, twice | In CI, over HL's runs, 125.3–235.3 s, and `main`'s 134.3 s and 185.1 s (§6.1). Alone: `main` 136.2 s and 134.5 s; PR 1's tree 135.6 s; PR 2's 140.3 s; b337183, PR 3's but for *guard*, 142.0 s and 140.1 s, 4.2% more than `main`'s. In turn: `main` 133.7 s and 133.7 s, PR 3's 140.2 s and 140.9 s, 5.1% more, 4.9% and 5.3% run by run. Each with its counts in §6.1, and `git status --porcelain` empty after. Beside other work: up to 161.4 s in a five-check run (§6.1), and 176.7 s in a negative case's (§6.2) | §6.1, §8, E11, the header |
| P11 | The tunnel at night: Movie Maker, `--autopilot --seed=12345 --hour=11`, 3,600 frames, from the City into Rural | Exit 0, no error line. In the tunnel, a faint warm wedge on its floor; the rock, at `z_index` 1, stays dark over it | §5.4, B19 |
| P12 | The merges after each squash: `git merge-tree --write-tree` of each PR's tree with `main` once the PR below it has squashed, with and without the merge-up first | PR 2's conflicts in `test_daylight_run.gd`, PR 3's in `prop_scatter.gd` and `test_prop_scatter.gd`. stacks.md step 5's `-X ours` gives exactly 003c32b and 7f2fd4c | §4.5 |

---

## 7. Owner actions

| When | Action | How |
|---|---|---|
| On this plan's PR | Answer Q1–Q12, or take their defaults; then squash it, which approves the plan and brings in the amended rules (Q11) | §3. It has `needs-owner`, as it changes `AGENTS.md` and `.github/` |
| On PR 3 | E12 on the Fold4, on both screens and through a fold, and E11's frame rate | §6.4's five routes on PR 3's APK, which has the three, past the tutorial, on both screens; the tunnel and the bridge at night in PR 3's Web build in the Fold4's Chrome; the frame rate from `hl/fps`'s APK. If the frame rate in the Meadows drops, say which of §8's changes to make |
| To land HL | Agents land PR 1, then PR 2, each once its gate passes. The owner lands PR 3 once E12 passes, then PR 4, which starts from `main` once PR 3 has merged (§4.4, §4.5) | Squash each. Before deleting a merged PR's branch, retarget the next PR to `main`: PR 1 before `hl/plan` goes, PR 2 before `hl/1-headlights`, PR 3 before `hl/2-windmills` |
| After PR 4 | Tag the prototype, which this plan cites, and delete the `hl/` branches | `git fetch origin hl/prototype && git push origin FETCH_HEAD:refs/tags/archive/hl/prototype`, then `git push origin --delete hl/plan hl/prototype hl/fps hl/1-headlights hl/2-windmills hl/3-grass hl/4-docs`, less any already deleted (docs/agents/planning.md §6) |

---

## 8. Risks

| Risk | Impact | Mitigation |
|---|---|---|
| The Fold4 drops frames in the Meadows | The grass adds about 600 animated props to the rows, about 13 in view, and about 900 nodes to World (P4). On the desktop `update()` takes about twice `main`'s time, a headless frame 306–328 µs against 192–204, and render times differ from `main`'s by less than its runs do (P3, P4). A phone's CPU is slower | E11 reads it on PR 3's APK (§6.4). If it drops: a lower density, or fewer frames a second (Q10); or the grass in the ground's tiles (§9) |
| The night is hard to reach on the Fold4 | The APK takes no `--hour`, and a zone's night comes 57.5 s after the car enters it | §6.4's routes reach it 57.5 s into a zone, from the title's Start in a debug build; the tunnel and the bridge at night only in PR 3's Web build in the Fold4's Chrome, whose frame rate is only a hint |
| The road's lines clip at night (B8) | In the cone the lines, 11% of the road's pixels, show dimmer than meant and of another hue (P6) | Q6 takes it for a cone that shows. Only a share of 0.0326 or less clips nothing in a run, and it barely shows (§5.3, P6); an ADD pass masked to the road would light the lines as meant (§9) |
| SP lands first | Its 60 s days in Rural, the Meadows and the Desert bring the night, the hold and the windmills' rest twice as often; its PRs change 4 of HL's files | At other lines: the merge with its prototype is clean, and the five checks pass on it (P8). Simulate each merge of `main` first (§4.5) |
| GUT's time in CI | It varies from 125.3 s to 235.3 s over HL's runs, and `main`'s took 134.3 s and 185.1 s (P10) | E11 compares a PR's run with `main`'s longer, 185.1 s, not with one run: PR 3's tree took 139.9 s. If a PR's run takes longer, re-run it, and compare GUT's time locally, run alone, with `main`'s (P10) |
| The merges after each squash conflict | PR 2's in `test_daylight_run.gd`, PR 3's in `prop_scatter.gd` and `test_prop_scatter.gd` (P12) | While nothing else lands in between, `-X ours` gives exactly the PRs' trees; otherwise resolve them by hand, and run the five checks on the merge (§4.5) |
| The hold reads badly | Into a zone's morning the cone stays on for up to about 2.3 s, while the light comes (B7) | With the clock's 07:00 start, the road in the cone never dims; once the light has come they light nothing more than the day does, and fade off in 0.5 s. A zone that `--hour=` starts in a tinted light can dim it to that light, if the light comes outside the night, as each sunrise does (§5.4) |
| The shader runs only where Godot draws | Headless GUT draws nothing: *cone* and *material* check `lit()`, the CPU's copy of the cone, and that the shader has its parameters | P1 and P9 saw the light drawn, in Movie Maker and in both browsers; §6.4's checks look again on each PR's build |

---

## 9. Notes for later work

- **Lamps that glow** (B18, Q7). The car's painted headlamps darken with it at night. A glow in `Lamps`, over the veil, as the street lamps have, would show them lit.
- **The ground or the props in the cone** (Q1). The ground's band sprites, each band and its edge, could take the road's material (`world_renderer.gd` `_add_band()`), and be lit as the road is. A prop's pixels stand above the ground under its foot, so the cone would have to be worked out at each prop's foot, or added over the veil, as Q4's ADD glow would add it, masked to the cone.
- **The lines lit as meant** (B8). An ADD pass over the veil, masked to the road's lines in the cone, would show them at their share of the day's light.
- **Other props that rest at night** (Q9). Any prop that animates can rest, by `make_props.gd`'s `RESTS`; of the six others, the traffic light, the pond, the dune grass, the tumbleweed, the smoky house and the grass, none does.
- **A carpet of grass** (Q10). Grass in the ground's tiles, animated by the `TileSet`, would cost no sprite, so it could be denser.
- **Physics interpolation** (IP :177). The cone follows `CarSim.pos`, as the car's sprite does now. If M7.5 interpolates the sprite, the cone should follow the sprite's drawn position.
- **M7.5's checklist** (IP :196–206). The cone through the turns, the tunnel and the bridge, the windmills at dusk and dawn, and the grass, on both screens; the frame rate in the Meadows (IP :203).
