extends GutTest

var _saved_max_fps := 0


func before_each() -> void:
	_saved_max_fps = Engine.max_fps


func after_each() -> void:
	Engine.max_fps = _saved_max_fps


func test_platform_defaults_and_nonnegative_integer_overrides() -> void:
	assert_eq(FramePacing.cap(true, false, ""), Tuning.MAX_FPS)
	assert_eq(FramePacing.cap(false, true, ""), Tuning.MAX_FPS)
	assert_eq(FramePacing.cap(false, false, ""), 0)
	for wanted: int in [0, 30, 61]:
		assert_eq(FramePacing.cap(true, false, str(wanted)), wanted)
		assert_eq(FramePacing.cap(false, true, str(wanted)), wanted)
		assert_eq(FramePacing.cap(false, false, str(wanted)), wanted)
	var args := PackedStringArray(["--fpscap=0"])
	assert_eq(FramePacing.cap(true, false, ViewSwitches.value("fpscap", args, "?fpscap=30")), 0)
	assert_eq(
		FramePacing.cap(
			true, false, ViewSwitches.value("fpscap", PackedStringArray(), "?fpscap=30")
		),
		30
	)


func test_invalid_caps_report_the_error_and_keep_the_platform_default() -> void:
	for bad: String in ["-1", "1.5", "none", "2147483648"]:
		assert_eq(FramePacing.cap(true, false, bad), Tuning.MAX_FPS)
		assert_eq(FramePacing.cap(false, false, bad), 0)
	assert_push_error_count(8)


func test_native_apply_sets_the_engine_limit() -> void:
	for wanted: int in [0, 30, 60]:
		FramePacing.apply(wanted)
		assert_eq(Engine.max_fps, wanted)
	FramePacing.apply(-1)
	assert_push_error_count(1)
	assert_eq(Engine.max_fps, 0)


func test_gate_js_serializes_the_cap_and_tuning_parameters() -> void:
	var code := FramePacing.gate_js(30)
	var matched := RegEx.create_from_string("\\}\\)\\(([^;]+)\\);").search(code)
	assert_not_null(matched)
	if matched != null:
		var values := matched.get_string(1).split(",")
		assert_eq(values.size(), 10)
		assert_eq(values[0].to_int(), 30)
		assert_eq(values[1].to_int(), Tuning.GATE_STEPS)
		assert_eq(values[2].to_int(), Tuning.GATE_CALIBRATION)
		assert_eq(values[3].to_float(), Tuning.GATE_PERCENTILE)
		assert_eq(values[9].to_float(), Tuning.GATE_SHORT_MS)


func test_the_real_main_applies_the_argument_override() -> void:
	var main: Node = load("res://ui/main.tscn").instantiate()
	main.args = PackedStringArray(["--fpscap=30"])
	add_child_autofree(main)
	assert_eq(Engine.max_fps, 30)
