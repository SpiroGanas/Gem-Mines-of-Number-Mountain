## Subtraction problems for Zone 2 (skills sub.*): facts within 10 and 20, taking away tens, and
## two-digit differences with and without regrouping. The skill's params pick the kind (see
## _kind_of). Facts use the ASCII "-" like every subtraction line in the game.
## Pure: only the passed-in rng is used.
class_name SubtractionGenerator
extends RefCounted

## Subtracting within 20 practices teen numbers (11 to 20); within 10 is its own skill.
const TEEN_LOW: int = 11
const BIGGEST_DIGIT: int = 9
## How often a two-digit difference takes away a one-digit number (52 - 7) instead of a two-digit one.
const ONE_DIGIT_RATE: float = 0.3
## The smallest upper limit a two-digit difference is eased down to (difficulty below 0).
const TWO_DIGIT_LOW: int = 20
## Tries before the sampler falls back to a known-good pair. Never reached in practice: every try
## succeeds about half the time.
const MAX_TRIES: int = 200


static func generate(skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Problem:
	return _make(skill, params, rng, true)


static func _make(skill: Skill, params: Dictionary, rng: RandomNumberGenerator, with_hints: bool) -> Problem:
	var problem: Problem = GeneratorKit.new_problem(skill, params, GeneratorKit.pick_representation(skill, params))
	var model: Dictionary
	match _kind_of(params):
		"facts":
			model = _facts(problem, skill, params, rng)
		"tens":
			model = _tens(problem, skill, params, rng)
		"two_digit":
			model = _two_digit(problem, skill, params, rng)
		_:
			push_error("SubtractionGenerator: unknown mode '%s'" % params.get("mode", ""))
			return problem
	if with_hints:
		var example: Problem = GeneratorKit.make_example(
			func(sub: RandomNumberGenerator) -> Problem: return _make(skill, params, sub, false), problem, rng)
		var line: Dictionary = {"line_id": &"z2.hint.example_sub", "params": {"a": example.prompt_params["a"], "b": example.prompt_params["b"], "diff": example.answer}}
		GeneratorKit.add_hints(problem, model, example, line)
	return problem


## Which kind of difference the params ask for: mode "tens", or mode "diff" as two-digit numbers
## when the params say whether to regroup, else as facts up to params.max.
static func _kind_of(params: Dictionary) -> String:
	match String(params.get("mode", "diff")):
		"tens":
			return "tens"
		"diff":
			return "two_digit" if params.has("regroup") else "facts"
	return ""


## What is {a} - {b}? with b from 1 to 9 and never more than a. Up to 10, a runs from 2 to 10 and
## the problem shows a pile of a loose gems (concrete); above 10, a is a teen number (11 to max)
## shown on two ten-frames (pictorial). The hint model jumps back along a number line, through 10
## when the jump crosses it (13 - 5: back 3 to 10, then 2 more).
static func _facts(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var limit: int = int(params.get("max", 10))
	var low: int = TEEN_LOW if limit > 10 else 2
	var high: int = GeneratorKit.eased_max(low, limit, GeneratorKit.difficulty_of(params))
	var a: int = rng.randi_range(low, high)
	var b: int = rng.randi_range(1, mini(a, BIGGEST_DIGIT))
	var diff: int = a - b
	problem.prompt_line_id = &"z2.sub.prompt_diff"
	problem.prompt_params = {"a": a, "b": b}
	problem.answer = diff
	if problem.representation == &"concrete":
		problem.visual = GeneratorKit.gem_piles([GeneratorKit.pile(0, 0, a)])
	else:
		problem.visual = {"type": "ten_frame", "count": a, "frames": maxi(1, ceili(a / 10.0))}
	GeneratorKit.add_distractor(problem, skill, a + b, &"added_instead")
	GeneratorKit.add_distractor(problem, skill, diff + 1, &"off_by_one")
	GeneratorKit.add_distractor(problem, skill, diff - 1, &"off_by_one") # skipped when diff is 0
	var line_max: int = maxi(10, ceili(a / 10.0) * 10)
	var line: Dictionary = GeneratorKit.number_line(0, line_max, 1 if line_max <= 10 else 5, [a], [])
	if a > 10 and diff < 10:
		line["jumps"] = [{"from": a, "to": 10}, {"from": 10, "to": diff}]
	else:
		line["jumps"] = [{"from": a, "to": diff}]
	return line


## What is {a} - {b}? with both multiples of ten and b less than a (70 - 30), shown as one pile of
## ten-bars. The hint model counts back by tens along a number line.
static func _tens(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var top_tens: int = GeneratorKit.eased_max(2, floori(int(params.get("max", 100)) / 10.0), GeneratorKit.difficulty_of(params), 1)
	var x: int = rng.randi_range(2, top_tens)
	var y: int = rng.randi_range(1, x - 1)
	var a: int = x * 10
	var b: int = y * 10
	var diff: int = a - b
	problem.prompt_line_id = &"z2.sub.prompt_tens"
	problem.prompt_params = {"a": a, "b": b}
	problem.answer = diff
	problem.visual = GeneratorKit.gem_piles([GeneratorKit.pile(0, x, 0)])
	GeneratorKit.add_distractor(problem, skill, x - y, &"subtracted_as_ones") # 70 - 30 as 7 - 3
	GeneratorKit.add_distractor(problem, skill, a - y, &"subtracted_as_ones") # took away 3 ones, not 3 tens
	var line: Dictionary = GeneratorKit.number_line(0, maxi(100, a), 10, [a], [])
	var jumps: Array[Dictionary] = []
	for step: int in y:
		jumps.append({"from": a - step * 10, "to": a - (step + 1) * 10})
	line["jumps"] = jumps
	return line


## A two-digit number minus a smaller one- or two-digit number. With `regroup` the ones of a are
## fewer than the ones of b, so a ten must be traded for ten ones (52 - 27); without it they are
## not (57 - 23). a stays under 100. Concrete problems show a pile of a; abstract ones show
## nothing until the hint.
static func _two_digit(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var regroup: bool = bool(params.get("regroup", false))
	var top: int = GeneratorKit.eased_max(TWO_DIGIT_LOW, mini(int(params.get("max", 100)), 99), GeneratorKit.difficulty_of(params), 10)
	var pair: Vector2i = _two_digit_pair(regroup, top, rng)
	var a: int = pair.x
	var b: int = pair.y
	var diff: int = a - b
	var tens_a: int = GeneratorKit.tens_digit(a)
	var ones_a: int = GeneratorKit.ones_digit(a)
	var tens_b: int = GeneratorKit.tens_digit(b)
	var ones_b: int = GeneratorKit.ones_digit(b)
	problem.prompt_line_id = &"z2.sub.prompt_diff"
	problem.prompt_params = {"a": a, "b": b}
	problem.answer = diff
	var start: Dictionary = GeneratorKit.gem_piles([GeneratorKit.pile_of(a)])
	if problem.representation == &"concrete":
		problem.visual = start
	if regroup:
		# Took the smaller digit from the larger in each place (53 - 27 as 34) ...
		GeneratorKit.add_distractor(problem, skill, absi(tens_a - tens_b) * 10 + absi(ones_a - ones_b), &"smaller_from_larger")
		# ... or traded a ten for ones but never took it away from the tens (53 - 27 as 36). The two
		# agree when the ones digits are 5 apart (52 - 27 is 35 both ways); then only one is kept.
		GeneratorKit.add_distractor(problem, skill, diff + 10, &"forgot_untrade")
	else:
		# Without regrouping, the smaller digit from the larger IS the right answer, so it is no
		# distractor here; the swapped digits and adding instead are.
		if _swap_is_a_new_number(diff):
			GeneratorKit.add_distractor(problem, skill, GeneratorKit.swap_digits(diff), &"digit_swap")
		GeneratorKit.add_distractor(problem, skill, a + b, &"added_instead")
	if problem.representation != &"concrete":
		return start
	if regroup:
		return GeneratorKit.gem_piles([GeneratorKit.pile(0, tens_a - 1, ones_a + 10)]) # a after trading one ten
	var window: Vector2i = GeneratorKit.window_around([diff, a], 0, 100)
	var line: Dictionary = GeneratorKit.number_line(window.x, window.y, 10, [a], [])
	var jumps: Array[Dictionary] = []
	var after_tens: int = a - tens_b * 10
	if tens_b > 0:
		jumps.append({"from": a, "to": after_tens}) # take away the tens ...
	if ones_b > 0:
		jumps.append({"from": after_tens, "to": diff}) # ... then the ones
	line["jumps"] = jumps
	return line


## A two-digit `a` and a smaller `b` (one digit about ONE_DIGIT_RATE of the time), at most `top`, whose
## ones need regrouping exactly when `regroup` is set.
static func _two_digit_pair(regroup: bool, top: int, rng: RandomNumberGenerator) -> Vector2i:
	var one_digit: bool = rng.randf() < ONE_DIGIT_RATE
	for attempt: int in MAX_TRIES:
		var a: int = rng.randi_range(10, top)
		var b: int = rng.randi_range(1, BIGGEST_DIGIT) if one_digit else rng.randi_range(10, maxi(10, a - 1))
		var needs_trade: bool = GeneratorKit.ones_digit(a) < GeneratorKit.ones_digit(b)
		if b < a and needs_trade == regroup:
			return Vector2i(a, b)
	return Vector2i(21, 2) if regroup else Vector2i(12, 1)


## True when swapping the digits of a two-digit `n` makes a different two-digit number (not 44, not 40).
static func _swap_is_a_new_number(n: int) -> bool:
	var tens: int = GeneratorKit.tens_digit(n)
	var ones: int = GeneratorKit.ones_digit(n)
	return n >= 10 and n <= 99 and ones != 0 and tens != ones
