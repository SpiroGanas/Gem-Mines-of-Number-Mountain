# Mirrors parent dashboard v2 (Sprint 21, P2-S21-01): the skill map matches Adaptive's state on a
# seeded save, and the weekly summary (with the handwriting confirmation rate) matches the log.
class_name DashboardV2Test
extends GdUnitTestSuite

var _dir: String
var _clock: FakeClock


func before_test() -> void:
	TestWindow.use_design_size(get_window())
	_dir = create_temp_dir("dashboard_v2_" + str(Time.get_ticks_usec()))
	SaveSystem.use_directory(_dir)
	_clock = FakeClock.new()
	_clock.unix = Time.get_unix_time_from_datetime_string("2027-04-07T18:00:00")
	Adaptive.use_clock(_clock)


func after_test() -> void:
	Adaptive.use_clock(GameClock.new())
	SaveSystem.use_directory(SaveSystem.DEFAULT_DIR)
	TestWindow.restore(get_window())


func _seed() -> void:
	var skills: Dictionary = SaveSystem.data()["skills"]
	var mastered: Dictionary = SkillRecord.fresh(0.97)
	mastered["mastered_at"] = "2027-04-05T17:00:00Z"
	mastered["attempts"] = 12
	skills["add.to_10.sums"] = mastered
	var old: Dictionary = SkillRecord.fresh(0.97)
	old["mastered_at"] = "2027-02-01T17:00:00Z" # mastered weeks ago
	old["attempts"] = 9
	skills["count.to_20.objects"] = old
	var flagged: Dictionary = SkillRecord.fresh(0.5)
	flagged["attempts"] = 6
	flagged["flagged_for_review"] = true
	skills["sub.to_10.diff"] = flagged
	var practicing: Dictionary = SkillRecord.fresh(0.4)
	practicing["attempts"] = 3
	skills["pv.tens_ones.read"] = practicing
	var lines: Array[Dictionary] = [
		{"ts": "2027-04-06T17:00:00Z", "session_id": "s1", "skill_id": "add.to_10.sums", "answer_mode": "handwriting", "correct": true, "hints_used": 0, "latency_ms": 4000, "confirmed": true},
		{"ts": "2027-04-06T17:01:00Z", "session_id": "s1", "skill_id": "add.to_10.sums", "answer_mode": "handwriting", "correct": true, "hints_used": 0, "latency_ms": 4000},
		{"ts": "2027-04-06T17:02:00Z", "session_id": "s1", "skill_id": "add.to_10.sums", "answer_mode": "handwriting", "correct": false, "hints_used": 0, "latency_ms": 4000, "low_confidence_rejected": true},
		{"ts": "2027-04-06T17:03:00Z", "session_id": "s1", "skill_id": "add.to_10.sums", "answer_mode": "handwriting", "correct": true, "hints_used": 0, "latency_ms": 4000},
		{"ts": "2027-04-07T17:00:00Z", "session_id": "s2", "skill_id": "pv.tens_ones.read", "answer_mode": "tap", "correct": true, "hints_used": 0, "latency_ms": 4000},
		{"ts": "2027-03-01T17:00:00Z", "session_id": "s0", "skill_id": "count.to_20.objects", "answer_mode": "handwriting", "correct": true, "hints_used": 0, "latency_ms": 4000, "confirmed": true},
	]
	for entry: Dictionary in lines:
		SaveSystem.append_attempt(Attempt.from_json(entry))


## Peer review 05: the web build has no way to hand a progress file to or from the computer's disk, so it shows a note
## where the app shows Export and Import (the privacy policy says the same).
func test_the_web_version_offers_no_progress_file() -> void:
	_seed()
	DashboardScreen.pretend_web = true
	var web: DashboardScreen = load("res://scenes/shell/parent_area/dashboard.tscn").instantiate()
	add_child(web)
	auto_free(web)
	DashboardScreen.pretend_web = false
	assert_object(web.find_child("ExportButton", true, false)).is_null()
	assert_object(web.find_child("ImportButton", true, false)).is_null()
	assert_object(web.find_child("ImportNewButton", true, false)).is_null()
	var note: Label = web.find_child("WebTransferNote", true, false)
	assert_object(note).is_not_null()
	assert_str(note.text).is_equal(Text.get_line(&"parent.dash.web_no_transfer"))
	var app: DashboardScreen = load("res://scenes/shell/parent_area/dashboard.tscn").instantiate()
	add_child(app)
	auto_free(app)
	assert_object(app.find_child("ExportButton", true, false)).is_not_null()
	assert_object(app.find_child("WebTransferNote", true, false)).is_null()


func test_the_skill_map_matches_adaptives_states() -> void:
	_seed()
	var dashboard: DashboardScreen = load("res://scenes/shell/parent_area/dashboard.tscn").instantiate()
	add_child(dashboard)
	auto_free(dashboard)
	var map: SkillMap = dashboard.skill_map()
	var states: Dictionary = Adaptive.skill_states()
	for id: StringName in states:
		assert_that(map.shown_state(id)).override_failure_message(String(id)).is_equal(states[id])
	assert_that(map.shown_state(&"add.to_10.sums")).is_equal(Adaptive.STATE_MASTERED)
	assert_that(map.shown_state(&"sub.to_10.diff")).is_equal(Adaptive.STATE_NEEDS_REVIEW)
	assert_that(map.shown_state(&"pv.tens_ones.read")).is_equal(Adaptive.STATE_PRACTICING)
	assert_that(map.shown_state(&"cmp.to_20.more_less")).is_equal(Adaptive.STATE_NOT_STARTED)
	map.node_for(&"sub.to_10.diff").pressed.emit()
	assert_str(map.detail_text()).is_equal(Text.get_line(&"parent.map.detail", {"skill": Adaptive.catalog().skill(&"sub.to_10.diff").name, "state": Text.get_line(&"parent.map.needs_review")}))
	for node: Node in map.find_children("*", "Button", true, false):
		assert_float((node as Button).custom_minimum_size.y).is_greater_equal(float(UI.min_target_px()))


func test_the_weekly_summary_counts_this_week_only() -> void:
	_seed()
	var week: Dictionary = ProgressReport.week_summary(SaveSystem.read_attempts()["entries"], SaveSystem.data()["skills"], "2027-04-07")
	assert_int(week["sessions"]).is_equal(2)
	assert_int(week["mastered"]).is_equal(1)
	assert_int(week["handwriting_answers"]).is_equal(3)
	assert_int(week["handwriting_confirmed"]).is_equal(1)
	assert_int(week["handwriting_rejected"]).is_equal(1)
	assert_int(week["confirmation_percent"]).is_equal(33)
	var dashboard: DashboardScreen = load("res://scenes/shell/parent_area/dashboard.tscn").instantiate()
	add_child(dashboard)
	auto_free(dashboard)
	var line: Label = dashboard.find_child("WeekHandwriting", true, false)
	assert_str(line.text).is_equal(Text.get_line(&"parent.week.handwriting", {"n": 3, "confirmed": 1, "percent": 33, "rejected": 1}))


func test_a_confirmed_slate_answer_is_logged_as_confirmed() -> void:
	var attempt: Attempt = Attempt.from_json({"confirmed": true})
	assert_bool(attempt.to_json()["confirmed"]).is_true()
	assert_bool(Attempt.from_json({}).confirmed).is_false() # older logs have no field
