class_name MenuScreen
extends Control
## A screen that the title screen opens (IMPLEMENTATION_PLAN.md M5.5): the Atlas, the Book of
## Legends (ENDGAME_PLAN.md §5.10) or the settings. Its Back button asks the title to close it, and
## the keys that move no focus may scroll it (scroll_by_key()).

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


## Scrolls `scroll` by `event` if it is one of the keys that move no focus, and returns whether it
## was: an arrow, which reaches a screen only where the focus has nowhere to go that way, by
## Tuning.BOOK_KEY_SCROLL of what shows, Page Up and Page Down by all of it, and Home and End to the
## top and the bottom. Without a screen reader, what a screen shows may take no focus, which a
## scroll follows, so these keys are what brings it into view where it runs past the screen
## (ENDGAME_PLAN.md W28).
static func scroll_by_key(scroll: ScrollContainer, event: InputEvent) -> bool:
	var across := scroll.get_h_scroll_bar()
	var down := scroll.get_v_scroll_bar()
	var by := Vector2.ZERO
	if event.is_action_pressed(&"ui_left", true, true):
		by.x = -across.page * Tuning.BOOK_KEY_SCROLL
	elif event.is_action_pressed(&"ui_right", true, true):
		by.x = across.page * Tuning.BOOK_KEY_SCROLL
	elif event.is_action_pressed(&"ui_up", true, true):
		by.y = -down.page * Tuning.BOOK_KEY_SCROLL
	elif event.is_action_pressed(&"ui_down", true, true):
		by.y = down.page * Tuning.BOOK_KEY_SCROLL
	elif event.is_action_pressed(&"ui_page_up", true, true):
		by.y = -down.page
	elif event.is_action_pressed(&"ui_page_down", true, true):
		by.y = down.page
	elif event.is_action_pressed(&"ui_home", true, true):
		by.y = -down.max_value
	elif event.is_action_pressed(&"ui_end", true, true):
		by.y = down.max_value
	else:
		return false
	# Each scroll stops at its ends.
	scroll.scroll_horizontal += roundi(by.x)
	scroll.scroll_vertical += roundi(by.y)
	return true
