# Road Roguelike — MVP Implementation Plan

Status: v1, derived from `plan.md` (Draft v2). M0–M6 are done, and their summaries are in `docs/` (`docs/README.md`). M7 is next.
Scope: everything needed to ship the MVP described in `plan.md` §12 on Android and Web, including CI/CD build actions.

This document turns the design in `plan.md` into ordered work packages with files, interfaces, algorithms, acceptance criteria and tests. When it conflicts with `plan.md`, `plan.md` wins for **game design**, and this document wins for **implementation details**. Any decision made here that `plan.md` leaves open is listed in §1.2.

---

## 1. Baseline

### 1.1 Toolchain (pinned)

| Tool | Version | Why / notes |
|---|---|---|
| Godot | **4.7.2-stable** (standard, non-.NET) | Latest stable (Aug 2026). Satisfies `plan.md` "4.3+". Android target SDK 36, min SDK 24, build-tools 36.1.0, JDK 17. |
| Renderer | **Compatibility** (OpenGL ES 3 / WebGL 2) | Required for Web, works on every Android device, and is enough for 2D pixel art. One renderer means identical output on both platforms. |
| GUT | **9.7.1** (vendored in `addons/gut/`) | 9.7.x is the line that supports Godot 4.7's stricter return types. |
| gdtoolkit | **4.5.0** (`gdlint`, `gdformat`) | Lint and format checks in CI. |
| CI image | `barichello/godot-ci:4.7.2` | Includes Godot, export templates, JDK 17, Android SDK and a debug keystore. |
| Art / audio | PNG and WAV, made by the scripts in `tools/art/` and `tools/audio/` | As in `plan.md` §5.4 and §6 (`docs/M5.md` Q1, L23). |

### 1.2 Implementation decisions (not fixed by `plan.md`)

| # | Decision | Rationale |
|---|---|---|
| D1 | **Simulation runs in logical tile space** (`Vector2`, 1.0 = one road tile). Rendering converts to isometric pixels. | Off-road checks, exit zones and distances become simple maths; tests need no rendering. |
| D2 | **Car logic is a pure `RefCounted` (`CarSim`)** with `step(delta, steer)`. `CarController` (Node) is a thin wrapper. | Deterministic, fast headless simulation tests (300+ turns in well under a second). |
| D3 | **The generator streams one correct-path tile at a time** (internal state machine) instead of whole segments. | Lets the buffer hit exactly 50 lookahead, keeping the 25..50 invariant strict. |
| D4 | Road surface = union of **capsules** from the tile centre to each exit edge midpoint (half-width `ROAD_HALF_WIDTH = 0.32` tiles). | Rounded corners for free steering, and one formula for every tile type. |
| D5 | Exit choice = the **first edge of the junction tile the car crosses** while on road, or the **branch of the first road tile it rejoins** after leaving the road. | Direct implementation of `plan.md` §4.1. |
| D6 | "Near a junction" = the car left the road while its tile was the next unresolved junction **or** a tile at most 1 step from it (the approach tile or any exit tile). | Gives a precise rule for disaster vs crash (`plan.md` §2.4). |
| D7 | `min_straight >= 2` for every area. | Gives room for 1–1.5 tile auto-braking and guarantees a 1-tile wrong stub always fits (§4.3). |
| D8 | Seed: random per run, or forced with `-- --seed=<int>` (user command-line argument). Sub-streams are seeded with `hash("%d:road" % seed)` and so on. | Reproducible bug reports, tests and screenshots. |
| D9 | Package name `com.pompomon.roadgame`; version code = `major*1_000_000 + minor*1_000 + patch`. | Version codes are deterministic and always increase. |
| D10 | Web builds deploy to **GitHub Pages from `main`** (continuous playtest build). Tagged releases attach the APK, AAB and Web zip to a GitHub Release. | Gives an always-playable build without any third-party hosting. |
| D11 | Tuning values live only in `AreaDef` `.tres` files and `config/tuning.gd` constants. No magic numbers in logic. | Tuning happens during prototyping (`plan.md` §14). |
| D12 | Static typing is required in GDScript (`untyped_declaration` warning set to *error* in project settings). | Catches bugs early and helps agents and reviewers. |

### 1.3 Conventions
- Files `snake_case.gd`; classes `PascalCase` with `class_name` for non-autoload scripts; signals `snake_case` in the past tense.
- Every gameplay `RefCounted` has a matching `tests/unit/test_<name>.gd`.
- No node lookups by string path outside scene roots. Use `@export` / `@onready` with `%UniqueName`.
- Every PR must pass the CI build actions (§7) before merge.

---

## 2. Repository layout (final MVP)

```
project.godot
export_presets.cfg                # committed; contains no secrets
.gutconfig.json
.gitignore                        # .godot/, /android/, build/, *.tmp
.gdlintrc                         # gdtoolkit config (excludes addons/)
addons/gut/                       # vendored GUT 9.7.1
config/       tuning.gd           # global constants (ROAD_HALF_WIDTH, buffer sizes, ...)
autoload/     game_state.gd, event_bus.gd, save_service.gd, audio_director.gd
road/         heading.gd, road_tile.gd, road_generator.gd, occupancy_grid.gd,
              road_buffer.gd, junction_trigger.gd, road_geometry.gd
world/        world.tscn, world_renderer.gd, prop_pool.gd, iso.gd, camera_rig.gd
car/          car.tscn, car_controller.gd, car_sim.gd, input_router.gd, autopilot.gd
disasters/    disaster_director.gd, disaster_base.gd, disaster_params.gd, legend.gd,
              legends/ (phantom_bus, ufo, fairy_ring, witch_hex, death_worm; M6)
areas/        area_def.gd, prop_def.gd, area_schedule.gd,
              city.tres, rural.tres, meadows.tres, village.tres, desert.tres, schedule.tres
setpieces/    set_piece.gd, tunnel.tscn, bridge.tscn
ui/           main.tscn, title.tscn, hud.tscn, touch_zones.tscn, pause.tscn,
              game_over.tscn, atlas.tscn, collection.tscn, settings.tscn, theme.tres
assets/       shared/, city/, rural/, meadows/, village/, desert/, greybox/
tests/        unit/, sim/, integration/, helpers/
tools/        ci/ (lint.sh, import.sh, run_tests.sh, smoke.sh, export.sh, stamp_version.sh,
              check_versions.sh), screenshots.gd
.github/      workflows/ci.yml, workflows/release.yml, workflows/visual.yml,
              actions/godot-env/action.yml, dependabot.yml
```

---

## 3. Milestones and dependency graph

```
M0 Bootstrap & CI ─▶ M1 Generator ─▶ M2 Driving ─▶ M3 Failure ─▶ M4 Areas ─▶ M5 Content ─▶ M6 Legends ─▶ M7 Ship
                          │                 └──────────────▶ (sim tests) ──────────────┘
                          └─▶ grey-box renderer (M1.6) can be built alongside M2
```

Sizes: **S** ≤ 1 day, **M** 2–3 days, **L** 4–6 days (one developer).

| Milestone | Goal (exit criteria) | Size |
|---|---|---|
| M0 | Empty project boots, all CI jobs green, Web build on Pages, debug APK artifact | M |
| M1 | `RoadGenerator` meets every unit invariant in `plan.md` §11; grey-box road visible and scrollable | L |
| M2 | A human can drive with touch or keyboard; auto-speed, off-road, health and junction judging work; sim tests pass | L |
| M3 | Wrong or missed turn → Sinkhole → game over → retry; crash path works | M |
| M4 | 5 areas, tunnel, bridge and schedule; per-area disaster pools (grey-box art) | M |
| M5 | Final art and audio, Atlas, disaster collection, settings, save file | L |
| M6 | Each area's disaster comes from a legend, with its veil, art, sound, fate and lore, and nothing flashes (`docs/M6.md`) | L |
| M7 | Orientation and foldable handling, haptics, Web audio unlock, signed release pipeline, device QA | M |

M0–M6 are done. Between M6 and M7, four smaller plans changed the game: junction kinds, side roads and decoys (`docs/ROADGEN.md`), the start area in debug builds (`docs/ZONE_SELECT.md`), the tutorial (`docs/TUTORIAL.md`), and day and night (`docs/DAYNIGHT.md`). `docs/README.md` lists every summary.

---

## 4. Work packages

M0–M6 are done. Each of their packages says what it built and where; `docs/M<n>.md` has the milestone's PRs, findings, decisions and design. The packages as first planned, with their algorithms, tables and starting values, are in git: `git show 08f316f:IMPLEMENTATION_PLAN.md`. M7's packages list **Deliverables**, **Details**, **Acceptance** and **Tests**.

### M0 — Bootstrap and CI (done: `docs/M0.md`)

- **M0.1 Project skeleton.** `project.godot`: a 360×640 portrait base size, `canvas_items` stretch with `expand` and integer scaling, the Compatibility renderer, nearest filtering, `untyped_declaration` as an error (D12), the input actions, and `display/window/size/resizable=true` for folding. Also `.gitignore`, `.gdlintrc` and `ui/main.tscn`.
- **M0.2 Test harness.** GUT 9.7.1 in `addons/gut/`, `.gutconfig.json` (`tests/unit/`, `sim/` and `integration/`), and `tools/ci/run_tests.sh`, which writes its reports to `build/reports/`.
- **M0.3 Export presets.** `export_presets.cfg`: `Web` (single-threaded, no extensions, no PWA), and `Android APK` and `Android AAB` (`com.pompomon.roadgame`, arm64-v8a and armeabi-v7a, `permissions/vibrate`). Never commit keystore paths or passwords: release signing reads `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`, `_USER` and `_PASSWORD`, and debug builds use the CI image's debug keystore.
- **M0.4 CI scripts and build actions.** `tools/ci/*.sh`, `.github/actions/godot-env/`, `ci.yml`, `release.yml` and Dependabot (§7). `main` requires `lint`, `test`, `export-web` and both `export-android` checks; Pages deploys from GitHub Actions.

### M1 — Generator (done: `docs/M1.md`; changed since by `docs/ROADGEN.md` and `docs/TUTORIAL.md`)

- **M1.1 `Heading` and geometry.** `road/heading.gd` (N, E, S, W, and `turn_for()`: even turns go left) and `road/road_geometry.gd`: a point is on the road within `ROAD_HALF_WIDTH` of a segment from the tile's centre to an exit's edge midpoint (D4).
- **M1.2 `RoadTile`.** `road/road_tile.gd`: one cell, with its type, heading, exits bitmask, `path_index` (−1 off the correct path) and `area_id`, and for a junction its `turn_number`, `expected_exit` and the dead-end `branches` it owns.
- **M1.3 `OccupancyGrid`.** `road/occupancy_grid.gd`: at most one tile per cell.
- **M1.4 `RoadGenerator`.** `road/road_generator.gd` streams one correct-path tile per call (D3) from the `road` stream. `PropLayout` places the props by `props_seed` (`docs/M5.md` L14), so props never change the road (`plan.md` §3.5). The path runs only north and west, and wrong exits point outward, so dead ends can't meet the path ahead. Areas switch at the schedule's turns; a set piece keeps the old area, and the tile after it carries the new one.
- **M1.5 `RoadBuffer`.** `road/road_buffer.gd` keeps `BUFFER_AHEAD` correct-path tiles ahead of the car, refills below `BUFFER_REFILL_AT`, and frees tiles more than `BUFFER_BEHIND` behind it, with their branches. Later milestones raised the values (`config/tuning.gd`, `docs/M5.md` L2, `docs/ROADGEN.md` R6).
- **M1.6 Grey-box renderer.** `world/iso.gd` (`tile_to_world()`: a 128×64 diamond, so the path's north-west staircase runs up the screen) and `world/world_renderer.gd`, which draws the tiles that the buffer generates and frees.
- **M1 tests.** Determinism over 2,000 tiles, the L–R pattern, occupancy over 200 seeds, the buffer's bounds, the area schedule and the capsules (§6).

### M2 — Driving (done: `docs/M2.md`)

- **M2.1 `InputRouter`.** `car/input_router.gd`: steering from −1 to 1, from the `steer_left` and `steer_right` actions, touches on either half of the screen (the last wins), or `car/autopilot.gd`, which follows the correct path's centreline. `DisasterDirector` turns it off.
- **M2.2 `CarSim`.** `car/car_sim.gd`, pure logic in tile space (D1, D2). It steers at `STEER_RATE` and straightens with no input. Its speed rises along a straight, up to a cap that grows with the distance, and always brakes to the area's junction speed within its brake distance, whichever exit is right (`plan.md` §2.3). Off the road it takes damage, and past the off-road limit it misses the turn near a junction (D6) or crashes elsewhere.
- **M2.3 `JunctionTrigger`.** `road/junction_trigger.gd`: the exit chosen is the first edge of the junction that the car crosses on the road, or the branch that it first rejoins (D5). The right exit completes the turn; a wrong or missed one triggers the disaster.
- **M2.4 `CarController` and the car.** `car/car.tscn`, `car/car_controller.gd`: steps the sim in `_physics_process`, places the car with `Iso`, shows one of 16 frames, and sorts it with the props.
- **M2.5 `CameraRig`.** `world/camera_rig.gd`: follows the car, looks ahead, and zooms in steps so that `VISIBLE_TILES` tiles fit the screen's smaller side, again on each `size_changed`.
- **M2.6 HUD and touch zones.** `ui/hud.tscn`: distance (`METRES_PER_TILE`), turns, health and the pause button, anchored so they reflow; the touch zones are the screen's two halves.
- **M2.7 `GameState` and `EventBus`.** `autoload/`: the signals of `plan.md` §7.4, and the run's state machine, whose invalid transitions `push_error`. Pausing uses `get_tree().paused`.
- **M2 tests.** Speed, off-road, the junction trigger, 300 turns of the autopilot over 20 seeds, the corner cut and the main scene's boot (§6).

### M3 — Failure (done: `docs/M3.md`)

- **M3.1 `DisasterDirector`.** On a wrong or missed turn, or a crash, `ui/main.gd` ends the run and turns the input off, and `CarSim` stops the car within `STOP_SECONDS` (`docs/M3.md` J1, J4). `disasters/disaster_director.gd` then plays a disaster from the area's pool, chosen with the run's `disaster` stream, as are its `DisasterParams`. A disaster extends `DisasterBase` (`play(params)`, `finished`), and the director ends it after `DISASTER_TIMEOUT` at most. Game over comes when it ends.
- **M3.2 Sinkhole.** The first disaster, with the camera's shake (`CameraRig.shake()`). M6's legends replaced it.
- **M3.3 Crash, game over and retry.** A crash ends the run without a disaster. `ui/game_over.tscn` shows why the run ended and its stats, with Retry, which rebuilds the run without reloading the scene, and Title. Debug builds show the seed.
- **M3 tests.** The wrong turn's disaster, retry without orphans, and the determinism of `DisasterParams`.

### M4 — Areas (done: `docs/M4.md`)

- **M4.1 Resources.** `areas/area_def.gd` and `area_schedule.gd`: each area's typed values (`plan.md` §3.7), and the schedule of turns, areas and set pieces. `prop_def.gd` came with M5's props (`docs/M4.md` K3).
- **M4.2 Five areas and the schedule.** `areas/*.tres`: City, Rural, Meadows, Village and Desert, from turns 0, 34 (after the tunnel), 100 (after the bridge), 200 and 220. Their values are tuned in the `.tres` files and `config/tuning.gd` (D11).
- **M4.3 Area transitions.** The renderer draws each tile in its area's look and blends the ground at a change. `area_changed` fires when the car enters a new area's first tile, and the HUD names the area.
- **M4.4 Set pieces.** `setpieces/set_piece.gd`, `tunnel.tscn` and `bridge.tscn`: scenes over a run of straight tiles, added once the whole run is made and freed with its last tile (`docs/M4.md` K6).
- **M4.5 Tornado, Flood, Quicksand.** The other areas' natural disasters, with the same `DisasterBase` interface. M6's legends replaced them.
- **M4 tests.** The areas' order on an autopilot run to turn 230, and a forced wrong turn in each area that plays only that area's pool.

### M5 — Content (done: `docs/M5.md`)

- **M5.1 Final art.** Each area's road, ground and props, the car's 16-direction sheet, skid marks, the pixel font and the theme, made by the scripts in `tools/art/` within the master palette, `assets/palette.gpl`. Textures import lossless, without mipmaps, and filter nearest.
- **M5.2 `PropPool`.** `world/prop_pool.gd`: reuses the props' sprites as tiles come and go.
- **M5.3 `AudioDirector`.** `autoload/audio_director.gd` and `default_bus_layout.tres`: the Master, Music, SFX and Ambient buses; each area's music and ambience, which cross-fade over `CROSS_FADE_SECONDS` (`audio/cross_fade.gd`); the engine's pitch, which follows the speed; and the volumes from the save.
- **M5.4 `SaveService`.** `autoload/save_service.gd` and `save_data.gd`: `user://save.json` as in `plan.md` §9, migrated from older versions, renamed to `.bak` when corrupt, and written atomically through a `.tmp` file after each run and soon after a setting changes.
- **M5.5 Title, Atlas, Collection and Settings.** `ui/`: the title (Play, Atlas, Disasters and Settings), the Atlas of areas with their bests, the disaster collection, and the settings (volumes, haptics and orientation, which M7.1 and M7.2 apply).
- **M5 tests.** The save's round trip, migration, recovery and atomic write, and the prop pool without leaks.

### M6 — Legends (done: `docs/M6.md`)

Five disasters from myths, folk tales and urban legends replaced the natural four, one for each area: the phantom bus (City), the UFO (Rural), the fairy ring (Meadows), the witch's hex (Village) and the death worm (Desert). `docs/M6.md` §3.3 has two more options for each area. `Legend` (`disasters/legend.gd`) adds beats on one clock, a veil that darkens the World, glows, standing parts that sort with the props, and a double that takes the car's place. Each disaster has a fate, which game over shows, and a lore, which its card in the collection shows.

---

### M7 — Ship

What the plans before it leave to M7 (each summary's §9 has more):
- **Settings.** M5 saves and shows the orientation and haptics settings. M7.1 and M7.2 read them with `SaveService.setting("orientation")` and `SaveService.setting("haptics")` (`docs/M5.md` Q3).
- **New views.** Each screen that M7 must fit, the Fold4's two included, goes in the tests' `SCREENS` lists: `test_props_in_view.gd`'s, which `test_view_veil.gd` reads too to check that the night's veil covers every view (`docs/DAYNIGHT.md` §9), `test_camera_rig.gd`'s, `test_world_renderer.gd`'s and `test_title_screen.gd`'s. Tall windows may need a larger `BUFFER_BEHIND` (`docs/M5.md` Q9).
- **Margins and tiles.** Integer scaling leaves black margins on the Fold4, where the game draws 50–78% of the screen, and the inner screen in portrait shows 3.72 tiles across, under M7.5's 5 (`docs/M2.md` H18, Q17, §6.5). M7.1 decides on both; the tiles change with `VISIBLE_TILES` or `CAMERA_ZOOMS`.
- **Haptics.** A disaster's pulse can follow `EventBus.disaster_started`, which comes once the car has stopped. They can pulse on a legend's beats, which `Beats` gives (`docs/M6.md` §5.2). If they mark a correct turn, they mark the tutorial's streak too: `EventBus.streak_changed` with a streak above 0, as the chime does (`docs/TUTORIAL.md` §5.4). The light drives neither sound nor haptics: add them to `test_the_light_changes_nothing_but_the_view`'s `_sound()`.
- **The Web.** Browsers start audio only after a gesture. The tap on Play is the first, so the title stays silent and a run's music starts on that tap (`docs/M5.md` Q4). M7.3 also decides on the gap at the end of a looped sample (`docs/M5.md` L20, Q11), unless Godot 4.8, which loops Web samples natively (godotengine/godot#123996), has come. Godot 4.7.2 tells the game nothing when a page closes, reloads or is hidden (`docs/M5.md` L10).
- **The release.** The store's content rating declares the legends' horror: fear, with no blood or gore (`docs/M6.md` Q8). The HUD shows the version and the seed in every build (`ui/hud.gd`), and game over shows the seed only in debug builds: decide what the release shows. M7.4's tag is the first run of `release.yml`'s signing and publishing; retry a failed one by re-running its own run, since a manual run fails if the tag exists (`docs/M0.md` F7, F32, §9).
- **Device checks.** In debug builds, the title's Start button chooses the area that Play starts in (`docs/ZONE_SELECT.md`), so M7.5 can check each area's art, legend and haptics on both screens and through a fold. These Fold4 checks of earlier plans aren't recorded as done: M0's E6, M2's E12, M3's E13, M4's E14, M5's E14 with its crossing run (L8) and listening (L29), M6's E11, RG's E10, ZS's E8, TUT's E9 and DN's E13, each in its summary.
- **Later.** Art for the set pieces, the river's shader, and the tunnel's darkening through `Daylight`, not a `CanvasModulate` (`docs/DAYNIGHT.md` C15).

#### M7.1 Orientation and foldables (M)
- Map the saved orientation setting to exactly one value (`sensor` → `DisplayServer.SCREEN_SENSOR`, `portrait` → `DisplayServer.SCREEN_PORTRAIT`, `landscape` → `DisplayServer.SCREEN_LANDSCAPE`) and pass only that value to `DisplayServer.screen_set_orientation()`.
- Every layout-dependent node (`CameraRig`, HUD, `TouchZones`) listens to `get_viewport().size_changed`; the run state is never touched by this path.
- Android: `display/window/size/resizable=true` → `resizeableActivity=true` (checked in the Godot 4.7.2 export plugin). Godot's activity already declares `configChanges` for screen size and orientation, so fold/unfold does **not** recreate the activity. Verify on the device (M7.5).

#### M7.2 Haptics (S)
- `Input.vibrate_handheld(30)` on damage ticks (at most 1 per 250 ms) and `vibrate_handheld(250)` when a disaster starts, gated by the setting. Requires `permissions/vibrate=true` (preset).

#### M7.3 Web specifics (S)
- Single-threaded export (preset). Do not start Music or Ambient until the first `InputEvent` (title screen "Tap to start"). Godot resumes the AudioContext on user gesture.
- Keyboard focus: `html/focus_canvas_on_start=true`.

#### M7.4 Release pipeline (S)
- Create the release keystore (offline, kept by the owner), add the repository secrets (§7.6), tag `v0.1.0`, and check that the release has the signed APK, AAB and Web zip.

#### M7.5 Device QA checklist (Galaxy Z Fold4 plus one other Android phone and desktop Chrome/Firefox)
- [ ] Cover screen (portrait 23:9) and inner screen (near-square) both show ≥ 5 tiles ahead; HUD is not clipped.
- [ ] Fold and unfold mid-run 5 times: the run continues and `turn_index` and health are unchanged.
- [ ] Rotate in sensor mode: layout reflows; orientation lock is respected.
- [ ] Touch: holding left or right steers; multitouch (holding both sides) gives "last touch wins"; the pause button never steers.
- [ ] Haptics on damage and disaster; off when disabled.
- [ ] Web: audio starts after the first tap; keyboard works; no COOP/COEP errors in the console.
- [ ] Informal 60 fps on the Fold4 (Godot monitor overlay); not a blocker (`plan.md` §10).
- [ ] A new save starts the tutorial; it reads well on both screens and through a fold.
- [ ] Side roads and decoys in each area but the City read as roads, and choosing between straight on and the turn feels fair.
- [ ] Each area's legend, day and night, on both screens.

#### M7.6 Visual screenshots (S, non-blocking)
- `tools/screenshots.gd`: boots `main.tscn` with `--seed`, `--autopilot` and `--fixed-fps 60`, drives to turns {0, 34, 100, 200, 220}, and saves PNGs for portrait (360×640) and landscape (640×360). It must drive there, not skip ahead, or it misses junctions that the game counts, and it needs `--audio-driver Dummy` (`docs/M1.md` G16).
- **Note:** `--headless` uses a dummy renderer and cannot take screenshots. The workflow runs under `xvfb-run` with `--rendering-driver opengl3` (Mesa llvmpipe). Images are uploaded as artifacts for human review, kept 1 day (§7.1); pixel diffing is post-MVP.

---

## 5. Cross-cutting technical design

### 5.1 Runtime data flow (implementation of `plan.md` §7.6)
```
_physics_process (60 Hz)
  InputRouter.steer ─▶ CarSim.step(dt, steer)
                          ├─ RoadBuffer.tile_at(cell) ─▶ RoadGeometry.is_on_road
                          ├─ cell crossed / rejoin ─▶ JunctionTrigger ─▶ EventBus.turn_completed | disaster_triggered
                          └─ path_index changed ─▶ RoadBuffer.on_car_path_index ─▶ EventBus.tiles_generated/freed ─▶ WorldRenderer
  CarController ─▶ sprite position/frame, CameraRig follow
EventBus ─▶ GameState (state machine) ─▶ HUD / AudioDirector / SaveService / DisasterDirector
```

### 5.2 Scene tree (as in `plan.md` §7.1, plus owners)
`Main` (`ui/main.tscn`, script `main.gd` owns run lifecycle) → `World` (`world.tscn`: `GroundLayer`, `RoadLayer`, `Props` + `WorldRenderer`, `PropPool`, `RoadBuffer` holder) → `DisasterLayer` → `CameraRig` → `UI` (`HUD`, `TouchZones`, `Overlays`).

### 5.3 Determinism rules
- Only `RoadGenerator` (the road's stream and `props_seed`) and `DisasterDirector` (the disaster stream) use RNG; they are seeded only from `GameState.run_seed`. Any `randf()` call on the global RNG is banned in gameplay code (enforced by a `gdlint`-adjacent grep in `tools/ci/lint.sh`).
- Simulation runs in `_physics_process` with `physics/common/physics_ticks_per_second=60`, and tests step `CarSim` with a fixed `delta`.

### 5.4 Error handling and debug
- Debug overlay (F3, debug builds only; not built yet, `docs/M2.md` §9): seed, `turn_index`, path index, lookahead, car state, speed and target, off-road distance, next junction `expected_exit` (marked as a spoiler).
- `push_error` on any broken invariant (buffer bounds, occupancy, invalid state transition). CI smoke tests fail on `ERROR:` in the log.

---

## 6. Test matrix (maps `plan.md` §11 → files)

| `plan.md` §11 requirement | Test file(s) | Milestone |
|---|---|---|
| Same seed → identical tiles | `unit/test_road_generator_determinism.gd` | M1 |
| L, R, L, R… starting with L | `unit/test_road_generator_pattern.gd` | M1 |
| No overlap between path and dead ends | `unit/test_road_generator_occupancy.gd` | M1 |
| ≥ 1 wrong exit per junction | `unit/test_road_generator_occupancy.gd` | M1 |
| Lookahead 25..50 | `unit/test_road_buffer.gd` | M1 |
| Area switches at 34/100/200/220, desert forever | `unit/test_area_schedule.gd` | M1/M4 |
| Scripted driver 300+ turns, no disaster | `sim/test_autopilot_300_turns.gd` | M2 |
| Wrong turn → disaster from the area pool | `integration/test_wrong_turn_disaster.gd`, `test_disaster_pools.gd` | M3/M4 |
| Brake before every junction, accelerate after | `unit/test_car_sim_speed.gd` | M2 |
| Corner cut within 2 tiles = correct + damage | `sim/test_corner_cut.gd` | M2 |
| > 2 tiles off-road: disaster near junction, crash on straight | `unit/test_car_sim_offroad.gd` | M2 |
| Fold/unfold keeps the run | M7.5 manual checklist | M7 |
| Headless screenshots | `visual.yml` + `tools/screenshots.gd` | M7 |

---

## 7. Build action definitions (GitHub Actions)

### 7.1 Overview

| Workflow | Trigger | Jobs | Output |
|---|---|---|---|
| `ci.yml` | `pull_request`, `push` to `main`, manual | `lint` → `test` → `export-web`, `export-android` (APK, AAB) → `deploy-web` (main only) | Pages deploy; `web`, debug APK and AAB artifacts only from a manual run with `upload-builds` |
| `release.yml` | Tag `v*.*.*`, manual | `test` → `android-release`, `web-release` → `publish` | Signed APK and AAB, Web zip on a GitHub Release |
| `visual.yml` | Manual, nightly | `screenshots` | PNG artifacts, kept 1 day (non-blocking) |

Shared logic lives in `tools/ci/*.sh` (runnable locally with the same commands) and one composite action `.github/actions/godot-env`. All jobs that run Godot use the container `barichello/godot-ci:4.7.2`, which already includes JDK 17, Android SDK, a debug keystore (`/root/debug.keystore`) and export templates. Godot export plugins read these from `~/.config/godot/editor_settings-4.7.tres`.

> **Version bump procedure:** change the image tag in all three workflows and `config/features` in `project.godot`, then re-vendor GUT if needed. `tools/ci/check_versions.sh` (run in `lint`) fails if the image tags differ from each other or from the `project.godot` minor version.

> **Actions storage policy (`docs/M0.md` F34, §5.12):** no caches of any kind, artifacts only where something needs them, and `retention-days: 1` on every upload. CI gets slower in exchange. `tools/ci/check_actions_storage.sh` (run in `lint`) enforces it. The files are the reference for §7.2–§7.5.

### 7.2 Composite action — `.github/actions/godot-env/action.yml`
Moves the CI image's export templates and editor settings where Godot looks for them, installs the Android SDK packages, and imports the project in full.

### 7.3 CI scripts — `tools/ci/`
`lint.sh`, `import.sh`, `check_scripts.sh`, `run_tests.sh`, `smoke.sh`, `export.sh`, `stamp_version.sh`, `check_versions.sh` and `check_actions_storage.sh`. CI and local runs use the same commands (`AGENTS.md` §3).

### 7.4 `.github/workflows/ci.yml`
The jobs of §7.1. A run by hand with `upload-builds` uploads the Web build, the APK and the AAB.

### 7.5 `.github/workflows/release.yml`
Tests, signs the APK and the AAB with the secrets of §7.6, zips the Web build, and publishes them on a GitHub Release.

### 7.6 Secrets and settings

| Name | Kind | Used by | Value |
|---|---|---|---|
| `ANDROID_KEYSTORE_BASE64` | Secret (env `release`) | `release.yml` | `base64 -w0 release.keystore` |
| `ANDROID_KEYSTORE_ALIAS` | Secret (env `release`) | `release.yml` | Key alias |
| `ANDROID_KEYSTORE_PASSWORD` | Secret (env `release`) | `release.yml` | Store and key password (same value) |
| Pages | Repo setting | `ci.yml` `deploy-web` | Source: GitHub Actions |
| Environment `release` | Repo setting | `release.yml` | Optional required reviewer |

PR builds from forks get no secrets. They only build debug artifacts, so this is by design.

### 7.7 `.github/workflows/visual.yml` (M7, non-blocking)
```yaml
name: Visual screenshots
on:
  workflow_dispatch:
  schedule:
    - cron: "0 3 * * 1"   # weekly, Monday 03:00 UTC
permissions:
  contents: read
jobs:
  screenshots:
    runs-on: ubuntu-24.04
    container: barichello/godot-ci:4.7.2
    steps:
      - uses: actions/checkout@v7
      - uses: ./.github/actions/godot-env
      - run: apt-get update -qq && apt-get install -y -qq xvfb libgl1-mesa-dri > /dev/null
      - run: |
          xvfb-run -a -s "-screen 0 1280x1280x24" \
            godot --path . --rendering-driver opengl3 --audio-driver Dummy --fixed-fps 60 -s tools/screenshots.gd -- \
            --seeds=1,2,3 --turns=0,34,100,200,220 --orientations=portrait,landscape --out=build/screenshots
      - uses: actions/upload-artifact@v7
        with:
          name: screenshots
          path: build/screenshots
          retention-days: 1   # Actions storage policy (§7.1)
```

### 7.8 `.github/dependabot.yml`
Weekly updates of the GitHub Actions. The `godot-ci` image's tag is bumped by hand (§7.1).

---

## 8. Risks and mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Free steering makes corner cuts ambiguous (which branch was rejoined) | Unfair deaths | Capsule geometry plus "first rejoined branch" rule (D4/D5); `test_corner_cut.gd`; debug overlay shows the pending choice |
| Auto-braking reveals the junction too late or too early at high speed | Unplayable late game | `GLOBAL_SPEED_CAP`; braking distance is per area; tune with the autopilot speed log |
| Fold/unfold restarts the Android activity | Lost run | `resizeable` setting plus Godot's `configChanges`; QA checklist; if it still fails, add an Android plugin manifest override (post-check) |
| Gradle AAB build is slow or flaky in CI | Red PRs | Separate matrix entry (`fail-fast: false`); APK stays the quick signal. No Gradle cache: CI keeps no caches (§7.1) |
| CI image lags behind Godot patch releases | Blocked upgrade | Fallback: `chickensoft-games/setup-godot@v2` with `include-templates: true` and `cache: false` (§7.1) plus `android-actions/setup-android@v4` and `actions/setup-java` (17); scripts in `tools/ci` stay the same |
| Headless rendering cannot take screenshots | No visual tests | `xvfb` with `opengl3` in a separate, non-blocking workflow |
| GUT and Godot 4.7 stricter typing on doubles | Test false positives | GUT 9.7.1; prefer real `RefCounted` objects over doubles in tests |
| Generator edge cases (collisions, area switch mid-set-piece) | Broken roads | Property tests over hundreds of seeds; `assert`s plus `push_error` in debug builds; smoke run in CI |

---

## 9. MVP definition of done
- [ ] All `plan.md` §11 automated tests exist and pass in CI (§6 matrix).
- [ ] `ci.yml` is green on `main`; Pages serves the latest Web build; debug APK and AAB artifacts (from a manual run with `upload-builds`) install and run.
- [ ] `v0.1.0` tag produces a GitHub Release with a signed APK, AAB and Web zip.
- [ ] All 5 areas, tunnel and bridge appear in order during an autopilot run to turn 230, and a wrong turn in each area plays its legend (M6).
- [ ] Atlas, disaster collection and settings persist across restarts (`user://save.json` v1).
- [ ] M7.5 device QA checklist passes on the Galaxy Z Fold4 and in desktop Chrome and Firefox.
