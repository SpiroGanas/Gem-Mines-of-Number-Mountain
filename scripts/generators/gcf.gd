## Greatest common factor for Zone 6 (skills gcf.*). Pure: only the passed-in rng is used.
##
## Modes (params.mode):
##   common_factors  "Which list shows all the common factors of {a} and {b}?" Answer buttons such as
##                   "1, 2, 4" (the answer is the common factors, smallest first). a < b share a factor
##                   above 1. Wrong lists: one extra factor of only one number (included_non_factor),
##                   the GCF left out (missed_largest), every factor of a (factors_of_one_number).
##   gcf             "What is the greatest common factor of {a} and {b}?" A number. With probability
##                   params.coprime_rate (drawn with rng.randf()) the pair is coprime and the answer 1.
##   factorization   "Use the prime recipes. What is the GCF of {a} and {b}?" Both are composites with at
##                   most params.max_factors primes and share at least one prime. The pictorial problem
##                   shows both prime recipes with the shared primes lit.
##   coprime         "Are {a} and {b} coprime?" Yes or no; about half the pairs are coprime.
##
## Every number is drawn from params.min to params.max_n (eased by difficulty), with a < b. The rung 2
## model is the two factor lists with the common factors marked (the recipes for factorization).
##
## Shared helpers (LcmGenerator, GearGenerator and SimplifyGenerator use them too): pick_pair,
## common_factors, factor_lists, multiple_lists, recipe_lists.
class_name GcfGenerator
extends RefCounted

const PROMPT_COMMON: StringName = &"z6.gcf.prompt_common"
const PROMPT_GCF: StringName = &"z6.gcf.prompt_gcf"
const PROMPT_RECIPES: StringName = &"z6.gcf.prompt_recipes"
const PROMPT_COPRIME: StringName = &"z6.gcf.prompt_coprime"
## A list picture shows at most this many numbers in a row (VisualModel draws them one by one).
const MAX_LIST_ITEMS: int = Problem.MAX_LIST_ITEMS
## Random pairs tried before the fallback pair (the cap is never reached for the authored ranges;
## tests/generators/test_gcf.gd proves it over every seed it makes).
const PAIR_TRIES: int = 400
## Tries at a problem with at least MIN_DISTRACTORS wrong answers (plan, Sprint 29 notes).
const PROBLEM_TRIES: int = 50
const MIN_DISTRACTORS: int = 2


static func generate(skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Problem:
	return _make(skill, params, rng, true)


static func _make(skill: Skill, params: Dictionary, rng: RandomNumberGenerator, with_hints: bool) -> Problem:
	var mode: String = String(params.get("mode", "gcf"))
	var problem: Problem
	var model: Dictionary
	for attempt: int in PROBLEM_TRIES:
		problem = GeneratorKit.new_problem(skill, params, GeneratorKit.pick_representation(skill, params))
		match mode:
			"common_factors":
				model = _common_factors(problem, skill, params, rng)
			"gcf":
				model = _gcf(problem, skill, params, rng)
			"factorization":
				model = _factorization(problem, skill, params, rng)
			"coprime":
				model = _coprime(problem, skill, params, rng)
			_:
				push_error("GcfGenerator: unknown mode '%s'" % mode)
				return problem
		if problem.answer is bool or problem.distractors.size() >= MIN_DISTRACTORS:
			break
		if attempt == PROBLEM_TRIES - 1:
			push_error("GcfGenerator: %s seed gave fewer than %d distractors" % [skill.id, MIN_DISTRACTORS])
	if with_hints:
		var example: Problem = GeneratorKit.make_example(
			func(sub: RandomNumberGenerator) -> Problem: return _make(skill, params, sub, false), problem, rng)
		GeneratorKit.add_hints(problem, model, example, _example_line(example))
	return problem


# --- Shared helpers ------------------------------------------------------------------------------


## The range numbers are drawn from: params.min up to params.max_n eased by difficulty.
static func range_of(params: Dictionary, default_max: int, span: int = 6) -> Vector2i:
	var low: int = int(params.get("min", 2))
	var high: int = GeneratorKit.eased_max(low, int(params.get("max_n", default_max)), GeneratorKit.difficulty_of(params), span)
	return Vector2i(low, high)


## Two numbers low <= a < b <= high that `accept`(a, b) likes, drawn at random; `fallback` if none
## turns up in PAIR_TRIES draws.
static func pick_pair(rng: RandomNumberGenerator, bounds: Vector2i, accept: Callable, fallback: Vector2i) -> Vector2i:
	for attempt: int in PAIR_TRIES:
		var a: int = rng.randi_range(bounds.x, bounds.y - 1)
		var b: int = rng.randi_range(a + 1, bounds.y)
		if accept.call(a, b):
			return Vector2i(a, b)
	push_error("GcfGenerator.pick_pair: no pair in %s; using %s" % [bounds, fallback])
	return fallback


## The factors a and b share, smallest first.
static func common_factors(a: int, b: int) -> Array[int]:
	var shared: Array[int] = []
	for factor: int in MathUtil.factors(a):
		if b % factor == 0:
			shared.append(factor)
	return shared


## A `lists` picture: one row per number (n and its items), `marked` values ringed wherever they show.
static func lists_picture(kind: String, rows: Array[Dictionary], marked: Array[int]) -> Dictionary:
	return {"type": "lists", "kind": kind, "rows": rows, "marked": marked}


## The factor lists of a and b, with `marked` values ringed.
static func factor_lists(a: int, b: int, marked: Array[int] = []) -> Dictionary:
	var rows: Array[Dictionary] = [{"n": a, "items": MathUtil.factors(a)}, {"n": b, "items": MathUtil.factors(b)}]
	return lists_picture("factors", rows, marked)


## The multiples of a and b up to `upto`, with `marked` values ringed.
static func multiple_lists(a: int, b: int, upto: int, marked: Array[int] = []) -> Dictionary:
	var rows: Array[Dictionary] = []
	for n: int in [a, b]:
		var items: Array[int] = []
		var at: int = n
		while at <= upto:
			items.append(at)
			at += n
		rows.append({"n": n, "items": items})
	return lists_picture("multiples", rows, marked)


## The prime recipes of a and b. `lit` "shared": the primes both share are lit (one for one);
## "most": each prime is lit in the row where it shows up most (the LCM's primes).
static func recipe_lists(a: int, b: int, lit: String) -> Dictionary:
	var first: Array[int] = MathUtil.prime_factorization(a)
	var second: Array[int] = MathUtil.prime_factorization(b)
	var lit_first: Array[int] = []
	var lit_second: Array[int] = []
	if lit == "shared":
		var spare: Array[int] = second.duplicate()
		for index: int in first.size():
			var at: int = spare.find(first[index])
			if at >= 0:
				lit_first.append(index)
				spare[at] = 0
		spare = first.duplicate()
		for index: int in second.size():
			var at: int = spare.find(second[index])
			if at >= 0:
				lit_second.append(index)
				spare[at] = 0
	else:
		var both: Array[int] = first.duplicate()
		both.append_array(second)
		for prime: int in _distinct(both):
			var in_first: int = first.count(prime)
			var in_second: int = second.count(prime)
			var target: Array[int] = first if in_first >= in_second else second
			var lit_list: Array[int] = lit_first if in_first >= in_second else lit_second
			for index: int in target.size():
				if target[index] == prime:
					lit_list.append(index)
		lit_first.sort()
		lit_second.sort()
	var rows: Array[Dictionary] = [{"n": a, "items": first, "lit": lit_first}, {"n": b, "items": second, "lit": lit_second}]
	return lists_picture("recipe", rows, [])


static func _distinct(values: Array[int]) -> Array[int]:
	var result: Array[int] = []
	for value: int in values:
		if not result.has(value):
			result.append(value)
	result.sort()
	return result


## The largest prime that divides n (n above 1).
static func largest_prime_factor(n: int) -> int:
	return MathUtil.prime_factorization(n).back()


## True when n is composite with at most `most_primes` prime factors, repeats counted.
static func composite_with(n: int, most_primes: int) -> bool:
	var count: int = MathUtil.prime_factorization(n).size()
	return count >= 2 and count <= most_primes


# --- common_factors ------------------------------------------------------------------------------


static func _common_factors(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var bounds: Vector2i = range_of(params, 50)
	var pair: Vector2i = pick_pair(rng, bounds, func(a: int, b: int) -> bool: return MathUtil.gcd(a, b) > 1 and MathUtil.factors(b).size() <= MAX_LIST_ITEMS, Vector2i(8, 12))
	var a: int = pair.x
	var b: int = pair.y
	var shared: Array[int] = common_factors(a, b)
	problem.prompt_line_id = PROMPT_COMMON
	problem.prompt_params = {"a": a, "b": b}
	problem.answer = shared
	# included_non_factor: a factor of only one of the two joins the list.
	var only_one: Array[int] = []
	var either: Array[int] = MathUtil.factors(a)
	either.append_array(MathUtil.factors(b))
	for factor: int in either:
		if not shared.has(factor) and not only_one.has(factor):
			only_one.append(factor)
	only_one.sort()
	if not only_one.is_empty():
		var extra: Array[int] = shared.duplicate()
		extra.append(only_one[rng.randi_range(0, only_one.size() - 1)])
		extra.sort()
		GeneratorKit.add_distractor(problem, skill, extra, &"included_non_factor")
	var missed: Array[int] = shared.duplicate()
	missed.pop_back()
	GeneratorKit.add_distractor(problem, skill, missed, &"missed_largest")
	GeneratorKit.add_distractor(problem, skill, MathUtil.factors(a), &"factors_of_one_number")
	problem.visual = _picture_for(problem.representation, a, b)
	return factor_lists(a, b, shared)


## The problem's own picture: two gears with a and b teeth (concrete), the factor lists (pictorial),
## nothing (abstract).
static func _picture_for(representation: StringName, a: int, b: int) -> Dictionary:
	match representation:
		&"concrete":
			return GearGenerator.gears_picture([a, b])
		&"pictorial":
			return factor_lists(a, b)
	return {}


# --- gcf -----------------------------------------------------------------------------------------


static func _gcf(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var bounds: Vector2i = range_of(params, 60)
	var coprime: bool = rng.randf() < float(params.get("coprime_rate", 0.2))
	var pair: Vector2i
	if coprime:
		pair = pick_pair(rng, bounds, func(a: int, b: int) -> bool: return MathUtil.gcd(a, b) == 1, Vector2i(8, 9))
	else:
		pair = pick_pair(rng, bounds, func(a: int, b: int) -> bool: return MathUtil.gcd(a, b) > 1, Vector2i(12, 18))
	var a: int = pair.x
	var b: int = pair.y
	var g: int = MathUtil.gcd(a, b)
	var shared: Array[int] = common_factors(a, b)
	problem.prompt_line_id = PROMPT_GCF
	problem.prompt_params = {"a": a, "b": b}
	problem.answer = g
	if shared.size() >= 2:
		GeneratorKit.add_distractor(problem, skill, shared[1], &"picked_smallest_common")
	if g > 1:
		GeneratorKit.add_distractor(problem, skill, largest_prime_factor(g), &"picked_prime_factor_only")
	GeneratorKit.add_distractor(problem, skill, MathUtil.lcm(a, b), &"picked_lcm")
	if b % a != 0:
		GeneratorKit.add_distractor(problem, skill, a, &"picked_smaller_number")
	if problem.representation == &"pictorial" and MathUtil.factors(b).size() <= MAX_LIST_ITEMS:
		problem.visual = factor_lists(a, b)
	return factor_lists(a, b, shared)


# --- factorization ---------------------------------------------------------------------------------


static func _factorization(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var bounds: Vector2i = range_of(params, 120, 20)
	var most: int = int(params.get("max_factors", 4))
	var accept: Callable = func(a: int, b: int) -> bool: return MathUtil.gcd(a, b) > 1 and composite_with(a, most) and composite_with(b, most)
	var pair: Vector2i = pick_pair(rng, bounds, accept, Vector2i(12, 18))
	var a: int = pair.x
	var b: int = pair.y
	var g: int = MathUtil.gcd(a, b)
	problem.prompt_line_id = PROMPT_RECIPES
	problem.prompt_params = {"a": a, "b": b}
	problem.answer = g
	GeneratorKit.add_distractor(problem, skill, MathUtil.lcm(a, b), &"took_union")
	GeneratorKit.add_distractor(problem, skill, largest_prime_factor(g), &"picked_prime_factor_only")
	GeneratorKit.add_distractor(problem, skill, a * b, &"multiplied_all_primes")
	var recipes: Dictionary = recipe_lists(a, b, "shared")
	if problem.representation == &"pictorial":
		problem.visual = recipes
	return recipes


# --- coprime ---------------------------------------------------------------------------------------


static func _coprime(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var bounds: Vector2i = range_of(params, 40)
	var want_coprime: bool = rng.randi_range(0, 1) == 0
	var pair: Vector2i = pick_pair(rng, bounds, func(a: int, b: int) -> bool: return (MathUtil.gcd(a, b) == 1) == want_coprime, Vector2i(8, 9) if want_coprime else Vector2i(9, 15))
	var a: int = pair.x
	var b: int = pair.y
	var coprime: bool = MathUtil.gcd(a, b) == 1
	problem.prompt_line_id = PROMPT_COPRIME
	problem.prompt_params = {"a": a, "b": b}
	problem.answer = coprime
	problem.meta = {"label_lines": GeneratorKit.yes_no_labels()}
	var mistake: StringName
	if coprime:
		mistake = &"assumed_common_factor" if MathUtil.is_prime(a) and MathUtil.is_prime(b) else &"assumed_primes_only"
	else:
		mistake = &"shared_even_only" if a % 2 == 1 and b % 2 == 1 else &"missed_common_factor"
	GeneratorKit.add_distractor(problem, skill, not coprime, mistake)
	return factor_lists(a, b, common_factors(a, b))


# --- Worked examples -----------------------------------------------------------------------------


static func _example_line(example: Problem) -> Dictionary:
	var a: int = example.prompt_params["a"]
	var b: int = example.prompt_params["b"]
	var g: int = MathUtil.gcd(a, b)
	match example.prompt_line_id:
		PROMPT_COMMON:
			return {"line_id": &"z6.hint.example_common", "params": {"g": g}}
		PROMPT_RECIPES:
			return {"line_id": &"z6.hint.example_recipes_gcf", "params": {"a": a, "b": b, "g": g}}
		PROMPT_COPRIME:
			if g == 1:
				return {"line_id": &"z6.hint.example_coprime_yes", "params": {"a": a, "b": b}}
			return {"line_id": &"z6.hint.example_coprime_no", "params": {"a": a, "b": b, "g": g}}
	return {"line_id": &"z6.hint.example_gcf", "params": {"a": a, "b": b, "g": g}}
