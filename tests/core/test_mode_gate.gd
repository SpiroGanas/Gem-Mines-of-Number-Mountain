# Scholar mode's gate (Phase 4, Sprint 37, P4-S37-03): every branch of ModeGate.is_enabled, the
# grade-to-reading-level stand-in for "auto", and ScholarMode reading the child's setting and the
# keyboard (conservative: typing only after a real key press).
class_name ModeGateTest
extends GdUnitTestSuite

const F := ModeGate.Feature

var _dir: String


func before_test() -> void:
	_dir = create_temp_dir("mode_gate_" + str(Time.get_ticks_usec()))
	SaveSystem.use_directory(_dir)
	ScholarMode.reset_overrides()
	InputRouter.reset_keyboard()


func after_test() -> void:
	ScholarMode.reset_overrides()
	InputRouter.reset_keyboard()
	SaveSystem.use_directory(SaveSystem.DEFAULT_DIR)


func test_explorer_turns_every_feature_off() -> void:
	for feature: int in F.values():
		for level: int in range(0, 4):
			for keyboard: bool in [false, true]:
				assert_bool(ModeGate.is_enabled(feature, "explorer", level, keyboard)).is_false()


func test_scholar_turns_every_feature_on_but_typing_needs_a_keyboard() -> void:
	for level: int in range(0, 4):
		assert_bool(ModeGate.is_enabled(F.MATH_NOTATION, "scholar", level, false)).is_true()
		assert_bool(ModeGate.is_enabled(F.LONGER_TEXT, "scholar", level, false)).is_true()
		assert_bool(ModeGate.is_enabled(F.REDUCED_NARRATION, "scholar", level, false)).is_true()
		assert_bool(ModeGate.is_enabled(F.KEYBOARD_ENTRY, "scholar", level, false)).is_false()
		assert_bool(ModeGate.is_enabled(F.KEYBOARD_ENTRY, "scholar", level, true)).is_true()


func test_auto_goes_by_reading_level() -> void:
	assert_bool(ModeGate.is_enabled(F.KEYBOARD_ENTRY, "auto", 1, true)).is_false()
	assert_bool(ModeGate.is_enabled(F.KEYBOARD_ENTRY, "auto", 2, false)).is_false()
	assert_bool(ModeGate.is_enabled(F.KEYBOARD_ENTRY, "auto", 2, true)).is_true()
	assert_bool(ModeGate.is_enabled(F.MATH_NOTATION, "auto", 1, true)).is_false()
	assert_bool(ModeGate.is_enabled(F.MATH_NOTATION, "auto", 2, false)).is_true()
	assert_bool(ModeGate.is_enabled(F.LONGER_TEXT, "auto", 2, true)).is_false()
	assert_bool(ModeGate.is_enabled(F.LONGER_TEXT, "auto", 3, false)).is_true()
	assert_bool(ModeGate.is_enabled(F.REDUCED_NARRATION, "auto", 2, false)).is_false()
	assert_bool(ModeGate.is_enabled(F.REDUCED_NARRATION, "auto", 3, false)).is_true()


func test_the_grade_stands_in_for_reading_checks_conservatively() -> void:
	assert_int(ModeGate.reading_level_for_grade(0)).is_equal(0)
	assert_int(ModeGate.reading_level_for_grade(1)).is_equal(0) # Charlie's grade: Explorer even on auto
	assert_int(ModeGate.reading_level_for_grade(2)).is_equal(1)
	assert_int(ModeGate.reading_level_for_grade(3)).is_equal(2)
	assert_int(ModeGate.reading_level_for_grade(4)).is_equal(3)
	assert_int(ModeGate.reading_level_for_grade(6)).is_equal(3)
	assert_str(ModeGate.clean_setting("scholar")).is_equal("scholar")
	assert_str(ModeGate.clean_setting("wizard")).is_equal("explorer") # unknown: the safe default


func test_scholar_mode_reads_the_childs_setting_and_grade() -> void:
	var settings: Dictionary = SaveSystem.data()["settings"]
	assert_str(ScholarMode.setting()).is_equal("explorer") # every save starts in Explorer mode
	assert_bool(ScholarMode.is_on(F.MATH_NOTATION)).is_false()
	settings["interface_mode"] = "auto"
	settings["starting_grade"] = 3
	assert_bool(ScholarMode.is_on(F.MATH_NOTATION)).is_true()
	assert_bool(ScholarMode.is_on(F.LONGER_TEXT)).is_false()
	settings["starting_grade"] = 1
	assert_bool(ScholarMode.is_on(F.MATH_NOTATION)).is_false()
	settings["interface_mode"] = "scholar"
	assert_bool(ScholarMode.is_on(F.LONGER_TEXT)).is_true()


func test_typing_waits_for_a_real_key_press() -> void:
	SaveSystem.data()["settings"]["interface_mode"] = "scholar"
	assert_bool(InputRouter.has_keyboard()).is_false()
	assert_bool(ScholarMode.is_on(F.KEYBOARD_ENTRY)).is_false()
	# A tablet's volume buttons and a lone modifier are not a keyboard.
	for key: Key in [KEY_VOLUMEUP, KEY_VOLUMEDOWN, KEY_SHIFT, KEY_ESCAPE, KEY_BACK]:
		InputRouter.process_event(_key(key))
	assert_bool(InputRouter.has_keyboard()).is_false()
	var seen: Array[bool] = [false]
	InputRouter.keyboard_detected.connect(func() -> void: seen[0] = true, CONNECT_ONE_SHOT)
	InputRouter.process_event(_key(KEY_7))
	assert_bool(seen[0]).is_true()
	assert_bool(InputRouter.has_keyboard()).is_true()
	assert_bool(ScholarMode.is_on(F.KEYBOARD_ENTRY)).is_true()


func _key(keycode: Key) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	return event
