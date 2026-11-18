class_name RouteStrip
extends Control
## The route strip (ENDGAME_PLAN.md §5.14, E12): on a road with a finish, a bar up the HUD's right
## edge, from the road's start at its foot to the finish at its top. A tick marks each area's first
## turn, a chequered flag the finish, a solid triangle the car, and a hollow diamond the best run,
## at the road's farthest turn: shapes, not only colours, tell them apart. The car's mark climbs a
## pixel or so a turn, and nothing on the strip moves otherwise, or flashes. It draws in _draw(),
## not with Polygon2D nodes: on the Web, each redraw of a Polygon2D after its first raises WebGL
## errors in Godot 4.7.2 (godotengine/godot#124726), and the HUD redraws its children each time it
## shows.

## The health bar's colours (ui/theme.tres): its border, and its fill and the outlines.
const EDGE_COLOR := Color(0.20392157, 0.1882353, 0.23529412)
const DARK_COLOR := Color(0.078431375, 0.07058824, 0.09411765)
## The text's.
const LIGHT_COLOR := Color(0.9411765, 0.9411765, 0.9098039)
## The focus border's yellow, for the car.
const CAR_COLOR := Color(0.9254902, 0.76862746, 0.2509804)
## The dark outline around each mark, in pixels.
const OUTLINE := 1.0
## How far a tick reaches past each side of the bar, and its thickness.
const TICK_OVERHANG := 2.0
const TICK_THICKNESS := 2.0
## The car's triangle, pointing up the road: its half-width and its height.
const CAR_HALF_WIDTH := 5.0
const CAR_HEIGHT := 8.0
## The best run's diamond: from its centre to its corners, outside and inside its ring.
const BEST_RADIUS := 6.0
const BEST_HOLE := 3.0
## The finish's flag: its pole on the strip's top, and its cloth of chequers flying left, inward.
const POLE_HEIGHT := 12.0
const POLE_WIDTH := 2.0
const CHEQUER := 2.0
const FLAG_COLUMNS := 4
const FLAG_ROWS := 3

## The road shown, or null on a road with no finish, where the strip hides.
var _road: AreaSchedule
## The car's turn and the best run's on the road.
var _car_turn := 0
var _best_turn := 0


## Shows `road` with the car at `car_turn` and the best run at `best_turn`, or 0 for none; or hides
## the strip if the road has no finish.
func show_road(road: AreaSchedule, car_turn: int, best_turn: int) -> void:
	_road = road if road != null and road.has_finish() else null
	_car_turn = car_turn
	_best_turn = best_turn
	visible = _road != null
	queue_redraw()


## Moves the car's mark to `turn` of the road.
func move_car(turn: int) -> void:
	_car_turn = turn
	queue_redraw()


## The height above the foot of a strip `length` pixels long, in whole pixels, of `turn` on a road
## whose finish is at `finish_turn`: the finish's, and those past it, are the strip's whole length.
## A road that ends where it starts, as --finish=0's does, is all finish. The length is rounded: the
## anchors that make it compute in single precision.
static func height(turn: int, finish_turn: int, length: float) -> int:
	var top := roundi(length)
	if finish_turn <= 0:
		return top
	return roundi(clampf(float(turn) / finish_turn, 0.0, 1.0) * top)


## The heights of the ticks, one at each area's first turn, from the foot up.
func tick_heights() -> Array[int]:
	var heights: Array[int] = []
	if _road == null:
		return heights
	for entry: AreaScheduleEntry in _road.entries:
		if entry != null:
			heights.append(_height(entry.turn))
	return heights


## The car's height.
func car_height() -> int:
	return _height(_car_turn)


## The best run's height, or -1 before the road has one.
func best_height() -> int:
	return _height(_best_turn) if _best_turn > 0 else -1


func _height(turn: int) -> int:
	return height(turn, _road.finish_turn, size.y) if _road != null else 0


func _draw() -> void:
	if _road == null:
		return
	var length := roundf(size.y)
	var middle := size.x / 2.0
	var bar := Rect2(0.0, 0.0, size.x, length)
	draw_rect(bar, EDGE_COLOR)
	draw_rect(bar.grow(-OUTLINE), DARK_COLOR)
	_draw_flag(middle)
	# After the flag: a tick at the finish stands at the pole's foot.
	for tick_height: int in tick_heights():
		var tick := Rect2(
			-TICK_OVERHANG,
			length - tick_height - TICK_THICKNESS / 2.0,
			size.x + 2.0 * TICK_OVERHANG,
			TICK_THICKNESS
		)
		draw_rect(tick.grow(OUTLINE), DARK_COLOR)
		draw_rect(tick, LIGHT_COLOR)
	if best_height() >= 0:
		_draw_diamond(Vector2(middle, length - best_height()))
	_draw_car(Vector2(middle, length - car_height()))


func _draw_flag(middle: float) -> void:
	var pole := Rect2(middle - POLE_WIDTH / 2.0, -POLE_HEIGHT, POLE_WIDTH, POLE_HEIGHT)
	var cloth_width := FLAG_COLUMNS * CHEQUER
	var cloth := Rect2(
		pole.position.x - OUTLINE - cloth_width, -POLE_HEIGHT, cloth_width, FLAG_ROWS * CHEQUER
	)
	draw_rect(cloth.grow(OUTLINE), DARK_COLOR)
	for row: int in FLAG_ROWS:
		for column: int in FLAG_COLUMNS:
			if (row + column) % 2 == 0:
				var at := cloth.position + Vector2(column, row) * CHEQUER
				draw_rect(Rect2(at, Vector2(CHEQUER, CHEQUER)), LIGHT_COLOR)
	draw_rect(pole.grow(OUTLINE), DARK_COLOR)
	draw_rect(pole, LIGHT_COLOR)


## A ring, dark around light: its edges run at 45 degrees, so its corners move SQRT2 pixels for an
## outline a pixel wide.
func _draw_diamond(centre: Vector2) -> void:
	var grow := OUTLINE * sqrt(2.0)
	_draw_ring(centre, BEST_RADIUS + grow, maxf(BEST_HOLE - grow, 0.0), DARK_COLOR)
	_draw_ring(centre, BEST_RADIUS, BEST_HOLE, LIGHT_COLOR)


## A diamond's ring around `centre`, from `outer` to `inner`, as four quadrilaterals.
func _draw_ring(centre: Vector2, outer: float, inner: float, color: Color) -> void:
	var corners: Array[Vector2] = [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]
	for k: int in corners.size():
		var a := corners[k]
		var b := corners[(k + 1) % corners.size()]
		var quad := PackedVector2Array(
			[centre + a * outer, centre + b * outer, centre + b * inner, centre + a * inner]
		)
		draw_colored_polygon(quad, color)


## The car's triangle, its tip up the strip, on a dark one a pixel larger on each side: scaled
## about the centre of the circle inside it, whose radius is twice its area over its perimeter.
func _draw_car(centre: Vector2) -> void:
	var points := PackedVector2Array(
		[
			centre + Vector2(0.0, -CAR_HEIGHT / 2.0),
			centre + Vector2(CAR_HALF_WIDTH, CAR_HEIGHT / 2.0),
			centre + Vector2(-CAR_HALF_WIDTH, CAR_HEIGHT / 2.0),
		]
	)
	var sides := PackedFloat64Array()
	for k: int in points.size():
		sides.append(points[(k + 1) % points.size()].distance_to(points[(k + 2) % points.size()]))
	var perimeter := sides[0] + sides[1] + sides[2]
	var incentre := (points[0] * sides[0] + points[1] * sides[1] + points[2] * sides[2]) / perimeter
	var radius := 2.0 * CAR_HALF_WIDTH * CAR_HEIGHT / perimeter
	var outline := PackedVector2Array()
	for point: Vector2 in points:
		outline.append(incentre + (point - incentre) * (radius + OUTLINE) / radius)
	draw_colored_polygon(outline, DARK_COLOR)
	draw_colored_polygon(points, CAR_COLOR)
