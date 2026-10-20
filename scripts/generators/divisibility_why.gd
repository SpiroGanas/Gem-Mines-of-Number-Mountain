## Why the divisibility rules work, for Zone 10, Clockwork Depths (skills div.rule.explain_*). The rules of Zone 5 are
## remainder facts: 10 leaves remainder 1 when divided by 3 or 9, so a number leaves the same remainder as its digit
## sum; 10 is a multiple of 2, 5 and 10, so only the last digit counts; 100 is a multiple of 4 and 1,000 of 8, so
## only the last two (or three) digits count. Each problem gives the number and the part of it that decides, and asks
## for the remainder of a ÷ b, which is the remainder of that part. Pure: only the passed-in rng is used.
##
## Modes (params.mode), with params.bases choosing the divisor:
##   digit_sum    bases 3 and 9: "The digits of {a} add up to {s}. What is the remainder of {a} ÷ {b}?"
##   last_digit   bases 2, 5 and 10: only the last digit of a matters.
##   last_digits  bases 4 and 8: the last two digits matter for 4, the last three for 8.
##
## The named mistakes:
##   used_last_digit       the last digit's remainder where the digit sum decides;
##   summed_wrong          the remainder of the digit sum with the last digit left out;
##   used_first_digit      the first digit's remainder where the last digit decides;
##   used_digit_sum        the digit sum's remainder where the end of the number decides;
##   used_last_digit_only  the last digit's remainder where two or three digits decide.
class_name DivisibilityWhyGenerator
extends RefCounted

const PROMPT_DIGIT_SUM: StringName = &"z10.div.prompt_digit_sum"
const PROMPT_LAST_DIGIT: StringName = &"z10.div.prompt_last_digit"
const PROMPT_LAST_DIGITS: StringName = &"z10.div.prompt_last_digits"


static func generate(skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Problem:
	return _make(skill, params, rng, true)


## The digits of a, most significant first.
static func digits_of(a: int) -> Array[int]:
	var digits: Array[int] = []
	for character: String in str(a):
		digits.append(int(character))
	return digits


static func digit_sum(a: int) -> int:
	var total: int = 0
	for digit: int in digits_of(a):
		total += digit
	return total


## The `digits` picture for this mode: the part of a that decides the remainder lit up.
static func digits_model(a: int, mode: String, base: int) -> Dictionary:
	var focus: String = "last"
	match mode:
		"digit_sum":
			focus = "sum"
		"last_digits":
			focus = "last_two" if base == 4 else "last_three"
	return {"type": "digits", "digits": digits_of(a), "focus": focus}


static func _make(skill: Skill, params: Dictionary, rng: RandomNumberGenerator, with_hints: bool) -> Problem:
	var mode: String = String(params.get("mode", "digit_sum"))
	var problem: Problem = GeneratorKit.new_problem(skill, params, GeneratorKit.pick_representation(skill, params))
	var bases: Array[int] = GeneratorKit.ints_of(params.get("bases", [3, 9]))
	var b: int = bases[rng.randi_range(0, bases.size() - 1)]
	var low: int = int(params.get("min_a", 10))
	var high: int = GeneratorKit.eased_max(low, int(params.get("max_a", 999)), GeneratorKit.difficulty_of(params), 20 * b)
	var a: int = rng.randi_range(low, high)
	var digits: Array[int] = digits_of(a)
	var sum: int = digit_sum(a)
	var last: int = digits.back()
	problem.answer = posmod(a, b)
	problem.prompt_params = {"a": a, "b": b}
	match mode:
		"digit_sum":
			problem.prompt_line_id = PROMPT_DIGIT_SUM
			problem.prompt_params["s"] = sum
			GeneratorKit.add_distractor(problem, skill, posmod(last, b), &"used_last_digit")
			GeneratorKit.add_distractor(problem, skill, posmod(sum - last, b), &"summed_wrong")
		"last_digit":
			problem.prompt_line_id = PROMPT_LAST_DIGIT
			GeneratorKit.add_distractor(problem, skill, posmod(digits[0], b), &"used_first_digit")
			GeneratorKit.add_distractor(problem, skill, posmod(sum, b), &"used_digit_sum")
		"last_digits":
			problem.prompt_line_id = PROMPT_LAST_DIGITS
			problem.prompt_params["k"] = 2 if b == 4 else 3
			GeneratorKit.add_distractor(problem, skill, posmod(last, b), &"used_last_digit_only")
			GeneratorKit.add_distractor(problem, skill, posmod(sum, b), &"used_digit_sum")
		_:
			push_error("DivisibilityWhyGenerator: unknown mode '%s'" % mode)
			return problem
	var model: Dictionary = digits_model(a, mode, b)
	if problem.representation == &"pictorial":
		problem.visual = model
	if with_hints:
		var example: Problem = GeneratorKit.make_example(
			func(sub: RandomNumberGenerator) -> Problem: return _make(skill, params, sub, false), problem, rng)
		GeneratorKit.add_hints(problem, model, example, _example_line(mode, example))
	return problem


static func _example_line(mode: String, example: Problem) -> Dictionary:
	var p: Dictionary = example.prompt_params
	match mode:
		"digit_sum":
			return {"line_id": &"z10.hint.example_digit_sum", "params": {"a": p["a"], "s": p["s"], "r": example.answer, "b": p["b"]}}
		"last_digit":
			return {"line_id": &"z10.hint.example_last_digit", "params": {"a": p["a"], "r": example.answer, "b": p["b"]}}
	return {"line_id": &"z10.hint.example_last_digits", "params": {"a": p["a"], "k": p["k"], "r": example.answer, "b": p["b"]}}
