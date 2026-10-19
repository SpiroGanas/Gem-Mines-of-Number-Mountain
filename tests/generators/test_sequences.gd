# Mirrors scripts/generators/sequences.gd (Zone 9 seq.*): arithmetic sequences add the same step and
# never go below zero, geometric ones multiply by a ratio from the list and stay under max_value, the
# rule is the step, and classify names the kind. Answers are rechecked here by walking the terms.
class_name SequenceGeneratorTest
extends GdUnitTestSuite

const N: int = 2000
const SKILLS: Array[StringName] = [
	&"seq.arith.next_term", &"seq.arith.missing_term", &"seq.arith.rule_describe",
	&"seq.geom.next_term", &"seq.arith_vs_geom.classify",
]

var _catalog: SkillCatalog
var _allowed: Array[StringName]


func before() -> void:
	_catalog = SkillCatalog.load_all()
	_allowed = SkillCatalog.misconception_names()


func _problems(skill_id: StringName, count: int = N, overrides: Dictionary = {}) -> Array[Problem]:
	return GeneratorChecks.make_all(_catalog.skill(skill_id), count, overrides)


func _distractor(problem: Problem, name: StringName) -> Array:
	var values: Array = []
	for entry: Dictionary in problem.distractors:
		if entry["misconception"] == name:
			values.append(entry["value"])
	return values


## The shown terms of a problem in order, the blank (if any) as null, from its prompt parameters.
func _shown(problem: Problem) -> Array:
	var terms: Array = []
	for key: String in ["a", "b", "c", "d", "e"]:
		if problem.prompt_params.has(key):
			terms.append(problem.prompt_params[key])
		elif problem.prompt_line_id.begins_with("z9.seq.prompt_missing") and terms.size() < 5:
			terms.append(null)
	return terms


func test_every_skill_passes_the_shared_checks() -> void:
	for skill_id: StringName in SKILLS:
		assert_array(GeneratorChecks.run(_catalog.skill(skill_id), N, _allowed)).override_failure_message(str(skill_id)).is_empty()
		assert_array(GeneratorChecks.run(_catalog.skill(skill_id), 300, _allowed, {"difficulty": -1})).override_failure_message(str(skill_id) + " easier").is_empty()


func test_the_same_seed_gives_the_same_problem() -> void:
	for skill_id: StringName in SKILLS:
		var skill: Skill = _catalog.skill(skill_id)
		for seed_value: int in [1, 77, 4096]:
			var first: Dictionary = GeneratorRegistry.make_problem(skill, seed_value).to_json()
			var again: Dictionary = GeneratorRegistry.make_problem(skill, seed_value).to_json()
			assert_str(JSON.stringify(first)).is_equal(JSON.stringify(again))


func test_the_next_term_adds_the_step_and_never_goes_below_zero() -> void:
	for problem: Problem in _problems(&"seq.arith.next_term"):
		var t: Array = _shown(problem)
		var step: int = int(t[1]) - int(t[0])
		assert_int(step).is_between(1, 9)
		assert_int(int(t[0])).is_between(1, 20)
		for index: int in range(1, 4):
			assert_int(int(t[index]) - int(t[index - 1])).is_equal(step)
		assert_int(problem.answer).is_equal(int(t[3]) + step)
		assert_array(_distractor(problem, &"repeated_last_term")).contains_exactly([t[3]])
		for wrong: Variant in _distractor(problem, &"added_wrong_step"):
			assert_int(absi(int(wrong) - problem.answer)).is_equal(1)
		if problem.representation == &"concrete":
			var wall: Dictionary = problem.meta["pattern_wall"]
			assert_array(wall["terms"]).is_equal([t[0], t[1], t[2], t[3], null])
			assert_bool(wall["tiles"].has(problem.answer)).is_true()
		else:
			assert_bool(problem.meta.has("pattern_wall")).is_false()


func test_a_missing_term_sits_between_its_neighbors() -> void:
	var gaps: Dictionary = {}
	for problem: Problem in _problems(&"seq.arith.missing_term"):
		var t: Array = _shown(problem)
		var blank: int = t.find(null)
		gaps[blank] = true
		assert_int(blank).is_between(1, 3)
		var step: int = floori((int(t[4]) - int(t[0])) / 4.0)
		assert_int(int(t[4]) - int(t[0])).is_equal(4 * step)
		assert_int(problem.answer).is_equal(int(t[0]) + blank * step)
		assert_array(_distractor(problem, &"averaged_neighbors_wrong")).contains_exactly([int(t[blank - 1]) + int(t[blank + 1])])
		assert_bool(problem.meta.has("pattern_wall")).is_equal(problem.representation == &"pictorial")
	assert_int(gaps.size()).is_equal(3)


func test_the_rule_is_the_step_and_its_buttons_read_add() -> void:
	for problem: Problem in _problems(&"seq.arith.rule_describe"):
		var t: Array = _shown(problem)
		assert_int(problem.answer).is_equal(int(t[1]) - int(t[0]))
		assert_array(_distractor(problem, &"confused_start_and_step")).contains_exactly([t[0]])
		assert_str(str(problem.meta["label_line"])).is_equal("z9.seq.rule_add")
		assert_int(problem.distractors.size()).is_greater_equal(2)
	assert_str(Text.get_line(&"z9.seq.rule_add", {"n": 4})).is_equal("Add 4")


func test_geometric_terms_multiply_and_stay_under_max_value() -> void:
	var ratios: Dictionary = {}
	for problem: Problem in _problems(&"seq.geom.next_term"):
		var t: Array = _shown(problem)
		var ratio: int = floori(int(t[1]) / float(int(t[0])))
		ratios[ratio] = true
		assert_bool([2, 3, 5, 10].has(ratio)).is_true()
		for index: int in range(1, t.size()):
			assert_int(int(t[index])).is_equal(int(t[index - 1]) * ratio)
		assert_int(problem.answer).is_equal(int(t[t.size() - 1]) * ratio)
		assert_int(problem.answer).is_less_equal(1000)
		assert_int(int(problem.meta["pad_digits"])).is_equal(4)
		assert_array(_distractor(problem, &"added_ratio")).contains_exactly([int(t[t.size() - 1]) + ratio])
	assert_int(ratios.size()).is_equal(4)


func test_classify_names_the_kind_and_offers_both_others() -> void:
	var kinds: Dictionary = {}
	for problem: Problem in _problems(&"seq.arith_vs_geom.classify"):
		var t: Array = _shown(problem)
		var adds: bool = int(t[1]) - int(t[0]) == int(t[2]) - int(t[1]) and int(t[2]) - int(t[1]) == int(t[3]) - int(t[2])
		var multiplies: bool = int(t[1]) * int(t[1]) == int(t[0]) * int(t[2]) and int(t[2]) * int(t[2]) == int(t[1]) * int(t[3])
		assert_bool(adds != multiplies).is_true() # exactly one kind, never both
		assert_str(str(problem.answer)).is_equal("arithmetic" if adds else "geometric")
		kinds[str(problem.answer)] = true
		assert_int(problem.distractors.size()).is_equal(2)
	assert_int(kinds.size()).is_equal(2)
	for key: String in SequenceGenerator.CLASSIFY_LABELS:
		assert_bool(Text.has_line(StringName(SequenceGenerator.CLASSIFY_LABELS[key]))).is_true()


func test_easier_problems_use_smaller_numbers() -> void:
	var full: int = 0
	var easier: int = 0
	for problem: Problem in _problems(&"seq.arith.next_term", 400):
		full = maxi(full, problem.answer)
	for problem: Problem in _problems(&"seq.arith.next_term", 400, {"difficulty": -1}):
		easier = maxi(easier, problem.answer)
	assert_int(easier).is_less(full)
