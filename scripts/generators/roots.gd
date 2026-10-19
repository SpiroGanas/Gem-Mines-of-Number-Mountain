## Square roots of perfect squares for Zone 8, Power Tower (skill root.square.perfect). Only perfect
## squares are asked, so every answer is a whole number: the side r of a square of n = r × r gems.
##   pictorial  "{n} gems make a square. How many gems are in each row?" with the square of gems
##              (r up to 10, the array picture's limit)
##   abstract   "What is the square root of {n}?" with the root sign on a notation card
## Pure: only the passed-in rng is used.
##
## The named mistakes: halved (n ÷ 2, only for an even n) and off_by_one_root (r + 1 or r - 1).
class_name RootGenerator
extends RefCounted

const MAX_ARRAY_SIDE: int = 10


static func generate(skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Problem:
	return _make(skill, params, rng, true)


## A notation card showing the square root sign over n.
static func root_card(n: int) -> Dictionary:
	return {"type": "notation", "form": "root", "n": n}


static func _make(skill: Skill, params: Dictionary, rng: RandomNumberGenerator, with_hints: bool) -> Problem:
	var problem: Problem = GeneratorKit.new_problem(skill, params, GeneratorKit.pick_representation(skill, params))
	var top: int = GeneratorKit.eased_max(2, int(params.get("max_root", 15)), GeneratorKit.difficulty_of(params), 2)
	if problem.representation == &"pictorial":
		top = mini(top, MAX_ARRAY_SIDE)
	var root: int = rng.randi_range(2, top)
	var n: int = root * root
	problem.prompt_params = {"n": n}
	problem.answer = root
	if problem.representation == &"pictorial":
		problem.prompt_line_id = &"z8.root.prompt_array"
		problem.visual = GeneratorKit.array_picture(root, root)
	else:
		problem.prompt_line_id = &"z8.root.prompt"
		problem.visual = root_card(n)
	if n % 2 == 0:
		GeneratorKit.add_distractor(problem, skill, floori(n / 2.0), &"halved")
	GeneratorKit.add_distractor(problem, skill, root + 1, &"off_by_one_root")
	GeneratorKit.add_distractor(problem, skill, root - 1, &"off_by_one_root")
	var model: Dictionary = GeneratorKit.array_picture(root, root, true) if root <= MAX_ARRAY_SIDE else root_card(n)
	if with_hints:
		var example: Problem = GeneratorKit.make_example(
			func(sub: RandomNumberGenerator) -> Problem: return _make(skill, params, sub, false), problem, rng)
		GeneratorKit.add_hints(problem, model, example, {"line_id": &"z8.hint.example_root", "params": {"r": example.answer, "n": example.prompt_params["n"]}})
	return problem
