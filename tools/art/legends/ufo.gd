extends RefCounted
## The UFO's sheets (docs/M6.md §3.3), drawn into assets/legends/ufo/ by
## tools/art/make_legends.gd. `saucer.png`: a dark saucer, a dome with dark windows on a disc whose
## rim catches the light, and the port under it. `rim.png`: the lights round its rim, a glow over
## the saucer's frame, in a frame for each quarter of a light's step to the next. `beam.png`: the
## cone of light from the port down to its pool on the ground, a glow, brighter at its core.
## `grey.png`: a tall grey figure with long arms, a big head and big dark eyes, lit by the beam on
## its right, facing, then with its head tilted to the beam. `crop_circle.png`: the rings scorched
## into the field. Their sizes are the legend's (disasters/legends/ufo.gd). Glows are drawn in white
## and grey, which their tint colours. The light comes from the upper left, as on the car. No
## class_name: tools/ is not exported.

const LegendArt := preload("res://tools/art/legend_art.gd")
const UfoLegend := preload("res://disasters/legends/ufo.gd")
## The disc's radii, in px, about the rim's centre; the dome's centre, from the rim's, and radii.
const DISC := Vector2(26.5, 6.0)
const DOME := Vector2(0.0, -6.0)
const DOME_RADII := Vector2(10.0, 6.5)
## Rim lights on its far half, where the sine of their angle is under RIM_BACK, are behind the
## saucer. There they would light pixels at the rim's ends that the near half's lights light too,
## twice a turn: those would flash at twice UFO_RIM_HZ (test_ufo.gd).
const RIM_BACK := 0.0
## How far in the beam's core is from its edge: at the port, and on the ground.
const CORE_IN := Vector2(2.0, 6.0)
## A grey: where its neck is, from its foot; its skull's centre, from the neck, and radii; its chin,
## from the neck, either side of the middle; and its tilt, in radians.
const NECK := Vector2(0.0, -22.0)
const HEAD := Vector2(0.0, -5.5)
const HEAD_RADII := Vector2(4.5, 4.0)
const CHIN := Vector2(1.0, 0.0)
const TILT := 0.35
## The crop circle's rings: the outer radii and the width of each, in px across; the satellites'
## distance out, as a share of the outer ring's radii, and radii.
const RINGS: Array[Vector2] = [Vector2(31.5, 2.0), Vector2(20.0, 2.0)]
const MIDDLE := Vector2(7.0, 3.5)
const SATELLITE_AT := 0.78
const SATELLITE := Vector2(3.0, 1.5)


static func make(dir: String) -> void:
	var saucer := LegendArt.new(UfoLegend.SAUCER)
	_draw_saucer(saucer)
	saucer.save(dir.path_join("saucer.png"))
	var rim := LegendArt.new(UfoLegend.SAUCER, UfoLegend.RIM_FRAMES)
	for frame: int in UfoLegend.RIM_FRAMES:
		rim.frame = frame
		_draw_rim(rim, float(frame) / UfoLegend.RIM_FRAMES)
	rim.save(dir.path_join("rim.png"))
	var beam := LegendArt.new(UfoLegend.beam_size())
	_draw_beam(beam)
	beam.save(dir.path_join("beam.png"))
	var grey := LegendArt.new(UfoLegend.GREY, 2)
	for frame: int in 2:
		grey.frame = frame
		_draw_grey(grey, TILT * frame)
	grey.save(dir.path_join("grey.png"))
	var circle := LegendArt.new(UfoLegend.CROP_CIRCLE)
	_draw_crop_circle(circle)
	circle.save(dir.path_join("crop_circle.png"))


static func _draw_saucer(art: LegendArt) -> void:
	var rim := UfoLegend.RIM_CENTRE
	# The disc: its underside in shadow, its top lit from the upper left, and the top of its rim
	# catching the light on that side.
	art.ellipse(rim, DISC, "shadow")
	art.ellipse(rim + Vector2(0.0, -1.0), DISC - Vector2(0.0, 1.0), "asphalt")
	art.ellipse(rim + Vector2(-6.0, -2.0), Vector2(14.0, 2.5), "asphalt light")
	for x: int in range(-floori(DISC.x), 1):
		var y := rim.y - 1.0 - (DISC.y - 1.0) * sqrt(1.0 - pow((x + 0.5) / DISC.x, 2.0))
		art.plot(Vector2i(x, floori(y)), "line")
	# The dome, with three dark windows.
	art.ellipse(rim + DOME, DOME_RADII, "asphalt")
	art.ellipse(rim + DOME + Vector2(-3.0, -2.5), Vector2(4.0, 2.5), "asphalt light")
	for k: float in [-4.0, 0.0, 4.0]:
		art.rect(Rect2i(Vector2i(rim + DOME + Vector2(k - 1.0, 1.0)), Vector2i(2, 2)), "ink")
	# The port under it, as wide as the beam.
	art.ellipse(Vector2(0.0, -3.5), Vector2(UfoLegend.PORT / 2.0 + 3.0, 3.0), "shadow")
	art.ellipse(Vector2(0.0, -2.0), Vector2(UfoLegend.PORT / 2.0, 1.5), "ink")
	art.outline()


## The rim's lights, `step` of the way from each light's place to the next one's.
static func _draw_rim(art: LegendArt, step: float) -> void:
	for k: int in UfoLegend.LIGHTS:
		var angle := TAU * (k + step) / UfoLegend.LIGHTS
		if sin(angle) < RIM_BACK:
			continue
		var at := UfoLegend.RIM_CENTRE + Vector2(cos(angle), sin(angle)) * UfoLegend.RIM_RADII
		art.rect(Rect2i(Vector2i((at - Vector2.ONE).floor()), Vector2i(2, 2)), "white")


## The cone from the port to the pool round the car's ground point, and its core.
static func _draw_beam(art: LegendArt) -> void:
	var top := -float(UfoLegend.beam_size().y)
	var ground := Vector2(0.0, -UfoLegend.POOL.y)
	for k: int in 2:
		var color := "white" if k == 1 else "asphalt light"
		var port := UfoLegend.PORT / 2.0 - CORE_IN.x * k
		var pool := UfoLegend.POOL.x - CORE_IN.y * k
		var cone: Array[Vector2] = [
			Vector2(-port, top),
			Vector2(port, top),
			Vector2(pool, ground.y),
			Vector2(-pool, ground.y)
		]
		art.poly(cone, color)
		art.ellipse(ground, Vector2(pool, pool * UfoLegend.POOL.y / UfoLegend.POOL.x), color)


## A grey with its head tilted `tilt` radians to its right, where the beam is.
static func _draw_grey(art: LegendArt, tilt: float) -> void:
	# Long thin legs and arms, and a narrow body, lit on the right.
	art.line(Vector2(-2.0, -1.0), Vector2(-1.0, -11.0), "asphalt light")
	art.line(Vector2(1.0, -1.0), Vector2(1.0, -11.0), "line")
	art.rect(Rect2i(-2, -20, 4, 9), "asphalt light")
	art.rect(Rect2i(0, -20, 2, 9), "line")
	art.line(Vector2(-3.0, -19.0), Vector2(-4.0, -8.0), "asphalt light")
	art.line(Vector2(2.0, -19.0), Vector2(3.0, -8.0), "line")
	art.rect(Rect2i(-1, -22, 2, 2), "asphalt light")
	# The head, a wide skull over a narrow chin, shaded on its left, and its eyes, all turned about
	# the neck.
	var head := _oval(HEAD, HEAD_RADII)
	head.append_array([CHIN, Vector2(-CHIN.x, CHIN.y)])
	head = _turned(Geometry2D.convex_hull(PackedVector2Array(head)), tilt)
	art.poly(head, "asphalt light")
	art.poly(_turned(_oval(HEAD + Vector2(1.0, 0.0), HEAD_RADII - Vector2(1.0, 0.5)), tilt), "line")
	for side: float in [-1.0, 1.0]:
		var eye: Array[Vector2] = [
			Vector2(side * 4.4, -7.8),
			Vector2(side * 0.8, -6.2),
			Vector2(side * 1.4, -3.6),
			Vector2(side * 4.2, -4.8),
		]
		art.poly(_turned(eye, tilt), "ink")
	art.outline()


## The rings scorched into the field, a circle in the middle and four small ones round it.
static func _draw_crop_circle(art: LegendArt) -> void:
	var centre := Vector2(0.0, -UfoLegend.CROP_CIRCLE.y / 2.0)
	var squash := float(UfoLegend.CROP_CIRCLE.y) / UfoLegend.CROP_CIRCLE.x
	for ring: Vector2 in RINGS:
		var outer := Vector2(ring.x, ring.x * squash)
		var inner := Vector2(ring.x - ring.y, (ring.x - ring.y) * squash)
		for y: int in range(floori(centre.y - outer.y), ceili(centre.y + outer.y)):
			for x: int in range(floori(-outer.x), ceili(outer.x)):
				var at := Vector2(x, y) + Vector2(0.5, 0.5) - centre
				if (at / outer).length_squared() <= 1.0 and (at / inner).length_squared() > 1.0:
					art.plot(Vector2i(x, y), "shadow")
	art.ellipse(centre, MIDDLE, "shadow")
	art.ellipse(centre, MIDDLE - Vector2(2.0, 1.0), "rural dark")
	var out := Vector2(RINGS[0].x, RINGS[0].x * squash) * SATELLITE_AT
	for k: int in 4:
		var angle := TAU * (k + 0.5) / 4.0
		art.ellipse(centre + Vector2(cos(angle), sin(angle)) * out, SATELLITE, "shadow")


## The points of an oval about `centre` with `radii`, from a grey's neck.
static func _oval(centre: Vector2, radii: Vector2) -> Array[Vector2]:
	const SIDES := 16
	var points: Array[Vector2] = []
	for k: int in SIDES:
		points.append(centre + Vector2.from_angle(TAU * k / SIDES) * radii)
	return points


## `points`, from a grey's neck, turned `angle` radians about it, from its foot.
static func _turned(points: Variant, angle: float) -> Array[Vector2]:
	var turned: Array[Vector2] = []
	for point: Vector2 in points:
		turned.append(NECK + point.rotated(angle))
	return turned
