# Mirrors scripts/generators/bases.gd (Zone 8 base.*): every number is re-read place by place from the
# right (ones, then base, then base times base...), digits are checked against their base, and the
# named mistakes are rebuilt from the digits.
class_name BaseGeneratorTest
extends GdUnitTestSuite

const N: int = 2000
const SKILLS: Array[StringName] = [
	&"base.binary.to_decimal", &"base.binary.from_decimal", &"base.binary.add",
	&"base.other.to_decimal", &"base.other.from_decimal",
]

var _catalog: SkillCatalog
var _allowed: Array[StringName]


func before() -> void:
	_catalog = SkillCatalog.load_all()
	_allowed = SkillCatalog.misconception_names()


func _problems(skill_id: StringName, count: int = N, overrides: Dictionary = {}) -> Array[Problem]:
	return GeneratorChecks.make_all(_catalog.skill(skill_id), count, overrides)


func _values(problem: Problem, name: StringName) -> Array:
	var found: Array = []
	for entry: Dictionary in problem.distractors:
		if entry["misconception"] == name:
			found.append(entry["value"])
	return found


## Reads digits (most significant first) from the right: ones, then base, then base², ...
func _read(digits: Array, base: int) -> int:
	var total: int = 0
	var worth: int = 1
	for index: int in range(digits.size() - 1, -1, -1):
		total += int(digits[index]) * worth
		worth *= base
	return total


func test_every_skill_passes_the_shared_checks() -> void:
	for skill_id: StringName in SKILLS:
		assert_array(GeneratorChecks.run(_catalog.skill(skill_id), N, _allowed)).override_failure_message(str(skill_id)).is_empty()
		assert_array(GeneratorChecks.run(_catalog.skill(skill_id), 300, _allowed, {"difficulty": -1})).override_failure_message(str(skill_id) + " easier").is_empty()


func test_the_same_seed_gives_the_same_problem() -> void:
	for skill_id: StringName in SKILLS:
		var skill: Skill = _catalog.skill(skill_id)
		var first: Problem = GeneratorRegistry.make_problem(skill, 99)
		assert_str(JSON.stringify(first.to_json())).is_equal(JSON.stringify(GeneratorRegistry.make_problem(skill, 99).to_json()))


func test_the_plan_examples() -> void:
	assert_int(Notation.value_of_digits([1, 1, 0, 1], 2)).is_equal(13)
	assert_int(Notation.value_of_digits([2, 3], 5)).is_equal(13)
	assert_array(Notation.digits_in_base(13, 2)).is_equal([1, 1, 0, 1])
	assert_array(Notation.digits_in_base(0, 2)).is_equal([0])
	assert_array(Notation.digits_in_base(99, 3)).is_equal([1, 0, 2, 0, 0])


func test_reading_a_number_in_a_base() -> void:
	for skill_id: StringName in [&"base.binary.to_decimal", &"base.other.to_decimal"]:
		for problem: Problem in _problems(skill_id):
			var base: int = problem.visual["base"]
			var digits: Array = problem.visual["rows"][0]
			assert_int(problem.answer).is_equal(_read(digits, base))
			assert_bool(digits.size() >= 2 and int(digits[0]) > 0).is_true()
			for digit: Variant in digits:
				assert_bool(int(digit) < base).is_true()
			if skill_id == &"base.binary.to_decimal":
				assert_int(base).is_equal(2)
				assert_bool(digits.size() <= 6).is_true()
				var reversed: Array = digits.duplicate()
				reversed.reverse()
				for wrong: Variant in _values(problem, &"reversed_bits"):
					assert_int(wrong).is_equal(_read(reversed, 2))
			else:
				assert_bool([3, 4, 5, 8].has(base)).is_true()
				assert_int(problem.prompt_params["b"]).is_equal(base)
				for wrong: Variant in _values(problem, &"used_base_two"):
					assert_int(wrong).is_equal(_read(digits, 2))
			var as_decimal: String = ""
			for digit: Variant in digits:
				as_decimal += str(int(digit))
			assert_array(_values(problem, &"read_as_decimal_digits")).contains_exactly([int(as_decimal)])


func test_writing_a_number_in_a_base() -> void:
	for skill_id: StringName in [&"base.binary.from_decimal", &"base.other.from_decimal"]:
		var locks: int = 0
		for problem: Problem in _problems(skill_id):
			var n: int = problem.prompt_params["n"]
			var base: int = problem.answer["base"]
			assert_int(_read(problem.answer["digits"], base)).is_equal(n)
			assert_bool(Notation.is_canonical_base_number(problem.answer)).is_true()
			assert_bool(problem.answer["digits"].size() >= 2).is_true()
			if problem.representation == &"concrete":
				locks += 1
				assert_int(problem.meta["vault_lock"]["base"]).is_equal(base)
				# The lock's size comes from the largest number asked for, never from this answer.
				var largest: int = 63 if base == 2 else 99
				assert_int(problem.meta["vault_lock"]["places"]).is_equal(Notation.digits_in_base(largest, base).size())
			for wrong: Variant in _values(problem, &"greedy_skipped_place"):
				assert_bool(wrong["digits"].has(0)).is_false()
				assert_bool(problem.answer["digits"].has(0)).is_true()
		assert_int(locks).is_greater(N / 3)


func test_binary_sums_always_carry() -> void:
	for problem: Problem in _problems(&"base.binary.add"):
		var a: int = problem.meta["sum"]["a"]
		var b: int = problem.meta["sum"]["b"]
		assert_int(a & b).is_not_equal(0)
		assert_int(_read(problem.answer["digits"], 2)).is_equal(a + b)
		assert_int(_read(_values(problem, &"forgot_carry")[0]["digits"], 2)).is_equal(a ^ b)
		assert_bool(_values(problem, &"carried_as_decimal")[0]["digits"].has(2)).is_true()
		assert_bool(problem.answer["digits"].size() <= problem.meta["base_pad"]["places"]).is_true()
