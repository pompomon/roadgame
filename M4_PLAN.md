# M4 Areas — Detailed Plan

Status: proposed, with the Q1–Q9 defaults applied · 2026-11-09 · Scope: `IMPLEMENTATION_PLAN.md` (below: **IP**) §3 M4 row, §4 M4.1–M4.5 and "M4 tests", the M4 rows of §6, and §9's line on areas, set pieces and disasters

**Verified, not just reviewed.** Every file this plan adds or changes exists on branch `m4/prototype` (49c24e1) and was run with the tools below. Each PR state in §4 was rebuilt from that branch on top of `main` (5c1e0ba) and passed the five local checks (§6.1). The 83 negative cases in §6.2 were run on the prototype and on their PR states, and the stacked landing was simulated (§4.5). A CI run on the prototype built the Web and Android exports, and the Web build ran in headless Chrome: every area with its name, the tunnel, the bridge and the four disasters, with no errors (§6.5). The editor reports no warnings that `main` doesn't (§6.3).

- Godot 4.7.2-stable (Linux x86_64)
- GUT 9.7.1
- gdtoolkit 4.5.0 on Python 3.12
- shellcheck 0.11.0
- actionlint 1.7.12
- Chrome 156.0.8078.79, headless, driven by Playwright

Some things could not be run here: a headed Chrome, Firefox and the Galaxy Z Fold4. They are checked in PR 3 (E14, §6.4).

**Precedence.** For M4, this document replaces IP §4 M4 wherever they differ. Each difference is marked **Δ** with its finding number (K#, §2). Where it differs from `plan.md`, it says so too (K2, K3, K14). Once this plan is approved, fold the changes back into IP (Q8).

**Reference code (Q9).** This plan has no appendices: each PR checks its files out of `m4/prototype` (§4.1). Don't open a PR from that branch, because the three PRs carry its code. Pushes to it start nothing: `ci.yml` runs only for pull requests, pushes to `main` and manual runs. Its `ci.yml` is `main`'s, so a manual run saves no caches and keeps artifacts for one day (M0 F34).

**Prerequisites.** M3 is merged (#30–#33). No repository settings change.

Contents:
1. Goal and exit criteria
2. Review findings
3. Decisions and open questions
4. Work breakdown (3 PRs)
5. Design
6. Verification
7. Owner actions
8. M4 risks
9. Notes for later milestones

---

## 1. Goal and exit criteria

Goal (IP §3): "5 areas, tunnel, bridge and schedule; per-area disaster pools (grey-box art)". Since M1 the road runs through the five areas on IP M4.2's schedule, each with its own straights, junctions and ground colour, and since M2 with its own driving values. But nothing marks a new area: `GameState.area_id` changes silently, the tunnel and the bridge are only road tiles of another colour, and every area's pool is M3's sinkhole. In M4 the HUD names each area the car enters, the ground blends from one area into the next, the tunnel and the bridge stand over their roads, and a wrong turn plays the area's own disaster: a tornado in Rural, a flood in Meadows, either of them in the Village, and quicksand in the Desert. It is all grey box: the art, the props and the audio come with M5 (Q1, Q4).

| # | Exit criterion | Checked by |
|---|---|---|
| E1 | `AreaSchedule.validate()` also rejects an entry whose next junction can be out of the buffer when `JunctionTrigger` looks for it: the entry's set piece, its area's longest straight and the junction's own tile must add up to at most `BUFFER_REFILL_AT` (25) path tiles (K1). The game's schedule passes, with 6–14 | `test_area_schedule.gd` |
| E2 | A run can start in any area of the schedule. `AreaSchedule.starting_at(id)` and the user argument `--area=<id>` start it there at turn 0, without the set piece that leads in, and the later areas follow as many turns apart as in the game. An id that the schedule lacks is an error, and the run starts in the City (K10) | `test_area_schedule.gd`, `test_area_start.gd` |
| E3 | An autopilot run from the City meets the areas and set pieces in order: the tunnel and Rural at turn 34, the bridge and Meadows at 100, the Village at 200 and the Desert at 220, and no other change of area in 230 turns (K11, K21). `main.gd` reports each area the car enters to `GameState.area_id` and `EventBus.area_changed`, and the first area of each run too (K4, K15) | `test_area_order.gd`, `test_area_start.gd` |
| E4 | The HUD names each area the car enters, the first included, for `AREA_BANNER_SECONDS` (2 s) of the run: the time while the game is paused doesn't count. A new area replaces the name and starts its time again. The end of a run and a new run hide it. Every area's name is in the default font (K16) | `test_hud.gd`, `test_area_start.gd`, `test_smoke.gd` |
| E5 | The ground of the first `TRANSITION_TILES` (2) path tiles of an area is a checker of the last area's colour and its own, from a column of the ground atlas for each pair of areas that meet in the schedule (K14) | `test_greybox_atlas.gd`, `test_world_renderer.gd` |
| E6 | `WorldRenderer` adds a set piece's scene to `World/SetPieces` once the buffer has made its whole run, which may take two batches. It gives the scene the run's car, and frees it with the run's last tile. `bind()` frees the last run's set pieces and its unfinished run, and forgets its car. A set piece without a scene is an error (K2, K6, K12) | `test_world_renderer.gd`, `test_retry.gd` |
| E7 | The tunnel covers its run with rock a little wider than the road, with its mouth in the end face that shows. It draws over the car, and fades to `TUNNEL_SEE_THROUGH` (0.2) as the car nears, so the car and a crash's smoke show through it. It is never redrawn (K5, K8, K9) | `test_tunnel.gd`, `test_car_controller.gd` |
| E8 | The bridge's river flows across its run, between a bank at each end, and its waves drift down the river and never leave it. The near railing draws over the car; the river, the deck and the far railing draw under it, and a crash's smoke shows over them. Nothing is redrawn (K7–K9) | `test_bridge.gd`, `test_car_controller.gd` |
| E9 | On the game's road, the autopilot drives through the tunnel and over the bridge. Each is drawn while the car is on it, and gone once the car has left it. Over 1,010 rivers, no other road comes within `BRIDGE_BANK` (0.5 tiles) of a river (K7) | `test_set_pieces_on_the_road.gd` |
| E10 | Each of the four disasters keeps M3's contract (M3_PLAN.md §5.5). It shows nothing until its delay is over, finishes once after its `duration(params)` with the car out of sight, and works without a car or a camera. Its particles take their seed from its params and scale with them. It redraws no polygon and doesn't move the car. With the stop, it takes 2–4 s from the turn for any params, from `junction_speed` and from the cap (K9, K19, K20) | `test_disasters.gd` |
| E11 | The tornado comes along its params' direction, whirling dust and shaking the camera, carries the car off as it spins, shrinks and fades, and goes on its way; a stronger one is bigger and spins the car faster. The flood rolls in along its direction, spreads around the car and rises over it with spray, faster when stronger. The quicksand spreads under the car, as big as it is strong, with ripples, and sinks the car with flying sand, rocking it less and less, faster when stronger. Their parts over the car draw over it (K8) | `test_tornado.gd`, `test_flood.gd`, `test_quicksand.gd` |
| E12 | Each area has `plan.md` §4.3's pool: the sinkhole in the City, the tornado in Rural, the flood in Meadows, the flood and the tornado in the Village, and the quicksand in the Desert. A wrong turn in each area plays a disaster from its own pool, and game over comes 2–4 s after the turn. The Village plays both of its disasters (K10, K11) | `test_disasters.gd`, `test_disaster_pools.gd` |
| E13 | The main scene still boots and drives. The smoke run prints `autopilot: tile 165, turns 35, area rural` and no error lines, as in M3; it now passes the tunnel and the "Rural" name | `test_main_scene_boot.gd`, `smoke.sh` |
| E14 | Manual: the Web build in Chrome and Firefox, and the Galaxy Z Fold4, whose Chrome runs the Web build in each area (Q6), with the debug APK from the City. Each area's name shows, the ground blends, the tunnel fades over the car, the bridge's waves drift, and a wrong turn plays the area's disaster. No errors in the console or `adb logcat` | PR 3 (§4, PR 3 step 3) |
| E15 | All five required checks are green. The editor reports no new warnings | PR checks; §6.3 |

---

## 2. Review findings

IP's M4 design holds up in its parts: areas as data on a schedule, set pieces as scenes over runs of road, and a pool of disasters per area behind M3's `DisasterBase`. The problems are in how they meet M1–M3's code:
- a schedule that can put the next junction out of the buffer;
- set pieces in the y-sorted `Props`, and a tunnel that hides the car;
- a renderer that would add a set piece before its run is made;
- a river that can reach other roads;
- a first area that nobody hears of;
- a definition of done that the autopilot can't meet, and no way to test an area without driving to it.

- **High:** following IP gives a broken game, or a check that passes when it shouldn't.
- **Medium:** fragile, missing from the code it depends on, or broken in some order of events.
- **Low:** clarity, naming or polish.

"Prototype" means the problem was reproduced with Godot 4.7.2 on `m4/prototype`, with the probes P1–P5 (§6.5) or the negative cases N# (§6.2). "Source" means Godot's code at the 4.7.2-stable tag, which its file and line numbers refer to. Line numbers in the repository's files are `main`'s (5c1e0ba).

### High

| # | Finding | Evidence | Fix |
|---|---|---|---|
| K1 | IP M4.1's validator checks only that the turns increase and that the first is 0. `JunctionTrigger` looks for the next junction in the buffer as the car enters the tile after a junction, and if the buffer doesn't have it, it stops judging, with only a `push_error` (M2 H31). `AreaDef` allows straights of 20 tiles and an entry a set piece of 20, so a schedule that passes `validate()` can leave the next junction out of the buffer: the car then drives through junctions that nobody judges. | `area_schedule.gd:9–36` checks no distance; `area_schedule_entry.gd:10`, `area_def.gd:13`; `junction_trigger.gd:73–81`. `road_buffer.gd:28–36`: once the car enters a tile, the buffer holds at least `BUFFER_REFILL_AT` (25) tiles past it, and `car_sim.gd:89–98` moves the buffer on before the trigger looks. Prototype: on `main`, P1 found every junction with gaps of 25 and 26 tiles, and stopped judging at 27 on 12 of 20 seeds; N1–N3 | **Δ IP M4.1:** `validate()` also rejects an entry whose `gap()`, its `set_piece_length` plus its area's `max_straight` plus 1 for the junction's own tile, is above `BUFFER_REFILL_AT`, as M2 §9 asked. That leaves one tile spare, so it doesn't rest on the order of `CarSim.step()` (§5.2). The game's gaps are 6–14 (E1) |
| K2 | `plan.md` §7.1 and IP §5.2 put the set pieces in `Props`, which sorts its children by y. A set piece is one node over a whole run of up to 20 tiles: no single y puts the tunnel's rock over the car all along the run. And `Props` draws after `RoadLayer`, so IP's water "under the road" can't be in it. | `plan.md` §7.1; IP §5.2, M4.4; `world.tscn`: `GroundLayer`, `RoadLayer`, `DisasterLayer`, `Props` (M3 J5). Prototype: N36, N39, N43 | **Δ `plan.md` §7.1, IP §5.2, M4.4:** `World/SetPieces`, a `Node2D` between `GroundLayer` and `RoadLayer`. The river and the deck draw under the road, and the parts that cover the car have `z_index` 1 (K8; E6; N43) |

### Medium

| # | Finding | Evidence | Fix |
|---|---|---|---|
| K3 | IP M4.1 asks for `AreaDef` "exactly as in `plan.md` §3.7": `palette`, `road_tileset`, `ground_variants`, `props: Array[PropDef]`, `transition_tiles`, `ambient_loop` and `music`. M1 §9 adds the props stream and its density test. Nothing reads any of them before M5's art (M5.1), `PropPool` (M5.2) and `AudioDirector` (M5.3): fields with nothing behind them can't be tested, and five `.tres` files would fill them with placeholders. | IP M4.1, M5.1–M5.3; `plan.md` §3.7; M1_PLAN.md G7 and §9 | **Δ IP M4.1, `plan.md` §3.7:** no `PropDef`, prop, art or audio field and no props stream in M4. Each comes with what reads it, in M5, and the density test with the props (Q1, Q4, §9). `area_def.gd`'s comment says so |
| K4 | `CarSim` emits `area_changed` only when the area changes, and `main.gd` relays it to `GameState` and `EventBus`. At the start of a run, `main.gd` sets `GameState.area_id` itself, so nothing hears of the first area: the HUD wouldn't name the City, and M5's `AudioDirector`, which cross-fades on `area_changed` (IP M5.3), wouldn't start its music. | `car_sim.gd:229`; `main.gd:79, 90, 124–126`. Prototype: N13 | Each run starts by reporting its first area, through the same `_on_area_changed()` (Q2; E3; N13) |
| K5 | IP M4.4's tunnel has "an occluding top layer" over the car. The game's tunnel is 6 tiles long, and a schedule may have one of 20 (K1). The car would be hidden all through it, where it can still leave the road and crash, and so would its crash smoke. | IP M4.4; `area_schedule_entry.gd:10` | **Δ IP M4.4:** the tunnel draws over the car, and fades to `TUNNEL_SEE_THROUGH` (0.2) while the car is within `TUNNEL_FADE_NEAR` (0.75 tiles) of its road, back to opaque by `TUNNEL_FADE_FAR` (2.5 tiles). It fades by `modulate`, without a redraw (K9). The smoke test covers the tunnel too (Q3; E7; N40–N42) |
| K6 | IP M4.4 adds a set piece "when it sees the first `SET_PIECE` tile", with `setup(first_tile, length, …)`. But the buffer makes tiles in batches that end wherever `BUFFER_AHEAD` falls, so a run can come in two: at its first tile, the renderer can't know its length. IP doesn't say what a retry, which keeps `World` (M3 J12), does with the last run's set pieces. | `road_buffer.gd:89–97`: one `tiles_generated` per batch; `world_renderer.gd:33–42`. Prototype: in `test_a_set_piece_comes_once_its_run_is_made_and_goes_with_its_last_tile`, the first batch ends at tile 50, in the middle of a run of tiles 49–52; N21–N26 | **Δ IP M4.4:** the renderer gathers the run's tiles, and adds the scene when the first path tile after the run comes. It frees the scene when the buffer frees the run's last tile. `bind()` frees every set piece and the unfinished run (E6; N21–N26) |
| K7 | IP M4.4's bridge has "a water layer … under the road", but not how far the water reaches. Other road comes near a run: the junctions at its two ends, and the dead end of the junction before the run's own. That dead end runs beside the run, `min_straight` + 1 tiles from its centreline, so its edge can be 2.5 tiles away (D7: `min_straight` is at least 2). Water there would run under it. | IP M4.4; `road_generator.gd:6`: the path heads N, then alternates W and N. Prototype: with `RIVER_REACH` 2.5, a river reached a dead end (N31) | The river spans the run but for a bank of `BRIDGE_BANK` (0.5 tiles) at each end, and reaches `RIVER_REACH` (2.0 tiles) each way across it. Over 1,010 rivers, on 10 seeds of the game's schedule and of a schedule with a bridge at every turn, the nearest other road was 0.50 tiles away (E9; N31–N34) |
| K8 | `Props` holds the car and draws after `SetPieces` and `DisasterLayer`, so whatever they draw is under the car. The tunnel's rock, the bridge's near railing, the tornado's funnel, the flood's rising surface and its spray, and the quicksand's flying sand must cover it. | `world.tscn`; M3_PLAN.md §5.10. Prototype: N36, N39, N67, N74 | These parts have `z_index` 1, as M3's debris and smoke do. Tests check the `z_index` each part draws at, its parents' included, against the car's (E7, E8, E11) |
| K9 | IP M4.4's water is "animated", the tornado sways and the quicksand ripples. In Godot 4.7.2, each redraw of a `Polygon2D` after its first raises WebGL errors on the Web (godotengine/godot#124726, fixed in 4.8), and changing its `polygon`, `color` or `offset` redraws it. | M2_PLAN.md §5.7; M3_PLAN.md P5. Prototype: `offset` redraws too (N35, N59) | Every polygon gets its points once, in `setup()` or `_ready()`. The waves and the sway move by `position`, parts grow by `scale` and fade by `modulate` or `self_modulate`. Tests count the `draw` signals (E7, E8, E10; N35, N41, N59) |
| K10 | The Desert comes at turn 220, 6.6 minutes into an autopilot run (P2), and IP's pool test needs "a forced wrong turn in each area". No test or manual check can wait that long for each area, and nothing starts a run anywhere but in the City. | IP "M4 tests"; `main.gd:6–7`: only `--seed` and `--autopilot`. Prototype: P2 | `AreaSchedule.starting_at(id)` makes a schedule that starts in area `id`, and `main.gd`'s `--area=<id>` starts every run with it (Q5; E2; N4–N6, N14) |
| K11 | IP §9's definition of done has "4 disaster types appear in order during an autopilot run to turn 230". The autopilot never turns wrong (M2's `sim/test_autopilot_300_turns.gd`), so no disaster appears in its run. | IP §9, §6 | Two tests: `sim/test_area_order.gd` drives the autopilot to turn 230 and checks the areas and the set pieces (E3), and `integration/test_disaster_pools.gd` turns wrong in each area, started with `--area` (E12) |

### Low

| # | Finding | Fix |
|---|---|---|
| K12 | IP M4.1's `AreaScheduleEntry.set_piece` is a `PackedScene`. Since M1 G5 it is a `StringName`, which the generator writes into `RoadTile.set_piece`. | Keep the ids. `WorldRenderer.set_piece_scenes: Dictionary[StringName, PackedScene]` maps them to scenes in `world.tscn`, and `build()` reports an id without a scene (N27) |
| K13 | IP M4.2 makes the five areas and the schedule. They exist since M1 (G5), with M4.2's values, and M2 gave them its driving values. | M4 changes only the pools of four areas (E12). The values stay first guesses for M6 |
| K14 | `plan.md` §3.7 gives each area a `transition_tiles: TileSet`, and IP M4.3 uses it for "the first `transition_tiles` ground cells of a new area". The grey box has no art for it, and a count of cells would split a tile's 4×4 ground. | **Δ `plan.md` §3.7, IP M4.3:** the first `Tuning.TRANSITION_TILES` (2) path tiles of an area, whose ground is a checker of the two areas' colours, from a ground-atlas column for each pair of areas that meet in the schedule. They are straights, as `min_straight` is at least 2 (D7). M5.1's art can bring a transition TileSet (§9; N17–N20) |
| K15 | IP M4.3 has `GameState` emit `area_changed`. Since M2, `CarSim` emits it as the car enters a new area's first tile, and `main.gd` relays it to `GameState.area_id` and `EventBus.area_changed` (`car_sim.gd:10, 229`; `main.gd:79, 124–126`; `event_bus.gd:10`). | Keep M2's design. The HUD listens to `EventBus` (E3, E4) |
| K16 | IP M4.3's banner shows "for 2 s", but doesn't say whether a pause stops the time, what a new area does within the 2 s, or what the end of a run does. | `AREA_BANNER_SECONDS` counts only while the game isn't paused. A new area replaces the name and starts the time again. The end of a run and a new run hide it (E4; N7–N12) |
| K17 | IP M4.4's `setup(first_tile, length, heading)` takes a heading that the first tile already has (`RoadTile.heading`). | `setup(first_tile, length)`: one source for the heading |
| K18 | IP M4.4's tunnel darkens the screen with a `CanvasModulate` and sends the SFX to a reverb, and the bridge's water has an animated shader. The reverb needs M5.3's `AudioDirector`; the others are art. | All three come with M5 (Q4, §9). The grey box tints the road through the tunnel and over the bridge, as since M1 (`greybox_atlas.gd:30–33`) |
| K19 | M3 J3 lets a disaster change only the car's `scale` and `modulate`, but the tornado spins the car and the quicksand rocks it. | `CarController` sets the car's position and its arrow's rotation (`car_controller.gd:36, 38`), so a disaster may turn the car's root too. `DisasterBase` and `CarController` say so (N60) |
| K20 | IP gives each disaster 2–4 s, and M3 tested the sinkhole's time from its own constants. Each new disaster would need a test of its own. | Each disaster's script has `static func duration(params)`, the seconds from `play()` to `finished`. One test checks every disaster in every pool, with the stop (E10; N53–N55) |
| K21 | IP's "M4 tests" put the autopilot run to turn 230 in `unit/test_area_schedule.gd`. It drives the car for minutes of game time, like M2's sim tests. | `tests/sim/test_area_order.gd` (E3) |

---

## 3. Decisions and open questions

This plan applies the defaults below. Tell me if you want any of them changed.

| # | Question | Default (applied) | Alternative |
|---|---|---|---|
| Q1 | Props in M4? | No: they come with M5.2's `PropPool` and the art, with `PropDef`, the props stream and its density test (K3) | Grey-box props now, with `PropDef`, the props stream and the density test |
| Q2 | Report each run's first area? | Yes, as a change from no area: the HUD names it, and M5's music can start with it (K4) | Only changes of area, as in M2 and M3 |
| Q3 | The tunnel over the car | It draws over the car and fades to 0.2 while the car is near (K5) | IP's occluding roof, which hides the car for the tunnel's length |
| Q4 | `AreaDef`'s art and audio fields, the water shader, the `CanvasModulate` and the reverb | With M5, where something reads them (K3, K18) | Add the fields now, unread, with placeholders |
| Q5 | `--area` in release builds? | In every build, like `--seed` and `--autopilot`. It changes nothing unless it's given (K10) | Debug builds only |
| Q6 | How does the Fold4 check each area? The debug APK can't take user arguments: Godot 4.7.2 strips them from the intents of exported activities (P4) | The Web build in the Fold4's Chrome, served from the computer over `adb reverse`, with `?arg=--area=<id>` (§4, PR 3 step 3). The APK checks the City, the tunnel and Rural, which come in about a minute | Read `?area=` with `JavaScriptBridge` in the game itself; or drive the APK to each area, 6.6 minutes to the Desert (P2) |
| Q7 | How do the 3 PRs land? | Stacked branches, each retargeted to `main` in turn (§4.5) | One PR at a time, each opened after the previous one merges |
| Q8 | Fold this plan into IP? | After review. Until then, this document wins for M4 | — |
| Q9 | Appendices with every file, as in M0? | No: `m4/prototype` is the reference, and PRs check files out of it | Copy the files into this plan |

The values in §5.10 are first guesses for the grey box. E14 judges them on the Fold4, and M6 tunes them.

---

## 4. Work breakdown

There are three PRs, and each one leaves CI green (E15). The total estimate is about 3 days, at the top of IP's size "M" (2–3 days). The code exists and is verified, but M4 is wider than M3: two set pieces and three disasters, each with its own tests. Most of the remaining risk is in PR 3: how the set pieces and the disasters look and time on the Fold4 and in real browsers can't be checked locally (E14).

```
PR 1 areas ──▶ PR 2 world ──▶ PR 3 disasters
 (M4.1, M4.3:     (M4.3, M4.4)     (M4.2's pools,
  the schedule,                     M4.5)
  --area, names)
 ~0.5 d           ~1 d             ~1.5 d
```

After PR 1, the HUD names each area, and `--area` starts a run in any of them; the road looks as in M3. PR 2 draws the ground's transitions, the tunnel and the bridge. PR 3 adds the tornado, the flood and the quicksand, and gives each area its pool.

### 4.1 Porting from the prototype

Every PR follows the same steps:

1. Fetch the branches and create the PR's branch. The refspec also works in a clone that tracks only `main`, as this one does:
   ```bash
   git fetch origin main '+refs/heads/m4/*:refs/remotes/origin/m4/*'
   git switch -c m4/1-areas origin/main    # PRs 2–3: from the previous PR's branch (§4.5)
   ```
2. Check the PR's files out of the prototype with the command in its section. The globs are quoted so the `.uid` files come along.
3. One trim, in PR 1. Each other file belongs to one PR, whole, except `ui/main.gd`: PR 1 takes it without the one line that PR 2 adds back. `config/tuning.gd` belongs to PR 1, with the values of the set pieces and the disasters too.
4. Run `tools/ci/import.sh`. It must create no files: `git status --porcelain` lists only the checked-out paths.
5. Run §6.1 and compare the counts with the PR's "Expect" line.
6. Have a model of another family review it (`AGENTS.md` §7). Then commit, push and open the PR.

The three commands below were run in this order on `main` (5c1e0ba). They checked out 13, 23 and 28 files, gave exactly the PR states of §6.1, and ended at the prototype's tree.

### PR 1: Areas: the schedule's check, `--area` and the area's name (M4.1, M4.3) **Δ K1, K3, K4, K10, K11, K15, K16, K21**

Branch `m4/1-areas`, from `main`.

| Area | Files |
|---|---|
| Tuning | `config/tuning.gd`: all of M4's constants (§5.10) |
| Areas | `areas/area_schedule.gd`: the gap check, `gap()` and `starting_at()` (§5.2); `areas/area_def.gd`: comments (K3) |
| UI | `ui/hud.gd`, `ui/hud.tscn`: the area's name (§5.3) |
| Game | `ui/main.gd`: `--area`, and each run reports its first area (§5.2, §5.3) |
| Tests | `tests/integration/test_area_start.gd`; `tests/sim/test_area_order.gd`; more tests in `tests/unit/test_area_schedule.gd` and `test_hud.gd`; `tests/helpers/main_scene.gd`: a comment |

Every new `.gd` file comes with its `.gd.uid`.

```bash
git checkout origin/m4/prototype -- areas/area_def.gd areas/area_schedule.gd config/tuning.gd \
  ui/hud.gd ui/hud.tscn ui/main.gd tests/helpers/main_scene.gd tests/unit/test_area_schedule.gd \
  tests/unit/test_hud.gd 'tests/sim/test_area_order.gd*' 'tests/integration/test_area_start.gd*'
sed -i '/^\t_world\.car = _car$/d' ui/main.gd
```

The trim (the `sed` line) takes out `_world.car = _car`, which needs PR 2's `WorldRenderer.car`. Expect: `check_scripts: loaded 68 scripts`; `GUT: 213 tests passed` (144,721 asserts, 17–18 s). `smoke.sh` still prints `autopilot: tile 165, turns 35, area rural`. Negative cases N1–N16.

**Acceptance:** E1–E4, E13 and E15.

### PR 2: World: the ground's transitions, the tunnel and the bridge (M4.3, M4.4) **Δ K2, K5–K9, K12, K14, K17, K18**

Branch `m4/2-world`, from `m4/1-areas`.

| Area | Files |
|---|---|
| World | `world/greybox_atlas.gd`: a ground column per transition (§5.4); `world/world_renderer.gd`: the transitions and the set pieces (§5.4, §5.5); `world/world.tscn`: `SetPieces` and the set pieces' scenes (§5.5) |
| Set pieces | `setpieces/set_piece.gd`; `tunnel.gd`, `tunnel.tscn`; `bridge.gd`, `bridge.tscn` (§5.6, §5.7) |
| Game | `ui/main.gd`: the line that gives the world the run's car |
| Tests | `tests/unit/test_tunnel.gd`, `test_bridge.gd`; `tests/sim/test_set_pieces_on_the_road.gd`; more tests in `test_world_renderer.gd`, `test_greybox_atlas.gd` and `test_car_controller.gd`; `tests/integration/test_retry.gd`: the world's car; `tests/helpers/road_fixtures.gd`: two schedules with set pieces |

```bash
git checkout origin/m4/prototype -- world/greybox_atlas.gd world/world_renderer.gd world/world.tscn \
  setpieces ui/main.gd tests/helpers/road_fixtures.gd tests/unit/test_greybox_atlas.gd \
  tests/unit/test_world_renderer.gd 'tests/unit/test_tunnel.gd*' 'tests/unit/test_bridge.gd*' \
  tests/unit/test_car_controller.gd 'tests/sim/test_set_pieces_on_the_road.gd*' \
  tests/integration/test_retry.gd
```

No trims. Expect: 74 scripts; `GUT: 234 tests passed` (144,916 asserts, 18–20 s). The smoke line is the same. Negative cases N17–N44.

**Acceptance:** E5–E9, E13 and E15.

### PR 3: The tornado, the flood and the quicksand (M4.2's pools, M4.5) **Δ K9, K11, K19, K20**

Branch `m4/3-disasters`, from `m4/2-world`.

| Area | Files |
|---|---|
| Disasters | `disasters/tornado.gd`, `tornado.tscn`, `flood.gd`, `flood.tscn`, `quicksand.gd`, `quicksand.tscn` (§5.9); `disaster_base.gd`: `apply_params()`, `outline()` and the contract's new rules (§5.8); `sinkhole.gd`: uses the two |
| Areas | `areas/rural.tres`, `meadows.tres`, `village.tres`, `desert.tres`: the pools (§5.8) |
| Car | `car/car_controller.gd`: a comment (K19) |
| Tests | `tests/unit/test_disasters.gd`, `test_tornado.gd`, `test_flood.gd`, `test_quicksand.gd`; `tests/integration/test_disaster_pools.gd`; `tests/helpers/disaster_fixtures.gd` |

```bash
git checkout origin/m4/prototype -- disasters areas/rural.tres areas/meadows.tres \
  areas/village.tres areas/desert.tres car/car_controller.gd 'tests/helpers/disaster_fixtures.gd*' \
  'tests/unit/test_disasters.gd*' 'tests/unit/test_tornado.gd*' 'tests/unit/test_flood.gd*' \
  'tests/unit/test_quicksand.gd*' 'tests/integration/test_disaster_pools.gd*'
```

1. No trims. Expect: 83 scripts; `GUT: 262 tests passed` (146,061 asserts, 19–21 s). The smoke line is the same. Negative cases N45–N83.
2. Check that the stack now matches the prototype. The command prints nothing, unless a review changed something on purpose. If `main` has changed other files since 5c1e0ba, exclude them too:
   ```bash
   git diff --stat origin/m4/prototype -- . ':!M4_PLAN.md'
   ```
3. Manual checks (E14). Start a run that uploads the builds, and download them within a day (M0 F34). `gh run download` puts each artifact in a folder named after it: `web`, `android-Android APK` and `android-Android AAB`.
   ```bash
   gh workflow run ci.yml --ref m4/3-disasters -f upload-builds=true
   gh run list -w ci.yml -b m4/3-disasters -e workflow_dispatch -L 1    # the run id
   gh run watch <run id> --exit-status
   gh run download <run id> -D /tmp/roadgame-builds
   ```
   - **A Web build that takes `--area`.** The Web export starts the engine with no user arguments: its `index.html` has `"args":[]` (P4). Serve a copy whose arguments come from the page's address:
     ```bash
     cp -r /tmp/roadgame-builds/web /tmp/roadgame-web
     sed -i 's/"args":\[\]/"args":["--"].concat(new URLSearchParams(location.search).getAll("arg"))/' \
       /tmp/roadgame-web/index.html
     python3 -m http.server -d /tmp/roadgame-web 8000
     ```
     http://localhost:8000/?arg=--area=desert then starts every run in the Desert, and `&arg=--seed=1` adds a seed. Without `?arg=`, the copy runs as the build does.
   - **Web**, in Chrome and Firefox:
     - From the City, with no `?arg=`: the HUD names the City for 2 s. About a minute in, after the 34th turn, the road goes into the tunnel. Its rock fades as the car nears, so the car shows through it. Then the HUD names Rural, and the ground blends from the City's colour into Rural's.
     - In each area, with `?arg=--area=` and `city`, `rural`, `meadows`, `village` or `desert`: the HUD names it at once. Take a wrong exit: the area's disaster plays, and game over comes 2–4 s after the turn. In the Village, seed 1 plays the tornado, and seed 12345 the flood (P5).
     - With `?arg=--area=rural`: the bridge comes after Rural's 66th turn, about 2 minutes in (P2). The river flows across the road, its waves drift, and the near railing draws over the car. Then the HUD names Meadows.
     - Pause while a name shows: the name stays until the game goes on and its 2 s are over.
     - The console shows one `grey box:` line, and no errors or WebGL warnings. Headless Chrome already ran these checks (§6.5).
   - **Android**, on the Galaxy Z Fold4, folded and unfolded:
     - The debug APK: `adb install -r "/tmp/roadgame-builds/android-Android APK/roadgame-debug.apk"`. From the City, the tunnel and Rural come about a minute in. Judge the names, the tunnel's fade and the ground's blend on both screens, at zoom 1 and 2. A wrong turn in the City still plays the sinkhole. `adb logcat -s godot` shows no errors.
     - The other areas, in the Fold4's Chrome (Q6). With the copy above served, run `adb reverse tcp:8000 tcp:8000` and open http://localhost:8000/?arg=--area=rural on the phone, then each other area. Check them as on the Web, and judge the size and the timing of the disasters and the set pieces (§5.10).
4. After the merge, https://pompomon.github.io/roadgame/ runs the game with M4.

**Acceptance:** E10–E12, E13, E14 and E15.

### 4.5 Landing the stack (Q7)

This is M3_PLAN.md §4.5's procedure, which landed #31–#33, with the `m4/` names. It was checked again by simulating the squash merges with `git merge-tree`, on the PR states of §6.1.

1. Each PR branches from the previous PR's branch, and its PR targets that branch, so its diff shows only its own files. `ci.yml` runs on every `pull_request` with no branch filter, so every PR gets the five checks. Required checks only gate PRs into `main`.
2. A review fix for PR n is committed on PR n's branch and then merged (`git merge --no-ff --no-edit`) into each later branch. No rebases and no force-pushes.
3. Merge only a PR whose base is `main`. A merge into another PR's branch skips the required checks; in M0, that is why #16 was needed.
4. After PR n squash-merges, update PR n+1:
   ```bash
   git fetch origin main '+refs/heads/m4/*:refs/remotes/origin/m4/*'
   git switch <PR n+1 branch>
   git merge origin/<PR n branch>     # PR n's final state, in case a fix wasn't merged up yet
   git merge origin/main              # the squash commit
   git diff --name-only origin/main   # must list only PR n+1's files
   git push
   gh pr edit <PR n+1> --base main    # unless GitHub did it (step 5)
   ```
   - If PR n's branch is already deleted, fetch its last state with `git fetch origin pull/<PR n>/head` and merge `FETCH_HEAD` instead.
   - The simulated merges had no conflicts, and the `diff` listed only each PR's own files: 13, 23 and 28. The last squash gave the prototype's tree. A conflict here means that a later branch changed the same lines as a review fix of PR n. Resolve it by hand.
   - A later branch mustn't change a file that an earlier PR adds or changes, unless the earlier PR makes the same change: merging `main` is then a conflict. So a review fix goes on the branch of the PR that owns the file (step 2). PR 1 owns `config/tuning.gd`, which PRs 2 and 3 use. `ui/main.gd` is the one file that two PRs change: PR 1 all but one line, and PR 2 that line. It merged without a conflict, because PR 2's branch has PR 1's change. A fix to `ui/main.gd` goes on PR 1's branch, unless it is to that line.
   - The merges bring no change that the branch doesn't have already, so the push may start no Copilot review. If the PR needs one, request it with `gh pr edit <PR n+1> --add-reviewer @copilot`.
5. If the owner deletes PR n's branch after the merge, GitHub retargets PR n+1 to `main` by itself, as it did for #21 and #22. Either way, step 4 is still needed: until PR n+1 merges `main`, its diff also shows PR n's files.

### 4.6 Review fixes

None yet. A fix that this plan's review brings is committed on `m4/prototype`, before the PRs check their files out of it, and listed here. A fix that a PR's review brings is committed on the branch of the PR that owns the code, merged into the later branches (§4.5), and listed here with its tests and negative case; PR 3's step 2 then lists its files.

| PR | Change | Tests | Negative case |
|---|---|---|---|

---

## 5. Design

The code on `m4/prototype` is the reference. This section summarizes it and lists what differs from IP, and why.

### 5.1 Files

| File | Class | PR | IP |
|---|---|---|---|
| `config/tuning.gd` | `Tuning` | 1 | M4.3–M4.5's values (§5.10) |
| `areas/area_schedule.gd` | `AreaSchedule` | 1 | M4.1's validator **Δ K1**; `starting_at()` (K10) (§5.2) |
| `areas/area_def.gd` | `AreaDef` | 1 | comments only **Δ K3** |
| `ui/main.gd` | (the game) | 1, 2 | `--area` (K10) and the first area (K4) (§5.2, §5.3); in PR 2, the world's car (§5.5) |
| `ui/hud.gd`, `ui/hud.tscn` | `Hud` | 1 | M4.3's area name **Δ K16** (§5.3) |
| `world/greybox_atlas.gd` | `GreyboxAtlas` | 2 | M4.3's transitions **Δ K14** (§5.4) |
| `world/world_renderer.gd` | `WorldRenderer` | 2 | M4.3, M4.4 **Δ K6, K12, K14** (§5.4, §5.5) |
| `world/world.tscn` | — | 2 | **Δ K2** (§5.5) |
| `setpieces/set_piece.gd` | `SetPiece` | 2 | M4.4 **Δ K6, K17** (§5.5) |
| `setpieces/tunnel.gd`, `tunnel.tscn` | `Tunnel` | 2 | M4.4 **Δ K5, K8, K9, K18** (§5.6) |
| `setpieces/bridge.gd`, `bridge.tscn` | `Bridge` | 2 | M4.4 **Δ K7, K8, K9, K18** (§5.7) |
| `disasters/disaster_base.gd` | `DisasterBase` | 3 | `apply_params()`, `outline()` and two more rules **Δ K19, K20** (§5.8) |
| `disasters/sinkhole.gd` | `Sinkhole` | 3 | uses `apply_params()` and `outline()`, which move from it to `DisasterBase` |
| `disasters/tornado.gd`, `tornado.tscn` | `Tornado` | 3 | M4.5 (§5.9) |
| `disasters/flood.gd`, `flood.tscn` | `Flood` | 3 | M4.5 (§5.9) |
| `disasters/quicksand.gd`, `quicksand.tscn` | `Quicksand` | 3 | M4.5 (§5.9) |
| `areas/rural.tres`, `meadows.tres`, `village.tres`, `desert.tres` | — | 3 | M4.2's pools (§5.8) |
| `car/car_controller.gd` | `CarController` | 3 | a comment **Δ K19** |

All of them are in IP §2's layout, with the scripts of the new scenes. M4 adds neither `areas/prop_def.gd` nor `world/prop_pool.gd` (Q1), and no shader or `autoload/audio_director.gd` (Q4). `GameState`, `EventBus`, `CarSim`, `RoadGenerator`, `RoadBuffer`, `JunctionTrigger`, `DisasterDirector`, `schedule.tres` and `city.tres` don't change (K13, K15).

### 5.2 The schedule and `--area` (PR 1) **Δ IP M4.1**

```gdscript
# areas/area_schedule.gd
func validate() -> PackedStringArray               # M1's checks, and now the gap (K1)
static func gap(entry: AreaScheduleEntry) -> int   # set_piece_length + area.max_straight + 1
func starting_at(id: StringName) -> AreaSchedule   # K10
```

- **The gap (K1).** In an entry's area, a junction is at most `gap(entry)` path tiles after the last one: the set piece that leads into the area, the area's longest straight, and the junction's own tile. `JunctionTrigger` looks for the next junction as the car enters the tile after a junction. `CarSim.step()` moves the buffer on first, so the buffer then holds at least `BUFFER_REFILL_AT` (25) tiles past that tile, and a gap of up to 26 tiles is found. P1 found every junction with gaps of 25 and 26, and lost one at 27 on 12 of 20 seeds (§6.5).
  - `validate()` allows up to 25: then the next junction is in the buffer even if the trigger looked before the buffer moved. `test_area_schedule.gd` drives schedules whose every junction is as far as they allow: at a gap of 25, the next junction is sometimes the buffer's last tile but one (N1–N3).
  - The message is `turn 34: the next junction can be 26 tiles away, above BUFFER_REFILL_AT (25)`. The gap is checked only for an entry that passes M1's checks, which report the rest.
  - The game's gaps: 6 in the City and the Village, 9 in the Desert, 13 in Meadows (the bridge's 5, 7 and 1) and 14 in Rural (the tunnel's 6, 7 and 1).
- **`starting_at(id)` (K10).** A new schedule from the first entry whose area is `id`: that entry and the later ones, with their turns moved so that it is turn 0. The first entry has no set piece: a run starts on its own straight (`START_STRAIGHT_TILES`), not in a tunnel. The later areas come as many turns apart as in the game, through their set pieces: from Rural, Meadows comes at turn 66 after the bridge, the Village at 166 and the Desert at 186. The entries share their `AreaDef`s, and the schedule it was called on doesn't change. An id it lacks is an error, `AreaSchedule: no area <id>`, and it returns the schedule itself (N4–N6).
- **`--area=<id>` (Q5).** `main.gd`'s `_ready()` reads it with `_parse_area()`, as it reads `--seed` with `_parse_seed()`, and replaces the schedule with `starting_at(id)` before `WorldRenderer.build()` (N14). So every run of the session starts in that area, retries included, and the ground atlas has only the areas from there on. Without the argument nothing changes, in any build. The Web export and the APK pass no user arguments, so PR 3's manual checks patch a copy of the Web build (P4, Q6; §4, PR 3 step 3).

### 5.3 The area's name (PR 1) **Δ IP M4.3**

```
main._start_run(run_seed): … GameState.start_run(run_seed) ─▶ run_started ─▶ Hud._reset(): hides the name
                           _on_area_changed(_sim.area)            # K4: each run's first area
CarSim.area_changed(area) ─▶ main._on_area_changed(area)          # as in M2
    GameState.area_id = area.id
    EventBus.area_changed(area) ─▶ Hud._on_area_changed(area): the name, for AREA_BANNER_SECONDS
EventBus.run_ended ─▶ Hud._on_run_ended(): hides the pause button and the name
```

- **The first area (K4, Q2).** `_start_run()` used to set `GameState.area_id` itself. Now, after `GameState.start_run()` has cleared it, it calls `_on_area_changed(_sim.area)`, as `CarSim`'s signal does for each new area (N15). So the first run and every retry set `GameState.area_id`, emit `EventBus.area_changed`, and the HUD names the area (N13). M5's `AudioDirector` can start the area's music on it (§9).
- **The name (K16).** `%AreaBanner` is a `Label` across the HUD, 72–112 px from the top, under the top bar of the distance, the turns, the health and the pause button. It has the game-over screen's cause's look, 24 px with a 6 px black outline, and is hidden until an area comes. A `Label` ignores the mouse by default (probed in 4.7.2), so it stops no tap.
  - `_on_area_changed()` shows the area's `display_name`, not its id (N12), and sets `_banner_left` to `AREA_BANNER_SECONDS` (2 s).
  - `_physics_process()` counts it down and hides the name at 0 (N8). The HUD processes while the game is paused (M2), so it counts only while `GameState.state` isn't `PAUSED`: a pause keeps the name and its time (N7).
  - A new area replaces the name and starts its 2 s again (N11).
  - `_reset()`, on every `run_started`, and `_on_run_ended()` hide it (N9, N10). The game-over screen names the area reached, as in M3.
  - Its time comes from physics deltas, as M3's does (M3 J2), so GUT's `simulate()` moves it.
- `test_smoke.gd`'s glyph test already checks every `Label` of the main scene and every area's `stats_text()`, which has its `display_name`. So every area's name is in the default font (E4).

### 5.4 The ground's transitions (PR 2) **Δ IP M4.3, `plan.md` §3.7**

```gdscript
# world/greybox_atlas.gd: `transitions` holds (from, to) pairs of indices into `colors`
static func build_ground_tileset(colors: Array[Color], transitions: Array[Vector2i] = []) -> TileSet
```

- **The atlas.** The ground atlas keeps M1's column per area, with two shades of its colour as rows. After them comes a column per transition: the colour of the area it comes from as row 0, and of the area it goes to as row 1 (N17). `build()` adds one for each pair of consecutive schedule entries whose areas differ, once per pair. A pair has an order: from Rural into Meadows is not from Meadows into Rural (N20). The game's schedule has four.
- **The tiles.** `ground_coords()` picks a ground cell's row by its checker parity, as in M1. So a transition tile's 4×4 ground cells are a checker of the two areas' colours, where an area's own tiles are a checker of two shades of its colour.
- **Which tiles (K14).** `_ground_column(tile)` gives a path tile the transition's column if one of the `TRANSITION_TILES` (2) path tiles before it is in another area, and its area's column otherwise (N18, N19). A new tile's two path tiles before it are still in the buffer: the buffer keeps `BUFFER_BEHIND` (5) tiles behind the car, and makes new tiles at least `BUFFER_REFILL_AT` (25) ahead of it. The path's first two tiles have none before them and keep their area's column.
- An area's first path tiles are straights, as `min_straight` is at least 2 (D7). So no junction or dead end needs a transition, and dead ends, with a `path_index` of −1, keep their area's column. A `TRANSITION_TILES` above `min_straight` would blend a junction but not its dead ends.
- The set-piece tiles and the junction before them belong to the last area (M1 G5), so the ground blends after the tunnel and after the bridge.

### 5.5 Set pieces in the world (PR 2) **Δ `plan.md` §7.1, IP §5.2, M4.4**

```gdscript
# world/world_renderer.gd
@export var set_piece_scenes: Dictionary[StringName, PackedScene] = {}   # K12: by RoadTile.set_piece
var car: Node2D                     # the run's car; set_car() gives it to the set pieces
func build(schedule: AreaSchedule) -> void   # also reports a set piece without a scene
func bind(buffer: RoadBuffer) -> void        # also frees the set pieces and the open run, and forgets the car

@abstract class_name SetPiece extends Node2D
var car: Node2D                     # the run's car, or null
var rect := Rect2()                 # the run's cells, in tile space
var heading := -1                   # the run's heading
func setup(first_tile: RoadTile, length: int) -> void    # Δ K17: no heading
func axis() -> int                                       # Vector2.AXIS_X or AXIS_Y
func grown(across: float, along: float) -> Rect2         # rect, grown across and along the run
func car_distance() -> float                             # tiles from rect to the car; INF without one
static func corners(r: Rect2, height := 0.0) -> PackedVector2Array   # a rectangle on the ground, or raised
static func face(from: Vector2, to: Vector2, low: float, high: float) -> PackedVector2Array   # an upright face
@abstract func _build() -> void                          # gives the polygons their points, once
```

- **The layer (K2).** `world.tscn` gets `SetPieces`, a `Node2D` between `GroundLayer` and `RoadLayer`, which doesn't sort by y. So World draws the ground, the set pieces, the road, the disasters and then `Props` with the car (N43). The river and the deck draw under the road. The parts that cover the car, the tunnel and the bridge's near railing, have `z_index` 1, so they draw over `Props` (K8).
- **When (K6).** `_on_tiles_generated()` follows the path tiles in order and gathers a run of `SET_PIECE` tiles into one set piece (N22). The first path tile after the run ends it. Then the renderer instantiates the run's scene, gives it the car, adds it to `SetPieces` and calls `setup(run[0], run.size())`, all in that frame. A run that a batch ends in the middle waits for the next batch (N21). The renderer keeps each set piece by its last tile's `path_index`, and frees it when the buffer frees that tile, once the car is `BUFFER_BEHIND` (5) tiles past the run (N23).
- **Retry (M3 J11).** `bind()` frees every set piece and the open run, and sets `car` to null (N24–N26). `main.gd`'s `_start_run()` sets `_world.car` after `bind()` (N30). `set_car()` gives the car to the set pieces of the buffer's first batch (N28), and each later set piece gets it as it's added (N29).
- **Ids (K12).** `world.tscn` maps `&"tunnel"` and `&"bridge"` to their scenes. `build()` reports each set piece of the schedule that has none, `WorldRenderer: no scene for set piece <id>` (N27). Its run then gets no scene and draws as plain road.
- **`SetPiece` (K17).** `setup(first_tile, length)` takes the heading from the first tile, works out `rect`, and calls `_build()`. The points are World pixels, from `Iso.tile_to_world()`, so the root stays at the origin, and they never change after `_build()` (K9). A set piece works without a car: `car_distance()` is then `INF`. The class's doc comment states these rules.

### 5.6 The tunnel (PR 2) **Δ IP M4.4**

`tunnel.tscn` is a `Tunnel` root at `z_index` 1, so it draws over the car (N39), with four `Polygon2D`s in drawing order: `FaceX`, `FaceY`, `Mouth` and `Roof`.
- **The rock** is a block over the run, `HALF_WIDTH` (0.55 tiles) each way from its centreline, so it covers the road (`ROAD_HALF_WIDTH` 0.32) and a little more (N37). It is `TUNNEL_HEIGHT_PX` (40 px) tall. Its roof and the two faces that the camera sees, +x and +y, show.
- **The mouth** is a dark opening in the end face that shows, the one at the far end of the run's axis: `MOUTH_HALF_WIDTH` (0.36 tiles) each way, and 0.8 of the tunnel's height (N38). The generator's path heads only N and W (`road_generator.gd:6`), so that face is where the car goes in.
- **The fade (K5, Q3).** Each physics frame, `modulate.a` is `opacity(car_distance())`: `TUNNEL_SEE_THROUGH` (0.2) while the car is within `TUNNEL_FADE_NEAR` (0.75 tiles) of the run's cells, rising with `smoothstep` to 1 at `TUNNEL_FADE_FAR` (2.5 tiles) (N40). `_build()` sets it too, so the first frame is right. It fades the whole tunnel by `modulate`, which doesn't redraw it (N41).
- At 0.2, a crash's smoke still shows through it: `test_car_controller.gd` checks the smoke's contrast through each of its four colours, over every background. At 0.35 it doesn't (N42).
- The road under it keeps M1's tint (`Row.TUNNEL`). The darkening `CanvasModulate` and the reverb come with M5 (K18, Q4).

### 5.7 The bridge (PR 2) **Δ IP M4.4**

`bridge.tscn` is a `Bridge` root with `River`, `Waves` (a `Node2D` with one `Wave`), `Deck`, `FarRailing` and `NearRailing`, the last at `z_index` 1.
- **The river (K7)** is `river(rect, axis())`: the run's cells less `BRIDGE_BANK` (0.5 tiles) at each end, and `RIVER_REACH` (2.0 tiles) each way across from the run's centreline (N31, N32). It flows across the run, towards the viewer: `across()`.
- **The waves** are 9 dashes, `WAVE_ROWS` (3) rows along the run of `WAVES_PER_ROW` (3), each `WAVE_LENGTH` (0.4 tiles) long down the river and `WAVE_WIDTH` (0.05 tiles) wide. `_build()` gives the first one its points and duplicates it. Each physics frame, `wave_rect(index, time)` places each wave: they start spread down the river, drift down at `WAVE_SPEED` (0.6 tiles/s), and go back to the top when their end reaches the bottom, so they never leave the river (N33, N34). They move by `position` only (K9; N35). Their clock is the physics deltas, with no randomness: `lint.sh`'s RNG rule covers `setpieces/` (IP §5.3; N44).
- **The deck** spans the run, `DECK_HALF_WIDTH` (0.42 tiles) each way, under the road and its M1 tint (`Row.BRIDGE`). **The railings** are faces `RAILING_HEIGHT` (8 px) tall, `RAILING` (0.4 tiles) each way from the centreline. The near one draws over the car (N36). They only show the edge: off the road, the car still takes damage by M2's capsule test, as IP M4.4 says.
- The river's shader comes with M5's art (K18, Q4).

### 5.8 Disasters and their pools (PR 3) **Δ IP M4.5**

```gdscript
# disasters/disaster_base.gd
const OUTLINE_POINTS := 32
static func apply_params(particles: CPUParticles2D, params: DisasterParams) -> void   # from Sinkhole
static func outline(radius: float) -> PackedVector2Array                             # from Sinkhole
# Each disaster's script (K20), which tests/unit/test_disasters.gd calls:
static func duration(params: DisasterParams) -> float   # the seconds from play() to finished
```

- **The contract** is M3's (M3_PLAN.md §5.5), with two more rules, which the class's doc comment states:
  - A disaster may also turn the car's root (K19): `rotation` joins `scale` and `modulate`. `CarController` sets the car's `position` and its arrow's `rotation`, not the root's, so neither undoes the other. A disaster still may not move the car (N60).
  - Each disaster's script has `static func duration(params)`. `test_disasters.gd` checks it for every scene of every pool (K20; N55).
- **`apply_params()`** moves M3's particle set-up from the sinkhole to the base, for all four disasters: a fixed seed from `particle_seed` (M3 J16), the speed times `intensity` and the size times `particle_scale` (N48–N51). **`outline()`**, the sinkhole's circle on the ground, moves with it, and its `POINTS` becomes `OUTLINE_POINTS` (N52). The sinkhole works as before: its 10 tests don't change.
- **The pools** are IP M4.2's, from `plan.md` §4.3. The director picks from a pool with the run's disaster stream, as in M3 (M3_PLAN.md §5.3), so in the Village the seed decides: seed 1 plays the tornado, and seed 12345 the flood (P5; N45–N47).

| Area | `disasters` | Since |
|---|---|---|
| City | sinkhole | M3 |
| Rural | tornado | PR 3 |
| Meadows | flood | PR 3 |
| Village | flood, tornado | PR 3 |
| Desert | quicksand | PR 3 |

- **Timing (E10).** `delay` is 0.1–0.5 s and `intensity` 0.5–1.0:

| Disaster | `duration(params)` | Shortest–longest |
|---|---|---|
| sinkhole | `delay` + 0.8 + 1.0 + 0.6 | 2.5–2.9 s |
| tornado | `delay` + 1.0 + 1.0 + 0.6 | 2.7–3.1 s |
| flood | `delay` + 0.6 + 0.7 / `intensity` + 0.7 | 2.1–3.2 s |
| quicksand | `delay` + 0.6 + 0.75 / `intensity` + 0.6 | 2.05–3.2 s |

  - The shortest is over 2 s without the stop. The longest, with the longest stop (`STOP_SECONDS`, 0.6 s) and a frame each for rounding (M3 P10), is 3.83 s (N53, N54).
  - `test_disasters.gd` checks both bounds for the shortest and longest params of each disaster, and then plays each through the director after a wrong turn, for 10 seeds, from `junction_speed` and from the cap. P3 measured 2.88–3.62 s from the end of the run to `sequence_finished` (§6.5).
  - The flood and the quicksand divide by `max(intensity, DISASTER_INTENSITY_MIN)`, so no intensity can make them longer than this.

### 5.9 The tornado, the flood and the quicksand (PR 3) **Δ IP M4.5**

Each is a scene whose root is its class, a `Node2D` with its `id`, and works like the sinkhole. `play()` moves it to `origin_world`, sets up its particles with `apply_params()` and starts its clock. Its phases come from `_physics_process` deltas (M3 J2), and at `DONE` it emits `finished`, once (N56). Before `play()` (`WAITING`) and during the params' `delay` (`DELAY`), nothing shows (N57, N77). As IP M4.5 says, the params drive the tornado's path, the flood's rise speed and the quicksand's sink speed: the direction sets where the tornado and the water come from, and the intensity how fast the water rises and the car sinks. The intensity also sets the tornado's size and spin and the size of the quicksand's pit.

**The tornado** (`tornado.tscn`, id `tornado`): `Funnel`, a `Node2D` at `z_index` 1 so that it draws over the car (N67), holds the `Shadow` (`z_index` −1, so 0 in all: under the car; N68), the `Body` and the `Core` `Polygon2D`s, and the `Dust` (48 particles). The funnel and everything in it scale with `intensity` (N64).

| Phase | Seconds | What happens |
|---|---|---|
| `APPROACH` | 1.0 | The funnel comes in a straight line to the car from `TORNADO_APPROACH_TILES` (2.5 tiles) against the params' direction, fading in over the first 30 %. The dust whirls, and the camera shakes by `intensity` for 2 s, through `LIFT` (N66) |
| `LIFT` | 1.0 | The car spins `TORNADO_SPIN` (2) turns a second times `intensity` (N63), shrinks to 0.3 (N62) and fades out (N61). The dust whirls (N65) |
| `LEAVE` | 0.6 | The dust stops. The funnel goes on `TORNADO_LEAVE_TILES` (1.5 tiles) along the direction (N58), fading out over the last 30 % |
| `DONE` | `delay` + 2.6 s | `finished` |

- The funnel is `TORNADO_HEIGHT_PX` (72 px) tall, 12 px wide at the ground and 60 px at its top, and the darker core half that. The core sways 5 px either way, 2.5 times a second, on a sine of its clock (N69), by its `position` (N59). The shadow is an `outline()` of 0.35 tiles.

**The flood** (`flood.tscn`, id `flood`): `Water` (`z_index` 0: under the car), and `Surface` and `Spray` (36 particles), both at `z_index` 1 (N74).

| Phase | Seconds | What happens |
|---|---|---|
| `SPREAD` | 0.6 | The water, an `outline()` of `FLOOD_RADIUS` (1.4 tiles), rolls in from that far against the direction (N70), and grows from nothing until it lies around the car, eased with `smoothstep` |
| `RISE` | `rise_seconds()`: 0.7 / `intensity` | The surface, 0.6 of the water's radius, grows from nothing over the car, faster when the flood is stronger (N71). The car takes the water's colour and fades out (N75, N76). The spray flies (N72) |
| `HOLD` | 0.7 | The spray stops (N73); the water stays |
| `DONE` | `delay` + 1.3 s + `rise_seconds()` | `finished` |

**The quicksand** (`quicksand.tscn`, id `quicksand`): `Pit` and `Ripple` (`z_index` 0: under the car), and `Grains` (30 particles, `z_index` 1).

| Phase | Seconds | What happens |
|---|---|---|
| `SPREAD` | 0.6 | The pit, an `outline()` of `QUICKSAND_RADIUS` (0.9 tiles), grows under the car to `intensity` times that, eased with `smoothstep` (N79). Ripples start |
| `SINK` | `sink_seconds()`: 0.75 / `intensity` | The car rocks `QUICKSAND_WOBBLE` (0.3 rad) either way, 3 times a second, less and less until it's level (N81). It shrinks to 0.3 and fades to transparent black, faster when the quicksand is stronger (N82). Sand flies |
| `HOLD` | 0.6 | The sand stops (N83); the pit stays |
| `DONE` | `delay` + 1.2 s + `sink_seconds()` | `finished` |

- A ripple grows from the centre to the pit's edge 1.5 times a second, fading as it grows, from the spread on. It never leaves the pit (N80). The quicksand works without a car (N78).

As with the sinkhole (M3_PLAN.md §5.5), the shapes, the colours and the particles are each disaster's grey-box art, in its script and scene: the funnel's widths, the sway, the shadow, the surface's share, the underwater colour, the ripples, and the car's scale at the end. M5's art replaces them. Their sizes and times are in `Tuning` (§5.10).

### 5.10 Tuning (PR 1)

| Constant | Value | Unit | What | IP |
|---|---|---|---|---|
| `TRANSITION_TILES` | 2 | path tiles | an area's first tiles, whose ground blends with the last area's (§5.4) | M4.3's `transition_tiles` **Δ K14** |
| `AREA_BANNER_SECONDS` | 2.0 | s | how long the area's name shows, not counting pauses | M4.3 |
| `TUNNEL_HEIGHT_PX` | 40.0 | screen px | the tunnel's height | — |
| `TUNNEL_SEE_THROUGH` | 0.2 | — | the tunnel's opacity while the car is near | **Δ K5** |
| `TUNNEL_FADE_NEAR`, `_FAR` | 0.75, 2.5 | tiles | from the run's cells: see-through up to NEAR, opaque from FAR | **Δ K5** |
| `BRIDGE_BANK` | 0.5 | tiles | the dry bank at each end of the river | K7 |
| `RIVER_REACH` | 2.0 | tiles | how far the river reaches each way from the run's centreline. With `BRIDGE_BANK`, at most `min_straight` + 0.5 | K7 |
| `WAVE_SPEED` | 0.6 | tiles/s | how fast the waves drift down the river | — |
| `TORNADO_APPROACH_TILES`, `_LEAVE_TILES` | 2.5, 1.5 | tiles | where the funnel starts, against the params' direction, and how far it goes on | M4.5's path |
| `TORNADO_HEIGHT_PX` | 72.0 | screen px | the funnel's height at intensity 1 | — |
| `TORNADO_APPROACH_SECONDS`, `_LIFT_`, `_LEAVE_` | 1.0, 1.0, 0.6 | s | the tornado's phases (§5.9) | — |
| `TORNADO_SPIN` | 2.0 | turns/s | how fast the car spins at intensity 1 | — |
| `FLOOD_RADIUS` | 1.4 | tiles | the water's radius, and how far away it starts | — |
| `FLOOD_SPREAD_SECONDS`, `_RISE_`, `_HOLD_` | 0.6, 0.7, 0.7 | s | the flood's phases; the rise at intensity 1 | M4.5's rise speed |
| `QUICKSAND_RADIUS` | 0.9 | tiles | the pit at intensity 1 | — |
| `QUICKSAND_SPREAD_SECONDS`, `_SINK_`, `_HOLD_` | 0.6, 0.75, 0.6 | s | the quicksand's phases; the sinking at intensity 1 | M4.5's sink speed |
| `QUICKSAND_WOBBLE`, `_WOBBLE_HZ` | 0.3, 3.0 | rad, Hz | how far and how often the car rocks as it starts to sink | — |

These are first guesses for the grey box. E14 judges them on the Fold4, and M6 tunes them. `test_disasters.gd` and `test_set_pieces_on_the_road.gd` guard the two limits: 2–4 s for every disaster, and the river's bank.

### 5.11 Tests

| File | Tests | PR | What they check |
|---|---|---|---|
| `test_area_schedule.gd` | 10 + 3 | M1–M3, 1 | `validate()` rejects a gap above 25: with straights of 20 and set pieces of 2–6 tiles, gaps of 23–25 pass and the trigger finds every junction, with one tile to spare at 25; 26 and 27 fail, and so does a straight of 25. A schedule can start in any of its areas, with the later turns and set pieces, sharing its areas and leaving itself unchanged. An area that it lacks is an error (E1, E2) |
| `test_hud.gd` | 7 + 4 | M2, M3, 1 | The HUD names the area the car enters for 2 s. A pause keeps the name. A new area replaces it and starts its time again. The end of a run and a new run hide it (E4) |
| `tests/integration/test_area_start.gd` | 4 | 1 | Each run starts by naming its area, after a retry too. `main.gd` reports each new area to `GameState` and `EventBus`. `--area=village` starts every run in the Village, retries too. An unknown area is an error, and the run starts in the City (E2–E4) |
| `tests/sim/test_area_order.gd` | 1 | 1 | The autopilot drives seed 1 to turn 230: Rural at turn 34, Meadows at 100, the Village at 200 and the Desert at 220, one `area_changed` each, and the tunnel and the bridge on the way (E3; N16) |
| `test_greybox_atlas.gd` | 5 + 1 | M1, 2 | The ground atlas has a column for each transition after the areas', with the two areas' colours as its rows (E5) |
| `test_world_renderer.gd` | 5 + 6 | M1, M3, 2 | The first 2 tiles of each new area blend with the last area. Set pieces draw above the ground and below the road. A set piece comes once its run is made, over two batches, and goes with its last tile. A new buffer drops the last run's set pieces, its car and its unfinished run. A set piece without a scene is an error (E5, E6) |
| `test_tunnel.gd` | 6 | 2 | A set piece covers its run's cells. The rock covers the run and a little more across it. The mouth is in the end face that shows, on N and W runs. The tunnel draws over the car, fades while the car is near, and is never redrawn (E7) |
| `test_bridge.gd` | 5 | 2 | The river flows across the run between its banks, on N and W runs. The near railing draws over the car, and the rest under it. The waves drift down the river and never leave it, and each is where its rectangle is. The bridge is never redrawn (E8) |
| `test_car_controller.gd` | 9 + 1 | M2, M3, 2 | The smoke shows through a tunnel. The smoke test's backgrounds now include what the bridge draws under the car (E7, E8) |
| `tests/sim/test_set_pieces_on_the_road.gd` | 2 | 2 | The autopilot drives seed 1 through the tunnel and over the bridge, each drawn while the car is on it and gone after. Over 1,010 rivers, on 10 seeds of the game's schedule and of one with a bridge at every turn, no other road comes within `BRIDGE_BANK` (E9) |
| `tests/integration/test_retry.gd` | 6 | M3, 2 | Also: the world has the run's car, and a retry gives it the next (E6) |
| `test_disasters.gd` | 9 | 3 | Each area has its pool. Each of the four disasters shows nothing until its delay is over. It finishes once, after its `duration()`, with the car where it stopped and out of sight, and also without a car or a camera. It seeds its particles from its params and scales them, and redraws no polygon and not the car. An `outline()` is a circle on the ground. With the stop, each takes 2–4 s, and after a wrong turn the director plays each in 2–4 s, for 10 seeds from `junction_speed` and from the cap (E10, E12) |
| `test_tornado.gd` | 7 | 3 | It comes along its direction, carries the car off and goes on. The funnel moves in a straight line, and fades in and out. The car spins, shrinks and fades as it lifts. A stronger tornado is bigger and spins the car faster. The dust whirls while it comes and lifts the car. It shakes the camera as it comes. The funnel draws over the car, and its shadow under it (E11) |
| `test_flood.gd` | 5 | 3 | The water rolls in along its direction and spreads around the car; then it rises over the car, faster when the flood is stronger. The spray flies while it rises. The water lies under the car, and its surface over it (E11) |
| `test_quicksand.gd` | 5 | 3 | The pit spreads under the car, as big as the quicksand is strong. Ripples grow and fade within the pit. The car rocks less and less as it sinks, faster when the quicksand is stronger. Sand flies while the car sinks (E11) |
| `tests/integration/test_disaster_pools.gd` | 2 | 3 | In each area, started with `--area` on seed 1, a wrong exit at the third junction plays a disaster from the area's pool, and game over comes 2–4 s after the turn. The Village plays both of its disasters within 8 seeds (E12) |

- 201 tests become 262: 61 are new, 12 in PR 1, 21 in PR 2 and 28 in PR 3. None is removed. `test_retry.gd` gets two asserts, and a comment changes in `test_area_schedule.gd`'s pool test and in `tests/helpers/main_scene.gd`.
- `tests/helpers/road_fixtures.gd` adds two schedules: `set_piece_schedule()`, for the renderer's tests, and `bridge_every_turn()`. `tests/helpers/disaster_fixtures.gd` gives the disaster tests their scenes, params, car and camera, and what they check: what shows, the polygons and particles, the `z_index` that each part draws at, and the director's time after a wrong turn.
- `test_disaster_pools.gd` runs the main scene in a 360×640 `SubViewport` with `main_scene.gd` and M3's `wrong_turn_pilot.gd`, as `test_wrong_turn_disaster.gd` does.
- Like M3's, the new timings come from physics deltas, so GUT's `simulate()` runs a disaster, 2–4 s, in a fraction of a second.
- M4 adds no `RefCounted`. The set pieces and the disasters are nodes, with unit tests of their own (IP §1.3).

---

## 6. Verification

### 6.1 Local checks

The commands are those of `AGENTS.md` §4: `lint.sh`, `import.sh`, `check_scripts.sh`, `run_tests.sh` and `smoke.sh` in `tools/ci/`. Each PR state was built with §4's commands from `m4/prototype` (49c24e1) on top of `main` (5c1e0ba), and all five checks passed on it:

| State | `check_scripts` | GUT tests | Asserts | GUT time | `smoke.sh` prints |
|---|---|---|---|---|---|
| M3 (`main`, 5c1e0ba) | 66 | 201 | 144,632 | 17.3–17.8 s | `autopilot: tile 165, turns 35, area rural` |
| PR 1 | 68 | 213 | 144,721 | 16.9–17.8 s | the same |
| PR 2 | 74 | 234 | 144,916 | 18.2–19.9 s | the same |
| PR 3 | 83 | 262 | 146,061 | 19.5–21.4 s | the same |

PR 3's state is the prototype's tree. Each GUT time is the range of two runs: for the PRs, of the states built from 21fd140 and from 49c24e1, which changes only tests (§6.3). This machine has 2 CPUs, and its load moves the times by up to 2 s. The smoke line is M3's: in its 60 s the autopilot takes the tunnel into Rural at turn 34, and now the tunnel is drawn and the HUD names Rural (E13). In every state:
- `lint.sh` reports `Godot 4.7.2 is pinned consistently` and `Actions storage: no caches, artifacts kept 1 day (5 files checked)`;
- `smoke.sh` also prints `grey box: tilesets built in 61–68 ms`, against M3's 60–67 ms (M3_PLAN.md §6.6), so the transitions' ground columns cost little;
- `git status` is clean after the checks, so `import.sh` creates no files (§4.1 step 4).

### 6.2 Negative cases

For each case, make the temporary change in the PR state listed, run the checks named under "Expected", then revert. A script made each change on its PR's state and again on PR 3's, so a case of PR 1 or 2 also shows which later tests catch it. Every case fails at least one check in both states. "GUT fails" means `run_tests.sh`, which also fails on error lines and leaks; no case left an error line or a leak that a failing test didn't report. N44 and N69 run `lint.sh` too.

The script first ran all 83 on the prototype at 49a8ac1, where 80 failed as they should, and a0c9199 fixed the tests for the other three. Then it ran them on the PR states built from 21fd140, and again on those of §6.1, built from 49c24e1. Both times, every case failed the checks that the table gives it, in both states; only N44's GUT test varies (below).

Three cases needed work before they failed as they should:
- **N29** passed at first: the test gave the world its car only after the set pieces were added, so `set_car()` gave it to them all. a0c9199 gives the world the car before the run is made, and checks that the tunnel has it once it's added.
- **N37** passed at first: the rock test took its expected width from `Tunnel.HALF_WIDTH`, so it passed at any width. a0c9199 also requires the rock to be 1.05–1.5 tiles across.
- **N52** passed at first: no test looked at `outline()`. a0c9199 adds `test_an_outline_is_a_circle_of_its_radius_on_the_ground`.

Two more need a note:
- **N44** drifts the waves by the global RNG, so whether `test_each_wave_is_where_its_rectangle_is` fails depends on the draws: it failed in 3 of its 5 runs. `lint.sh` fails every time.
- **N69** fails only `lint.sh`. The core's sway is grey-box art, and a test checks only that it doesn't redraw the core (N59).

N16 and N47 break files that M4 doesn't change, `areas/schedule.tres` and `disaster_director.gd`. M1's and M3's tests catch them, and so do M4's.

One rule can't fail a check here: `--area` works in every build (Q5). GUT runs a debug build, where an `--area` that only debug builds read works too, so a release build checks it (§6.4).

"With IP's design" says what happens with the same problem if IP is followed as written:
- **Fails ✓:** one of IP's M4 tests, a test that `main` already has, or IP §5.3's lint rule, fails too.
- **Not tested:** none of IP's tests would catch it.
- **Not specified:** IP doesn't say which behaviour is right.
- **IP's design:** the change is what IP describes.
- **Not in IP:** IP doesn't have the feature.

| # | PR | Temporary change | Expected | With IP's design |
|---|---|---|---|---|
| N1 | 1 | `validate()` doesn't check how far the next junction can be | GUT fails: `test_validate_allows_only_schedules_whose_next_junction_is_in_the_buffer` | IP's design (K1) |
| N2 | 1 | `gap()` leaves out the junction's own tile | GUT fails: `test_validate_allows_only_schedules_whose_next_junction_is_in_the_buffer` | Not in IP (K1) |
| N3 | 1 | `validate()` also rejects a gap of exactly `BUFFER_REFILL_AT`: `>=` for `>` | GUT fails: `test_validate_allows_only_schedules_whose_next_junction_is_in_the_buffer` | Not in IP (K1) |
| N4 | 1 | `starting_at()` keeps the set piece that leads into the first area | GUT fails: `test_a_schedule_can_start_in_any_of_its_areas`. On PR 3, also `test_a_wrong_turn_in_each_area_plays_a_disaster_from_its_pool` | Not in IP (K10) |
| N5 | 1 | `starting_at()` keeps the entries' turns | GUT fails: `test_the_area_argument_starts_every_run_in_that_area`, `test_a_schedule_can_start_in_any_of_its_areas`. On PR 3, also `test_a_wrong_turn_in_each_area_plays_a_disaster_from_its_pool`, `test_the_village_plays_both_of_its_disasters` | Not in IP (K10) |
| N6 | 1 | `starting_at()` an area that the schedule lacks is no error | GUT fails: `test_an_unknown_area_argument_starts_in_the_first_area`, `test_a_schedule_cannot_start_in_an_area_it_lacks` | Not in IP (K10) |
| N7 | 1 | The area's name counts down while the game is paused | GUT fails: `test_the_area_name_waits_while_the_game_is_paused` | Not specified (K16) |
| N8 | 1 | The area's name never hides | GUT fails: `test_it_names_the_area_the_car_enters_for_a_while`, `test_the_area_name_waits_while_the_game_is_paused`, `test_a_new_area_replaces_the_name_and_starts_its_time_again` | Not tested |
| N9 | 1 | The end of a run leaves the area's name | GUT fails: `test_the_end_of_a_run_and_a_new_run_hide_the_area_name` | Not specified (K16) |
| N10 | 1 | A new run leaves the last run's area name | GUT fails: `test_the_end_of_a_run_and_a_new_run_hide_the_area_name` | Not specified (K16) |
| N11 | 1 | A new area adds 2 s to the time left, instead of starting it again | GUT fails: `test_a_new_area_replaces_the_name_and_starts_its_time_again` | Not specified (K16) |
| N12 | 1 | The HUD shows the area's id, not its name | GUT fails 5 tests: `test_each_run_starts_by_naming_its_area`, `test_main_reports_each_new_area_of_the_car`, `test_the_area_argument_starts_every_run_in_that_area`, `test_it_names_the_area_the_car_enters_for_a_while`, `test_a_new_area_replaces_the_name_and_starts_its_time_again` | Not tested |
| N13 | 1 | A run doesn't report the area it starts in, as on `main`: `_start_run()` sets `GameState.area_id` itself | GUT fails: `test_each_run_starts_by_naming_its_area`, `test_main_reports_each_new_area_of_the_car`, `test_the_area_argument_starts_every_run_in_that_area` | IP's design (K4) |
| N14 | 1 | `main.gd` ignores `--area` | GUT fails: `test_the_area_argument_starts_every_run_in_that_area`, `test_an_unknown_area_argument_starts_in_the_first_area`. On PR 3, also `test_a_wrong_turn_in_each_area_plays_a_disaster_from_its_pool`, `test_the_village_plays_both_of_its_disasters` | Not in IP (K10) |
| N15 | 1 | `main.gd` doesn't relay the car's new areas | GUT fails: `test_main_reports_each_new_area_of_the_car` | Fails ✓: IP's order test, if it listens to `GameState` (K15) |
| N16 | 1 | The schedule swaps the tunnel and the bridge | GUT fails: `test_the_autopilot_meets_the_areas_and_set_pieces_in_order`, `test_areas_and_set_pieces_switch_at_34_100_200_and_220`, `test_a_schedule_can_start_in_any_of_its_areas`. On PR 3, also `test_the_autopilot_drives_through_the_tunnel_and_over_the_bridge` | Fails ✓: M1's `test_areas_and_set_pieces_switch_at_34_100_200_and_220` |
| N17 | 2 | A transition's rows swap its two areas' colours | GUT fails: `test_ground_tileset_has_a_column_for_each_transition`, `test_the_first_tiles_of_an_area_blend_its_ground_with_the_last_one` | Not in IP: a transition TileSet (K14) |
| N18 | 2 | No ground transitions: the loop over the tiles before runs over none | GUT fails: `test_the_first_tiles_of_an_area_blend_its_ground_with_the_last_one` | Not tested |
| N19 | 2 | A transition covers one tile too many | GUT fails: `test_the_first_tiles_of_an_area_blend_its_ground_with_the_last_one` | Not tested (K14) |
| N20 | 2 | A transition takes the column of the reverse pair, from the new area into the last | GUT fails: `test_the_first_tiles_of_an_area_blend_its_ground_with_the_last_one` | Not in IP (K14) |
| N21 | 2 | A set piece is added at the end of each batch, even if its run isn't finished | GUT fails: `test_a_set_piece_comes_once_its_run_is_made_and_goes_with_its_last_tile` | Not specified (K6) |
| N22 | 2 | Each tile of a run gets a set piece of its own | GUT fails: `test_the_autopilot_drives_through_the_tunnel_and_over_the_bridge`, `test_a_set_piece_comes_once_its_run_is_made_and_goes_with_its_last_tile`, `test_a_new_buffer_drops_the_last_runs_set_pieces_and_car` | Not tested |
| N23 | 2 | A set piece is freed with its run's first tile | GUT fails: `test_a_set_piece_comes_once_its_run_is_made_and_goes_with_its_last_tile` | Not tested |
| N24 | 2 | `bind()` forgets the last run's set pieces without freeing them | GUT fails: `test_a_new_buffer_drops_the_last_runs_set_pieces_and_car` | Not specified (K6) |
| N25 | 2 | `bind()` keeps the last run's car | GUT fails: `test_a_new_buffer_drops_the_last_runs_set_pieces_and_car` | Not in IP (K5) |
| N26 | 2 | `bind()` keeps the tiles of the last run's unfinished set piece | GUT fails: `test_a_new_buffer_drops_the_last_runs_unfinished_set_piece` | Not specified (K6) |
| N27 | 2 | A set piece without a scene is no error | GUT fails: `test_a_set_piece_without_a_scene_is_an_error` | Not in IP: a `PackedScene` (K12) |
| N28 | 2 | `set_car()` doesn't give the car to the set pieces already there | GUT fails: `test_a_new_buffer_drops_the_last_runs_set_pieces_and_car` | Not in IP (K5) |
| N29 | 2 | A new set piece doesn't get the car | GUT fails: `test_a_set_piece_comes_once_its_run_is_made_and_goes_with_its_last_tile` | Not in IP (K5) |
| N30 | 2 | `main.gd` doesn't give the world the car | GUT fails: `test_retry_starts_the_next_run_afresh` | Not in IP (K5) |
| N31 | 2 | `RIVER_REACH` is 2.5 tiles, so a river can reach other road | GUT fails: `test_rivers_keep_a_bank_clear_of_every_other_road` | Not specified (K7) |
| N32 | 2 | The river runs along the road, not across it | GUT fails: `test_rivers_keep_a_bank_clear_of_every_other_road`, `test_the_river_flows_across_the_run_between_its_banks`, `test_the_waves_drift_down_the_river_and_never_leave_it` | Not tested |
| N33 | 2 | The waves and the railings take the run's direction for the river's | GUT fails: `test_the_river_flows_across_the_run_between_its_banks`, `test_the_near_railing_draws_over_the_car_and_the_rest_under_it`, `test_the_waves_drift_down_the_river_and_never_leave_it` | Not tested |
| N34 | 2 | The waves' room down the river doesn't leave out a wave's length | GUT fails: `test_the_waves_drift_down_the_river_and_never_leave_it` | Not specified |
| N35 | 2 | The waves move by their `offset`, which redraws them | GUT fails: `test_each_wave_is_where_its_rectangle_is`, `test_the_bridge_is_never_redrawn` | Not in IP: a shader (K9) |
| N36 | 2 | The near railing has no `z_index`, so it draws under the car | GUT fails: `test_the_near_railing_draws_over_the_car_and_the_rest_under_it`, `test_the_smoke_shows_over_everything_the_grey_box_draws`, `test_the_smoke_shows_through_a_tunnel` | Not specified (K8) |
| N37 | 2 | The tunnel's rock is only a tile wide: `HALF_WIDTH` 0.5 | GUT fails: `test_the_rock_covers_the_run_and_a_little_more_across_it` | Not specified |
| N38 | 2 | The mouth is in the end face that doesn't show | GUT fails: `test_the_mouth_is_in_the_end_face_that_shows` | Not specified |
| N39 | 2 | The tunnel has no `z_index`, so it draws under the car | GUT fails: `test_the_tunnel_draws_over_the_car` | Not tested (K8) |
| N40 | 2 | The tunnel never fades | GUT fails: `test_the_tunnel_fades_while_the_car_is_near`, `test_the_tunnel_is_never_redrawn` | IP's design: an occluding roof (K5) |
| N41 | 2 | The tunnel also fades its roof by its `color`, which redraws it | GUT fails: `test_the_tunnel_is_never_redrawn` | Not in IP (K5, K9) |
| N42 | 2 | `TUNNEL_SEE_THROUGH` is 0.35 | GUT fails: `test_the_smoke_shows_through_a_tunnel` | Not in IP (K5) |
| N43 | 2 | `SetPieces` comes after `RoadLayer` in `world.tscn`, so set pieces draw over the road | GUT fails: `test_disasters_draw_above_the_road_and_below_the_car`, `test_set_pieces_draw_above_the_ground_and_below_the_road` | IP's design: in `Props`, after `RoadLayer` (K2) |
| N44 | 2 | The waves drift by the global RNG: `_time += delta * randf_range(0.9, 1.1)` | `lint.sh` fails: `Global RNG in gameplay code; use a seeded RandomNumberGenerator stream (§5.3)`. GUT fails `test_each_wave_is_where_its_rectangle_is` in some runs, as the draws decide: in 3 of its 5 runs | Fails ✓: IP §5.3's lint rule |
| N45 | 3 | Rural's pool is the sinkhole, as in M3 | GUT fails: `test_a_wrong_turn_in_each_area_plays_a_disaster_from_its_pool`, `test_each_area_has_its_pool_of_disasters` | Fails ✓: IP's pool test |
| N46 | 3 | The Village's pool is only the flood | GUT fails: `test_the_village_plays_both_of_its_disasters`, `test_each_area_has_its_pool_of_disasters` | Not tested: a pool that lacks a disaster passes IP's pool test |
| N47 | 3 | The director always plays the first disaster of a pool | GUT fails: `test_the_village_plays_both_of_its_disasters`, `test_pick_draws_every_scene_of_the_pool_with_the_stream` | Fails ✓: M3's `test_pick_draws_every_scene_of_the_pool_with_the_stream` |
| N48 | 3 | `apply_params()` doesn't fix the particles' seed | GUT fails: `test_each_seeds_its_particles_from_its_params_and_scales_them`, `test_the_debris_follows_its_params_and_flies_while_the_hole_opens` | Fails ✓: M3's sinkhole test |
| N49 | 3 | `apply_params()` doesn't scale the particles' speed by the intensity | GUT fails: `test_each_seeds_its_particles_from_its_params_and_scales_them`, `test_the_debris_follows_its_params_and_flies_while_the_hole_opens` | Fails ✓: M3's sinkhole test |
| N50 | 3 | `apply_params()` doesn't scale the particles' size | GUT fails: `test_each_seeds_its_particles_from_its_params_and_scales_them`, `test_the_debris_follows_its_params_and_flies_while_the_hole_opens` | Fails ✓: M3's sinkhole test |
| N51 | 3 | The sinkhole doesn't apply its params to its debris | GUT fails: `test_each_seeds_its_particles_from_its_params_and_scales_them`, `test_the_debris_follows_its_params_and_flies_while_the_hole_opens` | Fails ✓: M3's sinkhole test |
| N52 | 3 | `outline()` is half as big | GUT fails: `test_an_outline_is_a_circle_of_its_radius_on_the_ground` | Not tested |
| N53 | 3 | `TORNADO_LEAVE_SECONDS` is 1.5 s, so the longest tornado takes over 4 s | GUT fails: `test_a_wrong_turn_in_each_area_plays_a_disaster_from_its_pool`, `test_the_village_plays_both_of_its_disasters`, `test_with_the_stop_each_takes_2_to_4_seconds`, `test_after_a_wrong_turn_the_director_plays_each_in_2_to_4_seconds` | Not tested (K20) |
| N54 | 3 | `FLOOD_HOLD_SECONDS` is 0.1 s, so the shortest flood takes under 2 s | GUT fails: `test_with_the_stop_each_takes_2_to_4_seconds` | Not tested (K20) |
| N55 | 3 | The tornado's `duration()` leaves out its delay | GUT fails: `test_each_finishes_once_after_its_duration_with_the_car_out_of_sight` | Not in IP (K20) |
| N56 | 3 | The tornado emits `finished` on every frame after its end | GUT fails 5 tests: `test_each_finishes_once_after_its_duration_with_the_car_out_of_sight`, `test_each_finishes_without_a_car_or_a_camera`, `test_it_comes_along_its_direction_carries_the_car_off_and_goes_on`, `test_the_funnel_moves_straight_and_fades_in_and_out`, `test_the_dust_whirls_while_it_comes_and_lifts_the_car` | Not tested |
| N57 | 3 | The funnel shows during the delay | GUT fails: `test_each_shows_nothing_until_its_delay_is_over`, `test_the_funnel_moves_straight_and_fades_in_and_out` | Not tested |
| N58 | 3 | The tornado leaves back the way it came, against its direction | GUT fails: `test_it_comes_along_its_direction_carries_the_car_off_and_goes_on` | Not tested |
| N59 | 3 | The core sways by its `offset`, which redraws it | GUT fails: `test_none_redraws_a_polygon_or_the_car` | Not specified (K9) |
| N60 | 3 | The tornado moves the car up a pixel each frame | GUT fails: `test_each_finishes_once_after_its_duration_with_the_car_out_of_sight` | Not specified (K19) |
| N61 | 3 | The tornado only half hides the car | GUT fails: `test_each_finishes_once_after_its_duration_with_the_car_out_of_sight`, `test_it_comes_along_its_direction_carries_the_car_off_and_goes_on` | Not tested |
| N62 | 3 | The car doesn't shrink as the tornado lifts it | GUT fails: `test_it_comes_along_its_direction_carries_the_car_off_and_goes_on`, `test_the_car_spins_shrinks_and_fades_as_it_lifts` | Not specified |
| N63 | 3 | The spin doesn't grow with the intensity | GUT fails: `test_a_stronger_tornado_is_bigger_and_spins_the_car_faster` | Not specified |
| N64 | 3 | The funnel's size doesn't grow with the intensity | GUT fails: `test_a_stronger_tornado_is_bigger_and_spins_the_car_faster` | Not specified |
| N65 | 3 | The dust stops as the lift starts | GUT fails: `test_the_dust_whirls_while_it_comes_and_lifts_the_car` | Not specified |
| N66 | 3 | The tornado doesn't shake the camera | GUT fails: `test_it_shakes_the_camera_as_it_comes` | Not specified |
| N67 | 3 | The funnel has no `z_index`, so it draws under the car | GUT fails: `test_the_funnel_draws_over_the_car_and_its_shadow_under` | Not specified (K8) |
| N68 | 3 | The shadow has no `z_index`, so it draws with the funnel, over the car | GUT fails: `test_the_funnel_draws_over_the_car_and_its_shadow_under` | Not specified (K8) |
| N69 | 3 | The core sways by the global RNG: `randf_range(-SWAY_PX, SWAY_PX)` | `lint.sh` fails: `Global RNG in gameplay code; use a seeded RandomNumberGenerator stream (§5.3)` | Fails ✓: IP §5.3's lint rule |
| N70 | 3 | The water rolls in against its direction | GUT fails: `test_the_water_rolls_in_along_its_direction_and_spreads_around_the_car` | Not specified |
| N71 | 3 | The flood rises as fast whatever its intensity | GUT fails: `test_a_stronger_flood_rises_faster` | Not tested |
| N72 | 3 | The spray starts as the water rolls in | GUT fails: `test_the_spray_flies_while_it_rises` | Not specified |
| N73 | 3 | The spray never stops | GUT fails: `test_the_spray_flies_while_it_rises` | Not specified |
| N74 | 3 | The surface has no `z_index`, so it draws under the car | GUT fails: `test_the_water_lies_under_the_car_and_its_surface_over_it` | Not specified (K8) |
| N75 | 3 | The car under water still half shows | GUT fails: `test_each_finishes_once_after_its_duration_with_the_car_out_of_sight` | Not tested |
| N76 | 3 | The car fades under water without taking its colour | GUT fails: `test_then_it_rises_over_the_car` | Not specified |
| N77 | 3 | The quicksand ignores its delay | GUT fails: `test_each_shows_nothing_until_its_delay_is_over`, `test_each_finishes_once_after_its_duration_with_the_car_out_of_sight`, `test_the_sand_flies_while_the_car_sinks` | Not tested |
| N78 | 3 | The quicksand needs a car | GUT fails: `test_each_finishes_without_a_car_or_a_camera`, `test_ripples_grow_and_fade_within_the_pit`, `test_stronger_quicksand_sinks_the_car_faster`, `test_the_sand_flies_while_the_car_sinks` | Not in IP: M3's contract (M3_PLAN.md §5.5) |
| N79 | 3 | The pit's size doesn't grow with the intensity | GUT fails: `test_the_pit_spreads_under_the_car_as_big_as_the_quicksand_is_strong` | Not specified |
| N80 | 3 | The ripple grows beyond the pit | GUT fails: `test_ripples_grow_and_fade_within_the_pit` | Not specified |
| N81 | 3 | The car rocks as much until it has sunk | GUT fails: `test_the_car_rocks_less_and_less_as_it_sinks` | Not specified |
| N82 | 3 | The quicksand sinks the car as fast whatever its intensity | GUT fails: `test_stronger_quicksand_sinks_the_car_faster` | Not tested |
| N83 | 3 | The sand never stops flying | GUT fails: `test_the_sand_flies_while_the_car_sinks` | Not specified |

### 6.3 Editor warnings

None of the five checks reports GDScript warnings, so, as in M2 and M3 (M2_PLAN.md §6.3), a probe asked the editor's language server for them. On each PR state it reports 8 warnings: the same 8 as on `main`, all in M1's code (M2 H29). `ui/main.gd`'s INTEGER_DIVISION, the `grey box:` line, moves from line 33 to 37.

On 21fd140 it reported 14 in 83 scripts. The 6 new ones were in M4's tests, and 49c24e1 clears them:
- SHADOWED_VARIABLE: `set_piece_schedule()`'s local `schedule` hid the helper `schedule()` in `road_fixtures.gd` (`AGENTS.md` §3). It is `built`.
- INTEGER_DIVISION, 5 times: the middle of a tile in `test_greybox_atlas.gd` (3) and `test_world_renderer.gd`, and half the banner's frames in `test_hud.gd`. Each division is meant, so each test that keeps one has `@warning_ignore("integer_division")`, once. The transition test lists its four tiles by their atlas coordinates instead of working them out.

The probe isn't committed (§9).

### 6.4 Verified only in CI or on devices

| Check | PR | Result |
|---|---|---|
| The five checks on GitHub, and the `test` job's time against M3's 78–90 s | 1–3 | To do. On the prototype, all five passed, and `test` took 82 s (§6.5) |
| The Web build in headed Chrome and in Firefox (E14) | 3 | To do. Headless Chrome ran every area, the tunnel and the bridge, with no errors (§6.5) |
| The debug APK on the Galaxy Z Fold4, folded and unfolded: the City, the tunnel and Rural (E14) | 3 | To do (owner, §7) |
| The other areas in the Fold4's Chrome, with §4's Web copy over `adb reverse` (E14, Q6) | 3 | To do (owner, §7) |
| `--area` in a release build: GUT runs a debug build (Q5, §6.2) | 1 | Done on the prototype: the Web export is a release build (`ci.yml:65`), and §4's copy started each area (§6.5) |
| https://pompomon.github.io/roadgame/ runs the game with M4 after the merge | 3 | To do |

### 6.5 Measurements (prototype, local)

The probes ran on Godot 4.7.2, headless, in scratch scripts that aren't committed. The findings cite them.

| # | Probe | Result | Used by |
|---|---|---|---|
| P1 | M2 H31's schedule on `main` (5c1e0ba): two areas alternate every second turn, with straights of 15–20 tiles and a tunnel at each change. The autopilot drives 300 turns on each of 20 seeds, with tunnels of 4, 5 and 6 tiles: gaps of 25, 26 and 27 | 25 and 26 found every junction. The next junction was the buffer's last tile in 486 steps at 26, and never at 25. At 27, the trigger stopped judging on 12 of the 20 seeds, at turns 20–280, with `ERROR: JunctionTrigger: no junction after path index …`. With straights of exactly 20, 27 lost none: the junctions keep step with the buffer's refills, as M2 found | K1, §5.2; N1–N3 |
| P2 | The autopilot with seed 12345: when it reaches each set piece and area, from the City and with `--area` | From the City: the tunnel at 56.45 s, Rural 58.32 s, the bridge 179.92 s, Meadows 181.38 s, the Village 365.47 s and the Desert 397.15 s. From Rural: the bridge 124.68 s, Meadows 126.15 s, the Village 311.28 s and the Desert 342.73 s. From Meadows: the Village 188.10 s and the Desert 221.17 s. From the Village: the Desert 34.83 s | K10, Q6; §4, PR 3 step 3 |
| P3 | The director after a wrong turn, with each disaster, on 10 seeds, from `junction_speed` (2.0 tiles/s) and from the cap: the time from the end of the run to `sequence_finished` | The sinkhole 3.07–3.33 s from `junction_speed` and 3.15–3.42 s from the cap; the tornado 3.27–3.53 and 3.35–3.62 s; the flood 2.93–3.45 and 3.02–3.53 s; the quicksand 2.88–3.43 and 2.97–3.52 s | K20, §5.8 |
| P4 | Can user arguments reach the APK or the Web build? | No. Godot's `platform/android/java/lib/src/main/java/org/godotengine/godot/GodotActivity.kt` strips `command_line_params` from the intents of exported activities (`sanitizeLaunchIntent`, :99–107), and reads them only for activities that aren't exported (:113–121). The game's launcher activity is exported. The Web export's `index.html` starts the engine with `"args":[]` | Q6; §4, PR 3 step 3 |
| P5 | Which disaster the Village plays on a seed: the director's first pick from its pool | The tornado on seeds 1, 3, 4, 5 and 6; the flood on 0, 2, 7, 8 and 12345 | §5.8; §4, PR 3 step 3; N46, N47 |

- **M2's H31.** M2 found that 5-tile tunnels (26) lost junctions on 3 of 5 seeds (M2_PLAN.md §6.5). That ran on M2's prototype, whose `CarSim.step()` let the trigger look before `_update_path()` moved the buffer on (`car_sim.gd:77, 81` at db1506d). 684a976, in M2 PR 2 (#26), updates the path first, which gives the trigger one more tile: on `main`, 26 is found, and 27 is the first gap that can be lost (P1). M4's limit of 25 holds in either order (§5.2).
- **The end's timing.** Without the stop, the new disasters take 2.05–3.2 s (§5.8). With it, P3 measured 2.88–3.62 s from the end of the run to `sequence_finished`, inside IP's 2–4 s. The longest that §5.8's values allow is 3.83 s (N53, N54).
- **Web.** The prototype's Web export from run 42620851884 (21fd140) was served locally as §4's copy that takes `?arg=` (PR 3 step 3), and played in headless Chrome 156 with Playwright. Since 21fd140 only tests have changed (49c24e1). There is no GPU here, so Chrome drew with SwiftShader at 10–15 frames a second: the sessions say nothing about speed. In eight sessions:
  - Six started a run with no input: the City, Rural, Meadows, the Village and the Desert with seed 1, and the Village with seed 12345. In each, the HUD named the area, the car missed the first junction, the area's disaster played (the sinkhole, the tornado, the flood, the tornado, the quicksand and the flood), and the game-over screen said "You missed the turn!", with the area.
  - With the autopilot and seed 12345, from the City, the screenshots from 50 to 64 s show the tunnel's rock with the car through it, the ground's blend and "Rural" for 2 s. From Rural, those from 118 to 132 s show the river and its waves, the deck, the blend and "Meadows".
  - Each session logged Godot's 3 start-up lines and one `grey box:` line, and nothing else: no errors, no warnings, and none of the `GPU stall due to ReadPixels` notes that M3's build logged (M3_PLAN.md §6.5).
- **Tilesets.** 61–68 ms headless, against M3's 60–67 ms (§6.1), and 220–317 ms in headless Chrome.
- **CI.** One manual run on the prototype, 42620851884 on 21fd140, with `upload-builds`, passed all five jobs: `lint` 17 s, `test` 82 s, `export-web` 59 s, `export-android` 72 s (APK) and 180 s (AAB). M3's `test` job took 78–90 s.

### 6.6 Measurements (PRs)

Filled in while the PRs are reviewed, as M3_PLAN.md §6.6 was: each PR's counts on its final head, the negative cases again, its CI times, and the E14 results.

---

## 7. Owner actions

These need the repository owner. The current state was read with `gh api` on 2026-11-09: ruleset "Test" (26672445) requires `lint`, `test`, `export-web` and both `export-android` checks, and "Copilot" (26740665) has only its review rule. The repository doesn't delete merged branches by itself. M4 changes no settings.

| When | Action | How |
|---|---|---|
| Now | Answer Q1–Q9, or accept the defaults | A comment on this plan's PR. Without an answer, the PRs follow the defaults |
| Now | Merge this plan's PR | Squash-merge it into `main`. PR 1 branches from `main` with this plan, and PR 3's tree check leaves the plan out (§4, PR 3 step 2) |
| Before PR 3 merges | The E14 checks on the Galaxy Z Fold4: the debug APK of PR 3's final head, and the other areas in the Fold4's Chrome. An agent does the Web checks in Chrome and Firefox | §4, PR 3 step 3 |
| To land M4 | Merge PRs 1, 2 and 3, in that order, each once its base is `main` and it is updated as in §4.5 step 4 | §4.5 |
| Optional | Delete each PR's branch after it merges, so GitHub retargets the next PR by itself. Delete `m4/prototype` once PR 3 has merged | The **Delete branch** button on the merged PR (§4.5 step 5); `git push origin --delete m4/prototype` |

---

## 8. M4 risks

| Risk | Impact | Mitigation |
|---|---|---|
| The gap's limit rests on when `RoadBuffer` refills and when `JunctionTrigger` looks (K1) | A change to either can let a schedule that passes `validate()` lose junctions, and the car drives through junctions that nobody judges | `validate()` reads `BUFFER_REFILL_AT`, and leaves a tile for the order of `CarSim.step()` (P1). `test_area_schedule.gd` drives the trigger at the limit, where it must find every junction (N1–N3). The game's gaps are 6–14 |
| §5.10's sizes and times are first guesses | The set pieces or the disasters look wrong, or the end drags | E14 judges them on the Fold4. They are all in `config/tuning.gd`, and M6 tunes them. `test_disasters.gd` keeps every disaster within 2–4 s (N53, N54), and `test_set_pieces_on_the_road.gd` keeps the river off other roads (N31) |
| The APK can't start in another area (P4) | The Fold4's APK shows only the City, the tunnel and Rural | The other areas run in the Fold4's Chrome (Q6). They differ from the City only in data and in their disasters' scenes, and the Web build has the same Compatibility renderer, through WebGL 2 |
| A `Polygon2D` redrawn on the Web (K9) | WebGL errors while the waves drift, the tunnel fades or the core sways | No polygon changes after its first draw: the parts move, scale and fade by their transforms and `self_modulate` (§5.5–§5.9). Tests check every set piece and disaster (N35, N41, N59). Headless Chrome logged no errors (§6.5), and E14 checks headed Chrome and Firefox |
| The disasters' particles: 48 in the tornado, 36 in the flood and 30 in the quicksand, against the sinkhole's 40 and the smoke's 20 | Dropped frames on the Fold4 or in browsers during the end | One disaster plays at a time. E14 watches for it, and the amounts are in the scenes |
| A set piece outlives its run, or a retry keeps one (E6) | Set pieces pile up as the car drives, or one shows in the next run | `test_world_renderer.gd` checks that each goes with its last tile and that `bind()` frees them (N21–N26). `run_tests.sh` fails on leaks |
| The Village's disaster depends on the seed (P5) | A check that expects one of its two disasters sees the other | §4's steps name the seeds: 1 for the tornado and 12345 for the flood. `test_disaster_pools.gd` plays both (N46, N47) |
| `push_error` doesn't stop a release build | A broken rule goes unnoticed in the game | Every CI script fails on error lines (M0 F10), and a test covers each rule (§6.2) |
| Squash merges of stacked PRs. `ui/main.gd` is the one file that two PRs change | Conflicts, or a lost review fix | §4.5: merge PR n's final branch first, then check `git diff --name-only origin/main`. Fix a file only on the branch of the PR that owns it; `ui/main.gd` on PR 1's, unless the fix is to PR 2's line |
| The PRs drift from the prototype after reviews | The prototype stops being a reliable reference | PR 3's tree check lists every difference, which must be §4.6's files (§4, PR 3 step 2) |
| `m4/prototype` disappears before PR 3 merges | The PRs can't check their files out | Keep it until PR 3 merges (§7) |
| GUT's update check hits GitHub's rate limit in an editor run on CI | A red `export-*` job | Re-run the failed jobs (`AGENTS.md` §10) |
| M4 adds 61 tests, and some drive the autopilot or the main scene for minutes of game time | A slower `test` job | They add 2–4 s locally (§6.1). On the prototype, `test` took 82 s, within M3's 78–90 s (§6.5) |

---

## 9. Notes for later milestones

- **M5:**
  - M5.1's art: the areas' palettes, road tilesets and ground variants, transition tiles instead of the checker, the water shader and the `CanvasModulate` (K3, K14, K18, Q4). It replaces the grey-box art of the set pieces and the disasters, which is in their scripts and scenes (§5.6–§5.9). A disaster keeps M3's contract with §5.8's rules, and its `duration()`; a set piece keeps `SetPiece`'s interface (§5.5).
  - Until Godot 4.8, art still mustn't redraw a `Polygon2D` (K9, godotengine/godot#124726).
  - M5.2's `PropPool` comes with `PropDef`, the props stream and the density test (Q1). Props go in `Props`, which y-sorts them with the car; set pieces stay in `SetPieces` (K2). Like `WorldRenderer.bind()`, `PropPool` must drop the last run's props when a run starts (E6).
  - M5.3's `AudioDirector` cross-fades on `EventBus.area_changed`, which now comes for each run's first area too (K4, Q2). The tunnel's reverb comes with it (K18).
  - `test_the_smoke_shows_over_everything_the_grey_box_draws` takes its backgrounds from the grey box, now with what the bridge draws under the car (§5.11). Art that draws the ground or the set pieces some other way needs the same check.
  - M5.4's `record_disaster(id, …)` gets four ids: `sinkhole`, `tornado`, `flood` and `quicksand`.
- **M6:**
  - M6 tunes §5.10's values on the devices, within the limits that tests guard: 2–4 s for every disaster (`test_disasters.gd`), and `RIVER_REACH` plus `BRIDGE_BANK` at most `min_straight` + 0.5 (`test_set_pieces_on_the_road.gd`). `TRANSITION_TILES` must also stay within every area's `min_straight`, or a junction blends but its dead ends don't (§5.4). No test checks that.
  - M6.2's haptics "when a disaster starts" go where the director plays it, after the stop (M3_PLAN.md §9).
  - M6.5's checklist can take E14's steps.
- **IP:** fold this plan's Δs into IP once it's approved (Q8).
- **Optional:** a CI check for editor warnings, built on §6.3's language-server probe (M2 §9). M4's tests added 6 that only the probe found (§6.3).
