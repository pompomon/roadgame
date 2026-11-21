# The Speedup: the Road to the Sea in Five Minutes

Done, 2026-11-20 to 2026-11-21: the plan PR #116, then #118. The plan called the work SP. Both roads end after their 100th turn, not their 280th (E1), and the autopilot drives either in about four minutes: each area has fewer turns, the straights from the Meadows on are longer, the top speed grows faster, and Rural, the Meadows and the Desert turn a day in 60 s. The full plan, with its verification, negative cases and review history: `git show 72fcd5f:SPEEDUP_PLAN.md`; the tag `archive/sp/prototype` keeps the prototype's commits that it cites.

## 1. Goal and exit criteria

A whole road in one sitting, in at most five minutes on all but one of the 10,000 runs measured (Q15). Each area keeps its character and its legends, and each long area past the City still shows its night. E1–E9 are met.

- **E1.** Both roads end after their 100th turn, but for a rare first run's (§4.3). The autopilot drives each to its end with no disaster, crash or damage and no junction dropped: on seeds 0–9 within `MOST_SECONDS`, 300 s of game time, and on each road's slowest seed of P1, 4993 to the pier and 352 home, within `SLOWEST_SECONDS`, 310 s (Q15). Seeds 0–9 take 235.0–255.5 s to the pier and 239.4–280.9 s home.
- **E2.** Fewer turns and longer straights after the City: the areas switch at turns 20, 44, 68 and 78, and the Coast starts at 100 (§5.1); on a rare first run, each a turn or two later (§4.3). From the Meadows on, each area's shortest and longest straights are longer than Rural's, 3 and 7 tiles, the Coast's home stretch too.
- **E3.** Each zone of Rural, the Meadows and the Desert that the car leaves lasted into its night, by its area's `day_seconds` as loaded: in a 60 s day, 32.5 s in. No area's day is shorter than 55.68 s, which `validate()` checks (§5.3).
- **E4.** Nothing else changes (Q8): the road to the sea is `main`'s up to and including the junction of its 20th turn (P7), and only `endless()`'s digests change (U7).
- **E5.** The Road Home stays the mirror (Q2).
- **E6.** The route strip and the save follow the road's end (§5.4, §5.5).
- **E7.** The docs: PR 1's notes (§5.8), then this summary.
- **E8.** A desktop run's frames show the new road from the City to the end screen (§6).
- **E9.** CI's checks pass on each PR.

## 2. Findings

- **U1.** A run to the end took about ten minutes: 246 of the 280 turns came after the City's 34, and the Meadows' 100 alone took 217 s (P5).
- **U2.** With 120 s days, only about half of SP's shorter zones would reach their night, and almost none of Rural's (P3).
- **U3.** No test bounded a run's time.
- **U4.** The top speed grows with the distance driven, so a shorter road ends slower: at `main`'s growth, the cap would end at 5.57–5.99 tiles/s at the pier, not 7.0 (Q4).
- **U5, U6.** The strip's test expected a pixel or so a turn (§5.4), and 13 test files held the old road's numbers.
- **U7.** `PATH_DIGEST` and `ROAD_DIGEST` digest `endless()` on seeds 0–19 to turn 300, so SP's areas change them (docs/ROADGEN.md §6.1).
- **U8.** A save keeps the old road's records (§5.5).
- **U9.** A road has about 113 junctions, not 324, so at 1% errors a junction about 32% of runs arrive, not 4%, and the City has 20% of the turns, not 12%.
- **U10.** 82–84% of Rural's zones end at night, so the next zone's morning fades in from it, in 2.33 s (§5.3).
- **U11, U12.** Comments and docs named the old road (§5.7, §5.8).
- **U13.** A rare seed takes over 300 s, as each junction's kind is its own roll: 14 or more decoys, about 2.6 s each, come once in about 1,740 of the Meadows' zones. Pier seed 4993's Meadows had 14 among 38 junctions, 99.9 s against 73.7 s on average: 306.4 s in all (P1). In the first draft's Desert, with decoys at 0.2, home seed 3879 had 15: 301.6 s (P10), hence Q14.

## 3. Decisions

The owner answered Q1, Q4 and Q9, and kept the other defaults.

- **Q1.** The owner's turns: the City 20, Rural 24, the Meadows 24, the Village 10 and the Desert 22, so the areas switch at turns 20, 44, 68 and 78, the Coast starts at 100, and the road ends after its 100th (E1, E2). P1's runs arrived in 222.2–306.4 s, about four minutes (Q15).
- **Q2.** The Road Home stays the mirror: the Desert from turn 0, the Village from 22, the Meadows from 32, Rural from 56 and the City from 80, and `home` after 100.
- **Q3.** The Meadows' straights are 6–12 tiles, from 3–7; the Village's 4–8, from the defaults' 2–5; the Desert's 6–12, from 3–8. They take 2.6–3.1 s a turn, where Rural's 3–7 take 2.1.
- **Q4.** The owner's growth: `TOP_SPEED_GROWTH` is 0.0035 a tile, from 0.002, so the cap, 7.0 tiles/s, comes after 857 tiles, not 1,500, and a run is 4.1 s quicker to the pier and 3.5 s home on average (P6). The test checks it as a number.
- **Q5.** Rural, the Meadows and the Desert turn a day in 60 s, whose dusk comes 25 s in and night 32.5 s in, so that their zones, 41–109 s long, reach their night (P3). The City, the Village and the Coast keep 120 s.
- **Q6.** The strip stays 40% of the HUD's height (§5.4).
- **Q7.** The save stays at version 5, with no migration. A save from `main` keeps its best time until an arrival beats it, and its farthest turns, up to 280, which the goal line, the strip and the Hitchhiker clamp to the road's 100 (§5.5).
- **Q8.** Nothing else changes (§5.6).
- **Q9.** The Village's 10 turns, about 26 s, are an interlude.
- **Q10.** The five minutes are the run's clock, which the end screen shows, as `--autopilot` drives it, without the tutorial (P1). On a first run the clock starts at the tutorial's end, and read 231.4–274.2 s at the arrival (P9).
- **Q11.** Keep Driving's road is the Desert forever from turn 78, so its 300 turns take 758.8–833.6 s, about 29% longer than `main`'s 607.5–656.2 s (P8). A Departure has as many turns fewer: from Rural, the Meadows come at its turn 24 and the Desert at 58.
- **Q12, Q13.** PR 1 changes the docs in place, and PR 2 adds this summary. The owner was to land both, PR 1 after an optional run on the Fold4 (§4.2).
- **Q14.** The Desert's decoys fall to 0.15, from 0.2, and its side roads rise to 0.3, from 0.25, so a zone's junctions, and its time, vary less, and 0.45 of them still have a trick (U13). At 0.2 and 0.25, the model put 5 of 20,000 runs a road over 300 s, against none.
- **Q15.** Five minutes is a target, not a cap on every seed. Of P1's 10,000 runs, 5,000 seeds a road, only pier seed 4993 took longer, 306.4 s (U13), so E1 bounds each road's slowest by 310 s. A zone's decoys have no limit: the model puts about one run in 20,800 over 300 s, the slowest of 2,000,000 at 315.7 s (§9).

## 4. Work breakdown

- **PR 1** (#118): the schedules, the areas' straights, chances and days, `TOP_SPEED_GROWTH`, the rows of props across the view and the late areas after the tutorial's road (§4.3), the tests, and notes in the docs.
- **PR 2**: this summary, IP's M7 notes, and SP's learnings in the guidelines.

### 4.2 Landing

The plan left both PRs to the owner (Q13). The owner had PR 1 merge after C's fix (§4.3), as a82e764, and lands PR 2, which changes `AGENTS.md`.

### 4.3 Review fixes

Three of Copilot's findings on PR 1 changed the design:

- **A.** A decoy joins two straights of the Meadows or the Desert into a run of up to 25 tiles, whose view reached up to 370 px past a row's `PROP_SPREAD`, onto bare ground. `PropLayout.span()` also spreads each row `PROP_VIEW_SPREAD`, 3 tiles, either side of each of the `PROP_AHEAD` path tiles below it: up to 15 tiles a side, for 2–6% more sprites. The tallest view reaches about 300 px across from the car, and 3½ tiles 448 px.
- **B.** `test_road_generator_determinism.gd` compared 2,000 path tiles of `schedule()`, whose road reaches the pier at about tile 900, with no junction past it. It takes `endless()`'s, which reach about turn 200.
- **C.** On a first run, the tutorial's road can hold the City's 20th turn; Rural then comes at the City's first junction past it, a turn or two late (docs/TUTORIAL.md §5.5). `RoadGenerator._due_entry()` moves `_turn_base` on by as many turns, so the City takes the delay, the later areas keep their turns, and the road ends after its 101st or 102nd (`test_road_generator_tutorial.gd`: `test_an_entry_that_comes_late_moves_the_later_ones_and_the_finish_on`). That needs at least 17 of the tutorial's turns past its switch, where seeds 0–9,999 held 6–15: about 1.5e-7 of first runs without a mistake, in a model. The owner chose it over a bound on the tutorial's road. The strip's ticks stay at the schedule's turns, so its car reaches each later area's a turn or two early, and waits at the top from turn 100.

## 5. Design

### 5.1 The turns

`areas/schedule.tres`, with P1's mean times to the pier:

| Area | From turn | Turns | Straights | Day | Time |
|---|---|---|---|---|---|
| City | 0 | 20 | 2–5 | 120 s | 35.2 s |
| Rural | 20 | 24 | 3–7 | 60 s | 50.3 s |
| Meadows | 44 | 24 | 6–12 | 60 s | 73.7 s |
| Village | 68 | 10 | 4–8 | 120 s | 26.1 s |
| Desert | 78 | 22 | 6–12 | 60 s | 63.1 s |
| Coast | 100 | – | 20 | 120 s | 3.6 s |

`main`'s switched at 34, 100, 200 and 220. The tunnel leads into Rural, the bridge into the Meadows and Last Gas into the Desert, so the pit stops are 24 and 34 turns apart, not 66 and 120. `validate()` keeps each gap within `BUFFER_REFILL_AT`, 37 tiles (docs/M4.md K1): the game's are 6–21, the widest the Meadows' 18 behind the bridge, 5 + 12 + 1, and the Coast's 21, from EG; home, 13.

### 5.2 Straights and speed

The run's cap is `minf(GLOBAL_SPEED_CAP, BASE_TOP_SPEED + dist_total * TOP_SPEED_GROWTH)`: 4.0 tiles/s, 0.0035 more a tile driven, at most 7.0. The car brakes before each junction, so a longer straight takes less time a tile. Path tiles a turn grew from `main`'s 7.1 to 11.8 in the Meadows, 5.35 to 8.3 in the Village and 8.0 to 11.7 in the Desert. A run is 786–1,111 path tiles, not 1,829–1,998, and its cap ends at 6.64–7.0 tiles/s at the pier.

P2's model, about 0.4% slow against P1, puts the owner's turns at 209.2 s to the pier with `main`'s straights and 253.0 s with SP's: the straights add 44–47 s.

### 5.3 Days

A 60 s day's night lasts from 32.5 s to 53.75 s, then dawn to 60 s. `DayCycle.least_day_seconds()`, 55.68 s, is the shortest day whose light changes within `LIGHT_MAX_RATE`; a 60 s day uses 92.8% of the rate. The City's zones end by day, at 12:36–14:56, so the first night still comes in Rural on the road to the sea, and in the Desert home. 60.8% of the long areas' zones last into a second morning, and 28.4% end at night, where 39 of `main`'s 120 did (P4).

### 5.4 The route strip

The strip keeps 40% of the HUD's height (Q6), 256–368.8 px on the reference screens. `RouteStrip.height()` puts turn t at `roundi(clampf(t / finish_turn, 0, 1) * roundi(length))`, so its car climbs 2.56–3.69 px a turn, where `main`'s 280 turns gave 0.91–1.32. Each climb is the length over 100 turns, rounded down or up, so the car climbs evenly, and at most `floori(CAR_HEIGHT / 2.0)`, 4 px, half its mark's height.

### 5.5 The save

Saves stay at version 5 (Q7), and `V3_FINISH_TURN`, 280, still migrates version 3's. `record_arrival()` keeps the least time, so an arrival on the new road replaces `main`'s best only if it is faster: on every seed measured it would be, at most 306.4 s on the autopilot (P1) against at least 561.4 s on `main` (P5). A player whose overall best on `main` reached turn 100 without arriving reads "Next: reach the sea. Your best: turn 100 of 100" until they arrive. The Atlas's best turns aren't clamped: they are history.

### 5.6 What stays

On 200 seeds, the road to the sea is `main`'s up to and including the junction of its 20th turn, and differs by its 21st; the Road Home differs by its 10th turn (P7). The tutorial, from whose end the schedule counts, doesn't change: on seeds 0–99 it ended at 17.9–22.9 s, and the car arrived 252.1–294.1 s after its start (P9). The legends, their pools, the set pieces and the music stay.

### 5.7 Tests

`test_car_sim_speed.gd` checks the growth at 500 tiles, 5.75 tiles/s, below the cap. The drives count `damaged`, as a pit stop repairs the health read at the end. Tests that use 280 as a value, for a finish or an arrival of their own or to migrate version 3, stay.

### 5.8 Docs

PR 1 changed `plan.md` in place and added "Since SP" notes to six summaries; earlier plans' history, such as docs/ENDGAME.md W6, stays.

## 6. Verification

The checks passed on PR 1, locally and in CI. P1–P10 ran as GUT scripts, headless at 60 steps a second, or in Python, in `tools/sp/` at 17f5ff6.

- **P1.** The autopilot drove each road to its end without the tutorial, seeds 0–4999 a road: all 10,000 arrived with full health. To the pier, 223.1–306.4 s, 252.2 s on average, p99 278.9 s; home, 222.2–294.5 s, 253.1 s, p99 278.2 s.
- **P2.** The model of §5.2, in Python.
- **P3.** P1's 30,000 zones of Rural, the Meadows and the Desert: 48.9% would reach their night with 120 s days, 87.3% with 90 s, 99.6% with 80 s, and all did with 60 s. The shortest, a Rural zone of 40.97 s, had 8.47 s of night.
- **P4.** P1's zones of Rural, the Meadows and the Desert: the light as each ends, with 60 s days (§5.3).
- **P5.** `main` at ec6f54d: the autopilot drove each road to its end, seeds 0–19 (U1).
- **P6.** P1 with `main`'s growth, 0.002, seeds 0–199 (Q4).
- **P7.** Both roads, laid on `main` and on 98ffdd5 for seeds 0–199, digested up to the junctions of turns 1, 10, 16, 19, 20, 21, 22, 24 and 34 (§5.6).
- **P8.** `test_autopilot_300_turns.gd`'s drives, on `main` and 98ffdd5 (Q11).
- **P9.** First runs: the autopilot through the tutorial, then to the pier, seeds 0–99 (Q10, §5.6).
- **P10.** The first draft's P1, at 339b126, seeds 0–4999 a road (U13).
- **P11.** #121's grass on PR 1's rows, docs/HEADLIGHTS.md P4 again: in the main scene from the Meadows, `PropScatter.update()` took 100.8 µs a frame on `main` (4ea42e5), 187.8 with the grass (312885f), 116.2 on PR 1 (52ee443) and 206.9 with the grass (94fb19a): 10% more than 312885f's, and 2.05 times 4ea42e5's, about twice, as docs/HEADLIGHTS.md E11 asks.

E8: Movie Maker's frames of seed 1's road, on the prototype at 98ffdd5 and on PR 1 at 3b79952, show each area at its turn, the nights of Rural, the Meadows and the Desert, with the headlights at 3b79952, and the end screen at 255.25 s, "Time: 4:10". PR 1 changes nothing that only the Web or Android does, and no Fold4 run is recorded (Q13).

## 7. Owner actions

None left but landing PR 2, then tagging `sp/prototype` as `archive/sp/prototype` and deleting `sp/plan`, `sp/prototype`, `sp/1-road` and `sp/2-docs`, with the commands in PR 2's body.

## 8. Risks

- **Five minutes is a target** (Q15): a change to the car, the autopilot, the generator or an area can push more seeds over, which only E1's seeds would show. Run P1 again after one.
- **A player is slower:** off the road the car keeps 0.45–0.6 of its speed, so a player's run on a slow seed can pass five minutes.
- **The end comes sooner** (U9), **the car is faster** (Q4), and **the light changes faster**, near `LIGHT_MAX_RATE` (§5.3), which `test_daylight_run.gd` asserts each frame of a fade.
- **Old saves** carry `main`'s records over (Q7).
- **A first run's Rural can come late**, and the strip's car run early (§4.3).
- **A broken schedule takes the machine's memory:** `test_road_generator_tutorial.gd` loops forever on the fallback road, as on `main`. Run such a case on its script alone.

## 9. Notes for later

IP §4 M7 carries these:
- **Device QA:** a road takes about four minutes, so M7.5 can drive both, by day and by night, in one sitting, and M7.6's screenshots are at turns 0, 20, 44, 68 and 78. Nobody has read the Fold4's frame rate in the Meadows, where PR 1's wider rows and #121's grass make `PropScatter.update()` take about twice 4ea42e5's time (P11): the owner waived docs/HEADLIGHTS.md E11's reading on #121. HL's Fold4 routes (`git show a82e764:HEADLIGHTS_PLAN.md` §6.4) are timed on the road before SP: on a build with it, the headlights come on 28.75 s into a zone of Rural, the Meadows or the Desert, not 57.5 s, the City's zones end by day (§5.3), and the tunnel and the bridge come at turns 20 and 44.
- **Five minutes on every seed** needs a cap on each zone's decoys (Q15); **a time to beat**, a par from the autopilot's time on the same seed; **version 6** (Q7), old records clamped to the road's end and best times over five minutes dropped; **Keep Driving** (Q11), an endless schedule of its own to cross more areas; and **the tutorial test's loop** (§8), a bound.
