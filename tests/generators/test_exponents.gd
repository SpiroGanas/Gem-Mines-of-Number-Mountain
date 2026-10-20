# Mirrors scripts/generators/exponents.gd and roots.gd (Zone 8 exp.* and root.square.perfect): every
# value is recomputed by multiplying one step at a time, the named mistakes are checked by name, and
# the edge cases the plan names are pinned (2⁴ = 4² drops swapped_base_exp; b⁰ is 1, never 0).
class_name ExponentGeneratorTest
extends GdUnitTestSuite

const N: int = 2000
const SKILLS: Array[StringName] = [
	&"exp.repeated_mult.read", &"exp.evaluate.small", &"exp.square.numbers", &"exp.cube.numbers",
	&"root.square.perfect", &"exp.powers_of_two.list", &"exp.powers_of_ten.list", &"exp.zero_one.rules",
]

var _catalog: SkillCatalog
var _allowed: Array[StringName]


func before() -> void:
	_catalog = SkillCatalog.load_all()
	_allowed = SkillCatalog.misconception_names()


func _problems(skill_id: StringName, count: int = N, overrides: Dictionary = {}) -> Array[Problem]:
	return GeneratorChecks.make_all(_catalog.skill(skill_id), count, overrides)


func _values(problem: Problem, name: StringName) -> Array:
	var found: Array = []
	for entry: Dictionary in problem.distractors:
		if entry["misconception"] == name:
			found.append(entry["value"])
	return found


## b multiplied by itself e times, one step at a time (independent of Notation.power).
func _power(base: int, exp: int) -> int:
	var value: int = 1
	var step: int = 0
	while step < exp:
		value = value * base
		step += 1
	return value


func test_every_skill_passes_the_shared_checks() -> void:
	for skill_id: StringName in SKILLS:
		assert_array(GeneratorChecks.run(_catalog.skill(skill_id), N, _allowed)).override_failure_message(str(skill_id)).is_empty()
		assert_array(GeneratorChecks.run(_catalog.skill(skill_id), 300, _allowed, {"difficulty": -1})).override_failure_message(str(skill_id) + " easier").is_empty()


func test_the_same_seed_gives_the_same_problem() -> void:
	for skill_id: StringName in SKILLS:
		var skill: Skill = _catalog.skill(skill_id)
		for seed_value: int in [1, 77, 4096]:
			var first: Problem = GeneratorRegistry.make_problem(skill, seed_value)
			var second: Problem = GeneratorRegistry.make_problem(skill, seed_value)
			assert_str(JSON.stringify(first.to_json())).is_equal(JSON.stringify(second.to_json()))


func test_a_power_means_copies_of_the_base_multiplied() -> void:
	for problem: Problem in _problems(&"exp.repeated_mult.read"):
		var b: int = problem.prompt_params["b"]
		var e: int = problem.prompt_params["e"]
		assert_bool(b >= 2 and b <= 5 and e >= 2 and e <= 4).is_true()
		assert_str(str(problem.answer["op"])).is_equal("mul")
		assert_int(problem.answer["terms"].size()).is_equal(e)
		for term: Variant in problem.answer["terms"]:
			assert_int(int(term)).is_equal(b)
		assert_int(Notation.expression_value(problem.answer)).is_equal(_power(b, e))
		var added: Array = _values(problem, &"added_base_exp_times")
		assert_str(str(added[0]["op"])).is_equal("add")
		assert_int(Notation.expression_value(added[0])).is_equal(b * e)
		assert_bool(problem.distractors.size() >= 2).is_true()
		match problem.representation:
			&"concrete":
				assert_dict(problem.visual).is_equal({"type": "power_tower", "base": b, "exp": e, "values": false})
			&"abstract":
				assert_str(str(problem.visual["form"])).is_equal("power")


func test_evaluate_stays_under_the_limit_and_names_its_mistakes() -> void:
	for problem: Problem in _problems(&"exp.evaluate.small"):
		var b: int = problem.prompt_params["b"]
		var e: int = problem.prompt_params["e"]
		assert_int(problem.answer).is_equal(_power(b, e))
		assert_bool(problem.answer <= 1000 and b <= 6 and e <= 4).is_true()
		var swapped: Array = _values(problem, &"swapped_base_exp")
		if _power(e, b) == _power(b, e):
			assert_array(swapped).is_empty() # 2⁴ = 4²: swapping is not a mistake there
		else:
			assert_array(swapped).contains_exactly([_power(e, b)])
		for wrong: Variant in _values(problem, &"off_by_one_exponent"):
			assert_bool(wrong == _power(b, e + 1) or wrong == _power(b, e - 1)).is_true()


func test_two_to_the_fourth_never_offers_four_squared_as_a_wrong_answer() -> void:
	var seen: int = 0
	for problem: Problem in _problems(&"exp.evaluate.small", 4000):
		if problem.prompt_params["b"] == 2 and problem.prompt_params["e"] == 4:
			seen += 1
			assert_array(_values(problem, &"swapped_base_exp")).is_empty()
	assert_int(seen).is_greater(0)


func test_squares_cubes_and_roots() -> void:
	for problem: Problem in _problems(&"exp.square.numbers"):
		var n: int = problem.prompt_params["n"]
		assert_int(problem.answer).is_equal(n * n)
		if problem.representation == &"concrete":
			assert_bool(n <= 10).is_true() # drawn as gems
			assert_int(problem.visual["rows"]).is_equal(n)
		if n > 2:
			assert_array(_values(problem, &"doubled")).contains_exactly([2 * n])
	for problem: Problem in _problems(&"exp.cube.numbers"):
		var n: int = problem.prompt_params["n"]
		assert_int(problem.answer).is_equal(n * n * n)
		assert_bool(n >= 2 and n <= 8).is_true() # 8³ = 512 blocks at most
		assert_bool(_values(problem, &"squared_only").has(n * n) or n * n == 3 * n).is_true()
	for problem: Problem in _problems(&"root.square.perfect"):
		var n: int = problem.prompt_params["n"]
		var root: int = problem.answer
		assert_int(root * root).is_equal(n)
		for wrong: Variant in _values(problem, &"off_by_one_root"):
			assert_int(absi(int(wrong) - root)).is_equal(1)
		for wrong: Variant in _values(problem, &"halved"):
			assert_int(int(wrong) * 2).is_equal(n)


func test_powers_of_two_on_the_elevator_ask_for_the_floor() -> void:
	var rides: int = 0
	for problem: Problem in _problems(&"exp.powers_of_two.list"):
		if problem.representation == &"concrete":
			rides += 1
			var floor_number: int = problem.answer
			assert_int(_power(2, floor_number)).is_equal(problem.prompt_params["n"])
			assert_bool(floor_number >= 1 and floor_number <= problem.meta["tower"]["floors"]).is_true()
			assert_int(problem.meta["tower"]["floors"]).is_less_equal(10)
		else:
			assert_int(problem.answer).is_equal(_power(2, problem.prompt_params["e"]))
			assert_int(problem.meta["pad_digits"]).is_equal(4) # 2¹⁰ = 1024
			for wrong: Variant in _values(problem, &"added_two"):
				assert_int(wrong).is_equal(_power(2, problem.prompt_params["e"] - 1) + 2)
	assert_int(rides).is_greater(N / 3)


func test_powers_of_ten_count_their_zeros() -> void:
	for problem: Problem in _problems(&"exp.powers_of_ten.list"):
		var e: int = problem.prompt_params["e"]
		assert_int(problem.prompt_params["b"]).is_equal(10)
		assert_str(str(problem.answer)).is_equal("1" + "0".repeat(e))
		assert_array(_values(problem, &"counted_digits_not_zeros")).contains_exactly([_power(10, e - 1)])
		assert_int(problem.meta["pad_digits"]).is_equal(7)


func test_zero_and_one_as_exponents() -> void:
	var zeros: int = 0
	for problem: Problem in _problems(&"exp.zero_one.rules"):
		var b: int = problem.prompt_params["b"]
		var e: int = problem.prompt_params["e"]
		assert_bool(e == 0 or e == 1).is_true()
		if e == 0:
			zeros += 1
			assert_int(problem.answer).is_equal(1)
			assert_array(_values(problem, &"zero_power_is_zero")).contains_exactly([0])
		else:
			assert_int(problem.answer).is_equal(b)
			assert_array(_values(problem, &"first_power_is_one")).contains_exactly([1])
		assert_array(_values(problem, &"added_base_and_exp")).contains_exactly([b + e])
	assert_int(zeros).is_between(N / 3, 2 * N / 3)


func test_easier_problems_are_smaller() -> void:
	for problem: Problem in _problems(&"exp.square.numbers", 500, {"difficulty": -1}):
		assert_int(problem.prompt_params["n"]).is_less_equal(11)
	for problem: Problem in _problems(&"exp.powers_of_two.list", 500, {"difficulty": -1}):
		var e: int = problem.answer if problem.representation == &"concrete" else problem.prompt_params["e"]
		assert_int(e).is_less_equal(7)
