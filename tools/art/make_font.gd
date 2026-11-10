extends SceneTree
## Makes the UI's font (M5_PLAN.md §5.8): assets/fonts/pixel_operator_8.tres, the TTF beside it
## embedded in a FontFile, drawn without smoothing. The project theme (ui/theme.tres) uses it, and
## Godot loads that theme before it imports anything, so the font must load unimported: a fresh
## checkout's first import would otherwise fail (M5_PLAN.md L17). From the repository root:
##   godot --headless -s tools/art/make_font.gd

const SOURCE := "res://assets/fonts/PixelOperator8.ttf"
const PATH := "res://assets/fonts/pixel_operator_8.tres"


func _initialize() -> void:
	var font := FontFile.new()
	font.data = FileAccess.get_file_as_bytes(SOURCE)
	font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	font.hinting = TextServer.HINTING_NONE
	font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	font.allow_system_fallback = false
	var error := ResourceSaver.save(font, PATH)
	if error != OK:
		push_error("make_font: can't write %s (%s)" % [PATH, error_string(error)])
	else:
		print("make_font: %s" % PATH)
	quit()
