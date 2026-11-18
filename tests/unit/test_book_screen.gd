extends GutTest
## The Book of Legends (ENDGAME_PLAN.md §5.10) on its own: a row for each area with a pool and a
## cell for each slot, "Legends n/N", a legend's still and name once it is found, or its silhouette
## and its name's initials, a seal on each row whose legends are all found, and a found legend's
## page: how often, where and how far into a run it was first seen (docs/M6.md S12), its fate and
## its lore. The pools hold test legends, so that a change to the game's leaves these tests alone
## (S15), except where a test reads the game's.

const BOOK_SCENE := preload("res://ui/book_screen.tscn")
const Disasters := preload("res://tests/helpers/disaster_fixtures.gd")
const Fixtures := preload("res://tests/helpers/road_fixtures.gd")
const GHOST_FATE := "The ghost drove off in your car."
const GHOST_LORE := "A sheet with two holes cut in it, out on the road at night."
const GHOUL_FATE := "The ghoul kept your car."
const GHOUL_LORE := "It waits by the graveyard gate."
## A save that recorded the sinkhole, which left the game in M6 PR 8.
const RETIRED_SAVE := """{
	"version": 1,
	"disasters": {
		"sinkhole": { "seen": 3, "first_area": "city", "first_distance": 12.5, "first_turns": 3 }
	}
}"""


func _book() -> BookScreen:
	var view := SubViewport.new()
	view.size = Vector2i(360, 640)
	add_child_autofree(view)
	var book: BookScreen = BOOK_SCENE.instantiate()
	view.add_child(book)
	return book


## Three areas, with test legends in their pools: the Town's ghost; the Farm's ghoul, the ghost
## again, a black dog without a fate or lore, and a wraith too large for a cell; and the Marsh, with
## none.
static func _schedule() -> AreaSchedule:
	var ghost := Disasters.packed_legend(&"ghost", "Ghost", GHOST_FATE, GHOST_LORE)
	var farm: Array[PackedScene] = [
		Disasters.packed_legend(&"ghoul", "Ghoul", GHOUL_FATE, GHOUL_LORE),
		ghost,
		Disasters.packed_legend(&"black_dog", "Black Dog"),
		Disasters.packed_legend(&"wraith", "Wraith", "", "", Vector2i(96, 96)),
	]
	var schedule := AreaSchedule.new()
	schedule.entries = [
		_entry(&"town", "Town", Color.DARK_RED, [ghost]),
		_entry(&"farm", "Farm", Color.DARK_GREEN, farm),
		_entry(&"marsh", "Marsh", Color.DARK_BLUE, []),
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


static func _rows(book: BookScreen) -> Array[BookRow]:
	var rows: Array[BookRow] = []
	for row: BookRow in book.get_node("%Grid").get_children():
		rows.append(row)
	return rows


static func _cells(book: BookScreen) -> Array[BookCell]:
	var cells: Array[BookCell] = []
	for row: BookRow in _rows(book):
		cells.append_array(row.cells())
	return cells


## The ids of each row's legends.
static func _ids(book: BookScreen) -> Array[Array]:
	var ids: Array[Array] = []
	for row: BookRow in _rows(book):
		var legends: Array[StringName] = []
		for cell: BookCell in row.cells():
			legends.append(cell.legend["id"])
		ids.append(legends)
	return ids


## The first cell of the legend `id`.
static func _cell(book: BookScreen, id: StringName) -> BookCell:
	for cell: BookCell in _cells(book):
		if cell.legend["id"] == id:
			return cell
	return null


## A cell's name and note, "" when it shows none.
static func _text(cell: BookCell) -> Array[String]:
	var note: Label = cell.get_node("%Note")
	return [(cell.get_node("%Name") as Label).text, note.text if note.visible else ""]


## The open page's name, details, fate and lore, "" for each that it doesn't show.
static func _page(book: BookScreen) -> Array[String]:
	var shown: Array[String] = []
	for path: String in ["%PageName", "%Details", "%Fate", "%Lore"]:
		var label: Label = book.get_node(path)
		shown.append(label.text if label.is_visible_in_tree() else "")
	return shown


static func _page_still(book: BookScreen) -> LegendStill:
	var pivot: Control = book.get_node("%PagePivot")
	return pivot.get_child(0) as LegendStill if pivot.get_child_count() > 0 else null


## Stats as GameState.stats() gives them, `distance` tiles and `turns` turns into a run.
static func _stats(distance: float, turns: int) -> Dictionary:
	return {"distance": distance, "turn_index": turns}


func test_the_legends_in_the_order_a_run_meets_them_each_once_with_their_words() -> void:
	var found := BookScreen.disasters(_schedule())
	assert_eq(
		found,
		[
			{"id": &"ghost", "name": "Ghost", "fate": GHOST_FATE, "lore": GHOST_LORE},
			{"id": &"ghoul", "name": "Ghoul", "fate": GHOUL_FATE, "lore": GHOUL_LORE},
			{"id": &"black_dog", "name": "Black Dog", "fate": "", "lore": ""},
			{"id": &"wraith", "name": "Wraith", "fate": "", "lore": ""},
		]
	)
	assert_no_new_orphans("each scene is freed")


func test_a_pool_scene_that_is_no_disaster_is_an_error_and_left_out() -> void:
	var scene := PackedScene.new()
	var node := Node2D.new()
	scene.pack(node)
	node.free()
	var ghost := Disasters.packed_legend(&"ghost", "Ghost", GHOST_FATE, GHOST_LORE)
	var schedule := AreaSchedule.new()
	schedule.entries = [_entry(&"odd", "Odd", Color.GRAY, [scene, ghost])]
	var found := BookScreen.disasters(schedule)
	assert_push_error("isn't a disaster")
	assert_eq(found, [{"id": &"ghost", "name": "Ghost", "fate": GHOST_FATE, "lore": GHOST_LORE}])
	var book := _book()
	book.open(SaveData.new(), schedule)
	assert_push_error("isn't a disaster")
	assert_eq(_ids(book), [[&"ghost"]], "no cell for it")
	assert_no_new_orphans()


func test_a_row_for_each_area_with_a_pool_and_a_cell_for_each_slot() -> void:
	# A pool of 1, one of 4, with the ghost again, and one of none: whatever their size.
	var book := _book()
	assert_false(book.visible)
	book.open(SaveData.new(), _schedule())
	assert_true(book.visible)
	assert_eq(_ids(book), [[&"ghost"], [&"ghoul", &"ghost", &"black_dog", &"wraith"]])
	assert_true((book.get_node("%Back") as Button).has_focus())


func test_over_the_grid_how_many_of_the_pools_legends_are_found() -> void:
	var data := SaveData.new()
	var book := _book()
	book.open(data, _schedule())
	var heading: Label = book.get_node("%Heading")
	assert_eq(heading.text, "Legends 0/4", "each legend once, the ghost too")
	data.record_disaster(&"ghost", &"town", _stats(1.0, 1))
	data.unlock_disaster(&"ghoul")
	data.record_disaster(&"sinkhole", &"town", _stats(1.0, 1))
	book.open(data, _schedule())
	assert_eq(heading.text, "Legends 2/4", "seen or unlocked, of the pools only")


func test_a_legend_not_found_is_its_silhouette_and_its_initials_and_has_no_page() -> void:
	var book := _book()
	book.open(SaveData.new(), _schedule())
	var names: Array[String] = []
	for cell: BookCell in _cells(book):
		names.append(_text(cell)[0])
		assert_eq(_text(cell)[1], "", "no note")
		var still := cell.still()
		assert_not_null(still, "its still")
		assert_eq(still.id, cell.legend["id"])
		assert_eq(still.modulate, BookScreen.SILHOUETTE, "as a silhouette")
		assert_true(cell.disabled)
		assert_eq(cell.focus_mode, Control.FOCUS_NONE)
	assert_eq(names, ["G____", "G____", "G____", "B____ D__", "W_____"])
	var ghoul := _cell(book, &"ghoul")
	ghoul.pressed.emit()
	assert_null(book.open_cell(), "no page")
	assert_false((book.get_node("%Page") as Control).visible)


func test_a_legend_found_shows_its_still_and_its_name() -> void:
	var data := SaveData.new()
	data.record_disaster(&"ghost", &"town", _stats(1.0, 1))
	var book := _book()
	book.open(data, _schedule())
	var ghosts: Array[BookCell] = [_rows(book)[0].cells()[0], _rows(book)[1].cells()[1]]
	for cell: BookCell in ghosts:
		assert_eq(_text(cell), ["Ghost", ""])
		assert_eq(cell.still().modulate, Color.WHITE, "in its colours")
		assert_false(cell.disabled)
		assert_eq(cell.focus_mode, Control.FOCUS_ALL)
	assert_eq(_text(_cell(book, &"ghoul")), ["G____", ""], "the others are still hidden")


func test_a_found_legends_page_has_its_still_its_sightings_and_its_words() -> void:
	var data := SaveData.new()
	data.record_disaster(&"ghoul", &"farm", _stats(40.0, 4))
	data.record_disaster(&"ghoul", &"marsh", _stats(210.0, 25))
	data.record_disaster(&"black_dog", &"farm", _stats(12.34, 2))
	var book := _book()
	book.open(data, _schedule())
	var ghoul := _cell(book, &"ghoul")
	ghoul.pressed.emit()
	assert_eq(book.open_cell(), ghoul)
	assert_eq(
		_page(book), ["Ghoul", "Seen 2 times\nFirst: Farm, 400 m, 4 turns", GHOUL_FATE, GHOUL_LORE]
	)
	assert_false((book.get_node("%Grid") as Control).visible, "in place of the grid")
	var still := _page_still(book)
	assert_eq(still.id, &"ghoul")
	assert_eq(still.modulate, Color.WHITE)
	assert_eq(still.scale, Vector2.ONE * BookScreen.PAGE_ZOOM, "larger than in the world")
	assert_true((book.get_node("%Back") as Button).has_focus())
	assert_true(book.close_page())
	_cell(book, &"black_dog").pressed.emit()
	assert_eq(
		_page(book),
		["Black Dog", "Seen once\nFirst: Farm, 123 m, 2 turns", "", ""],
		"no fate or lore to show"
	)


## ENDGAME_PLAN.md §5.5: a legend that an arrival unlocked shows its still and its name, and that
## it hasn't been seen yet; its page has its lore, but not its fate. Once seen, it is a seen
## legend's.
func test_an_unlocked_legend_shows_until_it_is_seen() -> void:
	var data := SaveData.new()
	data.unlock_disaster(&"ghoul")
	var book := _book()
	var schedule := _schedule()
	book.open(data, schedule)
	var ghoul := _cell(book, &"ghoul")
	assert_eq(_text(ghoul), ["Ghoul", BookScreen.NOT_SEEN])
	assert_eq(ghoul.still().modulate, Color.WHITE)
	assert_false(ghoul.disabled)
	ghoul.pressed.emit()
	assert_eq(_page(book), ["Ghoul", BookScreen.UNLOCKED, "", GHOUL_LORE])
	data.record_disaster(&"ghoul", &"farm", _stats(40.0, 4))
	book.open(data, schedule)
	ghoul = _cell(book, &"ghoul")
	assert_eq(_text(ghoul), ["Ghoul", ""])
	ghoul.pressed.emit()
	assert_eq(
		_page(book), ["Ghoul", "Seen once\nFirst: Farm, 400 m, 4 turns", GHOUL_FATE, GHOUL_LORE]
	)


func test_a_first_area_that_the_schedule_lacks_shows_its_id() -> void:
	var data := SaveData.new()
	data.record_disaster(&"wraith", &"moon", _stats(1.0, 0))
	var book := _book()
	book.open(data, _schedule())
	_cell(book, &"wraith").pressed.emit()
	assert_eq(_page(book)[1], "Seen once\nFirst: moon, 10 m, 0 turns")


func test_a_row_whose_legends_are_all_found_has_a_seal_in_its_areas_colour() -> void:
	var data := SaveData.new()
	var book := _book()
	var schedule := _schedule()
	book.open(data, schedule)
	for row: BookRow in _rows(book):
		assert_false(row.sealed)
		assert_eq(row.seal_color(), BookScreen.SILHOUETTE)
	data.record_disaster(&"ghost", &"town", _stats(1.0, 1))
	data.record_disaster(&"ghoul", &"farm", _stats(1.0, 1))
	data.unlock_disaster(&"black_dog")
	book.open(data, schedule)
	var rows := _rows(book)
	assert_true(rows[0].sealed, "the Town's ghost")
	assert_eq(rows[0].seal_color(), Color.DARK_RED)
	assert_false(rows[1].sealed, "the Farm's wraith is missing")
	assert_eq(rows[1].seal_color(), BookScreen.SILHOUETTE)
	data.record_disaster(&"wraith", &"farm", _stats(1.0, 1))
	book.open(data, schedule)
	assert_true(_rows(book)[1].sealed, "seen or unlocked, the ghost too")
	assert_eq(_rows(book)[1].seal_color(), Color.DARK_GREEN)


func test_each_still_fits_its_cell_whole_with_square_pixels() -> void:
	# The wraith's 96 px are too many for a cell: it shows at half its size. The imp's 10 px are
	# few, and it keeps LegendStill's whole scale up.
	var schedule := _schedule()
	var imp: Array[PackedScene] = [Disasters.packed_legend(&"imp", "Imp", "", "", Vector2i(10, 10))]
	schedule.entries.append(_entry(&"moor", "Moor", Color.DARK_ORANGE, imp))
	var data := SaveData.new()
	data.record_disaster(&"wraith", &"farm", _stats(1.0, 1))
	var book := _book()
	book.open(data, schedule)
	await wait_process_frames(2)
	for cell: BookCell in _cells(book):
		var still := cell.still()
		var art := (cell.get_node("%Art") as Control).get_global_rect()
		var drawn := still.get_global_transform() * still.get_rect()
		assert_gt(art.get_area(), 0.0, "%s: laid out" % still.id)
		assert_true(art.encloses(drawn), "%s: %s in %s" % [still.id, drawn, art])
	assert_eq(_cell(book, &"wraith").still().scale, Vector2.ONE * 0.5)
	assert_eq(_cell(book, &"ghost").still().scale, Vector2.ONE)
	assert_eq(_cell(book, &"imp").still().scale, Vector2.ONE * 3.0)
	_cell(book, &"wraith").pressed.emit()
	assert_eq(_page_still(book).scale, Vector2.ONE * BookScreen.PAGE_ZOOM, "whole on its page")


func test_a_glow_draws_in_the_books_order_and_a_silhouette_has_no_glow() -> void:
	# The Meadows' Will-o'-the-Wisp and the Desert's Marfa Lights are glows, above the veil in the
	# world (docs/DAYNIGHT.md §5.5). In the Book they draw under the cell's band, and a silhouette
	# doesn't add light.
	var schedule := Fixtures.schedule()
	var data := SaveData.new()
	data.record_disaster(&"will_o_wisp", &"meadows", _stats(1.0, 1))
	var book := _book()
	book.open(data, schedule)
	var wisp := _cell(book, &"will_o_wisp").still()
	var lights := _cell(book, &"marfa_lights").still()
	var world: LegendStill = autofree(LegendStill.of(_cell(book, &"marfa_lights").scene))
	assert_not_null(world.material, "a glow in the world")
	assert_gt(world.z_index, 0, "above the veil in the world")
	for still: LegendStill in [wisp, lights]:
		assert_eq(still.z_index, 0, "%s: in the Book's order" % still.id)
		assert_true(still.z_as_relative)
	assert_not_null(wisp.material, "a glow, found")
	assert_null(lights.material, "a silhouette")
	assert_eq(lights.modulate, BookScreen.SILHOUETTE)
	_cell(book, &"will_o_wisp").pressed.emit()
	assert_eq(_page_still(book).z_index, 0)
	assert_true(_page_still(book).z_as_relative)


func test_back_closes_the_page_and_gives_its_cell_the_focus_then_asks_to_close() -> void:
	var data := SaveData.new()
	data.record_disaster(&"ghoul", &"farm", _stats(1.0, 1))
	var book := _book()
	book.open(data, _schedule())
	assert_false(book.close_page(), "no page is open")
	var ghoul := _cell(book, &"ghoul")
	ghoul.pressed.emit()
	var back: Button = book.get_node("%Back")
	watch_signals(book)
	back.pressed.emit()
	assert_signal_not_emitted(book, "back_requested")
	assert_null(book.open_cell())
	assert_null(_page_still(book), "its still is gone")
	assert_true((book.get_node("%Grid") as Control).visible)
	assert_false((book.get_node("%Page") as Control).visible)
	assert_true(ghoul.has_focus(), "back on its cell")
	back.pressed.emit()
	assert_signal_emit_count(book, "back_requested", 1)
	assert_no_new_orphans()


func test_opening_again_replaces_the_rows_and_closes_the_page() -> void:
	var data := SaveData.new()
	data.record_disaster(&"ghoul", &"farm", _stats(1.0, 1))
	var book := _book()
	book.open(data, _schedule())
	_cell(book, &"ghoul").pressed.emit()
	book.open(data, _schedule())
	assert_eq(_rows(book).size(), 2, "the old rows are gone")
	assert_null(book.open_cell())
	assert_null(_page_still(book))
	assert_true((book.get_node("%Grid") as Control).visible)
	assert_true((book.get_node("%Back") as Button).has_focus())
	assert_no_new_orphans()


func test_initials_keep_each_words_first_letter_and_whatever_is_no_letter() -> void:
	assert_eq(BookScreen.initials("Phantom Bus"), "P______ B__")
	assert_eq(BookScreen.initials("Baba Yaga's Hut"), "B___ Y___'_ H__")
	assert_eq(BookScreen.initials("Will-o'-the-Wisp"), "W___-_'-___-____")
	assert_eq(BookScreen.initials("UFO"), "U__")


func test_a_save_that_recorded_a_retired_disaster_loads_and_shows_only_the_pools() -> void:
	# docs/M6.md E10, Q3: the natural four left the game's pools and files in M6 PR 8. A save that
	# recorded one still loads and keeps it, and the Book shows a cell for each slot of the game's
	# pools alone, each a silhouette.
	var data := SaveData.new()
	assert_eq(data.load_json(RETIRED_SAVE), SaveData.Status.LOADED)
	assert_eq(data.problems, PackedStringArray())
	assert_eq(data.disasters.keys(), ["sinkhole"], "it keeps what it recorded")
	var schedule := Fixtures.schedule()
	var book := _book()
	book.open(data, schedule)
	var slots := 0
	for area: AreaDef in schedule.areas():
		slots += area.disasters.size()
	var cells := _cells(book)
	assert_eq(cells.size(), slots, "the pools' slots")
	var legends := BookScreen.disasters(schedule).size()
	assert_eq((book.get_node("%Heading") as Label).text, "Legends 0/%d" % legends)
	for cell: BookCell in cells:
		assert_eq(_text(cell), [BookScreen.initials(cell.legend["name"]), ""])
		assert_eq(cell.still().modulate, BookScreen.SILHOUETTE)
