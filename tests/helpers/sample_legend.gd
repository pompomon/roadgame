extends Legend
## A legend that uses every part of the kit (docs/M6.md §4 PR 2). The contract tests play it with
## the pools' disasters, and test_legend.gd checks the kit with it. A totem stands on the stage and
## opens its eyes, a ring grows on the ground, sparks fly, and a night veil falls. Then it takes the
## car: the car's double rises, shrinks and fades. Two glows that overlap pulse together, and a red
## glow lights once. Its totem's sheet is drawn by tools/art/legend_art.gd as it starts, so that
## assets/ holds only the game's art. Its numbers are its own, not Tuning's: no pool has it. No
## class_name: tests/ is not exported.

const LegendArt := preload("res://tools/art/legend_art.gd")
## Its beats, in s: the totem rises; it takes the car; the car goes; a hold. The glows pulse
## through the middle two.
const BEATS: Array[float] = [0.5, 0.5, 0.5, 0.5]
const TOTEM_FRAME := Vector2i(16, 32)
const TOTEM_FRAMES := 3
## The ring's radius, in tiles.
const RING_RADIUS := 1.2
## How far the double rises, in px.
const LIFT := 24.0
## The glows' pulses: how many a second, the share of a period that a pulse lasts, how many s GlowB
## lags GlowA, and their light at a pulse's peak. Short pulses add up where the glows overlap, even
## half a period apart.
const PULSE_HZ := 2.0
const PULSE_DUTY := 0.4
const PULSE_LAG := 0.0
const PULSE_ALPHA := 0.8
## How many times the red glow lights and goes out over the middle two beats, and its light.
const RED_PULSES := 1
const RED_ALPHA := 0.6

var _taken := false
var _double: Sprite2D

@onready var _totem: Sprite2D = %Totem
@onready var _ring: Polygon2D = %Ring
@onready var _sparks: CPUParticles2D = %Sparks
@onready var _glow_a: Sprite2D = %GlowA
@onready var _glow_b: Sprite2D = %GlowB
@onready var _red: Sprite2D = %RedGlow


static func duration(params: DisasterParams) -> float:
	return params.delay + Beats.total(BEATS)


## The totem's sheet: a pole with a roof and a face, whose eyes open over its frames. It draws with
## each of legend_art.gd's helpers.
static func sheet() -> Image:
	var art := LegendArt.new(TOTEM_FRAME, TOTEM_FRAMES)
	var roof: Array[Vector2] = [Vector2(-7, -26), Vector2(7, -26), Vector2(0, -31)]
	for k: int in TOTEM_FRAMES:
		art.frame = k
		art.rect(Rect2i(-4, -26, 8, 26), "plank")
		art.poly(roof, "violet")
		art.ellipse(Vector2(0, -8), Vector2(3, 2), "night")
		art.line(Vector2(-3, -14), Vector2(2, -14), "ink")
		for side: int in [-3, 1]:
			art.rect(Rect2i(side, -21 + (TOTEM_FRAMES - 1 - k), 2, k), "wisp")
			art.plot(Vector2i(side, -21 + TOTEM_FRAMES - 1), "lilac")
		art.outline()
	return art.image


func _ready() -> void:
	super()
	_totem.texture = ImageTexture.create_from_image(sheet())
	_ring.polygon = outline(RING_RADIUS)


func _beats() -> Array[float]:
	return BEATS


func _pose(beat: int, t: float) -> void:
	match beat:
		0:
			_totem.modulate.a = t
			_totem.frame = mini(floori(t * TOTEM_FRAMES), TOTEM_FRAMES - 1)
			_ring.scale = Vector2.ONE * t
			_sparks.emitting = true
		1:
			if not _taken:
				_taken = true
				_double = take_car()
			if _double != null:
				_double.offset.y = -CarController.FOOT.y - LIFT * t
			_pulse(t * BEATS[1])
		2:
			if _double != null:
				_double.scale = Vector2.ONE * (1.0 - t)
				_double.modulate.a = 1.0 - t
			_sparks.emitting = false
			_pulse(BEATS[1] + t * BEATS[2])
		_:
			_pulse(BEATS[1] + BEATS[2])


## The glows' light `time` s into the middle two beats.
func _pulse(time: float) -> void:
	_glow_a.modulate.a = PULSE_ALPHA * _bump(time * PULSE_HZ)
	_glow_b.modulate.a = PULSE_ALPHA * _bump((time - PULSE_LAG) * PULSE_HZ)
	var share := clampf(time / (BEATS[1] + BEATS[2]), 0.0, 1.0)
	_red.modulate.a = RED_ALPHA * (0.5 - 0.5 * cos(TAU * RED_PULSES * share))


## A pulse at the start of each period: up and down in PULSE_DUTY of it, then dark.
static func _bump(phase: float) -> float:
	if phase < 0.0:
		return 0.0
	var part := fposmod(phase, 1.0) / PULSE_DUTY
	return 1.0 - absf(2.0 * part - 1.0) if part < 1.0 else 0.0
