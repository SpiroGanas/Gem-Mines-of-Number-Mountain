# Mirrors scripts/generators/place_value.gd.
class_name PlaceValueGeneratorTest
extends GdUnitTestSuite

const N: int = 3000

var _catalog: SkillCatalog


func before() -> void:
	_catalog = SkillCatalog.load_all()


func _problems(skill_id: StringName, overrides: Dictionary = {}, count: int = N) -> Array[Problem]:
	return GeneratorChecks.make_all(_catalog.skill(skill_id), count, overrides)


func _value_of(pile: Dictionary) -> int:
	return pile["hundreds"] * 100 + pile["tens"] * 10 + pile["ones"]


func _by_name(problem: Problem) -> Dictionary:
	var result: Dictionary = {}
	for entry: Dictionary in problem.distractors:
		result[String(entry["misconception"])] = entry["value"]
	return result


func test_build_asks_for_the_tens_and_ones_of_the_number() -> void:
	for problem: Problem in _problems(&"pv.tens_ones.build"):
		var n: int = problem.prompt_params["n"]
		assert_int(n).is_between(11, 99)
		assert_dict(problem.answer).is_equal({"tens": floori(n / 10.0), "ones": n % 10})
		var wrong: Dictionary = _by_name(problem)
		if wrong.has("digit_swap"):
			assert_dict(wrong["digit_swap"]).is_equal({"tens": n % 10, "ones": floori(n / 10.0)})
		if wrong.has("counted_tens_as_ones"):
			assert_dict(wrong["counted_tens_as_ones"]).is_equal({"tens": 0, "ones": floori(n / 10.0) + n % 10})
		assert_array(problem.meta["tools"]).contains_exactly(["ten", "one"])


func test_read_in_both_representations() -> void:
	var seen: Dictionary = {}
	for problem: Problem in _problems(&"pv.tens_ones.read"):
		seen[problem.representation] = true
		var n: int = problem.answer
		assert_int(n).is_between(11, 99)
		if problem.representation == &"concrete":
			assert_int(_value_of(problem.visual["piles"][0])).is_equal(n)
		else:
			assert_int(problem.prompt_params["tens"] * 10 + problem.prompt_params["ones"]).is_equal(n)
		var wrong: Dictionary = _by_name(problem)
		if wrong.has("counted_bars_as_ones"):
			assert_int(wrong["counted_bars_as_ones"]).is_equal(floori(n / 10.0) + n % 10)
		if wrong.has("digit_swap"):
			assert_int(wrong["digit_swap"]).is_equal((n % 10) * 10 + floori(n / 10.0))
	assert_int(seen.size()).is_equal(2)


func test_expanded_form_lists_tens_value_then_ones() -> void:
	for problem: Problem in _problems(&"pv.tens_ones.expanded"):
		var n: int = problem.prompt_params["n"]
		assert_array(problem.answer).is_equal([floori(n / 10.0) * 10, n % 10])
		assert_int(problem.answer[0] + problem.answer[1]).is_equal(n)
		var wrong: Dictionary = _by_name(problem)
		if wrong.has("digit_value_as_digit"):
			assert_array(wrong["digit_value_as_digit"]).is_equal([floori(n / 10.0), n % 10])
		if wrong.has("digit_swap"):
			assert_array(wrong["digit_swap"]).is_equal([(n % 10) * 10, floori(n / 10.0)])


func test_digit_value_names_the_value_of_the_digit_asked_about() -> void:
	var asked_tens: int = 0
	var asked_ones: int = 0
	for problem: Problem in _problems(&"pv.tens_ones.digit_value"):
		var n: int = problem.prompt_params["n"]
		var tens: int = floori(n / 10.0)
		var ones: int = n % 10
		assert_int(tens).is_not_equal(ones) # "the 3 in 33" would be ambiguous
		var digit: int = problem.prompt_params["digit"]
		if problem.meta["place"] == "tens":
			asked_tens += 1
			assert_int(digit).is_equal(tens)
			assert_int(problem.answer).is_equal(tens * 10)
		else:
			asked_ones += 1
			assert_int(digit).is_equal(ones)
			assert_int(ones).is_not_equal(0) # the value of a zero is not worth asking
			assert_int(problem.answer).is_equal(ones)
	assert_int(asked_tens).is_greater(1000)
	assert_int(asked_ones).is_greater(1000)


func test_ten_more_and_ten_less() -> void:
	var more: int = 0
	var less: int = 0
	for problem: Problem in _problems(&"pv.tens.ten_more_less"):
		var n: int = problem.prompt_params["n"]
		assert_int(n).is_between(10, 110)
		if problem.meta["direction"] == "more":
			more += 1
			assert_int(problem.answer).is_equal(n + 10)
			assert_str(problem.prompt_line_id).is_equal("z1.pv.prompt_ten_more")
		else:
			less += 1
			assert_int(problem.answer).is_equal(n - 10)
			assert_str(problem.prompt_line_id).is_equal("z1.pv.prompt_ten_less")
		assert_int(problem.answer).is_between(0, 120)
		assert_int(_value_of(problem.visual["piles"][0])).is_equal(n)
		for entry: Dictionary in problem.distractors:
			if entry["misconception"] == &"changed_ones":
				assert_int(entry["value"]).is_equal(n + 1 if problem.meta["direction"] == "more" else n - 1)
			else:
				assert_int(absi(entry["value"] - problem.answer)).is_equal(1)
	assert_int(more).is_greater(1000)
	assert_int(less).is_greater(1000)


func test_build_hundred_covers_100_to_120() -> void:
	var seen: Dictionary = {}
	for problem: Problem in _problems(&"pv.hundred.intro"):
		var a: Dictionary = problem.answer
		var n: int = a["hundreds"] * 100 + a["tens"] * 10 + a["ones"]
		seen[n] = true
		assert_int(n).is_between(100, 120)
		assert_int(a["hundreds"]).is_equal(1)
		assert_int(problem.prompt_params["n"]).is_equal(n)
		assert_array(problem.meta["tools"]).contains_exactly(["hundred", "ten", "one"])
		var wrong: Dictionary = _by_name(problem)
		if wrong.has("counted_tens_as_ones"):
			assert_dict(wrong["counted_tens_as_ones"]).is_equal({"hundreds": 1, "tens": 0, "ones": a["tens"] + a["ones"]})
	assert_int(seen.size()).is_equal(21) # every number from 100 to 120 turns up


func test_the_sample_numbers_in_hint_examples_use_the_same_range() -> void:
	for problem: Problem in _problems(&"pv.tens_ones.build", {}, 300):
		var example_answer: Dictionary = problem.hint_steps[2]["example"]["answer"]
		assert_int(example_answer["tens"] * 10 + example_answer["ones"]).is_between(11, 99)
