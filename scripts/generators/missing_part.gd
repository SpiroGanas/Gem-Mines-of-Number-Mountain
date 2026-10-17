## Missing-number problems for Zone 2 (skills eq.missing_addend.to_20, eq.missing_subtrahend.to_20):
## "{a} + ? = {c}" and "{c} - ? = {a}". Both answers are c - a, the part that is not shown.
## Pure: only the passed-in rng is used.
class_name MissingPartGenerator
extends RefCounted

## The smallest whole: 1 + 1 = 2, so the known part and the answer are both at least 1.
const SMALLEST_WHOLE: int = 2


static func generate(skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Problem:
	return _make(skill, params, rng, true)


static func _make(skill: Skill, params: Dictionary, rng: RandomNumberGenerator, with_hints: bool) -> Problem:
	var mode: String = String(params.get("mode", "addend"))
	var problem: Problem = GeneratorKit.new_problem(skill, params, GeneratorKit.pick_representation(skill, params))
	var model: Dictionary
	var example_line: Callable
	match mode:
		"addend":
			model = _addend(problem, skill, params, rng)
			example_line = _addend_line_of
		"subtrahend":
			model = _subtrahend(problem, skill, params, rng)
			example_line = _subtrahend_line_of
		_:
			push_error("MissingPartGenerator: unknown mode '%s'" % mode)
			return problem
	if with_hints:
		var example: Problem = GeneratorKit.make_example(
			func(sub: RandomNumberGenerator) -> Problem: return _make(skill, params, sub, false), problem, rng)
		GeneratorKit.add_hints(problem, model, example, example_line.call(example))
	return problem


static func _addend_line_of(example: Problem) -> Dictionary:
	return {"line_id": &"z2.hint.example_missing_addend", "params": {"a": example.prompt_params["a"], "n": example.answer, "c": example.prompt_params["c"]}}


static func _subtrahend_line_of(example: Problem) -> Dictionary:
	return {"line_id": &"z2.hint.example_missing_subtrahend", "params": {"c": example.prompt_params["c"], "n": example.answer, "a": example.prompt_params["a"]}}


## The whole c (2 to the eased max) and the shown part a (1 to c - 1), as (a, c).
static func _part_and_whole(params: Dictionary, rng: RandomNumberGenerator) -> Vector2i:
	var top: int = GeneratorKit.eased_max(SMALLEST_WHOLE, int(params.get("max", 20)), GeneratorKit.difficulty_of(params))
	var c: int = rng.randi_range(SMALLEST_WHOLE, top)
	var a: int = rng.randi_range(1, c - 1)
	return Vector2i(a, c)


## {a} + ? = {c} (pictorial): a ten-frame shows the a gems there are. The hint fills in the rest of
## the c in a second color.
static func _addend(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var numbers: Vector2i = _part_and_whole(params, rng)
	var a: int = numbers.x
	var c: int = numbers.y
	var answer: int = c - a
	problem.prompt_line_id = &"z2.eq.prompt_missing_addend"
	problem.prompt_params = {"a": a, "c": c}
	problem.answer = answer
	problem.visual = GeneratorKit.ten_frame(a, 2)
	GeneratorKit.add_distractor(problem, skill, a + c, &"added_both")
	GeneratorKit.add_distractor(problem, skill, answer - 1, &"off_by_one")
	GeneratorKit.add_distractor(problem, skill, answer + 1, &"off_by_one")
	var model: Dictionary = GeneratorKit.ten_frame(a, 2)
	model["second"] = answer
	return model


## {c} - ? = {a} (pictorial): a number line marks c and a; the answer is how far back the jump from
## c to a goes. The hint draws that jump.
static func _subtrahend(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var numbers: Vector2i = _part_and_whole(params, rng)
	var a: int = numbers.x
	var c: int = numbers.y
	var window: Vector2i = GeneratorKit.window_around([a, c])
	var every: int = 1 if window.y - window.x <= 10 else 2
	problem.prompt_line_id = &"z2.eq.prompt_missing_subtrahend"
	problem.prompt_params = {"c": c, "a": a}
	problem.answer = c - a
	problem.visual = GeneratorKit.number_line(window.x, window.y, every, [c, a], [])
	GeneratorKit.add_distractor(problem, skill, c + a, &"added_both")
	var model: Dictionary = GeneratorKit.number_line(window.x, window.y, every, [c, a], [])
	model["jumps"] = [{"from": c, "to": a}]
	return model
