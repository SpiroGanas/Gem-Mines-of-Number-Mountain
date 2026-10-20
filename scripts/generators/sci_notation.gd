## Scientific notation for Zone 8, Power Tower (skills sci.notation.*). At this level the first number
## has exactly one digit after the point and that digit is not 0 (3.4, never 3.0 or 3.45), so every
## number normalizes cleanly. params.mode picks the question:
##   read   a card shows m × 10^e (m = mantissa / 10): write the number the usual way  answer an int,
##          mantissa × 10^(e - 1). e comes from params.exp_range ([2, 6]: at 10¹ the number would
##          have no zeros to place).
##   write  "Write {n} in scientific notation."  answer {mantissa, scale: 1, exp} (Notation), entered
##          on the scientific-notation pad (two boxes: the first number and the power of 10).
## A written answer is judged by its exact form: 34 × 10⁴ is the named mistake mantissa_not_normalized,
## not a right answer (Problem.same_value does not treat {mantissa, scale, exp} as a decimal).
## Pure: only the passed-in rng is used; every value is an exact integer.
##
## The named mistakes:
##   off_by_one_exponent       one place too few (read) or a power one off (write);
##   counted_digits_not_shift  e zeros written after all the digits (3.4 × 10⁵ read as 3400000);
##   mantissa_not_normalized   the first number left at 10 or more (34 × 10⁴).
class_name SciNotationGenerator
extends RefCounted

## The mantissas: 1.1 to 9.9 with a last digit that is not 0, as tenths (11 to 99).
const MIN_MANTISSA: int = 11
const MAX_MANTISSA: int = 99


static func generate(skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Problem:
	return _make(skill, params, rng, true)


## A notation card showing mantissa / 10^scale × 10^exp.
static func sci_card(mantissa: int, scale: int, exp: int) -> Dictionary:
	return {"type": "notation", "form": "sci", "mantissa": mantissa, "scale": scale, "exp": exp}


## The value of m × 10^e for a one-place mantissa (tenths): mantissa × 10^(e - 1). e >= 1.
static func value_of(mantissa: int, exp: int) -> int:
	return mantissa * Notation.power(10, exp - 1)


static func _mantissa(rng: RandomNumberGenerator) -> int:
	var mantissa: int = rng.randi_range(MIN_MANTISSA, MAX_MANTISSA - 1)
	return mantissa + 1 if mantissa % 10 == 0 else mantissa # 20 becomes 21: never a trailing 0


static func _make(skill: Skill, params: Dictionary, rng: RandomNumberGenerator, with_hints: bool) -> Problem:
	var problem: Problem = GeneratorKit.new_problem(skill, params, GeneratorKit.pick_representation(skill, params))
	var model: Dictionary = {}
	if str(params.get("mode", "read")) == "write":
		model = _write(problem, skill, params, rng)
	else:
		model = _read(problem, skill, params, rng)
	if with_hints:
		var example: Problem = GeneratorKit.make_example(
			func(sub: RandomNumberGenerator) -> Problem: return _make(skill, params, sub, false), problem, rng)
		GeneratorKit.add_hints(problem, model, example, example_line(example))
	return problem


static func example_line(example: Problem) -> Dictionary:
	if example.prompt_line_id == &"z8.sci.prompt_write":
		var answer: Dictionary = example.answer
		return {"line_id": &"z8.hint.example_sci_write", "params": {
			"n": example.prompt_params["n"], "m": {"mantissa": int(answer["mantissa"]), "scale": int(answer["scale"])}, "e": int(answer["exp"])}}
	var card: Dictionary = example.visual
	return {"line_id": &"z8.hint.example_sci_read", "params": {
		"m": {"mantissa": int(card["mantissa"]), "scale": int(card["scale"])}, "e": int(card["exp"]), "n": example.answer}}


static func _read(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var span: Array = params.get("exp_range", [2, 6])
	var low: int = maxi(int(span[0]), 2)
	var high: int = GeneratorKit.eased_max(low, int(span[1]), GeneratorKit.difficulty_of(params), 1)
	var exp: int = rng.randi_range(low, high)
	var mantissa: int = _mantissa(rng)
	problem.prompt_line_id = &"z8.sci.prompt_read"
	problem.prompt_params = {}
	problem.answer = value_of(mantissa, exp)
	problem.visual = sci_card(mantissa, 1, exp)
	problem.meta = {"pad_digits": ExponentGenerator.digits_for(value_of(MAX_MANTISSA, int(span[1])))}
	GeneratorKit.add_distractor(problem, skill, value_of(mantissa, exp - 1), &"off_by_one_exponent")
	GeneratorKit.add_distractor(problem, skill, mantissa * Notation.power(10, exp), &"counted_digits_not_shift")
	return sci_card(mantissa, 1, exp)


static func _write(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var max_value: int = GeneratorKit.eased_max(100, int(params.get("max_value", 9000000)), GeneratorKit.difficulty_of(params), 100)
	# The largest exponent whose smallest value (1.1 × 10^e) still fits under max_value.
	var top: int = 1
	while value_of(MIN_MANTISSA, top + 1) <= max_value:
		top += 1
	var exp: int = rng.randi_range(1, top)
	var mantissa: int = _mantissa(rng)
	while value_of(mantissa, exp) > max_value:
		mantissa -= 1 if (mantissa - 1) % 10 != 0 else 2
	var n: int = value_of(mantissa, exp)
	problem.prompt_line_id = &"z8.sci.prompt_write"
	problem.prompt_params = {"n": n}
	problem.answer = Notation.sci(mantissa, 1, exp)
	problem.visual = {}
	problem.meta = {"sci_pad": {"max_exp": top}}
	GeneratorKit.add_distractor(problem, skill, Notation.sci(mantissa, 0, exp - 1), &"mantissa_not_normalized")
	GeneratorKit.add_distractor(problem, skill, Notation.sci(mantissa, 1, exp + 1), &"off_by_one_exponent")
	if exp > 1:
		GeneratorKit.add_distractor(problem, skill, Notation.sci(mantissa, 1, exp - 1), &"off_by_one_exponent")
	return sci_card(mantissa, 1, exp)
