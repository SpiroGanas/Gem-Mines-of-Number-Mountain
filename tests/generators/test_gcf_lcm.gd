# Mirrors scripts/generators/gcf.gd and lcm.gd (P4-S29-03, -04). Written test-first: the oracles below
# work everything out the slow way (factors by trying every number, multiples by counting up, the GCF
# as the biggest number dividing both), never through MathUtil or the generators' helpers.
class_name GcfLcmGeneratorTest
extends GdUnitTestSuite

const N: int = 1500
const GCF_SKILLS: Array[StringName] = [&"gcf.list.common_factors", &"gcf.find.by_listing", &"gcf.find.by_factor_tree", &"gcf.coprime.identify"]
const LCM_SKILLS: Array[StringName] = [&"lcm.list.common_multiples", &"lcm.find.by_listing", &"lcm.find.by_factorization", &"lcm.relation.gcf_times_lcm"]

var _catalog: SkillCatalog
var _allowed: Array[StringName]


func before() -> void:
	_catalog = SkillCatalog.load_all()
	_allowed = SkillCatalog.misconception_names()


func _problems(skill_id: StringName, overrides: Dictionary = {}, count: int = N) -> Array[Problem]:
	return GeneratorChecks.make_all(_catalog.skill(skill_id), count, overrides)


# --- Slow oracles ------------------------------------------------------------------------------


func _factors(n: int) -> Array:
	var found: Array = []
	for d: int in range(1, n + 1):
		if n % d == 0:
			found.append(d)
	return found


func _common(a: int, b: int) -> Array:
	var found: Array = []
	for d: int in range(1, mini(a, b) + 1):
		if a % d == 0 and b % d == 0:
			found.append(d)
	return found


func _gcf(a: int, b: int) -> int:
	return _common(a, b).back()


## The first number found counting up by a that b also divides.
func _lcm(a: int, b: int) -> int:
	var at: int = a
	while at % b != 0:
		at += a
	return at


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
	return n >= 2 and _factors(n).size() == 2


func _by_name(problem: Problem, name: String) -> Variant:
	for entry: Dictionary in problem.distractors:
		if entry["misconception"] == name:
			return entry["value"]
	return null


# --- Shared invariants -------------------------------------------------------------------------


func test_every_skill_passes_the_shared_checks() -> void:
	for skill_id: StringName in GCF_SKILLS + LCM_SKILLS:
		assert_array(GeneratorChecks.run(_catalog.skill(skill_id), N, _allowed)).is_empty()


func test_easier_problems_pass_the_shared_checks_too() -> void:
	for skill_id: StringName in GCF_SKILLS + LCM_SKILLS:
		assert_array(GeneratorChecks.run(_catalog.skill(skill_id), 400, _allowed, {"difficulty": -1})).is_empty()
		assert_array(GeneratorChecks.run(_catalog.skill(skill_id), 200, _allowed, {"difficulty": -2})).is_empty()


func test_the_same_seed_gives_the_same_problem() -> void:
	for skill_id: StringName in GCF_SKILLS + LCM_SKILLS:
		for seed: int in range(1, 21):
			var first: Problem = GeneratorRegistry.make_problem(_catalog.skill(skill_id), seed)
			var second: Problem = GeneratorRegistry.make_problem(_catalog.skill(skill_id), seed)
			assert_str(JSON.stringify(first.to_json())).is_equal(JSON.stringify(second.to_json()))


func test_answer_buttons_offer_at_least_two_wrong_answers() -> void:
	for skill_id: StringName in [&"gcf.list.common_factors", &"gcf.find.by_listing", &"gcf.find.by_factor_tree"] + LCM_SKILLS:
		for problem: Problem in _problems(skill_id, {}, 600):
			assert_int(problem.distractors.size()).override_failure_message("%s seed %d" % [skill_id, problem.seed]).is_greater_equal(2)


# --- GCF ---------------------------------------------------------------------------------------


func test_common_factors_are_every_shared_factor() -> void:
	for problem: Problem in _problems(&"gcf.list.common_factors"):
		var a: int = problem.prompt_params["a"]
		var b: int = problem.prompt_params["b"]
		assert_bool(a >= 4 and a < b and b <= 50).is_true()
		assert_bool(Problem.same(problem.answer, _common(a, b))).is_true()
		assert_int(problem.answer.size()).is_greater_equal(2) # they share a factor above 1
		var extra: Variant = _by_name(problem, "included_non_factor")
		if extra != null:
			var strangers: Array = extra.filter(func(v: int) -> bool: return not _common(a, b).has(v))
			assert_int(strangers.size()).is_equal(1)
			assert_bool(a % strangers[0] == 0 or b % strangers[0] == 0).is_true()
		var missed: Array = _by_name(problem, "missed_largest")
		assert_bool(missed.has(_gcf(a, b))).is_false()
		var own: Variant = _by_name(problem, "factors_of_one_number")
		if own != null:
			assert_bool(Problem.same(own, _factors(a))).is_true()


func test_common_factor_pictures_follow_the_representation() -> void:
	for problem: Problem in _problems(&"gcf.list.common_factors", {}, 60):
		var a: int = problem.prompt_params["a"]
		var b: int = problem.prompt_params["b"]
		match problem.representation:
			&"concrete":
				assert_dict(problem.visual).is_equal({"type": "gears", "teeth": [a, b]})
			&"pictorial":
				assert_str(problem.visual["kind"]).is_equal("factors")
				assert_array(problem.visual["marked"]).is_empty()
			_:
				assert_dict(problem.visual).is_empty()
		assert_array(problem.hint_steps[1]["visual"]["marked"]).is_equal(_common(a, b))


func test_the_gcf_is_the_biggest_shared_factor() -> void:
	var names: Dictionary = {}
	for problem: Problem in _problems(&"gcf.find.by_listing"):
		var a: int = problem.prompt_params["a"]
		var b: int = problem.prompt_params["b"]
		assert_bool(a >= 4 and a < b and b <= 60).is_true()
		assert_int(problem.answer).is_equal(_gcf(a, b))
		var lcm_value: Variant = _by_name(problem, "picked_lcm")
		if lcm_value != null:
			assert_int(lcm_value).is_equal(_lcm(a, b))
		var smallest: Variant = _by_name(problem, "picked_smallest_common")
		if smallest != null:
			assert_int(smallest).is_equal(_common(a, b)[1])
		var prime: Variant = _by_name(problem, "picked_prime_factor_only")
		if prime != null:
			assert_bool(_is_prime(prime) and problem.answer % prime == 0).is_true()
		for entry: Dictionary in problem.distractors:
			names[entry["misconception"]] = true
	assert_array(names.keys()).contains_exactly_in_any_order(["picked_smallest_common", "picked_lcm", "picked_prime_factor_only", "picked_smaller_number"])


func test_the_coprime_rate_is_pinned_within_three_percent() -> void:
	var coprime: int = 0
	var count: int = 5000
	for problem: Problem in _problems(&"gcf.find.by_listing", {}, count):
		if problem.answer == 1:
			coprime += 1
	assert_float(float(coprime) / count).is_between(0.17, 0.23)


func test_the_gcf_from_prime_recipes() -> void:
	for problem: Problem in _problems(&"gcf.find.by_factor_tree"):
		var a: int = problem.prompt_params["a"]
		var b: int = problem.prompt_params["b"]
		assert_bool(_recipe(a).size() >= 2 and _recipe(a).size() <= 4 and _recipe(b).size() >= 2 and _recipe(b).size() <= 4).is_true()
		assert_int(problem.answer).is_equal(_gcf(a, b))
		assert_int(problem.answer).is_greater(1)
		assert_int(_by_name(problem, "took_union")).is_equal(_lcm(a, b))
		assert_int(_by_name(problem, "multiplied_all_primes")).is_equal(a * b)
		var recipes: Dictionary = problem.hint_steps[1]["visual"]
		assert_str(recipes["kind"]).is_equal("recipe")
		assert_array(recipes["rows"][0]["items"]).is_equal(_recipe(a))
		var lit_product: int = 1
		for index: int in recipes["rows"][0]["lit"]:
			lit_product *= int(recipes["rows"][0]["items"][index])
		assert_int(lit_product).is_equal(problem.answer) # the lit primes make the GCF
		if problem.representation == &"pictorial":
			assert_dict(problem.visual).is_equal(recipes)


func test_coprime_answers_and_their_named_mistakes() -> void:
	var names: Dictionary = {}
	var yes: int = 0
	for problem: Problem in _problems(&"gcf.coprime.identify"):
		var a: int = problem.prompt_params["a"]
		var b: int = problem.prompt_params["b"]
		var coprime: bool = _gcf(a, b) == 1
		assert_bool(problem.answer).is_equal(coprime)
		yes += 1 if coprime else 0
		assert_int(problem.distractors.size()).is_equal(1)
		assert_bool(problem.distractors[0]["value"]).is_equal(not coprime)
		var name: String = problem.distractors[0]["misconception"]
		names[name] = true
		match name:
			"shared_even_only":
				assert_bool(not coprime and a % 2 == 1 and b % 2 == 1).is_true()
			"missed_common_factor":
				assert_bool(not coprime and (a % 2 == 0 or b % 2 == 0)).is_true()
			"assumed_common_factor":
				assert_bool(coprime and _is_prime(a) and _is_prime(b)).is_true()
			"assumed_primes_only":
				assert_bool(coprime and not (_is_prime(a) and _is_prime(b))).is_true()
	assert_int(names.size()).is_equal(4)
	assert_float(float(yes) / N).is_between(0.4, 0.6)


func test_gcf_edge_pairs_one_number_divides_the_other() -> void:
	var seen_multiple: bool = false
	for problem: Problem in _problems(&"gcf.find.by_listing"):
		var a: int = problem.prompt_params["a"]
		var b: int = problem.prompt_params["b"]
		if b % a == 0:
			seen_multiple = true
			assert_int(problem.answer).is_equal(a)
			assert_object(_by_name(problem, "picked_smaller_number")).is_null() # it would be the answer
	assert_bool(seen_multiple).is_true()


# --- LCM ---------------------------------------------------------------------------------------


func test_common_multiples_are_multiples_of_the_lcm() -> void:
	for problem: Problem in _problems(&"lcm.list.common_multiples"):
		var a: int = problem.prompt_params["a"]
		var b: int = problem.prompt_params["b"]
		var k: int = problem.prompt_params["k"]
		assert_int(k).is_equal(3)
		var l: int = _lcm(a, b)
		assert_array(problem.answer).is_equal([l, 2 * l, 3 * l])
		for value: Variant in problem.answer:
			assert_bool(value % a == 0 and value % b == 0).is_true()
		assert_array(_by_name(problem, "off_by_one_multiple")).is_equal([2 * l, 3 * l, 4 * l])
		assert_array(_by_name(problem, "multiples_of_one_number")).is_equal([a, 2 * a, 3 * a])
		assert_bool(problem.meta["tile_board"]["ordered"]).is_false()
		assert_int(problem.meta["tile_board"]["slots"]).is_equal(3)


func test_the_lcm_is_the_first_shared_multiple() -> void:
	for problem: Problem in _problems(&"lcm.find.by_listing"):
		var a: int = problem.prompt_params["a"]
		var b: int = problem.prompt_params["b"]
		assert_bool(a >= 2 and a < b and b <= 15).is_true()
		assert_int(problem.answer).is_equal(_lcm(a, b))
		assert_int(_by_name(problem, "picked_gcf")).is_equal(_gcf(a, b))
		assert_int(_by_name(problem, "picked_sum")).is_equal(a + b)
		var marked: Array = problem.hint_steps[1]["visual"]["marked"]
		assert_array(marked).is_equal([problem.answer])


func test_the_lcm_from_prime_recipes() -> void:
	var dropped: int = 0
	for problem: Problem in _problems(&"lcm.find.by_factorization"):
		var a: int = problem.prompt_params["a"]
		var b: int = problem.prompt_params["b"]
		assert_int(problem.answer).is_equal(_lcm(a, b))
		assert_int(problem.answer).is_less_equal(999)
		assert_int(_gcf(a, b)).is_greater(1)
		assert_int(_by_name(problem, "took_intersection")).is_equal(_gcf(a, b))
		var once: Variant = _by_name(problem, "dropped_highest_power")
		if once != null:
			dropped += 1
			assert_bool(problem.answer % once == 0 and once < problem.answer).is_true()
	assert_int(dropped).is_greater(floori(N * 0.1))


func test_gcf_times_lcm_is_the_product() -> void:
	for problem: Problem in _problems(&"lcm.relation.gcf_times_lcm"):
		var a: int = problem.prompt_params["a"]
		var b: int = problem.prompt_params["b"]
		var g: int = problem.prompt_params["g"]
		assert_int(g).is_equal(_gcf(a, b))
		assert_int(problem.answer * g).is_equal(a * b)
		var added: Variant = _by_name(problem, "added_instead_of_multiplied")
		if added != null:
			assert_int(added + g).is_equal(a + b)


func test_the_worked_example_states_its_own_answer() -> void:
	for problem: Problem in _problems(&"lcm.relation.gcf_times_lcm", {}, 40):
		var example: Dictionary = problem.hint_steps[2]["example"]
		assert_str(String(example["answer_line_id"])).is_equal("z6.hint.example_relation")
		assert_int(example["answer_params"]["l"]).is_equal(example["answer"])


func test_answer_labels_read_as_lists() -> void:
	var problem: Problem = GeneratorRegistry.make_problem(_catalog.skill(&"gcf.list.common_factors"), 3)
	assert_str(AnswerPanel.label_for([1, 2, 4], problem)).is_equal("1, 2, 4")
