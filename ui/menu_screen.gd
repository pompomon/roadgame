class_name MenuScreen
extends Control
## A screen that the title screen opens (IMPLEMENTATION_PLAN.md M5.5): the Atlas, the disaster
## collection or the settings. Its Back button asks the title to close it.

## Back was pressed.
@warning_ignore("unused_signal")
signal back_requested


## Hides the screen. The title calls it when Back is pressed, and on Esc or Android's back button.
func close() -> void:
	hide()
