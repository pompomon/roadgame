extends GutTest
## The main scene and AudioDirector (IMPLEMENTATION_PLAN.md M5.3): a run plays its area's music and
## ambient sound and the engine, whose pitch follows the run's car, and the car's sounds stop when
## the scene leaves. A pit stop's repair dings (ENDGAME_PLAN.md §5.15).

const MainScene := preload("res://tests/helpers/main_scene.gd")
const AudioDirectorScript := preload("res://autoload/audio_director.gd")
const CITY := preload("res://areas/city.tres")
const RUNNING := GameState.State.RUNNING
## The car's health as the run starts, for a pit stop to repair.
const HURT := 40.0


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


## A run from the Village meets the Desert after seed 1's turn 20 (test_area_start.gd), and the
## Desert's first straight, by Last Gas, is a pit stop (ENDGAME_PLAN.md §5.15): the car, hurt,
## drives out of it repaired, with a ding, and the HUD's health bar rises.
func test_a_pit_stop_in_a_run_repairs_the_car_with_a_ding() -> void:
	watch_signals(AudioDirector)
	var main := MainScene.open(self, ["--seed=1", "--area=village", "--autopilot"])
	var sim := MainScene.car(main).sim
	sim.health = HURT
	for frame: int in 60 * 60:
		if GameState.turn_index > 20 or GameState.state != RUNNING:
			break
		simulate(main, 1, MainScene.DELTA)
	assert_eq(GameState.state, RUNNING)
	assert_eq(sim.area.id, &"desert")
	assert_eq(sim.health, HURT + Tuning.PIT_STOP_HEAL)
	var bar: ProgressBar = main.get_node("%HUD/%Health")
	assert_eq(bar.value, HURT + Tuning.PIT_STOP_HEAL)
	var played: Array[StringName] = []
	for i: int in get_signal_emit_count(AudioDirector, "effect_played"):
		played.append(get_signal_parameters(AudioDirector, "effect_played", i)[0])
	assert_eq(played.count(&"repair"), 1, "one ding")
