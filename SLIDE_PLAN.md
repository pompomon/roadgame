# Slides: Straights That Seem to Turn (SL)

- **Status:** draft, 2026-11-21, for the owner's review. Nine passes of an internal review by another model family, and a check between them, found 30 problems. This draft fixes them all.
- **Scope:** a straight may *slide*: two of its tiles become corners, so the road steps one tile to the side and then runs on. The car drives straight on, and the road carries it across (§5.3). Each area has its own chance (Q5). A slide steps towards the next turn's side (*forward*) or away from it (*backward*), half each (Q2). There is no junction and no choice, and the pattern is unchanged. §10 ranks three other tricks, the user's fallback: two of them, the mirage exit and the lure car, fool more players than a slide.
- **Verified with:** Python 3.12.3 models of `RoadGenerator`'s geometry, of the carry against `RoadGeometry`'s capsules, and of the car's progress (§6.5), and §5.3's proof. Godot wasn't at hand, so `sl/prototype` checks them with Godot 4.7.2, GUT 9.7.1 and the CI scripts before PR 1 (§4.1).
- **Precedence (Δ):** where this plan marks Δ, it replaces:
  - the path's −x/−y invariant (road_generator.gd:9–14);
  - docs/ROADGEN.md R5's proof that every junction keeps its wrong exits (docs/ROADGEN.md:20 and §5.3);
  - the list of streams in IP §5.3 and D8, which gains `slide`.

  Elsewhere IP, plan.md and the docs hold.
- **Reference code:** `main` at e73f96d (2026-11-21, #123). Every line cited is at that commit, and e93f12b (#124, PF's plan) changes no code.
- **Prerequisites:** none. SP is done (docs/SPEEDUP.md), and M7 can come before or after. PF's PR 3 (PERF_PLAN.md §5.3) also changes `world/prop_scatter.gd`: freed rows hide 2 a frame, up to `_hide_below`, and each row stores its anchor. Whichever of it and SL's PR 2 lands second merges the other, so that `_hide_below` is `lowest_row()`, a screen row, and the anchor is stored once.
- **IDs:** findings X#, and this plan's E#, P#, Q# and N#. Branches are `sl/…`, and commits are `<area>: <what> (SL PR <k>)`.

## 1. Goal and exit criteria

The road hides its pattern only at its junctions. Between them it runs straight, so a player who keeps count (plan.md:28, docs/ROADGEN.md:7) has nothing else to count. A slide adds bends that aren't choices. Seen ahead and driven through, a straight that steps aside and on looks like a bend and a bend back. A player who goes by the road's last bend, rather than the last turn they took at a junction, loses the count and takes the next turn the wrong way (X2).

The car isn't steered through it: it keeps its heading and its speed, and the road carries it one tile across, over 0.4 tiles of the straight (§5.3).

```
Map, N up and W left:                  On screen, N is up-right and W up-left:

   forward (W)        backward (E)     forward on an N road: a bend left, then right
      │                    │           backward on an N road: a bend right, then left
      └┐                  ┌┘           (on a W road: forward right then left; backward left then right)
       │                  │
   C1 is the lower corner (path index k), C2 the upper one (k + 1); the straight runs on from C2.
```

**The honest limit.** A slide fools no player who takes the turn that leads up the screen (X1), nor one who counts only the turns taken at junctions. It confuses players who read bends. Its chance to trick is low to medium (§10), and §10's mirage exit is the trick for the rest.

| E# | Criterion | Checked by |
|---|---|---|
| E1 | **Placement.** A straight slides only where §5.2 allows, and there with its area's `slide_chance`, to within 0.05 over a test's straights. So it never slides in these places:<br>• the start straight;<br>• the tutorial's straights;<br>• a pit stop's straight;<br>• a set piece;<br>• a straight shorter than 2·`SLIDE_MARGIN_TILES` + 2.<br>At least `SLIDE_MARGIN_TILES` straight tiles lie before C1 and after C2 (§5.2). | `test_road_generator_slides.gd` |
| E2 | **The road stays valid.** For seeds 0–199 of the game's road, the road home and `endless()`, with every eligible straight sliding, each road:<br>• is a connected path, and overlaps no tile;<br>• keeps every junction's wrong exits as R5 says: none dropped, no straight-on dead end cut, and each opposite-turn dead end at least 2 tiles.<br>The road's own stream is unchanged: junction indices, kinds, turns and areas match at chances 0 and 1. P4 runs the same checks on 5,000 seeds a road. | GUT; P4 |
| E3 | **A slide is no junction.** Driving through one leaves the turn count, streak, state and speed target as on a straight. It fires no trigger and no disaster. | `test_car_sim_slide.gd` |
| E4 | **The carry.** A car anywhere on its lane, \|w₀\| ≤ 0.318 off the centreline (§5.3), at 0.5 to 7 tiles/s, goes through each of the four kinds of slide without leaving the road or taking damage. The kinds are an N road to W or to E, and a W road to N or to S. The car ends one tile across, with its angle unchanged.<br>Driving back through a slide carries the car back, and the carry takes only the cars that §5.3's latch takes, however they then steer. | `test_car_sim_slide.gd` |
| E5 | **The autopilot.** On 20 seeds with every eligible straight sliding, it drives each road to its end with no damage and no time off the road. `test_autopilot_300_turns` still passes. | `tests/sim/test_autopilot_slides.gd` |
| E6 | **SP's E1 holds** (docs/SPEEDUP.md:9).<br>• Seeds 0–9 arrive within `MOST_SECONDS`, 300 s.<br>• Pier seed 4993 and home seed 352 arrive within `SLOWEST_SECONDS`, 310 s.<br>This holds with PR 3's chances. P1 measures the time that slides save. | `test_drive_to_the_end.gd`; P1 |
| E7 | **Rows.** No prop stands on a slide's road. Each screen row gets its props once, from the first path tile on it, spread across the view from every path tile on the `PROP_AHEAD` rows below it. The buffer keeps `BUFFER_REFILL_AT` to `BUFFER_AHEAD` screen rows ahead of the highest row the car has reached and `BUFFER_BEHIND` below it, and the props' guard counts screen rows (PR 2, §5.7). With PR 3's chances, nothing comes or goes in view. | `test_road_buffer.gd`, `test_prop_scatter.gd`, `test_prop_layout.gd`, `test_camera_rig.gd`; `test_props_in_view.gd` in PR 3; P6 |
| E8 | **The look.** Movie Maker frames at 2, 4 and 7 tiles/s, for each of the four kinds, in each area that slides. The road must read as a bend and a bend back, the car must stay on its lane, and each area's corner art must join its straights. The Fold4 checks follow (§6.4). | P3; the owner |
| E9 | **Docs and CI.** The docs change as §5.11 says, and docs/SLIDE.md replaces this plan. Every check passes, and `git status --porcelain` prints nothing. | CI; PR 3 |
| E10 | **The digests change only in PR 3**, when the chances turn on. Every area's chance is 0 in PRs 1 and 2, so `PATH_DIGEST` and `ROAD_DIGEST` (`test_road_generator_determinism.gd:11–12`) hold there. | GUT |

## 2. Findings

By severity. Each says what is wrong, the evidence, and the fix.

### High

- **X1. The up-screen tell.**
  - **What:** the path is a staircase of N and W runs (road_generator.gd:9–10, plan.md:88). So the pattern's next turn always leads up the screen, and the other turn always leads down it. At every junction, the correct exit is the turn that leads up the screen, or straight on if there is none:
    - **T junction:** the turn leads up, the opposite turn down.
    - **Crossroads and side road:** they add straight on, which is wrong while the up turn is offered.
    - **Decoy:** offers only straight on and the down turn.
  - **Evidence:** road_generator.gd:197–208: `turn_for`, `expected_exit` and the wrong exits.
  - **Fix:** none here. A slide changes neither which turn leads up nor what the junctions offer. A player who goes by the screen isn't fooled, and the plan claims nothing for that player (§1). Of §10's tricks, only the mirage exit can fool them.
- **X2. Who each slide fools.** A slide changes no junction, so it fools only a player whose rule reads bends. Which rules players use isn't known: E8's Fold4 check asks the owner whether a slide misleads.

  The examples are on an N road, where the next turn is left:

  | The player's rule | Forward slide (left, right) | Backward slide (right, left) |
  |---|---|---|
  | Turn up the screen, else go straight on (X1) | not fooled | not fooled |
  | Alternate the turns taken at junctions (plan.md:28) | not fooled | not fooled |
  | Flip the expected turn at every bend | not fooled: two flips | not fooled: two flips |
  | Take the opposite of the last bend gone round | not fooled: last bend right, so left | **fooled:** last bend left, so right |
  | A bend the expected way is the expected turn | **fooled:** the first bend | **fooled:** the second bend |

  A fooled player takes the opposite turn at the next junction, or at a decoy (which offers that turn as its wrong exit, X1). Either way the result is a disaster, as for any wrong turn.
- **X3. Both sides are needed.**
  - **What:** with one side only, a slide's first bend gives away the next turn. With forward slides only it always matches the next turn, and with backward only it never does: either way it's a hint, not a trick. With both, half each, the first bend matches the next turn half the time, and so does the second.
  - **Fix:** Q2's default is both sides, with `slide_back_share` 0.5 in every area. PR 1 is forward only, and PR 3 turns on no chance until PR 2 has made backward slides.
- **X4. Backward slides break the path's −x/−y invariant.**
  - **What:** a backward slide steps E or S, against road_generator.gd:9–14. Three things rest on that invariant:
    - **(a) R5's proof** that every junction keeps its wrong exits (docs/ROADGEN.md:20, §5.3).
      - Today's areas never break it at margin 2 (X16).
      - An area with straights of 2–12 tiles does. Without a veto, 371 of 400 runs had an opposite-turn dead end shorter than 2 tiles, 1,022 in all.
      - At margin 1 even the game's road does: 363 short ends in 260 of 400 runs.
    - **(b) Props.** Path tile k lies on screen row k, the tiles whose cells add up to −k (prop_layout.gd:7). After a backward slide whose C1 is tile p, C2 lies on tile p−1's row, and every later tile j on row j−2. A chicane can't win the rows back. `PropScatter` and `PropLayout` rest on the rule four ways:
      - It keys its rows by path index (prop_scatter.gd:61). Rows p−1 and p would get their props twice: doubled sprites, darker shadows, two lamps' glow.
      - `_fade()` finds rows by screen position (`SeeThrough.rows()`, see_through.gd:26), so it would look in the wrong rows.
      - Its guard counts path indices (prop_scatter.gd:174). With b backward slides between a row and the buffer's last tile, a later dead end can come 2b−1 rows down into the reach of the row's props.
      - `PropLayout.span()` spreads a row's props across the screen from each of the `PROP_AHEAD` path tiles below the row's (prop_layout.gd:105), which the car drives while the row shows ahead. With b backward slides among them, they cover only `PROP_AHEAD` − 2b rows, so the view from the car's first tiles below the row can reach past the row's props.
    - **(c) The buffer's margins** count path tiles (road_buffer.gd:3–4) but stand for screen rows (tuning.gd:6–20):
      - `BUFFER_REFILL_AT`, 37, is one over `PROP_AHEAD` + `PropLayout.rows_needed()`, 24 + 12. With b backward slides ahead of the car, a guard in rows would show props 2b−1 rows short of `PROP_AHEAD`.
      - `BUFFER_BEHIND`, 20, leaves a freed straight-on dead end 45 px below the tallest view at top speed, where 19 leaves 13 (tuning.gd:14–20). One backward slide behind the car makes it 18 in rows, and the dead end's end comes 19 px into view.
      - `test_props_in_view.gd` and `test_camera_rig.gd:199` check these on today's road.
    - **(d) Comments** that say the path heads only N or W, or count the buffer and the props in tiles: road_generator.gd:9–14, world_renderer.gd:6–7, prop_layout.gd:7, 41 and 95–99, road_buffer.gd:3–4, prop_scatter.gd:3–8 and 60, tuning.gd:6–20 and 43–47, and test_camera_rig.gd:191–198.
  - **Fix:** PR 2 adds the veto, counts the buffer and the props in screen rows, and rewrites those comments (§5.7). Without a backward slide, nothing changes (§5.7.2, E10). PR 1's forward slides keep the invariant: they need none of it.

### Medium

- **X5. Which straights can slide.**
  - **What:** C1 and C2 lie side by side across the heading, so the car drives a slid straight of s tiles in s−1 tiles' time (X7). The margins need s ≥ 6 (§5.2). So:
    - the City (straights of 2–5 tiles) can't slide;
    - Rural (3–7) slides only at 6 or 7 tiles;
    - the Meadows and the Desert (6–12) and the Village (4–8) slide often.
  - **Fix:** a straight's length decides whether it may slide (§5.2), and Q5's chances are set per area with that in mind.
- **X6. Readers of the exit heading.**
  - **What:** two places take a straight's exit to be its heading:
    - `path_progress` (car_sim.gd:229);
    - the pattern test (test_road_generator_pattern.gd:82).

    A corner leaves by a side edge. With `heading`, the car's progress on C2 measures its offset across the road, not its place along it. With the exit heading, the progress on a corner still depends on which half is nearer: it varies with the car's offset, and falls as the car steers back across C2 (N3). Separately, line 79 asserts every heading is N or W, and a backward slide's C2 heads E or S.
  - **Fix:** add `RoadTile.exit_heading()` (§5.1), for test line 82. `path_progress()` measures a slide's corners along the straight instead (§5.4), and line 229 stays as it is. PR 2 lets line 79 accept a slide's C2.
- **X7. SP's E1 has 3.6 s of headroom.**
  - **What:** pier seed 4993 takes 306.4 s of its 310 s (docs/SPEEDUP.md:50).
  - **Evidence:** a slide costs no time, since X5's cut tile saves about 0.18 s at 5.5 tiles/s (about 2.7 s a run at Q5's chances). Braking for a slide would cost about 0.7–1 s each, 10–15 s a run.
  - **Fix:** no braking (Q4). P1 measures.
- **X8. Steering can't follow a slide.**
  - **What:** `STEER_RATE`, 3 rad/s (tuning.gd:102), turns the car a quarter turn in 0.52 s. At `GLOBAL_SPEED_CAP`, 7 tiles/s, that's 3.7 tiles. A slide's bend and bend back take one tile.
  - **Fix:** the carry (§5.3, Q3). A player who steers into the bend anyway turns the car off its lane after the slide (§8).
- **X9. The autopilot's aim.**
  - **What:** the autopilot steers at `centreline_point(progress + 0.9)` (autopilot.gd:20), a polyline through tile centres (road_buffer.gd:79–87). Its segment from C1's centre to C2's runs sideways, so the autopilot would turn the car across while the carry also moves it.
  - **Fix:** the carried aim (§5.5), in PR 1.
- **X10. A new tile type on the road.**
  - **What:** `Type.CORNER` (road_tile.gd:7) is never generated. Its readers:
    - `type`: world/hitchhiker.gd:107, world_renderer.gd:199, prop_layout.gd:220 and greybox_atlas.gd:38;
    - `heading`: §5.6.

    Every area's road sheet has a column per exits mask, corners included (greybox_atlas.gd:4–5). But only the City's tutorial loops have put corners on screen in the ROAD row, so the corners of Rural, the Meadows, the Village and the Desert have never been seen.
  - **Fix:** §5.6 checks every reader. P3 looks at the corner art, and PR 3 fixes the art in `tools/art/` if P3 finds a flaw.
- **X11. Slides need a stream of their own.**
  - **What:** a roll from `_rng_road` would move every later junction's kind and dead ends, even on straights that don't slide.
  - **Fix:** `_rng_slide`, seeded with `hash("%d:slide" % run_seed)`, draws three rolls per sampled straight, whether it slides or not (§5.2; Δ IP §5.3, D8).

### Low

- **X12. Steering off and coming back.** The carry latches, so a car is carried through a slide or not as it enters the band, whatever it then does (§5.3). Off the road, distance and damage count as anywhere else.
- **X13. The tutorial.**
  - Its straights come from `_rng_tutorial` (road_generator.gd:272), not `_sample_straight()`, so they draw no slide rolls and never slide.
  - The City's chance is 0.
  - `_rescue` (car_sim.gd:436) runs only in the tutorial.
- **X14. The braking estimate.**
  - Outside the tutorial, `distance_to_turn()` (car_sim.gd:184) is `distance_to_junction()` (car_sim.gd:174), which counts path tiles, so it is a tile out before and through a slide (§5.4).
  - Braking starts within `junction_brake_distance` of the junction (car_sim.gd:255–271): 1.25 tiles, or 1.5 in the Desert and the Coast. The carry ends at least 2.8 tiles before it (§5.2), and `AreaDef.validate()` keeps it so (§5.4).
  - So braking is as before.
- **X15. The chord margins.** At h = 0.2, every carried chord stays on the road for any \|w₀\| ≤ 0.32 at any speed up to `GLOBAL_SPEED_CAP`, as on a straight. §5.3 proves it for h ≤ 0.2033. A larger h dips off the road at or near the lane's edge (§6.5).
- **X16. The veto never fires today.** At margin 2, no area of today's game ever needs it (§6.5), so PR 2's veto is only defensive. It is tested on a wide area, whose straights run 2–12 tiles.

## 3. Decisions and open questions

Each Q# has a default, which the plan follows unless the owner answers otherwise when merging `sl/plan`.

| Q# | Question | Default | Why |
|---|---|---|---|
| Q1 | Which trick should it be? The options are the slide, the warp (§5.12), real bends the player must steer, or one of §10's. | The slide | It fools bend readers with a road that the sim drives on. The warp fools the same players with no sim change, but it bends the car and the props with the road. Nobody can steer real bends at speed (X8). |
| Q2 | Should slides go to both sides, or forward only? | Both, half each | X3. Forward only would drop PR 2, with its veto and its screen rows (§5.7), but it would make the slide a hint. |
| Q3 | How does the car get across: the carry, a self-steer, or the player? A self-steer means the sim swings the car's angle through the bends. | The carry | The player can't (X8). A self-steer swings the car up to 75° and back within 4 frames at 7 tiles/s, which reads as a twitch. The carry keeps the car's angle. |
| Q4 | Should the car brake for a slide? | No | X7: it would cost 10–15 s a run against the 3.6 s that SP's E1 has to spare (E6). A slide isn't a turn (E3). |
| Q5 | What are each area's chances? | `slide_chance` is 0.15 in Rural, 0.2 in the Meadows and the Village, 0.25 in the Desert, and 0 in the City and the Coast. `slide_back_share` is 0.5 everywhere. | About 15 slides a run: 14.8 to the pier and 14.6 home in the model (§6.5). The City has none, because its straights are too short (X5). The Coast has none, because its only straight is the finishing one, which no turn follows (§5.2). |
| Q6 | Is `SLIDE_MARGIN_TILES` 2 or 1? | 2 | At 1, the carry ends 1.8 tiles before the junction, close to the 1.5-tile brake point, and the City's 4- and 5-tile straights would slide. The game's road would also need the veto (X4a). |
| Q7 | Should the carry be marked: a tilt of the car's sprite, dust, or a tyre squeal? | None: the car keeps its frame | The slide should read as the road's bend. An effect would need M7's audio or new art. P3 decides whether the sideways move looks wrong without one. |
| Q8 | Do SP's E1 limits stay, 300 s and 310 s? | Yes | E6. Slides save time (X7). |
| Q9 | Should one of §10's tricks be pursued too? | Not now | Each would be a plan of its own. The mirage comes first if the owner wants players who go by the screen fooled too (X1). |

## 4. Work breakdown

The stack: `sl/plan` (this plan, which the owner merges) ← `sl/1-slides` (PR 1) ← `sl/2-back` (PR 2) ← `sl/3-areas` (PR 3). `sl/prototype` branches from `sl/plan` and never gets a PR (planning.md §2). Each PR's commits end with the Copilot trailer (AGENTS.md §4).

### 4.1 The prototype (`sl/prototype`)

1. Record `main`'s counts at e73f96d (AGENTS.md §3): scripts loaded, tests, asserts, GUT time, and `smoke.sh`'s autopilot line.
2. Build PR 1's and PR 2's code roughly, with Q5's chances.
3. Run P1–P7 (§6.5), and check the Python models against them.
4. Run the whole suite with Q5's chances on, and list each test that fails, with why. PR 2 fixes those that test rows or props (§5.7), and PR 3 the rest (§4.4).
5. Put the measured numbers and the list into this plan, on `sl/plan` while its PR is open or else in PR 1, citing the prototype's commits. The owner tags the prototype at the end (§7).

### 4.2 PR 1: `sl/1-slides`, forward slides

Every area's chance stays 0, so the game's road doesn't change (E10). The slides are made, carried, driven and tested on fixtures.

| Area | Files | What |
|---|---|---|
| road | `road/road_tile.gd` | `slide_side`, -1 on any tile that isn't a slide's corner, and `exit_heading()` (§5.1) |
| road | `road/road_generator.gd` | <ul><li>`_rng_slide`, beside line 72, seeded beside line 98.</li><li>The slide's fields.</li><li>`_sample_straight()` (line 422) draws the rolls, and the static `slide_roll()` and `slide_place()` (§5.2).</li><li>`next_tile()`'s straight branch (lines 133–138).</li><li>`_plan_slide()` and `_corner_tile()`.</li><li>A paragraph in the header (§5.2).</li></ul> Forward side only. |
| road | `road/road_geometry.gd` | The static `slide_offset(u)` and `slide_corner(tile, buffer)` (§5.3) |
| areas | `areas/area_def.gd` | `slide_chance`, from 0 to 1 with a default of 0, after `decoy_chance` (line 24). `validate()` (line 75) checks its range, and that an area that slides brakes no earlier than a carry ends (§5.4). |
| config | `config/tuning.gd` | `SLIDE_MARGIN_TILES := 2` and `SLIDE_HALF_SPAN := 0.2`, after `START_STRAIGHT_TILES` (line 22) |
| car | `car/car_sim.gd` | <ul><li>`step()` splits a move where it enters a band, and its lines 120–148 become `_move()`.</li><li>`_carried_by`, `_carried_offset`, `_band_entry()` and `_carry()` (§5.3).</li><li>`path_progress()` measures a slide's corners along the straight (§5.4).</li></ul> |
| car | `car/autopilot.gd` | The carried aim (§5.5) |
| tests | `tests/unit/test_road_tile.gd` (new); `test_road_generator_slides.gd` (new); `test_car_sim_slide.gd` (new); `tests/sim/test_autopilot_slides.gd` (new); `test_road_geometry.gd`; `test_area_def.gd`; `tests/helpers/road_fixtures.gd`; `test_road_generator_pattern.gd:82` | §5.10. The fixtures gain `slide_schedule(chance, least, most)`. |

Steps:
1. Add `RoadTile`'s field and method, and `test_road_tile.gd`.
2. Add the generator's stream, rolls, plan and corners (§5.2).
3. Add the AreaDef field, its checks and the Tuning constants.
4. Add `slide_offset()`, `slide_corner()`, the split move, the latched carry and the corners' progress (§5.3, §5.4).
5. Add the autopilot's carried aim (§5.5).
6. Write the tests, with N1–N14, N22, N23, N25 and N26 (§6.2).
7. Run the checks.

About +36 tests. The digests hold.

### 4.3 PR 2: `sl/2-back`, backward slides and screen rows

Every area's chance is still 0, so with no backward slide the buffer, the props and the digests are as today (§5.7.2, E10).

| Area | Files | What |
|---|---|---|
| areas | `areas/area_def.gd` | `slide_back_share`, from 0 to 1 with a default of 0.5, and its check in `validate()` |
| road | `road/road_generator.gd` | <ul><li>The backward side and `_slide_fits()`, the veto (§5.7).</li><li>The header: lines 9–14 rewritten (Δ).</li></ul> |
| road | `road/road_tile.gd` | `screen_row()` (§5.7) |
| road | `road/road_buffer.gd` | <ul><li>Fills and frees by screen rows, from the highest row the car has reached: `start()` (line 25), `on_car_path_index()` (lines 31–37), `_generate_to()` (line 90) and `_free_before()` (line 101).</li><li>`on_car_path_index()` sets the car's row before it emits `tiles_generated`, as it sets `_car_index` today (§5.7.3).</li><li>New `car_row()`, `last_row()`, `rows_ahead()` and `lowest_row()`. `lookahead()` stays in tiles.</li><li>The doc comment, lines 3–6.</li></ul> |
| world | `world/prop_scatter.gd` | <ul><li>`_rows` keyed by screen row (line 61), each `Row` with the anchor it was shown from.</li><li>`_show_rows()` (line 172) walks the path tiles, with the guard in rows.</li><li>`bind()` (line 102) and `_on_tiles_freed()` (line 164) use `lowest_row()`.</li><li>`anchor()` (line 184) returns the stored anchor.</li><li>The header, lines 3–8, and line 60.</li></ul> |
| world | `world/prop_layout.gd` | `span()` counts rows (line 105), and the comments at lines 7, 41 and 95–99 |
| world, config | `world/world_renderer.gd`, `config/tuning.gd` | The comments at world_renderer.gd:6–7, and tuning.gd:6–20 and 43–47 |
| tests | `test_road_generator_slides.gd`; `test_car_sim_slide.gd`; `test_road_tile.gd`; `test_road_buffer.gd`; `test_prop_scatter.gd`; `test_prop_layout.gd`; `test_camera_rig.gd`; `test_road_generator_pattern.gd:79`; `test_area_def.gd`; `road_fixtures.gd` | §5.10, and in old tests:<ul><li>The buffer's tests at lines 29–57 count rows.</li><li>`test_prop_scatter.gd:113` counts rows, up to the highest car row.</li><li>In `test_prop_layout.gd`, `_road()` (line 77) and `_placed_again()` (line 688) key rows as PropScatter does, and the spread test (line 284) counts rows.</li><li>Line 79 accepts a slide's C2.</li><li>`slide_schedule()` gains `back_share`, and the fixtures gain `wide_schedule()`, with straights of 2–12 tiles.</li></ul> |

Steps:
1. Add the AreaDef field and the backward side.
2. Add the veto.
3. Add `screen_row()`, and fill and free the buffer by rows.
4. Key the props by screen row: the walk, the anchors, the guard and `span()`.
5. Rewrite the comments.
6. Write the tests, with N15–N21, N24 and N27 (§6.2).
7. Run the checks.

About +21 tests. The digests hold.

### 4.4 PR 3: `sl/3-areas`, the chances and the docs

| Area | Files | What |
|---|---|---|
| areas | `areas/rural.tres`, `meadows.tres`, `village.tres`, `desert.tres` | Q5's `slide_chance`. `slide_back_share` keeps its default of 0.5, so it isn't saved. |
| tests | `test_road_generator_determinism.gd:11–12` | The new digests. The commit says why (docs/ROADGEN.md §6.1). |
| tests | Those on §4.1's list left to PR 3 | Each fixed as §4.1 says |
| art | `tools/art/…`, `assets/…` | Corner fixes, if P3 found any |
| docs | `plan.md` §3.2; `docs/SLIDE.md` (new, replacing this plan); `docs/ROADGEN.md`; `IMPLEMENTATION_PLAN.md`; `docs/README.md`; `AGENTS.md`; the code's citations | §5.11 (E9) |

No new tests. 47 test scripts build roads from the real areas (`Fixtures.schedule()`, `endless()`, `schedule_home()` or the `.tres` files), so with the chances on they become the slides' widest check: `test_drive_to_the_end.gd` (E6), `test_props_in_view.gd` and `test_camera_rig.gd` (E7) among them. P1's times go into the PR body and docs/SLIDE.md. The gathered Fold4 list (§6.4) goes into the body, with a debug build, mentioning @pompomon (planning.md §5).

### 4.5 Landing

1. The owner merges `sl/plan`, which approves the plan, with Q1–Q9 answered or left at their defaults.
2. Agents land PR 1, then PR 2, each once its base is `main`, with `tools/agent/land_pr.sh <n>` (AGENTS.md §5 step 4).
3. The owner lands PR 3, labelled `needs-owner`. It is the plan's last PR, after the device checks, and it changes `AGENTS.md` and `docs/README.md`.

### 4.6 Review fixes

| PR | Comment | Fix | Tests | Negative case |
|---|---|---|---|---|
| | None yet. | | | |

## 5. Design

Each edge case is said once, here, and cited elsewhere (AGENTS.md §2).

### 5.1 The jog

A slide on a straight that heads H, to side S, takes two of the straight's tiles: C1 at path index k and C2 at k + 1.

| Tile | Cell | `type` | `heading` | `exits` | `slide_side` |
|---|---|---|---|---|---|
| C1 | c | `CORNER` | H | opposite(H), S | S |
| C2 | c + VEC[S] | `CORNER` | S | opposite(S), H | S |
| k + 2 | c + VEC[S] + VEC[H] | `STRAIGHT` | H | opposite(H), H | −1 |

- **Forward:** S is the next turn's side, `Heading.turn_for(turn_count + _parity, _heading)` (road_generator.gd:197): W on an N road, N on a W road. A decoy changes neither the heading nor the turn count (line 215), so it doesn't change the forward side either.
- **Backward:** S is the opposite side, E on an N road and S on a W road. A backward C2 is the only path tile that heads E or S.
- **Masks** (N 1, E 2, S 4, W 8). Between them, the four kinds of slide use all four corner masks, and every road sheet has a column for each (X10):

  | Road | Forward: C1, C2 | Backward: C1, C2 |
  |---|---|---|
  | N | W: 12, 3 | E: 6, 9 |
  | W | N: 3, 12 | S: 6, 9 |

`RoadTile` gains these in PR 1:

```gdscript
## The side that a slide's corner steps the road to (SLIDE_PLAN.md §5.1), or -1 on any other tile.
var slide_side := -1


## The heading the path leaves the tile by: a junction's expected exit, a corner's other exit, or
## else the heading it was entered by.
func exit_heading() -> int:
	if is_junction():
		return expected_exit
	if type == Type.CORNER:
		for h: int in 4:
			if h != Heading.opposite(heading) and has_exit(h):
				return h
	return heading
```

PR 2 adds `screen_row()` (§5.7.2).

On a slide's corner, C1's `heading` isn't its `slide_side` and C2's is. `RoadGeometry.slide_corner(tile, buffer)` returns the slide's C1 from either corner: the tile itself, or `buffer.path_tile(tile.path_index - 1)`. On any other tile, or null, it returns null. It takes the buffer as `PropLayout.span()` does (prop_layout.gd:100). The buffer still holds C1 while the car is on C2, since it holds `BUFFER_BEHIND` tiles behind the car.

### 5.2 Placement

**The stream (X11).** `_rng_slide` is seeded with `hash("%d:slide" % run_seed)`, beside line 98. Each call of `_sample_straight()` (line 422) draws three rolls from it, whether or not that straight will slide:
1. whether it slides;
2. which side (PR 2);
3. where.

So the slide stream's state depends only on how many straights have been sampled. A chance changes which straights slide, but no other straight's rolls, and the road's stream draws exactly as before (E2).

**Planned at the straight's first tile.** `_junction()` samples the next straight, at line 223 or through `_enter_area()` (lines 230 and 419), and only then sets `_pit_stop` (line 231) and `_finishing` (line 232). So `next_tile()` plans the slide at the straight's first tile, in `_plan_slide()`, from the rolls that the sample left.

A straight of s tiles slides if all of these hold at its first tile:
1. `_sample_straight()` drew it. The start straight (line 66) and the tutorial's (line 302, X13) are drawn elsewhere, and set pieces are laid by their own branch (line 125).
2. It isn't a pit stop's (`_pit_stop`), whose straight has its own art (world_renderer.gd:199). The finishing straight may slide, though no turn follows it to mislead about. `_sample_straight()` draws it like any other, and leaving it out would make a finishing road differ from the endless one before the finish, as docs/ENDGAME.md E1 forbids and test_road_generator_finish.gd:103–136 checks. On the game's road and the road home, that straight is the Coast's or the City's, and neither slides (Q5).
3. s ≥ 2m + 2 = 6, where m = `SLIDE_MARGIN_TILES` = 2.
4. Its first roll is below `current_area.slide_chance`.
5. In PR 2, a backward slide also needs the veto to pass (§5.7.1).

**The rolls.** Each roll is `slide_roll(_rng_slide.randi())`, one draw of 32 bits over 2³², so it is below 1, as a chance of 1 needs. `randf()` can return 1.0.

**Where.** C1 is the straight's tile `slide_place(roll₃, s)` = m + ⌊roll₃ · (s − 2m − 1)⌋, counting from 0. That places it from m to s − m − 2, uniformly, so at least m straight tiles lie before C1 and at least m after C2.

C2 is at most the straight's tile s − m − 1, and the junction follows the straight's last tile, s − 1, so it lies at least m + 1 tiles along H from C2's centre. The carry ends `SLIDE_HALF_SPAN` (h) along H from C1's and C2's centres, so it ends at least (m + 1) − h = 2.8 tiles before the junction's centre, both driven and by progress (§5.4).

```gdscript
const NO_SLIDE := -2
const TWO_POW_32 := 4294967296.0

## The slides' stream (SLIDE_PLAN.md X11).
var _rng_slide := RandomNumberGenerator.new()
## The rolls that _sample_straight() drew for the straight to come: whether it slides, its side and
## its place. Empty once _plan_slide() has read them.
var _slide_rolls := PackedFloat64Array()
## Straight tiles to lay before the planned slide's C1: 0 when C1 is next, -1 when C2 is, or NO_SLIDE.
var _slide_at := NO_SLIDE
var _slide_side := -1
## The straight's heading, which C2 turns the road back to.
var _slide_heading := -1


## A roll from 32 random bits: from 0 up to, but not including, 1.
static func slide_roll(bits: int) -> float:
	return bits / TWO_POW_32


## The straight's tile, counting from 0, that a slide placed by `roll` puts its C1 on: from
## SLIDE_MARGIN_TILES to `length` - SLIDE_MARGIN_TILES - 2 (SLIDE_PLAN.md §5.2).
static func slide_place(roll: float, length: int) -> int:
	var margin := Tuning.SLIDE_MARGIN_TILES
	return margin + floori(roll * (length - 2 * margin - 1))


func _sample_straight() -> int:
	_slide_rolls = PackedFloat64Array()
	for _i: int in 3:
		_slide_rolls.append(slide_roll(_rng_slide.randi()))
	return _rng_road.randi_range(current_area.min_straight, current_area.max_straight)


## At a straight's first tile: plans its slide from the rolls that _sample_straight() drew, or none.
func _plan_slide() -> void:
	var rolls := _slide_rolls
	_slide_rolls = PackedFloat64Array()
	if _pit_stop or _straight_left < 2 * Tuning.SLIDE_MARGIN_TILES + 2:
		return
	if rolls[0] >= current_area.slide_chance:
		return
	var side := Heading.turn_for(turn_count + _parity, _heading)
	var back := rolls[1] < current_area.slide_back_share  # PR 2
	if back:
		side = Heading.opposite(side)
	var at := slide_place(rolls[2], _straight_left)
	if back and not _slide_fits(at, side):  # PR 2
		return
	_slide_at = at
	_slide_side = side
	_slide_heading = _heading


## A slide's corner on the cursor: C1 turns the road to the slide's side, and C2 turns it back.
func _corner_tile() -> RoadTile:
	var tile := _path_tile(RoadTile.Type.CORNER)
	tile.slide_side = _slide_side
	var out := _slide_side if _slide_at == 0 else _slide_heading
	tile.exits = Heading.bit(Heading.opposite(_heading)) | Heading.bit(out)
	_heading = out
	return tile
```

The straight branch of `next_tile()` (lines 133–138) becomes:

```gdscript
	elif _straight_left > 0:
		if not _slide_rolls.is_empty():
			_plan_slide()
		if _slide_at == 0 or _slide_at == -1:
			tile = _corner_tile()
		else:
			tile = _path_tile(RoadTile.Type.STRAIGHT)
		if _slide_at != NO_SLIDE:
			_slide_at -= 1
		tile.pit_stop = _pit_stop
		...
```

Two details:
- **The cursor and the claim.** Line 143 moves the cursor by the new `_heading`. `_path_tile()` claims the cell with the tile object itself (line 184), so the exits set after the claim are the ones the occupancy holds.
- **The header (Δ).** PR 1 adds a paragraph to the header at lines 9–14: forward slides step N or W, so the path still heads only N or W. PR 2 rewrites that paragraph for backward slides (§5.7).

### 5.3 The carry

**The frame.** u runs along H and w towards S, both from C1's centre. The carried centreline is w = σ(u), with `σ(u) = smoothstep(-h, h, u)` and h = `SLIDE_HALF_SPAN` = 0.2:
- σ is exactly 0 up to u = −h and exactly 1 from u = +h, so the band is −h < u < h;
- it is steepest at u = 0, with a slope of 1.5/(2h) = 3.75, or 75°.

`RoadGeometry.slide_offset(u)` returns σ(u).

**The rule.** `step()` splits a move that enters a slide's band from outside, where it enters, if the car is there on the road of the corner that it drives from, in that corner's cell: C1 going forward, C2 going back. The cell is `floor()`'s, as in `cells_crossed()` (car_sim.gd:204–205). The road is the one that `_follow_road()` will find there: the move up to that point ends on the last of the corner's `RoadGeometry.on_road_spans()`, the very spans by which `_follow_road()` judges the first part's end (car_sim.gd:328). Not `is_on_road()`, which can round apart from them at the road's very edge (N27), so that the first part would end off the road. It judges the first part as it judges any move, and then calls `_carry()` before it judges the rest. Lines 120–148, the path and the rules, become `_move(from, delta) -> bool`, which returns false where they return now. Each part passes its share of `delta`. The first part ends on the road, so no time off it is left to count there, and its rules find what the whole move's would up to there, but for rounding. That tips only a value at its limit: a health within rounding of the damage, or a move that runs along the road's edge, within rounding of it, which may then leave or rejoin the road up to a tick sooner or later, as rounding decides anyway where such a move is on the road. A run that ends in the first part ends there, at the band's edge. `_leave_road()` judges whether the car is near the next junction at the part's end (line 350), but every cell level with the band is at least m + 1 grid steps from it (§5.2). Any other move is judged whole, as today: one that enters the band off the road, even in the corner's cell (N26), or in another cell (N8).
- **The latch.** A split move latches onto the slide. So a car that rejoins the road before the band is carried, and one off the road where it enters is not.
- **The carry.** While latched, each move moves the car as far across as the carried centreline moves, however it steers, on the road or off it. `_carried_offset` keeps the car's offset from that centreline, so that `pos`'s rounding doesn't add up (Rounding, below). Its angle and speed don't change. Neither do `dist_total` and `dist_on_straight` (lines 118–119), which count the distance driven.
- **The release.** The move that ends outside the band lets go. A latch holds for one slide: it lapses if `path_tile` is on neither of that slide's corners.

`_band_entry(from, to)` finds C1 as `_carry()` does. If σ is 0 or 1 at `from` and not at `to`, it returns the fraction of the move at which u reaches the band's edge, −h going forward and h going back, if that point, `from.lerp(to, fraction)` as `step()` puts it, is on the rule's road, in its cell. Otherwise it returns −1.

```gdscript
	# step(), from line 116:
	var from := pos
	var to := pos + velocity() * delta
	dist_total += speed * delta
	dist_on_straight += speed * delta
	var entry := _band_entry(from, to)
	if entry > 0.0:
		pos = from.lerp(to, entry)
		if not _move(from, entry * delta) or is_over():
			return
		from = pos
	pos = to
	_carry(from, entry >= 0.0)
	if _move(from, (1.0 - maxf(entry, 0.0)) * delta) and trigger.tutorial:
		_tutorial_step(delta)


## The C1 of the slide whose carry has the car (SLIDE_PLAN.md §5.3), or null.
var _carried_by: RoadTile
## The carried car's offset from the carried centreline, kept apart from pos's rounding.
var _carried_offset := 0.0


## Carries a latched car as far across as the carried centreline moves, until it leaves the band.
## A move that `entered` the band at `from`, on the road, as `_band_entry()` judges, latches
## (SLIDE_PLAN.md §5.3, X12).
func _carry(from: Vector2, entered: bool) -> void:
	var c1 := RoadGeometry.slide_corner(path_tile, buffer)
	if c1 != _carried_by:
		_carried_by = null
	if c1 == null:
		return
	var centre := Iso.cell_centre(c1.cell)
	var along := Vector2(Heading.VEC[c1.heading])
	var across := Vector2(Heading.VEC[c1.slide_side])
	var w_from := (from - centre).dot(across)
	if entered:
		_carried_by = c1
		_carried_offset = w_from - (0.0 if (from - centre).dot(along) < 0.0 else 1.0)
	if _carried_by == null:
		return
	var now := RoadGeometry.slide_offset((pos - centre).dot(along))
	var w := (pos - centre).dot(across)
	_carried_offset += w - w_from
	pos += across * (_carried_offset + now - w)
	if now == 0.0 or now == 1.0:
		_carried_by = null
```

**Why the corner, not the lane.** On the road's inner corner, a car can be on the road but off the slide's lane. A test of the lane, |w − σ| ≤ `ROAD_HALF_WIDTH`, would be a cliff there: a car on the lane's edge would be carried onto C2's lane, or, by rounding, not carried, and then drive off C1's side, 0.36 tile from the road. With the corner test, a car that enters the band on the road, heading along it, ends at most 0.18 tile off it, carried or not, and that only at the corners' boundary. A car that has cut into the other corner before the band isn't carried: it drives the jog itself, as a player who steers into the bend early does (§8).

**Why it holds:**
- **The steps in the band.** A step moves at most `GLOBAL_SPEED_CAP`/60 = 0.117 tile, so a step that touches the band starts and ends with |u| < h + 0.117 = 0.317. On the road, such a step lies in C1's cell or C2's. `_update_path()` has made that tile `path_tile`, whichever way the car came (car_sim.gd:285–299), and `slide_corner()` finds C1 from either. A carried step moves at most 0.117 + 3.75 · 0.117 = 0.55 tile, under the one tile that `step()` and `cells_crossed()` allow (car_sim.gd:101 and 201).
- **The cells.** For |w₀| ≤ 0.32, a carried car enters C2 between u = −0.09 and 0.09, where w passes 0.5, and enters tile k + 2 at u = 0.5. So `cells_crossed()` (line 125) sees C1, C2 and then k + 2, one path index at a time, as `_update_path()` and `JunctionTrigger.on_cell_crossed()` expect (E3). The step that enters C1 has `path_tile` k − 1 and isn't carried, but it ends by u = −0.38, before the band.
- **The road.** `_follow_road()` tests each cell's part of a step against that cell's capsules (car_sim.gd:321–340). For |u| ≤ R = `ROAD_HALF_WIDTH` = 0.32, take the region lower(u) ≤ w ≤ upper(u), where:
  - lower(u) is −R for u ≤ 0, and −√(R² − u²) for u ≥ 0;
  - upper(u) is 1 + √(R² − u²) for u ≤ 0, and 1 + R for u ≥ 0.

  In each of the two cells, the region's part lies in that cell's capsules. The region is convex, and it holds every point within R of the carried centreline, |w − σ(u)| ≤ R. Since h + 0.117 ≤ R, each part of a step that touches the band lies in the region, chord and all, if it starts and ends on the car's lane, however the car steered. Every other step keeps σ at 0 or 1, as on a straight. So a car on its lane leaves the road in a slide only where it would on a straight, and the model finds the least margin to be the straight's, R − |w₀| (§6.5). This needs h ≤ R − `GLOBAL_SPEED_CAP`/60 = 0.2033 (X15). At \|w₀\| = 0.32 exactly, the car is on the road's edge, and rounding decides, as on any straight: E4 and its test stop at 0.318.
- **Back.** Driving back, u falls, and the same rule carries the car back (E4).
- **Rounding.** `pos` holds 32-bit floats, 2⁻¹⁵ tile apart from 256 to 512 tiles out. Moved by `across * (now - was)`, the car would keep each step's rounding, which puts 1 of 320 drives near the lane's edge off the road (§6.5). `_carried_offset` adds up only the car's own moves, each exact, as `pos - centre` is (Sterbenz's lemma). Once σ is 0 or 1, the last move is a whole number of the floats' steps, so the car leaves the band at the offset it entered with, plus its own moves. Only past a power of 2, P tiles out, where the steps double, may it round once, by up to P·2⁻²⁴ tile: 0.00006 at 1,024. To 32,768 tiles out, that is within E4's margin of 0.002 tile, but a car nearer the road's edge, which a straight keeps on the road, may end off it (§6.5).
- **An ended run.** Once the run is over, `step()` returns before it reaches the carry (lines 104–113): an arrived car rolls on the finish, and any other brakes in a straight line.

The carry lasts 3.4 to 12 frames, at 7 to 2 tiles/s (§6.5).

### 5.4 Progress and braking

**Progress.** `path_progress()` (car_sim.gd:226–233) measures a tile along its entry half or its exit half, whichever is nearer the car. On a slide's corner that won't do, even with `exit_heading()` at line 229 (X6, N3). So `path_progress()` gains a branch at its top (line 227), `if tile.slide_side != -1: return _slide_progress(tile, p)`, and line 229 stays as it is:

```gdscript
## Progress on a slide's corner (SLIDE_PLAN.md §5.4): C1's index plus the place along the straight,
## from -0.5 at C1's entry edge to 0.5 at C2's exit edge, plus the carried centreline's step
## across. So it meets the tiles' progress before C1 and after C2.
static func _slide_progress(corner: RoadTile, p: Vector2) -> float:
	var c2 := corner.heading == corner.slide_side
	var straight := corner.exit_heading() if c2 else corner.heading
	var c1_cell := corner.cell - Heading.VEC[corner.slide_side] if c2 else corner.cell
	var u := (p - Iso.cell_centre(c1_cell)).dot(Vector2(Heading.VEC[straight]))
	var c1_index := corner.path_index - 1 if c2 else corner.path_index
	return c1_index + clampf(u, -0.5, 0.5) + RoadGeometry.slide_offset(u)
```

- It runs from k − 0.5 at C1's entry edge to k + 1.5 at C2's exit edge, so it meets the progress of tiles k − 1 and k + 2 at their edges. It depends on u alone, so it doesn't jump between C1 and C2, and it never falls while the car drives on.
- At the carry's end it reads k + 1 + h = k + 1.2, and from there the distance to the junction is exact.

**Its readers:**
- **Braking (X14).** `distance_to_junction()` is the junction's index minus the progress. Before the slide it reads one tile more than the car will drive, because C1 and C2 lie side by side. Across C1 and C2 it falls two tiles while the car drives one. From the carry's end on, it is exact again, and there it is at least 2.8 tiles (§5.2). In an area whose `slide_chance` is above 0, `AreaDef.validate()` requires `junction_brake_distance` ≤ `most_slide_brake_distance()` = `SLIDE_MARGIN_TILES` + 1 − `SLIDE_HALF_SPAN` = 2.8. So braking starts only once the estimate is exact.
- **The run's distance** (ui/main.gd:141, 370 and 471). It reads the progress, so it gains the slide's extra tile during the carry. At each junction it is the same as it would be without the slide.
- **The hitchhiker** (world/hitchhiker.gd:93) compares the progress with the index of the plain straight she stands by (§5.6), and is unchanged.
- **The autopilot:** §5.5.

### 5.5 The autopilot's carried aim

The autopilot aims at `centreline_point(progress + 0.9)` (autopilot.gd:20, X9). Between the car's arrival 0.9 tile before C1's centre and the carry's end, that point lies on the polyline's sideways segment, or past it, while the carry is still to move the car. The carried aim instead aims along the car's own carried lane:

```gdscript
## The point LOOKAHEAD ahead on the carried centreline, while the car is within LOOKAHEAD before a
## slide's carry or in it (SLIDE_PLAN.md §5.5); else on the path's centreline.
func _aim() -> Vector2:
	for k: int in range(floori(_sim.progress), floori(_sim.progress + LOOKAHEAD) + 2):
		var c1 := RoadGeometry.slide_corner(_sim.buffer.path_tile(k), _sim.buffer)
		if c1 == null:
			continue
		var centre := Iso.cell_centre(c1.cell)
		var along := Vector2(Heading.VEC[c1.heading])
		var u := (_sim.pos - centre).dot(along)
		if u >= -LOOKAHEAD and u <= Tuning.SLIDE_HALF_SPAN:
			var across := Vector2(Heading.VEC[c1.slide_side])
			return centre + along * (u + LOOKAHEAD) + across * RoadGeometry.slide_offset(u)
	return _sim.buffer.centreline_point(_sim.progress + LOOKAHEAD)
```

- **Lane only.** The aim is σ(u) across, not σ(u + L), so aim − pos = along · L − across · ω, where ω = w − σ(u) is the car's offset from its carried lane. The autopilot steers only to bring ω back to 0, and a car on its lane's centre isn't steered at all. The carry moves it across.
- **Seamless.** At u = −L, both aims are C1's centre. At u = h, both are C2's centre + along · (h + L), since the progress there is k + 1 + h (§5.4).
- **Why in PR 1.** The plain aim steers the car towards C2 while the carry is still to move it there, so the car would be moved across twice: by its steering and by the carry. `test_the_autopilot_keeps_its_lane_through_a_slide` fails with it (N12).

### 5.6 Readers of the corners

Every reader of a path tile's `type` or `heading` outside the generator, and of the centreline:

| Reader | What it reads | On a slide's corner? | Change |
|---|---|---|---|
| car_sim.gd:95, the start | The first tile's heading | Never: the start straight doesn't slide (E1) | None |
| car_sim.gd:228–229, `path_progress()` | Heading in, exit out | Yes | A branch for a slide's corners (§5.4) |
| car_sim.gd:184, `distance_to_turn()` while lost | Any tile that the car can't drive straight through | Only while the tutorial has lost the car, and the tutorial never slides (X13) | None |
| car_sim.gd:442, `_rescue()` | Its tile's heading | Never: the tutorial's road (X13) | None |
| car_sim.gd:469, `_on_arrived()` | `_finish_axis`, from the heading of the finish's set-piece tile at `finish_index` | Never: a set piece isn't a corner, and after C2 the road heads H again | None |
| junction_trigger.gd:62 and `_junction_after()` (line 175) | Junctions | Never: a corner isn't a junction, and C2 hands the junction its straight's heading | None |
| world/hitchhiker.gd:107 and 122 | The last `STRAIGHT` before her junction, not a pit stop's | Never: a corner isn't `STRAIGHT`, and the margin keeps two straight tiles before each junction | None |
| prop_layout.gd:106, `span()` | The tile below, by heading | Yes: from k + 2 it finds C2, and from C2 it finds C1 | PR 2 counts rows (§5.7.4) |
| prop_layout.gd:220; world_renderer.gd:199; greybox_atlas.gd:38 | `SET_PIECE`, a pit stop, `DEAD_END` | Never | None: a corner draws from its exits' column of the `ROAD` row (§5.8) |
| set_piece.gd:21; pier.gd:75 | A set piece's heading | Never | None |
| road_buffer.gd:79–87, `centreline_point()` | Tile centres | Yes: the polyline runs from C1 sideways to C2 | §5.5 |

### 5.7 Backward slides and screen rows (PR 2)

#### 5.7.1 The veto

`_slide_fits(at, side)` lets a backward slide through only if all of these cells are free (`occupancy.is_free()`):
- C1, `at` tiles up the straight from the cursor;
- C2 and the rest of the straight;
- the junction's cell;
- the junction's cell + VEC[S] and + 2·VEC[S]. These are the first two tiles of its opposite-turn dead end, which leads to the backward side and which R5 needs (docs/ROADGEN.md:20).

The veto reads the occupancy only, and draws no roll, so both streams are unchanged. It doesn't know the junction's kind, which `_rng_road` draws later, so it checks those two cells even for a side road, which has no opposite turn.

Forward slides need no veto: they keep the −x/−y invariant, on which R5's proof rests. §6.5 has the models: the veto never fires on today's areas (X16), and it fires on the wide fixture.

#### 5.7.2 Screen rows

`RoadTile.screen_row()` is `-(cell.x + cell.y)`. Without a backward slide, path tile k is on row k: every step goes N or W, and a forward slide's C2 does too. A backward slide whose C1 is on row r puts C2 on row r − 1 and tile k + 2 on row r. From then on, every tile is two rows below its index.

What holds for the rows:
- **(a) Contiguous.** Neighbouring path tiles are one row apart, so every row between two path tiles' rows holds a path tile.
- **(b) The only dip.** For i < j, row(j) ≥ row(i) − 1. Equality holds only for a backward C1 and its C2. A dip is one step down, and the margins put at least three steps up after it before its junction, and at least six before the next slide's C1.
- **(c) Two at most.** A row holds one or two path tiles, both of one straight and so of one area: tile k − 1 and C2, or C1 and tile k + 2.
- **(d) Within its area.** No path tile lies below its area's first path tile's row, since C1 is at least the straight's third tile. So an area's path tiles still lie between two screen rows, as the ground's bands need (world_renderer.gd:6–7, whose words change).
- **(e) Junctions rise.** A junction lies at least one row above every path tile before it, since each dip's three steps up come first. So a future junction lies above `_last_row`, as every future path tile does today.

#### 5.7.3 The buffer in rows

```gdscript
## The highest screen row of a generated path tile, and the highest row of a path tile that the car
## has reached.
var _last_row := -1
var _car_row := 0


func start() -> void:
	tiles_generated.emit(_generate_to(0, Tuning.BUFFER_AHEAD))


func on_car_path_index(index: int) -> void:
	if index <= _car_index:
		return
	_car_index = index
	var created: Array[RoadTile] = []
	var missing := last_index() < index
	if missing or _last_row - maxi(_car_row, _row_through(index)) < Tuning.BUFFER_REFILL_AT:
		created = _generate_to(index, Tuning.BUFFER_AHEAD)
	_car_row = maxi(_car_row, _row_through(index))
	if not created.is_empty():
		tiles_generated.emit(created)
	_free_below(_car_row - Tuning.BUFFER_BEHIND)


## The highest row of the path tiles up to `index`: its own, or its C1's if it is a backward C2
## (SLIDE_PLAN.md §5.7.2 (b)). A C2 is never the first path tile: it is freed with its C1.
func _row_through(index: int) -> int:
	var row := path_tile(index).screen_row()
	return row if index == _first_index else maxi(row, path_tile(index - 1).screen_row())


## Generates until path index `index` exists and the last generated row is `rows` above the higher
## of the car's row and the highest row up to `index`. Returns the new tiles, each followed by its
## dead-end tiles.
func _generate_to(index: int, rows: int) -> Array[RoadTile]:
	var created: Array[RoadTile] = []
	while last_index() < index or _last_row < maxi(_car_row, _row_through(index)) + rows:
		var tile := generator.next_tile()
		_path.append(tile)
		_last_row = maxi(_last_row, tile.screen_row())
		created.append(tile)
		created.append_array(tile.branches)
	return created
```

- **`_free_before(index)` becomes `_free_below(row)`.** It pops the first path tile, with its branches, while its row is below `row`. A backward C1's C2 is one row lower, so it goes with its C1.
- **The car's row is set before the emit**, as `_car_index` is today (road_buffer.gd:31–37), so a listener reads the buffer as of the move (AGENTS.md §2, state as of the event). That is why `_generate_to()` returns its tiles instead of emitting them. The `or` in its loop stops before `_row_through(index)` while the tile doesn't exist yet.
- **New readers:** `car_row()`, `last_row()`, `rows_ahead()` (`_last_row - _car_row`), and `lowest_row()`, the lower of the rows of the first two path tiles. `lookahead()` and the indices stay as they are.
- **The jump.** `missing` holds only when the car reaches a tile past the last generated one, as the fuzz test's jumps of 40 do (test_road_buffer.gd:38–57). A jump that lands on a backward C2 has passed its C1, so `_row_through()` counts C1's row.
- **No backward slide, no change:** each line does what it does today (§5.7.2, E10).

**The edge cases**, tested by the fuzz test on a backward fixture:
- **The rows of a backward slide.** With C1 on row r, tiles k − 1 to k + 3 are on rows r − 1, r, r − 1, r and r + 1. C2 and tile k + 2 reach no new row, so they leave `_car_row` as it is, and the buffer fills and frees nothing there. The buffer frees only as the car first reaches a row, at its tile's entry edge.
- **Rows ahead:** after each `on_car_path_index()`, `rows_ahead()` is between `BUFFER_REFILL_AT` and `BUFFER_AHEAD`, 37 and 55, a backward C2 included.
- **Rows behind:** the buffer holds rows down to `_car_row - BUFFER_BEHIND`. When the first path tile is a backward C1, it holds one row lower, C2's.
- **Junctions:** a junction is freed when the car first reaches its row + `BUFFER_BEHIND` + 1, as it is reached by index today. So the derivation above `test_camera_rig.gd:199` holds in rows. PR 2 rewrites its comment (lines 191–198, X4d).
- **The dip.** A backward slide's carry takes the car down the screen, at most 0.314 row (10 px) below where it entered C1, which may have freed a junction. Even if the view followed it all the way, a freed straight-on dead end's 45 px below the view at top speed (docs/ROADGEN.md R6) would shrink to 35, still more than `MARGIN`, 32 px (test_camera_rig.gd:18). PR 2's camera test checks it frame by frame (§5.10).

#### 5.7.4 The props in rows

`_rows` is keyed by screen row, and each `Row` stores the `anchor` it was shown from. Below the start, `_next_row` shows the rows of path tile 0's area, as it does today. Above it, `_next_index` walks the path tiles:

```gdscript
func _show_rows() -> void:
	var top := mini(
		_buffer.car_row() + Tuning.PROP_AHEAD, _buffer.last_row() - PropLayout.rows_needed()
	)
	_next_row = maxi(_next_row, _lowest_row)
	while _next_row < 0 and _next_row <= top:
		_show_row(_next_row, null)
		_next_row += 1
	_next_index = maxi(_next_index, _buffer.first_index())
	while _next_index <= _buffer.last_index():
		var tile := _buffer.path_tile(_next_index)
		var k := tile.screen_row()
		if k > top:
			break
		if k >= _lowest_row and not _rows.has(k):
			_show_row(k, tile)
		_next_index += 1
```

The rest of PropScatter:
- **`_show_row(k, tile)`** takes its area from `tile`, or `_first_area` below the start, and stores the anchor: `tile.cell`, or below the start the cell that `anchor()` computes today.
- **`anchor(k)`** returns a shown row's stored anchor, or the computed cell below the start. Any other row is an error (`push_error()`, `Vector2i.ZERO`).
- **Freeing.** `_on_tiles_freed()` hides the rows below `_buffer.lowest_row()`.
- **`bind()`** sets `_lowest_row` to −`BUFFER_BEHIND` on a buffer at index 0, else to `lowest_row()`, and sets `_next_index` to `first_index()`.
- **`_fade()`** (line 271) looks rows up by screen position (`SeeThrough.rows()`, see_through.gd:26), which is now what `_rows` is keyed by (X4b). `rows()`'s comment (line 142) says screen rows.

**The walk, the guard and `span()`:**
- **Breaking at a dip is safe.** By (b), only a backward C2 lies on a lower row than a tile before it. If the walk breaks at its C1, the C2's row was shown already, from tile k − 1. So each row gets its props once, from its first path tile (N16), and the rows with props run from the lowest held row up to the highest car row so far + `PROP_AHEAD`.
- **The guard** binds only before `start()`: after it, `rows_ahead()` ≥ `BUFFER_REFILL_AT` = 37 > `PROP_AHEAD` + `rows_needed()` = 36 (tuning.gd:9). Its count still holds in rows, with today's margins. When row k shows, `_last_row` ≥ k + 12. The road that its props must keep off lies on rows k − 1 to k + `rows_above()`, which is k + 3, and the set pieces within 2·`set_piece_margin()` = 4 rows (prop_layout.gd:190–203). And:
  - every future path tile, set pieces and pit stops included, lies on a row ≥ `_last_row` − 1 ≥ k + 11, by (b);
  - every future junction lies on a row ≥ `_last_row` + 1, by (e), so its dead ends come down no lower than `_last_row` + 1 − `DEAD_END_MAX_TILES` ≥ k + 4, as today.
- **`span()`** walks back from the anchor over the path tiles on the `PROP_AHEAD` rows below it. It stops at the first tile below them, unless that tile is a backward C2, one row below them: the car reaches it from its C1 while the row is shown. The walk is capped at 2·`PROP_AHEAD` tiles. With no backward slide, it visits the same tiles as today.

```gdscript
	var lowest := tile.screen_row() - Tuning.PROP_AHEAD
	for _k: int in 2 * Tuning.PROP_AHEAD:
		var below := buffer.tile_at(tile.cell - Heading.VEC[tile.heading])
		if below == null or below.path_index != tile.path_index - 1:
			break
		var below_row := below.screen_row()
		var back_c2 := below.heading == Heading.E or below.heading == Heading.S
		if below_row < lowest and not (back_c2 and below_row == lowest - 1):
			break
		tile = below
		...
```

### 5.8 Rendering, art and effects

- **The road.** `GreyboxAtlas.road_coords()` (greybox_atlas.gd:34–44) draws a corner from its exits' column of the `ROAD` row, as it does any tile that is neither a set piece nor a shown dead end. Those are columns 2, 5, 8 and 11, §5.1's masks less one.
  - Every area's sheet draws those columns as it draws its straights: `_road()` in tools/art/make_art.gd (lines 66–92) colours each column's surface, edge and speckle by `RoadGeometry.distance_to_centreline()`.
  - `test_area_art.gd:35` checks that each sheet is opaque exactly where the grey box's road is.
  - So the corners need no new art, unless P3 finds a flaw (X10).
- **Props** keep off a corner's cell as they keep off any road tile (prop_layout.gd:58).
- **The headlights' cone** follows `sim.forward()` (headlights.gd:54), which the carry leaves alone. So at night the cone points straight on while the road it lights steps aside. P3 looks at that by night.
- **Skid marks** are laid only while the car brakes for a junction (skid_marks.gd:42–45), and braking never starts before a carry ends (§5.4). So a slide leaves none.
- **The camera** follows the car smoothly, a little ahead along its heading (camera_rig.gd:3 and 37), so it trails the carry's sideways move. P3 decides whether that reads as a bend.

### 5.9 AreaDef and Tuning

PR 1 adds `slide_chance` after `decoy_chance` (area_def.gd:24), and PR 2 adds `slide_back_share` below it:

```gdscript
## Chance that a straight that may slide does (SLIDE_PLAN.md §5.2): two of its tiles become
## corners, and the road steps one tile aside and runs on.
@export_range(0.0, 1.0) var slide_chance := 0.0
## Of the straights that slide, the share that step away from the next turn (SLIDE_PLAN.md X3).
@export_range(0.0, 1.0) var slide_back_share := 0.5
```

`validate()` (line 75) checks each one's range beside the other chances (lines 83–88), and adds the brake rule of §5.4:

```gdscript
	if slide_chance > 0.0 and junction_brake_distance > most_slide_brake_distance():
		problems.append(
			"%s: junction_brake_distance is above %.3f" % [id, most_slide_brake_distance()]
		)
```

After `least_brake_distance()` (line 118):

```gdscript
## The most junction_brake_distance validate() allows in an area that slides. A slide's carry ends
## at least this far before its junction's centre (SLIDE_PLAN.md §5.2), and only from there is
## the car's distance to the junction exact (§5.4).
static func most_slide_brake_distance() -> float:
	return Tuning.SLIDE_MARGIN_TILES + 1 - Tuning.SLIDE_HALF_SPAN
```

PR 1 adds two constants to config/tuning.gd, after `START_STRAIGHT_TILES` (line 22):

```gdscript
## Straight tiles kept before a slide's first corner and after its second (SLIDE_PLAN.md §5.2, Q6).
const SLIDE_MARGIN_TILES := 2
## Half the stretch of road, in tiles along it, over which a slide carries the car one tile across.
## At most ROAD_HALF_WIDTH - GLOBAL_SPEED_CAP / 60, so that no carried step leaves the road
## (SLIDE_PLAN.md §5.3, X15).
const SLIDE_HALF_SPAN := 0.2
```

### 5.10 Tests

`slide_schedule(chance, least, most)` builds one bare area, as `dense_schedule()` does (road_fixtures.gd:22). It has straights of `least` to `most` tiles, the Meadows' junction chances (crossroads 0.3, side roads 0.2, decoys 0.15), and `slide_chance` = `chance`. With straights of exactly 6 tiles and a chance of 1, every C1 is its straight's tile 2 (§5.2), so a car test knows where each slide is. Turn 0 goes left (heading.gd:27), so on a road that isn't mirrored the first straight after a junction heads W and the second N. Those give the two forward kinds, and in PR 2, at a back share of 1, the two backward kinds.

**PR 1**, about +36 tests in four new scripts and two old ones:

| File | Tests |
|---|---|
| `tests/unit/test_road_tile.gd` (new) | <ul><li>`test_exit_heading_off_a_corner`: a straight's heading, a junction's expected exit.</li><li>`test_exit_heading_of_each_corner`: the four masks, entered by either exit.</li><li>`test_slide_side_is_minus_one_off_a_slide`</li></ul> |
| `tests/unit/test_road_generator_slides.gd` (new) | <ul><li>`test_straights_that_may_slide_do_at_the_chance` (E1)</li><li>`test_nothing_slides_at_chance_zero`</li><li>`test_the_start_and_the_tutorial_never_slide`</li><li>`test_a_pit_stop_never_slides` (N4)</li><li>`test_the_finishing_straight_slides_as_the_endless_one` (N13): `slide_schedule(1.0, 6, 6).ending_at(40, &"pier")` against its `endless()`, built as test_road_generator_finish.gd:106–108 builds its roads.</li><li>`test_a_short_straight_never_slides`</li><li>`test_slides_keep_their_margins` (N5)</li><li>`test_the_largest_roll_keeps_the_margins` (N14): `slide_place(slide_roll(0xFFFFFFFF), s)` is s − 4 for s = 6 to 12.</li><li>`test_a_slide_steps_to_the_next_turns_side`</li><li>`test_a_slide_is_two_corners`: §5.1's table.</li><li>`test_slides_leave_the_road_stream_alone` (E2, N1): at chances 0 and 1, the junctions' indices, kinds, turns and areas match a digest pinned from `main` at e73f96d.</li><li>`test_a_chance_changes_no_other_straights_rolls` (N2)</li><li>`test_slid_roads_stay_valid` (E2)</li></ul> |
| `tests/unit/test_road_geometry.gd` | `test_slide_offset_is_a_smoothstep`; `test_slide_corner_finds_c1_from_either_corner` |
| `tests/unit/test_car_sim_slide.gd` (new) | <ul><li>`test_the_carry_takes_the_car_one_tile_across` (E4): each kind, with its angle and speed kept.</li><li>`test_the_carry_keeps_the_car_on_the_road` (E4, N9): asserts that `SLIDE_HALF_SPAN` ≤ `ROAD_HALF_WIDTH` − `GLOBAL_SPEED_CAP`/60, then drives w₀ from −0.318 to 0.318 at speeds up to the cap, through each kind both ways, with no `offroad_changed` and no `damaged`.</li><li>`test_a_carried_car_crosses_its_cells_in_order` (N10)</li><li>`test_driving_back_carries_the_car_back` (E4)</li><li>`test_a_car_steered_off_mid_carry_is_carried_through` (N6)</li><li>`test_a_car_off_the_road_is_not_carried` (N7): at w = −0.4, held straight or steered onto the road inside the band.</li><li>`test_a_car_that_cuts_into_the_other_corner_is_not_carried` (N8): on the road in C2's cell at u = −0.3, w = 0.6, heading H.</li><li>`test_the_latch_is_judged_where_the_car_enters_the_band` (N22): a step in (u, w) from (−0.27, 0.48) to (−0.17, 0.525), which enters the band in C2's cell, isn't carried. One from (−0.28, −0.34), off the road, to (−0.18, −0.30), which rejoins it before the band, is carried. One held along the road at w = 0.5 is carried on N and W slides, where `floor()` puts it in C1's cell, but not on PR 2's E and S slides.</li><li>`test_the_move_is_judged_up_to_the_band_first` (N25): N22's second step, 0.05 tile short of the off-road limit: it drives 0.054 tile off the road before it rejoins, so `crashed(OFFROAD)`.</li><li>`test_a_car_beside_a_slide_is_judged_whole` (N26): in the grass with C1 still its `path_tile`, at w = −0.4 in C1's cell and at w = −0.6 beside it, 0.04 tile short of the off-road limit with 0.4 health, a step from u = −0.25 to −0.15 at 6 tiles/s ends in `crashed(HEALTH)`, as on a straight.</li><li>`test_a_far_slide_keeps_the_offset` (N23): the first slide whose C1 is more than 256 tiles out on both axes, which the test asserts is less than 511, driven unsteered from w₀ = 0.3 at 2 and 7 tiles/s, from 16 phases of the step. At u = 0.6, the offset is the one it started with, to within 1e−6 tile (§6.5).</li><li>`test_a_slide_is_no_junction` (E3)</li><li>`test_progress_rises_with_the_carry` (N3): §5.4's values.</li><li>`test_braking_waits_for_the_carry` (X14)</li></ul> |
| `tests/unit/test_area_def.gd` | `test_slide_chance_is_within_0_and_1`; `test_an_area_that_slides_brakes_after_its_carries` (N11) |
| `tests/sim/test_autopilot_slides.gd` (new) | <ul><li>`test_the_autopilot_drives_slid_roads` (E5)</li><li>`test_the_autopilot_keeps_its_lane_through_a_slide` (N12): one slide at 5 tiles/s, from the lane's centre. The car's angle stays H's, and its offset from its carried lane stays under 0.01 tile.</li></ul> |

**PR 2**, about +21 tests:

| File | Tests |
|---|---|
| `test_road_generator_slides.gd` | <ul><li>`test_slides_step_back_at_the_back_share`</li><li>`test_a_backward_slide_steps_away_from_the_next_turn`</li><li>`test_the_veto_keeps_every_dead_end` (N15): the wide fixture, every straight stepping back, seeds 0–399.</li><li>`test_forward_slides_keep_every_dead_end`: the same, forward.</li><li>`test_a_vetoed_slide_leaves_both_streams_alone`</li></ul> |
| `test_road_tile.gd` | `test_screen_row_is_minus_the_cells_sum` |
| `test_car_sim_slide.gd` | `test_the_split_judges_the_road_by_its_spans` (N27): a backward slide whose C1 lies on column 0, stepping E, so that the road's far edge at the band is x = 0.18. There, and likewise on row 0, 32-bit floats hold the edge more finely than its offset from the centreline, 0.32, so the spans and `is_on_road()` can round apart (§5.3). The test replays P7's steps through `step()`, each from P7's set-up and steer input, and the car is carried exactly when the spans put the entry point on the road. One step, which the spans put off the road and `is_on_road()` on it, isn't carried, so it ends where P7's did. The test asserts that too, to show that the step is still P7's, which rounds apart. |
| `test_road_buffer.gd` | <ul><li>`test_the_buffer_keeps_its_rows` (N17): §5.7.3's edge cases.</li><li>`test_jumps_on_a_road_that_slides_back`: the fuzz test (lines 38–57), on a backward fixture.</li><li>`test_a_backward_c2_goes_with_its_c1`</li><li>`test_the_car_row_is_set_before_tiles_are_generated` (N20): a method of the test, connected to `tiles_generated`, reads `car_row()`. A method, not a lambda that uses `self` (AGENTS.md §2).</li><li>`test_a_backward_c2_frees_nothing` (N21): entering C2 leaves `car_row()` and the held tiles as they were, and `rows_ahead()` at most `BUFFER_AHEAD`.</li><li>`test_a_jump_onto_a_backward_c2_counts_its_c1` (N24): `on_car_path_index()` from before C1 straight to C2 sets `car_row()` to C1's row.</li></ul> |
| `test_prop_scatter.gd` | <ul><li>`test_each_row_gets_its_props_once` (N16)</li><li>`test_the_guard_counts_rows` (N19): a fixture with enough path indices ahead but too few rows.</li><li>`test_fade_finds_the_rows_on_screen`</li><li>`test_a_road_that_slides_back_shows_the_same_props_however_the_car_got_there`: line 164's test, on a backward fixture.</li></ul> |
| `test_prop_layout.gd` | `test_span_takes_a_backward_c2_below_its_rows` (N18); `test_props_spread_across_the_view_on_a_road_that_slides_back` |
| `test_camera_rig.gd` | `test_a_freed_dead_end_stays_below_the_view_through_a_backward_slide`: line 199's test, with a backward slide's carry just after the junction is freed. The gap stays at least `MARGIN` on every frame (§5.7.3). |
| `test_area_def.gd` | `test_slide_back_share_is_within_0_and_1` |

`test_car_sim_slide.gd`'s other tests take the backward kinds as they are. PR 3 adds none (§4.4).

### 5.11 Docs

- **PRs 1 and 2** cite this plan in comments as `SLIDE_PLAN.md`, by its sections and IDs. PR 1 adds the generator header's paragraph (§5.2), and PR 2 rewrites it with the comments that X4d lists.
- **PR 3** sums up the plan (planning.md §6):
  - `docs/SLIDE.md`, at most about 15 KB, replaces `SLIDE_PLAN.md`. Its header points to `git show <sha>:SLIDE_PLAN.md`.
  - The citations outside `docs/` change from `SLIDE_PLAN.md` to `docs/SLIDE.md`, which has the same length.
  - `plan.md` §3.2 gains a sentence on slides.
  - `docs/ROADGEN.md` gains "Since SL" notes at R5 (line 20) and §5.3, for X4a's Δ, as SP added its own (docs/SPEEDUP.md §5.8).
  - IP: the slide stream joins the list at §5.3 (line 232) and D8 (Δ), and §9's notes move to §4 M7.
  - `docs/README.md` gets the plan's row, and `AGENTS.md` its state line and X# (SLIDE) in the ID list.

### 5.12 The warp, Q1's other answer

The warp bends the picture instead of the road.
- **How it works:** a full-view `ColorRect` sits on a `CanvasLayer` above the world's veil and below the HUD. Its shader reads `hint_screen_texture`, as lamps.gdshader:8 does, and shifts each screen row's pixels sideways by a smooth bend and bend back. The band of rows lies on a straight placed as §5.2 places a slide, from a stream of its own, and moves with the camera.
- **What it keeps:** the tiles, the sim, the buffer and the props all stay as they are. There is no PR 2 and no carry.
- **What it costs:**
  - It bends everything in its band: the props, the shadows, the lamps' glow, the legends, and the car as it passes. Tall sprites shear.
  - While the car is in the band, the car and the road on screen are up to a tile from where the sim has them. That breaks the rule that the road on screen is the road the off-road test sees (greybox_atlas.gd:2–3). To keep that rule, the bend must ease to nothing before the car reaches it. The bend then straightens as the player comes near, which a player soon learns to see through.
  - It adds a screen-texture pass every frame, to be measured on the Fold4 and the Web.

It fools the same players as the slide (X2), at about §10's middle complexity. Q1 keeps the slide, because the slide keeps the road on screen and the sim's road the same.

## 6. Verification

### 6.1 Local checks

Not run yet. §4.1 step 1 records `main`'s counts at e73f96d, and each PR's body gives its own (AGENTS.md §3). The expected changes:
- PR 1: 4 more test scripts and about 36 more tests (§5.10).
- PR 2: about 21 more tests.
- PR 3: no new tests.

E2's 600 roads and E5's 20 drives add the most GUT time. P4 and P2 time them on the prototype.

### 6.2 Negative cases

Each break must fail the tests named, and only for the reason given. A script applies each break, runs the test scripts that it names, and restores the file. With the whole suite, every case runs on the prototype and on each PR's head once its reviews are done (planning.md §4).

| N# | PR | The break | Fails |
|---|---|---|---|
| N1 | 1 | `_sample_straight()` draws the slide's rolls from `_rng_road` | `test_slides_leave_the_road_stream_alone`: at chances 0 and 1, the junctions differ from the digest pinned from `main`. Also the digests (`test_road_generator_determinism.gd:11–12`) |
| N2 | 1 | `_sample_straight()` draws the side's and the place's rolls only when the first roll is below the chance | `test_a_chance_changes_no_other_straights_rolls` |
| N3 | 1 | `path_progress()` has no branch for a slide's corners, and line 229 uses `exit_heading()` | `test_progress_rises_with_the_carry`: at u = h on C2, w₀ = −0.3 reads k + 0.7, not k + 1.2. Steering across C2 at u = 0.1 moves it from k + 0.6 to k + 1.1, not k + 0.94 throughout |
| N4 | 1 | `_plan_slide()` drops `_pit_stop` | `test_a_pit_stop_never_slides` |
| N5 | 1 | `slide_place()` returns `floori(roll * (length - 1))`, counting from the straight's first tile | `test_slides_keep_their_margins` |
| N6 | 1 | `_carry()` has no latch: it carries each step in the band that starts on the road | `test_a_car_steered_off_mid_carry_is_carried_through`: the car is left part of the way across |
| N7 | 1 | `_band_entry()` drops the road test | `test_a_car_off_the_road_is_not_carried`: the car is carried from the band's edge. Also N26's test, as N26 fails it |
| N8 | 1 | `_band_entry()` drops the cell test | `test_a_car_that_cuts_into_the_other_corner_is_not_carried`: the car is carried to w = 1.6, 0.28 tile off the road |
| N9 | 1 | `SLIDE_HALF_SPAN` is 0.3 | `test_the_carry_keeps_the_car_on_the_road`: the bound's check fails, and in the model chords at \|w₀\| = 0.318 dip 0.0053 tile off the road (§6.5). At 0.25 only the bound's check fails |
| N10 | 1 | `step()` calls `_carry()` after the second `_move()`, not before it | `test_a_carried_car_crosses_its_cells_in_order`: a step ends in C2's cell with `path_tile` still C1 |
| N11 | 1 | `validate()` has no brake rule | `test_an_area_that_slides_brakes_after_its_carries` |
| N12 | 1 | The autopilot aims only at `centreline_point()`, the plain aim | `test_the_autopilot_keeps_its_lane_through_a_slide` (§5.5). P2 finds whether `test_the_autopilot_drives_slid_roads` fails too |
| N13 | 1 | `_plan_slide()` leaves out the finishing straight (`or _finishing`) | `test_the_finishing_straight_slides_as_the_endless_one` |
| N14 | 1 | `slide_roll()` divides by 4294967295.0 | `test_the_largest_roll_keeps_the_margins`: the place is s − 3, so C2 has only 1 straight tile after it |
| N15 | 2 | No veto | `test_the_veto_keeps_every_dead_end`: 1,022 short ends in 371 of 400 runs in the model |
| N16 | 2 | `_rows` keyed by path index | `test_each_row_gets_its_props_once` |
| N17 | 2 | The buffer fills and frees by path index | `test_the_buffer_keeps_its_rows` |
| N18 | 2 | `span()` stops at its lowest row, whether or not the tile below is a backward C2 | `test_span_takes_a_backward_c2_below_its_rows` |
| N19 | 2 | The guard counts path indices | `test_the_guard_counts_rows` |
| N20 | 2 | `on_car_path_index()` sets `_car_row` after the emit | `test_the_car_row_is_set_before_tiles_are_generated` |
| N21 | 2 | `_car_row` is the row of the car's tile, not the highest row reached | `test_a_backward_c2_frees_nothing`: `car_row()` falls by one on C2 |
| N22 | 1 | `step()` doesn't split the move, and `_band_entry()` tests the road and the cell where the move starts | `test_the_latch_is_judged_where_the_car_enters_the_band`: the first step is carried, and the second isn't |
| N23 | 1 | `_carry()` moves the car by `across * (now - was)` | `test_a_far_slide_keeps_the_offset`: in the model, 18 or more of the 32 drives drift, by up to 0.00003 tile (§6.5) |
| N24 | 2 | `_row_through()` returns the tile's own row | `test_a_jump_onto_a_backward_c2_counts_its_c1`: `car_row()` is one row low |
| N25 | 1 | `step()` judges the whole move after the carry, latching where the move enters the band | `test_the_move_is_judged_up_to_the_band_first`: along the carried chord, the car rejoins 0.008 tile sooner and drives on |
| N26 | 1 | `_band_entry()` drops the road test, and `_carry()` latches only if `state` is on the road | `test_a_car_beside_a_slide_is_judged_whole`: at w = −0.4, the first part reaches the off-road limit with health left, so `crashed(OFFROAD)` |
| N27 | 2 | `_band_entry()` tests `is_on_road()` at the point, not the spans | `test_the_split_judges_the_road_by_its_spans`: each of P7's steps is carried exactly when the spans don't put its entry point on the road |

### 6.3 Editor warnings

Only the editor warns about shadowing, not CI (docs/agents/checks.md §1). The sketches' names avoid it:
- **CarSim:** no member (car_sim.gd:39–80) is named `to`, `entry`, `c1`, `c2`, `centre`, `along`, `across`, `u`, `u_from`, `u_to`, `w`, `w_from`, `was`, `now`, `edge`, `corner`, `at`, `part`, `straight`, `c1_cell` or `c1_index`, the locals of `step()`, `_band_entry()`, `_carry()` and `_slide_progress()`.
- **RoadGenerator:** no member is named `bits`, `roll`, `length`, `margin`, `rolls`, `side`, `back`, `at`, `tile` or `out`, the locals of `slide_roll()`, `slide_place()`, `_plan_slide()` and `_corner_tile()`.
- **Autopilot:** its members are `LOOKAHEAD`, `GAIN` and `_sim`, and `_aim()` uses `k`, `c1`, `centre`, `along`, `u` and `across`.
- **The rows:**
  - PropLayout has `row()`, so `span()` uses `below_row` (§5.7.4).
  - PropScatter has `rows()`, so `_show_rows()` uses `top`, `tile` and `k`.
  - RoadBuffer has no member named `rows`, `index`, `row`, `tile`, `missing` or `created`.
- **The seed** is `run_seed` (docs/M1.md G13).

### 6.4 CI, the Web and the Fold4

- **CI** runs every check on each PR. PRs 1 and 2 change nothing in the game (E10), so their builds behave as `main`'s.
- **The Web.** A slide adds no `Polygon2D`, no text and no shader: its corners are tile cells. PR 3 drives one run in Chrome and in Firefox through Rural and the Meadows (docs/agents/checks.md), since the Web build takes no `--area`.
- **The Fold4**, for PR 3's gathered list (planning.md §5):
  1. Slides read as a bend and a bend back, folded and unfolded, by day and by night with the headlights (E8).
  2. Steering by touch through a slide: whether the carry fights the thumb (§8).
  3. The frame rate holds through slides.
  4. The owner's call: do slides mislead (X2)?

### 6.5 Probes and models

The probes run on `sl/prototype` (§4.1):
- **P1. Time** (E6, X7): `test_drive_to_the_end.gd`'s drives with Q5's chances and without: seeds 0–9, pier seed 4993 and home seed 352, against X7's estimates.
- **P2. The autopilot** (E5, §5.5, N12): the carried aim on 20 seeds, with every eligible straight sliding, and the plain aim beside it. Records each drive whole: the largest offset from the lane, any time off the road, and whether the plain aim fails `test_the_autopilot_drives_slid_roads`.
- **P3. The look** (E8, Q7, X10): Movie Maker frames at 2, 4 and 7 tiles/s, of each kind, in Rural, the Meadows, the Village and the Desert, by day and by night with the headlights. It judges how h = 0.2 looks and decides Q7.
- **P4. The roads** (E2): the generator's checks on 5,000 seeds a road, at Q5's chances and with every eligible straight sliding. Records the slides, their sides, the vetoes and R5's checks, which must match the road model's to within the noise.
- **P5. The chords** (E4, X15): the carry model's sweep, run with `CarSim` and `RoadGeometry`. Its least margins go beside the model's: +0.0199 for \|w₀\| ≤ 0.3, and +0.0020 at 0.318.
- **P6. The rows** (E7): `test_props_in_view.gd` and `test_camera_rig.gd` with Q5's chances, and on a fixture whose slides all step back. Records the rows ahead and behind, and anything that comes or goes in view.
- **P7. The road's edge** (§5.3, N27): through `step()`, from N27's test's set-up of the car, steps whose entry points lie within rounding of the far edge that the test names. `step()` steers and sets the speed before it moves (car_sim.gd:114–115), so it records, for that test, each step that the spans and `is_on_road()` put on opposite sides of the edge, each way if both occur, with its set-up, its steer input and its end. It must find one that the spans put off the road.

The models are in Python 3.12.3, in `tools/sl/` on `sl/prototype`.

**The roads** (`slide_model.py`, `wide_check.py`). They model RoadGenerator's geometry at e73f96d: the kinds, the dead ends' free runs, the set pieces, the pit stops and the finish, but not the tutorial. Slides are placed as §5.2 and §5.7.1 say. The random numbers are Python's, so the model checks shapes, not the game's seeds. "Problems" counts overlaps, dropped or missing wrong exits, cut straight-on dead ends, and opposite-turn dead ends under 2 tiles (R5). "Every" means every eligible straight slides. Seeds: 1,000 a road unless the road says otherwise.

| Road | Slides | Forward | Backward | Vetoed | Problems |
|---|---|---|---|---|---|
| Pier | Q5, back share 0.5 | 7,433 | 7,411 | 0 | 0 |
| Home | Q5, back share 0.5 | 7,321 | 7,298 | 0 | 0 |
| Pier | every, backward | 0 | 70,920 | 0 | 0, with the veto or without |
| Home | every, backward | 0 | 69,937 | 0 | 0, with the veto or without |
| Endless Rural, Village and Desert: 250 seeds, 300 turns | every, backward, no veto | 0 | 33,187; 52,798; 87,750 | – | 0 |
| Wide (2–12 tiles): 400 seeds, 300 turns | every, backward, no veto | 0 | 89,814 | – | 1,022 short ends, in 371 runs |
| Wide | every, backward | 0 | 88,557 | 1,257 | 0 |
| Wide | every, back share 0.5 | 45,088 | 44,103 | 623 | 0 |
| Wide | every, forward, no veto | 89,814 | 0 | – | 0 |
| Pier at margin 1: 400 seeds | every, backward, no veto | 0 | 38,379 | – | 363 short ends, in 260 runs |
| Pier at margin 1 | every, backward | 0 | 38,012 | 367 | 0 |

`python3 tools/sl/slide_model.py 1000` prints the pier's and home's rows, and the endless roads' at a quarter of the seeds, in about 25 s. `python3 tools/sl/wide_check.py` prints the rest in about 9 s.

**The carry** (`carry_check.py`). It works in the jog's frame. Each step's chord is tested against the corners' capsules (half-width 0.32), as `_follow_road()` tests it, at 0.5–7 tiles/s, for |w₀| ≤ 0.3 in steps of 0.02 and 8 phases of the step. The plan's h is 0.2, which §5.3 proves; the larger ones show where the proof's bound, 0.2033, bites:

| h | 0.20 | 0.25 | 0.28 | 0.30 | 0.32 | 0.35 | 0.40 |
|---|---|---|---|---|---|---|---|
| Least margin, tiles | +0.0199 | +0.0168 | +0.0124 | +0.0089 | +0.0051 | −0.0011 | −0.0130 |

At the lane's edge, with 16 phases of the step:

| h | 0.20 | 0.25 | 0.30 |
|---|---|---|---|
| \|w₀\| = 0.318 | +0.0020 | +0.0005 | −0.0053 |
| \|w₀\| = 0.32 | −0.0000 | −0.0013 | −0.0071 |

At 0.32 the car is on the road's edge before the slide, so h = 0.2's −0.0000 is rounding (§5.3). `python3 tools/sl/carry_check.py` prints these in about 85 s.

**The progress** (`progress_check.py`). It measures the progress across a forward slide at h = 0.2 with §5.4's branch, and with the nearer half that N3 puts back. The drives run at 0.5–7 tiles/s, for |w₀| ≤ 0.32, unsteered:

| | The nearer half | The slide branch |
|---|---|---|
| On C2 at u = h, for w₀ = −0.3, 0 and 0.3 | k + 0.70, k + 1.20 and k + 1.20 | k + 1.20 each |
| Steering across C2 at u = 0.1, w from 0.6 to 1.3 | k + 0.60 to k + 1.10 | k + 0.94 throughout |
| Largest fall in a step, unsteered | 0 | 0 |
| Largest rise beyond the step's own move | 0.637 | 0.388 |

`python3 tools/sl/progress_check.py` prints these at once.

**The jog** (`jog_check.py`). The carry's numbers by h:

| h | Steepest slope | Longest carried step | Frames at 7, 5.5 and 2 tiles/s | A carried car enters C2 at | A backward slide's dip below C1's entry edge |
|---|---|---|---|---|---|
| 0.20 | 3.75 (75°) | 0.554 tile | 3.4, 4.4 and 12.0 | u = −0.092 to 0.092 | 0.314 row, 10 px |
| 0.25 | 3.00 (72°) | 0.467 tile | 4.3, 5.5 and 15.0 | u = −0.115 to 0.115 | 0.272 row, 8.7 px |
| 0.30 | 2.50 (68°) | 0.408 tile | 5.1, 6.5 and 18.0 | u = −0.138 to 0.138 | 0.232 row, 7.4 px |

`python3 tools/sl/jog_check.py` prints these, and §5.3's bound, at once.

**The rounding** (`round_check.py`). It replays forward carries in 32-bit floats, as `pos` holds them, held straight from C1 at (c, c), at \|w₀\| = 0.318 and 0.3199, 2–7 tiles/s and 16 phases of the step: 320 drives a column.

| C1 at c = | −511.5 | −1,023.5 |
|---|---|---|
| `across * (now - was)`: largest drift; drives off the road | 0.00012 tile; 1 | 0.00024 tile; 7 |
| `_carried_offset`: the same | 0; 0 | 0.00006 tile; 0 |

From −1,023.5 the carry crosses 1,024, so the kept offset rounds once (§5.3). At (−8,191.5, −8,191.5), the kept offset rounds by up to 0.00049 tile, 8,192·2⁻²⁴: no drive from \|w₀\| = 0.318 ends off the road, but each from 0.3198 does, at a tie. For each C1 from −256.5 to −510.5, at w₀ = 0.3 and 2 and 7 tiles/s, the old carry drifts in 18 or more of the 32 drives, by up to 0.00003 tile, and the kept offset in none (N23). `python3 tools/sl/round_check.py` prints these at once.

## 7. Owner actions

| When | Action | How |
|---|---|---|
| Before PR 1 | Answer Q1–Q9 or accept their defaults, and merge `sl/plan`'s PR, which approves the plan | Q1 and Q9 decide whether slides go ahead, or one of §10's tricks instead |
| PR 3's device checks | §6.4's Fold4 list, on the build that PR 3's comment gives with the list (planning.md §5). In a debug build, the title's Start button picks the area that Play starts in (docs/ZONE_SELECT.md), so each area that slides can be checked | `rm -rf /tmp/roadgame-apk && gh run download <run-id> -R pompomon/roadgame -n "android-Android APK" -D /tmp/roadgame-apk && adb install -r /tmp/roadgame-apk/roadgame-debug.apk`, with the run id from that comment (docs/agents/checks.md §4) |
| Once the device checks pass | Land PR 3, labelled `needs-owner` (§4.5) | Squash it, and remove the label |
| After PR 3 | Tag the prototype, which this plan cites, and delete SL's branches, which GitHub doesn't delete on merge | `git fetch origin sl/prototype && git push origin FETCH_HEAD:refs/tags/archive/sl/prototype`, then `git push origin --delete sl/plan sl/prototype sl/1-slides sl/2-back sl/3-areas`, leaving out the branches that GitHub deleted. Retarget any PR still open on one of them first (stacks.md) |

---

## 8. Risks

| Risk | Impact | Mitigation |
|---|---|---|
| Slides fool few players (X1, X2) | A player who goes by the screen, or counts the turns taken at junctions, is never fooled. To them, slides are scenery | E8's Fold4 check asks the owner whether slides mislead. §10's mirage is the only trick that beats X1 (Q9) |
| The carry reads as a slip | The car moves a tile sideways without turning. It may look as if the road moved under the car, or like a glitch | P3 at 2, 4 and 7 tiles/s, by day and night. h = 0.2 is the gentlest carry that §5.3's proof covers (X15). Q7's marks |
| A player steers into the bend | A latched car is carried however it steers, and steering into the bend adds to the carry. A car that steers in early may not be carried at all (§5.3, X12). Either way, off the road it takes damage as on any straight (car_sim.gd:373–391) | §6.4 item 2 checks steering by touch. If players do steer into bends, take Q3's self-steer |
| PR 2's rows regress the props | Props doubled, gaps in the view, or props popping in at the screen's edge | E10. Tests on fixtures that step back (§5.10), and P6 |
| SP's E1 has 3.6 s of headroom | A change that slows the car could push pier seed 4993 past 310 s | Slides save about 2.7 s a run (X7). P1 measures it, and E6's tests hold the bound |
| Corners never seen | Four areas' corners have never been on screen (X10) | P3. PR 3 fixes `tools/art/` if P3 finds a flaw |
| The headlights by night | The cone points straight on while the road steps aside, so the bend may show less | P3 by night (§5.8) |
| Determinism | A slide roll from another stream would move every later junction | `_rng_slide` (X11), N1 and N2, and lint's RNG rule |
| The game's roads change in PR 3 | Tests that pin a seed's road fail | Expected. §4.1 step 4 lists them, and PR 3 updates them (§4.4) |

---

## 9. Notes for later work

- **M7's haptics** (IP §4 M7): none for a slide (Q7), since it isn't a turn. If the owner's device check finds the carry hard to feel, a light tick at C1 could join M7's haptics.
- **M7's audio:** Q7's tyre squeal, if wanted, comes with M7's Web audio.
- **The folded screen:** the cover screen shows fewer rows ahead. P3's folded frames show whether a slide reads there, and M7's orientation work should look again.
- **Screen rows:** after PR 2, the buffer and the props count screen rows, not path tiles. A later feature whose path steps E or S starts from PR 2's rows and veto, not from the −x/−y invariant.
- **§10's tricks** are each a plan of their own (Q9).

---

## 10. Other tricks

The user asked for three other tricks in case slides proved too complex. Slides are feasible, in 3 PRs, but X1 caps what they can do, so the three are ranked here beside the slide and the warp (§5.12), by:
- **Chance to trick:** how many of X2's players a trick fools, and for how long once they know it.
  - *High* fools every rule, until the player learns its tell.
  - *Medium* fools players who follow a cue, until they learn that it lies.
  - *Low* fools few, even at first.
- **Complexity:** the PRs, and the systems that they touch.

Both ranks are judgements, not measurements. No player has met these tricks yet, so only a playtest can settle their chances.

### 10.1 The mirage exit

- **What:** at some decoys, a shimmering turn appears where the decoy has none. It is the pattern's turn, the one that leads up the screen. So the decoy looks like a crossroads that offers the expected turn.
  - It isn't road. A car that turns into it at the junction leaves the road near the junction (car_sim.gd:350–352).
  - If the car then drives `offroad_limit_tiles` off the road, 2 by default, the run ends as a missed turn (car_sim.gd:387–389, junction_trigger.gd:105–111, ui/main.gd:310), or as a crash if its health runs out first (line 386). A car that comes back to a decoy that it has passed crashes off the road instead (lines 390–391), since only the trigger's next junction is near (line 349). JunctionTrigger needs no change.
  - A player who sees the tell in time can steer back before the limit. Back onto the junction, that decides nothing. Onto the straight-on exit's tiles past it, it decides the decoy's correct exit (junction_trigger.gd:86–102).
- **Who it fools:** every rule in X2's table, X1's too. The screen rule and the count both look for the up turn, and see one. Only a player who spots the tell isn't fooled.
- **How:**
  - **The generator:** a `mirage_chance` per area, the Desert's to begin with, and a stream of its own. A mirage is laid as `_place_dead_end()` lays a dead end (road_generator.gd:369–389, R5), but as tiles of a new `Type.MIRAGE` with no exits, and it leaves the junction's exits alone. So it stops before a taken cell, nothing else is laid on it, and the props keep off it.
  - **The sim:** no change. `RoadGeometry` puts a tile with no exits off the road (road_geometry.gd:21–23).
  - **The renderer:** the road layer skips mirage tiles, and a TileMapLayer of their own draws them, over the junction's true art, with a shimmer shader. The shimmer is the tell.
  - **Tests:** the placement, each outcome above, and the props.
- **Chance:** high. **Complexity:** high: 3 PRs, about as many systems as slides touch, and a shader that the Web and the Fold4 must run.
- **Risk:** fairness. A mirage that can't be told from road makes the pattern useless at decoys, so the tell must be learnable. It breaks greybox_atlas.gd:2–3's rule on purpose, for its own layer only.

### 10.2 The lure car

- **What:** a car appears ahead of the player's, half see-through, and drives the road a few tiles ahead. At some junctions it takes an exit: the right one, or a wrong one at a `lure_lie_share` of 0.5. After a wrong one, it fades into the dead end.
- **Who it fools:** players who follow it rather than count, which comes naturally at speed. It shows its choice just as the player decides. It fools no rule in X2's table.
- **How:**
  - **The logic:** a pure `RefCounted` that walks the buffer's centreline, as the autopilot aims (autopilot.gd:20, road_buffer.gd:79–87), keeping a few tiles ahead of the player's progress. Into a dead end it follows the junction's dead-end tiles.
  - **The node:** a thin `Sprite2D` with the car's sheet (`tools/art/make_car.gd`), tinted through `self_modulate` (AGENTS.md §2, Web) and half see-through, like the Phantom Bus (disasters/legends/phantom_bus.gd:1–8).
  - **Visual only:** no `CarSim` of its own, no collisions and no events, and nothing in the game reads it. Its choices come from a stream of its own.
- **Chance:** medium. **Complexity:** medium: 2 PRs, the logic and its tests, then the art, the areas and the docs. The generator, the sim and the buffer don't change.
- **Risk:** a cue that lies half the time is soon ignored. A lower share builds trust before betraying it, which players may find unfair.

### 10.3 The lying signposts

- **What:** a signpost with an arrow stands by the last plain straight before some junctions. It points to the junction's correct exit, or, at a `sign_lie_share` of 0.5, to one of its wrong exits. So it may point straight on: a decoy's correct exit is straight on, and a side road's wrong one is (X1).
- **Who it fools:** players who read signs rather than count. Few do, once they see a sign lie.
- **How:** it is placed as the Hitchhiker is (world/hitchhiker.gd:96–108 and 120–124), never on her tile, from a stream of its own, with a prop sprite from `tools/art/make_props.gd`. The arrow is art, not text: the game's font has no arrows (AGENTS.md §2, Web).
- **Chance:** low. **Complexity:** low: 1 PR.
- **Risk:** an arrow on an isometric sign can be hard to read as left or right.

### 10.4 The ranking

| Trick | Who it fools | Chance to trick | Complexity | PRs | Changes the sim |
|---|---|---|---|---|---|
| The mirage exit (§10.1) | Every rule, until the tell is learnt | High | High | 3 | No |
| The lure car (§10.2) | Players who follow it | Medium | Medium | 2 | No |
| Slides (this plan) | Bend readers (X2) | Low to medium | Medium to high | 3 | Yes: the carry |
| The warp (§5.12) | Bend readers, until they see it straighten | Low to medium | Medium | 1–2 | No |
| The lying signposts (§10.3) | Sign readers | Low | Low | 1 | No |

- **By chance to trick:**
  1. the mirage;
  2. the lure car;
  3. slides, then the warp (§5.12);
  4. the signposts.
- **By complexity, simplest first:**
  1. the signposts;
  2. the lure car and the warp;
  3. slides;
  4. the mirage.

If slides prove too complex, the lure car gives the most trick for its cost. The mirage is the one to build if the owner wants the screen's readers fooled too (Q9), and the signposts are a cheap first try.
