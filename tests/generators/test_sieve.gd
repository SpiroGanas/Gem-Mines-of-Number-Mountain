# Mirrors scripts/generators/sieve.gd: the crossed-out rocks are worked out here by trial division
# (never by MathUtil), the precrossed rocks are an earlier part of the sieve and stay in every answer,
# a prime is never in an answer, and each wrong board is the mistake it names.
class_name SieveGeneratorTest
extends GdUnitTestSuite

const N: int = 600
const SKILLS: Array[StringName] = [&"sieve.mark.multiples_of", &"sieve.find.primes_to_50", &"sieve.find.primes_to_100"]

var _catalog: SkillCatalog
var _allowed: Array[StringName]


func before() -> void:
	_catalog = SkillCatalog.load_all()
	_allowed = SkillCatalog.misconception_names()


func _problems(skill_id: StringName, count: int = N) -> Array[Problem]:
	return GeneratorChecks.make_all(_catalog.skill(skill_id), count)


func _is_prime(n: int) -> bool:
	if n < 2:
		return false
	for d: int in range(2, n):
		if n % d == 0:
			return false
	return true


func _smallest_factor(n: int) -> int:
	for d: int in range(2, n + 1):
		if n % d == 0:
			return d
	return 0


func _by_name(problem: Problem, name: String) -> Array:
	for entry: Dictionary in problem.distractors:
		if entry["misconception"] == name:
			return entry["value"]
	return []


func test_every_skill_passes_the_shared_checks() -> void:
	for skill_id: StringName in SKILLS:
		assert_array(GeneratorChecks.run(_catalog.skill(skill_id), N, _allowed)).is_empty()


func test_the_same_seed_gives_the_same_grid() -> void:
	for skill_id: StringName in SKILLS:
		var a: Problem = GeneratorRegistry.make_problem(_catalog.skill(skill_id), 77)
		var b: Problem = GeneratorRegistry.make_problem(_catalog.skill(skill_id), 77)
		assert_dict(a.to_json()).is_equal(b.to_json())


func test_multiples_cross_out_every_multiple_but_the_prime() -> void:
	var seen_p: Dictionary = {}
	for problem: Problem in _problems(&"sieve.mark.multiples_of"):
		var p: int = problem.prompt_params["p"]
		var size: int = problem.prompt_params["size"]
		seen_p[p] = true
		assert_int(size % 10).is_equal(0)
		assert_bool(size >= p * p and size <= 50).is_true()
		var expected: Array = [1]
		var precrossed: Array = [1]
		for n: int in range(2, size + 1):
			var early: bool = not _is_prime(n) and _smallest_factor(n) < p
			if early:
				precrossed.append(n)
			if early or (n != p and n % p == 0):
				expected.append(n)
		assert_bool(Problem.same(problem.answer, expected)).is_true()
		assert_bool(Problem.same(problem.meta["sieve_grid"]["precrossed"], precrossed)).is_true()
		assert_bool(problem.answer.has(p)).is_false()
		assert_bool(_by_name(problem, "crossed_p_itself").has(p)).is_true()
		assert_bool(_by_name(problem, "missed_p_squared").has(p * p)).is_false()
	assert_array(seen_p.keys()).contains_exactly_in_any_order([2, 3, 5])


func test_the_primes_mode_crosses_one_and_every_composite_and_no_prime() -> void:
	for skill_id: StringName in [&"sieve.find.primes_to_50", &"sieve.find.primes_to_100"]:
		var size_wanted: int = 50 if skill_id == &"sieve.find.primes_to_50" else 100
		var qs: Dictionary = {}
		for problem: Problem in _problems(skill_id, 200):
			var q: int = problem.prompt_params["q"]
			qs[q] = true
			assert_int(problem.prompt_params["size"]).is_equal(size_wanted)
			var expected: Array = [1]
			for n: int in range(4, size_wanted + 1):
				if not _is_prime(n):
					expected.append(n)
			assert_bool(Problem.same(problem.answer, expected)).is_true()
			for crossed: int in problem.meta["sieve_grid"]["precrossed"]:
				assert_bool(_smallest_factor(crossed) <= q and not _is_prime(crossed)).is_true()
			assert_bool(_by_name(problem, "one_is_prime").has(1)).is_false()
			var square_board: Array = _by_name(problem, "square_is_prime")
			assert_int(square_board.size()).is_equal(expected.size() - 1)
		assert_int(qs.size()).is_equal(2)


func test_the_grid_meta_is_ten_wide() -> void:
	for skill_id: StringName in SKILLS:
		var problem: Problem = GeneratorRegistry.make_problem(_catalog.skill(skill_id), 3)
		assert_int(problem.meta["sieve_grid"]["cols"]).is_equal(10)
		assert_int(problem.meta["sieve_grid"]["size"]).is_equal(problem.prompt_params["size"])


func test_an_easier_multiples_grid_is_never_bigger() -> void:
	var skill: Skill = _catalog.skill(&"sieve.mark.multiples_of")
	for seed_value: int in range(1, 200):
		var easier: Problem = GeneratorRegistry.make_problem(skill, seed_value, {"difficulty": -2})
		assert_int(easier.prompt_params["size"]).is_less_equal(40)
