## Finds the generator for a skill and makes reproducible problems.
##
## A skill's `generator` field names a class ("CountingGenerator"). Each generator is a pure
## `static func generate(skill, params, rng) -> Problem`; adding a zone's generators means adding
## its file and one line to table(). Names are checked at load time by tests/curriculum.
##
## Godot note: `ClassName.method` (no parentheses) is a Callable for a static function, so the
## table is compile-checked: a typo here fails to load instead of failing mid-game.
class_name GeneratorRegistry
extends RefCounted


## generator name -> Callable(skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Problem
static func table() -> Dictionary:
	return {
		&"CountingGenerator": CountingGenerator.generate,
		&"CompareGenerator": CompareGenerator.generate,
		&"PlaceValueGenerator": PlaceValueGenerator.generate,
		&"RegroupGenerator": RegroupGenerator.generate,
		&"FactFamilyGenerator": FactFamilyGenerator.generate,
		&"MissingPartGenerator": MissingPartGenerator.generate,
		&"BalanceGenerator": BalanceGenerator.generate,
		&"AdditionGenerator": AdditionGenerator.generate,
		&"SubtractionGenerator": SubtractionGenerator.generate,
	}


static func registered_names() -> Array[StringName]:
	var names: Array[StringName] = []
	for name: StringName in table():
		names.append(name)
	return names


static func has_generator(name: StringName) -> bool:
	return table().has(name)


## The generate function for a skill, or an invalid Callable if its generator is not built yet.
static func callable_for(skill: Skill) -> Callable:
	return table().get(skill.generator, Callable())


## A reproducible problem: the same skill, seed and overrides always give the same problem.
## `overrides` is merged over the skill's params (for example {representation, difficulty}).
static func make_problem(skill: Skill, seed: int, overrides: Dictionary = {}) -> Problem:
	var generate: Callable = callable_for(skill)
	assert(generate.is_valid(), "no generator for %s" % skill.id)
	var merged: Dictionary = skill.params.duplicate(true)
	merged.merge(overrides, true)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed
	var problem: Problem = generate.call(skill, merged, rng)
	problem.seed = seed
	return problem
