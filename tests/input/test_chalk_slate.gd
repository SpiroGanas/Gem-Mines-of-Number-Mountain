# Mirrors scenes/input/chalk_slate/chalk_slate.gd, confirm_bubble.gd and stroke_demo.gd, with a
# FakeRecognizer saying what each box "reads" (the real network is checked in tests/handwriting).
class_name ChalkSlateTest
extends GdUnitTestSuite

var _router: Node
var _slate: ChalkSlate
var _fake: FakeRecognizer
var _submitted: Array[int] = []
var _rejected: int = 0
var _digits: Array[String] = []


func before_test() -> void:
	TestWindow.use_design_size(get_window())
	_submitted.clear()
	_rejected = 0
	_digits.clear()
	_router = auto_free(load("res://autoload/input_router.gd").new())
	add_child(_router)
	_fake = FakeRecognizer.new()


func after_test() -> void:
	TestWindow.restore(get_window())


func _make(digits: int, recognizer: Recognizer = _fake) -> ChalkSlate:
	_slate = load("res://scenes/input/chalk_slate/chalk_slate.tscn").instantiate()
	_slate.router = _router
	_slate.size = Vector2(1200, 800)
	add_child(_slate)
	auto_free(_slate)
	_slate.answer_submitted.connect(func(value: int) -> void: _submitted.append(value))
	_slate.answer_rejected.connect(func() -> void: _rejected += 1)
	_slate.digit_read.connect(func(digit: int, mirrored: bool) -> void: _digits.append("%d%s" % [digit, "m" if mirrored else ""]))
	_slate.setup(digits, recognizer)
	await await_idle_frame()
	return _slate


func _write(box: DigitBox) -> void:
	var rect: Rect2 = box.get_global_rect()
	InputSim.touch(_router, rect.position + rect.size * Vector2(0.3, 0.2), true)
	InputSim.drag(_router, rect.position + rect.size * Vector2(0.5, 0.5))
	InputSim.drag(_router, rect.position + rect.size * Vector2(0.4, 0.8))
	InputSim.touch(_router, rect.position + rect.size * Vector2(0.4, 0.8), false)


func _pressed(button: Button) -> void:
	button.pressed.emit()


func test_one_box_per_digit_with_place_names_and_nothing_pre_filled() -> void:
	for digits: int in [1, 2, 3]:
		var slate: ChalkSlate = await _make(digits)
		assert_int(slate.boxes().size()).is_equal(digits)
		for box: DigitBox in slate.boxes():
			assert_bool(box.has_ink()).is_false()
			assert_float(box.size.x).is_greater_equal(2.0 * UI.min_target_px())
		slate.get_parent().remove_child(slate)
		slate.queue_free()
	var three: ChalkSlate = await _make(3)
	var captions: Array[String] = []
	for label: Node in three.find_children("*", "Label", true, false):
		captions.append((label as Label).text)
	assert_array(captions).contains([Text.get_line(&"input.slate.place_hundreds"), Text.get_line(&"input.slate.place_tens"), Text.get_line(&"input.slate.place_ones")])


func test_buttons_are_big_enough_for_a_small_hand() -> void:
	var slate: ChalkSlate = await _make(2)
	for button: Button in [slate.done_button(), slate.clear_button(), slate.confirm_bubble().yes_button()]:
		assert_float(button.custom_minimum_size.x).is_greater_equal(float(UI.min_target_px()))
		assert_float(button.custom_minimum_size.y).is_greater_equal(float(UI.min_target_px()))


func test_done_with_empty_boxes_asks_for_an_answer_and_submits_nothing() -> void:
	var slate: ChalkSlate = await _make(2)
	_pressed(slate.done_button())
	assert_array(_submitted).is_empty()
	assert_str(slate.message_text()).is_equal(Text.get_line(&"input.slate.write_first"))
	assert_int(_fake.calls).is_equal(0)


func test_two_confident_digits_are_submitted_as_one_number_and_the_strokes_are_discarded() -> void:
	var slate: ChalkSlate = await _make(2)
	_fake.queued = [{"digit": 4, "confidence": 0.99}, {"digit": 7, "confidence": 0.95}]
	_write(slate.boxes()[0])
	_write(slate.boxes()[1])
	_pressed(slate.done_button())
	assert_array(_submitted).is_equal([47])
	assert_array(_digits).is_equal(["4", "7"])
	for box: DigitBox in slate.boxes():
		assert_bool(box.has_ink()).is_false() # nothing is kept once the answer goes
	assert_bool(slate.confirm_bubble().visible).is_false()


func test_an_answer_written_in_the_ones_box_only_is_that_number() -> void:
	var slate: ChalkSlate = await _make(2)
	_fake.queued = [{"digit": 7, "confidence": 0.99}]
	_write(slate.boxes()[1])
	_pressed(slate.done_button())
	assert_array(_submitted).is_equal([7])
	assert_int(_fake.calls).is_equal(1) # only the box with ink is read


func test_a_blank_box_after_the_first_number_is_not_submitted() -> void:
	var slate: ChalkSlate = await _make(2)
	_fake.queued = [{"digit": 4, "confidence": 0.99}]
	_write(slate.boxes()[0])
	_pressed(slate.done_button())
	assert_array(_submitted).is_empty()
	assert_str(slate.message_text()).is_equal(Text.get_line(&"input.slate.fill_boxes"))
	assert_bool(slate.boxes()[1].is_flagged()).is_true()
	assert_bool(slate.boxes()[0].has_ink()).is_true() # what was written stays


func test_marks_that_are_not_a_digit_are_flagged_and_nothing_is_lost() -> void:
	var slate: ChalkSlate = await _make(1)
	_fake.queued = [{"digit": -1, "confidence": 0.0}]
	_write(slate.boxes()[0])
	_pressed(slate.done_button())
	assert_array(_submitted).is_empty()
	assert_int(_rejected).is_equal(0) # not a "Try again": nothing was asked
	assert_str(slate.message_text()).is_equal(Text.get_line(&"input.slate.unreadable"))


func test_an_unsure_digit_asks_did_you_write_and_yes_submits() -> void:
	var slate: ChalkSlate = await _make(2)
	_fake.queued = [{"digit": 4, "confidence": 0.99}, {"digit": 7, "confidence": 0.4}]
	_write(slate.boxes()[0])
	_write(slate.boxes()[1])
	_pressed(slate.done_button())
	assert_array(_submitted).is_empty()
	assert_bool(slate.confirm_bubble().visible).is_true()
	assert_str(slate.confirm_bubble().question_text()).is_equal("Did you write 47?")
	assert_bool(slate.done_button().get_parent().visible).is_false() # the question replaces Erase and Done
	_pressed(slate.confirm_bubble().yes_button())
	assert_array(_submitted).is_equal([47])
	assert_bool(slate.confirm_bubble().visible).is_false()


func test_try_again_wipes_only_the_unsure_box_and_is_not_an_answer() -> void:
	var slate: ChalkSlate = await _make(2)
	_fake.queued = [{"digit": 4, "confidence": 0.99}, {"digit": 7, "confidence": 0.4}]
	_write(slate.boxes()[0])
	_write(slate.boxes()[1])
	_pressed(slate.done_button())
	_pressed(slate.confirm_bubble().try_again_button())
	assert_array(_submitted).is_empty()
	assert_int(_rejected).is_equal(1)
	assert_bool(slate.boxes()[0].has_ink()).is_true() # the sure digit stays
	assert_bool(slate.boxes()[1].has_ink()).is_false()
	assert_bool(slate.boxes()[1].is_flagged()).is_true()
	assert_bool(slate.confirm_bubble().visible).is_false()
	assert_bool(slate.done_button().get_parent().visible).is_true()
	# writing the second box again and pressing Done reads both again
	_fake.queued = [{"digit": 4, "confidence": 0.99}, {"digit": 2, "confidence": 0.99}]
	_write(slate.boxes()[1])
	_pressed(slate.done_button())
	assert_array(_submitted).is_equal([42])


func test_erase_clears_every_box() -> void:
	var slate: ChalkSlate = await _make(2)
	_write(slate.boxes()[0])
	_write(slate.boxes()[1])
	_pressed(slate.clear_button())
	for box: DigitBox in slate.boxes():
		assert_bool(box.has_ink()).is_false()


func test_a_backwards_digit_is_reported_for_coaching() -> void:
	var slate: ChalkSlate = await _make(1)
	_fake.queued = [{"digit": 3, "confidence": 0.99, "mirrored": true}]
	_write(slate.boxes()[0])
	_pressed(slate.done_button())
	assert_array(_submitted).is_equal([3]) # a backwards 3 is still the 3 the child meant
	assert_array(_digits).is_equal(["3m"])


func test_a_disabled_slate_ignores_done_and_strokes() -> void:
	var slate: ChalkSlate = await _make(1)
	slate.set_enabled(false)
	_write(slate.boxes()[0])
	assert_bool(slate.boxes()[0].has_ink()).is_false()
	_pressed(slate.done_button())
	assert_array(_submitted).is_empty()
	slate.set_enabled(true)
	_fake.queued = [{"digit": 5, "confidence": 0.99}]
	_write(slate.boxes()[0])
	_pressed(slate.done_button())
	assert_array(_submitted).is_equal([5])


func test_without_a_recognizer_the_slate_asks_for_the_number_pad() -> void:
	_slate = load("res://scenes/input/chalk_slate/chalk_slate.tscn").instantiate()
	_slate.router = _router
	add_child(_slate)
	auto_free(_slate)
	monitor_signals(_slate)
	_slate.setup(2, null)
	await assert_signal(_slate).is_emitted("fell_back_to_number_pad")
	assert_array(_slate.boxes()).is_empty()


func test_the_stroke_demo_draws_the_digit_and_closes_with_got_it() -> void:
	var demo: StrokeDemo = load("res://scenes/input/chalk_slate/stroke_demo.tscn").instantiate()
	demo.speed_scale = 50.0
	add_child(demo)
	auto_free(demo)
	monitor_signals(demo)
	demo.play(3)
	assert_bool(demo.visible).is_true()
	assert_str(demo.title_text()).is_equal("Here is how to write 3.")
	await get_tree().create_timer(0.3).timeout
	assert_float(demo.progress()).is_equal_approx(1.0, 0.001)
	assert_float(demo.close_button().custom_minimum_size.y).is_greater_equal(float(UI.min_target_px()))
	demo.close_button().pressed.emit()
	await assert_signal(demo).is_emitted("closed")
	assert_bool(demo.visible).is_false()
