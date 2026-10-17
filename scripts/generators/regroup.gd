## Regrouping ("trade ten") problems for Zone 1 (skills pv.regroup.*): trade ten ones for one ten,
## or one ten for ten ones, and show what you have now. The answer is the pile after the trade.
## Pure: only the passed-in rng is used.
class_name RegroupGenerator
extends RefCounted


static func generate(skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Problem:
	return _make(skill, params, rng, true)


static func _make(skill: Skill, params: Dictionary, rng: RandomNumberGenerator, with_hints: bool) -> Problem:
	var mode: String = String(params.get("mode", "ones_to_ten"))
	var problem: Problem = GeneratorKit.new_problem(skill, params, GeneratorKit.pick_representation(skill, params))
	var model: Dictionary
	match mode:
		"ones_to_ten":
			model = _ones_to_ten(problem, skill, params, rng)
		"ten_to_ones":
			model = _ten_to_ones(problem, skill, params, rng)
		_:
			push_error("RegroupGenerator: unknown mode '%s'" % mode)
			return problem
	if with_hints:
		var example: Problem = GeneratorKit.make_example(
			func(sub: RandomNumberGenerator) -> Problem: return _make(skill, params, sub, false), problem, rng)
		var line: Dictionary = {"line_id": &"z1.hint.example_tens_ones", "params": {"tens": example.answer["tens"], "ones": example.answer["ones"]}}
		GeneratorKit.add_hints(problem, model, example, line)
	return problem


## You have {tens} tens and {ones} ones (ones from 10 to 19). Trade ten ones for one ten.
static func _ones_to_ten(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var max_tens: int = GeneratorKit.eased_max(1, int(params.get("max_tens", 8)), GeneratorKit.difficulty_of(params), 1)
	var tens: int = rng.randi_range(0, max_tens)
	var ones: int = rng.randi_range(int(params.get("min_ones", 10)), int(params.get("max_ones", 19)))
	problem.prompt_line_id = &"z1.regroup.prompt_trade_ten"
	problem.prompt_params = {"tens": tens, "ones": ones}
	problem.answer = {"tens": tens + 1, "ones": ones - 10}
	problem.visual = GeneratorKit.gem_piles([GeneratorKit.pile(0, tens, ones)])
	problem.meta = {"start": {"tens": tens, "ones": ones}, "tools": ["ten", "one"]}
	GeneratorKit.add_distractor(problem, skill, {"tens": tens, "ones": ones}, &"forgot_regroup")
	GeneratorKit.add_distractor(problem, skill, {"tens": tens + 1, "ones": ones - 9}, &"traded_wrong_count")
	if ones >= 11:
		GeneratorKit.add_distractor(problem, skill, {"tens": tens + 1, "ones": ones - 11}, &"traded_wrong_count")
	return {"type": "gem_piles", "piles": [GeneratorKit.pile(0, tens, ones)], "group_ones": 10}


## You have {tens} tens and {ones} ones (tens from 1 to 9). Trade one ten for ten ones.
static func _ten_to_ones(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var max_tens: int = GeneratorKit.eased_max(1, int(params.get("max_tens", 9)), GeneratorKit.difficulty_of(params), 1)
	var tens: int = rng.randi_range(1, max_tens)
	var ones: int = rng.randi_range(0, int(params.get("max_ones", 9)))
	problem.prompt_line_id = &"z1.regroup.prompt_untrade"
	problem.prompt_params = {"tens": tens, "ones": ones}
	problem.answer = {"tens": tens - 1, "ones": ones + 10}
	problem.visual = GeneratorKit.gem_piles([GeneratorKit.pile(0, tens, ones)])
	problem.meta = {"start": {"tens": tens, "ones": ones}, "tools": ["ten", "one"]}
	GeneratorKit.add_distractor(problem, skill, {"tens": tens, "ones": ones}, &"forgot_regroup")
	GeneratorKit.add_distractor(problem, skill, {"tens": tens - 1, "ones": ones + 9}, &"traded_wrong_count")
	GeneratorKit.add_distractor(problem, skill, {"tens": tens - 1, "ones": ones + 11}, &"traded_wrong_count")
	return {"type": "gem_piles", "piles": [GeneratorKit.pile(0, tens, ones)], "group_tens": 1}
