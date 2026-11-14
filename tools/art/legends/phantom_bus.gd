extends RefCounted
## The phantom bus's sheets (docs/M6.md §3.3), drawn into assets/legends/phantom_bus/ by
## tools/art/make_legends.gd. `bus.png`: a red double-decker with no one at the wheel and pale
## faces at its windows, in DOORS frames for each of its FACINGS, its doors shut, half open and
## open on the dark, where two eyes wait. `ticket.png`: the ticket that it leaves on the road. Its
## sizes, facings and lamps are the legend's (disasters/legends/phantom_bus.gd). The light comes
## from the upper left, as on the car (tools/art/make_car.gd): a side that faces +y in tile space
## is lit, and one that faces +x is shaded. No class_name: tools/ is not exported.

const LegendArt := preload("res://tools/art/legend_art.gd")
const Bus := preload("res://disasters/legends/phantom_bus.gd")
const TICKET := Vector2i(12, 8)
## Heights up its sides, in px, from the ground: the lower deck's windows, its doors, the band
## between the decks and the upper deck's windows; on its ends, the upper deck's windows and the
## destination blind over them.
const LOWER := Vector2(5.0, 11.0)
const DOOR := Vector2(1.0, 11.0)
const BAND := Vector2(12.0, 14.0)
const UPPER := Vector2(15.0, 22.0)
const END_UPPER := Vector2(15.0, 19.0)
const BLIND := 20
## The window slots along its long side, the door's in the lower deck, and the slots with a face at
## the glass on each deck.
const SLOTS := 5
const DOOR_SLOT := 2
const LOWER_FACES: Array[int] = [0, 3]
const UPPER_FACES: Array[int] = [1, 2, 4]
## The share of a slot that its window takes.
const PANE := 0.7
## Its wheels: where along it, in tiles from its middle, and their radius, in px.
const WHEELS: Array[float] = [-0.2, 0.2]
const WHEEL := 2.5
## The route on its blind, a 7, as rows of pixels.
const ROUTE: Array[String] = ["###", "  #", " # ", " # "]


## A face of the bus, flat on screen: `a` tiles along it and `h` px up it is the pixel at().
class Face:
	extends RefCounted
	var origin: Vector2
	var along: Vector2

	func _init(p_origin: Vector2, p_along: Vector2) -> void:
		origin = p_origin
		along = p_along

	func at(a: float, h: float) -> Vector2:
		return origin + along * a - Vector2(0.0, h)

	## The part of it from `a` to `b` along it, and from `low` to `high` up it.
	func part(a: float, b: float, low: float, high: float) -> Array[Vector2]:
		return [at(a, low), at(b, low), at(b, high), at(a, high)]


static func make(dir: String) -> void:
	var bus := LegendArt.new(Bus.FRAME, Bus.FACINGS.size() * Bus.DOORS)
	for facing: int in Bus.FACINGS.size():
		for doors: int in Bus.DOORS:
			bus.frame = Bus.first_frame(Bus.FACINGS[facing]) + doors
			_draw_bus(bus, Bus.FACINGS[facing], doors)
	bus.save(dir.path_join("bus.png"))
	var ticket := LegendArt.new(TICKET)
	var paper: Array[Vector2] = [Vector2(-5, -3), Vector2(1, -6), Vector2(5, -4), Vector2(-1, -1)]
	ticket.poly(paper, "white")
	ticket.line(Vector2(-3, -4), Vector2(1, -2), "red")
	ticket.outline()
	ticket.save(dir.path_join("ticket.png"))


## The pixel, from the frame's foot, of the point `u` tiles along the bus, `v` tiles across it and
## `h` px up from the ground, as it faces `forward`. Its ground centre is at Bus.FOOT.
static func _at(forward: Vector2, u: float, v: float, h: float) -> Vector2:
	var shift := Vector2(Bus.FOOT.x - (Bus.FRAME.x >> 1), Bus.FOOT.y - Bus.FRAME.y)
	return Iso.tile_to_world(forward * u + Bus.side(forward) * v) + shift - Vector2(0.0, h)


## The bus facing `forward` with its doors in frame `doors`, 0 shut to DOORS - 1 open.
static func _draw_bus(art: LegendArt, forward: Vector2, doors: int) -> void:
	var half_length := Bus.LENGTH / 2.0
	var half_width := Bus.WIDTH / 2.0
	var height := float(Bus.HEIGHT)
	# The end that the viewer sees: its front if it comes toward the viewer, else its back.
	var front := forward.x + forward.y > 0.0
	var end_normal := forward if front else -forward
	var long := Face.new(_at(forward, 0.0, half_width, 0.0), Iso.tile_to_world(forward))
	var end := Face.new(
		_at(forward, half_length * (1.0 if front else -1.0), 0.0, 0.0),
		Iso.tile_to_world(Bus.side(forward))
	)
	# The whole box first, so that no pixel between its faces is left clear.
	var corners := PackedVector2Array()
	for u: float in [-half_length, half_length]:
		for v: float in [-half_width, half_width]:
			for h: float in [0.0, height]:
				corners.append(_at(forward, u, v, h))
	var hull: Array[Vector2] = []
	hull.assign(Array(Geometry2D.convex_hull(corners)))
	art.poly(hull, "village roof")
	art.poly(long.part(-half_length, half_length, 0.0, height), _paint(Bus.side(forward)))
	art.poly(end.part(-half_width, half_width, 0.0, height), _paint(end_normal))
	var roof: Array[Vector2] = []
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		roof.append(_at(forward, corner.x * half_length, corner.y * half_width, height))
	art.poly(roof, "line")
	art.poly(long.part(-half_length, half_length, BAND.x, BAND.y), "line")
	art.poly(end.part(-half_width, half_width, BAND.x, BAND.y), "line")
	_draw_long_side(art, long, doors)
	if front:
		_draw_front(art, end)
	else:
		_draw_back(art, end)
	for spot: Vector2 in Bus.lamps(forward):
		var lamp := Vector2i((spot + _at(forward, 0.0, 0.0, 0.0)).floor())
		art.rect(Rect2i(lamp - Vector2i.ONE, Vector2i(2, 2)), "wisp")
	for u: float in WHEELS:
		art.ellipse(long.at(u, WHEEL), Vector2(WHEEL, WHEEL), "ink")
	art.outline()


## A lit side is the palette's red, a shaded one the darker red of the Village's roofs.
static func _paint(normal: Vector2) -> String:
	return "red" if normal == Vector2.DOWN else "village roof"


## Its windows, the faces at them, and its doors in frame `doors`.
static func _draw_long_side(art: LegendArt, long: Face, doors: int) -> void:
	var slot := Bus.LENGTH / SLOTS
	for k: int in SLOTS:
		var a := -Bus.LENGTH / 2.0 + slot * (k + (1.0 - PANE) / 2.0)
		var b := a + slot * PANE
		art.poly(long.part(a, b, UPPER.x, UPPER.y), "ink")
		if k in UPPER_FACES:
			_draw_face(art, long.at((a + b) / 2.0, (UPPER.x + UPPER.y) / 2.0))
		if k == DOOR_SLOT:
			_draw_doors(art, long, a, b, doors)
			continue
		art.poly(long.part(a, b, LOWER.x, LOWER.y), "ink")
		if k in LOWER_FACES:
			_draw_face(art, long.at((a + b) / 2.0, (LOWER.x + LOWER.y) / 2.0))


## The doors from `a` to `b` along the side: shut, glass over a seam; half open, a dark gap
## between them; open, the dark, with two eyes in it.
static func _draw_doors(art: LegendArt, long: Face, a: float, b: float, doors: int) -> void:
	var middle := (a + b) / 2.0
	art.poly(long.part(a, b, LOWER.x, DOOR.y), "ink")
	art.line(long.at(a, DOOR.x), long.at(a, LOWER.x), "ink")
	art.line(long.at(b, DOOR.x), long.at(b, LOWER.x), "ink")
	art.line(long.at(middle, DOOR.x), long.at(middle, LOWER.x), "ink")
	if doors == 0:
		return
	var gap := (b - a) / 2.0 * doors / (Bus.DOORS - 1)
	art.poly(long.part(middle - gap, middle + gap, DOOR.x, DOOR.y), "night")
	if doors == Bus.DOORS - 1:
		var eyes := Vector2i(long.at(middle, DOOR.y - 3.0).floor())
		art.plot(eyes + Vector2i(-1, 0), "wisp")
		art.plot(eyes + Vector2i(1, 0), "wisp")


## The front: a dark windscreen with no one at the wheel, the upper deck's windows with a face at
## one, and the route on the blind over them.
static func _draw_front(art: LegendArt, end: Face) -> void:
	var half_width := Bus.WIDTH / 2.0
	art.poly(end.part(-half_width * 0.8, half_width * 0.8, LOWER.x - 1.0, LOWER.y), "ink")
	art.poly(end.part(-half_width * 0.85, -half_width * 0.1, END_UPPER.x, END_UPPER.y), "ink")
	art.poly(end.part(half_width * 0.1, half_width * 0.85, END_UPPER.x, END_UPPER.y), "ink")
	_draw_face(art, end.at(half_width * 0.45, (END_UPPER.x + END_UPPER.y) / 2.0))
	var blind := Vector2i(end.at(0.0, BLIND).floor()) - Vector2i(2, ROUTE.size() + 1)
	art.rect(Rect2i(blind, Vector2i(5, ROUTE.size() + 2)), "ink")
	for row: int in ROUTE.size():
		for column: int in ROUTE[row].length():
			if ROUTE[row][column] == "#":
				art.plot(blind + Vector2i(1 + column, 1 + row), "white")


## The back: a window on each deck, with a face at each.
static func _draw_back(art: LegendArt, end: Face) -> void:
	var half_width := Bus.WIDTH / 2.0
	for deck: Vector2 in [LOWER, END_UPPER]:
		art.poly(end.part(-half_width * 0.7, half_width * 0.7, deck.x, deck.y), "ink")
		_draw_face(art, end.at(0.0, (deck.x + deck.y) / 2.0))


## A pale face pressed to the glass, centred on `at`: white, three pixels wide and four high, with
## two dark eyes under its brow, and its chin.
static func _draw_face(art: LegendArt, at: Vector2) -> void:
	var middle := Vector2i(at.floor())
	art.rect(Rect2i(middle + Vector2i(-1, -2), Vector2i(3, 3)), "white")
	art.plot(middle + Vector2i(0, 1), "white")
	art.plot(middle + Vector2i(-1, -1), "ink")
	art.plot(middle + Vector2i(1, -1), "ink")
