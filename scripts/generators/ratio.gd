## Ratios for Zone 7, Crystal Shards (skills ratio.*): copper and tin ore mixed into an alloy (an
## electric mixing drum; nothing is melted over a flame). params.mode picks the question:
##   part_to_part  {a} copper ores and {b} tin ores: what is the ratio of copper to tin?  answer {a, b}
##                 in lowest terms (copper first, as the prompt says). params.reduce_share percent of
##                 the problems use counts that share a factor, so the answer is the simplified ratio.
##   scale_up      the recipe is {a} copper to {b} tin; the hopper has {c} copper: how much tin?
##                 answer b * (c / a), a whole number. Concrete problems use the alloy mixer
##                 (meta.alloy, scenes/workshop/builds/alloy_mixer/); abstract ones the number pad.
## Pure: only the passed-in rng is used.
##
## The named mistakes:
##   part_to_whole           compared copper with all the ore (a : a + b);
##   inverted_ratio          put tin first (b : a);
##   added_instead_of_scaled added the extra copper to the tin instead of multiplying (b + c - a);
##   scaled_one_part         grew the copper but kept the tin as in the recipe (b).
class_name RatioGenerator
extends RefCounted

## The tin hopper holds at most this many more scoops than the answer needs, so a slider never
## gives the answer away by ending at it.
const HOPPER_SPARE: int = 6


static func generate(skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Problem:
	return _make(skill, params, rng, true)


static func _make(skill: Skill, params: Dictionary, rng: RandomNumberGenerator, with_hints: bool) -> Problem:
	var problem: Problem = GeneratorKit.new_problem(skill, params, GeneratorKit.pick_representation(skill, params))
	var model: Dictionary = {}
	var example_line: Callable
	if str(params.get("mode", "part_to_part")) == "scale_up":
		model = _scale_up(problem, skill, params, rng)
		example_line = _scale_line
	else:
		model = _part_to_part(problem, skill, params, rng)
		example_line = _part_line
	if with_hints:
		var example: Problem = GeneratorKit.make_example(
			func(sub: RandomNumberGenerator) -> Problem: return _make(skill, params, sub, false), problem, rng)
		GeneratorKit.add_hints(problem, model, example, example_line.call(example))
	return problem


static func ratio(a: int, b: int) -> Dictionary:
	return Rational.normalize_ratio(a, b)


## An `ore_mix` picture: a copper ores (round) and b tin ores (square); `groups` rings them into that
## many equal mixes (0 for none).
static func ore_mix(a: int, b: int, groups: int = 0) -> Dictionary:
	var picture: Dictionary = {"type": "ore_mix", "a": a, "b": b}
	if groups > 1:
		picture["groups"] = groups
	return picture


static func _part_to_part(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var top: int = GeneratorKit.eased_max(2, int(params.get("max_count", 12)), GeneratorKit.difficulty_of(params), 3)
	var reduce: bool = rng.randi_range(0, 99) < int(params.get("reduce_share", 0))
	var pairs: Array[Vector2i] = []
	for a: int in range(1, top + 1):
		for b: int in range(1, top + 1):
			if a != b and (MathUtil.gcd(a, b) > 1) == reduce:
				pairs.append(Vector2i(a, b))
	if pairs.is_empty(): # no pair sharing a factor this small: fall back to coprime counts
		for a: int in range(1, top + 1):
			for b: int in range(1, top + 1):
				if a != b and MathUtil.gcd(a, b) == 1:
					pairs.append(Vector2i(a, b))
	var pick: Vector2i = pairs[rng.randi_range(0, pairs.size() - 1)]
	var copper: int = pick.x
	var tin: int = pick.y
	problem.prompt_line_id = &"z7.ratio.prompt"
	problem.prompt_params = {"a": copper, "b": tin}
	problem.answer = ratio(copper, tin)
	GeneratorKit.add_distractor(problem, skill, ratio(copper, copper + tin), &"part_to_whole")
	GeneratorKit.add_distractor(problem, skill, ratio(tin, copper), &"inverted_ratio")
	var groups: int = MathUtil.gcd(copper, tin)
	problem.visual = ore_mix(copper, tin, groups if problem.representation == &"pictorial" else 0)
	return ore_mix(copper, tin, groups)


static func _part_line(example: Problem) -> Dictionary:
	var a: int = example.prompt_params["a"]
	var b: int = example.prompt_params["b"]
	return {"line_id": &"z7.hint.example_ratio", "params": {"a": a, "b": b, "r": example.answer}}


static func _scale_up(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var difficulty: int = GeneratorKit.difficulty_of(params)
	var part_top: int = GeneratorKit.eased_max(2, int(params.get("max_part", 5)), difficulty, 1)
	var copper: int = rng.randi_range(1, part_top)
	var tin: int = rng.randi_range(1, part_top - 1)
	if tin >= copper:
		tin += 1 # copper and tin differ, so "add instead of scale" is a different number
	var simplest: Dictionary = ratio(copper, tin)
	copper = simplest["a"]
	tin = simplest["b"]
	var factor: int = rng.randi_range(2, GeneratorKit.eased_max(2, int(params.get("max_factor", 6)), difficulty, 1))
	var given: int = copper * factor
	var answer: int = tin * factor
	problem.prompt_line_id = &"z7.alloy.prompt"
	problem.prompt_params = {"a": copper, "b": tin, "c": given}
	problem.answer = answer
	if problem.representation == &"concrete":
		problem.meta = {"alloy": {"a": copper, "b": tin, "given": given, "max": answer + HOPPER_SPARE}}
	GeneratorKit.add_distractor(problem, skill, tin + given - copper, &"added_instead_of_scaled")
	GeneratorKit.add_distractor(problem, skill, tin, &"scaled_one_part")
	return ore_mix(given, answer, factor)


static func _scale_line(example: Problem) -> Dictionary:
	var p: Dictionary = example.prompt_params
	var factor: int = floori(float(p["c"]) / p["a"])
	return {"line_id": &"z7.hint.example_alloy", "params": {"a": p["a"], "b": p["b"], "c": p["c"], "k": factor, "t": example.answer}}
