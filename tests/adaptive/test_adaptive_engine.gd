# Mirrors scripts/adaptive/adaptive_engine.gd: the evidence policy, mastery on two days, spaced
# review, lapses, flags and placement marks. Uses a fake clock and its own skills dictionary.
class_name AdaptiveEngineTest
extends GdUnitTestSuite

const SKILL: StringName = &"count.write.numeral" # number pad: a lucky guess is rare
const TAP_SKILL: StringName = &"cmp.to_20.more_less" # two piles: a lucky tap is common
const PAD: float = 0.05

var _catalog: SkillCatalog
var _clock: FakeClock
var _engine: AdaptiveEngine
var _mastered: Array = []
var _flagged: Array[StringName] = []


func before() -> void:
	_catalog = SkillCatalog.load_all()


func before_test() -> void:
	_clock = FakeClock.new()
	_engine = AdaptiveEngine.new(_catalog, BKT.load_defaults(), _clock)
	_mastered.clear()
	_flagged.clear()
	_engine.skill_mastered.connect(func(id: StringName, first: bool) -> void: _mastered.append([id, first]))
	_engine.skill_flagged.connect(func(id: StringName) -> void: _flagged.append(id))


func _record(skill_id: StringName = SKILL) -> Dictionary:
	return _engine.skills()[String(skill_id)]


## `count` first-try correct answers in a row.
func _correct(count: int, skill_id: StringName = SKILL, chance: float = PAD) -> void:
	for i: int in count:
		_engine.record_answer(skill_id, true, 0, chance, 3000)


## Masters SKILL over two days and returns the mastery day.
func _master_skill() -> String:
	_correct(4)
	_clock.advance_days(1)
	_correct(1)
	return _clock.today()


func test_a_first_try_answer_updates_p_evidence_days_and_latency() -> void:
	var prior: float = BKT.load_defaults()["default"]["prior"]
	_engine.record_answer(SKILL, true, 0, PAD, 4200)
	var record: Dictionary = _record()
	assert_float(record["p_learned"]).is_greater(prior)
	assert_float(record["guess_evidence"]).is_equal_approx(log(0.9 / PAD), 0.0001)
	assert_array(record["correct_days"]).contains_exactly(["2026-12-07"])
	assert_array(record["recent_latency_ms"]).contains_exactly([4200])
	assert_int(record["attempts"]).is_equal(1)
	assert_int(record["correct"]).is_equal(1)


func test_a_correct_answer_after_hints_is_partial_evidence_and_a_later_miss_adds_nothing() -> void:
	_engine.record_answer(SKILL, false, 0, PAD, 3000)
	var after_miss: Dictionary = _record().duplicate(true)
	_engine.record_answer(SKILL, false, 1, PAD, 3000) # second miss on the same rock
	assert_float(_record()["p_learned"]).is_equal(after_miss["p_learned"])
	assert_float(_record()["guess_evidence"]).is_equal(after_miss["guess_evidence"])
	_engine.record_answer(SKILL, true, 2, PAD, 3000)
	var p: Dictionary = BKT.with_chance(_engine.params_for(SKILL), PAD)
	assert_float(_record()["p_learned"]).is_equal_approx(BKT.update_with_hints(after_miss["p_learned"], true, 2, p), 0.000001)
	assert_array(_record()["correct_days"]).is_empty() # a hint-assisted answer is not a correct day
	assert_int(_record()["attempts"]).is_equal(3)


func test_one_day_of_correct_answers_is_never_mastery() -> void:
	_correct(20)
	assert_bool(SkillRecord.is_mastered(_record())).is_false()
	assert_bool(SkillRecord.is_secure(_record())).is_true()
	assert_array(_mastered).is_empty()


func test_a_correct_answer_on_a_second_day_masters_the_skill() -> void:
	var day: String = _master_skill()
	assert_bool(SkillRecord.is_mastered(_record())).is_true()
	assert_array(_mastered).contains_exactly([[SKILL, true]])
	assert_str(_record()["next_review_at"]).is_equal(GameClock.add_days(day, 1))
	assert_int(_record()["review_stage"]).is_equal(0)
	assert_str(_record()["mastered_at"]).is_equal(_clock.now_iso())


func test_taps_on_two_piles_need_more_correct_answers_than_typed_numbers() -> void:
	var typed: int = 0
	while not SkillRecord.is_secure(_engine.record_for(SKILL)):
		_engine.record_answer(SKILL, true, 0, PAD, 3000)
		typed += 1
	var tapped: int = 0
	while not SkillRecord.is_secure(_engine.record_for(TAP_SKILL)):
		_engine.record_answer(TAP_SKILL, true, 0, 0.5, 3000)
		tapped += 1
	assert_int(tapped).is_greater(typed * 3)


func test_correct_reviews_space_out_over_1_3_7_21_and_60_days() -> void:
	_master_skill()
	var expected_gaps: Array[int] = [3, 7, 21, 60, 60]
	for gap: int in expected_gaps:
		_clock.unix = Time.get_unix_time_from_datetime_string(_record()["next_review_at"] + "T12:00:00")
		_correct(1)
		assert_str(_record()["next_review_at"]).is_equal(GameClock.add_days(_clock.today(), gap))
	assert_int(_record()["review_stage"]).is_equal(4)


func test_a_missed_review_sends_the_skill_back_to_practice() -> void:
	_master_skill()
	_clock.advance_days(1)
	var result: Dictionary = _engine.record_answer(SKILL, false, 0, PAD, 3000)
	assert_bool(result["lapsed"]).is_true()
	assert_bool(SkillRecord.is_mastered(_record())).is_false()
	assert_bool(_record()["flagged_for_review"]).is_true()
	assert_array(_record()["correct_days"]).is_empty()
	assert_array(_flagged).contains_exactly([SKILL])
	assert_str(_record()["mastered_at"]).is_not_empty() # remembered: the mastery gem is not given twice


func test_a_skill_won_back_after_a_lapse_is_not_a_first_mastery() -> void:
	_master_skill()
	_clock.advance_days(1)
	_engine.record_answer(SKILL, false, 0, PAD, 3000)
	_correct(6)
	_clock.advance_days(1)
	_correct(2)
	assert_bool(SkillRecord.is_mastered(_record())).is_true()
	assert_array(_mastered[-1]).contains_exactly([SKILL, false])
	assert_bool(_record()["flagged_for_review"]).is_false()


func test_a_mastered_skill_answered_before_its_review_day_is_not_judged() -> void:
	_master_skill()
	_engine.record_answer(SKILL, false, 0, PAD, 3000) # same day, not due yet
	assert_bool(SkillRecord.is_mastered(_record())).is_true()


func test_flagging_a_skill_marks_it_and_unmasters_a_mastered_one() -> void:
	_engine.flag_for_review(TAP_SKILL)
	assert_bool(_record(TAP_SKILL)["flagged_for_review"]).is_true()
	_master_skill()
	_engine.flag_for_review(SKILL)
	assert_bool(SkillRecord.is_mastered(_record())).is_false()
	assert_array(_flagged).contains_exactly([TAP_SKILL, SKILL])


func test_fact_skills_also_need_quick_answers_to_be_mastered() -> void:
	var fact: StringName = &"add.to_10.sums"
	for i: int in 5:
		_engine.record_answer(fact, true, 0, PAD, 12000) # right, but slow
	_clock.advance_days(1)
	_engine.record_answer(fact, true, 0, PAD, 12000)
	assert_bool(SkillRecord.is_mastered(_record(fact))).is_false()
	for i: int in 3:
		_engine.record_answer(fact, true, 0, PAD, 2500)
	assert_bool(SkillRecord.is_mastered(_record(fact))).is_true()


func test_placement_marks_skills_known_without_mastering_or_lowering_them() -> void:
	_correct(10, TAP_SKILL, 0.5)
	var high: float = _record(TAP_SKILL)["p_learned"]
	_engine.apply_placement([&"count.to_20.objects", TAP_SKILL])
	assert_float(_record(&"count.to_20.objects")["p_learned"]).is_equal(SkillRecord.PLACEMENT_P)
	assert_bool(_record(&"count.to_20.objects")["placement_passed"]).is_true()
	assert_bool(SkillRecord.is_mastered(_record(&"count.to_20.objects"))).is_false()
	assert_float(_record(TAP_SKILL)["p_learned"]).is_equal(maxf(high, SkillRecord.PLACEMENT_P))
	assert_bool(_engine.frontier().has(&"count.to_120.read")).is_true()


func test_struggling_lists_flagged_skills_and_three_misses_in_the_last_five_first_tries() -> void:
	var log_entries: Array = []
	for correct: bool in [true, true, false, true, false, false]:
		log_entries.append({"skill_id": "count.to_120.read", "hints_used": 0, "correct": correct})
	log_entries.append({"skill_id": "count.to_20.objects", "hints_used": 0, "correct": false})
	log_entries.append({"skill_id": "count.to_20.objects", "hints_used": 1, "correct": false}) # a retry does not count
	log_entries.append({"skill_id": "count.to_20.objects", "hints_used": 2, "correct": false})
	_engine.flag_for_review(TAP_SKILL)
	assert_array(_engine.struggling(log_entries)).contains_exactly_in_any_order([&"count.to_120.read", TAP_SKILL])


func test_next_problem_serves_the_frontier_at_its_representation() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 4
	var problem: Problem = _engine.next_problem(rng)
	assert_str(problem.skill_id).is_equal("count.to_20.objects")
	var only: Array[StringName] = [&"pv.tens_ones.read"]
	var limited: Problem = _engine.next_problem(rng, only)
	assert_str(limited.skill_id).is_equal("pv.tens_ones.read")
	assert_str(limited.representation).is_equal("concrete") # a new skill starts concrete


func test_the_easier_problem_is_the_same_skill_one_step_easier() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 9
	var problem: Problem = _engine.problem_for(&"pv.tens_ones.build", rng)
	var easier: Problem = _engine.easier_problem(problem, rng)
	assert_str(easier.skill_id).is_equal("pv.tens_ones.build")
	assert_int(easier.params["difficulty"]).is_equal(-1)
	assert_str(easier.representation).is_equal(problem.representation)
