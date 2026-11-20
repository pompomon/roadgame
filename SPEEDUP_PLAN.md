# The Speedup: the Road to the Sea in Five Minutes — Detailed Plan

Status: approved as #116 merged, with the owner's answers to Q1, Q4 and Q9 (§3) and the other questions' defaults. PR 1 is #118, which the owner lands (§4.2); PR 2 follows · 2026-11-20 · Scope: a run to the end of either road takes the autopilot about four minutes, not ten, and at most five on all but one of the 10,000 runs measured, 5,000 seeds a road: a target, not a cap proven for every seed (Q15). Both roads end after their 100th turn, not their 280th: the City has 20 turns, Rural 24, the Meadows 24, the Village 10 and the Desert 22, and from the Meadows on, the straights are longer, 6–12 tiles in the Meadows and the Desert and 4–8 in the Village. The car's top speed grows by 0.0035 tiles/s a tile driven, not 0.002, and Rural, the Meadows and the Desert turn a day in 60 s, so that each still shows its night. This plan calls the work SP. It builds on EG, which has landed, and comes before M7.

The owner asked: "Explore the codebase and create a detailed implementation plan for game speedup. Adjust the number of turns required after the first zone, so the end time on autopilot is 5 minutes at most. Also adjust the Meadows zone and beyond to have less turns and longer straight roads. Ask clarifying questions if needed". The clarifying questions are §3's Q1–Q15. Written in autopilot mode, the plan gave each question a default, which its first draft and its prototype followed. The owner then answered in the session: "Update the following defaults: Q1 reduce City turns to 20, keep Rural 24, increase Meadows to 24, Village to 10 and Desert to 22. Q4 increase speed growth 0.0035 a tile. Keep the rest of defaults and prepare the PR for merge". So Q1 and Q4 take the owner's answers, and so does Q9, the Village's turns, which Q1's answer settles; the other twelve keep their defaults. The prototype and every probe follow the answers (§6.5).

**What happens.** Today the autopilot takes about ten minutes to the end of either road: 562.2–613.3 s to the pier and 561.4–614.0 s home, on seeds 0–19 (P5; docs/ENDGAME.md P1). The road ends after its 280th turn (`schedule.tres`:52), and 246 of its turns come after the City's 34: Rural's 66, the Meadows' 100, the Village's 20 and the Desert's 60. The Meadows alone take 217 s. With SP, the areas switch at turns 20, 44, 68 and 78, and the road ends after its 100th (Q1). The Meadows' straights become 6–12 tiles, from 3–7, the Village's 4–8, from 2–5, and the Desert's 6–12, from 3–8, with fewer decoys (Q3, Q14), so those areas turn less and run straighter, as the owner asked: 2.6–3.1 s a turn, against Rural's 2.1. The car reaches its top speed's cap, 7.0 tiles/s, after 857 tiles, not 1,500 (Q4). The City takes about 35 s, Rural 50 s, the Meadows 74 s and the Desert 63 s, and the Village is a 26 s interlude. On 5,000 seeds of each road, the autopilot arrived in 222.2–306.4 s, 252.6 s on average, with full health (P1). The Road Home stays the road's mirror, with the same turns in reverse (Q2).

**One run over five minutes (Q15).** Pier seed 4993 took 306.4 s, the only one of P1's 10,000 runs over 300 s: its Meadows had 14 decoys among their 38 junctions, against 4.2 on average, and took 99.9 s, against 73.7 s, and its other areas took 28.0 s more than theirs (U13). The next slowest, home seed 352, took 294.5 s. Q15's default, which the owner kept, makes five minutes a target, not a cap on every seed: E1 bounds 10 seeds a road at 300 s, and each road's slowest seed at `SLOWEST_SECONDS`, 310 s, where the first draft bounded its slowest, 278.7 s, at 300 s: merging this plan accepted that change (§7). §5.2's model puts about one run in 20,800 over 300 s. Three variants, not chosen, put none of its 200,000 runs a road over it: V4, the Meadows 22 turns and the Desert 20, and V2, the Meadows 20, both ending after turn 96; or V7, the Meadows' and the Desert's straights 6–10 (§5.2, §9).

Shorter zones need shorter days. With 120 s days, the night comes 65 s into a zone (docs/DAYNIGHT.md §5.8), which only 48.9% of the new zones of Rural, the Meadows and the Desert would reach, and 0.05% of Rural's (P3), so runs would lose nights that DN added. So those three areas turn a day in 60 s, whose night comes 32.5 s into a zone, and each of P1's 30,000 such zones reached it (Q5). The City, the Village and the Coast keep 120 s, and end by day.

The rest stays (Q8). The route strip keeps its 40% of the HUD's height, and its car now climbs 2.56–3.69 pixels a turn, not about one (Q6, §5.4). Saves stay at version 5 (Q7). The car but for its top speed's growth, the autopilot, the legends and the pit stops' rule don't change, and the game's road is `main`'s up to the City's last junction, its 20th. PR 1 makes the change, and PR 2 replaces this plan with `docs/SPEEDUP.md` (§4).

**Verified locally.** The change was first built on branch `sp/prototype`, from `main` at ec6f54d, which never gets a PR of its own (§4.1). Its first eight commits change 6 area files, `config/tuning.gd`, a comment in `route_strip.gd` and 17 test files: 25 files, +216 −146. The first five, 529378c, 6740ac4, 339b126, a130c54 and 9229f94, built the first draft, with the defaults; 68ef177, 98ffdd5 and 8205270 build the owner's answers. The ninth, 17f5ff6, adds §6.5's probes in `tools/sp/`, which PR 1 leaves out. The prototype passed the five checks locally with Godot 4.7.2 and the warnings check, and each of the 12 negative cases failed the tests it names (§6.1–§6.3). CI run 44803243085 passed on 8205270, and built the Web build and the APK. Probes drove both roads to their ends on 5,000 seeds each, measured the nights, the speeds and the light, and compared the road with `main`'s (§6.5), and a movie shows the whole road (§6.4). A model of another family reviewed the plan and the prototype (§4.4).

- Godot 4.7.2-stable (4.7.2.stable.official.ed1daf0bf), as in CI
- GUT 9.7.1
- gdtoolkit 4.5.0 on Python 3.12, as in CI's `lint` job. shellcheck isn't installed locally, so `lint.sh` skipped it there; SP changes no shell script

**Precedence.** For SP, this document replaces `plan.md`'s vision (:13), §3.6 (:121–125), §5.5 (:229), §9 (:356), §11 (:390) and §13 (:429); docs/ENDGAME.md's header (:3), E6 (:11), Q1 (:47), §5.6 (:112), §5.8 (:120), P1 (:162) and §8 (:170); docs/DAYNIGHT.md Q3 (:40) and §5.8 (:99); docs/ROADGEN.md §5.5's straights and the Desert's chances (:82–88); and docs/TUTORIAL.md Q15 (:47), wherever it marks a difference with **Δ** and its finding (U#, §2). PR 1 folds them into those files (§5.8, Q12).

**Reference code.** PR 1 starts as the difference between ec6f54d and 8205270, with §5.8's Δs to the docs (§4.1), and adds §4.3's fixes. `sp/prototype`'s head, 17f5ff6, adds only `tools/sp/`.

**Prerequisites.** EG has landed, with its docs (#101–#114), so `main` has the road's end, the Road Home, the route strip, the pit stops and the records that SP retunes. The prototype starts from ec6f54d. Since then, `main` has taken the owner's #115, EG's learnings for agents, at 4a50bb2: it changes `AGENTS.md`, `docs/README.md`, docs/agents/ and `.github/instructions/`, but no file of PR 1's, and it adds the learnings step that PR 2 takes (planning.md §7). Then this plan, #116, HL's plan, #117, and HL's PR 1, #119, the car's headlights, which PR 1 merges (§6.4). M7 hasn't started; §9 has notes for it. No repository settings change.

Contents:
1. Goal and exit criteria
2. Review findings
3. Decisions and open questions
4. Work breakdown (2 PRs)
5. Design
6. Verification
7. Owner actions
8. Risks
9. Notes for later work

---

## 1. Goal and exit criteria

Goal: a whole road in one sitting. The autopilot drives either road to its end in about four minutes, and in at most five on all but one of the 10,000 runs measured (Q15), and a player who knows the way takes about as long. The City is shorter, the areas after it have fewer turns, and from the Meadows on, the road runs straighter. Each area keeps its character and its legends, and each long area past the City still shows its night.

| # | Exit criterion | Checked by |
|---|---|---|
| E1 | Five minutes (U1, U3, U4, U13; Q1, Q4, Q10, Q14, Q15). Both of the game's roads end after their 100th turn. The autopilot drives each to its end, with no disaster, crash or damage and no junction dropped: on each of 10 seeds in at most `MOST_SECONDS`, 300 s, and on the slowest of P1's 5,000 seeds a road in at most `SLOWEST_SECONDS`, 310 s, as pier seed 4993 takes 306.4 s (Q15). The time is game time: the run's clock, which the end screen shows. The end screen comes `ARRIVAL_SECONDS`, 5 s, after the arrival | `tests/sim/test_drive_to_the_end.gd`: `test_the_autopilot_drives_to_the_pier`, `test_the_autopilot_drives_the_road_home`; `test_area_schedule.gd`: `test_the_games_road_ends_at_the_pier_after_its_100th_turn`; `test_road_generator_finish.gd`: `test_the_road_home_ends_at_home_after_100_turns`; P1, on 5,000 seeds a road: 222.2–306.4 s, one run over 300 s |
| E2 | Fewer turns and longer straights after the City (U1; Q1, Q3, Q9). The areas switch at turns 20, 44, 68 and 78, and the Coast starts at 100: the City has 20 turns, Rural 24, the Meadows 24, the Village 10 and the Desert 22. On a first run, Rural can come a turn or two late, if the tutorial's road holds the 20th turn (§4.3). The tunnel, the bridge and Last Gas still lead into Rural, the Meadows and the Desert, with the same pit stops. From the Meadows on, each area's shortest and longest straights are longer than Rural's, 3 and 7 tiles: the Meadows' 6–12, the Village's 4–8 and the Desert's 6–12. The City and Rural keep theirs | `test_area_schedule.gd`: `test_from_the_meadows_on_the_straights_are_longer_than_rurals`, `test_areas_and_set_pieces_switch_at_20_44_68_and_78`, `test_the_game_schedule_is_valid`, `test_the_games_pit_stops`; `test_area_order.gd` and `test_tutorial_run.gd`, which drive the road through each switch to the Desert's, at turn 78; `test_set_pieces_on_the_road.gd`, past the bridge at turn 44; `test_drive_to_the_end.gd`, which ends each road in its last area, the Coast or the City; `test_area_start.gd` |
| E3 | Each long zone shows its night (U2; Q5). Each zone of Rural, the Meadows and the Desert that the car leaves lasted into its night, by its area's `day_seconds` as loaded: with SP's 60 s days, the night comes 32.5 s after the car enters one. No area's day is shorter than 55.68 s, the shortest whose light changes within `LIGHT_MAX_RATE`, which `validate()` checks. The days' lengths are data in the areas' `.tres` files, which no test names, as with the areas' other values: the City, the Village and the Coast keep 120 s | `test_drive_to_the_end.gd`'s two tests, through `_check_night()`, on each zone of `NIGHT_AREAS`; `test_area_schedule.gd`: `test_the_game_schedule_is_valid`, `test_the_road_home_is_valid_and_runs_the_other_way`; P3 |
| E4 | Nothing else changes (U6, U7; Q4, Q8). The City's straights and junctions, the tunnel, the car but for its top speed's growth (Q4), the autopilot, the legends, the pit stops' rule, the light's rules and the save stay as on `main`. Up to and including the junction of its 20th turn, the City's last, the game's road is `main`'s, tile for tile, with its dead ends. Only the golden digests of `endless()`, which lays Rural from turn 20, the Meadows from 44 and the Desert from 78, change, and PR 1's commit says why. `smoke.sh` prints `autopilot: tile 177, turns 32, area rural`, where `main`'s printed `tile 165, turns 35`, as Rural comes sooner and the car is faster | The tests that PR 1 doesn't change, which pass as on `main`, and `test_car_sim_speed.gd`'s `test_the_top_speed_grows_with_the_run_up_to_the_cap`, which checks the growth, 0.0035 a tile, at 500 tiles; `test_road_generator_determinism.gd`'s new digests; P7, on seeds 0–199; §6.1's smoke line |
| E5 | The Road Home (Q2). It stays the road's mirror: the Desert from its start, the Village at turn 22, the Meadows at 32, Rural at 56 behind the bridge and the City at 80 behind the tunnel, and home after turn 100, with pit stops where the Village, Rural and the City start | `test_area_schedule.gd`: `test_the_road_home_is_valid_and_runs_the_other_way`, `test_the_games_pit_stops`; `test_drive_to_the_end.gd`: `test_the_autopilot_drives_the_road_home`; `test_hud.gd`: `test_the_route_strip_shows_only_on_a_road_with_a_finish`; `test_hitchhiker_run.gd`: `test_a_departure_that_starts_before_her_turn_has_her_too`; `test_road_generator_finish.gd`: `test_the_road_home_ends_at_home_after_100_turns` |
| E6 | The strip and the save (U5, U8; Q6, Q7). The route strip keeps its 40% of the HUD's height, with ticks at turns 0, 20, 44, 68, 78 and 100. On each reference screen, 640, 800 and 922 pixels high, its car climbs evenly, each turn the strip's length over 100 turns, rounded down or up, and never more than half its mark's height. Saves stay at version 5: an older save loads as it is, and the goal line, the strip and the Hitchhiker clamp a farthest turn past 100, so the goal line of a player who passed turn 100 on `main` reads "Your best: turn 100 of 100" until they arrive | `test_hud.gd`: `test_the_route_strip_marks_each_area_the_car_and_the_best`, and `test_the_route_strip_shows_only_on_a_road_with_a_finish`, whose best is past the finish; `test_game_over.gd`: `test_the_next_goal_follows_the_players_progress`, whose farthest is 50 turns past the road's end; `test_hitchhiker.gd`: `test_her_turn_is_the_players_farthest_on_the_road_home_or_its_finish_once_home`, and `test_save_data.gd`, unchanged |
| E7 | Docs: PR 1's Δs (§5.8), then PR 2's `docs/SPEEDUP.md` (Q12) | Review |
| E8 | Manual: a run of the new road reads well, from the City to the end screen, with the nights of Rural, the Meadows and the Desert, in a desktop run's frames (done on the prototype at 98ffdd5, and on PR 1 at 3b79952, §6.4); the owner may play one on the Fold4 before landing PR 1 (Q13) | §6.4 |
| E9 | All four required checks are green on each PR, with §4's counts, and `smoke.sh` prints no error line. Each negative case makes the tests it names fail (§6.2), the warnings check finds only `main`'s five (§6.3), and GUT reports no warning | PR checks; §6.2 and §6.3, run locally with Godot 4.7.2 on PR 1's head |

---

## 2. Review findings

The prototype checked each finding below that has a fix (§6.2).

- **High:** the game misleads the player, or breaks.
- **Medium:** fragile, or missing from the tests.
- **Low:** clarity or polish.

Line numbers are at ec6f54d, from which the prototype was made, unless they say otherwise. `main`'s 4a50bb2 changes none of the files they cite but `AGENTS.md`, whose lines up to :24 are the same.

### High

| # | Finding | Evidence | Fix |
|---|---|---|---|
| U1 | A run to the end takes about ten minutes, most of it after the City. 246 of the road's 280 turns come after the City's 34, and the Meadows' 100 alone take 217 s | `schedule.tres`:18–52: the areas at turns 34, 100, 200 and 220, the Coast at 280, and `finish_turn = 280` (:52); `schedule_home.tres`:17–46, its mirror. P5, seeds 0–19: 562.2–613.3 s to the pier and 561.4–614.0 s home; to the pier, the City took 58 s, Rural 136 s, the Meadows 217 s, the Village 39 s and the Desert 136 s. docs/ENDGAME.md P1 (:162): 9.6–10.2 minutes | **Δ plan.md :13, §3.6, §11, §13; docs/ENDGAME.md Q1, §5.6, §5.8, P1, §8; docs/TUTORIAL.md Q15:** the areas switch at turns 20, 44, 68 and 78, and both roads end after turn 100 (Q1, Q2; §5.1). Prototype (E1, E2, N1, N8) |
| U2 | Shorter zones would lose their nights. With 120 s days, the night comes 65 s after the car enters a zone, and SP's Rural, Meadows and Desert zones last 41–109 s: only 48.9% of them would reach it, and 0.05% of Rural's, while each of `main`'s did | `area_def.gd`:71, `day_seconds := 120.0`, which no area sets; `tuning.gd`:247 and :251: a zone's clock starts at 07:00, and the night at 20:00, 13/24 of a day later; docs/DAYNIGHT.md §5.8 (:99). P3 | **Δ plan.md §5.5; docs/DAYNIGHT.md Q3, §5.8:** Rural, the Meadows and the Desert turn a day in 60 s (Q5; §5.3). Prototype (E3, N3, N7) |

### Medium

| # | Finding | Evidence | Fix |
|---|---|---|---|
| U3 | No test bounds a run's time, and the times spread: the slowest of P1's 10,000 runs took 306.4 s, 84.2 s more than the quickest | `test_drive_to_the_end.gd`:9–12: five seeds a road, "about 9 minutes", and a cap of 20 minutes, which only stops a car that never arrives; no assert reads the time | `MOST_SECONDS`, 300 s, asserted on 10 seeds a road, and `SLOWEST_SECONDS`, 310 s, on each road's slowest seed of P1, with the cap at twice `MOST_SECONDS` (E1, Q15); P1 on 5,000 seeds a road (§6.5). Prototype (E1, N1, N9) |
| U4 | The car's top speed grows with the distance it has driven in the run, so a shorter road ends slower: with `main`'s growth, the cap would end at 5.57–5.99 tiles/s at the pier, where on `main` it was 7.0 | `car_sim.gd`:250–253: `minf(GLOBAL_SPEED_CAP, BASE_TOP_SPEED + dist_total * TOP_SPEED_GROWTH)`; `tuning.gd`:65–68: 4.0, 0.002 a tile and 7.0, reached after 1,500 tiles. P1: 786–1,111 path tiles to the pier. P6, at 0.002 on seeds 0–199: the Desert's top speed to the pier 5.69 tiles/s on average, against 5.79 on `main` (P5) | `TOP_SPEED_GROWTH` 0.0035 a tile, the owner's answer to Q4, so that the cap reaches 7.0 after 857 tiles: the Desert's top speed to the pier is 6.83 tiles/s on average, and a run 3.5–4.1 s quicker on average than with 0.002, by road (P6; §5.2). Prototype (E1, E4, N12) |
| U5 | The strip's test expects a pixel or so a turn | `test_hud.gd`:268–272: each turn's climb 0–2 pixels; `route_strip.gd`:7, "a pixel or so a turn". The strip is 40% of the HUD's height (`hud.tscn`:66–68), 256–369 pixels on the reference screens, so 100 turns climb 2.56–3.69 pixels each | The strip stays (Q6). The test checks that the car climbs evenly, the strip's length over 100 turns rounded down or up, and at most half its mark, 4 pixels; the comment says "a few pixels a turn" (§5.4). Prototype (E6, N4) |
| U6 | Thirteen test files hold the old road's turns, times or digests: on `main`, the new schedules alone fail 25 of its 903 tests | `main` (4a50bb2) with 98ffdd5's `schedule.tres` and `schedule_home.tres`: `test_area_schedule.gd` 9; `test_arrival.gd`, `test_drive_to_the_end.gd`, `test_hud.gd` and `test_road_generator_finish.gd` 2 each; and one each in `test_area_start.gd`, `test_hitchhiker_run.gd`, `test_area_order.gd`, `test_set_pieces_on_the_road.gd`, `test_tutorial_run.gd`, `test_game_over.gd`, `test_prop_scatter.gd` and `test_road_generator_determinism.gd` | The 17 test files of §5.7: those thirteen; `test_car_sim_speed.gd`, whose 1,000 tiles would now grow the top speed past the cap (U4); and three whose comments name the old road or its days: `test_autopilot_300_turns.gd`, whose caps also become twice its new times, `test_daylight_run.gd` and `test_props_in_view.gd`. Prototype (E1, E2, E5, N1, N8) |
| U7 | The golden digests change. `PATH_DIGEST` and `ROAD_DIGEST` digest `endless()` on seeds 0–19 to turn 300, which now crosses Rural from turn 20, the Meadows from 44, the Village from 68 and the Desert from 78, with longer straights from the Meadows on | `test_road_generator_determinism.gd`; docs/ROADGEN.md §6.1: a commit that changes the digests says why | New digests, and PR 1's commit body says why. P7: up to the junction of its 20th turn, the road is `main`'s on 200 seeds (E4). Prototype (N2, N5, N6, N11) |
| U8 | A save keeps the old road's records. An arrival on `main` keeps the road's farthest turn, 280, and a best time of about ten minutes, and `main` deploys to Pages | `save_data.gd`:14, version 5; `record_arrival()` (:244–252) keeps the least time (:248) and the farthest turn (:251); `ci.yml`:88–90, the Pages artifact on a push to `main`. Clamped: the goal line (`game_over.gd`:125–127), the strip (`route_strip.gd`:64–68) and the Hitchhiker (`hitchhiker.gd`:54–58). Not clamped: the overall and the Atlas's best turns (`atlas_screen.gd`:60–73) | None by default (Q7): an arrival on the new road replaces the old best time only if it is faster, as each measured would be, the slowest at about half of `main`'s quickest (§5.5), and a best turn past 100 is history. Until a player arrives, their goal line reads "Your best: turn 100 of 100" if they passed turn 100 on `main` (§5.5). Prototype (E6) |
| U13 | A rare seed takes over 300 s, as a zone's decoys vary widely. A decoy is a junction with no turn, and each junction's kind is its own roll, so an area's turns can take many more junctions than usual: with the Meadows' 24 turns and their decoy chance of 0.15, 14 decoys or more come once in about 1,740 zones. With straights of 6–12 tiles, a decoy takes about 2.6 s | P10, on 339b126, with the first draft's turns: home seed 3879 arrived at 301.6 s, its Desert zone with 15 decoys among its 31 junctions. P1, with the owner's turns: pier seed 4993 arrived at 306.4 s, the only run over 300 s. Its Meadows zone had 14 decoys among its 38 junctions and 381 path tiles, against 282 on average, and took 99.9 s, against 73.7 s. `kind_for()` (`road_generator.gd`:149–159) draws each junction's kind from one roll, and `_junction()` gives a decoy a new straight and no turn (:213–216) | **Δ docs/ROADGEN.md §5.5:** the Desert's straights 6–12 tiles, not 6–14, and its decoy chance 0.15, not 0.2, with its side roads 0.3, not 0.25, so that 0.45 of its junctions still have a trick (Q3, Q14; §5.2). Five minutes is a target (Q15): E1 drives each road's slowest seed within 310 s, and §5.2's variants V4, V2 and V7 would leave a margin (§9). Prototype (E1, E2, N6, N9, N11) |

### Low

| # | Finding | Evidence | Fix |
|---|---|---|---|
| U9 | More runs arrive, and the City's share of the turns grows. A road has about 113 junctions, where it had about 324, so at 1% errors a junction, about 32% of runs would arrive, against about 4% | §3.6 of `plan.md`; the City's share of the turns 12% → 20%, Rural's 24% → 24%, the Meadows' 36% → 24%, the Village's 7% → 10%, the Desert's 21% → 22%. A decoy is a junction with wrong exits but no turn (`road_generator.gd`:213–216), so with each area's `decoy_chance`, 0–0.15, a road's 100 turns take 20 + 24/0.9 + 24/0.85 + 10/0.85 + 22/0.85, about 113 junctions | None: an arrival unlocks a legend of any area's pool (docs/ENDGAME.md §5.5), and Departures start in any area discovered (§8) |
| U10 | Most of Rural's zones end at night, so the next zone's morning fades in from the night | P4: with 60 s days, 82–84% of Rural's zones end at night, by road, and 28.4% of all the zones of Rural, the Meadows and the Desert, against 39 of P5's 120 on `main`. The fade takes 2.33 s (docs/DAYNIGHT.md Q2) | None: the light changes within `LIGHT_MAX_RATE`, which `test_daylight_run.gd`:129 asserts each frame of a morning's fade, and the whole road's movie shows no flicker (§6.4) |
| U11 | Comments name the old road's times and turns | `test_area_order.gd`:9, `test_autopilot_300_turns.gd`:11, `test_drive_to_the_end.gd`:11, `test_set_pieces_on_the_road.gd`:10 and `test_tutorial_run.gd`:11 give each drive's minutes; `test_props_in_view.gd`:253, Rural at turn 34; `test_daylight_run.gd`'s day of 120 s in every zone; `route_strip.gd`:7 | PR 1 updates each, with each drive's cap at about twice its time (§5.7). Prototype |
| U12 | The docs name 280 turns, the old switches and 120 s days | `plan.md`:13, :121–125, :229, :356, :390, :429; docs/ENDGAME.md :3, :11, :47, :112, :120, :162, :170; docs/DAYNIGHT.md :40, :99; docs/ROADGEN.md :82–88; docs/TUTORIAL.md :47; IP :209, :249, :320; `AGENTS.md`:7 | PR 1's Δs (§5.8) and PR 2 (§4) |

---

## 3. Decisions and open questions

Each question had a default, which the first draft and the prototype's first five commits followed. The owner answered Q1 and Q4, which settles Q9, and kept the other defaults, so the third column holds those three answers, marked as the owner's, and the other twelve defaults; where the first draft's default differed, the fourth column gives it. 68ef177, 98ffdd5 and 8205270 build the answers, and §6.5's probes ran again on them. The owner merged the plan with them (#116, §7).

| # | Question | Answer or default | Alternative |
|---|---|---|---|
| Q1 | How many turns, and where do the areas switch? | **The owner's answer: the City has 20 turns, Rural 24, the Meadows 24, the Village 10 and the Desert 22. The areas switch at turns 20, 44, 68 and 78, and the road ends after its 100th (§5.1). P1's 10,000 runs arrived in 222.2–306.4 s, one over 300 s (Q15)** | The first draft's default: the City kept its 34 turns, and the areas switched at 34, 58, 76 and 84, so that Rural had 24 turns, the Meadows 18, the Village 8 and the Desert 16; its P1 arrived in 208.1–278.7 s. Or, for a margin under the owner's split, §5.2's V4, the Meadows 22 and the Desert 20, or V2, the Meadows 20, which end after turn 96 and put none of the model's 200,000 runs a road over 300 s (§9) |
| Q2 | The Road Home starts in the Desert. Is the Desert its "first zone", whose turns stay? | **No: "the first zone" is the City, where the game's road starts, after the tutorial. The Road Home stays the road's mirror, with the same turns in reverse: the Desert has 22, the Village 10, the Meadows 24, Rural 24 and the City 20, and home comes after turn 100 (§5.1). P1: home in 222.2–294.5 s** | Keep the Desert's 60 turns at the Road Home's start. With SP's straights, they take about 179 s alone. P2 modelled two such roads: with SP's other areas after them, 363.3 s on average and 394.8 s at p99; with only the City's 20 turns after them, 214.3 s on average and 239.0 s at p99, but the Road Home would then skip the Village, the Meadows and Rural, their zones and their legends. Splits between the two weren't modelled |
| Q3 | How long are the straights from the Meadows on? | **The Meadows 6–12 tiles, from 3–7; the Village 4–8, from the defaults' 2–5; the Desert 6–12, from 3–8, with fewer decoys (Q14; §5.2). They take 2.6–3.1 s a turn, where Rural's take 2.1. Rural, which "the Meadows zone and beyond" leaves out, keeps 3–7, and the City's 2–5 and the Coast's 20 stay** | Twice `main`'s: the Meadows 6–14, the Village 4–10 and the Desert 6–16. In §5.2's model, 99 of 20,000 runs to the pier and 188 home then pass 300 s, where none of the default's did. Or longer still, with fewer turns |
| Q4 | Does the car reach its top speed sooner? | **The owner's answer: `TOP_SPEED_GROWTH` 0.0035 a tile, not 0.002, so the car's cap reaches 7.0 tiles/s after 857 tiles, not 1,500, and ends at 6.64–7.0 tiles/s at the pier (U4). A run is 4.1 s quicker to the pier and 3.5 s home on average, and the Desert's top speed to the pier 6.83 tiles/s, against 5.69 (P6). It changes the car on every road, Keep Driving's too** | The first draft's default: 0.002, as on `main`, whose cap ends at 5.57–5.99 tiles/s at the pier (P6). With the owner's turns, §5.2's model then puts 23 and 31 of 200,000 runs over 300 s, by road (V10), against 3 and 9 |
| Q5 | How long are the zones' days? | **60 s in Rural, the Meadows and the Desert, whose zones take 41–109 s: the night comes 32.5 s into a zone, and each of P1's 30,000 such zones reached it (P3). The City and the Village, which end by day, and the Coast keep 120 s (§5.3)** | 80 s, whose night comes at 43.3 s: 99.6% of the zones reach it, and 98.8% of Rural's; 90 s, 87.3%, and 60–63% of Rural's, by road; or 120 s, as on `main`, 48.9%, and 0.05% of Rural's, so that most runs show no night in Rural. Or 60 s in Rural and 80 s in the Meadows and the Desert, whose zones the owner's turns make longer: each zone still reaches its night, and 10.5% of theirs outlast their day, not 90.5% (§5.3) |
| Q6 | Does the route strip change? | **No: it keeps 40% of the HUD's height, so its car climbs 2.56–3.69 pixels a turn on the reference screens, and its closest ticks, the Village's and the Desert's, 10 turns apart, are 25.6–36.9 pixels apart (§5.4)** | 20%: 1.28–1.84 pixels a turn, near `main`'s 0.91–1.32, with those two ticks 12.8–18.4 pixels apart, and the car's mark 8 pixels high |
| Q7 | Does the save change? | **No: it stays at version 5. A save from `main` keeps its best time, about ten minutes, until the first arrival on the new road beats it, and a farthest turn of up to 280, which the goal line, the strip and the Hitchhiker clamp to the road's 100 (§5.5). So a player who passed turn 100 on `main` without arriving reads "Next: reach the sea. Your best: turn 100 of 100" until they arrive** | Version 6, which clamps each road's farthest turn to its end, and drops the old road's best times; or no migration, but a goal line that leaves out a best at or past the road's end until its first arrival |
| Q8 | Does anything else change? | **No: the City's straights and junctions, the tunnel, the bridge, Last Gas, the car but for its top speed's growth (Q4), the autopilot, the legends and their pools, the pit stops' rule, the tutorial, the light's rules and the music stay as on `main` (§5.6)** | Fewer pit stops, such as none on the bridge: the road from one to the next is 24 or 34 turns, where it was 66 or 120, so a run is easier (§8) |
| Q9 | How long is the Village? | **The owner's answer, with Q1's: 10 turns, about 26 s, an interlude between the Meadows and the Desert, as on `main`, where its 20 turns took 39 s (§5.1)** | The first draft's default: 8 turns, about 21 s |
| Q10 | What do the five minutes count? | **The run's clock, which the end screen shows, from the start to the arrival, as `--autopilot` drives it, without the tutorial (`AGENTS.md` §2). The end screen comes `ARRIVAL_SECONDS`, 5 s, later: at most 311.4 s into P1's runs. A first run plays the tutorial's 12 turns or more before the City's, from whose end the schedule and the run's clock count: on seeds 0–99, the autopilot finished the tutorial in 17.9–22.9 s, and arrived 252.1–294.1 s after the tutorial's start, with the run's clock at 231.4–274.2 s (P9)** | The tutorial's run too: P9's 100 first runs arrived within 294.1 s of the tutorial's start, but P9 drove only seeds 0–99, not P1's slowest |
| Q11 | Do Keep Driving and Departures follow the new road? | **Yes: they read the same schedules. Keep Driving, `endless()`, runs the Desert forever from turn 78, whose longer straights take longer a turn: the autopilot's 300 turns take 758.8–833.6 s, 811.7 s on average, against 607.5–656.2 s and 631 s on `main`, about 29% longer (P8). A Departure starts at its area's new turn, with as many turns fewer to the end (§5.6)** | Keep Driving on `main`'s schedule, a third file, so that its Desert still comes at turn 220. That alone wouldn't bring back `main`'s pace, as the straights are the areas', so its Meadows and Desert would keep SP's: it would need areas of its own too, with `main`'s straights |
| Q12 | Where do the docs change? | **PR 1 folds §5.8's Δs into `plan.md`, docs/ENDGAME.md, docs/DAYNIGHT.md, docs/ROADGEN.md and docs/TUTORIAL.md, with their findings. PR 2 adds `docs/SPEEDUP.md`, changes the owner's paths, `AGENTS.md`, `docs/README.md` and IP, and deletes this plan (§4)** | Everything in PR 1, which the owner then lands |
| Q13 | Who lands PR 1? | **The owner, as the last code PR of the plan (`AGENTS.md` §5 step 4), after an optional run on the Fold4: SP changes nothing that only Android or the Fold4 does (§6.4). The owner lands PR 2 too, which changes `AGENTS.md`** | Agents, with `land_pr.sh`, once its reviews are done |
| Q14 | Do the Desert's junctions change? | **Yes: its decoy chance falls to 0.15, from 0.2, and its side roads' rises to 0.3, from 0.25. 0.45 of its junctions still have a trick, the most of any area, and its T's stay 0.25 (docs/ROADGEN.md §5.5). With fewer decoys, a Desert zone's junctions vary less, and so does its time: with the first draft's turns, the slowest of P10's 10,000 runs, with 0.2 and straights of 6–14, took 301.6 s, and the slowest of the first draft's P1, with 0.15 and 6–12, 278.7 s (U13)** | Keep 0.2 and 0.25, as on `main`. With the owner's turns and the Desert's straights at 6–12, §5.2's model then puts 5 of 20,000 runs a road over 300 s, against none, and its slowest at 304.9 s to the pier and 305.2 s home, so the road would need fewer turns, or the Desert shorter straights |
| Q15 | Is five minutes a cap on every seed, or a target on the seeds measured? | **A target. P1's 10,000 runs took at most 306.4 s, and only pier seed 4993 took over 300 s (U13). E1's test drives 10 seeds a road within 300 s, and each road's slowest of P1 within `SLOWEST_SECONDS`, 310 s, where the first draft bounded its slowest, 278.7 s, at 300 s: merging accepted the change (§7). A zone's decoys have no limit, so a rarer seed may take longer: in §5.2's model, 96 of 2,000,000 runs took over 300 s, about one in 20,800, and the slowest 315.7 s, though the model isn't checked against the game past one run in a thousand (§5.2, §8)** | A cap on every seed: the generator would limit each zone's decoys, which changes the roads of the seeds that draw more, and a test would check the slowest road that the limits allow, a design of its own, with docs/ROADGEN.md §5.5's rules. Or a wider margin: §5.2's V4, V2 and V7 put none of the model's 200,000 runs a road over 300 s, and are 9–12 s quicker on average (§9) |

---

## 4. Work breakdown

Two PRs after this plan's (Q12): PR 1 makes the change, and PR 2, the docs, starts from `main` once PR 1 has merged. Each leaves CI green (E9).

```
main
 ──▶ PR 1 the road to the sea in five minutes (E1–E6, E8; U1–U8, U10, U11, U13)
   │
   ▼  once PR 1 has merged, from main
 PR 2 docs (E7; U12)
```

Why so:
- **One code PR.** The turns, the straights, the top speed, the days and the tests hang together. The schedules alone fail 25 tests (U6). Five minutes need the straights as well as the turns (§5.2), and shorter zones need shorter days, or E3's nights fail (N3). Split, each PR would land a road that the next retunes. PR 1 is small: 28 files, +395 −181, and the docs, with §4.3's fixes.
- **The docs from `main` (PR 2)**, with the owner's paths, as EG's PR 14 did (planning.md §3).

### 4.1 Porting from the prototype

PR 1 starts as the difference between ec6f54d and 8205270, with §5.8's Δs to the docs, and its reviews add §4.3's fixes. `sp/prototype`'s head, 17f5ff6, adds only §6.5's probes in `tools/sp/`, which PR 1 leaves out.

1. Fetch, create PR 1's branch from `main`, and apply the difference. If `main` has moved on since ec6f54d in the prototype's files, `--3way` merges its lines with the prototype's; where both changed the same lines, keep `main`'s other changes and SP's values (§3), then run step 2's probes:
   ```bash
   git fetch origin main '+refs/heads/sp/*:refs/remotes/origin/sp/*'
   git switch -c sp/1-road origin/main
   git diff ec6f54d 8205270 | git apply --3way --index
   ```
2. If `main` has changed the road, the car, the autopilot, the areas or the light since ec6f54d, which `git diff --stat ec6f54d origin/main -- road car areas config world/day_cycle.gd` shows, or step 1 had a conflict, or the owner had chosen a variant (§5.2), run P1 and P3 again with `tools/sp/` (§6.5), on 5,000 seeds a road, and give `test_drive_to_the_end.gd` each road's slowest seed, which must take at most `SLOWEST_SECONDS` (§8). A variant would re-base `neg.py`'s changes and §6.2's failures on its values.
3. Make §5.8's Δs to the docs, which the prototype doesn't have. Leave `SPEEDUP_PLAN.md` alone until PR 1's last round, which carries the plan's final sync (§4.2).
4. Run §6.1's checks and §6.3's warnings, and compare the counts with PR 1's "Expect" line. Run §6.2's negative cases, in their own worktree, each with the whole suite but N7, which runs on `test_area_schedule.gd` alone (§6.2): while the code changes, those whose files or tests changed; then all of them, N1–N13, B and A1–A3, on PR 1's head once its reviews are done, started as its last round is pushed (planning.md §4).
5. Have a model of another family review it (`AGENTS.md` §5). Commit as PR 1's title, with a body that says why the golden digests change (docs/ROADGEN.md §6.1, U7) and names the tests and the negative cases. Push, and open the PR with base `main`.

### PR 1: Areas: the road to the sea in five minutes **Δ U1–U8, U10, U11, U13**

Title `areas: the road ends after 100 turns, with longer straights, a faster top speed and 60 s days (SP PR 1)`. Branch `sp/1-road`, from `main` (§4.1).

| Area | Files |
|---|---|
| Areas | `areas/schedule.tres`: the areas at turns 20, 44, 68 and 78, and the pier after turn 100 (§5.1). `areas/schedule_home.tres`: its mirror, at 22, 32, 56 and 80. `areas/meadows.tres` and `areas/desert.tres`: their straights, and `day_seconds = 60.0`; the Desert's decoys at 0.15 and side roads at 0.3 (Q14, U13). `areas/village.tres`: its straights. `areas/rural.tres`: `day_seconds = 60.0` (§5.2, §5.3) |
| Car | `config/tuning.gd`:67: `TOP_SPEED_GROWTH` 0.0035, from 0.002 (Q4, U4; §5.2) |
| UI | `ui/route_strip.gd`:7: "a few pixels a turn" (§5.4) |
| Props | `world/prop_layout.gd`'s `span()` and `world/prop_scatter.gd`, with `PROP_VIEW_SPREAD`, 3 tiles, in `config/tuning.gd`: each row of props spreads across the view from each path tile below it, along the long straights. `test_prop_layout.gd` and `test_props_in_view.gd` check it (§4.3, Copilot's A) |
| Tests | The 17 files of §5.7: E1's times, E2's straights, E3's nights, E6's strip, E4's growth, 0.0035 a tile, and the new turns, digests and times |
| Docs | §5.8's Δs to `plan.md`, docs/ENDGAME.md, docs/DAYNIGHT.md, docs/ROADGEN.md and docs/TUTORIAL.md (U12), and its review's to docs/M4.md and docs/M5.md |

The prototype's 25 files, +216 −146, and the docs. Expect, against `main` at 4a50bb2: the same 221 scripts loaded and 103 test scripts; 904 tests, one more; 523,161 asserts, 66,620 more, as `test_road_generator_pattern.gd`'s tests assert each tile of `endless()`'s road to turn 300, which is longer from turn 44, 67,496 more; GUT 139.5–147.4 s locally, against 138.5 s; and `autopilot: tile 177, turns 32, area rural`, where `main`'s is `tile 165, turns 35`. Negative cases N1–N12. With §4.3's fixes and `main`'s #117, merged in 7854cfd, and #119, in 3b79952, PR 1 has 35 files besides this one, +421 −206. On 3b79952, whose code its head keeps: 223 scripts loaded and 104 test scripts, as #119 adds `world/headlights.gd` and its test; 916 tests and 524,238 asserts; GUT 146.4 s locally; the same `autopilot:` line; and N1–N13, B and A1–A3, whose run its body gives (§6.2).

**Acceptance:** E1–E6, E8, E9.

### PR 2: Docs: `docs/SPEEDUP.md` replaces the plan

Title `SP PR 2: docs/SPEEDUP.md replaces the plan`. Branch `sp/2-docs`, from `main`, once PR 1 has merged (Q12).

| Area | Files |
|---|---|
| Docs | `docs/SPEEDUP.md`, new, at most about 15 KB: the design as built, with every ID that code, tests or docs cite, E1, E3, Q15, §5.4 and the U#s and P#s that they cite, and a header that gives `git show <sha>:SPEEDUP_PLAN.md` (planning.md §6). The code's cites of `SPEEDUP_PLAN.md` become `docs/SPEEDUP.md`'s, the same length. `SPEEDUP_PLAN.md`, deleted |
| Owner's paths | `AGENTS.md`: the pier after the road's 100th turn (:7), U# (SPEEDUP) among the IDs (:18), and eight plans merged, with SP's PRs (:20). `docs/README.md`: SP's row, and ENDGAME's row's "after 280 turns" |
| Guidelines | Up to five of SP's learnings, each where an agent reads it as it works: `AGENTS.md` §2, `.github/instructions/` or docs/agents/ (planning.md §7) |
| IP | Eight smaller plans, with SP's (:101); M7.6's screenshots at turns 0, 20, 44, 68 and 78 (:209, :320); the schedule test's row, "Area switches at 20/44/68/78" (:249); and M7's notes from §9 |

No code, so the counts are PR 1's. PR 2 checks each sentence of `docs/SPEEDUP.md` against the plan and the code (planning.md §6), and takes the learnings step that #115 added (planning.md §7): it gathers what SP's PRs and sessions taught, picks five at most, changes the guidelines with them, and lists them in its body.

**Acceptance:** E7, E9.

### 4.2 Landing (Q13)

This plan's PR and PR 1 both target `main`, so there is no stack: PR 2 starts from `main` once PR 1 has merged. The owner lands both: PR 1 as the plan's last code PR, after §6.4's optional run on the Fold4, and PR 2, which changes `AGENTS.md`, `docs/README.md` and IP (`AGENTS.md` §5 step 4). If the owner answers Q13 otherwise, agents land PR 1 with `tools/agent/land_pr.sh` once its reviews are done.

**Labels.** This plan's PR, PR 1 and PR 2 each get `needs-owner` as they open, with a PR comment that says why: the owner lands plan PRs, this section marks PR 1 unless Q13's answer is otherwise, and PR 2 changes `AGENTS.md`. Only the owner removes it.

The plan changes only on `sp/plan` until its PR merges. After that, PR 1 carries the plan's final sync: its status, §4.3's rows, the counts and §6.4's results (planning.md §5). PR 2 deletes it.

### 4.3 Review fixes

Fixes from the prototype's build, the internal review (§4.4), the owner's answers and the PRs' reviews, each with its tests and negative case.

| PR | Change | Tests | Negative case |
|---|---|---|---|
| 1 | 6740ac4: the strip's test compares each climb, an int, with `floori()` of half the car's mark, where 529378c's float made GUT warn "Float/Int comparison"; the climbs are whole pixels, so the rule is the same (§5.4) | `test_the_route_strip_marks_each_area_the_car_and_the_best` | N4, which still fails it; no GUT warning |
| 1 | P8: SP's Desert makes `test_autopilot_300_turns.gd`'s 300 turns slower, so 9229f94 gives each drive a cap of twice its own time (§4.4 #6), and 98ffdd5 keeps that for the owner's turns: 27 minutes for `endless()`'s 300 turns, 758.8–833.6 s, and 16 for the road with every kind of junction, 476.2–495.8 s as on `main` (U11) | Its two tests: 2/2, 100 asserts, as on `main` | None: a cap only stops a car that never ends |
| 1 | a130c54 (§4.4 #1): P10 found home seed 3879 at 301.6 s, its Desert zone with 15 decoys among 31 junctions. The Desert's straights become 6–12 tiles, from 6–14, its decoys 0.15, from 0.2, and its side roads 0.3, from 0.25 (U13, Q14) | `test_the_game_road_matches_its_digests`; `test_from_the_meadows_on_the_straights_are_longer_than_rurals` | N11: 339b126's `desert.tres` |
| 1 | 9229f94 (§4.4 #1, #3): `test_drive_to_the_end.gd` also drives each road's slowest seed of P1, then 2823 to the pier and 3879 home, and counts `damaged`, where 339b126 read the health at the end, which a pit stop repairs | `test_the_autopilot_drives_to_the_pier`, `test_the_autopilot_drives_the_road_home` | N10, damage at each drive's start, fails "no damage" on each drive, and passed 339b126's test |
| 1 | 68ef177, the owner's answers to Q1, Q4 and Q9: the schedules at 20, 44, 68 and 78, and home at 22, 32, 56 and 80; `TOP_SPEED_GROWTH` 0.0035; and the 17 test files' turns, times and digests. `test_car_sim_speed.gd` checks the growth at 500 tiles, as at 1,000 it would pass the cap | The 17 files of §5.7 | N1 and N8, the old schedules; N12, the old growth, since 98ffdd5 (below) |
| 1 | 98ffdd5: P1, run again with the owner's turns, found pier seed 4993 at 306.4 s, its Meadows with 14 decoys among 38 junctions (U13). With Q15's default, five minutes is a target: `test_drive_to_the_end.gd` drives each road's new slowest seed, 4993 to the pier and 352 home, within `SLOWEST_SECONDS`, 310 s, with a comment that says why, and its 10 seeds a road within `MOST_SECONDS`, 300 s. The drives to turn 90 and Keep Driving's get caps of twice their new times | `test_the_autopilot_drives_to_the_pier`, `test_the_autopilot_drives_the_road_home`; `test_area_order.gd`, `test_autopilot_300_turns.gd`, `test_set_pieces_on_the_road.gd` | N9, a bound of 300 s on the slowest seeds, fails only 4993's time; N12, the old growth, fails it at 310.8 s |
| 1 | 8205270 (§4.4): the growth test expected `BASE_TOP_SPEED + 500.0 * TOP_SPEED_GROWTH`, which holds for any growth. It now expects 0.0035 a tile as a number: 5.75 tiles/s at 500 tiles | `test_the_top_speed_grows_with_the_run_up_to_the_cap` | A growth of 0.003, "[5.5] expected to equal [5.75]"; N12 fails it too, at 8205270 |
| 1 | bcf3a8e (PR 1's internal review #1): `test_autopilot_300_turns.gd` read each drive's health at its end, which a pit stop repairs, and now counts `damaged` | `test_300_turns_on_20_seeds`, `test_300_turns_through_every_kind_of_junction` | N13, 10 health taken at turn 5 and repaired at 20, fails both; the old check failed only the second |
| 1 | 99eb5d0, [Copilot's A](https://github.com/pompomon/roadgame/pull/118#discussion_r4647924974): a decoy joins two of the Meadows' or the Desert's straights into a run of up to 25 tiles, and the tallest view went up to 370 px past a row's `PROP_SPREAD` tiles, onto bare ground. `PropLayout.span()` spreads a row also `PROP_VIEW_SPREAD`, 3 tiles, either side of each of the `PROP_AHEAD` path tiles below it, which the car drives while the row may show: up to 15 tiles a side, for 2–6% more sprites there. The rows in view must reach `MARGIN` past it, as the camera lags 27 px farther across at `GLOBAL_SPEED_CAP`. The two drives count the props shown past `PROP_SPREAD` (§4.4) | `test_a_row_spreads_across_the_view_from_each_path_tile_below_it`; `test_props_reach_across_the_tallest_view_in_the_meadows` and `…_in_the_desert`, new, and `test_nothing_comes_or_goes_in_the_tallest_view` | A1, spans of `PROP_SPREAD` only, fails the four; A2, `row()` on `PROP_SPREAD` only, the first three; A3, `PropScatter` dropping each prop past `PROP_SPREAD`, both drives |
| 1 | 99eb5d0, [Copilot's B](https://github.com/pompomon/roadgame/pull/118#discussion_r4647925044): `test_road_generator_determinism.gd` compared 2,000 path tiles of `schedule()`, which reaches the pier at about tile 900 and has no junction past it. Its two comparisons take `endless()`, whose 2,000 tiles reach about turn 200 | `test_same_seed_same_road`, `test_buffer_refills_and_frees_do_not_change_the_road` | B, dead ends of another length past turn 120, fails both and the golden digests, whose road runs to turn 300; the old two passed it |

[Copilot's C](https://github.com/pompomon/roadgame/pull/118#discussion_r4648392076), on 7854cfd, is declined, with its thread left to the owner: on a first run, the tutorial's road can hold the 20th turn, and Rural then comes at the City's first junction past it, a turn or two late. That is docs/TUTORIAL.md §5.5's fallback, which `test_an_entry_due_on_the_tutorials_road_comes_after_its_last_group` checks, and it takes at least 17 of the tutorial's turns in the 38–56 tiles laid past its switch. With the City's straights forced to 2, the road held 18 and Rural came at turn 21; with its own, seeds 0–9,999, each switching after a tutorial without a mistake, held 6–15 at the switch, and Rural came at turn 20 on each. A model of the tutorial's straights, which matches that probe, puts it at 1.5e-7 of such runs. A bound would change the tutorial's road or the buffer, which Q8 keeps, and E1 counts the run without the tutorial (Q10). docs/TUTORIAL.md Q15 says so (§8).

### 4.4 Internal review

gpt-6.2-sol (`rubber-duck`), a model of another family, reviewed the first draft and the prototype three times, at 339b126, at 9229f94 and on its fixes (`AGENTS.md` §5). Each finding was checked before it was fixed or declined; `git show eb4a788:SPEEDUP_PLAN.md` §4.4 gives each in full.

| # | Finding | Change |
|---|---|---|
| 1 | E1's five minutes were a sample, while a zone's decoys have no bound | a130c54's Desert (U13, Q14); P1 on 5,000 seeds a road; each road's slowest seed driven, and N9 (§4.3); Q15 |
| 2 | The Road Home's first zone, the Desert, loses its 60 turns | Q2, with the mirror as its default |
| 3 | E1 timed the simulation, and its health at the end passed damage that a pit stop repaired | 9229f94 counts `damaged` (N10). The scene steps the run's clock and the car in the same physics frames (`main.gd`:138–143, `car_controller.gd`:42–43), as `test_arrival.gd`:42 checks |
| 4 | E3 and E8 overstated the night | E3 reworded; each frame of the movies sampled (§6.4) |
| 5 | Old saves: the goal line clamps the most turns of any whole run, and `record_arrival()` keeps the least time | §5.5, Q7 and E6 reworded |
| 6 | Keep Driving gets slower, and the cap of its unchanged drive rose too | Q11 says how much; each drive's cap at twice its own time (§4.3) |
| 7 | The plan's sync, the labels, the negative cases on the reviewed head, N7's out-of-memory | §4.1 steps 3–4, §4.2, §6.2 |

Its later passes found seven more, A–G, each fixed: the model's Road Home ended with the Coast's straight, not the City's (§5.2); Q10's wording and the clock's cites; Q2's alternative claimed more than P2 modelled; PR 1 left out U13's decoys and side roads (§4, §5.2); the goal line's best turn, `best.turns` (§5.5); §6.4 read the light's rate from each frame's mean, and now looks only for pulses of 1 to 30 frames, leaving the rate to the tests; and the scope promised a cap, where Q15's default is a target.

Three findings were declined, with what was checked (eb4a788 §4.4): a drive of the whole scene to each road's end (#3), more checks of the nights (#4), and caps at the drives' own times (#6). Its last pass on the first draft found nothing open.

**The owner's answers.** It reviewed this revision too, with 68ef177 and 98ffdd5, and found seven, each checked and fixed: E1's bound of 310 s on the slowest seeds, against the first draft's 300 s, which merging accepted (§7, Q15, §9); a port pinned to 8205270 (§4.1); the probes and the model, now in `tools/sp/` (§6.5); four sentences on the days (§5.1, §5.3, §5.8, §8); the growth test, which held for any growth (8205270, §4.3); Q10's 329 s; and §6.1's script times. Its pass on the fixes found three more, each fixed: `neg.py` gets a worktree of its own (§6.2), a variant re-bases the negative cases (§4.1 step 2), and F's wording.

**PR 1 (#118).** gpt-6.2-sol (`code-review`) reviewed 2e7b745 and found six, each checked: `test_autopilot_300_turns.gd` read the health at the end, which a pit stop repairs (bcf3a8e, N13, §4.3); DAYNIGHT's note on the nights read as a bound; M4's gaps and its run from Rural; old saves' farthest turn in ENDGAME §5.17; E6's digests; and "10,000 seeds", where P1 drove 5,000 a road (§5.8). bcf3a8e fixes them, but for one part of the second, declined: DAYNIGHT's first night in Rural predates the Road Home, and SP leaves each road's first night where it was (§5.3). Its pass on bcf3a8e found nothing, and its review of the fixes for Copilot's A, one: the drives checked each row's `span()`, not the sprites shown, so 99eb5d0 counts those too (A3). Its review of the docs' sync, 01a0d8f, found six, each checked, and the next commit fixes them: the late Rural's model covers first runs without a mistake, and E2 now names it; N13's five other failures in the whole suite; the port from the prototype, in the header and §4.1; PR 1's props, docs and counts, in its table and §4's overview; and the props in §6.4's note; and §3's and §4.1's wording from before #116 merged. The sixth, `test_daylight_run.gd`:129, is the rate's assert at ec6f54d, where this plan's lines are, so only §6.4's, whose run is at 3b79952, now names its test.

---

## 5. Design

§5.1–§5.6 describe PR 1 as built on the prototype, §5.7 its tests and §5.8 its Δs to the docs. The design follows tested principles: an end that a player can reach, Mark Rosewater's inertia, about four minutes away (§5.1); tension that rises and falls toward a climax, Jesse Schell's interest curve, with the Village's 26 s as a rest before the Desert (§5.1); a whole run in a short sitting, as mobile games have it (E1, Q15); and a world that tells its story, Rosewater's flavor, with each long zone's night (§5.3).

### 5.1 The turns (PR 1; Q1, Q2, Q9; U1, U3; E1, E2, E5)

The road to the sea, `areas/schedule.tres`, with P1's times on 5,000 seeds and P5's for `main` on seeds 0–19:

| Area | From turn | Turns | Way in | Straights | Day | Time, P1 (mean) | A turn | `main`: turns, mean time |
|---|---|---|---|---|---|---|---|---|
| City | 0 | 20 | — | 2–5 | 120 s | 30.6–39.7 s (35.2) | 1.76 s | 34, 57.9 s |
| Rural | 20 | 24 | The tunnel, a pit stop | 3–7 | 60 s | 41.0–69.2 s (50.3) | 2.10 s | 66, 135.8 s |
| Meadows | 44 | 24 | The bridge, a pit stop | 6–12 | 60 s | 58.0–109.1 s (73.7) | 3.07 s | 100, 217.0 s |
| Village | 68 | 10 | — | 4–8 | 120 s | 18.9–44.7 s (26.1) | 2.61 s | 20, 39.0 s |
| Desert | 78 | 22 | Last Gas, a pit stop | 6–12 | 60 s | 49.5–89.6 s (63.1) | 2.87 s | 60, 136.1 s |
| Coast | 100 | — | — | 20 | 120 s | 3.6–3.7 s (3.6) | — | 3.6 s |
| The road | | 100 | | | | 223.1–306.4 s (252.2) | | 280, 562.2–613.3 s (589.4) |

The Road Home, `areas/schedule_home.tres`, is its mirror (Q2): `mirrored`, starting W (docs/ENDGAME.md W9), with the same turns in reverse, Last Gas into the Village and the set pieces into Rural and the City:

| Area | From turn | Turns | Way in | Time, P1 (mean) | A turn | `main`: turns, mean time |
|---|---|---|---|---|---|---|
| Desert | 0 | 22 | — | 52.7–100.3 s (68.5) | 3.11 s | 60, 142.5 s |
| Village | 22 | 10 | Last Gas, a pit stop | 18.9–49.4 s (26.0) | 2.60 s | 20, 38.8 s |
| Meadows | 32 | 24 | — | 60.0–99.2 s (75.1) | 3.13 s | 100, 219.0 s |
| Rural | 56 | 24 | The bridge, a pit stop | 41.1–68.3 s (50.1) | 2.09 s | 66, 136.6 s |
| City | 80 | 20 | The tunnel, a pit stop | 28.0–39.1 s (33.4), with the last straight and home's tiles | 1.67 s | 34, 56.5 s |
| The road | | 100 | | 222.2–294.5 s (253.1) | | 280, 561.4–614.0 s (593.3) |

What the owner's turns do:
- **The City, shorter.** Its 20 turns take 35 s after the tutorial, where its 34 took 58 s, so Rural, its tunnel and its first night come 23 s sooner. The tutorial, which teaches the pattern, stays before them (§5.6).
- **The straights cost time.** The owner asked for longer straights from the Meadows on: §5.2's model puts the owner's 100 turns at 209.2 s to the pier and 207.0 s home on average with `main`'s straights, and at 253.0 s and 254.1 s with SP's, so the straights add 44–47 s. The top speed's growth (Q4) takes 3.5–4.1 s off (§5.2).
- **The margin.** On 5,000 seeds a road, the time's standard deviation was 10.15 s to the pier and 10.20 s home, so the means are 4.6–4.7 of them below 300 s. 250 runs to the pier and 294 home took more than 270 s, 41 and 36 more than 280 s, and 3 each more than 290 s. One took more than 300 s: pier seed 4993, at 306.4 s, 5.3 standard deviations above the mean, as a zone's decoys vary widely (U13); the slowest home, seed 352, took 294.5 s. E1's ten seeds a road take 235.0–255.5 s to the pier and 239.4–280.9 s home. §5.2's model puts about one run in 20,800 over 300 s; V4, V2 and V7 would leave a margin (Q15, §9).
- **Long enough for a night.** Rural's 24 turns take 50 s, the Meadows' 24 take 74–75 s and the Desert's 22 take 63–68 s, by road, so each of their zones lasts past its night's start, 32.5 s in with §5.3's 60 s days. The Village stays an interlude before the Desert: its 10 turns take 26 s, 10% of the run, where its 20 took 39 s, 7% (Q9).

The order of the areas, their set pieces, Last Gas and the pit stops' rule stay (Q8). On the road to the sea, the pit stops come after turns 20, 44 and 78, 24 and 34 turns apart, where they came 66 and 120 apart; on the Road Home, after turns 22, 56 and 80, 34 and 24 apart. A Departure from an area (docs/ENDGAME.md §5.11) has as many turns fewer to the end: from the Desert 22 turns to the pier, the Village 32, the Meadows 56 and Rural 80; on the Road Home, from the Village 78 turns home, the Meadows 68, Rural 44 and the City 20.

`validate()` (`area_schedule.gd`:48) keeps each area's gap, its set piece, its longest straight and the next junction's tile (`gap()`, :113), within `BUFFER_REFILL_AT`, 37 tiles (docs/M2.md H31, docs/M4.md K1). SP's widest is the Meadows' 18, behind the bridge (5 + 12 + 1), and the Coast's 21 as on `main`; on the Road Home, 13: the Desert's and the Meadows' (12 + 1), and Rural's, behind the bridge (5 + 7 + 1). No rule binds the switch turns' parity: a set piece takes the heading of the straight it replaces (`set_piece.gd`:21). The owner's, like `main`'s, are all even, so each area starts with the same turn as on `main`, a left on the road to the sea.

### 5.2 Straights and speed (PR 1; Q3, Q4, Q14; U4, U13; E2)

The car sets its own speed: the player only steers (`input_router.gd`:3–16). `target_speed()` (`car_sim.gd`:250–259) starts each straight at its area's `junction_speed` and rises by its `straight_accel` for each tile driven on it, up to the run's cap, `minf(GLOBAL_SPEED_CAP, BASE_TOP_SPEED + dist_total * TOP_SPEED_GROWTH)`: 4.0 tiles/s at the start, 0.0035 more a tile driven, where `main` has 0.002 (Q4), and at most 7.0 (`tuning.gd`:65–68). Within `junction_brake_distance` of the next junction, it is `junction_speed` again. `_update_speed()` (:262–277) moves the car's speed toward it at `ACCEL`, 2.0 tiles/s², or `BRAKE`, 4.0 (`tuning.gd`:69, :72), and before a junction brakes harder if it must, to enter the junction's tile at `junction_speed`. A turn's braking and corner cost the same on any straight, so a longer straight takes less time a tile: the car reaches a higher speed and holds it longer. The generator draws each straight's length from its area's `min_straight`..`max_straight`, with the road's stream, `_rng_road` (`road_generator.gd`:417–418). SP changes the ranges, and the Desert's decoys and side roads (Q14, U13):

| Area (road to the sea) | Straights, tiles | Path tiles a turn | Mean speed, tiles/s | Mean top speed, tiles/s |
|---|---|---|---|---|
| Rural | 3–7, unchanged | 6.7 → 6.9 | 3.27 → 3.27 | 5.08 → 4.84 |
| Meadows | 3–7 → 6–12 | 7.1 → 11.8 | 3.27 → 3.83 | 5.34 → 5.80 |
| Village | 2–5 → 4–8 | 5.35 → 8.3 | 2.74 → 3.17 | 4.25 → 5.46 |
| Desert | 3–8 → 6–12 | 8.0 → 11.7 | 3.54 → 4.09 | 5.79 → 6.83 |

`main`'s values are P5's, on seeds 0–19, and SP's P1's, on 5,000 seeds. Each area's `straight_accel`, `junction_speed` and `junction_brake_distance` stay. The new test, `test_from_the_meadows_on_the_straights_are_longer_than_rurals`, checks E2's rule on each entry of the road from the Meadows on, the Coast's 20 tiles included: its shortest and longest straights are longer than Rural's, 3 and 7. SP's are about twice `main`'s at their short end and less at their long end, and the Village's, which are the defaults' 2–5 on `main` (`area_def.gd`:14–15), become 4–8, above Rural's as E2 asks.

**The model, P2** (`tools/sp/model.py`, §6.5). It draws roads as the generator does, the turns, the decoys and each straight from its area's range, and moves the speed toward `target_speed()` at 60 Hz along each straight, as `_update_speed()` does. It leaves out the corners, the dead ends and the set pieces' shapes. Each road ends with the straight after its last turn, the last area's, to the finish's first tile: the Coast's 20 tiles to the pier, and the City's 2–5 home (`road_generator.gd`:24–25, :219–230). Against P1's 5,000 seeds a road, it runs about 0.4% slow on average, and −0.4 to +2.5 s off at P1's p99 and p99.9, so its tail follows the game's as far as P1 reaches, one run in a thousand. Past that, nothing checks it against the game (Q15, §8). On 20,000 runs a road:

| Case | To the pier: mean | p99 | Slowest | Over 300 s | Home: mean | p99 | Slowest | Over 300 s |
|---|---|---|---|---|---|---|---|---|
| `main` | 593.6 s | 630.6 s | 653.8 s | all | 593.2 s | 630.4 s | 658.3 s | all |
| The owner's turns, with `main`'s straights | 209.2 s | 229.8 s | 246.8 s | 0 | 207.0 s | 227.9 s | 243.3 s | 0 |
| SP | 253.0 s | 278.6 s | 298.8 s | 0 | 254.1 s | 279.3 s | 299.0 s | 0 |
| Twice `main`'s straights, Q3's alternative: the Meadows 6–14, the Village 4–10, the Desert 6–16 | 268.1 s | 296.2 s | 330.2 s | 99 | 271.3 s | 299.7 s | 324.0 s | 188 |
| The Desert's decoys at 0.2 and side roads at 0.25, Q14's alternative | 257.2 s | 284.0 s | 304.9 s | 5 | 258.3 s | 285.7 s | 305.2 s | 5 |

All but `main` grow the top speed by 0.0035 a tile. On a million runs a road, SP took 253.1 s on average to the pier and 254.1 s home, 288.1 s and 289.5 s at p99.9, and 296.8 s and 298.3 s at p99.99; 39 runs to the pier and 57 home took more than 300 s, about one in 20,800, and 1 and 6 more than 310 s, the slowest 315.7 s and 312.8 s.

**The variants (Q15).** Each would be a change to PR 1 that P1 then checks again. On 200,000 runs a road:

| # | Change | Ends after turn | To the pier: mean | Slowest | Over 300 s | Home: mean | Slowest | Over 300 s |
|---|---|---|---|---|---|---|---|---|
| V0 | None: SP | 100 | 253.1 s | 302.5 s | 3 | 254.1 s | 304.2 s | 9 |
| V2 | The Meadows 20 turns | 96 | 241.0 s | 290.5 s | 0 | 242.0 s | 297.3 s | 0 |
| V4 | The Meadows 22 turns and the Desert 20 | 96 | 241.4 s | 289.5 s | 0 | 242.2 s | 296.9 s | 0 |
| V7 | The Meadows' and the Desert's straights 6–10 | 100 | 243.9 s | 298.2 s | 0 | 244.0 s | 297.4 s | 0 |
| V10 | Growth 0.002 a tile, Q4's alternative | 100 | 257.2 s | 307.1 s | 23 | 257.6 s | 308.4 s | 31 |

V4, V2 and V7 put none over 300 s, and take 9–12 s less on average; V4 and V2 keep the owner's straights, and V7 the owner's turns. Smaller changes each left one or two runs over 300 s on one road or both: V1, the Meadows 22 turns; V3, the Desert 20; V5, the Meadows' straights 6–10; V6, both areas' 6–11; V8, growth 0.005 a tile; and V9, the Meadows' decoys 0.1. A faster car or fewer decoys do little, as the time is in the turns and the straights.

**The top speed (Q4, U4).** A run is now 786–1,111 path tiles to the pier, not 1,829–1,998 (P5), so with `main`'s growth the cap would end at 5.57–5.99 tiles/s at the pier, not 7.0, and the Desert's mean top speed would fall to 5.69 tiles/s, against 5.79 on `main` (P6). The owner's 0.0035 a tile reaches 7.0 after 857 tiles: the cap ends at 6.64–7.0 tiles/s at the pier and 6.57–7.0 home, and 3,176 of P1's 5,000 runs to the pier and 2,109 home reach 7.0. The Desert's mean top speed to the pier is 6.83 tiles/s, and 4.86 on the Road Home, which starts in the Desert. On seeds 0–199, P6 put a run 4.1 s quicker to the pier and 3.5 s home on average than at 0.002, and the slowest 4.3 s and 3.9 s quicker: the junctions and corners take most of a turn's time. The growth changes the car on every road, Keep Driving's too (§5.6).

### 5.3 Days (PR 1; Q5; U2, U10; E3)

A zone's clock starts at 07:00 as the car enters it (`DAY_START_HOUR`, `tuning.gd`:247) and turns a whole day in its area's `day_seconds`, 120 s by default (`area_def.gd`:71). `rural.tres`, `meadows.tres` and `desert.tres` set `day_seconds = 60.0`; the City, the Village and the Coast keep 120 s. The light's keys (`LIGHT_HOURS`, `tuning.gd`:251) fall at:

| Hours | The light | A 120 s day | A 60 s day |
|---|---|---|---|
| 07:00–17:00 | Day, white | 0–50 s | 0–25 s |
| 17:00–20:00 | Dusk: orange at 18:30, then the night's blue | 50–65 s | 25–32.5 s |
| 20:00–04:30 | Night | 65–107.5 s | 32.5–53.75 s |
| 04:30–07:00 | Dawn: pink at 06:00, then white | 107.5–120 s | 53.75–60 s |

`DayCycle.least_day_seconds()` (`day_cycle.gd`:127–135), 55.68 s, is the shortest day whose light changes within `LIGHT_MAX_RATE`, a quarter of white a second, so that the light shown follows the clock exactly (docs/DAYNIGHT.md §5.3). `AreaDef.validate()` (`area_def.gd`:105–110) reports a shorter day, as N7 shows. A 60 s day's steepest change uses 92.8% of the rate.

**Why 60 s (P3).** The share of the zones of Rural, the Meadows and the Desert, in P1's 10,000 runs, that reached the night:

| Zones | 120 s | 90 s | 80 s | 60 s |
|---|---|---|---|---|
| Rural, to the sea | 0.06% | 63.4% | 98.8% | 100% |
| Meadows, to the sea | 93.2% | 100% | 100% | 100% |
| Desert, to the sea | 33.8% | 100% | 100% | 100% |
| Rural, home | 0.04% | 60.0% | 98.8% | 100% |
| Meadows, home | 96.3% | 100% | 100% | 100% |
| Desert, home | 69.7% | 100% | 100% | 100% |
| All 30,000 | 48.9% | 87.3% | 99.6% | 100% |

At 60 s, each reached it. The shortest, a Rural zone of 40.97 s on the road to the sea, had 8.47 s of night, and the Desert's shortest, 49.48 s, 16.98 s (§8). A zone's night lasted 17.2–21.3 s on average, by area and road, and the night was 23.8% of a run to the sea and 23.6% of one home. Rural's zones are the shortest: at 90 s, each of the Meadows' and the Desert's zones would reach the night, but only 60–63% of Rural's. The City's day stays 120 s: its zones end by day, at 12:36–14:56, so a run to the sea's first night still comes in Rural, and one home's in the Desert (docs/DAYNIGHT.md §5.8). The Village's 26 s and the Coast's 3.6 s end by day too.

**Longer zones.** With the Meadows' 24 turns and the Desert's 22, most of their zones outlast a 60 s day. 18,234 of the 30,000 zones, 60.8%, lasted past 60 s, into a second morning: each of the Meadows' but 16, and 81% of the Desert's. 746 lasted past 85 s, into a second dusk, and 80 past 92.5 s, into a second night: 78 of the Meadows' and 2 of the Desert's. A day that comes round again is what a zone's clock does on `main` in a long zone too (docs/DAYNIGHT.md §5.1). With 80 s days in the Meadows and the Desert, and 60 s in Rural, each zone would still reach its night, the Desert's shortest with 6.2 s of it, and 10.5% of the Meadows' and the Desert's zones would outlast their day, not 90.5% (Q5's alternative).

**The light between zones (U10).** A zone that ends at night hands over to the next zone's morning, which `Daylight` fades in within `LIGHT_MAX_RATE`, in 2.33 s (docs/DAYNIGHT.md Q2). How the zones end (P4):

| Zones | Night | Dawn | Day | Dusk |
|---|---|---|---|---|
| Rural, to the sea | 82.4% | 16.4% | 1.2% | — |
| Meadows, to the sea | 0.6% | 0.3% | 94.3% | 4.8% |
| Desert, to the sea | 2.5% | 28.7% | 68.7% | 0.1% |
| Rural, home | 84.0% | 14.7% | 1.4% | — |
| Meadows, home | 0.9% | 0.02% | 91.7% | 7.3% |
| Desert, home | 0.06% | 6.2% | 92.6% | 1.2% |

28.4% of them end at night, where 39 of P5's 120 on `main` did, 32.5%. The movie of §6.4 shows the fades, and `test_daylight_run.gd`:129 asserts their rate each frame.

### 5.4 The route strip (PR 1; Q6; U5; E6)

The strip (`ui/route_strip.gd`, docs/ENDGAME.md §5.14) stays 40% of the HUD's height (`hud.tscn`:66–68): 256, 320 and 368.8 pixels on the reference screens, 640, 800 and 922 pixels high. `RouteStrip.height()` (:64–68) places turn t at `roundi(t / finish_turn * roundi(length))`, so over 100 turns its car climbs 2.56, 3.2 and 3.69 pixels a turn on average, 2–3, 3–4 and 3–4 pixels each, where `main`'s 280 turns gave 0.91–1.32. Its ticks are at turns 0, 20, 44, 68, 78 and 100; the closest, the Village's and the Desert's, are 10 turns apart, 25.6–36.9 pixels.

The car's mark is `CAR_HEIGHT`, 8 pixels, high. `test_the_route_strip_marks_each_area_the_car_and_the_best` drives the strip's car over 100 turns on each reference screen, and checks that each climb is the strip's rounded length over 100 turns, rounded down or up, so the car climbs evenly, and at most `floori(CAR_HEIGHT / 2.0)`, 4 pixels, so that each step overlaps the last by half the mark. `main`'s test allowed 0–2 pixels, a pixel or so a turn. The comment at `route_strip.gd`:7 says "a few pixels a turn". The test's HUD, sized by `PIXEL_A_TURN` so that its strip is a pixel a turn, becomes 250 pixels high, for a strip of 100, from 700. With a strip of 80% (N4), the car climbs 5.12–7.38 pixels a turn, which the test rejects.

### 5.5 The save (PR 1; Q7; U8; E6)

Saves stay at version 5 (`save_data.gd`:14), and nothing in the save names the road's length but `V3_FINISH_TURN`, 280 (:51), which migrates version 3's saves, made when both roads had 280 turns: it stays. A save from `main` loads as it is:
- **The best time.** `record_arrival()` keeps the least time (:248), so an arrival after SP replaces `main`'s best time only if it is faster. On every seed measured, it would be: the autopilot took at most 306.4 s on the new road (P1) and at least 561.4 s on `main` (P5), and a player's seconds off the road, which their health limits (§8), don't close that gap.
- **The farthest turns**, up to 280, are kept as the most: each road's (:211, :251), and `best.turns`, the most of any whole run (:216). Until a first arrival at the sea, the goal line shows `best.turns`, clamped to the road's finish, `mini(best.turns, finish_turn)` (`game_over.gd`:125–127): a player who has passed turn 100 on `main` without arriving reads "Next: reach the sea. Your best: turn 100 of 100" until they arrive. The strip clamps the road's farthest (`route_strip.gd`:64–68), and `test_the_route_strip_shows_only_on_a_road_with_a_finish` checks it. `Hitchhiker.road_turn()` takes `mini(farthest, finish_turn)` on the Road Home (`hitchhiker.gd`:54–58), so a home farthest of 50, in `main`'s Desert, now places her before the 50th junction, in the Meadows: she still stands at the player's farthest junction, as docs/ENDGAME.md §5.17 has it.
- **History.** The overall best turns and the Atlas's bests (`atlas_screen.gd`:60–73) aren't clamped: an area's best turns on `main`, such as the Meadows' up to 100, can exceed its turns now, 24, and stay as they were driven.

Q7's alternative, version 6, would clamp each road's farthest turn and drop `main`'s best times: a migration and its tests for a Pages build whose players are few.

### 5.6 What stays (PR 1; Q8, Q11; U7, U9; E4)

- **The City.** Its area, straights and junctions are as on `main`, and the generator draws each straight from its area's range in turn, so on 200 seeds the road to the sea is `main`'s, tile for tile with its dead ends, up to and including the junction of its 20th turn, and differs by its 21st, as the tunnel now comes after turn 20 (P7). The Road Home starts in the Desert, whose straights and junctions change, so it differs from `main`'s by its 10th turn on each seed, and by its first on 45 of the 200. `smoke.sh`'s 60 s end in Rural at turn 32, where `main`'s ended at turn 35 (§6.1).
- **The golden digests** (U7) of `endless()` on seeds 0–19 to turn 300 change, as that road crosses Rural from turn 20, the Meadows from 44, the Village from 68 and the Desert from 78, with longer straights from the Meadows on and fewer decoys in the Desert: `PATH_DIGEST` becomes `26bb5444423b2ecd363fa41878138257` and `ROAD_DIGEST` `8a25266a9e6c179c218e5e1b0de21908`, and PR 1's commit says why (docs/ROADGEN.md §6.1).
- **The tutorial** (docs/TUTORIAL.md) comes before the City's 20 turns, from whose end the schedule counts, and doesn't change. On seeds 0–99, the autopilot finished it in 17.9–22.9 s, and arrived 252.1–294.1 s after its start, each with full health (P9; Q10).
- **Keep Driving** drives `endless()`, which runs the Desert forever from turn 78 (Q11). Its turns past 78 take longer than `main`'s Meadows', so `test_autopilot_300_turns.gd`'s 300 turns take 758.8–833.6 s, not 607.5–656.2 s (P8, §4.3); its drive with every kind of junction takes 476.2–495.8 s on both. Its car, like every run's, reaches 7.0 tiles/s after 857 tiles, not 1,500 (Q4).
- **Departures** start at their area's new turn (§5.1).
- **The legends** and their pools stay. Each area has fewer turns, so the City's share of a run's turns grows, from 12% to 20%, and more runs arrive (U9). An arrival unlocks a legend of any area's pool (docs/ENDGAME.md §5.5), and Departures reach the later areas' legends.
- **The music and the ambience** cross-fade on `area_changed`, as on `main`. Their loops last 7.27–10.67 s and 4.0 s, so the Village's zones, 18.9 s at the shortest, play its music's 10 s loop nearly twice or more.

### 5.7 Tests (PR 1)

| File | Change |
|---|---|
| `tests/unit/test_area_schedule.gd` | New: `test_from_the_meadows_on_the_straights_are_longer_than_rurals` (E2). Renamed: `test_areas_and_set_pieces_switch_at_20_44_68_and_78`, `test_the_games_road_ends_at_the_pier_after_its_100th_turn`. The new turns in each test of the schedules, the Road Home, the pit stops, Departures' copies and `validate()`'s finish (U6) |
| `tests/sim/test_drive_to_the_end.gd` | `MOST_SECONDS`, 300 s, asserted on each of `SEEDS`, 10 seeds a road, not 5 (E1); `SLOWEST_SECONDS`, 310 s, on each road's slowest seed of P1, `SLOWEST_TO_THE_PIER`, 4993, and `SLOWEST_HOME`, 352, with a comment that says why (Q15, U13); `damaged` counted, and none allowed, where `main` checked the health at the end, which a pit stop repairs (N10); `_check_night()` on each zone of `NIGHT_AREAS`, Rural, the Meadows and the Desert, that the car leaves (E3); `MAX_STEPS` twice `MOST_SECONDS`; 100 turns |
| `tests/unit/test_hud.gd` | The strip's even climb (§5.4), and the new ticks and turns |
| `tests/unit/test_car_sim_speed.gd` | The growth, 0.0035 a tile, checked at 500 tiles, as 1,000 would now pass the cap (Q4) |
| `tests/unit/test_road_generator_finish.gd` | Renamed: `test_the_road_home_ends_at_home_after_100_turns`; both roads' 100 turns |
| `tests/unit/test_road_generator_determinism.gd` | The new digests (§5.6) |
| `tests/integration/test_arrival.gd` | `--finish=20`, the City's 20 turns, and `--area=rural --finish=22`, Rural's first two |
| `tests/integration/test_area_start.gd` | The Village's 10 turns |
| `tests/integration/test_hitchhiker_run.gd` | Her departure at the Road Home's turn 24, in the Village from 22 |
| `tests/sim/test_area_order.gd`, `tests/sim/test_tutorial_run.gd` | The switches at 20, 44, 68 and 78, driven to turn 90, about 3.7 minutes, with caps of 8 (U11) |
| `tests/sim/test_set_pieces_on_the_road.gd` | Seed 1 meets the bridge after turn 44, and has left it by 49, in under 2 minutes, with a cap of 4 |
| `tests/sim/test_autopilot_300_turns.gd` | The comments, and each drive's cap at twice its time: 27 minutes for `endless()`'s 300 turns, about 13.5 (P8), and 16 for the road with every kind of junction, about 8, where both had 20 (U11) |
| `tests/unit/test_game_over.gd` | A best of turn 72 before the first arrival |
| `tests/unit/test_prop_scatter.gd` | Past the bridge after turn 44 |
| `tests/integration/test_daylight_run.gd`, `tests/integration/test_props_in_view.gd` | Comments: the zone of 60 s that the first enters is any area's, whatever Rural's own day; Rural at turn 20 |

The tests that use 280 as a value stay: `test_hitchhiker.gd`, `test_title.gd` and `test_hitchhiker_run.gd`:118–119 pass a finish or record an arrival of their own, and `test_save_data.gd` migrates version 3's saves (§5.5).

### 5.8 Docs (PR 1; Q12; U12)

PR 1 changes `plan.md`, the game's design, in place, and adds a note to each summary of a finished plan, as EG did ("Since EG, …", docs/ZONE_SELECT.md Z4), so that its history stays. Until PR 2, the notes cite `SPEEDUP_PLAN.md`; PR 2 makes them `docs/SPEEDUP.md`'s.

| Where | Δ |
|---|---|
| `plan.md`:13 | "After its 280th turn" → "After its 100th turn" |
| `plan.md`:121–125, §3.6 | The table's turns: Rural at 20, the Meadows at 44, the Village at 68, the Desert at 78 and the Coast at 100 |
| `plan.md`, after §3.6's table | A new first bullet: "From the Meadows on, the road turns less and runs straighter: each area's straights are longer than Rural's, the Meadows' 6–12 tiles, the Village's 4–8 and the Desert's 6–12, and the autopilot drives the whole road in about four minutes, and within five on all but one of the 10,000 runs measured, 5,000 seeds a road (`SPEEDUP_PLAN.md` E1, Q3, Q15)." |
| `plan.md`:229, §5.5 | "120 s by default: dusk comes 50 s into a zone, and the night at 65 s." → "120 s by default, and 60 s in Rural, the Meadows and the Desert: dusk comes 10/24 of a day into a zone and the night 13/24, at 50 s and 65 s in a day of 120 s, and at 25 s and 32.5 s in one of 60 s (`SPEEDUP_PLAN.md` Q5)." |
| `plan.md`:356, §9 | `"best_seconds": 581.0` → `252.0`, and `"farthest": 280` → `100` |
| `plan.md`:390, §11 | "turns 34, 100, 200, 220 and 280, and the road ends at the pier after its 280th turn" → "turns 20, 44, 68, 78 and 100, and the road ends at the pier after its 100th turn" |
| `plan.md`:429, §13 | "after turn 280" → "after turn 100" |
| docs/ENDGAME.md :3 | Adds: "Since SP, the road ends after its 100th turn, and the autopilot drives it in about four minutes (`SPEEDUP_PLAN.md` Q1)." |
| docs/ENDGAME.md :11, E6 | Adds: "Since SP, past turn 100, and SP's areas changed the digests (`SPEEDUP_PLAN.md` Q1, U7)." |
| docs/ENDGAME.md :47, Q1 | Adds: "Since SP, after its 100th turn (`SPEEDUP_PLAN.md` Q1)." |
| docs/ENDGAME.md :112, §5.6 | Adds: "Since SP, the Village from 22, the Meadows from 32, Rural from 56 and the City from 80, and `home` after 100 (`SPEEDUP_PLAN.md` Q2)." |
| docs/ENDGAME.md :120, §5.8 | Adds: "Since SP, the Coast starts at turn 100 (`SPEEDUP_PLAN.md` Q1)." |
| docs/ENDGAME.md :162, P1 | Adds: "Since SP, seeds 0–9: at the pier after 3.9–4.3 minutes, and home after 4.0–4.7 (`SPEEDUP_PLAN.md` E1)." |
| docs/ENDGAME.md :170, §8 | Adds: "Since SP, about four minutes, and at most five on all but one of the 10,000 runs measured, 5,000 seeds a road (`SPEEDUP_PLAN.md` E1, Q15)." |
| docs/DAYNIGHT.md :40, Q3 | Adds: "Since SP, 60 s in Rural, the Meadows and the Desert (`SPEEDUP_PLAN.md` Q5)." |
| docs/DAYNIGHT.md :99, §5.8 | Adds: "Since SP, Rural, the Meadows and the Desert turn a day in 60 s, so that their zones reach their night, 32.5 s in: all of P1's 30,000 did, the shortest lasting 40.97 s (`SPEEDUP_PLAN.md` Q5, P3)." |
| docs/ROADGEN.md :90, after §5.5's table | Adds: "Since SP, the straights are longer from the Meadows on: the Meadows' 6–12, the Village's 4–8 and the Desert's 6–12. The Desert's decoys fall to 0.15 and its side roads rise to 0.3, so that a Desert zone's junctions, and its time, vary less (`SPEEDUP_PLAN.md` Q3, Q14, U13)." |
| docs/TUTORIAL.md :47, Q15 | Adds: "Since SP, at the 20th (`SPEEDUP_PLAN.md` Q1)", unless the tutorial's road reaches it, about one first run in seven million (§4.3) |
| PR 1's review (§4.4) | Notes in docs/M4.md: K1's gaps, 6–21 (:15), and from Rural, the Meadows at turn 24 and the Desert at 58 (:62); docs/ENDGAME.md §5.17: an old save's farthest turn, up to 280 (:156, Q7); and docs/M5.md §5.6: `PropLayout.span()` (:102, §4.3) |

Unchanged, as history or still true: `plan.md`:154, the default day; docs/ENDGAME.md W6 (:25), which tells of 280 turns, :136, version 3's migration, and :140, Keep Driving's Desert; docs/DAYNIGHT.md :69, :137 (N39) and :152; docs/ROADGEN.md :78, whose K1 check builds its own schedules; and IP's M4.2 (:147), which tells what M4 built. PR 2 changes the owner's paths and IP (§4).

---

## 6. Verification

### 6.1 Checks and counts

The checks are `AGENTS.md` §3's five: the import, `check_scripts.sh`, `lint.sh`, GUT and `smoke.sh`. They ran locally with Godot 4.7.2 on `main` (4a50bb2), on 98ffdd5 and on the prototype's head, 17f5ff6, and in CI on PR 1's reference, 8205270, in run 44803243085, started by hand with `upload-builds`, whose `lint`, `test`, `export-web` and `export-android` jobs passed. 8205270 changes only the growth test's expected value (§4.3), and 17f5ff6 adds `tools/sp/`, which GUT doesn't run. `main`'s CI counts are its push's run, 44744015047. The first draft's commits, 529378c to 9229f94, are counted in `git show eb4a788:SPEEDUP_PLAN.md` §6.1.

| State | Where | Scripts loaded | Test scripts | Tests | Asserts | GUT time | Smoke |
|---|---|---|---|---|---|---|---|
| `main` (4a50bb2) | Local | 221 | 103 | 903 | 456,541 | 138.5 s | `autopilot: tile 165, turns 35, area rural` |
| `main` (4a50bb2) | Run 44744015047 | 221 | 103 | 903 | 456,541 | 134.3 s | The same |
| 98ffdd5 | Local | 221 | 103 | 904 | 523,161 | 139.5 s, and 141.0 s again | `autopilot: tile 177, turns 32, area rural` |
| 8205270 | Run 44803243085 | 221 | 103 | 904 | 523,161 | 135.5 s | The same |
| 17f5ff6 | Local | 226 | 103 | 904 | 523,161 | 147.4 s | The same |
| bcf3a8e, PR 1 | Local | 221 | 103 | 904 | 523,161 | 144.7 s | The same |
| 99eb5d0, PR 1 | Local | 221 | 103 | 907 | 524,071 | 143.9 s | The same |
| 7854cfd, PR 1 | Run 44827287418 | 221 | 103 | 907 | 524,071 | 134.9 s | The same |
| 3b79952, PR 1, with #119 | Local | 223 | 104 | 916 | 524,238 | 146.4 s | The same |

`lint.sh` found no problem, and would leave each of 17f5ff6's 226 files as it is; shellcheck isn't installed locally, but SP changes no shell script, and CI's `lint` job ran it. `smoke.sh` printed no error line, GUT reported no warning, and `git status --porcelain` printed nothing after the checks.

CI's `test` job took 3 min 33 s at 8205270, and 3 min 11 s at 98ffdd5, against 3 min 15 s on `main`'s push; on PR 1, 3 min 7 s at bcf3a8e and 3 min 17 s at 7854cfd. But CI's runners vary more than SP does: the first draft's runs of the same job took 3 min 22 s to 4 min 35 s (eb4a788 §6.1). So the local runs, on one machine, are the ones to compare. A second pair of local runs, back to back, took 145.8 s on `main` and 145.5 s on 98ffdd5, each script within 1.1 s of its time on `main` but `test_autopilot_300_turns.gd`, 3.5 s slower, as Keep Driving's 300 turns take longer (§5.6), and `test_world_renderer.gd` and `test_road_generator_tutorial.gd`, 2.1 s and 1.6 s quicker.

### 6.2 Negative cases

Each case makes one change to the prototype, runs the whole suite with `run_tests.sh`, and checks that it exits 1 and fails the tests it names; then `git checkout -- .` restores the files, and would erase any unstaged edit, so `tools/sp/neg.py`, which runs them, takes a worktree of its own, from `git worktree add --detach`, imported. "As on `main`" is as at ec6f54d. All twelve ran on 98ffdd5, whose results these are, and N12 again on 8205270; N1–N11 change neither the growth nor its test; the first draft's ran on 9229f94 (eb4a788 §6.2). N7 ran on `test_area_schedule.gd` alone, with `-gselect`, as with every schedule invalid the whole suite runs out of memory (§8).

| N# | Change | Fail |
|---|---|---|
| N1 | `schedule.tres` and `schedule_home.tres` as on `main`: the areas at turns 34, 100, 200 and 220, home's at 60, 80, 180 and 246, and both roads ending after turn 280, with SP's straights, days and growth | 23 tests: U6's 25 but `test_game_over.gd`'s and `test_prop_scatter.gd`'s. Both drives' 22 runs reach their cap of 600 s at turns 224–246 to the pier and 197–219 home, "[600.0] expected to be <= than [300.0]: pier seed 0: the time to the end" |
| N2 | `meadows.tres`: straights of 3–7 tiles, as on `main` | 2: `test_from_the_meadows_on_the_straights_are_longer_than_rurals`, "[3] expected to be > than [3]: meadows's shortest straight", and `test_the_game_road_matches_its_digests` |
| N3 | `rural.tres`, `meadows.tres` and `desert.tres` without `day_seconds`: 120 s days, as on `main` | 2: both drives, in `_check_night()`, where 35 of the 66 zones end before their night: all 22 of Rural's, 12 of the Desert's and 1 of the Meadows', such as "[47.75] expected to be > than [65.0]: pier seed 0: rural's night" |
| N4 | `hud.tscn`: the strip's anchors at 0.1 and 0.9, 80% of the HUD's height | 2: `test_hud.gd`'s strip tests: "[6] expected to be <= than [4]: 640 pixels high: half the car's mark", and the strip's pixels, such as "[200] expected to equal [100]: at the finish" |
| N5 | `village.tres`: no straights of its own, so the defaults' 2–5, as on `main` | 2: E2's test, "[2] expected to be > than [3]: village's shortest straight", and the digests |
| N6 | `desert.tres`: straights of 3–8 tiles, as on `main` | 2: E2's test, "[3] expected to be > than [3]: desert's shortest straight", and the digests. Each Desert zone of the 22 drives still reaches its night |
| N7 | `rural.tres`: `day_seconds = 55.0`, under `least_day_seconds()`, 55.68 s | 9 of `test_area_schedule.gd`'s 24: each schedule with Rural is invalid, "rural: day_seconds is below 55.69", rounded up (`area_def.gd`:109), and the generator lays its fallback road |
| N8 | `schedule_home.tres` as on `main`: the Village at 60, the Meadows at 80, Rural at 180 and the City at 246, and home after 280 | 6: `test_the_autopilot_drives_the_road_home`, whose eleven runs reach their cap in Rural, at turns 197–219, "[600.0] expected to be <= than [300.0]: home seed 0: the time to the end"; `test_the_games_pit_stops`; `test_the_road_home_is_valid_and_runs_the_other_way`; `test_the_route_strip_shows_only_on_a_road_with_a_finish`; `test_the_road_home_ends_at_home_after_100_turns`; and `test_hitchhiker_run.gd`'s `test_a_departure_that_starts_before_her_turn_has_her_too` |
| N9 | `test_drive_to_the_end.gd`: `SLOWEST_SECONDS` at 300, as `MOST_SECONDS` | 1: `test_the_autopilot_drives_to_the_pier`, on pier seed 4993's time alone, "[306.4] expected to be <= than [300.0]: pier seed 4993: the time to the end"; 523,160 of the 523,161 asserts pass, home seed 352's 294.5 s among them |
| N10 | `test_drive_to_the_end.gd`: after `_damage` is reset, each drive's car takes a second's damage off the road, `sim._drive_off_road(1.0, sim.area)` | 2: both drives, "[1] expected to equal [0]: pier seed 0: no damage", and the same on each of the 22 drives; 523,139 of the 523,161 asserts pass |
| N11 | `desert.tres` as at 339b126: straights of 6–14 tiles, decoys at 0.2 and side roads at 0.25 | 1: the digests; 554,020 of the 554,022 asserts pass. E1's seeds and the slowest arrive within their bounds on that Desert too, so only P10 and §5.2's model show what the retune is worth (U13, Q14) |
| N12 | `tuning.gd`: `TOP_SPEED_GROWTH` at 0.002, as on `main` | 1 at 98ffdd5: `test_the_autopilot_drives_to_the_pier`, "[310.766666666667] expected to be <= than [310.0]: pier seed 4993: the time to the end". 2 at 8205270: that one, and `test_the_top_speed_grows_with_the_run_up_to_the_cap`, "[5.0…] expected to equal [5.75]"; 523,159 of the 523,161 asserts pass |

U6's count ran the same way, on `main` (4a50bb2) with 98ffdd5's two schedules: 25 of its 903 tests failed.

On PR 1, the twelve ran on 2e7b745 and, with N13, on bcf3a8e; B and A1–A3, for Copilot's review (§4.3), on 99eb5d0, on their test scripts; and all seventeen on 7854cfd, each with the whole suite but N7: each failed what this table and §4.3 say, and N2 also `test_props_reach_across_the_tallest_view_in_the_meadows`, which needs a view past `PROP_SPREAD` (A), and N13, as on bcf3a8e, also the five other tests that check a drive's damage or health: E1's two, `test_each_area_counts_from_its_first_tile`, `test_the_streak_ends_the_tutorial_and_the_city_run_counts_from_there` and `test_the_car_arrives_and_rolls_to_a_stop_on_the_finish`. PR 1's body gives their run on its head.

### 6.3 Editor warnings

As docs/agents/checks.md §1 says, a temporary `override.cfg` raised the warnings at level 1 to errors, and `check_scripts.sh` loaded every script, on `main` (4a50bb2), and on 98ffdd5 and again on 8205270; then again without `integer_division`, as Godot reports only a script's first error. Each pair of logs is the same, with only `main`'s five, which eb4a788 §6.3 lists: four `INTEGER_DIVISION` and an `UNUSED_VARIABLE`, none in the 19 scripts that SP changes, `tuning.gd`, `route_strip.gd` and §5.7's 17 test files.

### 6.4 Verified only in CI or on devices

- **CI.** PR 1's four required checks, and its `test` job's time (§6.1). This plan's PR changes only this file.
- **Nothing for the Web or Android alone.** PR 1 changes the areas' data, constants, how far each row of props spreads, a comment and tests: no node, no `Polygon2D`, no input, and no text but numbers, which the font has. Its CI builds the Web and the APK as `main`'s does, so this plan asks for no Web check, and the run on the Fold4 is optional (Q13).
- **E8, in a desktop run** (docs/agents/checks.md §2), on the prototype at 98ffdd5, and on PR 1 at 3b79952, as #119 had changed the light. Movie Maker's frames of the autopilot, seed 1, the whole road from the City:
  ```bash
  XDG_DATA_HOME=/tmp/sp2/movie/data xvfb-run -a -s "-screen 0 1280x1024x24" godot --path . \
    --write-movie /tmp/sp2/movie/full/f.png --fixed-fps 60 --quit-after 15600 -- --autopilot --seed=1
  ```
  Then each frame's mean luminance, out of 255, from the means of its red, green and blue with BT.601's weights, unrounded, and two sheets of frames. The first draft's four movies, at 9229f94, from Rural, the Meadows, the Desert and the City, are in eb4a788 §6.4.
  - **The road**, 260 s, each area's banner at its first turn, and each zone's start the same as P1's, to the frame: the City by day, to 34.2 s; Rural at turn 20, its dusk at 59.2–66.7 s and its night to 83.1 s; the Meadows at turn 44, as their morning fades in from the night, their dusk at 108.1–115.6 s, their night to 136.8 s, and a second morning, as their zone of 80.05 s outlasts its day (§5.3); the Village at turn 68, by day; the Desert at turn 78, at Last Gas, its dusk at 216.9–224.3 s, its night to 245.6 s, and its dawn; the Coast's morning at turn 100; the pier, as the sea fills the view and EG's sunset falls; and the end screen at 255.25 s, 5 s after the arrival: "NEW LEGEND!", "Turns: 100", "Area reached: Coast" and "Time: 4:10", where P1 measured 250.27 s for pier seed 1, and "Next: drive the Road Home". Its log had no `ERROR` line, and its `autopilot:` line read `tile 898, turns 100, area coast`. 3b79952's was the same, to the frame.
  - **The light, frame by frame.** No run of 1 to 30 frames was brighter or darker than both frames around it by more than 0.29, out of 255: 0.29 in the dusks, at 218.05 s as the Desert's begins; 0.24 by day, at 196.07 s in the Desert; 0.15 in the mornings' fades, at 248.62 s in the Coast's; 0.09 at night; and 0.08 in the dawns. At 3b79952: 0.29 and 0.24 again, at the same frames; 0.08 in the dawns, at 142.95 s; 0.17 in a zone's first 3 s, at 249.08 s, after the Coast's light has come, as the sea comes into the view; and 0.07 at night. A frame's mean moves with the view as well as the light, and can hide a change in one part of the view or in one colour, so the movie is evidence of how the road looks, not of the light's rate. That rate is asserted on each frame by `test_daylight_run.gd`'s `test_each_new_zone_starts_its_clock_again`, as a zone's morning takes over from the night, and by `test_arrival_scene.gd`:78–82, at the sunset.
  - **The headlights**, at 3b79952: on at each dusk's 18.5 h, at 62.95, 111.85 and 220.6 s, and lit within 0.5 s; on through each night; off from the Meadows' sunrise at 140.6 s, gone by 141.0 s; and into the mornings entered by night, the Meadows' and the Coast's, fading as their light comes, gone by 84.6 and 248.1 s (`world/headlights.gd`:34–39).
  - In the sheets, the strip's car climbed with the HUD's turns, from the bottom in the City past each area's tick to the top at the Coast.
- **The Fold4, optional, by the owner, before landing PR 1** (Q13). PR 1 changes the props and merges #119's headlights, so the prototype's build no longer serves: a comment on #118 gives a debug APK of its head, from `gh workflow run ci.yml -R pompomon/roadgame --ref sp/1-road -f upload-builds=true` (docs/agents/checks.md §4). A phone takes no arguments, so play by hand, with Play or the title's Start, which in a debug build chooses any area (docs/ZONE_SELECT.md Z1). On both screens: the nights of Rural, the Meadows and the Desert, with the headlights, and the fades into each next morning; the Village's 26 s; the long straights from the Meadows on, with props across the view; the strip's car, climbing evenly; and the end screen's time at the pier, which the autopilot reaches in about four minutes from the City.

### 6.5 Measurements

The probes ran headless with Godot 4.7.2, at 60 steps a second, as GUT scripts, with Python, which 17f5ff6 commits in `tools/sp/`. GUT runs them only by name, `SP_OUT=<csv> godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir= -gtest=res://tools/sp/<script> -gexit`, and each one's header gives its variables. P1 is `test_sp_probe.gd`, which P5, P6 and P10 ran too; P7, P8 and P9 are `test_sp_p7.gd` to `test_sp_p9.gd`, and U13's decoys `test_sp_kinds.gd`. `analyze_p1.py` reads P1's files for P3 and P4, and `cases.py`, `variants.py` and `tail.py` run P2's `model.py`. On another branch, `git archive 17f5ff6 tools/sp | tar -x` adds them, untracked, best in §6.2's worktree. P1, P3, P4, P6, P8 and P9 ran on 98ffdd5's game, 8205270's, and P7 on `main`'s and 98ffdd5's. P1's zone times match N3's messages to the step, such as pier seed 0's Rural, 47.75 s, and the movie's zones to the frame. P5 and P10 are the first draft's: P5 ran on `main`'s game at ec6f54d, which 4a50bb2 keeps, as it changes only docs, and P10 on 339b126's.

| P# | What | Result | Used by |
|---|---|---|---|
| P1 | The autopilot drives each road to its end, without the tutorial, seeds 0–4999: each area's time, path tiles and top speed | All 10,000 arrive, with full health at the end and no junction dropped. To the pier: 223.1–306.4 s, 252.2 on average, a standard deviation of 10.15, p95 270.0 and p99 278.9, and 1 over 300 s. Home: 222.2–294.5 s, 253.1, 10.20, 270.9 and 278.2, and none over 300 s. 786–1,111 path tiles to the pier, and a cap of 6.64–7.0 tiles/s at the end. Each area's times in §5.1, its speeds in §5.2, and E1's seeds in §5.1 | Q1–Q4, Q14, Q15, E1, U1, U3, U4, U13 |
| P2 | §5.2's model of a run: roads drawn as the generator draws them, with the speed moved toward `target_speed()` at 60 Hz along each straight, as `_update_speed()` does; 20,000 runs a road for each case, 200,000 for each variant, and a million for SP | §5.2's tables and the variants, and Q2's two roads, whose Desert's 60 turns take 178.5 s | Q2, Q3, Q14, Q15, §8, §9 |
| P3 | P1's 30,000 zones of Rural, the Meadows and the Desert: how many last into their night, with days of 120, 90, 80 and 60 s | 48.9%, 87.3%, 99.6% and 100% (§5.3). At 60 s, the shortest, a Rural zone of 40.97 s, has 8.47 s of night, and the Desert's shortest, 49.48 s, 16.98 s | Q5, E3, U2 |
| P4 | The same zones: the light as each ends, with 60 s days | §5.3's table: 28.4% end at night. 60.8% last into a second morning, 746 into a second dusk and 80 into a second night | U10 |
| P5 | `main` (ec6f54d): the autopilot drives each road to its end, seeds 0–19 | 562.2–613.3 s to the pier and 561.4–614.0 s home; each area's time (§5.1) and speeds (§5.2); 39 of the 120 zones of Rural, the Meadows and the Desert end at night | U1, U4, U10 |
| P6 | P1 with `TOP_SPEED_GROWTH` at 0.002, `main`'s, seeds 0–199 | 4.1 s slower to the pier and 3.5 s home on average than P1 on the same seeds; the slowest 4.3 s and 3.9 s slower; the cap ends at 5.57–5.99 tiles/s at the pier; the Desert's mean top speed to the pier 5.69 tiles/s, against 6.83 | Q4, U4 |
| P7 | Both roads, laid on `main` and on 98ffdd5 for seeds 0–199, each digested with its dead ends up to the junctions of turns 1, 10, 16, 19, 20, 21, 22, 24 and 34 | To the pier, the same on all 200 seeds up to turn 20, and on none from 21. Home, the same at turn 1 on 155 seeds, and on none from turn 10 | E4, §5.6 |
| P8 | `test_autopilot_300_turns.gd`'s drives, on `main` and 98ffdd5 | 300 turns of `endless()` take 758.8–833.6 s of game time, 811.7 on average, against 607.5–656.2 s on `main`; its drive with every kind of junction 476.2–495.8 s on each | §4.3, §5.6, Q11, U11 |
| P9 | A first run: the autopilot through the tutorial, then to the pier, seeds 0–99 | The tutorial ends at 17.9–22.9 s, and the car arrives 252.1–294.1 s after its start, each with full health | Q10, §5.6 |
| P10 | The first draft's P1, at 339b126, with its turns and a Desert of straights of 6–14 tiles, decoys at 0.2 and side roads at 0.25, seeds 0–4999 | To the pier: 215.3–290.6 s, 244.1 on average, a standard deviation of 10.08. Home: 212.8–301.6 s, 244.7, 10.53. Home seed 3879 took 301.6 s, the only run over 300 s: its Desert zone had 15 decoys among its 31 junctions and took 95.0 s | U13, Q14 |

---

## 7. Owner actions

| When | Action | How |
|---|---|---|
| Done | Merge this plan's PR: #116, with the answers to Q1, Q4 and Q9, the other defaults, and E1's bound of 310 s on each road's slowest seed (Q15) | |
| After PR 1's reviews | The Fold4's optional run (§6.4), then land PR 1; and Copilot's C, declined, whose thread is left open (§4.3) | Squash it, as the plan's last code PR (§4.2). Resolve C's thread, or say there what to change |
| After PR 1 | Land PR 2, the docs and SP's learnings | Review the guidelines that it changes (planning.md §7), then squash it |
| After PR 2 | Tag the prototype, which this plan cites, and delete SP's branches, which GitHub doesn't delete on merge | `git fetch origin sp/prototype && git push origin FETCH_HEAD:refs/tags/archive/sp/prototype`, then `git push origin --delete sp/plan sp/prototype sp/1-road sp/2-docs` |

---

## 8. Risks

| Risk | Impact | Mitigation |
|---|---|---|
| The bound is a target (Q15) | Pier seed 4993 took 306.4 s, and a zone's decoys have no limit (U13): §5.2's model puts about one run in 20,800 over 300 s, the slowest at 315.7 s, though it isn't checked against the game past one run in a thousand. A later change to the car, the autopilot, the generator or an area could push more seeds over, which no test would show but on E1's | E1's test drives 10 seeds a road within 300 s, and each road's slowest of P1 within 310 s (N9, N12). §4.1 step 2 runs P1 again if `main` has moved; so should a later change that slows the car. V4, V2 or V7 (§5.2) |
| A player is slower than the autopilot | A player only steers (§5.2), and a wrong exit ends the run (`plan.md`:29), so a run that arrives took its seed's road at the autopilot's speeds, but for its time off the road, at 0.45–0.6 of the speed (`car_sim.gd`:257–258). On the slowest seeds, a few seconds off the road take a player past five minutes | The bound is the autopilot's, as the owner asked (Q10). Each time off the road ends the run at 2 tiles (`car_sim.gd`:387–391), and costs 25–35 health a second |
| The car is faster on every road | Its cap reaches 7.0 tiles/s after 857 tiles, not 1,500, on Keep Driving and Departures too (Q4) | The cap stays 7.0, which `main`'s car reached on every run to the end (U4); the Fold4's optional run (§6.4) |
| The end comes sooner | At 1% errors a junction, about 32% of runs would arrive, where about 4% did (U9) | An arrival unlocks one legend (docs/ENDGAME.md §5.5). The finish's turn is one number in `schedule.tres` (Q1), and the pit stops could be fewer (Q8) |
| The light changes faster, and days come round | A 60 s day's steepest change uses 92.8% of `LIGHT_MAX_RATE`, 82–84% of Rural's zones end at night and hand over to the next morning (U10), and 60.8% of the long areas' zones last into a second morning (§5.3) | `test_daylight_run.gd`:129 asserts the rate of a morning's fade each frame, and the movie's mean had no pulse above 0.29 of 255 (§6.4). Q5's alternative, 80 s days in the Meadows and the Desert, puts 10.5% of their zones into a second morning |
| Old saves | A save from `main`, on Pages, keeps a best time of about ten minutes until its first arrival, and a farthest turn of up to 280 | The goal line, the strip and the Hitchhiker clamp it (§5.5); Q7's alternative, version 6 |
| A first run comes near the bound | With the tutorial, the autopilot arrived up to 294.1 s after its start (P9) | E1 counts the run without it (Q10) |
| A first run's Rural comes late | If the tutorial's road holds the 20th turn, Rural comes a turn or two late: about 1.5e-7 of first runs without a mistake, in a model, and none of the 10,000 probed (§4.3, Copilot's C) | docs/TUTORIAL.md §5.5's fallback, tested, and Q15 |
| A broken schedule takes the machine's memory | With every schedule invalid, `test_road_generator_tutorial.gd`:41 loops forever on the fallback road, as on `main` (N7) | Run such a case on its test script alone (§6.2); §9 notes a bound for the loop |

---

## 9. Notes for later work

- **M7's device QA** (IP §4 M7). A run to the pier now takes about four minutes on the autopilot, so a QA pass can drive both roads, by day and by night, in one sitting. PR 2 moves M7.6's screenshots to turns 0, 20, 44, 68 and 78 (IP :209, :320).
- **Every seed within five minutes** (Q15), if a target isn't enough: only a cap on each zone's decoys bounds every seed, and it changes the roads of the seeds that draw more. V4, V2 and V7 (§5.2) only widen the margin: none of the model's 200,000 runs a road passes 300 s with them.
- **A time to beat.** A run's time is its seed's road at the car's own speeds, plus its time off the road (§8), so a best time rewards a quick seed as much as a clean run: the autopilot's seeds alone spread over 222.2–306.4 s (P1). A par would have to be the autopilot's time on the same seed, not one number for the road.
- **Version 6** (Q7), if old records confuse players on Pages: a migration that clamps each road's farthest turn to its end, and drops the best times over five minutes.
- **Keep Driving's road** (Q11) is the Desert forever from turn 78. An endless run that crosses more areas would need an endless schedule of its own, such as `main`'s.
- **Bound the tutorial test's loop.** `test_road_generator_tutorial.gd`:41 loops until it meets a set piece, which the fallback road never lays (N7). A cap on its tiles would turn a broken schedule's out-of-memory into a failure. It's on `main`, so this plan leaves it alone.
