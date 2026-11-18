class_name Hitchhiker
extends Sprite2D
## The Vanishing Hitchhiker (ENDGAME_PLAN.md §5.17), the Book of Legends' last page: the road's own
## urban legend. Once every legend of the pools is collected, she stands beside the Road Home, on
## its far side, by the last plain straight before the player's farthest turn there, the first
## junction that no run of theirs has passed, or before its finish once they have arrived home: not
## on a set piece, nor by Last Gas. The car's passing finds her: she fades away over
## Tuning.HITCHHIKER_FADE_SECONDS, on her own clock, and `passed` reports it once, while the run
## goes on. A run that ends before it passes her doesn't find her. She is no disaster and in no
## pool, so no pick draws her and no arrival unlocks her. She reads no autoload, so that her art's
## script may load hers.

## The car passed her, in a run that goes on: the run found her.
signal passed

## Her entry in SaveData.disasters.
const ID := &"hitchhiker"
## Her one frame, in px (tools/art/legends/hitchhiker.gd).
const FRAME := Vector2i(28, 40)
## The finish of the road that she stands beside, the Road Home's (areas/schedule_home.tres).
const ROAD := &"home"

## Her name and her lore, as the Book shows them. She has no fate: she ends no run.
@export var display_name := ""
@export_multiline var lore := ""

## The run's car, which passes her.
var sim: CarSim
## The path index of the tile that she stands by, or -1 while she doesn't stand.
var index := -1

var _buffer: RoadBuffer
## The turn before whose junction she stands, as the run's generator counts them, and the road's.
var _turn := 0
var _finish_turn := 0
## The last plain straight laid before her place.
var _last_plain: RoadTile
## How long she has been fading, in seconds, or -1 until the car passes her.
var _fading := -1.0


## Whether she shows on a run to the finish `finish`, with the save `data`: only on the Road Home,
## once every legend of `schedule`'s pools is collected, until a run has found her.
static func shows(data: SaveData, finish: StringName, schedule: AreaSchedule) -> bool:
	if finish != ROAD:
		return false
	var collected := data.seen_disasters()
	return not collected.has(ID) and LegendUnlock.locked(schedule, collected).is_empty()


## The turn of the Road Home, which ends after `finish_turn`, before whose junction she stands, as
## `data` has it: the player's farthest turn there, the first that no run of theirs has passed, or
## once they have arrived home, the finish.
static func road_turn(data: SaveData, finish_turn: int) -> int:
	if data.arrival_count(ROAD) > 0:
		return finish_turn
	var road: Dictionary = data.arrivals.get(String(ROAD), SaveData.ARRIVAL_ENTRY)
	return mini(road["farthest"], finish_turn)


## Watches `buffer`'s road for her place, by the last plain straight before the junction of `turn`,
## as its generator numbers them, or before the finish if `turn` is `finish_turn` or more: she
## stands there once the buffer lays it. Every road starts with plain straights, so a place with
## none before it among the buffer's tiles is an error, and she stays hidden.
func watch(buffer: RoadBuffer, turn: int, finish_turn: int) -> void:
	hide()
	index = -1
	_buffer = buffer
	_turn = turn
	_finish_turn = finish_turn
	_last_plain = null
	_buffer.tiles_generated.connect(_on_tiles_generated)
	_on_tiles_generated(_buffer.tiles())


## Watches for the car to pass her, then fades her away.
func _physics_process(delta: float) -> void:
	if _fading < 0.0:
		if not _passing():
			return
		_fading = 0.0
		passed.emit()
	else:
		_fading += delta
	modulate.a = clampf(1.0 - _fading / Tuning.HITCHHIKER_FADE_SECONDS, 0.0, 1.0)
	if modulate.a <= 0.0:
		hide()
		set_physics_process(false)


## Whether the car, in a run that goes on, is past the centre of the tile that she stands by.
func _passing() -> bool:
	return index >= 0 and sim != null and not sim.is_over() and sim.progress > index


func _on_tiles_generated(tiles: Array[RoadTile]) -> void:
	for tile: RoadTile in tiles:
		if tile.path_index < 0:
			continue
		if _is_place(tile):
			_buffer.tiles_generated.disconnect(_on_tiles_generated)
			if _last_plain == null:
				push_error("Hitchhiker: no plain straight before path tile %d" % tile.path_index)
			else:
				_stand(_last_plain)
			return
		if tile.type == RoadTile.Type.STRAIGHT and not tile.pit_stop:
			_last_plain = tile


## Whether she stands before the path tile `tile`: her turn's junction, or the finish's first tile.
func _is_place(tile: RoadTile) -> bool:
	if _turn >= _finish_turn:
		return tile.path_index == _buffer.generator.finish_index
	return tile.is_turn() and tile.turn_number == _turn


## Stands her by `tile`, a straight, across from its centre on the road's far side, facing the road:
## her art holds her thumb out to the screen's right, where the road is on a road heading N or S.
func _stand(tile: RoadTile) -> void:
	index = tile.path_index
	var along := Heading.VEC[tile.heading]
	var across := Vector2.DOWN if along.x != 0 else Vector2.RIGHT
	position = Iso.tile_to_world(Iso.cell_centre(tile.cell) + across * Tuning.HITCHHIKER_ASIDE)
	flip_h = along.x != 0
	modulate.a = 1.0
	show()
