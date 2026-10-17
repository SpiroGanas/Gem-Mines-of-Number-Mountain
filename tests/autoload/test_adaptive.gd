# Mirrors autoload/adaptive.gd: the engine wired to the save, the attempt log and the placement
# quest. Uses the real autoload on a temp save folder and a fake clock.
class_name AdaptiveAutoloadTest
extends GdUnitTestSuite

var _dir: String
var _clock: FakeClock


func before_test() -> void:
	_dir = create_temp_dir("adaptive_" + str(Time.get_ticks_usec()))
	SaveSystem.use_directory(_dir)
	_clock = FakeClock.new()
	Adaptive.use_clock(_clock)


func after_test() -> void:
	Adaptive.use_clock(GameClock.new())
	SaveSystem.use_directory(SaveSystem.DEFAULT_DIR)


func _rng(seed_value: int = 1) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _attempt(problem: Problem, correct: bool, hints_used: int = 0) -> Attempt:
	var attempt: Attempt = Attempt.new()
	attempt.skill_id = problem.skill_id
	attempt.problem_seed = problem.seed
	attempt.representation = problem.representation
	attempt.answer_mode = AnswerPanel.answer_mode_for(problem)
	attempt.correct = correct
	attempt.hints_used = hints_used
	attempt.latency_ms = 3000
	return attempt


func test_record_logs_the_attempt_and_updates_the_saved_skill() -> void:
	var problem: Problem = Adaptive.next_problem(_rng())
	Adaptive.record(_attempt(problem, true), AnswerPanel.chance_for(problem))
	var entries: Array = SaveSystem.read_attempts()["entries"]
	assert_int(entries.size()).is_equal(1)
	assert_str(entries[0]["skill_id"]).is_equal(String(problem.skill_id))
	assert_str(entries[0]["ts"]).is_equal("2026-12-07T12:00:00Z")
	assert_str(entries[0]["session_id"]).is_equal(Adaptive.session_id)
	var record: Dictionary = SaveSystem.data()["skills"][String(problem.skill_id)]
	assert_int(record["attempts"]).is_equal(1)
	assert_array(record["correct_days"]).contains_exactly(["2026-12-07"])


func test_a_new_session_gets_a_new_id() -> void:
	var first: String = Adaptive.start_session()
	_clock.advance(3600)
	assert_str(Adaptive.start_session()).is_not_equal(first)


func test_a_new_profile_needs_the_placement_quest_and_finishing_it_is_saved() -> void:
	assert_bool(Adaptive.needs_placement()).is_true()
	Adaptive.start_placement()
	assert_bool(Adaptive.placement_active()).is_true()
	var finished: Array = []
	var on_finished: Callable = func(passed: Array[StringName]) -> void: finished.append(passed)
	Adaptive.placement_finished.connect(on_finished)
	var rng: RandomNumberGenerator = _rng(3)
	var problems: int = 0
	while Adaptive.placement_active() and problems < 60:
		var problem: Problem = Adaptive.next_problem(rng)
		assert_str(problem.skill_id).is_equal(String(Adaptive.placement().current_skill()))
		Adaptive.record(_attempt(problem, true), AnswerPanel.chance_for(problem))
		_clock.advance(15)
		problems += 1
	Adaptive.placement_finished.disconnect(on_finished)
	assert_bool(Adaptive.placement_active()).is_false()
	assert_int(finished.size()).is_equal(1)
	assert_bool(finished[0].has(&"count.to_120.read")).is_true()
	assert_bool(Adaptive.needs_placement()).is_false()
	assert_bool(SaveSystem.data()["skills"]["count.to_120.read"]["placement_passed"]).is_true()
	assert_float(SaveSystem.data()["skills"]["count.to_20.objects"]["p_learned"]).is_greater_equal(SkillRecord.PLACEMENT_P)
	# The save on disk says the quest is done.
	var reloaded: Dictionary = SaveStore.new(_dir).read_profile()["data"]
	assert_bool(reloaded["placement"]["done"]).is_true()


func test_retries_during_placement_do_not_count_as_probes() -> void:
	Adaptive.start_placement()
	var problem: Problem = Adaptive.next_problem(_rng())
	var probed: StringName = Adaptive.placement().current_skill()
	Adaptive.record(_attempt(problem, true), 0.25)
	Adaptive.record(_attempt(problem, true, 1), 0.5) # a retry on the same rock
	assert_int(Adaptive.placement().problems_given()).is_equal(1)
	assert_str(Adaptive.placement().current_skill()).is_equal(String(probed))


func test_a_parent_can_ask_for_the_quest_again() -> void:
	SaveSystem.data()["placement"]["done"] = true
	assert_bool(Adaptive.needs_placement()).is_false()
	Adaptive.rerun_placement()
	assert_bool(Adaptive.needs_placement()).is_true()


func test_loading_another_profile_drops_an_unfinished_quest() -> void:
	Adaptive.start_placement()
	SaveSystem.use_directory(create_temp_dir("adaptive_other_" + str(Time.get_ticks_usec())))
	assert_bool(Adaptive.placement_active()).is_false()
	assert_bool(Adaptive.has_session()).is_false()


func test_struggling_reads_the_attempt_log() -> void:
	var problem: Problem = Adaptive.next_problem(_rng(), [&"count.to_120.read"])
	for i: int in 3:
		Adaptive.record(_attempt(problem, false), 0.25)
	assert_array(Adaptive.struggling()).contains_exactly([&"count.to_120.read"])


func test_mastery_and_flags_are_announced() -> void:
	monitor_signals(Adaptive, false)
	Adaptive.flag_for_review(&"count.to_20.objects")
	await assert_signal(Adaptive).is_emitted("skill_flagged", [&"count.to_20.objects"])
	assert_bool(SaveSystem.data()["skills"]["count.to_20.objects"]["flagged_for_review"]).is_true()
