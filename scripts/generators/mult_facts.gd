## Multiplication facts for Zone 4 (skills mult.facts.0_5, mult.facts.6_10 and mult.facts.mixed):
## "What is a x b?" with an array of gems (concrete), a skip-count number line (pictorial) or the
## equation alone (abstract). Pure: only the passed-in rng is used.
##
## Params (a fact is "table x other", shown in either order):
##   table_min, table_max   the number the fact belongs to (default 2 to 10)
##   other_min, other_max   the other number (default 2 to 10; easier problems lower other_max)
## Zero is only used in abstract problems (an array or a hop line cannot show 0 groups), and a fact
## never has two zeros (there would be no wrong answer left to offer).
class_name MultFactsGenerator
extends RefCounted

## Arrays and hop lines hold at most this many groups or gems per group.
const MAX_SIDE: int = 10
const PROMPT: StringName = &"z4.mult.prompt_fact"
const EXAMPLE_LINE: StringName = &"z3.hint.example_fact"


static func generate(skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Problem:
	return _make(skill, params, rng, true)


static func _make(skill: Skill, params: Dictionary, rng: RandomNumberGenerator, with_hints: bool) -> Problem:
	var representation: StringName = GeneratorKit.pick_representation(skill, params)
	var problem: Problem = GeneratorKit.new_problem(skill, params, representation)
	var difficulty: int = GeneratorKit.difficulty_of(params)
	var lowest: int = 0 if representation == &"abstract" else 1
	var table_min: int = maxi(int(params.get("table_min", 2)), lowest)
	var table_max: int = mini(int(params.get("table_max", 10)), MAX_SIDE)
	var other_min: int = maxi(int(params.get("other_min", 2)), lowest)
	var other_max: int = GeneratorKit.eased_max(other_min, mini(int(params.get("other_max", 10)), MAX_SIDE), difficulty, 1)
	var table: int = rng.randi_range(table_min, table_max)
	var other: int = rng.randi_range(other_min, other_max)
	if table == 0 and other == 0:
		other = rng.randi_range(maxi(other_min, 1), other_max) # 0 x 0 has no wrong answer to offer
	var table_first: bool = rng.randi_range(0, 1) == 0
	var a: int = table if table_first else other
	var b: int = other if table_first else table
	var product: int = a * b
	problem.prompt_line_id = PROMPT
	problem.prompt_params = {"a": a, "b": b}
	problem.answer = product
	problem.meta = {"table": table, "table_first": table_first}
	match representation:
		&"concrete":
			problem.visual = GeneratorKit.array_picture(a, b)
		&"pictorial":
			problem.visual = GeneratorKit.hops_line(a, b)
	_add_distractors(problem, skill, a, b, rng)
	if with_hints:
		var model: Dictionary = GeneratorKit.array_picture(a, b, true) if a > 0 and b > 0 else _zero_line()
		var example: Problem = GeneratorKit.make_example(
			func(sub: RandomNumberGenerator) -> Problem: return _make(skill, params, sub, false), problem, rng)
		GeneratorKit.add_hints(problem, model, example, _example_line_of(example))
	return problem


## Nothing in zero groups: a number line with a marker on 0 and no hops.
static func _zero_line() -> Dictionary:
	return GeneratorKit.number_line(0, 10, 1, [0], [])


static func _example_line_of(example: Problem) -> Dictionary:
	var a: int = example.prompt_params["a"]
	var b: int = example.prompt_params["b"]
	return {"line_id": EXAMPLE_LINE, "params": {"a": a, "b": b, "product": example.answer}}


## Wrong answers, in the order the first three answer buttons should show them:
##   off_by_group    one group too many or too few (the product plus or minus a or b);
##   added_factors   a + b;
##   digit_swap      the product's two digits swapped (not when the product ends in 0);
##   off_by_group    a second one.
static func _add_distractors(problem: Problem, skill: Skill, a: int, b: int, rng: RandomNumberGenerator) -> void:
	var product: int = a * b
	var groups: Array[int] = GeneratorKit.shuffled_ints([product + a, product - a, product + b, product - b], rng)
	var valid: Array[int] = []
	for value: int in groups:
		if value >= 0 and value != product and not valid.has(value):
			valid.append(value)
	if not valid.is_empty():
		GeneratorKit.add_distractor(problem, skill, valid[0], &"off_by_group")
	GeneratorKit.add_distractor(problem, skill, a + b, &"added_factors")
	if product >= 10 and GeneratorKit.ones_digit(product) != 0:
		GeneratorKit.add_distractor(problem, skill, GeneratorKit.swap_digits(product), &"digit_swap")
	if valid.size() > 1:
		GeneratorKit.add_distractor(problem, skill, valid[1], &"off_by_group")
