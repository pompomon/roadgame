extends GutTest
## The shadows in the game (docs/DAYNIGHT.md §5.11): World lays them by the clock that Daylight
## keeps for the zone.

const MainScene := preload("res://tests/helpers/main_scene.gd")


func after_each() -> void:
	GameState.quit_to_title()
	AudioDirector.stop_all()


func test_the_props_and_the_car_cast_shadows_by_the_zones_clock() -> void:
	var main := MainScene.open(self, ["--hour=9"])
	simulate(main, 1, MainScene.DELTA)
	var before := MainScene.car(main).position
	simulate(main, 1, MainScene.DELTA)
	var world: WorldRenderer = main.get_node("%World")
	var daylight: Daylight = main.get_node("%Daylight")
	assert_same(world.cycle, daylight.cycle, "the zone's clock")
	var shadows: Shadows = world.get_node("%Shadows")
	assert_true(shadows.visible, "by day")
	assert_gt(daylight.cycle.shadow_alpha, 0.0)
	assert_almost_eq(shadows.self_modulate.a, daylight.cycle.shadow_alpha, 1e-6)
	var cast := shadows.car_cast()
	assert_not_null(cast, "the car's")
	if cast != null:
		assert_true(cast.sprite.visible)
		# simulate() steps World before the car it holds, so World saw the car before its step.
		assert_eq(cast.foot, before, "under the car")
		assert_ne(MainScene.car(main).position, before, "which drives")
	assert_gt(shadows.count(), 10, "the props' and the car's")
