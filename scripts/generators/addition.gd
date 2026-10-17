## Addition problems for Zone 2 (skills add.*): facts within 10, making a ten within 20, doubles and
## near doubles, adding tens, two-digit sums with and without regrouping, and three addends.
## The skill's params pick the kind of sum (see _kind_of). Pure: only the passed-in rng is used.
class_name AdditionGenerator
extends RefCounted

## The make-a-ten facts start from a first addend of 6 to 9 (the one that is filled up to ten).
const MAKE_TEN_LOW: int = 6
const MAKE_TEN_MIN_SUM: int = 11
const BIGGEST_DIGIT: int = 9
## How often a two-digit sum adds a one-digit number (34 + 5) instead of a two-digit one (34 + 25).
const ONE_DIGIT_RATE: float = 0.3
## The smallest upper limit a two-digit sum is eased down to (difficulty below 0).
const TWO_DIGIT_LOW: int = 20
## Tries before a sampler falls back to a known-good pair. Never reached in practice: every try
## succeeds about half the time or more.
const MAX_TRIES: int = 200


static func generate(skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Problem:
	return _make(skill, params, rng, true)


static func _make(skill: Skill, params: Dictionary, rng: RandomNumberGenerator, with_hints: bool) -> Problem:
	var problem: Problem = GeneratorKit.new_problem(skill, params, GeneratorKit.pick_representation(skill, params))
	var model: Dictionary
	var example_line: Callable = _sum_line_of
	match _kind_of(params):
		"facts":
			model = _facts(problem, skill, params, rng)
		"make_ten":
			model = _make_ten(problem, skill, params, rng)
			example_line = _make_ten_line_of
		"doubles":
			model = _doubles(problem, skill, params, rng)
		"tens":
			model = _tens(problem, skill, params, rng)
		"two_digit":
			model = _two_digit(problem, skill, params, rng)
		"three":
			model = _three(problem, skill, params, rng)
			example_line = _three_line_of
		_:
			push_error("AdditionGenerator: unknown mode '%s'" % params.get("mode", ""))
			return problem
	if with_hints:
		var example: Problem = GeneratorKit.make_example(
			func(sub: RandomNumberGenerator) -> Problem: return _make(skill, params, sub, false), problem, rng)
		GeneratorKit.add_hints(problem, model, example, example_line.call(example))
	return problem


## Which kind of sum the params ask for. mode "sums" covers four kinds, told apart by its other keys:
## `addends: 3` (three addends), `regroup` (two-digit sums), `strategy: make_ten`, else facts.
static func _kind_of(params: Dictionary) -> String:
	match String(params.get("mode", "sums")):
		"doubles_near":
			return "doubles"
		"tens":
			return "tens"
		"sums":
			if int(params.get("addends", 2)) == 3:
				return "three"
			if params.has("regroup"):
				return "two_digit"
			if String(params.get("strategy", "")) == "make_ten":
				return "make_ten"
			return "facts"
	return ""


# --- Worked-example answer lines -------------------------------------------------------------


static func _sum_line_of(example: Problem) -> Dictionary:
	return {"line_id": &"z2.hint.example_add", "params": {"a": example.prompt_params["a"], "b": example.prompt_params["b"], "sum": example.answer}}


static func _three_line_of(example: Problem) -> Dictionary:
	var p: Dictionary = example.prompt_params
	return {"line_id": &"z2.hint.example_add_three", "params": {"a": p["a"], "b": p["b"], "c": p["c"], "sum": example.answer}}


## "8 + 2 = 10. Then 10 + 3 = 13.": the make-a-ten steps of the example.
static func _make_ten_line_of(example: Problem) -> Dictionary:
	var a: int = example.prompt_params["a"]
	var b: int = example.prompt_params["b"]
	var fill: int = 10 - a
	return {"line_id": &"z2.hint.example_make_ten", "params": {"a": a, "fill": fill, "ten": 10, "rest": b - fill, "sum": example.answer}}


# --- Kinds of sum ----------------------------------------------------------------------------


## What is {a} + {b}? with a, b at least 1 and the sum at most max_sum. Shown as two piles of loose
## gems; the hint model is a ten-frame with each addend in its own color.
static func _facts(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var high: int = GeneratorKit.eased_max(2, int(params.get("max_sum", 10)), GeneratorKit.difficulty_of(params))
	var pair: Vector2i = _pair_with_sum_at_most(1, high - 1, high, rng)
	var a: int = pair.x
	var b: int = pair.y
	var sum: int = a + b
	problem.prompt_line_id = &"z2.add.prompt_sum"
	problem.prompt_params = {"a": a, "b": b}
	problem.answer = sum
	problem.visual = GeneratorKit.gem_piles([GeneratorKit.pile(0, 0, a), GeneratorKit.pile(0, 0, b)])
	# Counting on from a and saying "a" again as the first count lands one short.
	GeneratorKit.add_distractor(problem, skill, sum - 1, &"counted_from_one")
	GeneratorKit.add_distractor(problem, skill, sum + 1, &"off_by_one")
	return _two_color_frame(a, b)


## What is {a} + {b}? where a is 6 to 9 and the sum crosses ten (11 or more). Both addends are single
## digits, so the sums run from 11 to 18. The picture is the make-a-ten frame; the hint model is a
## number line jumping from a up to 10, then on to the sum.
static func _make_ten(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var high: int = GeneratorKit.eased_max(MAKE_TEN_MIN_SUM, int(params.get("max_sum", 20)), GeneratorKit.difficulty_of(params))
	var a: int = rng.randi_range(MAKE_TEN_LOW, BIGGEST_DIGIT)
	var b: int = rng.randi_range(MAKE_TEN_MIN_SUM - a, mini(BIGGEST_DIGIT, high - a))
	var sum: int = a + b
	problem.prompt_line_id = &"z2.add.prompt_make_ten"
	problem.prompt_params = {"a": a, "b": b}
	problem.answer = sum
	problem.visual = {"type": "ten_frame", "count": a, "second": b, "frames": 2}
	# Made the ten but kept only the ones left over (8 + 5 gave 3).
	GeneratorKit.add_distractor(problem, skill, sum - 10, &"forgot_regroup")
	GeneratorKit.add_distractor(problem, skill, sum + 1, &"off_by_one")
	GeneratorKit.add_distractor(problem, skill, sum - 1, &"off_by_one")
	var line: Dictionary = GeneratorKit.number_line(0, maxi(20, ceili(sum / 10.0) * 10), 5, [a], [])
	line["jumps"] = [{"from": a, "to": 10}, {"from": 10, "to": sum}]
	return line


## Doubles (7 + 7) and near doubles (7 + 8 or 8 + 7), half of each, with the sum at most max_sum.
## Shown as two piles of loose gems; the hint model lines the gems up in pairs, so a near double
## is a double with one gem left over.
static func _doubles(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var high: int = GeneratorKit.eased_max(2, int(params.get("max_sum", 20)), GeneratorKit.difficulty_of(params))
	var near: bool = high >= 3 and rng.randi_range(0, 1) == 1
	var n: int = rng.randi_range(1, floori((high - 1) / 2.0) if near else floori(high / 2.0))
	var a: int = n
	var b: int = n
	if near:
		if rng.randi_range(0, 1) == 0:
			b = n + 1
		else:
			a = n + 1
	var sum: int = a + b
	problem.prompt_line_id = &"z2.add.prompt_sum"
	problem.prompt_params = {"a": a, "b": b}
	problem.answer = sum
	problem.visual = GeneratorKit.gem_piles([GeneratorKit.pile(0, 0, a), GeneratorKit.pile(0, 0, b)])
	# Used the nearby double without adjusting (6 + 7 as 12 or 14) ...
	GeneratorKit.add_distractor(problem, skill, sum - 1, &"off_by_one")
	GeneratorKit.add_distractor(problem, skill, sum + 1, &"off_by_one")
	# ... or adjusted the wrong way (6 + 7 as 11 or 15). Never 0 for a sum of two counting numbers.
	var two_more: bool = sum - 2 < 1 or rng.randi_range(0, 1) == 0
	GeneratorKit.add_distractor(problem, skill, sum + 2 if two_more else sum - 2, &"off_by_two")
	return {"type": "pairs", "count": sum, "show_pairs": true}


## What is {a} + {b}? with both multiples of ten (30 + 40), shown as two piles of ten-bars. The hint
## model counts on by tens along a number line.
static func _tens(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var top_tens: int = GeneratorKit.eased_max(2, floori(int(params.get("max_sum", 100)) / 10.0), GeneratorKit.difficulty_of(params), 1)
	var pair: Vector2i = _pair_with_sum_at_most(1, top_tens - 1, top_tens, rng)
	var a: int = pair.x * 10
	var b: int = pair.y * 10
	var sum: int = a + b
	problem.prompt_line_id = &"z2.add.prompt_tens"
	problem.prompt_params = {"a": a, "b": b}
	problem.answer = sum
	problem.visual = GeneratorKit.gem_piles([GeneratorKit.pile(0, pair.x, 0), GeneratorKit.pile(0, pair.y, 0)])
	GeneratorKit.add_distractor(problem, skill, pair.x + pair.y, &"added_as_ones") # 30 + 40 as 3 + 4
	GeneratorKit.add_distractor(problem, skill, sum - 10, &"decade_skip")
	GeneratorKit.add_distractor(problem, skill, sum + 10, &"decade_skip")
	var line: Dictionary = GeneratorKit.number_line(0, maxi(100, sum), 10, [a], [])
	line["jumps"] = _jumps_by_ten(a, sum)
	return line


## A two-digit number plus a one- or two-digit number, the total at most max_sum. With `regroup` the
## ones make a new ten (38 + 5); without it they do not (34 + 25) and the total stays under 100.
## Concrete problems show the two piles; abstract ones show nothing until the hint.
static func _two_digit(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var regroup: bool = bool(params.get("regroup", false))
	var limit: int = int(params.get("max_sum", 100))
	if not regroup:
		limit = mini(limit, 99) # 50 + 50 would regroup the tens into a hundred
	var top: int = GeneratorKit.eased_max(TWO_DIGIT_LOW, limit, GeneratorKit.difficulty_of(params), 10)
	var pair: Vector2i = _two_digit_pair(regroup, top, rng)
	var a: int = pair.x
	var b: int = pair.y
	var sum: int = a + b
	problem.prompt_line_id = &"z2.add.prompt_sum"
	problem.prompt_params = {"a": a, "b": b}
	problem.answer = sum
	var addends: Dictionary = GeneratorKit.gem_piles([GeneratorKit.pile_of(a), GeneratorKit.pile_of(b)])
	if problem.representation == &"concrete":
		problem.visual = addends
	if regroup:
		GeneratorKit.add_distractor(problem, skill, sum - 10, &"forgot_regroup") # wrote the ones, dropped the ten
		GeneratorKit.add_distractor(problem, skill, sum + 10, &"carried_twice")
	else:
		var crossed: int = _crossed_places(a, b)
		if crossed >= 0:
			GeneratorKit.add_distractor(problem, skill, crossed, &"added_tens_to_ones")
		if _swap_is_a_new_number(sum):
			GeneratorKit.add_distractor(problem, skill, GeneratorKit.swap_digits(sum), &"digit_swap")
	if problem.representation != &"concrete":
		return addends
	# Tens together and ones together: with regrouping the ones pile has ten or more to trade.
	var tens: int = GeneratorKit.tens_digit(a) + GeneratorKit.tens_digit(b)
	var ones: int = GeneratorKit.ones_digit(a) + GeneratorKit.ones_digit(b)
	return GeneratorKit.gem_piles([GeneratorKit.pile(0, tens, ones)])


## What is {a} + {b} + {c}? with each addend 1 to 9 and the sum at most max_sum. Shown as three piles
## of loose gems; the hint model jumps along a number line from a, by b, then by c.
static func _three(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var high: int = GeneratorKit.eased_max(3, int(params.get("max_sum", 20)), GeneratorKit.difficulty_of(params), 3)
	var cap: int = mini(BIGGEST_DIGIT, high - 2)
	var a: int = 1
	var b: int = 1
	var c: int = 1
	for attempt: int in MAX_TRIES:
		var x: int = rng.randi_range(1, cap)
		var y: int = rng.randi_range(1, cap)
		var z: int = rng.randi_range(1, cap)
		if x + y + z <= high:
			a = x
			b = y
			c = z
			break
	var sum: int = a + b + c
	problem.prompt_line_id = &"z2.add.prompt_three"
	problem.prompt_params = {"a": a, "b": b, "c": c}
	problem.answer = sum
	problem.visual = GeneratorKit.gem_piles([GeneratorKit.pile(0, 0, a), GeneratorKit.pile(0, 0, b), GeneratorKit.pile(0, 0, c)])
	GeneratorKit.add_distractor(problem, skill, a + b, &"dropped_addend") # left out the last number
	GeneratorKit.add_distractor(problem, skill, sum + 1, &"off_by_one")
	GeneratorKit.add_distractor(problem, skill, b + c, &"dropped_addend") # left out the first number
	GeneratorKit.add_distractor(problem, skill, a + c, &"dropped_addend")
	GeneratorKit.add_distractor(problem, skill, sum - 1, &"off_by_one")
	var line: Dictionary = GeneratorKit.number_line(0, maxi(20, ceili(sum / 10.0) * 10), 5, [a], [])
	line["jumps"] = [{"from": a, "to": a + b}, {"from": a + b, "to": sum}]
	return line


# --- Helpers ---------------------------------------------------------------------------------


## Two numbers from `low` to `cap` whose sum is at most `max_sum`, uniform over all such pairs.
static func _pair_with_sum_at_most(low: int, cap: int, max_sum: int, rng: RandomNumberGenerator) -> Vector2i:
	for attempt: int in MAX_TRIES:
		var x: int = rng.randi_range(low, cap)
		var y: int = rng.randi_range(low, cap)
		if x + y <= max_sum:
			return Vector2i(x, y)
	return Vector2i(low, low)


## A two-digit `a` and a `b` (one digit about ONE_DIGIT_RATE of the time) with a + b <= top, whose
## ones make a new ten exactly when `regroup` is set. A sum without regrouping must also have at
## least one wrong answer to offer (see _two_digit).
static func _two_digit_pair(regroup: bool, top: int, rng: RandomNumberGenerator) -> Vector2i:
	var one_digit: bool = rng.randf() < ONE_DIGIT_RATE
	for attempt: int in MAX_TRIES:
		var a: int = rng.randi_range(10, top - 1)
		var b: int = rng.randi_range(1, BIGGEST_DIGIT) if one_digit else rng.randi_range(10, maxi(10, top - a))
		if a + b > top or _ones_make_a_ten(a, b) != regroup:
			continue
		if not regroup and _crossed_places(a, b) < 0 and not _swap_is_a_new_number(a + b):
			continue
		return Vector2i(a, b)
	return Vector2i(11, 9) if regroup else Vector2i(10, 1)


static func _ones_make_a_ten(a: int, b: int) -> bool:
	return GeneratorKit.ones_digit(a) + GeneratorKit.ones_digit(b) >= 10


## What a child writes who adds b's ones digit to a's tens and b's tens digit to a's ones, column by
## column (34 + 25 as 86; 34 + 5, the 5 lined up under the 3, as 84). -1 when that is not a clean
## two-digit number different from the answer: a column passes 9, or b's two digits are the same.
static func _crossed_places(a: int, b: int) -> int:
	var tens: int = GeneratorKit.tens_digit(a) + GeneratorKit.ones_digit(b)
	var ones: int = GeneratorKit.ones_digit(a) + GeneratorKit.tens_digit(b)
	if tens > BIGGEST_DIGIT or ones > BIGGEST_DIGIT or GeneratorKit.tens_digit(b) == GeneratorKit.ones_digit(b):
		return -1
	return tens * 10 + ones


## True when swapping the digits of a two-digit `n` makes a different two-digit number (not 44, not 40).
static func _swap_is_a_new_number(n: int) -> bool:
	var tens: int = GeneratorKit.tens_digit(n)
	var ones: int = GeneratorKit.ones_digit(n)
	return n >= 10 and n <= 99 and ones != 0 and tens != ones


## A ten-frame with `first` dots and then `second` dots of another color.
static func _two_color_frame(first: int, second: int) -> Dictionary:
	return {"type": "ten_frame", "count": first, "second": second, "frames": maxi(1, ceili((first + second) / 10.0))}


## Jumps of ten along a number line from `start` to `finish` (both multiples of ten).
static func _jumps_by_ten(start: int, finish: int) -> Array[Dictionary]:
	var jumps: Array[Dictionary] = []
	var step: int = 10 if finish >= start else -10
	var at: int = start
	while at != finish:
		jumps.append({"from": at, "to": at + step})
		at += step
	return jumps
