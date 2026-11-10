class_name SettingsScreen
extends MenuScreen
## The settings (plan.md §2.6, IMPLEMENTATION_PLAN.md M5.5): the volumes of the music, the sound
## effects and the ambient sound, vibration, and the screen's orientation. Each change goes to
## SaveService at once, which writes it SETTINGS_SAVE_DELAY after the last change, or when the
## screen closes. AudioDirector applies the volumes as they change (M5.3); vibration and the
## orientation take effect in M6 (M6.1, M6.2). Like the HUD, its text uses only characters in
## Godot's default font.

## How the orientation menu names SaveData.ORIENTATIONS, in its order.
const ORIENTATION_NAMES: Array[String] = ["Auto-rotate", "Portrait", "Landscape"]

@onready var _volumes: Dictionary[String, HSlider] = {
	"music": %Music,
	"sfx": %Sfx,
	"ambient": %Ambient,
}
@onready var _haptics: CheckButton = %Haptics
@onready var _orientation: OptionButton = %Orientation
@onready var _back: Button = %Back


func _ready() -> void:
	for label: String in ORIENTATION_NAMES:
		_orientation.add_item(label)
	for key: String in _volumes:
		_volumes[key].value_changed.connect(_on_volume_changed.bind(key))
	_haptics.toggled.connect(_on_haptics_toggled)
	_orientation.item_selected.connect(_on_orientation_selected)
	_back.pressed.connect(back_requested.emit)


## Shows the saved settings.
func open() -> void:
	for key: String in _volumes:
		_volumes[key].set_value_no_signal(SaveService.setting(key))
	_haptics.set_pressed_no_signal(SaveService.setting("haptics"))
	_orientation.select(SaveData.ORIENTATIONS.find(SaveService.setting("orientation")))
	show()
	_volumes["music"].grab_focus()


## Hides the screen and writes the changes at once.
func close() -> void:
	hide()
	SaveService.flush()


func _on_volume_changed(value: float, key: String) -> void:
	SaveService.set_setting(key, value)


func _on_haptics_toggled(on: bool) -> void:
	SaveService.set_setting("haptics", on)


func _on_orientation_selected(index: int) -> void:
	SaveService.set_setting("orientation", SaveData.ORIENTATIONS[index])
