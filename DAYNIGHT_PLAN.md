# Day and Night: Sun and Moon Light in the Zones — Detailed Plan

Status: the owner answered Q4 and Q5 and kept the other defaults (§3); the five PRs passed their reviews and checks, the Web's included, and wait for the owner's on the Fold4 (§6.4, §7); #70, PR 1, was merged into `dn/plan`, not `main`, so #76 lands its branch, and native stack #77 holds #76 and #71–#74, on `main` (§4.5) · 2026-11-14 · Step 0 and the internal reviews done (§4.1, §4.6) · Scope: a light that follows the sun and the moon through a 24-hour day in each zone, with the clock reset as the car enters each zone; the shadows that the sun and the moon cast; lamps and windows that glow at night; visual only. This plan calls the work DN. It comes after RG (#54–#57), ZS (#60, #61) and TUT (#65–#68), and doesn't depend on M7 (Ship), which may land before or after it (§4.5).

The owner asked: "create a detailed implementation plan for sun/moon light movement in the zones. Each zone resets the clock, and sunlight / moonlight cadence is zone-specific, starting with 2 minute for full 24h cycle in each zone. Sun/moon only affects visual part of the scene, audio remains separate. Current visuals could be used as the sunlight version without additional changes. The transition from sun to moon is gradual, not abrupt." On the first draft, which had three PRs: "Adjust the plan, Q4 implement shadows in pr4, Q5 glow lamps at night. Keep the rest of the default decisions and proceed with the implementation using stacked PRs".

**Verified.** As for M2–M6, RG and TUT, step 0 built every file of the PRs on a prototype branch before this plan was final (§4.1). The checks pass on each PR's head, each of the 105 negative cases fails its tests, and the probes that need no device ran (§6). Numbers marked ≈ are rounded; the rest are measured or exact.

Verified with:
- Godot 4.7.2-stable, the official Linux x86_64 build that CI's image has
- GUT 9.7.1
- gdtoolkit 4.5.0 on Python 3.12.3. No PR changes a shell script or a workflow, so shellcheck and actionlint have nothing new to check; CI's `lint` job runs them

**Precedence.** For DN, this document replaces `plan.md` §3.7, §5, §6, §7.1 and §7.2 wherever it marks a difference with **Δ** and its finding (C#, §2). PRs 1, 3, 4 and 5 fold the changes into `plan.md` (Q13). `IMPLEMENTATION_PLAN.md` (IP) stays as M0–M6 and RG left it: DN isn't one of its milestones.

**Reference code.** `dn/prototype` at 45bb1b6, pushed for reference. It was built from `main` at 1047e17, merged `main` at 528196e (ZS), 413829a (#63, in 5c724ad) and a5244fe (TUT, in c38f01c), and took the internal reviews' fixes (§4.1, §4.6). It never gets a PR. The PRs' branches hold the same files, PR by PR, in commits of their own (§4):

| PR | Prototype commits | What |
|---|---|---|
| 1 | 7e6e817, 21261af, 78cc8ae, 125b99a | The clock, then step 0's and the review's fixes |
| 2 | ad4a9a3, 7e752bf | `ViewVeil`, legends' ambient, the smoke in every light; the veil's own test |
| 3 | 98bc558, 7982976, 257af7a, c9b65ed, 9198181, 5e20b2d, 57b79d7 | Daylight, then a test's fix, the merge of ZS, the reviews' fixes, and C21 |
| 4 | 08e031e, 9ed8843, 5400f79, 45bb1b6 | Shadows; the car's shadow checked by its body, the game's wiring; the reviews' tests |
| 5 | f464d20, 1400a3e, 24d8c74, 5e8d4c8, 1e97dd7, 6ae2217 | Lamps, then one group that adds, with silhouettes, and step 0's and the reviews' fixes |

28424af (the shadows' lay by material; PRs 3–5's sprites as their nodes' own parts) and cdb1616 (sparse scatter tests) hold parts of PRs 3–5 (C20). The prototype has the code and the tests. Each PR also writes its docs (C14, §4).

**Prerequisites.** `main` at a5244fe (TUT PR 3, #68). DN needs no repository setting, secret or asset: `make_props.gd` writes each prop's shadow and lights into its `.tres`, and the art doesn't change.

Contents:
1. Goal and exit criteria
2. Review findings
3. Decisions and open questions
4. Work breakdown (5 PRs)
5. Design
6. Verification
7. Owner actions
8. Risks
9. Notes for later work

---

## 1. Goal and exit criteria

Goal: a day in each zone. The light on the scene follows the sun and the moon through 24 hours: the day, dusk, the night, dawn and the day again. The props and the car cast shadows away from the sun by day and the moon at night, and lamps and windows glow at night. Today's look is the day's light, unchanged. Terms:

- A **zone** is an area (`AreaDef`, `plan.md` §3.6–§3.7): the City, Rural, Meadows, the Village and the Desert. The code says area; this plan says zone where it follows the owner's words.
- Each zone has a **clock**, which gives the **hour**, 0–24. It starts at `Tuning.DAY_START_HOUR`, 07:00 (Q1), as the car enters the zone, and runs a full day in the zone's `day_seconds`: 120 s in every zone to start with, so an hour takes 5 s.
- The **light** is the colour that the world is multiplied by: white by day, so that the day is today's look exactly; dawn's, dusk's and the night's colours at their hours; and eased blends between them (§5.2).
- **Daylight** is the node that shows the light: a veil like M6's legends' veils (`M6_PLAN.md` §5.5), over the whole view, that multiplies the world under it. It sits under the glows and the UI.
- **Shadows** is the node that draws the props' and the car's shadows, black at the sun's or the moon's alpha, as one group, so that overlapping shadows darken once (§5.11). **Lamps** draws the props' lamps and lit windows over the veil at night, as one group that adds light (§5.12).

"Gradual" (§5.3): the light eases between key colours over hours of the clock, dusk taking 15 s at 120 s a day, and never changes faster than `Tuning.LIGHT_MAX_RATE`, so a reset at night brightens to the morning over 2.33 s. The shadows and the lamps fade by the same rule.

| # | Exit criterion | Checked by |
|---|---|---|
| E1 | The day's light is today's look. From 07:00 to 17:00 the light of the hour is exactly white. So is the light shown, from a run's start, and in a later zone once it has caught up with the hour: 140 physics frames (2.33 s) after a reset from the night (E4). While it is white, Daylight's veil waits at `modulate.a` 0, which the canvas skips, and the lamps are out. Through PR 3 each frame is drawn as on `main`; from PR 4 on, the shadows are the only change by day (Q4, E15) | `test_day_cycle.gd`, `test_daylight.gd`, `test_lamps.gd`; P4 (done) |
| E2 | The cycle (C1). The hour runs 24 h in `day_seconds`. At each key hour the light is that key's colour. Between two keys it eases from one to the other with no slope at either, so each channel only rises or only falls | `test_day_cycle.gd` (3 tests) |
| E3 | Zones (C6). Entering a zone starts its clock at `DAY_START_HOUR`, with the zone's own `day_seconds`; so does the tutorial's switch to the City (C21). The argument `--hour=<h>` starts every zone of every run at hour h instead | `test_day_cycle.gd`; `test_daylight_run.gd` (3); `test_tutorial.gd` |
| E4 | Gradual (C6, C7). No channel of the light shown changes by more than `LIGHT_MAX_RATE` × delta in a physics frame, also when a zone resets its clock. While the clock's light holds still, as it does for 50 s after each reset to 07:00, the light reaches it within 1 / `LIGHT_MAX_RATE` seconds, along the straight way; once there, it follows the clock's light exactly. `AreaDef.validate()` reports a `day_seconds` below `DayCycle.least_day_seconds()`, the shortest day whose light the rate can follow, and one that isn't finite. Nothing flashes (WCAG 2.3.1) | `test_day_cycle.gd` (4); `test_area_def.gd` (2); `test_area_schedule.gd` |
| E5 | Each run starts in the morning light at once, after a retry and from the title too: a new run is a cut, not a zone change. So do its shadows | `test_day_cycle.gd` (2); `test_daylight_run.gd` (2) |
| E6 | The clock and the light stop when the run ends or the game pauses. They stay as they are behind game over and the title, until the next run (C8, Q6). The veil still follows the camera as it shakes | `test_daylight_run.gd` (2); `test_daylight.gd` |
| E7 | Visual only. The light, the shadows and the lamps change nothing in the road, the car, the disasters, the HUD or the audio. The game's road digests, `smoke.sh`'s line and the audio tests stay as they are, and a run drives at night exactly as by day | `test_daylight_run.gd`; `test_road_generator_determinism.gd`; `test_audio.gd`; `smoke.sh` (§6.1) |
| E8 | Daylight (C2, C10, C11). It covers every reference screen at every zoom and follows the view of the same frame. It multiplies, at `VEIL_Z`, whatever its parent's z. It darkens the ground, the road, the skid marks, the shadows, the set pieces, the car, the props and the legends' parts, including nodes' own internal children, but not the glows, the lamps or the UI | `test_view_veil.gd` (2); `test_daylight.gd`; `test_daylight_run.gd`; P1 and P2 (done) |
| E9 | Legends at night (C4). A legend's veil darkens each channel only to the darker of its own colour and the light it plays in. By day a legend looks as on `main`. At night it never brightens anything, each channel ends at the darker of the two, never darker than both, and a veil with nothing left to darken isn't drawn | `test_legend.gd`; `test_disaster_director.gd`; `test_daylight_run.gd`; `test_disasters.gd` |
| E10 | The smoke still shows (C3, C22). Over everything the world draws, through a tunnel too, its contrast in each key light L is at least `SMOKE_CONTRAST` × the luminance of the light there: L, or in a shadow of alpha α, (1 − α)·L. So it shows in every light the game shows | `test_car_controller.gd`'s three smoke tests |
| E11 | The Web (C9). The veils change only their position, `modulate.a` and `self_modulate`, so they are never redrawn; the shadows and the lamps are sprites. Chrome and Firefox log no WebGL error over a whole day and night, and draw it at a steady rate | `test_daylight.gd`; `test_disasters.gd`; P3 and P9 (done, P9 with the shadows and the lamps) |
| E12 | All five required checks are green, with §6.1's counts, and `smoke.sh` prints no error line. Each negative case makes the tests it names fail (§6.2). The editor reports no new warnings (§6.3) | PR checks; §6.1–§6.3 |
| E13 | Manual, on the Web in Chrome and Firefox and on the Fold4, folded and unfolded: §6.4's checks. Dusk, dawn, a zone's reset and the shadows change gradually, the night reads well (Q10), the lamps glow warm, never white, and the frame rate holds (P5) | §6.4, on PRs 3–5 |
| E14 | `plan.md` §3.7, §5, §6, §7.1 and §7.2, `AGENTS.md`, and the comments that the PRs touch say what the code does (C14) | Review |
| E15 | Shadows (Q4; C16, C18). An upright prop casts the rows above its foot, a wall its base line, and flat props none; the car casts its body's frame and fades with it. Each falls away from the sun by day and from the moon at night, turns from the right to the left in front of what casts it, and is as long as the light is low, up to `SHADOW_LONGEST` times its height. Where shadows overlap they darken once. Each is drawn wherever it falls, from props off the view too | `test_shadows.gd` (10); `test_day_cycle.gd` (2); `test_prop_art.gd`; `test_prop_scatter.gd`; `test_world_renderer.gd`; `test_shadows_run.gd`; P8, P11 (done) |
| E16 | Gradual shadows (C7). The shadows shown move by at most `SHADOW_MAX_RATE` a second and their alpha changes by at most `SHADOW_ALPHA_RATE` a second. The sun's fade out as it sets, before the moon's fade in. After a reset they fade out, jump unseen and fade in. In the least day they follow the hour exactly. Nothing flashes | `test_day_cycle.gd` (3); `test_shadows.gd` |
| E17 | Lamps (Q5; C17–C19). Each prop's lamps and yellow windows glow `LAMP_COLOR` at night where it puts them, and a lamp's pool lights the ground below it. They glow over the veil, as one group that adds, and a prop hides the glows behind it as `%Props` draws it. They are out by day, come on once a day and go out once, gradually, and a glow never adds more than the veil takes away, so it never clips to white | `test_lamps.gd` (7); `test_prop_art.gd`; `test_prop_scatter.gd`; `test_world_renderer.gd`; `test_daylight_run.gd`; P10, P10b (done) |

---

## 2. Review findings

Nothing in the game has a time of day, and the tools that Godot offers for one would break rules that M6 set for its legends. The findings, by severity, with the evidence on `main` (a5244fe) and the fix. C16–C22 came with Q4's and Q5's answers, and with TUT.

### High

| # | Finding | Evidence | Fix |
|---|---|---|---|
| C1 | **No light.** The scene is drawn as its art is, at every moment of a run. No node in the game tints the world: there is no `CanvasModulate` or `Light2D`, and no `modulate` but the fades of single items. `plan.md` speaks of the night only for M6's legends' colours | `ui/main.tscn` and `world/world.tscn` (nodes: World, Ground, SetPieces, RoadLayer, Skids, DisasterLayer, Props); `setpieces/tunnel.gd`:7 (a `CanvasModulate` deferred, C15); `plan.md`:213 | `DayCycle`, the clock and its lights (PR 1, §5.1–§5.3), and `Daylight`, the veil that shows them (PR 3, §5.5) |
| C2 | **Godot's usual tools darken what must stay lit.** A `CanvasModulate` tints every item on its canvas. That includes the ADD glows that light the dark in M6's legends, and the legends' MUL veils, which would then darken twice. A `modulate` on World does the same through inheritance. 2D lights need a `CanvasModulate` to make the dark they light, and each light adds a pass | `M6_PLAN.md`:560–561 (the veil at `VEIL_Z` 2, the glows at `GLOW_Z` 3 over it, "Over a veil, a glow lights the dark") | A MUL veil like the legends', between the world and the glows (§5.5); the other ways and why not (§5.10) |
| C3 | **The smoke's contract is absolute.** `test_car_controller.gd` asks that the smoke's luminance differ by `SMOKE_CONTRAST` (0.1) from every background, and through a tunnel. The night's light, of luminance 0.485, about halves every contrast: by day the thinnest passes with ×1.04 to spare, so at night it would fail | `tests/unit/test_car_controller.gd`:10, :144, :155, :179; step 0's margins (§5.7) | Scale the rule by the light's luminance, and check it in each key light. With today's art it then holds in a light of any colour (§5.7, Q12) |
| C4 | **Legends would darken twice at night.** A legend's veil multiplies by `VEIL_NIGHT`, (70, 80, 150), and the night's light by ≈ (107, 122, 184). Together that's ≈ (29, 38, 108), luminance 0.163: half of `VEIL_NIGHT`'s 0.325, which M6 tuned on the Fold4 (Q8 there), so its glows would stand in the black. A `VEIL_DUSK` legend would turn the night darker still | `M6_PLAN.md`:560; `disasters/legend.gd`: `_veil_color()` | Each channel darkens to the darker of the light and the veil: `min()` (§5.6) |
| C18 | **Overlaps darken and light twice.** Each sprite blends on its own, so where two shadows overlap the ground darkens twice, 0.51 for one's 0.3, and where two glows overlap they add twice and clip to white, which `AGENTS.md` §3 forbids | P8 (two shadows); P10 (two glows 2 px apart); `AGENTS.md` §3 (Legends: glows) | Shadows and Lamps are `CanvasGroup`s: each draws its children into one buffer, then the buffer once, at its own `self_modulate`, so one shadow or two darken 0.302 (P8). A group in a group draws wrong (P8b), so none is nested (§5.11, §5.12) |

### Medium

| # | Finding | Evidence | Fix |
|---|---|---|---|
| C5 | **Zones differ in length.** At 120 s a day the night begins 65 s into a zone. With the autopilot, the City lasts 56–61 s and ends at dusk, and the Village 33–46 s and ends by day; Rural and Meadows show the night, and the Desert is endless. So a run's first night comes in Rural, ≈ 122 s in | `areas/schedule.tres` (the City at turn 0, Rural 34, Meadows 100, the Village 200, the Desert 220); step 0's times over 20 seeds (§5.8) | `day_seconds` per zone, 120 s by default as asked. Q3 asks whether the City and the Village get shorter days |
| C6 | **A reset would jump.** When the car enters a zone at 22:00, the clock goes back to 07:00. Showing the clock's light at once would turn the night into day in one frame: abrupt, against the request, and a 0.58 jump in red | §5.2's lights | The light shown follows the clock's light at no more than `LIGHT_MAX_RATE` (§5.3) |
| C7 | **A short day would change fast.** At 30 s a day, dusk to night takes 1.9 s | §5.3 | The rate caps it. `validate()` reports days shorter than the rate can follow: just over 55.68 s with §5.2's keys (§5.3) |
| C8 | **The clock after the run.** `main.gd` counts the distance only while the run is on. If the clock ran on, the scene would change under game over and under a legend that took the light at its start | `ui/main.gd`:92–94; `disasters/disaster_director.gd`: `_start_disaster()` | The clock advances only while the run is on. The director takes the light when the run ends (§5.4, §5.6) |
| C9 | **The Web's Polygon2D bug.** In Godot 4.7.2 each redraw of a `Polygon2D` after its first raises WebGL errors (godotengine/godot#124726) | `AGENTS.md` §3; M6 S6, P2, P10 | Draw the veil once. Tint it by `self_modulate`, show it by `modulate.a`, move it by its position (§5.5) |
| C10 | **Physics order.** The camera pans and shakes in its physics step, at priority 0. A veil that moves before it is a frame behind (M6 N41) | `disasters/legend.gd`:19; `tests/unit/test_legend.gd`:94 | Daylight steps at `ViewVeil.PHYSICS_PRIORITY`, 1, as the legends do (§5.5) |
| C11 | **The veil is the legend's.** `Legend._made_veil()` and `_follow_camera()` are private. The name `Veil` is taken by Legend's enum | `disasters/legend.gd`:15, :126, :147 | `ViewVeil` in `world/` (PR 2). Legend and Daylight both use it (§5.5) |
| C16 | **Props cast nothing.** `PropDef` gives the point where a prop meets the ground, its `foot`, but not whether it stands up, lies flat or is a wall, nor how far above its foot its base line is | `areas/prop_def.gd`; `tools/art/make_props.gd` | `PropDef.shadow` (UPRIGHT, WALL, NONE) and `shadow_rise`, which `make_props.gd` writes into each prop's `.tres` (PR 4, §5.11) |
| C17 | **Props have no lights.** Nothing says where a prop's lamps and lit windows are | `make_props.gd` paints windows in the palette's yellow, and the lamp's head | `PropDef.lights` and `light_pools`, which `make_props.gd` writes from its yellow windows and lamp heads (PR 5, §5.12) |
| C19 | **Glows show through props.** Over the veil, a lamp behind a building would light its face. The props can't join the glows' group: a y-sorted group draws its children straight to the screen, and a group holds only the items at its own z | P10b: `servers/rendering/renderer_canvas_cull.cpp`:197–257, :438–492 | In Lamps' group, a black silhouette of each prop that isn't flat, in the order that `%Props` draws the props, covers the glows behind it and adds nothing (P10, §5.12) |
| C20 | **Shadows and lamps cost time.** Laid on the CPU, the shadows took 1.3–1.7 ms a frame. Each sprite was a node that GUT's `simulate()` walks: 3.1 ms a frame with PR 4's, 5.1 ms with PR 5's, against PR 3's 1.2 ms, and CI's GUT time grew from 98 s to 225 s | Measured headless (§6.5) | A material for each kind of shadow lays them on the GPU, 14–16 µs a frame (P11). The sprites are their node's internal children, which `simulate()` skips: 1.1–1.3 ms. The scatter tests use sparse props: 33 s → 6 s. The game's frames, mean / p99: 0.22 / 1.65 ms at PR 3, 0.27 / 2.06 at PR 4, 0.30 / 2.41 at PR 5 (§5.11, §5.12) |
| C21 | **The tutorial's switch.** TUT's switch doesn't call `_on_area_changed()`, which would enter the City a second time, so the City's clock would run on from the tutorial's start (TUT T19) | `ui/main.gd`:248–255; `TUTORIAL_PLAN.md`:122, :149, :256–267 | TUT Q18's default: the clock runs in the tutorial too, and `_on_tutorial_completed()` starts it again after `GameState.end_tutorial()` (PR 3, §5.4) |

### Low

| # | Finding | Evidence | Fix |
|---|---|---|---|
| C12 | **Devices take no arguments.** `--hour=` works in the editor, the tests and `smoke.sh` only. Godot 4.7.2's Android export strips them, and the Web's `index.html` passes none | M4_PLAN.md P4 | On devices, the night comes by playing, in Rural from the title's Start button in debug builds (ZS). A debug Web build can read `?arg=` as M4 P4's did (§6.4) |
| C13 | **World's children are pinned.** A test lists them | `tests/unit/test_world_renderer.gd`:376 | Daylight goes under Main, after Camera, not in World (§5.5). Shadows and Lamps go in World, and PRs 4 and 5 add them to the list |
| C14 | **Docs.** `plan.md` §3.7 lists AreaDef's fields; §5, §6 and §7 have no light; `AGENTS.md` §3 has no rule for it | `plan.md`:126, :185, :221, :238, :256 | Each PR documents what it adds, in lines of its own: PRs 1, 3, 4 and 5's Docs rows (§4), §4.5 |
| C15 | **The tunnel's darkening is deferred.** IP M5 planned a darkening `CanvasModulate` for the tunnel. M4 (K18, Q4) and M5 (L26, Q2) put it off, and `tunnel.gd`:7 still mentions it. A `CanvasModulate` would break C2's rule | `IMPLEMENTATION_PLAN.md`:390; `setpieces/tunnel.gd`:7 | Nothing in DN. §9 says how a tunnel can darken through Daylight instead |
| C22 | **The smoke in a shadow.** C3's rule asks for contrast relative to the light, but a shadow dims the ground under the smoke: in the sun's, alpha 0.3, the thinnest contrast is ×0.912 of the rule's over the world and ×0.730 through a tunnel, and in the moon's, 0.15, ×1.108 and ×0.886 | Step 0's probe over #292933, the darkest background, in every key light (§5.7) | The casts are black, so a shadow is a dimmer light, (1 − α)·L, through a tunnel too, and in it Q12's rule keeps §5.7's margins. `test_the_smoke_shows_in_a_shadow` checks it (N103). The owner judges a crash in a shadow on the Fold4 (§6.4) |

---

## 3. Decisions and open questions

The owner asked to be asked where needed, and each question had a default (`AGENTS.md` §2). On the first draft the owner answered Q4 and Q5 and kept the other defaults: "Keep the rest of the default decisions". So at 120 s a day the first zone of every run, the City, still ends at dusk, and the Village by day (Q3, §5.8); shorter days there would change only their `.tres` files.

| # | Question | Default (this plan) | Other answers |
|---|---|---|---|
| Q1 | What hour does a zone's clock start at? | 07:00, the first hour of full day. Every zone starts in today's look; dusk begins 50 s in, and the night 65 s in | 00:00, a literal reset: each zone starts at midnight, in the dark. 06:00: each zone starts at dawn, and its first 5 s brighten. An hour per zone |
| Q2 | How does a zone's reset look? | The light moves to the morning's at `LIGHT_MAX_RATE`: 2.33 s from the night, 1.93 s from dusk. A new run, after a retry or from the title, cuts to the morning at once | A cut at the zone's first tile as well. A slower fade (§5.3) |
| Q3 | What is per zone? | `day_seconds` alone: 120 s in every zone, as asked, so no `.tres` file changes. The lights and their hours are the same in every zone. Only Rural, Meadows and the Desert then show the night | Shorter days where zones are short: the City at 80 s and the Village at 56 s show each its night, for 12–18 s and 2–15 s (§5.8). Lights or hours per zone (§9) |
| Q4 | What does "movement" mean? | **Answered: shadows, in PR 4.** The light's colour follows the sun and the moon round the clock, and the props and the car cast shadows that turn with them, cut from their own art (§5.11) | The light alone. A soft shade under each prop. Shadows drawn as new art (§9) |
| Q5 | Lights at night? | **Answered: lamps that glow at night, in PR 5.** The street lamps and the yellow windows glow over the veil (§5.12). No headlights (§9) | None. Headlights too |
| Q6 | What does the light do after the run ends? | It stops with the clock. Game over and the title show the last run's road in its last light | The title goes back to day |
| Q7 | How do legends' veils mix with the night? | Each channel ends at the darker of the two (`min()`, §5.6). By day a legend looks as on `main`; at night, wherever its veil is darker than the night, it looks as it does by day | Multiply (C4: too dark). The legend's veil replaces the light |
| Q8 | A clock on the HUD? | None | A sun or moon icon, as art: Pixel Operator 8 has no such glyph (`AGENTS.md` §3) |
| Q9 | A setting to turn the night off? | None | A switch in Settings, saved by `SaveService`, for players who find the night hard to read |
| Q10 | How dark is the night? | §5.2's keys: `LIGHT_NIGHT` (0.42, 0.48, 0.72) has luminance 0.485. The smoke shows in a light of any colour (§5.7), so the owner can tune them freely on the Fold4 (E13) | Darker or lighter; bluer or greyer |
| Q11 | An argument to start at another hour? | `--hour=<h>`, for tests, the editor and `smoke.sh` (§5.9) | None |
| Q12 | How must the smoke show at night? | As by day, relative to the light: its contrast at least `SMOKE_CONTRAST` × the light's luminance (§5.7). The smoke stays black | The day's contrast in every light, with paler smoke at night |
| Q13 | Which documents change? | `plan.md` and `AGENTS.md`. IP stays as it is | IP too |
| Q14 | How does DN land? | **Answered: stacked PRs.** This plan's PR, then 5 stacked PRs, before or after M7 (§4.5) | One PR. After M7 |

---

## 4. Work breakdown

Step 0 is done (§4.1). Five stacked PRs follow (`AGENTS.md` §5). Each passes the five checks on its own and has its negative cases (§6.2). PRs 1 and 2 change nothing on screen; PR 3 shows the light, PR 4 adds the shadows and PR 5 the lamps. Each PR's code and tests are in commits of their own, with its files as the prototype has them: `git diff dn/5-lamps dn/prototype` shows only the docs, which each PR then adds (C14), and this plan.

| PR | Branch → base | What | Scripts | Test scripts | Tests |
|---|---|---|---|---|---|
| — | `dn/prototype` | Step 0: the PRs' code and tests, the probes and the measurements (§4.1). Never a PR | — | — | — |
| 1 | `dn/1-cycle` → `dn/plan` (#70), then `main` (#76) | The clock: `DayCycle`, its lights and its rate, and `AreaDef.day_seconds` | +2 | +1 | +12 |
| 2 | `dn/2-night-ready` → `dn/1-cycle` | Ready for the night: `ViewVeil`, legends' veils in an ambient light, and the smoke in every light | +2 | +1 | +2 |
| 3 | `dn/3-daylight` → `dn/2-night-ready` | Daylight in the game, `--hour=<h>`, and the City's day from the tutorial's switch | +3 | +2 | +14 |
| 4 | `dn/4-shadows` → `dn/3-daylight` | The props' and the car's shadows, by the sun and by the moon | +3 | +2 | +20 |
| 5 | `dn/5-lamps` → `dn/4-shadows` | Lamps and lit windows at night; this plan's final sync | +2 | +1 | +11 |

### 4.1 Step 0: the prototype (done)

On `dn/prototype`, from `main` at 1047e17:
1. **The constants' place.** In `config/tuning.gd`, PR 1's block after `CRASH_SHAKE_SECONDS` and PR 4's after it, both before `# The City's legends.`, the first of M6's per-area comments (M6_PLAN.md §5.10); PR 5's three after `PROP_BELOW`, with the props'. No name is taken, and none ends in `_HZ`, which `test_disasters.gd` checks.
2. **The checks.** The five checks pass on each PR's head, with a clean tree (§6.1).
3. **The negative cases.** A script runs them (§6.2): 43 for the first draft's three PRs, 105 now. Its runs found five gaps, each now closed by a test: N5, a jump inside `enter()`, which the rate test didn't see (78cc8ae); N13 and N14, a veil that mixed or had a relative z (7e752bf); N26, a test helper that set no hour without `enter()` (7982976); and N81, the lamps lit by the group's `modulate`, which what it holds takes too (1e97dd7).
4. **The probes.** P1–P4, P6 and P8–P11 ran (§6.5), the Web's in Chrome and Firefox. P5 needs the Fold4 (§6.4). P7, a test of the first draft's Q4 default, went with Q4's answer.
5. **The new `main`.** 257af7a merges ZS, where `--hour` went in after `--area`; 5c724ad #63; and c38f01c TUT, with `ui/main.gd`'s two conflicts resolved as TUTORIAL_PLAN.md §4.5 says, and 5e20b2d C21. The checks, the cases and the warnings ran again after each.
6. **The internal reviews** (`AGENTS.md` §7), by gpt-6.1-sol (§4.6).

### 4.2 PR 1 — The clock (`dn/1-cycle` → `dn/plan`)

The clock and its lights, with no node. Nothing in the game reads them yet.

| Area | Files | Change |
|---|---|---|
| Clock | `world/day_cycle.gd` (+ `.uid`) | New `DayCycle extends RefCounted`: `start_hour`, `day_seconds`, `seconds`, `light`; `enter()`, `snap()`, `advance()`, `hour()`, `target()`, `static light_at()`, `static least_day_seconds()` (§5.1–§5.3) |
| Tuning | `config/tuning.gd` | `DAY_START_HOUR`, `LIGHT_DAWN`, `LIGHT_DUSK`, `LIGHT_NIGHT`, `LIGHT_HOURS`, `LIGHT_COLORS` and `LIGHT_MAX_RATE` (§5.2) |
| Areas | `areas/area_def.gd` | `@export_group("Light")` after Audio, with `day_seconds := 120.0`. `validate()` reports a day that isn't finite, or shorter than `DayCycle.least_day_seconds()` (C7). No `.tres` file changes: 120 is the default, which Godot doesn't save |
| Tests | `tests/unit/test_day_cycle.gd` (+ `.uid`) | 10 tests (below) |
| | `tests/unit/test_area_def.gd` | `test_validate_reports_a_day_too_short_to_follow`: the least day passes, and so does the day that the message names, 55.69 s; a hundredth less, and 0, are reported. `test_validate_reports_a_day_that_isnt_finite`: NaN, INF and −INF |
| Docs | `plan.md` | **Δ** §3.7: `day_seconds` in AreaDef's block |

`test_day_cycle.gd` (E2–E5):
- `test_the_hour_runs_round_the_clock_in_day_seconds`, from 07:00 and from 22:00, within 1e-6 h. `test_entering_a_zone_starts_its_clock_at_the_start_hour`.
- `test_each_key_hour_has_its_light`, exactly. `test_the_day_is_exactly_white_from_seven_to_five`, every 0.01 h. `test_between_keys_the_light_eases_in_and_out`: no channel turns back, and each segment's first and last steps move less than a tenth of a straight blend's.
- `test_the_light_shown_never_changes_faster_than_the_max_rate`: in days of 120 s and of the least, 24 zones reset the clock from every hour. Frame to frame, `enter()`s included, within 1e-6.
- `test_after_a_reset_the_light_catches_up_and_then_follows_exactly`: from 22:00, white after floor(d / (rate × delta)) to ceil(…) + 1 frames, each channel the same share of its way within 1e-4, then `light == target()` for a day.
- `test_snap_shows_the_light_of_the_hour_at_once`, at seven hours. `test_least_day_seconds_is_the_shortest_day_the_rate_can_follow`: and 0.95 of it isn't. `test_a_day_of_no_seconds_is_an_error_and_stops_the_clock`: 0, −5, NaN, INF and −INF.

### 4.3 PR 2 — Ready for the night (`dn/2-night-ready` → `dn/1-cycle`)

Legends learn the light they play in, and the smoke's tests check every light. The light stays white until PR 3, and in white every legend draws as on `main`.

| Area | Files | Change |
|---|---|---|
| Veil | `world/view_veil.gd` (+ `.uid`) | New `ViewVeil extends Polygon2D`, with what `Legend._made_veil()` makes on `main`: the square, the MUL material, the absolute `VEIL_Z` and the transparent wait. `PHYSICS_PRIORITY`; `follow(p_camera)`; `shade(p_light)`, which hides the veil in white (§5.5, C11) |
| Legends | `disasters/legend.gd` | `_veil` is a `ViewVeil`; `_made_veil()` and `_shown` go. The beats `shade()` the veil, and `_follow_camera()` calls `follow()`. `_veil_color()` becomes `_own_color()`, and a new `_veil_color()` takes the ambient light into account (§5.6) |
| | `disasters/disaster_base.gd`, `disaster_director.gd` | `var ambient := Color.WHITE`. `play_disaster(…, ambient := Color.WHITE)` keeps it for `_start_disaster()`, and `clear()` sets it back to white |
| Tests | `tests/unit/test_view_veil.gd` (+ `.uid`) | `test_the_veil_covers_every_view`, moved from `test_legend.gd`. `test_the_veil_multiplies_at_veil_z_and_starts_hidden`, under a parent at z 3 |
| | `tests/unit/test_legend.gd` | −1, moved. `test_at_night_a_veil_darkens_only_what_the_night_hasnt`: both veils in five lights; each channel ends at the darker of the two within 1e-6, no tint is above 1, and a veil with nothing left to darken is never drawn |
| | `tests/unit/test_disaster_director.gd` | `test_a_disaster_waits_for_the_car_to_stop` plays in `LIGHT_NIGHT`, which the disaster gets as its `ambient` |
| | `tests/unit/test_car_controller.gd` | The two smoke tests check each key light, with the rule scaled by its luminance (§5.7). In white they check what they check on `main` |

### 4.4 PRs 3–5 — What shows

#### PR 3 — Daylight (`dn/3-daylight` → `dn/2-night-ready`)

| Area | Files | Change |
|---|---|---|
| Light | `world/daylight.gd` (+ `.uid`) | New `Daylight extends ViewVeil`: `cycle` and `camera`. At `PHYSICS_PRIORITY`, `_physics_process()` calls `refresh()`, which follows the view and shades it with the cycle's light (§5.5) |
| Game | `ui/main.tscn` | `%Daylight` under Main, after Camera (C13) |
| | `ui/main.gd` | `--hour=<h>` in the header's arguments. `_ready()` gives Daylight the camera and `_parse_hour()`'s start hour. `_physics_process()` advances the clock while the run is on, in the tutorial too. `_on_area_changed()` and `_on_tutorial_completed()` enter the zone's clock (C21). `_start_run()` snaps the light, and `_on_disaster_triggered()` gives it to the director (§5.4, §5.9) |
| Tests | `tests/unit/test_daylight.gd` (+ `.uid`) | 3 tests (below) |
| | `tests/integration/test_daylight_run.gd` (+ `.uid`) | 10 tests through `tests/helpers/main_scene.gd` (below) |
| | `tests/integration/test_tutorial.gd` | `test_the_city_day_starts_at_the_switch`: at `--tutorial --hour=16`, with the autopilot, the clock runs over 10 s in the tutorial, is at 16:00 again at the switch, and the light goes back to the day's no faster than the rate |
| Docs | `plan.md` | **Δ** §5.5 Day and night (new); §6: the audio doesn't follow the hour; §7.1: Daylight; §7.2: `DayCycle`, `ViewVeil` and `Daylight` |
| | `AGENTS.md` | §1's layout: `world/` has the day and the night. §3: a rule for the light (§5.5) |

`test_daylight.gd`:
- `test_by_day_the_veil_is_transparent_and_by_night_it_shows_the_light`: at each key hour and halfway to the next.
- `test_in_the_games_frames_the_veil_follows_the_view_of_the_same_frame`: entered before a camera that pans and shakes; over 10 engine physics frames, within 1e-3 px (C10).
- `test_daylight_is_never_redrawn`: a day at a tenth of an hour per engine frame, with the low-processor sleep at 0, and no `draw` after the first (C9).

`test_daylight_run.gd`:
- `test_each_run_starts_at_once_in_the_morning`, and after a Retry from a game over at night.
- `test_the_title_keeps_the_night_and_play_starts_the_morning`: after a game over at 22:00, Title; for 120 frames the hour, the light and the veil stay the night's, and Play starts the morning at once (E5, E6).
- `test_the_light_follows_the_clock_while_the_car_drives`: `--autopilot --hour=17`; after 600 frames, still in the City, it is 19:00, in the hour's light exactly.
- `test_each_new_zone_starts_its_clock_again`: at 22:00, Rural's `area_changed` sets 07:00 at once; the light follows at the rate and is white within 2.4 s.
- `test_each_zone_runs_its_clock_at_its_own_pace`: a Rural of 60 s a day; 600 frames from 17:00 it is 21:00.
- `test_the_clock_stops_when_the_run_ends_and_while_paused`: paused, in DISASTER and in GAME_OVER.
- `test_the_hour_argument_starts_every_zone_at_that_hour`: 22, 26 and −1.5; `noon`, nothing and `1e999` are errors.
- `test_at_night_the_disaster_plays_in_the_light_the_run_ended_in`.
- `test_the_light_changes_nothing_but_the_view`: 1,200 frames of `--autopilot --seed=1` at 07:00 and at 19:00, each from silence with `AudioDirector` stepped. The buses, the cross-fades, the loops, each player and the sounds played are the same on every frame, and the runs end alike (E7).
- `test_the_veil_darkens_the_world_but_not_the_glows_or_the_ui`: at night, once seed 1's disaster shows, every MUL item under World and in the set pieces, their nodes' own parts included, draws at `VEIL_Z`, and all else but what adds below it; the UI is on layers above.

#### PR 4 — Shadows (`dn/4-shadows` → `dn/3-daylight`)

| Area | Files | Change |
|---|---|---|
| Props | `areas/prop_def.gd` | `enum Shadow { UPRIGHT, WALL, NONE }`, `shadow` and `shadow_rise`, which `validate()` checks (C16) |
| | `tools/art/make_props.gd`; 10 props' `.tres` | `SHADOWS`: the walls, the flat props and the boxes' centres (§5.11). Each `.tres` gets the lines that differ from the defaults; the art doesn't change |
| Clock | `world/day_cycle.gd` | `shadow` and `shadow_alpha`, shown, which `snap()` and `advance()` set; `static shadow_at()` and `shadow_alpha_at()` (§5.11) |
| Tuning | `config/tuning.gd` | `SUN_RISE_HOUR` to `SHADOW_ALPHA_RATE`, after PR 1's block |
| Shadows | `world/shadows.gd`, `world/shadows.gdshader` (+ `.uid`s) | New `Shadows extends CanvasGroup` and its `Cast`: `add()`, `remove()`, `count()`, `refresh()`, `car_cast()`, `static laid()` and `reach()`. The shader lays a frame along `lay_x` and `lay_y` (§5.11) |
| | `world/iso.gd`, `world/prop_pool.gd` | `WIDTH_PX` and `HEIGHT_PX`. A pool may make its sprites its layer's internal children (C20) |
| | `world/prop_scatter.gd` | `shadows`: a row's props cast as they show, in their frames, and stop as they hide |
| | `world/world.tscn`, `world/world_renderer.gd` | `%Shadows` after Skids, hidden. `cycle`; `build()` gives the scatter the shadows, and `_process()` refreshes them |
| Car, game | `car/car_controller.gd`, `ui/main.gd` | `body_texture()` and `body_frame()`. `_ready()` gives World Daylight's clock |
| Tests | `tests/unit/test_shadows.gd` (+ `.uid`) | 10 tests (below) |
| | `tests/integration/test_shadows_run.gd` (+ `.uid`) | `test_the_props_and_the_car_cast_shadows_by_the_zones_clock`: at 09:00, World has Daylight's clock, the group its alpha, and the car's shadow lies under the car |
| | `tests/unit/test_day_cycle.gd` | 5 tests (below) |
| | `tests/unit/test_car_controller.gd` | `test_the_smoke_shows_in_a_shadow`: at both shadows' alphas, in each key light, over each background and through each cover, the smoke keeps `SMOKE_CONTRAST` × the luminance of the shadow's light (C22) |
| | `test_prop_art.gd`, `test_prop_scatter.gd`, `test_world_renderer.gd` | `test_each_shadow_falls_from_where_its_prop_meets_the_ground`: the fences' posts stand on their base lines, and a box's side corners are level with its footprint's centre. `test_each_prop_casts_its_shadow_while_it_shows_in_its_frame`, on sparse props (C20). `test_the_shadows_follow_the_clock_and_the_props`; World's children with Shadows |
| Docs | `plan.md`, `AGENTS.md` | **Δ** §5.2: the shadows; §7.1 and §7.2: Shadows. `AGENTS.md` §3: a rule for the shadows (§5.11) |

`test_shadows.gd`:
- `test_an_upright_props_shadow_falls_from_its_foot_across_the_light`: a texel h px above the foot lies h times the clock's shadow from it, and the frame's left stays on the left (N44). `test_a_walls_shadow_falls_from_its_base_line`. `test_flat_props_cast_none`.
- `test_the_shadows_show_at_the_clocks_alpha_as_one`: opaque black casts in a group at the clock's alpha (P8), hidden without a clock or a shadow.
- `test_the_shadows_turn_with_the_clock`. `test_removed_shadows_give_their_sprites_back`, as internal children.
- `test_the_cars_shadow_follows_its_frame_and_fades_with_it`: its body's frame, scale and alpha; a hidden car casts none.
- `test_the_clock_turns_the_props_shadows_but_no_sprite`. `test_each_props_shadow_is_drawn_wherever_it_falls`: each prop's rect holds its shadow at each quarter hour, and at the longest every way round (C20, P11).
- `test_the_shader_lays_each_corner_where_laid_puts_it`: the shader's `VERTEX` line, run as an `Expression`, puts each corner of an upright and a wall frame where `laid()` does, at each hour. So the tests above, which check `laid()`, check the shader too.

`test_day_cycle.gd` (E15, E16): `test_shadows_sweep_from_the_right_to_the_left_in_front_of_what_casts_them`, `test_a_shadow_is_as_long_as_the_light_is_low_up_to_the_longest`, `test_shadows_fade_out_as_the_sun_sets_and_in_as_the_moon_rises`, `test_the_shadows_shown_follow_the_hour_exactly_in_the_least_day_too` and `test_after_a_reset_the_shadows_fade_out_jump_unseen_and_fade_in`.

#### PR 5 — Lamps (`dn/5-lamps` → `dn/4-shadows`)

| Area | Files | Change |
|---|---|---|
| Props | `areas/prop_def.gd` | `lights` and `light_pools`: boxes from the foot (C17) |
| | `tools/art/make_props.gd`; 4 props' `.tres` | A window painted the palette's yellow is a light, grown by `WINDOW_HALO`. A lamp's head, `LAMP_HEAD`, is one grown by `LAMP_HALO`, with a pool of ground `LAMP_POOL` under it. The art doesn't change |
| Tuning | `config/tuning.gd` | `LAMP_COLOR`, `LAMP_ALPHA` and `LAMP_POOL_SHARE`, after `PROP_BELOW` |
| Lamps | `world/lamps.gd`, `world/lamps.gdshader` (+ `.uid`s) | New `Lamps extends CanvasGroup` and its `Lit`: `add()`, `remove()`, `shown()`, `refresh()` and `static strength()`. The shader is Godot's canvas group shader, adding (§5.12) |
| | `world/prop_scatter.gd` | `lamps`: a row's props show their silhouettes and glows as they show, in their frames, and take them away as they hide |
| | `world/world.tscn`, `world/world_renderer.gd` | `%Lamps`, World's last child. `bind()` gives the scatter the lamps, and `_process()` refreshes them |
| Tests | `tests/unit/test_lamps.gd` (+ `.uid`) | 7 tests (below) |
| | `test_prop_art.gd`, `test_prop_scatter.gd`, `test_world_renderer.gd` | `test_each_prop_lights_its_yellow_windows_and_lamps`: each light's centre is yellow. `test_each_prop_lights_its_lamps_while_it_shows`, on sparse props. `test_the_lamps_glow_over_the_veil_at_night`: at `GLOW_Z`, absolute, adding and not y-sorted, and out without a clock and by day. World's children with Lamps |
| | `tests/integration/test_daylight_run.gd` | `test_the_lamps_light_by_the_zones_clock`: in the City at 22:00, over 20 glows at the light's strength, and out at noon. `_blends()` judges what a canvas group holds by the group's material, where Godot draws it in the group (P10b) |
| Docs | `plan.md`, `AGENTS.md`, this plan | **Δ** §5.3: the lights; §7.1 and §7.2: Lamps. `AGENTS.md` §3: a rule for the lamps (§5.12). This plan's status, §4.6, §6.1 and the device results |

`test_lamps.gd`:
- `test_the_lamps_draw_as_one_group_that_adds_over_the_veil`: what the group holds draws in it, at its z, with no material, lit by the group's `self_modulate` alone (P10, P10b).
- `test_each_light_and_pool_glows_where_its_prop_puts_it`. `test_silhouettes_are_used_again_with_their_glows`, as internal children.
- `test_the_silhouettes_draw_in_the_order_props_draws_the_props`: by y, then by Props' order, as props and the car come and go.
- `test_out_by_day_and_without_a_clock_and_on_at_night`. `test_a_glow_never_adds_more_than_the_veil_takes_away`, at each quarter hour and through resets.
- `test_the_lamps_fade_on_once_a_day_and_out_once`, in the least day and the reference one, no faster than the light (E17).

### 4.5 Landing

1. This plan's PR (#64, `dn/plan` → `main`), docs only, lands first.
2. PR 1 targets `dn/plan`, as M6's first PR did `m6/plan` (#46), and each next PR the previous one's branch, so that each diff shows only its own files. Only PRs whose base is `main` are merged. After #64's squash, PR 1 merges `origin/dn/plan` and `origin/main`, and is retargeted to `main` before `dn/plan` is deleted: deleting `m6/plan` closed #46 (ROADGEN_PLAN.md:195). After each later squash, the next PR merges its base's final state and `main` (`AGENTS.md` §5).
   That retarget didn't happen. #64 was squash-merged as 64f6693 at 01:41:40 UTC on 2026-11-14, and 11 s later #70–#74 were registered as native stack #75, whose base was then `dn/plan`. A stack merges into its bottom PR's base, so #70 merged into `dn/plan` as bc36f41, not into `main`. GitHub then retargeted #71 to `dn/plan` and rebased `dn/2-night-ready` onto bc36f41 with a force-push, 21748d4 to f08c2e4, with the same tree. It rebases only the next PR's branch, so #72's diff grew to 28 files. The repair merges, and rebases nothing (`AGENTS.md` §5). `dn/1-cycle` merges `dn/plan` and `main`, and is PR 1 again as #76, → `main`. `dn/2-night-ready` merges 21748d4 back, then `dn/1-cycle`, and #71 targets `dn/1-cycle` again. Each later branch merges the one below. No tree changed. #75 was unstacked and keeps only #70; stack #77 holds #76, #71, #72, #73 and #74, on `main`. Register a stack only once its bottom PR targets `main`: a stack merges into that PR's base, and the API can't put a PR below it.
3. **Lines apart.** After a squash, the next PR conflicts where its lines touch the squashed PR's, so in each file that neighbouring PRs both change, a line of `main` stands between theirs. In `tuning.gd`, PR 5's lines go with the props'; in `world_renderer.gd`, PR 4's are in `build()` and PR 5's in `bind()`; in `plan.md` and `AGENTS.md` too, so PR 5 notes Lamps after §7.1's tree: a line in it would change the Props line, next to PR 4's Shadows (C14). No PR changes a file that the PR before it adds, and only PR 5 changes this plan. Simulated with `git merge-tree`, the landing merges clean, squash by squash, and ends with `dn/5-lamps`'s tree.
4. A review fix goes on the branch of the PR that adds or changes the file, and is merged up (`AGENTS.md` §5).
5. M7. Whichever lands first, the other merges `main` as usual, after `git merge-tree` shows the conflicts. Both may change `ui/main.gd`, `ui/main.tscn`, `config/tuning.gd`, `plan.md` and `AGENTS.md`, where DN's lines are in blocks of their own.
6. **The native stack.** Merging #74 merges stack #77: #76 and #71–#74 land on `main` together, as one operation, each as its own squash, from the bottom up. The stack must be linear: each branch contains the one below, and `dn/1-cycle` contains `main`'s head. The merges keep it so. If `main` moves first, GitHub offers **Rebase stack**, which would rebase these merges: instead, `dn/1-cycle` merges `main`, and each branch the one below. Merging one PR of the stack alone makes GitHub rebase the next branch at once, as it did `dn/2-night-ready`. So to land the PRs one by one, unstack #77 first (`gh api --method POST repos/pompomon/roadgame/stacks/77/unstack`), check that `gh api 'repos/pompomon/roadgame/stacks?pull_request=<n>'` prints `[]` for each, and follow step 2.

### 4.6 Review fixes

The internal reviews (`AGENTS.md` §7) and the PRs' reviews add their fixes here, each with its tests and its negative case. gpt-6.1-sol reviewed the first draft and the prototype at 7982976 (seven findings, one declined, below), c9b65ed (two), PRs 4 and 5 at 1400a3e (three), the lamps' redesign at 5e8d4c8 (one), the code since then at 39be8d7 (one), this plan (two) and the PRs' docs (none). None was blocking, and the rest are fixed.

| PR | Change | Tests | Negative case |
|---|---|---|---|
| 1 | `enter()` and `validate()` took a day that isn't finite: with NaN the light would be NaN, and with INF the clock would stand still, unreported. Both now report it, and `enter()` stops the clock | `test_a_day_of_no_seconds_is_an_error_and_stops_the_clock`, with NaN, INF and −INF; `test_validate_reports_a_day_that_isnt_finite` | N36, N38 |
| 1 | `validate()`'s message named 55.68 s, but the least day is 55.680001… s. It now rounds up to the hundredth, 55.69 s (§5.3) | `test_validate_reports_a_day_too_short_to_follow` | N37 |
| 3 | No test gave a zone a day of its own, so `_on_area_changed()` could `enter(120.0)` and pass | `test_each_zone_runs_its_clock_at_its_own_pace` | N39 |
| 3 | The sound test compared the tracks and the buses once, after the runs, and never stepped `AudioDirector`. Then it compared no player's own gain or bus. It now steps `AudioDirector` with each run, from silence, and compares every frame's sound, each player's included (§4.4) | `test_the_light_changes_nothing_but_the_view` | N40–N43; N33 still fails it |
| 3 | Nothing checked the title: a clock that ran behind it, or a Title that reset it, passed (E5, E6) | `test_the_title_keeps_the_night_and_play_starts_the_morning` | N104, N105 |
| 4 | The car's shadow was checked against `body_frame()`, which Shadows reads, so a `body_frame()` that returned 0 passed. It is now checked against the body's own frame, as the car turns | `test_the_cars_shadow_follows_its_frame_and_fades_with_it` | N58 |
| 4 | Nothing checked that the game gives World Daylight's clock | `test_the_props_and_the_car_cast_shadows_by_the_zones_clock` | N59 |
| 4 | The shadows' tests checked `laid()`, Shadows' model of the shader, and not the shader: one that left each frame as it was passed. The new test runs the shader's line | `test_the_shader_lays_each_corner_where_laid_puts_it` | N101, N102 |
| 4 | E10 promised the smoke's contrast over everything the world draws, but no test put the smoke in a shadow (C22) | `test_the_smoke_shows_in_a_shadow` | N103 |
| 5 | Where two glows overlapped they added twice, past white. The lamps are now one group that adds (C18). Redesigned so, the group also holds the props' silhouettes, so that a lamp behind a building no longer lights its face (C19) | `test_the_lamps_draw_as_one_group_that_adds_over_the_veil`, `test_the_silhouettes_draw_in_the_order_props_draws_the_props` | N75–N80, N84 |
| 5 | `_blends()` took the outermost group's material for every item under it, but Godot groups only what draws at the group's z, and nothing if it y-sorts (P10b). So a y-sorted Lamps, or a glow at another z, drew plain over the veil and passed. It now takes a group's material only for what the group holds | `test_the_veil_darkens_the_world_but_not_the_glows_or_the_ui`, `test_the_lamps_draw_as_one_group_that_adds_over_the_veil` | N86–N88 |
| Plan | E1 now says that after a reset the light shown takes 140 frames to catch up (E4), and §5.10 that its fallback would dim the phantom bus's lamps, so it breaks E8 and C2 | — | — |
| Plan | §5.11 gave the shadow's length on the ground, 1 / tan(height), as its length on the screen. It now gives both ([#64](https://github.com/pompomon/roadgame/pull/64#discussion_r4568564611)) | — | — |

Declined: `day_seconds = 120.0` in each area's `.tres`. Godot saves there only what differs from the script's default, so no area's sets `offroad_limit_tiles` either. A zone that Q3 changes gets its line.

---

## 5. Design

### 5.1 The clock

`DayCycle` (`world/day_cycle.gd`, PR 1) is a pure `RefCounted`, like `CarSim` (D2): the clock of the zone that the car is in, and the light and the shadows that it gives. Daylight holds one (§5.5). `main.gd` steps it in `_physics_process()` at 60 Hz while the run is on, and tests step it with a fixed `DELTA`. It draws no random numbers (IP §5.3). Only Daylight, World's Shadows and Lamps, and `main.gd`, which gives its light to the director when a run ends (§5.6), read it. So the road, the car and the audio can't depend on it (E7).

- Each `AreaDef` gets `day_seconds`, 120 by default, in a group of its own after Audio. Godot doesn't write a default into a `.tres` file, so none changes.
- `validate()` reports a day that isn't finite, `"%s: day_seconds isn't finite"`, or a shorter one, `"%s: day_seconds is below %.2f"`, with its other problems. The least is `least_day_seconds()` rounded up to the hundredth, 55.69 s, so that the day that the message names is long enough (§5.3). So `test_the_game_schedule_is_valid` fails for a zone whose `.tres` sets one (N11).
- `enter()` starts a zone's clock and keeps the light shown; `snap()` shows the hour's light and shadows at once. `_start_run()` calls `enter()` for the first zone, then `snap()` (§5.4).
- With `day_seconds` 0 the clock stands at `start_hour`: at boot, and after `enter()` has reported a day of no seconds. `advance()` still moves the light shown to that hour's.

### 5.2 The lights

Six keys round the clock. Between two keys, every channel eases from one key's colour to the next's with the same weight, `smoothstep()` of the time between them.

| Hour | Key | Colour, 0–1 | Luminance |
|---|---|---|---|
| 04:30 | `LIGHT_NIGHT` | (0.42, 0.48, 0.72) | 0.485 |
| 06:00 | `LIGHT_DAWN` | (0.92, 0.74, 0.78) | 0.781 |
| 07:00 | White | (1, 1, 1) | 1 |
| 17:00 | White | (1, 1, 1) | 1 |
| 18:30 | `LIGHT_DUSK` | (1.0, 0.72, 0.52) | 0.765 |
| 20:00 | `LIGHT_NIGHT` | (0.42, 0.48, 0.72) | 0.485 |

The luminance is `Color.get_luminance()`'s: 0.2126 r + 0.7152 g + 0.0722 b. White is a key twice, so from 07:00 to 17:00 the light is white with white, which `lerp()` gives exactly (E1). The colours are a first guess, which the owner tunes on the Fold4 (Q10); `least_day_seconds()`, `validate()` and the tests follow them. They go in `config/tuning.gd` after `CRASH_SHAKE_SECONDS` (§4.1). At 120 s a day an hour takes 5 s: the day lasts 0–50 s into a zone, dusk 50–65 s, the night 65–107.5 s and dawn 107.5–120 s.

### 5.3 Gradual

"Gradual, not abrupt" has two parts.
1. **Eased keys.** `smoothstep()` has no slope at either end, so the light leaves each key and reaches the next gently. Between two keys each channel only rises or only falls, and so does the luminance, a sum of the channels with positive weights.
2. **A rate.** The light shown moves toward the light of the hour along the straight way, its farthest channel by at most `LIGHT_MAX_RATE`, 0.25, × delta in a frame (`advance()`).

| Segment | Hours | Largest change | Steepest at 120 s | Least day |
|---|---|---|---|---|
| Night to dawn | 04:30–06:00 | 0.50, red | 0.100 a second | 48.00 s |
| Dawn to day | 06:00–07:00 | 0.26, green | 0.078 a second | 37.44 s |
| Day to dusk | 17:00–18:30 | 0.48, blue | 0.096 a second | 46.08 s |
| Dusk to night | 18:30–20:00 | 0.58, red | 0.116 a second | **55.68 s** |

A segment of `span` hours whose largest change in a channel is Δ is steepest at its middle, where `smoothstep()`'s slope is 1.5: 1.5 Δ / (span × D / 24) a second in a day of D seconds. That stays within the rate R for D ≥ 36 Δ / (span R). The night's red, 0.42, is 0.41999999 as a 32-bit float, so the least day is 55.680001 s, and `validate()` names 55.69 s (§5.1).
- **Within a zone's day the rate never acts.** In a day at least `least_day_seconds()` long, once the light shown has reached the light of the hour, it is that light exactly on every frame. At 120 s the steepest change is under half the rate.
- **After a reset the rate acts** (E4). For 50 s after each reset to 07:00 the light of the hour holds still at white, and the light shown reaches it in 140 frames, 2.33 s, from the night, and 116 from dusk's key. If `--hour=` starts the zones where the light moves, the light of the hour moves more slowly than the rate, so the light shown still catches up.
- **The straight way.** `lerp()` moves every channel by the same share of its way, so on the way from the night to the morning the light shown is a blend of the two, never a colour that neither is. Each channel at the rate on its own would pass through a pale blue (N9).
- **It stays among the keys.** The light shown is always a blend of keys, with weights from 0 to 1 that add up to 1. So a rule that is linear in the light and holds at each key holds in every light that the game shows (§5.7).
- **Nothing flashes** (WCAG 2.3.1, M6_PLAN.md §5.6). No channel changes faster than 0.25 a second, so a change of a tenth of white in luminance takes at least 0.4 s: at most 1.25 flashes a second even if it turned back each time, and it turns only at keys and resets, seconds apart. No light is a saturated red: dusk's red share is 0.446, under WCAG's 0.8.
- **A slower reset** (Q2). `enter()` could cross-fade from the light at the reset over `LIGHT_RESET_SECONDS`, say 4 s: 0.22 a second at most, within the rate. It isn't in the defaults.

### 5.4 Zones and runs

| Moment | Clock | Light shown | In `main.gd` |
|---|---|---|---|
| Boot, and the title before the first run | Stands at `start_hour` (`day_seconds` 0) | White; the veil hides | — |
| A run starts: `--play`, Play or Retry | The first zone's: `enter()` | The hour's at once: `snap()`, then Daylight's `refresh()` | `_start_run()` |
| The run is on, the tutorial's too | `advance(delta)` in each physics frame | Follows the light of the hour | `_physics_process()` |
| The car enters a zone | `enter()`: back to `start_hour`, at the zone's `day_seconds` | Moves to the new hour's light at the rate | `_on_area_changed()` |
| The tutorial's switch to the City | `enter()`, after `GameState.end_tutorial()` (C21) | As for a new zone | `_on_tutorial_completed()` |
| The run ends: a wrong or missed turn, or a crash | Stops: the state isn't RUNNING | Stays. After a turn the director gives it to the disaster as its `ambient` | `_on_disaster_triggered()` |
| Paused | Stops: the tree is paused (`game_state.gd`:58–61) | Stays | — |
| Game over, then the title | Stopped | Stays over the last run's road until the next run (Q6) | — |

- **Why `refresh()`.** Retry and Play come as input, between physics frames. Without it, the frame drawn before Daylight's next step would show the last run's light over the new run (N28).
- **The order in a frame.** Main is the scene's root at priority 0, so its `_physics_process()` advances the clock before the car steps. The car's step may enter a zone, whose clock the next frame's `advance()` runs: the hour is at most a frame late, and the tests allow one `DELTA`. The camera steps at priority 0 and Daylight at 1, after it, so the veil covers this frame's view (C10). World refreshes the shadows and the lamps in `_process()`, after the frame's physics steps.
- **In tests.** GUT's `simulate()` steps a node and then its children in the tree's order, whatever their priority, and while the tree is paused (`addons/gut/gut_to_move.gd`:72–92). So `main.tscn` puts Daylight after Camera, `_physics_process()` asks GameState, not the tree, whether the run is on, and `test_daylight.gd` checks the priority in the engine's own frames.
- **The tutorial** (C21). TUT's switch emits `EventBus.area_changed` but doesn't call `_on_area_changed()`, which would enter the City again (TUT T19). So the City's day starts at the switch by a line of its own, as its distance and turns do. The clock runs in the tutorial too (TUT Q18's default).

### 5.5 The veil

Daylight multiplies everything drawn under it by the light, as the legends' veils do (M6_PLAN.md §5.5): one square over the view, with a `CanvasItemMaterial` in `BLEND_MODE_MUL`, at `Tuning.VEIL_Z`, 2, absolute.
- The ground, the road, the skid marks, the shadows, the set pieces, the props, the car and the legends' parts draw below `VEIL_Z`. The legends' glows and the lamps draw above it, at `GLOW_Z`, 3, and the UI on its own `CanvasLayer`s. So the night darkens the world, but not the glows or the UI (E8). P1 listed World's canvas items by z while a legend played: 601 at 0, 2 at 1, the legend's veil at 2 and its 2 glows at 3.
- A colour c under the light L shows L × c, channel by channel. Two MUL veils commute: P2 drew Daylight's and a legend's in both orders, at most 1/255 apart in a channel (§6.5).
- **`ViewVeil`** (PR 2, C11) is what `Legend._made_veil()` builds on `main`, as a class: the square, the material, the absolute z and the transparent wait. `follow()` centres it on the camera's view, shake included, and `shade()` sets its colour. Daylight (PR 3) extends it with a `cycle` and a `camera`, and `refresh()` does both.
- **By day nothing changes** (E1). In white, `shade()` sets `modulate.a` to 0, which the canvas skips. P4 compared 600 frames of `main` and of PR 3 from the same seed: the same, byte for byte. From PR 4 on the shadows are the day's only change (§5.11).
- **No redraw** (C9, E11). Only the position, `modulate` and `self_modulate` change. `test_daylight_is_never_redrawn` counts the veil's draws over a day.
- **Where** (C13). In `main.tscn`, Main's child after Camera, `%Daylight`, not in World, whose children a test pins. It sets its global position, and its z is absolute, so its place in the tree doesn't change where it draws. On a `CanvasLayer` it couldn't draw between the world and the glows (§5.10). It isn't a `@tool` script, so the editor saves only the node.
- **Cost.** One square over the view while the light isn't white, as each veiled legend draws. P5 measures the frames on the Fold4 (§6.4).

PR 3's **Light** rule in `AGENTS.md` §3 sums this section up.

### 5.6 Legends at night

When a wrong or missed turn ends the run, the clock stops (§5.4). `_on_disaster_triggered()` gives `play_disaster()` the light shown as its `ambient`. The director keeps it while the car stops, gives it to the disaster in `_start_disaster()`, and `clear()` sets it back to white. `ambient` lives on `DisasterBase`, so a legend without a veil gets it too, and ignores it: it draws under Daylight's veil and darkens with the world.

A legend with a veil multiplies the world by its own colour V, which its first beat eases from white. At night Daylight multiplies by L too, and the two would show L × V, darker than either (C4). So the legend's veil darkens each channel only as far as the night hasn't: its share is 1 where L ≤ V, and V / L where L > V. The world then shows min(L, V) in each channel, and by day V, as on `main`. In `legend.gd`, the beats `shade()` the veil, `_veil_color()` becomes `_own_color()`, and a new `_veil_color()` gives the share.

| Veil | Legends | In the light | Share | The world shows |
|---|---|---|---|---|
| `VEIL_NIGHT` (0.275, 0.314, 0.588) | The UFO (Rural) | `LIGHT_NIGHT` | (0.654, 0.654, 0.817) | `VEIL_NIGHT`, as by day |
| | | `LIGHT_DUSK` | (0.275, 0.436, 1) | (0.275, 0.314, 0.52) |
| `VEIL_DUSK` (0.667, 0.510, 0.745) | The phantom bus, the fairy ring, the witch's hex | `LIGHT_DUSK` | (0.667, 0.708, 1) | (0.667, 0.510, 0.52) |
| | | `LIGHT_NIGHT` | White: the veil hides | `LIGHT_NIGHT` |

- `_made_veil()` and `_shown` go: `shade()` shows the veil as soon as its colour isn't white, and a white veil changes no pixel. Each scene's `veil_kind` still picks its colour.
- **The flash rules hold at night.** At night the ambient light holds still, since the clock stopped with the run. Each channel of the veil's tint eases from 1 to the share s, as by day from 1 to V, and s ≥ V because L ≤ 1: on every frame it changes the same way as by day, and by no more. The glows draw above both veils, as by day, and a darker ground only lessens their clipping. So what `test_disasters.gd` passes by day passes at night, and it needn't play each legend in each light.
- **Glows** are as bright as by day, and over the night's darker ground they light the dark as M6 meant (S10).

### 5.7 Readable at night

The road, its edges, the junctions and the car must read at night. The HUD and the menus are above the veil and don't change. M3's rule for the car's smoke: its luminance differs by at least `SMOKE_CONTRAST`, 0.1, from each colour that it shows over, and through a tunnel (`test_car_controller.gd`:10, :144, :155).
- The smoke is black at 0.8 alpha, so its contrast with a background b under the light L is Σ w L (b − p) over the channels, with b − p ≥ 0: linear in L.
- The eye adapts to the light, so a night half as bright needs half the contrast: contrast ≥ `SMOKE_CONTRAST` × lum(L) (Q12). Both sides are linear in L, so the rule holds in every light the game shows if it holds in the four key lights (§5.3), which PR 2's tests check.

Step 0 measured the margin, the least contrast over all the backgrounds divided by the contrast needed. The least is over #292933 in each light:

| Light | Over the world | Through a tunnel |
|---|---|---|
| White | ×1.303 | ×1.043 |
| Dawn | ×1.303 | ×1.043 |
| Dusk | ×1.296 | ×1.037 |
| Night | ×1.314 | ×1.052 |

- A margin in any light is an average of its margins in red, green and blue, weighted by w L. The least of those, over all the backgrounds and covers, is ×1.024. So **with today's art the smoke shows in a light of any colour**, and the owner can tune `LIGHT_*` freely (Q10). The tests guard new art and a new smoke: a bluish smoke fails at night (N20).
- **In a shadow** (C22). A shadow of alpha α over a background b shows (1 − α) b, and the smoke over it (1 − α) times its contrast, through a tunnel too, where the cover's colour cancels out. Against the rule in L the margin falls to ×0.912 in the sun's shadow and ×0.730 through a tunnel. But the casts are black, so a shadow is the dimmer light (1 − α) L, and in that light Q12's rule keeps the margins above: `test_the_smoke_shows_in_a_shadow` checks it at both alphas. The owner judges a crash in a shadow on the Fold4 (§6.4).

P4's frames at `--hour=22` show the road, its edges and the car clearly; on the Fold4 the owner judges both screens (E13).

### 5.8 When the night shows

With D seconds a day from 07:00, dusk begins 10/24 D into the zone, the night 13/24 D, dawn 21.5/24 D, and the day again at D: 50, 65, 107.5 and 120 s at 120 s, and 23.2, 30.2, 49.9 and 55.68 s in the least day. Step 0 timed each zone with the autopilot over 20 seeds. Players don't set the speed (`plan.md` §2.2), so a player who turns right takes about as long:

| Zone | Seconds | Turns | At D = 120 s, the zone ends at |
|---|---|---|---|
| City | 55.7–61.4, median ≈ 57.6 | 34 | 18:08–19:17: dusk, no night |
| Rural | 127.6–147.1 | 66 | 08:31–12:25, after a whole day and night |
| Meadows | 201.3–227.0 | 100 | 23:16–04:24, its second night |
| Village | 32.7–45.6 | 20 | 13:32–16:07: day only |
| Desert | Endless | — | — |

- A run's first night comes ≈ 65 s into Rural, ≈ 122 s into the run. A zone shows its night only if it lasts more than 13/24 of its day, so the City needs D ≤ 102.8 s, and the Village D ≤ 60.4 s.
- `smoke.sh`'s 60 simulated seconds reach dusk at 50 s, and the car enters Rural before they end, so CI's smoke run shows the veil, the shadows, the lamps and a reset. Its `autopilot:` line stays the same.

### 5.9 Any hour: `--hour=<h>`

`--hour=<h>` starts every zone's clock at hour h instead of 07:00, so that a test, an agent or the owner on a desktop sees the night without waiting 65 s. `_ready()` reads it with `main.gd`'s other user arguments and sets `cycle.start_hour` for every run.
- Any number counts, round the clock: `--hour=26` is 02:00, and `--hour=-1.5` is 22:30.
- One that isn't a number, or isn't finite, such as `1e999`, is reported, and the clock starts at 07:00 (N31).
- Android and the Web take no user arguments: on a device the night comes by playing (C12, §6.4).

### 5.10 Rejected approaches

| Approach | Why not |
|---|---|
| `CanvasModulate` | It tints every item on the canvas, the glows and the lamps too, and the balance of glows and veils (S10) would change. Godot allows one per canvas |
| World's `modulate` | It multiplies every item under World: a legend's veil would darken twice, and the glows would dim |
| `Light2D`s for the night, the shadows or the lamps | They need a `CanvasModulate` to make the dark they light, and each light draws what it lights again: a cost on the Fold4 and the Web. `LightOccluder2D` shadows need a polygon per frame of every prop |
| A shader on every material | Every sprite, polygon and particle would need it, and new art that forgot it would stay lit in the dark |
| A `ColorRect` on a `CanvasLayer` | A layer draws over or under the whole world canvas, not between the world and the glows |
| Night art | A second set of art doubles the assets and the Web's download, and blending them gradually needs a shader anyway |

**Fallback.** If P5 fails on the Fold4, Daylight could set the `modulate` of World's children instead of drawing a veil. That adds no draw, but breaks E8 and C2: the phantom bus's ADD lamps, children of the bus under Props, would dim, a legend's other parts would stay lit, and each new child of World would have to join the list. So it needs the owner's agreement first. The shadows and the lamps can each be turned off by hiding their node.

### 5.11 Shadows

Q4's answer: the props and the car cast shadows that turn with the sun and the moon (PR 4, E15, E16).

**The sky.** The sun is up from `SUN_RISE_HOUR`, 06:00, to `SUN_SET_HOUR`, 18:00, and the moon the rest of the day. Each rises on the screen's left, `SKY_RISE_ANGLE` (135° in tile space) being the way toward it, crosses the top of the screen at its highest, `SUN_HIGHEST` 60° and `MOON_HIGHEST` 45° above the ground, and sets on the right: its height is the highest × sin(π × the share of its time up). So a shadow falls to the right in the morning, toward the viewer at noon and to the left in the evening: always in front of what casts it, where it shows, never behind it.
- `DayCycle.shadow_at(hour)` is where a pixel of height casts its shadow, in screen pixels from its foot. On the ground a shadow is 1 / tan(height) times as long as what casts it is tall, at most `SHADOW_LONGEST`, 2.5, away from the light. On the screen a tile of height stands `Iso.HEIGHT_PX` high, and `Iso.tile_to_world()` lays a tile of ground, so at noon a shadow falls straight down the screen, 0.33 pixels a pixel of height, at midnight 0.58, and sideways at most 2.89, `Shadows.FALL_MOST`.
- `shadow_alpha_at(hour)` is `SUN_SHADOW_ALPHA`, 0.3, by day and `MOON_SHADOW_ALPHA`, 0.15, by night, × `smoothstep()` of the height from `SHADOW_FADE_FROM`, 3°, to `SHADOW_FADE_TO`, 20°. At 120 s a day the sun's shadows fade in from 06:11 to 07:18 and out from 16:42 to 17:49, and the moon's in from 18:15 to 19:46 and out from 04:14 to 05:45: the sun's are gone before the moon's come, at both ends of the night.
- **Gradual.** `advance()` moves the shadow shown to the hour's while that moves no faster than `SHADOW_MAX_RATE`, 1.5 screen pixels a second per pixel of height, or while the alpha is 0: all day, and at the handovers, where both lights are on the ground. A shadow that would have to move faster, after a reset, turns toward the hour's while its alpha falls at `SHADOW_ALPHA_RATE`, 0.25 a second, jumps unseen at 0, and fades in again. In the least day the shadows shown follow the hour exactly (E16). `snap()` sets both at once.
- **Nothing flashes.** The alpha changes by at most 0.25 a second, and turns only at fades, so a shadow darkens or lightens the ground by a tenth of white in no less than 0.4 s, as the light does. Shadows turn by half a turn in 12 hours of the clock.

**What casts** (C16). `PropDef.shadow` is `UPRIGHT`, `WALL` or `NONE`, and `shadow_rise` the pixels above the foot that the shadow falls from. `make_props.gd` sets them: the fence is a wall whose base line is `WALL_RISE`, 2 px, above its foot; the flowers, the pond and the bones lie flat; a box falls from its footprint's centre, which `_box()` records; and the rest are upright from the foot.
- An upright prop's rows above that point lie on the ground: a texel h px above it lies at h × the clock's shadow, and its width across the shadow, so the shadow is as wide whichever way the light comes from. The frame's left stays on the left: the shadow is the frame turned down, never round (N44).
- A wall's pixels each fall from the wall's base below them, so its shadow starts along its base line.
- The car casts its body's frame, `body_frame()` of `body_texture()`, as an upright prop does, scaled and turned as the car is, and as clear as the car: a legend that fades the car fades its shadow (M6_PLAN.md §5.4). A hidden car casts none.

**How it draws.** `Shadows` (`world/shadows.gd`) is a `CanvasGroup` in `world.tscn` after Skids, before DisasterLayer and Props. So shadows lie on the ground, the road and the skid marks, under the legends, the props and the car, and Daylight's veil darkens them with the world.
- Each cast is a sprite of the prop's sheet, black, opaque, in the prop's frame. The group draws them into one buffer and the buffer once at its `self_modulate.a`, the clock's shadow alpha, so one shadow or two darken alike: 0.302 for 0.3 (P8; C18). No group is nested in another (P8b). The group hides at alpha 0.
- **Laid on the GPU** (C20). `shadows.gdshader` lays a frame's x along `lay_x` and its y along `lay_y` in the vertex shader. Shadows has one material for upright props and one for walls, and as the clock turns sets their two parameters: no sprite moves. Godot culls a sprite and sizes the group by its frame as it stands, so each cast gets a custom rect, `reach(def)`, as far as its shadow reaches at any hour (`renderer_canvas_cull.cpp`:192–262, :333). P11 checked the shader against the same lay on the CPU: within 1 px. The car's cast is laid on the CPU, as its frame, scale and turn change every frame.
- The sprites are Shadows' internal children (`PropPool`), so GUT's `simulate()` doesn't walk them (C20). PropScatter adds a prop's cast as the prop shows, sets its frame with the prop's, and removes it as the prop hides. World refreshes the group in `_process()`.
- On the Web only the sprites' transforms, frames and `self_modulate`, and two materials' parameters, change: no polygon is redrawn (C9). P9 ran a whole day and night with no WebGL error.
- The legends and the set pieces cast none, and the tunnel's rock and the bridge's near railing, at z 1, draw over shadows that reach them (§9).

### 5.12 Lamps

Q5's answer: the street lamps and the lit windows glow at night (PR 5, E17).

**Where** (C17). `PropDef.lights` are boxes, from the foot, that glow, and `light_pools` boxes of ground that a lamp lights. `make_props.gd` finds them as it paints: a window painted the palette's yellow is a light, grown by `WINDOW_HALO`, 2 px; a lamp's head, `LAMP_HEAD`, is one grown by `LAMP_HALO`, 4 px, with a pool `LAMP_POOL`, 64 × 32 px, on the ground under it. Four props get lines: the City's building and lamp, Rural's barn and the Village's cottage.

**How bright.** `Lamps.strength(L)` is the largest share up to 1 at which the glows add to no channel more than the light L takes away from white: min over the channels of (1 − L) / (`LAMP_ALPHA` × `LAMP_COLOR`), with `LAMP_COLOR` (1, 0.8, 0.45) and `LAMP_ALPHA` 0.55. A pixel under the veil shows at most L, so with a glow it reaches at most white, never past it (S10). Over a legend's veil it shows less, so the same holds.
- In white the strength is 0. Dusk's red is 1, so the lamps come on at 18:30, as the red falls, and are full from 19:48 to 04:43. They fade at dawn and are out at 07:00. After a reset at night they fade out with the light, in 2.33 s.
- A pool glows `LAMP_POOL_SHARE`, 0.4, as brightly as a light.
- The glows' alpha follows the light, so it changes by at most 0.25 / 0.45 a second, rises once at dusk and falls once at dawn: nothing flashes (`test_the_lamps_fade_on_once_a_day_and_out_once`).

**How it draws** (C18, C19). `Lamps` (`world/lamps.gd`) is a `CanvasGroup`, World's last child, at `GLOW_Z`, absolute: over the veil, as the legends' glows are. Its material is Godot 4.7.2's canvas group shader (`rasterizer_canvas_gles3.cpp`), with `blend_add`, so the group adds what it holds, once: where two glows overlap they light no more than one (P10). Its `self_modulate` is `LAMP_COLOR` at `LAMP_ALPHA` × the strength, and it hides at 0. Not its `modulate`, which what it holds would take too, lighting the glows twice (N81).
- The group holds a black silhouette of each prop that stands, with the prop's glows over it. Black adds nothing, so a prop's silhouette hides the glows of the props behind it, as the prop hides them. A flat prop with lights would get a clear silhouette.
- The silhouettes draw in the order that Props draws the props: by y, then by Props' order (`renderer_canvas_cull.h`:117). Props y-sorts, but a group that y-sorts draws its items straight to the screen, and holds only those at its own z (P10b: `renderer_canvas_cull.cpp`:197–257, :438–492), so Lamps inserts each silhouette in its place itself.
- The glows are `disasters/glow.tres`, the legends' glow texture, scaled to their boxes. The silhouettes, with their glows, are pooled per `PropDef` as Lamps' internal children (C20). PropScatter adds a prop's silhouette as the prop shows, sets its frame with the prop's, and removes it as the prop hides. World refreshes the group in `_process()`.
- On the Web only the group's `self_modulate` and `visible` change, and each silhouette's position, frame and order as it is added: no redraw (C9, P9).
- **Set pieces.** The parts that draw over the props, the tunnel's rock, 40 px tall, and the bridge's near railing, 8 px, reach at most 0.55 tiles from a set piece's road, and props stand at least 2.6 tiles from it (`PropLayout.near_set_piece()`). So on screen no prop's frame or pool reaches them, and no glow lies on them.
- The car and the legends hide no glows: a car in front of a lit window doesn't cover its glow (§9).

PRs 4 and 5's **Shadows** and **Lamps** rules in `AGENTS.md` §3 sum §5.11 and this section up.

---

## 6. Verification

### 6.1 Local checks

The five checks of `AGENTS.md` §4 passed with Godot 4.7.2 and gdtoolkit 4.5.0 on `main` and on each PR's head, and after them `git status --porcelain` printed nothing. `smoke.sh` printed `autopilot: tile 165, turns 35, area rural` on each: the light reaches neither the road, nor the car, nor the director (§5.1).

| Head | Scripts loaded | Test scripts | Tests | Asserts | GUT | CI `test` |
|---|---|---|---|---|---|---|
| `main` (a5244fe) | 148 | 70 | 524 | 423,545 | 1 min 47 s | 2 min 13 s |
| PR 1 | 150 | 71 | 536 | 423,629 | 1 min 49 s | 2 min 34 s |
| PR 2 | 152 | 72 | 538 | 424,120 | 1 min 46 s | 2 min 33 s |
| PR 3 | 155 | 74 | 552 | 424,852 | 1 min 59 s | 2 min 56 s |
| PR 4 | 158 | 76 | 572 | 426,750 | 2 min 1 s | 2 min 46 s |
| PR 5 | 160 | 77 | 583 | 426,861 | 2 min 22 s | 2 min 53 s |

GUT's time is its own report, the median of three runs of each head alone on 2 CPUs. Each head's first run, right after the other checks, was its slowest, by up to 63 s; the next two agreed within 11 s. CI's is the `test` job on each PR's head before this sync, and `main`'s on #64's. By hand, with `upload-builds`, every job passed on the prototype (run 43492158711 on 5e20b2d), on PR 3 (run 43505306109 on 03ea55f) and on PR 5 (run 43505310680 on 3f2b0b2), whose builds §6.4 checked.

### 6.2 Negative cases

Each case is a temporary change at its PR's head. A script, not committed, applies it, runs GUT and restores the tree. While the code changed it ran each case on the scripts of its tests; on the prototype, and on each PR's head after its reviews, on the whole suite, where a case must fail the tests of its row and no other, and leak nothing (`AGENTS.md` §2.4). Its runs found five gaps in the tests, now closed (§4.1). On each PR's final head every case did so but N11 and N12; where a change fails several tests, its row lists them all. N11 and N12 break the schedule, which fails most of the suite by design: the road falls back to one area, where TUT's `test_the_tutorial_ends_with_its_group_and_the_seed_road_follows` waits for a set piece until memory runs out. So they run on their test's script, `test_area_schedule.gd`, where they fail their row's test and others that need a valid schedule. The tests drop their `test_`; "The same" repeats the row above's, and "As N#" that row's.

| N# | PR | Temporary change | Tests that fail |
|---|---|---|---|
| N1 | 1 | `hour()` without its `fposmod()` | `the_hour_runs_round_the_clock_in_day_seconds` |
| N2 | 1 | `light_at()` starts at the first key, so the night doesn't run past midnight | `each_key_hour_has_its_light`, `after_a_reset_the_light_catches_up_and_then_follows_exactly`, `least_day_seconds_is_the_shortest_day_the_rate_can_follow` |
| N3 | 1 | `light_at()` blends by `t`, not `smoothstep()` | `between_keys_the_light_eases_in_and_out`, `least_day_seconds_is_the_shortest_day_the_rate_can_follow` |
| N4 | 1 | `advance()` sets `light = goal` | `the_light_shown_never_changes_faster_than_the_max_rate`, `after_a_reset_the_light_catches_up_and_then_follows_exactly` |
| N5 | 1 | `enter()` calls `snap()` | The same |
| N6 | 1 | `enter()` keeps `seconds` | `entering_a_zone_starts_its_clock_at_the_start_hour` |
| N7 | 1 | `STEEPEST := 1.0` | `least_day_seconds_is_the_shortest_day_the_rate_can_follow` |
| N8 | 1 | `enter()` without its check of the day | `a_day_of_no_seconds_is_an_error_and_stops_the_clock` |
| N9 | 1 | `advance()` moves each channel on its own, with `move_toward()` | `after_a_reset_the_light_catches_up_and_then_follows_exactly` |
| N10 | 1 | `validate()` without its check of a short day | `validate_reports_a_day_too_short_to_follow` |
| N11 | 1 | `city.tres` with `day_seconds = 50.0` | `the_game_schedule_is_valid` |
| N12 | 1 | `LIGHT_MAX_RATE := 0.1`: the least day becomes 139.2 s | The same |
| N13 | 2 | `ViewVeil` in `BLEND_MODE_MIX` | `the_veil_multiplies_at_veil_z_and_starts_hidden` |
| N14 | 2 | `ViewVeil` with `z_as_relative = true` | The same |
| N15 | 2 | `ViewVeil._init()` leaves `modulate.a` at 1 | `the_veil_multiplies_at_veil_z_and_starts_hidden`, `each_shows_nothing_until_its_delay_is_over`, `at_night_a_veil_darkens_only_what_the_night_hasnt` |
| N16 | 2 | `Legend._veil_color()` returns the legend's own colour | `at_night_a_veil_darkens_only_what_the_night_hasnt` |
| N17 | 2 | `_share()` always gives V / L, above 1 where the light is darker | The same |
| N18 | 2 | `shade()` never hides | The same |
| N19 | 2 | `ViewVeil.shade()` sets `color`, not `self_modulate` | `none_redraws_a_polygon` |
| N20 | 2 | A bluish smoke, `Color(0, 0, 0.4, 0.8)` in `car/car.tscn` | `the_smoke_shows_over_everything_the_world_draws`, `the_smoke_shows_through_a_tunnel` |
| N21 | 2 | `play_disaster()` doesn't keep its `ambient` | `a_disaster_waits_for_the_car_to_stop` |
| N22 | 2 | `_start_disaster()` doesn't pass it on | The same |
| N23 | 3 | Daylight's `_ready()` doesn't set its priority | `in_the_games_frames_the_veil_follows_the_view_of_the_same_frame` |
| N24 | 3 | Daylight's `_physics_process()` does nothing | `in_the_games_frames_the_veil_follows_the_view_of_the_same_frame`, `the_light_follows_the_clock_while_the_car_drives`, `each_new_zone_starts_its_clock_again` |
| N25 | 3 | `main.gd` advances the clock in every state | `the_clock_stops_when_the_run_ends_and_while_paused`, `the_title_keeps_the_night_and_play_starts_the_morning` |
| N26 | 3 | `_on_area_changed()` without `enter()` | `each_new_zone_starts_its_clock_again`, `the_title_keeps_the_night_and_play_starts_the_morning`, `each_run_starts_at_once_in_the_morning`, `each_zone_runs_its_clock_at_its_own_pace`, `the_city_day_starts_at_the_switch` |
| N27 | 3 | `_start_run()` without `snap()` | `each_run_starts_at_once_in_the_morning`, `the_title_keeps_the_night_and_play_starts_the_morning`, `the_hour_argument_starts_every_zone_at_that_hour` |
| N28 | 3 | `_start_run()` without `refresh()` | `each_run_starts_at_once_in_the_morning`, `the_title_keeps_the_night_and_play_starts_the_morning` |
| N29 | 3 | `play_disaster()` without the light | `at_night_the_disaster_plays_in_the_light_the_run_ended_in` |
| N30 | 3 | `_ready()` doesn't set `start_hour` | `the_hour_argument_starts_every_zone_at_that_hour`, `at_night_the_disaster_plays_in_the_light_the_run_ended_in`, `the_light_follows_the_clock_while_the_car_drives`, `each_zone_runs_its_clock_at_its_own_pace`, `the_city_day_starts_at_the_switch` |
| N31 | 3 | `_parse_hour()` without `is_finite()` | `the_hour_argument_starts_every_zone_at_that_hour` |
| N32 | 3 | Daylight at `VEIL_Z + 1` | `the_veil_darkens_the_world_but_not_the_glows_or_the_ui` |
| N33 | 3 | `main.gd` lowers bus 0 by 6 dB while the light isn't white | `the_light_changes_nothing_but_the_view` |
| N34 | 3 | `ViewVeil.shade()` sets `color`, in Daylight too | `daylight_is_never_redrawn`, `none_redraws_a_polygon` |
| N35 | 3 | `ViewVeil.shade()` never hides, in Daylight too | `by_day_the_veil_is_transparent_and_by_night_it_shows_the_light`, `each_run_starts_at_once_in_the_morning`, `the_title_keeps_the_night_and_play_starts_the_morning`, `daylight_is_never_redrawn`, `the_hour_argument_starts_every_zone_at_that_hour`, `at_night_a_veil_darkens_only_what_the_night_hasnt` |
| N36 | 1 | `enter()` checks only `p_day_seconds <= 0.0`, so NaN and INF pass | As N8 |
| N37 | 1 | `validate()` names the least day to the hundredth, not rounded up: 55.68 | As N10 |
| N38 | 1 | `validate()` without its check of a day that isn't finite | `validate_reports_a_day_that_isnt_finite` |
| N39 | 3 | `_on_area_changed()` enters a day of 120 s, not the zone's | `each_zone_runs_its_clock_at_its_own_pace` |
| N40 | 3 | `main.gd` mutes the Ambient bus while the light isn't white | As N33 |
| N41 | 3 | `main.gd` plays the junction's sound as the clock passes 20:00 | The same |
| N42 | 3 | `main.gd` sets the engine loop's `volume_db` to −80 while the light isn't white | The same |
| N43 | 3 | `main.gd` puts the ambient decks on the Music bus while the light isn't white | The same |
| N44 | 4 | A shadow's across axis turned round: the frame mirrored | `an_upright_props_shadow_falls_from_its_foot_across_the_light` |
| N45 | 4 | `SHADOW_MAX_RATE := 0.9` | `the_shadows_shown_follow_the_hour_exactly_in_the_least_day_too` |
| N46 | 4 | `snap()` leaves the shadows | `the_shadows_shown_follow_the_hour_exactly_in_the_least_day_too`, `an_upright_props_shadow_falls_from_its_foot_across_the_light`, `the_cars_shadow_follows_its_frame_and_fades_with_it`, `the_shadows_follow_the_clock_and_the_props`, `the_shadows_show_at_the_clocks_alpha_as_one`, `the_shadows_turn_with_the_clock` |
| N47 | 4 | `advance()` turns an unseen shadow at the rate, not at once | `after_a_reset_the_shadows_fade_out_jump_unseen_and_fade_in`, `the_shadows_shown_follow_the_hour_exactly_in_the_least_day_too` |
| N48 | 4 | The shadows' alpha jumps: `shadow_alpha = dark` | `after_a_reset_the_shadows_fade_out_jump_unseen_and_fade_in` |
| N49 | 4 | `SKY_RISE_ANGLE` 0° | `shadows_sweep_from_the_right_to_the_left_in_front_of_what_casts_them`, `after_a_reset_the_shadows_fade_out_jump_unseen_and_fade_in`, `an_upright_props_shadow_falls_from_its_foot_across_the_light`, `the_shadows_turn_with_the_clock` |
| N50 | 4 | The fence's `shadow_rise = 4` | `each_shadow_falls_from_where_its_prop_meets_the_ground` |
| N51 | 4 | Shadows after Props in `world.tscn` | `disasters_draw_above_the_road_and_below_the_car` |
| N52 | 4 | PropScatter keeps a hidden prop's cast | `each_prop_casts_its_shadow_while_it_shows_in_its_frame` |
| N53 | 4 | The car's shadow doesn't fade with the car | `the_cars_shadow_follows_its_frame_and_fades_with_it` |
| N54 | 4 | Walls laid as upright props | `a_walls_shadow_falls_from_its_base_line` |
| N55 | 4 | Shadows laid only once | `the_shadows_turn_with_the_clock`, `a_walls_shadow_falls_from_its_base_line`, `an_upright_props_shadow_falls_from_its_foot_across_the_light`, `the_clock_turns_the_props_shadows_but_no_sprite` |
| N56 | 4 | World's `_process()` doesn't refresh the shadows | `the_shadows_follow_the_clock_and_the_props`, `the_props_and_the_car_cast_shadows_by_the_zones_clock` |
| N57 | 4 | Flat props cast | `flat_props_cast_none`, `each_props_shadow_is_drawn_wherever_it_falls`, `each_prop_casts_its_shadow_while_it_shows_in_its_frame` |
| N58 | 4 | `body_frame()` returns 0 | As N53 |
| N59 | 4 | `main.gd` doesn't give World the clock | `the_props_and_the_car_cast_shadows_by_the_zones_clock` |
| N60 | 5 | PropScatter keeps a hidden prop's lamps | `each_prop_lights_its_lamps_while_it_shows` |
| N61 | 5 | `strength()` isn't capped at 1 | `out_by_day_and_without_a_clock_and_on_at_night`, `the_lamps_glow_over_the_veil_at_night` |
| N62 | 5 | `strength()` reads only the blue channel | `a_glow_never_adds_more_than_the_veil_takes_away`, `out_by_day_and_without_a_clock_and_on_at_night` |
| N63 | 5 | Lamps at `VEIL_Z` | `the_lamps_draw_as_one_group_that_adds_over_the_veil`, `the_lamps_glow_over_the_veil_at_night` |
| N64 | 5 | Lamps' z relative | The same |
| N65 | 5 | Pools as bright as lights | `each_light_and_pool_glows_where_its_prop_puts_it` |
| N66 | 5 | A released silhouette loses its glows | `silhouettes_are_used_again_with_their_glows`, `each_prop_lights_its_lamps_while_it_shows` |
| N67 | 5 | A reused silhouette gets its glows again | The same |
| N68 | 5 | Every box painted is a light, not only the yellow ones | `each_prop_lights_its_yellow_windows_and_lamps` |
| N69 | 5 | Without a clock the lamps glow as at night | As N61 |
| N70 | 5 | The lamps follow the hour's light, not the light shown | `the_lamps_fade_on_once_a_day_and_out_once` |
| N71 | 5 | World's `_process()` doesn't refresh the lamps | `the_lamps_glow_over_the_veil_at_night`, `the_lamps_light_by_the_zones_clock` |
| N72 | 5 | `bind()` doesn't give PropScatter the lamps | The same |
| N73 | 5 | `LAMP_ALPHA := 0.9` | As N61 |
| N74 | 5 | A lamp's pool under its foot, not its head | As N68 |
| N75 | 5 | Lamps a `Node2D`, not a group | `the_lamps_draw_as_one_group_that_adds_over_the_veil` |
| N76 | 5 | The group's shader mixes, not adds | `the_lamps_draw_as_one_group_that_adds_over_the_veil`, `the_veil_darkens_the_world_but_not_the_glows_or_the_ui` |
| N77 | 5 | Lamps y-sorts | `the_lamps_draw_as_one_group_that_adds_over_the_veil`, `the_lamps_glow_over_the_veil_at_night`, `the_veil_darkens_the_world_but_not_the_glows_or_the_ui` |
| N78 | 5 | A new silhouette draws last, not in its place | `the_silhouettes_draw_in_the_order_props_draws_the_props` |
| N79 | 5 | On a row, silhouettes ignore Props' order | The same |
| N80 | 5 | Every silhouette clear | As N65 |
| N81 | 5 | The lamps lit by the group's `modulate` | `the_lamps_draw_as_one_group_that_adds_over_the_veil`, `a_glow_never_adds_more_than_the_veil_takes_away`, `out_by_day_and_without_a_clock_and_on_at_night`, `the_lamps_fade_on_once_a_day_and_out_once`, `the_lamps_glow_over_the_veil_at_night`, `the_lamps_light_by_the_zones_clock` |
| N82 | 5 | Each glow with a material of its own | As N75 |
| N83 | 5 | A shown prop's silhouette keeps its first frame | As N60 |
| N84 | 5 | A released silhouette isn't moved last | As N78 |
| N85 | 5 | `remove()` releases a silhouette that isn't shown | `silhouettes_are_used_again_with_their_glows`, `each_prop_lights_its_lamps_while_it_shows`, `each_area_shows_its_ground_and_blends_it_into_the_last_ones`, `the_autopilot_drives_through_the_tunnel_and_over_the_bridge`, `the_title_starts_the_runs_in_the_chosen_area_as_the_area_argument_does` |
| N86 | 4 | Shadows y-sorts, in `world.tscn` | `the_shadows_follow_the_clock_and_the_props` |
| N87 | 5 | Lamps y-sorts, in `world.tscn` | `the_lamps_glow_over_the_veil_at_night`, `the_veil_darkens_the_world_but_not_the_glows_or_the_ui` |
| N88 | 5 | A glow at z 1 | As N76 |
| N89 | 4 | A prop's cast without its custom rect | `each_props_shadow_is_drawn_wherever_it_falls` |
| N90 | 4 | The car's cast keeps a prop's custom rect | As N53 |
| N91 | 4 | The car's cast keeps a prop's shader | The same |
| N92 | 4 | Each prop's cast laid on the CPU, by its transform | `the_clock_turns_the_props_shadows_but_no_sprite`, `each_props_shadow_is_drawn_wherever_it_falls`, `the_shader_lays_each_corner_where_laid_puts_it` |
| N93 | 4 | `FALL_MOST` in heights, not pixels across | As N89 |
| N94 | 4 | `WALL_ACROSS_MOST := 1.0` | The same |
| N95 | 4 | Shadows' pool without internal children | `removed_shadows_give_their_sprites_back` |
| N96 | 5 | Lamps' pools without internal children | `silhouettes_are_used_again_with_their_glows` |
| N97 | 4 | A cast at `VEIL_Z` | As N32 |
| N98 | 3 | `_on_tutorial_completed()` doesn't enter the City's clock | `the_city_day_starts_at_the_switch` |
| N99 | 3 | The clock stands still in the tutorial | The same |
| N100 | 3 | The switch snaps the light | The same |
| N101 | 4 | The shader leaves each corner where it is | `the_shader_lays_each_corner_where_laid_puts_it` |
| N102 | 4 | The shader swaps the lay's axes | The same |
| N103 | 4 | The smoke is grey 0.005, not black | `the_smoke_shows_in_a_shadow` |
| N104 | 3 | The clock runs behind the title | `the_title_keeps_the_night_and_play_starts_the_morning` |
| N105 | 3 | Title resets the clock to the morning | The same |
`clear()`'s reset of the director's `_ambient` has no case: only `play_disaster()` reaches `_start_disaster()`, and it sets the light first. It only tidies.

### 6.3 Editor warnings

Only the editor warns about shadowing (M2_PLAN.md §6.3). A script asked the editor's language server (`godot --headless --editor --lsp-port`) for the warnings of every script outside `addons/`, on `main` and on each PR's head. Each has only `main`'s 5, none in DN's lines: four integer divisions, one in `ui/main.gd`, and an unused variable. A local `var seconds` in `DayCycle.snap()` made it report `SHADOWED_VARIABLE`, so it sees shadowing.

### 6.4 CI, the Web and the Fold4

- **CI.** The five required checks on each PR into `main`, the `test` job's check of the tree included (`AGENTS.md` §10).
- **The Web** (E11, E13; P3, P9). The agent checked PR 3's and PR 5's builds in Chrome and Firefox with Playwright, headed under Xvfb, and posted a table in each PR, one row per check (`AGENTS.md` §6): every check passed, on [PR 3](https://github.com/pompomon/roadgame/pull/72#issuecomment-6865819008) and [PR 5](https://github.com/pompomon/roadgame/pull/74#issuecomment-6865943044). The page passes no arguments (C12), so it serves a copy that takes them from the address:
  ```bash
  gh workflow run ci.yml -R pompomon/roadgame --ref dn/5-lamps -f upload-builds=true
  gh run download <run id> -R pompomon/roadgame -n web -D /tmp/dn-web
  sed -i 's/"args":\[\]/"args":["--"].concat(new URLSearchParams(location.search).getAll("arg"))/' \
    /tmp/dn-web/index.html
  python3 -m http.server -d /tmp/dn-web 8000
  ```
  Each run takes screenshots, and neither console may log a WebGL error:
  1. `?arg=--autopilot&arg=--seed=12345`, `smoke.sh`'s run, for 190 s: dusk 50 s in; Rural about a minute in, back to the day within 2.4 s, with no jump; its night 65 s later, its dawn and its day.
  2. `--autopilot --seed=1` with `--area=city --hour=22`, `--area=city --hour=17`, `--area=meadows --hour=4`, `--area=rural --hour=9` and `--area=village --hour=21`: the night at once, dusk falling, dawn, the sun's shadows, and lit windows (PR 5).
  3. `?arg=--tutorial&arg=--hour=16&arg=--autopilot`: the tutorial's dusk and night, then the City's day back at the switch, within 2.4 s (C21).
  4. `?arg=--play&arg=--hour=21&arg=--seed=1`, as Play on a new save starts the tutorial, which has no disasters (TUT): a missed junction plays the phantom bus at night, its glows lit and its veil hidden (§5.6); game over keeps the night, and Retry starts again at 21:00 at once (E5).
- **The Fold4** (E13; P5). The owner installs the debug APK of PR 5, which holds the whole stack:
  ```bash
  gh workflow run ci.yml -R pompomon/roadgame --ref dn/5-lamps -f upload-builds=true
  gh run download <run-id> -R pompomon/roadgame -n "android-Android APK" -D /tmp/roadgame-apk
  adb install -r /tmp/roadgame-apk/roadgame-debug.apk
  ```
  Then, on the cover screen and unfolded: dusk about 50 s into the run, and in Rural the day back in about 2 s; the night about 2 minutes in, sooner from the title's "Start in: Rural" (debug builds, ZS), 65 s after Play. At night the road, its edges, the junctions and the car read (Q10), and so does a crash's smoke in a shadow (C22); the shadows turn smoothly; the lamps glow warm, never white; a legend looks right, and a game over keeps the night on the title (Q6); and the night plays as smoothly as the day (P5). If not, an APK with `debug/settings/stdout/print_fps` prints the frame rate to `adb logcat`. For the night at once, serve the Web copy above, run `adb reverse tcp:8000 tcp:8000`, and open http://localhost:8000/?arg=--hour=20 in the Fold4's Chrome.

### 6.5 Probes and measurements

| P# | What | How | Result |
|---|---|---|---|
| P1 | Only the glows and the UI draw above Daylight | The main scene at `--seed=1`, once the phantom bus showed: each canvas item's absolute z | Under World 601 items at z 0, 2 at 1, the veil at 2 and 2 glows at 3. Now a test, with the shadows and the lamps |
| P2 | Two MUL veils commute | Movie Maker under Xvfb, `--play --seed=1 --hour=17`, with Daylight drawn after World and before it | 714 frames differ, by at most 1/255 in a channel: the 8 bits' rounding |
| P3 | No WebGL error in PR 3's light | §6.4's runs 1 and 4, then at `--area=rural --hour=21` the UFO, on 257af7a's build (CI run 43370478843), in Chrome 157 and Firefox 159 | No error or WebGL message. The screenshots' colours followed the clock, alike in both browsers |
| P4 | A hidden veil changes no pixel | Movie Maker, 600 frames of `--autopilot --seed=1` on `main` and on PR 3 | The same, byte for byte |
| P5 | The night's cost on the Fold4 | §6.4 | The owner, on PR 5 |
| P6 | Daylight covers the view of its own frame | The engine's frames, not `simulate()` (§5.4) | Now a test; without the priority the veil is a frame late (N23) |
| P8 | Overlapping shadows darken once | Two black casts in a group at 0.5, over a grey of 0.6 | 0.302 under one and under both, for 0.3 |
| P8b | A group in a group | The same, nested | 0.541 where the inner casts overlap: wrong (§5.10) |
| P9 | No WebGL error with shadows and lamps | §6.4's runs 1 and 2 on 6ae2217's build (CI run 43461788754); all four on 5e20b2d's build (CI run 43492158711), beside two GUT runs; and on PR 5's (§6.4) | No error or WebGL message. Under Xvfb, 52–58 frames a second on 6ae2217's build, 16–46 on 5e20b2d's beside the GUT runs; PR 5's, alone, 53–60 by day and 57–59 by night in Chrome, 48–59 and 58–59 in Firefox. Firefox warned only of a deprecated WebAssembly instruction in Godot's build |
| P10 | Overlapping glows light once | Two glows 2 px apart over the night's veil, alone and in one ADD group | In the group the overlap shows (0.859, 0.792, 0.804), as one glow does; alone they add twice. Godot's grouping: P10b, `renderer_canvas_cull.cpp`:197–257, :438–492 |
| P11 | The shader lays the shadows as the CPU did | Every prop, laid by both, at each half hour | The same within 1 px, which only one of the 48 half hours shows |

Step 0 also measured the autopilot's seconds in each zone over 20 seeds (§5.8), the smoke's margins in each light and shadow (§5.7), and the frames' cost headless on each PR (C20).

---

## 7. Owner actions

For @pompomon:
1. **The Q#s** (§3). Q4 and Q5 are answered: the shadows in PR 4, the lamps in PR 5. The rest keep their defaults. Q3 still decides whether the City and the Village show their night: at 120 s a run's first night comes in Rural, about 2 minutes in (§5.8).
2. **Merge** stack #77 once its checks pass: on #74, merge the stack, squashed. #76 and #71–#74 land in order, each as one commit (§4.5 step 6). Don't merge one of them alone, and don't press **Rebase stack**: if GitHub asks for a rebase, or can't merge the stack, ask the agent. `dn/plan` can go now: no PR targets it. Don't delete `dn/1-cycle` from #70's page: it is #76's branch, and #71's base. The five branches can go once the stack is merged.
3. **Check the Fold4** with PR 5's debug APK (§6.4), and post the results in PR 5.
4. **Tune**, if Q10 asks for it: the `LIGHT_*` colours, `SUN_SHADOW_ALPHA`, `MOON_SHADOW_ALPHA` and `LAMP_*` in `config/tuning.gd`, or a zone's `day_seconds` in its `.tres`. The tests follow, and the smoke shows in a light of any colour with today's art (§5.7).
5. **Resolve** the review threads.

---

## 8. Risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Zones too short to show the night | Certain for the City and the Village at 120 s | A run's first night comes about 2 minutes in, in Rural | Q3: the City at 80 s and the Village at 56 s, a line each (§5.8) |
| The night too dark or too blue on the Fold4, or outdoors | Medium | The junctions read badly | The owner tunes `LIGHT_*` (Q10). The tests guard the smoke in any light (§5.7) |
| The reset to the morning looks sudden | Medium | It breaks the mood | Up to 2.33 s, at about twice dusk's steepest rate; the shadows fade out and in. Q2's slower fade |
| A legend looks wrong at night | Medium | Its colour is lost | The world shows the darker of the two lights (§5.6, Q7); §6.4's checks |
| The night costs frame time on the Fold4 | Low | Dropped frames | One veil, one group of shadows and one of lamps; 0.30 / 2.41 ms a frame headless (C20). P5. Shadows and Lamps can each be hidden; §5.10's fallback needs the owner's agreement |
| Something new draws above `VEIL_Z`, or a new prop's lights or shadows are wrong | Low | It stays lit in the dark, or glows or casts amiss | `test_the_veil_darkens_the_world_but_not_the_glows_or_the_ui`; `make_props.gd` finds lights and shadows as it paints, and `test_prop_art.gd` checks them; `AGENTS.md` §3's rules |
| WebGL errors on the Web | Low | Console errors (godotengine/godot#124726) | No polygon is redrawn: `test_daylight_is_never_redrawn`, `test_none_redraws_a_polygon`. P3 and P9 |
| M7 changes `ui/main.gd`, `config/tuning.gd`, `plan.md` or `AGENTS.md` at the same time | Medium | Merge conflicts | DN's lines are in blocks of their own; `git merge-tree` shows conflicts first (§4.5) |

---

## 9. Notes for later work

- **Orientation and foldables (M7).** The veil is a square of ±`Tuning.VEIL_HALF_SIZE` round the view. `test_the_veil_covers_every_view` checks it on every screen of `SCREENS` in `tests/integration/test_props_in_view.gd`, at every zoom; M7's new views go in that list. A cast's rect, `reach()`, is in the prop's own pixels and needs no change.
- **Haptics and the Web's audio (M7).** The light drives neither. What M7 adds to the sound, and its haptics, can join `test_the_light_changes_nothing_but_the_view`'s `_sound()`.
- **The tunnel's darkening (C15).** Daylight can multiply its light by a grey that eases in as the car enters a tunnel, `Tunnel.opacity()`, no faster than the rate. §5.7's rule scales with the light, and the glows stay lit.
- **A setting for the night (Q9).** `Color.WHITE.lerp(light, k)` is still a blend of keys that changes no faster than the light, so §5.3's and §5.7's rules hold, and the lamps' strength follows.
- **A loop that waits for a set piece.** TUT's `test_the_tutorial_ends_with_its_group_and_the_seed_road_follows` draws tiles until one is a set piece. With a broken schedule the road has none (§6.2), so it runs out of memory rather than fail. A bound on the loop would fail it instead.
- **Saved runs.** The light isn't saved: every run starts at the start hour. A run saved part-way would save `seconds`, the light, the shadow and its alpha.
- **Each zone's own hours and lights.** `AreaDef` could hold its start hour or keys; `least_day_seconds()` and `validate()` would then take each zone's.
- **Native stacks.** Register a stack only once its bottom PR targets `main`, as the stack merges into that PR's base. Then land it whole: merging one of its PRs alone makes GitHub rebase the next branch at once, with a force-push. To land them one by one, unstack it first (§4.5).
- **What DN doesn't light or shade.** The car has no headlights, and the traffic lights don't glow. The legends and the set pieces cast no shadows, and the car and the legends hide no glows (§5.11, §5.12). Tinted shadows would need §5.7's shadow rule again (C22).
