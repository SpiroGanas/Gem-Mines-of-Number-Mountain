# Keyboard entry (Scholar mode part 1, Sprint 37, P4-S37-04): digits, slash, period, minus, Backspace and
# Enter; invalid keys are ignored; it is never a text field; and the Zone 8 pads (scientific notation,
# base digits) take what the number pad cannot.
class_name KeyboardEntryTest
extends GdUnitTestSuite


func before_test() -> void:
	TestWindow.use_design_size(get_window())


func after_test() -> void:
	TestWindow.restore(get_window())


func _entry(kind: KeyboardEntry.Kind, setup: Callable = Callable()) -> KeyboardEntry:
	var entry: KeyboardEntry = load("res://scenes/input/keyboard_entry.tscn").instantiate()
	entry.kind = kind
	if setup.is_valid():
		setup.call(entry)
	add_child(entry)
	auto_free(entry)
	return entry


func _type(entry: KeyboardEntry, keys: String) -> void:
	for character: String in keys:
		entry.handle_key_event(PanelDriver.key_event(character))


func _given(entry: KeyboardEntry) -> Array:
	var given: Array = []
	entry.submitted.connect(func(value: Variant) -> void: given.append(value))
	return given


func test_it_is_not_a_text_field() -> void:
	var entry: KeyboardEntry = _entry(KeyboardEntry.Kind.INTEGER)
	assert_str(entry.get_class()).is_equal("VBoxContainer") # a plain container, not a text field
	assert_int(entry.find_children("*", "LineEdit", true, false).size() + entry.find_children("*", "TextEdit", true, false).size()).is_equal(0)


func test_digits_backspace_and_enter() -> void:
	var entry: KeyboardEntry = _entry(KeyboardEntry.Kind.INTEGER)
	var given: Array = _given(entry)
	_type(entry, "128")
	entry.handle_key_event(_key(KEY_BACKSPACE))
	assert_str(entry.entry()).is_equal("12")
	_type(entry, "5\n")
	assert_array(given).is_equal([125])


func test_invalid_keys_are_ignored() -> void:
	var entry: KeyboardEntry = _entry(KeyboardEntry.Kind.INTEGER)
	for key: Key in [KEY_A, KEY_SLASH, KEY_PERIOD, KEY_MINUS, KEY_SPACE, KEY_VOLUMEUP]:
		assert_bool(entry.handle_key_event(_key(key))).is_false()
	assert_str(entry.entry()).is_equal("")
	var given: Array = _given(entry)
	entry.handle_key_event(_key(KEY_ENTER)) # nothing typed: nothing handed in
	assert_array(given).is_empty()


func test_minus_flips_the_sign_when_allowed() -> void:
	var entry: KeyboardEntry = _entry(KeyboardEntry.Kind.INTEGER, func(e: KeyboardEntry) -> void: e.allow_negative = true)
	var given: Array = _given(entry)
	_type(entry, "15-\n")
	assert_array(given).is_equal([-15])


func test_slash_makes_a_fraction_and_period_a_decimal() -> void:
	var fraction: KeyboardEntry = _entry(KeyboardEntry.Kind.FRACTION, func(e: KeyboardEntry) -> void: e.max_digits = 2)
	var fractions: Array = _given(fraction)
	_type(fraction, "3/4\n")
	assert_array(fractions).is_equal([{"num": 3, "den": 4}])
	var decimal: KeyboardEntry = _entry(KeyboardEntry.Kind.DECIMAL, func(e: KeyboardEntry) -> void: e.max_digits = 4)
	var decimals: Array = _given(decimal)
	_type(decimal, "2.50\n")
	assert_array(decimals).is_equal([{"mantissa": 25, "scale": 1}])


func test_scientific_notation_and_bases() -> void:
	var sci: KeyboardEntry = _entry(KeyboardEntry.Kind.SCI)
	var values: Array = _given(sci)
	_type(sci, "3.4^5\n")
	assert_array(values).is_equal([{"mantissa": 34, "scale": 1, "exp": 5}])
	sci.clear()
	_type(sci, "34^4\n") # what a child who did not normalize types: kept as typed, judged by the problem
	assert_dict(values[1]).is_equal({"mantissa": 34, "scale": 0, "exp": 4})
	var binary: KeyboardEntry = _entry(KeyboardEntry.Kind.BASE, func(e: KeyboardEntry) -> void:
		e.base = 2
		e.max_digits = 6)
	var bits: Array = _given(binary)
	_type(binary, "0121") # 2 is not a binary digit
	assert_str(binary.entry()).is_equal("011")
	binary.handle_key_event(_key(KEY_ENTER))
	assert_array(bits).is_equal([{"base": 2, "digits": [1, 1]}])


func test_use_the_pad_asks_the_host() -> void:
	var entry: KeyboardEntry = _entry(KeyboardEntry.Kind.INTEGER)
	var asked: Array = [0]
	entry.pad_requested.connect(func() -> void: asked[0] += 1)
	entry.use_pad_button().pressed.emit()
	assert_int(asked[0]).is_equal(1)
	assert_float(entry.use_pad_button().custom_minimum_size.y).is_greater_equal(float(UI.min_target_px()))


func test_the_sci_pad_types_into_its_boxes() -> void:
	var pad: PowerPad = load("res://scenes/input/power_pad.tscn").instantiate()
	pad.layout = PowerPad.Layout.SCI
	add_child(pad)
	auto_free(pad)
	var given: Array = []
	pad.submitted.connect(func(value: Dictionary) -> void: given.append(value))
	for digit: int in [3, 4, 5]:
		pad.press_digit(digit)
	assert_array(pad.texts()).is_equal(["3", "4", "5"])
	pad.go()
	assert_array(given).is_equal([{"mantissa": 34, "scale": 1, "exp": 5}])


func test_the_base_pad_has_only_the_bases_digits() -> void:
	var pad: PowerPad = load("res://scenes/input/power_pad.tscn").instantiate()
	pad.layout = PowerPad.Layout.BASE
	pad.base = 2
	pad.places = 6
	add_child(pad)
	auto_free(pad)
	assert_object(pad.base_key(1)).is_not_null()
	assert_object(pad.base_key(2)).is_null()
	var given: Array = []
	pad.submitted.connect(func(value: Dictionary) -> void: given.append(value))
	for digit: int in [0, 1, 0, 2, 1, 1]:
		pad.press_digit(digit)
	pad.go()
	assert_array(given).is_equal([{"base": 2, "digits": [1, 0, 1, 1]}])
	await await_idle_frame()
	var needed: Vector2 = pad.get_combined_minimum_size() / float(UI.min_target_px())
	assert_float(needed.y).is_less_equal(4.6) # fits a landscape phone


func _key(keycode: Key) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	return event
