# Mirrors scripts/generators/arrays.gd: an array of r rows and c columns holds r x c gems, and each
# wrong answer is the named mistake (added instead of multiplied, a row too many or too few, swapped).
class_name ArraysGeneratorTest
extends GdUnitTestSuite

const N: int = 2000

var _catalog: SkillCatalog
var _allowed: Array[StringName]


func before() -> void:
	_catalog = SkillCatalog.load_all()
	_allowed = SkillCatalog.misconception_names()


func _problems(skill_id: StringName, overrides: Dictionary = {}, count: int = N) -> Array[Problem]:
	return GeneratorChecks.make_all(_catalog.skill(skill_id), count, overrides)


func _check(skill_id: StringName) -> void:
	var skill: Skill = _catalog.skill(skill_id)
	assert_object(skill).is_not_null()
	var errors: Array[String] = GeneratorChecks.run(skill, 10000, _allowed)
	assert_array(errors).override_failure_message("\n".join(errors)).is_empty()


func _distractor(problem: Problem, name: StringName) -> Array:
	var values: Array = []
	for entry: Dictionary in problem.distractors:
		if entry["misconception"] == name:
			values.append(entry["value"])
	return values


func test_arr_rows_cols_count_passes_the_shared_checks() -> void:
	_check(&"arr.rows_cols.count")


func test_arr_rows_cols_build_passes_the_shared_checks() -> void:
	_check(&"arr.rows_cols.build")


func test_count_answer_is_rows_times_columns() -> void:
	var shapes: Dictionary = {}
	for problem: Problem in _problems(&"arr.rows_cols.count"):
		var rows: int = problem.visual["rows"]
		var cols: int = problem.visual["cols"]
		shapes["%dx%d" % [rows, cols]] = true
		assert_str(problem.visual["type"]).is_equal("array")
		assert_int(rows).is_between(2, 5)
		assert_int(cols).is_between(2, 5)
		var counted: int = 0
		for _row: int in rows:
			counted += cols
		assert_int(problem.answer).is_equal(counted)
		assert_dict(problem.hint_steps[1]["visual"]).is_equal({"type": "array", "rows": rows, "cols": cols, "outline_rows": true})
	assert_int(shapes.size()).is_equal(16) # every shape from 2x2 to 5x5


func test_count_wrong_answers_are_the_named_mistakes() -> void:
	for problem: Problem in _problems(&"arr.rows_cols.count"):
		var rows: int = problem.visual["rows"]
		var cols: int = problem.visual["cols"]
		var total: int = problem.answer
		var added: Array = _distractor(problem, &"rows_plus_cols")
		if rows + cols == total:
			assert_array(added).is_empty() # 2 x 2: adding gives the right answer, so it is no mistake
		else:
			assert_array(added).is_equal([rows + cols])
		var off: Array = _distractor(problem, &"off_by_row")
		assert_bool(off.is_empty()).is_false()
		for value: int in off:
			assert_bool(value == total - cols or value == total + cols).is_true()
		assert_int(problem.distractors.size()).is_greater_equal(2) # enough for three answer buttons


func test_build_answer_matches_the_prompt_and_rows_and_columns_differ() -> void:
	var shapes: Dictionary = {}
	for problem: Problem in _problems(&"arr.rows_cols.build"):
		var rows: int = problem.prompt_params["rows"]
		var cols: int = problem.prompt_params["cols"]
		shapes["%dx%d" % [rows, cols]] = true
		assert_dict(problem.answer).is_equal({"rows": rows, "cols": cols})
		assert_int(rows).is_not_equal(cols)
		assert_int(rows).is_between(2, 5)
		assert_int(cols).is_between(2, 5)
		assert_bool(problem.visual.is_empty()).is_true() # the builder is the picture
		assert_dict(problem.meta["array_builder"]).is_equal({"max_rows": 5, "max_cols": 5})
		assert_array(problem.distractors).has_size(1)
		assert_str(problem.distractors[0]["misconception"]).is_equal("rows_cols_swapped")
		assert_dict(problem.distractors[0]["value"]).is_equal({"rows": cols, "cols": rows})
		assert_dict(problem.hint_steps[1]["visual"]).is_equal({"type": "array", "rows": rows, "cols": cols, "outline_rows": true})
		var example: Dictionary = problem.hint_steps[2]["example"]
		assert_dict(example["answer_params"]).is_equal(example["answer"])
	assert_int(shapes.size()).is_equal(12) # the 16 shapes from 2x2 to 5x5 less the four squares


func test_easier_difficulty_gives_smaller_arrays() -> void:
	for skill_id: StringName in [&"arr.rows_cols.count", &"arr.rows_cols.build"]:
		var easy: int = 0
		for problem: Problem in _problems(skill_id, {"difficulty": -1}, 1000):
			var shape: Dictionary = problem.visual if skill_id == &"arr.rows_cols.count" else problem.answer
			easy = maxi(easy, maxi(shape["rows"], shape["cols"]))
		assert_int(easy).is_less(5)
	# The builder itself stays full size so the board does not change under the child.
	for problem: Problem in _problems(&"arr.rows_cols.build", {"difficulty": -2}, 200):
		assert_dict(problem.meta["array_builder"]).is_equal({"max_rows": 5, "max_cols": 5})


func test_the_easiest_problems_still_pass_the_shared_checks() -> void:
	for skill_id: StringName in [&"arr.rows_cols.count", &"arr.rows_cols.build"]:
		var errors: Array[String] = GeneratorChecks.run(_catalog.skill(skill_id), 500, _allowed, {"difficulty": -8})
		assert_array(errors).override_failure_message("\n".join(errors)).is_empty()


func test_the_same_seed_gives_the_same_problem_and_the_global_rng_is_untouched() -> void:
	var skill: Skill = _catalog.skill(&"arr.rows_cols.build")
	for seed: int in range(1, 200):
		assert_dict(GeneratorRegistry.make_problem(skill, seed).to_json()).is_equal(GeneratorRegistry.make_problem(skill, seed).to_json())
	seed(777)
	var expected: int = randi()
	seed(777)
	_problems(&"arr.rows_cols.count", {}, 300)
	assert_int(randi()).is_equal(expected)
