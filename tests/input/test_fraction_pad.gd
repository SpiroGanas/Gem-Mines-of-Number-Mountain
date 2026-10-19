# The fraction and decimal pad (Zone 7): the slate's fallback when handwriting is unavailable, and the
# answer path on mouse-only devices. No text field anywhere (CLAUDE.md rule 6); every key and box is a
# touch target; the number pad's minus key for depths below zero.
class_name FractionPadTest
extends GdUnitTestSuite

var _pad: FractionPad
var _submitted: Array[Dictionary] = []


func before_test() -> void:
	_submitted.clear()


func _make(layout: FractionPad.Layout, places: int = 1) -> FractionPad:
	_pad = load("res://scenes/input/fraction_pad.tscn").instantiate()
	_pad.layout = layout
	_pad.box_digits = 2
	_pad.decimal_places = places
	add_child(_pad)
	auto_free(_pad)
	_pad.submitted.connect(func(value: Dictionary) -> void: _submitted.append(value))
	return _pad


func _type(text: String) -> void:
	for character: String in text:
		_pad.press_digit(int(character))


func test_top_go_bottom_go_hands_in_the_fraction() -> void:
	var pad: FractionPad = _make(FractionPad.Layout.FRACTION)
	_type("3")
	pad.keys().go_button().pressed.emit() # Go on the top moves to the bottom
	assert_int(pad.active_box()).is_equal(1)
	assert_array(_submitted).is_empty()
	_type("4")
	pad.keys().go_button().pressed.emit()
	assert_array(_submitted).is_equal([{"num": 3, "den": 4}])


func test_tapping_a_box_chooses_where_the_keys_type() -> void:
	var pad: FractionPad = _make(FractionPad.Layout.FRACTION)
	pad.box(1).pressed.emit()
	_type("12")
	pad.box(0).pressed.emit()
	_type("5")
	assert_array(pad.texts()).is_equal(["5", "12"])
	pad.go()
	assert_array(_submitted).is_equal([{"num": 5, "den": 12}])


func test_go_with_an_empty_box_moves_there_instead_of_answering() -> void:
	var pad: FractionPad = _make(FractionPad.Layout.FRACTION)
	pad.box(1).pressed.emit()
	_type("8")
	pad.go()
	assert_array(_submitted).is_empty()
	assert_int(pad.active_box()).is_equal(0)


func test_each_box_takes_at_most_two_digits() -> void:
	var pad: FractionPad = _make(FractionPad.Layout.FRACTION)
	_type("123")
	assert_array(pad.texts()).is_equal(["12", ""])


func test_the_decimal_layout_fills_missing_places_with_zeros() -> void:
	var pad: FractionPad = _make(FractionPad.Layout.DECIMAL, 2)
	_type("2")
	pad.go()
	_type("7")
	pad.go()
	assert_array(_submitted).is_equal([{"mantissa": 27, "scale": 1}]) # 2.70 is 2.7
	assert_object(pad.find_child("Point", true, false)).is_not_null()


func test_keys_and_boxes_are_touch_targets_and_there_is_no_text_field() -> void:
	var pad: FractionPad = _make(FractionPad.Layout.FRACTION)
	for node: Node in pad.find_children("*", "Button", true, false):
		var button: Button = node
		assert_float(button.custom_minimum_size.x).is_greater_equal(float(UI.min_target_px()))
		assert_float(button.custom_minimum_size.y).is_greater_equal(float(UI.min_target_px()))
	assert_array(pad.find_children("*", "LineEdit", true, false)).is_empty()
	assert_array(pad.find_children("*", "TextEdit", true, false)).is_empty()


func test_the_number_pad_minus_key_flips_the_sign() -> void:
	var numbers: NumberPad = load("res://scenes/input/number_pad.tscn").instantiate()
	numbers.allow_negative = true
	add_child(numbers)
	auto_free(numbers)
	var got: Array[int] = []
	numbers.submitted.connect(func(value: int) -> void: got.append(value))
	assert_object(numbers.minus_button()).is_not_null()
	assert_float(numbers.minus_button().custom_minimum_size.x).is_greater_equal(float(UI.min_target_px()))
	numbers.press_digit(1)
	numbers.press_digit(5)
	numbers.minus_button().pressed.emit()
	assert_str(numbers.entry()).is_equal("-15")
	numbers.submit()
	numbers.minus_button().pressed.emit()
	numbers.submit()
	assert_array(got).is_equal([-15, 15])


func test_a_lone_minus_is_not_an_answer_and_the_keyboard_minus_works() -> void:
	var numbers: NumberPad = load("res://scenes/input/number_pad.tscn").instantiate()
	numbers.allow_negative = true
	add_child(numbers)
	auto_free(numbers)
	var got: Array[int] = []
	numbers.submitted.connect(func(value: int) -> void: got.append(value))
	var minus: InputEventKey = InputEventKey.new()
	minus.keycode = KEY_MINUS
	minus.pressed = true
	assert_bool(numbers.handle_key_event(minus)).is_true()
	numbers.submit()
	assert_array(got).is_empty()
	numbers.press_digit(7)
	numbers.submit()
	assert_array(got).is_equal([-7])


func test_a_plain_number_pad_has_no_minus_key() -> void:
	var numbers: NumberPad = load("res://scenes/input/number_pad.tscn").instantiate()
	add_child(numbers)
	auto_free(numbers)
	assert_object(numbers.minus_button()).is_null()
	var minus: InputEventKey = InputEventKey.new()
	minus.keycode = KEY_MINUS
	minus.pressed = true
	assert_bool(numbers.handle_key_event(minus)).is_false()
