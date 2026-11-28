class_name PropScatter
extends RefCounted
## Scatters each area's props beside the road (plan.md §5.2, docs/M5.md §5.6) on World's Props
## layer, which y-sorts them with the car. Each screen row of the path gets its props from
## PropLayout once the car is PROP_AHEAD path tiles before the row's path tile, so a row at a time
## as the car drives, and retires them after the buffer frees that tile (docs/PERF.md §5.3).
## With BUFFER_BEHIND and BUFFER_REFILL_AT, neither shows on the reference screens (docs/M5.md L2).
## The BUFFER_BEHIND rows
## below the first path tile get the props of its area at the start, and lose them with it.
## WorldRenderer makes it, binds it with itself and updates it every frame. A see-through prop, such
## as the City's building, fades where it would hide the car or a legend's sprite on the layer
## (docs/VISUALS.md §5.9). No prop stands on the sea past a pier (docs/ENDGAME.md §5.8).

## The scale under which a sprite on the layer doesn't show: Node2D stores a zero scale as
## CMP_EPSILON (scene/2d/node_2d.cpp, set_scale), so a legend's part that waits at a scale of zero,
## such as the Witch's Hex's pumpkin, still has a rect with an area.
const HIDDEN_SCALE := 1e-4
## How long, in seconds of a prop's clock, before its next frame update() looks at its frame again.
const NEXT_FRAME_EARLY := 1e-6


## A prop that shows.
class Shown:
	extends RefCounted
	var sprite: Sprite2D
	## Its silhouette and its glows at night (docs/DAYNIGHT.md §5.12), or null.
	var lit: Lamps.Lit
	var def: PropDef
	var phase: float
	## Its shadow (docs/DAYNIGHT.md §5.11), or null.
	var cast: Shadows.Cast
	## Where its frame shows on the layer: a see-through prop's, which _fade() reads every frame.
	var frame: Rect2
	## When its next frame starts, in seconds of its clock: until then update() leaves its frame.
	var next_frame_at := 0.0


## The props of a row; those of them that animate, by the scatter's clock or, those that rest at
## night, by the rest clock; and those that are see-through.
class Row:
	extends RefCounted
	var anchor: Vector2i
	var shown: Array[Shown] = []
	var animated: Array[Shown] = []
	var resting: Array[Shown] = []
	var fading: Array[Shown] = []


## Where the props' lights glow at night (docs/DAYNIGHT.md §5.12), or null for none. WorldRenderer
## sets it.
var lamps: Lamps
var pool: PropPool
## Where the props' shadows lie (docs/DAYNIGHT.md §5.11), or null for none. WorldRenderer sets it.
var shadows: Shadows

## The props of each area of the schedule that keep the contract, by the area's id.
var _props: Dictionary[StringName, Array] = {}
## The area of the bound road's first path tile. A run can start in any area of the schedule
## (docs/ZONE_SELECT.md Z3).
var _first_area := &""
var _buffer: RoadBuffer
## The rows that have their props, by their path tile's index.
var _rows: Dictionary[int, Row] = {}
## The next row to get its props, and the lowest row that may still have them.
var _next_row := 0
var _lowest_row := 0
var _hide_below := 0
## Seconds of animation since bind().
var _clock := 0.0
## Seconds of animation since bind() of the props that rest at night (docs/HEADLIGHTS.md §5.5),
## which run at _rest_rate: from 1 by day to 0 at night. -1 until the first update() after bind().
var _rest_clock := 0.0
var _rest_rate := -1.0
## The layer whose own children, the car and the legends' sprites, see-through props fade for.
var _layer: Node2D
## The see-through props that show less than whole, and how much of themselves they show.
var _faded: Dictionary[Shown, float] = {}
## The first tile of the bound road's pier, once the buffer has made it, or null.
var _pier: RoadTile


## Scatters the props of `schedule`'s areas on `layer`. A prop that breaks the contract is an
## error, and doesn't show.
func _init(layer: Node2D, schedule: AreaSchedule) -> void:
	_layer = layer
	# Internal children, which simulate() walks past (docs/DAYNIGHT.md C20): the City's lots double
	# its props (docs/VISUALS.md A7). In front of the layer's own children, so that the car draws
	# over a prop on its y.
	pool = PropPool.new(layer, Node.INTERNAL_MODE_FRONT)
	for entry: AreaScheduleEntry in schedule.entries:
		if not _props.has(entry.area.id):
			_props[entry.area.id] = _valid_props(entry.area)


## Shows the props beside `buffer`'s road from now on, instead of the last buffer's.
func bind(buffer: RoadBuffer) -> void:
	if _buffer != null:
		_buffer.tiles_generated.disconnect(_on_tiles_generated)
		_buffer.tiles_freed.disconnect(_on_tiles_freed)
	for k: int in _rows.keys():
		_hide_row(k)
	_buffer = buffer
	_pier = null
	_first_area = buffer.generator.first_area().id
	_lowest_row = -Tuning.BUFFER_BEHIND if buffer.first_index() == 0 else buffer.first_index()
	_hide_below = _lowest_row
	_next_row = _lowest_row
	_clock = 0.0
	_rest_clock = 0.0
	_rest_rate = -1.0
	buffer.tiles_generated.connect(_on_tiles_generated)
	buffer.tiles_freed.connect(_on_tiles_freed)
	_find_pier()
	_show_rows()


## Shows the rows the car has come near, animates the props, and fades the see-through ones. Call
## it every frame. The props that rest at night slow to a stop in PROP_REST_SECONDS as `cycle`'s
## night falls, and start again as it ends (docs/HEADLIGHTS.md §5.5); without a clock they never
## rest. A run that starts at night starts with them at rest.
func update(delta: float, cycle: DayCycle = null) -> void:
	if _buffer == null:
		return
	_hide_rows()
	_show_rows()
	_clock += delta
	var rate := 0.0 if cycle != null and DayCycle.night_at(cycle.hour()) else 1.0
	if _rest_rate < 0.0:
		_rest_rate = rate
	_rest_rate = move_toward(_rest_rate, rate, delta / Tuning.PROP_REST_SECONDS)
	var rest_was := _rest_clock
	_rest_clock += delta * _rest_rate
	# Only the props whose next frame has come: the Meadows' grass animates hundreds
	# (docs/HEADLIGHTS.md B12). None that rest while their clock stands: it may stand within
	# NEXT_FRAME_EARLY of a prop's next frame, which would then come on every update all night.
	var rest_moved := _rest_clock != rest_was
	for row: Row in _rows.values():
		for shown: Shown in row.animated:
			if _clock >= shown.next_frame_at:
				_set_frame(shown, _clock)
		for shown: Shown in row.resting:
			if rest_moved and _rest_clock >= shown.next_frame_at:
				_set_frame(shown, _rest_clock)
	_fade()


## The path tile indices of the rows that have their props, lowest first.
func rows() -> Array[int]:
	var keys: Array[int] = []
	keys.assign(_rows.keys())
	keys.sort()
	return keys


## The sprites of the props of row `k`.
func sprites(k: int) -> Array[Sprite2D]:
	var found: Array[Sprite2D] = []
	if _rows.has(k):
		for shown: Shown in _rows[k].shown:
			found.append(shown.sprite)
	return found


func _on_tiles_generated(_tiles: Array[RoadTile]) -> void:
	_find_pier()
	_show_rows()


func _on_tiles_freed(_tiles: Array[RoadTile]) -> void:
	_hide_below = maxi(_hide_below, _buffer.first_index())


func _hide_rows() -> void:
	var left := Tuning.HIDE_ROWS_PER_FRAME
	while _lowest_row < _hide_below and left > 0:
		if _rows.has(_lowest_row):
			_hide_row(_lowest_row)
			left -= 1
		_lowest_row += 1


## Gives their props to the rows up to PROP_AHEAD path tiles past the car's whose road is made,
## from the lowest row the buffer still has.
func _show_rows() -> void:
	var last := mini(
		_buffer.car_index() + Tuning.PROP_AHEAD, _buffer.last_index() - PropLayout.rows_needed()
	)
	_next_row = maxi(_next_row, _hide_below)
	while _next_row <= last:
		_show_row(_next_row)
		_next_row += 1


## The cell of row `k` that its props spread either side of: its path tile's, or below the start,
## the cell of the row that is closest to below path tile 0's, on (0, 0).
func anchor(k: int) -> Vector2i:
	if _rows.has(k):
		return _rows[k].anchor
	if k >= 0:
		return _buffer.path_tile(k).cell
	var below := -k
	return Vector2i(below >> 1, below - (below >> 1))


func _show_row(k: int) -> void:
	var area := _first_area if k < 0 else _buffer.path_tile(k).area_id
	var props: Array[PropDef] = []
	if _props.has(area):
		props = _props[area]
	var row := Row.new()
	row.anchor = anchor(k)
	for placement: PropLayout.Placement in PropLayout.row(
		row.anchor, props, _buffer.generator.props_seed, _buffer
	):
		if _at_sea(placement.foot):
			continue
		var shown := Shown.new()
		shown.def = placement.def
		shown.phase = placement.phase
		shown.sprite = pool.acquire(placement.def)
		shown.sprite.position = placement.foot
		if shadows != null:
			shown.cast = shadows.add(placement.def, placement.foot)
		row.shown.append(shown)
		if lamps != null:
			shown.lit = lamps.add(placement.def, shown.sprite)
		if placement.def.rests_at_night:
			row.resting.append(shown)
			_set_frame(shown, _rest_clock)
		elif placement.def.frames > 1:
			row.animated.append(shown)
			_set_frame(shown, _clock)
		if placement.def.see_through:
			shown.frame = Rect2(
				placement.foot - Vector2(placement.def.foot), Vector2(placement.def.region.size)
			)
			row.fading.append(shown)
	_rows[k] = row


func _hide_row(k: int) -> void:
	if _rows.has(k):
		for shown: Shown in _rows[k].shown:
			_release(shown)
		_rows.erase(k)


## Takes prop `shown` off the layer, with its glows and its shadow.
func _release(shown: Shown) -> void:
	if lamps != null:
		lamps.remove(shown.lit)
	pool.release(shown.sprite)
	if shadows != null:
		shadows.remove(shown.cast)
	_faded.erase(shown)


## Finds the bound road's pier once the buffer has its first tile, and takes away each prop that
## already stands on the sea: on a short road, a row that reaches the sea can show before the pier
## is made.
func _find_pier() -> void:
	var finish := _buffer.generator.finish_index
	if _pier != null or finish < _buffer.first_index() or finish > _buffer.last_index():
		return
	if _buffer.path_tile(finish).set_piece != &"pier":
		return
	_pier = _buffer.path_tile(finish)
	for row: Row in _rows.values():
		for shown: Shown in row.shown.duplicate():
			if _at_sea(shown.sprite.position):
				_release(shown)
				row.shown.erase(shown)
				row.animated.erase(shown)
				row.resting.erase(shown)
				row.fading.erase(shown)


## Whether a prop with its foot on `foot` would stand on the sea.
func _at_sea(foot: Vector2) -> bool:
	return _pier != null and Pier.at_sea(Vector2i(Iso.world_to_tile(foot).floor()), _pier)


## Fades each see-through prop near an actor as far as the actor that it would hide most asks
## (SeeThrough.opacity()), and shows whole again each that no actor is near any more. Only the
## sprites' modulate changes, so nothing is redrawn on the Web (docs/M2.md §5.7).
func _fade() -> void:
	var fading: Dictionary[Shown, float] = {}
	for child: Node in _layer.get_children():
		var actor := actor_rect(child)
		if not actor.has_area():
			continue
		var actor_y := (child as Node2D).position.y
		var near := SeeThrough.rows(actor)
		# A row reaches PROP_SPREAD tiles or more either side of the road, and most of its props are
		# PROP_FADE_PX or more across from the actor, where they show whole.
		var left := actor.position.x - Tuning.PROP_FADE_PX
		var right := actor.end.x + Tuning.PROP_FADE_PX
		for k: int in range(near.x, near.y + 1):
			if not _rows.has(k):
				continue
			for shown: Shown in _rows[k].fading:
				var frame := shown.frame
				if frame.position.x >= right or frame.end.x <= left:
					continue
				var foot_y := frame.position.y + shown.def.foot.y
				var alpha := SeeThrough.opacity(frame, foot_y, actor, actor_y)
				if alpha < fading.get(shown, 1.0):
					fading[shown] = alpha
	for shown: Shown in _faded:
		if not fading.has(shown):
			_show_alpha(shown, 1.0)
	for shown: Shown in fading:
		if _faded.get(shown, 1.0) != fading[shown]:
			_show_alpha(shown, fading[shown])
	_faded = fading


## Where `node`, one of the layer's own children, shows on the layer, if a see-through prop mustn't
## hide it: the car's body, or a sprite that a legend stood there, such as the car's double (docs/
## M6.md §5.4). An empty rect for anything else, and for what doesn't show: a legend's part waits
## hidden by its alpha or its scale (HIDDEN_SCALE), and a legend hides the car by its alpha.
static func actor_rect(node: Node) -> Rect2:
	var item := node as CanvasItem
	if item == null or not item.visible or item.modulate.a <= 0.0:
		return Rect2()
	if item is CarController:
		return (item as CarController).body_rect()
	if item is Sprite2D:
		var sprite := item as Sprite2D
		if minf(absf(sprite.scale.x), absf(sprite.scale.y)) < HIDDEN_SCALE:
			return Rect2()
		return sprite.get_transform() * sprite.get_rect()
	return Rect2()


## Shows `alpha` of `shown`, and of its silhouette with its glows at night, which fade with it.
static func _show_alpha(shown: Shown, alpha: float) -> void:
	shown.sprite.modulate.a = alpha
	if shown.lit != null:
		Lamps.fade(shown.lit, alpha)


## Shows prop `shown` in its frame at `clock` seconds of its clock, and notes when its next starts.
func _set_frame(shown: Shown, clock: float) -> void:
	var frames := shown.def.frames
	var cycle := clock * shown.def.fps / frames + shown.phase
	var at := (cycle - floorf(cycle)) * frames
	var frame := int(at) % frames
	# A little early, so that rounding never makes it a frame late.
	shown.next_frame_at = clock + (floorf(at) + 1.0 - at) / shown.def.fps - NEXT_FRAME_EARLY
	if shown.sprite.frame != frame:
		if shown.lit != null:
			Lamps.show_frame(shown.lit, frame)
		shown.sprite.frame = frame
		if shown.cast != null:
			shown.cast.sprite.frame = frame


## Whether densities that add up to `sum` take it past 1, by more than adding floats rounds: 0.33,
## 0.56 and 0.11 add up to 1.0000000000000002.
static func past_1(sum: float) -> bool:
	return sum > 1.0 and not is_equal_approx(sum, 1.0)


static func _valid_props(area: AreaDef) -> Array[PropDef]:
	var valid: Array[PropDef] = []
	# Each size of lot picks from its own props (PropLayout.row()), so their densities add up apart,
	# and by a street their street densities. In floats, as PropLayout.pick() uses them: a Vector2's
	# 32 bits would take ten densities of 0.1 past 1.
	var density: Dictionary[int, float] = {}
	var street: Dictionary[int, float] = {}
	for prop: PropDef in area.props:
		var problems := PackedStringArray(["a prop is null"]) if prop == null else prop.validate()
		var inside := 0.0
		var by_street := 0.0
		if problems.is_empty():
			inside = density.get(prop.lot, 0.0) + prop.chance(false)
			by_street = street.get(prop.lot, 0.0) + prop.chance(true)
			if past_1(inside) or past_1(by_street):
				problems.append("prop %s takes the densities past 1" % prop.id)
		for problem: String in problems:
			push_error("PropScatter: %s: %s" % [area.id, problem])
		if problems.is_empty():
			valid.append(prop)
			density[prop.lot] = inside
			street[prop.lot] = by_street
	return valid
