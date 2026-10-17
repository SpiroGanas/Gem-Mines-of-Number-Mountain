## True-or-false equation problems for Zone 2 (skill eq.balance.true_false): is "a + b = c + d",
## "a + b = c" or "c = a + b" true? The picture is a balance with the numbers on its pans.
## Pure: only the passed-in rng is used.
##
## The misconception this skill exists for is reading "=" as "the answer comes next": checking only
## whether the left side makes the first number after "=". Some false items are built as that trap
## (3 + 4 = 7 + 2). The one wrong answer (the other truth value) is named left_side_only whenever
## that reading gives it; otherwise it is thought_equal (saying true when the sides differ) or
## thought_unequal (saying false when they match).
class_name BalanceGenerator
extends RefCounted

## The three ways the equation is written. Each has its own prompt line.
const SHAPES: Array[String] = ["two_two", "two_one", "one_two"]
const PROMPT_LINES: Dictionary[String, StringName] = {
	"two_two": &"z2.eq.prompt_balance_two_two",
	"two_one": &"z2.eq.prompt_balance_two_one",
	"one_two": &"z2.eq.prompt_balance_one_two",
}
const LABEL_LINES: Dictionary[String, String] = {"true": "ui.answer.true", "false": "ui.answer.false"}
## How many false "a + b = c + d" items are the trap a + b = (a + b) + d.
const TRAP_RATE: float = 0.5
## Every side's total runs from 2 up to the eased max, which is never below 5.
const SMALLEST_TOTAL: int = 2
const SMALLEST_TOP: int = 3
## A true "a + b = c + d" needs a total with at least two different splits into two numbers.
const SMALLEST_TRUE_PAIR_TOTAL: int = 3


static func generate(skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Problem:
	return _make(skill, params, rng, true)


static func _make(skill: Skill, params: Dictionary, rng: RandomNumberGenerator, with_hints: bool) -> Problem:
	var mode: String = String(params.get("mode", "true_false"))
	var problem: Problem = GeneratorKit.new_problem(skill, params, GeneratorKit.pick_representation(skill, params))
	var model: Dictionary
	match mode:
		"true_false":
			model = _true_false(problem, skill, params, rng)
		_:
			push_error("BalanceGenerator: unknown mode '%s'" % mode)
			return problem
	if with_hints:
		var example: Problem = GeneratorKit.make_example(
			func(sub: RandomNumberGenerator) -> Problem: return _make(skill, params, sub, false), problem, rng)
		GeneratorKit.add_hints(problem, model, example, _verdict_line_of(example))
	return problem


static func _verdict_line_of(example: Problem) -> Dictionary:
	var left: int = _total(example.visual["left"])
	var right: int = _total(example.visual["right"])
	if example.answer:
		return {"line_id": &"z2.hint.example_true", "params": {"n": left}}
	return {"line_id": &"z2.hint.example_false", "params": {"left": left, "right": right}}


## Is the equation true? About half are. The pans hold each side's numbers in the order written.
static func _true_false(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var top: int = GeneratorKit.eased_max(SMALLEST_TOP, int(params.get("max", 20)), GeneratorKit.difficulty_of(params))
	var shape: String = SHAPES[rng.randi_range(0, SHAPES.size() - 1)]
	var want_true: bool = rng.randi_range(0, 1) == 0
	var left: Array[int] = []
	var right: Array[int] = []
	match shape:
		"two_two":
			if want_true:
				# Never the very same pans (2 + 5 = 2 + 5); a turned-around pair (2 + 5 = 5 + 2) is fine.
				var total: int = rng.randi_range(SMALLEST_TRUE_PAIR_TOTAL, top)
				left = _split(total, rng)
				var first: int = rng.randi_range(1, total - 2)
				if first >= left[0]:
					first += 1
				right = [first, total - first]
			elif rng.randf() < TRAP_RATE:
				# a + b = (a + b) + d: the left side's total comes right after "=", then more is added.
				var total: int = rng.randi_range(SMALLEST_TOTAL, top - 1)
				left = _split(total, rng)
				right = [total, rng.randi_range(1, top - total)]
			else:
				var total: int = rng.randi_range(SMALLEST_TOTAL, top)
				left = _split(total, rng)
				right = _split(_near(total, SMALLEST_TOTAL, top, rng), rng)
		"two_one":
			var total: int = rng.randi_range(SMALLEST_TOTAL, top)
			left = _split(total, rng)
			right = [total if want_true else _near(total, 1, top, rng)]
		"one_two":
			var total: int = rng.randi_range(SMALLEST_TOTAL, top)
			right = _split(total, rng)
			left = [total if want_true else _near(total, 1, top, rng)]
	var left_total: int = _total(left)
	var right_total: int = _total(right)
	var truth: bool = left_total == right_total
	# Reading "=" as "the answer comes next": does the left side make the first number after "="?
	var trap_says: bool = left_total == right[0]
	var misconception: StringName = &"left_side_only"
	if trap_says == truth:
		misconception = &"thought_unequal" if truth else &"thought_equal"
	problem.prompt_line_id = PROMPT_LINES[shape]
	match shape:
		"two_two":
			problem.prompt_params = {"a": left[0], "b": left[1], "c": right[0], "d": right[1]}
		"two_one":
			problem.prompt_params = {"a": left[0], "b": left[1], "c": right[0]}
		"one_two":
			problem.prompt_params = {"c": left[0], "a": right[0], "b": right[1]}
	problem.answer = truth
	problem.visual = _balance(left, right, "unknown")
	problem.meta = {"label_lines": LABEL_LINES.duplicate()}
	GeneratorKit.add_distractor(problem, skill, not truth, misconception)
	var tilt: String = "level" if truth else ("left" if left_total > right_total else "right")
	return _balance(left, right, tilt)


static func _balance(left: Array[int], right: Array[int], tilt: String) -> Dictionary:
	return {"type": "balance", "left": left.duplicate(), "right": right.duplicate(), "tilt": tilt}


## Two numbers, each at least 1, that make `total`.
static func _split(total: int, rng: RandomNumberGenerator) -> Array[int]:
	var first: int = rng.randi_range(1, total - 1)
	return [first, total - first]


## A number one or two away from `total` (a tempting near miss) within low..high.
static func _near(total: int, low: int, high: int, rng: RandomNumberGenerator) -> int:
	var options: Array[int] = []
	for step: int in [-2, -1, 1, 2]:
		if total + step >= low and total + step <= high:
			options.append(total + step)
	return options[rng.randi_range(0, options.size() - 1)]


static func _total(values: Array) -> int:
	var sum: int = 0
	for value: int in values:
		sum += value
	return sum
