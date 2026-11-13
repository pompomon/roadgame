class_name TitleScreen
extends Control
## The title screen (plan.md §2.6, IMPLEMENTATION_PLAN.md M5.5): Play, and the Atlas, the disaster
## collection and the settings, each a screen of its own with a Back button. The game starts on it,
## and the game-over screen's Title button comes back to it. Esc, and Android's back button through
## main.gd, leave a screen for the title (M5_PLAN.md L13). On the Web, the tap on Play is also the
## first gesture, which lets the game start its sound (M7.3). In debug builds, the Start button
## steps through the schedule's areas, to choose the area that Play starts the run in, for checks
## on a phone (ZONE_SELECT_PLAN.md Z1): a button, as a dropdown's popup would let Android's back
## button quit the game (Z7).

## Play was pressed.
signal play_requested

## The Start button's text, with the area's name.
const START_TEXT := "Start in: %s"

## The game's schedule: the Atlas and the collection show its areas and disasters, and the Start
## button steps through its areas.
var schedule: AreaSchedule
## Whether the title shows the Start button: in debug builds only, like the game-over screen's seed
## (M3_PLAN.md J19; ZONE_SELECT_PLAN.md Z4). Tests change it.
var area_choice := OS.is_debug_build()
## The area that Play starts the run in, with area_choice. main.gd sets it first; open() makes it
## the schedule's first area if it isn't one of the schedule's.
var start_area: AreaDef

## The button that opens each screen, which takes the focus back when the screen closes.
var _buttons: Dictionary[MenuScreen, Button] = {}

@onready var _main_page: Control = %MainPage
@onready var _best: Label = %Best
@onready var _play: Button = %Play
@onready var _start: Button = %StartArea
@onready var _atlas: AtlasScreen = %Atlas
@onready var _collection: CollectionScreen = %Collection
@onready var _settings: SettingsScreen = %Settings
@onready var _atlas_button: Button = %AtlasButton
@onready var _disasters_button: Button = %DisastersButton
@onready var _settings_button: Button = %SettingsButton


func _ready() -> void:
	_play.pressed.connect(_on_play_pressed)
	_start.pressed.connect(_on_start_pressed)
	_add_screen(_atlas, _atlas_button, _open_atlas)
	_add_screen(_collection, _disasters_button, _open_collection)
	_add_screen(_settings, _settings_button, _open_settings)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel") and go_back():
		get_viewport().set_input_as_handled()


## Shows the title, with the bests from the save, and the Start button with area_choice.
func open() -> void:
	_close_screen()
	_best.text = AtlasScreen.best_text(SaveService.data().best)
	var areas := schedule.areas()
	if not areas.has(start_area):
		start_area = areas[0]
	_start.text = START_TEXT % start_area.display_name
	_start.visible = area_choice
	_main_page.show()
	show()
	_play.grab_focus()


func close() -> void:
	_close_screen()
	hide()


## Leaves the open screen for the title. Returns false if none was open.
func go_back() -> bool:
	var screen := _close_screen()
	if screen == null:
		return false
	_main_page.show()
	_buttons[screen].grab_focus()
	return true


## The screen that is open, or null.
func open_screen() -> MenuScreen:
	for screen: MenuScreen in _buttons:
		if screen.visible:
			return screen
	return null


func _add_screen(screen: MenuScreen, button: Button, open_it: Callable) -> void:
	_buttons[screen] = button
	button.pressed.connect(open_it)
	screen.back_requested.connect(go_back)


## Closes the open screen, and returns it, or null if none was open.
func _close_screen() -> MenuScreen:
	var screen := open_screen()
	if screen != null:
		screen.close()
	return screen


func _open_atlas() -> void:
	_main_page.hide()
	_atlas.open(SaveService.data(), schedule)


func _open_collection() -> void:
	_main_page.hide()
	_collection.open(SaveService.data(), schedule)


func _open_settings() -> void:
	_main_page.hide()
	_settings.open()


func _on_play_pressed() -> void:
	if visible and open_screen() == null:
		play_requested.emit()


## The next area of the schedule, and after the last, the first.
func _on_start_pressed() -> void:
	var areas := schedule.areas()
	start_area = areas[(areas.find(start_area) + 1) % areas.size()]
	_start.text = START_TEXT % start_area.display_name
