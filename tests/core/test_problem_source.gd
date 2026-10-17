# Mirrors scripts/core/problem_source.gd (the Sprint 5 stand-in for the adaptive engine).
class_name ProblemSourceTest
extends GdUnitTestSuite

var _catalog: SkillCatalog


func before() -> void:
	_catalog = SkillCatalog.load_all()


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func test_only_playable_zone_1_skills_are_offered() -> void:
	var source: ProblemSource = ProblemSource.new(_catalog)
	var skills: Array[Skill] = source.playable_skills()
	assert_int(skills.size()).is_equal(17)
	for skill: Skill in skills:
		assert_int(skill.zone).is_equal(1)


func test_a_wall_has_one_problem_per_rock() -> void:
	var wall: Array[Problem] = ProblemSource.new(_catalog).make_wall(8, _rng(1))
	assert_int(wall.size()).is_equal(8)
	for problem: Problem in wall:
		assert_bool(_catalog.has_skill(problem.skill_id)).is_true()


func test_the_same_seed_gives_the_same_wall() -> void:
	var first: Array[Problem] = ProblemSource.new(_catalog).make_wall(9, _rng(5))
	var second: Array[Problem] = ProblemSource.new(_catalog).make_wall(9, _rng(5))
	for index: int in 9:
		assert_dict(first[index].to_json()).is_equal(second[index].to_json())


func test_the_same_skill_never_comes_twice_in_a_row() -> void:
	var source: ProblemSource = ProblemSource.new(_catalog)
	for seed_value: int in range(1, 60):
		var wall: Array[Problem] = source.make_wall(9, _rng(seed_value))
		for index: int in range(1, wall.size()):
			assert_bool(wall[index].skill_id == wall[index - 1].skill_id).override_failure_message("seed %d rock %d repeats %s" % [seed_value, index, wall[index].skill_id]).is_false()


func test_the_pool_can_be_limited_to_chosen_skills() -> void:
	var source: ProblemSource = ProblemSource.new(_catalog, [&"pv.tens_ones.build"])
	for problem: Problem in source.make_wall(9, _rng(2)):
		assert_str(problem.skill_id).is_equal("pv.tens_ones.build")


func test_every_zone_1_skill_turns_up_across_walls() -> void:
	var seen: Dictionary = {}
	var source: ProblemSource = ProblemSource.new(_catalog)
	for seed_value: int in range(1, 60):
		for problem: Problem in source.make_wall(9, _rng(seed_value)):
			seen[problem.skill_id] = true
	assert_int(seen.size()).is_equal(17)


func test_each_representation_of_a_skill_turns_up() -> void:
	var seen: Dictionary = {}
	var source: ProblemSource = ProblemSource.new(_catalog, [&"pv.tens_ones.read"])
	for seed_value: int in range(1, 30):
		for problem: Problem in source.make_wall(9, _rng(seed_value)):
			seen[problem.representation] = true
	assert_array(seen.keys()).contains_exactly_in_any_order([&"concrete", &"abstract"])
