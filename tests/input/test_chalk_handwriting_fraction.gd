# The chalk slate's FRACTION and DECIMAL layouts (Phase 4, Sprint 32) with a FakeRecognizer: writing
# "3" above and "4" below hands in {num: 3, den: 4}; an unsure bottom digit asks "Did you write 3 over
# 4?"; "Try again" is never a wrong answer; decimals are written as digits around a fixed point.
class_name ChalkHandwritingFractionTest
extends GdUnitTestSuite

var _router: Node
var _slate: ChalkSlate
var _fake: FakeRecognizer
var _written: Array = []
var _rejected: int = 0


func before_test() -> void:
	TestWindow.use_design_size(get_window())
	_written.clear()
	_rejected = 0
	_router = auto_free(load("res://autoload/input_router.gd").new())
	add_child(_router)
	_fake = FakeRecognizer.new()


func after_test() -> void:
	TestWindow.restore(get_window())


func _make(layout: ChalkSlate.Layout, first: int, second: int) -> ChalkSlate:
	_slate = load("res://scenes/input/chalk_slate/chalk_slate.tscn").instantiate()
	_slate.router = _router
	_slate.size = Vector2(1200, 800)
	add_child(_slate)
	auto_free(_slate)
	_slate.answer_written.connect(func(value: Variant) -> void: _written.append(value))
	_slate.answer_rejected.connect(func() -> void: _rejected += 1)
	if layout == ChalkSlate.Layout.FRACTION:
		_slate.setup_fraction(first, second, _fake)
	else:
		_slate.setup_decimal(first, second, _fake)
	await await_idle_frame()
	return _slate


func _write(box: DigitBox) -> void:
	var rect: Rect2 = box.get_global_rect()
	InputSim.touch(_router, rect.position + rect.size * Vector2(0.3, 0.2), true)
	InputSim.drag(_router, rect.position + rect.size * Vector2(0.5, 0.5))
	InputSim.drag(_router, rect.position + rect.size * Vector2(0.4, 0.8))
	InputSim.touch(_router, rect.position + rect.size * Vector2(0.4, 0.8), false)


func _reads(digit: int, confidence: float = 0.99) -> Dictionary:
	return {"digit": digit, "confidence": confidence, "mirrored": false, "mirrored_confidence": 0.0}


func test_the_fraction_layout_has_top_boxes_a_bar_and_bottom_boxes() -> void:
	var slate: ChalkSlate = await _make(ChalkSlate.Layout.FRACTION, 2, 2)
	assert_int(slate.layout()).is_equal(ChalkSlate.Layout.FRACTION)
	assert_int(slate.boxes().size()).is_equal(4)
	var bar: ColorRect = slate.find_child("Vinculum", true, false)
	assert_object(bar).is_not_null()
	assert_int(bar.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE) # drawn, not a place to write
	var top: Rect2 = slate.boxes()[0].get_global_rect()
	var bottom: Rect2 = slate.boxes()[2].get_global_rect()
	assert_float(bottom.position.y).is_greater(top.end.y) # the bottom row is below the top row
	for box: DigitBox in slate.boxes():
		assert_float(box.size.x).is_greater_equal(1.5 * UI.min_target_px())
		assert_float(box.size.y).is_greater_equal(1.5 * UI.min_target_px())


func test_writing_3_above_and_4_below_hands_in_three_quarters() -> void:
	var slate: ChalkSlate = await _make(ChalkSlate.Layout.FRACTION, 2, 2)
	_fake.queued = [_reads(3), _reads(4)]
	_write(slate.boxes()[1]) # the ones box of the top: a blank leading box is fine
	_write(slate.boxes()[3])
	slate._on_done_pressed()
	assert_array(_written).is_equal([{"num": 3, "den": 4}])
	for box: DigitBox in slate.boxes():
		assert_bool(box.has_ink()).is_false() # the strokes go as the answer goes


func test_two_digit_tops_and_bottoms_read_whole() -> void:
	var slate: ChalkSlate = await _make(ChalkSlate.Layout.FRACTION, 2, 2)
	_fake.queued = [_reads(1), _reads(1), _reads(1), _reads(2)]
	for box: DigitBox in slate.boxes():
		_write(box)
	slate._on_done_pressed()
	assert_array(_written).is_equal([{"num": 11, "den": 12}])


func test_an_unsure_bottom_asks_did_you_write_3_over_4() -> void:
	var slate: ChalkSlate = await _make(ChalkSlate.Layout.FRACTION, 1, 1)
	_fake.queued = [_reads(3), _reads(4, 0.5)]
	_write(slate.boxes()[0])
	_write(slate.boxes()[1])
	slate._on_done_pressed()
	assert_array(_written).is_empty()
	assert_bool(slate.confirm_bubble().visible).is_true()
	assert_str(slate.confirm_bubble().question_text()).is_equal(Text.get_line(&"z7.slate.confirm_fraction", {"num": 3, "den": 4}))
	slate.confirm_bubble().yes_button().pressed.emit()
	assert_array(_written).is_equal([{"num": 3, "den": 4}])
	assert_bool(slate.last_answer_confirmed()).is_true()


func test_try_again_wipes_only_the_unsure_box_and_is_not_an_answer() -> void:
	var slate: ChalkSlate = await _make(ChalkSlate.Layout.FRACTION, 1, 1)
	_fake.queued = [_reads(3), _reads(4, 0.5)]
	_write(slate.boxes()[0])
	_write(slate.boxes()[1])
	slate._on_done_pressed()
	slate.confirm_bubble().try_again_button().pressed.emit()
	assert_int(_rejected).is_equal(1)
	assert_array(_written).is_empty()
	assert_bool(slate.boxes()[0].has_ink()).is_true()
	assert_bool(slate.boxes()[1].has_ink()).is_false()


func test_a_missing_bottom_asks_to_fill_the_boxes() -> void:
	var slate: ChalkSlate = await _make(ChalkSlate.Layout.FRACTION, 1, 1)
	_fake.queued = [_reads(3)]
	_write(slate.boxes()[0])
	slate._on_done_pressed()
	assert_array(_written).is_empty()
	assert_str(slate.message_text()).is_equal(Text.get_line(&"input.slate.fill_boxes"))


func test_the_decimal_layout_writes_digits_around_a_fixed_point() -> void:
	var slate: ChalkSlate = await _make(ChalkSlate.Layout.DECIMAL, 1, 2)
	assert_int(slate.boxes().size()).is_equal(3)
	assert_object(slate.find_child("Point", true, false)).is_not_null()
	_fake.queued = [_reads(2), _reads(7), _reads(5)]
	for box: DigitBox in slate.boxes():
		_write(box)
	slate._on_done_pressed()
	assert_array(_written).is_equal([{"mantissa": 275, "scale": 2}])


func test_a_blank_ones_box_reads_as_zero_and_trailing_zeros_drop() -> void:
	var slate: ChalkSlate = await _make(ChalkSlate.Layout.DECIMAL, 1, 2)
	_fake.queued = [_reads(5), _reads(0)]
	_write(slate.boxes()[1])
	_write(slate.boxes()[2])
	slate._on_done_pressed()
	assert_array(_written).is_equal([{"mantissa": 5, "scale": 1}]) # 0.50 is 0.5


func test_every_place_after_the_point_must_be_written() -> void:
	var slate: ChalkSlate = await _make(ChalkSlate.Layout.DECIMAL, 1, 2)
	_fake.queued = [_reads(0), _reads(5)]
	_write(slate.boxes()[0])
	_write(slate.boxes()[2]) # the tenths box left blank
	slate._on_done_pressed()
	assert_array(_written).is_empty()
	assert_str(slate.message_text()).is_equal(Text.get_line(&"input.slate.fill_boxes"))


func test_an_unsure_decimal_asks_with_its_point() -> void:
	var slate: ChalkSlate = await _make(ChalkSlate.Layout.DECIMAL, 1, 1)
	_fake.queued = [_reads(2), _reads(3, 0.4)]
	_write(slate.boxes()[0])
	_write(slate.boxes()[1])
	slate._on_done_pressed()
	assert_str(slate.confirm_bubble().question_text()).is_equal(Text.get_line(&"z7.slate.confirm_decimal", {"d": {"mantissa": 23, "scale": 1}}))
	assert_str(slate.confirm_bubble().question_text()).contains("2.3")


func test_the_row_layout_still_emits_both_signals() -> void:
	_slate = load("res://scenes/input/chalk_slate/chalk_slate.tscn").instantiate()
	_slate.router = _router
	add_child(_slate)
	auto_free(_slate)
	var plain: Array[int] = []
	_slate.answer_submitted.connect(func(value: int) -> void: plain.append(value))
	_slate.answer_written.connect(func(value: Variant) -> void: _written.append(value))
	_slate.setup(2, _fake)
	await await_idle_frame()
	_fake.queued = [_reads(4), _reads(7)]
	for box: DigitBox in _slate.boxes():
		_write(box)
	_slate._on_done_pressed()
	assert_array(plain).is_equal([47])
	assert_array(_written).is_equal([47])
