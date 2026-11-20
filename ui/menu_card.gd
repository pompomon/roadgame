class_name MenuCard
extends PanelContainer
## A postcard of the Atlas (IMPLEMENTATION_PLAN.md M5.5, docs/ENDGAME.md §5.16): a picture of its
## area, framed in the area's colour, of its ground with its tallest prop standing on it, then the
## area's name with a stamp beside it, and its bests. The stamp is whole, paper inked in the area's
## colour, once a run has crossed the area with no damage, and hollow until then, an outline in a
## grey that stands out from the card, so that the two differ by their shapes too, as the Book's
## seals do (docs/ENDGAME.md W26). An area not reached yet shows as a silhouette: a dark picture and
## no name. Nothing of it stops a finger, so a drag that starts on it scrolls the Atlas. Only a
## screen reader's focus stops on the card, which AtlasScreen names.

## How far above the picture's bottom edge the prop's foot stands, in pixels: a tallest prop, the
## smoky house's 70, stands whole in the ground inside the picture's frame.
const PROP_RISE := 6

## Whether the stamp is whole.
var stamped := false

@onready var _swatch: ColorRect = %Swatch
@onready var _ground: TextureRect = %Ground
@onready var _prop: TextureRect = %Prop
@onready var _title: Label = %Title
@onready var _paper: ColorRect = %Paper
@onready var _ink: ColorRect = %Ink
@onready var _hollow: Control = %Hollow
@onready var _details: Label = %Details


## Shows `title` over `details`, under a picture framed in `color` of `area`'s ground and tallest
## prop, or of nothing without an area. The stamp is whole if `p_stamped`, inked in `color`. The
## card must be in the tree.
func show_entry(
	title: String, details: String, color: Color, area: AreaDef = null, p_stamped := false
) -> void:
	_swatch.color = color
	_title.text = title
	_details.text = details
	_ground.texture = area.ground if area != null else null
	var prop := tallest_prop(area) if area != null else null
	_prop.texture = frame_of(prop) if prop != null else null
	if prop != null:
		_prop.offset_left = -prop.foot.x
		_prop.offset_top = -PROP_RISE - prop.foot.y
		_prop.offset_right = _prop.offset_left + prop.region.size.x
		_prop.offset_bottom = _prop.offset_top + prop.region.size.y
	stamped = p_stamped
	_ink.color = color
	_paper.visible = p_stamped
	_hollow.visible = not p_stamped


## The prop of `area` whose frame is the tallest, the first of those as tall, or null for none.
static func tallest_prop(area: AreaDef) -> PropDef:
	var tallest: PropDef = null
	for prop: PropDef in area.props:
		if tallest == null or prop.region.size.y > tallest.region.size.y:
			tallest = prop
	return tallest


## The first frame of `prop`, from its sheet.
static func frame_of(prop: PropDef) -> AtlasTexture:
	var frame := AtlasTexture.new()
	frame.atlas = prop.texture
	frame.region = Rect2(prop.region)
	return frame
