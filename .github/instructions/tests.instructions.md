---
applyTo: "tests/**"
---

# Tests

- GUT 9.7.1 tests live in `tests/unit/`, `tests/sim/` and `tests/integration/`, with fixtures in `tests/helpers/`. Every gameplay `RefCounted` has its `tests/unit/test_<name>.gd` (IP §1.3).
- Step the simulation with a fixed `delta` of 1/60 s. A clock that adds up such steps can end a frame late, so a test that bounds a time allows one `DELTA` per clock (`test_disasters.gd`, docs/M3.md P10).
- GUT fails a test on any engine error or unexpected `push_error()`. A test that causes one on purpose expects it with `assert_push_error()` or `assert_engine_error()`. `run_tests.sh` also fails on any `ERROR:` line and on leaks, such as a lambda that uses `self` connected to a signal of an object that `self` holds (docs/M2.md H16).
- The tutorial: until the save says it's done, Play starts a run with the tutorial. A test that presses Play for a run without it marks it done first, in a save in memory: `SaveService.use_memory()`, then `SaveService.complete_tutorial()`, as `test_title.gd` does (docs/TUTORIAL.md §5.6).
- While you work, run just the scripts you change: `tools/ci/run_tests.sh -gselect=test_hud` takes 2 s (docs/agents/checks.md §1). Run the whole suite before each push.
- Every fix gets a test, and a negative case: the temporary change that undoes the fix must make the test fail (docs/agents/planning.md §4).
