class_name AtlasScreen
extends MenuScreen
## The Atlas (plan.md §2.6, IMPLEMENTATION_PLAN.md M5.5): the bests, and a postcard for each area
## of the schedule, in the order a run reaches them (MenuCard, docs/ENDGAME.md §5.16). An area that
## no run has reached is a silhouette. A postcard's bests are the most distance and the most turns
## a run made in that area (docs/M5.md L8), and its stamp is earned by a run that crossed the area
## with no damage. The postcards run past the screen: a drag scrolls them, and so do the keys that
## move no focus, as no postcard takes it without a screen reader (MenuScreen.scroll_by_key()). A
## screen reader reads each postcard as its area's name, and whether it is stamped (STAMPED), and
## the Atlas scrolls to the postcard that it moves to. Like the HUD, its text uses only the font's
## glyphs.

const CARD_SCENE := preload("res://ui/menu_card.tscn")
## The name of an area that no run has reached, and its card's text and swatch.
const UNKNOWN := "???"
const NOT_REACHED := "Not reached yet"
const SILHOUETTE := Color(0.1, 0.1, 0.12)
## After the area's name, a postcard's name for a screen reader once its stamp is earned.
const STAMPED := ", stamped"

@onready var _best: Label = %Best
@onready var _scroll: ScrollContainer = %Scroll
@onready var _cards: VBoxContainer = %Cards
@onready var _back: Button = %Back


func _ready() -> void:
	_back.pressed.connect(back_requested.emit)


## Scrolls the postcards with the keys that move no focus.
func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() and scroll_by_key(_scroll, event):
		get_viewport().set_input_as_handled()


## Shows the atlas in `data` of the areas of `schedule`, from its first postcard.
func open(data: SaveData, schedule: AreaSchedule) -> void:
	_best.text = best_text(data.best)
	_scroll.scroll_vertical = 0
	for card: Node in _cards.get_children():
		card.free()
	for area: AreaDef in schedule.areas():
		var card: MenuCard = CARD_SCENE.instantiate()
		_cards.add_child(card)
		var entry: Dictionary = data.atlas.get(String(area.id), SaveData.ATLAS_ENTRY)
		if entry["discovered"]:
			var stamped: bool = entry["stamped"]
			card.show_entry(area.display_name, area_text(entry), area.id_color, area, stamped)
			card.accessibility_name = area.display_name + (STAMPED if stamped else "")
		else:
			card.show_entry(UNKNOWN, NOT_REACHED, SILHOUETTE)
			card.accessibility_name = NOT_REACHED
	show()
	_back.grab_focus()


## The best distance and the most turns, from SaveData.best, in a line; nothing before the first
## run. They may come from different runs.
static func best_text(best: Dictionary) -> String:
	var distance: float = best["distance"]
	var turns: int = best["turns"]
	if distance <= 0.0 and turns == 0:
		return ""
	return "Best: %s, %d turns" % [Hud.distance_text(distance), turns]


## The bests of an area, from an entry of SaveData.atlas.
static func area_text(entry: Dictionary) -> String:
	var distance: float = entry["best_distance"]
	var turns: int = entry["best_turns"]
	return "Best distance: %s\nBest turns: %d" % [Hud.distance_text(distance), turns]
