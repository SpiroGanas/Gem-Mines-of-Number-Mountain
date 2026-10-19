## Gear trains for Zone 6 (skills gear.*). Teeth push teeth: when a gear with a teeth turns once, a
## teeth pass where it meets the next gear, so a gear with b teeth turns a ÷ b times. Two marked teeth
## that start together meet again once a common multiple of teeth has passed: first after
## lcm(a, b) teeth, which is lcm(a, b) ÷ a turns of the first gear. Pure: only the passed-in rng is used.
##
## Modes (params.mode):
##   ratio  "The big gear has {a} teeth. It turns once. Which gear turns {k} times?" The answer is the
##          gear's teeth, a ÷ k. a comes from params.teeth and k from params.turns (a ÷ k at least
##          params.min_teeth). Concrete: the gear bench (meta.gear_bench = {driver, turns, tray}); the
##          child drags a gear from the tray onto the empty axle. Pictorial: answer buttons beside a
##          picture of the big gear. Wrong gears: a × k (inverted_ratio), a − k (subtracted_teeth) and a
##          gear like the first (same_size_gear).
##   sync   "A {a}-tooth gear turns a {b}-tooth gear. ... How many turns of the {a}-tooth gear until the
##          marks meet again?" The answer is lcm(a, b) ÷ a, at least 2. Both counts of turns stay at
##          most MAX_TURNS so the hint's lists fit. Wrong answers: gcd(a, b) (used_gcf), lcm ÷ b
##          (counted_other_gear), lcm itself (teeth_not_turns).
##
## Difficulty below 0 keeps only the smallest number of turns (ratio) and lowers the largest gear.
class_name GearGenerator
extends RefCounted

const PROMPT_RATIO: StringName = &"z6.gear.prompt_ratio"
const PROMPT_SYNC: StringName = &"z6.gear.prompt_sync"
## The most turns either gear makes before the marks meet (the hint lists show every multiple).
const MAX_TURNS: int = 12


static func generate(skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Problem:
	return _make(skill, params, rng, true)


static func _make(skill: Skill, params: Dictionary, rng: RandomNumberGenerator, with_hints: bool) -> Problem:
	var mode: String = String(params.get("mode", "ratio"))
	var problem: Problem = GeneratorKit.new_problem(skill, params, GeneratorKit.pick_representation(skill, params))
	var model: Dictionary
	match mode:
		"ratio":
			model = _ratio(problem, skill, params, rng)
		"sync":
			model = _sync(problem, skill, params, rng)
		_:
			push_error("GearGenerator: unknown mode '%s'" % mode)
			return problem
	if with_hints:
		var example: Problem = GeneratorKit.make_example(
			func(sub: RandomNumberGenerator) -> Problem: return _make(skill, params, sub, false), problem, rng)
		GeneratorKit.add_hints(problem, model, example, _example_line(example))
	return problem


## A `gears` picture: gears side by side with these teeth, the first one driving. `shaded` colors that
## many teeth of the first gear (simplest form); `marks` draws the marked teeth that start together.
static func gears_picture(teeth: Array[int], shaded: int = -1, marks: bool = false) -> Dictionary:
	var picture: Dictionary = {"type": "gears", "teeth": teeth}
	if shaded >= 0:
		picture["shaded"] = shaded
	if marks:
		picture["marks"] = true
	return picture


# --- ratio ---------------------------------------------------------------------------------------


## Every (teeth, turns) the skill allows: a from params.teeth, k from params.turns, a ÷ k whole and at
## least params.min_teeth. Easier problems keep the smallest k and drop the biggest gears.
static func ratio_choices(params: Dictionary) -> Array[Vector2i]:
	var difficulty: int = GeneratorKit.difficulty_of(params)
	var all_teeth: Array[int] = GeneratorKit.ints_of(params.get("teeth", [12, 16, 24, 32]))
	var turns: Array[int] = GeneratorKit.ints_of(params.get("turns", [2, 3, 4]))
	all_teeth.sort()
	turns.sort()
	if difficulty < 0:
		turns = [turns[0]]
	var largest: int = GeneratorKit.eased_max(all_teeth[0], all_teeth.back(), difficulty, 4)
	var least: int = int(params.get("min_teeth", 6))
	var choices: Array[Vector2i] = []
	for a: int in all_teeth:
		if a > largest:
			continue
		for k: int in turns:
			if a % k == 0 and floori(float(a) / k) >= least:
				choices.append(Vector2i(a, k))
	return choices


static func _ratio(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var choices: Array[Vector2i] = ratio_choices(params)
	var chosen: Vector2i = choices[rng.randi_range(0, choices.size() - 1)]
	var a: int = chosen.x
	var k: int = chosen.y
	var small: int = floori(float(a) / k)
	problem.prompt_line_id = PROMPT_RATIO
	problem.prompt_params = {"a": a, "k": k}
	problem.answer = small
	GeneratorKit.add_distractor(problem, skill, a * k, &"inverted_ratio")
	GeneratorKit.add_distractor(problem, skill, a - k, &"subtracted_teeth")
	GeneratorKit.add_distractor(problem, skill, a, &"same_size_gear")
	if problem.representation == &"concrete":
		var tray: Array[int] = [small]
		tray.append_array(GeneratorKit.ints_of(problem.distractor_values()))
		tray.sort()
		problem.meta = {"gear_bench": {"driver": a, "turns": k, "tray": tray}}
	else:
		problem.visual = gears_picture([a])
	return GeneratorKit.hops_line(k, small, [a])


# --- sync ----------------------------------------------------------------------------------------


static func _sync(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var low: int = int(params.get("min_teeth", 6))
	var high: int = GeneratorKit.eased_max(low, int(params.get("max_teeth", 24)), GeneratorKit.difficulty_of(params), 6)
	var a: int = 6
	var b: int = 8
	for attempt: int in GcfGenerator.PAIR_TRIES:
		var x: int = rng.randi_range(low, high)
		var y: int = rng.randi_range(low, high)
		var l: int = MathUtil.lcm(x, y)
		var turns_x: int = floori(float(l) / x)
		var turns_y: int = floori(float(l) / y)
		if x != y and turns_x >= 2 and turns_x <= MAX_TURNS and turns_y <= MAX_TURNS:
			a = x
			b = y
			break
	var lcm_teeth: int = MathUtil.lcm(a, b)
	problem.prompt_line_id = PROMPT_SYNC
	problem.prompt_params = {"a": a, "b": b}
	problem.answer = floori(float(lcm_teeth) / a)
	GeneratorKit.add_distractor(problem, skill, MathUtil.gcd(a, b), &"used_gcf")
	GeneratorKit.add_distractor(problem, skill, floori(float(lcm_teeth) / b), &"counted_other_gear")
	GeneratorKit.add_distractor(problem, skill, lcm_teeth, &"teeth_not_turns")
	problem.visual = gears_picture([a, b], -1, true)
	return GcfGenerator.multiple_lists(a, b, lcm_teeth, [lcm_teeth])


# --- Worked examples -----------------------------------------------------------------------------


static func _example_line(example: Problem) -> Dictionary:
	var a: int = example.prompt_params["a"]
	if example.prompt_line_id == PROMPT_RATIO:
		var k: int = example.prompt_params["k"]
		return {"line_id": &"z6.hint.example_ratio", "params": {"a": a, "b": floori(float(a) / k), "k": k}}
	var b: int = example.prompt_params["b"]
	var l: int = MathUtil.lcm(a, b)
	return {"line_id": &"z6.hint.example_sync", "params": {"a": a, "l": l, "t": floori(float(l) / a)}}
