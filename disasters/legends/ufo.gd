class_name Ufo
extends Legend
## Rural's legend (docs/M6.md §3.3, Q2): night falls over the fields, and a dark saucer drops
## without a sound and hovers over the car. The lights round its rim come on and turn, and a cone of
## cold light falls on the car, with sparkles rising in it. Three tall grey figures stand at its
## edge. The car's double shudders, then floats up the beam, turning, and is gone into the saucer,
## and the figures tilt their heads. The lights go out and the beam closes, the figures are gone,
## and the dark saucer zips off, leaving a crop circle where the car stood. Its lights come on only
## once it hovers and go out before it zips: lights that moved would pass the same points again and
## again (§5.6). tools/art/legends/ufo.gd draws its sheets with these constants.

## The saucer's sheet: one frame, its foot at the middle of its underside, which hovers HOVER px
## over the car's ground point.
const SAUCER := Vector2i(56, 24)
const HOVER := 64
## The lights round its rim: LIGHTS of them, on an ellipse of RIM_RADII px about RIM_CENTRE from
## the saucer's foot. Their sheet, a glow over the saucer's frame, has RIM_FRAMES frames for each
## light's step to the next.
const LIGHTS := 8
const RIM_CENTRE := Vector2(0.0, -9.0)
const RIM_RADII := Vector2(23.0, 4.0)
const RIM_FRAMES := 4
## The beam falls from the port under the saucer, PORT px wide, to a pool of light of POOL px radii
## about the car's ground point.
const PORT := 12
const POOL := Vector2(22.0, 11.0)
## The greys' sheet: frames of GREY px, facing, then with the head tilted.
const GREY := Vector2i(12, 32)
## The crop circle's sheet, centred on the car's ground point.
const CROP_CIRCLE := Vector2i(64, 32)
## The shares: of its drop that it takes to show; of the beam beat that the beam takes to open, and
## at its end that the greys take to show; of the lift that the double shudders for, and at its end
## that it takes to go into the saucer; and of the zip that the lights and the beam take to go out.
const SHOW_SHARE := 0.5
const OPEN_SHARE := 0.5
const GREYS_SHARE := 0.25
const SHUDDER_SHARE := 0.25
const ENTER_SHARE := 0.25
const CLOSE_SHARE := 0.3
## The share of its width that the beam is shut at, or under: Node2D stores a zero scale as
## CMP_EPSILON (scene/2d/node_2d.cpp, set_scale), so the beam is clear then, or it would still be a
## sliver of light.
const SLIVER := 1e-4
## The double's shudder: how far each way, in px, and how many times it moves; its turns as it
## floats up, and its scale once it's in the saucer.
const SHUDDER_PX := 1.0
const SHUDDER_STEPS := 6
const TURNS := 1
const ENTERED_SCALE := 0.4

## Where the saucer hovers and where it zips to, from the legend's origin.
var _hover := Vector2.ZERO
var _zip_to := Vector2.ZERO
var _taken := false
var _double: Sprite2D
## The double's frame when it took the car's place.
var _first := 0

@onready var _saucer: Sprite2D = %Saucer
@onready var _rim: Sprite2D = %Rim
@onready var _beam: Sprite2D = %Beam
@onready var _sparkles: CPUParticles2D = %Sparkles
@onready var _crop_circle: Sprite2D = %CropCircle


static func duration(params: DisasterParams) -> float:
	return params.delay + Beats.total(Tuning.UFO_BEATS)


## Where it zips to from its hover: up, and to the side of the screen that `direction`, in tile
## space, points to, or to the right for none.
static func zip(direction: Vector2) -> Vector2:
	var side := 1.0 if Iso.tile_to_world(direction).x >= 0.0 else -1.0
	return Vector2(side * Tuning.UFO_ZIP_PX.x, Tuning.UFO_ZIP_PX.y)


## The frame of its rim's lights `seconds` after they came on.
static func rim_frame(seconds: float) -> int:
	return posmod(floori(seconds * Tuning.UFO_RIM_HZ * RIM_FRAMES), RIM_FRAMES)


## The size of the beam's sheet: from the port down to the bottom of its pool.
static func beam_size() -> Vector2i:
	return Vector2i(2 * ceili(POOL.x), HOVER + ceili(POOL.y))


func play(params: DisasterParams) -> void:
	super(params)
	_hover = Vector2(0.0, -HOVER)
	_zip_to = _hover + zip(params.direction)
	_saucer.position = _hover - Vector2(0.0, Tuning.UFO_DROP_PX)


func _beats() -> Array[float]:
	return Tuning.UFO_BEATS


func _pose(beat: int, t: float) -> void:
	var beats := Tuning.UFO_BEATS
	match beat:
		1:
			var fallen := 1.0 - (1.0 - t) * (1.0 - t)
			_saucer.position = _hover - Vector2(0.0, Tuning.UFO_DROP_PX * (1.0 - fallen))
			_saucer.modulate.a = minf(t / SHOW_SHARE, 1.0)
		2:
			_open(minf(t / OPEN_SHARE, 1.0))
			_rim.frame = rim_frame(t * beats[2])
			_sparkles.emitting = true
			_show_greys(clampf((t - 1.0 + GREYS_SHARE) / GREYS_SHARE, 0.0, 1.0), 0)
		3:
			_rim.frame = rim_frame(beats[2] + t * beats[3])
			_lift(t)
			_show_greys(1.0, 1 if t >= SHUDDER_SHARE else 0)
		4:
			_rim.frame = rim_frame(beats[2] + beats[3] + t * beats[4])
			_open(1.0 - minf(t / CLOSE_SHARE, 1.0))
			_sparkles.emitting = false
			var gone := clampf((t - CLOSE_SHARE) / (1.0 - CLOSE_SHARE), 0.0, 1.0)
			if t >= CLOSE_SHARE:
				_show_greys(0.0, 1)
			_saucer.position = _hover.lerp(_zip_to, gone * gone)
			_saucer.modulate.a = 1.0 - gone
			_crop_circle.modulate.a = gone


## Opens the beam to `share` of its width, and lights the rim as much. Shut, the beam is clear too.
func _open(share: float) -> void:
	_beam.scale.x = share
	_beam.modulate.a = Tuning.UFO_BEAM_ALPHA if share > SLIVER else 0.0
	_rim.modulate.a = share


## Shows the greys, which stand on the stage, `alpha` of the way, in `frame`.
func _show_greys(alpha: float, frame: int) -> void:
	for grey: Sprite2D in standing:
		grey.modulate.a = alpha
		grey.frame = frame


## The car's double shudders where the car stopped, then floats up the beam, turning through its
## headings, and goes into the port under the saucer, shrinking and fading, `t` of the lift done.
## Its foot stays where the car stopped, so it sorts there.
func _lift(t: float) -> void:
	if not _taken:
		_taken = true
		_double = take_car()
		if _double != null:
			_first = roundi(_double.region_rect.position.x / CarController.FRAME_SIZE.x)
	if _double == null:
		return
	var size := Vector2(CarController.FRAME_SIZE)
	var shake := 0.0
	if t < SHUDDER_SHARE:
		var step := floori(t / SHUDDER_SHARE * SHUDDER_STEPS)
		shake = SHUDDER_PX if step % 2 == 0 else -SHUDDER_PX
	var up := smoothstep(0.0, 1.0, clampf((t - SHUDDER_SHARE) / (1.0 - SHUDDER_SHARE), 0.0, 1.0))
	var going := clampf((up - 1.0 + ENTER_SHARE) / ENTER_SHARE, 0.0, 1.0)
	var shrink := lerpf(1.0, ENTERED_SCALE, going)
	# Its middle rises from where the car's was to the port, and its offset keeps it there as it
	# shrinks about its foot.
	var middle := lerpf(CarController.FOOT.y - size.y / 2.0, HOVER, up)
	_double.scale = Vector2.ONE * shrink
	_double.offset = Vector2(shake / shrink - size.x / 2.0, -middle / shrink - size.y / 2.0)
	_double.modulate.a = 1.0 - going
	var frame := posmod(_first + roundi(TURNS * CarController.FRAMES * up), CarController.FRAMES)
	_double.region_rect.position.x = size.x * frame
