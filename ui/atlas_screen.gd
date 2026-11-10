class_name AtlasScreen
extends MenuScreen
## The Atlas (plan.md §2.6, IMPLEMENTATION_PLAN.md M5.5): the bests, and a card for each area
## of the schedule, in the order a run reaches them. An area that no run has reached is a
## silhouette. A card's bests are the most distance and the most turns a run made in that area
## (M5_PLAN.md L8). Like the HUD, its text uses only characters in Godot's default font.

const CARD_SCENE := preload("res://ui/menu_card.tscn")
## The name of an area that no run has reached, and its card's text and swatch.
const UNKNOWN := "???"
const NOT_REACHED := "Not reached yet"
const SILHOUETTE := Color(0.1, 0.1, 0.12)

@onready var _best: Label = %Best
@onready var _cards: VBoxContainer = %Cards
@onready var _back: Button = %Back


func _ready() -> void:
	_back.pressed.connect(back_requested.emit)


## Shows the atlas in `data` of the areas of `schedule`.
func open(data: SaveData, schedule: AreaSchedule) -> void:
	_best.text = best_text(data.best)
	for card: Node in _cards.get_children():
		card.free()
	for area: AreaDef in schedule.areas():
		var card: MenuCard = CARD_SCENE.instantiate()
		_cards.add_child(card)
		var entry: Dictionary = data.atlas.get(String(area.id), SaveData.ATLAS_ENTRY)
		if entry["discovered"]:
			card.show_entry(area.display_name, area_text(entry), area.id_color)
		else:
			card.show_entry(UNKNOWN, NOT_REACHED, SILHOUETTE)
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
