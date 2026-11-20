# The Speedup: the Road to the Sea in Five Minutes — Detailed Plan

Status: proposed. Merging its PR approves it with Q1–Q15's defaults (§3), unless the owner answers otherwise there · 2026-11-20 · Scope: a run to the end of either road takes the autopilot at most five minutes, not ten, on every seed measured: a target, not a cap proven for every seed (Q15). Both roads end after their 100th turn, not their 280th: the City keeps its 34 turns, each area after it has fewer, and from the Meadows on, the straights are about twice as long. Rural, the Meadows and the Desert turn a day in 60 s, so that each still shows its night. This plan calls the work SP. It builds on EG, which has landed, and comes before M7.

The owner asked: "Explore the codebase and create a detailed implementation plan for game speedup. Adjust the number of turns required after the first zone, so the end time on autopilot is 5 minutes at most. Also adjust the Meadows zone and beyond to have less turns and longer straight roads. Ask clarifying questions if needed". The clarifying questions are §3's Q1–Q15. This plan was written in autopilot mode, which decides rather than waits, so each question has a default, which the plan and its prototype follow, and the alternatives that the owner can choose instead on the plan's PR. Those with the most at stake are Q1, the turns; Q2, the Road Home, which starts in the Desert, not the City; Q3, the straights; and Q5, the days.

**What happens.** Today the autopilot takes about ten minutes to the end of either road: 562.2–613.3 s to the pier and 561.4–614.0 s home, on seeds 0–19 (P5; docs/ENDGAME.md P1). The road ends after its 280th turn (`schedule.tres`:52), and 246 of its turns come after the City's 34: Rural's 66, the Meadows' 100, the Village's 20 and the Desert's 60. The Meadows alone take 217 s. With SP, the areas switch at turns 34, 58, 76 and 84, and the road ends after its 100th (Q1): Rural has 24 turns, the Meadows 18, the Village 8 and the Desert 16. The Meadows' straights become 6–12 tiles, from 3–7, the Village's 4–8, from 2–5, and the Desert's 6–12, from 3–8, with fewer decoys (Q3, Q14), so those areas turn less and run straighter, as the owner asked: 2.6–3.3 s a turn, against Rural's 2.1. Each long area takes about a minute, the City 58 s, Rural 51 s, the Meadows 57 s and the Desert 47 s, and the Village is a 21 s interlude. On 5,000 seeds of each road, the autopilot arrived in 208.1–278.7 s, 237 s on average, with full health (P1). The Road Home stays the road's mirror, with the same turns in reverse (Q2).

Shorter zones need shorter days. With 120 s days, the night comes 65 s into a zone (docs/DAYNIGHT.md §5.8), and only 4.1% of the new zones would reach it (P3): runs would lose the nights that DN added. So Rural, the Meadows and the Desert turn a day in 60 s, whose night comes 32.5 s into a zone, and each of the 30,000 such zones of P1's runs reached it (Q5). The City, the Village and the Coast keep 120 s.

The rest stays (Q8). The route strip keeps its 40% of the HUD's height, and its car now climbs 2.56–3.69 pixels a turn, not about one (Q6, §5.4). Saves stay at version 5 (Q7). The City, the car, the legends and the pit stops don't change. PR 1 makes the change, and PR 2 replaces this plan with `docs/SPEEDUP.md` (§4).

**Verified locally.** The change was first built on branch `sp/prototype`, from `main` at ec6f54d, which never gets a PR of its own (§4.1). Its five commits, 529378c, 6740ac4, 339b126, a130c54 and 9229f94, change 6 area files, a comment in `route_strip.gd` and 14 test files: 21 files, +193 −128. 9229f94 passed the five checks locally with Godot 4.7.2 (§6.1), and the warnings check (§6.3), and each of the 11 negative cases failed the tests it names: ten against the whole suite, and N7, which breaks every schedule, against `test_area_schedule.gd` alone, as the whole suite then runs out of memory (§6.2). CI run 44755193873 passed on 9229f94 (§6.1). Probes in Godot drove both roads to their ends on 5,000 seeds each, measured the nights, the speeds and the light, and compared the road with `main`'s on 200 seeds (§6.5). A model of another family reviewed the plan and the prototype at 339b126 (§4.4). Its first finding asked for more seeds, and P10's 5,000 a road found a drive home of 301.6 s, which a130c54's Desert fixed (U13).

- Godot 4.7.2-stable (4.7.2.stable.official.ed1daf0bf), as in CI
- GUT 9.7.1
- gdtoolkit 4.5.0 on Python 3.12, as in CI's `lint` job. shellcheck isn't installed locally, so `lint.sh` skipped it there; SP changes no shell script

**Precedence.** For SP, this document replaces `plan.md`'s vision (:13), §3.6 (:122–125), §5.5 (:229), §9 (:356), §11 (:390) and §13 (:429); docs/ENDGAME.md's header (:3), E6 (:11), Q1 (:47), §5.6 (:112), §5.8 (:120), P1 (:162) and §8 (:170); docs/DAYNIGHT.md Q3 (:40) and §5.8 (:99); and docs/ROADGEN.md §5.5's straights and the Desert's chances (:82–88), wherever it marks a difference with **Δ** and its finding (U#, §2). PR 1 folds them into those files (§5.8, Q12).

**Reference code.** PR 1 is the difference between ec6f54d and 9229f94, the head of `sp/prototype`, with §5.8's Δs to the docs (§4.1).

**Prerequisites.** EG has landed, with its docs (#101–#114), so `main` has the road's end, the Road Home, the route strip, the pit stops and the records that SP retunes. The prototype starts from ec6f54d. Since then, `main` has taken only the owner's #115, EG's learnings for agents, at 4a50bb2: it changes `AGENTS.md`, `docs/README.md`, docs/agents/ and `.github/instructions/`, but no file of PR 1's, and it adds the learnings step that PR 2 takes (planning.md §7). M7 hasn't started; §9 has notes for it. No repository settings change.

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

Goal: a whole road in one sitting. The autopilot drives either road to its end in at most five minutes on every seed measured (Q15), and a player who knows the way takes about as long. The City stays as it is, the areas after it have fewer turns, and from the Meadows on, the road runs straighter. Each area keeps its character and its legends, and each long area past the City still shows its night.

| # | Exit criterion | Checked by |
|---|---|---|
| E1 | Five minutes (U1, U3, U13; Q1, Q10, Q14, Q15). Both of the game's roads end after their 100th turn. The autopilot drives each to its end on each of 10 seeds, and on the slowest of P1's 5,000 seeds a road, with no disaster, crash or damage and no junction dropped, in at most `MOST_SECONDS`, 300 s, of game time: the run's clock, which the end screen shows. The end screen comes `ARRIVAL_SECONDS`, 5 s, after the arrival | `tests/sim/test_drive_to_the_end.gd`: `test_the_autopilot_drives_to_the_pier`, `test_the_autopilot_drives_the_road_home`; `test_area_schedule.gd`: `test_the_games_road_ends_at_the_pier_after_its_100th_turn`; `test_road_generator_finish.gd`: `test_the_road_home_ends_at_home_after_100_turns`; P1, on 5,000 seeds a road: 208.1–278.7 s |
| E2 | Fewer turns and longer straights after the City (U1; Q1, Q3, Q9). The City keeps its 34 turns. The areas switch at turns 34, 58, 76 and 84, and the Coast starts at 100: Rural has 24 turns, the Meadows 18, the Village 8 and the Desert 16. The tunnel, the bridge and Last Gas still lead into Rural, the Meadows and the Desert, with the same pit stops. From the Meadows on, each area's shortest and longest straights are longer than Rural's, 3 and 7 tiles: the Meadows' 6–12, the Village's 4–8 and the Desert's 6–12. The City and Rural keep theirs | `test_area_schedule.gd`: `test_from_the_meadows_on_the_straights_are_longer_than_rurals`, `test_areas_and_set_pieces_switch_at_34_58_76_and_84`, `test_the_game_schedule_is_valid`, `test_the_games_pit_stops`; `test_area_order.gd` and `test_tutorial_run.gd`, which drive the road through each switch to the Desert's, at turn 84; `test_set_pieces_on_the_road.gd`, past the bridge at turn 58; `test_drive_to_the_end.gd`, which ends each road in its last area, the Coast or the City; `test_area_start.gd` |
| E3 | Each long zone shows its night (U2; Q5). Each zone of Rural, the Meadows and the Desert that the car leaves lasted into its night, by its area's `day_seconds` as loaded: with SP's 60 s days, the night comes 32.5 s after the car enters one. No area's day is shorter than 55.68 s, the shortest whose light changes within `LIGHT_MAX_RATE`, which `validate()` checks. The days' lengths are data in the areas' `.tres` files, which no test names, as with the areas' other values: the City, the Village and the Coast keep 120 s | `test_drive_to_the_end.gd`'s two tests, through `_check_night()`, on each zone of `NIGHT_AREAS`; `test_area_schedule.gd`: `test_the_game_schedule_is_valid`, `test_the_road_home_is_valid_and_runs_the_other_way`; P3 |
| E4 | Nothing else changes (U6, U7; Q8). The City, the tunnel, the car, the autopilot, the legends, the pit stops' rule, the light's rules and the save stay as on `main`. Up to and including the junction of its 58th turn, the game's road is `main`'s, tile for tile, with its dead ends. Only the golden digests of `endless()`, which lays the Meadows and the Desert, change, and PR 1's commit says why. `smoke.sh` prints `main`'s line, `autopilot: tile 165, turns 35, area rural` | The tests that PR 1 doesn't change, which pass as on `main`; `test_road_generator_determinism.gd`'s new digests; P7, on seeds 0–199; §6.1's smoke line |
| E5 | The Road Home (Q2). It stays the road's mirror: the Desert from its start, the Village at turn 16, the Meadows at 24, Rural at 42 behind the bridge and the City at 66 behind the tunnel, and home after turn 100, with pit stops where the Village, Rural and the City start | `test_area_schedule.gd`: `test_the_road_home_is_valid_and_runs_the_other_way`, `test_the_games_pit_stops`; `test_drive_to_the_end.gd`: `test_the_autopilot_drives_the_road_home`; `test_hud.gd`: `test_the_route_strip_shows_only_on_a_road_with_a_finish`; `test_hitchhiker_run.gd`: `test_a_departure_that_starts_before_her_turn_has_her_too`; `test_road_generator_finish.gd`: `test_the_road_home_ends_at_home_after_100_turns` |
| E6 | The strip and the save (U5, U8; Q6, Q7). The route strip keeps its 40% of the HUD's height, with ticks at turns 0, 34, 58, 76, 84 and 100. On each reference screen, 640, 800 and 922 pixels high, its car climbs evenly, each turn the strip's length over 100 turns, rounded down or up, and never more than half its mark's height. Saves stay at version 5: an older save loads as it is, and the goal line, the strip and the Hitchhiker clamp a farthest turn past 100, so the goal line of a player who passed turn 100 on `main` reads "Your best: turn 100 of 100" until they arrive | `test_hud.gd`: `test_the_route_strip_marks_each_area_the_car_and_the_best`, and `test_the_route_strip_shows_only_on_a_road_with_a_finish`, whose best is past the finish; `test_game_over.gd`: `test_the_next_goal_follows_the_players_progress`, whose farthest is 50 turns past the road's end; `test_hitchhiker.gd`: `test_her_turn_is_the_players_farthest_on_the_road_home_or_its_finish_once_home`, and `test_save_data.gd`, unchanged |
| E7 | Docs: PR 1's Δs (§5.8), then PR 2's `docs/SPEEDUP.md` (Q12) | Review |
| E8 | Manual: a run of the new road reads well, from the City to the end screen, with the nights of Rural, the Meadows and the Desert, in a desktop run's frames (done on the prototype, §6.4); the owner may play one on the Fold4 before landing PR 1 (Q13) | §6.4 |
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
| U1 | A run to the end takes about ten minutes, most of it after the City. 246 of the road's 280 turns come after the City's 34, and the Meadows' 100 alone take 217 s | `schedule.tres`:18–52: the areas at turns 34, 100, 200 and 220, the Coast at 280, and `finish_turn = 280` (:52); `schedule_home.tres`:17–46, its mirror. P5, seeds 0–19: 562.2–613.3 s to the pier and 561.4–614.0 s home; to the pier, the City took 58 s, Rural 136 s, the Meadows 217 s, the Village 39 s and the Desert 136 s. docs/ENDGAME.md P1 (:162): 9.6–10.2 minutes | **Δ plan.md :13, §3.6, §11, §13; docs/ENDGAME.md Q1, §5.6, §5.8, P1, §8:** the areas switch at turns 34, 58, 76 and 84, and both roads end after turn 100 (Q1, Q2; §5.1). Prototype (E1, E2, N1, N8) |
| U2 | Shorter zones would lose their nights. With 120 s days, the night comes 65 s after the car enters a zone, and SP's Rural, Meadows and Desert zones last 34–86 s: only 4.1% of them would reach it, while each of `main`'s did | `area_def.gd`:71, `day_seconds := 120.0`, which no area sets; `tuning.gd`:247 and :251: a zone's clock starts at 07:00, and the night at 20:00, 13/24 of a day later; docs/DAYNIGHT.md §5.8 (:99). P3 | **Δ plan.md §5.5; docs/DAYNIGHT.md Q3, §5.8:** Rural, the Meadows and the Desert turn a day in 60 s (Q5; §5.3). Prototype (E3, N3, N7) |

### Medium

| # | Finding | Evidence | Fix |
|---|---|---|---|
| U3 | No test bounds a run's time, and the times spread: the slowest of P1's 10,000 runs took 278.7 s, 70.6 s more than the quickest | `test_drive_to_the_end.gd`:9–12: five seeds a road, "about 9 minutes", and a cap of 20 minutes, which only stops a car that never arrives; no assert reads the time | `MOST_SECONDS`, 300 s, asserted on 10 seeds a road and on each road's slowest seed of P1, with the cap at twice that (E1); P1 on 5,000 seeds a road (§6.5). Prototype (E1, N1, N9) |
| U4 | The car's top speed grows with the distance it has driven in the run, so a shorter road ends slower: at the pier the cap is 5.33–5.82 tiles/s, where on `main` it was 7.0 | `car_sim.gd`:250–253: `minf(GLOBAL_SPEED_CAP, BASE_TOP_SPEED + dist_total * TOP_SPEED_GROWTH)`; `tuning.gd`:65–68: 4.0, 0.002 a tile and 7.0, reached after 1,500 tiles. P1: 700–941 path tiles to the pier, and the Desert's top speed 5.51 tiles/s on average, against 5.79 on `main` (P5) | None by default: the time comes from the turns and the straights, and a growth of 0.0035 saves 2.6–3.5 s on average (P6; Q4, §5.2) |
| U5 | The strip's test expects a pixel or so a turn | `test_hud.gd`:268–272: each turn's climb 0–2 pixels; `route_strip.gd`:7, "a pixel or so a turn". The strip is 40% of the HUD's height (`hud.tscn`:66–68), 256–369 pixels on the reference screens, so 100 turns climb 2.56–3.69 pixels each | The strip stays (Q6). The test checks that the car climbs evenly, the strip's length over 100 turns rounded down or up, and at most half its mark, 4 pixels; the comment says "a few pixels a turn" (§5.4). Prototype (E6, N4) |
| U6 | Twelve test files hold the old road's turns, times or digests: on `main`, the new schedules alone fail 23 of its 903 tests | ec6f54d with 339b126's `schedule.tres` and `schedule_home.tres`: `test_area_schedule.gd` 9, `test_drive_to_the_end.gd` 2, `test_hud.gd` 2, `test_road_generator_finish.gd` 2, and one each in `test_area_start.gd`, `test_hitchhiker_run.gd`, `test_area_order.gd`, `test_set_pieces_on_the_road.gd`, `test_tutorial_run.gd`, `test_game_over.gd`, `test_prop_scatter.gd` and `test_road_generator_determinism.gd` | The 14 test files of §5.7: those twelve, and two whose comments name the old road. Prototype (E1, E2, E5, N1, N8) |
| U7 | The golden digests change. `PATH_DIGEST` and `ROAD_DIGEST` digest `endless()` on seeds 0–19 to turn 300, which now crosses the Meadows from turn 58 and the Desert from 84, with longer straights | `test_road_generator_determinism.gd`; docs/ROADGEN.md §6.1: a commit that changes the digests says why | New digests, and PR 1's commit body says why. P7: up to the junction of its 58th turn, the road is `main`'s on 200 seeds (E4). Prototype (N2, N5, N6) |
| U8 | A save keeps the old road's records. An arrival on `main` keeps the road's farthest turn, 280, and a best time of about ten minutes, and `main` deploys to Pages | `save_data.gd`:14, version 5; `record_arrival()` (:244–252) keeps the least time (:248) and the farthest turn (:251); `ci.yml`:88–90, the Pages artifact on a push to `main`. Clamped: the goal line (`game_over.gd`:125–127), the strip (`route_strip.gd`:64–68) and the Hitchhiker (`hitchhiker.gd`:54–58). Not clamped: the overall and the Atlas's best turns (`atlas_screen.gd`:60–73) | None by default (Q7): an arrival on the new road replaces the old best time only if it is faster, as each measured would be, at about half of `main`'s (§5.5), and a best turn past 100 is history. Until a player arrives, their goal line reads "Your best: turn 100 of 100" if they passed turn 100 on `main` (§5.5). Prototype (E6) |
| U13 | A rare seed took over 300 s, as a zone's decoys vary widely. A decoy is a junction with no turn, and each junction's kind is its own roll, so an area's turns can take many more junctions than usual: with the Desert's 16 turns and a decoy chance of 0.2, 15 decoys or more come once in about 4,300 zones. With straights of 6–14 tiles, a decoy took about 2.6 s | P10, on 339b126, 5,000 seeds a road: home seed 3879 arrived at 301.6 s, the only run over 300 s. Its Desert zone had 15 decoys among its 31 junctions and 352 path tiles, against 214 on average, and took 95.0 s, against 58.6 s. `kind_for()` (`road_generator.gd`:149–159) draws each junction's kind from one roll, and `_junction()` gives a decoy a new straight and no turn (:213–216). The Road Home starts in the Desert, where the car's cap is lowest (U4) | **Δ docs/ROADGEN.md §5.5:** the Desert's straights 6–12 tiles, not 6–14, and its decoy chance 0.15, not 0.2, with its side roads 0.3, not 0.25, so that 0.45 of its junctions still have a trick (Q3, Q14; §5.2). 15 decoys then come once in about 141,000 zones, and P1's slowest run took 278.7 s. `test_drive_to_the_end.gd` also drives each road's slowest seed of P1 (E1). Prototype (E1, E2, N6, N9, N11) |

### Low

| # | Finding | Evidence | Fix |
|---|---|---|---|
| U9 | The road's turns shift to the City: it has 34 of 100, where it had 34 of 280. A run meets the City's junctions as on `main` and fewer of the later areas', so a player spends more of a run in the City, and arrives more often | §3.6 of `plan.md`; the City's share of the turns 12% → 34%, Rural's 24% → 24%, the Meadows' 36% → 18%, the Village's 7% → 8%, the Desert's 21% → 16%. A decoy is a junction with wrong exits but no turn (`road_generator.gd`:213–216), so with each area's `decoy_chance`, 0–0.15, a road has about 110 junctions where it had about 324. At 1% errors a junction, about 33% of runs would arrive, against about 4% | None: an arrival unlocks a legend of any area's pool (docs/ENDGAME.md §5.5), and Departures start in any area discovered (§8) |
| U10 | More zones end at night, so the next zone's morning fades in from the night more often | P4: with 60 s days, 19–90% of the zones of Rural, the Meadows and the Desert end at night, by area and road; on `main`, 39 of P5's 120. The fade takes 2.33 s (docs/DAYNIGHT.md Q2) | None: the light changes within `LIGHT_MAX_RATE`, which `test_daylight_run.gd`:129 asserts each frame of a morning's fade. In the whole road's movie, no run of 1 to 30 frames was brighter or darker than both frames around it by more than 0.24 of 255, and 0.23 by day (§6.4) |
| U11 | Comments name the old road's times | `test_area_order.gd`:9, `test_autopilot_300_turns.gd`:11, `test_drive_to_the_end.gd`:11, `test_set_pieces_on_the_road.gd`:10 and `test_tutorial_run.gd`:11 give each drive's minutes; `route_strip.gd`:7 | PR 1 updates each, with each drive's cap at about twice its time (§5.7). Prototype |
| U12 | The docs name 280 turns, the old switches and 120 s days | `plan.md`:13, :122–125, :229, :356, :390, :429; docs/ENDGAME.md :3, :11, :47, :112, :120, :162, :170; docs/DAYNIGHT.md :40, :99; docs/ROADGEN.md :82–88; IP :209, :249, :320; `AGENTS.md`:7 | PR 1's Δs (§5.8) and PR 2 (§4) |

---

## 3. Decisions and open questions

Each question has a default, which this plan and the prototype follow until the owner answers on this plan's PR (§7). If the owner merges the PR without answering, the defaults hold, as planning.md §5 says. An answer that changes a default changes PR 1, and the probes of §6.5 that it names are run again.

| # | Question | Default | Alternative |
|---|---|---|---|
| Q1 | How many turns, and where do the areas switch? | **The City keeps its 34 turns. The areas switch at turns 34, 58, 76 and 84, and the road ends after its 100th: Rural has 24 turns, the Meadows 18, the Village 8 and the Desert 16 (§5.1). Each long area takes about a minute, and the slowest of P1's 10,000 runs arrived at 278.7 s, 21.3 s inside the bound** | Another split of the 66 turns after the City, such as more for the Meadows and fewer for Rural; or fewer turns, for a wider margin: each turn after the City takes 2.1–3.3 s on average, by area and road (P1) |
| Q2 | The Road Home starts in the Desert. Is the Desert its "first zone", whose turns stay? | **No: "the first zone" is the City, where the game's road starts, after the tutorial, and whose 34 turns stay on both roads. The Road Home stays the road's mirror, with the same turns in reverse. The Desert has 16, the Village 8, the Meadows 18, Rural 24 and the City 34, and home comes after turn 100 (§5.1). P1: home in 208.1–278.7 s** | Keep the Desert's 60 turns at the Road Home's start. With SP's straights, they take about 185 s alone. P2 modelled two such roads: with SP's other areas after them, it takes about 371 s on average; with only the City's 34 turns after them, 246 s on average and 270 s at p99, but the Road Home would then skip the Village, the Meadows and Rural, their zones and their legends. Splits between the two weren't modelled |
| Q3 | How long are the straights from the Meadows on? | **The Meadows 6–12 tiles, from 3–7; the Village 4–8, from the defaults' 2–5; the Desert 6–12, from 3–8, with fewer decoys (Q14; §5.2). They take 2.6–3.3 s a turn, where Rural's take 2.1. Rural, which "the Meadows zone and beyond" leaves out, keeps 3–7, and the City's 2–5 and the Coast's 20 stay** | Twice `main`'s: the Meadows 6–14, the Village 4–10 and the Desert 6–16. In §5.2's model, 7 of 50,000 runs home then pass 300 s, where the default's took at most 289.7 s, and with the areas switching at 34, 58, 74 and 82 and the end after turn 98, one of 50,000 to the pier still does. Or longer still, with fewer turns |
| Q4 | Does the car reach its top speed sooner? | **No: `TOP_SPEED_GROWTH` stays 0.002 a tile, so the car's cap reaches 5.3–5.8 tiles/s by the pier, not `main`'s 7.0 (U4). The time comes from the turns and the straights** | 0.0035 a tile: 3.5 s quicker to the pier and 2.6 s home on average, and the Desert's top speed 6.57 tiles/s (P6). It changes the car on every road, Keep Driving's too, and each drive's time |
| Q5 | How long are the zones' days? | **60 s in Rural, the Meadows and the Desert, whose zones take about a minute: the night comes 32.5 s into a zone, and each of P1's 30,000 such zones reached it (P3). The City, which ends at dusk, the Village, a 21 s interlude, and the Coast keep 120 s (§5.3)** | 80 s, whose night comes at 43.3 s: 94.7% of the zones reach it, but only 76.6% of the Desert's on the road to the sea; 90 s, 68.9%; or 120 s, as on `main`, 4.1%, so that most runs show no night |
| Q6 | Does the route strip change? | **No: it keeps 40% of the HUD's height, so its car climbs 2.56–3.69 pixels a turn on the reference screens, and its closest ticks, the Village's and the Desert's, are 20.5–29.5 pixels apart (§5.4)** | 20%: 1.28–1.84 pixels a turn, near `main`'s 0.91–1.32, with those two ticks 10.2–14.8 pixels apart, and the car's mark 8 pixels high |
| Q7 | Does the save change? | **No: it stays at version 5. A save from `main` keeps its best time, about ten minutes, until the first arrival on the new road beats it, and a farthest turn of up to 280, which the goal line, the strip and the Hitchhiker clamp to the road's 100 (§5.5). So a player who passed turn 100 on `main` without arriving reads "Next: reach the sea. Your best: turn 100 of 100" until they arrive** | Version 6, which clamps each road's farthest turn to its end, and drops the old road's best times; or no migration, but a goal line that leaves out a best at or past the road's end until its first arrival |
| Q8 | Does anything else change? | **No: the City, the tunnel, the bridge, Last Gas, the car, the autopilot, the legends and their pools, the pit stops' rule, the tutorial, the light's rules and the music stay as on `main` (§5.6)** | Fewer pit stops, such as none on the bridge: the road from one to the next is 24 or 26 turns, where it was 66 or 120, so a run is easier (§8) |
| Q9 | How long is the Village? | **8 turns, about 21 s: an interlude between the Meadows and the Desert, as on `main`, where its 20 turns took 39 s (§5.1)** | 10 turns, with the Desert at 14 |
| Q10 | What do the five minutes count? | **The run's clock, which the end screen shows, from the start to the arrival, as `--autopilot` drives it, without the tutorial (`AGENTS.md` §2). The end screen comes `ARRIVAL_SECONDS`, 5 s, later: at most 283.7 s into P1's runs. A first run plays the tutorial's 12 turns or more before the City's, from whose end the schedule counts: on seeds 0–99, the autopilot finished the tutorial in 17.9–22.8 s and arrived in 236.2–280.4 s (P9)** | The tutorial's run too: P1's slowest seeds and the tutorial's 20 s or so could pass 300 s, so the road would need about 8 turns fewer |
| Q11 | Do Keep Driving and Departures follow the new road? | **Yes: they read the same schedules. Keep Driving, `endless()`, runs the Desert forever from turn 84, whose longer straights take longer a turn: the autopilot's 300 turns take 762.4–816.3 s, 798 s on average, against 607.5–656.2 s and 631 s on `main`, about 26% longer (P8). A Departure starts at its area's new turn, with as many turns fewer to the end (§5.6)** | Keep Driving on `main`'s schedule, a third file, so that its Desert still comes at turn 220. That alone wouldn't bring back `main`'s pace, as the straights are the areas', so its Meadows and Desert would keep SP's: it would need areas of its own too, with `main`'s straights |
| Q12 | Where do the docs change? | **PR 1 folds §5.8's Δs into `plan.md`, docs/ENDGAME.md, docs/DAYNIGHT.md and docs/ROADGEN.md, with their findings. PR 2 adds `docs/SPEEDUP.md`, changes the owner's paths, `AGENTS.md`, `docs/README.md` and IP, and deletes this plan (§4)** | Everything in PR 1, which the owner then lands |
| Q13 | Who lands PR 1? | **The owner, as the last code PR of the plan (`AGENTS.md` §5 step 4), after an optional run on the Fold4: SP changes nothing that only Android or the Fold4 does (§6.4). The owner lands PR 2 too, which changes `AGENTS.md`** | Agents, with `land_pr.sh`, once its reviews are done |
| Q14 | Do the Desert's junctions change? | **Yes: its decoy chance falls to 0.15, from 0.2, and its side roads' rises to 0.3, from 0.25. 0.45 of its junctions still have a trick, the most of any area, and its T's stay 0.25 (docs/ROADGEN.md §5.5). With fewer decoys, a Desert zone's junctions vary less, and so does its time: the slowest of P10's 10,000 runs, with 0.2 and straights of 6–14, took 301.6 s, and the slowest of P1's, with 0.15 and 6–12, 278.7 s (U13)** | Keep 0.2 and 0.25, as on `main`. With the Desert's straights at 6–12, §5.2's model then puts the slowest of 50,000 runs home at 302.6 s, so the road would need fewer turns, or the Desert shorter straights. Or 0.15 with the prototype's first straights, 6–14 (Q3): in the model, runs take 3.4–3.9 s more on average, by road, and the shortest Desert zones 1.4–1.6 s more, for a little more night (§8) |
| Q15 | Is five minutes a cap on every seed, or a target on the seeds measured? | **A target, met on every seed measured: P1's 10,000 runs took at most 278.7 s, and E1's test drives each road's slowest of them. A zone's decoys have no limit (U13), so a rarer seed may take longer: the model's slowest of a million runs a road took 298.4 s, but it isn't checked against the game past one run in a thousand (§5.2, §8)** | A cap on every seed: the generator would limit each zone's decoys, which changes the roads of the seeds that draw more, and a test would check the slowest road that the limits allow. A design of its own, with docs/ROADGEN.md §5.5's rules |

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
- **One code PR.** The turns, the straights, the days and the tests hang together. The schedules alone fail 23 tests (U6). Five minutes need the straights as well as the turns (§5.2), and shorter zones need shorter days, or E3's nights fail (N3). Split, each PR would land a road that the next retunes. PR 1 is small: 21 files, +193 −128, and the docs.
- **The docs from `main` (PR 2)**, with the owner's paths, as EG's PR 14 did (planning.md §3).

### 4.1 Porting from the prototype

PR 1 is the difference between ec6f54d and 9229f94, the head of `sp/prototype`, with §5.8's Δs to the docs.

1. Fetch, create PR 1's branch from `main`, and apply the difference. If `main` has moved on since ec6f54d in the prototype's files, `--3way` merges its lines with the prototype's; where both changed the same lines, keep both:
   ```bash
   git fetch origin main '+refs/heads/sp/*:refs/remotes/origin/sp/*'
   git switch -c sp/1-road origin/main
   git diff ec6f54d origin/sp/prototype | git apply --3way --index
   ```
2. If `main` has changed the road, the car, the autopilot, the areas or the light since ec6f54d, which `git diff --stat ec6f54d origin/main -- road car areas config world/day_cycle.gd` shows, run P1 and P3 again, on 5,000 seeds a road, check the slowest run's margin to E1's bound, and give `test_drive_to_the_end.gd` each road's slowest seed (§8).
3. Make §5.8's Δs to the docs, which the prototype doesn't have. Leave `SPEEDUP_PLAN.md` alone until PR 1's last round, which carries the plan's final sync (§4.2).
4. Run §6.1's checks and §6.3's warnings, and compare the counts with PR 1's "Expect" line. Run §6.2's negative cases, each with the whole suite but N7, which runs on `test_area_schedule.gd` alone (§6.2): while the code changes, those whose files or tests changed; then all eleven on PR 1's head once its reviews are done, started as its last round is pushed (planning.md §4).
5. Have a model of another family review it (`AGENTS.md` §5). Commit as PR 1's title, with a body that says why the golden digests change (docs/ROADGEN.md §6.1, U7) and names the tests and the negative cases. Push, and open the PR with base `main`.

### PR 1: Areas: the road to the sea in five minutes **Δ U1–U8, U10, U11, U13**

Title `areas: the road ends after 100 turns, with longer straights and 60 s days (SP PR 1)`. Branch `sp/1-road`, from `main` (§4.1).

| Area | Files |
|---|---|
| Areas | `areas/schedule.tres`: the areas at turns 34, 58, 76 and 84, and the pier after turn 100 (§5.1). `areas/schedule_home.tres`: its mirror. `areas/meadows.tres` and `areas/desert.tres`: their straights, and `day_seconds = 60.0`; the Desert's decoys at 0.15 and side roads at 0.3 (Q14, U13). `areas/village.tres`: its straights. `areas/rural.tres`: `day_seconds = 60.0` (§5.2, §5.3) |
| UI | `ui/route_strip.gd`:7: "a few pixels a turn" (§5.4) |
| Tests | The 14 files of §5.7. New: `test_from_the_meadows_on_the_straights_are_longer_than_rurals` (E2). `test_drive_to_the_end.gd`: `MOST_SECONDS` and `_check_night()`, on 10 seeds a road and each road's slowest of P1, and a count of the damage (E1, E3). `test_hud.gd`: the strip's even climb (E6). The rest: the new turns, digests and times |
| Docs | §5.8's Δs to `plan.md`, docs/ENDGAME.md, docs/DAYNIGHT.md and docs/ROADGEN.md (U12) |

21 files, +193 −128, and the docs. Expect, against `main` at ec6f54d: the same 221 scripts loaded and 103 test scripts; 904 tests, one more; 516,682 asserts, 60,141 more, as `test_road_generator_pattern.gd`'s tests assert each tile of `endless()`'s road to turn 300, which is longer from turn 58, 61,599 more; GUT 143.4 s locally, against 141.7 s; and `autopilot: tile 165, turns 35, area rural`, as on `main`. Negative cases N1–N11.

**Acceptance:** E1–E6, E8, E9.

### PR 2: Docs: `docs/SPEEDUP.md` replaces the plan

Title `SP PR 2: docs/SPEEDUP.md replaces the plan`. Branch `sp/2-docs`, from `main`, once PR 1 has merged (Q12).

| Area | Files |
|---|---|
| Docs | `docs/SPEEDUP.md`, new, at most about 15 KB: the design as built, with every ID that code, tests or docs cite, E1, E3, §5.4 and the U#s and P#s that they cite, and a header that gives `git show <sha>:SPEEDUP_PLAN.md` (planning.md §6). The code's cites of `SPEEDUP_PLAN.md` become `docs/SPEEDUP.md`'s, the same length. `SPEEDUP_PLAN.md`, deleted |
| Owner's paths | `AGENTS.md`: the pier after the road's 100th turn (:7), U# (SPEEDUP) among the IDs (:18), and eight plans merged, with SP's PRs (:20). `docs/README.md`: SP's row, and ENDGAME's row's "after 280 turns" |
| Guidelines | Up to five of SP's learnings, each where an agent reads it as it works: `AGENTS.md` §2, `.github/instructions/` or docs/agents/ (planning.md §7) |
| IP | Eight smaller plans, with SP's (:101); M7.6's screenshots at turns 0, 34, 58, 76 and 84 (:209, :320); the schedule test's row, "Area switches at 34/58/76/84" (:249); and M7's notes from §9 |

No code, so the counts are PR 1's. PR 2 checks each sentence of `docs/SPEEDUP.md` against the plan and the code (planning.md §6), and takes the learnings step that #115 added (planning.md §7): it gathers what SP's PRs and sessions taught, picks five at most, changes the guidelines with them, and lists them in its body.

**Acceptance:** E7, E9.

### 4.2 Landing (Q13)

This plan's PR and PR 1 both target `main`, so there is no stack: PR 2 starts from `main` once PR 1 has merged. The owner lands both: PR 1 as the plan's last code PR, after §6.4's optional run on the Fold4, and PR 2, which changes `AGENTS.md`, `docs/README.md` and IP (`AGENTS.md` §5 step 4). If the owner answers Q13 otherwise, agents land PR 1 with `tools/agent/land_pr.sh` once its reviews are done.

**Labels.** This plan's PR, PR 1 and PR 2 each get `needs-owner` as they open, with a PR comment that says why: the owner lands plan PRs, this section marks PR 1 unless Q13's answer is otherwise, and PR 2 changes `AGENTS.md`. Only the owner removes it.

The plan changes only on `sp/plan` until its PR merges. After that, PR 1 carries the plan's final sync: its status, §4.3's rows, the counts and §6.4's results (planning.md §5). PR 2 deletes it.

### 4.3 Review fixes

Fixes from the prototype's build, the internal review (§4.4) and the PRs' reviews, each with its tests and negative case.

| PR | Change | Tests | Negative case |
|---|---|---|---|
| 1 | The strip's test at 529378c compared each climb, an int, with half the car's mark, a float, and GUT warned "Float/Int comparison" once for each reference screen, where `main`'s suite has no GUT warning. 6740ac4 compares with `floori()` of it: the climbs are whole pixels, so the rule is the same (§5.4) | `test_the_route_strip_marks_each_area_the_car_and_the_best` | N4, which still fails it; no GUT warning at 6740ac4 |
| 1 | P8: from turn 84 the endless road is the Desert, so `test_autopilot_300_turns.gd`'s 300 turns took 831.4–920.2 s at 339b126, not 607.5–656.2 s. 339b126 said so in its comment, "about 15 minutes", and raised the cap of both its drives from 20 minutes to 30. 9229f94 gives each drive twice its own time (§4.4 #6): 26 minutes for `endless()`'s 300 turns, 762.4–816.3 s with a130c54's Desert, and 16 for the road with every kind of junction, 476.2–495.8 s as on `main` (U11) | `test_autopilot_300_turns.gd`'s two tests: 2/2, 100 asserts, as on `main` | None: a cap only stops a car that never ends |
| 1 | a130c54 (§4.4 #1): P10's 5,000 seeds a road, at 339b126, found home seed 3879 at 301.6 s, its Desert zone with 15 decoys among 31 junctions. The Desert's straights become 6–12 tiles, from 6–14, its decoys 0.15, from 0.2, and its side roads 0.3, from 0.25 (U13, Q14), and P1, run again on 5,000 seeds a road, has none over 278.7 s | `test_the_game_road_matches_its_digests`, new digests; `test_from_the_meadows_on_the_straights_are_longer_than_rurals` | N11: 339b126's `desert.tres` |
| 1 | 9229f94 (§4.4 #1, #3): `test_drive_to_the_end.gd` also drives each road's slowest seed of P1, 2823 to the pier and 3879 home, and counts `damaged`, where 339b126 read the health at the end, which a pit stop repairs | `test_the_autopilot_drives_to_the_pier`, `test_the_autopilot_drives_the_road_home` | N9, a bound of 270 s, fails only the slow seeds' times; N10, damage at each drive's start, fails "no damage" on each drive, and passed 339b126's test |

### 4.4 Internal review

gpt-6.2-sol (`rubber-duck`), a model of another family, reviewed this plan and the prototype at 339b126 (`AGENTS.md` §5). Each finding was checked before it was fixed or declined:

| # | Finding | Checked | Change |
|---|---|---|---|
| 1 | E1's five minutes were a sample, 10 seeds a road in the test and P1's 1,000, while a zone's decoys have no bound | P10, 5,000 seeds a road at 339b126: home seed 3879 took 301.6 s (U13). The test can't pass a late run: its cap, at twice the bound, fails the time's assert | a130c54's Desert (U13, Q14); P1 on 5,000 seeds a road; 9229f94 drives each road's slowest seed, and N9 arrives and fails only the time (§4.3). The bound stays a measured one, and Q15 asks the owner whether that is enough (§8). Q10 tells the end screen's 5 s apart from E1's time, which runs to the arrival |
| 2 | The Road Home doesn't keep its first zone: it starts in the Desert, whose 60 turns become 16 | `schedule_home.tres`:17–18, the Village at turn 60; P2: with the Desert's 60 turns first, the road takes about 371 s | Q2 asks the owner, with the mirror as its default |
| 3 | E1 times the simulation, not the run's clock, and its health at the end passes damage that a pit stop repaired | The scene steps the run's clock and the car in the same physics frames (`main.gd`:138–143, `car_controller.gd`:42–43), as `test_arrival.gd`:42 checks; with damage at each drive's start, 339b126's test passed, as a pit stop heals 50 | 9229f94 counts `damaged` (N10, §4.3). A drive of the whole scene to each road's end, declined: `test_arrival.gd` checks its clock |
| 4 | E3 and E8 overstate the night: `_check_night()` reads the days as loaded; neither movie showed the Meadows' night; a sample each 0.25 s can't rule out a flash | The days are the areas' data, as their straights are (IP D11); N3's 120 s days fail both drives | E3 reworded. A movie from the Meadows, and each frame of the movies sampled (§6.4) |
| 5 | Old saves: the goal line clamps the overall best turn, not the road's, and `record_arrival()` keeps the least time | `game_over.gd`:122–127: until a first arrival at the sea, the goal line shows `best.turns`, the most turns of any whole run (`save_data.gd`:216), clamped to the road's finish. `test_save_data.gd`:286 and :436 test the least time | §5.5, Q7 and E6 reworded. No new test: PR 1 changes no code of the save's |
| 6 | Keep Driving gets slower, and the cap of its unchanged drive rose too | P8: 881 s on average at 339b126, about 40% longer, and both drives' caps at 30 minutes | Q11 says how much slower, 26% with a130c54's Desert; 9229f94 gives each drive twice its own time (§4.3) |
| 7 | §4.1 left the plan alone while §4.2 had PR 1 sync it; the labels; the negative cases on the reviewed head; N7's out-of-memory; this section, empty | As said | §4.1 steps 3–4, §4.2's labels, N7 on its script alone with §9's note, and this section |

Its suggestions, taken: E2 cites the drive to the end for the Coast; §5.2 tells `straight_accel`, which shapes the target speed, from `ACCEL`, and §8 drops a player's braking, as a player only steers (`input_router.gd`:3–16); and U9 counts junctions, not turns, decoys included: about 33% of runs arrive at 1% errors a junction, against about 4%.

The same model reviewed the fixes at 9229f94. It found #2, #7 and the suggestions resolved, and raised six findings, each checked and fixed:

| # | Finding | Change |
|---|---|---|
| A | §5.2's model ended the Road Home with the Coast's straight, where the generator ends each road with its last area's, the City's 2–5 tiles home (`road_generator.gd`:24–25, :219–230), and §8 took the model's mean bias off its slowest runs | The model ends each road as the game does, and every case ran again: home, 241 s on average, and of a million runs, none over 300 s. §5.2 and §8 give the model's own times and its error against P1, which stops at P1's one run in a thousand, and Q15 asks the owner whether a measured bound is enough |
| B | Q10's wording, and the clock's cites | §4.4 #3 cites `main.gd`:138–143 and `car_controller.gd`:42–43 |
| C | Q2's alternative claimed more than P2 modelled, and a cite | Q2 gives P2's two cases; `schedule_home.tres`:17–18 |
| D | PR 1 left out U13's decoys and side roads | §4's diagram, PR 1's heading and areas, and §5.2 |
| E | #5's fix said the goal line shows the farthest turn on the road to the sea | It shows `best.turns`, the most of any whole run (§4.4 #5, §5.5) |
| F | §6.4 read the light's rate from each frame's mean | The movies show the road; the light's rate is the tests' (§6.4, §8, U10) |

It still found #1 and #3–#6 open. #1 is Q15. The rest are declined:
- #3: `test_arrival.gd`:42 checks the scene's clock against its steps, and the whole road's movie shows the end screen's "Time: 3:45" for pier seed 1, which P1 timed at 225.13 s (§6.4).
- #4: `_check_night()` checks each zone's time against the hour at which its area's day reaches its night. `test_day_cycle.gd`:36, :21 and :49 test that a zone's clock starts at 7:00, runs round in its `day_seconds`, and shows each key hour's light, the night's at 20:00. The whole road's movie shows the three nights.
- #5: `record_arrival()` replaces a best time only with a faster one (:248), which `test_save_data.gd`:286 and :436 test, and on every seed measured an arrival on the new road took about half as long as one on `main`, so it would be faster (§5.5).
- #6: each cap is about twice its drive's own time, as `main`'s 20 minutes were for 607.5–656.2 s.

It then found A, C, D and E resolved, and raised three more, each checked and fixed:
- B: the cite of `car_controller.gd` was two lines off; at ec6f54d, :42 is `_physics_process` and :43 `sim.step`.
- F: "no flash of the whole view" was read from each frame's mean, which can miss a flash of two frames. §6.4 now gives what was measured: runs of 1 to 30 frames, and each frame's luminance unrounded, as rounding each pixel's had turned the dusks' steps of one level of blue into pulses of up to 0.72.
- The scope, the goal, U8 and §5.8's Δs promised five minutes as a cap where Q15's default is a target, and #5's decline claimed every arrival: they say "on every seed measured", and U8, #5 and §5.5 say that an arrival replaces a best time only if it is faster, as each measured would be.

Its last pass, on these fixes, found nothing open.

---

## 5. Design

§5.1–§5.6 describe PR 1 as built on the prototype, §5.7 its tests and §5.8 its Δs to the docs. Each design serves one of the needs that Mark Rosewater lists for every game, or a practice that shipped games have tested:

| Principle | What it asks | Where |
|---|---|---|
| Inertia (Rosewater) | The game moves toward an end, which a player can reach | The road ends after 100 turns, about four minutes on the autopilot (§5.1) |
| The interest curve (Jesse Schell, *The Art of Game Design*) | Tension rises and falls, toward a climax | Each long area takes about a minute, and the Village's 21 s are a rest before the Desert, the climax (§5.1) |
| Short sessions (mobile games) | A whole run fits in a short sitting | Five minutes at most, on the reference device, a phone (E1) |
| Flavor (Rosewater) | The world tells its story | Each long zone still shows its night (§5.3) |

### 5.1 The turns (PR 1; Q1, Q2, Q9; U1, U3; E1, E2, E5)

The road to the sea, `areas/schedule.tres`, with P1's times on 5,000 seeds and P5's for `main` on seeds 0–19:

| Area | From turn | Turns | Way in | Straights | Day | Time, P1 (mean) | A turn | `main`: turns, mean time |
|---|---|---|---|---|---|---|---|---|
| City | 0 | 34 | — | 2–5 | 120 s | 49.6–64.3 s (58.2) | 1.71 s | 34, 57.9 s |
| Rural | 34 | 24 | The tunnel, a pit stop | 3–7 | 60 s | 40.2–66.9 s (50.6) | 2.11 s | 66, 135.8 s |
| Meadows | 58 | 18 | The bridge, a pit stop | 6–12 | 60 s | 42.5–85.8 s (56.6) | 3.14 s | 100, 217.0 s |
| Village | 76 | 8 | — | 4–8 | 120 s | 14.8–35.6 s (20.9) | 2.61 s | 20, 39.0 s |
| Desert | 84 | 16 | Last Gas, a pit stop | 6–12 | 60 s | 34.2–69.2 s (47.0) | 2.94 s | 60, 136.1 s |
| Coast | 100 | — | — | 20 | 120 s | 4.0–4.2 s (4.1) | — | 3.6 s |
| The road | | 100 | | | | 209.2–272.7 s (237.3) | | 280, 562.2–613.3 s (589.4) |

The Road Home, `areas/schedule_home.tres`, is its mirror (Q2): `mirrored`, starting W (docs/ENDGAME.md W9), with the same turns in reverse, and its set pieces lead into Rural and the City:

| Area | From turn | Turns | Way in | Time, P1 (mean) | A turn | `main`: turns, mean time |
|---|---|---|---|---|---|---|
| Desert | 0 | 16 | — | 37.9–79.7 s (50.9) | 3.18 s | 60, 142.5 s |
| Village | 16 | 8 | Last Gas, a pit stop | 14.7–38.3 s (21.0) | 2.62 s | 20, 38.8 s |
| Meadows | 24 | 18 | — | 45.3–85.2 s (58.8) | 3.27 s | 100, 219.0 s |
| Rural | 42 | 24 | The bridge, a pit stop | 40.6–66.6 s (50.2) | 2.09 s | 66, 136.6 s |
| City | 66 | 34 | The tunnel, a pit stop | 50.1–63.0 s (56.4), with the last straight and home's tiles | 1.66 s | 34, 56.5 s |
| The road | | 100 | | 208.1–278.7 s (237.3) | | 280, 561.4–614.0 s (593.3) |

How the turns were chosen:
- **The City stays**, as the owner asked: its 34 turns are where a run learns the pattern, with the tutorial before them, and they take 58 s. The Coast's straight takes 4 s more. That leaves the 66 turns between them to fit the rest of the five minutes.
- **The straights first.** The owner asked for longer straights from the Meadows on, and they cost time: §5.2's model puts SP's 100 turns at 204–205 s on average with `main`'s straights, and at 240–241 s with SP's, by road, so the straights add 35–37 s. Shorter straights would buy turns back, but not what the owner asked.
- **A margin for the slowest seeds.** The time to the end spreads: on 5,000 seeds a road, its standard deviation was 9.05 s to the pier and 9.39 s home, and the slowest of P1's 10,000 runs took 278.7 s. So SP aims at a mean of about 237 s, 6.7–6.9 standard deviations below the bound: 67 runs of the 5,000 to the pier and 66 home took more than 260 s, 4 and 5 more than 270 s, and one, home seed 3879, more than 275 s. The slowest are slower than a normal spread's: seed 3879 took 4.4 standard deviations more than the mean, as a zone's decoys vary widely (U13). §5.2's model, on a million runs a road, put the slowest at 298.4 s to the pier and 296.8 s home, but it isn't checked against the game that far into the tail (Q15, §8). E1's ten test seeds a road take 225.1–243.8 s to the pier and 225.3–261.2 s home, and P1's slowest seeds, which E1 drives too, 272.7 s and 278.7 s (P1).
- **About a minute an area.** Rural's 24 turns take 50–51 s, the Meadows' 18 take 57–59 s and the Desert's 16 take 47–51 s, by road, so each long area is about one of §5.3's 60 s days. The Village keeps its place as an interlude before the Desert: its 8 turns take 21 s, 9% of the run, where its 20 took 39 s, 7% (Q9).

The order of the areas, their set pieces, Last Gas and the pit stops' rule stay (Q8). The pit stops come 24 and 26 turns apart on the road to the sea, after turns 34, 58 and 84, where they came 66 and 120 apart; on the Road Home, 26 and 24 apart, after turns 16, 42 and 66. A Departure from an area (docs/ENDGAME.md §5.11) has as many turns fewer to the end: from the Desert 16 turns to the pier, the Village 24, the Meadows 42 and Rural 66; on the Road Home, from the Village 84 turns home, the Meadows 76, Rural 58 and the City 34.

`validate()` (`area_schedule.gd`:48) keeps each area's gap, its set piece, its longest straight and the next junction's tile (`gap()`, :113), within `BUFFER_REFILL_AT`, 37 tiles (docs/M2.md H31, docs/M4.md K1). SP's widest is the Meadows' 18, behind the bridge (5 + 12 + 1), and the Coast's 21 as on `main`; on the Road Home, 13: the Desert's and the Meadows' (12 + 1), and Rural's, behind the bridge (5 + 7 + 1). No rule binds the switch turns' parity: a set piece takes the heading of the straight it replaces (`set_piece.gd`:21). SP's, like `main`'s, are all even, so each area starts with the same turn as on `main`, a left on the road to the sea.

### 5.2 Straights and speed (PR 1; Q3, Q4; U4; E2)

The car sets its own speed: the player only steers (`input_router.gd`:3–16). `target_speed()` (`car_sim.gd`:250–259) starts each straight at its area's `junction_speed` and rises by its `straight_accel` for each tile driven on it, up to the run's cap, `minf(GLOBAL_SPEED_CAP, BASE_TOP_SPEED + dist_total * TOP_SPEED_GROWTH)`: 4.0 tiles/s at the start, 0.002 more a tile driven, and at most 7.0 (`tuning.gd`:65–68). Within `junction_brake_distance` of the next junction, it is `junction_speed` again. `_update_speed()` (:262–277) moves the car's speed toward it at `ACCEL`, 2.0 tiles/s², or `BRAKE`, 4.0 (`tuning.gd`:69, :72), and before a junction brakes harder if it must, to enter the junction's tile at `junction_speed`. A turn's braking and corner cost the same on any straight, so a longer straight takes less time a tile: the car reaches a higher speed and holds it longer. The generator draws each straight's length from its area's `min_straight`..`max_straight`, with the road's stream, `_rng_road` (`road_generator.gd`:417–418). SP changes only the ranges, and the Desert's decoys and side roads (Q14, U13):

| Area (road to the sea) | Straights, tiles | Path tiles a turn | Mean speed, tiles/s | Mean top speed, tiles/s |
|---|---|---|---|---|
| Rural | 3–7, unchanged | 6.7 → 6.9 | 3.27 → 3.27 | 5.08 → 4.61 |
| Meadows | 3–7 → 6–12 | 7.1 → 11.8 | 3.27 → 3.74 | 5.34 → 5.02 |
| Village | 2–5 → 4–8 | 5.35 → 8.3 | 2.74 → 3.17 | 4.25 → 5.12 |
| Desert | 3–8 → 6–12 | 8.0 → 11.7 | 3.54 → 3.99 | 5.79 → 5.51 |

`main`'s values are P5's, on seeds 0–19, and SP's P1's, on 5,000 seeds. Each area's `straight_accel`, `junction_speed` and `junction_brake_distance` stay. The new test, `test_from_the_meadows_on_the_straights_are_longer_than_rurals`, checks E2's rule on each entry of the road from the Meadows on, the Coast's 20 tiles included: its shortest and longest straights are longer than Rural's, 3 and 7.

**Why these lengths.** A model of the run, P2 (in the prototype's session, not in the repository), draws roads as the generator does, the turns, the decoys and each straight from its area's range, and moves the speed toward `target_speed()` at 60 Hz along each straight, as `_update_speed()` does. It leaves out the corners, the dead ends and the set pieces' shapes. Each road ends with the straight after its last turn, the last area's, to the finish's first tile: the Coast's 20 tiles to the pier, and the City's 2–5 home (`road_generator.gd`:24–25, :219–230). It runs slow against P1: 240 s on average to the pier, where P1 measured 237.3 s, and 241 s home, where P1 measured 237.3 s too. On 2,000 runs a road, with the Desert's decoys at 0.15 in each case but `main`'s (Q14):

| Case | To the pier: mean | p95 | Slowest | Home: mean | p95 | Slowest |
|---|---|---|---|---|---|---|
| `main` | 595 s | 618 s | 649.6 s | 596 s | 620 s | 645.6 s |
| SP's turns, with `main`'s straights | 205 s | 218 s | 233.5 s | 204 s | 216 s | 232.4 s |
| SP, the default | 240 s | 254 s | 272.4 s | 241 s | 257 s | 277.2 s |
| Twice `main`'s straights, Q3's alternative: the Meadows 6–14, the Village 4–10, the Desert 6–16 | 253 s | 270 s | 286.6 s | 256 s | 273 s | 293.3 s |
| The same, with the areas at 34, 58, 74 and 82 and the end after turn 98 | 246 s | 262 s | 280.5 s | 249 s | 266 s | 293.2 s |

The slowest runs are rarer than 2,000 runs show (U13). On 50,000 runs a road, the model's slowest took 277.8 s to the pier and 289.7 s home, where with the prototype's first Desert, 6–14 tiles with decoys at 0.2, they took 291.9 s and 299.8 s. On a million runs a road, the slowest took 298.4 s to the pier and 296.8 s home, and none passed 300 s: 4 to the pier and 2 home passed 290 s. Those are the model's own times. Against P1's 5,000 seeds a road, the model runs slow by 1.1% and 1.7% on average, and by 0.4–2.4 s at P1's p99 and p99.9, so its tail follows the game's as far as P1 reaches, one run in a thousand. Past that, nothing checks it against the game (Q15, §8). Q14's alternative, the Desert's decoys at 0.15 with straights of 6–14, took 3.4–3.9 s more on average, by road. Twice `main`'s straights put 7 of 50,000 runs home past 300 s, the slowest at 316.7 s, and with the end after turn 98, one to the pier, at 302.7 s. SP's are about twice `main`'s at their short end and less at their long end, and the Village's, which are the defaults' 2–5 on `main` (`area_def.gd`:14–15), become 4–8, above Rural's as E2 asks.

**The top speed (Q4, U4).** A run is now 700–941 path tiles to the pier, not 1,829–1,998, so the cap ends at 5.33–5.82 tiles/s, not 7.0: the Desert's mean top speed is 5.51 tiles/s, against 5.79 on `main`, and on the Road Home, which starts in the Desert, 4.35. SP keeps `TOP_SPEED_GROWTH`, so the car's feel on every road, Keep Driving's too, stays as tuned. P6 tried 0.0035 a tile, which reaches 7.0 after about 860 tiles: the Desert's mean top speed became 6.57 tiles/s, but a run was only 3.5 s quicker to the pier and 2.6 s home, as the junctions and corners take most of a turn's time.

### 5.3 Days (PR 1; Q5; U2, U10; E3)

A zone's clock starts at 07:00 as the car enters it (`DAY_START_HOUR`, `tuning.gd`:247) and turns a whole day in its area's `day_seconds`, 120 s by default (`area_def.gd`:71). `rural.tres`, `meadows.tres` and `desert.tres` set `day_seconds = 60.0`; the City, the Village and the Coast keep 120 s. The light's keys (`LIGHT_HOURS`, `tuning.gd`:251) fall at:

| Hours | The light | A 120 s day | A 60 s day |
|---|---|---|---|
| 07:00–17:00 | Day, white | 0–50 s | 0–25 s |
| 17:00–20:00 | Dusk: orange at 18:30, then the night's blue | 50–65 s | 25–32.5 s |
| 20:00–04:30 | Night | 65–107.5 s | 32.5–53.75 s |
| 04:30–07:00 | Dawn: pink at 06:00, then white | 107.5–120 s | 53.75–60 s |

`DayCycle.least_day_seconds()` (`day_cycle.gd`:123–127), 55.68 s, is the shortest day whose light changes within `LIGHT_MAX_RATE`, a quarter of white a second, so that the light shown follows the clock exactly (docs/DAYNIGHT.md §5.3). `AreaDef.validate()` (`area_def.gd`:105–110) reports a shorter day, as N7 shows. A 60 s day's steepest change uses 92.8% of the rate.

**Why 60 s (P3).** The share of the zones of Rural, the Meadows and the Desert, in P1's 10,000 runs, that reached the night:

| Zones | 120 s | 90 s | 80 s | 60 s |
|---|---|---|---|---|
| Rural, to the sea | 0.1% | 65.6% | 98.9% | 100% |
| Meadows, to the sea | 8.1% | 93.8% | 100% | 100% |
| Desert, to the sea | 0.1% | 32.9% | 76.6% | 100% |
| Rural, home | 0.1% | 61.8% | 98.5% | 100% |
| Meadows, home | 14.5% | 98.3% | 100% | 100% |
| Desert, home | 1.5% | 61.3% | 94.2% | 100% |
| All 30,000 | 4.1% | 68.9% | 94.7% | 100% |

At 60 s, each reached it: the shortest, a Desert zone of 34.25 s on the road to the sea, had 1.75 s of night (§8). A zone's night lasted 14.2–20.8 s on average, by area and road, and the night was 21.9% of a run to the sea and 23.3% of one home, against 27.1% and 27.2% on `main`. The City's day stays 120 s: its zones end at 16:56–19:51, all but one of the 5,000 in its dusk, so a run's first night still comes in Rural (docs/DAYNIGHT.md §5.8). The Village's 21 s and the Coast's 4 s end by day.

**Longer zones.** 3,688 of the 30,000 zones, 12.3%, lasted past 60 s, into a second morning, and 2, a Meadows zone on each road, past 85 s, into a second dusk; none reached a second night, at 92.5 s. A day that comes round again is what a zone's clock does on `main` in a long zone too (docs/DAYNIGHT.md §5.1).

**The light between zones (U10).** A zone that ends at night hands over to the next zone's morning, which `Daylight` fades in within `LIGHT_MAX_RATE`, in 2.33 s (docs/DAYNIGHT.md Q2). More zones now end at night or dawn (P4):

| Zones | Night | Dawn | Day | Dusk |
|---|---|---|---|---|
| Rural, to the sea | 80.4% | 18.3% | 1.3% | — |
| Meadows, to the sea | 33.9% | 40.8% | 25.3% | 0.02% |
| Desert, to the sea | 89.9% | 8.9% | 1.2% | — |
| Rural, home | 83.5% | 15.3% | 1.3% | — |
| Meadows, home | 19.2% | 42.3% | 38.5% | 0.02% |
| Desert, home | 72.6% | 21.1% | 6.3% | — |

On `main`, 39 of P5's 120 such zones ended at night. The movies of §6.4 show the fades, and `test_daylight_run.gd`:129 asserts their rate each frame.

### 5.4 The route strip (PR 1; Q6; U5; E6)

The strip (`ui/route_strip.gd`, docs/ENDGAME.md §5.14) stays 40% of the HUD's height (`hud.tscn`:66–68): 256, 320 and 368.8 pixels on the reference screens, 640, 800 and 922 pixels high. `RouteStrip.height()` (:64–68) places turn t at `roundi(t / finish_turn * roundi(length))`, so over 100 turns its car climbs 2.56, 3.2 and 3.69 pixels a turn on average, 2–3, 3–4 and 3–4 pixels each, where `main`'s 280 turns gave 0.91–1.32. Its ticks are at turns 0, 34, 58, 76, 84 and 100; the closest, the Village's and the Desert's, are 8 turns apart, 20.5–29.5 pixels.

The car's mark is `CAR_HEIGHT`, 8 pixels, high. `test_the_route_strip_marks_each_area_the_car_and_the_best` drives the strip's car over 100 turns on each reference screen, and checks that each climb is the strip's rounded length over 100 turns, rounded down or up, so the car climbs evenly, and at most `floori(CAR_HEIGHT / 2.0)`, 4 pixels, so that each step overlaps the last by half the mark. `main`'s test allowed 0–2 pixels, a pixel or so a turn. The comment at `route_strip.gd`:7 says "a few pixels a turn". The test's HUD, sized by `PIXEL_A_TURN` so that its strip is a pixel a turn, becomes 250 pixels high, for a strip of 100, from 700. With a strip of 80% (N4), the car climbs 5.12–7.38 pixels a turn, which the test rejects.

Q6's alternative, a strip of 20%, would climb 1.28–1.84 pixels a turn, nearer `main`'s, but with the Village's and the Desert's ticks only 10.2–14.8 pixels apart, under twice the mark's height.

### 5.5 The save (PR 1; Q7; U8; E6)

Saves stay at version 5 (`save_data.gd`:14), and nothing in the save names the road's length but `V3_FINISH_TURN`, 280 (:51), which migrates version 3's saves, made when both roads had 280 turns: it stays. A save from `main` loads as it is:
- **The best time.** `record_arrival()` keeps the least time (:248), so an arrival after SP replaces `main`'s best time only if it is faster. On every seed measured, it would be: the autopilot took at most 278.7 s on the new road (P1) and at least 561.4 s on `main` (P5), and a player's seconds off the road, which their health limits (§8), don't close that gap.
- **The farthest turns**, up to 280, are kept as the most: each road's (:211, :251), and `best.turns`, the most of any whole run (:216). Until a first arrival at the sea, the goal line shows `best.turns`, clamped to the road's finish, `mini(best.turns, finish_turn)` (`game_over.gd`:125–127): a player who has passed turn 100 on `main` without arriving reads "Next: reach the sea. Your best: turn 100 of 100" until they arrive. The strip clamps the road's farthest (`route_strip.gd`:64–68), and `test_the_route_strip_shows_only_on_a_road_with_a_finish` checks it. `Hitchhiker.road_turn()` takes `mini(farthest, finish_turn)` on the Road Home (`hitchhiker.gd`:54–58), so a home farthest of 50, in `main`'s Desert, now places her before the 50th junction, in Rural: she still stands at the player's farthest junction, as docs/ENDGAME.md §5.17 has it.
- **History.** The overall best turns and the Atlas's bests (`atlas_screen.gd`:60–73) aren't clamped: an area's best turns on `main`, such as the Meadows' up to 100, can exceed its turns now, 18, and stay as they were driven.

Q7's alternative, version 6, would clamp each road's farthest turn and drop `main`'s best times: a migration and its tests for a Pages build whose players are few.

### 5.6 What stays (PR 1; Q8, Q11; U7, U9; E4)

- **The road up to the Meadows.** The City's and Rural's areas, straights and set piece are as on `main`, and the generator draws each straight from its area's range in turn, so on 200 seeds the road to the sea is `main`'s, tile for tile with its dead ends, up to and including its 58th junction, and differs by its 66th (P7). The Road Home starts in the Desert, whose straights change, so it differs from `main`'s by its 16th junction, the first that P7 compares. `smoke.sh`'s 60 s end in Rural at turn 35, as on `main`.
- **The golden digests** (U7) of `endless()` on seeds 0–19 to turn 300 change, as that road crosses the Meadows from turn 58 and the Desert from 84 with longer straights, and the Desert's junctions with fewer decoys: `PATH_DIGEST` becomes `3b31d12a19e3db74e59e97d206fc3d3a` and `ROAD_DIGEST` `c131b56bf3794988820e911c0ff5b485`, and PR 1's commit says why (docs/ROADGEN.md §6.1).
- **The tutorial** (docs/TUTORIAL.md) comes before the City's 34 turns, from whose end the schedule counts, and doesn't change. On seeds 0–99, the autopilot finished it in 17.9–22.8 s and arrived at 236.2–280.4 s, each with full health (P9; Q10).
- **Keep Driving** drives `endless()`, which runs the Desert forever from turn 84 (Q11). Its turns past 84 take longer than `main`'s Meadows', so `test_autopilot_300_turns.gd`'s 300 turns take 762.4–816.3 s, not 607.5–656.2 s (P8, §4.3); its drive with every kind of junction takes 476.2–495.8 s on both.
- **Departures** start at their area's new turn (§5.1).
- **The legends** and their pools stay. A run's turns shift toward the City, which has 34% of them where it had 12% (U9): a run meets the City's junctions as often as on `main`, and the later areas' less often. With the decoys, a road has about 110 junctions, not 324, so at 1% errors a junction about 33% of runs would arrive, where about 4% did. An arrival unlocks a legend of any area's pool (docs/ENDGAME.md §5.5), and Departures reach the later areas' legends.
- **The music and the ambience** cross-fade on `area_changed`, as on `main`. Their loops last 7.27–10.67 s and 4.0 s, so the Village's 21 s play its music at least twice.

### 5.7 Tests (PR 1)

| File | Change |
|---|---|
| `tests/unit/test_area_schedule.gd` | New: `test_from_the_meadows_on_the_straights_are_longer_than_rurals` (E2). Renamed: `test_areas_and_set_pieces_switch_at_34_58_76_and_84`, `test_the_games_road_ends_at_the_pier_after_its_100th_turn`. The new turns in each test of the schedules, the Road Home, the pit stops, Departures' copies and `validate()`'s finish (U6) |
| `tests/sim/test_drive_to_the_end.gd` | `MOST_SECONDS`, 300 s, asserted on each run (E1), on `SEEDS`, 10 seeds a road, not 5, and on each road's slowest seed of P1, `SLOWEST_TO_THE_PIER`, 2823, and `SLOWEST_HOME`, 3879 (U13); `damaged` counted, and none allowed, where `main` checked the health at the end, which a pit stop repairs (N10); `_check_night()` on each zone of `NIGHT_AREAS`, Rural, the Meadows and the Desert, that the car leaves (E3); `MAX_STEPS` twice `MOST_SECONDS`; 100 turns |
| `tests/unit/test_hud.gd` | The strip's even climb (§5.4), and the new ticks and turns |
| `tests/unit/test_road_generator_finish.gd` | Renamed: `test_the_road_home_ends_at_home_after_100_turns`; both roads' 100 turns |
| `tests/unit/test_road_generator_determinism.gd` | The new digests (§5.6) |
| `tests/integration/test_area_start.gd` | The Village's 8 turns |
| `tests/integration/test_hitchhiker_run.gd` | Her departure at the Road Home's turn 18, in the Village from 16 |
| `tests/sim/test_area_order.gd`, `tests/sim/test_tutorial_run.gd` | The switches at 34, 58, 76 and 84, driven to turn 90, with their caps and comments (U11) |
| `tests/sim/test_set_pieces_on_the_road.gd` | Seed 1 meets the bridge after turn 58, and has left it by 63 |
| `tests/unit/test_game_over.gd` | A best of turn 72 before the first arrival |
| `tests/unit/test_prop_scatter.gd` | Past the bridge after turn 58 |
| `tests/sim/test_autopilot_300_turns.gd` | The comments, and each drive's cap at twice its time: 26 minutes for `endless()`'s 300 turns, about 13 (P8), and 16 for the road with every kind of junction, about 8, where both had 20 (U11) |
| `tests/integration/test_daylight_run.gd` | A comment: the zone of 60 s that its test enters is any area's, whatever Rural's own day |

The tests that use 280 as a value stay: `test_hitchhiker.gd`, `test_title.gd` and `test_hitchhiker_run.gd`:118–119 pass a finish or record an arrival of their own, and `test_save_data.gd` migrates version 3's saves (§5.5).

### 5.8 Docs (PR 1; Q12; U12)

PR 1 changes `plan.md`, the game's design, in place, and adds a note to each summary of a finished plan, as EG did ("Since EG, …", docs/ZONE_SELECT.md Z4), so that its history stays. Until PR 2, the notes cite `SPEEDUP_PLAN.md`; PR 2 makes them `docs/SPEEDUP.md`'s.

| Where | Δ |
|---|---|
| `plan.md`:13 | "After its 280th turn" → "After its 100th turn" |
| `plan.md`:122–125, §3.6 | The table's turns: the Meadows at 58, the Village at 76, the Desert at 84 and the Coast at 100 |
| `plan.md`, after §3.6's table | A new first bullet: "From the Meadows on, the road turns less and runs straighter: each area's straights are longer than Rural's, the Meadows' 6–12 tiles, the Village's 4–8 and the Desert's 6–12, and the autopilot drives the whole road in about four minutes, and within five on every seed measured (`SPEEDUP_PLAN.md` E1, Q3, Q15)." |
| `plan.md`:229, §5.5 | "120 s by default: dusk comes 50 s into a zone, and the night at 65 s." → "120 s by default, and 60 s in Rural, the Meadows and the Desert, whose zones take about a minute: dusk comes 10/24 of a day into a zone and the night 13/24, at 50 s and 65 s in a day of 120 s, and at 25 s and 32.5 s in one of 60 s (`SPEEDUP_PLAN.md` Q5)." |
| `plan.md`:356, §9 | `"best_seconds": 581.0` → `237.0`, and `"farthest": 280` → `100` |
| `plan.md`:390, §11 | "turns 34, 100, 200, 220 and 280, and the road ends at the pier after its 280th turn" → "turns 34, 58, 76, 84 and 100, and the road ends at the pier after its 100th turn" |
| `plan.md`:429, §13 | "after turn 280" → "after turn 100" |
| docs/ENDGAME.md :3 | Adds: "Since SP, the road ends after its 100th turn, and the autopilot drives it in about four minutes (`SPEEDUP_PLAN.md` Q1)." |
| docs/ENDGAME.md :11, E6 | Adds: "Since SP, past turn 100 (`SPEEDUP_PLAN.md` Q1)." |
| docs/ENDGAME.md :47, Q1 | Adds: "Since SP, after its 100th turn (`SPEEDUP_PLAN.md` Q1)." |
| docs/ENDGAME.md :112, §5.6 | Adds: "Since SP, the Village from 16, the Meadows from 24, Rural from 42 and the City from 66, and `home` after 100 (`SPEEDUP_PLAN.md` Q2)." |
| docs/ENDGAME.md :120, §5.8 | Adds: "Since SP, the Coast starts at turn 100 (`SPEEDUP_PLAN.md` Q1)." |
| docs/ENDGAME.md :162, P1 | Adds: "Since SP, seeds 0–9: at the pier after 3.8–4.1 minutes, and home after 3.8–4.4 (`SPEEDUP_PLAN.md` E1)." |
| docs/ENDGAME.md :170, §8 | Adds: "Since SP, about four minutes, and at most five on every seed measured (`SPEEDUP_PLAN.md` E1, Q15)." |
| docs/DAYNIGHT.md :40, Q3 | Adds: "Since SP, 60 s in Rural, the Meadows and the Desert (`SPEEDUP_PLAN.md` Q5)." |
| docs/DAYNIGHT.md :99, §5.8 | Adds: "Since SP, Rural, the Meadows and the Desert turn a day in 60 s, so each of their zones, about a minute long, reaches its night, 32.5 s in (`SPEEDUP_PLAN.md` Q5)." |
| docs/ROADGEN.md :90, after §5.5's table | Adds: "Since SP, the straights are longer from the Meadows on: the Meadows' 6–12, the Village's 4–8 and the Desert's 6–12. The Desert's decoys fall to 0.15 and its side roads rise to 0.3, so that a Desert zone's junctions, and its time, vary less (`SPEEDUP_PLAN.md` Q3, Q14, U13)." |

Unchanged, as history or still true: `plan.md`:154, the default day; docs/ENDGAME.md W6 (:25), which tells of 280 turns, and :140; docs/DAYNIGHT.md :69, :137 (N39) and :152; docs/ROADGEN.md :78, whose K1 check builds its own schedules; and IP's M4.2 (:147), which tells what M4 built. PR 2 changes the owner's paths and IP (§4).

---

## 6. Verification

### 6.1 Checks and counts

The checks are `AGENTS.md` §3's five: the import, `check_scripts.sh`, `lint.sh`, GUT and `smoke.sh`. They ran locally with Godot 4.7.2 on `main` and on each of the prototype's commits but a130c54, whose game 9229f94 keeps, and in CI on 339b126 and 9229f94, in runs 44739054576 and 44755193873, started by hand with `upload-builds`, whose `lint`, `test`, `export-web` and `export-android` jobs passed. `main`'s CI counts are its push's run, 44718978187:

| State | Where | Scripts loaded | Test scripts | Tests | Asserts | GUT time | Smoke |
|---|---|---|---|---|---|---|---|
| `main` (ec6f54d) | Local | 221 | 103 | 903 | 456,541 | 141.7 s | `autopilot: tile 165, turns 35, area rural` |
| `main` (ec6f54d) | Run 44718978187 | 221 | 103 | 903 | 456,541 | 135.4 s | The same |
| 529378c | Local | 221 | 103 | 904 | 545,822 | 143.5 s | The same |
| 6740ac4 | Local | 221 | 103 | 904 | 545,822 | 144.1 s | The same |
| 339b126 | Local | 221 | 103 | 904 | 545,822 | 145.1 s | The same |
| 339b126 | Run 44739054576 | 221 | 103 | 904 | 545,822 | 149.9 s | The same |
| 9229f94 | Local | 221 | 103 | 904 | 516,682 | 143.4 s | The same |
| 9229f94 | Run 44755193873 | 221 | 103 | 904 | 516,682 | 188.1 s | The same |

`lint.sh` found no problem, and would leave each of the 221 files as it is. `smoke.sh` printed no error line, and `git status --porcelain` printed nothing after the checks. GUT reported 3 warnings at 529378c, which 6740ac4 fixes (§4.3), and none at 6740ac4, 339b126 or 9229f94.

CI's `test` job took 3 min 48 s at 339b126 and 4 min 12 s at 9229f94, against 3 min 22 s on `main`'s push, but CI's runners vary more than SP does: on `main`'s code, which only docs have changed since ec6f54d, GUT took 134.3 s and the job 3 min 15 s in its push's run 44744015047, and 192.9 s and 4 min 35 s in #115's run 44726910992. So the local runs, on one machine, are the ones to compare: GUT took 143.4 s at 9229f94, 1.7 s more than on `main`. In their JUnit reports, the scripts that drive or lay `endless()` to turn 300, which runs longer from turn 58, took longer: `test_autopilot_300_turns.gd` 2.0 s more (P8) and `test_road_generator_occupancy.gd` 2.4 s more, while `test_drive_to_the_end.gd`, which drives 22 roads of 100 turns where `main`'s drove 10 of 280, took 0.6 s less.

### 6.2 Negative cases

Each case makes one change to the prototype, runs the whole suite with `run_tests.sh`, and checks that it exits 1 and fails the tests it names; then `git checkout` restores the files. N1–N8 ran on 6740ac4 and again on 339b126, and all eleven on 9229f94, the prototype's head, whose results these are. Each of N1–N8 failed the same tests at all three, N6 on other seeds once a130c54 had changed the Desert. N7 ran on `test_area_schedule.gd` alone, with `-gselect`, as the whole suite then runs out of memory.

| N# | Change | Fail |
|---|---|---|
| N1 | `schedule.tres` and `schedule_home.tres` as on `main`: the areas at turns 34, 100, 200 and 220, home's at 60, 80, 180 and 246, and both roads ending after turn 280, with SP's straights and days | 21 tests: nine of `test_area_schedule.gd`'s, each that names a switch, a pit stop or a finish's turn; both drives of `test_drive_to_the_end.gd`, which reach their cap, "[600.0] expected to be <= than [300.0]"; one each of `test_area_start.gd`, `test_hitchhiker_run.gd`, `test_area_order.gd`, `test_set_pieces_on_the_road.gd` and `test_tutorial_run.gd`; `test_hud.gd`'s two strip tests; the digests; and `test_road_generator_finish.gd`'s two |
| N2 | `meadows.tres`: straights of 3–7 tiles, as on `main` | 2: `test_from_the_meadows_on_the_straights_are_longer_than_rurals`, "[3] expected to be > than [3]: meadows's shortest straight", and `test_the_game_road_matches_its_digests` |
| N3 | `rural.tres`, `meadows.tres` and `desert.tres` without `day_seconds`: 120 s days, as on `main` | 2: both drives, in `_check_night()`, where 60 of the 66 zones end before their night: 22 of Rural's, 17 of the Meadows' and 21 of the Desert's, such as "[64.2833333333333] expected to be > than [65.0]: pier seed 6: meadows's night" |
| N4 | `hud.tscn`: the strip's anchors at 0.1 and 0.9, 80% of the HUD's height | 2: `test_hud.gd`'s strip tests: "[6] expected to be <= than [4]: 640 pixels high: half the car's mark", and the strip's pixels, such as "[200] expected to equal [100]: at the finish" |
| N5 | `village.tres`: no straights of its own, so the defaults' 2–5, as on `main` | 2: E2's test, "[2] expected to be > than [3]: village's shortest straight", and the digests |
| N6 | `desert.tres`: straights of 3–8 tiles, as on `main` | 3: `test_the_autopilot_drives_to_the_pier`, where three Desert zones now end before their night, such as "[28.6666666666667] expected to be > than [32.5]: pier seed 1: desert's night"; E2's test, "[3] expected to be > than [3]: desert's shortest straight"; and the digests |
| N7 | `rural.tres`: `day_seconds = 55.0`, under `least_day_seconds()`, 55.68 s | 9 of `test_area_schedule.gd`'s 24: each schedule with Rural is invalid, "AreaSchedule: rural: day_seconds is below 55.69", rounded up (`area_def.gd`:109), and the generator lays its fallback road. The whole suite ran out of memory: `test_road_generator_tutorial.gd`:41, unchanged from `main`, looks for a set piece on the fallback road, which lays none, until the kernel killed Godot at 6.6 GB after 133 s (§9) |
| N8 | `schedule_home.tres` as on `main`: the Village at 60, the Meadows at 80, Rural at 180 and the City at 246, and home after 280 | 6: `test_the_autopilot_drives_the_road_home`, whose eleven runs reach their cap in Rural, at turns 190–217, "[600.0] expected to be <= than [300.0]: home seed 3879: the time to the end"; `test_the_games_pit_stops`; `test_the_road_home_is_valid_and_runs_the_other_way`; `test_the_route_strip_shows_only_on_a_road_with_a_finish`; `test_the_road_home_ends_at_home_after_100_turns`; and `test_hitchhiker_run.gd`'s `test_a_departure_that_starts_before_her_turn_has_her_too` |
| N9 | `test_drive_to_the_end.gd`: `MOST_SECONDS` at 270, not 300 | 2: both drives, each on its slowest seed's time alone, "[272.733333333333] expected to be <= than [270.0]: pier seed 2823: the time to the end", and home seed 3879's 278.67 s. 516,680 of the 516,682 asserts pass: each car arrives, without damage |
| N10 | `test_drive_to_the_end.gd`: after `_damage` is reset, each drive's car takes a second's damage off the road, `sim._drive_off_road(1.0, sim.area)` | 2: both drives, "[1] expected to equal [0]: pier seed 0: no damage", and the same on each of the 22 drives; 516,660 of the 516,682 asserts pass |
| N11 | `desert.tres` as at 339b126: straights of 6–14 tiles, decoys at 0.2 and side roads at 0.25 | 2: `test_the_autopilot_drives_the_road_home`, "[301.6] expected to be <= than [300.0]: home seed 3879: the time to the end", and the digests; 545,839 of the 545,842 asserts pass |

U6's count ran the same way, on `main` with 339b126's two schedules: 23 of its 903 tests failed.

### 6.3 Editor warnings

As docs/agents/checks.md §1 says, a temporary `override.cfg` raised the warnings at level 1 to errors, and `check_scripts.sh` loaded every script, on `main` (ec6f54d), 339b126 and 9229f94. The three logs are the same, with only `main`'s five: `INTEGER_DIVISION` in `world/greybox_atlas.gd`:141, with which `world_renderer.gd` and `setpieces/pier.gd`, which depend on it, fail; in `ui/main.gd`:101, `test_greybox_atlas.gd`:15 and `test_iso.gd`:42; and `UNUSED_VARIABLE` `junctions` in `test_road_generator_occupancy.gd`:30. Godot reports only a script's first error, so the check ran again without `integer_division`: only `junctions` was left, on each. None of the 15 scripts that SP changes, `route_strip.gd` and §5.7's 14 test files, is among them, so none has a warning.

### 6.4 Verified only in CI or on devices

- **CI.** PR 1's four required checks, and its `test` job's time (§6.1). This plan's PR changes only this file.
- **Nothing for the Web or Android alone.** PR 1 changes the areas' data, a comment and tests: no node, no `Polygon2D`, no input, and no text but numbers, which the font has. Its CI builds the Web and the APK as `main`'s does, so this plan asks for no Web check, and the run on the Fold4 is optional (Q13).
- **E8, done on the prototype, in a desktop run** (docs/agents/checks.md §2). Movie Maker's frames of the autopilot at 9229f94, seed 1, from Rural, from the Meadows, from the Desert, and the whole road from the City:
  ```bash
  XDG_DATA_HOME=/tmp/sp/movie/data xvfb-run -a -s "-screen 0 1280x1024x24" godot --path . \
    --write-movie /tmp/sp/movie/f.png --fixed-fps 60 --quit-after 3900 -- --autopilot --seed=1 --area=rural
  ```
  and the same with `--quit-after 4500` and `--area=meadows`, with `--quit-after 4800` and `--area=desert`, and with `--quit-after 14100` and no area. Then the mean luminance of each frame, out of 255, and a sheet of frames from each run:
  - **From Rural**, 65 s: the day to 25 s; the dusk, orange at 29 s, from 146 to 73 in 25.5–32.5 s; the night from 32.5 s, at about 65–73, on Rural's last straights and on the bridge at 47–49.5 s; then the Meadows' banner at 51 s, as their morning fades in from 66 to 132 in 50.0–52.5 s; and the Meadows by day at 56 s.
  - **From the Meadows**, 75 s: the day to 25 s; the dusk, from 130 to 65 in 25.5–32.5 s; the night from 32.5 s, at about 65–67, on the Meadows' last straights and among the Village's first houses; then the Village's banner at 55 s, as its morning fades in from 67 to 137 in 54.0–56.5 s; and the Village by day at 57 s.
  - **From the Desert**, 80 s: the day to 25 s; the dusk, from 180 to 88 in 25.25–32.5 s; the night from 32.5 s, at about 88–91; the Coast's banner at 43 s, as its morning fades in from 92 to 193 in 41.5–44.25 s; the lighthouse at 44.5 s; the pier from 46 s, where the mean falls from 193 to 72 in 45.0–48.5 s, as the sea fills the view and EG's sunset darkens it; and the end screen at 51.6 s: "Turns: 16", "Time: 0:46" and "Next: reach the sea. Your best: turn 0 of 100", as a run from a later area keeps no overall best (docs/ENDGAME.md §5.11).
  - **The whole road**, 235 s, each area's banner at its first turn: the City by day, and in its dusk, orange, as its zone ends at 55.7 s (§5.3); Rural at turn 34, its dusk at 82–88 s and its night to 106 s; the Meadows at turn 58, their dusk at 132–138 s and their night to 159 s; the Village at turn 76, by day; the Desert at turn 84, its dusk at 209–214 s and its night to 221 s; the Coast's morning at turn 100; the pier from 225 s; and the end screen at 230.1 s, 5 s after the arrival: "Turns: 100", "Area reached: Coast" and "Time: 3:45", where P1 measured 225.13 s for pier seed 1, with the Death Worm as the book's new legend and "Next: drive the Road Home". Its log had no `ERROR` line.
  - **The light, frame by frame**, on the whole road: each frame's luminance, from the means of its red, green and blue with BT.601's weights. No run of 1 to 30 frames was brighter or darker than both frames around it by more than 0.24, out of 255: 0.23 by day, at 38.03 s in the City; 0.24 in the dusks, at 208.07 s as the Desert's begins; 0.20 in the mornings' fades; and 0.08 at night. Rounding each pixel's luminance first, as an earlier count did, gave up to 0.72 in the dusks, where the tint steps one level of one channel at a time: in frames 1770–1773 from the Meadows, 70% of the view, one grass, went from (100, 120, 45) to (100, 120, 46) and then (99, 119, 46), whose luminance, 105.47, 105.58 and 104.70, rounds to 105, 106 and 105. A frame's mean moves with the view as well as the light, and can hide a change in one part of the view or in one colour, so the movies are evidence of how the road looks, not of the light's rate. That rate is asserted each frame by `test_daylight_run.gd`:129, as a zone's morning takes over from the night, and by `test_arrival_scene.gd`:78–82, at the sunset.
  - In each sheet, the strip's car climbed with the HUD's turns: from Rural's tick past the Meadows', at turn 58; from the Meadows' past the Village's, to the Desert's; from the Desert's to the strip's top, where it stood from the Coast on; and on the whole road, from the bottom to the top.

  PR 1 runs them again only if `main` has changed the light, the areas or the HUD since ec6f54d (§4.1 step 2).
- **The Fold4, optional, by the owner, before landing PR 1** (Q13). The debug APK of run 44755193873, its artifact `android-Android APK`, kept until 2026-11-21 14:37 UTC, serves PR 1 as long as `git diff --name-only 9229f94 <PR 1's head> -- . ':!tests' ':!addons/gut' ':!*.md'` prints nothing (docs/agents/checks.md §4); otherwise `gh workflow run ci.yml -R pompomon/roadgame --ref sp/1-road -f upload-builds=true`. A phone takes no arguments, so play by hand, with Play or the title's Start, which in a debug build chooses any area (docs/ZONE_SELECT.md Z1). On both screens: the nights of Rural, the Meadows and the Desert, and the fades into each next morning; the Village's 21 s; the Desert's long straights; the strip's car, climbing evenly; and the end screen's time at the pier, which the autopilot reaches in about four minutes from the City.

### 6.5 Measurements

The probes ran headless with Godot 4.7.2, at 60 steps a second, as GUT scripts that aren't committed; P2 is a Python model. P1, P3, P4, P6, P8 and P9 ran on a130c54's game, which 9229f94 doesn't change, and P1's zone times match N3's messages at 9229f94 to the step, such as pier seed 6's Meadows, 64.28 s. P10 ran on 339b126's game, P5 on `main`'s, and P7 on both `main`'s and a130c54's.

| P# | What | Result | Used by |
|---|---|---|---|
| P1 | The autopilot drives each road to its end, without the tutorial, seeds 0–4999: each area's time, path tiles and top speed | All 10,000 arrive, with full health at the end and no junction dropped. To the pier: 209.2–272.7 s, 237.3 on average, a standard deviation of 9.05, p95 253.0 and p99 261.3, with 4 runs over 270 s. Home: 208.1–278.7 s, 237.3, 9.39, 253.3 and 261.5, with 5 over 270 s. 700–941 path tiles to the pier, and a top speed of 5.33–5.82 tiles/s at the end. Each area's times in §5.1, its speeds in §5.2. Seeds 0–9, E1's: 225.1–243.8 s to the pier and 225.3–261.2 s home; the slowest, pier seed 2823 at 272.7 s and home seed 3879 at 278.7 s, which E1 drives too | Q1–Q3, Q14, E1, U1, U3, U4, U13 |
| P2 | §5.2's model of a run: roads drawn as the generator draws them, with the speed moved toward `target_speed()` at 60 Hz along each straight, as `_update_speed()` does; 2,000 runs a case, and 50,000 and a million for the slowest | §5.2's table: SP 240 s on average to the pier and 241 s home, 1.1% and 1.7% slower than P1; twice `main`'s straights, 253 s and 256 s. On 50,000 runs a road, twice `main`'s straights put 7 home past 300 s. On a million runs a road, SP's slowest took 298.4 s to the pier and 296.8 s home, none over 300 s, and its shortest Desert zone 33.82 s. The Road Home with the Desert's 60 turns first (Q2): those take 184.8 s, and the road 371.1 s; with only the City's 34 after them, 245.7 s on average and a p99 of 269.9 s. Since the internal review, each road ends with its last area's straight, as the generator's do: the Road Home with the City's, where it had ended with the Coast's | Q2, Q3, Q14, Q15, §8 |
| P3 | P1's 30,000 zones of Rural, the Meadows and the Desert: how many last into their night, with days of 120, 90, 80 and 60 s | 4.1%, 68.9%, 94.7% and 100% (§5.3). At 60 s, the shortest, a Desert zone of 34.25 s, has 1.75 s of night | Q5, E3, U2 |
| P4 | The same zones: the light as each ends, with 60 s days | §5.3's table: 19.2–89.9% end at night, by area and road. 12.3% last into a second morning, and none into a second night | U10 |
| P5 | `main` (ec6f54d): the autopilot drives each road to its end, seeds 0–19 | 562.2–613.3 s to the pier and 561.4–614.0 s home; each area's time (§5.1) and speeds (§5.2); 39 of the 120 zones of Rural, the Meadows and the Desert end at night | U1, U4, U10 |
| P6 | P1 with `TOP_SPEED_GROWTH` at 0.0035 a tile, seeds 0–199 | 3.5 s quicker to the pier, 233.6 s on average, and 2.6 s home, 234.6 s, against P1 on the same seeds; the slowest, 266.0 s and 265.3 s; the Desert's mean top speed 6.57 tiles/s, against 5.50 | Q4, U4 |
| P7 | Both roads, laid on `main` and on the prototype for seeds 0–199, each digested with its dead ends up to the junctions of turns 16, 24, 34, 42, 58 and 66 | To the pier, the same on all 200 seeds up to turn 58, and on none at 66. Home, the same on none, from turn 16 | E4, §5.6 |
| P8 | `test_autopilot_300_turns.gd`'s drives, on `main` and the prototype | 300 turns of `endless()` take 762.4–816.3 s of game time, 798.0 on average, against 607.5–656.2 s on `main` and 831.4–920.2 s at 339b126; its drive with every kind of junction 476.2–495.8 s on each | §4.3, §5.6, Q11, U11 |
| P9 | A first run: the autopilot through the tutorial, then to the pier, seeds 0–99 | The tutorial ends at 17.9–22.8 s, and the car arrives at 236.2–280.4 s, each with full health | Q10, §5.6 |
| P10 | P1 at 339b126, whose Desert had straights of 6–14 tiles, decoys at 0.2 and side roads at 0.25, seeds 0–4999 | To the pier: 215.3–290.6 s, 244.1 on average, a standard deviation of 10.08. Home: 212.8–301.6 s, 244.7, 10.53. Home seed 3879 took 301.6 s, the only run over 300 s: its Desert zone had 15 decoys among its 31 junctions and took 95.0 s | U13, Q14 |

---

## 7. Owner actions

| When | Action | How |
|---|---|---|
| Now | Answer Q1–Q15 on this plan's PR, or merge it to take their defaults | A PR comment with each Q# to change and its answer. An answer that changes a default changes PR 1, and the probes that it names run again (§3) |
| Now, if wanted | Play the prototype | Run 44755193873's builds, kept until 2026-11-21 14:37 UTC, or a new run's: `gh workflow run ci.yml -R pompomon/roadgame --ref sp/prototype -f upload-builds=true`. Then docs/agents/checks.md §4's download, the APK, or the Web build patched, with `?arg=--autopilot` for the whole road, `&arg=--home` for the Road Home |
| After PR 1's reviews | The Fold4's optional run (§6.4), then land PR 1 | Squash it, as the plan's last code PR (§4.2) |
| After PR 1 | Land PR 2, the docs and SP's learnings | Review the guidelines that it changes (planning.md §7), then squash it |
| After PR 2 | Tag the prototype, which this plan cites, and delete SP's branches, which GitHub doesn't delete on merge | `git fetch origin sp/prototype && git push origin FETCH_HEAD:refs/tags/archive/sp/prototype`, then `git push origin --delete sp/plan sp/prototype sp/1-road sp/2-docs` |

---

## 8. Risks

| Risk | Impact | Mitigation |
|---|---|---|
| The bound is measured, not proven | The slowest of P1's 10,000 runs took 278.7 s, 21.3 s inside the bound, but a zone's decoys have no limit (U13): §5.2's model put the slowest of a million runs a road at 298.4 s to the pier and 296.8 s home, but it isn't checked against the game past P1's one run in a thousand, so a seed over 300 s may exist. E1's test drives 10 seeds a road and each road's slowest of P1. A later change to the car, the autopilot, the generator or an area could push rare seeds past 300 s, which no test would show but on those seeds | E1's seeds take 225.1–261.2 s, and P1's slowest 272.7 s and 278.7 s. §4.1 step 2 runs P1 again if `main` has moved; so should a later change that slows the car. The finish's turn, the straights and the decoys are numbers in the `.tres` files (Q1, Q3, Q14). Q15 asks the owner whether a measured bound is enough |
| A player is slower than the autopilot | A player only steers (`input_router.gd`:3–16): the car sets its own speed, and a wrong exit ends the run with a legend. So a player who arrives drove their seed's road at about the autopilot's speed, but for the time their car spent off the road, where it slows to its area's `offroad_speed_mult`, 0.45–0.6 (`car_sim.gd`:257–258). On the slowest seeds, which take the autopilot over 270 s, a few seconds off the road take a player past five minutes | The bound is the autopilot's, as the owner asked (Q10). Off the road, the car loses 25–35 health a second, so its health and the three pit stops' repairs keep a run that arrives off the road for at most 10 s |
| The end comes sooner | At 1% errors a junction, about 33% of runs would reach the end, where about 4% did (U9), so its unlocks come sooner | An arrival unlocks one legend (docs/ENDGAME.md §5.5). The finish's turn is one number in `schedule.tres` (Q1), and the pit stops could be fewer (Q8) |
| The Village is short | 8 turns and 21 s: its legends meet fewer junctions | Q9's alternative, 10 turns |
| The Desert's night comes late in its shortest zones | The shortest of P1's Desert zones to the sea took 34.25 s, 1.75 s into its night (§5.3); of the model's million, 33.82 s, and none under 33.5 s. A shorter zone would end before its night | E3's test checks each zone of its 22 drives. Q14's alternative, the Desert's straights at 6–14, makes its shortest zones 1.4–1.6 s longer (§5.2) |
| The light changes faster | A 60 s day's steepest change uses 92.8% of `LIGHT_MAX_RATE`, and more zones hand over from night to morning (U10); a fade could read as a flash on a phone | `test_daylight_run.gd`:129 asserts the rate of a morning's fade each frame; in the whole road's movie, the view's mean had no pulse of 1 to 30 frames above 0.24 of 255, and 0.23 by day (§6.4); and the Fold4's optional run checks it on the device. Q5's alternative, 80 s, uses 69.6% |
| Old saves | A save from `main`, on Pages, keeps a best time of about ten minutes until its first arrival, and a farthest turn of up to 280 | The goal line, the strip and the Hitchhiker clamp it (§5.5); Q7's alternative, version 6 |
| A first run comes near the bound | With the tutorial, the autopilot arrived at up to 280.4 s (P9) | E1 counts the run without it (Q10) |
| A broken schedule takes the machine's memory | With every schedule invalid, `test_road_generator_tutorial.gd`:41 loops forever on the fallback road (N7), as on `main` | Run such a case on its test script alone (§6.2); §9 notes a bound for the loop |

---

## 9. Notes for later work

- **M7's device QA** (IP §4 M7). A run to the pier now takes about four minutes on the autopilot, so a QA pass can drive both roads, by day and by night, in one sitting. PR 2 moves M7.6's screenshots to turns 0, 34, 58, 76 and 84 (IP :209, :320).
- **A time to beat.** A run's time is its seed's road at the car's own speeds, plus its time off the road (§8), so a best time rewards a quick seed as much as a clean run: the autopilot's seeds alone spread over 208.1–278.7 s (P1). A par for a player to beat, as docs/ENDGAME.md §9's medals would be for each area's time, would have to be the autopilot's time on the same seed, not one number for the road.
- **Version 6** (Q7), if old records confuse players on Pages: a migration that clamps each road's farthest turn to its end, and drops the best times over five minutes.
- **The top speed** (Q4, P6). If the Desert feels slow on the Fold4, `TOP_SPEED_GROWTH` at 0.0035 a tile, which changes every road's feel.
- **Keep Driving's road** (Q11) is the Desert forever from turn 84. If an endless run should cross more areas, it could have an endless schedule of its own, such as `main`'s.
- **Bound the tutorial test's loop.** `test_road_generator_tutorial.gd`:41 loops until it meets a set piece, which the fallback road never lays (N7). A cap on its tiles would turn a broken schedule's out-of-memory into a failure. It's on `main`, so this plan leaves it alone.
