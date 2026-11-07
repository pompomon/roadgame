class_name AreaScheduleEntry
extends Resource
## One AreaSchedule entry: when the generator has emitted `turn` junctions, the road enters `area`.
## A set piece (a run of straight tiles with no junction) can lead into it.

@export var turn := 0
@export var area: AreaDef
## &"tunnel", &"bridge" or &"" for none. M4.4 maps the id to its scene.
@export var set_piece := &""
@export_range(0, 20) var set_piece_length := 0
