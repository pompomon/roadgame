extends Control
## M0 placeholder main scene. Shows the build version so artifacts are easy to identify.

@onready var _label: Label = %Label


func _ready() -> void:
	var version: String = ProjectSettings.get_setting("application/config/version", "dev")
	_label.text = "Road Roguelike %s" % version
