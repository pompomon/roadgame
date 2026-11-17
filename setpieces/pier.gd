class_name Pier
extends SetPiece
## The pier (ENDGAME_PLAN.md §5.8), in grey box, where the game's road ends: its tiles are planks,
## as the bridge's are (GreyboxAtlas.road_coords()), on a deck that stands out to sea between two
## railings and up to a third across its end. The sea covers every cell at or past the pier's first
## tile along its heading (at_sea()), from the shore, where the road comes onto the pier, out past
## the view's edge, with foam along the shore and waves that roll in to it: dashes that move and
## fade in, and are never redrawn. The road beyond the pier draws nothing, and no prop stands on the
## sea (PropScatter). The near side's fascia and piles hang below the deck; the far side's and the
## end's would hang under it, and don't show. The near railing draws over the car (z_index 1). The
## path heads only N or W, so the sea lies up the screen from the shore.

## The deck and its railings are the bridge's.
const DECK_HALF_WIDTH := Bridge.DECK_HALF_WIDTH
const RAILING := Bridge.RAILING
const RAILING_HEIGHT := Bridge.RAILING_HEIGHT
## How far the near side's fascia and piles hang below the deck, in screen pixels, and how wide a
## pile is along the pier, in tiles. A pile stands under the middle of each tile.
const FASCIA_PX := 5.0
const PILE_PX := 14.0
const PILE_WIDTH := 0.1
## How far the sea reaches across the pier each way and past its end, in tiles: as far as the
## ground does, so that no view near the pier shows its edge (WorldRenderer.GROUND_MARGIN). A point
## up to GROUND_MARGIN px across and up or down the screen from a cell is at most this many tiles
## from it along each axis.
const SEA_REACH := (
	WorldRenderer.GROUND_MARGIN / Iso.TILE_W + WorldRenderer.GROUND_MARGIN / Iso.TILE_H
)
## How wide the foam along the shore is, in tiles.
const FOAM_WIDTH := 0.12
## The surf: waves roll in at WAVE_SPEED from SURF_REACH tiles out to the shore, where they start
## again, fading in as they come. They roll in lanes along the shore, LANES_PER_SIDE either side of
## the pier, LANE_STEP tiles apart from LANE_FIRST tiles off its centreline, WAVES_PER_LANE in each.
## A wave is WAVE_LENGTH tiles along the shore and WAVE_WIDTH tiles across it.
const SURF_REACH := 4.0
const LANES_PER_SIDE := 6
const LANE_FIRST := 1.5
const LANE_STEP := 2.5
const WAVES_PER_LANE := 3
const WAVE_LENGTH := 1.2
const WAVE_WIDTH := 0.06
## The share of a cycle by which each lane's waves start after the last lane's: the golden ratio's
## fraction, whose multiples spread evenly, so that lanes side by side are never level.
const LANE_SHIFT := 0.618034

## The sea, in tile space.
var water := Rect2()
## Seconds since setup().
var _time := 0.0

@onready var _sea: Polygon2D = %Sea
@onready var _foam: Polygon2D = %Foam
@onready var _waves: Node2D = %Waves
@onready var _piles: Node2D = %Piles
@onready var _fascia: Polygon2D = %Fascia
@onready var _deck: Polygon2D = %Deck
@onready var _far_railing: Polygon2D = %FarRailing
@onready var _end_railing: Polygon2D = %EndRailing
@onready var _near_railing: Polygon2D = %NearRailing


## Whether `cell` is at sea on a road whose pier starts with path tile `first`: at or past it along
## its heading.
static func at_sea(cell: Vector2i, first: RoadTile) -> bool:
	var step := Heading.VEC[first.heading]
	var past := cell - first.cell
	return past.x * step.x + past.y * step.y >= 0


func _build() -> void:
	var length := run_length()
	var reach := SEA_REACH + 0.5
	water = span(0.0, length + SEA_REACH, -reach, reach)
	_sea.polygon = corners(water)
	_foam.polygon = corners(span(0.0, FOAM_WIDTH, -reach, reach))
	_deck.polygon = corners(grown(DECK_HALF_WIDTH - 0.5, 0.0))
	var near := DECK_HALF_WIDTH
	_fascia.polygon = face(point(0.0, near), point(length, near), -FASCIA_PX, 0.0)
	var half_pile := forward() * PILE_WIDTH * 0.5
	var pile: Polygon2D = _piles.get_child(0)
	pile.polygon = face(-half_pile, half_pile, -PILE_PX, 0.0)
	for _k: int in range(1, roundi(length)):
		_piles.add_child(pile.duplicate())
	for k: int in _piles.get_child_count():
		(_piles.get_child(k) as Node2D).position = Iso.tile_to_world(point(k + 0.5, near))
	_far_railing.polygon = face(point(0.0, -RAILING), point(length, -RAILING), 0.0, RAILING_HEIGHT)
	_near_railing.polygon = face(point(0.0, RAILING), point(length, RAILING), 0.0, RAILING_HEIGHT)
	_end_railing.polygon = face(
		point(length, -RAILING), point(length, RAILING), 0.0, RAILING_HEIGHT
	)
	var wave: Polygon2D = _waves.get_child(0)
	wave.polygon = corners(Rect2(Vector2.ZERO, wave_rect(0, 0.0).size))
	for _k: int in range(1, 2 * LANES_PER_SIDE * WAVES_PER_LANE):
		_waves.add_child(wave.duplicate())
	_place_waves()


func _physics_process(delta: float) -> void:
	_time += delta
	_place_waves()


## How far lane `lane` is across from the pier's centreline, towards its near side: the even lanes
## lie on the near side, and the odd ones on the far side.
func lane_centre(lane: int) -> float:
	var towards := 1.0 if lane % 2 == 0 else -1.0
	@warning_ignore("integer_division")
	return towards * (LANE_FIRST + (lane / 2) * LANE_STEP)


## How far wave `index` is out from the shore `time` seconds after setup(), in tiles, at its side
## nearer the shore. A lane's waves start evenly spread over the surf, so they never touch, and each
## lane LANE_SHIFT of a cycle after the last.
func wave_out(index: int, time: float) -> float:
	@warning_ignore("integer_division")
	var lane := index / WAVES_PER_LANE
	var phase := ((index % WAVES_PER_LANE) + fposmod(lane * LANE_SHIFT, 1.0)) / WAVES_PER_LANE
	var room := SURF_REACH - WAVE_WIDTH
	return room - fposmod(phase * room + time * Tuning.WAVE_SPEED, room)


## Wave `index`'s tile-space rectangle `time` seconds after setup().
func wave_rect(index: int, time: float) -> Rect2:
	@warning_ignore("integer_division")
	var centre := lane_centre(index / WAVES_PER_LANE)
	var out := wave_out(index, time)
	var half := WAVE_LENGTH * 0.5
	return span(out, out + WAVE_WIDTH, centre - half, centre + half)


## How much of itself wave `index` shows `time` seconds after setup(): none at the surf's edge, and
## all of itself at the shore.
func wave_alpha(index: int, time: float) -> float:
	return 1.0 - wave_out(index, time) / SURF_REACH


func _place_waves() -> void:
	for index: int in _waves.get_child_count():
		var wave: Polygon2D = _waves.get_child(index)
		wave.position = Iso.tile_to_world(wave_rect(index, _time).position)
		wave.self_modulate.a = wave_alpha(index, _time)
