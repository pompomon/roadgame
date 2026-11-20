class_name LegendUnlock
extends RefCounted
## The legend that an arrival unlocks (docs/ENDGAME.md §5.5): a run that drove the whole road to its
## finish unlocks a legend that the player hasn't collected, neither seen nor unlocked, each as
## likely as the others, from the pools of all the road's areas. Its stream is the run's own, apart
## from the road's, the picks' and the disaster's, so that the same seed and the same collection
## unlock the same legend. With every legend of the pools collected, it unlocks none: the
## Vanishing Hitchhiker, in no pool, is found only on the Road Home (docs/ENDGAME.md §5.17), so the
## words with none left name the areas' legends, not all.

## The fate line of the arrival screen, for the unlocked legend's name, and with none left.
const UNLOCKED := "A new legend for your book: %s"
const BOOK_FULL := "Every area's legends are in your book."


## The arrival stream of the run with `run_seed`.
static func stream(run_seed: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:unlock" % run_seed)
	return rng


## The ids of the legends in the pools of `schedule`'s areas that aren't in `collected`, each once,
## in the order of the areas, as the Book of Legends has them.
static func locked(schedule: AreaSchedule, collected: Array[StringName]) -> Array[StringName]:
	var ids: Array[StringName] = []
	for area: AreaDef in schedule.areas():
		for scene: PackedScene in area.disasters:
			var id := DisasterPicks.id_of(scene)
			if id == &"":
				push_error("LegendUnlock: %s sets no id" % scene.resource_path)
			elif not ids.has(id) and not collected.has(id):
				ids.append(id)
	return ids


## The id of the legend that the arrival of the run with `run_seed` unlocks, of those in the pools
## of `schedule` that aren't in `collected`; &"" if there are none.
static func pick(schedule: AreaSchedule, collected: Array[StringName], run_seed: int) -> StringName:
	var pool := locked(schedule, collected)
	if pool.is_empty():
		return &""
	return pool[stream(run_seed).randi_range(0, pool.size() - 1)]


## The arrival screen's line for the legend `id` of `schedule`'s pools, or for none if it's &"".
static func text(schedule: AreaSchedule, id: StringName) -> String:
	if id == &"":
		return BOOK_FULL
	var area := pool_area(schedule, id)
	if area == null:
		push_error("LegendUnlock: no legend %s in the schedule's pools" % id)
		return BOOK_FULL
	for scene: PackedScene in area.disasters:
		if DisasterPicks.id_of(scene) == id:
			var node := scene.instantiate()
			var title: String = node.display_name if node is DisasterBase else String(id)
			node.free()
			return UNLOCKED % title
	return BOOK_FULL


## The first of `schedule`'s areas whose pool has the legend `id`, or null.
static func pool_area(schedule: AreaSchedule, id: StringName) -> AreaDef:
	for area: AreaDef in schedule.areas():
		for scene: PackedScene in area.disasters:
			if DisasterPicks.id_of(scene) == id:
				return area
	return null
