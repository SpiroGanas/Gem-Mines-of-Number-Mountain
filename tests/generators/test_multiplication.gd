# Mirrors scripts/generators/multiplication.gd: totals of repeated addition and equal groups, the
# commutative match (same product, every wrong fact a different one) and the 2, 5, 10 tables.
class_name MultiplicationGeneratorTest
extends GdUnitTestSuite

const N: int = 2000
const TIMES: String = " × "

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


## "5 × 3" as [5, 3].
func _factors(fact: String) -> Array[int]:
	var parts: PackedStringArray = fact.split(TIMES)
	assert_int(parts.size()).is_equal(2)
	var result: Array[int] = [int(parts[0]), int(parts[1])]
	assert_str("%d%s%d" % [result[0], TIMES, result[1]]).is_equal(fact) # nothing else in the label
	return result


func test_mult_repeated_add_to_sum_passes_the_shared_checks() -> void:
	_check(&"mult.repeated_add.to_sum")


func test_mult_equal_groups_total_passes_the_shared_checks() -> void:
	_check(&"mult.equal_groups.total")


func test_mult_commutative_match_passes_the_shared_checks() -> void:
	_check(&"mult.commutative.match")


func test_mult_facts_2_5_10_passes_the_shared_checks() -> void:
	_check(&"mult.facts.2_5_10")


func test_repeated_addition_adds_the_groups_shown() -> void:
	var lengths: Dictionary = {}
	for problem: Problem in _problems(&"mult.repeated_add.to_sum"):
		var groups: int = problem.visual["groups"]
		var size: int = problem.visual["size"]
		lengths[groups] = true
		assert_str(problem.visual["type"]).is_equal("groups")
		assert_int(groups).is_between(2, 5)
		assert_int(size).is_between(2, 5)
		assert_str(problem.prompt_line_id).is_equal("z3.mult.prompt_repeated_%d" % groups)
		assert_int(Text.get_line(problem.prompt_line_id, problem.prompt_params).count("+")).is_equal(groups - 1)
		assert_dict(problem.prompt_params).is_equal({"n": size})
		var total: int = 0
		for _group: int in groups:
			total += size
		assert_int(problem.answer).is_equal(total)
		assert_array(_distractor(problem, &"counted_groups")).is_equal([groups])
		for value: int in _distractor(problem, &"off_by_group"):
			assert_bool(value == total - size or value == total + size).is_true()
		var model: Dictionary = problem.hint_steps[1]["visual"]
		assert_int(model["max"]).is_equal(total)
		assert_array(model["jumps"]).has_size(groups)
	assert_array(lengths.keys()).contains_exactly_in_any_order([2, 3, 4, 5])


func test_equal_groups_total_stays_within_max() -> void:
	for problem: Problem in _problems(&"mult.equal_groups.total"):
		var groups: int = problem.prompt_params["groups"]
		var size: int = problem.prompt_params["size"]
		assert_dict(problem.visual).is_equal({"type": "groups", "groups": groups, "size": size})
		assert_int(problem.answer).is_equal(groups * size)
		assert_int(problem.answer).is_less_equal(25)
		assert_int(groups).is_greater_equal(2)
		assert_int(size).is_greater_equal(2)
		assert_array(_distractor(problem, &"counted_groups")).is_equal([groups])
		if groups + size != groups * size:
			assert_array(_distractor(problem, &"rows_plus_cols")).is_equal([groups + size])
		assert_dict(problem.hint_steps[1]["visual"]).is_equal({"type": "array", "rows": groups, "cols": size, "outline_rows": true})


func test_commutative_answer_is_the_swapped_fact_with_the_same_product() -> void:
	for problem: Problem in _problems(&"mult.commutative.match"):
		var rows: int = problem.visual["rows"]
		var cols: int = problem.visual["cols"]
		assert_int(rows).is_not_equal(cols)
		assert_int(rows).is_between(2, 5)
		assert_int(cols).is_between(2, 5)
		assert_dict(problem.prompt_params).is_equal({"rows": rows, "cols": cols})
		var answer: Array[int] = _factors(problem.answer)
		assert_array(answer).is_equal([cols, rows])
		assert_int(answer[0] * answer[1]).is_equal(rows * cols)


func test_every_commutative_wrong_fact_has_a_different_product() -> void:
	for problem: Problem in _problems(&"mult.commutative.match"):
		var rows: int = problem.visual["rows"]
		var cols: int = problem.visual["cols"]
		var products: Array[int] = [rows * cols]
		assert_array(problem.distractors).has_size(3)
		for entry: Dictionary in problem.distractors:
			assert_str(entry["misconception"]).is_equal("rows_cols_swapped_wrong")
			var wrong: Array[int] = _factors(entry["value"])
			# Swapped, then one number changed by one.
			var changed_first: bool = wrong[1] == rows and absi(wrong[0] - cols) == 1
			var changed_second: bool = wrong[0] == cols and absi(wrong[1] - rows) == 1
			assert_bool(changed_first or changed_second).is_true()
			assert_bool(products.has(wrong[0] * wrong[1])).override_failure_message("%s repeats a product" % entry["value"]).is_false()
			products.append(wrong[0] * wrong[1])


func test_facts_use_one_table_factor_in_either_order() -> void:
	var table_first: int = 0
	var tables_seen: Dictionary = {}
	for problem: Problem in _problems(&"mult.facts.2_5_10"):
		var a: int = problem.prompt_params["a"]
		var b: int = problem.prompt_params["b"]
		var table: int = problem.meta["table"]
		tables_seen[table] = true
		assert_array([2, 5, 10]).contains([table])
		var other: int = b if problem.meta["table_first"] else a
		assert_int(a if problem.meta["table_first"] else b).is_equal(table)
		assert_int(other).is_between(1, 10)
		assert_int(problem.answer).is_equal(a * b)
		assert_bool(problem.visual.is_empty()).is_true()
		assert_dict(problem.hint_steps[1]["visual"]).is_equal({"type": "groups", "groups": a, "size": b})
		if problem.meta["table_first"]:
			table_first += 1
	assert_array(tables_seen.keys()).contains_exactly_in_any_order([2, 5, 10])
	assert_int(table_first).is_between(int(N * 0.4), int(N * 0.6))


func test_facts_wrong_answers_are_the_named_mistakes() -> void:
	for problem: Problem in _problems(&"mult.facts.2_5_10"):
		var a: int = problem.prompt_params["a"]
		var b: int = problem.prompt_params["b"]
		var table: int = problem.meta["table"]
		var other: int = b if problem.meta["table_first"] else a
		var product: int = a * b
		var off: Array = _distractor(problem, &"off_by_group")
		assert_bool(off.is_empty()).is_false()
		for value: int in off:
			assert_bool(value == product - table or value == product + table).is_true()
			assert_int(value).is_greater(0)
		var wrong_tables: Array = _distractor(problem, &"wrong_table")
		assert_bool(wrong_tables.is_empty()).is_false()
		for value: int in wrong_tables:
			var ok: bool = false
			for times: int in [2, 5, 10]:
				if times != table and times * other == value:
					ok = true
			assert_bool(ok).override_failure_message("%d is not another table times %d" % [value, other]).is_true()
		# The first three buttons mix both kinds of mistake.
		var shown: Array = []
		for entry: Dictionary in problem.distractors.slice(0, 3):
			shown.append(entry["misconception"])
		assert_bool(shown.has(&"off_by_group") and shown.has(&"wrong_table")).is_true()


func test_easier_difficulty_gives_smaller_numbers() -> void:
	for skill_id: StringName in [&"mult.repeated_add.to_sum", &"mult.equal_groups.total", &"mult.facts.2_5_10"]:
		var normal: int = 0
		var easy: int = 0
		for problem: Problem in _problems(skill_id, {}, 1000):
			normal = maxi(normal, problem.answer)
		for problem: Problem in _problems(skill_id, {"difficulty": -1}, 1000):
			easy = maxi(easy, problem.answer)
		assert_int(easy).is_less(normal)
	var biggest: int = 0
	for problem: Problem in _problems(&"mult.commutative.match", {"difficulty": -1}, 1000):
		biggest = maxi(biggest, maxi(problem.visual["rows"], problem.visual["cols"]))
	assert_int(biggest).is_less(5)


func test_the_easiest_problems_still_pass_the_shared_checks() -> void:
	for skill_id: StringName in [&"mult.repeated_add.to_sum", &"mult.equal_groups.total", &"mult.commutative.match", &"mult.facts.2_5_10"]:
		var errors: Array[String] = GeneratorChecks.run(_catalog.skill(skill_id), 500, _allowed, {"difficulty": -8})
		assert_array(errors).override_failure_message("\n".join(errors)).is_empty()


func test_the_same_seed_gives_the_same_problem_and_the_global_rng_is_untouched() -> void:
	var skill: Skill = _catalog.skill(&"mult.commutative.match")
	for seed: int in range(1, 200):
		assert_dict(GeneratorRegistry.make_problem(skill, seed).to_json()).is_equal(GeneratorRegistry.make_problem(skill, seed).to_json())
	seed(777)
	var expected: int = randi()
	seed(777)
	_problems(&"mult.facts.2_5_10", {}, 300)
	assert_int(randi()).is_equal(expected)
