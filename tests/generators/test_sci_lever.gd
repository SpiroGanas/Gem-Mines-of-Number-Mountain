# Mirrors scripts/generators/sci_notation.gd and lever.gd (Zone 8 sci.notation.* and
# lever.counterweight.balance): scientific notation is re-read by moving the point one place at a time,
# never through a float, and a lever balances when weight × distance matches on both sides.
class_name SciLeverGeneratorTest
extends GdUnitTestSuite

const N: int = 2000
const SKILLS: Array[StringName] = [&"sci.notation.read", &"sci.notation.write", &"lever.counterweight.balance"]

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


## The digits of m (tenths) with the point moved e places right: "3.4" and 5 give 340000.
func _shifted(mantissa: int, exp: int) -> int:
	var text: String = str(mantissa) # two digits: the ones and the tenths
	var moved: int = exp - 1 # the tenths digit takes the first move
	return int(text + "0".repeat(moved))


func test_every_skill_passes_the_shared_checks() -> void:
	for skill_id: StringName in SKILLS:
		assert_array(GeneratorChecks.run(_catalog.skill(skill_id), N, _allowed)).override_failure_message(str(skill_id)).is_empty()
		assert_array(GeneratorChecks.run(_catalog.skill(skill_id), 300, _allowed, {"difficulty": -1})).override_failure_message(str(skill_id) + " easier").is_empty()


func test_the_same_seed_gives_the_same_problem() -> void:
	for skill_id: StringName in SKILLS:
		var skill: Skill = _catalog.skill(skill_id)
		assert_str(JSON.stringify(GeneratorRegistry.make_problem(skill, 5).to_json())).is_equal(JSON.stringify(GeneratorRegistry.make_problem(skill, 5).to_json()))


func test_reading_moves_the_point() -> void:
	for problem: Problem in _problems(&"sci.notation.read"):
		var card: Dictionary = problem.visual
		var mantissa: int = card["mantissa"]
		var exp: int = card["exp"]
		assert_int(card["scale"]).is_equal(1)
		assert_bool(mantissa >= 11 and mantissa <= 99 and mantissa % 10 != 0).is_true()
		assert_bool(exp >= 2 and exp <= 6).is_true()
		assert_int(problem.answer).is_equal(_shifted(mantissa, exp))
		assert_array(_values(problem, &"counted_digits_not_shift")).contains_exactly([int(str(mantissa) + "0".repeat(exp))])
		assert_array(_values(problem, &"off_by_one_exponent")).contains_exactly([_shifted(mantissa, exp - 1)])


func test_writing_normalizes_and_keeps_the_unnormalized_form_wrong() -> void:
	for problem: Problem in _problems(&"sci.notation.write"):
		var answer: Dictionary = problem.answer
		assert_bool(Notation.is_normalized_sci(answer)).is_true()
		assert_int(_shifted(answer["mantissa"], answer["exp"])).is_equal(problem.prompt_params["n"])
		assert_bool(problem.prompt_params["n"] <= 9000000).is_true()
		var unnormalized: Dictionary = _values(problem, &"mantissa_not_normalized")[0]
		assert_int(unnormalized["mantissa"]).is_equal(answer["mantissa"])
		assert_int(unnormalized["scale"]).is_equal(0)
		# Equal in value, but a different (wrong) form.
		assert_int(Notation.sci_value(unnormalized)).is_equal(problem.prompt_params["n"])
		assert_bool(problem.is_correct(unnormalized)).is_false()
	var plan: Problem = Problem.new()
	plan.answer = Notation.sci(34, 1, 5)
	assert_bool(plan.is_correct({"mantissa": 34, "scale": 1, "exp": 5})).is_true()
	assert_bool(plan.is_correct({"mantissa": 34, "scale": 0, "exp": 4})).is_false()
	assert_int(Notation.sci_value(plan.answer)).is_equal(340000)


func test_levers_balance_weight_times_distance() -> void:
	var concrete: int = 0
	for problem: Problem in _problems(&"lever.counterweight.balance"):
		var w: int = problem.prompt_params["w"]
		var d: int = problem.prompt_params["d"]
		var r: int = problem.prompt_params["r"]
		assert_int(w * d).is_equal(problem.answer * r)
		assert_bool(d != r and [1, 2, 4, 8].has(d) and [1, 2, 4, 8].has(r)).is_true()
		assert_bool(w <= 32 and problem.answer <= 32 and w >= 1 and problem.answer >= 1).is_true()
		assert_bool(w * d < 256).is_true()
		assert_array(_values(problem, &"matched_weight_only")).contains_exactly([w])
		if problem.representation == &"concrete":
			concrete += 1
			assert_int(problem.meta["lever"]["left_w"]).is_equal(w)
			assert_int(problem.meta["lever"]["right_d"]).is_equal(r)
		else:
			assert_str(str(problem.visual["type"])).is_equal("lever")
	assert_int(concrete).is_greater(N / 3)
