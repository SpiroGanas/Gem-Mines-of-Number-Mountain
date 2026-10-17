## Helpers shared by every problem generator. Pure functions, no nodes, no globals.
##
## The rules every generator follows (CLAUDE.md "Problem generators"):
##  - use only the rng it is given, never the global randi(), so a seed gives the same problem;
##  - every distractor names a misconception from the skill's own list, never equals the answer,
##    and never repeats another distractor's value;
##  - fill all four hint rungs.
class_name GeneratorKit
extends RefCounted

## Each step below difficulty 0 scales a generator's upper limit by this much.
const EASIER_FACTOR: float = 0.7


## The representation to use: params.representation if the skill lists it, else the skill's first.
static func pick_representation(skill: Skill, params: Dictionary) -> StringName:
	var wanted: StringName = StringName(str(params.get("representation", "")))
	return wanted if skill.representations.has(wanted) else skill.first_representation()


## The difficulty offset: 0 is the skill as authored, negative is easier. Hint rung 4 lowers it.
static func difficulty_of(params: Dictionary) -> int:
	return int(params.get("difficulty", 0))


## An upper limit eased by difficulty: `high` at 0, 70% of it one step easier, and so on, but
## never closer than `minimum_span` to `low`.
static func eased_max(low: int, high: int, difficulty: int, minimum_span: int = 2) -> int:
	if difficulty >= 0:
		return high
	var scaled: int = int(round(float(high) * pow(EASIER_FACTOR, float(-difficulty))))
	return clampi(scaled, low + minimum_span, high)


## A problem with the fields every generator sets.
static func new_problem(skill: Skill, params: Dictionary, representation: StringName) -> Problem:
	var problem: Problem = Problem.new()
	problem.skill_id = skill.id
	problem.representation = representation
	problem.answer_modes = skill.answer_modes.duplicate()
	problem.params = params.duplicate(true)
	return problem


## Adds a named wrong answer unless it is invalid: equal to the answer, a repeat of an earlier
## distractor, or a negative whole number. `skill.misconceptions` must list the name.
static func add_distractor(problem: Problem, skill: Skill, value: Variant, misconception: StringName) -> void:
	assert(skill.misconceptions.has(misconception), "%s is not a misconception of %s" % [misconception, skill.id])
	if value is int and value < 0:
		return
	var canon: Variant = Problem.canonical(value)
	if canon == Problem.canonical(problem.answer):
		return
	for existing: Dictionary in problem.distractors:
		if Problem.canonical(existing["value"]) == canon:
			return
	problem.distractors.append({"value": value, "misconception": misconception})


# --- Digits (no integer division, so the editor stays warning-free) ------------------------


static func hundreds_digit(n: int) -> int:
	return floori(n / 100.0)


static func tens_digit(n: int) -> int:
	return floori(n / 10.0) % 10


static func ones_digit(n: int) -> int:
	return n % 10


## Swaps the last two digits: 34 becomes 43, 107 becomes 170, 40 becomes 4. Numbers under 10
## are unchanged. This is the classic digit-swap misconception.
static func swap_digits(n: int) -> int:
	if n < 10:
		return n
	return hundreds_digit(n) * 100 + ones_digit(n) * 10 + tens_digit(n)


# --- Visuals ---------------------------------------------------------------------------------


static func pile(hundreds: int, tens: int, ones: int) -> Dictionary:
	return {"hundreds": hundreds, "tens": tens, "ones": ones}


## The pile that shows `n` as hundreds, tens and ones.
static func pile_of(n: int) -> Dictionary:
	return pile(hundreds_digit(n), tens_digit(n), ones_digit(n))


static func gem_piles(piles: Array[Dictionary]) -> Dictionary:
	return {"type": "gem_piles", "piles": piles}


static func ten_frame(count: int, frames: int) -> Dictionary:
	return {"type": "ten_frame", "count": count, "frames": frames}


## A number line from `low` to `high`. A label is drawn at every `labeled_every` (a label at a
## value in `blanks` is left empty). `markers` are values to point at.
static func number_line(low: int, high: int, labeled_every: int, markers: Array[int], blanks: Array[int]) -> Dictionary:
	return {"type": "number_line", "min": low, "max": high, "labeled_every": labeled_every, "markers": markers, "blanks": blanks}


## A line window that holds every value in `values`, rounded out to whole tens (at least 10 wide).
static func window_around(values: Array[int], floor_at: int = 0, ceiling_at: int = 120) -> Vector2i:
	var low: int = values.min()
	var high: int = values.max()
	var start: int = maxi(floori(low / 10.0) * 10, floor_at)
	var end: int = mini(ceili(high / 10.0) * 10, ceiling_at)
	if end - start < 10:
		end = mini(start + 10, ceiling_at)
		start = maxi(end - 10, floor_at)
	return Vector2i(start, end)


# --- Random helpers (rng only) ---------------------------------------------------------------


## A Fisher-Yates shuffle of integers driven only by `rng`.
static func shuffled_ints(values: Array[int], rng: RandomNumberGenerator) -> Array[int]:
	var items: Array[int] = values.duplicate()
	for i: int in range(items.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var held: int = items[i]
		items[i] = items[j]
		items[j] = held
	return items


# --- Hints -----------------------------------------------------------------------------------


## Fills hint_steps with the four rungs:
##   1 repeat_highlight  the prompt again, with its numbers highlighted;
##   2 visual_model      a picture of the problem (`model_visual`);
##   3 worked_example    a different problem of the same skill, solved (`example`);
##   4 easier_problem    the same skill with difficulty lowered by one (the engine regenerates).
## `example` is a Problem from the same generator and `example_answer` is {line_id, params}
## for the line that states its answer.
static func add_hints(problem: Problem, model_visual: Dictionary, example: Problem, example_answer: Dictionary) -> void:
	problem.hint_steps = [
		{
			"kind": &"repeat_highlight", "line_id": problem.prompt_line_id,
			"params": problem.prompt_params.duplicate(), "visual": {},
			"highlight": problem.prompt_params.keys(),
		},
		{"kind": &"visual_model", "line_id": &"bolt.hint.show_model", "params": {}, "visual": model_visual},
		{
			"kind": &"worked_example", "line_id": &"bolt.hint.worked_example", "params": {}, "visual": example.visual,
			"example": {
				"prompt_line_id": example.prompt_line_id, "prompt_params": example.prompt_params.duplicate(),
				"answer": example.answer, "answer_line_id": example_answer["line_id"], "answer_params": example_answer["params"],
			},
		},
		{
			"kind": &"easier_problem", "line_id": &"bolt.hint.easier", "params": {}, "visual": {},
			"easier_params": {"difficulty": difficulty_of(problem.params) - 1},
		},
	]


## A second problem of the same skill for the worked example. It is drawn from a rng seeded from
## the main one (so it is reproducible). It is never the identical problem, and it prefers one
## with a different answer so the example does not give the answer away (a two-way question such
## as "which pile is bigger" can only sometimes manage that).
static func make_example(make: Callable, problem: Problem, rng: RandomNumberGenerator) -> Problem:
	var same_answer: Problem = null
	var last: Problem = null
	for attempt: int in 12:
		var sub_rng: RandomNumberGenerator = RandomNumberGenerator.new()
		sub_rng.seed = rng.randi()
		var candidate: Problem = make.call(sub_rng)
		last = candidate
		var identical: bool = candidate.prompt_line_id == problem.prompt_line_id \
			and candidate.prompt_params == problem.prompt_params and candidate.visual == problem.visual
		if identical:
			continue
		if Problem.canonical(candidate.answer) != Problem.canonical(problem.answer):
			return candidate
		if same_answer == null:
			same_answer = candidate
	return same_answer if same_answer != null else last
