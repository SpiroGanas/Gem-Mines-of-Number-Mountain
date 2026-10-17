# Mirrors scripts/generators/addition.gd: the math of each kind of sum, restated independently
# (digits are read from the decimal string here, never with the generator's helpers).
class_name AdditionGeneratorTest
extends GdUnitTestSuite

const N: int = 2000
const SKILLS: Array[StringName] = [
	&"add.to_10.sums", &"add.to_20.sums", &"add.to_20.doubles", &"add.to_100.tens",
	&"add.to_100.no_regroup", &"add.to_100.regroup", &"add.three_addends.to_20",
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


func _swapped(n: int) -> int:
	return int(str(n).reverse())


func _model(problem: Problem) -> Dictionary:
	return problem.hint_steps[1]["visual"]


func _example(problem: Problem) -> Dictionary:
	return problem.hint_steps[2]["example"]


# --- Each kind of sum --------------------------------------------------------------------------


func test_sums_within_10_cover_every_fact() -> void:
	var seen: Dictionary = {}
	for problem: Problem in _problems(&"add.to_10.sums"):
		var a: int = problem.prompt_params["a"]
		var b: int = problem.prompt_params["b"]
		assert_str(problem.prompt_line_id).is_equal("z2.add.prompt_sum")
		assert_int(a).is_greater_equal(1)
		assert_int(b).is_greater_equal(1)
		assert_int(a + b).is_less_equal(10)
		assert_int(problem.answer).is_equal(a + b)
		var piles: Array = problem.visual["piles"]
		assert_int(piles.size()).is_equal(2)
		assert_dict(piles[0]).is_equal({"hundreds": 0, "tens": 0, "ones": a})
		assert_dict(piles[1]).is_equal({"hundreds": 0, "tens": 0, "ones": b})
		assert_dict(_model(problem)).is_equal({"type": "ten_frame", "count": a, "second": b, "frames": 1})
		var wrong: Dictionary = _by_name(problem)
		assert_array(wrong["counted_from_one"]).is_equal([a + b - 1])
		assert_array(wrong["off_by_one"]).is_equal([a + b + 1])
		seen["%d+%d" % [a, b]] = true
	assert_int(seen.size()).is_equal(45) # every a + b with a, b >= 1 and a sum up to 10


func test_make_ten_sums_always_cross_ten() -> void:
	var sums: Dictionary = {}
	for problem: Problem in _problems(&"add.to_20.sums"):
		var a: int = problem.prompt_params["a"]
		var b: int = problem.prompt_params["b"]
		var sum: int = a + b
		sums[sum] = true
		assert_str(problem.prompt_line_id).is_equal("z2.add.prompt_make_ten")
		assert_int(a).is_between(6, 9)
		assert_int(b).is_between(1, 9)
		assert_int(sum).is_between(11, 20)
		assert_int(problem.answer).is_equal(sum)
		assert_dict(problem.visual).is_equal({"type": "ten_frame", "count": a, "second": b, "frames": 2})
		var line: Dictionary = _model(problem)
		assert_str(line["type"]).is_equal("number_line")
		assert_array(Problem.canonical(line["jumps"])).is_equal([{"from": a, "to": 10}, {"from": 10, "to": sum}])
		assert_int(line["min"]).is_less_equal(a)
		assert_int(line["max"]).is_greater_equal(sum)
		var wrong: Dictionary = _by_name(problem)
		assert_array(wrong["forgot_regroup"]).is_equal([sum - 10]) # only the ones left over
		assert_array(_sorted(wrong["off_by_one"])).is_equal([sum - 1, sum + 1])
		# The worked example walks through making the ten.
		var example: Dictionary = _example(problem)
		var steps: Dictionary = example["answer_params"]
		assert_str(example["answer_line_id"]).is_equal("z2.hint.example_make_ten")
		assert_int(steps["ten"]).is_equal(10)
		assert_int(steps["a"] + steps["fill"]).is_equal(10)
		assert_int(steps["ten"] + steps["rest"]).is_equal(steps["sum"])
		assert_int(steps["fill"] + steps["rest"]).is_equal(example["prompt_params"]["b"])
		assert_int(steps["sum"]).is_equal(example["answer"])
	assert_int(sums.size()).is_equal(8) # 11 to 18: both addends are single digits


func test_doubles_and_near_doubles() -> void:
	var doubles: int = 0
	var near: int = 0
	var seen: Dictionary = {}
	for problem: Problem in _problems(&"add.to_20.doubles"):
		var a: int = problem.prompt_params["a"]
		var b: int = problem.prompt_params["b"]
		var sum: int = a + b
		seen["%d+%d" % [a, b]] = true
		assert_int(absi(a - b)).is_less_equal(1)
		assert_int(mini(a, b)).is_greater_equal(1)
		assert_int(sum).is_less_equal(20)
		assert_int(problem.answer).is_equal(sum)
		if a == b:
			doubles += 1
		else:
			near += 1
		assert_int(_total(problem.visual["piles"][0])).is_equal(a)
		assert_int(_total(problem.visual["piles"][1])).is_equal(b)
		assert_dict(_model(problem)).is_equal({"type": "pairs", "count": sum, "show_pairs": true})
		var wrong: Dictionary = _by_name(problem)
		assert_array(_sorted(wrong["off_by_one"])).is_equal([sum - 1, sum + 1])
		assert_int(wrong["off_by_two"].size()).is_equal(1)
		assert_int(absi(wrong["off_by_two"][0] - sum)).is_equal(2)
		assert_int(wrong["off_by_two"][0]).is_greater_equal(1)
	assert_int(doubles).is_greater(floori(N * 0.4))
	assert_int(near).is_greater(floori(N * 0.4))
	assert_bool(seen.has("10+10")).is_true()
	assert_bool(seen.has("9+10") or seen.has("10+9")).is_true()
	assert_bool(seen.has("1+1")).is_true()


func test_adding_tens() -> void:
	var biggest: int = 0
	for problem: Problem in _problems(&"add.to_100.tens"):
		var a: int = problem.prompt_params["a"]
		var b: int = problem.prompt_params["b"]
		var sum: int = a + b
		biggest = maxi(biggest, sum)
		assert_str(problem.prompt_line_id).is_equal("z2.add.prompt_tens")
		assert_int(a % 10).is_equal(0)
		assert_int(b % 10).is_equal(0)
		assert_int(mini(a, b)).is_greater_equal(10)
		assert_int(sum).is_less_equal(100)
		assert_int(problem.answer).is_equal(sum)
		assert_dict(problem.visual["piles"][0]).is_equal({"hundreds": 0, "tens": floori(a / 10.0), "ones": 0})
		assert_dict(problem.visual["piles"][1]).is_equal({"hundreds": 0, "tens": floori(b / 10.0), "ones": 0})
		var wrong: Dictionary = _by_name(problem)
		assert_array(wrong["added_as_ones"]).is_equal([floori(sum / 10.0)]) # 30 + 40 as 3 + 4
		assert_array(_sorted(wrong["decade_skip"])).is_equal([sum - 10, sum + 10])
		var jumps: Array = _model(problem)["jumps"]
		assert_int(jumps.size()).is_equal(floori(b / 10.0))
		assert_int(jumps[0]["from"]).is_equal(a)
		assert_int(jumps[jumps.size() - 1]["to"]).is_equal(sum)
		for jump: Dictionary in jumps:
			assert_int(jump["to"] - jump["from"]).is_equal(10)
	assert_int(biggest).is_equal(100)


func test_two_digit_sums_without_regrouping() -> void:
	var one_digit: int = 0
	var representations: Dictionary = {}
	var names: Dictionary = {}
	for problem: Problem in _problems(&"add.to_100.no_regroup"):
		var a: int = problem.prompt_params["a"]
		var b: int = problem.prompt_params["b"]
		var sum: int = a + b
		var da: Array[int] = _digits(a)
		var db: Array[int] = _digits(b)
		representations[problem.representation] = true
		if b < 10:
			one_digit += 1
		assert_str(problem.prompt_line_id).is_equal("z2.add.prompt_sum")
		assert_int(a).is_between(10, 99)
		assert_int(b).is_between(1, 99)
		assert_int(da[1] + db[1]).is_less_equal(9) # the ones never make a new ten
		assert_int(sum).is_less_equal(99) # nor do the tens make a hundred
		assert_int(problem.answer).is_equal(sum)
		if problem.representation == &"concrete":
			assert_int(_total(problem.visual["piles"][0])).is_equal(a)
			assert_int(_total(problem.visual["piles"][1])).is_equal(b)
			assert_dict(_model(problem)["piles"][0]).is_equal({"hundreds": 0, "tens": da[0] + db[0], "ones": da[1] + db[1]})
		else:
			assert_dict(problem.visual).is_empty()
			assert_int(_total(_model(problem)["piles"][0])).is_equal(a)
			assert_int(_total(_model(problem)["piles"][1])).is_equal(b)
		assert_array(problem.distractors).is_not_empty()
		var wrong: Dictionary = _by_name(problem)
		for name: String in wrong:
			names[name] = true
		for value: int in wrong.get("added_tens_to_ones", []):
			# b's ones digit went into the tens column and its tens digit into the ones column.
			assert_int(da[0] + db[1]).is_less_equal(9)
			assert_int(da[1] + db[0]).is_less_equal(9)
			assert_int(value).is_equal(int(str(da[0] + db[1]) + str(da[1] + db[0])))
			assert_int(value).is_not_equal(sum)
		for value: int in wrong.get("digit_swap", []):
			assert_int(value).is_equal(_swapped(sum))
			assert_int(sum % 10).is_not_equal(0)
			assert_int(value).is_between(10, 99)
	assert_int(representations.size()).is_equal(2)
	assert_int(one_digit).is_between(floori(N / 6.0), floori(N / 2.0)) # 34 + 5 as well as 34 + 25
	assert_bool(names.has("added_tens_to_ones") and names.has("digit_swap")).is_true()


func test_a_one_digit_addend_lined_up_under_the_tens() -> void:
	# 34 + 5 with the 5 lined up under the 3 is 84: the classic place-value slip.
	for problem: Problem in _problems(&"add.to_100.no_regroup", {}, 600):
		var a: int = problem.prompt_params["a"]
		var b: int = problem.prompt_params["b"]
		var wrong: Dictionary = _by_name(problem)
		if b < 10 and _digits(a)[0] + b <= 9:
			assert_array(wrong["added_tens_to_ones"]).is_equal([a + b * 10])


func test_two_digit_sums_with_regrouping() -> void:
	var representations: Dictionary = {}
	for problem: Problem in _problems(&"add.to_100.regroup"):
		var a: int = problem.prompt_params["a"]
		var b: int = problem.prompt_params["b"]
		var sum: int = a + b
		var da: Array[int] = _digits(a)
		var db: Array[int] = _digits(b)
		representations[problem.representation] = true
		assert_str(problem.prompt_line_id).is_equal("z2.add.prompt_sum")
		assert_int(a).is_between(10, 99)
		assert_int(b).is_between(1, 99)
		assert_int(da[1] + db[1]).is_greater_equal(10) # the ones make a new ten
		assert_int(sum).is_less_equal(100)
		assert_int(problem.answer).is_equal(sum)
		var wrong: Dictionary = _by_name(problem)
		assert_array(wrong["forgot_regroup"]).is_equal([sum - 10])
		assert_array(wrong["carried_twice"]).is_equal([sum + 10])
		if problem.representation == &"concrete":
			var together: Dictionary = _model(problem)["piles"][0]
			assert_int(together["ones"]).is_greater_equal(10) # ten ones ready to trade
			assert_int(_total(together)).is_equal(sum)
		else:
			assert_dict(problem.visual).is_empty()
	assert_int(representations.size()).is_equal(2)


func test_three_addends() -> void:
	for problem: Problem in _problems(&"add.three_addends.to_20"):
		var a: int = problem.prompt_params["a"]
		var b: int = problem.prompt_params["b"]
		var c: int = problem.prompt_params["c"]
		var sum: int = a + b + c
		assert_str(problem.prompt_line_id).is_equal("z2.add.prompt_three")
		for addend: int in [a, b, c]:
			assert_int(addend).is_between(1, 9)
		assert_int(sum).is_less_equal(20)
		assert_int(problem.answer).is_equal(sum)
		assert_int(problem.visual["piles"].size()).is_equal(3)
		assert_int(_total(problem.visual["piles"][2])).is_equal(c)
		var wrong: Dictionary = _by_name(problem)
		assert_array(wrong["dropped_addend"]).is_not_empty()
		for value: int in wrong["dropped_addend"]:
			assert_bool([a + b, b + c, a + c].has(value)).is_true()
		assert_bool(wrong["off_by_one"].has(sum + 1)).is_true()
		for value: int in wrong["off_by_one"]:
			assert_int(absi(value - sum)).is_equal(1)
		assert_array(Problem.canonical(_model(problem)["jumps"])).is_equal([{"from": a, "to": a + b}, {"from": a + b, "to": sum}])
		var example: Dictionary = _example(problem)
		var p: Dictionary = example["prompt_params"]
		assert_str(example["answer_line_id"]).is_equal("z2.hint.example_add_three")
		assert_int(example["answer"]).is_equal(p["a"] + p["b"] + p["c"])


# --- Rules for every addition skill ----------------------------------------------------------


func test_worked_examples_are_solved_and_stated_correctly() -> void:
	for skill_id: StringName in SKILLS:
		for problem: Problem in _problems(skill_id, {}, 300):
			var example: Dictionary = _example(problem)
			var p: Dictionary = example["prompt_params"]
			var expected: int = p["a"] + p["b"] + int(p.get("c", 0))
			assert_int(example["answer"]).is_equal(expected)
			assert_str(example["prompt_line_id"]).is_equal(problem.prompt_line_id)
			assert_int(example["answer_params"]["sum"]).is_equal(expected)
			if example["answer_line_id"] == &"z2.hint.example_add":
				assert_int(example["answer_params"]["a"]).is_equal(p["a"])
				assert_int(example["answer_params"]["b"]).is_equal(p["b"])


func test_easier_problems_use_smaller_numbers() -> void:
	for skill_id: StringName in SKILLS:
		var normal: int = 0
		var easier: int = 0
		for problem: Problem in _problems(skill_id, {}, 1000):
			normal = maxi(normal, problem.answer)
		for problem: Problem in _problems(skill_id, {"difficulty": -1}, 1000):
			easier = maxi(easier, problem.answer)
		assert_int(easier).override_failure_message("%s: easier max %d, normal max %d" % [skill_id, easier, normal]).is_less(normal)


func test_easier_problems_keep_the_skill() -> void:
	for problem: Problem in _problems(&"add.to_20.sums", {"difficulty": -2}, 500):
		assert_int(problem.answer).is_between(11, 13) # still crosses ten
	for problem: Problem in _problems(&"add.to_100.regroup", {"difficulty": -2}, 500):
		var ones: int = _digits(problem.prompt_params["a"])[1] + _digits(problem.prompt_params["b"])[1]
		assert_int(ones).is_greater_equal(10) # still regroups
		assert_int(problem.answer).is_less_equal(49)
	for problem: Problem in _problems(&"add.to_100.no_regroup", {"difficulty": -1}, 500):
		var ones: int = _digits(problem.prompt_params["a"])[1] + _digits(problem.prompt_params["b"])[1]
		assert_int(ones).is_less_equal(9)
		assert_int(problem.answer).is_less_equal(70)


func test_much_easier_problems_still_pass_every_check() -> void:
	for skill_id: StringName in SKILLS:
		var errors: Array[String] = GeneratorChecks.run(_catalog.skill(skill_id), 500, _allowed, {"difficulty": -4})
		assert_array(errors).override_failure_message("\n".join(errors)).is_empty()


func test_every_listed_misconception_turns_up() -> void:
	for skill_id: StringName in SKILLS:
		var seen: Dictionary = {}
		for problem: Problem in _problems(skill_id):
			for entry: Dictionary in problem.distractors:
				seen[entry["misconception"]] = true
		for name: StringName in _catalog.skill(skill_id).misconceptions:
			assert_bool(seen.has(name)).override_failure_message("%s never offers %s" % [skill_id, name]).is_true()


func test_tap_problems_offer_at_least_two_choices() -> void:
	for skill_id: StringName in SKILLS:
		for problem: Problem in _problems(skill_id, {}, 500):
			assert_int(problem.choice_options(func(value: Variant) -> String: return str(value)).size()).is_greater_equal(2)


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


func test_every_addition_skill_is_covered_here() -> void:
	for id: StringName in _catalog.ids():
		if _catalog.skill(id).generator == &"AdditionGenerator":
			assert_bool(SKILLS.has(id)).override_failure_message("no tests for " + id).is_true()


# --- 10,000 seeded problems per skill (Phase 1 plan) -----------------------------------------


func _check(skill_id: StringName) -> void:
	var skill: Skill = _catalog.skill(skill_id)
	assert_object(skill).is_not_null()
	var errors: Array[String] = GeneratorChecks.run(skill, GeneratorChecks.ZONE1_SEEDS, _allowed)
	assert_array(errors).override_failure_message("\n".join(errors)).is_empty()


func test_add_to_10_sums_10000() -> void:
	_check(&"add.to_10.sums")


func test_add_to_20_sums_10000() -> void:
	_check(&"add.to_20.sums")


func test_add_to_20_doubles_10000() -> void:
	_check(&"add.to_20.doubles")


func test_add_to_100_tens_10000() -> void:
	_check(&"add.to_100.tens")


func test_add_to_100_no_regroup_10000() -> void:
	_check(&"add.to_100.no_regroup")


func test_add_to_100_regroup_10000() -> void:
	_check(&"add.to_100.regroup")


func test_add_three_addends_to_20_10000() -> void:
	_check(&"add.three_addends.to_20")
