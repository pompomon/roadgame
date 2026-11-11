# Road Roguelike — Game Design & Architecture Document

Status: Draft v2 (open questions resolved)
Engine: Godot 4.3+ (GDScript)
Targets: Android (primary, reference device Samsung Galaxy Z Fold4), Web (secondary)
Monetisation: None (not a goal)
Input: Touch and keyboard

---

## 1. Vision

An isometric pixel-art endless driving roguelike. The player steers a car along a procedurally generated road through a series of hand-designed areas. At every junction the player must follow a hidden **Left → Right → Left → Right…** pattern. One wrong or missed turn ends the run with a procedural disaster. The goal is to drive as far as possible and discover every area and disaster.

### 1.1 Core pillars
- **One rule, learned through failure.** The L/R pattern is never explained. Players discover it by dying.
- **Familiar journey, fresh road.** The areas always appear in the same order, but each road is different.
- **Spectacular failure.** Every run ends with a varied, area-specific disaster that is worth watching.
- **Pure skill.** No meta-progression changes gameplay.

---

## 2. Game Rules

### 2.1 Run flow
1. The run starts in the **City**, heading north.
2. The car controls its speed automatically (§2.3). The player only steers.
3. The road has straights and **junctions**. At each junction the player must take the next turn in the global pattern `L, R, L, R, …`. The first turn is always **Left**. A **decoy** junction doesn't offer that turn, only straight on and the other turn: there straight on is correct, and the turn waits for a later junction.
4. Taking the wrong exit, or continuing straight through a junction that offers the turn (a "missed turn"), triggers a **disaster** and ends the run.
5. Driving off the road drains **health** and is limited to short excursions (§2.4). At 0 health the car crashes and the run ends.
6. Correct turns increment `turnIndex`; straight on at a decoy doesn't. Fixed areas and set pieces start at predefined turn numbers.
7. The game-over screen shows distance, turns, the area reached and the cause of the run's end.

### 2.2 Controls: free steering with automatic speed
| Action | Touch (portrait or landscape) | Keyboard |
|---|---|---|
| Steer left | Hold the left half of the screen | ← / A |
| Steer right | Hold the right half of the screen | → / D |
| Pause | Pause button (HUD) | Esc / P |

- Steering is analog over time: holding rotates the heading, and releasing lets the car straighten slightly. All inputs map to the same Godot InputMap actions (`steer_left`, `steer_right`, `pause`).

### 2.3 Speed model
- **Straights:** speed rises as the car drives along a straight. The top speed reached also increases with total run distance, up to a global cap.
- **Before every junction:** the car slows down automatically as it approaches, whether the player is about to turn correctly or not. Braking starts a set distance before the junction (set per area, about 1–1.5 tiles). This keeps the car from showing which way is correct and gives the player time to choose.
- **After the junction:** the car accelerates again on the next straight.
- **Off-road:** speed is multiplied by `offroad_speed_mult` (lower than 1).

### 2.4 Off-road and health
- Health starts at 100 and is drained per second while off-road (rate set per area).
- **Corner cutting:** if the car leaves the road near a junction and rejoins it within **2 tiles**, this counts as **damage only**, not as a missed turn. Which exit the player took is decided by the road tile the car rejoins (§4.1).
- **Off-road limit:** the car cannot stay off the road for longer than **2 tiles** of travel. Reaching the limit ends the run:
  - near a junction, it counts as a missed turn and triggers a **disaster**
  - anywhere else, the car **crashes**
- There are **no pickups** in the MVP (no health, fuel or score pickups), and health does not regenerate.

### 2.5 End conditions
| Cause | Trigger | Result |
|---|---|---|
| Disaster | Wrong exit, missed turn, or exceeding the off-road limit near a junction | Area-specific disaster sequence, then game over |
| Crash | Health reaches 0, or exceeding the off-road limit on a straight | Crash animation, then game over |

### 2.6 Meta-progression
None that affects gameplay. Persisted between runs:
- **Atlas:** areas discovered, plus best distance and best turn count overall and for each area.
- **Disaster collection:** each disaster type witnessed, with its area and run stats.
- Settings (volume, orientation lock, haptics).

---

## 3. World and Road Generation

### 3.1 Grid and directions
- Logical road grid: each cell is one **road tile**. Headings are `N, E, S, W` (all 4 directions are rendered).
- Tile types: `STRAIGHT`, `CORNER`, `T_JUNCTION`, `CROSS_JUNCTION`, `DEAD_END`, `SET_PIECE`.

### 3.2 Correct path shape
- The correct path alternates L and R, so it forms a staircase. Starting north, it alternates between two headings (N → W → N → W…). Because it always moves in the same overall direction, it **can never cross itself**.
- Randomness comes from:
  - straight lengths between junctions (`minStraight`..`maxStraight` per area)
  - junction kind (T-junction, crossroads, side road or decoy, so which of the turn, the opposite turn and "straight on" are offered)
  - which wrong branches exist
  - decorations and ground variants

### 3.3 Junctions and dead ends
- Every turn on the correct path is a junction. It offers the correct exit plus at least one wrong exit (the opposite turn and/or straight on). A side road offers the turn and straight on, but not the opposite turn.
- A **decoy** is a junction but no turn: it offers straight on, which is correct, and the opposite turn, a wrong exit. It shares `turnNumber` with the next junction.
- Wrong exits become short **dead-end branches** (2–3 tiles) in any direction. They are rendered as real road so they look like valid choices.
- Before placing a dead end, the generator checks an **occupancy grid**. On a collision it shortens the dead end to 1 tile or removes that wrong exit (for example, a crossroads becomes a T-junction). Every junction must keep at least one wrong exit.
- Each junction stores `expectedExit` (a heading) and `turnNumber`.

### 3.4 Buffer management
- The buffer counts **correct-path tiles** only. Dead ends belong to their junction and are added or removed with it.
- At run start: generate **50** tiles ahead.
- When the car passes the **midpoint** of the buffer (25 tiles of lookahead remain), generate enough to get back to 50 ahead.
- Tiles more than **5** behind the car are freed (cells erased, props returned to the pool).
- Invariant: lookahead is always **≥ 25 and ≤ 50** tiles. The visible field of view is about 5 tiles.

### 3.5 Determinism
- All generation uses a seeded `RandomNumberGenerator`. The same seed gives the same road, junctions, dead ends, decorations and disaster variations.
- Separate sub-streams (`road`, `props`, `disaster`) so that changing decorations never changes road layout.

### 3.6 Area schedule
Fixed areas are keyed by **correct-turn count**. The areas between schedule entries are filled procedurally using the active area's rules.

| Turn | Set piece | Area entered | Notes |
|---|---|---|---|
| 0 | — | City | City blocks, small houses |
| 34 | Tunnel | Rural | Yellow-brown palette, tumbleweed, small bushes |
| 100 | Bridge over a river | Meadows | Green meadows and pastures |
| 200 | — | Village | Family houses |
| 220 | — | Desert | **Final area, which continues forever** |

- When `turnIndex` reaches a schedule entry, the next straight is replaced by the set piece (a fixed run of straight tiles with no junction), then the area switches.
- Once the last scheduled area starts, the generator stays in it for the rest of the run.

### 3.7 AreaDef (Godot `Resource`, `.tres`)
```
AreaDef
  id: StringName
  display_name: String
  palette: Texture2D / color list
  road_tileset: TileSet
  ground_variants: Array[Vector2i] (atlas coords)
  props: Array[PropDef]           # scene, weight, density, min distance from road
  min_straight, max_straight: int
  cross_junction_chance: float     # chance a junction also offers "straight on"
  side_road_chance: float          # chance a junction offers the turn and "straight on" only
  decoy_chance: float              # chance a junction offers "straight on" (correct) and the opposite turn
  straight_accel: float            # speed gain per tile on straights
  junction_brake_distance: float   # tiles before a junction where auto-braking starts
  junction_speed: float            # target speed while passing through a junction
  offroad_speed_mult: float
  offroad_damage_per_sec: float
  offroad_limit_tiles: float       # 2.0 for the MVP
  disasters: Array[PackedScene]    # pool used on wrong or missed turns
  ambient_loop, music: AudioStream
  transition_tiles: TileSet        # blending into this area
```

`AreaSchedule` resource: an ordered list of `{ turn, area: AreaDef, set_piece: PackedScene? }`.

---

## 4. Disaster System

### 4.1 Trigger
- Each junction tile has an **exit-decision zone** on each edge. The first exit zone the car enters records the player's choice.
- If the car leaves the road near a junction (cutting the corner), the choice is decided when it **rejoins the road within 2 tiles**. The branch it rejoins (the correct exit, a dead end, or the straight-on road) is the choice. Off-road damage still applies.
- `JunctionTrigger` compares that choice with `expectedExit`:
  - Match: at a turn, `turnIndex += 1`; straight on at a decoy leaves it as it was (§2.1). Either way, `EventBus.turn_completed` is emitted.
  - Mismatch (wrong turn, or straight on when a turn was expected): `EventBus.disaster_triggered(area, junction)` is emitted.
  - Off-road limit reached before rejoining any branch: treated as a missed turn, so `disaster_triggered` is emitted.

### 4.2 DisasterDirector
1. Disables player input, then eases the car to a stop or moves it into the dead end.
2. Picks a disaster scene from the current area's pool using the `disaster` RNG stream.
3. Sets random parameters (direction, intensity, timing, particle counts) from the seed so no two disasters look the same.
4. Plays the sequence (2–4 s), records it in the disaster collection and shows the game-over screen.

### 4.3 MVP disaster pool
| Area | Disasters |
|---|---|
| City | Sinkhole |
| Rural | Tornado |
| Meadows | Flood |
| Village | Flood / Tornado |
| Desert | Quicksand |

Each disaster is a self-contained scene (animation, GPU particles, shaders, sound effects) that follows a common interface: `play(params) -> signal finished`.

---

## 5. Rendering and Art

### 5.1 Resolution and orientation
- **Portrait is the default**: base resolution 360×640. Landscape: 640×360.
- Orientation follows the device sensor and is handled at runtime.
- **Foldables:** the reference Galaxy Z Fold4 has a tall, narrow cover screen (904×2316, about 23:9) and an almost square inner screen (2176×1812). Folding or unfolding during a run must re-layout the screen without restarting or resetting the run (handled with the same `size_changed` path). Godot's `expand` aspect setting fills the extra width or height with more of the world.
- Godot stretch settings: mode `canvas_items`, aspect `expand`, integer scaling, nearest-neighbour filtering.
- The camera zooms for each orientation to keep about 5 road tiles visible along the direction of travel. It looks ahead so the car sits in the lower third of the screen in portrait.
- HUD anchors and touch zones re-layout on `size_changed`.

### 5.2 Isometric grid
- Road tile: **128×64** diamond.
- Ground tile: **32×16** (4×4 ground tiles per road tile) for decoration placement around the road.
- `TileMapLayer` in isometric mode. Props and the car sit in a Y-sorted `Node2D` with the pivot at the sprite's base.

### 5.3 Asset list per area
| Asset | Count | Notes |
|---|---|---|
| Road tiles | Straights (2 axes), corners (4), T-junctions (4), crossroads (1), dead-end caps (4) | Rounded corners for free steering |
| Ground | 3–4 variants | Placed randomly to avoid visible repetition |
| Props | 6–10 | Some animated (tumbleweed, water, smoke) |
| Transition | 1–2 tiles | Blends ground into the next area |
| Set pieces | Tunnel, Bridge+River | Separate scenes |

Shared assets:
- Car: 16 directions at about 32×24 px, plus a crash frame.
- Effects: dust, smoke, skid marks.
- UI: HUD, health bar, pixel font, pause and menus.
- One master palette of 16–32 colours, with a sub-palette for each area.

### 5.4 Art pipeline
- Drawn in Aseprite and exported as PNG sprite sheets into `assets/<area>/`.
- Import settings: no filtering, no mipmaps, lossless compression.

---

## 6. Audio

| Category | Content | Format |
|---|---|---|
| Engine | Loop, pitch follows speed | OGG |
| Effects | Tyre screech, off-road rumble, damage, crash, junction success | WAV |
| Disaster | One sound set per disaster | WAV/OGG |
| Ambient | One loop per area (traffic, wind, birds/river, village, desert) | OGG |
| Music | One track per area | OGG |

- Volume channels: `Master → Music, SFX, Ambient`. The tunnel adds a reverb effect on SFX.
- `AudioDirector` (autoload) cross-fades ambient and music on `area_changed`.

---

## 7. Architecture

### 7.1 Scene tree
```
Main
├── World
│   ├── GroundLayer (TileMapLayer, isometric)
│   ├── RoadLayer   (TileMapLayer, isometric)
│   └── Props (Node2D, y_sort_enabled)
│       ├── Car
│       ├── SetPiece instances
│       └── Pooled prop sprites
├── DisasterLayer (Node2D)
├── Camera2D (follows car, look-ahead)
└── UI (CanvasLayer)
    ├── HUD (distance, turns, health, pause)
    ├── TouchZones
    └── Overlays (pause, game over)
```

### 7.2 Modules
| Module | Type | Responsibility |
|---|---|---|
| `RoadGenerator` | `RefCounted` (no nodes) | Seeded generation of `RoadTile` data, junctions, dead ends, occupancy, buffer |
| `RoadTile` | `RefCounted` | Cell, type, heading, exits, `expectedExit`, area, `turnNumber` |
| `WorldRenderer` | `Node` | Turns `RoadTile`s into tilemap cells and props; erases freed tiles |
| `PropPool` | `Node` | Reuses prop sprites instead of creating and destroying them |
| `CarController` | `CharacterBody2D`-like custom movement | Steering, speed model (straight acceleration, junction auto-braking), off-road detection (from tile lookup), off-road limit, health |
| `InputRouter` | `Node` | Turns keyboard, touch and scripted input into a steering intent from -1 to 1 |
| `JunctionTrigger` | `Node` | Exit-zone detection and checking against the L/R pattern |
| `DisasterDirector` | `Node` | Selects, sets parameters for and plays disasters |
| `AreaRegistry` | Resources | Loads `AreaDef` and `AreaSchedule` |
| `GameState` | Autoload | Run state, seed, `turnIndex`, distance, state machine |
| `EventBus` | Autoload | Signals (below) |
| `SaveService` | Autoload | Atlas, collection, settings in `user://save.json` |
| `AudioDirector` | Autoload | Volume channels, cross-fades, engine pitch |

### 7.3 Game state machine
`TITLE → RUNNING ⇄ PAUSED → (DISASTER | CRASH) → GAME_OVER → RUNNING (retry) / TITLE`

### 7.4 Signals (EventBus)
- `run_started(seed)`
- `turn_completed(turn_index)`
- `area_changed(area_def)`
- `tiles_generated(tiles)`, `tiles_freed(tiles)`
- `health_changed(value)`
- `disaster_triggered(area_def, junction)`
- `run_ended(cause, stats)`

### 7.5 Car state machine
`DRIVING ⇄ BRAKING_FOR_JUNCTION`, `DRIVING/BRAKING → OFFROAD ⇄ DRIVING` (rejoin within 2 tiles), `OFFROAD → DISASTER` (limit reached near a junction) `| CRASHED` (limit reached on a straight, or health reaches 0), `DRIVING/BRAKING → DISASTER` (wrong exit)

### 7.6 Data flow
```
RoadGenerator ──tiles──▶ WorldRenderer ──cells/props──▶ TileMapLayers / Props
      ▲                                         
      │ request more (car passes buffer midpoint)
CarController ──position──▶ tile lookup ──▶ off-road? / JunctionTrigger
JunctionTrigger ──▶ EventBus ──▶ GameState / DisasterDirector / AudioDirector / HUD
```

---

## 8. Project Structure

```
project.godot
autoload/      game_state.gd, event_bus.gd, save_service.gd, audio_director.gd
road/          road_generator.gd, road_tile.gd, junction_trigger.gd
world/         world.tscn, world_renderer.gd, prop_pool.gd
car/           car.tscn, car_controller.gd, input_router.gd
disasters/     disaster_director.gd, sinkhole.tscn, tornado.tscn, flood.tscn, quicksand.tscn
areas/         city.tres, rural.tres, meadows.tres, village.tres, desert.tres, schedule.tres
setpieces/     tunnel.tscn, bridge.tscn
ui/            title.tscn, hud.tscn, game_over.tscn, atlas.tscn
assets/<area>/ sprites, sounds
tests/         GUT tests
```

---

## 9. Persistence

`user://save.json`:
```json
{
  "version": 1,
  "atlas": { "city": { "discovered": true, "best_distance": 0 } },
  "best": { "distance": 0, "turns": 0 },
  "disasters": { "sinkhole": { "seen": 3, "first_area": "city" } },
  "settings": { "music": 0.8, "sfx": 1.0, "ambient": 0.8, "haptics": true, "orientation": "sensor" }
}
```
The file has a version number so it can be migrated when the format changes. It is written on `run_ended` and when settings change.

---

## 10. Platforms and Builds

| Platform | Notes |
|---|---|
| Android | Godot Android export template, sensor orientation (portrait default), resizable activity for fold and unfold, haptics on damage and disaster. Reference device: **Samsung Galaxy Z Fold4** (modern Android phones in general) |
| Web | **Single-threaded** export (no special cross-origin headers needed), audio starts after the first user input |

**Performance:** not a blocker for the MVP. The informal target is a smooth 60 fps on the Galaxy Z Fold4. Profiling and optimisation happen after the MVP.

**Monetisation:** none. No ads, in-app purchases or store-driven features are planned.

CI: GitHub Actions with headless Godot. It runs the tests and builds the Android APK/AAB and Web export on every pull request.

---

## 11. Testing Strategy

All tests run headless (`godot --headless`) with GUT, so they work in CI and for agents.

**Unit (RoadGenerator)**
- The same seed gives an identical tile sequence.
- The correct path follows `L, R, L, R…` starting with Left.
- The correct path and dead ends never overlap (occupancy check).
- Every junction has ≥ 1 wrong exit.
- Lookahead stays within 25..50 tiles after any number of refills.
- Area switches and set pieces happen at turns 34, 100, 200 and 220. Desert continues forever afterwards.

**Simulation**
- A scripted driver follows `expectedExit` for 300+ turns with no disaster.
- A deliberate wrong turn triggers a disaster from the current area's pool.
- The car slows down before every junction, for both correct and wrong turns, and speeds up again on straights.
- Cutting a corner and rejoining the correct exit within 2 tiles counts as taking it and applies damage only.
- Exceeding 2 tiles off-road triggers a disaster near a junction and a crash on a straight.

**Device**
- Fold and unfold the Galaxy Z Fold4 during a run: the layout updates and the run continues.

**Visual**
- Headless screenshots for fixed seeds in portrait and landscape at key turn numbers.

---

## 12. MVP Milestones

1. **Generator.** `RoadGenerator` and unit tests, with grey-box tiles.
2. **Driving.** Car steering, camera, health and off-road, junction trigger.
3. **Failure.** `DisasterDirector` with one disaster, game over and retry.
4. **Areas.** All 5 areas, tunnel and bridge set pieces, schedule.
5. **Content.** Final art and audio, Atlas, disaster collection, saving.
6. **Ship.** Android and Web builds, orientation handling, polish.

---

## 13. Decision Log

| Topic | Decision |
|---|---|
| Engine | Godot 4.3+, GDScript (switched from Phaser on request) |
| Controls | Free steering, automatic speed (Model B) |
| Core rule | Hidden alternating L/R pattern, always starting Left; a wrong or missed turn triggers a disaster |
| Road directions | All 4 headings rendered; the correct path is a staircase, so it never crosses itself |
| Buffer | 50 tiles at start, refill at midpoint, keep 25–50 lookahead |
| Areas | Fixed schedule by turn count; the last area continues forever |
| Orientation | Portrait default, runtime orientation change supported |
| Meta-progression | None; Atlas and disaster collection only |
| Pickups | None in the MVP |
| Speed | Rises on straights and with distance; automatic braking before every junction |
| Off-road | Corner cutting within 2 tiles is damage only; the car cannot stay off-road longer than 2 tiles |
| Target device | Modern Android phones; Samsung Galaxy Z Fold4 is the reference device |
| Performance | Not a blocker for the MVP |
| Monetisation | Not a goal |
| Future areas | Planned in a separate document |

---

## 14. Out of Scope / Follow-up Documents

- **Future areas** (after Desert) will be planned in a separate document (`AREAS.md`). The MVP ends with Desert continuing forever.
- Detailed tuning values (speeds, braking distances, damage rates) will be set during prototyping.