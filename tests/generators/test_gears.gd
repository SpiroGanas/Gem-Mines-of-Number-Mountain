# Mirrors scripts/generators/gears.gd (P4-S29-05). Written test-first. The gear facts are worked out
# here by simulation, not arithmetic: turning a gear tooth by tooth and counting full turns, and
# counting teeth until two marked teeth are back where they started together.
class_name GearGeneratorTest
extends GdUnitTestSuite

const N: int = 1500
const SKILLS: Array[StringName] = [&"gear.ratio.teeth", &"gear.sync.turns_to_align"]

var _catalog: SkillCatalog
var _allowed: Array[StringName]


func before() -> void:
	_catalog = SkillCatalog.load_all()
	_allowed = SkillCatalog.misconception_names()


func _problems(skill_id: StringName, overrides: Dictionary = {}, count: int = N) -> Array[Problem]:
	return GeneratorChecks.make_all(_catalog.skill(skill_id), count, overrides)


## Turns of a gear with `small` teeth while `driver` teeth pass (counted tooth by tooth).
func _turns_while(driver_teeth_passing: int, small: int) -> float:
	var full: int = 0
	var at: int = 0
	for tooth: int in driver_teeth_passing:
		at += 1
		if at == small:
			full += 1
			at = 0
	return full + float(at) / small


## Teeth that pass before both marks are back at the meeting point together (at least one tooth).
func _teeth_until_marks_meet(a: int, b: int) -> int:
	var passed: int = 0
	while true:
		passed += 1
		if passed % a == 0 and passed % b == 0:
			return passed
	return 0


func _by_name(problem: Problem, name: String) -> Variant:
	for entry: Dictionary in problem.distractors:
		if entry["misconception"] == name:
			return entry["value"]
	return null


func test_every_skill_passes_the_shared_checks() -> void:
	for skill_id: StringName in SKILLS:
		assert_array(GeneratorChecks.run(_catalog.skill(skill_id), N, _allowed)).is_empty()
		assert_array(GeneratorChecks.run(_catalog.skill(skill_id), 400, _allowed, {"difficulty": -1})).is_empty()
		assert_array(GeneratorChecks.run(_catalog.skill(skill_id), 200, _allowed, {"difficulty": -2})).is_empty()


func test_the_same_seed_gives_the_same_problem() -> void:
	for skill_id: StringName in SKILLS:
		for seed: int in range(1, 21):
			var first: Problem = GeneratorRegistry.make_problem(_catalog.skill(skill_id), seed)
			var second: Problem = GeneratorRegistry.make_problem(_catalog.skill(skill_id), seed)
			assert_str(JSON.stringify(first.to_json())).is_equal(JSON.stringify(second.to_json()))


func test_the_picked_gear_turns_k_times_for_one_turn_of_the_big_gear() -> void:
	var turns_seen: Dictionary = {}
	for problem: Problem in _problems(&"gear.ratio.teeth"):
		var a: int = problem.prompt_params["a"]
		var k: int = problem.prompt_params["k"]
		assert_bool([12, 16, 18, 24, 30, 32, 36, 48].has(a)).is_true()
		assert_bool([2, 3, 4].has(k)).is_true()
		assert_float(_turns_while(a, problem.answer)).is_equal(float(k))
		assert_int(problem.answer).is_greater_equal(6)
		assert_int(_by_name(problem, "inverted_ratio")).is_equal(a * k)
		assert_int(_by_name(problem, "subtracted_teeth")).is_equal(a - k)
		assert_int(_by_name(problem, "same_size_gear")).is_equal(a)
		turns_seen[k] = true
	assert_int(turns_seen.size()).is_equal(3)


func test_the_concrete_ratio_problem_is_the_gear_bench() -> void:
	for problem: Problem in _problems(&"gear.ratio.teeth", {}, 200):
		if problem.representation == &"concrete":
			var bench: Dictionary = problem.meta["gear_bench"]
			assert_int(bench["driver"]).is_equal(problem.prompt_params["a"])
			assert_int(bench["turns"]).is_equal(problem.prompt_params["k"])
			assert_bool(bench["tray"].has(problem.answer)).is_true()
			assert_int(bench["tray"].size()).is_equal(problem.distractors.size() + 1)
			assert_dict(problem.visual).is_empty()
			assert_int(AnswerPanel.choose_input(problem)).is_equal(AnswerPanel.InputKind.GEAR)
		else:
			assert_bool(problem.meta.has("gear_bench")).is_false()
			assert_dict(problem.visual).is_equal({"type": "gears", "teeth": [problem.prompt_params["a"]]})
			assert_int(AnswerPanel.choose_input(problem)).is_equal(AnswerPanel.InputKind.CHOICES)


func test_easier_ratio_problems_turn_twice() -> void:
	for problem: Problem in _problems(&"gear.ratio.teeth", {"difficulty": -1}, 300):
		assert_int(problem.prompt_params["k"]).is_equal(2)


func test_marks_meet_after_the_lcm_of_teeth() -> void:
	for problem: Problem in _problems(&"gear.sync.turns_to_align"):
		var a: int = problem.prompt_params["a"]
		var b: int = problem.prompt_params["b"]
		assert_bool(a != b and a >= 6 and a <= 24 and b >= 6 and b <= 24).is_true()
		var teeth: int = _teeth_until_marks_meet(a, b)
		assert_int(problem.answer * a).is_equal(teeth)
		assert_int(problem.answer).is_between(2, GearGenerator.MAX_TURNS)
		assert_int(_by_name(problem, "teeth_not_turns")).is_equal(teeth)
		var other: Variant = _by_name(problem, "counted_other_gear")
		if other != null:
			assert_int(other * b).is_equal(teeth)
		assert_dict(problem.visual).is_equal({"type": "gears", "teeth": [a, b], "marks": true})


func test_gear_train_logic_agrees_with_the_generator() -> void:
	for problem: Problem in _problems(&"gear.sync.turns_to_align", {}, 300):
		var teeth: Array[int] = [problem.prompt_params["a"], problem.prompt_params["b"]]
		assert_int(GearTrain.turns_to_align(teeth)).is_equal(problem.answer)
