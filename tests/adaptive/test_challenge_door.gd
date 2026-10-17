# The Challenge Door (Sprint 19): simulated learners through the real engine, the real generators and
# the real inputs' guessing odds. A random guesser passes at most about 1 time in 64 (under 2% over
# 10,000 doors); a fast learner passes within 2 doors; a miss is not a wrong answer.
class_name ChallengeDoorTest
extends GdUnitTestSuite

const DOORS: int = 10000

var _catalog: SkillCatalog


func before() -> void:
	_catalog = SkillCatalog.load_all()


func _engine() -> AdaptiveEngine:
	return AdaptiveEngine.new(_catalog, BKT.load_defaults(), FakeClock.new())


func _door(engine: AdaptiveEngine, skill_id: StringName, rng: RandomNumberGenerator) -> Array[Problem]:
	return engine.challenge_problems(skill_id, rng, MotivationRules.CHALLENGE_PROBLEMS, MotivationRules.CHALLENGE_MAX_LUCK, MotivationRules.CHALLENGE_MOST, AnswerPanel.chance_for)


## True when `right_chance(problem)` gets every problem of the door right.
func _passes(problems: Array[Problem], rng: RandomNumberGenerator, right_chance: Callable) -> bool:
	for problem: Problem in problems:
		if rng.randf() >= float(right_chance.call(problem)):
			return false
	return true


func test_a_random_guesser_passes_under_two_percent_of_10000_doors_across_every_skill() -> void:
	var engine: AdaptiveEngine = _engine()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 2027
	var skills: Array[StringName] = engine.scheduler.playable
	var passed: int = 0
	for door: int in DOORS:
		var problems: Array[Problem] = _door(engine, skills[door % skills.size()], rng)
		if _passes(problems, rng, func(problem: Problem) -> float: return AnswerPanel.chance_for(problem)):
			passed += 1
	var rate: float = float(passed) / float(DOORS)
	print("Challenge Door: a random guesser passed %d of %d doors (%.2f%%)" % [passed, DOORS, rate * 100.0])
	assert_float(rate).is_less(0.02)


func test_an_easy_to_guess_skill_gets_more_problems_so_luck_stays_small() -> void:
	var engine: AdaptiveEngine = _engine()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 5
	for skill_id: StringName in engine.scheduler.playable:
		var problems: Array[Problem] = _door(engine, skill_id, rng)
		var luck: float = 1.0
		for problem: Problem in problems:
			luck *= AnswerPanel.chance_for(problem)
		assert_int(problems.size()).is_greater_equal(MotivationRules.CHALLENGE_PROBLEMS)
		assert_bool(luck <= MotivationRules.CHALLENGE_MAX_LUCK or problems.size() == MotivationRules.CHALLENGE_MOST).override_failure_message("%s: luck %f" % [skill_id, luck]).is_true()


func test_a_fast_learner_passes_within_two_doors() -> void:
	var engine: AdaptiveEngine = _engine()
	var fast: Callable = func(_problem: Problem) -> float: return 0.95
	for seed_value: int in [1, 2, 3, 4, 5]:
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = seed_value
		var doors: int = 0
		var opened: bool = false
		while doors < 2 and not opened:
			doors += 1
			opened = _passes(_door(engine, &"add.to_20.sums", rng), rng, fast)
		assert_bool(opened).override_failure_message("seed %d" % seed_value).is_true()


func test_the_door_problems_are_the_skills_hardest_and_most_abstract() -> void:
	var engine: AdaptiveEngine = _engine()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 9
	var skill: Skill = _catalog.skill(&"mult.facts.0_5")
	for problem: Problem in _door(engine, skill.id, rng):
		assert_that(problem.representation).is_equal(skill.representations[skill.representations.size() - 1])
		assert_that(problem.skill_id).is_equal(skill.id)


func test_passing_masters_with_challenge_evidence_and_reviews_follow() -> void:
	var engine: AdaptiveEngine = _engine()
	assert_bool(engine.master_by_challenge(&"add.to_20.sums")).is_true()
	var record: Dictionary = engine.record_for(&"add.to_20.sums")
	assert_bool(SkillRecord.is_mastered(record)).is_true()
	assert_str(record["mastery_evidence"]).is_equal("challenge")
	assert_str(str(record["next_review_at"])).is_equal(GameClock.add_days(engine.clock.today(), 1))
	assert_bool(engine.master_by_challenge(&"add.to_20.sums")).is_false() # once


func test_a_door_miss_closes_it_until_tomorrow_only() -> void:
	var save: Dictionary = SaveSchema.new_profile("t")
	MotivationRules.close_door(save, &"add.to_20.sums", "2027-03-22")
	assert_bool(MotivationRules.door_closed(save, &"add.to_20.sums", "2027-03-22")).is_true()
	assert_bool(MotivationRules.door_closed(save, &"add.to_20.sums", "2027-03-23")).is_false()
	assert_bool(MotivationRules.door_closed(save, &"sub.to_20.diff", "2027-03-22")).is_false()
