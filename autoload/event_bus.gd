extends Node
## Game-wide signals (plan.md §7.4, IMPLEMENTATION_PLAN.md M2.7). Senders emit them and listeners
## connect; EventBus has no state. The main scene relays the run's road and car signals here.

# Emitted by other scripts, so the editor would warn that this class never uses them.
@warning_ignore_start("unused_signal")
signal run_started(run_seed: int)
signal turn_completed(turn_index: int)
## The car reached the first tile of a new area.
signal area_changed(area: AreaDef)
signal tiles_generated(tiles: Array[RoadTile])
signal tiles_freed(tiles: Array[RoadTile])
signal health_changed(value: float)
## A wrong exit or a missed turn at `junction`.
signal disaster_triggered(area: AreaDef, junction: RoadTile)
## The disaster `id` started to play in `area`, after the car stopped (M5_PLAN.md L7).
signal disaster_started(id: StringName, area: AreaDef)
## The disaster `id` shows, once the delay in its params is over (M6_PLAN.md S18).
signal disaster_appeared(id: StringName, area: AreaDef)
## `cause` is one of CarSim's causes; `stats` comes from GameState.stats().
signal run_ended(cause: StringName, stats: Dictionary)
signal car_offroad_changed(is_offroad: bool)
signal paused_changed(paused: bool)
@warning_ignore_restore("unused_signal")
