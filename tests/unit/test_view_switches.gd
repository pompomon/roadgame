extends GutTest


func test_switches_in_arguments_and_the_query_match_whole_names() -> void:
	var args := PackedStringArray(["--fpscap=0", "--stretch=viewport"])
	assert_false(ViewSwitches.has("fps", args, "?fpscap=60"))
	assert_true(ViewSwitches.has("fpscap", args, ""))
	assert_eq(ViewSwitches.value("stretch", args, ""), "viewport")
	assert_true(ViewSwitches.has("fps", PackedStringArray(["--fps"]), ""))
	assert_true(ViewSwitches.has("fps", PackedStringArray(), "?fps"))
	assert_false(ViewSwitches.has("fps", PackedStringArray(), "?notfps"))
	assert_eq(
		ViewSwitches.value("stretch", PackedStringArray(), "?fps&stretch=canvas_items"),
		"canvas_items"
	)


func test_arguments_win_even_when_their_value_is_empty() -> void:
	assert_eq(ViewSwitches.value("fpscap", PackedStringArray(["--fpscap=0"]), "?fpscap=60"), "0")
	assert_eq(
		ViewSwitches.value("stretch", PackedStringArray(["--stretch"]), "?stretch=viewport"), ""
	)
	assert_eq(ViewSwitches.value("stretch", PackedStringArray(), ""), "")


func test_query_values_are_url_decoded_without_dropping_equals() -> void:
	assert_eq(
		ViewSwitches.value("stretch", PackedStringArray(), "?str%65tch=canvas%5Fitems"),
		"canvas_items"
	)
	assert_eq(ViewSwitches.value("name", PackedStringArray(), "?name=a%2Bb+c%3Dd"), "a+b c=d")
