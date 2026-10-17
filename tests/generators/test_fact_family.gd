# Mirrors scripts/generators/fact_family.gd. Every fact is checked by parsing its text and doing
# the arithmetic here, so a fact that only looks right (or a tile in the wrong format) fails.
class_name FactFamilyGeneratorTest
extends GdUnitTestSuite

const N: int = 3000
const BUILD: StringName = &"eq.fact_family.build"
const INVERSE: StringName = &"eq.inverse.check"

var _catalog: SkillCatalog
var _fact_pattern: RegEx = RegEx.new()


func before() -> void:
	_catalog = SkillCatalog.load_all()
	_fact_pattern.compile("^(\\d+) ([+-]) (\\d+) = (\\d+)$")


func _problems(skill_id: StringName, overrides: Dictionary = {}, count: int = N) -> Array[Problem]:
	return GeneratorChecks.make_all(_catalog.skill(skill_id), count, overrides)


## {x, op, y, z} from "x op y = z" written exactly so, or {} for anything else.
func _parse(fact: Variant) -> Dictionary:
	if typeof(fact) != TYPE_STRING:
		return {}
	var found: RegExMatch = _fact_pattern.search(fact)
	if found == null:
		return {}
	return {"x": int(found.get_string(1)), "op": found.get_string(2), "y": int(found.get_string(3)), "z": int(found.get_string(4))}


func _is_true(fact: Dictionary) -> bool:
	var value: int = fact["x"] + fact["y"] if fact["op"] == "+" else fact["x"] - fact["y"]
	return value == fact["z"]


## The three numbers a fact uses, smallest first.
func _numbers(fact: Dictionary) -> Array[int]:
	var numbers: Array[int] = [fact["x"], fact["y"], fact["z"]]
	numbers.sort()
	return numbers


## The family's three numbers, smallest first.
func _family_numbers(problem: Problem) -> Array[int]:
	var numbers: Array[int] = [problem.prompt_params["a"], problem.prompt_params["b"], problem.prompt_params["c"]]
	numbers.sort()
	return numbers


func _text(fact: Dictionary) -> String:
	return "%d %s %d = %d" % [fact["x"], fact["op"], fact["y"], fact["z"]]


## True when `fact` checks `shown` with the inverse operation: a true fact of the same three
## numbers that uses the other operation.
func _checks(fact: Dictionary, shown: Dictionary) -> bool:
	return fact["op"] != shown["op"] and _is_true(fact) and _numbers(fact) == _numbers(shown)


# --- Build the fact family -----------------------------------------------------------------


func test_the_three_numbers_make_a_family() -> void:
	var smallest: int = 100
	var largest: int = 0
	for problem: Problem in _problems(BUILD):
		var a: int = problem.prompt_params["a"]
		var b: int = problem.prompt_params["b"]
		var c: int = problem.prompt_params["c"]
		assert_int(a).is_greater_equal(1)
		assert_int(b).is_greater_equal(1)
		assert_int(a).is_not_equal(b) # equal parts would make only two different facts
		assert_int(c).is_equal(a + b)
		assert_int(c).is_less_equal(20)
		assert_str(problem.prompt_line_id).is_equal("z2.eq.prompt_fact_family")
		assert_dict(problem.visual).is_empty() # abstract: the picture is the hint
		smallest = mini(smallest, c)
		largest = maxi(largest, c)
	assert_int(smallest).is_equal(3) # 1 + 2 = 3
	assert_int(largest).is_equal(20)


func test_the_answer_is_four_true_distinct_facts_kept_sorted() -> void:
	for problem: Problem in _problems(BUILD):
		var answer: Array = problem.answer
		assert_int(answer.size()).is_equal(4)
		assert_array(answer).is_equal(Problem.sorted_values(answer))
		var adds: int = 0
		var seen: Dictionary = {}
		for item: Variant in answer:
			var fact: Dictionary = _parse(item)
			assert_bool(fact.is_empty()).override_failure_message("not a fact: %s" % item).is_false()
			assert_bool(_is_true(fact)).override_failure_message("false fact in the answer: %s" % item).is_true()
			assert_array(_numbers(fact)).is_equal(_family_numbers(problem))
			assert_str(_text(fact)).is_equal(item) # exactly one space around each sign
			adds += 1 if fact["op"] == "+" else 0
			seen[item] = true
		assert_int(seen.size()).is_equal(4)
		assert_int(adds).is_equal(2)


func test_the_board_holds_the_family_and_two_false_tiles_in_shuffled_order() -> void:
	var wrong_tiles_last: int = 0
	var wrong_tile_first: int = 0
	for problem: Problem in _problems(BUILD):
		var board: Dictionary = problem.meta["tile_board"]
		assert_int(board["slots"]).is_equal(4)
		assert_bool(board["ordered"]).is_false()
		var tiles: Array = board["tiles"]
		assert_int(tiles.size()).is_equal(6)
		var true_tiles: Array = []
		var false_positions: Array[int] = []
		for index: int in tiles.size():
			var fact: Dictionary = _parse(tiles[index])
			assert_bool(fact.is_empty()).is_false()
			assert_int(tiles.count(tiles[index])).is_equal(1)
			assert_array(_numbers(fact)).is_equal(_family_numbers(problem)) # every tile uses the same three numbers
			if _is_true(fact):
				true_tiles.append(tiles[index])
			else:
				false_positions.append(index)
		assert_array(Problem.sorted_values(true_tiles)).is_equal(problem.answer)
		assert_int(false_positions.size()).is_equal(2)
		if false_positions[0] == 4:
			wrong_tiles_last += 1 # positions 4 and 5: the very end
		if false_positions.has(0):
			wrong_tile_first += 1
	# Shuffled: the wrong tiles end up last about 1 time in 15, and first about 1 time in 3.
	assert_int(wrong_tiles_last).is_less(N / 8)
	assert_int(wrong_tile_first).is_greater(N / 5)


func test_each_wrong_answer_swaps_one_true_fact_for_its_named_mistake() -> void:
	for problem: Problem in _problems(BUILD):
		var c: int = problem.prompt_params["c"]
		var names: Array[StringName] = []
		for entry: Dictionary in problem.distractors:
			names.append(entry["misconception"])
			var value: Array = entry["value"]
			assert_int(value.size()).is_equal(4)
			assert_array(value).is_equal(Problem.sorted_values(value))
			var wrong: Array = value.filter(func(item: Variant) -> bool: return not problem.answer.has(item))
			var missing: Array = problem.answer.filter(func(item: Variant) -> bool: return not value.has(item))
			assert_int(wrong.size()).is_equal(1)
			assert_int(missing.size()).is_equal(1)
			assert_bool(problem.meta["tile_board"]["tiles"].has(wrong[0])).is_true()
			var tile: Dictionary = _parse(wrong[0])
			assert_bool(_is_true(tile)).is_false()
			var repaired: Dictionary = tile.duplicate()
			if entry["misconception"] == &"swapped_minuend":
				# A part minus the whole: put the two numbers before "=" back in order.
				assert_str(tile["op"]).is_equal("-")
				assert_int(tile["y"]).is_equal(c)
				repaired["x"] = tile["y"]
				repaired["y"] = tile["x"]
			else:
				assert_str(entry["misconception"]).is_equal("wrong_operation")
				repaired["op"] = "-" if tile["op"] == "+" else "+"
			assert_str(_text(repaired)).is_equal(missing[0])
		assert_array(names).contains_exactly_in_any_order([&"swapped_minuend", &"wrong_operation"])


func test_both_kinds_of_wrong_operation_tile_turn_up() -> void:
	var subtract_instead: int = 0
	var add_instead: int = 0
	for problem: Problem in _problems(BUILD, {}, 1000):
		for entry: Dictionary in problem.distractors:
			if entry["misconception"] == &"wrong_operation":
				var tile: Dictionary = _parse(entry["value"].filter(func(item: Variant) -> bool: return not problem.answer.has(item))[0])
				subtract_instead += 1 if tile["op"] == "-" else 0
				add_instead += 1 if tile["op"] == "+" else 0
	assert_int(subtract_instead).is_greater(300)
	assert_int(add_instead).is_greater(300)


func test_the_hints_show_both_parts_and_a_whole_family() -> void:
	for problem: Problem in _problems(BUILD, {}, 1000):
		assert_dict(problem.hint_steps[1]["visual"]).is_equal({
			"type": "ten_frame", "count": problem.prompt_params["a"], "second": problem.prompt_params["b"], "frames": 2,
		})
		var example: Dictionary = problem.hint_steps[2]["example"]
		assert_str(example["answer_line_id"]).is_equal("z2.hint.example_family")
		var listed: Array = Array(String(example["answer_params"]["list"]).split("; "))
		assert_array(Problem.sorted_values(listed)).is_equal(example["answer"])
		assert_bool(Problem.same(example["prompt_params"], problem.prompt_params)).is_false()


# --- Check with the inverse ----------------------------------------------------------------


func test_exactly_one_button_checks_the_shown_fact() -> void:
	var starts: Dictionary = {"z2.eq.prompt_inverse_add": 0, "z2.eq.prompt_inverse_sub": 0}
	for problem: Problem in _problems(INVERSE):
		var a: int = problem.prompt_params["a"]
		var b: int = problem.prompt_params["b"]
		var c: int = problem.prompt_params["c"]
		assert_int(a).is_greater_equal(1)
		assert_int(b).is_greater_equal(1)
		assert_int(a).is_not_equal(b)
		assert_int(c).is_equal(a + b)
		assert_int(c).is_less_equal(20)
		assert_bool(starts.has(String(problem.prompt_line_id))).is_true()
		starts[String(problem.prompt_line_id)] += 1
		var adding: bool = problem.prompt_line_id == &"z2.eq.prompt_inverse_add"
		var shown: Dictionary = {"x": a, "op": "+", "y": b, "z": c} if adding else {"x": c, "op": "-", "y": b, "z": a}
		# The answer undoes the shown fact: take b away again, or add b back.
		var undo: Dictionary = {"x": c, "op": "-", "y": b, "z": a} if adding else {"x": a, "op": "+", "y": b, "z": c}
		assert_str(problem.answer).is_equal(_text(undo))
		var options: Array = [problem.answer]
		options.append_array(problem.distractor_values())
		var checking: int = 0
		for option: Variant in options:
			var fact: Dictionary = _parse(option)
			assert_bool(fact.is_empty()).override_failure_message("not a fact: %s" % option).is_false()
			assert_bool(_is_true(fact)).override_failure_message("every button shows a true fact: %s" % option).is_true()
			assert_str(_text(fact)).is_not_equal(_text(shown))
			checking += 1 if _checks(fact, shown) else 0
		assert_int(checking).is_equal(1)
		assert_int(problem.distractors.size()).is_equal(2)
		for entry: Dictionary in problem.distractors:
			assert_str(entry["misconception"]).is_equal("wrong_numbers")
	assert_int(starts["z2.eq.prompt_inverse_add"]).is_between(N / 3, N * 2 / 3)
	assert_int(starts["z2.eq.prompt_inverse_sub"]).is_between(N / 3, N * 2 / 3)


func test_the_other_inverse_fact_is_never_offered() -> void:
	for problem: Problem in _problems(INVERSE, {}, 1000):
		var a: int = problem.prompt_params["a"]
		var b: int = problem.prompt_params["b"]
		var c: int = problem.prompt_params["c"]
		var also_checks: String = "%d - %d = %d" % [c, a, b] if problem.prompt_line_id == &"z2.eq.prompt_inverse_add" else "%d + %d = %d" % [b, a, c]
		assert_array(problem.distractor_values()).not_contains([also_checks])


func test_every_button_uses_the_checking_sign_so_the_sign_gives_nothing_away() -> void:
	for problem: Problem in _problems(INVERSE):
		var adding: bool = problem.prompt_line_id == &"z2.eq.prompt_inverse_add"
		var sign_of_answer: String = _parse(problem.answer)["op"]
		assert_str(sign_of_answer).is_equal("-" if adding else "+")
		for option: Variant in problem.distractor_values():
			assert_str(_parse(option)["op"]).is_equal(sign_of_answer)


func test_the_wrong_buttons_use_other_numbers_and_are_not_the_same_fact_twice() -> void:
	for problem: Problem in _problems(INVERSE):
		var shown_numbers: Array = [problem.prompt_params["a"], problem.prompt_params["b"], problem.prompt_params["c"]]
		shown_numbers.sort()
		var seen: Array = [problem.answer]
		for option: Variant in problem.distractor_values():
			var fact: Dictionary = _parse(option)
			var numbers: Array = [fact["x"], fact["y"], fact["z"]]
			numbers.sort()
			assert_array(numbers).is_not_equal(shown_numbers)
			assert_array(seen).not_contains([option])
			seen.append(option)
			assert_int(int(fact["y"])).is_greater_equal(1)
			assert_int(int(fact["z"])).is_greater_equal(1)
			assert_int(maxi(int(fact["x"]), int(fact["z"]))).is_less_equal(20)


func test_the_inverse_hint_jumps_back_or_forward_by_b() -> void:
	for problem: Problem in _problems(INVERSE, {}, 1000):
		var a: int = problem.prompt_params["a"]
		var c: int = problem.prompt_params["c"]
		var model: Dictionary = problem.hint_steps[1]["visual"]
		assert_str(model["type"]).is_equal("number_line")
		var expected: Dictionary = {"from": c, "to": a} if problem.prompt_line_id == &"z2.eq.prompt_inverse_add" else {"from": a, "to": c}
		assert_array(model["jumps"]).is_equal([expected])
		assert_array(model["markers"]).contains([a, c])
		var example: Dictionary = problem.hint_steps[2]["example"]
		assert_str(example["answer_line_id"]).is_equal("z2.hint.example_check")
		assert_str(example["answer_params"]["fact"]).is_equal(example["answer"])


# --- Both skills ---------------------------------------------------------------------------


func test_an_easier_problem_uses_smaller_numbers() -> void:
	for skill_id: StringName in [BUILD, INVERSE]:
		var largest: int = 0
		var largest_easier: int = 0
		for problem: Problem in _problems(skill_id, {}, 1000):
			largest = maxi(largest, problem.prompt_params["c"])
		for problem: Problem in _problems(skill_id, {"difficulty": -1}, 1000):
			largest_easier = maxi(largest_easier, problem.prompt_params["c"])
			assert_int(problem.hint_steps[3]["easier_params"]["difficulty"]).is_equal(-2)
		assert_int(largest).is_equal(20)
		assert_int(largest_easier).is_equal(GeneratorKit.eased_max(3, 20, -1))
		assert_int(largest_easier).is_less(largest)


func test_the_same_seed_gives_the_same_problem() -> void:
	for skill_id: StringName in [BUILD, INVERSE]:
		var skill: Skill = _catalog.skill(skill_id)
		for seed: int in range(1, 60):
			assert_dict(GeneratorRegistry.make_problem(skill, seed).to_json()).is_equal(GeneratorRegistry.make_problem(skill, seed).to_json())


func test_an_unknown_mode_reports_an_error_instead_of_a_problem() -> void:
	var made: Array[Problem] = [null]
	await assert_error(func() -> void: made[0] = FactFamilyGenerator.generate(_catalog.skill(BUILD), {"mode": "juggling"}, RandomNumberGenerator.new())) \
		.is_push_error("FactFamilyGenerator: unknown mode 'juggling'")
	assert_str(made[0].prompt_line_id).is_empty()
	assert_array(made[0].hint_steps).is_empty()


func test_eq_fact_family_build_10000_problems_meet_every_rule() -> void:
	var errors: Array[String] = GeneratorChecks.run(_catalog.skill(BUILD), 10000, SkillCatalog.misconception_names())
	assert_array(errors).override_failure_message("\n".join(errors)).is_empty()


func test_eq_inverse_check_10000_problems_meet_every_rule() -> void:
	var errors: Array[String] = GeneratorChecks.run(_catalog.skill(INVERSE), 10000, SkillCatalog.misconception_names())
	assert_array(errors).override_failure_message("\n".join(errors)).is_empty()
