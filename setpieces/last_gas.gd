class_name LastGas
extends SetPiece
## Last Gas (ENDGAME_PLAN.md §5.15), in grey box: the filling station by a pit stop's straight,
## which has no set piece of its own, as the Desert starts on the way out and the Village on the
## Road Home. It stands beside the road, not on it, on its far side, up the screen: a forecourt, a
## shack with its door and window towards the road, and a canopy over two pumps, with a sign before
## them. Their faces towards the viewer show, their +x and +y faces, as the tunnel's do: those
## towards the road and towards the straight's start. Nothing in it is lit, and nothing moves.
##
## It is as big on every straight, the shortest of which is two tiles long, and stands at the
## middle. All that it draws shows beside the straight, between its ends, so no road paints over
## it: not the straight's, nor that of the junctions at its ends, nor that of the road the next
## turns onto, which runs across its far side. And none of it shows as far from the straight as a
## prop's frame reaches, from past PropLayout.set_piece_margin() tiles of the straight, where the
## nearest props stand (PropLayout.near_set_piece()), so no prop shows over it either. The car on
## the road passes in front of it, so it draws under the car; a car off the road on its side draws
## over it too, on its way to a crash or back. The path heads only N or W.

## The parts' footprints, in tiles: x along the straight from its middle, towards its end, and y
## across it from its centreline, towards its near side, so the far side's are negative. The pumps
## and posts are listed from the straight's end, the farthest first, as they draw.
const FORECOURT := Rect2(-0.9, -1.85, 1.8, 1.45)
const SHACK := Rect2(-0.6, -1.72, 0.9, 0.4)
const ISLAND := Rect2(-0.74, -0.72, 1.18, 0.14)
const CANOPY := Rect2(-0.75, -0.85, 1.2, 0.4)
const PUMPS: Array[Rect2] = [Rect2(0.0, -0.7, 0.15, 0.1), Rect2(-0.45, -0.7, 0.15, 0.1)]
const POSTS: Array[float] = [0.4, -0.7]
const POST_HALF_WIDTH := 0.03
## The door and the window in the shack's face towards the road, along it from the straight's
## middle, in tiles, and the sign's panel and pole, across the far side at SIGN_AT along it.
const DOOR := Vector2(-0.24, -0.06)
const WINDOW := Vector2(0.02, 0.2)
const SIGN_AT := -0.85
const SIGN := Vector2(-0.78, -0.42)
const SIGN_POLE := Vector2(-0.62, -0.58)
## Heights, in screen pixels: the shack's walls, its door's top and its window's foot and top; the
## pumps', and their panels' foot and top; the canopy's underside and top; the sign panel's foot
## and top, and its band's.
const SHACK_PX := 18.0
const DOOR_PX := 12.0
const WINDOW_PX := Vector2(6.0, 13.0)
const PUMP_PX := 14.0
const PUMP_PANEL_PX := Vector2(6.0, 11.0)
const CANOPY_LOW_PX := 24.0
const CANOPY_HIGH_PX := 29.0
const SIGN_LOW_PX := 30.0
const SIGN_HIGH_PX := 44.0
const SIGN_BAND_PX := Vector2(35.0, 39.0)

## The footprints, in tile space.
var forecourt := Rect2()
var shack := Rect2()
var canopy := Rect2()

@onready var _forecourt: Polygon2D = %Forecourt
@onready var _island: Polygon2D = %Island
@onready var _shack_x: Polygon2D = %ShackX
@onready var _shack_y: Polygon2D = %ShackY
@onready var _door: Polygon2D = %Door
@onready var _window: Polygon2D = %Window
@onready var _shack_roof: Polygon2D = %ShackRoof
@onready var _end_post: Polygon2D = %EndPost
@onready var _end_pump: Polygon2D = %EndPump
@onready var _end_panel: Polygon2D = %EndPanel
@onready var _start_pump: Polygon2D = %StartPump
@onready var _start_panel: Polygon2D = %StartPanel
@onready var _start_post: Polygon2D = %StartPost
@onready var _canopy_x: Polygon2D = %CanopyX
@onready var _canopy_y: Polygon2D = %CanopyY
@onready var _canopy_top: Polygon2D = %CanopyTop
@onready var _sign_pole: Polygon2D = %SignPole
@onready var _sign_panel: Polygon2D = %SignPanel
@onready var _sign_band: Polygon2D = %SignBand


func _build() -> void:
	var middle := run_length() * 0.5
	forecourt = _footprint(FORECOURT)
	shack = _footprint(SHACK)
	canopy = _footprint(CANOPY)
	_forecourt.polygon = corners(forecourt)
	_island.polygon = corners(_footprint(ISLAND))
	_shack_x.polygon = face(Vector2(shack.end.x, shack.position.y), shack.end, 0.0, SHACK_PX)
	_shack_y.polygon = face(Vector2(shack.position.x, shack.end.y), shack.end, 0.0, SHACK_PX)
	var front := SHACK.end.y
	_door.polygon = face(point(middle + DOOR.x, front), point(middle + DOOR.y, front), 0.0, DOOR_PX)
	_window.polygon = face(
		point(middle + WINDOW.x, front), point(middle + WINDOW.y, front), WINDOW_PX.x, WINDOW_PX.y
	)
	_shack_roof.polygon = corners(shack, SHACK_PX)
	_end_post.polygon = _post(middle + POSTS[0])
	_end_pump.polygon = _pump(PUMPS[0])
	_end_panel.polygon = _panel(PUMPS[0])
	_start_pump.polygon = _pump(PUMPS[1])
	_start_panel.polygon = _panel(PUMPS[1])
	_start_post.polygon = _post(middle + POSTS[1])
	_canopy_x.polygon = face(
		Vector2(canopy.end.x, canopy.position.y), canopy.end, CANOPY_LOW_PX, CANOPY_HIGH_PX
	)
	_canopy_y.polygon = face(
		Vector2(canopy.position.x, canopy.end.y), canopy.end, CANOPY_LOW_PX, CANOPY_HIGH_PX
	)
	_canopy_top.polygon = corners(canopy, CANOPY_HIGH_PX)
	var sign_at := middle + SIGN_AT
	_sign_pole.polygon = face(
		point(sign_at, SIGN_POLE.x), point(sign_at, SIGN_POLE.y), 0.0, SIGN_LOW_PX
	)
	_sign_panel.polygon = face(
		point(sign_at, SIGN.x), point(sign_at, SIGN.y), SIGN_LOW_PX, SIGN_HIGH_PX
	)
	_sign_band.polygon = face(
		point(sign_at, SIGN.x), point(sign_at, SIGN.y), SIGN_BAND_PX.x, SIGN_BAND_PX.y
	)


## `part`, one of the footprints above, in tile space.
func _footprint(part: Rect2) -> Rect2:
	var middle := run_length() * 0.5
	return span(middle + part.position.x, middle + part.end.x, part.position.y, part.end.y)


## A pump on `part`, a box that shows as one shape: its top's back corners, then its foot's front
## ones.
func _pump(part: Rect2) -> PackedVector2Array:
	var box := _footprint(part)
	var foot := corners(box)
	var top := corners(box, PUMP_PX)
	return PackedVector2Array([top[0], top[1], foot[1], foot[2], foot[3], top[3]])


## The panel in the face towards the road of the pump on `part`.
func _panel(part: Rect2) -> PackedVector2Array:
	var middle := run_length() * 0.5
	var inset := part.size.x * 0.2
	return face(
		point(middle + part.position.x + inset, part.end.y),
		point(middle + part.end.x - inset, part.end.y),
		PUMP_PANEL_PX.x,
		PUMP_PANEL_PX.y
	)


## A post of the canopy, `ahead` tiles along the straight, under the canopy's middle.
func _post(ahead: float) -> PackedVector2Array:
	var across := CANOPY.get_center().y
	return face(
		point(ahead - POST_HALF_WIDTH, across),
		point(ahead + POST_HALF_WIDTH, across),
		0.0,
		CANOPY_LOW_PX
	)
