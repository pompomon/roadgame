extends GutTest
## The disaster collection (plan.md §2.6, IMPLEMENTATION_PLAN.md M5.5) on its own: a card for each
## disaster of the schedule's pools, in the order a run can first meet them, a silhouette until it
## is seen, and how often, where and how far into a run it was first seen.

const COLLECTION_SCENE := preload("res://ui/collection_screen.tscn")


func _collection() -> CollectionScreen:
	var view := SubViewport.new()
	view.size = Vector2i(360, 640)
	add_child_autofree(view)
	var collection: CollectionScreen = COLLECTION_SCENE.instantiate()
	view.add_child(collection)
	return collection


static func _schedule() -> AreaSchedule:
	return load("res://areas/schedule.tres")


static func _cards(collection: CollectionScreen) -> Array[MenuCard]:
	var cards: Array[MenuCard] = []
	for card: MenuCard in collection.get_node("%Cards").get_children():
		cards.append(card)
	return cards


static func _card_text(card: MenuCard) -> Array[String]:
	return [(card.get_node("%Title") as Label).text, (card.get_node("%Details") as Label).text]


static func _swatch(card: MenuCard) -> Color:
	return (card.get_node("%Swatch") as ColorRect).color


## Stats as GameState.stats() gives them, `distance` tiles and `turns` turns into a run.
static func _stats(distance: float, turns: int) -> Dictionary:
	return {"distance": distance, "turn_index": turns}


func test_the_games_disasters_in_the_order_a_run_meets_them_each_with_a_name() -> void:
	var found := CollectionScreen.disasters(_schedule())
	assert_eq(
		found,
		[
			{"id": &"sinkhole", "name": "Sinkhole"},
			{"id": &"tornado", "name": "Tornado"},
			{"id": &"flood", "name": "Flood"},
			{"id": &"quicksand", "name": "Quicksand"},
		]
	)
	assert_no_new_orphans("each scene is freed")


func test_a_pool_scene_that_is_no_disaster_is_an_error_and_left_out() -> void:
	var scene := PackedScene.new()
	var node := Node2D.new()
	scene.pack(node)
	node.free()
	var area := AreaDef.new()
	area.id = &"odd"
	area.disasters = [scene, load("res://disasters/flood.tscn")]
	var entry := AreaScheduleEntry.new()
	entry.area = area
	var schedule := AreaSchedule.new()
	schedule.entries = [entry]
	var found := CollectionScreen.disasters(schedule)
	assert_push_error("isn't a disaster")
	assert_eq(found, [{"id": &"flood", "name": "Flood"}])
	assert_no_new_orphans()


func test_before_any_disaster_every_card_is_a_silhouette() -> void:
	var collection := _collection()
	assert_false(collection.visible)
	collection.open(SaveData.new(), _schedule())
	assert_true(collection.visible)
	var cards := _cards(collection)
	assert_eq(cards.size(), 4)
	for card: MenuCard in cards:
		assert_eq(_card_text(card), [CollectionScreen.UNKNOWN, CollectionScreen.NOT_SEEN])
		assert_eq(_swatch(card), CollectionScreen.SILHOUETTE)


func test_a_seen_disaster_shows_how_often_and_where_and_when_first() -> void:
	var data := SaveData.new()
	data.record_disaster(&"tornado", &"rural", _stats(40.0, 4))
	data.record_disaster(&"tornado", &"village", _stats(210.0, 25))
	data.record_disaster(&"sinkhole", &"city", _stats(12.34, 2))
	var collection := _collection()
	var schedule := _schedule()
	collection.open(data, schedule)
	var cards := _cards(collection)
	assert_eq(_card_text(cards[0]), ["Sinkhole", "Seen once\nFirst: City, 123 m, 2 turns"])
	assert_eq(_swatch(cards[0]), schedule.areas()[0].id_color)
	assert_eq(_card_text(cards[1]), ["Tornado", "Seen 2 times\nFirst: Rural, 400 m, 4 turns"])
	assert_eq(_swatch(cards[1]), schedule.areas()[1].id_color)
	assert_eq(_card_text(cards[2])[0], CollectionScreen.UNKNOWN)


func test_a_first_area_that_the_schedule_lacks_shows_its_id() -> void:
	var data := SaveData.new()
	data.record_disaster(&"flood", &"moon", _stats(1.0, 0))
	var collection := _collection()
	collection.open(data, _schedule())
	var flood := _cards(collection)[2]
	assert_eq(_card_text(flood), ["Flood", "Seen once\nFirst: moon, 10 m, 0 turns"])
	assert_eq(_swatch(flood), CollectionScreen.SILHOUETTE)


func test_opening_again_replaces_the_cards_and_back_asks_to_close() -> void:
	var collection := _collection()
	collection.open(SaveData.new(), _schedule())
	collection.open(SaveData.new(), _schedule())
	assert_eq(_cards(collection).size(), 4, "the old cards are gone")
	var back: Button = collection.get_node("%Back")
	assert_true(back.has_focus())
	watch_signals(collection)
	back.pressed.emit()
	assert_signal_emit_count(collection, "back_requested", 1)
	assert_no_new_orphans()
