class_name MenuCard
extends HBoxContainer
## A card of the Atlas or the disaster collection (IMPLEMENTATION_PLAN.md M5.5): a swatch, a name,
## and a few lines under it. Something not found yet shows as a silhouette: a dark swatch and no
## name.

@onready var _swatch: ColorRect = %Swatch
@onready var _title: Label = %Title
@onready var _details: Label = %Details


## Shows `title` over `details`, by a swatch of `color`. The card must be in the tree.
func show_entry(title: String, details: String, color: Color) -> void:
	_swatch.color = color
	_title.text = title
	_details.text = details
