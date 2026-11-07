# M1 Generator — Detailed Plan

Status: approved, with the Q1–Q13 defaults; implemented in #20–#23, with the review fixes in §4.6 · 2026-11-07 · Scope: `IMPLEMENTATION_PLAN.md` (below: **IP**) §3 M1 row, §4 M1.1–M1.6 and "M1 tests", the M1 rows of §6, and the parts of M4.1 and M4.2 that M1 needs (G5)

**Verified, not just reviewed.** Every file this plan adds or changes exists on branch `m1/prototype` (c9ca9eb) and was run with the tools below. Each PR state in §4 was rebuilt from that branch on top of #18 and passed the five local checks (§6.1). The 23 negative cases in §6.2 were run too. The changes in §4.6, mostly review fixes, touch six files in the PRs; negative cases N24–N28 show that their new tests catch what they guard.

- Godot 4.7.2-stable (Linux x86_64)
- GUT 9.7.1
- gdtoolkit 4.5.0 on Python 3.12
- shellcheck 0.11.0
- actionlint 1.7.12

Some things could not be run locally: GitHub CI, browsers and the Galaxy Z Fold4. They are checked in the PRs (E9, §6.4), with the results so far in §6.6.

**Precedence.** For M1, this document replaces IP §4 M1 wherever they differ. Each difference is marked **Δ** with its finding number (G#, §2). The M1 rows of IP §6 still hold; §5.11 lists every test. Once this plan is approved, fold the changes back into IP (Q8).

**Reference code (Q13).** This plan has no appendices: each PR checks its files out of `m1/prototype` (§4.1). Don't open a PR from that branch, and don't start a CI run on it. Its `ci.yml` predates F34 (#18), so a run would save caches and keep artifacts for 14 days. Pushes to it start nothing, because `ci.yml` runs only for pull requests, pushes to `main` and manual runs.

**Prerequisites.** #18 (F34) is merged, and `lint` is a required check (§7).

Contents:
1. Goal and exit criteria
2. Review findings
3. Decisions and open questions
4. Work breakdown (4 PRs)
5. Design
6. Verification
7. Owner actions
8. M1 risks
9. Notes for later milestones

---

## 1. Goal and exit criteria

Goal (IP §3): `RoadGenerator` meets every unit invariant in `plan.md` §11, and the grey-box road is visible and scrollable. **Δ G4:** the road viewer is the main scene until M2, so Pages and the debug APK show it.

| # | Exit criterion | Checked by |
|---|---|---|
| E1 | The same seed gives identical tiles, dead ends included, for 2,000 path tiles. Buffer refills and frees don't change the road. Seeds 1 and 2 give different roads | `test_road_generator_determinism.gd` |
| E2 | The path starts north with 4 straight tiles and is a connected N/W staircase. Expected exits alternate L, R, L… starting with L. Each junction has its expected exit plus 1–2 wrong exits, and its type (T or crossroads) matches. Straights stay within the area's min/max | `test_road_generator_pattern.gd`, `test_heading.gd` |
| E3 | Over 200 seeds × 500 turns: one tile per cell, at least one wrong exit per junction, dead ends of 1–3 tiles that end in a cap, and no wrong exit dropped | `test_road_generator_occupancy.gd` |
| E4 | Under fuzzed car moves, lookahead stays in 25..50 and at most 5 path tiles stay behind the car. Freeing a junction also frees its dead ends and their cells. Dropping the buffer frees every tile, and Godot reports no leak at exit | `test_road_buffer.gd`; `run_tests.sh` (G1) |
| E5 | Areas switch at turns 34 (tunnel, then rural), 100 (bridge, then meadows), 200 (village) and 220 (desert). Set-piece tiles keep the old area, and the straight after a switch comes from the new area. Desert is still active at turn 1,000. A broken schedule is reported, and the generator then uses one default area instead | `test_area_schedule.gd` |
| E6 | The `is_on_road` capsule cases hold for every tile type, and the grey-box atlas pixels follow the same geometry | `test_road_geometry.gd`, `test_greybox_atlas.gd` |
| E7 | The renderer draws exactly the buffer's tiles, and its layers line up with tile space | `test_world_renderer.gd`, `test_iso.gd` |
| E8 | The smoke run (seed 12345) drives the viewer along the road and prints no error lines. Locally it prints `autopilot: tile 1440, turns 247, area desert` | `smoke.sh`: an `autopilot: tile N` line with N ≥ 1, and no error lines. PR 4 compares the full line by hand (§4) |
| E9 | Manual: the Web build in Chrome and Firefox and the debug APK on the Galaxy Z Fold4 show the road. Touch and hold fast-forwards. The tilesets build in under 300 ms | PR 4 (Q3) |
| E10 | All five required checks are green. `lint` picks up the new folders without changes (M0 F8), and its determinism rule covers `road/`, `world/` and `areas/` | PR checks |

---

## 2. Review findings

IP's M1 design holds up. The N/W staircase, the alternating turns and the dead-end placement work as described, and IP's proof sketch is right (§5.4). The problems are a leak that CI reports as green, a half-tile drawing offset, and dependencies on later milestones.

- **High:** IP's design gives a broken result that its own tests don't catch.
- **Medium:** fragile, or depends on a later milestone.
- **Low:** clarity, dead code or polish.

"Prototype" means the problem was reproduced with Godot 4.7.2 on `m1/prototype`.

### High

| # | Finding | Evidence | Fix |
|---|---|---|---|
| G1 | IP M1.2 gives dead-end tiles a `junction: RoadTile` field, marked "(weak ref)". A typed GDScript field is a strong reference, and the junction's `branches` array points back, so every junction and its dead ends form a `RefCounted` cycle that is never freed. GUT still exits 0. | Prototype, N3: with the field, the WeakRef test fails. Without that test, the other 46 pass and Godot prints "614892 ObjectDB instances were leaked at exit" | **Δ IP M1.2:** `junction_index: int`, the junction's `path_index`; look the junction up with `RoadBuffer.path_tile()`. `test_dropping_the_buffer_frees_every_tile` checks with `WeakRef` that no tile survives. `run_tests.sh` fails on Godot's leak report (N23). A `WeakRef` field would also work, but every read needs `get_ref()` and a cast |
| G2 | `TileMapLayer`'s DIAMOND_DOWN layout puts the centre of cell (0, 0) at (64, 32), but IP's `tile_to_world((0.5, 0.5))` is (0, 32). The road would be drawn half a tile to the right of where the car drives. | Prototype; N4 | `Iso.layer_offset()` moves each layer so that its cell centres land on `tile_to_world()`: (−64, 0) for the road layer and (−16, 0) for the ground layer. `test_iso.gd` and `test_world_renderer.gd` check it |

### Medium

| # | Finding | Evidence | Fix |
|---|---|---|---|
| G3 | IP M1.3 makes a double claim an `assert`. Release builds strip `assert`. In a debug run it prints `SCRIPT ERROR: Assertion failed` and abandons the calling function, and Godot still exits 0. | Prototype: the function returned 0 instead of 7 | **Δ IP M1.3:** `claim(tile) -> bool` calls `push_error`, returns false and keeps the old tile. `release(tile)` frees the cell only if `tile` holds it. The test uses `assert_push_error` |
| G4 | IP M1.6's acceptance scene, `tools/debug_road.tscn`, is never exported (`tools/*` is excluded, M0 F13) and never smoke-tested. Nothing would run it outside the editor, and Pages would keep showing M0's label. | `export_presets.cfg` `exclude_filter` | **Δ IP M1.6:** the road viewer is `ui/main.tscn` until M2 (Q1), so Pages, the APK and `smoke.sh` all run it |
| G5 | M1 needs `AreaDef` and `AreaSchedule`, which IP plans for M4.1 and M4.2. IP's `AreaScheduleEntry.set_piece: PackedScene` can't exist before the set-piece scenes of M4.4. | IP M4.1, M4.4 | **Δ IP M4.1, M4.2:** PR 1 brings the subset M1 uses (§5.6), with `set_piece: StringName`, plus the five areas and `schedule.tres` with IP M4.2's values. **Δ IP §2:** `AreaScheduleEntry` gets its own file, because a resource saved in a `.tres` needs its own script |
| G6 | IP M1.5 emits `EventBus.tiles_generated` and `tiles_freed`, but `EventBus` arrives in M2.7. | IP M2.7 | **Δ IP M1.5:** `RoadBuffer` has its own signals with those names; M2.7 can relay them (Q6) |
| G7 | IP M1.4 has the generator place props (`rng_props`, `tile.decor`, `PropDef.min_distance_from_road`), and IP M1.6 has the renderer ask `PropPool` for them. `PropDef` arrives in M4.1 and `PropPool` in M5.2, and there is no prop art yet. | IP M4.1, M5.2 | **Δ IP M1.4, M1.6:** no props in M1 (Q2). The props stream will be seeded with `hash("%d:props" % run_seed)`, separate from the road stream, so adding it can't change any road. The determinism test's "changing prop density does not change the road" moves to M4. `world.tscn` already has the `Props` node |
| G8 | IP M1.6's hand-drawn `assets/greybox/road.png` can drift from the D4 capsules that decide off-road, so the road on screen would not be the road the car is judged on. | — | **Δ IP M1.6:** `GreyboxAtlas` draws the atlas at startup from `RoadGeometry`, and a test compares its pixels with the geometry. Building it takes 59–65 ms locally; E9 measures it on devices (Q3) |

### Low

| # | Finding | Fix |
|---|---|---|
| G9 | IP M1.4's fallback loop (`if placed == 0`) and its "none equals the next correct cell" check can never trigger (§5.4). | Left out. `push_error` and the `shortened_count` and `dropped_count` counters stay, and the tests require `dropped_count == 0` |
| G10 | Grey-box diamonds show hairline seams at camera zoom 0.5. | `BLEED_PX = 1.0`: each diamond also covers the pixels within 1 px of its edge (N12) |
| G11 | IP M1.4 starts with `straight_left == 0`, so path tile 0, where the car starts, would be a junction. | Start with `START_STRAIGHT_TILES = 4` straight tiles (Q4) |
| G12 | The generator never emits `CORNER`: every turn is a junction. | Keep the enum value; M5.1 needs no corner art |
| G13 | IP M1.4's `_init(seed: int, …)` makes the editor warn SHADOWED_GLOBAL_IDENTIFIER: 'The function parameter "seed" has the same name as a built-in function.' CI stays green, because only the editor reports it. | Name it `run_seed`. M2.7's `start_run(seed := -1)` needs the same |
| G14 | IP doesn't say exactly when a schedule entry for turn T applies. | Defined in §5.6 |
| G15 | IP M1.5 doesn't define lookahead. | Lookahead = the last generated path index − the car's path index. The buffer holds at most 56 path tiles (§5.5) |
| G16 | Screenshots under xvfb (M6.6): without `--audio-driver Dummy`, Godot prints `ERROR: Condition "status < 0" is true. Returning: ERR_CANT_OPEN` and still exits 0. A script that jumps along the path skips the junctions the viewer counts. | §6.3 |
| G17 | `smoke.sh` now depends on the `autopilot:` line that `ui/main.gd` prints. | M2 keeps the line, or updates `smoke.sh` in the same PR (§9) |

---

## 3. Decisions and open questions

This plan applies the defaults below. Tell me if you want any of them changed.

| # | Question | Default (applied) | Alternative |
|---|---|---|---|
| Q1 | Where does the road viewer live? | `ui/main.tscn`, until M2 replaces it with the game (G4) | IP's `tools/debug_road.tscn`, which runs only in the editor |
| Q2 | Props in M1? | No: they need `PropDef` (M4.1) and `PropPool` (M5.2) (G7) | Placeholder props now |
| Q3 | Grey-box art | Drawn at startup from `RoadGeometry` (G8). If a device takes more than 300 ms (E9), PR 4 switches to a baked PNG before it merges: a tools script writes it from `GreyboxAtlas`, and a test checks that they match | IP's hand-drawn PNG |
| Q4 | How does the road start? | 4 straight tiles north, then the first junction (G11) | 2 tiles (the shortest straight), or a junction first as in IP |
| Q5 | Bring the area subset into M1? | Yes: `AreaDef`, `AreaSchedule`, the five areas and `schedule.tres` (G5) | A test-only schedule built in code; the resources stay in M4 |
| Q6 | Buffer signals | The buffer's own; M2.7's `EventBus` relays them (G6) | Add a minimal `EventBus` autoload now |
| Q7 | M0_PLAN.md appendices | Freeze them as M0's final state; PR 1 adds the note below | Keep them in sync: M1 changes 5 of their files |
| Q8 | Fold this plan into IP? | After review. Until then, this document wins for M1 | — |
| Q9 | Test sizes | Keep them: they add about 7 s to GUT (8–11 s in CI, §6.6) | Shrink the 200 × 500 test if the CI `test` job regularly takes more than 100 s (M0: 51–76 s) |
| Q10 | Dead-end tint | On in the M1 viewer, off in runs (`show_dead_ends`) | Off, or only in debug builds |
| Q11 | Leak guard | In PR 1, in `run_tests.sh` | Only the WeakRef test (PR 3) |
| Q12 | How do the 4 PRs land? | Stacked branches, each retargeted to `main` in turn (§4.5) | One PR at a time, each opened after the previous one merges |
| Q13 | Appendices with every file, as in M0? | No: `m1/prototype` is the reference, and PRs check files out of it | Copy the files into this plan |

**Q7 note.** PR 1 adds this note at the start of M0_PLAN.md Appendix A:

> Appendices A and B show the files as M0 left them. Later milestones change some of them (M1: `tools/ci/run_tests.sh`, `tools/ci/smoke.sh`, `ui/main.gd`, `ui/main.tscn`, `tests/unit/test_smoke.gd`); the repository has the current versions.

This ends the current convention, under which every change to such a file also updates its appendix copy. With the alternative, PR 1 updates the `run_tests.sh` copy and PR 4 the other four.

---

## 4. Work breakdown

There are four PRs, and each one leaves CI green. The total estimate is about 3–3.5 days, plus half a day if the atlas has to be baked (Q3). That is below IP's size "L" (4–6 days), because the code exists and is verified. Most of the remaining risk is in PR 4, because device performance can't be tested locally.

```
PR 1 road types, areas, Iso ──▶ PR 2 generator ──▶ PR 3 buffer ──▶ PR 4 grey box + viewer
 (M1.1–M1.3, G1, G3, G5)         (M1.4)             (M1.5)          (M1.6)
 ~1 d                            ~1 d               ~0.5 d          ~0.5–1 d
```

### 4.1 Porting from the prototype

Every PR follows the same steps:

1. Fetch the branches and create the PR's branch. The refspec also works in a clone that tracks only `main`:
   ```bash
   git fetch origin main '+refs/heads/m1/*:refs/remotes/origin/m1/*'
   git switch -c m1/1-road-types origin/main    # PRs 2–4: from the previous PR's branch (§4.5)
   ```
2. Check the PR's files out of the prototype with the command in its section. The globs are quoted so the `.uid` files come along.
3. Make the PR's trims, if any, then run `gdformat` on each trimmed file: a cut can leave an extra blank line.
4. Run `tools/ci/import.sh`. It must create no files: `git status --porcelain` lists only the checked-out paths.
5. Run §6.1 and compare the counts with the PR's "Expect" line.
6. Commit, push and open the PR.

### PR 1: Road types, areas and `Iso` (M1.1–M1.3; parts of M1.6, M4.1, M4.2) **Δ G1, G3, G5**

Branch `m1/1-road-types`, from `main`.

| Area | Files |
|---|---|
| Tuning | `config/tuning.gd` (§5.10) |
| Road types | `road/heading.gd`, `road/road_tile.gd`, `road/road_geometry.gd`, `road/occupancy_grid.gd` |
| Areas | `areas/area_def.gd`, `areas/area_schedule.gd`, `areas/area_schedule_entry.gd`; `city`, `rural`, `meadows`, `village`, `desert` and `schedule` `.tres` |
| World | `world/iso.gd` |
| Tests | `tests/helpers/road_fixtures.gd`; `tests/unit/test_heading.gd`, `test_road_geometry.gd`, `test_occupancy_grid.gd`, `test_iso.gd`, `test_area_schedule.gd` |
| CI | `tools/ci/run_tests.sh`: the leak guard (G1) |
| Docs | `M0_PLAN.md`: the Q7 note |

Every `.gd` file comes with its `.gd.uid`.

```bash
git checkout origin/m1/prototype -- config/ areas/ tests/helpers/ tools/ci/run_tests.sh \
  'road/heading.gd*' 'road/road_tile.gd*' 'road/road_geometry.gd*' 'road/occupancy_grid.gd*' \
  'world/iso.gd*' 'tests/unit/test_heading.gd*' 'tests/unit/test_road_geometry.gd*' \
  'tests/unit/test_occupancy_grid.gd*' 'tests/unit/test_iso.gd*' 'tests/unit/test_area_schedule.gd*'
```

Trims, because these parts need `RoadGenerator` (PR 2):
- `tests/helpers/road_fixtures.gd`: delete `path_until_turn()`.
- `tests/unit/test_area_schedule.gd`: keep `_area()`, `_entry()`, `_problems()` and the first two tests. Delete everything from `test_a_broken_schedule_is_reported_by_the_generator` on, including `_check_switch()`.

Expect: `check_scripts: loaded 19 scripts`; `GUT: 19 tests passed` (116 asserts, 0.4 s). Negative cases N15 and N23.

**Acceptance:** E6 (geometry part) and E10; the leak guard (N23) and the schedule validation work.

### PR 2: Generator (M1.4) **Δ G7, G9, G11, G13, G14**

Branch `m1/2-generator`, from `m1/1-road-types`.

**Files:** `road/road_generator.gd`; `tests/unit/test_road_generator_pattern.gd`, `test_road_generator_occupancy.gd`, `test_road_generator_determinism.gd`; the complete `tests/helpers/road_fixtures.gd` and `tests/unit/test_area_schedule.gd`.

```bash
git checkout origin/m1/prototype -- tests/helpers/road_fixtures.gd tests/unit/test_area_schedule.gd \
  'road/road_generator.gd*' 'tests/unit/test_road_generator_pattern.gd*' \
  'tests/unit/test_road_generator_occupancy.gd*' 'tests/unit/test_road_generator_determinism.gd*'
```

Trim: in `test_road_generator_determinism.gd`, delete `test_buffer_refills_and_frees_do_not_change_the_road`, which needs `RoadBuffer` (PR 3).

Expect: 23 scripts; `GUT: 33 tests passed` (143,055 asserts, about 7 s). Negative cases N1, N2, N6–N8, N13, N14, N16, N17, N20 and N22.

**Acceptance:** E1 without the buffer part, E2, E3 and E5. Compare the CI `test` job time with M0's 51–76 s (Q9).

### PR 3: Buffer (M1.5) **Δ G6, G15**

Branch `m1/3-buffer`, from `m1/2-generator`.

```bash
git checkout origin/m1/prototype -- tests/unit/test_road_generator_determinism.gd \
  'road/road_buffer.gd*' 'tests/unit/test_road_buffer.gd*'
```

No trims. Expect: 25 scripts; `GUT: 39 tests passed` (143,374 asserts). Negative cases N3, N5, N10, N11 and N18.

**Acceptance:** E1 and E4.

### PR 4: Grey box and road viewer (M1.6) **Δ G2, G4, G8, G10**

Branch `m1/4-greybox`, from `m1/3-buffer`.

| Area | Files |
|---|---|
| World | `world/greybox_atlas.gd`, `world/world_renderer.gd`, `world/world.tscn` |
| Viewer | `ui/main.gd`, `ui/main.tscn` |
| Tests | `tests/unit/test_greybox_atlas.gd`, `test_world_renderer.gd`; `test_smoke.gd` (the root is now a `Node`) |
| CI | `tools/ci/smoke.sh`: require the `autopilot:` line (G17) |

```bash
git checkout origin/m1/prototype -- 'world/greybox_atlas.gd*' 'world/world_renderer.gd*' \
  world/world.tscn ui/main.gd ui/main.tscn 'tests/unit/test_greybox_atlas.gd*' \
  'tests/unit/test_world_renderer.gd*' tests/unit/test_smoke.gd tools/ci/smoke.sh
```

1. No trims. Expect: 29 scripts; `GUT: 47 tests passed` (143,448 asserts). `smoke.sh` prints `grey box: tilesets built in … ms` and `autopilot: tile 1440, turns 247, area desert`. Negative cases N4, N9, N12, N19 and N21.
2. Check that the stack now matches the prototype. The command prints nothing, unless a review changed something on purpose. After the review fixes, it lists the six files changed in §4.6:
   ```bash
   git diff --stat origin/m1/prototype -- . ':!.github' ':!IMPLEMENTATION_PLAN.md' ':!M0_PLAN.md' \
     ':!M1_PLAN.md' ':!tools/ci/check_actions_storage.sh' ':!tools/ci/lint.sh'
   ```
3. Manual checks (E9). Start a run that uploads the builds, and download them within a day (F34). `gh run download` puts each artifact in a folder named after it: `web`, `android-Android APK` and `android-Android AAB`.
   ```bash
   gh workflow run ci.yml --ref m1/4-greybox -f upload-builds=true
   gh run list -w ci.yml -b m1/4-greybox -e workflow_dispatch -L 1    # the run id
   gh run watch <run id> --exit-status
   gh run download <run id> -D /tmp/roadgame-builds
   ```
   - **Android:** `adb install -r "/tmp/roadgame-builds/android-Android APK/roadgame-debug.apk"`. The road scrolls up the screen, and touch and hold fast-forwards. `adb logcat -s godot` shows the `grey box:` line.
   - **Web:** run `python3 -m http.server -d /tmp/roadgame-builds/web 8000` and open http://localhost:8000 in Chrome and Firefox. The browser console shows the `grey box:` line.
   - If a device takes more than 300 ms, don't merge PR 4 yet. Add the Q3 fallback to it (about half a day) and repeat these checks.
4. After the merge, https://pompomon.github.io/roadgame/ shows the road viewer.

**Acceptance:** E6–E9.

### 4.5 Landing the stack (Q12)

This procedure was checked by simulating squash merges in a scratch clone.

1. Each PR branches from the previous PR's branch, and its PR targets that branch, so its diff shows only its own files. `ci.yml` runs on every `pull_request` with no branch filter, so every PR gets the five checks. Required checks only gate PRs into `main`.
2. A review fix for PR n is committed on PR n's branch and then merged (`git merge`) into each later branch. No rebases and no force-pushes.
3. Merge only a PR whose base is `main`. A merge into another PR's branch skips the required checks; in M0, that is why #16 was needed.
4. After PR n squash-merges, update PR n+1:
   ```bash
   git fetch origin main '+refs/heads/m1/*:refs/remotes/origin/m1/*'
   git switch <PR n+1 branch>
   git merge origin/<PR n branch>     # PR n's final state, in case a fix wasn't merged up yet
   git merge -X ours origin/main      # the squash commit
   git diff --name-only origin/main   # must list only PR n+1's files
   git push
   gh pr edit <PR n+1> --base main
   ```
   Because of the trims, a plain `git merge origin/main` stops with add/add conflicts in `road_fixtures.gd` and `test_area_schedule.gd`. `-X ours` resolves them to this branch's version, which is the complete file. But `-X ours` would also silently drop a review fix that PR n got and this branch never merged. The first merge prevents that, and the `diff` check shows it: a file from PR n appears in the list.
5. Ruleset "Copilot" blocks branch deletion, so GitHub can't retarget PR n+1 by itself when PR n merges (§7).

### 4.6 Review fixes

These changes came from Copilot's reviews, the E9 Web check and a read-through of PR 4 before it was opened. Each one was committed on the branch of the PR that owns the code, then merged into the later branches (§4.5).

| PR | Change | Tests | Negative case |
|---|---|---|---|
| #20, PR 1 | `AreaSchedule.validate()` reports a missing (null) entry before it reads any entry, and a negative `set_piece_length` (§5.6) | 3 more asserts in `test_validate_reports_broken_schedules` | N24 |
| #21, PR 2 | `RoadGenerator._init` reports a missing or broken schedule, then generates from one default area instead (§5.3) | `test_the_generator_replaces_a_broken_schedule_with_one_default_area` | N25 |
| #22, PR 3 | Tests only: `centreline_point()` clamps at the buffer's ends, and reports an error before `start()` (§5.5) | `test_centreline_clamps_to_the_buffer_ends`, `test_centreline_before_start_is_an_error` | N26 |
| #23, PR 4 | The viewer tracks touches by index and the mouse button separately, so fast-forward lasts while any of them is held (§5.8) | `test_fast_forward_lasts_while_any_touch_or_the_mouse_button_is_held` | N27 |
| #23, PR 4 | Found in E9: Godot's default font has no "↑", and the Web build has no system font to fall back on, so the hint showed a box. The hint now spells it out (§5.8) | `test_main_scene_text_has_every_glyph_in_the_default_font` | N28 |
| #23, PR 4 | The comment above the `autopilot:` print says what `smoke.sh` enforces (§5.9) | — | — |

The "Expect" lines in PR 1–PR 4 give the counts right after the checkout. With the fixes, the PRs have 19, 34, 42 and 52 tests (§6.1).

---

## 5. Design

The code on `m1/prototype` is the reference. This section summarizes it and lists what differs from IP, and why.

### 5.1 Files

| File | Class | PR | IP |
|---|---|---|---|
| `config/tuning.gd` | `Tuning` | 1 | M1.5, D4 |
| `road/heading.gd` | `Heading` | 1 | M1.1, plus `NAMES`, `ALL`, `bit()` and `from_vec()` |
| `road/road_tile.gd` | `RoadTile` | 1 | M1.2 **Δ G1** |
| `road/road_geometry.gd` | `RoadGeometry` | 1 | M1.1, plus `is_on_road_exits()` and `distance_to_centreline()` |
| `road/occupancy_grid.gd` | `OccupancyGrid` | 1 | M1.3 **Δ G3** |
| `areas/area_def.gd`, `area_schedule.gd`, `area_schedule_entry.gd`, `*.tres` | `AreaDef`, `AreaSchedule`, `AreaScheduleEntry` | 1 | M4.1, M4.2 **Δ G5** |
| `world/iso.gd` | `Iso` | 1 | M1.6 **Δ G2** |
| `tests/helpers/road_fixtures.gd` | (preloaded; `tests/` is not exported) | 1 | — |
| `road/road_generator.gd` | `RoadGenerator` | 2 | M1.4 |
| `road/road_buffer.gd` | `RoadBuffer` | 3 | M1.5 **Δ G6** |
| `world/greybox_atlas.gd` | `GreyboxAtlas` | 4 | M1.6 **Δ G8** |
| `world/world_renderer.gd`, `world/world.tscn` | `WorldRenderer` | 4 | M1.6 |
| `ui/main.gd`, `ui/main.tscn` | (the viewer) | 4 | **Δ G4** |

All of them are in IP §2's layout, except `area_schedule_entry.gd` (G5).

### 5.2 Road types (PR 1)

**`Heading`** (static): `enum { N, E, S, W }`; `VEC` (N is −y, W is −x); `NAMES`; `ALL = 0b1111`; `left(h)`, `right(h)`, `opposite(h)`; `turn_for(turn_number, h)`, which turns left on even turns; `bit(h) = 1 << h`; `from_vec(step)`, which returns −1 for anything but the four unit steps.

**`RoadTile`** (`RefCounted`):
- `enum Type { STRAIGHT, CORNER, T_JUNCTION, CROSS_JUNCTION, DEAD_END, SET_PIECE }`.
- The fields of IP M1.2, with "unset" defaults: `path_index = -1` (dead ends), `area_id = &""`, `turn_number = -1`, `expected_exit = -1`, `branch_exit = -1`, `branches = []`, `set_piece = &""`.
- **Δ G1:** `junction_index: int = -1` replaces `junction: RoadTile`. A tile holds strong references only to its own dead ends (`branches`), so no cycle can form.
- `_init(cell, type, heading, exits)`, `is_junction()`, `has_exit(h)`.

**`OccupancyGrid`** (`RefCounted`): a `Dictionary[Vector2i, RoadTile]` with `is_free(cell)`, `get_tile(cell)` and `size()`. **Δ G3:** `claim(tile) -> bool` and `release(tile)` instead of IP's `claim(cell, tile)` and `release(cell)`:
- Claiming a taken cell calls `push_error("OccupancyGrid: cell %s is already taken")`, returns false and keeps the old tile.
- `release(tile)` frees the cell only if `tile` holds it.

**`RoadGeometry`** (static, D4): `CENTRE` and `EDGE_MID`. A point is on the road when it is within `ROAD_HALF_WIDTH` of a segment from the centre to an exit's edge midpoint.
- `is_on_road(tile, local)`: false for a null tile.
- `is_on_road_exits(exits, local)`.
- `distance_to_centreline(exits, local)`: `INF` for no exits. The atlas uses it (G8).

### 5.3 Generator (PR 2)

```gdscript
func _init(run_seed: int, schedule: AreaSchedule) -> void   # Δ G13: not "seed"
func next_tile() -> RoadTile   # the next correct-path tile; a junction comes with its dead ends
var occupancy: OccupancyGrid
var current_area: AreaDef
var turn_count: int            # junctions so far, which is also the next junction's turn_number
var shortened_count: int       # dead ends shortened to 1 tile
var dropped_count: int         # wrong exits dropped; always 0 (§5.4)
```

- `_init` reports a missing schedule, or each `schedule.validate()` problem, with `push_error("AreaSchedule: " + problem)`. It then generates from a one-area schedule instead: an `AreaDef` with id `fallback` and the default rules. A broken schedule is never read, so the buffer and the viewer need no null checks (§4.6).
- `_init` starts in `entries[0].area` and seeds the road stream with `hash("%d:road" % run_seed)` (D8; G7 reserves `":props"`).
- `next_tile()` emits, in this order of priority:
  1. a set-piece tile while a set piece is pending; after the last one, the generator enters the pending area;
  2. a straight while the current straight has tiles left (the first straight has 4, G11);
  3. otherwise a junction.

  Each tile is claimed in `occupancy` before it is returned.
- A junction:
  1. Starts as type `T_JUNCTION` with two exits: back, and `expected = Heading.turn_for(turn_count, heading)`. It records `turn_number` and `expected_exit`.
  2. Its wrong exits are the opposite turn, plus straight on if `randf() < current_area.cross_junction_chance`.
  3. Each wrong exit gets a dead end of `randi_range(2, 3)` tiles. If a cell is taken, it tries 1 tile (`shortened_count`), else drops that exit (`dropped_count`). With no wrong exit left, it calls `push_error`.
  4. Its type becomes `CROSS_JUNCTION` if all four exits are open.
  5. Then `heading = expected` and `turn_count += 1`, and the schedule is checked (§5.6). If no entry is due, the next straight's length is sampled. If an entry with a set piece is due, the set piece becomes pending. Otherwise, the generator enters the new area and samples the straight from it.
- Dead-end tiles have type `DEAD_END`, `heading` = the wrong exit, and exits back toward the junction plus forward, except the last tile (the cap). They carry the junction's `area_id`, its `junction_index` and their `branch_exit`. The junction's exit opens only if its dead end is placed.
- **RNG order** per junction: `randf()` for the crossroads, one `randi_range()` per wrong exit (the opposite turn first), then the next straight's length. If a set piece follows, that length is sampled when the set piece ends. Any change to this order changes the road of every seed, so seeds in old bug reports no longer reproduce (D8).

### 5.4 Why dead ends never block the path

IP M1.4's proof sketch holds. Here it is in full, because it is why G9's fallback can go.

- The path heads N, then turns L, R, L…, so it alternates between W and N and only ever moves towards −x and −y. Every straight has at least 2 tiles (D7).
- Take a junction J at (x, y) entered heading N. Its expected exit is W, and its wrong exits are E and, at a crossroads, N (straight on).
  - Every earlier path cell lies below row y (y′ > y). Every later path cell lies left of column x (x′ < x).
  - The E dead end runs along row y to the right of J, and the N dead end up column x above J. Neither can touch a path cell, past or future.
  - A junction entered heading W is the mirror image, with x and y swapped.
- So a dead end can only meet another dead end. Only the straight-on dead end of the junction two turns earlier, J₂, can reach row y on J's right. J₂ is at column x + 3 or further right, so the cells (x + 1, y) and (x + 2, y) are always free, and a 1-tile stub always fits. The straight-on stub (x, y − 1) is free too, because no earlier tile reaches above row y in column x. Nothing is ever dropped, and no crossroads loses an exit.
- The one collision: J's 3-tile E dead end meets J₂'s 3-tile N dead end at (x + 3, y). This happens when both straights between J₂ and J have 2 tiles. J's dead end, placed later, is shortened to 1 tile.

Measured over 200 seeds × 500 turns with the game schedule: 62 of 130,320 dead ends were shortened (0.048%) and none were dropped. With the densest rules the schedule allows (straights of 2, every junction a crossroads, 50 seeds): 6,169 of 50,000 (12.3%) were shortened, and none were dropped.

### 5.5 Buffer (PR 3)

`RoadBuffer` (`RefCounted`) owns a `RoadGenerator` (`generator`) and the window of correct-path tiles around the car.

- **Δ G6:** signals `tiles_generated(tiles: Array[RoadTile])`, which lists each new path tile followed by its dead ends, and `tiles_freed(tiles)`, in the same order, emitted after their cells are released.
- `start()` generates path indices 0 to 50.
- `on_car_path_index(i)`:
  - ignores any `i` at or below the current car index, so a car that rejoins behind changes nothing;
  - if lookahead is below 25, generates up to `i + 50`;
  - frees every path tile with `path_index < i − 5`, together with its dead ends.
- Queries:
  - `car_index()`, `lookahead()`, `first_index()`, `last_index()`;
  - `path_tile(i)`, null outside the buffer;
  - `tile_at(cell)`, through the occupancy grid, so it also finds dead ends;
  - `tiles()`, in `tiles_generated` order;
  - `centreline_point(distance)`: a point on the path's centreline, in tile space, interpolated between tile centres. A distance outside the buffer is clamped to the first or last buffered tile centre, without an error. It reports `push_error("RoadBuffer: no centreline at distance %.2f")` only while the buffer holds fewer than two path tiles, that is, before `start()`.
- **Δ G15:** lookahead = `last_index() − car_index()`. The buffer holds at most 56 path tiles: 50 ahead, the car's tile and 5 behind.
- M2's car calls `on_car_path_index()` when it enters a path tile. The junction trigger finds a dead end's junction with `path_tile(tile.junction_index)` (G1).

### 5.6 Areas and the schedule (PR 1; used from PR 2)

**Δ G5:** this is only the subset that M1 uses. M2.2 adds the driving fields that `CarSim` reads, and M4.1 the rest of `plan.md` §3.7, to the same classes (§9).

| Class | Fields | `validate() -> PackedStringArray` reports |
|---|---|---|
| `AreaDef` | `id: StringName`, `display_name`, `id_color`; `min_straight` and `max_straight`, both `@export_range(2, 20)` with defaults 2 and 5; `cross_junction_chance`, 0–1, default 0.3 | no id; `min_straight < 2` (D7); `max_straight < min_straight`; a chance outside 0–1 |
| `AreaScheduleEntry` | `turn`, `area`, `set_piece: StringName` (Δ: not a `PackedScene`), `set_piece_length` (`@export_range(0, 20)`) | (checked by the schedule) |
| `AreaSchedule` | `entries: Array[AreaScheduleEntry]` | no entries; a missing (null) entry, checked before any field is read; a first turn other than 0; a set piece on the first entry; turns that don't strictly increase; an entry without an area, and each area's own problems; a negative `set_piece_length`; a `set_piece` without a length, or a length without a `set_piece` |

The five areas use IP M4.2's values:

| Area | Straights (min/max) | Crossroads chance | `id_color` |
|---|---|---|---|
| city | 2/5 | 0.40 | (0.55, 0.58, 0.63) |
| rural | 3/7 | 0.25 | (0.78, 0.66, 0.38) |
| meadows | 3/7 | 0.30 | (0.42, 0.68, 0.33) |
| village | 2/5 | 0.35 | (0.76, 0.52, 0.40) |
| desert | 3/8 | 0.30 | (0.90, 0.79, 0.54) |

`schedule.tres` (IP M4.2): turn 0 city; 34 rural after a 6-tile tunnel; 100 meadows after a 5-tile bridge; 200 village; 220 desert. The last area goes on forever.

**Turn semantics (G14).** An entry for turn T applies once T junctions exist, that is, right after the junction whose `turn_number` is T − 1. That junction and the set-piece tiles keep the old area. The next tile is a straight from the new area, and its length follows the new area's rules. For seed 12345: the tunnel is at path tiles 154–159 and rural starts at 160; the bridge is at 562–566 and meadows starts at 567; village starts at 1181 and desert at 1269.

### 5.7 Grey box (PR 1 and PR 4)

**`Iso`** (static, PR 1): `TILE_W = 128` and `TILE_H = 64`; `GROUND_PER_TILE = 4`, which gives 32×16 ground diamonds (`plan.md` §5.2). It has `tile_to_world()` as in IP M1.6, its inverse `world_to_tile()`, and `cell_centre()`. **Δ G2:** `layer_offset(layer, cells_per_tile)`.

**`GreyboxAtlas`** (static, PR 4) **Δ G8**:
- Road atlas: column = `exits − 1`, which covers all 15 road tiles (4 caps, 2 straights, 4 corners, 4 T-junctions, 1 crossroads). Its rows are `ROAD`, `DEAD_END` (the debug tint), `TUNNEL` and `BRIDGE`. The 1920×256 image is drawn once from `RoadGeometry.distance_to_centreline()`, and `road_tileset()` caches it until the game quits.
- Road edges are `EDGE_WIDTH = 0.035` tiles wide, in `EDGE_COLOR`. `BLEED_PX = 1.0` (G10).
- Ground atlas, from `build_ground_tileset(colors)`: one column per area (`id_color`), and two checker shades as rows (`GROUND_SHADE = 0.07`).
- `road_coords(tile, show_dead_ends)`: the dead-end tint takes precedence over the tunnel and bridge rows. `ground_coords(column, cell)` picks the checker shade.

**`WorldRenderer`** (`Node2D`, PR 4). `world/world.tscn` holds it with `%GroundLayer`, `%RoadLayer` and a y-sorted `%Props`.
- `@export var show_dead_ends := false` (Q10).
- `bind(buffer, schedule)` builds both tilesets, offsets the layers (G2), connects the buffer's signals and draws `buffer.tiles()`.
- Each tile gets one road cell and 4×4 ground cells in its area's colour, and both are erased when the tile is freed. **Δ G7:** no props and no `PropPool`.

### 5.8 Road viewer (PR 4) **Δ G4**

`ui/main.tscn`: `Main` (`Node`, script `main.gd`) with `World` (an instance of `world.tscn`), `Ghost` (a yellow `Polygon2D` marker), `Camera` (zoom 0.5) and `UI/Label`.

- The ghost moves along `buffer.centreline_point()` at 3 tiles/s, or 24 while the up arrow (`ui_up`), any touch or the left mouse button is held. These speeds are viewer settings in `main.gd`, not tuning.
- Touches are tracked by index, and the mouse button separately, so lifting one finger doesn't stop fast-forward while another is still down. `is_fast_forwarding()` exposes the state to tests (§4.6).
- Every physics frame it calls `buffer.on_car_path_index(roundi(distance))`.
- User arguments after `--`: `--seed=N` picks the road, otherwise the seed is random (D8). `--autopilot` always fast-forwards.
- It prints `grey box: tilesets built in %d ms` at start (E9). With `--autopilot`, it prints `autopilot: tile %d, turns %d, area %s` when it quits (`_exit_tree`), which `smoke.sh` checks (G17).
- The label shows the version, seed, tile, turns passed, area and lookahead, and the hint "hold up arrow, click or touch: faster". Dead ends are tinted (Q10).
- The label uses only characters in Godot's default font. The Web build has no system font to fall back on, so a "↑" showed as a box (§4.6).

### 5.9 CI scripts

`lint.sh`, `ci.yml` and the other workflows don't change. `lint.sh` already lists `road/`, `world/`, `areas/`, `config/` and `tests/` for gdlint and gdformat, and runs its determinism rule over `road/`, `world/` and `areas/` once they exist.

- `run_tests.sh` (PR 1, G1). After the JUnit checks:
  ```bash
  fail_on "ObjectDB instances? (was|were) leaked|resources? still in use at exit" "$log" \
    "Objects leaked at exit: a cycle of RefCounted references, or a node that is never freed"
  ```
- `smoke.sh` (PR 4, G17). The M0 run already passes `-- --autopilot --seed=12345`. It now also requires a line that matches `^autopilot: tile [1-9]`, and otherwise fails with `::error::The main scene reported no autopilot progress (see $log)`. Its header comment changes to match.
  - The tile is the buffer's car index, so a viewer that stops driving the buffer reports `tile 0` and fails.
  - The rest of the line isn't pinned. Any intended change to the generator, the area tuning (M4) or the driving (M2's car) changes the turns and area at the end of the run, and GUT checks the generator's rules over many seeds (E1–E5).
- `tests/unit/test_smoke.gd` (PR 4): `var main: Node`; the root was a `Control`. Two new tests check the label's glyphs and the fast-forward input (§4.6).

### 5.10 Tuning

`config/tuning.gd` (PR 1):

| Constant | Value | Source |
|---|---|---|
| `ROAD_HALF_WIDTH` | 0.32 | D4 |
| `BUFFER_AHEAD` | 50 | IP M1.5 |
| `BUFFER_REFILL_AT` | 25 | IP M1.5 |
| `BUFFER_BEHIND` | 5 | IP M1.5 |
| `START_STRAIGHT_TILES` | 4 | G11, Q4 |
| `DEAD_END_MIN_TILES`, `DEAD_END_MAX_TILES` | 2, 3 | IP M1.4 (`randi_range(2, 3)`) |

### 5.11 Tests

| File | Tests | PR | What they check |
|---|---|---|---|
| `test_heading.gd` | 3 | 1 | left, right and opposite; turns alternate from L; bits and steps |
| `test_road_geometry.gd` | 6 | 1 | the centre is on the road for every tile; a straight; the cap is rounded at the centre; T-junction and crossroads; neighbouring tiles meet at the same width; the `RoadTile` overload |
| `test_occupancy_grid.gd` | 2 | 1 | claim and release; claiming a taken cell is an error (G3) |
| `test_iso.gd` | 4 | 1 | `tile_to_world()`; `world_to_tile()` inverts it; road and ground layer cells line up with tile space (G2) |
| `test_area_schedule.gd` | 2 + 5 | 1, 2 | the game schedule is valid; `validate()` reports broken schedules, missing entries and negative lengths included. PR 2: the generator reports a broken schedule; it replaces a broken schedule with one default area; switches at 34, 100, 200 and 220; the straight after a switch uses the new area; the last area goes on forever |
| `test_road_generator_pattern.gd` | 6 | 2 | over seeds 1, 2, 3, 42 and 12345: the path starts north with a straight run; expected exits alternate; a connected N/W staircase; the expected exit plus 1–2 wrong exits, with a matching type; straights follow the area rules; dead ends run straight out of wrong exits and end in a cap |
| `test_road_generator_occupancy.gd` | 2 | 2 | 200 seeds × 500 turns: one tile per cell, each junction keeps a wrong exit, dead ends of 1–3 tiles, nothing dropped. The densest rules over 50 seeds shorten dead ends but never drop them |
| `test_road_generator_determinism.gd` | 2 + 1 | 2, 3 | the same seed gives the same 2,000 path tiles; different seeds differ. PR 3: buffer refills and frees don't change the road |
| `test_road_buffer.gd` | 7 | 3 | `start()` generates 50 ahead; lookahead under a fuzz of 20 seeds × 400 random car moves, backwards included, with a jump of up to 40 tiles every 50 moves; freed tiles leave with their dead ends; `path_tile()` and the centreline; the centreline clamps at the buffer's ends; before `start()`, the centreline is an error; dropping the buffer frees every tile (`WeakRef`, G1) |
| `test_greybox_atlas.gd` | 5 | 4 | the layout; `road_coords()`; road in every tile's centre and in no corner; the pixels follow `RoadGeometry` (G8); the ground tileset |
| `test_world_renderer.gd` | 3 | 4 | it draws the buffer and follows refills and frees; the debug tint; the layers line up (G2) |
| `test_smoke.gd` | 2 + 2 | M0, 4 | the project name; the main scene shows the version, with its root now a `Node` (§5.9). PR 4: the label's text has every glyph in the default font; fast-forward lasts while any touch or the mouse button is held (§5.8) |

The determinism tests compare `road_fixtures.signature()`: the tile's cell, type, exits, `area_id`, `path_index`, `expected_exit` and `set_piece`, plus each dead end's cell, type, exits and `junction_index`. **Δ IP "M1 tests":** no `decor` (G7).

---

## 6. Verification

### 6.1 Local checks

The commands are those of M0_PLAN.md §6.1: `lint.sh`, `import.sh`, `check_scripts.sh`, `run_tests.sh` and `smoke.sh` in `tools/ci/`. Every PR state was rebuilt on #18's head (3fbd395), and all five passed. "Port" is the state right after the checkout (§4); "final" is the PR head after the review fixes (§4.6), all five checks run again:

| State | `check_scripts` | GUT tests: port → final | Asserts: port → final | GUT time |
|---|---|---|---|---|
| M0 (#18) | 4 | 2 | — | — |
| PR 1 | 19 | 19 → 19 | 116 → 119 | 0.4 s |
| PR 2 | 23 | 33 → 34 | 143,055 → 143,064 | 6.6–6.7 s |
| PR 3 | 25 | 39 → 42 | 143,374 → 143,391 | 6.8–7.3 s |
| PR 4 | 29 | 47 → 52 | 143,448 → 143,469 | 6.7–7.3 s |

`lint.sh` reports `Actions storage: no caches, artifacts kept 1 day (5 files checked)` in every state. PR 4's `smoke.sh` prints `autopilot: tile 1440, turns 247, area desert`.

### 6.2 Negative cases

For each case, make the temporary change in the PR state that has the code, run the checks, then revert. Every "Expected" result was reproduced: N1–N22 by a script that applied each change to the prototype in turn, N23 on the PR 1 state, and N24–N28 on the PR heads while fixing the reviews (§4.6).

| # | Temporary change | Expected | With IP's design |
|---|---|---|---|
| N1 | `turn_for()` swaps left and right | GUT fails: `test_turns_alternate_left_and_right_from_left` and 2 pattern tests | Fails ✓ |
| N2 | `_is_free_run()` ignores taken cells | GUT fails: 12 tests, including both occupancy tests | Fails ✓ |
| N3 | Dead ends hold their junction in a `RoadTile` field (IP M1.2) | GUT fails: `test_dropping_the_buffer_frees_every_tile`. Without that test, `run_tests.sh` still fails: 614,892 objects leaked | GUT exits 0 (G1) |
| N4 | The renderer drops the road layer offset | GUT fails: `test_layers_line_up_with_tile_space` | Not tested (G2) |
| N5 | The buffer frees a junction but not its dead-end cells | GUT fails: `test_freed_tiles_leave_with_their_dead_ends` | Fails ✓ |
| N6 | Set-piece tiles take the new area | GUT fails: 2 area-schedule tests | Fails ✓ |
| N7 | The generator calls the global RNG | `lint.sh` fails: "Global RNG in gameplay code"; GUT fails 2 determinism tests | Fails ✓ |
| N8 | No 1-tile retry for a blocked dead end | GUT fails: 10 tests | Fails ✓ |
| N9 | `main.gd` prints no `autopilot:` line | `smoke.sh` fails: "The main scene reported no autopilot progress" | Not tested (G17) |
| N10 | The buffer keeps 8 tiles behind instead of 5 | GUT fails: the lookahead fuzz | Fails ✓ |
| N11 | The buffer refills at lookahead 20 instead of 25 | GUT fails: the lookahead fuzz | Fails ✓ |
| N12 | Atlas diamonds without bleed | GUT fails: `test_road_pixels_follow_the_road_geometry` | No atlas (G8, G10) |
| N13 | Schedule entries apply one turn early | GUT fails: 2 area-schedule tests | Fails ✓ |
| N14 | The straight after a switch is sampled from the old area | GUT fails: `test_the_straight_after_a_switch_uses_the_new_area`, `test_straights_between_junctions_follow_the_area_rules` | Fails ✓ |
| N15 | `release()` frees a cell that another tile holds | GUT fails: `test_claiming_a_taken_cell_is_an_error` | IP's `release(cell)` always frees it (G3) |
| N16 | Crossroads keep type `T_JUNCTION` | GUT fails: `test_junctions_have_the_expected_exit_and_one_or_two_wrong_exits` | Not tested |
| N17 | `cross_junction_chance` is ignored (never a crossroads) | GUT fails: `test_densest_rules_shorten_dead_ends_but_never_drop_them` | Not tested |
| N18 | The buffer accepts a lower car index | GUT fails: the lookahead fuzz | IP's fuzz only moves forward |
| N19 | `tiles_generated` leaves out dead ends | GUT fails: 2 buffer and 2 renderer tests | Not tested |
| N20 | Dead ends one tile longer than allowed | GUT fails: 3 tests | Fails ✓ |
| N21 | Ground cells are not erased when their tile is freed | GUT fails: `test_draws_the_buffer_and_follows_refills_and_frees` | Not tested |
| N22 | Dead-end caps keep a forward exit | GUT fails: `test_dead_ends_run_straight_out_of_wrong_exits_and_end_in_a_cap` | Not tested |
| N23 | In the PR 1 state, a test makes a `RoadTile` hold itself in `branches` | GUT passes 20/20, but `run_tests.sh` fails on "3 ObjectDB instances were leaked at exit" and "1 resources still in use at exit" | GUT exits 0 (G1) |
| N24 | `AreaSchedule.validate()` without the missing-entry and negative-length checks | GUT fails `test_validate_reports_broken_schedules`: `[""] expected to equal ["entry 0 is missing"]`, plus the errors from reading a null entry | IP's validator checks only the turns (IP M4.1) |
| N25 | `RoadGenerator._init` keeps a broken schedule, as in the prototype | GUT fails `test_the_generator_replaces_a_broken_schedule_with_one_default_area` on the errors from reading it | Not specified |
| N26 | `centreline_point()` doesn't clamp the distance | GUT fails `test_centreline_clamps_to_the_buffer_ends`: 4 asserts, for example `(0.5, 3.5)` expected to equal `(0.5, 0.5)` | Not tested |
| N27 | `main.gd` keeps one flag for every touch and the mouse, as in the prototype | GUT fails `test_fast_forward_lasts_while_any_touch_or_the_mouse_button_is_held`: "touch 0 is still down" | Not tested |
| N28 | The hint says "↑" again, as in the prototype | GUT fails `test_main_scene_text_has_every_glyph_in_the_default_font`: `["↑"]` | Not tested |

### 6.3 Screenshots

A scratch `SceneTree` script drove the viewer at its fast speed with seed 12345 and saved the viewport 2 tiles before each area and set piece. The four main frames: tile 152 (turn 33, city, the tunnel ahead), tile 158 (in the tunnel), tile 565 (on the bridge) and tile 1267 (village, the desert ahead), with the dead ends tinted. The command:

```bash
xvfb-run -a -s "-screen 0 1280x1024x24" godot --path . --rendering-driver opengl3 \
  --resolution 360x640 --audio-driver Dummy --fixed-fps 60 -s res://shot_drive.gd -- --seed=12345
```

The script isn't committed, because it reads the viewer's private fields; M6.6 builds the real tool. Without `--audio-driver Dummy`, Godot prints an `ERR_CANT_OPEN` error and still exits 0 (G16).

### 6.4 Verified only in CI or on devices

| Check | PR | Result |
|---|---|---|
| The five checks on GitHub; the `test` job time against M0's 51–76 s (Q9) | 1–4 | Green on every PR head; the job takes 62–89 s (§6.6) |
| The Web build in Chrome and Firefox; Pages after the merge | 4 | Web done on 7030e40 (§6.6); Pages after the merge |
| The APK on the Galaxy Z Fold4: scrolling, touch and hold, and the `grey box:` time (Q3) | 4 | The owner (§7) |

### 6.5 Measurements (prototype, local)

- GUT: 47 tests and 143,448 asserts in 6.8–7.6 s. The 200 × 500 occupancy test alone takes 3.1 s.
- Over 200 seeds × 500 turns with the game schedule: 6.13 path tiles per turn, and 30.3% of junctions are crossroads.
- Grey-box tilesets: 59–62 ms to build headless, and 60–65 ms with the OpenGL renderer under xvfb; 2 ms when cached. The whole smoke run takes about 1 s.
- The CI `test` job took 51–76 s in M0's last 8 runs (Q9).

### 6.6 Measurements (PRs)

- **Local GUT:** PR 4's head runs 52 tests and 143,469 asserts in 6.9–7.0 s.
- **CI, the latest runs of each PR:** the `test` job took 62–89 s, against M0's 51–76 s. Starting the Godot container takes 41–62 s of that, and the GUT step 2 s in PR 1 and 8–11 s from PR 2 on. The job stays under Q9's 100 s, so the 200 × 500 test stays.
- **Web (E9):** the CI artifacts, served with `python3 -m http.server` and driven with Playwright. There is no GPU, so both browsers render in software. Results are on #23.
  - `grey box: tilesets built in` 171–213 ms in Chrome 156 (headless) and 107–216 ms in Firefox 156 (llvmpipe under Xvfb), over PR 4's builds.
  - Holding the left mouse button for 3 s moves the ghost about 72 tiles. After release, it moves about 3 tiles/s.
  - With Chrome's touch emulation: two fingers down, one lifted at 600 ms, the other held to 3 s. The ghost moves 74 tiles; before the fix in §4.6, it moved 28.

---

## 7. Owner actions

These need the repository owner. The current state was read with `gh api` on 2026-11-07.

| When | Action | How |
|---|---|---|
| Done | Merge #18 (F34) | Merged on 2026-11-07 |
| Done | Require the `lint` status check in ruleset "Test" (id 26672445) | See below |
| Optional | Allow deleting merged PR branches, so GitHub retargets stacked PRs by itself | Ruleset "Copilot" (id 26740665): turn off "Restrict deletions". Otherwise retarget with `gh pr edit` (§4.5) |
| Before PR 4 merges | The E9 Android check; the Web check is done (§6.6) | §4, PR 4 step 3 |
| Done | Answer Q1–Q13, or accept the defaults | The defaults were approved with this plan |

**Requiring `lint`.**
1. Settings → Rules → Rulesets → **Test**.
2. Under "Require status checks to pass", click **Add checks**.
3. Type `lint` in the search box. If it isn't in the suggestions, click the **+** button beside the box, which adds the typed name as it is. GitHub suggests only checks that reported in the last 7 days; `lint` ran on `main` (aeffcf6) on 2026-11-07, and on #18.
4. Click **Save changes**.

With the CLI, this adds `lint` and keeps everything else:

```bash
gh api repos/pompomon/roadgame/rulesets/26672445 \
  --jq '{name, target, enforcement, conditions, bypass_actors: (.bypass_actors // []),
         rules: [.rules[] | if .type == "required_status_checks"
                 then .parameters.required_status_checks += [{"context": "lint", "integration_id": 15368}]
                 else . end]}' \
  | gh api -X PUT repos/pompomon/roadgame/rulesets/26672445 --input -
```

`integration_id` 15368 is GitHub Actions, as for the other four checks.

---

## 8. M1 risks

| Risk | Impact | Mitigation |
|---|---|---|
| The new tests add about 7 s to GUT | A slower `test` check | Measured: the GUT step takes 8–11 s in CI, and the job 62–89 s (§6.6). Shrink the 200 × 500 test if the job regularly takes more than 100 s (Q9) |
| Building the atlas is slow in browsers or on the phone | A late first frame | E9 measures it: 107–216 ms in Chrome and Firefox with software rendering (§6.6); the phone is still to check. Over 300 ms, PR 4 switches to a baked PNG before it merges (Q3) |
| M2 replaces `ui/main.gd` | `smoke.sh` fails without the `autopilot:` line | M2 keeps the line, or changes `smoke.sh` in the same PR (G17, §9) |
| float32 positions far from the origin | Jitter in long runs | None needed: at 200,000 px (about 6,000 path tiles), positions are precise to about 1/64 px |
| `push_error` doesn't stop a release build | A broken invariant goes unnoticed | Every CI script fails on error lines (M0 F10), and a test covers each invariant (§6.2) |
| Squash merges of stacked PRs | Add/add conflicts, and `-X ours` can drop a review fix | §4.5: merge PR n's final branch first, then check `git diff --name-only origin/main` |
| The PRs drift from the prototype after reviews | The prototype stops being a reliable reference | PR 4's tree check shows every difference: the six files changed in §4.6 |
| `m1/prototype` disappears before PR 4 | PRs can't check files out | Keep it until PR 4 merges |
| A CI run on `m1/prototype` | Caches and 14-day artifacts from its pre-F34 `ci.yml` | Never open a PR from it or start a manual run on it |

---

## 9. Notes for later milestones

- **M2:**
  - Add the driving fields of `plan.md` §3.7 to `AreaDef`, because `CarSim` reads them (M2.2): `straight_accel`, `junction_brake_distance`, `junction_speed`, `offroad_speed_mult`, `offroad_damage_per_sec` and `offroad_limit_tiles`. Set them in the five area `.tres` files to IP M4.2's values, and extend `validate()` (G5). `offroad_limit_tiles` is 2.0 in every area: IP M4.2 lists it with the global constants, but M2.2 and `plan.md` §3.7 read it from the area.
  - Keep the `autopilot:` line, or update `smoke.sh` in the same PR (G17).
  - Find a dead end's junction with `buffer.path_tile(tile.junction_index)` (G1).
  - Relay the buffer's signals through `EventBus` (M2.7, G6).
  - `on_car_path_index()` ignores lower indices, so a car that rejoins behind is fine.
  - `centreline_point()` clamps at the ends of the buffer without an error (§5.5), so call `on_car_path_index()` before reading it.
  - Name seed parameters `run_seed`, including M2.7's `start_run(seed := -1)` (G13).
  - Turn the dead-end tint off in the game (Q10).
  - Use only characters in Godot's default font in UI text, or ship a font: the Web build has no system font to fall back on. Extend `test_main_scene_text_has_every_glyph_in_the_default_font` to the HUD (§4.6).
- **M4:**
  - Add the remaining `AreaDef` fields (`palette`, `road_tileset`, `ground_variants`, `props`, `disasters`, `ambient_loop`, `music` and `transition_tiles`) and `PropDef` (M4.1).
  - Seed the props stream with `hash("%d:props" % run_seed)`, and add the prop-density determinism test (G7).
  - Map `set_piece` ids to scenes (M4.4, G5).
  - `area_changed` (M4.3) fires on the first tile of a new area, as defined in §5.6.
- **M5.1:** no corner art (G12). The 15 road tiles match `GreyboxAtlas`'s columns.
- **M6.6:** run screenshots with `--audio-driver Dummy`, and drive along the road rather than jump (G16, §6.3).
