# Running and checking the game

What AGENTS.md §3 leaves out: setting up the checks (§1), seeing the game on the desktop (§2), where to check what (§3), and the builds for the Web and Android (§4).

## 1. The checks

- **Godot 4.7.2.** For the cloud agent, `copilot-setup-steps.yml` installs it as `/usr/local/bin/godot`, checked against its SHA-512. Elsewhere, install it the same way, or run the CI image in Docker: `docker run --rm -v "$PWD":/w -w /w barichello/godot-ci:4.7.2 bash -c "tools/ci/import.sh && tools/ci/check_scripts.sh && tools/ci/run_tests.sh && tools/ci/smoke.sh"`.
- **pip** refuses to install into the system Python on Debian and Ubuntu (PEP 668), hence the virtual environment in AGENTS.md §3. `tools/ci/requirements.txt` pins gdtoolkit 4.5.0, for Python 3.12.
- **shellcheck.** `lint.sh` only warns if it's missing. The plans were verified with shellcheck 0.11.0 and actionlint 1.7.12; CI's `lint` job runs actionlint too.
- **Results.** Reports go to `build/reports/`. The PR gets the counts (AGENTS.md §3).
- **Time**, on 2 CPUs: `lint.sh` 9 s, `import.sh` 14 s, `check_scripts.sh` 2 s, `run_tests.sh` 75–110 s, `smoke.sh` 1 s. A CI run started by hand takes 5–6 minutes for the same results.
- **Fewer tests.** `run_tests.sh` takes only GUT's options that choose tests, `-gselect=`, `-gtest=`, `-gdir=`, `-ginner_class=` and `-gunit_test_name=`, so its checks for errors, leaks and the save still apply. `-gselect=test_hud` runs each script whose file name contains `test_hud`, in 2 s. `-gdir= -gtest=res://tests/unit/test_hud.gd,res://tests/integration/test_crash.gd` runs just those two: `-gtest` alone adds them to the whole suite.
- **Side by side.** Two whole suites in two worktrees took 77 s each on 2 CPUs, as long as one alone, so run one worktree per CPU (`nproc`). Each needs its own import: `git worktree add --detach /tmp/n1 HEAD && (cd /tmp/n1 && tools/ci/import.sh)`. Remove it after with `git worktree remove /tmp/n1`.
- **Editor warnings.** No check reports GDScript warnings, so a plan's §6.3 compares them on `main` and on the branch in one of two ways. Put a temporary `override.cfg` in the project root that raises each `debug/gdscript/warnings/*` setting at level 1 (warn) to 2 (error), run `check_scripts.sh`, then delete the file (#61). Or start the language server, `godot --headless --editor --lsp-port <port>`, and open every `.gd` outside `addons/` and `.godot/` (docs/M2.md §6.3).

## 2. Seeing the game

No game code checks the platform. Only debug builds add extras, the title's area choice and the game-over seed, and only some platforms send the notifications for focus, pause and Back (docs/M2.md H4, docs/M5.md L10, L13). So a desktop run plays as the builds do, except for the Web's limits (AGENTS.md §2) and what only the Fold4 has (§3). It also takes the user arguments that the builds don't: `--play`, `--autopilot`, `--seed=<int>`, `--area=<id>` and `--tutorial` (`ui/main.gd`:7–13). Under Xvfb (package `xvfb`), Movie Maker writes each frame as a PNG for you to look at, and the sound as a WAV:

```bash
rm -rf /tmp/movie && mkdir -p /tmp/movie/data && XDG_DATA_HOME=/tmp/movie/data xvfb-run -a -s "-screen 0 1280x1024x24" \
  godot --path . --write-movie /tmp/movie/f.png --fixed-fps 60 --quit-after 600 -- --autopilot --seed=12345
```

- That's 10 s of play in 18 s. Each run starts afresh, with a scratch save in `/tmp/movie/data` that keeps yours out of it.
- The frames are always the project's 360×640 (Godot 4.7.2's `main/main.cpp`:4840–4855). With another `--resolution`, they show its middle, cut to that shape and scaled. For the Fold4's sizes (docs/M2.md §6.5), save the viewport's image from a probe script, as docs/M1.md §6.3 did.
- Without Movie Maker, add `--audio-driver Dummy`, or Godot prints an `ERR_CANT_OPEN` error (docs/M1.md G16).

## 3. Where to check what

Check each thing where it's quickest to check faithfully. Leave the owner only what needs the Fold4, in one list in the PR body, and mention @pompomon when the owner must act. Post results as a table in a PR comment, one row per check.

| What | Where | Who |
|---|---|---|
| Rules, numbers, layouts at a given size, the font's glyphs | GUT, headless (AGENTS.md §3) | Agent |
| How the game looks, sounds and plays | A desktop run, with Movie Maker's frames (§2) | Agent |
| What only the Web does: WebGL errors (AGENTS.md §2), the canvas's blur (docs/M2.md H4), sound, which some browsers start only after a gesture, the save in IndexedDB (docs/M5.md L11), touch in the browser | The Web build in Chrome and Firefox (§4) | Agent |
| What only Android or the Fold4 does: Back (docs/M5.md L13), leaving and resuming the app, both screens and folding, the frame rate on its GPU, haptics, how touch feels | The debug APK on the Fold4 | Owner |

**No Android emulator.** The Web and desktop runs play the same game as the APK (§2), and an emulator can't stand in for the Fold4. The APK holds only ARM code (`export_presets.cfg`:32–35), which an x86_64 emulator must translate, and without `/dev/kvm` it isn't accelerated either. Nor has it the Fold4's GPU, its two screens or haptics.

## 4. Builds

CI uploads builds only from a run started by hand, and keeps them 1 day. Start one only when you have something to check in it, and reuse it while nothing reaches it. The exports leave out `tests/`, `addons/gut/` and Markdown, so a build is current if `git diff --name-only <built> HEAD -- . ':!tests' ':!addons/gut' ':!*.md'` prints nothing. They leave out `tools/` too (`export_presets.cfg`), but `tools/ci/export.sh` makes them, so the check keeps it.

```bash
gh workflow run ci.yml -R pompomon/roadgame --ref <branch> -f upload-builds=true   # Web and Android artifacts, kept 1 day
rm -rf /tmp/roadgame-web /tmp/roadgame-apk                                        # gh won't overwrite an earlier download
gh run download <run-id> -R pompomon/roadgame -n web -D /tmp/roadgame-web
gh run download <run-id> -R pompomon/roadgame -n "android-Android APK" -D /tmp/roadgame-apk
adb install -r /tmp/roadgame-apk/roadgame-debug.apk                               # the owner, as #28 gave it
```

In debug builds, the title's Start button chooses the area that Play starts in, so a device can check each area without `--area` (docs/ZONE_SELECT.md).

**The Web build** is a release build, without the debug extras. It takes no arguments until you patch its `index.html` (docs/M4.md PR 3 step 3); then `?arg=` passes them:

```bash
sed -i 's/"args":\[\]/"args":["--"].concat(new URLSearchParams(location.search).getAll("arg"))/' /tmp/roadgame-web/index.html
python3 -m http.server -d /tmp/roadgame-web 8000   # http://localhost:8000/?arg=--play&arg=--seed=12345
```

- Drive Chrome and Firefox with Playwright, headed under Xvfb (#28): headless Chrome ran `requestAnimationFrame` at 1 Hz. If Firefox is missing, install Playwright's, with the version of Playwright that drives it: `npx -y playwright@<version> install --with-deps firefox` took 47 s. Without a sound device, Firefox's audio clock stands still, so give it a PulseAudio null sink to check sound (docs/M5.md P12).
- They draw in software, so their frame rate depends on the browser and the page's size: on 2 CPUs, Chrome drew 49 fps at 360×640 and 21 at 1280×720, and Firefox 59 and 55. Judge the frame rate only on the Fold4. Chrome's `GPU stall due to ReadPixels` notes, and an early `CONTEXT_LOST_WEBGL`, come from software GL too (docs/M4.md §6.6).
- With touch emulation on, Chrome takes touches of several fingers over the DevTools protocol (#23).
- Playwright keeps its pages focused, so a blur needs a browser without it, such as Chrome driven over the DevTools protocol, with real X input from `xdotool` under a window manager (#28, #33).
- The owner can play the same copy in the Fold4's Chrome, with arguments: `adb reverse tcp:8000 tcp:8000`, then the same address (docs/M4.md Q6).
