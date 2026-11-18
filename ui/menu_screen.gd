class_name MenuScreen
extends Control
## A screen that the title screen opens (IMPLEMENTATION_PLAN.md M5.5): the Atlas, the Book of
## Legends (ENDGAME_PLAN.md §5.10) or the settings. Its Back button asks the title to close it.

## Back was pressed.
@warning_ignore("unused_signal")
signal back_requested


## Hides the screen. The title calls it when Back is pressed, and on Esc or Android's back button.
func close() -> void:
	hide()


## Closes a page that the screen shows in place of its own, such as a legend's in the Book, and
## returns true; false if none is open. Esc and Android's back button close a page before the
## screen.
func close_page() -> bool:
	return false
