## Simplest form for Zone 6 (skills simplify.*): divide both numbers by their greatest common factor.
## Pure: only the passed-in rng is used.
##
## Answers use the Phase 4 canonical shapes (plan, "Shared data representation"): a fraction is
## {num, den} in lowest terms with a positive denominator (Rational.normalize), a ratio is {a, b} in
## lowest terms with the order kept. The child picks from answer buttons ("3/4", "2 : 3").
##
## Modes (params.mode):
##   fraction  "Write {a}/{b} in simplest form." b from params.min_den to params.max_den (eased by
##             difficulty), 0 < a < b, and a and b share a factor above 1. The pictorial problem shows a
##             gear with b teeth and a of them shaded.
##   ratio     "Write {a} : {b} in simplest form." a and b from params.min_term to params.max_term, not
##             equal, sharing a factor above 1. The concrete problem shows two gears with a and b teeth.
##
## The named mistakes: dividing by a common factor that is not the greatest (partially_simplified,
## only when the GCF has one), dividing the top number or the first number only
## (divided_numerator_only, divided_one_term_only), and writing the answer back to front
## (swapped_num_den, inverted_ratio). Wrong answers are what the child would write, so they need not be
## in lowest terms.
class_name SimplifyGenerator
extends RefCounted

const PROMPT_FRACTION: StringName = &"z6.simplify.prompt_fraction"
const PROMPT_RATIO: StringName = &"z6.simplify.prompt_ratio"


static func generate(skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Problem:
	return _make(skill, params, rng, true)


static func _make(skill: Skill, params: Dictionary, rng: RandomNumberGenerator, with_hints: bool) -> Problem:
	var mode: String = String(params.get("mode", "fraction"))
	var problem: Problem = GeneratorKit.new_problem(skill, params, GeneratorKit.pick_representation(skill, params))
	var model: Dictionary
	match mode:
		"fraction":
			model = _fraction(problem, skill, params, rng)
		"ratio":
			model = _ratio(problem, skill, params, rng)
		_:
			push_error("SimplifyGenerator: unknown mode '%s'" % mode)
			return problem
	if with_hints:
		var example: Problem = GeneratorKit.make_example(
			func(sub: RandomNumberGenerator) -> Problem: return _make(skill, params, sub, false), problem, rng)
		GeneratorKit.add_hints(problem, model, example, _example_line(example))
	return problem


## The largest common factor of a and b that is above 1 and below their GCF, or 0 if the GCF is prime.
static func partial_divisor(a: int, b: int) -> int:
	var g: int = MathUtil.gcd(a, b)
	var best: int = 0
	for factor: int in MathUtil.factors(g):
		if factor > 1 and factor < g:
			best = factor
	return best


static func _exact_div(a: int, b: int) -> int:
	return floori(float(a) / float(b))


# --- fraction ------------------------------------------------------------------------------------


static func _fraction(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var low: int = maxi(int(params.get("min_den", 4)), 4)
	var high: int = GeneratorKit.eased_max(low, int(params.get("max_den", 48)), GeneratorKit.difficulty_of(params), 8)
	var num: int = 2
	var den: int = 4
	for attempt: int in GcfGenerator.PAIR_TRIES:
		var b: int = rng.randi_range(low, high)
		var a: int = rng.randi_range(1, b - 1)
		if MathUtil.gcd(a, b) > 1:
			num = a
			den = b
			break
	var g: int = MathUtil.gcd(num, den)
	problem.prompt_line_id = PROMPT_FRACTION
	problem.prompt_params = {"a": num, "b": den}
	problem.answer = Rational.normalize(num, den)
	var part: int = partial_divisor(num, den)
	if part > 0:
		GeneratorKit.add_distractor(problem, skill, {"num": _exact_div(num, part), "den": _exact_div(den, part)}, &"partially_simplified")
	GeneratorKit.add_distractor(problem, skill, {"num": _exact_div(num, g), "den": den}, &"divided_numerator_only")
	GeneratorKit.add_distractor(problem, skill, {"num": _exact_div(den, g), "den": _exact_div(num, g)}, &"swapped_num_den")
	if problem.representation == &"pictorial":
		problem.visual = GearGenerator.gears_picture([den], num)
	return GcfGenerator.factor_lists(num, den, GcfGenerator.common_factors(num, den))


# --- ratio ---------------------------------------------------------------------------------------


static func _ratio(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var low: int = maxi(int(params.get("min_term", 2)), 2)
	var high: int = GeneratorKit.eased_max(low, int(params.get("max_term", 48)), GeneratorKit.difficulty_of(params), 8)
	var first: int = 4
	var second: int = 6
	for attempt: int in GcfGenerator.PAIR_TRIES:
		var x: int = rng.randi_range(low, high)
		var y: int = rng.randi_range(low, high)
		if x != y and MathUtil.gcd(x, y) > 1:
			first = x
			second = y
			break
	var g: int = MathUtil.gcd(first, second)
	problem.prompt_line_id = PROMPT_RATIO
	problem.prompt_params = {"a": first, "b": second}
	problem.answer = {"a": _exact_div(first, g), "b": _exact_div(second, g)}
	var part: int = partial_divisor(first, second)
	if part > 0:
		GeneratorKit.add_distractor(problem, skill, {"a": _exact_div(first, part), "b": _exact_div(second, part)}, &"partially_simplified")
	GeneratorKit.add_distractor(problem, skill, {"a": _exact_div(second, g), "b": _exact_div(first, g)}, &"inverted_ratio")
	GeneratorKit.add_distractor(problem, skill, {"a": _exact_div(first, g), "b": second}, &"divided_one_term_only")
	if problem.representation == &"concrete":
		problem.visual = GearGenerator.gears_picture([first, second])
	var small: int = mini(first, second)
	var large: int = maxi(first, second)
	return GcfGenerator.factor_lists(small, large, GcfGenerator.common_factors(small, large))


# --- Worked examples -----------------------------------------------------------------------------


static func _example_line(example: Problem) -> Dictionary:
	var a: int = example.prompt_params["a"]
	var b: int = example.prompt_params["b"]
	var g: int = MathUtil.gcd(a, b)
	var line: StringName = &"z6.hint.example_fraction" if example.prompt_line_id == PROMPT_FRACTION else &"z6.hint.example_ratio_simplify"
	return {"line_id": line, "params": {"g": g, "a": a, "b": b, "c": _exact_div(a, g), "d": _exact_div(b, g)}}
