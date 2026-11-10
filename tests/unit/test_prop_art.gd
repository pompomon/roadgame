extends GutTest
## The props of each area (plan.md §5.3, IMPLEMENTATION_PLAN.md M5.1, M5_PLAN.md §5.6): 6–10, some
## animated, each keeping PropDef's contract, on its area's props sheet, with frames cropped to
## their pixels and kept apart from the other props' frames. test_area_art checks the sheets'
## colours and import settings.

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
