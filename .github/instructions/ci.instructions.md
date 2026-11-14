---
applyTo: ".github/**,tools/ci/**,tools/agent/**,project.godot,export_presets.cfg"
---

# CI, scripts and versions

- The scripts in `tools/ci/` are what CI runs, and they run the same way locally (AGENTS.md §3). They fail on any `ERROR:` line. `lint.sh` runs gdlint, gdformat, the RNG rule (IP §5.3), shellcheck on `tools/ci/` and `tools/agent/`, `check_versions.sh` and `check_actions_storage.sh`. CI's `lint` job runs actionlint too.
- **Versions.** Godot 4.7.2 is pinned by the godot-ci image's tag in the workflows and by `GODOT_VERSION` in `copilot-setup-steps.yml`, and `project.godot`'s `config/features` starts with "4.7". `check_versions.sh` checks that they agree; a version bump follows IP §7.1. It reads every tag of the image under `.github/`, these instruction files included, so write the image's name there only with its pinned tag, as the workflows do.
- **Actions storage.** No Actions caches, and artifacts are kept 1 day (docs/M0.md F34). `check_actions_storage.sh` enforces it.
- **The tree.** The `test` job fails if the checks changed the tree (`git status --porcelain`): commit each file just as Godot writes it (docs/M5.md L28).
- **Builds.** CI uploads them only from a run started by hand with `upload-builds` (docs/agents/checks.md §4). `deploy-web` runs only on `main`, and `release.yml` for `v*.*.*` tags or by hand.
- **Flakes.** Re-run a failed job when GUT's daily update check hits GitHub's rate limit or a download times out (docs/agents/review.md §4). Never patch `addons/gut/`.
