# Visuals: Wheels That Turn and a Denser City

Done, 2026-11-14 to 2026-11-16: the plan PR #85, then two stacked PRs, #93 (PR 1) and #94 (PR 2). The car's wheels turn as it drives, and buildings line the City's streets, fading where they would hide the car. The full plan, with its verification, negative cases and review history: `git show 14f5747:VISUALS_PLAN.md`; the tag `archive/vis/prototype` keeps the prototype's commits that it cites.

## 1. Goal and exit criteria

Nothing else changes, nor what a seed plays. The exit criteria, E1–E13: the wheels roll forward with the car (E1–E3); lots, the City's buildings along its streets, none in another, and the other areas' props as before (E4–E7, E12); the fade (E13); the docs and the checks (E10, E11). All are met but E9 on the Fold4, with E8's frame rate (§7).

- **E8.** The cost, on the desktop: a frame of the City at most 1.7 ms more CPU than `main`'s by day and 5.3 ms at night (P15), a row 1.8 ms (P17), the fade 46 µs (P14). The Fold4's frame rate is read, against `docs/PERF.md` E1 since PF.
- **E9.** By hand, in the City by day and at night, on the Web in Chrome and Firefox (P18) and on both of the Fold4's screens: the wheels turn forward at every speed and stop with the car; no building stands in another or on the road; one over the car fades, and comes back as the car leaves it; nothing flickers; no error.

## 2. Findings

- **A1.** The wheels couldn't turn: an ink box an axle, in a sheet of one row. **Δ docs/M5.md §5.7:** a row for each of 4 phases (§5.1).
- **A2.** The City was sparse: 3.07 buildings a view (P13). Now 0.35 of its lots, 0.6 by a street (§5.3).
- **A3.** Buildings stood in each other: 8.3% of them on `main`, 92% at 0.3 a cell (P12). **Δ docs/M5.md §5.6:** lots of 2 × 2 (§5.4).
- **A4.** The sheet's users read only its first row. Now the body's row and column (§5.2).
- **A5.** Densities were per cell. **Δ docs/M5.md §5.6:** per lot of the prop's size, adding up to 1 at most for each size apart (§5.4).
- **A6.** Lots must move nothing else. A lot of one cell has its cell's own hash, in `main`'s loop (P2, §5.4).
- **A7.** The City's props took GUT from 91 s to 118 s. The pool's sprites are internal children, which `simulate()` skips (docs/DAYNIGHT.md C20): 86 s (§5.5).
- **A8.** On an internal child `get_index()` is an error that returns −1, and `get_children()` and `get_child_count()` leave it out. `Lamps` reads the props with `get_index(true)` and orders its canvas items by keys (§5.5; docs/PERF.md §5.2).
- **A9.** Whether the car drew over a prop on its y depended on when the prop was made. With `INTERNAL_MODE_FRONT` it always does (§5.5).
- **A10.** `Lamps`' insert of each silhouette cost more with more props. PF replaced node moves with draw-index keys (docs/PERF.md Y9, §5.2).
- **A11.** A row of the City shows in 1.45 ms, against 0.90 (P17). Left as it is (§5.6).
- **A12.** The City's street props are 35–42% fewer, and move, as buildings take their cells and their shares of each hash (P16). Kept (Q4).
- **A13.** Four phases alias: a true wheel turns 5.8 times a tile, which reads as backwards. Once a tile, and a phase a drawn frame at most (§5.1).
- **A14.** The docs had one row of the car and props of one cell: PR 1 changed `plan.md` §5.3, PR 3 docs/M5.md §5.6 and §5.7.
- **A15.** #88's tyre tracks fit `main`'s back wheels. #88 takes the fix after its merge of `main`: `GAUGE` 7, the sand's `emission_rect_extents` `Vector2(7, 1)`, and `tracks.png` drawn again by `make_legends.gd`.
- **A16.** No building could stand by a street, as `touches_road()` left out each prop whose frame touched a road tile. See-through props may rise over the road (§5.9).
- **A17.** Buildings by a street would hide the car, in 68% of the views (P13). They fade (§5.9).
- **A18.** The fade must see the car, however a disaster moves it, its double and a legend's parts, but nothing hidden: `actor_rect()` (§5.9).
- **A19.** A building's lights would stay over it. Its silhouette and glows fade with it (§5.9).
- **A20.** The pool would show a faded sprite again. `PropPool.acquire()` sets `modulate` to white.
- **A21.** 80.7 buildings a view, against 3.07, lit at night, cost more (P13, P15). Left as it is: E8 reads the Fold4's frame rate (§5.6).

## 3. Decisions

The owner answered Q2; the rest are defaults.

- **Q1.** The wheels roll with the car's speed; they don't steer (§9).
- **Q2.** "keep density between 35% and 60%, and move buildings closer to the streets. If the building overlaps the camera view of the car, then make them more transparent similar to the tunnel view." 0.35 of the City's lots, 0.6 of those by a street (§5.8); see-through buildings rise over the road behind them, and fade to 0.2 over the car (§5.9).
- **Q3.** No new art: the City's one building (§9).
- **Q4.** The City's street props keep their densities, so they thin (A12).
- **Q5.** The City's building only (P12, §9).
- **Q6.** Landing: a stack of two, the wheels then the City, then the docs from `main`.

## 4. Work breakdown

- **PR 1** (#93): `make_car.gd`'s wheels and rows, `CarController`'s roll, `WHEEL_ROLL_TILES`, the sheet's users, and `plan.md` §5.3's line on the car.
- **PR 2** (#94): `PropDef.lot`, `street_density` and `see_through`; `PropLayout`'s lots and streets; `SeeThrough` and the fade; internal props; `body_rect()`; `PROP_SEE_THROUGH` and `PROP_FADE_PX`.
- **PR 3**: this summary.

### 4.5 Landing

PR 2's merge of `main` after PR 1's squash conflicted in `car_controller.gd`; `-X ours` kept the branch's tree. #95, merged between them, left PR 2 and PR 3 to the owner.

## 5. Design

### 5.1 The wheels

`car.png` has a row for each of `CarController.PHASES`, 4, phases of the wheels' turn: 612 × 112 px, each row with the first's outline. `make_car.gd` splats each wheel as a cylinder 2.5 px in radius, with a hub and a marked quarter, a quarter turn on each row, its top forward. The wreck is in phase 0 in every row.

`_physics_process()` adds `sim.speed * delta` to `_driven`. Once a drawn frame, `_process()` adds that to `_rolled`, at most `WHEEL_ROLL_TILES`, 0.25 tile, dropping the rest, and on each whole `WHEEL_ROLL_TILES` shows the next row.
- **Once a tile (A13).** A true wheel at the cap, 7 tiles a second, would turn 2.7 phases a physics frame, which reads as backwards. Once a tile, it's 0.27 of a phase at `BASE_TOP_SPEED`, 4, and 0.47 at the cap.
- **A phase a drawn frame at most (A13).** Below 30 fps two phases could show at once, a half turn, which reads as back. So the wheels turn only forward, faster as the car speeds up, and never while it stands.
- **Visual only.** Nothing else reads the phase, and no RNG is drawn.

### 5.2 The sheet's users

The body shows `frame_coords`: the heading's column in the phase's row, the wreck's in row 0. `double()` cuts at `frame_coords * FRAME_SIZE`; `body_frame()`, which `Shadows` casts, returns `frame_coords.x`, as every row has the first's outline.

### 5.3 The City's density

The City's building takes a lot of 2 × 2 cells, at 0.35 and at 0.6 by a street (§5.8), and is see-through (§5.9): `make_props.gd`'s `PROPS`, `LOTS`, `STREETS` and `SEE_THROUGH` write them to `building.tres`. Its other props keep their densities (Q4). Over 400 views (P13):

| The building | Buildings a view | Nodes |
|---|---|---|
| `main`: a cell at 0.01 | 3.07, at most 9 | 3,827 |
| A lot at 0.3 | 18.27 | 13,382 |
| 0.35, neither by streets nor see-through | 21.59 | 15,204 |
| **Q2: 0.35, 0.6 by a street, see-through** | **80.66, 63 to 100** | **19,245** |

Both of Q2's parts are needed. Left out by `touches_road()`, two roads of 100 rows show 3,256 buildings with the street density or without; see-through, 4,427 without it and 4,951 with it, where `main` shows 402 (A16).

### 5.4 Lots

A prop takes a lot of `PropDef.lot` × `lot` ground cells, 1 by default, aligned with its tile.
- **The contract.** `validate()` rejects a lot that doesn't divide a tile's 4 cells. Each size's densities add up to 1 at most, apart, and so do its street densities: `_valid_props()` adds them in floats, and `past_1()` takes a sum past 1 by rounding alone as 1.
- **Largest first.** `by_lot()` sorts the props by lot. Each free lot of each size above 1 picks a prop of its size, or none. One that shows takes its cells, in the tile's 16-bit `taken`, and stands on its lot's front cell, nearest the bottom of the screen, its box reaching back over the rest; one left out at the road takes none.
- **The hash.** A lot of one cell has its cell's own hash, `cell_hash(props_seed, cell)`; a larger lot mixes in `LOT_SALT` × `lot`, else a cell whose lot showed nothing would pick past the lot's densities.
- **Cells of one, as on `main` (A6).** Each free cell picks a prop of one cell in `main`'s loop, `b` outer and `a` inner, so an area without lots or street densities places the same props, in the same places and order.

**Why no two buildings touch (A3).** Cells (p, q) apart stand (16(p − q), 8(p + q)) px apart, so two 40 × 20 px bases overlap when 0.8 · max(|p|, |q|) < 1. Lots of 2 × 2 keep two buildings' front cells an even number of cells apart each way, at least 2.

### 5.5 Internal props

`PropScatter`'s pool holds its sprites as internal children of `Props`, `PropPool.new(layer, Node.INTERNAL_MODE_FRONT)`, as `Shadows` holds its own, so `simulate()` skips them (A7), and 1,200 frames of the City in Movie Maker stay the same bytes. `Lamps` reads the props' `get_index(true)` (A8) and orders its RenderingServer items by keys (docs/PERF.md §5.2). `_fade()` takes `get_children()`: the layer's own children, the actors, and no prop. Godot's y-sort draws a tie in the order of the children, internal ones included, so every prop draws before the car, its double and a legend's parts (A9).

### 5.6 The cost

The City has 5 times `main`'s nodes; the other areas cost what they did (A6). On the desktop, two cloud CPUs with software GL:

| What | `main` | VIS | Probe |
|---|---|---|---|
| A row of the City's props shown: mean, p95, max | 0.90, 0.92, 20.0 ms | 1.45, 1.64, 1.73 ms | P17 |
| A frame of the City by day: Movie Maker's CPU time | 4.90–5.11 ms | 6.52–6.58 ms | P15 |
| The same at 22:00 | 9.50–9.55 ms | 14.38–14.79 ms | P15 |

At the speed cap a row shows and another hides about every 8.6 frames at 60 fps, within 2.1 ms together. These compare builds on one machine, and say little of a phone's (E8). The City shows at night only with `--hour`, as a run's first night comes in Rural (docs/DAYNIGHT.md §5.8).

### 5.8 Streets

A lot by a street shows its prop at `PropDef.street_density`, the others at `density`; −1, the default, is `density`'s (`chance()`).
- **By a street.** `street_sides()` gives the sides of a tile that a road tile is across, and `lot_sides()` those that a lot lies along: sharing one, the lot is by a street. A road tile across only a corner doesn't count.
- **Only where asked.** `row()` looks for streets only if a prop has a street density, so the other areas pick and cost as before (A6).
- **The contract.** `validate()` rejects a street density outside 0..1 but −1 (§5.4).

### 5.9 See-through props and the fade

**Rising over the road (A16).** `_place()` skips `touches_road()` for a prop with `PropDef.see_through`. `validate()` wants it an upright box whose base, reaching `2 × shadow_rise` back from its foot, lies in its lot: `4 × shadow_rise` at most `2 × lot − 1` cells' heights. The building's is 40 px against 48. Set pieces still keep it clear.

**The fade (A17).** As the tunnel does (docs/M4.md K5), a see-through prop shows `PROP_SEE_THROUGH`, 0.2, of itself where it would hide the car's body or a legend's sprite on `Props`. `SeeThrough.opacity()` adds the gaps across and down between their rects, and how far the actor sorts in front of the prop's foot (A9); over `PROP_FADE_PX`, 48 px, `smoothstep()` brings it back, so nothing pops.
- **The actors (A18).** `_fade()` takes the layer's own children (§5.5). `actor_rect()` gives the car's `body_rect()` or a sprite's rect, through its transform, and nothing for what doesn't show: not `visible`, alpha 0, or a scale under `HIDDEN_SCALE`, 1e-4, as Node2D keeps a zero scale at `CMP_EPSILON`.
- **Which props.** `Row.fading` keeps a row's see-through props and frames, and `SeeThrough.rows()` names the rows in reach. A prop takes the least opacity that its actors ask.
- **Its lights (A19).** `_show_alpha()` sets the prop's alpha and, through `Lamps.fade()`, its silhouette item's `modulate`, which its child glows inherit (docs/PERF.md §5.2). Nothing is redrawn by the fade (docs/M2.md §5.7).
- **Visual only.** Nothing else reads the fade, and no RNG is drawn.

## 6. Verification

The five checks passed on each PR; at PR 2, 162 scripts, 602 tests and 429,384 asserts, with `main`'s smoke line. The negative cases, N1–N67, are in the full plan's §6.2.

- **P2.** 150 rows on seeds 1–4: the other four areas place the same 27,590 props with lots, in the same places and order.
- **P12.** Wide props in another's base: the City's buildings on lots, none; the Village's houses 9.6%, Rural's barns and windmills 7.4%, the Meadows' ponds 1.5%; the building on a cell 8.3%, at 0.3 a cell 92.4%.
- **P13.** 400 views of 360 × 640 px, seeds 1–5, with the autopilot: §5.3. With Q2, 5.46 faded props a view, and a building over the car in 272.
- **P14.** `_fade()`: 35 µs a frame on average, 46 at most.
- **P15.** 900 frames of the City in Movie Maker, by day and at 22:00: §5.6.
- **P16.** As P2, in the City: 15,008 buildings, where `main` places 1,133, and 35–42% fewer street props.
- **P17.** A row's show and hide in the main scene, 168 times: §5.6.
- **P18.** The Web, on each PR's build, in Chrome and Firefox, by day and at 22:00: E9's checks hold, with no error from the game. Frames a second on software GL, PR 1's build then PR 2's: Chrome 33.2 then 24.5 by day, 23 then 13 at 22:00; Firefox 58.8 then 58.4, and 58.4 then 50–51. Posted on #93 and #94.

## 7. Owner actions

- **The Fold4** (E9), not recorded as done: a debug APK from `main`, on both screens and through a fold, in the City past the tutorial, and the night through the Web build with `--hour=22` in the Fold4's Chrome (docs/agents/checks.md §4). Read the frame rate (E8), not a blocker; if it drops, see §9.
- **Tune** if needed: `make_props.gd`'s `PROPS` and `STREETS`, then run it (Q2); `PROP_SEE_THROUGH`, `PROP_FADE_PX`, `WHEEL_ROLL_TILES`.

## 9. Notes for later

- **Other areas' wide props on lots** (Q5, P12): the Village's houses, Rural's barns and windmills, the Meadows' ponds, whose areas' props would then move (A12).
- **More buildings** (Q3), and lots of a whole tile, which `PropDef.lot` allows: a park or a square.
- **Steering** (Q1): a frame for each heading, angle and phase.
- **More phases** (A13): smoother, but below 60 fps a drawn frame holds the wheels to a phase more often; about 3.4 KB a row.
- **If the Fold4 drops frames** (§5.6): a lower street density, within Q2's 0.35 to 0.6; a row's props shown over frames (A11); one glow a building, about 80 in view at night, not 640 (A21). PF made the `Lamps` insert cheaper (A10).
