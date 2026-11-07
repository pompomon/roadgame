class_name Hud
extends Control
## The grey-box HUD (IMPLEMENTATION_PLAN.md M2.6): distance, turns, health and the pause button,
## and a message while the game is paused or after the run ends. It reads GameState, listens to
## EventBus, and processes while the game is paused. Its text uses only characters in Godot's
## default font: the Web build has no system font to fall back on.

## A tap, or Enter, after the run ended.
signal retry_requested

## The message at the end of a run, by cause.
const END_MESSAGES: Dictionary[StringName, String] = {
	CarSim.WRONG_TURN: "Wrong turn!",
	CarSim.MISSED_TURN: "You missed the turn!",
	CarSim.HEALTH: "Your car broke down.",
	CarSim.OFFROAD: "You got lost off the road.",
}
const RETRY_MESSAGE := "Tap or press Enter to drive again"
const PAUSED_MESSAGE := "Paused\nTap II or press Esc to go on"

@onready var _distance: Label = %Distance
@onready var _turns: Label = %Turns
@onready var _health: ProgressBar = %Health
@onready var _pause: Button = %Pause
@onready var _message: Label = %Message
@onready var _info: Label = %Info


func _ready() -> void:
	EventBus.run_started.connect(_on_run_started)
	EventBus.turn_completed.connect(_on_turn_completed)
	EventBus.health_changed.connect(_on_health_changed)
	EventBus.paused_changed.connect(_on_paused_changed)
	EventBus.run_ended.connect(_on_run_ended)
	_pause.pressed.connect(toggle_pause)
	_health.max_value = Tuning.START_HEALTH
	_health.value = Tuning.START_HEALTH
	_show_info()


func _process(_delta: float) -> void:
	_distance.text = "%d m" % roundi(GameState.distance * Tuning.METRES_PER_TILE)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		toggle_pause()
		get_viewport().set_input_as_handled()
	elif GameState.state == GameState.State.GAME_OVER and _is_retry(event):
		retry_requested.emit()
		get_viewport().set_input_as_handled()


## Pauses a running game, or resumes a paused one. Does nothing in other states.
func toggle_pause() -> void:
	if GameState.state == GameState.State.RUNNING:
		GameState.pause()
	elif GameState.state == GameState.State.PAUSED:
		GameState.resume()


func _show_info() -> void:
	var version: String = ProjectSettings.get_setting("application/config/version", "dev")
	_info.text = "Road Roguelike %s\nseed %d" % [version, GameState.run_seed]


func _on_run_started(_run_seed: int) -> void:
	_show_info()


func _on_turn_completed(turn_index: int) -> void:
	_turns.text = "turns %d" % turn_index


func _on_health_changed(value: float) -> void:
	_health.value = value


func _on_paused_changed(paused: bool) -> void:
	_message.text = PAUSED_MESSAGE if paused else ""


func _on_run_ended(cause: StringName, _stats: Dictionary) -> void:
	_message.text = "%s\n%s" % [END_MESSAGES[cause], RETRY_MESSAGE]
	_pause.visible = false


static func _is_retry(event: InputEvent) -> bool:
	var touch := event as InputEventScreenTouch
	return (touch != null and touch.pressed) or event.is_action_pressed(&"ui_accept")
