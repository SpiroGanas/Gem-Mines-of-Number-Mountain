## Factors for Zone 4 (skills fac.*): list every factor of a number, build a rectangle with a given
## number of gems and rows, and say whether one number is a factor of another.
## Pure: only the passed-in rng is used.
##
## Modes (params.mode):
##   list         "Find all {k} factors of {n}." Drag the factors onto an unordered tile board
##                (answer: the factors, smallest first). Wrong answers are whole boards that
##                leave out 1 and n (missing_one_and_n), leave out a middle pair (skip_middle_pair)
##                or swap in a multiple of n (multiple_not_factor).
##   rectangles   "Build a rectangle with {rows} rows and {n} gems in all." on the array builder
##                (answer: {rows, cols}). Wrong answers swap rows and columns or are one column off.
##   check        "Is {d} a factor of {n}?" Yes or no.
##   split        "Split {n} so one piece is {a}." Drag the pickaxe to a split point on the boulder's
##                factor rail (BoulderSplit; answer: [smaller, larger]). The wrong answers are the
##                boulder's other factor pairs (wrong_split). n has at least two pairs.
class_name FactorsGenerator
extends RefCounted

## The tile board holds at most this many tiles.
const MAX_TILES: int = 8
## A number with more factors than this leaves no room for a wrong tile.
const MAX_LIST_FACTORS: int = 7
const BUILDER_SIDE: int = 6
## Longest hop line a hint draws (more hops is just a ruler).
const MAX_HOPS: int = 24
## A ruler is labeled every this many.
const RULER_STEP: int = 5
const BIGGEST_MULTIPLE: int = 100
const PROMPT_LIST: StringName = &"z4.fac.prompt_list"
const PROMPT_RECTANGLE: StringName = &"z4.fac.prompt_rectangle"
const PROMPT_CHECK: StringName = &"z4.fac.prompt_check"
const PROMPT_SPLIT: StringName = &"z4.fac.prompt_split"
## The boulder splits a number of at least this size and with two or more factor pairs.
const SPLIT_FIRST: int = 8


static func generate(skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Problem:
	return _make(skill, params, rng, true)


static func _make(skill: Skill, params: Dictionary, rng: RandomNumberGenerator, with_hints: bool) -> Problem:
	var mode: String = String(params.get("mode", "list"))
	var problem: Problem = GeneratorKit.new_problem(skill, params, GeneratorKit.pick_representation(skill, params))
	var model: Dictionary
	var example_line: Callable
	match mode:
		"list":
			model = _list(problem, skill, params, rng)
			example_line = _list_line_of
		"rectangles":
			model = _rectangle(problem, skill, params, rng)
			example_line = _rectangle_line_of
		"check":
			model = _check(problem, skill, params, rng)
			example_line = _check_line_of
		"split":
			model = _split(problem, skill, params, rng)
			example_line = _split_line_of
		_:
			push_error("FactorsGenerator: unknown mode '%s'" % mode)
			return problem
	if with_hints:
		var example: Problem = GeneratorKit.make_example(
			func(sub: RandomNumberGenerator) -> Problem: return _make(skill, params, sub, false), problem, rng)
		GeneratorKit.add_hints(problem, model, example, example_line.call(example))
	return problem


# --- Pictures ------------------------------------------------------------------------------


## Hops of `size` from 0 along a line that ends at `end`: the multiples of `size` up to `end`.
## One hop per multiple; a ruler (no hops) when there would be too many to draw.
static func _hops_to(size: int, end: int, markers: Array[int]) -> Dictionary:
	var count: int = floori(float(end) / float(size))
	if count < 1 or count > MAX_HOPS:
		return GeneratorKit.number_line(0, end, RULER_STEP, markers, [])
	var line: Dictionary = GeneratorKit.number_line(0, end, size, markers, [])
	var jumps: Array[Dictionary] = []
	for index: int in count:
		jumps.append({"from": index * size, "to": (index + 1) * size})
	line["jumps"] = jumps
	return line


# --- list ------------------------------------------------------------------------------------


## "Find all {k} factors of {n}." The answer is the sorted factors; the tiles are the factors plus
## whatever extra numbers the wrong answers need (at most 8 tiles in all).
static func _list(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var low: int = int(params.get("min", 4))
	var high: int = GeneratorKit.eased_max(low, int(params.get("max", 30)), GeneratorKit.difficulty_of(params), 4)
	var candidates: Array[int] = []
	for n: int in range(low, high + 1):
		if not MathUtil.is_prime(n) and MathUtil.factors(n).size() <= MAX_LIST_FACTORS:
			candidates.append(n)
	var n: int = candidates[rng.randi_range(0, candidates.size() - 1)]
	var all: Array[int] = MathUtil.factors(n)
	var middle: Array[int] = GeneratorKit.ints_of(all.slice(1, all.size() - 1))
	problem.prompt_line_id = PROMPT_LIST
	problem.prompt_params = {"k": all.size(), "n": n}
	problem.answer = all
	# Two numbers that are not factors (they may sit just above n for tiny n).
	var strangers: Array[int] = []
	for x: int in range(2, n + 4):
		if n % x != 0:
			strangers.append(x)
	strangers = GeneratorKit.shuffled_ints(strangers, rng)
	# missing_one_and_n: only the middle factors, topped up with two strangers.
	var topped_up: Array[int] = middle.duplicate()
	topped_up.append(strangers[0])
	topped_up.append(strangers[1])
	_try_add_board(problem, skill, topped_up, &"missing_one_and_n")
	# skip_middle_pair: one middle pair (f and n / f) is left out and strangers fill its place.
	var pair: Array[int] = _middle_pair(n, middle, rng)
	var kept: Array[int] = []
	for factor: int in all:
		if not pair.has(factor):
			kept.append(factor)
	for index: int in pair.size():
		kept.append(strangers[index])
	_try_add_board(problem, skill, kept, &"skip_middle_pair")
	# multiple_not_factor: one middle factor is swapped for a multiple of n.
	var swapped: Array[int] = all.duplicate()
	swapped.erase(middle[rng.randi_range(0, middle.size() - 1)])
	swapped.append(n * 2)
	_try_add_board(problem, skill, swapped, &"multiple_not_factor")
	var tiles: Array[int] = GeneratorKit.tile_pool(problem)
	problem.meta = {"tile_board": {"tiles": tiles, "slots": all.size(), "ordered": false}}
	return _smallest_pair_model(n, middle)


## Adds a wrong board (sorted) unless the tile board would need more than 8 tiles.
static func _try_add_board(problem: Problem, skill: Skill, board: Array[int], misconception: StringName) -> void:
	board.sort()
	if GeneratorKit.pool_size_with(problem, board) <= MAX_TILES:
		GeneratorKit.add_distractor(problem, skill, board, misconception)


## A factor pair of n made of middle factors, f and n / f with f <= n / f (a square's middle is one
## number). Picked with the rng.
static func _middle_pair(n: int, middle: Array[int], rng: RandomNumberGenerator) -> Array[int]:
	var starts: Array[int] = []
	for factor: int in middle:
		if factor * factor <= n:
			starts.append(factor)
	var start: int = starts[rng.randi_range(0, starts.size() - 1)]
	var other: int = _exact_div(n, start)
	var pair: Array[int] = [start]
	if other != start:
		pair.append(other)
	return pair


## 12 / 3 without the integer-division warning (the divisor always divides).
static func _exact_div(a: int, b: int) -> int:
	return floori(float(a) / float(b))


## The rung 2 picture: the first middle pair as a rectangle, or hops of the smallest middle factor.
static func _smallest_pair_model(n: int, middle: Array[int]) -> Dictionary:
	var f: int = middle[0]
	var partner: int = _exact_div(n, f)
	if partner <= 10 and f <= 10:
		return GeneratorKit.array_picture(f, partner, true)
	return _hops_to(f, n, [n])


static func _list_line_of(example: Problem) -> Dictionary:
	var n: int = example.prompt_params["n"]
	var factors: Array[int] = MathUtil.factors(n)
	var a: int = factors[1]
	return {"line_id": &"z4.hint.example_factors", "params": {"a": a, "b": _exact_div(n, a), "n": n}}


# --- rectangles ------------------------------------------------------------------------------


## "Build a rectangle with {rows} rows and {n} gems in all." The rows are 2 to 6 and the columns
## 1 to 6 (the builder is 6 by 6), so the columns are n / rows.
static func _rectangle(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var top: int = GeneratorKit.eased_max(2, mini(int(params.get("max_side", BUILDER_SIDE)), BUILDER_SIDE), GeneratorKit.difficulty_of(params), 1)
	var rows: int = rng.randi_range(2, top)
	var cols: int = rng.randi_range(1, top)
	var total: int = rows * cols
	problem.prompt_line_id = PROMPT_RECTANGLE
	problem.prompt_params = {"rows": rows, "n": total}
	problem.answer = {"rows": rows, "cols": cols}
	problem.meta = {"array_builder": {"max_rows": BUILDER_SIDE, "max_cols": BUILDER_SIDE}}
	if rows != cols:
		GeneratorKit.add_distractor(problem, skill, {"rows": cols, "cols": rows}, &"rows_cols_swapped")
	var neighbours: Array[int] = [cols + 1, cols - 1]
	if rng.randi_range(0, 1) == 0:
		neighbours.reverse()
	for value: int in neighbours:
		if value >= 1 and value <= BUILDER_SIDE:
			GeneratorKit.add_distractor(problem, skill, {"rows": rows, "cols": value}, &"off_by_one")
	return GeneratorKit.array_picture(rows, cols, true)


static func _rectangle_line_of(example: Problem) -> Dictionary:
	var rows: int = example.answer["rows"]
	var cols: int = example.answer["cols"]
	return {"line_id": &"z4.hint.example_rectangle", "params": {"rows": rows, "cols": cols, "n": rows * cols}}


# --- split -----------------------------------------------------------------------------------


## The factor pairs a x b = n with 2 <= a <= b, smallest first.
static func _pairs_of(n: int) -> Array[Vector2i]:
	var pairs: Array[Vector2i] = []
	var a: int = 2
	while a * a <= n:
		if n % a == 0:
			pairs.append(Vector2i(a, _exact_div(n, a)))
		a += 1
	return pairs


## "Split {n} so one piece is {a}." The boulder's rail has every factor pair of n; the right one has
## {a} in it. The other pairs are the wrong answers (wrong_split).
static func _split(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var top: int = GeneratorKit.eased_max(SPLIT_FIRST + 4, int(params.get("max", 36)), GeneratorKit.difficulty_of(params))
	var n: int = 12
	for attempt: int in 200:
		var candidate: int = rng.randi_range(SPLIT_FIRST, top)
		if _pairs_of(candidate).size() >= 2:
			n = candidate
			break
	var pairs: Array[Vector2i] = _pairs_of(n)
	var chosen: Vector2i = pairs[rng.randi_range(0, pairs.size() - 1)]
	var shown: int = chosen.x if rng.randi_range(0, 1) == 0 else chosen.y
	problem.prompt_line_id = PROMPT_SPLIT
	problem.prompt_params = {"n": n, "a": shown}
	problem.answer = [chosen.x, chosen.y]
	var factors: Array[int] = []
	for pair: Vector2i in pairs:
		factors.append(pair.x)
		if pair.y != pair.x:
			factors.append(pair.y)
	factors.sort()
	problem.meta = {"boulder_split": {"value": n, "factors": factors}}
	for pair: Vector2i in pairs:
		if pair != chosen:
			GeneratorKit.add_distractor(problem, skill, [pair.x, pair.y], &"wrong_split")
	return _hops_to(chosen.x, n, [n])


static func _split_line_of(example: Problem) -> Dictionary:
	return {"line_id": &"z4.hint.example_split", "params": {"n": example.prompt_params["n"], "a": example.answer[0], "b": example.answer[1]}}


# --- check -----------------------------------------------------------------------------------


## "Is {d} a factor of {n}?" Four kinds, each with the mistake a "wrong" answer stands for:
##   a middle factor of n      yes (wrong: no, no_check_made);
##   1 or n itself             yes (wrong: no, missing_one_and_n);
##   a smaller non-factor      no (wrong: yes, no_check_made);
##   a multiple of n (2n, 3n)  no (wrong: yes, multiple_not_factor).
static func _check(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var low: int = int(params.get("min", 6))
	var high: int = GeneratorKit.eased_max(low, int(params.get("max", 48)), GeneratorKit.difficulty_of(params), 6)
	var pictorial: bool = problem.representation == &"pictorial"
	var roll: int = rng.randi_range(0, 99)
	var n: int
	var d: int
	var is_factor: bool
	var wrong: StringName
	if roll < 30:
		var composites: Array[int] = []
		for value: int in range(low, high + 1):
			if not MathUtil.is_prime(value):
				composites.append(value)
		n = composites[rng.randi_range(0, composites.size() - 1)]
		var all: Array[int] = MathUtil.factors(n)
		d = all[rng.randi_range(1, all.size() - 2)]
		is_factor = true
		wrong = &"no_check_made"
	elif roll < 45:
		n = rng.randi_range(low, high)
		d = n if pictorial or rng.randi_range(0, 1) == 0 else 1
		is_factor = true
		wrong = &"missing_one_and_n"
	elif roll < 75:
		n = rng.randi_range(low, high)
		var strangers: Array[int] = []
		for value: int in range(2, n):
			if n % value != 0:
				strangers.append(value)
		d = strangers[rng.randi_range(0, strangers.size() - 1)]
		is_factor = false
		wrong = &"no_check_made"
	else:
		n = rng.randi_range(low, mini(high, floori(BIGGEST_MULTIPLE / 2.0)))
		d = n * rng.randi_range(2, mini(3, floori(float(BIGGEST_MULTIPLE) / float(n))))
		is_factor = false
		wrong = &"multiple_not_factor"
	problem.prompt_line_id = PROMPT_CHECK
	problem.prompt_params = {"d": d, "n": n}
	problem.answer = is_factor
	problem.meta = {"label_lines": GeneratorKit.yes_no_labels()}
	GeneratorKit.add_distractor(problem, skill, not is_factor, wrong)
	var line: Dictionary = _check_line(d, n)
	if pictorial:
		problem.visual = line
	return line


## Hops of d along a line from 0, with a marker on n: a factor lands on it. A d bigger than n is one
## hop that sails past; d = 1 is the plain ruler.
static func _check_line(d: int, n: int) -> Dictionary:
	if d > n:
		var line: Dictionary = GeneratorKit.number_line(0, d, d, [n], [])
		line["jumps"] = [{"from": 0, "to": d}]
		return line
	return _hops_to(d, n, [n])


static func _check_line_of(example: Problem) -> Dictionary:
	var d: int = example.prompt_params["d"]
	var n: int = example.prompt_params["n"]
	if example.answer:
		return {"line_id": &"z4.hint.example_factor_yes", "params": {"d": d, "k": _exact_div(n, d), "n": n}}
	return {"line_id": &"z4.hint.example_factor_no", "params": {"d": d, "n": n}}
