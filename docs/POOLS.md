# Disaster Pools: More Legends in Each Zone, Picked by the Collection

Done, 2026-11-14 to 2026-11-17: the plan PR #80, then eleven stacked PRs, #81–#83, #86–#91, #96 and #98. The plan called the work PL. Each area's pool holds three legends, and a run plays one where it ends, picked as the car reaches the area, each that the collection shows half as likely as each not seen yet. The owner answered none of Q1–Q11, so their defaults stand. The full plan, with its verification, negative cases and review history: `git show 82b2f1e:POOLS_PLAN.md`; the tag `archive/pl/prototype` keeps the prototype's commits that it cites.

## 1. Goal and exit criteria

Nothing else changes: the junctions, the params, the end's timing, game over and the screens (Q9). E1–E14 are met: the picks, weights and collection (E1–E3); broken pools and ids (E4, E5); PR 1 changing nothing that shows (E6); three legends in each pool, keeping M6's rules, with sound and art, in a collection of 15 cards (E7–E10); the docs and checks (E13, E14).

- **E11.** The boot. On the desktop the ten legends added 114 ms and 2.1 MB (§5.7). On the Fold4, the owner on 2026-11-17: "Fold4 launch is within 150ms": PR 11 adds at most the 0.15 s that the desktop predicted, over the plan's 0.1 s, and the owner accepted it. The legends load at boot (Q5); lazily if it grows (§9).
- **E12.** Each new legend reads in 2–4 s without words, at noon and midnight, and nothing flashes: on the Web in Chrome 157 and Firefox 156, on each legend PR's build, and on both Fold4 screens, by the owner.

## 2. Findings

- **V1.** The pick was even, blind to the collection, and on the params' stream, which pools of three would shift. **Δ plan.md §3.5, §4.2; IP §5.3:** `DisasterPicks` (§5.1).
- **V2.** The director didn't know the collection: `_start_run()` passes `SaveData.seen_disasters()` to `start_run()`, so a retry weighs the disaster just seen less.
- **V3.** The Atlas shows areas, not disasters: "unlocked" means a card that the collection shows, `seen` above 0 (Q3).
- **V4.** `rand_weighted()` gives −1 with no weight above 0, and `pool[-1]` would play the last scene. Now an error, and the first (§5.1).
- **V5.** Saves keep ids that no pool has, such as `sinkhole`; the weights ignore them.
- **V6.** **Δ plan.md §2.6:** what persists changes nothing "that makes a run easier or harder".
- **V7.** `test_title.gd` took the City's disaster for the first card; `_card_of()` finds it by name.
- **V8.** The pools test met each disaster by luck; `_seed_for()` finds a seed that picks it from an empty save.
- **V9.** PR 1 rewrote the old pick where the docs gave it (V1, V6).
- **V10.** Reaching an area wasn't one path: `_on_area_changed()` calls `enter_area()`, and the wrong turn asks the same picks (§5.2).
- **V11.** Each legend sets `id` in its `.tscn`, as the picks read it from the `SceneState`: set by its script, it reads `&""` and never weighs less.
- **V12.** Ten more legends load at boot. Kept (Q5, E11).
- **V13.** M6's two other options for the Meadows both sank the car. **Δ docs/M6.md §3.3:** the wisps change it into a wisp (Q7).
- **V14.** Nothing shows that an area has three, or that seen ones come up less. Left so (Q9, §9).
- **V15.** Nothing checked how a legend reads at night. Each one's tests now check its figure, what it leaves and its glows in every key light, through its veil (§5.6).
- **V16.** Three of M6's other options had fates that took the car or its fuel. **Δ docs/M6.md §3.3:** each takes "you", as the ★s' do (Q8, §5.5).
- **V17.** The Sewer Gator would read as a crocodile attacking in a street. **Δ docs/M6.md §3.3:** the Grim Reaper takes its place (Q6).
- **V18.** Only the worm's test checked that a legend without a veil (§5.4) has no glow, and only at its start. `test_only_a_legend_with_a_veil_has_glows` checks each at every frame, by the material each part draws with (`material_of()`).

## 3. Decisions

- **Q1.** Three legends in each pool, the ★ and two more: ten new ones, in two waves.
- **Q2.** A seen disaster weighs `SEEN_DISASTER_WEIGHT`, 0.5, and one not seen yet 1: half as likely as each unseen one, not half an even share (§5.3).
- **Q3.** Seen means seen once, anywhere: a card in the collection (V3).
- **Q4.** Picked as the car reaches the area, on its own stream: the pick that the run's start would make (§5.2).
- **Q5.** The legends load at boot (V12, E11).
- **Q6.** The City's third is the Grim Reaper (V17).
- **Q7.** The wisps change the car (V13).
- **Q8.** Each fate takes "you" (V16).
- **Q9.** No screen shows the pools or the weights (V14).
- **Q10.** One stack: a wave of one legend for each area, then a second, so no two PRs in a row touch one area's lines (docs/M6.md §5.10); then the docs.
- **Q11.** PR 1 changed the picks' docs, PR 12 the rest.

## 4. Work breakdown

- **PR 1** (#81): `DisasterPicks`, the director's `enter_area()`, `seen_disasters()`, `SEEN_DISASTER_WEIGHT`, and V7's, V8's, V11's and V18's tests.
- **PR 2** (#82): the Mothman; `night_share()`; the art tests' bytes and particle sheets (§5.6).
- **PR 3** (#83): the scarecrow; `apply_params()` scales a range with no width once.
- **PR 4** (#86): the kelpie, and `Kelpie.to_middle()`, the middle of the road ahead.
- **PR 5** (#87): Frau Holle's well.
- **PR 6** (#88): the Marfa lights, and `glow_share()` (§5.6).
- **PR 7** (#89): the Grim Reaper.
- **PR 8** (#90): the Headless Horseman.
- **PR 9** (#91): the will-o'-the-wisps.
- **PR 10** (#96): Baba Yaga's hut.
- **PR 11** (#98): the chupacabra.
- **PR 12**: this summary.

### 4.4 Landing

Agents landed PRs 1–10 with `tools/agent/land_pr.sh`, the owner PR 11. PR 12 started from `main`, as it rewrites cites in PR 11's files.

## 5. Design

### 5.1 The picks

`DisasterPicks` (`disasters/disaster_picks.gd`), a pure `RefCounted` (IP D2), holds a run's picks; the director makes it in `start_run(run_seed, seen)`.
- **A stream for each area.** `pick(area)` draws once, with `rand_weighted()`, on `stream()`, seeded with `hash("%d:pick:%s" % [run_seed, area_id])`, so the pick is the same whenever it's made. `_picks` keeps it by `AreaDef`, as `AreaSchedule.starting_at()`'s copies share their areas.
- **The weights.** 1 for each scene, or `SEEN_DISASTER_WEIGHT` if the collection has its id (Q2).
- **The ids** (V11, P6). `id_of()` reads the `id` set on a scene's root from its `SceneState`, making no node, in a `.tscn` or the export's binary copy.
- **Broken pools** (V4). An empty pool picks nothing. An empty slot is an error and weighs 0. With no weight above 0, `draw()` reports an error and returns the first scene.
- **The director** plays `picks.pick(_area)`; `enter_area()` makes the pick sooner. Its `disaster` stream draws the params alone: the old `randi_range(0, 0)` left it as it was, so each ★ kept its params (E6).

### 5.2 When the picks are made

Picking at each area costs nothing more, as the pools load at boot either way (§5.7), and with lazy loading (§9) would load only the pick. `_start_run()` enters the first area, the City or that of `--area` or the Start choice (docs/ZONE_SELECT.md), with the pick that a run from the City would make there; the tutorial's switch to the City's rules keeps its pick (docs/TUTORIAL.md T19). `CarSim.area_changed` enters each next; with none entered, the wrong turn picks. `enter_area()` runs before `EventBus.area_changed` (§9).

### 5.3 The weights and the odds

| Of an area's three, seen | Each seen one | Each one not seen |
|---|---|---|
| None | | 33.3% |
| One | 20% | 40% |
| Two | 25% | 50% |
| All | 33.3% | |

A player meets all three of an area in 4.25 runs that end there, on average, against 5.5 with even odds and 3.7 with Q2's alternative; 3.25 with its ★ already seen.
- **Read as each run starts.** A disaster is saved as seen as it starts, so the collection never changes during a run. Seen once or ten times weighs the same (§9).
- **The same seed and collection give the same disasters** (`plan.md` §3.5); a seed alone may pick another legend once the collection grows (§8), so tests empty the save (V8).

### 5.4 The pools and the legends

| Area | ★ (M6) | Wave A | Wave B |
|---|---|---|---|
| City | Phantom Bus: aboard, dusk | Mothman: up, night | Grim Reaper: down, dusk |
| Rural | UFO: up, night | Scarecrow: away, none | Headless Horseman: changed, dusk |
| Meadows | Fairy Ring: away, dusk | Kelpie: down, none | Will-o'-the-Wisp: changed, night |
| Village | Witch's Hex: changed, dusk | Frau Holle's Well: down, none | Baba Yaga's Hut: aboard, dusk |
| Desert | Death Worm: down, none | Marfa Lights: away, night | Chupacabra: changed, none |

Each cell gives the legend's way and veil: an area's three take the car three ways. **Δ docs/M6.md §3.3:** the Reaper replaces the Sewer Gator (V17), the wisps change the car (V13), and the Horseman hurls ghost-fire, not a pumpkin. The new beats, `Tuning.<ID>_BEATS`, add up to 2.4–2.5 s; frames are at most 96 × 96, in the palette's colours; no emitter is additive. In brackets, what each leaves:
- **Mothman** (`mothman`): red eyes open at the roadside; it glides to the car and lifts it away (a grey feather). Its eyes, its glow, light once.
- **Scarecrow** (`scarecrow`): it turns its head, and crows, particles, rise from its arms and carry the car off (the scarecrow).
- **Kelpie** (`kelpie`): a black horse rises from a pool by the road, and plunges into it with the car (the pool, waterweed).
- **Frau Holle's Well** (`frau_holle`): snow falls; a well rises beside the road, and the car falls in, turning over (the well, in snow).
- **Marfa Lights** (`marfa_lights`): lights glimmer far up the screen, gather round the car, and it follows them away (tyre tracks). Its figure is its glows, white and amber.
- **Grim Reaper** (`grim_reaper`): it beckons; the road opens into a grave, and the car rolls in and sinks (a gravestone). The scythe never moves.
- **Headless Horseman** (`headless_horseman`): he gallops up and hurls pale green ghost-fire, and the car fades as a ghost (scorched hoofprints).
- **Will-o'-the-Wisp** (`will_o_wisp`): four pale blue-green wisps circle the car, closing in; it shrinks into a fifth, and they drift off (bog cotton).
- **Baba Yaga's Hut** (`baba_yaga`): a hut on chicken legs stomps up, crouches and opens its door; the car rolls in, and it stomps off (chicken-foot prints). **Δ** Nothing glows: its window is painted, not lit.
- **Chupacabra** (`chupacabra`): a grey, spined beast pounces onto the roof, and the car's colours drain to grey, with no blood (the car's grey husk).

### 5.5 The words

Each scene sets its name, its fate for game over and its card's lore: a fate of at most 40 characters and a lore of 80, in Pixel Operator 8's glyphs. Each fate takes "you" (V16), and each lore names the legend's place, and its date where there is one.

### 5.6 A legend PR

The contract tests play every scene of the pools, so a new legend meets M6's rules, V11's and V18's once its area's `.tres` lists it.
- **Its art, the same each time** (N28). `test_legend_art.gd` runs each script in `tools/art/legends/` twice and compares the bytes; not with the committed sheets, which an artist may replace.
- **Particle sheets** (N29, N30). The sheet tests read each `CPUParticles2D`'s texture, in its material's `particles_anim_h_frames` × `particles_anim_v_frames` frames, or one; a shader, or a frame count under 1, fails.
- **The night** (V15). `art_checks.gd`'s `night_share()` lights each frame by each key light of `Tuning.LIGHT_COLORS` through the veil, per channel the less of the two. A pixel stands out if its luminance differs by `NIGHT_CONTRAST`, 0.1, of the light's from each lit main colour (`MAIN_SHARE`, 5%) of the area's road's `ROAD` row, ground and ground edge. `NIGHT_SHARE`, 25%, of the opaque pixels must, in the worst frame and light: the ★s score 28.0–44.8%, the ten 41.3–100%, what they leave 33.6–100%.
- **Glows** (P13b). A glow adds above Daylight and the veil: `glow_share()` adds its pixels × the tint to the lit ground, and 25% must stand out from it. The Marfa lights and the wisps score 90.6–91.9%.
- **N25.** Every opaque pixel set to the area's main ground colour, or a glow's tint black: 0%, so the night test fails.
- **Its own tests** are named for what the player sees; its PR breaks each rule and check, naming the tests each case fails.

### 5.7 The cost

| What | Measured |
|---|---|
| A pick | 2.37 µs; all five 11.86 µs |
| The boot, desktop | 444 ms from Godot's banner to `grey box: tilesets built in`, against 330 ms on PR 1's head and 320 ms on `pl/prototype`, the median of 7 cold starts; 2.11 MB more. The ten's scripts compile in 100 ms |
| The boot, Fold4 | At most 150 ms more than `pl/prototype`'s, by the owner (E11) |
| The builds | Web 11.51 MB, APK 58.56 MB: 0.29 and 0.32 MB more |
| GUT | 109.1 s locally, 9.1 s more than PR 1's head |

## 6. Verification

The five checks passed on each PR; at PR 11, 195 scripts, 703 tests and 437,643 asserts, with `main`'s smoke line.

- **N28.** Four white pixels at random in the fairy ring's art: the bytes test fails, alone.
- **N29.** The worm's 280 px sheet on its spray, uncut or in 3, 0 or −5 frames, or its crater with a `ShaderMaterial`: `test_each_sheet_is_one_row_of_whole_frames_none_too_large` fails. Uncut, the crows' 56 px sheet fits a frame's 96 px, so only `test_crows_rise_from_its_arms_and_into_the_sky` fails.
- **N30.** A particle sheet from another legend's folder: `test_each_legend_of_the_pools_draws_only_its_own_art` fails.
- **P2.** `draw()` over 100,000 seeds: §5.3's odds, each within 0.2 points.
- **P6.** Each ★'s `id`, read from the `SceneState` of its `.tscn` and of a binary `.scn` copy, as the export makes, matched its instance's (V11).
- **P13b.** Glows added over the lit ground at night: `glow.tres` 92–94%, the UFO's 100%, black 0%.
- **P15.** With the bus, the UFO and the fairy ring in the City, seed 3 picks the bus from an empty save, but the UFO with the bus seen (§8).
- **Seeds** that pick each legend from an empty save: City 0 Mothman, 1 Reaper, 3 bus; Rural 0 Horseman, 2 scarecrow, 11 UFO; Meadows 0 wisps, 1 fairy ring, 3 kelpie; Village 0 Frau Holle, 1 witch, 2 hut; Desert 0 worm, 1 chupacabra, 8 Marfa lights.

## 7. Owner actions

None left but deleting `pl/12-docs` once PR 12 lands.

## 8. Risks

- **A seed doesn't replay its legend** (P15) once its run has saved the legend as seen (§5.3). Replay a report from a copy of the save from before its run, in a scratch `XDG_DATA_HOME`, or with §9's `--legend=`.
- **The boot** (E11): if it shows with more legends or slower phones, load them lazily (§9).

## 9. Notes for later

- **Lazy loading** (Q5, V12): pools as paths, the pick loaded with `ResourceLoader.load_threaded_request()` from the area before; ids from file names, which a test keeps equal.
- **The Atlas's count** (V14): each area's seen legends, such as 1/3.
- **Omens** (§5.2): a hint of the pick as the car enters the area, a raven for the Reaper.
- **Weights that fall with each sighting** (Q2): 0.5 to the power of the times seen.
- **A `--legend=<id>` flag** for debug builds, for device checks and reports (§8).
- **A looping schedule** would meet an area's first pick again (`_picks`): decide then whether to pick anew.
- **Shared helpers.** The ten call other legends' statics, `PhantomBus.road()` (8) and `side()` (7), `Kelpie.to_middle()` (5) and `steer()`, `WitchHex.car_middle()` (3): in `Legend`, a change to one would no longer reach the others unseen.
