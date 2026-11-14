# Docs

Summaries of the finished plans. Each keeps its plan's section numbers and every ID that code, tests or docs cite, such as `docs/M2.md H16`. Its header names the commit that has the full plan, for `git show <sha>:<NAME>_PLAN.md`. [`IMPLEMENTATION_PLAN.md`](../IMPLEMENTATION_PLAN.md) (IP) has the milestones and M7, Ship, which is next; [`plan.md`](../plan.md) has the game's design.

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

## For agents

[`AGENTS.md`](../AGENTS.md) is the short guide. Its how-tos are here:
- [agents/planning.md](agents/planning.md): planning a milestone, negative cases, and summarising a plan once it lands.
- [agents/stacks.md](agents/stacks.md): stacked PRs and how they land, GitHub's native stacks included.
- [agents/checks.md](agents/checks.md): the local checks, seeing the game, where to check what, and the builds.
- [agents/review.md](agents/review.md): the internal review, Copilot code review, watching a PR, and CI.

The rules in [`.github/instructions/`](../.github/instructions/) apply to the files that they name: the legends, the light, the tests and CI.
