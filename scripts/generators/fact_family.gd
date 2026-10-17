## Fact family problems for Zone 2 (skills eq.fact_family.build, eq.inverse.check): drag the four
## facts that use the same three numbers, and pick the fact that checks another one with the
## inverse operation. Pure: only the passed-in rng is used.
##
## A fact is a String written exactly "%d + %d = %d" or "%d - %d = %d" (ASCII hyphen-minus, single
## spaces); tiles and answer buttons show it as it is.
class_name FactFamilyGenerator
extends RefCounted

## The smallest whole a family can have: 1 + 2 = 3 (the two parts must differ).
const SMALLEST_WHOLE: int = 3


static func generate(skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Problem:
	return _make(skill, params, rng, true)


static func _make(skill: Skill, params: Dictionary, rng: RandomNumberGenerator, with_hints: bool) -> Problem:
	var mode: String = String(params.get("mode", "build"))
	var problem: Problem = GeneratorKit.new_problem(skill, params, GeneratorKit.pick_representation(skill, params))
	var model: Dictionary
	var example_line: Callable
	match mode:
		"build":
			model = _build(problem, skill, params, rng)
			example_line = _family_line_of
		"inverse_check":
			model = _inverse_check(problem, skill, params, rng)
			example_line = _check_line_of
		_:
			push_error("FactFamilyGenerator: unknown mode '%s'" % mode)
			return problem
	if with_hints:
		var example: Problem = GeneratorKit.make_example(
			func(sub: RandomNumberGenerator) -> Problem: return _make(skill, params, sub, false), problem, rng)
		GeneratorKit.add_hints(problem, model, example, example_line.call(example))
	return problem


## "x + y = z", exactly as a tile or button shows it.
static func add_fact(x: int, y: int, z: int) -> String:
	return "%d + %d = %d" % [x, y, z]


## "x - y = z", exactly as a tile or button shows it.
static func sub_fact(x: int, y: int, z: int) -> String:
	return "%d - %d = %d" % [x, y, z]


## The four facts of the family of a, b and their sum, in the order a child says them.
static func family(a: int, b: int) -> Array[String]:
	var c: int = a + b
	return [add_fact(a, b, c), add_fact(b, a, c), sub_fact(c, a, b), sub_fact(c, b, a)]


static func _family_line_of(example: Problem) -> Dictionary:
	var facts: Array[String] = family(example.prompt_params["a"], example.prompt_params["b"])
	return {"line_id": &"z2.hint.example_family", "params": {"list": "; ".join(PackedStringArray(facts))}}


static func _check_line_of(example: Problem) -> Dictionary:
	return {"line_id": &"z2.hint.example_check", "params": {"fact": String(example.answer)}}


## Build the fact family for {a}, {b} and {c}: drag the four true facts out of six tiles. The two
## wrong tiles are the two named mistakes; each distractor is the family with one true fact
## swapped for the wrong tile it turns into.
static func _build(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var top: int = GeneratorKit.eased_max(SMALLEST_WHOLE, int(params.get("max", 20)), GeneratorKit.difficulty_of(params))
	var parts: Vector2i = _parts(top, rng)
	var a: int = parts.x
	var b: int = parts.y
	var c: int = a + b
	var facts: Array[String] = family(a, b)
	# Subtracting the whole from a part (3 - 8 = 5): the two numbers before "=" in the wrong order.
	var part: int = a if rng.randi_range(0, 1) == 0 else b
	var swapped: String = sub_fact(part, c, c - part)
	var swapped_true: String = sub_fact(c, part, c - part)
	# The other operation: subtract where the family adds (3 - 5 = 8), or add where it subtracts (8 + 3 = 5).
	var first: int = a if rng.randi_range(0, 1) == 0 else b
	var wrong_op: String
	var wrong_op_true: String
	if rng.randi_range(0, 1) == 0:
		wrong_op = sub_fact(first, c - first, c)
		wrong_op_true = add_fact(first, c - first, c)
	else:
		wrong_op = add_fact(c, first, c - first)
		wrong_op_true = sub_fact(c, first, c - first)
	var tiles: Array[String] = facts.duplicate()
	tiles.append(swapped)
	tiles.append(wrong_op)
	problem.prompt_line_id = &"z2.eq.prompt_fact_family"
	problem.prompt_params = {"a": a, "b": b, "c": c}
	problem.answer = Problem.sorted_values(facts)
	problem.meta = {"tile_board": {"tiles": _shuffled(tiles, rng), "slots": 4, "ordered": false}}
	GeneratorKit.add_distractor(problem, skill, _replaced(facts, swapped_true, swapped), &"swapped_minuend")
	GeneratorKit.add_distractor(problem, skill, _replaced(facts, wrong_op_true, wrong_op), &"wrong_operation")
	var model: Dictionary = GeneratorKit.ten_frame(a, 2)
	model["second"] = b
	return model


## "{a} + {b} = {c}. Which fact checks it with the inverse?" (or the subtraction "{c} - {b} = {a}").
## The answer undoes the shown fact: c - b = a for a + b = c, and a + b = c for c - b = a. The
## family's other inverse fact (c - a = b, or b + a = c) would check it too, so it is never
## offered: exactly one button is right. Every button shows a true fact.
static func _inverse_check(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var top: int = GeneratorKit.eased_max(SMALLEST_WHOLE, int(params.get("max", 20)), GeneratorKit.difficulty_of(params))
	var parts: Vector2i = _parts(top, rng)
	var a: int = parts.x
	var b: int = parts.y
	var c: int = a + b
	var jump: Dictionary
	problem.prompt_params = {"a": a, "b": b, "c": c}
	if rng.randi_range(0, 1) == 0:
		problem.prompt_line_id = &"z2.eq.prompt_inverse_add"
		problem.answer = sub_fact(c, b, a)
		GeneratorKit.add_distractor(problem, skill, add_fact(b, a, c), &"wrong_operation") # turned around, still adding
		GeneratorKit.add_distractor(problem, skill, add_fact(c, b, c + b), &"wrong_operation") # adds b again instead of taking it away
		jump = {"from": c, "to": a}
	else:
		problem.prompt_line_id = &"z2.eq.prompt_inverse_sub"
		problem.answer = add_fact(a, b, c)
		GeneratorKit.add_distractor(problem, skill, sub_fact(c, a, b), &"wrong_operation") # the other subtraction, still subtracting
		GeneratorKit.add_distractor(problem, skill, add_fact(c, b, c + b), &"wrong_operation") # flips the sign but keeps the whole first
		jump = {"from": a, "to": c}
	var window: Vector2i = GeneratorKit.window_around([a, c])
	var model: Dictionary = GeneratorKit.number_line(window.x, window.y, 1 if window.y - window.x <= 10 else 2, [a, c], [])
	model["jumps"] = [jump]
	return model


## Two different parts (x, y), each at least 1, whose whole x + y is from 3 to `top`.
static func _parts(top: int, rng: RandomNumberGenerator) -> Vector2i:
	var whole: int = rng.randi_range(SMALLEST_WHOLE, top)
	var a: int
	if whole % 2 == 0:
		# Uniform over 1 .. whole - 1 without the middle, so the two parts are never equal.
		a = rng.randi_range(1, whole - 2)
		if a * 2 >= whole:
			a += 1
	else:
		a = rng.randi_range(1, whole - 1)
	return Vector2i(a, whole - a)


## `facts` with `old` swapped for `new`, sorted the way an unordered tile answer is kept.
static func _replaced(facts: Array[String], old: String, new: String) -> Array:
	var copy: Array[String] = facts.duplicate()
	copy[copy.find(old)] = new
	return Problem.sorted_values(copy)


## A Fisher-Yates shuffle of the tiles driven only by `rng`.
static func _shuffled(items: Array[String], rng: RandomNumberGenerator) -> Array[String]:
	var copy: Array[String] = items.duplicate()
	for i: int in range(copy.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var held: String = copy[i]
		copy[i] = copy[j]
		copy[j] = held
	return copy
