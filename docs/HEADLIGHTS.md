# Headlights, Resting Windmills and the Meadows' Grass

Done, 2026-11-20 to 2026-11-21: plan #117, then #119, #120 and #121. The owner approved Q1-Q12's defaults. Full plan/verification: `git show 312885f:HEADLIGHTS_PLAN.md`. Prototype archive: section 7.

## 1. Goal and exit criteria

Visual only: no gameplay/audio reads `DayCycle`. Browsers passed; unrecorded Fold4 checks stay in IP, with FPS measurement waived (section 7).

- **E1.** Night from 18:30 inclusive to 06:00 exclusive, wrapped exactly.
- **E2.** Fade on/off in 0.5 s, morning hold, and off when the run ends or clock/car is missing.
- **E3.** Give back at most the chosen share, never brighter than day; zero gain by day or off.
- **E4.** Cone at the lamps, 2.5 tiles long, dimming from 1 tile, correct through headings and transforms.
- **E5.** Road-only material and changed pixels; no darker pixel; City and Rural day frames unchanged.
- **E6.** Gameplay, audio and the smoke outcome unchanged.
- **E7.** Windmill rest/start ramps of 3 s; night starts still, other props go on, no clock means no rest.
- **E8.** Correct frames without redundant work; released pier props stop animating.
- **E9.** Swaying grass at 0.05, last in the picker, preserving other props.
- **E10.** Other visuals unchanged; frame-work optimization changes no frame.
- **E11.** Update about 2x baseline at most, render differences below run variation, GUT alone within 7%; Fold4 reading waived.
- **E12.** Visuals, pause/resume and folding without flicker/errors; browsers passed, unrecorded device checks in IP.
- **E13.** Summary, citations, related docs, guidelines and M7 notes.
- **E14.** Local/CI checks passed; negative cases failed only named tests; no new editor warning.

## 2. Findings

- **B1.** DN chose no headlights. `Headlights`, the road's material, gives back light taken by the veil.
- **B2.** No shared night definition. `night_at()` uses dusk, 18.5, and sunrise, 6.
- **B3.** Light2D or an unmasked ADD cone would light props too. Use the road's material below the veil.
- **B4.** Later opaque car, props, skids, shadows, legends and set-piece walls hide the lit road; faded buildings show it through themselves. Ground stays unlit.
- **B5.** Props turned all night by one clock. `rests_at_night` selects a clock that slows to zero.
- **B6.** No meadow grass. Six blades sway through four frames.
- **B7.** Switching off at a morning reset dimmed then brightened the cone. Hold already-on lights until the target light arrives.
- **B8.** Bright road texels clip before the veil: dimmer and bluer than intended. Q6 accepts this for a visible cone.
- **B9.** Light rules and DN Q5 forbade it. The plan amended the rules; this summary notes the exception.
- **B10.** Arrival holds dusk, a night hour. `is_over()` overrides the night and hold so lights fade out.
- **B11.** GUT cannot see rendered pixels. CPU cone and uniform tests need desktop/browser pixel checks too.
- **B12.** Grass raised animated props from about 33 to 650 and frame work from 94 to 616 us. Deadlines reduced it to 184 us, without changing frames. Tests must detect redundant work too (section 5.6).
- **B13.** Car coordinates are tiles, shader coordinates canvas pixels. Aim through World and the inverse projection.
- **B14.** Grass inserted earlier would move other props' hash bands. Append it to take only formerly empty lots.
- **B15.** Shallow `Resource.duplicate()` shares arrays. Editing the copied City's props corrupted the cached City and failed a later lamp test in CI; give the copy a new array, not `assign()` into the shared one.
- **B16.** Pier removal must erase all row lists, including `resting`, before pooled sprites can be reused; surviving props keep animating.
- **B17.** Polygon2D redraws raise WebGL errors in 4.7.2. Change only shader parameters, only when different.
- **B18.** Painted headlamps and tail lamps darken with the car; no new glow (Q7).
- **B19.** Tunnel/bridge decks are RoadLayer's. The floor cone is faint, rock stays dark, bridge planks clip.
- **B20.** `_process()` aims after physics. GUT may step again before reading: the test allows `Iso.TILE_H / 4`, 16 px, for a move of at most 5 px.

## 3. Decisions

The owner approved the defaults on #117 and merged it.

- **Q1.** Road tiles alone, including tunnel floor and bridge deck; not ground or objects.
- **Q2.** 18:30-06:00, 0.5 s switching, with the morning hold.
- **Q3.** Off after disaster, crash or arrival.
- **Q4.** Road material below the veil; no extra pass.
- **Q5.** Reach 2.5 tiles, whole to 1; half width 0.07, spread 0.14 a tile, soft from 0.6 of the half width.
- **Q6.** Share 0.6, warm white `(1, 0.92, 0.75)`, accepting clipping; at most 0.0326 avoids it but barely shows.
- **Q7.** No glows for painted lamps.
- **Q8.** Sails slow/start over 3 s from their current phase; night starts still.
- **Q9.** Only windmills rest; traffic lights, smoke, tumbleweed, pond and both grasses go on.
- **Q10.** Six blades, 14 x 9 px, two greens; 4 frames at 3 fps, density 0.05, last in picker; no outline/shadow.
- **Q11.** Plan PR amended Light rules before code review.
- **Q12.** Three code PRs then docs from `main`; agents land the first two, owner the last and docs.

## 4. Work breakdown

- **Plan** (#117): the design and the Light rules.
- **PR 1** (#119, 59c26a0): headlights, shader, night, tuning/tests; built with exact `fmod()` boundaries and live material parameters.
- **PR 2** (#120, 4ea42e5): resting flag/clock, separate animation lists and pier cleanup.
- **PR 3** (#121, 312885f): grass, deadlines/tests and final plan sync; skip resting props while their clock stands.
- **PR 4:** summary, citations, related docs, M7 notes and testing guidelines.

### 4.5 Landing

PRs landed individually into `main`, without a native stack. Verified `-X ours` merges preserved code trees (P12; `docs/agents/stacks.md`). Docs follow #121 to avoid citation conflicts.

## 5. Design

### 5.1 The night and the switch

`night_at()` takes `h = fmod(p_hour, 24.0)` and returns `h >= DUSK_HOUR - shift or h < SUN_RISE_HOUR - shift`, with `shift` 24 for a negative remainder, 0 otherwise. Previous-day boundaries, -5.5 and -18, avoid rounding caused by adding 24 or subtracting dusk before wrapping. Tests include adjacent representable values, negative and large hours.

`Headlights.update(cycle, sim, to_canvas, delta)` requires clock, car and a run not over. On at night, or while `level > 0` and shown light differs from target; off otherwise. `level` moves toward 1 or 0 by `delta / HEADLIGHT_SWITCH_SECONDS`, and gain scales with it. Braking/off-road driving continue; disaster/crash/arrival fade out.

### 5.2 The cone

Shader on `RoadLayer` alone: `MODEL_MATRIX` gives canvas vertices; half width is `half_width + spread * max(ahead, 0)`. Smooth dimming from `dim_from * reach` to `reach`, and `edge * width` to each side; nothing behind. RGB multiplies by `1 + gain * lit`.

`aim()` puts `origin` at the lamps, 0.16 tile ahead, through World and `Iso.tile_to_world()`. World's inverse global transform and `Iso.world_to_tile()` give `along`/`across`, mapping canvas offsets into tiles. Later opaque drawing hides the lit road (B4).

`shown()` reads live parameters; `_show()` avoids unchanged writes; `lit()` checks the CPU cone. Tests compare compiled uniforms' names/types; P1 checks pixels.

### 5.3 The light given back

For each channel where the veil's shown light `kept` is between 0 and 1:

`gain = level * HEADLIGHT_SHARE * HEADLIGHT_COLOR[channel] * (1 - kept) / kept`

A channel kept whole or blacked out gets zero. Unclipped colour `c` shows `c * (kept + level * HEADLIGHT_SHARE * HEADLIGHT_COLOR[channel] * (1 - kept))`, never more than by day. At night this is about `(0.77, 0.77, 0.85)` of day colour.

The canvas clips before the veil: at night, channels over `(139.5, 159.6, 217)` of 255. ROAD/BRIDGE lines and planks, 11.25% of opaque texels, show dimmer and bluer than intended, by up to 80 levels a channel; TUNNEL clips none. DEAD_END clips most but is only a debug view. Lines still brighten, never beyond day colour.

At most 0.0326 share clips nothing in a run at any light, limited by the Desert's red 244, but lifts night red only from 0.42 to 0.44. Q6 accepts clipping. An ADD pass above the veil masked to the road could avoid the cap; an unmasked glow lights props too.

### 5.4 Into a zone's morning, and the set pieces

Zones restart at 07:00; light follows at `LIGHT_MAX_RATE`, 0.25 a second per channel, about 2.3 s from night. Already-on lights hold; those off stay off. White reset never dims the cone; gain reaches zero before fade ends.

`--hour` sets every zone's start. Tinted resets in 06:00-07:00 or 17:00-18:30 can dim the fading cone, as sunrise can. Painted lamps stay under the veil; tunnel floor lights faintly, rock stays dark, bridge deck lights.

### 5.5 The windmills' rest

`rests_at_night` defaults false; validation rejects a one-frame resting prop. `RESTS` writes it only for windmill. World supplies its zone clock.

`_clock` adds `delta`; rest rate targets 0 at night, 1 otherwise, moving by `delta / PROP_REST_SECONDS` (3 s). `_rest_clock` adds `delta * _rest_rate`. `bind()` sets rate -1; first update takes the shown hour's rate, after any initial physics steps. Night starts still; no clock means no rest.

Rows separate `animated`/`resting` and initialize frames by the selected clock. After night sails restart from their stopped phase. Pier cleanup erases every list for released props; survivors turn.

### 5.6 The grass and its cost

Six blades 2 px apart, heights `[4, 7, 5, 8, 6, 4]`, alternating two greens. Tallest tip sways `[0, 1, 2, 1]` px, others proportionally. Frames 14 x 9 px at `(216, 0)` in the Meadows' sheet, foot `(6, 8)`; 4 frames at 3 fps, density 0.05, no outline/shadow.

Last in the picker, grass takes a 0.05-wide band of hashes past other one-cell props, not 5% of empty cells. Only formerly empty lots select it; omit tufts touching road. Other places/phases stay. About 13 tufts show, 22 at most, versus about 650 animated props in rows (P4).

`_set_frame()` computes the frame from clock, fps and phase, and always records the next deadline, even if already in that frame:

`next_frame_at = clock + (floorf(at) + 1 - at) / fps - NEXT_FRAME_EARLY`

`NEXT_FRAME_EARLY`, 1e-6 s, avoids rounding a frame late. Ordinary props update when `_clock` reaches it; resting ones when `_rest_clock` does, only if it actually moved. Compare movement exactly: relative tolerance can mistake a small dawn step an hour in for none. Stopped inside the early margin means no work all night.

Frame-equivalence covers odd deltas/fps. `test_an_update_sets_no_frame_before_the_next_starts` sets frames by hand to detect work avoided: initialization, moving/stopped clocks, a deadline an hour in, offset clocks after night, and newly shown sails at night; all advance when due. Ramp tests use 30 fps to reject a ramp 10% too fast, checking each second in both directions.

### 5.7 The rules and the docs

Light rules allow only the headlights' road material to brighten before Daylight. Light remains visual only. DN Q5 notes headlights (B1-B4); M5 notes rest clocks/deadlines (B5, B12). Code/tests cite this summary.

## 6. Verification

### 6.1 Checks

Historical checks/counts are in the archived plan and PR bodies; implementation heads passed local/CI checks with unchanged smoke outcome.

### 6.2 Negative cases and tests

Guard removal must fail work-avoidance tests, not just preserve frames. Copied resources own edited arrays (B15).

### 6.3 Editor warnings

No new warning; baseline integer-division/unused-variable warnings remain.

### 6.4 Browsers and devices

Chrome/Firefox results: [headlights](https://github.com/pompomon/roadgame/pull/119#issuecomment-7051909165), [windmills](https://github.com/pompomon/roadgame/pull/120#issuecomment-7053497165), [grass](https://github.com/pompomon/roadgame/pull/121#issuecomment-7055067236). No game error/warning; browser/software-GL notes are distinguished. Device status: section 7 and IP.

### 6.5 Measurements

Baseline: 4a50bb2; candidate: prototype, except P9. Godot 4.7.2 Compatibility, 360 x 640 under Xvfb/software GL, not Fold4.

- **P1.** 600 frames each of Rural/City at 22:00: all changed pixels on road, none darker. Mask includes faded buildings.
- **P2.** All 600 City/Rural day frames identical. Meadows without grass: 598 identical, two changed by 1 and 3 pixels from sheet width.
- **P3.** Meadows day CPU/GPU average grew 0.7/0.6 ms, below candidate variation, 1.1/1.4 ms; night City/Rural within baseline variation.
- **P4.** Update: 94.3 us baseline, 615.8 old grass loop, 184.2 optimized (178-193). Headless frame: 192-204 to 306-328 us. Animated props: 619-667, at most 972, versus 32.5-33.7, at most 50. About 900 more World nodes.
- **P5.** Optimizations changed none of 600 Meadows day or Rural dusk frames.
- **P6.** Texel clipping and no-clipping bound: section 5.3.
- **P7.** Without hold, cone red falls 0.768 to 0.545 in 0.5 s then brightens. Smoke seed leaves City at 58-59 s, after dusk.
- **P8.** Prototype merge with SP 98ffdd5: clean, four files (`meadows.tres`, `tuning.gd`, `test_daylight_run.gd`, `test_prop_scatter.gd`), checks passed; later states may differ.
- **P9.** Web grass-only, Meadows seed 1: #121 vs `main` 4ea42e5 after #120 (run 44829534995). Chrome day/night 32.3/24.1 vs 33.6/23.2 fps; Firefox 59.0/59.0 vs 58.8/59.0. No game errors. Chrome both 3.4-4.2 times earlier readings: compare one session.
- **P10.** GUT alternating runs alone: 133.7/140.5 s, +5.1%, within approved 7%. CI varied 125.3-235.3 s; a single run cannot establish a regression.
- **P11.** Tunnel night movie: faint warm floor wedge, dark rock, no error.
- **P12.** Predicted squash conflicts: PR 2's `test_daylight_run.gd`, PR 3's scatter and its test. Verified merges preserved code trees.

## 7. Owner actions

The owner merged #121 and said, ["Skip framerate measurements on Fold4, assume they are good"](https://github.com/pompomon/roadgame/pull/121#issuecomment-7055624813). E11's reading is waived, with no measured number. No separate functional result was posted; IP retains E12 on both screens and through folding.

The owner lands this PR (AGENTS, instructions, index). Then archive the prototype and delete branches, omitting any already deleted:

```bash
git fetch origin hl/prototype && git push origin FETCH_HEAD:refs/tags/archive/hl/prototype
git push origin --delete hl/plan hl/prototype hl/fps hl/1-headlights hl/2-windmills hl/3-grass hl/4-docs
```

## 8. Risks

Accepted clipping, extra grass nodes and tinted resets remain limits. Desktop/browser rates do not predict Fold4 performance. SP changes need new timings and merge checks.

## 9. Notes for later work

IP carries device/interpolation notes. Deferred: lamp glows (B18/Q7), lit ground/props (Q1), masked ADD (B8), other resting props (Q9), ground-tile grass (Q10).
