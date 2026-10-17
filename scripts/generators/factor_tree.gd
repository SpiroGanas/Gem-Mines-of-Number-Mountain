## Prime factorization for Zone 5 (skills pf.*). A number's "prime recipe" is its prime factors,
## repeats included, smallest first: 12 is 2 × 2 × 3. Pure: only the passed-in rng is used.
##
## Modes (params.mode):
##   tree   "Split {n} until every piece is a prime gem." The child builds the factor tree on the
##          FactorTree input (meta.factor_tree = {value}) and presses Done; the answer is the leaves,
##          smallest first. n is composite with at most params.max_factors prime factors.
##   write  "Which is the prime recipe for {n}?" Answer buttons such as "2 × 2 × 3" (meta.array_label
##          "product"). Now and then (params.prime_share percent) n is a prime, whose recipe is n alone.
##   check  "Is {a} × {b} × {c} the prime recipe for {n}?" Yes or no. The candidate (meta.candidate) is
##          the true recipe, a recipe with a composite left in it, or primes whose product is not n.
##
## The named mistakes:
##   stopped_at_composite     two primes multiplied back into one composite piece (12 as 4 × 3);
##   missing_repeated_factor  each prime only once (12 as 2 × 3);
##   one_is_prime             1 written as a prime (12 as 1 × 2 × 2 × 3);
##   product_mismatch         all primes, but the product is not n (12 as 2 × 2 × 5);
##   no_check_made            said no to the true recipe.
class_name FactorTreeGenerator
extends RefCounted

const PROMPT_TREE: StringName = &"z5.tree.prompt"
const PROMPT_WRITE: StringName = &"z5.pf.prompt_write"
## The check prompt for a candidate of 2, 3 or 4 numbers.
const PROMPT_CHECK: Array[StringName] = [&"z5.pf.prompt_check_2", &"z5.pf.prompt_check_3", &"z5.pf.prompt_check_4"]
## The worked-example line for a recipe of 1, 2, 3 or 4 primes.
const RECIPE_LINES: Array[StringName] = [&"z5.hint.example_recipe_1", &"z5.hint.example_recipe_2", &"z5.hint.example_recipe_3", &"z5.hint.example_recipe_4"]
const RECIPE_KEYS: Array[String] = ["a", "b", "c", "d"]
## Arrays draw at most this many rows and columns, hop lines this many hops.
const MAX_SIDE: int = 10


static func generate(skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Problem:
	return _make(skill, params, rng, true)


static func _make(skill: Skill, params: Dictionary, rng: RandomNumberGenerator, with_hints: bool) -> Problem:
	var mode: String = String(params.get("mode", "tree"))
	var problem: Problem = GeneratorKit.new_problem(skill, params, GeneratorKit.pick_representation(skill, params))
	var model: Dictionary
	match mode:
		"tree":
			model = _tree(problem, skill, params, rng)
		"write":
			model = _write(problem, skill, params, rng)
		"check":
			model = _check(problem, skill, params, rng)
		_:
			push_error("FactorTreeGenerator: unknown mode '%s'" % mode)
			return problem
	if with_hints:
		var example: Problem = GeneratorKit.make_example(
			func(sub: RandomNumberGenerator) -> Problem: return _make(skill, params, sub, false), problem, rng)
		GeneratorKit.add_hints(problem, model, example, recipe_line(example.prompt_params["n"]))
	return problem


# --- Shared helpers (FtaGenerator uses them too) -------------------------------------------------


## The composites from params.min to params.max (eased by difficulty) with `least` to
## params.max_factors prime factors, repeats counted.
static func composites_in_range(params: Dictionary, least: int = 2) -> Array[int]:
	var low: int = maxi(int(params.get("min", 4)), 4)
	var high: int = GeneratorKit.eased_max(low, int(params.get("max", 100)), GeneratorKit.difficulty_of(params), 20)
	var most: int = int(params.get("max_factors", 4))
	var found: Array[int] = []
	for n: int in range(low, high + 1):
		var count: int = MathUtil.prime_factorization(n).size()
		if count >= maxi(least, 2) and count <= most:
			found.append(n)
	return found


static func pick(values: Array[int], rng: RandomNumberGenerator) -> int:
	return values[rng.randi_range(0, values.size() - 1)]


## The recipe with its two smallest primes multiplied back together (a composite left in it).
static func with_composite_leaf(recipe: Array[int]) -> Array[int]:
	var result: Array[int] = recipe.slice(2)
	result.append(recipe[0] * recipe[1])
	result.sort()
	return result


## The recipe with its largest prime swapped for the next prime up: all primes, wrong product.
static func with_wrong_prime(recipe: Array[int]) -> Array[int]:
	var result: Array[int] = recipe.duplicate()
	var largest: int = result.pop_back()
	var next: int = largest + 1
	while not MathUtil.is_prime(next):
		next += 1
	result.append(next)
	result.sort()
	return result


## Each prime of the recipe once.
static func without_repeats(recipe: Array[int]) -> Array[int]:
	var result: Array[int] = []
	for prime: int in recipe:
		if not result.has(prime):
			result.append(prime)
	return result


## The rung 2 picture for n: its smallest prime times the rest, as an array or as hops.
static func split_model(n: int) -> Dictionary:
	var smallest: int = MathUtil.prime_factorization(n)[0]
	var rest: int = floori(float(n) / smallest)
	if rest == 1:
		return GeneratorKit.array_picture(1, n) if n <= MAX_SIDE else GeneratorKit.hops_line(1, n)
	if smallest <= MAX_SIDE and rest <= MAX_SIDE:
		return GeneratorKit.array_picture(smallest, rest, true)
	if rest <= MAX_SIDE:
		return GeneratorKit.hops_line(rest, smallest)
	return GeneratorKit.hops_line(smallest, rest)


## "The prime recipe for {n} is {a} × {b} × {c}." for n's recipe (1 to 4 primes).
static func recipe_line(n: int) -> Dictionary:
	var recipe: Array[int] = MathUtil.prime_factorization(n)
	var line_params: Dictionary = {"n": n}
	for index: int in recipe.size():
		line_params[RECIPE_KEYS[index]] = recipe[index]
	return {"line_id": RECIPE_LINES[recipe.size() - 1], "params": line_params}


# --- tree ------------------------------------------------------------------------------------


static func _tree(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var n: int = pick(composites_in_range(params), rng)
	var recipe: Array[int] = MathUtil.prime_factorization(n)
	problem.prompt_line_id = PROMPT_TREE
	problem.prompt_params = {"n": n}
	problem.answer = recipe
	problem.meta = {"factor_tree": {"value": n}}
	GeneratorKit.add_distractor(problem, skill, with_composite_leaf(recipe), &"stopped_at_composite")
	GeneratorKit.add_distractor(problem, skill, without_repeats(recipe), &"missing_repeated_factor")
	return split_model(n)


# --- write -----------------------------------------------------------------------------------


static func _write(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var n: int
	if rng.randi_range(0, 99) < int(params.get("prime_share", 0)):
		var low: int = maxi(int(params.get("min", 4)), 2)
		var high: int = GeneratorKit.eased_max(low, int(params.get("max", 100)), GeneratorKit.difficulty_of(params), 20)
		var primes: Array[int] = []
		for candidate: int in range(low, high + 1):
			if MathUtil.is_prime(candidate):
				primes.append(candidate)
		n = pick(primes, rng)
	else:
		n = pick(composites_in_range(params), rng)
	var recipe: Array[int] = MathUtil.prime_factorization(n)
	problem.prompt_line_id = PROMPT_WRITE
	problem.prompt_params = {"n": n}
	problem.answer = recipe
	problem.meta = {"array_label": "product"}
	if recipe.size() >= 2:
		GeneratorKit.add_distractor(problem, skill, with_composite_leaf(recipe), &"stopped_at_composite")
		GeneratorKit.add_distractor(problem, skill, without_repeats(recipe), &"missing_repeated_factor")
	GeneratorKit.add_distractor(problem, skill, with_wrong_prime(recipe), &"product_mismatch")
	var with_one: Array[int] = [1]
	with_one.append_array(recipe)
	GeneratorKit.add_distractor(problem, skill, with_one, &"one_is_prime")
	var model: Dictionary = split_model(n)
	if problem.representation == &"pictorial":
		problem.visual = model
	return model


# --- check -----------------------------------------------------------------------------------


static func _check(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var n: int = pick(composites_in_range(params), rng)
	var recipe: Array[int] = MathUtil.prime_factorization(n)
	var roll: int = rng.randi_range(0, 99)
	var candidate: Array[int] = recipe
	var mistake: StringName = &"no_check_made"
	if roll >= 50 and roll < 75 and recipe.size() >= 3:
		candidate = with_composite_leaf(recipe)
		mistake = &"stopped_at_composite"
	elif roll >= 50:
		candidate = with_wrong_prime(recipe)
		mistake = &"product_mismatch"
	problem.prompt_line_id = PROMPT_CHECK[candidate.size() - 2]
	problem.prompt_params = {"n": n}
	for index: int in candidate.size():
		problem.prompt_params[RECIPE_KEYS[index]] = candidate[index]
	problem.answer = candidate == recipe
	problem.meta = {"label_lines": GeneratorKit.yes_no_labels(), "candidate": candidate}
	GeneratorKit.add_distractor(problem, skill, not problem.answer, mistake)
	return split_model(n)
