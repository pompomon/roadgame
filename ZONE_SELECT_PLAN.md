# Zone Selection: Choosing the Start Area on a Phone — Detailed Plan

Status: the plan is merged (#60), and PR 1, which implements it, is in review (§4) · 2026-11-13 · Q1–Q6 had no answers when #60 landed, so PR 1 follows their defaults; the owner may still answer them (§3) · Scope: an option on the title screen of debug builds that chooses the area a run starts in, so that each area can be checked on a phone without driving to it. The game calls zones *areas*: the City, Rural, Meadows, the Village and the Desert. This plan calls the work ZS. It comes after RG (#54–#57) and before M7.

The owner asked: "Explore the codebase and create a detailed implementation plan for a 'zone selection' start option, for manual testing on phone."

**Verified locally.** Every file that this plan changes was first built on branch `zs/prototype`, on top of `main` (1047e17), as one commit, d4300a8 (§4.1). It passed the five checks with Godot 4.7.2 (§6.1). Each of its 12 negative cases made the tests it names fail, in a run of the whole suite (§6.2), and the editor's warnings didn't change (§6.3). Probes settled how Android's back button meets a dropdown and how wide each text is, and a throwaway test timed each area's first legend, also on the seeds with the most decoys (§6.5). Not done yet: the release builds' default, which only a release build shows (§6.4), and the Fold4 (§7). A model of another family, gpt-6.1-sol, reviewed this plan and the prototype (`AGENTS.md` §7). Its one finding, that decoys can put a legend off past E8's 9 s, changed E8, P4 and §7, not the code (§4.6).

**PR 1.** It ported the prototype, and passed the same checks with the same counts. The same model then reviewed PR 1's diff, and found two tests weaker than §5.4 says, which PR 1 fixes; each fix has a negative case, N13 and N14 (§4.6, §6.2). PR 1's head then passed the checks again, with one more assert. Its 14 negative cases failed the tests they name, and its warnings were the prototype's (§6.1–§6.3). Its release Web build showed `main`'s title, with no Start button, in Chrome and Firefox (§6.4). Not done yet: the Fold4 (§7).

- Godot 4.7.2-stable
- GUT 9.7.1
- gdtoolkit 4.5.0 on Python 3.12.3. shellcheck isn't installed locally, so `lint.sh` skipped it; no shell script changes. PR 1's checks ran with shellcheck 0.9.0
- git 2.51.1

**Precedence.** For ZS, this document replaces M4_PLAN.md Q6's way of checking each area on the Fold4 (the Web build in the phone's Chrome over `adb reverse`, with `?arg=--area=<id>` in a patched `index.html`), wherever it marks a difference with **Δ** and its finding (Z#, §2). `--area` stays as M4 K10 and Q5 made it. IP and `plan.md` don't change: players never see the option (Z4), and a run still starts in the City (`plan.md`:26).

**Reference code.** This plan has no appendices. PR 1 applies the difference between `main` (1047e17) and `zs/prototype` (d4300a8), which never gets a PR of its own (§4.1).

**Prerequisites.** RG is merged: its last PR (#57) landed as 1047e17. No repository settings change.

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

Goal: start a run in any area on a phone. Today only `--area=<id>` starts a run elsewhere than the City (M4_PLAN.md K10), and a phone can't pass it (Z1). Without it, the Desert is 6.6 minutes of right turns away (M4 P2), and one wrong turn starts over.

In debug builds, the title screen gets a second button under Play: "Start in: City". Each tap steps to the schedule's next area, and after the Desert back to the City. Play then starts the run in that area as `--area` does: the same road for the same seed, without the set piece that leads in. Retry stays in the area, and the title keeps the choice. `--area` presets it. Release builds, which players get, show nothing new (Q1, Q2).

```
        Road Roguelike
     Best: 420 m, 12 turns
          [  Play  ]
     [ Start in: Desert ]     <- debug builds only; each tap: the next area
          [ Atlas  ]
         [Disasters]
         [Settings ]
```

| # | Exit criterion | Checked by |
|---|---|---|
| E1 | In debug builds the title shows the Start button under Play, with "Start in: " and the area's name. Release builds hide it, and their Play runs as on `main` (Z4). Play keeps the focus | `test_title_screen.gd`: `test_the_start_button_shows_in_debug_builds_only`; `test_area_start.gd`: `test_a_hidden_start_button_leaves_the_run_to_the_area_argument`; the release default in §6.4 |
| E2 | Each tap on it steps to the schedule's next area, City, Rural, Meadows, Village, Desert, and after the last back to the first. It never starts a run. The title keeps the choice while the game runs, and makes an area that the schedule lacks its first | `test_title_screen.gd`: `test_the_start_button_steps_through_the_areas_and_open_keeps_the_last` |
| E3 | Play starts the run in the chosen area, as `--area=<id>` does (Z6): the car, `GameState.area_id` and the banner name it, and the road is `--seed=<n> --area=<id>`'s. Retry stays in the area, and the title after game over keeps the choice | `test_area_start.gd`: `test_the_title_starts_the_runs_in_the_chosen_area_as_the_area_argument_does` |
| E4 | The world draws the road, ground and props of every area, whichever area a run starts in, also after `--area` (Z2). The rows behind the car at the start show the start area's props (Z3) | `test_prop_scatter.gd`: `test_the_rows_below_the_start_show_the_area_the_road_starts_in`; `test_area_start.gd`: E3's test and `test_the_area_argument_presets_the_choice_and_the_world_has_every_area` |
| E5 | `--area=<id>` presets the choice. `--play` and `--autopilot` skip the title as before, so `smoke.sh` prints `main`'s line | `test_area_start.gd`: E4's second test and its 6 existing tests; `smoke.sh` (§6.1) |
| E6 | The title fits 360 × 640 with each area's text, and the button keeps its width as it steps (Z9). Its text uses only the font's glyphs (Z8) | `test_title_screen.gd`: `test_the_title_page_fits_a_portrait_screen_with_each_start_area`; `test_smoke.gd`: `test_main_scene_text_has_every_glyph_in_the_default_font` |
| E7 | All five required checks are green, with §6.1's counts. Each negative case makes the tests it names fail, and the editor reports no new warnings | PR checks; §6.2 and §6.3, run locally with Godot 4.7.2 on PR 1's head |
| E8 | Manual, on the Fold4 with CI's debug APK: the button shows and steps. A run in each area starts with that area's road, ground, props, banner, music and ambience, and with no input ends in that area's legend at the first junction that turns. That takes 5.5–8.6 s after Play in most runs; decoys before it put it off, to 17.3 s at the Desert's seed 2277, which has the most decoys first of seeds 1–3000. These times are a guide, not a limit (P4). Retry and Title keep the area, and Android's back button still quits from the title. The release Web build's title looks as `main`'s does | §6.4, §7 |
| E9 | The comments that PR 1 touches, and `AGENTS.md` §6 on device checks, say what the code does | Review |

---

## 2. Review findings

M4's `--area` (K10) already does the hard part. `AreaSchedule.starting_at()` (`areas/area_schedule.gd`:69) makes a schedule that starts in any area, and the generator, the director, the HUD and the music follow it. What's missing is a way in from a phone, and two places that assume the world's schedule is the run's. Lines below are `main`'s, at 1047e17.

### High

| # | Finding | Evidence | Fix |
|---|---|---|---|
| Z1 | **A phone can't choose an area.** `--area` is a user argument, and neither the APK nor the Web build takes them. M4's way round it needs a computer, `adb reverse` and a patched copy of the Web build, and it checks the Web build, not the APK. Without it, the Desert is 397 s of driving with no mistake | `ui/main.gd`:7–9 and :17 (`OS.get_cmdline_user_args()`); M4_PLAN.md P4 (:684): Godot strips the arguments from the intents of exported activities, and `index.html` passes `"args":[]`; Q6 (:118); P2 (:682); K10 (:87) | In debug builds, a Start button on the title that chooses the area for Play (Q1, Q2, §5.1). **Δ M4 Q6** |
| Z3 | **The scatter's first area is the schedule's, not the road's.** `PropScatter` gives the `BUFFER_BEHIND` (20) rows below path tile 0 the props of its schedule's first area, and `WorldRenderer` makes it once. With no `--area` that is the City, so a run that starts in the Desert would show City props behind the car at its start | `world/prop_scatter.gd`:44–48 (`_first_area` set in `_init`), :128–129 (`_show_row`: `_first_area` for k < 0); `world/world_renderer.gd`:84; M5_PLAN.md:397 | `bind()` takes it from the road it binds: `RoadGenerator.first_area()`, new, the area of path tile 0 (§5.3). The scatter still makes the props of every area of its schedule once |

### Medium

| # | Finding | Evidence | Fix |
|---|---|---|---|
| Z2 | **The world is built once, from the run's schedule.** With `--area=village`, the world has the Village and the Desert only. A run that the title then starts in the City would draw the City's road with the Village's sheet, the Village's ground and no props. Nothing reports it: each lookup falls back without an error | `ui/main.gd`:44 (`_world.build(_schedule)` in `_ready`); `world/world_renderer.gd`:70–84 ("Call it once"), :129 (`_road_sources.get(tile.area_id, 0)`), :177 (`_areas.get(tile.area_id, _areas.values()[0])`); `world/prop_scatter.gd`:50 (`_props` only for the schedule's areas) | `_ready` builds the world from the whole schedule, whichever area runs start in (§5.2). With no `--area`, that's what `main` does now |
| Z4 | **Players mustn't see it.** A run starts in the City (`plan.md`:26), and the Atlas and the collection record each run. The game-over screen's seed shows only in debug builds, for the same reason (M3 J19, N52) | `plan.md`:26; `ui/game_over.gd`:26 (`show_seed := OS.is_debug_build()`); CI exports the Web build as release (`.github/workflows/ci.yml`:76) and the APK and AAB as debug (:113); `release.yml` exports all three as release (:86–87, :107) | `area_choice := OS.is_debug_build()` on the title, which tests change (§5.1). The Pages build and every release hide the button; CI's APK, which the owner installs on the Fold4 (`AGENTS.md` §6), shows it. GUT runs a debug build, so the release default is a §6.4 check, as M3_PLAN.md:259 found for `show_seed` |
| Z6 | **The choice must fit the paths that start runs.** Retry keeps the run's schedule; `--play` and `--autopilot` skip the title; `--area` chooses the area for every run. A choice that Retry dropped, or one that hid `--area`'s area on the title, would surprise | `ui/main.gd`:36–61 (`_ready`), :141–146 (`_retry`), :161–166 (`_play`); `tests/integration/test_area_start.gd` (K10's tests) | Play applies the choice; Retry keeps it; the title shows the last one; `--area` presets it; `--play` and `--autopilot` don't see it (§5.2). A run that the title starts in an area with seed n draws `--seed=n --area=<id>`'s road, so a run seen on the phone, whose seed game over shows in debug builds (J19), replays on a desktop |
| Z7 | **A dropdown would let Android's back button quit the game.** With an `OptionButton`'s popup open on the title, back reaches `main.go_back()`, which quits from the title (M5 L13), and the popup stays open. Its items are 21.6 px tall, too small to tap | P1, P3 (§6.5). Godot 4.7.2: `platform/android/android_input_handler.cpp`:135–139 sends the window's go-back request and `Key.BACK`; `scene/main/window.cpp`:827–836, :913–915 (`_propagate_window_notification` skips child windows); `scene/gui/popup.cpp`:44–47 (a popup closes on `ui_cancel`), `core/input/input_map.cpp`:469–471 (`ui_cancel` is Escape) | A button that steps, with no popup (Q1). The Settings screen's Orientation popup is safe: back closes the screen, and the popup with it (P1) |

### Low

| # | Finding | Evidence | Fix |
|---|---|---|---|
| Z5 | **The save records the runs that the choice starts.** The bests, the Atlas's per-area bests and the collection's seen counts grow as for any run, as they did for `--area`'s runs | M5_PLAN.md:578 (`--area=rural`'s run in the Atlas and the collection) | Keep it (Q3): a debug build's save is the tester's own. `adb shell pm clear com.pompomon.roadgame` empties it (`export_presets.cfg`:39), and a release build can't install over a debug one without an uninstall, which empties it too (§7) |
| Z8 | **The text must use the font's glyphs.** The Web build has no fallback font (`AGENTS.md` §3) | `ui/theme.tres`:3; `tests/unit/test_smoke.gd`:20 (the glyph test of the main scene's texts) | "Start in: %s" in a constant, `TitleScreen.START_TEXT`, which the glyph test fills with each area's name. No arrows (N10) |
| Z9 | **The title must still fit, and each tap land on the button.** The main page is a 300 × 360 box with 16 px between its children, and one more 48 px button makes it 376 px tall. A button sized to its text would be 182 px wide for the City and 238 px for Meadows (P3), so a thumb near its edge would miss after a tap | `ui/title_screen.tscn`:27–42 (`MainPage`'s offsets and separation), :55–60 (Play); P3 | `custom_minimum_size` 240 × 48, the longest text's width and the other buttons' height. The box grows both ways from the centre, and fits 360 × 640 with each area's text (E6, N9) |

---

## 3. Decisions and open questions

The owner may answer each question, or accept its default. Until then, the defaults apply, and the prototype follows them.

| # | Question | Default | Alternatives |
|---|---|---|---|
| Q1 | What does the choice look like? | One button under Play, "Start in: City", that steps to the next area on each tap and wraps after the Desert: 4 taps at most, no new screen and no popup (Z7, Z9) | A "Start in" screen, one button per area, like the Atlas: a tap more and a screen's code and tests. An `OptionButton`: rejected by Z7, and its items are too small to tap (P3) |
| Q2 | Which builds show it? | Debug builds, like the game-over seed (Z4): CI's APK and AAB, desktop runs and GUT. Not the Pages build, nor any release | Also the Pages build, with `?area=<id>` read through `JavaScriptBridge` (M4 Q6's alternative); M4 Q6's patched copy keeps working meanwhile. Or every build: a player feature, which changes `plan.md` |
| Q3 | Does the save record the runs that the choice starts? | Yes, as it records `--area`'s (Z5) | Don't record a run that doesn't start in the schedule's first area: a flag for `SaveService.record_run`, and tests for the Atlas and the collection |
| Q4 | Can a run start before an area's set piece, to check the tunnel or the bridge? | No: `starting_at` leaves out the set piece that leads in (K10). The tunnel comes about 56 s into a City run, and the bridge about 125 s into a Rural one (M4 P2) | Two more steps, "Start in: Tunnel" and "Start in: Bridge", which start a few tiles before the set piece. They need a schedule that starts with a set piece, which `validate()` rejects now (§9) |
| Q5 | Does the choice last after the game closes? | No. Each launch starts with the City, or with `--area`'s area. While the game runs, Retry and the title keep it (Z6) | Keep it in the save's settings: a `SaveData` field, its migration and tests |
| Q6 | Does the title also choose the seed, or switch the autopilot on? | No (§9). A run's seed shows on game over in debug builds (J19), and `--seed=<n> --area=<id>` replays it on a desktop (Z6) | A seed field, or an "Autopilot" toggle, also in debug builds only |

---

## 4. Work breakdown

ZS is small: one implementation PR, after this plan's PR. Branches and commits follow `AGENTS.md` §5:

| PR | Branch | Base | What |
|---|---|---|---|
| Plan | `zs/plan` | `main` | This document only: #60, merged as fba6034 |
| 1 | `zs/1-start-area` | `main`, since #60 had landed (§4.5); planned on `zs/plan` | The Start button, the world for every area, and their tests (§5) |

### 4.1 Porting from the prototype

`zs/prototype` has one commit, d4300a8, on 1047e17. PR 1's branch takes its difference:

```bash
git fetch origin main zs/plan zs/prototype
git switch -c zs/1-start-area origin/zs/plan
git diff 1047e17 origin/zs/prototype | git apply --index    # 10 files; the plan isn't one
git commit    # ui: choose the start area on the title in debug builds (ZS PR 1)
```

If `main` has moved, merge it into `zs/plan` first and apply with `--3way`; then run §6.1's checks again, since the counts may change. PR 1 also adds `AGENTS.md` §6's line (E9, §5.5), which the prototype doesn't need.

As it happened, #60 had landed as fba6034 when PR 1 began. That commit's parent is 1047e17, and it adds only this plan, so PR 1's branch started from `origin/main`, and the difference applied as it is, without `--3way`.

### PR 1: The title chooses the start area in debug builds **Δ M4 Q6; Z1–Z9**

| Area | Files | What |
|---|---|---|
| Road | `road/road_generator.gd` | `first_area()`: the area of path tile 0, the schedule's first (Z3) |
| World | `world/prop_scatter.gd` | `bind()` sets `_first_area` from the bound road; `_init` no longer does (Z3) |
| Main | `ui/main.gd` | `_whole_schedule` and `_schedule`; the world and the title get the whole one; `_ready` presets the title's area; `_play` applies the choice (Z2, Z6) |
| Title | `ui/title_screen.gd`, `ui/title_screen.tscn` | `START_TEXT`, `area_choice`, `start_area`, the `%StartArea` button and `_on_start_pressed()`; `open()` shows it (Z4, Z7–Z9) |
| Areas | `areas/area_schedule.gd` | `starting_at()`'s comment names the button too; no code changes |
| Tests | `tests/unit/test_title_screen.gd`, `tests/integration/test_area_start.gd`, `tests/unit/test_prop_scatter.gd`, `tests/unit/test_smoke.gd` | 7 new tests, and the glyph test's texts (§5.4) |
| Docs | `AGENTS.md` | §6: the Start button for each area's device checks (§5.5) |

Steps:
1. Port the prototype (§4.1) and add `AGENTS.md`'s line.
2. Run §6.1's checks; expect its counts.
3. Run §6.2's negative cases on the head; each must fail the tests it names.
4. Have a model of another family review the diff (`AGENTS.md` §7), and fix what it finds, each fix with a test and a negative case.
5. Open the PR, with the body of `AGENTS.md` §6, and the device commands of §7.
6. Check the Web build of a dispatch run with `upload-builds`: it's a release export, so its title must look as `main`'s does (§6.4).
7. Watch Copilot's reviews with `tools/agent/watch_pr.sh` (`AGENTS.md` §8, §9).

Expected: 142 scripts loaded; 65 test scripts, 480 tests, 422,822 asserts; `smoke.sh` prints `main`'s lines (§6.1). After the review's fix (§4.6, 3), 422,823 asserts.

Acceptance: E1–E7 and E9 on the PR, and E8 by the owner (§7).

### 4.5 Landing

1. The owner squash-merges the plan PR into `main`.
2. PR 1 then merges `main`, as `AGENTS.md` §5's update says, and its base becomes `main`, unless GitHub retargets it. Retarget it before deleting `zs/plan`: deleting a merged PR's base closes the PRs on it (ROADGEN_PLAN.md:195).
3. The owner squash-merges PR 1 after its checks and the E8 device check.

Until the plan PR lands, PR 1 doesn't change this plan, so the merge of `main` has no add/add conflict (`AGENTS.md` §5): the plan's status and §4.6 change on `zs/plan`, and merge up into PR 1. After that they change on PR 1's branch, which can carry the final sync, as M2's PR 4 did.

As it happened, the owner merged #60 before PR 1 began, so steps 1 and 2 were done: PR 1 started from `main`, targets it, and carries this plan's sync.

### 4.6 Review fixes

| # | Review | Finding | Fix |
|---|---|---|---|
| 1 | Internal review by gpt-6.1-sol (`AGENTS.md` §7) of this plan and d4300a8 | E8 expected each legend "within about 9 s", but P4 timed seeds 1–10 only. Decoys put the legend off: the Desert's seed 2277 has 5 before its first turn, at path tile 42 | Confirmed: that run's legend ends 17.3 s after Play. P4 now gives how often each area's runs start with a decoy, and times each area's worst seed of 1–3000; E8 and §7 give the times as a guide, not a limit. The generator doesn't change, so each seed keeps its road (Z6). No code changed |
| 2 | Internal review by gpt-6.1-sol of PR 1's f0ace53 | `test_area_start.gd`'s `_prop_sheets()` took each sprite's own `visible`, so a hidden World or Props layer still showed the area's props (E4) | Confirmed: N13, `_show_title()` hiding World, which no run from the title shows again, failed no test. The helper now takes `is_visible_in_tree()` (6d9dd2b), and N13 fails E3's test and `--area`'s preset test |
| 3 | The same review | `test_the_title_page_fits_a_portrait_screen_with_each_start_area` compared the button's width with its current minimum, so a minimum fitted to each text, which Z9 rules out, passed (E6) | Confirmed: N14, `open()` setting the minimum width to the text's, failed no test. The test now also checks that the button has one width for every area (6d9dd2b), and N14 fails it. One more assert |

---

## 5. Design

### 5.1 The title's Start button (Z1, Z4, Z7–Z9)

`ui/title_screen.tscn` gets a `Button`, `StartArea`, right after `Play` in `MainPage`: `unique_name_in_owner`, hidden, `custom_minimum_size` 240 × 48, centred (`size_flags_horizontal` 4) like the other buttons. A hidden child of a `VBoxContainer` takes no room, so release builds lay the title out as `main` does.

`ui/title_screen.gd`:

```gdscript
## The Start button's text, with the area's name.
const START_TEXT := "Start in: %s"

## Whether the title shows the Start button: in debug builds only, like the game-over screen's seed
## (M3_PLAN.md J19; ZONE_SELECT_PLAN.md Z4). Tests change it.
var area_choice := OS.is_debug_build()
## The area that Play starts the run in, with area_choice. main.gd sets it first; open() makes it
## the schedule's first area if it isn't one of the schedule's.
var start_area: AreaDef

@onready var _start: Button = %StartArea

func open() -> void:
	...  # as now, then:
	var areas := schedule.areas()
	if not areas.has(start_area):
		start_area = areas[0]
	_start.text = START_TEXT % start_area.display_name
	_start.visible = area_choice
	...  # show, and Play takes the focus as now

## The next area of the schedule, and after the last, the first.
func _on_start_pressed() -> void:
	var areas := schedule.areas()
	start_area = areas[(areas.find(start_area) + 1) % areas.size()]
	_start.text = START_TEXT % start_area.display_name
```

- **Order.** `AreaSchedule.areas()` lists each area once, in the order a run reaches them (`area_schedule.gd`:48): the Atlas's order too. A schedule with more areas gets more steps, and E6's test checks each one's text.
- **Identity.** `starting_at()` shares the schedule's `AreaDef`s (`test_area_schedule.gd`:276, `assert_same`), so `areas().has(start_area)` holds for `--area`'s area, and `find()` gives its index.
- **Focus.** `open()` gives Play the focus, as now, so Enter on a keyboard plays. Once tapped, the Start button may keep the focus, and Enter then steps it, as any focused button does. The tests tap Play.
- **Input.** It's a plain `Button`: the title's existing handling of Esc and Android's back (`TitleScreen.go_back()`, M5 L13) doesn't change, and a tap on it never emits `play_requested` (E2).

### 5.2 Main's schedules (Z2, Z6)

`ui/main.gd` keeps two schedules:

```gdscript
## The game's schedule. The world, the Atlas and the collection show all of its areas.
var _whole_schedule: AreaSchedule
## The run's: the game's, or a copy that starts in --area's area or the title's choice.
var _schedule: AreaSchedule
```

`_ready` loads `_whole_schedule`, sets `_schedule` from `--area` as now, builds the world from `_whole_schedule` (Z2), and gives the title `_whole_schedule` and `start_area = _schedule.areas()[0]`. `_play` applies the choice before the run starts:

```gdscript
	_title.close()
	if _title.area_choice:
		_schedule = _whole_schedule.starting_at(_title.start_area.id)
	_start_run(_parse_seed(args))
```

| Path | The run's schedule | The Start button |
|---|---|---|
| Launch | The whole one | "Start in: City" (debug builds) |
| Launch with `--area=<id>` | `starting_at(id)` | "Start in: " and that area: Play without a tap does what `main` does |
| Play, debug | `_whole_schedule.starting_at(choice)` | Hidden with the title |
| Play, release | As now: the whole one, or `--area`'s (N5) | Never shown |
| Retry | The last run's (`_retry` doesn't change) | — |
| Game over → Title | — | The last choice |
| `--play`, `--autopilot` | As now: no title, so no choice | — |

- **The City.** `starting_at(&"city")` copies the whole schedule's entries with the same turns and set pieces (`test_area_schedule.gd`:276–311), so a debug Play that never touches the button draws `main`'s road for each seed.
- **Why the gate.** In release builds `start_area` stays `_schedule.areas()[0]`, so applying it there would change nothing either. The `if` keeps the release path exactly `main`'s, and N5 shows the test that holds it.
- **Seeds.** `_parse_seed(args)` doesn't change: a forced `--seed` stays, and otherwise each run gets a new random seed (M2 H28).

### 5.3 The world for every area (Z2, Z3)

With the world built from the whole schedule, `WorldRenderer` makes the road tileset's sources, the grounds and the scatter's props for every area, as it does with no `--area` now (`world_renderer.gd`:71–84). Building it took 1 ms in `smoke.sh` both before and after.

`PropScatter.bind(buffer)` sets `_first_area = buffer.generator.first_area().id`. `RoadGenerator.first_area()` returns `_schedule.entries[0].area`: the area of path tile 0, since a schedule starts at turn 0 (`AreaSchedule.validate()`, `area_schedule.gd`:19–20). The scatter's props per area are still made once, in `_init`. A retry binds a new buffer, which sets the area again: the same, since Retry keeps the schedule.

### 5.4 Tests

| Test | Checks | Finding |
|---|---|---|
| `test_title_screen.gd`: `test_the_start_button_shows_in_debug_builds_only` | `area_choice` defaults to `OS.is_debug_build()`; `open()` shows the button with it and hides it without; the text names the schedule's first area; Play keeps the focus | Z4 |
| `test_title_screen.gd`: `test_the_start_button_steps_through_the_areas_and_open_keeps_the_last` | 6 taps step Rural, Meadows, Village, Desert, City, Rural; no `play_requested`; `close()` and `open()` keep the choice; an `AreaDef` that the schedule lacks becomes the City | Z1, Z6 |
| `test_title_screen.gd`: `test_the_title_page_fits_a_portrait_screen_with_each_start_area` | At 360 × 640, with each area chosen and a long best, every visible control is on screen, and the button keeps one width, its minimum of 240 px, which no text widens | Z9 |
| `test_area_start.gd`: `test_the_title_starts_the_runs_in_the_chosen_area_as_the_area_argument_does` | Taps, as a phone sends them, choose the Desert and play. The car, `GameState.area_id` and the banner say Desert, and only the Desert's props show. Retry keeps the area and the forced seed's road. After game over the title keeps the choice, and one more tap then starts in the City, with the City's props. The Desert's road equals `--seed=1 --area=desert`'s | Z2, Z3, Z6 |
| `test_area_start.gd`: `test_the_area_argument_presets_the_choice_and_the_world_has_every_area` | `--area=village` shows "Start in: Village"; two taps reach the City, whose run has the City's banner and props | Z2, Z6 |
| `test_area_start.gd`: `test_a_hidden_start_button_leaves_the_run_to_the_area_argument` | With `area_choice` false and a choice left from before, Enter plays in the City, or in the Village with `--area=village` | Z4, Z6 |
| `test_prop_scatter.gd`: `test_the_rows_below_the_start_show_the_area_the_road_starts_in` | A scatter of the whole schedule, bound to a City road and then a Desert one, shows what a scatter of the Desert's schedule alone shows | Z3 |
| `test_smoke.gd`: `test_main_scene_text_has_every_glyph_in_the_default_font` | Also `START_TEXT` with each area's name | Z8 |

The integration tests open the main scene without `--play` (`MainScene.open(self, args, false)`), set `area_choice` to true, as a debug build has it, and tap the buttons' centres with touch events. `_prop_sheets()` lists the textures of the sprites on World's Props layer that are visible in the tree, so a hidden World or layer shows none: each area's props have their own sheet (`assets/<area>/props.png`).

### 5.5 Documents and comments

- `ui/main.gd`'s header: a phone can't take the user arguments, so in debug builds the title's Start button chooses the area, which `--area` presets.
- `ui/title_screen.gd`'s header: the Start button, and why it isn't a dropdown (Z7).
- `world/prop_scatter.gd`'s header and `_first_area`; `areas/area_schedule.gd`'s `starting_at()`; `tests/integration/test_area_start.gd`'s header.
- `AGENTS.md` §6, after the owner's APK commands: "In debug builds, the title's Start button chooses the area that Play starts in, so a device can check each area without `--area` (ZONE_SELECT_PLAN.md)."

---

## 6. Verification

### 6.1 Checks and counts

Run from the repository root with Godot 4.7.2 (`AGENTS.md` §4), on `main`, on the prototype and on PR 1's code (6d9dd2b; the commits after it change only documents):

| Check | `main` (1047e17) | Prototype (d4300a8) | PR 1 (6d9dd2b) |
|---|---|---|---|
| `lint.sh` | Exit 0 (shellcheck skipped) | Exit 0 | Exit 0, with shellcheck 0.9.0 |
| `import.sh` | Exit 0 | Exit 0 | Exit 0 |
| `check_scripts.sh` | 142 scripts loaded | 142 (no new scripts, so no new `.uid` files) | 142 |
| `run_tests.sh` | 65 scripts, 473 tests, 422,730 asserts, 86.8 s | 65 scripts, 480 tests, 422,822 asserts, 94.3 s | 65 scripts, 480 tests, 422,823 asserts (§4.6, 3), 63.5 s |
| `smoke.sh` | `grey box: tilesets built in 1 ms`; `autopilot: tile 165, turns 35, area rural` | The same | The same autopilot line; `tilesets built in 0 ms`, which varies by machine |
| `git status --porcelain` | Empty | Empty | Empty |

Per script on the prototype: `test_title_screen.gd` 9 tests (+3), 198 asserts; `test_area_start.gd` 9 tests (+3), 56 asserts, 4.9 s; `test_prop_scatter.gd` 8 tests (+1); `test_smoke.gd` 3 tests (one changed). PR 1 has the same tests, and one more assert in `test_title_screen.gd`. GUT's time varies by several seconds from run to run.

### 6.2 Negative cases

Each case changes the prototype for a moment, runs the whole suite, and must fail the tests named; every other test must pass. A script, not committed, applies each change, runs GUT on all 65 scripts and restores the file. On d4300a8, all 12 failed exactly the tests below, and no others, and so they did on PR 1's f0ace53. N13 and N14 come from PR 1's review (§4.6): on f0ace53 they failed no test. On 6d9dd2b, which makes the two tests stricter, all 14 failed exactly the tests below.

| # | Change | Tests that fail |
|---|---|---|
| N1 | Z3 undone: `_init` sets `_first_area` from the schedule, and `bind()` doesn't | `test_prop_scatter.gd`: `test_the_rows_below_the_start_show_the_area_the_road_starts_in`; `test_area_start.gd`: `test_the_title_starts_the_runs_in_the_chosen_area_as_the_area_argument_does` |
| N2 | `bind()` sets `_first_area` only the first time | The same as N1 |
| N3 | Z2 undone: `_world.build(_schedule)` | `test_area_start.gd`: `test_the_area_argument_presets_the_choice_and_the_world_has_every_area` |
| N4 | `_play` ignores the choice | `test_area_start.gd`: `test_the_title_starts_the_runs_in_the_chosen_area_as_the_area_argument_does`, `test_the_area_argument_presets_the_choice_and_the_world_has_every_area` |
| N5 | `_play` applies the choice with the button hidden (`if true:`) | `test_area_start.gd`: `test_a_hidden_start_button_leaves_the_run_to_the_area_argument` |
| N6 | `open()` shows the button in every build | `test_title_screen.gd`: `test_the_start_button_shows_in_debug_builds_only`; `test_area_start.gd`: `test_a_hidden_start_button_leaves_the_run_to_the_area_argument` |
| N7 | `_retry` starts again from the whole schedule | `test_area_start.gd`: `test_the_area_argument_starts_every_run_in_that_area` (K10's), `test_the_title_starts_the_runs_in_the_chosen_area_as_the_area_argument_does` |
| N8 | `--area` doesn't preset the choice | `test_area_start.gd`: `test_the_area_argument_presets_the_choice_and_the_world_has_every_area` |
| N9 | The button's minimum width is 160, the other buttons' | `test_title_screen.gd`: `test_the_title_page_fits_a_portrait_screen_with_each_start_area` |
| N10 | `START_TEXT` has an arrow, "Start in → %s" | `test_smoke.gd`: `test_main_scene_text_has_every_glyph_in_the_default_font`; and, since the text itself changes, the 5 tests that compare it: `test_title_screen.gd`'s 3 new ones, and `test_area_start.gd`: `test_the_title_starts_the_runs_in_the_chosen_area_as_the_area_argument_does`, `test_the_area_argument_presets_the_choice_and_the_world_has_every_area` |
| N11 | The steps stop at the Desert instead of wrapping (`mini(find + 1, size - 1)`) | `test_title_screen.gd`: `test_the_start_button_steps_through_the_areas_and_open_keeps_the_last`; `test_area_start.gd`: `test_the_title_starts_the_runs_in_the_chosen_area_as_the_area_argument_does`, `test_the_area_argument_presets_the_choice_and_the_world_has_every_area` |
| N12 | `open()` always resets the choice to the first area | The same as N11 |
| N13 | `_show_title()` hides World, and no run from the title shows it again (§4.6, 2) | `test_area_start.gd`: `test_the_title_starts_the_runs_in_the_chosen_area_as_the_area_argument_does`, `test_the_area_argument_presets_the_choice_and_the_world_has_every_area` |
| N14 | `open()` sets the button's minimum width to its text's: `_start.custom_minimum_size.x = _start.get_minimum_size().x` (§4.6, 3) | `test_title_screen.gd`: `test_the_title_page_fits_a_portrait_screen_with_each_start_area` |

### 6.3 Editor warnings

The editor warns about more than CI does (M2 §6.3). A temporary `override.cfg` in the project root, which Godot reads at start, raised the 37 `debug/gdscript/warnings/*` settings at level 1 (warn) to 2 (error), and `check_scripts.sh` ran on `main` and on the prototype. Both reported the same 5: `INTEGER_DIVISION` in `world/greybox_atlas.gd`, `ui/main.gd`, `tests/unit/test_greybox_atlas.gd` and `tests/unit/test_iso.gd`, and `UNUSED_VARIABLE` (`junctions`) in `tests/unit/test_road_generator_occupancy.gd`. None is on a line that PR 1 changes. With those two warnings left at 1, both trees loaded all 142 scripts with none. The file was then removed. PR 1's f0ace53 and 6d9dd2b gave the same 5, at the same lines (`ui/main.gd`:52, `main`'s :46), and none with those two at 1.

### 6.4 Verified only in CI or on devices

- **CI.** The five required checks on PR 1's head, with §6.1's counts; `test`'s time. The dispatch run 43352712023 of 6d9dd2b passed them all: `test` took 2 min 15 s, with 142 scripts, 480 tests, 422,823 asserts and `main`'s smoke line.
- **The release default** (E1). GUT runs a debug build, so `OS.is_debug_build()` is never false there. CI's Web build is a release export (`ci.yml`:76): from a dispatch run with `upload-builds`, serve it with `python3 -m http.server` and open it in Chrome and Firefox with Playwright under Xvfb, as #28 did. Its title must show Play, Atlas, Disasters and Settings and no Start button, laid out as `main`'s build lays them out: compare screenshots of both at 360 × 640. Done for PR 1 with dispatch run 43352712023 of 6d9dd2b, against `main`'s run 43293662593 of 1047e17. In Chrome 157 and Firefox 159, the title showed the four buttons and no Start button, and its screenshot matched `main`'s in every pixel. Enter played a City run in both builds. The consoles had no errors. Chrome logged its 4 `GPU stall due to ReadPixels` notes for both builds and, for PR 1's only, a `CONTEXT_LOST_WEBGL` before Godot started, as M4's builds did in 5 of 9 sessions on software GL (M4_PLAN.md:730). Firefox logged its deprecation of WebAssembly's `try` for both.
- **The debug APK** (E8). CI exports it as debug (`ci.yml`:113), so the button shows. The owner checks it on the Fold4 (§7).
- **Touch.** The integration tests tap with touch events at the buttons' centres, as `MainScene.push()` sends them; a finger's tap and the phone's hit areas need the device.

### 6.5 Measurements

| # | Question | Result |
|---|---|---|
| P1 | Does Android's back button close a dropdown's popup on the title? | No. In a probe on the title with an `OptionButton`'s popup open, the back notification reached `main`, which emitted `quit_requested` once; the popup stayed open. In Godot 4.7.2, back sends the window's go-back request and `Key.BACK` (`android_input_handler.cpp`:135–139); the gesture path sends only the request (`java_godot_lib_jni.cpp`:284). `_propagate_window_notification` skips child windows (`window.cpp`:827–836, :913–915), and a popup closes on `ui_cancel`, which is Escape (`popup.cpp`:44–47, `input_map.cpp`:469–471). The Settings screen's Orientation popup is safe: back closes the screen, and the popup hides with it |
| P2 | Does the title fit with one more button? | `MainPage`'s minimum height becomes about 376 px, over its 360 px rect; the box grows both ways from the centre, and on 360 × 640 every control stays on screen (E6's test) |
| P3 | How wide is each text, in Pixel Operator 8 at 16 px, the theme's? | The buttons' minimum widths, with the style's 16 px of margins: Play 68, Atlas 80, Settings 120, Disasters 136; "Start in: City" 182, "…Rural" 198, "…Meadows" 238, "…Village" 218, "…Desert" 214. An `OptionButton`'s items are 21.6 px tall |
| P4 | How soon does each area's legend show, with no input? | A throwaway test started each area from the title and let the car drive straight, so the legend plays at the first junction that turns. With seeds 1–10, that junction came 2.4–5.0 s after Play, and the legend played 3.0–3.6 s more: 5.5–8.6 s in all. City (Phantom Bus): 2.5–4.2 s, then 3.1–3.4 s; Rural (UFO): 2.4–3.8, 3.3–3.6; Meadows (Fairy Ring): 2.4–4.2, 3.1–3.4; Village (Witch's Hex): 2.5–4.1, 3.0–3.3; Desert (Death Worm): 2.4–5.0, 3.1–3.5. A decoy puts it off: the car goes straight on, the right way there, and the turn waits for the next junction (`road/road_generator.gd`:116, :130–133). Over seeds 1–3000, a decoy came first in 0 %, 10 %, 16 %, 15 % and 19 % of the runs that start in the City, Rural, the Meadows, the Village and the Desert, as their `decoy_chance` gives (`areas/area_def.gd`:24, `rural.tres`:31, `meadows.tres`:30, `village.tres`:29, `desert.tres`:30). The most decoys first, and those runs' times in all: Rural 2 (seed 64, 11.2 s), Village 3 (seed 659, 12.2 s), Meadows 4 (seed 1918, 13.8 s), Desert 5 (seed 2277, 17.3 s; its first turn is path tile 42). Each area's pool holds its legend only (`areas/city.tres`:28 and the others). The autopilot reaches the Desert in 397 s (M4 P2) |

---

## 7. Owner actions

1. **Answer Q1–Q6** in the plan PR, or let the defaults stand (§3).
2. **Merge the plan PR**, then PR 1 when its checks and E8 pass (§4.5).
3. **Check PR 1 on the Fold4** (E8). The agent posts PR 1's dispatch run; then:

   ```bash
   gh workflow run ci.yml -R pompomon/roadgame --ref zs/1-start-area -f upload-builds=true
   gh run list -R pompomon/roadgame --workflow ci.yml --branch zs/1-start-area -L 1   # the run's id
   gh run download <run-id> -R pompomon/roadgame -n "android-Android APK" -D /tmp/roadgame-apk
   adb install -r /tmp/roadgame-apk/roadgame-debug.apk
   ```

   On the title, on the cover screen and the inner one:
   - [ ] "Start in: City" shows under Play, as wide as "Start in: Meadows", and each tap steps Rural, Meadows, Village, Desert, City.
   - [ ] For each area: Play starts there. The banner names it; the road, the ground and the props are that area's, also behind the car; its music and ambience play. With no input, the run ends in its legend at the first junction that turns: the Phantom Bus, the UFO, the Fairy Ring, the Witch's Hex, the Death Worm. That's mostly within 9 s; a run whose first junctions are decoys, where straight on is right, takes longer (P4).
   - [ ] Retry starts in the same area; Title shows the same choice.
   - [ ] Android's back button: on the title it still quits; in a run it pauses, as before.
4. **Optional: empty the save** after the checks: `adb shell pm clear com.pompomon.roadgame` (Z5, Q3).

---

## 8. Risks

| Risk | Effect | Mitigation |
|---|---|---|
| A release build shows the button | Players can start anywhere, and their Atlas and collection fill early | `OS.is_debug_build()` (Z4), as the game-over seed has done since M3; the release Web check (§6.4). `release.yml` exports release builds only |
| Testers' saves hold runs that started in later areas | The Atlas and the collection on a test phone don't show a player's progress | Q3's default keeps it simple; empty the save after the checks (§7) |
| The focus stays on the Start button after a tap | Enter steps the area instead of playing, on a desktop keyboard in debug builds | `open()` gives Play the focus each time; Enter as such is ordinary button behaviour |
| A later area gets a longer name | Its text doesn't fit 240 px, and the button grows | E6's test runs each area of the game's schedule, and fails on a wider button (N9) |
| A later PR builds the world from the run's schedule again | Chosen runs fall back silently to the first area's art, with no error | N3's test; `ui/main.gd`'s comment on Z2 |
| `main` moves before PR 1 | The diff doesn't apply, or the counts change | §4.1: merge `main` and apply with `--3way`; run §6.1 again |

---

## 9. Notes for later work

- **M7.5's device checklist** (IP :456) can use the button: each area's art on the cover and inner screens, fold and unfold in each, and each legend's haptics.
- **The Web on a phone.** The Pages build is a release, so it has no button. Checking an area there still needs M4 Q6's patched copy, or Q2's `?area=` alternative.
- **Set pieces** (Q4). Starting before the tunnel or the bridge needs a schedule whose first entry has a set piece. Today `starting_at()` drops it, and `validate()` rejects it (`areas/area_schedule.gd`:21–22).
- **A seed and the autopilot** (Q6). If the owner wants them on the phone, they fit the same debug-only row: a second button, and `main.gd`'s `_parse_seed()` or `_autopilot` taking the title's value.
- **IP and `plan.md`** don't change (Precedence): the option exists only in debug builds.
