extends GutTest
## The disaster collection (plan.md §2.6, IMPLEMENTATION_PLAN.md M5.5) on its own: a card for each
## disaster of the schedule's pools, in the order a run can first meet them, a silhouette until it
## is seen, and how often, where and how far into a run it was first seen, and its lore (M6_PLAN.md
## S12). The pools hold test disasters, so that a change to the game's leaves these tests alone
## (S15).

const COLLECTION_SCENE := preload("res://ui/collection_screen.tscn")
const Disasters := preload("res://tests/helpers/disaster_fixtures.gd")
const GHOST_LORE := "A sheet with two holes cut in it, out on the road at night."
const GHOUL_LORE := "It waits by the graveyard gate."
## A save that recorded the sinkhole, which left the game in M6 PR 8.
const RETIRED_SAVE := """{
	"version": 1,
	"disasters": {
		"sinkhole": { "seen": 3, "first_area": "city", "first_distance": 12.5, "first_turns": 3 }
	}
}"""


func _collection() -> CollectionScreen:
	var view := SubViewport.new()
	view.size = Vector2i(360, 640)
	add_child_autofree(view)
	var collection: CollectionScreen = COLLECTION_SCENE.instantiate()
	view.add_child(collection)
	return collection


## Three areas, with test disasters in their pools: the Town's ghost; the Farm's ghoul, and the
## ghost again, which the collection shows once; and the Marsh's wraith, which has no lore.
static func _schedule() -> AreaSchedule:
	var ghost := Disasters.packed(&"ghost", "Ghost", "", GHOST_LORE)
	var ghoul := Disasters.packed(&"ghoul", "Ghoul", "", GHOUL_LORE)
	var schedule := AreaSchedule.new()
	schedule.entries = [
		_entry(&"town", "Town", Color.DARK_RED, [ghost]),
		_entry(&"farm", "Farm", Color.DARK_GREEN, [ghoul, ghost]),
		_entry(&"marsh", "Marsh", Color.DARK_BLUE, [Disasters.packed(&"wraith", "Wraith")]),
	]
	return schedule


static func _entry(
	id: StringName, display_name: String, color: Color, pool: Array[PackedScene]
) -> AreaScheduleEntry:
	var area := AreaDef.new()
	area.id = id
	area.display_name = display_name
	area.id_color = color
	area.disasters = pool
	var entry := AreaScheduleEntry.new()
	entry.area = area
	return entry


static func _cards(collection: CollectionScreen) -> Array[MenuCard]:
	var cards: Array[MenuCard] = []
	for card: MenuCard in collection.get_node("%Cards").get_children():
		cards.append(card)
	return cards


static func _card_text(card: MenuCard) -> Array[String]:
	return [(card.get_node("%Title") as Label).text, (card.get_node("%Details") as Label).text]


## The card's lore, or "" when it shows none.
static func _lore(card: MenuCard) -> String:
	var lore: Label = card.get_node("%Lore")
	return lore.text if lore.visible else ""


static func _swatch(card: MenuCard) -> Color:
	return (card.get_node("%Swatch") as ColorRect).color


## Stats as GameState.stats() gives them, `distance` tiles and `turns` turns into a run.
static func _stats(distance: float, turns: int) -> Dictionary:
	return {"distance": distance, "turn_index": turns}


func test_the_disasters_in_the_order_a_run_meets_them_each_once_with_a_name_and_lore() -> void:
	var found := CollectionScreen.disasters(_schedule())
	assert_eq(
		found,
		[
			{"id": &"ghost", "name": "Ghost", "lore": GHOST_LORE},
			{"id": &"ghoul", "name": "Ghoul", "lore": GHOUL_LORE},
			{"id": &"wraith", "name": "Wraith", "lore": ""},
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
	area.disasters = [scene, Disasters.packed(&"ghost", "Ghost", "", GHOST_LORE)]
	var entry := AreaScheduleEntry.new()
	entry.area = area
	var schedule := AreaSchedule.new()
	schedule.entries = [entry]
	var found := CollectionScreen.disasters(schedule)
	assert_push_error("isn't a disaster")
	assert_eq(found, [{"id": &"ghost", "name": "Ghost", "lore": GHOST_LORE}])
	assert_no_new_orphans()


func test_before_any_disaster_every_card_is_a_silhouette() -> void:
	var collection := _collection()
	assert_false(collection.visible)
	collection.open(SaveData.new(), _schedule())
	assert_true(collection.visible)
	var cards := _cards(collection)
	assert_eq(cards.size(), 3)
	for card: MenuCard in cards:
		assert_eq(_card_text(card), [CollectionScreen.UNKNOWN, CollectionScreen.NOT_SEEN])
		assert_eq(_swatch(card), CollectionScreen.SILHOUETTE)
		assert_eq(_lore(card), "", "no lore")


func test_a_seen_disaster_shows_how_often_and_where_and_when_first() -> void:
	var data := SaveData.new()
	data.record_disaster(&"ghoul", &"farm", _stats(40.0, 4))
	data.record_disaster(&"ghoul", &"marsh", _stats(210.0, 25))
	data.record_disaster(&"ghost", &"town", _stats(12.34, 2))
	var collection := _collection()
	var schedule := _schedule()
	collection.open(data, schedule)
	var cards := _cards(collection)
	assert_eq(_card_text(cards[0]), ["Ghost", "Seen once\nFirst: Town, 123 m, 2 turns"])
	assert_eq(_swatch(cards[0]), schedule.areas()[0].id_color)
	assert_eq(_card_text(cards[1]), ["Ghoul", "Seen 2 times\nFirst: Farm, 400 m, 4 turns"])
	assert_eq(_swatch(cards[1]), schedule.areas()[1].id_color)
	assert_eq(_card_text(cards[2])[0], CollectionScreen.UNKNOWN)


func test_a_seen_card_shows_its_lore_under_its_details() -> void:
	# M6_PLAN.md S12: in a label of its own, so that the details read as before (test_title.gd).
	var data := SaveData.new()
	data.record_disaster(&"ghost", &"town", _stats(1.0, 1))
	data.record_disaster(&"wraith", &"marsh", _stats(1.0, 1))
	var collection := _collection()
	collection.open(data, _schedule())
	var cards := _cards(collection)
	assert_eq(_lore(cards[0]), GHOST_LORE)
	assert_eq(_card_text(cards[0])[1], "Seen once\nFirst: Town, 10 m, 1 turns", "without the lore")
	assert_eq(_lore(cards[1]), "", "none on a silhouette")
	assert_eq(_lore(cards[2]), "", "none for a disaster without lore")


func test_a_first_area_that_the_schedule_lacks_shows_its_id() -> void:
	var data := SaveData.new()
	data.record_disaster(&"wraith", &"moon", _stats(1.0, 0))
	var collection := _collection()
	collection.open(data, _schedule())
	var wraith := _cards(collection)[2]
	assert_eq(_card_text(wraith), ["Wraith", "Seen once\nFirst: moon, 10 m, 0 turns"])
	assert_eq(_swatch(wraith), CollectionScreen.SILHOUETTE)


func test_opening_again_replaces_the_cards_and_back_asks_to_close() -> void:
	var collection := _collection()
	collection.open(SaveData.new(), _schedule())
	collection.open(SaveData.new(), _schedule())
	assert_eq(_cards(collection).size(), 3, "the old cards are gone")
	var back: Button = collection.get_node("%Back")
	assert_true(back.has_focus())
	watch_signals(collection)
	back.pressed.emit()
	assert_signal_emit_count(collection, "back_requested", 1)
	assert_no_new_orphans()


func test_a_save_that_recorded_a_retired_disaster_loads_and_shows_only_the_pools() -> void:
	# M6_PLAN.md E10, Q3: the natural four left the game's pools and files in M6 PR 8. A save that
	# recorded one still loads and keeps it, and the collection shows a card for each disaster of
	# the game's pools alone, each a silhouette.
	var data := SaveData.new()
	assert_eq(data.load_json(RETIRED_SAVE), SaveData.Status.LOADED)
	assert_eq(data.problems, PackedStringArray())
	assert_eq(data.disasters.keys(), ["sinkhole"], "it keeps what it recorded")
	var schedule: AreaSchedule = load("res://areas/schedule.tres")
	var collection := _collection()
	collection.open(data, schedule)
	var cards := _cards(collection)
	assert_eq(cards.size(), CollectionScreen.disasters(schedule).size(), "the pools' disasters")
	for card: MenuCard in cards:
		assert_eq(_card_text(card), [CollectionScreen.UNKNOWN, CollectionScreen.NOT_SEEN])
