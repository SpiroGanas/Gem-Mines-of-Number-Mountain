# Mirrors scripts/generators/ratio.gd and negatives.gd (Zone 7 ratio.* and negative.depth.*): ratios
# are checked by cross-multiplying, alloy recipes by counting groups, depths by walking the gauge one
# meter at a time.
class_name RatioNegativeGeneratorTest
extends GdUnitTestSuite

const N: int = 2000
const SKILLS: Array[StringName] = [
	&"ratio.describe.part_part", &"ratio.scale.alloy",
	&"negative.depth.read", &"negative.depth.compare", &"negative.depth.move",
]

var _catalog: SkillCatalog
var _allowed: Array[StringName]


func before() -> void:
	_catalog = SkillCatalog.load_all()
	_allowed = SkillCatalog.misconception_names()


func _problems(skill_id: StringName, count: int = N, overrides: Dictionary = {}) -> Array[Problem]:
	return GeneratorChecks.make_all(_catalog.skill(skill_id), count, overrides)


func _distractor(problem: Problem, name: StringName) -> Variant:
	for entry: Dictionary in problem.distractors:
		if entry["misconception"] == name:
			return entry["value"]
	return null


func test_every_skill_passes_the_shared_checks() -> void:
	for skill_id: StringName in SKILLS:
		assert_array(GeneratorChecks.run(_catalog.skill(skill_id), N, _allowed)).override_failure_message(str(skill_id)).is_empty()
		assert_array(GeneratorChecks.run(_catalog.skill(skill_id), 300, _allowed, {"difficulty": -1})).is_empty()


func test_a_ratio_is_copper_to_tin_in_lowest_terms() -> void:
	for problem: Problem in _problems(&"ratio.describe.part_part"):
		var a: int = problem.prompt_params["a"]
		var b: int = problem.prompt_params["b"]
		var r: Dictionary = problem.answer
		assert_bool(a != b).is_true()
		assert_int(r["a"] * b).is_equal(r["b"] * a)
		for divisor: int in range(2, mini(r["a"], r["b"]) + 1):
			assert_bool(r["a"] % divisor == 0 and r["b"] % divisor == 0).is_false()
		var flipped: Dictionary = _distractor(problem, &"inverted_ratio")
		assert_int(flipped["a"] * a).is_equal(flipped["b"] * b)


func test_counts_that_share_a_factor_come_up_when_asked_for() -> void:
	var shared: int = 0
	for problem: Problem in _problems(&"ratio.describe.part_part", 400, {"reduce_share": 100}):
		if problem.answer["a"] != problem.prompt_params["a"]:
			shared += 1
	assert_int(shared).is_equal(400)
	for problem: Problem in _problems(&"ratio.describe.part_part", 400, {"reduce_share": 0}):
		assert_int(problem.answer["a"]).is_equal(problem.prompt_params["a"]) # reduce_share 0: coprime counts
	var authored: int = 0 # as authored (about 30 in 100, since simplify.ratio.gcf is a prerequisite)
	for problem: Problem in _problems(&"ratio.describe.part_part", 400):
		if problem.answer["a"] != problem.prompt_params["a"]:
			authored += 1
	assert_int(authored).is_between(60, 180)


func test_the_alloy_grows_both_metals_by_the_same_number_of_groups() -> void:
	for problem: Problem in _problems(&"ratio.scale.alloy"):
		var p: Dictionary = problem.prompt_params
		var groups: int = 0
		var copper: int = 0
		while copper < p["c"]:
			copper += p["a"]
			groups += 1
		assert_int(copper).is_equal(p["c"]) # the hopper holds whole groups of the recipe
		assert_bool(groups >= 2 and groups <= 6).is_true()
		assert_int(problem.answer).is_equal(groups * p["b"])
		assert_int(_distractor(problem, &"scaled_one_part")).is_equal(p["b"])
		if problem.representation == &"concrete":
			assert_int(problem.meta["alloy"]["given"]).is_equal(p["c"])
			assert_bool(problem.meta["alloy"]["max"] > problem.answer).is_true()


func test_depths_are_read_with_their_sign() -> void:
	var below: int = 0
	for problem: Problem in _problems(&"negative.depth.read"):
		var depth: int = problem.answer
		assert_bool(depth != 0 and depth >= -30 and depth <= 30).is_true()
		assert_array(problem.visual["markers"]).contains_exactly([depth])
		assert_int(_distractor(problem, &"dropped_sign")).is_equal(-depth)
		assert_bool(problem.meta["signed"]).is_true()
		if depth < 0:
			below += 1
	assert_bool(below > N * 0.6).is_true()


func test_the_greater_depth_is_the_higher_one() -> void:
	for problem: Problem in _problems(&"negative.depth.compare"):
		var a: int = problem.prompt_params["a"]
		var b: int = problem.prompt_params["b"]
		assert_int(problem.answer).is_equal(maxi(a, b))
		var lower: int = mini(a, b)
		assert_bool(absi(lower) > absi(problem.answer)).is_true() # the trap: farther from zero
		assert_int(_distractor(problem, &"bigger_magnitude_bigger")).is_equal(lower)


func test_moving_the_cab_counts_meters_up_or_down() -> void:
	for problem: Problem in _problems(&"negative.depth.move"):
		var at: int = problem.prompt_params["s"]
		var down: bool = problem.prompt_line_id == &"z7.depth.prompt_down"
		for meter: int in problem.prompt_params["t"]:
			at += -1 if down else 1
		assert_int(problem.answer).is_equal(at)
		assert_bool(at >= -30 and at <= 30).is_true()
		var other_way: int = problem.prompt_params["s"] + (problem.prompt_params["t"] if down else -problem.prompt_params["t"])
		assert_int(_distractor(problem, &"wrong_direction")).is_equal(other_way)
		if problem.representation == &"pictorial":
			assert_int(problem.meta["depth_gauge"]["start"]).is_equal(problem.prompt_params["s"])
		else:
			assert_bool(problem.meta.has("depth_gauge")).is_false()
