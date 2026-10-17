## Division for Zone 4 (skills div.sharing.equal_shares, div.facts.by_2_5 and div.facts.by_6_10):
## share n gems into b equal carts (concrete), "What is n / b?" beside a number line of the
## multiples of b (pictorial), or the equation alone (abstract). Every division comes out exact.
## Pure: only the passed-in rng is used.
##
## Params: mode ("facts" or "share"), divisor_min, divisor_max, quotient_min, quotient_max
## (easier problems lower quotient_max). The "share" mode always asks in words about carts.
class_name DivFactsGenerator
extends RefCounted

## Pictures hold at most this many carts or gems per cart.
const MAX_SIDE: int = 10
const PROMPT_SHARE: StringName = &"z4.div.prompt_share"
const PROMPT_FACT: StringName = &"z4.div.prompt_fact"
const EXAMPLE_LINE: StringName = &"z4.hint.example_div"
## A pile of this many gems or fewer is drawn as single gems; more is drawn as tens and ones.
const ONES_ONLY_UP_TO: int = 30
## The number pad takes three digits, so a wrong answer is never longer than that.
const MAX_WRONG: int = 999


static func generate(skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Problem:
	return _make(skill, params, rng, true)


static func _make(skill: Skill, params: Dictionary, rng: RandomNumberGenerator, with_hints: bool) -> Problem:
	var mode: String = String(params.get("mode", "facts"))
	var representation: StringName = GeneratorKit.pick_representation(skill, params)
	var problem: Problem = GeneratorKit.new_problem(skill, params, representation)
	var difficulty: int = GeneratorKit.difficulty_of(params)
	var divisor: int = rng.randi_range(int(params.get("divisor_min", 2)), mini(int(params.get("divisor_max", 5)), MAX_SIDE))
	var quotient_min: int = int(params.get("quotient_min", 2))
	var quotient_max: int = GeneratorKit.eased_max(quotient_min, mini(int(params.get("quotient_max", 10)), MAX_SIDE), difficulty, 1)
	var quotient: int = rng.randi_range(quotient_min, quotient_max)
	var total: int = divisor * quotient
	var in_words: bool = mode == "share" or representation == &"concrete"
	problem.prompt_line_id = PROMPT_SHARE if in_words else PROMPT_FACT
	problem.prompt_params = {"n": total, "b": divisor}
	problem.answer = quotient
	match representation:
		&"concrete":
			problem.visual = _gems(total)
		&"pictorial":
			problem.visual = GeneratorKit.number_line(0, total, divisor, [total], [])
	_add_distractors(problem, skill, total, divisor, quotient, rng)
	if with_hints:
		var model: Dictionary = {"type": "groups", "groups": divisor, "size": quotient}
		var example: Problem = GeneratorKit.make_example(
			func(sub: RandomNumberGenerator) -> Problem: return _make(skill, params, sub, false), problem, rng)
		GeneratorKit.add_hints(problem, model, example, _example_line_of(example))
	return problem


## The gems to share: single gems for small piles, tens and ones for big ones.
static func _gems(total: int) -> Dictionary:
	if total <= ONES_ONLY_UP_TO:
		return GeneratorKit.gem_piles([GeneratorKit.pile(0, 0, total)])
	return GeneratorKit.gem_piles([GeneratorKit.pile_of(total)])


static func _example_line_of(example: Problem) -> Dictionary:
	return {"line_id": EXAMPLE_LINE, "params": {"n": example.prompt_params["n"], "b": example.prompt_params["b"], "q": example.answer}}


## multiplied_instead (n x b, never longer than three digits), then the answer one more and one less
## (off_by_one) in a random order.
static func _add_distractors(problem: Problem, skill: Skill, total: int, divisor: int, quotient: int, rng: RandomNumberGenerator) -> void:
	if total * divisor <= MAX_WRONG:
		GeneratorKit.add_distractor(problem, skill, total * divisor, &"multiplied_instead")
	var neighbours: Array[int] = [quotient + 1, quotient - 1]
	if rng.randi_range(0, 1) == 0:
		neighbours.reverse()
	for value: int in neighbours:
		GeneratorKit.add_distractor(problem, skill, value, &"off_by_one")
