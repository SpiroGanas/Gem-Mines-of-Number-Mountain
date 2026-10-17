# Mirrors scripts/generators/subtraction.gd: the math of each kind of difference, restated
# independently (digits are read from the decimal string here, never with the generator's helpers).
class_name SubtractionGeneratorTest
extends GdUnitTestSuite

const N: int = 2000
const SKILLS: Array[StringName] = [
	&"sub.to_10.diff", &"sub.to_20.diff", &"sub.to_100.tens", &"sub.to_100.no_regroup", &"sub.to_100.regroup",
]

var _catalog: SkillCatalog
var _allowed: Array[StringName]


func before() -> void:
	_catalog = SkillCatalog.load_all()
	_allowed = SkillCatalog.misconception_names()


func _problems(skill_id: StringName, overrides: Dictionary = {}, count: int = N) -> Array[Problem]:
	return GeneratorChecks.make_all(_catalog.skill(skill_id), count, overrides)


## {misconception name: [values]} in the order given.
func _by_name(problem: Problem) -> Dictionary:
	var result: Dictionary = {}
	for entry: Dictionary in problem.distractors:
		var name: String = String(entry["misconception"])
		if not result.has(name):
			result[name] = []
		result[name].append(entry["value"])
	return result


func _sorted(values: Array) -> Array:
	var copy: Array = values.duplicate()
	copy.sort()
	return copy


func _total(pile: Dictionary) -> int:
	return pile["hundreds"] * 100 + pile["tens"] * 10 + pile["ones"]


## The two digits of a number below 100, read from its text ("07" for 7).
func _digits(n: int) -> Array[int]:
	var text: String = str(n).pad_zeros(2)
	return [int(text[0]), int(text[1])]


func _model(problem: Problem) -> Dictionary:
	return problem.hint_steps[1]["visual"]


## Follows a number line's jumps from `start` and returns where they end (-1 if they do not chain).
func _follow(jumps: Array, start: int) -> int:
	var at: int = start
	for jump: Dictionary in jumps:
		if jump["from"] != at:
			return -1
		at = jump["to"]
	return at


# --- Each kind of difference -------------------------------------------------------------------


func test_subtracting_within_10_covers_every_fact() -> void:
	var seen: Dictionary = {}
	for problem: Problem in _problems(&"sub.to_10.diff"):
		var a: int = problem.prompt_params["a"]
		var b: int = problem.prompt_params["b"]
		var diff: int = a - b
		seen["%d-%d" % [a, b]] = true
		assert_str(problem.prompt_line_id).is_equal("z2.sub.prompt_diff")
		assert_int(a).is_between(2, 10)
		assert_int(b).is_between(1, mini(a, 9))
		assert_int(problem.answer).is_equal(diff)
		assert_array(problem.visual["piles"]).is_equal([{"hundreds": 0, "tens": 0, "ones": a}])
		var line: Dictionary = _model(problem)
		assert_array(Problem.canonical(line["jumps"])).is_equal([{"from": a, "to": diff}]) # one jump back
		assert_array(line["markers"]).is_equal([a])
		assert_int(line["min"]).is_equal(0)
		assert_int(line["max"]).is_equal(10)
		var wrong: Dictionary = _by_name(problem)
		assert_array(wrong["added_instead"]).is_equal([a + b])
		assert_array(_sorted(wrong["off_by_one"])).is_equal([diff - 1, diff + 1] if diff >= 1 else [diff + 1])
	assert_int(seen.size()).is_equal(53) # a from 2 to 9 with b up to a, and 10 with b up to 9


func test_subtracting_within_20_starts_from_a_teen_number() -> void:
	var through_ten: int = 0
	var straight: int = 0
	for problem: Problem in _problems(&"sub.to_20.diff"):
		var a: int = problem.prompt_params["a"]
		var b: int = problem.prompt_params["b"]
		var diff: int = a - b
		assert_str(problem.prompt_line_id).is_equal("z2.sub.prompt_diff")
		assert_int(a).is_between(11, 20)
		assert_int(b).is_between(1, 9)
		assert_int(problem.answer).is_equal(diff)
		assert_dict(problem.visual).is_equal({"type": "ten_frame", "count": a, "frames": 2})
		var jumps: Array = Problem.canonical(_model(problem)["jumps"])
		if diff < 10:
			through_ten += 1
			assert_array(jumps).is_equal([{"from": a, "to": 10}, {"from": 10, "to": diff}]) # back to ten, then on
		else:
			straight += 1
			assert_array(jumps).is_equal([{"from": a, "to": diff}])
		var wrong: Dictionary = _by_name(problem)
		assert_array(wrong["added_instead"]).is_equal([a + b])
		assert_array(_sorted(wrong["off_by_one"])).is_equal([diff - 1, diff + 1])
	assert_int(through_ten).is_greater(floori(N / 5.0))
	assert_int(straight).is_greater(floori(N / 5.0))


func test_subtracting_tens() -> void:
	for problem: Problem in _problems(&"sub.to_100.tens"):
		var a: int = problem.prompt_params["a"]
		var b: int = problem.prompt_params["b"]
		var diff: int = a - b
		var tens_a: int = floori(a / 10.0)
		var tens_b: int = floori(b / 10.0)
		assert_str(problem.prompt_line_id).is_equal("z2.sub.prompt_tens")
		assert_int(a % 10).is_equal(0)
		assert_int(b % 10).is_equal(0)
		assert_int(b).is_greater_equal(10)
		assert_int(b).is_less(a)
		assert_int(a).is_less_equal(100)
		assert_int(problem.answer).is_equal(diff)
		assert_array(problem.visual["piles"]).is_equal([{"hundreds": 0, "tens": tens_a, "ones": 0}])
		var wrong: Dictionary = _by_name(problem)
		# 70 - 30 as 7 - 3, and as 70 - 3.
		assert_array(_sorted(wrong["subtracted_as_ones"])).is_equal(_sorted([tens_a - tens_b, a - tens_b]))
		var jumps: Array = _model(problem)["jumps"]
		assert_int(jumps.size()).is_equal(tens_b)
		assert_int(_follow(jumps, a)).is_equal(diff)
		for jump: Dictionary in jumps:
			assert_int(jump["from"] - jump["to"]).is_equal(10)


func test_two_digit_differences_without_regrouping() -> void:
	var one_digit: int = 0
	var representations: Dictionary = {}
	for problem: Problem in _problems(&"sub.to_100.no_regroup"):
		var a: int = problem.prompt_params["a"]
		var b: int = problem.prompt_params["b"]
		var diff: int = a - b
		var da: Array[int] = _digits(a)
		var db: Array[int] = _digits(b)
		representations[problem.representation] = true
		if b < 10:
			one_digit += 1
		assert_str(problem.prompt_line_id).is_equal("z2.sub.prompt_diff")
		assert_int(a).is_between(10, 99)
		assert_int(b).is_between(1, a - 1)
		assert_int(da[1]).is_greater_equal(db[1]) # enough ones: no trade needed
		assert_int(problem.answer).is_equal(diff)
		# Without regrouping, the smaller digit from the larger in each place IS the answer ...
		assert_int(absi(da[0] - db[0]) * 10 + absi(da[1] - db[1])).is_equal(diff)
		var wrong: Dictionary = _by_name(problem)
		# ... so it is never offered as a wrong answer.
		assert_bool(wrong.has("smaller_from_larger")).is_false()
		assert_array(wrong["added_instead"]).is_equal([a + b])
		var swap_is_new: bool = diff >= 10 and diff % 10 != 0 and _digits(diff)[0] != _digits(diff)[1]
		if swap_is_new:
			assert_array(wrong["digit_swap"]).is_equal([int(str(diff).reverse())])
		else:
			assert_bool(wrong.has("digit_swap")).is_false()
		if problem.representation == &"concrete":
			assert_int(_total(problem.visual["piles"][0])).is_equal(a)
			var line: Dictionary = _model(problem)
			assert_int(_follow(line["jumps"], a)).is_equal(diff) # tens, then ones
			assert_int(line["min"]).is_less_equal(diff)
			assert_int(line["max"]).is_greater_equal(a)
		else:
			assert_dict(problem.visual).is_empty()
			assert_int(_total(_model(problem)["piles"][0])).is_equal(a)
	assert_int(representations.size()).is_equal(2)
	assert_int(one_digit).is_between(floori(N / 6.0), floori(N / 2.0))


func test_two_digit_differences_with_regrouping() -> void:
	var representations: Dictionary = {}
	var single: int = 0
	for problem: Problem in _problems(&"sub.to_100.regroup"):
		var a: int = problem.prompt_params["a"]
		var b: int = problem.prompt_params["b"]
		var diff: int = a - b
		var da: Array[int] = _digits(a)
		var db: Array[int] = _digits(b)
		representations[problem.representation] = true
		assert_str(problem.prompt_line_id).is_equal("z2.sub.prompt_diff")
		assert_int(a).is_between(10, 99)
		assert_int(b).is_between(1, a - 1)
		assert_int(da[1]).is_less(db[1]) # not enough ones: trade a ten
		assert_int(problem.answer).is_equal(diff)
		var smaller_from_larger: int = absi(da[0] - db[0]) * 10 + absi(da[1] - db[1])
		var wrong: Dictionary = _by_name(problem)
		for value: int in wrong.get("smaller_from_larger", []):
			assert_int(value).is_equal(smaller_from_larger)
		for value: int in wrong.get("forgot_untrade", []):
			assert_int(value).is_equal(diff + 10)
		# Both mistakes are offered, unless they give the same number (ones digits 5 apart).
		var values: Array = _sorted(problem.distractor_values())
		if smaller_from_larger == diff + 10:
			single += 1
			assert_int(db[1] - da[1]).is_equal(5)
			assert_array(values).is_equal([diff + 10])
		else:
			assert_array(values).is_equal(_sorted([smaller_from_larger, diff + 10]))
		if problem.representation == &"concrete":
			assert_int(_total(problem.visual["piles"][0])).is_equal(a)
			# The hint shows a after trading one ten for ten ones.
			assert_dict(_model(problem)["piles"][0]).is_equal({"hundreds": 0, "tens": da[0] - 1, "ones": da[1] + 10})
		else:
			assert_dict(problem.visual).is_empty()
	assert_int(representations.size()).is_equal(2)
	assert_int(single).is_greater(0)


# --- Rules for every subtraction skill -------------------------------------------------------


func test_worked_examples_are_solved_and_stated_correctly() -> void:
	for skill_id: StringName in SKILLS:
		for problem: Problem in _problems(skill_id, {}, 300):
			var example: Dictionary = problem.hint_steps[2]["example"]
			var p: Dictionary = example["prompt_params"]
			assert_int(example["answer"]).is_equal(p["a"] - p["b"])
			assert_str(example["prompt_line_id"]).is_equal(problem.prompt_line_id)
			assert_str(example["answer_line_id"]).is_equal("z2.hint.example_sub")
			assert_dict(example["answer_params"]).is_equal({"a": p["a"], "b": p["b"], "diff": p["a"] - p["b"]})


func test_easier_problems_use_smaller_numbers() -> void:
	for skill_id: StringName in SKILLS:
		var normal: int = 0
		var easier: int = 0
		for problem: Problem in _problems(skill_id, {}, 1000):
			normal = maxi(normal, problem.prompt_params["a"])
		for problem: Problem in _problems(skill_id, {"difficulty": -1}, 1000):
			easier = maxi(easier, problem.prompt_params["a"])
		assert_int(easier).override_failure_message("%s: easier max %d, normal max %d" % [skill_id, easier, normal]).is_less(normal)


func test_easier_problems_keep_the_skill() -> void:
	for problem: Problem in _problems(&"sub.to_20.diff", {"difficulty": -2}, 500):
		assert_int(problem.prompt_params["a"]).is_between(11, 13) # still a teen number
	for problem: Problem in _problems(&"sub.to_100.regroup", {"difficulty": -2}, 500):
		assert_int(_digits(problem.prompt_params["a"])[1]).is_less(_digits(problem.prompt_params["b"])[1]) # still regroups
		assert_int(problem.prompt_params["a"]).is_less_equal(49)


func test_much_easier_problems_still_pass_every_check() -> void:
	for skill_id: StringName in SKILLS:
		var errors: Array[String] = GeneratorChecks.run(_catalog.skill(skill_id), 500, _allowed, {"difficulty": -4})
		assert_array(errors).override_failure_message("\n".join(errors)).is_empty()


func test_every_usable_misconception_turns_up() -> void:
	for skill_id: StringName in SKILLS:
		var seen: Dictionary = {}
		for problem: Problem in _problems(skill_id):
			for entry: Dictionary in problem.distractors:
				seen[entry["misconception"]] = true
		for name: StringName in _catalog.skill(skill_id).misconceptions:
			if skill_id == &"sub.to_100.no_regroup" and name == &"smaller_from_larger":
				continue # equals the answer without regrouping (see the test above)
			assert_bool(seen.has(name)).override_failure_message("%s never offers %s" % [skill_id, name]).is_true()


func test_no_difference_is_negative() -> void:
	for skill_id: StringName in SKILLS:
		for problem: Problem in _problems(skill_id, {}, 1000):
			assert_int(problem.answer).is_greater_equal(0)
			for value: int in problem.distractor_values():
				assert_int(value).is_greater_equal(0)


func test_the_same_seed_gives_the_same_problem_whatever_the_global_rng() -> void:
	for skill_id: StringName in SKILLS:
		var skill: Skill = _catalog.skill(skill_id)
		for problem_seed: int in range(1, 41):
			seed(problem_seed * 7)
			var first: Dictionary = GeneratorRegistry.make_problem(skill, problem_seed).to_json()
			seed(problem_seed * 13 + 1)
			randi()
			var second: Dictionary = GeneratorRegistry.make_problem(skill, problem_seed).to_json()
			assert_dict(first).is_equal(second)


func test_different_seeds_give_different_problems() -> void:
	for skill_id: StringName in SKILLS:
		var seen: Dictionary = {}
		for problem: Problem in _problems(skill_id, {}, 200):
			seen[str(problem.prompt_params)] = true
		assert_int(seen.size()).override_failure_message(String(skill_id)).is_greater(10)


func test_every_subtraction_skill_is_covered_here() -> void:
	for id: StringName in _catalog.ids():
		if _catalog.skill(id).generator == &"SubtractionGenerator":
			assert_bool(SKILLS.has(id)).override_failure_message("no tests for " + id).is_true()


# --- 10,000 seeded problems per skill (Phase 1 plan) -----------------------------------------


func _check(skill_id: StringName) -> void:
	var skill: Skill = _catalog.skill(skill_id)
	assert_object(skill).is_not_null()
	var errors: Array[String] = GeneratorChecks.run(skill, GeneratorChecks.ZONE1_SEEDS, _allowed)
	assert_array(errors).override_failure_message("\n".join(errors)).is_empty()


func test_sub_to_10_diff_10000() -> void:
	_check(&"sub.to_10.diff")


func test_sub_to_20_diff_10000() -> void:
	_check(&"sub.to_20.diff")


func test_sub_to_100_tens_10000() -> void:
	_check(&"sub.to_100.tens")


func test_sub_to_100_no_regroup_10000() -> void:
	_check(&"sub.to_100.no_regroup")


func test_sub_to_100_regroup_10000() -> void:
	_check(&"sub.to_100.regroup")
