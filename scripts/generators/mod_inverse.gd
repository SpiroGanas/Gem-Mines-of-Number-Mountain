## Multiplying undo partners for Zone 11, Cipher Vault (skills modinv.*): on a loop of n stations, a number a has a
## multiplying undo partner (a modular inverse) x when a × x lands on 1. It exists exactly when a and n share no
## factor but 1, which is why only some rows of a multiplying table have a 1 in them. Pure: only the passed-in rng is
## used.
##
## Modes (params.mode):
##   exists  "On a loop of {n}, can {a} × x land on 1?" Yes or no. Pictorial: the multiplying table with row a lit.
##   find    "On a loop of {n}, {a} × x lands on 1. What is x?" a has a partner; x is the partner.
##
## The named mistakes:
##   thought_always_exists  said yes when a and n share a factor;
##   used_gcd_not_inverse   said no because the GCF is 1 (or answered with the GCF, 1);
##   gave_additive_inverse  n - a, the partner for adding;
##   off_by_one             the partner one number along.
class_name ModInverseGenerator
extends RefCounted

const PROMPT_EXISTS: StringName = &"z11.modinv.prompt_exists"
const PROMPT_FIND: StringName = &"z11.modinv.prompt_find"
## The table picture draws loops up to this size (Problem's cayley picture).
const MAX_N: int = 12


static func generate(skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Problem:
	return _make(skill, params, rng, true)


static func _make(skill: Skill, params: Dictionary, rng: RandomNumberGenerator, with_hints: bool) -> Problem:
	var mode: String = String(params.get("mode", "find"))
	var problem: Problem = GeneratorKit.new_problem(skill, params, GeneratorKit.pick_representation(skill, params))
	var low: int = maxi(int(params.get("min_n", 3)), 3)
	var high: int = GeneratorKit.eased_max(low, mini(int(params.get("max_n", MAX_N)), MAX_N), GeneratorKit.difficulty_of(params), 3)
	var model: Dictionary
	match mode:
		"exists":
			model = _exists(problem, skill, rng, low, high)
		"find":
			model = _find(problem, skill, rng, low, high)
		_:
			push_error("ModInverseGenerator: unknown mode '%s'" % mode)
			return problem
	if with_hints:
		var example: Problem = GeneratorKit.make_example(
			func(sub: RandomNumberGenerator) -> Problem: return _make(skill, params, sub, false), problem, rng)
		GeneratorKit.add_hints(problem, model, example, _example_line(mode, example))
	return problem


## The undo partner of a on the loop of n (1 to n - 1), or 0 when there is none; found by trying every number.
static func partner(a: int, n: int) -> int:
	for x: int in range(1, n):
		if posmod(a * x, n) == 1:
			return x
	return 0


static func _exists(problem: Problem, skill: Skill, rng: RandomNumberGenerator, low: int, high: int) -> Dictionary:
	var yes: bool = rng.randi_range(0, 1) == 0
	var pairs: Array[Vector2i] = []
	for n: int in range(low, high + 1):
		for a: int in range(2, n):
			if (MathUtil.gcd(a, n) == 1) == yes:
				pairs.append(Vector2i(a, n))
	if pairs.is_empty():
		yes = true # a range of primes only: every row has a 1
		for n: int in range(low, high + 1):
			for a: int in range(2, n):
				pairs.append(Vector2i(a, n))
	var chosen: Vector2i = pairs[rng.randi_range(0, pairs.size() - 1)]
	var a: int = chosen.x
	var n: int = chosen.y
	problem.answer = partner(a, n) > 0
	problem.prompt_line_id = PROMPT_EXISTS
	problem.prompt_params = {"a": a, "n": n}
	problem.meta = {"label_lines": GeneratorKit.yes_no_labels()}
	if problem.representation == &"pictorial":
		problem.visual = GroupGenerator.cayley_picture(n, &"mul", true, [], [], "", a)
	GeneratorKit.add_distractor(problem, skill, not problem.answer, &"used_gcd_not_inverse" if problem.answer else &"thought_always_exists")
	return GroupGenerator.cayley_picture(n, &"mul", true, [], [], "", a)


static func _find(problem: Problem, skill: Skill, rng: RandomNumberGenerator, low: int, high: int) -> Dictionary:
	var pairs: Array[Vector2i] = []
	for n: int in range(low, high + 1):
		for a: int in range(2, n):
			if MathUtil.gcd(a, n) == 1:
				pairs.append(Vector2i(a, n))
	var chosen: Vector2i = pairs[rng.randi_range(0, pairs.size() - 1)]
	var a: int = chosen.x
	var n: int = chosen.y
	var x: int = partner(a, n)
	problem.answer = x
	problem.prompt_line_id = PROMPT_FIND
	problem.prompt_params = {"a": a, "n": n}
	if problem.representation == &"pictorial":
		problem.visual = GroupGenerator.cayley_picture(n, &"mul", true, [], [], "", a)
	GeneratorKit.add_distractor(problem, skill, n - a, &"gave_additive_inverse")
	GeneratorKit.add_distractor(problem, skill, 1, &"used_gcd_not_inverse")
	GeneratorKit.add_distractor(problem, skill, x + 1 if x + 1 < n else x - 1, &"off_by_one")
	return GroupGenerator.cayley_picture(n, &"mul", true, [], [], "", a)


static func _example_line(mode: String, example: Problem) -> Dictionary:
	var p: Dictionary = example.prompt_params
	if mode == "exists":
		var line: StringName = &"z11.hint.example_modinv_yes" if example.answer else &"z11.hint.example_modinv_no"
		return {"line_id": line, "params": {"a": p["a"], "n": p["n"], "g": MathUtil.gcd(p["a"], p["n"])}}
	return {"line_id": &"z11.hint.example_modinv_find", "params": {"a": p["a"], "x": example.answer, "t": p["a"] * example.answer, "n": p["n"]}}
