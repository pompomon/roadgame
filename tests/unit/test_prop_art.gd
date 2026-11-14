extends GutTest
## The props of each area (plan.md §5.3, IMPLEMENTATION_PLAN.md M5.1, docs/M5.md §5.6): 6–10, some
## animated, each keeping PropDef's contract, on its area's props sheet, with frames cropped to
## their pixels and kept apart from the other props' frames. test_area_art checks the sheets'
## colours and import settings.

const Art := preload("res://tests/helpers/art_checks.gd")
const AREAS: Array[StringName] = [&"city", &"rural", &"meadows", &"village", &"desert"]


func _props(area: StringName) -> Array[PropDef]:
	return (load("res://areas/%s.tres" % area) as AreaDef).props


func test_each_area_has_six_to_ten_props_some_animated() -> void:
	for area: StringName in AREAS:
		var props := _props(area)
		assert_between(props.size(), 6, 10, "%s's props" % area)
		var ids: Dictionary[StringName, bool] = {}
		var animated := 0
		var density := 0.0
		for def: PropDef in props:
			assert_eq(def.validate(), PackedStringArray(), "%s: %s" % [area, def.id])
			assert_eq(def.texture.resource_path, "res://assets/%s/props.png" % area)
			ids[def.id] = true
			animated += 1 if def.frames > 1 else 0
			density += def.density
		assert_eq(ids.size(), props.size(), "%s's ids are unique" % area)
		assert_gt(animated, 0, "%s has an animated prop" % area)
		assert_between(density, 0.01, 1.0, "%s's densities" % area)


func test_each_frame_is_cropped_to_its_props_pixels_apart_from_the_others() -> void:
	for area: StringName in AREAS:
		var strips: Array[Rect2i] = []
		for def: PropDef in _props(area):
			var image := def.texture.get_image()
			var used := Rect2i()
			for frame: int in def.frames:
				var at := def.region.position + Vector2i(def.region.size.x * frame, 0)
				var pixels := image.get_region(Rect2i(at, def.region.size)).get_used_rect()
				assert_true(pixels.has_area(), "%s: %s's frame %d shows" % [area, def.id, frame])
				used = pixels if frame == 0 else used.merge(pixels)
			assert_eq(used, Rect2i(Vector2i.ZERO, def.region.size), "%s: %s" % [area, def.id])
			var strip := Rect2i(def.region.position, def.region.size * Vector2i(def.frames, 1))
			for other: Rect2i in strips:
				assert_false(strip.intersects(other), "%s: %s overlaps" % [area, def.id])
			strips.append(strip)


func test_each_prop_lights_its_yellow_windows_and_lamps() -> void:
	# make_props.gd records each box that it paints yellow, a lit window or a lamp's head, as a
	# light grown by a halo, and a lamp's pool on the ground below its head (docs/DAYNIGHT.md
	# §5.12). Each light's centre is yellow in the prop's first frame.
	var yellow := Art.pixel(Art.MakeArt.palette()["yellow"])
	var lit: Dictionary[String, Vector2i] = {}
	for area: StringName in AREAS:
		for def: PropDef in _props(area):
			var prop := "%s: %s" % [area, def.id]
			if def.lights.is_empty() and def.light_pools.is_empty():
				continue
			lit[prop] = Vector2i(def.lights.size(), def.light_pools.size())
			var image := def.texture.get_image()
			for box: Rect2 in def.lights:
				var centre := Vector2i((Vector2(def.foot) + box.get_center()).floor())
				var pixel := Art.pixel(image.get_pixelv(def.region.position + centre))
				assert_eq(pixel, yellow, "%s's light %s" % [prop, box])
			for pool: Rect2 in def.light_pools:
				assert_eq(pool.get_center().y, 0.0, "%s's pool is on the ground" % prop)
				var head := def.lights[0].get_center().x if def.lights.size() > 0 else NAN
				assert_eq(pool.get_center().x, head, "%s's pool is below its head" % prop)
	var expected: Dictionary[String, Vector2i] = {
		"city: building": Vector2i(8, 0),
		"city: lamp": Vector2i(1, 1),
		"rural: barn": Vector2i(1, 0),
		"village: cottage": Vector2i(1, 0),
	}
	assert_eq(lit, expected)


func test_the_traffic_light_changes_as_a_real_one_does() -> void:
	# E14's Web check saw it go from yellow to green, and from green straight to red.
	var palette := Art.MakeArt.palette()
	var lamps: Array[String] = ["meadows light", "yellow", "red"]
	var def := load("res://areas/props/city/traffic_light.tres") as PropDef
	var image := def.texture.get_image()
	assert_eq(def.frames, lamps.size(), "a frame for each lamp")
	var tops: Array[int] = []
	for frame: int in mini(def.frames, lamps.size()):
		var at := def.region.position + Vector2i(def.region.size.x * frame, 0)
		var pixels := Art.pixels(image.get_region(Rect2i(at, def.region.size)))
		var lit: Array[String] = []
		for lamp: String in lamps:
			var first := pixels.find(Art.pixel(palette[lamp]))
			if first >= 0:
				lit.append(lamp)
				@warning_ignore("integer_division")
				tops.append(first / def.region.size.x)
		assert_eq(lit, [lamps[frame]] as Array[String], "frame %d lights one lamp" % frame)
	# Green at the bottom, red on top: each frame's lamp is above the last one's.
	assert_eq(tops.size(), lamps.size())
	for k: int in range(1, tops.size()):
		assert_lt(tops[k], tops[k - 1], "frame %d's lamp is above frame %d's" % [k, k - 1])


## The lowest opaque pixel of each column of `image`, or -1 where a column has none.
static func _bottoms(image: Image) -> PackedInt32Array:
	var bottoms := PackedInt32Array()
	for x: int in image.get_width():
		var bottom := -1
		for y: int in image.get_height():
			if image.get_pixel(x, y).a > 0.0:
				bottom = y
		bottoms.append(bottom)
	return bottoms


func test_each_shadow_falls_from_where_its_prop_meets_the_ground() -> void:
	# A wall's shadow falls from its base, a line up-right across its frame that crosses the foot's
	# column shadow_rise above the foot: the posts in each half of it stand on that line, and the
	# rails between them above it. A box's falls from its footprint's centre, shadow_rise above
	# the foot and level with the footprint's side corners, where its walls' lower edges, rising
	# from the foot, end (docs/DAYNIGHT.md §5.11). Within PIXELS: an odd footprint's centre is
	# half a pixel off the grid, and its edges are drawn in whole pixels.
	const PIXELS := 1.5
	var walls := 0
	var boxes := 0
	for area: StringName in AREAS:
		for def: PropDef in _props(area):
			var bottoms := _bottoms(def.texture.get_image().get_region(def.region))
			var prop := "%s: %s" % [area, def.id]
			if def.shadow == PropDef.Shadow.WALL:
				walls += 1
				var middle := bottoms.size() >> 1
				for half: Vector2i in [Vector2i(0, middle), Vector2i(middle, bottoms.size())]:
					var lowest := -INF
					for x: int in range(half.x, half.y):
						var base := def.foot.y - def.shadow_rise - (x - def.foot.x) / 2.0
						lowest = maxf(lowest, bottoms[x] - base)
					assert_almost_eq(lowest, 0.0, PIXELS, "%s's posts from %d" % [prop, half.x])
			elif def.shadow == PropDef.Shadow.UPRIGHT and def.shadow_rise > 0:
				boxes += 1
				for step: int in [-1, 1]:
					var x := def.foot.x
					while _on_edge(bottoms, def.foot, x + step):
						x += step
					var corner := absf(x - def.foot.x) / 2.0
					assert_almost_eq(corner, float(def.shadow_rise), PIXELS, "%s's corner" % prop)
	assert_eq(walls, 2, "the fences")
	assert_eq(boxes, 5, "the building, the barn and the village's houses")


## Whether column `x` of a frame whose columns' lowest pixels are `bottoms` is on the lower edge of
## a footprint whose front corner is `foot`.
static func _on_edge(bottoms: PackedInt32Array, foot: Vector2i, x: int) -> bool:
	if x < 0 or x >= bottoms.size():
		return false
	return absf(bottoms[x] - (foot.y - absf(x - foot.x) / 2.0)) <= 1.0
