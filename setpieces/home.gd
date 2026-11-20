class_name Home
extends SetPiece
## Home (docs/ENDGAME.md §5.8), in grey box, where the Road Home ends: its tiles draw as road, a
## drive (GreyboxAtlas.road_coords()); a garden fence crosses its end, with a gate where the drive
## meets it, and a house stands past it, in the City's palette. The house's faces towards the viewer
## show, its +x and +y faces, as the tunnel's do, and its door is in the one that faces the drive.
## All of it stands past the drive's last tile, where the road draws nothing and no prop stands
## (PropLayout.near_set_piece()), and where the car never goes, so it draws under the car. The path
## heads only N or W.

## The fence: how far it reaches across the drive's line either way, in tiles, which keeps it
## within PropLayout.set_piece_margin(), and how tall it is, in screen pixels. The gate is as wide
## as the road, and taller.
const FENCE_HALF_LENGTH := 2.0
const FENCE_PX := 8.0
const GATE_HALF_WIDTH := Tuning.ROAD_HALF_WIDTH
const GATE_PX := 12.0
## The house: how far past the fence it starts and how long each side is, in tiles, and how tall
## its walls are and its roof's top above them, in screen pixels. Its door is DOOR_HALF_WIDTH tiles
## either side of the drive's line, and DOOR_PX tall.
const HOUSE_GAP := 0.4
const HOUSE_SIDE := 1.5
const WALL_PX := 28.0
const ROOF_PX := 22.0
const DOOR_HALF_WIDTH := 0.15
const DOOR_PX := 16.0

## The house's footprint, in tile space.
var house := Rect2()

@onready var _fence: Polygon2D = %Fence
@onready var _gate: Polygon2D = %Gate
@onready var _face_x: Polygon2D = %FaceX
@onready var _face_y: Polygon2D = %FaceY
@onready var _door: Polygon2D = %Door
@onready var _roof_back: Polygon2D = %RoofBack
@onready var _roof_front: Polygon2D = %RoofFront


func _build() -> void:
	var end := run_length()
	_fence.polygon = face(
		point(end, -FENCE_HALF_LENGTH), point(end, FENCE_HALF_LENGTH), 0.0, FENCE_PX
	)
	_gate.polygon = face(point(end, -GATE_HALF_WIDTH), point(end, GATE_HALF_WIDTH), 0.0, GATE_PX)
	var front := end + HOUSE_GAP
	var half := HOUSE_SIDE * 0.5
	house = span(front, front + HOUSE_SIDE, -half, half)
	_face_x.polygon = face(Vector2(house.end.x, house.position.y), house.end, 0.0, WALL_PX)
	_face_y.polygon = face(Vector2(house.position.x, house.end.y), house.end, 0.0, WALL_PX)
	_door.polygon = face(
		point(front, -DOOR_HALF_WIDTH), point(front, DOOR_HALF_WIDTH), 0.0, DOOR_PX
	)
	# The roof rises from the walls' tops to a point over the middle: its back half shows above its
	# front half.
	var eaves := corners(house, WALL_PX)
	var top := Iso.tile_to_world(house.get_center()) + Vector2(0.0, -WALL_PX - ROOF_PX)
	_roof_back.polygon = PackedVector2Array([eaves[3], eaves[0], eaves[1], top])
	_roof_front.polygon = PackedVector2Array([eaves[3], top, eaves[1], eaves[2]])
