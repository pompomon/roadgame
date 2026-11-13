class_name Hud
extends Control
## The grey-box HUD (IMPLEMENTATION_PLAN.md M2.6): distance, turns, health and the pause button,
## and a message while the game is paused. When the car enters an area, the area's name shows for
## AREA_BANNER_SECONDS (M4.3). It reads GameState, listens to EventBus, starts afresh with each
## run, and processes while the game is paused. When the run ends it hides the pause button and
## the area's name, and the game-over screen shows why it ended (M3.3). Its text uses only
## characters in Godot's default font: the Web build has no system font to fall back on.

const PAUSED_MESSAGE := "Paused\nTap II or press Esc to go on"
## The area banner when a run starts with the tutorial: its name and its goal, TUTORIAL_STREAK.
const TUTORIAL_BANNER := "Tutorial\n%d turns in a row"
## The turns label in the tutorial: the turns in a row, of TUTORIAL_STREAK.
const STREAK_TEXT := "turns %d/%d"

## Seconds left to show the area's name.
var _banner_left := 0.0

@onready var _distance: Label = %Distance
@onready var _turns: Label = %Turns
@onready var _health: ProgressBar = %Health
@onready var _pause: Button = %Pause
@onready var _message: Label = %Message
@onready var _info: Label = %Info
@onready var _area_banner: Label = %AreaBanner


func _ready() -> void:
	EventBus.run_started.connect(_on_run_started)
	EventBus.turn_completed.connect(_on_turn_completed)
	EventBus.health_changed.connect(_on_health_changed)
	EventBus.paused_changed.connect(_on_paused_changed)
	EventBus.run_ended.connect(_on_run_ended)
	EventBus.area_changed.connect(_on_area_changed)
	EventBus.streak_changed.connect(_on_streak_changed)
	EventBus.tutorial_completed.connect(_on_tutorial_completed)
	_pause.pressed.connect(toggle_pause)
	_health.max_value = Tuning.START_HEALTH
	_reset()


func _process(_delta: float) -> void:
	_distance.text = distance_text(GameState.distance)


func _physics_process(delta: float) -> void:
	# The HUD processes while the game is paused, but the name waits for the run to go on.
	if _banner_left > 0.0 and GameState.state != GameState.State.PAUSED:
		_banner_left -= delta
		_area_banner.visible = _banner_left > 0.0


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
	_distance.visible = not GameState.in_tutorial
	if GameState.in_tutorial:
		_on_streak_changed(0)
	else:
		_on_turn_completed(0)
	_on_health_changed(Tuning.START_HEALTH)
	_message.text = ""
	_hide_banner()
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
	_hide_banner()


## In the tutorial, the turns label shows the turns in a row, the distance is hidden, and the area
## banner shows the tutorial's goal (TUTORIAL_PLAN.md §5.4).
func _on_streak_changed(streak: int) -> void:
	_turns.text = STREAK_TEXT % [streak, Tuning.TUTORIAL_STREAK]


## The run goes on in the City, whose distance and turns count from here.
func _on_tutorial_completed() -> void:
	_distance.visible = true
	_on_turn_completed(0)


func _on_area_changed(area: AreaDef) -> void:
	var tutorial := TUTORIAL_BANNER % Tuning.TUTORIAL_STREAK
	_area_banner.text = tutorial if GameState.in_tutorial else area.display_name
	_area_banner.visible = true
	_banner_left = Tuning.AREA_BANNER_SECONDS


func _hide_banner() -> void:
	_area_banner.visible = false
	_banner_left = 0.0
