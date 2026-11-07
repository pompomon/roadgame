extends GutTest
## InputRouter on its own (IMPLEMENTATION_PLAN.md M2.1). The integration test sends input through
## the main scene, with the HUD's Pause button in the way.


## Always steers half right.
class HalfRightAutopilot:
	extends Autopilot

	func _init() -> void:
		super(null)

	func steer() -> float:
		return 0.5


func _router() -> InputRouter:
	var router := InputRouter.new()
	add_child_autofree(router)
	return router


## A key event that matches both the ui_* actions (by keycode) and the game's actions (by physical
## keycode).
static func _key(keycode: Key, pressed: bool, echo := false) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = pressed
	event.echo = echo
	return event


static func _touch(index: int, x: float, pressed: bool) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = Vector2(x, 300.0)
	event.pressed = pressed
	return event


## The x of the screen's middle, and a touch a little to its left or right.
static func _middle(router: InputRouter) -> float:
	return router.get_viewport().get_visible_rect().get_center().x


func _send(router: InputRouter, events: Array[InputEvent]) -> void:
	for event: InputEvent in events:
		router._unhandled_input(event)


func test_with_nothing_held_it_steers_straight() -> void:
	assert_eq(_router().steer(), 0.0)


func test_the_last_key_pressed_wins_until_it_is_released() -> void:
	var router := _router()
	_send(router, [_key(KEY_LEFT, true)])
	assert_eq(router.steer(), -1.0, "left arrow")
	_send(router, [_key(KEY_D, true)])
	assert_eq(router.steer(), 1.0, "D pressed after the left arrow")
	_send(router, [_key(KEY_LEFT, true, true)])
	assert_eq(router.steer(), 1.0, "a key repeat is not a new press")
	_send(router, [_key(KEY_D, false)])
	assert_eq(router.steer(), -1.0, "the left arrow is still held")
	_send(router, [_key(KEY_LEFT, false)])
	assert_eq(router.steer(), 0.0)


func test_a_touch_steers_by_the_half_where_it_started() -> void:
	var router := _router()
	var middle := _middle(router)
	_send(router, [_touch(0, middle - 1.0, true)])
	assert_eq(router.steer(), -1.0, "left half")
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = Vector2(middle + 100.0, 300.0)
	_send(router, [drag])
	assert_eq(router.steer(), -1.0, "dragged into the right half")
	_send(router, [_touch(0, middle + 100.0, false)])
	assert_eq(router.steer(), 0.0, "lifted")
	_send(router, [_touch(0, middle + 1.0, true)])
	assert_eq(router.steer(), 1.0, "right half")


func test_touches_and_keys_mix_and_the_last_one_wins() -> void:
	var router := _router()
	var middle := _middle(router)
	_send(router, [_touch(0, middle - 50.0, true), _touch(1, middle + 50.0, true)])
	assert_eq(router.steer(), 1.0, "second touch, right")
	_send(router, [_key(KEY_A, true)])
	assert_eq(router.steer(), -1.0, "A after both touches")
	_send(router, [_touch(1, middle + 50.0, false), _touch(0, middle - 50.0, false)])
	assert_eq(router.steer(), -1.0, "A is still held")
	_send(router, [_key(KEY_A, false)])
	assert_eq(router.steer(), 0.0)


func test_while_disabled_it_steers_straight_and_ignores_input() -> void:
	var router := _router()
	_send(router, [_key(KEY_RIGHT, true)])
	router.enabled = false
	assert_eq(router.steer(), 0.0, "disabled")
	_send(router, [_key(KEY_LEFT, true)])
	router.enabled = true
	assert_eq(router.steer(), 0.0, "the held key was forgotten and the new one ignored")


func test_losing_focus_releases_everything_held() -> void:
	var router := _router()
	for what: int in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT]:
		_send(router, [_key(KEY_RIGHT, true), _touch(0, 0.0, true)])
		assert_ne(router.steer(), 0.0)
		router.notification(what)
		assert_eq(router.steer(), 0.0, "after notification %d" % what)


func test_an_autopilot_steers_instead_of_the_player() -> void:
	var router := _router()
	router.autopilot = HalfRightAutopilot.new()
	_send(router, [_key(KEY_LEFT, true)])
	assert_eq(router.steer(), 0.5)
	router.enabled = false
	assert_eq(router.steer(), 0.0, "disabled")
