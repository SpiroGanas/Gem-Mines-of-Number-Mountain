# Mirrors scripts/generators/simplify.gd (P4-S29-05). Written test-first. Simplest form is checked by
# trial: no number from 2 up divides both parts, and the value is unchanged (cross-multiplying, never
# a float). Every wrong answer is checked against the mistake it names.
class_name SimplifyGeneratorTest
extends GdUnitTestSuite

const N: int = 1500
const SKILLS: Array[StringName] = [&"simplify.fraction.gcf", &"simplify.ratio.gcf"]

var _catalog: SkillCatalog
var _allowed: Array[StringName]


func before() -> void:
	_catalog = SkillCatalog.load_all()
	_allowed = SkillCatalog.misconception_names()


func _problems(skill_id: StringName, overrides: Dictionary = {}, count: int = N) -> Array[Problem]:
	return GeneratorChecks.make_all(_catalog.skill(skill_id), count, overrides)


func _shares_a_factor(x: int, y: int) -> bool:
	for d: int in range(2, mini(x, y) + 1):
		if x % d == 0 and y % d == 0:
			return true
	return false


func _same_value(x_top: int, x_bottom: int, y_top: int, y_bottom: int) -> bool:
	return x_top * y_bottom == y_top * x_bottom


func _by_name(problem: Problem, name: String) -> Variant:
	for entry: Dictionary in problem.distractors:
		if entry["misconception"] == name:
			return entry["value"]
	return null


func test_every_skill_passes_the_shared_checks() -> void:
	for skill_id: StringName in SKILLS:
		assert_array(GeneratorChecks.run(_catalog.skill(skill_id), N, _allowed)).is_empty()
		assert_array(GeneratorChecks.run(_catalog.skill(skill_id), 400, _allowed, {"difficulty": -1})).is_empty()
		assert_array(GeneratorChecks.run(_catalog.skill(skill_id), 200, _allowed, {"difficulty": -2})).is_empty()


func test_the_same_seed_gives_the_same_problem() -> void:
	for skill_id: StringName in SKILLS:
		for seed: int in range(1, 21):
			var first: Problem = GeneratorRegistry.make_problem(_catalog.skill(skill_id), seed)
			var second: Problem = GeneratorRegistry.make_problem(_catalog.skill(skill_id), seed)
			assert_str(JSON.stringify(first.to_json())).is_equal(JSON.stringify(second.to_json()))


func test_fractions_end_in_lowest_terms_with_the_same_value() -> void:
	var partial: int = 0
	for problem: Problem in _problems(&"simplify.fraction.gcf"):
		var a: int = problem.prompt_params["a"]
		var b: int = problem.prompt_params["b"]
		assert_bool(a > 0 and a < b and b >= 4 and b <= 48).is_true()
		assert_bool(_shares_a_factor(a, b)).is_true()
		var num: int = problem.answer["num"]
		var den: int = problem.answer["den"]
		assert_int(problem.answer.size()).is_equal(2)
		assert_bool(den > 0 and not _shares_a_factor(num, den)).is_true()
		assert_bool(_same_value(a, b, num, den)).is_true()
		assert_bool(Rational.is_canonical(problem.answer)).is_true()
		var top_only: Dictionary = _by_name(problem, "divided_numerator_only")
		assert_int(top_only["num"]).is_equal(num)
		assert_int(top_only["den"]).is_equal(b)
		var flipped: Dictionary = _by_name(problem, "swapped_num_den")
		assert_dict(flipped).is_equal({"num": den, "den": num})
		var halfway: Variant = _by_name(problem, "partially_simplified")
		if halfway != null:
			partial += 1
			assert_bool(_same_value(a, b, halfway["num"], halfway["den"])).is_true()
			assert_bool(_shares_a_factor(halfway["num"], halfway["den"])).is_true()
	assert_int(partial).is_greater(floori(N * 0.1))


func test_ratios_keep_their_order() -> void:
	for problem: Problem in _problems(&"simplify.ratio.gcf"):
		var a: int = problem.prompt_params["a"]
		var b: int = problem.prompt_params["b"]
		assert_bool(a != b and _shares_a_factor(a, b)).is_true()
		var x: int = problem.answer["a"]
		var y: int = problem.answer["b"]
		assert_bool(not _shares_a_factor(x, y) and _same_value(a, b, x, y)).is_true()
		assert_dict(_by_name(problem, "inverted_ratio")).is_equal({"a": y, "b": x})
		assert_dict(_by_name(problem, "divided_one_term_only")).is_equal({"a": x, "b": b})
		if problem.representation == &"concrete":
			assert_dict(problem.visual).is_equal({"type": "gears", "teeth": [a, b]})


func test_answer_labels_read_as_fractions_and_ratios() -> void:
	var fraction: Problem = GeneratorRegistry.make_problem(_catalog.skill(&"simplify.fraction.gcf"), 4)
	assert_str(AnswerPanel.label_for({"num": 3, "den": 4}, fraction)).is_equal("3/4")
	var ratio: Problem = GeneratorRegistry.make_problem(_catalog.skill(&"simplify.ratio.gcf"), 4)
	assert_str(AnswerPanel.label_for({"a": 2, "b": 3}, ratio)).is_equal("2 : 3")
	assert_int(AnswerPanel.choose_input(ratio)).is_equal(AnswerPanel.InputKind.CHOICES)
