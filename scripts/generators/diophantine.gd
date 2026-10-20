## Paying exact amounts with two kinds of coin for Zone 11, Cipher Vault (skills dioph.*): a·x + b·y = c, with x and y
## counts of coins (never below 0 in Explorer mode). A total c can be paid with a-coins and b-coins when c is a
## multiple of their GCF and big enough; every multiple of the GCF past (a/g - 1) × (b/g - 1) × g is. Pure: only the
## passed-in rng is used.
##
## Modes (params.mode):
##   solve    "Pay exactly {c} with {a}-coins and {b}-coins. How many of each?" The answer is [x, y] (a-coins, b-coins)
##            and it is the only way: c is below the least common multiple of a and b, so no other counts pay it.
##            Concrete: the coin puzzle (meta.coin_puzzle); abstract: answer buttons.
##   decide   "Can you pay exactly {c} with {a}-coins and {b}-coins?" Yes or no. c is never so small that the coins run out
##            of ways, so the answer is yes exactly when the GCF of a and b divides c.
##
## The named mistakes:
##   swapped_counts         [y, x], the counts the wrong way round;
##   one_coin_too_many      [x + 1, y];
##   one_coin_too_few       [x, y - 1];
##   ignored_gcd_condition  said yes when the GCF does not divide c;
##   doubted_big_total      said no when the GCF divides c.
class_name DiophantineGenerator
extends RefCounted

const PROMPT_SOLVE: StringName = &"z11.dioph.prompt_solve"
const PROMPT_DECIDE: StringName = &"z11.dioph.prompt_decide"
## The coin puzzle holds at most this many coins of each kind.
const MAX_COINS: int = 12
## The coin picture draws totals up to this.
const MAX_TOTAL: int = 250


static func generate(skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Problem:
	return _make(skill, params, rng, true)


## The `coins` picture: a-coins and b-coins and the total c to pay.
static func coins_picture(a: int, b: int, c: int) -> Dictionary:
	return {"type": "coins", "a": a, "b": b, "c": c}


## Every [x, y] with a·x + b·y = c and x, y >= 0, found by trying every x.
static func ways(a: int, b: int, c: int) -> Array[Array]:
	var found: Array[Array] = []
	var x: int = 0
	while a * x <= c:
		var rest: int = c - a * x
		if rest % b == 0:
			found.append([x, floori(float(rest) / b)])
		x += 1
	return found


static func _make(skill: Skill, params: Dictionary, rng: RandomNumberGenerator, with_hints: bool) -> Problem:
	var mode: String = String(params.get("mode", "solve"))
	var problem: Problem = GeneratorKit.new_problem(skill, params, GeneratorKit.pick_representation(skill, params))
	var high: int = GeneratorKit.eased_max(5, int(params.get("max_coin", 12)), GeneratorKit.difficulty_of(params), 3)
	var low: int = int(params.get("min_coin", 2))
	var model: Dictionary
	match mode:
		"solve":
			model = _solve(problem, skill, low, high, rng)
		"decide":
			model = _decide(problem, skill, low, high, rng)
		_:
			push_error("DiophantineGenerator: unknown mode '%s'" % mode)
			return problem
	if with_hints:
		var example: Problem = GeneratorKit.make_example(
			func(sub: RandomNumberGenerator) -> Problem: return _make(skill, params, sub, false), problem, rng)
		GeneratorKit.add_hints(problem, model, example, _example_line(mode, example))
	return problem


## Two different coins from low to high whose sum is below their least common multiple (so a puzzle that uses both
## has one way only), neither a multiple of the other.
static func _coin_pair(low: int, high: int, rng: RandomNumberGenerator) -> Vector2i:
	var pair: Vector2i = Vector2i(2, 3)
	for attempt: int in 80:
		var a: int = rng.randi_range(low, high)
		var b: int = rng.randi_range(low, high)
		if a != b and a + b < MathUtil.lcm(a, b):
			return Vector2i(a, b)
	return pair


static func _solve(problem: Problem, skill: Skill, low: int, high: int, rng: RandomNumberGenerator) -> Dictionary:
	var pair: Vector2i = _coin_pair(low, high, rng)
	var a: int = pair.x
	var b: int = pair.y
	var least: int = MathUtil.lcm(a, b)
	var x: int = 1
	var y: int = 1
	for attempt: int in 80:
		var try_x: int = rng.randi_range(1, MAX_COINS)
		var try_y: int = rng.randi_range(1, MAX_COINS)
		if a * try_x + b * try_y < least and a * try_x + b * try_y <= MAX_TOTAL:
			x = try_x
			y = try_y
			break
	var c: int = a * x + b * y # below the LCM, so no other counts pay it (the answer is the only way)
	problem.answer = [x, y]
	problem.prompt_line_id = PROMPT_SOLVE
	problem.prompt_params = {"a": a, "b": b, "c": c}
	problem.meta = {"array_label": "coins"}
	if problem.representation == &"concrete":
		problem.meta["coin_puzzle"] = {"a": a, "b": b, "c": c, "max": MAX_COINS}
	else:
		problem.visual = coins_picture(a, b, c)
	GeneratorKit.add_distractor(problem, skill, [y, x], &"swapped_counts")
	GeneratorKit.add_distractor(problem, skill, [x + 1, y], &"one_coin_too_many")
	GeneratorKit.add_distractor(problem, skill, [x, y - 1], &"one_coin_too_few")
	return coins_picture(a, b, c)


static func _decide(problem: Problem, skill: Skill, low: int, high: int, rng: RandomNumberGenerator) -> Dictionary:
	var want_yes: bool = rng.randi_range(0, 1) == 0
	var a: int = low
	var b: int = low + 1
	for attempt: int in 80:
		a = rng.randi_range(low, high)
		b = rng.randi_range(low, high)
		if a != b and (want_yes or MathUtil.gcd(a, b) > 1):
			break
	var g: int = MathUtil.gcd(a, b)
	if g == 1:
		want_yes = true # coins with no common factor can pay every total past the bound
	var bound: int = g * (floori(float(a) / g) - 1) * (floori(float(b) / g) - 1) # a multiple of g from here on can be paid
	var c: int = bound + rng.randi_range(1, 40)
	if want_yes:
		c = g * ceili(float(c) / g)
	elif c % g == 0:
		c += 1 + rng.randi_range(0, g - 2) # a total the GCF does not divide (g >= 2 here)
	c = mini(c, MAX_TOTAL)
	problem.answer = c % g == 0
	problem.prompt_line_id = PROMPT_DECIDE
	problem.prompt_params = {"a": a, "b": b, "c": c}
	problem.meta = {"label_lines": GeneratorKit.yes_no_labels(), "bound": bound}
	if problem.representation == &"pictorial":
		problem.visual = coins_picture(a, b, c)
	GeneratorKit.add_distractor(problem, skill, not problem.answer, &"doubted_big_total" if problem.answer else &"ignored_gcd_condition")
	return coins_picture(a, b, c)


static func _example_line(mode: String, example: Problem) -> Dictionary:
	var p: Dictionary = example.prompt_params
	if mode == "solve":
		return {"line_id": &"z11.hint.example_coins", "params": {"a": p["a"], "x": example.answer[0], "b": p["b"], "y": example.answer[1], "c": p["c"]}}
	var g: int = MathUtil.gcd(p["a"], p["b"])
	var line: StringName = &"z11.hint.example_pay_yes" if example.answer else &"z11.hint.example_pay_no"
	return {"line_id": line, "params": {"c": p["c"], "g": g}}
