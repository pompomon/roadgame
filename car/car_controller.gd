class_name CarController
extends Node2D
## Steps a CarSim every physics frame with the InputRouter's steering, and draws it
## (IMPLEMENTATION_PLAN.md M2.4). Its body is a frame of the car's sheet (docs/M5.md §5.7): the
## nearest of 16 directions, in the row of its wheels' phase as they roll (VISUALS_PLAN.md
## §5.1), or after a crash the wreck, which smokes (M3.3). Dust flies while the car is off the
## road. It lives under World/Props, which y-sorts it. It sets its position and its
## body's frame every frame, so a disaster may change only its scale, modulate and rotation
## (docs/M3.md J3, docs/M4.md K19).

## Sprite frames: the screen directions the car can face, clockwise from straight up.
const FRAMES := 16
## The wreck's frame, after the directions.
const WRECK_FRAME := FRAMES
## The rows of the sheet: the wheels' phases, a quarter turn apart. Every row has each frame, with
## the same silhouette: only the wheels' hubs differ.
const PHASES := 4
## The size of a frame of the car's sheet, and where in it the car's ground centre is.
const FRAME_SIZE := Vector2i(36, 28)
const FOOT := Vector2i(18, 18)

var sim: CarSim
var input: InputRouter

## How far the car has driven, in tiles, within a turn of its wheels: PHASES phases.
var _rolled := 0.0

@onready var _body: Sprite2D = %Body
@onready var _dust: CPUParticles2D = %Dust
@onready var _smoke: CPUParticles2D = %Smoke


func _ready() -> void:
	_update_view()


func _physics_process(delta: float) -> void:
	sim.step(delta, input.steer())
	_rolled = fposmod(_rolled + sim.speed * delta, Tuning.WHEEL_ROLL_TILES * PHASES)
	_update_view()


## The frame for heading `forward`, in tile space: the nearest of FRAMES screen directions.
static func frame(forward: Vector2) -> int:
	var screen := Iso.tile_to_world(forward)
	return posmod(roundi(atan2(screen.x, -screen.y) / (TAU / FRAMES)), FRAMES)


## The row of the sheet that shows the wheels after the car has driven `rolled` tiles: the next
## each WHEEL_ROLL_TILES.
static func phase(rolled: float) -> int:
	return posmod(floori(rolled / Tuning.WHEEL_ROLL_TILES), PHASES)


## A new sprite of the car as it shows now, for a legend to take in its place (docs/M6.md §5.4):
## the body's frame, cut from its sheet, with the car's ground centre at the sprite's origin.
func double() -> Sprite2D:
	var made := Sprite2D.new()
	made.name = "Double"
	made.texture = _body.texture
	made.centered = false
	made.offset = -Vector2(FOOT)
	made.region_enabled = true
	made.region_rect = Rect2(Vector2(_body.frame_coords * FRAME_SIZE), Vector2(FRAME_SIZE))
	return made


## The car's sheet, and the frame of its first row that the body shows, which its shadow shows
## too (docs/DAYNIGHT.md §5.11): every row has the same silhouette.
func body_texture() -> Texture2D:
	return _body.texture


func body_frame() -> int:
	return _body.frame_coords.x


func _update_view() -> void:
	position = Iso.tile_to_world(sim.pos)
	var crashed := sim.state == CarSim.State.CRASHED
	if crashed:
		_body.frame_coords = Vector2i(WRECK_FRAME, 0)
	else:
		_body.frame_coords = Vector2i(frame(sim.forward()), phase(_rolled))
	_dust.emitting = sim.state == CarSim.State.OFFROAD
	_smoke.emitting = crashed
