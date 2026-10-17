# Mirrors scripts/generators/multiples.gd: multiples are found by counting up (b, b + b, ...), the first
# shared multiple by walking both lists, and every wrong answer is the mistake it names.
class_name MultiplesGeneratorTest
extends GdUnitTestSuite

const N: int = 2000
const SKILLS: Array[StringName] = [&"mul.list.first_k", &"mul.check.is_multiple", &"mul.common.first"]

var _catalog: SkillCatalog
var _allowed: Array[StringName]


func before() -> void:
	_catalog = SkillCatalog.load_all()
	_allowed = SkillCatalog.misconception_names()


func _problems(skill_id: StringName, overrides: Dictionary = {}, count: int = N) -> Array[Problem]:
	return GeneratorChecks.make_all(_catalog.skill(skill_id), count, overrides)


## b, b + b, b + b + b... (count of them), found by counting up.
func _count_up(b: int, count: int) -> Array[int]:
	var found: Array[int] = []
	var at: int = 0
	for _step: int in count:
		at += b
		found.append(at)
	return found


func _factors(n: int) -> Array[int]:
	var found: Array[int] = []
	for d: int in range(1, n + 1):
		if n % d == 0:
			found.append(d)
	return found


func _by_name(problem: Problem, name: String) -> Array:
	var values: Array = []
	for entry: Dictionary in problem.distractors:
		if entry["misconception"] == name:
			values.append(entry["value"])
	return values


func test_every_skill_passes_the_shared_checks() -> void:
	for skill_id: StringName in SKILLS:
		var skill: Skill = _catalog.skill(skill_id)
		assert_object(skill).is_not_null()
		var errors: Array[String] = GeneratorChecks.run(skill, 10000, _allowed)
		assert_array(errors).override_failure_message("\n".join(errors)).is_equal([])


# --- mul.list.first_k ------------------------------------------------------------------------


func test_the_first_k_multiples_are_in_order_and_on_the_board() -> void:
	var ks: Dictionary = {}
	var bs: Dictionary = {}
	for problem: Problem in _problems(&"mul.list.first_k"):
		var k: int = problem.prompt_params["k"]
		var b: int = problem.prompt_params["b"]
		ks[k] = true
		bs[b] = true
		assert_str(problem.prompt_line_id).is_equal("z4.mul.prompt_first_k")
		assert_array(problem.answer).override_failure_message("first %d multiples of %d" % [k, b]).is_equal(_count_up(b, k))
		var board: Dictionary = problem.meta["tile_board"]
		assert_bool(board["ordered"]).is_true()
		assert_int(board["slots"]).is_equal(k)
		assert_int(board["tiles"].size()).is_between(k, 8)
		for value: int in problem.answer:
			assert_bool(board["tiles"].has(value)).is_true()
	assert_array(ks.keys()).contains_exactly_in_any_order([3, 4, 5])
	assert_array(bs.keys()).contains_exactly_in_any_order([2, 3, 4, 5, 6, 7, 8, 9])


func test_wrong_boards_start_early_or_late_or_list_factors() -> void:
	var counts: Dictionary = {"off_by_b": 0, "factor_not_multiple": 0}
	for problem: Problem in _problems(&"mul.list.first_k"):
		var k: int = problem.prompt_params["k"]
		var b: int = problem.prompt_params["b"]
		var late: Array[int] = _count_up(b, k + 1).slice(1)
		var early: Array[int] = [0]
		early.append_array(_count_up(b, k - 1))
		assert_array(_by_name(problem, "off_by_b")).is_not_empty()
		for board: Array in _by_name(problem, "off_by_b"):
			counts["off_by_b"] += 1
			assert_bool(board == late or board == early).override_failure_message("b=%d k=%d board %s" % [b, k, board]).is_true()
		for board: Array in _by_name(problem, "factor_not_multiple"):
			counts["factor_not_multiple"] += 1
			assert_array(board).is_equal(_factors(b).slice(0, k))
			assert_int(_factors(b).size()).is_greater_equal(k)
		if _factors(b).size() < k:
			assert_array(_by_name(problem, "factor_not_multiple")).is_empty()
	for name: String in counts:
		assert_int(counts[name]).override_failure_message(name).is_greater(100)


func test_the_first_multiples_picture_hops_by_b() -> void:
	for problem: Problem in _problems(&"mul.list.first_k", {}, 300):
		var k: int = problem.prompt_params["k"]
		var b: int = problem.prompt_params["b"]
		var model: Dictionary = problem.hint_steps[1]["visual"]
		assert_int(model["max"]).is_equal(k * b)
		assert_int(model["jumps"].size()).is_equal(k)
		assert_int(model["labeled_every"]).is_equal(b)
		var example: Dictionary = problem.hint_steps[2]["example"]
		var eb: int = example["prompt_params"]["b"]
		assert_dict(example["answer_params"]).is_equal({"b": eb, "m2": eb + eb, "m3": eb + eb + eb})


# --- mul.check.is_multiple -------------------------------------------------------------------


func test_the_answer_is_whether_counting_by_b_lands_on_n() -> void:
	for problem: Problem in _problems(&"mul.check.is_multiple"):
		var n: int = problem.prompt_params["n"]
		var b: int = problem.prompt_params["b"]
		assert_str(problem.prompt_line_id).is_equal("z4.mul.prompt_check")
		var lands: bool = false
		for stop: int in _count_up(b, 12):
			lands = lands or stop == n
		assert_bool(problem.answer).override_failure_message("%d by %d" % [n, b]).is_equal(lands)
		assert_array(problem.distractors).has_size(1)
		assert_bool(problem.distractors[0]["value"]).is_equal(not problem.answer)
		assert_dict(problem.meta["label_lines"]).is_equal({"true": "ui.common.yes", "false": "ui.common.no"})


func test_each_wrong_answer_stands_for_the_mistake_it_names() -> void:
	var counts: Dictionary = {"off_by_b": 0, "factor_not_multiple": 0, "no_check_made": 0}
	var yes: int = 0
	var total: int = 0
	for problem: Problem in _problems(&"mul.check.is_multiple"):
		var n: int = problem.prompt_params["n"]
		var b: int = problem.prompt_params["b"]
		var name: String = String(problem.distractors[0]["misconception"])
		counts[name] += 1
		total += 1
		yes += 1 if problem.answer else 0
		match name:
			"off_by_b":
				assert_bool(problem.answer).is_true()
				assert_int(n).is_equal(b) # b itself is the first multiple
			"factor_not_multiple":
				assert_bool(problem.answer).is_false()
				assert_bool(_factors(b).has(n) and n < b).override_failure_message("%d is not a smaller factor of %d" % [n, b]).is_true()
			"no_check_made":
				if problem.answer:
					assert_bool(n > b).is_true()
				else:
					assert_bool(n % b != 0 and b % n != 0).override_failure_message("%d / %d" % [n, b]).is_true()
	for name: String in counts:
		assert_int(counts[name]).override_failure_message(name).is_greater(100)
	assert_float(float(yes) / float(total)).is_between(0.35, 0.55)


func test_the_hop_picture_reaches_the_first_multiple_at_or_past_n() -> void:
	for problem: Problem in _problems(&"mul.check.is_multiple", {"representation": &"pictorial"}):
		var n: int = problem.prompt_params["n"]
		var b: int = problem.prompt_params["b"]
		var line: Dictionary = problem.visual
		assert_array(line["markers"]).is_equal([n])
		var hops: Array = line["jumps"]
		assert_int(hops.size()).is_between(1, 10)
		var last: int = hops[hops.size() - 1]["to"]
		assert_bool(last >= n and last - b < n).override_failure_message("%d by %d ends at %d" % [n, b, last]).is_true()
		assert_bool(last == n).is_equal(problem.answer)


# --- mul.common.first ------------------------------------------------------------------------


func test_the_first_common_multiple_is_the_first_number_in_both_lists() -> void:
	var seen_divides: bool = false
	var seen_coprime: bool = false
	for problem: Problem in _problems(&"mul.common.first"):
		var a: int = problem.prompt_params["a"]
		var b: int = problem.prompt_params["b"]
		assert_str(problem.prompt_line_id).is_equal("z4.mul.prompt_common")
		assert_int(a).is_not_equal(b)
		assert_int(a).is_between(2, 9)
		assert_int(b).is_between(2, 9)
		var of_a: Array[int] = _count_up(a, b)
		var of_b: Array[int] = _count_up(b, a)
		var first: int = -1
		for value: int in of_a:
			if of_b.has(value):
				first = value
				break
		assert_int(problem.answer).override_failure_message("first multiple shared by %d and %d" % [a, b]).is_equal(first)
		seen_divides = seen_divides or a % b == 0 or b % a == 0
		seen_coprime = seen_coprime or _factors(a).filter(func(f: int) -> bool: return _factors(b).has(f)) == [1]
	assert_bool(seen_divides).is_true() # 3 and 6, 2 and 8...
	assert_bool(seen_coprime).is_true() # 4 and 9, 2 and 3...


func test_wrong_answers_are_the_product_the_common_factor_or_a_step_away() -> void:
	for problem: Problem in _problems(&"mul.common.first"):
		var a: int = problem.prompt_params["a"]
		var b: int = problem.prompt_params["b"]
		var first: int = problem.answer
		var common: int = 1
		for d: int in _factors(a):
			if b % d == 0:
				common = d
		assert_array(problem.distractors).is_not_empty()
		for entry: Dictionary in problem.distractors:
			var value: int = entry["value"]
			var where: String = "%d and %d: %s" % [a, b, entry]
			assert_int(value).is_greater(0)
			match String(entry["misconception"]):
				"used_the_product":
					assert_int(value).override_failure_message(where).is_equal(a * b)
				"factor_not_multiple":
					assert_int(value).override_failure_message(where).is_equal(common)
				"off_by_b":
					assert_bool([first - a, first - b, first + a, first + b].has(value)).override_failure_message(where).is_true()
				_:
					fail("unexpected misconception in " + where)
		if a * b != first:
			assert_array(_by_name(problem, "used_the_product")).has_size(1)
		else:
			assert_array(_by_name(problem, "used_the_product")).is_empty() # coprime: the product is right


func test_the_hint_line_hops_by_a_with_a_marker_on_every_multiple_of_b() -> void:
	for problem: Problem in _problems(&"mul.common.first", {}, 300):
		var a: int = problem.prompt_params["a"]
		var b: int = problem.prompt_params["b"]
		var model: Dictionary = problem.hint_steps[1]["visual"]
		assert_int(model["max"]).is_equal(problem.answer)
		assert_int(model["labeled_every"]).is_equal(a)
		assert_array(model["markers"]).is_equal(_count_up(b, int(problem.answer / float(b))))


func test_easier_problems_use_smaller_numbers() -> void:
	for problem: Problem in _problems(&"mul.common.first", {"difficulty": -2}, 600):
		assert_int(problem.prompt_params["a"]).is_less_equal(5)
		assert_int(problem.prompt_params["b"]).is_less_equal(5)
	for problem: Problem in _problems(&"mul.list.first_k", {"difficulty": -2}, 600):
		assert_int(problem.prompt_params["k"]).is_equal(3)
		assert_int(problem.prompt_params["b"]).is_less_equal(5)


func test_the_easiest_problems_still_pass_the_shared_checks() -> void:
	for skill_id: StringName in SKILLS:
		var errors: Array[String] = GeneratorChecks.run(_catalog.skill(skill_id), 500, _allowed, {"difficulty": -8})
		assert_array(errors).override_failure_message("\n".join(errors)).is_equal([])


func test_the_same_seed_gives_the_same_problem_and_the_global_rng_is_untouched() -> void:
	for skill_id: StringName in SKILLS:
		var skill: Skill = _catalog.skill(skill_id)
		for seed: int in range(1, 100):
			assert_dict(GeneratorRegistry.make_problem(skill, seed).to_json()).is_equal(GeneratorRegistry.make_problem(skill, seed).to_json())
	seed(777)
	var expected: int = randi()
	seed(777)
	_problems(&"mul.list.first_k", {}, 200)
	_problems(&"mul.common.first", {}, 200)
	assert_int(randi()).is_equal(expected)
