## Gauss's sum for Zone 9, Pattern Grotto (skills gauss.sum.*): 1 + 2 + ... + n. Write the row twice,
## once backwards: every column is a pair that makes n + 1, there are n pairs, and that counts every
## number twice, so the sum is n × (n + 1) / 2 (integers only; n × (n + 1) is always even).
##   params.max_n           the largest n (2 up to it, eased by difficulty)
##   params.require_formula true for gauss.sum.formula: n is at least FORMULA_MIN_N, too long to add
##                          one by one, and there is no picture to count (abstract only)
## Pictorial problems show the pairing picture (two rows, one backwards, each column joined).
## Pure: only the passed-in rng is used.
##
## The named mistakes:
##   forgot_halve    made the pairs and did not halve: n × (n + 1);
##   used_n_squared  n × n;
##   off_by_one_n    stopped one number early: 1 + ... + (n - 1).
class_name GaussGenerator
extends RefCounted

## With require_formula, n starts here (a sum the child would not add term by term).
const FORMULA_MIN_N: int = 21
## The pad takes up to four digits for a formula answer (5050 at most), whatever the answer's length.
const FORMULA_PAD_DIGITS: int = 4


static func generate(skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Problem:
	return _make(skill, params, rng, true)


static func _make(skill: Skill, params: Dictionary, rng: RandomNumberGenerator, with_hints: bool) -> Problem:
	var problem: Problem = GeneratorKit.new_problem(skill, params, GeneratorKit.pick_representation(skill, params))
	var formula: bool = bool(params.get("require_formula", false))
	var low: int = FORMULA_MIN_N if formula else 2
	var n: int = rng.randi_range(low, GeneratorKit.eased_max(low, int(params.get("max_n", 20)), GeneratorKit.difficulty_of(params), 4))
	problem.prompt_line_id = &"z9.gauss.prompt_formula" if formula else &"z9.gauss.prompt_pairs"
	problem.prompt_params = {"a": 1, "b": 2, "n": n}
	problem.answer = sum_to(n)
	if formula:
		problem.meta = {"pad_digits": FORMULA_PAD_DIGITS}
	GeneratorKit.add_distractor(problem, skill, n * (n + 1), &"forgot_halve")
	GeneratorKit.add_distractor(problem, skill, n * n, &"used_n_squared")
	GeneratorKit.add_distractor(problem, skill, sum_to(n - 1), &"off_by_one_n")
	if problem.representation == &"pictorial":
		problem.visual = pairing(n)
	if with_hints:
		var example: Problem = GeneratorKit.make_example(
			func(sub: RandomNumberGenerator) -> Problem: return _make(skill, params, sub, false), problem, rng)
		var m: int = example.prompt_params["n"]
		var line: Dictionary = {"line_id": &"z9.hint.example_gauss", "params": {"n": m, "p": m + 1, "d": m * (m + 1), "t": example.answer}}
		GeneratorKit.add_hints(problem, pairing(n), example, line)
	return problem


## 1 + 2 + ... + n, as n × (n + 1) / 2.
static func sum_to(n: int) -> int:
	return floori(n * (n + 1) / 2.0)


## A `pairing` picture: 1 to n on top, n down to 1 below, each column joined and adding to n + 1 (long
## rows are drawn with their first and last columns and a gap between).
static func pairing(n: int) -> Dictionary:
	return {"type": "pairing", "n": n}
