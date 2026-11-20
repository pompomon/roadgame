class_name AreaScheduleEntry
extends Resource
## One AreaSchedule entry: when the generator has emitted `turn` turns, not counting decoys, the
## road enters `area`. A set piece (a run of straight tiles with no junction) can lead into it.

@export var turn := 0
@export var area: AreaDef
## &"tunnel", &"bridge" or &"" for none. M4.4 maps the id to its scene.
@export var set_piece := &""
@export_range(0, 20) var set_piece_length := 0
## Whether the way into the area is a pit stop, which repairs the car as it drives out of it on the
## road (docs/ENDGAME.md §5.15): its set piece, or with none, the area's first straight, by which
## Last Gas, a filling station, stands.
@export var pit_stop := false
