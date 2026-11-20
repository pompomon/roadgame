# Docs

Summaries of the finished plans. Each keeps its plan's section numbers and every ID that code, tests or docs cite, such as `docs/M2.md H16`. Its header names the commit that has the full plan, for `git show <sha>:<NAME>_PLAN.md`. The plans also cite commits on their prototype branches, such as `m3/prototype`. To keep those commits, the branches are now tags, such as `archive/m3/prototype`; only `tut/prototype` and `hb/prototype` are still branches. [`IMPLEMENTATION_PLAN.md`](../IMPLEMENTATION_PLAN.md) (IP) has the milestones and M7, Ship, which is next; [`plan.md`](../plan.md) has the game's design.

| Summary | What it built | PRs |
|---|---|---|
| [M0.md](M0.md) | Bootstrap and CI: the agent's environment, the skeleton, GUT, the lint, the exports, Pages, the release pipeline and Actions storage | #1–#18 |
| [M1.md](M1.md) | The road generator, the road buffer, the areas and the grey box | #19–#23 |
| [M2.md](M2.md) | Driving: the junction trigger, `CarSim` and the autopilot, `GameState` and `EventBus`, the HUD | #24–#28 |
| [M3.md](M3.md) | Failure: the disaster director, the sinkhole, game over and retry | #30–#33 |
| [M4.md](M4.md) | The areas: the schedule's check, the ground's transitions, the tunnel, the bridge and the areas' disasters | #34–#37 |
| [M5.md](M5.md) | Content: the save, the title and its menus, music and sounds, the areas' art, the props, the car and the font | #38–#44 |
| [M6.md](M6.md) | Legends: a disaster from a legend for each area, with its fate and lore | #45–#53 |
| [ROADGEN.md](ROADGEN.md) | RG: junctions with straight on and one turn, side roads, decoys and longer dead ends | #54–#57 |
| [ZONE_SELECT.md](ZONE_SELECT.md) | ZS: the start area on the title of debug builds | #60, #61 |
| [TUTORIAL.md](TUTORIAL.md) | TUT: the tutorial before the City | #65–#68 |
| [DAYNIGHT.md](DAYNIGHT.md) | DN: each zone's day and night, the shadows and the lamps | #64, #70–#76 |
| [VISUALS.md](VISUALS.md) | VIS: the car's wheels turn as it drives, and buildings line the City's streets, fading over the car | #85, #93, #94 |
| [POOLS.md](POOLS.md) | PL: three legends in each area's pool, one picked for each run as the car reaches the area, those seen half as likely | #80–#83, #86–#91, #96, #98 |
| [ENDGAME.md](ENDGAME.md) | EG: the road ends at a pier after 280 turns, and an arrival unlocks a legend; the Book of Legends, the Road Home, Departures, Keep Driving, the route strip, pit stops, postcards and the Vanishing Hitchhiker | #84, #101–#113 |

## For agents

[`AGENTS.md`](../AGENTS.md) is the short guide. Its how-tos are here:
- [agents/planning.md](agents/planning.md): planning a milestone, negative cases, and summarising a plan once it lands and learning from it.
- [agents/stacks.md](agents/stacks.md): stacked PRs and how they land, GitHub's native stacks included.
- [agents/checks.md](agents/checks.md): the local checks, seeing the game, where to check what, and the builds.
- [agents/review.md](agents/review.md): the internal review, Copilot code review, watching a PR, and CI.

The rules in [`.github/instructions/`](../.github/instructions/) apply to the files that they name: the legends, the light, the screens, the tests and CI.
