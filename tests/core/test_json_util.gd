# Mirrors scripts/core/json_util.gd.
class_name JsonUtilTest
extends GdUnitTestSuite


func test_godot_parses_every_json_number_as_float() -> void:
	# Documents the quirk JsonUtil exists to fix. If a future Godot changes this, the
	# helper becomes a no-op and this test tells us.
	var parsed: Variant = JSON.parse_string("1")
	assert_bool(parsed is float).is_true()


func test_parse_text_turns_whole_numbers_into_ints() -> void:
	var parsed: Dictionary = JsonUtil.parse_text('{"coins": 12, "p": 0.42, "list": [1, 2.5, 3]}')
	assert_bool(parsed["coins"] is int).is_true()
	assert_int(parsed["coins"]).is_equal(12)
	assert_bool(parsed["p"] is float).is_true()
	assert_float(parsed["p"]).is_equal(0.42)
	assert_bool(parsed["list"][0] is int).is_true()
	assert_bool(parsed["list"][1] is float).is_true()


func test_parse_text_returns_null_for_invalid_json() -> void:
	assert_object(JsonUtil.parse_text("{not json")).is_null()
	assert_object(JsonUtil.parse_text("")).is_null()


func test_parse_file_returns_null_for_a_missing_file() -> void:
	assert_object(JsonUtil.parse_file("user://tests_no_such_file.json")).is_null()


func test_intify_does_not_modify_its_input() -> void:
	var original: Dictionary = {"n": 3.0, "nested": {"m": 4.0}}
	var converted: Dictionary = JsonUtil.intify(original)
	assert_bool(original["n"] is float).is_true()
	assert_bool(converted["n"] is int).is_true()
	assert_bool(converted["nested"]["m"] is int).is_true()


func test_intify_keeps_huge_floats_as_floats() -> void:
	assert_bool(JsonUtil.intify(1.0e20) is float).is_true()
	assert_bool(JsonUtil.intify(-3.0) is int).is_true()
