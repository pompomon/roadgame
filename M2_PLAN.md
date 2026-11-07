# M2 Driving — Detailed Plan

Status: proposed; Q1–Q17 defaults applied · 2026-11-07 · Scope: `IMPLEMENTATION_PLAN.md` (below: **IP**) §3 M2 row, §4 M2.1–M2.7 and "M2 tests", the M2 rows of §6, and the driving values of M4.2, which M1_PLAN.md §9 moves into M2

**Verified, not just reviewed.** Every file this plan adds or changes exists on branch `m2/prototype` (c9fdb44) and was run with the tools below. Each PR state in §4 was rebuilt from that branch on top of #23 (938c7b2) and passed the five local checks (§6.1). The 46 negative cases in §6.2 were run too. The stacked landing was simulated (§4.5), and a probe played three runs with two retries through the real input path (§6.5).

- Godot 4.7.2-stable (Linux x86_64)
- GUT 9.7.1
- gdtoolkit 4.5.0 on Python 3.12
- shellcheck 0.11.0
- actionlint 1.7.12

Some things could not be run locally: GitHub CI, browsers and the Galaxy Z Fold4. They are checked in PR 4 (E12, §6.4).

**Precedence.** For M2, this document replaces IP §4 M2 wherever they differ. Each difference is marked **Δ** with its finding number (H#, §2). The M2 rows of IP §6 still hold; §5.13 lists every test. Once this plan is approved, fold the changes back into IP (Q15).

**Reference code (Q16).** This plan has no appendices: each PR checks its files out of `m2/prototype` (§4.1). Don't open a PR from that branch, because the four PRs carry its code. Pushes to it start nothing: `ci.yml` runs only for pull requests, pushes to `main` and manual runs. Its `ci.yml` is `main`'s, so a manual run would save no caches and keep artifacts for one day (M0 F34).

**Prerequisites.** M1 is merged (#19–#23). No repository settings change.

Contents:
1. Goal and exit criteria
2. Review findings
3. Decisions and open questions
4. Work breakdown (4 PRs)
5. Design
6. Verification
7. Owner actions
8. M2 risks
9. Notes for later milestones

---

## 1. Goal and exit criteria

Goal (IP §3): "A human can drive with touch or keyboard; auto-speed, off-road, health and junction judging work; sim tests pass". The game replaces M1's road viewer as the main scene, so Pages and the debug APK run it. Until M3 adds disasters, the end of a run shows game over at once, and a tap or Enter starts a new run (Q2).

| # | Exit criterion | Checked by |
|---|---|---|
| E1 | The car turns at `STEER_RATE` and moves where it faces. With no input it straightens up to the nearest grid direction. A step reports every cell it enters, in order, corners included (H10) | `test_car_sim_steering.gd` |
| E2 | Speed rises along a straight, and the top speed grows with the run up to the cap. Braking starts at the brake distance whichever exit the car takes, and the car enters the junction tile at `junction_speed`, even from the speed cap (H1). It speeds up again after the turn | `test_car_sim_speed.gd` |
| E3 | Off the road the car takes damage every step and slows down, and rejoining stops the damage. The off-road limit is a crash on a straight and a missed turn near a junction (D6, H12). Health 0 is a crash. Rejoining on a dead end is a disaster, and the car stops (H2) | `test_car_sim_offroad.gd` |
| E4 | The correct exit completes the turn, and every wrong exit is a disaster. The entry edge, edges without road, crossings off the road and other tiles decide nothing (H11). A rejoin decides by D5, also past two junctions (H13). The trigger finds the next junction for 300 turns | `test_junction_trigger.gd` |
| E5 | The autopilot completes 300 turns on each of 20 seeds at `delta = 1/60`, with no disaster and no damage, and never enters a junction tile above `junction_speed` | `tests/sim/test_autopilot_300_turns.gd` |
| E6 | A driver that cuts the inside corner leaves the road near the junction, rejoins 1–2 tiles past it, and completes the turn with 1–99 health | `tests/sim/test_corner_cut.gd` |
| E7 | `GameState` follows its transition table, and an invalid change is an error that changes nothing (H25). Pausing pauses the tree. `end_run()` reports the cause and the stats, and quitting to the title unpauses | `test_game_state.gd` |
| E8 | Keys and touches steer. Of the inputs held, the last one pressed wins (Q7). A touch steers by the half where it started. Losing focus, by either notification, drops everything held and pauses the run (H4). Input works while paused (H3), and a tap or click on II pauses without steering (H7–H9) | `test_input_router.gd`, `test_main_scene_boot.gd` |
| E9 | The HUD shows the version, the seed, turns, health and the distance in metres, pauses by key or button, and shows why a run ended and how to retry (H6). The camera takes the zoom step nearest, by ratio, to 5 tiles across the shorter side, looks ahead and keeps the car low in portrait. The car shows the nearest of 16 frames, and dust only off the road | `test_hud.gd`, `test_camera_rig.gd`, `test_car_controller.gd` |
| E10 | The main scene drives 600 frames with the autopilot and no errors. With no input, the first junction ends the run (H30). With the autopilot, the end of a run is an error (H17). Every glyph the HUD can show is in the default font | `test_main_scene_boot.gd`, `test_smoke.gd` |
| E11 | The smoke run (seed 12345, 3,600 frames) drives with the autopilot and prints no error lines, so the run doesn't end (H17). Locally it prints `autopilot: tile 165, turns 35, area rural` | `smoke.sh`: an `autopilot: tile N` line with N ≥ 1, and no error lines. PR 4 compares the full line by hand (§4) |
| E12 | Manual: the Web build in Chrome and Firefox and the debug APK on the Galaxy Z Fold4. A human drives with keys, touch and (on the Web) the mouse. II and Esc pause, losing focus pauses, game over and retry work, and the zoom suits the screen | PR 4 (§4, PR 4 step 3) |
| E13 | All five required checks are green. `lint` covers the new folders without changes. The editor reports no new warnings (H29) | PR checks; §6.3 |

---

## 2. Review findings

IP's M2 design mostly holds up. The speed model, the D5 and D6 rules and the split into a pure `CarSim` and thin nodes work as described. The problems:
- braking that can't get down to junction speed in time;
- a rejoin order that revives a finished run;
- input that is lost while paused or when the window loses focus;
- a field M1 removed.

- **High:** following IP gives a broken game, or a check that passes when it shouldn't.
- **Medium:** fragile, or broken on some platform or in some order of events.
- **Low:** clarity, naming or polish.

"Prototype" means the problem was reproduced with Godot 4.7.2 on `m2/prototype`. "Source" means Godot's source at the 4.7.2-stable tag, which the file and line numbers refer to.

### High

| # | Finding | Evidence | Fix |
|---|---|---|---|
| H1 | IP M2.2 brakes at the constant `BRAKE` (4 tiles/s²) from `junction_brake_distance` (1.25 tiles) before the junction's centre. The junction tile starts 0.5 tiles before its centre, so the car has 0.75 tiles to slow down and enters at √(v² − 6) tiles/s. From the cap of 7 that is 6.6 instead of `junction_speed` 2.0, and even from 4 it is 3.2. Too fast for the corner, the car runs off the road. | Prototype, N1: with IP's braking, the autopilot crashes on health on all 20 seeds, at turns 76–98. On each seed, its fastest entry is 1.94–2.21 tiles/s above `junction_speed`. IP's own 300-turn test fails | **Δ IP M2.2:** while braking for a junction, the rate is the larger of `BRAKE` and (v² − js²) / (2 · room), where room is the distance to the junction tile (d − 0.5). The car reaches `junction_speed` as it enters the tile. `AreaDef.validate()` requires a brake distance above 0.5. The 300-turn test checks every entry speed (Q1) |
| H2 | IP M2.2 handles a rejoin by calling `on_rejoin(tile)` and then setting state `DRIVING`. A rejoin on a dead end ends the run inside `on_rejoin()` (state `DISASTER`), and the next line sets `DRIVING` again. The car drives on, and a later crash makes `GameState` report DISASTER → CRASH as an invalid change. | Prototype, N43: `test_rejoining_on_a_dead_end_is_a_disaster_and_the_car_stops` fails | **Δ IP M2.2:** set `DRIVING`, then call `on_rejoin()`, then end the step |
| H3 | IP M2.7 pauses with `get_tree().paused` and gives only UI overlays `process_mode = ALWAYS`. The `InputRouter` then sleeps through a pause: a key released while paused stays held, and the car steers by itself after resuming. | Prototype, N9: `test_a_key_released_while_paused_is_not_missed` fails. N26 (the HUD without ALWAYS): that test and both II tests fail | **Δ IP M2.7:** the `InputRouter` and the HUD run with `process_mode = ALWAYS`. The HUD shows the pause message itself (Q3). The car, the camera and the world pause with the tree |
| H4 | Losing focus sends no key-up or touch-up events. Godot's own release, `Input.release_pressed_events()`, clears only `Input`'s state, without events. It also does nothing unless `NOTIFICATION_APPLICATION_FOCUS_OUT` came first, and the Web platform never sends that one. A blur reaches nodes only as `NOTIFICATION_WM_WINDOW_FOCUS_OUT`. A key held while the player switches away stays held in a router that tracks events, so the car keeps steering. | Source: input.cpp:1600–1604, scene_tree.cpp:934–947, display_server_web.cpp:843–845 (the window blur), window.cpp:898–903 (the canvas blur); no file in `platform/web` sends the application notification. Prototype: N16, N27, N46 | The `InputRouter` drops everything held on either notification, and `main.gd` pauses the run on either (Q4) |
| H5 | IP M2.3's `on_rejoin()` compares `tile.junction == next_junction`, a field that M1 removed (M1_PLAN.md G1). `check_scripts.sh` only loads scripts, and loading this one reports nothing. | Prototype, N3: `check_scripts.sh` passes; 8 GUT tests fail | **Δ IP M2.3:** `tile.junction_index == next_junction.path_index` |

### Medium

| # | Finding | Evidence | Fix |
|---|---|---|---|
| H6 | Retrying reloads the scene (Q2). `reload_current_scene()` takes the current scene out of the tree at once, before `retry_requested.emit()` returns. A HUD that marks the input handled after emitting has no viewport by then. | Source: scene_tree.cpp:1747–1751 and 1722–1739. Prototype: the retry probe printed one `SCRIPT ERROR` (hud.gd:51) per retry; N45 | The HUD marks the input handled, then emits. `test_a_retry_may_take_the_hud_out_of_the_tree` checks it |
| H7 | A clicked button takes keyboard focus by default, and Enter (`ui_accept`) then presses II again instead of reaching the game. | Prototype, N18 | II has `focus_mode = NONE` |
| H8 | Desktop browsers send mouse events, but IP M2.1 reads only actions and touches, so the mouse can't steer. Godot turns clicks into touches with `pointing/emulate_touch_from_mouse`, but only outside the editor and only when no touchscreen is available. | Source: main.cpp:3662–3666. Prototype, N21 | PR 4 turns the setting on (Q6). The tests feed both the emulated touch and the mouse event, in Godot's order (input.cpp:850–860) |
| H9 | IP M2.6's `TouchZones` (two half-screen `Control`s with II on top) only keep touches on II from steering. The GUI already does that: II's default `mouse_filter` (STOP) keeps every touch on it, including the emulated ones that `BaseButton` ignores in favour of the mouse event. | Source: base_button.cpp:66, input.cpp:858. Prototype: N19, N20 (II with PASS or IGNORE), N35 | **Δ IP M2.6:** no `TouchZones` (Q5). The `InputRouter` reads touches in `_unhandled_input()` and picks the side from the visible rect's centre |
| H10 | A step that crosses a cell corner moves diagonally, and IP M2.3's `heading(to_cell − from_cell)` has no heading for a diagonal: the car can leave a junction undecided. | Prototype, N28, N44 | **Δ IP M2.3:** `CarSim` reports every cell a step enters, in order. Through a corner, it reports first the neighbour whose edge the step reaches first |
| H11 | IP M2.3 decides an exit by the first edge the car crosses out of the junction cell, even an edge without road. | Prototype, N5. A step moves at most 0.117 tiles (7 tiles/s at 60 Hz), and the road ends 0.18 tiles before such an edge, so today the car is always off the road there | The trigger also requires `junction.has_exit(exit)`. The off-road rules take over, as IP's T-junction note expects |
| H12 | D6 doesn't say from which cell "near" is measured on the step that leaves the road. | Prototype, N6, N7; the corner-cut probe (§6.5) | From the cell after the step: at most 1 step (Manhattan) from the junction cell |
| H13 | IP M2.3's rejoin rule covers only the stretch up to the following junction. `offroad_limit_tiles` may be up to 5, so a car can rejoin past two junctions. | `AreaDef` range 0.5–5 | `on_rejoin()` resolves every junction it passed, in order, and stops at a dead end or at the first junction not reached |
| H14 | IP M2.3's `resolve()` writes `GameState.turn_index` and emits the disaster itself, so the trigger and every sim test would need the autoloads. | IP M2.3 | **Δ IP M2.3:** `JunctionTrigger` is a pure `RefCounted` with its own `turn_completed` and `disaster_triggered` signals. `main.gd` relays them to `GameState` and `EventBus` |
| H15 | D2 promises "300+ turns in well under a second". One run takes about 0.25 s, but IP's test runs 20 seeds: about 5 s, and GUT goes from 7 to 12 s. | §6.5 | Keep 20 seeds (Q11) |
| H16 | IP M2.2's "signals or callbacks" invite lambdas. A lambda that uses `self`, connected to a signal of an object that `self` holds, keeps `self` alive: `GDScriptLambdaSelfCallable` holds a `Ref<RefCounted>` to it. The cycle is never freed, and GUT still passes. | Source: gdscript_lambda_callable.h:73. Prototype, N2: GUT passes, and `run_tests.sh` fails on the leak guard (M1 G1) | The sim objects connect methods, never lambdas |
| H17 | Nothing in IP checks that the autopilot keeps driving in the real game loop: `smoke.sh` needs only a tile above 0. | Prototype, N12 | With `--autopilot`, the end of a run is a `push_error`, so `smoke.sh` and the boot test fail on it (N25) |
| H18 | `plan.md` §5.1 expects the `expand` aspect to fill extra width or height with more of the world, and also asks for integer scaling. Godot expands the view first and then scales it by a whole factor, so a screen that isn't a whole multiple of the view gets black margins. On the Fold4, the game covers 63% of the cover screen's area, and 78% of the inner screen's in portrait and 50% in landscape. | Source: window.cpp:1380–1401. Prototype: screenshots at the Fold4's screen sizes under Xvfb (§6.5). With `scale_mode="fractional"`, the same view fills the screen | None in M2 (Q17). E12 shows the margins on the device, and M6.1 decides how to fill the screen (§9) |

### Low

| # | Finding | Fix |
|---|---|---|
| H19 | IP M2.2's `path_index_changed(i)` output leaves moving the buffer to whoever listens, so a sim test without `main.gd` runs out of road. | `CarSim` calls `buffer.on_car_path_index()` itself, before it reads the centreline (N34) |
| H20 | IP M2.4 asks for a 16-frame sprite sheet, `GPUParticles2D` dust and an engine sound, but there is no art or audio yet. | A `Polygon2D` arrow, tinted per frame; `CPUParticles2D` dust, with no particle shader to compile the first time the car leaves the road (Q12); audio in M5 |
| H21 | IP M2.4 takes the frame from the velocity, which has no direction when the car stands still. The 16 frames sit 4.07° off the isometric grid directions. | The frame comes from the heading. N, E, S and W get frames 3, 5, 11 and 13; M5.1 draws the art to match (§9) |
| H22 | IP M2.7's `start_run(seed := -1)` would shadow the built-in `seed()` (M1 G13), and `run_seed` would shadow the member. `max_area_reached` always equals the current area, because areas only move forward. | `start_run(p_run_seed)`, and `main.gd` picks the seed (D8). No `max_area_reached` |
| H23 | `EventBus` only declares its signals, and other scripts emit them, so the editor warns that each one is unused. | `@warning_ignore_start("unused_signal")` |
| H24 | M2 needs an area by id, and a method named `area()` would add 2 SHADOWED_VARIABLE warnings in `road_generator.gd`. | `RoadGenerator.find_area(id)`. An unknown id is an error and returns the first area (N22) |
| H25 | `plan.md` §7.3 reads as if a paused run could end (PAUSED → DISASTER or CRASH), and it has no way back to the title from most states. | §5.5's table. A paused run can't end (N13), and every state can quit to the title, which `main.gd` does when it leaves the tree |
| H26 | IP M2.5's `snap()` is undefined, and its tile step of 71.6 px is rounded. On the unfolded Fold4 in portrait, the ideal zoom is 1.49: nearer to 1 by difference, and to 2 by ratio (§6.5). | The zoom step nearest by ratio (log scale), and a tile step of `Iso.tile_to_world(Vector2.RIGHT).length()` = 71.55 px |
| H27 | IP M2.6 doesn't say which distance the HUD shows. | The farthest point reached along the path, so backing up doesn't lower it (Q9, N42) |
| H28 | IP M2 has no retry. | A tap or Enter retries at once. A forced `--seed` stays for every retry; without it, each run gets a new random seed (Q2) |
| H29 | The editor reports 8 warnings in M1's code: INTEGER_DIVISION in `test_greybox_atlas.gd` (4), `test_iso.gd`, `ui/main.gd` and `world/greybox_atlas.gd`, and UNUSED_VARIABLE in `test_road_generator_occupancy.gd`. | Leave them (Q13). M2 adds none (§6.3) |
| H30 | IP's boot test runs 600 frames with no input. With no input, the car goes straight over the first junction, a wrong turn at frame 148, so the test would check game over, not driving. | **Δ IP "M2 tests":** the boot test drives with the autopilot, and another test checks that with no input the first junction ends the run (N41) |
| H31 | `JunctionTrigger` looks for the next junction in the buffer, which is sure to hold only 25 tiles ahead of the car (`BUFFER_REFILL_AT`). `AreaDef` allows straights of 20 tiles and a schedule entry a set piece of 20, and `validate()` doesn't check what they add up to. Past the buffer, the trigger stops judging, with only a `push_error`. | None in M2: in the game schedule, the next junction is at most 14 path tiles away. M4 checks it in `AreaSchedule.validate()` (§6.5, §9) |

---

## 3. Decisions and open questions

This plan applies the defaults below. Tell me if you want any of them changed.

| # | Question | Default (applied) | Alternative |
|---|---|---|---|
| Q1 | How does the car brake for a junction? | At least `BRAKE`, and harder when it must be, so that it enters the junction tile at `junction_speed` (H1) | IP's constant rate, raised to about 30 tiles/s² ((7² − 2²) / (2 × 0.75)); or a brake distance of about 6 tiles, outside `AreaDef`'s range of 1–3 |
| Q2 | How does a run end until M3 adds disasters? | Game over at once. The HUD shows why, and a tap or Enter starts a new run by reloading the scene (H6, H28) | A short delay before a retry is accepted (§8) |
| Q3 | Pause screen | The HUD shows "Paused" and how to go on. II and Esc pause and resume (H3) | A `ui/pause.tscn` overlay, as in IP §2's layout |
| Q4 | What happens when the game loses focus? | Drop everything held and pause the run (H4) | Only drop what is held, and drive on |
| Q5 | Touch zones | None: II keeps the touches on it from steering by itself (H9) | IP M2.6's `TouchZones` |
| Q6 | Can the mouse steer on desktop? | Yes: `emulate_touch_from_mouse` turns clicks into touches (H8) | Keyboard only on desktop |
| Q7 | Keys and touches held at the same time | The last one pressed wins, and the others take over again as it is released. A touch keeps the side where it started | Opposite inputs cancel out |
| Q8 | The autopilot | It replaces the player's input while it is set (`-- --autopilot`, tests) | One more input source, mixed in by Q7's rule |
| Q9 | Which distance does the HUD show? | The farthest point reached along the path, at 10 m per tile (H27) | The distance driven (`dist_total`), which grows off the road and when driving back |
| Q10 | `AreaDef`'s driving defaults | The City's values, so `city.tres` sets none | Every area sets all six |
| Q11 | The 300-turn test | 20 seeds, as in IP: about 5 s (H15) | Fewer seeds, if the CI `test` job regularly takes more than 100 s (M1 Q9; M1's PRs took 62–89 s) |
| Q12 | Dust | `CPUParticles2D` (H20) | IP M2.4's `GPUParticles2D` |
| Q13 | The 8 editor warnings in M1's code | Leave them (H29) | Fix them in one of the PRs |
| Q14 | How do the 4 PRs land? | Stacked branches, each retargeted to `main` in turn (§4.5) | One PR at a time, each opened after the previous one merges |
| Q15 | Fold this plan into IP? | After review. Until then, this document wins for M2 | — |
| Q16 | Appendices with every file, as in M0? | No: `m2/prototype` is the reference, and PRs check files out of it | Copy the files into this plan |
| Q17 | Black margins on the Fold4 (H18) | Keep `plan.md`'s integer scaling in M2. E12 shows the margins, and M6.1 decides how to fill the screen | `scale_mode="fractional"` in PR 4: the same view fills every screen, but with nearest-neighbour filtering, art pixels come out at uneven sizes |

---

## 4. Work breakdown

There are four PRs, and each one leaves CI green (E13). The total estimate is about 3 days, below IP's size "L" (4–6 days), because the code exists and is verified. Most of the remaining risk is in PR 4: touch, mouse and focus on real devices and browsers can't be tested locally (E12).

```
PR 1 trigger ──▶ PR 2 CarSim ──▶ PR 3 GameState ──▶ PR 4 the game
 (M2.3, M4.2)     (M2.2, M2.1)    (M2.7)              (M2.1, M2.4–M2.6)
 ~0.5 d           ~1 d            ~0.5 d              ~1 d
```

PRs 1–3 add code and tests only, and keep M1's road viewer as the main scene. PR 4 replaces it with the game.

### 4.1 Porting from the prototype

Every PR follows the same steps:

1. Fetch the branches and create the PR's branch. The refspec also works in a clone that tracks only `main`:
   ```bash
   git fetch origin main '+refs/heads/m2/*:refs/remotes/origin/m2/*'
   git switch -c m2/1-trigger origin/main    # PRs 2–4: from the previous PR's branch (§4.5)
   ```
2. Check the PR's files out of the prototype with the command in its section. The globs are quoted so the `.uid` files come along.
3. Make the PR's trim, if any. Only PR 3 has one.
4. Run `tools/ci/import.sh`. It must create no files: `git status --porcelain` lists only the checked-out paths.
5. Run §6.1 and compare the counts with the PR's "Expect" line.
6. Commit, push and open the PR.

### PR 1: Junction trigger and driving values (M2.3; the driving part of M4.2) **Δ H5, H11, H13, H14, H24**

Branch `m2/1-trigger`, from `main`.

| Area | Files |
|---|---|
| Tuning | `config/tuning.gd`: all of M2's constants (§5.12) |
| Areas | `areas/area_def.gd`: the driving fields and their checks (§5.2); `rural`, `meadows`, `village` and `desert` `.tres`: IP M4.2's values |
| Road | `road/junction_trigger.gd` (§5.3); `road/road_generator.gd`: `find_area()` (H24) |
| Tests | `tests/unit/test_junction_trigger.gd`; `tests/unit/test_area_schedule.gd`: 2 more tests |

Every `.gd` file comes with its `.gd.uid`.

```bash
git checkout origin/m2/prototype -- config/tuning.gd areas/ road/road_generator.gd \
  'road/junction_trigger.gd*' 'tests/unit/test_junction_trigger.gd*' tests/unit/test_area_schedule.gd
```

No trims. Expect: `check_scripts: loaded 31 scripts`; `GUT: 69 tests passed` (143,576 asserts, about 7 s). Negative cases N3–N5 and N22–N24.

**Acceptance:** E4; `validate()` reports driving values the car can't use.

### PR 2: `CarSim` and the autopilot (M2.2; the `Autopilot` of M2.1) **Δ H1, H2, H10, H12, H16, H19**

Branch `m2/2-car-sim`, from `m2/1-trigger`.

| Area | Files |
|---|---|
| Car | `car/car_sim.gd`, `car/autopilot.gd` (§5.4) |
| Tests | `tests/unit/test_car_sim_speed.gd`, `test_car_sim_offroad.gd`, `test_car_sim_steering.gd`; `tests/sim/test_autopilot_300_turns.gd`, `test_corner_cut.gd` |

```bash
git checkout origin/m2/prototype -- 'car/car_sim.gd*' 'car/autopilot.gd*' tests/sim/ \
  'tests/unit/test_car_sim_speed.gd*' 'tests/unit/test_car_sim_offroad.gd*' \
  'tests/unit/test_car_sim_steering.gd*'
```

No trims. Expect: 38 scripts; `GUT: 88 tests passed` (143,809 asserts, about 12 s). Negative cases N1, N2, N6–N8, N14, N28–N34, N43 and N44.

**Acceptance:** E1–E3, E5 and E6. Compare the CI `test` job time with M1's 62–89 s (Q11).

### PR 3: `GameState` and `EventBus` (M2.7) **Δ H22, H23, H25**

Branch `m2/3-game-state`, from `m2/2-car-sim`. It comes after PR 2 because `GameState.end_run()` takes `CarSim`'s causes.

| Area | Files |
|---|---|
| Autoloads | `autoload/event_bus.gd`, `autoload/game_state.gd` (§5.5) |
| Project | `project.godot`: the `[autoload]` section |
| Tests | `tests/unit/test_game_state.gd` |

```bash
git checkout origin/m2/prototype -- autoload/ project.godot 'tests/unit/test_game_state.gd*'
```

Trim: in `project.godot`, delete the `[input_devices]` section and its blank line. It turns on `emulate_touch_from_mouse`, which belongs with the input code in PR 4 (H8).

Expect: 41 scripts; `GUT: 100 tests passed` (143,852 asserts, about 12 s). Like PRs 1 and 2, `smoke.sh` still prints M1's `autopilot: tile 1440, turns 247, area desert`. Negative cases N13, N15 and N40.

**Acceptance:** E7.

### PR 4: The game (M2.1, M2.4–M2.6) **Δ H3, H4, H6–H9, H17, H20, H21, H26–H28, H30**

Branch `m2/4-game`, from `m2/3-game-state`.

| Area | Files |
|---|---|
| Input | `car/input_router.gd` (§5.6); `project.godot`: the `[input_devices]` section (H8) |
| Car | `car/car_controller.gd`, `car/car.tscn` (§5.7) |
| Camera | `world/camera_rig.gd` (§5.8) |
| HUD | `ui/hud.gd`, `ui/hud.tscn` (§5.9) |
| Game | `ui/main.gd`, `ui/main.tscn`: the game replaces M1's viewer (§5.10) |
| Tests | `tests/unit/test_input_router.gd`, `test_hud.gd`, `test_camera_rig.gd`, `test_car_controller.gd`; `tests/integration/test_main_scene_boot.gd`; `tests/unit/test_smoke.gd` |
| CI | `tools/ci/smoke.sh`: a comment (§5.11) |

```bash
git checkout origin/m2/prototype -- project.godot tools/ci/smoke.sh 'car/input_router.gd*' \
  'car/car_controller.gd*' car/car.tscn 'world/camera_rig.gd*' 'ui/hud.gd*' ui/hud.tscn \
  ui/main.gd ui/main.tscn 'tests/unit/test_input_router.gd*' 'tests/unit/test_hud.gd*' \
  'tests/unit/test_camera_rig.gd*' 'tests/unit/test_car_controller.gd*' tests/integration/ \
  tests/unit/test_smoke.gd
```

1. No trims. Expect: 50 scripts; `GUT: 128 tests passed` (143,964 asserts, about 12 s). `smoke.sh` prints `grey box: tilesets built in … ms` and `autopilot: tile 165, turns 35, area rural`. Negative cases N9–N12, N16–N21, N25–N27, N35–N39, N41, N42, N45 and N46.
2. Check that the stack now matches the prototype. The command prints nothing, unless a review changed something on purpose. If `main` has changed other files since 938c7b2, exclude them too:
   ```bash
   git diff --stat origin/m2/prototype -- . ':!M2_PLAN.md'
   ```
3. Manual checks (E12). Start a run that uploads the builds, and download them within a day (M0 F34). `gh run download` puts each artifact in a folder named after it: `web`, `android-Android APK` and `android-Android AAB`.
   ```bash
   gh workflow run ci.yml --ref m2/4-game -f upload-builds=true
   gh run list -w ci.yml -b m2/4-game -e workflow_dispatch -L 1    # the run id
   gh run watch <run id> --exit-status
   gh run download <run id> -D /tmp/roadgame-builds
   ```
   - **Android**, on the Galaxy Z Fold4, folded and unfolded: `adb install -r "/tmp/roadgame-builds/android-Android APK/roadgame-debug.apk"`.
     - Holding the left or right half steers. With both halves held, the last touch wins.
     - A tap on II pauses once and doesn't steer, and another tap resumes.
     - Hold a half and switch to another app. Back in the game, the run is paused, and after resuming the car doesn't steer (H4).
     - Game over says why. A tap starts a new run.
     - The cover screen shows about 5 tiles across (zoom 1), and the unfolded one 3.7 in portrait and 4.5 in landscape (zoom 2, §6.5). On both, junctions come into view in time to choose (§8). Both screens have black margins (H18, Q17).
     - `adb logcat -s godot` shows the `grey box:` line and no errors.
   - **Web:** run `python3 -m http.server -d /tmp/roadgame-builds/web 8000` and open http://localhost:8000 in Chrome and Firefox.
     - The arrow keys and A and D steer. Esc, P and a click on II pause and resume, and the click doesn't steer.
     - A click on either half steers like a touch (H8).
     - Hold a key and switch tabs. Back in the game, the run is paused, and after resuming the car doesn't steer (H4).
     - After game over, Enter or a click starts a new run.
     - The browser console shows the `grey box:` line and no errors.
4. After the merge, https://pompomon.github.io/roadgame/ runs the game.

**Acceptance:** E8–E12.

### 4.5 Landing the stack (Q14)

This is M1_PLAN.md §4.5's procedure, which landed #20–#23, with two changes: no `-X ours`, and GitHub may retarget the PRs by itself. It was checked by simulating the squash merges with `git merge-tree`, on the PR states of §6.1.

1. Each PR branches from the previous PR's branch, and its PR targets that branch, so its diff shows only its own files. `ci.yml` runs on every `pull_request` with no branch filter, so every PR gets the five checks. Required checks only gate PRs into `main`.
2. A review fix for PR n is committed on PR n's branch and then merged (`git merge`) into each later branch. No rebases and no force-pushes.
3. Merge only a PR whose base is `main`. A merge into another PR's branch skips the required checks; in M0, that is why #16 was needed.
4. After PR n squash-merges, update PR n+1:
   ```bash
   git fetch origin main '+refs/heads/m2/*:refs/remotes/origin/m2/*'
   git switch <PR n+1 branch>
   git merge origin/<PR n branch>     # PR n's final state, in case a fix wasn't merged up yet
   git merge origin/main              # the squash commit
   git diff --name-only origin/main   # must list only PR n+1's files
   git push
   gh pr edit <PR n+1> --base main    # unless GitHub did it (step 5)
   ```
   - If PR n's branch is already deleted, fetch its last state with `git fetch origin pull/<PR n>/head` and merge `FETCH_HEAD` instead.
   - M1 needed `-X ours` because its trims gave add/add conflicts. M2's only trim is in `project.godot`, where PR 3 and PR 4 change different places. The simulated merges had no conflicts, with or without the first merge, and the `diff` listed only each PR's own files (14, 7 and 25). A conflict here means that a later branch changed the same lines as a review fix of PR n. Resolve it by hand.
   - The push changes nothing in the PR's diff, so no Copilot review starts by itself. If the PR needs one, request it with `gh pr edit <PR n+1> --add-reviewer @copilot`.
5. Ruleset "Copilot" no longer restricts deletions (§7). If the owner deletes PR n's branch after the merge, GitHub retargets PR n+1 to `main` by itself, as it did for #21 and #22. The repository doesn't delete merged branches automatically. Either way, step 4 is still needed: until PR n+1 merges `main`, its diff also shows PR n's files.

---

## 5. Design

The code on `m2/prototype` is the reference. This section summarizes it and lists what differs from IP, and why.

### 5.1 Files

| File | Class | PR | IP |
|---|---|---|---|
| `config/tuning.gd` | `Tuning` | 1 | M2.5, M2.6, M4.2 (§5.12) |
| `areas/area_def.gd`; `rural`, `meadows`, `village` and `desert` `.tres` | `AreaDef` | 1 | M4.2's driving values (§5.2) |
| `road/road_generator.gd` | `RoadGenerator` | 1 | plus `find_area()` (H24) |
| `road/junction_trigger.gd` | `JunctionTrigger` | 1 | M2.3 **Δ H5, H11, H13, H14** |
| `car/car_sim.gd` | `CarSim` | 2 | M2.2 **Δ H1, H2, H10, H12, H16, H19** |
| `car/autopilot.gd` | `Autopilot` | 2 | M2.1 |
| `autoload/event_bus.gd` | (autoload `EventBus`) | 3 | M2.7, H23 |
| `autoload/game_state.gd` | (autoload `GameState`) | 3 | M2.7 **Δ H22, H25** |
| `project.godot` | — | 3, 4 | `[autoload]` (PR 3); `[input_devices]` (PR 4, H8) |
| `car/input_router.gd` | `InputRouter` | 4 | M2.1 **Δ H3, H4, H9** |
| `car/car_controller.gd`, `car/car.tscn` | `CarController` | 4 | M2.4 **Δ H20, H21** |
| `world/camera_rig.gd` | `CameraRig` | 4 | M2.5, H26 |
| `ui/hud.gd`, `ui/hud.tscn` | `Hud` | 4 | M2.6 **Δ H3, H6, H7, H9** |
| `ui/main.gd`, `ui/main.tscn` | (the game) | 4 | **Δ H4, H17, H27, H28, H30**; replaces M1's viewer |
| `tools/ci/smoke.sh` | — | 4 | a comment (§5.11) |

All of them are in IP §2's layout. That layout also has `ui/touch_zones.tscn` and `ui/pause.tscn`, which M2 doesn't add (Q5, Q3).

### 5.2 Driving values (PR 1)

M1_PLAN.md §9 moved IP M4.2's driving values into M2. `AreaDef` gets six fields in an `@export_group("Driving")`. Their defaults are the City's values, so `city.tres` doesn't change (Q10).

| Field | Range | Default (City) | Rural, Meadows | Village | Desert | `validate()` reports |
|---|---|---|---|---|---|---|
| `straight_accel` | 0–2 | 0.5 | 0.6 | 0.55 | 0.7 | a negative value |
| `junction_brake_distance` | 1–3 | 1.25 | 1.25 | 1.25 | 1.5 | 0.5 or less: no room to brake before the junction tile (H1) |
| `junction_speed` | 0.5–4 | 2.0 | 2.2 | 2.0 | 2.4 | 0 or less, or above `BASE_TOP_SPEED`: the car would speed up for some junctions |
| `offroad_speed_mult` | 0.1–1 | 0.5 | 0.6 | 0.55 | 0.45 | 0 or less, or above 1 |
| `offroad_damage_per_sec` | 0–100 | 30 | 25 | 30 | 35 | a negative value |
| `offroad_limit_tiles` | 0.5–5 | 2.0 | 2.0 | 2.0 | 2.0 | 0 or less |

- Each problem starts with the area's id, for example `desert: junction_speed is outside 0..BASE_TOP_SPEED`. The ranges only limit the inspector, so `validate()` checks what a `.tres` file can still hold.
- `offroad_limit_tiles` is a field, as in `plan.md` §3.7, although IP M4.2 lists it with the global constants. Every area keeps 2.0.
- `RoadGenerator.find_area(id) -> AreaDef` returns the schedule's area with that id. Every tile's `area_id` names one. Any other id is an error, `push_error("RoadGenerator: no area %s in the schedule")`, and returns the first area (H24). `CarSim` and `main.gd` use it.

### 5.3 Junction trigger (PR 1) **Δ IP M2.3**

```gdscript
class_name JunctionTrigger extends RefCounted     # Δ H14: no autoloads
signal turn_completed(turn_index: int)
signal disaster_triggered(junction: RoadTile, choice: int)  # choice: the exit taken, or -1 for a missed turn
var turn_index := 0              # correct turns so far
var next_junction: RoadTile      # the first unresolved junction ahead; null after a disaster
func _init(buffer: RoadBuffer) -> void   # the buffer must have started
func on_cell_crossed(from_cell: Vector2i, to_cell: Vector2i, on_road: bool) -> void
func on_rejoin(tile: RoadTile) -> void
func on_offroad_limit() -> void
```

- **Leaving the junction tile** (`on_cell_crossed`). The exit is `Heading.from_vec(to_cell − from_cell)`, and `CarSim` reports only neighbouring cells (H10). It decides only if all of these hold:
  - the car was on the road before the move;
  - `from_cell` is the next junction's cell;
  - the exit isn't the entry edge;
  - the junction has that exit (H11).
- **Rejoining** (`on_rejoin(tile)`, D5) **Δ H5, H13**. While a junction J is unresolved:
  1. A dead end of J (`tile.junction_index == J.path_index`) decides its `branch_exit`: a disaster.
  2. A path tile up to and including J, or a dead end of an earlier junction (`tile.path_index <= J.path_index and tile.junction_index < J.path_index`), decides nothing.
  3. Anything else lies past J: it decides J's correct exit, and the loop checks the tile against the following junction.
- **The off-road limit** (`on_offroad_limit()`, D6) is a missed turn: `choice` −1.
- **Resolving.** A wrong exit sets `next_junction` to null and emits `disaster_triggered`. After that, nothing is decided. The correct exit adds 1 to `turn_index`, moves `next_junction` to the following junction and emits `turn_completed`. Both update the trigger before they emit, so a listener sees the new state.
- The next junction is the first one after the current one in the buffer. If the buffer has none, it reports `push_error("JunctionTrigger: no junction after path index %d")` and stops judging (H31).

### 5.4 Car simulation (PR 2) **Δ IP M2.2**

```gdscript
class_name CarSim extends RefCounted
signal health_changed(value: float)
signal offroad_changed(is_offroad: bool)
signal area_changed(area: AreaDef)      # the car reached the first tile of a new area
signal crashed(cause: StringName)       # HEALTH or OFFROAD; disasters come from trigger.disaster_triggered
enum State { DRIVING, BRAKING, OFFROAD, DISASTER, CRASHED }
const WRONG_TURN := &"wrong_turn"       # the causes of plan.md §2.5
const MISSED_TURN := &"missed_turn"
const HEALTH := &"health"
const OFFROAD := &"offroad"
var pos: Vector2              # tile space (D1)
var angle: float              # radians; 0 is grid N (-y), clockwise
var speed: float              # tiles/s
var health: float
var state: State
var dist_total: float         # tiles driven in the run
var dist_on_straight: float   # tiles driven since the last correct turn
var offroad_dist: float
var offroad_junction: RoadTile  # the junction the car was near when it left the road (D6), or null
var path_tile: RoadTile       # the correct-path tile whose cell the car was in last
var progress: float           # path_tile's index plus the car's place along it (-0.5 to 0.5)
var area: AreaDef             # of the farthest path tile reached; its values drive the car
var buffer: RoadBuffer
var trigger: JunctionTrigger  # created by _init
func _init(p_buffer: RoadBuffer) -> void   # the buffer must have started
func step(delta: float, steer: float) -> void
func velocity() -> Vector2
func forward() -> Vector2
func is_over() -> bool                     # DISASTER or CRASHED
func distance_to_junction() -> float       # along the path, to the next junction's centre; INF after a disaster
func target_speed() -> float
static func cells_crossed(from: Vector2, to: Vector2) -> Array[Vector2i]
static func path_progress(tile: RoadTile, p: Vector2) -> float
```

`_init` creates the trigger and connects its signals to methods, never lambdas (H16). The car starts at speed 0 on the centre of the buffer's first path tile, facing along it.

`step(delta, steer)` does, in this order:
1. Once the run is over (`is_over()`), the car only rolls to a stop at `BRAKE`, and the step ends.
2. Steer, update the speed and move, and add the distance to `dist_total` and `dist_on_straight`.
3. For each cell the move enters (`cells_crossed()`, H10), call `trigger.on_cell_crossed(cell, next, was_on_road)`. If that ends the run, the step ends.
4. If the car entered a new path tile, call `buffer.on_car_path_index()` first (H19). Then take the area of the farthest path tile, and emit `area_changed` if it is new. On every step, update `progress` on the last path tile.
5. Apply the off-road rules (below).

A step must move less than a tile. At 7 tiles/s and 60 Hz it moves 0.117 tiles (§6.5).

**Steering** (IP M2.2): `angle += clamp(steer, −1, 1) · STEER_RATE · delta`. With no input, the angle eases towards the nearest multiple of π/2 at `STRAIGHTEN_RATE` (`plan.md` §2.2).

**Speed** (`plan.md` §2.3) **Δ H1**. `d` is `distance_to_junction()`, and the values come from `area`:
```
run_cap = min(GLOBAL_SPEED_CAP, BASE_TOP_SPEED + dist_total · TOP_SPEED_GROWTH)
target  = min(run_cap, junction_speed + straight_accel · dist_on_straight)
if d ≤ junction_brake_distance: target = junction_speed     # whichever exit the car takes
if OFFROAD: target ·= offroad_speed_mult
rate = ACCEL if target > speed else BRAKE
if BRAKING and speed > target:                              # Δ H1
    room = d − 0.5                                          # to the junction tile's entry edge
    rate = max(rate, (speed² − target²) / (2 · room)) if room > 0 else INF
speed = move_toward(speed, target, rate · delta)
```
- Unless the car is off the road, its state is `BRAKING` within the brake distance and `DRIVING` outside it.
- `dist_on_straight` resets on `turn_completed`.

**Off the road** (`plan.md` §2.4, D6). Whether the car is on the road is `RoadGeometry.is_on_road()` at its position after the move.
- **Leaving the road:** the state becomes `OFFROAD`, and `offroad_dist` resets. `offroad_junction` is the next junction if the car's cell is at most one grid step from it (Manhattan), otherwise null (H12). It emits `offroad_changed(true)`, and the damage starts on the same step.
- **Rejoining:** the state becomes `DRIVING`, and it emits `offroad_changed(false)`. Then it calls `trigger.on_rejoin(tile)`, and the step ends **Δ H2**. A dead-end rejoin sets `DISASTER` inside that call, and nothing changes it back.
- **Each step off the road:**
  - `offroad_dist += speed · delta`.
  - Health drops by `offroad_damage_per_sec · delta`, not below 0, and it emits `health_changed`.
  - At 0 health, the car crashes (`HEALTH`).
  - At `offroad_limit_tiles`, it calls `trigger.on_offroad_limit()` (a missed turn) if `offroad_junction` is set. Otherwise it crashes (`OFFROAD`).

The states follow `plan.md` §7.5:

| `plan.md` §7.5 | `CarSim` |
|---|---|
| `DRIVING ⇄ BRAKING_FOR_JUNCTION` | `DRIVING` and `BRAKING`, by `distance_to_junction()` |
| `DRIVING/BRAKING → OFFROAD ⇄ DRIVING` | `OFFROAD`, and `DRIVING` again on rejoining the road |
| `OFFROAD → DISASTER`, `DRIVING/BRAKING → DISASTER` | `DISASTER`: the off-road limit near a junction, a wrong exit, and also a rejoin on a dead end (D5) |
| `OFFROAD → CRASHED` | `CRASHED`: the off-road limit on a straight, or health 0 |

**`Autopilot`** (`RefCounted`, IP M2.1) steers by pure pursuit:
- It aims at `buffer.centreline_point(progress + LOOKAHEAD)`, with `LOOKAHEAD` = 0.9 tiles.
- It steers by the heading error × `GAIN` (4), clamped to ±1.
- It returns 0 if that point is the car's own position.
- The sim tests and `-- --autopilot` use it. Its two constants tune only this driver, not the game, so they are in `autopilot.gd` rather than `Tuning` (D11).

### 5.5 Game state and events (PR 3) **Δ IP M2.7**

`GameState` (autoload, no `class_name`) has `enum State { TITLE, RUNNING, PAUSED, DISASTER, CRASH, GAME_OVER }` and the stats `run_seed`, `turn_index`, `distance` (tiles), `area_id` and `end_cause`. No `max_area_reached` (H22).

Its transition table (H25):

| From | To |
|---|---|
| TITLE | RUNNING |
| RUNNING | PAUSED, DISASTER, CRASH, TITLE |
| PAUSED | RUNNING, TITLE |
| DISASTER, CRASH | GAME_OVER, TITLE |
| GAME_OVER | RUNNING, TITLE |

Any other change reports `push_error("GameState: %s to %s is not allowed")` and changes nothing. A paused run can't end (N13).

- `start_run(p_run_seed)` (H22) resets the stats and emits `run_started`.
- `pause()` and `resume()` also set `get_tree().paused` and emit `paused_changed`.
- `end_run(cause)` moves to `DISASTER` for `WRONG_TURN` and `MISSED_TURN` and to `CRASH` for the others. It keeps the cause and emits `run_ended(cause, stats())`.
- `show_game_over()` moves to `GAME_OVER`. M3's sequences will call it when they finish. In M2, `main.gd` calls it right away (Q2).
- `quit_to_title()` works from every state but `TITLE`, and unpauses the tree if the game was paused.
- `stats()` returns `{run_seed, turn_index, distance, area_id, cause}`.
- `main.gd` writes `turn_index`, `distance` and `area_id` (§5.10).

M2's retry reloads the scene (Q2): `main.gd` calls `quit_to_title()` as it leaves the tree, and the new scene calls `start_run()`. GAME_OVER → RUNNING is for a retry without a reload (§9).

**`EventBus`** (autoload) holds the 8 signals of `plan.md` §7.4 and IP M2.7's 2 more. It has no state.
```gdscript
signal run_started(run_seed: int)                  # plan.md: seed (H22)
signal turn_completed(turn_index: int)
signal area_changed(area: AreaDef)
signal tiles_generated(tiles: Array[RoadTile])
signal tiles_freed(tiles: Array[RoadTile])
signal health_changed(value: float)
signal disaster_triggered(area: AreaDef, junction: RoadTile)
signal run_ended(cause: StringName, stats: Dictionary)
signal car_offroad_changed(is_offroad: bool)       # IP M2.7
signal paused_changed(paused: bool)                # IP M2.7
```
- The signals sit between `@warning_ignore_start("unused_signal")` and `@warning_ignore_restore("unused_signal")` (H23).
- `GameState` emits `run_started`, `run_ended` and `paused_changed`, and `main.gd` relays the others.
- In M2 only the HUD listens: to `run_started`, `turn_completed`, `health_changed`, `paused_changed` and `run_ended`.

`project.godot` (PR 3) gets an `[autoload]` section with `EventBus` and then `GameState`.

### 5.6 Input (PR 4) **Δ IP M2.1**

`InputRouter` (`Node`). `main.tscn` gives it `process_mode = ALWAYS`, so a release during a pause isn't missed (H3).
- **`steer() -> float`:**
  - 0 while disabled;
  - the `autopilot`'s steering if one is set (Q8);
  - otherwise the latest of the inputs held, or 0 (Q7).
- **Keys:** the `steer_left` (−1) and `steer_right` (1) actions: the arrow keys and A/D, from M0's input map.
- **Touches** come in `_unhandled_input()`, keyed by touch index. A touch steers by the half of the visible rect where it started, until it lifts.
  - Touches on II never get here, because the button consumes them (H9).
  - With no touchscreen, `pointing/emulate_touch_from_mouse` turns the left mouse button into a touch (H8, Q6). PR 4 adds it to `project.godot`.
- **`enabled`:** setting it drops everything held. While it is false, `steer()` is 0 and input is ignored. `main.gd` turns it off when the run ends.
- **Focus:** either `NOTIFICATION_APPLICATION_FOCUS_OUT` or `NOTIFICATION_WM_WINDOW_FOCUS_OUT` drops everything held (H4).

### 5.7 Car view (PR 4) **Δ IP M2.4**

`CarController` (`Node2D`, `car/car.tscn`). `main.gd` sets its `sim` and `input`, and adds it under `World/%Props`, which y-sorts it.
- `_physics_process(delta)` calls `sim.step(delta, input.steer())`. Then `position = Iso.tile_to_world(sim.pos)`.
- `static func frame(forward: Vector2) -> int`: the nearest of 16 screen directions, clockwise from straight up, for the heading's direction on screen (H21). N, E, S and W get frames 3, 5, 11 and 13.
- The grey box (H20):
  - `%Arrow`, a `Polygon2D`, turned to the frame's direction and tinted with one hue per frame.
  - `%Dust`, a `CPUParticles2D` (24 particles, 0.6 s), emits only while the car is `OFFROAD`.
  - No sound until M5.

### 5.8 Camera (PR 4)

`CameraRig` (`Camera2D`) follows `car: CarController` (IP M2.5):
- `_physics_process(delta)` moves it `1 − exp(−CAMERA_SMOOTHING · delta)` of the way to `target()`, so the smoothing doesn't depend on the frame rate.
- `target()` is the car's position, plus `LOOKAHEAD_PX` along the heading's direction on screen. In portrait, it is also raised by `PORTRAIT_BIAS` of the view's height (`size.y / zoom.y`), so the car sits in the lower third (`plan.md` §5.1).
- `snap_to_target()` jumps there without smoothing. `main.gd` calls it at the start.
- `static func zoom_for(size: Vector2) -> float` (H26):
  - ideal = min(size.x, size.y) / (`VISIBLE_TILES` · 71.55), where 71.55 px is the tile step, `Iso.tile_to_world(Vector2.RIGHT).length()`;
  - the result is the step of `CAMERA_ZOOMS` with the smallest `|log(step / ideal)|`;
  - it runs at start and on every `size_changed`.

### 5.9 HUD (PR 4) **Δ IP M2.6**

`Hud` (`Control`, `ui/hud.tscn`) covers the screen with `process_mode = ALWAYS` (H3). The root, the top bar and the health bar have `mouse_filter = IGNORE`, so touches outside II reach the `InputRouter`. Anchor presets keep the layout on `size_changed` (IP M2.6).

| Node | Shows |
|---|---|
| `%Distance` | `"%d m"`: `GameState.distance` × `METRES_PER_TILE`, every frame (Q9) |
| `%Turns` | `"turns %d"`, on `turn_completed` |
| `%Health` | a `ProgressBar` from 0 to `START_HEALTH`, on `health_changed` |
| `%Pause` | "II": a `Button` with `focus_mode = NONE` (H7) and the default `mouse_filter = STOP` (H9). Hidden once the run ends |
| `%Message` | in the centre: the pause message, or why the run ended and how to retry |
| `%Info` | bottom left: `"Road Roguelike %s\nseed %d"`, the version and the run's seed |

The messages (Q2, Q3):

| When | Text |
|---|---|
| Paused | "Paused", then "Tap II or press Esc to go on" |
| `wrong_turn` | "Wrong turn!" |
| `missed_turn` | "You missed the turn!" |
| `health` | "Your car broke down." |
| `offroad` | "You got lost off the road." |

Each end message is followed by "Tap or press Enter to drive again".

- `_unhandled_input()` handles the `pause` action (Esc and P) with `toggle_pause()`. In `GAME_OVER`, a touch press or `ui_accept` (Enter) marks the input handled, then emits `retry_requested` (H6).
- `toggle_pause()` pauses a running game and resumes a paused one. II's `pressed` calls it.
- All the text uses only characters in Godot's default font. The Web build has no system font to fall back on (M1). `test_smoke.gd` checks every label, button and message.

### 5.10 Main scene (PR 4)

The game replaces M1's road viewer: no ghost, no label and no fast-forward. Dead ends look like real road, because `main.gd` leaves `show_dead_ends` off (M1 Q10). `ui/main.tscn` is `Main` (`Node`, `main.gd`) with these children, in tree order:
1. `World`, an instance of `world.tscn`;
2. `Camera` (`CameraRig`);
3. `InputRouter` (`process_mode = ALWAYS`);
4. `UI` (a `CanvasLayer`) with `HUD`.

The car lives under `World`, so every physics frame it steps before the camera moves.

`main.gd`:
- `args` defaults to `OS.get_cmdline_user_args()`, and tests set it before adding the scene:
  - `--seed=N` picks the road; without it, the seed is random (D8);
  - `--autopilot` drives by itself (Q8).
- `_ready()`:
  1. Builds the buffer from `areas/schedule.tres`, and relays its signals to `EventBus`.
  2. Binds the world and prints `grey box: tilesets built in %d ms`, as in M1. Then it starts the buffer.
  3. Creates the `CarSim`, and connects:
     - `trigger.turn_completed` to `GameState.turn_index` and `EventBus.turn_completed`;
     - `trigger.disaster_triggered` to `EventBus.disaster_triggered(find_area(junction.area_id), junction)`, and then to the end of the run (`MISSED_TURN` for choice −1, otherwise `WRONG_TURN`);
     - `crashed` to the end of the run;
     - `health_changed` and `offroad_changed` to `EventBus` (`car_offroad_changed`);
     - `area_changed` to `GameState.area_id` and `EventBus.area_changed`.
  4. Sets the autopilot, if asked. Adds the car under `%Props`, gives it to the camera and snaps the camera.
  5. Connects the HUD's `retry_requested` to `get_tree().reload_current_scene`. Then it calls `GameState.start_run()`, and sets `GameState.area_id` to the car's first area.
- `_physics_process()`: while `RUNNING`, `GameState.distance` is the farthest `progress` so far (H27).
- Losing focus, by either notification, pauses a running game (H4, Q4).
- **The end of a run** (Q2) records the distance, disables the `InputRouter`, and calls `GameState.end_run(cause)` and then `show_game_over()`. With `--autopilot`, it also reports `push_error("main: the autopilot's run ended: %s")` (H17).
- `_exit_tree()`: with `--autopilot`, it prints `autopilot: tile %d, turns %d, area %s` (M1 G17) for the farthest path tile. M1 printed the junctions its ghost had passed; M2 prints `GameState.turn_index`, the correct turns. Then it calls `GameState.quit_to_title()`, so the reloaded scene starts from `TITLE` (H25).
- A retry keeps a forced `--seed`. Without one, each run gets a new random seed (H28).

### 5.11 CI scripts

No CI script changes, apart from one comment.
- `lint.sh` already lists `autoload`, `car` and `ui` for gdlint and gdformat. Its determinism rule already covers `autoload/` and `car/`. M2's code there calls no global random functions.
- `.gutconfig.json` runs `res://tests/` with its subdirectories, so `tests/sim/` and `tests/integration/` run as they are.
- `smoke.sh` (PR 4): only its header comment changes ("drives by itself"). It still requires `^autopilot: tile [1-9]` and no error lines. With `--autopilot`, the end of a run is an error line (H17).
- `run_tests.sh`, `import.sh` and the workflows don't change.

### 5.12 Tuning

`config/tuning.gd` (PR 1) adds:

| Constant | Value | Source |
|---|---|---|
| `BASE_TOP_SPEED` | 4.0 tiles/s | IP M4.2 |
| `TOP_SPEED_GROWTH` | 0.002 per tile driven | IP M4.2 |
| `GLOBAL_SPEED_CAP` | 7.0 tiles/s | IP M4.2 |
| `ACCEL` | 2.0 tiles/s² | IP M4.2 |
| `BRAKE` | 4.0 tiles/s² | IP M4.2; now the least braking (H1) |
| `STEER_RATE`, `STRAIGHTEN_RATE` | 3.0, 1.0 rad/s | IP M4.2 |
| `START_HEALTH` | 100 | `plan.md` §2.4 |
| `VISIBLE_TILES` | 5 | IP M2.5 |
| `CAMERA_ZOOMS` | [0.5, 1, 2] | IP M2.5 |
| `LOOKAHEAD_PX` | 48 | IP M2.5 names it; the value is new |
| `PORTRAIT_BIAS` | 0.2 of the view's height | new (§5.8) |
| `CAMERA_SMOOTHING` | 6 per second | new (§5.8) |
| `METRES_PER_TILE` | 10 | IP M2.6 |

### 5.13 Tests

| File | Tests | PR | What they check |
|---|---|---|---|
| `test_junction_trigger.gd` | 15 | 1 | It starts at the first junction. The correct exit completes the turn, and every wrong exit of a crossroads is a disaster. Nothing is decided after a disaster, nor by the entry edge, an edge without road (H11), a crossing off the road, or a crossing from another tile. Rejoins: on a dead end, a disaster; past the junction, the turn; before or on it, nothing; past two junctions, both turns (H13); on a later dead end, the turn and then a disaster. The off-road limit is a missed turn. The next junction is found for 300 turns |
| `test_area_schedule.gd` | 7 + 2 | M1, 1 | PR 1: `validate()` reports each driving value the car can't use, and allows the limits themselves. `find_area()` finds each area, and an unknown id is an error that returns the first area (H24) |
| `test_car_sim_speed.gd` | 6 | 2 | Speed rises from 0 on the first straight, and the target rises along a straight. The top speed grows with the run, up to the cap. Braking starts at the brake distance whichever exit the car takes. The car enters the junction tile at `junction_speed`, even from the cap (H1). It speeds up again after a turn |
| `test_car_sim_offroad.gd` | 8 | 2 | Off the road, the car takes damage every step and slows down. Rejoining stops the damage. The off-road limit is a crash on a straight and a missed turn near a junction. Health 0 is a crash. Near is at most one step from the junction (H12). A dead-end rejoin is a disaster, and the car stops (H2) |
| `test_car_sim_steering.gd` | 3 | 2 | It turns at `STEER_RATE` and moves where it faces. With no input, it straightens up to the nearest grid direction. A move enters each cell it crosses, in order (H10) |
| `tests/sim/test_autopilot_300_turns.gd` | 1 | 2 | E5: seeds 0–19, at most 72,000 steps each. Each run reaches turn 300 with no disaster or crash and full health, and enters no junction tile above `junction_speed` (H1) |
| `tests/sim/test_corner_cut.gd` | 1 | 2 | E6: a pure-pursuit driver that aims 2 or 2.5 tiles ahead, on seeds 0–7. It leaves the road next to the first junction, and its rejoin decides the turn. It ends with 1–99 health. Across the 16 runs, it rejoins on the first and on the second tile past the junction |
| `test_game_state.gd` | 12 | 3 | It starts in `TITLE`, and `start_run()` resets the stats. Pause and resume pause the tree. Wrong and missed turns are disasters, health and off-road crashes, and `run_ended` carries the cause and the stats. Game over, then a retry. Quitting to the title unpauses, and does nothing in `TITLE`. An invalid change is an error and changes nothing, and a paused run can't end. Every state can quit to the title. Each test uses a new `GameState`, not the autoload |
| `test_input_router.gd` | 7 | 4 | With nothing held, it steers straight. The last key pressed wins until it is released. A touch steers by the half where it started. Touches and keys mix, and the last one wins. Disabled, it steers straight and ignores input. Losing focus, by either notification, releases everything held (H4). An autopilot steers instead of the player |
| `test_hud.gd` | 7 | 4 | The version and the seed; turns, health and the distance in metres. The pause action and II both pause and resume. The end of a run shows why and how to retry. A tap or Enter retries only once the game is over. A retry may take the HUD out of the tree (H6) |
| `test_camera_rig.gd` | 4 | 4 | The zoom step for 360×640, 640×360, 1920×1080, 200×200 and 500×500 (H26). The zoom follows size changes. It looks ahead, and in portrait keeps the car low. It catches up with its target smoothly |
| `test_car_controller.gd` | 3 | 4 | The grid headings N, E, S and W get frames 3, 5, 11 and 13, NE gets 4 and NW 0 (H21). It steps its sim with the input and moves with it. Dust flies only while the car is off the road |
| `tests/integration/test_main_scene_boot.gd` | 8 | 4 | The main scene in a 360×640 `SubViewport`, with input pushed through the viewport as on a device. With the autopilot, 600 frames and no errors, and the HUD shows the turns and metres (H30). The distance is the farthest point reached (H27). With no input, the first junction ends the run. With the autopilot, the end of a run is an error (H17). A key released while paused is not missed (H3). Losing focus pauses the run and releases the keys (H4). A tap on II pauses without steering (H9). A click works like a tap and leaves Enter alone (H7, H8) |
| `test_smoke.gd` | 4 → 3 | 4 | The project name. The HUD shows the version and the seed (`--seed=1`). Every character of every label and button, the digits, the minus sign and every message is in the default font. M1's fast-forward test goes with the viewer |

- 52 tests become 128: 77 are new, and one goes.
- GUT fails a test on any `push_error()` or engine error that the test doesn't expect with `assert_push_error()`. So "no errors" in the boot test needs no assert of its own.
- No test retries. A retry reloads the current scene, which under GUT is GUT itself. `test_hud.gd` checks the signal, and E12 checks the reload by hand.
- `CarSim`'s tests are split by topic, as in IP's M2 tests table, and the sim tests cover `Autopilot`.

---

## 6. Verification

### 6.1 Local checks

The commands are those of M0_PLAN.md §6.1: `lint.sh`, `import.sh`, `check_scripts.sh`, `run_tests.sh` and `smoke.sh` in `tools/ci/`. Every PR state was rebuilt from `m2/prototype` on top of #23 (938c7b2), and all five passed:

| State | `check_scripts` | GUT tests | Asserts | GUT time | `smoke.sh` prints |
|---|---|---|---|---|---|
| M1 (938c7b2) | 29 | 52 | 143,469 | 7.3 s | `autopilot: tile 1440, turns 247, area desert` |
| PR 1 | 31 | 69 | 143,576 | 6.9 s | the same |
| PR 2 | 38 | 88 | 143,809 | 12.6 s | the same |
| PR 3 | 41 | 100 | 143,852 | 12.1 s | the same |
| PR 4 | 50 | 128 | 143,964 | 12.3 s | `autopilot: tile 165, turns 35, area rural` |

PRs 1–3 keep M1's main scene, so their smoke line is M1's. Repeated runs of a state differ by up to 0.7 s. In every state:
- `lint.sh` reports `Actions storage: no caches, artifacts kept 1 day (5 files checked)`;
- `smoke.sh` also prints `grey box: tilesets built in … ms`;
- `git status` is clean after the checks, so `import.sh` creates no files (§4.1 step 4).

### 6.2 Negative cases

For each case, make the temporary change in the PR state listed, run the checks named under "Expected", then revert. A script did this for all 46 cases on `m2/prototype` (c9fdb44), and again for the 24 cases of PRs 1–3 on their own PR states. Every result below was reproduced.

"The two II tests" are `test_a_tap_on_the_pause_button_pauses_without_steering` and `test_a_click_works_like_a_tap_and_leaves_enter_alone`. "With IP's design" says what happens with the same problem if IP is followed as written:
- **Fails ✓:** one of IP's M2 tests fails too.
- **Not tested:** none of IP's tests would catch it.
- **Not specified:** IP doesn't say which behaviour is right.
- **IP's design:** the change is what IP describes.
- **Not in IP:** IP doesn't have the feature.

| # | PR | Temporary change | Expected | With IP's design |
|---|---|---|---|---|
| N1 | 2 | `CarSim` brakes at the constant `BRAKE` (IP M2.2) | GUT fails: `test_300_turns_on_20_seeds`, `test_brakes_at_the_brake_distance_whichever_exit_it_takes`, `test_enters_the_junction_at_junction_speed_from_the_speed_cap` | IP's design: its own 300-turn test fails (H1) |
| N2 | 2 | `Autopilot` connects a lambda that uses `self` to `sim.health_changed` | GUT passes, but `run_tests.sh` fails: "Objects leaked at exit: a cycle of RefCounted references, or a node that is never freed" | GUT exits 0 (H16) |
| N3 | 1 | `on_rejoin()` compares `tile.junction == next_junction` (IP M2.3) | `check_scripts.sh` passes. GUT fails the 5 rejoin tests of `test_junction_trigger.gd`. From PR 2 on, it also fails `test_cutting_the_corner_completes_the_turn_with_damage`, `test_rejoining_stops_the_damage` and `test_rejoining_on_a_dead_end_is_a_disaster_and_the_car_stops` | IP's design: its rejoin tests fail (H5) |
| N4 | 1 | Leaving the junction back through its entry edge decides an exit | GUT fails: `test_going_back_out_of_the_entry_edge_decides_nothing` | Not tested |
| N5 | 1 | No `has_exit()` check: an edge without road decides an exit | GUT fails: `test_an_edge_without_road_decides_nothing` | IP's design (H11) |
| N6 | 2 | "Near" is only the junction cell itself | GUT fails: `test_cutting_the_corner_completes_the_turn_with_damage`, `test_near_is_at_most_one_step_from_the_junction` | Not specified (H12) |
| N7 | 2 | "Near" is up to 2 steps from the junction cell | GUT fails: `test_near_is_at_most_one_step_from_the_junction` | Not specified (H12) |
| N8 | 2 | `CarSim` never reports a rejoin to the trigger | GUT fails: `test_cutting_the_corner_completes_the_turn_with_damage`, `test_rejoining_on_a_dead_end_is_a_disaster_and_the_car_stops` | Fails ✓ |
| N9 | 4 | The `InputRouter` pauses with the tree (no `process_mode = ALWAYS`) | GUT fails: `test_a_key_released_while_paused_is_not_missed` | IP's design (H3) |
| N10 | 4 | The pause message uses ↑, which the default font lacks | GUT fails: `test_main_scene_text_has_every_glyph_in_the_default_font` | Not tested |
| N11 | 4 | `main.gd` prints `autopilot reached tile …` instead of `autopilot: tile …` | `smoke.sh` fails: "The main scene reported no autopilot progress" | Not tested (M1 G17) |
| N12 | 4 | The autopilot stops steering after 40 tiles | `smoke.sh` fails: "Errors during smoke run", on `ERROR: main: the autopilot's run ended: missed_turn`. GUT fails: `test_300_turns_on_20_seeds` | `smoke.sh` passes (H17); IP's 300-turn test fails |
| N13 | 3 | The transition table lets a paused run end | GUT fails: `test_a_paused_run_cannot_end` | `plan.md` §7.3 reads as if it can (H25) |
| N14 | 2 | No straightening without input | GUT fails: `test_with_no_input_it_straightens_up_to_the_nearest_grid_direction` | Not tested |
| N15 | 3 | A missed turn counts as a crash | GUT fails: `test_wrong_and_missed_turns_are_disasters`, `test_every_state_can_quit_to_title` | Not tested |
| N16 | 4 | The `InputRouter` keeps what is held when the window loses focus | GUT fails: `test_losing_focus_releases_everything_held`, `test_losing_focus_pauses_the_run_and_releases_the_keys` | Not in IP (H4) |
| N17 | 4 | The first input held wins instead of the last | GUT fails: `test_the_last_key_pressed_wins_until_it_is_released`, `test_touches_and_keys_mix_and_the_last_one_wins` | Not tested |
| N18 | 4 | II takes focus (`focus_mode` ALL, Godot's default) | GUT fails: `test_a_click_works_like_a_tap_and_leaves_enter_alone` | IP's design: a default button (H7) |
| N19 | 4 | II passes pointer events on (`mouse_filter` PASS) | GUT fails: the two II tests | Not tested (H9) |
| N20 | 4 | II ignores pointer events (`mouse_filter` IGNORE) | GUT fails: the two II tests | Not tested (H9) |
| N21 | 4 | No `emulate_touch_from_mouse` | GUT fails: `test_a_click_works_like_a_tap_and_leaves_enter_alone` | IP's design (H8) |
| N22 | 1 | `find_area()` returns null for an unknown id, without an error | GUT fails: `test_the_generator_finds_each_area_by_id` | Not in IP (H24) |
| N23 | 1 | `validate()` accepts a `junction_speed` above `BASE_TOP_SPEED` | GUT fails: `test_validate_reports_driving_values_the_car_cannot_use` | Not in IP |
| N24 | 1 | `validate()` accepts a `junction_brake_distance` of 0.5 | GUT fails: `test_validate_reports_driving_values_the_car_cannot_use` | Not in IP (H1) |
| N25 | 4 | No `push_error` when an autopilot run ends | GUT fails: `test_with_the_autopilot_the_end_of_a_run_is_an_error` | IP's design (H17) |
| N26 | 4 | The HUD pauses with the tree (no `process_mode = ALWAYS`) | GUT fails: `test_a_key_released_while_paused_is_not_missed` and the two II tests | IP's design (H3) |
| N27 | 4 | `main.gd` doesn't pause when focus is lost | GUT fails: `test_losing_focus_pauses_the_run_and_releases_the_keys` | Not in IP (H4) |
| N28 | 2 | `cells_crossed()` skips the corner neighbour | GUT fails: `test_a_move_enters_each_cell_it_crosses_in_order` | IP's design (H10) |
| N29 | 2 | No off-road damage | GUT fails: `test_cutting_the_corner_completes_the_turn_with_damage`, `test_leaving_the_road_does_damage_every_step`, `test_running_out_of_health_is_a_crash` | Fails ✓ |
| N30 | 2 | No off-road slowdown | GUT fails: `test_the_speed_drops_off_the_road` | Not tested |
| N31 | 2 | Braking starts half a tile late | GUT fails: `test_brakes_at_the_brake_distance_whichever_exit_it_takes` | Fails ✓ |
| N32 | 2 | The top speed never grows | GUT fails: `test_the_top_speed_grows_with_the_run_up_to_the_cap` | Fails ✓ |
| N33 | 2 | The off-road limit near a junction is a crash | GUT fails: `test_the_offroad_limit_near_a_junction_is_a_missed_turn` | Fails ✓ |
| N34 | 2 | `CarSim` doesn't move the road buffer along | GUT fails: `test_300_turns_on_20_seeds` | IP's design (H19) |
| N35 | 4 | A touch steers by the opposite half | GUT fails: `test_a_touch_steers_by_the_half_where_it_started`, `test_touches_and_keys_mix_and_the_last_one_wins` and the two II tests | Not tested |
| N36 | 4 | The camera keeps the car high on a portrait screen | GUT fails: `test_it_looks_ahead_and_in_portrait_keeps_the_car_low` | Not tested |
| N37 | 4 | Car frames truncate instead of rounding | GUT fails: `test_the_grid_headings_get_the_nearest_of_16_frames` | Not tested |
| N38 | 4 | Dust flies all the time | GUT fails: `test_dust_flies_only_while_the_car_is_off_the_road` | Not tested |
| N39 | 4 | A tap retries before the game is over | GUT fails: `test_a_tap_or_enter_retries_only_once_the_game_is_over` and the two II tests | Not in IP (H28) |
| N40 | 3 | `quit_to_title()` leaves the tree paused | GUT fails: `test_quit_to_title_unpauses`, `test_every_state_can_quit_to_title` | Not tested |
| N41 | 4 | Input stays on after the run ends | GUT fails: `test_with_no_input_the_first_junction_ends_the_run` | Not tested |
| N42 | 4 | The distance follows the car back | GUT fails: `test_the_distance_is_the_farthest_point_reached` | Not specified (H27) |
| N43 | 2 | IP's rejoin order: `on_rejoin()`, then `DRIVING` (IP M2.2) | GUT fails: `test_rejoining_on_a_dead_end_is_a_disaster_and_the_car_stops` | IP's design (H2) |
| N44 | 2 | `cells_crossed()` always enters the x neighbour first | GUT fails: `test_a_move_enters_each_cell_it_crosses_in_order` | Not specified (H10) |
| N45 | 4 | The HUD marks the retry handled after emitting `retry_requested` | GUT fails: `test_a_retry_may_take_the_hud_out_of_the_tree` | Not in IP (H6) |
| N46 | 4 | `main.gd` pauses only on `NOTIFICATION_APPLICATION_FOCUS_OUT`, which the Web never sends | GUT fails: `test_losing_focus_pauses_the_run_and_releases_the_keys` | Not in IP (H4) |

### 6.3 Editor warnings

None of the five checks reports GDScript warnings. A probe asked the editor's language server for them instead: it starts `godot --headless --editor --lsp-port <port>` and opens every `.gd` file outside `addons/` and `.godot/`. On PR 4's state it reports 8 warnings in 50 scripts, all in M1's code (H29):
- INTEGER_DIVISION: `tests/unit/test_greybox_atlas.gd` (4), `tests/unit/test_iso.gd`, `world/greybox_atlas.gd`, and `ui/main.gd:33`, the `grey box:` line that PR 4 keeps from M1;
- UNUSED_VARIABLE: `tests/unit/test_road_generator_occupancy.gd`.

Without `EventBus`'s `@warning_ignore_start("unused_signal")`, it reports 18: one UNUSED_SIGNAL for each of the 10 signals (H23). The probe isn't committed (§9).

### 6.4 Verified only in CI or on devices

| Check | PR | Result |
|---|---|---|
| The five checks on GitHub; the `test` job time against M1's 62–89 s (Q11) | 1–4 | To do |
| The Web build in Chrome and Firefox (E12) | 4 | To do |
| The debug APK on the Galaxy Z Fold4, folded and unfolded, with the zoom and the margins (E12, H18) | 4 | To do (owner, §7) |
| https://pompomon.github.io/roadgame/ runs the game after the merge | 4 | To do |

### 6.5 Measurements (prototype, local)

- **GUT.** In PR 4's state, `test_300_turns_on_20_seeds` takes 5.1 s of GUT's 12.3 s, about 0.25 s a seed (H15). M1's 200 × 500 occupancy test takes 3.6 s.
- **IP's braking** (H1, N1). With the constant `BRAKE`, the autopilot ran out of health on all 20 seeds, at turns 76–98. On each seed, its fastest entry into a junction tile was 1.94–2.21 tiles/s above `junction_speed`.
- **Step size** (H11). At the cap of 7 tiles/s, a 1/60 s step moves 0.117 tiles. The road is 0.32 tiles wide on each side of its centreline (`ROAD_HALF_WIDTH`), so it ends 0.18 tiles before an edge without road.
- **Cutting corners** (H12, E6). A pure-pursuit driver that aims further along the path than the autopilot's 0.9 tiles drove to the first junction on 8 seeds. J+1 is the first tile past the junction.

  | Aims ahead | Completes the turn | Rejoins at | Health left |
  |---|---|---|---|
  | 1.5 tiles | 8 of 8 | J+1 | 92.5 |
  | 2.0 tiles | 8 of 8 | J+1 | 74–76 |
  | 2.5 tiles | 8 of 8 | J+1 or J+2 | 59.5–77 |
  | 3.0 tiles | 2 of 8; 6 crash | J+2 | 60 |

  `test_corner_cut.gd` uses 2.0 and 2.5.
- **Retry** (H6, Q2). A probe ran the real main scene with `--seed=1` and no input, and pushed a tap 10 frames after each game over:
  - Runs 1 and 2 both ended with `wrong_turn` at frame 148: turn 0, 4.0 tiles, city. The forced seed gives the same road each time (H28).
  - After each tap, the state went to TITLE as the old scene left the tree. The new scene started the next run with one `Main` in the root, the tree unpaused and the state RUNNING. Run 3 was still RUNNING 120 frames later.
  - The grey box took 59 ms to build the first time and 2 ms on each reload.
  - With the HUD's old order (N45), each retry printed `SCRIPT ERROR: Cannot call method 'set_input_as_handled' on a null value.` at `hud.gd:51`.
- **Zoom** (H26, E9), measured with `--resolution` under Xvfb. "Visible" is the view after `expand` and integer scaling. The Fold4 sizes are its full screens; E12 shows what Android leaves to the game.

  | Window | Screen | Visible | Zoom | Tiles across the shorter side |
  |---|---|---|---|---|
  | 360×640 | The base size | 360×640 | 1 | 5.03 |
  | 904×2316 | Fold4 cover, portrait | 360×922 | 1 | 5.03 |
  | 2316×904 | Fold4 cover, landscape | 1639×640 | 2 | 4.47 |
  | 1812×2176 | Fold4 inner, portrait | 532×640 | 2 | 3.72 |
  | 2176×1812 | Fold4 inner, landscape | 768×640 | 2 | 4.47 |
  | 1080×2400 | A common phone | 360×800 | 1 | 5.03 |
  | 1280×720 | Desktop | 1137×640 | 2 | 4.47 |

  On the inner screen in portrait, 5 tiles across would need zoom 532 / (5 × 71.55) = 1.49, which is nearer to 2 by ratio (H26).
- **Margins** (H18, Q17). Screenshots under Xvfb (`DisplayServer.screen_get_image(0)`), and the bounding box of the pixels that aren't black:

  | Window | Drawn area | Inset (x, y) | Area covered |
  |---|---|---|---|
  | 360×640 | 360×640 | 0, 0 | 100% |
  | 904×2316 | 720×1844 | 92, 236 | 63% |
  | 1812×2176 | 1596×1920 | 108, 128 | 78% |
  | 2176×1812 | 1536×1280 | 320, 266 | 50% |

  With `scale_mode="fractional"`, the view fills every screen, and the visible sizes and zooms stay the same (window.cpp:1380–1401).
- **Junction gaps** (H31). Over 200 seeds × 300 turns, the game schedule's largest gap between consecutive junctions is 14 path tiles. A test schedule alternates two areas, with straights of exactly 20 tiles and a tunnel at each switch, and passes `validate()`:
  - with 10-tile tunnels, the trigger stops judging at turn 5 (`ERROR: JunctionTrigger: no junction after path index 128`);
  - with 20-tile tunnels, it stops at turn 2 (path index 45).
- **Grey box.** The tilesets take 59–63 ms to build headless, in every PR state.

---

## 7. Owner actions

These need the repository owner. The current state was read with `gh api` on 2026-11-07.

| When | Action | How |
|---|---|---|
| Now | Answer Q1–Q17, or accept the defaults | §3 |
| Before PR 4 merges | The E12 checks on the Galaxy Z Fold4. The Web checks are done in the PR | §4, PR 4 step 3 |
| Optional | Delete each PR's branch after it merges, so GitHub retargets the next PR by itself | The **Delete branch** button on the merged PR (§4.5, step 5) |

Done since M1: `lint` is a required check in ruleset "Test" (id 26672445), with `test`, `export-web` and both `export-android` checks. Ruleset "Copilot" (id 26740665) has only its review rule, so it no longer restricts deletions. The repository doesn't delete merged branches automatically.

---

## 8. M2 risks

| Risk | Impact | Mitigation |
|---|---|---|
| The 300-turn test adds about 5 s to GUT (H15) | A slower `test` check | Measure in PR 2 against M1's 62–89 s. Use fewer seeds if the job regularly takes more than 100 s (Q11) |
| The car and the camera move in `_physics_process` at 60 Hz, without physics interpolation | Uneven motion on screens whose refresh rate isn't a multiple of 60 Hz | E12 looks for it. If it shows, turn on `physics/common/physics_interpolation` (M6) |
| On Android, a tap sends Godot's emulated mouse press before the touch, the reverse of the desktop order that the tests use (input.cpp:850–860, 908–943) | II could pause twice or steer, or a retry could fire twice | The design doesn't depend on the order: II stops every touch on it, and only a touch or Enter retries. E12 checks it on the Fold4 |
| On a desktop with a touchscreen, Godot doesn't turn clicks into touches (H8) | The mouse can't steer there | Accept: keys and touch still work |
| A tap or Enter retries at once (Q2) | A player who taps as the run ends starts a new run without seeing why it ended | E12 tries it. Q2's alternative adds a short delay, and M3's game-over screen replaces this one (§9) |
| On the Web, losing focus reaches the game's nodes only as the canvas's blur (H4) | If the canvas doesn't blur when the player switches tabs or windows, a held key stays held and the run goes on | E12 switches tabs and windows in Chrome and Firefox while holding a key |
| The inner Fold4 screen shows 3.7 tiles across in portrait (§6.5) | Junctions may come into view too late to choose | E12 checks it. M6 tunes `VISIBLE_TILES` and `CAMERA_ZOOMS` if needed (§9) |
| Black margins on the Fold4 (H18) | The game covers 50–78% of the inner screen and 63% of the cover screen | E12 shows them, and M6.1 decides (Q17) |
| Braking for a junction from the cap of 7 tiles/s reaches about 30 tiles/s² (Q1) | It may look abrupt | E12 looks at it. M4 can raise `junction_brake_distance` (1–3 tiles) |
| The smoke line changes with any driving or road value | The line in E11 and §4 goes stale | `smoke.sh` checks only for a tile above 0 and no errors; PR 4 compares the full line once |
| `push_error` doesn't stop a release build | A broken rule goes unnoticed in the game | Every CI script fails on error lines (M0 F10), and a test covers each rule (§6.2) |
| Squash merges of stacked PRs | Conflicts, or a lost review fix | §4.5: merge PR n's final branch first, then check `git diff --name-only origin/main` |
| The PRs drift from the prototype after reviews | The prototype stops being a reliable reference | PR 4's tree check shows every difference (§4, PR 4 step 2) |
| `m2/prototype` disappears before PR 4 merges | PRs can't check files out | Keep it until PR 4 merges |

---

## 9. Notes for later milestones

- **M3:**
  - `main.gd`'s `_end_run()` calls `GameState.end_run()` and then `show_game_over()` at once. M3's disaster and crash sequences go between the two.
  - Keep the four causes (`wrong_turn`, `missed_turn`, `health`, `offroad`) rather than IP M3's `&"crash"` (M3.3) and `&"disaster"` (M3 tests). `GameState` treats the first two as disasters (§5.5).
  - `JunctionTrigger.disaster_triggered` passes the exit taken (`choice`, −1 for a missed turn). `EventBus.disaster_triggered` passes the area and the junction.
  - IP M2.1 has the `DisasterDirector` turn input off. M2's `_end_run()` does it (N41).
  - IP M3.3's retry rebuilds the run without reloading the scene. It uses GAME_OVER → RUNNING, which §5.5's table already has. The HUD hides II when a run ends, and in M2 only the reload brings it back.
  - Game over shows the area reached: `GameState.stats()` has `area_id`.
  - If E12 finds accidental retries, add Q2's delay.
- **M4:**
  - M4.1 adds the rest of `AreaDef`. M2 adds only the six driving fields (§5.2) and M4.2's values for the four areas.
  - H31: make `AreaSchedule.validate()` check that a set piece plus the longest straight of the area it leads into stays within `BUFFER_REFILL_AT` (25 tiles), so the next junction is always in the buffer (§6.5).
- **M5:** M5.1 draws the 16 car frames at the angles of §5.7: N, E, S and W are frames 3, 5, 11 and 13, 4.07° off the grid directions (H21). Its car and dust art replace M2's arrow and particles, and M5.3 adds the engine sound (H20).
- **IP §5.4:** M2 has no F3 debug overlay.
- **M6:**
  - M6.5 asks for at least 5 tiles ahead on both Fold4 screens. At zoom 2, the inner screen shows 3.7 tiles across in portrait and 4.5 in landscape (§6.5). If E12 finds that too little, revisit `VISIBLE_TILES` and `CAMERA_ZOOMS`.
  - M6.1 decides how to fill the screen (Q17, H18). `CameraRig` already picks its zoom again on `size_changed`.
  - M6.5's touch checks ("last touch wins", "the pause button never steers") have desktop tests in M2. The device checks stay.
- **Optional:** a CI check for editor warnings, built on §6.3's language-server probe.
