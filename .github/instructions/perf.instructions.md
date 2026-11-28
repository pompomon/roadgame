---
applyTo: "tools/perf/**,ui/frame_*.gd,tests/unit/test_frame_*.gd"
---

# Measurements

The IDs below are those of docs/PERF.md. PF's plan (#124) drew 38 findings on these points in its internal reviews and 3 in Copilot's, and its PR 1 (#126) 3 more. Write new measuring code to this list, with a test for each point.

- **Sums.** Judge a rate by the frames and microseconds summed over whole windows, as `gameRate()` and `FrameStats.fps()` do, never by a mean of the windows' rates or by a rate rebuilt from a rounded figure (`test_measure.mjs`, "game rates use frame counts and actual microseconds, not rounded fps").
- **Rounding.** Round only what is shown, and away from the bound that it is judged by, so that a failure never reads as a pass: `FrameCounter` rounds the rate down below 60 and up above it, and the P95 up (N24).
- **Windows.** Say which frames a window holds, and test each edge: an interval across either edge, which `frameIntervals()` keeps whole; a window begun before the stretch measured, which `perfWindow()` drops, as `measure.mjs` drops its first; equal frame starts, whose zero interval counts (`test_frame_stats.gd`); the frame that closes the window, which a capture waits for (#126); and an empty window, which never passes (`gameRate()` throws).
- **Extremes.** Test each threshold at, just inside and just outside it, and each input at the limits that the tools accept: `test_gate.mjs` runs 540 Hz with whole and exact millisecond timestamps, refresh rates near the gate's boundaries, and jitter.
- **Deadlines.** Every wait on a browser, a page or an event has one: `within()` and `close()` in `browser.mjs`, and `run_godot`'s time limit. Give its test a timeout too, as `test_measure.mjs` does with `{ timeout: 1000 }`, or the negative case without the deadline hangs the runner instead of failing it, as it did for PR 1.
