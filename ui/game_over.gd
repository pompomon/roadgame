class_name GameOver
extends Control
## The game-over screen (plan.md §2.1, IMPLEMENTATION_PLAN.md M3.3): why the run ended, what the
## disaster did to the car (docs/M6.md S8), the run's distance, its turns and the area it reached,
## and the Retry and Title buttons. The main scene opens it once the end of the run has played.
## Retry starts the next run in place; Title goes back to the title screen (M5.5). Retry takes the
## focus, so Enter and Space press it too. The run's seed shows in small text in debug builds. Like
## the HUD, its text uses only characters in the game's font.

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

## Whether open() shows the seed. Tests change it.
var show_seed := OS.is_debug_build()

@onready var _cause: Label = %Cause
@onready var _fate: Label = %Fate
@onready var _stats: Label = %Stats
@onready var _retry: Button = %Retry
@onready var _title: Button = %Title
@onready var _seed: Label = %Seed


func _ready() -> void:
	_retry.pressed.connect(_on_retry_pressed)
	_title.pressed.connect(_on_title_pressed)


## Shows the end of the run with `stats`, from GameState.stats(), whose farthest tile was in `area`,
## and the `fate` of the disaster that ended it, if one did (DisasterBase.fate).
func open(stats: Dictionary, area: AreaDef, fate := "") -> void:
	var cause: StringName = stats["cause"]
	if not END_MESSAGES.has(cause):
		push_error("GameOver: no message for the cause '%s'" % cause)
	_cause.text = END_MESSAGES.get(cause, FALLBACK_MESSAGE)
	_fate.text = fate
	_fate.visible = fate != ""
	_stats.text = stats_text(stats, area)
	_seed.text = "seed %d" % stats["run_seed"]
	_seed.visible = show_seed
	show()
	_retry.grab_focus()


## Hides the screen, which also takes the focus from Retry, so the arrow keys and Enter reach the
## game again.
func close() -> void:
	hide()


## The run's distance in metres, its turns and the name of `area`, a line each, and after an
## arrival its time (ENDGAME_PLAN.md §5.3).
static func stats_text(stats: Dictionary, area: AreaDef) -> String:
	var distance: float = stats["distance"]
	var turns: int = stats["turn_index"]
	var text := (
		"Distance: %s\nTurns: %d\nArea reached: %s"
		% [Hud.distance_text(distance), turns, area.display_name]
	)
	if stats.get("cause", &"") == CarSim.ARRIVAL:
		text += "\nTime: %s" % time_text(stats.get("seconds", 0.0))
	return text


## `seconds` as minutes and seconds, such as "8:05".
static func time_text(seconds: float) -> String:
	var whole := floori(seconds)
	@warning_ignore("integer_division")
	return "%d:%02d" % [whole / 60, whole % 60]


func _on_retry_pressed() -> void:
	if visible:
		retry_requested.emit()


func _on_title_pressed() -> void:
	if visible:
		title_requested.emit()
