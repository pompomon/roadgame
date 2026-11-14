---
applyTo: "disasters/**,tools/art/**,tools/audio/**,autoload/audio_director.gd,config/tuning.gd,tests/unit/test_disasters.gd"
---

# Legends

A disaster from a legend extends `Legend` (`disasters/legend.gd`). The § and IDs below are those of docs/M6.md.

- **Choosing one** from §3.3's list. It reads at 360×640 in 2–4 s without words, belongs in its area, and ends with the car gone and something left behind. It comes from folklore or a public-domain story, not a recent work with owners such as Slender Man, Siren Head or the Backrooms, and isn't sacred to a living tradition. It takes the car another way than its area's other two, and needs only sprite sheets with frames of at most 96×96.
- It poses its beats, `Tuning.<ID>_BEATS`, on its own clock in `_physics_process`: no Tween and no timer (§5.2, §5.3). The beats are a `const` `Array[float]`: in 4.7.2 a `const` `PackedFloat64Array` fails to parse, and `check_scripts.sh` hangs.
- Before its delay nothing shows. Each part is in its scene, hidden by `modulate.a` 0 or `scale` 0. Polygons and particles stay under the legend, and a `Polygon2D`'s `visible`, `color`, `polygon` and `offset` never change (S6). A sprite that stands up goes in `standing`: `play()` puts it on the stage, `%Props`, to sort with the props and the car, and the legend frees it when it leaves the tree (§5.3).
- To take the car, it hides it in the frame that the double from `take_car()` shows (§5.4).
- Glows add light, so only a legend with a veil has them: over a light ground they clip to white (S10, §5.5). A new veil is a `ViewVeil`, drawn at `VEIL_Z` (light.instructions.md).
- Nothing flashes (WCAG 2.3.1). `test_disasters.gd` plays each legend and fails on a light that rises and falls more than 3 times a second, a red one more than once, a glow that covers a quarter of the screen, a veil that brightens, or a `Tuning` `*_HZ` above 3 (§5.6, E6).
- Its sound is made by `make_audio.gd`'s `_save_legend(id, synth)`, seeded by its id alone so that no other sound changes, with each cue at its beat's start (§5.9).
- Lists that each legend adds to (`AudioDirector.EFFECTS`, `make_audio.gd`, `config/tuning.gd` and `test_disasters.gd`'s pools) have a comment for each area. Add a legend's lines under its area's, so that stacked PRs' lines never touch (§5.10).
- Scary, but no gore: the car is taken, shrunk or changed, never smashed, and no one is hurt on screen (Q8).
- The legends and the set pieces cast no shadows.
- The art and the sounds in `assets/` are made by the scripts in `tools/art/` and `tools/audio/`: run `godot --headless -s <script>`, then `tools/ci/import.sh`, and commit what they write.
