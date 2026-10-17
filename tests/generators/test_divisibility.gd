# Mirrors scripts/generators/divisibility.gd: whether d divides n is checked here by repeated
# subtraction (never with %), the digits picture lights the part the rule looks at, about half the
# answers are yes, and every wrong answer names the rule mistake it stands for.
class_name DivisibilityGeneratorTest
extends GdUnitTestSuite

const N: int = 2000
const SKILLS: Array[StringName] = [&"div.rule.2_5_10", &"div.rule.3_9", &"div.rule.4_6", &"div.rule.mixed"]

var _catalog: SkillCatalog
var _allowed: Array[StringName]


func before() -> void:
	_catalog = SkillCatalog.load_all()
	_allowed = SkillCatalog.misconception_names()


func _problems(skill_id: StringName, count: int = N) -> Array[Problem]:
	return GeneratorChecks.make_all(_catalog.skill(skill_id), count)


func _shares(n: int, d: int) -> bool:
	var left: int = n
	while left >= d:
		left -= d
	return left == 0


func _is_prime(n: int) -> bool:
	if n < 2:
		return false
	for d: int in range(2, n):
		if _shares(n, d):
			return false
	return true


func test_every_skill_passes_the_shared_checks() -> void:
	for skill_id: StringName in SKILLS:
		assert_array(GeneratorChecks.run(_catalog.skill(skill_id), N, _allowed)).is_empty()


func test_the_answer_is_whether_d_divides_n_and_both_answers_come_up() -> void:
	for skill_id: StringName in SKILLS:
		var skill: Skill = _catalog.skill(skill_id)
		var yes: int = 0
		for problem: Problem in _problems(skill_id):
			var n: int = problem.prompt_params["n"]
			var d: int = problem.prompt_params["d"]
			assert_bool(GeneratorKit.ints_of(skill.params["divisors"]).has(d)).is_true()
			assert_bool(n >= int(skill.params["min"]) and n <= int(skill.params["max"])).is_true()
			assert_bool(problem.answer).is_equal(_shares(n, d))
			if problem.answer:
				yes += 1
		assert_bool(yes > N * 0.3 and yes < N * 0.7).override_failure_message("%s: %d yes of %d" % [skill_id, yes, N]).is_true()


func test_the_wrong_answer_names_the_first_rule_mistake_that_fits() -> void:
	for skill_id: StringName in SKILLS:
		for problem: Problem in _problems(skill_id, 600):
			var n: int = problem.prompt_params["n"]
			var d: int = problem.prompt_params["d"]
			var last: int = n - 10 * floori(n / 10.0)
			var expected: String = "no_check_made"
			if _shares(n, d):
				if (d == 3 or d == 9) and not _shares(last, d) and last != 0:
					expected = "last_digit_only_for_3"
			elif d == 10 and last == 5:
				expected = "mixed_up_5_and_10"
			elif (d == 3 or d == 9) and last != 0 and _shares(last, d):
				expected = "last_digit_only_for_3"
			elif d == 9 and _shares(n, 3):
				expected = "three_means_nine"
			elif d == 4 and _shares(n, 2):
				expected = "even_means_div_by_4"
			elif d == 6 and _shares(n, 2) != _shares(n, 3):
				expected = "only_one_rule_for_6"
			assert_int(problem.distractors.size()).is_equal(1)
			assert_str(String(problem.distractors[0]["misconception"])).override_failure_message("%s n=%d d=%d" % [skill_id, n, d]).is_equal(expected)
			assert_bool(problem.distractors[0]["value"]).is_equal(not problem.answer)


func test_the_digits_picture_lights_what_the_rule_reads() -> void:
	var focus_for: Dictionary = {2: "last", 5: "last", 10: "last", 4: "last_two", 3: "sum", 9: "sum", 6: "sum_and_last"}
	for problem: Problem in _problems(&"div.rule.mixed", 300):
		var model: Dictionary = problem.hint_steps[1]["visual"]
		assert_str(model["type"]).is_equal("digits")
		assert_str(model["focus"]).is_equal(focus_for[problem.prompt_params["d"]])
		var rebuilt: int = 0
		for digit: int in model["digits"]:
			rebuilt = rebuilt * 10 + digit
		assert_int(rebuilt).is_equal(problem.prompt_params["n"])
		assert_dict(problem.visual).is_empty() # abstract only


func test_pictorial_problems_show_the_digits_from_the_start() -> void:
	for problem: Problem in GeneratorChecks.make_all(_catalog.skill(&"div.rule.3_9"), 50, {"representation": &"pictorial"}):
		assert_dict(problem.visual).is_equal(problem.hint_steps[1]["visual"])


func test_the_mixed_skill_asks_about_primes_so_127_can_be_dug() -> void:
	var primes: int = 0
	var seen_127: bool = false
	for problem: Problem in _problems(&"div.rule.mixed", 6000):
		var n: int = problem.prompt_params["n"]
		if _is_prime(n):
			primes += 1
			assert_bool(problem.answer).is_false()
		seen_127 = seen_127 or n == 127
	assert_bool(primes > 300).is_true()
	assert_bool(seen_127).is_true()
	assert_str(String(RewardsRules.gem_for_rock(5, 127))).is_equal(String(GemArt.MERSENNE))
