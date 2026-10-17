## Divisibility rules for Zone 5 (skills div.rule.*): "Is {n} divisible by {d}?" Yes or no. The
## picture is the number's digits with the part the rule looks at lit up (a `digits` visual):
## the last digit for 2, 5 and 10, the last two for 4, the digit sum for 3 and 9, and both the last
## digit and the digit sum for 6. Pictorial problems show it from the start; abstract ones from hint
## rung 2. Pure: only the passed-in rng is used.
##
## About half the answers are yes. A "no" number is often one that trips a named rule mistake (one
## ending in 5 for 10, an even number for 4...). params.prime_share percent of problems ask about a
## prime n (always no), so rare prime gems such as 127 can be dug here.
##
## The named mistakes (the wrong yes or no stands for the first that fits):
##   mixed_up_5_and_10      said yes to 10 for a number ending in 5;
##   last_digit_only_for_3  judged 3 or 9 by the last digit (said yes to 19 for 3, no to 12 for 3);
##   three_means_nine       said yes to 9 for a number that only shares by 3;
##   even_means_div_by_4    said yes to 4 for an even number that does not share by 4;
##   only_one_rule_for_6    said yes to 6 when only one of the rules for 2 and 3 holds;
##   no_check_made          any other wrong yes or no.
class_name DivisibilityGenerator
extends RefCounted

const PROMPT: StringName = &"z5.div.prompt"
## Percent of "no" problems that use a number chosen to trip a rule mistake.
const TRICKY_SHARE: int = 60


static func generate(skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Problem:
	return _make(skill, params, rng, true)


static func _make(skill: Skill, params: Dictionary, rng: RandomNumberGenerator, with_hints: bool) -> Problem:
	var problem: Problem = GeneratorKit.new_problem(skill, params, GeneratorKit.pick_representation(skill, params))
	var divisors: Array[int] = GeneratorKit.ints_of(params.get("divisors", [2, 5, 10]))
	var d: int = divisors[rng.randi_range(0, divisors.size() - 1)]
	var low: int = maxi(int(params.get("min", 10)), d + 1)
	var high: int = GeneratorKit.eased_max(low, int(params.get("max", 200)), GeneratorKit.difficulty_of(params), 20)
	var n: int = _number(d, low, high, int(params.get("prime_share", 0)), rng)
	problem.prompt_line_id = PROMPT
	problem.prompt_params = {"n": n, "d": d}
	problem.answer = n % d == 0
	problem.meta = {"label_lines": GeneratorKit.yes_no_labels()}
	GeneratorKit.add_distractor(problem, skill, not problem.answer, mistake_for(n, d))
	var model: Dictionary = digits_model(n, d)
	if problem.representation == &"pictorial":
		problem.visual = model
	if with_hints:
		var example: Problem = GeneratorKit.make_example(
			func(sub: RandomNumberGenerator) -> Problem: return _make(skill, params, sub, false), problem, rng)
		GeneratorKit.add_hints(problem, model, example, _example_line(example))
	return problem


## The mistake behind the wrong answer about n and d (the opposite of whether d divides n).
static func mistake_for(n: int, d: int) -> StringName:
	var last: int = n % 10
	var divides: bool = n % d == 0
	if divides:
		if (d == 3 or d == 9) and last % d != 0:
			return &"last_digit_only_for_3"
		return &"no_check_made"
	if d == 10 and last == 5:
		return &"mixed_up_5_and_10"
	if (d == 3 or d == 9) and last != 0 and last % d == 0:
		return &"last_digit_only_for_3"
	if d == 9 and n % 3 == 0:
		return &"three_means_nine"
	if d == 4 and n % 2 == 0:
		return &"even_means_div_by_4"
	if d == 6 and (n % 2 == 0) != (n % 3 == 0):
		return &"only_one_rule_for_6"
	return &"no_check_made"


## The digits picture: which part of n the rule for d looks at.
static func digits_model(n: int, d: int) -> Dictionary:
	var digits: Array[int] = []
	for character: String in str(n):
		digits.append(int(character))
	var focus: String = "last"
	match d:
		4:
			focus = "last_two"
		3, 9:
			focus = "sum"
		6:
			focus = "sum_and_last"
	return {"type": "digits", "digits": digits, "focus": focus}


static func _number(d: int, low: int, high: int, prime_share: int, rng: RandomNumberGenerator) -> int:
	if rng.randi_range(0, 99) < prime_share:
		var primes: Array[int] = []
		for n: int in range(low, high + 1):
			if MathUtil.is_prime(n):
				primes.append(n)
		if not primes.is_empty():
			return primes[rng.randi_range(0, primes.size() - 1)]
	if rng.randi_range(0, 1) == 0:
		var first: int = ceili(float(low) / d)
		var last: int = floori(float(high) / d)
		return d * rng.randi_range(first, last)
	var others: Array[int] = []
	var tricky: Array[int] = []
	for n: int in range(low, high + 1):
		if n % d == 0:
			continue
		others.append(n)
		if mistake_for(n, d) != &"no_check_made":
			tricky.append(n)
	if not tricky.is_empty() and rng.randi_range(0, 99) < TRICKY_SHARE:
		return tricky[rng.randi_range(0, tricky.size() - 1)]
	return others[rng.randi_range(0, others.size() - 1)]


static func _example_line(example: Problem) -> Dictionary:
	var n: int = example.prompt_params["n"]
	var d: int = example.prompt_params["d"]
	var quotient: int = floori(float(n) / d)
	if example.answer:
		return {"line_id": &"z5.hint.example_div_yes", "params": {"n": n, "d": d, "q": quotient}}
	return {"line_id": &"z5.hint.example_div_no", "params": {"n": n, "d": d, "q": quotient, "r": n - quotient * d}}
