# The Speedup: the Road to the Sea in Five Minutes — Detailed Plan

Status: proposed. Merging its PR approves it with Q1–Q13's defaults (§3), unless the owner answers otherwise there · 2026-11-20 · Scope: a run to the end of either road takes at most five minutes on the autopilot, not ten. Both roads end after their 100th turn, not their 280th: the City keeps its 34 turns, each area after it has fewer, and from the Meadows on, the straights are about twice as long. Rural, the Meadows and the Desert turn a day in 60 s, so that each still shows its night. This plan calls the work SP. It builds on EG, which has landed, and comes before M7.

The owner asked: "Explore the codebase and create a detailed implementation plan for game speedup. Adjust the number of turns required after the first zone, so the end time on autopilot is 5 minutes at most. Also adjust the Meadows zone and beyond to have less turns and longer straight roads. Ask clarifying questions if needed". The clarifying questions are §3's Q1–Q13. This plan was written in autopilot mode, which decides rather than waits, so each question has a default, which the plan and its prototype follow, and the alternatives that the owner can choose instead on the plan's PR. Those with the most at stake are Q1, the turns; Q2, the Road Home, whose first zone is the Desert; Q3, the straights; and Q5, the days.

**What happens.** Today the autopilot takes about ten minutes to the end of either road: 562.2–613.3 s to the pier and 561.4–614.0 s home, on seeds 0–19 (P5; docs/ENDGAME.md P1). The road ends after its 280th turn (`schedule.tres`:52), and 246 of its turns come after the City's 34: Rural's 66, the Meadows' 100, the Village's 20 and the Desert's 60. The Meadows alone take 217 s. With SP, the areas switch at turns 34, 58, 76 and 84, and the road ends after its 100th (Q1): Rural has 24 turns, the Meadows 18, the Village 8 and the Desert 16. The Meadows' straights become 6–12 tiles, from 3–7, the Village's 4–8, from 2–5, and the Desert's 6–14, from 3–8 (Q3), so those areas turn less and run straighter, as the owner asked: 2.6–3.4 s a turn, against Rural's 2.1. Each long area takes about a minute, the City 58 s, Rural 51 s, the Meadows 57 s and the Desert 54 s, and the Village is a 21 s interlude. On 1,000 seeds of each road, the autopilot arrived in 216.1–280.5 s, 244 s on average, with full health (P1). The Road Home stays the road's mirror, with the same turns in reverse (Q2).

Shorter zones need shorter days. With 120 s days, the night comes 65 s into a zone (docs/DAYNIGHT.md §5.8), and only 6.6% of the new zones would reach it (P3): runs would lose the nights that DN added. So Rural, the Meadows and the Desert turn a day in 60 s, whose night comes 32.5 s into a zone, and each of the 6,000 such zones of P1's runs reached it (Q5). The City, the Village and the Coast keep 120 s.

The rest stays (Q8). The route strip keeps its 40% of the HUD's height, and its car now climbs 2.56–3.69 pixels a turn, not about one (Q6, §5.4). Saves stay at version 5 (Q7). The City, the car, the legends and the pit stops don't change. PR 1 makes the change, and PR 2 replaces this plan with `docs/SPEEDUP.md` (§4).

**Verified locally.** The change was first built on branch `sp/prototype`, from `main` at ec6f54d, which never gets a PR of its own (§4.1). Its three commits, 529378c, 6740ac4 and 339b126, change 6 area files, a comment in `route_strip.gd` and 14 test files: 21 files, +162 −118. 339b126 passed the five checks locally with Godot 4.7.2 (§6.1), and the warnings check (§6.3), and each of the 8 negative cases failed the tests it names: seven against the whole suite, and N7, which breaks every schedule, against `test_area_schedule.gd` alone, as the whole suite then runs out of memory (§6.2). CI run 44739054576 passed on 339b126 (§6.1). Probes in Godot drove both roads to their ends on 1,000 seeds each, measured the nights, the speeds and the light, and compared the road with `main`'s on 200 seeds (§6.5). REVIEW_TBD

- Godot 4.7.2-stable (4.7.2.stable.official.ed1daf0bf), as in CI
- GUT 9.7.1
- gdtoolkit 4.5.0 on Python 3.12, as in CI's `lint` job. shellcheck isn't installed locally, so `lint.sh` skipped it there; SP changes no shell script

**Precedence.** For SP, this document replaces `plan.md`'s vision (:13), §3.6 (:122–125), §5.5 (:229), §9 (:356), §11 (:390) and §13 (:429); docs/ENDGAME.md's header (:3), E6 (:11), Q1 (:47), §5.6 (:112), §5.8 (:120), P1 (:162) and §8 (:170); docs/DAYNIGHT.md Q3 (:40) and §5.8 (:99); and docs/ROADGEN.md §5.5's straights (:82–88), wherever it marks a difference with **Δ** and its finding (U#, §2). PR 1 folds them into those files (§5.8, Q12).

**Reference code.** PR 1 is the difference between ec6f54d and 339b126, the head of `sp/prototype`, with §5.8's Δs to the docs (§4.1).

**Prerequisites.** EG has landed, with its docs (#101–#114), so `main`, at ec6f54d, has the road's end, the Road Home, the route strip, the pit stops and the records that SP retunes. The owner's #115, EG's learnings for agents, is open: it changes `AGENTS.md`, `docs/README.md`, docs/agents/ and `.github/instructions/`, but no file of PR 1's, and PR 2 follows its planning.md §7 if it has merged by then (§4.2). M7 hasn't started; §9 has notes for it. No repository settings change.

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

Goal: a whole road in one sitting. The autopilot drives either road to its end in at most five minutes, and a player who knows the way takes about as long. The City stays as it is, the areas after it have fewer turns, and from the Meadows on, the road runs straighter. Each area keeps its character and its legends, and each long area past the City still shows its night.

| # | Exit criterion | Checked by |
|---|---|---|
| E1 | Five minutes (U1, U3; Q1, Q10). Both of the game's roads end after their 100th turn. The autopilot drives each to its end on each of 10 seeds, with no disaster, crash or damage and no junction dropped, in at most `MOST_SECONDS`, 300 s, of game time: the run's clock, which the end screen shows. The end screen comes `ARRIVAL_SECONDS`, 5 s, after the arrival | `tests/sim/test_drive_to_the_end.gd`: `test_the_autopilot_drives_to_the_pier`, `test_the_autopilot_drives_the_road_home`; `test_area_schedule.gd`: `test_the_games_road_ends_at_the_pier_after_its_100th_turn`; `test_road_generator_finish.gd`: `test_the_road_home_ends_at_home_after_100_turns`; P1, on 1,000 seeds a road: 216.1–280.5 s |
| E2 | Fewer turns and longer straights after the City (U1; Q1, Q3, Q9). The City keeps its 34 turns. The areas switch at turns 34, 58, 76 and 84, and the Coast starts at 100: Rural has 24 turns, the Meadows 18, the Village 8 and the Desert 16. The tunnel, the bridge and Last Gas still lead into Rural, the Meadows and the Desert, with the same pit stops. From the Meadows on, each area's shortest and longest straights are longer than Rural's, 3 and 7 tiles: the Meadows' 6–12, the Village's 4–8 and the Desert's 6–14. The City and Rural keep theirs | `test_area_schedule.gd`: `test_from_the_meadows_on_the_straights_are_longer_than_rurals`, `test_areas_and_set_pieces_switch_at_34_58_76_and_84`, `test_the_game_schedule_is_valid`, `test_the_games_pit_stops`; `test_area_order.gd`, `test_tutorial_run.gd` and `test_set_pieces_on_the_road.gd`, which drive the road through each switch; `test_area_start.gd` |
| E3 | Each long zone shows its night (U2; Q5). Rural, the Meadows and the Desert turn a day in 60 s, so the night comes 32.5 s after the car enters one of their zones, and each such zone that the car leaves lasted into its night. 60 s is above the shortest day whose light changes within `LIGHT_MAX_RATE`, 55.68 s, which `validate()` checks. The City, the Village and the Coast keep 120 s | `test_drive_to_the_end.gd`'s two tests, through `_check_night()`, on each zone of `NIGHT_AREAS`; `test_area_schedule.gd`: `test_the_game_schedule_is_valid`, `test_the_road_home_is_valid_and_runs_the_other_way`; P3 |
| E4 | Nothing else changes (U6, U7; Q8). The City, the tunnel, the car, the autopilot, the legends, the pit stops' rule, the light's rules and the save stay as on `main`. Up to and including the junction of its 58th turn, the game's road is `main`'s, tile for tile, with its dead ends. Only the golden digests of `endless()`, which lays the Meadows and the Desert, change, and PR 1's commit says why. `smoke.sh` prints `main`'s line, `autopilot: tile 165, turns 35, area rural` | The tests that PR 1 doesn't change, which pass as on `main`; `test_road_generator_determinism.gd`'s new digests; P7, on seeds 0–199; §6.1's smoke line |
| E5 | The Road Home (Q2). It stays the road's mirror: the Desert from its start, the Village at turn 16, the Meadows at 24, Rural at 42 behind the bridge and the City at 66 behind the tunnel, and home after turn 100, with pit stops where the Village, Rural and the City start | `test_area_schedule.gd`: `test_the_road_home_is_valid_and_runs_the_other_way`, `test_the_games_pit_stops`; `test_drive_to_the_end.gd`: `test_the_autopilot_drives_the_road_home`; `test_hud.gd`: `test_the_route_strip_shows_only_on_a_road_with_a_finish`; `test_hitchhiker_run.gd`: `test_a_departure_that_starts_before_her_turn_has_her_too`; `test_road_generator_finish.gd`: `test_the_road_home_ends_at_home_after_100_turns` |
| E6 | The strip and the save (U5, U8; Q6, Q7). The route strip keeps its 40% of the HUD's height, with ticks at turns 0, 34, 58, 76, 84 and 100. On each reference screen, 640, 800 and 922 pixels high, its car climbs evenly, each turn the strip's length over 100 turns, rounded down or up, and never more than half its mark's height. Saves stay at version 5: an older save loads as it is, and the goal line, the strip and the Hitchhiker clamp a farthest turn past 100 | `test_hud.gd`: `test_the_route_strip_marks_each_area_the_car_and_the_best`, and `test_the_route_strip_shows_only_on_a_road_with_a_finish`, whose best is past the finish; `test_game_over.gd`: `test_the_next_goal_follows_the_players_progress`, whose farthest is 50 turns past the road's end; `test_hitchhiker.gd`: `test_her_turn_is_the_players_farthest_on_the_road_home_or_its_finish_once_home`, and `test_save_data.gd`, unchanged |
| E7 | Docs: PR 1's Δs (§5.8), then PR 2's `docs/SPEEDUP.md` (Q12) | Review |
| E8 | Manual: a run of the new road reads well, with its nights, in a desktop run's frames (done on the prototype, §6.4); the owner may play one on the Fold4 before landing PR 1 (Q13) | §6.4 |
| E9 | All four required checks are green on each PR, with §4's counts, and `smoke.sh` prints no error line. Each negative case makes the tests it names fail (§6.2), the warnings check finds only `main`'s five (§6.3), and GUT reports no warning | PR checks; §6.2 and §6.3, run locally with Godot 4.7.2 on PR 1's head |

---

## 2. Review findings

The prototype checked each finding below that has a fix (§6.2).

- **High:** the game misleads the player, or breaks.
- **Medium:** fragile, or missing from the tests.
- **Low:** clarity or polish.

Line numbers are at ec6f54d, `main`, from which the prototype was made, unless they say otherwise.

### High

| # | Finding | Evidence | Fix |
|---|---|---|---|
| U1 | A run to the end takes about ten minutes, most of it after the City. 246 of the road's 280 turns come after the City's 34, and the Meadows' 100 alone take 217 s | `schedule.tres`:18–52: the areas at turns 34, 100, 200 and 220, the Coast at 280, and `finish_turn = 280` (:52); `schedule_home.tres`:17–46, its mirror. P5, seeds 0–19: 562.2–613.3 s to the pier and 561.4–614.0 s home; to the pier, the City took 58 s, Rural 136 s, the Meadows 217 s, the Village 39 s and the Desert 136 s. docs/ENDGAME.md P1 (:162): 9.6–10.2 minutes | **Δ plan.md :13, §3.6, §11, §13; docs/ENDGAME.md Q1, §5.6, §5.8, P1, §8:** the areas switch at turns 34, 58, 76 and 84, and both roads end after turn 100 (Q1, Q2; §5.1). Prototype (E1, E2, N1, N8) |
| U2 | Shorter zones would lose their nights. With 120 s days, the night comes 65 s after the car enters a zone, and SP's Rural, Meadows and Desert zones last 39–89 s: only 6.6% of them would reach it, while each of `main`'s did | `area_def.gd`:71, `day_seconds := 120.0`, which no area sets; `tuning.gd`:247 and :251: a zone's clock starts at 07:00, and the night at 20:00, 13/24 of a day later; docs/DAYNIGHT.md §5.8 (:99). P3 | **Δ plan.md §5.5; docs/DAYNIGHT.md Q3, §5.8:** Rural, the Meadows and the Desert turn a day in 60 s (Q5; §5.3). Prototype (E3, N3, N7) |

### Medium

| # | Finding | Evidence | Fix |
|---|---|---|---|
| U3 | No test bounds a run's time, and the times spread: the slowest of P1's 2,000 runs took 280.5 s, 64.4 s more than the quickest | `test_drive_to_the_end.gd`:9–12: five seeds a road, "about 9 minutes", and a cap of 20 minutes, which only stops a car that never arrives; no assert reads the time | `MOST_SECONDS`, 300 s, asserted on 10 seeds a road, with the cap at twice that (E1); P1 on 1,000 seeds a road (§6.5). Prototype (E1, N1) |
| U4 | The car's top speed grows with the distance it has driven in the run, so a shorter road ends slower: at the pier the cap is 5.38–5.90 tiles/s, where on `main` it was 7.0 | `car_sim.gd`:250–253: `minf(GLOBAL_SPEED_CAP, BASE_TOP_SPEED + dist_total * TOP_SPEED_GROWTH)`; `tuning.gd`:65–68: 4.0, 0.002 a tile and 7.0, reached after 1,500 tiles. P1: 726–984 path tiles to the pier, and the Desert's top speed 5.57 tiles/s on average, against 5.79 on `main` (P5) | None by default: the time comes from the turns and the straights, and a growth of 0.0035 saves 4 s on average (P6; Q4, §5.2) |
| U5 | The strip's test expects a pixel or so a turn | `test_hud.gd`:268–272: each turn's climb 0–2 pixels; `route_strip.gd`:7, "a pixel or so a turn". The strip is 40% of the HUD's height (`hud.tscn`:66–68), 256–369 pixels on the reference screens, so 100 turns climb 2.56–3.69 pixels each | The strip stays (Q6). The test checks that the car climbs evenly, the strip's length over 100 turns rounded down or up, and at most half its mark, 4 pixels; the comment says "a few pixels a turn" (§5.4). Prototype (E6, N4) |
| U6 | Twelve test files hold the old road's turns, times or digests: on `main`, the new schedules alone fail 23 of its 903 tests | ec6f54d with 339b126's `schedule.tres` and `schedule_home.tres`: `test_area_schedule.gd` 9, `test_drive_to_the_end.gd` 2, `test_hud.gd` 2, `test_road_generator_finish.gd` 2, and one each in `test_area_start.gd`, `test_hitchhiker_run.gd`, `test_area_order.gd`, `test_set_pieces_on_the_road.gd`, `test_tutorial_run.gd`, `test_game_over.gd`, `test_prop_scatter.gd` and `test_road_generator_determinism.gd` | The 14 test files of §5.7: those twelve, and two whose comments name the old road. Prototype (E1, E2, E5, N1, N8) |
| U7 | The golden digests change. `PATH_DIGEST` and `ROAD_DIGEST` digest `endless()` on seeds 0–19 to turn 300, which now crosses the Meadows from turn 58 and the Desert from 84, with longer straights | `test_road_generator_determinism.gd`; docs/ROADGEN.md §6.1: a commit that changes the digests says why | New digests, and PR 1's commit body says why. P7: up to the junction of its 58th turn, the road is `main`'s on 200 seeds (E4). Prototype (N2, N5, N6) |
| U8 | A save keeps the old road's records. An arrival on `main` keeps the road's farthest turn, 280, and a best time of about ten minutes, and `main` deploys to Pages | `save_data.gd`:14, version 5; `record_arrival()` (:244–252) keeps the least time (:248) and the farthest turn (:251); `ci.yml`:88–90, the Pages artifact on a push to `main`. Clamped: the goal line (`game_over.gd`:125–127), the strip (`route_strip.gd`:64–68) and the Hitchhiker (`hitchhiker.gd`:54–58). Not clamped: the overall and the Atlas's best turns (`atlas_screen.gd`:60–73) | None by default (Q7): the first arrival on the new road sets a best time under five minutes, and a best turn past 100 is history. Prototype (E6) |

### Low

| # | Finding | Evidence | Fix |
|---|---|---|---|
| U9 | The road's junctions shift to the City: it has 34 of 100, where it had 34 of 280. A run meets the City's legends more often, and arrives more often | §3.6 of `plan.md`; the City's share 12% → 34%, Rural's 24% → 24%, the Meadows' 36% → 18%, the Village's 7% → 8%, the Desert's 21% → 16%. At 1% errors a junction, 37% of runs would arrive, against 6% (0.99^100 and 0.99^280) | None: an arrival unlocks a legend of any area's pool (docs/ENDGAME.md §5.5), and Departures start in any area discovered (§8) |
| U10 | More zones end at night, so the next zone's morning fades in from the night more often | P4: with 60 s days, 21–82% of the zones of Rural, the Meadows and the Desert end at night, by area and road; on `main`, 39 of P5's 120. The fade takes 2.33 s (docs/DAYNIGHT.md Q2) | None: the light changes within `LIGHT_MAX_RATE`, and the movies show no flash (§6.4) |
| U11 | Comments name the old road's times | `test_area_order.gd`:9, `test_autopilot_300_turns.gd`:11, `test_drive_to_the_end.gd`:11, `test_set_pieces_on_the_road.gd`:10 and `test_tutorial_run.gd`:11 give each drive's minutes; `route_strip.gd`:7 | PR 1 updates each, with each drive's cap at about twice its time (§5.7). Prototype |
| U12 | The docs name 280 turns, the old switches and 120 s days | `plan.md`:13, :122–125, :229, :356, :390, :429; docs/ENDGAME.md :3, :11, :47, :112, :120, :162, :170; docs/DAYNIGHT.md :40, :99; docs/ROADGEN.md :82–88; IP :209, :249, :320; `AGENTS.md`:7 | PR 1's Δs (§5.8) and PR 2 (§4) |

---

## 3. Decisions and open questions

Each question has a default, which this plan and the prototype follow until the owner answers on this plan's PR (§7). If the owner merges the PR without answering, the defaults hold, as planning.md §5 says. An answer that changes a default changes PR 1, and the probes of §6.5 that it names are run again.

| # | Question | Default | Alternative |
|---|---|---|---|
| Q1 | How many turns, and where do the areas switch? | **The City keeps its 34 turns. The areas switch at turns 34, 58, 76 and 84, and the road ends after its 100th: Rural has 24 turns, the Meadows 18, the Village 8 and the Desert 16 (§5.1). Each long area takes about a minute, and the slowest of P1's 2,000 runs arrived at 280.5 s, 19.5 s inside the bound** | Another split of the 66 turns after the City, such as more for the Meadows and fewer for Rural; or fewer turns, for a wider margin: each turn after the City takes 2.1–3.6 s on average, by area and road (P1) |
| Q2 | Does the Road Home change as the road does? | **Yes: it stays the road's mirror, with the same turns in reverse. The Desert has 16, the Village 8, the Meadows 18, Rural 24 and the City 34, and home comes after turn 100 (§5.1). P1: home in 219.2–280.5 s** | A split of its own, such as a longer Desert to start: its turns take 3.6 s each there, so keeping `main`'s 60 would bring the run to about 400 s |
| Q3 | How long are the straights from the Meadows on? | **The Meadows 6–12 tiles, from 3–7; the Village 4–8, from the defaults' 2–5; the Desert 6–14, from 3–8 (§5.2). They take 2.6–3.4 s a turn, where Rural's take 2.1. Rural, which "the Meadows zone and beyond" leaves out, keeps 3–7, and the City's 2–5 and the Coast's 20 stay** | Twice `main`'s: the Meadows 6–14, the Village 4–10 and the Desert 6–16. §5.2's model puts the slowest of 2,000 runs at 296 s, or at 289 s with the areas switching at 34, 58, 74 and 82 and the end after turn 98; it puts the default's at 286 s, where P1 measured 280.5 s. Or longer still, with fewer turns |
| Q4 | Does the car reach its top speed sooner? | **No: `TOP_SPEED_GROWTH` stays 0.002 a tile, so the car's cap reaches 5.4–5.9 tiles/s by the pier, not `main`'s 7.0 (U4). The time comes from the turns and the straights** | 0.0035 a tile: 4.0 s quicker to the pier and 2.9 s home on average, and the Desert's top speed 6.71 tiles/s (P6). It changes the car on every road, Keep Driving's too, and each drive's time |
| Q5 | How long are the zones' days? | **60 s in Rural, the Meadows and the Desert, whose zones take about a minute: the night comes 32.5 s into a zone, and each of P1's 6,000 such zones reached it (P3). The City, which ends at dusk, the Village, a 21 s interlude, and the Coast keep 120 s (§5.3)** | 80 s, whose night comes at 43.3 s: 99.0% of the zones reach it, but only 96.6% of the Desert's on the road to the sea; 90 s, 82.0%; or 120 s, as on `main`, 6.6%, so that most runs show no night |
| Q6 | Does the route strip change? | **No: it keeps 40% of the HUD's height, so its car climbs 2.56–3.69 pixels a turn on the reference screens, and its closest ticks, the Village's and the Desert's, are 20.5–29.5 pixels apart (§5.4)** | 20%: 1.28–1.84 pixels a turn, near `main`'s 0.91–1.32, with those two ticks 10.2–14.8 pixels apart, and the car's mark 8 pixels high |
| Q7 | Does the save change? | **No: it stays at version 5. A save from `main` keeps its best time, about ten minutes, until the first arrival on the new road beats it, and a farthest turn of up to 280, which the goal line, the strip and the Hitchhiker clamp to the road's 100 (§5.5)** | Version 6, which clamps each road's farthest turn to its end, and drops the old road's best times |
| Q8 | Does anything else change? | **No: the City, the tunnel, the bridge, Last Gas, the car, the autopilot, the legends and their pools, the pit stops' rule, the tutorial, the light's rules and the music stay as on `main` (§5.6)** | Fewer pit stops, such as none on the bridge: the road from one to the next is 24 or 26 turns, where it was 66 or 120, so a run is easier (§8) |
| Q9 | How long is the Village? | **8 turns, about 21 s: an interlude between the Meadows and the Desert, as on `main`, where its 20 turns took 39 s (§5.1)** | 10 turns, with the Desert at 14 |
| Q10 | What do the five minutes count? | **The run's clock, which the end screen shows, from the start to the arrival, as `--autopilot` drives it, without the tutorial (`AGENTS.md` §2). The end screen comes `ARRIVAL_SECONDS`, 5 s, later: at most 285.5 s into P1's runs. A first run plays the tutorial's 12 turns or more before the City's, from whose end the schedule counts: on seeds 0–99, the autopilot finished the tutorial in 17.9–22.8 s and arrived in 242.9–289.7 s (P9)** | The tutorial's run too: P1's slowest seeds and the tutorial's 20 s or so could pass 300 s, so the road would need about 8 turns fewer |
| Q11 | Do Keep Driving and Departures follow the new road? | **Yes: they read the same schedules. Keep Driving, `endless()`, runs the Desert forever from turn 84, and a Departure starts at its area's new turn, with as many turns fewer to the end (§5.6)** | Keep Driving on `main`'s schedule, a third file, so that its Desert still comes at turn 220 |
| Q12 | Where do the docs change? | **PR 1 folds §5.8's Δs into `plan.md`, docs/ENDGAME.md, docs/DAYNIGHT.md and docs/ROADGEN.md, with their findings. PR 2 adds `docs/SPEEDUP.md`, changes the owner's paths, `AGENTS.md`, `docs/README.md` and IP, and deletes this plan (§4)** | Everything in PR 1, which the owner then lands |
| Q13 | Who lands PR 1? | **The owner, as the last code PR of the plan (`AGENTS.md` §5 step 4), after an optional run on the Fold4: SP changes nothing that only Android or the Fold4 does (§6.4). The owner lands PR 2 too, which changes `AGENTS.md`** | Agents, with `land_pr.sh`, once its reviews are done |

---

## 4. Work breakdown

Two PRs after this plan's (Q12): PR 1 makes the change, and PR 2, the docs, starts from `main` once PR 1 has merged. Each leaves CI green (E9).

```
main
 ──▶ PR 1 the road to the sea in five minutes (E1–E6, E8; U1–U8, U10, U11)
   │
   ▼  once PR 1 has merged, from main
 PR 2 docs (E7; U12)
```

Why so:
- **One code PR.** The turns, the straights, the days and the tests hang together. The schedules alone fail 23 tests (U6). Five minutes need the straights as well as the turns (§5.2), and shorter zones need shorter days, or E3's nights fail (N3). Split, each PR would land a road that the next retunes. PR 1 is small: 21 files, +162 −118, and the docs.
- **The docs from `main` (PR 2)**, with the owner's paths, as EG's PR 14 did (planning.md §3).

### 4.1 Porting from the prototype

PR 1 is the difference between ec6f54d and 339b126, the head of `sp/prototype`, with §5.8's Δs to the docs.

1. Fetch, create PR 1's branch from `main`, and apply the difference. If `main` has moved on since ec6f54d in the prototype's files, `--3way` merges its lines with the prototype's; where both changed the same lines, keep both:
   ```bash
   git fetch origin main '+refs/heads/sp/*:refs/remotes/origin/sp/*'
   git switch -c sp/1-road origin/main
   git diff ec6f54d origin/sp/prototype | git apply --3way --index
   ```
2. If `main` has changed the road, the car, the autopilot, the areas or the light since ec6f54d, which `git diff --stat ec6f54d origin/main -- road car areas config world/day_cycle.gd` shows, run P1 and P3 again, on 1,000 seeds a road, and check the slowest run's margin to E1's bound (§8).
3. Make §5.8's Δs to the docs, which the prototype doesn't have. Leave `SPEEDUP_PLAN.md` alone (§4.2).
4. Run §6.1's checks, §6.2's negative cases and §6.3's warnings, and compare the counts with PR 1's "Expect" line.
5. Have a model of another family review it (`AGENTS.md` §5). Commit as PR 1's title, with a body that says why the golden digests change (docs/ROADGEN.md §6.1, U7) and names the tests and the negative cases. Push, and open the PR with base `main`.

### PR 1: Areas: the road to the sea in five minutes **Δ U1–U8, U10, U11**

Title `areas: the road ends after 100 turns, with longer straights and 60 s days (SP PR 1)`. Branch `sp/1-road`, from `main` (§4.1).

| Area | Files |
|---|---|
| Areas | `areas/schedule.tres`: the areas at turns 34, 58, 76 and 84, and the pier after turn 100 (§5.1). `areas/schedule_home.tres`: its mirror. `areas/meadows.tres` and `areas/desert.tres`: their straights, and `day_seconds = 60.0`. `areas/village.tres`: its straights. `areas/rural.tres`: `day_seconds = 60.0` (§5.2, §5.3) |
| UI | `ui/route_strip.gd`:7: "a few pixels a turn" (§5.4) |
| Tests | The 14 files of §5.7. New: `test_from_the_meadows_on_the_straights_are_longer_than_rurals` (E2). `test_drive_to_the_end.gd`: `MOST_SECONDS` and `_check_night()`, on 10 seeds a road (E1, E3). `test_hud.gd`: the strip's even climb (E6). The rest: the new turns, digests and times |
| Docs | §5.8's Δs to `plan.md`, docs/ENDGAME.md, docs/DAYNIGHT.md and docs/ROADGEN.md (U12) |

21 files, +162 −118, and the docs. Expect, against `main` at ec6f54d: the same 221 scripts loaded and 103 test scripts; 904 tests, one more; 545,822 asserts, 89,281 more, nearly all in `test_road_generator_pattern.gd`, whose tests assert each tile of `endless()`'s road to turn 300, which is longer from turn 58; GUT 145.1 s locally, against 141.7 s; and `autopilot: tile 165, turns 35, area rural`, as on `main`. Negative cases N1–N8.

**Acceptance:** E1–E6, E8, E9.

### PR 2: Docs: `docs/SPEEDUP.md` replaces the plan

Title `SP PR 2: docs/SPEEDUP.md replaces the plan`. Branch `sp/2-docs`, from `main`, once PR 1 has merged (Q12).

| Area | Files |
|---|---|
| Docs | `docs/SPEEDUP.md`, new, at most about 15 KB: the design as built, with every ID that code, tests or docs cite, E1, E3, §5.4 and the U#s and P#s that they cite, and a header that gives `git show <sha>:SPEEDUP_PLAN.md` (planning.md §6). The code's cites of `SPEEDUP_PLAN.md` become `docs/SPEEDUP.md`'s, the same length. `SPEEDUP_PLAN.md`, deleted |
| Owner's paths | `AGENTS.md`: the pier after the road's 100th turn (:7), U# (SPEEDUP) among the IDs (:18), and eight plans merged, with SP's PRs (:20). `docs/README.md`: SP's row, and ENDGAME's row's "after 280 turns" |
| IP | Eight smaller plans, with SP's (:101); M7.6's screenshots at turns 0, 34, 58, 76 and 84 (:209, :320); the schedule test's row, "Area switches at 34/58/76/84" (:249); and M7's notes from §9 |

No code, so the counts are PR 1's. If the owner's #115 has merged by then, PR 2 also takes its learnings step (its planning.md §7): it gathers SP's learnings and changes the guidelines with them.

**Acceptance:** E7, E9.

### 4.2 Landing (Q13)

This plan's PR and PR 1 both target `main`, so there is no stack: PR 2 starts from `main` once PR 1 has merged. The owner lands both: PR 1 as the plan's last code PR, after §6.4's optional run on the Fold4, and PR 2, which changes `AGENTS.md`, `docs/README.md` and IP (`AGENTS.md` §5 step 4). If the owner answers Q13 otherwise, agents land PR 1 with `tools/agent/land_pr.sh` once its reviews are done.

The plan changes only on `sp/plan` until its PR merges. After that, PR 1 carries the plan's final sync: its status, §4.3's rows, the counts and §6.4's results (planning.md §5). PR 2 deletes it.

PR 2 and the owner's #115 both change `AGENTS.md` and `docs/README.md`. Whichever lands second merges `main` first, simulated with `git merge-tree`, and keeps both sides' lines.

### 4.3 Review fixes

Fixes from the prototype's build, the internal review (§4.4) and the PRs' reviews, each with its tests and negative case.

| PR | Change | Tests | Negative case |
|---|---|---|---|
| 1 | The strip's test at 529378c compared each climb, an int, with half the car's mark, a float, and GUT warned "Float/Int comparison" once for each reference screen, where `main`'s suite has no GUT warning. 6740ac4 compares with `floori()` of it: the climbs are whole pixels, so the rule is the same (§5.4) | `test_the_route_strip_marks_each_area_the_car_and_the_best` | N4, which still fails it; no GUT warning at 6740ac4 |
| 1 | P8: from turn 84 the endless road is the Desert, so `test_autopilot_300_turns.gd`'s 300 turns take 831.4–920.2 s, not 607.5–656.2 s. 339b126 says so in its comment, "about 15 minutes", and raises its cap from 20 minutes to 30, twice the run, as the other drives' caps are (U11) | `test_autopilot_300_turns.gd`'s two tests: 2/2, 100 asserts | None: a cap only stops a car that never ends |
REVIEW_FIX_ROWS_TBD

### 4.4 Internal review

INTERNAL_REVIEW_TBD

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

The road to the sea, `areas/schedule.tres`, with P1's times on 1,000 seeds and P5's for `main` on seeds 0–19:

| Area | From turn | Turns | Way in | Straights | Day | Time, P1 (mean) | A turn | `main`: turns, mean time |
|---|---|---|---|---|---|---|---|---|
| City | 0 | 34 | — | 2–5 | 120 s | 53.1–63.7 s (58.1) | 1.71 s | 34, 57.9 s |
| Rural | 34 | 24 | The tunnel, a pit stop | 3–7 | 60 s | 41.9–66.0 s (50.7) | 2.11 s | 66, 135.8 s |
| Meadows | 58 | 18 | The bridge, a pit stop | 6–12 | 60 s | 43.5–79.2 s (56.5) | 3.14 s | 100, 217.0 s |
| Village | 76 | 8 | — | 4–8 | 120 s | 14.8–35.6 s (20.9) | 2.61 s | 20, 39.0 s |
| Desert | 84 | 16 | Last Gas, a pit stop | 6–14 | 60 s | 39.1–76.9 s (53.6) | 3.35 s | 60, 136.1 s |
| Coast | 100 | — | — | 20 | 120 s | 3.9–4.2 s (4.1) | — | 3.6 s |
| The road | | 100 | | | | 216.1–280.2 s (243.8) | | 280, 562.2–613.3 s (589.4) |

The Road Home, `areas/schedule_home.tres`, is its mirror (Q2): `mirrored`, starting W (docs/ENDGAME.md W9), with the same turns in reverse, and its set pieces lead into Rural and the City:

| Area | From turn | Turns | Way in | Time, P1 (mean) | A turn | `main`: turns, mean time |
|---|---|---|---|---|---|---|
| Desert | 0 | 16 | — | 41.5–88.5 s (58.2) | 3.64 s | 60, 142.5 s |
| Village | 16 | 8 | Last Gas, a pit stop | 14.7–33.4 s (20.9) | 2.62 s | 20, 38.8 s |
| Meadows | 24 | 18 | — | 45.7–86.6 s (58.6) | 3.25 s | 100, 219.0 s |
| Rural | 42 | 24 | The bridge, a pit stop | 41.7–67.5 s (50.3) | 2.10 s | 66, 136.6 s |
| City | 66 | 34 | The tunnel, a pit stop | 50.1–62.8 s (56.3), with the last straight and home's tiles | 1.66 s | 34, 56.5 s |
| The road | | 100 | | 219.2–280.5 s (244.3) | | 280, 561.4–614.0 s (593.3) |

How the turns were chosen:
- **The City stays**, as the owner asked: its 34 turns are where a run learns the pattern, with the tutorial before them, and they take 58 s. The Coast's straight takes 4 s more. That leaves the 66 turns between them to fit the rest of the five minutes.
- **The straights first.** The owner asked for longer straights from the Meadows on, and they cost time: §5.2's model puts SP's 100 turns at 207 s on average with `main`'s straights, and at 247 s with SP's, so the straights add about 40 s. Shorter straights would buy turns back, but not what the owner asked.
- **A margin for the slowest seeds.** The time to the end spreads: on 1,000 seeds a road, its standard deviation was 10.09 s to the pier and 10.51 s home, and the slowest of P1's 2,000 runs took 280.5 s. So SP aims at a mean of about 245 s, 5.3–5.6 standard deviations below the bound: 12 runs of the 1,000 to the pier and 14 home took more than 270 s, and none more than 280.5 s. E1's ten test seeds a road take 229.2–255.3 s to the pier and 233.3–267.6 s home (§6.1).
- **About a minute an area.** Rural's 24 turns take 51 s, the Meadows' 18 take 57 s and the Desert's 16 take 54 s, so each long area is about one of §5.3's 60 s days. The Village keeps its place as an interlude before the Desert: its 8 turns take 21 s, 9% of the run, where its 20 took 39 s, 7% (Q9).

The order of the areas, their set pieces, Last Gas and the pit stops' rule stay (Q8). The pit stops come 24 and 26 turns apart on the road to the sea, after turns 34, 58 and 84, where they came 66 and 120 apart; on the Road Home, 26 and 24 apart, after turns 16, 42 and 66. A Departure from an area (docs/ENDGAME.md §5.11) has as many turns fewer to the end: from the Desert 16 turns to the pier, the Village 24, the Meadows 42 and Rural 66; on the Road Home, from the Village 84 turns home, the Meadows 76, Rural 58 and the City 34.

`validate()` (`area_schedule.gd`:48) keeps each area's gap, its set piece, its longest straight and the next junction's tile (`gap()`, :113), within `BUFFER_REFILL_AT`, 37 tiles (docs/M2.md H31, docs/M4.md K1). SP's widest is the Meadows' 18, behind the bridge (5 + 12 + 1), and the Coast's 21 as on `main`; on the Road Home, the Desert's 15. No rule binds the switch turns' parity: a set piece takes the heading of the straight it replaces (`set_piece.gd`:21). SP's, like `main`'s, are all even, so each area starts with the same turn as on `main`, a left on the road to the sea.

### 5.2 Straights and speed (PR 1; Q3, Q4; U4; E2)

The car accelerates at its area's `accel` along a straight, toward `target_speed()`'s cap (`car_sim.gd`:249–257), `minf(GLOBAL_SPEED_CAP, BASE_TOP_SPEED + dist_total * TOP_SPEED_GROWTH)`: 4.0 tiles/s at the start, 0.002 more a tile driven, and at most 7.0 (`tuning.gd`:65–68). It brakes to its area's junction speed before each junction. A turn's braking and corner cost the same on any straight, so a longer straight takes less time a tile: the car reaches a higher speed and holds it longer. The generator draws each straight's length from its area's `min_straight`..`max_straight`, with the road's stream, `_rng_road` (`road_generator.gd`:417–418), and SP changes only the ranges:

| Area (road to the sea) | Straights, tiles | Path tiles a turn | Mean speed, tiles/s | Mean top speed, tiles/s |
|---|---|---|---|---|
| Rural | 3–7, unchanged | 6.7 → 6.9 | 3.27 → 3.26 | 5.08 → 4.61 |
| Meadows | 3–7 → 6–12 | 7.1 → 11.7 | 3.27 → 3.74 | 5.34 → 5.01 |
| Village | 2–5 → 4–8 | 5.35 → 8.3 | 2.74 → 3.17 | 4.25 → 5.12 |
| Desert | 3–8 → 6–14 | 8.0 → 13.7 | 3.54 → 4.09 | 5.79 → 5.57 |

`main`'s values are P5's, on seeds 0–19, and SP's P1's, on 1,000 seeds. Each area's `accel`, junction speed and braking distance stay. The new test, `test_from_the_meadows_on_the_straights_are_longer_than_rurals`, checks E2's rule on each entry of the road from the Meadows on, the Coast's 20 tiles included: its shortest and longest straights are longer than Rural's, 3 and 7.

**Why these lengths.** A model of the run, P2 (in the prototype's session, not in the repository), draws roads as the generator does, the turns and each straight from its area's range, and integrates `target_speed()` at 60 Hz along each straight. It leaves out the corners, the dead ends and the set pieces' shapes, and runs 1–2% slow against P1: 247 s on average, where P1 measured 244. On 2,000 runs:

| Case | Mean | p95 | Slowest |
|---|---|---|---|
| `main` | 595 s | 618 s | 650 s |
| SP's turns, with `main`'s straights | 207 s | 220 s | 237 s |
| SP, the default | 247 s | 263 s | 286 s |
| Twice `main`'s straights, Q3's alternative: the Meadows 6–14, the Village 4–10, the Desert 6–16 | 256 s | 274 s | 296 s |
| The same, with the areas at 34, 58, 74 and 82 and the end after turn 98 | 250 s | 268 s | 289 s |

Twice `main`'s straights would put the slowest run 4 s inside the bound in the model, which its 1–2% doesn't leave room for. SP's are about twice `main`'s at their short end and a little less at their long end, and the Village's, which are the defaults' 2–5 on `main` (`area_def.gd`:14–15), become 4–8, above Rural's as E2 asks.

**The top speed (Q4, U4).** A run is now 726–984 path tiles to the pier, not 1,829–1,998, so the cap ends at 5.38–5.90 tiles/s, not 7.0: the Desert's mean top speed is 5.57 tiles/s, against 5.79 on `main`, and on the Road Home, which starts in the Desert, 4.41. SP keeps `TOP_SPEED_GROWTH`, so the car's feel on every road, Keep Driving's too, stays as tuned. P6 tried 0.0035 a tile, which reaches 7.0 after about 860 tiles: the Desert's mean top speed became 6.71 tiles/s, but a run was only 4.0 s quicker to the pier and 2.9 s home, as the junctions and corners take most of a turn's time.

### 5.3 Days (PR 1; Q5; U2, U10; E3)

A zone's clock starts at 07:00 as the car enters it (`DAY_START_HOUR`, `tuning.gd`:247) and turns a whole day in its area's `day_seconds`, 120 s by default (`area_def.gd`:71). `rural.tres`, `meadows.tres` and `desert.tres` set `day_seconds = 60.0`; the City, the Village and the Coast keep 120 s. The light's keys (`LIGHT_HOURS`, `tuning.gd`:251) fall at:

| Hours | The light | A 120 s day | A 60 s day |
|---|---|---|---|
| 07:00–17:00 | Day, white | 0–50 s | 0–25 s |
| 17:00–20:00 | Dusk: orange at 18:30, then the night's blue | 50–65 s | 25–32.5 s |
| 20:00–04:30 | Night | 65–107.5 s | 32.5–53.75 s |
| 04:30–07:00 | Dawn: pink at 06:00, then white | 107.5–120 s | 53.75–60 s |

`DayCycle.least_day_seconds()` (`day_cycle.gd`:123–127), 55.68 s, is the shortest day whose light changes within `LIGHT_MAX_RATE`, a quarter of white a second, so that the light shown follows the clock exactly (docs/DAYNIGHT.md §5.3). `AreaDef.validate()` (`area_def.gd`:105–110) reports a shorter day, as N7 shows. A 60 s day's steepest change uses 92.8% of the rate.

**Why 60 s (P3).** The share of the zones of Rural, the Meadows and the Desert, in P1's 2,000 runs, that reached the night:

| Zones | 120 s | 90 s | 80 s | 60 s |
|---|---|---|---|---|
| Rural, to the sea | 0.1% | 67.0% | 98.7% | 100% |
| Meadows, to the sea | 7.4% | 92.4% | 100% | 100% |
| Desert, to the sea | 4.2% | 76.5% | 96.6% | 100% |
| Rural, home | 0.2% | 64.2% | 98.9% | 100% |
| Meadows, home | 12.7% | 98.5% | 100% | 100% |
| Desert, home | 15.0% | 93.6% | 99.7% | 100% |
| All 6,000 | 6.6% | 82.0% | 99.0% | 100% |

At 60 s, each reached it: the shortest, a Desert zone of 39.1 s, had 6.6 s of night. A zone's night lasted 17.3–20.8 s on average, by area and road, and the night was 23.2% of a run to the sea and 23.9% of one home, against 27.1% and 27.2% on `main`. The City's day stays 120 s: its zones end at 17:37–19:44, in its dusk, so a run's first night still comes in Rural (docs/DAYNIGHT.md §5.8). The Village's 21 s and the Coast's 4 s end by day.

**Longer zones.** 1,149 of the 6,000 zones, 19.1%, lasted past 60 s, into a second morning, and 2, a Desert and a Meadows zone home, past 85 s, into a second dusk; none reached a second night, at 92.5 s. A day that comes round again is what a zone's clock does on `main` in a long zone too (docs/DAYNIGHT.md §5.1).

**The light between zones (U10).** A zone that ends at night hands over to the next zone's morning, which `Daylight` fades in within `LIGHT_MAX_RATE`, in 2.33 s (docs/DAYNIGHT.md Q2). More zones now end at night or dawn (P4):

| Zones | Night | Dawn | Day | Dusk |
|---|---|---|---|---|
| Rural, to the sea | 79.4% | 19.2% | 1.4% | — |
| Meadows, to the sea | 36.0% | 38.3% | 25.7% | — |
| Desert, to the sea | 53.1% | 32.0% | 14.9% | — |
| Rural, home | 81.7% | 16.9% | 1.4% | — |
| Meadows, home | 21.0% | 44.1% | 34.8% | 0.1% |
| Desert, home | 26.6% | 36.7% | 36.6% | 0.1% |

On `main`, 39 of P5's 120 such zones ended at night. The movies of §6.4 show the fades: no flash, and no step above the rate.

### 5.4 The route strip (PR 1; Q6; U5; E6)

The strip (`ui/route_strip.gd`, docs/ENDGAME.md §5.14) stays 40% of the HUD's height (`hud.tscn`:66–68): 256, 320 and 368.8 pixels on the reference screens, 640, 800 and 922 pixels high. `RouteStrip.height()` (:64–68) places turn t at `roundi(t / finish_turn * roundi(length))`, so over 100 turns its car climbs 2.56, 3.2 and 3.69 pixels a turn on average, 2–3, 3–4 and 3–4 pixels each, where `main`'s 280 turns gave 0.91–1.32. Its ticks are at turns 0, 34, 58, 76, 84 and 100; the closest, the Village's and the Desert's, are 8 turns apart, 20.5–29.5 pixels.

The car's mark is `CAR_HEIGHT`, 8 pixels, high. `test_the_route_strip_marks_each_area_the_car_and_the_best` drives the strip's car over 100 turns on each reference screen, and checks that each climb is the strip's rounded length over 100 turns, rounded down or up, so the car climbs evenly, and at most `floori(CAR_HEIGHT / 2.0)`, 4 pixels, so that each step overlaps the last by half the mark. `main`'s test allowed 0–2 pixels, a pixel or so a turn. The comment at `route_strip.gd`:7 says "a few pixels a turn". The test's HUD, sized by `PIXEL_A_TURN` so that its strip is a pixel a turn, becomes 250 pixels high, for a strip of 100, from 700. With a strip of 80% (N4), the car climbs 5.12–7.38 pixels a turn, which the test rejects.

Q6's alternative, a strip of 20%, would climb 1.28–1.84 pixels a turn, nearer `main`'s, but with the Village's and the Desert's ticks only 10.2–14.8 pixels apart, under twice the mark's height.

### 5.5 The save (PR 1; Q7; U8; E6)

Saves stay at version 5 (`save_data.gd`:14), and nothing in the save names the road's length but `V3_FINISH_TURN`, 280 (:51), which migrates version 3's saves, made when both roads had 280 turns: it stays. A save from `main` loads as it is:
- **The best time.** `record_arrival()` keeps the least time (:248), so a road's first arrival after SP, at most five minutes, replaces `main`'s, about ten.
- **The farthest turn**, up to 280, is kept as the most (:251). The goal line clamps it to the road's finish, `mini(best.turns, finish_turn)` (`game_over.gd`:125–127): a player who has passed turn 100 on `main` without arriving reads "Next: reach the sea. Your best: turn 100 of 100" until they arrive. The strip clamps it too (`route_strip.gd`:64–68), and `test_the_route_strip_shows_only_on_a_road_with_a_finish` checks it. `Hitchhiker.road_turn()` takes `mini(farthest, finish_turn)` on the Road Home (`hitchhiker.gd`:54–58), so a home farthest of 50, in `main`'s Desert, now places her before the 50th junction, in Rural: she still stands at the player's farthest junction, as docs/ENDGAME.md §5.17 has it.
- **History.** The overall best turns and the Atlas's bests (`atlas_screen.gd`:60–73) aren't clamped: an area's best turns on `main`, such as the Meadows' up to 100, can exceed its turns now, 18, and stay as they were driven.

Q7's alternative, version 6, would clamp each road's farthest turn and drop `main`'s best times: a migration and its tests for a Pages build whose players are few.

### 5.6 What stays (PR 1; Q8, Q11; U7, U9; E4)

- **The road up to the Meadows.** The City's and Rural's areas, straights and set piece are as on `main`, and the generator draws each straight from its area's range in turn, so on 200 seeds the road to the sea is `main`'s, tile for tile with its dead ends, up to and including its 58th junction, and differs by its 66th (P7). The Road Home starts in the Desert, whose straights change, so it differs from `main`'s by its 16th junction, the first that P7 compares. `smoke.sh`'s 60 s end in Rural at turn 35, as on `main`.
- **The golden digests** (U7) of `endless()` on seeds 0–19 to turn 300 change, as that road crosses the Meadows from turn 58 and the Desert from 84 with longer straights: `PATH_DIGEST` becomes `7c3ec860ba0ec1e2475c5e586862301d` and `ROAD_DIGEST` `00714c894c32efb84dc483e06ebe8f72`, and PR 1's commit says why (docs/ROADGEN.md §6.1).
- **The tutorial** (docs/TUTORIAL.md) comes before the City's 34 turns, from whose end the schedule counts, and doesn't change. On seeds 0–99, the autopilot finished it in 17.9–22.8 s and arrived at 242.9–289.7 s, each with full health (P9; Q10).
- **Keep Driving** drives `endless()`, which runs the Desert forever from turn 84 (Q11). Its turns past 84 take longer than `main`'s Meadows', so `test_autopilot_300_turns.gd`'s 300 turns take 831.4–920.2 s, not 607.5–656.2 s (P8, §4.3); its drive with every kind of junction takes 476.2–495.8 s on both.
- **Departures** start at their area's new turn (§5.1).
- **The legends** and their pools stay. A run's junctions shift toward the City, which has 34% of them where it had 12% (U9): a run meets the City's legends more often, and at 1% errors a junction 37% of runs would arrive, where 6% did. An arrival unlocks a legend of any area's pool (docs/ENDGAME.md §5.5), and Departures reach the later areas' legends.
- **The music and the ambience** cross-fade on `area_changed`, as on `main`. Their loops last 7.27–10.67 s and 4.0 s, so the Village's 21 s play its music at least twice.

### 5.7 Tests (PR 1)

| File | Change |
|---|---|
| `tests/unit/test_area_schedule.gd` | New: `test_from_the_meadows_on_the_straights_are_longer_than_rurals` (E2). Renamed: `test_areas_and_set_pieces_switch_at_34_58_76_and_84`, `test_the_games_road_ends_at_the_pier_after_its_100th_turn`. The new turns in each test of the schedules, the Road Home, the pit stops, Departures' copies and `validate()`'s finish (U6) |
| `tests/sim/test_drive_to_the_end.gd` | `MOST_SECONDS`, 300 s, asserted on each run (E1), on `SEEDS`, 10 seeds a road, not 5; `_check_night()` on each zone of `NIGHT_AREAS`, Rural, the Meadows and the Desert, that the car leaves (E3); `MAX_STEPS` twice `MOST_SECONDS`; 100 turns |
| `tests/unit/test_hud.gd` | The strip's even climb (§5.4), and the new ticks and turns |
| `tests/unit/test_road_generator_finish.gd` | Renamed: `test_the_road_home_ends_at_home_after_100_turns`; both roads' 100 turns |
| `tests/unit/test_road_generator_determinism.gd` | The new digests (§5.6) |
| `tests/integration/test_area_start.gd` | The Village's 8 turns |
| `tests/integration/test_hitchhiker_run.gd` | Her departure at the Road Home's turn 18, in the Village from 16 |
| `tests/sim/test_area_order.gd`, `tests/sim/test_tutorial_run.gd` | The switches at 34, 58, 76 and 84, driven to turn 90, with their caps and comments (U11) |
| `tests/sim/test_set_pieces_on_the_road.gd` | Seed 1 meets the bridge after turn 58, and has left it by 63 |
| `tests/unit/test_game_over.gd` | A best of turn 72 before the first arrival |
| `tests/unit/test_prop_scatter.gd` | Past the bridge after turn 58 |
| `tests/sim/test_autopilot_300_turns.gd` | The comment and the cap, 30 minutes (P8, U11) |
| `tests/integration/test_daylight_run.gd` | A comment: the zone of 60 s that its test enters is any area's, whatever Rural's own day |

The tests that use 280 as a value stay: `test_hitchhiker.gd`, `test_title.gd` and `test_hitchhiker_run.gd`:118–119 pass a finish or record an arrival of their own, and `test_save_data.gd` migrates version 3's saves (§5.5).

### 5.8 Docs (PR 1; Q12; U12)

PR 1 changes `plan.md`, the game's design, in place, and adds a note to each summary of a finished plan, as EG did ("Since EG, …", docs/ZONE_SELECT.md Z4), so that its history stays. Until PR 2, the notes cite `SPEEDUP_PLAN.md`; PR 2 makes them `docs/SPEEDUP.md`'s.

| Where | Δ |
|---|---|
| `plan.md`:13 | "After its 280th turn" → "After its 100th turn" |
| `plan.md`:122–125, §3.6 | The table's turns: the Meadows at 58, the Village at 76, the Desert at 84 and the Coast at 100 |
| `plan.md`, after §3.6's table | A new first bullet: "From the Meadows on, the road turns less and runs straighter: each area's straights are longer than Rural's, the Meadows' 6–12 tiles, the Village's 4–8 and the Desert's 6–14, and the autopilot drives the whole road in about four minutes, at most five (`SPEEDUP_PLAN.md` E1, Q3)." |
| `plan.md`:229, §5.5 | "120 s by default: dusk comes 50 s into a zone, and the night at 65 s." → "120 s by default, and 60 s in Rural, the Meadows and the Desert, whose zones take about a minute: dusk comes 10/24 of a day into a zone and the night 13/24, at 50 s and 65 s in a day of 120 s, and at 25 s and 32.5 s in one of 60 s (`SPEEDUP_PLAN.md` Q5)." |
| `plan.md`:356, §9 | `"best_seconds": 581.0` → `244.0`, and `"farthest": 280` → `100` |
| `plan.md`:390, §11 | "turns 34, 100, 200, 220 and 280, and the road ends at the pier after its 280th turn" → "turns 34, 58, 76, 84 and 100, and the road ends at the pier after its 100th turn" |
| `plan.md`:429, §13 | "after turn 280" → "after turn 100" |
| docs/ENDGAME.md :3 | Adds: "Since SP, the road ends after its 100th turn, and the autopilot drives it in about four minutes (`SPEEDUP_PLAN.md` Q1)." |
| docs/ENDGAME.md :11, E6 | Adds: "Since SP, past turn 100 (`SPEEDUP_PLAN.md` Q1)." |
| docs/ENDGAME.md :47, Q1 | Adds: "Since SP, after its 100th turn (`SPEEDUP_PLAN.md` Q1)." |
| docs/ENDGAME.md :112, §5.6 | Adds: "Since SP, the Village from 16, the Meadows from 24, Rural from 42 and the City from 66, and `home` after 100 (`SPEEDUP_PLAN.md` Q2)." |
| docs/ENDGAME.md :120, §5.8 | Adds: "Since SP, the Coast starts at turn 100 (`SPEEDUP_PLAN.md` Q1)." |
| docs/ENDGAME.md :162, P1 | Adds: "Since SP, seeds 0–9: at the pier after 3.8–4.3 minutes, and home after 3.9–4.5 (`SPEEDUP_PLAN.md` E1)." |
| docs/ENDGAME.md :170, §8 | Adds: "Since SP, about four minutes, at most five (`SPEEDUP_PLAN.md` E1)." |
| docs/DAYNIGHT.md :40, Q3 | Adds: "Since SP, 60 s in Rural, the Meadows and the Desert (`SPEEDUP_PLAN.md` Q5)." |
| docs/DAYNIGHT.md :99, §5.8 | Adds: "Since SP, Rural, the Meadows and the Desert turn a day in 60 s, so each of their zones, about a minute long, reaches its night, 32.5 s in (`SPEEDUP_PLAN.md` Q5)." |
| docs/ROADGEN.md :90, after §5.5's table | Adds: "Since SP, the straights are longer from the Meadows on: the Meadows' 6–12, the Village's 4–8 and the Desert's 6–14 (`SPEEDUP_PLAN.md` Q3)." |

Unchanged, as history or still true: `plan.md`:154, the default day; docs/ENDGAME.md W6 (:25), which tells of 280 turns, and :140; docs/DAYNIGHT.md :69, :137 (N39) and :152; docs/ROADGEN.md :78, whose K1 check builds its own schedules; and IP's M4.2 (:147), which tells what M4 built. PR 2 changes the owner's paths and IP (§4).

---

## 6. Verification

### 6.1 Checks and counts

The checks are `AGENTS.md` §3's five: the import, `check_scripts.sh`, `lint.sh`, GUT and `smoke.sh`. They ran locally with Godot 4.7.2 on `main` and on each of the prototype's commits, and in CI on 339b126, in run 44739054576, started by hand with `upload-builds`, whose `lint`, `test`, `export-web` and `export-android` jobs passed. `main`'s CI counts are its push's run, 44718978187:

| State | Where | Scripts loaded | Test scripts | Tests | Asserts | GUT time | Smoke |
|---|---|---|---|---|---|---|---|
| `main` (ec6f54d) | Local | 221 | 103 | 903 | 456,541 | 141.7 s | `autopilot: tile 165, turns 35, area rural` |
| `main` (ec6f54d) | Run 44718978187 | 221 | 103 | 903 | 456,541 | 135.4 s | The same |
| 529378c | Local | 221 | 103 | 904 | 545,822 | 143.5 s | The same |
| 6740ac4 | Local | 221 | 103 | 904 | 545,822 | 144.1 s | The same |
| Prototype (339b126) | Local | 221 | 103 | 904 | 545,822 | 145.1 s | The same |
| Prototype (339b126) | Run 44739054576 | 221 | 103 | 904 | 545,822 | 149.9 s | The same |

`lint.sh` found no problem, and would leave each of the 221 files as it is. `smoke.sh` printed no error line, and `git status --porcelain` printed nothing after the checks. GUT reported 3 warnings at 529378c, which 6740ac4 fixes (§4.3), and none at 6740ac4 or 339b126.

CI's `test` job took 3 min 48 s on the prototype, against 3 min 22 s on `main`'s push. In the JUnit reports of `main`'s and 529378c's local runs, the scripts that drive or lay `endless()` to turn 300, which runs longer from turn 58, took longer: `test_autopilot_300_turns.gd` 3.5 s more (P8) and `test_road_generator_occupancy.gd` 2.7 s more, while `test_drive_to_the_end.gd`, with twice the seeds of shorter runs, took 1.0 s less.

### 6.2 Negative cases

Each case makes one change to the prototype, runs the whole suite with `run_tests.sh`, and checks that it exits 1 and fails the tests it names; then `git checkout` restores the files. All eight ran on 6740ac4 and again on 339b126, with the same failures and the same counts of asserts. N7 ran on `test_area_schedule.gd` alone, with `-gselect`, as the whole suite then runs out of memory.

| N# | Change | Fail |
|---|---|---|
| N1 | `schedule.tres` and `schedule_home.tres` as on `main`: the areas at turns 34, 100, 200 and 220, home's at 60, 80, 180 and 246, and both roads ending after turn 280, with SP's straights and days | 21 tests: nine of `test_area_schedule.gd`'s, each that names a switch, a pit stop or a finish's turn; both drives of `test_drive_to_the_end.gd`, which reach their cap, "[600.0] expected to be <= than [300.0]"; one each of `test_area_start.gd`, `test_hitchhiker_run.gd`, `test_area_order.gd`, `test_set_pieces_on_the_road.gd` and `test_tutorial_run.gd`; `test_hud.gd`'s two strip tests; the digests; and `test_road_generator_finish.gd`'s two |
| N2 | `meadows.tres`: straights of 3–7 tiles, as on `main` | 2: `test_from_the_meadows_on_the_straights_are_longer_than_rurals`, "[3] expected to be > than [3]: meadows's shortest straight", and `test_the_game_road_matches_its_digests` |
| N3 | `rural.tres`, `meadows.tres` and `desert.tres` without `day_seconds`: 120 s days, as on `main` | 2: both drives, in `_check_night()`, which find zones that end before their night, such as "[64.28] expected to be > than [65.0]: pier seed 6: meadows's night" |
| N4 | `hud.tscn`: the strip's anchors at 0.1 and 0.9, 80% of the HUD's height | 2: `test_hud.gd`'s strip tests: "[6] expected to be <= than [4]: 640 pixels high: half the car's mark", and the strip's pixels, such as "[200] expected to equal [100]: at the finish" |
| N5 | `village.tres`: no straights of its own, so the defaults' 2–5, as on `main` | 2: E2's test, "[2] expected to be > than [3]: village's shortest straight", and the digests |
| N6 | `desert.tres`: straights of 3–8 tiles, as on `main` | 3: `test_the_autopilot_drives_to_the_pier`, whose Desert zone now ends before its night, "[30.7] expected to be > than [32.5]: pier seed 1: desert's night"; E2's test, "[3] expected to be > than [3]: desert's shortest straight"; and the digests |
| N7 | `rural.tres`: `day_seconds = 55.0`, under `least_day_seconds()`, 55.68 s | 9 of `test_area_schedule.gd`'s 24: each schedule with Rural is invalid, "AreaSchedule: rural: day_seconds is below 55.69", rounded up (`area_def.gd`:109), and the generator lays its fallback road. The whole suite ran out of memory: `test_road_generator_tutorial.gd`:41, unchanged from `main`, looks for a set piece on the fallback road, which lays none, until the kernel killed Godot at 6.6 GB after 133 s (§9) |
| N8 | `schedule_home.tres` as on `main`: the Village at 60, the Meadows at 80, Rural at 180 and the City at 246, and home after 280 | 6: `test_the_autopilot_drives_the_road_home`, whose ten runs reach their cap in Rural, "[600.0] expected to be <= than [300.0]: home seed 9: the time to the end"; `test_the_games_pit_stops`; `test_the_road_home_is_valid_and_runs_the_other_way`; `test_the_route_strip_shows_only_on_a_road_with_a_finish`; `test_the_road_home_ends_at_home_after_100_turns`; and `test_hitchhiker_run.gd`'s `test_a_departure_that_starts_before_her_turn_has_her_too` |

U6's count ran the same way, on `main` with 339b126's two schedules: 23 of its 903 tests failed.

### 6.3 Editor warnings

As docs/agents/checks.md §1 says, a temporary `override.cfg` raised the warnings at level 1 to errors, and `check_scripts.sh` loaded every script, on `main` (ec6f54d) and on 339b126. The two logs are the same, with only `main`'s five: `INTEGER_DIVISION` in `world/greybox_atlas.gd`:141, with which `world_renderer.gd` and `setpieces/pier.gd`, which depend on it, fail; in `ui/main.gd`:101, `test_greybox_atlas.gd`:15 and `test_iso.gd`:42; and `UNUSED_VARIABLE` `junctions` in `test_road_generator_occupancy.gd`:30. Godot reports only a script's first error, so the check ran again without `integer_division`: only `junctions` was left, on both. None of the 15 scripts that SP changes, `route_strip.gd` and §5.7's 14 test files, is among them, so none has a warning.

### 6.4 Verified only in CI or on devices

- **CI.** PR 1's four required checks, and its `test` job's time (§6.1). This plan's PR changes only this file.
- **Nothing for the Web or Android alone.** PR 1 changes the areas' data, a comment and tests: no node, no `Polygon2D`, no input, and no text but numbers, which the font has. Its CI builds the Web and the APK as `main`'s does, so this plan asks for no Web check, and the run on the Fold4 is optional (Q13).
- **E8, done on the prototype, in a desktop run** (docs/agents/checks.md §2). Movie Maker's frames of the autopilot from the prototype's tree, seed 1, from Rural and from the Desert:
  ```bash
  XDG_DATA_HOME=/tmp/sp/movie/data xvfb-run -a -s "-screen 0 1280x1024x24" godot --path . \
    --write-movie /tmp/sp/movie/f.png --fixed-fps 60 --quit-after 3900 -- --autopilot --seed=1 --area=rural
  ```
  and the same with `--quit-after 4800` and `--area=desert`. Then a frame each 0.25 s, its mean luminance out of 255, and a sheet of frames from each run, six from Rural and seven from the Desert:
  - **From Rural**, 65 s: the day to 25 s; the dusk, orange at 29 s, which darkens at most 5.5 a sample; the night from 32.5 s, at about 65–73, on Rural's last straights and on the bridge at 49.5 s; then the Meadows' banner at 51 s, as their morning fades in from 67.5 to 133 in 50.25–52.5 s, at most 8.0 a sample; and the Meadows by day at 56 s.
  - **From the Desert**, 80 s: the day; the dusk, at most 6.1 a sample; the night from 32.5 s; the Coast's banner at 44.5 s, as its morning fades in from 92 to 195 in 43.75–46.0 s, at most 11.7 a sample; the lighthouse at 47.5 s; EG's sunset on the pier, from 194 to 72 in 47.0–50.25 s, at most 15.4 a sample; and the end screen at 53.5 s: "Turns: 16", "Time: 0:48" and "Next: reach the sea. Your best: turn 0 of 100", as a run from a later area keeps no overall best (docs/ENDGAME.md §5.11).
  - `LIGHT_MAX_RATE` allows 15.9 a sample. No sample was brighter or darker than both its neighbours by more than 1.1, so nothing flashed. In both sheets, the strip's car climbed with the HUD's turns: from Rural past the Meadows' tick, at turn 58, and from the Desert to the strip's top, where it stood from the Coast on.

  PR 1 runs them again only if `main` has changed the light, the areas or the HUD since ec6f54d (§4.1 step 2).
- **The Fold4, optional, by the owner, before landing PR 1** (Q13). The debug APK of run 44739054576, its artifact `android-Android APK`, kept until 2026-11-21 12:49 UTC, serves PR 1 as long as `git diff --name-only 339b126 <PR 1's head> -- . ':!tests' ':!addons/gut' ':!*.md'` prints nothing (docs/agents/checks.md §4); otherwise `gh workflow run ci.yml -R pompomon/roadgame --ref sp/1-road -f upload-builds=true`. A phone takes no arguments, so play by hand, with Play or the title's Start, which in a debug build chooses any area (docs/ZONE_SELECT.md Z1). On both screens: the nights of Rural, the Meadows and the Desert, and the fades into each next morning; the Village's 21 s; the Desert's long straights; the strip's car, climbing evenly; and the end screen's time at the pier, which the autopilot reaches in about four minutes from the City.

### 6.5 Measurements

The probes ran headless with Godot 4.7.2, at 60 steps a second, as GUT scripts that aren't committed; P2 is a Python model. P1, P3, P4, P6 and P9 ran on the prototype's game, which none of its commits after 529378c changes, and P1's zone times match N3's messages at 339b126 to the step, such as pier seed 6's Meadows, 64.28 s. P5 ran on `main`, and P7 and P8 on both.

| P# | What | Result | Used by |
|---|---|---|---|
| P1 | The autopilot drives each road to its end, without the tutorial, seeds 0–999: each area's time, path tiles and top speed | All 2,000 arrive with full health. To the pier: 216.1–280.2 s, 243.8 on average, a standard deviation of 10.09, p95 261.6 and p99 270.9, with 12 runs over 270 s. Home: 219.2–280.5 s, 244.3, 10.51, 262.4 and 273.1, with 14 over 270 s. 726–984 path tiles to the pier, and a top speed of 5.38–5.90 tiles/s at the end. Each area's times in §5.1, its speeds in §5.2. Seeds 0–9, E1's: 229.2–255.3 s to the pier and 233.3–267.6 s home | Q1–Q3, E1, U1, U3, U4 |
| P2 | §5.2's model of a run: roads drawn as the generator draws them, with `target_speed()` integrated at 60 Hz along each straight; 2,000 runs a case | §5.2's table: SP 247 s on average, 1–2% slower than P1; twice `main`'s straights, 256 s, the slowest at 296 s | Q3 |
| P3 | P1's 6,000 zones of Rural, the Meadows and the Desert: how many last into their night, with days of 120, 90, 80 and 60 s | 6.6%, 82.0%, 99.0% and 100% (§5.3). At 60 s, the shortest, a Desert zone of 39.1 s, has 6.6 s of night | Q5, E3, U2 |
| P4 | The same zones: the light as each ends, with 60 s days | §5.3's table: 21.0–81.7% end at night, by area and road. 19.1% last into a second morning, and none into a second night | U10 |
| P5 | `main` (ec6f54d): the autopilot drives each road to its end, seeds 0–19 | 562.2–613.3 s to the pier and 561.4–614.0 s home; each area's time (§5.1) and speeds (§5.2); 39 of the 120 zones of Rural, the Meadows and the Desert end at night | U1, U4, U10 |
| P6 | P1 with `TOP_SPEED_GROWTH` at 0.0035 a tile, seeds 0–199 | 4.0 s quicker to the pier, 239.9 s on average, and 2.9 s home, 241.7 s, against P1 on the same seeds; the slowest, 271.4 s and 277.0 s; the Desert's mean top speed 6.71 tiles/s, against 5.57 | Q4, U4 |
| P7 | Both roads, laid on `main` and on the prototype for seeds 0–199, each digested with its dead ends up to the junctions of turns 16, 24, 34, 42, 58 and 66 | To the pier, the same on all 200 seeds up to turn 58, and on none at 66. Home, the same on none, from turn 16 | E4, §5.6 |
| P8 | `test_autopilot_300_turns.gd`'s drives, on `main` and the prototype | 300 turns of `endless()` take 831.4–920.2 s of game time, 881.0 on average, against 607.5–656.2 s; its drive with every kind of junction 476.2–495.8 s on both | §4.3, §5.6, U11 |
| P9 | A first run: the autopilot through the tutorial, then to the pier, seeds 0–99 | The tutorial ends at 17.9–22.8 s, and the car arrives at 242.9–289.7 s, each with full health | Q10, §5.6 |

---

## 7. Owner actions

| When | Action | How |
|---|---|---|
| Now | Answer Q1–Q13 on this plan's PR, or merge it to take their defaults | A PR comment with each Q# to change and its answer. An answer that changes a default changes PR 1, and the probes that it names run again (§3) |
| Now, if wanted | Play the prototype | Run 44739054576's builds, kept until 2026-11-21 12:49 UTC, or a new run's: `gh workflow run ci.yml -R pompomon/roadgame --ref sp/prototype -f upload-builds=true`. Then docs/agents/checks.md §4's download, the APK, or the Web build patched, with `?arg=--autopilot` for the whole road, `&arg=--home` for the Road Home |
| After PR 1's reviews | The Fold4's optional run (§6.4), then land PR 1 | Squash it, as the plan's last code PR (§4.2) |
| After PR 1 | Land PR 2, the docs | Squash it. If #115 is still open, whichever lands second merges `main` first (§4.2) |
| After PR 2 | Tag the prototype, which this plan cites, and delete SP's branches, which GitHub doesn't delete on merge | `git fetch origin sp/prototype && git push origin FETCH_HEAD:refs/tags/archive/sp/prototype`, then `git push origin --delete sp/plan sp/prototype sp/1-road sp/2-docs` |

---

## 8. Risks

| Risk | Impact | Mitigation |
|---|---|---|
| The margin is the autopilot's | The slowest of P1's 2,000 runs took 280.5 s, 19.5 s inside the bound, and E1's test drives 10 seeds a road. A later change to the car, the autopilot, the generator or an area could push rare seeds past 300 s, which no test would show but on those seeds | E1's seeds take 229.2–267.6 s. §4.1 step 2 runs P1 again if `main` has moved; so should a later change that slows the car. The finish's turn and the straights are numbers in the `.tres` files (Q1, Q3) |
| A player is slower than the autopilot | The autopilot never hesitates, and brakes as late as it can; a player who brakes early or misreads a junction takes longer than five minutes | The bound is the autopilot's, as the owner asked (Q10). A player's time shows on the end screen, and the autopilot's four minutes are a time to beat (§9) |
| The end comes sooner | At 1% errors a junction, 37% of runs would reach the end, where 6% did (U9), so its unlocks come sooner | An arrival unlocks one legend (docs/ENDGAME.md §5.5). The finish's turn is one number in `schedule.tres` (Q1), and the pit stops could be fewer (Q8) |
| The Village is short | 8 turns and 21 s: its legends meet fewer junctions | Q9's alternative, 10 turns |
| The light changes faster | A 60 s day's steepest change uses 92.8% of `LIGHT_MAX_RATE`, and more zones hand over from night to morning (U10); a fade could read as a flash on a phone | The movies show no flash and no step above the rate (§6.4), and the Fold4's optional run checks it on the device. Q5's alternative, 80 s, uses 69.6% |
| Old saves | A save from `main`, on Pages, keeps a best time of about ten minutes until its first arrival, and a farthest turn of up to 280 | The goal line, the strip and the Hitchhiker clamp it (§5.5); Q7's alternative, version 6 |
| A first run comes near the bound | With the tutorial, the autopilot arrived at up to 289.7 s (P9) | E1 counts the run without it (Q10) |
| A broken schedule takes the machine's memory | With every schedule invalid, `test_road_generator_tutorial.gd`:41 loops forever on the fallback road (N7), as on `main` | Run such a case on its test script alone (§6.2); §9 notes a bound for the loop |

---

## 9. Notes for later work

- **M7's device QA** (IP §4 M7). A run to the pier now takes about four minutes on the autopilot, so a QA pass can drive both roads, by day and by night, in one sitting. PR 2 moves M7.6's screenshots to turns 0, 34, 58, 76 and 84 (IP :209, :320).
- **A time to beat.** The end screen could show a par for each road, such as the autopilot's 4:00, for a player to beat, as docs/ENDGAME.md §9's medals would for each area's time.
- **Version 6** (Q7), if old records confuse players on Pages: a migration that clamps each road's farthest turn to its end, and drops the best times over five minutes.
- **The top speed** (Q4, P6). If the Desert feels slow on the Fold4, `TOP_SPEED_GROWTH` at 0.0035 a tile, which changes every road's feel.
- **Keep Driving's road** (Q11) is the Desert forever from turn 84. If an endless run should cross more areas, it could have an endless schedule of its own, such as `main`'s.
- **Bound the tutorial test's loop.** `test_road_generator_tutorial.gd`:41 loops until it meets a set piece, which the fallback road never lays (N7). A cap on its tiles would turn a broken schedule's out-of-memory into a failure. It's on `main`, so this plan leaves it alone.
