## Fibonacci numbers for Zone 9, Pattern Grotto (skills fib.sequence.* and fib.ratio.converge). The
## sequence starts F(1) = 1, F(2) = 1 and each number is the sum of the two before it (integers only).
## params.mode picks the question:
##   next     F(i) to F(i + 3) are shown: what comes next? F(i + 4), with i + 4 <= params.max_index.
##            Concrete problems use the pattern wall (meta.pattern_wall).
##   missing  F(i) to F(i + 4) with one inside number blank: what is missing?
##   ratio    F(n + 1) ÷ F(n) to the nearest hundredth (n from 3 to params.max_index): the answer is the
##            decimal {mantissa, scale}, rounded half up with integers only (Rational.round_decimal),
##            never through a float. The ratios close in on the golden ratio. The pad takes two places
##            (meta.decimal_places).
## Pure: only the passed-in rng is used.
##
## The named mistakes:
##   added_wrong_pair  added two numbers that are not the two just before (skipped one);
##   doubled_last      doubled the number before the gap;
##   inverted_ratio    divided the smaller number by the bigger one;
##   place_shift       put the decimal point one place too far right (16.2 for 1.62);
##   rounded_down      cut the digits off instead of rounding (only when that differs).
class_name FibGenerator
extends RefCounted

const MISSING_PROMPTS: Array[StringName] = [&"", &"z9.fib.prompt_missing_1", &"z9.fib.prompt_missing_2", &"z9.fib.prompt_missing_3"]
const KEYS: Array[String] = ["a", "b", "c", "d", "e"]
## The golden-rectangle picture shows at most this many squares.
const MAX_SQUARES: int = 8


static func generate(skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Problem:
	return _make(skill, params, rng, true)


static func _make(skill: Skill, params: Dictionary, rng: RandomNumberGenerator, with_hints: bool) -> Problem:
	var problem: Problem = GeneratorKit.new_problem(skill, params, GeneratorKit.pick_representation(skill, params))
	var model: Dictionary = {}
	var example_line: Callable
	match str(params.get("mode", "next")):
		"missing":
			model = _missing(problem, skill, params, rng)
			example_line = _missing_line
		"ratio":
			model = _ratio(problem, skill, params, rng)
			example_line = _ratio_line
		_:
			model = _next(problem, skill, params, rng)
			example_line = _next_line
	if with_hints:
		var example: Problem = GeneratorKit.make_example(
			func(sub: RandomNumberGenerator) -> Problem: return _make(skill, params, sub, false), problem, rng)
		GeneratorKit.add_hints(problem, model, example, example_line.call(example))
	return problem


## F(index) for index >= 1: 1, 1, 2, 3, 5, 8, ...
static func fib(index: int) -> int:
	var before: int = 0
	var now: int = 1
	for step: int in range(1, index):
		var next: int = before + now
		before = now
		now = next
	return now


## F(first) to F(first + count - 1).
static func run(first: int, count: int) -> Array[int]:
	var terms: Array[int] = []
	for index: int in range(first, first + count):
		terms.append(fib(index))
	return terms


## A `fib_squares` picture: squares with these Fibonacci sides fitted into a golden rectangle (at most
## MAX_SQUARES, the last ones).
static func squares(terms: Array[int]) -> Dictionary:
	return {"type": "fib_squares", "terms": terms.slice(maxi(terms.size() - MAX_SQUARES, 0))}


## The first index of a run of five (or `count`) numbers that ends at or below max_index (eased).
static func _first_index(params: Dictionary, rng: RandomNumberGenerator, count: int) -> int:
	var top: int = GeneratorKit.eased_max(count + 2, int(params.get("max_index", 15)), GeneratorKit.difficulty_of(params), 2)
	return rng.randi_range(1, top - count + 1)


static func _next(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var first: int = _first_index(params, rng, 5)
	var terms: Array[int] = run(first, 5)
	problem.prompt_line_id = &"z9.fib.prompt_next"
	for index: int in 4:
		problem.prompt_params[KEYS[index]] = terms[index]
	problem.answer = terms[4]
	GeneratorKit.add_distractor(problem, skill, terms[1] + terms[3], &"added_wrong_pair")
	GeneratorKit.add_distractor(problem, skill, 2 * terms[3], &"doubled_last")
	problem.visual = SequenceGenerator.pattern(terms, [4], SequenceGenerator.style_for(problem))
	if problem.representation == &"concrete":
		SequenceGenerator.add_wall(problem, terms, 4)
	return squares(run(1, first + 3))


static func _next_line(example: Problem) -> Dictionary:
	var p: Dictionary = example.prompt_params
	return {"line_id": &"z9.hint.example_fib_next", "params": {"c": p["c"], "d": p["d"], "e": example.answer}}


static func _missing(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var first: int = _first_index(params, rng, 5)
	var terms: Array[int] = run(first, 5)
	var blank: int = rng.randi_range(1, 3)
	problem.prompt_line_id = MISSING_PROMPTS[blank]
	for index: int in 5:
		if index != blank:
			problem.prompt_params[KEYS[index]] = terms[index]
	problem.answer = terms[blank]
	GeneratorKit.add_distractor(problem, skill, terms[blank - 1] + terms[blank + 1], &"added_wrong_pair")
	GeneratorKit.add_distractor(problem, skill, 2 * terms[blank - 1], &"doubled_last")
	problem.visual = SequenceGenerator.pattern(terms, [blank], "numbers")
	return squares(run(1, first + 4))


static func _missing_line(example: Problem) -> Dictionary:
	return {"line_id": &"z9.hint.example_fib_missing", "params": {"m": example.answer}}


static func _ratio(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var top: int = GeneratorKit.eased_max(5, int(params.get("max_index", 12)), GeneratorKit.difficulty_of(params), 2)
	var n: int = rng.randi_range(3, top)
	var small: int = fib(n)
	var big: int = fib(n + 1)
	problem.prompt_line_id = &"z9.fib.prompt_ratio"
	problem.prompt_params = {"a": small, "b": big}
	var rounded: Dictionary = Rational.round_decimal(big, small, 2)
	problem.answer = Rational.normalize_decimal(int(rounded["mantissa"]), 2)
	problem.meta = {"decimal_places": 2}
	var flipped: Dictionary = Rational.round_decimal(small, big, 2)
	GeneratorKit.add_distractor(problem, skill, Rational.normalize_decimal(int(flipped["mantissa"]), 2), &"inverted_ratio")
	GeneratorKit.add_distractor(problem, skill, Rational.normalize_decimal(int(rounded["mantissa"]), 1), &"place_shift")
	# Cutting off instead of rounding: one hundredth less exactly when the remainder rounded up.
	var cut: int = int(rounded["mantissa"]) - (1 if ((big * 100) % small) * 2 >= small else 0)
	GeneratorKit.add_distractor(problem, skill, Rational.normalize_decimal(cut, 2), &"rounded_down")
	var picture: Dictionary = squares(run(1, n + 1))
	if problem.representation == &"pictorial":
		problem.visual = picture.duplicate(true)
	return picture


static func _ratio_line(example: Problem) -> Dictionary:
	var p: Dictionary = example.prompt_params
	return {"line_id": &"z9.hint.example_ratio", "params": {"a": p["a"], "b": p["b"], "d": example.answer}}
