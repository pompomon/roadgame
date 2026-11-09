class_name Bridge
extends SetPiece
## The bridge (plan.md §3.6, IMPLEMENTATION_PLAN.md M4.4), in grey box: a river crosses under the
## run, between banks at both ends, and a deck carries the road over it, between two railings.
## Waves drift down the river: dashes that move, and are never redrawn. The railings only show the
## edge: off the road, the car still takes damage by the capsule test. The near railing draws over
## the car (z_index 1). The river's shader comes with M5's art (M4_PLAN.md Q4). A run too short
## for the waves' rows between its banks is an error, and gets neither river nor waves.

## How far the deck reaches across the run from its centreline, in tiles.
const DECK_HALF_WIDTH := 0.42
## How far the railings are from the centreline, in tiles, and how tall, in screen pixels.
const RAILING := 0.4
const RAILING_HEIGHT := 8.0
## The waves: rows along the run, waves per row, and a wave's length down the river and width, in
## tiles.
const WAVE_ROWS := 3
const WAVES_PER_ROW := 3
const WAVE_LENGTH := 0.4
const WAVE_WIDTH := 0.05

## The river, in tile space.
var water := Rect2()
## Seconds since setup().
var _time := 0.0

@onready var _river: Polygon2D = %River
@onready var _waves: Node2D = %Waves
@onready var _deck: Polygon2D = %Deck
@onready var _far_railing: Polygon2D = %FarRailing
@onready var _near_railing: Polygon2D = %NearRailing


## The river under a run on `cells` along `run_axis`: all of it but a bank at each end, and
## RIVER_REACH tiles each way across it from its centreline.
static func river(cells: Rect2, run_axis: int) -> Rect2:
	var bank := Tuning.BRIDGE_BANK
	var reach := Tuning.RIVER_REACH - 0.5
	if run_axis == Vector2.AXIS_X:
		return cells.grow_individual(-bank, reach, -bank, reach)
	return cells.grow_individual(reach, -bank, reach, -bank)


## The unit vector along the run, towards its end cell's side, in tile space.
func along() -> Vector2:
	return Vector2.RIGHT if axis() == Vector2.AXIS_X else Vector2.DOWN


## The direction the river flows, in tile space: across the run, towards the viewer.
func across() -> Vector2:
	return Vector2.DOWN if axis() == Vector2.AXIS_X else Vector2.RIGHT


func _build() -> void:
	water = river(rect, axis())
	_river.polygon = corners(water)
	_deck.polygon = corners(grown(DECK_HALF_WIDTH - 0.5, 0.0))
	var centre := rect.get_center().dot(across()) * across()
	var start := rect.position.dot(along()) * along()
	var end := rect.end.dot(along()) * along()
	var side := across() * RAILING
	_far_railing.polygon = face(start + centre - side, end + centre - side, 0.0, RAILING_HEIGHT)
	_near_railing.polygon = face(start + centre + side, end + centre + side, 0.0, RAILING_HEIGHT)
	var wave: Polygon2D = _waves.get_child(0)
	var length := across() * WAVE_LENGTH
	var width := along() * WAVE_WIDTH
	wave.polygon = PackedVector2Array(
		[
			Vector2.ZERO,
			Iso.tile_to_world(length),
			Iso.tile_to_world(length + width),
			Iso.tile_to_world(width),
		]
	)
	for _k: int in range(1, WAVE_ROWS * WAVES_PER_ROW):
		_waves.add_child(wave.duplicate())
	_place_waves()
	if water.size.dot(along()) < WAVE_ROWS * WAVE_WIDTH:
		var tiles := roundi(rect.size.dot(along()))
		push_error("Bridge: no room for the river between the banks of a %d-tile run" % tiles)
		_river.hide()
		_waves.hide()


func _physics_process(delta: float) -> void:
	_time += delta
	_place_waves()


## Wave `index`'s tile-space rectangle `time` seconds after setup(). The waves of a row start
## spread down the river; each drifts down at WAVE_SPEED, and back to the top once its end reaches
## the bottom.
func wave_rect(index: int, time: float) -> Rect2:
	@warning_ignore("integer_division")
	var row := index / WAVES_PER_ROW
	var room := water.size.dot(across()) - WAVE_LENGTH
	var phase := float(index) / (WAVE_ROWS * WAVES_PER_ROW)
	var down := fposmod(phase * room + time * Tuning.WAVE_SPEED, room)
	var row_centre := water.size.dot(along()) * (row + 0.5) / WAVE_ROWS
	var start := water.position + across() * down + along() * (row_centre - WAVE_WIDTH * 0.5)
	return Rect2(start, across() * WAVE_LENGTH + along() * WAVE_WIDTH)


func _place_waves() -> void:
	for index: int in _waves.get_child_count():
		var wave: Polygon2D = _waves.get_child(index)
		wave.position = Iso.tile_to_world(wave_rect(index, _time).position)
