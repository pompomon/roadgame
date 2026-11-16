# Disaster Pools: More Legends in Each Zone, Picked by the Collection — Detailed Plan

Status: plan, in review. PR 1's prototype is built on `pl/prototype` and verified locally and in CI (§6); the ten legends of PRs 2–11 are designed, not built (§5.4–§5.6) · 2026-11-14 · The owner hasn't answered Q1–Q11 yet, so the plan and the prototype go on with the defaults (§3) · Scope: each area's pool of disasters holds three legends instead of one, and each run picks one for each area, at random, as the car reaches the area, with each disaster that the collection shows half as likely as each one not seen yet. This plan calls the work PL. It comes after DN (#64, #70–#76) and before M7.

The owner asked: "Explore the codebase and create a detailed implementation plan for enabling additional disasters in each zone. Disasters are picked randomly when the run starts or when the player reaches the zone (whatever is more performant) and disasters unlocked in the Atlas have 50% less chance of getting picked again. Ask clarifying questions if needed". The clarifying questions are Q1–Q11 (§3), each with the default that this plan follows until the owner answers.

**What happens.** Each area's pool, `AreaDef.disasters`, holds one legend today, its ★ (docs/M6.md §3.3, E10). `DisasterDirector` already picks from a pool, so a pool of three would play. But it picks with `randi_range()` at the wrong turn, on the stream that then draws the disaster's params, with even odds and blind to the collection (`disaster_director.gd`:91–94, :126). With one scene in each pool, that draw leaves the stream as it was (P1); with three, it would change the params of every disaster, and a draw at each area's entry on one shared stream would depend on the areas before (V1). This plan adds `DisasterPicks`. It picks an area's disaster the first time that the run asks for it, as the car reaches the area or at its wrong turn, from a stream of the area's own, `hash("<seed>:pick:<area id>")`, and keeps it for the run. Each disaster that the collection shows weighs 0.5, and each one not seen yet 1 (Q2, Q3). So with one of an area's three seen, the odds are 20/40/40%; with two, 25/25/50%; with all three, a third each (P2). A player meets all three of an area in 4.25 runs that end there, on average, against 5.5 with even odds (§5.3).

When to pick costs the same either way. A pick takes 2.4 µs, and all five 11.9 µs (P3), while the pools and their sounds load at boot, whenever the pick is made (P4, P16). So the plan picks as the car reaches the area, as the owner offered, on a stream of the area's own: the picks are then the same as if all five were drawn at the run's start, in any order, and with `--area` or the title's Start choice (Q4, §5.2). If the legends ever load lazily (Q5), picking at the zone loads only the one picked.

Then ten legends, two for each area, in two waves of one PR per area. Eight come from M6's options (docs/M6.md §3.3), and two change: the Grim Reaper, M6's omen of death (docs/M6.md §9), takes the City's third place from the Sewer Gator (V17, Q6), and the will-o'-the-wisps change the car instead of sinking it, as the kelpie does in the same area (V13, Q7). Each ends a run another way than its area's other two: aboard, up, down, away or changed (§5.4).

**Verified locally and in CI.** Every file of PR 1 was first built on branch `pl/prototype`, from `main` (2d93074). Its commits, 27ddf63 to d3a09a8, add the picks and the checks of V11 and V18, and after the internal review (§4.6) fix empty slots and glows drawn with a parent's material (§4.5). d3a09a8 passed the five checks locally with Godot 4.7.2 and in CI (§6.1), and the warnings check (§6.3); each negative case failed the tests it names (§6.2). Probes in Godot measured the picks and the ids they read, what a legend costs to load, the tests and merges with pools of three, the new words, the night, the saves and the art (§6.5). The legends are only designed: each PR builds one, as M6 built the ★s (§4.2). gpt-6.1-sol, a model of another family, reviewed this plan and the prototype, and each of its findings is fixed (`AGENTS.md` §5, §4.6).

- Godot 4.7.2-stable (4.7.2.stable.official.ed1daf0bf), in CI's image and locally
- GUT 9.7.1
- gdtoolkit 4.5.0 on Python 3.12, in CI's `lint` job and locally. shellcheck isn't installed locally, so `lint.sh` skipped it there; PL changes no shell script

**Precedence.** For PL, this document replaces `plan.md` §2.6 (:64–66), §3.5 (:108–109) and §4.2's step 2 (:167), `IMPLEMENTATION_PLAN.md` (IP) §5.3 (:231), and docs/M6.md §3.3's options and fates where §5.4 and §5.5 change them, wherever it marks a difference with **Δ** and its finding (V#, §2). PR 1 folds the picks into `plan.md` and IP; PR 12 folds the pools into `plan.md` §4.3 and §8, IP, `AGENTS.md` and the legends instructions, and replaces this plan with `docs/POOLS.md` (Q11, §5.8).

**Reference code.** This plan has no appendices. PR 1 applies the difference between 2d93074, `main`, and d3a09a8, the head of `pl/prototype`, which never gets a PR of its own (§4.1). Each legend follows the ★s' code, the death worm's (#52) above all.

**Prerequisites.** M0–M6, RG, ZS, TUT and DN are merged (#1–#79), and `main` is at 2d93074. M7 hasn't started; §9 has notes for it. No repository settings change.

Contents:
1. Goal and exit criteria
2. Review findings
3. Decisions and open questions
4. Work breakdown (12 PRs)
5. Design
6. Verification
7. Owner actions
8. Risks
9. Notes for later work

---

## 1. Goal and exit criteria

Goal: each area has three legends that end a run in three ways, and each run plays one of them in the area where it ends. The pick is random, made as the car reaches the area, and the same for the same seed and the same collection; a disaster that the collection shows is half as likely as each one not seen yet, so a player sees the ones still missing sooner. Nothing else changes: the junctions, the params, when the end comes and how long it takes, game over, and the screens (Q9).

| # | Exit criterion | Checked by |
|---|---|---|
| E1 | The picks (V1, V10). An area's disaster for the run is drawn from its pool the first time the run asks for it, as the car reaches the area, or at its wrong turn if nothing asked before, and kept for the run. It draws on a stream of the area's own, from the run's seed and the area's id, so it is the same whenever it's drawn, in any order, after any areas, and with `--area`. The director plays that pick, with params from the `disaster` stream, as on `main` | `test_disaster_picks.gd`: `test_the_same_seed_and_collection_pick_the_same_whenever_and_in_any_order`, `test_each_area_draws_on_its_own_stream`, `test_picked_lists_the_areas_asked_for_once_each`; `test_disaster_pools.gd`: `test_each_area_is_picked_as_the_car_reaches_it`; `test_disaster_director.gd`: `test_the_disaster_is_the_areas_pick_for_the_run` |
| E2 | The weights (Q2). A disaster that the collection shows weighs `Tuning.SEEN_DISASTER_WEIGHT`, 0.5, and one not seen yet 1, so it is half as likely as each one not seen yet. Ids seen that no pool holds change nothing | `test_disaster_picks.gd`: `test_a_seen_disaster_is_half_as_likely_as_each_unseen_one`, over 3,000 seeds, each share within 0.03: none, one, two and all of a pool seen, and ids seen elsewhere |
| E3 | The collection (V2, V3, Q3). Each run reads the disasters seen from the save as it starts, so a retry weighs the disaster just seen less. "Seen" is what the Disasters screen shows: a card with `seen` above 0 | `test_save_data.gd`: `test_the_disasters_seen_are_those_the_collection_shows`; `test_retry.gd`: `test_a_retry_weighs_the_disaster_just_seen_less` |
| E4 | Broken pools (V4). An empty pool picks nothing, as on `main`. A pool with no weight above 0 is an error and picks its first scene, not its last | `test_disaster_picks.gd`: `test_an_empty_pool_picks_nothing`, `test_no_weight_above_zero_is_an_error_and_picks_the_first` |
| E5 | The ids (V11). The picks read a disaster's id from its scene's `SceneState`, without instancing it, so each disaster of the pools sets its id in its `.tscn`, as each ★ does | `test_disaster_picks.gd`: `test_the_id_comes_from_the_scene_without_instancing_it`; `test_disasters.gd`: `test_each_sets_its_id_in_its_scene_where_the_picks_read_it` |
| E6 | With pools of one, PR 1 changes nothing that shows. Each area plays its ★ with `main`'s params: the pick no longer draws on the `disaster` stream, and on `main` `randi_range(0, 0)` left it as it was (P1). Of `main`'s tests, one is replaced and two changed (V7, V8), and `smoke.sh` prints `main`'s line, `autopilot: tile 165, turns 35, area rural` | §6.1, §6.2 |
| E7 | Three in each pool (Q1). Each area's pool holds its ★ and §5.4's two, each ending a run another way. Every disaster of every pool plays through the director, with a seed that picks it | `test_disasters.gd`: `test_each_area_has_its_pool_of_disasters`; `test_disaster_pools.gd`: `test_every_disaster_of_every_pool_plays` |
| E8 | Each new legend keeps M6's rules (the legends instructions; docs/M6.md §5): 2–4 s with the stop, nothing before its delay, the car taken out of sight with something left, particles seeded from the params, no flashing, no polygon redrawn, glows only with a veil (V18), and a fate and a lore that fit. Its own tests check its beats, how it takes the car and what it leaves, by day and by night (V15) | `test_disasters.gd`'s contract tests (§5.6), which play every scene of the pools, and its guard `test_only_a_legend_with_a_veil_has_glows`; the legend's `test_<id>.gd` |
| E9 | The collection has 15 cards, in the order a run can first meet them, each a silhouette until it's seen | `test_collection_screen.gd`: `test_the_disasters_in_the_order_a_run_meets_them_each_once_with_a_name_and_lore`, `test_before_any_disaster_every_card_is_a_silhouette` |
| E10 | Sound and art. Each legend has its sound, made by `make_audio.gd`, under its id in `AudioDirector.EFFECTS` and within its kind's peak; and its sheets, particle sheets too, made by `tools/art/legends/<id>.gd`: one row of whole frames of at most 96 × 96, in the palette's colours, the same each time | `test_audio_director.gd`: `test_every_disaster_of_every_area_has_its_sound`, `test_no_sound_peaks_above_its_kinds_budget`; `test_legend_art.gd`: `test_each_sheet_is_one_row_of_whole_frames_none_too_large` and `test_each_legend_of_the_pools_draws_only_its_own_art`, and PR 2's `test_each_legends_script_draws_the_same_bytes_every_time` (§5.6); `test_area_art.gd`: `test_art_is_in_the_palettes_colours` |
| E11 | The cost (V12, Q5). The ten legends add about 74 ms and 1.9–2.8 MB to the boot's loading on the desktop, with their sounds (P4, P16), and 0.3–0.5 MB to the builds (P7). PR 11 measures both again, and the owner times the Fold4's boot | §5.7, on PR 11 |
| E12 | Manual, on the Web in Chrome and Firefox and on both of the Fold4's screens: each new legend reads in 2–4 s without words, at noon and at midnight, and nothing flashes | §6.4, on each legend PR's build |
| E13 | Docs (V6, V9, V14, V16, V17). PR 1: `plan.md` §2.6, §3.5 and §4.2 and IP §5.3 say how the picks work. PR 12: `plan.md` §4.3 and §8, IP, `AGENTS.md` and the legends instructions name the pools, and `docs/POOLS.md` replaces this plan | Review |
| E14 | All five required checks are green on each PR, with §4's counts, and `smoke.sh` prints no error line. Each negative case makes the tests it names fail (§6.2), and the warnings check finds no new warning (§6.3) | PR checks; §6.2 and §6.3, run locally with Godot 4.7.2 on each PR's head |

---

## 2. Review findings

M4 gave each area a pool, `AreaDef.disasters`, and the director a pick from it (plan.md §4.3, docs/M4.md). M6 filled each pool with one legend, its ★, chosen from three options for each area, and deleted the four natural disasters (docs/M6.md E10, §3.3); its §9 left "the other ten" for later, one PR per area. So the pick has never had a choice to make, and the tests have never met a pool of more than one.

- **High:** the game misleads the player, or breaks.
- **Medium:** fragile, or missing from the tests.
- **Low:** clarity or polish.

Line numbers are `main`'s, at 2d93074, unless they say otherwise.

### High

| # | Finding | Evidence | Fix |
|---|---|---|---|
| V1 | The pick is even, made on the params' stream, and blind to the collection. With a pool of three it would change every disaster's params, and a pick made at each area's entry on one stream would depend on the areas before it | `pick()` draws `randi_range(0, size − 1)` from the run's `disaster` stream (`disaster_director.gd`:91–94), at the wrong turn (:126), before the params (:131). With one scene, `randi_range(0, 0)` leaves the stream as it was (P1), so the params are the seed's; with more, every draw after it moves. Drawn at each area's entry instead, on one stream, the City's pick would set the stream for Rural's, and `--area` and the title's Start choice skip the areas before. And the director knows nothing of the save, so nothing can weigh what was seen | **Δ plan.md §3.5, §4.2; IP §5.3:** `DisasterPicks` (§5.1): each area's pick on a stream of its own, `hash("<seed>:pick:<area id>")`, drawn the first time the run asks and kept for the run, with weights from the collection. The director plays it, and draws the params from the `disaster` stream as on `main`. Prototype (§5.1, E1, E2, E6) |

### Medium

| # | Finding | Evidence | Fix |
|---|---|---|---|
| V2 | The director doesn't know the collection, and a retry must read it again | The save records each disaster as it starts, `seen` included (`save_service.gd`:194–195, `save_data.gd`:152). `main.gd`'s `_start_run()` calls `_director.start_run(run_seed)` (:163), for the first run and for each retry | `SaveData.seen_disasters()`: the ids with `seen` above 0. `_start_run()` passes them to `start_run(run_seed, seen)`, which makes the run's picks. So a retry weighs the disaster just seen less. Prototype (E3) |
| V4 | A broken weight would pick the last scene, silently | `rand_weighted()` returns −1 when no weight is above 0, or for none (P1), and `pool[-1]` is the pool's last scene | An error, and the pool's first scene. Prototype (E4) |
| V7 | A test reads the City's disaster as the collection's first card | `test_title.gd`'s `test_the_atlas_and_the_collection_show_a_wrong_turn` plays a wrong turn in the City and checks that `cards[0]`, the bus, is seen (:155–159). With three in the City's pool, its seed may pick another; P8 shows it failing | `_card_of()` finds the card by the disaster's name. Prototype (E6) |
| V8 | The pools test meets each disaster by luck, and with weights it would depend on the order of its runs | `test_disaster_pools.gd`'s `test_every_disaster_of_every_pool_plays` tries 8 seeds in each area until each disaster of its pool has played (:15). With picks weighted by the collection, each run's record changes the next run's odds | For each disaster, `_seed_for()` finds the first of 100 seeds whose pick it is from an empty collection, and the test empties the save with `SaveService.use_memory()` before that run. Prototype (E7) |
| V11 | A legend that set its id in code would never weigh less | The picks read each scene's id from its `SceneState`, without instancing it (P6, §5.1). Every ★ sets `id` in its `.tscn`. One that set it in `_init()` or `_ready()` would read as `&""`, so it would never count as seen | `test_each_sets_its_id_in_its_scene_where_the_picks_read_it`: each scene of the pools, read as the picks read it, has the id of its instance. 0e1a76c (E5) |
| V12 | Ten more legends load at boot | Each area's `.tres` holds its pool as `ExtResource`s, which load with the schedule (`main.gd`:52). A legend's first load took 7.2–8.8 ms and 170–250 KB on the desktop, and the schedule's whole load 155.6 ms (P4). Its sound loads at boot too, in `AudioDirector.EFFECTS` (`audio_director.gd`:28–42): 0.09–0.11 ms and 24–32 KB (P16) | None by default: about 74 ms and 1.9–2.8 MB more at boot (Q5). PR 11 measures it again and the owner on the Fold4 (E11); lazy loading is §9's |
| V13 | Two of the Meadows' options end the same way | M6's options sink the car both times: the kelpie into the loch, and the will-o'-the-wisps into a bog (docs/M6.md §3.3). The legends instructions ask each to take the car another way than its area's other two | The wisps change the car into a wisp (Q7, §5.4) |
| V15 | Nothing checks how a legend reads at night | The ★s' tests play them with `ambient` white, and their Web checks (#53) came before DN. DN checks the veils' colours under each light on a sample legend (`test_legend.gd`: `test_at_night_a_veil_darkens_only_what_the_night_hasnt`), not how a legend reads. Under `LIGHT_NIGHT`, (0.42, 0.48, 0.72), a dark legend without a veil may sink into the night | Each legend's test checks that its figure stands out from its area's road and ground in every key light, through its veil, as P13 measured for the ★s: a sheet lit by the light, and glows added over the lit ground. Its PR shows frames at `--hour=12` and `--hour=0` (§5.6, E8, E12) |
| V16 | Three of M6's fates take the car or its fuel, not the player | The Horseman "took your car.", Baba Yaga's hut "swallowed your car.", the Chupacabra "drank your fuel." (docs/M6.md §3.3). Each ★'s fate takes "you": "The death worm swallowed you whole." | Fates with "you" (Q8, §5.5) |
| V18 | Only one legend's test checks that it has no glow without a veil | Glows only with a veil (docs/M6.md S10). `test_death_worm.gd` checks it for the death worm, and only for what it draws at the start. Of the ★s, only the worm has no veil and no glow; the bus, the fairy ring and the witch have one glow under a dusk veil, the UFO two under a night veil (P12). The kelpie, Frau Holle's well, the scarecrow and the chupacabra have no veil (§5.4), and a glow among their particles or their later frames would pass every test | `test_only_a_legend_with_a_veil_has_glows` plays every legend of the pools without a veil and checks, at each frame, every item that it draws, particles too. c4fd24d (E8) |

### Low

| # | Finding | Evidence | Fix |
|---|---|---|---|
| V3 | "Unlocked in the Atlas" | The Atlas shows the bests and a card for each area (`atlas_screen.gd`:3–6). The disasters are on the Disasters screen, the collection, each a silhouette until seen (`collection_screen.gd`:3–7) | "Seen" means a card shown in the collection: `seen` above 0 (Q3) |
| V5 | Saves keep ids that no pool has | M6 deleted the four natural disasters, and saves keep their records, such as `sinkhole` (docs/M6.md E10) | None: the picks weigh only their pool's ids, and the "seen elsewhere" case of E2's test checks it |
| V6 | `plan.md` says that nothing persisted affects gameplay | `plan.md` §2.6 (:64): "None that affects gameplay." The weights change which disaster ends a run | **Δ plan.md §2.6:** "None that makes a run easier or harder", as each disaster just ends the run; the collection's line says that seen ones come up half as often. Prototype |
| V9 | The docs describe the old pick | `plan.md` §3.5 (:108–109), §4.2's step 2 (:167); IP §5.3 (:231) | PR 1 rewrites them. Prototype (E13) |
| V10 | Reaching an area isn't one path in the code | The first area: `_start_run()` calls `_on_area_changed()` (`main.gd`:166). The next: `CarSim.area_changed` (:149). The tutorial's switch calls neither (docs/DAYNIGHT.md C21, docs/TUTORIAL.md T19), and a test can play a disaster with no area entered | `_on_area_changed()` calls the director's `enter_area()`; the wrong turn asks the same picks, which draw on the area's own stream if nothing asked before, so the scene is the same either way. Prototype (§5.2, E1) |
| V14 | Nothing tells the player that an area has three, or that seen ones come up less | The Atlas and the collection show what was met (`plan.md` §2.6); the collection lists every disaster, unseen ones as silhouettes, so it shows the 15 | None by default (Q9). §9: the Atlas could show each area's seen count, such as 1/3 |
| V17 | The City's third option reads badly | The Sewer Gator: its sewer is out of sight under the road, so on screen it is a crocodile in a street, and dragging the car under reads as an attack, where M6 has no one hurt on screen (docs/M6.md Q8) | The Grim Reaper, one of M6's omens of death (docs/M6.md §9), in its place (Q6). Not Santa Muerte, a saint of a living tradition (the legends instructions) |

---

## 3. Decisions and open questions

Each question has a default, which this plan and the prototype follow until the owner answers (§7). An answer that changes a default changes the PRs that §4 names for it.

| # | Question | Default | Alternative |
|---|---|---|---|
| Q1 | How many legends in each pool? | **Three: the ★ and two of §5.4's, ten new legends in all, in two waves (§4)** | Wave A only, five legends, and wave B later; or another number in some areas. A pool of two picks 33/67% with one seen |
| Q2 | What does "50% less chance" mean? | **A seen disaster weighs 0.5 and one not seen yet 1: half as likely as each unseen one. With one of three seen, 20/40/40%; with two, 25/25/50%** | Half of an even share: with one of three seen, 1/6 against 5/12 each; with two, 1/6 each against 2/3. Meets all three in 3.7 runs, against 4.25. Or 0.5 to the power of the times seen (§9) |
| Q3 | What counts as "unlocked in the Atlas"? | **A disaster with its card shown in the collection, the title's Disasters screen: seen at least once. The Atlas shows areas, not disasters (V3)** | A disaster seen in the run's area only |
| Q4 | When is a disaster picked? | **As the car reaches its area, on a stream of the area's own. The picks are the same as if made at the run's start (§5.2)** | All five at the run's start: the same picks, as each area has its own stream, for 11.9 µs at once instead of 2.4 µs at each area (P3) |
| Q5 | When do the legends load? | **At boot, as now: about 74 ms and 1.9–2.8 MB more on the desktop (P4, P16)** | Lazily: the pools as paths, and each pick loaded on a thread as the car reaches its area (§9) |
| Q6 | The City's third legend | **The Grim Reaper (V17)** | The Sewer Gator, M6's option |
| Q7 | How the wisps end a run | **They change the car into a wisp (V13)** | M6's: they lead it into a bog, as the kelpie takes it into the loch |
| Q8 | The fates | **Each takes "you", as the ★s' do (V16, §5.5)** | M6's words, which take the car or its fuel |
| Q9 | Does a screen show the pools or the weights? | **No (V14)** | The Atlas shows each area's seen count, such as 1/3 |
| Q10 | How do the legend PRs land? | **One stack of 11: PR 1, a wave of one legend for each area, then a second, so that no two PRs in a row are of one area (docs/M6.md §5.10). Then the docs, PR 12, from `main` once PR 11 has merged (docs/agents/planning.md §6)** | Independent PRs on `main`, each merging `main` after the one before lands; or one PR per area with both its legends |
| Q11 | Where do the docs change? | **PR 1 the picks' (`plan.md` §2.6, §3.5, §4.2; IP §5.3), and PR 12 the rest, with `docs/POOLS.md`** | All in PR 12 |

---

## 4. Work breakdown

Twelve PRs after this plan's (Q10): PRs 1–11 in one stack, each targeting the branch of the PR before it, then PR 12, the docs, from `main` once PR 11 has merged (§4.3). Each leaves CI green (E14).

```
plan PR ──▶ PR 1 picks (V1–V11, V18)
 (docs)       │
              ▼  wave A: each area's second legend
            PR 2 Mothman, City ──▶ PR 3 Scarecrow, Rural ──▶ PR 4 Kelpie, Meadows
              ──▶ PR 5 Frau Holle's Well, Village ──▶ PR 6 Marfa Lights, Desert
              │
              ▼  wave B: each area's third
            PR 7 Grim Reaper, City ──▶ PR 8 Headless Horseman, Rural ──▶ PR 9 Will-o'-the-Wisp, Meadows
              ──▶ PR 10 Baba Yaga's Hut, Village ──▶ PR 11 Chupacabra, Desert
              │
              ▼  once PR 11 has merged, from main
            PR 12 docs
```

Why this order:
- **The picks first.** A pool of two before PR 1 would change every disaster's params (V1), and its legend would come up at even odds.
- **One area per PR, in the schedule's order.** No two PRs in a row change the same area's lines, so a merge-up after each squash is clean (P9, docs/M6.md §5.10).
- **Wave A, then wave B.** After wave A every area has two, so the owner can stop there (Q1). In each area, wave A's legend differs from the ★ both in its way and in its light: the City's bus boards the car at dusk, and Mothman lifts it at night; Rural's UFO lifts it at night, and the scarecrow's crows carry it away by day (§5.4).
- **The docs last**, once the pools are full and on `main` (Q11, §4.3).

### 4.1 Porting from the prototype

PR 1's changes are the difference between `main` and the head of `pl/prototype`:

1. Fetch the branches, create PR 1's branch, and apply the difference:
   ```bash
   git fetch origin main '+refs/heads/pl/*:refs/remotes/origin/pl/*'
   git switch -c pl/1-picks origin/pl/plan
   git diff 2d93074 d3a09a8 | git apply --index
   ```
   If `main` has moved on and changed the same lines, use `git apply --3way --index` and keep both.
2. Make the changes of any row of §4.5 for PR 1 that the prototype doesn't have; d3a09a8 has all of them so far. Leave `POOLS_PLAN.md` alone on every PR's branch until this plan's PR has merged: until then the plan changes only on `pl/plan`, which is then merged up (§4.4). A change to it on a PR's branch would make the merge of `main` after the plan's squash an add/add conflict.
3. Run §6.1's checks, §6.2's negative cases and §6.3's warnings, and compare the counts with the "Expect" line below.
4. Have a model of another family review it (`AGENTS.md` §5). Commit as `disasters: pick each area's disaster as the car reaches it, the seen ones less often (PL PR 1)`: the prototype's commits say "POOLS PR 1", but PL is this plan's short name. Push, and open the PR with base `pl/plan`.

### PR 1: Disasters: each area's disaster picked as the car reaches it, the seen ones less often **Δ V1–V11, V18**

Branch `pl/1-picks`, from `pl/plan`. `git diff 2d93074 d3a09a8 | git apply --index`, then the changes of §4.5's rows for PR 1 that d3a09a8 doesn't have (§4.1).

| Area | Files |
|---|---|
| Disasters | `disasters/disaster_picks.gd`, new, and its `.uid`: `DisasterPicks` (§5.1), which never picks an empty slot (§4.5). `disasters/disaster_director.gd`: `picks`; `start_run(run_seed, seen)`, which makes the run's picks; `enter_area()`; and `_start_disaster()` plays `picks.pick(_area)`. The static `pick()` goes (V1, V10) |
| Autoload | `autoload/save_data.gd`: `seen_disasters()` (V2, V3) |
| Config | `config/tuning.gd`: `SEEN_DISASTER_WEIGHT` (Q2) |
| UI | `ui/main.gd`: `_start_run()` passes the collection to the director, and `_on_area_changed()` calls `enter_area()` (V2, V10) |
| Docs | `plan.md` §2.6, §3.5 and §4.2's step 2 **Δ V6, V9**; IP §5.3 |
| Tests | `tests/unit/test_disaster_picks.gd`, new, and its `.uid`: 9 tests (E1, E2, E4, E5; §4.5). `tests/unit/test_disaster_director.gd`: `test_the_disaster_is_the_areas_pick_for_the_run` replaces the static pick's test, and `_seed_near()` rolls the params alone (E1). `tests/unit/test_disasters.gd`: 2 new (V11, V18). `tests/helpers/disaster_fixtures.gd`: `material_of()`, the material that a part draws with, for the glow checks (§4.5). `tests/unit/test_save_data.gd`: 1 new (E3). `tests/integration/test_disaster_pools.gd`: `_seed_for()`, and 1 new (V8, V10). `tests/integration/test_retry.gd`: 1 new (E3). `tests/integration/test_title.gd`: `_card_of()` (V7) |

17 files, +455 −72. Expect, on `main` at 2d93074: `check_scripts: loaded 162 scripts`; `GUT: 597 tests passed`, 14 more than `main`'s, in 78 test scripts (427,048 asserts, 187 more; 93.1 s locally); `autopilot: tile 165, turns 35, area rural`, as on `main`. Negative cases N1–N11, N26 and N27.

**Acceptance:** E1–E6, E14, and E13's part for PR 1.

### 4.2 The legend PRs (PRs 2–11)

| PR | Branch, from the PR before | Legend, its id | Area | Way | Veil | Leaves |
|---|---|---|---|---|---|---|
| 2 | `pl/2-mothman` | Mothman, `mothman` | City | Up | Night | A grey feather |
| 3 | `pl/3-scarecrow` | Scarecrow, `scarecrow` | Rural | Away | None | The scarecrow, its head turned |
| 4 | `pl/4-kelpie` | Kelpie, `kelpie` | Meadows | Down | None | Waterweed |
| 5 | `pl/5-frau-holle` | Frau Holle's Well, `frau_holle` | Village | Down | None | The well, in snow |
| 6 | `pl/6-marfa-lights` | Marfa Lights, `marfa_lights` | Desert | Away | Night | Tyre tracks |
| 7 | `pl/7-grim-reaper` | Grim Reaper, `grim_reaper` | City | Down | Dusk | A gravestone |
| 8 | `pl/8-headless-horseman` | Headless Horseman, `headless_horseman` | Rural | Changed | Dusk | Scorched hoofprints |
| 9 | `pl/9-will-o-wisp` | Will-o'-the-Wisp, `will_o_wisp` | Meadows | Changed | Night | Bog cotton |
| 10 | `pl/10-baba-yaga` | Baba Yaga's Hut, `baba_yaga` | Village | Aboard | Dusk | Chicken-foot prints |
| 11 | `pl/11-chupacabra` | Chupacabra, `chupacabra` | Desert | Changed | None | The car's grey husk |

Each is titled `PL PR <k>: <the legend>, <the area>'s <second or third> legend`, as M6's were (#52: "M6 PR 7: the death worm, the Desert's legend"), and builds its legend as M6 built the ★s, the death worm (#52) above all. §5.4 designs each; §5.6 gives the rules and the tests.

| Area | Files, as in #52 (20 files, +1,168 −3) |
|---|---|
| Legend | `disasters/legends/<id>.gd` and its `.uid`; `disasters/legends/<id>.tscn`, which sets `id`, `display_name`, `fate`, `lore` and `veil_kind` (V11, §5.5) |
| Art | `tools/art/legends/<id>.gd` and its `.uid`; 2–4 sheets under `assets/legends/<id>/`, each with its `.import` |
| Sound | `tools/audio/make_audio.gd`: `_<id>()` after its area's last legend's function, and its `_save_legend()` line after its area's last; `assets/audio/sfx/<id>.wav` and its `.import`; `autoload/audio_director.gd`: its `EFFECTS` line after its area's last |
| Tuning | `config/tuning.gd`: `<ID>_BEATS` and its other constants, after its area's last legend's |
| Area | `areas/<area>.tres`: an `ext_resource` after its area's last legend's, and the scene at the end of `disasters` |
| Tests | `tests/unit/test_<id>.gd` and its `.uid`; `tests/unit/test_disasters.gd`: the id at the end of its area's list in `test_each_area_has_its_pool_of_disasters` |

So each PR's lines in the five shared files sit in its own area's block, as docs/M6.md §5.10 asks, and two PRs in a row never touch (P9). Every other test that lists disasters reads the pools, and so does the collection (E9); `make_legends.gd` runs every script in `tools/art/legends/`, so it doesn't change.

Building PR k:

1. `git switch -c <its branch> origin/<PR k−1's branch>`.
2. Its beats and other constants in `config/tuning.gd`, and its script, `disasters/legends/<id>.gd`. The art and the sound read them: the worm's art script preloads its legend's script (`tools/art/legends/death_worm.gd`:13), and `make_audio.gd`'s `_death_worm()` reads its beats and `DeathWorm`'s constants (:300–306).
3. `tools/ci/import.sh`, so that Godot knows the script's `class_name`, and commit the `.uid` that it makes.
4. Its art script, modelled on `tools/art/legends/death_worm.gd`; then `godot --headless -s tools/art/make_legends.gd`.
5. Its sound in `make_audio.gd`, seeded by its id; then `godot --headless -s tools/audio/make_audio.gd`. Its `EFFECTS` line.
6. `tools/ci/import.sh` again, and commit every `.import` and `.uid` that it makes.
7. Its scene, with the sheets, and the area's `.tres`.
8. Its `test_<id>.gd`, and the pools test's line.
9. §6.1's checks, the negative cases N12–N25 and N28, and N29 and N30 for a particle sheet (§6.2), and the warnings (§6.3).
10. Its seeds, frames and Web build for the body (§5.6, §6.4). PR 11 also measures the boot's loading on the desktop, as P4 and P16 did (E11, §5.7).
11. A review by a model of another family (`AGENTS.md` §5). Then commit as `legends: <the legend>, <the area>'s <second or third> (PL PR <k>)`, push, and open the PR with base PR k−1's branch.

Expect, after PR k: `check_scripts: loaded` 3 more scripts than the PR before, and one more test script (192 and 88 after PR 11); the legend's own 5–8 tests more, and PR 2's art test (about 648–678 after PR 11); about 16 more asserts in the shared tests (P8, P17), PR 2's 25 for the ★s' art, and the legend's own; GUT about 0.5 s more (P11); `smoke.sh`'s line as on `main` (P8).

**Acceptance:** E7 for its area, E8, E10 and E14; E9 once the collection shows it; E12 on its build; and E11 on PR 11.

### 4.3 PR 12: Docs: the pools, and docs/POOLS.md

Branch `pl/12-docs`, from `main` once PR 11 has merged (docs/agents/planning.md §6). Not before: it rewrites the cites in PR 11's new files, so made from PR 11's branch it would add other versions of them, and its merge of `main` after PR 11's squash would be an add/add conflict (docs/agents/stacks.md step 2).

| Area | Files |
|---|---|
| Docs | `docs/POOLS.md`, new, which replaces this plan (§5.8), and its row in `docs/README.md`. `POOLS_PLAN.md`, deleted, and each cite of it in code and docs rewritten as `docs/POOLS.md`, which is as long, so no line reflows |
| | `plan.md` §4.3 (:172), which names the pools and the weights, and §8's tree (:329) |
| | IP: the tree's legends (:64), M6's row and the state (:98, :101, :107), M6's package (:164), and §4 M7: §9's notes and any owner action still open (planning.md §6) |
| | `AGENTS.md`: the IDs (:18), with V# (POOLS), and the state (:20) |
| | `.github/instructions/legends.instructions.md`: "Choosing one": the pools are full at three (docs/POOLS.md §5.4), so a new legend replaces one, or the owner asks for more (Q1) |

No code, so the counts are PR 11's.

**Acceptance:** E13; E14.

### 4.4 Landing (Q10)

This plan's PR targets `main`, PR 1 targets `pl/plan`, and each of PRs 2–11 the branch of the one before. Only a PR whose base is `main` merges (`AGENTS.md` §5), so they're squashed in order: the plan, PR 1, then PRs 2–11; PR 12 then starts from `main` (§4.3). The owner merged the plan (#80), so agents land PRs 1–10, each once `tools/agent/land_pr.sh` passes; the owner lands PR 11, after the device checks, and PR 12 (`AGENTS.md` §5 step 4). The plan changes only on `pl/plan` until its PR merges. After that, each PR keeps its results and its review fixes in its body, and PR 11 carries the plan's final sync: its status, §4.5's rows, the counts and the device results (docs/agents/planning.md §5). So no two PRs of the stack change the plan's lines, and PR 12 deletes it.

A review fix goes on the branch of the PR that adds the file, then merges up the stack (`AGENTS.md` §4). The five shared files and the area `.tres` files are `main`'s, so a fix to one PR's lines in them goes on that PR's branch too. The plan's fixes go on `pl/plan`, and merge into PR 1's branch with `git merge --no-ff --no-edit`.

After each squash, retarget the next PR to `main` before anyone deletes the merged branch: deleting a merged PR's branch closes each open PR based on it, unless GitHub has retargeted it first, as the deletion of `m6/plan` closed #46 (docs/agents/stacks.md step 6). Then, on the next PR's branch (stacks.md step 5):

```bash
gh pr edit <next PR> --base main       # unless GitHub retargeted it
git fetch origin main '+refs/heads/pl/*:refs/remotes/origin/pl/*'
git switch <next PR's branch>
git merge origin/<merged PR's branch>  # its last fixes, in case one wasn't merged up yet
git merge origin/main                  # the squash
git diff --name-only origin/main       # must list only the next PR's files
git push
```

Each PR's branch merged `main` before its squash, so the next one's merge of `main` starts from there and is clean. Two PRs of the same area, such as PRs 2 and 7, change the same `disasters` line and the same list in the pools test; with this order they merge cleanly too, while merging `main` straight into PR 7 after PR 2's squash, skipping PRs 3–6's merges, conflicts and would need `-X ours` (P9). Simulate each with `git merge-tree` first. A merge-up that changes no file in the PR's diff may start no Copilot review: request one with `gh pr edit <n> --add-reviewer @copilot`. If the owner links the PRs as a GitHub stack instead, it retargets and rebases them by itself (stacks.md step 7).

### 4.5 Review fixes

Fixes found while the prototype was built, by the internal review of this plan (§4.6) and by the PRs' reviews, each with its tests and its negative case.

| PR | Change | Tests | Negative case |
|---|---|---|---|
| 1 | V11: a legend that set its id in its script would never count as seen, as the picks read the id from its scene. 0e1a76c checks that each scene of the pools, read as the picks read it, has its instance's id | `test_disasters.gd`: `test_each_sets_its_id_in_its_scene_where_the_picks_read_it`; `test_disaster_pools.gd`: `test_every_disaster_of_every_pool_plays` | N9 |
| 1 | V18: only the death worm's test checked that a legend without a veil has no glow, and only at its start. Four of the ten have no veil. c4fd24d plays each legend of the pools without a veil, and checks every item it draws at each frame, particles too | `test_disasters.gd`: `test_only_a_legend_with_a_veil_has_glows` | N10, N11 |
| 1 | §4.6 #4: an empty slot in a pool, a null in its `Array[PackedScene]`, was a script error as the car reached the area, picked or not, as `id_of()` read the null's state. 1c92081 makes it an error with no weight, so it is never picked; a pool of only empty slots picks nothing, and the director finishes as for an empty pool | `test_disaster_picks.gd`: `test_an_empty_slot_is_an_error_and_never_picked`, `test_a_pool_of_empty_slots_is_an_error_and_picks_nothing`, `test_the_id_comes_from_the_scene_without_instancing_it` | N26 |
| 1 | §4.6 #5: the glow guard read a part's own material, but a part with `use_parent_material` draws with its parent's. d3a09a8's `material_of()` finds the material that a part draws with, as the renderer does, for the guard and for the flash check's blends | `test_disasters.gd`: `test_only_a_legend_with_a_veil_has_glows` | N27 |
| 2 | Copilot's review of this plan: CI never runs the art scripts, so no test checked E10's "the same each time". PR 2's test runs each twice and compares the bytes (§5.6) | `test_legend_art.gd`: `test_each_legends_script_draws_the_same_bytes_every_time` | N28 |
| 2 | Copilot's review of this plan: the sheet tests missed particle sheets, such as the crow (§5.4). PR 2's `_sheets()` reads them, and fails one drawn with a shader or with a frame count under 1 (§5.6) | `test_legend_art.gd`: the two sheet tests (E10) | N29, N30 |

### 4.6 Internal review

A model of another family, gpt-6.1-sol (`rubber-duck`), reviewed this plan and the prototype at c4fd24d (`AGENTS.md` §5). It read the whole plan, the prototype's diff and the pinned engine's source, and emulated the picks' PCG in Python. It found no issue with: determinism, as the String hash is DJB2 and `randi_range(0, 0)` leaves the stream's state; the ids read from the scenes; `seen > 0`, the save's keys, the retries' snapshot, the tutorial, and Start and `--area`; the tests' helpers; the beats against the time limit, and the 30 strings against their limits and the font's glyphs; and the counts, P2's odds and the expected runs, 4.25, 5.5, 3.7 and 3.25 (§5.3). It didn't retime the loading, the build's size or the device. Each of its eight findings was checked, and was real. Its check of the fixes, at d3a09a8 and in this text, found two more, #9 and #10, also real:

| # | Finding | Checked | Change |
|---|---|---|---|
| 1 | §4.2's steps made the art and the sound before the legend's script and constants, which they read | Read: the worm's art script preloads its legend's script (`tools/art/legends/death_worm.gd`:13), and `make_audio.gd` reads `Tuning.DEATH_WORM_BEATS` and `DeathWorm`'s constants (:300–306) | §4.2: the constants and the script first, then `import.sh` for its `class_name`, then the art and the sound |
| 2 | Seven of §5.4's ten designs had no emitter, but the contract asserts that each legend has particles (`test_disasters.gd`:159) | Read: the assertion has no exception | §5.4 gives each of the seven an emitter that its story has, not a dummy one, and none additive (§5.6) |
| 3 | PR 12, made from PR 11's branch, rewrites cites in PR 11's new files, so its merge of `main` after PR 11's squash would be an add/add conflict | Read docs/agents/stacks.md step 2, and planning.md §6, which makes the docs PR once the plan's last PR has merged | Q10, §4.3 and §4.4: PR 12 starts from `main` once PR 11 has merged, and PR 11 carries the plan's final sync |
| 4 | An empty slot in a pool was a script error as the car reached the area, picked or not | Read: `id_of()` read the null's state | 1c92081 (§4.5, N26) |
| 5 | The glow guard missed a part that draws with its parent's additive material | Read the pinned renderer's source: an item with `use_parent_material` draws with the nearest canvas item above it that doesn't | d3a09a8 (§4.5, N27) |
| 6 | V15's test, of a sheet's pixels lit through the veil, doesn't fit the Marfa Lights and the wisps, whose figures are glows that add above the veil; and its "light" was not defined | P13b: glows added over the lit ground at night stand out in 92–100% of their pixels, and black ones in none | V15 and §5.6: the effective light, per channel the less of the light's and the veil's, and a test for glows |
| 7 | N25 didn't make the test fail: with each ★'s main colour set to its ground's, all five stayed above 30% | P13: 47–65%, and 0% with every opaque pixel set to it | §5.6 and §6.2: N25 sets every opaque pixel, or a glow's tint to black |
| 8 | A seed replayed on an empty save isn't the same run if the reporter had seen a legend | P15: with the bus, the UFO and the fairy ring in the City, seed 3 picks the bus from an empty save but the UFO with the bus seen; 18 of seeds 0–99 differ | §8: an empty save replays only a run that had seen nothing; otherwise a copy of the save from before the run (#10), or §9's `--legend=` |
| 9 | §5.1's code lacked #4's checks for an empty slot | Read: §5.1's `weights()` and `id_of()` against `disaster_picks.gd`:45–53 and :81–83 at d3a09a8 | §5.1: the code as d3a09a8 has it, and its bullet on broken pools |
| 10 | #8's fix replayed a report from the reporter's save, but the save after a run counts each legend that the run met | Read: the run's picks use the collection from its start (PR 1's `main.gd`:164), and each legend is saved as seen when it starts (`save_service.gd`:194–197). So the save that seed 3's run leaves has the bus seen, and picks the UFO (P15) | §8: a copy of the save from before the run, or §9's `--legend=`, which now says why |

---

## 5. Design

### 5.1 The picks (V1, V4, V10, V11; E1, E2, E4, E5)

PR 1 adds `DisasterPicks`, a pure `RefCounted` (IP D2), in `disasters/disaster_picks.gd`. Without its doc comments:

```gdscript
class_name DisasterPicks
extends RefCounted

var _run_seed: int
var _seen: Dictionary[StringName, bool] = {}
## Kept by area, as a schedule's copies share their areas (AreaSchedule.starting_at()).
var _picks: Dictionary[AreaDef, PackedScene] = {}


func _init(run_seed := 0, seen: Array[StringName] = []) -> void:
	_run_seed = run_seed
	for id: StringName in seen:
		_seen[id] = true


func pick(area: AreaDef) -> PackedScene:
	if not _picks.has(area):
		var pool := area.disasters
		_picks[area] = draw(pool, weights(pool), stream(_run_seed, area.id))
	return _picks[area]


func weights(pool: Array[PackedScene]) -> PackedFloat32Array:
	var result := PackedFloat32Array()
	for scene: PackedScene in pool:
		if scene == null:
			push_error("DisasterPicks: a pool has an empty slot, which is never picked")
			result.append(0.0)
		else:
			result.append(Tuning.SEEN_DISASTER_WEIGHT if _seen.has(id_of(scene)) else 1.0)
	return result


static func stream(run_seed: int, area_id: StringName) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:pick:%s" % [run_seed, area_id])
	return rng


static func draw(
	pool: Array[PackedScene], p_weights: PackedFloat32Array, rng: RandomNumberGenerator
) -> PackedScene:
	if pool.is_empty():
		return null
	var index := rng.rand_weighted(p_weights)
	# rand_weighted() gives -1 if no weight is above 0, which would index the last scene (V4).
	if index < 0 or index >= pool.size():
		push_error("DisasterPicks: no scene of the pool has a weight above 0")
		return pool[0]
	return pool[index]


static func id_of(scene: PackedScene) -> StringName:
	if scene == null:
		return &""
	var state := scene.get_state()
	if state.get_node_count() == 0:
		return &""
	for i: int in state.get_node_property_count(0):
		if state.get_node_property_name(0, i) == &"id":
			return state.get_node_property_value(0, i)
	return &""
```

`picked()` lists the ids of the areas picked so far, in order, for the tests.

- **A stream for each area.** Each pick draws once, with `rand_weighted()`, from a stream of its own, seeded from the run's seed and the area's id. It is apart from the `road`, `props` and `disaster` streams and the tutorial's (`plan.md` §3.5), so nothing else draws from it, and the pick is the same whenever it's made and whatever came before (§5.2). `stream()` is static so that the tests, and each legend PR's search for seeds (§5.6), can draw the same picks.
- **Made once, kept for the run.** The first `pick()` of an area draws, and each later one returns the same scene. `_picks` is keyed by the `AreaDef`, not by a schedule entry: `starting_at()` copies the entries, and the copies share their areas.
- **The params stay on the `disaster` stream.** The director's `_rng` now draws the params alone. On `main`, the pick drew `randi_range(0, 0)` from it first, which leaves a stream as it was (P1), so each ★ plays with `main`'s params for the same seed (E6).
- **A broken pool** (V4). `rand_weighted()` returns −1 when no weight is above 0 (P1), and `pool[-1]` would be the last scene, silently. So `draw()` reports it as an error, and the pool's first scene plays. With weights of 1 and 0.5, only a pool of empty slots has no weight above 0 (§4.6 #4): each empty slot, a null in the pool, is an error and weighs 0, so it's never picked, and the first scene of such a pool is null, so it plays nothing. An empty pool picks nothing, and the director then plays no disaster, as on `main`.
- **The id from the scene** (V11). The weights need each scene's id before anything is instanced. `id_of()` reads the `id` that the scene's root sets from its `SceneState`, which costs no node; instancing a legend would take 0.014–0.021 ms and a tree of nodes (P5). In P6 it read each ★'s id as its instance has it, also from a binary copy of the scene, as the export converts it. A legend that set its id in its script would read `&""` and never count as seen, so `test_each_sets_its_id_in_its_scene_where_the_picks_read_it` checks every scene of the pools.
- **Seeded streams only.** The picks use their own `RandomNumberGenerator`, so `lint.sh`'s RNG rule holds (IP §5.3).

The director makes a run's picks with its stream, and plays the pick:

```gdscript
var picks := DisasterPicks.new()


func start_run(run_seed: int, seen: Array[StringName] = []) -> void:
	clear()
	_rng = stream(run_seed)
	picks = DisasterPicks.new(run_seed, seen)


func enter_area(area: AreaDef) -> void:
	picks.pick(area)


func _start_disaster() -> void:
	var scene := picks.pick(_area)
	...
```

Its static `pick(pool, rng)` goes. `main.gd` passes the collection as each run starts, and tells the director of each area the car reaches:

```gdscript
	# _start_run(), :164
	_director.start_run(run_seed, SaveService.data().seen_disasters())
	# _on_area_changed(), :256, before EventBus.area_changed.emit(area)
	_director.enter_area(area)
```

`SaveData.seen_disasters()` gives the ids whose `seen` is above 0, which are the cards that the collection shows (V3):

```gdscript
func seen_disasters() -> Array[StringName]:
	var ids: Array[StringName] = []
	for id: String in disasters:
		if disasters[id]["seen"] > 0:
			ids.append(StringName(id))
	return ids
```

`config/tuning.gd` gets `SEEN_DISASTER_WEIGHT := 0.5` next to the disasters' other values (Q2). Nothing else changes: the director still records nothing, `disaster_started` still makes `SaveService` record the disaster (`save_service.gd`:194–195), and the collection, the Atlas and game over are as on `main`.

### 5.2 When the picks are made (Q4, V10; E1)

The owner asked for the picks at the run's start or as the car reaches each zone, whichever is more performant. They cost the same:

| | At the run's start | As the car reaches each area (the default) |
|---|---|---|
| The draws | All five at once, 11.9 µs (P3) | One at each area, 2.4 µs (P3) |
| Loading, as now (Q5) | None: each area's `.tres` holds its pool, which loads at boot with the schedule, as do the sounds (`main.gd`:52; P4, P16) | The same |
| Loading, lazily (§9) | Five legends at once, of which at most one plays | Only the area's pick, on a thread, as the car reaches it |
| The picks | The same: each area has its own stream (§5.1) | The same |

Both are far under a frame's 16.7 ms. So the plan picks as the car reaches the area, as the owner offered: it costs nothing more now, and less if the legends ever load lazily. `test_the_same_seed_and_collection_pick_the_same_whenever_and_in_any_order` checks that the time and the order change nothing.

A run reaches an area along four paths, and each makes the pick, or the wrong turn makes it (V10):

- **The run's first area.** `_start_run()` calls `_on_area_changed(_sim.area)` (`main.gd`:167), which calls `enter_area()`. That is the City, or the area of `--area` or of the title's Start choice in a debug build (docs/ZONE_SELECT.md); its stream is the same as when a run from the City reaches it.
- **Each next area.** `CarSim.area_changed` calls `_on_area_changed()` (:149) in the step that reaches its first tile. `test_each_area_is_picked_as_the_car_reaches_it` checks `picked()` as a run starts in the City, as it reaches Rural, and as a run starts with `--area=village`.
- **The tutorial.** Its run starts in the City, which `_start_run()` enters, so the City's pick is made then. The tutorial has no disasters (docs/TUTORIAL.md §5.6), and its switch to the City's rules doesn't call `_on_area_changed()` (docs/TUTORIAL.md T19), nor needs to: the pick is kept for the run.
- **A test with no area entered.** The wrong turn asks the picks, which draw the same scene then (`test_the_disaster_is_the_areas_pick_for_the_run`).

The schedule's last area goes on forever (`area_schedule.gd`:3), so a run reaches each area once. `enter_area()` runs before `EventBus.area_changed` is emitted, so a listener could already read the area's pick, such as an omen (§9).

### 5.3 The weights and the odds (Q2, Q3; E2, E3)

Each scene of a pool weighs 1, or `SEEN_DISASTER_WEIGHT`, 0.5, if the collection shows it. So a seen disaster is half as likely as each one not seen yet:

| Of an area's three, seen | A seen one | One not seen | Measured over 100,000 seeds (P2) |
|---|---|---|---|
| None | | 33.3% | 33.4%, 33.2%, 33.4% |
| One | 20% | 40% each | 20.0%, 39.9%, 40.1% |
| Two | 25% each | 50% | 25.0%, 24.9%, 50.1% |
| All three | 33.3% | | as with none |

Between the waves, with two in each pool and only the ★ seen, the ★ has 33.3% and the new one 66.7%. A player meets all three of an area in 4.25 runs that end there, on average: the first run meets one, then each run ending there meets a new one with odds of 80% (1.25 runs), then 50% (2 runs). With even odds that takes 1 + 1.5 + 3 = 5.5 runs, and with Q2's alternative, a seen one at half of an even share, 1 + 1.2 + 1.5 = 3.7.

- **Read as the run starts.** A run's disaster is recorded as it starts to play (`save_service.gd`:194–195), after the run has ended, so the collection never changes during a run, and reading it at each area would give the same. A retry starts a new run, so its picks weigh the disaster just seen less (`test_a_retry_weighs_the_disaster_just_seen_less`). A crash ends a run without a disaster, and the collection stays as it was.
- **Seen once or ten times weighs the same**, 0.5. Weights that fall with each sighting are §9's (Q2).
- **Ids that no pool holds** change nothing: the old saves' natural disasters, such as `sinkhole` (V5), are never looked up, as the weights look up only the pool's ids.
- **Seen in its own area.** Each disaster is in one pool, so "seen anywhere" (Q3's default) and "seen in this area" (its alternative) weigh the same until a disaster joins a second pool.
- **The same seed and the same collection give the same disasters** (`plan.md` §3.5, **Δ V1**). A seed alone gives the same road and the same params, but the disaster may change once the collection has grown: a seed shown at game over in a debug build may replay another legend (§8). The tests that need a given disaster empty the save first (`SaveService.use_memory()`, V8).

### 5.4 The pools and the legends (Q1, Q6, Q7, V13, V17) **Δ docs/M6.md §3.3**

| Area | ★ (M6) | Wave A (PRs 2–6) | Wave B (PRs 7–11) |
|---|---|---|---|
| City | Phantom Bus: aboard, dusk | Mothman: up, night | Grim Reaper: down, dusk |
| Rural | UFO: up, night | Scarecrow: away, none | Headless Horseman: changed, dusk |
| Meadows | Fairy Ring: away, dusk | Kelpie: down, none | Will-o'-the-Wisp: changed, night |
| Village | Witch's Hex: changed, dusk | Frau Holle's Well: down, none | Baba Yaga's Hut: aboard, dusk |
| Desert | Death Worm: down, none | Marfa Lights: away, night | Chupacabra: changed, none |

Each cell gives the way that the legend ends a run and its veil. In each area the three take the car three ways, and wave A's differs from the ★ in both its way and its veil. Eight of the ten are M6's options as M6 listed them. **Δ:** the Grim Reaper takes the Sewer Gator's place (V17, Q6); the wisps change the car instead of sinking it (V13, Q7); and the Horseman hurls ghost-fire, not a pumpkin, as the witch already leaves a jack-o'-lantern in the Village next door.

Each legend's beats add up to 2.4–2.5 s, as the ★s' do (2.4–2.6 s), so with the stop and the longest delay each ends within 4 s (§5.6). The names of the beats are those of `Tuning.<ID>_BEATS`. Each sheet's frames are at most 96 × 96, in the palette's colours. Each legend has at least one emitter, as the contract asserts (`test_disasters.gd`:159), and each emitter is part of the story: it emits, it is seeded by `apply_params()`, its speeds scale with the intensity and its sizes with `particle_scale`, and none is additive (§5.6).

- **Mothman** (City; `MOTHMAN_BEATS` [0.5, 0.5, 0.6, 0.8]). *Perch*: two red eyes open in a grey shape at the roadside ahead. *Unfurl*: it spreads its wings. *Swoop*: it glides down over the car. *Lift*: it carries the car up and out of the top of the view, and a grey feather drifts down to the road. Sheets: the Mothman (perched, unfurled, flying, carrying) and the feather. Particles: the dust that its wingbeats whirl up from the road as it lifts. A night veil, and one glow, its eyes, which light once and stay lit: a red light may rise only once a second (`test_none_flashes`). Sound: a rustle, a low screech, a rush of wings.
- **Scarecrow** (Rural; [0.6, 0.4, 0.8, 0.7]). *Turn*: a scarecrow by the road turns its head to the car. *Caw*: crows rise from its arms. *Flock*: they settle over the car. *Carry*: they carry it off low over the fields and out of view, and the scarecrow stays, its head turned after it. Sheets: the scarecrow (its head in three turns) and a crow (its wingbeats). The crows are particles with the crow's frames, seeded and scaled by `apply_params()`. No veil, no glow. Sound: a creak, caws, many wings.
- **Kelpie** (Meadows; [0.6, 0.5, 0.5, 0.8]). *Rise*: a black horse with weed in its mane rises from a dark pool by the road. *Wait*: it stands, dripping, and looks at the car. *Mount*: the car rolls to its side, as a rider mounts. *Plunge*: it plunges back into the pool with the car, and the water closes over them. It leaves waterweed on the road. Sheets: the kelpie, the pool and its rings, the weed; the splash is particles. No veil, no glow. Sound: bubbles, a whinny, a splash.
- **Frau Holle's Well** (Village; [0.6, 0.5, 0.6, 0.7]). *Snow*: snow starts to fall round the car. *Well*: a stone well rises by the road. *Tip*: the car tips towards it. *Fall*: it falls in, and the snow settles on the well, which stays. Sheets: the well (rising, then capped with snow). The snow is particles, at most 120, seeded and scaled by `apply_params()`. No veil, no glow. Sound: the hush of snow, a windlass's creak, a falling echo.
- **Marfa Lights** (Desert; [0.6, 0.8, 0.5, 0.6]). *Glimmer*: lights appear low over the desert, far off. *Dance*: they drift and bob, at most once a second. *Beckon*: they come close round the car. *Follow*: the car leaves the road after them, smaller and smaller until it's gone, and its tyre tracks stay. Sheets: the tracks; the lights, its figure, are glows. Particles: the sand that the tyres throw up as the car follows. A night veil; the glows white and amber, each as bright as it moves, never red. Sound: a hum that rises and falls, a soft chime for each light, tyres on sand.
- **Grim Reaper** (City; [0.6, 0.5, 0.6, 0.7]). *Step*: a hooded figure with a scythe steps out at the roadside. *Beckon*: it beckons with one bony hand. *Open*: the road opens into a grave in front of the car. *Sink*: the car sinks into it, and a gravestone rises where it was. Sheets: the Reaper, the grave, the gravestone. Particles: the earth that falls in as the car sinks. The scythe never swings at the car (docs/M6.md Q8). A dusk veil, no glow. Sound: a bell's toll, a dry whisper, falling earth.
- **Headless Horseman** (Rural; [0.6, 0.4, 0.5, 0.9]). *Gallop*: a headless rider gallops along the road to the car. *Raise*: he raises a ball of pale ghost-fire. *Hurl*: he hurls it at the car. *Kindle*: pale fire runs over the car, which becomes a pale ghost of itself and fades as he gallops off, leaving scorched hoofprints. Sheets: the Horseman (its gallop), the ghost-fire, the hoofprints. Particles: the dust from his hooves as he gallops. A dusk veil; the ghost-fire a pale green glow that rises once and fades, with no flicker. Sound: hoofbeats, a whoosh, the hiss of cold fire.
- **Will-o'-the-Wisp** (Meadows; [0.6, 0.8, 0.5, 0.6]). *Glimmer*: lights glimmer over the meadow. *Circle*: four wisps circle the car, at most half a turn a second. *Shrink*: the car shrinks into a light. *Drift*: it drifts off with them, a fifth wisp, and they fade. Tufts of bog cotton stay where it stood. Sheets: the bog cotton; the wisps, its figure, are glows. Particles: the bog cotton's seeds, which blow up as the car shrinks; they don't glow. A night veil; the glows pale blue-green and steady. Sound: soft chimes, a whisper, a fading tone.
- **Baba Yaga's Hut** (Village; [0.6, 0.5, 0.5, 0.8]). *Stomp*: a hut on chicken legs stomps out to the road. *Turn*: it turns its front to the car. *Open*: its door opens. *Swallow*: the car rolls in, the door shuts, and the hut stomps off, leaving chicken-foot prints. Sheets: the hut (stomping, turning, open), the prints. Particles: the dust of each stomp. A dusk veil; its window may glow, steady. Sound: heavy thuds, a creak, a door's slam.
- **Chupacabra** (Desert; [0.6, 0.4, 0.5, 0.9]). *Creep*: a grey, spined beast creeps out of the scrub. *Crouch*: it crouches by the car. *Pounce*: it leaps onto the car. *Drain*: the car's colours drain to grey, and the beast slinks off, leaving the car's grey husk. No blood: only the colour goes (docs/M6.md Q8). Sheets: the chupacabra, the husk. Particles: grey dust that flakes off the car as its colours drain. No veil, so its red eyes are pixels of its sheet, not glows. Sound: a hiss, a chitter, a dry rattle.

### 5.5 The words (Q8, V16) **Δ docs/M6.md §3.3**

Each scene sets the name, the fate that game over shows, and the lore of its card. `test_each_has_a_fate_for_game_over_and_a_lore_for_its_card` allows a fate of up to 40 characters and a lore of up to 80, and `test_main_scene_text_has_every_glyph_in_the_default_font` checks every glyph against Pixel Operator 8. P10 checked these words with both.

| Legend | Fate | Lore | Characters |
|---|---|---|---|
| Mothman | Mothman carried you off. | Point Pleasant, West Virginia, 1966: a winged man with red eyes. | 7, 24, 64 |
| Scarecrow | The scarecrow sent its crows for you. | Farm tales tell of a scarecrow that turns its head as you pass. | 9, 37, 63 |
| Kelpie | A kelpie carried you into the loch. | Scotland: a water horse that carries its riders into the loch. | 6, 35, 62 |
| Frau Holle's Well | You fell down Frau Holle's well. | Grimm, 1812: when Frau Holle shakes out her bed, it snows. | 17, 32, 58 |
| Marfa Lights | You followed the Marfa lights. | Marfa, Texas: lights that dance on the horizon at night. | 12, 30, 56 |
| Grim Reaper | The Reaper came for you. | Europe, 1300s: in the plague years, Death walked the streets with a scythe. | 11, 24, 75 |
| Headless Horseman | The Horseman's ghost-fire took you. | Sleepy Hollow, 1820: a headless rider gallops by night, seeking his head. | 17, 35, 73 |
| Will-o'-the-Wisp | The wisps made you one of them. | Lights over the marsh lead travellers astray. Some become lights too. | 16, 31, 69 |
| Baba Yaga's Hut | Baba Yaga's hut swallowed you. | "Little hut, little hut, turn your back to the forest, your front to me." | 15, 30, 73 |
| Chupacabra | The chupacabra drank you dry. | Puerto Rico, 1995: the goat-sucker, a beast that hunts by night. | 10, 29, 64 |

Each fate takes "you", as each ★'s does, such as "The death worm swallowed you whole." (V16). M6's took the car or its fuel: "took your car.", "swallowed your car.", "drank your fuel." Each lore names where the legend comes from, and a date where there is one; Frau Holle and Sleepy Hollow are public-domain stories (the legends instructions). If the owner keeps the Sewer Gator (Q6), its words are "A sewer gator dragged you under." (32) and "New York, 1935: boys pulled an alligator out of a Harlem sewer." (63).

### 5.6 A legend PR (E7, E8, E10, E12)

A legend PR follows the legends instructions, and these tests check them. Each plays every scene of the pools, so a new legend goes through them as soon as its area's `.tres` lists it:

| Rule | Checked by |
|---|---|
| In its area's pool; its id in its scene (V11) | `test_disasters.gd`: `test_each_area_has_its_pool_of_disasters`, `test_each_sets_its_id_in_its_scene_where_the_picks_read_it`; `test_disaster_pools.gd`: `test_every_disaster_of_every_pool_plays` |
| 2–4 s with the stop; nothing before its delay; the car out of sight once, at the end | `test_with_the_stop_each_takes_2_to_4_seconds`, `test_after_a_wrong_turn_the_director_plays_each_in_2_to_4_seconds`, `test_each_shows_nothing_until_its_delay_is_over`, `test_each_finishes_once_after_its_duration_with_the_car_out_of_sight`, `test_each_finishes_without_a_car_or_a_camera` |
| At least one emitter, each emitting, its particles seeded and scaled from the params (docs/M3.md J16) | `test_each_seeds_its_particles_from_its_params_and_scales_them`, `test_each_shows_its_particles_while_they_emit_and_each_emits` |
| No flashing; glows only with a veil (V18); no polygon redrawn | `test_none_flashes`, `test_only_a_legend_with_a_veil_has_glows`, `test_none_redraws_a_polygon` |
| Words that fit, in the font's glyphs | `test_each_has_a_fate_for_game_over_and_a_lore_for_its_card`; `test_smoke.gd`: `test_main_scene_text_has_every_glyph_in_the_default_font` |
| Its sound and sheets (E10) | `test_audio_director.gd`, `test_legend_art.gd`, `test_area_art.gd` (E10's tests) |
| The collection shows it, in order (E9) | `test_collection_screen.gd` |

**Its art, the same each time** (E10). CI never runs the art scripts, so nothing checked `make_legends.gd`:6–7's claim that each draws the same sheets on every run. PR 2 adds `test_each_legends_script_draws_the_same_bytes_every_time` to `test_legend_art.gd`: it runs each script in `tools/art/legends/` twice into `user://` and compares the bytes; not with the committed sheets, which an artist may replace (:5–6). The ★s' 14 sheets pass, their two runs taking 0.15 s (P17), and N28 fails it.

**Particle sheets** (E10). The sheet tests read only `Sprite2D`s, so they would miss the scarecrow's crow, drawn by particles (§5.4). PR 2 makes their `_sprites()` into `_sheets()`, which reads each `CPUParticles2D`'s texture too, in `particles_anim_h_frames` by `particles_anim_v_frames` frames if the material it draws with (`material_of()`) animates particles, else in one. A sheet drawn with a shader, which may cut it any way, fails, and so does a frame count under 1, which the material keeps. The ★s draw no particle sheet, so the tests' 144 asserts stay (P18). N29 and N30, which passed with `_sprites()`, fail them; PR 2 runs them on the worm, and PR 3 on its crow.

**Its own tests.** `tests/unit/test_<id>.gd` has 5–8 tests, named for what the player sees, as the ★s' are (`test_death_worm.gd`, `test_ufo.gd`): one for each beat, one for how it takes the car, hidden in the frame that its double shows, one for what it leaves, one for its glows or why it has none, and one for the night (V15).

**The night** (V15). Under the night's light, (0.42, 0.48, 0.72), a dark figure can sink into a dark ground. So each legend's test checks that its figure stands out from its area's road and ground in every light, as `test_car_controller.gd` checks the smoke (`test_the_smoke_shows_over_everything_the_world_draws`). The figure is the first sheet that §5.4 lists for the legend, every frame of it, as P13 took the ★s' (`bus.png`, `saucer.png`, `toadstool.png`, `witch.png`, `worm.png`); the Marfa Lights' and the wisps' figures are their glows (below). In each key light of `Tuning.LIGHT_COLORS`, the effective light e is, in each channel, the less of the light's and the veil's, as Daylight and the veil both darken; with no veil, it is the light. At least 30% of the figure's opaque pixels, lit by e, must differ in luminance from each main colour of its area's `road_sheet`, `ground` and `ground_edge` (those of at least 5% of a sheet, `art_checks.gd`'s `shares()`), lit by e, by at least 0.1 × lum(e). P13 measured the ★s' figures this way: the bus 64%, the UFO's saucer 37%, the toadstool 47%, the witch 41% and the worm 40%, each at its least by night. PR 2 adds the share as a helper in `tests/helpers/art_checks.gd`, with the 30% and the 0.1 as its constants; the later PRs call it.

A glow draws above Daylight and the veil, and adds. So a glow is checked as it draws (P13b): each pixel adds its colour × its alpha × the glow's tint to the lit ground, clipped at 1, and at least 30% of its pixels with alpha above 0 must differ in luminance from the lit ground by at least 0.1 × lum(e). P13b measured `glow.tres` in white and amber over the Desert at 94% and 92%, and in pale blue-green over the Meadows at 93%, each at its least by night, and the UFO's rim and beam at 100%. PR 6 adds this share as a second helper.

The negative case, N25, sets every opaque pixel of the figure to its area's main ground colour, which leaves 0%, or a glow's tint to black, which leaves 0% too. Setting only the figure's main colour to the ground's isn't enough: it left the ★s at 47–65% (§4.6 #7).

**The negative cases** N12–N25 and N28, and N29 and N30 for a particle sheet (§6.2), break each rule once, and each must fail the tests that §6.2 names.

**Seeds, frames and builds** for the body:

1. The seed to show it: the first of 0–99 whose pick in its area, from an empty collection, is the new legend. The pools test finds it as `_seed_for()` does; by hand:
   ```bash
   cat > /tmp/seed_for.gd <<'EOF'
   extends SceneTree
   func _initialize() -> void:
   	var area: AreaDef = load("res://areas/city.tres")
   	for s: int in 100:
   		if DisasterPicks.id_of(DisasterPicks.new(s).pick(area)) == &"mothman":
   			print(s)
   			break
   	quit()
   EOF
   godot --headless --path . -s /tmp/seed_for.gd
   ```
2. Frames at noon and at midnight, with Movie Maker and a scratch save, whose collection is empty (docs/agents/checks.md §2). With no input, the car misses its first turn and the legend starts 3.0–4.5 s in (P14), so 600 frames hold it:
   ```bash
   for hour in 12 0; do
     rm -rf /tmp/movie-$hour && mkdir -p /tmp/movie-$hour/data && XDG_DATA_HOME=/tmp/movie-$hour/data xvfb-run -a -s "-screen 0 1280x1024x24" \
       godot --path . --write-movie /tmp/movie-$hour/f.png --fixed-fps 60 --quit-after 600 -- --play --seed=<s> --area=<area> --hour=$hour
   done
   ```
   Post a frame from each beat at both hours in a PR comment, as a table (docs/agents/checks.md §3).
3. The Web build, served with M4's patch so that it takes arguments, at noon and at midnight, in Chrome and Firefox, each browser and hour in a fresh profile (§6.4, E12).
4. For the owner, on the Fold4: in the debug APK, the title's Start choice picks the area (docs/ZONE_SELECT.md). Each wrong turn there plays the new legend with odds of 67% in wave A, with the ★ seen, and 50% in wave B, with the other two seen; Retry keeps the area.

### 5.7 The cost (V12, Q5; E11)

| What | Measured (P3, P4, P7, P11, P16) | After PR 11 |
|---|---|---|
| A pick | 2.37 µs; all five 11.86 µs | Unchanged: a pick's cost hardly depends on the pool |
| The boot's loading | The schedule's deep load 155.6 ms; a legend's first load 7.2–7.4 ms (the bus 8.8; the first of all about 21, which loads what legends share) and 170–250 KB; its sound, in `AudioDirector.EFFECTS`, 0.09–0.11 ms and 24–32 KB | About 74 ms and 1.9–2.8 MB more, on the desktop: the scenes 73 ms and 1.7–2.5 MB, the sounds about 1 ms and 0.3 MB |
| The builds | A legend's sound 23.6–31.6 KB once imported, its sheets 0.4–3.7 KB each; the Web build 11.2 MB, the APK 58.2 MB | 0.3–0.5 MB more |
| GUT | About 0.5 s for each legend: about 0.47 s in `test_every_disaster_of_every_pool_plays`, and its own tests | About 5 s more, about 97 s locally |
| A frame | A legend plays as the ★s do | Unchanged |

The boot is the only cost that the player could notice. PR 11 measures it again on the desktop, as P4 and P16 did, and the owner times the Fold4's boot on PR 11's debug APK against `pl/prototype`'s, which has none of the ten (E11, §6.4, §7). If it shows, the legends load lazily (§9).

### 5.8 The docs (Q11; E13)

PR 1 changes what the picks change:

- `plan.md` §2.6: "None that makes a run easier or harder", and the collection's line: "A disaster in it comes up half as often as each one not seen yet (§4.2), so that runs show the ones still missing sooner." **Δ V6**
- `plan.md` §3.5: the same seed and the same collection give the same disasters, and the streams list "a `pick` stream for each area". **Δ V1, V9**
- `plan.md` §4.2's step 2: the director plays the area's disaster for the run, which its own stream drew as the car reached it, each seen one half as likely. **Δ V9**
- IP §5.3: the director's streams include the picks', seeded from the run's seed and the area's id, and weighted by the collection. **Δ V9**

PR 12 names the pools (§4.3), and replaces this plan with `docs/POOLS.md`, as each plan's summary has (`docs/README.md`): its header says where the full plan is (`git show <sha>:POOLS_PLAN.md`, the SHA of the last commit with it); then the findings V1–V18, the decisions Q1–Q11 with the owner's answers, the picks' design (§5.1–§5.3), the pools and the words (§5.4, §5.5), and the rules for a legend PR (§5.6), within about 15 KB. Each cite of `POOLS_PLAN.md` in code, tests and docs becomes `docs/POOLS.md`, and keeps its §, Q# or V#: the prototype has 19, in 14 files (`git grep -n POOLS_PLAN.md -- ':!POOLS_PLAN.md'`).

---

## 6. Verification

### 6.1 Checks and counts

The checks are `AGENTS.md` §3's five. `main` (2d93074) ran them in CI on its push, and the prototype in runs started by hand (`workflow_dispatch`), which built the Web build and the APK too. 27ddf63, c4fd24d and d3a09a8 ran all five locally, with Godot 4.7.2, and 0e1a76c ran GUT:

| State | Where | Scripts loaded | Test scripts | Tests | Asserts | GUT time | Smoke |
|---|---|---|---|---|---|---|---|
| `main` (2d93074) | Run 43619624931 | 160 | 77 | 583 | 426,861 | 89.0 s | `autopilot: tile 165, turns 35, area rural` |
| `main` (2d93074) | Local | 160 | 77 | 583 | 426,861 | 90.6 s | The same |
| Prototype (27ddf63) | Local | 162 | 78 | 593 | 427,029 | 92.1 s | The same |
| Prototype (0e1a76c) | Local, GUT only | | 78 | 594 | 427,039 | 91.1 s | |
| Prototype (0e1a76c) | Run 43626335381 | 162 | 78 | 594 | 427,039 | 88.9 s | The same |
| Prototype (c4fd24d) | Local | 162 | 78 | 595 | 427,041 | 91.7 s | The same |
| Prototype (c4fd24d) | Run 43628484904 | 162 | 78 | 595 | 427,041 | 91.8 s | The same |
| Prototype (d3a09a8) | Local | 162 | 78 | 597 | 427,048 | 93.1 s | The same |
| Prototype (d3a09a8) | Run 43638425708 | 162 | 78 | 597 | 427,048 | 79.0 s | The same |

PR 1 adds `disaster_picks.gd` and `test_disaster_picks.gd`, 15 tests, and 187 asserts, and removes a test. 27ddf63 adds 11 tests: 7 in `test_disaster_picks.gd`, and one each in `test_save_data.gd`, `test_retry.gd`, `test_disaster_pools.gd` (`test_each_area_is_picked_as_the_car_reaches_it`) and `test_disaster_director.gd` (`test_the_disaster_is_the_areas_pick_for_the_run`, which replaces `test_pick_draws_every_scene_of_the_pool_with_the_stream`). 0e1a76c and c4fd24d add one each to `test_disasters.gd` (V11, V18). After the internal review, 1c92081 adds two to `test_disaster_picks.gd`, for empty slots, and d3a09a8 has the glow guard and the flash check read the material that each part draws with (§4.5). Two of `main`'s tests change: `test_title.gd`'s `test_the_atlas_and_the_collection_show_a_wrong_turn` (V7) and `test_disaster_pools.gd`'s `test_every_disaster_of_every_pool_plays` (V8). `_seed_near()`, a helper of `test_disaster_appeared_comes_once_when_the_delay_is_over`, now rolls the params alone, and finds the seeds it found on `main` (P1).

The `test` job took 2 min 42 s on `main`, 2 min 27 s on 0e1a76c, 2 min 46 s on c4fd24d and 2 min 27 s on d3a09a8. Locally, every check passed: `lint.sh` printed `Success: no problems found` and `162 files would be left unchanged`, the version pins and the Actions storage passed, `smoke.sh` printed no error line, and `git status --porcelain` printed nothing after them. GUT's time varies from run to run: in CI, from 79.0 s to 91.8 s over the prototype's three runs, and locally by a few seconds.

### 6.2 Negative cases

Each change below makes the tests named fail, and nothing else. A script, not committed, applied each change to a clean worktree, ran `tools/ci/run_tests.sh`, read GUT's JUnit report, and restored the files: N12–N24 on c4fd24d, where each ran all 595 tests in 94–97 s; then N1–N11 again, and N26 and N27, on d3a09a8, where each ran all 597; N28 on d3a09a8 with PR 2's art test added, all 598; and N29 and N30 with PR 2's `_sheets()` instead, all 597. Each exited 1. N1–N11 failed the same tests on both, and N7 and N8 the new tests of empty slots too. After the runs, `git status --porcelain` printed nothing.

**PR 1's** (§4, PR 1):

| N# | Change | Fails |
|---|---|---|
| N1 | `disaster_picks.gd`: `weights()` gives a seen disaster 1.0, not `SEEN_DISASTER_WEIGHT` | `test_disaster_picks.gd`: `test_a_seen_disaster_is_half_as_likely_as_each_unseen_one`; `test_retry.gd`: `test_a_retry_weighs_the_disaster_just_seen_less` |
| N2 | `disaster_picks.gd`: `stream()` seeds from `hash("%d:pick" % run_seed)`, without the area's id | `test_each_area_draws_on_its_own_stream` |
| N3 | `disaster_director.gd`: the director draws its own pick, `DisasterPicks.draw(_area.disasters, picks.weights(_area.disasters), _rng)`, on the `disaster` stream | `test_disaster_director.gd`: `test_the_disaster_is_the_areas_pick_for_the_run`, `test_disaster_appeared_comes_once_when_the_delay_is_over` |
| N4 | `main.gd`: `_director.start_run(run_seed)`, without the seen disasters | `test_a_retry_weighs_the_disaster_just_seen_less` |
| N5 | `main.gd`: no `_director.enter_area(area)` | `test_disaster_pools.gd`: `test_each_area_is_picked_as_the_car_reaches_it` |
| N6 | `save_data.gd`: `seen_disasters()` keeps the entries with `seen >= 0` | `test_save_data.gd`: `test_the_disasters_seen_are_those_the_collection_shows` |
| N7 | `disaster_picks.gd`: `draw()` uses `randi_range(0, pool.size() - 1)`, not `rand_weighted()` | `test_a_seen_disaster_is_half_as_likely_as_each_unseen_one`, `test_no_weight_above_zero_is_an_error_and_picks_the_first`, `test_an_empty_slot_is_an_error_and_never_picked`, `test_a_pool_of_empty_slots_is_an_error_and_picks_nothing` |
| N8 | `disaster_picks.gd`: `draw()` checks only `index >= pool.size()`, not −1 | `test_no_weight_above_zero_is_an_error_and_picks_the_first`, `test_a_pool_of_empty_slots_is_an_error_and_picks_nothing` |
| N9 | `ufo.tscn` has no `id = &"ufo"`, and `ufo.gd` sets it in `_init()` | `test_disaster_pools.gd`: `test_every_disaster_of_every_pool_plays`; `test_disasters.gd`: `test_each_sets_its_id_in_its_scene_where_the_picks_read_it` |
| N10 | `death_worm.tscn`: the crater has the glow material, `glow_material.tres` | `test_death_worm.gd`: `test_the_ground_trembles_and_ripples_run_through_the_sand_to_the_car`; `test_disasters.gd`: `test_only_a_legend_with_a_veil_has_glows` |
| N11 | `death_worm.tscn`: the spray, a `CPUParticles2D`, has it | `test_only_a_legend_with_a_veil_has_glows` |
| N26 | `disaster_picks.gd` without its two checks for an empty slot, in `weights()` and `id_of()` | `test_disaster_picks.gd`: `test_an_empty_slot_is_an_error_and_never_picked`, `test_a_pool_of_empty_slots_is_an_error_and_picks_nothing`, `test_the_id_comes_from_the_scene_without_instancing_it` |
| N27 | `death_worm.tscn`: the glow material on its root, and the crater with `use_parent_material = true` | `test_only_a_legend_with_a_veil_has_glows`. Before d3a09a8, it failed nothing |

**Each legend PR's** (§5.6). Each legend PR breaks its own legend in these ways, and its body names the tests that fail. Here they ran on the death worm, N16 on the UFO and N28 on the fairy ring; N25 needs PR 2's helper, so PR 2 runs it first, and PR 6 its form for glows. A change also fails the legend's own tests that check the same thing, as N14 does. `Legend.play()` seeds and scales every `CPUParticles2D` under a legend (`disaster_base.gd`:46), so only a legend that changes them after it plays could break docs/M3.md J16, and N23 checks the other half of that rule. M6's N39 and N40 cover the polygons (docs/M6.md §6):

| N# | Rule broken, on the worm | Fails |
|---|---|---|
| N12 | Its id set in its script, not its scene: N9 | N9's two |
| N13 | Over 4 s: `DEATH_WORM_BEATS` ends in 2.3 s, not 0.3 | `test_disasters.gd`: `test_with_the_stop_each_takes_2_to_4_seconds`, `test_after_a_wrong_turn_the_director_plays_each_in_2_to_4_seconds`; `test_disaster_pools.gd`: `test_a_wrong_turn_in_each_area_plays_a_disaster_from_its_pool`, `test_every_disaster_of_every_pool_plays` |
| N14 | Something shows before its delay: the crater opaque in `death_worm.tscn` | `test_each_shows_nothing_until_its_delay_is_over`; `test_death_worm.gd`: `test_it_leaves_a_crater_where_the_car_stood` |
| N15 | The car shows at its end: `_take()` shows the car again after `take_car()` | `test_each_finishes_once_after_its_duration_with_the_car_out_of_sight`, and the 10 other tests that play it to its end, as the legend reports it with an error, "the car still shows at its end": 5 more in `test_disasters.gd`, 2 in `test_death_worm.gd`, 2 in `test_disaster_pools.gd` and 1 in `test_area_start.gd` |
| N16 | It flashes: `UFO_RIM_HZ` 4.0, not 2.0, on the UFO | `test_none_flashes` |
| N17 | A glow without a veil: N10 and N11 | N10's and N11's |
| N18 | A fate of 41 characters: "The death worm swallowed you whole today." | `test_each_has_a_fate_for_game_over_and_a_lore_for_its_card` |
| N19 | A glyph outside the font: "→" in its lore | `test_smoke.gd`: `test_main_scene_text_has_every_glyph_in_the_default_font` |
| N20 | A sheet cut into frames of the wrong width: the mound's 128 px sheet in 3 frames, not 2 | `test_legend_art.gd`: `test_each_sheet_is_one_row_of_whole_frames_none_too_large` |
| N21 | No sound: `audio_director.gd` without `&"death_worm"` | `test_audio_director.gd`: `test_every_disaster_of_every_area_has_its_sound`; N13's two in `test_disaster_pools.gd` and `test_area_start.gd`'s `test_the_title_starts_the_runs_in_the_chosen_area_as_the_area_argument_does`, which play it, as an unknown sound is an error |
| N22 | The tests' list of the pools not updated: `test_disasters.gd` without `&"death_worm"` | `test_each_area_has_its_pool_of_disasters` |
| N23 | Particles that never emit: the spray's `emitting` always false | `test_each_shows_its_particles_while_they_emit_and_each_emits`; `test_death_worm.gd`: `test_the_worm_bursts_up_out_of_the_cracked_mound_carrying_the_double_on_its_head`, `test_the_swallow_goes_down_its_body_as_it_dives_back_into_the_sand` |
| N24 | What it leaves hides at its end: the crater's alpha 0 at the last beat, as docs/M6.md N31 | `test_death_worm.gd`: `test_it_leaves_a_crater_where_the_car_stood` |
| N25 | It sinks into the night: every opaque pixel of its figure set to its area's main ground colour, or a glow's tint to black (§5.6) | Its night test (V15), once PR 2 adds the helper, and PR 6 the glows'; not run here, but P13 and P13b give 0% for both |
| N28 | Its art drawn at random: four white pixels at `randi_range()` places in the fairy ring's eyes, as `lint.sh`'s RNG rule skips `tools/` | PR 2's `test_each_legends_script_draws_the_same_bytes_every_time`, alone of 598 tests, run on d3a09a8 with that test added |
| N29 | A particle sheet cut wrong: the worm's spray given its 280 px sheet, uncut, or in 3, 0 or −5 frames; or the crater with a `ShaderMaterial` | `test_legend_art.gd`: `test_each_sheet_is_one_row_of_whole_frames_none_too_large`; with `_sprites()`, nothing |
| N30 | A particle sheet from another legend's folder: the worm's spray given the UFO's grey | `test_legend_art.gd`: `test_each_legend_of_the_pools_draws_only_its_own_art`; with `_sprites()`, nothing |

### 6.3 Editor warnings

The five checks report no GDScript warnings, and shadowing shows only in the editor (`AGENTS.md` §2). As docs/agents/checks.md §1 says (#61), a temporary `override.cfg` raised the 37 warnings at level 1 (warn) to 2 (error), and `check_scripts.sh` loaded every script. On `main` (2d93074), on c4fd24d and on d3a09a8 it found the same 5, and no other error: `INTEGER_DIVISION` in `world/greybox_atlas.gd`:135, `ui/main.gd`:62, `test_greybox_atlas.gd`:15 and `test_iso.gd`:42, and `UNUSED_VARIABLE` `junctions` in `test_road_generator_occupancy.gd`:30. `make_art.gd` and `art_checks.gd`, which load `greybox_atlas.gd`, failed to compile after it. Godot reports only the first error in a script, so the probe ran again without `integer_division`: only `junctions` was left, on each. So no script that PR 1 adds or changes has a warning, and no name it adds shadows a member or a built-in; `test_road_generator_occupancy.gd`, the one script that `junctions` could hide more in, PR 1 doesn't change. `ui/main.gd`:62 is in `_ready()`, on each. The file was deleted after; the editor changed none.

### 6.4 Verified only in CI or on devices

- **CI.** The five required checks on each PR, and the `test` job's time (§6.1). This plan's PR changes only this file.
- **PR 1** shows nothing new (E6): no text, no node, no `Polygon2D`. So it needs no Web or Fold4 check, and nothing was left for one. Its Web build and APK, from run 43638425708 on d3a09a8, are there for the owner to try (§7).
- **Each legend PR on the Web** (E12), by an agent. Build its branch, named as in §4.2's table: `pl/5-frau-holle`, not `pl/5-frau_holle`; then download and serve the build with M4's patch, which passes the URL's `arg`s to the game (docs/agents/checks.md §4):
  ```bash
  gh workflow run ci.yml -R pompomon/roadgame --ref <branch> -f upload-builds=true
  rm -rf /tmp/roadgame-web
  gh run download <run id> -R pompomon/roadgame -n web -D /tmp/roadgame-web
  sed -i 's/"args":\[\]/"args":["--"].concat(new URLSearchParams(location.search).getAll("arg"))/' \
    /tmp/roadgame-web/index.html
  python3 -m http.server -d /tmp/roadgame-web 8000
  ```
  Open `http://localhost:8000/?arg=--seed=<s>&arg=--area=<area>&arg=--play&arg=--hour=12`, with §5.6's seed, and again with `--hour=0` in its place (`main.gd` reads the first), in Chrome and Firefox, driven by Playwright, headed under Xvfb. Give each browser and hour a new Playwright context, whose IndexedDB is empty: a run saves its legend as seen, and the seed may then pick another (§8, P15). Left alone, the car misses its first turn and the legend starts 3.0–4.5 s in (P14). Post a frame of each beat and the console's errors, by browser and hour, in a PR comment. The build stays current while `git diff --name-only <built> HEAD -- . ':!tests' ':!addons/gut' ':!*.md'` prints nothing, so a fix to tests or words in Markdown needs no new one.
- **Each legend PR on the Fold4** (E12), by the owner, on both screens: `rm -rf /tmp/roadgame-apk && gh run download <run id> -R pompomon/roadgame -n "android-Android APK" -D /tmp/roadgame-apk`, as `gh` won't overwrite an earlier download (docs/agents/checks.md §4), then `adb install -r /tmp/roadgame-apk/roadgame-debug.apk`. The APK takes no arguments, so the title's Start choice picks the area, and each wrong turn plays the new legend with odds of 67% in wave A and 50% in wave B, once the area's others are seen (§5.6). For noon and midnight, serve the Web build as above, run `adb reverse tcp:8000 tcp:8000`, and open the same URLs in the Fold4's Chrome, each in Incognito with every Incognito tab closed first, so that each starts with no save. Check that the legend reads in 2–4 s without words, at 60 fps, and that nothing flashes.
- **E11, the boot on the Fold4,** by the owner, on two debug APKs: `pl/prototype`'s, `main` at 2d93074 with PR 1 and none of the ten legends, and PR 11's, with all ten; `main`'s may hold some of them by then. Build each with the command above (`--ref pl/prototype`, `--ref pl/11-chupacabra`), and download it the same day, as CI keeps builds for one (`ci.yml`:127), each into a cleared folder of its own, such as `/tmp/apk-prototype` and `/tmp/apk-11`. Install each in turn with `adb install -r`, and start it three times, each after `adb shell am force-stop com.pompomon.roadgame` and `adb logcat -c`, so that each start is cold; then `adb logcat -d -v time -s godot`, and take the time from Godot's banner, `Godot Engine v4.7.2.stable…`, to `grey box: tilesets built in`, which `_ready()` prints (`ui/main.gd`:62). PR 11 should add at most about 0.1 s, the desktop's 74 ms (P4, P16) scaled for a slower CPU; more, and the legends load lazily (§9).

### 6.5 Measurements

The probes ran headless with Godot 4.7.2, on `main` (2d93074) or the prototype; they aren't committed.

| P# | What | Result | Used by |
|---|---|---|---|
| P1 | What `RandomNumberGenerator` does with a pool of one, and with weights that it can't use | `randi_range(0, 0)` returns 0 and leaves the state as it was; `rand_weighted([1.0])` returns 0 and moves it. `rand_weighted()` returns −1 for no weights, for negative ones and for all zero | E6, V2, V4, §5.1 |
| P2 | `DisasterPicks.draw()` on the City's stream for seeds 0–99,999, with the weights of none, one and two of three seen | [1, 1, 1]: 33.4%, 33.2%, 33.4%. [0.5, 1, 1]: 20.0%, 39.9%, 40.1%. [0.5, 0.5, 1]: 25.0%, 24.9%, 50.1%. The same seed and area give the same pick, run after run; another area's stream another | Q2, §5.3 |
| P3 | A pick's cost: 10,000 picks from a pool of three ★s, each reading the ids from the scenes' `SceneState`, weighing them, seeding a stream and drawing | 2.37 µs a pick, so 11.86 µs for all five areas | Q4, §5.2, §5.7 |
| P4 | What a legend costs to load: in a fresh process, each ★'s scene, script and sheets loaded for the first time, as the schedule loads them at boot, in both orders; and the schedule's whole load, without the cache | A legend's first load 7.2–7.4 ms, the bus 8.8 ms, and the first of all about 21 ms, which loads what legends share; each 170–250 KB of memory. The schedule's deep load 155.6 ms. Ten more legends' scenes: about 73 ms and 1.7–2.5 MB | V12, Q5, E11, §5.7 |
| P5 | What instancing a legend costs, which `id_of()` avoids | 0.014–0.021 ms and a tree of nodes, for each ★ | §5.1 |
| P6 | Each ★'s `id` read from its scene's `SceneState`, against its instance's, from its `.tscn` and from a copy saved as binary `.scn` (magic `RSCC`), as the export converts it | The same for all five, in both | V11, §5.1 |
| P7 | What a legend adds to the builds | Its sound 115–154 KB as a WAV, 23.6–31.6 KB imported; its sheets 0.4–3.7 KB each. The Web build 11.2 MB, the APK 58.2 MB; ten legends add 0.3–0.5 MB | §5.7, E11 |
| P8 | Pools of three, made of the ★s: the City + UFO and fairy ring, Rural + witch and worm, the Meadows + bus and witch, the Village + worm and UFO, the Desert + bus and fairy ring, on c4fd24d. A: with c4fd24d's tests. B: with `main`'s `test_title.gd` | A: only `test_each_area_has_its_pool_of_disasters` fails, which lists the pools; 427,153 asserts, 112 more, in 97.8 s. B: V7's test fails too, in 96.9 s. `test_every_disaster_of_every_pool_plays` takes 6.6 s, against 1.9 s with five. `smoke.sh` prints `main`'s line | V7, §4.2 |
| P9 | Stacked legend PRs merged up after squashes, simulated with `git` in scratch repositories: two PRs that add lines to the same table, or to two areas' blocks of the same dictionary | Lines added to adjacent rows conflict; lines under each area's own comment merge cleanly. `main` merged straight into PR 7 after PR 2's squash, skipping PRs 3–6, conflicts; merged into each PR in turn, it is clean | §4.2, §4.4 |
| P10 | §5.5's words against the limits and the font | Each fate at most 40 characters, each lore at most 80, every glyph in Pixel Operator 8 | §5.5 |
| P11 | GUT's time for a legend, from P8 and the ★s' own tests | `test_every_disaster_of_every_pool_plays` takes about 0.47 s more for each entry, and a ★'s own tests 0.05–0.08 s: about 0.5 s a legend | §4.2, §5.7 |
| P12 | Each ★'s veil and glows, as `test_only_a_legend_with_a_veil_has_glows` reads them | The bus, the fairy ring and the witch: a dusk veil and one glow. The UFO: a night veil and two. The worm: no veil and none | V18 |
| P13 | How each ★'s figure stands out at night: the share of its opaque pixels whose luminance, in each key light and through its veil, differs from each main colour of its area's road and ground by at least 0.1 of the effective light's, per channel the less of the light's and the veil's | At their least, by night: the bus 64%, the UFO's saucer 37%, the toadstool 47%, the witch 41%, the worm 40%. Hence §5.6's 30%. With every opaque pixel set to the area's main ground colour, 0%; with only the figure's main colour, 47–65% | V15, §5.6, N25 |
| P13b | How a glow stands out at night, as it draws above Daylight and the veil: each pixel's colour × its alpha × the tint added to the lit ground, clipped at 1; the share of its pixels with alpha above 0 that differ in luminance from the lit ground by at least 0.1 of the effective light's | At their least, by night: `glow.tres` white and amber over the Desert 94% and 92%, pale blue-green over the Meadows 93%; the UFO's rim and beam 100%; black 0% | V15, §5.6, N25 |
| P14 | When a legend starts in a run left alone: `--play --hour=0`, seeds 1–3 in each area | 2.97–4.52 s in, over the 15 runs | §5.6, §6.4 |
| P15 | Whether a save replays a seed's pick: a City pool of the bus, the UFO and the fairy ring, seeds 0–99, from an empty collection and with the bus seen, as a run that met the bus leaves the save | Seed 3 picks the bus from an empty one and the UFO with the bus seen; 18 of the 100 seeds pick another legend | §8 |
| P16 | What a legend's sound adds to the boot, as `AudioDirector.EFFECTS` preloads it (`audio_director.gd`:28–42): each ★'s sound loaded fresh, the median of five, three times | Each is QOA-compressed, and loads in 0.09–0.11 ms and 24–32 KB. Ten more: about 1 ms and 0.3 MB | V12, Q5, E11, §5.7 |
| P17 | Whether each ★'s art script draws the same sheets each time: each run twice into `user://`, three times, on d3a09a8 | Its 14 sheets the same bytes each time, and as committed. Both runs of all five 152.5–153.7 ms; a run of the bus 43 ms, the worm 30, the others 1–5 | E10, §4.2, §5.6 |
| P18 | Whether the sheet tests see a particle sheet: `_sprites()` and §5.6's `_sheets()` on d3a09a8 | The ★s have none; the bus's fog and the witch's smoke draw the glow, which the tests skip. Both give 144 asserts; with `_sheets()`, all 597 tests pass with 427,048. N29 and N30 pass with `_sprites()`. A material keeps 0 or −5 frames; without §5.6's guard, N29's −5 and shader pass | E10, §5.6 |

---

## 7. Owner actions

| When | Action | How |
|---|---|---|
| Now | Answer Q1–Q11, or accept the defaults | A comment on this plan's PR. Without an answer, the PRs follow the defaults (§3). Q2–Q5 change PR 1; Q1, Q6 and Q7 which legends PRs 2–11 build; Q8 their words; Q9 and Q11 the UI and the docs; Q10 how they land |
| Now, if wanted | Try the prototype on the Fold4 | Until 2026-11-15 20:36 UTC: `rm -rf /tmp/roadgame-apk && gh run download 43638425708 -R pompomon/roadgame -n "android-Android APK" -D /tmp/roadgame-apk`, then `adb install -r /tmp/roadgame-apk/roadgame-debug.apk`. After that, `gh workflow run ci.yml -R pompomon/roadgame --ref pl/prototype -f upload-builds=true` makes a new one, kept a day. With pools of one, it plays as `main` does (E6) |
| On each legend PR, if wanted | E12 on the Fold4, on both screens. It doesn't hold the PR: PR 11's build has all ten legends, and PR 11 waits for what's left (`AGENTS.md` §5) | §6.4: its APK, with the Start choice and Retry; at noon and midnight, its Web build in the Fold4's Chrome, in Incognito |
| On PR 11 | E11: time the boot | §6.4: three cold starts each of `pl/prototype`'s debug APK and PR 11's, each built and downloaded the same day |
| To land PL | Agents land PRs 1–10 in order (§4.4). Merge PR 11 once E11 and E12 pass, then PR 12, which starts from `main` once PR 11 has merged (§4.3) | Squash each. Before deleting a merged PR's branch, retarget the next PR to `main` (§4.4) |
| After PR 12 | Tag the prototype, which this plan cites, and delete the `pl/` branches | `git fetch origin pl/prototype && git push origin FETCH_HEAD:refs/tags/archive/pl/prototype`, then `git push origin --delete pl/plan pl/prototype pl/1-picks pl/2-mothman pl/3-scarecrow pl/4-kelpie pl/5-frau-holle pl/6-marfa-lights pl/7-grim-reaper pl/8-headless-horseman pl/9-will-o-wisp pl/10-baba-yaga pl/11-chupacabra pl/12-docs`, less any already deleted (docs/agents/planning.md §6) |

---

## 8. Risks

| Risk | Impact | Mitigation |
|---|---|---|
| The boot is slower on the Fold4 | Ten more legends load at boot, their scenes with the schedule and their sounds with `AudioDirector`: about 74 ms and 1.9–2.8 MB on the desktop (P4, P16), and a phone's CPU is slower | E11 times it on PR 11's APK against `pl/prototype`'s, which has none of the ten (§6.4). If it shows, the pools load lazily (§9, Q5) |
| A seed doesn't replay its legend | The same seed gives the same road and params, but its disaster depends on the collection too (**Δ V1**, §5.3). A seed shown at game over in a debug build, or in a report, may play another legend on another device | A replay needs the collection as it was when the run started, as the run's picks use that one (§5.1; PR 1's `main.gd`:164). An empty save (`SaveService.use_memory()` in tests, a scratch `XDG_DATA_HOME` on the desktop, §5.6) gives it only for a run that had seen nothing: with the bus seen, seed 3 in the City picks the UFO, not the bus (P15, §4.6 #8). The save after the run won't do either if the run met a legend for the first time, as each legend is saved as seen when it starts (`save_service.gd`:194–197): seed 3's run leaves the bus seen, and so replays with the UFO (§4.6 #10). So replay a report from a copy of the save taken before its run, in a scratch `XDG_DATA_HOME`; or a `--legend=` flag would force the legend (§9) |
| A stack of 11 | A fix low in the stack must merge up through every PR above it, and a PR waiting for review holds up the rest | Each PR adds its own files and its own area's lines, so merge-ups are clean (P9); simulate each with `git merge-tree` first (§4.4). Two waves let wave A land before wave B is built (Q10) |
| A new legend is slow to meet on a device | With the area's other legends seen, a wrong turn plays the new one 67% of the time in wave A and 50% in wave B, so the owner may need a few retries for E12 | The Start choice picks the area and Retry keeps it (§5.6); the Web build takes `--seed`, `--area` and `--hour` (§6.4) |
| A legend sinks into the night | A dark figure on a dark ground under `LIGHT_NIGHT` reads as nothing | V15: each legend's test checks its contrast in every key light, at 30% (§5.6), and each PR posts frames at midnight; the ★s measured 37–64% (P13) |
| The lights look alike | The UFO in Rural, the wisps in the Meadows next to it, and the Marfa Lights in the Desert all show lights at night | Each takes the car another way: up into a saucer, changed into a light, away after them. The wisps are small, pale blue-green and steady, and circle the car; the Marfa Lights white and amber, far off, then close (§5.4). PR 9's frames show the UFO's beside the wisps', and the owner judges them (E12) |
| Too much for the content rating | A legend that hurts someone on screen, or uses a living tradition's sacred figure | The legends instructions forbid both; the chupacabra drains colour, not blood, and the Reaper replaces the gator for that reason (V17). The owner judges each PR's frames (E12) |

---

## 9. Notes for later work

- **Lazy loading** (Q5, V12). Each `AreaDef` would hold its pool as paths, and the picks would load only the scene picked, with `ResourceLoader.load_threaded_request()` as the car enters the area before it, so it's ready by the first junction. The weights would need each id without loading its scene, such as from its file's name, which a test would keep equal to its id. The sounds could stay in `AudioDirector.EFFECTS`: ten take about 1 ms (P16). Only if E11 shows the boot.
- **The Atlas's count** (V14, Q9). Each area's card could show how many of its legends are seen, such as 1/3, from `seen_disasters()` and its pool.
- **Omens** (§5.2). `enter_area()` picks before `EventBus.area_changed`, so an area could hint at its legend as the car enters it: a raven for the Reaper, a grey moth for the Mothman.
- **Weights that fall with each sighting** (Q2). 0.5 to the power of the times seen, from the collection's counts, so that the legend seen most comes up least. `weights()` would read the counts.
- **A `--legend=<id>` flag** for debug builds, to play a given legend in its area, for device checks and reports, as a seed replays its legends only with the collection from before its run (§8). The title's Start choice could choose a legend too (docs/ZONE_SELECT.md).
- **A looping schedule.** The last area goes on forever (`area_schedule.gd`:3), so each area is picked once a run. A schedule that came back to an area would get its first pick again, as `_picks` keeps it by `AreaDef`; decide then whether a second visit picks anew.
- **M7.2's haptics** can pulse on the new legends' beats, as on the ★s' (`Beats`, docs/M6.md §9).
- **M7.4's content rating** stays: fear, with no blood or gore (IP :176).
- **M7.5's checklist** (IP :206): "Each area's legend, day and night, on both screens" becomes "each area's three legends". With the Start choice and Retry, meeting an area's three takes about 4.25 wrong turns from a fresh save, or 3.25 with its ★ seen.
