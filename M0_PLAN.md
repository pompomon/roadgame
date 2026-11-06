# M0 Bootstrap & CI — Detailed Plan

Status: in implementation (four stacked PRs, §4); Q1–Q8 defaults applied · 2026-11-06 · Scope: `IMPLEMENTATION_PLAN.md` (below: **IP**) §3 M0 row, §4 M0.1–M0.4, §7

**Verified, not just reviewed.** Every file in Appendices A and B was run in a scratch copy of the project using the tools below; the run included the negative cases in §6.2.

- Godot 4.7.2-stable (Linux x86_64, SHA-512 checked)
- GUT 9.7.1
- gdtoolkit 4.5.0 on Python 3.12
- shellcheck 0.11.0
- actionlint 1.7.12

Some things could not be run locally: real exports (they need export templates and the Android SDK), the CI container image, Pages and the Copilot agent environment. Each one is verified in the PR that introduces it (§4, §6.3).

**Precedence.** For M0, this document replaces IP §4 M0, §7.2–§7.5 and §7.8–§7.9 wherever they differ. Each difference is marked **Δ** with its finding number (F#, §2). Once this plan is approved, fold the changes back into IP.

Contents:
1. Goal and exit criteria
2. Review findings
3. Decisions and open questions
4. Work breakdown (4 PRs)
5. File specifications
6. Verification
7. Owner actions
8. M0 risks
- Appendix A: project files and scripts
- Appendix B: workflows and the composite action

---

## 1. Goal and exit criteria

Goal (unchanged from IP §3): the empty project boots, all CI jobs are green, the Web build is on Pages and a debug APK artifact can be downloaded.

| # | Exit criterion | Checked by |
|---|---|---|
| E1 | The main scene runs headless for 3600 fixed frames with no error lines | `tools/ci/smoke.sh` (a superset of the M0.1 `--quit-after 10` check) |
| E2 | Every project script loads with D12 static typing enforced | `tools/ci/check_scripts.sh` **Δ F2** |
| E3 | GUT runs at least 2 tests and writes `build/reports/gut-junit.xml`. It fails if a test fails, a test script does not parse, or the project was never imported | `tools/ci/run_tests.sh`; §6.2 N1–N3, N7, N10 |
| E4 | gdlint, gdformat, the determinism rule, shellcheck, actionlint and the version pins all pass | `lint` job |
| E5 | On a PR, all five required checks are green: `lint`, `test`, `export-web`, `export-android (Android APK)`, `export-android (Android AAB)` | PR checks |
| E6 | The artifacts `web`, `android-Android APK` and `android-Android AAB` download. The APK installs on the Galaxy Z Fold4 and shows "Road Roguelike 0.0.0". The Web build runs in desktop Chrome and Firefox | Manual, PR 3 |
| E7 | After a merge to `main`, https://pompomon.github.io/roadgame/ serves the build | Manual, PR 4 |
| E8 | No export contains `addons/gut/`, `tests/` or `tools/` | §6.2 N11, PR 3 step 5 **Δ F13** |
| E9 | `release.yml` passes actionlint. A manual dry run passes `test` and `web-release`, then stops at the missing-secret check | Manual, PR 4 |
| E10 | The Copilot setup workflow is green, and agent sessions have `godot` 4.7.2 and `gdlint` on `PATH` | Actions tab, PR 1 **Δ F16** |

---

## 2. Review findings

The milestone structure and most of IP §7 hold up. The problems are mostly CI guards that report green while something is broken, because Godot and GUT exit 0 after many failures.

- **High:** CI passes while the project is broken, or a pipeline fails the first time it is really used.
- **Medium:** the result is wrong or fragile, or work is blocked.
- **Low:** hygiene or portability.

"Spike" means the problem was reproduced with Godot 4.7.2 in the scratch project.

### High

| # | Finding | Evidence | Fix |
|---|---|---|---|
| F1 | GUT exits 0 when a test script fails to parse. This includes untyped declarations under D12. The tests in that file silently do not run. | Spike N1, N2 | `run_tests.sh` fails on `Parse Error` / `Failed to load script` in the GUT log; also `check_scripts.sh` (F2) |
| F2 | `godot --import` does not compile scripts, so the error grep in IP `import.sh` can never match. Scripts that the main scene never loads are not compiled anywhere in CI. | Spike: a parse error passes import; N5 passes smoke | New `check_scripts.sh` + `check_scripts.gd`: load every project script. Skips `addons/`, `android/`, `build/` and folders with a `.gdignore` |
| F3 | Without an import cache (`.godot/`), GUT prints "…have not been imported…", runs 0 tests and exits 0. | Spike N7 | `run_tests.sh` fails on that message and requires a non-empty JUnit file with `tests` > 0 |
| F4 | The determinism grep (IP §5.3, §7.3) both misses real violations and flags valid code:<br>(a) Under `pipefail`, a missing folder makes `grep … \| grep -v …` exit non-zero even when it prints violations, so the `if` never fires.<br>(b) It misses `randfn`, `seed`, `rand_from_seed`, `shuffle` and `pick_random`.<br>(c) `\b` also matches after a `.`, so a seeded `_rng.randf()` is flagged.<br>(d) The exclusion is applied to the whole `path:line:text`, so a file named `rng_*.gd` is exempt entirely. Comments are flagged. | Spike N6, N6b, N6c; N6d. A fixture `road/rng_ok.gd` was exempted completely | New regex flags only global calls plus `.shuffle(` and `.pick_random(`. It lexes each candidate file as GDScript does, so text in string literals (triple-quoted and backslash-continued ones too) and comments never counts, nor does the name in a `func` declaration (PR 2 reviews: the first versions skipped only full-line comments and whole `func` lines, then missed a call after a triple-quoted string). It checks grep's exit code and scans only folders that exist (§5.5) |
| F5 | No time limits. A `-s` script (GUT, check_scripts) that hits a runtime error before `quit()` never exits, so the job runs until the 6 h default timeout. | Spike N12: `SCRIPT ERROR`, then a hang | `run_godot` (`_common.sh`) wraps every Godot run in `timeout -k 10 <s>`; every job sets `timeout-minutes` |
| F6 | M0.1 gives `project.godot` no `config/version`. `stamp_version.sh` uses `sed`, which silently changes nothing when the key is missing, so releases keep the default version. Also:<br>- `08` is invalid octal in `$((…))`<br>- no input validation (`1.2`, `1.2.3-rc1`)<br>- parts ≥ 1000 break the D9 ordering | Spike N9–N9f | Add `config/version="0.0.0"`. The new `stamp_version.sh` validates `[v]X.Y.Z` (each part 0–999), uses `10#`, fails on a missing key and keeps the file mode |
| F7 | In a container job, `${{ runner.temp }}` expands to the host path, not the container path. `release.yml` decodes the keystore to `$RUNNER_TEMP` but passes Godot `${{ runner.temp }}/release.keystore`, so signed exports fail at M6.4. | actions/runner#2498 | One step sets `GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$RUNNER_TEMP/release.keystore"`, decodes the keystore, exports and removes it with `trap` |
| F29 | GUT fails a test only for errors raised in its body. A `push_error()` or engine error in `before_all`, `before_each`, `after_each` or `after_all` is tracked under `GutUtils.NO_TEST` and never checked, so GUT exits 0 and the JUnit file shows no failure. | PR 2 review; N14 | Post-run hook `tests/gut_post_run.gd` (`post_run_script` in `.gutconfig.json`) sets exit code 1 on unhandled errors outside test bodies. Errors that a hook asserts (`assert_push_error()` and the like) are marked handled and still pass (N14b) |
| F30 | Headless Android exports fail with "ETC2/ASTC texture compression is required for Android export". `rendering/textures/vram_compression/import_etc2_astc` defaults to false, and Godot implies it only on hosts whose preferred texture format is ETC2/ASTC (ARM). The project manager doesn't set it, and the export dialog's fix button needs the GUI, so x86 CI fails before any Gradle step. | PR 3 CI; N15. Godot 4.7.2 source: `platform/android/export/export_plugin.cpp`, `editor/import/resource_importer_texture_settings.cpp` | PR 3 sets `import_etc2_astc=true` in `project.godot`. Every texture is imported Lossless today, so no `.import` file changes |

### Medium

| # | Finding | Evidence | Fix |
|---|---|---|---|
| F8 | gdlint and gdformat fail on a path that doesn't exist. IP `lint.sh` passes 11 folders, most of which only appear in M1–M5, and git cannot commit the empty "folder skeleton" from M0.1. | Spike | `lint.sh` passes only folders that exist. **Δ M0.1:** no empty skeleton; each folder is created with its first file |
| F9 | IP `.gutconfig.json` lists `res://tests/sim/` and `res://tests/integration/`, which only appear in M2 and M3. GUT logs `[GUT ERROR]` for each one and carries on. | Spike N10 | `"dirs": ["res://tests/"]` with `include_subdirs`, so new folders are picked up automatically |
| F10 | Godot exits 0 after runtime errors: `push_error` prints `ERROR:` and a call on null prints `SCRIPT ERROR:`. IP `smoke.sh` scans for both, but IP `import.sh` does not scan for engine `ERROR:` lines such as broken resources. | Spike: both lines printed, exit 0. PR 2 CI: a corrupt image also imports with exit 0 | One regex, `ANY_ERROR_RE` in `_common.sh`, used by import, check_scripts, smoke and export (export since the PR 3 review, N16). `IGNORE_RE` skips one harmless line: the godot-ci image has no fontconfig, so editor runs (`--import`) print `ERROR: Unable to load fontconfig, system font support is disabled.` (found in PR 2 CI) |
| F11 | `godot-env` doesn't install the NDK. The Godot 4.7.2 Gradle build sets `ndkVersion '29.0.14206865'` and strips native libraries with it. The image ships NDK 25.2.9519653, so Gradle either downloads the NDK mid-build or skips stripping. | Godot 4.7.2 source: `platform/android/java/app/config.gradle`, `app/build.gradle` | Add `"ndk;29.0.14206865"` to `sdkmanager --install` |
| F12 | `export.sh` writes its log next to the output (`build/web/index.html.log`), and `ci.yml` publishes that folder to Pages. The release zip excludes `*.log`; the Pages upload doesn't. | IP §7.3, §7.4 | Logs go to `build/reports/export-<preset>.log` and are uploaded only on failure, as `export-log-*` |
| F13 | Exports include GUT, the tests and the tools, because the presets use `export_filter="all_resources"` with no exclusions. | Spike N11: a Web pack without the filter has 510 `addons/gut/` paths and 8 `tests/`/`tools/` paths (1.46 MB). With the filter it has none (6.6 KB) | `exclude_filter="addons/gut/*, tests/*, tools/*"` in every preset |
| F14 | Redefining `ui_accept` in `project.godot` replaces the built-in action and its default events (Enter, Keypad Enter, Space, joypad). Binding A/D by `keycode` puts them on different rows on AZERTY keyboards. | Godot InputMap defaults | Don't override `ui_accept`. Bind `steer_*` and `pause` by `physical_keycode` (§5.1) |
| F15 | gdlint's default `max-public-methods: 20` fails every GUT file with more than 20 tests, because each `test_*` method is public. gdtoolkit 4.5.0 has no inline disable comments. | Spike: a file with 21 tests fails | `.gdlintrc` sets `max-public-methods: 40` |
| F16 | There is no `copilot-setup-steps.yml`. Copilot cloud agent sessions start without Godot or gdtoolkit, so the agent can't run the checks it has to keep green. | — | PR 1 adds it: Godot 4.7.2 from `godotengine/godot-builds` (SHA-512 checked), gdtoolkit, and a project import |
| F17 | Repository settings don't match the plan:<br>- Pages is not enabled, so the first `deploy-web` will fail.<br>- Ruleset "Test" targets `~ALL` with deletion, non-fast-forward, PR and Copilot-review rules. PR branches can't be deleted or force-pushed, and any required checks added there would apply to every branch. | `gh api`: Pages returns 404; ruleset 26672445 | §7 |
| F18 | Godot 4.4+ generates files that must be committed: `*.uid` (script UIDs) and `*.import` (import settings, which are also part of the import cache key). Scripts committed without the executable bit fail in CI with "Permission denied". | Spike: `--import` created `*.gd.uid` and `icon.svg.import` | Commit them; `git add --chmod=+x tools/ci/*.sh`; `.gitattributes` with `* text=auto eol=lf` |
| F19 | Release versions are inconsistent. Tag pushes give `v1.2.3`, but the manual input suggests `0.1.0`, which creates a tag without the `v` that doesn't match `v*.*.*`. Nothing checks the version before the 40-minute Android build starts. | IP §7.5 | The manual input is the tag itself (`v0.1.0`). The first step of `test` validates it |
| F20 | Every Godot job pulls `barichello/godot-ci:4.7.2`, about 2.6 GB compressed. That is 4 pulls per CI run and 3 per release, which costs time and disk and runs into Docker Hub's anonymous pull limits. | Docker Hub tag size | Measure in PR 2 and PR 3; mitigations in §8 (Q6) |
| F31 | The Gradle cache is never saved. In container jobs `$HOME` is `/github/home`, but Java takes `user.home` from `/etc/passwd` (`/root`). Gradle therefore uses `/root/.gradle`, the cache step finds no `~/.gradle`, and `actions/cache` only warns: "Path(s) specified in the action for caching do(es) not exist". | PR 3 CI (AAB job of #8). In the image with `HOME=/github/home`, `java -XshowSettings:properties` prints `user.home = /root` | `godot-env`'s Android step sets `GRADLE_USER_HOME=$HOME/.gradle`, so Gradle and the cache step in `ci.yml` and `release.yml` use the same folder |
| F32 | A manual release with a tag that already exists publishes the wrong build. The run builds and tests the selected branch, but `gh release create` attaches the files to the existing tag; `--target` only applies when it creates the tag. Running `v0.1.0` again from a newer `main` would ship newer code as `v0.1.0`. | PR 4 review (#10); IP §7.5 has the same `publish` step | A manual run first looks the tag up with `git ls-remote --exit-code` and fails if it exists, before any build. A failed tag release is retried by re-running its own run. `actions/checkout` trusts the container's workspace only in a temporary config, so the step adds `safe.directory` itself (N19) |

### Low

| # | Finding | Fix |
|---|---|---|
| F21 | Python 3.13: gdtoolkit 4.5.0 declares support only up to 3.10. 3.12 is verified. The gdtoolkit version pin appears in several places. | Use Python 3.12. Pin gdtoolkit in `tools/ci/requirements.txt`, shared by CI, the agent and developers (it is also the pip cache key) |
| F22 | Workflows and shell scripts are not linted. | `lint` runs actionlint 1.7.12, which also shellchecks `run:` blocks. `lint.sh` runs `shellcheck -x tools/ci/*.sh`, which needs `# shellcheck source=` directives (present) |
| F23 | The import cache key uses `runner.os`, which is always Linux. After a Godot bump, `restore-keys` can restore the old version's cache. | Key on `GODOT_TEMPLATE_VERSION` |
| F24 | IP `check_versions.sh` exits silently when no tag is found (`set -e` with `pipefail` inside `$(…)`). It scans only `.github/workflows/`, accepts tags such as `4.7` or `4.7.2.1`, truncates `4.7.2-rc1` or `4.7.2${{ matrix.suffix }}` to `4.7.2`, skips `latest`, and ignores the agent setup. | Rewritten (spike N8, N8b). It compares complete tags, including any `$` or `{}` part (PR 2 reviews, N8c) |
| F25 | `build/` is not `.gdignore`d, so the editor imports exported files such as `build/web/index.png`, and a later export packs them. | Commit `build/.gdignore` (`.gitignore`: `/build/*` plus `!/build/.gdignore`); `_common.sh` recreates it |
| F26 | The only export check is "the output file is non-empty". | Web exports must also have `.js`, `.wasm` and `.pck` files. APK/AAB must contain an `arm64-v8a` `.so`: `grep -qE '(^\|/)lib/arm64-v8a/[^/]+\.so$'` over the `unzip -Z1` names (one per line), read from a here-string because `unzip \| grep -q` can fail with SIGPIPE under `pipefail`. The first version ran a `case` glob over the whole `unzip -l` text, where `*` also matches newlines (PR 3 review, N17) |
| F27 | `release.yml` has no `defaults.run.shell: bash`, so inline steps run without `pipefail`. Its `test` job skips the script-loading check, three jobs have no `timeout-minutes`, and scripts use `${{ … }}` where env vars exist. It is otherwise actionlint-clean. | Fixed in Appendix B |
| F28 | The scripts assume GNU tools (`sed -i -E`), bash 4, and `godot` on `PATH`. | Bash 3.2 and BSD tools (macOS), no `sed -i`, `timeout` or `gtimeout`, and a `GODOT=/path/to/godot` override. Not run on macOS |
| F33 | The first PR 4 version checks (`stamp_version.sh` and the release's "Validate version") used `grep -E '^…$'`, which matches line by line. A version followed by a newline (`$'v1.2.3\n'`, possible through the API) passed, and `stamp_version.sh` wrote two-line values. | Match the whole string with bash `[[ $v =~ $re ]]` (PR 4 review, N18) |

---

## 3. Decisions and open questions

This plan applies the defaults below. Tell me if you want any of them changed.

| # | Question | Default (applied) | Alternative |
|---|---|---|---|
| Q1 | Build the AAB (Gradle and NDK) on every PR? | Yes, as a required check: it catches Gradle breakage early | Build the AAB only on `main` and for releases. The AAB is probably the slowest check (Gradle, NDK), so PRs would wait less |
| Q2 | Who implements PRs 2–4? | Either the Copilot cloud agent or a person. PR 1 lands first, because the setup steps only apply from the default branch | — |
| Q3 | Keep the scripts portable to macOS (bash 3.2)? | Yes; it costs little | Linux only |
| Q4 | Land `release.yml` in M0, although the signing secrets only arrive in M6.4? | Yes: actionlint and a dry run now, the full run in M6.4 | Move it to M6.4 |
| Q5 | Retarget ruleset "Test" from `~ALL` to `~DEFAULT_BRANCH`? | Yes (owner action, §7) | Keep `~ALL` and never add required checks to it |
| Q6 | Run the `test` job in the container image? | Yes, for parity with the exports. If the pull takes more than 2 min, switch to a direct Godot download as in `copilot-setup-steps.yml` | — |
| Q7 | Should `deploy-web` wait for the Android exports? | Yes: Pages only shows builds where every export passed | `needs: export-web` only, for faster Pages updates |
| Q8 | Fold these changes into IP? | After review. Until then, this document wins for M0 | — |

---

## 4. Work breakdown

There are four PRs, and each one leaves CI green. The total estimate is about 2.75–3.25 days, which fits IP's size "M" because the appendix files are already verified. Most of the remaining risk is in PR 3, since Gradle and the NDK can't be tested locally.

```
PR 1 agent env ──▶ PR 2 skeleton + GUT + lint/test CI ──▶ PR 3 exports ──▶ PR 4 Pages + release
 (new M0.5)         (M0.1, M0.2, part of M0.4)             (M0.3, M0.4)     (rest of M0.4)
 ~0.25 d            ~1 d                                    ~1 d             ~0.5–1 d
```

### PR 1: Copilot agent environment (new M0.5) **Δ F16**

**Files:** `.github/workflows/copilot-setup-steps.yml`, `tools/ci/requirements.txt`.

1. Add both files from the appendices.
2. Push. The workflow runs on the PR (it has a path filter) and logs `4.7.2.stable.official.…`. It skips the import because there is no `project.godot` yet.
3. Merge, then run the workflow once from the Actions tab on `main`.

**Acceptance:** E10.

### PR 2: Skeleton, test harness, lint and test CI (M0.1, M0.2, part of M0.4)

| Area | Files |
|---|---|
| Project | `project.godot` (§5.1), `icon.svg` (Godot's default) plus `icon.svg.import`, `ui/main.tscn`, `ui/main.gd` and `.uid` |
| Repo hygiene | `.gitignore`, `.gitattributes`, `build/.gdignore` (§5.2) |
| Tests | `addons/gut/` (GUT 9.7.1), `.gutconfig.json`, `tests/unit/test_smoke.gd` and `tests/gut_post_run.gd` (F29), each with its `.uid` |
| Lint | `.gdlintrc` |
| CI scripts | `tools/ci/_common.sh`, `import.sh`, `check_scripts.sh`, `check_scripts.gd` and `.uid`, `run_tests.sh`, `smoke.sh`, `lint.sh`, `check_versions.sh` |
| CI | `.github/actions/godot-env/action.yml` without the `android` input and step; `.github/workflows/ci.yml` with only the `lint` and `test` jobs |

1. Add `project.godot` and `icon.svg`.
   **Δ F8:** create no empty folders. In M0 only `ui/`, `tests/unit/`, `tools/ci/` and `addons/gut/` exist.
2. Vendor GUT: from the release at https://github.com/bitwes/Gut/releases/tag/v9.7.1, copy only `addons/gut/` (keep its `.uid` files).
3. Add these files:
   - `ui/main.*`
   - `tests/unit/test_smoke.gd` and `tests/gut_post_run.gd`
   - `.gutconfig.json`
   - `.gdlintrc`
   - `.gitignore`, `.gitattributes`, `build/.gdignore`
4. Add the scripts and commit them as executable: `git add --chmod=+x tools/ci/*.sh`.
5. Run `tools/ci/import.sh`. Commit the generated `*.uid` files and `icon.svg.import` (F18); `.godot/` stays ignored.
6. Run the checks in §6.1, plus at least negative cases N1, N3, N5 and N7 from §6.2.
7. Add `godot-env` and `ci.yml` (scope as in the table above).
8. Push and check:
   - `lint` and `test` are green.
   - The `test-reports` artifact contains `gut-junit.xml` with `tests="2"`.
   - Note how long "Initialize containers" took in the PR description (Q6, F20).
9. After the merge, the owner adds the `lint` and `test` required checks (§7).

**Acceptance:** E1–E4.

### PR 3: Export presets and export jobs (M0.3, part of M0.4)

**Files:**
- `export_presets.cfg`
- `tools/ci/export.sh`
- `project.godot`: add `import_etc2_astc=true` (F30)
- `godot-env`: add the `android` input and the SDK/NDK step, which also sets `GRADLE_USER_HOME` (F31)
- `ci.yml`: add `export-web` and `export-android` (without the Pages steps)

1. Add `export_presets.cfg`. The Appendix A version contains only the key options, and Godot uses defaults for the rest; this was verified with `--export-pack`. Optionally, open Project → Export once in the 4.7.2 editor and save, which writes every default explicitly; keep the §5.4 options, including `exclude_filter`.
2. Add `export.sh` (executable), the Android step in `godot-env`, and the export jobs.
3. Push and check:
   - All three export checks are green.
   - The `web`, `android-Android APK` and `android-Android AAB` artifacts exist.
   - Note the durations of the NDK install and the Gradle build.
   - The AAB job's "Post Cache Gradle" step saves `gradle-godot-<version>`, and a re-run restores it (F31).
4. Manual checks (E6):
   - **Android:** run `adb install -r roadgame-debug.apk`. The app opens, shows "Road Roguelike 0.0.0" and follows the sensor orientation.
   - **Web:** unzip `web`, serve it with `python3 -m http.server -d <dir> 8000`, and open it in Chrome and Firefox.
5. Check the export contents (E8):
   ```bash
   unzip -l roadgame-debug.apk | grep -cE 'assets/(addons/gut|tests|tools)/'   # expect 0
   unzip -l roadgame-debug.aab | grep -cE 'assets/(addons/gut|tests|tools)/'   # expect 0
   strings index.pck | grep -cE 'res://(tests|tools)/'                       # expect 0
   strings index.pck | grep -c 'addons/gut/'   # expect ≤ 1: the editor_plugins entry in project.binary
   ```
6. After the merge, the owner adds the three export required checks (§7).

**Acceptance:** E5, E6, E8.

### PR 4: Pages, release pipeline, Dependabot (rest of M0.4)

**Prerequisite:** the owner has enabled Pages (§7).

**Files:**
- `ci.yml`: add the "Upload Pages artifact" step to `export-web`, and the `deploy-web` job
- `.github/workflows/release.yml`
- `tools/ci/stamp_version.sh`
- `.github/dependabot.yml`

1. Add the files. `lint` must be green; actionlint checks `release.yml`.
2. Test the version stamp locally:
   - Run `tools/ci/stamp_version.sh v1.2.3`, then `git diff`.
   - Expect `config/version="1.2.3"`, and in both Android presets `version/name="1.2.3"` and `version/code=1002003`.
   - Revert with `git checkout -- project.godot export_presets.cfg`.
   - `tools/ci/stamp_version.sh $'v1.2.3\n'` must fail and change nothing (N18).
3. Merge. The run on `main` deploys the site (E7).
4. Do a release dry run (E9): Actions → Release → Run workflow with version `v0.0.1`. Expected:
   - `test` passes, including "Check that the tag is new" (F32).
   - `web-release` passes and produces `roadgame-v0.0.1-web.zip`.
   - `android-release` fails at "Check signing secrets".
   - `publish` is skipped, and no tag or release is created.
5. Check that Dependabot version updates are listed under Insights → Dependency graph → Dependabot.

**Acceptance:** E7 and E9. The full release (signed APK and AAB on a GitHub Release) is verified in M6.4, once the secrets exist.

---

## 5. File specifications

Full contents are in Appendix A and Appendix B. This section lists only what differs from IP, and why.

### 5.1 `project.godot`

All M0.1 settings are unchanged. Additions:

- **Δ F6:** `application/config/version="0.0.0"`. The main scene label shows it, and `stamp_version.sh` overwrites it.
- **Δ F14:** input actions bound by physical key, with deadzone 0.2. `ui_accept` stays at the built-in default.
- `[editor_plugins] enabled=PackedStringArray("res://addons/gut/plugin.cfg")`.
- **Δ F30 (PR 3):** `rendering/textures/vram_compression/import_etc2_astc=true`. Android export requires it.

| Action | Physical keys | `physical_keycode` |
|---|---|---|
| `steer_left` | ←, A | 4194319, 65 |
| `steer_right` | →, D | 4194321, 68 |
| `pause` | Esc, P | 4194305, 80 |

To create these, use Project Settings → Input Map and pick "Physical Keycode", or paste the `[input]` block from Appendix A.

### 5.2 Repository hygiene (Δ F18, F25)

`.gitignore`:
```gitignore
.godot/
/android/
/build/*
!/build/.gdignore
*.tmp
```

Other files:
- `.gitattributes`: `* text=auto eol=lf`.
- `build/.gdignore`: an empty file, committed.

Commit `*.uid`, `*.import` and `addons/gut/**`. Never commit `.godot/`, `android/`, build outputs or keystores.

### 5.3 `.gdlintrc` and `.gutconfig.json`

**`.gdlintrc` Δ F15:** `excluded_directories` (`.git`, `.godot`, `addons`, `android`, `build`) and `max-public-methods: 40`. Everything else uses gdtoolkit 4.5.0 defaults. These defaults matter from M1 on:
- `max-line-length: 100`
- `max-file-lines: 1000`
- `function-arguments-number: 10`
- `max-returns: 6`
- `class-definitions-order`: tool, class_name, extends, docstring, signals, enums, consts, static vars, exports, public vars, private vars, onready public vars, onready private vars, others

**`.gutconfig.json` Δ F9, F29:** `"dirs": ["res://tests/"]` and `"post_run_script": "res://tests/gut_post_run.gd"`. All other options are as in IP.

### 5.4 `export_presets.cfg`

Same as the IP M0.3 table, with these additions:
- **Δ F13:** `exclude_filter="addons/gut/*, tests/*, tools/*"` in every preset.
- Explicit `export_filter="all_resources"`.
- `runnable`: true for Web and APK, false for AAB.
- Export paths: `build/web/index.html`, `build/android/roadgame-debug.apk` and `build/android/roadgame-debug.aab`. CI passes explicit output paths anyway.
- Still no keystore paths or passwords.

### 5.5 `tools/ci/` scripts

Every script sources `_common.sh`, which does the following:
- sets `set -euo pipefail`
- moves to the repository root, so a script works from any working directory
- uses `$GODOT` if set (default `godot`)
- writes logs to `build/reports/`
- provides `run_godot <seconds> <log> <args…>`: a time limit, a log copy and Godot's exit code
- provides `fail_on <regex> <log> <message>`, which skips lines that match `IGNORE_RE`
- defines the error regexes: `SCRIPT_ERROR_RE`, `ANY_ERROR_RE` = `^(SCRIPT |USER )?ERROR:|Parse Error|Failed to load script`, and `IGNORE_RE` for known-harmless lines (whole-line match; today only the missing-fontconfig message)

| Script | Time limit | Fails when | Δ |
|---|---|---|---|
| `import.sh` | 900 s | Godot exits non-zero, or the log has any error line | F10 |
| `check_scripts.sh` + `check_scripts.gd` | 300 s | Any error line, or the "loaded N scripts" line is missing | new, F2 |
| `run_tests.sh` | 900 s | A parse or load error, "have not been imported" or `[GUT ERROR]` appears; GUT exits non-zero, which includes an unhandled error in a setup or teardown hook; the JUnit file is missing; 0 tests ran | F1, F3, F9, F29 |
| `smoke.sh` | 300 s | Godot exits non-zero, or the log has any error line | F10 |
| `lint.sh` | — | gdlint, gdformat, the determinism rule, shellcheck or `check_versions.sh` fails | F4, F8, F22 |
| `check_versions.sh` | — | The complete godot-ci tags differ or aren't `x.y.z` (`4.7.2-rc1`, `latest` and `4.7.2${{ matrix.suffix }}` fail); the minor version ≠ `config/features`; the agent's `GODOT_VERSION` differs | F24 |
| `export.sh` | 900 s; 1800 s for AAB | Godot exits non-zero, or the log has any error line; no output file; a Web export missing `.js`, `.wasm` or `.pck`; an APK or AAB with no `arm64-v8a` `.so` | F10, F12, F26 |
| `stamp_version.sh` | — | The version is invalid (the whole string is checked), or a key is missing | F6, F33 |

**Determinism rule (IP §5.3, Δ F4).** It covers `autoload road world car disasters areas setpieces` (scope unchanged).

- **Flagged:**
  - the global functions `randf`, `randi`, `randfn`, `randf_range`, `randi_range`, `randomize`, `seed` and `rand_from_seed`, when they are not called on an object
  - any `.shuffle(` or `.pick_random(`, because they use the global RNG
- **Allowed:** calls on a seeded `RandomNumberGenerator` such as `_rng.randf()` or `road_rng.randi_range(0, 3)`, any text in string literals and comments, and the name in a `func` declaration. A one-line `func` body is still checked. Strings are recognised the way GDScript lexes them, including triple-quoted strings and strings that continue on the next line.
- **Conventions for M1+:**
  - Don't name your own methods `seed`, `randf` and so on: a bare call to them would be flagged.
  - Shuffle with a Fisher–Yates helper that takes the stream's `RandomNumberGenerator`.

### 5.6 `.github/actions/godot-env/action.yml`

- **Δ F11:** adds `"ndk;29.0.14206865"` to the SDK install.
- **Δ F23:** the cache key is `godot-import-<GODOT_TEMPLATE_VERSION>-<hash>`.
- The `android` input and the Android step arrive in PR 3.
- **Δ F31 (PR 3):** the Android step sets `GRADLE_USER_HOME=$HOME/.gradle`, the folder the Gradle cache saves.

### 5.7 `.github/workflows/ci.yml`

Changes from IP §7.4:
- `defaults.run.shell: bash` adds `pipefail` to inline steps.
- **F5:** every job has `timeout-minutes`.
- `lint`:
  - **F21:** Python 3.12, with the pip cache keyed on `tools/ci/requirements.txt`.
  - **F22:** runs actionlint 1.7.12.
- `test`: **F2:** a new "Load every script" step runs before GUT.
- Export jobs: **F12:** on failure, `build/reports` is uploaded as `export-log-web` or `export-log-<apk|aab>`; the matrix gains a `slug`.

Job and check names are unchanged.

### 5.8 `.github/workflows/release.yml`

Changes from IP §7.5:
- **F19:** the manual input is the tag (for example `v0.1.0`) and is validated first.
- **F33:** that check matches the whole string, so a version with a newline fails.
- **F32:** a manual run fails in `test` if the tag already exists, because `gh release create` would attach the new build to it.
- **F2:** `test` runs `check_scripts.sh`.
- **F7:** the keystore path comes from `$RUNNER_TEMP`, and decode, export and `trap` cleanup happen in one step.
- **F27:** `defaults.run.shell: bash`, timeouts on every job, env vars instead of `${{ … }}` in scripts, and the `gh` arguments built as an array.
- **F12:** the zip no longer needs `-x '*.log'`.

### 5.9 `.github/workflows/copilot-setup-steps.yml` (new, F16)

- The job must be named `copilot-setup-steps`.
- Only `steps`, `permissions`, `runs-on`, `services`, `snapshot` and `timeout-minutes` (at most 59) are honoured, so `GODOT_VERSION` is a step-level env var.
- It installs Python 3.12 with gdtoolkit, and Godot 4.7.2 into `/usr/local/bin/godot`. The Godot zip is the official one from `godotengine/godot-builds`, checked against `SHA512-SUMS.txt`.
- It imports the project when `project.godot` exists.
- It installs no export templates or Android SDK (over 1 GB). Exports are verified in CI, not in agent sessions.
- It runs on PRs that change it, but the agent only uses the copy on `main`.

### 5.10 Version bump procedure (Δ IP §7.1)

Make all of these changes in one PR:
- `barichello/godot-ci:<x.y.z>` in every workflow
- `GODOT_VERSION` in `copilot-setup-steps.yml`
- `config/features` in `project.godot`
- the SDK and NDK versions in `godot-env`, taken from the new release's `platform/android/java/app/config.gradle`
- re-vendor GUT and bump gdtoolkit in `tools/ci/requirements.txt`, if needed

`check_versions.sh` enforces the first three.

### 5.11 `.github/dependabot.yml`

Unchanged: GitHub Actions, weekly.

---

## 6. Verification

### 6.1 Local checks (Linux; written for macOS too)

```bash
pip install -r tools/ci/requirements.txt    # gdtoolkit 4.5.0, Python 3.12
export GODOT=/path/to/godot-4.7.2           # optional; the default is godot on PATH
tools/ci/lint.sh             # → Godot 4.7.2 is pinned consistently
tools/ci/import.sh
tools/ci/check_scripts.sh    # → check_scripts: loaded 4 scripts
tools/ci/run_tests.sh        # → GUT: 2 tests passed
tools/ci/smoke.sh
```

Parity with the CI image (Δ: adds `check_scripts.sh`):
`docker run --rm -v "$PWD":/w -w /w barichello/godot-ci:4.7.2 bash -c "tools/ci/import.sh && tools/ci/check_scripts.sh && tools/ci/run_tests.sh && tools/ci/smoke.sh"`

### 6.2 Negative cases

For each case, make the temporary change, run the script, then revert. Every "Expected" result was reproduced with Godot 4.7.2: N1–N12 in the spike; N6d, N8c, N13 and N14 (and the extended N6c) while implementing PR 2; N15–N17 while implementing PR 3; N18 and N19 while implementing PR 4.

| # | Temporary change | Expected | With the IP scripts |
|---|---|---|---|
| N1 | A syntax error in `tests/unit/test_smoke.gd` | `run_tests.sh` and `check_scripts.sh` fail | GUT exits 0 (F1) |
| N2 | `var x = 1` (untyped) in a test | Both fail | GUT exits 0 (F1) |
| N3 | `assert_eq(1, 2)` in a test | `run_tests.sh` exits 1 | Fails ✓ |
| N4 | `push_error("x")` in `ui/main.gd` `_ready()` | `smoke.sh` fails | Fails ✓ |
| N4b | A method call on `null` in `_ready()` | `smoke.sh` fails | Fails ✓ |
| N5 | A parse error in `road/broken.gd`, which no scene uses | `check_scripts.sh` fails (`smoke.sh` passes) | Passes (F2) |
| N6 | A bare `randf()` in `road/x.gd` | `lint.sh` fails | Passes while any gameplay folder is missing (F4) |
| N6b | `a.shuffle()` in `road/` | `lint.sh` fails | Passes (F4) |
| N6c | `_rng.randf()`, `road_rng.randi_range(0, 3)`, `func seed(…)`, full-line and trailing comments (`_rng.randf()  # replaces randf()`) and strings (`"#ff0000"`, `"call randf()"`, `&"randf()"`, `"""randi() # x"""`, prose that mentions `randi()` inside a multi-line `"""…"""` string) | `lint.sh` passes | Flags `_rng.randf()`, the comments and the strings (F4) |
| N6d | Real calls next to a comment or string: `randi_range(0, 3)  # uses the global RNG`, `"#fff" + str(randi())`, `"""note " # x""" + str(randi())`, a call after a multi-line string closes | `lint.sh` fails | Same as N6 |
| N7 | `rm -rf .godot`, then `run_tests.sh` | Fails ("have not been imported") | Exits 0 after 0 tests (F3) |
| N8 | One workflow uses `godot-ci:4.7.1` | `check_versions.sh` fails | Fails ✓ |
| N8b | `GODOT_VERSION: "4.7.1"` in the agent setup | `check_versions.sh` fails | Not checked |
| N8c | One workflow uses `godot-ci:4.7.2-rc1`, `godot-ci:latest` or `godot-ci:4.7.2${{ matrix.suffix }}` | `check_versions.sh` fails (mismatched tags, or not `x.y.z`) | Passes: `4.7.2-rc1` and `4.7.2${{ … }}` are truncated to `4.7.2`, and `latest` is skipped (F24) |
| N9 | `stamp_version.sh v1.2.3` | `config/version="1.2.3"`; presets get `1.2.3` and `1002003` | `config/version` is not written (F6) |
| N9b | `stamp_version.sh 0.08.009` | `version/code=8009` | Arithmetic error (`08` is invalid octal) |
| N9c–f | `1.2`, `1.2.3-rc1`, `1.1000.0`, a missing key | `stamp_version.sh` fails | Shell errors, or silently wrong (`1.1000.0` gets the same code as `2.0.0`; a missing key is ignored) |
| N10 | `.gutconfig.json` with the IP `dirs` | `run_tests.sh` fails (`[GUT ERROR]`) | Exits 0 (F9) |
| N11 | `godot --headless --path . --export-pack "Web" build/t.pck` | With `exclude_filter`: 0 `tests/`/`tools/` paths. Without: 510 GUT and 8 test/tool paths | — (F13) |
| N12 | A `-s` script with a runtime error before `quit()` | `run_godot` stops it: exit 124, "did not finish within" | Hangs until the job timeout (F5) |
| N13 | A corrupt `bad.png` in the project (run without fontconfig, like the CI image) | `import.sh` fails on `ERROR: Error importing 'res://bad.png'`; the fontconfig lines are ignored | Passes: Godot exits 0 and only script errors are scanned (F10) |
| N14 | `push_error("x")` in a test's `before_each()`; likewise `before_all`, `after_each`, `after_all` or an engine error there | `run_tests.sh` fails: "Unexpected errors outside test bodies", GUT exit 1 | Passes: GUT exits 0 (F29) |
| N14b | `before_all()` calls `push_error("x")`, then `assert_push_error("x")` | `run_tests.sh` passes | Passes ✓ |
| N14c | `tests/gut_post_run.gd` is deleted | `run_tests.sh` fails, but only at the 900 s limit: GUT logs `[GUT ERROR]` and aborts the run without quitting | — |
| N15 | `import_etc2_astc=true` removed from `project.godot`; export in the CI image | `export.sh "Android APK" …` fails: "ETC2/ASTC texture compression is required for Android export". With the line, the APK exports | — (F30) |
| N16 | After `import.sh`, add a corrupt `bad.png`; then `export.sh "Web" build/web/index.html release` | Fails on `ERROR: Error importing 'res://bad.png'` | Passes: Godot exits 0 and writes every file (F10; PR 3 review) |
| N17 | Run `export.sh "Android APK" build/android/t.apk debug` with a fake `GODOT` that copies in an APK holding only `lib/arm64-v8a/readme.txt` and `lib/armeabi-v7a/libgodot_android.so` | Fails: "contains no arm64-v8a native library" | Passes: only the file size is checked. The first PR 3 check passed it too, because its `case` glob matched across lines (F26; PR 3 review) |
| N18 | `stamp_version.sh $'v1.2.3\n'`, and `$'v1.2.3\nx'` | Fails: "must be MAJOR.MINOR.PATCH"; `project.godot` and `export_presets.cfg` are unchanged | Fails with the `sed` error ``unterminated `s' command``: there is no version check. The first PR 4 check passed both and wrote two-line values (F33; PR 4 review) |
| N19 | Run "Check that the tag is new" in the CI image as Actions does (root, `HOME=/github/home`, `bash --noprofile --norc -eo pipefail`), in a workspace owned by another user whose `origin` is a local bare repo with tag `v0.0.1` | `v0.0.1` fails: "Tag v0.0.1 already exists"; `v0.0.2` passes; an unreachable `origin` fails (exit code 128). Without the `safe.directory` line, git ignores the workspace, cannot resolve `origin` and the step fails | The run builds the selected ref, and `publish` attaches it to the old tag (F32; PR 4 review) |

### 6.3 Verified only in CI

| Check | PR |
|---|---|
| The agent setup on a GitHub runner | 1 |
| Image pull time; `godot-env` moving templates and settings; the import cache | 2 |
| Web, APK and AAB exports with templates; SDK and NDK install; the Gradle cache; artifact contents | 3 |
| Pages deploy; the release dry run | 4 |

---

## 7. Owner actions

Agents can't change repository settings. The current state was read with `gh api` on 2026-11-06.

| When | Action | How |
|---|---|---|
| Before PR 1 (recommended) | Change ruleset "Test" (id 26672445) to target `~DEFAULT_BRANCH` instead of `~ALL` | Settings → Rules → Rulesets → Test → Target branches. Today its four rules apply to every branch, so PR branches can't be deleted after a merge or force-pushed |
| After PR 2 merges | Require the `lint` and `test` status checks | In the same ruleset: "Require status checks to pass", source GitHub Actions. Adding a check before its job exists blocks every PR |
| After PR 3 merges | Also require `export-web`, `export-android (Android APK)` and `export-android (Android AAB)` | Same place |
| Before PR 4 merges | Enable Pages, with GitHub Actions as the source | `gh api -X POST repos/pompomon/roadgame/pages -f build_type=workflow` |
| Optional | Give environment `release` a required reviewer | Settings → Environments |
| M6.4 | Add `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_ALIAS` and `ANDROID_KEYSTORE_PASSWORD` to environment `release` | IP §7.6 (unchanged) |
| Only if image pulls are rate-limited (F20) | Create a read-only Docker Hub token and use it for `container.credentials` | §8 |

---

## 8. M0 risks

| Risk | Impact | Mitigation |
|---|---|---|
| Image pulls: about 2.6 GB × 4 per run, plus Docker Hub's anonymous pull limits | Slow or red CI | Measure in PRs 2 and 3. If a pull takes more than 2 min, run `test` on the plain runner with the direct Godot download (it needs no templates). Otherwise use `container.credentials`, or mirror the image to GHCR |
| Runner disk: the image, NDK 29 and Gradle | The AAB job fails with "No space left on device" | Print `df -h` in PR 3. Remove unused SDK packages or preinstalled runner tools if needed |
| NDK 29 is downloaded on every AAB run | Each AAB job takes 1–3 min longer | If it takes more than 2 min, cache `$ANDROID_HOME/ndk/29.0.14206865` with `actions/cache`, keyed on the NDK version |
| Gradle's first-run downloads; flaky network | A red AAB check | The Gradle cache, `fail-fast: false` and re-runs. If it keeps happening, take the Q1 alternative |
| gdformat can produce indentation that Godot rejects after multi-line lambda bodies (Scony/godot-gdscript-toolkit#424, open) | `lint` and Godot disagree | Prefer named functions to multi-line lambdas inside call arguments; `check_scripts.sh` catches the result. `@abstract` works with gdtoolkit 4.5.0 (verified) |
| Godot prints errors but exits 0 | CI is green while broken | Every script scans its log (§5.5). Re-run §6.2 whenever `tools/ci/` changes |
| The agent firewall blocks downloads during sessions | The agent can't fetch templates or images | The setup steps install everything needed for lint, import, tests and smoke; exports are left to CI |

---

## Appendix A: project files and scripts

These are copied verbatim from the verified scratch project. Each file notes the PR that adds it. `icon.svg` is Godot's default icon. The `*.uid` and `*.import` files are generated by `tools/ci/import.sh`.

### `project.godot`

_Added in PR 2. PR 3 adds `import_etc2_astc` (F30)._

```ini
; Engine configuration file.
config_version=5

[application]

config/name="Road Roguelike"
config/version="0.0.0"
run/main_scene="res://ui/main.tscn"
config/features=PackedStringArray("4.7", "GL Compatibility")
config/icon="res://icon.svg"

[debug]

gdscript/warnings/untyped_declaration=2

[display]

window/size/viewport_width=360
window/size/viewport_height=640
window/size/resizable=true
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"
window/stretch/scale_mode="integer"
window/handheld/orientation=6

[editor_plugins]

enabled=PackedStringArray("res://addons/gut/plugin.cfg")

[input]

steer_left={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":16,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194319,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
, Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":16,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":65,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
steer_right={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":16,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194321,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
, Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":16,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":68,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
pause={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":16,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194305,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
, Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":16,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":80,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}

[rendering]

renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
textures/canvas_textures/default_texture_filter=0
textures/vram_compression/import_etc2_astc=true
2d/snap/snap_2d_transforms_to_pixel=true
```

### `.gdlintrc`

_Added in PR 2._

```yaml
# gdtoolkit 4.5.0. Options not listed here use the gdlint defaults (gdlint --dump-default-config).
excluded_directories: !!set
  .git: null
  .godot: null
  addons: null
  android: null
  build: null
# GUT test scripts have one public method per test (default limit: 20).
max-public-methods: 40
```

### `.gutconfig.json`

_Added in PR 2._

```json
{
  "dirs": ["res://tests/"],
  "include_subdirs": true,
  "prefix": "test_",
  "suffix": ".gd",
  "log_level": 1,
  "should_exit": true,
  "should_exit_on_success": true,
  "post_run_script": "res://tests/gut_post_run.gd"
}
```

### `ui/main.gd`

_Added in PR 2._

```gdscript
extends Control
## M0 placeholder main scene. Shows the build version so artifacts are easy to identify.

@onready var _label: Label = %Label


func _ready() -> void:
	var version: String = ProjectSettings.get_setting("application/config/version", "dev")
	_label.text = "Road Roguelike %s" % version
```

### `ui/main.tscn`

_Added in PR 2._

```ini
[gd_scene format=3]

[ext_resource type="Script" path="res://ui/main.gd" id="1_main"]

[node name="Main" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("1_main")

[node name="Label" type="Label" parent="."]
unique_name_in_owner = true
layout_mode = 1
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
grow_horizontal = 2
grow_vertical = 2
text = "Road Roguelike"
horizontal_alignment = 1
```

### `tests/unit/test_smoke.gd`

_Added in PR 2._

```gdscript
extends GutTest


func test_project_name() -> void:
	assert_eq(ProjectSettings.get_setting("application/config/name"), "Road Roguelike")


func test_main_scene_shows_version() -> void:
	var scene: PackedScene = load("res://ui/main.tscn")
	var main: Control = scene.instantiate()
	add_child_autofree(main)
	var label: Label = main.get_node("%Label")
	assert_string_contains(label.text, "Road Roguelike")
```

### `tests/gut_post_run.gd`

_Added in PR 2 (F29)._

```gdscript
extends GutHookScript
## GUT post-run hook (post_run_script in .gutconfig.json). GUT fails a test only for errors raised
## in its body. Errors from before_all, before_each, after_each and after_all are tracked under
## GutUtils.NO_TEST and would leave the run green, so this hook fails the run on them. Errors that
## a hook asserts (assert_push_error() and the like) are marked handled and do not count.


func run() -> void:
	var tracker: GutErrorTracker = gut.error_tracker
	if tracker.should_test_fail_from_errors(GutUtils.NO_TEST):
		gut.logger.failed(
			str(
				"Unexpected errors outside test bodies (before_all, before_each, after_each",
				" or after_all):\n",
				tracker.get_fail_text_for_errors(GutUtils.NO_TEST)
			)
		)
		set_exit_code(1)
```

### `tools/ci/requirements.txt`

_Added in PR 1._

```text
gdtoolkit==4.5.0
```

### `tools/ci/_common.sh`

_Added in PR 2._

```bash
#!/usr/bin/env bash
# Shared setup for tools/ci/*.sh: source it, do not run it. Works with bash 3.2+ (macOS) and
# GNU or BSD tools. Use another Godot binary with GODOT=/path/to/godot.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.."

GODOT="${GODOT:-godot}"
REPORTS="build/reports"
mkdir -p "$REPORTS"
# Stop the editor from importing build outputs (index.png, ...) into the project.
[ -f build/.gdignore ] || : > build/.gdignore

# A GDScript file failed to parse or load (warnings set to "error" are reported the same way).
SCRIPT_ERROR_RE='Parse Error|Failed to load script'
# Any engine or script error. Godot exits 0 after most runtime errors, so logs must be scanned.
# shellcheck disable=SC2034 # used by the scripts that source this file
ANY_ERROR_RE="^(SCRIPT |USER )?ERROR:|$SCRIPT_ERROR_RE"
# Known harmless error lines, never counted by fail_on (whole-line match). The godot-ci image has
# no fontconfig, so editor runs (--import) cannot look up system fonts; the project uses none.
IGNORE_RE='ERROR: Unable to load fontconfig, system font support is disabled\.'

TIMEOUT_BIN=""
if command -v timeout > /dev/null 2>&1; then
  TIMEOUT_BIN="timeout"
elif command -v gtimeout > /dev/null 2>&1; then
  TIMEOUT_BIN="gtimeout"
else
  echo "warning: no 'timeout' command (macOS: brew install coreutils); Godot runs have no time limit" >&2
fi

# run_godot <seconds> <log> <godot args...>
# Runs Godot with a time limit (a -s script that hits an error before quit() never exits),
# copies its output to <log> and returns Godot's exit code (124 = timed out).
run_godot() {
  local secs="$1" log="$2" rc=0
  shift 2
  if [ -n "$TIMEOUT_BIN" ]; then
    "$TIMEOUT_BIN" -k 10 "$secs" "$GODOT" "$@" 2>&1 | tee "$log" || rc=$?
  else
    "$GODOT" "$@" 2>&1 | tee "$log" || rc=$?
  fi
  [ "$rc" -ne 124 ] || echo "::error::Godot did not finish within ${secs}s (see $log)"
  return "$rc"
}

# fail_on <regex> <log> <message>: print the matching lines and fail if <log> matches <regex>.
# Lines that match IGNORE_RE are skipped.
fail_on() {
  local hits rc=0
  hits=$(grep -nE "$1" "$2") || rc=$?
  [ "$rc" -le 1 ] || { echo "::error::Could not read $2"; return 1; }
  hits=$(printf '%s\n' "$hits" | grep -vE "^[0-9]+:($IGNORE_RE)\$") || true
  [ -n "$hits" ] || return 0
  printf '%s\n' "$hits"
  echo "::error::$3 (see $2)"
  return 1
}
```

### `tools/ci/import.sh`

_Added in PR 2._

```bash
#!/usr/bin/env bash
# Import all resources so .godot/ (imported assets, global class cache) exists; GUT and exports
# need it. --import does not report GDScript errors; check_scripts.sh covers those.
# shellcheck source=tools/ci/_common.sh
source "$(dirname "$0")/_common.sh"

run_godot 900 "$REPORTS/import.log" --headless --path . --import
fail_on "$ANY_ERROR_RE" "$REPORTS/import.log" "Errors during import"
```

### `tools/ci/check_scripts.sh`

_Added in PR 2._

```bash
#!/usr/bin/env bash
# Load every project GDScript and fail on parse errors, including warnings set to "error"
# (untyped_declaration). Neither --import nor GUT fails on these.
# shellcheck source=tools/ci/_common.sh
source "$(dirname "$0")/_common.sh"

log="$REPORTS/check_scripts.log"
run_godot 300 "$log" --headless --path . -s res://tools/ci/check_scripts.gd
fail_on "$ANY_ERROR_RE" "$log" "GDScript errors"
grep -qE '^check_scripts: loaded [1-9][0-9]* scripts' "$log" \
  || { echo "::error::check_scripts.gd did not finish (see $log)"; exit 1; }
```

### `tools/ci/check_scripts.gd`

_Added in PR 2._

```gdscript
extends SceneTree
## Loads every project script so Godot prints parse errors. Run by check_scripts.sh.

const SKIP_DIRS: Array[String] = ["res://addons", "res://android", "res://build"]


func _initialize() -> void:
	var paths: Array[String] = []
	_collect("res://", paths)
	for path: String in paths:
		if load(path) == null:
			printerr("ERROR: Failed to load script %s" % path)
	print("check_scripts: loaded %d scripts" % paths.size())
	quit()


func _collect(dir: String, out: Array[String]) -> void:
	if dir in SKIP_DIRS or FileAccess.file_exists(dir.path_join(".gdignore")):
		return
	for file: String in DirAccess.get_files_at(dir):
		if file.get_extension() == "gd":
			out.append(dir.path_join(file))
	for sub: String in DirAccess.get_directories_at(dir):
		if not sub.begins_with("."):
			_collect(dir.path_join(sub), out)
```

### `tools/ci/run_tests.sh`

_Added in PR 2._

```bash
#!/usr/bin/env bash
# Run every GUT test and write build/reports/gut-junit.xml. GUT exits 0 when a test script does
# not parse or the project was never imported, so the log and the JUnit total are checked too.
# The post-run hook tests/gut_post_run.gd makes GUT exit 1 on errors in setup/teardown hooks.
# shellcheck source=tools/ci/_common.sh
source "$(dirname "$0")/_common.sh"

log="$REPORTS/gut.log"
junit="$REPORTS/gut-junit.xml"
rm -f "$junit"
rc=0
run_godot 900 "$log" --headless --path . -s res://addons/gut/gut_cmdln.gd \
  -gconfig=res://.gutconfig.json -gjunit_xml_file="$junit" -gexit || rc=$?

fail_on "$SCRIPT_ERROR_RE|have not been imported|\\[GUT ERROR\\]" "$log" "GUT could not load every test"
[ "$rc" -eq 0 ] || { echo "::error::GUT reported failures (exit $rc)"; exit "$rc"; }
[ -s "$junit" ] || { echo "::error::GUT wrote no JUnit report ($junit)"; exit 1; }
total=$(sed -n 's/.*<testsuites[^>]* tests="\([0-9][0-9]*\)".*/\1/p' "$junit" | head -n 1)
[ "${total:-0}" -gt 0 ] || { echo "::error::GUT ran 0 tests"; exit 1; }
echo "GUT: $total tests passed"
```

### `tools/ci/smoke.sh`

_Added in PR 2._

```bash
#!/usr/bin/env bash
# Boot the real main scene for 3600 fixed frames (60 s simulated) and fail on any error.
# The main scene ignores --autopilot until M2.
# shellcheck source=tools/ci/_common.sh
source "$(dirname "$0")/_common.sh"

log="$REPORTS/smoke.log"
run_godot 300 "$log" --headless --path . --fixed-fps 60 --quit-after 3600 -- --autopilot --seed=12345
fail_on "$ANY_ERROR_RE" "$log" "Errors during smoke run"
```

### `tools/ci/lint.sh`

_Added in PR 2._

```bash
#!/usr/bin/env bash
# Style (gdlint, gdformat), the determinism rule (IMPLEMENTATION_PLAN.md §5.3), shell scripts
# and version pins. Needs gdtoolkit (pip install -r tools/ci/requirements.txt), not Godot.
# shellcheck source=tools/ci/_common.sh
source "$(dirname "$0")/_common.sh"

# Only pass directories that exist: gdlint fails on missing paths, and grep exits 2 on them.
gd_dirs=()
for d in autoload road world car disasters areas setpieces ui config tests tools; do
  if [ -d "$d" ]; then gd_dirs+=("$d"); fi
done
[ "${#gd_dirs[@]}" -gt 0 ] || { echo "::error::No GDScript directories found"; exit 1; }
gdlint "${gd_dirs[@]}"
gdformat --check "${gd_dirs[@]}"

# Determinism: gameplay code must use seeded RandomNumberGenerator streams. Flags bare global RNG
# calls (rng.randf() is fine) and Array.shuffle()/pick_random(). Text in string literals and
# comments never counts, nor does the name in a func declaration (its one-line body does).
rng_re='(^|[^.[:alnum:]_])(randf|randi|randfn|randf_range|randi_range|randomize|seed|rand_from_seed)[[:space:]]*\(|\.(shuffle|pick_random)[[:space:]]*\('
gameplay_dirs=()
for d in autoload road world car disasters areas setpieces; do
  if [ -d "$d" ]; then gameplay_dirs+=("$d"); fi
done
if [ "${#gameplay_dirs[@]}" -gt 0 ]; then
  candidates="$REPORTS/rng_candidates.txt"
  hits="$REPORTS/rng_hits.txt"
  rc=0
  grep -rlE --include='*.gd' "$rng_re" "${gameplay_dirs[@]}" > "$candidates" || rc=$?
  [ "$rc" -le 1 ] || { echo "::error::Determinism check could not scan gameplay code"; exit 1; }
  files=()
  while IFS= read -r f; do files+=("$f"); done < "$candidates"
  : > "$hits"
  if [ "${#files[@]}" -gt 0 ]; then
    # Lex each candidate file as GDScript does: a backslash escapes the next character in every
    # string kind, and triple-quoted or backslash-continued strings span lines. String literals
    # become "", comments and declared func names are dropped, and the rest of each line is
    # matched again. \047 is a single quote.
    RNG_RE="$rng_re" awk '
      function str_end(s, d,    i) {
        for (i = 1; i <= length(s); i++) {
          if (substr(s, i, 1) == "\\") i++
          else if (substr(s, i, length(d)) == d) return i + length(d)
        }
        return 0
      }
      FNR == 1 { open = "" }
      {
        rest = $0; code = ""
        while (rest != "") {
          if (open != "") {
            i = str_end(rest, open)
            if (i == 0) break
            code = code "\"\""; rest = substr(rest, i); open = ""
          } else if (match(rest, /[#"\047]/)) {
            code = code substr(rest, 1, RSTART - 1)
            c = substr(rest, RSTART, 1)
            if (c == "#") break
            open = c
            if (substr(rest, RSTART, 3) == c c c) open = c c c
            rest = substr(rest, RSTART + length(open))
          } else {
            code = code rest; rest = ""
          }
        }
        sub(/^[[:space:]]*(static[[:space:]]+)?func[[:space:]]+[[:alnum:]_]+/, "func", code)
        if (code ~ ENVIRON["RNG_RE"]) print FILENAME ":" FNR ":" $0
      }' "${files[@]}" > "$hits"
  fi
  if [ -s "$hits" ]; then
    cat "$hits"
    echo "::error::Global RNG in gameplay code; use a seeded RandomNumberGenerator stream (§5.3)"
    exit 1
  fi
fi

if command -v shellcheck > /dev/null 2>&1; then
  shellcheck -x tools/ci/*.sh
else
  echo "warning: shellcheck not found; shell scripts not checked" >&2
fi

tools/ci/check_versions.sh
```

### `tools/ci/check_versions.sh`

_Added in PR 2._

```bash
#!/usr/bin/env bash
# The Godot version must match everywhere: godot-ci image tags, the Copilot setup workflow and
# project.godot config/features (version bump procedure: IMPLEMENTATION_PLAN.md §7.1).
# shellcheck source=tools/ci/_common.sh
source "$(dirname "$0")/_common.sh"

rc=0
# Capture the complete tag, including any $ and braces, so 4.7.2-rc1, latest or an expression
# such as 4.7.2${{ matrix.suffix }} never passes as 4.7.2.
tags=$(grep -rhoE 'barichello/godot-ci:[-[:alnum:]_.{}$]*' .github | sort -u) || rc=$?
[ "$rc" -le 1 ] || { echo "::error::Could not scan .github/"; exit 1; }
[ -n "$tags" ] || { echo "::error::No barichello/godot-ci image tag under .github/"; exit 1; }
if [ "$(printf '%s\n' "$tags" | wc -l | tr -d ' ')" -ne 1 ]; then
  echo "::error::Mismatched godot-ci image tags:"
  printf '%s\n' "$tags"
  exit 1
fi
version="${tags#*:}"
printf '%s' "$version" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$' \
  || { echo "::error::Pin godot-ci to a full x.y.z tag (found '$version')"; exit 1; }
minor="${version%.*}"
grep -qF "config/features=PackedStringArray(\"$minor\"" project.godot \
  || { echo "::error::project.godot config/features must start with \"$minor\""; exit 1; }
setup=.github/workflows/copilot-setup-steps.yml
if [ -f "$setup" ]; then
  grep -qF "GODOT_VERSION: \"$version\"" "$setup" \
    || { echo "::error::$setup must set GODOT_VERSION: \"$version\""; exit 1; }
fi
echo "Godot $version is pinned consistently"
```

### `export_presets.cfg`

_Added in PR 3._

```ini
[preset.0]

name="Web"
platform="Web"
runnable=true
export_filter="all_resources"
include_filter=""
exclude_filter="addons/gut/*, tests/*, tools/*"
export_path="build/web/index.html"

[preset.0.options]

variant/extensions_support=false
variant/thread_support=false
html/canvas_resize_policy=2
html/focus_canvas_on_start=true
progressive_web_app/enabled=false

[preset.1]

name="Android APK"
platform="Android"
runnable=true
export_filter="all_resources"
include_filter=""
exclude_filter="addons/gut/*, tests/*, tools/*"
export_path="build/android/roadgame-debug.apk"

[preset.1.options]

gradle_build/use_gradle_build=false
architectures/armeabi-v7a=true
architectures/arm64-v8a=true
architectures/x86=false
architectures/x86_64=false
keystore/release=""
version/code=1
version/name="0.0.0"
package/unique_name="com.pompomon.roadgame"
screen/immersive_mode=true
permissions/vibrate=true

[preset.2]

name="Android AAB"
platform="Android"
runnable=false
export_filter="all_resources"
include_filter=""
exclude_filter="addons/gut/*, tests/*, tools/*"
export_path="build/android/roadgame-debug.aab"

[preset.2.options]

gradle_build/use_gradle_build=true
gradle_build/export_format=1
gradle_build/min_sdk=""
gradle_build/target_sdk=""
architectures/armeabi-v7a=true
architectures/arm64-v8a=true
architectures/x86=false
architectures/x86_64=false
keystore/release=""
version/code=1
version/name="0.0.0"
package/unique_name="com.pompomon.roadgame"
screen/immersive_mode=true
permissions/vibrate=true
```

### `tools/ci/export.sh`

_Added in PR 3._

```bash
#!/usr/bin/env bash
# export.sh <preset> <output> [debug|release]: export one preset and sanity-check the result.
# The log goes to build/reports, never next to the output (build/web is published).
# shellcheck source=tools/ci/_common.sh
source "$(dirname "$0")/_common.sh"

usage="usage: export.sh <preset> <output> [debug|release]"
preset="${1:?$usage}"
out="${2:?$usage}"
mode="${3:-release}"
case "$mode" in
  debug | release) ;;
  *) echo "::error::$usage"; exit 1 ;;
esac

slug=$(printf '%s' "$preset" | tr '[:upper:]' '[:lower:]' | tr -c '[:alnum:]' '-')
log="$REPORTS/export-$slug.log"
mkdir -p "$(dirname "$out")"
rm -f "$out"
if [ "$preset" = "Android AAB" ]; then
  # Gradle builds need res://android/build. The first Gradle run downloads its dependencies.
  run_godot 1800 "$log" --headless --path . --install-android-build-template \
    "--export-$mode" "$preset" "$out"
else
  run_godot 900 "$log" --headless --path . "--export-$mode" "$preset" "$out"
fi
fail_on "$ANY_ERROR_RE" "$log" "Errors during export of '$preset'"
[ -s "$out" ] || { echo "::error::Export '$preset' produced no file at $out (see $log)"; exit 1; }

case "$out" in
  *.html)
    for f in "${out%.html}.js" "${out%.html}.wasm" "${out%.html}.pck"; do
      [ -s "$f" ] || { echo "::error::Web export is missing $f"; exit 1; }
    done
    ;;
  *.apk | *.aab)
    # One entry per line, matched line by line. A here-string, because unzip | grep -q can
    # fail with SIGPIPE under pipefail.
    names=$(unzip -Z1 "$out")
    grep -qE '(^|/)lib/arm64-v8a/[^/]+\.so$' <<< "$names" \
      || { echo "::error::$out contains no arm64-v8a native library"; exit 1; }
    ;;
esac
echo "Exported '$preset' to $out"
```

### `tools/ci/stamp_version.sh`

_Added in PR 4._

```bash
#!/usr/bin/env bash
# stamp_version.sh <[v]MAJOR.MINOR.PATCH>: write the version to project.godot
# (application/config/version) and the Android presets (version/name, version/code per D9).
# shellcheck source=tools/ci/_common.sh
source "$(dirname "$0")/_common.sh"

v="${1:?usage: stamp_version.sh <[v]MAJOR.MINOR.PATCH>}"
v="${v#v}"
# A whole-string match: grep matches line by line, so "1.2.3" plus a newline and more would pass.
re='^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$'
[[ $v =~ $re ]] \
  || { echo "::error::Version '$v' must be MAJOR.MINOR.PATCH with each part 0-999 (D9)"; exit 1; }
IFS=. read -r major minor patch <<< "$v"
code=$((10#$major * 1000000 + 10#$minor * 1000 + 10#$patch))
[ "$code" -ge 1 ] || { echo "::error::Android version/code must be at least 1"; exit 1; }

# set_key <file> <key> <value>: replace every "<key>=..." line; fail if there is none.
set_key() {
  local tmp
  grep -q "^$2=" "$1" || { echo "::error::$1 has no '$2=' line"; exit 1; }
  tmp=$(mktemp)
  awk -v k="$2=" -v line="$2=$3" 'index($0, k) == 1 { print line; next } { print }' "$1" > "$tmp"
  cat "$tmp" > "$1"
  rm -f "$tmp"
}

set_key project.godot config/version "\"$v\""
set_key export_presets.cfg version/name "\"$v\""
set_key export_presets.cfg version/code "$code"
echo "Stamped version $v (Android version/code $code)"
```

## Appendix B: workflows and the composite action

These pass actionlint 1.7.12, including its shellcheck integration. The files below are the final M0 state. Earlier PRs add only part of each:

- **`godot-env`:** PR 2 adds it without the `android` input and the "Install Android SDK packages" step; PR 3 adds those.
- **`ci.yml`:** PR 2 has `lint` and `test`. PR 3 adds `export-web` (without "Upload Pages artifact") and `export-android`. PR 4 adds the Pages upload step and `deploy-web`.

### `.github/workflows/copilot-setup-steps.yml`

_Added in PR 1._

```yaml
name: Copilot Setup Steps

# Runs when this file changes so it is validated in PRs. The Copilot cloud agent only uses the
# version on the default branch.
on:
  workflow_dispatch:
  push:
    paths: [.github/workflows/copilot-setup-steps.yml]
  pull_request:
    paths: [.github/workflows/copilot-setup-steps.yml]

jobs:
  # The job must be called copilot-setup-steps. Only steps, permissions, runs-on, services,
  # snapshot and timeout-minutes (max 59) are honoured, so env is set per step.
  copilot-setup-steps:
    runs-on: ubuntu-latest
    timeout-minutes: 20
    permissions:
      contents: read
    steps:
      - uses: actions/checkout@v7
      - uses: actions/setup-python@v7
        with:
          python-version: "3.12"
      - name: Install gdtoolkit
        run: pip install -r tools/ci/requirements.txt
      - name: Install Godot (SHA-512 verified)
        env:
          GODOT_VERSION: "4.7.2"   # keep in sync: tools/ci/check_versions.sh
        run: |
          set -euo pipefail
          zip="Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip"
          url="https://github.com/godotengine/godot-builds/releases/download/${GODOT_VERSION}-stable"
          cd "$RUNNER_TEMP"
          curl -fsSLO "$url/$zip"
          curl -fsSL "$url/SHA512-SUMS.txt" | grep " $zip\$" | sha512sum -c -
          unzip -q "$zip"
          sudo install -m 0755 "${zip%.zip}" /usr/local/bin/godot
          godot --headless --version
      - name: Import project
        run: if [ -f project.godot ]; then tools/ci/import.sh; fi
```

### `.github/actions/godot-env/action.yml`

_Added in PR 2; the `android` input and step in PR 3._

```yaml
name: Godot environment
description: >
  Prepare the barichello/godot-ci container: move export templates and editor settings into
  $HOME, optionally install the Android SDK packages that Godot 4.7's Gradle build needs,
  restore the import cache and import the project.
inputs:
  android:
    description: Install the Android platform, build-tools and NDK for Gradle (AAB) builds and set GRADLE_USER_HOME
    default: "false"
runs:
  using: composite
  steps:
    - name: Relocate templates and editor settings
      shell: bash
      run: |
        set -euo pipefail
        ver="$(godot --version | cut -d. -f1-4)"        # e.g. 4.7.2.stable
        mkdir -p "$HOME/.local/share/godot/export_templates" "$HOME/.config"
        if [ "$HOME" != "/root" ]; then
          mv "/root/.local/share/godot/export_templates/$ver" "$HOME/.local/share/godot/export_templates/$ver"
          mv /root/.config/godot "$HOME/.config/godot"
        fi
        echo "GODOT_TEMPLATE_VERSION=$ver" >> "$GITHUB_ENV"
        godot --version

    - name: Install Android SDK packages
      if: inputs.android == 'true'
      shell: bash
      run: |
        set -euo pipefail
        sdk="${ANDROID_HOME:-/usr/lib/android-sdk}"
        sdkm="$sdk/cmdline-tools/latest/bin/sdkmanager"
        [ -x "$sdkm" ] || sdkm="$(command -v sdkmanager)"
        "$sdkm" --licenses > /dev/null < <(yes)
        # Versions from Godot 4.7.2 platform/android/java/app/config.gradle. Without the NDK,
        # Gradle downloads it during the build or skips stripping the native libraries.
        "$sdkm" --install "platform-tools" "platforms;android-36" "build-tools;36.1.0" "ndk;29.0.14206865" > /dev/null
        # Java takes user.home from /etc/passwd (/root), not $HOME (/github/home in container jobs),
        # so without this Gradle uses /root/.gradle and the workflows' ~/.gradle cache stays empty.
        echo "GRADLE_USER_HOME=$HOME/.gradle" >> "$GITHUB_ENV"

    - name: Restore Godot import cache
      uses: actions/cache@v6
      with:
        path: .godot
        key: godot-import-${{ env.GODOT_TEMPLATE_VERSION }}-${{ hashFiles('project.godot', '**/*.import') }}
        restore-keys: godot-import-${{ env.GODOT_TEMPLATE_VERSION }}-

    - name: Import project
      shell: bash
      run: tools/ci/import.sh
```

### `.github/workflows/ci.yml`

_Built up over PRs 2–4 (see above)._

```yaml
name: CI

on:
  pull_request:
  push:
    branches: [main]
  workflow_dispatch:

concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: ${{ github.event_name == 'pull_request' }}

permissions:
  contents: read

defaults:
  run:
    shell: bash

jobs:
  lint:
    runs-on: ubuntu-24.04
    timeout-minutes: 10
    steps:
      - uses: actions/checkout@v7
      - uses: actions/setup-python@v7
        with:
          python-version: "3.12"
          cache: pip
          cache-dependency-path: tools/ci/requirements.txt
      - run: pip install -r tools/ci/requirements.txt
      - run: tools/ci/lint.sh
      - name: actionlint
        run: |
          bash <(curl -fsSL https://raw.githubusercontent.com/rhysd/actionlint/v1.7.12/scripts/download-actionlint.bash) 1.7.12
          ./actionlint -color

  test:
    runs-on: ubuntu-24.04
    container: barichello/godot-ci:4.7.2   # keep in sync: tools/ci/check_versions.sh
    timeout-minutes: 20
    steps:
      - uses: actions/checkout@v7
      - uses: ./.github/actions/godot-env
      - name: Load every script (parse errors)
        run: tools/ci/check_scripts.sh
      - name: Unit, simulation and integration tests (GUT)
        run: tools/ci/run_tests.sh
      - name: Smoke run (main scene, 60 s simulated)
        run: tools/ci/smoke.sh
      - name: Upload test reports
        if: always()
        uses: actions/upload-artifact@v7
        with:
          name: test-reports
          path: build/reports
          retention-days: 14

  export-web:
    needs: [lint, test]
    runs-on: ubuntu-24.04
    container: barichello/godot-ci:4.7.2
    timeout-minutes: 20
    steps:
      - uses: actions/checkout@v7
      - uses: ./.github/actions/godot-env
      - run: tools/ci/export.sh "Web" build/web/index.html release
      - name: Upload Web build
        uses: actions/upload-artifact@v7
        with:
          name: web
          path: build/web
          if-no-files-found: error
          retention-days: 14
      - name: Upload Pages artifact
        if: github.event_name == 'push' && github.ref == 'refs/heads/main'
        uses: actions/upload-pages-artifact@v5
        with:
          path: build/web
      - name: Upload export log
        if: failure()
        uses: actions/upload-artifact@v7
        with:
          name: export-log-web
          path: build/reports

  export-android:
    needs: [lint, test]
    runs-on: ubuntu-24.04
    container: barichello/godot-ci:4.7.2
    timeout-minutes: 40
    strategy:
      fail-fast: false
      matrix:
        include:
          - preset: Android APK
            file: roadgame-debug.apk
            slug: apk
          - preset: Android AAB
            file: roadgame-debug.aab
            slug: aab
    name: export-android (${{ matrix.preset }})
    steps:
      - uses: actions/checkout@v7
      - uses: ./.github/actions/godot-env
        with:
          android: ${{ matrix.preset == 'Android AAB' }}
      - name: Cache Gradle
        if: matrix.preset == 'Android AAB'
        uses: actions/cache@v6
        with:
          path: |
            ~/.gradle/caches
            ~/.gradle/wrapper
          key: gradle-godot-${{ env.GODOT_TEMPLATE_VERSION }}
      - name: Export (debug keystore from the CI image)
        run: tools/ci/export.sh "${{ matrix.preset }}" "build/android/${{ matrix.file }}" debug
      - uses: actions/upload-artifact@v7
        with:
          name: android-${{ matrix.preset }}
          path: build/android/${{ matrix.file }}
          if-no-files-found: error
          retention-days: 14
      - name: Upload export log
        if: failure()
        uses: actions/upload-artifact@v7
        with:
          name: export-log-${{ matrix.slug }}
          path: build/reports

  deploy-web:
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    needs: [export-web, export-android]
    runs-on: ubuntu-24.04
    timeout-minutes: 10
    permissions:
      pages: write
      id-token: write
    environment:
      name: github-pages
      url: ${{ steps.deploy.outputs.page_url }}
    steps:
      - id: deploy
        uses: actions/deploy-pages@v5
```

### `.github/workflows/release.yml`

_Added in PR 4._

```yaml
name: Release

on:
  push:
    tags: ["v*.*.*"]
  workflow_dispatch:
    inputs:
      version:
        description: "Tag to create, e.g. v0.1.0 (makes a draft release)"
        required: true

concurrency:
  group: release-${{ github.ref }}
  cancel-in-progress: false

permissions:
  contents: read

defaults:
  run:
    shell: bash

env:
  VERSION: ${{ inputs.version || github.ref_name }}

jobs:
  test:
    runs-on: ubuntu-24.04
    container: barichello/godot-ci:4.7.2
    timeout-minutes: 20
    steps:
      - name: Validate version
        run: |
          # A whole-string match: grep matches line by line, so "v1.2.3" plus a newline would pass.
          re='^v[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$'
          [[ $VERSION =~ $re ]] \
            || { echo "::error::Version must look like v1.2.3 (got '$VERSION')"; exit 1; }
      - uses: actions/checkout@v7
      - name: Check that the tag is new
        if: github.event_name == 'workflow_dispatch'
        run: |
          # A manual run builds the selected ref, but gh release create attaches the files to an
          # existing tag as it is (--target only applies to new tags). Retry a failed tag release
          # by re-running its own run.
          # checkout trusts the workspace (safe.directory) only in a temporary config.
          git config --global --add safe.directory "$GITHUB_WORKSPACE"
          rc=0
          git ls-remote --exit-code --tags origin "refs/tags/$VERSION" > /dev/null || rc=$?
          case "$rc" in
            2) ;;
            0) echo "::error::Tag $VERSION already exists. Re-run its Release run, or use a new version"; exit 1 ;;
            *) echo "::error::Could not list the remote tags (git exit code $rc)"; exit 1 ;;
          esac
      - uses: ./.github/actions/godot-env
      - run: tools/ci/check_scripts.sh
      - run: tools/ci/run_tests.sh
      - run: tools/ci/smoke.sh

  android-release:
    needs: test
    runs-on: ubuntu-24.04
    container: barichello/godot-ci:4.7.2
    timeout-minutes: 45
    environment: release
    steps:
      - uses: actions/checkout@v7
      - name: Check signing secrets
        env:
          KS: ${{ secrets.ANDROID_KEYSTORE_BASE64 }}
        run: '[ -n "$KS" ] || { echo "::error::ANDROID_KEYSTORE_BASE64 is not set"; exit 1; }'
      - run: tools/ci/stamp_version.sh "$VERSION"
      - uses: ./.github/actions/godot-env
        with:
          android: "true"
      - uses: actions/cache@v6
        with:
          path: |
            ~/.gradle/caches
            ~/.gradle/wrapper
          key: gradle-godot-${{ env.GODOT_TEMPLATE_VERSION }}
      - name: Export signed APK and AAB
        env:
          KS: ${{ secrets.ANDROID_KEYSTORE_BASE64 }}
          GODOT_ANDROID_KEYSTORE_RELEASE_USER: ${{ secrets.ANDROID_KEYSTORE_ALIAS }}
          GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD: ${{ secrets.ANDROID_KEYSTORE_PASSWORD }}
        run: |
          # Use $RUNNER_TEMP, not the runner.temp context: in container jobs the context is the
          # host path (actions/runner#2498).
          export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$RUNNER_TEMP/release.keystore"
          trap 'rm -f "$GODOT_ANDROID_KEYSTORE_RELEASE_PATH"' EXIT
          printf '%s' "$KS" | base64 -d > "$GODOT_ANDROID_KEYSTORE_RELEASE_PATH"
          tools/ci/export.sh "Android APK" "build/release/roadgame-$VERSION.apk" release
          tools/ci/export.sh "Android AAB" "build/release/roadgame-$VERSION.aab" release
      - uses: actions/upload-artifact@v7
        with:
          name: android-release
          path: |
            build/release/*.apk
            build/release/*.aab
          if-no-files-found: error

  web-release:
    needs: test
    runs-on: ubuntu-24.04
    container: barichello/godot-ci:4.7.2
    timeout-minutes: 20
    steps:
      - uses: actions/checkout@v7
      - run: tools/ci/stamp_version.sh "$VERSION"
      - uses: ./.github/actions/godot-env
      - run: tools/ci/export.sh "Web" build/web/index.html release
      - run: cd build/web && zip -qr "../roadgame-$VERSION-web.zip" .
      - uses: actions/upload-artifact@v7
        with:
          name: web-release
          path: build/roadgame-*-web.zip
          if-no-files-found: error

  publish:
    needs: [android-release, web-release]
    runs-on: ubuntu-24.04
    timeout-minutes: 10
    permissions:
      contents: write
    steps:
      - uses: actions/download-artifact@v8
        with:
          path: dist
          merge-multiple: true
      - name: Create GitHub Release
        env:
          GH_TOKEN: ${{ github.token }}
        run: |
          args=(--repo "$GITHUB_REPOSITORY" --target "$GITHUB_SHA" --generate-notes)
          if [ "$GITHUB_EVENT_NAME" = "workflow_dispatch" ]; then args+=(--draft); fi
          gh release create "$VERSION" dist/* --title "Road Roguelike $VERSION" "${args[@]}"
```

### `.github/dependabot.yml`

_Added in PR 4._

```yaml
version: 2
updates:
  - package-ecosystem: github-actions
    directory: "/"
    schedule:
      interval: weekly
```
