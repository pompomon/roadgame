class_name DisasterPicks
extends RefCounted
## Each area's disaster for a run (POOLS_PLAN.md §5.1): drawn from the area's pool the first time
## that it's asked for, as the car reaches the area (Q4), and kept for the run. Each area draws on
## its own stream, from the run's seed and the area's id, so the pick doesn't depend on when it's
## made or on the areas before: --area, the title's Start choice and the tutorial leave it as it is
## (V1). A disaster that the player has seen, which the collection shows, weighs
## Tuning.SEEN_DISASTER_WEIGHT against 1 for one not seen yet (Q2). So the same seed and the same
## collection give the same disasters (plan.md §3.5).

var _run_seed: int
## The ids of the disasters seen, as keys.
var _seen: Dictionary[StringName, bool] = {}
## The pick of each area asked for so far, in the order they were asked for. Kept by area, as a
## schedule's copies share their areas (AreaSchedule.starting_at()), and tests give one id to areas
## with other pools.
var _picks: Dictionary[AreaDef, PackedScene] = {}


func _init(run_seed := 0, seen: Array[StringName] = []) -> void:
	_run_seed = run_seed
	for id: StringName in seen:
		_seen[id] = true


## The disaster of `area` for this run, or null if its pool is empty.
func pick(area: AreaDef) -> PackedScene:
	if not _picks.has(area):
		var pool := area.disasters
		_picks[area] = draw(pool, weights(pool), stream(_run_seed, area.id))
	return _picks[area]


## The ids of the areas picked for so far, in order.
func picked() -> Array[StringName]:
	var ids: Array[StringName] = []
	for area: AreaDef in _picks:
		ids.append(area.id)
	return ids


## The weight of each scene of `pool`: 1 for a disaster not seen yet, and
## Tuning.SEEN_DISASTER_WEIGHT for one seen. An empty slot is an error, and weighs 0, so it's never
## picked.
func weights(pool: Array[PackedScene]) -> PackedFloat32Array:
	var result := PackedFloat32Array()
	for scene: PackedScene in pool:
		if scene == null:
			push_error("DisasterPicks: a pool has an empty slot, which is never picked")
			result.append(0.0)
		else:
			result.append(Tuning.SEEN_DISASTER_WEIGHT if _seen.has(id_of(scene)) else 1.0)
	return result


## The stream of the pick in the area `area_id` of the run with `run_seed`, apart from the run's
## other streams (plan.md §3.5).
static func stream(run_seed: int, area_id: StringName) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:pick:%s" % [run_seed, area_id])
	return rng


## The scene of `pool` that `rng` draws, each as likely as its weight in `p_weights`; null if the
## pool is empty.
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


## The id that `scene`'s root sets, read from the scene without instancing it (P6); &"" if it sets
## none, or if there's no scene.
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
