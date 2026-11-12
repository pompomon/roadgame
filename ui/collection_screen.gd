class_name CollectionScreen
extends MenuScreen
## The disaster collection (plan.md §2.6, IMPLEMENTATION_PLAN.md M5.5): a card for each disaster in
## the pools of the schedule's areas, in the order a run can first meet them. A card tells how often
## the disaster was seen, where and how far into a run it was seen first, and its lore (M6_PLAN.md
## S12); one never seen is a silhouette. Like the HUD, its text uses only characters in the game's
## font.

const CARD_SCENE := preload("res://ui/menu_card.tscn")
## The name of a disaster never seen, and its card's text and swatch.
const UNKNOWN := "???"
const NOT_SEEN := "Not seen yet"
const SILHOUETTE := Color(0.1, 0.1, 0.12)

@onready var _cards: VBoxContainer = %Cards
@onready var _back: Button = %Back


func _ready() -> void:
	_back.pressed.connect(back_requested.emit)


## Shows the collection in `data` of the disasters of `schedule`.
func open(data: SaveData, schedule: AreaSchedule) -> void:
	for card: Node in _cards.get_children():
		card.free()
	for disaster: Dictionary in disasters(schedule):
		var card: MenuCard = CARD_SCENE.instantiate()
		_cards.add_child(card)
		var entry: Dictionary = data.disasters.get(String(disaster["id"]), SaveData.DISASTER_ENTRY)
		var seen: int = entry["seen"]
		if seen > 0:
			var area := _find_area(schedule, entry["first_area"])
			var color := area.id_color if area != null else SILHOUETTE
			card.show_entry(disaster["name"], seen_text(entry, area), color, disaster["lore"])
		else:
			card.show_entry(UNKNOWN, NOT_SEEN, SILHOUETTE)
	show()
	_back.grab_focus()


## The id, the display name and the lore of each disaster in the pools of `schedule`'s areas, each
## once, in the order of the areas: [{"id": StringName, "name": String, "lore": String}].
static func disasters(schedule: AreaSchedule) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var scenes: Array[PackedScene] = []
	for area: AreaDef in schedule.areas():
		for scene: PackedScene in area.disasters:
			if scenes.has(scene):
				continue
			scenes.append(scene)
			var node: Node = scene.instantiate() if scene.can_instantiate() else null
			var disaster := node as DisasterBase
			if disaster != null:
				found.append(
					{"id": disaster.id, "name": disaster.display_name, "lore": disaster.lore}
				)
			else:
				push_error("CollectionScreen: %s isn't a disaster" % scene.resource_path)
			if node != null:
				node.free()
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


static func _find_area(schedule: AreaSchedule, id: String) -> AreaDef:
	for area: AreaDef in schedule.areas():
		if String(area.id) == id:
			return area
	return null
