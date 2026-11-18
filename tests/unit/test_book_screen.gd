extends GutTest
## The Book of Legends (ENDGAME_PLAN.md §5.10) on its own: a row for each area with a pool and a
## cell for each slot, "Legends n/N", a legend's still and name once it is found, or its silhouette
## and its name's initials, a seal on each row whose legends are all found, and a found legend's
## page: how often, where and how far into a run it was first seen (docs/M6.md S12), its fate and
## its lore; how a finger's drag and tap reach the Book, what a screen reader reads, and that a
## silhouette and a seal stand out from their grounds, a seal not earned yet hollow. The pools hold
## test legends, so that a change to the game's leaves these tests alone (S15), except where a test
## reads the game's.

const BOOK_SCENE := preload("res://ui/book_screen.tscn")
const TITLE_SCENE := preload("res://ui/title_screen.tscn")
const Disasters := preload("res://tests/helpers/disaster_fixtures.gd")
const Fixtures := preload("res://tests/helpers/road_fixtures.gd")
const GHOST_FATE := "The ghost drove off in your car."
const GHOST_LORE := "A sheet with two holes cut in it, out on the road at night."
const GHOUL_FATE := "The ghoul kept your car."
const GHOUL_LORE := "It waits by the graveyard gate."
## WCAG 2.2 1.4.11: the contrast with what is next to it that a shape needs to be made out.
const NON_TEXT_CONTRAST := 3.0
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


## The colours that a row's seal draws, each once, from the back: those of its parts that show.
static func _seal_colors(row: BookRow) -> Array[Color]:
	var colors: Array[Color] = []
	for part: Node in row.get_node(^"Seal").find_children("*", "ColorRect", true, false):
		var rect := part as ColorRect
		if rect.is_visible_in_tree() and not colors.has(rect.color):
			colors.append(rect.color)
	return colors


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


## Each row's name for a screen reader.
static func _row_names(book: BookScreen) -> Array[String]:
	var names: Array[String] = []
	for row: BookRow in _rows(book):
		names.append(row.accessibility_name)
	return names


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


## Whether `still` draws as its legend's silhouette: its shape, flat in BookScreen.SILHOUETTE.
static func _is_silhouette(still: LegendStill) -> bool:
	var flat := still.material as ShaderMaterial
	return (
		flat != null
		and flat.shader == BookScreen.SILHOUETTE_SHADER
		and flat.get_shader_parameter(&"fill") == BookScreen.SILHOUETTE
		and still.self_modulate == Color.WHITE
		and still.modulate == Color.WHITE
	)


## The contrast ratio of two colours, as WCAG 2.2 has it, from their relative luminance.
static func _contrast(a: Color, b: Color) -> float:
	var lighter := a.srgb_to_linear().get_luminance()
	var darker := b.srgb_to_linear().get_luminance()
	if darker > lighter:
		var swap := lighter
		lighter = darker
		darker = swap
	return (lighter + 0.05) / (darker + 0.05)


## Whether `control` is all in the part of `scroll` that shows its content, inside its scroll bars.
static func _in_view(scroll: ScrollContainer, control: Control) -> bool:
	var shown := scroll.get_global_rect()
	if scroll.get_v_scroll_bar().visible:
		shown.size.x -= scroll.get_v_scroll_bar().size.x
	if scroll.get_h_scroll_bar().visible:
		shown.size.y -= scroll.get_h_scroll_bar().size.y
	return shown.encloses(control.get_global_rect())


## The lightest channel of `ground` once a white texel of `still` adds its light, as a glow does.
static func _lit(still: LegendStill, ground: Color) -> float:
	var tint := still.self_modulate
	var lit := ground + Color(tint.r, tint.g, tint.b) * tint.a
	return maxf(lit.r, maxf(lit.g, lit.b))


## Stats as GameState.stats() gives them, `distance` tiles and `turns` turns into a run.
static func _stats(distance: float, turns: int) -> Dictionary:
	return {"distance": distance, "turn_index": turns}


## A finger that touches the middle of `cell`, moves by each of `moves` and lifts, all in one frame.
## Android sends each touch and move as Input's emulated mouse event first, then as itself.
static func _finger(cell: Control, moves: Array[Vector2]) -> void:
	var view := cell.get_viewport()
	var at := cell.get_global_rect().get_center()
	view.push_input(_mouse_button(at, true), true)
	view.push_input(_touch(at, true), true)
	for move: Vector2 in moves:
		at += move
		var motion := InputEventMouseMotion.new()
		motion.device = InputEvent.DEVICE_ID_EMULATION
		motion.position = at
		motion.global_position = at
		motion.relative = move
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		view.push_input(motion, true)
		var drag := InputEventScreenDrag.new()
		drag.position = at
		drag.relative = move
		view.push_input(drag, true)
	view.push_input(_mouse_button(at, false), true)
	view.push_input(_touch(at, false), true)


static func _mouse_button(at: Vector2, pressed: bool) -> InputEventMouseButton:
	var button := InputEventMouseButton.new()
	button.device = InputEvent.DEVICE_ID_EMULATION
	button.button_index = MOUSE_BUTTON_LEFT
	button.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	button.pressed = pressed
	button.position = at
	button.global_position = at
	return button


static func _touch(at: Vector2, pressed: bool) -> InputEventScreenTouch:
	var touch := InputEventScreenTouch.new()
	touch.pressed = pressed
	touch.position = at
	return touch


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
		assert_true(_is_silhouette(still), "as a silhouette")
		assert_true(cell.disabled)
		assert_eq(cell.focus_mode, Control.FOCUS_ACCESSIBILITY, "a screen reader's focus only")
	assert_eq(names, ["G____", "G____", "G____", "B____ D__", "W_____"])
	var ghoul := _cell(book, &"ghoul")
	ghoul.pressed.emit()
	assert_null(book.open_cell(), "no page, even for a screen reader's click")
	assert_false((book.get_node("%Page") as Control).is_visible_in_tree())


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
	assert_false((book.get_node("%Grid") as Control).is_visible_in_tree(), "in place of the grid")
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


## A screen reader's focus, which Tab moves, reaches each line of words that a page shows, from the
## count over it, in the order that they show. Without a screen reader, no line takes the focus, and
## Tab leaves it on Back. Godot 4.7.2 has a screen reader on the desktop builds only, and none
## headless, so the test reads the focus that each line takes.
func test_a_screen_reader_reaches_the_count_and_each_line_of_a_page() -> void:
	var data := SaveData.new()
	data.record_disaster(&"ghoul", &"farm", _stats(40.0, 4))
	var book := _book()
	book.open(data, _schedule())
	_cell(book, &"ghoul").pressed.emit()
	var lines: Array[Array] = []
	for label: Label in book.find_children("*", "Label", true, false):
		if label.is_visible_in_tree():
			lines.append([label.text, label.focus_mode])
	var reader := Control.FOCUS_ACCESSIBILITY
	assert_eq(
		lines,
		[
			["Legends 1/4", reader],
			["Ghoul", reader],
			["Seen once\nFirst: Farm, 400 m, 4 turns", reader],
			[GHOUL_FATE, reader],
			[GHOUL_LORE, reader],
		]
	)
	var back: Button = book.get_node("%Back")
	assert_eq(back.find_next_valid_focus(), back, "without a screen reader, Tab stays on Back")


## A page scrolls to the line that has the focus, as a screen reader's moves down it: the ghoul's
## lore, below the fold of a page too short for it. Headless, with no screen reader, the lore takes
## any focus here, as a screen reader lets it.
func test_a_page_scrolls_to_the_line_that_has_the_focus() -> void:
	var data := SaveData.new()
	data.record_disaster(&"ghoul", &"farm", _stats(1.0, 1))
	var book := _book()
	(book.get_viewport() as SubViewport).size = Vector2i(360, 300)
	book.open(data, _schedule())
	_cell(book, &"ghoul").pressed.emit()
	await wait_process_frames(2)
	var page: ScrollContainer = book.get_node("%PageScroll")
	var lore: Label = book.get_node("%Lore")
	assert_false(_in_view(page, lore), "below the fold")
	lore.focus_mode = Control.FOCUS_ALL
	lore.grab_focus()
	await wait_process_frames(2)
	assert_gt(page.scroll_vertical, 0)
	assert_true(_in_view(page, lore), "scrolled to it")


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


## ENDGAME_PLAN.md W26: a silhouette shows its legend's shape, flat in a grey that stands out from
## its cell's ground, the cell's disabled style, and a seal not earned yet, in the same grey, stands
## out from the title's background, which the Book draws over.
func test_a_silhouette_and_an_unearned_seal_stand_out_from_their_grounds() -> void:
	var book := _book()
	book.open(SaveData.new(), _schedule())
	var ghoul := _cell(book, &"ghoul")
	var ground := (ghoul.get_theme_stylebox(&"disabled") as StyleBoxFlat).bg_color
	assert_gte(_contrast(BookScreen.SILHOUETTE, ground), NON_TEXT_CONTRAST, "on its cell")
	assert_true(_is_silhouette(ghoul.still()), "flat, in that grey")
	var title: Control = autofree(TITLE_SCENE.instantiate())
	var backdrop := (title.get_node("%Background") as ColorRect).color
	assert_gte(_contrast(BookScreen.SILHOUETTE, backdrop), NON_TEXT_CONTRAST, "a seal on the title")
	assert_eq(_rows(book)[0].seal_color(), BookScreen.SILHOUETTE)


## ENDGAME_PLAN.md W26: a seal not earned yet is hollow, its star's outline, and an earned one is
## whole, so that they differ by their shapes too: the City's colour, Color(0.55, 0.58, 0.63), has a
## contrast of 1.28:1 with SILHOUETTE, in much the same hue. A hollow seal's outline stands out from
## the dark inside it, and a whole one draws its area's colour alone.
func test_a_seal_not_earned_is_hollow_and_an_earned_one_whole() -> void:
	var data := SaveData.new()
	var book := _book()
	var schedule := _schedule()
	book.open(data, schedule)
	for row: BookRow in _rows(book):
		assert_true(row.hollow())
		var colors := _seal_colors(row)
		assert_eq(colors.size(), 2, "an outline and its inside")
		assert_eq(colors.front(), BookScreen.SILHOUETTE)
		assert_gte(_contrast(colors.front(), colors.back()), NON_TEXT_CONTRAST)
	data.record_disaster(&"ghost", &"town", _stats(1.0, 1))
	book.open(data, schedule)
	assert_false(_rows(book)[0].hollow(), "the Town's ghost")
	assert_eq(_seal_colors(_rows(book)[0]), [Color.DARK_RED], "whole, with nothing drawn in it")
	assert_true(_rows(book)[1].hollow(), "the Farm's legends are missing")


## What a screen reader reads on a row: its area, how many of its legends are found and whether
## its seal is earned. Only a screen reader's focus stops on it, as on a silhouette.
func test_a_row_names_its_area_and_how_many_of_its_legends_are_found() -> void:
	var data := SaveData.new()
	var book := _book()
	var schedule := _schedule()
	book.open(data, schedule)
	assert_eq(_row_names(book), ["Town: 0 of 1 legends found", "Farm: 0 of 4 legends found"])
	for row: BookRow in _rows(book):
		assert_eq(row.focus_mode, Control.FOCUS_ACCESSIBILITY)
	data.record_disaster(&"ghost", &"town", _stats(1.0, 1))
	data.unlock_disaster(&"black_dog")
	book.open(data, schedule)
	assert_eq(
		_row_names(book),
		["Town: 1 of 1 legends found, sealed", "Farm: 2 of 4 legends found"],
		"seen or unlocked"
	)


func test_each_still_fits_its_cell_whole_with_square_pixels() -> void:
	# The wraith's 96 px are too many for a cell: it shows at half its size. The imp's 10 px are
	# few, and it keeps LegendStill's whole scale up. The horseman, unlocked and not seen yet, has
	# a name of two lines over a note: its band is taller than the scene leaves room for, and its
	# 64 px still stays whole above it.
	var schedule := _schedule()
	var moor: Array[PackedScene] = [
		Disasters.packed_legend(&"imp", "Imp", "", "", Vector2i(10, 10)),
		Disasters.packed_legend(&"horseman", "Headless Horseman", "", "", Vector2i(64, 64)),
	]
	schedule.entries.append(_entry(&"moor", "Moor", Color.DARK_ORANGE, moor))
	var data := SaveData.new()
	data.record_disaster(&"wraith", &"farm", _stats(1.0, 1))
	data.unlock_disaster(&"horseman")
	var book := _book()
	book.open(data, schedule)
	await wait_process_frames(2)
	for cell: BookCell in _cells(book):
		var still := cell.still()
		var art := (cell.get_node("%Art") as Control).get_global_rect()
		var band := (cell.get_node("%Band") as Control).get_global_rect()
		var drawn := still.get_global_transform() * still.get_rect()
		assert_gt(art.get_area(), 0.0, "%s: laid out" % still.id)
		assert_true(art.encloses(drawn), "%s: %s in %s" % [still.id, drawn, art])
		assert_false(band.intersects(drawn), "%s: %s clear of %s" % [still.id, drawn, band])
	var horseman := _cell(book, &"horseman")
	assert_eq((horseman.get_node("%Name") as Label).get_line_count(), 2)
	assert_eq(_text(horseman)[1], BookScreen.NOT_SEEN)
	assert_eq(horseman.still().scale, Vector2.ONE, "whole")
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
	assert_true(_is_silhouette(lights), "a silhouette, without its glow's blend")
	_cell(book, &"will_o_wisp").pressed.emit()
	assert_eq(_page_still(book).z_index, 0)
	assert_true(_page_still(book).z_as_relative)


func test_a_glow_adds_no_more_light_than_its_cell_or_the_backdrop_leaves_below_white() -> void:
	# The Will-o'-the-Wisp's and the Marfa Lights' stills add light, without their legends' veils
	# and alphas, and over the cells' styles they would clip to white (docs/M6.md S10). In a cell, a
	# white texel of each lights no channel past white over any style that the cell draws, and over
	# the lightest it reaches white; on its page, it reaches white over the Book's backdrop.
	var data := SaveData.new()
	data.record_disaster(&"will_o_wisp", &"meadows", _stats(1.0, 1))
	data.record_disaster(&"marfa_lights", &"desert", _stats(1.0, 1))
	var book := _book()
	book.backdrop = Color(0.5, 0.45, 0.4)
	book.open(data, Fixtures.schedule())
	for id: StringName in [&"will_o_wisp", &"marfa_lights"]:
		var cell := _cell(book, id)
		assert_not_null(cell.still().material, "%s: a glow" % id)
		var lightest := 0.0
		for style_name: StringName in [&"normal", &"hover", &"pressed"]:
			var style: StyleBoxFlat = cell.get_theme_stylebox(style_name)
			var lit := _lit(cell.still(), style.bg_color)
			assert_lte(lit, 1.0 + 1e-6, "%s over the cell's %s style" % [id, style_name])
			lightest = maxf(lightest, lit)
		assert_almost_eq(lightest, 1.0, 1e-5, "%s: as bright as its cell lets it be" % id)
		cell.pressed.emit()
		assert_almost_eq(_lit(_page_still(book), book.backdrop), 1.0, 1e-5, "%s: its page" % id)
		book.close_page()


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
	assert_true((book.get_node("%Grid") as Control).is_visible_in_tree())
	assert_false((book.get_node("%Page") as Control).is_visible_in_tree())
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
	assert_true((book.get_node("%Grid") as Control).is_visible_in_tree())
	assert_true((book.get_node("%Back") as Button).has_focus())
	assert_no_new_orphans()


## A page scrolls on its own, in place of the Book. Closing it shows the Book as it was left, with
## its cell in view, though the cell is where the Book scrolls both ways: the wraith's, the last of
## the Farm's, in a Book too short for its two rows. Opening the Book again starts at its top left.
func test_a_page_closes_to_its_cell_in_view_where_the_book_was_left() -> void:
	var data := SaveData.new()
	data.record_disaster(&"wraith", &"farm", _stats(1.0, 1))
	var book := _book()
	(book.get_viewport() as SubViewport).size = Vector2i(360, 300)
	book.open(data, _schedule())
	await wait_process_frames(2)
	var scroll: ScrollContainer = book.get_node("%Scroll")
	var wraith := _cell(book, &"wraith")
	wraith.grab_focus()
	await wait_process_frames(2)
	var left := Vector2i(scroll.scroll_horizontal, scroll.scroll_vertical)
	assert_gt(left.x, 0, "scrolled sideways")
	assert_gt(left.y, 0, "and down")
	assert_true(_in_view(scroll, wraith))
	wraith.pressed.emit()
	await wait_process_frames(2)
	assert_eq(book.open_cell(), wraith)
	assert_true(book.close_page())
	assert_true(wraith.has_focus())
	await wait_process_frames(2)
	assert_eq(Vector2i(scroll.scroll_horizontal, scroll.scroll_vertical), left, "where it was left")
	assert_true(_in_view(scroll, wraith), "its cell in view")
	book.open(data, _schedule())
	await wait_process_frames(2)
	assert_eq(Vector2i(scroll.scroll_horizontal, scroll.scroll_vertical), Vector2i.ZERO)


## A drag scrolls the Book wherever it starts: on a found legend's cell, which it doesn't open, and
## on a silhouette's. The Farm's four cells are wider than the Book, which scrolls them sideways.
func test_a_drag_from_any_cell_scrolls_the_book_and_opens_no_page() -> void:
	var data := SaveData.new()
	data.record_disaster(&"ghoul", &"farm", _stats(1.0, 1))
	var book := _book()
	book.open(data, _schedule())
	await wait_process_frames(2)
	var scroll: ScrollContainer = book.get_node("%Scroll")
	var bar := scroll.get_h_scroll_bar()
	assert_gt(bar.max_value - bar.page, 64.0, "wider than the Book")
	var left: Array[Vector2] = [Vector2(-16, 0), Vector2(-16, 0), Vector2(-16, 0), Vector2(-16, 0)]
	_finger(_cell(book, &"ghoul"), left)
	assert_eq(scroll.scroll_horizontal, 64, "from a found legend's cell")
	assert_null(book.open_cell(), "no page")
	await wait_process_frames(2)
	var right: Array[Vector2] = [Vector2(16, 0), Vector2(16, 0), Vector2(16, 0), Vector2(16, 0)]
	_finger(_cell(book, &"black_dog"), right)
	assert_eq(scroll.scroll_horizontal, 0, "from a silhouette's")
	assert_null(book.open_cell())


## A finger wobbles as it taps. Within the scroll's deadzone, the tap still opens the page, and the
## Book doesn't scroll.
func test_a_tap_that_wobbles_opens_the_page() -> void:
	var data := SaveData.new()
	data.record_disaster(&"ghoul", &"farm", _stats(1.0, 1))
	var book := _book()
	book.open(data, _schedule())
	await wait_process_frames(2)
	var ghoul := _cell(book, &"ghoul")
	var near := Tuning.BOOK_SCROLL_DEADZONE - 1.0
	var wobble: Array[Vector2] = [Vector2(-near, near / 2), Vector2(near, -near), Vector2(-2, near)]
	_finger(ghoul, wobble)
	assert_eq(book.open_cell(), ghoul)
	assert_eq((book.get_node("%Scroll") as ScrollContainer).scroll_horizontal, 0)


func test_initials_keep_each_words_first_letter_and_whatever_is_no_letter() -> void:
	assert_eq(BookScreen.initials("Phantom Bus"), "P______ B__")
	assert_eq(BookScreen.initials("Baba Yaga's Hut"), "B___ Y___'_ H__")
	assert_eq(BookScreen.initials("Will-o'-the-Wisp"), "W___-_'-___-____")
	assert_eq(BookScreen.initials("UFO"), "U__")


func test_a_word_too_wide_for_its_cell_breaks_after_a_hyphen() -> void:
	# An exported build's label breaks a line only at a space, and cuts a word too wide where it
	# overflows (ENDGAME_PLAN.md W25). Tests run in the editor's build, which breaks after a hyphen
	# itself, so this reads each cell's text: each part between its spaces and line breaks fits,
	# whether the cell shows a name or initials. Of the game's legends, only the Will-o'-the-Wisp's
	# name needs a break.
	var schedule := Fixtures.schedule()
	var data := SaveData.new()
	var book := _book()
	var broken: Array[String] = []
	for found: bool in [false, true]:
		if found:
			for disaster: Dictionary in BookScreen.disasters(schedule):
				data.record_disaster(disaster["id"], &"city", _stats(1.0, 1))
		book.open(data, schedule)
		await wait_process_frames(2)
		assert_eq(_cells(book).size(), 15, "the five pools")
		for cell: BookCell in _cells(book):
			var label: Label = cell.get_node("%Name")
			var font := label.get_theme_font(&"font")
			var font_size := label.get_theme_font_size(&"font_size")
			var width := label.size.x - label.get_theme_stylebox(&"normal").get_minimum_size().x
			var whole: String = cell.legend["name"]
			assert_eq(label.text.replace("\n", ""), whole if found else BookScreen.initials(whole))
			assert_gt(width, 0.0, "laid out")
			for part: String in label.text.replace("\n", " ").split(" "):
				var drawn := font.get_string_size(part, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
				assert_lte(drawn.x, width, "%s: %s" % [cell.legend["id"], part])
			if "\n" in label.text:
				broken.append(label.text)
	assert_eq(broken, ["Will-o'-the-\nWisp"])


## The cell's button shows no text of its own. A screen reader reads the cell's words: its name,
## whole where the label breaks it, or its initials, and its note.
func test_a_cell_reads_its_words_to_a_screen_reader() -> void:
	var schedule := _schedule()
	var wisp: Array[PackedScene] = [Disasters.packed_legend(&"wisp", "Will-o'-the-Wisp")]
	schedule.entries.append(_entry(&"moor", "Moor", Color.DARK_ORANGE, wisp))
	var data := SaveData.new()
	data.record_disaster(&"ghost", &"town", _stats(1.0, 1))
	data.unlock_disaster(&"ghoul")
	data.record_disaster(&"wisp", &"moor", _stats(1.0, 1))
	var book := _book()
	book.open(data, schedule)
	await wait_process_frames(2)
	assert_eq(_cell(book, &"ghost").accessibility_name, "Ghost")
	assert_eq(_cell(book, &"ghoul").accessibility_name, "Ghoul, " + BookScreen.NOT_SEEN)
	assert_eq(_cell(book, &"black_dog").accessibility_name, "B____ D__")
	var wisp_cell := _cell(book, &"wisp")
	assert_eq(_text(wisp_cell)[0], "Will-o'-the-\nWisp", "broken in its label")
	assert_eq(wisp_cell.accessibility_name, "Will-o'-the-Wisp")


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
		assert_true(_is_silhouette(cell.still()))
