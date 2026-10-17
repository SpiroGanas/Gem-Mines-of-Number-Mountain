# Mirrors scripts/adaptive/skill_record.gd: the mastery rules and the guessing guard.
class_name SkillRecordTest
extends GdUnitTestSuite

const PARAMS: Dictionary = {"prior": 0.3, "learn": 0.2, "guess": 0.2, "slip": 0.1, "fluency_ms": 8000}


func _ready_record() -> Dictionary:
	var record: Dictionary = SkillRecord.fresh(0.3)
	record["p_learned"] = 0.97
	record["correct_days"] = ["2026-12-07", "2026-12-08"]
	record["guess_evidence"] = 9.0
	record["recent_latency_ms"] = [3000, 4000, 5000]
	return record


func test_a_fresh_record_has_every_schema_v1_field_and_the_optional_ones() -> void:
	var record: Dictionary = SkillRecord.fresh(0.25)
	for field: String in ["p_learned", "attempts", "correct", "correct_days", "mastered_at", "review_stage", "next_review_at", "flagged_for_review", "recent_latency_ms", "placement_passed", "guess_evidence"]:
		assert_bool(record.has(field)).override_failure_message(field).is_true()
	assert_float(record["p_learned"]).is_equal(0.25)


func test_ensure_fills_the_optional_fields_of_a_v1_record_without_touching_the_rest() -> void:
	var fixture: Dictionary = JsonUtil.parse_file("res://tests/save/fixtures/v1.json")
	var skills: Dictionary = fixture["skills"]
	var record: Dictionary = SkillRecord.ensure(skills, &"pv.tens_ones.build", 0.3)
	assert_float(record["p_learned"]).is_equal(0.42) # the saved value, not the prior
	assert_int(record["attempts"]).is_equal(12)
	assert_bool(record["placement_passed"]).is_false()
	assert_float(record["guess_evidence"]).is_equal(0.0)


func test_ensure_creates_and_stores_a_new_record() -> void:
	var skills: Dictionary = {}
	var record: Dictionary = SkillRecord.ensure(skills, &"count.to_20.objects", 0.3)
	assert_bool(skills.has("count.to_20.objects")).is_true()
	record["attempts"] = 5
	assert_int(skills["count.to_20.objects"]["attempts"]).is_equal(5)


func test_every_mastery_condition_is_needed() -> void:
	assert_bool(SkillRecord.is_ready_to_master(_ready_record(), PARAMS, true)).is_true()
	var low_p: Dictionary = _ready_record()
	low_p["p_learned"] = 0.94
	var one_day: Dictionary = _ready_record()
	one_day["correct_days"] = ["2026-12-07"]
	var guessing: Dictionary = _ready_record()
	guessing["guess_evidence"] = SkillRecord.EVIDENCE_TO_MASTER - 0.01
	var slow: Dictionary = _ready_record()
	slow["recent_latency_ms"] = [9000, 9500, 4000]
	for record: Dictionary in [low_p, one_day, guessing, slow]:
		assert_bool(SkillRecord.is_ready_to_master(record, PARAMS, true)).is_false()
	assert_bool(SkillRecord.is_ready_to_master(slow, PARAMS, false)).is_true() # fluency is for fact skills only


func test_the_guessing_guard_is_a_likelihood_ratio_of_one_in_two_thousand() -> void:
	assert_float(SkillRecord.EVIDENCE_TO_MASTER).is_equal_approx(log(2000.0), 0.000001)
	assert_float(SkillRecord.EVIDENCE_FLOOR).is_equal_approx(log(0.01), 0.000001)
	# One of four buttons, slip 0.1: right is ln(0.9 / 0.25), wrong is ln(0.1 / 0.75).
	assert_float(SkillRecord.evidence_of(true, 0.25, 0.1)).is_equal_approx(1.280934, 0.000001)
	assert_float(SkillRecord.evidence_of(false, 0.25, 0.1)).is_equal_approx(-2.014903, 0.000001)
	# A typed answer says far more than a tap on one of two piles.
	assert_float(SkillRecord.evidence_of(true, 0.05, 0.1)).is_greater(SkillRecord.evidence_of(true, 0.5, 0.1) * 4.0)


func test_mastered_means_mastered_once_and_not_flagged_since() -> void:
	var record: Dictionary = SkillRecord.fresh(0.3)
	assert_bool(SkillRecord.is_mastered(record)).is_false()
	record["mastered_at"] = "2026-12-08T10:00:00Z"
	assert_bool(SkillRecord.is_mastered(record)).is_true()
	record["flagged_for_review"] = true
	assert_bool(SkillRecord.is_mastered(record)).is_false()


func test_secure_and_placement_passed_skills_open_their_successors() -> void:
	var record: Dictionary = SkillRecord.fresh(0.3)
	assert_bool(SkillRecord.opens_successors(record)).is_false()
	record["p_learned"] = 0.96
	assert_bool(SkillRecord.opens_successors(record)).is_false() # learned, but not shown to beat guessing
	record["guess_evidence"] = SkillRecord.EVIDENCE_TO_MASTER
	assert_bool(SkillRecord.is_secure(record)).is_true()
	assert_bool(SkillRecord.opens_successors(record)).is_true()
	var placed: Dictionary = SkillRecord.fresh(0.3)
	placed["placement_passed"] = true
	assert_bool(SkillRecord.opens_successors(placed)).is_true()


func test_a_skill_is_due_on_and_after_its_review_day() -> void:
	var record: Dictionary = SkillRecord.fresh(0.3)
	record["mastered_at"] = "2026-12-07T10:00:00Z"
	record["next_review_at"] = "2026-12-08"
	assert_bool(SkillRecord.is_due(record, "2026-12-07")).is_false()
	assert_bool(SkillRecord.is_due(record, "2026-12-08")).is_true()
	assert_bool(SkillRecord.is_due(record, "2027-01-02")).is_true()


func test_median_handles_odd_even_and_empty_lists() -> void:
	assert_float(SkillRecord.median([5, 1, 3])).is_equal(3.0)
	assert_float(SkillRecord.median([4, 1, 3, 2])).is_equal(2.5)
	assert_float(SkillRecord.median([])).is_equal(0.0)


func test_the_review_intervals_are_the_plans() -> void:
	assert_array(SkillRecord.REVIEW_INTERVALS).contains_exactly([1, 3, 7, 21, 60])
	assert_float(SkillRecord.MASTERY_P).is_equal(0.95)
	assert_int(SkillRecord.MASTERY_DAYS).is_equal(2)
