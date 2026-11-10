# M5 Content — Detailed Plan

Status: approved, with the Q1–Q11 defaults; implemented in #39–#44, with the review fixes in §4.6 · 2026-11-10 · Scope: `IMPLEMENTATION_PLAN.md` (below: **IP**) §3 M5 row, §4 M5.1–M5.5 and "M5 tests", §9's line on the atlas, the collection and the settings, and M4_PLAN.md §9's notes for M5

**Verified, not just reviewed.** Every file this plan adds or changes exists on branch `m5/prototype`, which has one commit per PR (§4.1): 791190d, 1fe7021, f30beb5, 89a3732, 40a77c4 and 132d464, on top of `main` (18fd716). Each commit's state passed the five local checks (§6.1), and the stacked landing was simulated (§4.5). Each of the 50 negative cases in §6.2 failed its checks: 49 on the prototype's last commit, and N36 by hand. CI on the prototype passed all five jobs (§6.4), and its Web build ran in Chrome and Firefox: the title and its screens, a run through the City, the tunnel and Rural with the new art and props, a disaster, and a save that survives a reload, with no errors, and its sound no longer clips (§6.5, L29). The editor reports no warnings that `main` doesn't (§6.3), and leaves the tree as it found it (L28). A model of another family, gpt-6.1-sol, reviewed the plan, the prototype and each later fix (`AGENTS.md` §7). The fixes of its findings are in the PRs' commits, with their tests and negative cases (§4.6). Its reviews of the PRs brought six more fixes, which the PRs add as later commits, with N51–N56, and running the negative cases on the PRs changed N16. Copilot's reviews of the PRs brought five more, R8–R12, with N57–N63 (§4.6). On the PRs' final heads, all 63 negative cases fail their checks, and the landing simulates cleanly again (§6.6).

- Godot 4.7.2-stable (Linux x86_64)
- GUT 9.7.1
- gdtoolkit 4.5.0 on Python 3.12
- shellcheck 0.11.0
- actionlint 1.7.12
- Chrome 157, headless and headed, and Firefox 159, headed under Xvfb, driven by Playwright

The Galaxy Z Fold4 couldn't be used here, and nobody has listened to the sound yet, though P12 measured its level on the Web (L29). Both are E14's checks in PR 6 (§6.4). On the Web, P13 checked pausing, losing focus, reloading and the title's navigation, and found that a page that closes or reloads tells the game nothing (L10).

**Precedence.** For M5, this document replaces IP §4 M5 wherever they differ. Each difference is marked **Δ** with its finding number (L#, §2). Where it differs from `plan.md`, it says so too (L2, L3, L18, L23). Once this plan is approved, fold the changes back into IP and `plan.md` (Q10).

**Reference code (Q10).** This plan has no appendices. Each PR cherry-picks its own commit of `m5/prototype` (§4.1), which never gets a PR of its own. Pushes to it start no CI: the runs in §6.4 were started by hand.

**Prerequisites.** M4 is merged (#35–#37). No repository settings change.

Contents:
1. Goal and exit criteria
2. Review findings
3. Decisions and open questions
4. Work breakdown (6 PRs)
5. Design
6. Verification
7. Owner actions
8. M5 risks
9. Notes for later milestones

---

## 1. Goal and exit criteria

Goal (IP §3): "Final art and audio, Atlas, disaster collection, settings, save file". After M4 the game plays from start to end, but it is grey, silent and forgetful: each launch starts a run at once, nothing records a run or a disaster, and Android's back button quits from anywhere. In M5 the game starts on a title with the Atlas, the disaster collection and the settings, kept in a save file that survives restarts. Each area has its music and ambience, and the car, the junctions, the damage and the disasters have their sounds. Each area has its road, ground and props, and the car, its skid marks and the UI get their art and a pixel font. The art and the audio are placeholders made by scripts, to contracts that tests check, so that final files can replace them one at a time (Q1). The set pieces and the disasters keep M4's look (Q2), and the orientation and vibration settings take effect in M6 (Q3).

| # | Exit criterion | Checked by |
|---|---|---|
| E1 | The save holds `plan.md` §9's schema at version 1, with the atlas's best turns and each disaster's first distance and turns (L18). `SaveData` reads any text without an error line. A file without a version is version 0 (Q8), and each older version migrates in order. A value of the wrong type or out of range keeps its default, with a note. Text that isn't a save object is corrupt, and a file from a later version is read as far as this version knows it (L5, L6, L9) | `test_save_data.gd` |
| E2 | `SaveService` writes `save.json` through `save.json.tmp` and a rename, in one frame (L11): at once when a run ends or a disaster starts, and a setting 0.5 s after its last change, or at once when the app closes, pauses or loses focus (L10; the Web reports only the loss of focus). Reading removes a stale `.tmp`. A corrupt file is kept as `save.json.bak` and the defaults are written at once. A later version's file is never written over. A failed write is a warning (L9, L11) | `test_save_service.gd`, `test_wrong_turn_disaster.gd` |
| E3 | The tests and the autopilot never read or write the player's save (L1) | `test_save_service.gd`, `smoke.sh` |
| E4 | The game starts on a title: Play, Atlas, Disasters, Settings and the best run. The Atlas shows the five areas in the order a run reaches them, each a silhouette until a run reaches it, then with its colour and the most distance and turns a run made in it (L8). The collection shows the four disasters, silhouettes until seen, then how often and where each was first seen. Settings has the three volumes, vibration and the screen's orientation (Q3). Each screen fits a 360×640 portrait screen with its longest texts, and what they show survives a restart (IP §9) | `test_title_screen.gd`, `test_atlas_screen.gd`, `test_collection_screen.gd`, `test_settings_screen.gd`, `test_title.gd` |
| E5 | Play starts one run, which doesn't steer until the player does. Game over offers Title as well as Retry. Android's back button: a screen of the title goes back to it, the title quits, a run pauses, game over goes to the title, and nothing else reacts (L13, Q5). Esc does the same on the title's screens. `--autopilot`, and the new `--play`, start a run at once, as M4's game did | `test_title.gd`, `test_game_over.gd` |
| E6 | Nothing comes or goes in view: while the autopilot drives, no road tile, set piece or row of props is added or freed within a screen row (32 px) of what the tallest (360×922) or the widest (1639×640) reference view shows, nor of where the camera heads. Those two views hold the other five, and each row's props reach past both sides of them (L2) | `test_props_in_view.gd`, `test_prop_scatter.gd` |
| E7 | `AudioDirector` plays each area's music and ambient loop, cross-fading them in `CROSS_FADE_SECONDS` (1.5 s) on `area_changed` (L22). The engine runs from a run's start to its end, its pitch from 0.8 standing to 1.6 at the speed cap (L21). Leaving the road screeches and rumbles until the car is back, each turn made chimes, the health thumps each time it falls past a multiple of 10, and a crash and each disaster as it starts have their sounds (L7). The SFX bus's reverb is on only while the car is in a tunnel. Volumes follow the settings as they change. Music and ambience go on while paused; the car's sounds pause. No sound peaks above its kind's budget (L29) | `test_audio_director.gd`, `test_cross_fade.gd`, `test_audio.gd` |
| E8 | Headless runs play no sound, so neither the tests nor `smoke.sh` leak at exit (L15). `lint.sh` lints `audio/`, and fails on a script in a directory it doesn't list (L16) | `smoke.sh`, `run_tests.sh`, `lint.sh` |
| E9 | Each area has a road sheet in the grey box's layout, opaque exactly where its road is; a seamless ground that covers the screen and stays put in the world; and an edge that blends it into the last area's ground over `TRANSITION_TILES` (2) path tiles (L3, L4). An area without art draws a checker of its colour. Every PNG under `assets/` uses only the palette's 32 colours and imports lossless, without mipmaps (L25). A crash's smoke shows over everything the world draws | `test_area_art.gd`, `test_greybox_atlas.gd`, `test_world_renderer.gd`, `test_car_controller.gd` |
| E10 | Each area has 6–10 props, some animated, beside the road, placed from the run's props seed: a seed places the same props on every run, and they take nothing from the road's stream. No prop's frame touches a road tile, whether made before or after its row, and none stands near a set piece. Over 1,000 rows, `PropPool` makes no more sprites than a row shows (L14, L24) | `test_prop_layout.gd`, `test_prop_pool.gd`, `test_prop_scatter.gd`, `test_prop_art.gd` |
| E11 | The props y-sort with the car in `World/Props`. A retry starts the next run with one car and that run's props (L12) | `test_retry.gd`, `test_main_scene_boot.gd`, `test_title.gd` |
| E12 | The car is a sheet of 16 directions and a wreck: the body shows the frame of each heading, and a crash shows the wreck and smokes, with nothing redrawn. While the car brakes for a junction above its target speed, its rear wheels leave skid marks on the road, at most `SKID_MARKS` (256), which go with their tiles and with a retry. The UI uses Pixel Operator 8, embedded so that it loads before an import (L17), crisp and on the font's grid, in the palette's colours | `test_car_art.gd`, `test_car_controller.gd`, `test_skid_marks.gd`, `test_ui_theme.gd`, `test_smoke.gd` |
| E13 | The main scene still boots and drives: the smoke run prints `autopilot: tile 165, turns 35, area rural`, as in M4, and no error lines | `test_main_scene_boot.gd`, `smoke.sh` |
| E14 | Manual: the Web build in Chrome and Firefox, and the Fold4's APK and Chrome. The title and its screens, a run's sound, art and props, the back button, and a save that survives a reload and a restart. No errors in the console or `adb logcat` | PR 6 (§4, PR 6 step 2) |
| E15 | All five required checks are green. The editor reports no new warnings | PR checks; §6.3 |

---

## 2. Review findings

IP's M5 design holds up in its parts: a versioned save with migrations and atomic writes, an audio director on the event bus, a pool of props, and menus over the save. The problems are where they meet M1–M4's code and the platforms: tests that would write the player's save, a buffer that frees road in view, a ground that ends at the road's edge, a Web file system that doesn't persist a rename, and a back button that quits.

- **High:** following IP gives a broken game, or a check that passes when it shouldn't.
- **Medium:** fragile, missing from the code it depends on, or broken in some order of events.
- **Low:** clarity, naming or polish.

"Prototype" means the problem was reproduced with Godot 4.7.2 on `m5/prototype`, with the probes P1–P13 (§6.5) or the negative cases N# (§6.2). Line numbers are `main`'s (18fd716) in the repository's files, and the 4.7.2-stable tag's in Godot's.

### High

| # | Finding | Evidence | Fix |
|---|---|---|---|
| L1 | IP M5.4's `SaveService` reads and writes `user://save.json`. GUT boots the main scene and ends runs in many tests, and `smoke.sh` drives the autopilot for 60 s. Each would read the developer's save, so results would depend on it, and write test runs into it. | On Linux `user://` is `~/.local/share/godot/app_userdata/Road Roguelike/`, which the editor, the tests and the game share (P4). `tests/helpers/main_scene.gd` boots `main.tscn`. Prototype: N1, N2 | `SaveService.use_memory()` keeps the save in memory and writes nothing. GUT's pre-run hook `tests/gut_pre_run.gd` (`.gutconfig.json`) calls it before any test, and `--autopilot` too. `test_save_service.gd` writes only its own files (`use_file()`), and its first test checks the hook. `smoke.sh` points `XDG_DATA_HOME` at a scratch `save.json` that isn't JSON: reading it would rename it to `.bak`, so the check sees a read as well as a write (E3) |
| L2 | `plan.md` §3.4's buffer frees road tiles where the camera shows them: 5 path tiles behind the car's tile, and refills at 25 ahead. M5's props, which come and go with the road, would do the same. | P1: in 3 runs of 40 s, 292–330 of the 549 frees happened in view on the 360-wide portrait screens, and 5–293 on the others. Prototype: N18–N21 | **Δ `plan.md` §3.4, §11, IP M1.5:** `BUFFER_BEHIND` 14, `BUFFER_REFILL_AT` 30, `BUFFER_AHEAD` 55, so the lookahead stays within 30–55. A row of props shows once the car is `PROP_AHEAD` (24) path tiles before it, which needs `PROP_AHEAD + PropLayout.rows_needed()` ≤ `BUFFER_REFILL_AT`, and its props reach `PROP_SPREAD` (9) tiles either side. In the test's drives, nothing came or went nearer than 60 px to the tallest view, or 187 px to the widest (P1, P2, E6) |
| L3 | IP's ground is drawn per road tile: `GroundLayer` cells under each tile, freed with it, with 3–4 variants and transition tiles (IP M5.1, `plan.md` §5.3). Beside the road the screen shows the clear colour, as in the grey box, so the props that stand there (L14) would stand on nothing. | `world_renderer.gd:88–98` sets and erases the ground cells with their tile. Screenshots of M4 on the Web (M4_PLAN.md §6.5) | **Δ IP M1.6, M4.3, M5.1, `plan.md` §5.3:** ground bands. A `Sprite2D` per area of the road repeats the area's ground across the screen, anchored in the world, the newest over the older ones. Each starts with an edge strip that blends it into the last area's ground. No variants or transition tiles: the ground holds its own variety (§5.5, E9) |
| L11 | On the Web, `user://` lives in IndexedDB, and Godot syncs it after a file opened for writing closes, or is removed, but not after a rename. IP's atomic write ends with a rename, so the new save would reach IndexedDB only with a later write. | `platform/web/os_web.cpp:227–251` schedules the sync when a file opened for writing closes, and on a remove; `:81–85` runs it at the start of the next frame. `DirAccessUnix::rename` (`drivers/unix/dir_access_unix.cpp:401`) schedules none. Prototype: N7 | Write the `.tmp`, close it and rename it in one call, so the sync that the close schedules runs after the rename. After renaming a corrupt file to `.bak`, write the defaults at once, for the same reason. If the rename fails, keep the file and never write over it: `DirAccessUnix::rename` (`:401–423`) returns the error without a line (P4; N7, N44, E2) |
| L13 | Godot's `application/config/quit_on_go_back` is on by default, so Android's back button quits the game from every screen, a run included. | `scene/main/scene_tree.cpp:899–903` quits on back while it is set; `core/config/project_settings.cpp:1709` defaults it to true. Prototype: N8 | `quit_on_go_back=false`, and `main.gd` handles `NOTIFICATION_WM_GO_BACK_REQUEST` with `go_back()`: a screen of the title closes, the title quits, a run pauses, game over goes to the title, and the other states do nothing (Q5, E5) |
| L15 | A sound that still plays when Godot quits leaks: GUT and `smoke.sh` then report `2 ObjectDB instances were leaked` and `1 resources still in use at exit`, and `run_tests.sh` and `smoke.sh` fail. Headless runs use the Dummy audio driver, which plays as any other. | P3. `servers/audio/audio_server.cpp:1288–1321`: stopping a playback only marks it for deletion, which a later mix step does (`:534–538`); `finish()` (`:1653–1663`) frees no playback. Prototype: N11 | `AudioDirector.can_play` is false on the Dummy driver: everything else runs, so the tests check the players, the fades and the pitch. A test that turns it on stops every sound and waits 0.25 s before the run ends (§5.4, E8) |
| L17 | A project theme (`gui/theme/custom`) loads when Godot starts, before the import. A theme that uses an imported TTF fails on a fresh clone, and with it the CI's `import.sh`. | P5. `scene/theme/theme_db.cpp:69–75` loads the theme at start-up, and prints an error if it can't. Prototype: N28 | The font is a `FontFile` resource with its data embedded, `assets/fonts/pixel_operator_8.tres`, made by `tools/art/make_font.gd` from the TTF, so it needs no import (§5.8, E12) |

### Medium

| # | Finding | Evidence | Fix |
|---|---|---|---|
| L4 | IP M5.1 lists the art but gives it no contract: which pixels are road, how the ground repeats, how an edge blends. Final art could then break the road's look in ways that nothing checks. | IP M5.1; `greybox_atlas.gd` builds the road from `RoadGeometry` | `test_area_art.gd` holds each area's art to the grey box's layout: a road sheet opaque exactly where the grey box's road is, a ground that repeats with the ground cells, an edge that is its ground's first rows thinning out, and the palette and import rules (§5.5, E9) |
| L5 | IP M5.4 fills missing keys with defaults, but says nothing of wrong values. A float assigned to a typed `int` truncates without a word, and a `String` raises a SCRIPT ERROR. Nor does it bound them: `int(1e20)` is −2^63, and so are the HUD's metres for a distance of 1e308. | P4 | `SaveData` checks each value's type and range. One it can't use keeps its default and adds a line to `problems`, which `SaveService` reports as one warning. Counts must be whole numbers, and counts and distances at most `MAX_NUMBER`, 2^53 − 1, the largest whole number that a JSON number holds exactly (§5.3; N4, N43) |
| L6 | IP's "parse JSON": `JSON.parse_string()` prints an `ERROR:` line for text that isn't JSON, which fails CI's scripts and the GUT test that reads it. | `core/io/json.cpp:629`. P4. Prototype: N3 | `JSON.new().parse()`, which reports through its return value and `get_error_message()` (§5.3) |
| L7 | IP's `record_disaster(id, area, stats)` has no caller. `DisasterDirector` picks the disaster inside `play_disaster()`, and `EventBus.disaster_triggered` comes before the pick. | `disaster_director.gd:44, 102`; `event_bus.gd:15` | `DisasterDirector.disaster_started(disaster, area)` when it plays it; `main.gd` relays `EventBus.disaster_started(id, area)`. `SaveService` records it at once and `AudioDirector` plays its sound. **Δ IP M5.4:** recorded when it starts, so a player who closes the app during the disaster keeps it (N5) |
| L8 | IP's `record_run(stats)` updates the atlas from the run's stats, which name only the last area. A run through three areas would discover only the last, and give it all the run's distance. Nor can an area simply start where the car is when `area_changed` comes: in that step, `CarSim` reports the area before it judges the turn at the junction behind it, and off the road the car can reach the area's tiles before its distance does. Where no set piece lies between two areas, as before the Village and the Desert, the turn would count for the new area. | `game_state.gd:86–91`; `car_sim.gd:90` updates the path, and emits `area_changed` (`:229`), before `:98` judges the turn. Prototype: N40 gave the Village 19 of its 20 turns | `GameState.enter_area(id, start_distance, start_turns)` records where each area begins: `main.gd` finds the area's first tile in the buffer, at the distance of its near edge, and the turns of the junctions before it. `stats()["areas"]` gives each the distance and turns from its start up to the next area's start, or the run's own if they are less, and never below 0. `record_run` discovers each and keeps, per area, the most a run made in it (N6, N40–N42) |
| L9 | IP doesn't say what happens to a file from a later version, say after going back to an older build. Migrations only go up, and writing would lose the later fields. | IP M5.4 | `Status.NEWER`: read it as far as this version knows it, and never write over it. A warning says so (§5.3; N38) |
| L10 | Settings are written 0.5 s after the last change. Android can kill a paused app sooner, and a window can close sooner. | IP M5.4. P13 | `flush()` writes at once on close, on pause, on losing focus and on exit. The Web never sends `NOTIFICATION_APPLICATION_FOCUS_OUT` (M2 H4), so the window's focus-out counts too (§5.3; N39). Nor does it tell the game when a page closes, reloads or is hidden: 4.7.2's Web build listens for none of these (`platform/web/js/libs/library_godot_display.js:719–737`). There a setting changed less than 0.5 s before, with no loss of focus, is lost (P13), and the sync of a write to IndexedDB starts only at the next frame (L11), which a hidden tab doesn't draw. Settings writes when it closes, so M5 accepts this (§9) |
| L14 | IP's generator draws each road tile's props from its `rng_props` stream into `tile.decor` as it makes the tile. Props stand up to 9 tiles beside the road (L2), where road made later can pass, and a prop drawn with its tile can't keep off road that doesn't exist yet. A stream drawn tile by tile also makes each prop depend on every draw before it. | IP M1.4 (`rng_props`, `tile.decor`), M1.6 | **Δ IP M1.4, M5.2:** `PropLayout` places a row's props once the road `rows_needed()` rows beyond it exists, and hashes the run's `props_seed`, `hash("%d:props" % run_seed)`, with each ground cell. The road takes nothing from it (§5.6; N25, N27) |
| L16 | `lint.sh` lints a fixed list of directories. A script in a new one, such as `audio/`, skips gdlint, gdformat and the RNG rule without a word. | `tools/ci/lint.sh:9–11`. Prototype: N12, N13 | The list adds `audio/`, and `lint.sh` fails on any `.gd` outside it and `addons/` |
| L18 | `plan.md` §9's atlas keeps only the best distance, and its collection only the count and the first area. `plan.md` §2.6 and IP M5.4, M5.5 ask for best turns, and for where in its run each disaster was first seen. | `plan.md` §2.6, §9 | **Δ `plan.md` §9:** `atlas.*.best_turns`, `disasters.*.first_distance` and `first_turns` (§5.3) |
| L19 | The Web export plays sounds as samples by default, and samples skip the bus effects: no tunnel reverb on the Web. | `core/config/project_settings.cpp:1755`; `doc/classes/ProjectSettings.xml:486` | Accepted. The reverb plays on Android; E14 checks the rest on the Web |
| L20 | 4.7.2's Web samples loop by restarting: when the main thread handles a source's `ended` event, it starts a new one at once, with nothing scheduled ahead. P10 timed 144 restarts in Chrome: the next source started 15 ms after the last ended at the median, 30 ms at the 90th percentile and 144 ms at worst. The engine's 1 s loop therefore ticks about once a second on the Web, the ambience every 4 s and the music every 7.3–10.7 s. Stream playback has no such gap, but in P10 the single-threaded build's worklet ran short of mixed sound 27 times a second, so streams would crackle. 4.8 loops samples natively (godotengine/godot#123996) | `platform/web/js/libs/library_godot_audio.js:428`, `:554–559` and `:719–790`; P10 | Accepted until M6.3 or 4.8 (Q11). E14 listens for it |
| L26 | M4 left the tunnel's darkening `CanvasModulate` and the bridge's water shader to M5, and expected M5's art to replace the grey box of the set pieces and the disasters (M4_PLAN.md K18, Q4, §9). IP M5.1 and `plan.md` §5.3 list neither. | P7: 25 of the 27 colours in `setpieces/`, `disasters/`, `car.tscn` and `tuning.gd` aren't in M5's palette | Q2: M5 leaves them as they are. §9 lists them for later |
| L27 | On the Web, each restart of a sample loop (L20) starts the new source at the sound's own rate, and so does unpausing it. An engine whose pitch is set only when the speed changes plays at the WAV's pitch after its first second at a steady speed. | `library_godot_audio.js`: `_restart()` (`:719`), which `_unpause()` calls too, makes the source without `_syncPlaybackRate()` (`:710`); `setPitchScale()` (`:507–512`) syncs it. `AudioStreamPlayerInternal::set_pitch_scale()` (`audio_stream_player_internal.cpp:316–323`) passes every assignment on, unchanged or not (`audio_server.cpp:1391–1399`). P10 | `AudioDirector` assigns the engine's pitch every physics frame (§5.4; N45). In P10, each restarted source had its rate before the audio clock moved on, where before the fix 14 of 63 played at the WAV's rate for up to 0.4 s. E14 listens for it |
| L28 | Opening the editor saves `default_bus_layout.tres`, and so does a new checkout's first `import.sh` on a slow machine. Each writes a uid into its header, which leaves `git status` dirty (`AGENTS.md` §3). A later PR that commits that line changes a file that PR 3 adds (§4.5). CI doesn't check the tree, and it imports before the tests, which then read the file as the editor wrote it. | The editor's bus panel saves the layout 0.8 s after a bus effect `is_edited()` (`editor/audio/editor_audio_buses.cpp:1300–1316`, `:1594–1598`). Loading the reverb sets that flag, as `Object::set()` does in the editor's build (`core/object/object.cpp:233–237`). `_server_save()` (`:1430–1443`) then writes the uid that `ResourceUID::create_id_for_path()` seeds with the project's name, the path and the file's MD5 (`core/io/resource_uid.cpp:134–142`), so always `uid://bkp2lspkw8gej`. The panel processes from the start (`:1615`), and `--import` quits at the first frame after its first scan (`main/main.cpp:1683–1687`, `:5157–5167`): the import saves only if it outlasts the timer. P11 | PR 3's layout has that uid and is just as Godot writes it, so the saves don't change a byte (P11). `test_audio_director.gd` checks both. It reads the uid from the header, as `ResourceLoader.get_resource_uid()` also answers from the import's `.godot/uid_cache.bin` (N46, N47). CI's `test` job ends by failing if `git status --porcelain` prints anything, as it does after an import that writes the file (N48, N49) |
| L29 | Sounds that play together went past full scale, where Godot's mixer clamps each channel and the browser's output clips. Nothing set how loud each may be: the placeholders peaked at 0.5–1.0, and `damage.wav` was clipped. On the Web, samples skip the bus effects (L19), so a limiter wouldn't help there. | `servers/audio/audio_server.cpp:317`, `:323`. P12: at the default volumes the mix peaked at up to +5.7 dBFS, the autopilot's nearly always with a chime over the engine, the music and the ambience | Each kind of sound has a peak budget in `Tuning`: `MUSIC_PEAK` 0.5, `AMBIENT_PEAK` 0.25, `LOOP_PEAK` 0.15 (the engine, the rumble) and `EFFECT_PEAK` 0.25, so that at the default volumes the music, the ambience, the engine and one effect add up to 1. `make_audio.gd` scales each sound to its budget, and `test_audio_director.gd` reads each WAV's peak, which final files must keep too (Q1; N50). Cross-fades and overlapping effects can add up to more, but P12 measured nothing past full scale, and at most −1.3 dBFS (§8) |

### Low

| # | Finding | Fix |
|---|---|---|
| L12 | The tests found the car as `%Props`' only child, which the props break. | `WorldRenderer.car`; the helper's `car()` and `cars()` (N22) |
| L21 | IP has the engine in an `AudioStreamPlayer2D` in the car. With one car and a camera that follows it, that only pans it. | The engine is one of `AudioDirector`'s loops, its pitch from `CarSim` (§5.4) |
| L22 | IP doesn't say what a change of area does in the middle of a fade. | `CrossFade`: the new track fades in on the quieter deck (§5.4; N14) |
| L23 | `plan.md` §6 asks for OGG, which Godot can't write. | **Δ `plan.md` §6:** WAV in git, made by `make_audio.gd` and imported as QOA: 3.4 MB of WAV make 0.70 MB of samples |
| L24 | IP's pool pre-warms 64 nodes per prop scene. Props here are one kind of `Sprite2D`, made on demand and reused. | **Δ IP M5.2** (§5.6) |
| L25 | IP's palette check is an optional local script. | A GUT test over every `assets/**/*.png`, so CI checks it (N16) |

---

## 3. Decisions and open questions

The prototype follows the defaults. Each alternative changes the PRs named.

| # | Question | Default | Alternative |
|---|---|---|---|
| Q1 | Who makes the art and the audio? | Placeholders, made by `tools/art/make_art.gd`, `make_props.gd`, `make_car.gd`, `make_font.gd` and `tools/audio/make_audio.gd`, which run headless with a fixed seed. The tests hold any art to the same contracts (L4), and any sound to its kind's peak (L29), so final files replace them without code changes | Final art and audio before M5 lands: PRs 3–6 wait for them |
| Q2 | The set pieces, the disasters, the dust and the smoke; the tunnel's darkening and the water shader (L26) | As M2–M4 made them. Their colours are flat polygons and particles, and E14 judges how they sit with the new art | PR 4 recolours them from the palette and adds the darkening and the shader, with a test for each |
| Q3 | Orientation and vibration | Saved, and shown in Settings, but applied by M6.1 and M6.2, with the rest of the device work (IP M6) | PR 2 applies the orientation now |
| Q4 | Music on the title | Silence at launch. After a run, the title keeps that run's music and ambience, and the next run cross-fades from them | A title theme |
| Q5 | Back while paused, during a disaster or a crash | Nothing: the pause menu has Resume, and the end of a run takes 2–4 s (M4 E10) | Back resumes from the pause |
| Q6 | The best run on the title and the Atlas | "Best: 412 m, 31 turns": the most distance and the most turns, which may come from different runs | The run with the most distance, whole |
| Q7 | When the car leaves skid marks | While it brakes for a junction above the junction's target speed | Also off-road |
| Q8 | What is a version-0 save? | A file without `"version"`, with `plan.md` §9's keys. It needs no change: the keys that version 1 adds get their defaults | Treat it as corrupt |
| Q9 | Screens taller than the reference views, such as a 1:4 window | Not covered: road and props may come and go at the top and bottom. M6.1 handles windows and foldables | A larger `BUFFER_BEHIND`, with a test at 1:4 |
| Q10 | How the plan lands | Fold it into IP and `plan.md` once approved. No appendices: each PR cherry-picks its commit of `m5/prototype`. Six stacked PRs | Fewer, larger PRs |
| Q11 | The gap where a loop restarts on the Web (L20, P10) | Accepted in M5, and E14 notes how it sounds. M6.3, the Web's milestone, or Godot 4.8 fixes it | Engine and rumble loops of 4 s, not 1 s: the gaps stay, but come a quarter as often |

---

## 4. Work breakdown

There are six PRs, and each one leaves CI green (E15). The estimate is about 6 days, at the top of IP's size "L" (4–6 days): the code is verified, but M5 touches every layer of the game, and most of what is left to judge is how it looks and sounds on the Fold4 (E14).

```
PR 1 save ──▶ PR 2 menus ──▶ PR 3 audio ──▶ PR 4 world art ──▶ PR 5 props ──▶ PR 6 car and font
 (M5.4)        (M5.5)         (M5.3)         (M5.1: road,        (M5.1's props,  (M5.1: car, skid
                                              ground, palette)    M5.2)           marks, font, theme)
 ~1 d          ~1 d           ~1 d           ~1 d                ~1.5 d          ~0.5 d
```

After PR 1 the game records each run and disaster, still without a screen that shows them. PR 2 starts the game on the title, with the Atlas, the collection and the settings. PR 3 adds the sound, PR 4 the areas' road and ground, PR 5 the props beside the road, and PR 6 the car's sheet, the skid marks and the pixel font.

### 4.1 Porting from the prototype

Each PR's changes are one commit of `m5/prototype`, so every PR follows the same steps:

1. Fetch the branches and create the PR's branch. The refspec also works in a clone that tracks only `main`:
   ```bash
   git fetch origin main '+refs/heads/m5/*:refs/remotes/origin/m5/*'
   git switch -c m5/1-save origin/main    # PRs 2–6: from the previous PR's branch (§4.5)
   ```
2. Apply the PR's commit with `git cherry-pick --no-commit <commit>`, from its section. A cherry-pick applies only that commit's changes, so it keeps the review fixes that earlier PRs made to the same files, which M4 needed `sed` for. If a fix changed the very lines that the commit changes, it stops with a conflict: keep both.
3. Run `tools/ci/import.sh`. It must create no files: `git status --porcelain` lists only the cherry-picked paths. In PRs 3–6, run the PR's generators too, `godot --headless -s tools/<dir>/make_<what>.gd`. They must reproduce the committed assets byte for byte, which they do on the prototype.
4. Run §6.1 and compare the counts with the PR's "Expect" line.
5. Have a model of another family review it (`AGENTS.md` §7). Then commit, push and open the PR.

The prototype's commits sit on `main` (18fd716) in order, so the six cherry-picks give exactly the PR states of §6.1. The PRs' diffs have 22, 43, 66, 50, 75 and 34 files. With the review fixes (§4.6), PR 1's has 24, and PR 6's 35, with this plan's sync. Each section below gives the cherry-picked commit's files and numbers; §6.6 has the final heads'.

### PR 1: Save: the save file, the runs and the disasters it records (M5.4) **Δ L1, L5–L11, L18, Q8**

Branch `m5/1-save`, from `main`. `git cherry-pick --no-commit 791190d`.

| Area | Files |
|---|---|
| Save | `autoload/save_data.gd`: the schema, the migrations, the checks and the records; `autoload/save_service.gd`: reading and writing it (§5.3) |
| Game | `autoload/game_state.gd`: `enter_area()` and `stats()["areas"]` (L8); `autoload/event_bus.gd`: `disaster_started` (L7); `disasters/disaster_director.gd`: `disaster_started`, when it plays one (L7); `ui/main.gd`: relays it, and enters each area at its first tile (L8) |
| Config | `project.godot`: the `SaveService` autoload; `config/tuning.gd`: `SETTINGS_SAVE_DELAY` |
| CI | `.gutconfig.json`: `pre_run_script`; `tools/ci/smoke.sh`: the scratch save (L1) |
| Tests | `tests/gut_pre_run.gd` (L1); `tests/unit/test_save_data.gd` (13), `test_save_service.gd` (13); 2 tests more in `test_game_state.gd`, and one in `test_disaster_director.gd`, `tests/integration/test_wrong_turn_disaster.gd` and `test_area_start.gd` |

Every new `.gd` file comes with its `.gd.uid`. Expect: `check_scripts: loaded 88 scripts`; `GUT: 300 tests passed` (146,300 asserts, 21.3–22.9 s). `smoke.sh` still prints `autopilot: tile 165, turns 35, area rural`. Negative cases N1–N7 and N38–N44.

**Acceptance:** E1–E3, E13 and E15.

### PR 2: Menus: the title, the Atlas, the collection and the settings (M5.5) **Δ L13, Q3–Q6**

Branch `m5/2-menus`, from `m5/1-save`. `git cherry-pick --no-commit 1fe7021`.

| Area | Files |
|---|---|
| UI | `ui/menu_screen.gd`, the screens' base; `ui/menu_card.gd`, `.tscn`; `ui/title_screen.gd`, `atlas_screen.gd`, `collection_screen.gd`, `settings_screen.gd` and their `.tscn` (§5.2); `ui/game_over.gd`, `.tscn`: Title |
| Game | `ui/main.gd`, `ui/main.tscn`: the title, `--play` and `go_back()` (L13); `areas/area_schedule.gd`: `areas()`, in the order a run reaches them; `disasters/disaster_base.gd` and the four disasters' `.tscn`: `display_name` |
| Config | `project.godot`: `quit_on_go_back=false` (L13) |
| Tests | `tests/integration/test_title.gd` (10); `tests/unit/test_title_screen.gd` (6), `test_atlas_screen.gd` (5), `test_collection_screen.gd` (6), `test_settings_screen.gd` (5); a test more in `test_area_schedule.gd` and `test_game_over.gd`; `test_smoke.gd`: the screens' texts in the glyph check; `tests/helpers/main_scene.gd` and `tests/integration/test_main_scene_boot.gd`: `--play`, unless a test asks for the title |

Expect: `check_scripts: loaded 99 scripts`; `GUT: 334 tests passed` (146,576 asserts, 21.9–22.5 s). The smoke line as in PR 1. Negative cases N8–N10 and N37.

**Acceptance:** E4, E5, E13 and E15.

### PR 3: Audio: music, ambience and sounds (M5.3) **Δ L15, L16, L19–L23, L27–L29, Q4**

Branch `m5/3-audio`, from `m5/2-menus`. `git cherry-pick --no-commit f30beb5`.

| Area | Files |
|---|---|
| Audio | `autoload/audio_director.gd`, with the engine's pitch set every frame (L27); `audio/cross_fade.gd`; `default_bus_layout.tres`: Music, SFX with its reverb, Ambient (§5.4), with the uid that the editor would write in (L28) |
| Assets | `assets/audio/music/<area>.wav`, `assets/audio/ambient/<area>.wav` (5 each) and `assets/audio/sfx/*.wav` (10), each with its `.import`; `tools/audio/make_audio.gd`, which makes them, each at its kind's peak (Q1, L23, L29) |
| Areas | `areas/area_def.gd`: the Audio group, `music` and `ambient_loop`; the five areas' `.tres` |
| Game | `ui/main.gd`: the director follows each run's car; `project.godot`: the `AudioDirector` autoload; `config/tuning.gd`: `CROSS_FADE_SECONDS`, `ENGINE_PITCH_MIN`, `ENGINE_PITCH_MAX`, `DAMAGE_SOUND_STEP`, and the peaks `MUSIC_PEAK`, `AMBIENT_PEAK`, `LOOP_PEAK`, `EFFECT_PEAK` (L29) |
| CI | `tools/ci/lint.sh`: `audio/`, and the check for scripts outside the linted directories (L16); `.github/workflows/ci.yml`: the `test` job's last step, which fails if the checks changed the tree (L28) |
| Tests | `tests/unit/test_audio_director.gd` (25), `test_cross_fade.gd` (8); `tests/integration/test_audio.gd` (2); `tests/helpers/pitch_spy.gd`, which counts the engine's pitch settings (L27) |

Expect: `check_scripts: loaded 106 scripts`; `GUT: 369 tests passed` (146,790 asserts, 23.1–23.2 s). The smoke line as in PR 1. Negative cases N11–N14 and N45–N50.

**Acceptance:** E7, E8, E13 and E15.

### PR 4: World art: the palette, the roads and the ground (M5.1) **Δ L3, L4, L25, Q1, Q2**

Branch `m5/4-world-art`, from `m5/3-audio`. `git cherry-pick --no-commit 89a3732`.

| Area | Files |
|---|---|
| Assets | `assets/palette.gpl` (32 colours); `assets/<area>/road.png`, `ground.png`, `edge.png` for each area, with their `.import`; `tools/art/make_art.gd`, which makes them (§5.5) |
| Areas | `areas/area_def.gd`: the Art group, `road_sheet`, `ground` and `ground_edge`; the five areas' `.tres` |
| World | `world/world.tscn`: `Ground`, a `Node2D`, replaces `GroundLayer` (L3); `world/world_renderer.gd`: the ground bands and a road source per area; `world/greybox_atlas.gd`: the checker and the edge for an area without art |
| Config | `project.godot`: `[importer_defaults]`, lossless and without mipmaps |
| Tests | `tests/unit/test_area_art.gd` (6) and `tests/helpers/art_checks.gd` (L4, L25); `test_greybox_atlas.gd` (3 tests more, 2 fewer) and `test_world_renderer.gd` (4 more, 1 fewer): the bands; `test_car_controller.gd`: the smoke shows over everything the world draws |

Expect: `check_scripts: loaded 109 scripts`; `GUT: 379 tests passed` (147,089 asserts, 24.5–25.3 s). The smoke line as in PR 1. Negative cases N15–N17.

**Acceptance:** E9, E13 and E15.

### PR 5: Props beside the road (M5.1's props, M5.2) **Δ L2, L12, L14, L24**

Branch `m5/5-props`, from `m5/4-world-art`. `git cherry-pick --no-commit 40a77c4`.

| Area | Files |
|---|---|
| Props | `areas/prop_def.gd`; six props per area in `areas/props/<area>/*.tres`; `assets/<area>/props.png`, with its `.import`; `tools/art/make_props.gd` (§5.6) |
| World | `world/prop_layout.gd`, `prop_pool.gd` and `prop_scatter.gd` (§5.6); `world/world_renderer.gd`: `car`, and the scatter (L12) |
| Areas and road | `areas/area_def.gd`: the Props group; the five areas' `.tres`; `road/road_generator.gd`: `props_seed` (L14); `road/road_buffer.gd`: a comment |
| Config | `config/tuning.gd`: the buffer (L2) and `PROP_AHEAD`, `PROP_SPREAD`, `PROP_MAX_SIZE`, `PROP_BELOW` |
| Tests | `tests/integration/test_props_in_view.gd` (3); `tests/unit/test_prop_art.gd` (2), `test_prop_layout.gd` (5), `test_prop_pool.gd` (3), `test_prop_scatter.gd` (7); `test_retry.gd`, `test_main_scene_boot.gd`, `tests/helpers/main_scene.gd`: the car among the props (L12); `test_area_schedule.gd`, `test_world_renderer.gd`: the new buffer |

Expect: `check_scripts: loaded 119 scripts`; `GUT: 399 tests passed` (147,510 asserts, 45.4–46.0 s, §8). The smoke line as in PR 1. Negative cases N18–N27.

**Acceptance:** E6, E10, E11, E13 and E15.

### PR 6: The car, skid marks, the pixel font and the theme (M5.1) **Δ L17, Q7**

Branch `m5/6-car-font`, from `m5/5-props`. `git cherry-pick --no-commit 132d464`.

| Area | Files |
|---|---|
| Car | `assets/car/car.png`, `skid.png`, with their `.import`; `tools/art/make_car.gd`; `car/car.tscn`, `car/car_controller.gd`: the sheet and the wreck (§5.7) |
| Skids | `world/skid_marks.gd`; `world/world.tscn`: `Skids`; `world/world_renderer.gd`: the marks; `config/tuning.gd`: the `SKID_*` values, and no more `CRASH_TINT` |
| UI | `assets/fonts/PixelOperator8.ttf`, its `.import` and `PixelOperator8_LICENSE.txt` (CC0); `assets/fonts/pixel_operator_8.tres` and `tools/art/make_font.gd` (L17); `ui/theme.tres`; `ui/hud.tscn`, `ui/game_over.tscn`: sizes on the font's grid (§5.8); `project.godot`: `gui/theme/custom` |
| Tests | `tests/unit/test_car_art.gd` (3), `test_skid_marks.gd` (3), `test_ui_theme.gd` (4); `test_car_controller.gd`: 2 tests for the sheet replace the tint's; `tests/integration/test_crash.gd`: the wreck's frame; `test_disasters.gd`, `test_sinkhole.gd`: no car polygon left to check; `test_world_renderer.gd`: the skids |

Expect: `check_scripts: loaded 125 scripts`; `GUT: 409 tests passed` (147,664 asserts, 47.0–48.7 s). The smoke line as in PR 1. Negative cases N28–N36.

Steps after the cherry-pick:
1. After the review fixes, `git diff --stat origin/m5/prototype -- . ':!M5_PLAN.md'` lists only them.
2. Manual checks (E14). Start a run that uploads the builds, and download them within a day (M0 F34):
   ```bash
   gh workflow run ci.yml --ref m5/6-car-font -f upload-builds=true
   gh run list -w ci.yml -b m5/6-car-font -e workflow_dispatch -L 1    # the run id
   gh run watch <run id> --exit-status
   rm -rf /tmp/roadgame-builds && gh run download <run id> -D /tmp/roadgame-builds
   python3 -m http.server -d /tmp/roadgame-builds/web 8000
   ```
   - **Web**, in Chrome and Firefox, at http://localhost:8000:
     - The title shows the four buttons, silent (Q4). The arrow keys, Enter, Esc and the mouse move between the screens, and each screen fits the window.
     - Settings: lower the music and change the screen's orientation, then close Settings and wait two seconds before reloading: both stay (L11). A reload sooner can lose the last change (L10, P13).
     - Play: the City's music and ambience start, and the engine rises with the speed. Props stand beside the road, and none touches it. Braking for a junction leaves skid marks. After the 34th turn, the tunnel, then Rural: the music and ambience cross-fade, and Rural's ground blends in over the City's.
     - Take a wrong turn in Rural: the tornado, Rural's only disaster, sounds, then game over. Title, then Atlas: the City and Rural, each with the distance and the turns driven in it (L8). Disasters: the Tornado, seen once, first in Rural. Reload: they stay.
     - Listen for the gaps where the loops restart (L20): about once a second in the engine, and at each loop of the music and the ambience. Note how they sound (Q11), and whether the mix is balanced and loud enough (L29).
     - The console shows no errors. Chrome's `GPU stall due to ReadPixels` notes and an early `CONTEXT_LOST_WEBGL` are the environment's (§6.5).
   - **Android**, on the Galaxy Z Fold4, folded and unfolded: `adb install -r "/tmp/roadgame-builds/android-Android APK/roadgame-debug.apk"`.
     - The title and its screens fit both screens, and the text is crisp.
     - The back button: a screen of the title goes back to it; the title quits; a run pauses; game over goes to the title (L13).
     - Leave a run with the home button and come back: it waits, paused, for the II button (M2 H4).
     - A run's sound: music, ambience, the engine, and the reverb in the tunnel (L19).
     - Change a setting and leave the app at once with the home button; close it from the recent apps; open it: the setting stays (L10). Take a wrong turn in the City and close the app during the sinkhole: the collection keeps it (L7).
     - `adb logcat -s godot` shows no errors.
3. After the merge, https://pompomon.github.io/roadgame/ runs the game with M5.

**Acceptance:** E12, E13, E14 and E15.

### 4.5 Landing the stack (Q10)

The PRs land by `AGENTS.md` §5's procedure for stacked PRs, with the `m5/` names: each PR targets the previous PR's branch; a review fix goes on the branch of the PR that owns the file and is merged into each later branch; only a PR whose base is `main` merges; and after PR k's squash merge, PR k+1 merges PR k's final branch and `main`. That was simulated with `git merge-tree` on the prototype's commits: no conflicts, `git diff --name-only origin/main` listed only each PR's own files, and the last squash gave the prototype's tree. Two rules keep it so:

- **No add/add conflicts.** No PR changes a file that an earlier M5 PR adds. Files that several PRs change all exist on `main`: `config/tuning.gd` (PRs 1, 3, 5, 6), `project.godot` (1–4, 6), `ui/main.gd` (1–3), `areas/area_def.gd` and the five areas' `.tres` (3–5), `world/world_renderer.gd` (4–6), `world/world.tscn` (4, 6), `ui/game_over.tscn` (2, 6), and some tests.
- **Insertions a line apart.** When PR k+1 merges `main` after PR k's squash, the merge base is the squash of PR k−1. A line that PR k+1 inserts right next to one that PR k inserts falls in the same hunk as PR k's on the other side, and the merge conflicts. The first prototype of PR 6 added its `SKID_*` constants right after PR 5's `PROP_*` ones, and its `_skids` field next to PR 5's, and both conflicted. Its commit now puts them away from PR 5's lines: the constants after `START_HEALTH`. A review fix that adds lines next to a later PR's must do the same.

If PR k's branch is already deleted, merge its last state from `git fetch origin pull/<PR k>/head`. The merges change no files in PR k+1, so the push may start no Copilot review: request it with `gh pr edit <PR k+1> --add-reviewer @copilot` if it needs one.

### 4.6 Review fixes

The internal review of this plan (`AGENTS.md` §7) and the PRs' reviews add their fixes here, each with its tests and negative case. The plan's review, by gpt-6.1-sol as `rubber-duck`, found three bugs in the prototype and a fourth on the Web, two findings without a negative case, and a wrong citation. All six were real, and so were the later findings, in the last three rows. Their fixes are in the PRs' commits (§4), so each PR starts with them:

| PR | Change | Tests | Negative case |
|---|---|---|---|
| 1 | L8: an area began where the car was when `area_changed` came, before the turn behind it was judged, so the Village lost its last turn to the Desert. `main.gd` gives `enter_area()` the area's first tile and the turns before it; `GameState` ends each area at the next one's start or the run's end, and never below 0 | `test_game_state.gd`: `test_an_area_counts_from_its_first_tile_and_the_turns_after_it`; `test_area_start.gd`: `test_each_area_counts_from_its_first_tile` | N40–N42 |
| 1 | L5: no upper bound on counts and distances, and `int(1e20)` is −2^63. They are at most `MAX_NUMBER`, 2^53 − 1 | `test_save_data.gd`: `test_numbers_past_the_largest_exact_whole_number_get_their_defaults` | N43 |
| 1 | L11: a corrupt file that couldn't be renamed to `.bak` was written over. It stays, with a warning, and is never written | `test_save_service.gd`: `test_a_corrupt_file_that_cant_be_kept_is_never_written_over` | N44 |
| 1 | L9 and L10 had tests but no negative case | `test_a_file_from_a_later_version_is_never_written_over`; `test_flush_and_leaving_the_app_write_the_settings_at_once` | N38, N39 |
| 3 | L27: on the Web, each restart of the engine's loop played at the WAV's pitch while the speed stayed the same. The pitch is set every physics frame | `test_audio_director.gd`: `test_the_engines_pitch_is_set_every_frame`, with `tests/helpers/pitch_spy.gd` | N45 |
| 3 | §5.4 named `test_audio.gd` as the test that lets sounds play; it is `test_audio_director.gd`'s | — | — |
| 3 | L28: CI imports before the tests (`.github/actions/godot-env`), and a slow runner's first import writes the uid back, so the test passes without the fix. The `test` job's last step, "Tree unchanged by the checks (git status)", fails if `git status --porcelain` prints anything | That step | N48, N49 |
| 3 | L29: the sounds that play together clipped (P12). Each kind of sound has a peak budget, which `make_audio.gd` keeps and a test checks | `test_audio_director.gd`: `test_no_sound_peaks_above_its_kinds_budget` | N50 |
| 6 | E14's Web steps expected the sinkhole after the car reached Rural, whose only disaster is the tornado (`areas/rural.tres:18`), and the whole run under the City in the Atlas. They now expect the tornado, and the City and Rural each with its part of the run. The Android steps' wrong turn is in the City | `test_disaster_pools.gd` (M4): `test_a_wrong_turn_in_each_area_plays_a_disaster_from_its_pool`; PR 1's `test_area_start.gd`: `test_each_area_counts_from_its_first_tile` | — |

The same model then reviewed these fixes as `code-review`, and found no issues. L28 came after both reviews, from §6.3's run of the editor; its fix is in PR 3's commit too. A third review, of that fix, by the same model as `code-review`, found L28's row: P11 then said that a new checkout's first import writes the uid, and CI imports before the tests. Measured again, a first import writes it only under load, and the test then passes (P11, N48). Copilot's first review of this plan's PR found the last row. Its second called the sound unverified: P12 measured its level on the Web and found L29. The same model reviewed that fix and found no issues. Copilot's third review asked for the Fold4's checks of pausing, losing focus, closing and navigating, which are E14's (§7). P13 ran them on the Web, and found L10's limit there. The same model, as `rubber-duck`, then found that E14's Web step reloaded too soon after the settings changed; it now closes Settings and waits (P13).

The PRs' internal reviews, by the same model as `code-review`, found R1–R4 and R6 below; on PR 1's state, N2 also showed R3. Running the negative cases on each PR's state found R5. A review of those fixes found R7, and claimed that R1's read-back prints an error line when the `.tmp` can't be opened: in 4.7.2 the script binding of `FileAccess.get_file_as_string()` passes an error pointer (`core/io/file_access.h:281`), so it returns `""` without one, and a test whose `_store()` deleted the `.tmp` passed with warnings only. Copilot's first reviews of PRs 1, 3, 4, 5 and 6 found R8–R12; its review of PR 2 asked only for E14's checks on the Fold4 (§7). The fixes are later commits on the PRs' branches, so the cherry-picks of §4 don't have them:

| PR, commit | Change | Tests | Negative case |
|---|---|---|---|
| PR 1, 9cd7213 | R1: Godot 4.7.2 ignores what `fclose()` and `fflush()` return (`drivers/unix/file_access_unix.cpp`), so a write that failed as the file closed, as on a full disk, went unreported, and its truncated `.tmp` replaced the last good save. `_write()` reads the `.tmp` back, and keeps the last save unless the two match. `_store()` is the tests' seam | `test_save_service.gd`: `test_a_write_that_fails_as_the_file_closes_keeps_the_last_save` | N51 |
| PR 1, 0d548d6 | R2: GUT runs `tests/integration` before `tests/unit`, and `test_wrong_turn_disaster.gd` calls `use_memory()`. In the full suite, `test_the_tests_never_touch_the_players_save` passed without the pre-run hook, while the integration tests before it used the player's save. `run_tests.sh` runs GUT with a scratch save, as `smoke.sh` runs the autopilot, and fails if the tests read or wrote it | `run_tests.sh` | N1 |
| PR 1, 0d548d6 | R3: before PR 3, nothing reads the save in `smoke.sh`'s 60 s, so N2 passed on PR 1's state. The autopilot prints `autopilot: the save is in memory`, and `smoke.sh` fails without that line | `smoke.sh` | N2 |
| PR 1, 0f76e42 | R7: Godot 4.7.2 on macOS ignores `XDG_DATA_HOME`. `user://` is under `$HOME/Library/Application Support/Godot/app_userdata/` (`platform/macos/os_macos.mm`, `get_data_path()`), so on a Mac the scratch save of L1 and R2 was never opened, and both scripts passed whatever the game did. `_common.sh` moves `HOME` into the scratch directory on macOS, and `XDG_DATA_HOME` elsewhere, and fails unless Godot wrote its log, `user://logs/godot.log`, in the scratch `user://` | `run_tests.sh`, `smoke.sh` | N56 |
| PR 1, 130f341 | R8: `load_json()` read the text over what its `SaveData` already held, so a second load kept the first's atlas, bests, collection, settings and problems wherever the new text left them out. The game loads each save into a new `SaveData`, but the method's contract is the defaults. It now resets them first | `test_save_data.gd`: `test_each_load_starts_from_the_defaults` | N57 |
| PR 3, 7a3af97 | R6: each sound took the next of the four effect players, so a sound that came again before it ended played twice or more at once, as the screech can a few frames apart along the road's edge. Four screeches raise the peak beside the music, the ambience and the rumble from 0.53 to 0.97 (L29). A sound now starts over on the player that last played it, unless another sound has taken that player since | `test_audio_director.gd`: `test_a_sound_never_plays_twice_at_once` | N55 |
| PR 3, 30661b9 | R9: `CrossFade.fade_to(null)` mid-fade gave "no track" to the quieter deck as if it were one, so that deck stopped at once, from a gain of up to 0.71, where an area without music or ambience fades the last area's out (`area_def.gd`). No track is now no deck: `current` is `NONE`, both decks fade out from where they are and keep their tracks until they are silent, and a track still fading out fades back in from where it is. `current_track()` guards `NONE`, which as an index would read the last deck | `test_cross_fade.gd`: `test_no_track_mid_fade_fades_both_decks_out_from_where_they_are`, `test_a_track_fading_out_to_silence_fades_back_in_from_where_it_is`; `test_audio_director.gd`: `test_an_area_with_no_sound_mid_fade_fades_both_areas_out` | N58, N59, N62 |
| PR 4, 6596cba | R4: `test_world_renderer.gd` read a band's pixels from its texture as if the sprite drew it whole, from its position and repeated, so a band without `region_enabled`, `centered = false` or `texture_repeat` passed. Its helpers now find each pixel as `Sprite2D` draws it: through `get_rect()` and the global transform, from the region only if it is enabled, and repeated only if `texture_repeat` is on | `test_world_renderer.gd`'s band tests | N52–N54 |
| PR 4 | R5: N16 changed "ink", which no art of PR 4 uses, so on PR 4's state it failed nothing; PR 5's props and PR 6's car use it. N16 changes "asphalt" now (§6.2) | — | N16 |
| PR 4, aca2151 | R10: the desert's ripples, `sin(x × 0.09)`, made 7.33 waves across its 512-pixel ground, so a seam showed wherever the ground repeats. They make `RIPPLE_WAVES` (7) now; only the desert's ground and edge change | `test_area_art.gd`: `test_a_placeholder_grounds_pattern_goes_on_where_it_repeats` | N60 |
| PR 5, aa47487 | R11: a prop with no frames passed `validate()`, as a strip of none fits any texture. Each of its sprites then got `hframes = 0`, which Godot refuses, one error per placement; `@export_range` guards only the inspector. `validate()` reports it now | `test_prop_scatter.gd`: `test_props_that_break_the_contract_are_errors_and_do_not_show` | N61 |
| PR 6, d576904 | R12: a wheel left a mark wherever its cell had a tile, but the road is `ROAD_HALF_WIDTH` (0.32) wide on each side of the tile's centreline, and the rest of the cell is beside it. A car braking 0.3 tiles right of a straight's centreline is on the road, while its right rear wheel, `SKID_TRACK` / 2 (0.09) further out, is not, so its mark lay beside the road. A mark now needs `RoadGeometry.is_on_road()` at its wheel, which a cell without a tile fails too | `test_skid_marks.gd`: `test_a_wheel_over_the_roads_edge_leaves_no_mark` | N63 |

The same model reviewed R8–R11 as `code-review`, and PR 6's sync of this plan before them, and found no issues. Its review of this plan's sync of R8–R11 found that N3 fails a seventh test since R8; checking each case's tests against §6.2 then found that N14 fails a fourth since R9. §6.2 lists both. Running the negative cases on the new heads found that no case failed R9's `test_a_track_fading_out_to_silence_fades_back_in_from_where_it_is`: N62 fails it alone. The same model reviewed R12 and its sync of this plan, and found no issues.

---

## 5. Design

The code on `m5/prototype` is the reference. This section summarizes it and lists what differs from IP, and why.

### 5.1 Files and IDs

§4's tables list each PR's files. M5 adds the autoloads `SaveService`, after `GameState`, and `AudioDirector`, after `EventBus` (§4.5's second rule). `AudioDirector._ready()` connects to `SaveService` although `SaveService` comes later: Godot makes every autoload and its global before it adds any to the tree (`main/main.cpp:4515–4564`). M5 also adds the classes `SaveData`, `CrossFade`, `MenuScreen` and the four screens, `PropDef`, `PropLayout`, `PropPool`, `PropScatter` and `SkidMarks`, and the directories `audio/`, `assets/`, `tools/art/` and `tools/audio/`. Comments cite this plan's IDs as `M5_PLAN.md L2`, as earlier milestones' do. Every gameplay `RefCounted` has its unit test (IP §1.3): `SaveData`, `CrossFade`, `PropLayout`, `PropPool`, `PropScatter` and `SkidMarks`. The generators in `tools/` are `SceneTree` scripts with a fixed seed, run by hand: CI checks what they made, not the scripts' runs.

### 5.2 Menus (PR 2)

- **The title** is `%Title`, a `TitleScreen` on `main.tscn`'s UI layer after the HUD and the game-over screen, so it sees Esc first. It shows "Road Roguelike", Play, Atlas, Disasters, Settings, and the best run, "Best: 412 m, 31 turns" (Q6), or nothing before the first run. Each button opens its screen, and Back or Esc returns with the button's focus. Play emits `play_requested`.
- **`MenuScreen`** is the base of the title's three screens: its Back button emits `back_requested`, and the title then calls its `close()`. `TitleScreen.go_back()` closes the open screen, or returns false on the title's own page, where `main.gd` then quits (L13).
- **The Atlas** shows the best run, and a `MenuCard` for each of `AreaSchedule.areas()`: each area once, in the order a run reaches them. An area no run has reached shows "???", "Not reached yet" and a silhouette (`Color(0.1, 0.1, 0.12)`); a reached one its name, its colour, and "Best distance: 412 m" and "Best turns: 31", the most a run made in it (L8).
- **The collection** shows the disasters of those areas' pools, in the same order, each with its `DisasterBase.display_name`. One not seen yet is a silhouette; a seen one says "Seen once" or "Seen 3 times", and "First: City, 412 m, 31 turns" (L18).
- **Settings** has sliders for Music, Sound effects and Ambient, a Vibration toggle, a Screen choice of Auto-rotate, Portrait and Landscape (Q3), and Back. Each control calls `SaveService.set_setting()` at once, and closing the screen flushes it.
- **`main.gd`** starts on the title, with no run, unless `--autopilot` or `--play` is given. Play starts one run; the key or tap that pressed it doesn't steer. Game over gets a Title button beside Retry. `go_back()` handles Android's back button (L13): a screen of the title closes, the title quits, a run pauses, game over goes to the title, and in the pause, a disaster or a crash nothing happens (Q5).
- **Layout.** Each screen fits a 360×640 portrait screen with its longest texts, at the theme's font after PR 6: the details wrap (N9). Every text uses only the font's glyphs (N10).

### 5.3 The save (PR 1)

```json
{
  "version": 1,
  "atlas": { "city": { "discovered": true, "best_distance": 41.2, "best_turns": 31 } },
  "best": { "distance": 41.2, "turns": 31 },
  "disasters": { "sinkhole": { "seen": 3, "first_area": "city", "first_distance": 41.2, "first_turns": 31 } },
  "settings": { "music": 0.8, "sfx": 1.0, "ambient": 0.8, "haptics": true, "orientation": "sensor" }
}
```

- **`SaveData`** holds it. Distances are in tiles, as `GameState` counts them; the screens show metres, as the HUD does. **Δ `plan.md` §9 (L18):** `best_turns`, `first_distance` and `first_turns`.
- **Reading** (`load_json()`) starts from the defaults (R8). It uses `JSON.new().parse()`, which prints nothing (L6), and returns `LOADED`, `CORRUPT` or `NEWER`. Text that isn't a JSON object, or whose version isn't a whole number from 0 up, is `CORRUPT`. A file from a later version is `NEWER`: read as far as version 1 knows it (L9). Anything else is migrated, then each key is checked. A value of the wrong type or out of range keeps its default and adds a line to `problems`: volumes are 0–1, counts and distances whole or real numbers from 0 to `MAX_NUMBER`, 2^53 − 1, the orientation one of the three (L5). `MAX_NUMBER` is an int literal: Godot reads the float literal `9007199254740991.0` as `9007199254740990.0` (P4).
- **Migrations.** `migrations()` maps each version to the step that takes it to the next. Version 0 is a file without `"version"` (Q8), and its step changes nothing: version 1 only adds keys, which get their defaults. `migrate()` runs the steps in order and reports a missing one with `push_error()`.
- **Areas.** `stats()["areas"]` counts each area from its first tile, and the turns after the junctions before it, which `main.gd` reads from the buffer when the area comes (L8).
- **Records.** `record_run(stats)` discovers each area of `stats["areas"]` and keeps, per area, the most distance and the most turns a run made in it, and the most overall (Q6). `record_disaster(id, area_id, stats)` counts a sighting, and the first one keeps its area, distance and turns. `set_setting()` takes only what the setting can be.
- **`SaveService`** reads `user://save.json` the first time something needs it. It records each run on `run_ended` and each disaster on `disaster_started`, and writes at once. A setting is written `SETTINGS_SAVE_DELAY` (0.5 s) after its last change, or at once on `NOTIFICATION_WM_CLOSE_REQUEST`, `NOTIFICATION_APPLICATION_PAUSED`, `NOTIFICATION_APPLICATION_FOCUS_OUT`, `NOTIFICATION_WM_WINDOW_FOCUS_OUT` or on leaving the tree (L10). On the Web, only the window's focus-out comes before a page closes. `settings_changed(key)` tells the audio.
- **Writing** (L11): store the JSON in `save.json.tmp`, close it, and `DirAccess.rename_absolute()` it over `save.json`, all in one call. Reading first removes a `.tmp` that a killed write left. A `CORRUPT` file becomes `save.json.bak`, and the defaults are written at once; if it can't be renamed, it stays, and is never written over, as a `NEWER` one. A `NEWER` file is never written over. A failed write, and the `problems` of a read, are one `push_warning()` each: the game goes on.
- **Tests** (L1): `use_memory()` keeps everything in memory, `use_file(path)` uses another file. `tests/gut_pre_run.gd` calls `use_memory()` before the first test, and `--autopilot` does too.

### 5.4 Audio (PR 3)

- **Buses** (`default_bus_layout.tres`): Music, SFX and Ambient, each sending to Master. SFX's effect 0 is an `AudioEffectReverb`, on only while the car's tile is a tunnel's (IP M5.3). On the Web it does nothing (L19). The editor saves the layout whenever it opens the project, so the file is just as Godot writes it, with the uid in its header (L28): a change to the buses is made in the editor's Audio panel, or copied from what it saves. CI fails if the checks change the file (L28).
- **`AudioDirector`** runs while paused (`PROCESS_MODE_ALWAYS`), and so do its music and ambient players; the engine, the rumble and the effects are pausable. Two players each for Music and Ambient are `CrossFade`'s decks. `follow(sim)` gives it each run's `CarSim`; `follow(null)` stops the car's sounds.
- **The car's sounds.** Two loops on the SFX bus: the engine from a run's start to its end, its pitch `lerp(ENGINE_PITCH_MIN, ENGINE_PITCH_MAX, speed / GLOBAL_SPEED_CAP)`, 0.8 to 1.6 (L21), assigned every physics frame (L27), and the rumble while the car is off the road. Four effect players take the one-shots in turn: the screech as the car leaves the road, a chime for each turn made, a thump each time the health falls past a multiple of `DAMAGE_SOUND_STEP` (10), the crash when the health or the time off the road ends the run, and each disaster as it starts (L7). `effect_played` tells the tests.
- **`CrossFade`** fades a new track in on the quieter deck as the other fades out, over `CROSS_FADE_SECONDS` (1.5 s), at equal power. Back to the old track mid-fade fades it back in from where it is; the same track again changes nothing (L22). No track, as for an area without music or ambience, fades both decks out from where they are (R9). A deck that has faded out stops.
- **Music** comes from `AreaDef.music` and `ambient_loop`, on `area_changed`. At launch the title is silent; after a run, it keeps that run's music and ambience, and the next run cross-fades from them (Q4).
- **Volumes** are the settings' linear volumes of the three buses, and 0 mutes a bus. They apply when a run starts and on `settings_changed`, never in `_ready()`, which mustn't read the save (L1).
- **Headless** (L15): `can_play` is false on the Dummy driver, and nothing plays. Everything else runs, so the tests check the players, their streams, the fades and the pitch. A test that turns `can_play` on, as `test_audio_director.gd`'s `test_a_deck_stops_once_it_has_faded_out` does, calls `stop_all()` and waits 0.25 s before the tests end.
- **Assets** (Q1, L23): `make_audio.gd` writes mono 16-bit WAV at 22,050 Hz: 3.4 MB for 5 music tracks, 5 ambient loops and 10 car and disaster sounds. A loop carries its loop points in a `smpl` chunk, which the importer's default `edit/loop_mode`, Detect From WAV, reads: the 12 loops import as `LOOP_FORWARD` over the whole file, and the 8 one-shots don't loop (`test_audio_director.gd`). The import compresses them all to QOA. Each peaks at its kind's budget (L29). Final files replace them under the same names, within the same budgets.

### 5.5 World art (PR 4)

- **The palette.** `assets/palette.gpl` has 32 named colours: 8 shared ("ink", "shadow", "asphalt", "asphalt light", "line", "tunnel road", "plank", "white"), 4 per area (its ground, which is the area's `id_color`, a dark, a light and an accent), and 4 for effects and the UI. Every PNG under `assets/` uses only these (L25, N16). `Image.set_pixel()` truncates a channel where `Color.to_rgba32()` rounds, so a test compares 8-bit values (P6).
- **Import** (IP M5.1): `[importer_defaults]` makes textures lossless and without mipmaps, and the filter stays nearest.
- **Road sheets** have `GreyboxAtlas`'s layout: 15 columns, one per exit mask, by 4 rows (road, dead end, tunnel, bridge) of 128×64 cells. The tunnel's row is "tunnel road" and the bridge's "plank", as the grey box's tints were (M4 K18). A sheet is opaque exactly where the grey box's road is, so the road reads the same (L4).
- **Ground bands** (L3). The world's `Ground` node holds a `Sprite2D` for each stretch of the path in one area: its region repeats the area's ground and is anchored in the world, so the ground doesn't move with the band. Each band reaches `GROUND_MARGIN` (2048 px) past the buffered tiles either side, from its line up to the next band's, and draws over the older ones. Its edge, a child below its line, blends it into the last area's ground over `TRANSITION_TILES` (2) path tiles (IP M4.3). A band goes once the next one begins `GROUND_MARGIN` below the oldest path tile, as it can't show again.
- **Grounds** repeat with the ground cells (32×16) and are opaque. A placeholder's pattern goes on where its ground repeats (R10). **Edges** repeat across, 64 px high, opaque or clear by an 8×8 Bayer matrix: each row shows no more than the row 8 above, so the ground thins out downwards (N15). An area without art draws a checker of its colour and the grey box's road.
- **Generator.** `tools/art/make_art.gd` draws them from the palette with a seeded RNG (Q1).

### 5.6 Props (PR 5)

- **`PropDef`** (`.tres`): a sheet, the first frame's region, the number of frames and their fps, the foot (where the prop stands, in the frame), and a density, the chance that a ground cell beside the road shows it: 0.003 to 0.016. An area's densities add up to 1 at most. Each area has six props, one of them animated: the city's traffic light, the desert's tumbleweed, the meadows' pond, the rural windmill and the village's smoky house (`test_prop_art.gd`).
- **`PropLayout.row()`** (L14) places the props of screen row k. Path tile k's row is the tiles whose cells add up to −k. Its props stand on the ground cells of the `PROP_SPREAD` (9) tiles either side of path tile k that are neither road nor within `set_piece_margin()` tiles of a set piece. The hash of each cell with `props_seed` picks a prop by the cumulative densities, or none, so a cell's prop depends on nothing else. A prop whose frame would touch a road tile's diamond is left out. A frame reaches at most 72 px above its foot, 32 px either side and 8 px below it (`PROP_MAX_SIZE` 64×72, `PROP_BELOW`), so it can touch only the diamonds of its own row, the one below and the `rows_above()` (3) above.
- **`PropScatter`** shows row k once the car is `PROP_AHEAD` (24) path tiles before it, when the buffer holds `rows_needed()` (6) rows more: the 3 rows above plus a junction's longest dead end (`DEAD_END_MAX_TILES`, 3), which can come down into them. `BUFFER_REFILL_AT` is their sum, 30: L2's contract. It hides the row's props when the buffer frees path tile k. At the start the `BUFFER_BEHIND` rows below the first path tile get the first area's props. A new buffer, at retry, takes back every sprite. Animated props step through their frames at their fps.
- **`PropPool`** (**Δ IP M5.2**, L24) hands out `Sprite2D`s that show a prop's first frame with its foot on their position. A released sprite is hidden and handed out again; the pool makes one only when none is free. Over 1,000 rows it makes no more than a row shows.
- **Y-sort.** The sprites are children of `World/Props` with the car, so they y-sort with it. `WorldRenderer.car` gives the car, and the tests find it by type (L12).
- **Contract.** A `PropDef` that breaks it (no texture, frames outside it, no frame at all (R11), frames without an fps, a foot outside its frame, a frame larger than `PROP_MAX_SIZE` and `PROP_BELOW` allow, densities past 1) is reported with `push_error()` once, when the world is built, and never shows.

### 5.7 The car and its skid marks (PR 6)

- **The sheet.** `car.png` is 17 frames of 36×28 px: 16 directions and the wreck (`WRECK_FRAME` 16), each standing on the foot (18, 18). `%Body`, a `Sprite2D`, replaces M2's arrow: it shows the frame of the car's heading, and the wreck when it crashes, where M3 tinted it. No polygon is redrawn (M2 §5.7). The dust and the smoke are as before (Q2).
- **The wreck's outline** is "tunnel road", so the crash's smoke stands out against it by 0.131, above `SMOKE_CONTRAST` (0.1); "ink" would give 0.047 (N36).
- **`SkidMarks`** (Q7). While the car brakes for a junction faster than the junction's target speed, its rear wheels leave a pair of marks every `SKID_SPACING` (0.08) tiles, `SKID_REAR` (0.09) tiles behind its centre and `SKID_TRACK` (0.18) apart, at `SKID_ALPHA` (0.5). A wheel over the road's edge leaves none, also while the car's centre is on the road (R12). Each mark is a `Sprite2D` on `World/Skids`, between the road and the disasters, placed once. A mark goes back to the pool when the buffer frees its tile, or, once `SKID_MARKS` (256) show, the oldest first. A new buffer takes back all of them.

### 5.8 Font and theme (PR 6)

- **The font** is Pixel Operator 8 (CC0, with its licence), drawn on an 8 px grid, so every font size is a multiple of 8: the UI uses 8, 16 and 24 px. `ui/theme.tres` is the project's theme, at 16 px by default, with the palette's colours.
- **Embedded** (L17). `tools/art/make_font.gd` copies the TTF's bytes into `assets/fonts/pixel_operator_8.tres`, a `FontFile` with no antialiasing, hinting or subpixel positioning. Godot loads the theme before any import, so a theme that used the imported TTF failed on a fresh clone. The TTF stays, with its `.import`, as the source.
- **Tests.** The theme loads without an import, the font draws only fully clear or fully opaque pixels, every font size in the UI's scenes is on the grid, and the theme's colours are the palette's. `test_smoke.gd`'s glyph check uses the theme's font. The font is about 1.6 times as wide as Godot's default, which the layout test of §5.2 covers.

## 6. Verification

### 6.1 Local checks

The commands are those of `AGENTS.md` §4: `lint.sh`, `import.sh`, `check_scripts.sh`, `run_tests.sh` and `smoke.sh` in `tools/ci/`. Each PR's state is its commit of `m5/prototype`, on `main` (18fd716) and the earlier PRs' commits (§4.1). All five checks passed on each:

| State | `check_scripts` | GUT tests | Asserts | GUT time | The PR's diff |
|---|---|---|---|---|---|
| M4 (`main`, 18fd716) | 83 | 269 | 146,144 | 19.6–21.2 s | |
| PR 1 (791190d) | 88 | 300 | 146,300 | 21.3–22.9 s | 22 files, +971 −8 |
| PR 2 (1fe7021) | 99 | 334 | 146,576 | 21.9–22.5 s | 43 files, +1,506 −26 |
| PR 3 (f30beb5) | 106 | 369 | 146,790 | 23.1–23.2 s | 66 files, +1,791 −1 |
| PR 4 (89a3732) | 109 | 379 | 147,089 | 24.5–25.3 s | 50 files, +1,587 −219 |
| PR 5 (40a77c4) | 119 | 399 | 147,510 | 45.4–46.0 s | 75 files, +2,570 −31 |
| PR 6 (132d464) | 125 | 409 | 147,664 | 47.0–48.7 s | 34 files, +978 −68 |

M5 adds 42 scripts and 140 tests, in +9,403 −353 lines. PR 6's state is the prototype's tree. Each GUT time is the range of two runs of its state. This machine has 2 CPUs, and its load moves the times by up to 5 s. In the second run of PR 6's state, `import.sh` failed on GUT's update check (`AGENTS.md` §10), with a 401 from GitHub's API, and passed when run again. PR 5's tests nearly double GUT's time (P8, §8). In every state:
- `smoke.sh` prints M4's line, `autopilot: tile 165, turns 35, area rural`: nothing in M5 changes where the autopilot drives (E13). Its `grey box:` line says the tilesets took 64 ms on `main`, and 0 ms on PR 6's state, where every area loads its art;
- `lint.sh` reports `Godot 4.7.2 is pinned consistently` and `Actions storage: no caches, artifacts kept 1 day (5 files checked)`;
- `git status` is clean after the checks: `import.sh` creates no files, and the generators of PRs 3–6 make the committed assets byte for byte (§4.1 step 3). From PR 3 on, CI's `test` job checks it too (L28).

§6.6 has the same checks on the PRs' final heads, with the review fixes (§4.6).

### 6.2 Negative cases

For each case, make the temporary change in the PR's state, run the check under "Fails", then revert it. A script made each change on PR 6's state (132d464), ran the check and restored the files, and every case failed its check, in 2 min 12 s. N48 and N49 commit their change in a new worktree, run `import.sh`, `check_scripts.sh` and `test_audio_director.gd` there, then the step's script from `ci.yml`. N36 ran by hand, on 84e261b (§6.5), because it must make the car's sheet again. The script isn't committed (§9). Each PR runs its cases again on its final head (`AGENTS.md` §2). The PRs' reviews added N51–N63 and changed N1, N2 and N16 (§4.6), and all 63 failed their checks on the PRs' final heads (§6.6). "Fails" names the GUT tests that fail, which fail `run_tests.sh`, or the script that fails and its message.

| N# | PR | Ref | Change | Fails |
|---|---|---|---|---|
| N1 | 1 | L1 | `tests/gut_pre_run.gd` doesn't call `SaveService.use_memory()` | `run_tests.sh`: "The tests read or wrote the save file" (R2). `test_save_service.gd`: `test_the_tests_never_touch_the_players_save`, when its file runs alone |
| N2 | 1 | L1 | `--autopilot` doesn't call `use_memory()` | `smoke.sh`: "The autopilot read or wrote the save file, or might have", from PR 1 on (R3) |
| N3 | 1 | L6 | `SaveData` reads the text with `JSON.parse_string()` | 7 tests of `test_save_data.gd`, from `test_json_round_trip` to `test_a_later_version_is_read_as_far_as_it_is_known`, R8's included |
| N4 | 1 | L5 | `_is_count()` takes a number with a fraction | `test_values_of_the_wrong_type_get_their_defaults` |
| N5 | 1 | L7 | The director doesn't emit `disaster_started` | `test_disaster_director.gd`: `test_disaster_started_comes_once_when_the_disaster_plays`; `test_wrong_turn_disaster.gd`: `test_the_run_and_the_sinkhole_are_saved` |
| N6 | 1 | L8 | `GameState` doesn't record the areas a run enters | `test_game_state.gd`: `test_end_run_emits_the_cause_and_stats`, `test_stats_have_the_distance_and_turns_made_in_each_area`, `test_an_area_counts_from_its_first_tile_and_the_turns_after_it` |
| N7 | 1 | L11 | A corrupt file goes to `.bak`, and the defaults wait for the next write | `test_a_corrupt_file_is_kept_as_bak_and_replaced_with_the_defaults_at_once` |
| N8 | 2 | L13 | `project.godot` without `config/quit_on_go_back=false` | `test_title.gd`: `test_the_back_button_does_not_quit_on_its_own` |
| N9 | 2 | §5.2 | A card's details don't wrap: `autowrap_mode = 0` in `menu_card.tscn` | `test_title_screen.gd`: `test_every_screen_fits_a_portrait_screen_with_the_longest_texts` |
| N10 | 2 | §5.2 | The title's button says "Play →", a glyph that the default font lacks | `test_smoke.gd`: `test_main_scene_text_has_every_glyph_in_the_default_font` |
| N11 | 3 | L15 | Sounds play on the Dummy driver: `can_play := true` | `smoke.sh`: "Errors during smoke run", for the leak at exit |
| N12 | 3 | L16 | A script in a directory that `lint.sh` doesn't list, `fx/stray.gd` | `lint.sh`: "GDScript outside the linted directories" |
| N13 | 3 | L16 | A misformatted line in `audio/cross_fade.gd` | `lint.sh`: "would reformat audio/cross_fade.gd" |
| N14 | 3 | §5.4 | A new track takes the louder deck | `test_cross_fade.gd`: `test_a_new_track_fades_in_as_the_old_fades_out_at_equal_power`, `test_back_to_the_old_track_mid_fade_fades_it_back_in_from_where_it_is`, `test_a_third_track_mid_fade_takes_the_quieter_deck`, and R9's `test_no_track_mid_fade_fades_both_decks_out_from_where_they_are` |
| N15 | 4 | §5.5 | The edge's dither inverted: `bayer(x, y) < cover` | `test_greybox_atlas.gd`: `test_the_grey_box_edge_is_its_grounds_first_rows_thinning_out` |
| N16 | 4 | L25 | The palette's "asphalt" one step off: `85 87 97`. Not "ink", which PR 4's art doesn't use (R5) | `test_area_art.gd`: `test_art_is_in_the_palettes_colours` |
| N17 | 4 | §5.5 | A band's ground starts at its top, which rises with the road, not at its line | `test_world_renderer.gd`: `test_each_area_shows_its_ground_and_blends_it_into_the_last_ones`, `test_the_ground_stays_put` |
| N18 | 5 | L2 | `BUFFER_BEHIND` 13 | `test_props_in_view.gd`: `test_nothing_comes_or_goes_in_the_tallest_view` |
| N19 | 5 | L2 | `PROP_AHEAD` 20 | The same |
| N20 | 5 | L2 | `BUFFER_REFILL_AT` 25, below `PROP_AHEAD + rows_needed()` | `test_prop_scatter.gd`: `test_rows_show_props_ahead_of_the_car_and_lose_them_with_their_path_tile`, `test_a_seed_shows_the_same_props_however_the_car_got_there` |
| N21 | 5 | L2 | `PROP_SPREAD` 6 | `test_nothing_comes_or_goes_in_the_tallest_view` |
| N22 | 5 | L12 | The helper's `car()` takes `%Props`' first child, not `WorldRenderer.car` | `test_retry.gd`: `test_retry_starts_the_next_run_afresh` |
| N23 | 5 | §5.6 | A row that goes keeps its props: no `_hide_row()` | `test_rows_show_props_ahead_of_the_car_and_lose_them_with_their_path_tile` |
| N24 | 5 | §5.6 | A new buffer leaves the last one connected | `test_a_new_buffer_takes_the_sprites_of_the_last` |
| N25 | 5 | §5.6 | Props may touch the road: the diamond test never hits | `test_prop_layout.gd`: `test_the_largest_props_keep_off_the_road_made_before_and_after_their_row`, `test_rows_above_counts_the_rows_the_tallest_frame_reaches` |
| N26 | 5 | §5.6 | Props may stand near a set piece | `test_props_keep_off_the_river_and_out_of_the_tunnels_rock` |
| N27 | 5 | §5.6 | The props' hash leaves out the seed | `test_a_seed_places_the_same_props_and_another_seed_others` |
| N28 | 6 | L17 | The theme uses the imported TTF | `test_ui_theme.gd`: `test_the_project_theme_loads_without_an_import`, `test_the_font_draws_crisp_pixels` |
| N29 | 6 | §5.8 | The font is antialiased | `test_the_font_draws_crisp_pixels` |
| N30 | 6 | §5.8 | The HUD at 12 px, off the font's grid | `test_every_text_is_on_the_fonts_grid` |
| N31 | 6 | §5.8 | A border colour outside the palette | `test_the_themes_colours_are_the_palettes` |
| N32 | 6 | §5.7 | Marks stay when their tiles go: `SkidMarks` doesn't connect `tiles_freed` | `test_skid_marks.gd`: `test_the_rear_wheels_mark_the_road_only_while_the_car_brakes_for_a_junction`, `test_a_new_buffer_takes_the_marks_of_the_last` |
| N33 | 6 | Q7 | Marks wherever the car is on the road, braking or not | `test_the_rear_wheels_mark_the_road_only_while_the_car_brakes_for_a_junction` |
| N34 | 6 | §5.7 | Past `SKID_MARKS`, the newest mark goes: `pop_back()` | `test_past_the_limit_the_oldest_marks_go_first` |
| N35 | 6 | §5.7 | The body's offset 2 px off the sheet's foot | `test_car_art.gd`: `test_the_sheet_has_a_frame_for_each_direction_and_the_wreck` |
| N36 | 6 | §5.7 | The wreck outlined in "ink", as the car is: `WRECK_OUTLINE` in `tools/art/make_car.gd`, then the sheet made again | `test_car_controller.gd`: `test_the_smoke_shows_over_everything_the_world_draws` and `test_the_smoke_shows_through_a_tunnel`, at a contrast of 0.059 and 0.047, under 0.1 |
| N37 | 2 | §5.2 | The title's node before the HUD's in `ui/main.tscn` | `test_title.gd`: `test_esc_leaves_a_screen_of_the_title_before_the_hud_sees_it` |
| N38 | 1 | L9 | A file from a later version may be written: `_writable` stays true | `test_save_service.gd`: `test_a_file_from_a_later_version_is_never_written_over` |
| N39 | 1 | L10 | The window's focus-out doesn't write: no `NOTIFICATION_WM_WINDOW_FOCUS_OUT` | `test_flush_and_leaving_the_app_write_the_settings_at_once` |
| N40 | 1 | L8 | An area starts where the car is when it comes: `enter_area(area.id, GameState.distance, GameState.turn_index)` | `test_area_start.gd`: `test_each_area_counts_from_its_first_tile` |
| N41 | 1 | L8 | An area's distance and turns may fall below 0 | `test_game_state.gd`: `test_an_area_counts_from_its_first_tile_and_the_turns_after_it` |
| N42 | 1 | L8 | An area counts up to the next one's start, past the run's end | The same |
| N43 | 1 | L5 | Counts and distances without the bound: no `value <= MAX_NUMBER` | `test_save_data.gd`: `test_numbers_past_the_largest_exact_whole_number_get_their_defaults` |
| N44 | 1 | L11 | A corrupt file that can't be renamed to `.bak` is written over | `test_save_service.gd`: `test_a_corrupt_file_that_cant_be_kept_is_never_written_over` |
| N45 | 3 | L27 | The engine's pitch is set only when it changes | `test_audio_director.gd`: `test_the_engines_pitch_is_set_every_frame` |
| N46 | 3 | L28 | `default_bus_layout.tres` has no uid in its header | `test_audio_director.gd`: `test_the_bus_layout_is_as_the_editor_saves_it` |
| N47 | 3 | L28 | A value in the layout isn't as Godot writes it: `bus/1/volume_db = 0` | The same |
| N48 | 3 | L28 | N46 as CI would meet it on a slow runner: committed, then a new worktree's first `import.sh` with four CPU-bound processes running. The import writes the uid back, and `test_audio_director.gd` passes | `ci.yml`'s last `test` step, "Tree unchanged by the checks": ` M default_bus_layout.tres` |
| N49 | 3 | L28 | A script's `.uid` isn't committed: `car/car_sim.gd.uid`, which the import writes again | The same step: `?? car/car_sim.gd.uid`. On GitHub too (§6.5) |
| N50 | 3 | L29 | `damage.wav` three times as loud, peaking at 0.75 | `test_audio_director.gd`: `test_no_sound_peaks_above_its_kinds_budget` |
| N51 | 1 | L11 | No read-back: `_write()` renames the `.tmp` whatever it holds (R1) | `test_save_service.gd`: `test_a_write_that_fails_as_the_file_closes_keeps_the_last_save` |
| N52 | 4 | §5.5 | A band's sprite without `region_enabled`, so it draws its whole texture once (R4) | `test_world_renderer.gd`: `test_each_area_shows_its_ground_and_blends_it_into_the_last_ones`, `test_the_ground_covers_every_view_on_a_long_drive`, `test_an_area_without_art_gets_a_checker_of_its_colour` |
| N53 | 4 | §5.5 | A band's sprite without `centered = false` (R4) | The same, and `test_the_ground_stays_put` |
| N54 | 4 | §5.5 | A band's texture without `texture_repeat` (R4) | `test_an_area_without_art_gets_a_checker_of_its_colour` |
| N55 | 3 | L29 | A sound that comes again takes the next player, and plays over itself (R6) | `test_audio_director.gd`: `test_a_sound_never_plays_twice_at_once` |
| N56 | 1 | L1 | `_common.sh` doesn't export `XDG_DATA_HOME`, as Godot on macOS ignores it (R7) | `run_tests.sh` and `smoke.sh`: "Godot kept user:// outside …, so the save there proves nothing" |
| N57 | 1 | §5.3 | `load_json()` reads over what an earlier load left (R8) | `test_save_data.gd`: `test_each_load_starts_from_the_defaults` |
| N58 | 3 | §5.4 | No track mid-fade goes to the quieter deck, as a track would (R9) | `test_cross_fade.gd`: `test_no_track_fades_out`, `test_no_track_mid_fade_fades_both_decks_out_from_where_they_are`; `test_audio_director.gd`: `test_an_area_with_no_sound_mid_fade_fades_both_areas_out` |
| N59 | 3 | §5.4 | `current_track()` reads `tracks[current]`, the last deck's when none is current (R9) | `test_cross_fade.gd`: `test_no_track_mid_fade_fades_both_decks_out_from_where_they_are`; `test_audio_director.gd`: `test_an_area_with_no_sound_mid_fade_fades_both_areas_out` |
| N60 | 4 | §5.5 | The desert's ripples back to `sin(pixel.x * 0.09)` (R10) | `test_area_art.gd`: `test_a_placeholder_grounds_pattern_goes_on_where_it_repeats` |
| N61 | 5 | §5.6 | `validate()` lets a prop with no frames through (R11) | `test_prop_scatter.gd`: `test_props_that_break_the_contract_are_errors_and_do_not_show` |
| N62 | 3 | §5.4 | A track fades back in only while a deck is current, so one fading out to silence starts again on the quieter deck (R9) | `test_cross_fade.gd`: `test_a_track_fading_out_to_silence_fades_back_in_from_where_it_is` |
| N63 | 6 | §5.7 | A wheel leaves a mark wherever its cell has a tile, so one over the road's edge marks beside it (R12) | `test_skid_marks.gd`: `test_a_wheel_over_the_roads_edge_leaves_no_mark` |

Only N50 breaks a sound itself: headless runs play nothing (L15), so the tests check the players, the fades, the pitch and the files' peaks, and E14 listens. N15–N17, N28–N31, N35 and N36 break the art's contracts, which final art must also pass (Q1).

### 6.3 Editor warnings

None of the five checks reports GDScript warnings, so, as in M2–M4 (M2_PLAN.md §6.3), a probe asked the editor's language server for them. `main` reports 8, in 83 scripts: those that M4 left (M4_PLAN.md §6.3). PRs 1–3 report the same 8, in 88, 99 and 106 scripts; from PR 2 on, `ui/main.gd`'s INTEGER_DIVISION, the `grey box:` line, is on line 44, not 37. PRs 4–6 report 5 of them, in 109, 119 and 125 scripts: PR 4 replaces the ground tileset's tests (L3), which had 3 of `test_greybox_atlas.gd`'s 4, and `world/greybox_atlas.gd`'s moves from line 71 to 135. In PRs 3–6 the editor also saved `default_bus_layout.tres` with a uid in its header, until PR 3 committed it so (L28): now `git status` stays clean after the probe.

Before the prototype's last rewrite it reported 6 more, all INTEGER_DIVISIONs that are meant: in `tools/audio/make_audio.gd`, `tools/art/make_art.gd` and `tests/unit/test_prop_layout.gd` (4). Each now has `@warning_ignore("integer_division")`. `MenuScreen.back_requested`, which only the screens emit, has `@warning_ignore("unused_signal")`, as `DisasterBase.finished` has (M3 J25). The probe isn't committed (§9). §6.6 has its results on the PRs' final heads.

### 6.4 Verified only in CI or on devices

| Check | PR | Result |
|---|---|---|
| The five checks on GitHub, and the `test` job's time | 1–6 | Done on the prototype: six runs passed all five jobs, and `test` took 106–118 s, against 83 and 107 s in `main`'s last two runs (§6.5). Done on each PR's first head (§6.6). To do on the final heads |
| The Web build in headed Chrome and in Firefox (E14) | 6 | Done on the build of 84e261b, the prototype before the `test` job's last step (§6.5): the title and its screens, a run through the City, the tunnel and Rural, a disaster, and a save that survives a reload, with no errors (P9). P13 checked pausing, losing focus, reloading and navigating on 132d464's. To do again on PR 6's final head |
| Listening: the music, the ambience, the engine, the sounds, the tunnel's reverb on Android, and the gap where a loop restarts on the Web (E7, E14, L19, L20) | 6 | To do (owner, §7). Nobody can listen here: the tests check the players and the files' peaks, and P12 the Web build's level (L29), not what they sound like |
| The debug APK on the Galaxy Z Fold4, folded and unfolded: the title, a run, the back button, and a save that survives closing the app (E14, L10, L13) | 6 | To do (owner, §7) |
| https://pompomon.github.io/roadgame/ runs the game with M5 after the merge | 6 | To do |

### 6.5 Measurements (prototype, local)

The probes ran on Godot 4.7.2, headless unless they say otherwise, in scratch scripts that aren't committed. The findings cite them. 84e261b, which P9–P12 name, was PR 6's commit before the `test` job's last step and L29: its tree differs from 132d464's only in `ci.yml` and L29's files.

| # | Probe | Result | Used by |
|---|---|---|---|
| P1 | The buffer in view. The autopilot drives, and each road tile added or freed is placed against the views of the seven reference screens (M2_PLAN.md §6.5). First `main`'s buffer (`BUFFER_BEHIND` 5, `BUFFER_REFILL_AT` 25, `BUFFER_AHEAD` 50), on 3 seeds for 40 s each; then 13, 30 and 55, on 20 seeds for 2 min each; then 14, in `test_props_in_view.gd`'s drives | `main`'s buffer freed 549 tiles, of which 292 in view at 360×640, 324 at 360×800, 330 at 360×922, 5 at 532×640, 207 at 768×640 and 293 at 1639×640. 13, 30 and 55 freed 11,288, none in view, but a dead end that went with its junction came within 12 px of the tallest view; with 14, 44 px at worst. In the test's drive on the tallest view (seed 3, 4,800 frames), the nearest were: a road tile freed 60 px away, a row of props shown 73 and hidden 107, a set piece shown 107 and hidden 120, and a road tile added 179. On the widest (1,800 frames): freed 187, shown 557, hidden 235 and added 680. The worst case comes up to 16 px nearer than one drive, hence the test's margin of 32 px | L2, E6; N18–N21 |
| P2 | How far each view reaches sideways from the car's path tile, on 5 seeds for 60 s each | 1,125 px, 8.8 road tiles, on the 360-wide portrait screens; 808 px at 532×640, 739 at 768×640 and 956 at 1639×640. The other view lies within these (E6) | L2: `PROP_SPREAD` 9; N21 |
| P3 | Sounds on the Dummy driver, and the WAV importer | A sound that still plays when Godot quits leaks: `2 ObjectDB instances were leaked` and `1 resources still in use at exit`. The Dummy driver plays in real time, and a paused tree pauses the players that are pausable. `play()` outside the tree is an error (`scene/audio/audio_stream_player_internal.cpp:145`). The importer defaults to QOA (`compress/mode` 2) and to the WAV's own loop (`edit/loop_mode` 0), and `AudioStreamWAV.save_to_wav()` writes no loop, so `make_audio.gd` writes a `smpl` chunk. The 12 loops import as `LOOP_FORWARD` with the generator's ends (the engine's at 22,000 samples, the City's music at 160,364 and its ambience at 88,200), and the 8 one-shots don't loop. `default_bus_layout.tres` loads without a setting | L15, §5.4; N11 |
| P4 | Where `user://` is, and how `JSON`, typed variables and file calls fail | `user://` is `~/.local/share/godot/app_userdata/Road Roguelike/` for the editor, the tests and the game. `JSON.parse_string()` on text that isn't JSON prints an `ERROR:` line; `JSON.new().parse()` returns 43 (`ERR_PARSE_ERROR`) and prints nothing. JSON reads every number as a float. A float assigned to a typed `int` truncates without a word, and a `String` raises a SCRIPT ERROR. `int(1e20)` and `int(1e308)` are −2^63. The float literal `9007199254740991.0` reads as `9007199254740990.0`: Godot's `built_in_strtod` (`core/string/ustring.cpp:2362`, from `gdscript_tokenizer.cpp:841`) rounds its 17 digits; the int literal is exact, and so is JSON's `9007199254740991`. `DirAccess.rename_absolute()` replaces an existing file; with no source, or onto a directory, it returns 1 (`FAILED`), and opening a missing file returns null with error 7 (`ERR_FILE_NOT_FOUND`), neither with an error line | L1, L5, L6, §5.3; N1–N4 |
| P5 | The theme and the font before and after an import | The project theme loads at start-up, before `--import`: one that uses the imported TTF fails on a fresh clone, and one with the font embedded in a `.tres` doesn't. Pixel Operator 8 is about 1.6 times as wide as Godot's default font: "Sound effects" takes 170 px at 16 px, against 106 | L17, §5.2, §5.8; N28, N9 |
| P6 | Importing pixel art, and reading it back | `--import` honours `project.godot`'s `[importer_defaults]` (`compress/mode` 0, no mipmaps) for new PNGs. `Image.set_pixel()` truncates a channel where `Color.to_rgba32()` rounds; the palette's 8-bit colours survive both. A Bayer 8×8 dither isn't monotone along a row, so the edge's contract counts its cover over each 8 rows | L25, §5.5; N15, N16 |
| P7 | The colours of `setpieces/`, `disasters/`, `car/car.tscn` and `config/tuning.gd` | 25 of their 27 `Color` literals aren't in M5's palette, and some are tints by design (`flood.gd:15`, `quicksand.gd:112`, `sinkhole.gd:97`) | L26, Q2 |
| P8 | GUT's time by suite, from the JUnit reports of PR 4's and PR 5's states | The suites' sum goes from 25.1 to 41.8 s. The new suites take 6.2 s (`test_props_in_view.gd`), 2.7 s (`test_prop_layout.gd`) and 1.3 s (`test_prop_scatter.gd`). The suites that boot the main scene, which now places props too, gain about 6 s: `test_disaster_pools.gd` 2.0, `test_world_renderer.gd` 1.5, `test_retry.gd` 1.4, `test_wrong_turn_disaster.gd` 1.1, `test_title.gd` 0.7 and `test_main_scene_boot.gd` 0.7. M1's `test_autopilot_300_turns` alone takes 9 s | §6.1, §8 |
| P9 | The Web export of 84e261b from run 42773869986, served locally, with `index.html` patched to pass each `?arg=` as a user argument (M4_PLAN.md P4). Headed Chrome 157 and Firefox 159 under Xvfb, with Playwright | Below | E14, §6.4 |
| P10 | The gap where a Web sample loops, the engine's pitch, and stream playback. The Web export of ee9bc99, before L27's fix, from run 42762952606, in headed Chrome under Xvfb with the autopilot, for 45 and 60 s; then P9's build for 60 s. A script hooks `createBufferSource()` and times each source's start, playback rate and `ended` event. In the second run, the worklet's commented-out underrun message (`index.audio.worklet.js:187`), restored, reports each 128-frame quantum that it has nothing to play | 144 restarts. The engine's 1 s loop restarted 108 times: the next source started 14 ms after the last ended at the median, 25 ms at the 90th percentile and 144 ms at worst. The ambience's 24 restarts came 20 ms late at the median and 49 ms at worst, and the music's 12 came 18 and 50 ms late. The worklet, which plays what Godot's mixer makes, streams included, ran short 1,631 times in 60 s, throughout the run: streams would crackle, as `ProjectSettings.xml:487` warns. Samples bypass it. Firefox's audio clock stood still without a sound device, so it timed nothing. Before L27's fix, 9 of the first run's 47 engine sources and 14 of the second's 63 played at the WAV's own rate for over 2 frames, up to 0.4 s, while the speed held. On P9's build, each of the 63 had its rate at the same reading of the clock as its start, and the 83 restarts came as late as before: the engine's 62 by 11 ms at the median and 51 ms at worst | L20, L27, Q11 |
| P11 | The editor and the bus layout (L28). New worktrees of the prototype's last commit before L28's fix, whose layout had no uid: as it was, without its reverb, and with the uid. Each ran one `--import`, then 300 frames of the editor (`--headless --editor --quit-after 300`). Then a new worktree of 84e261b, with `import.sh` and the editor, and §6.3's probe on PRs 3 and 6. Then 13 first imports of 84e261b with the uid taken out, in one new worktree, each after removing its `.godot/` | Without the uid, the editor wrote `uid="uid://bkp2lspkw8gej"` into the header in a worktree already imported. Without the reverb, neither the import nor the editor wrote the file. With the uid, neither changed a byte, and the editor wrote a `bus/1/volume_db = 0` back as `0.0`. With the uid taken out of the header of an imported worktree, `ResourceLoader.get_resource_uid()` still gave it, from `.godot/uid_cache.bin`; without that file, −1. On 84e261b, `git status` stayed clean after each. A first import wrote the uid only under load: in all 4 with four CPU-bound processes running, which took 11.7–14.5 s, and in none of the 9 without, which took 4.1–6.2 s, 3 of them on one CPU. After such an import, `test_audio_director.gd` passed (N48) | L28; N46–N49 |
| P12 | The level of what the Web build plays (L29). A script wraps `AudioNode.connect()`, so that what Godot connects to the output passes through a worklet that records each 1,024-frame window's peak and energy. Headed Chrome 157 and Firefox 159 under Xvfb, Firefox with a PulseAudio null sink for its device (P10). A: the autopilot, seed 12345, for 85 s. B: `--play` with no input, for 45 s: off the road, then the sinkhole. Each at the default volumes and at full volume: B's set in Settings, and A's in a scratch build, as the autopilot keeps no settings (L1). First 84e261b's build, then 132d464's | Before, A peaked at +2.6 dBFS in Chrome and +2.4 in Firefox, past full scale in 108 of 3,591 windows and 94 of 3,240, nearly all with a chime over the engine, the music and the ambience; B at +5.2 and +5.7 dBFS. After, no sample went past full scale. A peaked at −3.4 dBFS in both, and at −1.3 and −1.6 at full volume; B at −5.4 and −4.7, and −4.0 and −4.5. The RMS while sounding fell from −10.2 to −19.1 dBFS in A, and from −16.1 and −16.3 to −22.2 in B. The title was silent (Q4) | L29; N50 |
| P13 | Pausing, losing focus, reloading and navigating on the Web, for Copilot's third review. The Web export of 132d464 from run 42792876467, served as in P9, in headed Chrome 157 and Firefox 159 under Xvfb, Firefox with P12's sink. A script records when the page's keys and blurs come, when Godot starts each sync of `/userfs` (the read-only transaction that IDBFS opens inside `godot_js_os_fs_sync`), and what each write of the save holds. Two runs in each browser | Chrome passed 19 checks and Firefox 17, each time, with no errors. Esc on the title does nothing. With no loss of focus, a setting's sync started 506–536 ms after its key: the 0.5 s timer. When the canvas lost focus two frames after the key, it started 2–23 ms after the blur, and when Esc closed Settings, 20–52 ms after the Esc; IndexedDB had the file up to 0.6 s later. A reload 0.1 s after a change lost it. Esc, the II button and a blur each paused a run, which stayed paused when the focus came back, and so did switching to another window (Chrome only); Esc and II went on. After a run that ended in the sinkhole, a new page load showed P9's best run, Atlas and collection, and a new profile none of them. Playwright opens a new tab as a window, so a hidden tab couldn't be tried. Firefox's audio worklets logged "Script terminated by timeout" at some page loads, as M4's build, with the same worklet files, does. E14's settings step, done fast in Chrome, lost the orientation chosen 0.2 s before a reload, though the screen showed it; closing Settings and waiting 2 s kept both changes | L10, E2, E4, E5, E14 |

- **Web (P9).** Headless Chrome's `requestAnimationFrame` ran at 1 Hz, so the sessions ran headed.
  - Chrome, `--autopilot --seed=12345`, 133 s: 45–57 frames a second. The City, then the tunnel into Rural at 1,600 m after 34 turns, and 3,965 m after 75, with the props, the skid marks and the pixel font. No errors. Chrome logged its 4 `GPU stall due to ReadPixels` notes, and in the save's session one `CONTEXT_LOST_WEBGL` before Godot started, as with M3's and M4's builds (M4_PLAN.md §6.5): they are the environment's.
  - Firefox, the same, 78 s: 57–59 frames a second, and no errors. One warning that WebAssembly's legacy exceptions are deprecated, from the engine.
  - The save, in Chrome: `--play --seed=12345` with no input ends in a sinkhole at the first junction. IndexedDB then holds `/userfs/godot/app_userdata/Road Roguelike/save.json`, with the best distance of 4.0 tiles and the sinkhole first seen in the City, and no `.tmp` (L11). After a reload, the title shows "Best: 40 m, 0 turns". The Atlas shows the City with "Best distance: 40 m" and "Best turns: 0", and four areas "???", "Not reached yet". The collection shows the sinkhole "Seen once", first in the City at 40 m and 0 turns, and three unseen. The arrow keys, Enter and Esc move between the screens. In one earlier session an Enter on the title did nothing; that didn't happen again, and E14 watches for it.
  - The `.pck` grows from 120 KB to 1.07 MB: 0.70 MB of sounds, 233 KB of textures and 27 KB of font. The Web export is 11.1 MB in all.
- **CI.** Six runs on the prototype, started by hand, passed all five jobs: 42760715735, 42761898836 and 42762952606 on earlier states of PR 6, 42773869986 on 84e261b, 42778138424 on c571409, before L29, and 42789644289 on 132d464; the third and the fourth had `upload-builds`. They took 13–26 s for `lint`, 106–118 s for `test`, 57–82 s for `export-web`, 72–88 s for the APK, and 165–191 s for the AAB, once 607 s. Run 42777729455, on a commit that deleted `car/car_sim.gd.uid` from c571409 (N49), failed at the `test` job's last step, which printed `?? car/car_sim.gd.uid`. Run 42778916449 showed why that step passes `safe.directory` to git: the job's container runs its steps as root, uid 1001 owns the checkout, and a plain `git status` stops with "detected dubious ownership". The APK is 58.1 MB and the AAB 58.0 MB.


### 6.6 Measurements (PRs)

The PRs' final heads, after the review fixes (§4.6), are 130f341, ffd7b59, ba05454, decef88, 4b17154 and d576904. PR 6's later commits change only this plan. The local numbers are from those heads.

- **Local checks** (§6.1). All five pass on each head, and `git status` is clean after them. The generators of PRs 3–6 make the committed assets byte for byte:

  | Head | `check_scripts` | GUT tests | Asserts | GUT time | The PR's diff |
  |---|---|---|---|---|---|
  | PR 1, 130f341 | 88 | 302 | 146,331 | 20.3 s | 24 files, +1,063 −8 |
  | PR 2, ffd7b59 | 99 | 336 | 146,607 | 21.1 s | 43 files, +1,506 −26 |
  | PR 3, ba05454 | 106 | 375 | 146,843 | 22.2 s | 66 files, +1,896 −1 |
  | PR 4, decef88 | 109 | 386 | 147,147 | 24.6 s | 50 files, +1,628 −219 |
  | PR 5, 4b17154 | 119 | 406 | 147,569 | 44.0 s | 75 files, +2,578 −31 |
  | PR 6, d576904 | 125 | 417 | 147,729 | 42.6 s | 34 files, +1,019 −68, and this plan |

  The review fixes add to §6.1's counts: from PR 1 on, R1's test with its 6 asserts and R8's with 25; from PR 3 on, R6's test with 2 and R9's three, with 20 between them and the assert it adds to `test_no_track_fades_out`; from PR 4 on, R10's test with 5; from PR 5 on, R11's assert; on PR 6, R12's test with 6. R2, R3 and R7 change the scripts, and R4 the tests' helpers. Each GUT time is one run on the head; before R8–R11 they took 20.4–44.4 s. On each head, `smoke.sh` prints `autopilot: the save is in memory` and M4's `autopilot: tile 165, turns 35, area rural` (E13).
- **The stack.** `git diff --stat origin/m5/prototype -- . ':!M5_PLAN.md'` on PR 6's head lists only §4.6's 20 files (§4 PR 6 step 1): `autoload/save_service.gd` (R1, R3), `autoload/save_data.gd` (R8), `autoload/audio_director.gd` (R6, R9), `audio/cross_fade.gd` (R9), `tools/art/make_art.gd` and the desert's `ground.png` and `edge.png` (R10), `areas/prop_def.gd` (R11), `world/skid_marks.gd` (R12), `tools/ci/_common.sh`, `run_tests.sh` and `smoke.sh` (R2, R3, R7), and eight tests. The landing, simulated again on the final heads as in §4.5, has no conflicts: after its merges, each PR's diff from `main` lists only its own files, and the last squash gives PR 6's tree.
- **Editor warnings** (§6.3). The probe reported §6.3's warnings on each head, and no others: main's 8 on PRs 1–3, in 88, 99 and 106 scripts, and 5 of them on PRs 4–6, in 109, 119 and 125. The review fixes add none, and `git status` stayed clean after each run.
- **Negative cases** (§6.2). The script ran all 61 of its cases again, each on its PR's final head, in 3 min 4 s, and N36 ran by hand on PR 6's. R12 changes only PR 6, and on its new head the script ran PR 6's cases again, N28–N35 and N63, in 12 s. Each failed the checks that §6.2 gives it. R9 rewrote the lines that N13 and N14 change, so the script changes their new form. N36's two tests measured contrasts of 0.059 and 0.047, below 0.1.
- **CI.** The first heads of PRs 1–5, and PR 6's in run 42835507373, passed all five jobs, with `test` taking 85–133 s, except PR 3's AAB export: GUT's update check got a 403 from GitHub's rate limit (`AGENTS.md` §10), and the next push ran it again. To do: the runs on the final heads, and a run by hand on PR 6's for E14.
- **Web (E14).** To do, with that run's Web build (§4 PR 6 step 2).

---

## 7. Owner actions

These need the repository owner. The current state was read with `gh api` on 2026-11-10: ruleset "Test" (26672445) requires `lint`, `test`, `export-web` and both `export-android` checks, and "Copilot" (26740665) has only its review rule. The repository doesn't delete merged branches by itself. M5 changes no settings.

| When | Action | How |
|---|---|---|
| Now | Answer Q1–Q11, or accept the defaults | A comment on this plan's PR. Without an answer, the PRs follow the defaults. Q1's alternative holds PRs 3–6 until final files come |
| Now | Merge this plan's PR | Squash-merge it into `main`. PR 1 branches from `main` with this plan, and PR 6's tree check leaves the plan out (§4, PR 6 step 1) |
| Before PR 6 merges | E14 on the Galaxy Z Fold4, and listening to the sound, its balance and loudness too (L29), on the Fold4 and in a browser. An agent does the Web checks in Chrome and Firefox | §4, PR 6 step 2 |
| To land M5 | Merge PRs 1–6 in order, each once its base is `main` and it is updated as in §4.5 | §4.5 |
| Optional | Delete each PR's branch after it merges, so GitHub retargets the next PR by itself. Delete `m5/prototype` once PR 6 has merged | The **Delete branch** button on the merged PR (§4.5); `git push origin --delete m5/prototype` |

---

## 8. M5 risks

| Risk | Impact | Mitigation |
|---|---|---|
| The art and the audio are placeholders made by scripts (Q1) | The game looks and sounds unfinished until final files replace them | Each asset type has a contract that tests check: the palette, the road sheet's layout, the ground's seams, the props' and the car's frames and feet, the font's grid, which sounds loop and how loud they peak (§5.4–§5.8). A final file that passes needs no code change |
| The set pieces, the disasters, the dust and the smoke keep M2–M4's flat colours (Q2, P7) | They look out of place among the new art | E14 judges it. §9 lists them for M6 or a later art pass, and the smoke already has to show over everything the world draws (E9, N36) |
| GUT takes over twice as long from PR 5 on: 45–49 s locally, against M4's 20–21 s (P8) | Slower local checks, and a `test` job of 106–118 s, against `main`'s 83–107 s | Most of it is the props' drives, which keep everything out of view (E6). They drive only the tallest and the widest views, which hold the other five. If the time matters, the drives can share one run |
| No reverb on the Web (L19), and a gap where a loop restarts (L20) | The tunnel sounds dry in browsers. On the Web the engine ticks about once a second, and the music and the ambience at each loop (P10) | Accepted until M6.3 or Godot 4.8 (Q11, §9): streams, which have neither problem, would crackle (P10). E14 listens for both. Q11's alternative, engine and rumble loops of 4 s, makes the ticks a quarter as frequent |
| The sounds' peak budgets (L29) | The mix is 6–9 dB quieter than before them, and a final sound can't peak above its kind's budget | Nothing clips (P12). E14 listens to the balance and the loudness. A final sound can be louder within its budget if it's compressed. A higher budget needs P12 again |
| Windows taller than the reference screens (Q9) | Road and props may come and go at the top or the bottom of the screen | `test_props_in_view.gd` holds the seven reference screens. M6.1 handles windows and foldables, and a larger `BUFFER_BEHIND` with a test can follow |
| The `.pck` grows ninefold, to 1.07 MB (P9) | A longer first load on the Web | It is a tenth of the 11.1 MB Web export, most of which is the engine. The sounds are QOA, 0.70 MB from 3.4 MB of WAV (L23) |
| The Fold4 hasn't run M5 (§6.4) | Problems only Android shows: the back button, saving when the app is closed, the sound's latency, the font's crispness at the Fold4's scale | E14's Android steps check each, before PR 6 merges (§7). The save's flush on pause and focus loss is tested (L10) |
| A change to the save's format after M5 ships | Lost progress | Saves carry a version, and each older version migrates in order (E1). A later version's file is read as far as it is known and never written over (L9). Each new version needs a migration and its test |
| Six stacked PRs, with `config/tuning.gd`, `project.godot` and others changed by several (§4.5) | Conflicts, or a lost review fix | §4.5's procedure, simulated without conflicts. A fix keeps its insertions away from a later PR's lines |
| CI's `test` job fails when the checks change the tree (L28) | A PR fails CI for a file that isn't committed as Godot writes it, such as a new script's `.uid` (N49) | That is the step's purpose: `AGENTS.md` §4 already asks for a clean tree. The step prints the files, and committing what Godot wrote fixes it. A Godot upgrade commits what the new version writes (IP §7.1) |
| The PRs drift from the prototype after reviews | The prototype stops being a reliable reference | PR 6's tree check lists every difference, which must be §4.6's (§4, PR 6 step 1) |

---

## 9. Notes for later milestones

- **M6:**
  - M6.1 applies the orientation setting, and M6.2 the vibration setting: both are saved and shown since M5 (Q3). They read them with `SaveService.setting("orientation")` and `SaveService.setting("haptics")`.
  - L10's Web limit: 4.7.2 tells the game nothing when a page closes, reloads or is hidden. A `pagehide` listener through `JavaScriptBridge` could flush, but the IndexedDB sync starts only at a frame, and the build doesn't export `FS` to start it. P13's script times it.
  - M6.3's Web work: browsers start audio only after a user gesture. The tap on Play is the first, so the title stays silent (Q4), and a run's music starts on that tap. M6.3 also decides on L20's gap (Q11), unless Godot 4.8 has come; P10's probe measures it again.
  - M6.5's checklist can take E14's steps (§4, PR 6 step 2).
  - Q9's tall windows, with M6.1's foldables: a larger `BUFFER_BEHIND`, and a 1:4 screen in `test_props_in_view.gd`.
- **Art after M5** (Q2, L26): the tunnel's darkening `CanvasModulate` and the bridge's water shader (M4 K18, Q4), and art for the set pieces, the disasters, the dust and the smoke, in the palette's colours. New art must keep §5.5–§5.8's contracts. Until Godot 4.8 it mustn't redraw a `Polygon2D` (M4 K9, godotengine/godot#124726).
- **Godot 4.8** loops Web samples natively (godotengine/godot#123996, L20) and fixes the `Polygon2D` redraws. After an upgrade, listen for the gap again, and check whether samples still skip the bus effects (L19).
- **`AGENTS.md` §5:** add §4.5's second rule: in stacked PRs, a line inserted next to one that an earlier PR inserts conflicts once that PR is squash-merged.
- **`AGENTS.md` §3:** a file that the editor saves by itself, as it does the bus layout, is committed just as the editor writes it, uid included (L28). Change the buses in the editor's Audio panel.
- **`AGENTS.md` §4 and §10:** since PR 3, CI's `test` job runs §4's last check, `git status --porcelain`, after the others (L28).
- **IP and `plan.md`:** fold this plan's Δs into them once it is approved (Q10).
- **Tests and CI scripts** (§4.6):
  - GUT runs `tests/integration/` before `tests/unit/`, so a unit test can't vouch for the tests that ran before it. A check on the whole suite belongs in `run_tests.sh`, as the scratch save's does (R2).
  - Godot 4.7.2 ignores what `fclose()` returns, so a write that matters reads its file back, as `SaveService._write()` does (R1).
  - On macOS, `user://` follows `HOME`, not `XDG_DATA_HOME`. `_common.sh`'s `scratch_save` moves the one each system reads, and checks that Godot's log landed there (R7).
- **Optional:** a CI check for editor warnings, built on §6.3's language-server probe (M2–M4 §9). M5's code had 6 that only the probe found (§6.3). The negative-case script and P12's audio tap could be committed too, under `tools/agent/`.
