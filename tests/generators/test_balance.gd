# Mirrors scripts/generators/balance.gd. The verdict must match the arithmetic of the two pans, and
# the wrong verdict must carry the name of the reading that gives it.
class_name BalanceGeneratorTest
extends GdUnitTestSuite

const N: int = 3000
const SKILL: StringName = &"eq.balance.true_false"
## prompt line -> [left pan params, right pan params], in the order the equation is written.
const SIDES: Dictionary[String, Array] = {
	"z2.eq.prompt_balance_two_two": [["a", "b"], ["c", "d"]],
	"z2.eq.prompt_balance_two_one": [["a", "b"], ["c"]],
	"z2.eq.prompt_balance_one_two": [["c"], ["a", "b"]],
}

var _catalog: SkillCatalog


func before() -> void:
	_catalog = SkillCatalog.load_all()


func _problems(overrides: Dictionary = {}, count: int = N) -> Array[Problem]:
	return GeneratorChecks.make_all(_catalog.skill(SKILL), count, overrides)


func _pan(problem: Problem, names: Array) -> Array[int]:
	var values: Array[int] = []
	for name: String in names:
		values.append(problem.prompt_params[name])
	return values


func _sum(values: Array) -> int:
	var total: int = 0
	for value: int in values:
		total += value
	return total


func test_the_verdict_matches_the_arithmetic_and_the_pans_match_the_prompt() -> void:
	var shapes: Dictionary = {}
	var true_count: int = 0
	for problem: Problem in _problems():
		var line: String = String(problem.prompt_line_id)
		assert_bool(SIDES.has(line)).override_failure_message("unexpected prompt %s" % line).is_true()
		var left: Array[int] = _pan(problem, SIDES[line][0])
		var right: Array[int] = _pan(problem, SIDES[line][1])
		assert_int(problem.prompt_params.size()).is_equal(left.size() + right.size())
		assert_array(problem.visual["left"]).is_equal(left)
		assert_array(problem.visual["right"]).is_equal(right)
		assert_str(problem.visual["tilt"]).is_equal("unknown") # the child decides; the hint shows it
		var truth: bool = _sum(left) == _sum(right)
		assert_bool(problem.answer).is_equal(truth)
		assert_array(problem.distractor_values()).is_equal([not truth])
		true_count += 1 if truth else 0
		shapes[line] = int(shapes.get(line, 0)) + 1
	assert_int(true_count).is_between(N * 2 / 5, N * 3 / 5) # about half are true
	for line: String in SIDES:
		assert_int(int(shapes.get(line, 0))).is_greater(N / 5)


func test_every_number_and_every_side_stays_within_20() -> void:
	for problem: Problem in _problems():
		for side: String in ["left", "right"]:
			for value: int in problem.visual[side]:
				assert_int(value).is_between(1, 20)
			assert_int(_sum(problem.visual[side])).is_between(1, 20)


func test_the_wrong_verdict_is_named_by_the_reading_that_gives_it() -> void:
	var names: Dictionary = {}
	for problem: Problem in _problems():
		var left: Array = problem.visual["left"]
		var right: Array = problem.visual["right"]
		var truth: bool = _sum(left) == _sum(right)
		# Reading "=" as "the answer comes next": does the left side make the first number after "="?
		var trap_says: bool = _sum(left) == right[0]
		var expected: String = "left_side_only"
		if trap_says == truth:
			expected = "thought_unequal" if truth else "thought_equal"
		assert_str(problem.distractors[0]["misconception"]).is_equal(expected)
		names[expected] = true
	assert_dict(names).contains_keys(["left_side_only", "thought_equal", "thought_unequal"])


func test_the_trap_turns_up_among_the_false_items() -> void:
	var traps: int = 0
	for problem: Problem in _problems():
		if problem.prompt_line_id != &"z2.eq.prompt_balance_two_two" or problem.answer:
			continue
		var left_total: int = problem.prompt_params["a"] + problem.prompt_params["b"]
		if problem.prompt_params["c"] == left_total:
			traps += 1 # a + b = (a + b) + d: says true to a child who stops at the first number
			assert_str(problem.distractors[0]["misconception"]).is_equal("left_side_only")
			assert_bool(problem.distractors[0]["value"]).is_true()
	assert_int(traps).is_greater(N / 20)


func test_a_true_backwards_equation_is_a_left_side_only_item() -> void:
	var seen: int = 0
	for problem: Problem in _problems():
		if problem.prompt_line_id == &"z2.eq.prompt_balance_one_two" and problem.answer:
			seen += 1 # c = a + b: "the answer is on the wrong side" says false
			assert_str(problem.distractors[0]["misconception"]).is_equal("left_side_only")
	assert_int(seen).is_greater(N / 10)


func test_a_true_two_and_two_never_shows_the_same_pans() -> void:
	for problem: Problem in _problems():
		if problem.prompt_line_id == &"z2.eq.prompt_balance_two_two" and problem.answer:
			assert_array(problem.visual["left"]).is_not_equal(problem.visual["right"])


func test_true_and_false_buttons_use_word_labels() -> void:
	for problem: Problem in _problems({}, 300):
		assert_dict(problem.meta["label_lines"]).is_equal({"true": "ui.answer.true", "false": "ui.answer.false"})
		assert_bool(Text.has_line(&"ui.answer.true")).is_true()
		assert_bool(Text.has_line(&"ui.answer.false")).is_true()


func test_the_hint_shows_which_way_the_balance_tips() -> void:
	for problem: Problem in _problems({}, 1000):
		var model: Dictionary = problem.hint_steps[1]["visual"]
		var left: int = _sum(problem.visual["left"])
		var right: int = _sum(problem.visual["right"])
		assert_array(model["left"]).is_equal(problem.visual["left"])
		assert_array(model["right"]).is_equal(problem.visual["right"])
		var tilt: String = "level" if left == right else ("left" if left > right else "right")
		assert_str(model["tilt"]).is_equal(tilt)


func test_the_worked_example_says_what_each_side_makes() -> void:
	for problem: Problem in _problems({}, 1000):
		var example: Dictionary = problem.hint_steps[2]["example"]
		var line: String = String(example["prompt_line_id"])
		var params: Dictionary = example["prompt_params"]
		var left: int = 0
		var right: int = 0
		for name: String in SIDES[line][0]:
			left += params[name]
		for name: String in SIDES[line][1]:
			right += params[name]
		assert_bool(example["answer"]).is_equal(left == right)
		if example["answer"]:
			assert_str(example["answer_line_id"]).is_equal("z2.hint.example_true")
			assert_dict(example["answer_params"]).is_equal({"n": left})
		else:
			assert_str(example["answer_line_id"]).is_equal("z2.hint.example_false")
			assert_dict(example["answer_params"]).is_equal({"left": left, "right": right})


func test_an_easier_problem_uses_smaller_numbers() -> void:
	var largest: int = 0
	var largest_easier: int = 0
	for problem: Problem in _problems({}, 1000):
		largest = maxi(largest, maxi(_sum(problem.visual["left"]), _sum(problem.visual["right"])))
	for problem: Problem in _problems({"difficulty": -1}, 1000):
		largest_easier = maxi(largest_easier, maxi(_sum(problem.visual["left"]), _sum(problem.visual["right"])))
	assert_int(largest).is_equal(20)
	assert_int(largest_easier).is_equal(GeneratorKit.eased_max(3, 20, -1))
	assert_int(largest_easier).is_less(largest)


func test_the_easiest_problems_still_have_both_answers_and_the_trap() -> void:
	var truths: Dictionary = {}
	var names: Dictionary = {}
	for problem: Problem in _problems({"difficulty": -6}, 1000):
		assert_int(maxi(_sum(problem.visual["left"]), _sum(problem.visual["right"]))).is_less_equal(5)
		truths[problem.answer] = true
		names[problem.distractors[0]["misconception"]] = true
	assert_int(truths.size()).is_equal(2)
	assert_bool(names.has(&"left_side_only")).is_true()


func test_the_same_seed_gives_the_same_problem() -> void:
	var skill: Skill = _catalog.skill(SKILL)
	for seed: int in range(1, 60):
		assert_dict(GeneratorRegistry.make_problem(skill, seed).to_json()).is_equal(GeneratorRegistry.make_problem(skill, seed).to_json())


func test_eq_balance_true_false_10000_problems_meet_every_rule() -> void:
	var errors: Array[String] = GeneratorChecks.run(_catalog.skill(SKILL), 10000, SkillCatalog.misconception_names())
	assert_array(errors).override_failure_message("\n".join(errors)).is_empty()
