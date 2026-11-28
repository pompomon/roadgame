# Performance: 40–50 fps in the Browser

Done, 2026-11-21 to 2026-11-28: the plan PR #124, then four stacked PRs, #126 (PR 1) to #129 (PR 4). The plan called the work PF. Settings → Show FPS shows the frame rate on any build; the lamps batch, and hide while no glow is in view; the scatter hides at most two rows a frame; the Web build and the APK aim at 60 fps; and the game renders at its own resolution, which the screen scales up. The full plan: `git show 8df84ee:PERF_PLAN.md`; the tag `archive/pf/prototype` keeps the prototype's commits that it cites.

## 1. Goal and exit criteria

40–50 fps in a browser, as the owner asked, in the real scenes, those a run reaches: the City and the Village by day, and Rural, the Meadows and the Desert at night (docs/SPEEDUP.md E3), with neither the simulation nor the look at a scale of 1 changed (E4). E2–E4, E7 and E8 are met, and E6 on the Web; E1 in part; E5 on the Fold4 and the APK's E6 weren't recorded (§6.6).

- **E1.** Real devices decide (Q1). In Chrome on both of the Fold4's screens, and in a desktop browser with a GPU, its page at 1280×720 and a pixel ratio of 1 (Y10), each real scene reads at least 50 fps and a P95 of at most 25 ms in each of 10 readings in a row. So does a whole run's approach to its end, in each reading but its first, and each way in, in the 6 readings before it and the 2 after; but the way into the City home, and a run's end in each reading but its first until the game-over screen, need only 40 fps, with any P95 (Q12, Y11).
- **E2.** The software proxy (Q1): each PR's build against PR 1's, in the same session, in the VM's Firefox and Chrome at 360×640 and 60 Hz, at pixel ratios of 1 and 2, each case by the unrounded mean of two runs, or, where that fails a check, of four (§6.5). On PR 4, Firefox at both ratios runs each real scene, the approach and each way in at 50 fps or more, and the City at night, the way into the City home and each end at 40; Chrome at 2 runs each scene faster than on PR 1; and no PR runs a scene more than 1 fps slower than PR 1.
- **E3.** Hitches (Y4). The scatter hides at most 2 freed rows a frame. In the proxy's Firefox, in the City by day, no frame from 7 s to 12 s takes over 25 ms in either of 2 runs, where on PR 2's head one does in each (`tools/perf/hitch.mjs`).
- **E4.** At a scale of 1, no PR changes a pixel of a desktop run's frames (Q6; `tools/perf/movie.sh`).
- **E5.** At a scale of 2 or 3 (Q2), the art and the text keep their pixels, and what moves steps by the game's pixel (§5.5); the owner compares both stretches on the Fold4.
- **E6.** Pacing (Y5, Q3). The Web build and the APK aim at 60 fps. In the proxy's Firefox at 120 Hz, the City by day and the Meadows at night run at 60 ± 1 fps with at most 2 early frames a second, and the City at night at most 1 fps under its uncapped rate; at 60 Hz, the cap changes the City by day by at most 1 fps. On the Fold4, the APK reads 60 ± 1 fps and a P95 of at most 20 ms in 10 readings in play on each screen, each with the refresh rate that Developer options → Show refresh rate shows.
- **E7.** The docs: §5.8 and this summary.
- **E8.** CI's checks pass on each PR, and each negative case fails its tests.

## 2. Findings

- **Y1.** Every frame rate in the docs came from VMs that draw in software, none from a GPU or the Fold4, and software's costs aren't a GPU's (P3).
- **Y2.** The `canvas_items` stretch draws every layer and group buffer at the screen's pixels: at a pixel ratio of 2, Firefox fell from 58.7–59 fps to 24.4–34.4 (P10). PR 4 fixed it.
- **Y3.** `Lamps` held a `Sprite2D` for each silhouette and glow, with alternating textures: 204 draw calls at night in the City (P4), and a screen-sized buffer filled with no glow in view. PR 2 fixed it.
- **Y4.** The scatter's first free, about 8 s in, hid 21 rows in one frame, a long one in Firefox (P13b). PR 3 fixed it.
- **Y5.** The game steps at 60 Hz, so a 120 Hz screen draws each step twice, or unevenly: uncapped in Firefox at 120 Hz, the City by day drew 83.9–86.1 fps (P18). PR 3 fixed it.
- **Y6.** Nothing showed the frame rate on the Pages build or the APK, which take no arguments. PR 1 fixed it.
- **Y7.** docs/agents/checks.md gave stale software frame rates. PR 5 fixed it.
- **Y8.** For about 6 s after a run starts, rows are made while the props' pools are empty, at up to 21 ms a row (P13). Not fixed (§9).
- **Y9.** `Lamps.add()` and `remove()` moved a child, at a cost that grows with the children: steady rows cost 3–8 ms in Chrome (P13). PR 2 orders the items by draw index (§5.2).
- **Y10.** A desktop window of 1280×720 shows a 1137×640 view at a scale of 1, at zoom 2: Firefox ran it at 29.5–38.7 fps with every lever. Not fixed (Q10, §9).
- **Y11.** The City at night is a stress case: only `--hour` shows it, but for about 2.3 s after a banner the light eases from the last zone's, as into the City home.
- **Y12–Y14** needed no change: headless runs draw nothing, so GUT checks the work's counts and the browsers its time; scripts are cheap (P4); and rendering straight to the screen fails with `CanvasGroup`s.

## 3. Decisions

The owner approved Q1–Q12's defaults by merging #124.

- **Q1.** E1's device readings decide. The VM's Firefox is the agents' proxy, and Chrome's SwiftShader only a relative check.
- **Q2.** The `viewport` stretch everywhere (§5.5).
- **Q3.** A cap at `MAX_FPS`, 60, on the Web and Android. On the Web it is a target by whole refreshes, not a ceiling: 72 fps at 144 Hz (§5.4).
- **Q4.** The Pages build reads `?fps`, `?stretch=` and `?fpscap=` (§5.1), and no other query, so `?area=` stays off it (docs/ZONE_SELECT.md Q2).
- **Q5.** Every player has Settings → Show FPS, off by default (§5.1).
- **Q6.** The lamps as RenderingServer items, culled (§5.2).
- **Q7.** At most 2 freed rows hidden a frame (§5.3); the first 6 s' rows stay (Y8).
- **Q8.** The owner reads the APK by playing it, with Show FPS.
- **Q9.** Agents land PRs 1–3, the owner PRs 4 and 5.
- **Q10.** A desktop window at a scale of 1 stays as it is (Y10).
- **Q11.** The prototype built the levers as switches of a probe; PRs 2–4 wrote the final code and its tests.
- **Q12.** A run's ends need 40 fps, not 50, as the player doesn't steer then.

## 4. Work breakdown

- **PR 1** (#126): `FrameStats`, `FrameCounter`, `ViewSwitches`, Show FPS (§5.1), and `tools/perf/` (§6.5).
- **PR 2** (#127): the lamps as RenderingServer items, culled (§5.2).
- **PR 3** (#128): two rows hidden a frame (§5.3), and `FramePacing`'s cap (§5.4).
- **PR 4** (#129): the `viewport` stretch (§5.5).
- **PR 5**: this summary, CI's checks of `tools/perf/` and of leaked RIDs, and PF's learnings.

### 4.2 Landing

Agents landed PRs 1–3 with `tools/agent/land_pr.sh`. The owner had PR 4 merge after reading the Fold4 (§6.6), and lands PR 5, which changes the owner's paths.

## 5. Design

### 5.1 The counter and the switches

- **`FrameStats`** (`ui/frame_stats.gd`), a pure `RefCounted`, times frames between `_process()` starts by `Time.get_ticks_usec()`, as Godot smooths `delta`, in windows of `FPS_WINDOW_SECONDS`, 1 s: `fps()`, the nearest-rank `p95_ms()`, and `early()`, the frames under `FPS_EARLY_MS`, 12.5 ms.
- **`FrameCounter`** (`ui/frame_counter.gd`), a `CanvasLayer` that runs while paused, shows "60.0 FPS" over "P95 17 MS" at the bottom right, clear of the HUD's `Info`, while the setting `"fps"` is on or the switch `fps` is given. It rounds the rate away from 60 and the P95 up, so that a reading meets E1's and E6's bounds only if its window does (N24). With the switch it prints a line a window, `PERF fps=… n=… us=… med=… p95=… max=… early=… draws=…`, and `EVENT` lines with the frames drawn, which `tools/perf/` reads.
- **`ViewSwitches`** (`ui/view_switches.gd`) reads `--fps`, `--stretch=` and `--fpscap=`, or else `?fps`, `?stretch=` and `?fpscap=` from the page's query, once, at startup (Q4).
- **The setting** `"fps": false` is in `SaveData.DEFAULT_SETTINGS`, so saves stay at version 5.

### 5.2 The lamps

`Lamps` stays one `CanvasGroup` over the veil (docs/DAYNIGHT.md §5.12), but holds RenderingServer canvas items, not nodes (Y3):
- **An item a prop that stands or has lights** draws a standing prop's silhouette in black, with a child item for each glow at its sprite's transform: the 2D snap puts them on the sprites' pixels at any zoom, where rects of the silhouette's item could land a pixel off at a fractional one.
- **One texture per atlas**, the glow with the props' art below it from `ATLAS_Y`, 64, so that the items batch: in E2's runs of the City at night, a frame's draw calls, sampled once a window, averaged 45.54–48.93 a run on PR 2's build, against 201.62–212.23 on PR 1's.
- **Draw-index keys** keep Props' y-sort order (Y9): a new key is its neighbours' midpoint, or `KEY_GAP` past an end, and all are spread again when none fits or one would pass `KEY_MOST`. Keys never repeat, as Godot's sort is unstable, and `Lamps` has no node children.
- **Redraws.** `show_frame()` redraws a silhouette when its frame changes (N7), and `fade()` sets its `modulate`. Rects aren't polygons, so redraws raise no WebGL error (docs/M2.md §5.7; P16).
- **Freeing.** At `NOTIFICATION_PREDELETE`, `Lamps` frees every item it made (N8).
- **The cull.** The group shows only while the lamps are on and the rect around some prop's glows meets the viewport's, grown by `LAMP_CULL_MARGIN_PX`, 2, for the snaps (N19).

### 5.3 Two rows a frame

`_on_tiles_freed()` only raises `_hide_below` to the buffer's first tile. Each `update()` then hides at most `HIDE_ROWS_PER_FRAME`, 2, rows from `_lowest_row` before it shows rows: the first free's 21 rows go in 11 frames, out of view. `bind()` hides the last run's rows at once, and keeps rows −20 to −1, which may be in view, until the buffer frees tile 0 (N10); each row keeps `Row.anchor`, as its path tile may be gone.

### 5.4 The cap

`FramePacing.cap()` (`ui/frame_pacing.gd`) gives `MAX_FPS`, 60, on the Web and Android and 0 elsewhere, unless the switch `fpscap` gives a whole number, 0 for none. `apply()` sets `Engine.max_fps`, but on the Web, where Godot's limiter paces by its own clock (P15), installs `GATE_JS`. The gate wraps `requestAnimationFrame` for Emscripten's main loop, fits the refresh interval, r ms, to the last `GATE_STEPS`, 30, steps between its timestamps, and runs the game every n refreshes, n = max(1, floor(`GATE_MARGIN` × 1000 ÷ r ÷ cap)), which moves only past `GATE_HYSTERESIS`:

| Refresh (Hz) | 60 | 75 | 90 | 120 | 144 | 165 | 240 |
|---|---|---|---|---|---|---|---|
| Frame rate | 60 | 75 | 90 | 60 | 72 | 82.5 | 60 |

`window.__framePacing` shows the refresh, n and the frames skipped. `tools/perf/test_gate.mjs` runs `GATE_JS` against simulated refreshes, jitter, loads and switches (P17).

### 5.5 The viewport stretch

`project.godot` sets `window/stretch/mode="viewport"`, with `expand` and integer scaling as before: the game draws its view at the view's pixels and scales the frame to the screen, where `canvas_items` drew it at the screen's. At a scale of 1 nothing changes (E4). At 2 or 3, what moves steps by the game's pixel, and the edges of the glows, the veil and the headlights' cone are drawn at the view's resolution. `StretchSwitch.mode()` (`ui/stretch_switch.gd`) reads the switch `stretch`, and `main.gd` applies it at startup.

### 5.7 The Fold4: what to expect

Estimates, as no GPU had timed this game (Y1):

| Build and screen | Expected |
|---|---|
| Chrome, cover, portrait | 60, steady: a median of 55–60, a P95 of 20 ms or less |
| Chrome, cover, landscape | About 50–60: PR 4 changes nothing at a scale of 1, so only PRs 2 and 3 help |
| Chrome, inner | 60, steady: a median of 55 or more, a P95 of 20 ms or less |
| The APK, any screen | 60 ± 1, a P95 of 20 ms or less (E6) |

Red flags: a real scene under 55 fps, or a P95 over 25 ms. A run's first 6 s (Y8), its ends and the way into the City home may read lower. With the cap at 120 Hz, the counter counts the game's 60 frames, where the browser's meters may count 120.

### 5.8 Docs

PR 2 changed docs/VISUALS.md and docs/M2.md for the items. PR 5 changed `plan.md`, IP's M0.1 and M7, docs/VISUALS.md's E8, docs/agents/checks.md and `AGENTS.md`; CI's `lint` job runs `tools/perf/`'s Node tests and shellcheck, and `run_tests.sh` fails on leaked RIDs (N8, N15).

## 6. Verification

### 6.2 Negative cases

Those that the code and CI cite:
- **N7.** A `show_frame()` that doesn't redraw fails `test_lamps.gd`.
- **N8.** Without the free at `NOTIFICATION_PREDELETE`, `test_freeing_the_lamps_frees_their_items` fails. Godot itself only warns at exit, `WARNING: 2 RIDs of type "CanvasItem" were leaked.`, on which `run_tests.sh` fails since PR 5.
- **N10.** `_hide_below` from 0 at `bind()` fails `test_rows_below_0_stay_while_the_buffer_holds_tile_0`.
- **N15.** With a scratch test that leaves one canvas item unfreed, or two, for the warning's singular and plural forms, `run_tests.sh` exits 1, and 0 without its leak check.
- **N19.** The cull without its margin fails `test_lamps.gd`: a glow just past the view's edge must show the group.
- **N24.** The counter rounded to the nearest fails `test_frame_counter.gd`: about 49.99 fps would read 50.0.

### 6.5 Measurements

`tools/perf/measure.mjs` runs release exports in a VM's Chrome (SwiftShader) and Firefox (llvmpipe), headed under Xvfb (docs/agents/checks.md §4): each run starts a scene with `--fps`, waits 6 s and records 15 s of `PERF` lines. `events.mjs` times the ends and ways in, and `hitch.mjs` E3's frames; the three fail on WebGL's errors, which the browsers log as warnings. `movie.sh` records E4's frames on the desktop. The prototype, at 695a61b, measured:

- **P3.** SwiftShader: an empty frame takes 8.5 ms, and each `CanvasGroup` 9–11 ms more.
- **P4.** The main thread takes 3–9 ms a frame on `main`, and 2–4 with every lever; its scripts 0.2–2.5 ms. The City at night in Chrome: 204 draw calls and 6.82 ms to issue them; with the prototype's lamps, 45 and 3.06 ms.
- **P10.** Every lever, Firefox at a pixel ratio of 2: the real scenes from 24.4–34.4 fps to 52.8–58.4. Chrome at 2: each 1.9–2.9 times as fast, but 17.9–22.3 fps.
- **P13.** The rows' work: the first free's 21 rows took 31–38 ms in Chrome, and 1.2–2.4 ms a frame with the budget. Rows made with empty pools: 6–9 ms a row in Chrome and 6–21 in Firefox; later rows 3–8 ms.
- **P13b.** Firefox's frame at the first free: 33.4–34.8 ms; with the budget, none over 25 ms from 7 s to 12 s.
- **P15.** In Firefox at 120 Hz, Godot's limiter put 1.2–5.73 frames a second off the 16.7 ms cadence.
- **P16.** Neither the items' redraws nor the gate raised a browser warning.
- **P17.** The gate in simulation (§5.4).
- **P18.** The gate in Firefox at 120 Hz: 59.89–59.97 fps, against 77.1–86.1 uncapped.

### 6.6 Results

On the PRs' builds:
- **E2.** Every floor and comparison passed, without extra runs. On PR 4 in Firefox at a pixel ratio of 2, the closest to their floors were Rural at night, 50.26 fps, and the City at night, 40.13; home into the City ran at 44.98 and each end at 47.61 or more. Chrome at 2 ran each scene 1.93–2.75 times as fast as on PR 1, and no PR ran a scene more than 0.55 fps slower than PR 1.
- **E3.** By the page's frame intervals, PR 2's longest, 34.30 and 34.32 ms, came at the first free, and PR 3's were 17.82 and 17.84 ms; an earlier pair on the same source had one of 33.56 ms, at 10.7 s.
- **E4.** Every frame compared was identical.
- **E6.** In Firefox at 120 Hz, uncapped and capped: the City by day 82.48 and 59.90 fps, with 1.69 early frames a second; the Meadows at night 95.66 and 59.94; the City at night 53.28 and 52.42. At 60 Hz, the cap changed the City by day by under 0.001 fps in Firefox, and 0.19 in Chrome.
- **On the Fold4,** the owner read 58 fps in the City and 59–60 elsewhere, with a P95 of 22 ms on straights and up to 30 ms on turns, naming no screen, browser or build (#129). That meets E1's 50 fps, and its 25 ms but on turns; as the APK's, it would miss E6. E1 on a desktop GPU and E5 on the Fold4 weren't recorded; [#129's screenshots](https://github.com/pompomon/roadgame/pull/129#issuecomment-7088832306) compare both stretches in the proxy's Chrome.

## 7. Owner actions

None but landing PR 5, then tagging `pf/prototype` as `archive/pf/prototype` and deleting PF's branches, with the commands in PR 5's body. What E1, E5 and E6 still lack moved to M7 (§9).

## 8. Risks

- **The proxy isn't a phone** (Y1): its numbers and §5.7's are estimates, and the prototype's sessions differed by up to 3.8 fps, so a change of a few fps can cross a floor.
- **The gate** relies on Emscripten's main loop calling `window.requestAnimationFrame` each frame. After a Godot upgrade or a custom shell, run P18's case again.
- **Android's pacing.** `Engine.max_fps` may pace 120 Hz unevenly, as on the Web (P15). If the APK's P95 stays over 20 ms, `cap()` can give 0 on Android, once the owner changes E6.
- **Software rendering on a desktop.** Chrome without a GPU, or with one on its blocklist, draws with SwiftShader, as slowly as P10 shows: out of E1's scope (Q1), but a "low" setting would help (§9).

## 9. Notes for later

IP §4 M7 carries these:
- **Device QA,** by Show FPS: the readings that E1, E5 and E6 lack (§6.6), §5.7 saying what to expect; E1 again after 10 minutes' play, for heat, and a profile of the turns.
- **The world in a `SubViewport`** at its art's resolution, with the UI at the window's (Q10, Y10): 48.3–58.9 fps in Firefox at 1280×720. It changes how the camera, the HUD and the touch zones map to the screen: a plan of its own.
- **A "low" setting** for software rendering (Q1, §8): the shadows without their group, and the night without the lamps' group and the veil, which changes the look.
- **Physics interpolation** (Q3): 120 distinct frames at 120 Hz, at twice the GPU's work.
- **The pools filled while a run loads** (Y8, Q7).
