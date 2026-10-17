# Mirrors scripts/generators/counting.gd: the math of each counting mode, restated independently.
class_name CountingGeneratorTest
extends GdUnitTestSuite

const N: int = 2000

var _catalog: SkillCatalog


func before() -> void:
	_catalog = SkillCatalog.load_all()


func _problems(skill_id: StringName, overrides: Dictionary = {}, count: int = N) -> Array[Problem]:
	return GeneratorChecks.make_all(_catalog.skill(skill_id), count, overrides)


func _total(pile: Dictionary) -> int:
	return pile["hundreds"] * 100 + pile["tens"] * 10 + pile["ones"]


func _distractor(problem: Problem, name: StringName) -> Array:
	var values: Array = []
	for entry: Dictionary in problem.distractors:
		if entry["misconception"] == name:
			values.append(entry["value"])
	return values


func test_objects_answer_matches_the_gems_shown() -> void:
	for problem: Problem in _problems(&"count.to_20.objects"):
		var n: int = problem.answer
		assert_int(n).is_between(1, 20)
		assert_int(_total(problem.visual["piles"][0])).is_equal(n)
		assert_int(problem.hint_steps[1]["visual"]["count"]).is_equal(n)
		assert_int(problem.hint_steps[1]["visual"]["frames"]).is_equal(1 if n <= 10 else 2)


func test_objects_distractors_are_the_named_mistakes() -> void:
	for problem: Problem in _problems(&"count.to_20.objects"):
		var n: int = problem.answer
		for value: int in _distractor(problem, &"off_by_one"):
			assert_bool(value == n - 1 or value == n + 1).is_true()
		for value: int in _distractor(problem, &"double_counted"):
			assert_bool(value == n + 2 or value == n + 3).is_true()
		assert_int(problem.distractors.size()).is_greater_equal(2) # enough for three choice buttons


func test_read_marker_is_the_answer_and_the_line_shows_it() -> void:
	for problem: Problem in _problems(&"count.to_120.read"):
		var n: int = problem.answer
		var line: Dictionary = problem.visual
		assert_int(n).is_between(21, 120)
		assert_array(line["markers"]).contains_exactly([n])
		assert_int(line["min"]).is_less_equal(n)
		assert_int(line["max"]).is_greater_equal(n)
		assert_int(line["max"] - line["min"]).is_equal(30)
		assert_int(line["min"] % 10).is_equal(0)
		assert_int(line["labeled_every"]).is_equal(10)
		assert_int(line["max"]).is_less_equal(120)
		for value: int in _distractor(problem, &"digit_swap"):
			var digits: String = str(n)
			var swapped: String = digits.substr(0, digits.length() - 2) + digits[digits.length() - 1] + digits[digits.length() - 2]
			assert_int(value).is_equal(int(swapped))


func test_next_is_one_more_than_the_second_number() -> void:
	for problem: Problem in _problems(&"count.to_120.next"):
		var a: int = problem.prompt_params["a"]
		var b: int = problem.prompt_params["b"]
		assert_int(b).is_equal(a + 1)
		assert_int(problem.answer).is_equal(b + 1)
		assert_int(problem.answer).is_between(3, 120)
		for value: int in _distractor(problem, &"decade_skip"):
			assert_bool(value == problem.answer + 10 or value == problem.answer - 10).is_true()
			if b % 10 == 9 and problem.answer - 10 >= 1:
				assert_int(value).is_equal(problem.answer - 10) # 39, 40: the tempting answer is 30


func test_between_is_the_middle_number() -> void:
	for problem: Problem in _problems(&"count.to_120.between"):
		var a: int = problem.prompt_params["a"]
		assert_int(problem.prompt_params["b"]).is_equal(a + 2)
		assert_int(problem.answer).is_equal(a + 1)
		var wrong: Array = problem.distractor_values()
		wrong.sort()
		assert_array(wrong).contains_exactly([a, a + 2])


func test_strip_blanks_are_interior_and_the_answer_lists_them_in_order() -> void:
	for problem: Problem in _problems(&"count.to_120.fill_strip"):
		var line: Dictionary = problem.visual
		assert_int(line["max"] - line["min"] + 1).is_equal(5)
		assert_int(line["labeled_every"]).is_equal(1)
		assert_array(problem.answer).has_size(2)
		var sorted: Array = problem.answer.duplicate()
		sorted.sort()
		assert_array(problem.answer).is_equal(sorted)
		assert_array(line["blanks"]).is_equal(problem.answer)
		for blank: int in problem.answer:
			assert_bool(blank > line["min"] and blank < line["max"]).is_true() # never the first or last number
		assert_int(line["max"]).is_less_equal(120)
		for shifted: Array in _distractor(problem, &"off_by_one"):
			assert_array(shifted).is_equal([problem.answer[0] + 1, problem.answer[1] + 1])
		for jumped: Array in _distractor(problem, &"decade_skip"):
			assert_array(jumped).is_equal([problem.answer[0] + 10, problem.answer[1]])


func test_write_numeral_in_both_representations() -> void:
	var concrete: int = 0
	var abstract: int = 0
	for problem: Problem in _problems(&"count.write.numeral"):
		var n: int = problem.answer
		assert_int(n).is_between(11, 120)
		if problem.representation == &"concrete":
			concrete += 1
			assert_int(_total(problem.visual["piles"][0])).is_equal(n)
		else:
			abstract += 1
			assert_int(n).is_less_equal(99)
			assert_int(problem.prompt_params["tens"] * 10 + problem.prompt_params["ones"]).is_equal(n)
			assert_bool(problem.visual.is_empty()).is_true()
	assert_int(concrete).is_greater(500)
	assert_int(abstract).is_greater(500)


func test_easier_difficulty_gives_smaller_numbers() -> void:
	var normal: int = 0
	var easy: int = 0
	for problem: Problem in _problems(&"count.to_20.objects", {"difficulty": 0}):
		normal = maxi(normal, problem.answer)
	var total_easy: int = 0
	for problem: Problem in _problems(&"count.to_20.objects", {"difficulty": -2}):
		easy = maxi(easy, problem.answer)
		total_easy += problem.answer
	assert_int(normal).is_equal(20)
	assert_int(easy).is_less_equal(10)
	assert_float(float(total_easy) / float(N)).is_less(7.0)


func test_the_easier_rung_asks_for_one_step_easier() -> void:
	var problem: Problem = _problems(&"count.to_120.next", {"difficulty": -1}, 1)[0]
	assert_int(problem.hint_steps[3]["easier_params"]["difficulty"]).is_equal(-2)
	var problem0: Problem = _problems(&"count.to_120.next", {}, 1)[0]
	assert_int(problem0.hint_steps[3]["easier_params"]["difficulty"]).is_equal(-1)


func test_the_same_seed_gives_the_same_problem_and_the_global_rng_is_untouched() -> void:
	var skill: Skill = _catalog.skill(&"count.to_120.fill_strip")
	for seed: int in range(1, 200):
		assert_dict(GeneratorRegistry.make_problem(skill, seed).to_json()).is_equal(GeneratorRegistry.make_problem(skill, seed).to_json())
	seed(777)
	var expected: int = randi()
	seed(777)
	_problems(&"count.to_120.between", {}, 300)
	assert_int(randi()).is_equal(expected) # generators use only the rng they are given
