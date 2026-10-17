## Counting problems for Zone 1 (skills count.*): count objects, read a number line, say what
## comes next, find the number between, fill a number strip, write a numeral.
## Modes come from the skill's params.mode. Pure: only the passed-in rng is used.
class_name CountingGenerator
extends RefCounted


static func generate(skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Problem:
	return _make(skill, params, rng, true)


static func _make(skill: Skill, params: Dictionary, rng: RandomNumberGenerator, with_hints: bool) -> Problem:
	var mode: String = String(params.get("mode", "objects"))
	var problem: Problem = GeneratorKit.new_problem(skill, params, GeneratorKit.pick_representation(skill, params))
	var model: Dictionary
	var example_line: Callable
	match mode:
		"objects":
			model = _objects(problem, skill, params, rng)
			example_line = _number_line_of
		"read":
			model = _read(problem, skill, params, rng)
			example_line = _number_line_of
		"next":
			model = _next(problem, skill, params, rng)
			example_line = _number_line_of
		"between":
			model = _between(problem, skill, params, rng)
			example_line = _number_line_of
		"strip":
			model = _strip(problem, skill, params, rng)
			example_line = _list_line_of
		"write":
			model = _write(problem, skill, params, rng)
			example_line = _number_line_of
		_:
			push_error("CountingGenerator: unknown mode '%s'" % mode)
			return problem
	if with_hints:
		var example: Problem = GeneratorKit.make_example(
			func(sub: RandomNumberGenerator) -> Problem: return _make(skill, params, sub, false), problem, rng)
		GeneratorKit.add_hints(problem, model, example, example_line.call(example))
	return problem


static func _number_line_of(example: Problem) -> Dictionary:
	return {"line_id": &"z1.hint.example_number", "params": {"answer": example.answer}}


static func _list_line_of(example: Problem) -> Dictionary:
	var parts: PackedStringArray = PackedStringArray()
	for value: int in example.answer:
		parts.append(str(value))
	return {"line_id": &"z1.hint.example_list", "params": {"list": ", ".join(parts)}}


## How many gems? (concrete). Answer is the count.
static func _objects(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var low: int = int(params.get("min", 1))
	var high: int = GeneratorKit.eased_max(low, int(params.get("max", 20)), GeneratorKit.difficulty_of(params))
	var n: int = rng.randi_range(low, high)
	problem.prompt_line_id = &"z1.count.prompt_objects"
	problem.answer = n
	problem.visual = GeneratorKit.gem_piles([GeneratorKit.pile(0, 0, n)])
	GeneratorKit.add_distractor(problem, skill, n - 1, &"off_by_one")
	GeneratorKit.add_distractor(problem, skill, n + 1, &"off_by_one")
	GeneratorKit.add_distractor(problem, skill, n + rng.randi_range(2, 3), &"double_counted")
	return GeneratorKit.ten_frame(n, 1 if n <= 10 else 2)


## Which number is the arrow on? A number line with the marker at n (pictorial).
static func _read(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var low: int = int(params.get("min", 21))
	var high: int = GeneratorKit.eased_max(low, int(params.get("max", 120)), GeneratorKit.difficulty_of(params))
	var n: int = rng.randi_range(low, high)
	var start: int = clampi(floori(n / 10.0) * 10 - 10, 0, 90)
	problem.prompt_line_id = &"z1.count.prompt_read_line"
	problem.answer = n
	problem.visual = GeneratorKit.number_line(start, start + 30, 10, [n], [])
	GeneratorKit.add_distractor(problem, skill, GeneratorKit.swap_digits(n), &"digit_swap")
	GeneratorKit.add_distractor(problem, skill, n - 1, &"off_by_one")
	GeneratorKit.add_distractor(problem, skill, n + 1, &"off_by_one")
	return GeneratorKit.number_line(start, start + 30, 5, [n], [])


## "{a}, {b}, ... What comes next?" with b = a + 1; the answer is b + 1 (abstract).
static func _next(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var low: int = maxi(int(params.get("min", 1)), 2)
	var high: int = GeneratorKit.eased_max(low, mini(int(params.get("max", 119)), 119), GeneratorKit.difficulty_of(params))
	var b: int = rng.randi_range(low, high)
	var answer: int = b + 1
	problem.prompt_line_id = &"z1.count.prompt_next"
	problem.prompt_params = {"a": b - 1, "b": b}
	problem.answer = answer
	GeneratorKit.add_distractor(problem, skill, answer - 1, &"off_by_one")
	GeneratorKit.add_distractor(problem, skill, answer + 1, &"off_by_one")
	# Crossing a decade (39 to 40) is where "30" tempts; otherwise jumping a whole ten tempts.
	var decade: int = answer - 10 if (b % 10 == 9 and answer - 10 >= 1) else answer + 10
	GeneratorKit.add_distractor(problem, skill, decade, &"decade_skip")
	var window: Vector2i = GeneratorKit.window_around([b - 1, answer])
	return GeneratorKit.number_line(window.x, window.y, 10, [b - 1, b], [])


## "What number is between {a} and {b}?" with b = a + 2 (abstract).
static func _between(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var low: int = int(params.get("min", 1))
	var high: int = GeneratorKit.eased_max(low + 2, int(params.get("max", 120)), GeneratorKit.difficulty_of(params))
	var a: int = rng.randi_range(low, high - 2)
	problem.prompt_line_id = &"z1.count.prompt_between"
	problem.prompt_params = {"a": a, "b": a + 2}
	problem.answer = a + 1
	GeneratorKit.add_distractor(problem, skill, a, &"off_by_one")
	GeneratorKit.add_distractor(problem, skill, a + 2, &"off_by_one")
	var window: Vector2i = GeneratorKit.window_around([a, a + 2])
	return GeneratorKit.number_line(window.x, window.y, 10, [a, a + 2], [])


## Fill in the missing numbers of a strip of `len` numbers in a row (pictorial). The blanks are
## never the first or last number, so there is always context on both sides.
static func _strip(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var length: int = int(params.get("len", 5))
	var blank_count: int = clampi(int(params.get("blanks", 2)), 1, length - 2)
	var top: int = GeneratorKit.eased_max(length, int(params.get("max", 120)), GeneratorKit.difficulty_of(params), length)
	var start: int = rng.randi_range(1, top - length + 1)
	var interior: Array[int] = []
	for index: int in range(1, length - 1):
		interior.append(index)
	var chosen: Array[int] = GeneratorKit.shuffled_ints(interior, rng).slice(0, blank_count)
	chosen.sort()
	var blanks: Array[int] = []
	for index: int in chosen:
		blanks.append(start + index)
	problem.prompt_line_id = &"z1.count.prompt_strip"
	problem.answer = blanks
	problem.visual = GeneratorKit.number_line(start, start + length - 1, 1, [], blanks)
	var shifted: Array[int] = []
	for value: int in blanks:
		shifted.append(value + 1)
	GeneratorKit.add_distractor(problem, skill, shifted, &"off_by_one")
	var jumped: Array[int] = blanks.duplicate()
	jumped[0] += 10
	GeneratorKit.add_distractor(problem, skill, jumped, &"decade_skip")
	# Hint model: the same strip with the first blank filled in (kept hidden if it is the only one).
	var still_hidden: Array[int] = blanks.slice(1) if blanks.size() > 1 else blanks
	return GeneratorKit.number_line(start, start + length - 1, 1, [], still_hidden)


## Write the number: shown as gems (concrete) or as tens and ones in words (abstract). The
## abstract form stays under 100 so it can be said as "tens and ones".
static func _write(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var low: int = int(params.get("min", 11))
	var high: int = GeneratorKit.eased_max(low, int(params.get("max", 120)), GeneratorKit.difficulty_of(params))
	if problem.representation == &"abstract":
		high = mini(high, 99)
	var n: int = rng.randi_range(low, high)
	problem.answer = n
	if problem.representation == &"abstract":
		problem.prompt_line_id = &"z1.count.prompt_write_words"
		problem.prompt_params = {"tens": GeneratorKit.tens_digit(n), "ones": GeneratorKit.ones_digit(n)}
	else:
		problem.prompt_line_id = &"z1.count.prompt_write_piles"
		problem.visual = GeneratorKit.gem_piles([GeneratorKit.pile_of(n)])
	GeneratorKit.add_distractor(problem, skill, GeneratorKit.swap_digits(n), &"digit_swap")
	return GeneratorKit.gem_piles([GeneratorKit.pile_of(n)])
