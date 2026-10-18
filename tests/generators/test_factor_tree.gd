# Mirrors scripts/generators/factor_tree.gd and fta.gd: the prime recipe of n is worked out here by
# dividing out the smallest divisor again and again (never by MathUtil), trees stay shallow (at most
# four primes, n up to 100), and every wrong recipe is the named mistake it stands for.
class_name FactorTreeGeneratorTest
extends GdUnitTestSuite

const N: int = 1500
const SKILLS: Array[StringName] = [&"pf.tree.build", &"pf.list.write", &"pf.check.equal_products", &"pf.fta.unique"]

var _catalog: SkillCatalog
var _allowed: Array[StringName]


func before() -> void:
	_catalog = SkillCatalog.load_all()
	_allowed = SkillCatalog.misconception_names()


func _problems(skill_id: StringName, count: int = N) -> Array[Problem]:
	return GeneratorChecks.make_all(_catalog.skill(skill_id), count)


func _recipe(n: int) -> Array:
	var found: Array = []
	var left: int = n
	while left > 1:
		var d: int = 2
		while left % d != 0:
			d += 1
		found.append(d)
		left = floori(left / float(d))
	return found


func _is_prime(n: int) -> bool:
	return _recipe(n).size() == 1


func _product(values: Array) -> int:
	var total: int = 1
	for value: Variant in values:
		total *= int(value)
	return total


func _by_name(problem: Problem, name: String) -> Variant:
	for entry: Dictionary in problem.distractors:
		if entry["misconception"] == name:
			return entry["value"]
	return null


func test_every_skill_passes_the_shared_checks() -> void:
	for skill_id: StringName in SKILLS:
		assert_array(GeneratorChecks.run(_catalog.skill(skill_id), N, _allowed)).is_empty()


func test_the_tree_is_the_prime_recipe_of_a_shallow_composite() -> void:
	var sizes: Dictionary = {}
	for problem: Problem in _problems(&"pf.tree.build"):
		var n: int = problem.prompt_params["n"]
		assert_bool(n >= 6 and n <= 100).is_true()
		assert_bool(Problem.same(problem.answer, _recipe(n))).is_true()
		assert_int(problem.answer.size()).is_between(2, 4)
		assert_int(problem.meta["factor_tree"]["value"]).is_equal(n)
		sizes[problem.answer.size()] = true
		var stopped: Variant = _by_name(problem, "stopped_at_composite")
		assert_int(_product(stopped)).is_equal(n)
		assert_bool(stopped.any(func(v: int) -> bool: return not _is_prime(v))).is_true()
	assert_array(sizes.keys()).contains_exactly_in_any_order([2, 3, 4])


func test_written_recipes_offer_the_four_named_mistakes() -> void:
	var primes_asked: int = 0
	for problem: Problem in _problems(&"pf.list.write"):
		var n: int = problem.prompt_params["n"]
		assert_bool(Problem.same(problem.answer, _recipe(n))).is_true()
		assert_str(problem.meta["array_label"]).is_equal("product")
		var with_one: Variant = _by_name(problem, "one_is_prime")
		assert_int(with_one[0]).is_equal(1)
		var mismatch: Variant = _by_name(problem, "product_mismatch")
		assert_bool(_product(mismatch) != n).is_true()
		assert_bool(mismatch.all(func(v: int) -> bool: return _is_prime(v))).is_true()
		if _is_prime(n):
			primes_asked += 1
		else:
			var missing: Variant = _by_name(problem, "missing_repeated_factor")
			if missing != null:
				assert_bool(_product(missing) < n).is_true()
	assert_bool(primes_asked > N * 0.05).is_true()


func test_the_check_answer_is_whether_the_candidate_is_the_recipe() -> void:
	var kinds: Dictionary = {}
	for problem: Problem in _problems(&"pf.check.equal_products"):
		var n: int = problem.prompt_params["n"]
		var candidate: Array = problem.meta["candidate"]
		var keys: Array[String] = ["a", "b", "c", "d"]
		for index: int in candidate.size():
			assert_int(problem.prompt_params[keys[index]]).is_equal(candidate[index])
		assert_bool(problem.answer).is_equal(Problem.same(candidate, _recipe(n)))
		var name: String = problem.distractors[0]["misconception"]
		kinds[name] = true
		if name == "stopped_at_composite":
			assert_int(_product(candidate)).is_equal(n)
		elif name == "product_mismatch":
			assert_bool(_product(candidate) != n).is_true()
		else:
			assert_bool(problem.answer).is_true()
	assert_int(kinds.size()).is_equal(3)


func test_who_is_right_offers_a_composite_leaf_and_a_wrong_product() -> void:
	for problem: Problem in _problems(&"pf.fta.unique"):
		var n: int = problem.prompt_params["n"]
		assert_bool(Problem.same(problem.answer, _recipe(n))).is_true()
		assert_int(problem.answer.size()).is_greater_equal(3)
		var leaf: Variant = _by_name(problem, "tree_with_composite_leaf")
		assert_int(_product(leaf)).is_equal(n)
		assert_int(leaf.size()).is_equal(problem.answer.size() - 1)
		assert_bool(_product(_by_name(problem, "product_mismatch")) != n).is_true()


func test_answer_labels_read_as_products() -> void:
	var problem: Problem = GeneratorRegistry.make_problem(_catalog.skill(&"pf.fta.unique"), 5)
	assert_str(AnswerPanel.label_for([2, 2, 3], problem)).is_equal("2 × 2 × 3")
