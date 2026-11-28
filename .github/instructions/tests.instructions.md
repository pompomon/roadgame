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
- Test what ships: the real `main.tscn`, its signals and calls, and the values the code issues, recorded where it issues them, not a stand-in or a value computed apart from the call. PF's internal reviews (#124) found 12 tests or measurements of a stand-in, and its PRs fixed 4 more: `test_frame_counter.gd` drives the real main's counter, `test_lamps.gd` reads the visibility and draw index recorded with each RenderingServer call, which has no getter for them, `tools/perf/test_gate.mjs` an actual 30 fps cadence rather than the cap's value, and `test_stretch_switch.gd` the root of `main.tscn`.
- For an optimization that skips work, test the work skipped, not only the final value. `test_an_update_sets_no_frame_before_the_next_starts` sets frames by hand so a redundant write fails: check initialization, newly shown props, moving and stopped clocks, clocks separated by a night, and a small step late in the run (docs/HEADLIGHTS.md B12, §5.6).
- For a fade or ramp, check intermediate values in both directions, with enough frame resolution to reject the timing difference under test. The headlights check their material's gain halfway; the sails use 30 frames a second and check each second of both ramps (docs/HEADLIGHTS.md Q2, Q8, §5.6).
