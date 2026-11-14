---
applyTo: "world/**,disasters/**,setpieces/**,areas/**,tools/art/**,config/tuning.gd,ui/main.gd,ui/main.tscn"
---

# Light, shadows and lamps

The § and IDs below are those of docs/DAYNIGHT.md, unless marked.

- **Light** (§5.5). Draw the world as by day. `Daylight`, a `ViewVeil` under Main, multiplies everything below `VEIL_Z` by the light of the zone's hour. At `VEIL_Z` draw only MUL veils, and above it only ADD glows; the UI is on layers of its own. Don't tint the world with a `CanvasModulate`, a `Light2D` or World's `modulate`: they would dim the glows and darken the legends' veils twice. A new veil is a `ViewVeil`. The light is visual only: no gameplay or audio code reads `DayCycle` (`test_daylight_run.gd`).
- **Shadows** (§5.11). A prop says how it casts in its `PropDef`, `shadow` and `shadow_rise`, which `make_props.gd` sets with its art. Each cast is a black sprite in `Shadows`, a `CanvasGroup` that draws them into one buffer, then the buffer once at the clock's shadow alpha, so that overlaps don't darken twice (P8). A cast is a sprite in the group, never a group in a group, which draws wrong (P8b). Only the sprites' transforms, frames and `self_modulate`, and the two materials' parameters, change, so nothing is redrawn on the Web (C9). The legends and the set pieces cast none.
- **Lamps** (§5.12). A prop's lights and pools of light, `lights` and `light_pools` in its `PropDef`, come from `make_props.gd`: the windows that it paints the palette's yellow, and the lamps' heads. `Lamps` is one `CanvasGroup` above the veil that adds what it holds once, so overlapping glows light no more than one (P10). It holds a black silhouette of each standing prop with the prop's glows, in the order that Props draws the props, so a prop hides the glows behind it. Tint it through `self_modulate`: its `modulate` would light the glows twice (N81). A glow adds to no channel more than the light takes away from white, so it never clips (`Lamps.strength()`, docs/M6.md S10).
