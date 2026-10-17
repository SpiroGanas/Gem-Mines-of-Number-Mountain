## Multiples for Zone 4 (skills mul.*): load the cart with the first multiples of a number, say
## whether one number is a multiple of another, and find the first multiple two numbers share.
## Pure: only the passed-in rng is used.
##
## Modes (params.mode):
##   first_k   "Load the cart with the first {k} multiples of {b}." Drag tiles into ordered slots
##             (answer: the multiples in order). Wrong boards start one multiple early or late
##             (off_by_b) or list factors instead (factor_not_multiple).
##   check     "Is {n} a multiple of {b}?" Yes or no.
##   common    "What is the first multiple of both {a} and {b}?" A number.
class_name MultiplesGenerator
extends RefCounted

## The tile board holds at most this many tiles.
const MAX_TILES: int = 8
## A hop line draws at most this many hops (a check never needs more).
const MAX_MULTIPLIER: int = 10
const PROMPT_FIRST_K: StringName = &"z4.mul.prompt_first_k"
const PROMPT_CHECK: StringName = &"z4.mul.prompt_check"
const PROMPT_COMMON: StringName = &"z4.mul.prompt_common"


static func generate(skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Problem:
	return _make(skill, params, rng, true)


static func _make(skill: Skill, params: Dictionary, rng: RandomNumberGenerator, with_hints: bool) -> Problem:
	var mode: String = String(params.get("mode", "first_k"))
	var problem: Problem = GeneratorKit.new_problem(skill, params, GeneratorKit.pick_representation(skill, params))
	var model: Dictionary
	var example_line: Callable
	match mode:
		"first_k":
			model = _first_k(problem, skill, params, rng)
			example_line = _first_k_line_of
		"check":
			model = _check(problem, skill, params, rng)
			example_line = _check_line_of
		"common":
			model = _common(problem, skill, params, rng)
			example_line = _common_line_of
		_:
			push_error("MultiplesGenerator: unknown mode '%s'" % mode)
			return problem
	if with_hints:
		var example: Problem = GeneratorKit.make_example(
			func(sub: RandomNumberGenerator) -> Problem: return _make(skill, params, sub, false), problem, rng)
		GeneratorKit.add_hints(problem, model, example, example_line.call(example))
	return problem


## The first `count` multiples of b: b, 2b, 3b...
static func _multiples(b: int, count: int, start: int = 1) -> Array[int]:
	var found: Array[int] = []
	for index: int in range(start, start + count):
		found.append(b * index)
	return found


# --- first_k ---------------------------------------------------------------------------------


static func _first_k(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var difficulty: int = GeneratorKit.difficulty_of(params)
	var b_min: int = int(params.get("b_min", 2))
	var b: int = rng.randi_range(b_min, GeneratorKit.eased_max(b_min, int(params.get("b_max", 9)), difficulty, 2))
	var k_min: int = int(params.get("k_min", 3))
	var k: int = rng.randi_range(k_min, GeneratorKit.eased_max(k_min, int(params.get("k_max", 5)), difficulty, 0))
	problem.prompt_line_id = PROMPT_FIRST_K
	problem.prompt_params = {"k": k, "b": b}
	problem.answer = _multiples(b, k)
	# Listing the factors of b instead of its multiples (only when b has enough factors).
	var factors: Array[int] = MathUtil.factors(b)
	if factors.size() >= k:
		_try_add_board(problem, skill, GeneratorKit.ints_of(factors.slice(0, k)), &"factor_not_multiple")
	# Starting one multiple late (leaving out b), or one early (counting 0 as the first).
	_try_add_board(problem, skill, _multiples(b, k, 2), &"off_by_b")
	_try_add_board(problem, skill, _multiples(b, k, 0), &"off_by_b")
	var tiles: Array[int] = GeneratorKit.tile_pool(problem)
	problem.meta = {"tile_board": {"tiles": tiles, "slots": k, "ordered": true}}
	return GeneratorKit.hops_line(k, b)


## Adds a wrong board (in the order the child would write it) unless the tile board would need
## more than 8 tiles.
static func _try_add_board(problem: Problem, skill: Skill, board: Array[int], misconception: StringName) -> void:
	if GeneratorKit.pool_size_with(problem, board) <= MAX_TILES:
		GeneratorKit.add_distractor(problem, skill, board, misconception)


static func _first_k_line_of(example: Problem) -> Dictionary:
	var b: int = example.prompt_params["b"]
	return {"line_id": &"z4.hint.example_multiples", "params": {"b": b, "m2": b * 2, "m3": b * 3}}


# --- check -----------------------------------------------------------------------------------


## "Is {n} a multiple of {b}?" Four kinds, each with the mistake the wrong answer stands for:
##   b times 2 to 10        yes (wrong: no, no_check_made);
##   b itself               yes (wrong: no, off_by_b: left out the first multiple);
##   a factor of b          no (wrong: yes, factor_not_multiple);
##   any other number       no (wrong: yes, no_check_made).
static func _check(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var difficulty: int = GeneratorKit.difficulty_of(params)
	var b_min: int = int(params.get("b_min", 2))
	var b: int = rng.randi_range(b_min, GeneratorKit.eased_max(b_min, int(params.get("b_max", 9)), difficulty, 2))
	var most: int = GeneratorKit.eased_max(3, mini(int(params.get("max_multiplier", MAX_MULTIPLIER)), MAX_MULTIPLIER), difficulty, 1)
	var roll: int = rng.randi_range(0, 99)
	var n: int
	var is_multiple: bool
	var wrong: StringName
	if roll < 30:
		n = b * rng.randi_range(2, most)
		is_multiple = true
		wrong = &"no_check_made"
	elif roll < 45:
		n = b
		is_multiple = true
		wrong = &"off_by_b"
	elif roll < 70:
		var smaller: Array[int] = MathUtil.factors(b) # 1 up to b
		smaller.erase(b)
		n = smaller[rng.randi_range(0, smaller.size() - 1)]
		is_multiple = false
		wrong = &"factor_not_multiple"
	else:
		var others: Array[int] = []
		for value: int in range(2, b * most + 1):
			if value % b != 0 and b % value != 0:
				others.append(value)
		n = others[rng.randi_range(0, others.size() - 1)]
		is_multiple = false
		wrong = &"no_check_made"
	problem.prompt_line_id = PROMPT_CHECK
	problem.prompt_params = {"n": n, "b": b}
	problem.answer = is_multiple
	problem.meta = {"label_lines": GeneratorKit.yes_no_labels()}
	GeneratorKit.add_distractor(problem, skill, not is_multiple, wrong)
	var line: Dictionary = _hops_past(b, n)
	if problem.representation == &"pictorial":
		problem.visual = line
	return line


## Hops of b from 0 up to the first multiple that reaches n, with a marker on n.
static func _hops_past(b: int, n: int) -> Dictionary:
	var groups: int = ceili(float(n) / float(b))
	var markers: Array[int] = [n]
	return GeneratorKit.hops_line(groups, b, markers)


static func _check_line_of(example: Problem) -> Dictionary:
	var n: int = example.prompt_params["n"]
	var b: int = example.prompt_params["b"]
	if example.answer:
		return {"line_id": &"z4.hint.example_multiple_yes", "params": {"b": b, "m": floori(float(n) / float(b)), "n": n}}
	return {"line_id": &"z4.hint.example_multiple_no", "params": {"b": b, "n": n}}


# --- common ----------------------------------------------------------------------------------


## The first multiple that a and b share. a and b differ. Wrong answers:
##   used_the_product        a x b (when that is not the right answer);
##   factor_not_multiple     the greatest number that goes into both (gcd), a factor, not a multiple;
##   off_by_b                one multiple of a (or b) too early or too late.
static func _common(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var low: int = int(params.get("min", 2))
	var high: int = GeneratorKit.eased_max(low, int(params.get("max", 9)), GeneratorKit.difficulty_of(params), 2)
	var a: int = rng.randi_range(low, high)
	var b: int = rng.randi_range(low, high - 1)
	if b >= a:
		b += 1 # uniform over the numbers that are not a
	var first: int = MathUtil.lcm(a, b)
	problem.prompt_line_id = PROMPT_COMMON
	problem.prompt_params = {"a": a, "b": b}
	problem.answer = first
	GeneratorKit.add_distractor(problem, skill, a * b, &"used_the_product")
	GeneratorKit.add_distractor(problem, skill, MathUtil.gcd(a, b), &"factor_not_multiple")
	var near: Array[int] = GeneratorKit.shuffled_ints([first - a, first - b, first + a, first + b], rng)
	for value: int in near:
		if value > 0 and problem.distractors.size() < 3:
			GeneratorKit.add_distractor(problem, skill, value, &"off_by_b")
	# Hint picture: hops of a up to the shared multiple, with a marker on every multiple of b.
	var marks: Array[int] = []
	for index: int in range(1, floori(float(first) / float(b)) + 1):
		marks.append(b * index)
	var line: Dictionary = GeneratorKit.hops_line(floori(float(first) / float(a)), a, marks)
	return line


static func _common_line_of(example: Problem) -> Dictionary:
	return {"line_id": &"z4.hint.example_common", "params": {"a": example.prompt_params["a"], "b": example.prompt_params["b"], "m": example.answer}}
