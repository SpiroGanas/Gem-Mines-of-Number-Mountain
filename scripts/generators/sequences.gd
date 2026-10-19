## Sequences for Zone 9, Pattern Grotto (skills seq.*): rows of crystal tiles that grow by a rule.
## params.mode picks the question:
##   next       {a}, {b}, {c}, {d}: what comes next? An arithmetic sequence (the same step is added).
##   missing    five terms of an arithmetic sequence with one inside term blank: what is missing?
##   rule       five terms: what is added each time? The answer is the step; its button reads "Add 4"
##              (meta.label_line).
##   geometric  three or four terms that multiply by the same ratio (params.ratios): what comes next?
##              The answer stays at or below params.max_value.
##   classify   four terms: does the sequence add or multiply the same number? The answer is
##              "arithmetic" or "geometric"; the buttons read in words (meta.label_lines).
## Explorer terms never go below zero: every sequence grows from a start of at least 1. Concrete and
## pictorial problems of next, missing and geometric are answered on the pattern wall
## (meta.pattern_wall: drag a crystal tile into the gap), abstract ones on the number pad.
## Pure: only the passed-in rng is used.
##
## The named mistakes:
##   added_wrong_step         added one more or one less than the step;
##   repeated_last_term       wrote the last shown term again;
##   averaged_neighbors_wrong added the gap's two neighbors and did not halve;
##   confused_start_and_step  gave the first term as the step;
##   added_ratio              added the ratio instead of multiplying (last + r);
##   off_by_one_exponent      multiplied one time too many (last × r × r);
##   continued_by_adding      kept adding the last difference (last + (last - before));
##   swapped_types            called an adding sequence multiplying, or the other way round;
##   missed_the_pattern       said the sequence has no rule.
class_name SequenceGenerator
extends RefCounted

const ARITHMETIC: StringName = &"arithmetic"
const GEOMETRIC: StringName = &"geometric"
const NEITHER: StringName = &"neither"
## The buttons of a classify problem, in words.
const CLASSIFY_LABELS: Dictionary = {"arithmetic": "z9.classify.adds", "geometric": "z9.classify.multiplies", "neither": "z9.classify.neither"}
const MISSING_PROMPTS: Array[StringName] = [&"", &"z9.seq.prompt_missing_1", &"z9.seq.prompt_missing_2", &"z9.seq.prompt_missing_3"]
const KEYS: Array[String] = ["a", "b", "c", "d", "e"]
## The biggest start of a geometric sequence (small starts keep the products in reach).
const GEOMETRIC_MAX_START: int = 9
## The pad takes up to four digits for a geometric answer (1000 at most), whatever the answer's length.
const GEOMETRIC_PAD_DIGITS: int = 4


static func generate(skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Problem:
	return _make(skill, params, rng, true)


static func _make(skill: Skill, params: Dictionary, rng: RandomNumberGenerator, with_hints: bool) -> Problem:
	var problem: Problem = GeneratorKit.new_problem(skill, params, GeneratorKit.pick_representation(skill, params))
	var model: Dictionary = {}
	var example_line: Callable
	match str(params.get("mode", "next")):
		"missing":
			model = _missing(problem, skill, params, rng)
			example_line = _missing_line
		"rule":
			model = _rule(problem, skill, params, rng)
			example_line = _rule_line
		"geometric":
			model = _geometric(problem, skill, params, rng)
			example_line = _geometric_line
		"classify":
			model = _classify(problem, skill, params, rng)
			example_line = _classify_line
		_:
			model = _next(problem, skill, params, rng)
			example_line = _next_line
	if with_hints:
		var example: Problem = GeneratorKit.make_example(
			func(sub: RandomNumberGenerator) -> Problem: return _make(skill, params, sub, false), problem, rng)
		GeneratorKit.add_hints(problem, model, example, example_line.call(example))
	return problem


# --- Pictures and the pattern wall ---------------------------------------------------------------


## A `pattern` picture: a row of tiles with `terms`; the tiles at `blanks` show "?". `steps` (one fewer
## than the terms, or empty) are drawn between the tiles as "+3" (step_op "plus") or "×2" ("times").
static func pattern(terms: Array[int], blanks: Array[int], style: String, steps: Array[int] = [], step_op: String = "plus") -> Dictionary:
	var picture: Dictionary = {"type": "pattern", "terms": terms.duplicate(), "blanks": blanks.duplicate(), "style": style}
	if not steps.is_empty():
		picture["steps"] = steps.duplicate()
		picture["step_op"] = step_op
	return picture


## The style of a problem's picture: crystal tiles for concrete, plain numbers otherwise.
static func style_for(problem: Problem) -> String:
	return "crystals" if problem.representation == &"concrete" else "numbers"


## meta.pattern_wall for a problem whose int answer fills the gap at `blank` of `terms`: the terms with
## null at the gap, and the crystal tiles to drag (the answer and every wrong answer, smallest first).
## Call it after the distractors are added.
static func add_wall(problem: Problem, terms: Array[int], blank: int) -> void:
	var shown: Array = []
	for index: int in terms.size():
		shown.append(null if index == blank else terms[index])
	var tiles: Array[int] = [int(problem.answer)]
	for value: Variant in problem.distractor_values():
		if not tiles.has(int(value)):
			tiles.append(int(value))
	tiles.sort()
	problem.meta["pattern_wall"] = {"terms": shown, "tiles": tiles}


## Every term from `start` adding `step`, `length` of them.
static func arithmetic_terms(start: int, step: int, length: int) -> Array[int]:
	var terms: Array[int] = []
	for index: int in length:
		terms.append(start + index * step)
	return terms


## Every term from `start` multiplying by `ratio`, `length` of them.
static func geometric_terms(start: int, ratio: int, length: int) -> Array[int]:
	var terms: Array[int] = []
	var value: int = start
	for index: int in length:
		terms.append(value)
		value *= ratio
	return terms


static func _params_of(terms: Array[int], count: int) -> Dictionary:
	var named: Dictionary = {}
	for index: int in count:
		named[KEYS[index]] = terms[index]
	return named


## A start and a step for an arithmetic sequence, eased by difficulty (both at least 1).
static func _start_and_step(params: Dictionary, rng: RandomNumberGenerator) -> Vector2i:
	var difficulty: int = GeneratorKit.difficulty_of(params)
	var start: int = rng.randi_range(1, GeneratorKit.eased_max(1, int(params.get("max_start", 20)), difficulty, 4))
	var step: int = rng.randi_range(1, GeneratorKit.eased_max(1, int(params.get("max_step", 9)), difficulty, 2))
	return Vector2i(start, step)


static func _steps_of(step: int, count: int) -> Array[int]:
	var steps: Array[int] = []
	for index: int in count:
		steps.append(step)
	return steps


# --- Arithmetic ------------------------------------------------------------------------------------


static func _next(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var pick: Vector2i = _start_and_step(params, rng)
	var terms: Array[int] = arithmetic_terms(pick.x, pick.y, 5) # four shown, the fifth asked
	var last: int = terms[3]
	problem.prompt_line_id = &"z9.seq.prompt_next"
	problem.prompt_params = _params_of(terms, 4)
	problem.answer = terms[4]
	var off: int = 1 if pick.y == 1 or rng.randi_range(0, 1) == 0 else -1
	GeneratorKit.add_distractor(problem, skill, last + pick.y + off, &"added_wrong_step")
	GeneratorKit.add_distractor(problem, skill, last, &"repeated_last_term")
	problem.visual = pattern(terms, [4], style_for(problem))
	if problem.representation == &"concrete":
		add_wall(problem, terms, 4)
	return pattern(terms, [4], style_for(problem), _steps_of(pick.y, 4))


static func _next_line(example: Problem) -> Dictionary:
	var p: Dictionary = example.prompt_params
	return {"line_id": &"z9.hint.example_next", "params": {"s": int(p["b"]) - int(p["a"]), "d": p["d"], "e": example.answer}}


static func _missing(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var pick: Vector2i = _start_and_step(params, rng)
	var terms: Array[int] = arithmetic_terms(pick.x, pick.y, 5)
	var blank: int = rng.randi_range(1, 3)
	problem.prompt_line_id = MISSING_PROMPTS[blank]
	for index: int in 5:
		if index != blank:
			problem.prompt_params[KEYS[index]] = terms[index]
	problem.answer = terms[blank]
	var off: int = 1 if pick.y == 1 or rng.randi_range(0, 1) == 0 else -1
	GeneratorKit.add_distractor(problem, skill, terms[blank - 1] + pick.y + off, &"added_wrong_step")
	GeneratorKit.add_distractor(problem, skill, terms[blank - 1] + terms[blank + 1], &"averaged_neighbors_wrong")
	problem.visual = pattern(terms, [blank], style_for(problem))
	if problem.representation != &"abstract":
		add_wall(problem, terms, blank)
	return pattern(terms, [blank], "numbers", _steps_of(pick.y, 4))


static func _missing_line(example: Problem) -> Dictionary:
	var p: Dictionary = example.prompt_params
	var step: int = int(p["e"]) - int(p["d"]) if p.has("d") else floori((int(p["e"]) - int(p["c"])) / 2.0)
	return {"line_id": &"z9.hint.example_missing", "params": {"s": step, "m": example.answer}}


static func _rule(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var pick: Vector2i = _start_and_step(params, rng)
	# The start differs from the step, so "gave the start" is a different answer; with a step of 1 it
	# also differs from 2 (the only other near miss), so there are always two wrong answers to tap.
	while pick.x == pick.y or (pick.y == 1 and pick.x == 2):
		pick.x += 1
	var terms: Array[int] = arithmetic_terms(pick.x, pick.y, 5)
	problem.prompt_line_id = &"z9.seq.prompt_rule"
	problem.prompt_params = _params_of(terms, 5)
	problem.answer = pick.y
	problem.meta = {"label_line": "z9.seq.rule_add"}
	GeneratorKit.add_distractor(problem, skill, pick.x, &"confused_start_and_step")
	GeneratorKit.add_distractor(problem, skill, pick.y + 1, &"added_wrong_step")
	if pick.y > 1:
		GeneratorKit.add_distractor(problem, skill, pick.y - 1, &"added_wrong_step")
	return pattern(terms, [], "numbers", _steps_of(pick.y, 4))


static func _rule_line(example: Problem) -> Dictionary:
	return {"line_id": &"z9.hint.example_rule", "params": {"s": example.answer}}


# --- Geometric -------------------------------------------------------------------------------------


## A start and a ratio whose fourth term (index 3) stays at or below max_value, with three or four terms
## shown: four when the fifth term fits too.
static func geometric_pick(params: Dictionary, rng: RandomNumberGenerator) -> Vector3i:
	var top: int = GeneratorKit.eased_max(8, int(params.get("max_value", 1000)), GeneratorKit.difficulty_of(params), 8)
	var options: Array[Vector2i] = []
	for ratio: Variant in params.get("ratios", [2, 3, 5, 10]):
		for start: int in range(1, GEOMETRIC_MAX_START + 1):
			if start * int(ratio) * int(ratio) * int(ratio) <= top:
				options.append(Vector2i(start, int(ratio)))
	if options.is_empty():
		options.append(Vector2i(1, 2)) # 1, 2, 4 then 8: always within the eased floor
	var pick: Vector2i = options[rng.randi_range(0, options.size() - 1)]
	var shown: int = 4 if pick.x * pick.y * pick.y * pick.y * pick.y <= top else 3
	return Vector3i(pick.x, pick.y, shown)


static func _geometric(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var pick: Vector3i = geometric_pick(params, rng)
	var ratio: int = pick.y
	var shown: int = pick.z
	var terms: Array[int] = geometric_terms(pick.x, ratio, shown + 1)
	var last: int = terms[shown - 1]
	problem.prompt_line_id = &"z9.seq.prompt_next" if shown == 4 else &"z9.seq.prompt_next3"
	problem.prompt_params = _params_of(terms, shown)
	problem.answer = terms[shown]
	problem.meta = {"pad_digits": GEOMETRIC_PAD_DIGITS}
	GeneratorKit.add_distractor(problem, skill, last + ratio, &"added_ratio")
	GeneratorKit.add_distractor(problem, skill, last * ratio * ratio, &"off_by_one_exponent")
	GeneratorKit.add_distractor(problem, skill, last + (last - terms[shown - 2]), &"continued_by_adding")
	problem.visual = pattern(terms, [shown], style_for(problem))
	if problem.representation == &"concrete":
		add_wall(problem, terms, shown)
	return pattern(terms, [shown], "numbers", _steps_of(ratio, shown), "times")


static func _geometric_line(example: Problem) -> Dictionary:
	var p: Dictionary = example.prompt_params
	var last: int = int(p["d"]) if p.has("d") else int(p["c"])
	return {"line_id": &"z9.hint.example_geometric", "params": {"r": floori(int(p["b"]) / float(int(p["a"]))), "d": last, "e": example.answer}}


# --- Classify --------------------------------------------------------------------------------------


static func _classify(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var kind: StringName = ARITHMETIC if rng.randi_range(0, 1) == 0 else GEOMETRIC
	var terms: Array[int] = []
	var steps: Array[int] = []
	var op: String = "plus"
	if kind == ARITHMETIC:
		var pick: Vector2i = _start_and_step(params, rng)
		terms = arithmetic_terms(pick.x, pick.y, 4)
		steps = _steps_of(pick.y, 3)
	else:
		var pick: Vector3i = geometric_pick(params, rng)
		terms = geometric_terms(pick.x, pick.y, 4)
		steps = _steps_of(pick.y, 3)
		op = "times"
	problem.prompt_line_id = &"z9.seq.prompt_classify"
	problem.prompt_params = _params_of(terms, 4)
	problem.answer = kind
	problem.meta = {"label_lines": CLASSIFY_LABELS.duplicate()}
	GeneratorKit.add_distractor(problem, skill, GEOMETRIC if kind == ARITHMETIC else ARITHMETIC, &"swapped_types")
	GeneratorKit.add_distractor(problem, skill, NEITHER, &"missed_the_pattern")
	problem.visual = pattern(terms, [], "numbers")
	return pattern(terms, [], "numbers", steps, op)


static func _classify_line(example: Problem) -> Dictionary:
	var p: Dictionary = example.prompt_params
	var a: int = int(p["a"])
	var b: int = int(p["b"])
	if example.answer == ARITHMETIC:
		return {"line_id": &"z9.hint.example_classify_adds", "params": {"a": a, "b": b, "c": p["c"], "s": b - a}}
	return {"line_id": &"z9.hint.example_classify_multiplies", "params": {"a": a, "b": b, "c": p["c"], "r": floori(b / float(a))}}
