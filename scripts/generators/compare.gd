## Comparing problems for Zone 1 (skills cmp.*): which pile has more, which symbol goes between
## two numbers, and putting three numbers in order. Pure: only the passed-in rng is used.
class_name CompareGenerator
extends RefCounted

const SYMBOL_LESS: StringName = &"<"
const SYMBOL_GREATER: StringName = &">"
const SYMBOL_EQUAL: StringName = &"="
## How often a symbol problem uses two equal numbers.
const EQUAL_RATE: float = 0.15
const CONFLICT_TRIES: int = 40


static func generate(skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Problem:
	return _make(skill, params, rng, true)


static func _make(skill: Skill, params: Dictionary, rng: RandomNumberGenerator, with_hints: bool) -> Problem:
	var mode: String = String(params.get("mode", "more_less"))
	var problem: Problem = GeneratorKit.new_problem(skill, params, GeneratorKit.pick_representation(skill, params))
	var model: Dictionary
	var example_line: Callable
	match mode:
		"more_less":
			model = _more_less(problem, skill, params, rng)
			example_line = _pile_line_of
		"symbols":
			model = _symbols(problem, skill, params, rng)
			example_line = _symbol_line_of
		"order":
			model = _order(problem, skill, params, rng)
			example_line = _list_line_of
		_:
			push_error("CompareGenerator: unknown mode '%s'" % mode)
			return problem
	if with_hints:
		var example: Problem = GeneratorKit.make_example(
			func(sub: RandomNumberGenerator) -> Problem: return _make(skill, params, sub, false), problem, rng)
		GeneratorKit.add_hints(problem, model, example, example_line.call(example))
	return problem


static func _pile_line_of(example: Problem) -> Dictionary:
	var line: StringName = &"z1.hint.example_pile_left" if example.answer == 0 else &"z1.hint.example_pile_right"
	return {"line_id": line, "params": {}}


static func _symbol_line_of(example: Problem) -> Dictionary:
	return {"line_id": &"z1.hint.example_symbol", "params": {"a": example.prompt_params["a"], "b": example.prompt_params["b"], "symbol": String(example.answer)}}


static func _list_line_of(example: Problem) -> Dictionary:
	var parts: PackedStringArray = PackedStringArray()
	for value: int in example.answer:
		parts.append(str(value))
	return {"line_id": &"z1.hint.example_list", "params": {"list": ", ".join(parts)}}


## Two piles of loose gems; tap the one with more (or fewer). The answer is the pile index, 0 or 1.
static func _more_less(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var low: int = 1
	var high: int = GeneratorKit.eased_max(low, int(params.get("max", 20)), GeneratorKit.difficulty_of(params), 3)
	var a: int = rng.randi_range(low, high)
	var b: int = rng.randi_range(low, high - 1)
	if b >= a:
		b += 1 # uniform over the values that are not a, so the piles are never equal
	var ask: String = String(params.get("ask", "mixed"))
	if ask == "mixed":
		ask = "more" if rng.randi_range(0, 1) == 0 else "fewer"
	var bigger_first: bool = a > b
	var answer: int = (0 if bigger_first else 1) if ask == "more" else (1 if bigger_first else 0)
	problem.prompt_line_id = &"z1.cmp.prompt_more" if ask == "more" else &"z1.cmp.prompt_fewer"
	problem.answer = answer
	problem.visual = GeneratorKit.gem_piles([GeneratorKit.pile(0, 0, a), GeneratorKit.pile(0, 0, b)])
	problem.meta = {"ask": ask, "tap_target": "pile"}
	GeneratorKit.add_distractor(problem, skill, 1 - answer, &"picked_smaller")
	return GeneratorKit.number_line(0, 20, 5, [a, b], [])


## Which symbol (<, > or =) goes between {a} and {b}? Some pairs have the tens and ones disagree
## (47 and 52) so a child who compares the ones first is caught; some pairs are equal.
static func _symbols(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var low: int = 1
	var high: int = GeneratorKit.eased_max(low, int(params.get("max", 100)), GeneratorKit.difficulty_of(params), 5)
	var a: int
	var b: int
	if rng.randf() < EQUAL_RATE:
		a = rng.randi_range(low, high)
		b = a
	else:
		var want_conflict: bool = rng.randf() < float(params.get("conflict_rate", 0.5)) and high >= 20
		var pair: Vector2i = _random_pair(low, high, want_conflict, rng)
		a = pair.x
		b = pair.y
	var answer: StringName = SYMBOL_EQUAL if a == b else (SYMBOL_LESS if a < b else SYMBOL_GREATER)
	var conflict: bool = _tens_and_ones_disagree(a, b)
	problem.prompt_line_id = &"z1.cmp.prompt_symbol"
	problem.prompt_params = {"a": a, "b": b}
	problem.answer = answer
	problem.meta = {"conflict": conflict}
	if a == b:
		GeneratorKit.add_distractor(problem, skill, SYMBOL_LESS, &"thought_unequal")
		GeneratorKit.add_distractor(problem, skill, SYMBOL_GREATER, &"thought_unequal")
	else:
		var opposite: StringName = SYMBOL_GREATER if answer == SYMBOL_LESS else SYMBOL_LESS
		GeneratorKit.add_distractor(problem, skill, opposite, &"compared_ones_first" if conflict else &"reversed_symbol")
		GeneratorKit.add_distractor(problem, skill, SYMBOL_EQUAL, &"thought_equal")
	var window: Vector2i = GeneratorKit.window_around([a, b])
	return GeneratorKit.number_line(window.x, window.y, 10 if window.y - window.x <= 60 else 20, [a, b], [])


## Put `n` numbers in order, least or greatest first. The piles are shown shuffled; the answer is
## the numbers in the asked order.
static func _order(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var count: int = int(params.get("n", 3))
	var high: int = GeneratorKit.eased_max(10, int(params.get("max", 100)), GeneratorKit.difficulty_of(params), 20)
	var pool: Array[int] = []
	for value: int in range(10, high + 1):
		pool.append(value)
	var numbers: Array[int] = GeneratorKit.shuffled_ints(pool, rng).slice(0, count)
	var least_first: bool = rng.randi_range(0, 1) == 0
	var ascending: Array[int] = numbers.duplicate()
	ascending.sort()
	var answer: Array[int] = ascending.duplicate()
	if not least_first:
		answer.reverse()
	# Show the piles in an order that is not already the answer.
	var shown: Array[int] = GeneratorKit.shuffled_ints(numbers, rng)
	if shown == answer:
		shown.append(shown.pop_front())
	var piles: Array[Dictionary] = []
	for value: int in shown:
		piles.append(GeneratorKit.pile_of(value))
	problem.prompt_line_id = &"z1.cmp.order_least_first" if least_first else &"z1.cmp.order_greatest_first"
	problem.answer = answer
	problem.visual = GeneratorKit.gem_piles(piles)
	problem.meta = {"direction": "least_first" if least_first else "greatest_first", "numbers": shown}
	var reversed: Array[int] = answer.duplicate()
	reversed.reverse()
	GeneratorKit.add_distractor(problem, skill, reversed, &"reversed_order")
	# A child who compares only the ones digits sorts by ones, then tens.
	var by_ones: Array[int] = numbers.duplicate()
	by_ones.sort_custom(func(x: int, y: int) -> bool: return [x % 10, x] < [y % 10, y])
	if not least_first:
		by_ones.reverse()
	GeneratorKit.add_distractor(problem, skill, by_ones, &"compared_ones_first")
	# Drag the numbers into order: the tiles come in the order the piles are shown.
	problem.meta["tile_board"] = {"tiles": shown.duplicate(), "slots": count, "ordered": true}
	var window: Vector2i = GeneratorKit.window_around(numbers)
	return GeneratorKit.number_line(window.x, window.y, 10 if window.y - window.x <= 60 else 20, numbers, [])


## True when the tens digits order the numbers one way and the ones digits the other way.
static func _tens_and_ones_disagree(a: int, b: int) -> bool:
	var tens_a: int = floori(a / 10.0)
	var tens_b: int = floori(b / 10.0)
	var ones_a: int = a % 10
	var ones_b: int = b % 10
	return (tens_a < tens_b and ones_a > ones_b) or (tens_a > tens_b and ones_a < ones_b)


## Two different numbers; when `want_conflict` is set, tries for a pair where tens and ones disagree.
static func _random_pair(low: int, high: int, want_conflict: bool, rng: RandomNumberGenerator) -> Vector2i:
	var a: int = rng.randi_range(low, high)
	var b: int = rng.randi_range(low, high - 1)
	if b >= a:
		b += 1
	if not want_conflict:
		return Vector2i(a, b)
	for attempt: int in CONFLICT_TRIES:
		if _tens_and_ones_disagree(a, b):
			return Vector2i(a, b)
		a = rng.randi_range(low, high)
		b = rng.randi_range(low, high - 1)
		if b >= a:
			b += 1
	return Vector2i(a, b)
