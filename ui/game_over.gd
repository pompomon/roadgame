class_name GameOver
extends Control
## The game-over screen (plan.md §2.1, IMPLEMENTATION_PLAN.md M3.3): why the run ended, what the
## disaster did to the car (docs/M6.md S8), the run's distance, its turns and the area it reached,
## after an arrival its time, and whether it beat the best (ENDGAME_PLAN.md §5.16), and the Retry
## and Title buttons. The main scene opens it once the end of the run has played.
## Over them, NEW LEGEND! for a run that met, found or unlocked a legend that wasn't collected as
## it started, in large letters that stay still, and under the stats the player's next goal, in a
## line (ENDGAME_PLAN.md §5.9). Retry starts the next run in place; Title goes back to the title
## screen (M5.5). Retry takes the focus, so Enter and Space press it too. The run's seed shows in
## small text in debug builds. Like the HUD, its text uses only characters in the game's font.

## Retry was pressed while the screen was open.
signal retry_requested
## Title was pressed while the screen was open.
signal title_requested

## Why the run ended, by CarSim's causes.
const END_MESSAGES: Dictionary[StringName, String] = {
	CarSim.WRONG_TURN: "Wrong turn!",
	CarSim.MISSED_TURN: "You missed the turn!",
	CarSim.HEALTH: "Your car broke down.",
	CarSim.OFFROAD: "You got lost off the road.",
	CarSim.ARRIVAL: "You reached the end of the road!",
}
## For a cause without a message, which is an error.
const FALLBACK_MESSAGE := "Game over"
## The next goal's lines (ENDGAME_PLAN.md §5.9), in next_goal()'s order: the first that holds shows.
## Each is a line of the font's glyphs that fits the screen.
const GOAL_SEA := "Next: reach the sea. Your best: turn %d of %d"
const GOAL_HOME := "Next: drive the Road Home"
const GOAL_LEGENDS := "Next: find the %d legends still missing"
const GOAL_LAST_LEGEND := "Next: find the last legend still missing"
const GOAL_HITCHHIKER := "Next: someone waits on the Road Home"
const GOAL_CLEAN := "Next: reach the sea without leaving the road"
const GOAL_TIME := "Next: beat your best time, %s"
## Under an arrival's time, when it beat the best time at its finish (ENDGAME_PLAN.md §5.16).
const NEW_BEST_TIME := "New best time!"
## The finish of the road to the sea (areas/schedule.tres).
const SEA := &"pier"
## The Road Home's (areas/schedule_home.tres, ENDGAME_PLAN.md §5.12).
const HOME := &"home"

## Whether open() shows the seed. Tests change it.
var show_seed := OS.is_debug_build()

@onready var _new_legend: Label = %NewLegend
@onready var _cause: Label = %Cause
@onready var _fate: Label = %Fate
@onready var _stats: Label = %Stats
@onready var _goal: Label = %Goal
@onready var _retry: Button = %Retry
@onready var _title: Button = %Title
@onready var _seed: Label = %Seed


func _ready() -> void:
	_retry.pressed.connect(_on_retry_pressed)
	_title.pressed.connect(_on_title_pressed)


## Shows the end of the run with `stats`, from GameState.stats(), whose farthest tile was in `area`;
## the `fate` of the disaster that ended it, if one did (DisasterBase.fate), or of the legend that
## its arrival unlocked; NEW LEGEND! if `new_legend`, with its jingle; the player's next `goal`,
## from next_goal(); and whether its arrival was a `new_best` time.
func open(
	stats: Dictionary, area: AreaDef, fate := "", new_legend := false, goal := "", new_best := false
) -> void:
	var cause: StringName = stats["cause"]
	if not END_MESSAGES.has(cause):
		push_error("GameOver: no message for the cause '%s'" % cause)
	_new_legend.visible = new_legend
	_cause.text = END_MESSAGES.get(cause, FALLBACK_MESSAGE)
	_fate.text = fate
	_fate.visible = fate != ""
	_stats.text = stats_text(stats, area, new_best)
	_goal.text = goal
	_goal.visible = goal != ""
	_seed.text = "seed %d" % stats["run_seed"]
	_seed.visible = show_seed
	show()
	_retry.grab_focus()
	if new_legend:
		EventBus.new_legend_shown.emit()


## Hides the screen, which also takes the focus from Retry, so the arrow keys and Enter reach the
## game again.
func close() -> void:
	hide()


## The run's distance in metres, its turns and the name of `area`, a line each, and after an
## arrival its time (ENDGAME_PLAN.md §5.3), and NEW_BEST_TIME under it if it is a `new_best`.
static func stats_text(stats: Dictionary, area: AreaDef, new_best := false) -> String:
	var distance: float = stats["distance"]
	var turns: int = stats["turn_index"]
	var text := (
		"Distance: %s\nTurns: %d\nArea reached: %s"
		% [Hud.distance_text(distance), turns, area.display_name]
	)
	if stats.get("cause", &"") == CarSim.ARRIVAL:
		text += "\nTime: %s" % time_text(stats.get("seconds", 0.0))
		if new_best:
			text += "\n" + NEW_BEST_TIME
	return text


## `seconds` as minutes and seconds, such as "8:05".
static func time_text(seconds: float) -> String:
	var whole := floori(seconds)
	@warning_ignore("integer_division")
	return "%d:%02d" % [whole / 60, whole % 60]


## The player's next goal in `data`, the first that holds (ENDGAME_PLAN.md §5.9): to reach the sea,
## with their best turn of `schedule`'s, the game's road; then to drive the Road Home to its end
## (§5.12); then to find the legends of its pools still missing; then to find the Vanishing
## Hitchhiker, who waits on the Road Home once they are all found (§5.17); then to reach the sea
## without leaving the road; then to beat their best time there. Only the player's progress changes
## it.
static func next_goal(data: SaveData, schedule: AreaSchedule) -> String:
	var sea: Dictionary = data.arrivals.get(String(SEA), SaveData.ARRIVAL_ENTRY)
	if sea["count"] == 0:
		# A save from before the road had an end may hold a best past it.
		var best := mini(data.best["turns"], schedule.finish_turn)
		return GOAL_SEA % [best, schedule.finish_turn]
	if data.arrival_count(HOME) == 0:
		return GOAL_HOME
	var missing := LegendUnlock.locked(schedule, data.seen_disasters()).size()
	if missing > 1:
		return GOAL_LEGENDS % missing
	if missing == 1:
		return GOAL_LAST_LEGEND
	if not data.seen_disasters().has(Hitchhiker.ID):
		return GOAL_HITCHHIKER
	if not sea["clean"]:
		return GOAL_CLEAN
	return GOAL_TIME % time_text(sea["best_seconds"])


func _on_retry_pressed() -> void:
	if visible:
		retry_requested.emit()


func _on_title_pressed() -> void:
	if visible:
		title_requested.emit()
