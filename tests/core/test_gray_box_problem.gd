# Mirrors scripts/core/gray_box_problem.gd (the Sprint 4 stand-in, deleted in Sprint 5).
class_name GrayBoxProblemTest
extends GdUnitTestSuite


func test_answers_are_between_11_and_99_and_match_the_prompt_number() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1
	for i: int in 2000:
		var problem: Dictionary = GrayBoxProblem.build_number(rng)
		var n: int = problem["prompt_params"]["n"]
		assert_int(n).is_between(11, 99)
		assert_int(problem["answer"]["tens"] * 10 + problem["answer"]["ones"]).is_equal(n)
		assert_int(problem["answer"]["ones"]).is_between(0, 9)
		assert_int(problem["answer"]["tens"]).is_between(1, 9)


func test_the_same_seed_gives_the_same_problems() -> void:
	var first: RandomNumberGenerator = RandomNumberGenerator.new()
	first.seed = 42
	var second: RandomNumberGenerator = RandomNumberGenerator.new()
	second.seed = 42
	for i: int in 50:
		assert_dict(GrayBoxProblem.build_number(first)).is_equal(GrayBoxProblem.build_number(second))


func test_is_correct_compares_tens_and_ones() -> void:
	var problem: Dictionary = {"answer": {"tens": 3, "ones": 4}}
	assert_bool(GrayBoxProblem.is_correct(problem, {"tens": 3, "ones": 4})).is_true()
	assert_bool(GrayBoxProblem.is_correct(problem, {"tens": 4, "ones": 3})).is_false() # digit swap
	assert_bool(GrayBoxProblem.is_correct(problem, {"tens": 0, "ones": 7})).is_false()
	assert_bool(GrayBoxProblem.is_correct(problem, {})).is_false()


func test_the_prompt_line_exists_and_takes_n() -> void:
	assert_bool(Text.has_line(GrayBoxProblem.PROMPT_LINE_ID)).is_true()
	assert_array(Text.required_params(GrayBoxProblem.PROMPT_LINE_ID)).contains_exactly(["n"])
