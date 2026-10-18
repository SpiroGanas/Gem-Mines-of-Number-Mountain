## "Who is right?" for Zone 5 (skill pf.fta.unique): the Fundamental Theorem of Arithmetic, every
## number has exactly one prime recipe. Three miners show recipes for {n} as answer buttons ("2 × 2 × 3",
## meta.array_label "product"): the true one, one that still has a composite piece in it, and one made
## of primes whose product is not n. n is composite with at least three prime factors (repeats
## counted), so a recipe with a composite piece still has two numbers. Pure: only the passed-in rng.
##
## The named mistakes:
##   tree_with_composite_leaf  picked the recipe with a composite left in it (12 as 3 × 4);
##   product_mismatch          picked primes whose product is not n (12 as 2 × 2 × 5).
class_name FtaGenerator
extends RefCounted

const PROMPT: StringName = &"z5.fta.prompt"


static func generate(skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Problem:
	return _make(skill, params, rng, true)


static func _make(skill: Skill, params: Dictionary, rng: RandomNumberGenerator, with_hints: bool) -> Problem:
	var problem: Problem = GeneratorKit.new_problem(skill, params, GeneratorKit.pick_representation(skill, params))
	var n: int = FactorTreeGenerator.pick(FactorTreeGenerator.composites_in_range(params, 3), rng)
	var recipe: Array[int] = MathUtil.prime_factorization(n)
	problem.prompt_line_id = PROMPT
	problem.prompt_params = {"n": n}
	problem.answer = recipe
	problem.meta = {"array_label": "product"}
	GeneratorKit.add_distractor(problem, skill, _composite_leaf(recipe, rng), &"tree_with_composite_leaf")
	GeneratorKit.add_distractor(problem, skill, FactorTreeGenerator.with_wrong_prime(recipe), &"product_mismatch")
	if with_hints:
		var example: Problem = GeneratorKit.make_example(
			func(sub: RandomNumberGenerator) -> Problem: return _make(skill, params, sub, false), problem, rng)
		GeneratorKit.add_hints(problem, FactorTreeGenerator.split_model(n), example, FactorTreeGenerator.recipe_line(example.prompt_params["n"]))
	return problem


## The recipe with two neighbouring primes (a random pair) multiplied back into one composite piece.
static func _composite_leaf(recipe: Array[int], rng: RandomNumberGenerator) -> Array[int]:
	var at: int = rng.randi_range(0, recipe.size() - 2)
	var result: Array[int] = []
	for index: int in recipe.size():
		if index == at:
			result.append(recipe[index] * recipe[index + 1])
		elif index != at + 1:
			result.append(recipe[index])
	result.sort()
	return result
