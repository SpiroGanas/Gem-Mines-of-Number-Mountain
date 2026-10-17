# Mirrors the chalk-slate input of scenes/mine/answer_panel.gd (Sprint 14): when the slate replaces
# the number pad, and that a written answer reaches the panel the same way a typed one does.
class_name AnswerPanelSlateTest
extends GdUnitTestSuite

var _catalog: SkillCatalog
var _panel: AnswerPanel
var _fake: FakeRecognizer
var _given: Array = []
var _settings_dir: String


func before() -> void:
	_catalog = SkillCatalog.load_all()


func before_test() -> void:
	TestWindow.use_design_size(get_window())
	_given.clear()
	_fake = FakeRecognizer.new()
	_settings_dir = create_temp_dir("slate_settings_" + str(Time.get_ticks_usec()))
	DeviceSettings.use_shared(DeviceSettings.new(_settings_dir + "/device_settings.cfg"))
	_panel = load("res://scenes/mine/answer_panel.tscn").instantiate()
	_panel.size = Vector2(1100, 800)
	add_child(_panel)
	auto_free(_panel)


func after_test() -> void:
	DeviceSettings.use_shared(null)
	DigitInk.reset()
	TestWindow.restore(get_window())


func _problem(skill_id: StringName, seed_value: int = 4) -> Problem:
	return GeneratorRegistry.make_problem(_catalog.skill(skill_id), seed_value)


func _open(problem: Problem) -> void:
	_panel.slate_override = true
	_panel.recognizer = _fake
	_panel.setup(problem, RandomNumberGenerator.new())
	_panel.set_enabled(true)
	_panel.answered.connect(func(value: Variant) -> void: _given.append(value))
	await await_idle_frame()


func _write(box: DigitBox) -> void:
	var rect: Rect2 = box.get_global_rect()
	InputSim.touch(InputRouter, rect.position + rect.size * Vector2(0.3, 0.2), true)
	InputSim.drag(InputRouter, rect.position + rect.size * Vector2(0.5, 0.5))
	InputSim.drag(InputRouter, rect.position + rect.size * Vector2(0.4, 0.8))
	InputSim.touch(InputRouter, rect.position + rect.size * Vector2(0.4, 0.8), false)


func test_the_slate_takes_the_number_pads_place_only_where_the_skill_allows_handwriting() -> void:
	var numeral: Problem = _problem(&"count.write.numeral")
	assert_int(AnswerPanel.choose_input(numeral)).is_equal(AnswerPanel.InputKind.NUMBER_PAD)
	assert_int(AnswerPanel.choose_input(numeral, true)).is_equal(AnswerPanel.InputKind.SLATE)
	# a choice-button skill keeps its buttons: the slate replaces typing, not tapping
	assert_int(AnswerPanel.choose_input(_problem(&"pv.tens_ones.read"), true)).is_equal(AnswerPanel.InputKind.CHOICES)
	# a drag skill is untouched
	assert_int(AnswerPanel.choose_input(_problem(&"pv.tens_ones.build"), true)).is_equal(AnswerPanel.InputKind.BOARD)
	assert_int(AnswerPanel.choose_input(_problem(&"skip.by_2.to_40"), true)).is_equal(AnswerPanel.InputKind.TILES)


func test_a_skill_without_the_handwriting_mode_never_gets_the_slate() -> void:
	var problem: Problem = _problem(&"count.write.numeral")
	problem.answer_modes = [&"number_pad"]
	assert_int(AnswerPanel.choose_input(problem, true)).is_equal(AnswerPanel.InputKind.NUMBER_PAD)


func test_only_whole_numbers_of_one_to_three_digits_fit_the_slate() -> void:
	var problem: Problem = _problem(&"count.write.numeral")
	for answer: Variant in [0, 7, 120, 999]:
		problem.answer = answer
		assert_bool(AnswerPanel.slate_fits(problem)).override_failure_message(str(answer)).is_true()
	for answer: Variant in [1000, -3, "7", [1, 2], {"a": 1}]:
		problem.answer = answer
		assert_bool(AnswerPanel.slate_fits(problem)).override_failure_message(str(answer)).is_false()


func test_every_handwriting_skill_makes_whole_numbers_that_fit() -> void:
	var count: int = 0
	for skill: Skill in _catalog.skills_in_zone(1) + _catalog.skills_in_zone(2) + _catalog.skills_in_zone(3):
		if not skill.answer_modes.has(&"handwriting"):
			continue
		count += 1
		assert_bool(skill.answer_modes.has(&"number_pad")).override_failure_message("%s lists handwriting without number_pad" % skill.id).is_true()
		for seed_value: int in range(1, 301):
			var problem: Problem = GeneratorRegistry.make_problem(skill, seed_value)
			assert_bool(AnswerPanel.slate_fits(problem)).override_failure_message("%s seed %d: answer %s" % [skill.id, seed_value, problem.answer]).is_true()
	assert_int(count).is_equal(24)


func test_the_attempt_log_calls_the_slate_handwriting() -> void:
	assert_str(AnswerPanel.answer_mode_for_kind(AnswerPanel.InputKind.SLATE)).is_equal("handwriting")
	assert_str(AnswerPanel.answer_mode_for_kind(AnswerPanel.InputKind.NUMBER_PAD)).is_equal("number_pad")


func test_the_panel_builds_one_box_per_digit_of_the_answer() -> void:
	var problem: Problem = _problem(&"add.to_100.regroup")
	await _open(problem)
	assert_int(_panel.input_kind).is_equal(AnswerPanel.InputKind.SLATE)
	assert_object(_panel.number_pad()).is_null()
	assert_int(_panel.chalk_slate().boxes().size()).is_equal(problem.answer_digits())


func test_a_written_answer_reaches_the_panel_like_a_typed_one() -> void:
	var problem: Problem = _problem(&"add.to_20.sums", 9)
	await _open(problem)
	var queue: Array[Dictionary] = []
	for digit: String in str(problem.answer):
		queue.append({"digit": int(digit), "confidence": 0.99})
	_fake.queued = queue
	for box: DigitBox in _panel.chalk_slate().boxes():
		_write(box)
	_panel.chalk_slate().done_button().pressed.emit()
	assert_array(_given).is_equal([problem.answer])


func test_a_disabled_panel_ignores_the_slate() -> void:
	var problem: Problem = _problem(&"add.to_10.sums", 2)
	await _open(problem)
	_panel.set_enabled(false)
	_fake.queued = [{"digit": 1, "confidence": 0.99}]
	_write(_panel.chalk_slate().boxes()[0])
	_panel.chalk_slate().done_button().pressed.emit()
	assert_array(_given).is_empty()


func test_try_again_is_reported_apart_from_answers() -> void:
	await _open(_problem(&"add.to_10.sums", 2))
	var rejected: Array[int] = [0]
	_panel.rejected.connect(func() -> void: rejected[0] += 1)
	_fake.queued = [{"digit": 1, "confidence": 0.3}]
	_write(_panel.chalk_slate().boxes()[0])
	_panel.chalk_slate().done_button().pressed.emit()
	_panel.chalk_slate().confirm_bubble().try_again_button().pressed.emit()
	assert_int(rejected[0]).is_equal(1)
	assert_array(_given).is_empty()


func test_a_slate_that_cannot_read_falls_back_to_the_number_pad() -> void:
	await _open(_problem(&"add.to_10.sums", 2))
	_panel.chalk_slate().setup(1, null)
	await await_idle_frame()
	await await_idle_frame()
	assert_int(_panel.input_kind).is_equal(AnswerPanel.InputKind.NUMBER_PAD)
	assert_object(_panel.number_pad()).is_not_null()
	assert_object(_panel.chalk_slate()).is_null()


func test_without_touch_support_the_panel_keeps_the_number_pad() -> void:
	var panel: AnswerPanel = load("res://scenes/mine/answer_panel.tscn").instantiate()
	panel.size = Vector2(1100, 800)
	add_child(panel)
	auto_free(panel)
	panel.setup(_problem(&"add.to_10.sums"), RandomNumberGenerator.new())
	assert_int(panel.input_kind).is_equal(AnswerPanel.InputKind.NUMBER_PAD) # headless: no touch screen


func test_a_grown_up_can_switch_handwriting_off() -> void:
	DigitInk.availability_override = true
	assert_bool(_panel.slate_wanted()).is_true()
	DeviceSettings.shared().set_handwriting_enabled(false)
	assert_bool(_panel.slate_wanted()).is_false()
	DeviceSettings.shared().set_handwriting_enabled(true)
	assert_bool(_panel.slate_wanted()).is_true()
	DigitInk.availability_override = false
	assert_bool(_panel.slate_wanted()).is_false()
