extends GutTest
## The Atlas (plan.md §2.6, IMPLEMENTATION_PLAN.md M5.5) on its own: a card for each area of the
## schedule, in its order, a silhouette until a run reaches the area, and the best run.

const ATLAS_SCENE := preload("res://ui/atlas_screen.tscn")


func _atlas() -> AtlasScreen:
	var view := SubViewport.new()
	view.size = Vector2i(360, 640)
	add_child_autofree(view)
	var atlas: AtlasScreen = ATLAS_SCENE.instantiate()
	view.add_child(atlas)
	return atlas


static func _schedule() -> AreaSchedule:
	return load("res://areas/schedule.tres")


## A run as GameState.stats() gives it, which made `areas` ({id: [distance, turns]}).
static func _run(areas: Dictionary, distance: float, turns: int) -> Dictionary:
	var made := {}
	for id: StringName in areas:
		made[id] = {"distance": areas[id][0], "turns": areas[id][1]}
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


func test_before_any_run_every_area_is_a_silhouette_and_there_is_no_best() -> void:
	var atlas := _atlas()
	assert_false(atlas.visible)
	atlas.open(SaveData.new(), _schedule())
	assert_true(atlas.visible)
	assert_eq((atlas.get_node("%Best") as Label).text, "")
	var cards := _cards(atlas)
	assert_eq(cards.size(), 5, "city, rural, meadows, village, desert")
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
	assert_eq(cards.size(), 5, "the old cards are gone")
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
