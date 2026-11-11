# Road Roguelike — MVP Implementation Plan

Status: v1, derived from `plan.md` (Draft v2)
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
| Art / audio | Aseprite → PNG; OGG / WAV | As in `plan.md` §5.4 and §6. |

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
| M6 | Each area's disaster comes from a legend, with its veil, art, sound, fate and lore, and nothing flashes (`M6_PLAN.md`) | L |
| M7 | Orientation and foldable handling, haptics, Web audio unlock, signed release pipeline, device QA | M |

---

## 4. Work packages

Each package lists **Deliverables**, **Details**, **Acceptance** and **Tests**.

### M0 — Bootstrap and CI

#### M0.1 Project skeleton (S)
- **Deliverables:** `project.godot`, `.gitignore`, `.gdlintrc`, folder skeleton, `ui/main.tscn` (empty `Main` with a label), `icon.svg`.
- **Details (project settings):**
  - `application/config/name="Road Roguelike"`, `config/features=PackedStringArray("4.7", "GL Compatibility")`
  - `rendering/renderer/rendering_method="gl_compatibility"` and `.mobile="gl_compatibility"`
  - `display/window/size/viewport_width=360`, `viewport_height=640`
  - `display/window/stretch/mode="canvas_items"`, `aspect="expand"`, `scale_mode="integer"`
  - `display/window/handheld/orientation=6` (sensor; portrait is the default via the base size)
  - `display/window/size/resizable=true` (Godot uses this for Android `resizeableActivity`, needed for fold/unfold)
  - `rendering/textures/canvas_textures/default_texture_filter=0` (nearest), `rendering/2d/snap/snap_2d_transforms_to_pixel=true`
  - `debug/gdscript/warnings/untyped_declaration=2` (error)
  - InputMap: `steer_left` (←, A), `steer_right` (→, D), `pause` (Esc, P), `ui_accept` (Enter, Space)
- **Acceptance:** `godot --headless --path . --quit-after 10` exits 0 with no errors.

#### M0.2 Test harness (S)
- **Deliverables:** `addons/gut/` (v9.7.1, plugin enabled), `.gutconfig.json`, `tests/unit/test_smoke.gd`.
- `.gutconfig.json`:
  ```json
  {
    "dirs": ["res://tests/unit/", "res://tests/sim/", "res://tests/integration/"],
    "include_subdirs": true,
    "prefix": "test_",
    "suffix": ".gd",
    "log_level": 1,
    "should_exit": true,
    "should_exit_on_success": true
  }
  ```
- **Acceptance:** `tools/ci/run_tests.sh` exits 0 locally and in CI, and writes `build/reports/gut-junit.xml`.

#### M0.3 Export presets (S)
- **Deliverables:** `export_presets.cfg` with three presets (exact option keys checked against the Godot 4.7.2 source):

| Preset name | Key options |
|---|---|
| `Web` | `platform="Web"`, `export_path="build/web/index.html"`, `variant/thread_support=false` (single-threaded, no COOP/COEP), `variant/extensions_support=false`, `html/canvas_resize_policy=2` (adaptive), `html/focus_canvas_on_start=true`, `progressive_web_app/enabled=false` |
| `Android APK` | `platform="Android"`, `gradle_build/use_gradle_build=false`, `package/unique_name="com.pompomon.roadgame"`, `version/code=1`, `version/name="0.0.0"`, `architectures/arm64-v8a=true`, `architectures/armeabi-v7a=true`, `permissions/vibrate=true`, `screen/immersive_mode=true`, `keystore/release=""` (CI uses environment variables) |
| `Android AAB` | Same as APK, plus `gradle_build/use_gradle_build=true`, `gradle_build/export_format=1` (AAB), `gradle_build/min_sdk=""` / `target_sdk=""` (defaults: 24 / 36) |

- **Rule:** never commit keystore paths or passwords. Release signing uses `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`, `GODOT_ANDROID_KEYSTORE_RELEASE_USER` and `GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD`. Debug builds use the debug keystore from the CI image.

#### M0.4 CI scripts and build actions (M)
- **Deliverables:** `tools/ci/*.sh`, `.github/actions/godot-env/action.yml`, `.github/workflows/ci.yml`, `.github/workflows/release.yml`, `.github/dependabot.yml`. Full definitions are in §7.
- **Repository settings:** Pages source = "GitHub Actions"; branch protection on `main` requires `lint`, `test`, `export-web`, `export-android (Android APK)` and `export-android (Android AAB)`.
- **Acceptance:** a PR shows all required checks green, artifacts `web`, `android-Android APK` and `android-Android AAB` download and run. After merge, the Pages URL serves the build.

---

### M1 — Generator

#### M1.1 `Heading` and geometry helpers (S) — `road/heading.gd`, `road/road_geometry.gd`
```gdscript
class_name Heading
enum { N, E, S, W }
const VEC: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
static func left(h: int) -> int: return (h + 3) % 4
static func right(h: int) -> int: return (h + 1) % 4
static func opposite(h: int) -> int: return (h + 2) % 4
static func turn_for(turn_number: int, h: int) -> int: return left(h) if turn_number % 2 == 0 else right(h)
```
- `RoadGeometry.is_on_road(tile: RoadTile, local: Vector2) -> bool`: `local` is in [0,1]², and the result is true if the distance to any segment `centre → edge_mid(exit)` is ≤ `ROAD_HALF_WIDTH` (decision D4). Edge midpoints: N `(0.5, 0)`, E `(1, 0.5)`, S `(0.5, 1)`, W `(0, 0.5)`.
- **Tests:** turn maths; `is_on_road` for each tile type at the centre, at the edges and in the corners (corners of a straight tile are off-road).

#### M1.2 `RoadTile` (S) — `road/road_tile.gd`
| Field | Type | Notes |
|---|---|---|
| `cell` | `Vector2i` | Grid cell |
| `type` | `int` | `STRAIGHT, CORNER, T_JUNCTION, CROSS_JUNCTION, DEAD_END, SET_PIECE` |
| `heading` | `int` | Direction of travel when entering this tile |
| `exits` | `int` (bitmask of headings) | Road connections, including the entry edge |
| `path_index` | `int` | Index on the correct path; `-1` for dead-end tiles |
| `area_id` | `StringName` | Area that owns the tile |
| `turn_number` | `int` | Junctions only; 0-based (`turn_number` 0 expects **L**) |
| `expected_exit` | `int` | Junctions only |
| `junction` | `RoadTile` (weak ref) | For dead-end tiles: their junction; for correct-path tiles, use path indices to identify their junction's reachable correct exit |
| `branch_exit` | `int` | For branch tiles: the heading of the junction exit they continue |
| `branches` | `Array[RoadTile]` | Junctions only: owned dead-end tiles (freed with the junction) |
| `set_piece` | `StringName` | `&"tunnel"`, `&"bridge"` or `&""` |
- Junction tiles are typed as `T_JUNCTION` (3 exits) or `CROSS_JUNCTION` (4 exits) **after** dead-end placement, because a failed placement can downgrade a crossroads (`plan.md` §3.3).

#### M1.3 `OccupancyGrid` (S) — `road/occupancy_grid.gd`
- A `Dictionary[Vector2i, RoadTile]` with `is_free(cell)`, `claim(cell, tile)`, `release(cell)`.
- **Invariant:** one tile per cell; claiming an occupied cell is an `assert`.

#### M1.4 `RoadGenerator` (L) — `road/road_generator.gd`
- **API:**
  ```gdscript
  func _init(seed: int, schedule: AreaSchedule) -> void
  func next_tile() -> RoadTile          # next correct-path tile (junction branches attached)
  var occupancy: OccupancyGrid
  var current_area: AreaDef
  ```
- **State:** `cursor: Vector2i`, `heading: int`, `turn_count: int` (junctions generated so far), `straight_left: int`, `pending_set_piece: int`, `schedule_ptr: int`, `rng_road`, `rng_props`.
- **Algorithm (one correct-path tile per call):**
  ```
  next_tile():
    if straight_left == 0 and pending_set_piece == 0:
        # emit junction at cursor
        exp := Heading.turn_for(turn_count, heading)
        J := RoadTile(JUNCTION, cell=cursor, heading, expected_exit=exp, turn_number=turn_count)
        wrong := [opposite turn]
        if rng_road.randf() < area.cross_junction_chance: wrong.append(heading)   # straight on
        placed := 0
        for w in wrong: placed += try_place_dead_end(J, w, len=rng_road.randi_range(2,3))
        if placed == 0:  # D7 guarantees the 1-tile opposite stub fits; this is a defensive fallback
            for w in [opposite turn, heading]: if try_place_dead_end(J, w, 1): break
        assert(J.branches.size() > 0)
        J.type = CROSS if both wrong exits are present else T
        heading = exp; turn_count += 1
        if schedule hits turn_count:
            pending_area = entry.area
            if entry.set_piece_length > 0:
                pending_set_piece = entry.set_piece_length
                straight_left = 0
            else:
                current_area = pending_area; pending_area = null
                straight_left = rng_road.randi_range(current_area.min_straight, current_area.max_straight)
        else:
            straight_left = rng_road.randi_range(current_area.min_straight, current_area.max_straight)
        claim, advance cursor, return J
    elif pending_set_piece > 0:
        emit SET_PIECE straight tile (area = current_area); pending_set_piece -= 1
        when it reaches 0: current_area = pending_area; pending_area = null
                          straight_left = randi_range(current_area.min_straight, current_area.max_straight)
    else:
        emit STRAIGHT tile; straight_left -= 1
  try_place_dead_end(J, dir, len):
    for L in [len, 1]:  # shorten to 1 on collision
        cells := [J.cell + VEC[dir]*k for k in 1..L]
        if all occupancy.is_free(cells) and none equals the next correct cell: claim; build DEAD_END tiles
             (last tile has a cap = exits only toward J); return 1
    return 0
  ```
- **Area switches:** scheduled junction and set-piece tiles retain the current area's `area_id`. If there is a set piece, switch `current_area` only after emitting its final tile; otherwise switch immediately after the scheduled junction and before sampling the following straight's length. The first subsequent tile carries the new area's `area_id`. At runtime `area_changed` is emitted when the car enters the first tile of a new area (M4.3).
- **Proof sketch, checked by property tests:** the correct path is monotonic in −x and −y. Wrong exits always point "outward" (E/S, or straight on N/W while the path turns), so dead ends can only collide with **other dead ends**, never with the future correct path. With `min_straight >= 2` the 1-tile opposite stub cell is always free.
- **Props:** `rng_props` places ground variants and props per tile into `tile.decor: Array[Dictionary]` (`{cell32: Vector2i, prop_id, variant}`), keeping `PropDef.min_distance_from_road`. The road stream is **never** used for props (`plan.md` §3.5).

#### M1.5 `RoadBuffer` (M) — `road/road_buffer.gd`
- Holds `path: Array[RoadTile]` (correct-path tiles only, with a sliding base index), owns the `RoadGenerator`, and emits `EventBus.tiles_generated` / `tiles_freed`.
- `start()`: generate 50. `on_car_path_index(i)`: if `lookahead(i) < 25` → generate until `lookahead == 50`; free every tile with `path_index < i - 5`, including its junction branches, and release occupancy.
- `tile_at(cell) -> RoadTile` lookup (via the occupancy grid) for the car and the junction trigger.
- **Constants** (`config/tuning.gd`): `BUFFER_AHEAD = 50`, `BUFFER_REFILL_AT = 25`, `BUFFER_BEHIND = 5`.

#### M1.6 Grey-box renderer (M) — `world/iso.gd`, `world/world_renderer.gd`, `world/world.tscn`
- `Iso.tile_to_world(p: Vector2) -> Vector2 = Vector2((p.x - p.y) * 64.0, (p.x + p.y) * 32.0)` (128×64 diamond). The inverse is used for touch debugging only.
  - Grid N `(0,-1)` → screen up-right, W `(-1,0)` → up-left, so the N/W staircase runs **straight up the screen**, which suits portrait.
- `WorldRenderer` listens to `tiles_generated` / `tiles_freed`. It sets `RoadLayer` cells from `(type, exits)` → atlas coordinates using a lookup table, fills `GroundLayer` with 4×4 ground cells per road tile, and asks `PropPool` for props.
- Grey-box tileset `assets/greybox/road.png`: 15 flat-colour diamonds (2 straights, 4 corners, 4 T-junctions, 1 crossroads, 4 caps) with each dead end tinted in a debug build.
- **Acceptance:** a debug scene `tools/debug_road.tscn` scrolls a camera along the path with ↑ and shows refills and frees happening.

#### M1 tests (`tests/unit/`)
| File | Checks (`plan.md` §11) |
|---|---|
| `test_road_generator_determinism.gd` | Same seed → identical `(cell, type, exits, area_id, decor)` for 2,000 tiles; changing prop density does not change the road |
| `test_road_generator_pattern.gd` | Junction `expected_exit` follows L, R, L, R… starting with L; headings only N/W after turn 0 |
| `test_road_generator_occupancy.gd` | Over 200 seeds × 500 turns: no shared cells; each junction has ≥ 1 branch; branch length 1..3 |
| `test_road_buffer.gd` | Lookahead stays in 25..50 after random car advances (fuzzed); tiles behind −5 are freed along with their branches |
| `test_area_schedule.gd` | Area switches and set pieces happen at turns 34 (tunnel → rural), 100 (bridge → meadows), 200 (village) and 220 (desert); set-piece tiles keep the old area, the first following tile gets the new area, and no-set-piece switches occur before sampling the following straight; desert still active at turn 1,000 |
| `test_road_geometry.gd` | `is_on_road` capsule cases |

---

### M2 — Driving

#### M2.1 `InputRouter` (S) — `car/input_router.gd`
- Output: `steer: float` in [-1, 1]. Sources, combined by "last non-zero wins":
  - Actions `steer_left` / `steer_right` (keyboard, and any gamepad mapped later).
  - Touch: tracks active touch indices; x < viewport width / 2 → −1, otherwise +1. Zones come from `TouchZones` (M2.6), so the pause button area is excluded.
  - `Autopilot` (scripted): enabled by `-- --autopilot` or by tests.
- `enabled: bool` — `DisasterDirector` turns it off.

#### M2.2 `CarSim` (L) — `car/car_sim.gd` (pure logic)
- **State:** `pos: Vector2` (tile space), `angle: float` (radians, 0 = N), `speed: float` (tiles/s), `health: float`, `state` (`DRIVING, BRAKING, OFFROAD, DISASTER, CRASHED`), `dist_total`, `dist_on_straight`, `offroad_dist`, `offroad_junction: RoadTile`.
- **Steering:** `angle += steer * STEER_RATE * delta`. With no input: ease `angle` toward the nearest multiple of π/2 at `STRAIGHTEN_RATE` (the "straightens slightly" behaviour). Velocity = `Vector2(sin(angle), -cos(angle)) * speed`.
- **Speed model** (`plan.md` §2.3):
  ```
  run_cap  = min(GLOBAL_SPEED_CAP, BASE_TOP_SPEED + dist_total * TOP_SPEED_GROWTH)
  target   = min(run_cap, area.junction_speed + area.straight_accel * dist_on_straight)
  d_next   = path distance from the car to the centre of the next unresolved junction
  if d_next <= area.junction_brake_distance: target = area.junction_speed   # always, never reveals the answer
  if state == OFFROAD: target *= area.offroad_speed_mult
  speed    = move_toward(speed, target, (ACCEL if target > speed else BRAKE) * delta)
  ```
  `dist_on_straight` resets to 0 when a junction is resolved.
- **Off-road** (`plan.md` §2.4, D6):
  - Each step: `tile = buffer.tile_at(floor(pos))`; on-road = `tile != null and RoadGeometry.is_on_road(tile, frac(pos))`.
  - Road → off-road: state `OFFROAD`, `offroad_dist = 0`, and `offroad_junction` = the next unresolved junction if the car is "near" it (D6), otherwise `null`.
  - While off-road: `health -= area.offroad_damage_per_sec * delta`; `offroad_dist += speed * delta`.
  - Off-road → road: notify `JunctionTrigger.on_rejoin(tile)`, then state `DRIVING`.
  - `offroad_dist >= area.offroad_limit_tiles` → if `offroad_junction` is set, report a **missed turn** (disaster); otherwise **crash**.
  - `health <= 0` → crash.
- **Outputs:** signals or callbacks `health_changed`, `crashed(cause)`, `path_index_changed(i)`.

#### M2.3 `JunctionTrigger` (M) — `road/junction_trigger.gd`
- Tracks `next_junction` (the first unresolved junction ahead on the path).
- `on_cell_crossed(from_cell, to_cell, on_road)`: if `from_cell == next_junction.cell` and the car was on road, `choice = heading(to_cell - from_cell)`. Ignore the entry edge (`opposite(J.heading)`); re-entering the approach means no decision yet.
- `on_rejoin(tile)`: if `tile.junction == next_junction` → `choice = tile.branch_exit`; otherwise, if `tile.path_index` is after `next_junction.path_index` and no later than the following junction's path index, the rejoin is on the correct exit → `choice = next_junction.expected_exit`. If `tile` is the approach tile, make no decision.
- `resolve(choice)`: if equal to `expected_exit` → `GameState.turn_index += 1`, emit `turn_completed`, and set `next_junction` to the next one; otherwise emit `disaster_triggered(area, junction)`.
- `on_offroad_limit()` with a pending junction → `disaster_triggered` (missed turn).
- Straight on at a T-junction with no straight exit leaves the road at the far edge, which then hits the off-road limit and becomes a disaster. No special case is needed.

#### M2.4 `CarController` and car scene (M) — `car/car.tscn`, `car/car_controller.gd`
- `Node2D` with `Sprite2D` (16-direction sheet; grey box = 16 coloured arrows), `GPUParticles2D` dust, and `AudioStreamPlayer2D` engine.
- `_physics_process(delta)`: `sim.step(delta, input.steer)`, then `position = Iso.tile_to_world(sim.pos)`. Frame = `posmod(roundi(screen_angle / (TAU / 16.0)), 16)`, where `screen_angle` is the angle of the isometric-projected velocity.
- Y-sorting: the car lives under `World/Props` (`y_sort_enabled`), with the sprite offset so the pivot is at the base.

#### M2.5 `CameraRig` (S) — `world/camera_rig.gd`
- Follows the car with smoothing. Look-ahead offset = projected heading × `LOOKAHEAD_PX`; portrait adds a vertical bias so the car sits in the lower third.
- Zoom: `zoom = snap(min(vp.x, vp.y) / (VISIBLE_TILES * 71.6))`, where 71.6 px is one tile step on screen and `VISIBLE_TILES = 5`. Snap to {0.5, 1, 2} to keep pixels crisp. Recalculated on `get_viewport().size_changed`.

#### M2.6 HUD and touch zones, grey box (S) — `ui/hud.tscn`, `ui/touch_zones.tscn`
- HUD: distance (tiles → "m", 1 tile = 10 m for display), turns, health bar, pause button. Anchors are full-rect presets, so the layout reflows on `size_changed`.
- `TouchZones`: two full-height `Control`s (left and right halves) that pass touches through; the pause button sits on top.

#### M2.7 `GameState` and `EventBus` (S) — autoloads
- `EventBus` signals exactly as in `plan.md` §7.4, plus `car_offroad_changed(is_offroad)` and `paused_changed(paused)`.
- `GameState`: `enum State { TITLE, RUNNING, PAUSED, DISASTER, CRASH, GAME_OVER }`; `start_run(seed := -1)`, `pause()`, `resume()`, `end_run(cause)`. It keeps `turn_index`, `distance`, `area_id`, `seed` and `max_area_reached`. Transitions are validated by a table, and invalid ones `push_error`.
- Pausing uses `get_tree().paused`; UI overlays use `process_mode = ALWAYS`.

#### M2 tests
| File | Checks |
|---|---|
| `tests/unit/test_car_sim_speed.gd` | Speed rises along a straight; the top speed grows with `dist_total` and is capped; braking to `junction_speed` starts at `brake_distance` for **both** correct and wrong approaches; it accelerates again afterwards |
| `tests/unit/test_car_sim_offroad.gd` | Damage per second; limit on a straight → crash; limit near a junction → missed-turn disaster; health 0 → crash |
| `tests/unit/test_junction_trigger.gd` | Correct exit → `turn_completed`; wrong exit, or straight at a crossroads → disaster; rejoin on the first or second reachable correct-path tile → success with damage; rejoin on a dead end → disaster |
| `tests/sim/test_autopilot_300_turns.gd` | `Autopilot` (pure pursuit on the correct-path centreline) completes 300+ turns for 20 seeds with no disaster, at fixed `delta = 1/60` |
| `tests/sim/test_corner_cut.gd` | A scripted path that cuts the inside corner and rejoins within 2 tiles → correct turn, health < 100 |
| `tests/integration/test_main_scene_boot.gd` | `main.tscn` instantiates, starts a run with seed 1, runs 600 frames, and logs no errors |

---

### M3 — Failure

#### M3.1 `DisasterDirector` (M) — `disasters/disaster_director.gd`
- On `disaster_triggered(area, junction)`: `GameState` → `DISASTER`; disable input; tween the car to a stop (or into the dead end if the choice was a dead end) over 0.6 s; pick a scene from `area.disasters` using the `disaster` RNG stream.
- `DisasterParams` (`RefCounted`): `seed, direction: Vector2, intensity: float (0.5..1.0), delay: float, particle_scale: float, origin_world: Vector2`, all from the disaster stream.
- `DisasterBase` (`Node2D`) interface: `func play(params: DisasterParams) -> void` and `signal finished`. Each sequence must finish in 2–4 s; a director timeout of 6 s forces `finished`.
- After `finished`: `SaveService.record_disaster(id, area, stats)` and `GameState.end_run(&"disaster")`.

#### M3.2 Sinkhole (M) — `disasters/sinkhole.tscn`
- Grey box first: a growing dark ellipse with a shader (`disasters/shaders/hole.gdshader`), a debris `GPUParticles2D`, the car sinking (scale/position tween plus a clip mask), and screen shake from `CameraRig.shake(intensity)`.

#### M3.3 Crash, game over and retry (S) — `ui/game_over.tscn`
- Crash: crash frame, smoke particles, 1.2 s, then `end_run(&"crash")`.
- Game over shows distance, turns, area reached and cause (`plan.md` §2.1.7). Buttons: **Retry** (new seed → `RUNNING`) and **Title**. The seed is shown in small text in debug builds.
- Retry fully rebuilds `World`, `RoadBuffer` and the car without reloading the scene tree (fast, and keeps `PropPool`).

#### M3 tests
- `tests/integration/test_wrong_turn_disaster.gd`: the autopilot deliberately takes the wrong exit at turn 3 → `disaster_triggered` once → the disaster scene is from the city pool → `run_ended(&"disaster")` within 6 s of simulated time.
- `tests/integration/test_retry.gd`: retry resets `turn_index`, health and buffer; there are no orphan nodes (`assert_no_new_orphans`).
- `tests/unit/test_disaster_params.gd`: same seed → same params; different seeds → different params.

---

### M4 — Areas

#### M4.1 Resources (S) — `areas/area_def.gd`, `prop_def.gd`, `area_schedule.gd`
- `AreaDef` exactly as in `plan.md` §3.7 (typed `@export`s). Add `id_color: Color` for grey box and `set_piece_length` on the schedule entry.
- `AreaSchedule`: `entries: Array[AreaScheduleEntry]` where `AreaScheduleEntry { turn: int, area: AreaDef, set_piece: PackedScene, set_piece_length: int }`. A validator checks that turns increase strictly and that the first entry is turn 0.

#### M4.2 Five areas plus schedule (M) — `areas/*.tres`
Starting tuning values (placeholders, to be tuned in playtests):

| Area | min/max straight | cross chance | straight_accel | brake dist | junction speed | offroad mult | dmg/s | Disasters |
|---|---|---|---|---|---|---|---|---|
| City | 2 / 5 | 0.40 | 0.50 | 1.25 | 2.0 | 0.50 | 30 | Sinkhole |
| Rural | 3 / 7 | 0.25 | 0.60 | 1.25 | 2.2 | 0.60 | 25 | Tornado |
| Meadows | 3 / 7 | 0.30 | 0.60 | 1.25 | 2.2 | 0.60 | 25 | Flood |
| Village | 2 / 5 | 0.35 | 0.55 | 1.25 | 2.0 | 0.55 | 30 | Flood, Tornado |
| Desert | 3 / 8 | 0.30 | 0.70 | 1.50 | 2.4 | 0.45 | 35 | Quicksand |

Global constants (`config/tuning.gd`): `BASE_TOP_SPEED = 4.0`, `TOP_SPEED_GROWTH = 0.002` (per tile), `GLOBAL_SPEED_CAP = 7.0`, `ACCEL = 2.0`, `BRAKE = 4.0`, `STEER_RATE = 3.0 rad/s`, `STRAIGHTEN_RATE = 1.0 rad/s`, `offroad_limit_tiles = 2.0` (all areas).

Schedule: `0 → city`, `34 → rural (tunnel, 6 tiles)`, `100 → meadows (bridge, 5 tiles)`, `200 → village`, `220 → desert`.

#### M4.3 Area transitions at runtime (S)
- `WorldRenderer` picks the tileset and ground variants per tile `area_id`. The first `transition_tiles` ground cells of a new area use the transition atlas.
- `GameState` emits `area_changed(area_def)` when the car's current tile `area_id` changes. HUD shows the area name banner for 2 s, and `AudioDirector` cross-fades (M5).

#### M4.4 Set pieces (M) — `setpieces/tunnel.tscn`, `bridge.tscn`, `set_piece.gd`
- `SetPiece` (`Node2D`): `func setup(first_tile: RoadTile, length: int, heading: int)`. It is spawned by `WorldRenderer` when it sees the first `SET_PIECE` tile, and freed with the last one.
- Tunnel: walls and roof overlay sprites with an occluding top layer, darkening `CanvasModulate`, and a reverb send on SFX (M5).
- Bridge: water layer with an animated shader under the road, railings (which also act as off-road blockers visually; logically, off-road still uses the capsule test).

#### M4.5 Tornado, Flood, Quicksand (M each, grey box first)
- Same `DisasterBase` interface. Params drive direction (tornado path), water rise speed (flood) and sink speed (quicksand).

#### M4 tests
- `test_area_schedule.gd` (extended): runtime `area_changed` order is `city, rural, meadows, village, desert` for an autopilot run to turn 230.
- `test_disaster_pools.gd`: a forced wrong turn in each area spawns a disaster from that area's pool only.

---

### M5 — Content

#### M5.1 Final art (L, parallel with M5.2–M5.4)
- Per area: road tiles (15), 3–4 ground variants, 6–10 props, 1–2 transition tiles (`plan.md` §5.3). Shared: car (16 directions + crash frame), dust, smoke, skid marks, UI theme and pixel font.
- Import preset (`.import` defaults via `project.godot` → `importer_defaults/texture`): `compress/mode=0` (lossless), `mipmaps/generate=false`; filtering stays nearest through the project default.
- `assets/palette.gpl` master palette (16–32 colours) with a sub-palette per area; check palette compliance with `tools/check_palette.py` (optional, local only).

#### M5.2 `PropPool` (S) — `world/prop_pool.gd`
- `acquire(prop_def) -> Node2D` / `release(node)`; pre-warms 64 nodes per prop scene used in the current and next area. Freed tiles return their props.

#### M5.3 `AudioDirector` (M) — `autoload/audio_director.gd`, `default_bus_layout.tres`
- Buses: `Master → Music, SFX, Ambient`; `SFX` gets a `AudioEffectReverb` that is enabled only while the car is in a tunnel tile.
- Two `AudioStreamPlayer`s each for Music and Ambient, with a 1.5 s cross-fade on `area_changed`. Engine pitch = `lerp(0.8, 1.6, speed / GLOBAL_SPEED_CAP)`.
- Bus volumes come from `SaveService.settings`.

#### M5.4 `SaveService` (M) — `autoload/save_service.gd`
- Schema exactly as in `plan.md` §9, `version: 1`. Load: parse JSON → `_migrate(data)` (a table of `from_version → Callable`) → fill missing keys with defaults. A corrupt file is renamed to `save.json.bak` and the defaults are used.
- Atomic write: write `user://save.json.tmp` → `DirAccess.rename_absolute` over `save.json`. Writes happen on `run_ended` and when settings change (debounced by 0.5 s).
- `record_run(stats)` updates `atlas[area].discovered`, per-area best distance and best turns, and overall best. `record_disaster(id, area, stats)` updates `seen` and `first_area`.

#### M5.5 Title, Atlas, Collection and Settings UI (M)
- Title: Play, Atlas, Disasters, Settings. Atlas: 5 area cards (shown as silhouettes until discovered) with best distance and turns. Collection: a grid of 4 disasters with seen count. Settings: music, SFX and ambient sliders, haptics toggle, orientation (`sensor`, `portrait`, `landscape`).

#### M5 tests
- `test_save_service.gd`: round trip, migration from a fake v0 file, corrupt-file recovery, atomic write leaves no `.tmp` behind.
- `test_prop_pool.gd`: there are no leaks after 1,000 acquire/release cycles.

---

### M6 — Legends

`M6_PLAN.md` has the details. Five disasters from myths, folk tales and urban legends replaced the natural four, one for each area: the phantom bus (City), the UFO (Rural), the fairy ring (Meadows), the witch's hex (Village) and the death worm (Desert). Its §3.3 has two more options for each area. `Legend` (`disasters/legend.gd`) adds beats on one clock, a veil that darkens the World, glows, standing parts that sort with the props, and a double that takes the car's place. Each disaster has a fate, which game over shows, and a lore, which its card in the collection shows.

---

### M7 — Ship

`M5_PLAN.md` §9's notes for M6 apply to M7.

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

#### M7.6 Visual screenshots (S, non-blocking)
- `tools/screenshots.gd`: boots `main.tscn` with `--seed`, `--autopilot` and `--fixed-fps 60`, fast-forwards to turns {0, 34, 100, 200, 220}, and saves PNGs for portrait (360×640) and landscape (640×360).
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
- Only `RoadGenerator` (road and props streams) and `DisasterDirector` (disaster stream) use RNG; they are seeded only from `GameState.seed`. Any `randf()` call on the global RNG is banned in gameplay code (enforced by a `gdlint`-adjacent grep in `tools/ci/lint.sh`).
- Simulation runs in `_physics_process` with `physics/common/physics_ticks_per_second=60`, and tests step `CarSim` with a fixed `delta`.

### 5.4 Error handling and debug
- Debug overlay (F3, debug builds only): seed, `turn_index`, path index, lookahead, car state, speed and target, off-road distance, next junction `expected_exit` (marked as a spoiler).
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

> **Actions storage policy (`M0_PLAN.md` F34, §5.12):** no caches of any kind, artifacts only where something needs them, and `retention-days: 1` on every upload. CI gets slower in exchange. `tools/ci/check_actions_storage.sh` (run in `lint`) enforces it. The §7.2–§7.5 listings predate the policy; `M0_PLAN.md` Appendix B has the current files.

### 7.2 Composite action — `.github/actions/godot-env/action.yml`
```yaml
name: Godot environment
description: >
  Prepare the barichello/godot-ci container: move export templates and editor
  settings into $HOME, optionally install Android SDK packages for Godot 4.7,
  restore the import cache and import the project.
inputs:
  android:
    description: Install Android SDK platform/build-tools required by Godot's gradle build
    default: "false"
runs:
  using: composite
  steps:
    - name: Relocate templates and editor settings
      shell: bash
      run: |
        set -euo pipefail
        ver="$(godot --version | cut -d. -f1-4)"        # e.g. 4.7.2.stable
        mkdir -p "$HOME/.local/share/godot/export_templates" "$HOME/.config"
        if [ "$HOME" != "/root" ]; then
          mv "/root/.local/share/godot/export_templates/$ver" "$HOME/.local/share/godot/export_templates/$ver"
          mv /root/.config/godot "$HOME/.config/godot"
        fi
        echo "GODOT_TEMPLATE_VERSION=$ver" >> "$GITHUB_ENV"
        godot --version

    - name: Install Android SDK packages
      if: inputs.android == 'true'
      shell: bash
      run: |
        set -euo pipefail
        sdk="${ANDROID_HOME:-/usr/lib/android-sdk}"
        sdkm="$sdk/cmdline-tools/latest/bin/sdkmanager"
        [ -x "$sdkm" ] || sdkm="$(command -v sdkmanager)"
        "$sdkm" --licenses > /dev/null < <(yes)
        "$sdkm" --install "platform-tools" "platforms;android-36" "build-tools;36.1.0"

    - name: Restore Godot import cache
      uses: actions/cache@v6
      with:
        path: .godot
        key: godot-import-${{ runner.os }}-${{ hashFiles('project.godot', '**/*.import') }}
        restore-keys: godot-import-${{ runner.os }}-

    - name: Import project
      shell: bash
      run: tools/ci/import.sh
```

### 7.3 CI scripts — `tools/ci/`
All scripts start with `#!/usr/bin/env bash` and `set -euo pipefail`, and are run from the repository root.

`import.sh` — import resources and fail on script errors:
```bash
mkdir -p build/reports
godot --headless --path . --import 2>&1 | tee build/reports/import.log
if grep -E "SCRIPT ERROR|Parse Error|Failed to load script" build/reports/import.log; then
  echo "::error::GDScript errors during import"; exit 1
fi
```

`run_tests.sh` — GUT unit, sim and integration tests plus JUnit output:
```bash
mkdir -p build/reports
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gconfig=res://.gutconfig.json \
  -gjunit_xml_file=build/reports/gut-junit.xml \
  -gexit
```

`smoke.sh` — boot the real main scene and simulate 60 s of autopilot driving:
```bash
mkdir -p build/reports
godot --headless --path . --fixed-fps 60 --quit-after 3600 -- --autopilot --seed=12345 \
  2>&1 | tee build/reports/smoke.log
if grep -E "SCRIPT ERROR|^ERROR:" build/reports/smoke.log; then
  echo "::error::Errors during smoke run"; exit 1
fi
```

`export.sh <preset> <output> [debug|release]` — export and verify the file exists:
```bash
preset="$1"; out="$2"; mode="${3:-release}"
mkdir -p "$(dirname "$out")"
extra=()
[[ "$preset" == "Android AAB" ]] && extra+=(--install-android-build-template)
godot --headless --path . "${extra[@]}" "--export-$mode" "$preset" "$out" 2>&1 | tee "$out.log"
test -s "$out" || { echo "::error::Export '$preset' produced no file"; exit 1; }
```

`stamp_version.sh <semver>` — set Android `version/name` and `version/code` (D9) and `application/config/version`:
```bash
v="${1#v}"; IFS=. read -r ma mi pa <<<"$v"
code=$((ma*1000000 + mi*1000 + pa))
sed -i -E "s/^version\/name=.*/version\/name=\"$v\"/; s/^version\/code=.*/version\/code=$code/" export_presets.cfg
sed -i -E "s/^config\/version=.*/config\/version=\"$v\"/" project.godot
```

`lint.sh` — style and rule checks (no Godot needed):
```bash
dirs=(autoload road world car disasters areas setpieces ui config tests tools)
gdlint "${dirs[@]}"
gdformat --check "${dirs[@]}"
# Determinism rule (§5.3): no global RNG in gameplay code (`! cmd` is ignored by `set -e`, so use `if`)
if grep -rnE "\b(randf|randi|randf_range|randi_range|randomize)\(" autoload road world car disasters areas setpieces \
     | grep -vE "rng_[a-z]+\.|\.rng\."; then
  echo "::error::Global RNG used in gameplay code; use a seeded RandomNumberGenerator stream"; exit 1
fi
tools/ci/check_versions.sh
```

`check_versions.sh` — keep the Godot version consistent:
```bash
tags=$(grep -rhoE "barichello/godot-ci:[0-9.]+" .github/workflows | sort -u)
[ "$(echo "$tags" | wc -l)" -eq 1 ] || { echo "::error::Mismatched godot-ci tags: $tags"; exit 1; }
minor=$(echo "$tags" | sed -E 's/.*:([0-9]+\.[0-9]+).*/\1/')
grep -q "config/features=PackedStringArray(\"$minor\"" project.godot \
  || { echo "::error::project.godot features do not match Godot $minor"; exit 1; }
```

### 7.4 `.github/workflows/ci.yml`
```yaml
name: CI

on:
  pull_request:
  push:
    branches: [main]
  workflow_dispatch:

concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: ${{ github.event_name == 'pull_request' }}

permissions:
  contents: read

jobs:
  lint:
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@v7
      - uses: actions/setup-python@v7
        with:
          python-version: "3.13"
      - run: pip install "gdtoolkit==4.5.0"
      - run: tools/ci/lint.sh

  test:
    runs-on: ubuntu-24.04
    container: barichello/godot-ci:4.7.2   # keep in sync: tools/ci/check_versions.sh
    timeout-minutes: 20
    steps:
      - uses: actions/checkout@v7
      - uses: ./.github/actions/godot-env
      - name: Unit, simulation and integration tests (GUT)
        run: tools/ci/run_tests.sh
      - name: Smoke run (main scene, autopilot, 60 s simulated)
        run: tools/ci/smoke.sh
      - name: Upload test reports
        if: always()
        uses: actions/upload-artifact@v7
        with:
          name: test-reports
          path: build/reports
          retention-days: 14

  export-web:
    needs: [lint, test]
    runs-on: ubuntu-24.04
    container: barichello/godot-ci:4.7.2
    timeout-minutes: 20
    steps:
      - uses: actions/checkout@v7
      - uses: ./.github/actions/godot-env
      - run: tools/ci/export.sh "Web" build/web/index.html release
      - name: Upload Web build
        uses: actions/upload-artifact@v7
        with:
          name: web
          path: build/web
          if-no-files-found: error
          retention-days: 14
      - name: Upload Pages artifact
        if: github.event_name == 'push' && github.ref == 'refs/heads/main'
        uses: actions/upload-pages-artifact@v5
        with:
          path: build/web

  export-android:
    needs: [lint, test]
    runs-on: ubuntu-24.04
    container: barichello/godot-ci:4.7.2
    timeout-minutes: 40
    strategy:
      fail-fast: false
      matrix:
        include:
          - preset: Android APK
            file: roadgame-debug.apk
          - preset: Android AAB
            file: roadgame-debug.aab
    name: export-android (${{ matrix.preset }})
    steps:
      - uses: actions/checkout@v7
      - uses: ./.github/actions/godot-env
        with:
          android: ${{ matrix.preset == 'Android AAB' }}
      - name: Cache Gradle
        if: matrix.preset == 'Android AAB'
        uses: actions/cache@v6
        with:
          path: |
            ~/.gradle/caches
            ~/.gradle/wrapper
          key: gradle-godot-${{ env.GODOT_TEMPLATE_VERSION }}
      - name: Export (debug keystore from CI image)
        run: tools/ci/export.sh "${{ matrix.preset }}" "build/android/${{ matrix.file }}" debug
      - uses: actions/upload-artifact@v7
        with:
          name: android-${{ matrix.preset }}
          path: build/android/${{ matrix.file }}
          if-no-files-found: error
          retention-days: 14

  deploy-web:
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    needs: [export-web, export-android]
    runs-on: ubuntu-24.04
    permissions:
      pages: write
      id-token: write
    environment:
      name: github-pages
      url: ${{ steps.deploy.outputs.page_url }}
    steps:
      - id: deploy
        uses: actions/deploy-pages@v5
```

### 7.5 `.github/workflows/release.yml`
```yaml
name: Release

on:
  push:
    tags: ["v*.*.*"]
  workflow_dispatch:
    inputs:
      version:
        description: "Version to build (e.g. 0.1.0); creates a draft release"
        required: true

concurrency:
  group: release-${{ github.ref }}
  cancel-in-progress: false

permissions:
  contents: read

env:
  VERSION: ${{ inputs.version || github.ref_name }}

jobs:
  test:
    runs-on: ubuntu-24.04
    container: barichello/godot-ci:4.7.2
    steps:
      - uses: actions/checkout@v7
      - uses: ./.github/actions/godot-env
      - run: tools/ci/run_tests.sh
      - run: tools/ci/smoke.sh

  android-release:
    needs: test
    runs-on: ubuntu-24.04
    container: barichello/godot-ci:4.7.2
    timeout-minutes: 45
    environment: release            # protect secrets with required reviewers if desired
    steps:
      - uses: actions/checkout@v7
      - name: Check signing secrets
        env:
          KS: ${{ secrets.ANDROID_KEYSTORE_BASE64 }}
        run: '[ -n "$KS" ] || { echo "::error::ANDROID_KEYSTORE_BASE64 is not set"; exit 1; }'
      - run: tools/ci/stamp_version.sh "$VERSION"
      - uses: ./.github/actions/godot-env
        with:
          android: "true"
      - uses: actions/cache@v6
        with:
          path: |
            ~/.gradle/caches
            ~/.gradle/wrapper
          key: gradle-godot-${{ env.GODOT_TEMPLATE_VERSION }}
      - name: Decode release keystore
        env:
          KS: ${{ secrets.ANDROID_KEYSTORE_BASE64 }}
        run: echo "$KS" | base64 -d > "$RUNNER_TEMP/release.keystore"
      - name: Export signed APK and AAB
        env:
          GODOT_ANDROID_KEYSTORE_RELEASE_PATH: ${{ runner.temp }}/release.keystore
          GODOT_ANDROID_KEYSTORE_RELEASE_USER: ${{ secrets.ANDROID_KEYSTORE_ALIAS }}
          GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD: ${{ secrets.ANDROID_KEYSTORE_PASSWORD }}
        run: |
          tools/ci/export.sh "Android APK" "build/release/roadgame-$VERSION.apk" release
          tools/ci/export.sh "Android AAB" "build/release/roadgame-$VERSION.aab" release
      - name: Remove keystore
        if: always()
        run: rm -f "$RUNNER_TEMP/release.keystore"
      - uses: actions/upload-artifact@v7
        with:
          name: android-release
          path: |
            build/release/*.apk
            build/release/*.aab
          if-no-files-found: error

  web-release:
    needs: test
    runs-on: ubuntu-24.04
    container: barichello/godot-ci:4.7.2
    steps:
      - uses: actions/checkout@v7
      - run: tools/ci/stamp_version.sh "$VERSION"
      - uses: ./.github/actions/godot-env
      - run: tools/ci/export.sh "Web" build/web/index.html release
      - run: cd build/web && zip -qr "../roadgame-$VERSION-web.zip" . -x '*.log'
      - uses: actions/upload-artifact@v7
        with:
          name: web-release
          path: build/roadgame-*-web.zip
          if-no-files-found: error

  publish:
    needs: [android-release, web-release]
    runs-on: ubuntu-24.04
    permissions:
      contents: write
    steps:
      - uses: actions/download-artifact@v8
        with:
          path: dist
          merge-multiple: true
      - name: Create GitHub Release
        env:
          GH_TOKEN: ${{ github.token }}
        run: |
          draft=""; [ "${{ github.event_name }}" = "workflow_dispatch" ] && draft="--draft"
          gh release create "$VERSION" dist/* --repo "${{ github.repository }}" --target "$GITHUB_SHA" \
            --title "Road Roguelike $VERSION" --generate-notes $draft
```

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
            godot --path . --rendering-driver opengl3 --fixed-fps 60 -s tools/screenshots.gd -- \
            --seeds=1,2,3 --turns=0,34,100,200,220 --orientations=portrait,landscape --out=build/screenshots
      - uses: actions/upload-artifact@v7
        with:
          name: screenshots
          path: build/screenshots
          retention-days: 1   # Actions storage policy (§7.1)
```

### 7.8 `.github/dependabot.yml`
```yaml
version: 2
updates:
  - package-ecosystem: github-actions
    directory: "/"
    schedule:
      interval: weekly
```
(The `godot-ci` container tag is bumped by hand using the procedure in §7.1.)

### 7.9 Local parity
Developers and agents run the same commands as CI:
```bash
tools/ci/lint.sh          # needs: pip install gdtoolkit==4.5.0
tools/ci/import.sh && tools/ci/run_tests.sh && tools/ci/smoke.sh
tools/ci/export.sh "Web" build/web/index.html release
```
Or all of them inside the CI image:
`docker run --rm -v "$PWD":/w -w /w barichello/godot-ci:4.7.2 bash -c "tools/ci/import.sh && tools/ci/run_tests.sh"`.

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
