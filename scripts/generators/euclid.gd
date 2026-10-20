## The Euclidean algorithm for Zone 11, Cipher Vault (skills euclid.*): to find the GCF of two numbers, lay the
## shorter bar along the longer one as often as it fits; what is left over becomes the new short bar, and the last bar
## that fits exactly is the GCF. Pure: only the passed-in rng is used.
##
## Modes (params.mode):
##   basic     "Use the Euclid machine. What is the GCF of {a} and {b}?" (a above b, a and b up to params.max)
##   count     "Use the Euclid machine on {a} and {b}. How many steps until nothing is left over?"
##   extended  "The GCF of {a} and {b} is {g}. Find x below {m}. {a} × x leaves {g} when divided by {b}." The answer x is
##             the one number from 0 to m - 1 (m = b ÷ g) that works: walking the machine's steps backward finds it.
##
## The named mistakes:
##   stopped_one_step_early  the leftover of the step before the last (the machine did not run to 0);
##   gave_last_quotient      how many times the last bar fit, not the bar;
##   gave_smaller            the shorter number;
##   gave_gcd_instead        (count) the GCF, not the number of steps;
##   off_by_one              one step too many or too few (or x one along);
##   swapped_coeffs          the answer for the other bar (b × x leaves g when divided by a);
##   sign_flip               the minus of the answer: m - x.
class_name EuclidGenerator
extends RefCounted

const PROMPT_GCD: StringName = &"z11.euclid.prompt_gcd"
const PROMPT_COUNT: StringName = &"z11.euclid.prompt_count"
const PROMPT_EXTENDED: StringName = &"z11.euclid.prompt_extended"
## The ladder picture shows at most this many steps.
const MAX_STEPS: int = 8


static func generate(skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Problem:
	return _make(skill, params, rng, true)


## Each step of the machine on (a, b), a >= b: {a, b, q, r} with a = q × b + r, until r is 0. Iterative.
static func steps(a: int, b: int) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var big: int = maxi(a, b)
	var small: int = mini(a, b)
	while small > 0:
		var q: int = floori(float(big) / small)
		var r: int = big - q * small
		rows.append({"a": big, "b": small, "q": q, "r": r})
		big = small
		small = r
	return rows


## [g, x, y] with a × x + b × y = g = the GCF (the machine run backward). Iterative.
static func extended_gcd(a: int, b: int) -> Array[int]:
	var old_r: int = a
	var r: int = b
	var old_x: int = 1
	var x: int = 0
	var old_y: int = 0
	var y: int = 1
	while r != 0:
		var q: int = floori(float(old_r) / r)
		var next_r: int = old_r - q * r
		old_r = r
		r = next_r
		var next_x: int = old_x - q * x
		old_x = x
		x = next_x
		var next_y: int = old_y - q * y
		old_y = y
		y = next_y
	return [old_r, old_x, old_y]


## The one x from 0 to b ÷ g - 1 with a × x leaving g when divided by b (g the GCF of a and b).
static func smallest_x(a: int, b: int) -> int:
	var parts: Array[int] = extended_gcd(a, b)
	var m: int = floori(float(b) / parts[0])
	return posmod(parts[1], m)


## The `euclid` picture: the bars of a and b and the machine's steps written as a = q × b + r, up to `upto` steps
## (-1: all of them, 0: only the two bars).
static func euclid_picture(a: int, b: int, upto: int = -1) -> Dictionary:
	return {"type": "euclid", "a": a, "b": b, "upto": upto}


static func _make(skill: Skill, params: Dictionary, rng: RandomNumberGenerator, with_hints: bool) -> Problem:
	var mode: String = String(params.get("mode", "basic"))
	var problem: Problem = GeneratorKit.new_problem(skill, params, GeneratorKit.pick_representation(skill, params))
	var model: Dictionary
	match mode:
		"basic", "count":
			model = _gcd(problem, skill, params, rng, mode == "count")
		"extended":
			model = _extended(problem, skill, params, rng)
		_:
			push_error("EuclidGenerator: unknown mode '%s'" % mode)
			return problem
	if with_hints:
		var example: Problem = GeneratorKit.make_example(
			func(sub: RandomNumberGenerator) -> Problem: return _make(skill, params, sub, false), problem, rng)
		GeneratorKit.add_hints(problem, model, example, _example_line(mode, example))
	return problem


## A pair a > b >= 2 up to `high`, built as g × u and g × v with u, v sharing nothing, so the GCF is g; the machine
## runs for 2 to MAX_STEPS steps.
static func _pair(low: int, high: int, min_steps: int, rng: RandomNumberGenerator) -> Vector2i:
	var pair: Vector2i = Vector2i(high, low)
	for attempt: int in 80:
		var g: int = rng.randi_range(1, maxi(floori(float(high) / 8.0), 2))
		var v: int = rng.randi_range(2, maxi(floori(float(high) / g) - 1, 2))
		var u: int = rng.randi_range(v + 1, maxi(floori(float(high) / g), v + 1))
		if MathUtil.gcd(u, v) != 1 or g * u > high or g * v < low:
			continue
		pair = Vector2i(g * u, g * v)
		var count: int = steps(pair.x, pair.y).size()
		if count >= min_steps and count <= MAX_STEPS:
			return pair
	return pair


static func _gcd(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator, counting: bool) -> Dictionary:
	var high: int = GeneratorKit.eased_max(20, int(params.get("max", 200)), GeneratorKit.difficulty_of(params), 20)
	var pair: Vector2i = _pair(int(params.get("min", 4)), high, 2 if GeneratorKit.difficulty_of(params) >= 0 else 1, rng)
	var a: int = pair.x
	var b: int = pair.y
	var rows: Array[Dictionary] = steps(a, b)
	var g: int = int(rows.back()["b"])
	problem.prompt_params = {"a": a, "b": b}
	if counting:
		problem.prompt_line_id = PROMPT_COUNT
		problem.answer = rows.size()
		GeneratorKit.add_distractor(problem, skill, rows.size() + 1, &"off_by_one")
		GeneratorKit.add_distractor(problem, skill, rows.size() - 1, &"off_by_one")
		GeneratorKit.add_distractor(problem, skill, g, &"gave_gcd_instead")
	else:
		problem.prompt_line_id = PROMPT_GCD
		problem.answer = g
		GeneratorKit.add_distractor(problem, skill, int(rows.back()["a"]), &"stopped_one_step_early")
		GeneratorKit.add_distractor(problem, skill, int(rows.back()["q"]), &"gave_last_quotient")
		GeneratorKit.add_distractor(problem, skill, b, &"gave_smaller")
	if problem.representation == &"pictorial":
		problem.visual = euclid_picture(a, b, 0)
	return euclid_picture(a, b, -1)


static func _extended(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var high: int = GeneratorKit.eased_max(12, int(params.get("max", 60)), GeneratorKit.difficulty_of(params), 12)
	var a: int = 5
	var b: int = 7
	for attempt: int in 80:
		b = rng.randi_range(5, high)
		a = rng.randi_range(2, high)
		var common: int = MathUtil.gcd(a, b)
		if a != b and floori(float(b) / common) >= 3:
			break
	var parts: Array[int] = extended_gcd(a, b)
	var g: int = parts[0]
	var m: int = floori(float(b) / g)
	var x: int = smallest_x(a, b)
	problem.answer = x
	problem.prompt_line_id = PROMPT_EXTENDED
	problem.prompt_params = {"a": a, "b": b, "g": g, "m": m}
	problem.meta = {"other": smallest_x(b, a)}
	var big: int = maxi(a, b)
	var small: int = mini(a, b)
	if problem.representation == &"pictorial":
		problem.visual = euclid_picture(big, small, -1)
	GeneratorKit.add_distractor(problem, skill, smallest_x(b, a), &"swapped_coeffs")
	GeneratorKit.add_distractor(problem, skill, posmod(m - x, m), &"sign_flip")
	GeneratorKit.add_distractor(problem, skill, x + 1 if x + 1 < m else x - 1, &"off_by_one")
	return euclid_picture(big, small, -1)


static func _example_line(mode: String, example: Problem) -> Dictionary:
	var p: Dictionary = example.prompt_params
	match mode:
		"basic":
			return {"line_id": &"z11.hint.example_gcd", "params": {"a": p["a"], "b": p["b"], "g": example.answer}}
		"count":
			return {"line_id": &"z11.hint.example_count", "params": {"a": p["a"], "b": p["b"], "k": example.answer}}
	return {"line_id": &"z11.hint.example_extended", "params": {"a": p["a"], "x": example.answer, "g": p["g"], "b": p["b"]}}
