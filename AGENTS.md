# AGENTS.md

How to work on Road Roguelike, for coding agents (the Copilot cloud agent, Copilot CLI and others) and for Copilot code review. This file holds what every task needs. Rules for some paths are in `.github/instructions/`, which Copilot applies to matching files, and how-tos are in `docs/agents/` (§1).

## 1. Start here

**The game.** An isometric driving roguelike for Android (reference device: Samsung Galaxy Z Fold4) and the Web. At each junction the player must follow a hidden left-right pattern, to reach the pier where the road ends after its 100th turn (`plan.md` §1–§2). It uses Godot 4.7.2 with the Compatibility renderer, typed GDScript, and GUT 9.7.1 for tests.

**Documents.** The most specific one wins.

| File | What |
|---|---|
| `<NAME>_PLAN.md`, at the root | The plan of work in progress, if any. It replaces IP wherever it marks a difference with **Δ** |
| `docs/<NAME>.md` | A summary of each finished plan (`docs/README.md`): the findings, decisions and design that code and tests cite by ID |
| `IMPLEMENTATION_PLAN.md` (IP) | Milestones M0–M7 (§3, §4), decisions D1–D12 (§1.2), conventions (§1.3), determinism (§5.3), CI (§7), definition of done (§9) |
| `plan.md` | The game design |

IDs: E# exit criteria, P# probes, Q# questions, N# negative cases, and findings F# (M0), G# (M1), H# (M2), J# (M3), K# (M4), L# (M5), S# (M6), R# (ROADGEN), Z# (ZONE_SELECT), T# (TUTORIAL), C# (DAYNIGHT), A# (VISUALS), V# (POOLS), W# (ENDGAME), B# (HEADLIGHTS), U# (SPEEDUP) and Y# (PERF). Cite them with their file, such as `docs/M2.md H16`; "M2 H16" is short for that.

**State.** M0–M6 are merged, and so are ten plans of their own: the road generator, the zone select, the tutorial, the day and the night, the visuals, the legends' pools, the road's end with the Book of Legends, the headlights, resting windmills and meadow grass, the road to the sea in five minutes, and 40–50 fps in the browser (#1–#76, #80–#91, #93, #94, #96–#98, #101–#113, #116–#121, #124 and #126–#129). Settings → Show FPS shows the frame rate on any build, and desktop runs and the Web build take the switches `fps`, `stretch` and `fpscap` (docs/agents/checks.md §2). M7 is next: Ship, with orientation and foldables, haptics, the Web's audio, the signed release and device QA. IP §4 M7 gathers the notes for it.

**Layout.** `autoload/`: the `EventBus`, `GameState`, `SaveService` and `AudioDirector` singletons. `road/`: the generator and the junctions. `car/`: `CarSim` (the pure simulation), `Autopilot`, `CarController` and `InputRouter`. `world/`: the projection, the renderer, props, shadows, lamps, the camera, and the day and the night. `disasters/`: the director and the legends. `setpieces/`: the tunnel and the bridge. `ui/`: `main.tscn` (the main scene), the HUD, game over and the title. `audio/`: the music and the ambience. `areas/`: `AreaDef` and one `.tres` per area. `config/tuning.gd`: the tuning constants. `assets/`: the art, the font and the sounds, made by `tools/art/` and `tools/audio/`. `tests/`: `unit/`, `sim/`, `integration/` and `helpers/`. `tools/ci/`: the CI scripts (§3). `tools/agent/`: `watch_pr.sh` and `land_pr.sh` (§5), and their tests in `test/`. `tools/perf/`: the frame-rate measurements in the browsers, the pixel comparison of desktop runs, and their Node tests (docs/PERF.md §6.5). `addons/gut/`: GUT 9.7.1, unmodified.

**Read more** when you need it:

| When you | Read |
|---|---|
| plan a milestone or a feature, land its last PR, or sum it up and learn from it | `docs/agents/planning.md` |
| stack PRs, land one, or update one after its base is merged | `docs/agents/stacks.md` |
| set up the checks, run the game, build it, or check it in a browser | `docs/agents/checks.md` |
| ask for a review, answer one, watch a PR, or fix CI | `docs/agents/review.md` |
| change legends, light, screens, tests or CI | `.github/instructions/`: `legends`, `light`, `ui`, `tests` and `ci` |

## 2. Rules for code

Reviewers check these too.

- **Typed GDScript.** The `untyped_declaration` warning is an error (IP D12). Files are `snake_case.gd`, non-autoload scripts have a `class_name`, and signals are named in the past tense (IP §1.3).
- **Determinism.** Gameplay code uses only seeded `RandomNumberGenerator` streams. `lint.sh` rejects the global `randf()`, `randi()`, `randfn()`, `randf_range()`, `randi_range()`, `randomize()`, `seed()` and `rand_from_seed()`, and `.shuffle()` and `.pick_random()`, in `autoload/`, `road/`, `world/`, `car/`, `disasters/`, `areas/` and `setpieces/` (IP §5.3). The simulation runs in `_physics_process` at 60 Hz, and tests step it with a fixed `delta`.
- **Logic apart from nodes.** Game logic lives in pure `RefCounted` classes such as `CarSim`, with thin `Node` wrappers, so tests can run hundreds of turns headless (IP D2). Every gameplay `RefCounted` has its `tests/unit/test_<name>.gd`.
- **State as of the event.** A handler that records or judges an outcome runs once the outcome is known. `CarSim.step()` emits `area_changed` before the move's road checks, and `main` takes `GameState.distance` before the car steps. So listen to a signal that fires after the outcome, adding one if need be, as `area_crossed` was (docs/ENDGAME.md W32). Have it carry the value, as `damaged(area)` does, or read the value again from its source, as `_end_run()` does, and test the value recorded (#84, #113).
- **No lambdas that use `self`** connected to a signal of an object that `self` holds. The cycle is never freed: GUT passes, but `run_tests.sh` fails on the leak (docs/M2.md H16). Connect a method instead.
- **Errors.** Report a broken invariant with `push_error()` and go on with a safe fallback. Don't use `assert()`: release builds strip it, and a debug run abandons the calling function while Godot still exits 0 (docs/M1.md G3). The CI scripts fail on any `ERROR:` line, and GUT fails a test on any unexpected error.
- **No shadowing.** Don't name a parameter or a variable after a built-in or a member: `seed` became `run_seed` (docs/M1.md G13, docs/M2.md H22). Only the editor warns about it, not CI (docs/agents/checks.md §1).
- **Say an edge case once.** Say when it happens in one place, the doc's section or the comment where the code decides it, no further than a test checks it, and cite that test. Elsewhere, cite that place. #118 said when an area or the finish comes after the tutorial in its plan, four sections of two summaries, `plan.md` twice, and comments in the generator, `main.gd` and two tests: 6 internal-review passes in a row found such a sentence, or one beside it, wrong or incomplete, 11 times in all, and 6 of the 7 commits from 9aaaa3b to 95ed1cf fixed them.
- **Values.** Tuning values live only in the `AreaDef` `.tres` files and `config/tuning.gd`. No magic numbers in logic (IP D11).
- **Nodes.** No node lookups by string path outside scene roots: use `@export`, or `@onready` with `%UniqueName` (IP §1.3). A node that must work while the tree is paused, such as input handling, needs `process_mode = PROCESS_MODE_ALWAYS` (docs/M2.md H3).
- **The tutorial.** Until the save says it's done, Play starts a run in the City with the tutorial, which has no disasters. `--play` and `--autopilot` skip it, and `--tutorial` forces it (docs/TUTORIAL.md §5.6).
- **Web.**
  - The Web export has no system font fallback. UI text may use only glyphs of the game's font, Pixel Operator 8 (`ui/theme.tres:3`): no arrows such as ↑. `test_smoke.gd` checks the main scene's text (docs/M6.md §5.8).
  - In Godot 4.7.2, each redraw of a `Polygon2D` after its first raises WebGL errors on the Web (godotengine/godot#124726, fixed in 4.8). Tint through `self_modulate`, not `color` (docs/M2.md §5.7).
  - Losing focus reaches the game only as the canvas's blur. The Web never sends `NOTIFICATION_APPLICATION_FOCUS_OUT` (docs/M2.md H4).
- **Light.** Draw the world as by day: `Daylight` darkens it by the zone's hour. The one exception is the car's headlights, whose material brightens the road in their cone while they are on, before the veil darkens it (docs/HEADLIGHTS.md §5.2). The light is visual only, so no gameplay or audio code reads `DayCycle`.
- **Files.** Commit the `.uid` file that Godot makes for each new script. After the checks, `git status --porcelain` must print nothing. A file that the editor saves by itself, such as the bus layout, is committed just as the editor writes it, uid included: change the buses in the editor's Audio panel (docs/M5.md L28).
- **`addons/gut/`** is GUT 9.7.1 as released. Don't patch it: upgrade by copying a newer release, and report bugs to bitwes/Gut.
- **Versions.** Godot 4.7.2 is pinned in the workflows and in `project.godot`, and `check_versions.sh` checks that they agree (`ci` instructions).
- **Every fix gets a test**, and a negative case that shows the test fails without the fix.

## 3. Local checks

CI runs these scripts, and they work the same way locally. In the cloud agent, Godot 4.7.2 is `/usr/local/bin/godot`; elsewhere, see `docs/agents/checks.md` §1. From the repository root:

```bash
python3 -m venv /tmp/venv && /tmp/venv/bin/pip install -r tools/ci/requirements.txt   # gdtoolkit
export PATH=/tmp/venv/bin:$PATH    # and GODOT=/path/to/godot, if godot isn't on PATH
tools/ci/lint.sh           # gdlint, gdformat, the RNG rule, shellcheck, version pins, Actions storage
tools/ci/import.sh         # imports the project; the next three need it
tools/ci/check_scripts.sh  # loads every script: parse and type errors
tools/ci/run_tests.sh      # GUT, 75–110 s; also fails on error lines and leaks
tools/ci/smoke.sh          # runs the main scene for 60 simulated seconds
git status --porcelain     # must print nothing, or CI's test job fails
```

While you work, `tools/ci/run_tests.sh -gselect=test_hud` runs each test script whose name contains `test_hud`, with the same checks. Run the whole suite before each push. Put the counts in the PR: scripts loaded, tests, asserts, GUT time, and `smoke.sh`'s `autopilot: tile …, turns …, area …` line. If you change `tools/agent/`, run `python3 tools/agent/test/scenarios.py` too, and if you change `tools/perf/`, `node --test tools/perf/test_*.mjs`, as CI's `lint` job does (`ci` instructions).

## 4. Branches and commits

- **Branches:** `m<n>/plan`; `m<n>/prototype`, which never gets a PR; `m<n>/<k>-<slug>` for PR k of milestone n, such as `m2/2-car-sim`. A plan of its own takes a short prefix, such as `dn/`. `ci/<slug>` and `docs/<slug>` are for the rest.
- **Commits:** `<area>: <what, in lower case> (M<n> PR <k>)`, such as `car: count only the part of a step off the road (M2 PR 2)`. The body says why, and names the tests and negative cases. Every commit, merges included, ends with `Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>`.
- **Never rebase or force-push** a branch that has a PR. Merge instead: review replies cite commit SHAs, and later branches merge earlier ones.
- **Stacked PRs.** PR k+1 branches from PR k's branch and targets it, with one worktree per branch. A review fix goes on the branch of the PR that adds the file, then merges up. Only PRs whose base is `main` get merged, and once the owner has merged the plan's PR, agents land them (§5). See `docs/agents/stacks.md`, also for updating a stack after a squash.

## 5. Pull requests and reviews

**The body** (no template; keep it current with `gh pr edit <n> --body-file <file>`):
- a first paragraph: which PR of its plan this is, what it does, and a link to its section of the plan;
- **Stack:** the chain of PRs and their bases, "Merge PRs only when their base is `main`.", and who lands this one: an agent, or the owner and why (step 4);
- `## Changes`: a table of area, files and differences from the plan, with the finding IDs;
- `## Verification (local, Godot 4.7.2)`: the checks' counts (§3), the CI `test` time, and each negative case with the tests it fails;
- `## Internal review`, `## Review fixes` (each with a link to the comment, its tests and its negative case), `## Manual checks (E#)`, and **Acceptance:** the E#s that it meets.

Before each push, check each claim in the body against the new head: its SHAs, counts, checks, negative cases and E# results. Copilot reviews the body too, and one of #106's rounds went on a body that still reported an older head's checks. A results comment claims only what its frames or recordings measure: #104's overstated a gap by the recorder's lag, and #106's called seals whole that had a hole in the middle.

**The loop** (`docs/agents/review.md`):
1. Before you open a PR, and before you push non-trivial fixes, have a subagent of a **different model family** review the change: `code-review` for a diff, `rubber-duck` for a plan. Check each finding yourself, and fix the real ones.
2. Copilot code review reviews every push. After each push, once your replies are posted, run `tools/agent/watch_pr.sh <n>`, with a long wait such as `initial_wait: 600`. Its exit says what to do: 0, land it (step 4); 2, feedback to handle; 3, no review, so `gh pr edit <n> --add-reviewer @copilot`; 4, someone pushed, so pull; 5, a check failed; 1, `gh` failed. If GitHub holds a push's CI run (`action_required`), its checks show only Copilot's: start the run with `gh run rerun <run-id>`, from `gh run list --branch <branch>`.
3. Answer each finding. Fix it with a test and a negative case, put all of a round's fixes in one push, and reply in its thread, starting `**Fixed in <sha>.**`. Or decline it with what you ran and what that showed. A review that you answer without a push also needs a PR comment that starts with a link to it, once you've answered all of it, and so does a person's PR comment or review, such as the owner's `@copilot …` (review.md §2 item 4). Start every PR comment you post with `Re [<what it answers or is about>](<link>)`. Then resolve Copilot's thread (review.md §2), but leave a thread that a person started for them to resolve.
4. **Land.** Once the owner has merged a plan's PR, which approves the plan, agents land its other PRs, bottom up: `tools/agent/land_pr.sh <n>` checks the gate (stacks.md step 4), squash-merges the PR at the head that Copilot reviewed, and retargets the PRs above it. The owner lands the rest: plan PRs; `docs/` and `ci/` PRs; the plan's last PR, after the device checks; PRs that the plan's §4 marks; PRs that change `AGENTS.md`, `.github/`, `docs/agents/`, `docs/README.md`, `tools/ci/`, `tools/agent/`, `export_presets.cfg` or `addons/`; PRs that add a Q#, change an E# or the scope, or decline a finding as out of the PR's scope; and PRs still drawing new findings after 5 rounds of review. Label each of those `needs-owner` and say why in a comment; only the owner removes the label. The owner holds any other PR the same way, or with a review thread.

**Where to check what** (`docs/agents/checks.md`): rules and numbers in GUT; how the game looks, sounds and plays in a desktop run with Movie Maker's frames; what only the Web does in the Web build, in Chrome and Firefox. Only what Android or the Fold4 alone does is left to the owner, on the debug APK: Back, leaving and resuming, both screens and folding, the frame rate, haptics and touch. List it in the PR body, for the plan's §6.4 when it is synced. It doesn't hold the PR: the plan's last PR gathers the list, with a build, and mentions @pompomon (planning.md §5).

## 6. Owner-only actions

Only the owner (@pompomon) approves plans, by merging their PRs; lands the PRs that §5 step 4 leaves to the owner (squash, in stack order), and removes `needs-owner`; deletes the branches that GitHub doesn't delete on merge; changes rulesets, repository settings, secrets, the release keystore and Pages settings; runs device checks on the Galaxy Z Fold4; answers the Q#s; and resolves the review threads that people start. Agents push to their own branches and open PRs, reply to reviews and resolve Copilot's threads, re-run CI, build artifacts, request Copilot reviews, and land the other PRs of approved plans (§5 step 4). Prepare each owner action so that it takes one step: exact commands, links and the expected results.
