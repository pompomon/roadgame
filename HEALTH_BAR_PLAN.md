# Health Bar: Show the Off-Road Limit — Detailed Plan

Status: plan, in review. The prototype is built on `hb/prototype` and verified locally and in CI (§6), and on the Web in Chrome; Firefox and the Fold4 are left (§6.4, §7) · 2026-11-13 · The owner hasn't answered Q1–Q7 yet, so the plan and the prototype go on with the defaults (§3) · Scope: the HUD shows both of the limits that can end a run off the road, so that no run ends with the HUD showing room left. This plan calls the work HB. It comes after RG (#54–#57) and before M7.

The owner asked: "Review the codebase, analyse attached screenshot and create a detailed implementation plan for fixing the health bar inconsistency - right now the car crashes with almost 3/4 of health bar full". The screenshot is of the debug APK (version 0.0.0) on Android. The HUD shows 17 m, 0 turns and the red health bar about two-thirds full, over the game-over screen: "You got lost off the road.", Distance 17 m, Turns 0, Area City, seed 3331220946.

**What happens.** Two limits end a run off the road, and the HUD shows only one of them. Off the road, `CarSim` takes health at the area's rate, 30 a second in the City, and counts the distance driven off the road. At the off-road limit, 2 tiles, the run ends whatever the health: as a crash on a straight, "You got lost off the road.", or as a missed turn near a junction (`plan.md` §2.4, `car/car_sim.gd`:290–300). The health bar is right, but nothing on screen shows the limit. So the screenshot shows the limit at work, not a wrong health bar. A replay of its seed that steers left off the City's first straight ends at 17 m with "You got lost off the road." and 64.9–66.2 health left (P1). From full health, no trip off the road ran out of health before the limit, in any area or at any speed (P2, P8), and none can (P9). A crash on a straight left 51.8–92.0 health. A missed turn near a junction, where the car stays slow off the road, left 35.0–82.8. The most that a trip can take is 74.3 health, and a step's 0.6 more: in the Desert, from rest by a junction, where the car is slowest off the road (P9). So health runs out first only on a trip that starts with less than that. The fix: a meter under the health bar that shows, while the car is off the road, how much of the limit is left (Q1, §5).

**Verified locally and in CI.** Every file of this plan's PR was first built on branch `hb/prototype`, on top of `main` (1047e17). Its commits: 45fa976 adds the meter; 73e5012 fixes `hud.gd`'s header (B5); 7ddb234 makes two tests ask only what they mean to; d964101 adds a touch test and a layout test that were found to be missing while it was built; 71e2c9e and 4553c1b add the checks that the internal review and its follow-up found missing (§4.6). 4553c1b passed the five checks locally with Godot 4.7.2 and in CI (§6.1), every negative case (§6.2) and the editor's warnings (§6.3). After ZS merged, 4553c1b's difference, applied to `main` at 528196e, passed them all again, locally (§4.5). Probes in Godot replayed the screenshot's seed, measured the health left at the limit in each area and along the road, found the costliest trip that the rules allow, and measured the HUD and how much of a window the meter covers (§6.5). The Web build of 45fa976 was checked in Chrome (§6.4). Not done: Firefox, and the Fold4 (§7). A model of another family, gpt-6.1-sol, reviewed this plan and the prototype, and then the fixes (`AGENTS.md` §7, §4.7).

- Godot 4.7.2-stable, in CI's image and locally
- GUT 9.7.1
- gdtoolkit 4.5.0 on Python 3.12, in CI's `lint` job and locally. shellcheck isn't installed locally, so `lint.sh` skipped it there; HB changes no shell script
- Chrome 157.0.8103.50, driven by Playwright, for the Web check

**Precedence.** For HB, this document replaces IP M2.6's HUD (`IMPLEMENTATION_PLAN.md`:320), M2.7's list of `EventBus` signals (:324) and M2_PLAN.md §5.9's HUD (:575–588), wherever it marks a difference with **Δ** and its finding (B#, §2). PR 1 folds the change into `plan.md` §2.4, §5.3, §7.1 and §13. IP and M2_PLAN.md are left as M2 left them (Q7).

**Reference code.** This plan has no appendices. PR 1 applies the difference between 1047e17, `main` when the prototype was built, and 4553c1b, the head of `hb/prototype`, which never gets a PR of its own (§4.1). It applies to today's `main`, 528196e, cleanly (§4.5).

**Prerequisites.** RG is merged (#54–#57), and so is ZS, a debug-only choice of the start area on the title: its plan (#60) and its PR 1 (#61). `main` is at 528196e, and `hb/plan` has merged it. M7 hasn't started; §9 has notes for it. No repository settings change.

Contents:
1. Goal and exit criteria
2. Review findings
3. Decisions and open questions
4. Work breakdown (1 PR)
5. Design
6. Verification
7. Owner actions
8. Risks
9. Notes for later work

---

## 1. Goal and exit criteria

Goal: no run ends with the HUD showing room left for what ended it. The HUD keeps its health bar, and adds an off-road meter under it, which shows only while the car is off the road: full as the car leaves the road, lower with each step off it, and empty at the limit (Q1, Q2). The rules don't change: not the limit, the damage, the causes, nor how the end looks and sounds (Q3).

| # | Exit criterion | Checked by |
|---|---|---|
| E1 | The meter (B1). While the car is off the road, an 8-px bar shows 2 px under the health bar, as wide as it. It is full as the car leaves the road, and then shows the room left. On the road it is hidden by its alpha, not by `visible`, so the health bar never moves | `test_hud.gd`: `test_off_the_road_a_meter_under_the_health_shows_the_room_left`, `test_the_meter_sits_under_the_health_bar_and_never_moves_it` |
| E2 | The room (B1). `CarSim.offroad_room(rates)` is the share of the off-road limit of the area `rates` that is left: 1 − `offroad_dist` / `offroad_limit_tiles`, clamped to 0..1. `CarSim` emits it as `offroad_room_changed` with each damage, after `health_changed` and before the limit is checked. So it falls with each step to 0 at the limit, whether the limit ends the run as a crash or as a missed turn, and stays above 0 if health runs out first. If both run out in the same step, the health ends the run, as on `main`, and the room is 0. Each part of a step uses the limit of the area whose rates count that part | `test_car_sim_offroad.gd`: `test_off_the_road_the_room_left_falls_with_each_step_to_none_at_the_limit` and `test_the_offroad_limit_near_a_junction_is_a_missed_turn`, with the signals' order; `test_the_room_left_is_a_share_of_the_limit_of_the_area_driving_the_car`; `test_off_the_road_the_time_before_a_new_area_counts_at_the_old_areas_rates`, with each area's limit; the last room in `test_running_out_of_health_is_a_crash` |
| E3 | The screenshot's end (B1, B2). In the main scene, a car driven off the road ends the run with "You got lost off the road." and health left. The HUD shows that health and an empty meter, and keeps them under the game-over screen until the next run, which hides the meter and fills it | `test_crash.gd`: `test_a_car_lost_off_the_road_shows_its_health_left_and_an_empty_meter`; `test_hud.gd`: `test_a_run_that_ends_off_the_road_leaves_the_meter_as_it_was`, `test_each_run_starts_the_hud_afresh` |
| E4 | Touches (B6). A touch on the health bar or on the meter, shown or hidden, steers, as a touch anywhere but on II does. The meter, the health bar and the box that holds them have `mouse_filter = IGNORE` | `test_main_scene_boot.gd`: `test_a_touch_on_the_health_bar_or_the_off_road_meter_steers` |
| E5 | The look (B1). The meter's fill is the palette's yellow, (236, 196, 64), with the health bar's 2-px ink border and its background; the health bar keeps its red. Against the ink background, the yellow has a contrast of 11.10:1, as against 3.50:1 for the red; the yellow against the red, 3.17:1. Every colour is the palette's | `test_hud.gd` (the fill's contrast with the meter's background and with the health bar's red, 3:1 at least, and each of the three styles drawn and opaque); `test_ui_theme.gd`: `test_the_themes_colours_are_the_palettes` |
| E6 | Nothing else changes (Q3): the limit, the damage, the causes, the messages, and how a crash looks and sounds. Every test on `main` passes, 4 of them with checks added, one of those on areas with other limits (§4), and `smoke.sh` prints `main`'s line, `autopilot: tile 165, turns 35, area rural` | §6.1 |
| E7 | Manual, on the Web in Chrome and Firefox and on both of the Fold4's screens. Off the road, the meter reads as a second limit and doesn't crowd the top bar. The health bar never moves. At the screenshot's end, the meter is empty under the health bar. Nothing flashes, and a touch on the bars steers | §6.4, on PR 1's build |
| E8 | `plan.md` §2.4, §5.3, §7.1 and §13 and `hud.gd`'s header say what the code does (B4, B5) | Review |
| E9 | All five required checks are green, with §6.1's counts, and `smoke.sh` prints no error line. Each negative case makes the tests it names fail (§6.2), and the editor reports no new warnings (§6.3) | PR checks; §6.2 and §6.3, run locally with Godot 4.7.2 on the PR's head |

---

## 2. Review findings

M2 built the HUD that IP M2.6 asks for: the distance, the turns, the health bar and II (M2_PLAN.md §5.9). Neither IP nor `plan.md` gives the off-road limit a place in it, and M3–M6 left it as it was. The limit itself came with M2's `CarSim`, and `test_car_sim_offroad.gd` checks it well. What is missing is that the player can see it.

- **High:** the game misleads the player, or breaks.
- **Medium:** fragile, or missing from the tests.
- **Low:** clarity or polish.

Line numbers are 1047e17's, `main` when the prototype was built. Of the lines that this plan cites, ZS has since moved only `ui/main.gd`'s; §4.5, §5.1 and §6.3 give their new numbers. "Prototype" means that the fix runs on `hb/prototype` and passed the checks locally and in CI (§6.1). B6 was found while the prototype was built, after B1–B5 were numbered; the prototype's tests cite it by that number.

### High

| # | Finding | Evidence | Fix |
|---|---|---|---|
| B1 | The HUD shows one of the two limits that end a run off the road. Off the road, the car loses health and uses up the off-road limit at the same time, and either can end the run, but only the health is on screen. From full health the limit always comes first, with at least a quarter of the health left (P9). In the probes, a crash on a straight ended the run with the health bar at least half full, and a missed turn near a junction with it at least a third full, for no reason that the HUD gives. | `car/car_sim.gd`:290–300: `_drive_off_road()` takes the damage, then ends the run with `_crash(HEALTH)` at 0 health, or else at `offroad_limit_tiles` with a missed turn near a junction or `_crash(OFFROAD)`. `ui/hud.tscn`:42–50: the HUD's one bar, `%Health`. `plan.md` §2.4 (:52–54); IP M2.6 (:320). The screenshot. P1: its seed ends at 17 m with 64.9–66.2 health left. P2: from full health, each of 3,550 trips off a straight ends at the limit, with 51.8–92.0 health left. P8: of 3,630 trips from full health at points along the road, none ran out of health; 2,388 crashed at the limit with 51.8–82.8 left, and 1,058 missed a turn at it with 35.0–82.8. P9: the slowest trip that the rules allow costs at most 74.3 health, and a step's 0.6; 100 trips from rest by a junction lost 46.3–74.1 | **Δ IP M2.6, M2.7, M2_PLAN.md §5.9, `plan.md` §2.4:** an off-road meter under the health bar, shown only off the road: full as the car leaves the road, empty at the limit (Q1, Q2). `CarSim` emits the room left with each damage, and `EventBus` relays it to the HUD. Prototype (§5.1–§5.3, E1–E3, E5) |

### Medium

| # | Finding | Evidence | Fix |
|---|---|---|---|
| B2 | No test checks what the HUD shows at the end of a run. The one test that drives the main scene off the road takes either cause and never looks at the HUD, and the HUD's tests check only the health bar's value. | `tests/integration/test_crash.gd`:13–48, with `assert_has([CarSim.OFFROAD, CarSim.HEALTH], GameState.end_cause)` at :21; `tests/unit/test_hud.gd`:48–61 | A test of the screenshot's end, in the main scene: the run ends at the limit with health left, and the HUD shows that health and an empty meter, under the game-over screen too (E3). Prototype |
| B3 | A car lost off the road looks and sounds wrecked, as one whose health ran out. With health left on the bar, the wreck adds to the surprise. | `car/car_controller.gd`:54–59: the wreck frame and the smoke in any `CRASHED` state. `autoload/audio_director.gd`:264–268: the crash sound for `HEALTH` and `OFFROAD`. `plan.md` §2.5 (:57–61) calls both a crash | None by default (Q3). With the meter empty under the game-over screen, the wreck has a cause on screen. Q3's alternative stops a lost car without the wreck |
| B6 | Touches can stop at the HUD's bars. `InputRouter` reads touches in `_unhandled_input()`, so a `Control` that keeps a touch takes it from steering. M2 gave the HUD's root, top bar and health bar `mouse_filter = IGNORE`, but no test checks it. A meter hidden by its alpha (E1) stays under the player's thumb whenever the car is on the road. A `ProgressBar` keeps touches by default, so without `IGNORE` the meter would take every touch on it from steering, unseen. | `car/input_router.gd`:37–47; M2_PLAN.md §5.9 (:577); no file under `tests/` names `mouse_filter`. P6: `ProgressBar` and `Control` default to `STOP`, `VBoxContainer` and `HBoxContainer` to `PASS`, `Label` to `IGNORE`. N13 and N15: with `STOP`, a touch on the bar doesn't steer | `mouse_filter = IGNORE` on the meter and on the box that holds both bars, as on the health bar, and a test that touches each bar in the main scene and checks that it steers (E4). Prototype (§5.4, §4.6) |

### Low

| # | Finding | Evidence | Fix |
|---|---|---|---|
| B4 | `plan.md` gives the limit, but not how the player sees it. §5.3's assets and §7.1's scene tree name the health bar alone, and §13's decision log gives the limit alone. | `plan.md`:52–54, :203, :242 and :391 | **Δ `plan.md` §2.4, §5.3, §7.1, §13:** PR 1 adds the meter to each (§5.6, E8) |
| B5 | `hud.gd`'s header says that the HUD's text uses only characters in "Godot's default font". Since M5, the theme's font is Pixel Operator 8, and `test_smoke.gd` checks the text against it. | `ui/hud.gd`:7–8; `ui/theme.tres`:3; `AGENTS.md` §3. `ui/atlas_screen.gd`:6 and `ui/settings_screen.gd`:7–8 say the same | PR 1 rewrites the header, which it changes anyway: "the game's font" (E8). The other two are left for a docs PR (§9) |

---

## 3. Decisions and open questions

The prototype follows the defaults. The owner hasn't answered the questions yet, so PR 1 goes on with the defaults until the owner says otherwise (`AGENTS.md` §2 step 5). Each alternative changes PR 1 as named.

| # | Question | Default | Alternative |
|---|---|---|---|
| Q1 | How should the HUD show the off-road limit? | **A: an off-road meter** under the health bar, shown only while the car is off the road (§5). The rules stay as they are, and the player sees both limits | **B: no limit on straights,** so that only health ends a trip there. From full health a trip would go 4.7–12.0 tiles (P3), and most straights are shorter: 2–5 tiles in the City and the Village, 3–7 in Rural and Meadows, 3–8 in the Desert (`areas/area_def.gd`:14–15, `areas/*.tres`). A car that cut across to a later leg would have each junction it skipped counted as correct (`road/junction_trigger.gd`:42–51): a shortcut. It changes `plan.md` §2.4's rule. **C: the limit costs health,** 50 a tile, so that 2 tiles take all 100 and health is the only limit. A 2-tile trip took 8.0 health at the least (P2) and can take 74.3 at the most (P9), so C is 1.3–12 times as harsh, and a corner cut, "damage only" in `plan.md` §2.4, could end the run. **D: empty the health bar** when the limit ends the run: right at the end, but no warning before it, and the bar would show health that the car didn't lose. **E: one bar for the lesser of the two:** it would switch scales during a trip, and can't show both |
| Q2 | Where does the meter go? | **Under the health bar,** in the top bar, as wide as the health bar and 8 px high, so that the two limits read together (§5.2) | Over the car, where the player is looking. That needs a node in the world that follows the car and the camera's zoom, and its own layout and touch tests |
| Q3 | Does a car lost off the road still look and sound wrecked? | **Yes,** as `plan.md` §2.5 calls it a crash. The empty meter shows why (B3) | It stops without the wreck frame, the smoke and the crash sound. `CarController` and `AudioDirector` need the cause (`GameState.end_cause`), `audio_director.gd`:267–268 splits, and `test_crash.gd` checks both causes |
| Q4 | Does the meter have a label? | **No.** It shows only off the road, under the health bar and in its own colour, and the game-over screen says "You got lost off the road." | A label such as "off road", in the game's font. The top bar is tight at the game's base size, 360 × 640, its narrowest layout (`project.godot`:26–31: `expand`, with integer scaling): the bars are 124 px wide at 17 m, and lose 14 px with each digit of the distance or of the turns: 54 px at 12,340 m after 100 turns (P7, P7b) |
| Q5 | A sound or a vibration as the meter runs low? | **No.** Off the road, the screech and the rumble play already (`audio_director.gd`:251–254), and M7.2 adds a short vibration on damage ticks, at most one each 250 ms (`IMPLEMENTATION_PLAN.md`:446–447) | A warning sound at a quarter left: a new sound in `tools/audio/make_audio.gd`, a line in `AudioDirector.EFFECTS`, and a test |
| Q6 | How does HB land? | **This plan's PR, then one PR,** `hb/1-offroad-meter`, of 11 files (§4) | The code in this plan's PR: one review instead of two, but the plan's review would wait for the code's |
| Q7 | Which documents change? | **`plan.md` §2.4, §5.3, §7.1 and §13,** in PR 1. IP and M2_PLAN.md stay as M2 left them, and this plan replaces them where it says Δ. `plan.md` §7.4's list of signals (:267–274) stays too: it lacks `car_offroad_changed`, which IP M2.7 adds to it (:324), and so it would lack the room as well (§9) | Fold the change into IP M2.6 and M2.7 too |

---

## 4. Work breakdown

There is one PR after this plan's, and it leaves CI green (E9).

```
plan PR ──▶ PR 1 off-road meter
 (docs)      (B1–B6)
```

### 4.1 Porting from the prototype

PR 1's changes are the difference between `main` and the head of `hb/prototype`:

1. Fetch the branches, create PR 1's branch, and apply the difference:
   ```bash
   git fetch origin main '+refs/heads/hb/*:refs/remotes/origin/hb/*'
   git switch -c hb/1-offroad-meter origin/hb/plan
   git diff 1047e17 4553c1b | git apply --index
   ```
   If `main` has moved on and changed the same lines, use `git apply --3way --index` and keep both.
2. Make the changes of any row of §4.6 for PR 1 that the prototype doesn't have; 4553c1b has all of them so far. Leave `HEALTH_BAR_PLAN.md` alone on PR 1's branch until this plan's PR has merged: until then the plan changes only on `hb/plan`, which is then merged into PR 1's branch (§4.5). A change to it on PR 1's branch would make the merge of `main` after the plan's squash an add/add conflict.
3. Run §6.1's checks, §6.2's negative cases and §6.3's warnings, and compare the counts with the "Expect" line below.
4. Have a model of another family review it (`AGENTS.md` §7). Then commit, push, and open the PR with base `hb/plan`.

### PR 1: UI: an off-road meter under the health bar **Δ B1–B6**

Branch `hb/1-offroad-meter`, from `hb/plan`. `git diff 1047e17 4553c1b | git apply --index`, then the changes of §4.6's rows for PR 1 that 4553c1b doesn't have (§4.1).

| Area | Files |
|---|---|
| Car | `car/car_sim.gd`: `offroad_room_changed`, `offroad_room()`, and the emit in `_drive_off_road()` (§5.1) |
| Autoload | `autoload/event_bus.gd`: `car_offroad_room_changed` **Δ IP M2.7** |
| UI | `ui/main.gd`: the relay; `ui/hud.gd`: the meter's two handlers, `_reset()` and the header (B5); `ui/hud.tscn`: the `Bars` box, with `Health` and the new `Offroad` (§5.2); `ui/theme.tres`: `StyleBoxFlat_offroad` and the `OffroadBar` variation (§5.3) |
| Docs | `plan.md` §2.4, §5.3, §7.1 and §13 (§5.6) |
| Tests | `tests/unit/test_car_sim_offroad.gd`: `_rooms()` and `_hear()`, 2 new tests, the last room in 2 and the signals' order in 2, and each area's limit in the area-crossing test (E2); `tests/unit/test_hud.gd`: `_contrast()`, 3 new, and the meter and the health bar in `test_each_run_starts_the_hud_afresh` (E1, E3, E5); `tests/integration/test_crash.gd`: 1 new (E3); `tests/integration/test_main_scene_boot.gd`: 1 new (E4) |

11 files, +262 −15. No new script, so no `.uid` file. Expect, on `main` at 528196e: `check_scripts: loaded 142 scripts`; `GUT: 487 tests passed`, 7 more than `main`'s, in 65 test scripts (422,982 asserts, 159 more; 86.8 s locally); `autopilot: tile 165, turns 35, area rural`, as on `main`. On 1047e17, 4553c1b had 480 tests and 422,889 asserts (§6.1). Negative cases N1–N25.

**Acceptance:** E1–E6, E8 and E9, and E7 on its build (§6.4).

### 4.5 Landing (Q6)

This plan's PR targets `main`, and PR 1 targets `hb/plan`. Only a PR whose base is `main` merges (`AGENTS.md` §5). The plan changes only on `hb/plan` until its PR merges, and after that on PR 1's branch. A review fix goes on PR 1's branch, or on `hb/plan` for this plan, which is then merged into PR 1's branch with `git merge --no-ff --no-edit`.

Once this plan's PR has merged, retarget PR 1 to `main` before anyone deletes `hb/plan`: deleting a merged PR's branch closes each open PR based on it, unless GitHub has retargeted it first, as the deletion of `m6/plan` closed #46 (ROADGEN_PLAN.md §4.5). Then:

```bash
gh pr edit <PR 1> --base main       # unless GitHub retargeted it
git fetch origin main '+refs/heads/hb/*:refs/remotes/origin/hb/*'
git switch hb/1-offroad-meter
git merge origin/hb/plan            # the plan's final state, in case a fix wasn't merged up yet
git merge origin/main               # the plan's squash
git diff --name-only origin/main    # must list only PR 1's files
git push
```

The squash adds `HEALTH_BAR_PLAN.md` as `hb/plan` has it, and so does PR 1's branch once it has merged `hb/plan`, so the merge of `main` is clean; simulate it first with `git merge-tree`. The push then changes no file in PR 1's diff, so it may start no Copilot review: request one with `gh pr edit <PR 1> --add-reviewer @copilot` if the PR needs it. If the owner links the two PRs as a GitHub stack instead, the stack retargets PR 1 and rebases it by itself (ROADGEN_PLAN.md §4.5). PR 1's own commits change only its 11 files, none of which the plan's squash changes, so they replay cleanly.

**ZS.** ZS, a debug-only choice of the start area on the title (`ZONE_SELECT_PLAN.md`), merged after the prototype was built: its plan as #60, and its PR 1 as #61, 528196e, which `hb/plan` has merged. #61 changes `ui/main.gd`, as PR 1 does, but in other lines: the header, the members, `_ready()` and `_play()`, where PR 1 adds one line to `_start_run()`, at :128 (:121 on 1047e17). So 4553c1b's difference applies to 528196e cleanly, with that hunk 7 lines lower, and 4553c1b and 528196e merge without conflict (`git merge-tree`). Applied there, it passed the five checks, adding the same 7 tests and 159 asserts as on 1047e17 (§6.1), every negative case as §6.2 says, and the editor's warnings (§6.3).

### 4.6 Review fixes

Fixes found while the prototype was built, by the internal review of this plan (`AGENTS.md` §7) and by the PRs' reviews, each with its tests and its negative case.

| PR | Change | Tests | Negative case |
|---|---|---|---|
| 1 | B6, found while the prototype was built. The meter, hidden by its alpha, is always under the player's thumb, and nothing tested M2's `IGNORE` on the HUD. With `STOP`, a `ProgressBar`'s default, a bar takes every touch on it from steering. d964101 touches the middle of each bar in the main scene, with the meter hidden, as it is on the road: the touch must steer, and its release stop | `test_main_scene_boot.gd`: `test_a_touch_on_the_health_bar_or_the_off_road_meter_steers` | N13, N15. N14 fails nothing: the box at its default, `PASS`, lets a touch through (§5.4) |
| 1 | Found while the prototype was built: no test checked where the meter is. The first HUD tests check its value and alpha, so a meter beside the health bar, or one that moved it, passed them. d964101 checks that the meter is under the health bar and as wide, and that showing or hiding it leaves the health bar where it was | `test_hud.gd`: `test_the_meter_sits_under_the_health_bar_and_never_moves_it` | N16; N7 fails it too |
| 1 | 7ddb234: `test_crash.gd`'s new test asked for more than half the health left, a number that the areas' tuning sets, where its point is only that the limit came first. It now asks for any health left. And a message in `test_car_sim_offroad.gd` said "a quarter of the way", which the test doesn't check | The same two tests | None: a looser check, and wording |
| 1 | The internal review (§4.7), F1: nothing checked the meter's scale. With `ProgressBar`'s default `max_value`, 100, the meter would show the room as a hundredth of itself; with its default `step`, 0.01, a room under 0.005 would round to 0. 71e2c9e checks that a room of 0.25 fills a quarter of the meter, and that 0.004 comes through as the car sent it | `test_hud.gd`: `test_off_the_road_a_meter_under_the_health_shows_the_room_left` | N17, N18 |
| 1 | F2: the tests of a run's end and of a retry checked the meter's alpha, but not that it is drawn, so a meter hidden by `visible` at the end of the run passed them. 71e2c9e checks `is_visible_in_tree()` at the end, and `visible` after a retry | `test_hud.gd`: `test_a_run_that_ends_off_the_road_leaves_the_meter_as_it_was`, `test_each_run_starts_the_hud_afresh`; `test_crash.gd`: `test_a_car_lost_off_the_road_shows_its_health_left_and_an_empty_meter` | N19 |
| 1 | F3: nothing checked E2's order, so a room sent after the run had ended passed. 71e2c9e hears the car's signals, and checks that the health and the room come before `crashed` or `disaster_triggered` | `test_car_sim_offroad.gd`: `test_off_the_road_the_room_left_falls_with_each_step_to_none_at_the_limit`, `test_the_offroad_limit_near_a_junction_is_a_missed_turn` | N20 |
| 1 | F4: a room from `area`, not `rates`, passed. The two differ only in a step that crosses into a new area, and every area's limit is 2 tiles. 71e2c9e gives the areas of the area-crossing test limits of 4 and 3 tiles, and checks the room of each part of the step | `test_car_sim_offroad.gd`: `test_off_the_road_the_time_before_a_new_area_counts_at_the_old_areas_rates` | N21 |
| 1 | F5: the colour test asked only that the fill isn't the health bar's red, so an ink fill, unseen on the ink background, passed. 71e2c9e asks for 3:1 against the background and against the red (E5) | `test_hud.gd`: `test_off_the_road_a_meter_under_the_health_shows_the_room_left` | N22 |
| 1 | The follow-up review (§4.7), F9: the tests of a run's end and of a retry checked that the meter is drawn, but not the health bar. So an end of the run that hid the health bar passed them, and left it hidden in the next run too, as `_reset()` doesn't show it. 4553c1b checks that the health bar is drawn, with the health left, at the crash and under the game-over screen, and drawn after a retry | `test_crash.gd`: `test_a_car_lost_off_the_road_shows_its_health_left_and_an_empty_meter`; `test_hud.gd`: `test_each_run_starts_the_hud_afresh` | N23 |
| 1 | F10: the contrast checks compared the styles' colours, so a fill painted transparent, or not painted at all, passed them. 4553c1b checks that the meter's fill, its background and the health bar's fill each draw their centre, opaque (E5) | `test_hud.gd`: `test_off_the_road_a_meter_under_the_health_shows_the_room_left` | N24, N25 |
| Plan | F6: §5.2 said that with `step` 0 the meter is empty only at the limit. But a `ProgressBar` draws its fill in whole pixels, and none under half a pixel, so the meter looks empty a little before the limit. §5.2 now says so, and why `step` 0 still counts | None: wording | None |
| Plan | F7: E2, §5.1 and §5.2 said that the room stays above 0 if the health runs out first. If both run out in the same step, the health's check comes first, as on `main`, and the room is 0. They now say so; the rule doesn't change | None: wording | None |
| Plan | F8: some measurements were applied beyond what they measured. Q1 C used P3's costs, measured on straights only; the widths were measured with 0 turns; the most that a trip takes was the largest of a sample. P9 now bounds a trip's cost, and P7b measures the widths with the turns (B1, Q1, Q4, §5.2, §5.3, §8, §9) | None: wording | None |
| Plan | F11: §5.3 said that the meter covers under 1.25% of any screen, as the view is at least 640 px high. But the game scales the view by whole numbers, and a window smaller than the base size shows it at scale 1, cut off. §5.3 and §8 now say so, with P10's measures | None: wording | None |
| Plan | Copilot's review of 9f7690c, [on §4.1](https://github.com/pompomon/roadgame/pull/62#discussion_r4559391537): step 2, "Add §4.6's rows for PR 1", read as adding rows to this plan on PR 1's branch before the plan lands. §4.5 keeps the plan on `hb/plan` until then, as merging `main` after the plan's squash would otherwise be an add/add conflict; `git merge-tree` shows it. Step 2 and PR 1's section now say to make the rows' changes, and to leave the plan alone on PR 1's branch until it lands | None: wording | None |

### 4.7 Internal review

Before the plan's PR, a model of another family, gpt-6.1-sol, reviewed this plan and `hb/prototype` at d964101 (`AGENTS.md` §7). It found nothing that blocks, and 8 findings: F1–F5, tests that a broken meter passed, and F6–F8, claims that went further than their evidence. Each was checked before it was fixed. Each of F1–F5's six changes passed every test on d964101, and fails on 71e2c9e, as N17–N22 (§6.2). F6 was checked in Godot's source, F7 in `car_sim.gd`, and F8 with P7b and P9. §4.6 gives the fixes.

After F1–F8 were fixed, the same model reviewed the fixes, the one review after fixes that `AGENTS.md` §7 allows. It found 3 more: F9 and F10, two more ways to break the HUD that the tests passed, and F11, a claim about the screen that the game's integer scaling breaks. Each of the three changes, N23–N25, passed every test on 71e2c9e, and fails on 4553c1b (§6.2). F11 was checked in Godot's source and with P10. §4.6 gives the fixes.

---

## 5. Design

### 5.1 The room left (B1, E2)

`CarSim` gets a signal and a function:

```gdscript
## Off the road, with the damage: the share of the off-road limit still to drive, from 1 with none
## driven to 0 at the limit (HEALTH_BAR_PLAN.md B1). The HUD shows it.
signal offroad_room_changed(room: float)

## The share of the off-road limit of `rates` that the car can still drive off the road: 1 with
## none driven, 0 at the limit. validate() keeps the limit above 0.
func offroad_room(rates: AreaDef) -> float:
	return clampf(1.0 - offroad_dist / rates.offroad_limit_tiles, 0.0, 1.0)
```

`_drive_off_road()` emits it right after the health:

```gdscript
func _drive_off_road(seconds: float, rates: AreaDef) -> void:
	offroad_dist += speed * seconds
	health = maxf(0.0, health - rates.offroad_damage_per_sec * seconds)
	health_changed.emit(health)
	offroad_room_changed.emit(offroad_room(rates))
	if health <= 0.0:
		_crash(HEALTH)
	elif offroad_dist >= rates.offroad_limit_tiles:
		...
```

- **Where.** `_drive_off_road()` is the only place that adds to `offroad_dist`, so the room goes out each time it changes, with the damage. It runs at three points of a step: at an area's first tile, for the time before it, at the old area's rates (`car_sim.gd`:102–103); at the end of the step (:109–110); and in `_rejoin_road()`, for the time up to the rejoin (:280). Each sends the room of the area whose rates count that time. Every area's limit is 2 tiles today, so the room never jumps at an area's first tile. `test_the_room_left_is_a_share_of_the_limit_of_the_area_driving_the_car` checks with a limit of 4 tiles that the room uses the area's, and `test_off_the_road_the_time_before_a_new_area_counts_at_the_old_areas_rates`, with limits of 4 and 3 tiles, that each part of a step into a new area uses its own area's.
- **Order.** The health, then the room, then the limit's checks, and the tests hear them in that order. So the HUD has both before `crashed` or `disaster_triggered` ends the run. At the limit the last room is 0, as `offroad_dist` has reached the limit. If the health runs out first, the last room is above 0. If both run out in the same step, the health's check comes first, as on `main`: the run ends as `HEALTH`, with the room at 0.
- **The limit is above 0.** `AreaDef.validate()` reports a limit of 0 or less (`areas/area_def.gd`:96–97), and a schedule that fails it is never read (`road/road_generator.gd`:44–51), so the division is safe. The clamp keeps the room at 0 past the limit, as the step that reaches the limit can drive past it.
- **A signal of its own.** `offroad_changed` says when the car leaves and rejoins the road, and `health_changed` gives the health. On `main`, `AudioDirector` listens to both (`autoload/audio_director.gd`:76–77), and the HUD to `health_changed`. A new signal leaves them and their listeners as they are. The room is a share, not a distance, so the HUD needn't know the area's limit. **Δ IP M2.7:** `EventBus` gets `car_offroad_room_changed(room: float)`, and `ui/main.gd` relays it as it relays the others (:126–127 on 528196e): `_sim.offroad_room_changed.connect(EventBus.car_offroad_room_changed.emit)`.
- **Leaving and rejoining.** `_leave_road()` sends `offroad_changed(true)` before any damage, and `_rejoin_road()` sends the last damage and room, then `offroad_changed(false)`. A car that leaves and rejoins the road within one step sends all of them in one physics frame, so the meter is never drawn.

`CarSim` stays pure (D2) and uses nothing random (IP §5.3).

### 5.2 The HUD (B1, E1, E3) **Δ M2_PLAN.md §5.9**

On `main`, the top bar holds the distance, the turns, the health bar and II. PR 1 puts the health bar in a `VBoxContainer`, `Bars`, with the meter under it:

| Node | Properties |
|---|---|
| `Top/Bars` (`VBoxContainer`) | Takes the health bar's place and its size flags: it fills the width that the labels and II leave (`size_flags_horizontal` 3), and is centred in the top bar's height (`size_flags_vertical` 4). `separation` 2, `mouse_filter = IGNORE` |
| `Top/Bars/Health` (`ProgressBar`, `%Health`) | As on `main`: 12 px high, 0 to `START_HEALTH`, `mouse_filter = IGNORE` |
| `Top/Bars/Offroad` (`ProgressBar`, `%Offroad`) | 8 px high; 0 to 1, with `step` 0; `value` 1; no percentage; `theme_type_variation` `OffroadBar`; `mouse_filter = IGNORE`; `modulate` alpha 0 |

At the game's base size, 360 × 640, its narrowest layout, the top bar is 40 px high, from y 8 to 48. The box is 22 px high and centred in it, so the health bar runs from y 17 to 29, 5 px higher than `main`'s 22–34, and the meter from 31 to 39 (P7). Both are 124 px wide at 17 m with 0 turns. They are 138 px wide at 0 m, and lose 14 px with each digit of the distance or of the turns, as the health bar does on `main`: at 12,340 m, 82 px with fewer than 10 turns and 54 px with 100 or more; at 999,990 m with 999 turns, 40 px (P7, P7b). Wider screens give them more: the stretch mode keeps the base size as the least and scales by whole numbers (`project.godot`:26–31).

`hud.gd`:

```gdscript
@onready var _offroad: ProgressBar = %Offroad
...
	EventBus.car_offroad_changed.connect(_on_car_offroad_changed)
	EventBus.car_offroad_room_changed.connect(_on_car_offroad_room_changed)
...
func _reset() -> void:
	...
	_on_car_offroad_changed(false)
...
## The off-road meter shows only while the car is off the road, and is full as the car leaves it.
## It hides by its alpha, so that the health bar above it never moves. A run that ends off the road
## leaves it as it was until the next run: empty if the car reached the limit.
func _on_car_offroad_changed(is_offroad: bool) -> void:
	_offroad.value = _offroad.max_value
	_offroad.modulate.a = 1.0 if is_offroad else 0.0


func _on_car_offroad_room_changed(room: float) -> void:
	_offroad.value = room
```

- **Hidden by its alpha.** With `visible = false`, the box would shrink to the health bar's 12 px, and the top bar would centre the health bar again each time the car left or rejoined the road: it would jump between y 22 and 17 (N7). At alpha 0 the meter keeps its place, and the health bar moves once, with PR 1.
- **Full as the car leaves.** Each trip off the road counts from 0 (`_leave_road()` sets `offroad_dist` to 0), so the meter fills on `offroad_changed(true)`, before the first room comes. It fills on `false` too, so that it is full the next time.
- **At the end of a run.** `_on_run_ended()` leaves the meter alone, so under the game-over screen it shows how the run ended: empty after the limit, as a crash or a missed turn; partly full if the health ran out off the road first, and empty if both ran out in the same step (§5.1); hidden if the run ended on the road, at a wrong exit. The next run's `_reset()` hides it and fills it, as a retry doesn't reload the HUD (M3_PLAN.md J10).
- **While paused,** the car doesn't move, so the meter keeps its value under the pause message.
- **`step` 0.** A `Range` rounds its value to `step`, which a `ProgressBar` sets to 0.01 (`scene/gui/progress_bar.cpp`:292–294 at 4.7.2-stable). With `step` 0, `value` is the room that the car sent, and the tests compare it exactly. The fill is drawn in whole pixels, and not at all under half a pixel (:115–125), so the meter looks empty a little before the limit: under 0.42% of it at 124 px wide, 1% at 54 px and 1.4% at 40 px (P7b). Off the road at the limit, the car drives at least a tile a second (P9), so that is the last frame or two of the trip.

### 5.3 The look (E5)

`theme.tres` gets a type variation of `ProgressBar`, `OffroadBar`, with a fill of its own:

```
[sub_resource type="StyleBoxFlat" id="StyleBoxFlat_offroad"]
bg_color = Color(0.9254902, 0.76862746, 0.2509804, 1)
border_width_left = 2
border_width_top = 2
border_width_right = 2
border_width_bottom = 2
border_color = Color(0.078431375, 0.07058824, 0.09411765, 1)
...
OffroadBar/base_type = &"ProgressBar"
OffroadBar/styles/fill = SubResource("StyleBoxFlat_offroad")
```

- **Colours.** The yellow, (236, 196, 64), is the palette's `yellow` (`assets/palette.gpl`:39). The fill's border is the health bar's 2 px of ink, (20, 18, 24). Through the variation, the meter's background is every `ProgressBar`'s, `StyleBoxFlat_bar`.
- **Contrast.** Against the ink background, the yellow has 11.10:1, and the health bar's red 3.50:1; WCAG 2.2's 1.4.11 asks 3:1 of a control's parts. The yellow against the red is 3.17:1, so the two bars differ in lightness, not only in hue. `test_hud.gd` checks both of the yellow's ratios against 3:1 (N22), and that each of the three styles draws its colour, opaque (N24, N25). They also differ in place, height and when they show, so colour is not the only cue (1.4.1).
- **Nothing flashes.** The meter shows and hides only as the car leaves and rejoins the road, which a car along the road's edge can do again and again. But it is small. Godot draws the view, at least 640 px high (`expand`), at a whole scale k, and centres it (`scale_mode="integer"`, `project.godot`:26–31). In a window at least the base size, 360 × 640, the view fits, so the meter is drawn 8k px high in a window at least 640k px high: at most 1.25% of the window's height, and less of its area. A smaller window, as a desktop browser's can be, shows the view at scale 1, cut off at its right and bottom edges (Godot 4.7.2's `window.cpp`:1380–1402), so the meter covers 8 px of its height: 2.2% of a window 360 px high. P10 measured 0.19–0.78% of the window's area at the base size, the Fold4's screens and a desktop's, and 0.66–1.61% in three smaller windows. That is far below a quarter of the screen, the most that `test_disasters.gd` lets a legend's glow cover (`AGENTS.md` §3), and below WCAG 2.3.1's threshold for a flash, a quarter of any 10° of the field of view, at a phone's viewing distance.
- **The Web.** The meter is a `ProgressBar`, drawn with `StyleBoxFlat`s, and `modulate` redraws no polygon, so godotengine/godot#124726 doesn't apply (`AGENTS.md` §3). It has no text, so it needs no glyph. In Chrome, the console showed no error (§6.4).

### 5.4 Touches (B6, E4)

`InputRouter` reads touches in `_unhandled_input()` (`car/input_router.gd`:37–47). A touch steers left or right by the half of the screen that it lands in, unless a `Control` under it has kept it, as II does (M2_PLAN.md H9). With `mouse_filter = STOP`, a `ProgressBar`'s default, a bar keeps every touch on it (N13, N15). With `IGNORE`, the touch goes through. A container at its default, `PASS`, lets the touch through too, as N14 shows.

So the meter, the health bar and their box have `IGNORE`, as M2 gave the root, the top bar and the health bar. `test_a_touch_on_the_health_bar_or_the_off_road_meter_steers` touches the middle of each bar in the main scene, with the meter hidden as it is on the road. The touch must steer left or right by the half of the screen that it's in, and its release must stop. The test fails if either bar keeps its touches (N13, N15). It can't fail for the box, which lets a touch through even at `PASS` (N14), so the box's `IGNORE` says what it does, as the top bar's does.

### 5.5 What doesn't change (E6)

- The rules: the limit, 2 tiles in every area; the damage rates; the causes; `GameState`'s states; and the messages (`ui/game_over.gd`:16–21).
- How the end looks and sounds: the wreck and the smoke for `HEALTH` and `OFFROAD`, the crash sound, and the screech and rumble off the road (Q3, Q5).
- The road, the autopilot and every seed: `smoke.sh` prints `main`'s line, and `test_road_generator_determinism.gd`'s digest is unchanged.
- The save, the settings, the Atlas and the legends.

### 5.6 Documents (B4, B5, E8)

PR 1 changes `plan.md`:

- §2.4, after the off-road limit: "**The HUD shows both limits:** the health bar, and, while the car is off the road, a meter under it that shows how much of the off-road limit is left. The car can reach the limit with health left, so the meter is the one that warns of it (`HEALTH_BAR_PLAN.md` B1)."
- §5.3's shared assets: "UI: HUD, health bar, off-road meter, pixel font, pause and menus."
- §7.1's scene tree: "HUD (distance, turns, health, off-road meter, pause)".
- §13's decision log, the off-road row: "Corner cutting within 2 tiles is damage only; the car cannot stay off-road longer than 2 tiles, and the HUD shows how much of that is left".

`hud.gd`'s header names the meter and says "the game's font" (B5).

---

## 6. Verification

### 6.1 Checks and counts

The checks are `AGENTS.md` §4's five. `main` (1047e17) and the prototype's states ran them in CI, in runs started by hand (`workflow_dispatch`), and 7ddb234, d964101, 71e2c9e and 4553c1b ran them locally too, with Godot 4.7.2 on 2 CPUs. 528196e, `main` after ZS, ran them in this plan's PR's CI, and 4553c1b's difference applied to it ran them locally (§4.5):

| State | Where | Scripts loaded | Test scripts | Tests | Asserts | GUT time | Smoke |
|---|---|---|---|---|---|---|---|
| `main` (1047e17) | Run 43293662593 | 142 | 65 | 473 | 422,730 | 86.7 s | `autopilot: tile 165, turns 35, area rural` |
| Prototype (45fa976) | Run 43340484313 | 142 | 65 | 478 | 422,859 | 51.6 s | The same |
| Prototype (7ddb234) | Run 43341234890 | 142 | 65 | 478 | 422,859 | 61.4 s | The same |
| Prototype (7ddb234) | Local | 142 | 65 | 478 | 422,859 | 105.8 s | The same |
| Prototype (d964101) | Local | 142 | 65 | 480 | 422,867 | 95.3 s | The same |
| Prototype (d964101) | Run 43343658211 | 142 | 65 | 480 | 422,867 | 55.5 s | The same |
| Prototype (71e2c9e) | Local | 142 | 65 | 480 | 422,879 | 86.5 s | The same |
| Prototype (71e2c9e) | Run 43350939501 | 142 | 65 | 480 | 422,879 | 84.6 s | The same |
| Prototype (4553c1b) | Local | 142 | 65 | 480 | 422,889 | 86.8 s | The same |
| Prototype (4553c1b) | Run 43355628358 | 142 | 65 | 480 | 422,889 | 87.6 s | The same |
| `main` (528196e) | Run 43360902414 | 142 | 65 | 480 | 422,823 | 54.4 s | The same |
| 4553c1b's difference on 528196e | Local | 142 | 65 | 487 | 422,982 | 86.8 s | The same |

45fa976 adds 5 tests and d964101 2 (§4.6); 73e5012 changes a comment, 7ddb234 a check and a message, 71e2c9e adds 12 checks to 7 tests, and 4553c1b 10 to 3 (§4.6). ZS adds 7 tests and 93 asserts to `main`, and the difference adds the same 7 tests and 159 asserts to 528196e as to 1047e17. The `test` job took 2 min 19 s on 7ddb234, 2 min 07 s on d964101, 2 min 27 s on 71e2c9e, 2 min 27 s on 4553c1b, and 2 min 06 s on 528196e. Locally, every check passed, `smoke.sh` printed no error line, and `git status --porcelain` printed nothing after them. GUT's time varies by tens of seconds from run to run, and more on the local machine than in CI.

### 6.2 Negative cases

Each change below makes the tests named fail. A script, not committed, applied each change to a clean worktree of `hb/prototype`, ran `tools/ci/run_tests.sh`, read GUT's JUnit report, and restored the file. Each case took 87–95 s (87–90 s on 4553c1b, 87–91 s on 528196e). N1–N12 ran on 7ddb234, N1–N16 on d964101, N1–N25 on 71e2c9e, and all 25 on 4553c1b, whose results the table gives. All 25 ran again on a worktree of 528196e with 4553c1b's difference applied (§4.5), and each failed the same tests as on 4553c1b. Each failed as below, and nothing else did; N14 fails nothing, as expected (§5.4). On 71e2c9e, N23–N25 failed nothing: they are the follow-up review's F9 and F10 (§4.7). After the run, `git status --porcelain` printed nothing.

| N# | Change | Fails |
|---|---|---|
| N1 | `car_sim.gd`: `_drive_off_road()` doesn't emit `offroad_room_changed` | `test_car_sim_offroad.gd`: `test_off_the_road_the_room_left_falls_with_each_step_to_none_at_the_limit`, `test_the_room_left_is_a_share_of_the_limit_of_the_area_driving_the_car`, `test_off_the_road_the_time_before_a_new_area_counts_at_the_old_areas_rates`, `test_running_out_of_health_is_a_crash`, `test_the_offroad_limit_near_a_junction_is_a_missed_turn`; `test_crash.gd`: `test_a_car_lost_off_the_road_shows_its_health_left_and_an_empty_meter` |
| N2 | `car_sim.gd`: `offroad_room()` divides by 2.0, not by the area's limit | `test_the_room_left_is_a_share_of_the_limit_of_the_area_driving_the_car`, `test_off_the_road_the_time_before_a_new_area_counts_at_the_old_areas_rates` |
| N3 | `car_sim.gd`: `offroad_room()` isn't clamped | `test_off_the_road_the_room_left_falls_with_each_step_to_none_at_the_limit`, `test_the_offroad_limit_near_a_junction_is_a_missed_turn` |
| N4 | `car_sim.gd`: `offroad_room()` returns `health / Tuning.START_HEALTH` | N1's six |
| N5 | `main.gd` doesn't relay `offroad_room_changed` | `test_crash.gd`: `test_a_car_lost_off_the_road_shows_its_health_left_and_an_empty_meter` |
| N6 | `hud.gd` doesn't connect `car_offroad_room_changed` | N5's, and `test_hud.gd`: `test_off_the_road_a_meter_under_the_health_shows_the_room_left`, `test_a_run_that_ends_off_the_road_leaves_the_meter_as_it_was` |
| N7 | `hud.gd` hides the meter by `visible`, not by its alpha | N6's three, `test_the_meter_sits_under_the_health_bar_and_never_moves_it` and `test_each_run_starts_the_hud_afresh` |
| N8 | `hud.gd` doesn't fill the meter on `car_offroad_changed` | `test_off_the_road_a_meter_under_the_health_shows_the_room_left`, `test_each_run_starts_the_hud_afresh` |
| N9 | `_reset()` neither hides nor fills the meter | `test_each_run_starts_the_hud_afresh` |
| N10 | `_on_run_ended()` hides the meter | N5's, and `test_a_run_that_ends_off_the_road_leaves_the_meter_as_it_was` |
| N11 | `hud.tscn`: the meter has no `theme_type_variation`, so it takes the health bar's red | `test_off_the_road_a_meter_under_the_health_shows_the_room_left` |
| N12 | `theme.tres`: the meter's yellow is (0.93, 0.77, 0.25), off the palette | `test_ui_theme.gd`: `test_the_themes_colours_are_the_palettes` |
| N13 | `hud.tscn`: the meter has the default `mouse_filter`, `STOP` | `test_main_scene_boot.gd`: `test_a_touch_on_the_health_bar_or_the_off_road_meter_steers` |
| N14 | `hud.tscn`: `Bars` has the default `mouse_filter`, `PASS` | None, as expected: `PASS` lets the touch through to `InputRouter` (§5.4) |
| N15 | `hud.tscn`: the health bar has the default `mouse_filter`, `STOP` | `test_a_touch_on_the_health_bar_or_the_off_road_meter_steers` |
| N16 | `hud.tscn`: the meter is a child of `Top`, beside the health bar | `test_the_meter_sits_under_the_health_bar_and_never_moves_it` |
| N17 | `hud.tscn`: the meter keeps `ProgressBar`'s default `max_value`, 100 | `test_off_the_road_a_meter_under_the_health_shows_the_room_left` |
| N18 | `hud.tscn`: the meter keeps the default `step`, 0.01 | `test_off_the_road_a_meter_under_the_health_shows_the_room_left` |
| N19 | `hud.gd`: `_on_run_ended()` hides the meter by `visible` | N10's two, and `test_each_run_starts_the_hud_afresh` |
| N20 | `car_sim.gd`: `_drive_off_road()` emits the room after it checks the limits | N3's two |
| N21 | `car_sim.gd`: the room uses `area`, the new area's limit, for the whole step | `test_off_the_road_the_time_before_a_new_area_counts_at_the_old_areas_rates` |
| N22 | `theme.tres`: the meter's fill is the palette's ink | `test_off_the_road_a_meter_under_the_health_shows_the_room_left` |
| N23 | `hud.gd`: `_on_run_ended()` hides the health bar | N5's, and `test_each_run_starts_the_hud_afresh` |
| N24 | `theme.tres`: the meter's yellow is transparent | `test_off_the_road_a_meter_under_the_health_shows_the_room_left` |
| N25 | `theme.tres`: the meter's fill draws no centre, `draw_center = false` | `test_off_the_road_a_meter_under_the_health_shows_the_room_left` |

### 6.3 Editor warnings

None of the five checks reports GDScript warnings, and shadowing shows only in the editor (`AGENTS.md` §3). As in M2–M6 (M2_PLAN.md §6.3), a probe asked the editor's language server for them: it starts `godot --headless --editor --lsp-port <port>` and opens every `.gd` file outside `addons/` and `.godot/`. The shadowing warnings are on, at level 1, as `project.godot` raises only `untyped_declaration` (:22). On `main` (1047e17), on d964101, on 4553c1b, and on 4553c1b's difference applied to 528196e, it reports the same 5 warnings in 142 scripts, and no error. They are M5's (ROADGEN_PLAN.md §6.3): `INTEGER_DIVISION` in `test_greybox_atlas.gd`:15, `test_iso.gd`:42, `ui/main.gd`:46 and `world/greybox_atlas.gd`:135, and `UNUSED_VARIABLE` `junctions` in `test_road_generator_occupancy.gd`:30. None comes from HB: `ui/main.gd`:46 is in `_ready()`, and PR 1 adds only :121; on 528196e they are :52 and :128. So no name that HB adds shadows a member or a built-in. The editor changed no file.

### 6.4 Verified only in CI or on devices

- **CI.** The five required checks on PR 1, and the `test` job's time (§6.1).
- **E7 on the Web,** on PR 1's build, by an agent if it can, or else by the owner. Build, download and serve it with M4's patch, which passes the URL's `arg`s to the game (M4_PLAN.md §4, PR 3 step 3):
  ```bash
  gh workflow run ci.yml -R pompomon/roadgame --ref hb/1-offroad-meter -f upload-builds=true
  gh run download <run id> -R pompomon/roadgame -n web -D /tmp/roadgame-web
  sed -i 's/"args":\[\]/"args":["--"].concat(new URLSearchParams(location.search).getAll("arg"))/' \
    /tmp/roadgame-web/index.html
  python3 -m http.server -d /tmp/roadgame-web 8000
  ```
  Open `http://localhost:8000/?arg=--play&arg=--seed=3331220946` in Chrome and Firefox; `--play` skips the title (M5_PLAN.md:349). Steer off the road and stay off: the meter shows full as the car leaves the road and empties as it goes, and the run ends at the limit with health left. To end as the screenshot did, hold the left half of the screen, or Left, from about 0.9 s after the start for about a third of a second (P1). Check each point of E7, and post a table in a PR comment, one row per check, with screenshots.

  **Done in Chrome,** on the build of 45fa976 from run 43340484313. Chrome 157, driven by Playwright, ran the game off the road (P5). Partway through the trip, the meter showed about 45% left under a health bar about 85% full. The run ended at 15 m with "You got lost off the road.", the health bar about 75% full, the meter empty under it, and the car a wreck. Retry filled the health bar and hid the meter. The console had no errors, only the 4 known `GPU stall due to ReadPixels` notes. The commits since change only a comment and tests, so the build looks the same. Firefox isn't installed where this plan was written, so it is left for PR 1's build.
- **On the Fold4,** by the owner, on both screens. The APK takes no arguments (M4_PLAN.md P4), so start a run from the title, steer off the road and stay off. PR 1's build has ZS, so its title's Start button can choose the area (`AGENTS.md` §6). Or, as M4 did (M4_PLAN.md Q6), serve the Web build above, run `adb reverse tcp:8000 tcp:8000`, and open the same URL in the Fold4's Chrome. Check that the meter reads as the second limit, doesn't crowd the cover screen's top bar, and never moves the health bar, and that a touch on the bars steers.

### 6.5 Measurements

The probes ran headless with Godot 4.7.2, on `main`'s rules; they aren't committed.

| P# | What | Result | Used by |
|---|---|---|---|
| P1 | The screenshot's run. Seed 3331220946, in the game's schedule, with `CarSim` stepped at 60 Hz: 1,230 ways of steering left once, starting in the first 2 s, in steps of 0.05 s, and held for 0.05–1.5 s | 3 end the run at 17 m, all with "You got lost off the road.": start 0.90 s and hold 0.30 s, with 64.9 health left; start 0.95 s and hold 0.40 or 0.45 s, with 66.2. The car was off the road for 1.12–1.17 s, and left it at 2.43–2.53 tiles a second | B1 |
| P2 | Health at the limit, from full health, on a straight. On seed 1's path tile 1, in a schedule of each area alone, the car turned 90° right, at 71 speeds from 0 to 7 tiles a second in steps of 0.1, with 0, 2, 4, 8 or 100 tiles driven on the straight and 0 or 1,500 tiles driven in the run: 710 trips an area | All 3,550 ended at the limit (`OFFROAD`). Health left: the City 53.8–90.4, Rural and Meadows 70.9–92.0, the Village 58.8–90.4, the Desert 51.8–88.8. Least when the car starts at rest with none of the straight driven. So these trips off a straight took 8.0–48.2 health | B1, Q1 |
| P3 | P2 without the limit, at 14 speeds from 0.5 to 7 tiles a second: how far a trip goes until the health runs out, and what a tile off the road costs | Distance: the City 5.42–9.55 tiles, Rural and Meadows 8.85–12.04, the Village 6.23–9.98, the Desert 4.72–8.28. A tile costs the City 5.1–25.1 health, Rural and Meadows 4.3–15.9, the Village 5.1–22.6, the Desert 6.0–26.4 | Q1 B and C |
| P4 | `test_crash.gd`'s new drive, seed 1 turned 90°, in the main scene under Xvfb, with the HUD captured | Partway, 74.7 health and room 0.492; at the end, 54.2 health and room 0, the meter empty under the health bar | E3 |
| P5 | The Web build of 45fa976 in Chrome 157 | §6.4 | E7 |
| P6 | The default `mouse_filter` of the HUD's node types | `ProgressBar` and `Control`: `STOP`. `VBoxContainer` and `HBoxContainer`: `PASS`. `Label`: `IGNORE` | B6 |
| P7 | The bars in the HUD, in a 360 × 640 viewport, with the distance at 0, 17, 170, 1,700 and 12,340 m, and 0 turns | The health bar at y 17–29 and the meter at 31–39, both 138 px wide at 0 m, 124 at 17 m (0.43% of the screen for the meter), 110, 96 and 82 | §5.2, §5.3, Q4 |
| P7b | P7 with the turns too: at 12,340 m with 0, 9, 35, 99, 100 and 999 turns, at 99,990 m with 100, and at 999,990 m with 999 | At 12,340 m, 82 px with 0–9 turns, 68 with 35–99, and 54 with 100–999; 54 px at 99,990 m with 100, and 40 at 999,990 m with 999. The fill is 4 px narrower, inside the border, so it draws nothing under 0.0064 of the limit at 82 px, 0.0100 at 54 px and 0.0139 at 40 px | §5.2, Q4, §8, §9 |
| P8 | Trips from full health at points along the road. In a schedule of each area alone, the autopilot drove seeds 1–3 for 0 to 20 s, in steps of 1/6 s; then the car turned 90° left or right and drove on unsteered: 726 trips an area | None ran out of health. 2,388 crashed at the limit, with 51.8–82.8 health left; 1,058 missed a turn at it, near a junction, with 35.0–82.8; 179 ended in a disaster on the road before the limit; 5 rejoined the road. Crash and missed turn by area: the City 54.2–77.4 and 39.8–77.9; Rural and Meadows 70.8–82.8 and 61.9–82.8; the Village 59.2–78.9 and 45.2–78.4; the Desert 51.8–74.1 and 35.0–59.2. The least came from cars that left the road at the junction's speed, half a tile before the junction, where the target speed off the road stays at `junction_speed` × `offroad_speed_mult` (`car_sim.gd`:187–190). So these trips near a junction took up to 65.0 health; P9 finds the most that one can | B1 |
| P9 | The costliest trip off the road that the rules allow. Off the road the car heads for at least T = `junction_speed` × `offroad_speed_mult` (`car_sim.gd`:182–191), as `AreaDef.validate()` keeps `junction_speed` at most `BASE_TOP_SPEED`, where the run's speed cap starts (`area_def.gd`:90–91). Nothing else slows it until the run ends, and from rest it gains `ACCEL`, 2 tiles a second each second (`car_sim.gd`:194–209). So the slowest trip to the limit, 2 tiles, starts at rest and takes T/4 + 2/T s. In a schedule of each area alone, seeds 1–10: the car at rest on the tile before the first junction, 0.45 tiles to the side of its centre, facing away from the road, unsteered: 20 trips an area | The most a trip can take: the City 67.5 health, Rural and Meadows 46.1, the Village 62.8, the Desert 74.3, and one step's 0.4–0.6 more. A trip that crosses into the next area, at the slower area's speed and the costlier's rate, takes no more: the Village's and the Desert's T are 1.10 and 1.08 tiles a second. The trips lost 67.5, 46.3, 46.3, 63.0 and 74.1, and all missed the turn at the limit. So from full health the limit comes first, with at least 25 health left; and at the limit the car drives at least 1 tile a second, the City's T | B1, Q1, §5.2 |
| P10 | How much of a window the meter covers, with the project's stretch settings. The HUD at 17 m, in a real window under Xvfb: at the base size, at the Fold4's four screen sizes in M2_PLAN.md §6.5, at a desktop's 1280 × 720, and in three windows smaller than the base size | At least the base size, the view fits, centred: 360 × 640 at scale 1, the meter 0.43% of the window and 1.25% of its height; 904 × 2316 at 2, 0.19% and 0.69%; 2316 × 904 at 1, 0.54% and 0.88%; 1812 × 2176 at 3, 0.54% and 1.10%; 2176 × 1812 at 2, 0.43% and 0.88%; 1280 × 720 at 1, 0.78% and 1.11%. Smaller, the view at scale 1, cut off at the right and bottom: 640 × 360, 1.61% and 2.22%; 1366 × 600, 1.16% and 1.33%; 300 × 500, 0.66% and 1.60% | §5.3, §8 |

---

## 7. Owner actions

| When | Action | How |
|---|---|---|
| Now | Answer Q1–Q7, or accept the defaults | A comment on this plan's PR. Without an answer, PR 1 follows the defaults (§3) |
| Now, if wanted | Try the prototype on the Fold4 | Until 2026-11-14 02:57 UTC: `gh run download 43355628358 -R pompomon/roadgame -n "android-Android APK" -D /tmp/roadgame-apk`. After that, `gh workflow run ci.yml -R pompomon/roadgame --ref hb/prototype -f upload-builds=true` makes a new one. Then `adb install -r /tmp/roadgame-apk/roadgame-debug.apk`, and §6.4 |
| Before PR 1 merges | E7 on the Fold4 | On PR 1's build: the run that PR 1's body gives, as above (§6.4) |
| To land HB | Merge this plan's PR. Retarget PR 1 to `main` before `hb/plan` is deleted. Once PR 1 has merged `main` and its checks pass, merge it | §4.5 |
| After | Delete the `hb/` branches | `git push origin --delete hb/plan hb/1-offroad-meter hb/prototype`, less any already deleted |

---

## 8. Risks

| Risk | Impact | Mitigation |
|---|---|---|
| The meter blinks along the road's edge | A car that runs along the road's edge leaves and rejoins it often, and the meter shows and hides each time | It covers at most 1.25% of the height of a window at least the base size, and 2.2% of a window 360 px high (§5.3, P10), and shows only off the road, where the screech and the rumble play too. If play shows that it distracts, it can stay a moment after the car rejoins (§9) |
| The meter isn't understood | With no label (Q4), a player may not know what the yellow bar is | It shows only off the road, and is empty as the run ends with "You got lost off the road." E7 checks it on the Fold4. Q4's alternative adds a label |
| The top bar is crowded on a narrow screen | At the base width, 360 px, the bars lose 14 px with each digit of the distance or of the turns: 82 px at 12,340 m with fewer than 10 turns, 54 px with 100 or more, and 40 px at 999,990 m with 999 (P7, P7b) | The meter takes no width, only 10 px under the health bar within the top bar's 40. Wider screens give the bars more (§5.2), and M7.1 lays out both of the Fold4's screens (§9) |
| An area with another limit | At such an area's first tile, the room would jump, as the limit changes with the rates | That is the rule: the room is a share of the limit that counts the step, and a test checks it with a limit of 4 tiles. Every area's is 2 today |
| A lost car still looks wrecked | A car with health left is wrecked (B3) | The meter is empty under it. Q3's alternative stops the car without the wreck |
| The health bar moves 5 px up | Once, with PR 1 | No test or screenshot checks its place on `main`. PR 1's layout test checks it from then on |

---

## 9. Notes for later work

- M7.2 (`IMPLEMENTATION_PLAN.md`:446–447) vibrates on damage ticks, at most once each 250 ms. A trip off the road gets those ticks until it ends, so the vibration warns of both limits. A longer pulse as the meter nears empty would be Q5's alternative.
- M7.5's device checklist (`IMPLEMENTATION_PLAN.md`:456–462) gains a line: "Off the road, the meter under the health bar shows how much of the off-road limit is left, on both screens, without crowding the HUD." Its touch line (:460) holds for the bars too: a touch on them steers (E4).
- M7.1 lays out both of the Fold4's screens (`IMPLEMENTATION_PLAN.md`:441–444). On `main` the health bar narrows with each digit of the distance or of the turns, to 54 px at 12,340 m after 100 turns at the base width (P7, P7b), and the meter with it.
- M7.1 could fit windows smaller than the base size, 360 × 640, too, as a desktop browser's can be. There `scale_mode="integer"` keeps the scale at 1, and Godot cuts the view off at the window's right and bottom edges (§5.3, P10). At 640 × 360 and at 1366 × 600, P10 found the meter's right end cut off, so the pause button, right of the bars in `Top`, is off screen too. So is it on `main`, right of the health bar.
- B5's leftovers, `ui/atlas_screen.gd`:6 and `ui/settings_screen.gd`:7–8, still say "Godot's default font". A docs PR can fix them.
- `plan.md` §7.4's list of signals (:267–274) has neither `car_offroad_changed` nor `car_offroad_room_changed` (Q7). A docs PR can complete it.
- Q3's alternative, if play shows that the wreck confuses: a lost car stops without the wreck and the crash sound.
- If the meter blinks too much along the road's edge (§8), `hud.gd` can keep it shown for a moment after the car rejoins the road.
