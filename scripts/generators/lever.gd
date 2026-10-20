## The counterweight lever for Zone 8, Power Tower (skill lever.counterweight.balance): a weight w hangs
## d steps left of the middle; which weight balances r steps to the right? A lever balances when
## weight × distance is the same on both sides (the moment), so the answer is w × d ÷ r. Distances come
## from params.distances (1, 2, 4, 8: powers of 2), every weight is a whole number up to
## params.max_weight, and weight × distance stays under 256 on each side.
##   concrete   the counterweight scene (meta.lever): set the right weight with More and Less, press
##              Balance; the beam tips toward the heavier side as the weight changes
##   pictorial  the lever picture, answered on the number pad or slate
## Pure: only the passed-in rng is used.
##
## The named mistakes:
##   matched_weight_only  the same weight as the left side, whatever the distances;
##   added_distance       weight + distance matched instead of weight × distance (w + d - r);
##   swapped_distances    the two distances mixed up (w × r ÷ d).
class_name LeverGenerator
extends RefCounted

## weight × distance on each side stays under this.
const MAX_MOMENT: int = 255


static func generate(skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Problem:
	return _make(skill, params, rng, true)


## The lever picture: weights `left_w` at `left_d` and `right_w` at `right_d` steps from the middle
## (a weight of 0 is drawn as an empty hook with a question mark). `products` writes w × d under a side
## that has its weight.
static func lever_picture(left_w: int, left_d: int, right_w: int, right_d: int, tilt: String, products: bool = false) -> Dictionary:
	var picture: Dictionary = {"type": "lever", "left": {"w": left_w, "d": left_d}, "right": {"w": right_w, "d": right_d}, "tilt": tilt}
	if products:
		picture["products"] = true
	return picture


static func _make(skill: Skill, params: Dictionary, rng: RandomNumberGenerator, with_hints: bool) -> Problem:
	var problem: Problem = GeneratorKit.new_problem(skill, params, GeneratorKit.pick_representation(skill, params))
	var difficulty: int = GeneratorKit.difficulty_of(params)
	var max_weight: int = GeneratorKit.eased_max(8, int(params.get("max_weight", 32)), difficulty, 4)
	var distances: Array[int] = GeneratorKit.ints_of(params.get("distances", [1, 2, 4, 8]))
	if difficulty < 0 and distances.size() > 3:
		distances = distances.slice(0, 3) # easier: the near hooks only
	var left_d: int = distances[rng.randi_range(0, distances.size() - 1)]
	var right_d: int = left_d
	while right_d == left_d:
		right_d = distances[rng.randi_range(0, distances.size() - 1)]
	# The moment w × d is a multiple of both distances and small enough for both weights.
	var step: int = MathUtil.lcm(left_d, right_d)
	var most: int = floori(mini(max_weight * mini(left_d, right_d), MAX_MOMENT) / float(step))
	var moment: int = step * rng.randi_range(1, maxi(most, 1))
	var left_w: int = floori(moment / float(left_d))
	var right_w: int = floori(moment / float(right_d))
	problem.prompt_line_id = &"z8.lever.prompt"
	problem.prompt_params = {"w": left_w, "d": left_d, "r": right_d}
	problem.answer = right_w
	if problem.representation == &"concrete":
		problem.meta = {"lever": {"left_w": left_w, "left_d": left_d, "right_d": right_d, "max": max_weight}}
	else:
		problem.visual = lever_picture(left_w, left_d, 0, right_d, "unknown")
	GeneratorKit.add_distractor(problem, skill, left_w, &"matched_weight_only")
	if left_w + left_d - right_d >= 1:
		GeneratorKit.add_distractor(problem, skill, left_w + left_d - right_d, &"added_distance")
	if (left_w * right_d) % left_d == 0:
		GeneratorKit.add_distractor(problem, skill, floori(left_w * right_d / float(left_d)), &"swapped_distances")
	if with_hints:
		var example: Problem = GeneratorKit.make_example(
			func(sub: RandomNumberGenerator) -> Problem: return _make(skill, params, sub, false), problem, rng)
		var p: Dictionary = example.prompt_params
		GeneratorKit.add_hints(problem, lever_picture(left_w, left_d, 0, right_d, "unknown", true), example, {
			"line_id": &"z8.hint.example_lever",
			"params": {"w": p["w"], "d": p["d"], "p": int(p["w"]) * int(p["d"]), "x": example.answer, "r": p["r"]}})
	return problem
