# Visuals: Wheels That Turn and a Denser City — Detailed Plan

Status: landing. The plan, #85, is squashed into `main` as 02c38ac, and PR 1, #93, as 6f12931, so #88 takes A15's commit (§4.2). PR 2, #94, now on `main`, waits for the owner's E9 on the Fold4 (§7); PR 3 follows it (§4.4) · 2026-11-16 · The owner took the defaults of Q1 and Q3–Q6, and answered Q2: the City's buildings at 35% to 60%, closer to its streets, and see-through where they would hide the car, as the tunnel is (§3) · Scope: the car's wheels turn as it drives, and buildings line the City's streets, none standing in another and none hiding the car; but for the City's street props and #88's tyre tracks (A15), nothing else that shows changes. This plan calls the work VIS. It comes after DN (#64, #70–#76), beside PL (#80–#83, #86–#90) and EG's plan (#84), and before M7.

The owner asked: "Explore the codebase and create a detailed implementation plan for visual enhancements. 1. Update the car visual to make the wheels turn while driving. 2. Increase the number of the houses density in the city". To Q2 they answered: "keep density between 35% and 60%, and move buildings closer to the streets. If the building overlaps the camera view of the car, then make them more transparent similar to the tunnel view."

**The wheels.** The car is one row of 17 frames of 36 × 28 px, 16 headings and the wreck (docs/M5.md §5.7). Its wheels are an ink box across each axle, alike in every frame (`make_car.gd`:35–36), so nothing on the car moves but its heading (A1). PR 1 draws each wheel as a cylinder with a hub and a marked quarter, and gives the sheet a row for each of four phases, each a quarter turn on. `CarController` shows the next row each `WHEEL_ROLL_TILES`, a quarter of a tile, that the car drives: the wheels turn once a tile, with its speed, and stand when it stands. A frame drawn turns them a phase at most, only forward, at any frame rate (§5.1, A13). The double, the shadow and `body_frame()` read the body's row (A4).

**The City.** Its "small houses" (`plan.md` §3.6, :117) are its building prop, on 0.01 of the ground cells: 3.1 a view, and 3% of views none (P1, A2). Its base is wider than a cell, so denser buildings would stand in each other (A3). PR 2 gives each prop a lot, `PropDef.lot`, the side of the square of ground cells that it takes, 2 for the building: each tile's four lots of 2 × 2 show a building or not by their own hash, and no two touch (§5.4). The other areas' props stand as before (A6). A lot with a side on a street shows one at 0.6, `PropDef.street_density`, and the others at 0.35 (Q2, §5.8). But `main` leaves out each prop whose frame touches the road, and a building's does from every lot by a street (A16). So the building is see-through: it may rise over the road behind it, and where it would hide the car or a legend it shows 0.2 of itself, as the tunnel does, and comes back as they part (§5.9, A17). A view of the City shows 63 to 100 buildings, 80.7 on average, and in 68% of views one stands over the car, faded (P13). The City's street props are 35–42% fewer (A12, Q4).

**The cost.** GUT's `simulate()` walks every node, so the props' pool holds its sprites as internal children of `Props`, as `Shadows` and `Lamps` hold theirs (A7, docs/DAYNIGHT.md C20). They go in front of the layer's own children, so the car draws over a prop on its y (A9). On the desktop, Movie Maker's render times for a frame of the City grow by 1.4–1.7 ms of the CPU's by day and 4.8–5.3 ms at night against `main`, as each building's windows glow (P15, A21); a row of props takes 1.45 ms to show, against 0.90 (P17), and the fade 35 µs a frame (P14). The Fold4 reads the frame rate (E8).

**Verified locally and in CI.** Every file of PRs 1 and 2 was built first on branch `vis/prototype`, from `main` at 2d93074, which merged `main` at 81f22e3 in 44c3e0a. Its first commit, 5f02ebf, adds the wheels and the lots, and the next make fixes of §4.6; 4d607d7 numbers the findings A#, and a7ab941 and a6b88fb follow Q2's answer. PR 2's branch adds the reviews' fixes, in 93a55e3 and 6ef331f (§4.6). It passed the five checks locally with Godot 4.7.2 and in CI, and so did each PR's branch (§6.1), and the warnings check (§6.3); each negative case, with the whole suite on its PR's head, failed the tests it names (§6.2). Probes measured the City's views and placements, the rows' and the fade's cost, the frames by day and at night, the Web in Chrome and Firefox, GUT's time and the art (§6.5).

- Godot 4.7.2-stable (4.7.2.stable.official.ed1daf0bf), in CI's image and locally
- GUT 9.7.1
- gdtoolkit 4.5.0 on Python 3.12, in CI's `lint` job and locally; shellcheck only in CI (§6.1)

**Precedence.** For VIS, this document replaces docs/M5.md §5.6 (:100–102), on the props' density and placement, and §5.7 (:104–106), on the car's sheet, and `plan.md` §5.3's line on the car (:211), wherever it marks a difference with **Δ** and its finding (A#, §2). PR 1 changes `plan.md`'s line; PR 3 replaces this plan with `docs/VISUALS.md` (§4.4).

**Reference code.** This plan has no appendices. PR 1 applies its files' part of the difference between 81f22e3, `main`, and 4d607d7, the prototype before Q2's answer; PR 2 checks out its files, and three of PR 1's, from a6b88fb, the head of `vis/prototype`, which never gets a PR of its own, and adds the reviews' fixes (§4.1).

**Prerequisites.** M0–M6, RG, ZS, TUT and DN are merged, and so is PL's plan (#1–#80); `main` is at 81f22e3. PL's PRs 1–10 (#81–#83, #86–#91, #96), each on the one before, are open: of VIS's 27 files they change only `config/tuning.gd` and `plan.md`, at other lines, and merge with each VIS PR's head cleanly (P11). Their legends take the car's double, which PR 1 cuts from the body's row (§5.2), and stand their parts on `Props`, where buildings fade for them (§5.9); #88's tyre tracks fit `main`'s back wheels, which PR 1 redraws, so the later of the two narrows them (A15). EG's plan (#84) is in review: it changes `plan.md` at other lines than PR 1, and its PR 3 would add the Coast's props to `make_props.gd`, which PR 2 changes (§4.5). #95, on how agents land PRs, is open too. M7 hasn't started; §9 has notes for it. No repository settings change.

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

Goal: the car's wheels turn as it drives, with its speed and forward, and the City looks like a city: buildings line its streets in every view, none standing in another, and none hiding the car. Nothing else changes: the other areas' props, the road, how the car drives, the disasters, the light, the screens, and what a seed plays; with #88, its tyre tracks narrow to fit the new wheels (A15).

| # | Exit criterion | Checked by |
|---|---|---|
| E1 | The wheels roll (A1, A13; Q1). The body shows the row of its wheels' phase, the next of 4 each `WHEEL_ROLL_TILES`, 0.25 tile, that the car drives: once a tile, faster as the car speeds up, not at all while it stands, and at most 0.47 of a phase a physics frame, at the speed cap. A frame drawn rolls them by the car's drive since the last, but a phase at most, and drops the rest: they turn only forward, however few frames a second are drawn and however unevenly, no less often as the car goes faster, and stand once it stands | `test_car_controller.gd`: `test_its_wheels_turn_on_a_phase_each_wheel_roll_tiles_it_moves` (*roll* below), `test_a_drawn_frame_turns_the_wheels_a_phase_at_most_and_the_faster_the_more_often` (*drawn*), `test_once_the_car_stands_its_wheels_stand_however_far_it_rolled_unshown` (*stands*), `test_at_6_frames_a_second_the_wheels_turn_a_phase_at_most_and_stand_with_the_car` (*6 fps*) |
| E2 | The sheet (A1). `car.png` has 4 rows of 17 frames of 36 × 28 px, 612 × 112. Each row has the first's outline, with the wheels a quarter turn on from the row above: seen side on, each nearer hub's mark shows in every row, and turns about a quarter turn a row, its top towards the car's front. Only the palette's colours; the same bytes on each run of `make_car.gd` | `test_car_art.gd`: `test_the_sheet_has_a_frame_for_each_direction_and_the_wreck`, `test_each_phase_turns_the_wheels_in_the_same_outline`, `test_seen_side_on_the_wheels_roll_forward`; `test_area_art.gd`'s colours; P8 |
| E3 | The sheet's users (A4). The double for the disasters cuts the body's frame from its row; `body_frame()` gives the heading's frame, which the shadow reads; the wreck shows the first row, whatever the phase. With #88, its tyre tracks and sand fit the new back wheels (A15) | `test_car_controller.gd`: `test_its_double_shows_what_the_body_shows_where_it_shows_it`, `test_the_body_shows_the_frame_of_each_heading`, `test_a_crashed_car_shows_its_wreck_and_smokes`; `test_shadows.gd`: `test_the_cars_shadow_follows_its_frame_and_fades_with_it`; `test_crash.gd`'s crash; with #88, `test_marfa_lights.gd`'s tracks and sand (N34, N35) |
| E4 | Lots (A3, A5). `PropDef.lot` is the side of the square of ground cells that a prop takes: 1 by default, 2 or 4, which divide a tile's 4; `validate()` rejects 3. Each tile's cells make lots of each size that its area's props take, the largest first. A lot that no larger prop stands on shows one prop of its size, or none, by its own hash; a prop that shows stands on its lot's front cell and takes all of its cells, and one left out, as it would touch the road, takes none. Each size's densities add up to 1 at most, apart, and so do its street densities, 1 itself included | `test_prop_layout.gd`: `test_a_lot_shows_one_prop_on_its_front_cell_and_no_other_stands_on_it`, `test_each_size_of_lot_takes_its_density_and_a_free_lots_cells_their_own` (the two lot tests); `test_prop_scatter.gd`: `test_props_that_break_the_contract_are_errors_and_do_not_show` (*contract*), `test_densities_that_add_up_to_1_are_valid` (*add up*); `test_prop_art.gd`'s densities |
| E5 | The City (A2, A3, A16; Q2). Its building takes a lot of 2 × 2, at 0.6 by a street and 0.35 elsewhere, and is see-through. On two roads of 100 rows, more than 4,600 buildings show, none on a cell next to another's, side by side or corner to corner: 4,951, where `main` shows 402, some in each other. A view shows 80.7 on average, 63 to 100 | `test_prop_layout.gd`: `test_the_city_shows_many_buildings_and_none_stand_in_each_other` (*City*); P13 |
| E6 | Everything else stands as before (A6). A lot of one cell has its cell's own hash, and one-cell props are laid in `main`'s order, so each area whose props all take one cell and have no street density, all but the City, places the same props, in the same places and order, as on `main`. `smoke.sh` prints `main`'s line | `test_prop_layout.gd`: `test_props_of_one_cell_stand_where_they_stood_before_lots`; P2; `smoke.sh`: `autopilot: tile 165, turns 35, area rural` |
| E7 | Internal props (A7–A9). `PropScatter`'s pool holds its sprites as internal children of `Props`, in front of its own children: `simulate()` walks past them, the car draws over a prop on its y, and `Lamps` finds each prop's place with `get_index(true)`. Frames are the same as with ordinary children | `test_prop_scatter.gd`: `test_rows_show_props_ahead_of_the_car_and_lose_them_with_their_path_tile` (*rows*), `test_the_layers_own_children_draw_over_the_props_on_their_y` (*ties*); `test_lamps.gd`: `test_the_silhouettes_draw_in_the_order_props_draws_the_props`; P7 |
| E8 | The cost (A10, A11, A21). On the desktop, a frame of the City renders with at most 1.7 ms more of the CPU than on `main` by day, and 5.3 ms more at night, in Movie Maker's render times (P15); a row of its props shows within 1.8 ms (P17); the fade takes at most 46 µs a frame (P14); GUT within about 10% of `main`'s time (P6). On the Fold4, IP's informal check reads the City's frame rate, not a blocker (IP :203, `plan.md` §10): by day on the APK, and at night through the Web build in its Chrome; if it drops, §5.6 says what to change | §5.6; P6, P14, P15, P17; E9 |
| E9 | Manual, on the Web in Chrome and Firefox and on both of the Fold4's screens, in the City, not its tutorial (§6.4), by day and at night: the wheels turn forward at every speed and stop with the car; no building stands in another or on the road; a building over the car fades, and comes back as the car leaves it; nothing flickers; no error. The Fold4's frame rate is read, not required (E8) | §6.4: the Web on each PR's build, with videos (P18); the Fold4 is the owner's |
| E10 | Docs (A14). PR 1: `plan.md` §5.3's line on the car. PR 3: `docs/VISUALS.md` replaces this plan, with its row in `docs/README.md`; `AGENTS.md`'s IDs and state; IP's M7 notes | Review |
| E11 | All five required checks are green on each PR, with §4's counts, and `smoke.sh` prints no error line. Each negative case makes the tests it names fail (§6.2), and the warnings check finds no new warning (§6.3) | PR checks; §6.2 and §6.3, run locally with Godot 4.7.2 on each PR's head |
| E12 | Streets (A16; Q2). A lot with a side on a road tile's side, not just a corner, shows its prop at `PropDef.street_density`, and the others at `density`; −1, the default, is `density`'s, and only an area with a street density looks for streets. A see-through prop isn't left out where its frame touches the road: its box's base lies in its lot, so never on the road, and `validate()` rejects one that isn't an upright box whose base fits its lot | `test_prop_layout.gd`: `test_lots_by_a_street_take_its_street_density_and_the_others_its_density` (*street*), `test_see_through_props_rise_over_the_road_behind_them_but_never_stand_on_it` (*rise*); *contract*; `test_prop_art.gd`'s sums |
| E13 | The fade (A17–A20; Q2). A see-through prop in front of the car's body, or of a sprite that a legend stood on `Props`, shows `PROP_SEE_THROUGH`, 0.2, of itself where their rects meet, and comes back whole as they part by `PROP_FADE_PX`, 48 px, across and down together, or as the actor comes that far in front of it; at the tie it changes little. Its silhouette and glows fade with it. What doesn't show, by its visibility, its alpha or its scale, is no actor. A sprite back from the pool shows whole | `test_prop_scatter.gd`: `test_see_through_props_fade_where_they_would_hide_the_car_or_a_legends_sprite` (*fade*); `test_see_through.gd`'s three; `test_car_controller.gd`: `test_its_body_rect_is_where_its_body_shows_however_a_disaster_moves_and_scales_it` (*body rect*); `test_prop_pool.gd`: `test_a_released_sprite_shows_the_next_prop` (*pool*) |

---

## 2. Review findings

M5 drew the car and the props (docs/M5.md §5.6, §5.7), as the summary above describes them. Nothing since has changed either: DN lit them and gave them shadows (docs/DAYNIGHT.md), and PL changes neither. **High:** what the owner asked for can't show, or shows wrong. **Medium:** fragile, or missing from the tests. **Low:** clarity, cost or polish. Line numbers are `main`'s, at 81f22e3, unless they say otherwise.

### High

| # | Finding | Evidence | Fix |
|---|---|---|---|
| A1 | The wheels can't turn | Each axle's wheels are one ink box across the car, 3 px high (`make_car.gd`:35–36), alike in every frame of a one-row sheet (:61). `CarController` picks only the heading's frame (`car_controller.gd`:67), so at speed the car slides | **Δ docs/M5.md §5.7:** each wheel a cylinder with a hub and a marked quarter, a row of the sheet for each of 4 phases, and the controller shows the row of the tiles it has driven (§5.1; E1, E2) |
| A2 | The City is sparse | The building takes 0.01 of the ground cells, and the City's props 0.045 (`make_props.gd`:23–30). A 360 × 640 view shows 3.07 buildings on average, 9 at most, and 3% of views none (P1) | Its building on 0.35 of the City's lots, and 0.6 of those by a street (Q2, §5.3, §5.8; E5) |
| A3 | Buildings stand in each other, and more would stand in more | The building's base is a 40 × 20 px diamond, its front corner on the foot (`make_props.gd`:343–345, `_box()` :543); a ground cell's is 32 × 16. Two bases overlap when their feet are within \|dx\|/40 + \|dy\|/20 < 1: every pair of cells side by side or corner to corner. On `main` 8.3% of the City's buildings have such a neighbour; at 0.3 a cell 92% would (P12) | **Δ docs/M5.md §5.6:** lots (§5.4): a building takes 2 × 2 cells, so the nearest two can stand is two cells apart (E4, E5) |
| A16 | No building can stand by a street | `main` leaves out each prop whose frame would touch a road tile's diamond (`prop_layout.gd`'s `touches_road()`), and a building's does from every lot by a street: at 0.35 and 0.6, two roads of 100 rows show 3,256 buildings with the street density or without, all inside (P13). Q2 moves them closer to the streets | `PropDef.see_through`: such a prop may rise over the road behind it, and `validate()` holds it to an upright box whose base lies in its lot, so it never stands on the road: 4,951 (§5.9; E5, E12) |
| A17 | Buildings by a street would hide the car | The car drives on the road, behind the buildings whose frames rise over it: in 272 of 400 views of the City (68%), a building's frame stands over the car's body (P13) | Q2: the fade. A see-through prop shows 0.2 of itself where it would hide the car, as the tunnel does (docs/M4.md K5), and comes back as they part (§5.9; E13) |

### Medium

| # | Finding | Evidence | Fix |
|---|---|---|---|
| A4 | The sheet's users read only its first row | `double()` cuts `Rect2(FRAME_SIZE.x * _body.frame, 0, …)` (`car_controller.gd`:50); `body_frame()` returns `_body.frame` (:60–61), which with rows counts across them; `Shadows` cuts its outlines from the first row (`shadows.gd`:201–206) | The double cuts at `frame_coords * FRAME_SIZE`, `body_frame()` returns `frame_coords.x`, and the wreck shows the first row. Each row has the first's outline, so the shadow fits every phase (§5.2; E3) |
| A5 | The density contract is per cell | "An area's densities add up to 1 at most, the chance that a ground cell shows a prop" (docs/M5.md §5.6, :102; `area_def.gd`:51–52), and `_valid_props()` adds up every prop's (`prop_scatter.gd`:190, :196) | **Δ docs/M5.md §5.6:** a prop's density is the chance that a lot of its size shows it, and each size's densities, and its street densities, add up to 1 at most, apart; `validate()` rejects a lot that doesn't divide a tile (§5.4, §5.8; E4) |
| A6 | Lots must move nothing else | Rural's, the Meadows', the Village's and the Desert's props all take one cell. Each seed's look is where they stand, and `test_a_seed_shows_the_same_props_however_the_car_got_there` holds it | A lot of one cell has its cell's own hash, and one-cell props take `main`'s loop, skipping only the cells that a larger lot took; only an area with a street density looks for streets. The other areas place the same 27,590 props, in the same order (P2, §5.4; E6) |
| A7 | GUT's time grows with the City's props | `simulate()` steps every node of the tree each frame, so DN held its shadows and lamps as internal children, which it skips (docs/DAYNIGHT.md C20). The lots took the suite from 91 s to 118 s (P6) | `PropScatter`'s pool holds its sprites as internal children of `Props`: 86 s (§5.5; E7) |
| A8 | Internal children need `true` | On an internal node, `get_index()` is an error, "Node is internal. Can't get index with 'include_internal' being false.", and returns −1; `get_children()` and `get_child_count()` leave them out. `Lamps` orders its silhouettes by `get_index()` (`lamps.gd`:114), and three tests count `Props`' children | `get_index(true)`, `get_children(true)` and `get_child_count(true)` (§5.5). Without the first, the whole suite logged 145,692 errors and ran out of memory (N19; E7) |
| A15 | PL's Marfa lights fit their tyre tracks to `main`'s back wheels | #88 (b0502ea) draws two grooves `GAUGE`, 9 px, each side of the car's middle, up from frame 0's bottom row, with sand between them (`marfa_lights.gd`:29–36, `.tscn`:38). `main`'s rear axle box fills that row from −10 to 9 px; PR 1's wheels from −9 to 7, so the grooves at −10, 8 and 9 hang off it, and #88's tracks test fails 3 asserts, such as "x 8: under the car" (P11, N34) | The later of PR 1 and #88, in a commit of its own, sets `GAUGE` to 7 and the sand's `emission_rect_extents` to `Vector2(7, 1)`, and draws `tracks.png` again with `make_legends.gd`. The merges then pass the five checks (§4.2, P11, N35) |
| A18 | What the fade must see | `Props`' own children are the car, a legend's standing parts and the car's double (A9). A legend hides the car by its alpha (`legend.gd`:79) and shows its double (:72); its parts wait hidden by their alpha or their scale (:8); a disaster may change the car's scale, `modulate` and rotation (docs/M3.md J3, docs/M4.md K19) | `actor_rect()`: the car's `body_rect()`, through its transform and its body's; a sprite's rect, through its transform; nothing for what is hidden, transparent or scaled to nothing (§5.9; E13) |
| A19 | A building's lights would stay over it | At night `Lamps` draws each building's silhouette over it, and its windows' glows as children of the silhouette (`lamps.gd`:122–126) | The fade sets the silhouette's alpha with the prop's, and the glows take it (§5.9; E13) |

### Low

| # | Finding | Evidence | Fix |
|---|---|---|---|
| A9 | Which draws first, the car or a prop on its y, depended on when the prop was made | Godot's y-sort draws a tie in the order of the children, internal ones included. `main.gd` adds the car to `Props` once the first rows show (:156), and a legend its double (`legend.gd`:72–74), so props made before them drew under them and those made after over them | Internal children in front, `INTERNAL_MODE_FRONT`: every prop draws before the car at a tie (§5.5; E7) |
| A10 | `Lamps` inserts each silhouette at its place, which costs more with more props | `bsearch_custom()`, `insert()` and `move_child()` (`lamps.gd`:70–72), linear in the silhouettes: over 100 rows of the City, 67–87 ms at 0.3 a lot, against 19 ms on `main` (P3) | None now: a row shows within 1.8 ms (P17). §9 if the Fold4 shows it |
| A11 | Each row of the City costs more | A row takes 1.45 ms to show on average and 1.73 at most, against 0.90 on `main`, and 0.27 ms to hide, against 0.10 (P17). `PropLayout.row()` takes 0.79 ms in the City at 0.3 a lot, against 0.60–0.62 on `main` (P4) | None by default: at the speed cap, 7 tiles a second, a row shows and another hides about every 8.6 frames at 60 fps, together within 2.1 ms (E8, §5.6) |
| A12 | The City's street props thin, and move | Buildings take their lots' cells, so the City shows 35–42% fewer trees, lamps, bins, hydrants and traffic lights (P16). `pick()` gives each prop the next share of a cell's hash, in the list's order (`prop_layout.gd`:115–121), so without the building's share each street prop's starts lower, and a free cell may show another prop than on `main` | None by default (Q4): their densities × 1.6 would bring their numbers back. No test holds the City's street props where they stood |
| A13 | Four phases can alias | A true wheel of 2.5 px would turn 5.8 times a tile: at the cap, 2.7 phases a physics frame, which reads as backwards. Physics runs at 60 Hz without interpolation, and the Fold4's screen at up to 120 Hz (IP §4 M7, :177); a device that draws fewer frames shows only some physics frames, as Chrome on software GL at 18.7–21 a second at night (P10) | Once a tile: at most 0.47 of a phase a physics frame. A frame drawn rolls them a phase at most and drops the rest of its drive, so they never turn back, and stand with the car (§5.1; E1); the Fold4 checks it (E9) |
| A14 | The docs describe one row and one cell a prop | docs/M5.md §5.6 (:102) and §5.7 (:106); `plan.md` §5.3 (:211): "Car: 16 directions at about 32×24 px, plus a crash frame." | PR 1 changes `plan.md`'s line, and PR 3 writes `docs/VISUALS.md` (§5.7; E10) |
| A20 | The pool would show a faded sprite again | `PropPool.acquire()` sets a reused sprite's texture, region and frame, not its `modulate` (`prop_pool.gd`:30–36), so a building released faded would show the next prop faded | `acquire()` sets `modulate` to white (§5.9; E13) |
| A21 | The City's views cost more | 80.7 buildings a view against 3.07, 19,245 nodes against 3,827 (P13), each building's windows lit at night: a frame takes 1.4–1.7 ms more of the CPU by day and 4.8–5.3 ms at night on the desktop (P15). In software GL, Chrome's frames a second fall from 23 to 13 at 22:00 (P18) | None by default: E8 reads the Fold4's frame rate, and §5.6 says what to change if it drops |

---

## 3. Decisions

The owner took the defaults of Q1 and Q3–Q6, and answered Q2, on 2026-11-15 (#85). This plan and the PRs follow the answers.

| # | Question | Answer | Not taken |
|---|---|---|---|
| Q1 | What does "the wheels turn" mean? | **They roll: they spin as the car drives, with its speed, and stand with it (§5.1)** | They steer as well: each heading would need frames for each angle of the front wheels and each phase (§9) |
| Q2 | How dense? | **"keep density between 35% and 60%, and move buildings closer to the streets. If the building overlaps the camera view of the car, then make them more transparent similar to the tunnel view." 0.35 of the City's lots, 0.6 of those by a street; a see-through building may rise over the road behind it, and fades to 0.2 over the car (§5.8, §5.9). A view shows 80.7 on average, 63 to 100 (P13)** | The default, 0.3 of the lots, none by a street: 17.8 a view, 33 at most (P1) |
| Q3 | New art for the buildings? | **No: the City's one building** | Two or three buildings of the same lot (§9) |
| Q4 | Do the City's street props keep their densities? | **Yes: they thin by 35–42%, as buildings take their cells (A12)** | × 1.6, which places about as many as on `main` (P16) |
| Q5 | Which areas? | **The City's building only** | The Village's houses, Rural's barns and windmills and the Meadows' ponds, which stand in each other's base 9.6%, 7.4% and 1.5% of the time (P12, §9) |
| Q6 | How do the PRs land? | **A stack of two, the wheels then the City, then the docs from `main` once the second has merged (§4)** | Two PRs on `vis/plan`: PR 2 now changes three of PR 1's files (§4.3), so the second to merge would have to merge `main` and resolve them |

---

## 4. Work breakdown

Three PRs after this plan's (Q6): PR 1, the wheels, with base `vis/plan`; PR 2, the City, with base PR 1's branch; then PR 3, the docs, from `main` once PR 2 has merged (§4.4). Each leaves CI green (E11).

```
plan PR ──▶ PR 1 the wheels (A1, A4, A13) ──▶ PR 2 the City (A2, A3, A5–A12, A16–A21)
 (docs)                                             │
                                                    ▼  once PR 2 has merged, from main
                                                  PR 3 docs (A14)
```

- **One PR for each of the owner's two asks**, so each can be reviewed, tried and stopped on its own. PR 2 adds to three of PR 1's files: the car's body rect and the fade's tuning (§4.3).
- **The wheels first.** They change only the car. The City changes how every area lays its props, and its review needs A6's proof that nothing else moved.
- **Stacked** (`AGENTS.md` §4): each is checked on what it lands on, and PR 2's head has the prototype's code (§6.1).
- **The docs last**, once both are on `main` (docs/agents/planning.md §6).

### 4.1 Building the PRs from the prototype

Both branches are built, and §6 checked them. This is how they were made, for a rebuild if `main` moves on first. PR 1 applies its files' part of the difference between `main` at 81f22e3 and 4d607d7, the prototype before Q2's answer. PR 2 checks out its own files, and three of PR 1's, from a6b88fb, the prototype's head, then adds the review's fix (§4.6): its head has a6b88fb's code but for `_valid_props()`'s sums, and PR 1's line in `plan.md`.

1. Fetch the branches, and create and fill PR 1's:
   ```bash
   git fetch origin main '+refs/heads/vis/*:refs/remotes/origin/vis/*'
   git switch -c vis/1-wheels origin/vis/plan
   git diff --binary 81f22e3 4d607d7 -- car/car.tscn car/car_controller.gd config/tuning.gd \
     tools/art/make_car.gd assets/car/car.png tests/unit/test_car_art.gd \
     tests/unit/test_car_controller.gd tests/unit/test_shadows.gd | git apply --index
   ```
   `--binary`, as `car.png` changes. PR 2 starts with `git switch -c vis/2-city-lots vis/1-wheels`, then `git checkout a6b88fb --` and §4.3's 21 files, which stages them, the 4 new ones too; its fixes are `git cherry-pick 93a55e3 6ef331f`. If `main` has moved on and changed the same lines, use `git apply --3way --index`, and keep both. For PR 2, apply so `git diff 81f22e3 a6b88fb` of its own 18 files, and `git diff 4d607d7 a6b88fb` of the 3 it shares with PR 1, `car_controller.gd`, `tuning.gd` and `test_car_controller.gd`: the second alone would miss the lots, which 4d607d7 has already.
2. Run `tools/ci/import.sh`, then the PR's art script, `godot --headless -s tools/art/make_car.gd` or `make_props.gd`, then `import.sh` again: `git diff --exit-code` must print nothing, as each draws the same bytes on every run (P8). In a new worktree the first import is needed: before it, `make_car.gd` fails, "Identifier "CarController" not declared".
3. For PR 1, change `plan.md`'s line (§4.2).
4. Leave `VISUALS_PLAN.md` alone on the PRs' branches: it changes only on `vis/plan`, which is merged up (§4.5). A change to it on a PR's branch would make the merge of `main` after the plan's squash an add/add conflict.
5. Run §6.1's checks, §6.2's negative cases with the whole suite on the PR's head, and §6.3's warnings, and compare the counts with the PR's "Expect" line. Run the cases again if a later commit changes more than docs (docs/agents/planning.md §4).
6. Have a model of another family review it (`AGENTS.md` §5). Then commit, push, and open the PR with its base.

### 4.2 PR 1: Car: wheels that turn as it drives **Δ A1, A4, A13**

Branch `vis/1-wheels`, from `vis/plan`, at 873a792: `car: turn the wheels as the car drives (VIS PR 1)`.

| Area | Files |
|---|---|
| Car | `car/car_controller.gd`: `PHASES`, `_driven`, `_rolled` and `_phase`; `_process()` rolls the wheels (§5.1); `_update_view()` sets `frame_coords`, the wreck's in the first row; `double()` cuts the body's frame from its row, and `body_frame()` returns its column (§5.2). `car/car.tscn`: `vframes = 4` |
| Config | `config/tuning.gd`: `WHEEL_ROLL_TILES` |
| Art | `tools/art/make_car.gd`: the wheels, with `_splat_wheel()`, `_wheel_color()` and `_plot()`, a row for each phase, and the wreck's colours (§5.1). `assets/car/car.png`: 612 × 112 px, 13,587 B, where `main`'s is 3,072 |
| Docs | `plan.md` §5.3's line on the car (:211) **Δ A14**: "Car: 16 directions at 36×28 px, each with its wheels in 4 phases of a turn, plus a crash frame." |
| Tests | `test_car_art.gd`: the sheet's size and rows, and 2 new (E2). `test_car_controller.gd`: 4 new (E1); the step, frame, double and wreck tests read `frame_coords`, and the wreck's rolls the wheels first (E3). `test_shadows.gd`: the car's shadow in a phase past the first (E3) |

9 files, +442 −48. Expect, on `vis/plan`: `check_scripts: loaded 160 scripts`, as on `main`; `GUT: 589 tests passed`, 6 more than `main`'s, in 77 test scripts, with 427,317 asserts, 456 more; `autopilot: tile 165, turns 35, area rural`, as on `main`. Negative cases N1–N8 and N24–N33.

**With #88 (A15).** The later of PR 1 and #88, after its merge of `main` (§4.5), in a commit of its own: `GAUGE` 7 in `disasters/legends/marfa_lights.gd`, and the sand's `emission_rect_extents` `Vector2(7, 1)` in its `.tscn`; then `tools/art/make_legends.gd` and `import.sh`, which draw `tracks.png` again. Not in the merge, which a GitHub stack's replay drops (§4.5). On #88's head, PR 1's files and these three passed 643 tests in 83 scripts, #88's 637 and 6 more, with 429,851 asserts, in 100.1 s, and `main`'s smoke line (P11, N34, N35).

**Acceptance:** E1–E3, E11, and E9's and E10's parts for PR 1.

### 4.3 PR 2: Props: lots, streets and see-through buildings **Δ A2, A3, A5–A12, A16–A21**

Branch `vis/2-city-lots`, from `vis/1-wheels`, at 6ef331f: 1d5aa59, `props: line the city's streets with buildings, see-through over the car (VIS PR 2)`, and the reviews' fixes, 93a55e3, `props: add up densities as floats, not float32 (VIS PR 2)`, and 6ef331f, `props: fade for no sprite hidden by its scale, and allow for rounding at 1 (VIS PR 2)` (§4.6).

| Area | Files |
|---|---|
| Areas | `areas/prop_def.gd`: `lot`, `street_density`, `see_through` and `chance()`, and `validate()`'s rules (§5.4, §5.8, §5.9). `areas/area_def.gd`: the densities' doc. `areas/props/city/building.tres`: lot 2, density 0.35, street density 0.6, see-through |
| Art | `tools/art/make_props.gd`: `LOTS`, `STREETS` and `SEE_THROUGH`, written to each `.tres` that differs from the default, and the building's density. It draws the same sheets as on `main` (P8) |
| World | `world/prop_layout.gd`: lots (§5.4), streets (§5.8), and see-through props past `touches_road()` (§5.9). `world/see_through.gd`, new: `SeeThrough.opacity()` and `rows()` (§5.9). `world/prop_scatter.gd`: the pool's sprites internal and in front (A7, A9); `_valid_props()` per size, with the street densities, in floats, with `past_1()` (A5); `_fade()` and `actor_rect()`, which skips a sprite scaled to nothing (§5.9). `world/prop_pool.gd`: `acquire()` resets `modulate` (A20). `world/lamps.gd`: `get_index(true)` (A8) |
| Car | `car/car_controller.gd`: `body_rect()` (A18). `config/tuning.gd`: `PROP_SEE_THROUGH` and `PROP_FADE_PX` |
| Tests | `test_prop_layout.gd`: 6 new (E4–E6, E12), and the river test lays see-through props too. `test_prop_scatter.gd`: 3 new (E4, E7, E13); the rows test counts internal children, and the contract test adds a lot of 3, a prop of 2 × 2, street densities and see-through props that break it (E4, E12). `test_see_through.gd`, new: 3 (E13). `test_car_controller.gd`: *body rect*. `test_prop_pool.gd`: *pool*. `test_prop_art.gd`: each size's sums. `test_lamps.gd` and `tests/integration/test_area_start.gd`: internal children (A8) |

21 files, 4 of them new, 2 of those `.uid`s; +1049 −87. Expect, on `vis/1-wheels`: `check_scripts: loaded 162 scripts`; `GUT: 602 tests passed`, 13 more than PR 1's, in 78 test scripts, with 429,384 asserts, 2,067 more; `main`'s smoke line (E6). Negative cases N9–N23 and N36–N67, and PR 1's on its head too.

**Acceptance:** E4–E8, E11–E13, and E9's part for PR 2.

### 4.4 PR 3: Docs: docs/VISUALS.md

Branch `vis/3-docs`, from `main` once PR 2 has merged (docs/agents/planning.md §6). Not before: it rewrites cites in PRs 1 and 2's files, so made from PR 2's branch it would carry other versions of them, and its merge of `main` after PR 2's squash would be an add/add conflict (docs/agents/stacks.md step 2).

| Area | Files |
|---|---|
| Docs | `docs/VISUALS.md`, new, at most about 15 KB, which replaces this plan (§5.7), and its row in `docs/README.md`. `VISUALS_PLAN.md`, deleted, and each cite of it in code and tests rewritten as `docs/VISUALS.md`, as long, so no line reflows |
| | docs/M5.md §5.6 (:102) and §5.7 (:106) each end with "now …" and the A# that changed them, as its L2 does for docs/ROADGEN.md R6 |
| | IP §4 M7: the device checks still open, with E9 (:178), and §9's notes. `AGENTS.md`: the IDs (:18), with A# (VISUALS), and the state (:20) |

No code, so PR 2's counts. Its owner actions end with the branches (§7). **Acceptance:** E10, E11.

### 4.5 Landing (Q6)

This plan's PR targets `main`, PR 1 `vis/plan`, and PR 2 `vis/1-wheels`. Only a PR whose base is `main` merges (`AGENTS.md` §5), so the owner squashes the plan, PR 1, then PR 2; PR 3 then starts from `main`. If #95 merges first, its rules say who lands each. The plan changes only on `vis/plan` until its PR merges. After that each PR keeps its results and its review fixes in its body, and PR 2 carries the plan's final sync: its status, §4.6's rows, the counts and the device results (docs/agents/planning.md §5). PR 3 deletes it.

A review fix goes on the branch of the PR that adds the file, then merges up (`AGENTS.md` §4): PR 2's four new files on PR 2's, and a fix to a file that both change on the branch of the PR whose part it fixes. The plan's fixes go on `vis/plan`, and merge into PR 1's branch with `git merge --no-ff --no-edit`, then into PR 2's.

After each squash, retarget the next PR to `main` before anyone deletes the merged branch: deleting it closes each open PR based on it, unless GitHub has retargeted it first (docs/agents/stacks.md step 6). Then, on the next PR's branch (stacks.md step 5):

```bash
gh pr edit <next PR> --base main       # unless GitHub retargeted it
git fetch origin main '+refs/heads/vis/*:refs/remotes/origin/vis/*'
git switch <next PR's branch>
git merge origin/<merged PR's branch>  # its last fixes, in case one wasn't merged up yet
git merge origin/main                  # the squash
git diff --name-only origin/main       # must list only the next PR's files
git push
```

Each branch merged the one before it, so its merge of `main` after that one's squash changes no file. PR 1's, ee73241, was clean. PR 2's, 60d3e18, conflicted in `car_controller.gd`: its `body_rect()` follows the line of `body_frame()` that PR 1 changes, so after #93's squash both sides changed those lines (stacks.md step 3). `-X ours` kept the branch's side, as #56 did (stacks.md step 7), and the tree stayed 0e1c770's. PL's PRs (#81–#83, #86–#91, #96) change `config/tuning.gd` and `plan.md` at other lines, EG's plan (#84) `plan.md`, and #95 `AGENTS.md`, `POOLS_PLAN.md`, `docs/agents/` and `tools/agent/`: each merges cleanly with either PR's head (P11). But a clean merge can still fail a test: the later of PR 1 and #88 narrows the tracks (A15), so run the five checks on each merge. EG's PR 3, not yet built, would change `make_props.gd`, as PR 2 does. Simulate each merge with `git merge-tree --write-tree` first. A merge-up that changes no file in the PR's diff may start no Copilot review: request one with `gh pr edit <n> --add-reviewer @copilot`. If the owner links the PRs as a GitHub stack instead, it retargets them by itself, and replays each branch's own commits without its merges (stacks.md step 7).

### 4.6 Review fixes

Fixes found while the prototype was built, by the internal reviews (§4.7) and by Copilot's, each with its tests (short names in §6.2) and its negative case.

| PR | Change | Tests | Negative case |
|---|---|---|---|
| 2 | A6: 5f02ebf hashed each cell as a lot of its own, 0.12 ms more a row in every area. 2fe01e1 lays one-cell props in `main`'s loop; e3fe5b7 checks it | *as before* | N15, N16 |
| 2 | A7: the lots took GUT from 91 s to 118 s. 2fe01e1 holds the props as internal children: 86 s, and the same frames (P6, P7) | *rows* | N17 |
| 2 | A8: the Lamps tests held the props as ordinary children, where both indices agree. 4baf203 holds them as `PropScatter` does | *order* | N19 |
| 1 | A4: the controller's wreck test crashed in the first phase. 4baf203 rolls the wheels first | *wreck*; `test_crash.gd` | N8 |
| 1 | E2: nothing caught wheels that turn backwards. 51f45d6 follows each hub's mark | *forward* | N2 |
| 2 | A9: which drew first at a tie depended on when the prop was made. 910cd24 checks that every prop goes before the car | *ties* | N17, N18 |
| 2 | A3: nothing named the City's building: on one cell at 0.3 it passed every test, 11,742 standing in each other. fc17a3e checks the City's own | *City* | N20, N21 |
| 2 | E4: no test laid a lot of 4 × 4. 6e75911 adds one to both lot tests | *lots* | N22, N23 |
| 1 | A13 (§4.7): below 30 fps a frame could turn the wheels two phases, e462135's fix then turned standing wheels and a faster car's less often, and *drawn* passed `>` for `>=`. 28d0414 and 04bddda: a frame rolls them by its drive, a phase at most, and drops the rest (§5.1) | *drawn*, *stands*, *6 fps* | N24–N26, N28–N33 |
| 1 | E2 (§4.7): the roll test passed a hub with no mark, its angle NAN. be340a8 wants each mark | *forward* | N27, N3 |
| 1, 2 | Copilot on #85: VIS's findings are A#, as W# is EG's, and every case runs with the whole suite; the Fold4's frame rate is read, not required (09eb772, IP :203); its run in the City comes after the tutorial (704cdf4) | | None: words |
| 1 | A15: #88's tracks hang off PR 1's wheels. The later sets the gauge to 7, in a commit of its own, which a stack's replay keeps (Copilot on 2a920a2) | #88's tracks and sand | N34, N35 |
| 2 | Q2 (a7ab941): streets, see-through buildings and the fade (A16–A21) | *street*, *rise*, *river*, *City*, *fade*, `test_see_through.gd`'s 3, *body rect*, *pool*, *contract*, *sums* | N36–N62 |
| 2 | The editor's warnings (§6.3): the fade test's `double` shadowed `GutTest.double()`. a6b88fb names it `stand_in` | *fade* | None: a name |
| 2 | The street test gave only lots of 2 × 2 a street density. a6b88fb adds a one-cell prop at 0.2 and 0.5 | *street* | N63 |
| 2 | This plan's rewrite: the river test's see-through half had no negative case | *river* | N64 |
| 2 | The PRs' review (§4.7): `_valid_props()` added each size's densities in a `Vector2`, whose 32-bit floats took ten of 0.1 to 1.0000001, so the tenth prop was an error. 93a55e3 adds them in floats, as `main` did | *add up* | N65 |
| 2 | Copilot on 93a55e3: floats add 0.33, 0.56 and 0.11 up to 1.0000000000000002, so the third was an error too. 6ef331f's `past_1()` allows for the rounding, and *sums* uses it | *add up* | N66 |
| 2 | Copilot on 93a55e3: Node2D stores a zero scale as CMP_EPSILON, so a legend's part that waits at a scale of zero, as the Witch's Hex's pumpkin does, faded a building over it. 6ef331f takes a sprite under 1e-4 as hidden, as `ufo.gd`'s `SLIVER` does | *fade* | N67 |

### 4.7 Internal review

gpt-6.1-sol, a model of another family, reviewed this plan at 808b210 and the prototype at 6e75911 (`rubber-duck`), then re-checked the wheels' fixes three times, read-only, with Python probes of up to 400,000 seeded frames. Its eleven findings were all real; 704cdf4's §4.7 gives each with its check. Below 30 fps the wheels could turn two phases a drawn frame, turn while the car stood, or turn a faster car's less often (its rows 1, 5, 6, 8); the roll test passed a hub without its mark (2); *drawn* passed `>` for `>=` (10); five were words (3, 4, 7, 9, 11). §4.6 has the fixes.

For Q2, gpt-6.1-sol (`code-review`) read a7ab941's diff from 4d607d7: the fade, the streets, `validate()`'s fit, the cost and the tests. It found no significant issue. The editor's warnings and a re-read of the street test found §4.6's next two rows.

For the PRs, gpt-6.1-sol read 873a792's and 1d5aa59's diffs (`code-review`) and this plan's draft (`rubber-duck`). The code review found one issue, real: §4.6's last row. The plan's review found two, both real. §4.1 rebuilt PR 2 with `git diff 4d607d7 a6b88fb` alone, which misses the lots, as 4d607d7 has them already. And N20, the building on one cell, still see-through, broke `validate()`'s fit, so 88 tests failed, not *City* alone: N20 now drops `see_through` too (§6.2). Asked whether 93a55e3 left another sum in 32 bits, or a way for its test to pass with a broken sum, it found no issue. Copilot's review of 93a55e3 found two bugs, §4.6's last two rows; gpt-6.1-sol read their fix, 6ef331f, and found no issue. Last, it checked P18 and §5.6 against the Web runs, and P11's merges with #95 and #96: one finding, real, as P11 named older heads for the new PRs.

---

## 5. Design

### 5.1 The wheels (A1, A13; Q1; E1, E2) **Δ docs/M5.md §5.7**

docs/M5.md §5.7 made the car's sheet one row of 17 frames of 36 × 28 px: 16 headings, clockwise from straight up, and the wreck. **Δ** The sheet has a row for each of `CarController.PHASES`, 4, phases of its wheels' turn, so it is 612 × 112 px. Row k has every frame, each with its wheels a quarter turn on from row k − 1 and with the first row's outline: only the wheels' faces and treads differ.

**The wheels.** `make_car.gd` drew each axle's wheels as one ink box across the car (:35–36). It now splats each of the four into the depth buffer as a cylinder, as it splats the boxes: 2.5 px in radius, 0.09 tile ahead of and behind the car's middle, from 0.07 to 0.1 tile out, where the body reaches 0.09. Its tyre is ink, and its outer face's hub, within 0.6 of the radius, "asphalt light". A quarter of the wheel is marked, as if painted across it: "white" on the hub, and "asphalt" on the tread, which shows from ahead and behind. Row k's mark is turned k quarter turns from the top towards the front, as a wheel's top moves forward as it rolls: seen side on, clockwise when the car faces right. `test_seen_side_on_the_wheels_roll_forward` (*forward*) finds the mark about each nearer hub in each row, wants it to show, and to turn forward by 22.5° to 157.5° from each row to the next: about a quarter turn, and never back (N2, N27). `test_each_phase_turns_the_wheels_in_the_same_outline` checks each frame's outline in every row against the first's: seen side on or at a slant all four phases differ, and from ahead or behind, where only the treads' marks show, more than one (N1, N3). Every row draws the wreck alike, in phase 0, with the wreck's colours for the wheels', none of them ink, so the smoke over the wreck still shows. The sheet has only the palette's colours (`test_area_art.gd`), and the script draws the same bytes on every run, in 5.2–5.4 s, where `main`'s took 1.46 s (P8).

**The roll.** `CarController` counts the tiles that the car drives, rolls its wheels by them once a drawn frame, and shows the next row each `WHEEL_ROLL_TILES`:

```gdscript
func _physics_process(delta: float) -> void:
	sim.step(delta, input.steer())
	_driven += sim.speed * delta
	_update_view()

## Once a drawn frame, after its physics frames.
func _process(_delta: float) -> void:
	var drive := minf(_driven, Tuning.WHEEL_ROLL_TILES)
	_driven = 0.0
	if drive <= 0.0:
		return
	_rolled += drive
	if _rolled >= Tuning.WHEEL_ROLL_TILES:
		_rolled -= Tuning.WHEEL_ROLL_TILES
		_phase = posmod(_phase + 1, PHASES)
		_update_view()
```

and `_update_view()` sets `_body.frame_coords = Vector2i(frame(sim.forward()), _phase)`, or `Vector2i(WRECK_FRAME, 0)` after a crash.

- **Distance, not time.** `sim.speed` is in tiles a second, so the wheels turn faster as the car speeds up, and stand when it stands: before the run starts, and as a disaster brakes it (N4, N5). After each drawn frame `_driven` is 0 and `_rolled` at most a phase, so neither grows and loses precision.
- **Once a tile (A13).** `WHEEL_ROLL_TILES` is 0.25. A true wheel of 2.5 px would turn 5.8 times a tile, `Iso.WIDTH_PX`, 90.5 px a tile across the screen, over its 15.7 px round: at `GLOBAL_SPEED_CAP`, 7 tiles a second, 2.7 phases a physics frame, which four phases show as 1.3 back. Once a tile, it's 0.27 of a phase a physics frame at `BASE_TOP_SPEED`, 4, and 0.47 at the cap. *roll* drives 4 s with the autopilot, then brakes to a stop for a disaster: never two phases in a frame, nor back, and a phase each 0.25 tile within one.
- **A phase a drawn frame at most (A13).** The engine runs the physics frames that are due, then `_process()`, then draws, so a device that draws fewer than 30 frames a second shows only some physics frames: at the cap, more than a phase apart. Chrome on software GL drew 18.7–21 a second at night (P10). Two phases at once would be a half turn, which reads as back as well as forward. So `_process()` adds the drive since the last drawn frame to `_rolled`, but a phase at most, and drops the rest; `-=` takes a turn off exactly. Where each drawn frame comes after 2 physics frames or fewer, as at 30 fps and more with `Engine.time_scale` at 1, which nothing changes, nothing is dropped. Otherwise the wheels turn on each frame that drives a phase or more, and in all a phase each `WHEEL_ROLL_TILES` of the frames' drives, each counted up to a phase. So however unevenly the frames come, a faster car's wheels turn no less often; a slow device turns them slower than they roll, but never back; and never once the car stands. Where a sum of floats rounds up to two phases, one waits in `_rolled` for the car to drive on. *drawn* draws 120 frames at 5 speeds, 1.5 to 7 tiles a second, and 9 cadences of 1 to 6 physics frames a drawn frame, uneven ones too: a phase at most, as many as the drives count within one, a turn on each frame that drives a phase, and no fewer at a higher speed. *stands* stops the car for two frames after each frame it drives; *6 fps* drives the body with the autopilot, then brakes it to a stop. Each calls `_physics_process()` for the physics frames due and then `_process()`, in the engine's order, where GUT's `simulate()` calls `_process()` first (N24–N26, N28–N33).
- **Visual only.** Nothing reads `_driven`, `_rolled`, `_phase` or the row but the view and the double (§5.2), and no RNG is drawn, so a seed plays as before. The front wheels don't point into a turn (Q1, §9).

### 5.2 The sheet's users (A4; E3)

Three users of the sheet read only its first row on `main`. Each now reads the body's column and row:

| User | On `main` | Now |
|---|---|---|
| The body | `frame = WRECK_FRAME if crashed else frame(sim.forward())` (`car_controller.gd`:67) | `frame_coords`: the heading's column in the phase's row; after a crash the wreck's column in the first row, whatever the phase (N8) |
| `double()`, which a legend takes in the car's place (docs/M6.md §5.4; `legend.gd`:72) | `Rect2(FRAME_SIZE.x * _body.frame, 0, …)` (:50) | `Rect2(Vector2(_body.frame_coords * FRAME_SIZE), Vector2(FRAME_SIZE))`: what the body shows, its phase included, as a still (N7) |
| `body_frame()`, which `Shadows` shows (`shadows.gd`:136) | `_body.frame` (:60–61) | `_body.frame_coords.x`. `Sprite2D.frame` counts across the rows, so past the first phase it would name a frame past the 17 that `Shadows` cuts from the first row (:201–206): an error each frame, which fails 43 tests (N6) |

So the car's shadow casts the first row's frame of its heading, whatever its phase. That is exact, as every row has the first's outline: `test_the_cars_shadow_follows_its_frame_and_fades_with_it` rolls the wheels past the first phase before it compares them.

### 5.3 The City's density (A2, A12; Q2, Q4; E5)

The City's building takes a lot of 2 × 2 cells: at 0.35 a lot, and 0.6 by a street (§5.8), and see-through (§5.9). `make_props.gd`'s `LOTS`, `STREETS`, `SEE_THROUGH` and `PROPS` give `building.tres` `lot = 2`, `density = 0.35`, `street_density = 0.6` and `see_through = true`. Its other props keep their densities, of a cell each: the tree and the lamp 0.01, the bin 0.006, the hydrant 0.005 and the traffic light 0.004 (Q4).

P13 drove seeds 1–5 for 40 s each in the City with the autopilot, and sampled 400 views of 360 × 640 px:

| The building | Buildings a view | Nodes |
|---|---|---|
| `main`: a cell at 0.01 | 3.07, at most 9 (P1) | 3,827 (P1) |
| The default: a lot of 2 × 2 at 0.3 | 18.27 | 13,382 |
| 0.35, neither by streets nor see-through | 21.59 | 15,204 |
| **Q2: 0.35, 0.6 by a street, see-through** | **80.66, 63 to 100** | **19,245, at most 20,495** |

Q2's views show 26 times `main`'s buildings: a street of them along the road, with blocks behind. About 17% of the lots beside the road are by a street, so about 39% show a building. A view shows 89.4 props on average, and fades 5.46 of them (§5.9). Both of Q2's parts are needed: left out by `touches_road()`, no lot by a street shows a building, so on two roads of 100 rows 3,256 show with the street density or without; see-through, 4,427 without it and 4,951 with it (A16).

P16 counted the props that 150 rows place on seeds 1–4: the City's buildings 1,133 on `main`, 8,760 at the default and 15,008 with Q2's, and its street props 35–42% fewer than on `main`, as buildings take their cells (A12). The other areas place the same props, in the same places and order, as on `main` (A6).

### 5.4 Lots (A3, A5, A6; E4, E6) **Δ docs/M5.md §5.6**

docs/M5.md §5.6 gave each ground cell beside the road one prop or none, by the cell's hash, with the area's densities adding up to 1 at most. **Δ** A prop takes a lot: a square of `PropDef.lot` × `lot` ground cells, 1 by default, aligned with its tile's corner.

- **The contract.** `validate()` rejects a lot that doesn't divide a tile's 4 cells a side: "prop <id>: a lot of 3 cells doesn't divide a tile". A prop's density is the chance that a lot of its size shows it, and each size's densities add up to 1 at most, apart, and so do its street densities (§5.8): `_valid_props()` keeps both sums for each size, in floats, and takes a sum that only rounding puts past 1 as 1, by `past_1()` (*add up*; N65, N66); `test_prop_art.gd` checks each area's (*sums*; N13, N14, N40).
- **Largest first.** `PropLayout.row()` takes each tile of the spread that is neither road nor near a set piece, as before. `by_lot()` sorts the props by the size of their lot, largest first (N23). For each size above 1, the tile's lots of that size, back to front, each pick a prop of their size, or none, by their own hash; a lot of which a larger lot's prop took a cell is skipped (N22). A prop that shows takes its lot's cells, a bit each in the tile's 16-bit `taken`. One left out, as its frame would touch the road and it isn't see-through, takes none, so its cells stay free for props of one cell (N9, N11).
- **The front cell.** A prop stands on the centre of its lot's front cell, the one nearest the bottom of the screen, and its box reaches back over the rest. In a lot of 2 × 2 the foot is 8 px below the lot's centre, at the front corner of the building's 40 × 20 px base (`make_props.gd`'s `_box()`), so the base lies within its lot (§5.9).
- **The hash.** A lot of one cell has its cell's own hash, `cell_hash(props_seed, cell)`. A larger lot hashes its front cell, then mixes in a salt for its size, `LOT_SALT` 0x9E3779B9 times `lot`. Without it, a cell whose lot showed nothing would pick by the same hash, past the lot's densities, and in the City never show a prop of one cell (N12).
- **Cells of one, as on `main` (A6).** Then each of the tile's cells that no larger lot took picks from the props of one cell by its own hash, in `main`'s loop, `b` outer and `a` inner (N10). An area whose props all take one cell and have no street density skips nothing and looks for no street, so it places the same props as on `main`, in the same places and order (N15, N16). The City's take their shares of each hash without the building's, so they stand elsewhere than on `main` (A12).

**Why no two buildings touch (A3).** A ground cell is 32 × 16 px, so cells (p, q) apart stand (16(p − q), 8(p + q)) px apart on the screen. Two of the building's 40 × 20 px bases overlap when |dx| / 40 + |dy| / 20 < 1, which is 0.8 · max(|p|, |q|) < 1: on cells side by side or corner to corner. Lots of 2 × 2 are aligned with the tiles, 4 cells a side, so two buildings' front cells are an even number of cells apart each way, at least 2: 1.6. *City* places the City's own props on two roads of 100 rows: 4,951 buildings, none on a cell next to another's (N20, N21). The lot tests use a block of their own, so they don't depend on the City's tuning.

**Larger lots.** No area uses a lot of 4 × 4, a whole tile. The lot tests place one at 0.2 beside lots of 2 × 2 and props of one cell, so a square takes its tile first; the contract test rejects a lot of 3 (E4). The Village's houses, Rural's barns and windmills and the Meadows' ponds are wider than a cell too, but stand in each other less often (P12): Q5 leaves them as they are (§9).

### 5.5 Internal props (A7–A9; E7)

DN made the sprites of `Shadows` and `Lamps` internal children of their layers: GUT's `simulate()` steps every node of the tree each frame, but not internal children, and those sprites had taken CI's GUT from 98 s to 225 s (docs/DAYNIGHT.md C20). The props' own sprites stayed ordinary children of `Props`, and with lots the suite took 118 s where `main`'s took 91 s (P6). So `PropScatter`'s pool holds them as internal children too, `PropPool.new(layer, Node.INTERNAL_MODE_FRONT)`; `PropPool` already took the mode (`prop_pool.gd`:18). The suite then took 85–91 s, and the City's frames were the same bytes as with ordinary children (P6, P7); with Q2's buildings it takes 97 s locally and 100 s in CI (§6.1).

- **What reads them (A8).** `get_children()` and `get_child_count()` leave internal children out, and `get_index()` on one is an error that returns −1. `Lamps._draws_before()` orders the silhouettes by `get_index(true)` (`lamps.gd`:114): with `get_index()`, each silhouette that it inserts logs the error, and *order* fails (N19). That test holds its props as `PropScatter` does, and the tests that count `Props`' children pass `true`. `_fade()` relies on it the other way: `get_children()` gives it the layer's own children, the actors, and no prop (§5.9, N17).
- **Ties (A9).** Godot's y-sort draws two items of the same y in the order of the layer's children, internal ones included (servers/rendering/renderer_canvas_cull.h:117, `ItemYSort`). `Props`' own children are the car, which `main.gd` adds once the first rows show (:156); a legend's standing parts (`legend.gd`:56–59); and the car's double (:72–74). On `main`, a prop made before one of them drew under it at a tie, and one made after over it. In front, every prop comes before them, so they draw over a prop on their y. *ties* adds a node as `main.gd` adds the car, drives on 199 tiles, and wants every sprite before it: as ordinary children, 1,057 of 1,483 came before it (N17), and at the back none (N18).

### 5.6 The cost (A10, A11, A21; Q2; E8)

The City's buildings give it 5 times `main`'s nodes, and light their windows at night; the other areas cost what they did (A6). Measured on the desktop, on two cloud CPUs with software GL (llvmpipe):

| What | `main` | The default, 0.3 | Q2 | Probe |
|---|---|---|---|---|
| The City's nodes | 3,827 | 13,382 | 19,245 | P1, P13 |
| A row of its props shown: mean, p95, max | 0.90, 0.92, 20.0 ms | 1.14, 1.33, 2.27 ms | 1.45, 1.64, 1.73 ms | P17 |
| A row hidden: mean, p95, max | 0.10, 0.15, 1.85 ms | 0.14, 0.19, 0.24 ms | 0.27, 0.33, 0.37 ms | P17 |
| `_fade()`, a frame: mean, max | | | 35, 46 µs | P14 |
| A frame of the City by day: Movie Maker's CPU and GPU times | 4.90–5.11, 6.15–6.42 ms | 4.62–5.57, 5.61–6.78 ms | 6.52–6.58, 7.99 ms | P15 |
| The same at 22:00 | 9.50–9.55, 10.15–10.19 ms | 10.68–10.99, 10.58–10.76 ms | 14.38–14.79, 13.28–13.61 ms | P15 |
| GUT, locally | 91.5–94.4 s | 85.3–90.7 s | 97.3 s | P6, §6.1 |

**A row's worst frame.** At the speed cap, 7 tiles a second, a row shows and another hides about every 8.6 frames at 60 fps: in the City, at most 2.1 ms on the desktop, of the 16.7 ms that a frame has. `main`'s maxima are outliers over its p95s. P17 measures otherwise than the old P3 and P5, so their times don't compare with these. `Lamps` inserts each silhouette at its place, which costs more with more props (A10).

**The desktop isn't the Fold4.** Movie Maker's times are the renderer's: the CPU's work to set up each frame, and the GPU's, which llvmpipe runs on the CPU too. They compare the builds on one machine, but say nothing of a phone's frame. A browser's frames a second there, which the default's buildings hardly moved (P10), fall with Q2's: from PR 1's build to PR 2's, Chrome's from 33.2 to 24.5 by day and from 23 to 13 at 22:00, and Firefox's from 58 to 50–51 at 22:00, while by day it keeps 58 (P18). At night `Lamps` holds a silhouette and 8 window glows for each building, about 720 sprites in view. Yet llvmpipe draws every pixel on the CPU, so these say little of a phone's (docs/agents/checks.md:64). So the Fold4 reads E8's frame rate, not a blocker (§6.4; IP :203). The City costs most at night, when each building's windows glow (A19, A21). A run's first night comes in Rural, as the City ends before its night, 65 s into the zone (docs/DAYNIGHT.md §5.8), so the City shows at night with `--hour`, as P15 ran it, or in a later schedule.

**If the Fold4 drops frames** (E8): lower the street density, within Q2's 0.35 to 0.6; give each building one glow for its windows (§9); show a row's props over a few frames (§9); or give `Lamps` a row's silhouettes at once (A10, §9). Each is a change to PR 2, or a PR after it, as the owner chooses.

### 5.7 The docs (A14; E10)

PR 1 changes `plan.md` §5.3's line on the car (:211), as the sheet changes (**Δ A14**). PR 3 replaces this plan with `docs/VISUALS.md`, at most about 15 KB (`docs/README.md`; docs/agents/planning.md §6). Its header says where the full plan is: `git show <sha>:VISUALS_PLAN.md`, the SHA of the last commit with it, and the tag `archive/vis/prototype`. Then the findings A1–A21 with their fixes; Q1–Q6 with the owner's answers; §5.1, §5.3, §5.4, §5.8 and §5.9 under the same numbers, as code and tests cite them; the exit criteria and the device results. IP's M7 notes take the device checks still open and §9's notes (§4.4).

On PR 2's head, 35 lines in 19 files name this plan, and comments after them cite more of it bare: §5.1, §5.3, §5.4, §5.8 and §5.9; A3, A6–A9, A13 and A16; and Q2. `docs/VISUALS.md` must define each.

### 5.8 Streets (A16; Q2; E12) **Δ docs/M5.md §5.6**

Q2 keeps the City's buildings between 0.35 and 0.6, and moves them closer to the streets. A lot by a street shows its prop at `PropDef.street_density`, and the others at `density`:

```gdscript
## The chance that a lot of its size by a street shows it: a lot with a side on a road tile's, but
## not just a corner. -1 for `density`'s (VISUALS_PLAN.md §5.8).
@export_range(-1.0, 1.0, 0.001) var street_density := -1.0

func chance(by_street: bool) -> float:
	return street_density if by_street and street_density >= 0.0 else density
```

- **By a street.** `row()` takes the sides of each tile that a road tile is across, `street_sides()`, a bit each in `SIDES`' order: x−, x+, y− and y+. A lot is by a street if a side of the tile that it lies along, `lot_sides()`, is one of them: a lot of 2 × 2 lies along two of its tile's sides, and a cell along none, one or two. A road tile across only a corner meets the lot at a point, so doesn't count (N37, N38). `pick(props, hashed, by_street)` takes each prop's `chance()` from the hash's share, for lots of 2 × 2 and of one cell alike (N36, N39, N63).
- **Only where asked.** `row()` looks for streets only if a prop has a street density, so the other areas' rows cost and pick as before (A6).
- **The contract.** `validate()` rejects a street density outside 0..1 that isn't −1, and each size's street densities add up to 1 at most (§5.4; N40, N41).
- **The numbers.** *street* lays a see-through block of 2 × 2 at 0.35, and 0.6 by a street, and a dot of one cell at 0.2, and 0.5 by a street, on seeds 1–3. It counts more than 1,000 of each kind: lots by a street and inside, and free cells by a street and inside; and wants the props that each shows within four standard deviations of its chance: on a6b88fb, 1,342 of 2,722 free cells by a street showed the dot (0.493), and 8,728 of 43,586 inside (0.200). Placed again on the whole road, the rows are the same. *City* wants more than 4,600 buildings, which the City's tuning without its street density or without see-through doesn't reach (N42, N47).

### 5.9 See-through props and the fade (A16–A20; Q2; E12, E13) **Δ docs/M5.md §5.6**

**Rising over the road (A16).** `main`'s `_place()` leaves out each prop whose frame would touch a road tile's diamond, `touches_road()`, and a building's tall frame does from every lot by a street. `PropDef.see_through` lets a prop rise over the road behind it: `_place()` skips `touches_road()` for it. It must still not stand on the road, so `validate()` wants it an upright box whose base lies in its lot. Its shadow falls from the middle of its base, `shadow_rise` above its foot, so the base reaches `2 × shadow_rise` back from the foot, which is half a cell from the lot's front corner: `4 × shadow_rise` must be at most `2 × lot − 1` cells' heights, else "prop <id> is see-through, but not a box on its lot" (N44–N46). The building's is 40 px against 48. Set pieces still keep it clear, as `row()` skips each tile near one, whatever its props (*river*, N64). *rise* lays see-through boxes on two roads: more than 200 frames over the road, more props than boxes that keep off it, and no corner of a base on a road tile (N43).

**The fade (A17).** In 68% of the City's views a building's frame stands over the car's body (P13). Q2: "make them more transparent similar to the tunnel view". The tunnel fades to 0.2 while the car is near it, `TUNNEL_SEE_THROUGH` (docs/M4.md K5, Q3), so a see-through prop shows `PROP_SEE_THROUGH`, 0.2, of itself where it would hide the car's body, or a sprite that a legend stood on `Props`, and comes back whole as they part:

```gdscript
static func opacity(frame: Rect2, foot_y: float, actor: Rect2, actor_y: float) -> float:
	var gap := maxf(0.0, maxf(frame.position.x - actor.end.x, actor.position.x - frame.end.x))
	gap += maxf(0.0, maxf(frame.position.y - actor.end.y, actor.position.y - frame.end.y))
	gap += maxf(0.0, actor_y - foot_y)
	return lerpf(Tuning.PROP_SEE_THROUGH, 1.0, smoothstep(0.0, Tuning.PROP_FADE_PX, gap))
```

- **The gap.** Across and down between the two rects, and how far the actor sorts in front of the prop's foot: `Props` y-sorts them, so the prop hides the actor only while its foot is lower on the screen (A9). Over `PROP_FADE_PX`, 48 px, it comes back smoothly, so it changes little as the car comes in front of it, at the tie, and nothing pops (N48, N49).
- **The actors (A18).** `_fade()` takes each of the layer's own children, which the props aren't (§5.5). `actor_rect()` gives the car's `body_rect()`, through its transform and its body's, as a disaster may move, scale or turn it (*body rect*, N61); a sprite's rect through its transform, such as the car's double or a legend's part; and nothing for what doesn't show, by `visible` or by an alpha of 0, as a legend hides the car and its parts wait (N53, N54). A part that waits at scale 0 still has an area, as Node2D keeps the scale at `CMP_EPSILON`, so a scale under `HIDDEN_SCALE`, 1e-4, is hidden too, as `ufo.gd`'s `SLIVER` relies on (N67). An actor sorts at its position (N55).
- **Which props.** Each row keeps its see-through props, `Row.fading`, each with its frame on the layer, cached as it shows (N60). `SeeThrough.rows()` names the rows whose props may come within `PROP_FADE_PX` of an actor (N50, N51). In them `_fade()` skips each prop more than that across (N59), and gives each other the least opacity that an actor asks. It sets only what changed, and shows whole each prop no longer near (N57). `_hide_row()` forgets its props, and `PropPool.acquire()` shows a reused sprite whole (A20, *pool*, N62).
- **Its lights (A19).** `_show_alpha()` sets the prop's alpha and its silhouette's, and the glows are the silhouette's children, so they fade with it (N56). Only `modulate` changes, so nothing is redrawn on the Web (docs/M2.md §5.7).
- **Only see-through props** fade, as only they rise over the road (N58). Nothing but the view reads the fade, and no RNG is drawn, so a seed plays as before.
- **Tests.** `test_see_through.gd` checks `opacity()` over the car and as they part, at the tie and once the car is well in front, and that `rows()` holds every prop that may fade (N48–N51). *fade* shows buildings and plain props by the car, its double behind one building and two sprites that don't show behind others, and wants each prop at the opacity that its actors ask, only buildings faded, each silhouette as its prop, and all whole once the actors go (N52–N60).

`_fade()` takes 35 µs a frame on average and 46 µs at most, and 3.6 µs where no prop is see-through (P14).

---

## 6. Verification

### 6.1 Checks and counts

The checks are `AGENTS.md` §3's five. `ci.yml` runs on pull requests, on pushes to `main` and by hand, so a push to a `vis/` branch starts none: the prototype ran by hand with `upload-builds`, which built the Web build and the APK too. Each state marked Local ran all five with Godot 4.7.2, and every check passed: `lint.sh` printed `Success: no problems found`, `smoke.sh` `main`'s smoke line, `autopilot: tile 165, turns 35, area rural`, and no error line, and `git status --porcelain` nothing after. GUT's time varies from run to run, in CI most (P9).

| State | Where | Scripts | Tests | Asserts | GUT time | `test` job |
|---|---|---|---|---|---|---|
| `main` (81f22e3) | Runs 43677544228, on its push, and 43681791616, by hand; Local | 160 | 583 | 426,861 | 112.8 s, 82.1 s; 91.5–94.4 s | 2 min 53 s, 2 min 36 s |
| The default (4d607d7) | Run 43700925150; Local | 160 | 594 | 428,552 | 76.8 s; 88.9 s | 2 min 29 s |
| Q2 (a7ab941) | Run 43761614657; Local | 162 | 601 | 429,379 | 133.4 s; 97.3 s | 3 min 15 s |
| Q2 (a6b88fb) | Run 43762371205; Local, beside other runs | 162 | 601 | 429,381 | 100.3 s; 121.6 s | 2 min 36 s |
| PR 1 (873a792) | Runs 43767951164, on its PR, and 43768052322, by hand; Local | 160 | 589 | 427,317 | 93.0 s, 94.2 s; 98.3 s, and 434.2 s at a low priority beside the negative cases | 2 min 31 s, 2 min 29 s |
| PR 2 (6ef331f) | Runs 43769483981, on its PR, and 43769530988, by hand; Local | 162 | 602 | 429,384 | 102.2 s, 128.5 s; 552.9 s, as PR 1's 434.2 s, and 101.7 s alone (§6.2) | 2 min 56 s, 3 min 9 s |
| PR 1 (ee73241), merged with `main` after the plan's squash | Run 43839662082, on its PR; Local | 160 | 589 | 427,317 | 93.6 s; 96.6 s | 2 min 34 s |
| PR 2 (60d3e18), merged with `main` after PR 1's squash, and bba50c8, the plan's sync | Run 43845380797, on its PR; for bba50c8, runs 43846829433, on its PR, and 43846887823, by hand; Local | 162 | 602 | 429,384 | 134.8 s; 144.7 s, 133.2 s; 105.9 s | 4 min 13 s; 3 min 29 s, 3 min 15 s |

a6b88fb gives cells of one their street density too, which *street* now checks (N63), and renames a local that shadowed `GutTest.double()` (§6.3). PR 2's code is a6b88fb's with the reviews' fixes, 93a55e3 and 6ef331f (§4.6), and PR 1's the default's files on `main` (§4.1). ee73241 and 60d3e18 change no file (§4.5).

### 6.2 Negative cases

Each change below makes the tests named fail, and nothing else. A script, not committed, applied each to a clean worktree of the PR's head, ran `tools/ci/run_tests.sh`, read GUT's JUnit report, and restored the files; for the sheet's, N1–N3 and N27, it ran `make_car.gd` and `import.sh` first, and `import.sh` again after. `git status --porcelain` printed nothing after each. PR 1's ran on 873a792, and PR 2's, PR 1's again among them, on 6ef331f, two at a time, each in a worktree of its own (`docs/agents/planning.md` §4). GUT took 93.3–107.1 s on 873a792 and 88.9–178.8 s on 6ef331f, N20 the longest; N66 and N67 ran first, at a low priority beside other cases, in 597 s and 583 s. 6ef331f itself, run alone, passed in 101.7 s. N17 and N19 ran script by script: N17 takes `test_props_in_view.gd` from 7 s to 564 s, past `run_tests.sh`'s 900 s with the rest, and N19's error, logged by the hundred thousand, uses up the machine's 7.6 GB, so each Godot was held to 3 GB. So run, the head unchanged passed all 78 scripts. N34 and N35 ran on 4d607d7 merged with #88's head, b0502ea, with A15's change: 648 tests.

**Short names.** `test_car_controller.gd`: *roll* `test_its_wheels_turn_on_a_phase_…`, *drawn* `test_a_drawn_frame_turns_the_wheels_…`, *stands* `test_once_the_car_stands_…`, *6 fps* `test_at_6_frames_a_second_…`, *double* `test_its_double_shows_…`, *wreck* `test_a_crashed_car_shows_its_wreck_…` and *body rect* `test_its_body_rect_is_where_…`. `test_car_art.gd`: *outline* `test_each_phase_turns_the_wheels_in_the_same_outline` and *forward* `test_seen_side_on_the_wheels_roll_forward`. *shadow*: `test_shadows.gd`'s `test_the_cars_shadow_follows_its_frame_…`. *crash*: `test_crash.gd`'s `test_a_crash_smokes_shakes_…`. `test_prop_layout.gd`: *front* `test_a_lot_shows_one_prop_on_its_front_cell_…` and *sizes* `test_each_size_of_lot_takes_its_density_…`, together *lots*; *as before* `test_props_of_one_cell_stand_where_they_stood_before_lots`; *City* `test_the_city_shows_many_buildings_…`; *street* `test_lots_by_a_street_take_…`; *rise* `test_see_through_props_rise_over_the_road_…`; *river* `test_props_keep_off_the_river_…`. `test_prop_scatter.gd`: *contract* `test_props_that_break_the_contract_…`, *add up* `test_densities_that_add_up_to_1_are_valid`, *rows* `test_rows_show_props_ahead_of_the_car_…`, *ties* `test_the_layers_own_children_draw_over_…` and *fade* `test_see_through_props_fade_where_…`. `test_see_through.gd`: *over* `test_a_prop_shows_little_of_itself_…`, *tie* `test_it_changes_little_as_the_car_comes_in_front_…` and *names* `test_the_rows_it_names_…`. *order*: `test_lamps.gd`'s `test_the_silhouettes_draw_in_the_order_…`. *pool*: `test_prop_pool.gd`'s `test_a_released_sprite_shows_the_next_prop`. *sums*: `test_prop_art.gd`'s `test_each_area_has_six_to_ten_props_some_animated`.

**PR 1's** (§4.2). `car_controller.gd` unless named:

| N# | Change | Fails |
|---|---|---|
| N1 | `make_car.gd`: every row drawn in phase 0 | *outline*, *forward* |
| N2 | `make_car.gd`: the mark turns backwards, `TAU / 4.0 + phase * TAU / PHASES` | *forward* |
| N3 | `make_car.gd`: no wheels, as `_splat_wheel()` returns at once | *outline*, *forward*, as no mark shows |
| N4 | `_driven` never changes | *roll*, *drawn*, *6 fps*, *double*, *wreck*, *shadow*: the last three roll the wheels past the first phase first |
| N5 | The wheels roll with time, `_driven += delta` | *roll*, *drawn*, *stands*, *6 fps* |
| N6 | `body_frame()` returns `_body.frame` | *shadow*, and 42 tests in 11 main-scene scripts, on Godot's error "Index p_frame = 20 is out of bounds (vframes * hframes = 17)": the shadow's sheet has one row |
| N7 | `double()` cuts from the first row | *double* |
| N8 | The wreck in the wheels' row, `Vector2i(WRECK_FRAME, _phase)` | *crash*, *wreck* |
| N24 | No limit, as before e462135: a frame's whole drive turns the wheels a phase each `WHEEL_ROLL_TILES` | *drawn*, *6 fps* |
| N25 | The wheels turn back, `posmod(_phase - 1, PHASES)` | *roll*, *drawn*, *6 fps* |
| N26 | `_physics_process()` calls `_process(delta)` too | *drawn*, *6 fps* |
| N27 | `make_car.gd`: no hub's mark in phase 2 | *forward*: "frame 4, the left wheel, phase 2: its mark shows", and so for each wheel in frames 4 and 12 |
| N28 | The rest of a frame's drive kept as a debt, `_driven -= drive` | *drawn*, *stands*, *6 fps* |
| N29 | As at be340a8, with e462135's rule | *drawn*, *stands* |
| N30 | The first draft (§4.7): the drive uncapped, and `fposmod()` for `-=` | *drawn* |
| N31 | The second draft: `fposmod()` for `-=` | *drawn* |
| N32 | No `if drive <= 0.0: return` | *stands* |
| N33 | A turn only past a phase, `if _rolled > Tuning.WHEEL_ROLL_TILES:` | *drawn* |
| N34 | A15's change undone, as #88 has it: `GAUGE` 9, the sand's extents 9 | `test_marfa_lights.gd`'s tracks test: "x -10: under the car", and so for x 8 and 9 |
| N35 | A15's change but the sand's, `Vector2(9, 1)` | Its sand test: "the sand from between its back wheels", at each of 4 headings |

**PR 2's** (§4.3). `prop_layout.gd` unless named:

| N# | Change | Fails |
|---|---|---|
| N9 | A lot's prop placed, but its cells not taken | *lots*, *street* |
| N10 | The cells of one don't skip those that a larger lot took | *lots*, *street* |
| N11 | A lot's prop left out, as it would touch the road, takes its cells all the same | *front* |
| N12 | `lot_hash()` without its size's salt | *sizes*, *street* |
| N13 | `prop_scatter.gd`: `_valid_props()` sums each prop with the props of one cell, not of its size | *contract*, *add up* |
| N14 | `prop_def.gd`: `validate()` without its rule for the lot | *contract* |
| N15 | The cells of one hashed as a larger lot is, `_mix(cell_hash(…))` | *as before* |
| N16 | The cells of one in another order, `a` outer and `b` inner | *as before* |
| N17 | `prop_scatter.gd`: the pool's sprites ordinary children, `PropPool.new(layer)` | *rows*, *ties*, and *fade*: "1508 props wrong", as `_fade()` then takes the props for actors (§5.5) |
| N18 | `prop_scatter.gd`: internal, but at the back, `INTERNAL_MODE_BACK` | *ties* |
| N19 | `lamps.gd`: `_draws_before()` with `get_index()` | *order*, with 226 errors "Node is internal. Can't get index with 'include_internal' being false."; and 58 tests in the 17 other scripts that order lamps' silhouettes, as `Lamps` logs the error each time: GUT fails them on it, or Godot crashes, as 10 of the scripts did |
| N20 | `building.tres` without `lot = 2` and `see_through`: a building of one cell, at 0.35 and 0.6 by a street. Without `lot` alone, it breaks `validate()`'s fit, and 88 tests fail (§4.7) | *City*: "seed 1: on (-35, 36) and (-34, 35)", and so on |
| N21 | `building.tres` as on `main`: one cell, at 0.01 | *City* |
| N22 | A lot of which a larger lot's prop took a cell isn't skipped | *lots* |
| N23 | `by_lot()` smallest first | *lots* |
| N36 | No lot of 2 × 2 by a street, `by_street := false` | *City*: 4,427 buildings, not over 4,600; *street*: 1,184 lots by a street, against 1,981 ± 113 |
| N37 | `lot_sides()` takes x− for x+ | *street* |
| N38 | `street_sides()` counts a road tile across a corner | *street* |
| N39 | `prop_def.gd`: `chance()` returns `density` | *City* and *street*, as N36; *contract*: no "dense: prop lining takes the densities past 1" |
| N40 | `prop_scatter.gd`: `_valid_props()` without the street sums | *contract* |
| N41 | `prop_def.gd`: no range for `street_density` | *contract* |
| N42 | `building.tres` without `street_density` | *City* |
| N43 | `touches_road()` for every prop | *City*: 3,256 buildings; *rise*: no frame over the road; *street*: no lot by a street |
| N44 | `prop_def.gd`: a see-through prop needn't be upright | *contract* |
| N45 | `prop_def.gd`: the fit with `>=`, so a box that just fits is rejected | *contract* |
| N46 | `prop_def.gd`: the fit with `2 *` for `4 *` | *contract* |
| N47 | `building.tres` without `see_through` | *City* |
| N48 | `see_through.gd`: a step, `PROP_SEE_THROUGH` where the gap is 0, else 1 | *over*, *tie*, *names*, *fade* |
| N49 | `see_through.gd`: no sort term in the gap | *tie* |
| N50 | `see_through.gd`: `rows()` without `PROP_FADE_PX` at the top | *names* |
| N51 | The same at the bottom | *names* |
| N52 | `prop_scatter.gd`: no `_fade()` | *fade* |
| N53 | `actor_rect()` without its alpha check | *fade* |
| N54 | `actor_rect()` without its `visible` check | *fade* |
| N55 | An actor sorts at its rect's end, `actor.end.y` | *fade* |
| N56 | `_show_alpha()` leaves the silhouette | *fade* |
| N57 | No prop shown whole again once no actor is near | *fade* |
| N58 | Every prop fades, `if true:` | *fade* |
| N59 | The early-out across without `PROP_FADE_PX` | *fade* |
| N60 | No frame cached | *fade* |
| N61 | `car_controller.gd`: `body_rect()` without the car's transform | *body rect* |
| N62 | `prop_pool.gd`: `acquire()` keeps the last alpha | *pool* |
| N63 | No cell of one by a street, `by_street := false` | *street*: "free cells by a street", 540 against 1,361 ± 104 |
| N64 | Set pieces don't keep see-through props clear | *river*: "624 props in set pieces" |
| N65 | `prop_scatter.gd`: `_valid_props()` sums in a `Vector2`, as at 1d5aa59 | *add up*: "Expected 0 push_error errors. Got 2" |
| N66 | `prop_scatter.gd`: `past_1()` as `sum > 1.0` | *add up*: "Got 1", and "the third shows" |
| N67 | `prop_scatter.gd`: `actor_rect()` without its check of the scale | *fade*: the hidden fade 1.0, 0.2 and 1.0 |

### 6.3 Editor warnings

The five checks report no GDScript warnings, and shadowing shows only in the editor (`AGENTS.md` §2). As docs/agents/checks.md §1 says, a temporary `override.cfg` raised the 37 warnings at level 1 to 2, errors, and `check_scripts.sh` loaded every script. On a7ab941 it found that *fade*'s local `double` shadowed `GutTest.double()`: a6b88fb renamed it `stand_in`. On 873a792 and 6ef331f it found only `main`'s: 4 `INTEGER_DIVISION`, in `art_checks.gd`, `ui/main.gd`, `test_greybox_atlas.gd` and `test_iso.gd`, and 1 `UNUSED_VARIABLE`, in `test_road_generator_occupancy.gd`. As Godot reports only a script's first error, it ran again without `integer_division`, and found only the `UNUSED_VARIABLE`. VIS's one integer division, in a test, has `@warning_ignore("integer_division")`. The file was deleted after, and `git status --porcelain` printed nothing.

### 6.4 Verified only in CI or on devices

- **CI.** The five required checks on each PR, and the `test` job's time (§6.1).
- **The Web** (E9, E12, E13), by an agent, on each PR's build, served with M4's patch, which passes the URL's `arg`s to the game (docs/agents/checks.md §4):
  ```bash
  gh workflow run ci.yml -R pompomon/roadgame --ref <branch> -f upload-builds=true
  rm -rf /tmp/roadgame-web
  gh run download <run id> -R pompomon/roadgame -n web -D /tmp/roadgame-web
  sed -i 's/"args":\[\]/"args":["--"].concat(new URLSearchParams(location.search).getAll("arg"))/' \
    /tmp/roadgame-web/index.html
  python3 -m http.server -d /tmp/roadgame-web 8000
  ```
  Open `http://localhost:8000/?arg=--autopilot&arg=--seed=1&arg=--area=city`, and again with `&arg=--hour=22`, in Chrome and Firefox, driven by Playwright, headed under Xvfb, at 360 × 640, each run in a new context. Post what each shows and the console's errors, by browser and hour, in a PR comment.
  - **PR 1.** Record each run with Playwright's video: the wheels turn forward, faster as the car speeds up, a phase a frame at most where Chrome draws about 19 frames a second (§5.1). With `--play` for `--autopilot` the car misses its first turn, and the wheels must stop as the legend brakes it.
  - **PR 2.** Frames at 8, 16, 24 and 32 s, by day and at 22:00: buildings along the streets, none in another or on the road; each over the car faded, and whole again once the car leaves it; nothing that flickers.

  A PR's build stays current while `git diff --name-only <built> HEAD -- . ':!tests' ':!addons/gut' ':!*.md'` prints nothing, so a fix to tests or words needs no new one. P18 ran each PR's part on its own build: PR 1's of 873a792, and PR 2's of 6ef331f.
- **The Fold4** (E9), by the owner, on both screens and through a fold. PR 2's debug APK has PR 1's wheels too, so one check does for both: `rm -rf /tmp/roadgame-apk && gh run download <run id> -R pompomon/roadgame -n "android-Android APK" -D /tmp/roadgame-apk`, then `adb install -r /tmp/roadgame-apk/roadgame-debug.apk`. The APK takes no arguments: in a debug build, the title's Start button chooses the City (docs/ZONE_SELECT.md; IP :178). Until the save says it's done, Play starts a run with the tutorial, which has no disasters (docs/TUTORIAL.md §5.6): if the banner reads "Tutorial", finish it, 12 correct turns in a row, and the run goes on in the City under its rules. By day, check that the wheels turn forward at every speed and stop as a missed turn's legend brakes the car; that buildings line the streets, none in another or on the road; that each building over the car fades, and comes back as the car leaves it; that nothing flickers; and the frame rate, with the Godot monitor overlay or `print_fps`, not a blocker (E8; IP :203). The City's night needs `--hour` (§5.6), which the APK can't take: serve PR 2's Web build as above, run `adb reverse tcp:8000 tcp:8000`, and open the URL with `&arg=--hour=22` in the Fold4's Chrome (docs/agents/checks.md:67). A browser's frame rate isn't the APK's, so the night's is a hint: if it drops where the day's holds, §5.6 says what to change.

### 6.5 Measurements

The probes ran with Godot 4.7.2, headless unless they say otherwise; they aren't committed. "The default" is the prototype before Q2, 4d607d7 or earlier: a lot of 2 × 2 at 0.3.

| P# | What | Result | Used by |
|---|---|---|---|
| P1 | The City's views: seeds 1–5, 40 s each with the autopilot, 385 views of 360 × 640 px; the nodes, and in each view the buildings, those in each other's base and the props | `main` 3.07 buildings a view, at most 9, and 3,827 nodes; the default 17.79, at most 33. At 0.3 a lot, a building's frame would touch the road on 24% of the lots | A2, A3, §5.3 |
| P2 | The props that 150 rows place on seeds 1–4, in each area, `main` against the default | The City 5,839 → 12,192, its buildings 1,133 → 8,760. Rural, the Meadows, the Village and the Desert: the same 27,590 props, in the same places and order | A6, A12 |
| P3 | A row's show and hide in a run of the City, `main` and lots at 0.2–0.4 | Of 100 rows' shows, `Lamps` took 19 ms on `main` and 67–87 ms at 0.3. P17 times rows otherwise, and replaces the rest | A10 |
| P4 | `PropLayout.row()` alone: 200 rows of each area's props, far from any road | `main` 0.60–0.62 ms a row in the City; the default 0.79 in the City and 0.63–0.65 in the others | A6, A11 |
| P5 | A frame of the City in Movie Maker, `main` and the default | P15 runs it again with Q2, and replaces it | |
| P6 | GUT's time locally, with the props' sprites ordinary and internal | `main` 91 s; the default 118 s with ordinary children and 86 s with internal | A7, E8 |
| P7 | Whether internal children draw the same: 600 frames of the City by day and 600 at 22:00 in Movie Maker | All 1,200 the same bytes | A7, E7 |
| P8 | The art and the builds | `make_car.gd` 5.2–5.4 s, against 1.46 s on `main`; both art scripts draw the bytes committed. `car.png` 3,072 → 13,587 B. The Web build 11,219,350 B on `main`, 11,227,197 the default, 11,227,884 a6b88fb; the APK 58,239,836, 58,245,809 and 58,249,968 B (runs 43681791616, 43686668804 and 43762371205) | E2, §5.1 |
| P9 | GUT's time in CI's `test` job | 68.8–144.7 s over VIS's runs to bba50c8's; `main`'s 82.1 and 112.8 s (§6.1) | §6.1, §8 |
| P10 | The Web: `main`'s build and the default's, 910cd24, as §6.4 says, with Playwright 1.64; frames a second over 3 s from `requestAnimationFrame` | Chrome by day and at 22:00: `main` 33.0 and 19.0, the default 30.0–31.3 and 18.7–21.0. Firefox 54.7–59.3. No WebGL error from either | E9, §5.1, §5.6 |
| P11 | Whether VIS merges with the open PRs: PL's, #81–#83, #86–#91 and #96, EG's plan, #84, and #95 | `git merge-tree` of each one's head with 873a792 and with 6ef331f, on 2026-11-16: clean, and again with 60d3e18, PR 2 merged with `main` after PR 1's squash; PL's change `config/tuning.gd` and `plan.md` at other lines. The five checks passed on the default merged with #83's head and with #88's and #89's, once A15's change was made | §4.5, A15 |
| P12 | How often a prop wider than a cell stands in another: 4 seeds × 100 rows of each area | The City's buildings on lots: none. Rural's barns and windmills 7.4%, the Meadows' ponds 1.5%, the Village's houses 9.6%. The City's building as on `main` 8.3%; on a cell at 0.3, 92.4% | A3, Q5, §9 |
| P13 | The City's views as P1, 400 of them: Q2, the default, and 0.35 neither by streets nor see-through | §5.3's table. With Q2, 89.4 props a view, 5.46 of them faded; a building over the car in 272 of the 400 | A16, A17, E5 |
| P14 | `_fade()`'s time a frame in the City, with the autopilot | Without the early-out across and the cached frames, 189 µs; with the early-out, 79 µs; with both, 35.0 µs on average and 45.6 at most; with no see-through prop, 3.6 µs | A18, E8 |
| P15 | A frame of the City in Movie Maker: 900 frames at 360 × 640 under Xvfb, software GL on 2 CPUs, `--fixed-fps 60 -- --autopilot --seed=1 --area=city`, by day and with `--hour=22`, two runs each | §5.6's table | A21, E8 |
| P16 | As P2 in the City, with Q2 | 17,887 props, 15,008 of them buildings; its street props 35–42% fewer than on `main` | A12, §5.3 |
| P17 | A row's show and hide: the main scene in GUT with the autopilot, seeds 1–3, 1,800 frames each; from frame 120, every 30th frame hides and shows again the farthest row, 168 times | §5.6's table | A11, E8 |
| P18 | The Web, on each PR's build (runs 43768052322, of 873a792, and 43769530988, of 6ef331f), as §6.4 says, with Playwright 1.64; frames a second over 30 s from `requestAnimationFrame`, with no screenshot or video, the two builds in turn | PR 1: the hubs' marks move in 24 frames in a row at 8, 16 and 24 s, by day and at 22:00, in both browsers. With `--play`, the legend brakes the car to a stop at 40 m, about 3 s in, and from then its box stays the same: 0.0 of 255 over Chrome's last 7 frames. PR 2: at 8, 16, 24 and 32 s, by day and at 22:00, buildings line the streets, none in another or on the road, and each over the car is faded. Frame by frame, 25 a second, each fades over a few frames and comes back, and none flickers. Frames a second, PR 1's build, then PR 2's: Chrome 33.2, then 24.5, by day, and 22.8–23.1, then 13.1–13.2, at 22:00; Firefox 58.8, then 58.4, and 58.4–58.5, then 50.0–51.2. No error from the game: Chrome logs 4 `GPU stall due to ReadPixels` notes, and in some runs a `CONTEXT_LOST_WEBGL` before Godot starts; Firefox logs 2 JS warnings. Posted on #93 and #94 | E8, E9, E12, E13 |

---

## 7. Owner actions

| When | Action | How |
|---|---|---|
| On PR 2 | E9 on the Fold4, on both screens and through a fold | §6.4: PR 2's APK, which has PR 1's wheels too, in the City by day, past the tutorial, and its Web build at 22:00 in the Fold4's Chrome. If the frame rate drops, say which of §5.6's changes to make |
| To land VIS | Merge this plan's PR, then PR 1, then PR 2, each once its base is `main` and its checks pass; then PR 3, which starts from `main` once PR 2 has merged (§4.4) | Squash each. Before deleting a merged PR's branch, retarget the next PR to `main`: PR 1 before `vis/plan` goes, PR 2 before `vis/1-wheels` (§4.5) |
| When #88 lands | Nothing more: PR 1 landed first, so #88 takes A15's commit after its merge of `main`, as noted on #88 | §4.2 |
| After PR 3 | Tag the prototype, which this plan cites, and delete the `vis/` branches | `git fetch origin vis/prototype && git push origin FETCH_HEAD:refs/tags/archive/vis/prototype`, then `git push origin --delete vis/plan vis/prototype vis/1-wheels vis/2-city-lots vis/3-docs`, less any already deleted (docs/agents/planning.md §6) |

---

## 8. Risks

| Risk | Impact | Mitigation |
|---|---|---|
| The Fold4 drops frames in the City | It holds 5 times `main`'s nodes and 26 times its buildings in a view (P13). On the desktop a row shows and another hides within 2.1 ms (P17), and a frame takes 1.4–1.7 ms more of the renderer's CPU by day and 4.8–5.3 at night (P15). A phone's CPU is slower, and those times say nothing of its frame | E8 reads it on PR 2's APK (§6.4). If it drops: a lower street density, within Q2's 0.35 to 0.6; a row's show over frames; or `Lamps` given a row's silhouettes at once (§5.6, §9) |
| The City's night is seen only through `--hour` | A run's first night comes in Rural (§5.6), so the APK shows the City by day only, and the night costs most (P15) | The Fold4's Chrome runs PR 2's Web build at 22:00 (§6.4). Its frame rate is a hint, as a browser's isn't the APK's |
| GUT's time in CI | It varies from 68.8 s to 144.7 s (P9), and the City's buildings slow each test that drives there | The props' sprites are internal children, which `simulate()` walks past (A7): locally the suite takes 97 s, `main` 91–94 s |
| The fade reads badly | A building that fades as the car passes behind it could read as a flicker, or show too little of the car | It comes back over 48 px with `smoothstep()`, so it changes little at the tie (§5.9). `PROP_SEE_THROUGH` and `PROP_FADE_PX` are two constants, the first the tunnel's |
| Too dense, or too sparse | The owner sees the City on the Fold4 and wants another look | Q2: the density and the street density are two values in `make_props.gd`'s `PROPS` and `STREETS`, then `make_props.gd` again; P1 and P13 measured four looks |
| The City's street props move and thin | A seed's City shows its trees, lamps, bins, hydrants and traffic lights elsewhere than on `main`, and 35–42% fewer (A12, P16) | Q4: their densities × 1.6 bring their numbers back. No test holds where they stood, and the other areas' stand as before (E6) |
| PL's PRs (#81–#83, #86–#91, #96) land first | They change `config/tuning.gd` too, and #88's tyre tracks fit `main`'s wheels (A15) | At other lines: the merges are clean (P11). With #88, A15's commit narrows the tracks (§4.5) |
| The wheels shimmer, or alias | The Fold4's screen refreshes at up to 120 Hz, and four phases a tile could read as flicker on the hubs | Physics steps at 60 Hz without interpolation (IP :177), at most 0.47 of a phase a physics frame, and a drawn frame turns the wheels a phase at most, forward (A13, §5.1). `WHEEL_ROLL_TILES` is one constant, and the sheet could take more phases (§9) |

---

## 9. Notes for later work

- **Other areas' wide props on lots** (Q5, P12). The Village's houses, Rural's barns and windmills and the Meadows' ponds stand in each other's base 9.6%, 7.4% and 1.5% of the time. Each could take `lot = 2`, a density for a lot, and see-through if it rises over the road; its area's props would then stand elsewhere than on `main`, as the City's do (A12).
- **More buildings** (Q3). Two or three for the City's lots, each with its density, its lights and its shadow, as DN gave the building (docs/DAYNIGHT.md), so that a street of them repeats less.
- **Lots of a tile.** `PropDef.lot` allows 4, a whole tile, which the lot tests place: a park, a square or a plaza could take one.
- **Steering** (Q1). Front wheels that point into a turn need a frame for each heading, each angle and each phase: three angles would triple the sheet. The angle would come from `input.steer()`, and stay visual only.
- **More phases** (A13). Six or eight rows a turn would roll more smoothly; to keep a turn a tile, `WHEEL_ROLL_TILES` would be a sixth or an eighth of a tile, so below 60 fps a drawn frame would more often hold the wheels to a phase (§5.1). Each row adds about 3.4 KB to the sheet (P8).
- **A row's show over frames** (A11, §5.6). `PropScatter` could show a row's props a tile at a time, over the frames before the next row. Only if the Fold4 drops frames.
- **One glow a building** (A21, P18). At night `Lamps` draws a glow for each of a building's 8 windows, about 640 in view. A glow texture of all 8 would make them about 80. Only if the Fold4 drops frames at night.
- **A faster `Lamps` insert** (A10). Sort a row's silhouettes once, then merge them into the layer's in one pass, rather than a `bsearch_custom()` and a `move_child()` for each.
- **Physics interpolation** (IP :177). If M7.5 turns it on, the wheels still roll in `_physics_process()` and show their phase in `_process()`, and a sprite's frame doesn't interpolate.
- **M7.5's checklist** (IP :206). The wheels at every speed, and the City by day and at night, with its fade, on both screens.
