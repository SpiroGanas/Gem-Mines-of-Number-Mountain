# Mirrors scripts/generators/registry.gd.
class_name GeneratorRegistryTest
extends GdUnitTestSuite

var _catalog: SkillCatalog


func before() -> void:
	_catalog = SkillCatalog.load_all()


func test_every_skill_of_zones_1_to_4_has_a_generator() -> void:
	for zone: int in [1, 2, 3, 4]:
		for skill: Skill in _catalog.skills_in_zone(zone):
			assert_bool(GeneratorRegistry.has_generator(skill.generator)).override_failure_message("no generator for " + skill.id).is_true()
			assert_bool(GeneratorRegistry.callable_for(skill).is_valid()).is_true()


func test_zone_4_has_its_sixteen_skills_and_five_generators() -> void:
	var zone: Array[Skill] = _catalog.skills_in_zone(4)
	assert_int(zone.size()).is_equal(16)
	var names: Dictionary = {}
	for skill: Skill in zone:
		names[skill.generator] = true
	assert_array(names.keys()).contains_exactly_in_any_order([&"MultFactsGenerator", &"DivFactsGenerator", &"FactorsGenerator", &"MultiplesGenerator", &"PrimeCompositeGenerator"])


func test_a_skill_without_a_built_generator_gets_an_invalid_callable() -> void:
	var skill: Skill = _catalog.skill(&"add.to_10.sums").duplicate()
	skill.generator = &"PrimeGenerator" # a later zone's generator, not built in the MVP
	assert_bool(GeneratorRegistry.callable_for(skill).is_valid()).is_false()


func test_every_registered_generator_is_used_by_a_skill() -> void:
	var used: Dictionary = {}
	for id: StringName in _catalog.ids():
		used[_catalog.skill(id).generator] = true
	for name: StringName in GeneratorRegistry.registered_names():
		assert_bool(used.has(name)).override_failure_message("%s is registered but no skill uses it" % name).is_true()
	assert_array(GeneratorRegistry.registered_names()).contains([&"CountingGenerator", &"CompareGenerator", &"PlaceValueGenerator", &"RegroupGenerator"])


func test_make_problem_records_the_seed_and_is_reproducible() -> void:
	var skill: Skill = _catalog.skill(&"pv.tens_ones.build")
	var first: Problem = GeneratorRegistry.make_problem(skill, 4242)
	var second: Problem = GeneratorRegistry.make_problem(skill, 4242)
	assert_int(first.seed).is_equal(4242)
	assert_dict(first.to_json()).is_equal(second.to_json())


func test_different_seeds_give_different_problems() -> void:
	var skill: Skill = _catalog.skill(&"pv.tens_ones.build")
	var seen: Dictionary = {}
	for seed: int in range(1, 200):
		seen[GeneratorRegistry.make_problem(skill, seed).prompt_params["n"]] = true
	assert_int(seen.size()).is_greater(40)


func test_overrides_change_the_problem_but_never_the_skill() -> void:
	var skill: Skill = _catalog.skill(&"count.write.numeral")
	var before_params: Dictionary = skill.params.duplicate(true)
	var abstract: Problem = GeneratorRegistry.make_problem(skill, 1, {"representation": &"abstract"})
	var concrete: Problem = GeneratorRegistry.make_problem(skill, 1, {"representation": &"concrete"})
	assert_str(abstract.representation).is_equal("abstract")
	assert_str(concrete.representation).is_equal("concrete")
	assert_dict(skill.params).is_equal(before_params)
	assert_str(abstract.params["representation"]).is_equal("abstract")


func test_an_unlisted_representation_falls_back_to_the_skills_first() -> void:
	var skill: Skill = _catalog.skill(&"cmp.to_20.more_less") # concrete only
	var problem: Problem = GeneratorRegistry.make_problem(skill, 1, {"representation": &"abstract"})
	assert_str(problem.representation).is_equal("concrete")


func test_the_easier_step_regenerates_a_smaller_problem_of_the_same_skill() -> void:
	var skill: Skill = _catalog.skill(&"count.to_20.objects")
	var biggest: int = 0
	for seed: int in range(1, 300):
		var problem: Problem = GeneratorRegistry.make_problem(skill, seed)
		var easier: Problem = GeneratorRegistry.make_problem(skill, seed + 1000, problem.hint_steps[3]["easier_params"])
		assert_str(easier.skill_id).is_equal(problem.skill_id)
		biggest = maxi(biggest, easier.answer)
	assert_int(biggest).is_less(20)
