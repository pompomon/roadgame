# Day and Night: Sun and Moon Light in the Zones

Done, 2026-11-13 to 2026-11-14: the plan PR #64, then five stacked PRs, #76 (PR 1) and #71–#74. Each zone's 24-hour clock starts at 07:00 as the car enters it; `Daylight`, a veil over the view, multiplies the world by the hour's light, which never jumps. Props and the car cast shadows that turn with the sun and the moon, and lamps glow at night. The full plan, with its verification, negative cases and review history: `git show 08f316f:DAYNIGHT_PLAN.md`.

## 1. Goal and exit criteria

Each zone gets a day, its light following the sun and the moon; by day the game looks as before. The exit criteria, E1–E17: the light, shadows and lamps change gradually, restart with each zone, stop with the run, change only the picture and keep the smoke readable, with no WebGL error; all are met but E13's Fold4 checks (§7).

## 2. Findings

- **C1.** No time of day. `DayCycle` gives the light; `Daylight` shows it.
- **C2.** A `CanvasModulate`, World's `modulate` or a `Light2D` would dim the glows and darken legends' veils twice. A MUL veil instead.
- **C3.** The smoke's fixed contrast halves at night. It scales with the light.
- **C4.** A legend's veil darkens twice at night. The darker of the two per channel.
- **C5.** Zones differ in length. `AreaDef.day_seconds`.
- **C6.** A zone's reset would cut from night to day. `LIGHT_MAX_RATE`.
- **C7.** A short day changes fast. The rate caps the light, and `AreaDef.validate()` reports a `day_seconds` that isn't finite or is below `DayCycle.least_day_seconds()`, 55.68 s, naming it rounded up, 55.69 s.
- **C8.** A clock that ran on would change game over. It runs only with the run.
- **C9.** In Godot 4.7.2 each redraw of a `Polygon2D` after its first raises WebGL errors (godotengine/godot#124726). The veil changes only `self_modulate`, `modulate.a` and position; shadows and lamps are sprites.
- **C10.** A veil stepped before the camera lags a frame. Daylight steps after it, at `ViewVeil.PHYSICS_PRIORITY`.
- **C11.** The legends' veil was private. Now `ViewVeil`, shared with `Daylight`.
- **C12.** Devices take no arguments (docs/M4.md P4), so `--hour` is for desktops and tests.
- **C13.** A test pins World's children. `%Daylight` goes under Main; `Shadows` and `Lamps` join World.
- **C14.** The docs had no light. `plan.md` and `AGENTS.md` updated (Q13).
- **C15.** IP's darkening `CanvasModulate` in the tunnel would break C2. Deferred (§9).
- **C16.** No prop said how it casts. `PropDef.shadow` and `shadow_rise`.
- **C17.** No prop said where it glows. `PropDef.lights` and `light_pools`.
- **C18.** Overlapping shadows darken twice, and glows add twice. One `CanvasGroup` each (P8, P10), never nested (P8b).
- **C19.** A glow behind a prop would light its face, and props can't join the glows' group (P10b). Silhouettes in Lamps.
- **C20.** Shadows laid on the CPU took 1.3–1.7 ms a frame, and sprites that GUT's `simulate()` walks took CI's GUT time from 98 s to 225 s. Materials lay them on the GPU (P11), each cast with a custom rect from `Shadows.reach()` so it isn't culled; the sprites are internal children (`PropPool`), which `simulate()` skips; scatter tests use sparse props.
- **C21.** The tutorial's switch skips `_on_area_changed()` (docs/TUTORIAL.md T19). `_on_tutorial_completed()` enters the City's clock.
- **C22.** A shadow dims the ground under a crash's smoke, to ×0.912 of the rule's contrast, ×0.730 through a tunnel. A black cast is a dimmer light, (1 − α)·L, in which Q12's rule holds (N103).

## 3. Decisions

The owner answered Q4, Q5 and Q14; the rest are defaults.

- **Q1.** Start hour: 07:00 (`Tuning.DAY_START_HOUR`).
- **Q2.** A zone's reset: at the rate, 2.33 s from night; a new run cuts.
- **Q3.** Per zone: `day_seconds` only, 120 s.
- **Q4.** Shadows that turn with the sun and the moon: yes (PR 4).
- **Q5.** Lamps and windows that glow at night: yes (PR 5); no headlights.
- **Q6.** After the run: the light stays.
- **Q7.** Legends' veils at night: the darker per channel.
- **Q8.** A HUD clock: none.
- **Q9.** A setting to turn off the night: none.
- **Q10.** The night: `LIGHT_NIGHT` (0.42, 0.48, 0.72), to tune.
- **Q11.** Another start hour: `--hour=<h>`.
- **Q12.** The smoke at night: contrast at least `SMOKE_CONTRAST` × the light's luminance.
- **Q13.** Docs: `plan.md` and `AGENTS.md`, not IP.
- **Q14.** Landing: five stacked PRs after the plan's (§4.5).

## 4. Work breakdown

- **PR 1** (#76; first #70, §4.5): `DayCycle`, the lights, `AreaDef.day_seconds`.
- **PR 2** (#71): `ViewVeil`, out of `Legend`; legends' veils in an `ambient` light.
- **PR 3** (#72): `Daylight`, the clock in `ui/main.gd`, `--hour`, the Light rule.
- **PR 4** (#73): `PropDef.shadow`, `Shadows`, `shadows.gdshader`, the Shadows rule.
- **PR 5** (#74): `PropDef.lights`, `Lamps`, `lamps.gdshader`, the Lamps rule.

### 4.5 Landing

Each PR targeted the branch below and landed alone once its base was `main`. With #70–#74 in native stack #75 while #70's base was `dn/plan`, #70 merged there, not into `main`; GitHub's cascade, which replays each branch's commits without its merges, stopped at `dn/3-daylight`. The repair rebased nothing: `dn/1-cycle` came back as #76.

## 5. Design

### 5.1 The clock

`DayCycle` (`world/day_cycle.gd`) is a pure `RefCounted`. `hour()` runs from `start_hour` round the clock in `day_seconds`, which each zone's `AreaDef` sets, 120 s by default. `enter(p_day_seconds)` restarts it for a zone and keeps the light shown; a day that isn't finite and positive is reported, and the clock stops. `snap()` shows the hour's light and shadows at once.

### 5.2 The lights

Six keys, `Tuning.LIGHT_HOURS` and `LIGHT_COLORS`: `LIGHT_NIGHT` at 04:30, `LIGHT_DAWN` at 06:00, white at 07:00 and 17:00, `LIGHT_DUSK` at 18:30, `LIGHT_NIGHT` at 20:00. Channels ease between keys by one `smoothstep()` weight, so 07:00–17:00 is exactly white.

### 5.3 Gradual

`advance(delta)` moves the light shown straight toward the hour's, its farthest channel by at most `LIGHT_MAX_RATE`, 0.25 a second. `least_day_seconds()`, 55.680001 s, is the shortest day whose steepest change (`STEEPEST`, 1.5) the rate can follow. The light shown is a blend of the keys, so a rule linear in the light that holds at each key always holds.

### 5.4 Zones and runs

`_start_run()` enters the first zone, then calls `snap()` and Daylight's `refresh()`: a run starts with a cut. `_physics_process()` advances the clock while `GameState` is RUNNING, tutorial included. `_on_area_changed()` calls `enter(area.day_seconds)`, as `_on_tutorial_completed()` does (C21). At game over or a pause the clock stops, and the light stays.

### 5.5 The veil

Its rule, Light, is in `.github/instructions/light.instructions.md`.

`ViewVeil` (`world/view_veil.gd`) is a `Polygon2D` square, `BLEND_MODE_MUL`, at absolute z `VEIL_Z` (2), hidden by `modulate.a` 0; `follow()` centres it on the camera, and `shade()` sets `self_modulate`, hiding it in white.

### 5.6 Legends at night

`_on_disaster_triggered()` passes the light shown to `DisasterDirector.play_disaster()`, which sets `DisasterBase.ambient`, white after `clear()`. Under light L a veil V would show L × V (C4), so `Legend._veil_color()` darkens each channel by V / L where L > V, else not: the world shows min(L, V).

### 5.7 Readable at night

The smoke's luminance must differ by at least `SMOKE_CONTRAST`, 0.1, from what it covers, through a tunnel too, and at night by `SMOKE_CONTRAST` × lum(L) (Q12). Both sides are linear in L, so `test_car_controller.gd` checks the key lights (§5.3).

### 5.8 When the night shows

Dusk starts 10/24 of a day into a zone and the night 13/24: at 120 s a day, 50 s and 65 s. The City and the Village are shorter, so a run's first night comes in Rural.

### 5.9 Any hour

`--hour=<h>` starts every zone's clock at hour h. `main.gd`'s `_parse_hour()` takes any finite number, round the clock (`--hour=26` is 02:00), and reports anything else, keeping `Tuning.DAY_START_HOUR`.

### 5.10 Rejected approaches

Tinting the world breaks C2; a shader per material fails art that forgets it; a `CanvasLayer` can't draw between the world and the glows.

### 5.11 Shadows

Its rule, Shadows, is in `.github/instructions/light.instructions.md`.

The sun is up from 06:00 to 18:00, the moon otherwise; each rises on the screen's left and sets on its right, so shadows fall in front of their casters. `DayCycle.shadow` is where a pixel of height falls, at most `SHADOW_LONGEST` (2.5) heights away; `shadow_alpha` is 0.3 by the sun, 0.15 by the moon.

### 5.12 Lamps

Its rule, Lamps, is in `.github/instructions/light.instructions.md`.

`Lamps.strength(L)` is the least over the channels of (1 − L) / (`LAMP_ALPHA` × `LAMP_COLOR`), from 0 to 1: 0 by day, 1 from 19:48 to 04:43. Lamps is World's last child, at `GLOW_Z` (3), not y-sorted, so it orders the silhouettes itself (P10b).

## 6. Verification

The five checks passed on each PR; at PR 5, 160 scripts, 583 tests and 426,861 asserts. The Web ran in Chrome and Firefox with no WebGL error. Test names drop `test_`.

- **P1.** Only the glows and the UI draw above Daylight: World's items at z 0–1, the veil at 2, glows at 3.
- **P8.** Two black casts in a group at 0.5, over a grey of 0.6: 0.302, for 0.3, under one and under both.
- **P8b.** A cast is a sprite in the Shadows group, never a `CanvasGroup` inside a `CanvasGroup`, which draws wrong: nested, the overlap showed 0.541.
- **P10.** In one ADD group, overlapping glows light as one; alone they add twice.
- **P10b.** A `CanvasGroup` holds only the items at its own z, and none if it y-sorts (`renderer_canvas_cull.cpp`:197–257, :438–492).
- **P11.** The shader and `Shadows.laid()`, the car's CPU lay, agree within 1 px at every half hour.
- **N4.** `advance()` sets `light = goal`; **N5.** `enter()` calls `snap()`: both fail `the_light_shown_never_changes_faster_than_the_max_rate`.
- **N8.** `enter()` skips its check; **N36.** it checks only `<= 0.0`, so NaN passes: both fail `a_day_of_no_seconds_is_an_error_and_stops_the_clock`.
- **N37.** `validate()` names 55.68: fails `validate_reports_a_day_too_short_to_follow`. **N38.** It skips non-finite days: fails `validate_reports_a_day_that_isnt_finite`.
- **N13.** `ViewVeil` in `BLEND_MODE_MIX`; **N14.** z relative; **N15.** shown from `_init()`: each fails `the_veil_multiplies_at_veil_z_and_starts_hidden`.
- **N23.** Daylight doesn't set its priority: fails `in_the_games_frames_the_veil_follows_the_view_of_the_same_frame`. **N24.** Its `_physics_process()` does nothing: fails `the_light_follows_the_clock_while_the_car_drives`.
- **N25.** The clock advances in every state: fails `the_clock_stops_when_the_run_ends_and_while_paused`.
- **N26.** `_on_area_changed()` without `enter()`: fails `each_new_zone_starts_its_clock_again`. **N39.** It enters 120 s: fails `each_zone_runs_its_clock_at_its_own_pace`.
- **N27.** `_start_run()` without `snap()`; **N28.** without `refresh()`: both fail `each_run_starts_at_once_in_the_morning`.
- **N29.** `play_disaster()` without the light: fails `at_night_the_disaster_plays_in_the_light_the_run_ended_in`.
- **N30.** `_ready()` doesn't set `start_hour`; **N31.** `_parse_hour()` without `is_finite()`: both fail `the_hour_argument_starts_every_zone_at_that_hour`.
- **N32.** Daylight at `VEIL_Z + 1`: fails `the_veil_darkens_the_world_but_not_the_glows_or_the_ui`.
- **N33.** While the light isn't white, `main.gd` lowers bus 0 by 6 dB; **N40.** mutes Ambient; **N41.** plays the junction's sound at 20:00; **N42.** mutes the engine; **N43.** moves the ambience to Music: each fails `the_light_changes_nothing_but_the_view`.
- **N34.** `ViewVeil.shade()` sets `color`: fails `daylight_is_never_redrawn`. **N35.** It never hides: fails `by_day_the_veil_is_transparent_and_by_night_it_shows_the_light`.
- **N44.** A shadow's frame mirrored: fails `an_upright_props_shadow_falls_from_its_foot_across_the_light`.
- **N81.** Lamps tinted through `modulate`, not `self_modulate`, which lights the glows twice: fails `the_lamps_draw_as_one_group_that_adds_over_the_veil`.
- **N103.** The smoke grey 0.005, not black: fails `the_smoke_shows_in_a_shadow`.
- **N104.** The clock runs behind the title; **N105.** Title resets it: both fail `the_title_keeps_the_night_and_play_starts_the_morning`.

## 7. Owner actions

- **The Fold4** (E13), not yet reported, on a debug APK from `main`, folded and unfolded: dusk and Rural's reset gradual; the road, car and shaded smoke readable at night; lamps warm, never white; the night as smooth as the day.
- **Tune** if needed (Q3, Q10): `LIGHT_*`, `*_SHADOW_ALPHA`, `LAMP_*` or a zone's `day_seconds`.
- **Delete** `dn/plan` and `dn/1-cycle`.

## 9. Notes for later

- **M7 views:** add them to `SCREENS` in `tests/integration/test_props_in_view.gd`, which checks that the veil covers them.
- **M7 haptics and Web audio:** add them to `_sound()` in `tests/integration/test_daylight_run.gd`.
- **The tunnel's darkening** (C15, `setpieces/tunnel.gd`): through Daylight, eased with `Tunnel.opacity()`, not a `CanvasModulate`.
- **A night setting** (Q9): `Color.WHITE.lerp(light, k)` keeps the rules.
- **Saved runs** would need `DayCycle`'s state; per-zone hours would go in `AreaDef`.
- **A bound** for the loop in `tests/unit/test_road_generator_tutorial.gd`, which runs out of memory if the schedule has no set piece.
