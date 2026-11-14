# Tutorial: Learning the Pattern Before the City

Done on 2026-11-13: the plan PR #65 and PRs 1–3, #66–#68. The plan called the work TUT. Until the save says it is done, Play starts a run with a tutorial: the City's look, no disasters and no death, and wrong exits that loop back to the road. After 12 correct turns in a row the run goes on in the City, under its rules, on the same road, with no break. The owner answered none of Q1–Q18, so their defaults stand. The full plan, with its verification, negative cases and review history: `git show 08f316f:TUTORIAL_PLAN.md`.

## 1. Goal and exit criteria

Goal: let a new player learn the pattern without dying; on `main` the first wrong turn ended the run. For its runs it overrides `plan.md`'s rule that health does not regenerate (T2), IP D8 (T8) and `docs/M5.md` E1 (T6). The exit criteria, E1–E10, cover the look, the rules, the streak, the switch, health, who gets it, the seed's road, the checks, the Web and the Fold4, and `plan.md`; all but E9's Fold4 check are met (§7).

## 2. Findings

- **T1.** Every wrong exit ended the run. In the tutorial it loops back and ends only the streak.
- **T2.** 0 health and the off-road limit crashed the car, and nothing healed it. In the tutorial neither crashes it, and it heals.
- **T3.** The buffer lays up to 55 tiles ahead, so the tutorial's road goes on past the switch. The City's rules hold on it, and its group closes its loops.
- **T4.** The schedule counted turns from the run's start, and only an entry's exact turn. It counts from the switch, and a passed turn counts.
- **T5.** The distance, turns and area entries counted from the run's start. They count from the switch.
- **T6.** The save had no place for the tutorial: version 2.
- **T7.** Tests, `smoke.sh`, `--area` and the Start button must not get it: `_tutorial_wanted()`.
- **T8.** IP D8 promises one road per seed, but the tutorial's length depends on the player. Its own stream and whole groups keep the road after it the seed's.
- **T9.** Nothing followed a car that drove on after a mistake. The trigger loses it and finds it on the path; it brakes for the turns ahead.
- **T10.** A run ends only at game over, so a player who never finds the pattern can only close the app. Left so (Q12).
- **T11.** Past the switch, a loop could bring a car back past the next junction, which then never decides. That is a missed turn.
- **T12.** Loops must keep the road's rules (D7) and lie within `DEAD_END_MAX_TILES` (9) rows of their junction. They do.
- **T13.** No tile type for a loop: `DEAD_END` tiles with two exits.
- **T14.** `CarController` moves its node after the step, so the camera snaps to a rescued car deferred.
- **T15.** The music must play on at the switch: `CrossFade.fade_to()` already ignores the playing track.
- **T16.** HB (#62) changed the same lines of `CarSim._drive_off_road()`. Moot: #62 closed unmerged.
- **T17.** The Web has no font fallback: `test_smoke.gd` checks the tutorial's texts.
- **T18.** The chime came only with `turn_completed`. It comes with `streak_changed` too.
- **T19.** DN (#64) starts a zone's clock in `_on_area_changed()`, which the switch doesn't call. The switch starts it too (Q18).

## 3. Decisions

- **Q1.** The road: T's in groups of four, each wrong exit a loop to the junction two on or two back. A crossroads' third exit would lead into the space that the path and a loop enclose, where it could only end.
- **Q2.** When the City starts: at the streak's last turn, on the road already laid.
- **Q3.** Who gets it: Play, until it is finished once, and only in the City.
- **Q4.** The off-road limit: it ends the streak; 0 health ends nothing.
- **Q5.** A car far off the road: 6 tiles off in one go, it is put back on the path, at rest.
- **Q6.** Healing: on the road only, from 0 to full in 2 s.
- **Q7.** The car at the switch: full health, and its top speed grows from there.
- **Q8.** A U-turn: a mistake.
- **Q9.** A lost car: it brakes for each junction and loop corner ahead (§4.6).
- **Q10.** The texts: "Tutorial", "12 turns in a row" and "turns 3/12", with no distance; "City" at the switch.
- **Q11.** Showing the pattern: no hint, and no sound for a mistake. The streak, the chime on each correct turn and the counter's reset teach it.
- **Q12.** A way out: none; the tutorial ends only with its streak. The autopilot takes 18 s (P1).
- **Q13.** HB's off-road meter: as in the City. Moot.
- **Q14.** A loop driven past the switch: back onto the path at or past the next junction is a missed turn.
- **Q15.** The areas after it: the schedule counts from the switch, so Rural comes at the 34th turn after it.
- **Q16.** Leaving mid-tutorial: nothing is saved.
- **Q17.** The road behind: the buffer frees it as on `main`, so a car that drives back far can find a loop cut (§5.2).
- **Q18.** The day: the zone's clock runs in the tutorial and goes back to the morning at the switch, as the distance does (`docs/DAYNIGHT.md §5.4`). DN PR 3 (#72) added that line to `_on_tutorial_completed()`.

## 4. Work breakdown

- **PR 1** (#66): the road: `RoadGenerator`'s groups and loops, `end_tutorial()` and the schedule's turn base.
- **PR 2** (#67): the rules: `JunctionTrigger`'s streak, `CarSim`'s heal, rescue and braking, the tuning and `RoutePilot`.
- **PR 3** (#68): the game: who gets it, the save, the switch, the HUD, the chime and the docs.

### 4.6 Review fixes

Each fix came with a test and a negative case. F1, 989b387: a group's last junction lies within `BUFFER_BEHIND` of its first, so a car that drives forward finds each loop whole (§5.2). F2, 034e721, and F6, 3cc0b5e: a lost car brakes only for the turns ahead, but for each junction, as any car does, so it can turn down the foot of a T that it enters by an arm; `RoutePilot`'s `back_at` tests it. F4, 267d65f, made the migration count only a discovered area as a run (§5.6); F3, F7 and F8 added tests.

## 5. Design

The tutorial is a road in the City's look where every wrong exit loops back to the path and nothing ends the run, until `TUTORIAL_STREAK` (12) correct turns in a row. `TUTORIAL_HEAL_SECONDS` (2.0) and `TUTORIAL_RESCUE_TILES` (6.0) tune the heal and the rescue (`config/tuning.gd`).

### 5.1 The road

`RoadGenerator.new()` takes a third argument, `p_tutorial`. While its `tutorial` holds, `_junction()` returns `_tutorial_junction()`; a run without it gets `main`'s road. With `part = turn_count % 4`, the junctions are T's in groups A to D: A and C turn left, B and D right, so each group starts heading north. Straights come from `_rng_tutorial`, seeded with `hash("%d:tutorial" % run_seed)`. Each wrong exit is a loop whose first leg has L = `min_straight` + 1 cells, the last a corner. A lays its leg east; B lays the rest of A's loop, up the column L east of A and along C's row into C's east exit, and its own leg south; C lays the rest of B's loop, along the row L south of B and up into D's south exit. So a car wrong at A or B drives round into C or D and on, and one wrong at C or D back to A or B. The loops never cross, keep the path's straights, and have 11–17 tiles, at most 5 rows before and 8 past their junction. Their tiles are `DEAD_END` tiles with two exits, owned by the junction that lays them, with the nearer end's `junction_index` and `branch_exit`. `end_tutorial(turn_base)` sets `_ending`, and the tutorial ends at `turn_count % 4 == 0`, so every loop closes. It ends heading north, having drawn nothing from `_rng_road`, so the seed's road follows from its first junction.

### 5.2 The trigger

`JunctionTrigger` adds `streak`, `streak_changed(streak)`, `tutorial_completed(junction)` and `on_rescued(tile)`. In the tutorial a mistake calls `_lose()`: the streak goes to 0 and `next_junction` to null, so the car is *lost*. Mistakes: a wrong exit, a U-turn, entering a path tile from a loop, rejoining the road on a loop, and the off-road limit. Driving from path tile k to k+1 finds the car, with the next junction the first after k, so none is skipped; a rescue on tile t does the same from t. At `TUTORIAL_STREAK`, `tutorial` turns false and `tutorial_completed` fires, in the same call as the last `streak_changed`. Past the tutorial, entering a path tile from a branch at or past the next junction is `_fail(-1)`. The buffer frees A's leg with A and the rest of A's loop with B, so D must lie within `BUFFER_BEHIND` (20) path tiles of A: 9–18 in the City. A car that drives back 9 tiles or more can find a loop cut, and is rescued.

### 5.3 The car

While `trigger.tutorial` holds, `_drive_off_road()` takes damage, but reports the off-road limit to `trigger.on_offroad_limit()` and never calls `_crash()`. `_tutorial_step(delta)` heals `START_HEALTH / TUTORIAL_HEAL_SECONDS * delta` on the road. At `TUTORIAL_RESCUE_TILES` off it, `_rescue()` puts the car at rest on `path_tile`, or the tile before if that is a junction, calls `trigger.on_rescued(tile)` and sends `rescued`, which `main.gd` connects to the camera's `snap_to_target()`, deferred. `is_lost()` is `trigger.tutorial and trigger.next_junction == null`. While lost, `distance_to_turn()` is the distance to the first tile ahead within `junction_brake_distance` that is a junction or a loop's corner, so the car slows to `junction_speed` for each and can turn down a T's foot. `_tutorial_step()` restarts `dist_on_straight` while the car brakes, and off the road once it is lost, so it heads for `junction_speed`, slowed; each `streak_changed` restarts it too.

### 5.4 The HUD and the sounds

In the tutorial the banner shows `Hud.TUTORIAL_BANNER`, "Tutorial" and "12 turns in a row", and `_reset()` shows `Hud.STREAK_TEXT`, "turns 0/12", with the distance hidden. At `tutorial_completed` the distance returns and the turns read "turns 0"; `area_changed` then shows "City". `AudioDirector` chimes `junction` when `streak_changed` brings a streak above 0; a mistake is silent (Q11). The City's music plays on through the switch. `test_smoke.gd` checks the texts' glyphs.

### 5.5 The switch and the stats

At J, the streak's last correct turn, the trigger sends `tutorial_completed(J)`. `CarSim` takes `START_HEALTH` and sets `dist_total` to 0, so its speed cap grows from `BASE_TOP_SPEED`. `main.gd`'s `_on_tutorial_completed(J)` sets `_origin = J.path_index + 0.5` and `_turn_base = J.turn_number + 1`, calls `end_tutorial(_turn_base)`, `SaveService.complete_tutorial()`, `GameState.end_tutorial()` and `_daylight.cycle.enter()`, and sends `tutorial_completed` and `area_changed`; not `_on_area_changed()`, which would enter the City twice. In the tutorial, `GameState.in_tutorial`, set before `run_started`, leaves the distance, `_sim.progress - _origin`, unset, and turns count only past the switch; `_on_area_changed()` subtracts `_origin` and `_turn_base`. `_due_entry()` counts from `_turn_base` and asks whether an entry's turn has come, so one due on the tutorial's road comes at the City's first junction rather than never. That road plays by the City's rules: a wrong exit there is a disaster, though its loop leads back.

### 5.6 Who gets it, and the save

Until the save says it's done, Play starts a run in the City with the tutorial, which has no disasters. `--play` and `--autopilot` skip it, and `--tutorial` forces it; `main.gd`'s `_tutorial_wanted()` gives none to a run that starts past the City. `SaveData.VERSION` 2 adds `"tutorial": {"done": false}`; `_v1_to_v2()` marks it done if the save has a run: a best distance above 0, or a discovered area. `SaveService.complete_tutorial()` writes at once. A test that presses Play for a run without the tutorial marks it done first, in a save in memory: `SaveService.use_memory()`, then `SaveService.complete_tutorial()`, as `tests/integration/test_title.gd` does.

### 5.7 Tests

`RoutePilot` (`tests/helpers/route_pilot.gd`) drives as the autopilot does, but takes the wrong exit at the turns in `wrong_at`, following the loop back, and turns down the junction's foot at those in `back_at`. `tests/sim/test_tutorial_run.gd` drives the tutorial and on; each class has its `test_*_tutorial.gd`, and `tests/integration/test_tutorial.gd` plays the game.

### 5.8 Documents and comments

`plan.md` §2.7 describes the tutorial, `AGENTS.md` §2 has §5.6's rule, and `docs/agents/checks.md` §2 lists `--tutorial`.

## 6. Verification

The five checks passed on each PR; at PR 3's head, 148 scripts loaded, and GUT ran 70 test scripts, 524 tests and 423,545 asserts. Each of 67 negative cases failed its tests. The Web build passed in Chrome 157 and Firefox 156.

### 6.5 Measurements

- **P1.** With seed 1 the autopilot finished the tutorial in 17.9 s, with 48 tiles and 9 junctions laid past it. The first 12 junctions after the switch were the tutorial's, and the run went on to turn 230 with no rescue.
- **P2a.** With `TUTORIAL_STREAK` 4 every test passed: no streak in the mistake tests reaches 4 first.
- **P2c.** With `TUTORIAL_HEAL_SECONDS` 3.5 every test passed: the autopilot steers the heal test's car.
- **P2d.** With `TUTORIAL_RESCUE_TILES` 4 every test passed: the off-road tests stop short of the rescue, which stops the car. In another probe a car with full health reached 0 health 3.89 tiles off the road, so a rescue under about 3.9 tiles would come first.

## 7. Owner actions

E9's Fold4 check has no recorded result. On a debug APK of `main`, first with an earlier build's save that has runs: Play starts with no tutorial. Then, after `adb shell pm clear com.pompomon.roadgame`: the tutorial's look, chimes and counter; a wrong turn resets it while the car drives on; the heal and the rescue; the switch with no stop; no tutorial after Retry or a restart; both screens and Back. Judge the loops' corners by hand, and the bar of a car left alone, at about 40% after each rescue.

## 9. Notes for later

- **A way out** (Q12): Skip or Title on the pause screen (`ui/hud.gd`); `ui/main.gd`'s `_to_title()` takes only game over.
- **A hint** (Q11): "left" or "right" in text; the font has no arrows.
- **M7.** IP M7.5's device checks gain the tutorial, on both screens and through a fold. IP M7.2's haptics should mark `EventBus.streak_changed` above 0 as a correct turn.
- **Other areas.** `_tutorial_wanted()` allows only the City. The generator lays the tutorial in the run's first area, so another needs only that rule changed, and straights that fit the loops.
- **The save.** Keep `_v1_to_v2()` after `_v0_to_v1()` in `SaveData.migrations()`.
- **Tuning.** Keep `TUTORIAL_STREAK` at 4 or more (P2a) and `TUTORIAL_RESCUE_TILES` above about 3.9 (P2d). A change to the City's straights changes the loops, and can make a group longer than the buffer keeps: `test_road_generator_tutorial.gd` checks both.
- **After a rescue.** If 40% health reads badly, `CarSim._rescue()` could give full health.
- **The road behind** (Q17): keeping each group whole would change `road/road_buffer.gd`'s `_free_before()`.
