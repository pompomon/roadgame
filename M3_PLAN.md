# M3 Failure — Detailed Plan

Status: proposed, with the Q1–Q13 defaults applied · 2026-11-08 · Scope: `IMPLEMENTATION_PLAN.md` (below: **IP**) §3 M3 row, §4 M3.1–M3.3 and "M3 tests", and the M3 row of §6

**Verified, not just reviewed.** Every file this plan adds or changes exists on branch `m3/prototype` (2dff52b) and was run with the tools below. Each PR state in §4 was rebuilt from that branch on top of `main` (73256cf) and passed the five local checks (§6.1). The 55 negative cases in §6.2 were run on the prototype and on their PR states, and the stacked landing was simulated (§4.5). A CI run on the prototype built the Web and Android exports, and the Web build ran in headless Chromium: two sinkholes, a crash and three retries, with no errors (§6.5).

- Godot 4.7.2-stable (Linux x86_64)
- GUT 9.7.1
- gdtoolkit 4.5.0 on Python 3.12
- shellcheck 0.11.0
- actionlint 1.7.12

Some things could not be run here: a headed Chrome, Firefox and the Galaxy Z Fold4. They are checked in PR 3 (E13, §6.4).

**Precedence.** For M3, this document replaces IP §4 M3 wherever they differ. Each difference is marked **Δ** with its finding number (J#, §2). Where it differs from `plan.md`, it says so too (J5). Once this plan is approved, fold the changes back into IP (Q12).

**Reference code (Q13).** This plan has no appendices: each PR checks its files out of `m3/prototype` (§4.1). Don't open a PR from that branch, because the three PRs carry its code. Pushes to it start nothing: `ci.yml` runs only for pull requests, pushes to `main` and manual runs. Its `ci.yml` is `main`'s, so a manual run saves no caches and keeps artifacts for one day (M0 F34).

**Prerequisites.** M2 is merged (#24–#28), and so is `AGENTS.md` (#29). No repository settings change.

Contents:
1. Goal and exit criteria
2. Review findings
3. Decisions and open questions
4. Work breakdown (3 PRs)
5. Design
6. Verification
7. Owner actions
8. M3 risks
9. Notes for later milestones

---

## 1. Goal and exit criteria

Goal (IP §3): "Wrong or missed turn → Sinkhole → game over → retry; crash path works". In M2 a run ends with game over at once, and a tap or Enter reloads the scene. In M3 the run ends at once too, but the game over waits: the car stops, a disaster from the area's pool plays (or, after a crash, the car smokes), and then the game-over screen shows the cause and the run's stats. Retry starts the next run in place, without reloading the scene.

| # | Exit criterion | Checked by |
|---|---|---|
| E1 | Once the run is over, the car brakes in a straight line along its heading, at `BRAKE` or harder, and stops within `STOP_SECONDS` (0.6 s) of the step that ended the run, from any speed up to the cap. It doesn't steer (J4) | `test_car_sim_speed.gd` |
| E2 | `DisasterParams` come from the run's disaster stream: the same seed gives the same params, different seeds different ones, the stream goes on from one disaster to the next, and every value is in its range. The origin is where the car stopped (J17) | `test_disaster_params.gd` |
| E3 | After a wrong or missed turn, `DisasterDirector` waits for the car to stop, picks a scene from the area's pool with the disaster stream, adds it to the layer it is given and plays it. It ends the sequence once, when the disaster finishes, and `DISASTER_TIMEOUT` (6 s) after the end of the run at the latest, with an error. A second sequence, an empty pool and a scene that isn't a disaster are errors; the last two end the sequence. `clear()` frees the disaster at once (J13) | `test_disaster_director.gd` |
| E4 | After a crash, the car turns to its grey crash frame without a redraw and smokes, from a fixed seed (J16), the camera shakes, and the sequence ends `CRASH_SECONDS` (1.2 s) after the crash. No disaster plays (J22) | `test_car_controller.gd`, `test_disaster_director.gd`, `test_crash.gd` |
| E5 | `CameraRig.shake()` moves only the camera's offset, by the same amount on screen at every zoom, with no randomness. It fades out and ends, a new shake replaces the last, and `stop_shake()` ends it at once | `test_camera_rig.gd` |
| E6 | The sinkhole waits for `play()`, then for its params' delay. It opens under the car by its scale, without a redraw, throws debris from its params' particle seed, direction, intensity and scale, and shakes the camera. The car then shrinks and darkens, and it finishes once. With the stop, it takes 2–4 s from the turn for any params (J20). It works without a car or a camera | `test_sinkhole.gd` |
| E7 | Every area of the game has a disaster pool, and every scene in it is a disaster with an id (J6) | `test_area_schedule.gd`, `test_sinkhole.gd` |
| E8 | A wrong exit at the third junction ends the run once, in the City, with the input off and no pause button. The City's sinkhole plays on World's `DisasterLayer` and swallows the car. Esc doesn't pause it. The game-over screen shows 2–4 s after the turn, with the cause and the stats. The same seed plays the same disaster | `test_wrong_turn_disaster.gd` |
| E9 | The game-over screen shows the cause, the distance, the turns and the area reached, and the seed in debug builds only (J19). Retry takes the focus, so Enter and Space press it. A tap or a click on Retry retries once. A closed screen gives the focus back and can't retry. Every glyph it can show is in the default font | `test_game_over.gd`, `test_retry.gd`, `test_smoke.gd` |
| E10 | Retry starts the next run in place (J12). `GameState`, the HUD, the road, the car, the camera, the input and the director all start afresh. The last run's car, disaster, `CarSim` and road are freed at once, and no orphan nodes are left (J13). A forced `--seed` stays (J18). Three runs in a row work, and a retry outside game over is an error | `test_retry.gd`, `test_hud.gd`, `test_world_renderer.gd` |
| E11 | Disasters draw above the road and below the car (J5) | `test_world_renderer.gd`, `test_wrong_turn_disaster.gd` |
| E12 | The main scene still boots and drives, and with no input the first junction ends the run, now in `DISASTER`. The smoke run prints `autopilot: tile 165, turns 35, area rural` and no error lines, as in M2 | `test_main_scene_boot.gd`, `smoke.sh` |
| E13 | Manual: the Web build in Chrome and Firefox, and the debug APK on the Galaxy Z Fold4. A wrong turn plays the sinkhole and then game over; a crash smokes and then game over; Retry works by tap, click and Enter; no errors in the console or `adb logcat` | PR 3 (§4, PR 3 step 3) |
| E14 | All five required checks are green. The editor reports no new warnings (J25) | PR checks; §6.3 |

---

## 2. Review findings

IP's M3 design holds up in its parts: a director that picks a scene from the area's pool with a seeded stream, a `play(params)` and `finished` interface, a timeout, and a retry without a reload. The problems are in how they meet M2's code:
- a run that ends only after its disaster, so the game is still running during it;
- tweens, which tests can't step and which `CarController` undoes;
- a car that slides on long after a crash;
- a disaster layer above the car it swallows;
- a HUD, a renderer and a retry that assume the scene reloads.

- **High:** following IP gives a broken game, or a check that passes when it shouldn't.
- **Medium:** fragile, missing from the code it depends on, or broken in some order of events.
- **Low:** clarity, naming or polish.

"Prototype" means the problem was reproduced with Godot 4.7.2 on `m3/prototype`, with the probes P1–P9 (§6.5) or the negative cases N# (§6.2). "Source" means the code at the 4.7.2-stable tag, or GUT 9.7.1's, which the file and line numbers refer to. Line numbers in the repository's files are `main`'s (73256cf).

### High

| # | Finding | Evidence | Fix |
|---|---|---|---|
| J1 | IP M3.1 moves `GameState` to `DISASTER` at the trigger, and then calls `end_run(&"disaster")` after the disaster's `finished`; M3.3 calls `end_run(&"crash")` after the crash's 1.2 s. In M2's `GameState`, `end_run()` is the only way into `DISASTER` or `CRASH`, and only from `RUNNING`. So IP's second call is an invalid transition, and without the first, the game stays `RUNNING` while the disaster plays: the player can pause it, which freezes it, the pause button stays, the distance keeps counting, and `run_ended` comes 2–4 s late. And `&"disaster"` and `&"crash"` aren't causes: `end_run()` takes one of `CarSim`'s four, which the game-over screen shows, and picks `DISASTER` or `CRASH` from it. IP's test expects `run_ended(&"disaster")`. | `game_state.gd:8–15`: only `RUNNING` goes to `DISASTER` or `CRASH`, and they go only to `GAME_OVER` or `TITLE`. `game_state.gd:61–62`. `main.gd:96–100`: M2 ends the run at the trigger, then shows game over at once. Prototype: P6; N35 | **Δ IP M3.1, M3.3:** `main.gd` ends the run at the turn or the crash, with `CarSim`'s cause, as M2 does: the input stops and `run_ended` fires once (§5.2). The director then plays the end in `DISASTER` or `CRASH`, where nothing pauses, and `main.gd` calls `show_game_over()` when it ends. The wrong-turn test expects `run_ended` with `CarSim.WRONG_TURN` at the turn, and game over 2–4 s later (E8; N35–N37) |
| J2 | IP M3.1 "tween[s] the car to a stop", and M3.2 sinks it with a "scale/position tween". GUT's `simulate()` only calls `_process()` and `_physics_process()` on a node and its children, so Tweens and timers don't move in tests. Every timing test would have to wait in real time, or not test the timing at all. | Source: `addons/gut/gut_to_move.gd:62–92`. Tweens and `SceneTreeTimer`s are processed by the `SceneTree`, not by nodes. Prototype: P1 | Every M3 timing runs on `_physics_process` deltas: the stop in `CarSim` (J4), the director's clock, the sinkhole's phases and the shake. `DisasterBase` says so for every disaster (§5.5) |
| J3 | IP M3.2's tween moves the car's position, but `CarController` sets its position from `CarSim` every physics frame, which undoes it. | `car_controller.gd:33`. Prototype: P7; N25 | **Δ IP M3.2:** the car stops by `CarSim` (J4) and stays where it stopped. A disaster may change only the car's `scale` and `modulate`, which `CarController` leaves alone (N23, N25) |
| J4 | Once the run is over, M2's car brakes at `BRAKE`, 4 tiles/s². From the cap of 7 tiles/s it rolls 6.1 tiles in 1.75 s, longer than a crash's 1.2 s: the game-over screen would show with the car still moving. IP's 0.6 s tween can't fix it (J2, J3). | `car_sim.gd:68–69`, `tuning.gd:26`. Prototype: P8 measured a crash at 5.73 tiles/s rolling 4.06 tiles in 1.45 s | **Δ IP M3.1:** no tween. Once the run is over, `CarSim.step()` brakes at max(`BRAKE`, speed / `STOP_SECONDS`), worked out at the first step after the end, in a straight line along the car's heading. It stops within 0.6 s: 1.72 tiles from 5.73 tiles/s. A wrong or missed turn comes at about `junction_speed` (P9), so the car stops in about 0.5 s and 0.5 tiles, in the exit it took: "into the dead end", if it took one (N1–N3) |
| J5 | `plan.md` §7.1 and IP §5.2 put `DisasterLayer` under `Main`, after `World`. It would then draw over everything in `World`, the car included: the sinkhole would cover the car it swallows. | `plan.md` §7.1; IP §5.2. Prototype: N44, N45 | **Δ `plan.md` §7.1, IP §5.2:** `World/DisasterLayer`, between `RoadLayer` and `Props`, so disasters draw above the road and below the car and the props (N44, N45) |

### Medium

| # | Finding | Evidence | Fix |
|---|---|---|---|
| J6 | IP M3.1 picks from `area.disasters`, which `AreaDef` doesn't have: M4.1 adds it. M3 has only the sinkhole, which `plan.md` §4.3 gives the City, but a wrong turn in another area needs a disaster too. The smoke run reaches Rural. | `area_def.gd:4`: "M4 adds the prop, disaster and audio fields"; IP M4.5 adds the other disasters | `AreaDef.disasters: Array[PackedScene]` comes in M3, and every area's pool is the sinkhole until M4.5 (Q2). An empty pool is an error that ends the sequence, so the game over still comes (N12, N33) |
| J7 | IP M3.1 calls `SaveService.record_disaster(id, area, stats)`, which M5.4 adds. | IP M5.4 | None in M3. Each disaster has an `id` for it, such as `&"sinkhole"` (N34, §9) |
| J8 | IP M3.3 has a **Title** button, but the title screen comes in M5.5. | IP M5.5 | Only **Retry** in M3. `GameState` already allows `GAME_OVER` → `TITLE` (Q5, §9) |
| J9 | M2's HUD retries on any tap or Enter in `GAME_OVER`. With buttons on the game-over screen, a tap anywhere would retry, and a tap on a button would retry as well as press it. | `hud.gd:48–51, 89–91` | **Δ IP M3.3:** the HUD no longer retries. The game-over screen's Retry takes the focus when it opens, so Enter and Space press it; a tap or a click on it retries once, and it does nothing while the screen is closed (Q9, N49–N51) |
| J10 | The HUD shows full health and 0 turns only from `_ready()`, and hides the pause button at the end of a run. M2 needed nothing more because a retry reloaded the scene. After a retry in place, the next run would start with the last run's health and turns and no pause button. | `hud.gd:36–38`, `hud.gd:84–86` | The HUD starts afresh on every `run_started` (N46) |
| J11 | `WorldRenderer.bind(buffer, schedule)` builds the tilesets and follows the buffer, once. A second call would build the tilesets again and keep drawing the last run's buffer, whose tiles stay on the layers. | `world_renderer.gd:16–27` | `build(schedule)` makes the tilesets once. `bind(buffer)` stops following the last buffer, clears the layers and draws the new one (N47, N48) |
| J12 | IP M3.3's retry "fully rebuilds `World`" and "keeps `PropPool`". `PropPool` is part of `World` (IP §2, §5.2), and rebuilding `World` means building its tilesets again: 59–63 ms headless, and 100–390 ms in browsers (M2 §6.6, §6.5 here). | IP §2, §5.2; M2_PLAN.md §6.5, §6.6 | **Δ IP M3.3:** retry keeps `World` and its tilesets, and binds the next run's buffer (J11). The road, the car and its `CarSim` are new. M4's `PropPool` must reset on `run_started` (§9) |
| J13 | A retry that frees the last car or disaster with `queue_free()` leaves it in the tree until the end of the frame: two cars under `Props` for a frame, both for the camera and for tests that look up the car. IP's retry test asks for no orphan nodes, but doesn't say when. | Prototype: N8, N38 | Retry frees the car, and `DisasterDirector.clear()` the disaster, with `free()`, at once. Neither is the object whose signal is being handled. The test checks it with GUT's `assert_no_new_orphans()` and with `is_instance_valid()` (N8, N38) |
| J14 | IP's `DisasterParams.seed` would shadow the built-in `seed()` (M1 G13, M2 H22). | M1_PLAN.md G13 | `particle_seed`: it seeds the debris, with `use_fixed_seed` (P3, N26) |

### Low

| # | Finding | Fix |
|---|---|---|
| J15 | IP M3.2 asks for a shader (`disasters/shaders/hole.gdshader`) and a clip mask for the car. The grey box needs neither: an ellipse grows by its scale, and the car shrinks and darkens instead of being clipped. | Both come with M5's art (Q3, §9) |
| J16 | IP M3.2 uses `GPUParticles2D` for the debris. | `CPUParticles2D` for the debris and the crash smoke, like M2's dust (M2 H20): no particle shader to compile when the first disaster plays. Both have `use_fixed_seed`: the debris takes its params' `particle_seed` (J14), and the smoke a seed fixed in `car.tscn`, so every crash smokes alike (§5.6; N55) (Q4) |
| J17 | IP's `DisasterParams` has `origin_world` "all from the disaster stream", but the stream can't know where the car stops. | `DisasterParams.roll(rng, origin)` draws the other five values, always in the same order, and takes the origin from the stopped car (N14) |
| J18 | IP M3.3's retry takes a new seed. M2's retry kept a forced `--seed`, so that tests and bug reports can replay a road (M2 H28). | A forced `--seed` stays for every retry; without it, each run gets a new random seed (Q7, N41) |
| J19 | IP M3.3 shows the seed on the game-over screen "in debug builds". The HUD has shown it in every build since M2 (M2 E9). | The game-over screen shows it in debug builds only. The HUD's line stays (Q6, §9, N52) |
| J20 | IP says each sequence "must finish in 2–4 s", but not from when. | From the wrong or missed turn to the game-over screen, the stop and the delay included: 2.5–3.5 s for the sinkhole (§5.5). The 6 s timeout counts from the turn too (N32) |
| J21 | IP §5.3 seeds the disaster stream "only from `GameState.seed`", but not how. | `hash("%d:disaster" % run_seed)`, as `RoadGenerator` seeds its road stream with `hash("%d:road" % run_seed)` (`road_generator.gd:40`). One stream per run, kept from one disaster to the next (N10) |
| J22 | IP M3.3's crash has a "crash frame", but there is no art until M5.1. | The arrow turns grey (`CRASH_TINT`) through `self_modulate`, without a redraw (M2 §5.7), and smokes (Q10, N21, N22) |
| J23 | IP's wrong-turn test takes the wrong exit "at turn 3". | The third junction: `turn_number` 2, after two correct turns, so `turn_index` ends at 2 |
| J24 | IP §5.1 has the `DisasterDirector` listen to `GameState`, but the director needs the car and the camera, which no signal carries. | `main.gd` calls `play_disaster(area, car, camera)` and `play_crash(car, camera)`, as it relays M2's other signals (§5.2) |
| J25 | `DisasterBase.finished` is emitted only by the disasters, so the editor reports UNUSED_SIGNAL for it. | `@warning_ignore("unused_signal")`, as `EventBus` does (M2 H23, §6.3) |
| J26 | `@abstract` makes a disaster without `play()` a parse error, but doesn't stop `DisasterBase.new()`. | Keep `@abstract`: the director only instantiates scenes, and checks that the root is a `DisasterBase` (P2, N13) |

---

## 3. Decisions and open questions

This plan applies the defaults below. Tell me if you want any of them changed.

| # | Question | Default (applied) | Alternative |
|---|---|---|---|
| Q1 | How does the car stop? | `CarSim` brakes in a straight line, at `BRAKE` or harder, so that it stops within `STOP_SECONDS` (J4) | IP's 0.6 s tween, with `CarController` reading the tweened position instead of the sim's |
| Q2 | Disaster pools until M4.5 adds the other disasters | The sinkhole in every area (J6) | Only the City's pool; a wrong turn elsewhere ends with an error and game over at once (N12) |
| Q3 | The sinkhole's shader and clip mask | With M5's art (J15) | Add `hole.gdshader` and a clip mask in M3 |
| Q4 | Particles | `CPUParticles2D` (J16) | IP M3.2's `GPUParticles2D` |
| Q5 | A **Title** button | Not until the title screen (M5.5, J8) | A button that reloads the scene until then |
| Q6 | The seed on the game-over screen | Debug builds only, as IP says. The HUD's line, from M2, stays in every build (J19) | Hide the HUD's seed in release builds too |
| Q7 | Retry with `--seed` | Keep the seed (J18) | IP's new seed every time |
| Q8 | How does retry rebuild the run? | In place, keeping `World` and its tilesets (J12) | IP's full rebuild of `World`, or M2's scene reload |
| Q9 | How does the player retry? | The Retry button, by tap, click, Enter or Space (J9) | M2's tap anywhere |
| Q10 | The crash | The grey arrow and smoke, and a shake of 0.5 for 0.4 s (J22) | No crash look until M5.1 |
| Q11 | How do the 3 PRs land? | Stacked branches, each retargeted to `main` in turn (§4.5) | One PR at a time, each opened after the previous one merges |
| Q12 | Fold this plan into IP? | After review. Until then, this document wins for M3 | — |
| Q13 | Appendices with every file, as in M0? | No: `m3/prototype` is the reference, and PRs check files out of it | Copy the files into this plan |

The values in §5.9 are first guesses for the grey box. E13 judges them on the Fold4, and M6 tunes them.

---

## 4. Work breakdown

There are three PRs, and each one leaves CI green (E14). The total estimate is about 2 days, within IP's size "M" (2–3 days), because the code exists and is verified. Most of the remaining risk is in PR 3: focus, touch and the look of the end on real devices and browsers can't be checked locally (E13).

```
PR 1 director ──▶ PR 2 sinkhole ──▶ PR 3 the game
 (M3.1; M3.3's     (M3.2)            (M3.3)
  crash)
 ~0.5 d            ~0.5 d            ~1 d
```

PRs 1 and 2 add code and tests, and the game still ends as in M2, at once, except that the car now stops within 0.6 s and a crashed car turns grey and smokes. PR 3 plays the disasters and adds the game-over screen and retry.

### 4.1 Porting from the prototype

Every PR follows the same steps:

1. Fetch the branches and create the PR's branch. The refspec also works in a clone that tracks only `main`:
   ```bash
   git fetch origin main '+refs/heads/m3/*:refs/remotes/origin/m3/*'
   git switch -c m3/1-director origin/main    # PRs 2–3: from the previous PR's branch (§4.5)
   ```
2. Check the PR's files out of the prototype with the command in its section. The globs are quoted so the `.uid` files come along.
3. There are no trims: each file belongs to one PR, whole. `config/tuning.gd` belongs to PR 1, with the sinkhole's values too.
4. Run `tools/ci/import.sh`. It must create no files: `git status --porcelain` lists only the checked-out paths.
5. Run §6.1 and compare the counts with the PR's "Expect" line.
6. Have a model of another family review it (`AGENTS.md` §7). Then commit, push and open the PR.

The three commands below were run in this order on `main` (73256cf). They checked out 23, 11 and 25 files, gave exactly the PR states of §6.1, and ended at the prototype's tree.

### PR 1: The director, the stop and the shake (M3.1; the crash of M3.3) **Δ J2–J4, J13, J14, J17, J21, J22, J24–J26**

Branch `m3/1-director`, from `main`.

| Area | Files |
|---|---|
| Tuning | `config/tuning.gd`: all of M3's constants (§5.9) |
| Car | `car/car_sim.gd`: the stop (§5.6); `car/car_controller.gd`, `car/car.tscn`: the crash frame and smoke (§5.6) |
| Camera | `world/camera_rig.gd`: `shake()` and `stop_shake()` (§5.7) |
| Areas | `areas/area_def.gd`: the `disasters` pool, empty until PR 2 (§5.3) |
| Disasters | `disasters/disaster_params.gd`, `disaster_base.gd`, `disaster_director.gd` (§5.3–§5.5) |
| Tests | `tests/unit/test_disaster_params.gd`, `test_disaster_director.gd`; more tests in `test_camera_rig.gd`, `test_car_sim_speed.gd` and `test_car_controller.gd`; `tests/helpers/stuck_disaster.gd` and `timed_disaster.gd`, test disasters for the director |

Every new `.gd` file comes with its `.gd.uid`.

```bash
git checkout origin/m3/prototype -- config/tuning.gd areas/area_def.gd car/car_sim.gd \
  car/car_controller.gd car/car.tscn world/camera_rig.gd 'disasters/disaster_params.gd*' \
  'disasters/disaster_base.gd*' 'disasters/disaster_director.gd*' \
  'tests/unit/test_disaster_params.gd*' 'tests/unit/test_disaster_director.gd*' \
  tests/unit/test_camera_rig.gd tests/unit/test_car_sim_speed.gd tests/unit/test_car_controller.gd \
  'tests/helpers/stuck_disaster.gd*' 'tests/helpers/timed_disaster.gd*'
```

No trims. Expect: `check_scripts: loaded 57 scripts`; `GUT: 171 tests passed` (144,342 asserts, 16–18 s). `smoke.sh` still prints `autopilot: tile 165, turns 35, area rural`. Negative cases N1–N23 and N55.

**Acceptance:** E1–E3 and E5; E4 except `test_crash.gd`, which needs the game (PR 3).

### PR 2: The sinkhole (M3.2) **Δ J3, J6, J15, J16, J20**

Branch `m3/2-sinkhole`, from `m3/1-director`.

| Area | Files |
|---|---|
| Disasters | `disasters/sinkhole.gd`, `disasters/sinkhole.tscn` (§5.5) |
| Areas | `areas/city.tres`, `rural.tres`, `meadows.tres`, `village.tres` and `desert.tres`: the sinkhole in every pool (Q2) |
| Tests | `tests/unit/test_sinkhole.gd`; one more test in `tests/unit/test_area_schedule.gd` |

```bash
git checkout origin/m3/prototype -- 'disasters/sinkhole.*' areas/city.tres areas/rural.tres \
  areas/meadows.tres areas/village.tres areas/desert.tres 'tests/unit/test_sinkhole.gd*' \
  tests/unit/test_area_schedule.gd
```

No trims. Expect: 59 scripts; `GUT: 182 tests passed` (144,483 asserts, 16–18 s). The smoke line is the same. Negative cases N24–N34.

**Acceptance:** E6 and E7.

### PR 3: The game: the end of a run, game over and retry (M3.3) **Δ J1, J5, J8–J13, J18, J19, J23**

Branch `m3/3-game`, from `m3/2-sinkhole`.

| Area | Files |
|---|---|
| Game | `ui/main.gd`, `ui/main.tscn`: the end of a run, game over, and retry in place (§5.2) |
| UI | `ui/game_over.gd`, `ui/game_over.tscn` (§5.8); `ui/hud.gd`: no retry, and a fresh start with each run (J9, J10) |
| World | `world/world.tscn`: `DisasterLayer` (J5); `world/world_renderer.gd`: `build()` and `bind()` (J11) |
| Autoloads | `autoload/game_state.gd`: a comment |
| Tests | `tests/unit/test_game_over.gd`; `test_hud.gd`, `test_world_renderer.gd` and `test_smoke.gd`, changed; `tests/integration/test_wrong_turn_disaster.gd`, `test_crash.gd` and `test_retry.gd`; `test_main_scene_boot.gd`, changed; `tests/helpers/main_scene.gd` and `wrong_turn_pilot.gd` |

```bash
git checkout origin/m3/prototype -- ui/main.gd ui/main.tscn ui/hud.gd 'ui/game_over.*' \
  world/world.tscn world/world_renderer.gd autoload/game_state.gd \
  'tests/unit/test_game_over.gd*' tests/unit/test_hud.gd tests/unit/test_smoke.gd \
  tests/unit/test_world_renderer.gd tests/integration/ 'tests/helpers/main_scene.gd*' \
  'tests/helpers/wrong_turn_pilot.gd*'
```

1. No trims. Expect: 66 scripts; `GUT: 200 tests passed` (144,611 asserts, 16–18 s). `smoke.sh` prints `grey box: tilesets built in … ms` and `autopilot: tile 165, turns 35, area rural`. Negative cases N35–N54.
2. Check that the stack now matches the prototype. The command prints nothing, unless a review changed something on purpose; then it lists the files of §4.6. If `main` has changed other files since 73256cf, exclude them too:
   ```bash
   git diff --stat origin/m3/prototype -- . ':!M3_PLAN.md'
   ```
3. Manual checks (E13). Start a run that uploads the builds, and download them within a day (M0 F34). `gh run download` puts each artifact in a folder named after it: `web`, `android-Android APK` and `android-Android AAB`.
   ```bash
   gh workflow run ci.yml --ref m3/3-game -f upload-builds=true
   gh run list -w ci.yml -b m3/3-game -e workflow_dispatch -L 1    # the run id
   gh run watch <run id> --exit-status
   gh run download <run id> -D /tmp/roadgame-builds
   ```
   - **Android**, on the Galaxy Z Fold4, folded and unfolded: `adb install -r "/tmp/roadgame-builds/android-Android APK/roadgame-debug.apk"`.
     - Take a wrong exit. The car stops in it, a hole opens under it with debris and a shake, and the car sinks. Then the game-over screen says "Wrong turn!", with the distance, the turns, the area and the seed (a debug build). It comes 2–4 s after the turn.
     - Leave the road until the car crashes. The arrow turns grey and smokes, the view shakes, and about 1.2 s later the screen says "You got lost off the road." or "Your car broke down.".
     - During the end, the pause button is gone, and leaving the app and coming back doesn't pause it.
     - A tap on Retry starts a new run at once: full health, 0 turns, 0 m and the pause button, and only one car. A tap elsewhere on the screen does nothing.
     - The sinkhole, the debris and the smoke are visible on both screens, at zoom 1 and zoom 2. Judge the timing and the size (§5.9).
     - `adb logcat -s godot` shows one `grey box:` line for the whole session, so no retry reloaded the scene, and no errors.
   - **Web:** run `python3 -m http.server -d /tmp/roadgame-builds/web 8000` and open http://localhost:8000 in Chrome and Firefox.
     - The same ends. After game over, Enter or Space retries, and so does a click on Retry; a click elsewhere does nothing.
     - Esc doesn't pause during the end. The arrow keys steer the next run at once, without a click first.
     - The game-over screen shows no seed, because the Web export is a release build (J19); the HUD still shows it (Q6). Only a release build can check `show_seed`'s default (§6.4).
     - The browser console shows one `grey box:` line and no errors. Open M2's Pages site in the same browser first: a WebGL warning that it doesn't show is M3's (M2 §5.7). Headless Chromium logged 4 `GPU stall due to ReadPixels` notes at startup (§6.5).
     - Headless Chromium already ran the prototype's build: two sinkholes, a crash and three retries, with no errors and no seed on the game-over screen (§6.5). The rest of these checks, in a headed Chrome and in Firefox, remain.
4. After the merge, https://pompomon.github.io/roadgame/ runs the game with M3.

**Acceptance:** E4, E8–E12 and E13.

### 4.5 Landing the stack (Q11)

This is M2_PLAN.md §4.5's procedure, which landed #25–#28, with the `m3/` names. It was checked again by simulating the squash merges with `git merge-tree`, on the PR states of §6.1.

1. Each PR branches from the previous PR's branch, and its PR targets that branch, so its diff shows only its own files. `ci.yml` runs on every `pull_request` with no branch filter, so every PR gets the five checks. Required checks only gate PRs into `main`.
2. A review fix for PR n is committed on PR n's branch and then merged (`git merge --no-ff --no-edit`) into each later branch. No rebases and no force-pushes.
3. Merge only a PR whose base is `main`. A merge into another PR's branch skips the required checks; in M0, that is why #16 was needed.
4. After PR n squash-merges, update PR n+1:
   ```bash
   git fetch origin main '+refs/heads/m3/*:refs/remotes/origin/m3/*'
   git switch <PR n+1 branch>
   git merge origin/<PR n branch>     # PR n's final state, in case a fix wasn't merged up yet
   git merge origin/main              # the squash commit
   git diff --name-only origin/main   # must list only PR n+1's files
   git push
   gh pr edit <PR n+1> --base main    # unless GitHub did it (step 5)
   ```
   - If PR n's branch is already deleted, fetch its last state with `git fetch origin pull/<PR n>/head` and merge `FETCH_HEAD` instead.
   - The simulated merges had no conflicts, and the `diff` listed only each PR's own files: 23, 11 and 25. A conflict here means that a later branch changed the same lines as a review fix of PR n. Resolve it by hand.
   - A later branch mustn't change a file that an earlier PR adds or changes, unless the earlier PR makes the same change: merging `main` is then a conflict. So a review fix goes on the branch of the PR that owns the file (step 2). PR 1 owns `config/tuning.gd`, `car_controller.gd` and `camera_rig.gd`, which PRs 2 and 3 use.
   - The merges bring no change that the branch doesn't have already, so the push may start no Copilot review. If the PR needs one, request it with `gh pr edit <PR n+1> --add-reviewer @copilot`.
5. If the owner deletes PR n's branch after the merge, GitHub retargets PR n+1 to `main` by itself, as it did for #21 and #22. Either way, step 4 is still needed: until PR n+1 merges `main`, its diff also shows PR n's files.

### 4.6 Review fixes

None yet. Each fix that the PRs' reviews bring is committed on the branch of the PR that owns the code, merged into the later branches (§4.5), and listed here with its tests and negative case.

| PR | Change | Tests | Negative case |
|---|---|---|---|

---

## 5. Design

The code on `m3/prototype` is the reference. This section summarizes it and lists what differs from IP, and why.

### 5.1 Files

| File | Class | PR | IP |
|---|---|---|---|
| `config/tuning.gd` | `Tuning` | 1 | M3.1–M3.3's values (§5.9) |
| `areas/area_def.gd` | `AreaDef` | 1 | `disasters`, from M4.1 (J6, §5.3) |
| `car/car_sim.gd` | `CarSim` | 1 | **Δ J4**: the stop instead of M3.1's tween (§5.6) |
| `car/car_controller.gd`, `car/car.tscn` | `CarController` | 1 | M3.3's crash frame and smoke **Δ J3, J22** (§5.6) |
| `world/camera_rig.gd` | `CameraRig` | 1 | M3.2's `shake()` (§5.7) |
| `disasters/disaster_params.gd` | `DisasterParams` | 1 | M3.1 **Δ J14, J17** (§5.3) |
| `disasters/disaster_director.gd` | `DisasterDirector` | 1 | M3.1, M3.3 **Δ J1, J2, J13, J20, J21, J24** (§5.4) |
| `disasters/disaster_base.gd` | `DisasterBase` | 1 | M3.1 **Δ J2, J3, J25, J26** (§5.5) |
| `disasters/sinkhole.gd`, `disasters/sinkhole.tscn` | `Sinkhole` | 2 | M3.2 **Δ J3, J15, J16** (§5.5) |
| `areas/city.tres`, `rural.tres`, `meadows.tres`, `village.tres`, `desert.tres` | — | 2 | the pools until M4.5 (Q2) |
| `ui/main.gd`, `ui/main.tscn` | (the game) | 3 | M3.1, M3.3 **Δ J1, J12, J13, J18** (§5.2) |
| `ui/game_over.gd`, `ui/game_over.tscn` | `GameOver` | 3 | M3.3 **Δ J8, J9, J19** (§5.8) |
| `ui/hud.gd` | `Hud` | 3 | J9, J10 (§5.8) |
| `world/world.tscn` | — | 3 | **Δ J5** (§5.10) |
| `world/world_renderer.gd` | `WorldRenderer` | 3 | J11 (§5.10) |
| `autoload/game_state.gd` | (autoload `GameState`) | 3 | a comment: `show_game_over()` now comes after the end has played |

All of them are in IP §2's layout, with the scripts of `sinkhole.tscn` and `game_over.tscn`. M3 adds none of `disasters/shaders/` (Q3), `ui/title.tscn` (Q5) or `autoload/save_service.gd` (J7). `GameState` keeps M2's states and transitions: M3 uses `DISASTER`, `CRASH` and `GAME_OVER` as M2 defined them (J1).

### 5.2 The end of a run (PR 3) **Δ IP M3.1, M3.3**

```
JunctionTrigger.disaster_triggered(junction, choice) ─▶ main._on_disaster_triggered
    EventBus.disaster_triggered(area, junction)        # as in M2
    _end_run(WRONG_TURN or MISSED_TURN)
    DisasterDirector.play_disaster(area, car, camera)
CarSim.crashed(cause) ─▶ main._on_crashed
    _end_run(cause)                                    # HEALTH or OFFROAD
    DisasterDirector.play_crash(car, camera)
_end_run(cause): the distance; the input off; GameState.end_run(cause) ─▶ DISASTER or CRASH, EventBus.run_ended
DisasterDirector.sequence_finished ─▶ main._on_sequence_finished
    GameState.show_game_over() ─▶ GAME_OVER
    GameOver.open(GameState.stats(), area)
GameOver.retry_requested ─▶ main._retry
    GameOver.close(); DisasterDirector.clear(); CameraRig.stop_shake(); car.free(); _start_run(seed)
```

- **The run ends at once (J1).** As in M2, the step that decides the run ends it: `GameState.end_run()` moves to `DISASTER` or `CRASH` and emits `run_ended` once, with `CarSim`'s cause. The input goes off, the distance stops counting, and the HUD hides the pause button. Nothing can pause the end: `GameState` allows `PAUSED` only from `RUNNING` (`game_state.gd:8–15`), the HUD's `toggle_pause()` does nothing in other states, and `main.gd` pauses on a focus loss only while `RUNNING` (E8; N35).
- **The end plays.** After a wrong or missed turn, `play_disaster()` gets the junction's area, `find_area(junction.area_id)`, the one that M2's `EventBus.disaster_triggered` already carries. After a crash, `play_crash()`. `main.gd` passes the car and the camera, which no signal carries (J24).
- **Game over** comes only from `sequence_finished`, which the director emits once per run (§5.4). `GameOver.open()` gets the stats and the area of `GameState.area_id`, the area the car was in when the run ended.
- **`_start_run(run_seed)`** builds every run, the first and each retry:
  1. a new `RoadBuffer` from `RoadGenerator.new(run_seed, schedule)`, relayed to `EventBus` as in M2, bound to the renderer (§5.10) and started;
  2. a new `CarSim`, whose signals go to `main.gd` and `EventBus` as in M2;
  3. the input, enabled, with the autopilot if `--autopilot` is given and none otherwise;
  4. a new car from `car.tscn` under `World/Props`, which the camera follows and snaps to;
  5. `DisasterDirector.start_run(run_seed)`; then `GameState.start_run(run_seed)`, which emits `run_started`, and the area's id.
- **`_ready()`** builds the tilesets once with `WorldRenderer.build()`, prints M1's `grey box:` line once, gives the director World's `DisasterLayer`, and connects `sequence_finished` and `retry_requested` once. So a session prints one `grey box:` line, however many runs it has (E13).
- **Retry (J12, J13, J18).** `_retry()` is allowed only in `GAME_OVER`. Anywhere else it is an error and changes nothing (N40). It then:
  1. closes the game-over screen, which takes the focus from Retry (§5.8);
  2. clears the director, which frees the disaster;
  3. stops the shake (N39);
  4. frees the car with `free()`, so that `Props` never holds two cars, not even for a frame (N38);
  5. starts the next run. A forced `--seed` stays; without one, each run gets a new random seed, as M2's reload gave it (N41). `_start_run()` sets the pilot and turns the input on again (N42, N43).
- The last run's `CarSim`, `JunctionTrigger` and `RoadBuffer` are `RefCounted`. The car, the renderer and `main.gd` held them, so they are freed when `_start_run()` replaces them; `test_retry.gd` checks it with `weakref()`. `retry_requested` comes from Retry's `pressed` signal, and neither the button nor the screen is freed, so no object is freed while it emits a signal (J13).
- The autopilot's run never ends, so an end is an error, as in M2 (H17), and the smoke run fails on it.

### 5.3 Pools, params and the disaster stream (PRs 1, 2) **Δ IP M3.1**

```gdscript
# areas/area_def.gd (PR 1)
@export_group("Disasters")
@export var disasters: Array[PackedScene] = []   # scenes whose root is a DisasterBase

class_name DisasterParams extends RefCounted     # PR 1
var direction := Vector2.RIGHT     # a unit vector in tile space
var intensity := 1.0               # DISASTER_INTENSITY_MIN..MAX
var delay := 0.0                   # seconds from play() until the disaster shows
var particle_scale := 1.0          # PARTICLE_SCALE_MIN..MAX
var particle_seed := 0             # Δ J14: not `seed`
var origin_world := Vector2.ZERO   # Δ J17: where the car stopped, in world pixels
static func roll(rng: RandomNumberGenerator, origin: Vector2) -> DisasterParams
```

- **Pools (J6, Q2).** `AreaDef.disasters` comes in M3, from IP M4.1, as M2 brought M4.2's driving values. PR 1 adds it, empty; PR 2 sets every area's pool to `[sinkhole.tscn]`. M4.5 gives each area its own pool, from IP M4.2's table (§9). `test_area_schedule.gd` checks that every area of the schedule has a pool, and every scene in it is a disaster with an id (E7; N33, N34).
- **The stream (J21).** `DisasterDirector.stream(run_seed)` seeds a `RandomNumberGenerator` with `hash("%d:disaster" % run_seed)`, as `RoadGenerator` seeds the road's with `hash("%d:road" % run_seed)`. The director takes a new one in `start_run()`, so the same seed gives the same road and the same disasters (`plan.md` §3.5, IP §5.3; N10).
- **Draws.** For a disaster, the director draws the scene with `pick(pool, rng)`, one `randi_range()`, and then the params with `roll()`: the direction, intensity, delay, particle scale and particle seed. `roll()` draws all five, always in that order, whichever ones the disaster reads, so the draws don't depend on the disaster. `origin_world` is where the car stopped (N14).
- `lint.sh`'s RNG rule already covers `disasters/` (IP §5.3). So `pick()` uses the stream's `randi_range()`, not `pick_random()` (N9).

### 5.4 The director (PR 1) **Δ IP M3.1, M3.3**

```gdscript
class_name DisasterDirector extends Node        # Main/Director, %Director
signal sequence_finished                        # once per run
enum Sequence { NONE, STOPPING, PLAYING, CRASH, FINISHED }
var layer: Node2D                               # World's DisasterLayer; main.gd sets it
var sequence := Sequence.NONE
var disaster: DisasterBase                      # the disaster playing, or null
var params: DisasterParams
func start_run(run_seed: int) -> void           # clear(), then this run's stream
static func stream(run_seed: int) -> RandomNumberGenerator
func play_disaster(area: AreaDef, car: CarController, camera: CameraRig) -> void
func play_crash(car: CarController, camera: CameraRig) -> void
func clear() -> void                            # frees the disaster at once (J13)
static func pick(pool: Array[PackedScene], rng: RandomNumberGenerator) -> PackedScene
```

| Sequence | Starts with | Each physics frame | Then |
|---|---|---|---|
| `NONE` | `start_run()`, `clear()` | nothing | `play_disaster()`: `STOPPING`. `play_crash()`: `CRASH` |
| `STOPPING` | `play_disaster()` | waits for the car's speed to be 0 | the disaster starts: `PLAYING`. No disaster to start: `FINISHED`, with an error |
| `PLAYING` | the disaster is added and played | waits for its `finished` | `FINISHED` |
| `CRASH` | `play_crash()`, which shakes the camera by `CRASH_SHAKE` for `CRASH_SHAKE_SECONDS` | waits `CRASH_SECONDS` | `FINISHED` |
| `FINISHED` | emits `sequence_finished` | nothing | `clear()`, `start_run()`: `NONE` |

- **The clock** counts physics deltas from `play_disaster()` or `play_crash()`, the end of the run (J2). At `DISASTER_TIMEOUT` it reports `push_error("DisasterDirector: the sequence did not end in 6.0 s")` and finishes anyway, so game over always comes (J20; N5, N6).
- **A disaster starts** once the car has stopped (N4). The director picks a scene and instantiates it, sets `car` and `camera`, connects `finished`, adds it to `layer`, rolls the params at the car's position and calls `play(params)`. An empty pool, or a scene whose root isn't a `DisasterBase`, is an error: it frees the node and finishes (N12, N13).
- `finished` counts only in `PLAYING`, so a disaster that emits it late, or twice, ends nothing more (N7).
- A second `play_disaster()` or `play_crash()` before `clear()` is an error and changes nothing (N11). `main.gd` calls one of them per run.
- `clear()` frees the disaster with `free()` (N8), and forgets the sequence, the pool, the car and the camera.
- The director doesn't listen to `GameState` (J24); `main.gd` calls it. It needs no `process_mode`: the tree can't be paused while it plays (§5.2).
- PR 1 tests it without the sinkhole, with two test disasters in `tests/helpers/`: `stuck_disaster.gd` never finishes, and `timed_disaster.gd` finishes 1 s after `play()`.

### 5.5 Disasters and the sinkhole (PRs 1, 2) **Δ IP M3.1, M3.2**

```gdscript
@abstract class_name DisasterBase extends Node2D   # PR 1
@warning_ignore("unused_signal")                     # Δ J25: only the disasters emit it
signal finished
@export var id := &""                # what M5.4's collection will record (J7)
var car: CarController               # set before play()
var camera: CameraRig
@abstract func play(params: DisasterParams) -> void
```

Every disaster keeps to these rules. The class's doc comment states them:
- The director adds it to `DisasterLayer` once the car has stopped, sets `car` and `camera`, and calls `play()` once.
- It emits `finished` once, 2–4 s after the wrong or missed turn. The car's stop, up to `STOP_SECONDS`, and the params' delay count towards that (J20). The director ends the sequence anyway at `DISASTER_TIMEOUT`, with an error.
- Its time comes from `_physics_process` deltas. No Tween or timer: GUT's `simulate()` moves neither (J2, P1).
- It may change the car's `scale` and `modulate`, but not its position, which `CarController` sets from `CarSim` every frame (J3, P7; N23, N25).
- It works without a car or a camera, for tests (N31).
- `@abstract` makes a disaster without `play()` a parse error, but `DisasterBase.new()` still works (J26, P2). The director checks the scene's root instead (N13).

**The sinkhole** (PR 2) is `sinkhole.tscn`: a `Sinkhole` root (`Node2D`, `id = &"sinkhole"`) with the `Rim` and `Hole` `Polygon2D`s and the `Debris` `CPUParticles2D`. `play()` moves it to `origin_world`, sets up the debris from the params, and starts its clock.

| Phase | Seconds after `play()` | What happens |
|---|---|---|
| `WAITING` | before `play()` | nothing (N29) |
| `DELAY` | 0 to `delay` | nothing shows |
| `GROW` | 0.8 s | The hole and its rim grow from nothing to `intensity` × their size, eased with `smoothstep`. The debris flies, and the camera shakes by `intensity` for 1.8 s, through `SINK` (N30) |
| `SINK` | 1.0 s | The car shrinks to `SUNK_SCALE` (0.2) and fades to transparent black. The debris flies |
| `HOLD` | 0.6 s | The debris stops (N27); the hole stays |
| `DONE` | `delay` + 2.4 s | `finished`, once (N28) |

- The hole is an ellipse on the ground: `outline(radius)` takes 32 points on a circle of `radius` tiles through `Iso.tile_to_world()`. The hole's radius is `SINKHOLE_RADIUS` (0.8 tiles) and the rim's 1.25 times that. `_ready()` sets their polygons once; then they grow only by their `scale`, which doesn't redraw a `Polygon2D` (P5, M2 §5.7; N24). IP's shader comes with M5's art (Q3).
- The debris (J16, Q4) is 40 particles that live 0.9 s, thrown up and leaning towards the params' `direction`. They come from `particle_seed`, with `use_fixed_seed` (P3; N26), at `intensity` times their speed and `particle_scale` times their size. Its `z_index` is 1, so it flies in front of the car, as the car's smoke does.
- The car shrinks and fades instead of IP's clip mask (J15, Q3): the hole is below it (§5.10), so a clip would need a mask that M5's art will bring anyway.
- `duration(params)` is `delay` + 2.4 s, so 2.5–2.9 s. With the stop, which takes up to 0.6 s, game over comes 2.5–3.5 s after the turn, inside IP's 2–4 s (J20; N32). A wrong turn comes at about `junction_speed`, 2.0 tiles/s, so the stop takes about 0.5 s (P9).
- The shape (`POINTS`, `RIM`, `LEAN`, `SUNK_SCALE`) and the particles' values are the sinkhole's grey-box art, as the arrow and the dust are the car's in M2. So they live in `sinkhole.gd` and `sinkhole.tscn`, not in `Tuning` (D11), and M5's art replaces them. Its timing and size are in `Tuning` (§5.9).

### 5.6 The car's stop and crash (PR 1) **Δ IP M3.1, M3.3**

- **The stop (J4, Q1).** Once the run is over, `CarSim.step()` brakes at `max(BRAKE, speed / STOP_SECONDS)`, worked out once, at the first step after the end (N2). It doesn't steer (N3): the car goes on in a straight line along its heading, into the exit it took, and stops within `STOP_SECONDS` (N1).
  - From the cap of 7 tiles/s it brakes at 11.7 tiles/s² and stops after 2.1 tiles.
  - From the 5.73 tiles/s of P8's crash, after 1.72 tiles, where M2's car rolled 4.06 tiles in 1.45 s.
  - From `junction_speed`, 2.0 tiles/s, at `BRAKE`: 0.5 s and 0.5 tiles.
- **The crash (J22, Q10).** When `CarSim`'s state is `CRASHED`, `CarController` tints the arrow `CRASH_TINT` (grey) through `self_modulate`, which doesn't redraw it (M2 §5.7; N21), and turns on `%Smoke`: a new `CPUParticles2D` in `car.tscn`, 20 grey puffs that rise for 1 s. Only a crash smokes (N22). The scene fixes the smoke's seed (`use_fixed_seed`, `seed = 1`), so every crash smokes alike (J16; N55): Godot gives each `CPUParticles2D` a random seed when it's made (`scene/2d/cpu_particles_2d.cpp:1733` in 4.7.2), and each run makes a new car. The seed isn't 0, the declared default (`:1553`), which the editor doesn't save. The dust shows only while the car is off the road, as in M2, so it stops at the crash.
- `CarController` never sets its own `scale` or `modulate`, which a disaster may change (J3; N23).

### 5.7 Camera shake (PR 1)

```gdscript
func shake(intensity: float, seconds: float) -> void   # replaces a shake that is still going
func stop_shake() -> void                              # ends it at once
```

- The shake moves only `offset`, by `(sin(t·SHAKE_FREQ_X), cos(t·SHAKE_FREQ_Y)) × SHAKE_PX × intensity × (1 − t / seconds) / zoom`. So it leaves the position and its smoothing alone (N20), it is the same number of screen pixels at every zoom (N19), and it fades out and ends after `seconds` (N17).
- There is no randomness: the same seed replays the same shake, and `lint.sh`'s RNG rule covers `world/` (N18).
- Its time comes from `_physics_process` deltas, like the rest of M3 (J2).
- The sinkhole shakes it by `intensity` (3–6 px) for 1.8 s; a crash by 0.5 (3 px) for 0.4 s. M5's audio and M5.7's haptics may add to both.

### 5.8 Game over and the HUD (PR 3) **Δ IP M3.3**

```gdscript
class_name GameOver extends Control       # Main/UI/GameOver, %GameOver; hidden until open()
signal retry_requested                    # Retry was pressed while the screen was open
const END_MESSAGES: Dictionary[StringName, String]   # moved from Hud
const FALLBACK_MESSAGE := "Game over"
var show_seed := OS.is_debug_build()      # Δ J19; tests change it
func open(stats: Dictionary, area: AreaDef) -> void
func close() -> void
static func stats_text(stats: Dictionary, area: AreaDef) -> String
```

The screen fills the window: a `Shade` (black at 55 %), which stops taps and clicks, and a centred column with `Cause` (24 px), `Stats`, `Retry` (at least 160×48) and `Seed` (12 px). Each label has an outline, like the HUD's.

| Cause | `Cause` |
|---|---|
| `CarSim.WRONG_TURN` | Wrong turn! |
| `CarSim.MISSED_TURN` | You missed the turn! |
| `CarSim.HEALTH` | Your car broke down. |
| `CarSim.OFFROAD` | You got lost off the road. |
| any other | Game over, with an error (N54) |

- These are M2's messages, which move from the HUD. `Stats` reads `Distance: 1230 m`, `Turns: 2` and `Area reached: City`, a line each (`plan.md` §2.1). The distance uses the HUD's `distance_text()`, so the two agree.
- **The focus (J9, Q9).** `open()` shows the screen and calls `Retry.grab_focus()`. A focused button presses on `ui_accept`, so Enter and Space retry (N49). A tap or a click on it retries once: a button skips the emulated touch that comes with a click. A tap anywhere else lands on the shade and does nothing.
- `close()` hides the screen. Hiding a parent releases the focus of the button in it (P4), so the arrow keys, which a focused button would take to move the focus, steer again (N51).
- Retry emits `retry_requested` only while the screen is visible (N50).
- The seed shows only in debug builds, as IP says (J19; N52). The Android APK that CI uploads is a debug build; the Web build is a release build, so it has no seed there. GUT runs a debug build, so only a release build can check `show_seed`'s default (§6.4). The HUD's seed line stays in every build (Q6).
- `test_smoke.gd` checks every glyph the screen can show: the messages, the fallback, and the stats of every area in the schedule (E9; N53).

**The HUD (J9, J10)** no longer retries. Its `retry_requested`, `RETRY_MESSAGE` and `_is_retry()` go, and `END_MESSAGES` moves to `GameOver`. `_reset()` shows 0 turns, full health, no message, the pause button, and the version and seed. It runs in `_ready()` and on every `run_started` (N46). At the end of a run the HUD hides the pause button and leaves the message alone. `distance_text()` is static, for the game-over screen.

### 5.9 Tuning (PR 1)

| Constant | Value | Unit | What | IP |
|---|---|---|---|---|
| `STOP_SECONDS` | 0.6 | s | the longest the car takes to stop once the run is over | M3.1's tween **Δ J4** |
| `CRASH_SECONDS` | 1.2 | s | from a crash to game over | M3.3 |
| `DISASTER_TIMEOUT` | 6.0 | s | from the end of the run, the latest game over may come | M3.1 |
| `DISASTER_DELAY_MIN`, `_MAX` | 0.1, 0.5 | s | `DisasterParams.delay` | M3.1 gives no range |
| `DISASTER_INTENSITY_MIN`, `_MAX` | 0.5, 1.0 | — | `DisasterParams.intensity` | M3.1 |
| `PARTICLE_SCALE_MIN`, `_MAX` | 0.75, 1.25 | — | `DisasterParams.particle_scale` | M3.1 gives no range |
| `SHAKE_PX` | 6.0 | screen px | the shake's offset at intensity 1, as it starts | — |
| `SHAKE_FREQ_X`, `_Y` | 47.0, 31.0 | rad/s | across and up the screen; they differ, so the view moves in a figure | — |
| `CRASH_SHAKE`, `CRASH_SHAKE_SECONDS` | 0.5, 0.4 | —, s | a crash's shake | — |
| `CRASH_TINT` | (0.4, 0.4, 0.4) | colour | the crashed arrow | **Δ J22** |
| `SINKHOLE_RADIUS` | 0.8 | tiles | the hole at intensity 1 | — |
| `SINKHOLE_GROW_SECONDS`, `_SINK_`, `_HOLD_` | 0.8, 1.0, 0.6 | s | the sinkhole's phases (§5.5) | — |

These are first guesses for the grey box. E13 judges them on the Fold4, and M6 tunes them.

### 5.10 World (PR 3) **Δ `plan.md` §7.1, IP §5.2**

- `world.tscn` gets `DisasterLayer`, a `Node2D`, between `RoadLayer` and `Props`. World draws its children in order, and only `Props` sorts by y. So the hole draws above the road and below the car and the props (J5; N44, N45). The debris and the smoke have `z_index` 1, so they draw in front of the car.
- `WorldRenderer.build(schedule)` makes the tilesets and lines the layers up, once. `bind(buffer)` stops following the last buffer, clears both layers, and draws the new buffer's tiles and every later change (J11; N47, N48). M1's `bind(buffer, schedule)` did both, once.

### 5.11 Tests

| File | Tests | PR | What they check |
|---|---|---|---|
| `test_car_sim_speed.gd` | 7 + 1 | M2, 1 | Once the run is over, the car stops within `STOP_SECONDS`, from `junction_speed` and from the cap. It goes on in a straight line along its heading, whatever the steering (E1) |
| `test_car_controller.gd` | 4 + 4 | M2, 1 | It leaves its scale and modulate to a disaster. A crashed car turns grey and smokes, without a redraw. Every car's smoke has the same fixed seed. Only a crash smokes (E4) |
| `test_camera_rig.gd` | 4 + 4 | M2, 1 | A shake moves only the offset, and fades out and ends. It is the same every time. `stop_shake()` ends it, and a new shake replaces the last. It has the same size on screen at zoom 1 and 2 (E5) |
| `test_disaster_params.gd` | 4 | 1 | The same seed gives the same params, and different seeds different ones. The stream goes on from one disaster to the next. Every value is in its range, and the origin is the one given (E2) |
| `test_disaster_director.gd` | 11 | 1 | `pick()` draws every scene of a pool with the stream. A disaster waits for the car to stop. The sequence ends once, when the disaster finishes, and a late `finished` ends nothing. A crash shakes the camera and ends after `CRASH_SECONDS`. A car that never stops and a disaster that never finishes both time out, with an error. An empty pool and a scene that isn't a disaster are errors that end the sequence, and the scene is freed. `clear()` frees the disaster at once. A second sequence is an error. The run's seed decides the disaster (E3, E4) |
| `test_sinkhole.gd` | 10 | 2 | It is a disaster with an id, and waits for `play()`. It opens, sinks the car and finishes once, after its duration. It grows while it opens, and the car sinks after that. The debris follows its params and flies only while the hole opens. It shakes the camera as it opens. Nothing is redrawn. It finishes without a car or a camera. After a wrong turn, for 10 seeds from `junction_speed` and from the cap, the director plays it in 2–4 s; so do the shortest and longest params (E6) |
| `test_area_schedule.gd` | 9 + 1 | M1, M2, 2 | Every area of the game has a pool of disasters, each with an id (E7) |
| `test_game_over.gd` | 6 | 3 | It is hidden until it opens. It shows why the run ended and its stats. A cause without a message is an error, and shows "Game over". The seed shows in debug builds only. Retry takes the focus, and Enter or Space presses it. `close()` drops the focus, and Retry does nothing while the screen is closed (E9) |
| `test_hud.gd` | 7 − 3 + 3 | M2, 3 | M2's three retry tests go. New: the distance is in whole metres; the end of a run hides the pause button and leaves the message alone; each run starts the HUD afresh (E10) |
| `test_world_renderer.gd` | 3 + 2 | M1, 3 | A new buffer replaces the last one, whose changes no longer draw. Disasters draw above the road and below the car (E10, E11) |
| `test_smoke.gd` | 3 | M2, 3 | The glyph test also checks the game-over screen's messages and the stats of every area (E9) |
| `tests/integration/test_main_scene_boot.gd` | 9 | M2, 3 | The end of a run is now `DISASTER`, not `GAME_OVER`, and hides the pause button. M2's check that a retry reloads the scene goes (E12) |
| `tests/integration/test_wrong_turn_disaster.gd` | 3 | 3 | A wrong exit at the third junction ends the run once, in the City, with the input off and no pause button. The City's sinkhole plays on `DisasterLayer` and swallows the car; Esc doesn't pause it; game over comes 2–4 s after the turn and shows the cause and stats. The same seed plays the same disaster (E8, E11) |
| `tests/integration/test_crash.gd` | 1 | 3 | A crash, sideways off the first straight, turns the car grey; it smokes, the camera shakes, the car stops within `STOP_SECONDS`, no disaster plays, and game over comes `CRASH_SECONDS` later (E4) |
| `tests/integration/test_retry.gd` | 6 | 3 | Enter on Retry starts the next run afresh: `GameState`, the HUD, a new car and road on the same seed, no disaster or shake, the input on, and the last run's car, disaster, sim and road freed at once. After a retry, the arrow keys steer and Enter does nothing. A tap or a click on Retry retries once. Three runs in a row, each with a new seed. No orphan nodes. A retry while the run goes on is an error (E9, E10) |

- 147 tests become 200: 53 are new, and three of the HUD's are replaced.
- The integration tests run the main scene in a 360×640 `SubViewport` with `tests/helpers/main_scene.gd`, and push input through the viewport as a device sends it, as M2's boot test does. `wrong_turn_pilot.gd` is an `Autopilot` that takes a wrong exit at the third junction.
- Every timing in M3 comes from physics deltas, so GUT's `simulate()` runs the whole end of a run, 2–4 s, in a fraction of a second, with no real-time waits.
- `DisasterParams` is the only new `RefCounted`, and has its own test (IP §1.3). The director and the sinkhole are nodes, with unit tests of their own too.

---

## 6. Verification

### 6.1 Local checks

The commands are those of `AGENTS.md` §4: `lint.sh`, `import.sh`, `check_scripts.sh`, `run_tests.sh` and `smoke.sh` in `tools/ci/`. Each PR state was built with §4's commands from `m3/prototype` (2dff52b) on top of `main` (73256cf), and all five checks passed on it:

| State | `check_scripts` | GUT tests | Asserts | GUT time | `smoke.sh` prints |
|---|---|---|---|---|---|
| M2 (`main`, 73256cf) | 50 | 147 | 144,193 | 15.7 s | `autopilot: tile 165, turns 35, area rural` |
| PR 1 | 57 | 171 | 144,342 | 15.9 s | the same |
| PR 2 | 59 | 182 | 144,483 | 16.5 s | the same |
| PR 3 | 66 | 200 | 144,611 | 17.6 s | the same |

PR 3's state is the prototype's tree. Repeated runs differ by about 1 s: an earlier run of the prototype took 16.4 s. The smoke line is M2's, because the stop changes the car only once a run is over, and the autopilot's run doesn't end in 60 s (E12). In every state:
- `lint.sh` reports `Actions storage: no caches, artifacts kept 1 day (5 files checked)`;
- `smoke.sh` also prints `grey box: tilesets built in 60–62 ms`;
- `git status` is clean after the checks, so `import.sh` creates no files (§4.1 step 4).

### 6.2 Negative cases

For each case, make the temporary change in the PR state listed, run the checks named under "Expected", then revert. A script did this for all 55 cases, each on its PR's state and again on PR 3's, so a case of PR 1 or 2 also shows which later tests catch it. Every case fails at least one check in both states. "GUT fails" means `run_tests.sh`, which also fails on error lines and leaks. N9 and N18 run `lint.sh` too.

Three cases needed work before they failed as they should:
- **N9** also renames `pick()`'s `rng` parameter, which the change leaves unused, to `_rng`. Without that, gdlint's `unused-argument` stops `lint.sh` (`set -e`) before its RNG rule runs.
- **N28** at first hung GUT until its 900 s timeout: three loops in `test_sinkhole.gd` waited for a phase without a bound. 7244faf bounds them by `MAX_FRAMES`, so the tests fail instead.
- **N39** passed at first, because every shake in the tests ended before game over. 27505b1 starts a long shake before the retry in `test_retry_starts_the_next_run_afresh`.

One rule can't fail a check here: `show_seed`'s default, `OS.is_debug_build()` (J19). GUT runs a debug build, where a default of `true` passes too, so a release build checks it (§6.4). N52 breaks the use of `show_seed` instead.

"With IP's design" says what happens with the same problem if IP is followed as written:
- **Fails ✓:** one of IP's M3 tests, or IP §5.3's lint rule, fails too.
- **Not tested:** none of IP's tests would catch it.
- **Not specified:** IP doesn't say which behaviour is right.
- **IP's design:** the change is what IP describes.
- **Not in IP:** IP doesn't have the feature.

| # | PR | Temporary change | Expected | With IP's design |
|---|---|---|---|---|
| N1 | 1 | Once the run is over, `CarSim` brakes at `BRAKE`, as in M2 | GUT fails: `test_once_the_run_is_over_the_car_stops_in_a_line_within_stop_seconds`, `test_the_sequence_ends_once_when_the_disaster_finishes`. On PR 3, also `test_after_a_wrong_turn_the_director_plays_it_in_2_to_4_seconds` | Not in IP: it tweens the car (J2, J4) |
| N2 | 1 | The stop's rate is worked out again at every step | GUT fails: `test_once_the_run_is_over_the_car_stops_in_a_line_within_stop_seconds`, `test_the_sequence_ends_once_when_the_disaster_finishes`. On PR 3, also `test_after_a_wrong_turn_the_director_plays_it_in_2_to_4_seconds` | Not in IP (J4) |
| N3 | 1 | The car still steers once the run is over | GUT fails: `test_once_the_run_is_over_the_car_stops_in_a_line_within_stop_seconds` | Not in IP (J4) |
| N4 | 1 | The disaster starts before the car has stopped | GUT fails: `test_a_disaster_waits_for_the_car_to_stop`, `test_the_sequence_ends_once_when_the_disaster_finishes` | Not specified |
| N5 | 1 | No `DISASTER_TIMEOUT` | GUT fails: `test_a_car_that_never_stops_times_out_with_an_error`, `test_a_disaster_that_never_finishes_times_out_with_an_error` | Not tested |
| N6 | 1 | The timeout ends the sequence without an error | GUT fails: `test_a_car_that_never_stops_times_out_with_an_error`, `test_a_disaster_that_never_finishes_times_out_with_an_error` | IP's design: the timeout forces `finished` |
| N7 | 1 | A `finished` outside `PLAYING` ends the sequence again | GUT fails: `test_a_disaster_that_never_finishes_times_out_with_an_error` | Not specified |
| N8 | 1 | `clear()` frees the disaster with `queue_free()` | GUT fails: `test_clear_frees_the_disaster_at_once_and_forgets_the_sequence`. On PR 3, also `test_retry_starts_the_next_run_afresh` | Not specified (J13) |
| N9 | 1 | `pick()` uses the global RNG: `pool.pick_random()` | `lint.sh` fails: `Global RNG in gameplay code; use a seeded RandomNumberGenerator stream (§5.3)`. GUT fails: `test_pick_draws_every_scene_of_the_pool_with_the_stream` | Fails ✓: IP §5.3's lint rule |
| N10 | 1 | The disaster stream isn't seeded | GUT fails: `test_the_run_seed_decides_the_disaster`, `test_the_same_seed_gives_the_same_params`. On PR 3, also `test_the_same_seed_plays_the_same_disaster`, `test_pick_draws_every_scene_of_the_pool_with_the_stream` | Fails ✓: `test_disaster_params.gd` |
| N11 | 1 | A second sequence replaces the first, without an error | GUT fails: `test_a_second_sequence_is_an_error` | Not specified |
| N12 | 1 | An empty pool is no error | GUT fails: `test_an_empty_pool_is_an_error_and_ends_the_sequence`, `test_a_scene_that_is_not_a_disaster_is_an_error_and_is_freed` | Not specified (J6) |
| N13 | 1 | A scene that isn't a disaster is never freed | GUT fails: `test_a_scene_that_is_not_a_disaster_is_an_error_and_is_freed`. `run_tests.sh` reports the leak | Not specified |
| N14 | 1 | The disaster plays at the world's origin, not where the car stopped | GUT fails: `test_a_disaster_waits_for_the_car_to_stop` | Not specified (J17) |
| N15 | 1 | A crash doesn't shake the camera | GUT fails: `test_a_crash_shakes_the_camera_and_ends_after_crash_seconds`. On PR 3, also `test_a_crash_smokes_shakes_and_ends_the_game_after_crash_seconds` | IP's design: its crash doesn't shake (Q10) |
| N16 | 1 | A crash ends at once, without `CRASH_SECONDS` | GUT fails: `test_a_crash_shakes_the_camera_and_ends_after_crash_seconds`. On PR 3, also `test_a_crash_smokes_shakes_and_ends_the_game_after_crash_seconds` | Not tested |
| N17 | 1 | A shake never ends | GUT fails: `test_a_shake_moves_the_view_and_fades_out`, `test_stop_shake_ends_it_and_a_new_shake_replaces_the_last`. On PR 3, also `test_a_crash_smokes_shakes_and_ends_the_game_after_crash_seconds` | Not specified |
| N18 | 1 | The shake is random: the global `randf_range()` | `lint.sh` fails: `Global RNG in gameplay code; use a seeded RandomNumberGenerator stream (§5.3)`. GUT fails: `test_a_shake_is_the_same_every_time`, `test_stop_shake_ends_it_and_a_new_shake_replaces_the_last`, `test_the_shake_is_in_screen_pixels` | Fails ✓: IP §5.3's lint rule |
| N19 | 1 | The shake is in world pixels: no division by the zoom | GUT fails: `test_the_shake_is_in_screen_pixels` | Not specified |
| N20 | 1 | The shake moves the camera's position, not its offset | GUT fails: `test_a_shake_moves_the_view_and_fades_out`, `test_stop_shake_ends_it_and_a_new_shake_replaces_the_last`, `test_the_shake_is_in_screen_pixels`, `test_a_crash_shakes_the_camera_and_ends_after_crash_seconds`. On PR 3, also `test_a_crash_smokes_shakes_and_ends_the_game_after_crash_seconds`, `test_it_shakes_the_camera_as_it_opens` | Not specified |
| N21 | 1 | The crashed arrow is tinted through its `color`, which redraws it | GUT fails: `test_a_crashed_car_turns_grey_and_smokes_without_being_redrawn`. On PR 3, also `test_a_crash_smokes_shakes_and_ends_the_game_after_crash_seconds` | Not in IP (J22) |
| N22 | 1 | Every end of a run smokes, not only a crash | GUT fails: `test_only_a_crash_smokes` | Not specified |
| N23 | 1 | `CarController` resets its scale and modulate every frame | GUT fails: `test_it_leaves_its_scale_and_modulate_to_a_disaster`. On PR 3, also `test_the_citys_sinkhole_swallows_the_car_and_then_the_game_is_over` | Not specified (J3) |
| N24 | 2 | The hole grows by its polygon, which redraws it | GUT fails: `test_it_waits_for_play`, `test_it_opens_sinks_the_car_and_finishes_once_after_its_duration`, `test_it_grows_while_it_opens_and_the_car_sinks_after`, `test_it_grows_and_sinks_the_car_without_redrawing` | Not in IP: it uses a shader (J15) |
| N25 | 2 | The car slides into the hole by its position | GUT fails: `test_it_opens_sinks_the_car_and_finishes_once_after_its_duration` | IP's design (J3) |
| N26 | 2 | The debris has no fixed seed | GUT fails: `test_the_debris_follows_its_params_and_flies_while_the_hole_opens` | Not specified (J14) |
| N27 | 2 | The debris never stops | GUT fails: `test_the_debris_follows_its_params_and_flies_while_the_hole_opens` | Not specified |
| N28 | 2 | The sinkhole emits `finished` on every frame after its duration | GUT fails 5 tests: `test_it_opens_sinks_the_car_and_finishes_once_after_its_duration`, `test_it_grows_while_it_opens_and_the_car_sinks_after`, `test_the_debris_follows_its_params_and_flies_while_the_hole_opens`, `test_it_grows_and_sinks_the_car_without_redrawing`, `test_it_finishes_without_a_car_or_a_camera` | Not tested |
| N29 | 2 | It ignores the delay in its params | GUT fails: `test_it_opens_sinks_the_car_and_finishes_once_after_its_duration`, `test_the_debris_follows_its_params_and_flies_while_the_hole_opens`, `test_after_a_wrong_turn_the_director_plays_it_in_2_to_4_seconds` | Not tested |
| N30 | 2 | It doesn't shake the camera | GUT fails: `test_it_shakes_the_camera_as_it_opens` | Not tested |
| N31 | 2 | It needs a car | GUT fails: `test_it_finishes_without_a_car_or_a_camera` | Not in IP |
| N32 | 2 | `SINKHOLE_HOLD_SECONDS` is 2.0, so the sequence takes too long | GUT fails: `test_after_a_wrong_turn_the_director_plays_it_in_2_to_4_seconds`, `test_with_the_stop_it_takes_2_to_4_seconds`. On PR 3, also `test_the_citys_sinkhole_swallows_the_car_and_then_the_game_is_over` | Not tested: IP's test allows 6 s (J20) |
| N33 | 2 | The City's pool is empty | GUT fails: `test_every_area_of_the_game_has_a_pool_of_disasters`. On PR 3, also `test_retry_starts_the_next_run_afresh`, `test_after_retry_the_arrow_keys_steer_and_enter_does_nothing`, `test_a_tap_or_a_click_on_retry_retries_once`, `test_three_runs_in_a_row`, `test_a_retry_leaves_no_orphan_nodes`, `test_the_citys_sinkhole_swallows_the_car_and_then_the_game_is_over`, `test_the_same_seed_plays_the_same_disaster` | Fails ✓: the wrong-turn test |
| N34 | 2 | The sinkhole has no id | GUT fails: `test_every_area_of_the_game_has_a_pool_of_disasters`, `test_it_is_a_disaster_with_an_id` | Not tested (J7) |
| N35 | 3 | The run ends only once the disaster has played | GUT fails 5 tests: `test_a_rejoin_that_ends_the_run_counts_its_last_step`, `test_with_no_input_the_first_junction_ends_the_run`, `test_with_the_autopilot_the_end_of_a_run_is_an_error`, `test_a_wrong_turn_at_the_third_junction_triggers_one_disaster_in_the_city`, `test_the_citys_sinkhole_swallows_the_car_and_then_the_game_is_over` | IP's design (J1) |
| N36 | 3 | Game over at the turn, without a disaster, as in M2 | GUT fails 6 tests: `test_a_rejoin_that_ends_the_run_counts_its_last_step`, `test_with_no_input_the_first_junction_ends_the_run`, `test_with_the_autopilot_the_end_of_a_run_is_an_error`, `test_a_wrong_turn_at_the_third_junction_triggers_one_disaster_in_the_city`, `test_the_citys_sinkhole_swallows_the_car_and_then_the_game_is_over`, `test_the_same_seed_plays_the_same_disaster` | Fails ✓: the wrong-turn test |
| N37 | 3 | Game over at a crash, at once, as in M2 | GUT fails: `test_a_crash_smokes_shakes_and_ends_the_game_after_crash_seconds` | Not tested |
| N38 | 3 | Retry frees the car with `queue_free()` | GUT fails: `test_retry_starts_the_next_run_afresh`, `test_three_runs_in_a_row` | Not specified (J13) |
| N39 | 3 | Retry leaves the shake going | GUT fails: `test_retry_starts_the_next_run_afresh` | Not specified |
| N40 | 3 | Retry works in any state | GUT fails: `test_a_retry_while_the_run_goes_on_is_an_error` | Not specified |
| N41 | 3 | Retry takes a new seed, even with `--seed` | GUT fails: `test_retry_starts_the_next_run_afresh` | IP's design (J18) |
| N42 | 3 | Retry keeps the last run's pilot | GUT fails: `test_retry_starts_the_next_run_afresh` | Not tested |
| N43 | 3 | The input stays off after a retry | GUT fails: `test_retry_starts_the_next_run_afresh`, `test_after_retry_the_arrow_keys_steer_and_enter_does_nothing` | Not tested |
| N44 | 3 | Disasters go on `Props`, which y-sorts them with the car | GUT fails: `test_the_citys_sinkhole_swallows_the_car_and_then_the_game_is_over` | Not specified (J5) |
| N45 | 3 | `DisasterLayer` comes after `Props`, so disasters draw over the car | GUT fails: `test_disasters_draw_above_the_road_and_below_the_car` | IP's design (J5) |
| N46 | 3 | The HUD doesn't start afresh with a new run | GUT fails: `test_retry_starts_the_next_run_afresh`, `test_it_shows_the_version_and_the_seed_of_the_run`, `test_each_run_starts_the_hud_afresh`, `test_main_scene_shows_the_version_and_the_seed` | Not tested (J10) |
| N47 | 3 | `bind()` keeps following the last buffer | GUT fails: `test_a_new_buffer_replaces_the_last_one` | Not in IP: it rebuilds `World` (J11, J12) |
| N48 | 3 | `bind()` leaves the last run's tiles | GUT fails: `test_a_new_buffer_replaces_the_last_one` | Not in IP: it rebuilds `World` (J11, J12) |
| N49 | 3 | Retry doesn't take the focus | GUT fails 5 tests: `test_retry_starts_the_next_run_afresh`, `test_after_retry_the_arrow_keys_steer_and_enter_does_nothing`, `test_three_runs_in_a_row`, `test_a_retry_leaves_no_orphan_nodes`, `test_retry_takes_the_focus_and_enter_or_space_presses_it` | Not specified (J9) |
| N50 | 3 | Retry works while the screen is closed | GUT fails: `test_close_drops_the_focus_and_retry_does_nothing_while_closed` | Not specified (J9) |
| N51 | 3 | `close()` leaves the screen open, so Retry keeps the focus | GUT fails: `test_retry_starts_the_next_run_afresh`, `test_after_retry_the_arrow_keys_steer_and_enter_does_nothing`, `test_close_drops_the_focus_and_retry_does_nothing_while_closed` | Not specified (J9) |
| N52 | 3 | `open()` shows the seed whatever `show_seed` says, so release builds show it too | GUT fails: `test_the_seed_shows_in_debug_builds_only` | Not tested (J19) |
| N53 | 3 | A game-over message uses a glyph that the default font lacks (↩) | GUT fails: `test_main_scene_text_has_every_glyph_in_the_default_font` | Not in IP: the font rule is M1's |
| N54 | 3 | A cause without a message is no error | GUT fails: `test_a_cause_with_no_message_is_an_error_and_shows_game_over` | Not specified |
| N55 | 1 | The crash smoke has no fixed seed | GUT fails: `test_every_car_smokes_alike` | Not specified (J16) |

### 6.3 Editor warnings

None of the five checks reports GDScript warnings, so, as in M2 (M2_PLAN.md §6.3), a probe asked the editor's language server for them. On PR 3's state it reports 8 warnings in 66 scripts: the same 8 as on `main`, in 50 scripts, all in M1's code (M2 H29). `ui/main.gd:33`'s INTEGER_DIVISION, the `grey box:` line, is still on line 33. Without `DisasterBase`'s `@warning_ignore("unused_signal")`, it reports 9: UNUSED_SIGNAL for `finished` (J25). The probe isn't committed (§9).

### 6.4 Verified only in CI or on devices

| Check | PR | Result |
|---|---|---|
| The five checks on GitHub, and the `test` job's time against M2's 64–105 s | 1–3 | Green on the prototype in three manual runs (§6.5). The PRs' runs: to do |
| The Web build in Chrome and Firefox (E13) | 3 | Headless Chromium ran the prototype's build (§6.5). Headed Chrome and Firefox: to do |
| The debug APK on the Galaxy Z Fold4, folded and unfolded (E13) | 3 | To do (owner, §7) |
| The game-over screen hides the seed in release builds: GUT runs a debug build, which can't tell `show_seed`'s default from `true` (J19, §6.2) | 3 | The prototype's Web build, a release build, showed none (§6.5). In E13's Web checks: to do |
| https://pompomon.github.io/roadgame/ runs the game with M3 after the merge | 3 | To do |

### 6.5 Measurements (prototype, local)

The probes ran on Godot 4.7.2, headless, in scratch scripts that aren't committed. The findings cite them.

| # | Probe | Result | Used by |
|---|---|---|---|
| P1 | Step a Tween and a `SceneTreeTimer` with GUT's `simulate()` | Neither moves. `simulate()` calls `_process()` and `_physics_process()` on a node and its children (`addons/gut/gut_to_move.gd:62–92`), and the `SceneTree` processes Tweens and timers | J2 |
| P2 | `@abstract func play()` in a base class; a subclass without it; `.new()` on the base | The subclass is a parse error. `.new()` on the base works | J26 |
| P3 | `CPUParticles2D`'s seed | It has `use_fixed_seed` and `seed` | J14, J16 |
| P4 | Hide the parent of a focused `Button` | The button loses the focus | §5.8; N51 |
| P5 | Change a `Polygon2D`'s `scale`, `modulate`, `self_modulate` and `color` | Only `color` redraws it | J15, J22; N21, N24 |
| P6 | `GameState.end_run()` in `DISASTER` | An error: `end_run()` changes to `DISASTER` or `CRASH`, which `TRANSITIONS` allows only from `RUNNING` (`game_state.gd:8–15, 61–64`) | J1 |
| P7 | Move the car's node, then step its `CarController` | The next physics frame puts it back where `CarSim` is | J3; N25 |
| P8 | Stop the car after a crash at 5.73 tiles/s | At `BRAKE`, 4 tiles/s², M2's car rolls 4.06 tiles in 1.45 s. M3's stop takes 0.6 s and 1.72 tiles. From the cap of 7 tiles/s: 6.1 tiles in 1.75 s, against 2.1 tiles at 11.7 tiles/s² | J4 |
| P9 | The speed at wrong and missed turns | About `junction_speed`, 2.0 tiles/s, so the car stops in about 0.5 s and 0.5 tiles | J4, J20 |

- **The end's timing.** The sinkhole takes its params' delay, 0.1–0.5 s, plus 2.4 s for its phases: 2.5–2.9 s. With the stop, game over comes 2.5–3.5 s after the turn, inside IP's 2–4 s (J20). After a crash, it comes 1.2 s later.
- **Web.** The prototype's Web export from run 42512134595 (afc0ce9) was served locally and played in headless Chromium with Playwright. In one session: two sinkholes, a crash and three retries. Since afc0ce9, the game has changed only by `DisasterBase`'s `@warning_ignore` (ff30033, J25) and the smoke's fixed seed (2dff52b, J16); the other changes are tests.
  - No errors. There was one `grey box: tilesets built in 390 ms` line for the whole session, so no retry built the tilesets again (J12).
  - The game-over screens showed no seed: the Web export is a release build (`ci.yml` runs `tools/ci/export.sh "Web" … release`). The HUD's seed line stayed (J19, Q6).
  - In each new browser, Chromium's GL driver logged 4 performance notes, `GPU stall due to ReadPixels`, 0.3–0.6 s after the `grey box:` line, and then stopped repeating them. That was while the first run was still driving, before any junction, so before any disaster, crash or game-over screen. They aren't WebGL errors like M2's `INVALID_OPERATION` (M2 §4.6). M2's build couldn't be run in the same browser, so E13 compares the two in headed Chrome (§8).
- **Tilesets.** 59–63 ms headless, and 100–390 ms in headless Chromium: what each retry would cost if it rebuilt `World` (J12).
- **CI.** Three manual runs on the prototype passed all five jobs:
  - 42512134595 on afc0ce9, with `upload-builds`: `lint` 15 s, `test` 79 s, `export-web` 57 s, `export-android` 90 s (APK) and 185 s (AAB);
  - 42514884362 on 27505b1, without `upload-builds`: `lint` 13 s, `test` 88 s, `export-web` 59 s, `export-android` 71 s (APK) and 176 s (AAB);
  - 42517328547 on 2dff52b, the final prototype, without `upload-builds`: `lint` 14 s, `test` 93 s, `export-web` 76 s, `export-android` 66 s (APK) and 174 s (AAB).

  M2's `test` job took 64–105 s.

### 6.6 Measurements (PRs)

Filled in while the PRs are reviewed, as M2_PLAN.md §6.6 was: each PR's counts on its final head, its CI times, and the E13 results.

---

## 7. Owner actions

These need the repository owner. The current state was read with `gh api` on 2026-11-08: ruleset "Test" (26672445) requires `lint`, `test`, `export-web` and both `export-android` checks, and "Copilot" (26740665) has only its review rule. The repository doesn't delete merged branches by itself. M3 changes no settings.

| When | Action | How |
|---|---|---|
| Now | Answer Q1–Q13, or accept the defaults | A comment on this plan's PR. Without an answer, the PRs follow the defaults |
| Now | Merge this plan's PR | Squash-merge it into `main`. The landing simulation (§4.5) starts from `main` with this plan |
| Before PR 3 merges | The E13 checks on the Galaxy Z Fold4, with the debug APK of PR 3's final head. An agent does the Web checks | §4, PR 3 step 3 |
| To land M3 | Merge PRs 1, 2 and 3, in that order, each once its base is `main` and it is updated as in §4.5 step 4 | §4.5 |
| Optional | Delete each PR's branch after it merges, so GitHub retargets the next PR by itself. Delete `m3/prototype` once PR 3 has merged | The **Delete branch** button on the merged PR (§4.5 step 5); `git push origin --delete m3/prototype` |

---

## 8. M3 risks

| Risk | Impact | Mitigation |
|---|---|---|
| Focus and touch may work differently on devices. Retry takes the focus, a focused button presses when Enter or Space is released, and a button skips the emulated touch that comes with a click (§5.8) | A retry that needs a second tap or fires twice, or arrow keys that move the focus instead of steering | `test_game_over.gd` and `test_retry.gd` press keys, click and tap on the desktop (N49–N51). E13 tries all three on the Fold4 and in both browsers |
| The end's timings, sizes and shakes are first guesses (§5.9) | The end drags, or the player misses what happened | E13 judges them on the Fold4. They are all in `config/tuning.gd`, and M6 tunes them |
| Once the run is over, the car stops within 0.6 s: at up to 11.7 tiles/s² from the cap, about three times `BRAKE` (P8) | A crash at speed may stop abruptly | E13 looks at it. Wrong and missed turns come at about `junction_speed`, 2.0 tiles/s, where the stop is at `BRAKE` (P9). `STOP_SECONDS` can grow to `CRASH_SECONDS`, 1.2 s, and the car still stops before game over |
| The debris and the smoke are `CPUParticles2D`: 40 particles in the sinkhole, 20 in the smoke | Dropped frames on the Fold4 or in browsers during the end | Headless Chromium ran them without errors (§6.5). E13 watches for it, and the amounts are in `sinkhole.tscn` and `car.tscn` |
| Chromium's `GPU stall due to ReadPixels` notes (§6.5) | A Web check takes them for an M3 bug, or misses one | E13 opens M2's Pages site in the same headed Chrome first. If only M3 shows them, PR 3 finds what reads the pixels |
| A retry in place keeps something of the last run: a node, a shake, a signal, the HUD's numbers or its pause button | The next run starts wrong, or memory grows run after run | `test_retry.gd` checks every part afresh, three runs in a row, and no orphans; `run_tests.sh` fails on leaks (E10; N38–N43, N46–N51). E13 retries several times on the Fold4 |
| A disaster that never finishes | The game hangs at the end of a run | The director ends the sequence at `DISASTER_TIMEOUT`, with an error (E3; N5–N7). Every CI script fails on error lines |
| The sinkhole plays in every area until M4.5 (Q2) | A sinkhole in the desert, unlike `plan.md` §4.3 | Accept until M4.5 brings the other disasters (§9) |
| `push_error` doesn't stop a release build | A broken rule goes unnoticed in the game | Every CI script fails on error lines (M0 F10), and a test covers each rule (§6.2) |
| Squash merges of stacked PRs | Conflicts, or a lost review fix | §4.5: merge PR n's final branch first, then check `git diff --name-only origin/main`. Fix a file only on the branch of the PR that owns it |
| The PRs drift from the prototype after reviews | The prototype stops being a reliable reference | PR 3's tree check lists every difference, which must be §4.6's files (§4, PR 3 step 2) |
| `m3/prototype` disappears before PR 3 merges | The PRs can't check their files out | Keep it until PR 3 merges (§7) |
| GUT's update check hits GitHub's rate limit in an editor run on CI | A red `export-*` job | Re-run the failed jobs (`AGENTS.md` §10) |

---

## 9. Notes for later milestones

- **M4:**
  - M4.1 adds the rest of `AreaDef`. M3 adds only `disasters` (§5.3).
  - M4.5 adds the Tornado, the Flood and the Quicksand. Then M4.2's pools replace Q2's sinkholes: City a Sinkhole, Rural a Tornado, Meadows a Flood, Village a Flood and a Tornado, Desert a Quicksand. M4's `test_disaster_pools.gd` checks that a wrong turn in each area plays a disaster from its own pool. `test_area_schedule.gd`'s pool test (E7) stays.
  - Each new disaster extends `DisasterBase` and follows §5.5: it times itself by `_physics_process` deltas, changes only the car's `scale` and `modulate`, works without a car or a camera, finishes once, and takes 2–4 s from the turn, with the stop. Its particles take their seed from its params, with `use_fixed_seed` (J14, J16). `test_sinkhole.gd` is the model for its tests.
  - Until Godot 4.8, grow a `Polygon2D` by its `scale` and tint it by `self_modulate`, never by its `polygon` or `color` (P5, godotengine/godot#124726).
- **M5:**
  - M5.1's art replaces the grey crash arrow (J22), and can bring the sinkhole's shader and clip mask (Q3, J15).
  - M5.2's `PropPool` is part of `World`, which a retry keeps (J12). It must take back the last run's props when a new run starts, as `WorldRenderer.bind()` drops the last run's tiles (J11).
  - M5.4's `SaveService.record_disaster(id, area, stats)` goes in `main.gd`, where the sequence ends, with the `id` of the director's `disaster` (J7).
  - M5.5 adds the title screen, and the **Title** button on the game-over screen (Q5, J8). `GameState` already allows `GAME_OVER` → `TITLE`.
  - The HUD still shows the seed in release builds (Q6). If that should change, it's a UI decision for M5.5.
  - M2's dust still takes Godot's random seed in each car, unlike the smoke (J16). M5.1's art can fix its seed the same way.
- **M6:**
  - M6.2's `vibrate_handheld(250)` "when a disaster starts" goes where the director plays the disaster, after the stop.
  - M6 tunes §5.9's values on the devices, and M6.5's checklist can take E13's steps.
- **IP:** fold this plan's Δs into IP once it's approved (Q12).
- **Optional:** a CI check for editor warnings, built on §6.3's language-server probe (M2 §9).
