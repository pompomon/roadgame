# Road Generation: Junction Kinds and Long Dead Ends

Done on 2026-11-12, a day after it opened: the plan in #54, then three stacked PRs, #55–#57, all four linked as GitHub's stack #59. RG, as the plan calls the work, added junctions that offer straight on and one turn: side roads, where the turn is right, and decoys, where straight on is right and the turn waits. It made dead ends 6–9 tiles so that they look like roads, grew the buffer to hold them, and gave every area but the City chances of the new kinds. Its **Δ** fixes (R1, R2, R4–R6) replace IP M1.4's junction and dead-end rules and M1.5's buffer values; `plan.md` took them, but not IP (Q7). The full plan, with its verification, negative cases and review history: `git show 08f316f:ROADGEN_PLAN.md`.

## 1. Goal and exit criteria

Before RG every junction was a turn, so a player who kept count never needed to look at a junction's shape. The owner asked for junctions with straight on and one turn, where either can be right (Q1), and for dead ends that look like proper roads (Q3). The player's rule became: take the pattern's next turn if the junction offers it, otherwise go straight on.

E1–E11, on the kinds, the chances, the digests, the dead ends, the buffer, the autopilot, the areas, the checks, the look on the Web and the Fold4 (E10), and the docs, were all met but E10's Fold4 part, which is not recorded (§7).

- **E5.** Dead ends are 6–9 tiles. One keeps the length it drew if nothing is in its way; one that a taken cell cuts short stops right before that cell, with at least 2 tiles. A straight-on one is never cut, and none is dropped. On the 7 reference screens, the end of one of 6 tiles or more is out of view as the car enters its junction on the centreline (`test_camera_rig.gd`).
- **E8.** The City has no side roads or decoys. Rural, Meadows, the Village and the Desert have both, and each keeps at least a quarter of its junctions as T's (`LEAST_T_SHARE` in `test_area_schedule.gd`).

## 2. Findings

- **R1.** Every junction was a T or a crossroads: `_junction()` always made the opposite turn a wrong exit. **Δ IP M1.4:** `RoadGenerator.Kind` is T, CROSSROADS, SIDE_ROAD or DECOY. A side road's one wrong exit is straight on. A decoy's correct exit is straight on, so the turn waits for the next junction, and its wrong exit is the opposite turn (§5.1).
- **R2.** Straight on was never correct: the generator, the trigger, turn numbers and the schedule took every junction for a turn. **Δ:** a decoy keeps the heading, `turn_count` and the schedule, and shares its `turn_number` with the next junction. `JunctionTrigger` adds to `turn_index` only where `RoadTile.is_turn()`, but emits `turn_completed` at every correct exit (§5.2).
- **R3.** `AreaDef` had only `cross_junction_chance`. It gains `side_road_chance` and `decoy_chance`, 0 by default; `validate()` checks that each chance is within 0..1 and that the three add up to no more than 1, with `is_equal_approx()`. `kind_for()` picks the kind from one `randf()`, the draw that M1 made for the crossroads, so an area without the new kinds keeps its road (§5.1).
- **R4.** Dead ends of 2–3 tiles looked like stubs, with their end in view as the car entered the junction, which gave a side road away. **Δ:** `DEAD_END_MIN_TILES` 6 and `DEAD_END_MAX_TILES` 9 (Q3, §5.3).
- **R5.** A dead end that met a taken cell became a 1-tile stub, or was dropped. **Δ:** `_free_run()` stops it right before the first taken cell. The path's shape leaves a straight-on dead end whole and any other at least 2 tiles, so every junction keeps a wrong exit (§5.3).
- **R6.** The buffer was sized for 3-tile dead ends. **Δ `docs/M5.md` L2, IP M1.5:** `BUFFER_REFILL_AT` 37, so that each row of props has its road and the check of `docs/M4.md` K1's spare tile still holds. `BUFFER_BEHIND` 20, so that a straight-on dead end freed with its junction stays below the tallest view at top speed: 45 px below, where 19 leaves 13 (§5.4).
- **R7.** Comments and `plan.md` that the new kinds and lengths made wrong, such as "junctions" where decoys make it turns. PRs 1 and 2 rewrote them (§5.7).
- **R8.** Off the road too long at a decoy, the run ends with "You missed the turn!", though there is no turn to miss. Kept (Q5).
- **R9.** Masks 11 and 13, a side road's, had never been seen in a run. E10 checked them on the Web.

## 3. Decisions

The owner answered Q1 and Q3, and confirmed the other defaults on 2026-11-12.

- **Q1.** Can straight on be correct? Yes, so there are decoys as well as side roads.
- **Q2.** Each area's chances: §5.5. None in the City, and every area keeps at least a quarter of T's.
- **Q3.** Dead ends: 6–9 tiles, the shortest whose end stays out of view as the car enters the junction (§5.3).
- **Q4.** `BUFFER_REFILL_AT` 37, not 36, whose 20-tile refill cycle fails K1's check (§5.4).
- **Q5.** The off-road limit at a decoy: "You missed the turn!", as anywhere (R8).
- **Q6.** The plan's PR, then three stacked PRs (§4).
- **Q7.** `plan.md` changes (§5.7); IP stays as M1–M6 left it.

## 4. Work breakdown

- **Plan PR** (#54).
- **PR 1** (#55): the junction kinds, `RoadTile.is_turn()`, the trigger's turn count and `AreaDef`'s chances (R1–R3, R7). No area used them yet, so the road stayed as it was.
- **PR 2** (#56): 6–9-tile dead ends, `_free_run()` and the buffer (R4–R7, Q3, Q4).
- **PR 3** (#57): the four areas' chances, the new digests and E8's test (Q2).

### 4.5 Landing the stack

Each PR was based on the one before (`docs/agents/stacks.md`). The PRs change the same lines in turn, so after PR k's squash merge, PR k+1 merged PR k's branch and then `main` with `-X ours`, as its side already held PR k's final state, and checked that its diff against `main` was still its own. GitHub's stack #59 rebased #55, dropping its merges; #56's commits couldn't be replayed, so it merged only `main`.

**Retarget before deleting a branch.** Deleting a merged PR's branch closes each open PR based on it, unless GitHub retargets that PR first. It didn't once, so deleting `m6/plan` closed #46, which could be reopened only by restoring the branch; and GitHub Mobile's "Delete branch" is reported to close such PRs. So once PR k merges, run `gh pr edit <k+1> --base main` before PR k's branch is deleted, or keep the branches until the whole stack has landed.

## 5. Design

### 5.1 Junction kinds (R1, R3)

A mask has the `Heading.bit()` of each edge with road, the entry's included: N 1, E 2, S 4, W 8. At heading N the turn is W; at heading W, N.

| Kind | Correct | Wrong, each with a dead end | Mask at N | Mask at W |
|---|---|---|---|---|
| T | The turn | The opposite turn | 14 | 7 |
| CROSSROADS | The turn | The opposite turn, straight on | 15 | 15 |
| SIDE_ROAD | The turn | Straight on | 13 | 11 |
| DECOY | Straight on | The opposite turn | 7 | 14 |

Only a crossroads' tile is a `CROSS_JUNCTION`; a decoy's mask is a T's at the other heading. `kind_for(roll, area)` is static and pure: the crossroads, side road and decoy chances take their parts of 0..1 in that order, with `<` at each bound, and T the rest. `_junction()` then draws one `randi_range(DEAD_END_MIN_TILES, DEAD_END_MAX_TILES)` per wrong exit, the opposite turn's first. So a side road draws what a T draws, keeping the path; a decoy doesn't turn, so the path after it changes (D8). A junction left with no wrong exit is a `push_error()`.

### 5.2 Decoys (R2)

`RoadTile.is_turn()` is `is_junction() and expected_exit != heading`. At a decoy, `_junction()` sets `expected_exit` to the heading, places the opposite turn's dead end and returns before turning, so the next junction expects the same turn. At its correct exit, `JunctionTrigger` emits `turn_completed`, so the chime plays and `CarSim` restarts `dist_on_straight`, as at a turn, but the HUD's count stays. `_junction_after()` still finds decoys, so their wrong exit is judged, and a car that rejoins past one counts only turns. Nothing but the exits tells the kinds apart: the car brakes before every junction, and straight on is offered at crossroads, side roads and decoys.

### 5.3 Dead ends (R4, R5)

`_free_run(from, exit, length)` counts the free cells up to the first taken one, and `_place_dead_end()` lays that many. Fewer than it drew counts in `shortened_count`; 0 drops the exit, in `dropped_count`. None is dropped, as the path moves only towards −x and −y. A straight-on dead end meets no earlier tile. An opposite-turn one can be cut only by an earlier junction's straight-on dead end. The nearest, two turns back, is at least 3 cells away (D7), which leaves it 2, and earlier ones are farther. Dead ends meet only those of junctions within 2 × `DEAD_END_MAX_TILES` = 18 path steps, all in the buffer.

At 6 tiles, an end is out of view on all 7 reference screens as the car enters the junction on the centreline; at 5, 1639×640 and 1137×640 show it. Ends still show from the leg before a short approach, and 1639×640 shows up to 4.5 px of a 6-tile end to a car steered 15–45° across the entry, which 7 tiles would hide. An end tells only that an exit is wrong, which the player's rule already does, so the length is for the look.

### 5.4 The buffer (R6, Q4)

`PropLayout.rows_needed()` grows from 6 to 12 with `DEAD_END_MAX_TILES`, so a row of props needs `PROP_AHEAD` + 12 = 36 tiles ahead, and `BUFFER_REFILL_AT` must be at least 36. K1's check in `test_area_schedule.gd` finds its 1 spare tile only if the schedule's junctions meet every point of the refill cycle, `BUFFER_AHEAD - BUFFER_REFILL_AT + 1` tiles: they meet 5 points of 20 at 36, and all 19 at 37, a prime. A freed junction's straight-on dead end reaches `DEAD_END_MAX_TILES` rows above it, so `BUFFER_BEHIND` grows a tile per row, from M5's 14 for 3 rows to 20 for 9. At `GLOBAL_SPEED_CAP` on 360×922 its end is then 45 px below the view; at 19, 13 px; at 18, in view. The lookahead is 37–55 tiles.

### 5.5 Area chances (Q2)

| Area | Straights | Crossroads | Side roads | Decoys | T's |
|---|---|---|---|---|---|
| City | 2–5 | 0.4 | 0 | 0 | 0.6 |
| Rural | 3–7 | 0.25 | 0.15 | 0.1 | 0.5 |
| Meadows | 3–7 | 0.3 | 0.2 | 0.15 | 0.35 |
| Village | 2–5 | 0.35 | 0.2 | 0.15 | 0.3 |
| Desert | 3–8 | 0.3 | 0.25 | 0.2 | 0.25 |

The City, where a run learns the pattern, has none. The chances grow along the run, and each is one line in the area's `.tres`, 0 where it's missing.

### 5.6 Tests and fixtures

`Fixtures.kinds_schedule(cross, side, decoy)` is one area with those chances, and `Fixtures.kind(junction)` reads a junction's kind from its exits. The kinds' tests and `test_autopilot_300_turns.gd`'s 300 turns run on such schedules.

### 5.7 Documents and comments (R7, Q7)

`plan.md` §2.1 (rules 3, 4 and 6), §2.4, §3.2, §3.3, §3.7, §4.1 and §11 have the kinds, the decoys and the dead ends: only a turn adds to `turnIndex`.

## 6. Verification

Each PR's head passed `AGENTS.md` §3's five checks, locally and in CI, and each negative case failed only the tests it names. With M6 merged, PR 3 had 142 scripts, 473 tests and 422,730 asserts, and the smoke line `autopilot: tile 165, turns 35, area rural`. E10's Web part passed in Chrome and Firefox (#57).

### 6.1 Checks and counts

`test_road_generator_determinism.gd` holds MD5 digests of the game's road for seeds 0–19 up to turn 300: `PATH_DIGEST`, of its path tiles, and `ROAD_DIGEST`, with their dead ends. PR 2 changed `ROAD_DIGEST`, and PR 3 both. To record new ones, set them to `""` and run the tests, whose failures give the new values; the commit says why (E4). A Godot upgrade that changes the road stream fails them too, as D8 allows.

### 6.2 Negative cases

- **N7.** Straight-on dead ends of 1 tile fail 6 tests, the digests and 4 of `test_road_generator_occupancy.gd`'s among them. At first N7 and N8 ran out of memory: `_check()` failed the test about three times at each junction, GUT kept each failure's text, and Godot grew to 6.2 GB. Now `_check()`, like `test_road_generator_tutorial.gd`'s `_check_tutorial()`, stops at the first failing junction and checks nothing once the test fails.

## 7. Owner actions

- E10 on the Fold4, not recorded as done: on both screens, side roads and decoys read as roads, masks 11 and 13 look right, dead ends don't look like stubs, and the trick feels fair. A debug build's title Start button picks the area that Play starts in (`docs/ZONE_SELECT.md`).

## 9. Notes for later

- IP's M7.5 device checklist gains: "Side roads and decoys in each area but the City read as roads, and choosing between straight on and the turn feels fair."
- R8: if "You missed the turn!" confuses at a decoy, give leaving the road there its own cause, in `CarSim` and `ui/game_over.gd`.
- Art could end a dead end in a gate or a field, so that an end in view still reads as a road's (`tools/art/make_art.gd`).
