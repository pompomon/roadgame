# Visuals: Wheels That Turn and a Denser City — Detailed Plan

Status: plan, in review. Both code PRs are built on `vis/prototype` and verified locally and in CI (§6) · 2026-11-15 · The owner hasn't answered Q1–Q6 yet, so the plan and the prototype go on with the defaults (§3) · Scope: the car's wheels turn as it drives, and a view of the City shows about six times as many buildings, none standing in another; but for the City's street props, nothing else that shows changes. This plan calls the work VIS. It comes after DN (#64, #70–#76), beside PL (#80, #81), and before M7.

The owner asked: "Explore the codebase and create a detailed implementation plan for visual enhancements. 1. Update the car visual to make the wheels turn while driving. 2. Increase the number of the houses density in the city". The clarifying questions are Q1–Q6 (§3), each with the default that this plan follows until the owner answers.

**What happens.** The car is one row of 17 frames of 36 × 28 px, 16 headings and the wreck (docs/M5.md §5.7). Its wheels are four ink boxes, drawn alike in every frame (`make_car.gd`:35–36), so nothing on the car moves but its heading (W1). This plan draws each wheel as a cylinder with a hub and a marked quarter, and gives the sheet a row for each of four phases, each a quarter turn on as the wheels roll forward. `CarController` counts the tiles that the car drives and shows the next row each `WHEEL_ROLL_TILES`, a quarter of a tile: the wheels turn once a tile, with the car's speed, and stop when it stops. At the speed cap that's 0.47 of a phase each physics frame, and less than one a frame at 30 fps, so they never seem to turn backwards (§5.1). Three users of the sheet read only its first row: the car's double for the disasters, its shadow and `body_frame()` (W4).

The City's "small houses" (`plan.md` §3.6, :117) are its building prop. Each ground cell shows at most one prop, picked by its hash, and the building takes 0.01 of the cells (`make_props.gd`:23–30, docs/M5.md §5.6). A view of the City shows 3.1 on average, and 3% of views none (P1, W2). More density alone won't do: the building's base, 40 × 20 px, is wider than its cell's diamond, 32 × 16, so buildings on neighbouring cells stand in each other. On `main` 8.3% of the City's buildings have such a neighbour, and at 0.3 a cell 92% would (P12, W3). So this plan gives each prop a lot, `PropDef.lot`: the side, in ground cells, of the square that it takes, 1 by default, and 2 for the City's building. Each tile's 4 × 4 ground cells make four lots of 2 × 2, and each picks by its own hash whether a building stands on it, at 0.3 a lot (Q2). A building takes its lot's four cells, and the cells of the lots without one pick their props one by one, as before. No two buildings touch, and a view of the City shows 17.8 on average, 33 at most and never none (P1). The other areas' props are placed exactly as before (W6, P2). The City's street props pick from its props of one cell, which no longer hold the building's share of each hash, so they stand elsewhere than on `main`, and thin by 23–29% as buildings take their cells (W12, Q4).

The City then holds 3.5 times as many nodes (P1). On the desktop, Movie Maker's render times for a frame there grow by about 0.3 ms of the CPU's by day and 1.5 ms at night (P5), and a row of props takes 0.7 ms more to show on average (P3). GUT's `simulate()` walks every node, which took the suite from 91 s to 118 s, so the props' pool holds its sprites as internal children of `Props`, as `Shadows` and `Lamps` hold theirs (docs/DAYNIGHT.md C20): 86 s (W7). They go in front of the layer's own children, so the car, one of those, draws over a prop on its y (W9).

**Verified locally and in CI.** Every file of PRs 1 and 2 was first built on branch `vis/prototype`, from `main` at 2d93074, which merged `main` at 81f22e3 in 44c3e0a. Its first commit, 5f02ebf, adds the wheels and the lots, with four tests; 2fe01e1 lays one-cell props as before and holds the props as internal children; the rest, to 6e75911, add four tests and extend four (§4.6). 6e75911 passed the five checks locally with Godot 4.7.2 and in CI, and so did each PR's files alone on `main` (§6.1), and the warnings check (§6.3); each negative case failed the tests it names (§6.2). Probes measured the City's views and placements, the rows' cost, the frames by day and at night, the Web in Chrome and Firefox, GUT's time and the art (§6.5).

- Godot 4.7.2-stable (4.7.2.stable.official.ed1daf0bf), in CI's image and locally
- GUT 9.7.1
- gdtoolkit 4.5.0 on Python 3.12, in CI's `lint` job and locally. shellcheck isn't installed locally, so `lint.sh` skipped it there; VIS changes no shell script

**Precedence.** For VIS, this document replaces docs/M5.md §5.6 (:100–102), on the props' density, and §5.7 (:104–106), on the car's sheet, and `plan.md` §5.3's line on the car (:211), wherever it marks a difference with **Δ** and its finding (W#, §2). PR 1 changes `plan.md`'s line; PR 3 replaces this plan with `docs/VISUALS.md` (§4.4).

**Reference code.** This plan has no appendices. PRs 1 and 2 each apply their files' part of the difference between 81f22e3, `main`, and 6e75911, the head of `vis/prototype`, which never gets a PR of its own (§4.1).

**Prerequisites.** M0–M6, RG, ZS, TUT and DN are merged, and so is PL's plan (#1–#80); `main` is at 81f22e3. PL's PR 1 (#81) is open: of VIS's 21 files it changes only `config/tuning.gd`, at other lines, and merges with 6e75911 cleanly (P11). M7 hasn't started; §9 has notes for it. No repository settings change.

Contents:
1. Goal and exit criteria
2. Review findings
3. Decisions and open questions
4. Work breakdown (3 PRs)
5. Design
6. Verification
7. Owner actions
8. Risks
9. Notes for later work

---

## 1. Goal and exit criteria

Goal: the car's wheels turn as it drives, with its speed and forward, and the City looks like a city: buildings along its streets in every view, none standing in another. Nothing else changes: the other areas' props, the road, how the car drives, the disasters, the light, the screens, and what a seed plays.

| # | Exit criterion | Checked by |
|---|---|---|
| E1 | The wheels roll (W1, W13; Q1). The body shows the row of its wheels' phase, the next of 4 each `WHEEL_ROLL_TILES`, 0.25 tile, that the car drives: once a tile, faster as the car speeds up, and not at all while it stands. They count tiles driven, not time, and step at most 0.47 of a phase a physics frame, at the speed cap | `test_car_controller.gd`: `test_its_wheels_turn_on_a_phase_each_wheel_roll_tiles_it_moves` |
| E2 | The sheet (W1). `car.png` has 4 rows of 17 frames of 36 × 28 px, 612 × 112. Each row has the same outline as the first, with the wheels a quarter turn on from the row above, forward: seen side on, each nearer hub's mark turns about a quarter turn a row, its top towards the car's front. Only the palette's colours; the same bytes on each run of `make_car.gd` | `test_car_art.gd`: `test_the_sheet_has_a_frame_for_each_direction_and_the_wreck`, `test_each_phase_turns_the_wheels_in_the_same_outline`, `test_seen_side_on_the_wheels_roll_forward`; `test_area_art.gd`'s colours; P8 for the bytes |
| E3 | The sheet's users (W4). The double for the disasters cuts the body's frame from its row; `body_frame()` gives the heading's frame, which the shadow reads; the wreck shows the first row, whatever the phase | `test_car_controller.gd`: `test_its_double_shows_what_the_body_shows_where_it_shows_it`, `test_the_body_shows_the_frame_of_each_heading`, `test_a_crashed_car_shows_its_wreck_and_smokes`; `test_shadows.gd`: `test_the_cars_shadow_follows_its_frame_and_fades_with_it`; `test_crash.gd`: `test_a_crash_smokes_shakes_and_ends_the_game_after_crash_seconds` |
| E4 | Lots (W3, W5). `PropDef.lot` is the side of the square of ground cells that a prop takes: 1 by default, 2 or 4, which divide a tile's 4; `validate()` rejects 3. Each tile's cells make lots of each size that its area's props take, the largest first. A lot that no larger prop stands on shows one prop of its size, or none, by its own hash; a prop that shows stands on its lot's front cell and takes all of its cells, and one left out, as it would touch the road, takes none. Each size's densities add up to 1 at most, apart | `test_prop_layout.gd`: `test_a_lot_shows_one_prop_on_its_front_cell_and_no_other_stands_on_it`, `test_each_size_of_lot_takes_its_density_and_a_free_lots_cells_their_own`; `test_prop_scatter.gd`: `test_props_that_break_the_contract_are_errors_and_do_not_show`; `test_prop_art.gd`: `test_each_area_has_six_to_ten_props_some_animated` |
| E5 | The City (W2, W3; Q2). Its building takes a lot of 2 × 2 at 0.3 a lot. On two roads of 100 rows, more than 1,000 buildings show, and none on a cell next to another's, side by side or corner to corner: 2,792, where `main` shows 402, some of them in each other. A view shows 17.8 on average, 33 at most, and never none | `test_prop_layout.gd`: `test_the_city_shows_many_buildings_and_none_stand_in_each_other`; P1 |
| E6 | Everything else stands as before (W6). A lot of one cell has its cell's own hash, and one-cell props are laid in `main`'s order, so each area whose props all take one cell, all but the City, places the same props, in the same places and order, as on `main`. `smoke.sh` prints `main`'s line | `test_prop_layout.gd`: `test_props_of_one_cell_stand_where_they_stood_before_lots`; P2; `smoke.sh`: `autopilot: tile 165, turns 35, area rural` |
| E7 | Internal props (W7–W9). `PropScatter`'s pool holds its sprites as internal children of `Props`, in front of its own children: `simulate()` walks past them, the car draws over a prop on its y, and `Lamps` finds each prop's place with `get_index(true)`. Frames are the same as with ordinary children | `test_prop_scatter.gd`: `test_rows_show_props_ahead_of_the_car_and_lose_them_with_their_path_tile`, `test_the_layers_own_children_draw_over_the_props_on_their_y`; `test_lamps.gd`: `test_the_silhouettes_draw_in_the_order_props_draws_the_props`; P7 |
| E8 | The cost (W10, W11). On the desktop, a frame of the City renders with at most 0.3 ms more of the CPU than on `main` by day, and 1.9 ms more at night, in Movie Maker's render times (P5); a row of its props at most 3.6 ms to show (P3), and GUT no longer than on `main` (P6). On the Fold4, the APK holds 60 fps in the City by day, as IP's informal check asks (IP :203); at night, through the Web build in its Chrome, it is a hint (E9, §6.4) | §5.6; P3, P5, P6; E9 |
| E9 | Manual, on the Web in Chrome and Firefox and on both of the Fold4's screens, in the City by day and at night: the wheels turn forward at every speed and stop with the car; no building stands in another or on the road; nothing flickers; no error. The Fold4's APK holds 60 fps by day (E8) | §6.4: the City's buildings on the Web on 910cd24's build, whose game 6e75911 doesn't change (P10); the wheels' roll, which stills can't show, on PR 1's build, with a video; the Fold4 is the owner's |
| E10 | Docs (W14). PR 1: `plan.md` §5.3's line on the car. PR 3: `docs/VISUALS.md` replaces this plan, with its row in `docs/README.md`; `AGENTS.md`'s IDs and state; IP's M7 notes | Review |
| E11 | All five required checks are green on each PR, with §4's counts, and `smoke.sh` prints no error line. Each negative case makes the tests it names fail (§6.2), and the warnings check finds no new warning (§6.3) | PR checks; §6.2 and §6.3, run locally with Godot 4.7.2 on each PR's head |

---

## 2. Review findings

M5 drew the car and the props (docs/M5.md §5.6, §5.7). The car's sheet has one frame for each of 16 headings and the wreck, in one row. Each area's props stand one to a ground cell at most, each cell picking by its hash, and an area's densities add up to 1 at most; the City's add up to 0.045, of which its building takes 0.01. Nothing since has changed either: DN lit them and gave them shadows (docs/DAYNIGHT.md), and PL changes neither.

- **High:** what the owner asked for can't show, or shows wrong.
- **Medium:** fragile, or missing from the tests.
- **Low:** clarity, cost or polish.

Line numbers are `main`'s, at 81f22e3, unless they say otherwise.

### High

| # | Finding | Evidence | Fix |
|---|---|---|---|
| W1 | The wheels can't turn | Each axle's wheels are one ink box across the car, 0.06 to 0.12 tile ahead of its centre or behind it and 3 px high (`make_car.gd`:35–36), drawn alike in every frame of a one-row sheet (:61). `CarController` picks only the heading's frame (`car_controller.gd`:67). So nothing on the car moves but its heading, and at speed it slides | **Δ docs/M5.md §5.7:** each wheel a cylinder with a hub and a marked quarter, a row of the sheet for each of 4 phases, and the controller shows the row of the tiles it has driven (§5.1). Prototype (E1, E2) |
| W2 | The City is sparse | The building takes 0.01 of the ground cells; with the trees, lamps, bins, hydrants and traffic lights, the City's props take 0.045 (`make_props.gd`:23–30). A 360 × 640 view of the City shows 3.07 buildings on average, 9 at most, and 3% of views none (P1) | 0.3 of the City's lots of 2 × 2 (Q2, §5.3). Prototype (E5) |
| W3 | Buildings stand in each other, and more would stand in more | The building's base is a 40 × 20 px diamond, with its front corner on the foot (`make_props.gd`:343–345, `_box()` :543), and a ground cell's 32 × 16 (`Iso`). Two bases overlap when their feet are within `\|dx\|/40 + \|dy\|/20 < 1`, which is every pair of cells side by side or corner to corner. On `main` 8.3% of the City's buildings have such a neighbour; at 0.3 a cell 92% would, 89 pairs in each view (P12, P1) | **Δ docs/M5.md §5.6:** lots (§5.4): a building takes 2 × 2 cells, so the nearest two can stand is two cells apart. Prototype (E4, E5) |

### Medium

| # | Finding | Evidence | Fix |
|---|---|---|---|
| W4 | The sheet's users read only its first row | `double()` cuts `Rect2(FRAME_SIZE.x * _body.frame, 0, …)` (`car_controller.gd`:50); `body_frame()` returns `_body.frame` (:60–61), which, with rows, counts across them; `Shadows` cuts its outlines from the first row (`shadows.gd`:201–206) by `body_frame()` (:136). The disasters take the double (`legend.gd`:72) | The double cuts at `frame_coords * FRAME_SIZE`, `body_frame()` returns `frame_coords.x`, and the wreck shows the first row. Each row has the first's outline, so the shadow fits every phase (§5.2). Prototype (E3) |
| W5 | The density contract is per cell | "An area's densities add up to 1 at most, the chance that a ground cell shows a prop" (docs/M5.md §5.6, :102; `area_def.gd`:51–52). `_valid_props()` adds up every prop's (`prop_scatter.gd`:190, :196). A building's 0.3 is a lot's chance, not a cell's | **Δ docs/M5.md §5.6:** a prop's density is the chance that a lot of its size shows it, and each size's add up to 1 at most, apart; `validate()` rejects a lot that doesn't divide a tile (§5.4). Prototype (E4) |
| W6 | Lots must move nothing else | Rural's, the Meadows', the Village's and the Desert's props all take one cell. Each seed's look is where they stand, and `test_a_seed_shows_the_same_props_however_the_car_got_there` holds it. The prototype's first lot pass hashed every cell as a lot of one, and made every area's rows 0.12 ms slower (2fe01e1) | A lot of one cell has its cell's own hash, and one-cell props take `main`'s loop, skipping only the cells that a larger lot took. The other areas place the same 27,590 props as on `main`, in the same order (P2, §5.4). 2fe01e1, e3fe5b7 (E6) |
| W7 | GUT's time grows with the City's props | GUT's `simulate()` steps every node of the tree each frame, so DN held its shadows and lamps as internal children, which it skips (docs/DAYNIGHT.md C20). The City's lots more than double its props: the suite took 118 s instead of 91 (P6) | `PropScatter`'s pool holds its sprites as internal children of `Props`: 86 s (§5.5). 2fe01e1 (E7) |
| W8 | Internal children need `true` | On an internal node, `get_index()` is an error, "Node is internal. Can't get index with 'include_internal' being false.", and returns −1; `get_children()` and `get_child_count()` leave internal ones out. `Lamps` orders its silhouettes by `get_index()` (`lamps.gd`:114), and three tests count `Props`' children (`test_prop_scatter.gd`, `test_lamps.gd`, `test_area_start.gd`) | `get_index(true)`, `get_children(true)` and `get_child_count(true)` (§5.5). Without the first, `test_lamps.gd` fails, and before 4baf203 the whole suite logged 145,692 errors and ran out of memory (N19). 2fe01e1, 4baf203 (E7) |

### Low

| # | Finding | Evidence | Fix |
|---|---|---|---|
| W9 | Which draws first, the car or a prop on its y, depended on when the prop was made | Godot's y-sort draws a tie in the order of the children, internal ones included. `main.gd` adds the car to `Props` once the first rows show (:156), and a legend its double (`legend.gd`:72–74), so on `main` the props made before them drew under them and those made after over them | Internal children in front, `INTERNAL_MODE_FRONT`: every prop draws before the car at a tie (§5.5). 910cd24 (E7) |
| W10 | `Lamps` inserts each silhouette at its place, which costs more with more props | `bsearch_custom()`, then `insert()` and `move_child()` (`lamps.gd`:70–72), linear in the silhouettes. In the City, `Lamps` took 67–87 ms over 100 rows shown, against 19 ms on `main` (P3) | None now: a row shows within 3.6 ms at most (P3). §9 if the Fold4 shows it |
| W11 | Each row of the City costs more | A row takes 1.59 ms to show on average, 0.85 ms on `main`, and 2.6–3.6 ms at most; to hide, at most 0.99–1.08 ms, against 0.27–0.28 (P3). `PropLayout.row()` takes 0.79 ms in the City, against 0.60–0.62 on `main` (P4) | None by default: at the speed cap, 7 tiles a second, a row shows and another hides about every 8.6 frames at 60 fps, together within 4.7 ms. E8 and E9 (§5.6) |
| W12 | The City's street props thin, and move | Buildings take their lots' cells, so the City shows 23–29% fewer trees, lamps, bins, hydrants and traffic lights (P2). And `pick()` gives each prop of a list the next share of a cell's hash, in the list's order (`prop_layout.gd`:115–121). The building was first of the City's, so without it each street prop's share starts 0.01 lower, and a free cell may show another prop than on `main` | None by default (Q4): their densities × 1.37 would bring their numbers back. No test holds the City's street props where they stood: the City changes anyway |
| W13 | Four phases can alias | A wheel of 2.5 px rolling true would turn 5.8 times a tile: at the cap, 2.7 phases a physics frame, which reads as turning backwards. Physics runs at 60 Hz without interpolation, and the Fold4's screen at up to 120 Hz (IP §4 M7, :177) | Once a tile: at most 0.47 of a phase a physics frame, and 0.93 a drawn frame at 30 fps, so each frame shows the same phase or the next (§5.1). The Fold4 checks it (E9) |
| W14 | The docs describe one row and one cell a prop | docs/M5.md §5.6 (:102) and §5.7 (:106); `plan.md` §5.3 (:211): "Car: 16 directions at about 32×24 px, plus a crash frame." | PR 1 changes `plan.md`'s line, and PR 3 writes `docs/VISUALS.md` (§5.7, E10) |

---

## 3. Decisions and open questions

Each question has a default, which this plan and the prototype follow until the owner answers (§7). An answer that changes a default changes the PRs that §4 names for it.

| # | Question | Default | Alternative |
|---|---|---|---|
| Q1 | What does "the wheels turn" mean? | **They roll: they spin as the car drives, with its speed, and stand with it (§5.1)** | They steer as well: the front wheels point into a turn. Each heading would need frames for each angle of the front wheels and each phase (§9) |
| Q2 | How dense? | **0.3 of the City's lots: a view shows 17.8 buildings on average, 5.8 times `main`'s 3.07, 33 at most, and never none (P1)** | 0.2: 12.3 on average and 25 at most, 0.3 ms less a row to show. 0.4: 24.0 and 44, 0.3 ms more, and 3,800 more nodes (§5.3) |
| Q3 | New art for the buildings? | **No: the City's one building, as now** | Two or three buildings of the same lot, each with its density, so that a denser street repeats less (§9). Each needs its lights and its shadow, as DN gave the building |
| Q4 | Do the City's street props keep their densities? | **Yes: they thin by 23–29%, as buildings take their cells (W12)** | × 1.37, which places about as many as on `main` (P2) |
| Q5 | Which areas? | **The City's building only: the owner asked for the City's houses** | The Village's houses and the other wide props as well. The Village's houses, Rural's barns and windmills and the Meadows' ponds stand in each other's base 9.6%, 7.4% and 1.5% of the time (P12); each would take a lot of 2 × 2, and its density set again (§9) |
| Q6 | How do the PRs land? | **A stack of two, the wheels then the lots, then the docs from `main` once the second has merged (§4)** | Two PRs on `vis/plan`, which share no file and can merge in either order |

---

## 4. Work breakdown

Three PRs after this plan's (Q6): PR 1, the wheels, with base `vis/plan`; PR 2, the City's lots, with base PR 1's branch; then PR 3, the docs, from `main` once PR 2 has merged (§4.4). Each leaves CI green (E11).

```
plan PR ──▶ PR 1 the wheels (W1, W4, W13) ──▶ PR 2 the City's lots (W2, W3, W5–W12)
 (docs)                                             │
                                                    ▼  once PR 2 has merged, from main
                                                  PR 3 docs (W14)
```

Why this order:
- **One PR for each of the owner's two asks.** The wheels and the lots share no file (§4.1), so each can be reviewed, tried and stopped on its own.
- **The wheels first.** They change only the car, in 8 files. The lots change how every area lays its props, and their review needs W6's proof that nothing else moved.
- **Stacked, as `AGENTS.md` §4 asks.** Each is checked on the state that it lands on, and PR 2's counts are the prototype's (§6.1). Q6's alternative is two PRs on `vis/plan`.
- **The docs last**, once both are on `main` (docs/agents/planning.md §6).

### 4.1 Porting from the prototype

PRs 1 and 2 each take their files' part of the difference between `main` at 81f22e3 and the head of `vis/prototype`, 6e75911. Every one of its 21 files is changed, none added, so no `.uid` is new. PR 1 has the car's 8 files and PR 2 the props' 13, and together they make all 21: each was checked alone on `main`, and PR 2 on PR 1 is 6e75911 (§6.1).

1. Fetch the branches, create the PR's branch, and apply its files' part, here PR 1's:
   ```bash
   git fetch origin main '+refs/heads/vis/*:refs/remotes/origin/vis/*'
   git switch -c vis/1-wheels origin/vis/plan
   git diff --binary 81f22e3 6e75911 -- car/car.tscn car/car_controller.gd config/tuning.gd \
     tools/art/make_car.gd assets/car/car.png tests/unit/test_car_art.gd \
     tests/unit/test_car_controller.gd tests/unit/test_shadows.gd | git apply --index
   ```
   `--binary`, as `car.png` changes. PR 2 starts with `git switch -c vis/2-city-lots origin/vis/1-wheels` and names §4.3's 13 files. If `main` has moved on and changed the same lines, use `git apply --3way --index` and keep both.
2. Run the PR's art script, `godot --headless -s tools/art/make_car.gd` or `make_props.gd`, then `tools/ci/import.sh`: `git status --porcelain` must print nothing, as each script draws the same bytes on every run (P8).
3. Make the changes of any row of §4.6 for the PR that 6e75911 doesn't have, and for PR 1 `plan.md`'s line (§4.2).
4. Leave `VISUALS_PLAN.md` alone on the PRs' branches until this plan's PR has merged: until then it changes only on `vis/plan`, which is then merged up (§4.5). A change to it on a PR's branch would make the merge of `main` after the plan's squash an add/add conflict.
5. Run §6.1's checks, §6.2's negative cases and §6.3's warnings, and compare the counts with the PR's "Expect" line.
6. Have a model of another family review it (`AGENTS.md` §5). Then commit, push, and open the PR with its base.

### 4.2 PR 1: Car: wheels that turn as it drives **Δ W1, W4, W13**

Branch `vis/1-wheels`, from `vis/plan`. Commit as `car: turn the wheels as the car drives (VIS PR 1)`: the prototype's commits say "VIS prototype".

| Area | Files |
|---|---|
| Car | `car/car_controller.gd`: `PHASES`, `_rolled` and `phase()`; `_update_view()` sets `frame_coords`, the wreck's in the first row; `double()` cuts the body's frame from its row, and `body_frame()` returns its column (§5.1, §5.2). `car/car.tscn`: `vframes = 4` |
| Config | `config/tuning.gd`: `WHEEL_ROLL_TILES` (§5.1) |
| Art | `tools/art/make_car.gd`: the wheels, with `_splat_wheel()`, `_wheel_color()` and `_plot()`; a row for each phase; the wreck's colours for the wheels' (§5.1). `assets/car/car.png`, which it makes: 612 × 112 px, 13,587 B where `main`'s is 3,072 |
| Docs | `plan.md` §5.3's line on the car (:211) **Δ W14**: "Car: 16 directions at 36×28 px, each with its wheels in 4 phases of a turn, plus a crash frame." |
| Tests | `tests/unit/test_car_art.gd`: the sheet's size and rows, and 2 new (E2). `tests/unit/test_car_controller.gd`: 1 new (E1); the step, frame, double and wreck tests read `frame_coords`, and the wreck's rolls the wheels first (E3). `tests/unit/test_shadows.gd`: the car's shadow is checked in a phase past the first (E3) |

9 files, +295 −48 with `plan.md`'s line. Expect, on `vis/plan`: `check_scripts: loaded 160 scripts`, as on `main`; `GUT: 586 tests passed`, 3 more than `main`'s, in 77 test scripts (427,071 asserts, 210 more; 93.6 s locally); `autopilot: tile 165, turns 35, area rural`, as on `main`. Negative cases N1–N8.

**Acceptance:** E1–E3, E11, and E9's and E10's parts for PR 1.

### 4.3 PR 2: Props: lots, and a denser City **Δ W2, W3, W5–W12**

Branch `vis/2-city-lots`, from `vis/1-wheels`. Commit as `props: lay the city's buildings on lots of 2x2 cells, at 0.3 a lot (VIS PR 2)`.

| Area | Files |
|---|---|
| Areas | `areas/prop_def.gd`: `lot`, and `validate()`'s rule (§5.4). `areas/area_def.gd`: the densities' doc. `areas/props/city/building.tres`: `lot = 2` and `density = 0.3` (§5.3) |
| Art | `tools/art/make_props.gd`: `LOTS`, the building's density, and `lot` in each `.tres` where it isn't 1. It draws the same sheets as on `main` (P8) |
| World | `world/prop_layout.gd`: `LOT_SALT`; `row()` lays each size of lot, largest first, then the cells of one as on `main`; `_place()`, `by_lot()`, `lot_cells()` and `lot_hash()` (§5.4). `world/prop_scatter.gd`: the pool's sprites internal and in front (W7, W9), and `_valid_props()` adds up each size's densities apart (W5). `world/prop_pool.gd`: its doc. `world/lamps.gd`: `_draws_before()` with `get_index(true)` (W8) |
| Tests | `tests/unit/test_prop_layout.gd`: 4 new (E4–E6). `tests/unit/test_prop_scatter.gd`: 1 new (E7); the rows' test counts internal children, and the contract test adds a lot of 3 and a prop of 2 × 2 (E4). `tests/unit/test_prop_art.gd`: each size's densities (E4). `tests/unit/test_lamps.gd` and `tests/integration/test_area_start.gd`: internal children (W8) |

13 files, +327 −41. Expect, on `vis/1-wheels`: `check_scripts: loaded 160 scripts`; `GUT: 591 tests passed`, 5 more than PR 1's, in 77 test scripts (428,306 asserts, 1,235 more; 87.6 s locally); `autopilot: tile 165, turns 35, area rural`, as on `main` (E6). Alone on `main` they give 588 tests and 428,096 asserts. Negative cases N9–N23.

**Acceptance:** E4–E8, E11, and E9's part for PR 2.

### 4.4 PR 3: Docs: the wheels and the lots, and docs/VISUALS.md

Branch `vis/3-docs`, from `main` once PR 2 has merged (docs/agents/planning.md §6). Not before: it rewrites cites in PRs 1 and 2's files, so made from PR 2's branch it would carry other versions of them, and its merge of `main` after PR 2's squash would be an add/add conflict (docs/agents/stacks.md step 2).

| Area | Files |
|---|---|
| Docs | `docs/VISUALS.md`, new, at most about 15 KB, which replaces this plan (§5.7), and its row in `docs/README.md`. `VISUALS_PLAN.md`, deleted, and each cite of it in code and tests rewritten as `docs/VISUALS.md`, which is as long, so no line reflows |
| | docs/M5.md: §5.6 (:102) and §5.7 (:106) each end with "now …" and the ID of `docs/VISUALS.md` that changed them, as its L2 does for docs/ROADGEN.md R6 |
| | IP §4 M7: the device checks still open, with VIS's E9 (:178), and §9's notes (planning.md §6) |
| | `AGENTS.md`: the IDs (:18), with W# (VISUALS), and the state (:20) |

No code, so the counts are PR 2's. Its owner actions end with the tag and the branches (§7).

**Acceptance:** E10; E11.

### 4.5 Landing (Q6)

This plan's PR targets `main`, PR 1 targets `vis/plan`, and PR 2 targets `vis/1-wheels`. Only a PR whose base is `main` merges (`AGENTS.md` §5), so the owner squashes them in order: the plan, PR 1, then PR 2; PR 3 then starts from `main` (§4.4). The plan changes only on `vis/plan` until its PR merges. After that, each PR keeps its results and its review fixes in its body, and PR 2 carries the plan's final sync: its status, §4.6's rows, the counts and the device results (docs/agents/planning.md §5). So PRs 1 and 2 never change the same lines of the plan, and PR 3 deletes it.

A review fix goes on the branch of the PR that adds the file, then merges up (`AGENTS.md` §4). PRs 1 and 2 add no file and share none, so a fix goes on the branch of the PR that changes the file. The plan's fixes go on `vis/plan`, and merge into PR 1's branch with `git merge --no-ff --no-edit`, then into PR 2's.

After each squash, retarget the next PR to `main` before anyone deletes the merged branch: deleting a merged PR's branch closes each open PR based on it, unless GitHub has retargeted it first (docs/agents/stacks.md step 6). Then, on the next PR's branch (stacks.md step 5):

```bash
gh pr edit <next PR> --base main       # unless GitHub retargeted it
git fetch origin main '+refs/heads/vis/*:refs/remotes/origin/vis/*'
git switch <next PR's branch>
git merge origin/<merged PR's branch>  # its last fixes, in case one wasn't merged up yet
git merge origin/main                  # the squash
git diff --name-only origin/main       # must list only the next PR's files
git push
```

Each PR's branch merged the one before it, so its merge of `main` after that one's squash is clean. PL's PR 1 (#81) changes `config/tuning.gd`, as PR 1 does, at other lines: whichever lands second merges `main` cleanly (P11). Simulate each merge with `git merge-tree` first. A merge-up that changes no file in the PR's diff may start no Copilot review: request one with `gh pr edit <n> --add-reviewer @copilot`. If the owner links the PRs as a GitHub stack instead, it retargets and rebases them by itself (stacks.md step 7).

### 4.6 Review fixes

Fixes found while the prototype was built, by the internal review of this plan (§4.7) and by the PRs' reviews, each with its tests and its negative case.

| PR | Change | Tests | Negative case |
|---|---|---|---|
| 2 | W6: the first lot pass (5f02ebf) hashed every cell as a lot of its own, which made every area's rows 0.12 ms slower. 2fe01e1 lays the cells of one in `main`'s loop, skipping only those that a larger lot took; e3fe5b7 checks that each stands where it stood on `main` | `test_prop_layout.gd`: `test_props_of_one_cell_stand_where_they_stood_before_lots` | N15, N16 |
| 2 | W7: the City's lots took GUT from 91 s to 118 s. 2fe01e1 holds the props as internal children: 86 s, and the City's frames, by day and at night, are the same bytes (P6, P7) | `test_prop_scatter.gd`: `test_rows_show_props_ahead_of_the_car_and_lose_them_with_their_path_tile` | N17 |
| 2 | W8: the Lamps tests held the props as ordinary children, where `get_index()` and `get_index(true)` agree, so only a run in the City named the rule. 4baf203 holds them as `PropScatter` does | `test_lamps.gd`: `test_the_silhouettes_draw_in_the_order_props_draws_the_props` | N19 |
| 1 | W4: the wreck shows the first row, whatever the wheels' phase, but the controller's test crashed in the first phase, so only `test_crash.gd` saw a wreck drawn from the phase's row. 4baf203 rolls the wheels to the second phase first | `test_car_controller.gd`: `test_a_crashed_car_shows_its_wreck_and_smokes`; `test_crash.gd`: `test_a_crash_smokes_shakes_and_ends_the_game_after_crash_seconds` | N8 |
| 1 | E2: no test caught wheels that turn backwards, as the phase test checks only that the rows differ. 51f45d6 finds each nearer hub's mark, seen side on, and checks that each row turns it forward | `test_car_art.gd`: `test_seen_side_on_the_wheels_roll_forward` | N2 |
| 2 | W9: which drew first at a tie, the car or a prop, depended on when the prop was made. With internal children in front, every prop goes before the car; 910cd24 checks it | `test_prop_scatter.gd`: `test_the_layers_own_children_draw_over_the_props_on_their_y` | N17, N18 |
| 2 | W3: the lot tests use a block of their own, so nothing named the City's building: back on one cell at 0.3, it passed every test, with 11,742 buildings standing in each other. fc17a3e checks the City's own | `test_prop_layout.gd`: `test_the_city_shows_many_buildings_and_none_stand_in_each_other` | N20, N21 |
| 2 | E4: `PropDef.lot` allows 4, but the lot tests placed only lots of 2 × 2 and of one cell, so no test ran the skip of a lot that a larger lot's prop took, or `by_lot()`'s order. 6e75911 adds a square of 4 × 4 at 0.2 to both lot tests | The two lot tests (§6.2) | N22, N23 |

### 4.7 Internal review

To come: the review of this plan and the prototype by a model of another family (`AGENTS.md` §5).

---

## 5. Design

### 5.1 The wheels (W1, W13; Q1; E1, E2) **Δ docs/M5.md §5.7**

docs/M5.md §5.7 made the car's sheet one row of 17 frames of 36 × 28 px: 16 headings, clockwise from straight up, and the wreck. **Δ** The sheet has a row for each of `CarController.PHASES`, 4, phases of its wheels' turn, so it is 612 × 112 px. Row k has every frame, each with its wheels a quarter turn on from row k − 1 and with the first row's outline: only the wheels' faces and treads differ.

**The wheels.** `make_car.gd` drew each axle's wheels as one ink box across the car (:35–36). It now splats each of the four into the depth buffer as a cylinder, as it splats the boxes:

```gdscript
const WHEEL_RADIUS := 2.5                          # screen px; the axle as high
const WHEEL_ALONG: Array[float] = [0.09, -0.09]    # tiles; the rear where the skid marks start
const WHEEL_ACROSS := Vector2(0.07, 0.1)           # tiles; the body reaches 0.09
const HUB := 0.6                                   # of the radius
const HUB_COLOR := "asphalt light"
const MARK_COLOR := "white"
const TREAD_MARK := "asphalt"
```

Its tyre is ink, and its outer face's hub, within `HUB` of the radius, `HUB_COLOR`. A quarter of the wheel is marked, as if painted across it: `MARK_COLOR` on the hub, and `TREAD_MARK` on the tread, which shows from ahead and behind. A point's colour comes from where it is on the wheel's side, with the radius 1, forward then up:

```gdscript
static func _wheel_color(spoke: Vector2, v: float, tile_step: float, phase: int) -> String:
	var reach := spoke.length()
	if reach > 1.0:
		return ""
	# The mark starts at the top and turns towards the front: clockwise, seen from the right.
	var mark := TAU / 4.0 - phase * TAU / PHASES
	var marked := absf(wrapf(spoke.angle() - mark, -PI, PI)) < PI / PHASES
	if v > WHEEL_ACROSS.y - tile_step:
		if reach > HUB:
			return "ink"
		return MARK_COLOR if marked else HUB_COLOR
	if reach > 1.0 - STEP / WHEEL_RADIUS:
		return TREAD_MARK if marked else "ink"
	if v < WHEEL_ACROSS.x + tile_step:
		return "ink"
	return ""
```

A wheel's top moves forward as it rolls, so the mark turns towards the front a quarter turn each row: seen side on, clockwise when the car faces right. `test_seen_side_on_the_wheels_roll_forward` finds the mark's angle about each nearer hub in each row, and wants it to turn forward by 22.5° to 157.5° from each row to the next: about a quarter turn, and never back (N2). Every row draws the wreck alike, in phase 0, and the wreck's colours map the wheels' to its own: "asphalt light" and "white" to "shadow", "asphalt" to "tunnel road". None is ink, so the smoke over the wreck still shows (`test_car_controller.gd`). The sheet uses only the palette's colours (`test_area_art.gd`), and the script draws the same bytes on every run, in 5.2–5.4 s where `main`'s took 1.46 s (P8).

`test_each_phase_turns_the_wheels_in_the_same_outline` checks each frame's outline in every row against the first's. Seen side on or at a slant, the faces show, and all four phases differ on the straights; from ahead or behind they are edge on, and only the treads' marks show, so some phases may look alike there, but more than one differs (N1, N3).

**The roll.** `CarController` counts the tiles that the car drives, within one turn of its wheels, and shows the next row each `WHEEL_ROLL_TILES`:

```gdscript
## How far the car has driven, in tiles, within a turn of its wheels: PHASES phases.
var _rolled := 0.0

func _physics_process(delta: float) -> void:
	sim.step(delta, input.steer())
	_rolled = fposmod(_rolled + sim.speed * delta, Tuning.WHEEL_ROLL_TILES * PHASES)
	_update_view()

static func phase(rolled: float) -> int:
	return posmod(floori(rolled / Tuning.WHEEL_ROLL_TILES), PHASES)
```

and `_update_view()` sets `_body.frame_coords = Vector2i(frame(sim.forward()), phase(_rolled))`, or `Vector2i(WRECK_FRAME, 0)` after a crash.

- **Distance, not time.** `sim.speed` is in tiles a second, so the wheels turn faster as the car speeds up, and stand when it stands: before the run starts, and as a disaster brakes it (N4, N5). `_rolled` wraps at one turn, a tile, so it never grows and loses precision.
- **Once a tile (W13).** `WHEEL_ROLL_TILES` is 0.25. A true wheel of 2.5 px would turn 5.8 times a tile: `Iso.WIDTH_PX`, 90.5 px a tile across the screen, over its 15.7 px round. At `GLOBAL_SPEED_CAP`, 7 tiles a second, that's 2.7 phases a physics frame, which four phases show as 1.3 back. Once a tile, it's 0.27 of a phase a physics frame at `BASE_TOP_SPEED`, 4, and 0.47 at the cap: each frame shows the same phase or the next. Drawn at 30 fps, at the cap, it's 0.93 a frame, still forward. `test_its_wheels_turn_on_a_phase_each_wheel_roll_tiles_it_moves` drives 4 s with the autopilot, then brakes to a stop for a disaster: never two phases in a frame, nor back, round more than twice, and a phase each 0.25 tile within one.
- **Visual only.** Nothing reads `_rolled` or the row but the view and the double (§5.2), and no RNG is drawn, so a seed plays as before.
- **Rolling, not steering (Q1).** The front wheels don't point into a turn: each heading would need a frame for each angle of them in each phase (§9).

### 5.2 The sheet's users (W4; E3)

Three users of the sheet read only its first row on `main`. Each now reads the body's column and row:

| User | On `main` | Now |
|---|---|---|
| The body | `frame = WRECK_FRAME if crashed else frame(sim.forward())` (`car_controller.gd`:67) | `frame_coords`: the heading's column in the phase's row; after a crash the wreck's column in the first row, whatever the phase (N8) |
| `double()`, which a legend takes in the car's place (docs/M6.md §5.4; `legend.gd`:72) | `Rect2(FRAME_SIZE.x * _body.frame, 0, …)` (:50) | `Rect2(Vector2(_body.frame_coords * FRAME_SIZE), Vector2(FRAME_SIZE))`: what the body shows, its phase included, as a still (N7) |
| `body_frame()`, which `Shadows` shows (`shadows.gd`:136) | `_body.frame` (:60–61) | `_body.frame_coords.x`. `Sprite2D.frame` counts across the rows, so past the first phase it would name a frame past the 17 that `Shadows` cuts from the first row (`_car_def()`, :201–206): an error each frame, which fails 43 tests, 42 of them runs in the main scene (N6) |

So the car's shadow casts the first row's frame of its heading, whatever its phase. That is exact, as every row has the first's outline (§5.1): `test_the_cars_shadow_follows_its_frame_and_fades_with_it` now rolls the wheels past the first phase before it compares them.

### 5.3 The City's density (W2, W12; Q2, Q4; E5)

The City's building takes a lot of 2 × 2 cells, at 0.3 a lot: `building.tres` gets `lot = 2` and `density = 0.3`, from `make_props.gd`'s `LOTS` and `PROPS`. Its other props keep their densities, of a cell each: the tree and the lamp 0.01, the bin 0.006, the hydrant 0.005 and the traffic light 0.004 (Q4).

P1 drove seeds 1–5 for 40 s each in the City with the autopilot and sampled 385 views of 360 × 640 px:

| The building | Nodes | Buildings a view, mean and most | Views with none | Pairs in each other a view | Props a view | Sprites |
|---|---|---|---|---|---|---|
| `main`: a cell at 0.01 | 3,827 | 3.07, 9 | 3% | 0.06 | 17.7 | 471.6 |
| A lot of 2 × 2 at 0.2 | 9,736 | 12.31, 25 | 0 | 0 | 26.3 | 780.6 |
| **At 0.3 (Q2)** | 13,464 | **17.79, 33** | **0** | **0** | 31.0 | 983.3 |
| At 0.4 | 17,238 | 23.99, 44 | 0 | 0 | 36.5 | 1,188.0 |
| A cell at 0.3 | 50,619 | 92.99, 160 | 0 | 89.09 | 107.2 | 3,310.7 |

0.3 a lot, the default, shows 5.8 times `main`'s buildings: a street of them in every view, with ground between. 0.2 shows four times as many, and costs 0.3 ms less a row to show; 0.4 eight times as many, 0.3 ms more and 3,800 more nodes (P3). A cell at 0.3 would put most buildings in each other (W3).

P2 counted the props that 150 rows place on seeds 1–4: the City's buildings 1,133 on `main`, 8,760 at 0.3 a lot; its trees 1,274 → 918, lamps 1,276 → 929, bins 898 → 638, hydrants 728 → 541, traffic lights 530 → 406, 23–29% fewer, as buildings take their cells (W12). The City then places 12,192 props where `main` placed 5,839. Rural, the Meadows, the Village and the Desert place the same 27,590 props, in the same places and order, as on `main` (W6).

### 5.4 Lots (W3, W5, W6; E4, E6) **Δ docs/M5.md §5.6**

docs/M5.md §5.6 gave each ground cell beside the road one prop or none, by the cell's hash, with the area's densities adding up to 1 at most. **Δ** A prop takes a lot: a square of `lot` × `lot` ground cells, aligned with its tile's corner.

```gdscript
## The ground it takes, in cells a side: a lot of `lot` × `lot` cells, aligned with its tile's
## corner, whose front cell its foot stands on the centre of. No other prop stands on a lot that
## shows it, so a box wider than a cell, such as a building, stands in no other prop.
@export_range(1, 4) var lot := 1
## The chance that a lot of its size beside the road shows it.
@export_range(0.0, 1.0, 0.001) var density := 0.0
```

- **The contract.** `validate()` rejects a lot that doesn't divide a tile's 4 cells a side: "prop <id>: a lot of 3 cells doesn't divide a tile". A prop's density is the chance that a lot of its size shows it, and each size's densities add up to 1 at most, apart: `_valid_props()` keeps a sum for each (`prop_scatter.gd`), and `test_prop_art.gd` checks each area's (N13, N14).
- **Largest first.** `PropLayout.row()` takes each tile of the spread that is neither road nor near a set piece, as before. `by_lot()` sorts the area's props by the size of their lot, largest first (N23). For each size above 1, the tile's lots of that size, back to front, each pick a prop of their size, or none, by their own hash. A lot of which a larger lot's prop took a cell is skipped (N22). A prop that shows takes its lot's cells, a bit each in the tile's 16-bit `taken`; one left out, as its frame would touch the road, takes none, so its cells stay free for the props of one cell (N9, N11).
- **The front cell.** A prop stands on the centre of its lot's front cell, the one nearest the bottom of the screen, `origin + (a, b) + (lot − 1, lot − 1)`, and its box reaches back over the rest. In a lot of 2 × 2 the foot is 8 px below the lot's centre, at the front corner of the building's 40 × 20 px base (`make_props.gd`'s `_box()`), so the base reaches at most three quarters of the way to the lot's edges: the building stands within its lot.
- **The hash.** A lot of one cell has its cell's own hash, `cell_hash(props_seed, cell)`. A larger lot hashes its front cell, then mixes in a salt for its size, `_mix(hashed ^ (LOT_SALT * lot & MASK))`, with `LOT_SALT` 0x9E3779B9. Without it, the front cell of a lot that showed nothing would pick by the same hash, whose share is past the lot's densities: in the City, at 0.3 a lot, it would never show a prop of one cell, as those take the first 0.035 (N12).
- **Cells of one, as on `main` (W6).** Then each of the tile's cells that no larger lot took picks from the props of one cell by its own hash, in `main`'s loop: `b` outer, `a` inner (N10). An area whose props all take one cell skips nothing, so it places the same props as on `main`, in the same places and order (N15, N16). The City's take their shares of each hash without the building's, so they stand elsewhere than on `main` (W12).

```gdscript
	var sizes := by_lot(props)
	var singles: Array[PropDef] = sizes.get(1, [] as Array[PropDef])
	for j: int in range(-Tuning.PROP_SPREAD, Tuning.PROP_SPREAD + 1):
		var tile := anchor + Vector2i(j, -j)
		if buffer.tile_at(tile) != null or near_set_piece(tile, buffer):
			continue
		var origin := tile * Iso.GROUND_PER_TILE
		# The tile's cells that a larger lot's prop takes, a bit each.
		var taken := 0
		for lot: int in sizes:
			if lot == 1:
				continue
			var sized: Array[PropDef] = sizes[lot]
			for b: int in range(0, Iso.GROUND_PER_TILE, lot):
				for a: int in range(0, Iso.GROUND_PER_TILE, lot):
					var cells := lot_cells(Vector2i(a, b), lot)
					if taken & cells != 0:
						continue
					var front := origin + Vector2i(a, b) + Vector2i.ONE * (lot - 1)
					var hashed := lot_hash(props_seed, front, lot)
					var def := pick(sized, hashed)
					if def != null and _place(def, front, hashed, buffer, placed):
						taken |= cells
		if singles.is_empty():
			continue
		# The lots of one cell, as before lots, and as fast: most rows have no larger lots.
		for b: int in Iso.GROUND_PER_TILE:
			for a: int in Iso.GROUND_PER_TILE:
				if taken & (1 << (b * Iso.GROUND_PER_TILE + a)) != 0:
					continue
				var cell := origin + Vector2i(a, b)
				var hashed := cell_hash(props_seed, cell)
				var def := pick(singles, hashed)
				if def != null:
					_place(def, cell, hashed, buffer, placed)
```

`_place()` is `main`'s placement, with its animation's phase from the hash and its check of the road, and returns whether it placed the prop.

**Why no two buildings touch (W3).** A ground cell is 32 × 16 px, so cells (p, q) apart stand (16(p − q), 8(p + q)) px apart on the screen. Two of the building's 40 × 20 px bases overlap when |dx| / 40 + |dy| / 20 < 1, which is 0.8 · max(|p|, |q|) < 1: on cells side by side or corner to corner. Lots of 2 × 2 are aligned with the tiles, and a tile is 4 cells a side, so two buildings' front cells are an even number of cells apart each way, at least 2: 1.6. `test_the_city_shows_many_buildings_and_none_stand_in_each_other` places the City's own props on two roads of 100 rows: 2,792 buildings, none on a cell next to another's (N20, N21). The lot tests use a prop of their own, a block of 2 × 2, so they don't depend on the City's tuning.

**Larger lots.** No area uses a lot of 4 × 4, a whole tile. The lot tests place a square of 4 × 4 at 0.2, lots of 2 × 2 and props of one cell, so a square takes its tile first, and a lot of 2 × 2 shows only where no square does; the contract test rejects a lot of 3 (E4). The Village's houses, Rural's barns and windmills and the Meadows' ponds are wider than a cell too, but stand in each other less often (P12): Q5 leaves them as they are (§9).

### 5.5 Internal props (W7–W9; E7)

DN made the sprites of `Shadows` and `Lamps` internal children of their layers. GUT's `simulate()` steps every node of the tree each frame, but not internal children, and those sprites had taken CI's GUT from 98 s to 225 s (docs/DAYNIGHT.md C20). The props' own sprites stayed ordinary children of `Props`. The City's lots give it 3.5 times as many nodes (P1), and the suite took 118 s where `main`'s took 91 s (P6). So `PropScatter`'s pool holds them as internal children too:

```gdscript
	# Internal children, which simulate() walks past (docs/DAYNIGHT.md C20): the City's lots double
	# its props (VISUALS_PLAN.md W7). In front of the layer's own children, so that the car draws
	# over a prop on its y.
	pool = PropPool.new(layer, Node.INTERNAL_MODE_FRONT)
```

`PropPool` already takes the mode, for `Shadows` and `Lamps`, which hold theirs at the back of their own layers (`prop_pool.gd`:18, `shadows.gd`:37, `lamps.gd`:58); only its doc changes. The suite then takes 85–91 s, and the City's frames are the same bytes as with ordinary children (P6, P7).

- **What reads them (W8).** `get_children()` and `get_child_count()` leave internal children out, and `get_index()` on one is an error that returns −1. `Lamps._draws_before()` now orders the silhouettes by `get_index(true)`, where it used `get_index()` (`lamps.gd`:114). With `get_index()`, each silhouette that it inserts logs the error, and `test_the_silhouettes_draw_in_the_order_props_draws_the_props` fails (N19). That test holds its props as `PropScatter` does (`test_lamps.gd`:19), and the tests that look at `Props`' children pass `true`: `test_prop_scatter.gd`:118 and :140, `test_lamps.gd`:169 and `test_area_start.gd`:52.
- **Ties (W9).** Godot's y-sort draws two items of the same y in the order of the layer's children, internal ones included (servers/rendering/renderer_canvas_cull.h:117, `ItemYSort`). `Props`' own children are the car, which `main.gd` adds once the first rows show (:156); a legend's standing parts, which it moves there as it plays (`legend.gd`:56–59); and the car's double, which a legend takes in the car's place (:72–74). On `main`, a prop made before one of them drew under it at a tie, and one made after it drew over it. In front, every prop comes before them, so they draw over a prop on their y. `test_the_layers_own_children_draw_over_the_props_on_their_y` shows the first rows, adds a node as `main.gd` adds the car, drives on 199 tiles, and wants every sprite before it. As ordinary children, 1,057 of the 1,483 came before it and 426 after (N17); at the back, none came before it (N18).

### 5.6 The cost (W10, W11; Q2; E8)

The City's lots double the sprites in its views and give it 3.5 times as many nodes; the other areas cost what they did (W6). Measured on the desktop, `main` (81f22e3) against the prototype:

| What | `main` | VIS | Probe |
|---|---|---|---|
| The City's nodes, the whole tree's | 3,827 | 13,464 | P1 |
| Sprites in a view of the City | 471.6 | 983.3 | P1 |
| A row of the City's props shown: on average, at most | 0.85 ms, 1.24–1.30 ms | 1.59 ms, 2.6–3.6 ms | P3 |
| A row hidden, at most | 0.27–0.28 ms | 0.99–1.08 ms | P3 |
| `Lamps`, over 100 rows shown | 19 ms, 445 silhouettes | 67–87 ms, 877 silhouettes | P3 |
| `PropLayout.row()` | 0.60–0.62 ms in the City | 0.79 ms in the City; 0.63–0.65 ms in the others | P4 |
| A frame of the City by day: Movie Maker's render times, the CPU's and the GPU's | 5.32–5.34 ms, 6.61–6.62 ms | 5.59–5.62 ms, 6.79–6.83 ms | P5 |
| The same at 22:00 | 8.76–9.19 ms, 9.39–9.81 ms | 10.34–10.62 ms, 10.15–10.34 ms | P5 |
| GUT, locally | 91.5–94.4 s | 85.3–90.7 s | P6, §6.1 |
| The Web in the City, frames a second by day and at 22:00 | Chrome 33.0, 19.0; Firefox 54.7, 59.3 | Chrome 30.0, 18.7; Firefox 59.0, 59.0 | P10 |
| `make_car.gd`; `car.png` | 1.46 s; 3,072 B | 5.2–5.4 s; 13,587 B | P8 |
| The Web build; the APK | 11,219,350 B; 58,239,836 B | 7,847 B more; 5,973 B more | P8 |

**A row's worst frame.** At the speed cap, 7 tiles a second, a row shows and another hides about every 8.6 frames at 60 fps. In the City that costs at most 4.7 ms on the desktop, 3.6 to show and 1.08 to hide, where `main`'s cost 1.58 ms; a frame at 60 fps has 16.7 ms. `Lamps` takes about half of a row's show, 0.67–0.87 ms of 1.59 on average, as it inserts each silhouette at its place (W10).

**The desktop isn't the Fold4.** P5 ran on two cloud CPUs with software GL (llvmpipe), and Movie Maker's times are the renderer's: the CPU's work to set up each frame, and the GPU's, which llvmpipe runs on the CPU too. They compare `main` with VIS on one machine, but say nothing of a phone's frame. Nor do a browser's frames a second there, which vary as much from run to run as between the builds (P10; docs/agents/checks.md:64). So the Fold4 decides E8 and E9: the owner watches the City on PR 2's APK by day, and at night through its Web build in the Fold4's Chrome, with IP's fps check (§6.4; IP :203).

**At night.** A run's first night comes in Rural, as the City ends before its night, 65 s into the zone (docs/DAYNIGHT.md §5.8). So the City shows at night with `--hour`, as P5 ran it, or in a later schedule that brings the car back to it.

**If the Fold4 drops frames** (E9): show a row's props over a few frames, a lot at a time (§9); give `Lamps` a row's silhouettes at once (W10, §9); or take 0.2 a lot, whose rows take 1.29 ms on average to show and at most 2.1–2.9 ms (Q2, P3). Each is a change to PR 2, or a PR after it.

### 5.7 The docs (W14; E10)

PR 1 changes `plan.md` §5.3's line on the car (:211), as the sheet changes: "Car: 16 directions at 36×28 px, each with its wheels in 4 phases of a turn, plus a crash frame." **Δ W14**

PR 3 replaces this plan with `docs/VISUALS.md`, as each plan's summary has (`docs/README.md`; docs/agents/planning.md §6), at most about 15 KB. Its header says where the full plan is: `git show <sha>:VISUALS_PLAN.md`, the SHA of the last commit with it, and the tag `archive/vis/prototype`. Then the findings W1–W14, each with its fix; the decisions Q1–Q6 with the owner's answers; §5.1's wheels, §5.4's lots and §5.5's internal props, under the same section numbers, as code and tests cite them; the exit criteria and the device results. The device checks still open and §9's notes move to IP's M7 notes (§4.4).

At 6e75911, 19 lines in 14 files cite this plan: §5.1 (8), §5.4 (6), W3, W6, W7, W8 and W9. PR 3 makes each `docs/VISUALS.md`, which is as long as `VISUALS_PLAN.md`, so no line reflows, and `docs/VISUALS.md` defines each ID that they cite.

---

## 6. Verification

### 6.1 Checks and counts

The checks are `AGENTS.md` §3's five. `ci.yml` runs on pull requests, on pushes to `main` and by hand (`workflow_dispatch`), so a push to a `vis/` branch starts none: the prototype ran in runs started by hand with `upload-builds`, which built the Web build and the APK too. `main` (81f22e3) ran on its push and once by hand. Locally, with Godot 4.7.2, `main`, fc17a3e and 6e75911 ran all five, and so did each PR's files alone on `main`, applied as §4.1 says. Each loaded 160 scripts, ran 77 test scripts, and printed `main`'s smoke line, `autopilot: tile 165, turns 35, area rural`:

| State | Where | Tests | Asserts | GUT time | `test` job |
|---|---|---|---|---|---|
| `main` (81f22e3) | Run 43677544228, on its push | 583 | 426,861 | 112.8 s | 2 min 53 s |
| `main` (81f22e3) | Run 43681791616, by hand | 583 | 426,861 | 82.1 s | 2 min 36 s |
| `main` (81f22e3) | Local | 583 | 426,861 | 91.5–94.4 s | |
| PR 1's 8 files on `main` | Local | 586 | 427,071 | 93.6 s | |
| PR 2's 13 files on `main` | Local | 588 | 428,096 | 85.3 s | |
| Prototype (4baf203) | Run 43679922264 | 589 | 428,299 | 115.7 s | 2 min 56 s |
| Prototype (910cd24) | Runs 43680197599 and 43680444065 | 590 | 428,302 | 117.3 s, 118.3 s | 2 min 58 s, 3 min 1 s |
| Prototype (fc17a3e) | Local | 591 | 428,304 | 90.7 s | |
| Prototype (fc17a3e) | Run 43683511615 | 591 | 428,304 | 68.8 s | 2 min 23 s |
| Prototype (6e75911) | Local | 591 | 428,306 | 87.6 s | |
| Prototype (6e75911) | Run 43686668804 | 591 | 428,306 | 90.0 s | 2 min 49 s |

PR 1 adds 3 tests and 210 asserts: `test_car_art.gd`'s `test_each_phase_turns_the_wheels_in_the_same_outline` and `test_seen_side_on_the_wheels_roll_forward`, and `test_car_controller.gd`'s `test_its_wheels_turn_on_a_phase_each_wheel_roll_tiles_it_moves`. PR 2 adds 5 tests and 1,235 asserts, on PR 1 as alone on `main`: in `test_prop_layout.gd`, the two lot tests, `test_props_of_one_cell_stand_where_they_stood_before_lots` and `test_the_city_shows_many_buildings_and_none_stand_in_each_other`; in `test_prop_scatter.gd`, `test_the_layers_own_children_draw_over_the_props_on_their_y`. The prototype's last commits added the last of them (§4.6): 910cd24 the one in `test_prop_scatter.gd`, fc17a3e the City's, and 6e75911 a square of 4 × 4 to each lot test, 2 asserts.

Locally, every check passed. `lint.sh` printed `Success: no problems found` and `160 files would be left unchanged`, and the version pins and the Actions storage passed; it skipped shellcheck, which isn't installed there, and VIS changes no shell script. `smoke.sh` printed no error line, and `git status --porcelain` printed nothing after the checks. GUT's time varies from run to run, in CI most: from 68.8 s to 118.3 s over the prototype's runs above, and 112.8 s and 82.1 s for `main`'s one commit (P9). Locally, with the props internal, the prototype took 85–91 s, and `main` 91–94 s (P6).

### 6.2 Negative cases

Each change below makes the tests named fail, and nothing else. A script, not committed, applied each change to a clean worktree, ran `tools/ci/run_tests.sh`, read GUT's JUnit report, and restored the files: N1–N18 and N20–N23, each with all 591 tests, in 82.9–121.1 s and N20's 166.4 s; N1–N8, N13–N18, N20 and N21 on fc17a3e, and N9–N12, N22 and N23 on 6e75911. Each exited 1, and `git status --porcelain` printed nothing after it. For N1–N3 the script ran `make_car.gd` and `tools/ci/import.sh` first, so that the sheet changed, and `import.sh` again once it had restored the files. 6e75911 changes only `test_prop_layout.gd`, and there the cases run on fc17a3e fail as they did: run on 6e75911 with `-gselect=test_prop_layout`, N15 and N16 fail its one-cell test, N20 and N21 the City's, and N13, N14, N17, N18 and N19 none of its 9 tests. N19 ran on 6e75911 with `-gselect=test_lamps`, its 7 tests, and exited 1: a whole run logs its error by the hundred thousand.

**PR 1's** (§4.2):

| N# | Change | Fails |
|---|---|---|
| N1 | `make_car.gd`: every row drawn in phase 0, `_frame(heading(3 if wreck else f), wreck, 0)` | `test_car_art.gd`: `test_each_phase_turns_the_wheels_in_the_same_outline`, `test_seen_side_on_the_wheels_roll_forward` |
| N2 | `make_car.gd`: the mark turns backwards, `TAU / 4.0 + phase * TAU / PHASES` | `test_seen_side_on_the_wheels_roll_forward` |
| N3 | `make_car.gd`: no wheels, as `_splat_wheel()` returns at once | `test_each_phase_turns_the_wheels_in_the_same_outline` |
| N4 | `car_controller.gd`: `_rolled` never changes | `test_car_controller.gd`: `test_its_wheels_turn_on_a_phase_each_wheel_roll_tiles_it_moves`, `test_its_double_shows_what_the_body_shows_where_it_shows_it`, `test_a_crashed_car_shows_its_wreck_and_smokes`; `test_shadows.gd`: `test_the_cars_shadow_follows_its_frame_and_fades_with_it`. Each but the first rolls the wheels past the first phase first |
| N5 | `car_controller.gd`: the wheels roll with time, `_rolled + delta` | `test_its_wheels_turn_on_a_phase_each_wheel_roll_tiles_it_moves` |
| N6 | `car_controller.gd`: `body_frame()` returns `_body.frame` | `test_the_cars_shadow_follows_its_frame_and_fades_with_it`, and 42 tests that run the main scene, as `Shadows` logs an error each frame past the first phase (§5.2): 10 in `test_daylight_run.gd`, 6 in `test_retry.gd`, 5 in `test_wrong_turn_disaster.gd`, 4 each in `test_area_start.gd`, `test_main_scene_boot.gd` and `test_tutorial.gd`, 3 in `test_title.gd`, 2 each in `test_disaster_pools.gd` and `test_props_in_view.gd`, and 1 each in `test_audio.gd` and `test_crash.gd` |
| N7 | `car_controller.gd`: `double()` cuts from the first row, `Rect2(FRAME_SIZE.x * _body.frame_coords.x, 0, …)` | `test_its_double_shows_what_the_body_shows_where_it_shows_it` |
| N8 | `car_controller.gd`: the wreck in the phase's row, `Vector2i(WRECK_FRAME, phase(_rolled))` | `test_crash.gd`: `test_a_crash_smokes_shakes_and_ends_the_game_after_crash_seconds`; `test_a_crashed_car_shows_its_wreck_and_smokes` |

**PR 2's** (§4.3). The two lot tests are `test_prop_layout.gd`'s `test_a_lot_shows_one_prop_on_its_front_cell_and_no_other_stands_on_it` and `test_each_size_of_lot_takes_its_density_and_a_free_lots_cells_their_own`:

| N# | Change | Fails |
|---|---|---|
| N9 | `prop_layout.gd`: a lot's prop placed, but its cells not taken | The two lot tests |
| N10 | `prop_layout.gd`: the cells of one don't skip those that a larger lot took | The two lot tests |
| N11 | `prop_layout.gd`: a lot's prop left out, as it would touch the road, takes its cells all the same | `test_a_lot_shows_one_prop_on_its_front_cell_and_no_other_stands_on_it` |
| N12 | `prop_layout.gd`: `lot_hash()` returns the front cell's hash, without its size's salt | `test_each_size_of_lot_takes_its_density_and_a_free_lots_cells_their_own` |
| N13 | `prop_scatter.gd`: `_valid_props()` checks each prop against the sum of the props of one cell, `density.get(1, 0.0)`, not of its own size | `test_prop_scatter.gd`: `test_props_that_break_the_contract_are_errors_and_do_not_show` |
| N14 | `prop_def.gd`: `validate()` without its rule for the lot | `test_props_that_break_the_contract_are_errors_and_do_not_show` |
| N15 | `prop_layout.gd`: the cells of one hashed as a larger lot is, `_mix(cell_hash(…))` | `test_props_of_one_cell_stand_where_they_stood_before_lots` |
| N16 | `prop_layout.gd`: the cells of one in another order, `a` outer and `b` inner | `test_props_of_one_cell_stand_where_they_stood_before_lots` |
| N17 | `prop_scatter.gd`: the pool's sprites ordinary children, `PropPool.new(layer)` | `test_prop_scatter.gd`: `test_rows_show_props_ahead_of_the_car_and_lose_them_with_their_path_tile`, `test_the_layers_own_children_draw_over_the_props_on_their_y`. GUT took 121.1 s |
| N18 | `prop_scatter.gd`: the pool's sprites internal, but at the back, `INTERNAL_MODE_BACK` | `test_the_layers_own_children_draw_over_the_props_on_their_y` |
| N19 | `lamps.gd`: `_draws_before()` with `get_index()` | `test_lamps.gd`: `test_the_silhouettes_draw_in_the_order_props_draws_the_props`, with 226 errors "Node is internal. Can't get index with 'include_internal' being false.". Before 4baf203, the Lamps tests held their props as ordinary children, where `get_index()` works, and passed; the whole suite logged 145,692 such errors, and was killed when memory ran out (§4.6) |
| N20 | `building.tres` without `lot = 2`: the building on one cell, at 0.3 | `test_prop_layout.gd`: `test_the_city_shows_many_buildings_and_none_stand_in_each_other`. GUT took 166.4 s |
| N21 | `building.tres` as on `main`: one cell, at 0.01 | `test_the_city_shows_many_buildings_and_none_stand_in_each_other` |
| N22 | `prop_layout.gd`: a lot of which a larger lot's prop took a cell isn't skipped | The two lot tests |
| N23 | `prop_layout.gd`: `by_lot()` takes the sizes smallest first, `range(1, Iso.GROUND_PER_TILE + 1)` | The two lot tests |

### 6.3 Editor warnings

The five checks report no GDScript warnings, and shadowing shows only in the editor (`AGENTS.md` §2). As docs/agents/checks.md §1 says, a temporary `override.cfg` raised the 37 warnings at level 1 (warn) to 2 (error), and `check_scripts.sh` loaded every script. On `main` (81f22e3) and on 6e75911 it printed the same lines but for the worktrees' paths: the same 5 warnings, and no other error. They are `INTEGER_DIVISION` in `world/greybox_atlas.gd`:135, `ui/main.gd`:62, `test_greybox_atlas.gd`:15 and `test_iso.gd`:42, and `UNUSED_VARIABLE` `junctions` in `test_road_generator_occupancy.gd`:30; `make_art.gd` and `art_checks.gd`, which load `greybox_atlas.gd`, failed to compile after it. Godot reports only the first error in a script, so the probe ran again without `integer_division`: only `junctions` was left, on each. So no script that VIS changes has a warning, and no name it adds shadows a member or a built-in. The one integer division that it adds, in a lot test, has `@warning_ignore("integer_division")` (`test_prop_layout.gd`:226). The file was deleted after, and `git status --porcelain` printed nothing.

### 6.4 Verified only in CI or on devices

- **CI.** The five required checks on each PR, and the `test` job's time (§6.1). This plan's PR changes only this file.
- **The Web** (E9), by an agent, on PR 1 and on PR 2. Build the PR's branch, then download and serve the build with M4's patch, which passes the URL's `arg`s to the game (docs/agents/checks.md §4):
  ```bash
  gh workflow run ci.yml -R pompomon/roadgame --ref <branch> -f upload-builds=true
  rm -rf /tmp/roadgame-web
  gh run download <run id> -R pompomon/roadgame -n web -D /tmp/roadgame-web
  sed -i 's/"args":\[\]/"args":["--"].concat(new URLSearchParams(location.search).getAll("arg"))/' \
    /tmp/roadgame-web/index.html
  python3 -m http.server -d /tmp/roadgame-web 8000
  ```
  Open `http://localhost:8000/?arg=--autopilot&arg=--seed=1&arg=--area=city`, and again with `&arg=--hour=22`, in Chrome and Firefox, driven by Playwright, headed under Xvfb, at 360 × 640, each run in a new context. Post what each shows and the console's errors, by browser and hour, in a PR comment.
  - **PR 1.** The wheels roll only in motion, so record each run with Playwright's video, and post the videos: the wheels turn forward, faster as the car speeds up. `?arg=--play&arg=--seed=1&arg=--area=city` leaves the car alone: it misses its first turn, and the wheels must stop as the legend brakes it.
  - **PR 2.** Frames at 8, 16, 24 and 32 s, by day and at 22:00: buildings along the streets in each, none in another or on the road, and nothing that flickers from frame to frame.

  P10 ran PR 2's part on 910cd24's build, whose game 6e75911 doesn't change: 7–16 buildings a view, and no WebGL error in either browser, by day or at 22:00. Its stills can't show the wheels roll. A PR's build stays current while `git diff --name-only <built> HEAD -- . ':!tests' ':!addons/gut' ':!*.md'` prints nothing, so a fix to tests or words needs no new one.
- **The Fold4** (E9), by the owner, on both screens and through a fold. PR 2's debug APK has PR 1's wheels too, so one check can do for both PRs: `rm -rf /tmp/roadgame-apk && gh run download <run id> -R pompomon/roadgame -n "android-Android APK" -D /tmp/roadgame-apk`, as `gh` won't overwrite an earlier download (docs/agents/checks.md §4), then `adb install -r /tmp/roadgame-apk/roadgame-debug.apk`. The APK takes no arguments: in a debug build, the title's Start button chooses the City (docs/ZONE_SELECT.md; IP :178). By day, check that the wheels turn forward at every speed and stand with the car, that buildings line the streets, none in another or on the road, that nothing flickers, and the frame rate, with the Godot monitor overlay or `print_fps` (IP :203). The City's night needs `--hour` (§5.6), which the APK can't take: serve PR 2's Web build as above, run `adb reverse tcp:8000 tcp:8000`, and open `http://localhost:8000/?arg=--autopilot&arg=--seed=1&arg=--area=city&arg=--hour=22` in the Fold4's Chrome (docs/agents/checks.md:67). A browser's frame rate isn't the APK's, so the night's is a hint: if it drops where the day's holds, §5.6 says what to change.

### 6.5 Measurements

The probes ran with Godot 4.7.2 on `main` (81f22e3) and on the prototype, headless unless they say otherwise; they aren't committed. Those of the prototype before 44c3e0a ran on `main` at 2d93074, which 81f22e3 changes only by adding PL's plan, `POOLS_PLAN.md`.

| P# | What | Result | Used by |
|---|---|---|---|
| P1 | The City's views: seeds 1–5, 40 s each with the autopilot in the City, 385 views of 360 × 640 px sampled along the way; the nodes in the tree, and in each view the buildings, the pairs of them in each other's base, the props and the sprites. For `main`, and for the building on a lot of 2 × 2 at 0.2, 0.3 and 0.4, and on a cell at 0.3 | §5.3's table. At 0.3 a lot, a building would touch the road on 24% of the lots, so 75% of its picks show. Run again on fc17a3e: the same numbers | W2, W3, Q2, E5, §5.3, §5.6 |
| P2 | The props that 150 rows place on seeds 1–4, in each area, `main` against the prototype | The City: 5,839 → 12,192 props, its buildings 1,133 → 8,760, its trees 1,274 → 918, lamps 1,276 → 929, bins 898 → 638, hydrants 728 → 541 and traffic lights 530 → 406. Rural, the Meadows, the Village and the Desert: the same 27,590 props, in the same places and order | W6, W12, Q4, E6, §5.3 |
| P3 | A row's cost in the City: `--fixed-fps 60 --quit-after <n> -- --autopilot --seed=1 --area=city`, with `PropScatter._show_row()` and `_hide_row()` timed, from physics frame 120. `main` showed 100 rows in 1,240 frames | To show, on average and at most, and to hide at most; the props placed and `Lamps`' silhouettes in 100 rows. `main`: 0.85, 1.24–1.30 and 0.27–0.28 ms; 1,070 and 445. 0.2 a lot: 1.29, 2.1–2.9 and 0.70–0.77 ms; 1,726 and 691. 0.3: 1.59, 2.6–3.6 and 0.99–1.08 ms; 2,167 and 877. 0.4: 1.88, 3.1–4.8 and 1.4–3.4 ms; 2,615 and 1,063. Of 100 rows' shows, `Lamps` took 19 ms on `main` and 67–87 ms at 0.3 | W10, W11, Q2, E8, §5.3, §5.6 |
| P4 | `PropLayout.row()` alone: each area's props on 200 rows of ground far from any road, so every tile of the spread lays its props; the best of 5 runs | `main`: 0.60–0.62 ms a row in the City. The prototype: 0.79 ms in the City, 0.63–0.65 in the others. The first lot pass (5f02ebf), which hashed every cell as a lot, took 0.12 ms more in every area | W6, W11 |
| P5 | A frame of the City in Movie Maker: 900 frames at 360 × 640 under Xvfb, with software GL (llvmpipe) on 2 CPUs, `--fixed-fps 60 -- --autopilot --seed=1 --area=city`, and again with `--hour=22`; two runs of each, with nothing else running. Movie Maker prints each run's average CPU and GPU render times | §5.6's table. By day the prototype takes 0.25–0.30 ms more of the CPU and 0.17–0.22 of the GPU; at 22:00, 1.15–1.86 and 0.34–0.95 | E8, §5.6 |
| P6 | GUT's time locally, with the props' sprites as ordinary children and as internal ones | `main` 91 s; the prototype 118 s with ordinary children and 86 s with internal ones; since then 85–91 s (§6.1) | W7, E8 |
| P7 | Whether internal children draw the same: 600 frames of the City by day and 600 at 22:00, seed 1, in Movie Maker as P5, with the props' sprites internal and as ordinary children | All 1,200 frames the same bytes | W7, E7 |
| P8 | The art and the builds: both art scripts run again in a worktree of 910cd24, and the builds' sizes in CI | `make_car.gd` 5.2–5.4 s, against 1.46 s on `main`; `make_props.gd` 0.45 s. `car.png`, `skid.png`, each area's `props.png` and the `.tres` files came out as committed, and `git status --porcelain` printed nothing. `car.png` 3,072 → 13,587 B. The Web build 11,219,350 → 11,227,197 B, and the APK 58,239,836 → 58,245,809 B, from runs 43681791616 and 43686668804 | E2, §5.1, §5.6 |
| P9 | GUT's time in CI's `test` job | 68.8–118.3 s over the prototype's runs; `main`'s 81f22e3 took 112.8 s on its push and 82.1 s by hand (§6.1) | §6.1, §8 |
| P10 | The Web: the builds of `main` (run 43681791616) and of 910cd24 (run 43680444065), whose game 6e75911 doesn't change, served as §6.4 says, at `?arg=--autopilot&arg=--seed=1&arg=--area=city` and with `&arg=--hour=22`. Playwright 1.64, headed under Xvfb, at 360 × 640, a new context for each run: the frames a second over 3 s, from `requestAnimationFrame`; stills at 8, 16, 24 and 32 s; the console | Frames a second by day and at 22:00. Chrome: `main` 33.0 and 19.0, VIS 30.0 and 18.7, and 31.3 and 21.0 in an earlier run. Firefox: `main` 54.7 and 59.3, VIS 59.0 and 59.0. 7–16 buildings a view. No WebGL error from either build. Chrome logged 4 `GPU stall due to ReadPixels` notes by day from each build, and none at 22:00, and one `CONTEXT_LOST_WEBGL` from `main` by day, as software GL does (docs/agents/checks.md:64). Firefox logged the same 8 warnings in each run: 7 that an AudioContext waits for a gesture, and one that the wasm `try` instruction is deprecated | E9, §5.6, §6.4 |
| P11 | Whether VIS merges with PL's PR 1 (#81, `pl/1-picks` at 532908a): `git merge-tree` with 6e75911 | Clean: both change `config/tuning.gd`, at other lines | §4.5 |
| P12 | How often a prop wider than a cell stands in another: 4 seeds × 100 rows of each area; such props with another on a cell next to theirs, side by side or corner to corner | The City's buildings on lots: 5,748, none. Rural's barns and windmills: 42 of 571 (7.4%), 22 pairs. The Meadows' ponds: 4 of 275 (1.5%), 2 pairs. The Village's two houses: 89 of 929 (9.6%), 47 pairs. The Desert has none. The City's building as on `main`: 63 of 762 (8.3%), 33 pairs; on a cell at 0.3: 22,065 of 23,881 (92.4%), 26,827 pairs | W3, Q5, §9 |

---

## 7. Owner actions

| When | Action | How |
|---|---|---|
| Now | Answer Q1–Q6, or accept the defaults | A comment on this plan's PR. Without an answer, the PRs follow the defaults (§3). Q1 changes PR 1; Q2–Q5 PR 2; Q6 how they land |
| Now, if wanted | Try the prototype on the Fold4 | Until 2026-11-16 06:42 UTC: `rm -rf /tmp/roadgame-apk && gh run download 43686668804 -R pompomon/roadgame -n "android-Android APK" -D /tmp/roadgame-apk`, then `adb install -r /tmp/roadgame-apk/roadgame-debug.apk`. After that, `gh workflow run ci.yml -R pompomon/roadgame --ref vis/prototype -f upload-builds=true` makes a new one, kept a day. In a debug build, the title's Start button chooses the City (§6.4) |
| On PR 2 | E9 on the Fold4, on both screens and through a fold | §6.4: PR 2's APK in the City by day, and its Web build at 22:00 in the Fold4's Chrome. PR 2's APK has PR 1's wheels too, so one check does for both PRs; PR 1's own APK, built as above with `--ref vis/1-wheels`, shows the wheels on `main`'s City |
| To land VIS | Merge this plan's PR, then PR 1, then PR 2, each once its base is `main` and its checks pass; then PR 3, which starts from `main` once PR 2 has merged (§4.4) | Squash each. Before deleting a merged PR's branch, retarget the next PR to `main` (§4.5) |
| After PR 3 | Tag the prototype, which this plan cites, and delete the `vis/` branches | `git fetch origin vis/prototype && git push origin FETCH_HEAD:refs/tags/archive/vis/prototype`, then `git push origin --delete vis/plan vis/prototype vis/1-wheels vis/2-city-lots vis/3-docs`, less any already deleted (docs/agents/planning.md §6) |

---

## 8. Risks

| Risk | Impact | Mitigation |
|---|---|---|
| The Fold4 drops frames in the City | The City holds 3.5 times the nodes and twice the sprites in a view (P1), and at the speed cap a row shows and another hides about every 8.6 frames, within 4.7 ms on the desktop (§5.6). A phone's CPU is slower, and P5's times say nothing of its frame | E9 checks it on PR 2's APK (§6.4). If it shows: spread a row's show over frames, give `Lamps` a row's silhouettes at once, or take 0.2 a lot (§5.6, §9) |
| The City's night is seen only through `--hour` | A run's first night comes in Rural (§5.6), so the APK shows the City by day only; at 22:00 a frame takes 1.15–1.86 ms more of the renderer's CPU on the desktop, against 0.25–0.30 by day (P5) | The Fold4's Chrome runs PR 2's Web build at 22:00 (§6.4). Its frame rate is a hint, as a browser's isn't the APK's |
| GUT's time in CI | CI's `test` job varies from 68.8 s to 118.3 s (P9); the City's nodes would slow each test that drives there | The props' sprites are internal children, which `simulate()` walks past: locally the suite takes 85–91 s, and `main`'s 91–94 s (W7, P6) |
| PL's PR 1 (#81) lands first | Both change `config/tuning.gd` | At other lines: the merge is clean (P11). Simulate each merge with `git merge-tree` first (§4.5) |
| Too dense, or too sparse | The owner sees the City on the Fold4 and wants another look | Q2: another density is one value in `make_props.gd`'s `PROPS`, then `make_props.gd` again; §5.3 measured 0.2 and 0.4, and P3 their cost |
| The City's street props move and thin | A seed's City shows its trees, lamps, bins, hydrants and traffic lights elsewhere than on `main`, and 23–29% fewer (W12, P2) | Q4: their densities × 1.37 bring their numbers back. No test holds where they stood, and the other areas' stand as before (E6) |
| The wheels shimmer, or alias | The Fold4's screen refreshes at up to 120 Hz, and four phases a tile could read as flicker on the hubs | Physics steps at 60 Hz without interpolation (IP :177), so each frame drawn shows a physics frame's phase, at most 0.47 of a phase on from the last (W13). If they shimmer, `WHEEL_ROLL_TILES` is one constant, and the sheet could take more phases (§9) |

---

## 9. Notes for later work

- **Other areas' wide props on lots** (Q5, P12). The Village's houses, Rural's barns and windmills and the Meadows' ponds stand in each other's base 9.6%, 7.4% and 1.5% of the time. Each would take `lot = 2` and a density for a lot, set so that its area shows about as many as now; its area's props would then stand elsewhere than on `main`, as the City's do (W12).
- **More buildings** (Q3). Two or three for the City's lots, each with its density, its lights and its shadow, as DN gave the building (docs/DAYNIGHT.md), so that a denser street repeats less.
- **Lots of a tile.** `PropDef.lot` allows 4, a whole tile, which the lot tests place: a park, a square or a plaza could take one.
- **Steering** (Q1). Front wheels that point into a turn need a frame for each heading, each angle of the wheels and each phase: three angles would triple the sheet. The angle would come from `input.steer()`, and stay visual only.
- **More phases** (W13). Six or eight rows a turn would roll more smoothly. The wheels would still turn once a tile, 0.12 of a turn a physics frame at the cap, so they would never seem to turn back. `make_car.gd`, the controller and the tests read `CarController.PHASES`, and `test_car_art.gd` checks that `car.tscn`'s `vframes` matches it; each row adds about 3.4 KB to the sheet (P8).
- **A row's show over frames** (W11, §5.6). `PropScatter` could show a row's props a tile at a time, over the frames before the next row, as rows show ahead of the view. Only if the Fold4 drops frames.
- **A faster `Lamps` insert** (W10). Sort a row's silhouettes once, then merge them into the layer's in one pass, rather than a `bsearch_custom()` and a `move_child()` for each.
- **Physics interpolation** (IP :177). If M7.5 turns it on, the wheels' phase still steps once a physics frame, as `_rolled` is set in `_physics_process()` and a sprite's frame doesn't interpolate.
- **M7.5's checklist** (IP :206). The wheels at every speed, and the City by day and at night, on both screens.
