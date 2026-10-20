## Negative numbers for Zone 7, Crystal Shards (skills negative.depth.*): the depth gauge, a vertical
## number line with 0 at the mountain's base. Up is above the base, down is below it, so "deeper"
## means more negative. Bolt's elevator cab rides along it. params.mode picks the question:
##   read     the cab is at {d} on the gauge: what number is it at?  answer d (often below zero)
##   compare  which number is greater, {a} or {b}?  a is always the one farther from zero, so a
##            child who thinks "farther from zero is bigger" picks it
##   move     the cab is at {s} and goes up or down {t}: where is it now?  answer s + t or s - t.
##            Pictorial problems are answered by riding the cab (meta.depth_gauge); abstract ones on the
##            number pad with its minus key (meta.signed).
## Answers are plain ints; the gauge and the pad handle the sign. Values stay in params.range.
## Pure: only the passed-in rng is used.
##
## The named mistakes:
##   dropped_sign             left off the minus sign (-15 as 15), or added one;
##   off_by_one               read the gauge one mark off;
##   bigger_magnitude_bigger  thought the number farther from zero is greater (-12 > -7);
##   wrong_direction          moved the cab up instead of down, or down instead of up.
class_name NegativeGenerator
extends RefCounted

## Labels on the gauge every this many meters.
const LABEL_EVERY: int = 5
## How often a read problem is below zero (percent); the rest are above it.
const BELOW_SHARE: int = 75


static func generate(skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Problem:
	return _make(skill, params, rng, true)


static func _make(skill: Skill, params: Dictionary, rng: RandomNumberGenerator, with_hints: bool) -> Problem:
	var problem: Problem = GeneratorKit.new_problem(skill, params, GeneratorKit.pick_representation(skill, params))
	var model: Dictionary = {}
	var example_line: Callable
	match str(params.get("mode", "read")):
		"read":
			model = _read(problem, skill, params, rng)
			example_line = _read_line
		"compare":
			model = _compare(problem, skill, params, rng)
			example_line = _compare_line
		"move":
			model = _move(problem, skill, params, rng)
			example_line = _move_line
	if with_hints:
		var example: Problem = GeneratorKit.make_example(
			func(sub: RandomNumberGenerator) -> Problem: return _make(skill, params, sub, false), problem, rng)
		GeneratorKit.add_hints(problem, model, example, example_line.call(example))
	return problem


## The lowest and highest levels at this difficulty: params.range ([-30, 30] as authored), or
## params.min_depth to its mirror above the base; one step easier shrinks both ends toward 0.
static func levels(params: Dictionary) -> Vector2i:
	var span: Array = params.get("range", [int(params.get("min_depth", -30)), -int(params.get("min_depth", -30))])
	var difficulty: int = GeneratorKit.difficulty_of(params)
	var low: int = -GeneratorKit.eased_max(5, -int(span[0]), difficulty, 5)
	var high: int = GeneratorKit.eased_max(5, int(span[1]), difficulty, 5)
	return Vector2i(low, high)


## A `depth_gauge` picture for the values: from a multiple of 10 at or below the lowest (and below 0)
## to one at or above the highest (and above 0), labeled every LABEL_EVERY.
static func gauge(values: Array[int], jump: Vector2i = Vector2i.ZERO, with_jump: bool = false) -> Dictionary:
	var low: int = mini(values.min(), -5)
	var high: int = maxi(values.max(), 5)
	var picture: Dictionary = {
		"type": "depth_gauge", "min": floori(low / 10.0) * 10, "max": ceili(high / 10.0) * 10,
		"labeled_every": LABEL_EVERY, "markers": values,
	}
	if with_jump:
		picture["jumps"] = [{"from": jump.x, "to": jump.y}]
	return picture


static func _read(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var range_now: Vector2i = levels(params)
	var depth: int = rng.randi_range(range_now.x, -1) if rng.randi_range(0, 99) < BELOW_SHARE else rng.randi_range(1, range_now.y)
	problem.prompt_line_id = &"z7.depth.prompt_read"
	problem.prompt_params = {}
	problem.answer = depth
	problem.meta = {"signed": true}
	problem.visual = gauge([depth] as Array[int])
	GeneratorKit.add_distractor(problem, skill, -depth, &"dropped_sign", true)
	GeneratorKit.add_distractor(problem, skill, depth + (1 if rng.randi_range(0, 1) == 0 else -1), &"off_by_one", true)
	return problem.visual.duplicate(true)


static func _read_line(example: Problem) -> Dictionary:
	var depth: int = example.answer
	if depth < 0:
		return {"line_id": &"z7.hint.example_depth_below", "params": {"m": -depth, "d": depth}}
	return {"line_id": &"z7.hint.example_depth_above", "params": {"m": depth, "d": depth}}


static func _compare(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var range_now: Vector2i = levels(params)
	# a < b with a farther from zero than b: a is below zero and |a| > |b|.
	var a: int = rng.randi_range(range_now.x, -2)
	var b: int = rng.randi_range(a + 1, mini(-a - 1, range_now.y))
	var first_is_a: bool = rng.randi_range(0, 1) == 0
	problem.prompt_line_id = &"z7.depth.prompt_compare"
	problem.prompt_params = {"a": a, "b": b} if first_is_a else {"a": b, "b": a}
	problem.answer = b
	GeneratorKit.add_distractor(problem, skill, a, &"bigger_magnitude_bigger", true)
	var model: Dictionary = gauge([a, b] as Array[int])
	if problem.representation == &"pictorial":
		problem.visual = model.duplicate(true)
	return model


static func _compare_line(example: Problem) -> Dictionary:
	var greater: int = example.answer
	var p: Dictionary = example.prompt_params
	var lower: int = p["a"] if p["b"] == greater else p["b"]
	return {"line_id": &"z7.hint.example_depth_compare", "params": {"a": greater, "b": lower}}


static func _move(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var range_now: Vector2i = levels(params)
	var step_top: int = GeneratorKit.eased_max(1, int(params.get("step", 15)), GeneratorKit.difficulty_of(params), 4)
	var start: int = rng.randi_range(range_now.x + 1, range_now.y - 1)
	var down: bool = rng.randi_range(0, 1) == 0
	# Room to move without leaving the gauge: below the start for a trip down, above it for a trip up.
	var room: int = (start - range_now.x) if down else (range_now.y - start)
	var step: int = rng.randi_range(1, mini(step_top, room))
	var end: int = start - step if down else start + step
	problem.prompt_line_id = &"z7.depth.prompt_down" if down else &"z7.depth.prompt_up"
	problem.prompt_params = {"s": start, "t": step}
	problem.answer = end
	problem.meta = {"signed": true}
	if problem.representation == &"pictorial":
		problem.meta["depth_gauge"] = {"min": range_now.x, "max": range_now.y, "start": start}
	GeneratorKit.add_distractor(problem, skill, start + step if down else start - step, &"wrong_direction", true)
	GeneratorKit.add_distractor(problem, skill, -end, &"dropped_sign", true)
	return gauge([start, end] as Array[int], Vector2i(start, end), true)


static func _move_line(example: Problem) -> Dictionary:
	var p: Dictionary = example.prompt_params
	var line: StringName = &"z7.hint.example_move_down" if example.prompt_line_id == &"z7.depth.prompt_down" else &"z7.hint.example_move_up"
	return {"line_id": line, "params": {"s": p["s"], "t": p["t"], "e": example.answer}}
