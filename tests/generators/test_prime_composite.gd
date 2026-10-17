# Mirrors scripts/generators/prime_composite.gd: prime means exactly two factors (found here by trial
# division, never by MathUtil), 1 is never a candidate until prime.explain.factor_pairs, the even prime 2
# and the square and odd composites that fool children all come up, and each wrong answer is the
# named mistake it stands for.
class_name PrimeCompositeGeneratorTest
extends GdUnitTestSuite

const N: int = 2000
const SKILLS: Array[StringName] = [&"prime.classify.single", &"prime.classify.set", &"prime.explain.factor_pairs"]

var _catalog: SkillCatalog
var _allowed: Array[StringName]


func before() -> void:
	_catalog = SkillCatalog.load_all()
	_allowed = SkillCatalog.misconception_names()


func _problems(skill_id: StringName, overrides: Dictionary = {}, count: int = N) -> Array[Problem]:
	return GeneratorChecks.make_all(_catalog.skill(skill_id), count, overrides)


func _factors(n: int) -> Array[int]:
	var found: Array[int] = []
	for d: int in range(1, n + 1):
		if n % d == 0:
			found.append(d)
	return found


func _is_prime(n: int) -> bool:
	return _factors(n).size() == 2


func _is_square(n: int) -> bool:
	for root: int in range(1, n + 1):
		if root * root == n:
			return true
	return false


## The mistake a wrong answer about n stands for (the rule the generator documents).
func _expected_mistake(n: int) -> String:
	if n == 1:
		return "one_is_prime"
	if _is_prime(n):
		return "two_is_not_prime" if n == 2 else "no_check_made"
	if _is_square(n):
		return "square_is_prime"
	return "odd_means_prime" if n % 2 == 1 else "no_check_made"


func _by_name(problem: Problem, name: String) -> Array:
	var values: Array = []
	for entry: Dictionary in problem.distractors:
		if entry["misconception"] == name:
			values.append(entry["value"])
	return values


func test_every_skill_passes_the_shared_checks() -> void:
	for skill_id: StringName in SKILLS:
		var skill: Skill = _catalog.skill(skill_id)
		assert_object(skill).is_not_null()
		var errors: Array[String] = GeneratorChecks.run(skill, 10000, _allowed)
		assert_array(errors).override_failure_message("\n".join(errors)).is_empty()
	# The hardest setting: primes and composites up to 100.
	for skill_id: StringName in [&"prime.classify.single", &"prime.classify.set"]:
		var errors: Array[String] = GeneratorChecks.run(_catalog.skill(skill_id), 3000, _allowed, {"max": 100})
		assert_array(errors).override_failure_message("\n".join(errors)).is_empty()


# --- prime.classify.single -------------------------------------------------------------------


func test_the_answer_is_whether_n_has_exactly_two_factors() -> void:
	var seen: Dictionary = {}
	for problem: Problem in _problems(&"prime.classify.single"):
		var n: int = problem.prompt_params["n"]
		seen[n] = true
		assert_str(problem.prompt_line_id).is_equal("z4.prime.prompt_single")
		assert_int(n).is_between(2, 30) # 1 is never a candidate here
		assert_bool(problem.answer).override_failure_message("is %d prime?" % n).is_equal(_is_prime(n))
		assert_dict(problem.meta["label_lines"]).is_equal({"true": "ui.common.yes", "false": "ui.common.no"})
		assert_array(problem.distractors).has_size(1)
		assert_bool(problem.distractors[0]["value"]).is_equal(not problem.answer)
	assert_int(seen.size()).is_equal(29) # every number from 2 to 30
	assert_bool(seen.has(1)).is_false()


func test_the_range_reaches_100_at_the_hardest_setting() -> void:
	var biggest: int = 0
	var big_prime: bool = false
	for problem: Problem in _problems(&"prime.classify.single", {"max": 100}, 4000):
		var n: int = problem.prompt_params["n"]
		assert_int(n).is_between(2, 100)
		biggest = maxi(biggest, n)
		big_prime = big_prime or (n > 90 and problem.answer)
	assert_int(biggest).is_greater(95)
	assert_bool(big_prime).is_true() # 97


func test_the_wrong_answer_names_the_mistake_that_fits_the_number() -> void:
	var counts: Dictionary = {"two_is_not_prime": 0, "odd_means_prime": 0, "square_is_prime": 0, "no_check_made": 0}
	var primes: int = 0
	var total: int = 0
	for problem: Problem in _problems(&"prime.classify.single", {"max": 100}, 4000):
		var n: int = problem.prompt_params["n"]
		var name: String = String(problem.distractors[0]["misconception"])
		assert_str(name).override_failure_message("n = %d" % n).is_equal(_expected_mistake(n))
		counts[name] += 1
		total += 1
		primes += 1 if problem.answer else 0
	for name: String in counts:
		assert_int(counts[name]).override_failure_message(name + " never came up").is_greater(100)
	assert_float(float(primes) / float(total)).is_between(0.28, 0.5)


func test_two_squares_and_odd_composites_all_come_up_at_the_default_range() -> void:
	var seen: Dictionary = {}
	for problem: Problem in _problems(&"prime.classify.single"):
		seen[problem.prompt_params["n"]] = true
	for n: int in [2, 4, 9, 16, 25, 15, 21, 27, 3, 29]:
		assert_bool(seen.has(n)).override_failure_message("%d never asked" % n).is_true()


func test_the_hint_picture_is_a_rectangle_for_a_composite_and_one_row_for_a_prime() -> void:
	for problem: Problem in _problems(&"prime.classify.single", {}, 600):
		var n: int = problem.prompt_params["n"]
		var model: Dictionary = problem.hint_steps[1]["visual"]
		if problem.answer:
			if n <= 10:
				assert_dict(model).is_equal({"type": "array", "rows": 1, "cols": n})
			else:
				assert_str(model["type"]).is_equal("number_line")
				assert_int(model["jumps"].size()).is_equal(1) # one hop over the whole line
		elif model["type"] == "array":
			assert_int(model["rows"] * model["cols"]).is_equal(n)
			assert_bool(model["rows"] > 1 and model["cols"] > 1).is_true()
		else:
			assert_int(model["max"]).is_equal(n)
			assert_int(model["jumps"].size() * (model["jumps"][0]["to"] - model["jumps"][0]["from"])).is_equal(n)


# --- prime.classify.set ----------------------------------------------------------------------


func test_the_answer_is_exactly_the_primes_among_the_six_rocks() -> void:
	var with_two: int = 0
	for problem: Problem in _problems(&"prime.classify.set"):
		var rocks: Array = problem.meta["tile_board"]["tiles"]
		assert_str(problem.prompt_line_id).is_equal("z4.prime.prompt_set")
		assert_int(rocks.size()).is_equal(6)
		var found: Array[int] = []
		for rock: int in rocks:
			assert_int(rock).is_between(2, 30)
			if _is_prime(rock):
				found.append(rock)
		found.sort()
		assert_array(problem.answer).override_failure_message("rocks %s" % [rocks]).is_equal(found)
		assert_int(problem.prompt_params["k"]).is_equal(found.size())
		var sorted_rocks: Array = rocks.duplicate()
		sorted_rocks.sort()
		for index: int in 6:
			assert_int(problem.prompt_params["r%d" % (index + 1)]).is_equal(sorted_rocks[index])
		assert_int(found.size()).is_between(2, 3)
		assert_int(problem.meta["tile_board"]["slots"]).is_equal(found.size())
		assert_bool(problem.meta["tile_board"]["ordered"]).is_false()
		with_two += 1 if found.has(2) else 0
	assert_int(with_two).is_greater(200)


func test_every_set_has_an_odd_composite_or_a_square_to_trip_over() -> void:
	for problem: Problem in _problems(&"prime.classify.set"):
		var rocks: Array = problem.meta["tile_board"]["tiles"]
		var tricky: bool = false
		for rock: int in rocks:
			tricky = tricky or (not _is_prime(rock) and (rock % 2 == 1 or _is_square(rock)))
		assert_bool(tricky).override_failure_message("%s" % [rocks]).is_true()
		assert_array(problem.distractors).is_not_empty()


func test_each_wrong_board_swaps_in_the_composite_that_fools_children() -> void:
	var counts: Dictionary = {"odd_means_prime": 0, "square_is_prime": 0, "two_is_not_prime": 0}
	for problem: Problem in _problems(&"prime.classify.set", {"max": 100}, 3000):
		var rocks: Array = problem.meta["tile_board"]["tiles"]
		for entry: Dictionary in problem.distractors:
			var board: Array = entry["value"]
			var name: String = String(entry["misconception"])
			counts[name] += 1
			assert_int(board.size()).is_equal(problem.answer.size())
			for rock: int in board:
				assert_bool(rocks.has(rock)).is_true()
			var wrongly_in: Array = board.filter(func(r: int) -> bool: return not _is_prime(r))
			var left_out: Array = problem.answer.filter(func(r: int) -> bool: return not board.has(r))
			assert_int(wrongly_in.size()).is_equal(1)
			assert_int(left_out.size()).is_equal(1)
			match name:
				"odd_means_prime":
					assert_bool(wrongly_in[0] % 2 == 1).is_true()
					assert_int(left_out[0]).is_not_equal(2)
				"square_is_prime":
					assert_bool(_is_square(wrongly_in[0])).is_true()
					assert_int(left_out[0]).is_not_equal(2)
				"two_is_not_prime":
					assert_int(left_out[0]).is_equal(2)
	for name: String in counts:
		assert_int(counts[name]).override_failure_message(name).is_greater(100)


# --- prime.explain.factor_pairs ---------------------------------------------------------------


## The number of pairs of whole numbers that multiply to n, 3 x 4 and 4 x 3 counting once.
func _pairs(n: int) -> int:
	var count: int = 0
	for a: int in range(1, n + 1):
		for b: int in range(a, n + 1):
			if a * b == n:
				count += 1
	return count


func test_counting_pairs_and_telling_primes_from_pairs_both_come_up() -> void:
	var counts: int = 0
	var primes: int = 0
	var seen_one: bool = false
	var seen_two: bool = false
	for problem: Problem in _problems(&"prime.explain.factor_pairs"):
		var n: int = problem.prompt_params["n"]
		if problem.prompt_line_id == &"z4.prime.prompt_pairs_count":
			counts += 1
			assert_int(n).is_between(2, 36)
			assert_int(problem.answer).override_failure_message("pairs of %d" % n).is_equal(_pairs(n))
		else:
			primes += 1
			assert_str(problem.prompt_line_id).is_equal("z4.prime.prompt_pairs_prime")
			assert_int(n).is_between(1, 36)
			assert_bool(problem.answer).override_failure_message("is %d prime?" % n).is_equal(_is_prime(n))
			seen_one = seen_one or n == 1
			seen_two = seen_two or n == 2
	assert_int(counts).is_greater(700)
	assert_int(primes).is_greater(700)
	assert_bool(seen_one).is_true() # "1 is not prime" is taught in this skill
	assert_bool(seen_two).is_true()


func test_wrong_pair_counts_are_the_named_mistakes() -> void:
	for problem: Problem in _problems(&"prime.explain.factor_pairs", {"representation": &"abstract"}):
		if problem.prompt_line_id != &"z4.prime.prompt_pairs_count":
			continue
		var n: int = problem.prompt_params["n"]
		var pairs: int = problem.answer
		assert_array(problem.distractors).is_not_empty()
		for entry: Dictionary in problem.distractors:
			var value: int = entry["value"]
			match String(entry["misconception"]):
				"counted_factors_not_pairs":
					assert_int(value).override_failure_message("n = %d" % n).is_equal(_factors(n).size())
				"missing_one_and_n":
					assert_int(value).is_equal(pairs - 1)
				"off_by_one":
					assert_int(value).is_equal(pairs + 1)
				_:
					fail("unexpected misconception " + String(entry["misconception"]))


func test_wrong_yes_or_no_names_the_mistake_that_fits_the_number() -> void:
	var counts: Dictionary = {}
	for problem: Problem in _problems(&"prime.explain.factor_pairs", {}, 4000):
		if problem.prompt_line_id != &"z4.prime.prompt_pairs_prime":
			continue
		var n: int = problem.prompt_params["n"]
		var name: String = String(problem.distractors[0]["misconception"])
		assert_str(name).override_failure_message("n = %d" % n).is_equal(_expected_mistake(n))
		counts[name] = counts.get(name, 0) + 1
	for name: String in ["one_is_prime", "two_is_not_prime", "odd_means_prime", "square_is_prime", "no_check_made"]:
		assert_int(counts.get(name, 0)).override_failure_message(name + " never came up").is_greater(30)


func test_one_is_explained_in_the_worked_example() -> void:
	var found: bool = false
	for problem: Problem in _problems(&"prime.explain.factor_pairs", {}, 2000):
		var example: Dictionary = problem.hint_steps[2]["example"]
		if example["prompt_params"]["n"] == 1:
			found = true
			assert_str(example["answer_line_id"]).is_equal("z4.prime.one_not_prime")
	assert_bool(found).is_true()


func test_easier_problems_use_smaller_numbers() -> void:
	for problem: Problem in _problems(&"prime.classify.single", {"difficulty": -2}, 800):
		assert_int(problem.prompt_params["n"]).is_less_equal(15)
	for problem: Problem in _problems(&"prime.explain.factor_pairs", {"difficulty": -2}, 800):
		assert_int(problem.prompt_params["n"]).is_less_equal(18)


func test_the_easiest_problems_still_pass_the_shared_checks() -> void:
	for skill_id: StringName in SKILLS:
		var errors: Array[String] = GeneratorChecks.run(_catalog.skill(skill_id), 500, _allowed, {"difficulty": -8})
		assert_array(errors).override_failure_message("\n".join(errors)).is_empty()


func test_the_same_seed_gives_the_same_problem_and_the_global_rng_is_untouched() -> void:
	for skill_id: StringName in SKILLS:
		var skill: Skill = _catalog.skill(skill_id)
		for seed: int in range(1, 100):
			assert_dict(GeneratorRegistry.make_problem(skill, seed).to_json()).is_equal(GeneratorRegistry.make_problem(skill, seed).to_json())
	seed(777)
	var expected: int = randi()
	seed(777)
	_problems(&"prime.classify.set", {}, 200)
	_problems(&"prime.explain.factor_pairs", {}, 200)
	assert_int(randi()).is_equal(expected)
