# AGENTS.md

How to work on Road Roguelike. This guide is for coding agents (the Copilot cloud agent, Copilot CLI and others) and for Copilot code review, which reads this file on GitHub. It sums up how #1–#28 were planned, built, reviewed and landed, and what their reviews taught. The plans hold the details; this file points to them by section and ID.

Contents:
1. Start here
2. Planning a milestone
3. Rules for code
4. Local checks
5. Branches, commits and stacked PRs
6. Pull requests
7. Internal review by a different model
8. Copilot code review
9. Watching a PR after each push
10. CI
11. Owner-only actions

## 1. Start here

**The game.** An isometric endless driving roguelike for Android (reference device: Samsung Galaxy Z Fold4) and the Web. At each junction the player must follow a hidden left-right pattern (`plan.md` §1–§2). It uses Godot 4.7.2 with the Compatibility renderer, typed GDScript, and GUT 9.7.1 for tests.

**Documents.** The most specific one wins:

| File | What | IDs |
|---|---|---|
| `M<n>_PLAN.md` | The detailed plan of milestone n. For that milestone it replaces IP wherever it marks a difference with **Δ** | E# exit criteria; F#, G#, H#, J#, K#, L#, S# findings (M0–M6); P# probes; Q# questions; N# negative cases |
| `IMPLEMENTATION_PLAN.md` (IP) | Milestones M0–M7 (§3, §4), decisions D1–D12 (§1.2), conventions (§1.3), determinism (§5.3), CI (§7), definition of done (§9) | D#; work packages such as M2.2 |
| `plan.md` | The game design | — |

**State.** M0–M6 are merged (#1–#53): CI, the road generator and grey box, driving, disasters with game over and retry, the five areas with the tunnel and the bridge, the final art and audio with the menus and the save, and the legends. M7 is next: Ship, with orientation and foldables, haptics, the Web's audio, the signed release and device QA (IP §3, §4 M7). Read M6_PLAN.md §9 and M5_PLAN.md §9 first; they have notes for M7.

**Layout.**

| Path | What |
|---|---|
| `autoload/` | The `EventBus`, `GameState`, `SaveService` and `AudioDirector` singletons, and `SaveData` |
| `road/` | Road generator, buffer, geometry, occupancy grid and junction trigger |
| `car/` | `CarSim` (the pure simulation), `Autopilot`, `CarController` and `InputRouter` |
| `world/` | Isometric projection, the renderer with its props and skid marks, the camera, and the day and the night |
| `disasters/` | `DisasterDirector`, `DisasterBase` and `Legend`, and each legend's script and scene in `legends/` |
| `setpieces/` | The tunnel and the bridge |
| `ui/` | `main.tscn` (the main scene), the HUD, game over, the title with its screens, and the theme |
| `audio/` | `CrossFade`, for the music and the ambience |
| `areas/` | `AreaDef`, the area schedule, and one `.tres` per area |
| `config/tuning.gd` | Tuning constants |
| `assets/` | The palette, the art, the font and the sounds |
| `tests/` | GUT tests in `unit/`, `sim/` and `integration/`, with `helpers/` and `gut_post_run.gd` |
| `tools/ci/` | The CI scripts. They run the same way locally (§4) |
| `tools/art/`, `tools/audio/` | The scripts that make the art, the font and the sounds in `assets/`: `godot --headless -s <script>`, then `tools/ci/import.sh` |
| `tools/agent/` | Agent helpers: `watch_pr.sh` (§9) |
| `addons/gut/` | GUT 9.7.1, vendored unmodified |
| `.github/` | `ci.yml`, `release.yml`, `copilot-setup-steps.yml`, the `godot-env` action and Dependabot |

## 2. Planning a milestone

Each milestone started from a written plan, and the code followed in stacked PRs. M0's plan came with #2; M1's and M2's were plan PRs of their own, #19 and #24. Do the same:

1. **Review IP's milestone against the code on `main`.** Write down what is wrong, missing or ambiguous as findings, each with its evidence and its fix (M2 had H1–H31). The IDs are cited everywhere after that: in the plan, code comments, tests, commits and PRs.
2. **Verify, don't just review.** Build every file the plan adds or changes on a branch `m<n>/prototype` and run the five checks (§4) on it, locally: they take about 2 minutes there, and a CI run started by hand 5–6 minutes for the same results. Start one only for a build that you will check (§6). Back each claim about Godot with a probe or a test. Where Godot's behaviour isn't documented, cite its source by file and line (H16 cites `GDScriptLambdaSelfCallable`). To see or hear the game, run it on the desktop (§4). The prototype is only a reference: it never gets a PR.
3. **Write `M<n>_PLAN.md`** on branch `m<n>/plan`, in M2_PLAN.md's shape:
   - a header with the status, date and scope; the tool versions it was verified with; the precedence (Δ); the reference code; the prerequisites;
   - §1 the goal and exit criteria E#, each with how it is checked;
   - §2 the findings by severity: what's wrong, the evidence, the fix;
   - §3 decisions and open questions Q#, each with a default;
   - §4 the work breakdown: one PR per reviewable piece, with its files, steps and expected test counts; how the stack lands (§4.5); a table of review fixes, filled in later (§4.6);
   - §5 the design; §6 verification: local checks with counts (§6.1), negative cases (§6.2), editor warnings (§6.3), what only CI or a device can check (§6.4), measurements; §7 owner actions; §8 risks; §9 notes for later milestones.
4. **Negative cases.** For each rule and each fix, write the temporary change that breaks it and the check that must then fail (M2 has N1–N69). Run them with a script that applies each change, runs the check and restores the file:
   - While the code changes, run only the new cases and those whose files or tests changed, each with just the check that it names: for GUT, its test scripts (§4). The five scripts that HB's cases name run in 3 s; the whole suite takes 75–110 s. A case that must fail nothing needs the whole suite.
   - With the whole suite, run every case twice: on the prototype state that the plan reports, and on each PR's head once its reviews are done. That shows that each fails what the plan says and nothing else. Run them side by side in worktrees (§4). Start a PR's run as you push what should be its last round, while Copilot reviews it (§9). If a later commit changes more than docs, run them again.

   HB ran its 25 cases with the whole suite on 5 states: 103 runs of 87–95 s, about 2.6 hours (#62, HEALTH_BAR_PLAN.md §6.2). So run, they would take a few minutes on the 3 states between, and about 20 minutes, two at a time, on each of the other two.
5. **Open the plan PR**: docs only, base `main`. Have a different model review it first (§7). The owner answers the Q#s or accepts the defaults. If nobody answers, go on with the defaults and say so.
6. **Keep the plan current** while the PRs are reviewed: its status line, the review-fix table, the counts and the device results. The stack's last PR can carry the final sync, as M2 PR 4 did in aac0b4b.

## 3. Rules for code

Reviewers check these too. The IDs say where each rule comes from.

- **Typed GDScript.** The `untyped_declaration` warning is an error (D12). Files are `snake_case.gd`, non-autoload scripts have a `class_name`, and signals are named in the past tense (IP §1.3).
- **Determinism.** Gameplay code uses only seeded `RandomNumberGenerator` streams. `lint.sh` rejects global `randf()`, `randi()`, `randfn()`, `randf_range()`, `randi_range()`, `randomize()`, `seed()` and `rand_from_seed()`, and `.shuffle()` and `.pick_random()`, in `autoload/`, `road/`, `world/`, `car/`, `disasters/`, `areas/` and `setpieces/` (IP §5.3). The simulation runs in `_physics_process` at 60 Hz, and tests step it with a fixed `delta`.
- **Logic apart from nodes.** Game logic lives in pure `RefCounted` classes such as `CarSim`, with thin `Node` wrappers, so tests can run hundreds of turns headless (D2). Every gameplay `RefCounted` has its `tests/unit/test_<name>.gd` (IP §1.3).
- **No lambdas that use `self`** connected to a signal of an object that `self` holds. The cycle is never freed: GUT passes, but `run_tests.sh` fails on the leak (M2 H16, N2). Connect a method instead.
- **Errors.** Report a broken invariant with `push_error()` and go on with a safe fallback. Don't use `assert()`: release builds strip it, and a debug run abandons the calling function while Godot still exits 0 (M1 G3). The CI scripts fail on any `ERROR:` line, and GUT fails a test on any unexpected error. A test that causes one on purpose expects it with `assert_push_error()` or `assert_engine_error()`.
- **No shadowing.** Don't name a parameter or variable after a built-in or a member: `seed` became `run_seed`, and `start_run(p_run_seed)` (M1 G13, M2 H22, H24). Only the editor warns about it, not CI (M2 §6.3).
- **Values.** Tuning values live only in the `AreaDef` `.tres` files and `config/tuning.gd`. No magic numbers in logic (D11).
- **Nodes.** No node lookups by string path outside scene roots: use `@export`, or `@onready` with `%UniqueName` (IP §1.3). A node that must work while the tree is paused, such as input handling, needs `process_mode = PROCESS_MODE_ALWAYS` (H3).
- **The tutorial** (TUTORIAL_PLAN.md §5.6). Until the save says it's done, Play starts a run in the City with the tutorial, which has no disasters. `--play` and `--autopilot` skip it, and `--tutorial` forces it. A test that presses Play for a run without it marks it done first, in a save in memory: `SaveService.use_memory()`, then `SaveService.complete_tutorial()`, as `test_title.gd` does.
- **Web.**
  - The Web export has no system font fallback. UI text may use only glyphs of the game's font, Pixel Operator 8 (`ui/theme.tres:3`): no arrows such as ↑. `test_smoke.gd` checks the main scene's text, with the disasters' names, fates and lore (M6 §5.8).
  - In Godot 4.7.2, each redraw of a `Polygon2D` after its first raises WebGL errors on the Web (godotengine/godot#124726, fixed in 4.8). Tint through `self_modulate`, not `color` (M2 §5.7).
  - Losing focus reaches the game only as the canvas's blur. The Web never sends `NOTIFICATION_APPLICATION_FOCUS_OUT` (H4, N46).
- **Light** (DAYNIGHT_PLAN.md §5.5). Draw the world as by day. `Daylight`, a `ViewVeil` under Main, multiplies everything below `VEIL_Z` by the light of the zone's hour. At `VEIL_Z` draw only MUL veils, and above it only ADD glows; the UI is on layers of its own. Don't tint the world with a `CanvasModulate`, a `Light2D` or World's `modulate`: they would dim the glows and darken the legends' veils twice. A new veil is a `ViewVeil`. The light is visual only: no gameplay or audio code reads `DayCycle` (`test_daylight_run.gd`).
- **Files.** Commit the `.uid` file that Godot makes for each new script. After the checks, `git status --porcelain` must print nothing. A file that the editor saves by itself, as it does the bus layout, is committed just as the editor writes it, uid included: change the buses in the editor's Audio panel (M5 L28).
- **Shadows** (DAYNIGHT_PLAN.md §5.11). A prop says how it casts in its `PropDef`, `shadow` and `shadow_rise`, which `make_props.gd` sets with its art. Each cast is a black sprite in `Shadows`, a `CanvasGroup` that draws them into one buffer, then the buffer once at the clock's shadow alpha, so that overlaps don't darken twice (P8). A cast is a sprite in the group, never a group in a group, which draws wrong (P8b). Only the sprites' transforms, frames and `self_modulate`, and the two materials' parameters, change, so nothing is redrawn on the Web (C9). The legends and the set pieces cast none.
- **Legends** (M6_PLAN.md §5). A disaster from a legend extends `Legend` (`disasters/legend.gd`):
  - It poses its beats, `Tuning.<ID>_BEATS`, on its own clock in `_physics_process`: no Tween and no timer (§5.2, §5.3).
  - Before its delay nothing shows. Each part is in its scene, hidden by `modulate.a` 0 or `scale` 0. Polygons and particles stay under the legend, and a `Polygon2D`'s `visible`, `color`, `polygon` and `offset` never change (S6). A sprite that stands up goes in `standing`: `play()` puts it on the stage, `%Props`, to sort with the props and the car, and the legend frees it when it leaves the tree (§5.3).
  - To take the car, it hides it in the frame that the double from `take_car()` shows (§5.4).
  - Glows add light, so only a legend with a veil has them: over a light ground they clip to white (S10, §5.5).
  - Nothing flashes (WCAG 2.3.1). `test_disasters.gd` plays each legend and fails on a light that rises and falls more than 3 times a second, a red one more than once, a glow that covers a quarter of the screen, a veil that brightens, or a `Tuning` `*_HZ` above 3 (§5.6, E6).
  - Its sound is made by `make_audio.gd`'s `_save_legend(id, synth)`, seeded by its id alone so that no other sound changes, with each cue at its beat's start (§5.9).
  - Lists that each legend adds to (`AudioDirector.EFFECTS`, `make_audio.gd`, `config/tuning.gd` and `test_disasters.gd`'s pools) have a comment for each area. Add a legend's lines under its area's, so that stacked PRs' lines never touch (§5.10).
  - Scary, but no gore: the car is taken, shrunk or changed, never smashed, and no one is hurt on screen (Q8).
- **Lamps** (DAYNIGHT_PLAN.md §5.12). A prop's lights and pools of light, `lights` and `light_pools` in its `PropDef`, come from `make_props.gd`: the windows that it paints the palette's yellow, and the lamps' heads. `Lamps` is one `CanvasGroup` above the veil that adds what it holds once, so overlapping glows light no more than one (P10). It holds a black silhouette of each standing prop with the prop's glows, in the order that Props draws the props, so a prop hides the glows behind it. Tint it through `self_modulate`: its `modulate` would light the glows twice (N81). A glow adds to no channel more than the light takes away from white, so it never clips (`Lamps.strength()`, M6 S10).
- **`addons/gut/`** is GUT 9.7.1 as released. Don't patch it: upgrade by copying a newer release, and report bugs to bitwes/Gut.
- **Versions.** Godot 4.7.2 is pinned by the CI image tag `barichello/godot-ci:4.7.2` and by `GODOT_VERSION` in `copilot-setup-steps.yml`, and `project.godot`'s `config/features` starts with "4.7". `check_versions.sh` checks that they agree; a version bump follows IP §7.1. It reads every `barichello/godot-ci:` tag under `.github/`, so don't write that string there in any other form.
- **Actions storage.** No Actions caches, and artifacts are kept 1 day (M0 F34). `check_actions_storage.sh` enforces it.
- **Frozen appendices.** M0_PLAN.md's appendices A and B show M0's final files. Don't update them when those files change (M1 Q7).
- **Every fix gets a test**, and a negative case that shows the test fails without the fix.

## 4. Local checks

CI runs these scripts, and they work the same way locally (M0_PLAN.md §6.1). From the repository root:

```bash
pip install -r tools/ci/requirements.txt   # gdtoolkit 4.5.0, Python 3.12
export GODOT=/path/to/godot                # optional; the default is godot on PATH
tools/ci/lint.sh           # gdlint, gdformat, the RNG rule, shellcheck, version pins, Actions storage
tools/ci/import.sh         # imports the project; the next three need it
tools/ci/check_scripts.sh  # loads every script: parse and type errors
tools/ci/run_tests.sh      # GUT; also fails on error lines and leaks
tools/ci/smoke.sh          # runs the main scene for 60 simulated seconds
git status --porcelain     # must print nothing
```

- **Godot 4.7.2.** For the cloud agent, `copilot-setup-steps.yml` installs it as `/usr/local/bin/godot`, checked against its SHA-512. Elsewhere, install it the same way. Docker can run the CI image instead: `docker run --rm -v "$PWD":/w -w /w barichello/godot-ci:4.7.2 bash -c "tools/ci/import.sh && tools/ci/check_scripts.sh && tools/ci/run_tests.sh && tools/ci/smoke.sh"`.
- **pip refuses** to install into the system Python on Debian and Ubuntu (PEP 668). Use a virtual environment: `python3 -m venv /tmp/venv && /tmp/venv/bin/pip install -r tools/ci/requirements.txt`, then put `/tmp/venv/bin` first on `PATH`.
- **shellcheck.** `lint.sh` only warns if it's missing. The plans were verified with shellcheck 0.11.0 and actionlint 1.7.12; the `lint` job runs actionlint too.
- **The tree.** CI's `test` job runs the last check too, after the others, and fails if it prints anything (M5 L28).
- **Results.** Reports go to `build/reports/`. Put the counts in the PR, as M2_PLAN.md §6.1 does: scripts loaded, tests, asserts, GUT time, and `smoke.sh`'s `autopilot: tile …, turns …, area …` line.
- **Time**, on 2 CPUs: `lint.sh` 9 s, `import.sh` 14 s, `check_scripts.sh` 2 s, `run_tests.sh` 75–110 s, `smoke.sh` 1 s.
- **Fewer tests.** `run_tests.sh` takes GUT's options that choose tests, `-gselect=`, `-gtest=`, `-gdir=`, `-ginner_class=` and `-gunit_test_name=`, and no others, so its checks for errors, leaks and the save still apply. `tools/ci/run_tests.sh -gselect=test_hud` runs each script whose file name contains `test_hud`, in 2 s. `tools/ci/run_tests.sh -gdir= -gtest=res://tests/unit/test_hud.gd,res://tests/integration/test_crash.gd` runs just those two: `-gtest` alone adds them to the whole suite. Run the whole suite before each push.
- **Side by side.** Two whole suites in two worktrees took 77 s each on 2 CPUs, as long as one alone, so run one worktree per CPU (`nproc`). Each needs its own import: `git worktree add --detach /tmp/n1 HEAD && (cd /tmp/n1 && tools/ci/import.sh)`. Remove it after with `git worktree remove /tmp/n1`.

**Seeing the game.** No game code checks the platform: only debug builds add extras, the title's area choice and the game-over seed, and only some platforms send the notifications for focus, pause and Back (M2 H4, M5 L10, L13). So a desktop run plays as the builds do, but for the Web's limits (§3) and what only the Fold4 has (§6). It also takes the user arguments that the builds don't: `--play`, `--autopilot`, `--seed=<int>`, `--area=<id>` and `--tutorial` (`ui/main.gd`:7–13). Under Xvfb, Movie Maker writes each frame as a PNG for you to look at, and the sound as a WAV:

```bash
rm -rf /tmp/movie && mkdir -p /tmp/movie/data && XDG_DATA_HOME=/tmp/movie/data xvfb-run -a -s "-screen 0 1280x1024x24" \
  godot --path . --write-movie /tmp/movie/f.png --fixed-fps 60 --quit-after 600 -- --autopilot --seed=12345
```

- That's 10 s of play in 18 s. Each run starts afresh, with a scratch save in `/tmp/movie/data` that keeps yours out of it. `xvfb-run` is in the `xvfb` package.
- The frames are always the project's 360×640 (Godot 4.7.2's `main/main.cpp`:4840–4855): with another `--resolution`, they show its middle, cut to that shape and scaled. For the Fold4's sizes (M2_PLAN.md §6.5), save the viewport's image from a probe script, as M1_PLAN.md §6.3 did.
- Without Movie Maker, add `--audio-driver Dummy`, or Godot prints an `ERR_CANT_OPEN` error (M1 G16).

## 5. Branches, commits and stacked PRs

- **Branches:** `m<n>/plan`; `m<n>/prototype`, never a PR; `m<n>/<k>-<slug>` for PR k of milestone n, such as `m2/2-car-sim`; `ci/<slug>` and `docs/<slug>` for the rest.
- **Commits:** `<area>: <what, in lower case> (M<n> PR <k>)`, such as `car: count only the part of a step off the road (M2 PR 2)`. The body says why, and names the tests and negative cases. Every commit, merges included, ends with `Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>`.
- **Never rebase or force-push** a branch that has a PR. Merge instead: review replies cite commit SHAs, and later branches merge earlier ones.
- **One worktree per PR branch**, such as `git worktree add ../m2-2 m2/2-car-sim`, so the branches of a stack don't mix.
- **Stacked PRs** (M2_PLAN.md §4.5):
  1. PR k+1 branches from PR k's branch and targets it, so its diff shows only its own files. CI runs on every PR, but the required checks gate only PRs into `main`.
  2. A review fix goes on the branch of the PR that adds the file. Then merge that branch into each later one with `git merge --no-ff --no-edit` ("Merge m2/1-trigger into m2/2-car-sim"). If a later branch changes a file that an earlier PR adds, merging `main` after the squash is an add/add conflict. Likewise, a line inserted right next to one that an earlier PR inserts conflicts once that PR is squash-merged: keep them apart, as M5's `SKID_*` constants are from the `PROP_*` ones (M5_PLAN.md §4.5), or under comments that an earlier PR adds, as M6's legends are (M6_PLAN.md §5.10).
  3. Only PRs whose base is `main` get merged. In M0, fix PRs merged into stack branches skipped the required checks, so #16 and #18 had to land them again.
  4. After the owner squash-merges PR k, update PR k+1:
     ```bash
     git fetch origin main '+refs/heads/m<n>/*:refs/remotes/origin/m<n>/*'
     git switch <PR k+1 branch>
     git merge origin/<PR k branch>     # PR k's final state, in case a fix wasn't merged up yet
     git merge origin/main              # the squash commit
     git diff --name-only origin/main   # must list only PR k+1's files
     git push
     gh pr edit <k+1> --base main       # unless GitHub retargeted it
     ```
     Simulate the merges first with `git merge-tree`. A push like this changes no files in the PR, so it starts no Copilot review (§8).

## 6. Pull requests

There is no PR template. #25–#28 used this shape, and the body stays current as the PR changes (`gh pr edit <n> --body-file <file>`):

- A first paragraph: which PR of the milestone this is, what it does, and a link to its section of the plan.
- **Stack:** the chain of PRs and their bases, such as "#25 (→ `main`) ← this PR (→ `m2/1-trigger`) ← PR 3 ← PR 4", and "Merge PRs only when their base is `main`."
- `## Changes`: a table of area, files and differences from IP, with the finding IDs.
- `## Verification (local, Godot 4.7.2)`: the five checks on the head, with their counts (§4); the CI `test` time; each negative case and the tests it fails.
- `## Internal review`: the model, its findings and what you did (§7).
- `## Review fixes`: each fix, with a link to the comment or review, and its new tests and negative cases.
- `## Manual checks (E#)`: what a browser or the owner must check, and the results so far.
- **Acceptance:** the E#s that this PR meets.

**Where to check what.** Check each thing where it's quickest to check faithfully. Leave the owner only what needs the Fold4, in one list in the PR body:

| What | Where | Who |
|---|---|---|
| Rules, numbers, layouts at a given size, the font's glyphs | GUT, headless (§4) | Agent |
| How the game looks, sounds and plays | A desktop run, with Movie Maker's frames (§4) | Agent |
| What only the Web does: WebGL errors (§3), the canvas's blur (M2 H4), sound, which browsers start only after a gesture (M5_PLAN.md §9), the save in IndexedDB (M5 L11), touch in the browser | The Web build in Chrome and Firefox | Agent |
| What only Android or the Fold4 does: Back (M5 L13), leaving and resuming the app, both screens and folding, the frame rate on its GPU, haptics, how touch feels | The debug APK on the Fold4 | Owner |

**No Android emulator.** The Web and desktop runs play the same game as the APK (§4), and an emulator can't stand in for the Fold4. The APK holds only ARM code (`export_presets.cfg`:32–35), which an x86_64 emulator must translate. Where there's no `/dev/kvm`, as on the 2-CPU machine that the times in §4 come from, it isn't accelerated either. And it has neither the Fold4's GPU, nor its two screens, nor haptics.

**Builds.** CI uploads them only from a run started by hand, and keeps them 1 day. Start one only when you have something to check in it, and reuse it while nothing reaches it. The exports leave out `tests/`, `addons/gut/` and Markdown, so the build is current if `git diff --name-only <built> HEAD -- . ':!tests' ':!addons/gut' ':!*.md'` prints nothing. They leave out `tools/` too (`export_presets.cfg`), but `tools/ci/export.sh` makes them. Of the 6 builds of HB's prototype, the last 5 had nothing new but a comment.

```bash
gh workflow run ci.yml -R pompomon/roadgame --ref <branch> -f upload-builds=true   # Web and Android artifacts, kept 1 day
rm -rf /tmp/roadgame-web /tmp/roadgame-apk                                        # gh won't overwrite an earlier download
gh run download <run-id> -R pompomon/roadgame -n web -D /tmp/roadgame-web
gh run download <run-id> -R pompomon/roadgame -n "android-Android APK" -D /tmp/roadgame-apk
adb install -r /tmp/roadgame-apk/roadgame-debug.apk                               # the owner, as #28 gave it
```

In debug builds, the title's Start button chooses the area that Play starts in, so a device can check each area without `--area` (ZONE_SELECT_PLAN.md).

**The Web build** is a release build, without the debug extras. It takes no arguments until you patch its `index.html` (M4_PLAN.md §4, PR 3 step 3); then `?arg=` passes them:

```bash
sed -i 's/"args":\[\]/"args":["--"].concat(new URLSearchParams(location.search).getAll("arg"))/' /tmp/roadgame-web/index.html
python3 -m http.server -d /tmp/roadgame-web 8000   # http://localhost:8000/?arg=--play&arg=--seed=12345
```

- Drive Chrome and Firefox with Playwright, headed under Xvfb (#28). If Firefox is missing, install Playwright's, with the version of Playwright that drives it: `npx -y playwright@<version> install --with-deps firefox` took 47 s.
- They draw in software, so their frame rate depends on the browser and the page's size: on 2 CPUs, Chrome drew 49 fps at 360×640 and 21 at 1280×720 (22 in #44), and Firefox 59 and 55. Judge the frame rate only on the Fold4. Chrome's `GPU stall due to ReadPixels` notes, and an early `CONTEXT_LOST_WEBGL`, come from software GL too (M4_PLAN.md §6.6).
- With touch emulation on, Chrome takes touches of several fingers over the DevTools protocol (#23).
- Playwright keeps its pages focused, so a blur needs a browser without it, such as Chrome driven over the DevTools protocol, with real X input from `xdotool` under a window manager (#28, #33).
- The owner can play the same copy in the Fold4's Chrome, with arguments: `adb reverse tcp:8000 tcp:8000`, then the same address (M4_PLAN.md Q6).

Post the results as a table in a PR comment, one row per check. Mention @pompomon when the owner must act.

## 7. Internal review by a different model

Before you open a PR, and before you push non-trivial fixes, have a subagent that runs a **different model family** review the change. A reviewer built like you tends to miss what you missed. Each Copilot review round takes 2–7 minutes, and #26–#28 took 10–11 rounds each.

**How.** In Copilot CLI and the cloud agent, use the `task` tool:
- `agent_type`: `code-review` for a diff; `rubber-duck` for a plan or a design.
- `model`: one from another family. If you are a Claude model, pick a GPT or Gemini model (for example `gpt-6.1-sol` or `gemini-4-argon` as of 2026-11); if you are a GPT model, pick Claude. The `model` parameter lists the models available.
- If no other family is available, use the default model, and say so in the PR.
- `mode`: `background`, so that you can go on meanwhile, such as with a run of negative cases (§2). Read its result before you push.

**The prompt.** The subagent starts with no context. Give it:
- the goal, with the plan's sections and IDs;
- how to see the change, such as `git diff origin/main...HEAD`, and the files to read;
- the rules: "read AGENTS.md §3";
- the checks you ran and their results;
- what you want back: high-confidence bugs, missed edge cases, and tests that would pass without the fix. No style comments.

**After.** Check each finding yourself: reproduce it, or show why it's wrong. Fix the real ones as in §8, each with a test and a negative case. List the model, the findings and the outcome in the PR body. Bound it: one review per PR state, plus one after non-trivial fixes. Don't loop until the reviewer finds nothing.

## 8. Copilot code review

Rulesets "Test" (26672445) and "Copilot" (26740665) have Copilot review every push to a PR. In #19–#28 its 52 reviews came 2–7 minutes after the request, 3.3 minutes in the median. Expect several rounds: #26, #27 and #28 had 10, 10 and 11.

**What it posts.** `tools/agent/watch_pr.sh` (§9) prints all three kinds:
- **A review** by `copilot-pull-request-reviewer[bot]`. Its body begins with a verdict: 🟢 Approval recommended, 🟡 Changes recommended or 🔵 Needs a closer look. Then comes "No open issues" or "N open issues", and sometimes "N resolved since last review" or "N previously missed issues" (in code you didn't change). A 🔵 review may describe an unpublished finding that has no inline comment. A 🟢 review can still list an open issue (#3).
- **Inline comments** by `Copilot`, one thread each.
- **PR comments** by `Copilot`, such as a setup-step failure (#28: "Install Godot (SHA-512 verified)" failed). The review may then have missed context. Copilot's own check, `copilot-pull-request-reviewer`, shows as failed too.

**How to answer.**
1. Check each finding against the code, and reproduce it with a test where you can.
2. Fix it on the branch of the PR that owns the code (§5), with a test and a negative case. Put all of a round's fixes in one push: each push starts a new review.
3. Reply in each inline thread. Start with `**Fixed in <sha>.**`, then say what changed, the tests and the negative case, and for a stack `Merged up into #<k> (<sha>).` Use your environment's reply tool if it has one, as the cloud agent did on #1 and #17. Otherwise use `gh api repos/pompomon/roadgame/pulls/<n>/comments/<comment-id>/replies -F body=@reply.md` (`-F` reads the file; `-f` would send the text `@reply.md`).
4. Answer findings that have no thread (previously missed or unpublished ones) in one PR comment, as #26 did: `Re [Copilot's review of <sha>](<review URL>), whose overview says …: **Confirmed.** … **Fixed in <sha>.**`
5. Decline with evidence, not opinion: say what you ran and what it showed. #18 checked YAML findings against actionlint and PyYAML. Its last finding, a bypass of a heuristic check by deliberate shell tricks, was declined as out of the check's scope. When findings turn into ever-rarer edge cases like that, write down the check's scope and stop.
6. Add the fix to the PR body and to the plan's review-fix table (§2).
7. Don't resolve threads: the owner does.

A 🔵 review with no open issues that only asks for browser or device checks needs no code change. 10 of #28's 11 reviews were like that. Do the browser checks yourself (§6), and list the owner's device checks in the PR body.

**No review?** A push that changes no files in the PR, such as a merge of `main` after a squash, starts none. When the PR needs one, request it: `gh pr edit <n> --add-reviewer @copilot`.

## 9. Watching a PR after each push

After each push to a PR, once your replies are posted, run:

```bash
tools/agent/watch_pr.sh <n>    # polls every 60 s, for up to 15 min
```

It first prints the feedback posted since the head commit. Then it prints each new review, inline comment and PR comment as it arrives, and stops one poll after Copilot's review of the head commit. The summary gives the review's verdict and the checks. `--minutes 0` prints the current state and exits; `--minutes`, `--interval` (at least 10 s) and `--repo` change the defaults.

In Copilot CLI and the cloud agent, run it with the bash tool and a long wait, such as `initial_wait: 600`. If the tool returns before the script ends, the script keeps running: read the rest with `read_bash`, after the completion notice or with a `delay` of a few minutes. Don't poll with `sleep`. If you have other work meanwhile, such as Web checks or negative cases (§2), start the script in async mode instead, and read it when you're told that it has ended.

| Exit | Meaning | Do |
|---|---|---|
| 0 | Copilot reviewed the head commit, nothing new needs an answer, and no check failed but Copilot's own (`copilot-pull-request-reviewer`, §8). Or the PR is closed, even if feedback came with that | If the summary shows checks still running, `gh pr checks <n> --watch --required`. Then the PR waits for the owner. Once it's closed there's nothing to push: read any feedback printed above, which may ask for a follow-up |
| 2 | Feedback that needs an answer, printed above the summary: any new review but a clean 🟢 one, and any new comment, the owner's too. Or, if you started late, Copilot's review of the head that isn't clean and has no thread reply or post by anyone but Copilot after it | Handle it (§8), push, reply, and watch again. If the last line says someone pushed, pull first |
| 3 | No Copilot review of the head commit in 15 minutes | Look for a setup-failure comment from Copilot, then `gh pr edit <n> --add-reviewer @copilot` and watch once more. If there's still none, tell the owner in a PR comment |
| 4 | The head moved, so someone pushed, and nothing new needs an answer | Pull, then watch again |
| 5 | A check other than Copilot's own failed (named in the summary) | §10, then watch again |
| 1 | Bad arguments, or `gh` failed 3 times in a row, while starting, polling or reading the checks | Check `gh auth status` and try again |

- The script can't tell your posts from others'. Replies made with `gh` post as the account `gh` is logged in as: #2–#28's 35 thread replies came from the owner's, `pompomon`. The cloud agent's own replies post as `Copilot`, the same login as Copilot's inline comments (#1, #17). Post your replies first; anything new after that came from someone else.
- Repeat the cycle (push, watch, handle) until it exits 0. Each run waits at most 15 minutes: when a review doesn't come, follow exit 3 rather than waiting longer.
- If you answer a review without a push (declines only, or a 🔵 review that needs no code change), Copilot won't review again, so there's nothing to wait for. Post your answers; a later run counts a review as answered once a thread reply, or a post by anyone but Copilot, follows it.

## 10. CI

`ci.yml` runs on every pull request (no branch filter), on pushes to `main` and by hand. The jobs are `lint`, `test`, `export-web`, and `export-android` for the APK and the AAB; these five are the required checks of ruleset "Test". `test` also fails if the checks changed the tree (`git status --porcelain`, M5 L28). `deploy-web` publishes to GitHub Pages and runs only on `main`. A run takes about 4–6 minutes: `lint` under 20 s, `test` 1–2 min, each export 1–3 min. `release.yml` runs for `v*.*.*` tags or by hand.

When a check fails:
- Read the log: `gh run view <run-id> --log-failed`. `gh pr checks <n>` gives the run's URL.
- Known flakes. Re-run the failed jobs with `gh run rerun <run-id> --failed`:
  - GUT's daily update check gets a 403 from GitHub's API rate limit in an editor run, and the scripts reject its `ERROR: [GUT] Could not get version info`. Don't patch `addons/gut/`.
  - A download from GitHub times out.
- Anything else is a real failure. Reproduce it locally (§4), fix it, and add a test.

## 11. Owner-only actions

Only the owner (@pompomon):
- merges PRs (squash, in stack order) and deletes branches;
- changes rulesets, secrets, the release keystore and Pages settings;
- runs device checks on the Galaxy Z Fold4;
- answers the Q#s;
- resolves review threads.

Agents push to their own branches and open PRs; reply to reviews; re-run CI; build artifacts; and request Copilot reviews. Prepare the owner's actions so that they take one step: exact commands, links and the expected results.
