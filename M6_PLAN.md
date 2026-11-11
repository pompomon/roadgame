# M6 Legends — Detailed Plan

Status: answered by the owner in #45: Q8's alternative, scarier but still with no gore, and the defaults for the rest; being built (§4) · 2026-11-11 · Scope: new disasters drawn from myths, folk tales and urban legends, with three options for each area, their visuals, sound and lore (§3.3); the changes they need in the disaster contract, its tests, the palette and the UI; and where the milestone goes (Q1)

**Verified so far, and what isn't yet.** This plan reviews `main` at 4ade5f2 (#44). Each claim about the code cites its file and line. Each claim about Godot that its docs don't settle was checked with a probe, P1–P15 (§6.5): headless, or rendered with the Compatibility renderer (`opengl3` on Mesa llvmpipe under Xvfb, as IP M6.6 plans for screenshots). There was no prototype before the owner's answers: building all 15 options would have wasted the 10 not picked. Now `m6/prototype` is built as `AGENTS.md` §2 says, one commit per PR (§4.1). It fixes §6.1's counts, runs §6.2's negative cases and simulates the landing again on its own files (§4.5), and this plan takes its results before PR 1 opens. A model of another family reviewed this plan (`AGENTS.md` §7), and so did Copilot; their findings and the fixes are in §4.6.

- Godot 4.7.2-stable (Linux x86_64)
- GUT 9.7.1
- Mesa llvmpipe under Xvfb, for the rendered probes P5, P6 and P9

**Baseline.** On `main` (4ade5f2) with Godot 4.7.2: `check_scripts.sh` loads 125 scripts; `run_tests.sh` runs 60 scripts, 418 tests and 147,736 asserts in 43.0 s, all passing; `smoke.sh` prints `autopilot: tile 165, turns 35, area rural`; and `git status --porcelain` prints nothing.

**Precedence.** For M6, this document replaces `plan.md` §4.3's disaster pools and IP §9's line on disaster types wherever they differ. Each difference is marked **Δ** with its finding (S#, §2). With Q1's default, this milestone comes before Ship: IP §3's and §4's M6 "Ship" becomes M7, its work packages M6.1–M6.6 become M7.1–M7.6, and M5_PLAN.md §9's notes for M6 apply to M7. PR 8 folds the changes back into IP and `plan.md` (§4).

**Reference code.** None yet (above). §5 names the classes and functions that the prototype must have.

**Prerequisites.** M5 is merged (#39–#44). No repository settings change.

Contents:
1. Goal and exit criteria
2. Review findings
3. Decisions, questions and the legends
4. Work breakdown (8 PRs)
5. Design
6. Verification
7. Owner actions
8. Risks
9. Notes for later milestones

---

## 1. Goal and exit criteria

**Goal.** When a run ends at a junction, the player meets a legend of the area instead of a natural disaster: with Q2's default, a phantom bus in the City, a UFO over Rural's fields, a fairy ring in the Meadows, a witch's hex in the Village and a death worm in the Desert. Each is a 2–4 s scene that keeps the disaster contract (`disasters/disaster_base.gd:3–10`), reads at the reference screen of 360×640, and plays the same on Android and the Web. The tone is scary, with no gore: no blood, no wounds and no one hurt on screen (Q8).

| ID | Exit criterion | How it is checked |
|---|---|---|
| E1 | Each area's pool holds the legends chosen for it (Q2), and no pool holds a natural disaster (Q3) | `test_disasters.gd`'s pools test; `test_disaster_pools.gd` plays every legend of every pool |
| E2 | Each legend keeps the contract: hidden until its delay and shown after it, `finished` once at `duration()`, 2–4 s with the car's stop, the car's position untouched and the car hidden at the end, seeded particles, no polygon drawn twice, and no errors without a car or a camera. The checks see every drawable: polygons, sprites and particles, the parts on the stage and the car's double (S1, S6) | the generalized `test_disasters.gd` |
| E3 | Each legend's beats play in order, a beat that a frame skips still ends in its final state, and the parts are where §3.3 says at the end of each beat | `test_beats.gd`; `test_<legend>.gd` |
| E4 | Standing parts sort with the props by their foot, and everything a legend puts on the stage is freed with it: on retry, on going to the title, and when the World is freed (S2, P8) | `test_legend.gd`; `test_retry.gd` |
| E5 | A night or dusk veil covers the whole view at every reference screen and zoom, draws over everything else in the World, fades by `self_modulate` (P6), and leaves the HUD alone (P9) | `test_legend.gd`; the Web checks (E11) |
| E6 | No legend flashes: a veil never reverses; at each point of the view, the glows' light, added up, brightens and dims at most 3 times in any second, and their red light at most once; and no glow covers a quarter of the reference view (WCAG 2.3.1; S4, S11) | the flash test in `test_disasters.gd`, run on every legend |
| E7 | Each legend's sheet keeps its contract: palette colours or clear pixels only, its frame size and count, lossless import without mipmaps. The palette has 36 colours (Q4) | `test_area_art.gd` (every PNG); `test_legend_art.gd` |
| E8 | Each legend has its sound, within the effects' peak budget, and it starts on the frame the legend shows, whatever the delay (S18). It is made from its id and its own synth and beats alone, so no later PR changes it (S17) | `test_audio_director.gd`; `test_disaster_director.gd`; `test_wrong_turn_disaster.gd`; `make_audio.gd` makes every WAV again byte for byte (§4.1) |
| E9 | The game-over screen says what the legend did to the car, and a seen legend's card in the collection shows its lore. All this text fits a 360×640 screen and has its glyphs in the game's font (Q6, Q7; S8, S12, S15, S16) | `test_game_over.gd`; `test_collection_screen.gd`; `test_title_screen.gd`'s layout test, with every disaster of the pools seen; `test_smoke.gd`'s glyph test |
| E10 | Once no pool uses them, the natural four are deleted with their scripts, scenes, tests, sounds and tuning. Saves that recorded them still load (Q3, Q9) | PR 8's diff; `test_collection_screen.gd`: a save that recorded the sinkhole |
| E11 | The Web build plays each legend in Chrome and Firefox without WebGL errors, and the owner's checks on the Galaxy Z Fold4 pass | `AGENTS.md` §6's Playwright run; §7 |
| E12 | The five local checks and CI pass on each PR, the stack lands without conflicts (§4.5), and the documents carry the Δs | §6.1; §4.5; PR 8 |

---

## 2. Review findings

Each finding has its evidence and its fix. The fixes are in §4's PRs, and §6.2's negative cases show that their tests fail without them.

### High

**S1. The contract's visibility checks see only polygons.**
- Evidence: "shows a second after its delay" filters `Disasters.polygons()` (`tests/unit/test_disasters.gd:58`), and `_assert_hidden()` checks polygons and particles (`:66–69`), through `tests/helpers/disaster_fixtures.gd:107–119`. The natural four are drawn with polygons. A legend drawn with sprites fails the first check though it shows, and passes the second though it may show too soon. Parts on the stage (S2) and the car's double (S3) aren't the legend's descendants, so neither check would see them.
- Fix: `Disasters.drawables(disaster)` returns every Polygon2D, Sprite2D and CPUParticles2D under the disaster, plus what it put on the stage (`Legend.staged()`). Both checks use it; particles are still checked by `emitting`. N1, N2.

**S2. Standing parts can't sort with the props.**
- Evidence: `world/world.tscn:26–31` puts DisasterLayer above the road but before Props, which is y-sorted, and `test_world_renderer.gd:369–378` keeps that order. A part at z 0 hides behind every prop, and a part at z 1 (`sinkhole.tscn:20`, `flood.tscn:16`) covers every prop, the building in front of it too. M5_PLAN.md:629 (§9) saw this coming. The natural four lie flat on the road, so it never showed. A bus, a scarecrow or a worm stands up.
- Fix: the director gets a `stage`, which `ui/main.gd` sets to World's `%Props` as it sets the layer (`main.gd:45`). It hands it to the disaster with the car and the camera (`disasters/disaster_director.gd:113–116`). `Legend.stand()` puts a standing sprite on the stage, where it sorts with the props by its foot, and the legend frees what it staged in `_exit_tree()` (P8). Only sprites stand: a polygon moved to the stage would draw again (S6). Without a stage, as in unit tests, the sprites stay under the legend. Flat parts, such as a crop circle, stay under the legend on DisasterLayer. N3, N4.

**S3. The car can't leave.**
- Evidence: a disaster may change the car's scale, modulate and rotation, but not its position (`disaster_base.gd:24–26`), because `car/car_controller.gd:41–44` sets the position and the frame every physics frame. At the end the car must be where it stopped, and hidden (`test_disasters.gd:98–99`). A legend that carries the car off, such as the bus, the UFO or the worm, needs something else to move.
- Fix: `CarController.double()` returns a Sprite2D that looks like the car does now. The legend stages it and hides the car (`modulate.a = 0`) in the same frame, then moves the double. It lifts it by its `offset`, so its foot, and so its place in the sort, stay put (S2). It sinks it into the ground by cropping its region from the bottom (P3), and turns it by stepping its region through the 16 headings. N5–N7.

**S4. A multiply veil ignores alpha.**
- Evidence: P6. With `BLEND_MODE_MUL`, `modulate.a` 0.5 darkens as much as 1.0, and only an alpha near 0 hides the veil, because the canvas then skips the item. Fading a night veil by alpha would turn the whole view from day to night in one frame: a general flash in WCAG 2.3.1's terms, and a jolt.
- Fix: `Legend.veil()` keeps the veil at `modulate.a` 0 until the delay. Then it sets it to 1 with `self_modulate` white, which changes nothing, and lerps `self_modulate` to the tint. P6 shows that halfway gives half the darkening. E6's test checks that the veil never reverses. N8.

### Medium

**S5. Lines shared by the legend PRs would conflict as the stack lands.**
- Evidence: P7 (§6.5). After PR k's squash merge, merging `main` into PR k+1's branch conflicts wherever the two PRs changed adjacent lines. One unchanged line between the changes avoids it, but only if that line is in the merge base, which holds `main` and the PRs before PR k. Each legend PR would change:
  - the counts at `tests/unit/test_audio_director.gd:279` (`ids.size() == 4`) and `:328` (`budgets.size() == 20`);
  - the pools at `test_disasters.gd:16–22`, one line per area, and its list of all four at `:41`;
  - the expected ids at `tests/integration/test_disaster_pools.gd:65–69`;
  - the disasters' sounds at `autoload/audio_director.gd:33–36` and their generators' calls at `tools/audio/make_audio.gd:38–41`, four lines each;
  - the synths at `make_audio.gd:159–196`;
  - the disasters' constants in `config/tuning.gd:133–165`.
- Fix: PR 2 derives the counts and lists from the data (S15). PR 1 adds a comment line for each area to each list that the legend PRs add to, such as `# The City's legends.`, and moves the natural four into a block of their own, which only PR 8 changes (§4.5, §5.10). It must be PR 1, not PR 2. When PR 3 is updated after PR 2's squash, the merge base holds PR 1's lines but not PR 2's, so a comment added by PR 2 would separate nothing (P7, N30). Each legend's art generator, script, scene, sheet, sound and test are files of its own.

**S6. Polygons made late escape the redraw test.**
- Evidence: `test_disasters.gd:152–164` connects to `draw` only on the polygons that exist two frames after setup. A polygon made later, such as a veil made at the delay, isn't counted, and neither is one moved to the stage, which draws again as it enters the canvas. Hiding and showing a polygon with `visible` draws it again (P1), as a change of its `color` does (P2) or of its `polygon` or `offset` (M4_PLAN.md K9). On the Web, every redraw of a Polygon2D after its first raises WebGL errors in Godot 4.7.2 (godotengine/godot#124726, fixed in 4.8; M2_PLAN.md §5.7).
- Fix: a legend makes every polygon and every particle emitter before `play()`, in its scene or in `_ready()`, and keeps them under itself, hidden by alpha 0 or scale 0 as `flood.gd:33` and `tornado.gd:50` do. It never toggles a polygon's `visible` or changes its `color`, `polygon` or `offset`. The test also checks that the polygons after the run are the ones from before `play()`, and that nothing staged is a polygon, so a late one fails rather than going unwatched. Sprites may change their frame, region and offset: that draws a rect, not a mesh (P3), as the car's frame does every physics frame (`car/car_controller.gd:44`), with no errors in M5's Web checks (M5_PLAN.md:574). N9, N10.

**S7. Many beats, one clock.**
- Evidence: `finished` must come within `DELTA * 1.01` of `duration()` (`test_disasters.gd:90–95`), and each clock that adds up steps of DELTA can end a frame late (`:172–174`, M3_PLAN.md P10). A legend with 4–5 beats, each on a clock of its own, could end frames late.
- Fix: `Beats` keeps one clock from `play()` and finds the beat from the beats' cumulative ends. `test_beats.gd` checks that 5 beats end within one DELTA, and that a step that skips a beat still shows that beat's end. N11, N12.

**S8. Nothing says which disaster ended the run.**
- Evidence: the game-over screen's messages go by CarSim's cause (`ui/game_over.gd:16–21`), and `open(stats, area)` takes nothing else (`:41–45`). `main.gd:224–225` knows the disaster when it starts. For a legend, being named is the point.
- Fix (Q6): `DisasterBase.fate`, a line such as "The bus with no driver took you aboard." `main.gd` keeps the fate from `disaster_started`, clears it at each run's start, and passes it to `GameOver.open()`, which shows it under the cause. A crash has none. PR 1 writes the natural four's fates too. N13, N14.

**S9. The palette has no colours for night magic.**
- Evidence: `assets/palette.gpl` has 32 colours, and none is a deep blue, a violet, a lilac or a pale spirit green. The nearest are shadow (52 48 60), foam (158 199 240) and meadows light (140 200 108). `plan.md:199` asks for 16–32 colours.
- Fix (Q4): add night, violet, lilac and wisp (§5.7), 36 in all: **Δ plan.md §5.3**. Every PNG under `res://assets` keeps to the palette, which `test_area_art.gd:88–96` checks. A veil's tint is a multiply factor, not a pixel's colour, so it lives in `Tuning` (§5.5).

**S10. Additive glows clip to white on light ground.**
- Evidence: P5. An additive (110, 220, 160) over the grey box's ground (200, 200, 200) gives white; over the night veil it gives (133, 247, 216).
- Fix: glows (`BLEND_MODE_ADD`) only where a veil darkens the view or over a dark part. In daylight, lights are plain sprites.

**S15. Tests name the natural four as the game's disasters.**
- Evidence: once PR 3 gives the City its legend, these fail:
  - `tests/integration/test_wrong_turn_disaster.gd:71` (the car at `Sinkhole.SUNK_SCALE`), `:104` and `:108` (`&"sinkhole"`);
  - `test_title.gd:154` (the card "Sinkhole");
  - `test_disasters.gd:31–35`, which wants each pool's scene at `res://disasters/<id>.tscn`, not under `disasters/legends/`;
  - `tests/unit/test_area_schedule.gd:67–68` (the City's pool is the sinkhole);
  - `test_collection_screen.gd:42–53`, `:74–110` and `:116`, which read the game's schedule: its four disasters, four cards, and the sinkhole's first. From PR 4 on, the pools hold five or six disasters.

  `test_disaster_pools.gd:65–69` and `test_collection_screen.gd:47–50` have a line per area, which neighbouring legend PRs would change (S5). After PR 8, `test_collection_screen.gd:63` loads `flood.tscn`, which is gone. And `test_title_screen.gd:110`, the layout test with the longest texts, marks only the four as seen (`:114–119`), so a lore that doesn't fit 360×640 would go unnoticed.
- Fix: PR 2 makes them read the pools, and checks only a scene's file name. The City's disaster, whichever it is, takes the car and is saved; the collection shows the card of the disaster that played; and each area's wrong turn plays one of its pool. The card tests are PR 1's. PR 1 changes the cards (S12), and with them the dicts that `test_collection_screen.gd:44–52` and `:70` compare, so it moves every test of that file to a schedule of packed test disasters (`Disasters.packed()`), one of them in two pools, as the Village's flood and tornado are now, and `:63`'s flood to one of them. PR 2 then leaves that file alone (§4.5). PR 1, which adds the lore, also makes the layout test mark every disaster of the pools as seen, so each legend's lore is laid out at 360×640 as its PR adds it (E9). N22.

**S16. The layout test fails on cards the collection scrolls to.**
- Evidence: P13. With the five ★ legends seen and their lore under their details, the cards are 891 px high in the collection's 504 px `Scroll` (`ui/collection_screen.tscn:37–45`), and 2 of them end below the screen. That's what the scroll is for, but `test_title_screen.gd:127–130` requires every visible control to lie within 360×640. No card is wider than the screen: the scroll doesn't scroll sideways (`:40`), and the labels wrap (`ui/menu_card.tscn:24`, `:29`).
- Fix: PR 1's layout test checks a control inside the scroll only against the screen's width, and checks that the scroll itself fits. Then it scrolls to the last card (`ensure_control_visible()`) and checks that the card is inside the scroll's rect. N23.

**S17. One generator makes every sound.**
- Evidence: `tools/audio/make_audio.gd` draws every sound's noise from one generator (`:24`), seeded once (`:28`), in `_initialize()`'s order (`:29–41`): through `_noise()` (`:264–267`), and directly, as the sinkhole and the flood do (`:163`, `:187`). A legend's sound, made after theirs, would change when PR 8 deletes them. PR 8 would then change `death_worm.wav`, which PR 7 adds: an add/add conflict (§4.5). A second legend for an area (Q2) would change the sounds of every area after it.
- Fix: PR 1 adds `_save_legend(id, synth)`, which seeds the generator with `hash(id)` and then saves the synth's sound (§5.9). A legend's sound then depends only on its id (P14). A sheet that uses chance has a generator of its own, seeded the same way (§5.7). N32.

**S18. A disaster's sound starts before its picture.**
- Evidence: the director emits `disaster_started` as it calls `play()` (`disasters/disaster_director.gd:119–120`), and `main.gd:224–225` passes it on to `EventBus`, where `AudioDirector` plays the disaster's sound at once (`autoload/audio_director.gd:73`, `:265–266`). The disaster shows only after `params.delay`, 0.1–0.5 s a run (`disasters/disaster_params.gd:26`, `config/tuning.gd:118–119`), as `sinkhole.gd:57–59` counts it. A legend's sound has cues on its beats, such as the UFO's zip and Baba Yaga's steps, and a WAV that starts early misses them by a different amount each run.
- Fix: PR 2's director emits `disaster_appeared(disaster, area)` once, on the frame the delay is over. It counts the delay as the disaster does, on a clock of its own from `play()`, since its `_time` counts from the run's end (`:27–28`); `clear()` resets that clock. In the main scene the disaster steps before the director (`test_disaster_director.gd:14–15`), and a node added during a step first steps on the next frame, so both clocks add the same steps, and the signal comes on the frame the disaster shows (P15). `main.gd` relays it to `EventBus.disaster_appeared`, where `AudioDirector` plays the sound, so a legend's synth puts each cue at its beat's start (§5.9). `SaveService` still records the disaster at `disaster_started` (`autoload/save_service.gd:35`), so a player who closes the app during the delay keeps it (M5_PLAN.md L7). The natural four's sounds start with their pictures too, 0.1–0.5 s later than on `main`. N36.

### Low

**S11. No rule or test against flashing.** None of the natural four flashes, so nothing checks it. Several legends have lights that pulse: the UFO's rim, the wisps, the Marfa lights. Fix: E6's test, run on every legend. Lights that overlap add up, so it measures their sum at each point of the view, not each glow alone (§5.6). N20, N21.

**S12. The collection shows only names.** A seen card shows the name and `seen_text()` (`ui/collection_screen.gd:34`, `ui/menu_card.gd:13`). Fix (Q7): `DisasterBase.lore`, one sentence, which a seen card shows in a `%Lore` label of its own, under `%Details` (§5.8). `%Details` keeps its text, which `test_title.gd:155–158` reads. `test_smoke.gd:18–49` checks names' glyphs in the game's font; PR 1 adds fates and lore. N17, N35.

**S13. One test is for the Village's pair.** `test_disaster_pools.gd:72–80` checks that 8 seeds play both of the Village's disasters. With one legend per pool it would check a pool of one. Fix: PR 2 makes it check that every disaster of every pool plays, which also covers Q2's larger choices.

**S14. The documents list the natural four.** `plan.md:158–167` (§4.3's pools) and `:293` (§8's files); `IMPLEMENTATION_PLAN.md:960` (§9: "4 disaster types"), and `:83` and `:98`, where M6 is Ship. Fix: PR 8's Δs (§4).

---

---

## 3. Decisions, questions and the legends

### 3.1 Questions

The owner chose Q8's alternative, still with no gore, and the defaults for the rest (#45, 2026-11-11). The prototype follows these answers. Each other alternative would change the PRs named.

| # | Question | Default | Alternative |
|---|---|---|---|
| Q1 | Where does this milestone go? | Before Ship. IP's M6 "Ship" becomes M7, with M5_PLAN.md §9's notes (PR 8; **Δ IP §3, §4**) | After Ship, as M7. This plan's citations are checked again on Ship's code |
| Q2 | Which legends? | One per area, §3.3's ★s: the phantom bus, the UFO, the fairy ring, the witch's hex and the death worm | Up to three per area, each of §3.3's size and with a line in its pool. An area's further legends share a PR like PR 3, after PR 7 (§4.5). Not both the sewer gator and the death worm: both come from below |
| Q3 | Do the legends replace the natural four? | Yes. PR 8 deletes them (E10) | Keep them in the pools beside the legends. PR 8 deletes nothing |
| Q4 | Colours for night magic (S9)? | Add night (40 44 92), violet (112 72 160), lilac (190 150 230) and wisp (150 240 190): 36 colours (**Δ plan.md §5.3**) | Keep 32: magic in foam, red and yellow, and no glows in a veil |
| Q5 | Which legends darken the view? | A night veil for the UFO, Mothman, the wisps and the Marfa lights; a dusk veil for the bus, the horseman, the fairy ring, the witch and Baba Yaga | No veils: lights are plain sprites (S10), and E5 goes |
| Q6 | Does game over name the legend? | Yes: a fate line under the cause (S8) | No: no `fate`, no N13, N14 |
| Q7 | Does the collection tell the legend? | Yes: a seen card adds its lore (S12, S16) | No: no `lore`, no S16 |
| Q8 | How scary? | Spooky-funny, for all ages: no gore, and no one hurt on screen. The car is taken, shrunk or changed, never smashed | **Chosen**, with no gore: scarier. The ★s get darker veils, eyes in the dark, grim sounds and words (§3.3); the car is still never smashed, and no one is hurt on screen. §3.2's omens of death may come back (§9), and the store's content rating needs a look (§7) |
| Q9 | What of saves that recorded a natural disaster? | Nothing: they load as before, as `_read()` keeps any id (`autoload/save_data.gd:155–158`), and the collection shows only the pools' disasters | A save version 2 that drops them, with a migration (`autoload/save_data.gd:59`) |
| Q10 | Should props near a standing legend hide? | No: it sorts with them (S2) | Hide them for the scene: the prop pool needs a way to, and tests |
| Q11 | Placeholder art? | Sheets made by script, as M5's are (`tools/art/`), with contracts that final art must keep (E7) | Hand-drawn sheets first, held to the same contracts |

### 3.2 Choosing the options

Each option:
1. reads at 360×640 in 2–4 s without words;
2. belongs in its area;
3. ends with the car gone and something left behind, so the last frame tells what happened;
4. is eerie or frightening but shows no gore: no blood, no wounds and no one hurt on screen (Q8); comes from folklore or a public-domain story, and isn't sacred to a living tradition;
5. takes the car another way than its area's other two;
6. needs only sprite sheets with frames of at most 96×96, and no polygon drawn twice (S6).

Across the ★s, the car goes five ways: aboard, up, away, changed and down.

Left out:
- the vanishing hitchhiker (the hitchhiker vanishes, not the car) and the ghost stagecoach (the bus and the horseman again);
- the Pied Piper (the wisps' luring, and the children), the roc (Mothman again) and Nessie (the kelpie again);
- Slender Man, Siren Head and the Backrooms: recent works with owners;
- the skinwalker, the wendigo and the thunderbird (sacred to Indigenous nations), La Llorona (drowned children) and the djinn (religious);
- Krampus, which is seasonal.

### 3.3 The legends

Beats are in seconds after the delay (0.1–0.5 s, `config/tuning.gd:118–119`). Each legend's beats add up to 2.3–2.6 s, so with the delay and the car's stop it takes 3.0–3.7 s (E2). A sheet is `assets/legends/<id>/<part>.png`, given as its frame size × its frames. Colours are the palette's, by name (`assets/palette.gpl`), with Q4's four in italics. The double is the car's stand-in (S3), a standing part sorts with the props (S2), and a glow is an additive light, used only in a veil or over a dark part (S10). Sizes, once PR 2 is in: S up to 1 day, M 1–1.5 days, L 2 days. Q8's answer made the five ★s scarier: darker veils (§5.5), eyes in the dark, low and dissonant sounds, and grim words, still with no gore. The other ten are as first proposed, and would darken the same way if chosen (§9). P13 checked every name, fate and lore below: all their glyphs are in the game's font, Pixel Operator 8, and the longest are 17, 39 and 79 characters.

#### City (now: the sinkhole)

**★ Phantom Bus** · `phantom_bus` · M · fog 0.5, approach 0.9, board 0.4, leave 0.7
- Look: a dusk veil, and a cold fog (white particles) rolling over the road. A red double-decker, half see-through and with no one at the wheel, glides out of it along `params.direction`, its headlamps two *wisp* glows. Its windows are ink, with pale faces (white) pressed to the glass. It stops by the car, its doors open on the dark. `bus.png`: 64×56 × 6, two facings × three door frames, flipped for the other two facings.
- The car: the double slides to the doors and shrinks into them. The doors close, and the bus glides off into the fog and fades.
- Left behind: a ticket (`ticket.png`, 12×8; white and red) on the road.
- Sound: a cracked bell tolling twice, a low engine drone, the doors' hiss.
- Words: "The bus with no driver took you aboard." / "North Kensington, 1934: a driver died swerving from a ghostly No. 7 bus."

**Sewer Gator** · `sewer_gator` · M · rumble 0.5, burst 0.4, jaws 0.7, drag 0.5, hold 0.4
- Look: no veil. The street shakes (`camera.shake()`, as in `sinkhole.gd:63`), and a manhole cover by the car (`cover.png`, 24×12 × 2; asphalt light) bursts up on a jet of steam (white particles). An alligator's head (`gator.png`, 48×48 × 5: rising, jaws open, jaws shut, sinking; meadows dark, white teeth) rises from the hole.
- The car: the jaws shut over the double, and the gator sinks back by cropping (S3), taking it under.
- Left behind: the cover, askew by the open manhole.
- Sound: a rumble, a clang, a snap.
- Words: "A sewer gator dragged you under." / "New York, 1935: boys pulled an alligator out of a Harlem sewer."

**Mothman** · `mothman` · M · dim 0.5, eyes 0.4, swoop 0.6, carry 0.9
- Look: a night veil. Two red eyes (a red glow) open above the car once and stay lit (E6). Mothman (`mothman.png`, 64×48 × 4 wing frames, beating at most 3 times a second; ink and shadow) swoops down out of the dark.
- The car: Mothman takes the double and climbs; the double rises by its offset (S3) and leaves the view.
- Left behind: dark feathers (`feather.png`, 8×8) drifting down to the road.
- Sound: heavy wingbeats, a low screech.
- Words: "Mothman carried you off." / "Point Pleasant, West Virginia, 1966: a winged man with red eyes."

#### Rural (now: the tornado)

**★ UFO** · `ufo` · M · night 0.5, descend 0.5, beam 0.4, lift 0.8, zip 0.4
- Look: a night veil falls over the fields. A dark saucer (`saucer.png`, 56×24 × 4; shadow and asphalt, with *wisp* lights turning round its rim at most 3 times a second) drops without a sound and hovers over the car. A cone of cold light (a *wisp* glow, opened by `scale.x` from 0 to 1) falls on the car, with white sparkles rising in it. Three tall grey figures (`grey.png`, 12×32 × 2: facing, head tilted; asphalt light, with ink eyes) stand at its edge, on the stage, and watch.
- The car: the double shudders, then floats up the beam by its offset, turning through its 16 headings, and is gone into the saucer. The beam closes, the figures are gone, and the saucer zips off.
- Left behind: a crop circle (`crop_circle.png`, 64×32; rural dark) scorched into the field.
- Sound: rising radio static, a deep throb, a high whine, and a zip into silence.
- Words: "They took you. Two hours are missing." / "New Hampshire, 1961: Betty and Barney Hill lost two hours on a night drive."

**Headless Horseman** · `headless_horseman` · M · hooves 0.5, gallop 0.8, hurl 0.5, fade 0.7
- Look: a dusk veil. Hooves drum, and a headless rider in a fire-orange cape on a black horse (`horseman.png`, 56×56 × 8: four gallop frames, two facings; ink, shadow and fire) gallops in with ghost-fire at its hooves (fire particles), rears, and hurls a lit jack-o'-lantern (`pumpkin.png`, 16×16 × 2; fire and yellow) in an arc.
- The car: the pumpkin lands on it in a puff of smoke (white particles), and the car is gone. The rider gallops off and fades.
- Left behind: the jack-o'-lantern, grinning on the road.
- Sound: galloping hooves, a whinny, a pop.
- Words: "The Headless Horseman took your car." / "Sleepy Hollow, 1820: a headless rider hurls his head. Or was it a pumpkin?"
- Its jack-o'-lantern repeats the witch's (the Village's ★). With both, he hurls a ball of ghost-fire instead.

**Scarecrow** · `scarecrow` · S–M · creak 0.4, turn 0.4, flock 1.0, scatter 0.6
- Look: no veil, in broad day. A scarecrow (`scarecrow.png`, 32×48 × 4: still, head turning, head turned, arm raised; plank, rural light straw and a shadow hat) stands in the field by the road and slowly turns its head to the car. Crows burst from it (particles with an 8×6 × 2 ink texture, orbiting) and wheel round the car.
- The car: the crows swarm over it, and it shrinks away under them, as the sinkhole's car does. Then they scatter.
- Left behind: the scarecrow, with a crow on its raised arm.
- Sound: a creak, then caws and the flutter of wings.
- Words: "The scarecrow sent its crows for you." / "Farm tales tell of a scarecrow that turns its head as you pass."

#### Meadows (now: the flood)

**★ Fairy Ring** · `fairy_ring` · M · sprout 0.6, glow 0.5, spin 0.9, hold 0.4
- Look: a dusk veil. Ten pale toadstools (`toadstool.png`, 10×10 × 3 growing frames; white caps with shadow spots) sprout one by one in a ring round the car, standing on the stage. A sickly *wisp* glow swells over each in turn and stays lit. Pairs of small yellow eyes (glows) open one by one in the grass beyond the ring and watch, and *lilac* and *wisp* sparkles circle inside it.
- The car: the double spins through its 16 headings, faster and faster, as if made to dance, shrinks to a point and is gone. The eyes close.
- Left behind: the ring of toadstools.
- Sound: tiny bells out of tune, thin laughter, a rising whirl, then one low chime.
- Words: "The fair folk made you dance forever." / "Step into a fairy ring and you dance with the fair folk. Years pass in a night."

**Will-o'-the-Wisp** · `will_o_wisp` · M · lights 0.5, circle 0.6, bog 0.4, sink 0.8, out 0.3
- Look: a night veil over the meadow. Three to five wisps (*wisp* glows round white cores; the count from `params.intensity`) light one after another and circle the car, at most half a turn a second (E6). The ground under it turns to bog: a meadows dark pool, grown by `scale` from 0, with bubbles (particles).
- The car: the double sinks into the bog by cropping.
- Left behind: the bog, and one wisp drifting away as the others go out one by one.
- Sound: soft chimes, a bubbling glug.
- Words: "The wisps led you into the bog." / "Lights over the marsh that lead travellers astray."

**Kelpie** · `kelpie` · M · spill 0.6, rise 0.5, rear 0.5, dive 0.6, hold 0.3
- Look: no veil. Water spills over the road round the car: a meadows water pool, grown by `scale` as the flood's water is. A water horse (`kelpie.png`, 48×56 × 5: rising, rearing, diving; meadows water and foam, with a meadows dark mane of weed) rises from it and rears.
- The car: the kelpie dives, and the double sinks with it by cropping, in a splash of foam (particles).
- Left behind: the pool, with rings of foam.
- Sound: a splash, a whinny, a deep plunge.
- Words: "A kelpie carried you into the loch." / "Scotland: a water horse that carries its riders into the loch."

#### Village (now: the flood and the tornado)

**★ Witch's Hex** · `witch_hex` · S · cackle 0.5, hex 0.5, puff 0.6, pumpkin 0.8
- Look: a dusk veil. A hunched witch on a broomstick (`witch.png`, 32×24 × 2; ink, *violet* and plank, with *wisp* eyes) swoops in out of the dark, circles the car once and points a long finger. A trail of *violet* sparkles runs from her finger to the car.
- The car: a puff of black smoke (ink and *violet* particles) hides it. When the smoke clears, a jack-o'-lantern (`pumpkin.png`, 24×20 × 2; fire, with an ink grin and a desert cactus stalk) has popped up where it stood, by `scale`, and a yellow glow lights its grin from within. The witch flies off, cackling.
- Left behind: the jack-o'-lantern, its grin lit.
- Sound: a long, low cackle, a whoosh, a poof, a hollow knock.
- Words: "The witch made you her jack-o'-lantern." / "Village tales: cross a witch after dark and she keeps you, lit, on her step."
- No double: the car hides in the puff. That makes it the cheapest legend.

**Frau Holle's Well** · `frau_holle` · M · well 0.5, tip 0.5, fall 0.7, snow 0.8
- Look: no veil. An old stone well grows out of the cobbles by the car: its back wall (`well_back.png`, 40×32; shadow and city light, under a plank roof) stands behind the car, and its front wall (`well_front.png`, 40×32) in front, both on the stage. Then snow falls over the whole view (at most 120 white particles that follow the camera), with a few white feathers in it.
- The car: the double tips toward the well, turning, slides between its walls and drops in: it sinks behind the front wall by cropping.
- Left behind: the well, with the snow still falling.
- Sound: a creak, a falling whistle, a soft plop, the hush of snow.
- Words: "You fell down Frau Holle's well." / "Grimm, 1812: when Frau Holle shakes out her bed, it snows."

**Baba Yaga's Hut** · `baba_yaga` · L · stir 0.4, stride 0.9, gulp 0.5, leave 0.6
- Look: a dusk veil. The ground thuds (a short `camera.shake()` per step, at most 3 a second), and a hut on chicken legs (`hut.png`, 56×72 × 6: four strides, a turn, its door open; plank walls, a village roof thatch and yellow legs) strides in, turns its front to the car and opens its door.
- The car: the double slides in through the door. The door shuts, and the hut strides away.
- Left behind: three-toed footprints (`footprint.png`, 12×8; village dark) across the road.
- Sound: thudding steps, a creaking door, a cluck.
- Words: "Baba Yaga's hut swallowed your car." / "\"Little hut, little hut, turn your back to the forest, your front to me.\""
- L: the biggest sheet, and a walk whose steps the shake and the sound must match.

#### Desert (now: the quicksand)

**★ Death Worm** · `death_worm` · M · ripple 0.6, bulge 0.4, erupt 0.6, sink 0.6, hold 0.3
- Look: no veil, in the glare. The ground trembles (`camera.shake()`, as in `sinkhole.gd:63`), ripples run through the sand to the car (desert dark particles), and a mound swells under it (`mound.png`, 48×24 × 2; desert dark and light). A giant eyeless worm (`worm.png`, 40×80 × 5: rising, mouth open, mouth shut, sinking; village roof with desert light bands, its round mouth ringed with white teeth) bursts up in a spray of sand and rears over the car.
- The car: the worm's mouth closes over the double, and the worm dives back into the sand, sinking by cropping.
- Left behind: a crater (`crater.png`, 48×24) where the car stood.
- Sound: a deep rumble that grows, a shriek, a burst, a gulp.
- Words: "The death worm swallowed you whole." / "Gobi Desert: herders fear the olgoi-khorkhoi, a worm whose touch kills."

**Marfa Lights** · `marfa_lights` · S · dusk 0.5, orbs 0.7, converge 0.6, merge 0.5
- Look: a night veil over the desert. Four to six orbs (yellow, white and foam glows; the count from `params.intensity`) rise on the horizon, drift and bob at most once a second (E6), then close in on the car.
- The car: the orbs merge over it into one light, which swells once and fades, and the car is gone with it.
- Left behind: one small orb, drifting away.
- Sound: a soft hum that rises into a chord.
- Words: "You followed the Marfa lights." / "Marfa, Texas: lights that dance on the horizon at night."
- S: glows and particles only, with no sheet and no double.

**Chupacabra** · `chupacabra` · M · rustle 0.5, pounce 0.5, drain 0.9, flee 0.5
- Look: no veil. A tumbleweed (`tumbleweed.png`, 16×16 × 4 rolling frames; desert dark) rolls by, and a spiny grey creature with red eyes (`chupacabra.png`, 32×28 × 4: crouch, leap, drink, run; shadow, asphalt light and red) leaps out of the scrub onto the car.
- The car: it drinks the car dry. The double shrivels, its `scale.y` falling and its `self_modulate` fading to desert dark, into a heap of dust (particles) that blows away. The chupacabra runs off.
- Left behind: an empty fuel can (`fuel_can.png`, 12×12; red).
- Sound: a rustle, a hiss, a long slurp.
- Words: "The chupacabra drank your fuel." / "Puerto Rico, 1995: the goat-sucker. Now it drinks fuel too."

PR 1 gives the natural four their words too, for as long as they're in the pools: "The ground opened under you.", "A tornado carried you away.", "The flood swept you away." and "The quicksand swallowed you.", each with a line of lore.

---

## 4. Work breakdown

There are eight PRs, and each one leaves CI green (E12). With Q2's default, the estimate is about 12 days: PR 2's kit is most of the risk, and then each legend is mostly art and timing, which only the Fold4 can judge (E11).

```
PR 1 words ──▶ PR 2 kit ──▶ PR 3 City ──▶ PR 4 Rural ──▶ PR 5 Meadows ──▶ PR 6 Village ──▶ PR 7 Desert ──▶ PR 8 retire
 fate, lore,    stage,        phantom      ufo            fairy_ring        witch_hex         death_worm        the natural
 palette,       double,       bus                                                                             four, the
 anchors        beats, veil                                                                                   documents
 ~1.5 d         ~2.5 d        ~1.5 d       ~1.5 d         ~1.5 d            ~1 d              ~1.5 d            ~1 d
```

After PR 1, game over names the natural disaster that ended the run, and the collection tells its lore; nothing else looks different. Each list that the legend PRs add to now has a comment line for each area (§5.10). PR 2 adds the kit that legends are built from, and a test legend that uses all of it, but no legend in a pool. PRs 3–7 each put one area's legend in its pool in place of its natural disaster. PR 8 deletes the natural four and brings the documents up to date. With Q2's alternative, each area's further legends share a PR like PRs 3–7, after PR 7 and before PR 8 (§4.5).

### 4.1 Porting from the prototype

Each PR's changes are one commit of `m6/prototype`, ported as M5's were (M5_PLAN.md §4.1):

1. `git fetch origin main '+refs/heads/m6/*:refs/remotes/origin/m6/*'`, then `git switch -c m6/1-words origin/m6/plan`; PRs 2–8 branch from the previous PR's branch (§4.5).
2. `git cherry-pick --no-commit <commit>`, the commit named in the PR's section once the prototype exists. Where a review fix changed the same lines, keep both.
3. Run `tools/ci/import.sh`: it must create no files. Run `godot --headless -s tools/audio/make_audio.gd` in every PR, and `tools/art/make_legends.gd` from PR 2 on: they must make the committed sounds and sheets again, byte for byte. In PR 8, this shows that no legend's sound changed with the natural four's going (S17).
4. Run §6.1, and compare the counts with the PR's "Expect" line.
5. Have a model of another family review it (`AGENTS.md` §7). Then commit, push and open the PR.

The counts below are estimates until the prototype fixes them. Every new `.gd` comes with its `.gd.uid`, and every PNG and WAV with its `.import`.

### PR 1: Words, colours and anchors: fates, lore, the palette, and a place for each area's legends **Δ S5, S8, S9, S12, S15–S17, Q4, Q6, Q7**

Branch `m6/1-words`, from `m6/plan`: this plan's PR, #45, is the stack's root (§4.5).

| Area | Files |
|---|---|
| Disasters | `disasters/disaster_base.gd`: `@export var fate` and `@export_multiline var lore`, after `display_name` (`:22`), which `CollectionScreen.disasters()` reads with the name (`ui/collection_screen.gd:51–54`); the four `.tscn`: their words (§3.3) |
| UI | `ui/game_over.gd`, `.tscn`: `open(stats, area, fate)`, and a `%Fate` label under `%Cause`, at 16 px and wrapping (P13); `ui/menu_card.gd`, `.tscn`: `show_entry(title, details, color, lore := "")` and a `%Lore` label under `%Details`, hidden when it is empty, so the Atlas's calls stay as they are (S12, §5.8); `ui/collection_screen.gd`: `disasters()` gives each one's lore too, and a seen card shows it; `ui/main.gd`: keeps the fate from `disaster_started` (`:224`), clears it in `_clear_run()` (`:173`), and passes it on (`:241`) |
| Art | `assets/palette.gpl`: night, violet, lilac and wisp, after yellow, and "36 colours" in its comment. The generators read colours by name (`tools/art/make_art.gd:54`), so no sheet changes |
| Anchors | A comment line for each area, and the natural four in a block of their own, in `autoload/audio_director.gd`'s `EFFECTS`, `tools/audio/make_audio.gd`'s `_initialize()` and synths, `config/tuning.gd`, and `test_disasters.gd`'s pools (S5, §5.10). `make_audio.gd`: `_save_legend()`, after `_save()` (`:336`), which seeds each legend's sound by its id (S17, §5.9) |
| Tests | `test_game_over.gd`: the fate, and none after a crash; `test_collection_screen.gd`: every test on a schedule of packed test disasters, `:63`'s flood too (S15), a seen card's lore in `%Lore`, and none on a silhouette; `tests/helpers/disaster_fixtures.gd`: `packed()`, after its last function (`:160`), which packs `tests/helpers/test_disaster.gd`, a disaster with only its words; `test_disasters.gd`: each has a fate of at most 40 characters and a lore of at most 80, appended after the last test; `test_title_screen.gd`: every disaster of the pools seen, and the scroll (S15, S16); `test_smoke.gd`: the fates and lore in the glyph check; `tests/integration/test_wrong_turn_disaster.gd`: game over shows the disaster's fate, under the check of the cause (`:74`); `test_retry.gd`: a crash in the next run shows none |

Expect: `check_scripts: loaded 126 scripts`; about 426 tests. The smoke line as on `main`. Negative cases N13, N14, N17, N23, N30 and N35.

**Acceptance:** E9, E7's palette, and the anchors that E12's landing needs (§4.5).

### PR 2: The legend kit: stage, double, beats, veils and glows **Δ S1–S7, S10, S11, S13, S15, S18**

Branch `m6/2-kit`, from `m6/1-words`.

| Area | Files |
|---|---|
| Disasters | `disasters/beats.gd` (§5.2); `disasters/legend.gd`, every legend's base (§5.3); `disasters/disaster_base.gd`: `var stage`, after `var camera` (`:27`), away from PR 1's lines; `disasters/disaster_director.gd`: `stage`, handed on with the car and the camera (`:113–116`), and `disaster_appeared`, on a clock of its own from `play()` (S18) |
| Car | `car/car_controller.gd`: `double()` (§5.4) |
| Audio | `autoload/event_bus.gd`: `disaster_appeared(id, area)`, after `disaster_started` (`:17`); `autoload/audio_director.gd`: a disaster's sound at `disaster_appeared`, not at `disaster_started` (`:73`, `:265–266`; S18, §5.9) |
| Game | `ui/main.gd`: `_director.stage = _world.get_node("%Props")` after `:45`, and `disaster_appeared` relayed to `EventBus`: its connect after `:47`, its function before `:224`; `config/tuning.gd`: `SKY_Z`, `VEIL_Z`, `GLOW_Z`, `VEIL_HALF_SIZE`, `VEIL_DUSK`, `VEIL_NIGHT` and `FLASH_*`, after `PARTICLE_SCALE_MAX` (`:123`), away from PR 1's anchors |
| Art | `tools/art/make_legends.gd`, which runs each `tools/art/legends/<id>.gd` it finds; `tools/art/legend_art.gd`: drawing helpers (§5.7) |
| Tests | `tests/unit/test_beats.gd` (6), `test_legend.gd` (12), `test_legend_art.gd` (3); `tests/helpers/test_legend.gd`, `.tscn`: a legend that uses every part of the kit, which the contract tests run with the pools' disasters; `tests/helpers/disaster_fixtures.gd`: `drawables()`, the stage and `flashes()`, by `polygons()` (`:107`); `test_disasters.gd`: the checks on `drawables()`, the polygon set and the flash test, its new tests before `test_none_redraws_a_polygon` (`:152`), away from PR 1's at the end (S1, S6, S11). Its pools test checks a scene's file name, not its folder (`:31–35`), and its list of every disaster in the pools (`:41`) comes from the dict (S15); `test_car_controller.gd`: the double; `test_disaster_director.gd`: the stage, and `disaster_appeared` once, on the frame the disaster's clock reaches its delay, for the run seeds whose delays are nearest 0.1 and 0.5 s, and never after `clear()` during the delay (`:214`) (S18); `test_wrong_turn_disaster.gd` (`:71`, `:104–108`) and `test_title.gd:154` read the pools, and `test_area_schedule.gd:66–68` leaves the City's pool to `test_disasters.gd`'s pools test (S15); `test_wrong_turn_disaster.gd`: the disaster's sound `params.delay` after `disaster_started`, within a frame, appended (S18); `test_disaster_pools.gd`: each area's wrong turn plays one of its pool (`:65–69`, S15), and every disaster of every pool plays (`:72–80`, S13); `test_audio_director.gd`: the counts from the data (S5), and a disaster's sound at `disaster_appeared`, none at `disaster_started` (S18) |

Expect: about 134 scripts and 455 tests. The smoke line as on `main`: no pool has a legend yet. Negative cases N1–N12, N16, N19–N21, N24–N29 and N36.

**Acceptance:** E2–E6, and E8's derived counts and timing.

### PRs 3–7: one legend each

| PR | Branch, from the previous PR's | Area | Legend (§3.3) | Size |
|---|---|---|---|---|
| 3 | `m6/3-city` | City | `phantom_bus` | M |
| 4 | `m6/4-rural` | Rural | `ufo` | M |
| 5 | `m6/5-meadows` | Meadows | `fairy_ring` | M |
| 6 | `m6/6-village` | Village | `witch_hex` | S |
| 7 | `m6/7-desert` | Desert | `death_worm` | M |

Each adds, for its legend `<id>`:

| Area | Files |
|---|---|
| Legend | `disasters/legends/<id>.gd`, `.tscn`: its parts, beats, veil and words |
| Pool | `areas/<area>.tres`: the legend in place of the natural disaster (Q3). The Village's two leave together |
| Art | `tools/art/legends/<id>.gd`; `assets/legends/<id>/*.png` |
| Audio | `assets/audio/sfx/<id>.wav`; its line in `audio_director.gd`'s `EFFECTS`, and its `_save_legend()` call and synth in `make_audio.gd`, each under its area's comment line (§5.9, §5.10) |
| Config | `config/tuning.gd`: its beats and constants, under its area's comment line |
| Tests | `tests/unit/test_<id>.gd` (6–8): its beats' end states (§3.3), what it leaves behind, its glows' count, and the double; `test_disasters.gd`: its area's line of the pools, under that area's comment (§5.10). PR 6 replaces the Village's `[&"flood", &"tornado"]` with `[&"witch_hex"]`. The other contract tests take it from the pool with no change |

Expect, after each: 3 scripts and about 7 tests more, up to 149 scripts and about 490 tests after PR 7. After PR 3, `smoke.sh` still prints the same line: the autopilot never turns wrong. Each PR runs, on its own legend, the negative cases that §6.2's matrix gives it.

**Acceptance:** E1 for its area; E2–E8 for its legend.

### PR 8: Retire the natural four, and the documents **Δ S14, Q3**

Branch `m6/8-retire`, from `m6/7-desert`.

| Area | Files |
|---|---|
| Disasters | delete `sinkhole`, `tornado`, `flood` and `quicksand`: `.gd`, `.gd.uid`, `.tscn`; `disaster_base.gd:19`, `:21`: examples from the legends |
| Audio | delete their WAVs and their block in `audio_director.gd` and `make_audio.gd`. `make_audio.gd` then makes every other WAV again byte for byte (S17, §4.1) |
| Config | `config/tuning.gd`: delete their block (`:133–165`, under PR 1's comment) |
| Tests | delete `test_sinkhole.gd` (10), `test_tornado.gd` (7), `test_flood.gd` (5) and `test_quicksand.gd` (6); `test_disasters.gd`: the outline test's radii from `Tuning`'s that remain; `test_collection_screen.gd`: a save that recorded the sinkhole loads and shows only the pools' disasters, appended (E10); `test_disaster_director.gd:5–6`: comments |
| Docs | `plan.md` §4.3 (`:158–167`), §5.3 (`:199`) and §8 (`:293`); `IMPLEMENTATION_PLAN.md` `:83`, `:98`, `:430–456` and `:960`, with Ship as M7 (Q1); `AGENTS.md`: §1's state, which still names M3 as next (`AGENTS.md:30`), §3's Web rule, whose font is now Pixel Operator 8 (`ui/theme.tres:3`), §3's rules for legends (§5.3–§5.6, §5.9, §5.10), and M5_PLAN.md §9's notes for §3–§5 and §10, which it doesn't have yet; this plan's status, §4.6 and §6.6 |

Expect: about 141 scripts and 463 tests. The smoke line unchanged.

Steps:
1. After the review fixes, `git diff --stat origin/m6/prototype -- . ':!M6_PLAN.md'` lists only their files (§4.6).
2. E11, on the Web and the Fold4:
   ```bash
   gh workflow run ci.yml -R pompomon/roadgame --ref m6/8-retire -f upload-builds=true
   gh run list -w ci.yml -b m6/8-retire -e workflow_dispatch -L 1    # the run id
   gh run watch <run id> --exit-status
   rm -rf /tmp/roadgame-builds && gh run download <run id> -D /tmp/roadgame-builds
   sed -i 's/"args":\[\]/"args":["--"].concat(new URLSearchParams(location.search).getAll("arg"))/' \
     /tmp/roadgame-builds/web/index.html    # M4_PLAN.md:238–242: ?arg= reaches the game
   python3 -m http.server -d /tmp/roadgame-builds/web 8000
   ```
   - **Web**, in Chrome and Firefox: for each area, http://localhost:8000/?arg=--play&arg=--area=<id>, and a wrong turn at the first junction. Its legend plays as §3.3 says, and its veil covers the whole window, also at the widest and the tallest window. Game over shows its fate. The title's Disasters show its card with its lore, and the last card scrolls into view. The console shows no WebGL errors: an `INVALID_OPERATION` is a polygon drawn twice (S6).
   - **Android**, on the Galaxy Z Fold4, folded and unfolded. The APK: a wrong turn in the City plays the bus, at 60 frames a second, and the text is crisp. The other areas: the Web build in the Fold4's Chrome over `adb reverse tcp:8000 tcp:8000` (M4 Q6). `adb logcat -s godot` shows no errors.
3. After the merge, https://pompomon.github.io/roadgame/ plays the legends.

**Acceptance:** E10–E12, and E1 for every area.

### 4.5 Landing the stack

The PRs land by `AGENTS.md` §5's procedure, with the `m6/` names, as M5's did (M5_PLAN.md §4.5). This plan's PR, #45, lands first: PR 1 targets `m6/plan` until then, as M1's PR 1 opened before its plan merged. Once #45 is squash-merged, PR 1 merges `origin/m6/plan` and then `origin/main`, both adding this plan with the same text, and targets `main`. P7 simulated the landing on a model of the lists that the PRs share, and the prototype simulates it again on its own files with `git merge-tree`. Four rules keep it free of conflicts:

- **No add/add conflicts.** No PR changes a file that an earlier M6 PR adds. A legend that needs a change to the kit gets it on PR 2's branch, merged up. `make_legends.gd` finds the legends' art scripts by itself (§5.7), and a legend's sound and sheets depend only on its id (S17), so no later PR changes them. Files that several PRs change all exist on `main`: `config/tuning.gd`, `test_disasters.gd` and `audio_director.gd` (PRs 1–8), `make_audio.gd` (1, 3–8), `disaster_base.gd` (1, 2, 8), `ui/main.gd`, `disaster_fixtures.gd` and `test_wrong_turn_disaster.gd` (1, 2), `test_disaster_director.gd` (2, 8), and `test_collection_screen.gd` (1, 8).
- **A line of the merge base between** (P7). When PR k+1 is updated after PR k's squash, the merge base holds `main` and PRs 1 to k−1. Two neighbouring PRs' changes need a line from there between them, or they conflict. So PR 1 adds the anchors, a comment line for each area (§5.10). Each legend PR adds its lines under its own area's comment, so the next area's comment lies between its lines and the next PR's. The natural four's block comes before the City's comment, far from the Desert's, the last that a PR adds to before PR 8 deletes the block. PR 1 and PR 2 change seven files with `main`'s lines between their changes:

  | File | PR 1 | PR 2 |
  |---|---|---|
  | `disasters/disaster_base.gd` | after `:22` | after `:27` |
  | `config/tuning.gd` | above `:133`, after `:165` | after `:123` |
  | `autoload/audio_director.gd` | `EFFECTS` (`:28–37`) | `:73`, `:265–266` |
  | `ui/main.gd` | after `:23`; `:173`, after `:225`, `:241` | after `:45`, after `:47`, before `:224` |
  | `tests/helpers/disaster_fixtures.gd` | after `middle()` (`:160–161`) | after `polygons()` (`:107–111`) |
  | `tests/unit/test_disasters.gd` | `:16–22`; after `:203` | `:31–41`, `:58`, `:66–67`, `:152–164`, and new tests before `:152` |
  | `tests/integration/test_wrong_turn_disaster.gd` | under `:74` | `:71`, `:104–108`, and after `:108` |

- **No two PRs in a row for one area.** Two PRs in a row for one area change the same lines: its pool in `areas/<area>.tres` and in `test_disasters.gd`, and the lists under its comment, with no line of the merge base between their changes. The second then conflicts on its update. So, with Q2's alternative, each area's further legends come in one PR, after PR 7 and in the areas' order, each adding its lines after its area's ★. If only the Desert has more, they join PR 7, as their PR would follow it. PR 8 stays last, or each of these PRs would also change its area's row of `plan.md`'s pools, next to the next one's. P7 landed these orders cleanly; a second City PR right after PR 3, two City PRs after PR 7, or a Desert PR right after PR 7 conflict (N30).

- **No counts.** No test counts the pools' disasters or sounds (S5): each count comes from the data, so no PR changes it.

If PR k's branch is already deleted, merge its last state from `git fetch origin pull/<PR k>/head`. A push of merges alone may start no Copilot review: then `gh pr edit <PR k+1> --add-reviewer @copilot`.

### 4.6 Review fixes

The PRs' reviews add their fixes here, each with its tests and negative case, as M5's did (M5_PLAN.md §4.6). Before the plan PR, a model of another family (GPT-6.1 Sol, as a rubber duck) reviewed the plan against `main` (`AGENTS.md` §7). It found R1–R5, and its fixes found R6. Each was checked against the code or a probe. A second review of the fixes, by the same model, found only two citations a few lines off, now corrected. The six and their fixes:

| Finding | Fix | PR | Tests | Negative case |
|---|---|---|---|---|
| R1. Lore appended to `%Details` would break `test_title.gd:155–158`, which reads that label's text | A `%Lore` label of its own, and `show_entry()`'s lore optional, so the Atlas's calls stay as they are (S12, §5.8) | 1 | `test_collection_screen.gd`: the lore in `%Lore`; `test_title.gd:155–158` as on `main` | N35 |
| R2. A comment line added by PR 2 isn't in PR 3's merge base when PR 3 is updated after PR 2's squash, so it separates nothing; PR 1 and PR 2's lines were only "a line apart" | PR 1 adds the anchors; each of PR 1's and PR 2's changes has a line of `main` between them, listed by file (S5, §4.5, P7) | 1, 2 | the landing simulated (P7) | N30 |
| R3. `test_disasters.gd:14` names each area's pool, the natural four and their folder, and no legend PR changed it, so each would fail it | PR 2 checks a scene's file name and lists every disaster from the dict; each legend PR changes its area's line, under its comment (S15, §5.10) | 2–7 | `test_disasters.gd:14` | N33 |
| R4. `make_audio.gd` draws every sound from one generator, so PR 8 would change every legend's sound (S17) | `_save_legend()` seeds each legend's sound by its id (§5.9, P14) | 1, 3–7 | `make_audio.gd` makes every WAV again, byte for byte, in every PR (§4.1) | N32 |
| R5. Each legend PR was to repeat the kit's cases, though most break the kit, which no legend PR changes, and the witch and the worm have no glows | §6.2's matrix: each legend PR breaks only its own parts, and PR 2 alone the kit | 3–7 | — | — |
| R6. PR 1's lore changes the dicts that `test_collection_screen.gd:44–52` and `:70` compare, lines that S15 had PR 2 change too; and `:80` and `:116` count four cards | PR 1 moves every test of that file to packed test disasters, and PR 2 leaves it alone (S15) | 1 | `test_collection_screen.gd` | N30's third variant |

Copilot's review of d5e2beb, this plan's first state on PR #45, found three more. Each was checked against the code, P7's simulation or a probe:

| Finding | Fix | PR | Tests | Negative case |
|---|---|---|---|---|
| [§4.5](https://github.com/pompomon/roadgame/pull/45#discussion_r4534107502): with Q2's alternative, two PRs in a row for one area add lines under the same comment, with no line of the merge base between | Each area's further legends in one PR, after PR 7 in the areas' order, and PR 8 last; the Desert's alone join PR 7 (§4.5) | 3–8 | the landing simulated (P7) | N30's fourth variant |
| [§5.6](https://github.com/pompomon/roadgame/pull/45#discussion_r4534107539): each glow was checked alone, so two that overlap, each with 3 short pulses a second, 10 frames apart, would flash 6 times a second | The flash test adds up the glows' light at each point of the view (S11, §5.6) | 2 | the flash test | N20's second variant |
| [§5.9](https://github.com/pompomon/roadgame/pull/45#discussion_r4534107565): the sound started at `disaster_started`, 0.1–0.5 s before the legend shows, so its cues would miss the beats | S18: the director's `disaster_appeared`, at the delay, starts the sound (P15) | 2 | `test_disaster_director.gd`, at both ends of the delay's range; `test_audio_director.gd`; `test_wrong_turn_disaster.gd` | N36 |

The PRs' reviews:

| PR | Change | Tests | Negative case |
|---|---|---|---|

---

## 5. Design

There is no reference code yet. This section is what `m6/prototype` builds. Where the prototype finds a better way, this section changes with it before PR 1 opens.

### 5.1 Files and IDs

- A legend is `disasters/legends/<id>.gd` and `.tscn`, with a `class_name` such as `PhantomBus`, `Ufo`, `FairyRing`, `WitchHex` or `DeathWorm`. Its `id` is its file name (S15) and its key in the save's `disasters` and in `AudioDirector.EFFECTS`. The rest is named by the id: `assets/legends/<id>/<part>.png`, drawn by `tools/art/legends/<id>.gd`; `assets/audio/sfx/<id>.wav`; `tests/unit/test_<id>.gd`; and its constants in `config/tuning.gd`, starting with `<ID>_BEATS`.
- `lint.sh` lints `disasters/` and `tools/` (`tools/ci/lint.sh:9`), so its RNG rule covers the legends. A legend's chances come from its params alone: a count such as the wisps' from `intensity`, a side from `direction`, and particles from `particle_seed` (`disaster_base.gd:32–40`).
- One signal is new: the director's `disaster_appeared`, for the sound (S18). `main.gd:224` already gets the disaster from `disaster_started`, and keeps its `fate` from there.

### 5.2 Beats (PR 2; S7)

```gdscript
class_name Beats
extends RefCounted
## A legend's beats on one clock (M6_PLAN.md S7): beat i ends at the delay plus the lengths of
## beats 0..i, so the last ends at duration() however many beats there are.

func _init(lengths: Array[float], start: float) -> void
func advance(delta: float) -> void   # the one clock
func index() -> int                  # -1 before start; lengths.size() once done
func progress(i: int) -> float       # beat i's share done: 0 before it, 1 after it
func done() -> bool
static func total(lengths: Array[float]) -> float
```

A legend's script has `static func duration(params: DisasterParams) -> float`, `params.delay + Beats.total(Tuning.<ID>_BEATS)`, as `disaster_base.gd:8–10` asks. `Legend` shows each beat's end once, in order: when a frame skips over beat i, `_pose(i, 1.0)` comes before the next beat's first pose, so nothing is left halfway (N12).

### 5.3 Legend and the stage (PR 2; S2, S6)

```gdscript
@abstract class_name Legend
extends DisasterBase
## A disaster from a legend (M6_PLAN.md §5.3): beats on one clock, a veil, glows, standing parts
## that sort with the props, and a double that takes the car's place.

enum Veil { NONE, DUSK, NIGHT }

@export var veil_kind := Veil.NONE
## Sprites that stand up: play() puts them on the stage, where they sort with the props.
@export var standing: Array[Sprite2D] = []

func play(params: DisasterParams) -> void   # Beats, the stage, apply_params() on every particle
func staged() -> Array[Sprite2D]            # what play() and take_car() put on the stage
func take_car() -> Sprite2D                 # the double, or null without a car (§5.4)
@abstract func _beats() -> Array[float]     # Tuning.<ID>_BEATS
@abstract func _pose(beat: int, t: float) -> void
```

- **Before the delay** nothing shows. Every part is in the scene, hidden by `modulate.a` 0 or `scale` 0, as `flood.gd:33` and `tornado.gd:50` hide theirs. Polygons and particles never leave the legend, and a polygon's `visible`, `color`, `polygon` and `offset` never change (S6). `play()` stands the `standing` sprites on the stage at their places, still hidden.
- **Each physics frame** advances the clock, poses the beats (§5.2), fades the veil (§5.5) and, at the end, checks that the car is hidden, then emits `finished` once and stops. No Tween and no timer, as `disaster_base.gd:7–8` says.
- **The stage** is `DisasterBase.stage`, which the director sets with `car` and `camera` (`disaster_director.gd:113–116`), to World's `%Props` (`main.gd:45`). A part there sorts by its foot with the props and the car, which is a child of `%Props` too (`main.gd:124`). Without a stage, as in the unit tests, the parts stay under the legend, and the checks are the same.
- **Freeing.** `_exit_tree()` frees every staged part that `is_instance_valid()`. P8 shows that this leaves nothing and logs nothing, whether the legend is freed alone (retry, `main.gd:173`), with the World, or queued with it. `test_legend.gd` and `test_retry.gd` count the stage's children and the orphans (E4; N3, N4).
- **Flat parts**, such as the crop circle, the toadstools' ring of light or the crater, stay under the legend on DisasterLayer, under the props and the car.

### 5.4 The double (PR 2; S3)

`CarController.double()` returns a new Sprite2D that draws as `%Body` does now: the body's texture, `centered` false and `offset` (-18, -18) (`car/car.tscn:40–45`), with `region_enabled` and the region `(frame × 36, 0, 36, 28)` for `frame(sim.forward())` (`car_controller.gd:15`, `:36–38`). `Legend.take_car()` stands it at the car's position and sets the car's `modulate.a` to 0 in the same frame, so no frame shows both or neither (N6), and the double faces as the car did (N5). The car stays where it stopped (`disaster_base.gd:24–26`). Then, by pixels `d`:
- **lift:** `offset.y = -18 - d`, so its foot, and its place in the sort, stay put (N7);
- **sink:** the region's height `28 - d` and `offset.y = -18 + d`: it goes into the ground from the bottom up (P3);
- **turn:** the region's x steps through the 16 frames;
- **shrink and fade:** `scale` and `modulate`, as the sinkhole does to the car (`sinkhole.gd:96`).

The witch's hex needs no double: the car hides in the puff, by its own `modulate.a`.

### 5.5 Veils and glows (PR 2; S4, S10, E5, Q5)

- **The veil** is a Polygon2D square, 2 × `VEIL_HALF_SIZE` (4096 px) a side, that `Legend._ready()` makes: white, with a `BLEND_MODE_MUL` material, at `z_index` `VEIL_Z`, not relative. That is above the car, the props and the parts (z 0 and 1), and below the glows (`GLOW_Z`). The widest reference view is 3278 × 1280 px of the world at zoom 0.5, so the square covers it wherever the camera points. Each frame it moves to `camera.get_screen_center_position()`; moving it draws nothing again (P2). It waits at `modulate.a` 0, drawn once (P10). At the delay, `modulate.a` becomes 1, and over the first beat `self_modulate` goes from white to `Tuning.VEIL_DUSK` or `VEIL_NIGHT`, about (170, 130, 190) and (70, 80, 150), darker for Q8's answer and tuned on the Fold4: P6 shows that halfway darkens half as much. It never brightens again while the legend plays (E6; N8). It's in the World, so the HUD and the menus stay as they are (P9). Without a camera, it stays where the legend is.
- **A glow** is a Sprite2D with a `BLEND_MODE_ADD` material at `GLOW_Z`: a soft round light (a radial `GradientTexture2D`, white to clear) tinted with a palette colour by `self_modulate`, or a part of a sheet, such as the UFO's beam. It grows by `scale` and fades by `modulate.a`. Over a veil, a glow lights the dark (P5). Over a light ground it clips to white (S10), so a legend without a veil has no glows: its lights are plain sprites.
- **A sky part**, such as the saucer, sits at `SKY_Z`, over the props, as the tornado's funnel does at z 1 (`disasters/tornado.tscn:10–12`).

### 5.6 No flashing (PR 2; S11, E6)

`Disasters.flashes(disaster)` plays a disaster frame by frame and records the light at the points of a grid fixed in the World, 4 px apart, so that the camera's shake doesn't count. Each glow adds its light at every point it covers: its texture's luminance and alpha there, times its `self_modulate`, and its `modulate` with its parents'. So glows that overlap add up, a glow cut from a sheet, such as the UFO's beam, counts as a round one does, and a glow that moves counts at each point it passes. Only points that a glow covers are kept, so the test's cost follows the glows' area. E6's test fails if:
- at a point, the light rises and falls by more than 10 % of that point's peak more than 3 times in any 60 frames (WCAG 2.3.1: three flashes a second);
- at a point, the red light, from glows whose red is at least 80 % of their colour, rises more than once, or falls more than once, by more than 10 % of its peak;
- a glow covers 57,600 px² or more at the reference zoom, a quarter of 360 × 640;
- the veil's luminance rises while the legend plays;
- or a `Tuning` constant whose name ends in `_HZ` is above 3.

Blinking parts are paced in Hz by such constants: the UFO's rim at most 3 Hz, the wing beats of a later Mothman at most 3 Hz. Moving glows keep to the test too: the bus's headlamps pass a point at most once coming and once going; the UFO's beam opens and closes once; the fairy ring's glows and eyes light one by one and stay lit until the eyes close at the end; the witch's lantern lights once; five wisps, spread evenly and circling at most half a turn a second, pass a point at most 3 times in any second. The test legend has two glows that overlap and pulse together, in short pulses twice a second (N20, N21).

### 5.7 Palette and art (PR 1, PRs 3–7; S9, Q4, Q11, E7)

- **Palette.** PR 1 appends to `assets/palette.gpl`, after yellow: night (40 44 92), violet (112 72 160), lilac (190 150 230) and wisp (150 240 190). The generators read colours by name (`tools/art/make_art.gd:54`), and no existing sheet uses the new ones, so no PNG changes. `test_ui_theme.gd:56` and `test_area_art.gd:88` read the palette, so they take the new colours as they are.
- **Sheets.** `tools/art/make_legends.gd`, run as `godot --headless -s tools/art/make_legends.gd`, finds each `tools/art/legends/<id>.gd` with `DirAccess` and calls it, so no legend PR changes it (§4.5). Each draws its parts with `tools/art/legend_art.gd`'s helpers: pixels, lines, ellipses and fills in the palette's named colours, never blended. It writes `assets/legends/<id>/<part>.png`, the same bytes on every run, as `tools/art/make_art.gd:7–8` does. A sheet that uses chance draws it from a generator of its own, seeded with `hash("<id>")`, so that it depends on nothing else (S17). A sheet is one row of frames of at most 96 × 96 px. A frame stands on its bottom row, its foot at the middle of the bottom row.
- **Tests.** `test_area_art.gd`'s palette and import tests already read every PNG under `res://assets` (`:88`, `:99`). `test_legend_art.gd` adds three, for the test legend and every legend of the pools: each sheet's frame size and count are what the scene's sprites say (N16), and no frame is larger than 96 × 96; every texture of a pool's legend is under its own `assets/legends/<id>/`, or a glow; and `legend_art.gd` draws only the palette's colours, the same bytes twice. The test legend's sheet is drawn by `legend_art.gd` as the test runs, so `assets/` holds only the game's.
- **Final art** may replace a sheet file by file, as M5's may (Q11), if it keeps these tests.

### 5.8 Fate and lore (PR 1; S8, S12, S16, Q6, Q7)

- `DisasterBase` gets `@export var fate := ""` and `@export_multiline var lore := ""`, and `test_disasters.gd` checks that every disaster of the pools has both: a fate of at most 40 characters and a lore of at most 80, with every glyph in the game's font (`test_smoke.gd`, N17).
- `main.gd` keeps `disaster.fate` in `_on_disaster_started()` (`:224`), sets it to "" in `_clear_run()` (`:173`), and passes it to `_game_over.open()` (`:241`). `GameOver.open(stats, area, fate)` shows it in `%Fate`, under `%Cause` at 16 px with autowrap, or hides `%Fate` when it is "" (N13, N14). P13: at 360 × 640 the longest fate takes two lines, and nothing leaves the screen.
- `CollectionScreen.disasters()` (`ui/collection_screen.gd:43`) reads each disaster's `lore` with its name, from the instance it makes and frees (`:51–58`). A legend makes its veil and glows in `_ready()`, which an instance outside the tree never runs. `MenuCard.show_entry(title, details, color, lore := "")` (`ui/menu_card.gd:13`) shows the lore in `%Lore`, a Label under `%Details` in the card's `Text` box (`ui/menu_card.tscn:15–29`), at 16 px with autowrap, and hides it when the lore is "". A seen card passes its lore; a silhouette and the Atlas's cards pass none, so the Atlas's calls stay as they are. `%Details` keeps `seen_text()` alone, which `test_title.gd:155–158` reads (R1, N35).
- The layout test (`test_title_screen.gd:110`) marks every disaster of the pools as seen. A control inside the collection's `Scroll` must fit the screen's width; the scroll itself must fit the screen; and once the scroll has followed the last card (`ensure_control_visible()`), that card must lie inside the scroll (S16, N23).

### 5.9 Sound (PRs 1–7; S17, S18, E8)

`tools/audio/make_audio.gd` makes each legend's one-shot sound from its synth, the same bytes on every run, at `assets/audio/sfx/<id>.wav`, and `AudioDirector.EFFECTS` maps the id to it. From PR 2 on, `AudioDirector` plays a disaster's sound by its id at `disaster_appeared`, on the frame the disaster shows, not at `disaster_started` (`autoload/audio_director.gd:73`, `:265–266`; S18). So a WAV starts with the first beat, whatever the delay, and a legend's synth puts each cue at its beat's start, from `Tuning.<ID>_BEATS`: `make_audio.gd` already reads `Tuning` (`:30–33`). A cue then comes within a frame of its beat. `test_audio_director.gd:271` and `:319` check that every disaster of every pool has its sound, within its kind's peak budget. PR 2 makes them count from the pools and from `EFFECTS`, not from 4 and 20 (S5), and play the sound at `disaster_appeared`.

Every sound draws its noise from one generator, `_rng` (`make_audio.gd:24`), seeded once (`:28`), so each sound depends on every sound made before it (S17). PR 1 adds, after `_save()` (`:336`):

```gdscript
## Saves the legend `id`'s sound from `synth`, its noise drawn from a generator seeded by the id
## alone, so that no other sound changes it (M6_PLAN.md S17).
func _save_legend(id: String, synth: Callable) -> void:
	_rng.seed = hash(id)
	_save("sfx/" + id, synth.call(), Tuning.EFFECT_PEAK, false)
```

A legend PR adds `_save_legend("phantom_bus", _phantom_bus)` under its area's comment in `_initialize()`, and its synth under its area's comment among the synths (§5.10). P14: `hash()` of a string is the same on every run, and a used generator, seeded again, draws what a new one with that seed draws.

### 5.10 Anchors (PR 1; S5, §4.5)

PR 1 adds a comment line for each area to each list that several legend PRs add to, and moves the natural four into a block of their own. It must be PR 1: when PR 3 is updated after PR 2's squash, the merge base holds PR 1 but not PR 2, so PR 2's comments would separate nothing (P7). P11 shows that `gdformat` and `gdlint` keep them:

```gdscript
	# The natural disasters, until M6 PR 8.
	&"sinkhole": preload("res://assets/audio/sfx/sinkhole.wav"),
	...
	# The City's legends.
	# Rural's legends.
	# The Meadows' legends.
	# The Village's legends.
	# The Desert's legends.
}
```

They go into `AudioDirector.EFFECTS`, `make_audio.gd`'s `_initialize()` and its synths, `config/tuning.gd`, and `test_disasters.gd`'s pools, where each area's line has its own comment line above it, such as `# The City's.`. Among functions, PR 1 leaves a blank line between its comments, which `gdformat` keeps as one, and `gdformat` puts two blank lines before a comment that a function follows. So a synth added under its comment adds lines only between that comment and the next (P11). A legend PR adds its lines under its area's comment, so a comment from the merge base always lies between two neighbouring PRs' changes (P7). PR 8 deletes the natural block and keeps the comments, for later legends (§9). With Q2's alternative, an area's further legends add their lines after its ★'s, under the same comment, in a PR that never follows another of that area's (§4.5).

---

## 6. Verification

### 6.1 Local checks

The commands are those of `AGENTS.md` §4. The counts after `main`'s are estimates, which `m6/prototype` replaces with its own (§4.1).

| State | `check_scripts` | GUT tests | `smoke.sh` |
|---|---|---|---|
| `main` (4ade5f2) | 125 | 418: 147,736 asserts in 43.0 s | `autopilot: tile 165, turns 35, area rural` |
| PR 1 | 126 | about 426 | the same |
| PR 2 | about 134 | about 455 | the same |
| PRs 3–7 | 3 more each: 149 after PR 7 | 7 more each: about 490 | the same |
| PR 8 | 141 | about 463 | the same |

The smoke line never changes: the autopilot never turns wrong (M2's `sim/test_autopilot_300_turns.gd`), so no disaster plays in it, and no PR changes the road, the props or a random stream. After every check, and after `make_audio.gd` in every PR and `make_legends.gd` from PR 2 on, `git status --porcelain` prints nothing (§4.1).

### 6.2 Negative cases

Each is a temporary change, made on the prototype and again on its PR's head, and each fails the checks named. "The test legend" is PR 2's `tests/helpers/test_legend.tscn`. PRs 3–7 also make some of PR 2's cases again on their own legend: the matrix after the table says which.

| N# | PR | Ref | Change | Fails |
|---|---|---|---|---|
| N1 | 2 | S1 | The test legend's standing sprite starts at `modulate.a` 1 | `test_disasters.gd:44` `test_each_shows_nothing_until_its_delay_is_over` |
| N2 | 2 | S1 | The same, but only once `play()` has staged it | `:44`, because `drawables()` counts what is staged |
| N3 | 2 | S2 | `play()` leaves the standing sprites under the legend | `test_legend.gd`: they stand on the stage |
| N4 | 2 | S2, E4 | `Legend._exit_tree()` frees nothing | `test_legend.gd`: the stage is empty after a free; `test_retry.gd:141` `test_a_retry_leaves_no_orphan_nodes`; `run_tests.sh`'s leak check |
| N5 | 2 | S3 | `double()` shows frame 0, not the car's | `test_car_controller.gd`: the double looks as the car does |
| N6 | 2 | S3 | `take_car()` leaves the car's `modulate.a` at 1 | `test_legend.gd`: no frame shows both; `test_disasters.gd:76` |
| N7 | 2 | S3 | The lift moves the double's `position`, not its `offset` | `test_legend.gd`: the double's foot stays put |
| N8 | 2 | S4 | The veil fades in by `modulate.a`, at its tint | `test_legend.gd`: halfway through the first beat, half as dark |
| N9 | 2 | S6 | The test legend hides and shows a polygon by `visible` | `test_disasters.gd:152` `test_none_redraws_a_polygon` |
| N10 | 2 | S6 | `Legend` makes the veil at the delay, not in `_ready()` | `:152`: a polygon that wasn't there before `play()` |
| N11 | 2 | S7 | `Beats` starts its clock again at each beat | `test_beats.gd`: five beats end within one DELTA of their total |
| N12 | 2 | S7 | `Legend` poses only the current beat | `test_beats.gd`, `test_legend.gd`: a frame that skips a beat still shows its end |
| N13 | 1 | S8 | `main.gd:241` passes no fate | `test_wrong_turn_disaster.gd`: game over shows the fate |
| N14 | 1 | S8 | `_clear_run()` keeps the fate | `test_retry.gd`: a crash in the next run shows none |
| N15 | 3–7 | E7 | One pixel of the legend's sheet blended with its neighbour | `test_area_art.gd:88` `test_art_is_in_the_palettes_colours` |
| N16 | 2 | E7 | The test legend's sheet a pixel wider than its frames | `test_legend_art.gd` |
| N17 | 1 | S12 | The sinkhole's lore ends with an emoji | `test_smoke.gd`'s glyph test |
| N18 | 3–7 | E8 | `EFFECTS` without the legend's id | `test_audio_director.gd:271` `test_every_disaster_of_every_area_has_its_sound` |
| N19 | 2 | E2 | The test legend's particles skip `apply_params()` | `test_disasters.gd:111` `test_each_seeds_its_particles_from_its_params_and_scales_them` |
| N20 | 2 | S11 | Two variants: the test legend's glows pulse 4 times a second; then, instead, 3 times a second each, the second's pulses 10 frames after the first's. Each glow alone passes, but where they overlap the light pulses 6 times a second. The pulses are short: waves half a period apart would cancel out | the flash test, each time |
| N21 | 2 | S11 | Its red glow pulses twice; then, instead, its glow grows to 260 × 260 px | the flash test, each time |
| N22 | 3 | S15 | `save_service.gd:186` records `&"sinkhole"`, whatever played | `test_wrong_turn_disaster.gd:92`'s save test, which reads the id that played |
| N23 | 1 | S16 | The collection's `Scroll` doesn't scroll vertically | `test_title_screen.gd:110`: the scroll no longer fits the screen |
| N24 | 2 | E2 | The test legend moves the car up 4 px | `test_disasters.gd:76` |
| N25 | 2 | §5.2 | The test legend's `duration()` leaves out the delay | `test_disasters.gd:76` |
| N26 | 2 | E5 | `VEIL_HALF_SIZE` 1024 | `test_legend.gd`: the veil covers the widest view |
| N27 | 2 | E5 | The veil at z 0, relative to the legend | `test_legend.gd`: the veil covers the props, the car and the parts |
| N28 | 2 | E5 | The veil doesn't follow the camera | `test_legend.gd`: the veil covers the view after the camera pans |
| N29 | 2 | S2 | The director doesn't hand the stage on | `test_disaster_director.gd`: the disaster gets the stage |
| N30 | 1 | S5, S15 | Four variants, each with the landing simulated (P7): the anchors added by PR 2, not PR 1; `# Rural's legends.` deleted from `EFFECTS`; PR 2 changes `test_collection_screen.gd:44–52` too; with Q2's alternative, a second City legend in a PR right after PR 3 | `git merge-tree` reports a conflict: on PR 3's update after PR 2's squash; on PR 4's after PR 3's; on PR 2's after PR 1's; on that PR's after PR 3's (§4.5) |
| N31 | 3–7 | E3 | What the legend leaves behind hides at its end | `test_<id>.gd`: what it leaves behind |
| N32 | 3 | S17 | `_save_legend()` doesn't seed the generator; then delete the natural four's `_save()` calls, as PR 8 will, and run `make_audio.gd` | `git status --porcelain` lists `phantom_bus.wav` as changed |
| N33 | 3 | E1 | The bus in Rural's pool, and the tornado in the City's | `test_disasters.gd:14` `test_each_area_has_its_pool_of_disasters` |
| N34 | 6 | E2 | The witch's puff leaves the car's `modulate.a` at 1 | `test_disasters.gd:76` |
| N35 | 1 | S12 | `show_entry()` adds the lore to `%Details`, not `%Lore` | `test_title.gd:155–158`; `test_collection_screen.gd`: the lore in `%Lore` |
| N36 | 2 | S18 | Four variants: (1) the director emits `disaster_appeared` with `disaster_started`; (2) on every frame after the delay; (3) `main.gd` doesn't relay it; (4) `AudioDirector` plays at `disaster_started`, as on `main` | `test_disaster_director.gd`: 1, 2; `test_wrong_turn_disaster.gd`'s sound test: 1, 3, 4; `test_audio_director.gd`: 4 |

The kit's cases (N2–N12, N19, N26–N29, N36) break parts of PR 2's that no legend PR changes, so PR 2 alone makes them. Each legend PR makes N15, N18 and N31 on its legend; PR 3 also N22, N32 and N33, and PR 6 N34. Each also makes again those of PR 2's cases that break its own parts:

| Legend (PR) | PR 2's cases on its own parts | Left out |
|---|---|---|
| `phantom_bus` (3) | N1, N16, N20, N21 (its headlamps' glow grows to 260 × 260 px), N24, N25 | — |
| `ufo` (4) | N1, N16, N20 (its beam, then `UFO_RIM_HZ` at 4), N21 (a glow grows), N24, N25 | — |
| `fairy_ring` (5) | as the bus's, on its *wisp* glows | — |
| `witch_hex` (6) | N1 (a part hidden by `modulate.a`; the pumpkin is hidden by its scale), N16, N20, N21 (on its lantern's glow), N24, N25 | — |
| `death_worm` (7) | N1, N16, N24, N25 | N20, N21: no glows |

### 6.3 Editor warnings

None of the five checks reports GDScript warnings. As in M2–M5 (M5_PLAN.md §6.3), a probe asks the editor's language server for them. Each PR must report only the warnings that `main` does, none of them in its files. Shadowing shows only there (`AGENTS.md` §3): `Legend` keeps its params as `_params`, so `play(params)` shadows nothing, and a part's variable is never named `scale`, `offset` or `position`.

### 6.4 Verified only in CI or on devices

- **CI** builds the Web and Android exports on each PR (`AGENTS.md` §10). Only PR 8's builds are checked by hand (§4, PR 8).
- **The Web** (E11), in Chrome and Firefox, driven by Playwright, headed under Xvfb as #28 did: each legend from `?arg=--play&arg=--area=<id>`, its veil at the widest and the tallest window, game over's fate, the collection's lore and its last card. Chrome's `GPU stall due to ReadPixels` notes and an early `CONTEXT_LOST_WEBGL` come from the environment, as with M2–M5's builds (M5_PLAN.md:273).
- **The Fold4** (E11, §7): 60 frames a second through each legend, folded and unfolded, and the text crisp.
- **No check judges** whether a legend reads in 2–4 s without words, whether it is scary with no gore (Q8), or whether its sound fits. The owner judges them on the Fold4, from PR 3 on. A legend that misses goes back to its art and beats, in its own PR.

### 6.5 Probes

Each ran with Godot 4.7.2: headless, or rendered with the Compatibility renderer (`gl_compatibility` on llvmpipe under Xvfb) where it says so. The draw counts come from each node's `draw` signal.

| # | Probe | Result | Used by |
|---|---|---|---|
| P1 | A Polygon2D enters the tree, is hidden and shown by `visible`, then scaled 0 → 1 and faded 0 → 1 | It draws once on entering, nothing while hidden, once again when shown, and nothing for the scale or the fade | S6, §5.3 |
| P2 | A drawn Polygon2D's transform, `modulate`, `self_modulate`, `material` and `z_index` change; then its `color` | Nothing for the first five; one draw for the colour | S6, §5.5 |
| P3 | A Sprite2D's `region_rect` and `offset` change; rendered, a region cropped from the bottom | One draw, a textured rect. Rendered, the kept rows draw and the cropped ones show the ground | S3, §5.4 |
| P4 | Properties and constants the legends use | `CanvasItemMaterial`'s ADD (1) and MUL (3) blends and particle animation; CPUParticles2D's `texture`, `anim_speed_*`, `anim_offset_*`, `orbit_velocity_*` and `tangential_accel_*`; `clip_children` | §3.3, §5.5 |
| P5 | Rendered: a MUL square tinted (30, 34, 72) over a ground of (200, 200, 200), and an ADD glow of (110, 220, 160) on and off it | The veiled ground (23, 27, 56); the glow on it (133, 247, 216), and off it (255, 255, 255) | S10, §5.5 |
| P6 | Rendered: the MUL square at `modulate.a` 0, 0.5 and 1; at `self_modulate` halfway from white; and an ADD (40, 40, 40) at alpha 0.5 | 0: the ground (200, 200, 200); 0.5 and 1: (23, 27, 56); halfway: (112, 113, 128), half the darkening; the ADD adds (20, 20, 20) | S4, §5.5 |
| P7 | Two stacked branches change neighbouring lines of one file, and then lines one unchanged line apart; the first is squash-merged, and `main` is merged into the second. Then the whole stack of eight, on a model of the lists they share (`EFFECTS`, `make_audio.gd`'s calls and synths, `tuning.gd`, `test_disasters.gd`'s pools and tests), each PR formatted by `gdformat` and landed by `AGENTS.md` §5's updates. Then Q2's alternative, in several orders (§4.5) | Neighbouring lines conflict; lines one apart merge cleanly only if that line is in the merge base. With PR 1's anchors every update is clean, and `main` ends as PR 8's branch. Anchors in PR 2: PR 3's update conflicts in all four files; no `# Rural's legends.` in `EFFECTS`: PR 4's does; PR 2's tests right after PR 1's: PR 2's does. Further legends, one PR per area after PR 7 in the areas' order: clean for all five areas (13 PRs), the City alone, the Meadows alone, and the pairs of the City, the Village and the Desert. The Desert's alone conflict right after PR 7, and land cleanly inside it. A second City PR right after PR 3, or two after PR 7, conflict in all four files | S5, §4.5, §5.10 |
| P8 | A part staged under Props is freed by its disaster's `_exit_tree()` (`is_instance_valid()`, then `free()`): with the disaster freed, with the World freed, and with the World queued | Nothing left under Props in each case, and no errors | S2, §5.3 |
| P9 | Rendered: the MUL square in the World, and a panel on a CanvasLayer over it | The World under the square (23, 27, 56); the panel's (240, 200, 80) as it is | E5, §5.5 |
| P10 | Two Polygon2Ds and a Sprite2D, drawn, are moved to another parent; then their `modulate`, `z_index` and `position` change | Each draws once more on the move, and not for the rest | S2, S6 |
| P11 | `gdformat` and `gdlint` (gdtoolkit 4.5.0) on a script with §5.10's comment lines in a typed Dictionary constant, in a dictionary literal, among statements and among functions; then a function added under one of the comments | Both keep them, and neither reports anything. Among functions, `gdformat` keeps one blank line between two comments, and puts two before a comment that a function follows. The added function adds lines only between its comment and the next | S5, §5.10 |
| P12 | A `const` of `PackedFloat64Array`, and one of `Array[float]` | The first fails to parse, and the check hangs; the second is typed and read-only, so beats are `Array[float]` | §5.2 |
| P13 | Every name, fate and lore of §3.3 against Pixel Operator 8 (`assets/fonts/pixel_operator_8.tres`); the five ★ legends' cards laid out in the collection at 360 × 640, each lore in a Label of its own under the details; game over with the longest fate | Every glyph is in the font. The cards are 891 px high in a 504 px scroll, 2 of them below the screen and none wider than it; with all 15, 2,661 px and 12. The fate takes at most two lines, and nothing leaves the screen | S12, S16, §5.8 |
| P14 | `hash()` of `"a"` and of `"phantom_bus"`, in two runs; a `RandomNumberGenerator` that has drawn, seeded again with the second, against a new one with that seed | `hash("a")` is 177670, as the docs say, and `hash("phantom_bus")` 2079240293, in both runs. Both generators then draw 0.205491 first | S17, §5.9 |
| P15 | 200 pairs of a layer and a director after it, as in the main scene. On a random frame the director adds a disaster under the layer and calls its `play()` with a delay of 0.1–0.5 s; both count the delay from there, each in its own `_physics_process` | A node added during a later sibling's step first steps on the next frame. The director's clock reaches the delay on the frame the disaster's does, in all 200 | S18 |

### 6.6 Measurements (PRs)

To fill in as the PRs land: each PR's counts, GUT time and diff; the frame rate in each legend, on the Web and on the Fold4; and how long each legend takes from the turn.

---

## 7. Owner actions

These need the repository owner. The current state was read with `gh api` on 2026-11-11: ruleset "Test" (26672445) requires `lint`, `test`, `export-web` and both `export-android` checks, and "Copilot" (26740665) has only its review rule. The repository doesn't delete merged branches by itself. M6 changes no settings.

| When | Action | How |
|---|---|---|
| Done, 2026-11-11 | Answer Q1–Q11 | Q8's alternative, with no gore; the defaults for the rest (#45) |
| Now | Merge this plan's PR | Squash-merge it into `main` first: it is the stack's root, and PR 1 targets `m6/plan` until then (§4.5). PR 8's tree check leaves the plan out (§4, PR 8 step 1) |
| As PRs 3–7 come | Judge each legend on the Fold4: it reads in 2–4 s without words, it is scary with no gore (Q8), and its sound fits (§6.4) | The PR's builds: `gh workflow run ci.yml -R pompomon/roadgame --ref <branch> -f upload-builds=true`, then `AGENTS.md` §6's commands. The APK reaches the City's and Rural's legends within a minute (M4 Q6); the other areas' as in §4, PR 8 step 2 |
| Before PR 8 merges | E11 on the Galaxy Z Fold4, folded and unfolded. An agent does the Web checks in Chrome and Firefox (§6.4) | §4, PR 8 step 2 |
| To land M6 | Merge PRs 1–8 in order, each once its base is `main` and it is updated as in §4.5, and resolve their review threads | §4.5 |
| Optional | Delete each PR's branch after it merges, so GitHub retargets the next PR by itself. Delete `m6/prototype` once PR 8 has merged | The **Delete branch** button on the merged PR (§4.5); `git push origin --delete m6/prototype` |

---

## 8. Risks

| Risk | Impact | Mitigation |
|---|---|---|
| The legends' art is made by scripts (Q11) | A legend may not read as itself at 360 × 640: the fairy ring as just a ring, the hex as just a glow | Each legend is a silhouette that reads in frames of at most 96 × 96, and leaves something behind (§3.2). Game over names it (Q6). The owner judges each from PR 3 on (§7). Final sheets replace the placeholders within E7's contracts, with no change to the code |
| A legend's timing | Five beats in 2–4 s may feel rushed, or slow by the tenth retry | The beats' lengths are `Tuning` constants, and E2 bounds the total. The owner judges them on the Fold4 (§7) |
| The tone (Q8), and where the legends come from | A legend is too frightening for the rating the store gives, or offends the tradition it comes from | §3.2's criteria and the legends it leaves out. No gore, and no one hurt on screen. The owner judges each before its PR lands, and the store's content rating is checked before release (§9) |
| The flash test reads the glows' and the veil's light, not the screen's pixels (§5.6) | A sheet whose frames alternate light and dark could flash where no glow does | The placeholder sheets change shape from frame to frame, not light. A final sheet is checked by eye on the Fold4 (E11), and a rendered check could follow (§9) |
| Godot 4.7.2 redraws a `Polygon2D` with WebGL errors (godotengine/godot#124726) | Errors in the browser's console, and a legend that may draw wrong on the Web | S6: no polygon is drawn twice. `test_none_redraws_a_polygon` checks every drawable, the stage's parts and the veil included (N9, N10). What changes is a sprite, a particle or a material (P1–P3) |
| The veil and the glows on the Fold4 | Fewer than 60 frames a second during a legend | The veil is one square, clipped to the screen, and E6 keeps each glow under a quarter of the view. E11 measures the frame rate on the Fold4 (§6.6) |
| The kit is backed by probes, not yet by a prototype (§4.1) | PR 2's kit may lack something a legend needs, and the counts may differ | The test legend uses every part of the kit. A change goes on PR 2's branch and is merged up (§4.5), and §4.6 records it. The prototype replaces every estimate |
| Q2's alternative: up to three legends per area | Three times the art and the timing, and up to five more PRs | An area's further legends share a PR, after PR 7 (§4.5), from §3.3's design, and the kit doesn't change. The ★s land first, and PR 8 last |
| Eight stacked PRs change `config/tuning.gd`, `test_disasters.gd`, `audio_director.gd` and `make_audio.gd` | Conflicts as they land, or a sound that changes as the natural four's go | §4.5's rules: PR 1's comment line per area (S5, P11); a line of the merge base between neighbouring PRs' changes (P7); counts from the data; sounds and sheets seeded by their id (S17). P7 simulated the landing, and the prototype simulates it again on its own files (N30, N32) |
| Copilot reviews no file whose diff is over about 100 KB | A plan or a PR with no review | This plan is kept under 95 KB, and each legend has a PR of its own |
| Saves keep the natural four's ids (Q9) | Nothing the player sees: the collection lists only the pools' disasters, and shows no count | E10's test. A later save version could drop them (§9) |

---

## 9. Notes for later milestones

- **M7 Ship** (Q1). IP's M6 becomes M7, and M5_PLAN.md §9's notes for M6 become M7's: the orientation and vibration settings, the Web's audio, the release checklist and tall windows. With the legends:
  - the vibration setting can pulse on a legend's beats, whose ends `Beats` gives (§5.2);
  - the store's content rating declares the legends' horror: fear, with no blood or gore (Q8). Its screenshots may show them.
- **More legends** (Q2's alternative): §3.3 has ten more designs. They land as §4.5 says: one PR per area, never two in a row for one area. A new legend is checked against §3.2's criteria first, and made as dark as the ★s (Q8). Q8's answer also lets the omens of death in: Black Shuck in Rural, the banshee in the Village, the Grim Reaper in any area.
- **Godot 4.8** fixes the `Polygon2D` redraws (godotengine/godot#124726). Keep S6's rule and its test while the Web build runs 4.7. After an upgrade, run P1–P3 and P10 again (IP §7.1).
- **A rendered flash check** (§8): render each legend frame by frame, as P5 does, and measure the screen's light, for final sheets.
- **Saves:** a later save version could drop the ids that no pool has, with its migration and its test (Q9).
- **Optional:** commit the probes P1–P15, the landing's simulation (P7) and the negative-case script under `tools/agent/`, so that an upgrade can run them again.
