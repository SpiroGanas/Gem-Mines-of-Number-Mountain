## Powers for Zone 8, Power Tower (skills exp.*): what a power means, its value, square and cube
## numbers, the powers of 2 and of 10, and the powers 0 and 1. params.mode picks the question:
##   repeated_mult      "{b} to the power {e}: which multiplication is it?"  answer {op: "mul", terms:
##                      [b, b, ..., b]} picked from answer buttons (Notation's written-out calculation)
##   evaluate           "What is {b} to the power {e}?"  answer b^e (an int), at most max_value
##   square             "What is {n} squared?" or a square array of n by n gems  answer n × n
##   cube               "What is {n} cubed?" or a big cube of n blocks a side  answer n × n × n
##   powers_of_base     params.base 2 or 10. Abstract: "What is {b} to the power {e}?"  answer b^e.
##                      Concrete (base 2): ride the doubling elevator to the floor at {n} meters;
##                      floor k is at 2^k meters, so the answer is the floor k (meta.tower).
##   special_exponents  "What is {b} to the power {e}?" with e = 0 or 1  answer 1 or b
## Every value is exact (Notation.power multiplies integers). The tower floors, square arrays and
## cubes stay small enough to draw: squares as gems up to 10 a side, cubes up to 8 (512 blocks), the
## doubling elevator up to floor 10 (1024 meters). Pure: only the passed-in rng is used.
##
## The named mistakes:
##   multiplied_base_by_exp   3 to the power 4 as 3 × 4;
##   added_base_exp_times     3 + 3 + 3 + 3 for 3 to the power 4;
##   swapped_base_exp         4 to the power 3 for 3 to the power 4 (dropped when equal: 2⁴ = 4²);
##   off_by_one_exponent      one copy too many or too few;
##   doubled / off_by_one_square   2n, or the square of a neighbour, for n squared;
##   tripled / squared_only   3n, or n², for n cubed;
##   added_two                adding 2 instead of doubling (1, 2, 4, 6, 8...): 2^(k-1) + 2;
##   counted_digits_not_zeros 10 to the power k written with k digits (10^(k-1));
##   zero_power_is_zero / first_power_is_one / added_base_and_exp   for b⁰ and b¹.
class_name ExponentGenerator
extends RefCounted

## The largest base and exponent a power_tower picture draws.
const MAX_TOWER_FLOORS: int = 10
const MAX_TOWER_BASE: int = 12
## The largest square drawn as an array of gems (the array picture is at most 10 by 10).
const MAX_ARRAY_SIDE: int = 10
## The largest cube drawn as blocks.
const MAX_CUBE_SIDE: int = 8


static func generate(skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Problem:
	return _make(skill, params, rng, true)


static func _make(skill: Skill, params: Dictionary, rng: RandomNumberGenerator, with_hints: bool) -> Problem:
	var problem: Problem = GeneratorKit.new_problem(skill, params, GeneratorKit.pick_representation(skill, params))
	var model: Dictionary = {}
	var example_line: Callable
	match str(params.get("mode", "evaluate")):
		"repeated_mult":
			model = _repeated(problem, skill, params, rng)
			example_line = _repeated_line
		"evaluate":
			model = _evaluate(problem, skill, params, rng)
			example_line = _value_line
		"square":
			model = _square(problem, skill, params, rng)
			example_line = _square_line
		"cube":
			model = _cube(problem, skill, params, rng)
			example_line = _cube_line
		"powers_of_base":
			model = _powers_of_base(problem, skill, params, rng)
			example_line = _powers_line
		"special_exponents":
			model = _special(problem, skill, params, rng)
			example_line = _special_line
	if with_hints:
		var example: Problem = GeneratorKit.make_example(
			func(sub: RandomNumberGenerator) -> Problem: return _make(skill, params, sub, false), problem, rng)
		GeneratorKit.add_hints(problem, model, example, example_line.call(example))
	return problem


# --- Pictures ----------------------------------------------------------------------------------


## The power tower: the ground floor is 1 and each of `exp` floors multiplies by `base`; with
## `values` each floor shows its height (base, base², ...).
static func tower(base: int, exp: int, values: bool) -> Dictionary:
	return {"type": "power_tower", "base": base, "exp": exp, "values": values}


## A notation card showing base^exp (with "base to the power exp" in words in Explorer mode).
static func power_card(base: int, exp: int) -> Dictionary:
	return {"type": "notation", "form": "power", "base": base, "exp": exp}


static func cube_picture(n: int) -> Dictionary:
	return {"type": "cube_blocks", "n": n}


## How many digits the number pad needs for the largest answer this skill can ask for.
static func digits_for(value: int) -> int:
	return maxi(str(value).length(), 3)


# --- Questions ---------------------------------------------------------------------------------


static func _repeated(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var difficulty: int = GeneratorKit.difficulty_of(params)
	var base: int = rng.randi_range(2, GeneratorKit.eased_max(2, int(params.get("max_base", 5)), difficulty, 1))
	var exp: int = rng.randi_range(2, GeneratorKit.eased_max(2, int(params.get("max_exp", 4)), difficulty, 1))
	problem.prompt_line_id = &"z8.repeat.prompt"
	problem.prompt_params = {"b": base, "e": exp}
	problem.answer = Notation.repeated("mul", base, exp)
	match problem.representation:
		&"concrete":
			problem.visual = tower(base, exp, false)
		&"pictorial":
			problem.visual = tower(base, exp, true)
		_:
			problem.visual = power_card(base, exp)
	GeneratorKit.add_distractor(problem, skill, {"op": "mul", "terms": [base, exp] as Array[int]}, &"multiplied_base_by_exp")
	GeneratorKit.add_distractor(problem, skill, Notation.repeated("add", base, exp), &"added_base_exp_times")
	GeneratorKit.add_distractor(problem, skill, Notation.repeated("mul", exp, base), &"swapped_base_exp")
	GeneratorKit.add_distractor(problem, skill, Notation.repeated("mul", base, exp + 1), &"off_by_one_exponent")
	return tower(base, exp, true)


static func _repeated_line(example: Problem) -> Dictionary:
	return {"line_id": &"z8.hint.example_repeat", "params": example.prompt_params.duplicate()}


static func _evaluate(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var difficulty: int = GeneratorKit.difficulty_of(params)
	var top_base: int = GeneratorKit.eased_max(2, int(params.get("max_base", 6)), difficulty, 1)
	var top_exp: int = GeneratorKit.eased_max(2, int(params.get("max_exp", 4)), difficulty, 1)
	var max_value: int = int(params.get("max_value", 1000))
	var exp: int = rng.randi_range(2, top_exp)
	# The bases whose power stays at or under max_value (2 always does: 2⁴ = 16).
	var bases: Array[int] = []
	for base: int in range(2, top_base + 1):
		if Notation.power(base, exp) <= max_value:
			bases.append(base)
	var base: int = bases[rng.randi_range(0, bases.size() - 1)]
	var value: int = Notation.power(base, exp)
	problem.prompt_params = {"b": base, "e": exp}
	problem.answer = value
	if problem.representation == &"pictorial":
		problem.prompt_line_id = &"z8.evaluate.prompt_tower"
		problem.visual = tower(base, exp, false)
	else:
		problem.prompt_line_id = &"z8.evaluate.prompt"
		problem.visual = power_card(base, exp)
	GeneratorKit.add_distractor(problem, skill, base * exp, &"multiplied_base_by_exp")
	GeneratorKit.add_distractor(problem, skill, Notation.power(base, exp + 1), &"off_by_one_exponent")
	GeneratorKit.add_distractor(problem, skill, Notation.power(base, exp - 1), &"off_by_one_exponent")
	GeneratorKit.add_distractor(problem, skill, Notation.power(exp, base), &"swapped_base_exp")
	return tower(base, exp, true)


static func _value_line(example: Problem) -> Dictionary:
	var p: Dictionary = example.prompt_params
	return {"line_id": &"z8.hint.example_value", "params": {"b": p["b"], "e": p["e"], "v": example.answer}}


static func _square(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var top: int = GeneratorKit.eased_max(2, int(params.get("max_n", 15)), GeneratorKit.difficulty_of(params), 2)
	if problem.representation == &"concrete":
		top = mini(top, MAX_ARRAY_SIDE)
	var n: int = rng.randi_range(2, top)
	problem.prompt_params = {"n": n}
	problem.answer = n * n
	if problem.representation == &"concrete":
		problem.prompt_line_id = &"z8.square.prompt_array"
		problem.visual = GeneratorKit.array_picture(n, n)
	else:
		problem.prompt_line_id = &"z8.square.prompt"
		problem.visual = power_card(n, 2)
	GeneratorKit.add_distractor(problem, skill, 2 * n, &"doubled")
	GeneratorKit.add_distractor(problem, skill, (n + 1) * (n + 1), &"off_by_one_square")
	GeneratorKit.add_distractor(problem, skill, (n - 1) * (n - 1), &"off_by_one_square")
	return GeneratorKit.array_picture(n, n, true) if n <= MAX_ARRAY_SIDE else power_card(n, 2)


static func _square_line(example: Problem) -> Dictionary:
	return {"line_id": &"z8.hint.example_square", "params": {"n": example.prompt_params["n"], "v": example.answer}}


static func _cube(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var top: int = mini(GeneratorKit.eased_max(2, int(params.get("max_n", 8)), GeneratorKit.difficulty_of(params), 2), MAX_CUBE_SIDE)
	var n: int = rng.randi_range(2, top)
	problem.prompt_params = {"n": n}
	problem.answer = n * n * n
	if problem.representation == &"concrete":
		problem.prompt_line_id = &"z8.cube.prompt_blocks"
		problem.visual = cube_picture(n)
	else:
		problem.prompt_line_id = &"z8.cube.prompt"
		problem.visual = power_card(n, 3)
	GeneratorKit.add_distractor(problem, skill, 3 * n, &"tripled")
	GeneratorKit.add_distractor(problem, skill, n * n, &"squared_only")
	return cube_picture(n)


static func _cube_line(example: Problem) -> Dictionary:
	return {"line_id": &"z8.hint.example_cube", "params": {"n": example.prompt_params["n"], "v": example.answer}}


static func _powers_of_base(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var base: int = int(params.get("base", 2))
	var authored_top: int = int(params.get("max_exp", 10))
	var top: int = mini(GeneratorKit.eased_max(1, authored_top, GeneratorKit.difficulty_of(params), 2), MAX_TOWER_FLOORS)
	var exp: int = rng.randi_range(1, top)
	var value: int = Notation.power(base, exp)
	if problem.representation == &"concrete":
		# The doubling elevator: ride to the floor at `value` meters. The answer is the floor (the exponent).
		problem.prompt_line_id = &"z8.two.prompt_ride"
		problem.prompt_params = {"n": value}
		problem.answer = exp
		problem.meta = {"tower": {"base": base, "floors": top, "start": 0}}
		GeneratorKit.add_distractor(problem, skill, exp + 1 if exp < top else exp - 1, &"off_by_one_exponent")
		if exp > 0 and exp < top:
			GeneratorKit.add_distractor(problem, skill, exp - 1, &"off_by_one_exponent")
		return tower(base, exp, true)
	problem.prompt_line_id = &"z8.evaluate.prompt"
	problem.prompt_params = {"b": base, "e": exp}
	problem.answer = value
	problem.visual = power_card(base, exp)
	problem.meta = {"pad_digits": digits_for(Notation.power(base, authored_top))}
	GeneratorKit.add_distractor(problem, skill, Notation.power(base, exp + 1), &"off_by_one_exponent")
	if base == 10:
		GeneratorKit.add_distractor(problem, skill, Notation.power(base, exp - 1), &"counted_digits_not_zeros")
		GeneratorKit.add_distractor(problem, skill, base * exp, &"multiplied_base_by_exp")
	else:
		GeneratorKit.add_distractor(problem, skill, Notation.power(base, exp - 1), &"off_by_one_exponent")
		GeneratorKit.add_distractor(problem, skill, Notation.power(base, exp - 1) + 2, &"added_two")
	return tower(base, exp, true)


static func _powers_line(example: Problem) -> Dictionary:
	if example.prompt_line_id == &"z8.two.prompt_ride":
		return {"line_id": &"z8.hint.example_floor", "params": {"k": example.answer, "n": example.prompt_params["n"]}}
	return _value_line(example)


static func _special(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var base: int = rng.randi_range(2, GeneratorKit.eased_max(2, int(params.get("max_base", 12)), GeneratorKit.difficulty_of(params), 2))
	var exp: int = rng.randi_range(0, 1)
	problem.prompt_line_id = &"z8.evaluate.prompt"
	problem.prompt_params = {"b": base, "e": exp}
	problem.answer = Notation.power(base, exp)
	problem.visual = power_card(base, exp)
	if exp == 0:
		GeneratorKit.add_distractor(problem, skill, 0, &"zero_power_is_zero")
	else:
		GeneratorKit.add_distractor(problem, skill, 1, &"first_power_is_one")
	GeneratorKit.add_distractor(problem, skill, base + exp, &"added_base_and_exp")
	return tower(base, exp, true)


static func _special_line(example: Problem) -> Dictionary:
	var p: Dictionary = example.prompt_params
	if int(p["e"]) == 0:
		return {"line_id": &"z8.hint.example_zero", "params": {"b": p["b"]}}
	return {"line_id": &"z8.hint.example_one", "params": {"b": p["b"]}}
