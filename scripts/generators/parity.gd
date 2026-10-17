## Even-and-odd problems for Zone 3 (skills parity.even_odd.*): make pairs of gems and see if one is
## left over, or decide from the number's last digit. The answer is the word "even" or "odd"; the
## answer buttons read their labels from meta.label_lines. Pure: only the passed-in rng is used.
class_name ParityGenerator
extends RefCounted

const EVEN: String = "even"
const ODD: String = "odd"
## The pairs picture holds at most this many gems (Problem.VISUAL_TYPES).
const MAX_PAIRS_COUNT: int = 40


static func generate(skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Problem:
	return _make(skill, params, rng, true)


static func _make(skill: Skill, params: Dictionary, rng: RandomNumberGenerator, with_hints: bool) -> Problem:
	var mode: String = String(params.get("mode", "pairs"))
	var problem: Problem = GeneratorKit.new_problem(skill, params, GeneratorKit.pick_representation(skill, params))
	var model: Dictionary
	var example_line: Callable
	match mode:
		"pairs":
			model = _pairs(problem, skill, params, rng)
			example_line = _pairs_line_of
		"last_digit":
			model = _last_digit(problem, skill, params, rng)
			example_line = _rule_line_of
		_:
			push_error("ParityGenerator: unknown mode '%s'" % mode)
			return problem
	if with_hints:
		var example: Problem = GeneratorKit.make_example(
			func(sub: RandomNumberGenerator) -> Problem: return _make(skill, params, sub, false), problem, rng)
		GeneratorKit.add_hints(problem, model, example, example_line.call(example))
	return problem


static func _pairs_line_of(example: Problem) -> Dictionary:
	var line: StringName = &"z3.hint.example_pairs_even" if example.answer == EVEN else &"z3.hint.example_pairs_odd"
	return {"line_id": line, "params": {"n": example.visual["count"]}}


static func _rule_line_of(example: Problem) -> Dictionary:
	var n: int = example.prompt_params["n"]
	var line: StringName = &"z3.hint.example_rule_even" if example.answer == EVEN else &"z3.hint.example_rule_odd"
	return {"line_id": line, "params": {"n": n, "digit": GeneratorKit.ones_digit(n)}}


static func _word(n: int) -> String:
	return EVEN if n % 2 == 0 else ODD


static func _other(word: String) -> String:
	return ODD if word == EVEN else EVEN


static func _labels() -> Dictionary:
	return {EVEN: &"ui.answer.even", ODD: &"ui.answer.odd"}


## Some gems, not yet paired (concrete). Pairing them shows whether one is left over.
static func _pairs(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var high: int = GeneratorKit.eased_max(1, mini(int(params.get("max", 20)), MAX_PAIRS_COUNT), GeneratorKit.difficulty_of(params))
	var n: int = rng.randi_range(1, high)
	problem.prompt_line_id = &"z3.parity.prompt_pairs"
	problem.answer = _word(n)
	problem.visual = {"type": "pairs", "count": n, "show_pairs": false}
	problem.meta = {"label_lines": _labels()}
	GeneratorKit.add_distractor(problem, skill, _other(problem.answer), &"leftover_miscounted")
	return {"type": "pairs", "count": n, "show_pairs": true}


## Is {n} even or odd? for n from 10 to max (abstract). The numbers are uniform, so the tens digit
## agrees with the answer about half the time; a child cannot learn "say the opposite of the tens".
## The wrong word is named used_tens_digit when the tens digit points to it, and parity_swapped
## (simply mixing up the words) when it does not.
static func _last_digit(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var low: int = 10
	var high: int = GeneratorKit.eased_max(low, int(params.get("max", 100)), GeneratorKit.difficulty_of(params), 10)
	var n: int = rng.randi_range(low, high)
	var answer: String = _word(n)
	var tens_misleads: bool = _word(GeneratorKit.tens_digit(n)) != answer
	problem.prompt_line_id = &"z3.parity.prompt_rule"
	problem.prompt_params = {"n": n}
	problem.answer = answer
	problem.meta = {"label_lines": _labels(), "tens_digit_misleads": tens_misleads}
	GeneratorKit.add_distractor(problem, skill, _other(answer), &"used_tens_digit" if tens_misleads else &"parity_swapped")
	# Hint: the ten around n, labeled every two from an even number, so only even numbers get a label.
	var window: Vector2i = GeneratorKit.window_around([n])
	return GeneratorKit.number_line(window.x, window.y, 2, [n], [])
