# Mirrors scripts/core/problem.gd.
class_name ProblemTest
extends GdUnitTestSuite


func _problem(answer: Variant) -> Problem:
	var problem: Problem = Problem.new()
	problem.answer = answer
	return problem


func test_an_int_answer_matches_the_same_number_however_it_is_stored() -> void:
	var problem: Problem = _problem(34)
	assert_bool(problem.is_correct(34)).is_true()
	assert_bool(problem.is_correct(34.0)).is_true() # JSON hands back floats
	assert_bool(problem.is_correct(43)).is_false()


func test_a_choice_answer_matches_string_and_string_name() -> void:
	var problem: Problem = _problem(&"<")
	assert_bool(problem.is_correct(&"<")).is_true()
	assert_bool(problem.is_correct("<")).is_true()
	assert_bool(problem.is_correct(&">")).is_false()


func test_a_list_answer_is_order_sensitive() -> void:
	var problem: Problem = _problem([30, 4])
	assert_bool(problem.is_correct([30, 4])).is_true()
	assert_bool(problem.is_correct([4, 30])).is_false()
	assert_bool(problem.is_correct([30])).is_false()
	var typed: Array[int] = [30, 4]
	assert_bool(problem.is_correct(typed)).is_true()


func test_a_dictionary_answer_compares_by_content() -> void:
	var problem: Problem = _problem({"tens": 3, "ones": 4})
	assert_bool(problem.is_correct({"ones": 4, "tens": 3})).is_true()
	assert_bool(problem.is_correct({"tens": 4, "ones": 3})).is_false()
	assert_bool(problem.is_correct({"tens": 3.0, "ones": 4.0})).is_true()
	assert_bool(problem.is_correct({"tens": 3})).is_false()


func test_canonical_is_a_json_friendly_deep_copy() -> void:
	var original: Dictionary = {&"key": [&"a", 2.0, {&"inner": 3.0}]}
	var canon: Dictionary = Problem.canonical(original)
	assert_bool(canon.has("key")).is_true()
	assert_str(canon["key"][0]).is_equal("a")
	assert_bool(canon["key"][1] is int).is_true()
	assert_bool(canon["key"][2]["inner"] is int).is_true()
	assert_bool(original.has(&"key")).is_true() # the input is untouched


func test_to_json_has_the_documented_shape_and_survives_json() -> void:
	var problem: Problem = _problem({"tens": 3, "ones": 4})
	problem.skill_id = &"pv.tens_ones.build"
	problem.seed = 9
	problem.representation = &"concrete"
	problem.prompt_line_id = &"z1.dig.prompt_build_number"
	problem.prompt_params = {"n": 34}
	problem.answer_modes = [&"drag"]
	problem.distractors = [{"value": {"tens": 4, "ones": 3}, "misconception": &"digit_swap"}]
	problem.params = {"mode": "build"}
	var json: Dictionary = problem.to_json()
	var keys: Array = json.keys()
	keys.sort()
	assert_array(keys).contains_exactly(["answer", "answer_modes", "distractors", "hint_steps", "meta", "params", "prompt_line_id", "prompt_params", "representation", "seed", "skill_id", "visual"])
	var back: Dictionary = JsonUtil.parse_text(JSON.stringify(json))
	assert_dict(back["answer"]).is_equal({"tens": 3, "ones": 4})
	assert_str(back["distractors"][0]["misconception"]).is_equal("digit_swap")
	assert_int(back["seed"]).is_equal(9)


func test_choice_options_lists_the_answer_first_then_distractors_up_to_the_limit() -> void:
	var problem: Problem = _problem(5)
	problem.distractors = [
		{"value": 4, "misconception": &"off_by_one"}, {"value": 6, "misconception": &"off_by_one"},
		{"value": 7, "misconception": &"double_counted"}, {"value": 8, "misconception": &"double_counted"},
	]
	var options: Array[Dictionary] = problem.choice_options(func(value: Variant) -> String: return "#%s" % value)
	assert_int(options.size()).is_equal(4) # the answer plus three
	assert_dict(options[0]).is_equal({"value": 5, "label": "#5"})
	assert_array(problem.distractor_values()).contains_exactly([4, 6, 7, 8])
	assert_int(problem.choice_options(func(value: Variant) -> String: return str(value), 1).size()).is_equal(2)


func test_a_true_false_answer_matches_only_the_same_truth_value() -> void:
	var problem: Problem = _problem(true)
	assert_bool(problem.is_correct(true)).is_true()
	assert_bool(problem.is_correct(false)).is_false()
	assert_bool(problem.is_correct(1)).is_false() # a number is not a truth value


func test_label_keys_name_truth_values_and_text() -> void:
	assert_str(Problem.label_key(true)).is_equal("true")
	assert_str(Problem.label_key(false)).is_equal("false")
	assert_str(Problem.label_key(&"even")).is_equal("even")
	assert_str(Problem.label_key(12)).is_equal("12")


func test_sorted_values_puts_numbers_first_then_text_in_order() -> void:
	assert_array(Problem.sorted_values([12, 3, 7])).contains_exactly([3, 7, 12])
	assert_array(Problem.sorted_values(["8 - 5 = 3", "3 + 5 = 8", "5 + 3 = 8"])).contains_exactly(["3 + 5 = 8", "5 + 3 = 8", "8 - 5 = 3"])
	assert_array(Problem.sorted_values([&"b", 2, "a", 1])).contains_exactly([1, 2, "a", "b"])


func test_values_of_different_kinds_are_never_the_same_answer() -> void:
	assert_bool(Problem.same(1, true)).is_false()
	assert_bool(Problem.same([1, 2], [1, true])).is_false()
	assert_bool(Problem.same({"tens": 1}, {"tens": 1.0})).is_true()
	assert_bool(Problem.same(&"=", "=")).is_true()
	assert_bool(Problem.same([3, 4], [3, 4, 5])).is_false()
