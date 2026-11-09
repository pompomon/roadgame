extends Node
## The run's state and stats (plan.md §7.3, IMPLEMENTATION_PLAN.md M2.7). The main scene starts and
## ends runs. Every state change is checked against TRANSITIONS, and EventBus is told.

enum State { TITLE, RUNNING, PAUSED, DISASTER, CRASH, GAME_OVER }

## The states each state may change to. Quitting to TITLE is allowed from every other state.
const TRANSITIONS := {
	State.TITLE: [State.RUNNING],
	State.RUNNING: [State.PAUSED, State.DISASTER, State.CRASH, State.TITLE],
	State.PAUSED: [State.RUNNING, State.TITLE],
	State.DISASTER: [State.GAME_OVER, State.TITLE],
	State.CRASH: [State.GAME_OVER, State.TITLE],
	State.GAME_OVER: [State.RUNNING, State.TITLE],
}

var state := State.TITLE
var run_seed := 0
## Correct turns in this run.
var turn_index := 0
## The farthest the car got along the correct path, in tiles.
var distance := 0.0
## The area of the farthest correct-path tile the car reached.
var area_id := &""
## Why the run ended, or empty while it goes on.
var end_cause := &""


## Starts a run from TITLE or GAME_OVER. A paused run must be resumed or quit first.
func start_run(p_run_seed: int) -> void:
	if state == State.PAUSED:
		push_error("GameState: start_run() in PAUSED is not allowed")
		return
	if not _change_to(State.RUNNING):
		return
	run_seed = p_run_seed
	turn_index = 0
	distance = 0.0
	area_id = &""
	end_cause = &""
	EventBus.run_started.emit(run_seed)


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


## Ends the run with one of CarSim's causes: DISASTER for a wrong or missed turn, otherwise CRASH.
func end_run(cause: StringName) -> void:
	var next := State.DISASTER if cause in [CarSim.WRONG_TURN, CarSim.MISSED_TURN] else State.CRASH
	if not _change_to(next):
		return
	end_cause = cause
	EventBus.run_ended.emit(cause, stats())


## After the disaster or crash sequence: the main scene calls it when the DisasterDirector's
## sequence ends (IMPLEMENTATION_PLAN.md M3).
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


func stats() -> Dictionary:
	return {
		"run_seed": run_seed,
		"turn_index": turn_index,
		"distance": distance,
		"area_id": area_id,
		"cause": end_cause,
	}


func _change_to(next: State) -> bool:
	if not TRANSITIONS[state].has(next):
		push_error("GameState: %s to %s is not allowed" % [State.keys()[state], State.keys()[next]])
		return false
	state = next
	return true
