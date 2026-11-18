class_name BookCell
extends Button
## A cell of the Book of Legends (ENDGAME_PLAN.md §5.10): a legend's still, over a band with its
## name, or its initials, and a note. BookScreen fills it. Only a found legend's cell takes the
## focus and a tap, which opens its page. The still and the band stay inside the button's border,
## which shows the focus. A still larger than the cell's art is shown smaller, divided by the least
## whole number that makes it fit, so that its pixels stay square, as LegendStill's do. A glow's
## still adds no more light than the cell's lightest style leaves below white (docs/M6.md S10).

## The theme's styles that a found cell draws under its still: its state's, and its focus's over it.
const GROUND_STYLES: Array[StringName] = [&"normal", &"hover", &"pressed", &"focus"]

## The legend's scene, and its words, as BookScreen.disasters() gives them.
var scene: PackedScene
var legend := {}
## Whether the legend is found: seen, or unlocked by an arrival.
var found := false
## Its page's words: [details, fate, lore]; none if it isn't found.
var page := PackedStringArray()

## The still's own scale, before the cell fits it.
var _still_scale := Vector2.ONE

@onready var _art: Control = %Art
@onready var _pivot: Control = %Pivot
@onready var _name: Label = %Name
@onready var _note: Label = %Note


func _ready() -> void:
	_art.resized.connect(_fit)


## Shows `p_still`, unless it's null, over `p_text` and `note`, unless it's "". A glow's still shows
## as much of its light as ground() leaves (LegendStill.strength()). Only a cell whose legend is
## `p_found` takes the focus and a tap. The cell must be in the tree.
func show_legend(p_still: LegendStill, p_text: String, note: String, p_found: bool) -> void:
	for child: Node in _pivot.get_children():
		child.free()
	if p_still != null:
		_still_scale = p_still.scale
		p_still.self_modulate.a *= p_still.strength(ground())
		_pivot.add_child(p_still)
		_fit()
	_name.text = p_text
	_note.text = note
	_note.visible = note != ""
	found = p_found
	disabled = not found
	focus_mode = FOCUS_ALL if found else FOCUS_NONE


## The still that the cell shows, or null.
func still() -> LegendStill:
	return _pivot.get_child(0) as LegendStill if _pivot.get_child_count() > 0 else null


## The colour under the still at its lightest, channel by channel: the centre of each of
## GROUND_STYLES that draws one. The theme's are flat and opaque (ui/theme.tres), and the still
## stays inside their borders.
func ground() -> Color:
	var lightest := Color.BLACK
	for style_name: StringName in GROUND_STYLES:
		var flat := get_theme_stylebox(style_name) as StyleBoxFlat
		if flat != null and flat.draw_center:
			for channel: int in 3:
				lightest[channel] = maxf(lightest[channel], flat.bg_color[channel])
	return lightest


func _fit() -> void:
	var shown := still()
	if shown == null or _art.size.x <= 0.0 or _art.size.y <= 0.0:
		return
	var side := shown.get_rect().size * _still_scale
	var over := maxf(side.x / _art.size.x, side.y / _art.size.y)
	shown.scale = _still_scale / maxf(1.0, ceilf(over))
