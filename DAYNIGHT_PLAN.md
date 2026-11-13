# Day and Night: Sun and Moon Light in the Zones — Detailed Plan

Status: draft, for the owner's review · 2026-11-13 · Step 0 done: every file of the three PRs built and verified on `dn/prototype` (§4.1, §6) · Internal review done: six fixes, one declined, and two more from a follow-up review (§4.6) · Q1–Q14 have defaults, which this plan follows until the owner answers (§3) · Scope: a light that follows the sun and the moon through a 24-hour day in each zone, with the clock reset as the car enters each zone; visual only. This plan calls the work DN. It comes after RG (#54–#57) and ZS (#60, #61), and doesn't depend on M7 (Ship) or HB (#62), which may land before or after it (§4.5).

The owner asked: "create a detailed implementation plan for sun/moon light movement in the zones. Each zone resets the clock, and sunlight / moonlight cadence is zone-specific, starting with 2 minute for full 24h cycle in each zone. Sun/moon only affects visual part of the scene, audio remains separate. Current visuals could be used as the sunlight version without additional changes. The transition from sun to moon is gradual, not abrupt."

**Verified.** As for M2–M6 and RG, step 0 built every file that the PRs add or change on a prototype branch before this plan was final (§4.1). The five checks pass on each PR's state (§6.1). Each of the 43 negative cases makes the tests it names fail (§6.2), after tests closed four gaps that the first run found and five findings of the internal reviews (§4.1, §4.6). The probes that need no device ran (§6.5), and each zone's time was measured with the autopilot (§5.8). Numbers marked ≈ are rounded; the rest are measured or exact.

Verified with:
- Godot 4.7.2-stable, the official Linux x86_64 build that CI's image has
- GUT 9.7.1
- gdtoolkit 4.5.0 on Python 3.12.3. No PR changes a shell script or a workflow, so shellcheck and actionlint have nothing new to check; CI's `lint` job runs them

**Precedence.** For DN, this document replaces `plan.md` §3.7, §5, §6, §7.1 and §7.2 wherever it marks a difference with **Δ** and its finding (C#, §2). PRs 1 and 3 fold the changes into `plan.md` (Q13). `IMPLEMENTATION_PLAN.md` (IP) stays as M0–M6 and RG left it: DN isn't one of its milestones.

**Reference code.** `dn/prototype` at 9198181, pushed for reference. It was built from `main` at 1047e17, then merged `main` at 528196e, with ZS, and took the internal reviews' fixes (§4.1, §4.6). It never gets a PR. Each PR takes the files of its commits:

| PR | Commits | What |
|---|---|---|
| 1 | 7e6e817, 21261af, 78cc8ae, 125b99a | The clock; the light catches up the straight way; the rate test measures across `enter()`; a day that isn't finite is refused, and `validate()` names a day long enough |
| 2 | ad4a9a3, 7e752bf | `ViewVeil`, legends' ambient, the smoke in every light; the veil's own test |
| 3 | 98bc558, 7982976, 257af7a, c9b65ed, 9198181 | Daylight in the game; its tests check that the zone's clock runs; the merge of `main`, where `ui/main.gd`'s list of arguments took both ZS's lines and DN's; the tests of each zone's own pace and of the sound on every frame; the sound test compares each player's gain and bus too |

The prototype has the code and the tests. Each PR also writes its docs (C14, §4).

**Prerequisites.** `main` at 528196e (ZS PR 1, #61). DN needs no repository setting, secret, asset or art.

Contents:
1. Goal and exit criteria
2. Review findings
3. Decisions and open questions
4. Work breakdown (3 PRs)
5. Design
6. Verification
7. Owner actions
8. Risks
9. Notes for later work

---

## 1. Goal and exit criteria

Goal: a day in each zone. The light on the scene follows the sun and the moon through 24 hours: the day, dusk, the night, dawn and the day again. Today's look is the day's, unchanged. Terms:

- A **zone** is an area (`AreaDef`, `plan.md` §3.6–§3.7): the City, Rural, Meadows, the Village and the Desert. The code says area; this plan says zone where it follows the owner's words.
- Each zone has a **clock**, which gives the **hour**, 0–24. It starts at `Tuning.DAY_START_HOUR`, 07:00 (Q1), as the car enters the zone, and runs a full day in the zone's `day_seconds`: 120 s in every zone to start with, so an hour takes 5 s.
- The **light** is the colour that the world is multiplied by: white by day, so that the day is today's look exactly; dawn's, dusk's and the night's colours at their hours; and eased blends between them (§5.2).
- **Daylight** is the node that shows the light: a veil like M6's legends' veils (`M6_PLAN.md` §5.5), over the whole view, that multiplies the world under it. It sits under the glows and the UI.

"Gradual" has two parts (§5.3). The light eases from one key colour to the next over hours of the clock, so dusk takes 15 s and dawn 12.5 s at 120 s a day. And the light shown never changes faster than `Tuning.LIGHT_MAX_RATE` a second in any channel, so when a zone resets its clock at night, the light brightens to the morning over 2.33 s, not in one frame.

| # | Exit criterion | Checked by |
|---|---|---|
| E1 | The day is today's look. From 07:00 to 17:00 the light of the hour is exactly white. So is the light shown, from a run's start, and in a later zone once it has caught up with the hour: 140 physics frames (2.33 s) after a reset from the night (E4). While it is white, Daylight's veil waits at `modulate.a` 0, which the canvas skips, so each frame is drawn as on `main` | `test_day_cycle.gd`: `test_the_day_is_exactly_white_from_seven_to_five`; `test_daylight.gd`: `test_by_day_the_veil_is_transparent_and_by_night_it_shows_the_light`; P4 (done: 600 frames identical to `main`'s) |
| E2 | The cycle (C1). The hour runs 24 h in `day_seconds`. At each key hour the light is that key's colour. Between two keys it eases from one to the other with no slope at either, so each channel only rises or only falls | `test_day_cycle.gd`: `test_the_hour_runs_round_the_clock_in_day_seconds`, `test_each_key_hour_has_its_light`, `test_between_keys_the_light_eases_in_and_out` |
| E3 | Zones (C6). Entering a zone starts its clock at `DAY_START_HOUR`, with the zone's own `day_seconds`. The argument `--hour=<h>` starts every zone of every run at hour h instead | `test_day_cycle.gd`: `test_entering_a_zone_starts_its_clock_at_the_start_hour`; `test_daylight_run.gd`: `test_each_new_zone_starts_its_clock_again`, `test_the_hour_argument_starts_every_zone_at_that_hour` |
| E4 | Gradual (C6, C7). No channel of the light shown changes by more than `LIGHT_MAX_RATE` × delta in a physics frame, also when a zone resets its clock. While the clock's light holds still, as it does for 50 s after each reset to 07:00, the light reaches it within 1 / `LIGHT_MAX_RATE` seconds, along the straight way; once there, it follows the clock's light exactly. `AreaDef.validate()` reports a `day_seconds` below `DayCycle.least_day_seconds()`, the shortest day whose light the rate can follow. Nothing flashes (WCAG 2.3.1) | `test_day_cycle.gd`: `test_the_light_shown_never_changes_faster_than_the_max_rate`, `test_after_a_reset_the_light_catches_up_and_then_follows_exactly`, `test_least_day_seconds_is_the_shortest_day_the_rate_can_follow`; `test_area_def.gd`: `test_validate_reports_a_day_too_short_to_follow`; `test_area_schedule.gd`: `test_the_game_schedule_is_valid` |
| E5 | Each run starts in the morning light at once, after a retry and from the title too: a new run is a cut, not a zone change | `test_day_cycle.gd`: `test_snap_shows_the_light_of_the_hour_at_once`; `test_daylight_run.gd`: `test_each_run_starts_at_once_in_the_morning` |
| E6 | The clock and the light stop when the run ends or the game pauses. They stay as they are behind game over and the title, until the next run (C8, Q6). The veil still follows the camera as it shakes | `test_daylight_run.gd`: `test_the_clock_stops_when_the_run_ends_and_while_paused`; `test_daylight.gd`: `test_in_the_games_frames_the_veil_follows_the_view_of_the_same_frame` |
| E7 | Visual only. The light changes nothing in the road, the car, the disasters, the HUD or the audio. The game's road digests, `smoke.sh`'s line and the audio tests stay as they are, and a run drives at night exactly as by day | `test_daylight_run.gd`: `test_the_light_changes_nothing_but_the_view`; `test_road_generator_determinism.gd`; `test_audio.gd`; `smoke.sh` (§6.1) |
| E8 | Daylight (C2, C10, C11). It covers every reference screen at every zoom and follows the view of the same frame. It multiplies, at `VEIL_Z`, whatever its parent's z. It darkens the ground, the road, the skid marks, the set pieces, the car, the props and the legends' parts, but not the glows or the UI | `test_view_veil.gd`: `test_the_veil_covers_every_view`, `test_the_veil_multiplies_at_veil_z_and_starts_hidden`; `test_daylight.gd`: `test_in_the_games_frames_the_veil_follows_the_view_of_the_same_frame`; `test_daylight_run.gd`: `test_the_veil_darkens_the_world_but_not_the_glows_or_the_ui`; P1 and P2 (done) |
| E9 | Legends at night (C4). A legend's veil darkens each channel only to the darker of its own colour and the light it plays in. By day a legend looks as on `main`. At night it never brightens anything, each channel ends at the darker of the two, never darker than both, and a veil with nothing left to darken isn't drawn | `test_legend.gd`: `test_at_night_a_veil_darkens_only_what_the_night_hasnt`; `test_disaster_director.gd`: `test_a_disaster_waits_for_the_car_to_stop`; `test_daylight_run.gd`: `test_at_night_the_disaster_plays_in_the_light_the_run_ended_in`; `test_disasters.gd` |
| E10 | The smoke still shows (C3). Over everything the world draws, and through a tunnel, its contrast in each key light is at least `SMOKE_CONTRAST` × the light's luminance, and so in every light the game shows | `test_car_controller.gd`: `test_the_smoke_shows_over_everything_the_world_draws`, `test_the_smoke_shows_through_a_tunnel` |
| E11 | The Web (C9). The veils change only their position, `modulate.a` and `self_modulate`, so they are never redrawn, and Chrome and Firefox log no WebGL error over a whole day | `test_daylight.gd`: `test_daylight_is_never_redrawn`; `test_disasters.gd`: `test_none_redraws_a_polygon`; P3 (done on the prototype's build, and again on PR 3's) |
| E12 | All five required checks are green, with §6.1's counts, and `smoke.sh` prints no error line. Each negative case makes the tests it names fail (§6.2). The editor reports no new warnings (§6.3) | PR checks; §6.1–§6.3, locally with Godot 4.7.2 on each PR's head |
| E13 | Manual, on the Web in Chrome and Firefox and on the Fold4, folded and unfolded. Dusk and dawn look gradual. The night is dark, but the road, the junctions and the car read well (Q10). A zone's reset brightens smoothly. Legends at night look as they do by day. The frame rate holds (P5) | §6.4, on PR 3 |
| E14 | `plan.md` §3.7, §5, §6, §7.1 and §7.2, `AGENTS.md`, and the comments that the PRs touch say what the code does (C14) | Review |

---

## 2. Review findings

Nothing in the game has a time of day, and the tools that Godot offers for one would break rules that M6 set for its legends. The findings, by severity, with the evidence on `main` (528196e) and the fix.

### High

| # | Finding | Evidence | Fix |
|---|---|---|---|
| C1 | **No light.** The scene is drawn as its art is, at every moment of a run. No node in the game tints the world: there is no `CanvasModulate` or `Light2D`, and no `modulate` but the fades of single items. `plan.md` speaks of the night only for M6's legends' colours | `ui/main.tscn` and `world/world.tscn` (nodes: World, Ground, SetPieces, RoadLayer, Skids, DisasterLayer, Props); `setpieces/tunnel.gd`:7 (a `CanvasModulate` deferred, C15); `plan.md`:204 | `DayCycle`, the clock and its lights (PR 1, §5.1–§5.3), and `Daylight`, the veil that shows them (PR 3, §5.5) |
| C2 | **Godot's usual tools darken what must stay lit.** A `CanvasModulate` tints every item on its canvas. That includes the ADD glows that light the dark in M6's legends, and the legends' MUL veils, which would then darken twice. A `modulate` on World does the same through inheritance. 2D lights need a `CanvasModulate` to make the dark they light, and each light adds a pass | `M6_PLAN.md`:560–561 (the veil at `VEIL_Z` 2, the glows at `GLOW_Z` 3 over it, "Over a veil, a glow lights the dark") | A MUL veil like the legends', between the world and the glows (§5.5); the other ways and why not (§5.10) |
| C3 | **The smoke's contract is absolute.** `test_car_controller.gd` asks that the smoke's luminance differ by `SMOKE_CONTRAST` (0.1) from every background, and through a tunnel. The night's light, of luminance 0.485, about halves every contrast: by day the thinnest passes with ×1.04 to spare, so at night it would fail | `tests/unit/test_car_controller.gd`:10, :144, :155, :179; step 0's margins (§5.7) | Scale the rule by the light's luminance, and check it in each key light. With today's art it then holds in a light of any colour (§5.7, Q12) |
| C4 | **Legends would darken twice at night.** A legend's veil multiplies by `VEIL_NIGHT`, (70, 80, 150), and the night's light by ≈ (107, 122, 184). Together that's ≈ (29, 38, 108), luminance 0.163: half of `VEIL_NIGHT`'s 0.325, which M6 tuned on the Fold4 (Q8 there), so its glows would stand in the black. A `VEIL_DUSK` legend would turn the night darker still | `M6_PLAN.md`:560; `disasters/legend.gd`: `_veil_color()` | Each channel darkens to the darker of the light and the veil: `min()` (§5.6) |

### Medium

| # | Finding | Evidence | Fix |
|---|---|---|---|
| C5 | **Zones differ in length.** At 120 s a day the night begins 65 s into a zone. With the autopilot, the City lasts 56–61 s and ends at dusk, and the Village 33–46 s and ends by day; Rural and Meadows show the night, and the Desert is endless. So a run's first night comes in Rural, ≈ 122 s in | `areas/schedule.tres` (the City at turn 0, Rural 34, Meadows 100, the Village 200, the Desert 220); step 0's times over 20 seeds (§5.8) | `day_seconds` per zone, 120 s by default as asked. Q3 asks whether the City and the Village get shorter days |
| C6 | **A reset would jump.** When the car enters a zone at 22:00, the clock goes back to 07:00. Showing the clock's light at once would turn the night into day in one frame: abrupt, against the request, and a 0.58 jump in red | §5.2's lights | The light shown follows the clock's light at no more than `LIGHT_MAX_RATE` (§5.3) |
| C7 | **A short day would change fast.** At 30 s a day, dusk to night takes 1.9 s | §5.3 | The rate caps it. `validate()` reports days shorter than the rate can follow: just over 55.68 s with §5.2's keys (§5.3) |
| C8 | **The clock after the run.** `main.gd` counts the distance only while the run is on (`_physics_process`, :85–87). If the clock ran on, the scene would change under game over and under a legend that took the light at its start | `ui/main.gd`:85–87; `disasters/disaster_director.gd`: `_start_disaster()` | The clock advances only while the run is on. The director takes the light when the run ends (§5.4, §5.6) |
| C9 | **The Web's Polygon2D bug.** In Godot 4.7.2 each redraw of a `Polygon2D` after its first raises WebGL errors (godotengine/godot#124726) | `AGENTS.md` §3; M6 S6, P2, P10 | Draw the veil once. Tint it by `self_modulate`, show it by `modulate.a`, move it by its position (§5.5) |
| C10 | **Physics order.** The camera pans and shakes in its physics step, at priority 0. A veil that moves before it is a frame behind (M6 N41) | `disasters/legend.gd`:19; `tests/unit/test_legend.gd`:94 | Daylight steps at `ViewVeil.PHYSICS_PRIORITY`, 1, as the legends do (§5.5) |
| C11 | **The veil is the legend's.** `Legend._made_veil()` and `_follow_camera()` are private. The name `Veil` is taken by Legend's enum | `disasters/legend.gd`:15, :126, :147 | `ViewVeil` in `world/` (PR 2). Legend and Daylight both use it (§5.5) |

### Low

| # | Finding | Evidence | Fix |
|---|---|---|---|
| C12 | **Devices take no arguments.** `--hour=` works in the editor, the tests and `smoke.sh` only. Godot 4.7.2's Android export strips them, and the Web's `index.html` passes none | M4_PLAN.md P4 | On devices, the night comes by playing, in Rural from the title's Start button in debug builds (ZS). A debug Web build can read `?arg=` as M4 P4's did (§6.4) |
| C13 | **World's children are pinned.** A test lists them | `tests/unit/test_world_renderer.gd`:376 | Daylight goes under Main, after Camera, not in World (§5.5) |
| C14 | **Docs.** `plan.md` §3.7 lists AreaDef's fields; §5, §6 and §7 have no light; `AGENTS.md` §3 has no rule for it | `plan.md`:117, :176, :212, :229, :247 | PR 1: §3.7. PR 3: §5.5 (new), §6, §7.1, §7.2 and `AGENTS.md` (§4.4) |
| C15 | **The tunnel's darkening is deferred.** IP M5 planned a darkening `CanvasModulate` for the tunnel. M4 (K18, Q4) and M5 (L26, Q2) put it off, and `tunnel.gd`:7 still mentions it. A `CanvasModulate` would break C2's rule | `IMPLEMENTATION_PLAN.md`:390; `setpieces/tunnel.gd`:7 | Nothing in DN. §9 says how a tunnel can darken through Daylight instead |

---

## 3. Decisions and open questions

The owner asked to be asked where needed. This plan was written by an agent working on its own, so each question has a default, and the plan follows the defaults until the owner answers in the plan PR (`AGENTS.md` §2). **Q3 matters most**: at the default 120 s, the first zone of every run, the City, ends at dusk, and the Village by day (§5.8). Q1 and Q10 come next.

| # | Question | Default (this plan) | Other answers |
|---|---|---|---|
| Q1 | What hour does a zone's clock start at? | 07:00, the first hour of full day. Every zone starts in today's look; dusk begins 50 s in, and the night 65 s in | 00:00, a literal reset: each zone starts at midnight, in the dark. 06:00: each zone starts at dawn, and its first 5 s brighten. An hour per zone |
| Q2 | How does a zone's reset look? | The light moves to the morning's at `LIGHT_MAX_RATE`: 2.33 s from the night, 1.93 s from dusk. A new run, after a retry or from the title, cuts to the morning at once | A cut at the zone's first tile as well. A slower fade (§5.3) |
| Q3 | What is per zone? | `day_seconds` alone: 120 s in every zone, as asked, so no `.tres` file changes. The lights and their hours are the same in every zone. Only Rural, Meadows and the Desert then show the night | Shorter days where zones are short: the City at 80 s and the Village at 56 s show each its night, for 12–18 s and 2–15 s (§5.8). Lights or hours per zone (§9) |
| Q4 | What does "movement" mean? | The light's colour and brightness, which follow the sun and the moon round the clock. Nothing on screen shows where the sun is | A soft shade that turns with the sun and the moon, as an optional PR 4 (§5.11). Shadows that turn with the sun, which need new art (§9) |
| Q5 | Lights at night? | None: no headlights or street lamps | Lamps as glows above the veil (§9) |
| Q6 | What does the light do after the run ends? | It stops with the clock. Game over and the title show the last run's road in its last light | The title goes back to day |
| Q7 | How do legends' veils mix with the night? | Each channel ends at the darker of the two (`min()`, §5.6). By day a legend looks as on `main`; at night, wherever its veil is darker than the night, it looks as it does by day | Multiply (C4: too dark). The legend's veil replaces the light |
| Q8 | A clock on the HUD? | None | A sun or moon icon, as art: Pixel Operator 8 has no such glyph (`AGENTS.md` §3) |
| Q9 | A setting to turn the night off? | None | A switch in Settings, saved by `SaveService`, for players who find the night hard to read |
| Q10 | How dark is the night? | `LIGHT_NIGHT` (0.42, 0.48, 0.72), ≈ (107, 122, 184), luminance 0.485. Dawn (0.92, 0.74, 0.78) and dusk (1.0, 0.72, 0.52) (§5.2). The smoke shows in a light of any colour (§5.7), so the owner can tune them freely on the Fold4 (E13) | Darker or lighter; bluer or greyer |
| Q11 | An argument to start at another hour? | `--hour=<h>`, for tests, the editor and `smoke.sh` (§5.9) | None |
| Q12 | How must the smoke show at night? | As by day, relative to the light: its contrast at least `SMOKE_CONTRAST` × the light's luminance (§5.7). The smoke stays black | The day's contrast in every light, with paler smoke at night |
| Q13 | Which documents change? | `plan.md` and `AGENTS.md`. IP stays as it is | IP too |
| Q14 | How does DN land? | This plan's PR, then 3 stacked PRs, before or after M7 and HB (§4.5) | One PR. After M7 |

---

## 4. Work breakdown

Step 0 is done (§4.1). Next come three stacked PRs (`AGENTS.md` §5). Each passes the five checks on its own and has its negative cases. Only PR 3 changes what the game shows. No commit on the prototype touches another PR's files, so each PR's code and tests are its files as they are at 9198181, `git checkout 9198181 -- <files>` on its branch. The PR then adds its docs.

| PR | Branch → base | What | Scripts | Test scripts | Tests |
|---|---|---|---|---|---|
| — | `dn/prototype` | Step 0: the three PRs' code and tests, the probes and the measurements (§4.1). Never a PR | — | — | — |
| 1 | `dn/1-cycle` → `main` | The clock: `DayCycle`, its lights and its rate, and `AreaDef.day_seconds` | +2 | +1 | +12 |
| 2 | `dn/2-night-ready` → `dn/1-cycle` | Ready for the night: `ViewVeil`, legends' veils in an ambient light, and the smoke in every light. Nothing changes on screen | +2 | +1 | +2 |
| 3 | `dn/3-daylight` → `dn/2-night-ready` | Daylight in the game, `--hour=<h>`, and the docs | +3 | +2 | +12 |

### 4.1 Step 0: the prototype (done)

On `dn/prototype`, from `main` at 1047e17:
1. **The constants' place.** `config/tuning.gd`:166–179, a block of their own after `CRASH_SHAKE_SECONDS` and before `# The City's legends.`, the first of M6's per-area comments (M6_PLAN.md §5.10). No name is taken, and none ends in `_HZ`, which `test_disasters.gd` checks.
2. **The states.** Each PR's state was built and committed (the header's table), and each later commit changed only its own PR's files.
3. **The checks.** The five checks pass on each state, with a clean tree (§6.1).
4. **The negative cases.** A script ran the cases on each PR's state (§6.2): 35, then 41 after the internal review and 43 after its follow-up (step 9). Its first run found four gaps, each now closed by a test:
   - N5. A jump inside `enter()`, between two `advance()`s, went unseen: the rate test compared the light before and after each `advance()`. It now compares each frame's light with the last frame's (78cc8ae).
   - N13, N14. No test at PR 2 saw a veil in `BLEND_MODE_MIX`, or with a relative z. M6's tests never checked the veil's blend mode, and their legends sit at z 0. `test_view_veil.gd` now checks both, under a parent at z 3 (7e752bf).
   - N26. Without `enter()`, no zone's clock started, so the test's helper that sets the hour left the clock at 07:00, and the new-zone test passed with nothing to reset. The helper now asserts the hour that it sets (7982976).
5. **The probes.** P1–P4 and P6 ran (§6.5), P3 on the prototype's Web build in Chrome and Firefox. P5 needs the Fold4, and P3 runs again on PR 3's build (§6.4). P7 runs only if the owner asks for PR 4 (§5.11).
6. **The measurements.** The autopilot's seconds in each zone, over 20 seeds (§5.8). The smoke's margins in each light (§5.7). The editor's warnings (§6.3).
7. **The new `main`.** ZS (#60, #61) merged while this plan was written. 257af7a merges `main` at 528196e into the prototype. Only `ui/main.gd`'s list of user arguments conflicted: ZS's lines stay as they are, and DN's `--hour` line goes in on its own after `--area`'s. The checks, the negative cases and the warnings then ran again on the new base (§6), and `hb/prototype` (578a030) merges with the prototype with no conflict (§4.5).
8. **This plan.** Corrected to match the build: the counts; the constants' place; `--hour=<h>`, in the form of `main.gd`'s other arguments; the ambient as an argument of `play_disaster()`; `ViewVeil.shade()`; the straight catch-up (§5.3); and the four tests above.
9. **The internal review.** gpt-6.1-sol reviewed this plan and the prototype at 7982976 (`AGENTS.md` §7). Of its seven findings, four changed the code or its tests, at 125b99a (PR 1) and c9b65ed (PR 3), and two this plan's text; one is declined (§4.6). A follow-up review of c9b65ed found two more: the sound test compared no player's own gain or bus, fixed at 9198181 (PR 3), and E1's time to catch up, which this plan gave in seconds, not in frames. The checks, the 43 cases, the warnings and the merge with `hb/prototype` then ran again (§4.5, §6).

### 4.2 PR 1 — The clock (`dn/1-cycle` → `main`)

The clock and its lights, with no node. Nothing in the game reads them yet, so nothing changes on screen.

| Area | Files | Change |
|---|---|---|
| Clock | `world/day_cycle.gd` (+ `.uid`) | New `DayCycle extends RefCounted`: `start_hour`, `day_seconds`, `seconds`, `light`; `enter()`, `snap()`, `advance()`, `hour()`, `target()`, `static light_at()`, `static least_day_seconds()` (§5.1–§5.3) |
| Tuning | `config/tuning.gd` | `DAY_START_HOUR`, `LIGHT_DAWN`, `LIGHT_DUSK`, `LIGHT_NIGHT`, `LIGHT_HOURS`, `LIGHT_COLORS` and `LIGHT_MAX_RATE`, in a block of their own (§4.1, §5.2) |
| Areas | `areas/area_def.gd` | `@export_group("Light")` after Audio (:60–64), with `day_seconds := 120.0`. `validate()` reports a day that isn't finite, or shorter than `DayCycle.least_day_seconds()` (C7). No `.tres` file changes: 120 is the default, which Godot doesn't save |
| Tests | `tests/unit/test_day_cycle.gd` (+ `.uid`) | 10 tests (below) |
| | `tests/unit/test_area_def.gd` | `test_validate_reports_a_day_too_short_to_follow`: the least day passes; 0.01 s less, and 0, are reported. The day that the message names, 55.69 s, passes, and a hundredth less is reported. `test_validate_reports_a_day_that_isnt_finite`: NaN, INF and −INF are reported |
| Docs | `plan.md` §3.7 | **Δ** `day_seconds` in AreaDef's block, under a Light group (C14) |

`test_day_cycle.gd`:
- `test_the_hour_runs_round_the_clock_in_day_seconds`: from 07:00 and from 22:00, after 1, 2, 4 and 7 quarters of a day, within 1e-6 h.
- `test_entering_a_zone_starts_its_clock_at_the_start_hour`: after 1,000 frames, `enter(60.0)` sets `seconds` to 0, the day to 60 s and the hour to 07:00. 15 s later it is 13:00.
- `test_each_key_hour_has_its_light`: the keys' hours rise within 0–24, there are as many colours as hours, and `light_at()` gives each key's colour exactly at its hour. 00:00 and 24:00 are `LIGHT_NIGHT`.
- `test_the_day_is_exactly_white_from_seven_to_five`: every 0.01 h from 07:00 to 17:00, `light_at()` is exactly `Color.WHITE` (E1); at 6.99 h and 17.01 h it isn't.
- `test_between_keys_the_light_eases_in_and_out`: in 100 steps through each segment, no channel moves against its way, and the first and the last step each move less than a tenth of a straight blend's step.
- `test_the_light_shown_never_changes_faster_than_the_max_rate`: in days of 120 s and of `least_day_seconds()`, 24 zones that last from half an hour to 23 and a half, so that the clock goes back to the morning from every hour. Frame to frame, `enter()`s included, no channel changes by more than `LIGHT_MAX_RATE` × delta + 1e-6.
- `test_after_a_reset_the_light_catches_up_and_then_follows_exactly`: from 22:00's light, after `enter()`, the light turns white no sooner than `floor(d / (LIGHT_MAX_RATE × DELTA))` frames and no later than `ceil(…) + 1`, where d is the largest channel difference. The extra frame is for sums of 1/60 s that fall short. On the way, every channel has gone the same share of its way, within 1e-4: the straight way. Then `light == target()` on every frame of a day.
- `test_snap_shows_the_light_of_the_hour_at_once`: at 00:00, 05:00, 06:30, 12:00, 18:00, 19:00 and 22:00.
- `test_least_day_seconds_is_the_shortest_day_the_rate_can_follow`: in a day of `least_day_seconds()`, the light of the hour changes by no more than the rate allows in any frame, within 1e-6; in 0.95 times it, in some frame it changes by more.
- `test_a_day_of_no_seconds_is_an_error_and_stops_the_clock`: `enter()` with 0, −5, NaN, INF and −INF seconds reports with `push_error()` (`assert_push_error`), and 10 s later the hour is still the start hour.

### 4.3 PR 2 — Ready for the night (`dn/2-night-ready` → `dn/1-cycle`)

Legends learn the light they play in, and the smoke's tests check every light. The ambient light stays white until PR 3, and in white every legend draws as on `main`: nothing changes on screen.

| Area | Files | Change |
|---|---|---|
| Veil | `world/view_veil.gd` (+ `.uid`) | New `ViewVeil extends Polygon2D`, with what `Legend._made_veil()` makes on `main`: the square, the MUL material, the absolute `VEIL_Z` and the transparent wait. `PHYSICS_PRIORITY`; `follow(p_camera)`; `shade(p_light)`, which hides the veil in white (§5.5, C11) |
| Legends | `disasters/legend.gd` | `_veil` is a `ViewVeil`, named `Veil`; `_made_veil()` and `_shown` go. `PHYSICS_PRIORITY` is `ViewVeil.PHYSICS_PRIORITY`. The beats `shade()` the veil, and `_follow_camera()` calls `follow()`. `_veil_color()` becomes `_own_color()`, and a new `_veil_color()` takes the ambient light into account, channel by channel (§5.6) |
| | `disasters/disaster_base.gd` | `var ambient := Color.WHITE`, after `stage` |
| | `disasters/disaster_director.gd` | `play_disaster(area, car, camera, ambient := Color.WHITE)` keeps the light until `_start_disaster()` gives it to the disaster, with `car`, `camera` and `stage`. `clear()` sets it back to white |
| Tests | `tests/unit/test_view_veil.gd` (+ `.uid`) | `test_the_veil_covers_every_view`, moved from `test_legend.gd`:56. `test_the_veil_multiplies_at_veil_z_and_starts_hidden`: under a parent at z 3, a new veil has a MUL material, draws at `VEIL_Z`, and waits at `modulate.a` 0 |
| | `tests/unit/test_legend.gd` | −1, moved. `test_at_night_a_veil_darkens_only_what_the_night_hasnt`: for both kinds of veil, in white, dawn, dusk, the night and halfway from dusk to night. At the end of the first beat, the light × the veil's tint is the darker of the light and the legend's colour in each channel, within 1e-6, and no channel of the tint is above 1. A veil with nothing left to darken, the dusk veil in the night's light, is never drawn; the others are |
| | `tests/unit/test_disaster_director.gd` | `test_a_disaster_waits_for_the_car_to_stop` plays in `LIGHT_NIGHT`, and asserts that the disaster gets it as its `ambient` |
| | `tests/unit/test_car_controller.gd` | `test_the_smoke_shows_over_everything_the_world_draws` and `test_the_smoke_shows_through_a_tunnel` check each key light, with the rule scaled by its luminance (§5.7). In white they check what they check on `main` |

### 4.4 PR 3 — Daylight (`dn/3-daylight` → `dn/2-night-ready`)

The visible change: Daylight in the main scene, run by `main.gd`.

| Area | Files | Change |
|---|---|---|
| Light | `world/daylight.gd` (+ `.uid`) | New `Daylight extends ViewVeil`: `cycle` and `camera`. At `PHYSICS_PRIORITY`, its `_physics_process()` calls `refresh()`, which follows the view and shades it with the cycle's light (§5.5) |
| Game | `ui/main.tscn` | A `Daylight` node, `%Daylight`, under Main after Camera (C13) |
| | `ui/main.gd` | `--hour=<h>` in the header's list of arguments. `@onready var _daylight`. `_ready()` gives it the camera, and `_parse_hour()`'s start hour to its clock. `_physics_process()` advances the clock while the run is on. `_on_area_changed()` enters the zone's clock. `_start_run()` snaps the light and refreshes Daylight after the first zone. `_on_disaster_triggered()` gives the director the light. `static _parse_hour()` (§5.4, §5.9) |
| Tests | `tests/unit/test_daylight.gd` (+ `.uid`) | 3 tests (below) |
| | `tests/integration/test_daylight_run.gd` (+ `.uid`) | 9 tests through `tests/helpers/main_scene.gd` (below) |
| Docs | `plan.md` | **Δ** §5.5 Day and night (new); §6: the audio doesn't follow the hour; §7.1: Daylight under Main; §7.2: `DayCycle`, `Daylight` and `ViewVeil` |
| | `AGENTS.md` | §1's layout: `world/` has the day's light. §3: the rule for light (§5.5) |
| | `DAYNIGHT_PLAN.md` | The status, §4.6 and §6.1's counts |

`test_daylight.gd`:
- `test_by_day_the_veil_is_transparent_and_by_night_it_shows_the_light`: at each key hour and halfway to the next, Daylight hides in white, and otherwise its `veil_tint()` (`tests/helpers/disaster_fixtures.gd`) is the cycle's light. Both cases occur.
- `test_in_the_games_frames_the_veil_follows_the_view_of_the_same_frame`: Daylight enters the tree before a camera that pans and shakes, so that the tree's order alone would step it a frame late. Over 10 of the engine's physics frames, in which the view moves more than 1 px each, the veil stays on the view's centre within 1e-3 px (C10).
- `test_daylight_is_never_redrawn`: a day shown a tenth of an hour per engine frame, 241 frames, with the low-processor sleep at 0, as headless frames otherwise sleep as if nothing was drawn. The veil shows on some frames and not all, changes its light more than twice, and hides again in the morning, with no `draw` after its first (C9).

`test_daylight_run.gd`:
- `test_each_run_starts_at_once_in_the_morning`: the first run is at 07:00, white, with the veil hidden. A run that the test sets to 22:00 ends in game over under the night's veil; Retry is at 07:00, white and hidden at once.
- `test_the_light_follows_the_clock_while_the_car_drives`: at `--autopilot --hour=17`, after 600 frames, the car is still in the City, the hour is 19:00 within a frame's step, the light is exactly `light_at()` of the hour, and Daylight shows it on the view's centre.
- `test_each_new_zone_starts_its_clock_again`: at 22:00, the sim's `area_changed` with Rural, sent as `tests/integration/test_area_start.gd`:103 sends it, sets the hour to 07:00 at once, but not the light. Frame to frame, the light changes no faster than the rate, turns white within 2.4 s, and the veil hides.
- `test_each_zone_runs_its_clock_at_its_own_pace`: at `--hour=17`, the sim's `area_changed` with a copy of Rural whose day lasts 60 s gives the clock that day. 600 frames later the hour is 21:00 within a frame's step, where 120 s would give 19:00, and the light is exactly `LIGHT_NIGHT`.
- `test_the_clock_stops_when_the_run_ends_and_while_paused`: paused, 30 engine frames don't change the hour. Neither do 60 simulated frames in DISASTER or 120 in GAME_OVER change the hour or the light. `simulate()` ignores the pause (§5.4), so there the state is what stops the clock.
- `test_the_hour_argument_starts_every_zone_at_that_hour`: `--hour=22`, `--hour=26` and `--hour=-1.5` start the run at 22:00, 02:00 and 22:30, in that hour's light at once, and a new zone at the same hour. `--hour=noon`, `--hour=` and `--hour=1e999` report an error (`assert_push_error`; for `1e999`, Godot's own "Exponent too high" too) and start at 07:00.
- `test_at_night_the_disaster_plays_in_the_light_the_run_ended_in`: at `--seed=1 --hour=22`, the run ends at the first junction, and the disaster gets the light shown as its `ambient`.
- `test_the_light_changes_nothing_but_the_view`: 1,200 frames of `--autopilot --seed=1` at `--hour=7`, then at `--hour=19`, the first freed before the second opens. Each starts in silence (`AudioDirector.stop_all()`), and `AudioDirector` is stepped with the run, before it, as the engine steps autoloads. On every frame the sound is the same: each bus's volume, mute, solo, bypass and effects; the music's and the ambience's cross-fades, with their tracks, weights and current deck; the loops that are on; each player's bus, pitch and whether it plays, and its gain and stream, but not what `AudioDirector` leaves from the last run until it uses the player again (an idle deck's gain and stream, and an effect player's stream); and the count of sounds played. Both runs end with the same tile, turns, distance, health, area and state, and played the same sounds, by id.
- `test_the_veil_darkens_the_world_but_not_the_glows_or_the_ui`: at `--seed=1 --hour=22`, once the disaster at the first junction shows: Daylight draws at `VEIL_Z`, absolute; under World, and in each set piece's scene under SetPieces, every MUL item draws at `VEIL_Z`, and every other item but the ADD glows below it; Daylight is on the world's canvas, and the HUD and the menus are on layers above it.

### 4.5 Landing

1. The plan PR (`dn/plan` → `main`), docs only, lands first, with the owner's answers to §3. Answers change the PRs before they open: a `.tres` file's `day_seconds` (Q3), a constant (Q1, Q10), or a test.
2. PR 1 targets `main`, PR 2 `dn/1-cycle` and PR 3 `dn/2-night-ready`. The owner squash-merges them in order. Before deleting a merged PR's branch, retarget the next PR to `main`: deleting `m6/plan` closed #46 (ROADGEN_PLAN.md:195). The next PR then merges its base's final state and `main`, as `AGENTS.md` §5 shows.
3. A review fix goes on the branch of the PR that adds the file, and is merged up (`AGENTS.md` §5).
4. M7. If M7's PRs land first, `dn/1-cycle` merges `main`, and the stack merges up; `git merge-tree` shows the conflicts first. Both may change `ui/main.gd` (`_ready()`, `_start_run()`), `ui/main.tscn`, `config/tuning.gd` and `AGENTS.md`. DN's lines are in blocks of their own: the constants after `CRASH_SHAKE_SECONDS`, Daylight after Camera, and in `main.gd` lines after the calls they follow. If DN lands first, M7 merges `main` as usual.
5. HB (#62), an off-road meter under the health bar. Its PR 1 changes `ui/main.gd`, one line among `_start_run()`'s signal connections, and `plan.md` §7.1's HUD line, two lines below PR 3's Daylight. `git merge-tree` of `hb/prototype` (578a030) and `dn/prototype` (9198181) is clean, and so is a `git merge-file` of the two §7.1 changes. Whichever lands second merges `main` as in 2.
6. #63 (`docs/faster-checks`) changes `AGENTS.md` §2, §4, §6, §7 and §9, and `tools/ci/run_tests.sh`. DN changes neither: PR 3's lines go in §1's layout and in §3, before **Legends** (§5.5). If #63 lands first, DN's PRs follow its checks.

### 4.6 Review fixes

The internal review of this plan (`AGENTS.md` §7) and the PRs' reviews add their fixes here, each with its tests and its negative case. gpt-6.1-sol reviewed the plan and the prototype at 7982976 as a rubber duck: nothing blocking, and seven findings. Six are fixed below; the seventh is declined after the table. Its follow-up review of c9b65ed found two more, neither blocking, both fixed: the last row for PR 3 and the last for the plan.

| PR | Change | Tests | Negative case |
|---|---|---|---|
| 1 | `enter()` and `validate()` took a day that isn't finite: with NaN the light would be NaN, and with INF the clock would stand still, unreported. `enter()` now reports it and stops the clock, as for a day of no seconds, and `validate()` reports "day_seconds isn't finite" | `test_day_cycle.gd`: `test_a_day_of_no_seconds_is_an_error_and_stops_the_clock`, also with NaN, INF and −INF; `test_area_def.gd`: `test_validate_reports_a_day_that_isnt_finite` | N36, N38 |
| 1 | `validate()`'s message named 55.68 s, but the least day is 55.680001… s, so a zone set to the day that the message named was reported again. The message now rounds up to the hundredth: 55.69 s (§5.3) | `test_validate_reports_a_day_too_short_to_follow`: the day that the message names passes, and a hundredth less is reported | N37 |
| 3 | No test gave a zone a day of its own: every area's lasts 120 s, so `_on_area_changed()` could `enter(120.0)` and pass. New test: a zone whose day lasts 60 s | `test_daylight_run.gd`: `test_each_zone_runs_its_clock_at_its_own_pace` | N39 |
| 3 | The test of the sound compared the tracks and the bus volumes once, after the runs, and never stepped `AudioDirector`: a bus muted at night, or a sound played at dusk, passed. It now steps `AudioDirector` with each run, from silence, and compares the sound on every frame and the sounds played (§4.4) | `test_daylight_run.gd`: `test_the_light_changes_nothing_but_the_view` | N40, N41; N33 still fails it |
| 3 | The test of the sound compared the buses and the cross-fades, but no player's own gain or bus: by night the engine's `volume_db` at −80, or the ambient decks on the Music bus, passed. Each frame now also compares each player's bus, pitch, whether it plays, gain and stream, but not what a player keeps from the last run (§4.4) | The same | N42, N43 |
| Plan | E1 said that the light is white from 07:00 to 17:00, but after a zone's reset the light shown takes over 2 s to get there (E4). E1 now says that the light of the hour is white then, and the light shown at a run's start, and in a later zone once it has caught up | None: docs only | None: docs only |
| Plan | §5.10's fallback, World's children tinted in place of a veil, would also dim the phantom bus's lamps: `Legend.play()` puts the standing bus under Props, with its ADD glows as its children. §5.10 now says so: the fallback breaks E8 and C2, and needs the owner's agreement. P3 passed (§6.5), so only P5 can call for it | None: docs only | None: docs only |
| Plan | E1 said that the light shown is white again within 2.32 s: the catch-up's time, with no frames. At 60 Hz it takes 140 frames, 2.33 s, as the last frame takes what's left, and the test allows a frame more (§5.3). E1 now gives the frames | None: docs only | None: docs only |

Declined: the review asked for `day_seconds = 120.0` in each area's `.tres`, rather than as the default in `area_def.gd`. Every tuning field of `AreaDef` has its default in the script, and Godot saves in a `.tres` only the values that differ from it: the City's file sets none of the driving values, and no area's sets `offroad_limit_tiles`. A zone that Q3 changes gets its line.

---

## 5. Design

### 5.1 The clock

`DayCycle` (`world/day_cycle.gd`, PR 1) is a pure `RefCounted`, like `CarSim` (D2): the clock of the zone that the car is in, and the light that it gives. Daylight holds one (§5.5). `main.gd` steps it in `_physics_process()` at 60 Hz while the run is on, and tests step it with a fixed `DELTA`. It draws no random numbers (IP §5.3). Only Daylight reads it, and `main.gd`, which gives its light to the director when a run ends (§5.6). So the road, the car and the audio can't depend on it (E7).

Each `AreaDef` gets `day_seconds`, in a group of its own after Audio:

```gdscript
@export_group("Light")
## Seconds for a full day of 24 hours in this area, whose clock starts again as the car enters it
## (DAYNIGHT_PLAN.md §5.1). Finite, and at least DayCycle.least_day_seconds(), so that the light
## never changes faster than Tuning.LIGHT_MAX_RATE.
@export_range(10.0, 600.0, 0.5, "or_greater") var day_seconds := 120.0
```

`validate()` reports a day that isn't finite, `"%s: day_seconds isn't finite"`, or a shorter one, `"%s: day_seconds is below %.2f" % [id, least]`, with its other problems. `least` is `least_day_seconds()` rounded up to the hundredth, 55.69, so that the day that the message names is long enough (§5.3). So `test_area_schedule.gd`'s `test_the_game_schedule_is_valid` fails for a zone whose `.tres` sets one (N11). 120 s is the default, which Godot doesn't write into a `.tres` file, so none changes.

The clock, as built. `light_at()` is in §5.2, and `least_day_seconds()` and `_distance()` are in §5.3.

```gdscript
class_name DayCycle
extends RefCounted
## A zone's clock and its light (DAYNIGHT_PLAN.md §5.1–§5.3). The hour runs from start_hour round
## the clock in day_seconds. The light shown follows the light of the hour, no faster than
## Tuning.LIGHT_MAX_RATE a second in any channel, so that it never jumps, also when a zone sets the
## clock back.

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


## Starts the clock of a zone whose day lasts `p_day_seconds`, at start_hour. The light shown
## doesn't jump: advance() moves it to the new hour's at the rate.
func enter(p_day_seconds: float) -> void:
	seconds = 0.0
	day_seconds = p_day_seconds
	if not is_finite(p_day_seconds) or p_day_seconds <= 0.0:
		push_error("DayCycle: a day of %.2f s; the clock stands still" % p_day_seconds)
		day_seconds = 0.0


## Shows the light of the hour at once: a new run is a cut.
func snap() -> void:
	light = target()


## Runs the clock for `delta` seconds, and moves the light shown toward the hour's, its farthest
## channel by at most the rate.
func advance(delta: float) -> void:
	seconds += delta
	var goal := target()
	var far := _distance(light, goal)
	var reach := Tuning.LIGHT_MAX_RATE * delta
	light = goal if far <= reach else light.lerp(goal, reach / far)


func hour() -> float:
	if day_seconds <= 0.0:
		return start_hour
	return fposmod(start_hour + 24.0 * seconds / day_seconds, 24.0)


## The light of the hour, which the light shown follows.
func target() -> Color:
	return light_at(hour())
```

- `seconds` sums steps of 1/60 s in a 64-bit float. After an hour in the Desert, which never ends, it is off by about 1e-7 s.
- `enter()` keeps the light shown, and `snap()` sets it. `_start_run()` calls `enter()` for the first zone, then `snap()` (§5.4).
- With `day_seconds` 0 the clock stands at `start_hour`: at boot, and after `enter()` has reported a day of no seconds. `advance()` still moves the light shown to that hour's.

### 5.2 The lights

Six keys round the clock. Between two keys, every channel eases from one key's colour to the next's, with the same weight.

| Hour | Key | Colour, 0–1 | ≈ 0–255 | Luminance | What it shows |
|---|---|---|---|---|---|
| 04:30 | `LIGHT_NIGHT` | (0.42, 0.48, 0.72) | (107, 122, 184) | 0.485 | The night ends; the sky starts to lighten |
| 06:00 | `LIGHT_DAWN` | (0.92, 0.74, 0.78) | (235, 189, 199) | 0.781 | A rose dawn |
| 07:00 | White | (1, 1, 1) | (255, 255, 255) | 1 | Full day: today's look |
| 17:00 | White | (1, 1, 1) | (255, 255, 255) | 1 | The day's end |
| 18:30 | `LIGHT_DUSK` | (1.0, 0.72, 0.52) | (255, 184, 133) | 0.765 | An amber dusk |
| 20:00 | `LIGHT_NIGHT` | (0.42, 0.48, 0.72) | (107, 122, 184) | 0.485 | Moonlight: blue, about half as bright |

The luminance is `Color.get_luminance()`'s: 0.2126 r + 0.7152 g + 0.0722 b. White is a key twice, so from 07:00 to 17:00 the light blends white with white, which `lerp()` gives exactly (E1). The colours are a first guess, which the owner tunes on the Fold4 (Q10). Changing them changes no code: `least_day_seconds()`, `validate()` and the tests follow.

They go in `config/tuning.gd`, in a block of their own after `CRASH_SHAKE_SECONDS` and before `# The City's legends.` (§4.1). No name ends in `_HZ`, so the flash test's check of `*_HZ` constants doesn't apply to them.

```gdscript
## Day and night (DAYNIGHT_PLAN.md §5.2): what Daylight multiplies the world by at the key hours of
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
```

```gdscript
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
```

At 120 s a day, an hour takes 5 s:

| Part | Hours | Seconds | Seconds into the zone |
|---|---|---|---|
| Day | 07:00–17:00 | 50 | 0–50 |
| Dusk | 17:00–20:00 | 15 | 50–65 |
| Night | 20:00–04:30 | 42.5 | 65–107.5 |
| Dawn | 04:30–07:00 | 12.5 | 107.5–120 |

### 5.3 Gradual

"Gradual, not abrupt" has two parts.

1. **Eased keys.** `smoothstep()` has no slope at either end, so the light leaves each key and reaches the next gently. Between two keys each channel only rises or only falls. Every channel takes the same weight, so the luminance, a sum of the channels with positive weights, also only rises or only falls between two keys.
2. **A rate.** The light shown moves toward the light of the hour, its farthest channel by at most `LIGHT_MAX_RATE` × delta in a frame (`advance()`, §5.1).

| Segment | Hours | Largest change | Steepest at 120 s | Least day |
|---|---|---|---|---|
| Night to dawn | 04:30–06:00 | 0.50, red | 0.100 a second | 48.00 s |
| Dawn to day | 06:00–07:00 | 0.26, green | 0.078 a second | 37.44 s |
| Day to dusk | 17:00–18:30 | 0.48, blue | 0.096 a second | 46.08 s |
| Dusk to night | 18:30–20:00 | 0.58, red | 0.116 a second | **55.68 s** |

The least days are to the hundredth. `Color`'s channels are 32-bit floats, so the night's red, 0.42, is 0.41999999, and the least day is 55.680001 s: `validate()`'s message names 55.69 s, a day long enough (§5.1).

A segment of `span` hours whose largest change in a channel is Δ is steepest at its middle, where `smoothstep()`'s slope is 1.5: 1.5 × Δ / (span × day_seconds / 24) a second. That stays within the rate R for days of at least 36 Δ / (span × R) seconds:

```gdscript
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


## The largest difference between `a` and `b` in a channel.
static func _distance(a: Color, b: Color) -> float:
	return maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b)))
```

- **Within a zone's day the rate never acts.** With `day_seconds` at least `least_day_seconds()`, the light of the hour moves by at most R × delta in a frame. Once the light shown has reached it, `far <= reach` in every frame, and the light shown is the light of the hour exactly. At 120 s the steepest change, 0.116 a second, is under half the rate. At exactly the least day, rounding may leave the light shown 1e-9 behind for a frame; the tests allow 1e-6.
- **After a reset the rate acts** (E4). For 50 s after each reset to 07:00, the light of the hour holds still at white. The light shown reaches it in (the largest channel difference) / R: 2.32 s from the night, 1.92 s from dusk's key. At 60 Hz that's 140 and 116 frames, 2.33 s and 1.93 s, as the last frame takes what's left; the test allows a frame more for rounding. If `--hour=` starts the zones in a segment that moves, the light of the hour moves more slowly than the rate, so the light shown still catches up, by the time the hour reaches the day or the night, which hold still.
- **The straight way.** `lerp()` moves every channel by the same share of its way, so on the way from the night to the morning the light shown is a blend of the two, never a colour that neither is. Moving each channel at the rate on its own (`move_toward()`) would leave that line: from the night, blue would reach white in 1.12 s and red in 2.32 s, with a pale blue between (N9).
- **It stays among the keys.** `light_at()` blends two keys, and `advance()` and `snap()` blend the light shown with that. So the light shown is always a blend of keys, with weights from 0 to 1 that add up to 1. A rule that is linear in the light and holds at each key then holds in every light that the game shows (§5.7).
- **Nothing flashes** (WCAG 2.3.1, M6_PLAN.md §5.6). A flash is a pair of opposite changes in luminance of a tenth of white or more, and more than 3 flashes in a second fail. No channel of the light changes faster than 0.25 a second, and the luminance's weights add up to 1, so a change of a tenth takes at least 0.4 s: at most 1.25 flashes a second, even if the light turned back each time. It turns only at keys and at resets, seconds apart. No light is a saturated red either, whose red share r / (r + g + b) WCAG puts at 0.8: dusk's is 0.446.
- **A slower reset** (Q2). If the owner wants the reset to take longer, say 4 s, without longer days, `enter()` can start a cross-fade instead: for `LIGHT_RESET_SECONDS`, the light shown is the light at the reset eased to the light of the hour. With the light of the hour still, the fade's steepest change is 1.5 × 0.58 / 4 ≈ 0.22 a second, within the rate. It isn't in this plan's defaults.

### 5.4 Zones and runs

| Moment | Clock | Light shown | In `main.gd` |
|---|---|---|---|
| Boot, and the title before the first run | Stands at `start_hour` (`day_seconds` 0) | White; the veil hides | — |
| A run starts: `--play`, Play or Retry | The first zone's: `enter()` | The light of the hour at once: `snap()`, then `refresh()` | `_start_run()` |
| The run is on | `advance(delta)` in each physics frame | Follows the light of the hour | `_physics_process()` |
| The car enters a zone | `enter()`: back to `start_hour`, with the zone's `day_seconds` | Moves to the new hour's light at the rate | `_on_area_changed()` |
| The run ends: a wrong or missed turn, or a crash | Stops: the state isn't RUNNING | Stays. After a turn, the director gives it to the disaster as its `ambient` | `_on_disaster_triggered()` |
| Paused | Stops: the tree is paused, and the state is PAUSED | Stays | — |
| Game over, then the title | Stopped | Stays over the last run's road until the next run (Q6) | — |

`main.gd` as built, abridged: `...` stands for `main`'s code.

```gdscript
## --play; --area=<id> starts every run in that area, for tests and manual checks (M4_PLAN.md K10).
## --hour=<h> starts every zone's clock at hour h instead of the morning (DAYNIGHT_PLAN.md §5.9).
## A phone can't take them (M4_PLAN.md P4), so in debug builds the title's Start button chooses the
...

@onready var _camera: CameraRig = %Camera
@onready var _daylight: Daylight = %Daylight


func _ready() -> void:
	...
	_director.layer = _world.get_node("%DisasterLayer")
	_director.stage = _world.get_node("%Props")
	_daylight.camera = _camera
	_daylight.cycle.start_hour = _parse_hour(args)
	...


func _physics_process(delta: float) -> void:
	if GameState.state == GameState.State.RUNNING:
		GameState.distance = maxf(GameState.distance, _sim.progress)
		# The zone's clock runs with the run, and stops when it ends or pauses (DAYNIGHT_PLAN.md
		# §5.4). Daylight shows the light after the camera has moved.
		_daylight.cycle.advance(delta)


func _start_run(run_seed: int) -> void:
	...
	# Every run starts in an area too: the HUD names it, and M5's music starts with it (M4.3).
	_on_area_changed(_sim.area)
	# A new run is a cut: it shows the morning, or --hour's light, at once (DAYNIGHT_PLAN.md §5.4).
	_daylight.cycle.snap()
	_daylight.refresh()


func _on_disaster_triggered(junction: RoadTile, choice: int) -> void:
	...
	_end_run(CarSim.MISSED_TURN if choice == -1 else CarSim.WRONG_TURN)
	_director.play_disaster(area, _car, _camera, _daylight.cycle.light)


func _on_area_changed(area: AreaDef) -> void:
	...
	GameState.enter_area(area.id, maxf(first - 0.5, 0.0), _turns_before(first))
	# Each zone starts its clock again, at its own pace (DAYNIGHT_PLAN.md §5.4).
	_daylight.cycle.enter(area.day_seconds)
	EventBus.area_changed.emit(area)
```

- **Why `refresh()` too.** Retry and Play come as input, between physics frames. Without `refresh()`, the frame drawn before Daylight's next step would show the last run's light over the new run (N28).
- **The order in a frame.** The engine steps physics by priority, and at the same priority in the tree's order, a parent before its children. Main is the scene's root, at priority 0, so its `_physics_process()` advances the clock before the car steps. The car's step may enter a new zone: CarSim emits `area_changed`, and `_on_area_changed()` calls `enter()`. The next frame's `advance()` runs the new zone's clock, so its hour is at most a frame late, and the tests allow one `DELTA`. The camera steps at priority 0, and Daylight at 1, after it, so Daylight shows this frame's light on this frame's view (C10).
- **In tests.** GUT's `simulate()` steps a node and then its children in the tree's order, whatever their priority, and also while the tree is paused (`addons/gut/gut_to_move.gd`:72–92). So `main.tscn` puts Daylight after Camera, where the tree's order is right too; `_physics_process()` asks GameState's state, not the tree, whether the run is on; and `test_daylight.gd` checks the priority in the engine's own frames (§4.4).
- **Pause.** `GameState.pause()` pauses the tree (`autoload/game_state.gd`:58–61), so in the game nothing steps, and the state is PAUSED.

### 5.5 The veil

Daylight multiplies everything drawn under it by the light, as the legends' veils do (M6_PLAN.md §5.5): one square over the view, with a `CanvasItemMaterial` in `BLEND_MODE_MUL`, at `Tuning.VEIL_Z`, 2.
- The ground, the road, the skid marks, the set pieces, the props, the car and the legends' parts draw below `VEIL_Z`. The legends' glows draw above it, at `GLOW_Z`, 3, and the UI on its own `CanvasLayer`s. So the night darkens the world, but neither the glows nor the UI (E8). P1 listed World's canvas items by z while a legend played: 601 at 0, 2 at 1, the legend's veil at 2 and its 2 glows at 3.
- A pixel of colour c under the light L shows L × c, channel by channel.
- Two MUL veils commute: Daylight's and a legend's darken the world the same in either order, up to the rounding of 8 bits. P2 drew them in both orders: at most 1/255 apart in a channel (§6.5).

PR 2 moves the veil that `Legend._made_veil()` builds on `main` into a class of its own, which the legends and Daylight share:

```gdscript
class_name ViewVeil
extends Polygon2D
## A square over the view that multiplies what is drawn under it by its self_modulate: a legend's
## veil (M6_PLAN.md §5.5) and the night's (DAYNIGHT_PLAN.md §5.5). It covers the widest view at the
## smallest zoom. It is built once: its polygon, colour and offset never change, since on the Web
## each redraw of a Polygon2D after its first raises WebGL errors (M2_PLAN.md §5.7). It shows and
## hides by modulate.a, which needs no redraw, and waits transparent, which the canvas skips: a
## multiply ignores the alpha it draws with (M6_PLAN.md P10).

## A veil's physics step comes after those at the default priority, 0, such as the camera's, so
## that it follows the view of the same frame.
const PHYSICS_PRIORITY := 1


func _init() -> void:
	var half := Tuning.VEIL_HALF_SIZE
	polygon = PackedVector2Array(
		[Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half)]
	)
	var multiply := CanvasItemMaterial.new()
	multiply.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	material = multiply
	z_index = Tuning.VEIL_Z
	z_as_relative = false
	modulate.a = 0.0


## Centres the veil on `p_camera`'s view, shake included.
func follow(p_camera: Camera2D) -> void:
	global_position = p_camera.global_position + p_camera.offset


## Multiplies what is under the veil by `p_light`. White changes nothing, so the veil then hides,
## and isn't drawn.
func shade(p_light: Color) -> void:
	if p_light == Color.WHITE:
		modulate.a = 0.0
		return
	self_modulate = p_light
	modulate.a = 1.0
```

PR 3 adds Daylight:

```gdscript
class_name Daylight
extends ViewVeil
## The light of the zone's hour (DAYNIGHT_PLAN.md §5.5): a veil over the view that multiplies the
## world by the light that its clock shows. The legends' glows draw above it, and the UI on its own
## layer, so they stay as bright. By day the light is white and the veil hidden, so the frame is the
## same as before the day had hours. main.gd runs the clock: it starts it again in each zone, and
## stops it with the run.

## The zone's clock, and the light shown.
var cycle := DayCycle.new()
## The camera whose view the veil covers. main.gd sets it.
var camera: Camera2D


func _ready() -> void:
	process_physics_priority = PHYSICS_PRIORITY


func _physics_process(_delta: float) -> void:
	refresh()


## Covers the camera's view with the clock's light, at once.
func refresh() -> void:
	if camera != null:
		follow(camera)
	shade(cycle.light)
```

- **By day nothing changes** (E1). While the light is white, `shade()` sets `modulate.a` to 0, which the canvas skips, so the frame is today's, pixel for pixel. P4 compared 600 frames of `main` and of the prototype from the same seed: byte for byte the same. `Color`'s `==` is exact, and so is the day's white: `lerp()` of white with white gives exactly white, and `advance()` sets the light to the goal once it is within reach (§5.1).
- **No redraw** (C9, E11). Only the position, `modulate` and `self_modulate` change, and none of them redraws the polygon. `test_daylight_is_never_redrawn` counts the veil's draws over a day.
- **The same frame** (C10). Daylight's `_ready()` sets its priority. A legend sets its own, as on `main`, and moves its veil, a child, in its own step.
- **Where** (C13). In `main.tscn`, a child of Main after Camera, named `%Daylight`. Not in World, whose children `test_world_renderer.gd` pins. Its place in the tree doesn't change where it draws: it sets its global position, and its z is absolute. It must stay on the world's canvas: on a `CanvasLayer` it couldn't draw between the world and the glows (§5.10).
- **Not in the editor.** `daylight.gd` isn't a `@tool` script, so the editor never runs `_init()`, and `main.tscn` saves only the node, its script and its unique name.
- **Cost.** One more square over the view, drawn while the light isn't white: from 17:00 to 07:00, 14 of each 24 hours, and less where zones reset at 07:00. M6's legends draw a veil of the same size. P5 measures the frame time on the Fold4 and the Web.

PR 3 adds the rule to `AGENTS.md` §3, before **Legends**:

> - **Light** (DAYNIGHT_PLAN.md §5.5). Draw the world as by day. `Daylight`, a `ViewVeil` under Main, multiplies everything below `VEIL_Z` by the light of the zone's hour. At `VEIL_Z` draw only MUL veils, and above it only ADD glows; the UI is on layers of its own. Don't tint the world with a `CanvasModulate`, a `Light2D` or World's `modulate`: they would dim the glows and darken the legends' veils twice. A new veil is a `ViewVeil`. The light is visual only: no gameplay or audio code reads `DayCycle` (`test_daylight_run.gd`).

### 5.6 Legends at night

When a wrong or missed turn ends the run, the clock stops (§5.4). `_on_disaster_triggered()` gives `play_disaster()` the light shown as its `ambient`. The director keeps it while the car stops, and gives it to the disaster in `_start_disaster()`, with the car, the camera and the stage. `clear()` sets it back to white. `ambient` lives on `DisasterBase`, white unless set, so a legend without a veil gets it too and ignores it: it draws under Daylight's veil and darkens with the world.

```gdscript
# disasters/disaster_base.gd, after stage
## The light that the run ended in, under the night's veil (DAYNIGHT_PLAN.md §5.6). The director
## sets it before play(). White by day, and in tests that need no other.
var ambient := Color.WHITE

# disasters/disaster_director.gd
## The light that the run ended in, for the disaster (DAYNIGHT_PLAN.md §5.6).
var _ambient := Color.WHITE


## After a wrong or missed turn: a disaster from `area`'s pool, once `car` has stopped, in the
## `ambient` light that the run ended in.
func play_disaster(
	area: AreaDef, car: CarController, camera: CameraRig, ambient := Color.WHITE
) -> void:
	if _begin(car, camera):
		_area = area
		_ambient = ambient
		sequence = Sequence.STOPPING

# _start_disaster(), after disaster.stage = stage:
	disaster.ambient = _ambient
# clear():
	_ambient = Color.WHITE
```

A legend with a veil multiplies the world by its own colour V, which its first beat eases from white (M6_PLAN.md §5.5). At night Daylight multiplies the world by L as well, and the two would show L × V, darker than either (C4). So a legend's veil darkens only what the night hasn't, channel by channel:
- where the light is as dark as the legend's colour already (L ≤ V), the veil leaves the channel: its share is 1, and the world shows L;
- where the light is brighter (L > V), the veil darkens the channel the rest of the way: its share is V / L, and the world shows V.

So the world shows min(L, V) in each channel, and by day V, as on `main`. In `legend.gd`, the beats now `shade()` the veil, `_veil_color()` becomes `_own_color()`, and a new `_veil_color()` gives the share:

```gdscript
	if _veil != null:
		_veil.shade(Color.WHITE.lerp(_veil_color(), _clock.progress(0)))


## What the veil multiplies the world by at the end of the first beat. The world shows the legend's
## own colour where the ambient light is brighter, and the ambient's where it is as dark already, so
## at night the two veils never darken a channel past either (DAYNIGHT_PLAN.md §5.6). By day it is
## the legend's own colour.
func _veil_color() -> Color:
	var own := _own_color()
	return Color(_share(own.r, ambient.r), _share(own.g, ambient.g), _share(own.b, ambient.b))


## The legend's own colour, which its veil darkens the world to by day.
func _own_color() -> Color:
	return Tuning.VEIL_DUSK if veil_kind == Veil.DUSK else Tuning.VEIL_NIGHT


## The share of a channel that the veil leaves: what takes the ambient light `p_ambient` down to the
## legend's own `p_own`, and 1 where it is no brighter. It divides only by a value above `p_own`,
## which is at least 0.
static func _share(p_own: float, p_ambient: float) -> float:
	return 1.0 if p_ambient <= p_own else p_own / p_ambient
```

| Veil | Legends | In the light | Share | The world shows |
|---|---|---|---|---|
| `VEIL_NIGHT` (0.275, 0.314, 0.588) | The UFO (Rural) | `LIGHT_NIGHT` | (0.654, 0.654, 0.817) | `VEIL_NIGHT`, as by day |
| | | `LIGHT_DUSK` | (0.275, 0.436, 1) | (0.275, 0.314, 0.52) |
| `VEIL_DUSK` (0.667, 0.510, 0.745) | The phantom bus (City), the fairy ring (Meadows), the witch's hex (Village) | `LIGHT_DUSK` | (0.667, 0.708, 1) | (0.667, 0.510, 0.52) |
| | | `LIGHT_NIGHT` | White: the veil hides | `LIGHT_NIGHT`, darker in every channel |

- **What goes.** `_made_veil()` becomes `ViewVeil`. `_shown`, which showed the veil once the delay was over, goes too: `shade()` shows the veil as soon as its colour isn't white. By day the pixels are the same, as a white veil changes none. No legend overrides `_veil_color()`; each scene's `veil_kind` picks its colour.
- **A veil with nothing to darken isn't drawn.** In the night's light, a `VEIL_DUSK` legend's share is white in every channel, so its veil never shows, and its glows light the night.
- **The flash rules hold at night.** `test_disasters.gd` plays each legend by day and fails one that flashes (M6_PLAN.md §5.6, E6 there). At night the ambient light holds still, since the clock stopped with the run. In each channel the veil's tint eases from 1 to the share s, as by day from 1 to V, and s ≥ V because L ≤ 1. So on every frame each channel of the tint changes in the same direction as by day, and by no more. The glows draw above both veils, as by day, and the flash test counts their light before any clipping to white, which a darker ground only lessens. So what passes by day passes at night, and `test_disasters.gd` needn't play each legend again in each light.
- **Glows.** They are as bright as by day. Over a ground that the night has darkened they clip to white less (S10), and light the dark as M6 meant.

### 5.7 Readable at night

The night must keep the game playable: the road, its edges, the junctions and the car must read. The HUD and the menus are above the veil and don't change.

M3 set a rule for the car's smoke: its luminance differs by at least `SMOKE_CONTRAST`, 0.1, from each colour that it shows over, a tunnel's among them (`tests/unit/test_car_controller.gd`:10, :144, :155). Under the light L, each colour c shows as L × c.
- The smoke is black at 0.8 alpha, so a puff darkens each channel of what it covers. Its contrast with a colour is then Σ w·L·(b − p) over the channels, with b − p ≥ 0: linear in L.
- The eye adapts to the light, so a night half as bright needs only half the contrast. The rule becomes: contrast ≥ `SMOKE_CONTRAST` × lum(L) (Q12).
- Both sides are linear in L. So if the rule holds in the four key lights, it holds in every blend of them, which is every light that the game shows (§5.3). PR 2's tests check each key light:

```gdscript
	for light: Color in _lights():
		for background: Color in _backgrounds():
			var puff := background.blend(smoke.color)
			assert_gte(
				absf((puff * light).get_luminance() - (background * light).get_luminance()),
				SMOKE_CONTRAST * light.get_luminance(),
				"a puff over %s in %s" % [background, light]
			)
```

Step 0 measured the margin, the least contrast over all the backgrounds divided by the contrast needed, in each key light. The least is over the same background in each, #292933:

| Light | Over the world | Through a tunnel |
|---|---|---|
| White | ×1.303 | ×1.043 |
| Dawn | ×1.303 | ×1.043 |
| Dusk | ×1.296 | ×1.037 |
| Night | ×1.314 | ×1.052 |

- In any light, the margin over a background is an average of its margins in red, green and blue, weighted by w·L. The least of those, over all the backgrounds and covers, is ×1.024, red and green through a tunnel. So **with today's art the smoke shows in a light of any colour**, and the owner can tune `LIGHT_*` freely (Q10). The tests guard against new art and a new smoke: a bluish smoke fails in the night's light (N20).
- Dawn's margins equal white's to three digits. #292933 is a dark grey with a little blue, whose red and green are about equal, so over it the margin depends almost only on blue's share of the light's luminance: 0.0721 at dawn, and 0.0722 in white.

The night is blue and about half as bright: `LIGHT_NIGHT`'s luminance is 0.485. On the Fold4 the owner judges whether the road and the junctions read well, on both screens (§6.4). P4's frames at `--hour=22` show the road, its edges and the car clearly.

### 5.8 When the night shows

With D seconds a day, starting at 07:00, each part of the day begins (hour − 7) / 24 × D seconds into the zone:

| Begins | Hour | Share of the day | D = 120 s | D = 55.68 s, the least |
|---|---|---|---|---|
| Dusk | 17:00 | 10/24 | 50 s | 23.2 s |
| Night | 20:00 | 13/24 | 65 s | 30.2 s |
| Dawn | 04:30 | 21.5/24 | 107.5 s | 49.9 s |
| Day again | 07:00 | 1 | 120 s | 55.68 s |

Step 0 measured each zone's time with the autopilot, over 20 seeds. Players don't set the speed (`plan.md` §2.2), so a player who turns right spends about as long:

| Zone | Seconds | Turns | At D = 120 s, the zone ends at |
|---|---|---|---|
| City | 55.7–61.4, median ≈ 57.6 | 34 | 18:08–19:17: dusk, no night |
| Rural | 127.6–147.1 | 66 | 08:31–12:25, after a whole day and night |
| Meadows | 201.3–227.0 | 100 | 23:16–04:24, the second night |
| Village | 32.7–45.6 | 20 | 13:32–16:07: day only |
| Desert | Endless | — | — |

- At the default, a run's first night comes ≈ 65 s into Rural, ≈ 122 s into the run. The City and the Village never show theirs.
- A zone shows its night only if it lasts more than 13/24 of its day. So the City needs D ≤ 102.8 s, and the Village D ≤ 60.4 s.
- **Q3's alternative:** the City at 80 s shows 12–18 s of night, and the Village at 56 s, just above the least day, 2–15 s. Each is one line in its `.tres`.
- `smoke.sh`'s 60 simulated seconds reach dusk at 50 s, and the car enters Rural before they end, so CI's smoke run shows the veil and a reset every time. Its `autopilot:` line stays the same, since the light changes nothing but the view.

### 5.9 Any hour: `--hour=<h>`

`--hour=<h>` starts every zone's clock at hour h instead of 07:00, in the form of `main.gd`'s other arguments. A test, an agent or the owner on a desktop can then see the night without waiting 65 s. `_ready()` reads it from the user arguments and sets `cycle.start_hour` once for every run.

```gdscript
## The hour of --hour=<h> in `p_args`, round the clock, which every zone's clock starts at
## (DAYNIGHT_PLAN.md §5.9). Tuning.DAY_START_HOUR without it, or with an h that isn't a number.
static func _parse_hour(p_args: PackedStringArray) -> float:
	for arg: String in p_args:
		if arg.begins_with("--hour="):
			var text := arg.trim_prefix("--hour=")
			if text.is_valid_float() and is_finite(text.to_float()):
				return fposmod(text.to_float(), 24.0)
			push_error("main: --hour= needs an hour, such as --hour=20.5")
	return Tuning.DAY_START_HOUR
```

- Any number counts, round the clock: `--hour=26` is 02:00, and `--hour=-1.5` is 22:30.
- An hour that isn't a number is reported, and the clock starts at 07:00 (`AGENTS.md` §3). `1e999` is a valid float to Godot, but `to_float()` logs "Exponent too high" and gives infinity, which `is_finite()` turns away (N31).
- Android and the Web take no user arguments (C12). On a device the night comes by playing. In debug builds the title's Start button can start the run in Rural (ZONE_SELECT_PLAN.md), whose night comes 65 s after Play. The agents' Web checks serve the build with its page patched to pass the query's `?arg=` values, as M4's P4 did, such as `?arg=--hour=19` (§6.4).

### 5.10 Rejected approaches

| Approach | Why not |
|---|---|
| `CanvasModulate` | It tints every item on the canvas, the legends' glows too. They would dim at night, and the balance of glows and veils (S10) would change. Godot allows only one per canvas |
| World's `modulate` | It multiplies every item under World, the legends among them: a legend's veil would darken twice, and its glows would dim |
| `Light2D`s | They need a `CanvasModulate` to make the dark that they light, and each light draws the items that it lights again: a cost on the Fold4 and the Web, for what is only a change of colour |
| A shader on every material | Every sprite, polygon and particle would need it, and each new piece of art would have to remember it. One that forgot would stay lit in the dark |
| A `ColorRect` on a `CanvasLayer` | A layer draws over or under the whole world canvas. It can't sit between the world and the glows |
| Night art | A second set of art doubles the assets and the Web's download, and blending the two sets gradually needs a shader anyway |

**Fallback.** If P5 fails on PR 3 (P3 passed, §6.5), Daylight could set the `modulate` of World's children (GroundLayer, SetPieces, RoadLayer, Skids and Props) to the light instead of showing a veil, from the same `DayCycle`. That adds no draw, but it breaks E8 and C2. A `modulate` passes to the children, and `Legend.play()` stands the phantom bus under Props with its ADD lamps as the bus's children, so they would dim at night. A legend's other parts, under DisasterLayer, would stay lit, and each new child of World would have to join the list. So it needs the owner's agreement first.

### 5.11 The sun's direction

Q4's default is colour only: the light changes the world's colour, not where the light comes from. An optional PR 4 could add a soft gradient over the view, lighter on the sun's side by day and the moon's by night, turning with the hour:
- a `Sprite2D` with a fixed gradient texture, blended in MIX at a low alpha under the veil;
- only its rotation and `modulate` would change, so it would never redraw;
- like the light, it would change slowly and never flash (§5.3).

It isn't in the defaults: the art has its shading drawn in, and a gradient turning across it may look wrong. P7, screenshots of it at the key hours, needs the owner's eye, so it runs only if the owner asks for PR 4.

---

## 6. Verification

### 6.1 Local checks

The five checks of `AGENTS.md` §4 ran with Godot 4.7.2 and gdtoolkit 4.5.0 on `main` and on each PR's state: `main` with the files of that PR and of the PRs before it, as they are at 9198181 (§4). `lint.sh` passed on each, and after the checks `git status --porcelain` printed nothing.

| Head | Scripts loaded | Test scripts | Tests | Asserts | GUT time |
|---|---|---|---|---|---|
| `main` (528196e) | 142 | 65 | 480 | 422,823 | 122.6 s |
| PR 1 | 144 | 66 | 492 | 422,907 | 127.7 s |
| PR 2 | 146 | 67 | 494 | 423,398 | 138.0 s |
| PR 3 (9198181) | 149 | 69 | 506 | 424,110 | 141.0 s |

- `smoke.sh` printed `autopilot: tile 165, turns 35, area rural` on every head, and no error line. The light reaches neither the road, nor the car, nor the director's choice of disaster (§5.1). On PR 3 its 60 s reach dusk in the City and a reset in Rural (§5.8).
- GUT's times come from a machine with 2 shared CPUs, and vary with its load.
- CI ran on the prototype by hand, with `upload-builds`: run 43379528114 at 9198181, all five jobs green, with GUT's 506 tests in 98.0 s and the same `smoke.sh` line.

### 6.2 Negative cases

Each case is a temporary change at its PR's head. A script applies it, runs GUT on the scripts that hold the tests named, checks that those tests fail, and restores the tree. In its last run, on the three heads, all 43 failed as below. Its first run had found four gaps, which tests now close (§4.1); N36–N43 came with the internal reviews' fixes (§4.6). It runs again on each PR's final head.

| N# | PR | Temporary change | Tests that fail |
|---|---|---|---|
| N1 | 1 | `hour()` without its `fposmod()` | `test_the_hour_runs_round_the_clock_in_day_seconds` |
| N2 | 1 | `light_at()` starts at the first key, `var i := 0`, so the night doesn't run past midnight | `test_each_key_hour_has_its_light`, and the catch-up and least-day tests |
| N3 | 1 | `light_at()` blends by `t`, not `smoothstep()` | `test_between_keys_the_light_eases_in_and_out`, and the least-day test |
| N4 | 1 | `advance()` sets `light = goal` | `test_the_light_shown_never_changes_faster_than_the_max_rate`, `test_after_a_reset_the_light_catches_up_and_then_follows_exactly` |
| N5 | 1 | `enter()` calls `snap()` | The same two |
| N6 | 1 | `enter()` keeps `seconds` | `test_entering_a_zone_starts_its_clock_at_the_start_hour` |
| N7 | 1 | `STEEPEST := 1.0` | `test_least_day_seconds_is_the_shortest_day_the_rate_can_follow` |
| N8 | 1 | `enter()` without its check of the day | `test_a_day_of_no_seconds_is_an_error_and_stops_the_clock` |
| N9 | 1 | `advance()` moves each channel on its own, with `move_toward()` | `test_after_a_reset_the_light_catches_up_and_then_follows_exactly`: not the straight way |
| N10 | 1 | `AreaDef.validate()` without its check of a short day | `test_area_def.gd`: `test_validate_reports_a_day_too_short_to_follow` |
| N11 | 1 | `city.tres` with `day_seconds = 50.0` | `test_area_schedule.gd`: `test_the_game_schedule_is_valid`, and 4 more of its tests |
| N12 | 1 | `LIGHT_MAX_RATE := 0.1`: the least day becomes 139.2 s | The same, and more of `test_area_schedule.gd` |
| N13 | 2 | `ViewVeil` in `BLEND_MODE_MIX` | `test_view_veil.gd`: `test_the_veil_multiplies_at_veil_z_and_starts_hidden` |
| N14 | 2 | `ViewVeil` with `z_as_relative = true` | The same |
| N15 | 2 | `ViewVeil._init()` leaves `modulate.a` at 1 | The same; `test_disasters.gd`: `test_each_shows_nothing_until_its_delay_is_over`; `test_legend.gd`: `test_at_night_a_veil_darkens_only_what_the_night_hasnt` |
| N16 | 2 | `Legend._veil_color()` returns the legend's own colour | `test_at_night_a_veil_darkens_only_what_the_night_hasnt` |
| N17 | 2 | `_share()` always gives `p_own / p_ambient`, above 1 where the light is darker | The same |
| N18 | 2 | `shade()` never hides: `if false:` | The same: the dusk veil is drawn in the night's light |
| N19 | 2 | `shade()` sets `color`, not `self_modulate` | `test_disasters.gd`: `test_none_redraws_a_polygon` |
| N20 | 2 | A bluish smoke, `Color(0, 0, 0.4, 0.8)` in `car/car.tscn` | `test_car_controller.gd`: `test_the_smoke_shows_over_everything_the_world_draws`, only in the night's light, and `test_the_smoke_shows_through_a_tunnel` |
| N21 | 2 | `play_disaster()` doesn't keep its `ambient` | `test_disaster_director.gd`: `test_a_disaster_waits_for_the_car_to_stop` |
| N22 | 2 | `_start_disaster()` doesn't pass it on | The same |
| N23 | 3 | Daylight's `_ready()` doesn't set its priority | `test_daylight.gd`: `test_in_the_games_frames_the_veil_follows_the_view_of_the_same_frame` |
| N24 | 3 | Daylight's `_physics_process()` does nothing | The same; `test_daylight_run.gd`: `test_the_light_follows_the_clock_while_the_car_drives`, `test_each_new_zone_starts_its_clock_again` |
| N25 | 3 | `main.gd` advances the clock in every state | `test_the_clock_stops_when_the_run_ends_and_while_paused` |
| N26 | 3 | `_on_area_changed()` without `enter()` | `test_each_new_zone_starts_its_clock_again`, `test_each_run_starts_at_once_in_the_morning`, `test_each_zone_runs_its_clock_at_its_own_pace` |
| N27 | 3 | `_start_run()` without `snap()` | `test_each_run_starts_at_once_in_the_morning`, `test_the_hour_argument_starts_every_zone_at_that_hour` |
| N28 | 3 | `_start_run()` without `refresh()` | `test_each_run_starts_at_once_in_the_morning` |
| N29 | 3 | `play_disaster()` without the light | `test_at_night_the_disaster_plays_in_the_light_the_run_ended_in` |
| N30 | 3 | `_ready()` doesn't set `start_hour` | The same; `test_the_hour_argument_starts_every_zone_at_that_hour`; `test_the_light_follows_the_clock_while_the_car_drives`; `test_each_zone_runs_its_clock_at_its_own_pace` |
| N31 | 3 | `_parse_hour()` without `is_finite()` | `test_the_hour_argument_starts_every_zone_at_that_hour` |
| N32 | 3 | Daylight at `VEIL_Z + 1` | `test_the_veil_darkens_the_world_but_not_the_glows_or_the_ui` |
| N33 | 3 | `main.gd` lowers bus 0 by 6 dB while the light isn't white | `test_the_light_changes_nothing_but_the_view` |
| N34 | 3 | `shade()` sets `color`, not `self_modulate` | `test_daylight.gd`: `test_daylight_is_never_redrawn` |
| N35 | 3 | `shade()` never hides | `test_by_day_the_veil_is_transparent_and_by_night_it_shows_the_light`, `test_daylight_is_never_redrawn`, `test_each_run_starts_at_once_in_the_morning`, `test_the_hour_argument_starts_every_zone_at_that_hour` |
| N36 | 1 | `enter()` checks only `p_day_seconds <= 0.0`, so NaN and INF pass | `test_a_day_of_no_seconds_is_an_error_and_stops_the_clock` |
| N37 | 1 | `validate()`'s message names `least_day_seconds()` to the hundredth, not rounded up: 55.68 | `test_area_def.gd`: `test_validate_reports_a_day_too_short_to_follow` |
| N38 | 1 | `validate()` without its check of a day that isn't finite | `test_area_def.gd`: `test_validate_reports_a_day_that_isnt_finite` |
| N39 | 3 | `_on_area_changed()` enters a day of 120 s, not the zone's | `test_each_zone_runs_its_clock_at_its_own_pace` |
| N40 | 3 | `main.gd` mutes the Ambient bus while the light isn't white | `test_the_light_changes_nothing_but_the_view`. Its version at 257af7a passed |
| N41 | 3 | `main.gd` plays the junction's sound as the clock passes 20:00 | The same, whose version at 257af7a passed too |
| N42 | 3 | `main.gd` sets the engine loop's `volume_db` to −80 while the light isn't white | `test_the_light_changes_nothing_but_the_view`. Its version at c9b65ed passed |
| N43 | 3 | `main.gd` puts the ambient decks on the Music bus while the light isn't white | The same, whose version at c9b65ed passed too |

`clear()`'s reset of the director's `_ambient` has no case: only `play_disaster()` starts a sequence that reaches `_start_disaster()`, and it sets the light first, so nothing can see the reset. It only tidies.

### 6.3 Editor warnings

Only the editor warns about shadowing, not CI (M2_PLAN.md §6.3). A script asked the editor's language server (`godot --headless --editor --lsp-port`) for the warnings of every script outside `addons/`, on `main` and on each PR's state. Each gave the same five, all from before DN:
- `INTEGER_DIVISION` at `tests/unit/test_greybox_atlas.gd`:15, `tests/unit/test_iso.gd`:42, `ui/main.gd`:52 (:54 on PR 3) and `world/greybox_atlas.gd`:135;
- `UNUSED_VARIABLE` at `tests/unit/test_road_generator_occupancy.gd`:30.

So DN adds none. To show that the probe sees shadowing: a local `var seconds` in `DayCycle.snap()` made it report `SHADOWED_VARIABLE` at `world/day_cycle.gd`:34.

The names follow `AGENTS.md` §3: the parameters are `p_day_seconds`, `p_hour`, `p_camera`, `p_light`, `p_own`, `p_ambient` and `p_args`, and `light_at()` calls its hour `h`, as `hour()` is a method.

### 6.4 CI, the Web and the Fold4

- **CI.** The five required checks on each PR into `main`, with the `test` job's check of the tree (`AGENTS.md` §10).
- **The Web** (E11, E13; P3). The agent checks PR 3's build in Chrome and Firefox with Playwright, headed under Xvfb, and posts a table in PR 3, one row per check (`AGENTS.md` §6). The page passes no arguments (C12), so it serves a copy that takes them from the address, as M4 did (M4_PLAN.md §4, PR 3 step 3):
  ```bash
  gh workflow run ci.yml -R pompomon/roadgame --ref dn/3-daylight -f upload-builds=true
  gh run download <run id> -R pompomon/roadgame -n web -D /tmp/dn-web
  sed -i 's/"args":\[\]/"args":["--"].concat(new URLSearchParams(location.search).getAll("arg"))/' \
    /tmp/dn-web/index.html
  python3 -m http.server -d /tmp/dn-web 8000
  ```
  1. `?arg=--autopilot&arg=--seed=12345`, `smoke.sh`'s run: dusk begins 50 s in. The car enters Rural about a minute in, and the light goes back to day in about 2 s, with no jump. Then Rural's whole day: dusk 50 s in, the night 65 s in, dawn 107.5 s in, and day again at 120 s (§5.8). A screenshot of each, and neither console logs a WebGL error (P3).
  2. `main`'s build, patched the same way, at the same address: the first 50 s look the same (E1).
  3. `?arg=--hour=21&arg=--seed=1`, then Play on the title: the night at once. Miss the first junction: the phantom bus's dusk veil stays hidden, and its glows light the night (§5.6). Game over, then the title, keep the night (Q6). Retry starts again at 21:00 at once, with no fade (E5).
  4. `?arg=--area=rural&arg=--hour=21`: miss the first junction. The UFO's night veil darkens the world to its own colour, as by day (§5.6).

  Step 0 ran 1, 3 and 4 on the prototype's build, with `--play` in place of the title's first Play (P3, §6.5). On PR 3 the agent runs all four.
- **The Fold4** (E13; P5). The owner installs PR 3's debug APK:
  ```bash
  gh workflow run ci.yml -R pompomon/roadgame --ref dn/3-daylight -f upload-builds=true
  gh run download <run-id> -R pompomon/roadgame -n "android-Android APK" -D /tmp/roadgame-apk
  adb install -r /tmp/roadgame-apk/roadgame-debug.apk
  ```
  Then, on the cover screen and unfolded:
  - dusk shows about 50 s into the run, and in Rural the light returns to day in about 2 s, with no jump;
  - the night comes about 2 minutes into the run, and the road, its edges, the junctions and the car read well (Q10). Sooner: press the title's Start button until it reads "Start in: Rural" (debug builds, ZS), then Play, and the night comes 65 s in;
  - a legend at night looks right, and a game over at night keeps the night on the title (Q6);
  - the night plays as smoothly as the day (P5). If it doesn't, the agent builds the APK on a scratch branch with `debug/settings/stdout/print_fps`, which prints the frame rate to `adb logcat`.

  To see the night at once on the phone, serve the Web copy above, run `adb reverse tcp:8000 tcp:8000`, and open http://localhost:8000/?arg=--hour=20 in the Fold4's Chrome, as M4's Q6 did.

### 6.5 Probes and measurements

| P# | What | How | Result |
|---|---|---|---|
| P1 | Only the glows and the UI draw above Daylight | The running main scene at `--seed=1`, once the phantom bus showed at the first junction: each canvas item's absolute z | Done. Under World, 601 items at z 0, 2 at 1, the legend's MUL veil at 2 and its 2 ADD glows at 3. Daylight, under Main, at 2. Now a test: `test_the_veil_darkens_the_world_but_not_the_glows_or_the_ui` |
| P2 | Two MUL veils commute | Movie Maker under Xvfb, `--fixed-fps 60 --quit-after 900 -- --play --seed=1 --hour=17`: the run ends at the first junction at about 17:40, and from frame 186 the phantom bus's veil shows under Daylight's. Again with Daylight before World in `main.tscn`, so that it draws first | Done. 714 frames differ, by at most 1/255 in a channel, in 0.44% of the values: the 8 bits' rounding |
| P3 | No WebGL error over a day | §6.4's runs 1, 3 and 4, on the prototype's Web build (CI run 43370478843, 257af7a), in Chrome 157 and Firefox 159 with Playwright, headed under Xvfb. The autopilot for 205 s, and each night run through its disaster and game over, then the title and Play, or Retry | Done. Neither console logged an error or a WebGL message. The screenshots' mean colours followed the clock: dusk, Rural's reset to the day, its night and its dawn; at 21:00 the night at once, after Play and after Retry, kept behind game over and on the title; the UFO's veil over Rural's night. The night runs' colours were the same in both browsers, and the autopilot's within 2/255 at the same point of the run. Firefox warned only of its autoplay policy, before any click, and of a deprecated WebAssembly instruction in Godot's build. Again on PR 3's build |
| P4 | A hidden veil changes no pixel | Movie Maker under Xvfb, `--fixed-fps 60 --quit-after 600 -- --autopilot --seed=1`, on `main` and on the prototype | Done. All 600 frames are byte for byte the same. At `--hour=22` the frames are darker and bluer; the road, its edges and the car read, and the HUD is as by day |
| P5 | The veil's cost | §6.4 | On PR 3, on the Fold4 |
| P6 | At priority 1, Daylight covers the view of the same frame | In the engine's frames, not GUT's `simulate()` (§5.4) | Done. Now a test: `test_in_the_games_frames_the_veil_follows_the_view_of_the_same_frame`. Without the priority the veil is a frame behind (N23) |
| P7 | The sun's gradient (§5.11) | Screenshots at the key hours | Only if the owner asks for PR 4 (Q4) |

Step 0 also measured the autopilot's seconds in each zone over 20 seeds (§5.8), the smoke's margins in each key light (§5.7), the editor's warnings (§6.3) and §6.1's counts.

---

## 7. Owner actions

For @pompomon:
1. **Answer the Q#s** of §3, or accept their defaults. Q3 first: at the default, 120 s in every zone, the City and the Village never show their night, and a run's first night comes about 2 minutes in, in Rural (§5.8). The City at 80 s and the Village at 56 s would show theirs. The others that shape the code: Q1, the start hour; Q2, the reset; Q4, colour only; Q6, the last light stays after the run; Q7, legends at night; Q10, the night's colours; Q12, the smoke's rule.
2. **Merge** the plan PR, then PRs 1, 2 and 3, squashed, in that order, each once its base is `main` (§4.5). Before deleting a merged PR's branch, retarget the next PR: `gh pr edit <n> --base main`.
3. **Check the Fold4** with PR 3's debug APK (§6.4), and post the results in PR 3.
4. **Tune the night**, if Q10 asks for it: the `LIGHT_*` colours in `config/tuning.gd`, or a zone's `day_seconds` in its `.tres`. Nothing else changes: `least_day_seconds()`, `validate()` and the tests follow, and the smoke shows in a light of any colour with today's art (§5.7).
5. **Resolve** the review threads.

---

## 8. Risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Zones too short to show the night | Certain for the City and the Village at 120 s | A run's first night comes about 2 minutes in, in Rural | Q3: the City at 80 s and the Village at 56 s, a line each (§5.8) |
| The night is too dark or too blue on the Fold4, or outdoors | Medium | The junctions read badly, and runs feel unfair | The owner tunes `LIGHT_*` (Q10), in `Tuning` alone. The smoke shows in any light with today's art, and the tests guard it (§5.7) |
| The reset to the morning at each zone looks sudden | Medium | It breaks the mood | It takes up to 2.33 s, at a rate about twice dusk's steepest. Q2's slower fade (§5.3) |
| A legend looks wrong at night | Medium | Its colour is lost where the night is darker | The world shows the darker of the two in each channel (§5.6, Q7). The Web and Fold4 checks (§6.4) |
| The veil costs frame time | Low | Dropped frames at night | Hidden by day, a square like each legend's veil. P5. §5.10's fallback would dim the phantom bus's lamps, so it needs the owner's agreement |
| Something other than a glow draws above `VEIL_Z` | Low | It stays lit in the dark | `test_the_veil_darkens_the_world_but_not_the_glows_or_the_ui` (P1), and the rule in `AGENTS.md` §3 |
| WebGL errors on the Web | Low | Console errors, as in godotengine/godot#124726 | Only the position, `modulate` and `self_modulate` change: `test_daylight_is_never_redrawn` and `test_none_redraws_a_polygon`. P3 passed on the prototype's build |
| Two MUL veils round differently in 8 bits | Low | Banding under a legend at night | P2: at most 1/255 |
| M7 or HB (#62) changes `ui/main.gd`, `ui/main.tscn`, `config/tuning.gd`, `plan.md` or `AGENTS.md` at the same time | Medium | Merge conflicts | DN's lines are in blocks of their own, and `git merge-tree` shows conflicts first. HB's prototype merges with DN's cleanly (§4.5) |

---

## 9. Notes for later work

- **Orientation and foldables (M7).** The veil is a square of ±`Tuning.VEIL_HALF_SIZE` round the view, built once (§5.5). `test_view_veil.gd`'s `test_the_veil_covers_every_view` checks it on every reference screen, `SCREENS` in `tests/integration/test_props_in_view.gd`, at every step of the zoom. The views that M7 adds go in that list, and the veil's test follows.
- **Haptics and the Web's audio (M7).** The light drives neither. `test_the_light_changes_nothing_but_the_view` compares the sound on every frame of a run by day and one from dusk into the night: the buses, the cross-fades, the loops, each player's gain, bus and pitch, and the sounds played. What M7 adds to the sound, and its haptics, can join the test's `_sound()`, so that it checks them too.
- **Godot 4.8** fixes the redraw of a `Polygon2D` (godotengine/godot#124726). The veils could then tint through `color`, but `self_modulate` keeps working, so nothing needs to change.
- **The tunnel's darkening (C15).** Not a `CanvasModulate`, which would dim the glows (C2): Daylight can multiply its light by a grey that eases in as the car enters a tunnel, with `Tunnel.opacity()`, no faster than the rate. §5.7's rule scales with the light, so it holds under a grey too, and the glows stay lit.
- **A setting for the night (Q9).** A player who finds the night hard to read could get a brighter one: `Color.WHITE.lerp(light, k)`, with k from 0 to 1. That is still a blend of keys, since white is one, and it changes no faster than the light, so §5.3's and §5.7's rules hold.
- **Saved runs.** The light isn't saved, since every run starts at the start hour. If runs are ever saved part-way, save `seconds` and the light shown.
- **Each zone's own hours and lights.** `AreaDef` could hold its own start hour or keys: a desert's harsh noon, a city's lit night. `least_day_seconds()` would then take the zone's keys, and `validate()` would check each zone against its own.
- **Lamps (Q5).** Lit windows or street lamps would be glows above the veil, which add light (S10). That is how to light the night, not a lighter veil.
