class_name BookScreen
extends MenuScreen
## The Book of Legends (ENDGAME_PLAN.md §5.10), which the disaster collection became (plan.md
## §2.6). It reads the schedule's pools, whatever their size: a row for each area with a pool, in
## the road's order, and a cell for each slot of it, the ★, wave A's and wave B's (docs/POOLS.md
## §5.4). Over the grid, how many of the pools' legends are collected, seen or unlocked by an
## arrival (ENDGAME_PLAN.md §5.5). A cell (BookCell) shows a legend collected as its still and its
## name, and one not found as its still's silhouette and its name's initials. A row whose legends
## are all collected has a seal in its area's colour (BookRow). Tapping a legend collected opens its
## page: how often it was seen, and where and how far into a run first (docs/M6.md S12), its fate
## and its lore; a legend unlocked and not seen yet has its lore, but not how it ends a run. Back,
## Esc and Android's back button close the page before the Book. A drag scrolls the Book wherever
## it starts, on a cell too, once it goes further than Tuning.BOOK_SCROLL_DEADZONE, so that a tap
## that wobbles less still opens a page. A screen reader reads each row as its area and how many of
## its legends are found (ROW_NAME), and reaches it though its cells are all silhouettes. Like the
## HUD, its text uses only the font's glyphs. A glow's still adds no more light than its ground
## leaves below white: its cell's, or on its page the backdrop's (docs/M6.md S10).

const ROW_SCENE := preload("res://ui/book_row.tscn")
const CELL_SCENE := preload("res://ui/book_cell.tscn")
## Over the grid: the legends collected, of the pools' legends.
const HEADING := "Legends %d/%d"
## A row's name for a screen reader: its area's, then how many of its legends are found, of all.
const ROW_NAME := "%s: %d of %d legends found"
## After ROW_NAME, once the row's seal is earned.
const ROW_SEALED := ", sealed"
## Under the name of a legend that an arrival unlocked, before a run meets it.
const NOT_SEEN := "Not seen yet"
## Its page's words.
const UNLOCKED := "Unlocked by an arrival\nNot seen yet"
## The colour of a legend's silhouette, and of a seal not earned yet.
const SILHOUETTE := Color(0.1, 0.1, 0.12)
## How much larger than the world a page shows its legend's still.
const PAGE_ZOOM := 2.0

## The colour that the Book draws over, which bounds a glow's light on a legend's page: TitleScreen
## gives it its background's.
var backdrop := Color.BLACK

## The cell whose page is open, or null.
var _open_cell: BookCell

@onready var _heading: Label = %Heading
@onready var _scroll: ScrollContainer = %Scroll
@onready var _grid: VBoxContainer = %Grid
@onready var _page: VBoxContainer = %Page
@onready var _page_art: Control = %PageArt
@onready var _page_pivot: Control = %PagePivot
@onready var _page_name: Label = %PageName
@onready var _details: Label = %Details
@onready var _fate: Label = %Fate
@onready var _lore: Label = %Lore
@onready var _back: Button = %Back


func _ready() -> void:
	_scroll.scroll_deadzone = Tuning.BOOK_SCROLL_DEADZONE
	_back.pressed.connect(_on_back_pressed)


## Shows the Book of the legends in `data` of `schedule`'s pools.
func open(data: SaveData, schedule: AreaSchedule) -> void:
	_clear_page()
	for row: Node in _grid.get_children():
		row.free()
	var words := _words_of(schedule)
	var collected := data.seen_disasters()
	var count := 0
	for scene: PackedScene in words:
		if collected.has(words[scene]["id"]):
			count += 1
	_heading.text = HEADING % [count, words.size()]
	for area: AreaDef in schedule.areas():
		var row: BookRow = null
		var found_count := 0
		for scene: PackedScene in area.disasters:
			if not words.has(scene):
				continue
			if row == null:
				row = ROW_SCENE.instantiate()
				_grid.add_child(row)
			var cell: BookCell = CELL_SCENE.instantiate()
			row.add_child(cell)
			_show_cell(cell, scene, words[scene], data, schedule)
			if cell.found:
				found_count += 1
		if row != null:
			var cells := row.cells().size()
			var sealed := found_count == cells
			row.seal(area.id_color if sealed else SILHOUETTE, sealed)
			row.accessibility_name = (
				ROW_NAME % [area.display_name, found_count, cells] + (ROW_SEALED if sealed else "")
			)
	show()
	_back.grab_focus()


## Closes the open page for the grid, and gives its cell the focus. Returns false if no page was
## open.
func close_page() -> bool:
	var cell := _open_cell
	if cell == null:
		return false
	_clear_page()
	cell.grab_focus()
	return true


## The cell whose page is open, or null.
func open_cell() -> BookCell:
	return _open_cell


## The id, the display name, the fate and the lore of each disaster in the pools of `schedule`'s
## areas, each once, in the order of the areas: [{"id": StringName, "name": String, "fate": String,
## "lore": String}]. A scene that isn't a disaster's is an error, and left out.
static func disasters(schedule: AreaSchedule) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	found.assign(_words_of(schedule).values())
	return found


## How often a disaster was seen, and where and how far into a run it was seen first, from an entry
## of SaveData.disasters. `area` is the first area's, or null if the schedule has no such area.
static func seen_text(entry: Dictionary, area: AreaDef) -> String:
	var seen: int = entry["seen"]
	var distance: float = entry["first_distance"]
	var turns: int = entry["first_turns"]
	var where: String = area.display_name if area != null else entry["first_area"]
	return (
		"%s\nFirst: %s, %s, %d turns"
		% [
			"Seen once" if seen == 1 else "Seen %d times" % seen,
			where,
			Hud.distance_text(distance),
			turns,
		]
	)


## A name's initials, the first letter of each word, with each other letter an underscore and the
## rest kept: "Phantom Bus" is "P______ B__", "Baba Yaga's Hut" is "B___ Y___'_ H__".
static func initials(display_name: String) -> String:
	var hint := ""
	var first := true
	for c: String in display_name:
		var letter := c.to_upper() != c.to_lower()
		hint += "_" if letter and not first else c
		first = c == " "
	return hint


## The words of each disaster scene in the pools of `schedule`'s areas, each once, in the order of
## the areas, as disasters() gives them. A scene that isn't a disaster's is an error, and left out.
static func _words_of(schedule: AreaSchedule) -> Dictionary[PackedScene, Dictionary]:
	var words: Dictionary[PackedScene, Dictionary] = {}
	var scenes: Array[PackedScene] = []
	for area: AreaDef in schedule.areas():
		for scene: PackedScene in area.disasters:
			if scenes.has(scene):
				continue
			scenes.append(scene)
			var node: Node = scene.instantiate() if scene.can_instantiate() else null
			var disaster := node as DisasterBase
			if disaster != null:
				words[scene] = {
					"id": disaster.id,
					"name": disaster.display_name,
					"fate": disaster.fate,
					"lore": disaster.lore,
				}
			else:
				push_error("BookScreen: %s isn't a disaster" % scene.resource_path)
			if node != null:
				node.free()
	return words


## The page of `legend`, with its entry of SaveData.disasters: [details, fate, lore]. A legend
## unlocked and not seen yet has no fate; one not found has no page.
static func _page_text(
	legend: Dictionary, entry: Dictionary, schedule: AreaSchedule
) -> PackedStringArray:
	var text := PackedStringArray()
	if entry["seen"] > 0:
		var area := _find_area(schedule, entry["first_area"])
		text.append_array([seen_text(entry, area), legend["fate"], legend["lore"]])
	elif entry["unlocked"]:
		text.append_array([UNLOCKED, "", legend["lore"]])
	return text


static func _find_area(schedule: AreaSchedule, id: String) -> AreaDef:
	for area: AreaDef in schedule.areas():
		if String(area.id) == id:
			return area
	return null


## The still of the legend of `scene`, or null, with an error, if it has none. It draws in the
## order of the Book's controls, not the world's z; a legend not `found` draws as its silhouette,
## dark and without its glow's blend.
static func _still(scene: PackedScene, found: bool) -> LegendStill:
	var still := LegendStill.of(scene)
	if still != null:
		still.z_index = 0
		still.z_as_relative = true
		if not found:
			still.modulate = SILHOUETTE
			still.material = null
	return still


## Shows in `cell` the legend of `scene`, with its `words`, as `data` has it.
func _show_cell(
	cell: BookCell, scene: PackedScene, words: Dictionary, data: SaveData, schedule: AreaSchedule
) -> void:
	var entry: Dictionary = data.disasters.get(String(words["id"]), SaveData.DISASTER_ENTRY)
	var seen: bool = entry["seen"] > 0
	var found: bool = seen or entry["unlocked"]
	cell.scene = scene
	cell.legend = words
	cell.page = _page_text(words, entry, schedule)
	var text: String = words["name"] if found else initials(words["name"])
	cell.show_legend(_still(scene, found), text, NOT_SEEN if found and not seen else "", found)
	cell.pressed.connect(_open_page.bind(cell))


func _open_page(cell: BookCell) -> void:
	if not visible or _open_cell != null or not cell.found:
		return
	_open_cell = cell
	var still := _still(cell.scene, true)
	if still != null:
		still.scale *= PAGE_ZOOM
		still.self_modulate.a *= still.strength(backdrop)
		_page_pivot.add_child(still)
		_page_art.custom_minimum_size.y = still.get_rect().size.y * still.scale.y
	_page_name.text = cell.legend["name"]
	_details.text = cell.page[0]
	_fate.text = cell.page[1]
	_fate.visible = _fate.text != ""
	_lore.text = cell.page[2]
	_lore.visible = _lore.text != ""
	_grid.hide()
	_page.show()
	_scroll.scroll_vertical = 0
	_back.grab_focus()


## Leaves the page for the grid, without moving the focus.
func _clear_page() -> void:
	_open_cell = null
	for child: Node in _page_pivot.get_children():
		child.free()
	_page_art.custom_minimum_size.y = 0.0
	_page.hide()
	_grid.show()
	_scroll.scroll_vertical = 0


func _on_back_pressed() -> void:
	if not close_page():
		back_requested.emit()
