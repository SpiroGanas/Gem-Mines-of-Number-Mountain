# Mirrors scenes/input/number_pad.tscn (P1-S03-05).
class_name NumberPadTest
extends GdUnitTestSuite

const SCENE_PATH: String = "res://scenes/input/number_pad.tscn"

var _pad: NumberPad
var _submitted: Array[int] = []


func before_test() -> void:
	_submitted.clear()
	_pad = load(SCENE_PATH).instantiate()
	add_child(_pad)
	auto_free(_pad)
	_pad.submitted.connect(func(value: int) -> void: _submitted.append(value))


func _tap(button: Button) -> void:
	button.pressed.emit() # what a finger, a stylus tap or a click ends up doing


func test_it_has_ten_digit_keys_plus_erase_and_go() -> void:
	for digit: int in 10:
		assert_object(_pad.digit_button(digit)).is_not_null()
		assert_str(_pad.digit_button(digit).text).is_equal(str(digit))
	assert_str(_pad.erase_button().text).is_equal(Text.get_line(&"ui.numpad.erase"))
	assert_str(_pad.go_button().text).is_equal(Text.get_line(&"ui.numpad.go"))


func test_every_key_is_at_least_the_minimum_touch_target() -> void:
	var buttons: Array[Node] = _pad.find_children("*", "Button", true, false)
	assert_int(buttons.size()).is_equal(12)
	for node: Node in buttons:
		var button: Button = node
		assert_float(button.custom_minimum_size.x).is_greater_equal(float(UI.min_target_px()))
		assert_float(button.custom_minimum_size.y).is_greater_equal(float(UI.min_target_px()))


func test_there_is_no_text_field_to_raise_the_system_keyboard() -> void:
	# CLAUDE.md rule 6: LineEdit and TextEdit (SpinBox contains a LineEdit) are forbidden in child scenes.
	for forbidden: String in ["LineEdit", "TextEdit", "SpinBox", "CodeEdit"]:
		assert_array(_pad.find_children("*", forbidden, true, false)).override_failure_message("found a " + forbidden).is_empty()


func test_tapping_keys_builds_the_number() -> void:
	_tap(_pad.digit_button(4))
	_tap(_pad.digit_button(7))
	assert_str(_pad.entry()).is_equal("47")
	assert_int(_pad.value()).is_equal(47)


func test_value_is_minus_one_when_empty() -> void:
	assert_int(_pad.value()).is_equal(-1)
	assert_str(_pad.entry()).is_empty()


func test_the_entry_stops_at_max_digits() -> void:
	_pad.max_digits = 2
	for digit: int in [1, 2, 3]:
		_pad.press_digit(digit)
	assert_str(_pad.entry()).is_equal("12")


func test_a_leading_zero_is_replaced_by_the_next_digit() -> void:
	_pad.press_digit(0)
	assert_str(_pad.entry()).is_equal("0")
	_pad.press_digit(5)
	assert_str(_pad.entry()).is_equal("5")


func test_zero_by_itself_is_a_valid_answer() -> void:
	_pad.press_digit(0)
	_pad.submit()
	assert_array(_submitted).contains_exactly([0])


func test_erase_removes_the_last_digit_and_clear_removes_all() -> void:
	_pad.press_digit(1)
	_pad.press_digit(2)
	_tap(_pad.erase_button())
	assert_str(_pad.entry()).is_equal("1")
	_pad.press_digit(9)
	_pad.clear()
	assert_str(_pad.entry()).is_empty()
	_pad.erase() # erasing nothing is fine
	assert_str(_pad.entry()).is_empty()


func test_go_is_disabled_until_something_is_entered() -> void:
	assert_bool(_pad.go_button().disabled).is_true()
	_pad.press_digit(3)
	assert_bool(_pad.go_button().disabled).is_false()
	_pad.erase()
	assert_bool(_pad.go_button().disabled).is_true()


func test_go_submits_the_number_once() -> void:
	_pad.press_digit(3)
	_pad.press_digit(4)
	_tap(_pad.go_button())
	assert_array(_submitted).contains_exactly([34])


func test_submitting_an_empty_entry_does_nothing() -> void:
	_pad.submit()
	assert_array(_submitted).is_empty()


func test_the_display_follows_the_entry() -> void:
	_pad.press_digit(8)
	var display: Label = _pad.find_children("*", "Label", true, false)[0]
	assert_str(display.text).is_equal("8")


func test_value_changed_announces_each_change() -> void:
	var seen: Array[String] = []
	_pad.value_changed.connect(func(text: String) -> void: seen.append(text))
	_pad.press_digit(1)
	_pad.press_digit(2)
	_pad.erase()
	_pad.clear()
	assert_array(seen).contains_exactly(["1", "12", "1", ""])


func test_a_disabled_pad_ignores_keys_and_greys_them_out() -> void:
	_pad.set_enabled(false)
	_pad.press_digit(5)
	_pad.submit()
	assert_str(_pad.entry()).is_empty()
	assert_bool(_pad.digit_button(5).disabled).is_true()
	_pad.set_enabled(true)
	assert_bool(_pad.digit_button(5).disabled).is_false()


func test_out_of_range_digits_are_ignored() -> void:
	_pad.press_digit(-1)
	_pad.press_digit(10)
	assert_str(_pad.entry()).is_empty()


# --- Keyboard (laptop posture) --------------------------------------------------------


func test_keyboard_digits_backspace_and_enter_work() -> void:
	InputSim.key(_pad, KEY_4)
	InputSim.key(_pad, KEY_KP_2)
	assert_str(_pad.entry()).is_equal("42")
	InputSim.key(_pad, KEY_BACKSPACE)
	assert_str(_pad.entry()).is_equal("4")
	InputSim.key(_pad, KEY_ENTER)
	assert_array(_submitted).contains_exactly([4])
	InputSim.key(_pad, KEY_KP_ENTER)
	assert_array(_submitted).contains_exactly([4, 4])


func test_other_keys_are_not_consumed() -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = KEY_A
	event.pressed = true
	assert_bool(_pad.handle_key_event(event)).is_false()
	event.keycode = KEY_5
	assert_bool(_pad.handle_key_event(event)).is_true()


func test_key_release_and_echo_are_ignored() -> void:
	InputSim.key(_pad, KEY_7, false)
	assert_str(_pad.entry()).is_empty()
	var echo: InputEventKey = InputEventKey.new()
	echo.keycode = KEY_7
	echo.pressed = true
	echo.echo = true
	assert_bool(_pad.handle_key_event(echo)).is_false()
