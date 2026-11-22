# Performance: 40–50 fps in the Browser — Detailed Plan

Status: proposed. Written in autopilot mode, so each question of §3 holds its default; merging this plan's PR approves it with them · 2026-11-21 · Scope: the frame rate and frame pacing of the Web build and the APK, on the reference phone and on desktops, with a counter to read them. No change to gameplay, and none to the look but how a screen at a scale of 2 or more draws moving sprites (E4, E5)

The owner asked: "Explore the codebase and create a detailed implementation plan for performance optimisation - make sure the game is able to run on 40-50 fps in browser. Also in the summary provide a reference expectations of the phone fps for Fold4 for me to compare. Ask clarifying questions if needed". The clarifying questions are §3's Q1–Q12, each with a default, which this plan follows, and an alternative. §5.7 gives the Fold4's expected frame rates to compare with, and how to read them.

**What happens.** No one has read the game's frame rate on a GPU: the docs' come from agents' VMs, whose browsers draw in software, and the owner waived the Fold4's reading on #121 (Y1). In this plan's VM, 2 vCPUs of an AMD EPYC 9V74 and no GPU, `main` at e73f96d runs at 360×640 at 24.5–36.3 fps by day and 13.9–23.8 at night in Chrome, which draws with SwiftShader, and at 57.8–59 and 49.6–59 in Firefox, which draws with llvmpipe (P1).

The time goes to filling pixels (Y2, Y3; P2–P4). The `canvas_items` stretch (`project.godot`:29) draws each layer, and each `CanvasGroup`'s buffer, at the screen's full resolution: at a device pixel ratio of 2, Firefox falls from 59 fps to 24–34 (P10), and the Fold4's inner screen draws 9 times its view's pixels. The lamps cost draw calls: 204 at night in the City, of which the prototype's removed 159 (P4). And the scatter's first free, about 8 s into each run, hides 21 rows in one frame: Firefox draws a frame of 33–35 ms there (P13b).

**What PF does.** Five PRs after this plan's. PR 1 adds a frame counter, Settings → Show FPS, `--fps` and `?fps`, and the scripts that measure a build in Chrome and Firefox, and changes nothing else, so the owner can read `main`'s frame rate on the Pages build first. PR 2 draws the lamps' silhouettes and glows as RenderingServer items in one texture per atlas, so they batch, and hides the lamps' group while no glow is in view. PR 3 hides at most two rows a frame, and caps the Web build and the APK at 60 fps, so that a 120 Hz screen doesn't draw each of the game's 60 steps a second twice. PR 4 renders at the game's own resolution, the `viewport` stretch, and lets the screen scale the frame up, as pixel art allows. PRs 1–3 change no pixel, and PR 4 none at a scale of 1 (E4; P12, P14). PR 5 replaces this plan with `docs/PERF.md`.

With all four on the prototype, Firefox at 360×640 and a pixel ratio of 2 runs every real scene at 52.8–58.4 fps, against 24.4–34.4 on the same build without them, and a run's ends, a legend or the arrival, at 48.6–58.6, against 24.1–38.2 (P20); and in Chrome none runs slower, and each runs 1.9–2.9 times as fast at a pixel ratio of 2 (P10, P19). A desktop window at a scale of 1 gains little in software, but a GPU should fill its 1137×640 pixels easily; E1 reads the frame rate at that size (Y10, Q10).

**Verified locally.** The levers were built as switches of a probe on `pf/prototype`, from `main` at e73f96d, which never gets a PR (§4.1): `--pf-lamps=rs,cull` for PR 2, `--pf-hide-budget=2` and `--pf-gate=60`, or `--pf-maxfps=60` off the Web, for PR 3, and `--pf-stretch=viewport` for PR 4. They are off by default, so the prototype's five checks match `main`'s; the suite also ran with each lever on, which shows what each PR's tests must change (§6.1). Q11 says what the prototype left to the PRs, against docs/agents/planning.md §2.

- Godot 4.7.2-stable (4.7.2.stable.official.ed1daf0bf), as in CI
- GUT 9.7.1
- gdtoolkit 4.5.0 on Python 3.12, as in CI's `lint` job, and shellcheck 0.9.0
- Playwright 1.66.0-alpha-2026-11-09, driving Google Chrome 157.0.8103.78 and Playwright's Firefox 159.0, headed under Xvfb (docs/agents/checks.md §4)

**Precedence.** For PF, this document replaces `plan.md` :199 (the `canvas_items` stretch) and :373 (performance isn't a blocker; the informal 60 fps); IP :111 (M0.1's `canvas_items` stretch) and :203 (how to read the Fold4's frame rate); docs/agents/checks.md :64 (the software frame rates, and "Judge the frame rate only on the Fold4"); and docs/VISUALS.md E8 (:9), which reads the Fold4's frame rate without holding a PR for it. Elsewhere, IP and the docs rule.

**Reference code.** `pf/prototype`'s head, 29ea230: PR 2's lamps in `world/lamps.gd`; PR 3's budget in `world/prop_scatter.gd`, and its gate, `GATE_JS`, in the probe, `autoload/pf_probe.gd`, whose overlay PR 1's counter follows; and the scripts in `tools/pf/`, which PRs 1 and 3 move to `tools/perf/` (§4.1). The levers were measured at c5bfd9f; 6d7ce3f and a08cbe9 hold the gate that the first internal review led to, d7f4d77 the second's (§4.4), and the commits since only the tools that measured them, and the probe's events (P20).

**Prerequisites.** SP has landed, with its docs (#118, #123), so `main` has 60 s days in Rural, the Meadows and the Desert, whose nights E1's scenes use, and HL's headlights (#119–#122). Line numbers are at e73f96d unless a SHA is given beside them, and Godot's are at its 4.7.2-stable tag.

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

Goal: the game runs smoothly in a browser, and can show that it does. In every real scene, at 50 fps or more, with no frame over 25 ms but rare ones, the owner's 40–50 with a margin, in Chrome on the reference phone and in a desktop browser with a GPU; and the APK at a steady 60. A counter in Settings shows the frame rate on any build. The real scenes are those a run reaches: the City and the Village by day, as their 120 s days end before the night, and Rural, the Meadows and the Desert at night, 32.5 s into a zone (docs/SPEEDUP.md E3). The City at night, with `--hour=20`, is the stress case (Y11). A run's ends, a legend after a wrong or missed turn and the arrival at the pier, which last seconds, run at 40 or more (Q12).

| # | Exit criterion | Checked by |
|---|---|---|
| E1 | Real devices (Y1, Y2; Q1). In Chrome on the Fold4, on both screens, and in a desktop browser with a GPU, its page 1280×720 at a pixel ratio of 1 (Y10), the counter (PR 1) shows at least 50 fps and a P95 of at most 25 ms in each of 10 readings in a row, one a second, in each real scene. On PR 4's CI build, served from the owner's computer before it lands, §7's URL starts each by the autopilot at its hour, and the readings start 6 s later. Against `main`'s, read by play on Pages after PR 1 lands: the City and the Village from 6 s into their zone, and Rural, the Meadows and the Desert within their night, 32.5 to 53.75 s into the zone (docs/SPEEDUP.md §5.3; §5.7). The ends, on PR 4's build: a legend in the City by day and one in Rural at night, and the arrival approached at night, show at least 40 fps in each reading after the first that shows once the run has ended, until the game-over screen; an end with no such reading is read again (Q12) | The owner, §7's template; §6.4 |
| E2 | The software proxy (Y1, Y2; Q1). In this VM's Firefox and Chrome (SwiftShader), at 360×640 and 60 Hz, at pixel ratios of 1 and 2, each PR's build runs against PR 1's, `main` with the counter, in the same session, in the five real scenes and the City at night. E2's floors, on PR 4's head: in Firefox, at both ratios, each real scene runs at 50 fps or more, and the City at night and each end at 40 or more; in Chrome, at a pixel ratio of 2, each scene runs faster than on PR 1's build. E2's comparison, on each of PRs 2–4: no scene runs more than 1 fps slower than on PR 1's build, in the same browser at the same ratio. A run's rate is the game's frames over their time in the counter's `PERF` windows within its record, 15 s from 6 s after its start (`tools/perf/measure.mjs`), and a case's the mean of two runs; where that fails a check, each build runs the case twice more in the session, and the four runs' mean decides. The ends, which count only for Firefox's floor, are `tools/perf/ends.json`'s 17 cases: the 15 legends, each after a wrong or missed turn at its area's first junction, in its real scene's light, and the arrival with every legend, approached by day and at night; there, a run's rate is the game's frames from `run_ended` to the game-over screen, by their `EVENT` lines' counts, over the time between them (`events.mjs`), and a case's as above. In P10 and P20, the prototype with every lever met these floors, and in P10 the comparison against itself without them, but by the page's frames with Godot's limiter, one or two runs a case | §6.5 |
| E3 | Hitches (Y4; Q7). The scatter hides at most `HIDE_ROWS_PER_FRAME`, 2, of the rows that frees release a frame, each within §5.3's bound, where frees overlap too; `bind()` hides the last run's at once. In the proxy's Firefox at 360×640, the City by day, no frame from 7 s to 12 s after the engine's first line, which holds the run's first free, takes over 25 ms, in each of 2 runs, while on PR 2's head, in the same session, one does in each (P13b) | `test_prop_scatter.gd` (PR 3); `tools/perf/hitch.mjs`, §6.5 |
| E4 | No pixel changes at a scale of 1 (Q6). With the counter hidden, PRs 1, 2 and 3 change no pixel of 720 frames of a desktop run at 360×640, in the City at night and the Meadows by day and at night; nor PR 2 in a 1280×720 window's view, 1137×640 at zoom 2 (Y10), recorded at that size (PR 1's `movie.sh`), by day and at night, and in an arrival at the pier at night there, `--finish=<turns>` with `--hour=20`, whose zoom eases from 2 to 1 as the lamps fade (§5.2); and PR 4 none at 360×640, where both stretches render the same | Movie Maker and `tools/perf/diff_frames.py`, §6.5 |
| E5 | The look at a scale of 2 or 3 (Q2). With the `viewport` stretch, the art keeps its pixels and the text its glyphs; moving sprites step by the game's pixel, ½ an art pixel at zoom 2 and 1 at zoom 1, not by the screen's (§5.5). The owner compares both stretches on both of the Fold4's screens with `?stretch=` | The owner, §7; screenshots at a pixel ratio of 2, §6.4 |
| E6 | Pacing (Y5; Q3). The Web build and the APK aim at `MAX_FPS`, 60. The APK caps with `Engine.max_fps`. The Web runs the engine's frames at most once every n refreshes, with n the largest that keeps 60 ÷ 1.05, 57 fps, or more, then kept down to 56: 60 at 120 and 240 Hz, 72 at 144, 82.5 at 165, and every refresh at 90 Hz or less, once it has read the screen's refresh (§5.4). Headless runs, GUT, `smoke.sh` and Movie Maker don't cap. In the proxy's Firefox at 120 Hz, by the counter's `PERF` lines, each the mean of 2 runs, the City by day and the Meadows at night run at 60 ± 1 fps, with at most 2 frames a second `early`, a refresh after the last; the City at night, which can't hold 60, at most 1 fps under its uncapped rate; and at 60 Hz the City by day changes by at most 1 fps in either browser (P18). `--fpscap=` and `?fpscap=` change the cap, and 0 lifts it. On the Fold4, the APK reads 60 ± 1 fps with a P95 of 20 ms or less in 10 readings in play on each screen, each with the refresh that Developer options → Show refresh rate shows; readings at 60 Hz leave §8's 120 Hz risk untested, as it doesn't arise there | `test_frame_pacing.gd` and `tools/perf/test_gate.mjs` (PR 3); §6.5; the owner on the Fold4 |
| E7 | Docs: PR 5's `docs/PERF.md` and §5.8's Δs | Review |
| E8 | All four required checks are green on each PR, with §4's counts, and `smoke.sh` prints no error line. Each negative case makes the tests it names fail (§6.2), the warnings check finds only `main`'s warnings (§6.3), and GUT reports no warning | PR checks; §6.2, §6.3 |

---

## 2. Review findings

Each finding's evidence is a measurement of §6.5 (P#) or a cited line; the prototype checked each fix (§6.1, §6.5).

- **High:** the game misses the goal, or no one can tell whether it meets it.
- **Medium:** it costs frames or smoothness in some scenes, or misleads.
- **Low:** checked, and needs no change.

### High

- **Y1. The docs' frame rates are software rendering's, and no GPU has been read.** Every frame rate in the docs was measured in a VM without a GPU: Chrome's 24.5 and 13 fps (docs/VISUALS.md P18), the Meadows' 32.3 and 24.1 (docs/HEADLIGHTS.md P9) and checks.md :64's 49 and 21, now stale (Y7). SwiftShader's costs aren't a GPU's: 8.5 ms for an empty frame, and 9–11 ms more for each `CanvasGroup` (P3); a GPU should fill one far faster, but none was timed. Firefox's llvmpipe is 2–3 times faster, but still a CPU. The Fold4 was never read: VISUALS's E8 recorded no reading (docs/VISUALS.md :143), and the owner waived HL's (#121). **Fix:** PR 1's counter, which reads any build on any device; E1 on the Fold4 and a desktop GPU, read by the owner (§5.7); E2 on Firefox as the agents' proxy, with Chrome's SwiftShader as a relative check only (Q1).
- **Y2. The `canvas_items` stretch draws every layer at the screen's resolution.** `project.godot`:29–31 stretch `canvas_items` with `expand` and integer scaling, so the 2D canvas draws at the window's own pixels, and each layer and each group's buffer fills the screen's (window.cpp :1407–1412). At a pixel ratio of 2, Firefox at 360×640 falls from 58.7–59 fps to 24.4–34.4 in the real scenes, and Chrome from 22.4–32.2 to 7.5–11.5 (P10). On the Fold4, the cover screen draws 720×1844 pixels for a 360×922 view, and the inner one 1596×1920 for 532×640 (docs/M2.md :157–164): 4 and 9 times the art's pixels. The art needs none of them, being pixel art at integer zooms, with nearest filtering (`project.godot`:78) and a pixel font without antialiasing (`assets/fonts/pixel_operator_8.tres`). **Fix:** PR 4, the `viewport` stretch, which renders the game's own size and scales it up (window.cpp :1414–1424), with a switch to compare (Q2).
- **Y3. The lamps cost draw calls, and a group that shows nothing.** `Lamps` holds a `Sprite2D` silhouette for each standing prop and a `Sprite2D` for each of its glows (`world/lamps.gd`:55–75, :122–137), with the props' textures and the glow's, which alternate, so nothing batches: 204 draw calls at night in the City, against 45 with the prototype's lamps, and 6.82 ms of Chrome's main thread to issue them, against 3.06 (P4). And `refresh()` shows the group whenever the light is below day's (:94–98), so at night it fills a screen-sized buffer even when no glow is in view, as on Rural's open road. **Fix:** PR 2 draws each silhouette as a RenderingServer canvas item, and each of its glows as a child item, from one texture per atlas, which holds the atlas and the glow, so they batch, and hides the group while no glow is in view. The prototype's lamps changed no pixel at 360×640 (P12; Q6).
- **Y4. Freeing rows makes hitches.** `PropScatter._on_tiles_freed()` hides every freed row in one frame (`world/prop_scatter.gd`:164–168). The first free comes about 8 s into a run, as the car reaches path tile 21, and hides 21 rows, rows −20 to 0, in one frame: 27–37 ms of work, at about 1.3–1.7 ms a row. At 360×640, Firefox draws a frame of 33.4–34.8 ms there, in each run (P13b). **Fix:** PR 3 hides at most `HIDE_ROWS_PER_FRAME`, 2, a frame, and the rest in the next frames. In the prototype, Firefox drew no frame over 25 ms from 7 s to 12 s after its start, the longest 17.8 ms (P13b), and no pixel changed (P14), as the rows are out of view (§5.3).

### Medium

- **Y5. A 120 Hz screen draws each step twice, or unevenly.** The game steps at 60 Hz in `_physics_process` (`ui/main.gd`:138, `world/camera_rig.gd`:32, `car/car_controller.gd`:42), and the camera and the car move only there; `project.godot` sets no physics interpolation and no cap. Where the browser calls the game 120 times a second, as on the Fold4's 120 Hz screens, it draws each step twice where the frames are light, for twice the GPU's work, and unevenly where they aren't. In Firefox at 120 Hz, uncapped, the game drew 119.7 fps with every layer hidden; the City by day 83.9–86.1, of which 60–63 frames a second came a refresh, 8.3 ms, after the last; and the Meadows at night 77.1–79.0; each showed 60–61 of its steps a second (P15, P18). **Fix:** PR 3 caps the Web build and the APK at 60 fps (Q3). On the Web, Godot's limiter, `Engine.max_fps`, judges by its clock in each callback, whose jitter paces 120 Hz unevenly (P15), so PR 3 caps with a gate on `requestAnimationFrame`'s timestamps instead (§5.4), which drew 59.89–59.97 fps where the game holds 60 (P18).
- **Y6. Nothing shows the frame rate.** IP :203 asks for an informal reading on the Fold4, with the editor's monitors or an APK exported with `debug/settings/stdout/print_fps`; the Pages build and CI's APK take no arguments (checks.md §4). **Fix:** PR 1's counter and its switches (Q4, Q5).
- **Y7. checks.md :64 is stale.** It gives Chrome 49 and 21 fps, at 360×640 and 1280×720, and Firefox 59 and 55; on `main`, the City by day draws 24.5 and 10.9 in Chrome, and 58.8 and 34.3 in Firefox (P1). **Fix:** PR 5.
- **Y8. The first rows are slow to make.** For about 6 s after a run starts, rows 25–44 are shown while the props' pools are empty, so each sprite is made: 6–9 ms a row in Chrome, and 6–21 ms in Firefox, against 3–8 ms later (P13), and some of Firefox's frames there took up to 34.7 ms (P13b). **Fix:** none in PF; a pool filled while the run loads could take them (§9, Q7).
- **Y9. Each lamp's add and remove moves a child.** `Lamps.add()` and `remove()` call `move_child()` (:74, :84), whose cost grows with the number of children: steady rows cost 3–8 ms in Chrome, mostly there (P13). **Fix:** PR 2 orders the canvas items by draw index, with keys spaced apart (§5.2), so neither moves a node.
- **Y10. A desktop window at a scale of 1 draws the world at zoom 2.** A 16:9 window from 1280×720 up to 2273×1279 shows the game in a box of 1137×640 pixels at a scale of 1, with margins (window.cpp :1342–1401), and the camera picks zoom 2 for it (`world/camera_rig.gd`:106–113). Firefox there runs the real scenes at 29.5–38.7 fps with every lever, against 28.2–39.6 without (P10). A GPU should fill 1137×640 a frame easily; E1 reads the frame rate at that size. **Fix:** none in PF: a "fold" of the zoom into the stretch made Firefox run at 48.3–58.9 (P11), but shrinks the UI (Q10, §9).

### Low

- **Y11. The City at night is a stress case.** The City's, the Village's and the Coast's 120 s days end before their nights (docs/SPEEDUP.md E3), so only `--hour` shows them at night. The heaviest real scenes are the City by day, and Rural, the Meadows and the Desert at night (P1). E1 and E2 measure those, and E2 the City at night as a margin.
- **Y12. Headless runs can't measure rendering.** GUT and `smoke.sh` run with a dummy renderer, so they check the work's counts, such as rows hidden a frame (E3), not its time; the browsers measure the time (`tools/perf/`, §6.5).
- **Y13. Scripts are cheap.** The main thread's `_process` and `_physics_process` take 0.2–2.5 ms a frame in the browsers (P4), and Godot's y-sort of the props costs nothing measurable (P6). No script needs to change for speed.
- **Y14. Rendering straight to the screen isn't a lever.** `viewport_set_render_direct_to_screen` fails with `CanvasGroup`s and back buffers: Godot logs `Condition "rt->direct_to_screen" is true` from `render_target_clear_back_buffer` (P7).

---

## 3. Decisions and open questions

The owner wasn't asked, as the status line says: each question holds the default of the third column, which the prototype and §4–§6 follow. An answer that picks the fourth column changes the PRs that the last column names.

| # | Question | Default | Alternative | Changes |
|---|---|---|---|---|
| Q1 | Where must the game run at 40–50 fps? | **On real devices: in Chrome on the Fold4's two screens and in a desktop browser with a GPU, at 50 fps or more with a P95 of 25 ms or less in each real scene, read by the owner with PR 1's counter (E1). Agents use this VM's Firefox as the proxy (E2), and Chrome's SwiftShader only as a relative check (Y1)** | In software too: Chrome at 40–50 fps on SwiftShader, whose empty frame takes 8.5 ms and each group 9–11 ms more (P3). That needs the shadows and the lamps drawn without their groups, which changes the look: a "low" setting (§9; P2) | E1, E2; a PR 6 |
| Q2 | Does the game render at its own resolution? | **Yes, the `viewport` stretch everywhere (PR 4): at a scale of 1, as at 360×640 or in a 1280×720 window, the same pixels as `canvas_items` (E4); at a scale of 2 or 3, as on the Fold4 and HiDPI desktops, 1/4 or 1/9 of them, scaled up, so the art and the pixel font keep their pixels, while what moves steps by the game's pixel, not the screen's (§5.5). `?stretch=` and `--stretch=` compare the two (E5)** | `canvas_items` as now, and lose PR 4's gains: at 360×640 and a pixel ratio of 2, Firefox with the prototype's lamps ran at 19.5 fps in the City at night, 29.3 by day and 32.9 in the Meadows at night, and with PR 4 too at 42.9, 53.1 and 56.1 (P8). The Fold4's inner screen would keep 9 times the pixels (§5.7) | PR 4 |
| Q3 | Is the frame rate capped? | **At `MAX_FPS`, 60, on the Web and on Android (PR 3), which a screen of 120 Hz or more would otherwise draw at up to its rate (Y5). The car and the camera move only in the game's 60 Hz steps, so the cap halves the GPU's work at 120 Hz and shows them as smoothly. On the Web it is a target by whole refreshes, not a ceiling (E6): a 144 Hz screen draws 72 fps and a 90 Hz one 90, as every third refresh, 48 fps, or every second, 45, would fall under 60 (§5.4)** | A strict ceiling on the Web, every ceil(rate ÷ 60) refreshes: 48 fps at 144 Hz and 55 at 165; Godot's limiter on the Web, with 1.2–5.7 frames a second off the cadence at 120 Hz (P15); no cap; or physics interpolation, which Godot 4.7.2 has in 2D, at 120 fps: smoother on a 120 Hz screen, at twice the GPU's work, and every node that moves would need checking (§9) | PR 3 |
| Q4 | Which switches does the Pages build read? | **`?fps`, `?stretch=` and `?fpscap=`, read once at startup through `JavaScriptBridge`, which change only the view: the owner reads and compares them on the Fold4 without a build (§5.7). ZS Q2 kept `?area=`, which changes the game, off the Pages build (docs/ZONE_SELECT.md :26), and PF reads no other** | Only `?fps`, or no query at all: the counter is in Settings anyway (Q5), and the comparisons need the sed-patched Web build of checks.md §4, served to the phone with `adb reverse` | PRs 1, 3, 4 |
| Q5 | Who sees the counter? | **Every player: Settings → Show FPS, off by default, saved with the settings as `"fps"` without a new save version (§5.1). Its text uses only the font's glyphs** | Debug builds only, and `?fps` on the Web: the owner reads the APK only from a debug build | PR 1 |
| Q6 | How do the lamps get cheaper? | **RenderingServer canvas items, one per lit prop for its silhouette and a child item for each of its glows, from one texture per atlas, so they batch; and the lamps' group hidden while no glow is in view (PR 2; Y3, §5.2). E4 checks that no pixel changes, at 1280×720 too, and in an arrival at night** | The nodes as now, and only the cull: the group's buffer goes where no glow is in view, as on Rural's road, but the 204 draw calls and the 6.82 ms stay (Y3) | PR 2 |
| Q7 | How are hitches handled? | **`HIDE_ROWS_PER_FRAME`, 2: the scatter hides at most 2 freed rows a frame (PR 3; Y4). The rows made in the first 6 s, while the pools are empty (Y8), stay as they are: §9** | One row a frame; or the pools filled while a run loads, before its first frame (§9) | PR 3 |
| Q8 | How does the owner read the APK? | **By playing it, with Settings → Show FPS: the APK takes no arguments (checks.md §4). E1's scenes come by playing: the City by day at the start, and Rural's night from 32.5 s into its zone (Y11)** | A debug-only button that starts the autopilot, as `--autopilot` does on the desktop | PR 1 |
| Q9 | Who lands what? | **Agents land PRs 1–3, once this plan's PR is merged. The owner lands PR 4, after E1, E5 and the APK's checks on its CI build (§7), and PR 5, which changes the owner's paths (§4.2)** | The owner lands every PR, after E1 | §4.2 |
| Q10 | Does a desktop window at a scale of 1 change? | **No: it draws its 1137×640 pixels, which a GPU should fill easily; E1 reads the frame rate at that size (Y10)** | A "fold": the world rendered at its art's resolution in a `SubViewport` of its own, and scaled up by the camera's zoom, which made Firefox at 1280×720 run at 48.3–58.9 fps (P11). It changes how the camera and the UI are laid out (§9) | A PR 6 |
| Q11 | The prototype built the levers as switches of a probe, not as PRs 2–4's files and tests (docs/agents/planning.md §2) | **Accepted: each lever runs, is measured and changes no pixel at 360×640 (§6.1, §6.5; P12, P14), and the suite ran with each on, which tells each PR which tests change (§6.1); §6.1's checks ran with the levers off, as they are by default. PRs 2–4 write the final code and its tests from it (§4.1)** | The prototype rebuilt as PR 2–4's files, with their tests, before the plan | §4.1 |
| Q12 | Must a run's ends run at 50 fps too? | **No: at 40 or more, the owner's lower bound, as the City at night (E1, E2). In game time, a legend ends within 6 s of the turn (`Tuning.DISASTER_TIMEOUT`), and the arrival's screen shows 5 s after the finish (`Tuning.ARRIVAL_SECONDS`), while the player doesn't steer. In the proxy, with every lever, the legends ran at 48.6–58.5 fps, up to 8.2 under their area's drive (P10, P20)** | At 50, as the drive: if E1 reads an end under it, a PR 6 makes the ends cheaper, once a profile finds their cost (P20) | E1, E2; a PR 6 |

---

## 4. Work breakdown

Five PRs after this plan's. PRs 1–4 are a stack, each branched from the one before and based on it; PR 5, the docs, starts from `main` once PR 4 has merged. Each leaves CI green (E8).

```
main
 ──▶ PR 1 the frame counter, and tools/perf/ (E8; Y1, Y6)
      ──▶ PR 2 the lamps as RenderingServer items, culled (E2, E4; Y3, Y9)
           ──▶ PR 3 two rows hidden a frame, and the 60 fps cap (E2–E4, E6; Y4, Y5)
                ──▶ PR 4 the viewport stretch (E1, E2, E4–E6; Y2)
   │
   ▼  once PR 4 has merged, from main
 PR 5 docs, and CI's checks (E7; Y7)
```

Why so:
- **The counter first.** PR 1 changes nothing on screen while the counter is off, so the owner can read `main`'s frame rate on the Pages build, E1's baseline, before any lever lands (§5.7).
- **A lever a PR.** The lamps, the scatter's hides with the main loop's pacing, and the stretch are different code with their own tests; each was measured alone (P8, P10) and can be reverted alone. PR 4 changes the look at a scale of 2 or more, so it comes last, and the owner lands it after E5 (§4.2).
- **Stacked.** PRs 3 and 4 read their switches through PR 1's `ViewSwitches`, and E2's floors measure all four on PR 4's head. No PR changes a file that an earlier one adds, as merging `main` after a squash would make it an add/add conflict (docs/agents/stacks.md): PR 1's `measure.mjs` already records PR 3's gate, and PR 4's switch and its test are files of its own. Each PR's lines in `ui/main.gd`'s `_ready()` stay apart from the others' (stacks.md steps 2, 3): PR 1's after `_autopilot`'s, PR 3's before `_world.build()`, PR 4's before `quit_requested.connect()`.

### 4.1 Porting from the prototype

The prototype built each lever as a switch of a probe (Q11), so no PR is a plain difference: each writes its final code from the prototype's at 29ea230, as §5 describes it, without `PfProbe`, its switches and its timers.

1. Fetch, and create each branch from the one below, PR 1's from `main`:
   ```bash
   git fetch origin main '+refs/heads/pf/*:refs/remotes/origin/pf/*'
   git switch -c pf/1-measure origin/main
   git show 29ea230:world/lamps.gd > /tmp/lamps_proto.gd   # PR 2's source, and so on
   ```
2. **PR 1** writes `FrameStats`, `FrameCounter` and `ViewSwitches` new, after the probe's overlay and report (`autoload/pf_probe.gd`), and moves `tools/pf/`'s `measure.mjs`, `hitch.mjs`, `events.mjs`, `ends.json`, `tab.py`, `diff_frames.py` and `movie.sh` to `tools/perf/`, reading the counter's `PERF` and `EVENT` lines instead of the probe's, and the gate's state as `window.__framePacing` (§5.1, §6.5).
3. **PR 2** keeps `world/lamps.gd`'s `rs` and `cull` paths and drops the `Sprite2D` path; `world/prop_scatter.gd` calls `Lamps.show_frame()` and `Lamps.fade()` (§5.2).
4. **PR 3** takes `world/prop_scatter.gd`'s `_hide_below`, `_hide_rows()` and `Row.anchor`, the probe's `GATE_JS` as `FramePacing`'s, and `tools/pf/sim_gate.mjs` as `tools/perf/test_gate.mjs` (§5.3, §5.4, §5.6).
5. **PR 4** sets `project.godot`:29 and adds `StretchSwitch` (§5.5).
6. For each, run §6.1's checks, §6.3's warnings and its negative cases (§6.2), each in its own worktree with the whole suite, and once more on its head when its reviews are done (docs/agents/planning.md §4); measure it as §6.5 says; then follow `AGENTS.md` §5's loop, with a body that names the tests and the negative cases.

### PR 1: UI: the frame counter, and the tools that measure

Title `ui: a frame counter in Settings, with --fps and ?fps (PF PR 1)`. Branch `pf/1-measure`, from `main`.

| Area | Files |
|---|---|
| UI | `ui/frame_stats.gd`, new: `FrameStats`, a pure `RefCounted` that takes each frame's start and gives a window's frame rate, median, P95, longest frame and early frames (§5.1). `ui/frame_counter.gd` and `.tscn`, new: `FrameCounter`, a `CanvasLayer` over the UI, whose `Label` shows "60 FPS" over "P95 17 MS" at the bottom right, and with the switch prints a `PERF` line a window and `EVENT` lines (§5.1). `ui/view_switches.gd`, new: `ViewSwitches`, which reads a switch from the user arguments or, on the Web, from the page's query (Q4). `ui/main.tscn`: the counter. `ui/main.gd`: the switch `fps` forces it on. `ui/settings_screen.gd` and `.tscn`: Show FPS, a `CheckButton` after `Orientation`, the Screen option, with an `accessibility_name` (`.github/instructions/ui.instructions.md`) |
| Values | `config/tuning.gd`: `FPS_WINDOW_SECONDS`, 1, the counter's window, and `FPS_EARLY_MS`, 12.5, under which a frame is early (§5.1) |
| Save | `autoload/save_data.gd`:16–22: `"fps": false` among the settings. A save without it keeps the default, and `_setting_ok()` takes any bool, so no new version (§5.1, Q5) |
| Tools | `tools/perf/`, new: `measure.mjs`, `hitch.mjs`, `events.mjs`, `ends.json`, `tab.py`, `diff_frames.py` and `movie.sh`, from the prototype's `tools/pf/` (§6.5). `measure.mjs` records the state of PR 3's gate, `window.__framePacing`, where there is one, so PR 3 needn't change it, and takes a run's rate from the `PERF` lines after its record's first, whose window opened before it, until its end, as their frames over their time (E2); `movie.sh` sets the size with a temporary `override.cfg`, as `--resolution` records the view's middle 360×640 (main.cpp :4840–4855), and checks the frames' size (E4); `hitch.mjs` times E3's window by the page's clock at the engine's first line, and fails a run without frames in it; `events.mjs` times E2's ends, `ends.json`'s cases, and counts their frames by the `EVENT` lines, and fails a run with an error line, without its case's legend or arrival, or without `game_over` within 15 s of `run_ended`; a page that stops answering as it waits runs the run again, unless the run has failed |
| Tests | `test_frame_stats.gd`, `test_view_switches.gd` and `test_frame_counter.gd`, new; `test_settings_screen.gd` and `test_save_data.gd` (§5.6) |

Expect, against `main` at e73f96d (§6.1): 6 more scripts loaded, 229, of which 3 are test scripts, 107; about 18 more tests; GUT within `main`'s time, and `main`'s `autopilot:` line, as the counter is off. Negative cases N1–N4, N17, N20 and N23.

**Acceptance:** E8, and the counter for E1.

### PR 2: World: the lamps as RenderingServer items, culled **Δ Y3, Y9**

Title `world: draw the lamps as RenderingServer items, hidden while no glow is in view (PF PR 2)`. Branch `pf/2-lamps`, from `pf/1-measure`.

| Area | Files |
|---|---|
| World | `world/lamps.gd`: each silhouette a canvas item under the group, and each of its glows a child item, from one texture per props atlas, ordered by draw index keys; the group hides while no glow is within `LAMP_CULL_MARGIN_PX` of the view (§5.2). `world/prop_scatter.gd`: frames and fades through `Lamps.show_frame()` and `Lamps.fade()` |
| Values | `config/tuning.gd`: `LAMP_CULL_MARGIN_PX`, 2 (§5.2) |
| Tests | `test_lamps.gd`, and the 4 tests of `test_prop_scatter.gd`, `test_world_renderer.gd` and `test_daylight_run.gd` that read the lamps' nodes (P5; §5.6) |
| Docs | docs/VISUALS.md and docs/M2.md, which describe the lamps' sprites (§5.8) |

Expect: the same scripts; 9 tests in 4 scripts changed, as the suite with `rs,cull` failed them (P5), and about 9 more; the same `autopilot:` line; and the City at night's draw calls, against the prototype's 45 (P4). Negative cases N5–N8, N18 and N19.

**Acceptance:** E2's comparison, E4.

### PR 3: World: two rows hidden a frame, and the 60 fps cap **Δ Y4, Y5**

Title `world: hide two rows a frame, and cap the frame rate at 60 (PF PR 3)`. Branch `pf/3-pacing`, from `pf/2-lamps`.

| Area | Files |
|---|---|
| World | `world/prop_scatter.gd`: a freed row waits in `_hide_below` until it can go, and `update()` hides at most `HIDE_ROWS_PER_FRAME` a frame; `bind()` hides the old run's rows at once; each row keeps its anchor as it shows (§5.3) |
| Pacing | `ui/frame_pacing.gd`, new: `FramePacing`, whose pure `cap()` gives 60 on the Web and Android, 0 elsewhere or what `fpscap` says, and whose `apply()` sets `Engine.max_fps`, or on the Web installs the gate of §5.4, `GATE_JS` with the values below written in (E6). `ui/main.gd`: applies it |
| Values | `config/tuning.gd`: `HIDE_ROWS_PER_FRAME` 2 and `MAX_FPS` 60, and the gate's `GATE_MARGIN` 1.05, `GATE_STEPS` 30, `GATE_PERCENTILE` 0.1, `GATE_CALIBRATION` 8, `GATE_GAP_MS` 100, `GATE_RANGE` 0.25 and `GATE_HYSTERESIS` 1.02, each with its finding (§5.4) |
| Tests | `test_prop_scatter.gd`; `test_frame_pacing.gd`, new; and `tools/perf/test_gate.mjs`, new, from the prototype's `sim_gate.mjs`, run with `node`: by hand with §6.1's checks, until PR 5 adds it to CI (§5.4, §5.6, §5.8) |

Expect: 2 more scripts loaded, 231, of which 1 is a test script, 108; about 11 more tests; the same `autopilot:` line, as the scatter's pixels don't change (P14). Negative cases N9–N13, N16, N21 and N22.

**Acceptance:** E2's comparison, E3, E4, and E6 on the Web.

### PR 4: Project: the viewport stretch **Δ Y2**

Title `project: render at the game's own resolution and scale it up, the viewport stretch (PF PR 4)`. Branch `pf/4-stretch`, from `pf/3-pacing`.

| Area | Files |
|---|---|
| Project | `project.godot`:29: `window/stretch/mode="viewport"`, with `aspect` `expand` and integer scaling as now (§5.5) |
| UI | `ui/stretch_switch.gd`, new: `StretchSwitch`, whose pure `mode()` gives the mode that the switch `stretch` names, `canvas_items` or `viewport`, and the project's without it or with any other value. `ui/main.gd`: sets the root's mode from it at startup (Q2) |
| Tests | `test_stretch_switch.gd`, new (§5.6) |

Expect: 2 more scripts loaded, 233, of which 1 is a test script, 109; 3–4 more tests; the same `autopilot:` line. Negative case N14. Screenshots of both stretches at a pixel ratio of 2, and §6.4's input checks, on the PR; E1 and E5 on its CI build (§7).

**Acceptance:** E1, E2, E4, E5, and E6 on the APK.

### PR 5: Docs: `docs/PERF.md` replaces the plan, and CI runs PF's checks

Title `PF PR 5: docs/PERF.md replaces the plan, and CI runs PF's checks`. Branch `pf/5-docs`, from `main`, once PR 4 has merged.

| Area | Files |
|---|---|
| Docs | `docs/PERF.md`, new, at most about 15 KB: the design as built, with every ID that code, tests or docs cite, and a header that gives `git show <sha>:PERF_PLAN.md` (planning.md §6). Code cites of `PERF_PLAN.md` become `docs/PERF.md`'s. `PERF_PLAN.md`, deleted |
| Owner's paths and CI | docs/agents/checks.md, `AGENTS.md`, `docs/README.md`, `.github/workflows/ci.yml`, `tools/ci/lint.sh` and `tools/ci/run_tests.sh`, as §5.8 says: among them, CI runs `test_gate.mjs` and fails on leaked RIDs (N8, N15) |
| Guidelines | Up to five of PF's learnings, where an agent reads them as it works (planning.md §7) |
| Plan and IP | `plan.md` and IP, as §5.8 says |

No game code or tests, so the counts are PR 4's. Negative case N15.

**Acceptance:** E7.

### 4.2 Landing (Q9)

Once the owner has merged this plan's PR, agents land PRs 1–3, bottom up, with `tools/agent/land_pr.sh`, each once its reviews are done (docs/agents/stacks.md step 4). The owner lands PR 4, after E5's look, and E1 and the APK's checks on the Fold4, all on PR 4's CI build (§6.4, §7); and PR 5, which changes `AGENTS.md`, `docs/agents/`, `docs/README.md`, `.github/` and `tools/ci/` (`AGENTS.md` §5 step 4).

**Labels.** This plan's PR, PR 4 and PR 5 each get `needs-owner` as they open, with a PR comment that says why: the owner lands plan PRs, this section marks PR 4, and PR 5 changes the owner's paths. Only the owner removes it.

The plan changes only on `pf/plan` until its PR merges. After that, PR 4 carries the plan's final sync: its status, §4.3's rows, the counts, E2's table and §6.4's results (planning.md §5). PR 5 deletes it.

### 4.3 Review fixes

Fixes from the prototype's build, the internal review (§4.4), the owner's answers and the PRs' reviews, each with its tests and negative case.

| PR | Change | Tests | Negative case |
|---|---|---|---|
| 3 | The prototype's first budget set `_hide_below` to 0 at `bind()`, so it hid rows −20 to −1 in the run's first frames, while they were in view and the buffer still held tile 0, and 183 of P14's 720 frames differed. `_hide_below` holds each freed row until it is below the buffer's first tile (§5.3), and then all 720 matched | `test_rows_below_0_stay_while_the_buffer_holds_tile_0` | N10, the first budget |
| 3 | With the budget, `test_props_in_view.gd`'s 4 tests read `anchor()` of rows that wait, whose path tiles the buffer had freed: "Invalid access to property or key 'cell' on a base object of type 'Nil'" (P5). Each row keeps the anchor it showed at | Those 4, and `test_a_waiting_row_keeps_its_anchor` | N11, `anchor()` from the buffer |
| 3 | Godot's `Engine.max_fps` drew 1.2–5.7 frames a second off the cadence at 120 Hz, as the callbacks' lateness decides (P15). The Web build caps with the gate (§5.4) | `tools/perf/test_gate.mjs` | N13, the limiter's rule |
| 3 | The prototype's first gate, at c5bfd9f, took the refresh as the least of 120 steps, which jitter shortens, gated every chain of the page, and lost the game's cancel after a skip (N16, §6.2). The gates since pace only the engine's chain, with handles of their own (§5.4) | `tools/perf/test_gate.mjs` | N16, the first gate |
| 3 | The internal review's gate, at a08cbe9, took the median of the short steps as the refresh and set n at 8 steps: in whole milliseconds it read 9 ms at 120 Hz at times, slow frames hid a 240 Hz screen, and n flipped near its boundaries (N21, §6.2). The gate of §5.4 calibrates on the steps after a skip, fits the refresh to the steps' lattice, sets n at 30 steps and moves it only past a 2% margin | `tools/perf/test_gate.mjs` | N21, that gate |
| 2 | The prototype drew each lamp's glows as rects of its silhouette's item, which at `CameraRig.arrive()`'s fractional zooms can land a pixel from where its sprite drew, and hid the group by the view's own edge (§4.4). Each glow is a child item at its sprite's transform, and the cull keeps `LAMP_CULL_MARGIN_PX` around the view (§5.2) | `test_lamps.gd`: a glow's item and transform, the cull's margin and the arrival; E4 at 1280×720 and in the arrival | N18, N19 |
| 1 | The counter at the bottom left, as first planned, covered the HUD's `Info`, the version and the seed (§4.4). It sits at the bottom right, at the font's size, 8, as at the theme's 16 it would reach the `Back` buttons (§5.1) | `test_frame_counter.gd`: its rect against `Info`'s, `RouteStrip`'s and `Back`'s | N17, the bottom left; N20, the size 16 |
| 4 | PR 4 first read the switch in `ViewSwitches` and tested it in `test_view_switches.gd`, PR 1's files, and so an add/add conflict once PR 1 squashes (§4.4); and its test read the helper, not the root. `StretchSwitch` and its test are PR 4's own, and the test reads `main.tscn`'s root | `test_stretch_switch.gd` | N14, `main.gd` without the switch |
| 1 | `measure.mjs` recorded only error lines, while the browsers log WebGL's errors as warnings. It counts warnings too (P9) | §6.3 | None: a tool's report |

### 4.4 Internal review

A model of another family reviewed this plan and the prototype ten times (`AGENTS.md` §5 step 1): at c5bfd9f, a08cbe9, f2f9e73, f074f83, d14c28b, 78ee7a0, 10f3ad0 and 29ea230, and the fixes of the third and the fourth. Of its 71 findings, 62 were valid and 9 valid in part; each was checked against the code or a new measurement, and this plan's PR gives each, with its evidence. The findings changed the gate (§5.4; N16, N21); E1's readings and routes (§5.7, §7), E2's cases and runs, E3's window and control (P13b), E4's sizes and E6's bounds; the ends' measure and its checks (P20; N23); the glows and the cull (§5.2; N18, N19); the counter (§5.1; N17); `StretchSwitch` (§4.3); and §5.7's figures.

---

## 5. Design

§5.1–§5.5 describe PRs 1–4 as the prototype built them, and what each PR changes from it; §5.6 lists their tests, §5.7 gives the Fold4's expected frame rates, and §5.8 the Δs to the docs. No lever changes the game's logic: the simulation steps at 60 Hz in `_physics_process`, seeded as before (IP §5.3). Only what draws, how often and at what resolution changes.

### 5.1 The counter and the switches (PR 1; Q4, Q5, Q8; Y1, Y6; E1, E8)

**`FrameStats`** (`ui/frame_stats.gd`), a pure `RefCounted`. `add(usec)` takes a frame's length: the microseconds between two `_process()` starts, read with `Time.get_ticks_usec()`, not `_process()`'s `delta`, which Godot smooths (`application/run/delta_smoothing`, on by default). It returns true once the frames since the last window add up to `Tuning.FPS_WINDOW_SECONDS`, 1 s; then `fps()`, the frames over their time, `median_ms()`, `p95_ms()`, `longest_ms()` and `early()`, the frames under `Tuning.FPS_EARLY_MS`, 12.5 ms, ¾ of a 60 Hz frame, describe that window until the next `add()` starts another. The P95 is the nearest rank, index ceil(0.95 n) − 1 of the sorted lengths: of 100 frames, 5 of them long, it is a short one, and with 6, a long one. The probe took index int(0.95 n), one rank higher, which gives a long one with 5 (N1).

**`FrameCounter`** (`ui/frame_counter.gd` and `.tscn`), a `CanvasLayer` at layer 2, over `main.tscn`'s `UI` layer (:36, layer 1), with `process_mode = PROCESS_MODE_ALWAYS`, so that it counts while the game is paused (`AGENTS.md` §2). Its `Label`, on a box of 60% black as the probe's overlay was, ignores the mouse, and as each window closes shows "60 FPS" over "P95 17 MS": capitals, digits and spaces, which Pixel Operator 8 has (N2). It sits at the bottom right, 8 px in, at the font's own size, 8, not the theme's 16 (`ui/theme.tres`:79): its widest text, "P95 100 MS", is then 66 px wide, clear at 360×640 of the HUD's `Info` at the bottom left (`ui/hud.tscn`:105–115; N17), its `RouteStrip` on the right (:60–71), and the `Back` buttons of Settings, the Book and the Atlas, at x 100–260, which at 16, 132 px wide, it would reach (N20). A static `text(stats)` makes that text, so that tests check it without a scene. It shows while the setting `"fps"` is on or the switch `fps` is given, and follows `SaveService.settings_changed` (:15) with a method, not a lambda (docs/M2.md H16). While hidden it doesn't process, and a new window starts when it shows. It counts the game's frames, not the page's: where a browser runs the page at 120 Hz and PR 3's cap draws the game at 60, the browser's own meters may count 120 (§5.7). With the switch, each window also prints a line to the log, the browser's console on the Web:

```
PERF fps=59.9 n=60 med=16.7 p95=17.4 max=33.6 early=0 draws=29
```

`n` is the window's frames, so that `measure.mjs` can weigh windows by their time, `n / fps` (E2). `early` is `early()`: at 120 Hz, the frames a refresh after the last, which the cap should leave out (E6). `draws` is `RenderingServer.get_rendering_info(RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)`, and `tools/perf/measure.mjs` reads these lines (§6.5). With the switch, it also prints `EVENT area <id>`, `EVENT disaster_started <id>` and `EVENT run_ended <cause>` as `EventBus` emits them, and `EVENT game_over` as `GameState.state` becomes `GAME_OVER`, which no signal marks, each ending with `frames=` and `Engine.get_frames_drawn()`, by which `events.mjs` times E2's ends and counts their frames. Without the switch it prints nothing, so GUT's and `smoke.sh`'s logs stay as they are.

**`ViewSwitches`** (`ui/view_switches.gd`), static functions. `has(name, args, query)` and `value(name, args, query)` read a switch from the user arguments, as `--fps`, `--stretch=viewport` or `--fpscap=0`, or else from the page's query, as `?fps`, `?stretch=viewport` or `?fpscap=0`. Each matches the whole name, so that `fpscap` doesn't count as `fps` (N4), and an argument wins over the query. `page_query()` gives `location.search` through `JavaScriptBridge.eval("location.search", true)` on the Web, which the release template runs, as the prototype's gate did (P15), and "" elsewhere, where `eval()` gives null. `main.gd` reads the query once, in `_ready()` after `_autopilot`'s line, and passes it with `args`, which tests set (`ui/main.gd`:34–35). The APK takes no arguments (checks.md §4), so there the counter comes only from Settings (Q8).

**The setting.** `"fps": false` joins `SaveData.DEFAULT_SETTINGS` (`autoload/save_data.gd`:16–22). `_setting_ok()` takes any bool for it (:353–358); a save without it keeps the default, as the load copies only the keys that the save has (:313–318); and an older build ignores it. So `VERSION` stays 5 (Q5). The settings screen's `List` gets `FpsLabel`, "Show FPS", and `Fps`, a `CheckButton`, after `Orientation` (`ui/settings_screen.tscn`:90–98), with `accessibility_name = "Show FPS"` as the `ui` instructions ask, and `settings_screen.gd` shows and saves it as it does `Haptics` (:18, :28, :37, :53–54).

### 5.2 The lamps (PR 2; Q6; Y3, Y9; E2, E4)

`Lamps` stays one `CanvasGroup` at `GLOW_Z`, over the veil, with its adding shader, and `refresh()` still sets its `self_modulate` by the zone's clock (docs/DAYNIGHT.md §5.12). What it holds changes, from nodes to RenderingServer canvas items laid out as the nodes were:

- **An item a lit prop, and one a glow.** `add()` makes a canvas item for the prop, or takes one that `remove()` left, parents it to the group's (`canvas_item_set_parent(item, get_canvas_item())`) and gives it the prop's position, as its silhouette's `Sprite2D` had. It draws the silhouette, if the prop stands: the prop's frame at `-def.foot`, in `Color.BLACK` (`world/prop_pool.gd`:27–41). Each glow, of `def.lights` and then of `def.light_pools`, is a child item of it, with its glow sprite's transform: at the box's centre, scaled by `box.size / GLOW.get_size()` (`world/lamps.gd`:129–137). It draws `GLOW` centred, at the offset that `Sprite2D` rounds (sprite_2d.cpp :135–146), in white at an alpha of 1, or of `LAMP_POOL_SHARE` for a pool. The glows take draw indices 0, 1, 2…, their places among the sprite's children, as Godot sorts siblings by that index alone, with an unstable sort (renderer_canvas_cull.h :111–115).
- **Why child items.** With the 2D snap on (`project.godot`:80), Godot rounds an item's own translation and its parent's to whole pixels, at each level (renderer_canvas_cull.cpp :361–364). The items are rounded at the sprites' levels, so they cover the sprites' pixels at any zoom, as at `CameraRig.arrive()`'s fractional ones (`world/camera_rig.gd`:143–147). The prototype's glows, rects of the silhouette's item, matched at 360×640 (P12), but can land a pixel off at a fractional zoom (§4.3; N18).
- **One texture an atlas.** `_atlas()` puts `GLOW`'s image at the top left of an RGBA8 `ImageTexture`, and the props' atlas under it at `ATLAS_Y`, 64, with sides that are powers of two, so that the glow's coordinates scale exactly and its texels sample as before. Every item then draws from one texture, and Godot batches rects across items that share their texture and material, each with its own transform. The prototype's rects drew 45 draw calls at night in the City, not 204 (P4), and PR 2 counts its items' against that.
- **The order by draw index.** Props y-sorts its sprites, and `Lamps` keeps its props' items in that order (`_draws_before()`: by y, then by child index). Instead of `move_child()`, whose cost grows with the children (Y9), each gets an integer key between its neighbours' in `_order` and `canvas_item_set_draw_index()`. A new key is the midpoint of its neighbours', or `KEY_GAP`, 65,536, beyond the first or the last. When two neighbours' keys differ by less than 2, or a key would pass `KEY_MOST`, 2^30, as the index is a 32-bit integer, every key is spread again, `KEY_GAP` apart around 0. Keys must never repeat, as the sort is unstable (N5), and `Lamps` must have no node children, whose index is their place among its children.
- **Frames and fades.** `Lamps.show_frame(lit, frame)` clears the prop's item and draws its silhouette again when the frame changes, if the prop stands, and its glows' items stay; `Lamps.fade(lit, alpha)` sets the prop's item's `modulate`, which Godot passes to its children, as the silhouette's did to its glows (docs/VISUALS.md A19). `PropScatter._set_frame()` and `_show_alpha()` call them. Rects aren't polygons, so a redraw raises no WebGL error (godot#124726; docs/M2.md §5.7): P16 found no warning with them in either browser.
- **Remove and free.** `remove()` hides the prop's item, and keeps it and its glows' items for later `add()`s. On `NOTIFICATION_PREDELETE`, `Lamps` frees every item it made. A leaked item would only make Godot warn at exit, which no check fails on, so `test_freeing_the_lamps_frees_their_items` checks the free (N8), and PR 5 makes `run_tests.sh` fail on the warning.
- **The cull.** `refresh()` shows the group only while the lamps are on and a glow is near the view: `on > 0.0 and _glow_in_view()`. `add()` notes the rect that the prop's glows cover in the group's space, with the roundings that don't depend on the camera: the prop's position and the glows' centres, each to a whole unit of its parent's space, and the glows' offsets as `Sprite2D` rounds them. The others, of the parents' translations in the viewport's pixels, move a glow by ½ pixel at most at the prop's level, and ½ at the glow's, only at a fractional zoom. So `_glow_in_view()` grows the viewport's rect by `LAMP_CULL_MARGIN_PX`, 2, maps it into the group's space with `get_global_transform_with_canvas().affine_inverse()`, and looks for a noted rect that meets it (N6, N19); unrounded rects could be off by 1 pixel plus the zoom, 3 at zoom 2. Hiding the group changes no pixel, as a group that adds black adds nothing (P12), and saves its screen-sized buffer where no glow is in view, as on Rural's open road at night. The group's `self_modulate` still carries the strength by the clock, apart from the cull, so `test_a_glow_never_adds_more_than_the_veil_takes_away`, which has no lamp in view, counts the quarter hours lit by its alpha instead of by `visible`.
- **For tests,** `Lamps.parts(lit)`, a pure static function, gives what a prop's items draw: the silhouette's rect, its region of the texture and its colour, and each glow's transform, draw index, rect and colour; the items draw what it gives. `shown()` gives the props' items in their order, with their keys.

PR 2 drops the `Sprite2D` path, the silhouettes' `PropPool`s and `move_child()`. The prototype's midpoints and relabel divide integers, which raised 2 warnings (§6.3), so PR 2 marks each `@warning_ignore("integer_division")`, as `world/greybox_atlas.gd`:135 does.

### 5.3 Two rows a frame (PR 3; Q7; Y4; E3)

`PropScatter` shows rows of props ahead of the car, and `RoadBuffer` frees the path tiles more than `BUFFER_BEHIND`, 20, behind it. Today `_on_tiles_freed()` hides every row below the buffer's first tile at once (`world/prop_scatter.gd`:164–168). `bind()` shows rows from −20, the ground before the start (:102), so the first free, as the car reaches path tile 21 about 8 s into a run, hides rows −20 to 0, 21 rows, in one frame (Y4).

PR 3:
- `_on_tiles_freed()` only raises `_hide_below` to the buffer's first tile.
- `update()`, each frame, first calls `_hide_rows()`, which hides rows from `_lowest_row` up to `_hide_below`, at most `Tuning.HIDE_ROWS_PER_FRAME`, 2, and then `_show_rows()` as now. The first free's 21 rows go in 11 frames, about 0.18 s. Rows go lowest first, so each freed row goes within ceil(w / 2) updates of its free, w being the rows then waiting up to and including it: a later free's row, as the car passes a tile, in the next frame, or behind the rows that still wait (`test_freed_rows_go_lowest_first_within_their_bound`; N22). The rows are 20 tiles behind the car, out of view, so no frame changes (P14).
- `bind()`, as a run starts, hides the last run's rows at once, as now, and sets `_hide_below` to the new run's `_lowest_row`, so that rows −20 to −1 stay until the buffer frees tile 0 (§4.3; N10).
- **`Row.anchor`.** Each row notes, as it shows, the cell that its props spread from, and `anchor(k)` gives it while the row shows, as a row that waits may have lost its path tile (§4.3; N11).

### 5.4 The cap (PR 3; Q3; Y5; E6)

The car and the camera move only in the game's 60 Hz steps (Y5), so a frame drawn between two steps shows them where they were. `FramePacing` (`ui/frame_pacing.gd`):

- `static func cap(web: bool, android: bool, switch: String) -> int`: the switch `fpscap`'s value, if it is a whole number of 0 or more; otherwise `Tuning.MAX_FPS`, 60, on the Web and on Android, and 0, no cap, elsewhere: desktop builds, the editor, headless runs, GUT, `smoke.sh` and Movie Maker, which renders at its own fixed rate (N12).
- `static func apply(cap: int) -> void`: on the Web, `Engine.max_fps = 0` and, for a cap over 0, the gate below; elsewhere `Engine.max_fps = cap`, whose limiter sleeps out the rest of each frame (os.cpp :708–741).
- `static func gate_js(cap: int) -> String`: `GATE_JS` with the cap and `config/tuning.gd`'s `GATE_` values written in with `%`.
- `main.gd`, before `_world.build()`, calls `FramePacing.apply(FramePacing.cap(OS.has_feature("web"), OS.has_feature("android"), ViewSwitches.value("fpscap", args, query)))`. With neither feature and no switch, a test's `main` sets 0, the default.

**Why a gate on the Web.** Godot's Web build runs a frame in each `requestAnimationFrame` callback, and its limiter skips a callback while too little time has passed since the last frame, by `OS::get_ticks_usec()` read in the callback (web_main.cpp :80–103). Callbacks run a little early or late, so at 120 Hz some frames come 8.3 or 25 ms after the last instead of 16.7: 1.2–5.7 a second in Firefox in the City by day (P15). The gate decides by the callback's timestamp instead, the frame's own time, which steps by whole refreshes.

**The gate,** which `apply()` runs once through `JavaScriptBridge.eval()`, wraps `window.requestAnimationFrame` and `cancelAnimationFrame`, which Emscripten's main loop calls (§8):

- **It paces only the engine.** The first callback requested after the install is the runner, which the gate paces; any other goes straight to the browser. `main.gd`'s `_ready()`, which installs it, and `emscripten_set_main_loop`, which asks for the main loop's first frame, run in one call (web_main.cpp :165–175), so the runner is Emscripten's main loop while nothing between them asks for a frame; the stock loader's progress frames (`index.js` :203, :670) come in callbacks of their own. Code that asked for one there would have it paced instead (§8). Each request of the runner returns a handle of the gate's own, a negative number, which the wrapped `cancelAnimationFrame` maps to the browser's pending request, so a cancel after a skip still cancels. A second install only sets the cap, and a cap of 0 installs nothing. `window.__framePacing` holds the cap, the refresh, n and the frames skipped, which `measure.mjs` records (§6.5).
- **The refresh.** Each timestamp 2 ms or more after the last distinct one adds its step, skipped frames' included, to the last `GATE_STEPS`, 30. A rough refresh is the upper median of the steps under 1.5 times their `GATE_PERCENTILE`, 0.1, quantile, which neither jitter nor slow frames move. A step after a skipped callback is one refresh, as the game did no work in it: if the upper median of the last `GATE_CALIBRATION`, 8, is under ⅔ of the rough refresh, slow frames have hidden a faster screen, and it replaces it. Once 8 or more steps follow the last step over `GATE_GAP_MS`, 100, the refresh is fitted to their timestamps: of the whole numbers k of refreshes in their span that put span ÷ k within `GATE_RANGE`, 25%, of the rough refresh, the one whose lattice best lines up the timestamps, by the largest \|1 + Σ e^(2πi k t ÷ span)\|, gives span ÷ k. Rounding each step alone would miscount those that jitter takes past half a refresh, as with timestamps in whole milliseconds. A switch between 120 and 90 Hz takes effect within half a second (P17). While n is 1, the gate skips no callback, so frames slower than a refresh can hide a faster screen, and the game runs as uncapped: 80 fps after 60 → 240 Hz under 9 ms of work.
- **The rule.** The gate first skips callbacks until it has 8 steps after a skip, or has skipped 16: about 8 refreshes, after a first frame that Godot runs outside the gate (web_main.cpp :178). At 30 steps it sets n = fit(`GATE_MARGIN`), where fit(m) = max(1, floor(m × 1000 ÷ refresh ÷ cap)) and `GATE_MARGIN` is 1.05; after that, n moves only as far as fit(1.05 ÷ `GATE_HYSTERESIS`) and fit(1.05 × `GATE_HYSTERESIS`) both say, with `GATE_HYSTERESIS` 1.02, so that a rate near a boundary doesn't flip it. A callback runs the game unless n > 1 and t − last < (n − ½) × refresh; then it asks for the next frame. So the game draws every n refreshes, at the screen's rate over a whole number: the fewest frames that keep 60 ÷ 1.05, 57 fps, or more as n is set, and 56 once it is (E6).

| Refresh (Hz) | 60 | 75 | 90 | 120 | 144 | 165 | 240 |
|---|---|---|---|---|---|---|---|
| n | 1 | 1 | 1 | 2 | 2 | 2 | 4 |
| Frame rate | 60 | 75 | 90 | 60 | 72 | 82.5 | 60 |

At 120 Hz, once n is 2, it stays 2 while the refresh reads 5.72–8.92 ms; Firefox's read 8.30–8.35 (P18). A skipped callback costs no work, so a frame that takes c refreshes takes max(n, c) with the gate. Over 5 s or more, it shows at least the lesser of uncapped's steps a second and its own frames a second, less 0.5, as uncapped frames over 60 a second repeat steps (P17).

**What it showed:** in simulation, the table's rates, with at most 0.1 frames a second off the cadence, or 0.5 with timestamps in whole milliseconds, where Godot's limiter's rule drew 60 at each rate (P17); in Firefox at 120 Hz, Y5's rates; and at 60 Hz, the uncapped rates in both browsers, with only its 8 calibration frames skipped (P18).

**`tools/perf/test_gate.mjs`**, run with `node`, reads `GATE_JS` from `ui/frame_pacing.gd` and its values from `config/tuning.gd`, so that it tests the code that ships, and runs it on a `window` and a `performance` of its own, against simulated refreshes. It reads no git history, which CI's shallow checkout lacks: N16 and N21 put the old gates in `GATE_JS` (§6.2). It passes if:
- at each rate of the table, with exact timestamps, with 0.3 ms of jitter, and in whole milliseconds with 0.5 ms, the game draws the table's rate ± 1, with at most 0.1 frames a second off the cadence, or 0.5 in whole milliseconds; and so with callbacks up to 2 ms late at 120 and 119.88 Hz, near n's boundaries at 115, 170 and 230 Hz, and with 7–9 ms of work a frame at 240 and 360 Hz;
- in each case of 5 s or more, it shows at least the lesser of uncapped's steps a second and its own frames a second, less 0.5;
- as the screen goes from 120 Hz to 90, or back, the first half second draws 57 fps or more, and the next 1.5 s the new rate ± 1; and after 5 s hidden, it draws 60 again;
- the page's other chains run at the screen's rate, and the game draws no frame from a cancel on, whether its last callback ran or was skipped; and, which the prototype's `sim_gate.mjs` leaves out, a second install sets the cap, and a cap of 0 installs nothing.

N13, Godot's limiter's rule, N16, the prototype's first gate at c5bfd9f, and N21, the internal review's at a08cbe9, fail it (§6.2).

**Android.** The APK caps with `Engine.max_fps`. Whether its frames then come evenly on the Fold4's 120 Hz screens is E6's reading (§8).

### 5.5 The viewport stretch (PR 4; Q2; Y2; E1, E4, E5)

`project.godot`:29 becomes `window/stretch/mode="viewport"`; `aspect="expand"` (:30), `scale_mode="integer"` (:31), the nearest filter (:78) and the 2D snap (:80) stay. Godot works out the same view for both modes: 360 wide or 640 tall, grown to the screen's shape, at the largest whole scale that fits, with black margins for the rest (window.cpp :1317–1324, :1342–1401). `canvas_items` then draws every layer at the screen's pixels, by scaling the canvas (:1407–1412); `viewport` draws them at the view's, and scales the frame up (:1414–1424), with the nearest filter (rasterizer_gles3.cpp :452–453), on a window cleared to black where the frame doesn't reach (:427–435). The view, the camera's zoom (`world/camera_rig.gd`:106–113) and the UI's layout stay as they are, and at a scale of 1 so does every pixel (E4).

At a scale of 2 or 3, each of the game's pixels fills a block of 2×2 or 3×3 of the screen's, as each art pixel already did:
- **The same:** the art, drawn at whole zooms with the nearest filter, and the text, in a pixel font without antialiasing.
- **Changed:** what moves steps by the game's pixel. On the Fold4's cover screen in portrait, at zoom 1 and a scale of 2, the camera's scroll, the car and the legends move by whole art pixels, not halves; on its inner screen, at zoom 2, by halves, not sixths in portrait, at a scale of 3, or quarters in landscape (docs/M2.md :157–164). The edges of the glows, the veil and the headlights' cone, and any sprite drawn rotated or scaled, are drawn at the view's resolution. At a scale of 1, as on the cover screen in landscape, nothing changes.
- **E5:** the owner compares both on each of the Fold4's screens, with `?stretch=canvas_items` and `?stretch=viewport`, on PR 4's CI build served from the owner's computer (§7), as Pages serves only `main`.
- **Input:** checked on the export at scales of 2 and 3, with the black margins (§6.4).

**`StretchSwitch`** (`ui/stretch_switch.gd`) is PR 4's own, so that PR 4 changes none of PR 1's new files (§4.3). Its pure static `mode(value, project_mode)` gives `Window.CONTENT_SCALE_MODE_CANVAS_ITEMS` for `canvas_items`, `CONTENT_SCALE_MODE_VIEWPORT` for `viewport`, and `project_mode` for any other value or none. `main.gd`'s `_ready()` sets the root's `content_scale_mode` to `StretchSwitch.mode(ViewSwitches.value("stretch", args, query), root.content_scale_mode)` before `quit_requested.connect()`, and `test_stretch_switch.gd` checks `main.tscn`'s root in that mode once it is ready, and restores it (N14).

### 5.6 Tests (E2–E6, E8)

Names are proposals; each PR's count is in §4. Each negative case is in §6.2.

| PR | Script | Tests | N# |
|---|---|---|---|
| 1 | `test_frame_stats.gd`, new | Even frames give their rate; the P95 of 100 frames with 5, then 6, long ones; a window closes after a second of frames; the longest frame; `early()` counts the frames under 12.5 ms | N1 |
| 1 | `test_view_switches.gd`, new | A switch from the arguments, from the query, and with no value; an argument wins over the query; `fpscap` isn't `fps` | N4 |
| 1 | `test_frame_counter.gd`, new | It shows while the setting is on, and follows a change; the switch shows it and prints a `PERF` line a window, and `EVENT` lines, with the frames drawn, as a run ends and as the game-over screen opens; without it, nothing is printed; it and every `Control` under it ignore the mouse; at 360×640, with its widest text, its rect meets neither the HUD's `Info` nor its `RouteStrip`, nor Settings' `Back`; its text, with every digit, has only the font's glyphs | N2, N17, N20 |
| 1 | `test_settings_screen.gd`, `test_save_data.gd` | Show FPS shows and saves the setting, and has its name; the default, and a save without `"fps"` keeps it | N3 |
| 2 | `test_lamps.gd` | Its 4 tests that read the silhouettes' and glows' nodes read `shown()` and `parts()`, and the veil's test reads the group's alpha (§5.2). New: each glow is a child item of its prop's, at its sprite's transform and index; the keys follow Props' order and never repeat, also after a relabel; a frame change redraws the silhouette; a fade sets the item's alpha; the group hides while no glow is within the margin of the view, with the camera moved, and shows for a glow just past the view's edge and through the arrival; an item is used again after `remove()`; and `test_freeing_the_lamps_frees_their_items` | N5–N8, N18, N19 |
| 2 | `test_prop_scatter.gd` (2), `test_world_renderer.gd` (1), `test_daylight_run.gd` (1) | Read the items, not the nodes (P5) | — |
| 3 | `test_prop_scatter.gd` | Its 2 tests of the rows that a free hides wait for the budget (P5). New: a free hides at most 2 rows a frame; freed rows go lowest first, each within §5.3's bound, also when a free comes while rows wait; rows below 0 stay while the buffer holds tile 0; a waiting row keeps its anchor, as `test_props_in_view.gd`'s 4 tests need (§4.3); `bind()` hides the last run's rows at once | N9–N11, N22 |
| 3 | `test_frame_pacing.gd`, new | The Web and Android cap at 60; desktop and headless runs don't; `fpscap` sets the cap, 0 lifts it, and a value that isn't a whole number keeps the default; `apply()` sets `Engine.max_fps` off the Web, and the test restores it; `gate_js()` writes in the cap and the tuning's values | N12 |
| 3 | `tools/perf/test_gate.mjs`, new, run with `node` | §5.4's rates, late callbacks, loads, switches, resume, chains, cancel and installs | N13, N16, N21 |
| 4 | `test_stretch_switch.gd`, new | Each value's mode, and the project's for any other or none; `main.tscn`'s root in the switch's mode once it is ready, restored after | N14 |

### 5.7 The Fold4: what to expect (Q1; Y1, Y2; E1)

No one has read the game's frame rate on the Fold4, nor timed a GPU on this game (Y1). So these figures are provisional: estimates from the screens' pixels and this VM's proxy, for the owner to compare with. E1's readings are what count.

**What it draws.** The APK hides the system's bars, in immersive mode (`export_presets.cfg`:40). Chrome fills its page, less its own bars, at the screen's pixel ratio, by `html/canvas_resize_policy=2` (`export_presets.cfg`:15) and `allow_hidpi`, which the project leaves on (main.cpp :2759). Each view is the base grown to the screen's shape, at the largest whole scale that fits (§5.5). The APK's figures are docs/M2.md §6.5's reference geometry, of the full screens (:157–164). Chrome's are estimates, with 80 dp of bars, its toolbar and the status bar, about 210 pixels, or 128 dp, about 336, with three-button navigation; its page is shorter than the screen, and so is its view:

| Screen | View, zoom | The APK, `canvas_items` | Chrome, `canvas_items` | With PR 4 |
|---|---|---|---|---|
| Cover, portrait | 360×922, 1 | ×2: 720×1844, 1.33 M | ×2: about 720×1580–1680, 1.1–1.2 M | 360×922, 0.33 M; in Chrome about 360×788–838, 0.28–0.30 M |
| Cover, landscape | 1639×640, 2 | ×1: 1639×640, 1.05 M | ×1: about 2136×640, 1.37 M | The same, at a scale of 1 |
| Inner, portrait | 532×640, 2 | ×3: 1596×1920, 3.06 M | ×3: about 1770×1920, 3.4 M; ×2, about 1260×1280, 1.6 M, where the page is under 1920 pixels tall | 532×640, 0.34 M; in Chrome about 590–630×640, 0.38–0.40 M |
| Inner, landscape | 768×640, 2 | ×2: 1536×1280, 1.97 M | ×2: about 1740–1890×1280, 2.2–2.4 M | 768×640, 0.49 M; in Chrome about 869–943×640, 0.56–0.60 M |

In landscape, Chrome leaves the cover about 694 of its 904 pixels of height, so it keeps a scale of 1: about 2136×640, or 2020×640 with three-button navigation on the side. A page under 640 pixels tall, as with those buttons at the bottom, about 568, keeps a scale of 1 too, cropped at the right and the bottom with either stretch (window.cpp :1381–1388), and the counter with them: `?fps`'s `PERF` lines in DevTools' console give the readings (§5.1).

**The frame rates to expect,** as E1 reads them, in each real scene; provisional:

| Build and screen | Today: `main`, on Pages | After PF: PR 4's head |
|---|---|---|
| Chrome, cover, portrait | 50–60 fps on a 60 Hz page; 80–120, and uneven, where Chrome runs the page at 120 Hz | 60, steady: a median of 55–60 fps, a P95 of 20 ms or less |
| Chrome, cover, landscape | As in portrait | About today's, held to 60: PR 4 changes nothing at a scale of 1 (§5.5), so only PRs 2 and 3 help |
| Chrome, inner, either way | 40–60, a P95 of 20–35 ms | 60, steady: a median of 55 or more, a P95 of 20 ms or less |
| The APK, any screen | 60, or up to 120 and uneven | 60 ± 1, capped, a P95 of 20 ms or less (E6) |

Today, also: slower frames in a run's first 6 s, as its first rows are made (Y8, which PF keeps), and one long frame about 8 s in, as the first rows are freed (Y4, which PR 3 removes). After PF too, a run's ends may read lower than its drive: in the proxy, a legend ran up to 8 fps under its area's (P20; Q12).

**Why.** A frame takes about the longer of the main thread's work and the GPU's. The main thread's took 3–9 ms a frame in this VM on `main`, and 2–4 with PF (P4). The GPU fills each layer and each group's buffer at the canvas's pixels: today 1.1–3.4 M in Chrome, the most on the inner screen, and with PR 4 0.28–0.60 M, but for the cover in landscape, which keeps 1.37 M at a scale of 1. How fast the Fold4's GPU fills those pixels is the unknown, so the rates above are judgements from those counts and the proxy's gains (P10), and the inner screen, with the most pixels, should gain the most.

**How to read it.**
- **Today,** before PR 1: in Chrome on the phone, https://pompomon.github.io/roadgame/, which `main`'s CI deploys: e73f96d's game, as this plan's PR changes only docs. With the phone on USB, `chrome://inspect` on a computer, the page's DevTools, then Rendering → Frame rendering stats.
- **After PR 1:** Settings → Show FPS, or `?fps` on the Pages build; the APK, from Settings only. The counter counts the game's frames: at 120 Hz with PR 3's cap, the browser's meters may count the page's 120 while the game draws 60 (P18).
- **PR 4's CI build,** before it lands: §7.
- **When:** the City by day from a run's start, and Rural at night from about 32.5 s to 53.75 s after the tunnel, Rural's way in, at turn 20 (docs/SPEEDUP.md :84, :94, :150; Y11); §7 gives the other scenes' routes. E1 takes its 10 readings in a row within each. The Pages build sets no hour, so the City at night is the agents' alone.
- **Red flags,** which would mean these estimates are wrong: today, the City by day under 40 fps on the inner screen, or under 50 on the cover; after PF, any real scene under 55 fps, or a P95 over 25 ms.

**Unknowns.** Whether Chrome on the Fold4 runs pages at 120 Hz, as Samsung's adaptive motion smoothness allows, or at 60; heat, after 10 minutes or more of play; and the APK's pacing with `Engine.max_fps` at 120 Hz (§5.4, §8).

### 5.8 Δs to the docs (E7)

- **PR 2:** docs/VISUALS.md A8 (:21), on `get_index(true)` for the silhouettes, and :97, which become the items' keys; A10 (:23), the insert's cost, fixed (Y9); A19 (:125), a fade by the item's `modulate`; and :152's "faster `Lamps` insert", done. docs/M2.md :106: rects that the RenderingServer draws may be redrawn, as only polygons raise the errors (P16).
- **PR 5:** `plan.md` :199, the `viewport` stretch, and :373, E1's frame rates; IP :111, M0.1's stretch, :203, the counter instead of the editor's monitors, and §4 M7, §9's notes for M7; docs/agents/checks.md :64, §5.7's expectations and `tools/perf/` instead of the software frame rates; `AGENTS.md` :18, Y# (PERF) among the IDs, :20, PF among the plans merged, and the switches `fps`, `stretch` and `fpscap`; `docs/README.md`, PF's row; and `.github/workflows/ci.yml`'s `lint` job, which runs `node tools/perf/test_gate.mjs`; `tools/ci/lint.sh`, whose shellcheck takes `tools/perf/*.sh`; and `tools/ci/run_tests.sh`, which fails on Godot's warning of leaked RIDs, in its singular and plural forms (N8, N15). These are the owner's paths (`AGENTS.md` §5 step 4), so PR 3, which agents land, leaves them, and runs the gate's test by hand with §6.1's checks.

---

## 6. Verification

### 6.1 Checks and counts

The checks are `AGENTS.md` §3's five: the import, `check_scripts.sh`, `lint.sh`, GUT and `smoke.sh`. They ran locally with Godot 4.7.2, on the prototype with its levers off, and in CI, started by hand with `upload-builds`, whose `lint`, `test`, `export-web` and `export-android` jobs passed. The prototype's commits since d7f4d77 change only `tools/pf/`, which no check loads, but for the probe's events at f074f83 and d14c28b (P20).

| State | Where | Scripts loaded | Test scripts | Tests | Asserts | GUT time | Smoke |
|---|---|---|---|---|---|---|---|
| `main` (e73f96d) | Local | 223 | 104 | 924 | 524,374 | 148.0 s | `autopilot: tile 177, turns 32, area rural` |
| `main` (e73f96d) | Run 44887282149 | 223 | 104 | 924 | 524,374 | 144.3 s | The same |
| c5bfd9f, a08cbe9, d7f4d77, f074f83, d14c28b | Local | 224 | 104 | 924 | 524,374 | 150.4, 149.6, 149.8, 150.5, 150.7 s | The same |
| a08cbe9, 769bf38 | Runs 44931127749, 44936084277 | 224 | 104 | 924 | 524,374 | 150.6, 149.8 s | The same |

`lint.sh` found no problem in `main`'s 223 files or the prototype's 224, and would change none; `shellcheck` 0.9.0 passed `tools/pf/movie.sh` too, which `lint.sh` doesn't check (`tools/ci/lint.sh`:83). `smoke.sh` printed no error line, GUT reported no warning, and `git status --porcelain` printed nothing after the checks. CI's `test` job took 3 min 24 s on `main`, and 3 min 35 s on a08cbe9 and 769bf38. The prototype's one more script is the probe; its tools are in `tools/pf/`, which the exports leave out (docs/agents/checks.md §4).

**The suite with each lever on** (P5) ran as `run_tests.sh` runs GUT, with the lever's switches after `--`, on the five scripts that read the lamps and the rows: `test_lamps.gd`, `test_prop_scatter.gd`, `test_world_renderer.gd`, `test_daylight_run.gd` and `test_props_in_view.gd`.

| Switches | Failing tests |
|---|---|
| `--pf-lamps=rs` | 8, each reading the silhouettes' or glows' nodes: 4 of `test_lamps.gd`, 2 of `test_prop_scatter.gd`, and 1 each of `test_world_renderer.gd` and `test_daylight_run.gd` (§5.6) |
| `--pf-lamps=rs,cull` | 9: those, and `test_a_glow_never_adds_more_than_the_veil_takes_away`, "[0] expected to be between [30] and [60]: quarter hours lit", as it reads the group's visibility, which the cull changes (§5.2) |
| `--pf-hide-budget=2`, before `Row.anchor` | 6: 4 of `test_props_in_view.gd`, each "Invalid access to property or key 'cell' on a base object of type 'Nil'" (N11), and 2 of `test_prop_scatter.gd`, which expect the freed rows gone in the frame of the free |
| `--pf-hide-budget=2` | 2: `test_prop_scatter.gd`'s two |
| All four, before `Row.anchor`, on the whole suite | 15 of 924, in 140.4 s: the lamps' 9 and the budget's 6, so the stretch and the cap fail none |

### 6.2 Negative cases

Each case makes one change to its PR's code, runs the whole suite with `run_tests.sh`, and checks that it exits 1 and fails the tests it names; N13, N16 and N21 run `node tools/perf/test_gate.mjs` instead, and N23 `tools/perf/events.mjs`, which must exit 1. They run in their own worktree, from `git worktree add --detach`, imported, as `git checkout -- .` restores the files after each. The prototype has no GUT tests of its own (Q11), so each PR runs its cases; N10, N11 and N23 were measured on the prototype; N13, N16 and N21 with its `sim_gate.mjs`, whose argument names the gate: it exits 0 with §5.4's, and 1 with each of those, which fail 32, 22 and 11 of its checks (P17); N8's mechanism was checked, and N15 on `main`.

| N# | PR | Change | Fail |
|---|---|---|---|
| N1 | 1 | `FrameStats`' P95 at index int(0.95 n), as the probe's | `test_frame_stats.gd`'s P95 test: 100 frames with 5 long ones give a long one |
| N2 | 1 | The counter's text with an arrow, "↓" | `test_frame_counter.gd`'s glyph test |
| N3 | 1 | `settings_screen.gd` doesn't save Show FPS | `test_settings_screen.gd`'s toggle test |
| N4 | 1 | `ViewSwitches` matches a switch by its prefix | `test_view_switches.gd`: `fpscap` isn't `fps` |
| N5 | 2 | Keys by midpoints alone, without the relabel | `test_lamps.gd`: keys never repeat, also after a relabel; with neighbours' keys 1 apart, the midpoint repeats one |
| N6 | 2 | `_glow_in_view()` with the viewport's rect, without the canvas transform | `test_lamps.gd`: the cull with the camera moved |
| N7 | 2 | `show_frame()` that notes the frame without redrawing | `test_lamps.gd`: a frame change redraws the silhouette |
| N8 | 2 | No free at `NOTIFICATION_PREDELETE` | `test_freeing_the_lamps_frees_their_items`, which touches each item after the free and expects Godot's `Parameter "canvas_item" is null.` for each, with `assert_engine_error_count()`, as a scratch test showed. Godot itself only warns at exit, `WARNING: 2 RIDs of type "CanvasItem" were leaked.` (§5.8) |
| N9 | 3 | `_hide_rows()` without the budget | `test_a_free_hides_at_most_two_rows_a_frame` |
| N10 | 3 | `_hide_below` from 0 at `bind()`, the prototype's first budget | `test_rows_below_0_stay_while_the_buffer_holds_tile_0`. Measured: 183 of P14's 720 frames differed |
| N11 | 3 | `anchor()` from the buffer, as `main` | `test_props_in_view.gd`'s 4 and `test_a_waiting_row_keeps_its_anchor`. Measured: the 4 failed (§6.1) |
| N12 | 3 | `cap()` gives 60 everywhere | `test_frame_pacing.gd`: desktop and headless runs aren't capped |
| N13 | 3 | The gate with Godot's limiter's rule: by the clock in the callback, against a target that moves on by 1/60 s | `test_gate.mjs`: 60 fps at 75, 90, 144 and 165 Hz, with 14.9–40.1 frames a second off the cadence, and 5.2 at 119.88 Hz with late callbacks (P17) |
| N14 | 4 | `main.gd` without the switch | `test_stretch_switch.gd`: `main.tscn`'s root in the switch's mode |
| N15 | 5 | `run_tests.sh` without its leak check | A scratch test that leaves a canvas item unfreed, run with `-gselect=`: `run_tests.sh` exits 1 with the check, and 0 without it, as on `main` (N8) |
| N16 | 3 | The prototype's first gate, at c5bfd9f | `test_gate.mjs`: 69.1 and 61.5 fps at 144 and 165 Hz with 0.3 ms of jitter; 45 for half a second after 120 Hz → 90; the page's chains at 60; 598 frames after a cancel (P17) |
| N17 | 1 | The counter at the bottom left | `test_frame_counter.gd`: its rect meets `Info`'s |
| N18 | 2 | Each glow a rect of its silhouette's item, as in the prototype | `test_lamps.gd`: each glow a child item at its sprite's transform |
| N19 | 2 | The cull without its margin | `test_lamps.gd`: a glow just past the view's edge shows the group |
| N20 | 1 | The counter at the theme's size, 16 | `test_frame_counter.gd`: its rect meets Settings' `Back` |
| N21 | 3 | The internal review's gate, at a08cbe9: the median of the short steps as the refresh, and n set at 8 steps | `test_gate.mjs`: at 120 Hz in whole milliseconds, 64.9 fps, with 10.1 frames a second off the cadence; 80 at 240 Hz under 9 ms of work; 65.4, 81.2 and 64.5 at 115, 170 and 230 Hz (P17) |
| N22 | 3 | `_on_tiles_freed()` moves `_lowest_row` up to the last `_hide_below`, dropping the rows that wait | `test_freed_rows_go_lowest_first_within_their_bound`: rows of the first free stay |
| N23 | 1 | `events.mjs` without its check of a case's events | `ends.json`'s grim reaper with `--seed=2`, which picks the mothman, or with `"to": "area"`, an event before `run_ended`: `events.mjs` exits 1 for each, and 0 without the check. Measured on the prototype |

### 6.3 Warnings

**The editor's.** As docs/agents/checks.md §1 says, a temporary `override.cfg` raised the 37 warnings at level 1 to errors, and `check_scripts.sh` loaded every script, on `main` (e73f96d) and on the prototype (c5bfd9f); then again without `integer_division`, so that its errors hide no other warning. `main` has five, four `INTEGER_DIVISION` and an `UNUSED_VARIABLE`, in `world/greybox_atlas.gd`:141, `ui/main.gd`:101 and three tests; `setpieces/pier.gd`, which uses the atlas, then fails to compile too. The prototype adds two, `INTEGER_DIVISION` at `world/lamps.gd`:160 and :169, the keys' midpoint and the relabel's start, which PR 2 marks (§5.2), and nothing else. Each PR runs the check, and adds none.

**The browsers'.** In Chrome, the prototype with its levers off logged 5 warnings in the City at night, the software GL's `GPU stall due to ReadPixels` and `CONTEXT_LOST_WEBGL` (checks.md §4), and with its `rs,cull` lamps none; Firefox logged one each run, the WebAssembly `try` instruction's deprecation, from the engine's build. The gate added none, and neither did the RenderingServer items' redraws (P16). `measure.mjs` counts warnings, as the browsers log WebGL's errors as warnings (docs/M2.md §5.7; P9).

### 6.4 Verified only in CI or on devices

- **CI.** Each PR's four required checks, and its `test` job's time against `main`'s 3 min 24 s (§6.1). This plan's PR changes only this file.
- **The Web, by agents** (docs/agents/checks.md §4), on each PR's local export, patched for `?arg=`: PR 1's counter in Chrome and Firefox, with `?fps` and with Settings → Show FPS, its text, its `PERF` and `EVENT` lines, and no new warning; E2's comparison on PRs 2–4 and its floors on PR 4, and E3 on PR 3 against PR 2's head (§6.5); E6's runs on PR 3, as P18's; and on PR 4, screenshots of both stretches at a pixel ratio of 2, the City by day and the Meadows at night, posted on the PR for E5, and the input at pixel ratios of 2 and 3, with the black margins: steering, Pause, the tutorial, Settings, and the Book's tap, drag and focus (§5.5).
- **Desktop runs.** E4's frames with Movie Maker, `tools/perf/movie.sh` and `diff_frames.py` (§6.5).
- **The Fold4, by the owner** (§7): E1 on both screens, E5's look, and E6's pacing in the APK, with what Android alone does (`AGENTS.md` §5). They don't hold PRs 1–3: PR 4 gathers them, with a build, and mentions @pompomon (docs/agents/planning.md §5).

### 6.5 Measurements

The browsers ran in this VM with `measure.mjs`, headed under Xvfb (checks.md §4), on release exports patched to take `?arg=`. Each run loads the build at a size and pixel ratio, starts a scene by the autopilot, with `?arg=--autopilot&arg=--seed=1&arg=--area=<area>&arg=--hour=<hour>` and the levers' switches, waits 6 s, then records 15 s, or 12 s for P1: the page's frame times, and the probe's `PERF` line, one a second. A record ends within the night, which lasts 21.25 s from 20:00. It writes a line of JSON a run, which `tab.py` tabulates. P1, P8 and P10 ran once a case, and P8's second pair three times; P15 two to four times, and P18 and P19 twice. The frame rates below are the page's frames over the 15 s, within 0.5 fps of the probe's count at 60 Hz; P15 and P18 count the probe's frames and their distance from the last, as a cap can leave the page's own chain at the screen's rate (§5.1).

```bash
tools/ci/export.sh Web /tmp/pf-web/rs/index.html release
sed -i 's/"args":\[\]/"args":["--"].concat(new URLSearchParams(location.search).getAll("arg"))/' /tmp/pf-web/rs/index.html
python3 -m http.server -d /tmp/pf-web 8000 &
xvfb-run -a -s "-screen 0 1920x1200x24" node tools/pf/measure.mjs '{"browsers":["firefox","chrome"],
  "builds":{"rs":"http://localhost:8000/rs/"},"sizes":[[360,640,2]],"scenarios":[{"area":"meadows","hour":20,
  "extra":["--pf-lamps=rs,cull","--pf-hide-budget=2","--pf-stretch=viewport"]}],"reps":2,"out":"/tmp/pf.jsonl"}'
```

On the PRs, `tools/perf/measure.mjs` and `events.mjs` take PR 1's build and the PR's in one session, with `--fps`, for the `PERF` and `EVENT` lines whose frames E2 counts, and without the `--pf-` switches, which the PRs build in.

**P1, `main`'s frame rates** (e73f96d), by day at 7:00 and at night at 20:00: the City's, then the other four areas':

| Browser | Size | Day | Night |
|---|---|---|---|
| Chrome | 360×640 | 24.5; 32.7–36.3 | 13.9; 22.7–23.8 |
| Chrome | 1280×720 | 10.9; 13.3–14.0 | 6.7; 7.9–9.4 |
| Firefox | 360×640 | 58.8; 57.8–59 | 49.6; 58.7–59 |
| Firefox | 1280×720 | 34.3; 41.4–45.5 | 21.8; 28.0–29.7 |

**P10, every lever** (E2): the prototype without its levers → with `--pf-lamps=rs,cull --pf-hide-budget=2 --pf-stretch=viewport --pf-maxfps=60`, in E1's real scenes and the City at night:

| Browser | Size and ratio | City, day | Rural, night | Meadows, night | Desert, night | Village, day | City, night |
|---|---|---|---|---|---|---|---|
| Firefox | 360×640, 1 | 58.7 → 59 | 59 → 58.9 | 58.9 → 59 | 59 → 59 | 59 → 58.9 | 50.3 → 56.0 |
| Firefox | 360×640, 2 | 29.1 → 56.9 | 24.4 → 52.8 | 25.9 → 57.3 | 25.5 → 57.2 | 34.4 → 58.4 | 19.3 → 44.0 |
| Firefox | 1280×720, 1 | 32.7 → 34.5 | 29.1 → 29.5 | 28.2 → 37.8 | 28.3 → 35.9 | 39.6 → 38.7 | 21.8 → 25.7 |
| Chrome | 360×640, 1 | 25.2 → 25.9 | 22.4 → 23.4 | 22.7 → 29.2 | 23.3 → 30.8 | 32.2 → 32.2 | 13.2 → 13.8 |
| Chrome | 360×640, 2 | 9.0 → 19.0 | 7.5 → 17.9 | 7.8 → 20.9 | 7.6 → 22.0 | 11.5 → 22.3 | 5.3 → 12.1 |

With every lever, Firefox at a pixel ratio of 2 had a median frame of 17.1 ms in each real scene, and a P95 of 17.5–17.7 ms but in Rural at night, 33.9 ms, whose 52.8 fps is the nearest to E2's bound. The City at night drew 43 draw calls a frame in Firefox and 44 in Chrome, against about 200. A 1280×720 window keeps a scale of 1, so the stretch doesn't change it, and E2 leaves that size out (Y10): there the Village by day ran 0.9 fps slower, in one run each.

| P# | What | Result | Used by |
|---|---|---|---|
| P1 | `main`'s frame rates (above) | The City is the slowest but in Firefox at 360×640 by day, near 60; each area is slower at night | Y1, Y2, Y7, Y11 |
| P2 | Layers hidden with `--pf-hide=`, Chrome, the City at 360×640 | By day 24.4 fps; without the shadows 35.4–39.6; without the props and shadows 46.2. At night 13.9; without the lamps 19.8; without the lamps, the veil and the shadows 29.1–29.9 | Q1, Y3 |
| P3 | SwiftShader's floor | An empty frame takes 8.5 ms, and each `CanvasGroup` 9–11 ms more | Y1, Q1 |
| P4 | The probe's times and Godot's draw calls | The main thread takes 3–9 ms a frame on `main`, and 2–4 with every lever; its scripts 0.2–2.5 ms. The City at night: 204 draw calls and 6.82 ms to issue them in Chrome, and with the prototype's `rs,cull` lamps 45 and 3.06 ms | Y3, Y13, §5.7 |
| P5 | The suite with each lever on | §6.1 | §4, §5.6 |
| P6 | `--pf-nosort`: Props without its y-sort | No change beyond the runs' spread | Y13 |
| P7 | `--pf-direct`: the root drawn straight to the screen | `ERROR: Condition "rt->direct_to_screen" is true`, from `render_target_clear_back_buffer` | Y14 |
| P8 | `main`'s lamps, `rs,cull`, `viewport`, and both, at 360×640 and a pixel ratio of 2 | Chrome, the City at night: 5.4, 5.4, 11.4, 11.8. Firefox, the City at night: 18.3, 19.5, 41.0, 42.9; the Meadows at night: 24.6, 32.9, 56.1, 56.1; the City by day: 31.8, 29.3, 54.7, 53.1. By day again, `main`'s lamps and `rs,cull`, three runs each by the `PERF` lines: Firefox 28.0–29.7 and 28.5–29.4, Chrome 9.1–9.2 and 9.0–9.2, so the first pair's 2.5 fps was noise | Y2, Q2, Q6, E2 |
| P9 | What the browsers log | WebGL's errors come as warnings (§6.3) | §4.3 |
| P10 | Every lever (above) | E2's tables | E2, Q1 |
| P11 | The fold (Q10), Firefox at 1280×720 | The City at night 48.3 fps, the Meadows 58.9 | Y10, Q10 |
| P12 | The prototype's `rs,cull` lamps, rects of the silhouettes' items, against `main`'s, Movie Maker at 360×640 | Identical: the City at night, 300 frames of 300; the Meadows and Rural at night, 900 of 900. A control without lamps differed in 300 of 300 | E4, Q6 |
| P13 | The work of hiding and making rows, by the probe's `PFSPIKE` lines, not frames (P13b) | The first free's 21 rows took 31–38 ms in Chrome, and with the budget 1.2–2.4 ms a frame. Rows 25–44, made while the pools are empty: 6–9 ms a row in Chrome and 6–21 in Firefox; later rows 3–8 ms | Y4, Y8, Y9 |
| P13b | Frames at the first free: `hitch.mjs` times the page's frames from its load, with the log's lines; the City by day at 360×640, without and with the budget, 8 runs each | The first free: 7.76–8.03 s after the engine's first line, as `hitch.mjs` saw it, 27–37 ms of work, 1.3–1.7 ms a row. Firefox's frame there: 33.4–34.8 ms without the budget, in each run; with it, none over 25 ms from 7 s to 12 s, the longest 17.8. The first rows' making: frames of 33.5–34.7 ms, 1.7–5.9 s in, in 3 runs of 16. Chrome: frames of 66.7 ms at random either way | Y4, Y8, E3 |
| P14 | `--pf-hide-budget=2` against 0, Movie Maker | 720 frames of 720 identical. The first budget differed in 183, frames 6–188 (§4.3) | E4, N10 |
| P15 | Pacing at 120 Hz in Firefox (`layout.frame_rate`), the City by day, with every layer hidden and with none | Uncapped with every layer hidden: 119.7 fps. Frames a second off the 16.7 ms cadence: Godot's limiter 0.41–1.86 hidden and 1.2–5.73 with every layer; the first gate 0.40–0.60 and 0.61–1.2 | Y5, §5.4 |
| P16 | Warnings, with and without the levers | §6.3 | §5.2 |
| P17 | The gate in simulation: the prototype's `tools/pf/sim_gate.mjs`, with §5.4's cases for `test_gate.mjs` but the installs, and with one cancel, checked from 50 ms after it | §5.4's gate met each: 57.5, 85 and 57.5 fps at 115, 170 and 230 Hz; 60 at 240 Hz under 9 ms of work; with the City's bursts, 58.6 steps a second shown against 58.1 uncapped, and 1.8 frames off the cadence against 25; after a switch, 73.6–74.5 fps for half a second. The limiter's rule and the earlier gates fail them: N13, N16, N21 | Y5, §5.4 |
| P18 | §5.4's gate, at d7f4d77, at 360×640 and a pixel ratio of 1, two runs each: in Firefox at 120 Hz (`layout.frame_rate`) and 60 Hz, and in Chrome at 60 Hz | At 120 Hz, the City by day 59.89–59.91 fps and the Meadows at night 59.92–59.97, against 83.9–86.1 and 77.1–79.0 uncapped, with 0.13–0.6 frames a second early; the City at night 50.05 on average, against 50.8. The page's chain ran at 117.6–119.1 fps. At 60 Hz, the City by day: 59.91–59.97 fps in Firefox and 24.6–24.9 in Chrome, against 59.87–59.93 and 24.5–24.9 uncapped; n was 1, and the gate skipped only its 8 calibration frames | Y5, E6, §5.4 |
| P19 | a08cbe9's gate, Godot's limiter and no cap at 60 Hz, Firefox at 360×640 and a pixel ratio of 2 with PRs 2–4's levers, two runs each | The City by day 53.2, 53.15 and 54.0 fps; Rural at night 51.25, 51.45 and 52.55. That gate skipped no frame, and §5.4's skips only its 8 calibration frames (P18), so P10, capped by the limiter, stands for it. Its capped runs ran 1.2–4.4 fps under P10's same cases, their means 1.4–3.8: the spread between sessions | E2, §5.4, §8 |
| P20 | The ends (Q12), by the prototype's `tools/pf/events.mjs` at f6e9083 and 78ee7a0: the page's frames from the probe's `run_ended` line to its `game_over`, at 360×640, in `tools/pf/ends.json`'s 17 cases, each run checked for its legend or arrival (N23). A legend: `--play` and a seed that picks it on a new save, in its real scene's light; its turn came 2.2–4.1 s after the `area` line in Firefox and 2.3–4.4 in Chrome, among the first rows (Y8), and its end lasted 3.05–3.52 s in Firefox and 3.05–3.72 in Chrome, whose long frames can lose game time, as Godot runs at most 8 physics steps a frame. The arrival: `--area=coast --collected=all`, by day and at 20:00; the clock holds at dusk (`Tuning.ARRIVAL_HOUR`), whose light it reaches within 2.4 s of game time (`Tuning.LIGHT_MAX_RATE`) | Firefox at a pixel ratio of 2, two runs a case in one session, without → with every lever: the legends 24.1–35.5 → 48.6–58.5 fps, each one's slowest second in its two runs 46–58, up to 8.2 fps under their area's drive in P10 (the City's grim reaper); the arrival 35.1–38.2 → 58.2–58.6. At 1, with them: 58.1–59.0. Chrome at 2, one run a case: 7.0–13.1 → 16.6–25.7. Hiding the legends' layer or the UI, in two runs each of the grim reaper and Rural's UFO in one session, moved a case's mean by −1.5 to +5.4 fps, while its two runs with nothing hidden differed by 4.4–6.6, so this check of what shows named no part | Q12, E1, E2 |

---

## 7. Owner actions

| When | Action | How |
|---|---|---|
| Now, if wanted | Read today's frame rate on the Fold4, to compare with §5.7 and later with PF | §5.7's "Today": https://pompomon.github.io/roadgame/ in Chrome, and DevTools' frame rendering stats over USB |
| Now | Merge this plan's PR, which approves it with Q1–Q12's defaults; or answer a Q# in a PR comment, which the plan takes first | Squash it |
| Now, if wanted | Play the prototype | `gh workflow run ci.yml -R pompomon/roadgame --ref pf/prototype -f upload-builds=true`, then checks.md §4's download, patch and server, with `adb reverse tcp:8000 tcp:8000`, and `http://localhost:8000/?arg=--pf-overlay&arg=--pf-lamps=rs,cull&arg=--pf-hide-budget=2&arg=--pf-gate=60&arg=--pf-stretch=viewport`; without the `--pf-` switches but the overlay, it is `main` |
| After PR 1, before PR 2 lands | E1's baseline, if wanted: `main` with the counter | On Pages, Settings → Show FPS or `?fps`, on both screens, in §5.7's scenes: the City from Play, and the others from the title's "Start in" button, which offers the areas found (docs/ZONE_SELECT.md Z4), at 32.5 s into the zone for its night. The template below, in a comment on PR 2, which a PR comment asks agents to hold until then |
| Before landing PR 4 | E5 and E1, and E6 on the APK with checks.md :38's Android checks | `gh workflow run ci.yml -R pompomon/roadgame --ref pf/4-stretch -f upload-builds=true`. Within a day, as its artifacts are kept 1 day: its `web` build, patched and served as the prototype's, above, with `http://localhost:8000/?fps&stretch=viewport&arg=--autopilot&arg=--seed=1&arg=--area=<city, village, rural, meadows or desert>&arg=--hour=<7 by day, 20 at night>`, read from 6 s after the start (E1), then with `stretch=canvas_items`, on both screens and in a desktop browser with a GPU; for E1's ends, with these as its `arg=`s: `arg=--play&arg=--seed=1&arg=--area=city&arg=--hour=7`, a legend in the City by day, without steering, `arg=--play&arg=--seed=11&arg=--area=rural&arg=--hour=20`, one in Rural at night, and `arg=--autopilot&arg=--seed=1&arg=--area=coast&arg=--collected=all&arg=--hour=20`, the arrival; and its APK in play, with Settings → Show FPS and Developer options → Show refresh rate, for E6. Then land it, or comment |
| After PR 4 | Land PR 5, the docs, the owner's paths and PF's learnings | Review the guidelines it changes (planning.md §7), then squash it |
| After PR 5 | Tag the prototype, which this plan cites, and delete PF's branches, which GitHub doesn't delete on merge | `git fetch origin pf/prototype && git push origin FETCH_HEAD:refs/tags/archive/pf/prototype`, then `git push origin --delete pf/plan pf/prototype pf/1-measure pf/2-lamps pf/3-pacing pf/4-stretch pf/5-docs`, once no open PR is based on them |

**E1's template,** a comment a build:

```
Build: main on Pages, or PR 4's CI build at <sha>, stretch=<mode>, or its APK
Device: Fold4, <cover or inner>, <portrait or landscape>, Motion smoothness <Adaptive or Standard>; or a desktop and its GPU
Browser: <name and version>
Page: innerWidth × innerHeight and devicePixelRatio, from DevTools' console
Scene: <area>, <day or night>, <the drive, a legend or the arrival>, <cold, or after 10 minutes' play>
Readings: 10 in a row, one a second, each "<fps> FPS, P95 <ms> MS"; for an end, those of E1
Refresh: <Hz>, as Developer options → Show refresh rate shows it
```

---

## 8. Risks

| Risk | Impact | Mitigation |
|---|---|---|
| The VM isn't a phone | The proxy's numbers, and §5.7's, are estimates; a GPU's costs differ from software's (Y1) | E1 on the Fold4 decides, with the counter; §5.7's red flags |
| Thin margins in the proxy at a pixel ratio of 2 | With every lever, Rural at night ran at 51.25–52.8 fps, with a P95 of 33.9 ms, and the City at night at 44.0, against E2's 50 and 40 (P10, P19); sessions' means differed by up to 3.8 fps, one session's runs of a case by up to 1.7 (P8), and an end's with every lever by up to 6.6 (P20), so a change of a few fps could cross them | E2's further runs where a case's two fail; if PR 4's head still crosses a floor, its PR reports it, and the owner accepts it or a PR 6 takes Q1's alternative (§9) |
| The gate relies on Emscripten's main loop calling `window.requestAnimationFrame` each frame, and on nothing asking for a frame between the gate's install and the loop's first request | A later Godot that keeps its own reference would skip the gate: no cap on the Web, as today. Code that asked for a frame there would have its own chain paced, and not the game's | On each Godot upgrade, or a custom shell, P18's run at 120 Hz; `window.__framePacing` records n and the frames it skips |
| `Engine.max_fps` paces Android unevenly at 120 Hz | Frames of 25 ms among the 16.7 ms ones, as on the Web (P15) | E6's reading on the APK; if its P95 is over 20 ms, `cap()` gives 0 on Android, one line, once the owner changes E6 |
| The `viewport` stretch's look | What moves steps by the game's pixel: halves of an art pixel on the inner screen, whole ones on the cover (§5.5) | E5 on both screens, with `?stretch=`; the owner lands PR 4; reverting it is one line |
| Software rendering on a desktop | Chrome without a GPU, or with one on its blocklist, draws with SwiftShader: 17.9–22.3 fps at a pixel ratio of 2 with every lever (P10) | Out of E1's scope (Q1); a "low" setting (§9) |
| Heat | Slower frames after 10 minutes or more, by an amount no one has measured (§5.7) | The owner reads E1 again after 10 minutes' play |
| The items' order | A repeated key, or a node child of `Lamps`, draws a glow in the wrong order, as Godot's sort of the draw index isn't stable | N5's test; §5.2's rule, in `lamps.gd`'s comments |
| A leaked item | Godot only warns, and no check fails on it (N8) | N8's test; PR 5 makes `run_tests.sh` fail on the warning |
| Chrome's scale on the inner screen | Its page may be under 1920 pixels tall, at a scale of 2, with wider margins than the APK's (§5.7) | E5 reads it; the margins are black, as now |

---

## 9. Notes for later work

- **The fold** (Q10, Y10). The world in a `SubViewport` at its art's resolution, scaled up by the camera's zoom, with the UI at the window's: Firefox at 1280×720 ran at 48.3–58.9 fps with it (P11). It changes how the camera, the HUD and the touch zones map to the screen, so it is a plan of its own.
- **A "low" setting** (Q1). Shadows drawn without their group, and the night without the lamps' group and the veil, for software rendering: the City ran at 35.4–39.6 fps by day and 29.1–29.9 at night in Chrome (P2). Overlapping shadows would draw darker, so it changes the look.
- **Physics interpolation** (Q3). Godot 4.7.2's, in 2D, would let a 120 Hz screen show 120 distinct frames, at twice the GPU's work; each node that moves in `_physics_process` would need checking.
- **The pools filled while a run loads** (Y8, Q7), to take the first 6 s' rows of 6–21 ms (P13).
- **M7's device QA** (IP §4 M7). Show FPS gives each QA pass a frame rate to record, on both screens, folded and unfolded.
