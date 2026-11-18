extends Node
## The run's state and stats (plan.md §7.3, IMPLEMENTATION_PLAN.md M2.7). The main scene starts and
## ends runs. Every state change is checked against TRANSITIONS, and EventBus is told. A run that
## reaches the finish ends in ARRIVED, and then shows its end screen as GAME_OVER, as the others do
## (ENDGAME_PLAN.md §5.3).

enum State { TITLE, RUNNING, PAUSED, DISASTER, CRASH, GAME_OVER, ARRIVED }

## The states each state may change to. Quitting to TITLE is allowed from every other state.
const TRANSITIONS := {
	State.TITLE: [State.RUNNING],
	State.RUNNING: [State.PAUSED, State.DISASTER, State.CRASH, State.ARRIVED, State.TITLE],
	State.PAUSED: [State.RUNNING, State.TITLE],
	State.DISASTER: [State.GAME_OVER, State.TITLE],
	State.CRASH: [State.GAME_OVER, State.TITLE],
	State.ARRIVED: [State.GAME_OVER, State.TITLE],
	State.GAME_OVER: [State.RUNNING, State.TITLE],
}

var state := State.TITLE
var run_seed := 0
## Correct turns in this run.
var turn_index := 0
## The farthest the car got along the correct path, in tiles.
var distance := 0.0
## The run's time, in seconds: from its start, or the tutorial's end, to its end, without the
## pauses. The main scene counts it (ENDGAME_PLAN.md §5.3).
var seconds := 0.0
## Whether the car has stayed on the road since the run's start, or the tutorial's end: a clean
## run (ENDGAME_PLAN.md §5.4).
var clean := true
## The area of the farthest correct-path tile the car reached.
var area_id := &""
## Why the run ended, or empty while it goes on.
var end_cause := &""
## Whether the run is in its tutorial, whose distance and turns count for nothing: the stats start
## when it ends (docs/TUTORIAL.md §5.5).
var in_tutorial := false
## Whether the run drives the whole road, from its first area: not a departure from a later one.
## Only such a run counts an arrival and the overall bests (ENDGAME_PLAN.md Q4, W22).
var whole_road := true
## The finish of the road that the run drives whole, whose farthest turn the save keeps
## (ENDGAME_PLAN.md §5.12): &"" for a run from a later area, and on a road without a finish.
var road := &""

## Where each area the run entered begins, in order: [area id, distance, turns], the path distance
## to the area's first tile and the turns at the junctions before it (docs/M5.md L8).
var _entries: Array[Array] = []
## The areas where the car took damage, and those it crossed: onto the next area's first tile on
## the road, or by arriving in the last (ENDGAME_PLAN.md §5.16). The tutorial's count for neither.
var _damaged: Dictionary[StringName, bool] = {}
var _crossed: Dictionary[StringName, bool] = {}


## Starts a run from TITLE or GAME_OVER: with the tutorial if `tutorial`; as a departure from a
## later area than the road's first if not `p_whole_road`; and on the road whose finish is `p_road`,
## if it drives that road whole. A paused run must be resumed or quit first.
func start_run(p_run_seed: int, tutorial := false, p_whole_road := true, p_road := &"") -> void:
	if state == State.PAUSED:
		push_error("GameState: start_run() in PAUSED is not allowed")
		return
	if not _change_to(State.RUNNING):
		return
	run_seed = p_run_seed
	turn_index = 0
	distance = 0.0
	seconds = 0.0
	clean = true
	area_id = &""
	end_cause = &""
	in_tutorial = tutorial
	whole_road = p_whole_road
	road = p_road
	_entries = []
	_damaged = {}
	_crossed = {}
	EventBus.run_started.emit(run_seed)


## The run's tutorial is over: from now on, the run counts as one that started in the City.
func end_tutorial() -> void:
	in_tutorial = false
	clean = true


## The car reached the area `id`, whose first tile begins `start_distance` tiles along the path,
## after `start_turns` turns: the distance and turns from there on count for it, in
## stats()["areas"]. The car may get there before its turn at the junction behind is judged, or
## before `distance` passes `start_distance`: until then, those still count for the area before.
func enter_area(id: StringName, start_distance: float, start_turns: int) -> void:
	area_id = id
	_entries.append([id, start_distance, start_turns])


## The car took damage in the area `id`, at its rates (ENDGAME_PLAN.md §5.16).
func damage_area(id: StringName) -> void:
	_damaged[id] = true


## The car crossed the area `id` on the road, onto the next area's first tile (§5.16).
func cross_area(id: StringName) -> void:
	_crossed[id] = true


func pause() -> void:
	if _change_to(State.PAUSED):
		get_tree().paused = true
		EventBus.paused_changed.emit(true)


## Resumes a paused run. Only start_run() leaves TITLE or GAME_OVER for RUNNING.
func resume() -> void:
	if state != State.PAUSED:
		push_error("GameState: resume() in %s is not allowed" % State.keys()[state])
		return
	_change_to(State.RUNNING)
	get_tree().paused = false
	EventBus.paused_changed.emit(false)


## Ends the run with one of CarSim's causes: DISASTER for a wrong or missed turn, ARRIVED at the
## finish, otherwise CRASH. An arrival crosses the area that it ends in, the road's last.
func end_run(cause: StringName) -> void:
	var next := State.CRASH
	if cause in [CarSim.WRONG_TURN, CarSim.MISSED_TURN]:
		next = State.DISASTER
	elif cause == CarSim.ARRIVAL:
		next = State.ARRIVED
	if not _change_to(next):
		return
	end_cause = cause
	if cause == CarSim.ARRIVAL:
		cross_area(area_id)
	EventBus.run_ended.emit(cause, stats())


## After the disaster, crash or arrival sequence: the main scene calls it when the
## DisasterDirector's sequence ends (IMPLEMENTATION_PLAN.md M3).
func show_game_over() -> void:
	_change_to(State.GAME_OVER)


## Leaves the run from any state, and unpauses the tree.
func quit_to_title() -> void:
	if state == State.TITLE:
		return
	var was_paused := state == State.PAUSED
	_change_to(State.TITLE)
	if was_paused:
		get_tree().paused = false
		EventBus.paused_changed.emit(false)


## The run's stats. "areas" has, for each area it entered, the distance and the turns the run made
## there, and whether the car took damage there and crossed it (ENDGAME_PLAN.md §5.16):
## {id: {"distance": float, "turns": int, "damaged": bool, "crossed": bool}}.
func stats() -> Dictionary:
	return {
		"run_seed": run_seed,
		"turn_index": turn_index,
		"distance": distance,
		"seconds": seconds,
		"clean": clean,
		"area_id": area_id,
		"cause": end_cause,
		"areas": _area_stats(),
		"whole_road": whole_road,
		"road": road,
	}


func _area_stats() -> Dictionary[StringName, Dictionary]:
	var areas: Dictionary[StringName, Dictionary] = {}
	for i: int in _entries.size():
		var entry: Array = _entries[i]
		var to_distance := distance
		var to_turns := turn_index
		if i + 1 < _entries.size():
			to_distance = minf(to_distance, _entries[i + 1][1])
			to_turns = mini(to_turns, _entries[i + 1][2])
		var made: Dictionary = areas.get(entry[0], {"distance": 0.0, "turns": 0})
		made["distance"] += maxf(to_distance - entry[1], 0.0)
		made["turns"] += maxi(to_turns - entry[2], 0)
		made["damaged"] = _damaged.has(entry[0])
		made["crossed"] = _crossed.has(entry[0])
		areas[entry[0]] = made
	return areas


func _change_to(next: State) -> bool:
	if not TRANSITIONS[state].has(next):
		push_error("GameState: %s to %s is not allowed" % [State.keys()[state], State.keys()[next]])
		return false
	state = next
	return true
