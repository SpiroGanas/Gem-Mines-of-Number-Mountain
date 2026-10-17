# Mirrors scripts/generators/missing_part.gd. Putting the answer back into the equation must make
# it true; each wrong answer is the named mistake and leaves the equation false.
class_name MissingPartGeneratorTest
extends GdUnitTestSuite

const N: int = 3000
const ADDEND: StringName = &"eq.missing_addend.to_20"
const SUBTRAHEND: StringName = &"eq.missing_subtrahend.to_20"

var _catalog: SkillCatalog


func before() -> void:
	_catalog = SkillCatalog.load_all()


func _problems(skill_id: StringName, overrides: Dictionary = {}, count: int = N) -> Array[Problem]:
	return GeneratorChecks.make_all(_catalog.skill(skill_id), count, overrides)


func test_the_missing_addend_completes_the_sum() -> void:
	var answers: Dictionary = {}
	for problem: Problem in _problems(ADDEND):
		var a: int = problem.prompt_params["a"]
		var c: int = problem.prompt_params["c"]
		assert_str(problem.prompt_line_id).is_equal("z2.eq.prompt_missing_addend")
		assert_int(a).is_between(1, 19)
		assert_int(c).is_between(2, 20)
		assert_int(problem.answer).is_greater_equal(1)
		assert_int(a + problem.answer).is_equal(c)
		answers[problem.answer] = true
	for value: int in range(1, 20):
		assert_bool(answers.has(value)).override_failure_message("missing addend %d never turns up" % value).is_true()


func test_the_missing_addend_wrong_answers_are_the_named_mistakes() -> void:
	for problem: Problem in _problems(ADDEND):
		var a: int = problem.prompt_params["a"]
		var c: int = problem.prompt_params["c"]
		var answer: int = problem.answer
		var named: Array = []
		for entry: Dictionary in problem.distractors:
			var value: int = entry["value"]
			assert_int(a + value).is_not_equal(c) # a wrong answer never completes the sum
			named.append([String(entry["misconception"]), value])
		# Adding the two numbers shown, and one more or one less than the answer.
		assert_array(named).contains_exactly_in_any_order([["added_both", a + c], ["off_by_one", answer - 1], ["off_by_one", answer + 1]])


func test_the_missing_addend_picture_shows_the_part_and_the_hint_fills_the_rest() -> void:
	for problem: Problem in _problems(ADDEND, {}, 1000):
		var a: int = problem.prompt_params["a"]
		assert_dict(problem.visual).is_equal({"type": "ten_frame", "count": a, "frames": 2})
		assert_dict(problem.hint_steps[1]["visual"]).is_equal({"type": "ten_frame", "count": a, "second": problem.answer, "frames": 2})
		var example: Dictionary = problem.hint_steps[2]["example"]
		assert_str(example["answer_line_id"]).is_equal("z2.hint.example_missing_addend")
		var said: Dictionary = example["answer_params"]
		assert_int(said["a"] + said["n"]).is_equal(said["c"])
		assert_int(said["n"]).is_equal(example["answer"])
		assert_dict({"a": said["a"], "c": said["c"]}).is_equal(example["prompt_params"])


func test_the_missing_subtrahend_leaves_what_is_left() -> void:
	var answers: Dictionary = {}
	for problem: Problem in _problems(SUBTRAHEND):
		var a: int = problem.prompt_params["a"]
		var c: int = problem.prompt_params["c"]
		assert_str(problem.prompt_line_id).is_equal("z2.eq.prompt_missing_subtrahend")
		assert_int(a).is_between(1, 19)
		assert_int(c).is_between(2, 20)
		assert_int(problem.answer).is_greater_equal(1)
		assert_int(c - problem.answer).is_equal(a)
		answers[problem.answer] = true
		# Adding the two numbers is the one named mistake; it never takes c down to a.
		assert_array(problem.distractors).is_equal([{"value": c + a, "misconception": &"added_both"}])
		assert_int(c - (c + a)).is_not_equal(a)
	for value: int in range(1, 20):
		assert_bool(answers.has(value)).override_failure_message("missing number %d never turns up" % value).is_true()


func test_the_missing_subtrahend_line_jumps_back_from_c_to_a_in_the_hint() -> void:
	for problem: Problem in _problems(SUBTRAHEND, {}, 1000):
		var a: int = problem.prompt_params["a"]
		var c: int = problem.prompt_params["c"]
		var line: Dictionary = problem.visual
		assert_str(line["type"]).is_equal("number_line")
		assert_array(line["markers"]).contains_exactly_in_any_order([a, c])
		assert_bool(line.has("jumps")).is_false() # the picture marks both ends; the jump is the hint
		assert_int(line["min"]).is_less_equal(a)
		assert_int(line["max"]).is_greater_equal(c)
		var model: Dictionary = problem.hint_steps[1]["visual"]
		assert_array(model["jumps"]).is_equal([{"from": c, "to": a}])
		assert_int(model["min"]).is_equal(line["min"])
		assert_int(model["max"]).is_equal(line["max"])
		var example: Dictionary = problem.hint_steps[2]["example"]
		assert_str(example["answer_line_id"]).is_equal("z2.hint.example_missing_subtrahend")
		var said: Dictionary = example["answer_params"]
		assert_int(said["c"] - said["n"]).is_equal(said["a"])
		assert_int(said["n"]).is_equal(example["answer"])


func test_an_easier_problem_uses_a_smaller_whole() -> void:
	for skill_id: StringName in [ADDEND, SUBTRAHEND]:
		var largest: int = 0
		var largest_easier: int = 0
		for problem: Problem in _problems(skill_id, {}, 1000):
			largest = maxi(largest, problem.prompt_params["c"])
		for problem: Problem in _problems(skill_id, {"difficulty": -1}, 1000):
			largest_easier = maxi(largest_easier, problem.prompt_params["c"])
		assert_int(largest).is_equal(20)
		assert_int(largest_easier).is_equal(GeneratorKit.eased_max(2, 20, -1))
		assert_int(largest_easier).is_less(largest)


func test_the_smallest_whole_is_one_plus_one() -> void:
	var smallest: int = 100
	for problem: Problem in _problems(ADDEND):
		smallest = mini(smallest, problem.prompt_params["c"])
	assert_int(smallest).is_equal(2)


func test_the_same_seed_gives_the_same_problem() -> void:
	for skill_id: StringName in [ADDEND, SUBTRAHEND]:
		var skill: Skill = _catalog.skill(skill_id)
		for seed: int in range(1, 60):
			assert_dict(GeneratorRegistry.make_problem(skill, seed).to_json()).is_equal(GeneratorRegistry.make_problem(skill, seed).to_json())


func test_eq_missing_addend_to_20_10000_problems_meet_every_rule() -> void:
	var errors: Array[String] = GeneratorChecks.run(_catalog.skill(ADDEND), 10000, SkillCatalog.misconception_names())
	assert_array(errors).override_failure_message("\n".join(errors)).is_empty()


func test_eq_missing_subtrahend_to_20_10000_problems_meet_every_rule() -> void:
	var errors: Array[String] = GeneratorChecks.run(_catalog.skill(SUBTRAHEND), 10000, SkillCatalog.misconception_names())
	assert_array(errors).override_failure_message("\n".join(errors)).is_empty()
