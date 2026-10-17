# Mirrors scenes/shell/parent_area/: the parent gate and dashboard v1 (P1-S09-03, -04, -05).
class_name ParentAreaTest
extends GdUnitTestSuite

var _dir: String
var _clock: FakeClock


func before_test() -> void:
	TestWindow.use_design_size(get_window())
	_dir = create_temp_dir("parent_" + str(Time.get_ticks_usec()))
	SaveSystem.use_directory(_dir)
	_clock = FakeClock.new()
	_clock.unix = Time.get_unix_time_from_datetime_string("2026-12-15T20:00:00")
	Adaptive.use_clock(_clock)


func after_test() -> void:
	Adaptive.use_clock(GameClock.new())
	SaveSystem.use_directory(SaveSystem.DEFAULT_DIR)
	TestWindow.restore(get_window())


func _screen(path: String) -> ShellScreen:
	var screen: ShellScreen = load(path).instantiate()
	add_child(screen)
	auto_free(screen)
	return screen


func _type(pad: NumberPad, value: int) -> void:
	pad.clear()
	for digit: String in str(value):
		pad.press_digit(int(digit))
	pad.submit()


func _copy_fixture_log() -> void:
	SaveStore.new(_dir).write_attempts(SaveStore.new(_dir).read_attempts_file("res://tests/save/fixtures/attempts_sample.jsonl"))


func test_the_right_answer_opens_the_dashboard() -> void:
	var gate: ParentGateScreen = _screen("res://scenes/shell/parent_area/parent_gate.tscn")
	assert_str(gate.question_text()).is_equal(Text.get_line(&"parent.gate.question", {"a": gate.rules.a, "b": gate.rules.b}))
	var requested: Array[StringName] = []
	gate.request_screen.connect(func(id: StringName, _args: Dictionary) -> void: requested.append(id))
	_type(gate.number_pad(), gate.rules.answer())
	assert_array(requested).contains_exactly([&"dashboard"])


func test_three_misses_lock_the_pad_without_a_countdown() -> void:
	var gate: ParentGateScreen = _screen("res://scenes/shell/parent_area/parent_gate.tscn")
	var now: Array[int] = [0]
	gate.now_ms = func() -> int: return now[0]
	for miss: int in 3:
		_type(gate.number_pad(), gate.rules.answer() + 1)
	assert_str(gate.feedback_text()).is_equal(Text.get_line(&"parent.gate.wait"))
	assert_bool(gate.number_pad().go_button().disabled).is_true()
	assert_bool(gate.feedback_text().is_valid_int()).is_false()


func test_the_dashboard_numbers_match_the_attempt_log_and_the_save() -> void:
	_copy_fixture_log()
	var skills: Dictionary = SaveSystem.data()["skills"]
	SkillRecord.ensure(skills, &"count.to_20.objects", 0.3)["mastered_at"] = "2026-12-08T10:00:00Z"
	SkillRecord.ensure(skills, &"pv.tens_ones.build", 0.3)["flagged_for_review"] = true
	var dashboard: DashboardScreen = _screen("res://scenes/shell/parent_area/dashboard.tscn")
	var texts: Array[String] = []
	for node: Node in dashboard.find_children("*", "Label", true, false):
		texts.append((node as Label).text)
	assert_array(texts).contains([
		Text.get_line(&"parent.dash.today", {"n": 1}), # 67 s on Dec 15
		Text.get_line(&"parent.dash.week", {"n": 2}), # 68 + 67 s, Dec 9 to 15
		Text.get_line(&"parent.dash.mastered", {"n": 1}),
		_catalog_name(&"count.to_20.objects"),
		Text.get_line(&"parent.dash.session_row", {"day": "2026-12-15", "minutes": 1, "rocks": 1, "percent": 0}),
		Text.get_line(&"parent.dash.session_row", {"day": "2026-12-07", "minutes": 3, "rocks": 4, "percent": 75}),
		Text.get_line(&"parent.dash.skill_reason", {"skill": _catalog_name(&"pv.tens_ones.build"), "reason": Text.get_line(&"parent.dash.reason_flagged")}),
	])


func _catalog_name(id: StringName) -> String:
	return Adaptive.catalog().skill(id).name


func test_settings_change_the_save() -> void:
	var dashboard: DashboardScreen = _screen("res://scenes/shell/parent_area/dashboard.tscn")
	dashboard.find_child("MoreButton", true, false).pressed.emit()
	assert_int(SaveSystem.data()["settings"]["session_minutes"]).is_equal(25)
	for i: int in 20:
		dashboard.find_child("LessButton", true, false).pressed.emit()
	assert_int(SaveSystem.data()["settings"]["session_minutes"]).is_equal(DashboardScreen.MIN_SESSION_MINUTES)
	dashboard.set_nickname("  Charlie  ")
	assert_str(SaveSystem.data()["child"]["nickname"]).is_equal("Charlie")
	SaveSystem.data()["placement"]["done"] = true
	dashboard.find_child("RerunButton", true, false).pressed.emit()
	assert_bool(Adaptive.needs_placement()).is_true()
	assert_str(dashboard.status_text()).is_equal(Text.get_line(&"parent.dash.rerun_done"))


func test_export_and_import_from_the_dashboard() -> void:
	SaveSystem.data()["rewards"]["coins"] = 31
	var dashboard: DashboardScreen = _screen("res://scenes/shell/parent_area/dashboard.tscn")
	var path: String = _dir.path_join("progress.json")
	assert_int(dashboard.export_to(path)).is_equal(OK)
	assert_str(dashboard.status_text()).is_equal(Text.get_line(&"parent.dash.exported", {"path": path}))
	SaveSystem.use_directory(create_temp_dir("other_" + str(Time.get_ticks_usec())))
	SaveSystem.data()["updated_at"] = "2000-01-01T00:00:00Z"
	assert_int(dashboard.import_from(path)).is_equal(OK)
	assert_int(Rewards.coins()).is_equal(31)
	assert_str(dashboard.status_text()).is_equal(Text.get_line(&"parent.dash.imported"))


func test_only_the_parent_area_has_a_text_field() -> void:
	var dashboard: DashboardScreen = _screen("res://scenes/shell/parent_area/dashboard.tscn")
	assert_array(dashboard.find_children("*", "LineEdit", true, false)).has_size(1)
