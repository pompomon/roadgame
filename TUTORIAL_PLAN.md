# Tutorial: Learning the Pattern Before the City — Detailed Plan

Status: plan, in review (§4) · 2026-11-13 · The owner hasn't answered Q1–Q18 yet, so the plan and the prototype follow their defaults (§3) · Scope: a tutorial at the start of a new player's runs: a road with the City's look, with no disasters and no death, whose wrong exits loop back to the road. After 12 correct turns in a row the run goes on in the City, on the same road, with no break. This plan calls the work TUT. It comes after ZS (#60, #61), beside HB (#62), and before M7.

The owner asked: "Explore the codebase and create a detailed implementation plan for a tutorial zone, which would visually mimic the city, but won't have any disasters, and no death penalty for wrong turn. Instead all the roads in the tutorial city are possible, but only after making 12 correct left-right turns (make it configurable for future tuning), the player seamlessly is transitioned to the proper city. If the player makes a wrong turn in the tutorial city, the counter resets, but no other penalties applied. Road damage still occurs in the tutorial zone, but car still drives with 0 health and health is auto-healed in 2 seconds of driving on the road. Ask any clarifying questions if needed."

**How this plan reads the request.**
- *Visually mimic the City*: the tutorial's road is in the City's area, so it has the City's tiles, props, ground, music and ambience. Only the banner and the HUD's turns say it is the tutorial (E1).
- *All the roads are possible*: every exit of every junction leads on. There are no dead ends: each wrong exit is a loop that joins it to the wrong exit of the junction two on, or two back (§5.1, Q1).
- *12 correct left-right turns*: 12 in a row, since a wrong turn resets the counter. The 12 is `Tuning.TUTORIAL_STREAK` in `config/tuning.gd` (D11), and the tests pass with 4 and 13 as well (P2).
- *Seamlessly transitioned*: no screen, no stop, and no new road under the car. At the 12th correct turn the City's rules hold, and once the road already laid ahead is driven, the City's road follows (§5.5, Q2).
- *Road damage still occurs, the car drives with 0 health, and heals in 2 s on the road*: off the road the car takes the City's damage and drives on at 0. On the road it heals from 0 to full in 2 s, `Tuning.TUTORIAL_HEAL_SECONDS` (§5.3, Q6).
- *Clarifying questions*: Q1–Q18 (§3). The owner may answer them on this plan's PR. Until then the prototype follows their defaults.

**Verified locally.** Every file that this plan changes was first built on branch `tut/prototype`, on top of `main` (528196e), in 18 commits, 31d5045 to e64d381 (§4.1). It passed the five checks with Godot 4.7.2 (§6.1), and so did its trees split for PRs 1 and 2, and CI runs with its exports (§6.4). Each of its 66 negative cases made tests fail in a run of the whole suite, and its 4 probes of other tunings made none fail (§6.2). The editor's warnings didn't change (§6.3). Probes measured the road laid past the streak's end (P1), the loops (P3), how far a car drives at 0 health (P5) and what a car finds that drives back past the road the buffer keeps (P6), and showed that a run without the tutorial gets `main`'s road: a digest of 72,000 tiles is unchanged (P4, §6.5). The Web build ran in Chrome (§6.4). Not done yet: Firefox, for PR 3 (§6.4), and the Fold4 (§7). A model of another family, gpt-6.1-sol, reviewed the plan and the prototype. Of its 5 findings, F2–F5 were fixed, and so was F1 for a car that only drives forward; F1's rest, a loop that the buffer can cut behind a car that drives back, is left to the owner as Q17. Its review of the fixes found 2 more, F6 and F7, both fixed (§4.6, §4.7).

- Godot 4.7.2-stable
- GUT 9.7.1
- gdtoolkit 4.5.0 on Python 3.12.3. shellcheck isn't installed locally, so `lint.sh` skipped it; no shell script changes
- git 2.51.1

**Precedence.** For TUT, this document replaces the following, wherever it marks a difference with **Δ** and its finding (T#, §2). Everything else stands: the City's rules, the areas, the legends and the other plans.
- `plan.md`:16, "Players discover it by dying", and :26, a run starts in the City: until the player has finished the tutorial, Play starts a run with it (T1, T7). PR 3 adds `plan.md` §2.7.
- `plan.md` §2.4 (:55), no regeneration: in the tutorial the car heals, and 0 health ends nothing (T2).
- IP §5.3 and D8: a third stream, `hash("%d:tutorial" % seed)`, lays the tutorial's straights. The City's road after the tutorial is still the seed's, but where it starts depends on where the streak ends (T8).
- M5_PLAN.md's save, version 1 (its E1): version 2 adds whether the tutorial is done (T6).
- The area schedule's turns (M4, ROADGEN_PLAN.md): after a tutorial they count from the City's start (T4).

**Reference code.** This plan has no appendices. PRs 1–3 apply the difference between `main` (528196e) and `tut/prototype` (e64d381), split by file (§4.1). The prototype never gets a PR of its own.

**Prerequisites.** ZS is merged: its PR 1 (#61) landed as 528196e, which the prototype is built on. HB (#62, a plan) may land before or after TUT's PRs: the two meet in one function, `CarSim._drive_off_road()` (§4.5, T16). So may DN (#64, a plan), which meets TUT in two functions of `ui/main.gd` (§4.5, T19, Q18). No repository settings change.

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

Goal: let a new player learn the pattern without dying. Today the first wrong turn ends the run (T1), so the pattern is learned only by dying, as `plan.md`:16 intends. The tutorial keeps the discovery, since it never shows the pattern (Q11), but takes away the penalty.

Until they finish the tutorial, Play starts each run with it. The road looks like the City, and the area banner says "Tutorial" and the goal, "12 turns in a row". Its junctions are all T's; the City has crossroads too. A correct turn chimes as in the City and adds one to the streak, which the HUD shows as "turns 3/12", with the distance hidden. A wrong turn sets the streak to 0 and does nothing else: the wrong exit is a loop that comes back onto the road at the junction two on, or two back. On it the car brakes for each corner, as it does for a junction (Q9). A U-turn is a mistake too (Q8). Off the road, the car takes damage at the City's rate, and drives on with 0 health. Back on the road, it heals from 0 to full in 2 s. If it drives 6 tiles off the road in one go, it is put back on the road, at rest, before the junction it missed (Q5).

At the 12th correct turn in a row, the run goes on in the City, under its rules, on the same road: no screen, no stop, and no new road. The banner says "City", the HUD shows the distance and "turns 0", the car has full health, and the music plays on. The run's distance, turns and areas count from that junction. The road already laid ahead stays the tutorial's, loops and all, to the end of the generator's group of four: in P1, 12 junctions, 9 laid ahead at the switch and 3 that close the group. By the City's rules, a wrong exit there is a disaster. Then the City's road comes: the seed's road, from its first junction, with its crossroads and dead ends. The tutorial is done for good: the save records it at once, and later runs start in the City.

The tutorial's road comes in groups of four T junctions, A to D, which turn left, right, left, right. Each wrong exit is a loop, which the generator lays as dead-end tiles: A's leads round to C's wrong exit, and B's to D's. Here is a group with straights of 2 tiles, on the grid with north up; the game shows it isometric:

```
     x: -6 -5 -4 -3 -2 -1  0  1  2  3
y -5     #                                 # the path; A–D its junctions
y -4     #                                 a A's loop: 3 tiles E, then N, then W into C
y -3     D  #  #  C  a  a  a  a  a  a      b B's loop: 3 tiles S, then W, then N into D
y -2     b        #                 a
y -1     b        #                 a      A car that goes wrong at A drives round
y  0     b        B  #  #  A  a  a  a      into C from the E, and on west, out of C's
y  1     b        b        #               correct exit. One that goes wrong at C
y  2     b        b        #               drives A's loop the other way, into A from
y  3     b  b  b  b        #               the E, and on west towards B.
```

### Exit criteria

| # | Exit criterion | Checked by |
|---|---|---|
| E1 | **The City's look.** The tutorial's road, its loops included, is in the City: its tiles, props, ground, music and ambience are the City's. Its junctions are T's. The banner reads "Tutorial" and the goal | `test_road_generator_tutorial.gd`, `test_hud.gd`; the Web (§6.4) and the Fold4 (§7) |
| E2 | **No disasters and no death.** In the tutorial, a wrong exit, a U-turn, a rejoin off the path and the off-road limit end the streak and nothing else, and 0 health ends nothing. Every wrong exit loops to the junction two on or two back, over 100 seeds of 48 turns. A car that goes wrong, or drives off and is left alone, drives on | `test_road_generator_tutorial.gd`, `test_junction_trigger_tutorial.gd`, `test_car_sim_tutorial.gd`, `test_tutorial_run.gd` |
| E3 | **The streak.** Each correct turn adds 1 and chimes; a mistake sets it to 0, with no sound. The HUD shows "turns k/N", where N is `Tuning.TUTORIAL_STREAK`, 12. With N 4 or 13, every test passes (P2a, P2b) | `test_junction_trigger_tutorial.gd`, `test_hud.gd`, `test_audio_director.gd`, `test_tutorial.gd`; §6.2 |
| E4 | **A seamless switch.** At the Nth correct turn, the City's rules hold at once, on the same road, with no pause. The tutorial's road ahead closes its loops within its group of four, and the seed's road follows. The run's distance, turns and area entries count from the switch; the car has full health; the music plays on. A wrong exit on the tutorial's road past the switch is a disaster | `test_tutorial.gd`, `test_tutorial_run.gd`, `test_car_sim_tutorial.gd`, `test_road_generator_tutorial.gd`, `test_audio_director.gd` |
| E5 | **Health.** Off the road, the car takes the City's damage, and at 0 drives on. On the road, it heals from 0 to full within `TUTORIAL_HEAL_SECONDS`, 2 s, and a frame. At `TUTORIAL_RESCUE_TILES`, 6, off the road in one go, it is put back on the path, before the junction if it left there, with the camera on it. Other tunings pass too (P2c, P2d) | `test_car_sim_tutorial.gd`, `test_tutorial_run.gd`, `test_tutorial.gd`; §6.2 |
| E6 | **Who gets it.** Play starts a run in the City with the tutorial until it is done. The save records that at once, and a save from before TUT that has a run counts as done. `--play` and `--autopilot` skip it; `--tutorial` forces it; a run that starts past the City has none | `test_tutorial.gd`, `test_save_data.gd`, `test_save_service.gd`, `test_game_state.gd` |
| E7 | **Determinism.** A run without the tutorial gets `main`'s road, its branches included: a digest of 72,000 tiles is unchanged. The tutorial's road depends only on the seed, and the City's road after it is the seed's from its first junction | P4 (§6.5); `test_road_generator_tutorial.gd` |
| E8 | **The checks.** The five checks pass on each PR's head, and the tree stays clean. Every negative case fails a test, and the editor's warnings are `main`'s | §6.1–§6.3 |
| E9 | **The Web and the Fold4.** With a fresh save, Play starts the tutorial in Chrome and Firefox, on the Web build, and on the debug APK on the Fold4. Its texts show in the game's font, and the switch to the City has no break | §6.4, §7 |
| E10 | **The documents.** `plan.md` §2.7 says what the tutorial is and who gets it | Review |

---

## 2. Review findings

Line numbers are `main`'s at 528196e. Each finding gives what is wrong or missing for a tutorial, the evidence, and the fix that the prototype makes.

### High

| # | Finding | Evidence | Fix |
|---|---|---|---|
| T1 | **Every wrong exit ends the run, and leads nowhere.** The generator lays each wrong exit as a dead end of 6–9 tiles. The trigger sends any wrong exit to `_fail()`, and so does the off-road limit near a junction: the disaster plays, and game over follows. No road lets a wrong turn cost less, or leads back to the path | `road/road_generator.gd`:116–150 (dead ends :129); `road/junction_trigger.gd`:54–56, :59–66; `plan.md`:29 | The tutorial's wrong exits are loops back onto the path, at the junction two on or two back (§5.1). In the tutorial, the trigger's mistakes end the streak, not the run (§5.2) **Δ `plan.md`:16, :29** |
| T2 | **At 0 health the car crashes, and nothing heals it.** Off the road, `_drive_off_road()` takes health and crashes at 0, and at the off-road limit on a straight. `plan.md` rules out regeneration | `car/car_sim.gd`:290–300 (:292 the damage, :295 `_crash(HEALTH)`, :300 `_crash(OFFROAD)`); `plan.md`:55 | In the tutorial, the car takes the damage, and the limit ends the streak, but it never crashes. On the road it heals `START_HEALTH` in `TUTORIAL_HEAL_SECONDS` (§5.3) **Δ `plan.md`:55** |
| T3 | **The road ahead is laid before the streak ends.** The buffer keeps up to 55 tiles ahead, and has sent them to the renderer. When the autopilot's streak ended, 48 tiles and 9 junctions lay past it (P1). They can't be laid again, so a switch with no break must play the City's rules on the tutorial's road ahead, and the loops there must close | `config/tuning.gd`:7 (`BUFFER_AHEAD`), :13 (`BUFFER_REFILL_AT`); `road/road_buffer.gd`:35–36, :90–98 | At the switch, the trigger and the car take the City's rules at once. The generator finishes the group of four it is in, so that every loop has both ends, and then lays the seed's road (§5.1, §5.5) |

### Medium

| # | Finding | Evidence | Fix |
|---|---|---|---|
| T4 | **The schedule counts turns from the run's start.** `_due_entry()` enters an area at the turn that equals its entry's. A tutorial's turns would bring Rural (turn 34) that much sooner, and a long tutorial would skip the City. And an entry that falls due while the tutorial's road is laid would never come, since `!=` asks for that exact turn | `road/road_generator.gd`:184–191 (:188); `areas/schedule.tres`:17 | The generator counts the schedule from `end_tutorial()`'s turn base, the turns before the City's first. `_due_entry()` asks whether an entry's turn has come (`>`), so an entry due on the tutorial's road comes at the City's first junction (§5.5, N4, N5) |
| T5 | **The run's stats count from its start.** The distance is the car's path progress, the turns are the trigger's correct turns, and an area's entry is at its first tile. A tutorial would add its road to the distance, the best run and the atlas | `ui/main.gd`:87, :218–224, :251; `road/junction_trigger.gd`:63–66; `autoload/game_state.gd`:20 | In the tutorial the distance doesn't count, and the trigger counts the streak, not the turns. At the switch, `main.gd` keeps the junction as the origin of the run's distance, turns and area entries (§5.5) |
| T6 | **The save has no place for the tutorial.** Version 1 has the best run, the atlas, the collection and the settings. A player who has finished the tutorial would get it again on the next start | `autoload/save_data.gd`:12 (`VERSION := 1`), :36–42; M5_PLAN.md E1 | Version 2 adds `"tutorial": {"done": false}`. The migration from version 1 marks it done if the save has a run. `SaveService.complete_tutorial()` writes it at once (§5.6) **Δ M5 E1** |
| T7 | **Many things start runs, and most must not get the tutorial.** `--play` and `--autopilot` start a run at once, for tests and `smoke.sh`, which checks the autopilot's line. ZS's tests press Play with whatever save. `--area` and the title's Start button start runs in other areas | `ui/main.gd`:7–9, :42, :65, :169–176, :271–278; `tools/ci/smoke.sh`; `tests/integration/test_area_start.gd`, `test_title.gd` | `_tutorial_wanted()`: only a run that starts in the City; `--tutorial` forces it; `--play` and `--autopilot` skip it; else Play, until the save says it is done. ZS's tests mark it done (§5.6, Q3) |
| T8 | **The road must stay the seed's.** IP gives the road one stream from the seed, and D8 promises the same road for the same seed. A tutorial that drew from that stream would change the City's road, and so would one whose length depended on the stream's state. The number of the tutorial's turns depends on the player | IP D8 (:34), §5.3 (:487–489); `road/road_generator.gd`:53 | The tutorial's straights come from their own stream, and its groups of four keep the turn's parity and the heading. So the City's road after it is the seed's from its first junction, wherever the streak ends, and a run without the tutorial is `main`'s (P4) **Δ IP D8, §5.3** |
| T9 | **Nothing follows a car that goes on after a mistake.** The trigger knows only the next junction, and on `main` a wrong exit ends the run. In the tutorial the car goes on: round a loop, back along the path, into the next junction from the wrong side, or off the road far from it, where the road behind may have been freed | `road/junction_trigger.gd`:16, :30–50; `road/road_buffer.gd`:101–112 | After a mistake the trigger *loses* the car, and finds it when it drives on along the path from one path tile to the next. A U-turn and a rejoin off the path are mistakes. While lost, the car brakes for the corners ahead as it does for a junction, and 6 tiles off the road it is put back (§5.2, §5.3, Q5, Q8, Q9) |
| T10 | **A run ends only at game over.** Pause offers only "go on". The back button pauses a running game, and the title is reachable only from game over. A tutorial has no game over, so a player who can't finish it can leave only by closing the app. `GameState` allows RUNNING→TITLE and PAUSED→TITLE, but nothing uses them | `ui/hud.gd`:10; `ui/main.gd`:103–111, :158–164; `autoload/game_state.gd`:10–11 | None by default: the tutorial ends only with its streak (Q12). §9 notes where a way out would go |
| T11 | **After the switch, the tutorial's loops are still on the road.** A car that turns back and drives one comes back onto the path past the next junction, which then never decides. The trigger decides only when the car leaves the next junction's tile | `road/junction_trigger.gd`:30–40 | Past the tutorial, a car that enters the path from a branch at or past the next junction has missed its turn: `_fail(-1)`, as the off-road limit near a junction is (§5.2, Q14) |

### Low

| # | Finding | Evidence | Fix |
|---|---|---|---|
| T12 | **Loops must keep the road's rules.** Dead ends never touch the path; straights are at least 2 tiles (D7); and the buffer frees a junction's branches with it, which `BUFFER_BEHIND` and the props allow for only within `DEAD_END_MAX_TILES` (9) rows of the junction | `road/road_generator.gd`:10–14; `config/tuning.gd`:14–20, :27; `world/prop_layout.gd`:58–63 | A loop turns no sooner after a junction or corner than the path does, and touches no road but at its ends. Its tiles lie at most 5 rows before and 8 past the junction that lays them (P3). The test checks all three over 100 seeds (§5.1, N1) |
| T13 | **There is no tile type for a loop.** Branches are `DEAD_END` tiles of one junction, and the trigger and the buffer find a branch's junction by its `junction_index`. The renderer draws a tile by its exits | `road/road_tile.gd`:6, :23–29; `world/greybox_atlas.gd`:30–38 (the column is `exits - 1`) | Loop tiles are `DEAD_END` tiles with two exits. The junction that lays them owns them, and each has the `junction_index` and `branch_exit` of the nearer end, where a car that rejoins on it went wrong (§5.1, N6, N7) |
| T14 | **The camera can't snap to a rescued car at once.** `CarController` steps the sim, then moves its node. A camera that snaps when the sim reports the rescue would find the node where it was | `car/car_controller.gd`:30–32; `world/camera_rig.gd`:53–54 | `rescued` reaches `snap_to_target()` deferred (§5.3, N29) |
| T15 | **At the switch, the City's music must play on.** The switch names the City again, which the audio director fades to | `autoload/audio_director.gd`:242–244; `audio/cross_fade.gd`:30–37 | Nothing to change: `fade_to()` returns -1 for the track that is playing. `test_tutorial.gd` checks that the music plays on (§5.4) |
| T16 | **HB changes the same lines.** #62 adds `offroad_room_changed.emit()` after `health_changed.emit(health)` in `_drive_off_road()`, where TUT's branch goes | `car/car_sim.gd`:290–300; #62's HEALTH_BAR_PLAN.md §5.1 | Both go after the emit, HB's first. §4.5 gives the resolution of the one conflict (Q13) |
| T17 | **The Web has no font fallback.** "turns 3/12" needs "/", and the banner's text must be in Pixel Operator 8 too | `AGENTS.md` §3; `tests/unit/test_smoke.gd` | `test_smoke.gd`'s glyph test checks both texts (§5.4, N54) |
| T18 | **The chime comes only with `turn_completed`,** which the tutorial doesn't send, since its turns don't count | `autoload/audio_director.gd`:247–248 | The chime also comes with `streak_changed` when the streak grows, not when a mistake ends it (§5.4, Q11, N55) |
| T19 | **DN changes the same functions, and starts a clock in each zone.** #64 runs the zone's clock in `_physics_process()` and starts it again in `_on_area_changed()`, where TUT counts the distance and the City's entries from the switch. TUT's switch doesn't call `_on_area_changed()`, so the City's day would run on from the tutorial's start | `ui/main.gd`:85–87, :218–224; #64's DAYNIGHT_PLAN.md §4.4, §5.4 | The clock runs in the tutorial too, and the switch starts it again (Q18). §4.5 gives the resolution of the two conflicts |

---

## 3. Decisions and open questions

The owner may answer each question, or accept its default. Until then, the prototype and the PRs follow the defaults. A different answer changes the code and tests named in §5.

| # | Question | Default | Alternatives |
|---|---|---|---|
| Q1 | What road does the tutorial have? | T junctions only, in groups of four, whose wrong exits loop round to the junction two on or two back (§5.1). Every exit leads on, and a car that goes wrong drives on, back onto the path | Crossroads too: but a crossroads' straight-on exit leads into the space that the path and the loop round it enclose, so it could only end there. Or dead ends that the car turns round in: no loops, but a road that ends isn't "possible" |
| Q2 | When does the City start? | At once, at the last turn of the streak. The City's rules then hold on the tutorial's road already laid ahead, 12 junctions in P1: the 9 laid at the switch and the 3 that close its group. Then they hold on the seed's road (§5.5) | The City's rules from the seed's road only: the tutorial's rules, and its streak, would go on for those junctions. Or a set piece, the tunnel, between the two, which would bring Rural sooner |
| Q3 | Who gets the tutorial? | Play starts a run with it until the player has finished it once. A save from before TUT that has a run counts as finished. `--play` and `--autopilot`, which tests and `smoke.sh` use, skip it; `--tutorial` forces it. Only a run that starts in the City has it: not one that `--area` or the title's Start button starts elsewhere (§5.6) | Every run. Only the first run, finished or not. A Tutorial button on the title, with no tutorial at Play |
| Q4 | What does the off-road limit do in the tutorial? | It ends the streak, as a missed turn would in the City. Nothing else: 0 health ends nothing (§5.2) | Nothing: only exits count. Or 0 health ends the streak too |
| Q5 | What if the car drives far off the road? | Once it has driven `TUTORIAL_RESCUE_TILES`, 6, off the road in one go, it is put back on the path at rest: on the last path tile it was on, or the tile before it if that is a junction, so it can take its turn again. The streak is then 0, and the camera snaps to the car (§5.3) | No rescue: the player steers back. Or another distance. Or a fade to black and back |
| Q6 | How does the car heal? | On the road, at `START_HEALTH / TUTORIAL_HEAL_SECONDS`, 50 a second: from 0 to full in 2 s, and from 60 in 0.8 s. It doesn't heal off the road (§5.3) | Full health at once after 2 s on the road. Or 2 s to full from any level |
| Q7 | What does the car have at the switch? | Full health, and its top speed's growth counts from the switch, as at a run's start. The car keeps its speed (§5.5) | Keep the health, which 2 s on the road fills anyway. Keep the growth: under 0.1 tile/s, too little to see |
| Q8 | Is a U-turn a mistake? | Yes: a car that drives back from one path tile to the one before ends the streak, and the trigger finds it once it drives on (§5.2) | No: only exits count. Then a car could drive back and take a junction again |
| Q9 | How does a lost car drive? | Like any car on the road: it brakes to the area's junction speed for the first tile ahead that is a junction, whichever exit it will take, as a car on the path does, or a loop's corner, which it can't drive straight through. Between them it speeds up as on any straight, and the straight starts again at each (§5.3) | A cap at the junction speed for as long as it is lost, the prototype's first rule: the internal review called it a penalty beyond the counter's reset, since it slows the car on the loops' straights and on the path until a junction finds it (F2, §4.7). Or braking only for a tile that it can't drive straight through, the second: a car that comes into a T by an arm, from a loop or driving back along the path, then can't turn down its foot on the road (F6). Or no braking: then most cars miss a loop's first corner, and go off the road |
| Q10 | What do the texts say? | The banner: "Tutorial" and "12 turns in a row". The turns label: "turns 3/12", with the distance hidden. At the switch, the banner says "City" (§5.4) | Other words. The distance shown in the tutorial too |
| Q11 | Does the tutorial show the pattern? | No: no hint, and no sound for a mistake. The player learns it from the streak, the chime on each correct turn, and the counter going back to 0 (§5.4) | A hint, "left" and "right" in text, since the font has no arrows, after some mistakes. A sound for a mistake |
| Q12 | Can the player leave the tutorial? | No: it ends only with the streak, or when the app is closed. The tutorial is short for a player who has the pattern: the autopilot takes 18 s (P1) | Skip on the pause screen, in the tutorial only, which marks it done. Or Title on the pause screen in every run (§9) |
| Q13 | How does HB's off-road meter (#62) work in the tutorial? | As in the City: it empties at the area's off-road limit, which in the tutorial ends the streak (§4.5) | Hidden in the tutorial. Or one that empties at the rescue's distance |
| Q14 | Past the switch, what if the car turns back and drives a loop of the tutorial's road? | Coming back onto the path at or past the next junction is a missed turn: a disaster, as the off-road limit near a junction is (§5.2) | Nothing: the car skips the junctions it went round |
| Q15 | When do the City's areas come after a tutorial? | The schedule counts from the switch: Rural at the 34th turn after it, as in a run without the tutorial. The tutorial's road past the switch counts, so on the seed's road Rural comes as many junctions sooner, 12 in P1 (§5.5) | From the run's start: Rural sooner, or at once after a long tutorial. Or from the seed's road's first junction: Rural later, at the 46th turn after the switch in P1 |
| Q16 | What if the player leaves in the middle of the tutorial? | Nothing is saved: the next run starts it again from 0 (§5.6) | Save the streak |
| Q17 | What if a car drives back past the road that the buffer keeps? | Nothing new: as on `main`, the buffer keeps `BUFFER_BEHIND`, 20, path tiles behind the furthest the car has been, with their branches. A car that only drives forward finds both ends of every loop, which a test checks (§5.1). One that turns round, drives back 9 tiles or more to a junction and takes its wrong exit can find the far end of the loop gone. It leaves the road there and is put back on the path, as anywhere else off the road (P6) | Keep each group of four whole until all of it is behind: a change to the buffer, `road/road_buffer.gd`'s `_free_before()`, that only the tutorial needs |
| Q18 | With DN (#64), how does the day run in the tutorial, and when does the City's start? | As in any zone: the clock runs in the tutorial from the run's morning, and goes back to the morning at the switch, as the City's distance and turns do. The light follows at DN's rate, with no jump (§4.5). In DN's day of 120 s, dusk comes 50 s into the tutorial, and the night 65 s in, where DN keeps the road readable (its Q10) | (a) The day runs on from the tutorial's, as the music does: no line at the switch. A player who took a minute and a half over the tutorial then meets the City at night. (b) The tutorial stays in the morning: the clock runs only outside it |

---

## 4. Work breakdown

TUT is three PRs, after this plan's PR, stacked as `AGENTS.md` §5 says. Each PR passes the checks on its own:

| PR | Branch | Base | What |
|---|---|---|---|
| Plan | `tut/plan` | `main` | This document only |
| 1 | `tut/1-road` | `main`, once the plan has landed | The tutorial's road: groups of four T's whose wrong exits loop back, its end, and the schedule's turn base (§5.1, §5.5) |
| 2 | `tut/2-rules` | `tut/1-road` | The rules: the trigger's streak and the lost car; the car's damage, heal, rescue and speed; the tuning (§5.2, §5.3) |
| 3 | `tut/3-game` | `tut/2-rules` | The game: who gets the tutorial, the save, the switch and the stats, the HUD, the chime, and `plan.md` (§5.4–§5.6) |

### 4.1 Porting from the prototype

`tut/prototype` has 18 commits on 528196e. Each PR's branch takes its files' difference:

```bash
git fetch origin main '+refs/heads/tut/*:refs/remotes/origin/tut/*'
base=528196e proto=origin/tut/prototype
pr1=(road/road_generator.gd road/road_tile.gd 'tests/unit/test_road_generator_tutorial.gd*')
pr2=(road/junction_trigger.gd car/car_sim.gd config/tuning.gd 'tests/helpers/route_pilot.gd*'
  'tests/unit/test_junction_trigger_tutorial.gd*' 'tests/unit/test_car_sim_tutorial.gd*'
  'tests/sim/test_tutorial_run.gd*')
git switch -c tut/1-road origin/main
git diff $base $proto -- "${pr1[@]}" | git apply --index --3way
git commit    # road: a tutorial before the City, whose wrong exits loop back (TUT PR 1)
git switch -c tut/2-rules
git diff $base $proto -- "${pr2[@]}" | git apply --index --3way
git commit    # road, car: the tutorial's streak, heal and rescue (TUT PR 2)
git switch -c tut/3-game
git diff $base $proto -- . "${pr1[@]/#/:!}" "${pr2[@]/#/:!}" | git apply --index --3way
git commit    # ui, autoload: the tutorial in the game, and its save (TUT PR 3)
git diff --stat $proto -- . ':!TUTORIAL_PLAN.md'    # only main's changes since 528196e
```

If `main` has moved, run §6.1's checks again on each branch, since the counts may change. Split this way from e64d381, PR 3's tree is the prototype's, and the trees of PRs 1 and 2 pass the checks alone (§6.1).

### PR 1: The tutorial's road **Δ IP D8, §5.3; T1, T3, T4, T8, T12, T13**

| Area | Files | What |
|---|---|---|
| Road | `road/road_generator.gd` | A third argument, `tutorial`. While it holds, `_junction()` lays `_tutorial_junction()`'s groups of four T's, whose wrong exits loop back (§5.1). `end_tutorial(turn_base)` ends the tutorial with its group, and `_due_entry()` counts the schedule from the turn base (§5.5) |
| Road | `road/road_tile.gd` | Comments only: a loop is made of dead-end tiles, and a tile's `junction_index` is the nearer end's |
| Tests | `tests/unit/test_road_generator_tutorial.gd` (new) | 3 tests (§5.7) |

Steps:
1. Port the files (§4.1).
2. Run the five checks (§6.1), the digest (P4), N1–N7 and N60 (§6.2).

Expected counts: 143 scripts load; 66 test scripts, 483 tests, 423,226 asserts. `smoke.sh` prints `main`'s lines, the last `autopilot: tile 165, turns 35, area rural`.

Acceptance: E2's road, E7, and E8 for PR 1.

### PR 2: The tutorial's rules **Δ `plan.md`:29, :55; T1, T2, T9, T11, T14**

| Area | Files | What |
|---|---|---|
| Road | `road/junction_trigger.gd` | `tutorial` and `streak`, with the signals `streak_changed` and `tutorial_completed`. In the tutorial, a mistake ends the streak and loses the car, which the path finds again; the streak's last turn starts the City's rules. Past it, a loop back past the next junction is a missed turn (§5.2) |
| Car | `car/car_sim.gd` | In the tutorial: damage but no crash, the off-road limit to the trigger, the heal, the rescue and the `rescued` signal, and the lost car's braking for junctions and corners. At the switch, full health and the speed's growth from 0 (§5.3, §5.5) |
| Tuning | `config/tuning.gd` | `TUTORIAL_STREAK` 12, `TUTORIAL_HEAL_SECONDS` 2.0, `TUTORIAL_RESCUE_TILES` 6.0 |
| Tests | `tests/helpers/route_pilot.gd`, `tests/unit/test_junction_trigger_tutorial.gd`, `test_car_sim_tutorial.gd`, `tests/sim/test_tutorial_run.gd` (new) | A pilot that goes wrong where it is told, and turns back along the path where it is told, and 29 tests (§5.7) |

Steps:
1. Port the files (§4.1).
2. Run the five checks, N8–N28, N56–N59 and P2a–P2d (§6.2).

Expected counts: 147 scripts load; 69 test scripts, 512 tests, 423,409 asserts. `smoke.sh` prints `main`'s lines.

Acceptance: E2, E3's streak, E5, and E8 for PR 2.

### PR 3: The tutorial in the game **Δ `plan.md`:16, :26; M5 E1; T5–T7, T10, T15, T17, T18**

| Area | Files | What |
|---|---|---|
| Main | `ui/main.gd` | `_tutorial_wanted()` and `--tutorial` (§5.6). The run's origin and turn base, and the switch, `_on_tutorial_completed()` (§5.5). The camera's deferred snap after a rescue (§5.3) |
| State | `autoload/game_state.gd`, `autoload/event_bus.gd` | `in_tutorial`, `start_run(seed, tutorial)` and `end_tutorial()`. The signals `streak_changed` and `tutorial_completed` |
| Save | `autoload/save_data.gd`, `autoload/save_service.gd` | Version 2, with `tutorial`, and its migration. `complete_tutorial()`, which writes at once (§5.6) |
| HUD and sound | `ui/hud.gd`, `autoload/audio_director.gd` | The streak and the goal, the hidden distance, and the banner. The chime on each turn of the streak (§5.4) |
| Docs | `plan.md`, `AGENTS.md` | `plan.md` §2.7, the tutorial, and the lines that it changes. `AGENTS.md` §3: a test that presses Play marks the tutorial done (§5.8) |
| Tests | `tests/integration/test_tutorial.gd` (new); `test_area_start.gd`, `test_title.gd`; `tests/unit/test_audio_director.gd`, `test_game_state.gd`, `test_hud.gd`, `test_save_data.gd`, `test_save_service.gd`, `test_smoke.gd` | 12 tests, and the texts in the glyph test. ZS's tests mark the tutorial done, in a save in memory (§5.7) |

Steps:
1. Port the rest (§4.1).
2. Run the five checks, N29–N55 and N61–N66 (§6.2).
3. Check the Web build in Chrome and Firefox (§6.4), and post the results on the PR.
4. Ask the owner to check the debug APK on the Fold4 (§7).

Expected counts: 148 scripts load; 70 test scripts, 524 tests, 423,533 asserts. `smoke.sh` prints `main`'s lines.

Acceptance: E1, E3, E4, E6, E9, E10, and E8 for PR 3.

### 4.5 Landing

- **Order.** The plan PR first, then PRs 1, 2 and 3, each squash-merged by the owner once its base is `main` (`AGENTS.md` §5). A review fix goes on the branch of the PR that adds the file, and is merged up.
- **HB (#62).** HB's PR changes `car/car_sim.gd`, `ui/hud.gd`, `ui/main.gd`, `autoload/event_bus.gd`, `tests/unit/test_hud.gd` and `plan.md`, as TUT's PRs 2 and 3 do. Git merges all but one function without a conflict: `git merge-tree` of the prototype with `hb/prototype` (578a030) lists one conflict, in `_drive_off_road()`. Both add a line after `health_changed.emit(health)`. Whichever lands second keeps both, HB's first:

  ```gdscript
  	health = maxf(0.0, health - rates.offroad_damage_per_sec * seconds)
  	health_changed.emit(health)
  	offroad_room_changed.emit(offroad_room(rates))
  	if trigger.tutorial:
  ```

  Then HB's meter works in the tutorial as in the City (Q13), and `test_car_sim_tutorial.gd` and HB's tests pass. The prototype could avoid the conflict by putting the tutorial's branch above the emit, but that would skip the health bar and HB's meter in the tutorial without a word. TUT leaves `hud.gd`'s header to HB, which rewrites it (its B5).
- **DN (#64).** DN changes `config/tuning.gd` in its PR 1 and `ui/main.gd` in its PR 3, Daylight, as TUT's PRs do. `git merge-tree` of the prototype with `dn/prototype` (9198181) merges `tuning.gd`, and lists two conflicts, both in `ui/main.gd` (T19). Whichever lands second keeps both sides. In `_physics_process()`, the clock runs in the tutorial too, and only the distance waits for the switch:

  ```gdscript
  func _physics_process(delta: float) -> void:
  	if GameState.state == GameState.State.RUNNING:
  		if not GameState.in_tutorial:
  			GameState.distance = maxf(GameState.distance, _sim.progress - _origin)
  		# The zone's clock runs with the run, ... (DN's comment)
  		_daylight.cycle.advance(delta)
  ```

  In `_on_area_changed()`, TUT's two lines, `start` and `enter_area()`, then DN's `_daylight.cycle.enter(area.day_seconds)`. The switch doesn't call `_on_area_changed()`, which would enter the City in GameState a second time (§5.5), so Q18's default adds one line to `_on_tutorial_completed()`, after `GameState.end_tutorial()`: `_daylight.cycle.enter(_sim.area.day_seconds)`. With it, `test_tutorial.gd`'s `test_the_city_day_starts_at_the_switch` checks that the clock ran in the tutorial, at 10:35 at the switch in seed 1, then stood at 07:00 and ran on. On that merge, `gdlint` and `gdformat` pass, 155 scripts load, and `run_tests.sh` passes 74 scripts, 551 tests and 424,824 asserts. Without the line the test fails, and so it does with the clock run only outside the tutorial. DN's tests open the main scene with `--play`, so they get no tutorial.
- **ZS.** ZS's tests press Play with the save that the test run has. PR 3 makes them mark the tutorial done first, in a save in memory, so that they test what they did (T7).

### 4.6 Review fixes

Fixes found by the internal review of this plan (`AGENTS.md` §7) and by the PRs' reviews, each with its tests and its negative case.

| PR | Change | Tests | Negative case |
|---|---|---|---|
| 1 | The internal review (§4.7), F1: the buffer frees a loop in two parts, each with the junction that lays it, so a loop can be cut while a car can still reach its far end. 989b387 checks that a car that only drives forward never finds one cut: a group's last junction may be no more than `BUFFER_BEHIND` path tiles past its first (§5.2). A car that drives back 9 tiles or more can still find one cut, and is put back on the path (P6); Q17 leaves that to the owner | `test_road_generator_tutorial.gd`: `test_wrong_exits_loop_round_to_the_junction_two_on`, `test_the_tutorial_ends_with_its_group_and_the_seed_road_follows` | N60 |
| 2 | F2: the prototype held a lost car to the junction speed until a junction found it, on the loops' straights and on the path too: a penalty beyond the counter's reset. 034e721 brakes it only for the turns ahead, as for a junction: the first tile within the brake distance that it can't drive straight through, to which F6 adds each junction. Its straight starts again as it brakes, and off the road once it is lost (§5.3, Q9) | `test_car_sim_tutorial.gd`: `test_a_lost_car_brakes_for_a_junction_that_it_enters_from_its_foot`, `test_a_lost_car_brakes_for_the_corners_of_a_loop_and_a_junction_entered_by_an_arm`, `test_a_lost_car_speeds_up_along_a_loop_and_slows_for_its_corners`, `test_the_straight_starts_again_as_the_car_brakes_for_a_junction`, `test_a_lost_car_off_the_road_heads_for_junction_speed`, in place of `test_the_car_slows_while_lost` | N24, N25, N56, N57, N59 |
| 3 | F3: no test played a game over and a retry after the tutorial, and none checked that the music plays on at the switch. 989b387 ends a run in the City after the tutorial with a disaster, and checks the distance, the best run and the atlas, counted from the switch; then it retries, and checks that the run has no tutorial and counts from 0. The switch's test checks that the music's and the ambience's tracks and weights don't change (§5.4, §5.5) | `test_tutorial.gd`: `test_the_city_run_after_the_tutorial_ends_and_retries_without_it`, `test_the_streak_ends_the_tutorial_and_the_city_run_counts_from_there` | N62–N65 |
| 3 | F4: the migration took a version 1 save whose atlas had any entry for one with a run, so an atlas of the wrong shape, or one with no area discovered, skipped the tutorial. 267d65f counts only an area whose `discovered` is `true` (§5.6) | `test_save_data.gd`: `test_a_v1_file_has_done_the_tutorial_if_it_has_a_run` | N61 |
| Plan | F5: §1, Q2 and §5.5 said that up to 3 junctions close the group after the switch, and that the seed's road comes as much sooner. In P1, 12 of the tutorial's junctions follow the switch: the 9 laid, and the 3 that close the group (§5.1). The plan says so, and that on the seed's road Rural comes as many junctions sooner (Q15) | — | None: wording |
| 2 | The follow-up review (§4.7), F6: a lost car braked only for a tile that it couldn't drive straight through. So it came into a T by an arm without braking, from a loop or driving back along the path, and as the player only steers (`plan.md`:27), it couldn't turn down the T's foot on the road: the review's probe, at speed 4, left the road. And the test of the speeds at the corners sampled them only where `distance_to_turn()` saw a turn, so it couldn't see one missed. 3cc0b5e brakes a lost car for each junction ahead too, whichever exit it will take, as a car on the path brakes for each junction. The tests find the corners and junctions from the tiles' exits, and `RoutePilot`'s new `back_at` turns down a T's foot (§5.3, Q9) | `test_car_sim_tutorial.gd`: `test_a_lost_car_brakes_for_the_corners_of_a_loop_and_a_junction_entered_by_an_arm`, `test_a_lost_car_speeds_up_along_a_loop_and_slows_for_its_corners`, `test_a_lost_car_can_turn_down_the_foot_of_a_junction_that_it_enters_by_an_arm` | N58 |
| 3 | F7: the switch's test compared the cross-fades' tracks, decks and weights, but not the players. A `fade_to()` that gave the deck of a track that a deck still has passed it, while `AudioDirector` then set that deck's player to silence and started it again. 44bb3de compares each player's track, gain and play state too, and checks that the City's music and ambience are at full gain before the switch (§5.4) | `test_tutorial.gd`: `test_the_streak_ends_the_tutorial_and_the_city_run_counts_from_there` | N66 |
| Plan | Copilot's review of 487d345: §6.2's N58 described F6's fix, not the case, which drops `tile.is_junction()` from `distance_to_turn()`'s test, so that a lost car brakes only for a tile that it can't drive straight through. The row says so, and N1's and N26's say what their cases change: a loop's one leg, and any change of the streak | — | None: wording |

### 4.7 Internal review

Before the plan's PR, a model of another family, gpt-6.1-sol, reviewed this plan and `tut/prototype` at a04151a (`AGENTS.md` §7). It found 5: F1, which it took to block, that the buffer frees a loop in two parts, so that a car can reach a loop whose far end is gone; F2, a choice for the owner, that a lost car was held to the junction speed, a penalty beyond the counter's reset; F3, that no test played a game over and a retry after the tutorial, and that nothing checked the claim that the music plays on at the switch; F4, that the migration took any atlas for a run; and F5, a claim about the road past the switch that went further than P1. It found the rest sound. Each finding was checked before it was fixed: F1 in `road/road_buffer.gd` and with P6, which showed that a car that only drives forward never meets a cut loop while a group's last junction is within `BUFFER_BEHIND` of its first, which a test now checks (N60), and that one that drives back 9 tiles or more can, and is put back on the path (Q17); F2 by Q9's new default; F3 and F4 with tests (N61–N65); and F5 with P1. §4.6 gives the fixes.

After F1–F5 were fixed, the same model reviewed the fixes, a04151a to 989b387, the one review after fixes that `AGENTS.md` §7 allows. It found nothing that blocks, and 2 more: F6, that a lost car didn't brake for a T that it came into by an arm, and that the test of the corners' speeds sampled them only where `distance_to_turn()` saw a turn; and F7, that the switch's test passed a `fade_to()` that gave back the deck that already had the track, while `AudioDirector` then silenced that deck's player and started it again. It noted that `test_cross_fade.gd` catches that change too. It confirmed that it found no way for a car that only drives forward to meet a cut loop, that F3's test catches a run whose progress counts the tutorial's road, and F4's fix. F6 was checked with the review's probe, which left the road at speed 4, and F7 with that change to `fade_to()`. Both are fixed, and N58 and N66 fail on 44bb3de (§6.2). F6's fix brakes for every junction, the straight ones too, as a car on the path does (§5.3).

---

## 5. Design

### 5.1 The road

**The generator.** `RoadGenerator.new(run_seed, schedule, tutorial := false)` takes a third argument. While its `tutorial` holds, `_junction()` returns `_tutorial_junction()`. A run without the tutorial never reaches the new code, so its road is `main`'s (P4).

**A group of four.** The tutorial's junctions are T's, with the pattern's turn and the opposite, wrong, exit. With `part = turn_count % 4`, they come in groups A to D: A and C turn left, B and D right, as the pattern's turns 0 to 3 do, so each group starts heading north. Each straight after a junction comes from `_rng_tutorial`, between the area's `min_straight` and `max_straight`: the City's 2 to 5 tiles. Each wrong exit is a loop, with a first leg of L = `min_straight` + 1 = 3 cells and a corner (§1's picture):

| Junction | Knows | Lays |
|---|---|---|
| A (part 0) | its straight, s1 | The leg of A's loop: L cells east, the last a corner to the north |
| B (part 1) | s2, so C's cell | The rest of A's loop: north up the column L east of A, to C's row, then west to the cell east of C. Then the leg of B's loop: L cells south, the last a corner to the west |
| C (part 2) | s3, so D's cell | The rest of B's loop: west along the row L south of B, to D's column, then north to the cell south of D |
| D (part 3) | — | Nothing: its wrong exit is the end of B's loop |

A car that goes wrong at A or B drives round to C or D, comes in by their wrong exit, and can drive on out of their correct exit. One that goes wrong at C or D drives the loop the other way, to A or B (§5.2). Why this shape:
- **It fits.** The path is a staircase to the north-west. A's loop and the path from A to C enclose a rectangle east of the path's leg from B to C, and B's loop and the path from B to D enclose one west of it, so the two loops never cross each other or the path. The next group's loops start at least a straight further north. The loops have 11 to 17 tiles (P3).
- **It keeps the road's rules** (T12). A loop's leg is a straight of the area's shortest length before its corner, and each loop runs at least L cells from the path, so it turns no sooner after a junction or a corner than the path does, and touches no road but its two ends. Its tiles lie at most 5 rows before and 8 past the junction that frees them, which `BUFFER_BEHIND` and the props allow for, as they do for dead ends of 9 tiles (P3).
- **Every exit leads on** (Q1). A crossroads' third exit would lead into the space that the path and a loop enclose, where it could only end.

**The tiles** (T13). A loop's tiles are `DEAD_END` tiles with two exits, its cells before and after: the renderer draws a tile by its exits, so they look like any road of the City. Each takes the area of the junction that lays it, its owner, which claims it in the occupancy grid and holds it in `branches`, so the buffer sends it to the renderer and frees it with the owner. Its `junction_index` and `branch_exit` are those of the nearer of the loop's two ends, the start if they are as near: the junction and exit where a car that rejoins the road on it went wrong. `RoadTile`'s comments say so.

**The end** (T3). `end_tutorial(turn_base)` sets `_ending`. The tutorial goes on to the end of its group: `_junction()` turns it off once `turn_count % 4 == 0`, so that each loop's last part, which the next junction lays, is there. The road that the buffer has laid ahead is never laid again: at the switch it is the tutorial's, up to 55 tiles ahead (`BUFFER_AHEAD`), and the generator then closes its group. So `4 * ceil(turn_count / 4) - turn_base` of the tutorial's junctions follow the switch, where `turn_count` is the junctions laid by then and `turn_base` the turns before the switch's next junction (§5.5): 12 in P1, where they were 21 and 12, the 9 laid ahead and the 3 that close the group.

**The seed's road after it** (T8). Each group turns left, right, left, right, so the tutorial ends heading north, with a turn count that is a multiple of 4, as the seed's road starts. The tutorial draws its straights from `_rng_tutorial`, seeded with `hash("%d:tutorial" % run_seed)`, and nothing from `_rng_road`. So the next junction is the seed's first, and the road from there is the seed's, until the schedule's next entry: `test_the_tutorial_ends_with_its_group_and_the_seed_road_follows` checks it tile by tile over 100 seeds and streak ends. The seed's road is in another place, but the tutorial's loops lie behind and beside it, so its dead ends find the same free cells.

**The schedule** (T4). `_due_entry()` counts an entry's turn from `_turn_base`, which `end_tutorial()` sets to the turns before the City's first junction, and asks whether the entry's turn has come rather than whether it is now:

```gdscript
	if entry.turn > turn_count - _turn_base:
		return null
```

The tutorial's junctions don't call `_due_entry()`, so an entry that falls due on the road that the tutorial laid past the switch comes at the City's first junction after it (N5). Without the tutorial, `_turn_base` is 0, and the first junction at which `turn_count` reaches an entry's turn is the one where it equals it, so `>` changes nothing (P4).

### 5.2 The trigger

`JunctionTrigger` takes `tutorial` from the generator, and adds `streak`, the signals `streak_changed(streak)` and `tutorial_completed(junction)`, and `on_rescued(tile)`. While `tutorial` holds, a mistake calls `_lose()`: `streak` goes to 0, with `streak_changed` if it wasn't 0, and `next_junction` to null. The car is then *lost*, until it drives on along the path, from one path tile on the road to the next: the trigger then looks for the first junction after the tile it left. The car can't skip a junction while lost: the path finds it before the next junction, or at the junction's own correct exit, and a car that drives on the road can't leave the path but at a junction. How each event plays out:

| Event | In the tutorial | Past it |
|---|---|---|
| Leaves the next junction by its correct exit | The streak grows, and the next junction is the one after. At `TUTORIAL_STREAK`, `tutorial` is false, and `tutorial_completed(junction)` fires (§5.5) | `main`'s: a turn, or nothing at a decoy |
| Leaves it by a wrong exit | `_lose()` | `main`'s: `_fail()`, a disaster |
| Drives from a path tile to the one before (a U-turn), or out of the next junction by its entry (Q8) | `_lose()` | `main`'s: nothing |
| Enters a path tile from a loop | `_lose()`: the car is lost already, since it reached the loop by a wrong exit or a rejoin | A missed turn, `_fail(-1)`, if the tile is at or past the next junction (T11, Q14). Else nothing: the car went back on the road behind |
| Drives from path tile k to k+1 while lost | Found: the next junction is the first after k | — |
| Rejoins the road on a loop | `_lose()` | `main`'s |
| Rejoins the road on the path | `main`'s: past the next junction, it takes that junction's correct exit. While lost, nothing | `main`'s |
| Reaches the off-road limit | `_lose()`, wherever the car left the road (Q4) | `main`'s: a missed turn near a junction, a crash on a straight |
| Is rescued on path tile t (§5.3) | `_lose()`, then the next junction is the first after t: the car isn't lost | — |

Which loop a lost car drives depends on where it went wrong. Wrong at A, it comes into C from the east and drives on west, out of C's correct exit: the streak starts again at D. Wrong at C, it drives A's loop backward, into A from the east, and on west towards B: the streak starts again at B. `test_tutorial_run.gd` drives both, and B and D, with `RoutePilot`, and checks that the car never leaves the road.

**Past the tutorial** (T11). On `main`'s road no branch leads to a path tile past its own junction, so the new rule fires only on the tutorial's road, after the switch. Without it, a car that turned back past the switch and drove a loop forward would come back onto the path past the next junction, which would then never decide, and every junction after it would count for nothing.

**The road behind** (Q17). The buffer frees each path tile, with its branches, once the car has been `BUFFER_BEHIND`, 20, path tiles past it (`road/road_buffer.gd`:31–37, :101–112). A loop goes in two parts: A's leg with A, and the rest of A's loop with B (§5.1). A car that only drives forward gets no further than D, the group's last junction, before it leaves by D's correct exit. From D it can still go wrong and drive B's loop back to B, then on along the path, wrong again at C, and round A's loop back to A. So the buffer must hold A while the car is at D: D may be no more than `BUFFER_BEHIND` past A. The City's straights of 2 to 5 tiles put D 9 to 18 tiles past A, 10 in seed 1's first group, and `test_road_generator_tutorial.gd` checks it over 100 seeds (N60). A car that has driven 9 tiles or more past C or D, and turns round to take its wrong exit, can find the far end of its loop freed. It leaves the road where the loop ends, and is put back on the path before the junction (P6). On `main` too, a car that drives back finds the road ending 20 tiles behind the furthest it has been.

### 5.3 The car

`CarSim` keeps `main`'s model, with these changes while `trigger.tutorial` holds:

- **Damage, no crash** (T2). `_drive_off_road()` takes the area's damage, `offroad_damage_per_sec` (30 a second in the City), down to 0, and sends `health_changed`, as on `main`. Then, in the tutorial, it reports the off-road limit, the area's `offroad_limit_tiles` (2), to the trigger, and returns: no `_crash()`, at 0 health or at the limit. Past the limit it reports it each step, but `_lose()` sends nothing once the streak is 0.
- **The heal** (Q6). `_tutorial_step(delta)`, at the end of `step()`: on the road, the car heals `START_HEALTH / TUTORIAL_HEAL_SECONDS * delta`, 50 a second, up to `START_HEALTH`, and sends `health_changed`. So it heals from 0 to full in 2 s, in 120 steps, or one more, since the sums of 1/60 s can fall short. Off the road, it doesn't heal.
- **The rescue** (Q5, T14). In the same function, off the road: once `offroad_dist` reaches `TUTORIAL_RESCUE_TILES`, 6, `_rescue()` puts the car at the centre of `path_tile`, the last path tile whose cell it entered. If that is a junction, it takes the tile before it, so that the car can take its turn again. The car faces along the path, at rest, `DRIVING`, with `offroad_dist` 0. It sends `offroad_changed(false)`, then `trigger.on_rescued(tile)`, then `rescued`. Its health stays as it was, and heals on the road. `main.gd` connects `rescued` to the camera's `snap_to_target()`, deferred: `CarController` moves its node to the sim's position after the step, so a camera that snapped at once would find the node where the car was.
- **A lost car's turns** (Q9). `is_lost()` is `trigger.tutorial and trigger.next_junction == null`. A lost car has no next junction to brake for, and at its full speed most cars would miss a loop's first corner. So `target_speed()` and `_update_speed()` brake for `distance_to_turn()`, which is `distance_to_junction()` unless the car is lost. While it is, it walks the cells ahead along the grid direction nearest the car's heading, up to `junction_brake_distance`, and gives the distance to the first tile that is a junction, whichever exit the car will take, as a car on the path brakes for each junction; or that has no exit that way, a loop's corner. A straight the car drives through; a cell with no tile ends the walk. So the car brakes to the area's `junction_speed`, 2 tiles a second in the City, before each corner and each junction, and speeds up between them as on any straight. Lost round A's loop and through C for 4.75 s, it reached 4.03 tiles a second, and entered each of the loop's two corners, and C, at 2.00 at most (`test_car_sim_tutorial.gd` prints it). C it enters by an arm: braked for it, the car can also turn down C's foot, back along the path, on the road (F6). `_tutorial_step()` starts the straight again while the car brakes, so that a mistake starts it as a correct turn does, even one that ends no streak; and off the road once the car is lost, so that it drives to the rescue at the junction speed, slowed by `offroad_speed_mult`. Each `streak_changed` starts it again too.
- **The switch** (Q7). On `tutorial_completed`, the car takes `START_HEALTH`, and `dist_total` goes to 0, so that the top speed's growth counts from the switch, as a run's does from its start. The tutorial grows the cap by `TOP_SPEED_GROWTH`, 0.002 tiles a second for each tile: under 0.1 in P1's 45 tiles.

**HB's off-road meter** (#62, Q13). If HB lands, `_drive_off_road()` sends `offroad_room_changed` after `health_changed`, and TUT's branch comes after both (§4.5). The meter then empties at the area's off-road limit in the tutorial too, where it ends the streak.

### 5.4 The HUD and the sounds

- **The banner** (Q10). The HUD shows `Hud.TUTORIAL_BANNER % Tuning.TUTORIAL_STREAK`, "Tutorial" and "12 turns in a row", in place of the area's name while `GameState.in_tutorial` holds. It shows at the run's start, for `AREA_BANNER_SECONDS`, as an area's name does. At the switch, `main.gd` sends `area_changed` for the City, whose banner then says "City".
- **The turns** (Q10). In the tutorial, `_reset()` shows `Hud.STREAK_TEXT % [0, Tuning.TUTORIAL_STREAK]`, "turns 0/12", and hides the distance, which counts for nothing there. `streak_changed` updates it. At `tutorial_completed`, which the trigger sends in the same call as the last `streak_changed` (`road/junction_trigger.gd`:116–120), the distance shows again, and the turns read "turns 0". So "turns 12/12" is never drawn; `test_smoke.gd` checks its glyphs only as the widest text.
- **Health.** The bar works as in the City. It falls to 0 and fills again, which shows the heal.
- **The chime** (T18). `AudioDirector` plays the `junction` effect on `streak_changed` with a streak above 0: a correct turn chimes as it does in the City. A mistake has no sound of its own (Q11). Leaving the road screeches, and damage sounds, as in the City.
- **The music** (T15). At the switch, `area_changed` names the City again. `CrossFade.fade_to()` returns -1 for the track that is playing, so the City's music and ambience play on with no fade. `test_tutorial.gd` checks that both play at full gain before the switch, and that after it the cross-fades' tracks, decks and weights, and each player's track, gain and play state, are as they were (N65, N66).
- **Glyphs** (T17). `test_smoke.gd`'s glyph test checks both texts, at their longest, against Pixel Operator 8.

### 5.5 The switch and the stats

The streak's last correct turn is at junction J. In that step, in this order:
1. The trigger sets `tutorial` to false, and its next junction is the one after J. It sends `tutorial_completed(J)`.
2. `CarSim` takes full health and sets `dist_total` to 0 (§5.3).
3. `main.gd`'s `_on_tutorial_completed(J)`:
   - `_origin` is `J.path_index + 0.5`, the edge where the car leaves J, and `_turn_base` is `J.turn_number + 1`, the turns before the next junction.
   - `_buffer.generator.end_tutorial(_turn_base)` (§5.1).
   - `SaveService.complete_tutorial()`, which writes the save at once (§5.6).
   - `GameState.end_tutorial()` sets `in_tutorial` to false.
   - `EventBus.tutorial_completed` for the HUD (§5.4), then `EventBus.area_changed` with the City for the banner and the audio.

How the run counts from there (T5):
- **Distance.** `_physics_process()` and `_end_run()` set `GameState.distance` to `_sim.progress - _origin`, and not at all in the tutorial. So the run's distance, the best run and the City's atlas entry count from J.
- **Turns.** The trigger's `turn_index` counts only past the tutorial, from 0.
- **Areas.** GameState's entry for the City, made at the run's start at distance 0 and turn 0, stands: the tutorial counted none. `_on_area_changed()` subtracts `_origin` from an area's start distance and `_turn_base` from its turns.
- **The schedule** (Q15). It counts from `_turn_base` (§5.1): Rural comes at the 34th turn after the switch, as it does in a run without the tutorial. Those turns include the tutorial's road past the switch, so the seed's road, which begins 12 junctions after the switch in P1 (§5.1), comes to Rural 12 junctions sooner than in that run: at its own 22nd turn, not its 34th.

The road ahead is the tutorial's, under the City's rules: a wrong exit is a disaster, a U-turn is nothing, and a loop back past the next junction is a missed turn (§5.2). A run that ends there has a game over as any other.

### 5.6 Who gets it, and the save

**Who** (Q3, T7). `main.gd`'s `_tutorial_wanted()`, at each run's start:
1. No, if the run starts in an area that isn't the whole schedule's first, the City: `--area` or the title's Start button chose another.
2. Yes, with `--tutorial`: every run that starts in the City has it.
3. No, with `--autopilot` or `--play`, which tests and `smoke.sh` use.
4. Else, yes until the save says it is done. Play, and the retry after a run, ask it.

`GameState.start_run(run_seed, tutorial)` sets `in_tutorial` before it sends `run_started`, whose handlers, such as the HUD's `_reset()`, read it (N44).

**The save** (T6, Q16). `SaveData.VERSION` is 2, with `tutorial`, `{"done": false}`, which `to_json()` writes and `_read()` reads: a value of the wrong type falls back to the default, with a note in `problems`. The migration `_v1_to_v2()` marks the tutorial done if the version 1 save has a run: a best distance above 0, or an area whose `discovered` is `true` in the atlas, as every run's first area is. A value of the wrong type, or an area that isn't discovered, counts as no run. A version 1 save with no run, such as one with only changed settings, gets the tutorial. `SaveService.complete_tutorial()` marks it done and writes the file at once, as the end of a run would, so that a player who closes the app in the City doesn't get the tutorial again. Nothing is saved before that: a player who leaves in the tutorial starts it again from 0. `plan.md` §9's example has the new key.

**Tests.** `test_area_start.gd` and `test_title.gd`, ZS's, press Play. Their `before_each()` now puts the save in memory with `SaveService.use_memory()` and calls `complete_tutorial()`, so that they test what they did. `AGENTS.md` §3 tells contributors to do the same (§5.8).

### 5.7 Tests

44 new tests, in five new files and five that exist; three more files change. `RoutePilot` (`tests/helpers/route_pilot.gd`) steers along the road as the autopilot does, but at the turns in `wrong_at` takes the wrong exit, and follows the road from there, round a loop and back onto the path; at the turns in `back_at`, it turns down the junction's foot, back along the path.

| Test | Checks | Finding |
|---|---|---|
| `test_road_generator_tutorial.gd` (PR 1, 3 tests) | Over 100 seeds of 12 groups: T's only; each wrong exit loops to the junction two on; each loop tile's exits, area, owner, `junction_index` and `branch_exit`; no loop turns sooner than the path, touches another road, or lies outside the rows that the buffer allows; no group's last junction lies more than `BUFFER_BEHIND` tiles past its first (Q17). `end_tutorial()` ends with the group, the schedule counts from the base, and the road after is the seed's, tile by tile. An entry due on the tutorial's road comes at the City's first junction | T1, T3, T4, T8, T12, T13, Q17 |
| `test_junction_trigger_tutorial.gd` (PR 2, 12) | Each row of §5.2's table, in the tutorial and past it: correct turns build the streak and count no turns; the streak's end; a wrong exit, a U-turn, going back out of a junction, the off-road limit and a rejoin off the path end it; only driving on finds the car; a rejoin past the junction counts its turn; the rescue; a loop past the next junction is a missed turn after the tutorial | T1, T9, T11 |
| `test_car_sim_tutorial.gd` (PR 2, 13) | Driving on at 0 health; the limit ends the streak, not the run; the heal's rate and its end, on the road only; the rescue's tile, before a junction; the lost car brakes for a junction that it enters from its foot or by an arm, and for each corner of a loop, entering each at the junction speed at most, found from the tiles' exits, and speeds up between them; it turns down the foot of a junction that it enters by an arm, on the road; off the road it heads for the junction speed; the straight starts again while the car brakes and at a new streak; full health and `dist_total` at the switch | T2, T9, T14, Q9 |
| `test_tutorial_run.gd` (PR 2, 4, sim) | The autopilot through the tutorial, the switch and the schedule's tunnel and bridge, with no rescue (P1). `RoutePilot` going wrong at A, B, C, D, and twice: the streaks, and where each ends, on the road throughout. A car left alone: 0 health, rescued again and again, never past the junction. A wrong exit on the road that the tutorial laid past the switch: a disaster | T1–T4, T9, T11 |
| `test_tutorial.gd` (PR 3, 6, integration) | Play starts the tutorial until it is done; `--play` and `--autopilot` skip it; the switch: the stats, the City's banner, the save, and the music and the ambience playing on at full gain with no fade; a disaster in the City after the tutorial, its game over and its stats, then a retry that has no tutorial and counts from its own start; the rescue with the camera on the car; only a run that starts in the City has it | T5, T6, T7, T14, T15 |
| `test_game_state.gd` (+1) | `in_tutorial` is set before `run_started`, and `end_tutorial()` clears it | T5 |
| `test_hud.gd` (+1) | "turns k/12", the hidden distance and the banner, then the City's | T5, T17 |
| `test_audio_director.gd` (+1) | A chime for each turn of the streak, none for a mistake | T18 |
| `test_save_data.gd` (+2) | A version 1 file with a run has done the tutorial, one without hasn't, nor one whose atlas has an area that isn't discovered or a `discovered` of the wrong type; a value of the wrong type isn't done | T6 |
| `test_save_service.gd` (+1) | `complete_tutorial()` writes the file at once | T6 |
| `test_smoke.gd` (changed) | The banner and "turns 12/12" in the game's font | T17 |
| `test_area_start.gd`, `test_title.gd` (changed) | Mark the tutorial done in a save in memory | T7 |

The trigger's, the car's and the generator's tests of `main` pass unchanged: a run without the tutorial plays as before.

### 5.8 Documents and comments

- **`plan.md`** (PR 3): a new §2.7, the tutorial: who gets it, its road, the streak, the heal and the rescue, the switch, the HUD and the save. §1.1's first pillar and §2.1's first step mention it. §3.5 says that with the tutorial the road also depends on where the streak ends. §7.4 lists the two signals; §9's example has `"tutorial"` and version 2, and says when it is written; §13's table has a row for it.
- **`AGENTS.md`** (PR 3): §3 gets a rule, *The tutorial*: Play starts it until the save says it's done, `--play` and `--autopilot` skip it, and a test that presses Play for a run without it marks it done in a save in memory.
- **Code comments.** Each changed class's header says what the tutorial changes, and cites this plan's section: `road_generator.gd` §5.1, `junction_trigger.gd` §5.2, `car_sim.gd` §5.3, `hud.gd` §5.4, `main.gd` and `game_state.gd` §5.5 and §5.6, `save_data.gd` §5.6, `tuning.gd` §5. The tests cite the sections that they check. No comment cites a T#, which the code can't show.
- **This plan.** Its status line, §4.6 and the counts stay current as the PRs are reviewed (`AGENTS.md` §2).

---

## 6. Verification

### 6.1 Checks and counts

Run from the repository root with Godot 4.7.2 (`AGENTS.md` §4), on `main`, on the prototype, and on the trees of PRs 1 and 2 as §4.1 splits them from the prototype. PR 3's tree is the prototype's: `git diff` between them is empty.

| Check | `main` (528196e) | Prototype (e64d381), PR 3 | PR 1 | PR 2 |
|---|---|---|---|---|
| `lint.sh` | Exit 0 (shellcheck skipped) | Exit 0; in CI, with shellcheck and actionlint (§6.4) | Exit 0 | Exit 0 |
| `import.sh` | Exit 0 | Exit 0 | Exit 0 | Exit 0 |
| `check_scripts.sh` | 142 scripts loaded | 148: 6 new scripts, each with its `.uid` | 143 | 147 |
| `run_tests.sh` | 65 scripts, 480 tests, 422,823 asserts, 84.5 s | 70 scripts, 524 tests, 423,533 asserts, 103.3 s | 66 scripts, 483 tests, 423,226 asserts | 69 scripts, 512 tests, 423,409 asserts |
| `smoke.sh` | `autopilot: the save is in memory`; `autopilot: tile 165, turns 35, area rural` | The same | The same | The same |
| `git status --porcelain` | Empty | Empty | Empty | Empty |

Per script on the prototype: `test_road_generator_tutorial.gd` 3 tests, 403 asserts, 5.7 s; `test_junction_trigger_tutorial.gd` 12 tests, 72 asserts; `test_car_sim_tutorial.gd` 13, 69; `test_tutorial_run.gd` 4, 42, 0.8 s; `test_tutorial.gd` 6, 70, 6.8 s; `test_save_data.gd` 16 (+2), `test_game_state.gd` 17 (+1), `test_hud.gd` 12 (+1), `test_audio_director.gd` 29 (+1) and `test_save_service.gd` 15 (+1). `test_smoke.gd`, `test_area_start.gd` and `test_title.gd` keep `main`'s counts. GUT's time varies by several seconds from run to run, and PRs 1 and 2 ran beside §6.2's runs, on 2 CPUs, so their times aren't given.

### 6.2 Negative cases

Each case changes the prototype for a moment and runs the whole suite, which must fail. A script, not committed, applies each change, runs GUT on all 70 test scripts, records the tests that fail and restores the file. N1–N7 change `road/road_generator.gd`; N8–N16 `road/junction_trigger.gd`, and N16 `config/tuning.gd` too, so that the hard-coded 12 shows; N17–N28 `car/car_sim.gd`; N29–N43 `ui/main.gd`; N44 `autoload/game_state.gd`; N45–N47 `autoload/save_data.gd`; N48 `autoload/save_service.gd`; N49–N54 `ui/hud.gd`; N55 `autoload/audio_director.gd`; N56–N59 `car/car_sim.gd`; N60 `config/tuning.gd`, a `BUFFER_BEHIND` of 9; N61 `autoload/save_data.gd`; N62–N64 `ui/main.gd`; N65 and N66 `audio/cross_fade.gd`. On 44bb3de, each case failed the tests that its row counts, with no leaks. A row names one of them, and the plan's PR lists them all. In N6, N16, N30, N32, N39, N47 and N60, some of the tests that failed also stopped on a script error, 15 in all, as they read a value that the change left null or missing, or in N47 in `SaveData._read()`, which the case breaks. GUT counts those as failures too. e64d381 changes one test, the one that P2d failed (below). Run alone in each of the 70 cases and probes, it failed in the same 4 as on 44bb3de, N10, N17, N25 and N57, and in no other.

The probes P2a–P2d (§6.5) ran the same way, and must fail no test. In the first run, on 7bb28c7, they failed four tests that assumed the default tuning: P2a and P2b `test_tutorial_run.gd`'s `test_a_wrong_turn_starts_the_streak_again_where_its_loop_comes_back`, which named the turns where its streaks end; P2c `test_car_sim_tutorial.gd`'s `test_the_car_heals_on_the_road`, whose car drove off the road at the first junction; P2d its `test_the_car_drives_on_with_no_health` and `test_the_offroad_limit_ends_the_streak`, which drove 4 s, past a rescue at 4 tiles. a04151a reads the tuning in those tests, steers the heal test's car with the autopilot, and drives the others until they are as far off the road as they need. On 44bb3de, P2d failed one more, `test_car_sim_tutorial.gd`'s `test_a_lost_car_off_the_road_heads_for_junction_speed`, which 034e721, F2's fix, added after a04151a: it drove on for 2 s from 2.5 tiles off the road, and so reached a rescue at 4 tiles, which stops the car. e64d381 drives it to half a tile short of the rescue, and on it P2a–P2d failed no test.

| # | Change | Tests that fail |
|---|---|---|
| N1 | A loop's leg is 1 cell, not `min_straight` + 1 | `test_road_generator_tutorial.gd`: `test_wrong_exits_loop_round_to_the_junction_two_on` and 5 more |
| N2 | The tutorial's straights come from the road's stream, `_rng_road` | `test_road_generator_tutorial.gd`: `test_the_tutorial_ends_with_its_group_and_the_seed_road_follows` |
| N3 | `end_tutorial()` ends the tutorial at the next junction, mid-group | `test_road_generator_tutorial.gd`: `test_the_tutorial_ends_with_its_group_and_the_seed_road_follows` and 1 more |
| N4 | The schedule counts the tutorial's turns: `entry.turn > turn_count` | `test_road_generator_tutorial.gd`: `test_the_tutorial_ends_with_its_group_and_the_seed_road_follows` and 2 more |
| N5 | An entry is due only at its exact turn: `!=` for `>` | `test_road_generator_tutorial.gd`: `test_an_entry_due_on_the_tutorials_road_comes_after_its_last_group` |
| N6 | Loop tiles aren't claimed in the occupancy grid | `test_road_generator_tutorial.gd`: `test_wrong_exits_loop_round_to_the_junction_two_on` and 7 more |
| N7 | Loop tiles have no area | `test_road_generator_tutorial.gd`: `test_wrong_exits_loop_round_to_the_junction_two_on` and 1 more |
| N8 | A wrong exit in the tutorial loses the car, but keeps the streak | `test_junction_trigger_tutorial.gd`: `test_a_wrong_exit_ends_the_streak_and_loses_the_car` |
| N9 | A wrong exit in the tutorial ends the run: `_fail(choice)` | `test_junction_trigger_tutorial.gd`: `test_a_wrong_exit_ends_the_streak_and_loses_the_car` and 4 more |
| N10 | The off-road limit costs nothing in the tutorial | `test_junction_trigger_tutorial.gd`: `test_the_offroad_limit_ends_the_streak` and 5 more |
| N11 | A U-turn keeps the streak: only a jump forward counts | `test_junction_trigger_tutorial.gd`: `test_a_u_turn_ends_the_streak` and 2 more |
| N12 | A rejoin off the path keeps the streak | `test_junction_trigger_tutorial.gd`: `test_a_rejoin_off_the_path_ends_the_streak` |
| N13 | Past the tutorial, a loop back at or past the next junction is no missed turn | `test_junction_trigger_tutorial.gd`: `test_after_the_tutorial_a_loop_past_the_next_junction_is_a_missed_turn` |
| N14 | Past the tutorial, any loop back onto the path is a missed turn | The same as N13 |
| N15 | A rescue keeps the streak | `test_junction_trigger_tutorial.gd`: `test_a_rescue_ends_the_streak_and_finds_the_car_on_its_tile` |
| N16 | The goal is 12 in the trigger, and `TUTORIAL_STREAK` 4 | `test_junction_trigger_tutorial.gd`: `test_the_streak_ends_the_tutorial_and_the_city_rules_follow` and 7 more |
| N17 | In the tutorial, `_drive_off_road()` goes on to the City's crash | `test_car_sim_tutorial.gd`: `test_the_car_drives_on_with_no_health` and 5 more |
| N18 | No heal | `test_car_sim_tutorial.gd`: `test_the_car_heals_on_the_road` |
| N19 | The heal takes twice `TUTORIAL_HEAL_SECONDS` | The same as N18 |
| N20 | The car heals off the road too | `test_car_sim_tutorial.gd`: `test_the_car_drives_on_with_no_health` and 2 more |
| N21 | No rescue | `test_car_sim_tutorial.gd`: `test_a_rescue_puts_the_car_back_on_its_path_tile` and 3 more |
| N22 | A rescue onto a junction stays there | `test_car_sim_tutorial.gd`: `test_a_rescue_from_a_junction_puts_the_car_before_it` |
| N23 | The rescue sends no `offroad_changed(false)` | `test_car_sim_tutorial.gd`: `test_a_rescue_puts_the_car_back_on_its_path_tile` |
| N24 | `distance_to_turn()` is `distance_to_junction()` while lost too: INF | `test_car_sim_tutorial.gd`: `test_a_lost_car_brakes_for_a_junction_that_it_enters_from_its_foot` and 4 more |
| N25 | `_tutorial_step()` never sets `dist_on_straight` to 0 | `test_car_sim_tutorial.gd`: `test_the_straight_starts_again_as_the_car_brakes_for_a_junction` and 1 more |
| N26 | A change of the streak keeps the straight | `test_car_sim_tutorial.gd`: `test_the_streak_restarts_the_straight` |
| N27 | No full health at the switch | `test_car_sim_tutorial.gd`: `test_the_end_of_the_tutorial_starts_the_city_run` |
| N28 | `dist_total` goes on at the switch | The same as N27 |
| N29 | The camera snaps to the rescued car at once, not deferred | `test_tutorial.gd`: `test_a_car_left_alone_is_put_back_with_the_camera_on_it` |
| N30 | `--play` gets the tutorial | `test_tutorial.gd`: `test_the_play_and_autopilot_arguments_skip_the_tutorial` and 4 more |
| N31 | `--autopilot` gets the tutorial | `test_tutorial.gd`: `test_the_play_and_autopilot_arguments_skip_the_tutorial` and 1 more |
| N32 | `--tutorial` doesn't force it | `test_tutorial.gd`: `test_the_streak_ends_the_tutorial_and_the_city_run_counts_from_there` and 1 more |
| N33 | A run that starts past the City gets the tutorial | `test_tutorial.gd`: `test_only_a_run_that_starts_in_the_city_has_the_tutorial` |
| N34 | The tutorial's distance counts | `test_tutorial.gd`: `test_the_streak_ends_the_tutorial_and_the_city_run_counts_from_there` and 1 more |
| N35 | The City's distance counts from the run's start, not `_origin` | The same as N34 |
| N36 | The turn base is `J.turn_number`, one short | `test_tutorial.gd`: `test_the_streak_ends_the_tutorial_and_the_city_run_counts_from_there` |
| N37 | An area's start distance counts the tutorial's road | The same as N36 |
| N38 | An area's start turns count the tutorial's | The same as N36 |
| N39 | No `end_tutorial()`: the road stays the tutorial's | The same as N36 |
| N40 | The save never marks the tutorial done | The same as N34 |
| N41 | `GameState` stays in the tutorial | The same as N36 |
| N42 | The HUD isn't told of the switch | The same as N36 |
| N43 | No City banner at the switch | The same as N36 |
| N44 | `start_run()` sets `in_tutorial` after `run_started` | `test_tutorial.gd`: `test_play_starts_the_tutorial_until_the_player_has_finished_it` and 3 more |
| N45 | The migration gives every version 1 save the tutorial | `test_save_data.gd`: `test_a_v0_file_is_migrated_and_keeps_its_values` and 1 more |
| N46 | The migration marks every version 1 save done | `test_save_data.gd`: `test_each_load_starts_from_the_defaults` and 1 more |
| N47 | A saved `tutorial` of the wrong shape is kept | `test_save_data.gd`: `test_a_tutorial_of_the_wrong_type_is_not_done` |
| N48 | `complete_tutorial()` waits for the next write | `test_save_service.gd`: `test_the_end_of_the_tutorial_is_written_at_once` |
| N49 | The turns label shows the streak as a bare number | `test_tutorial.gd`: `test_the_streak_ends_the_tutorial_and_the_city_run_counts_from_there` and 1 more |
| N50 | The distance stays hidden after the switch | The same as N49 |
| N51 | The turns label keeps the streak after the switch | The same as N49 |
| N52 | The distance shows in the tutorial | `test_tutorial.gd`: `test_play_starts_the_tutorial_until_the_player_has_finished_it` and 2 more |
| N53 | The banner shows the area's name in the tutorial | The same as N49 |
| N54 | The banner has an arrow, which the font lacks | `test_hud.gd`: `test_the_tutorial_shows_its_streak_and_goal_until_it_is_done` and 1 more |
| N55 | No chime for a correct turn in the tutorial | `test_audio_director.gd`: `test_each_turn_of_the_tutorials_streak_chimes_and_a_mistake_is_silent` |
| N56 | The straight starts again while the car is lost and not `DRIVING`, a04151a's rule | `test_car_sim_tutorial.gd`: `test_the_straight_starts_again_as_the_car_brakes_for_a_junction` |
| N57 | The straight starts again off the road, lost or not | `test_car_sim_tutorial.gd`: `test_a_lost_car_off_the_road_heads_for_junction_speed` |
| N58 | A lost car brakes only for a tile that it can't drive straight through, and so not for a T that it enters by an arm (F6) | `test_car_sim_tutorial.gd`: `test_a_lost_car_brakes_for_the_corners_of_a_loop_and_a_junction_entered_by_an_arm` and 2 more |
| N59 | A lost car is held to `junction_speed`, a04151a's cap | `test_car_sim_tutorial.gd`: `test_a_lost_car_brakes_for_a_junction_that_it_enters_from_its_foot` and 1 more |
| N60 | `BUFFER_BEHIND` 9: the buffer frees A before the car can loop back to it | `test_road_generator_tutorial.gd`: `test_wrong_exits_loop_round_to_the_junction_two_on` and 6 more |
| N61 | Any area in a version 1 save's atlas counts as a run, a04151a's migration | `test_save_data.gd`: `test_a_v1_file_has_done_the_tutorial_if_it_has_a_run` |
| N62 | `_end_run()` takes the distance from the run's start, not `_origin` | `test_tutorial.gd`: `test_the_city_run_after_the_tutorial_ends_and_retries_without_it` |
| N63 | `_start_run()` keeps the last run's `_origin` | The same as N62 |
| N64 | `_start_run()` keeps the last run's `_turn_base` | The same as N62 |
| N65 | `CrossFade.fade_to()` starts a track again on the other deck, though a deck has it | `test_tutorial.gd`: `test_the_streak_ends_the_tutorial_and_the_city_run_counts_from_there` and 3 more |
| N66 | `CrossFade.fade_to()` gives the deck that still has the track, not -1 (F7) | The same as N65 |

### 6.3 Editor warnings

The editor warns about more than CI does (M2 §6.3). A temporary `override.cfg` in the project root raised the 37 `debug/gdscript/warnings/*` settings at level 1 (warn) to 2 (error), and `check_scripts.sh` ran on `main` and on the prototype, e64d381. Both reported the same 5: `INTEGER_DIVISION` in `world/greybox_atlas.gd`:135, `ui/main.gd` (`main`'s :52, the prototype's :59), `tests/unit/test_greybox_atlas.gd`:15 and `tests/unit/test_iso.gd`:42, and `UNUSED_VARIABLE` (`junctions`) in `tests/unit/test_road_generator_occupancy.gd`:30. None is on a line that TUT changes. With those two left at 1, `main` loaded its 142 scripts and the prototype its 148 with none. The file was then removed.

### 6.4 Verified only in CI or on devices

- **CI.** The five required checks on each PR's head. The dispatch run 43389628804 of e64d381 passed them all: `lint`, with shellcheck and actionlint, in 21 s; `test` in 2 min 49 s, with 148 scripts, 70 test scripts, 524 tests, 423,533 asserts, 104.2 s of GUT and `main`'s smoke lines; `export-web` in 58 s; and `export-android`'s APK in 1 min 25 s and AAB in 2 min 58 s. So did run 43380649191 of 44bb3de, with 82.5 s of GUT, whose Web build the next item ran.
- **The Web** (E1, E9). For PR 3, from a dispatch run with `upload-builds`: serve the Web build with `python3 -m http.server`, and drive Chrome and Firefox with Playwright under Xvfb, as #28 did, each with an empty profile and so an empty save. Play must show the City's road with the banner "Tutorial" and "12 turns in a row", and "turns 0/12" with no distance, in the game's font. Then M4's copy of the build that takes `?arg=` (M4_PLAN.md §4, PR 3 step 3), with `?arg=--tutorial&arg=--autopilot`: the autopilot drives the tutorial, the turns count up to "turns 11/12", and at the 12th, about 18 s in (P1), with no pause, the banner says "City", the distance shows and the turns read "turns 0" (§5.4). The consoles must show nothing but the notes that M4's builds logged on software GL (M4_PLAN.md:730). So far, in Chrome only, with Playwright on software GL, the build of 44bb3de from run 43380649191, which is e64d381's, since the exports leave out `tests/`, at about 8 frames a second beside §6.2's runs, so the times weren't measured:
  - With `?arg=--tutorial&arg=--autopilot&arg=--seed=1`: the banner "Tutorial" and "12 turns in a row", "turns 0/12", no distance and full health; the turns counted up; past the switch, the City's road with "134 m", "turns 2" and full health, with no pause and no game over. The console showed Godot's 5 lines and the 4 `GPU stall due to ReadPixels` notes, and no error.
  - With the save emptied, IndexedDB's `/userfs` and the page's localStorage deleted, and no arguments: Play started the tutorial. Left alone, the car left the road, fell to 0 health and drove on with no game over, was put back on the road, and its health filled again. The console showed Godot's 4 lines and nothing else.
- **The debug APK** (E9). The owner checks PR 3's on the Fold4 (§7): the tutorial's feel, its sounds, both screens, and the save across starts of the app.
- **Feel.** The tests check the loops' geometry, the heal's rate and the rescue, but not whether a loop's corners can be driven by hand at the junction speed, or whether 2 s of healing reads on the health bar. The Fold4 check does.

### 6.5 Measurements

| # | Question | Result |
|---|---|---|
| P1 | How much road lies past the streak's end? | With seed 1, the autopilot finished the tutorial in 17.9 s, at path tile 45. 48 tiles and 9 junctions lay past it, laid before the switch (`test_tutorial_run.gd`, which prints it). It then drove on to turn 230, entering Rural at the 34th turn after the switch, the Meadows at the 100th, the Village at the 200th and the Desert at the 220th, through the tunnel and the bridge, with no rescue. The first 12 junctions after the switch were the tutorial's: the 9 laid before it, and the 3 that closed its group, junctions 21–23 (§5.1). The seed's road began at the 25th junction, so Rural came after 22 of its turns, 12 sooner than in a run without the tutorial (Q15) |
| P2a–P2d | Does the tutorial pass with other tunings? | Yes. With `TUTORIAL_STREAK` 4 (P2a) or 13 (P2b), `TUTORIAL_HEAL_SECONDS` 3.5 (P2c), or `TUTORIAL_RESCUE_TILES` 4 (P2d), every test passed on e64d381 (§6.2). The tests of the mistakes need a streak of 4 or more: no streak before their mistakes reaches 4 |
| P3 | How long are the loops, and how far do they reach? | Over seeds 1–100, with 48 of the tutorial's turns each: every loop has 11–17 tiles; its tiles lie at most 5 rows before and 8 past the junction that lays them, within `main`'s dead ends' 9; one junction holds at most 17 branch tiles, under a crossroads' two dead ends of 9 |
| P4 | Does a run without the tutorial get `main`'s road? | Yes. A throwaway script laid 800 tiles of seeds 1–40 of the whole schedule and of seeds 1–10 starting in each of the 5 areas, 72,000 tiles, and digested each tile's fields, its branches' and the generator's counts: `PATH 8aa552761657cde2c0bcfbf51ae6d53e`, `ROAD 09d2214bfe17f1ad0366124e0000857d`, the same on `main` and the prototype |
| P5 | How long does a car that leaves the road drive at 0 health? | With the City's tuning, a car that drove east off path tile 1 reached the off-road limit, 2 tiles, at 1.77 s, which ended the streak; 0 health at 3.60 s, 3.89 tiles off; and the rescue at 5.72 s, 6 tiles off. So it drives about 2.1 tiles at 0 health. A `TUTORIAL_RESCUE_TILES` under about 3.9 would put a car with full health back before it reached 0 |
| P6 | What does a car find that drives back past the road that the buffer keeps? | A throwaway script, with seeds 1–5 and the first two groups of each, but seed 2's second, which the streak ended first: 9 cases, whose D lay 10 to 16 tiles past A. The car drove on to 21 tiles past B, 9 to 15 past D, so the buffer freed B with its loop's leg, 3 of the loop's 11 to 17 tiles. Put back 2 tiles before D at the junction speed, it took D's wrong exit and drove B's loop back. It left the road where the loop was cut at 3.82–5.35 s, reached 0 health at 7.17–8.70 s, and was put back on the path, on the tile before D, at 9.22–10.23 s. No run ended, and no error was logged (Q17) |


---

## 7. Owner actions

1. **Answer Q1–Q18** in the plan PR, or let the defaults stand (§3). Q1, Q2, Q3 and Q12 shape the most code.
2. **Merge the plan PR**, then PRs 1, 2 and 3, in order, each once its base is `main` and its checks pass (§4.5).
3. **Check PR 3 on the Fold4** (E9). The agent posts PR 3's dispatch run; then:

   ```bash
   gh workflow run ci.yml -R pompomon/roadgame --ref tut/3-game -f upload-builds=true
   gh run list -R pompomon/roadgame --workflow ci.yml --branch tut/3-game -L 1   # the run's id
   gh run download <run-id> -R pompomon/roadgame -n "android-Android APK" -D /tmp/roadgame-apk
   adb install -r /tmp/roadgame-apk/roadgame-debug.apk     # keeps the save
   ```

   - [ ] With the save from earlier builds, which has runs: Play starts in the City with no tutorial (the migration, §5.6).
   - [ ] Then empty the save, `adb shell pm clear com.pompomon.roadgame`, and start the app again. Play: the banner says "Tutorial" and "12 turns in a row". The road, the props, the music and the ambience are the City's; every junction is a T; the HUD shows "turns 0/12" and no distance.
   - [ ] Correct turns chime and count up. A wrong turn sets the counter to 0 with no other effect; its road leads round, back onto the road, and the car drives on. Driving back the way it came does the same.
   - [ ] Off the road the health falls, to 0, and the car drives on. Back on the road it is full within 2 s. Driven 6 tiles off the road, the car is put back before the junction, with the camera on it.
   - [ ] At the 12th correct turn in a row, after "turns 11/12": the banner says "City", the distance shows, the turns read "turns 0", the health is full, and the car and the music go on with no stop. A wrong turn after that ends the run with the Phantom Bus.
   - [ ] Retry, and a new start of the app: Play starts in the City with no tutorial. The Atlas and the best run count from the switch.
   - [ ] On the cover screen and the inner one, and with the back button: back pauses the tutorial, and going on resumes it.
4. **Optional: empty the save** after the checks, as above.

---

## 8. Risks

| Risk | Effect | Mitigation |
|---|---|---|
| A player never finds the pattern | They stay in the tutorial, with no way out but closing the app (T10) | The streak counter, the chime and the reset teach it; the autopilot finishes in 18 s (P1). Q12 offers a way out, and §9 says where it would go |
| A player goes wrong on the tutorial's road past the switch | A disaster on a road whose loops forgave the same turn a moment before | The banner says "City", and the turns label changes; this is the City's rule. Q2's alternative would keep the tutorial's rules there |
| A loop meets another road in a seed not tested | Two roads join, or overlap where the renderer draws one | The geometry (§5.1); the test's 100 seeds of 48 turns and P3; `OccupancyGrid.claim()` reports a taken cell with `push_error()`, which fails any test and CI run that meets it |
| The City's `min_straight` or `max_straight` changes | The loops' legs and lengths change with it, and a group can grow longer than the buffer keeps | The generator reads the area; the test checks the rows that the buffer allows, and that each group's last junction is within `BUFFER_BEHIND` of its first (N60). Run P3 and P6 again, and the test, after such a change |
| A car drives back past the road that the buffer keeps | It can find the far end of a loop gone, leave the road there, and drive at 0 health until it is put back on the path (Q17) | As on `main`, where the road ends 20 tiles behind the furthest the car has been. In P6 it was back on the path within 10.3 s, and no run ended. Q17's alternative keeps each group whole until all of it is behind |
| HB (#62) or DN (#64) lands first, or after | One conflict in `_drive_off_road()` with HB, and two in `ui/main.gd` with DN | §4.5 gives the resolutions, and the tests that check them |
| `main` moves before a PR | The diff doesn't apply, or the counts change | §4.1: `--3way`, then §6.1's checks again |
| A tester goes back to a build from before TUT | It reads the version 2 save as far as it knows it, and never writes it, so its runs aren't saved (M5 L9) | Install the newer build again, or empty the save |
| The same seed plays differently | With the tutorial, the road depends on where the streak ends (T8) | The City's road is the seed's from its first junction, and a run without the tutorial is `main`'s (E7). The seeds that tests and the autopilot use have no tutorial |

---

## 9. Notes for later work

- **A way out** (Q12, T10). If the owner wants one: the pause screen (`ui/hud.gd`:10) could offer "Skip" in the tutorial, which would end it at the next junction as the streak does (§5.5); or "Title" in every run, through `GameState`'s RUNNING→TITLE and PAUSED→TITLE, which nothing uses yet.
- **A hint** (Q11). After some mistakes, the HUD could say "left" or "right" in text: the font has no arrows (`AGENTS.md` §3).
- **M7.** The device checks (IP M7.5) gain the tutorial, on both screens and through a fold. If M7's haptics mark a correct turn, they should mark the streak's too: `EventBus.streak_changed` with a streak above 0, as the chime does (§5.4).
- **Other areas.** `_tutorial_wanted()` gives the tutorial only to a run that starts in the City. The generator lays it in the run's first area, so a tutorial in another area's look would need only that rule to change, and that area's straights to fit the loops (§5.1).
- **The save.** A later version keeps `_v1_to_v2()` in the chain of migrations, after `_v0_to_v1()`.
- **Tuning.** `TUTORIAL_STREAK`, `TUTORIAL_HEAL_SECONDS` and `TUTORIAL_RESCUE_TILES` are in `config/tuning.gd`. The game and the tests read them, and the tests pass with a streak of 4 or 13, a heal of 3.5 s and a rescue at 4 tiles (P2a–P2d). The tests of the mistakes need a streak of 4 or more. A rescue under about 3.9 tiles would put a car with full health back before it showed 0 health (P5).
