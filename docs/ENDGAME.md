# The End of the Road and the Book of Legends

Done, 2026-11-15 to 2026-11-19: the plan PR #84, then thirteen stacked PRs, #101–#113. The plan called the work EG. After its 280th turn the road ends at a pier on the Coast. A run that drives the whole road there arrives, the game's first win, and unlocks a legend not yet collected; the first arrival opens the Road Home and Keep Driving. The collection became the Book of Legends, and a full Book brings the Vanishing Hitchhiker. The full plan, with its verification, negative cases and review history: `git show 1a067fc:ENDGAME_PLAN.md`; the tag `archive/eg/prototype` keeps the prototype's commits that it cites.

## 1. Goal and exit criteria

Nothing kept in the save makes a run easier or harder (`plan.md` §2.6), and the pit stops repair every run alike (Q10). E1–E18 are met; those not below cover the arrival, its records, the Book, Departures, the postcards, the docs and the checks.

- **E1.** A schedule with a finish ends its road (§5.1).
- **E5.** An arrival that counts unlocks a legend not collected (§5.5).
- **E6.** A road without a finish is laid as before EG, so the golden digests pass unchanged. `endless()` is the road of Keep Driving and of the tests that drive past turn 280.
- **E7.** The Coast, the pier and the arrival's scene (§5.8).
- **E9.** The Road Home (§5.6, §5.12).
- **E11.** Keep Driving (§5.13).
- **E12.** The route strip (§5.14).
- **E13.** Pit stops (§5.15).
- **E15.** The Hitchhiker (§5.17).
- **E16.** The arrival reads as a win without words, and NEW LEGEND!, the Book and the strip read at 360 × 640, with nothing flashing. An agent checked them on the Web, in Chrome and Firefox; the owner on both Fold4 screens: "Fold4 checks approved" (#106), "Fold4 review done" (#113).

## 2. Findings

- **W1.** The game had no end and no win. **Δ plan.md §1, §2.5, §3.6:** the finish and the arrival (§5.1, §5.2).
- **W2.** An arrival would end as a crash. **Δ plan.md §7.3:** `State.ARRIVED` (§5.3).
- **W3.** The save had no room for arrivals or unlocks. **Δ plan.md §9:** version 3 (§5.4).
- **W6.** Once the road ends, the tests that drove past turn 280 fail, and `Fixtures.path_until_turn()` looped until the OOM killer ended it, at 6.7 GB: they drive `Fixtures.endless()`, and it errors at a finish.
- **W9.** Flipped from N, a road's first right would head E, across the screen. **Δ plan.md §3.2:** a mirrored road starts heading W, so its first right heads N (§5.6).
- **W10.** The tutorial's loops are laid for a road that starts heading N, so a mirrored road has no tutorial (`_tutorial_wanted()`).
- **W11.** With no junction ahead, `_turns_before()` errored: on a finished road, every turn is behind the car.
- **W14.** `seen_disasters()` lists the unlocked as collected: never unlocked again, and weighed as seen by PL's picks (Q3).
- **W15.** The end screen's words for an arrival: "You reached the end of the road!".
- **W17.** A home stretch, a last area that starts at the finish's turn, has no junction and no pool: `endless()` leaves it out, or it would be one straight forever.
- **W18.** The pier, and what lies beyond it, would draw as road: they draw as planks and the sea, and `WorldRenderer.build()` checks the finish's scene (§5.8).
- **W19.** The tests that list the game's areas gain the Coast; those of the pools and of wrong turns loop over `endless()`'s areas.
- **W22.** A run that didn't drive the whole road keeps its areas' bests, not the overall ones (§5.11).
- **W23.** **Δ IP §5.3:** the unlock's stream, `hash("<seed>:unlock")` (§5.5).
- **W24.** **Δ plan.md §2.4, §13:** health regenerates at the pit stops, still with no pickups, as Q10's default stood (§5.15).
- **W25.** An export breaks a label's lines only at spaces, without the text server's 4 MB of ICU data: `BookCell.break_hyphens()` breaks a word too wide after a hyphen.
- **W26.** Silhouettes and unearned seals had 1.05:1 to 1.63:1 with their ground, where WCAG 2.2 1.4.11 asks 3:1. A silhouette is its still's whole shape, flat in `BookScreen.SILHOUETTE`, 3.28:1 with its cell, so a glow's is a disc; an unearned seal is hollow (§5.10); the Atlas's stamps, hollow or whole, stand out 3:1 from their postcards (§5.16).
- **W28.** Godot 4.7.2's ScrollContainer scrolls by no key. Where the focus can't move, the keys scroll: an arrow by `Tuning.BOOK_KEY_SCROLL`, an eighth of the view, as a wheel's notch does, Page Up and Down by a view, Home and End to the ends.
- **W32.** `area_changed` comes before the move's road checks, and off the road too: `CarSim.area_crossed` tells a crossing on the road, from an area's last path tile onto the next's first (§5.16).
- **W33.** At 360 × 640 the Atlas's scroll shows 472 px of its six postcards' 1,130: the keys, through `MenuScreen.scroll_by_key()`, and a drag from a postcard scroll it.

## 3. Decisions

The owner chose a random legend not collected for the unlock, and the Road Home heading W, and approved the other defaults on 2026-11-17: "Defaults are approved" (#84).

- **Q1.** The road ends after its 280th turn, at a pier. The Coast starts at that turn, a home stretch with no junction and no legend, so the Desert stays the climax.
- **Q2.** The unlock: any legend not collected, each as likely (§5.5).
- **Q3.** An unlocked legend is collected (W14).
- **Q4.** Only a run that drove the whole road records an arrival, unlocks a legend or sets an overall best (§5.4).
- **Q5.** A failure picks its legend as PL does (docs/POOLS.md Q2).
- **Q6.** A crash plays no legend.
- **Q7.** No lore tiers (§9).
- **Q8.** The Book is a grid: an area a row, a pool's slot a column (§5.10).
- **Q9.** The 16th page is the Hitchhiker (§5.17).
- **Q10.** Pit stops repair the car (W24).
- **Q11.** Departures, from each area discovered, in every build (§5.11).
- **Q12.** The Road Home opens after the first arrival (§5.12).
- **Q13.** Keep Driving, after the first arrival (§5.13).
- **Q14.** A route strip on the HUD (§5.14).
- **Q15.** Records and postcards, in the save's version 5 (§5.16).
- **Q16.** NEW LEGEND! plays a jingle, and its words stay still (§5.9).
- **Q17.** The arrival lasts `ARRIVAL_SECONDS`, 5.0: past the roll, at most `ARRIVE_ROLL_SECONDS`, 4.0, and within the director's `DISASTER_TIMEOUT`, 6.0.
- **Q18.** Each PR folded its Δs into `plan.md`, IP and docs/ZONE_SELECT.md; PR 14 wrote this summary.
- **Q19.** One stack, PRs 1–13, then PR 14 from `main`.

## 4. Work breakdown

- **PR 1** (#101): the road's end, the arrival and the mirror (§5.1, §5.2, §5.6).
- **PR 2** (#102): the run's end, its records, the unlock and the debug flags (§5.3–§5.7).
- **PR 3** (#103): the Coast and the pier.
- **PR 4** (#104): the arrival's scene.
- **PR 5** (#105): NEW LEGEND! and the next goal.
- **PR 6** (#106): the Book.
- **PR 7** (#107): Departures.
- **PR 8** (#108): the Road Home on the title, and each road's farthest turn.
- **PR 9** (#109): Keep Driving.
- **PR 10** (#110): the route strip.
- **PR 11** (#111): pit stops.
- **PR 12** (#112): records and postcards.
- **PR 13** (#113): the Hitchhiker.
- **PR 14**: this summary.

### 4.2 Landing

Agents landed the PRs in order with `tools/agent/land_pr.sh`, but PR 4, which the owner landed to approve its stills over the sea and its zoom (§5.8). PR 6 waited for the owner to approve its unlabelled rows, and PR 13, which the plan left to the owner, for the Fold4 checks (E16).

## 5. Design

### 5.1 The road's end

`AreaSchedule`'s `finish` names the finish's set piece, and `finish_turn` counts the turns before it from the City's first turn after the tutorial. `ending_at()` ends a copy sooner, for tests and `--finish`; `endless()` drops the finish and a home stretch (W17); `starting_at()` brings the finish as many turns sooner. Once `RoadGenerator._finish_due()` holds, no junction follows: the straight leads to the finish's `FINISH_TILES`, 8, the first of which sets `finish_index`, then to `BEYOND` tiles. Neither draws a number, so up to its last junction the road is `endless()`'s (E6).

### 5.2 The arrival

`JunctionTrigger` arrives as the car enters the finish, or rejoins the road on it, with every junction behind it, never after a mistake or in the tutorial. `CarSim` enters `State.ARRIVED`, steers onto the centreline and brakes evenly, to stop `ARRIVE_STOP_SHORT`, 0.5 tiles, before the centre of the finish's last tile, or within `ARRIVE_ROLL_SECONDS` if it came slowly.

### 5.3 The run's end, its sequence and its clock

`GameState.State.ARRIVED` leads to GAME_OVER or TITLE (W2). A run's `seconds` count while RUNNING outside the tutorial; `clean` holds until the car leaves the road outside it. The director plays no disaster for `ARRIVAL_SECONDS` (Q17), then the end screen shows W15's words and "Time: 9:41".

### 5.4 Records and the save's version 3

Version 3 adds `arrivals` by the finish's id, each `{count, best_seconds, clean}`, and each disaster's `unlocked`; `_v2_to_v3()` changes nothing, as `_entry()` fills in missing keys (W3). `SaveService.record_arrival()` saves at once. Only a run from the whole road's first area counts (`_drives_whole_road()`, Q4); the others arrive and show their time.

### 5.5 The unlock

`LegendUnlock.pick()` draws one of the whole road's pools' legends, also on `--finish`'s, neither seen nor unlocked, each as likely, on `hash("<seed>:unlock")`'s stream, so the other streams draw as before (W23): over 10,000 seeds, each of five came 0.196–0.206 of the time. The end screen names it, or says "Every area's legends are in your book.", as the Hitchhiker is in no pool. PL's picks weigh it as seen (W14).

### 5.6 The Road Home

`areas/schedule_home.tres` drives back: the Desert from turn 0, the Village from 60, the Meadows from 80, Rural from 180 and the City from 246, then `home` after 280. It is `mirrored`, starting W (W9), with no tutorial (W10), and `setpieces/home.gd` ends it at a fence and a house. Its arrivals count under `home`.

### 5.7 The debug flags

`--finish=<turns>` ends the road sooner, and a `--finish` run from the City counts; `--home` drives the Road Home with `--play` or `--autopilot`; `--collected=<area>` or `=all` marks legends seen.

### 5.8 The Coast, the pier and the arrival's scene

The Coast starts at turn 280, with `finish = &"pier"`: one 20-tile straight, no junction or pool (Q1), and seven props. `setpieces/pier.gd` draws the sea (`Pier.at_sea()`, a half-plane) and the pier's planks (W18). The arrival's scene, in its 5.0 s: `DayCycle.hold(ARRIVAL_HOUR)` brings the sunset at 18.5, the light following at `LIGHT_MAX_RATE`, with no flash; `Pier.welcome()` stands the collected legends' stills over the sea past the pier, in the Book's grid, as the 448-px shore can't show whole in a 360-px view, a glow held by `LegendStill.strength()`, a small frame scaled up whole (`STILL_MIN_SIDE`); `CameraRig.arrive()` pans to them, and zooms out to 1 where their 338 px don't fit zoom 2's 320 (`arrival_zoom_for()`); and `arrival.wav` plays as the car stops.

### 5.9 NEW LEGEND! and the next goal

A legend that the run met or unlocked, not collected as it started, shows NEW LEGEND! in still letters, and `new_legend.wav` plays once (Q16). One line gives the next goal, the first that holds: reach the sea, drive the Road Home, find the legends missing, find the Hitchhiker, arrive clean, beat the best time.

### 5.10 The Book of Legends

`ui/book_screen.gd` reads the pools, whatever their size: an unlabelled `BookRow` for each area, as the owner chose, and a `BookCell` for each slot, under "Legends 7/15"; the title's button still says "Disasters". A legend seen shows its still and opens its page: name, sightings, fate and lore. One unlocked shows "Not seen yet", and its page no fate. One not found shows its silhouette (W26) and initials, "P______ B__". An area all found earns a whole seal. Names break after a hyphen (W25); a drag scrolls past `BOOK_SCROLL_DEADZONE`, 8 px; a screen reader's focus reaches the count and a page's lines; the keys scroll (W28).

### 5.11 Departures

**Δ docs/ZONE_SELECT.md Z4, Z5:** every build offers a start from the areas discovered (`TitleScreen.departures()`), but a home stretch; a debug build, every area. With `GameState.whole_road` false, such a run keeps its areas' bests, discoveries and legends, not the overall bests (W22).

### 5.12 The Road Home on the title

After an arrival at the pier, the title's Road choice offers "Road: Home" (`TitleScreen.offered_roads()`); a retry keeps the road, a reload doesn't. `GameState.road` names the road that a run drives whole. Version 4 adds each arrival entry's `farthest` turn, which a run raises; `_v3_to_v4()` gives the pier's its finish's turn with an arrival, else `min(best.turns, 280)`.

### 5.13 Keep Driving

After the first arrival, "Road: Endless" drives `endless()`, the Desert forever: its runs count as before EG, never arrive, and show no strip.

### 5.14 The route strip

On a road with a finish, `RouteStrip` runs up the HUD's right edge, 40% of its height: ticks at the areas, a flag, a triangle for the car and a hollow diamond at `farthest`, shapes, not only colours. It draws in `_draw()`, above `Daylight`.

### 5.15 Pit stops

`AreaScheduleEntry.pit_stop` marks the way into an area: the tunnel, the bridge, and Last Gas, a filling station, as the Desert starts, or as the Village does going home. Past one, on the road, `CarSim` adds `PIT_STOP_HEAL`, 50, up to `START_HEALTH`, once each a run, with `repair.wav` (W24); a departure's first area has none. `Fixtures.signature()` leaves `pit_stop` out, so the digests stay.

### 5.16 Records and postcards

Version 5 adds each atlas entry's `stamped`, for a crossing with no damage, which `CarSim.area_crossed` (W32) and `damaged` tell `GameState`; an arrival crosses the road's last area. The Atlas's cards are postcards, `MenuCard`s, that scroll (W33). The title shows the arrivals, the best time and a clean arrival; the end screen, "New best time!" (`SaveData.beats_best_time()`).

### 5.17 The Vanishing Hitchhiker

With the pools all collected, until found, she stands across the Road Home, `HITCHHIKER_ASIDE`, by the last plain straight before the junction of its farthest turn, or the finish once home (`Hitchhiker.road_turn()`), so a departure past that turn misses her; with no such straight, it's an error and she stays hidden. Passing her in a run that goes on finds her: she fades in `HITCHHIKER_FADE_SECONDS`, `SaveService.record_found()` saves her, and NEW LEGEND! shows. In no pool, she is never unlocked or picked; the Book counts 16 once her row shows.

## 6. Verification

The five checks passed at each PR's head, locally and in CI; at PR 13, 221 scripts, 903 tests and 456,541 asserts, with `main`'s smoke line. Each negative case failed the tests that it names.

- **P1.** The autopilot drove both roads to their ends, seeds 0–4: all 10 arrived with full health, at the pier after 9.6–9.9 minutes of game time, home after 9.7–10.2 (`test_drive_to_the_end.gd`).

## 7. Owner actions

None left but landing PR 14 and deleting `eg/14-docs`. At the owner's word, an agent made the tag and deleted EG's other branches.

## 8. Risks

- **The end is far:** about 10 minutes (P1). A wrong turn meets a legend, and Departures, the strip and the pit stops help. The finish's turn is one number in `schedule.tres`.
- **An older build meets a newer save:** a build never writes a newer save, so an older APK over a newer one saves nothing. Check builds in order, or from a new save.
- **A seed doesn't replay its unlock** on another collection: a report needs both (docs/POOLS.md §8).

## 9. Notes for later

- **Souvenirs and lore tiers** (Q7): a second sighting adds to a page, as Hades' Codex does.
- **A Daily Road and medals:** a seed of the day, and medals for each area's time.
- **More finishes:** `finish` is an id, so a road can end elsewhere.
- **Lazy loading** (docs/POOLS.md §9): the Coast, the pier and the Hitchhiker add to the boot, which no Fold4 time records (IP §4 M7).
- **M7:** a haptic pulse as the car stops on the pier, the postcards as images to share, and the records in a cloud save (IP §4 M7).
