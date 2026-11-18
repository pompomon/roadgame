# The End of the Road and the Book of Legends — Detailed Plan

Status: approved with Q1–Q19's defaults (§3), as the owner merged its PR, #84, and built: PRs 1–13 pass their checks (§6), and §4.1's **Built** lines say where each differs from this plan. Agents landed PRs 1–3 (#101–#103). PRs 4–12 are open (#104–#112): #104 and #106 wait for the owner (`needs-owner`), #104 for its two Δs to E7 and #106 for its rows' labels, and agents land the others in order (§4.2, §7). PR 13 (#113) carries this final sync, and the owner lands it after the Fold4's checks (§6.4), then PR 14 · 2026-11-18 · Scope: the road ends. After 280 turns, past the Desert, it reaches the sea at the Coast's pier. A run that drives the whole road there arrives, the game's first win, and unlocks a legend that the player hasn't collected, at random. The collection becomes the Book of Legends, the long goal, and the Road Home, the road's mirror, the second quest. This plan calls the work EG. It builds on PL, which has landed, and comes before M7.

The owner asked for options first: "Help me brainstorm the endgame for the roadgame repo. Provide 3 options on what should be the goal for the player and how to better gamify it. Follow the best practices in the industry and game design recommendations from Mark Rosewater." The brainstorm offered A, The End of the Road: a finish line, a win and a second quest; B, Legend Hunter: the collection as a book to complete; and C, Road Master: medals, a driver's grade and a daily road. It recommended B as the heart, A as the finish line, and C's daily road for later. Then the owner asked: "Create a PR with the detailed implementation plan for A and B, with the following adjustments - player unlocks a legend not only by failing, but also for a full road completion - a random legend from the pool of locked. I approve starting west for the reverse road run".

**What happens.** Today the road never ends: the Desert goes on forever (`area_schedule.gd`:3), every run ends in a disaster or a crash (`car_sim.gd`:23–26), and the vision's "drive as far as possible" (`plan.md`:13) has no point at which the player has done it. Mark Rosewater calls the missing piece *inertia*, something built into a game that makes sure it ends, and the first thing a game needs is a *goal*. So after the schedule's last turn, 280 (Q1), the straight leads to a pier on the Coast, and no junction follows (§5.1). The car drives onto it, rolls to a stop, and the run ends in a new state, `ARRIVED`, with the run's time (§5.2, §5.3).

The owner's first answer: a run that drove the whole road also unlocks a legend that the player hasn't collected, neither seen nor unlocked, at random and each as likely as the others, from the pools of the road's areas, on the run's own stream (§5.5). The collection and PL's picks count it as seen. With every legend collected, the arrival unlocks none, and says that the book is full. A run that started in a later area arrives but counts nothing (Q4).

The owner's second answer: the Road Home starts heading W. The first arrival unlocks it, the road driven back from the Desert to the City, which ends at home (§5.6). Its first turn is a right, so its path is the staircase of N and W that can't cross itself (`plan.md` §3.2, W9), and a player who knows "left first" learns the road again. Its arrivals count under `home`, and unlock a legend too.

The collection becomes the Book of Legends (B, §5.10), with NEW LEGEND! on the end screen (§5.9), and the Vanishing Hitchhiker, the road's own urban legend, as a full book's 16th page (§5.17). B's rule, a legend by the way a run fails, gives way to PL's picks, as the owner asked in #80 (Q5). The rest comes a PR each: Departures (§5.11), Keep Driving (§5.13), the route strip (§5.14), pit stops (§5.15), and records and postcards (§5.16).

**Verified locally.** Every file of PRs 1–2 was first built on branch `eg/prototype`, from PL's PR 1 (`pl/1-picks`, 532908a, #81). Its commits, 1da20c6 to 4d3d981, add the road's end, the arrival, the unlock, the save's version 3 and the Road Home's mirror, with 45 tests. 4d3d981 passed the five checks locally with Godot 4.7.2 and in CI (§6.1), and the warnings check (§6.3); each of the 32 negative cases failed the tests it names, run against the whole suite (§6.2). Probes in Godot drove both roads to their ends, laid 200 seeds of each, and measured the unlock's odds, the stop and the save (§6.5). gpt-6.1-sol, a model of another family, found seven issues, each fixed, and none in its review of the fixes (§4.4).

- Godot 4.7.2-stable (4.7.2.stable.official.ed1daf0bf), in CI's image and locally
- GUT 9.7.1
- gdtoolkit 4.5.0 on Python 3.12, in CI's `lint` job and locally. shellcheck isn't installed locally, so `lint.sh` skipped it there; EG changes no shell script

**Precedence.** For EG, this document replaces `plan.md`'s vision (:13), §2.1 (:26), §2.4 (:55), §2.5 (:57–61), §2.6 (:63–66), §3.2 (:86), §3.6 (:121), §7.3 (:295), §9 (:339–352), §11 (:381), §13 (:419–428) and §14 (:434); `IMPLEMENTATION_PLAN.md` (IP) §5.3 (:231); docs/ZONE_SELECT.md Z4 and Q2 (:14, :26); and docs/POOLS.md's collection (V3) where §5.10 changes it, wherever it marks a difference with **Δ** and its finding (W#, §2). Each PR folds its own differences into them as it lands (Q18).

**Reference code.** PRs 1 and 2 split the difference between 532908a, PL's PR 1, and 4d3d981, the head of `eg/prototype`, which never gets a PR of its own (§4.1). PRs 3–14 follow the code of their nearest kin: the tunnel's set piece for the pier, ZS's Start choice for Departures, the collection and the Atlas for the Book and the postcards, and PL's legends for the Hitchhiker.

**Prerequisites.** PL has landed: its plan (#80), its PRs (#81–#83, #86–#91, #96, #98) and its docs (#100). So `main`, at f491e55, has the picks, `SaveData.seen_disasters()` and the 15 legends that EG's unlock, Book and Hitchhiker use, and EG's PRs stack on it (§4.2). M7 hasn't started; §9 has notes for it. No repository settings change.

Contents:
1. Goal and exit criteria
2. Review findings
3. Decisions and open questions
4. Work breakdown (14 PRs)
5. Design
6. Verification
7. Owner actions
8. Risks
9. Notes for later work

---

## 1. Goal and exit criteria

Goal: the player has a goal, and the game an end. Drive the whole road, from the City to the pier on the Coast, in one run, and fill the Book of Legends. An arrival is a win: it shows the run's time, and unlocks a legend that the player hasn't collected; the first one unlocks the Road Home, the road's mirror, which starts heading W. Each legend met or unlocked fills a page of the book, and a full book brings the Hitchhiker. Nothing changes on a road without a finish (E6), and nothing kept in the save makes a run easier or harder (`plan.md` §2.6), while the pit stops repair the car in every run alike (Q10).

| # | Exit criterion | Checked by |
|---|---|---|
| E1 | The road's end (W1, W4). A schedule with a finish ends its road. Once the car has entered the last area and `finish_turn` turns are behind, counted from the City's first turn after the tutorial, the straight after the last junction leads to `FINISH_TILES` path tiles of the finish's set piece, then to `BEYOND` tiles, which no car reaches. No junction comes after the last, and a finish due by the tutorial's end comes right after it, where the City's first junction would be. The finish draws nothing from the road's stream, so up to and including the last junction the road is `endless()`'s, tile for tile, and up to the finish without a home stretch, which is its own area's from the next tile. `validate()` reports a finish before the last area, and a `finish_turn` without a finish | `test_road_generator_finish.gd`: `test_the_road_ends_at_the_finish_after_its_last_turn`, `test_a_last_area_at_the_finish_turn_is_a_home_stretch`, `test_the_finish_counts_its_turns_from_the_end_of_the_tutorial`, `test_a_finish_due_by_the_end_of_the_tutorial_comes_right_after_it`, `test_the_road_before_the_finish_is_the_endless_roads`, which PR 3 extends to the game's road and its home stretch; `test_area_schedule.gd`: `test_validate_reports_a_finish_that_cannot_be_reached`, `test_a_road_can_end_early_or_never_and_keep_its_areas`, `test_a_road_that_starts_in_a_later_area_ends_as_many_turns_sooner`; `tests/sim/test_drive_to_the_end.gd`: `test_the_autopilot_drives_to_the_pier`, five seeds to turn 280 |
| E2 | The arrival (W2, W5). The car arrives as it drives onto the finish's first tile, or comes back onto the road on a tile of it, with every junction behind it taken; never off the road, after a mistake or in the tutorial. It then rolls to a stop on the finish, steering onto its centreline, `ARRIVE_STOP_SHORT` before the centre of its last tile, from any speed up to the cap, or sooner, within `ARRIVE_ROLL_SECONDS`, if it came slowly. However it came onto the finish, at an angle or across it after a rejoin, it stops on it, within the road's edges and the finish's ends. The run ends in `GameState.State.ARRIVED`, not a crash, and then shows its end screen in `GAME_OVER`, as the others do | `test_junction_trigger.gd`: `test_the_car_arrives_as_it_enters_the_finish_after_the_last_turn`, `test_the_car_arrives_as_it_rejoins_the_road_on_the_finish`, `test_no_arrival_off_the_road_or_after_a_disaster`; `test_car_sim_arrival.gd`: `test_the_car_arrives_and_rolls_to_a_stop_on_the_finish`, `test_the_car_stops_on_the_finish_from_the_speed_cap`, `test_a_slow_car_stops_on_the_finish_within_arrive_roll_seconds`, `test_the_car_stops_on_the_finish_however_it_comes_onto_it`; `test_game_state.gd`: `test_an_arrival_ends_the_run_and_its_end_screen_follows` |
| E3 | The arrival's sequence and end screen (W8, W11, W15, W20). The director plays no disaster: it waits `ARRIVAL_SECONDS`, 5.0, while the car rolls to a stop, and finishes before `DISASTER_TIMEOUT`. The end screen says "You reached the end of the road!", with the run's distance, turns and area, its time as m:ss, and the legend it unlocked. The run's clock counts from its start, or the tutorial's end, and stops while the run pauses. The autopilot's run may end in an arrival | `test_disaster_director.gd`: `test_an_arrival_ends_after_arrival_seconds_with_no_disaster`; `test_game_over.gd`: `test_the_time_is_in_minutes_and_seconds`; `tests/integration/test_arrival.gd`: `test_the_autopilot_reaches_the_finish_and_unlocks_a_legend`, `test_the_runs_clock_stops_while_it_pauses`, `test_an_area_without_a_junction_has_every_turn_behind_it` |
| E4 | Records and the save's version 3 (W3, W7, W16, Q4). A run that drove the whole road, from the route's first area, records its arrival under the finish's id at once: one more arrival, the least time, and whether one never left the road outside the tutorial, a clean run. A run from a later area (W7) arrives, but records no arrival and unlocks nothing. A version 2 file loads with no arrivals and nothing unlocked | `test_save_data.gd`: `test_a_v2_file_is_migrated_with_no_arrivals_and_nothing_unlocked`, `test_record_arrival_counts_and_keeps_the_best_time_and_a_clean_one`, `test_json_round_trip`, `test_every_older_version_has_a_migration`; `test_arrival.gd`: `test_a_run_from_a_later_area_arrives_but_counts_nothing`, `test_leaving_the_road_spoils_a_clean_run` |
| E5 | The unlock (the owner's answer; Q2, W14). An arrival that counts unlocks one legend of the road's pools that the player hasn't collected, neither seen nor unlocked, each as likely as the others, on the stream `hash("<seed>:unlock")`, so the same seed and collection unlock the same legend. The end screen names it: "A new legend for your book: <name>". With every legend of the pools collected, it unlocks none, and says "Every area's legends are in your book." (**Δ** PR 13). The Book shows an unlocked legend's page, "Unlocked by an arrival", until a run meets it (PR 6); PL's picks weigh it as seen | `test_legend_unlock.gd`: `test_the_locked_legends_are_those_not_collected_in_the_collections_order`, `test_each_locked_legend_is_as_likely_as_the_others`, `test_the_same_seed_and_collection_unlock_the_same_legend`, `test_with_every_legend_collected_none_is_unlocked`, `test_the_arrival_screen_names_the_unlocked_legend`, `test_every_legend_of_the_game_can_be_unlocked`; `test_save_data.gd`: `test_an_unlocked_disaster_is_collected_as_if_seen`; `test_book_screen.gd`: `test_an_unlocked_legend_shows_until_it_is_seen`; `test_arrival.gd`: `test_the_autopilot_reaches_the_finish_and_unlocks_a_legend`, `test_with_every_legend_collected_the_book_is_full` |
| E6 | Nothing changes without a finish (W6, W17). On a schedule without one, the generator lays `main`'s road and draws the same numbers, so the golden digests and the determinism tests pass unchanged. `endless()`, a copy without the finish and without a home stretch, is the road of Keep Driving and of every test that drives past turn 280. On PRs 1–2, `smoke.sh` prints `main`'s line, `autopilot: tile 165, turns 35, area rural`; PR 3 ends the game's road after turn 280, which the smoke run never reaches | `test_road_generator_finish.gd`: `test_a_road_without_a_finish_never_ends`; `test_area_schedule.gd`: `test_an_endless_road_leaves_out_the_home_stretch`; the golden and determinism tests of `main`, unchanged; §6.1 |
| E7 | The Coast and the arrival's scene (PRs 3, 4; Q1, Q17, W18, W19). The game's road ends after its 280th turn. The Coast, an area of long straights with no junction and no legend, starts at that turn, and its straight leads to the pier. Its art, props, music and ambience come from scripts, as every area's do. The pier draws as a pier, and `BEYOND` as the sea; `WorldRenderer.build()` checks that the finish has a scene. On the arrival, the sun sets over the sea, a still of each legend collected stands over the sea past the pier's end, in the Book's grid (**Δ** PR 4), the view holds them and the car, and a jingle plays, within `ARRIVAL_SECONDS` (PR 4) | PR 3: `test_area_schedule.gd`: `test_the_games_road_ends_at_the_pier_after_its_280th_turn`; `test_world_renderer.gd`: `test_the_finish_draws_its_set_piece_and_nothing_beyond_it`; `test_drive_to_the_end.gd` on the game's own road; `test_area_art.gd`, `test_audio_director.gd` and `test_prop_layout.gd`, which check every area of the game's road, with the Coast. PR 4: `test_arrival_scene.gd`, `test_legend_still.gd` |
| E8 | NEW LEGEND! and the Book (PRs 5, 6; Q8, Q16). The end screen of a run that met a legend for the first time, or unlocked one, shows NEW LEGEND!, with a jingle, and gives the next goal in one line. The collection becomes the Book: a grid with an area a row and a pool's slot a column, "Legends n/N", a still of each legend found, its silhouette and its name's initials, such as "P______ B__", for each not found, and a seal on each area whose legends are all found. It reads the pools, whatever their size | PR 5: `test_game_over.gd`: `test_a_first_sighting_or_an_unlock_shows_new_legend`, `test_the_next_goal_is_one_line_of_the_fonts_glyphs`. PR 6: `test_book_screen.gd` |
| E9 | The Road Home (the owner's answer; W9, W10, Q12). The Road Home is the road's mirror: it starts in the Desert heading W, its first turn is a right, its areas come in reverse with the same lengths and set pieces, and it ends at home after 280 turns. It has no tutorial. The first arrival unlocks it on the title (PR 8); its arrivals count under `home`, and unlock legends too. From PR 8, the save keeps each road's farthest turn, so a Road Home run that never arrives keeps its progress | `test_road_generator_finish.gd`: `test_a_mirrored_road_starts_west_and_turns_right_first`, `test_a_mirrored_road_has_no_tutorial`, `test_the_road_home_ends_at_home_after_280_turns`; `test_area_schedule.gd`: `test_the_road_home_is_valid_and_runs_the_other_way`; `test_arrival.gd`: `test_the_road_home_starts_west_and_ends_at_home`, `test_the_road_home_has_no_tutorial`; `test_drive_to_the_end.gd`: `test_the_autopilot_drives_the_road_home`. PR 8: `test_title.gd`: `test_the_road_home_is_offered_after_the_first_arrival`; `test_save_data.gd`: `test_a_v3_file_is_migrated_with_each_roads_farthest`, `test_a_road_home_run_that_never_arrives_keeps_its_farthest` |
| E10 | Departures (PR 7; Q11, W22). In every build, the title offers a start from each area discovered. Such a run counts no arrival, no unlock and no overall best; the legends that it meets, its areas' bests and its discoveries count | PR 7: `test_title.gd`: `test_departures_offer_only_the_areas_discovered`; `test_save_data.gd`: `test_a_departure_keeps_the_overall_best` |
| E11 | Keep Driving (PR 9, Q13). After the first arrival, the title offers the endless road, `endless()`, on which the Desert goes on as on `main`; its runs count as on `main` | PR 9: `test_title.gd`: `test_keep_driving_is_the_endless_road_after_the_first_arrival` |
| E12 | The route strip (PR 10, Q14). The HUD shows the road's areas as ticks on a strip, the car's place on it and the best run's mark, in shapes, not only colours, and nothing on it flashes | PR 10: `test_hud.gd`: `test_the_route_strip_marks_each_area_the_car_and_the_best` |
| E13 | Pit stops (PR 11; Q10, W24). The tunnel, the bridge and Last Gas, a filling station where the Desert starts, each repair the car by `PIT_STOP_HEAL`, once per run each | PR 11: `test_car_sim_pit_stop.gd` |
| E14 | Records and postcards (PR 12, Q15). The Atlas's cards become postcards, each stamped by a clean crossing of its area; the title and the end screen show the arrivals, the best time and a clean arrival; the save's version 5 | PR 12: `test_save_data.gd`, `test_atlas_screen.gd` |
| E15 | The Hitchhiker (PR 13, Q9). With every legend of the pools collected, the Road Home shows her on its far side, by the last plain straight before the junction of the player's farthest turn there, or before the finish once they have arrived home. Passing her, in a run that goes on, finds her, the Book's 16th page, and she fades away. An arrival never unlocks her | PR 13: `test_hitchhiker.gd`, `test_hitchhiker_run.gd`, `test_book_screen.gd` |
| E16 | Manual, on the Web in Chrome and Firefox and on both of the Fold4's screens: the arrival reads as a win without words, the car stops on the pier on screen, NEW LEGEND!, the Book and the strip read at 360 × 640, and nothing flashes | §6.4, on PRs 3–6, 8, 10 and 13 |
| E17 | Docs: each PR's Δs as it lands, then PR 14's `docs/ENDGAME.md` (Q18, §5.18) | Review |
| E18 | All four required checks are green on each PR, with §4's counts, and `smoke.sh` prints no error line. Each negative case makes the tests it names fail (§6.2), and the warnings check finds no new warning (§6.3) | PR checks; §6.2 and §6.3, run locally with Godot 4.7.2 on each PR's head |

---

## 2. Review findings

The prototype checked each finding below that has a fix in PRs 1–2, and P5 the one that PR 3 fixes in the tests (W6).

- **High:** the game misleads the player, or breaks.
- **Medium:** fragile, or missing from the tests.
- **Low:** clarity or polish.

Line numbers are at 532908a, the head of PL's PR 1 (#81), from which the prototype was made, unless they say otherwise.

### High

| # | Finding | Evidence | Fix |
|---|---|---|---|
| W1 | The game has no end, and so no win: every run ends in a mistake, and its only goal is to last longer than the one before | `area_schedule.gd`:3, "The last area continues forever."; `car_sim.gd`:23–26, the four end causes, each a mistake; `plan.md`:13, "An isometric pixel-art endless driving roguelike", and §2.5 (:57–61), whose table has disasters and crashes only | **Δ plan.md §1 (:13), §2.5, §3.6 (:121):** a finish ends the road (§5.1), and the car arrives on it (§5.2). Prototype (E1, E2) |
| W2 | An arrival would end as a crash | `GameState.end_run()` gives every cause but a wrong or missed turn `State.CRASH` (`game_state.gd`:84–86) | **Δ plan.md §7.3 (:295):** `State.ARRIVED`, entered from RUNNING, which leads to GAME_OVER or TITLE, as DISASTER and CRASH do. Prototype (E2, N17) |
| W6 | Once the game's road ends at turn 280, each test that drives it further fails, and four never stop | Ten tests drive the game's road to turn 300 or more: `test_autopilot_300_turns.gd`:17, `test_area_schedule.gd`:213, `test_junction_trigger.gd`:229, `test_road_generator_determinism.gd`:59, `test_road_generator_occupancy.gd`:65 and `test_road_generator_pattern.gd`:11, whose road five share; three of PR 1's take it for a road without a finish. `Fixtures.path_until_turn()` loops until `turn_count` reaches its target (`road_fixtures.gd`:103–107), which a finished road's never does: in P5, one test took 6.7 GB, and the OOM killer ended the run | PR 3: `Fixtures.endless()`, the game's road without its finish, `main`'s (E6), for those 13 tests; and `path_until_turn()` errors and stops at a finish. With both, every test passed in P5 (§6.5) |
| W9 | The Road Home can't just flip the pattern | The road starts heading N (`road_generator.gd`:49), and turn n goes left when n is even (`heading.gd`:27–28), so the path is a staircase of N and W (`plan.md` §3.2, :86; `heading.gd`:2, "The correct path only heads N or W"). On screen, N goes up and right and W up and left (`iso.gd`:17), so the road climbs the portrait screen. Flipped from N, the first turn is a right, to E, which goes down and right: the road would run across the screen, not up it | **Δ plan.md §3.2:** a mirrored road starts heading W, so its first turn, a right, heads N, and the staircase is N and W again (approved by the owner). Prototype (E9, N2) |

### Medium

| # | Finding | Evidence | Fix |
|---|---|---|---|
| W3 | The save has no room for arrivals or unlocks | `SaveData.VERSION` is 2 (`save_data.gd`:13), with migrations from versions 0 and 1 (:53); `_entry()` gives a stored entry the defaults of the keys it lacks (:219) | **Δ plan.md §9:** version 3 adds `arrivals` and each disaster's `unlocked`; `_v2_to_v3()` changes nothing, as `_entry()` fills both in. Prototype (E4, N13, N14) |
| W4 | The finish must count its turns from the tutorial's end | The tutorial lasts as many turns as the player needs, and `end_tutorial(turn_base)` counts the schedule's turns from the City's first turn after it (`road_generator.gd`:78–82; docs/TUTORIAL.md §5.5) | The finish counts from `_turn_base`, as the areas do, and a finish already due as the tutorial's last group of junctions ends comes right after it (§4.4 #2). Prototype (E1, N22, N30) |
| W5 | The car would stop on the pier as it does in a crash | After a crash, the car stops in `STOP_SECONDS`, 0.6 (`tuning.gd`:131): in about 0.3·v tiles, 1.7 at 5.8 tiles/s. The prototype's first sequence, 2.5 s long, showed its screen while the car still rolled | The car brakes evenly, to stop `ARRIVE_STOP_SHORT` before the centre of the finish's last tile, or within `ARRIVE_ROLL_SECONDS` if it came slowly, and steers onto the finish's centreline, which holds it however it came onto the finish (§5.2, §4.4 #1). P4: 2.40–4.02 s from 2.98–5.79 tiles/s. Prototype (E2, N6, N7, N28, N29) |
| W7 | A run from a later area would count | `starting_at()` keeps the finish, counted from the road's first area (§5.1), so a run from the Desert arrives 60 turns later. `--area` starts there, and so does, in debug builds, the title's Start choice (docs/ZONE_SELECT.md Z4); Departures would in every build (E10) | Only a run that drove the whole road counts: `_drove_whole_road()`, from the road's first area (Q4). Prototype (E4, N10) |
| W8 | The autopilot's run errors as it ends | `_on_run_ended()` errors on any end of the autopilot's run (`main.gd`:304–305), so `smoke.sh` and the tests that drive the autopilot to the end would fail | No error on an arrival. Prototype (E3, N19) |
| W10 | The tutorial's loops are laid for a road heading N | `road_generator.gd`:205–222 lays them E and N | A mirrored road has no tutorial: `_tutorial_wanted()` is false for it, and a mirrored generator asked for one errors and lays none. Prototype (E9, N16) |
| W11 | Nothing counts the turns on the home stretch | `_turns_before()` gives the turn number of the next junction (`main.gd`:277–286), and errors when there is none (:285), as after the last one | On a finished road, every turn is behind the car: `turn_count`. Prototype (E3, N25) |
| W14 | A legend unlocked could be unlocked again, and the picks would weigh it as new | `seen_disasters()` lists the disasters with `seen` above 0 (`save_data.gd`:162–169), for the collection and the picks (docs/POOLS.md Q2, Q3) | `seen_disasters()` lists the unlocked ones too, as collected: never unlocked again, and weighed as seen (Q3). Prototype (E5, N11) |
| W17 | A home stretch would go on forever on an endless road | The Coast has no junction, and its pool is empty (Q1): last on an endless road, it would be one straight forever. A run that asked its pool for a disaster would error (`disaster_director.gd`:133–135, `disaster_picks.gd`:69–70) | `endless()` leaves out a last area that starts at the finish, the home stretch, so the one before it goes on, as on `main`. Prototype (E6, N24) |
| W18 | The pier, and what lies beyond it, would draw as road | `GreyboxAtlas.road_coords()` draws each set piece but the tunnel and the bridge as road (`greybox_atlas.gd`:30–38). `WorldRenderer.build()` checks only the areas' set pieces for a scene (`world_renderer.gd`:86–88), and a set piece with none adds nothing (:166–169) | PR 3: the pier's scene and rows, the sea for `BEYOND`, and `build()` checks the finish's scene (E7) |
| W19 | The tests that list the game's areas, or loop over them, would fail on the Coast, or leave it out | `test_area_schedule.gd`:62 and :70–84 and `test_disasters.gd`:35 and :63 want five areas, each with a pool; `test_disaster_pools.gd`:63–69 makes a wrong turn in each, and the Coast has no junction; `test_prop_art.gd`:8, `test_shadows.gd`:8 and `test_title_screen.gd`:180 list the five; `test_world_renderer.gd`:393 lists the set pieces' scenes | PR 3: the tests of the pools and of wrong turns loop over `endless()`'s areas; the lists gain the Coast, and the scenes the pier and home (E7) |
| W22 | A departure would set the overall best | `record_run()` (`save_data.gd`:138) keeps each area's bests (:144–145), then the overall ones, from any run (:147–148). Debug starts already do (docs/ZONE_SELECT.md Z5); Departures would, in every build | PR 7: a run that didn't drive the whole road keeps its areas' bests, not the overall ones (E10) |
| W26 | The Book's silhouettes and the seals not earned yet hardly stand out | A silhouette multiplied its still by `SILHOUETTE`, Color(0.1, 0.1, 0.12), as the collection's swatch was: its texels had a contrast of 1.36:1 to 1.63:1 with its cell's ground, the theme's disabled style, and a seal not earned yet 1.05:1 with the title's background, where WCAG 2.2 1.4.11 asks 3:1 of a shape that must be made out. No colour darker than the cell reaches 3:1 with it: black has 1.63:1. Found in Copilot's review of PR 6. In the lighter grey, a seal not earned yet looked like the City's earned one, Color(0.55, 0.58, 0.63), with 1.28:1 between them and much the same hue; each area's colour has 1.27:1 to 2.70:1 with it. Found in E16's frames of PR 6. A glow's silhouette, the Will-o'-the-Wisp's or the Marfa Lights', kept its still's alpha, which falls to nothing at its edge: in a frame of the Book, 2,976 of the 2,992 pixels that it drew had less than 3:1 with the cell. Found in Copilot's next review | PR 6: a silhouette draws its still's shape flat (`ui/silhouette.gdshader`), and `SILHOUETTE` is a lighter grey, Color(0.5, 0.5, 0.55): 3.28:1 with the cell, 4.68:1 with the title's background (§5.10; N148, N149). A seal not earned yet is hollow, its star's outline in that grey, and an earned one whole, so that they differ by their shapes too (N152, N153, N155). Each texel that a silhouette's still covers at all is drawn whole, so that a glow's is a disc of 3,096 pixels, all in that grey (N154, in a frame: GUT draws nothing) |

### Low

| # | Finding | Evidence | Fix |
|---|---|---|---|
| W12 | A test compares a whole disaster entry | `test_wrong_turn_disaster.gd`:111–114 | It has `"unlocked": false`. Prototype |
| W13 | Two tests compare the whole stats | `test_game_state.gd`: `test_start_run_resets_the_stats` (:25) and `test_end_run_emits_the_cause_and_stats` (:73) | They have `seconds` and `clean`. Prototype |
| W15 | The end screen has no words for an arrival | `END_MESSAGES` has the four causes (`game_over.gd`:16–21), and any other shows "Game over" | `CarSim.ARRIVAL`: "You reached the end of the road!". Prototype (E3) |
| W16 | Two tests use version 3 as a newer save's | `test_save_data.gd`:70 and :205 | They use 4; PR 8, whose save is version 4, makes them 5, and PR 12's version 5 makes them 6. Prototype |
| W20 | The arrival's sequence must outlast the roll, and end before the director's timeout | The roll lasts up to `ARRIVE_ROLL_SECONDS`, 4.0, to within a 60 Hz step, and P4 measured 2.40–4.02 s; the director errors after `DISASTER_TIMEOUT`, 6.0 (`tuning.gd`:136, `disaster_director.gd`:116) | `ARRIVAL_SECONDS`, 5.0, between them (Q17), which `test_car_sim_arrival.gd` checks. Prototype (E3, N18) |
| W21 | A `--finish` run from the City counts | The debug flag `--finish=<turns>` ends the road early; a run with it from the City records an arrival, and unlocks a legend | None: a debug build's save is the tester's own (docs/ZONE_SELECT.md Z5) |
| W23 | IP lists what uses the RNG | IP §5.3 (:231) names the road's streams, the disaster stream and the picks' | **Δ IP §5.3:** and the unlock's, `hash("<seed>:unlock")` (§5.5). PR 2 |
| W24 | The pit stops change a rule | `plan.md` §2.4 (:55): "There are **no pickups** in the MVP (no health, fuel or score pickups), and health does not regenerate."; §13 (:422), "Pickups: None in the MVP" | **Δ plan.md §2.4, §13**, in PR 11, if the owner agrees (Q10) |
| W25 | Exported builds break a label's lines only at spaces | The text server breaks lines by Unicode's rules (UAX #14), from ICU data that the editor has built in but that an export carries only with `internationalization/locale/include_text_server_data`, about 4 MB, which `project.godot` doesn't set. Without it, a label cuts a word too wide where it overflows: PR 6's Web build showed the Book's "Will-o'-the-Wisp", 102 px in a cell's 88, as "Will-o'-the-Wi" over "sp", in Chrome and Firefox, where the editor breaks it after "the-" | `BookCell.break_hyphens()` breaks such a word after its last hyphen that fits (§5.10), rather than every build carrying the 4 MB. PR 6 (N138, N139) |
| W27 | A screen reader's focus reaches neither the Book's count nor a page's words | A label takes no focus in Godot 4.7.2: `Label.focus_mode` is `FOCUS_NONE`. Tab moves the focus to a control whose mode is `FOCUS_ALL`, or `FOCUS_ACCESSIBILITY` while a screen reader is on (`Control.find_next_valid_focus()`), so a page's only stop was Back. Raised by Copilot's review of PR 6; in the desktop build under Xvfb, with `--accessibility always`, Tab left the focus on Back | PR 6: the count and each line of a page take a screen reader's focus, `FOCUS_ACCESSIBILITY`, and the page's scroll follows the focus (§5.10). With a screen reader, Tab goes from Back to the count, the name, the sightings, the fate and the lore, and back; without one, it stays on Back, as it did (N156–N158) |
| W28 | A keyboard can't scroll the Book, or a page, to what runs past the screen | Godot 4.7.2's ScrollContainer scrolls by no key, and its scroll bars take no focus (`scroll_container.cpp`:993, :1000), so their own keys never reach them. It scrolls to what has the focus, but without a screen reader neither a silhouette, which is disabled, nor a page's line takes it (W27), and an arrow that moves no focus goes on, unhandled (`viewport.cpp`:2421–2423). Nothing runs past the screen yet: the logical screen is 360 × 640 or more in any window (`window.cpp`:1339–1389), where the Book's 5 rows take 496 of the 520 pixels that its scroll has, and the longest page, the Death Worm's, 391 of as many. Run headed under Xvfb at nine window sizes, from 360 × 640 to 2316 × 904 and 904 × 2316, Down, Page Down, End and Tab moved neither the Book nor any of the 15 pages. A sixth row would run past it, and §5.10 reads the pools whatever their size. Raised by Copilot's review of PR 6 | PR 6: the keys that move no focus scroll the Book, or the page that is open: an arrow, where the focus has nowhere to go that way, by an eighth of what shows, `Tuning.BOOK_KEY_SCROLL`, as a mouse wheel's notch does (`scroll_bar.h`:116); Page Up and Page Down by all of it; Home and End to its top and its bottom. Where an arrow moves the focus, it still does, and a Book that is closed takes no key (§5.10; N159–N163) |
| W29 | The route strip can't draw with `Polygon2D` | In Godot 4.7.2, each redraw of a `Polygon2D` after its first raises WebGL errors on the Web (godotengine/godot#124726, fixed in 4.8; docs/M2.md §5.7), and the HUD's children redraw each time it shows | PR 10: `RouteStrip` draws its marks in `_draw()`, with `draw_rect()` and `draw_colored_polygon()`, and its Web check found no WebGL error. It is in the HUD, on the `UI` canvas layer, above `Daylight`'s veil, so the night doesn't darken it |
| W30 | On a 640-pixel screen, some turns climb no pixel | There the strip is 256 pixels for the road's 280 turns, where §5.14 says "a pixel or two a turn". On the phone's 800 pixels and the Fold4 cover's 922, it is 320 and 369, and each turn climbs 1 or 2 | PR 10: none. The test drives the 280 turns on each of the three, and checks that no turn climbs more than 2 pixels and that the car ends at the top |
| W31 | `make_audio.gd` had no room for PR 11's ding | It had 996 lines, and gdlint allows 1,000 (`max-file-lines`, which `.gdlintrc` leaves at its default) | PR 11: its WAV writer moved, unchanged, to `tools/audio/wav.gd`, which it preloads as `Wav`, and it has 976 lines. All 36 sounds regenerate byte for byte |
| W32 | `GameState` can't tell a crossing on its own | §5.16 has it set `crossed` "as the car crosses onto the next area's first tile on the road, where the trigger judges it". But `area_changed`, its only news of an area, comes before the move's road checks (§5.15), and fires off the road too, on any tile of the new area | PR 12: `CarSim.area_crossed`, after the trigger has judged the crossing, only on the road and only from the area's last path tile onto the next's first |
| W33 | The Atlas runs past the screen | At 360 × 640 its scroll shows 472 pixels, and the six postcards take 1,130. PR 11's cards took 548 already, so the Coast's was all but 2 of its 78 pixels below: `test_every_screen_fits_a_portrait_screen_with_the_longest_texts` checked each card against the window, not the scroll that clips it. Without a screen reader no card takes the focus, so no key scrolled it (W28) | PR 12: the keys that move no focus scroll it, with `BookScreen`'s key scroll moved to `MenuScreen.scroll_by_key()`, and so does a drag that starts on a postcard. It follows the focus, and opens at the first. The fit test checks that the last postcard scrolls into view |
| W34 | The Hitchhiker's place at the finish could be a dead end's | `RoadGenerator.finish_index` is -1 until the finish's first tile is laid, and so is each dead end's `path_index`, so a dead end's tile matched it | PR 13: she skips the tiles off the path, and waits until the buffer lays the finish (§5.17; N282) |

---

## 3. Decisions and open questions

Beyond the owner's two answers, each question below had a default, and the owner approved them all on 2026-11-17: "Defaults are approved" (#84). The alternatives that they declined are in this plan at 94b5007.

| # | Question | Default |
|---|---|---|
| Q1 | Where does the road end? | **After its 280th turn, at a pier. The Coast starts at that turn: a home stretch, with long straights, no junction and no legend, so the Desert stays the climax, and the run ends on a victory lap: the Coast's one long straight, then the pier (PR 3). The autopilot took 9.6–9.9 min to the end (P1)** |
| Q2 | Which legend does an arrival unlock? | **One of those not collected yet, from every area's pool, each as likely, on the run's own stream (§5.5). P3: each of five came 0.196–0.206 of the time** |
| Q3 | Does a legend unlocked come up less often? | **Yes: it is collected, so PL's picks weigh it as seen, 0.5 against 1 (W14). The card is in the book, and the run shows the legends still missing sooner** |
| Q4 | Which arrivals count? | **Only a run that drove the whole road, from its first area (W7). The others arrive, but record no arrival, unlock nothing and set no overall best** |
| Q5 | How does a failure choose its legend? | **As PL does: each area's pool, the legends collected at half (docs/POOLS.md Q2), as the owner asked in #80. B's goal, the full book, stays, and the arrival's unlock fills the pages that failures don't** |
| Q6 | Does a crash play a legend? | **No: it stays a crash (`plan.md` §2.5)** |
| Q7 | Do the legends have lore tiers? | **No: the book shows a legend's fate and lore once it is met. The souvenirs, what each legend leaves behind, are §9's** |
| Q8 | What does the book look like? | **A grid: an area a row, a pool's slot a column (★, wave A, wave B), "Legends n/N", a still of each legend found, its silhouette and its name's initials for each not found, and a seal on an area whose legends are all found. It reads the pools, so it grows as PL's legends land, and needs nothing new from them (§5.10)** |
| Q9 | What is the book's 16th page? | **The Vanishing Hitchhiker. Once every legend of the pools is collected, she stands by the Road Home at the player's best turn on it; passing her finds her. An arrival never unlocks her (§5.17)** |
| Q10 | Do pit stops repair the car? | **Yes: the tunnel, the bridge and Last Gas, a filling station as the Desert starts, and on the Road Home as the Village starts, each repair `PIT_STOP_HEAL` once per run (W24, §5.15)** |
| Q11 | Who can start from another area? | **Everyone, from each area they have discovered: Departures. Such a run counts no arrival, unlocks nothing and sets no overall best; the legends it meets, its areas' bests and its discoveries count (W22, §5.11)** |
| Q12 | When does the Road Home open? | **After the first arrival, on the title. Its arrivals count under `home`, apart from the pier's, and unlock a legend as theirs do (§5.12)** |
| Q13 | Can the player still drive forever? | **Yes, after the first arrival: Keep Driving, `endless()`, the Desert forever, whose runs count as on `main` (§5.13)** |
| Q14 | Does the HUD show the way to the end? | **A route strip: a tick for each area, the car and the best run's mark, in shapes, not only colours, and nothing flashes (§5.14)** |
| Q15 | What do the records keep? | **Save version 4: the Atlas's cards become postcards, stamped by a crossing of the area with no damage, and the title shows the arrivals, the best time and a clean arrival (§5.16)**. It is version 5, as PR 8's version 4 keeps each road's farthest turn (§4.3) |
| Q16 | Does NEW LEGEND! play a sound? | **A short jingle from `make_audio.gd`, and the words stay still: no flash (§5.9)** |
| Q17 | How long is the arrival? | **5.0 s, `ARRIVAL_SECONDS`, after the car reaches the finish, which stops within 4.0 s, `ARRIVE_ROLL_SECONDS` (W20). PR 4's scene plays in it** |
| Q18 | Where do the docs change? | **Each PR folds its own Δs, with their findings, into `plan.md`, IP and docs/ZONE_SELECT.md; PR 14 adds `docs/ENDGAME.md` and `AGENTS.md`'s W prefix, and deletes this plan** |
| Q19 | How do the PRs land? | **One stack: PRs 1–13, each targeting the branch of the one before, PR 1 PL's PR 1 (#81) until it merges; then PR 14 from `main` (§4.2)**. #81 merged first, so PR 1 targets `main` |

---

## 4. Work breakdown

Fourteen PRs after this plan's (Q19): PRs 1–13 form one stack on `main`, and PR 14, the docs, starts from `main` once PR 13 has merged (§4.2). Each leaves CI green (E18).

```
main
 ──▶ PR 1 the road's end (E1, E2, E6; W1, W4–W6, W9, W17)
 ──▶ PR 2 the arrival, its records and the unlock (E3–E5, E9; W2, W3, W7, W8, W10–W16, W20)
   │
   ▼  the game's road ends
 PR 3 the Coast and the pier ──▶ PR 4 the arrival's scene
   │
   ▼  the Book of Legends (B)
 PR 5 NEW LEGEND! and the next goal ──▶ PR 6 the Book
   │
   ▼  the title's roads
 PR 7 Departures ──▶ PR 8 the Road Home (v4) ──▶ PR 9 Keep Driving
   │
   ▼  the rest of the gamification
 PR 10 the route strip ──▶ PR 11 pit stops ──▶ PR 12 records and postcards (v5)
   ──▶ PR 13 the Hitchhiker
   │
   ▼  once PR 13 has merged, from main
 PR 14 docs
```

Why this order:
- **The end, with nothing to see (PR 1).** The generator, the schedule, the trigger and the car learn to end a road, but no road of the game has a finish yet, as `main`'s golden digests show (E6).
- **Then the win (PR 2).** The arrival ends the run, counts, and unlocks a legend, the owner's first answer. PRs 1–2 are the prototype, split where its tests split: PR 1's 23 tests need nothing of PR 2's.
- **Then the end itself (PRs 3–4).** PR 3 puts the finish on the game's road, with the place it needs: an end without a scene would read as a bug. W6's tests move to the endless road in the same PR that ends the game's. PR 4 makes the end a reward.
- **B's heart next (PRs 5–6).** Once arrivals unlock legends, the player must see what they got and what is still missing: Rosewater's goal, made visible, and the Zeigarnik pull of an unfinished set.
- **The title's roads (PRs 7–9)**, each opened by progress: Departures by discovering an area, and the Road Home and Keep Driving by the first arrival.
- **The rest (PRs 10–12)**, each small. PR 11 changes a rule of `plan.md` (W24), so it comes late and can be dropped without touching the others (Q10).
- **The Hitchhiker last (PR 13).** She is the full book's reward, the 16th page after PL's 15.
- **The docs from `main` (PR 14)**, as PL's did (docs/POOLS.md §4.4).

### 4.1 Porting from the prototype

PRs 1 and 2 split the difference between 532908a and 4d3d981 by file: PR 1 takes the 15 files in its table below, and PR 2 the other 19.

1. Fetch, and create PR 1's branch from `main`. Then apply PR 1's part of the difference, and on PR 2's branch, made from PR 1's, the rest. `main` has moved on since 532908a, in 7 of the prototype's files, so `--3way` merges its lines with the prototype's:
   ```bash
   git fetch origin main '+refs/heads/eg/*:refs/remotes/origin/eg/*'
   git switch -c eg/1-road-end origin/main
   PR1="areas/area_schedule.gd areas/schedule_home.tres car/car_sim.gd config/tuning.gd
     road/junction_trigger.gd road/road_generator.gd tests/helpers/road_fixtures.gd
     tests/unit/test_road_generator_finish.gd tests/unit/test_road_generator_finish.gd.uid
     tests/unit/test_car_sim_arrival.gd tests/unit/test_car_sim_arrival.gd.uid
     tests/unit/test_junction_trigger.gd tests/unit/test_area_schedule.gd
     tests/sim/test_drive_to_the_end.gd tests/sim/test_drive_to_the_end.gd.uid"
   git diff 532908a 4d3d981 -- $PR1 | git apply --3way --index                                # PR 1
   git diff 532908a 4d3d981 -- . $(printf ' :(exclude)%s' $PR1) | git apply --3way --index   # PR 2
   ```
   Where both changed the same lines, keep both.
2. Make the PR's docs changes, its table's Docs row, which the prototype doesn't have, and the changes of any row of §4.3 for it that the prototype doesn't have; 4d3d981 has all of §4.3's for PRs 1–2. Leave `ENDGAME_PLAN.md` alone on every PR's branch (§4.2).
3. Run §6.1's checks, §6.2's negative cases and §6.3's warnings, and compare the counts with the PR's "Expect" line.
4. Have a model of another family review it (`AGENTS.md` §5). Commit as the PR's title, with "(EG PR k)"; the prototype's commits say "prototype", and cite this plan's sections. Push, and open the PR with base `main` for PR 1 and PR 1's branch for PR 2.

### PR 1: Road: a finish ends the road, and the car arrives on it **Δ W1, W4, W5, W9, W17**

Branch `eg/1-road-end`, from `main` (§4.1).

**Built** as #101, landed as 0837412: as planned, with its expected counts (§6.1).

| Area | Files |
|---|---|
| Areas | `areas/area_schedule.gd`: `finish`, `finish_turn` and `mirrored`; `has_finish()`, `endless()` and `ending_at()`; `starting_at()` moves the finish; `validate()`'s two new checks (§5.1). `areas/schedule_home.tres`, new: the Road Home (§5.6) |
| Road | `road/road_generator.gd`: `BEYOND`, `finish_index`, `finished()`, `_finish_due()` and `_finish_tile()`, also as the tutorial ends; a mirrored road's heading and parity (§5.1, §5.6). `road/junction_trigger.gd`: `arrived`, `has_arrived`, `_is_finish()`, and no junction after the last (§5.2) |
| Car | `car/car_sim.gd`: `State.ARRIVED`, `ARRIVAL`, `arrived`, and the roll to a stop on the finish's centreline, which holds the car (§5.2) |
| Config | `config/tuning.gd`, whole: `FINISH_TILES`, `ARRIVE_STOP_SHORT`, `ARRIVE_ROLL_SECONDS` and `ARRIVAL_SECONDS`, which `test_car_sim_arrival.gd` checks against `ARRIVE_ROLL_SECONDS` (W20) |
| Tests | `tests/unit/test_road_generator_finish.gd`, new: 9 tests (E1, E6, E9). `tests/unit/test_car_sim_arrival.gd`, new: 4 (E2, W20). `tests/sim/test_drive_to_the_end.gd`, new: 2, the autopilot to the pier and home on five seeds (E1, E9). `tests/unit/test_junction_trigger.gd`: 3 (E2). `tests/unit/test_area_schedule.gd`: 5 (E1, E6, E9). `tests/helpers/road_fixtures.gd`: `schedule_home()` |
| Docs | `plan.md` §3.2 (:86): a mirrored road (W9) |

15 files, +788 −9, and the docs. Expect 3 more scripts loaded than its base, 3 more test scripts, 23 more tests and 12,968 more asserts, as on 532908a: on `main` at f491e55, `check_scripts: loaded 198 scripts`; `GUT: 726 tests passed`, in 93 test scripts (450,611 asserts; 114.3 s locally); `autopilot: tile 165, turns 35, area rural`, as on `main`. Negative cases N1–N7, N15, N22–N24, N28–N30.

**Acceptance:** E1, E2's road and car part, E6, E9's generator part, E18.

### PR 2: Game: an arrival ends the run, counts, and unlocks a legend **Δ W2, W3, W7, W8, W10–W16, W20, W23**

Branch `eg/2-arrival`, from `eg/1-road-end` (§4.1).

**Built** as #102, landed as 6193277: as planned, and `seen_disasters()`'s comment cites docs/POOLS.md too.

| Area | Files |
|---|---|
| Autoload | `autoload/game_state.gd`: `State.ARRIVED`, `seconds` and `clean` (§5.3). `autoload/save_data.gd`: version 3, `arrivals`, each disaster's `unlocked`, `record_arrival()`, `unlock_disaster()` and `arrival_count(finish)`; `seen_disasters()` lists the unlocked (§5.4, W14). `autoload/save_service.gd`: `record_arrival()`, which saves at once |
| Disasters | `disasters/legend_unlock.gd`, new, and its `.uid`: `LegendUnlock` (§5.5). `disasters/disaster_director.gd`: `Sequence.ARRIVAL` and `play_arrival()` (§5.3) |
| UI | `ui/main.gd`: `_on_arrived()`, `_drove_whole_road()`, the run's clock, a clean run, `--finish` and `--home`, and no tutorial on a mirrored road (§5.3–§5.7). `ui/game_over.gd`: the arrival's words and its time (W15). `ui/collection_screen.gd`: an unlocked legend's card (§5.5) |
| Docs | `plan.md` §2.1 item 7, the time; §2.5, the arrival's row (W1); §2.6 and §13 (:421), what an arrival keeps and unlocks; §7.3, `ARRIVED` (W2); §9, version 3 (W3). IP §5.3 (W23) |
| Tests | `tests/integration/test_arrival.gd`, new, and its `.uid`: 9 tests (E3–E5, E9). `tests/unit/test_legend_unlock.gd`, new, and its `.uid`: 6 (E5). `tests/unit/test_save_data.gd`: 3, and W16's two (E4). `tests/unit/test_game_state.gd`: 1, and W13's two (E2). `tests/unit/test_disaster_director.gd`, `test_game_over.gd` and `test_collection_screen.gd`: 1 each (E3, E5). `tests/integration/test_wrong_turn_disaster.gd`: W12 |

19 files, +696 −47, and the docs. Expect, over PR 1's, 3 more scripts loaded, 2 more test scripts, 22 more tests and about 173 more asserts, as on 4d3d981 (§6.1); `autopilot: tile 165, turns 35, area rural`. Negative cases N8–N14, N16–N21, N25–N27, N31, N32.

**Acceptance:** E2's game part, E3–E5, E9's game part, E18.

### PR 3: Areas: the Coast and the pier, where the game's road ends **Δ W6, W18, W19**

Branch `eg/3-coast`, from `eg/2-arrival`. §5.8 designs it.

**Built** as #103, landed as 42abda5. **Δ** The Coast has seven props, not §5.8's three: dune grass, beach huts, a lighthouse, umbrellas, driftwood, shells and rocks. `Pier.at_sea()` is a half-plane. W19 missed six lists, which gain the Coast too: `test_area_schedule.gd`:37 and :48, `test_atlas_screen.gd`:51 and :82, `test_prop_art.gd`:162 and `test_title_screen.gd`:133; and `test_greybox_atlas.gd`'s `test_road_coords` checks the pier's and `BEYOND`'s. A `--finish` past the road's own end is an error (§4.3, §5.7). `AGENTS.md`'s "endless" waits for PR 14.

| Area | Files |
|---|---|
| Areas | `areas/coast.tres`, new: the Coast, with long straights, no pool, and its art, props, music and ambience. `areas/props/coast/*.tres`, new. `areas/schedule.tres`: the Coast at turn 280, `finish = &"pier"` and `finish_turn = 280` |
| Art and sound | `tools/art/make_art.gd`, `make_props.gd` and `tools/audio/make_audio.gd`: the Coast's, as each area's (`assets/palette.gpl` gains the sea's colours if it lacks them); their output: `assets/coast/{road,ground,edge}.png`, its props' sheets and `assets/audio/{music,ambient}/coast.wav`, with their `.import` files |
| Set pieces | `setpieces/pier.gd` and `.tscn`, new: the deck, its piles and railings, and the sea around and beyond its end, with waves. `setpieces/home.gd` and `.tscn`, new: the Road Home's end, a house and its gate. `world/world.tscn`: both scenes |
| World | `world/greybox_atlas.gd`: `road_coords()` draws the pier's tiles in the bridge's row, and gives `BEYOND` no tile. `world/world_renderer.gd`: `build()` checks the finish's scene. `world/prop_scatter.gd`: no props on a row past the finish's first tile, which the sea covers |
| Tests | `tests/helpers/road_fixtures.gd`: `endless()`; `path_until_turn()` errors and stops at a finish (W6). W6's 13 tests drive `Fixtures.endless()`. W19's seven. `tests/unit/test_pier.gd`, new, as `test_bridge.gd`: the deck on the finish's tiles and the sea under and beyond it, and home's house (E7). `tests/unit/test_world_renderer.gd`: `test_the_finish_draws_its_set_piece_and_nothing_beyond_it`, `test_every_finish_has_its_scene`. `tests/unit/test_area_schedule.gd`: `test_the_games_road_ends_at_the_pier_after_its_280th_turn`. `tests/unit/test_prop_scatter.gd`: `test_no_prop_stands_on_the_sea`. `tests/unit/test_road_generator_finish.gd`: `test_the_road_before_the_finish_is_the_endless_roads` also lays the game's road, with its home stretch (E1). `tests/sim/test_drive_to_the_end.gd`: the game's own road |
| Docs | `plan.md`'s vision (:13), §3.6's table (:121), §11 (:381), §13 (:419) and §14 (:434): the game's road ends at the pier (W1) |

Expect: PR 2's counts, with PR 3's new scripts and tests; `autopilot: tile 165, turns 35, area rural`, as the smoke run stops long before turn 280.

**Acceptance:** E6, E7's PR 3 part, E16 for the pier, E18.

### PR 4: The arrival's scene: the sunset, the legends on the shore, and a jingle

Branch `eg/4-arrival-scene`, from `eg/3-coast`. §5.8 designs it.

**Built** as #104, open and `needs-owner` for its two Δs (§5.8): the stills stand over the sea past the pier's end, in the Book's grid, as the shore, about 448 pixels across, can't show whole in a view 360 wide (E7); and the arrival zooms out to 1 where its welcome, 338 pixels high, doesn't fit zoom 2's 320, as in a landscape window or on the Fold4's inner screen. `Pier.welcome(schedule, collected)` and `welcome_bounds`, `CameraRig.arrive()`, `arrival_zoom_for()` and `end_arrival()`, `WorldRenderer.set_piece_at()` and `LegendStill.strength()` (§4.3) are new, with eight more constants in `tuning.gd` (IP D11). A frame under `STILL_MIN_SIDE`, 30 pixels, is scaled up by a whole number, the Fairy Ring's by 3, and an hour that isn't finite is an error to `hold()`.

| Area | Files |
|---|---|
| World | `world/day_cycle.gd`: `hold(hour)`: the clock stands at `hour`, and the light follows at `LIGHT_MAX_RATE`; `enter()` clears the hold, so the next run's clock runs. `setpieces/pier.gd`: `welcome(legends)`, the stills of the legends collected, which fade in along the shore. `world/camera_rig.gd`: the arrival's view (§5.8), the target easing at `ARRIVAL_PAN_RATE` |
| Disasters | `disasters/legend.gd`: `figure`, the sprite that is the legend, and `figure_frame`, which each of the 15 legends' scenes sets |
| UI | `ui/main.gd`: on an arrival, the hold at `ARRIVAL_HOUR`, the welcome, and the view. `_physics_process()` advances the cycle in `ARRIVED` too (§5.8). `ui/legend_still.gd`, new: `LegendStill`, a legend's still (§5.8), which PR 6's Book reuses |
| Audio | `autoload/audio_director.gd`: on an arrival, the engine winds down with the car and stops with it, the music fades, and `arrival.wav` plays; no crash. `tools/audio/make_audio.gd`: the jingle; `assets/audio/sfx/arrival.wav` |
| Config | `config/tuning.gd`: `ARRIVAL_HOUR`, 18.5, the key of `LIGHT_DUSK`; `ARRIVAL_PAN_RATE` |
| Docs | docs/DAYNIGHT.md §5.4: on an arrival, the clock stands at `ARRIVAL_HOUR` and the light goes on toward it, where at a game over it stops |
| Tests | `tests/integration/test_arrival_scene.gd`, new, through the main scene's `_physics_process()`, not `DayCycle` alone: the light reaches dusk within `ARRIVAL_SECONDS`, never faster than the rate, and the next run's clock runs from its own hour; each collected legend's still is in the 360 × 640 view as the car stops, and none of a legend not collected. `tests/unit/test_legend_still.gd`, new: for each legend of every area's pool, the still is its figure's whole frame, with pixels of alpha over 0.5, whatever its rest pose hides. `tests/unit/test_audio_director.gd`: `test_an_arrival_winds_the_engine_down_and_plays_its_jingle` |

**Acceptance:** E7's PR 4 part, E16 for the scene, E18.

### PR 5: End screen: NEW LEGEND! and the next goal

Branch `eg/5-new-legend`, from `eg/4-arrival-scene`. §5.9 designs it.

**Built** as #105, open: as planned, with `GOAL_LAST_LEGEND`, "Next: find the last legend still missing", and the signal `EventBus.new_legend_shown`; three more tests cover a sighting, a legend collected before the run, and a retry.

| Area | Files |
|---|---|
| UI | `ui/game_over.gd` and `.tscn`: NEW LEGEND!, still, above the fate, for a run that met a legend for the first time or unlocked one; `next_goal()` and its line. `ui/main.gd`: the run's new legends, those it met or unlocked that weren't in the collection at its start, which PL's picks already keep (docs/POOLS.md V2) |
| Audio | `autoload/audio_director.gd`: the jingle, once, as the end screen shows NEW LEGEND!. `tools/audio/make_audio.gd`; `assets/audio/sfx/new_legend.wav` |
| Tests | `tests/unit/test_game_over.gd`: `test_a_first_sighting_or_an_unlock_shows_new_legend`, `test_the_next_goal_follows_the_players_progress`, `test_the_next_goal_is_one_line_of_the_fonts_glyphs`. `tests/integration/test_arrival.gd`: `test_an_arrival_that_unlocks_shows_new_legend`. `tests/unit/test_audio_director.gd`: `test_new_legend_plays_its_jingle_once` |

**Acceptance:** E8's PR 5 part, E16 for the screen, E18.

### PR 6: The Book of Legends

Branch `eg/6-book`, from `eg/5-new-legend`. §5.10 designs it.

**Built** as #106, open and `needs-owner` until the owner chooses whether its rows get visible labels ([the options](https://github.com/pompomon/roadgame/pull/106#issuecomment-6970573638)). A cell and a row are scenes of their own, `BookCell`, with `break_hyphens()`, and `BookRow`, and a silhouette is `ui/silhouette.gdshader`'s flat grey. **Δ** A legend's page replaces the grid, where the plan had the collection's card, and an unlocked legend's has "Unlocked by an arrival", "Not seen yet" and its lore, but no fate. A glow's still adds no more light than its ground leaves below white (docs/M6.md S10): in a cell, the lightest centre of its styles, `BookCell.ground()`, and on a page, `BookScreen.backdrop`. The title's button keeps its label, "Disasters", `SaveService.collect()` serves `--collected`, and `MenuScreen.close_page()`, `Tuning.BOOK_SCROLL_DEADZONE` and `BOOK_KEY_SCROLL` are new. W25–W28 and most of §4.3's rows are its reviews'.

| Area | Files |
|---|---|
| UI | `ui/book_screen.gd` and `.tscn`, which replace `ui/collection_screen.gd` and `.tscn`: the grid, with PR 4's stills, and `disasters()`, as the collection's. `ui/title_screen.gd` and `.tscn`: the Disasters button opens the Book. `ui/main.gd`: `--collected` (§5.7) |
| Docs | `plan.md` §2.6's collection; docs/POOLS.md V3's collection is then the Book's |
| Tests | `tests/unit/test_book_screen.gd`, new, which takes over `test_collection_screen.gd`'s tests that still hold: a row for each area with a pool, a column for each slot, "Legends n/N", a still or a silhouette and the initials, a seal, the fit at 360 × 640, and the font's glyphs. `tests/integration/test_title.gd`: the Book from the title, with `--collected=city` the City's row sealed, and with `all` a full Book. Each other use of `CollectionScreen` or `%Collection` moves to the Book, so `git grep` finds none: `test_smoke.gd`:36–48's glyphs take the Book's words and each legend's name and lore; `test_title_screen.gd`:184–213's fit at 360 × 640 and its last card's scroll take the grid; `test_title.gd`:41 and :168; and PR 2's `test_arrival.gd`:66 and `test_legend_unlock.gd`:97 (4d3d981) |

**Acceptance:** E8's PR 6 part, E16 for the Book, E18.

### PR 7: Title: Departures, from any area discovered **Δ W22**

Branch `eg/7-departures`, from `eg/6-book`. §5.11 designs it.

**Built** as #107, open: as planned, with `TitleScreen.departures()`, but `area_choice` is `every_area`, `_drove_whole_road()` is `_drives_whole_road()`, as it's asked as the run starts, and in other builds than debug `--area` presets only a departure, though no phone can pass it (docs/M4.md P4). docs/ZONE_SELECT.md Z5 changes too, and so do `test_area_start.gd`, `test_arrival.gd` and `test_tutorial.gd`.

| Area | Files |
|---|---|
| UI | `ui/title_screen.gd`: the Start choice in every build: over the areas discovered, but a home stretch, and in debug builds over all, as now (docs/ZONE_SELECT.md Z1). `ui/main.gd`: `GameState.whole_road`, set as the run starts |
| Autoload | `autoload/game_state.gd`: `whole_road`, in `stats()`. `autoload/save_data.gd`: `record_run()` keeps the overall bests only for a whole road (W22) |
| Docs | `plan.md` §2.1 item 1 (:26) and §2.6; docs/ZONE_SELECT.md Z4 and Q2 |
| Tests | `tests/integration/test_title.gd`: `test_departures_offer_only_the_areas_discovered`. `tests/unit/test_save_data.gd`: `test_a_departure_keeps_the_overall_best`. `tests/unit/test_title_screen.gd`: the Start choice in a release build. W13's two tests, with `whole_road` |

**Acceptance:** E10, E18.

### PR 8: Title: the Road Home, after the first arrival, and each road's farthest turn

Branch `eg/8-road-home`, from `eg/7-departures`. §5.12 designs it.

**Built** as #108, open. `TitleScreen.offered_roads()`, with `roads`, `road` and `ROAD_NAMES`, reads the first road's finish. `--home` presets the Road choice, which `open()` turns back before the first arrival. A retry keeps the run's road, and a reload starts on the road to the sea. A run's turns are its `turn_index`, and stats with no `road` raise no road's `farthest`. plan.md §2.6's Atlas line changes too, and its tests are also in `test_title_screen.gd`, `test_game_over.gd`, `test_smoke.gd` and `test_arrival.gd`.

| Area | Files |
|---|---|
| UI | `ui/title_screen.gd` and `.tscn`: the Road choice, "Road: To the sea", then "Road: Home" once the pier has an arrival. `ui/main.gd`: the run's road from the title, or `--home`; Departures step through the chosen road's areas; `GameState.road` at the run's start. `ui/game_over.gd`: the next goal's Road Home line |
| Autoload | `autoload/game_state.gd`: `road`, in `stats()`. `autoload/save_data.gd`: version 4, each arrival entry's `farthest`; `_v3_to_v4()` (§5.12) |
| Docs | `plan.md` §2.1 item 1 and §2.6: the Road Home; §9: version 4 |
| Tests | `tests/integration/test_title.gd`: `test_the_road_home_is_offered_after_the_first_arrival`, `test_the_road_home_counts_under_home`. `tests/unit/test_save_data.gd`: `test_a_v3_file_is_migrated_with_each_roads_farthest`, `test_a_run_raises_only_its_roads_farthest`, `test_a_road_home_run_that_never_arrives_keeps_its_farthest`; W16's two tests use 5. `tests/unit/test_game_state.gd`: `test_the_stats_name_the_road_driven_whole`; W13's two, with `road`. `tests/unit/test_world_renderer.gd`: `test_every_finish_has_its_scene` reads both roads |

**Acceptance:** E9's title and save part, E16, E18.

### PR 9: Title: Keep Driving, the endless road

Branch `eg/9-keep-driving`, from `eg/8-road-home`. §5.13 designs it.

**Built** as #109, open: as planned; Retry drives the same road, as plan.md §2.1 now says, and `test_title_screen.gd` tests it too.

| Area | Files |
|---|---|
| UI | `ui/title_screen.gd`: "Road: Endless", the game's road's `endless()`, after the first arrival. `ui/main.gd`: its run, which counts as on `main` |
| Docs | `plan.md` §3.6: the endless road |
| Tests | `tests/integration/test_title.gd`: `test_keep_driving_is_the_endless_road_after_the_first_arrival` |

**Acceptance:** E11, E18.

### PR 10: HUD: the route strip

Branch `eg/10-route-strip`, from `eg/9-keep-driving`. §5.14 designs it.

**Built** as #110, open. The strip draws in `_draw()` (W29), and its length is rounded to whole pixels, as float32 makes the Fold4 cover's 368.79996; on a 640-pixel screen some turns climb no pixel (W30). `main.gd` gives it the road, and plan.md's scene tree has it.

| Area | Files |
|---|---|
| UI | `ui/route_strip.gd`, new: a strip up the HUD's right edge, from the road's start at its foot to the finish at its top: a tick for each area, a flag for the finish, a triangle for the car and a hollow diamond for the best run, at the road's `farthest` (PR 8). `ui/hud.gd` and `.tscn`: the strip, on a road with a finish only |
| Tests | `tests/unit/test_hud.gd`: `test_the_route_strip_marks_each_area_the_car_and_the_best`, `test_the_route_strip_shows_only_on_a_road_with_a_finish` |

**Acceptance:** E12, E16 for the strip, E18.

### PR 11: Pit stops: the tunnel, the bridge and Last Gas repair the car **Δ W24**

Branch `eg/11-pit-stops`, from `eg/10-route-strip`. §5.15 designs it. If the owner declines Q10, it is dropped, and PR 12 targets PR 10's branch.

**Built** as #111, open, as Q10's default is yes. **Δ** `validate()` checks the pit stops. A road's first area has no way in, so a Departure from the Desert has no Last Gas, nor one from the Village on the Road Home. The repair waits for the path tile after a pit stop's last, so turning back out of one repairs nothing (§4.3). `repair.wav` is its sound, and `make_audio.gd`'s WAV writer moved to `tools/audio/wav.gd` (W31). `world_renderer.gd`, `world.tscn` and `prop_layout.gd` place Last Gas, plan.md §3.6 and §3.7 change too, and its tests are also in `test_last_gas.gd`, `test_world_renderer.gd`, `test_prop_layout.gd`, `test_audio_director.gd` and `tests/integration/test_audio.gd`.

| Area | Files |
|---|---|
| Areas | `areas/area_schedule_entry.gd`: `pit_stop`, which `area_schedule.gd`'s `starting_at()` copies. `areas/schedule.tres` and `schedule_home.tres`: the pit stops |
| Road | `road/road_tile.gd`: `pit_stop`, which `road_generator.gd` sets on a pit stop's tiles (§5.15) |
| Car | `car/car_sim.gd`: the repair, once per pit stop, as the car leaves its tiles on the road |
| World | `setpieces/last_gas.gd` and `.tscn`, new: the filling station beside the road, not on it, so that the road and its digests stay as they are |
| Config | `config/tuning.gd`: `PIT_STOP_HEAL` |
| Docs | `plan.md` §2.4 (:55) and §13 (:422) |
| Tests | `tests/unit/test_car_sim_pit_stop.gd`, new: the repair, once each, on a Departure too, never above `START_HEALTH`, and none off the road, on entering the area alone, or after the run's end. `tests/unit/test_area_schedule.gd`: `test_the_games_pit_stops` |

**Acceptance:** E13, E18.

### PR 12: Records and postcards: the save's version 5

Branch `eg/12-records`, from `eg/11-pit-stops`. §5.16 designs it.

**Built** as #112, open. **Δ** `CarSim.area_crossed` tells `GameState` a crossing (W32), and `SaveData.beats_best_time()` the end screen's "New best time!". The postcards are `MenuCard`s, with `atlas_screen.tscn` and `title_screen.tscn`, and the keys and a drag scroll the Atlas (W33). Two tests' names changed (below, §4.3), the Atlas has 8 tests where the plan had 1, `test_car_sim_crossing.gd` and `tests/helpers/finger.gd` are new, and `test_game_over.gd`, `test_arrival.gd`, `test_area_start.gd` and `test_tutorial.gd` gain tests.

| Area | Files |
|---|---|
| Car | `car/car_sim.gd`: the signal `damaged`, which names the area charged (§5.16) |
| Autoload | `autoload/save_data.gd`: version 5, each atlas entry's `stamped`; `_v4_to_v5()`, which keeps each road's `farthest` (§5.16). `autoload/game_state.gd`: for each area, whether the car took damage there and whether it `crossed` it (§5.16) |
| UI | `ui/main.gd`: each `damaged` but the tutorial's. `ui/atlas_screen.gd`: a postcard for each area, stamped. `ui/title_screen.gd`: the arrivals, the best time and a clean arrival. `ui/game_over.gd`: "New best time!" |
| Tests | `tests/unit/test_save_data.gd`: `test_a_v4_file_is_migrated_with_no_stamps_and_keeps_each_roads_farthest`, with a Road Home that has a `farthest` and no arrival, `test_a_crossing_with_no_damage_stamps_the_area`, `test_an_area_crossed_with_damage_or_not_crossed_is_not_stamped`; W16's two tests use 6. `tests/unit/test_game_state.gd`: `test_an_area_is_crossed_onto_the_next_or_by_an_arrival`. `tests/unit/test_car_sim_offroad.gd`: `test_damage_across_a_border_names_each_area`. `tests/unit/test_atlas_screen.gd`: `test_a_postcards_stamp_is_whole_once_its_area_is_crossed_with_no_damage`. `tests/unit/test_title_screen.gd`: `test_the_title_shows_the_arrivals_and_the_best_time` |
| Docs | `plan.md` §9: version 5 |

**Acceptance:** E14, E18.

### PR 13: The Vanishing Hitchhiker, the book's 16th page

Branch `eg/13-hitchhiker`, from `eg/12-records`. §5.17 designs it.

**Built** as #113, `needs-owner`, as the owner lands it (§4.2). She stands on the road's far side, `HITCHHIKER_ASIDE` across, facing it, by the last plain straight, not a pit stop's, before her turn's junction, never a decoy's; with none, it is an error, and she stays hidden. A place that the buffer hasn't laid yet waits for it (W34). Found, she fades in `HITCHHIKER_FADE_SECONDS`. The Book's last row is hers once the pools are full, and the pier's welcome leaves her out.

| Area | Files |
|---|---|
| World | `world/hitchhiker.gd` and `.tscn`, new: she stands on the Road Home's far side, by the last plain straight before the junction of the player's farthest turn on it, or before the finish once they have arrived home, and fades once passed. Her art from `tools/art/legends/hitchhiker.gd` |
| UI | `ui/main.gd`: she shows on the Road Home once the book is full. `ui/book_screen.gd`: her row and page. `ui/game_over.gd`: NEW LEGEND!, and the next goal's line for her. `ui/legend_still.gd`: her still |
| Autoload | **Δ** `autoload/save_service.gd`: `record_found()` writes her at once, as the disaster entry `hitchhiker`, which `_entry()` already reads; `save_data.gd` is unchanged |
| Config, Disasters, Docs | `config/tuning.gd`: `HITCHHIKER_ASIDE`, `HITCHHIKER_FADE_SECONDS`. `disasters/legend_unlock.gd`: `BOOK_FULL` (§5.5). plan.md §2.6: the Book has her |
| Tests | `tests/unit/test_hitchhiker.gd`, new: she shows only on the Road Home with every legend of the pools collected; where she stands; passing her finds her once, and she fades; an arrival never unlocks her. `tests/integration/test_hitchhiker_run.gd`, new, in the main scene: her place, a departure, NEW LEGEND! as the run goes on, and a retry. `tests/unit/test_book_screen.gd`: she is the Book's last row and page |

**Acceptance:** E15, E16, E18.

### PR 14: Docs: `docs/ENDGAME.md`

Branch `eg/14-docs`, from `main`, once PR 13 has merged (Q18).

| Area | Files |
|---|---|
| Docs | `docs/ENDGAME.md`, new: the design as built, with this plan's IDs, which the code cites. `AGENTS.md`: the IDs, with W# (ENDGAME), and the state. IP: the state, and M7's notes from §9. `ENDGAME_PLAN.md`, deleted; the code's cites of it become `docs/ENDGAME.md`'s |

No code, so the counts are PR 13's.

**Acceptance:** E17, E18.

### 4.2 Landing (Q19)

This plan's PR targets `main`, and so does PR 1; each of PRs 2–13 targets the branch of the one before. Only a PR whose base is `main` merges (`AGENTS.md` §5). Once the owner has merged this plan's PR, agents land PRs 1–12 in order with `tools/agent/land_pr.sh` (stacks.md step 4), so none is registered as a GitHub stack (step 7). The owner lands PR 13, the stack's last, after the device checks (§6.4), and PR 14, which changes `AGENTS.md`. The plan changes only on `eg/plan` until its PR merges, and none of PRs 1–13 has it before PR 1 merges `main`. After that, each PR keeps its results and its review fixes in its body, and PR 13 carries the plan's final sync: its status, §4.3's rows, the counts and the device results (docs/agents/planning.md §5). So no two PRs change the plan's lines, and PR 14 deletes it.

A review fix goes on the branch of the PR that adds the file, then merges up the stack (`AGENTS.md` §4).

After each squash, retarget the next PR to `main` before the merged branch is deleted, which would close it (stacks.md step 6); then merge the merged branch and `origin/main` into the next PR's, each simulated with `git merge-tree` first, and check that `git diff --name-only origin/main` lists only that PR's files (step 5). A merge-up that changes no file in the PR's diff may start no Copilot review: request one with `gh pr edit <n> --add-reviewer @copilot`.

### 4.3 Review fixes

Fixes from the prototype's build, the internal review (§4.4) and the PRs' reviews, each with its tests and negative case.

| PR | Change | Tests | Negative case |
|---|---|---|---|
| 2 | The warnings check found an integer division in `GameOver.time_text()` at c153f03 (`game_over.gd`:81). 93a85f5 marks it `@warning_ignore("integer_division")`, as whole minutes are meant | §6.3's check, which finds only `main`'s five | None: §6.3 |
| 1 | 75904a8: the roll steers onto the finish's centreline, and the finish holds the car (§4.4 #1) | `test_the_car_stops_on_the_finish_however_it_comes_onto_it` | N28, N29 |
| 1 | 7c6e8bf: a finish due by the tutorial's end comes right after it (§4.4 #2) | `test_a_finish_due_by_the_end_of_the_tutorial_comes_right_after_it` | N30 |
| 2 | 6edcea6: the unlock's shares are tested with two locked legends in one area and one in another (§4.4 #3) | `test_each_locked_legend_is_as_likely_as_the_others` | N31, which passed the old test |
| 2 | 4d3d981: `arrival_count(finish)`, which PR 8 asks for the pier's (§4.4 #5) | `test_record_arrival_counts_and_keeps_the_best_time_and_a_clean_one` | N32 |
| All | Copilot's review of this plan: §4.2 had the stacks rebase on `main`; they merge it (stacks.md step 5) | None | None |
| 4 | Copilot: a legend's first `standing` sprite can be blank, a remnant or a glow; PR 4's `LegendStill` draws each scene's `figure` (§5.8) | `test_legend_still.gd` | PR 4's N54, N59, N60, N70 and N122–N124 |
| 11 | Copilot: §5.15 repaired on `area_changed`, before the move's road checks; the repair waits for the car to leave the set piece, or pass Last Gas, on the road | `test_car_sim_pit_stop.gd` | PR 11's N206 |
| 6 | Copilot: §6.4's runs, whose save is in memory, reached no seal, full Book or Hitchhiker; PR 6's `--collected`, and a reload (§5.7, §6.4) | `test_title.gd`'s `--collected` | PR 6's N114–N117 and N119 |
| 6 | Copilot: PR 6 left five tests on `CollectionScreen`, a deleted class; they move to the Book | Theirs; `git grep` finds no use | PR 6's N130, which is N20 on the Book |
| 12 | Copilot: a stamp read `_area_stats()`, which has the area that a run ends in; `crossed`, set on the road into the next area or by an arrival (§5.16) | `test_an_area_crossed_with_damage_or_not_crossed_is_not_stamped` | PR 12's N236 and N242–N244 |
| 14 | Copilot: §8 let PR 14 land before PR 13, which makes this plan's final sync; it waits (§4.2) | None | None |
| 11 | Copilot's overview: no tile carried `pit_stop` to `CarSim`, and `starting_at()` dropped it; tiles get it (§5.15) | `test_car_sim_pit_stop.gd`'s Departure | PR 11's N207, N208 and N211 |
| 12 | Copilot's overview: damage by `area_id` goes to the next area in a step that crosses, and misses one entered off the road; `damaged` names the area charged (§5.16) | `test_damage_across_a_border_names_each_area` | PR 12's N230 and N231 |
| 8, 12 | Copilot's review of 94b5007: PR 8 opens the Road Home, but only PR 12 kept a road's `farthest`, and its migration set Home's to 0, losing a run's progress there between them. PR 8's version 4 keeps each road's `farthest` from the Road Home's first run, and PR 12's version 5 keeps it (§5.12, §5.16) | `test_a_road_home_run_that_never_arrives_keeps_its_farthest`; `test_a_v4_file_is_migrated_with_no_stamps_and_keeps_each_roads_farthest` | PR 8's N167 and N168; PR 12's N240 and N241 |
| 3 | [Copilot](https://github.com/pompomon/roadgame/pull/103#discussion_r4605314853): `--finish=281` laid a junction on the Coast, which has no pool. 6dd4985: a `--finish` past the road's own end, 280, is an error (§5.7) | `test_a_finish_past_the_roads_own_end_is_an_error_and_the_road_is_the_games` | N45 |
| 4 | PR 4's probes at real sizes: the welcome didn't fit at zoom 2. 7e9077e zooms the arrival out (§5.8's Δ) | `test_the_welcome_shows_at_zoom_1_on_every_screen`, `test_on_the_fold4s_inner_screen_the_arrival_zooms_out_to_show_them`, `test_an_arrival_eases_the_view_to_show_the_welcome_and_the_car` | N72–N84 |
| 4 | The internal review of 7e9077e: a resize during an arrival hid the car, for 52 frames on a fold to the cover. bdb1471 moves the camera at once; a probe of 1,300 resizes found no frame without the car | `test_a_resize_during_an_arrival_keeps_the_car_in_view` | N85 |
| 4 | [Copilot](https://github.com/pompomon/roadgame/pull/104#discussion_r4607979789): a glow's still clipped over the sea, the wisp's green at 1.25. b0e2ed0: `LegendStill.strength()` | `test_a_glows_still_adds_no_more_light_than_its_ground_leaves_below_white`, `test_the_glows_on_the_shore_never_clip_as_the_sun_sets` | N121–N124 |
| 6 | The warnings check: a local `flat` shadowed a base class's member at 5cc4f6b (`book_cell.gd`:64); 0bbfcde names it `box` | §6.3's check | None: §6.3 |
| 6 | [Copilot's first review](https://github.com/pompomon/roadgame/pull/106#pullrequestreview-5950768396), 2866e43 and 7976703: a cell's and a row's names for a screen reader, a drag from a cell past `BOOK_SCROLL_DEADZONE`, and a band over the art | `test_a_cell_reads_its_words_to_a_screen_reader`, `test_a_drag_from_any_cell_scrolls_the_book_and_opens_no_page`, `test_a_tap_that_wobbles_opens_the_page`, `test_each_still_fits_its_cell_whole_with_square_pixels`, `test_a_row_names_its_area_and_how_many_of_its_legends_are_found` | N140–N145 |
| 6 | [The second](https://github.com/pompomon/roadgame/pull/106#pullrequestreview-5951180691), 1e876fd: a silhouette's focus, a page that closes to its cell, and the silhouettes' and seals' contrast (W26). A visible row label waits for the owner | `test_a_legend_not_found_is_its_silhouette_and_its_initials_and_has_no_page`, `test_a_page_closes_to_its_cell_in_view_where_the_book_was_left`, `test_a_silhouette_and_an_unearned_seal_stand_out_from_their_grounds` | N146–N151 |
| 6 | [The third](https://github.com/pompomon/roadgame/pull/106#pullrequestreview-5951619394) and [the fourth](https://github.com/pompomon/roadgame/pull/106#pullrequestreview-5951949512): a seal not earned is hollow (cfbbe64), a glow's silhouette a disc (4a17718), and an earned seal has no dark core (2b0dea7; W26) | `test_a_seal_not_earned_is_hollow_and_an_earned_one_whole`, and a frame of the Book | N152–N155; N154 fails the frame |
| 6 | [The fifth](https://github.com/pompomon/roadgame/pull/106#pullrequestreview-5952204310)'s and [the sixth](https://github.com/pompomon/roadgame/pull/106#pullrequestreview-5952663374)'s overviews: a screen reader's focus on a page's lines (9f8322b, W27), and the keys that scroll the Book (0eeb84d, W28) | `test_a_screen_reader_reaches_the_count_and_each_line_of_a_page`, `test_a_page_scrolls_to_the_line_that_has_the_focus`, `test_the_keys_scroll_the_book_where_the_focus_has_nowhere_to_go`, `test_the_keys_scroll_a_page` | N156–N163 |
| 11 | The internal review: a car that turned back out of a pit stop was repaired; the repair waits for the path tile after its last, once | `test_turning_back_out_of_a_pit_stop_repairs_nothing` | N229 |
| 12 | The internal review: the Atlas didn't follow a screen reader's focus; `%Scroll` does | `test_the_atlas_scrolls_to_the_postcard_that_has_the_focus` | N265 |
| 13 | The warnings check: two integer divisions at 3c71ca7 (`test_hitchhiker.gd`:215 and :218); 30d6f1a divides as floats | §6.3's check | None: §6.3 |

### 4.4 Internal review

gpt-6.1-sol (`rubber-duck`), a model of another family, reviewed this plan and the prototype at 93a85f5 (`AGENTS.md` §5). Each finding was checked before it was fixed, and its review of the fixes, at 4d3d981, found no more:

| # | Finding | Checked | Change |
|---|---|---|---|
| 1 | The roll steered straight, so a car that came onto the finish askew could leave it | A probe stopped an angled arrival 0.53 tiles off the centreline, past the road's edge at 0.32, and rolled cars that rejoined across the finish 3.3–5.2 tiles off its side | 75904a8 (§4.3, §5.2) |
| 2 | A finish due by the tutorial's end came a junction late | The new test laid 5 turns, not 4 | 7c6e8bf (§4.3, §5.1) |
| 3 | The unlock's test couldn't tell a flat pick from an area-first one | N31's area-first pick passed it | 6edcea6 (§4.3) |
| 4 | A home stretch, as PR 3's Coast, breaks E1's tile-for-tile road | P2b: the road is `endless()`'s up to and including the last junction, and the home stretch's from the next tile | E1, §5.1, PR 3's test |
| 5 | PR 8's `arrival_count(&"pier")` didn't exist | `arrival_count()` took no finish, and counted all | 4d3d981 (§4.3, §5.4) |
| 6 | PR 4's held sunset would never move | `main.gd`:97–103 advances the cycle only while RUNNING | PR 4, §5.8 |
| 7 | PR 12 had no road for a run's `farthest`, and its migration lost Home's | `stats()` names no road (`game_state.gd`:112–120); `record_run()` keeps overall bests only (`save_data.gd`:138–150) | PR 12, §5.14, §5.16; PR 8 since Copilot's review (§4.3) |


## 5. Design

§5.1–§5.7 describe the prototype, PRs 1–2, as built; §5.8–§5.18 design PRs 3–14. Each design serves one of the needs that Mark Rosewater lists for every game, or a practice that shipped games have tested:

| Principle | What it asks | Where |
|---|---|---|
| A goal (Rosewater) | The player knows what winning is | The pier (§5.1); the Book's count and the next goal (§5.9, §5.10) |
| Inertia (Rosewater) | The game moves toward an end | The road ends after 280 turns (§5.1) |
| Surprise (Rosewater) | Not every reward is foreseen | The random unlock (§5.5), the Road Home's first right (§5.6), the Hitchhiker (§5.17) |
| A catch-up feature (Rosewater) | A player who falls behind can come back | Pit stops (§5.15) |
| Flavor (Rosewater) | The world tells its story | The Coast's sunset and the legends on the shore (§5.8); the Book's lore |
| The goal gradient | Effort rises as a visible goal nears | The route strip (§5.14) |
| An unfinished set pulls (the Zeigarnik effect) | Show what is missing, not only what is owned | The Book's silhouettes and initials (§5.10) |
| Encounters fill the codex (Hades) | The collection comes from playing | The Book; the unlock (§5.5, §5.10) |
| A second quest (The Legend of Zelda) | After the win, the same world, rearranged | The Road Home (§5.6, §5.12) |
| Earned shortcuts (Spelunky) | Practise the hard part without the easy one | Departures (§5.11) |
| Optional goals never gate the end (Celeste's strawberries) | Mastery for those who want it | A clean arrival, the best time, the stamps (§5.16) |

### 5.1 The road's end (PR 1; W1, W4, W6, W17; E1, E6)

`AreaSchedule` gains three exports: `finish`, the id of the finish's set piece, `&""` for none; `finish_turn`, after which the road leads to it, counted from the City's first turn after the tutorial, as the areas' turns are (W4); and `mirrored` (§5.6). `validate()` reports a `finish_turn` without a finish, and a finish before the last area's turn. `ending_at(turns, finish)` is a copy that ends after `turns` turns, with the areas before it, for the short roads of tests and `--finish`; `endless()` is a copy without the finish, which also leaves out a home stretch, a last area that starts at the finish's turn, so that the area before it goes on as on `main` (W17); and `starting_at()` moves the finish as many turns sooner as the area starts (W7). The first two share the entries, and `starting_at()` copies them field by field (§5.15).

`_finish_due()` holds once the road is in its last area, out of the tutorial, with `finish_turn` turns behind since `_turn_base`. `RoadGenerator` asks it after each junction, and as the tutorial ends, so that a finish due by then, as on a `--finish` road of the City alone, comes right after it, where the City's first junction would be (§4.4 #2). Once it holds, no junction follows: the straight after the last one is drawn as any other, then `_finish_tile()` lays the finish's `FINISH_TILES`, 8, the first of which sets `finish_index`, and after them `BEYOND` tiles, straight on, as many as the buffer asks for. Neither draws a number, so up to and including the last junction the road is `endless()`'s, and up to the finish without a home stretch (E6, P2). A home stretch is its own area's from the next tile on, and draws its straight from its own range (P2b, §4.4 #4). `finished()` and `finish_index` tell the rest of the game where it is.

Until PR 3 nothing draws a finish: `GreyboxAtlas` draws both kinds of tile as road, and `WorldRenderer` finds no scene for them and adds none (`world_renderer.gd`:166–169). Only `--finish` and `--home` reach one (§5.7).

### 5.2 The arrival (PR 1; W5; E2)

`JunctionTrigger` arrives as the car crosses onto a tile of the finish, or comes back onto the road on one, with every junction behind it; never after a mistake, which sets `_failed`, or in the tutorial. `_junction_after()` returns null only when no junction is ahead in the buffer and the generator has finished, so `_is_finish()` takes `next_junction == null` to mean that every junction is behind.

On the trigger's `arrived`, `CarSim` enters `State.ARRIVED`, whose end cause is `ARRIVAL`, and brakes evenly, to stop `ARRIVE_STOP_SHORT`, 0.5, before the centre of the finish's last tile, or within `ARRIVE_ROLL_SECONDS`, 4.0, if it came slowly: `_on_arrived()` takes the greater of the rates v²/2d, d being the room left and at least `ARRIVE_STOP_SHORT`, and v/`ARRIVE_ROLL_SECONDS` (W5). `_roll()` steers it as the autopilot steers, toward the finish's centreline `Autopilot.LOOKAHEAD` ahead, and the finish holds it: each step keeps it within the road's edges and the finish's ends. So a car that came onto the finish at an angle, or across it after a rejoin, stops on it too, where one that steered straight left the road (§4.4 #1). P4's cars stopped in 2.40–4.02 s, each on the centreline (§6.5).

### 5.3 The run's end, its sequence and its clock (PR 2; W2, W8, W11, W15, W20; E3)

`GameState` gains `State.ARRIVED`, which `end_run(CarSim.ARRIVAL)` enters from RUNNING and which leads to GAME_OVER or TITLE, as DISASTER and CRASH do (W2). The run's clock, `seconds`, adds each frame while RUNNING outside the tutorial, so a pause stops it; `clean` is true at the run's start and at the tutorial's end, and false once the car leaves the road outside the tutorial. `stats()` has both. `main.gd` ends the run on `arrived`, with no autopilot error (W8), and on a finished road `_turns_before()` counts every turn as behind (W11). The director's `play_arrival()` plays no disaster for `ARRIVAL_SECONDS`, 5.0, which outlasts the roll and ends before `DISASTER_TIMEOUT`, 6.0 (W20). The end screen then says "You reached the end of the road!" (W15), and its stats add "Time: 9:41".

### 5.4 Records and the save's version 3 (PR 2; Q4, W3, W7, W16; E4)

Version 3 adds `arrivals`, keyed by the finish's id, each `{count, best_seconds, clean}`, and each disaster entry's `unlocked`. `_v2_to_v3()` changes nothing, as `_entry()` gives a stored entry the defaults of the keys it lacks (W3). `record_arrival()` counts an arrival, and keeps the least time and whether any was clean; `unlock_disaster()` marks a legend unlocked; `arrival_count(finish)` reads a finish's count, or every finish's without one. `SaveService.record_arrival(finish, stats, unlocked)` does both and saves at once, as a player may close the game on the arrival. Only a run that drove the whole road counts, one whose schedule starts in the whole schedule's first area (`_drove_whole_road()`; Q4, W7). A run from `--area`, the title's Start choice or, after PR 7, Departures arrives and shows its time, but records no arrival and unlocks nothing. P4's saves stayed under 2 KB (§6.5).

### 5.5 The unlock (PR 2; the owner's answer; Q2, Q3, W14, W23; E5)

`LegendUnlock`, static, in `disasters/legend_unlock.gd`, lists the locked legends, those of the road's pools neither seen nor unlocked, in the collection's order, and picks one, each as likely as the others, on the run's own stream:

```gdscript
static func pick(schedule: AreaSchedule, collected: Array[StringName], run_seed: int) -> StringName:
	var pool := locked(schedule, collected)
	if pool.is_empty():
		return &""
	return pool[stream(run_seed).randi_range(0, pool.size() - 1)]
```

`stream()` is seeded with `hash("<seed>:unlock")`, so the same seed and collection unlock the same legend, and the road's streams and PL's picks draw what they drew before (W23). `main.gd` asks for one on an arrival that counts, with `seen_disasters()`, which lists the unlocked as collected (W14), and with the whole road's pools, also on `--finish`'s short road, after `_end_run(CarSim.ARRIVAL)`; `SaveService.record_arrival()` records both before the director plays the arrival.

The end screen's fate line names it, "A new legend for your book: Phantom Bus", or says "Every area's legends are in your book." (**Δ** PR 13: the Hitchhiker is in no pool, so a full pool is not yet a full Book). The Book shows its page, with its name, "Unlocked by an arrival", "Not seen yet" and its lore, but no fate, until a run meets it (PR 6). PL's picks weigh it as seen, 0.5 against 1 (Q3), so the runs show the legends still missing sooner: the unlock and the picks pull the same way, toward the full book. P3 drew each of five locked legends 0.196–0.206 of the time (§6.5). The owner asked for "a random legend from the pool of locked"; it is also Rosewater's surprise, as the player knows that an arrival pays, not what it pays.

### 5.6 The Road Home (PRs 1, 2; the owner's answer; W9, W10; E9)

`areas/schedule_home.tres` is the road driven back: the Desert from turn 0, the Village from 60, the Meadows from 80, Rural from 180 over the bridge and the City from 246 through the tunnel, each as long as on the way out, and `home` after 280. It is `mirrored`: the generator starts it heading W, with `_parity` 1, so its first turn, `Heading.turn_for(turn_count + _parity, heading)`, is a right, to N, and the staircase climbs N and W as the way out does (W9). It has no tutorial, whose loops are laid for a road heading N: `_tutorial_wanted()` is false for it, and a mirrored generator asked for one errors and lays none (W10). `--home` drives it, and PR 8 offers it on the title after the first arrival. Its arrivals count under `home`, and unlock as the pier's do.

### 5.7 The debug flags (PRs 2, 6; W21)

`--finish=<turns>` ends the run's road after that many turns, at its own finish, or at the pier on a road without one, with the areas before it; a bad number, or one past the road's own end, 280, errors (PR 3, §4.3), and the road stays the game's. `--home` drives the Road Home. Both go with `--area`, `--seed` and `--autopilot`. A `--finish` run from the City counts (W21). PR 6 adds `--collected=<area>` and `--collected=all`, which mark that area's legends, or every pool's, seen in the save in use, for E16's seals and full Book and PR 13's Hitchhiker (§6.4).

### 5.8 The Coast, the pier and the arrival's scene (PRs 3, 4; Q1, Q17, W6, W17–W19; E7)

PR 3 adds the Coast to `schedule.tres` at turn 280, with `finish = &"pier"` and `finish_turn = 280`. The Coast is a home stretch: one straight of 20 tiles, the most `max_straight` allows, then the pier; no junction, so no pool and no legend, and the Desert stays the climax (Q1). At the speed cap the straight takes about 3 s, time for the sand, the light and the sea ahead. Its art, its props (dune grass, beach huts, a lighthouse), its music and its ambience (waves, gulls) come from the generators, as each area's do.

The pier is a set piece like the bridge. `GreyboxAtlas.road_coords()` draws its 8 tiles in the bridge's row, planks, and gives `BEYOND` no tile. `setpieces/pier.gd` draws the sea in the set pieces' layer, over the ground and under the road: every cell at or past the finish's first tile along the road's heading, out past the view's edge, with a line of waves on the shore. So the road ends on planks, with the sea ahead and around, and nothing beyond. `PropScatter` places no prop past the finish's first row, and `build()` checks the finish's scene as it checks the areas' (W18). `setpieces/home.gd`, the Road Home's end, draws a garden fence across the road's end and a house past it, in the City's palette; its tiles draw as road, a drive. W6's and W19's tests change as §2 says.

PR 4 makes the arrival a scene, within its 5.0 s (Q17):
- **The sunset.** `DayCycle.hold(ARRIVAL_HOUR)` stands the clock at 18.5, `LIGHT_DUSK`'s hour, and the light follows at `LIGHT_MAX_RATE`, 0.25 a second for each channel, as it always does: 1.92 s from noon's white and 2.32 s from night, in time, and never a flash. As only `advance()` moves the light, `main.gd` advances the cycle in `ARRIVED` too, which today it does only while RUNNING (`main.gd`:97–103, docs/DAYNIGHT.md §5.4); the next run's `enter()` clears the hold.
- **The legends over the sea.** **Δ** `Pier.welcome(schedule, collected)` stands each collected legend's still over the sea past the pier's end, in the Book's grid, as the shore, about 448 pixels across, can't show whole in a view 360 wide (PR 4). They fade in one after another, a legend not yet found leaves its place empty, and a glow's still adds no more light than the sea leaves below white, by `LegendStill.strength()` (docs/M6.md S10). The Book becomes something the player sees, as they earn it. `LegendStill`, which the Book reuses, draws the frame that each legend's scene names as its figure (`figure`, `figure_frame`) whole, in its `self_modulate`, whatever the rest pose hides: the worm rests transparent and cropped to nothing (`death_worm.tscn`:53–59). A `standing` part can be a remnant, such as the Witch Hex's pumpkin, and PL's Marfa Lights and wisps are glows (docs/POOLS.md §5.4).
- **The view.** **Δ** `CameraRig.arrive()` eases the view from the car to hold the welcome and the car (PR 4). Where the welcome, 338 pixels high, doesn't fit zoom 2's view, 320, as in a landscape window or on the Fold4's inner screen, the zoom eases out to 1 over the pan (`arrival_zoom_for()`), and a resize keeps the car in view (§4.3); otherwise the zoom keeps its whole step.
- **The sound.** The engine winds down with the car, where today every loop stops as the run ends (`audio_director.gd`, `_on_run_ended()`); the area's music fades; and `arrival.wav`, a short rising jingle from `make_audio.gd`, plays as the car stops.

### 5.9 NEW LEGEND! and the next goal (PR 5; Q16; E8)

A legend is new to a run if the run met or unlocked it, and it wasn't collected as the run started: `main.gd` keeps the collection that PL's picks were made with (docs/POOLS.md V2). The end screen then shows NEW LEGEND! above the fate, in large letters that stay still, and `new_legend.wav` plays once (Q16). Under the stats, one line gives the next goal, the first that holds:

| Holds | Line |
|---|---|
| No arrival at the pier | "Next: reach the sea. Your best: turn 212 of 280" |
| PR 8: no arrival home | "Next: drive the Road Home" |
| Legends missing | "Next: find the 6 legends still missing" |
| PR 13: the Hitchhiker not found | "Next: someone waits on the Road Home" |
| No clean arrival | "Next: reach the sea without leaving the road" |
| Otherwise | "Next: beat your best time, 9:41" |

Each line uses only the font's glyphs, fits 360 pixels, and changes only as progress does. Rosewater's first need is a goal, and a roguelike's end screen is where the player decides to go again, so it names the nearest one.

### 5.10 The Book of Legends (PR 6; Q8; E8)

The collection becomes the Book. `ui/book_screen.gd` reads the game's pools, whatever their size: a row for each area with a pool, in the road's order, and a column for each slot, the ★, wave A's and wave B's (docs/POOLS.md §5.4). Over the grid, "Legends 7/15". A cell shows:
- a legend seen: its still and its name; tapped, its page, in place of the grid, with its name, its sightings, its fate and its lore (**Δ** PR 6, where this plan had the collection's card);
- a legend unlocked and not yet seen: its still, its name and "Not seen yet"; its page has "Unlocked by an arrival", "Not seen yet" and its lore, but no fate;
- a legend not found: its silhouette, the still's shape flat in `SILHOUETTE`, a grey that stands out from the cell, each texel that the still covers at all drawn whole, so that a glow's is a disc (W26), and its name's initials, "P______ B__";
- a glow's still, in a cell or on a page, adds no more light than its ground leaves below white: the lightest centre of the cell's styles, `BookCell.ground()`, or `BookScreen.backdrop` (docs/M6.md S10);
- the Hitchhiker's row, last, once the pools are full: her silhouette, then her still and a white seal, read as "Road Home: 0 of 1 legend found" until she is found (PR 13, §5.17);
- an area whose legends are all found: a seal beside its row, an eight-pointed star whole in the area's colour, and until then hollow, its outline in `SILHOUETTE` (W26).

At 360 × 640, five rows of three 96-pixel cells fit under the title, with the count. A word of a name too wide for its cell, as "Will-o'-the-Wisp" is, breaks after a hyphen, which an exported build's labels don't do themselves (W25). A band taller than the cell leaves room for, a name of two lines over "Not seen yet", raises the still's area to its top, so that the still stays whole. A row wider than the screen scrolls, and a drag that starts on a cell scrolls it too, once it goes 8 pixels, `Tuning.BOOK_SCROLL_DEADZONE`, so that a tap that wobbles less still opens the page. A page scrolls on its own, in place of the grid, which keeps its place: closing the page shows the Book as it was left, with the page's cell in view. A screen reader, which Godot 4.7.2 has on the desktop builds only, reads each cell's words, a silhouette's initials too, without opening its page, and a row's area with its legends found ("Meadows: 2 of 3 legends found"). Its focus, which Tab moves, reaches the count too, and on a page each line in turn, which the page scrolls to; without a screen reader, no line takes the focus, and Tab stays on Back (W27). Where the focus has nowhere to go, the keys scroll the Book, or the page: an arrow by an eighth of what shows, `Tuning.BOOK_KEY_SCROLL`, Page Up and Page Down by all of it, and Home and End to the top and the bottom, so that a keyboard reaches a row or a line past the screen, which takes no focus without a screen reader (W28). The silhouette and the initials hint without telling: an unfinished set pulls (the Zeigarnik effect), and Hades' Codex shows how a book that fills as the player plays brings them back for its last pages.

### 5.11 Departures (PR 7; Q11, W22; E10)

ZS's Start choice, in debug builds only today (docs/ZONE_SELECT.md Z4), comes to every build. A release build offers the areas discovered, in the road's order, but a home stretch; a debug build offers every area, as now. A departure arrives but counts nothing (§5.4), and `GameState.whole_road`, in `stats()`, tells `record_run()` to keep its areas' bests and discoveries but not the overall bests (W22). The legends it meets count, so a player can hunt a missing legend in its own area. Spelunky's shortcuts work so: a later start is earned by reaching it, and practises the hard part without the easy one, while only the whole road wins.

### 5.12 The Road Home on the title (PR 8; Q12; E9)

Once `arrival_count(&"pier")` is above 0, the title shows a Road choice, "Road: To the sea" or "Road: Home", kept until the game closes. `main.gd` holds both schedules, and builds the world from the game's, whose areas the Road Home shares; `test_every_finish_has_its_scene` checks both finishes. Departures follow the chosen road's areas, the Desert's first on the Road Home. Its arrivals count under `home` and unlock a legend, and the first is the next goal's second line. The Legend of Zelda's Second Quest gave back a finished world, rearranged; here the player who knows "left first" fails at the first junction and learns the road again (`plan.md` §1.1).

PR 8 also keeps each road's progress, which the strip (§5.14) and the Hitchhiker (§5.17) read from the Road Home's first run on (§4.3). `GameState` learns the run's `road`: the finish of the road that the run drives whole, or `&""` on Keep Driving's endless road and for a run from a later area; `stats()` has it, and `main.gd` sets it as the run starts. The save's version 4 adds `farthest` to each arrival entry, its road's farthest turn: `record_run()` raises the run's road's to the run's turns, and an arrival raises it to the finish's turn, so a Road Home run that never arrives keeps its progress. `_v3_to_v4()` sets the pier's to its finish's turn if it has an arrival, or else to `min(best.turns, 280)`, as before PR 8 only the pier's road counts in `best`, the debug flags and a debug build's Start choice aside: Keep Driving comes after it, and Departures count no overall best. Home's is its finish's turn if it has an arrival, or else 0, which is exact, as only `--home` drove it before.

### 5.13 Keep Driving (PR 9; Q13; E11)

After the first arrival, the Road choice also offers "Road: Endless", `schedule.tres`'s `endless()`, on which the Desert goes on as on `main`. Its runs count as `main`'s do, with the overall bests, the areas and the legends; none can arrive, and the route strip doesn't show. The endless chase stays for the players who loved it.

### 5.14 The route strip (PR 10; Q14; E12)

On a road with a finish, a strip runs up the HUD's right edge, 6 pixels wide and 40% of the screen's height: the road's start at its foot and the finish at its top, a tick at each area's first turn, a flag at the top, a solid triangle for the car at `turn_index / finish_turn`, and a hollow diamond for the best run, at the road's `farthest`, which PR 8 keeps for both roads (§5.12). Shapes, not only colours, tell them apart, and the car's mark moves a pixel or two a turn, never a flash; in the tutorial it waits at the foot. The goal-gradient effect (Kivetz, Urminsky and Zheng, 2006): people speed up as a goal they can see comes near. The diamond is the player's own ghost, a rival always their size.

### 5.15 Pit stops (PR 11; Q10, W24; E13)

Rosewater's catch-up feature: a player behind can come back. `AreaScheduleEntry` gains `pit_stop`: on the way out, Rural, through the tunnel, the Meadows, over the bridge, and the Desert, where Last Gas, a filling station, stands by its first straight; on the Road Home, Rural over the bridge, the City through the tunnel, and the Village, with Last Gas. Its tiles, the set piece or Last Gas's straight, carry `pit_stop`, set by `RoadGenerator` as `set_piece` is (`road_generator.gd`:90, :178) and copied by `starting_at()` for a Departure (`area_schedule.gd`:85–91). As the car leaves them on the road, `CarSim` adds `PIT_STOP_HEAL` to its health, at most `START_HEALTH`, once for each in a run, with a sound and the health bar's rise; never off the road, or once the run has ended. It checks each crossing as the trigger judges it, after the move's road checks (`car_sim.gd`:103–107), not on `area_changed`, which `_update_path()` emits before them (:267–268). Last Gas is a scene beside the road, not on it, and `Fixtures.signature()` leaves `pit_stop` out, so the road and its digests stay as they are. It breaks `plan.md` §2.4's "no pickups" (W24), so it waits for the owner's yes (Q10), and dropping it changes no other PR.

### 5.16 Records and postcards (PR 12; Q15; E14)

Version 5 adds `stamped` to each atlas entry, true once a run crossed the area with no damage. `_area_stats()` also has the area that a run ends in (`game_state.gd`:123–136), and `area_changed` comes before the move's road checks (§5.15), so `GameState` keeps each area's `crossed` beside its damage: set as the car crosses onto the next area's first tile on the road, where the trigger judges it, or arrives in the last. A failure with no damage, or a Departure stopped before the area's end, stamps nothing. An area's damage is what `_drive_off_road()` charges at its rates (`car_sim.gd`:329–332), and a new `CarSim` signal, `damaged`, names that area: a step charges after `area_changed` (:99), so `area_id` may be the next area's, and an area entered off the road gets no `offroad_changed`. The tutorial's counts for nothing, as for `clean`. `_v4_to_v5()` changes nothing: `_entry()` gives each atlas entry `stamped`, false, and each road's `farthest`, PR 8's, stays as it was (§5.12). The Atlas's cards become postcards: the area's ground and a prop, its name and bests, and a stamp once crossed clean. The title shows the arrivals, the best time and a clean arrival, and the end screen says "New best time!" when an arrival beats it. Like Celeste's strawberries, these goals never gate the end: mastery for those who want it, once the Book is done.

**Δ** As built (PR 12): `CarSim.area_crossed` tells `GameState` each crossing, only on the road and from an area's last path tile onto the next's first (W32), and `SaveData.beats_best_time()` the end screen's "New best time!". The postcards are `MenuCard`s, and the keys that move no focus and a drag from a postcard scroll the Atlas, which follows the focus (W33).

### 5.17 The Vanishing Hitchhiker (PR 13; Q9; E15)

The Book's last page is the road's own urban legend. Once every legend of the pools is collected, she stands on the Road Home's far side, `HITCHHIKER_ASIDE` across from the centre of the last plain straight, not a pit stop's, before the junction of the player's farthest turn there, never a decoy's, or before the finish once they have arrived home (`Hitchhiker.road_turn()`), and faces the road. A place that the buffer hasn't laid yet waits for it (W34), and one with no plain straight before it is an error, and she stays hidden. A Departure from an area before her turn shows her too. Passing her, in a run that isn't over, finds her: she fades in `HITCHHIKER_FADE_SECONDS`, the run goes on, and its end screen shows NEW LEGEND!. A run that ends before her doesn't, and a retry places her anew. She is no disaster and in no pool, so an arrival never unlocks her and PL's picks never draw her, and a full pool's line is "Every area's legends are in your book." (§5.5). **Δ** `SaveService.record_found()` writes her at once, as the disaster entry `hitchhiker`, which `_entry()` already reads, so `save_data.gd` is unchanged. The end screen's next goal is "Next: someone waits on the Road Home" until she is found. The Book counts 15 legends until her row shows, then 16 (§5.10), and the pier's welcome leaves her out. Her art comes from `tools/art/legends/hitchhiker.gd`, as PL's legends' does. The full book's reward is a new mystery, not a number: Rosewater's surprise again, and a reason to drive the Road Home once more.

### 5.18 The docs (PR 14; Q18; E17)

Each of PRs 1–13 folds its own Δs, with their findings, into `plan.md`, IP and docs/ZONE_SELECT.md (§4's Docs rows), so that `main`'s docs describe `main`'s game at each step. PR 14 adds `docs/ENDGAME.md`, the design as built, with its E# and W#; adds W# (ENDGAME) to `AGENTS.md`'s IDs; brings IP's state and §9's notes for M7 up to date; points the code's cites of this plan to `docs/ENDGAME.md`; and deletes this plan.

---

## 6. Verification

### 6.1 Checks and counts

The checks are `AGENTS.md` §3's five: the import, `check_scripts.sh`, `lint.sh`, GUT and `smoke.sh`. They ran locally with Godot 4.7.2, and on 4d3d981 in CI run 43692666379, started by hand, whose `test`, `lint`, `export-web` and both `export-android` jobs passed:

| State | Where | Scripts loaded | Test scripts | Tests | Asserts | GUT time | Smoke |
|---|---|---|---|---|---|---|---|
| `main` (81f22e3) | Local | 160 | 77 | 583 | 426,861 | 92.1 s | `autopilot: tile 165, turns 35, area rural` |
| PL's PR 1 (532908a) | Local | 162 | 78 | 597 | 427,048 | 96.2 s | The same |
| PR 1 alone, from 4d3d981 | Local | 165 | 81 | 620 | 440,016 | 103.7 s | The same |
| Prototype (4d3d981): PRs 1–2 | Local | 168 | 83 | 642 | 440,189 | 108.1 s | The same |
| Prototype (4d3d981) | Run 43692666379 | 168 | 83 | 642 | 440,189 | 83.1 s | The same |
| `main` (f491e55), PL landed | Local | 195 | 90 | 703 | 437,643 | 109.1 s | The same |
| PR 1, ported onto f491e55 | Local | 198 | 93 | 726 | 450,611 | 114.3 s | The same |

`lint.sh` found no problem, and would leave every file as it is: 165 for PR 1, 168 at the head. `smoke.sh` printed no error line.

**Δ** As built, at each PR's head, locally and in CI: every check passed, `git status --porcelain` printed nothing, and each smoke run printed `autopilot: tile 165, turns 35, area rural`.

| PR (head) | Scripts loaded | Test scripts | Tests | Asserts | GUT time | CI run | CI's `test` job, its GUT |
|---|---|---|---|---|---|---|---|
| 1, #101 (c15604b) | 198 | 93 | 726 | 450,611 | 115.6 s | 44149774286 | 3 min 13 s, 114.3 s |
| 2, #102 (1e16cdf) | 201 | 95 | 748 | 450,794 | 118.4 s | 44153183467 | 3 min 26 s, 145.9 s |
| 3, #103 (6dd4985) | 204 | 96 | 763 | 451,675 | 145.4 s | 44171387868 | 3 min 1 s, 120.0 s |
| 4, #104 (b0e2ed0) | 207 | 98 | 790 | 452,672 | 130.3 s | 44217507554 | 3 min 6 s, 127.5 s |
| 5, #105 (323fd25) | 207 | 98 | 797 | 452,958 | 128.9 s | 44220731030 | 3 min 7 s, 127.7 s |
| 6, #106 (0eeb84d; 88009d3 changes only this plan) | 210 | 98 | 823 | 453,503 | 129.5 s | 44268595188 | 3 min 40 s, 138.6 s |
| 7, #107 (bde2d6a) | 210 | 98 | 826 | 453,524 | 130.3 s | 44271410279 | 4 min 2 s, 180.2 s |
| 8, #108 (ebf7d37) | 210 | 98 | 833 | 453,704 | 131.4 s | 44282297765 | 3 min 57 s, 151.9 s |
| 9, #109 (a5d8e20) | 210 | 98 | 834 | 453,789 | 130.5 s | 44286172584 | 3 min 13 s, 132.4 s |
| 10, #110 (e1e42e7) | 211 | 98 | 837 | 453,833 | 127.7 s | 44295102528 | 3 min 14 s, 130.5 s |
| 11, #111 (c0903b0) | 215 | 100 | 856 | 455,944 | 131.4 s | 44321462801 | 3 min 29 s, 130.5 s |
| 12, #112 (1b4a0cd) | 217 | 101 | 877 | 456,190 | 132.5 s | 44347412000 | 4 min 7 s, 184.9 s |
| 13, #113 (30d6f1a) | 221 | 103 | 903 | 456,538 | 134.0 s | 44367702653 | 3 min 6 s, 126.3 s |

### 6.2 Negative cases

Each case makes one change to the prototype's code, runs the whole suite, and checks that the tests it names fail; then it undoes the change. All 32 ran on 4d3d981, of 642 tests; the first 27 ran on c153f03 and 93a85f5 too. PRs 1 and 2 ran theirs on their own branches (§4.1); PRs 3–13 added theirs from N33, at least one for each of their E#s.

PR 1's:

| N# | Change | Fail |
|---|---|---|
| N1 | `road_generator.gd`: `_finish_due()` is never true, so no road ends | `test_the_road_ends_at_the_finish_after_its_last_turn`, and every test that needs a finish: 22 |
| N2 | `road_generator.gd`: a mirrored road starts with `main`'s parity | `test_a_mirrored_road_starts_west_and_turns_right_first`: 1 |
| N3 | `road_generator.gd`: every tile past the finish is the finish's, not `BEYOND` | `test_the_road_ends_at_the_finish_after_its_last_turn`: 1 |
| N4 | `junction_trigger.gd`: a run that has failed can still arrive | `test_no_arrival_off_the_road_or_after_a_disaster`: 1 |
| N5 | `junction_trigger.gd`: a car that rejoins the road on the finish doesn't arrive | `test_the_car_arrives_as_it_rejoins_the_road_on_the_finish`, and the roll's rejoin: 2 |
| N6 | `car_sim.gd`: an arriving car brakes as after a crash | `test_the_car_arrives_and_rolls_to_a_stop_on_the_finish`, from the speed cap and at an angle: 3 |
| N7 | `car_sim.gd`: the roll has no `ARRIVE_ROLL_SECONDS` floor | `test_a_slow_car_stops_on_the_finish_within_arrive_roll_seconds`: 1 |
| N15 | `area_schedule.gd`: `starting_at()` keeps the whole road's `finish_turn` | `test_a_road_that_starts_in_a_later_area_ends_as_many_turns_sooner`, and its arrival: 2 |
| N22 | `road_generator.gd`: the finish counts the tutorial's turns | `test_the_finish_counts_its_turns_from_the_end_of_the_tutorial`, and the finish due by its end: 2 |
| N23 | `road_generator.gd`: `_finish_due()` draws from the road's stream | `test_the_road_before_the_finish_is_the_endless_roads`, and a roll: 2 |
| N24 | `area_schedule.gd`: `endless()` keeps the home stretch | `test_an_endless_road_leaves_out_the_home_stretch`: 1 |
| N28 | `car_sim.gd`: the roll steers straight, as at 93a85f5 | `test_the_car_stops_on_the_finish_however_it_comes_onto_it`: 1 |
| N29 | `car_sim.gd`: the roll steers onto the centreline, but nothing holds the car on the finish | `test_the_car_stops_on_the_finish_however_it_comes_onto_it`: 1 |
| N30 | `road_generator.gd`: the tutorial's end lays no finish that is due | `test_a_finish_due_by_the_end_of_the_tutorial_comes_right_after_it`: 1 |

PR 2's:

| N# | Change | Fail |
|---|---|---|
| N8 | `legend_unlock.gd`: a collected legend counts as locked | `test_the_locked_legends_are_those_not_collected_in_the_collections_order`: 6 |
| N9 | `legend_unlock.gd`: the draw, off by one and clamped, picks the last legend twice as often | `test_each_locked_legend_is_as_likely_as_the_others`: 1 |
| N10 | `main.gd`: every run drove the whole road | `test_a_run_from_a_later_area_arrives_but_counts_nothing`: 1 |
| N11 | `save_data.gd`: `seen_disasters()` leaves out the unlocked | `test_an_unlocked_disaster_is_collected_as_if_seen`: 2 |
| N12 | `save_data.gd`: `record_arrival()` keeps the slowest time | `test_record_arrival_counts_and_keeps_the_best_time_and_a_clean_one`: 1 |
| N13 | `save_data.gd`: `to_json()` leaves out `arrivals` | `test_json_round_trip`: 1 |
| N14 | `save_data.gd`: no migration from version 2 | `test_every_older_version_has_a_migration`, and each older save's load: 11 |
| N16 | `main.gd`: the Road Home plays the tutorial | `test_the_road_home_has_no_tutorial`: 1 |
| N17 | `game_state.gd`: an arrival ends the run as a crash | `test_an_arrival_ends_the_run_and_its_end_screen_follows`: 9 |
| N18 | `disaster_director.gd`: the arrival lasts twice `ARRIVAL_SECONDS` | `test_an_arrival_ends_after_arrival_seconds_with_no_disaster`: 4 |
| N19 | `main.gd`: the autopilot's arrival is an error, as its failures are | `test_the_autopilot_reaches_the_finish_and_unlocks_a_legend`: 7 |
| N20 | `collection_screen.gd`: an unlocked legend's card stays hidden | `test_an_unlocked_legend_shows_until_it_is_seen`: 1 |
| N21 | `main.gd`: leaving the road keeps a run clean | `test_leaving_the_road_spoils_a_clean_run`: 1 |
| N25 | `main.gd`: past the last junction, `_turns_before()` errors | `test_an_area_without_a_junction_has_every_turn_behind_it`: 1 |
| N26 | `main.gd`: the run's clock runs while it pauses | `test_the_runs_clock_stops_while_it_pauses`: 1 |
| N27 | `main.gd`: `--finish` takes a negative number | `test_a_bad_finish_argument_is_an_error_and_the_road_is_the_games`: 1 |
| N31 | `legend_unlock.gd`: the unlock picks an area, then one of its legends | `test_each_locked_legend_is_as_likely_as_the_others`: 1 |
| N32 | `save_data.gd`: `arrival_count(finish)` counts every finish's arrivals | `test_record_arrival_counts_and_keeps_the_best_time_and_a_clean_one`: 1 |

**Δ** PRs 3–13's, as built. Each PR's description gives each case's change and the tests that it fails: each exited 1 and failed them, and the files were restored.

| PR | Cases | How they ran, with `run_tests.sh` |
|---|---|---|
| 3, #103 | N33–N45 | The whole suite: 762 tests, and 763 for N45 |
| 4, #104 | N46–N85, N121–N124 | The whole suite: 788 tests, and 790 for N121–N124 |
| 5, #105 | N86–N101 | The whole suite: 797 tests |
| 6, #106 | N102–N120, N125–N130, N138–N163 | The whole suite: 811–823 tests. N130 is N20 on the Book, and N154 fails a frame of the Book, as GUT draws nothing |
| 7, #107 | N131–N137 | The whole suite, on 3ec3ae9: 815 tests |
| 8–12, #108–#112 | N164–N182, N183–N188, N189–N200, N201–N229, N230–N267 | `-gtest=` on the test scripts of the tests that each names |
| 13, #113 | N268–N297 | `-gselect=` on the scripts that each names; N295–N297, the whole suite of 903 tests |

### 6.3 Editor warnings

As docs/agents/checks.md §1 says, a temporary `override.cfg` raised the warnings at level 1 to errors, and `check_scripts.sh` loaded every script. On `main` (81f22e3), 532908a and 4d3d981 it found only `main`'s five: `INTEGER_DIVISION` in `world/greybox_atlas.gd`:135, `ui/main.gd` (:62 on `main` and 532908a, :71 on 4d3d981), `test_greybox_atlas.gd`:15 and `test_iso.gd`:42, and `UNUSED_VARIABLE` `junctions` in `test_road_generator_occupancy.gd`:30. Godot reports only a script's first error, so it ran again without `integer_division`: only `junctions` was left, on each. c153f03 had a sixth, in `game_over.gd`:81, which 93a85f5 fixes (§4.3). So no script that PRs 1–2 add or change has a warning. On f491e55 and on PR 1's port it found the same five, and PL's `make_art.gd` and `art_checks.gd`, which load `greybox_atlas.gd`, fail with it.

**Δ** As built, the check found only `main`'s five at each head of PRs 1–13, but for two warnings, each fixed (§4.3): PR 6's at 5cc4f6b and PR 13's at 3c71ca7. At PR 13's head, `ui/main.gd`'s `INTEGER_DIVISION` is at :101, and `greybox_atlas.gd`'s at :141, as PR 3 moved it.

### 6.4 Verified only in CI or on devices

- **CI.** Each PR's four required checks, and its `test` job's time (§6.1). This plan's PR changes only this file.
- **PRs 1–2** show a player nothing new: no road of the game ends before PR 3, and only `--finish` and `--home` reach an arrival. Their tests check the end screen's words (E3, E5), and E16 starts at PR 3.
- **E16 on the Web, on PRs 3–6, 8, 10 and 13**, by an agent. Start a CI run of the PR's branch with `-f upload-builds=true`, download its Web build and patch its `index.html` (docs/agents/checks.md §4), then play it in Chrome and Firefox, headed under Xvfb, at 360 × 640 and 1280 × 720: `?arg=--autopilot&arg=--finish=3` for a quick arrival and its unlock; `?arg=--autopilot&arg=--area=desert`, which counts nothing, for the last 60 turns, the home stretch and the pier, each with `&arg=--hour=12` and `&arg=--hour=0`; and `?arg=--collected=city` and `=all` for a seal and a full Book, `=all` with `&arg=--home&arg=--autopilot` for the Hitchhiker. Post frames of the arrival, the end screen and the PR's screen on the PR.
- **E16 on the Fold4**, by the owner, on both screens: the PR's debug APK, with the Start choice from the Desert, as a phone passes no arguments (docs/ZONE_SELECT.md Z1); and the same Web build in the Fold4's Chrome, through `adb reverse tcp:8000 tcp:8000` (docs/M4.md Q6). As `--autopilot` keeps its save in memory, drive `?arg=--play&arg=--finish=3` there by hand too, in a new Incognito tab, to the arrival, and reload with no argument: the Book has the unlocked legend, and from PR 8 the title offers the Road Home. **Δ** As built, check every PR at once, on PR 13's build (below).
- **Δ** **E16 on the Web, as built**, by an agent, in Chrome and Firefox at 360 × 640 and 1280 × 720, each PR's frames in its description:
  - PR 3: the car on the pier, `--finish=3`'s unlock, and the Desert by day and by night, in 12 sessions.
  - PR 4: the sunset, the stills, the pan and the zoom, and the jingle, once, as the car stopped: each recording matched `arrival.wav` once, at 0.90–0.93. Nothing flashed: no frame was brighter or darker than both its neighbours by more than 9.4 of 255.
  - PR 5: NEW LEGEND! stayed still for the rest of each run, 15–22 s, and the jingle played once.
  - PR 6: the Book, its seals, the wisp's name broken after "the-", and the unlock.
  - PR 8: the Road choice, and the Road Home's arrivals. PR 10: the strip, its diamond 128 pixels up the 256 at turn 140 of 280, and the car climbing it, with no flash.
  - PR 11: Last Gas's 19 `Polygon2D`s raised no WebGL error; PR 12 adds no `Polygon2D`.
  - PR 13: by day and by night, she stood by the road and faded as the car passed her; then NEW LEGEND!, the Book at 16/16 with her white seal, and her page. `--collected=all` alone gave 15/16, with her silhouette. Nothing flashed: no frame was brighter or darker than both its neighbours by more than 2.9 of 255. The consoles had only Chrome's known `CONTEXT_LOST_WEBGL` and ReadPixels notes, and Firefox's `'try'` warning and its timeouts as a page unloaded.
- **Δ** **E16 on the Fold4, as built**, by the owner, all at once on PR 13's build, [run 44367702653](https://github.com/pompomon/roadgame/actions/runs/44367702653): its artifacts `web` and `android-Android APK`, whose package is `com.pompomon.roadgame`. On both screens, in the APK and in the Fold4's Chrome:
  - PR 3: the pier and the arrival, from the Desert's Start choice.
  - PR 4: the sunset, the stills in view as the car stops, the jingle, and nothing flashing.
  - PR 5: in a new Incognito tab, `?arg=--play&arg=--finish=3` driven by hand: NEW LEGEND! stays still, the jingle plays once, and the goal line is whole.
  - PR 6: the Book, with `--collected=city` and `=all` on the Web: flat grey silhouettes, a glow's a disc, and seals whole or hollow. A tap that rolls a little opens a page, a silhouette's does nothing, and Back closes the page, then the Book. The wisp's name breaks after "the-".
  - PR 7: the debug APK offers every area; a release build, on Pages, shows Start only once an area past the City is discovered.
  - PR 8: in Chrome, through `adb reverse tcp:8000 tcp:8000`, `?arg=--play&arg=--finish=3` to the arrival, then a reload: "Road: To the sea" steps to "Road: Home", and Play drives home from the Desert, heading west, its first turn a right.
  - PR 10: the strip reads by day and by night, the car climbs it with no flash, and the diamond stands at the last farthest.
  - PR 11: Last Gas by the Desert's first straight, by day and by night; a hurt car gets the repair and its ding.
  - PR 12: the records under the bests, with the Road button in place; the postcards read whole; a drag from a postcard scrolls the Atlas.
  - PR 13: she stands by the Road Home on both screens, by day and by night, and fades as the car passes; then NEW LEGEND!, her page and her seal. Time the boot (§9); `adb logcat -s godot` shows no error.

### 6.5 Measurements

The probes ran headless with Godot 4.7.2: P2, P3 and P5 on 93a85f5, whose results §4.4's fixes leave as they were, and P1, P2b and P4 on 4d3d981. P1 is `test_drive_to_the_end.gd`'s print; P2–P4 ran as a GUT script that isn't committed, and P5 changed `Fixtures.schedule()` for a run of the suite.

| P# | What | Result | Used by |
|---|---|---|---|
| P1 | The autopilot drives the game's road, ended at the pier after 280 turns as PR 3 ends it, without the Coast, and the Road Home; seeds 0–4 each, at 60 steps a second | All 10 arrive with full health and no junction dropped: at the pier after 9.6–9.9 min of game time, home after 9.7–10.2 | Q1, E1, E9 |
| P2 | The same two roads, neither with a home stretch, laid to their ends for seeds 0–199, against each seed's `endless()` road | No tile before the finish differs. The finish starts at path tile 1792–2037 at the pier, 1796–2049 at home; a road takes 15–16 ms to lay | E1, E6, E9 |
| P2b | `Fixtures.schedule().ending_at(220, &"pier")`, whose Desert starts at the finish's turn, a home stretch, against `endless()`, seeds 0–199 | Each road is `endless()`'s up to and including its last junction, and the home stretch's from the next tile; the finish comes 4–9 tiles after that junction | E1, §4.4 #4 |
| P3 | `LegendUnlock.pick()` on the game's road with nothing collected, seeds 0–9,999 | Each of the five ★s: 0.196–0.206 | Q2, E5 |
| P4 | P1's arrivals, stepped on until the car stopped; the save's JSON | The pier: 4.19–5.79 tiles/s, stopped in 2.40–3.32 s. Home: 2.98–4.45, stopped in 3.13–4.02 s, the slowest on `ARRIVE_ROLL_SECONDS` to within a step. Each car stopped on the centreline, within 0.002 tiles and 0.02°. The save: 260 bytes new, 585 after `--finish=3`'s first arrival and unlock, 1,662 with every area discovered, the five ★s seen and unlocked and both finishes reached | W5, W20, §5.4 |
| P5 | `Fixtures.schedule()` ending at the pier after 280 turns, as PR 3 makes the game's road, under the whole suite | With `path_until_turn()` stopping at a finish: 13 of 640 fail, W6's ten and PR 1's three, each with "the road ended at turn 280, before turn 300". Without it, `test_the_last_area_goes_on_forever` never ends: Godot grew to 6.7 GB in 32 s, and the kernel killed it. With W6's 13 tests on `Fixtures.endless()`, all 640 pass | W6, PR 3 |

---

## 7. Owner actions

| When | Action | How |
|---|---|---|
| Done | Merge this plan's PR | #84, merged as 4844183, approved the plan, and agents landed PRs 1–3 (#101–#103) |
| Now | Land #104, PR 4, if its two Δs are right (E7, §5.8) | Squash it; agents then land #105 (§4.2) |
| Now | Choose #106's row labels | (a), (b) or (c), in [the options](https://github.com/pompomon/roadgame/pull/106#issuecomment-6970573638); then land #106, after which agents land #107–#112 in order |
| Now, if wanted | Play the prototype's arrival | `gh workflow run ci.yml -R pompomon/roadgame --ref eg/prototype -f upload-builds=true`, then docs/agents/checks.md §4's download and patch, and `?arg=--autopilot&arg=--finish=3`, or with `&arg=--home` |
| Now | E16 on the Fold4, on both screens, for PRs 3–13 at once | §6.4's list, on PR 13's build, [run 44367702653](https://github.com/pompomon/roadgame/actions/runs/44367702653) |
| To land EG | Land PR 13 (#113) once PRs 1–12 have landed and the device checks pass; then PR 14, from `main` | Squash each. Before deleting a merged PR's branch, retarget the next PR to `main` (§4.2) |
| After PR 14 | Tag the prototype, which this plan cites, and delete EG's branches | `git fetch origin eg/prototype && git push origin FETCH_HEAD:refs/tags/archive/eg/prototype`, then `git push origin --delete eg/plan eg/prototype` and §4's 14 branches |

---

## 8. Risks

| Risk | Impact | Mitigation |
|---|---|---|
| The end is far | A run to the pier takes about 10 minutes when nothing goes wrong (P1). Most runs fail long before it, and a failure at turn 250 costs 9 minutes | Every run still pays: a failure meets a legend (PL), and an arrival unlocks one. Departures starts from any area found (PR 7), the strip shows how near the end is (PR 10), and pit stops repair the car (PR 11): Rosewater's catch-up feature. The finish's turn is one number in `schedule.tres` (Q1), to tune on the owner's runs |
| A test drives past the end | Once PR 3 ends the game's road, a test that drives it 300 turns never ends, and takes the machine's memory (P5) | W6's tests drive `Fixtures.endless()`, and `path_until_turn()` errors and stops at a finish (PR 3) |
| The Road Home looks wrong | It mirrors the road and reverses the areas, so the bridge, the tunnel, the props and the areas' borders meet the road from new sides | `test_drive_to_the_end.gd` drives it home on five seeds (P1), and PR 8's E16 checks it before the title offers it |
| An older build meets a newer save | Versions 3, 4 and 5 add keys. A build reads a newer save but never writes it (`save_service.gd`:155), so an older PR's APK installed after a newer one saves nothing | Check the PRs in order, or from a new save: the Web build in an Incognito window |
| Pit stops change a rule | `plan.md` §2.4: no pickups, and health doesn't regenerate (W24). Pit stops make the end easier for every player | PR 11 comes late, and can be dropped alone (Q10) |
| The Coast drags | 20 tiles with nothing to do, about 3 s at the speed cap (§5.8) | It's the victory lap, with the sea ahead and PR 4's sunset; if it drags on the Fold4, its length is one number in `coast.tres` |
| A seed doesn't replay its unlock | The unlock draws from the legends not yet collected, so a seed unlocks another legend on a save with another collection | As with PL's picks (docs/POOLS.md §8): a report needs the seed and the collection |

---

## 9. Notes for later work

- **Souvenirs and lore tiers** (Q7). Each legend could leave something on its page at a second sighting, as Hades' Codex adds lore: the worm's tooth, the bus's ticket.
- **C's Daily Road and medals** (the brainstorm's option C). A seed of the day, the same for every player, with its pier time on the title, and medals for each area's time. A shared board needs a server, which the game hasn't.
- **More finishes.** A schedule's `finish` is an id, so a later road can end elsewhere, such as a mountain pass, with arrivals of its own.
- **Lazy loading** (docs/POOLS.md §9). The Coast, the pier and the Hitchhiker add to the boot; time it on PR 13's APK.
- **M7.** A long haptic pulse as the car stops on the pier; the postcards as images to share; and the records in a cloud save, where each arrival keeps the best of both.
