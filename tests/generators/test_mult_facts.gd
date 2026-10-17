# Mirrors scripts/generators/mult_facts.gd: a x b is found by adding b to itself a times (never by the
# generator's own multiplication), the factors stay in the skill's ranges, zero shows up only where
# it can be drawn (the abstract problems), and every wrong answer is a named mistake.
class_name MultFactsGeneratorTest
extends GdUnitTestSuite

const N: int = 2000
const SKILLS: Array[StringName] = [&"mult.facts.0_5", &"mult.facts.6_10", &"mult.facts.mixed"]

var _catalog: SkillCatalog
var _allowed: Array[StringName]


func before() -> void:
	_catalog = SkillCatalog.load_all()
	_allowed = SkillCatalog.misconception_names()


func _problems(skill_id: StringName, overrides: Dictionary = {}, count: int = N) -> Array[Problem]:
	return GeneratorChecks.make_all(_catalog.skill(skill_id), count, overrides)


func _sum_of_groups(groups: int, size: int) -> int:
	var total: int = 0
	for _group: int in groups:
		total += size
	return total


func _names(problem: Problem) -> Array:
	var names: Array = []
	for entry: Dictionary in problem.distractors:
		names.append(entry["misconception"])
	return names


func test_every_skill_passes_the_shared_checks() -> void:
	for skill_id: StringName in SKILLS:
		var skill: Skill = _catalog.skill(skill_id)
		assert_object(skill).is_not_null()
		var errors: Array[String] = GeneratorChecks.run(skill, 10000, _allowed)
		assert_array(errors).override_failure_message("\n".join(errors)).is_empty()


func test_the_answer_is_the_sum_of_a_equal_groups_of_b() -> void:
	for skill_id: StringName in SKILLS:
		for problem: Problem in _problems(skill_id):
			var a: int = problem.prompt_params["a"]
			var b: int = problem.prompt_params["b"]
			assert_str(problem.prompt_line_id).is_equal("z4.mult.prompt_fact")
			assert_int(problem.answer).override_failure_message("%s seed %d" % [skill_id, problem.seed]).is_equal(_sum_of_groups(a, b))


func test_the_factors_stay_in_the_skills_ranges() -> void:
	var seen_zero: bool = false
	for problem: Problem in _problems(&"mult.facts.0_5"):
		var a: int = problem.prompt_params["a"]
		var b: int = problem.prompt_params["b"]
		assert_int(a).is_between(0, 5)
		assert_int(b).is_between(0, 5)
		assert_bool(a == 0 and b == 0).is_false() # 0 x 0 leaves no wrong answer to offer
		if a == 0 or b == 0:
			seen_zero = true
			assert_str(problem.representation).override_failure_message("zero cannot be drawn").is_equal("abstract")
	assert_bool(seen_zero).is_true()
	for problem: Problem in _problems(&"mult.facts.6_10"):
		var a: int = problem.prompt_params["a"]
		var b: int = problem.prompt_params["b"]
		var table: int = problem.meta["table"]
		assert_int(table).is_between(6, 10)
		assert_int(a if problem.meta["table_first"] else b).is_equal(table)
		assert_int(b if problem.meta["table_first"] else a).is_between(2, 10)
	for problem: Problem in _problems(&"mult.facts.mixed"):
		assert_int(problem.prompt_params["a"]).is_between(2, 10)
		assert_int(problem.prompt_params["b"]).is_between(2, 10)


func test_every_fact_of_the_ranges_can_be_asked() -> void:
	var seen: Dictionary = {}
	for problem: Problem in _problems(&"mult.facts.0_5", {"representation": &"abstract"}, 4000):
		seen["%d,%d" % [problem.prompt_params["a"], problem.prompt_params["b"]]] = true
	assert_int(seen.size()).is_equal(35) # the 36 facts from 0 to 5 less 0 x 0
	seen.clear()
	for problem: Problem in _problems(&"mult.facts.mixed", {}, 4000):
		seen["%d,%d" % [problem.prompt_params["a"], problem.prompt_params["b"]]] = true
	assert_int(seen.size()).is_equal(81) # 2 to 10 times 2 to 10


func test_the_pictures_match_the_representation() -> void:
	var counts: Dictionary = {"concrete": 0, "pictorial": 0, "abstract": 0}
	for problem: Problem in _problems(&"mult.facts.0_5"):
		var a: int = problem.prompt_params["a"]
		var b: int = problem.prompt_params["b"]
		counts[String(problem.representation)] += 1
		match problem.representation:
			&"concrete":
				assert_dict(problem.visual).is_equal({"type": "array", "rows": a, "cols": b})
			&"pictorial":
				var hops: Array = problem.visual["jumps"]
				assert_int(hops.size()).is_equal(a)
				assert_int(problem.visual["max"]).is_equal(a * b)
				assert_int(problem.visual["labeled_every"]).is_equal(b)
			&"abstract":
				assert_dict(problem.visual).is_empty()
	for count: int in counts.values():
		assert_int(count).is_greater(100)


func test_wrong_answers_are_the_named_mistakes() -> void:
	for skill_id: StringName in SKILLS:
		for problem: Problem in _problems(skill_id):
			var a: int = problem.prompt_params["a"]
			var b: int = problem.prompt_params["b"]
			var product: int = problem.answer
			assert_array(problem.distractors).is_not_empty()
			for entry: Dictionary in problem.distractors:
				var value: int = entry["value"]
				var where: String = "%s seed %d: %d x %d, %s" % [skill_id, problem.seed, a, b, entry]
				assert_int(value).override_failure_message(where).is_greater_equal(0)
				match String(entry["misconception"]):
					"off_by_group":
						assert_bool([product + a, product - a, product + b, product - b].has(value)).override_failure_message(where).is_true()
					"added_factors":
						assert_int(value).override_failure_message(where).is_equal(a + b)
					"digit_swap":
						assert_str(str(value)).override_failure_message(where).is_equal(str(product).reverse())
						assert_int(product % 10).is_not_equal(0)
					_:
						fail("unexpected misconception in " + where)


func test_the_first_three_buttons_mix_kinds_of_mistake() -> void:
	var mixed: int = 0
	var total: int = 0
	for problem: Problem in _problems(&"mult.facts.mixed"):
		var kinds: Dictionary = {}
		for entry: Dictionary in problem.distractors.slice(0, 3):
			kinds[entry["misconception"]] = true
		total += 1
		if kinds.size() >= 2:
			mixed += 1
	assert_float(float(mixed) / float(total)).is_greater(0.95)


func test_zero_facts_still_have_a_wrong_answer() -> void:
	var checked: int = 0
	for problem: Problem in _problems(&"mult.facts.0_5", {"representation": &"abstract"}, 4000):
		if problem.answer == 0:
			checked += 1
			assert_array(problem.distractors).is_not_empty()
			assert_dict(problem.hint_steps[1]["visual"]).is_equal({"type": "number_line", "min": 0, "max": 10, "labeled_every": 1, "markers": [0], "blanks": []})
	assert_int(checked).is_greater(100)


func test_the_hint_picture_is_the_array_and_the_example_states_its_product() -> void:
	for problem: Problem in _problems(&"mult.facts.6_10"):
		var a: int = problem.prompt_params["a"]
		var b: int = problem.prompt_params["b"]
		assert_dict(problem.hint_steps[1]["visual"]).is_equal({"type": "array", "rows": a, "cols": b, "outline_rows": true})
		var example: Dictionary = problem.hint_steps[2]["example"]
		assert_str(example["answer_line_id"]).is_equal("z3.hint.example_fact")
		var ea: int = example["prompt_params"]["a"]
		var eb: int = example["prompt_params"]["b"]
		assert_dict(example["answer_params"]).is_equal({"a": ea, "b": eb, "product": _sum_of_groups(ea, eb)})


func test_easier_difficulty_lowers_the_other_factor_but_not_the_table() -> void:
	var biggest_other: int = 0
	var seen_tables: Dictionary = {}
	for problem: Problem in _problems(&"mult.facts.6_10", {"difficulty": -2}, 1500):
		var other: int = problem.prompt_params["b"] if problem.meta["table_first"] else problem.prompt_params["a"]
		biggest_other = maxi(biggest_other, other)
		seen_tables[problem.meta["table"]] = true
	assert_int(biggest_other).is_less(10)
	assert_int(seen_tables.size()).is_equal(5)


func test_the_easiest_problems_still_pass_the_shared_checks() -> void:
	for skill_id: StringName in SKILLS:
		var errors: Array[String] = GeneratorChecks.run(_catalog.skill(skill_id), 500, _allowed, {"difficulty": -8})
		assert_array(errors).override_failure_message("\n".join(errors)).is_empty()


func test_the_same_seed_gives_the_same_problem_and_the_global_rng_is_untouched() -> void:
	var skill: Skill = _catalog.skill(&"mult.facts.mixed")
	for seed: int in range(1, 200):
		assert_dict(GeneratorRegistry.make_problem(skill, seed).to_json()).is_equal(GeneratorRegistry.make_problem(skill, seed).to_json())
	seed(777)
	var expected: int = randi()
	seed(777)
	_problems(&"mult.facts.mixed", {}, 300)
	assert_int(randi()).is_equal(expected)
