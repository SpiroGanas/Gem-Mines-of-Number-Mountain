"""Tests for tools/bkt/gate_report.py on a small synthetic bundle."""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import gate_report  # noqa: E402


def attempt(ts, skill="a", correct=True, hints=0, mode="tap", rejected=False, session="s1"):
    return {"ts": ts, "session_id": session, "skill_id": skill, "correct": correct, "hints_used": hints,
            "answer_mode": mode, "latency_ms": 4000, "low_confidence_rejected": rejected}


def test_days_played_per_week_counts_distinct_days_in_monday_weeks():
    attempts = [attempt("2027-02-01T10:00:00Z"), attempt("2027-02-01T10:05:00Z"), attempt("2027-02-03T10:00:00Z"),
                attempt("2027-02-05T10:00:00Z"), attempt("2027-02-08T10:00:00Z")]
    assert gate_report.days_played_per_week(attempts) == {"2027-02-01": 3, "2027-02-08": 1}


def test_a_rejected_reading_alone_is_not_a_day_played():
    attempts = [attempt("2027-02-01T10:00:00Z", rejected=True)]
    assert gate_report.days_played_per_week(attempts) == {}


def test_the_local_offset_moves_late_evening_play_to_the_right_day():
    attempts = [attempt("2027-02-08T02:30:00Z")]  # Sunday evening in US Eastern
    assert gate_report.days_played_per_week(attempts, -300) == {"2027-02-01": 1}


def test_since_drops_earlier_days():
    attempts = [attempt("2027-01-20T10:00:00Z"), attempt("2027-02-02T10:00:00Z")]
    assert gate_report.days_played_per_week(attempts, since="2027-01-29") == {"2027-02-01": 1}


def test_minutes_cap_idle_gaps():
    attempts = [attempt("2027-02-01T10:00:00Z"), attempt("2027-02-01T10:00:30Z"), attempt("2027-02-01T11:00:00Z")]
    # 4 s first answer + 30 s + a 1-hour gap capped at 120 s = 154 s = 3 minutes
    assert gate_report.minutes_per_week(attempts) == {"2027-02-01": 3}


def test_mastered_count_is_cumulative_by_week():
    profile = {"skills": {"a": {"mastered_at": "2027-02-02T10:00:00Z"}, "b": {"mastered_at": "2027-02-03T10:00:00Z"},
                          "c": {"mastered_at": "2027-02-10T10:00:00Z"}, "d": {"mastered_at": None}}}
    assert gate_report.mastered_by_week(profile) == {"2027-02-01": 2, "2027-02-08": 3}


def test_ceiling_and_floor_need_enough_first_tries():
    attempts = [attempt("2027-02-01T10:00:%02dZ" % (i % 60), skill="easy") for i in range(40)]
    attempts += [attempt("2027-02-01T10:01:%02dZ" % (i % 60), skill="hard", correct=i % 5 == 0) for i in range(40)]
    attempts += [attempt("2027-02-01T10:02:%02dZ" % (i % 60), skill="few") for i in range(10)]
    attempts += [attempt("2027-02-01T10:03:00Z", skill="easy", correct=False, hints=1)]  # a hinted answer is not a first try
    flags = gate_report.ceiling_floor(attempts)
    assert [r["skill"] for r in flags["ceiling"]] == ["easy"]
    assert [r["skill"] for r in flags["floor"]] == ["hard"]


def test_input_summary_separates_rejected_readings():
    attempts = [attempt("2027-02-01T10:00:00Z", mode="handwriting"), attempt("2027-02-01T10:00:10Z", mode="handwriting", rejected=True),
                attempt("2027-02-01T10:00:20Z", mode="tap")]
    assert gate_report.input_summary(attempts) == {"handwriting": {"answers": 1, "rejected": 1}, "tap": {"answers": 1, "rejected": 0}}


def test_the_report_is_markdown_with_the_open_questions(tmp_path, capsys):
    bundle = tmp_path / "b.json"
    bundle.write_text(json.dumps({"format": "gem-mines-progress", "bundle_version": 1, "profile": {"skills": {}},
                                  "attempts": [attempt("2027-02-01T10:00:00Z")]}))
    assert gate_report.main([str(bundle)]) == 0
    text = capsys.readouterr().out
    assert "## MVP decision gate" in text and "Does Charlie ask to play?" in text and "| 2027-02-01 | 1 |" in text


def test_a_file_that_is_not_a_bundle_is_refused(tmp_path):
    bad = tmp_path / "x.json"
    bad.write_text("{}")
    try:
        gate_report.load_bundle(bad)
    except SystemExit:
        return
    raise AssertionError("expected SystemExit")
