# Mirrors scripts/core/progress_report.gd against a hand-made attempt log
# (tests/save/fixtures/attempts_sample.jsonl). Expected numbers are worked out by hand:
#   s1 (Dec 7):  4 s first latency + 30 + 20 + 30 + 120 (a 520 s gap, capped) = 204 s,
#                5 answers, 4 rocks, 3 of 4 first tries right (75%)
#   s2 (Dec 9):  8 + 60 = 68 s, 2 rocks, 2 of 2 first tries (100%)
#   s3 (Dec 15): 7 + 40 + 20 = 67 s, 1 rock, 0 of 2 first tries (0%)
class_name ProgressReportTest
extends GdUnitTestSuite

var _entries: Array


func before() -> void:
	_entries = SaveStore.new("res://tests/save/fixtures").read_attempts_file("res://tests/save/fixtures/attempts_sample.jsonl")


func test_sessions_are_counted_from_the_log() -> void:
	var sessions: Array[Dictionary] = ProgressReport.sessions(_entries)
	assert_int(sessions.size()).is_equal(3)
	assert_dict(sessions[0]).is_equal({
		"session_id": "s1", "start_ts": "2026-12-07T15:00:00Z", "day": "2026-12-07",
		"seconds": 204, "answers": 5, "rocks": 4, "first_tries": 4, "first_try_correct": 3,
	})
	assert_int(sessions[1]["seconds"]).is_equal(68)
	assert_int(sessions[2]["seconds"]).is_equal(67)
	assert_int(ProgressReport.first_try_percent(sessions[0])).is_equal(75)
	assert_int(ProgressReport.first_try_percent(sessions[1])).is_equal(100)
	assert_int(ProgressReport.first_try_percent(sessions[2])).is_equal(0)


func test_time_played_today_and_this_week() -> void:
	assert_int(ProgressReport.seconds_on(_entries, "2026-12-07")).is_equal(204)
	assert_int(ProgressReport.seconds_on(_entries, "2026-12-08")).is_equal(0)
	assert_int(ProgressReport.seconds_this_week(_entries, "2026-12-15")).is_equal(68 + 67) # Dec 9 to 15
	assert_int(ProgressReport.seconds_this_week(_entries, "2026-12-10")).is_equal(204 + 68)
	assert_int(ProgressReport.minutes(204)).is_equal(3)
	assert_int(ProgressReport.minutes(1199)).is_equal(20)


func test_recent_sessions_are_newest_first_and_at_most_seven() -> void:
	var recent: Array[Dictionary] = ProgressReport.recent_sessions(_entries)
	assert_array(recent.map(func(s: Dictionary) -> String: return s["session_id"])).contains_exactly(["s3", "s2", "s1"])
	var many: Array = []
	for index: int in 20:
		many.append({"ts": "2026-12-%02dT10:00:00Z" % (index + 1), "session_id": "x%d" % index, "correct": true, "hints_used": 0, "latency_ms": 1000})
	assert_int(ProgressReport.recent_sessions(many).size()).is_equal(ProgressReport.SESSIONS_SHOWN)


func test_days_follow_the_childs_time_zone() -> void:
	var sessions: Array[Dictionary] = ProgressReport.sessions(_entries, -600) # UTC-10
	assert_str(sessions[1]["day"]).is_equal("2026-12-08") # 09:00 UTC is 23:00 the evening before


func test_an_empty_log_reports_nothing() -> void:
	assert_array(ProgressReport.sessions([])).is_empty()
	assert_int(ProgressReport.seconds_on([], "2026-12-07")).is_equal(0)
