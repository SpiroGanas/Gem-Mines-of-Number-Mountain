# Mirrors scripts/generators/skip_count.gd: a strip really counts by its step, stays under its max,
# hides two interior numbers, and every wrong answer is the named mistake (restated independently).
class_name SkipCountGeneratorTest
extends GdUnitTestSuite

const N: int = 2000
const SKILLS: Array[StringName] = [&"skip.by_10.to_120", &"skip.by_5.to_100", &"skip.by_2.to_40"]

var _catalog: SkillCatalog
var _allowed: Array[StringName]


func before() -> void:
	_catalog = SkillCatalog.load_all()
	_allowed = SkillCatalog.misconception_names()


func _problems(skill_id: StringName, overrides: Dictionary = {}, count: int = N) -> Array[Problem]:
	return GeneratorChecks.make_all(_catalog.skill(skill_id), count, overrides)


func _distractor(problem: Problem, name: StringName) -> Array:
	var values: Array = []
	for entry: Dictionary in problem.distractors:
		if entry["misconception"] == name:
			values.append(entry["value"])
	return values


func _check(skill_id: StringName) -> void:
	var skill: Skill = _catalog.skill(skill_id)
	assert_object(skill).is_not_null()
	var errors: Array[String] = GeneratorChecks.run(skill, 10000, _allowed)
	assert_array(errors).override_failure_message("\n".join(errors)).is_empty()


func test_skip_by_10_to_120_passes_the_shared_checks() -> void:
	_check(&"skip.by_10.to_120")


func test_skip_by_5_to_100_passes_the_shared_checks() -> void:
	_check(&"skip.by_5.to_100")


func test_skip_by_2_to_40_passes_the_shared_checks() -> void:
	_check(&"skip.by_2.to_40")


func test_every_strip_counts_by_its_step_and_stays_within_max() -> void:
	for skill_id: StringName in SKILLS:
		var step: int = _catalog.skill(skill_id).params["step"]
		var high: int = _catalog.skill(skill_id).params["max"]
		for problem: Problem in _problems(skill_id):
			var strip: Array = problem.meta["strip"]
			assert_array(strip).has_size(5)
			assert_int(strip[0] % step).is_equal(0) # starts on a multiple of the step
			assert_int(strip[0]).is_greater_equal(step)
			for index: int in range(1, 5):
				assert_int(strip[index] - strip[index - 1]).is_equal(step)
			assert_int(strip[4]).is_less_equal(high)


func test_the_two_blanks_are_interior_and_listed_in_strip_order() -> void:
	for skill_id: StringName in SKILLS:
		for problem: Problem in _problems(skill_id):
			var strip: Array = problem.meta["strip"]
			var answer: Array = problem.answer
			assert_array(answer).has_size(2)
			var first: int = strip.find(answer[0])
			var second: int = strip.find(answer[1])
			assert_bool(first >= 1 and first <= 3).override_failure_message("blank %d is not interior" % answer[0]).is_true()
			assert_bool(second >= 1 and second <= 3).override_failure_message("blank %d is not interior" % answer[1]).is_true()
			assert_int(first).is_less(second)


func test_pictorial_strips_are_number_lines_labeled_by_the_step() -> void:
	for skill_id: StringName in [&"skip.by_10.to_120", &"skip.by_5.to_100"]:
		var step: int = _catalog.skill(skill_id).params["step"]
		for problem: Problem in _problems(skill_id):
			var line: Dictionary = problem.visual
			var strip: Array = problem.meta["strip"]
			assert_str(problem.representation).is_equal("pictorial")
			assert_str(line["type"]).is_equal("number_line")
			assert_int(line["min"]).is_equal(strip[0])
			assert_int(line["max"]).is_equal(strip[4])
			assert_int(line["labeled_every"]).is_equal(step)
			assert_array(line["markers"]).is_empty()
			assert_array(line["blanks"]).is_equal(problem.answer)
			assert_bool(problem.meta.has("picture")).is_false()


func test_counting_by_twos_shows_the_gems_in_pairs_up_to_the_last_number() -> void:
	for problem: Problem in _problems(&"skip.by_2.to_40"):
		var strip: Array = problem.meta["strip"]
		assert_str(problem.representation).is_equal("concrete")
		assert_dict(problem.visual).is_equal({"type": "pairs", "count": strip[4], "show_pairs": true})
		assert_str(problem.meta["picture"]).is_equal("pairs_up_to_last")
		assert_int(strip[4] % 2).is_equal(0) # every number of the strip is a whole number of pairs


func test_wrong_step_counts_by_ones_from_the_number_before_each_blank() -> void:
	for skill_id: StringName in SKILLS:
		for problem: Problem in _problems(skill_id):
			var strip: Array = problem.meta["strip"]
			var answer: Array = problem.answer
			# Write the strip the way a child counting by ones would, left to right.
			var written: Array = [strip[0]]
			for index: int in range(1, 5):
				written.append(written[index - 1] + 1 if answer.has(strip[index]) else strip[index])
			var expected: Array = [written[strip.find(answer[0])], written[strip.find(answer[1])]]
			assert_array(_distractor(problem, &"wrong_step")).is_equal([expected])


func test_by_tens_adds_a_decade_skip_that_moves_one_blank_by_ten() -> void:
	for problem: Problem in _problems(&"skip.by_10.to_120"):
		var skipped: Array = _distractor(problem, &"decade_skip")
		assert_array(skipped).has_size(1)
		var value: Array = skipped[0]
		var changed: int = 0
		for index: int in 2:
			if value[index] != problem.answer[index]:
				changed += 1
				assert_int(absi(value[index] - problem.answer[index])).is_equal(10)
		assert_int(changed).is_equal(1)
		assert_int(value[0]).is_not_equal(value[1]) # one tile per number


func test_by_twos_adds_blanks_one_too_big() -> void:
	for problem: Problem in _problems(&"skip.by_2.to_40"):
		assert_array(_distractor(problem, &"off_by_one")).is_equal([[problem.answer[0] + 1, problem.answer[1] + 1]])


func test_by_fives_has_only_the_wrong_step_mistake() -> void:
	for problem: Problem in _problems(&"skip.by_5.to_100", {}, 500):
		assert_array(problem.distractors).has_size(1)
		assert_str(problem.distractors[0]["misconception"]).is_equal("wrong_step")


func test_the_tiles_are_the_answer_and_the_wrong_numbers_each_once() -> void:
	var answer_first: int = 0
	for skill_id: StringName in SKILLS:
		for problem: Problem in _problems(skill_id):
			var board: Dictionary = problem.meta["tile_board"]
			assert_int(board["slots"]).is_equal(2)
			assert_bool(board["ordered"]).is_true()
			var expected: Array = problem.answer.duplicate()
			for wrong: Array in problem.distractor_values():
				for value: int in wrong:
					if not expected.has(value):
						expected.append(value)
			assert_array(board["tiles"]).contains_exactly_in_any_order(expected)
			assert_int(board["tiles"].size()).is_less_equal(8)
			if board["tiles"].slice(0, 2) == problem.answer:
				answer_first += 1
	assert_int(answer_first).is_less(N) # the tiles are shuffled, not answer first


func test_the_hint_model_fills_in_the_first_blank_and_hops_by_the_step() -> void:
	for skill_id: StringName in SKILLS:
		var step: int = _catalog.skill(skill_id).params["step"]
		for problem: Problem in _problems(skill_id, {}, 500):
			var model: Dictionary = problem.hint_steps[1]["visual"]
			var strip: Array = problem.meta["strip"]
			assert_str(model["type"]).is_equal("number_line")
			assert_int(model["min"]).is_equal(strip[0])
			assert_int(model["max"]).is_equal(strip[4])
			assert_array(model["blanks"]).is_equal([problem.answer[1]])
			assert_array(model["jumps"]).has_size(4)
			for jump: Dictionary in model["jumps"]:
				assert_int(jump["to"] - jump["from"]).is_equal(step)
			var example: Dictionary = problem.hint_steps[2]["example"]
			assert_dict(example["answer_params"]).is_equal({"a": example["answer"][0], "b": example["answer"][1]})


func test_every_start_and_every_blank_pair_turns_up() -> void:
	var starts: Dictionary = {}
	var pairs: Dictionary = {}
	for problem: Problem in _problems(&"skip.by_10.to_120"):
		starts[problem.meta["strip"][0]] = true
		pairs["%d/%d" % [problem.meta["strip"].find(problem.answer[0]), problem.meta["strip"].find(problem.answer[1])]] = true
	assert_array(starts.keys()).contains_exactly_in_any_order([10, 20, 30, 40, 50, 60, 70, 80])
	assert_array(pairs.keys()).contains_exactly_in_any_order(["1/2", "1/3", "2/3"])


func test_easier_difficulty_gives_smaller_strips() -> void:
	for skill_id: StringName in SKILLS:
		var normal: int = 0
		for problem: Problem in _problems(skill_id, {}, 500):
			normal = maxi(normal, problem.meta["strip"][4])
		var easy: int = 0
		for problem: Problem in _problems(skill_id, {"difficulty": -1}, 500):
			easy = maxi(easy, problem.meta["strip"][4])
		assert_int(normal).is_equal(_catalog.skill(skill_id).params["max"])
		assert_int(easy).is_less(normal)


func test_the_easiest_strips_still_have_room_for_a_different_example() -> void:
	for skill_id: StringName in SKILLS:
		var errors: Array[String] = GeneratorChecks.run(_catalog.skill(skill_id), 500, _allowed, {"difficulty": -8})
		assert_array(errors).override_failure_message("\n".join(errors)).is_empty()


func test_the_same_seed_gives_the_same_problem_and_the_global_rng_is_untouched() -> void:
	var skill: Skill = _catalog.skill(&"skip.by_2.to_40")
	for seed: int in range(1, 200):
		assert_dict(GeneratorRegistry.make_problem(skill, seed).to_json()).is_equal(GeneratorRegistry.make_problem(skill, seed).to_json())
	seed(777)
	var expected: int = randi()
	seed(777)
	_problems(&"skip.by_10.to_120", {}, 300)
	assert_int(randi()).is_equal(expected) # generators use only the rng they are given
