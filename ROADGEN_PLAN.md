# Road Generation: Junction Kinds and Long Dead Ends — Detailed Plan

Status: for review · 2026-11-11 · Q1 and Q3 answered by the owner; the other questions follow their defaults until answered (§3) · Scope: junctions that offer straight on and only one turn, where either straight on or the turn can be right, and dead ends long enough to look like roads. This plan calls the work RG. It comes after M5 (#39–#44) and is independent of M6's plan (#45).

The owner asked: "Allow junctions with only straight and either left or right, to confuse and trick the player." The first draft of this plan had side roads only, where straight on is always wrong, and kept M1's 2–3-tile dead ends. The owner's answer to it: "1q both straight and turn could be the right decision, Q3 longer deadends so it looks like a proper road."

**Verified in CI, not locally.** Every file this plan adds or changes exists on branch `rg/prototype`, on top of `main` (4ade5f2), with one state per PR: cb2c7f9 for PR 1, f002f6a for PR 2 and 3c2ca03 for PR 3 (§4.1). The session that wrote this plan couldn't run Godot: it wasn't allowed to install it, or to run CI's image in Docker. So each state ran the five checks in CI, started by hand (§6.1): run 42980918434 on fb8bccb, which is PR 1 but for a check that cb2c7f9 adds to a test; 42986814437 on f002f6a; and 42986884807 on 3c2ca03, whose only failures were the two digests that PR 3 changes, whose new values it printed. The landing was simulated with `git merge-tree` (§4.5). Python models measured what the camera shows (§6.5). Not done: the negative cases (§6.2), which needed scratch pushes that weren't allowed; the editor's warnings (§6.3); the Web and the Fold4 (§6.4). A model of another family, gpt-6.1-sol, reviewed this plan (`AGENTS.md` §7, §4.6).

- Godot 4.7.2-stable, in CI's image
- GUT 9.7.1
- gdtoolkit 4.5.0 on Python 3.12, in CI's `lint` job
- git 2.51.1, for `git merge-tree`

**Precedence.** For RG, this document replaces IP M1.4's junction and dead-end rules (`IMPLEMENTATION_PLAN.md`:206–212 and :235) and its proof sketch (:242), M1.5's buffer values as M5 set them (M5_PLAN.md L2), and `plan.md` §2.1, §3.2, §3.3 and §3.7, wherever it marks a difference with **Δ** and its finding (R#, §2). PRs 1 and 2 fold the changes into `plan.md`; IP is left as M1–M5 left it (Q7).

**Reference code.** This plan has no appendices. Each PR applies the difference between two states of `rg/prototype` (§4.1), which never gets a PR of its own. Its commits: 03c79b7 adds a test of the game's road digests with `main`'s values (its run 42978434562, with the digests empty, printed them); fb8bccb adds the junction kinds; cb2c7f9 checks that a straight-on dead end is never cut short; 8da3835 makes dead ends 6–9 tiles; f002f6a refills the buffer at 37 tiles and records the road's new digest; 3c2ca03 gives the areas their chances. PR 3 also sets the two digests that 3c2ca03's run printed (§6.1).

**Prerequisites.** M5 is merged (#39–#44). M6's plan (#45) changes only `M6_PLAN.md`, so either can land first (§9). No repository settings change.

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

Goal: the owner's request, as adjusted. Today every junction is a turn. A T-junction offers the pattern's turn and the other turn, and a crossroads offers straight on as well, so a player who keeps count never needs to look at a junction's shape. RG adds two kinds of junction that offer straight on and one turn:

- A **side road** offers the pattern's turn and straight on, which is a dead end. It looks like the road going on, with a turn off it.
- A **decoy** offers straight on and the other turn. The pattern's turn isn't there, so straight on is right, and the turn waits for a later junction.

The rule for the player becomes: take the pattern's next turn if the junction offers it, otherwise go straight on (Q1). Dead ends grow from 2–3 tiles to 6–9, so that they look like roads (Q3), and the buffer grows to hold them.

| # | Exit criterion | Checked by |
|---|---|---|
| E1 | Four kinds of junction (R1). A T offers the turn and the opposite turn; a crossroads offers straight on as well; a side road offers the turn and straight on; a decoy offers straight on and the opposite turn. Each kind has exactly its exits, and each wrong exit has a dead end. One `randf()` per junction picks the kind: the crossroads, side road and decoy chances take their parts of 0..1 in that order, and T takes the rest. Over many junctions, each kind comes as often as its chance, within 0.04 | `test_road_generator_pattern.gd`: `test_one_roll_picks_the_kind_from_the_chances_in_order`, `test_junctions_offer_the_exits_of_their_kind_as_often_as_its_chance`; `test_road_generator_occupancy.gd`: `test_every_kind_of_junction_keeps_its_wrong_exits` |
| E2 | Decoys (R2). Straight on is a decoy's correct exit: the trigger emits `turn_completed` with `turn_index` unchanged. The heading, the turn count and the schedule wait for the next junction, which has the decoy's `turn_number` and expects the same turn. The opposite turn is wrong at a decoy, as at a T, and straight on is wrong at a crossroads or a side road. A car that leaves the road and rejoins past a decoy counts only the turns it passed | `test_junction_trigger.gd`: `test_each_kind_of_junction_has_one_correct_exit`, `test_rejoining_past_a_decoy_counts_only_the_turns`; `test_road_generator_pattern.gd`: `test_expected_exits_alternate_left_and_right`; `test_area_start.gd` |
| E3 | `AreaDef` has `side_road_chance` and `decoy_chance`, both 0 by default. `validate()` reports a chance outside 0..1, and chances that add up to more than 1 beyond rounding (R3) | `test_area_def.gd`; `test_area_schedule.gd`: `test_the_game_schedule_is_valid` |
| E4 | Determinism (D8). An area with no side roads or decoys keeps `main`'s road, so after PR 1 the game's road matches `main`'s digests. A side road draws what a T draws, so it keeps the path; a decoy changes the path after it. Each PR that changes the road records the new digests and says why | `test_road_generator_determinism.gd`: `test_the_game_road_matches_its_digests` |
| E5 | Dead ends (R4, R5). They are 6–9 tiles. One that a taken cell cuts short stops right before that cell and keeps at least 2 tiles. A straight-on one is never cut, and none is dropped. On each of the 7 reference screens, the end of a dead end of 6 tiles or more is out of view as the car enters its junction | `test_road_generator_occupancy.gd`, `test_road_generator_pattern.gd`; `test_camera_rig.gd`: `test_a_dead_end_ends_out_of_view_as_the_car_enters_its_junction` |
| E6 | The buffer (R6), at `BUFFER_REFILL_AT` 37 and `BUFFER_BEHIND` 20. Every row of props still has the road it must avoid when it's made. Nothing comes or goes in view of the reference screens (M5 E6). A schedule at `AreaSchedule`'s limit still has M4 K1's one spare tile | `test_prop_scatter.gd`, `test_props_in_view.gd`; `test_area_schedule.gd`: `test_validate_allows_only_schedules_whose_next_junction_is_in_the_buffer` |
| E7 | The autopilot drives 300 turns through every kind of junction, with no damage | `test_autopilot_300_turns.gd`: `test_300_turns_through_every_kind_of_junction` |
| E8 | Areas (Q2). The City has no side roads or decoys. Rural, Meadows, the Village and the Desert get theirs, and each keeps at least a quarter of its junctions as T's | `test_area_schedule.gd`: `test_the_game_schedule_is_valid`; the digests; `smoke.sh` |
| E9 | All five required checks are green, with §6.1's counts, and `smoke.sh` prints no error line. The editor reports no new warnings | PR checks; §6.3 |
| E10 | Manual, on the Web in Chrome and Firefox and on the Fold4. A side road reads as the road going on with a turn off it, and a decoy as the road going on with the wrong turn off it. Masks 11 and 13 look right in each area's art (R9). A dead end looks like a road, not a stub. Straight on at a side road ends in "Wrong turn!"; straight on at a decoy goes on and chimes, and the HUD's count stays | §6.4, on PR 3 |
| E11 | `plan.md` §2.1, §3.2, §3.3 and §3.7, and the comments that PRs 1 and 2 touch, say what the code does (R7) | Review |

---

## 2. Review findings

M1's generator does what IP M1.4 asks of it, and does it well: it is deterministic, its dead ends never touch the path, and its tests run it over 100,000 junctions. The problems are in what it was never asked to do: a junction that isn't a turn, and dead ends that look like roads.

- **High:** following IP can't give what the owner asked for, or gives a broken game.
- **Medium:** fragile, or missing from the code it depends on.
- **Low:** clarity, naming or polish.

Line numbers are `main`'s (4ade5f2). "Prototype" means that the fix runs on `rg/prototype` and passed CI (§6.1).

### High

| # | Finding | Evidence | Fix |
|---|---|---|---|
| R1 | No junction offers straight on and only one turn. `_junction()` always makes the opposite turn a wrong exit, and adds straight on by chance, so every junction is a T or a crossroads. | `road/road_generator.gd`:88–93: the exits, then `wrong` with the opposite turn, and straight on if `randf() < cross_junction_chance`. IP M1.4 (:208–209). Masks 11 and 13 never occur in a run (R9) | **Δ IP M1.4, `plan.md` §3.2, §3.3:** `RoadGenerator.Kind`: T, CROSSROADS, SIDE_ROAD and DECOY. A side road's wrong exit is straight on, and it has no opposite turn. A decoy's correct exit is straight on (R2), and its wrong exit is the opposite turn. Prototype (§5.1, E1) |
| R2 | Straight on is never correct. Every part of the game assumes that each junction is a turn. The generator turns and counts at each one. The trigger counts each correct exit as a turn. Each junction has its own turn number, and areas and set pieces fall due after junctions. | `road_generator.gd`:101–103 (`_heading = expected`, `turn_count += 1`, `_due_entry()`); `road/junction_trigger.gd`:62 (`turn_index += 1`); `road/road_tile.gd`:17 (`turn_number`) and :19 (`expected_exit`); `plan.md` §2.1 rules 3, 4 and 6 | **Δ `plan.md` §2.1 rules 3, 4 and 6:** a decoy keeps the heading, the turn count and the schedule as they were, and shares its `turn_number` with the next junction. `RoadTile.is_turn()` is true for a junction whose correct exit isn't straight on. The trigger counts only those, but still emits `turn_completed` at every correct exit, so the chime, the straight's distance and the HUD react as they do at a turn, and the HUD's count stays. Prototype (§5.2, E2) |
| R4 | Dead ends of 2–3 tiles look like stubs, not roads (the owner's Q3). On every reference screen, their end is in view as the car enters the junction. A stub straight on reads as a dead end at a glance, which spoils a side road's trick. | `config/tuning.gd`:19–21 (`DEAD_END_MIN_TILES` 2, `DEAD_END_MAX_TILES` 3); `plan.md` §3.3; IP M1.4 (:211). P4: on the 7 reference screens, the end of a 2- or 3-tile dead end is in view as the car enters the junction, at every junction | **Δ `plan.md` §3.3, IP M1.4:** 6–9 tiles (Q3). Below 6, the two wide landscape screens, 1639×640 and 1137×640, show the end as the car enters the junction (P4). The buffer follows (R6). Prototype (§5.3, E5) |

### Medium

| # | Finding | Evidence | Fix |
|---|---|---|---|
| R3 | `cross_junction_chance` is the only chance, and `validate()` checks it alone. New chances need their bounds and their sum checked. They also need a fixed order in the roll; otherwise an area without the new kinds would change its road. | `areas/area_def.gd`:17 and :69–70 | `side_road_chance` and `decoy_chance`, 0 by default. `validate()` checks each one, and checks their sum against 1 with `is_equal_approx()`, so that 0.3 + 0.3 + 0.4 passes. `kind_for()` reads the crossroads, side road and decoy from one `randf()`, the draw that M1 made for the crossroads, so PR 1 keeps every road. Prototype (§5.1, E3, E4) |
| R5 | A dead end that runs into a taken cell is shortened to 1 tile, or dropped. With 6–9 tiles, an 8-tile dead end with 7 free cells would become a 1-tile stub, which looks like a glitch. And the comments only claim that a 1-tile stub always fits. | `road_generator.gd`:115–134 (`_place_dead_end()`: the drawn length, then 1, then nothing) and :6–9; IP M1.4 (:235) | **Δ `plan.md` §3.3, IP M1.4 (:235, :242):** stop the dead end right before the first taken cell (`_free_run()`). The path's shape leaves a straight-on dead end its whole length, and an opposite-turn one at least 2 cells, so none is dropped. Prototype (§5.3, E5) |
| R6 | The buffer is sized for 3-tile dead ends. A row of props must have every tile its frames could touch before it is made, and that includes dead ends reaching down from `DEAD_END_MAX_TILES` rows above. At 9, a row needs 36 tiles ahead of the car, but the buffer refills at 30. And a freed junction's straight-on dead end reaches 9 rows above it, into the tallest screen's view at `BUFFER_BEHIND` 14. | `world/prop_layout.gd`:58–63 (`rows_needed()` is `rows_above() + DEAD_END_MAX_TILES`, or twice `set_piece_margin()`, 4, if that's more: 6 on `main`, 12 at 9); `tuning.gd`:8–16 (`BUFFER_REFILL_AT` 30; `BUFFER_BEHIND` 14, whose comment counts 3 rows); `test_prop_scatter.gd`:93; `test_props_in_view.gd` | **Δ M5_PLAN.md L2, IP M1.5:** `BUFFER_REFILL_AT` 37. That is at least `PROP_AHEAD` (24) + 12 = 36, and 37 lets K1's check in `test_area_schedule.gd` still meet every point of the refill cycle (Q4). `BUFFER_BEHIND` 20: M5's 14 plus the 6 more rows. Prototype; at 36, K1's check failed in CI (§5.4, P6, E6) |

### Low

| # | Finding | Evidence | Fix |
|---|---|---|---|
| R7 | Comments and `plan.md` that the new kinds and lengths make wrong | `road_generator.gd`:6–9 ("within 6 path steps", "a one-tile stub always fits") and :13 (`turn_count`); `junction_trigger.gd`:73–74 ("well under its 25-tile lookahead": the lookahead is 30–55 since M5's L2, and 37–55 with R6); `road_tile.gd`:17 and :19; `tuning.gd`:19; `plan.md` §2.1, §3.2, §3.3 and §3.7 | PRs 1 and 2 rewrite each one that they make wrong (§5.7, E11) |
| R8 | At a decoy, staying off the road too long ends the run with "You missed the turn!", though a decoy has no turn to miss | `road/junction_trigger.gd`:52–55: the off-road limit fails the next junction, whatever it is (`test_junction_trigger.gd`:177, `test_the_offroad_limit_is_a_missed_turn`); `ui/game_over.gd`:17–18 and M3_PLAN.md:494–497: that cause's message | None (Q5): the player left the road near a junction, as anywhere else |
| R9 | Masks 11 (N, E, W) and 13 (N, S, W), a side road's, have never been seen in a run. Each area's road sheet draws them, and a test checks that they're opaque where the road is, but not how they look | `world/greybox_atlas.gd`:4–5 and :78, and `tools/art/make_art.gd`:76, draw all 15 masks; `test_area_art.gd`:35 | E10 looks at them on the Web and the Fold4 |

---

## 3. Decisions and open questions

The prototype follows the defaults. Q1 and Q3 are the owner's answers to the first draft. Each alternative changes the PRs named.

| # | Question | Default | Alternative |
|---|---|---|---|
| Q1 | Can straight on be correct? | **The owner's answer: yes**, "both straight and turn could be the right decision". So there are side roads, where the turn is right and straight on is a dead end, and decoys, where straight on is right and the turn waits (§5.2) | The first draft: side roads only. That needs no change to the trigger or the turn count. But a player who knows that every junction is a turn turns at each one, so a side road would trick only a player who lost count |
| Q2 | Each area's chances | The City has none, as it teaches the pattern. Side roads and decoys: Rural 0.15 and 0.1, Meadows 0.2 and 0.15, the Village 0.2 and 0.15, the Desert 0.25 and 0.2. Each area keeps its crossroads chance, and at least a quarter of its junctions are T's (§5.5) | Other values. Each is one line in an area's `.tres`, and PR 3 re-records the digests |
| Q3 | How long are dead ends? | **The owner's answer: longer**, "so it looks like a proper road". 6–9 tiles: the shortest at which no reference screen shows the end of an uncut dead end as the car enters its junction (P4). The buffer grows to hold them (R6) | 4–7: on the wide screens, an end shows at 60–73% of junctions (P5). Longer than 6–9, such as 8–12: a larger buffer and more dead ends cut short, but fewer ends in view from the leg before (§5.3) |
| Q4 | `BUFFER_REFILL_AT` | 37. Its refill cycle of 19 tiles is a prime, so K1's check (`test_area_schedule.gd`:238) still finds the 1 spare tile | 36, the least that R6 needs. Its cycle of 20 tiles is met at only 5 points by the check's schedule, which finds 3 spare tiles and fails (P6). The check would need set pieces of 3 and 4 tiles in turn |
| Q5 | The off-road limit at a decoy (R8) | "You missed the turn!", as anywhere | A message of its own, in `CarSim` and `ui/game_over.gd` |
| Q6 | How RG lands | This plan's PR, then 3 stacked PRs: the kinds, the dead ends, the areas' chances (§4) | One PR: simpler to land, harder to review |
| Q7 | Which documents change | `plan.md` §2.1, §3.2, §3.3 and §3.7, in PRs 1 and 2. IP stays as M1–M5 left it, and this plan replaces it where it says Δ | Fold this plan into IP as well |

---

## 4. Work breakdown

There are three PRs after this plan's, and each one leaves CI green (E9).

```
plan PR ──▶ PR 1 junction kinds ──▶ PR 2 long dead ends ──▶ PR 3 area chances
 (docs)      (R1–R3, R7)             (R4–R7, Q3, Q4)          (Q2)
```

After PR 1, the generator can make side roads and decoys, but no area has them, so the game's road is `main`'s. PR 2 makes dead ends 6–9 tiles and grows the buffer. PR 3 gives four areas their chances.

### 4.1 Porting from the prototype

Each PR's changes are the difference between two states of `rg/prototype`, so every PR follows the same steps:

1. Fetch the branches and create the PR's branch:
   ```bash
   git fetch origin main '+refs/heads/rg/*:refs/remotes/origin/rg/*'
   git switch -c rg/1-junction-kinds origin/rg/plan   # PR 2 from rg/1-junction-kinds, PR 3 from rg/2-long-dead-ends
   ```
2. Apply the PR's difference with `git diff <from> <to> | git apply --index`, using the states in its section. If a review fix on an earlier branch changed the same lines, use `git apply --3way --index` and keep both.
3. Run §6.1, or CI without Godot, and compare the counts with the PR's "Expect" line.
4. Have a model of another family review it (`AGENTS.md` §7). Then commit, push and open the PR.

### PR 1: Road: junction kinds, side roads and decoys **Δ R1–R3, R7**

Branch `rg/1-junction-kinds`, from `rg/plan`. `git diff 4ade5f2 cb2c7f9 | git apply --index`.

| Area | Files |
|---|---|
| Road | `road/road_generator.gd`: `Kind`, `kind_for()` and `_junction()` (§5.1, §5.2); `road/road_tile.gd`: `is_turn()`, and the `turn_number` and `expected_exit` comments; `road/junction_trigger.gd`: counts only turns (§5.2) |
| Areas | `areas/area_def.gd`: `side_road_chance`, `decoy_chance` and `validate()` (R3) |
| Docs | `plan.md` §2.1 rules 3, 4 and 6, §3.2, §3.3 and §3.7 (§5.7) |
| Tests | New `tests/unit/test_area_def.gd` (1 test); `tests/helpers/road_fixtures.gd`: `kinds_schedule()` and `kind()`; `test_road_generator_pattern.gd` (2 new); `test_road_generator_occupancy.gd` (1 new, and a check that a straight-on dead end is never cut short); `test_road_generator_determinism.gd` (1 new: the game's road digests); `test_junction_trigger.gd` (1 new, and `test_each_kind_of_junction_has_one_correct_exit` replaces `test_every_wrong_exit_of_a_crossroads_is_a_disaster`); `tests/sim/test_autopilot_300_turns.gd` (1 new); `tests/integration/test_area_start.gd` and `tests/helpers/wrong_turn_pilot.gd` count only turns (§5.6) |

15 files, +435 −130, including `test_area_def.gd.uid`. Expect: `check_scripts: loaded 126 scripts`; `GUT: 425 tests passed` (272,401 asserts, 66.8 s in CI); `autopilot: tile 165, turns 35, area rural`. Both digests stay `main`'s (E4). Negative cases N1–N6 and N13.

**Acceptance:** E1–E4, E7, E9 and E11.

### PR 2: Road: dead ends of 6 to 9 tiles **Δ R4–R7, Q3, Q4**

Branch `rg/2-long-dead-ends`, from `rg/1-junction-kinds`. `git diff cb2c7f9 f002f6a | git apply --index`, then §4.6's first row.

| Area | Files |
|---|---|
| Config | `config/tuning.gd`: `DEAD_END_MIN_TILES` 6, `DEAD_END_MAX_TILES` 9, `BUFFER_REFILL_AT` 37 and `BUFFER_BEHIND` 20, with their comments (R4, R6) |
| Road | `road/road_generator.gd`: `_place_dead_end()` and `_free_run()` stop a dead end before a taken cell, and the header and `shortened_count`'s comment (R5); `road/junction_trigger.gd`: `_junction_after()`'s comment (R7) |
| Docs | `plan.md` §3.3 |
| Tests | `test_camera_rig.gd`: 1 new (R4); `test_road_generator_occupancy.gd`: at least 2 tiles, a short dead end stops before a taken cell, and a log line of the short ones; `test_road_generator_pattern.gd`: 2 to `DEAD_END_MAX_TILES` tiles; `test_road_generator_determinism.gd`: the road's new digest; `tests/integration/test_props_in_view.gd`: a comment |

9 files, +100 −34. Expect: 126 scripts; `GUT: 426 tests passed` (389,074 asserts, 64.5 s in CI); the same smoke line. The occupancy test logs `130320 dead ends, 15061 (11.6%) shorter than DEAD_END_MIN_TILES`. The path's digest stays (E4). Negative cases N7–N12.

**Acceptance:** E4–E6, E9 and E11.

### PR 3: Areas: side roads and decoys outside the City **Q2**

Branch `rg/3-area-chances`, from `rg/2-long-dead-ends`. `git diff f002f6a 3c2ca03 | git apply --index`, then set §6.1's two digests for PR 3 in `test_road_generator_determinism.gd`.

| Area | Files |
|---|---|
| Areas | `areas/rural.tres`, `meadows.tres`, `village.tres` and `desert.tres`: `side_road_chance` and `decoy_chance` (§5.5) |
| Tests | `test_road_generator_determinism.gd`: both digests, as decoys change the path |

5 files, +10 −2. Expect: 126 scripts; `GUT: 426 tests passed` (421,842 asserts, about 80 s in CI). The occupancy test logs `156022 dead ends, 19646 (12.6%) shorter than DEAD_END_MIN_TILES`. The smoke line comes from this PR's CI: decoys in Rural may change its tile and turn counts. Then E10, on this PR's build (§6.4).

**Acceptance:** E4, E8, E9 and E10.

### 4.5 Landing the stack (Q6)

The PRs land by `AGENTS.md` §5's procedure for stacked PRs, with the `rg/` names. This plan's PR targets `main`, PR 1 targets `rg/plan`, PR 2 `rg/1-junction-kinds`, and PR 3 `rg/2-long-dead-ends`. Only a PR whose base is `main` merges. The plan changes only on `rg/plan` until its PR merges, and after that on the branch of the lowest open PR. A review fix goes on the branch of the PR that owns the file, and is merged into each later branch with `git merge --no-ff --no-edit`.

After PR k's squash merge, PR k+1 merges PR k's final branch and then `main`:

```bash
git fetch origin main '+refs/heads/rg/*:refs/remotes/origin/rg/*'
git switch <PR k+1's branch>
git merge origin/<PR k's branch>
git merge -X ours origin/main
git diff --name-only origin/main    # must list only PR k+1's files
git diff origin/main                # must be PR k+1's own changes, as before the merge
git push
gh pr edit <PR k+1> --base main     # unless GitHub retargeted it
```

**Why `-X ours`.** Unlike M5's PRs, these change the same lines in turn. PR 2 rewrites `_place_dead_end()`, the header and tests that PR 1 changes, and PR 3 changes the digest line that PR 2 changes. A squash commit isn't an ancestor of the next branch, so the merge base stays where the branches started, and each line that both changed conflicts. In `git merge-tree`, PR 2's merge of PR 1's squash conflicted in `plan.md`, `road/road_generator.gd`, `test_road_generator_determinism.gd`, `test_road_generator_occupancy.gd` and `test_road_generator_pattern.gd`. PR k+1's branch already holds PR k's final state, so its side of each conflict is right. With `-X ours`, the merge was clean and gave exactly f002f6a's tree, and `git diff --name-only` against PR 1's state listed only PR 2's 9 files. M1's stack needed `-X ours` too, for add/add conflicts (M2_PLAN.md:301). But `-X ours` would also keep PR k+1's side of lines that `main` changed for another reason, so compare the diff against `main` with the PR's diff before pushing. PR 3's merge of PR 2's squash conflicts only in the road digest's line: simulated without it, the merge was clean.

The plan's squash adds `ROADGEN_PLAN.md` as PR 1's branch has it, once `rg/plan` is merged into it, so PR 1's merge of `main` is clean. The merges change no files in PR k+1, so the push may start no Copilot review. Request one with `gh pr edit <PR k+1> --add-reviewer @copilot` if the PR needs it.

### 4.6 Review fixes

The internal review of this plan (`AGENTS.md` §7) and the PRs' reviews add their fixes here, each with its tests and its negative case.

| PR | Change | Tests | Negative case |
|---|---|---|---|
| 2 | P4's model of the camera showed that `test_camera_rig.gd`'s new test checks one moment, the car entering the junction. Its name and the comments said "as the car comes to its junction", but on the approach an opposite-turn dead end of exactly 6 tiles shows its end on 1639×640, just before the junction (§5.3). The test is now `test_a_dead_end_ends_out_of_view_as_the_car_enters_its_junction`, and `tuning.gd`, `plan.md` §3.3 and the occupancy test's comment say "enters" | `test_camera_rig.gd`: renamed | None: wording only |

---

## 5. Design

### 5.1 Junction kinds (R1, R3)

`RoadGenerator.Kind` names a junction's exits besides its entry. The masks are `Heading.bit()`s with the entry: N is 1, E 2, S 4 and W 8. At heading N the entry is S, the turn W and the opposite turn E; at heading W, the entry is E, the turn N and the opposite turn S.

| Kind | Exits | Correct | Wrong, each with a dead end | Mask at heading N | Mask at heading W |
|---|---|---|---|---|---|
| T | The turn, the opposite turn | The turn | The opposite turn | 14 | 7 |
| CROSSROADS | All three | The turn | The opposite turn, straight on | 15 | 15 |
| SIDE_ROAD | The turn, straight on | The turn | Straight on | 13 | 11 |
| DECOY | Straight on, the opposite turn | Straight on | The opposite turn | 7 | 14 |

A decoy's mask is a T's at the other heading, and its tile is a `T_JUNCTION`. Masks 11 and 13 are new in runs (R9).

`kind_for(roll, area)` is static and pure. The crossroads chance takes 0 up to c, the side road chance the next s, the decoy chance the next d, and T the rest, with `<` at each bound:

```gdscript
static func kind_for(roll: float, area: AreaDef) -> Kind:
	var bound := area.cross_junction_chance
	if roll < bound:
		return Kind.CROSSROADS
	bound += area.side_road_chance
	if roll < bound:
		return Kind.SIDE_ROAD
	bound += area.decoy_chance
	if roll < bound:
		return Kind.DECOY
	return Kind.T
```

`_junction()` draws the roll with `randf()` where M1 drew its crossroads roll. Then it draws one `randi_range(DEAD_END_MIN_TILES, DEAD_END_MAX_TILES)` per wrong exit, in a fixed order (the opposite turn, then straight on), and then the next straight. So:

- With `side_road_chance` and `decoy_chance` at 0, every junction draws what M1's did, and the road is `main`'s (E4).
- A side road draws what a T draws: one roll, one length and a straight. A T that becomes a side road keeps the path and the stream; only its dead end moves.
- A decoy draws a roll, a length and a straight, and doesn't turn, so the path after it changes. D8 allows that, and PR 3 says so.

A junction left with no wrong exit is reported with `push_error()` (`AGENTS.md` §3). §5.3's geometry rules it out.

### 5.2 Decoys (R2)

A decoy is a junction that isn't a turn: `RoadTile.is_turn()` is `is_junction() and expected_exit != heading`.

- **Generator.** At a decoy, `_junction()` sets `expected_exit` to the heading, places the opposite turn's dead end, samples the next straight and returns. The heading, `turn_count` and the schedule stay as they were. So the next junction gets the same `turn_number` and expects the same turn.
- **Trigger.** `_resolve()` adds to `turn_index` only at a turn, but emits `turn_completed(turn_index)` at every correct exit. Its listeners react as they do at a turn: the HUD shows the same count, the chime plays (`autoload/audio_director.gd`:241), and `CarSim` restarts the straight's distance (`car/car_sim.gd`:307), so the car speeds up after a decoy as after any junction (`plan.md` §2.3). The opposite turn is a wrong turn, and the off-road limit is a missed turn (R8). `_junction_after()` still finds every junction, decoys included, so a decoy's wrong exit is judged.
- **Speed.** The car brakes before the trigger's next junction (`car/car_sim.gd`:128 and :186), so before a decoy as before any junction, whichever exit the player takes. As `plan.md` §2.3 asks, the speed shows nothing of which exit is right.
- **Autopilot.** It follows the correct path's centreline (`car/autopilot.gd`:3–4), which leaves a junction through `expected_exit` (`car/car_sim.gd`:160): straight on, at a decoy.
- **Schedule.** Areas and set pieces fall due after turns, as before. `AreaSchedule`'s bound on the distance between junctions still holds, as a straight follows a decoy as it follows any junction.
- **Rejoining.** A car that leaves the road and rejoins further on resolves the junctions it passed. `test_rejoining_past_a_decoy_counts_only_the_turns` checks that a decoy among them doesn't count.
- **The player's rule.** Take the pattern's next turn if the junction offers it, otherwise go straight on. Together, the kinds leave no tell: straight on is offered at crossroads, side roads and decoys, and is right only at decoys; the turn is offered everywhere but at decoys.

### 5.3 Dead ends (R4, R5)

**Length.** `DEAD_END_MIN_TILES` 6, `DEAD_END_MAX_TILES` 9 (Q3).

**Cut short, never a stub.** `_free_run(from, exit, length)` counts the free cells up to the first taken one. `_place_dead_end()` lays that many, counts the dead end in `shortened_count` if they're fewer than it drew, and drops the exit only at 0, counting it in `dropped_count`:

```gdscript
func _place_dead_end(junction: RoadTile, exit: int, length: int) -> void:
	var fits := _free_run(junction.cell, exit, length)
	if fits == 0:
		dropped_count += 1
		return
	if fits < length:
		shortened_count += 1
	# ... lays `fits` DEAD_END tiles, the last one a cap
```

**Why it always fits.** The path heads N, then W and N in turn, so it moves only towards −x and −y. A dead end points E or S (the opposite turn), or straight on (N or W) while the path turns away:

- A straight-on dead end always fits whole. No earlier tile lies beyond the junction in its column (at heading N) or its row (at heading W), and later path tiles move away from it.
- An opposite-turn dead end can only be cut by an earlier junction's straight-on dead end, whose column (or row) it crosses. The nearest is that of the junction two turns back. Its column (or row) is at least 3 cells away, past a straight of at least 2 tiles (D7), so at least 2 cells stay free. Decoys between them only move it further away, and have no straight-on dead end.
- Dead ends never touch the path. They can only meet the dead ends of junctions within 2 × `DEAD_END_MAX_TILES` = 18 path steps, which are all in the buffer (§5.4).

The occupancy test checks all three over 200 seeds × 500 turns of the game's schedule: no dead end has fewer than 2 tiles, no straight-on one fewer than 6, each short one ends before a taken cell, and none is dropped. In the game's areas, 11.6% of dead ends end short after PR 2, and 12.6% after PR 3, as side roads add straight-on dead ends (P3). Most of them are in the City and the Village, whose crossroads are commonest and whose straights are shortest.

**In view.** As the car enters a junction's tile, with the camera on its target, which is as far ahead as the smoothed camera gets, the end of a dead end of 6 tiles is out of view on each of the 7 reference screens, straight on or the other way (`test_camera_rig.gd`). At 5 tiles, the wide landscape screens 1639×640 and 1137×640 show it. On the approach, the view closes in on a straight-on dead end along its own line, so its end is nearest the view at that moment, and stays out of view all along the approach. P4 modelled the rest, with the camera's smoothing at 2, 4 and 7 tiles a second:

- On the approach, an opposite-turn dead end of exactly 6 tiles peeks in at a corner of 1639×640, the Fold4's cover screen in landscape, in the last 0.03–0.7 tiles before the junction, later and shorter the faster the car. At 7 tiles or more it never does.
- The leg before the approach runs alongside the opposite-turn dead end, as many rows away as the approach is long plus 1. From that leg, every screen shows the dead end's end when the approach is short (up to 3–8 tiles, by screen), whatever its length, as on `main`.
- From the leg before, the two tall portrait screens, 360×922 and 360×800, show a straight-on dead end's end when the approach is short: at 6 tiles, approaches of up to 4 and 3 tiles; at 7, up to 3 and 2; at 8, up to 2 tiles on 360×922 only; at 9, never.
- A dead end that is cut short shows its end like any short one.

What the player sees of an end tells them only that an exit is a dead end, which the junction's shape and the player's rule already tell them. So the length is for the look (§8).

### 5.4 The buffer (R6, Q4)

`PropLayout.rows_needed()` grows from 6 to 12 with `DEAD_END_MAX_TILES`, so a row of props needs `PROP_AHEAD` + 12 = 36 path tiles ahead of the car before it is made, and `BUFFER_REFILL_AT` must be at least 36: below that, `test_prop_scatter.gd`:93's fuzz fails.

The refill cycle is `BUFFER_AHEAD - BUFFER_REFILL_AT + 1` tiles: 26 on `main`, 20 at 36, and 19 at 37. K1's check in `test_area_schedule.gd` (:238–253) drives a schedule at `AreaSchedule`'s limit, with 4-tile set pieces and the longest straights, and asserts that the least spare tile count it finds, past the next junction, is exactly K1's 1. It finds the 1 only if the schedule's junctions meet every point of the refill cycle. A cycle of 20 shares a factor of 4 with the schedule's, so they meet only 5 points of it, and the least found is 3 (P6). A cycle of 19, a prime, is met at all its points. The bound is safe at 36 as well; the check just can't show that it is tight. Q4's alternative changes the check instead.

`BUFFER_BEHIND`: the highest thing above a freed path tile is its junction's straight-on dead end, `DEAD_END_MAX_TILES` rows above it. For 3 rows, M5 measured that 14 leaves 44 px below the tallest view at top speed, and 13 only 12 px (M5_PLAN.md:532, P1). Each row more needs a tile more, so 9 rows need 20, with the same 44 px; `test_props_in_view.gd` passes at 20 in CI. The lookahead stays within 37–55 tiles, and the junction trigger's next junction is always in it (`_junction_after()`'s comment).

### 5.5 Area chances (Q2)

| Area | Straights | Crossroads | Side roads | Decoys | T's |
|---|---|---|---|---|---|
| City | 2–5 | 0.4 | 0 | 0 | 0.6 |
| Rural | 3–7 | 0.25 | 0.15 | 0.1 | 0.5 |
| Meadows | 3–7 | 0.3 | 0.2 | 0.15 | 0.35 |
| Village | 2–5 | 0.35 | 0.2 | 0.15 | 0.3 |
| Desert | 3–8 | 0.3 | 0.25 | 0.2 | 0.25 |

The City has none: a run's first 34 turns teach the pattern on T's and crossroads. The chances grow along the run, and every area keeps at least a quarter of T's, so the new kinds stay a surprise. Each chance is one line in the area's `.tres`, after `max_straight`, or after `cross_junction_chance` where an area sets it. An area without the lines has 0.

### 5.6 Tests and fixtures

- `Fixtures.kinds_schedule(cross, side, decoy)` is one area with those chances, for the kinds' tests. `Fixtures.kind(junction)` reads a junction's kind from its exits.
- `test_one_roll_picks_the_kind_from_the_chances_in_order`: `kind_for()` at and around each bound.
- `test_junctions_offer_the_exits_of_their_kind_as_often_as_its_chance`: crossroads 0.1, side roads 0.2, decoys 0.3 and T's 0.4, each within 0.04.
- `test_every_kind_of_junction_keeps_its_wrong_exits`: each kind's exits and dead ends.
- `test_each_kind_of_junction_has_one_correct_exit`: every exit of each kind, through the trigger: one is correct, and the others are disasters.
- `test_rejoining_past_a_decoy_counts_only_the_turns` (§5.2).
- `test_expected_exits_alternate_left_and_right` now runs on `kinds_schedule(0.25, 0.25, 0.25)` as well, and checks that a decoy hides the turn whose number it shares.
- `test_the_game_road_matches_its_digests`: MD5 digests of the game's road for seeds 0–19 up to turn 300, of the path tiles alone and of the path tiles with their dead ends. That's 35,367 path tiles on `main`, and 41,206 after PR 3, whose decoys add junctions. PR 1 keeps both digests, and PR 2 changes only the road's.
- `test_validate_reports_junction_chances_that_cannot_be`: below 0, above 1, a sum above 1, and a sum of 1 whose floats round above it.
- `test_300_turns_through_every_kind_of_junction`: the autopilot, on `kinds_schedule(0.25, 0.25, 0.25)`.
- `test_a_dead_end_ends_out_of_view_as_the_car_enters_its_junction` (PR 2): `test_camera_rig.gd`'s 7 reference screens, both headings, and both dead ends of `DEAD_END_MIN_TILES` tiles. The end is the road's round cap, a box of `ROAD_HALF_WIDTH` × √2 tiles around the last tile's centre.
- The occupancy test logs how many dead ends it saw, and how many were shorter than `DEAD_END_MIN_TILES`.

### 5.7 Documents and comments (R7, Q7)

- `plan.md` §2.1 (PR 1): rule 3 adds decoys; rule 4 makes a missed turn one at a junction that offers the turn; rule 6 says that straight on at a decoy doesn't count.
- `plan.md` §3.2 (PR 1): the four kinds. §3.3 (PRs 1 and 2): the side road, the decoy, 6–9-tile dead ends, and a dead end stopping before a taken cell. §3.7 (PR 1): the two chances.
- `plan.md` §3.4 still gives M1's buffer (50, 25 and 5), which M5's L2 changed. RG leaves it, as M5 did (§9).
- The comments R7 lists, in the PR that makes each one wrong.

---

## 6. Verification

### 6.1 Checks and counts

The checks are `AGENTS.md` §4's five. This plan's numbers are CI's, from `workflow_dispatch` runs on `rg/prototype`:

| State | Run | Scripts loaded | Test scripts | Tests | Asserts | GUT time | Smoke |
|---|---|---|---|---|---|---|---|
| `main` (4ade5f2) | 42940083409 | 125 | 60 | 418 | 147,736 | 58.1 s | `autopilot: tile 165, turns 35, area rural` |
| PR 1 (fb8bccb) | 42980918434 | 126 | 61 | 425 | 272,401 | 66.8 s | The same |
| PR 2 (f002f6a) | 42986814437 | 126 | 61 | 426 | 389,074 | 64.5 s | The same |
| PR 3 (3c2ca03) | 42986884807 | 126 | 61 | 426 | 421,842 | 80.2 s | Not run: the digests failed |

cb2c7f9 adds a check to an existing test, with no new assert, so PR 1's counts are fb8bccb's. PR 2's run ran that check. The `test` job took 2 min 04 s on PR 1 and 2 min 21 s on PR 2.

The digests, in `test_road_generator_determinism.gd`:

| State | `PATH_DIGEST` | `ROAD_DIGEST` |
|---|---|---|
| `main` and PR 1 | `811569241f55e1fce2a50331fe4c3e7d` | `33b32b4135f684041d8772ec3661e3ce` |
| PR 2 | `811569241f55e1fce2a50331fe4c3e7d` | `3135d6c1c4c1b505121ff96b02dc202b` |
| PR 3 | `b596a88cc0b5a09fc5db329cf0af264d` | `d6b8a6e863a39539fe21c0ee9f5c18d0` |

To record new digests, set them to `""` and run the tests: the failures give the new values. A commit that changes them says why (E4).

### 6.2 Negative cases

Each change below should make the named checks fail. They weren't run: the session had no Godot, and the scratch pushes they'd need for CI weren't allowed. To run one with Godot 4.7.2, apply its change to the PR's head, run `tools/ci/run_tests.sh`, check the failures, and restore the file.

| N# | PR | Change | Should fail |
|---|---|---|---|
| N1 | 1 | `_resolve()` adds to `turn_index` at every correct exit | `test_rejoining_past_a_decoy_counts_only_the_turns`, `test_each_kind_of_junction_has_one_correct_exit` |
| N2 | 1 | A decoy counts a turn: `turn_count += 1` before its early return | `test_expected_exits_alternate_left_and_right` on `kinds_schedule()` |
| N3 | 1 | A side road gets no straight-on dead end | `_junction()`'s `push_error()`, and `test_every_kind_of_junction_keeps_its_wrong_exits` |
| N4 | 1 | `<=` for `<` in `kind_for()` | `test_one_roll_picks_the_kind_from_the_chances_in_order` |
| N5 | 1 | `validate()` without the sum check | `test_validate_reports_junction_chances_that_cannot_be` |
| N6 | 1 | The sum check without `is_equal_approx()` | The same test's rounding case |
| N7 | 2 | Straight-on dead ends of 1 tile | `test_road_generator_occupancy.gd` and `test_road_generator_pattern.gd` |
| N8 | 2 | `_place_dead_end()` lays 1 tile whenever the dead end doesn't fit | The occupancy test's "before a free cell" check |
| N9 | 2 | `_free_run()` returns `maxi(k - 2, 0)` | The same check |
| N10 | 2 | `DEAD_END_MIN_TILES` 5 | `test_a_dead_end_ends_out_of_view_as_the_car_enters_its_junction` on 1639×640 and 1137×640, and the road digest |
| N11 | 2 | `BUFFER_BEHIND` 19 | `test_props_in_view.gd` |
| N12 | 2 | `BUFFER_REFILL_AT` 35 | `test_prop_scatter.gd`:93's fuzz, and K1's check |
| N13 | 1 | `_junction_after()` skips decoys (`is_turn()` for `is_junction()`) | `test_each_kind_of_junction_has_one_correct_exit`: a decoy's wrong exit isn't judged |

### 6.3 Editor warnings

Not measured: the session couldn't run the editor. M5 left 5 (M5_PLAN.md §6.3). By reading, no new name shadows a member or a built-in (`AGENTS.md` §3): the fixtures' parameters are `cross`, `side` and `decoy`; `kind_for()` takes `roll` and `area`; `_free_run()` takes `from`, `exit` and `length`. Whoever runs Godot on the PRs should confirm it (§7).

### 6.4 Verified only in CI or on devices

- **CI.** The five required checks on each PR, and the `test` job's time.
- **E10 on the Web**, on PR 3's build, by an agent if it can, or else by the owner. Build, download and serve it with M4's patch, which passes the URL's `arg`s to the game (M4_PLAN.md §4, PR 3 step 3):
  ```bash
  gh workflow run ci.yml -R pompomon/roadgame --ref rg/3-area-chances -f upload-builds=true
  gh run download <run id> -R pompomon/roadgame -n web -D /tmp/roadgame-web
  sed -i 's/"args":\[\]/"args":["--"].concat(new URLSearchParams(location.search).getAll("arg"))/' \
    /tmp/roadgame-web/index.html
  python3 -m http.server -d /tmp/roadgame-web 8000
  ```
  Open `http://localhost:8000/?arg=--autopilot&arg=--area=desert` in Chrome and Firefox, and the same for `meadows`, `village` and `rural`, to watch; and `?arg=--play&arg=--area=desert` to drive, as `--play` skips the title (M5_PLAN.md:349). In the Desert, 45% of junctions are side roads or decoys. Check each point of E10, and post a table in a PR comment, one row per check, with screenshots.
- **On the Fold4**, by the owner. The APK takes no arguments (M4_PLAN.md P4), so drive into Rural, at turn 34: with its chances, 94% of runs meet a side road or a decoy in Rural's first 10 junctions. Or, as M4 did (M4_PLAN.md Q6), serve the Web build above, run `adb reverse tcp:8000 tcp:8000`, and open the same URLs in the Fold4's Chrome. Check the look on both screens, that a dead end reads as a road and not a stub, and that the trick feels fair.

### 6.5 Measurements

| P# | What | Result | Used by |
|---|---|---|---|
| P1 | The five checks in CI, on each state of the prototype | §6.1 | E9 |
| P2 | The digests. 03c79b7's run 42978434562, with the digests empty, printed `main`'s; the later runs printed PR 2's and PR 3's | §6.1: PR 1 keeps both, and PR 2 the path's | E4 |
| P3 | The dead ends in the occupancy test, 200 seeds × 500 turns of the game's schedule | PR 2: 130,320 dead ends, of which 15,061 (11.6%) are shorter than 6 tiles. PR 3: 156,022, and 19,646 (12.6%). None dropped, none under 2 tiles, no straight-on one short | R5, E5 |
| P4 | The ends in view. A Python model of `CameraRig.target()`, `zoom_for()` and the smoothing, with `Iso`'s tiles, and the end as `test_camera_rig.gd` takes it, on the 7 reference screens | As the car enters the junction: dead ends of 2–5 tiles show their end on 1639×640 and 1137×640; of 6 or more, on no screen. On the approach and from the leg before, with the smoothing at 2, 4 and 7 tiles a second and approaches of 2–8 tiles: §5.3 | R4, Q3, §4.6 |
| P5 | The share of junctions where some dead end's end is in view as the car enters, on the wide screens, by area with PR 3's chances: a Python model of the generator and the camera | 6–9 tiles: the City 40%, the Village 39%, Rural 16%, Meadows 17% and the Desert 12%, all of them dead ends cut short. 4–7 tiles: the City 73%, the others about 60%. `main`: every junction | Q3 |
| P6 | K1's check at `BUFFER_REFILL_AT` 36 (8da3835, run 42985667487) | Failed: it found 3 spare tiles, not 1. The road digest failed too, as expected before it was recorded | R6, Q4 |
| P7 | The landing, with `git merge-tree --write-tree --merge-base` | §4.5 | Q6 |

---

## 7. Owner actions

| When | Action | How |
|---|---|---|
| Now | Review this plan, and answer Q2 and Q4–Q7 or accept the defaults | A comment on this plan's PR. Without an answer, the PRs follow the defaults |
| Before PR 3 merges | E10 on the Fold4 | `gh workflow run ci.yml -R pompomon/roadgame --ref rg/3-area-chances -f upload-builds=true`; `gh run download <run id> -R pompomon/roadgame -n "android-Android APK" -D /tmp/roadgame-apk`; `adb install -r /tmp/roadgame-apk/roadgame-debug.apk`. Then §6.4 |
| Optional, before merging | §6.2's negative cases and §6.3's warnings, with Godot 4.7.2 | §6.2 |
| To land RG | Merge this plan's PR, then PRs 1, 2 and 3, each once its base is `main` | §4.5 |
| After | Delete the prototype's branch | `git push origin --delete rg/prototype` |

---

## 8. Risks

| Risk | Impact | Mitigation |
|---|---|---|
| Decoys change the road from Rural on | A seed gives a different road after Rural's first decoy (D8) | Said in PR 3, whose digests record it. Nothing saved holds a road |
| Ends still show in some views (§5.3) | From the leg before, an opposite-turn dead end's end shows on every screen after a short approach, and a straight-on one's on the tall portrait screens. A cut one shows like any short one: at about 40% of the City's junctions | These exits are wrong wherever they are, and the player's rule decides from the turn alone, so an end gives nothing away; it only spoils the look. Longer dead ends hide more, for a larger buffer (Q3). Art could end a dead end in something that reads as a road's end (§9) |
| The trick feels unfair | A missed side road or decoy ends the run | Judged on the Fold4 (E10). Each chance is one line in an area's `.tres` (Q2) |
| Masks 11 and 13 look wrong in some area's art | Seen only in E10 | The road sheets are generated (`tools/art/make_art.gd`): fix them there |
| Verified only in CI | A count may differ locally, and the negative cases haven't run | Each PR's CI runs every check. §6.2 lists the cases for whoever runs Godot |
| Longer tests | GUT took 58.1 s on `main`, and 64.5–80.2 s with RG | The `test` job still takes about 2 minutes |
| A Godot upgrade changes the road stream | The digests fail on the upgrade | Intended: such an upgrade breaks old seeds (D8). Its PR records the new digests (§6.1) |

---

## 9. Notes for later work

- M6.5's device checklist (`IMPLEMENTATION_PLAN.md`:447) gains a line: "Side roads and decoys in each area but the City read as roads, and choosing between straight on and the turn feels fair."
- M6's PRs that change the areas' `.tres` keep PR 3's lines. A conflict there is between two independent additions: keep both.
- `plan.md` §3.4 still gives M1's buffer, 50, 25 and 5 tiles, and `test_road_buffer.gd`:38 is still called `test_lookahead_stays_between_25_and_50_fuzzed`. M5's L2 and R6 changed both values. A docs PR can fix them.
- R8: if play shows that "You missed the turn!" confuses at a decoy, give leaving the road there a cause of its own (Q5's alternative).
- Final art could end a dead end in something that reads as a road's end, such as a gate or a field, so that an end in view still looks like a road.
