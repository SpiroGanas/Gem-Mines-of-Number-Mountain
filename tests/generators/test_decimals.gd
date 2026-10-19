# Mirrors scripts/generators/decimals.gd and percents.gd (Zone 7 decimal.* and percent.*): the decimal
# each picture or fraction stands for is rebuilt here from its digits and compared as whole numbers
# after lining up the places (never with Rational or a float).
class_name DecimalGeneratorTest
extends GdUnitTestSuite

const N: int = 2000
const SKILLS: Array[StringName] = [
	&"decimal.tenths.read", &"decimal.hundredths.read", &"decimal.fraction.convert", &"decimal.compare.order",
	&"percent.of_hundred.read", &"percent.fraction.convert",
]

var _catalog: SkillCatalog
var _allowed: Array[StringName]


func before() -> void:
	_catalog = SkillCatalog.load_all()
	_allowed = SkillCatalog.misconception_names()


func _problems(skill_id: StringName, count: int = N) -> Array[Problem]:
	return GeneratorChecks.make_all(_catalog.skill(skill_id), count)


## The decimal as hundredths (a whole number): {275, 2} is 275 and {5, 1} is 50.
func _hundredths(decimal: Dictionary) -> int:
	var value: int = decimal["mantissa"]
	for place: int in range(decimal["scale"], 2):
		value *= 10
	return value


func _distractor(problem: Problem, name: StringName) -> Variant:
	for entry: Dictionary in problem.distractors:
		if entry["misconception"] == name:
			return entry["value"]
	return null


func test_every_skill_passes_the_shared_checks() -> void:
	for skill_id: StringName in SKILLS:
		assert_array(GeneratorChecks.run(_catalog.skill(skill_id), N, _allowed)).override_failure_message(str(skill_id)).is_empty()
		assert_array(GeneratorChecks.run(_catalog.skill(skill_id), 300, _allowed, {"difficulty": -1})).is_empty()


func test_decimal_answers_have_no_trailing_zero() -> void:
	for skill_id: StringName in [&"decimal.tenths.read", &"decimal.hundredths.read", &"decimal.fraction.convert"]:
		for problem: Problem in _problems(skill_id, 600):
			var answer: Dictionary = problem.answer
			assert_bool(answer["scale"] == 0 or answer["mantissa"] % 10 != 0).is_true()
			assert_bool(answer["scale"] <= problem.meta["decimal_places"]).is_true()


func test_tenths_are_wholes_and_lit_shards() -> void:
	for problem: Problem in _problems(&"decimal.tenths.read"):
		var w: int = problem.prompt_params["w"]
		var k: int = problem.prompt_params["k"]
		assert_bool(w >= 0 and w <= 9 and k >= 1 and k <= 9).is_true()
		assert_int(_hundredths(problem.answer)).is_equal(w * 100 + k * 10)
		assert_int(_hundredths(_distractor(problem, &"read_as_whole"))).is_equal((w * 10 + k) * 100)
		assert_int(problem.meta["decimal_places"]).is_equal(1)


func test_hundredths_are_wholes_and_lit_cells() -> void:
	var dropped: int = 0
	for problem: Problem in _problems(&"decimal.hundredths.read"):
		var w: int = problem.prompt_params["w"]
		var k: int = problem.prompt_params["k"]
		assert_int(_hundredths(problem.answer)).is_equal(w * 100 + k)
		var zero: Variant = _distractor(problem, &"dropped_zero")
		if zero != null:
			dropped += 1
			assert_bool(k < 10).is_true()
			assert_int(_hundredths(zero)).is_equal(w * 100 + k * 10)
		if problem.representation == &"pictorial":
			assert_int(problem.visual["grids"][0]["lit"]).is_equal(k)
	assert_bool(dropped > 0).is_true()


func test_fractions_become_exact_decimals() -> void:
	for problem: Problem in _problems(&"decimal.fraction.convert"):
		var num: int = problem.prompt_params["num"]
		var den: int = problem.prompt_params["den"]
		assert_bool([2, 4, 5, 10, 20, 25, 50, 100].has(den)).is_true()
		assert_int(_hundredths(problem.answer) * den).is_equal(num * 100)


func test_decimal_comparisons_point_the_right_way() -> void:
	var named: int = 0
	for problem: Problem in _problems(&"decimal.compare.order"):
		var a: int = _hundredths(problem.prompt_params["a"])
		var b: int = _hundredths(problem.prompt_params["b"])
		assert_bool(a != b).is_true()
		assert_str(String(problem.answer)).is_equal("<" if a < b else ">")
		if _distractor(problem, &"reversed_symbol") == null:
			named += 1
	assert_bool(named > N * 0.9).override_failure_message("most pairs should invite a named mistake: %d" % named).is_true()


func test_percent_of_a_hundred_is_the_lit_cells() -> void:
	for problem: Problem in _problems(&"percent.of_hundred.read"):
		var lit: int = problem.visual["grids"][0]["lit"]
		assert_int(problem.answer).is_equal(lit)
		if lit != 50: # half lit: the dark cells are the same count, so that is no wrong answer
			assert_int(_distractor(problem, &"counted_unlit")).is_equal(100 - lit)
		else:
			assert_that(_distractor(problem, &"counted_unlit")).is_null()
		assert_bool(problem.meta["percent"]).is_true()


func test_fractions_become_whole_percents() -> void:
	for problem: Problem in _problems(&"percent.fraction.convert"):
		var num: int = problem.prompt_params["num"]
		var den: int = problem.prompt_params["den"]
		assert_int(problem.answer * den).is_equal(num * 100)
		var top: Variant = _distractor(problem, &"wrote_numerator_as_percent")
		if top != null:
			assert_int(top).is_equal(num)
