## Place-value problems for Zone 1 (skills pv.tens_ones.*, pv.tens.ten_more_less, pv.hundred.intro):
## build a number from tens and ones, read the number a pile shows, write it as tens plus ones,
## name a digit's value, find ten more or ten less, and build numbers from 100 to 120.
## Pure: only the passed-in rng is used.
class_name PlaceValueGenerator
extends RefCounted


static func generate(skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Problem:
	return _make(skill, params, rng, true)


static func _make(skill: Skill, params: Dictionary, rng: RandomNumberGenerator, with_hints: bool) -> Problem:
	var mode: String = String(params.get("mode", "build"))
	var problem: Problem = GeneratorKit.new_problem(skill, params, GeneratorKit.pick_representation(skill, params))
	var model: Dictionary
	var example_line: Callable
	match mode:
		"build":
			model = _build(problem, skill, params, rng)
			example_line = _tens_ones_line_of
		"read":
			model = _read(problem, skill, params, rng)
			example_line = _tens_ones_of_number_line
		"expanded":
			model = _expanded(problem, skill, params, rng)
			example_line = _expanded_line_of
		"digit_value":
			model = _digit_value(problem, skill, params, rng)
			example_line = _number_line_of
		"ten_more_less":
			model = _ten_more_less(problem, skill, params, rng)
			example_line = _number_line_of
		"build_hundred":
			model = _build_hundred(problem, skill, params, rng)
			example_line = _hundreds_line_of
		_:
			push_error("PlaceValueGenerator: unknown mode '%s'" % mode)
			return problem
	if with_hints:
		var example: Problem = GeneratorKit.make_example(
			func(sub: RandomNumberGenerator) -> Problem: return _make(skill, params, sub, false), problem, rng)
		GeneratorKit.add_hints(problem, model, example, example_line.call(example))
	return problem


static func _number_line_of(example: Problem) -> Dictionary:
	return {"line_id": &"z1.hint.example_number", "params": {"answer": example.answer}}


static func _tens_ones_line_of(example: Problem) -> Dictionary:
	return {"line_id": &"z1.hint.example_tens_ones", "params": {"tens": example.answer["tens"], "ones": example.answer["ones"]}}


## For `read`, the answer is the number itself; state it as tens and ones.
static func _tens_ones_of_number_line(example: Problem) -> Dictionary:
	var n: int = example.answer
	return {"line_id": &"z1.hint.example_tens_ones", "params": {"tens": GeneratorKit.tens_digit(n), "ones": GeneratorKit.ones_digit(n)}}


static func _expanded_line_of(example: Problem) -> Dictionary:
	return {"line_id": &"z1.hint.example_list", "params": {"list": "%d + %d" % [example.answer[0], example.answer[1]]}}


static func _hundreds_line_of(example: Problem) -> Dictionary:
	return {"line_id": &"z1.hint.example_hundreds", "params": {"hundreds": example.answer["hundreds"], "tens": example.answer["tens"], "ones": example.answer["ones"]}}


## Build {n} with ten-bars and one-gems. The answer is {tens, ones}.
static func _build(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var low: int = maxi(int(params.get("min", 11)), 10)
	var high: int = GeneratorKit.eased_max(low, int(params.get("max", 99)), GeneratorKit.difficulty_of(params))
	var n: int = rng.randi_range(low, high)
	var tens: int = GeneratorKit.tens_digit(n)
	var ones: int = GeneratorKit.ones_digit(n)
	problem.prompt_line_id = &"z1.dig.prompt_build_number"
	problem.prompt_params = {"n": n}
	problem.answer = {"tens": tens, "ones": ones}
	problem.meta = {"tools": ["ten", "one"]}
	GeneratorKit.add_distractor(problem, skill, {"tens": ones, "ones": tens}, &"digit_swap")
	GeneratorKit.add_distractor(problem, skill, {"tens": 0, "ones": tens + ones}, &"counted_tens_as_ones")
	return GeneratorKit.gem_piles([GeneratorKit.pile_of(n)])


## How many gems is that? (concrete: piles) or "{tens} tens and {ones} ones" (abstract).
static func _read(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var low: int = maxi(int(params.get("min", 11)), 10)
	var high: int = GeneratorKit.eased_max(low, int(params.get("max", 99)), GeneratorKit.difficulty_of(params))
	var n: int = rng.randi_range(low, high)
	var tens: int = GeneratorKit.tens_digit(n)
	var ones: int = GeneratorKit.ones_digit(n)
	problem.answer = n
	if problem.representation == &"abstract":
		problem.prompt_line_id = &"z1.pv.prompt_read_words"
		problem.prompt_params = {"tens": tens, "ones": ones}
	else:
		problem.prompt_line_id = &"z1.pv.prompt_read_piles"
		problem.visual = GeneratorKit.gem_piles([GeneratorKit.pile_of(n)])
	GeneratorKit.add_distractor(problem, skill, GeneratorKit.swap_digits(n), &"digit_swap")
	GeneratorKit.add_distractor(problem, skill, tens + ones, &"counted_bars_as_ones")
	return GeneratorKit.gem_piles([GeneratorKit.pile_of(n)])


## Which shows {n} as tens plus ones? The answer is [tens * 10, ones], e.g. [30, 4].
static func _expanded(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var low: int = maxi(int(params.get("min", 11)), 10)
	var high: int = GeneratorKit.eased_max(low, int(params.get("max", 99)), GeneratorKit.difficulty_of(params))
	var n: int = rng.randi_range(low, high)
	var tens: int = GeneratorKit.tens_digit(n)
	var ones: int = GeneratorKit.ones_digit(n)
	problem.prompt_line_id = &"z1.pv.prompt_expanded"
	problem.prompt_params = {"n": n}
	problem.meta = {"array_label": "sum"}
	problem.answer = [tens * 10, ones]
	GeneratorKit.add_distractor(problem, skill, [tens, ones], &"digit_value_as_digit")
	GeneratorKit.add_distractor(problem, skill, [ones * 10, tens], &"digit_swap")
	return GeneratorKit.gem_piles([GeneratorKit.pile_of(n)])


## In {n}, what is the value of the {digit}? The two digits differ so "the 3" is never ambiguous,
## and a ones digit of 0 is never asked about.
static func _digit_value(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var low: int = maxi(int(params.get("min", 11)), 10)
	var high: int = GeneratorKit.eased_max(low, int(params.get("max", 99)), GeneratorKit.difficulty_of(params))
	var n: int = rng.randi_range(low, high)
	while GeneratorKit.tens_digit(n) == GeneratorKit.ones_digit(n):
		n = n + 1 if n < high else low # step to the next number; wraps at the top
	var tens: int = GeneratorKit.tens_digit(n)
	var ones: int = GeneratorKit.ones_digit(n)
	var ask_tens: bool = ones == 0 or rng.randi_range(0, 1) == 0
	problem.prompt_line_id = &"z1.pv.prompt_digit_value"
	problem.prompt_params = {"n": n, "digit": tens if ask_tens else ones}
	problem.answer = tens * 10 if ask_tens else ones
	problem.meta = {"place": "tens" if ask_tens else "ones"}
	if ask_tens:
		GeneratorKit.add_distractor(problem, skill, tens, &"digit_value_as_digit")
		GeneratorKit.add_distractor(problem, skill, ones, &"wrong_place")
	else:
		GeneratorKit.add_distractor(problem, skill, tens * 10, &"wrong_place")
	return GeneratorKit.gem_piles([GeneratorKit.pile_of(n)])


## What is ten more (or ten less) than {n}?
static func _ten_more_less(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var low: int = maxi(int(params.get("min", 10)), 10)
	var high: int = GeneratorKit.eased_max(low, int(params.get("max", 110)), GeneratorKit.difficulty_of(params), 10)
	var n: int = rng.randi_range(low, high)
	var more: bool = rng.randi_range(0, 1) == 0
	var answer: int = n + 10 if more else n - 10
	problem.prompt_line_id = &"z1.pv.prompt_ten_more" if more else &"z1.pv.prompt_ten_less"
	problem.prompt_params = {"n": n}
	problem.answer = answer
	problem.visual = GeneratorKit.gem_piles([GeneratorKit.pile_of(n)])
	problem.meta = {"direction": "more" if more else "less"}
	GeneratorKit.add_distractor(problem, skill, n + 1 if more else n - 1, &"changed_ones")
	GeneratorKit.add_distractor(problem, skill, answer + 1, &"off_by_one")
	GeneratorKit.add_distractor(problem, skill, answer - 1, &"off_by_one")
	var window: Vector2i = GeneratorKit.window_around([mini(n, answer), maxi(n, answer)])
	return GeneratorKit.number_line(window.x, window.y, 10, [n], [])


## Build {n} with a hundred-block, ten-bars and one-gems, for n from 100 to 120.
static func _build_hundred(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var low: int = maxi(int(params.get("min", 100)), 100)
	var high: int = GeneratorKit.eased_max(low, int(params.get("max", 120)), GeneratorKit.difficulty_of(params), 2)
	var n: int = rng.randi_range(low, high)
	var hundreds: int = GeneratorKit.hundreds_digit(n)
	var tens: int = GeneratorKit.tens_digit(n)
	var ones: int = GeneratorKit.ones_digit(n)
	problem.prompt_line_id = &"z1.pv.prompt_build_hundred"
	problem.prompt_params = {"n": n}
	problem.answer = {"hundreds": hundreds, "tens": tens, "ones": ones}
	problem.meta = {"tools": ["hundred", "ten", "one"]}
	GeneratorKit.add_distractor(problem, skill, {"hundreds": hundreds, "tens": 0, "ones": tens + ones}, &"counted_tens_as_ones")
	GeneratorKit.add_distractor(problem, skill, {"hundreds": hundreds, "tens": ones, "ones": tens}, &"digit_swap")
	return GeneratorKit.gem_piles([GeneratorKit.pile_of(n)])
