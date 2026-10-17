# Mirrors scripts/generators/compare.gd.
class_name CompareGeneratorTest
extends GdUnitTestSuite

const N: int = 3000

var _catalog: SkillCatalog


func before() -> void:
	_catalog = SkillCatalog.load_all()


func _problems(skill_id: StringName, overrides: Dictionary = {}, count: int = N) -> Array[Problem]:
	return GeneratorChecks.make_all(_catalog.skill(skill_id), count, overrides)


func _pile_value(pile: Dictionary) -> int:
	return pile["hundreds"] * 100 + pile["tens"] * 10 + pile["ones"]


func test_more_less_picks_the_right_pile_for_the_question_asked() -> void:
	var asked_more: int = 0
	var asked_fewer: int = 0
	for problem: Problem in _problems(&"cmp.to_20.more_less"):
		var a: int = _pile_value(problem.visual["piles"][0])
		var b: int = _pile_value(problem.visual["piles"][1])
		assert_int(a).is_between(1, 20)
		assert_int(b).is_between(1, 20)
		assert_int(a).is_not_equal(b) # equal piles would have no right answer
		var ask: String = problem.meta["ask"]
		if ask == "more":
			asked_more += 1
			assert_int(problem.answer).is_equal(0 if a > b else 1)
			assert_str(problem.prompt_line_id).is_equal("z1.cmp.prompt_more")
		else:
			asked_fewer += 1
			assert_int(problem.answer).is_equal(0 if a < b else 1)
			assert_str(problem.prompt_line_id).is_equal("z1.cmp.prompt_fewer")
		assert_array(problem.distractor_values()).contains_exactly([1 - problem.answer])
		assert_str(problem.meta["tap_target"]).is_equal("pile")
	assert_int(asked_more).is_greater(1000)
	assert_int(asked_fewer).is_greater(1000)


func test_more_less_can_be_forced_to_one_question() -> void:
	for problem: Problem in _problems(&"cmp.to_20.more_less", {"ask": "fewer"}, 300):
		assert_str(problem.meta["ask"]).is_equal("fewer")


func test_the_bigger_pile_is_on_either_side() -> void:
	var left: int = 0
	for problem: Problem in _problems(&"cmp.to_20.more_less", {"ask": "more"}):
		if problem.answer == 0:
			left += 1
	assert_int(left).is_between(N / 3, N * 2 / 3)


func test_symbols_follow_the_comparison() -> void:
	var equal_count: int = 0
	var conflict_count: int = 0
	var unequal_count: int = 0
	for problem: Problem in _problems(&"cmp.to_100.symbols"):
		var a: int = problem.prompt_params["a"]
		var b: int = problem.prompt_params["b"]
		assert_int(a).is_between(1, 100)
		assert_int(b).is_between(1, 100)
		var expected: String = "=" if a == b else ("<" if a < b else ">")
		assert_str(problem.answer).is_equal(expected)
		var wrong: Dictionary = {}
		for entry: Dictionary in problem.distractors:
			wrong[String(entry["value"])] = entry["misconception"]
		assert_int(wrong.size()).is_equal(2) # the three symbol buttons always have two wrong ones
		if a == b:
			equal_count += 1
			assert_str(wrong["<"]).is_equal("thought_unequal")
			assert_str(wrong[">"]).is_equal("thought_unequal")
		else:
			unequal_count += 1
			var opposite: String = ">" if expected == "<" else "<"
			var disagree: bool = (floori(a / 10.0) < floori(b / 10.0) and a % 10 > b % 10) or (floori(a / 10.0) > floori(b / 10.0) and a % 10 < b % 10)
			assert_bool(problem.meta["conflict"]).is_equal(disagree)
			assert_str(wrong[opposite]).is_equal("compared_ones_first" if disagree else "reversed_symbol")
			assert_str(wrong["="]).is_equal("thought_equal")
			if disagree:
				conflict_count += 1
	assert_float(float(equal_count) / float(N)).is_between(0.10, 0.20)
	assert_float(float(conflict_count) / float(unequal_count)).is_greater(0.3) # the tricky pairs appear often


func test_ordering_numbers_least_or_greatest_first() -> void:
	var least: int = 0
	var greatest: int = 0
	for problem: Problem in _problems(&"cmp.to_100.order3"):
		var numbers: Array = problem.meta["numbers"]
		assert_array(numbers).has_size(3)
		var unique: Dictionary = {}
		for value: int in numbers:
			unique[value] = true
			assert_int(value).is_between(10, 100)
		assert_int(unique.size()).is_equal(3)
		var ascending: Array = numbers.duplicate()
		ascending.sort()
		var shown: Array = []
		for pile: Dictionary in problem.visual["piles"]:
			shown.append(_pile_value(pile))
		assert_array(shown).is_equal(numbers) # the piles are drawn in the order of meta.numbers
		if problem.meta["direction"] == "least_first":
			least += 1
			assert_array(problem.answer).is_equal(ascending)
		else:
			greatest += 1
			var descending: Array = ascending.duplicate()
			descending.reverse()
			assert_array(problem.answer).is_equal(descending)
		assert_array(numbers).is_not_equal(problem.answer) # the child always has something to rearrange
	assert_int(least).is_greater(1000)
	assert_int(greatest).is_greater(1000)


func test_order_distractors_are_the_reversed_order_and_the_ones_first_order() -> void:
	for problem: Problem in _problems(&"cmp.to_100.order3"):
		var reversed: Array = problem.answer.duplicate()
		reversed.reverse()
		var by_ones: Array = problem.meta["numbers"].duplicate()
		by_ones.sort_custom(func(x: int, y: int) -> bool: return [x % 10, x] < [y % 10, y])
		if problem.meta["direction"] == "greatest_first":
			by_ones.reverse()
		for entry: Dictionary in problem.distractors:
			if entry["misconception"] == &"reversed_order":
				assert_array(entry["value"]).is_equal(reversed)
			else:
				assert_str(entry["misconception"]).is_equal("compared_ones_first")
				assert_array(entry["value"]).is_equal(by_ones)
