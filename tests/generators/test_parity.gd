# Mirrors scripts/generators/parity.gd: the answer word matches n % 2, the wrong word is the other
# one, and the rule skill names its mistake by whether the tens digit would have misled the child.
class_name ParityGeneratorTest
extends GdUnitTestSuite

const N: int = 2000
const LABELS: Dictionary = {"even": "ui.answer.even", "odd": "ui.answer.odd"}

var _catalog: SkillCatalog
var _allowed: Array[StringName]


func before() -> void:
	_catalog = SkillCatalog.load_all()
	_allowed = SkillCatalog.misconception_names()


func _problems(skill_id: StringName, overrides: Dictionary = {}, count: int = N) -> Array[Problem]:
	return GeneratorChecks.make_all(_catalog.skill(skill_id), count, overrides)


func _check(skill_id: StringName) -> void:
	var skill: Skill = _catalog.skill(skill_id)
	assert_object(skill).is_not_null()
	var errors: Array[String] = GeneratorChecks.run(skill, 10000, _allowed)
	assert_array(errors).override_failure_message("\n".join(errors)).is_empty()


func _word(n: int) -> String:
	return "odd" if n % 2 == 1 else "even"


func test_parity_even_odd_pairs_passes_the_shared_checks() -> void:
	_check(&"parity.even_odd.pairs")


func test_parity_even_odd_rule_passes_the_shared_checks() -> void:
	_check(&"parity.even_odd.rule")


func test_pairs_answer_matches_the_gems_shown() -> void:
	var seen: Dictionary = {}
	for problem: Problem in _problems(&"parity.even_odd.pairs"):
		var n: int = problem.visual["count"]
		seen[n] = true
		assert_int(n).is_between(1, 20)
		assert_str(problem.visual["type"]).is_equal("pairs")
		assert_bool(problem.visual["show_pairs"]).is_false() # the child makes the pairs
		assert_str(problem.answer).is_equal(_word(n))
		assert_str(problem.prompt_line_id).is_equal("z3.parity.prompt_pairs")
		assert_dict(problem.hint_steps[1]["visual"]).is_equal({"type": "pairs", "count": n, "show_pairs": true})
	assert_int(seen.size()).is_equal(20)


func test_pairs_wrong_answer_is_the_other_word() -> void:
	for problem: Problem in _problems(&"parity.even_odd.pairs", {}, 500):
		assert_array(problem.distractors).has_size(1)
		assert_str(problem.distractors[0]["misconception"]).is_equal("leftover_miscounted")
		assert_str(problem.distractors[0]["value"]).is_equal("odd" if problem.answer == "even" else "even")
		assert_dict(Problem.canonical(problem.meta["label_lines"])).is_equal(LABELS)


func test_rule_answer_matches_the_number() -> void:
	var even: int = 0
	for problem: Problem in _problems(&"parity.even_odd.rule"):
		var n: int = problem.prompt_params["n"]
		assert_int(n).is_between(10, 100)
		assert_str(problem.answer).is_equal(_word(n))
		assert_bool(problem.visual.is_empty()).is_true() # abstract: no picture until the hint
		assert_dict(Problem.canonical(problem.meta["label_lines"])).is_equal(LABELS)
		if problem.answer == "even":
			even += 1
	assert_int(even).is_between(int(N * 0.4), int(N * 0.6))


func test_rule_names_the_mistake_by_what_the_tens_digit_says() -> void:
	var tens_misled: int = 0
	var swapped: int = 0
	for problem: Problem in _problems(&"parity.even_odd.rule"):
		var n: int = problem.prompt_params["n"]
		var digits: String = str(n)
		var tens_word: String = _word(int(digits[digits.length() - 2]))
		assert_array(problem.distractors).has_size(1)
		var entry: Dictionary = problem.distractors[0]
		assert_str(entry["value"]).is_equal("odd" if problem.answer == "even" else "even")
		if tens_word != problem.answer:
			tens_misled += 1
			assert_str(entry["misconception"]).is_equal("used_tens_digit")
			assert_bool(problem.meta["tens_digit_misleads"]).is_true()
		else:
			swapped += 1
			assert_str(entry["misconception"]).is_equal("parity_swapped")
			assert_bool(problem.meta["tens_digit_misleads"]).is_false()
	# Both cases are common, so "say the opposite of the tens digit" is not a winning trick.
	assert_int(tens_misled).is_greater(int(N * 0.4))
	assert_int(swapped).is_greater(int(N * 0.4))


func test_rule_hint_labels_the_even_numbers_around_n() -> void:
	for problem: Problem in _problems(&"parity.even_odd.rule", {}, 500):
		var n: int = problem.prompt_params["n"]
		var model: Dictionary = problem.hint_steps[1]["visual"]
		assert_str(model["type"]).is_equal("number_line")
		assert_int(model["labeled_every"]).is_equal(2)
		assert_int(model["min"] % 2).is_equal(0)
		assert_array(model["markers"]).is_equal([n])
		var example: Dictionary = problem.hint_steps[2]["example"]
		var shown: int = example["prompt_params"]["n"]
		assert_dict(example["answer_params"]).is_equal({"n": shown, "digit": shown % 10})
		assert_str(example["answer_line_id"]).is_equal("z3.hint.example_rule_" + _word(shown))


func test_the_worked_example_usually_has_the_other_answer() -> void:
	var other: int = 0
	for problem: Problem in _problems(&"parity.even_odd.pairs", {}, 500):
		if problem.hint_steps[2]["example"]["answer"] != problem.answer:
			other += 1
	assert_int(other).is_greater(490)


## The number the question is about: the gems shown, or the number in the prompt.
func _number(problem: Problem) -> int:
	return problem.visual["count"] if problem.prompt_params.is_empty() else problem.prompt_params["n"]


func test_easier_difficulty_gives_smaller_numbers() -> void:
	for skill_id: StringName in [&"parity.even_odd.pairs", &"parity.even_odd.rule"]:
		var normal: int = 0
		var easy: int = 0
		for problem: Problem in _problems(skill_id, {}, 1000):
			normal = maxi(normal, _number(problem))
		for problem: Problem in _problems(skill_id, {"difficulty": -1}, 1000):
			easy = maxi(easy, _number(problem))
		assert_int(normal).is_equal(_catalog.skill(skill_id).params["max"])
		assert_int(easy).is_less(normal)


func test_the_easiest_problems_still_pass_the_shared_checks() -> void:
	for skill_id: StringName in [&"parity.even_odd.pairs", &"parity.even_odd.rule"]:
		var errors: Array[String] = GeneratorChecks.run(_catalog.skill(skill_id), 500, _allowed, {"difficulty": -8})
		assert_array(errors).override_failure_message("\n".join(errors)).is_empty()


func test_the_same_seed_gives_the_same_problem_and_the_global_rng_is_untouched() -> void:
	var skill: Skill = _catalog.skill(&"parity.even_odd.rule")
	for seed: int in range(1, 200):
		assert_dict(GeneratorRegistry.make_problem(skill, seed).to_json()).is_equal(GeneratorRegistry.make_problem(skill, seed).to_json())
	seed(777)
	var expected: int = randi()
	seed(777)
	_problems(&"parity.even_odd.pairs", {}, 300)
	assert_int(randi()).is_equal(expected)
