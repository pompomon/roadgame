extends GutTest
## The main scene and AudioDirector (IMPLEMENTATION_PLAN.md M5.3): a run plays its area's music and
## ambient sound and the engine, whose pitch follows the run's car, and the car's sounds stop when
## the scene leaves.

const MainScene := preload("res://tests/helpers/main_scene.gd")
const AudioDirectorScript := preload("res://autoload/audio_director.gd")
const CITY := preload("res://areas/city.tres")
const RUNNING := GameState.State.RUNNING


func after_each() -> void:
	GameState.quit_to_title()
	AudioDirector.stop_all()


func test_a_run_plays_its_areas_music_and_ambient_sound_and_the_engine() -> void:
	var main := MainScene.open(self, ["--seed=1"])
	assert_eq(AudioDirector.tracks(), [CITY.music, CITY.ambient_loop] as Array[AudioStream])
	assert_true(AudioDirector.is_loop_on(&"engine"))
	assert_eq(MainScene.run_while(self, main, RUNNING, 120), 120)
	var sim := MainScene.car(main).sim
	assert_gt(sim.speed, 0.0)
	AudioDirector._physics_process(MainScene.DELTA)
	var engine: AudioStreamPlayer = AudioDirector._loop_players[&"engine"]
	assert_almost_eq(engine.pitch_scale, AudioDirectorScript.engine_pitch(sim.speed), 1e-5)


func test_the_cars_sounds_stop_when_the_main_scene_leaves() -> void:
	var main := MainScene.open(self, ["--seed=1"])
	assert_eq(AudioDirector._sim, MainScene.car(main).sim, "it follows the run's car")
	main.get_parent().remove_child(main)
	assert_null(AudioDirector._sim)
	assert_false(AudioDirector.is_loop_on(&"engine"))
	main.free()
