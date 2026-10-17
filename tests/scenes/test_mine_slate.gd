# Mirrors the handwriting path of scenes/mine/mine.gd (Sprint 14): a written answer is a normal
# answer; "Try again" to "Did you write 47?" is logged apart and changes nothing the engine knows.
class_name MineSlateTest
extends GdUnitTestSuite

const SKILL: StringName = &"add.to_20.sums"

var _mine: MineScreen
var _fake: FakeRecognizer


func before_test() -> void:
	TestWindow.use_design_size(get_window())
	var dir: String = create_temp_dir("mine_slate_" + str(Time.get_ticks_usec()))
	SaveSystem.use_directory(dir)
	DeviceSettings.use_shared(DeviceSettings.new(dir + "/device_settings.cfg"))
	_fake = FakeRecognizer.new()
	DigitInk.availability_override = true
	DigitInk.recognizer_override = _fake
	_mine = load("res://scenes/mine/mine.tscn").instantiate()
	_mine.animation_speed = 25.0
	_mine.seed_value = 777
	_mine.skill_ids = [SKILL]
	add_child(_mine)
	auto_free(_mine)


func after_test() -> void:
	get_tree().paused = false
	DigitInk.reset()
	DeviceSettings.use_shared(null)
	SaveSystem.use_directory(SaveSystem.DEFAULT_DIR)
	TestWindow.restore(get_window())


func _until(condition: Callable, max_frames: int = 600) -> void:
	var frames: int = 0
	while not condition.call() and frames < max_frames:
		await get_tree().process_frame
		frames += 1
	assert_bool(condition.call()).override_failure_message("timed out (state %s)" % DigFlow.State.keys()[_mine.flow.state]).is_true()


func _open(index: int) -> void:
	_mine.wall().rock(index).pressed.emit()
	await _until(func() -> bool: return _mine.flow.state == DigFlow.State.AWAIT_ANSWER)
	await await_idle_frame()


func _write(box: DigitBox) -> void:
	var rect: Rect2 = box.get_global_rect()
	InputSim.touch(InputRouter, rect.position + rect.size * Vector2(0.3, 0.2), true)
	InputSim.drag(InputRouter, rect.position + rect.size * Vector2(0.5, 0.5))
	InputSim.drag(InputRouter, rect.position + rect.size * Vector2(0.4, 0.8))
	InputSim.touch(InputRouter, rect.position + rect.size * Vector2(0.4, 0.8), false)


## Writes `value` digit by digit (the fake recognizer reads each box as the digit meant).
func _write_number(value: int, confidence: float = 0.99, mirrored: bool = false) -> void:
	var slate: ChalkSlate = _mine.answer_panel().chalk_slate()
	var queue: Array[Dictionary] = []
	for digit: String in str(value):
		queue.append({"digit": int(digit), "confidence": confidence, "mirrored": mirrored})
	_fake.queued = queue
	for box: DigitBox in slate.boxes():
		_write(box)
	slate.done_button().pressed.emit()


func test_the_mine_shows_the_slate_when_the_device_can_read_handwriting() -> void:
	await _open(0)
	assert_int(_mine.answer_panel().input_kind).is_equal(AnswerPanel.InputKind.SLATE)


func test_a_written_correct_answer_cracks_the_rock_and_is_logged_as_handwriting() -> void:
	await _open(0)
	_write_number(_mine.current_problem().answer)
	await _until(func() -> bool: return _mine.flow.state == DigFlow.State.PICK_ROCK)
	var entries: Array = SaveSystem.read_attempts()["entries"]
	assert_int(entries.size()).is_equal(1)
	assert_str(entries[0]["answer_mode"]).is_equal("handwriting")
	assert_bool(entries[0]["correct"]).is_true()
	assert_bool(entries[0]["low_confidence_rejected"]).is_false()


func test_a_written_wrong_answer_is_just_not_quite() -> void:
	await _open(0)
	var wrong: int = _mine.current_problem().answer + 1
	_write_number(wrong)
	await _until(func() -> bool: return _mine.flow.state == DigFlow.State.AWAIT_ANSWER and _mine.flow.wrong_count() == 1)
	assert_bool(_mine.current_problem().is_correct(wrong)).is_false()
	assert_int(SaveSystem.data()["skills"][String(SKILL)]["attempts"]).is_equal(1)


func test_try_again_changes_nothing_the_engine_knows() -> void:
	await _open(0)
	var before: Dictionary = SaveSystem.data()["skills"].get(String(SKILL), {}).duplicate(true)
	_write_number(_mine.current_problem().answer, 0.3) # unsure: Bolt asks
	var slate: ChalkSlate = _mine.answer_panel().chalk_slate()
	assert_bool(slate.confirm_bubble().visible).is_true()
	slate.confirm_bubble().try_again_button().pressed.emit()
	assert_int(_mine.flow.state).is_equal(DigFlow.State.AWAIT_ANSWER)
	assert_int(_mine.flow.wrong_count()).is_equal(0) # no hint rung climbed
	var entries: Array = SaveSystem.read_attempts()["entries"]
	assert_int(entries.size()).is_equal(1)
	assert_bool(entries[0]["low_confidence_rejected"]).is_true()
	assert_bool(entries[0]["correct"]).is_false()
	assert_str(entries[0]["answer_mode"]).is_equal("handwriting")
	var after: Dictionary = SaveSystem.data()["skills"].get(String(SKILL), {})
	assert_dict(after).is_equal(before) # P(L), attempts, evidence and days: untouched
	# and the same rock can still be answered, first try included
	_write_number(_mine.current_problem().answer)
	await _until(func() -> bool: return _mine.flow.state == DigFlow.State.PICK_ROCK)
	assert_int(SaveSystem.data()["skills"][String(SKILL)]["attempts"]).is_equal(1)


func test_rejected_readings_are_not_misses_in_the_dashboard_numbers() -> void:
	await _open(0)
	_write_number(_mine.current_problem().answer, 0.3)
	_mine.answer_panel().chalk_slate().confirm_bubble().try_again_button().pressed.emit()
	_write_number(_mine.current_problem().answer)
	await _until(func() -> bool: return _mine.flow.state == DigFlow.State.PICK_ROCK)
	var entries: Array = SaveSystem.read_attempts()["entries"]
	assert_int(entries.size()).is_equal(2)
	var sessions: Array[Dictionary] = ProgressReport.sessions(entries)
	assert_int(sessions[0]["answers"]).is_equal(1)
	assert_int(sessions[0]["first_tries"]).is_equal(1)
	assert_int(ProgressReport.first_try_percent(sessions[0])).is_equal(100)
	assert_array(Adaptive.engine.struggling(entries)).is_empty()


func test_numeral_coaching_shows_the_demo_on_the_third_backwards_digit_only_when_switched_on() -> void:
	SaveSystem.data()["settings"]["handwriting_coaching"] = true
	var shown: Array[bool] = [false]
	for rock: int in 3:
		await _open(rock)
		var problem: Problem = _mine.current_problem()
		_fake.queued = [{"digit": 3, "confidence": 0.99, "mirrored": true}]
		var slate: ChalkSlate = _mine.answer_panel().chalk_slate()
		# a one-digit stand-in answer: the coach counts the backwards 3 whatever the answer was
		if slate.boxes().size() != 1:
			slate.setup(1, _fake)
			await await_idle_frame()
		_write(slate.boxes()[0])
		slate.done_button().pressed.emit()
		await _until(func() -> bool: return _mine.flow.state == DigFlow.State.AWAIT_ANSWER or _mine.flow.state == DigFlow.State.PICK_ROCK)
		if rock == 2 and problem.answer != 3:
			shown[0] = _mine.find_children("*", "StrokeDemo", true, false).size() > 0
	assert_bool(shown[0]).is_true()


func test_with_coaching_off_no_demo_ever_shows() -> void:
	for rock: int in 3:
		await _open(rock)
		_fake.queued = [{"digit": 3, "confidence": 0.99, "mirrored": true}]
		var slate: ChalkSlate = _mine.answer_panel().chalk_slate()
		if slate.boxes().size() != 1:
			slate.setup(1, _fake)
			await await_idle_frame()
		_write(slate.boxes()[0])
		slate.done_button().pressed.emit()
		await _until(func() -> bool: return _mine.flow.state == DigFlow.State.AWAIT_ANSWER or _mine.flow.state == DigFlow.State.PICK_ROCK)
	assert_array(_mine.find_children("*", "StrokeDemo", true, false)).is_empty()
