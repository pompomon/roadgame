class_name Tunnel
extends SetPiece
## The tunnel (plan.md §3.6, IMPLEMENTATION_PLAN.md M4.4), in grey box: a block of rock over the
## run. Its roof and the two faces towards the viewer show, the +x and +y faces, and the end face
## among them has a dark mouth: the entrance on N and W runs, which are all the generator makes.
## It draws over the car (z_index 1), so as the car nears, the whole tunnel fades and the car shows
## through it (M4_PLAN.md K5). The art and the darkening CanvasModulate come with M5's art, and
## the reverb with M5's AudioDirector (M4_PLAN.md Q4).

## How far the rock reaches across the run from its centreline, in tiles.
const HALF_WIDTH := 0.55
## The mouth's half-width, in tiles, and its height, as a share of the tunnel's.
const MOUTH_HALF_WIDTH := 0.36
const MOUTH_HEIGHT := 0.8

@onready var _roof: Polygon2D = %Roof
@onready var _face_x: Polygon2D = %FaceX
@onready var _face_y: Polygon2D = %FaceY
@onready var _mouth: Polygon2D = %Mouth


func _build() -> void:
	var box := grown(HALF_WIDTH - 0.5, 0.0)
	var height := Tuning.TUNNEL_HEIGHT_PX
	_roof.polygon = corners(box, height)
	_face_x.polygon = face(Vector2(box.end.x, box.position.y), box.end, 0.0, height)
	_face_y.polygon = face(Vector2(box.position.x, box.end.y), box.end, 0.0, height)
	# The end face that shows is the one at the far end of the run's axis.
	var centre := rect.get_center()
	var mouth := Vector2(MOUTH_HALF_WIDTH, 0.0)
	var end := Vector2(centre.x, box.end.y)
	if axis() == Vector2.AXIS_X:
		mouth = Vector2(0.0, MOUTH_HALF_WIDTH)
		end = Vector2(box.end.x, centre.y)
	_mouth.polygon = face(end - mouth, end + mouth, 0.0, height * MOUTH_HEIGHT)
	_fade()


func _physics_process(_delta: float) -> void:
	_fade()


## The tunnel's opacity with the car `distance` tiles from the run: SEE_THROUGH on it and up to
## FADE_NEAR away, opaque from FADE_FAR on.
static func opacity(distance: float) -> float:
	var t := smoothstep(Tuning.TUNNEL_FADE_NEAR, Tuning.TUNNEL_FADE_FAR, distance)
	return lerpf(Tuning.TUNNEL_SEE_THROUGH, 1.0, t)


func _fade() -> void:
	modulate.a = opacity(car_distance())
