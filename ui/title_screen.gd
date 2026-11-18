class_name TitleScreen
extends Control
## The title screen (plan.md §2.6, IMPLEMENTATION_PLAN.md M5.5): Play, and the Atlas, the Book of
## Legends (ENDGAME_PLAN.md §5.10) and the settings, each a screen of its own with a Back button.
## The game starts on it, and the game-over screen's Title button comes back to it. Esc, and
## Android's back button through main.gd, leave a screen for the title (docs/M5.md L13), or first a
## page that it shows, such as a legend's in the Book. On the Web, the tap on Play is also the first
## gesture, which lets the game start its sound (M7.3). The Road button steps through the roads that
## Play can drive: the game's, to the sea, and after its first arrival the Road Home and Keep
## Driving's endless road too (ENDGAME_PLAN.md §5.12, §5.13). The Start button steps through the
## areas of the road that Play can start the run in: its first, and each later area discovered, but
## a home stretch, Departures (§5.11), or in debug builds every area, for checks on a phone
## (docs/ZONE_SELECT.md Z1). Each shows only when there is a choice, and is a button, as a
## dropdown's popup would let Android's back button quit the game (Z7).

## Play was pressed.
signal play_requested

## The Start button's text, with the area's name.
const START_TEXT := "Start in: %s"
## The Road button's text, with the road's name.
const ROAD_TEXT := "Road: %s"
## Each road's name, by its finish: &"" is Keep Driving's, the endless road (ENDGAME_PLAN.md §5.13).
const ROAD_NAMES: Dictionary[StringName, String] = {
	&"pier": "To the sea", &"home": "Home", &"": "Endless"
}

## The game's schedule: the Atlas and the Book show its areas and legends.
var schedule: AreaSchedule
## The roads that Play can drive, the game's first, of which the Road button steps through
## offered_roads(). main.gd sets them.
var roads: Array[AreaSchedule] = []
## The road that Play drives, whose departures() the Start button steps through. main.gd sets it
## first; open() makes it the game's, from its first area, if it isn't offered.
var road: AreaSchedule
## Whether the Start button offers every area: in debug builds only, like the game-over screen's
## seed (docs/M3.md J19; docs/ZONE_SELECT.md Z4). Otherwise it offers the departures. Tests change
## it.
var every_area := OS.is_debug_build()
## The area that Play starts the run in. main.gd sets it first; open() makes it the first of the
## departures if it isn't one of them.
var start_area: AreaDef

## The button that opens each screen, which takes the focus back when the screen closes.
var _buttons: Dictionary[MenuScreen, Button] = {}

@onready var _background: ColorRect = %Background
@onready var _main_page: Control = %MainPage
@onready var _best: Label = %Best
@onready var _play: Button = %Play
@onready var _road_button: Button = %Road
@onready var _start: Button = %StartArea
@onready var _atlas: AtlasScreen = %Atlas
@onready var _book: BookScreen = %Book
@onready var _settings: SettingsScreen = %Settings
@onready var _atlas_button: Button = %AtlasButton
@onready var _disasters_button: Button = %DisastersButton
@onready var _settings_button: Button = %SettingsButton


func _ready() -> void:
	# The Book has no background of its own.
	_book.backdrop = _background.color
	_play.pressed.connect(_on_play_pressed)
	_road_button.pressed.connect(_on_road_pressed)
	_start.pressed.connect(_on_start_pressed)
	_add_screen(_atlas, _atlas_button, _open_atlas)
	_add_screen(_book, _disasters_button, _open_book)
	_add_screen(_settings, _settings_button, _open_settings)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel") and go_back():
		get_viewport().set_input_as_handled()


## Shows the title, with the bests from the save, the Road button if there are roads to choose
## from, and the Start button if there are departures.
func open() -> void:
	_close_screen()
	var data := SaveService.data()
	_best.text = AtlasScreen.best_text(data.best)
	var choices := offered_roads(roads, data)
	if road not in choices:
		road = choices[0]
		start_area = road.areas()[0]
	var areas := departures(road, data, every_area)
	if not areas.has(start_area):
		start_area = areas[0]
	_show_choices()
	_main_page.show()
	show()
	_play.grab_focus()


func close() -> void:
	_close_screen()
	hide()


## Leaves the open screen's page for the screen, or the screen for the title. Returns false if no
## screen was open.
func go_back() -> bool:
	var screen := open_screen()
	if screen == null:
		return false
	if screen.close_page():
		return true
	_close_screen()
	_main_page.show()
	_buttons[screen].grab_focus()
	return true


## The roads of `p_roads`, the game's first, that Play can drive: the game's alone until `data` has
## an arrival at its finish, and then each one (ENDGAME_PLAN.md §5.12).
static func offered_roads(p_roads: Array[AreaSchedule], data: SaveData) -> Array[AreaSchedule]:
	if data.arrival_count(p_roads[0].finish) > 0:
		return p_roads
	return p_roads.slice(0, 1)


## The areas of `p_road` that Play can start a run in, in the order a run reaches them: with
## `every`, as in debug builds, each one (docs/ZONE_SELECT.md Z1). Otherwise the road's first area,
## and each later one that `data`'s atlas has discovered, but a home stretch, which has no junction
## to play: Departures (ENDGAME_PLAN.md §5.11).
static func departures(p_road: AreaSchedule, data: SaveData, every: bool) -> Array[AreaDef]:
	if every:
		return p_road.areas()
	var areas: Array[AreaDef] = []
	# endless() leaves out a home stretch.
	for area: AreaDef in p_road.endless().areas():
		var entry: Dictionary = data.atlas.get(String(area.id), SaveData.ATLAS_ENTRY)
		if areas.is_empty() or entry["discovered"]:
			areas.append(area)
	return areas


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


func _open_book() -> void:
	_main_page.hide()
	_book.open(SaveService.data(), schedule)


func _open_settings() -> void:
	_main_page.hide()
	_settings.open()


func _on_play_pressed() -> void:
	if visible and open_screen() == null:
		play_requested.emit()


## The next of the roads offered, and after the last, the first, from its first area.
func _on_road_pressed() -> void:
	var choices := offered_roads(roads, SaveService.data())
	road = choices[(choices.find(road) + 1) % choices.size()]
	start_area = road.areas()[0]
	_show_choices()


## The next of the departures, and after the last, the first.
func _on_start_pressed() -> void:
	var areas := departures(road, SaveService.data(), every_area)
	start_area = areas[(areas.find(start_area) + 1) % areas.size()]
	_start.text = START_TEXT % start_area.display_name


## Names the road and the area that Play starts in on their buttons, each shown only if there is a
## choice.
func _show_choices() -> void:
	var data := SaveService.data()
	_road_button.text = ROAD_TEXT % ROAD_NAMES.get(road.finish, String(road.finish))
	_road_button.visible = offered_roads(roads, data).size() > 1
	_start.text = START_TEXT % start_area.display_name
	_start.visible = departures(road, data, every_area).size() > 1
