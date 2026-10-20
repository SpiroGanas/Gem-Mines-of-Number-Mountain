## Least common multiple for Zone 6 (skills lcm.*). Pure: only the passed-in rng is used.
##
## Modes (params.mode):
##   common_multiples  "Find the first {k} common multiples of {a} and {b}." Drag tiles into k slots in
##                     any order (answer: the multiples of the LCM, smallest first). Wrong boards start
##                     one multiple late (off_by_one_multiple), hold multiples of a only
##                     (multiples_of_one_number) or of a × b (listed_product_only). At most 8 tiles.
##   lcm               "What is the least common multiple of {a} and {b}?" A number.
##   factorization     "Use the prime recipes. What is the LCM of {a} and {b}?" Composites with at most
##                     params.max_factors primes that share a prime, with an LCM of three digits at most.
##   relation          "GCF × LCM = {a} × {b}. The GCF is {g}. What is the LCM?" The LCM is a × b ÷ g.
##
## Numbers come from params.min to params.max_n (eased by difficulty), a < b. The rung 2 model is the
## two lists of multiples up to the LCM, with the LCM marked (the recipes for factorization, the
## factor lists for relation).
class_name LcmGenerator
extends RefCounted

const PROMPT_COMMON: StringName = &"z6.lcm.prompt_common"
const PROMPT_LCM: StringName = &"z6.lcm.prompt_lcm"
const PROMPT_RECIPES: StringName = &"z6.lcm.prompt_recipes"
const PROMPT_RELATION: StringName = &"z6.lcm.prompt_relation"
const MAX_TILES: int = 8
## The number pad and the slate take at most three digits.
const MAX_ANSWER: int = 999


static func generate(skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Problem:
	return _make(skill, params, rng, true)


static func _make(skill: Skill, params: Dictionary, rng: RandomNumberGenerator, with_hints: bool) -> Problem:
	var mode: String = String(params.get("mode", "lcm"))
	var problem: Problem
	var model: Dictionary
	for attempt: int in GcfGenerator.PROBLEM_TRIES:
		problem = GeneratorKit.new_problem(skill, params, GeneratorKit.pick_representation(skill, params))
		match mode:
			"common_multiples":
				model = _common_multiples(problem, skill, params, rng)
			"lcm":
				model = _lcm(problem, skill, params, rng)
			"factorization":
				model = _factorization(problem, skill, params, rng)
			"relation":
				model = _relation(problem, skill, params, rng)
			_:
				push_error("LcmGenerator: unknown mode '%s'" % mode)
				return problem
		if problem.distractors.size() >= GcfGenerator.MIN_DISTRACTORS:
			break
		if attempt == GcfGenerator.PROBLEM_TRIES - 1:
			push_error("LcmGenerator: %s gave fewer than %d distractors" % [skill.id, GcfGenerator.MIN_DISTRACTORS])
	if with_hints:
		var example: Problem = GeneratorKit.make_example(
			func(sub: RandomNumberGenerator) -> Problem: return _make(skill, params, sub, false), problem, rng)
		GeneratorKit.add_hints(problem, model, example, _example_line(example))
	return problem


## step, 2 × step, ... (count of them), from the `start`-th multiple.
static func multiples_of(step: int, count: int, start: int = 1) -> Array[int]:
	var found: Array[int] = []
	for index: int in range(start, start + count):
		found.append(step * index)
	return found


## Each prime of n's recipe once, multiplied (n's largest square-free factor).
static func distinct_prime_product(n: int) -> int:
	var product: int = 1
	var seen: Array[int] = []
	for prime: int in MathUtil.prime_factorization(n):
		if not seen.has(prime):
			seen.append(prime)
			product *= prime
	return product


# --- common_multiples ----------------------------------------------------------------------------


static func _common_multiples(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var bounds: Vector2i = GcfGenerator.range_of(params, 12, 4)
	var count: int = clampi(int(params.get("count", 3)), 2, 4)
	var pair: Vector2i = GcfGenerator.pick_pair(rng, bounds, func(_a: int, _b: int) -> bool: return true, Vector2i(4, 6))
	var a: int = pair.x
	var b: int = pair.y
	var l: int = MathUtil.lcm(a, b)
	problem.prompt_line_id = PROMPT_COMMON
	problem.prompt_params = {"k": count, "a": a, "b": b}
	problem.answer = multiples_of(l, count)
	_try_add_board(problem, skill, multiples_of(l, count, 2), &"off_by_one_multiple")
	_try_add_board(problem, skill, multiples_of(a, count), &"multiples_of_one_number")
	_try_add_board(problem, skill, multiples_of(a * b, count), &"listed_product_only")
	problem.meta = {"tile_board": {"tiles": GeneratorKit.tile_pool(problem), "slots": count, "ordered": false}}
	match problem.representation:
		&"concrete":
			problem.visual = GearGenerator.gears_picture([a, b])
		&"pictorial":
			problem.visual = GcfGenerator.multiple_lists(a, b, l)
	return GcfGenerator.multiple_lists(a, b, l, [l])


## Adds a wrong board (sorted) unless the tile board would need more than 8 tiles.
static func _try_add_board(problem: Problem, skill: Skill, board: Array[int], misconception: StringName) -> void:
	board.sort()
	if GeneratorKit.pool_size_with(problem, board) <= MAX_TILES:
		GeneratorKit.add_distractor(problem, skill, board, misconception)


# --- lcm -----------------------------------------------------------------------------------------


static func _lcm(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var bounds: Vector2i = GcfGenerator.range_of(params, 15, 4)
	var pair: Vector2i = GcfGenerator.pick_pair(rng, bounds, func(_a: int, _b: int) -> bool: return true, Vector2i(4, 6))
	var a: int = pair.x
	var b: int = pair.y
	var l: int = MathUtil.lcm(a, b)
	problem.prompt_line_id = PROMPT_LCM
	problem.prompt_params = {"a": a, "b": b}
	problem.answer = l
	GeneratorKit.add_distractor(problem, skill, a * b, &"picked_product")
	GeneratorKit.add_distractor(problem, skill, MathUtil.gcd(a, b), &"picked_gcf")
	GeneratorKit.add_distractor(problem, skill, a + b, &"picked_sum")
	if problem.representation == &"pictorial":
		problem.visual = GcfGenerator.multiple_lists(a, b, l)
	return GcfGenerator.multiple_lists(a, b, l, [l])


# --- factorization ---------------------------------------------------------------------------------


static func _factorization(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var bounds: Vector2i = GcfGenerator.range_of(params, 60, 12)
	var most: int = int(params.get("max_factors", 4))
	var accept: Callable = func(a: int, b: int) -> bool:
		return MathUtil.gcd(a, b) > 1 and MathUtil.lcm(a, b) <= MAX_ANSWER and GcfGenerator.composite_with(a, most) and GcfGenerator.composite_with(b, most)
	var pair: Vector2i = GcfGenerator.pick_pair(rng, bounds, accept, Vector2i(12, 18))
	var a: int = pair.x
	var b: int = pair.y
	var l: int = MathUtil.lcm(a, b)
	problem.prompt_line_id = PROMPT_RECIPES
	problem.prompt_params = {"a": a, "b": b}
	problem.answer = l
	GeneratorKit.add_distractor(problem, skill, MathUtil.gcd(a, b), &"took_intersection")
	GeneratorKit.add_distractor(problem, skill, distinct_prime_product(l), &"dropped_highest_power")
	GeneratorKit.add_distractor(problem, skill, a * b, &"picked_product")
	return GcfGenerator.recipe_lists(a, b, "most")


# --- relation ------------------------------------------------------------------------------------


static func _relation(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var bounds: Vector2i = GcfGenerator.range_of(params, 30, 6)
	var pair: Vector2i = GcfGenerator.pick_pair(rng, bounds, func(_a: int, _b: int) -> bool: return true, Vector2i(6, 8))
	var a: int = pair.x
	var b: int = pair.y
	var g: int = MathUtil.gcd(a, b)
	problem.prompt_line_id = PROMPT_RELATION
	problem.prompt_params = {"a": a, "b": b, "g": g}
	problem.answer = MathUtil.lcm(a, b)
	GeneratorKit.add_distractor(problem, skill, a + b - g, &"added_instead_of_multiplied")
	GeneratorKit.add_distractor(problem, skill, a * b, &"picked_product")
	GeneratorKit.add_distractor(problem, skill, g, &"picked_gcf")
	return GcfGenerator.factor_lists(a, b, GcfGenerator.common_factors(a, b))


# --- Worked examples -----------------------------------------------------------------------------


static func _example_line(example: Problem) -> Dictionary:
	var a: int = example.prompt_params["a"]
	var b: int = example.prompt_params["b"]
	var l: int = MathUtil.lcm(a, b)
	match example.prompt_line_id:
		PROMPT_COMMON:
			return {"line_id": &"z6.hint.example_common_multiples", "params": {"a": a, "b": b, "l": l}}
		PROMPT_RECIPES:
			return {"line_id": &"z6.hint.example_recipes_lcm", "params": {"a": a, "b": b, "l": l}}
		PROMPT_RELATION:
			return {"line_id": &"z6.hint.example_relation", "params": {"a": a, "b": b, "p": a * b, "g": MathUtil.gcd(a, b), "l": l}}
	return {"line_id": &"z6.hint.example_lcm", "params": {"a": a, "b": b, "l": l}}
