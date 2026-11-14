# Zone Selection: Choosing the Start Area on a Phone

Done on 2026-11-13: the plan PR #60 and PR 1, #61. The plan called the work ZS, and zones *areas*. In debug builds, the title's Start button chooses the area that Play starts in, so a device can check each area without `--area`. Play starts the run there as `--area=<id>` does, Retry and the title keep the choice, and release builds show nothing new. The world holds every area's art. The full plan, with its verification, negative cases and review history: `git show 08f316f:ZONE_SELECT_PLAN.md`.

## 1. Goal and exit criteria

Goal: start a run in any area on a phone. Only `--area=<id>` (`docs/M4.md K10`) did that, and a phone can't pass it (Z1): without it the Desert is 397 s of right turns away. ZS replaces `docs/M4.md Q6`'s way of checking each area on the Fold4, a patched Web build in the phone's Chrome. IP and `plan.md` don't change, since players never see the option (Z4). #61 met the exit criteria E1–E9 but E8, the check on the Fold4 (§7).

## 2. Findings

- **Z1.** A phone can't choose an area: neither the APK nor the Web build takes user arguments such as `--area` (`docs/M4.md P4`). In debug builds, a Start button on the title chooses it (§5.1).
- **Z2.** The world was built once, from the run's schedule: after `--area=village`, a City run from the title would draw the City's road with the Village's sheet and ground, and no props, with no error. `_ready` builds it from the whole schedule (§5.2).
- **Z3.** `PropScatter` gave the rows below path tile 0 its schedule's first area, so a Desert run from the title would show City props behind the car. `bind()` takes the area from the bound road, `RoadGenerator.first_area()` (§5.3).
- **Z4.** Players mustn't see it: a run starts in the City (`plan.md`:26). `area_choice := OS.is_debug_build()`, like the game-over seed (`docs/M3.md J19`): CI's debug APK and AAB show the button; the Pages build and every release hide it.
- **Z5.** The save records chosen runs in the bests, the Atlas and the collection, as it does `--area`'s. Kept (Q3): a debug build's save is the tester's own.
- **Z6.** The choice must fit every path that starts a run: Play applies it, Retry keeps it, the title shows the last one, `--area` presets it, and `--play` and `--autopilot` never see it (§5.2). A chosen run with seed n draws `--seed=n --area=<id>`'s road, so it replays on a desktop.
- **Z7.** A dropdown would let Android's back button quit the game: in Godot 4.7.2 back's go-back request skips the popup's window, which closes only on Escape, so `main.go_back()` quits from the title (`docs/M5.md L13`). Its 21.6 px items are too small to tap too. So the choice is a button that steps (Q1).
- **Z8.** The text must use the font's glyphs, as the Web has no fallback font. "Start in: %s" is `TitleScreen.START_TEXT`, which the glyph test fills with each area's name. No arrows.
- **Z9.** The title must fit 360 × 640, and each tap land on the button: sized to its text, it would be 182 px wide for the City and 238 px for Meadows. Its `custom_minimum_size` is 240 × 48, so it keeps one width; `MainPage` grows to about 376 px tall and still fits.

## 3. Decisions

No answers came, so the defaults apply.

- **Q1.** The form: one button under Play that steps through the areas and wraps after the Desert. No screen, no popup (Z7, Z9).
- **Q2.** The builds: debug only (Z4). Not the Pages build, with `?area=` read through `JavaScriptBridge` (§9), nor every build.
- **Q3.** Record chosen runs in the save: yes (Z5).
- **Q4.** Start before a set piece: no. `starting_at()` leaves out the set piece that leads in (§9).
- **Q5.** Keep the choice after the game closes: no. While it runs, Retry and the title keep it.
- **Q6.** Choose the seed or the autopilot too: no (§9). Debug builds show the seed on game over, and `--seed=<n> --area=<id>` replays it.

## 4. Work breakdown

- **Plan** (#60): this plan.
- **PR 1** (#61): the Start button, `RoadGenerator.first_area()`, `PropScatter.bind()` taking the start area, `main.gd`'s two schedules, 7 new tests (§5.4), the comments and a line in `AGENTS.md` (§5.5).

## 5. Design

### 5.1 The title's Start button (Z1, Z4, Z7–Z9)

`ui/title_screen.tscn` has `%StartArea`, a hidden 240 × 48 `Button` after `Play` in `MainPage`; hidden, it takes no room, so release builds lay the title out as before. `open()` makes `start_area`, which `main.gd` sets first, the schedule's first area if `schedule.areas()` lacks it, shows the button with `area_choice`, and gives Play the focus, so Enter plays. `_on_start_pressed()` steps to the next of `schedule.areas()`, in the order a run reaches them, and after the last to the first; it never emits `play_requested`. `starting_at()` shares the schedule's `AreaDef`s, so `--area`'s area is among them.

### 5.2 Main's schedules (Z2, Z6)

`ui/main.gd` keeps `_whole_schedule`, the game's, for the world, the Atlas and the collection, and `_schedule`, the run's: the whole one, or a `starting_at()` copy for `--area` or the title's choice. `_ready` sets `_schedule` from `--area`, builds the world from `_whole_schedule`, and presets the title's `start_area` to `_schedule.areas()[0]`. `_play` sets `_schedule = _whole_schedule.starting_at(_title.start_area.id)` only if `_title.area_choice`, so release builds play as before. `_retry` keeps the run's schedule, and a forced `--seed` (`docs/M2.md H28`). `starting_at(&"city")` keeps every entry, so a debug Play that never touches the button draws the same road for each seed. `_tutorial_wanted()`, added later, gives the tutorial only to a run that starts in the City, however chosen (`docs/TUTORIAL.md §5.6`).

### 5.3 The world for every area (Z2, Z3)

Built from the whole schedule, `WorldRenderer` makes the road tileset's sources, the grounds and the props of every area, as it did with no `--area`, in 1 ms. `PropScatter.bind(buffer)` sets `_first_area` from `buffer.generator.first_area()`, which returns `_schedule.entries[0].area`, path tile 0's area, and `_show_row()` uses it for the `BUFFER_BEHIND` rows below the start. The props of each area are still made once, in `_init`.

### 5.4 Tests

Three tests in `test_title_screen.gd` (Z4, Z9 and the steps), three in `test_area_start.gd` (Z2–Z4, Z6) and one in `test_prop_scatter.gd` (Z3); `test_smoke.gd`'s glyph test fills `START_TEXT` with each area's name (Z8). The integration tests open the main scene on its title, set `area_choice` to true, tap with touch events, and check the props by their sheet, `assets/<area>/props.png`, on the sprites visible in the tree.

### 5.5 Documents and comments

The headers of `ui/main.gd` and `ui/title_screen.gd` explain the button, and `docs/agents/checks.md` §4 has device checks use it for each area.

## 6. Verification

#61 passed the five checks with Godot 4.7.2: 142 scripts loaded; 65 test scripts, 480 tests, 422,823 asserts; `smoke.sh`'s line unchanged. Its 14 negative cases each failed the tests they name. GUT runs a debug build, so the release default (Z4) was checked in CI's release Web build: in Chrome and Firefox its title had no Start button and matched `main`'s in every pixel.

## 7. Owner actions

- **E8 on the Fold4**, not recorded as done. With CI's debug APK (`docs/agents/checks.md` §4), on both screens: the button keeps one width and steps through the areas. A run from each area has its banner, road, ground, props (also behind the car), music and ambience, and with no input ends in its legend at the first junction that turns: mostly 5.5–8.6 s after Play, up to 17.3 s after decoys. Retry and Title keep the area; back still quits from the title. A fresh save's City run starts with the tutorial, which has no disasters: finish it first.
- **Optional:** empty the save after, `adb shell pm clear com.pompomon.roadgame` (Z5); the tutorial comes back.

## 9. Notes for later

- **M7.5's device checklist** (IP M7.5) can use the button: each area's art on both screens, a fold in each, and each legend's haptics.
- **The Web on a phone.** The Pages build is a release, with no button: an area there still needs `docs/M4.md Q6`'s patched copy, or Q2's `?area=`, which nothing reads yet.
- **Set pieces** (Q4). A start just before the tunnel or the bridge needs a first entry with a set piece, which `starting_at()` drops and `AreaSchedule.validate()` rejects.
- **A seed and the autopilot** (Q6) would fit the same debug-only row: another button, read by `ui/main.gd`'s `_parse_seed()` or `_autopilot`.
