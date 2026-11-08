class_name CarSim
extends RefCounted
## The car, in tile space (IMPLEMENTATION_PLAN.md D1, D2, M2.2): steering, the speed model and
## off-road damage. Pure logic, stepped at a fixed delta. It moves the road buffer along, reports
## cell crossings and rejoins to its JunctionTrigger, and CarController draws it.

signal health_changed(value: float)
signal offroad_changed(is_offroad: bool)
## The car reached the first tile of a new area.
signal area_changed(area: AreaDef)
## The run ended in a crash: HEALTH or OFFROAD. Disasters come from trigger.disaster_triggered.
signal crashed(cause: StringName)

enum State { DRIVING, BRAKING, OFFROAD, DISASTER, CRASHED }

## Why a run ends (plan.md §2.5). WRONG_TURN and MISSED_TURN are disasters, the others crashes.
const WRONG_TURN := &"wrong_turn"
const MISSED_TURN := &"missed_turn"
const HEALTH := &"health"
const OFFROAD := &"offroad"

## Position in tile space (D1).
var pos := Vector2.ZERO
## Heading in radians: 0 is grid N (-y), clockwise.
var angle := 0.0
## Tiles per second.
var speed := 0.0
var health := Tuning.START_HEALTH
var state := State.DRIVING
## Tiles driven in the run, and since the last correct turn.
var dist_total := 0.0
var dist_on_straight := 0.0
## Tiles driven since the car last left the road.
var offroad_dist := 0.0
## The junction the car was near when it left the road (D6), or null.
var offroad_junction: RoadTile
## The correct-path tile whose cell the car was in last.
var path_tile: RoadTile
## Progress along the correct path, in tiles: path_tile's index plus the car's place along it.
var progress := 0.0
## The area of the farthest correct-path tile the car has reached. Its values drive the car.
var area: AreaDef
var buffer: RoadBuffer
var trigger: JunctionTrigger

## While off the road: the fraction of the current step from which the off-road time is not yet
## counted.
var _offroad_since := 0.0


## Puts the car on the centre of the buffer's first path tile, facing along it, at speed 0.
## `p_buffer` must have started.
func _init(p_buffer: RoadBuffer) -> void:
	buffer = p_buffer
	trigger = JunctionTrigger.new(buffer)
	trigger.turn_completed.connect(_on_turn_completed)
	trigger.disaster_triggered.connect(_on_disaster_triggered)
	path_tile = buffer.path_tile(buffer.first_index())
	pos = Iso.cell_centre(path_tile.cell)
	angle = path_tile.heading * PI / 2.0
	progress = path_tile.path_index
	area = buffer.generator.find_area(path_tile.area_id)


## Moves the car on by `delta` seconds, with steering `steer` from -1 (left) to 1 (right). One step
## must move less than a tile.
func step(delta: float, steer: float) -> void:
	if is_over():
		speed = move_toward(speed, 0.0, Tuning.BRAKE * delta)
		pos += velocity() * delta
		return
	_steer(delta, steer)
	_update_speed(delta)
	var from := pos
	pos += velocity() * delta
	# Whatever ends the run during the step sees the progress at the car's new position.
	progress = path_progress(path_tile, pos)
	dist_total += speed * delta
	dist_on_straight += speed * delta
	_offroad_since = 0.0
	# Follow the move in order: in each cell, where it leaves or rejoins the road, then where it
	# crosses into the next cell, which the trigger judges by whether the car is on the road there.
	# A path tile the move passes through counts as reached, even if the move ends off the path.
	var cell := Vector2i(from.floor())
	var done := 0.0
	for next: Vector2i in cells_crossed(from, pos):
		var at := _crossing_fraction(from, pos, cell, next)
		if not _follow_road(from, cell, done, at, delta):
			return
		trigger.on_cell_crossed(cell, next, state != State.OFFROAD)
		if is_over() or not _update_path(next, at, delta):
			return
		cell = next
		done = at
	if not _follow_road(from, cell, done, 1.0, delta) or not _update_path(cell, 1.0, delta):
		return
	if state == State.OFFROAD:
		_drive_off_road((1.0 - _offroad_since) * delta, area)


func velocity() -> Vector2:
	return forward() * speed


## Unit vector of the heading, in tile space.
func forward() -> Vector2:
	return Vector2(sin(angle), -cos(angle))


func is_over() -> bool:
	return state == State.DISASTER or state == State.CRASHED


## Path distance from the car to the centre of the next unresolved junction, or INF after a
## disaster.
func distance_to_junction() -> float:
	var junction := trigger.next_junction
	return INF if junction == null else junction.path_index - progress


## The cells a move from `from` to `to` enters, in order: none, one, or two when the move crosses a
## cell corner. The move must be shorter than one tile.
static func cells_crossed(from: Vector2, to: Vector2) -> Array[Vector2i]:
	var a := Vector2i(from.floor())
	var b := Vector2i(to.floor())
	var cells: Array[Vector2i] = []
	if a.x != b.x and a.y != b.y:
		# Enter first the neighbour across whichever cell edge the move reaches first.
		var tx := (maxi(a.x, b.x) - from.x) / (to.x - from.x)
		var ty := (maxi(a.y, b.y) - from.y) / (to.y - from.y)
		cells.append(Vector2i(b.x, a.y) if tx < ty else Vector2i(a.x, b.y))
	if a != b:
		cells.append(b)
	return cells


## The fraction of the move from `from` to `to` at which it crosses from `cell` into the
## neighbouring `next`.
static func _crossing_fraction(from: Vector2, to: Vector2, cell: Vector2i, next: Vector2i) -> float:
	var axis := 0 if next.x != cell.x else 1
	return (maxi(cell[axis], next[axis]) - from[axis]) / (to[axis] - from[axis])


## Progress along the correct path at `p`, measured on path tile `tile`: its index plus the place of
## the nearest point on its centreline, from -0.5 at the entry edge to 0.5 at the exit edge.
static func path_progress(tile: RoadTile, p: Vector2) -> float:
	var rel := p - Iso.cell_centre(tile.cell)
	var into := Vector2(Heading.VEC[tile.heading])
	var out := Vector2(Heading.VEC[tile.expected_exit if tile.is_junction() else tile.heading])
	var t_in := clampf(rel.dot(into), -0.5, 0.0)
	var t_out := clampf(rel.dot(out), 0.0, 0.5)
	var nearer_in := rel.distance_squared_to(into * t_in) < rel.distance_squared_to(out * t_out)
	return tile.path_index + (t_in if nearer_in else t_out)


func _steer(delta: float, steer: float) -> void:
	if steer != 0.0:
		angle += clampf(steer, -1.0, 1.0) * Tuning.STEER_RATE * delta
	else:
		# With no input, ease towards the nearest grid direction (plan.md §2.2).
		var axis := roundf(angle / (PI / 2.0)) * (PI / 2.0)
		angle = move_toward(angle, axis, Tuning.STRAIGHTEN_RATE * delta)
	angle = wrapf(angle, -PI, PI)


## The speed the car heads for (plan.md §2.3, IMPLEMENTATION_PLAN.md M2.2): it rises along a
## straight, up to a cap that grows with the distance driven; it is junction_speed from
## junction_brake_distance before the next junction, whichever exit the car will take; and it drops
## while the car is off the road.
func target_speed() -> float:
	var run_cap := minf(
		Tuning.GLOBAL_SPEED_CAP, Tuning.BASE_TOP_SPEED + dist_total * Tuning.TOP_SPEED_GROWTH
	)
	var target := minf(run_cap, area.junction_speed + area.straight_accel * dist_on_straight)
	if distance_to_junction() <= area.junction_brake_distance:
		target = area.junction_speed
	if state == State.OFFROAD:
		target *= area.offroad_speed_mult
	return target


func _update_speed(delta: float) -> void:
	var to_junction := distance_to_junction()
	if state != State.OFFROAD:
		state = State.BRAKING if to_junction <= area.junction_brake_distance else State.DRIVING
	var target := target_speed()
	var rate := Tuning.ACCEL if target > speed else Tuning.BRAKE
	if to_junction <= area.junction_brake_distance and speed > target:
		# Brake hard enough to be at the target speed on entering the junction tile, half a tile
		# before its centre, from any speed: junction_speed on the road, and less off it. Off the
		# road in the junction tile, the car slows as it does anywhere off the road.
		var room := to_junction - 0.5
		if room > 0.0:
			rate = maxf(rate, (speed * speed - target * target) / (2.0 * room))
		elif state == State.BRAKING:
			rate = INF
	speed = move_toward(speed, target, rate * delta)


## The car is in `cell` from fraction `at` of the step. If the cell holds a correct-path tile other
## than path_tile, that tile becomes path_tile: the buffer moves along, progress is measured on it
## at the car's position, and the area of the farthest path tile reached drives the car from
## there. Off the road, the time before a new area then counts at the old area's rates, so a run
## that ends there ends on the new tile, in the new area. Returns false if the run ended.
func _update_path(cell: Vector2i, at: float, delta: float) -> bool:
	var tile := buffer.tile_at(cell)
	if tile != null and tile.path_index >= 0 and tile != path_tile:
		var farthest := buffer.path_tile(maxi(buffer.car_index(), tile.path_index))
		path_tile = tile
		buffer.on_car_path_index(tile.path_index)
		progress = path_progress(path_tile, pos)
		if farthest.area_id != area.id:
			var before := area
			area = buffer.generator.find_area(farthest.area_id)
			area_changed.emit(area)
			if state == State.OFFROAD:
				_drive_off_road((at - _offroad_since) * delta, before)
				_offroad_since = at
	return not is_over()


## Off-road rules (plan.md §2.4, D6) on the part of the step from `from` to `pos` between
## fractions `start` and `end`, which lies in `cell`: the car leaves the road and rejoins it where
## that part crosses the road's edge, however often. Only the time off the road counts, and a
## rejoin counts only if the car reaches the road before the off-road limit or 0 health. Returns
## false if the run ended.
func _follow_road(from: Vector2, cell: Vector2i, start: float, end: float, delta: float) -> bool:
	var tile := buffer.tile_at(cell)
	var origin := Vector2(cell)
	var exits := 0 if tile == null else tile.exits
	var t := start
	for span: Vector2 in RoadGeometry.on_road_spans(exits, from - origin, pos - origin):
		var on_from := maxf(span.x, start)
		var on_to := minf(span.y, end)
		if on_from > on_to:
			continue
		if on_from > t:
			_leave_road(t)
		if state == State.OFFROAD and not _rejoin_road(tile, on_from, delta):
			return false
		t = on_to
	if t < end:
		_leave_road(t)
	return true


## The car leaves the road at fraction `t` of the step, unless it is off it already. It is near the
## next junction (D6) if its cell after the step is at most one grid step from the junction's.
func _leave_road(t: float) -> void:
	if state == State.OFFROAD:
		return
	state = State.OFFROAD
	offroad_dist = 0.0
	var junction := trigger.next_junction
	var near := junction != null and _steps(Vector2i(pos.floor()), junction.cell) <= 1
	offroad_junction = junction if near else null
	_offroad_since = t
	offroad_changed.emit(true)


## The car comes back onto the road on `tile` at fraction `t` of the step, after the off-road time
## up to there counts. Returns false if the run ended first, or on the rejoin.
func _rejoin_road(tile: RoadTile, t: float, delta: float) -> bool:
	_drive_off_road((t - _offroad_since) * delta, area)
	if is_over():
		return false
	state = State.DRIVING
	offroad_junction = null
	offroad_changed.emit(false)
	trigger.on_rejoin(tile)
	return not is_over()


## Damage and the off-road limit for `seconds` driven off the road, at the rates of `rates`.
func _drive_off_road(seconds: float, rates: AreaDef) -> void:
	offroad_dist += speed * seconds
	health = maxf(0.0, health - rates.offroad_damage_per_sec * seconds)
	health_changed.emit(health)
	if health <= 0.0:
		_crash(HEALTH)
	elif offroad_dist >= rates.offroad_limit_tiles:
		if offroad_junction != null:
			trigger.on_offroad_limit()
		else:
			_crash(OFFROAD)


func _crash(cause: StringName) -> void:
	state = State.CRASHED
	crashed.emit(cause)


func _on_turn_completed(_turn_index: int) -> void:
	dist_on_straight = 0.0


func _on_disaster_triggered(_junction: RoadTile, _choice: int) -> void:
	state = State.DISASTER


## Grid steps between two cells (Manhattan distance).
static func _steps(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)
