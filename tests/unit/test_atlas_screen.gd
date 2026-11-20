extends GutTest
## The Atlas (plan.md §2.6, IMPLEMENTATION_PLAN.md M5.5) on its own: a postcard for each area of
## the schedule, in its order, a silhouette until a run reaches the area, and the best run. A
## postcard shows its area's ground and tallest prop, and a stamp once a run crossed the area with
## no damage (docs/ENDGAME.md §5.16). The postcards scroll by drag and by keys (W33).

const ATLAS_SCENE := preload("res://ui/atlas_screen.tscn")
const TITLE_SCENE := preload("res://ui/title_screen.tscn")
const Finger := preload("res://tests/helpers/finger.gd")
## WCAG 2.2's least contrast for what is not text, 1.4.11.
const NON_TEXT_CONTRAST := 3.0


func _atlas() -> AtlasScreen:
	var view := SubViewport.new()
	view.size = Vector2i(360, 640)
	add_child_autofree(view)
	var atlas: AtlasScreen = ATLAS_SCENE.instantiate()
	view.add_child(atlas)
	return atlas


static func _schedule() -> AreaSchedule:
	return load("res://areas/schedule.tres")


## A run as GameState.stats() gives it, which made `areas` ({id: [distance, turns]}, or [distance,
## turns, crossed] for an area that it crossed with no damage if `crossed`).
static func _run(areas: Dictionary, distance: float, turns: int) -> Dictionary:
	var made := {}
	for id: StringName in areas:
		var each: Array = areas[id]
		var crossed: bool = each.size() > 2 and each[2]
		made[id] = {"distance": each[0], "turns": each[1], "damaged": false, "crossed": crossed}
	return {"areas": made, "distance": distance, "turn_index": turns}


static func _cards(atlas: AtlasScreen) -> Array[MenuCard]:
	var cards: Array[MenuCard] = []
	for card: MenuCard in atlas.get_node("%Cards").get_children():
		cards.append(card)
	return cards


static func _card_text(card: MenuCard) -> Array[String]:
	return [(card.get_node("%Title") as Label).text, (card.get_node("%Details") as Label).text]


static func _swatch(card: MenuCard) -> Color:
	return (card.get_node("%Swatch") as ColorRect).color


## Which stamp a postcard shows: "whole", "hollow", "both" or "none".
static func _stamp(card: MenuCard) -> String:
	var whole := (card.get_node("%Paper") as Control).visible
	var hollow := (card.get_node("%Hollow") as Control).visible
	if whole and hollow:
		return "both"
	if whole:
		return "whole"
	return "hollow" if hollow else "none"


## The contrast ratio of two colours, as WCAG 2.2 has it, from their relative luminance.
static func _contrast(a: Color, b: Color) -> float:
	var lighter := a.srgb_to_linear().get_luminance()
	var darker := b.srgb_to_linear().get_luminance()
	if darker > lighter:
		var swap := lighter
		lighter = darker
		darker = swap
	return (lighter + 0.05) / (darker + 0.05)


## Presses `key` and lets it go, through the Atlas's viewport, as a keyboard does: what has the
## focus gets it first, then the focus's moves, then what is left over.
## Whether all of `control` shows in `scroll`, beside its scroll bars.
static func _in_view(scroll: ScrollContainer, control: Control) -> bool:
	var shown := scroll.get_global_rect()
	if scroll.get_v_scroll_bar().visible:
		shown.size.x -= scroll.get_v_scroll_bar().size.x
	return shown.encloses(control.get_global_rect())


static func _key(atlas: AtlasScreen, key: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = key
		event.physical_keycode = key
		event.pressed = pressed
		atlas.get_viewport().push_input(event)


func test_before_any_run_every_area_is_a_silhouette_and_there_is_no_best() -> void:
	var atlas := _atlas()
	assert_false(atlas.visible)
	atlas.open(SaveData.new(), _schedule())
	assert_true(atlas.visible)
	assert_eq((atlas.get_node("%Best") as Label).text, "")
	var cards := _cards(atlas)
	assert_eq(cards.size(), 6, "city, rural, meadows, village, desert, coast")
	for card: MenuCard in cards:
		assert_eq(_card_text(card), [AtlasScreen.UNKNOWN, AtlasScreen.NOT_REACHED])
		assert_eq(_swatch(card), AtlasScreen.SILHOUETTE)


func test_a_reached_area_shows_its_name_colour_and_bests() -> void:
	var data := SaveData.new()
	data.record_run(_run({&"city": [34.0, 3], &"rural": [5.0, 1]}, 39.0, 4))
	data.record_run(_run({&"city": [20.0, 5]}, 20.0, 5))
	var atlas := _atlas()
	var schedule := _schedule()
	atlas.open(data, schedule)
	assert_eq((atlas.get_node("%Best") as Label).text, "Best: 390 m, 5 turns")
	var cards := _cards(atlas)
	var areas := schedule.areas()
	assert_eq(_card_text(cards[0]), ["City", "Best distance: 340 m\nBest turns: 5"])
	assert_eq(_swatch(cards[0]), areas[0].id_color)
	assert_eq(_card_text(cards[1]), ["Rural", "Best distance: 50 m\nBest turns: 1"])
	assert_eq(_swatch(cards[1]), areas[1].id_color)
	for card: MenuCard in cards.slice(2):
		assert_eq(_card_text(card)[0], AtlasScreen.UNKNOWN)


func test_opening_again_replaces_the_cards() -> void:
	var atlas := _atlas()
	atlas.open(SaveData.new(), _schedule())
	var data := SaveData.new()
	data.record_run(_run({&"city": [1.0, 0]}, 1.0, 0))
	atlas.open(data, _schedule())
	var cards := _cards(atlas)
	assert_eq(cards.size(), 6, "the old cards are gone")
	assert_eq(_card_text(cards[0])[0], "City")
	assert_no_new_orphans()


func test_back_takes_the_focus_and_asks_to_close() -> void:
	var atlas := _atlas()
	atlas.open(SaveData.new(), _schedule())
	var back: Button = atlas.get_node("%Back")
	assert_true(back.has_focus())
	watch_signals(atlas)
	back.pressed.emit()
	assert_signal_emit_count(atlas, "back_requested", 1)
	atlas.close()
	assert_false(atlas.visible)


func test_best_text_is_empty_until_a_run_goes_somewhere() -> void:
	assert_eq(AtlasScreen.best_text(SaveData.BEST), "")
	assert_eq(AtlasScreen.best_text({"distance": 0.04, "turns": 0}), "Best: 0 m, 0 turns")
	assert_eq(AtlasScreen.best_text({"distance": 0.0, "turns": 2}), "Best: 0 m, 2 turns")


## docs/ENDGAME.md §5.16: a postcard's stamp is whole once a run crossed its area with no damage,
## paper inked in the area's colour, and hollow until then, as is a silhouette's.
func test_a_postcards_stamp_is_whole_once_its_area_is_crossed_with_no_damage() -> void:
	var data := SaveData.new()
	data.record_run(_run({&"city": [34.0, 3, true], &"rural": [5.0, 1]}, 39.0, 4))
	var atlas := _atlas()
	var schedule := _schedule()
	atlas.open(data, schedule)
	var cards := _cards(atlas)
	assert_eq(_stamp(cards[0]), "whole", "the City, crossed")
	assert_true(cards[0].stamped)
	assert_eq((cards[0].get_node("%Ink") as ColorRect).color, schedule.areas()[0].id_color)
	assert_eq(_stamp(cards[1]), "hollow", "Rural, reached")
	assert_false(cards[1].stamped)
	for card: MenuCard in cards.slice(2):
		assert_eq(_stamp(card), "hollow", "a silhouette")


## docs/ENDGAME.md §5.16: a postcard's picture is its area's ground, with the area's tallest prop
## standing whole on it inside the picture's frame, at its own size. A silhouette's has neither.
func test_a_postcards_picture_is_its_areas_ground_and_tallest_prop() -> void:
	var schedule := _schedule()
	var reached := {}
	for area: AreaDef in schedule.areas():
		reached[area.id] = [1.0, 1]
	var data := SaveData.new()
	data.record_run(_run(reached, 1.0, 1))
	var atlas := _atlas()
	atlas.open(data, schedule)
	await wait_process_frames(2)
	var cards := _cards(atlas)
	for i: int in cards.size():
		var area := schedule.areas()[i]
		var ground: TextureRect = cards[i].get_node("%Ground")
		var prop: TextureRect = cards[i].get_node("%Prop")
		var tallest := MenuCard.tallest_prop(area)
		assert_not_null(area.ground, String(area.id))
		assert_eq(ground.texture, area.ground, String(area.id))
		var frame := prop.texture as AtlasTexture
		assert_eq(frame.atlas, tallest.texture, String(area.id))
		assert_eq(frame.region, Rect2(tallest.region), String(area.id))
		assert_eq(prop.size, Vector2(tallest.region.size), "%s: at its own size" % area.id)
		var inside := ground.get_global_rect().encloses(prop.get_global_rect())
		assert_true(inside, "%s: whole inside the frame" % area.id)
	atlas.open(SaveData.new(), schedule)
	for card: MenuCard in _cards(atlas):
		assert_null((card.get_node("%Ground") as TextureRect).texture, "a silhouette's")
		assert_null((card.get_node("%Prop") as TextureRect).texture, "a silhouette's")


## The tallest of an area's props is the first of those as tall, and none without props.
func test_the_tallest_prop_is_the_first_of_the_tallest() -> void:
	var area := AreaDef.new()
	assert_null(MenuCard.tallest_prop(area))
	for size: Vector2i in [Vector2i(8, 20), Vector2i(4, 30), Vector2i(6, 30), Vector2i(8, 10)]:
		var prop := PropDef.new()
		prop.region = Rect2i(Vector2i.ZERO, size)
		area.props.append(prop)
	assert_eq(MenuCard.tallest_prop(area), area.props[1])


## A screen reader reads each postcard as its area's name and whether it is stamped, or as an area
## not reached yet. Only a screen reader's focus stops on a postcard.
func test_a_screen_reader_reads_each_postcards_area_and_stamp() -> void:
	var data := SaveData.new()
	data.record_run(_run({&"city": [34.0, 3, true], &"rural": [5.0, 1]}, 39.0, 4))
	var atlas := _atlas()
	atlas.open(data, _schedule())
	var cards := _cards(atlas)
	assert_eq(cards[0].accessibility_name, "City, stamped")
	assert_eq(cards[1].accessibility_name, "Rural")
	for card: MenuCard in cards.slice(2):
		assert_eq(card.accessibility_name, AtlasScreen.NOT_REACHED)
	for card: MenuCard in cards:
		assert_eq(card.focus_mode, Control.FOCUS_ACCESSIBILITY)


## The Atlas scrolls to the postcard that has the focus, as a screen reader's moves down them: the
## last, below the fold. Headless, with no screen reader, the postcard takes any focus here, as a
## screen reader lets it.
func test_the_atlas_scrolls_to_the_postcard_that_has_the_focus() -> void:
	var atlas := _atlas()
	atlas.open(SaveData.new(), _schedule())
	await wait_process_frames(2)
	var scroll: ScrollContainer = atlas.get_node("%Scroll")
	var last: MenuCard = _cards(atlas).back()
	assert_false(_in_view(scroll, last), "below the fold")
	last.focus_mode = Control.FOCUS_ALL
	last.grab_focus()
	await wait_process_frames(2)
	assert_gt(scroll.scroll_vertical, 0)
	assert_true(_in_view(scroll, last), "scrolled to it")


## docs/ENDGAME.md §5.16, W26: a stamp stands out from its postcard, which the Atlas draws over the
## title's background: a hollow one's outline and a whole one's paper.
func test_a_stamp_whole_or_hollow_stands_out_from_its_postcard() -> void:
	var atlas := _atlas()
	atlas.open(SaveData.new(), _schedule())
	var card := _cards(atlas)[0]
	var title: Control = autofree(TITLE_SCENE.instantiate())
	var backdrop := (title.get_node("%Background") as ColorRect).color
	var ground := backdrop.blend((card.get_theme_stylebox(&"panel") as StyleBoxFlat).bg_color)
	var hollow := (card.get_node("%Hollow") as Panel).get_theme_stylebox(&"panel") as StyleBoxFlat
	assert_false(hollow.draw_center, "hollow")
	assert_gte(_contrast(hollow.border_color, ground), NON_TEXT_CONTRAST, "a hollow stamp")
	var paper := (card.get_node("%Paper") as ColorRect).color
	assert_gte(_contrast(paper, ground), NON_TEXT_CONTRAST, "a whole one")


## docs/ENDGAME.md W33: the postcards run past the screen, and as none takes the focus without a
## screen reader, the keys scroll them: an arrow by Tuning.BOOK_KEY_SCROLL of what shows, and Home
## and End to the top and the bottom. The Atlas opens again at its first postcard, and once closed
## it leaves the keys alone.
func test_the_keys_scroll_the_postcards_and_the_atlas_opens_at_the_first() -> void:
	var atlas := _atlas()
	(atlas.get_viewport() as SubViewport).size = Vector2i(360, 240)
	atlas.open(SaveData.new(), _schedule())
	await wait_process_frames(2)
	var scroll: ScrollContainer = atlas.get_node("%Scroll")
	var down := scroll.get_v_scroll_bar()
	var bottom := down.max_value - down.page
	var step := roundi(down.page * Tuning.BOOK_KEY_SCROLL)
	assert_gt(bottom, 2.0 * step, "taller than the screen")
	_key(atlas, KEY_DOWN)
	assert_eq(scroll.scroll_vertical, step, "Down")
	_key(atlas, KEY_DOWN)
	_key(atlas, KEY_UP)
	assert_eq(scroll.scroll_vertical, step, "Down, Down, Up")
	_key(atlas, KEY_END)
	assert_almost_eq(float(scroll.scroll_vertical), bottom, 1.0, "End")
	assert_true((atlas.get_node("%Back") as Button).has_focus(), "the focus stayed on Back")
	atlas.open(SaveData.new(), _schedule())
	await wait_process_frames(2)
	assert_eq(scroll.scroll_vertical, 0, "opened again")
	_key(atlas, KEY_END)
	_key(atlas, KEY_HOME)
	assert_eq(scroll.scroll_vertical, 0, "Home")
	atlas.close()
	_key(atlas, KEY_DOWN)
	assert_eq(scroll.scroll_vertical, 0, "closed")


## docs/ENDGAME.md W33: a drag that starts on a postcard scrolls the Atlas: no part of a postcard
## stops a finger.
func test_a_drag_from_a_postcard_scrolls_the_atlas() -> void:
	var data := SaveData.new()
	data.record_run(_run({&"city": [34.0, 3, true]}, 34.0, 3))
	var atlas := _atlas()
	atlas.open(data, _schedule())
	await wait_process_frames(2)
	var scroll: ScrollContainer = atlas.get_node("%Scroll")
	var card := _cards(atlas)[0]
	var touched := scroll.get_global_rect().has_point(card.get_global_rect().get_center())
	assert_true(touched, "the finger touches the postcard")
	var up: Array[Vector2] = [Vector2(0, -16), Vector2(0, -16), Vector2(0, -16), Vector2(0, -16)]
	Finger.drag(card, up)
	assert_eq(scroll.scroll_vertical, 64)
