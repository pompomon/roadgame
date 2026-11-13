extends GutTest
## ViewVeil (DAYNIGHT_PLAN.md §5.5): the square over the view that a legend's veil and the night's
## share. test_legend.gd checks that a legend's veil follows the view, and darkens the world.

const Disasters := preload("res://tests/helpers/disaster_fixtures.gd")
const ViewTest := preload("res://tests/integration/test_props_in_view.gd")


## The World rect that `veil` covers.
static func _cover(veil: Polygon2D) -> Rect2:
	var box := Rect2(veil.polygon[0], Vector2.ZERO)
	for point: Vector2 in veil.polygon:
		box = box.expand(point)
	box.position += veil.offset
	return veil.get_global_transform() * box


func test_the_veil_covers_every_view() -> void:
	# Every reference screen at every step of the zoom (M6_PLAN.md N26).
	var camera := Disasters.camera(self)
	camera.position = Vector2(-700.0, 900.0)
	var veil: ViewVeil = add_child_autofree(ViewVeil.new())
	veil.follow(camera)
	var covered := _cover(veil)
	var centre := camera.global_position + camera.offset
	for screen: Vector2i in ViewTest.SCREENS:
		for zoom: float in Tuning.CAMERA_ZOOMS:
			var size := Vector2(screen) / zoom
			assert_true(
				covered.encloses(Rect2(centre - size / 2.0, size)),
				"%s at zoom %.1f" % [screen, zoom]
			)
