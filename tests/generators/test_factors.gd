# Mirrors scripts/generators/factors.gd: the factor lists are complete (checked against trial division
# written in this test), the three kinds of wrong board are what they claim to be, rectangles hold
# exactly n gems, and each yes/no question's wrong answer stands for the mistake named.
class_name FactorsGeneratorTest
extends GdUnitTestSuite

const N: int = 2000

var _catalog: SkillCatalog
var _allowed: Array[StringName]


func before() -> void:
	_catalog = SkillCatalog.load_all()
	_allowed = SkillCatalog.misconception_names()


func _problems(skill_id: StringName, overrides: Dictionary = {}, count: int = N) -> Array[Problem]:
	return GeneratorChecks.make_all(_catalog.skill(skill_id), count, overrides)


## Every number from 1 to n that divides n, by trying them all.
func _factors(n: int) -> Array[int]:
	var found: Array[int] = []
	for d: int in range(1, n + 1):
		if n % d == 0:
			found.append(d)
	return found


func _is_prime(n: int) -> bool:
	return n >= 2 and _factors(n).size() == 2


func _by_name(problem: Problem, name: String) -> Array:
	var values: Array = []
	for entry: Dictionary in problem.distractors:
		if entry["misconception"] == name:
			values.append(entry["value"])
	return values


func test_every_skill_passes_the_shared_checks() -> void:
	for skill_id: StringName in [&"fac.list.find_all", &"fac.pairs.rectangles", &"fac.check.is_factor"]:
		var skill: Skill = _catalog.skill(skill_id)
		assert_object(skill).is_not_null()
		var errors: Array[String] = GeneratorChecks.run(skill, 10000, _allowed)
		assert_array(errors).override_failure_message("\n".join(errors)).is_empty()


# --- fac.list.find_all -----------------------------------------------------------------------


func test_the_factor_list_is_complete_and_sorted() -> void:
	var seen: Dictionary = {}
	for problem: Problem in _problems(&"fac.list.find_all"):
		var n: int = problem.prompt_params["n"]
		seen[n] = true
		assert_str(problem.prompt_line_id).is_equal("z4.fac.prompt_list")
		assert_array(problem.answer).override_failure_message("factors of %d" % n).is_equal(_factors(n))
		assert_int(problem.prompt_params["k"]).is_equal(_factors(n).size())
		assert_bool(_is_prime(n)).is_false()
		assert_int(n).is_between(4, 30)
		assert_int(_factors(n).size()).is_between(3, 7)
	assert_bool(seen.has(4)).is_true() # the smallest composite
	for square: int in [4, 9, 16, 25]:
		assert_bool(seen.has(square)).override_failure_message("%d never asked" % square).is_true()
	for left_out: int in [24, 30]: # eight factors leave no room for a wrong tile
		assert_bool(seen.has(left_out)).override_failure_message("%d has too many factors for the board" % left_out).is_false()


func test_the_tile_board_holds_the_factors_and_at_most_eight_tiles() -> void:
	for problem: Problem in _problems(&"fac.list.find_all"):
		var board: Dictionary = problem.meta["tile_board"]
		assert_bool(board["ordered"]).is_false()
		assert_int(board["slots"]).is_equal(problem.answer.size())
		assert_int(board["tiles"].size()).is_between(problem.answer.size(), 8)
		for factor: int in problem.answer:
			assert_bool(board["tiles"].has(factor)).is_true()
		assert_bool(problem.visual.is_empty()).is_true()


func test_each_wrong_board_is_the_mistake_it_names() -> void:
	var counts: Dictionary = {"missing_one_and_n": 0, "skip_middle_pair": 0, "multiple_not_factor": 0}
	for problem: Problem in _problems(&"fac.list.find_all"):
		var n: int = problem.prompt_params["n"]
		var real: Array[int] = _factors(n)
		var middle: Array[int] = real.filter(func(f: int) -> bool: return f != 1 and f != n)
		assert_array(problem.distractors).is_not_empty()
		for board: Array in _by_name(problem, "missing_one_and_n"):
			counts["missing_one_and_n"] += 1
			assert_bool(board.has(1) or board.has(n)).is_false()
			for factor: int in middle:
				assert_bool(board.has(factor)).is_true()
			assert_int(board.size()).is_equal(real.size())
			for value: int in board:
				assert_bool(middle.has(value) or not real.has(value)).is_true()
		for board: Array in _by_name(problem, "skip_middle_pair"):
			counts["skip_middle_pair"] += 1
			assert_bool(board.has(1) and board.has(n)).is_true()
			var missing: Array[int] = real.filter(func(f: int) -> bool: return not board.has(f))
			assert_array(missing).is_not_empty()
			for factor: int in missing:
				assert_bool(middle.has(factor)).is_true()
				assert_bool(missing.has(int(n / float(factor)))).override_failure_message("n=%d lost %d but not its partner" % [n, factor]).is_true()
			var strangers: Array = board.filter(func(v: int) -> bool: return not real.has(v))
			assert_int(strangers.size()).is_equal(missing.size())
			assert_int(board.size()).is_equal(real.size())
		for board: Array in _by_name(problem, "multiple_not_factor"):
			counts["multiple_not_factor"] += 1
			assert_bool(board.has(n * 2)).is_true()
			var missing: Array[int] = real.filter(func(f: int) -> bool: return not board.has(f))
			assert_int(missing.size()).is_equal(1)
			assert_bool(middle.has(missing[0])).is_true()
			assert_int(board.size()).is_equal(real.size())
		for entry: Dictionary in problem.distractors:
			assert_bool(entry["value"] == Problem.sorted_values(entry["value"])).is_true()
	for name: String in counts:
		assert_int(counts[name]).override_failure_message(name + " never produced").is_greater(100)


func test_a_number_with_six_factors_keeps_room_for_two_strangers() -> void:
	var checked: int = 0
	for problem: Problem in _problems(&"fac.list.find_all"):
		if problem.prompt_params["n"] == 12:
			checked += 1
			assert_array(problem.answer).is_equal([1, 2, 3, 4, 6, 12])
			assert_int(problem.meta["tile_board"]["tiles"].size()).is_equal(8)
			assert_array(_by_name(problem, "multiple_not_factor")).is_empty() # no room for the multiple tile
			assert_array(_by_name(problem, "missing_one_and_n")).is_not_empty()
	assert_int(checked).is_greater(20)


func test_the_smallest_composite_has_a_full_set_of_wrong_boards() -> void:
	for problem: Problem in _problems(&"fac.list.find_all"):
		if problem.prompt_params["n"] == 4:
			assert_array(problem.answer).is_equal([1, 2, 4])
			assert_int(problem.distractors.size()).is_equal(3)
			return
	fail("n = 4 never came up")


func test_the_hint_picture_is_a_rectangle_of_the_first_middle_pair_or_hops() -> void:
	for problem: Problem in _problems(&"fac.list.find_all"):
		var n: int = problem.prompt_params["n"]
		var f: int = problem.answer[1]
		var model: Dictionary = problem.hint_steps[1]["visual"]
		if int(n / float(f)) <= 10:
			assert_dict(model).is_equal({"type": "array", "rows": f, "cols": int(n / float(f)), "outline_rows": true})
		else:
			assert_str(model["type"]).is_equal("number_line")
			assert_int(model["max"]).is_equal(n)
		var example: Dictionary = problem.hint_steps[2]["example"]
		var en: int = example["prompt_params"]["n"]
		assert_str(example["answer_line_id"]).is_equal("z4.hint.example_factors")
		assert_int(example["answer_params"]["a"] * example["answer_params"]["b"]).is_equal(en)


# --- fac.pairs.rectangles --------------------------------------------------------------------


func test_a_rectangle_holds_exactly_n_gems() -> void:
	var seen: Dictionary = {}
	for problem: Problem in _problems(&"fac.pairs.rectangles"):
		var rows: int = problem.prompt_params["rows"]
		var n: int = problem.prompt_params["n"]
		var cols: int = problem.answer["cols"]
		seen["%dx%d" % [rows, cols]] = true
		assert_str(problem.prompt_line_id).is_equal("z4.fac.prompt_rectangle")
		assert_int(problem.answer["rows"]).is_equal(rows)
		var counted: int = 0
		for _row: int in rows:
			counted += cols
		assert_int(counted).is_equal(n)
		assert_int(rows).is_between(2, 6)
		assert_int(cols).is_between(1, 6)
		assert_dict(problem.meta["array_builder"]).is_equal({"max_rows": 6, "max_cols": 6})
		assert_bool(problem.visual.is_empty()).is_true()
		assert_array(problem.distractors).is_not_empty()
	assert_int(seen.size()).is_equal(30) # rows 2 to 6 by columns 1 to 6


func test_a_split_problem_asks_for_a_factor_pair_that_has_the_shown_number() -> void:
	var seen: Dictionary = {}
	for problem: Problem in _problems(&"fac.split.pair"):
		var n: int = problem.prompt_params["n"]
		var shown: int = problem.prompt_params["a"]
		assert_str(problem.prompt_line_id).is_equal("z4.fac.prompt_split")
		var pair: Array = problem.answer
		assert_int(pair.size()).is_equal(2)
		assert_int(pair[0] * pair[1]).is_equal(n)
		assert_int(pair[0]).is_between(2, pair[1])
		assert_bool(pair.has(shown)).is_true()
		assert_int(n).is_between(8, 36)
		var spec: Dictionary = problem.meta["boulder_split"]
		assert_int(spec["value"]).is_equal(n)
		for factor: int in spec["factors"]:
			assert_int(n % factor).is_equal(0)
			assert_int(factor).is_between(2, n / 2)
		# every other factor pair is a wrong answer, named wrong_split, and none repeats the answer
		var others: Array = _by_name(problem, "wrong_split")
		assert_int(others.size()).is_equal(problem.distractors.size())
		assert_int(others.size()).is_greater_equal(1)
		for other: Array in others:
			assert_int(other[0] * other[1]).is_equal(n)
			assert_bool(other == pair).is_false()
		assert_bool(problem.visual.is_empty()).is_true()
		seen[n] = true
	assert_int(seen.size()).is_equal(9) # 12, 16, 18, 20, 24, 28, 30, 32 and 36 are the numbers in 8..36 with two factor pairs


func test_a_split_problem_has_a_boulder_input_and_a_real_chance_of_a_wrong_pick() -> void:
	var problem: Problem = GeneratorRegistry.make_problem(_catalog.skill(&"fac.split.pair"), 5)
	assert_int(AnswerPanel.choose_input(problem)).is_equal(AnswerPanel.InputKind.SPLIT)
	assert_float(AnswerPanel.chance_for(problem)).is_less_equal(0.5)


func test_wrong_rectangles_are_swapped_or_one_column_off() -> void:
	var swapped: int = 0
	var off: int = 0
	for problem: Problem in _problems(&"fac.pairs.rectangles"):
		var rows: int = problem.answer["rows"]
		var cols: int = problem.answer["cols"]
		for entry: Dictionary in problem.distractors:
			match String(entry["misconception"]):
				"rows_cols_swapped":
					swapped += 1
					assert_dict(entry["value"]).is_equal({"rows": cols, "cols": rows})
					assert_int(rows).is_not_equal(cols)
				"off_by_one":
					off += 1
					assert_int(entry["value"]["rows"]).is_equal(rows)
					assert_int(absi(entry["value"]["cols"] - cols)).is_equal(1)
				_:
					fail("unexpected misconception " + String(entry["misconception"]))
		if rows == cols:
			assert_array(_by_name(problem, "rows_cols_swapped")).is_empty() # a square turned is the same square
	assert_int(swapped).is_greater(500)
	assert_int(off).is_greater(500)


# --- fac.check.is_factor ---------------------------------------------------------------------


func test_the_answer_is_whether_d_goes_into_n_with_none_left_over() -> void:
	for problem: Problem in _problems(&"fac.check.is_factor"):
		var d: int = problem.prompt_params["d"]
		var n: int = problem.prompt_params["n"]
		assert_str(problem.prompt_line_id).is_equal("z4.fac.prompt_check")
		assert_bool(problem.answer).override_failure_message("%d in %d" % [d, n]).is_equal(_factors(n).has(d))
		assert_array(problem.distractors).has_size(1)
		assert_bool(problem.distractors[0]["value"]).is_equal(not problem.answer)
		assert_dict(problem.meta["label_lines"]).is_equal({"true": "ui.common.yes", "false": "ui.common.no"})


func test_each_wrong_answer_stands_for_the_mistake_it_names() -> void:
	var counts: Dictionary = {"multiple_not_factor": 0, "missing_one_and_n": 0, "no_check_made": 0}
	var yes: int = 0
	var total: int = 0
	for problem: Problem in _problems(&"fac.check.is_factor"):
		var d: int = problem.prompt_params["d"]
		var n: int = problem.prompt_params["n"]
		var name: String = String(problem.distractors[0]["misconception"])
		counts[name] += 1
		total += 1
		if problem.answer:
			yes += 1
		match name:
			"multiple_not_factor":
				assert_bool(problem.answer).is_false()
				assert_bool(d > n and d % n == 0).override_failure_message("%d is not a multiple of %d" % [d, n]).is_true()
			"missing_one_and_n":
				assert_bool(problem.answer).is_true()
				assert_bool(d == 1 or d == n).is_true()
			"no_check_made":
				assert_bool(d > 1 and d < n).override_failure_message("%d in %d" % [d, n]).is_true()
	for name: String in counts:
		assert_int(counts[name]).override_failure_message(name).is_greater(100)
	assert_float(float(yes) / float(total)).is_between(0.35, 0.55)


func test_one_and_the_number_itself_are_asked_about() -> void:
	var one: bool = false
	var itself: bool = false
	for problem: Problem in _problems(&"fac.check.is_factor", {"representation": &"abstract"}):
		one = one or problem.prompt_params["d"] == 1
		itself = itself or problem.prompt_params["d"] == problem.prompt_params["n"]
	assert_bool(one).is_true()
	assert_bool(itself).is_true()


func test_the_hop_picture_lands_on_n_only_for_a_factor() -> void:
	for problem: Problem in _problems(&"fac.check.is_factor", {"representation": &"pictorial"}):
		var d: int = problem.prompt_params["d"]
		var n: int = problem.prompt_params["n"]
		assert_int(d).is_greater(1) # the plain ruler is only for the abstract version's hint
		var line: Dictionary = problem.visual
		assert_array(line["markers"]).is_equal([n])
		var lands: bool = false
		for jump: Dictionary in line.get("jumps", []):
			assert_int(jump["to"] - jump["from"]).is_equal(d)
			lands = lands or jump["to"] == n
		assert_bool(lands).override_failure_message("hops of %d and n = %d" % [d, n]).is_equal(problem.answer)


func test_the_worked_example_line_matches_its_answer() -> void:
	for problem: Problem in _problems(&"fac.check.is_factor", {}, 500):
		var example: Dictionary = problem.hint_steps[2]["example"]
		var expected: String = "z4.hint.example_factor_yes" if example["answer"] else "z4.hint.example_factor_no"
		assert_str(example["answer_line_id"]).is_equal(expected)


func test_easier_problems_use_smaller_numbers() -> void:
	var biggest: int = 0
	for problem: Problem in _problems(&"fac.check.is_factor", {"difficulty": -2}, 1000):
		biggest = maxi(biggest, problem.prompt_params["n"])
	assert_int(biggest).is_less(30)
	for problem: Problem in _problems(&"fac.list.find_all", {"difficulty": -2}, 1000):
		assert_int(problem.prompt_params["n"]).is_less_equal(15)


func test_the_easiest_problems_still_pass_the_shared_checks() -> void:
	for skill_id: StringName in [&"fac.list.find_all", &"fac.pairs.rectangles", &"fac.check.is_factor"]:
		var errors: Array[String] = GeneratorChecks.run(_catalog.skill(skill_id), 500, _allowed, {"difficulty": -8})
		assert_array(errors).override_failure_message("\n".join(errors)).is_empty()


func test_the_same_seed_gives_the_same_problem_and_the_global_rng_is_untouched() -> void:
	for skill_id: StringName in [&"fac.list.find_all", &"fac.pairs.rectangles", &"fac.check.is_factor"]:
		var skill: Skill = _catalog.skill(skill_id)
		for seed: int in range(1, 100):
			assert_dict(GeneratorRegistry.make_problem(skill, seed).to_json()).is_equal(GeneratorRegistry.make_problem(skill, seed).to_json())
	seed(777)
	var expected: int = randi()
	seed(777)
	_problems(&"fac.list.find_all", {}, 200)
	_problems(&"fac.check.is_factor", {}, 200)
	assert_int(randi()).is_equal(expected)
