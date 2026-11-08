class_name Hud
extends Control
## The grey-box HUD (IMPLEMENTATION_PLAN.md M2.6): distance, turns, health and the pause button,
## and a message while the game is paused. It reads GameState, listens to EventBus, starts afresh
## with each run, and processes while the game is paused. When the run ends it hides the pause
## button, and the game-over screen shows why it ended (M3.3). Its text uses only characters in
## Godot's default font: the Web build has no system font to fall back on.

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
	_reset()


func _process(_delta: float) -> void:
	_distance.text = distance_text(GameState.distance)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		toggle_pause()
		get_viewport().set_input_as_handled()


## Pauses a running game, or resumes a paused one. Does nothing in other states.
func toggle_pause() -> void:
	if GameState.state == GameState.State.RUNNING:
		GameState.pause()
	elif GameState.state == GameState.State.PAUSED:
		GameState.resume()


## `tiles` of distance, in whole metres.
static func distance_text(tiles: float) -> String:
	return "%d m" % roundi(tiles * Tuning.METRES_PER_TILE)


## What a run starts with. A retry starts the next run without reloading the HUD (M3_PLAN.md J10).
func _reset() -> void:
	_on_turn_completed(0)
	_on_health_changed(Tuning.START_HEALTH)
	_message.text = ""
	_pause.visible = true
	var version: String = ProjectSettings.get_setting("application/config/version", "dev")
	_info.text = "Road Roguelike %s\nseed %d" % [version, GameState.run_seed]


func _on_run_started(_run_seed: int) -> void:
	_reset()


func _on_turn_completed(turn_index: int) -> void:
	_turns.text = "turns %d" % turn_index


func _on_health_changed(value: float) -> void:
	_health.value = value


func _on_paused_changed(paused: bool) -> void:
	_message.text = PAUSED_MESSAGE if paused else ""


func _on_run_ended(_cause: StringName, _stats: Dictionary) -> void:
	_pause.visible = false
