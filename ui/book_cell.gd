class_name BookCell
extends Button
## A cell of the Book of Legends (ENDGAME_PLAN.md §5.10): a legend's still, over a band with its
## name, or its initials, and a note. BookScreen fills it. Only a found legend's cell takes the
## focus and a tap, which opens its page. The still and the band stay inside the button's border,
## which shows the focus. A still larger than the cell's art is shown smaller, divided by the least
## whole number that makes it fit, so that its pixels stay square, as LegendStill's do. A glow's
## still adds no more light than the cell's lightest style leaves below white (docs/M6.md S10). A
## word of the name too wide for the cell breaks after a hyphen (break_hyphens()).

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
## The name or the initials that the cell shows, before break_hyphens().
var _name_text := ""

@onready var _art: Control = %Art
@onready var _pivot: Control = %Pivot
@onready var _name: Label = %Name
@onready var _note: Label = %Note


func _ready() -> void:
	_art.resized.connect(_fit)
	_name.resized.connect(_wrap_name)


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
	_name_text = p_text
	_wrap_name()
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
		var box := get_theme_stylebox(style_name) as StyleBoxFlat
		if box != null and box.draw_center:
			for channel: int in 3:
				lightest[channel] = maxf(lightest[channel], box.bg_color[channel])
	return lightest


## `p_text`, with a line break in each word too wide for `width` in `font` at `font_size`: after its
## last hyphen up to which it fits, and so on in the rest of the word while one is too wide and has
## such a hyphen. Exported builds lack the text server's line-break rules: their labels break a line
## only at a space, and cut a word too wide where it overflows, as "Will-o'-the-Wi" over "sp"
## (ENDGAME_PLAN.md W25).
static func break_hyphens(p_text: String, font: Font, font_size: int, width: float) -> String:
	var words := p_text.split(" ")
	for i: int in words.size():
		var lines := PackedStringArray()
		var rest := words[i]
		while _width_of(rest, font, font_size) > width:
			var cut := _hyphen_cut(rest, font, font_size, width)
			if cut < 0:
				break
			lines.append(rest.left(cut + 1))
			rest = rest.substr(cut + 1)
		lines.append(rest)
		words[i] = "\n".join(lines)
	return " ".join(words)


## The index of the last hyphen in `word`, but for its first and last characters, up to which `word`
## fits `width`; -1 if there is none.
static func _hyphen_cut(word: String, font: Font, font_size: int, width: float) -> int:
	for at: int in range(word.length() - 2, 0, -1):
		if word[at] == "-" and _width_of(word.left(at + 1), font, font_size) <= width:
			return at
	return -1


static func _width_of(line: String, font: Font, font_size: int) -> float:
	return font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


## Shows the name, broken to fit the width that the label wraps text in: its own, less its style's
## margins. A resize shows it again. Before the cell is laid out, no part of a word fits, and the
## name shows whole.
func _wrap_name() -> void:
	var width := _name.size.x - _name.get_theme_stylebox(&"normal").get_minimum_size().x
	var font := _name.get_theme_font(&"font")
	_name.text = break_hyphens(_name_text, font, _name.get_theme_font_size(&"font_size"), width)


func _fit() -> void:
	var shown := still()
	if shown == null or _art.size.x <= 0.0 or _art.size.y <= 0.0:
		return
	var side := shown.get_rect().size * _still_scale
	var over := maxf(side.x / _art.size.x, side.y / _art.size.y)
	shown.scale = _still_scale / maxf(1.0, ceilf(over))
