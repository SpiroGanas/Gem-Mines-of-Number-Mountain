# Mirrors scripts/generators/figurate.gd and gauss.gd (Zone 9 fig.* and gauss.sum.*): triangles are
# counted row by row, squares row times row, two staircases make a square, and Gauss's sum is added up
# one number at a time here (never with the generator's formula).
class_name FigurateGaussGeneratorTest
extends GdUnitTestSuite

const N: int = 2000
const SKILLS: Array[StringName] = [
	&"fig.triangular.build", &"fig.square.build", &"fig.two_triangles.square",
	&"gauss.sum.pairing", &"gauss.sum.formula",
]

var _catalog: SkillCatalog
var _allowed: Array[StringName]


func before() -> void:
	_catalog = SkillCatalog.load_all()
	_allowed = SkillCatalog.misconception_names()


func _problems(skill_id: StringName, count: int = N, overrides: Dictionary = {}) -> Array[Problem]:
	return GeneratorChecks.make_all(_catalog.skill(skill_id), count, overrides)


func _rows(n: int) -> int:
	var total: int = 0
	for row: int in range(1, n + 1):
		total += row
	return total


func _names(problem: Problem) -> Dictionary:
	var named: Dictionary = {}
	for entry: Dictionary in problem.distractors:
		named[entry["misconception"]] = named.get(entry["misconception"], []) + [entry["value"]]
	return named


func test_every_skill_passes_the_shared_checks() -> void:
	for skill_id: StringName in SKILLS:
		assert_array(GeneratorChecks.run(_catalog.skill(skill_id), N, _allowed)).override_failure_message(str(skill_id)).is_empty()
		assert_array(GeneratorChecks.run(_catalog.skill(skill_id), 300, _allowed, {"difficulty": -1})).override_failure_message(str(skill_id) + " easier").is_empty()


func test_a_triangle_is_counted_row_by_row() -> void:
	var sizes: Dictionary = {}
	for problem: Problem in _problems(&"fig.triangular.build"):
		var n: int = problem.prompt_params["n"]
		sizes[n] = true
		assert_int(n).is_between(2, 12)
		assert_int(problem.answer).is_equal(_rows(n))
		assert_array(_names(problem)[&"used_square"]).contains_exactly([n * n])
		if problem.representation == &"concrete":
			assert_int(n).is_greater_equal(3)
			var terms: Array = problem.meta["pattern_wall"]["terms"]
			assert_that(terms.back()).is_null()
			var first: int = int(problem.visual["first_index"])
			for index: int in terms.size() - 1:
				assert_int(int(terms[index])).is_equal(_rows(first + index))
		else:
			assert_dict(problem.visual).is_equal({"type": "figurate", "kind": "triangle", "n": n})
	assert_int(sizes.size()).is_equal(11)


func test_a_square_is_rows_times_rows_on_the_wall() -> void:
	for problem: Problem in _problems(&"fig.square.build"):
		var n: int = problem.prompt_params["n"]
		assert_int(problem.answer).is_equal(n * n)
		assert_array(_names(problem)[&"used_triangular"]).contains_exactly([_rows(n)])
		assert_bool(problem.meta["pattern_wall"]["tiles"].has(n * n)).is_true()
		assert_str(str(problem.visual["figure"])).is_equal("square")


func test_two_staircases_fill_the_square() -> void:
	for problem: Problem in _problems(&"fig.two_triangles.square"):
		var n: int = problem.prompt_params["n"]
		assert_int(problem.prompt_params["m"]).is_equal(n - 1)
		assert_int(_rows(n) + _rows(n - 1)).is_equal(problem.answer)
		assert_int(problem.answer).is_equal(n * n)
		assert_array(_names(problem)[&"added_same_triangular_twice_wrong_n"]).contains_exactly([2 * _rows(n)])
		assert_bool(problem.visual["fitted"]).is_false()
		assert_bool(problem.hint_steps[1]["visual"]["fitted"]).is_true()


func test_gauss_adds_one_to_n() -> void:
	for problem: Problem in _problems(&"gauss.sum.pairing"):
		var n: int = problem.prompt_params["n"]
		assert_int(n).is_between(2, 20)
		assert_int(problem.prompt_params["a"]).is_equal(1)
		assert_int(problem.prompt_params["b"]).is_equal(2)
		assert_int(problem.answer).is_equal(_rows(n))
		var named: Dictionary = _names(problem)
		assert_array(named[&"forgot_halve"]).contains_exactly([2 * _rows(n)])
		assert_array(named[&"used_n_squared"]).contains_exactly([n * n])
		assert_array(named[&"off_by_one_n"]).contains_exactly([_rows(n - 1)])
		assert_bool(problem.visual.is_empty()).is_equal(problem.representation == &"abstract")


func test_the_formula_skill_uses_sums_too_long_to_add_by_hand() -> void:
	var biggest: int = 0
	for problem: Problem in _problems(&"gauss.sum.formula"):
		var n: int = problem.prompt_params["n"]
		assert_int(n).is_between(GaussGenerator.FORMULA_MIN_N, 100)
		assert_int(problem.answer).is_equal(_rows(n))
		assert_int(int(problem.meta["pad_digits"])).is_equal(4)
		assert_bool(problem.visual.is_empty()).is_true()
		biggest = maxi(biggest, problem.answer)
	assert_int(biggest).is_equal(5050)
