extends RefCounted
## Baba Yaga's hut's sheets (POOLS_PLAN.md §5.4), drawn into assets/legends/baba_yaga/ by
## tools/art/make_legends.gd. `hut.png`: a log hut on a pair of chicken legs, its roof thatched. In
## profile, facing the screen's right, a window in its side, it stomps, its near leg raised and then
## its far one, and stands; it turns three-quarters, its door in its front; it faces the screen, its
## door shut; it squats, and crouches on its folded legs, its door shut and then open on the dark.
## `prints.png`: the prints of its chicken feet along the tile x axis, one a stride, by turns either
## side of the road's middle, the first 1 to 4 of them. The logs and the prints are dark, and the
## thatch, the legs, the door and the window light, so they stand out from the Village by night
## (§5.6). The window is painted yellow: it has no glow. Its sizes are the legend's
## (disasters/legends/baba_yaga.gd). No class_name: tools/ is not exported.

const LegendArt := preload("res://tools/art/legend_art.gd")
const BabaYagaLegend := preload("res://disasters/legends/baba_yaga.gd")
## The hut's walls, in px from its foot: LOGS logs of LOG px, each but the last with a seam along
## its foot, and the ends of the logs, LOG_END px, sticking out at its corners. Its thatch is
## streaked from its eaves to its ridge, STREAKS streaks across.
const LOG := 4
const LOGS := 5
const LOG_END := Vector2i(2, 2)
const STREAKS := 8
## In profile: the top of its side wall, from end to end; its thatch, from its eave up to its ridge,
## along it and down; and the window in its side.
const SIDE: Array[Vector2] = [Vector2(-20, -44), Vector2(20, -44)]
const SIDE_THATCH: Array[Vector2] = [
	Vector2(-25, -45), Vector2(-22, -58), Vector2(21, -58), Vector2(24, -45)
]
const SIDE_WINDOW := Rect2i(-5, -39, 9, 9)
## Turned three-quarters: the tops of its side wall, from its far end to its near corner, and of its
## front wall, from that corner to its far end, which rise away from the corner; its thatch over its
## side, from the corner's eave up the front's gable to the ridge, back along it and down to the far
## eave; its gable, of planks, and its verge, thatched; and the door in its front and the window in
## its side.
const TURN_SIDE: Array[Vector2] = [Vector2(-25, -46), Vector2(2, -44)]
const TURN_FRONT: Array[Vector2] = [Vector2(2, -44), Vector2(23, -46)]
const TURN_THATCH: Array[Vector2] = [
	Vector2(-1, -42), Vector2(12, -61), Vector2(-15, -63), Vector2(-28, -44)
]
const TURN_GABLE: Array[Vector2] = [Vector2(2, -44), Vector2(12.5, -59), Vector2(23, -46)]
const TURN_VERGE: Array[Vector2] = [Vector2(12.5, -61), Vector2(25, -45)]
const VERGE_WIDTH := 2
const TURN_DOOR := Rect2i(8, -41, 9, 16)
const TURN_WINDOW := Rect2i(-16, -40, 8, 8)
## Facing the screen: the top of its front wall; its thatch, up either side of its gable to the
## ridge, its eaves sticking out at the sides; its gable, of planks, with a window; and its door. It
## is drawn on its left half and mirrored, all but the door's handle. Squatting, the hut is
## SQUAT_DROP px lower; crouched, CROUCH_DROP, and its door opens on the dark, its leaf swung out to
## the left.
const FRONT: Array[Vector2] = [Vector2(-16, -44), Vector2(16, -44)]
const FRONT_THATCH: Array[Vector2] = [Vector2(-22, -43), Vector2(0, -63), Vector2(22, -43)]
const FRONT_GABLE: Array[Vector2] = [Vector2(-16, -44), Vector2(0, -58), Vector2(16, -44)]
const GABLE_WINDOW := Rect2i(-4, -55, 8, 7)
const DOOR := Rect2i(-5, -41, 10, 17)
const SQUAT_DROP := 12
const CROUCH_DROP := 24
const LEAF: Array[Vector2] = [
	Vector2(-5, -41), Vector2(-10, -39), Vector2(-10, -24), Vector2(-5, -24)
]
## A door's leaf, in a frame of ink with no sill: planks PLANK px apart, and its handle, HANDLE px
## from the leaf's top right corner.
const PLANK := 3
const HANDLE := Vector2i(-2, 7)
## The legs, each in px from its hip's x and the hut's foot: its hip, its hock and its ankle, joined
## by lines THIGH and then SHANK px wide, and its toes, pairs of points joined by lines. In profile,
## its far leg's hip is FAR_HIP and its near leg's NEAR_HIP: a leg planted, its hock back and its
## toes along the ground, the back one behind; raised, its foot drawn up and forward, its toes
## hanging. Turned, it stands so too. Facing the screen, its left leg's hip is FRONT_HIP, its toes
## splayed; squatting, that leg bends; crouched, it folds up beside the hut, its hip FOLDED_HIP and
## its hock out to the side.
const THIGH := 3
const SHANK := 2
const FAR_HIP := -3.0
const NEAR_HIP := 3.0
const PLANTED: Array[Vector2] = [Vector2(0, -24), Vector2(-5, -13), Vector2(-1, -3)]
const PLANTED_TOES: Array[Vector2] = [Vector2(-4, -1), Vector2(7, -1)]
const RAISED: Array[Vector2] = [Vector2(0, -24), Vector2(-6, -16), Vector2(4, -9)]
const RAISED_TOES: Array[Vector2] = [
	Vector2(5, -8), Vector2(9, -5), Vector2(5, -8), Vector2(7, -4), Vector2(4, -8), Vector2(2, -9)
]
const FRONT_HIP := -7.0
const FRONT_LEG: Array[Vector2] = [Vector2(0, -24), Vector2(-2, -13), Vector2(-1, -3)]
const FRONT_TOES: Array[Vector2] = [Vector2(-5, -1), Vector2(3, -1)]
const SQUAT_LEG: Array[Vector2] = [Vector2(0, -12), Vector2(-4, -7), Vector2(-2, -3)]
const FOLDED_HIP := -22.0
const FOLDED: Array[Vector2] = [Vector2(0, -9), Vector2(-4, -5), Vector2(-1, -2)]
const FOLDED_TOES: Array[Vector2] = [Vector2(-5, -1), Vector2(2, -1)]
## The prints, in tiles from the middle of the stretch that they lie on, along the tile x axis from
## where the hut stopped: one a stride, by turns either side of the road's middle, PRINT_ACROSS
## from it, each from its heel, its three toes forward, the middle one MIDDLE_TOE long and the
## others SIDE_TOE, splayed SPLAY to either side of it, and its back toe BACK_TOE.
const PRINT_ACROSS := 0.08
const MIDDLE_TOE := 0.12
const SIDE_TOE := 0.1
const SPLAY := deg_to_rad(40.0)
const BACK_TOE := 0.05


static func make(dir: String) -> void:
	var hut := LegendArt.new(BabaYagaLegend.HUT, BabaYagaLegend.Pose.size())
	for pose: int in BabaYagaLegend.Pose.size():
		hut.frame = pose
		_draw_hut(hut, pose)
		hut.outline()
	hut.save(dir.path_join("hut.png"))
	var prints := LegendArt.new(BabaYagaLegend.PRINTS, BabaYagaLegend.STRIDES)
	for strides: int in BabaYagaLegend.STRIDES:
		prints.frame = strides
		_draw_prints(prints, strides + 1)
	prints.save(dir.path_join("prints.png"))


static func _draw_hut(art: LegendArt, pose: int) -> void:
	match pose:
		BabaYagaLegend.Pose.TURN:
			_draw_turned(art)
		BabaYagaLegend.Pose.FRONT:
			_draw_front(art, 0, FRONT_HIP, FRONT_LEG, FRONT_TOES)
		BabaYagaLegend.Pose.SQUAT:
			_draw_front(art, SQUAT_DROP, FRONT_HIP, SQUAT_LEG, FRONT_TOES)
		BabaYagaLegend.Pose.CROUCH:
			_draw_front(art, CROUCH_DROP, FOLDED_HIP, FOLDED, FOLDED_TOES)
		BabaYagaLegend.Pose.OPEN:
			_draw_front(art, CROUCH_DROP, FOLDED_HIP, FOLDED, FOLDED_TOES)
			_draw_open(art)
		_:
			_draw_profile(art, pose)


## In profile, facing the screen's right: its far leg and then its near one, raised in turn as it
## stomps and both planted as it stands; its side wall, its thatch and its window.
static func _draw_profile(art: LegendArt, pose: int) -> void:
	var far_up := pose == BabaYagaLegend.Pose.STOMP_B
	var near_up := pose == BabaYagaLegend.Pose.STOMP_A
	var far_toes := RAISED_TOES if far_up else PLANTED_TOES
	var near_toes := RAISED_TOES if near_up else PLANTED_TOES
	_draw_leg(art, FAR_HIP, RAISED if far_up else PLANTED, far_toes, "rural dark")
	_draw_leg(art, NEAR_HIP, RAISED if near_up else PLANTED, near_toes, "yellow")
	_draw_logs(art, SIDE[0], SIDE[1])
	_draw_thatch(art, SIDE_THATCH)
	_draw_window(art, SIDE_WINDOW)


## Turned three-quarters, its legs planted: its side wall and its front wall, its thatch, its gable
## and its verge, its door, shut, and its window.
static func _draw_turned(art: LegendArt) -> void:
	_draw_leg(art, FAR_HIP, PLANTED, PLANTED_TOES, "rural dark")
	_draw_leg(art, NEAR_HIP, PLANTED, PLANTED_TOES, "yellow")
	_draw_logs(art, TURN_SIDE[0], TURN_SIDE[1])
	_draw_logs(art, TURN_FRONT[0], TURN_FRONT[1])
	_draw_thatch(art, TURN_THATCH)
	art.poly(TURN_GABLE, "plank")
	art.line(TURN_VERGE[0], TURN_VERGE[1], "rural light", VERGE_WIDTH)
	_draw_door(art, TURN_DOOR)
	_draw_handle(art, TURN_DOOR)
	_draw_window(art, TURN_WINDOW)


## Facing the screen, `drop` px lower, its legs' hips `hip` px from its middle, each leg `leg` and
## its toes `toes`: its legs, its thatch, its front wall, its gable and its window, and its door,
## shut.
static func _draw_front(
	art: LegendArt, drop: int, hip: float, leg: Array[Vector2], toes: Array[Vector2]
) -> void:
	var down := Vector2(0.0, drop)
	_draw_leg(art, hip, leg, toes, "yellow")
	art.poly(_moved(FRONT_THATCH, down), "rural light")
	_draw_logs(art, FRONT[0] + down, FRONT[1] + down)
	art.poly(_moved(FRONT_GABLE, down), "plank")
	_draw_window(art, Rect2i(GABLE_WINDOW.position + Vector2i(down), GABLE_WINDOW.size))
	var door := Rect2i(DOOR.position + Vector2i(down), DOOR.size)
	_draw_door(art, door)
	art.mirror()
	_draw_handle(art, door)


## The door, crouched, open on the dark, its leaf swung out to the left on its hinges.
static func _draw_open(art: LegendArt) -> void:
	var down := Vector2i(0, CROUCH_DROP)
	art.rect(Rect2i(DOOR.position + down, DOOR.size), "ink")
	var leaf := _moved(LEAF, Vector2(down))
	art.poly(leaf, "desert dark")
	var seam := (leaf[1] + leaf[2]) / 2.0 + Vector2(PLANK - 1, 0.0)
	art.line(Vector2(seam.x, leaf[1].y + 1.0), Vector2(seam.x, leaf[2].y - 1.0), "plank")


## A wall of LOGS logs whose top runs from `left` to `right`, its seams and its log ends at both.
static func _draw_logs(art: LegendArt, left: Vector2, right: Vector2) -> void:
	var height := Vector2(0.0, LOG * LOGS)
	var wall: Array[Vector2] = [left, right, right + height, left + height]
	art.poly(wall, "shadow")
	for k: int in LOGS:
		var top := Vector2(0.0, LOG * k)
		if k < LOGS - 1:
			var seam := top + Vector2(0.0, LOG - 1)
			art.line(left + seam, right + seam + Vector2.LEFT, "ink")
		var row := Vector2i(top) + Vector2i(0, 1)
		art.rect(Rect2i(Vector2i(left) + row + Vector2i(-LOG_END.x, 0), LOG_END), "desert dark")
		art.rect(Rect2i(Vector2i(right) + row, LOG_END), "desert dark")


## Thatch over `points`, its eave, its ridge from that end to the other, and its other eave: pale
## straw, streaked from its eaves to its ridge.
static func _draw_thatch(art: LegendArt, points: Array[Vector2]) -> void:
	art.poly(points, "rural light")
	for k: int in range(1, STREAKS):
		var across := float(k) / STREAKS
		var eave := points[0].lerp(points[3], across)
		var ridge := points[1].lerp(points[2], across)
		art.line(eave.lerp(ridge, 0.1), eave.lerp(ridge, 0.9), "desert dark")


## A window filling `frame`: a carved frame round its pane, which is crossed in its middle, by one
## pixel or, where the pane is even, two.
static func _draw_window(art: LegendArt, frame: Rect2i) -> void:
	art.rect(frame, "desert dark")
	var pane := frame.grow(-1)
	art.rect(pane, "yellow")
	var low := pane.position + Vector2i((pane.size.x - 1) >> 1, (pane.size.y - 1) >> 1)
	var high := pane.position + Vector2i(pane.size.x >> 1, pane.size.y >> 1)
	art.rect(Rect2i(low.x, pane.position.y, high.x - low.x + 1, pane.size.y), "ink")
	art.rect(Rect2i(pane.position.x, low.y, pane.size.x, high.y - low.y + 1), "ink")


## A door filling `frame`, shut: its leaf of planks in a frame of ink, which has no sill.
static func _draw_door(art: LegendArt, frame: Rect2i) -> void:
	art.rect(frame, "ink")
	var leaf := frame.grow_individual(-1, -1, -1, 0)
	art.rect(leaf, "desert dark")
	for x: int in [leaf.position.x + PLANK - 1, leaf.end.x - PLANK]:
		art.line(Vector2(x, leaf.position.y), Vector2(x, leaf.end.y - 1), "plank")


## The handle of the door that fills `frame`.
static func _draw_handle(art: LegendArt, frame: Rect2i) -> void:
	art.plot(Vector2i(frame.end.x - 1, frame.position.y + 1) + HANDLE, "ink")


## A leg whose hip is `hip` px right of the hut's foot: its hip, its hock and its ankle, `joints`,
## and its toes, `toes`, pairs of points.
static func _draw_leg(
	art: LegendArt, hip: float, joints: Array[Vector2], toes: Array[Vector2], color_name: String
) -> void:
	var at := Vector2(hip, 0.0)
	art.line(at + joints[0], at + joints[1], color_name, THIGH)
	art.line(at + joints[1], at + joints[2], color_name, SHANK)
	for k: int in range(0, toes.size(), 2):
		art.line(at + toes[k], at + toes[k + 1], color_name)


## `points`, each moved `by`.
static func _moved(points: Array[Vector2], by: Vector2) -> Array[Vector2]:
	var moved: Array[Vector2] = []
	for point: Vector2 in points:
		moved.append(point + by)
	return moved


## The first `strides` of its prints, from where it stopped.
static func _draw_prints(art: LegendArt, strides: int) -> void:
	for k: int in strides:
		var along := -BabaYagaLegend.PRINTS_TILES / 2.0 + (k + 0.5) * BabaYagaLegend.STRIDE_TILES
		_draw_print(art, Vector2(along, PRINT_ACROSS if k % 2 == 1 else -PRINT_ACROSS))


## A chicken foot's print, its heel `heel` tiles from the stretch's middle: its toes, forward and
## splayed, and its back toe.
static func _draw_print(art: LegendArt, heel: Vector2) -> void:
	var toes: Array[Vector2] = [
		Vector2(MIDDLE_TOE, 0.0),
		Vector2.from_angle(SPLAY) * SIDE_TOE,
		Vector2.from_angle(-SPLAY) * SIDE_TOE,
		Vector2(-BACK_TOE, 0.0),
	]
	for toe: Vector2 in toes:
		art.line(_at(heel), _at(heel + toe), "ink")


## The point `tiles` from the stretch's middle, along and across, in px from its frame's foot.
static func _at(tiles: Vector2) -> Vector2:
	var middle := Vector2(0.0, -BabaYagaLegend.PRINTS.y / 2.0)
	return middle + Iso.tile_to_world(tiles)
