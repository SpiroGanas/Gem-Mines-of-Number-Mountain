# Mirrors scripts/generators/modular.gd, group.gd and divisibility_why.gd (Zone 10 mod.*, group.* and
# div.rule.explain_*). Written test-first. Cart rides are worked out here by walking the loop one stop at a
# time, never with % (posmod is what the generators use). The group.* answers are read back from
# GroupGenerator.cayley_table (the Latin-square test is the independent one here); the independent recomputation
# of every table, identity and undo partner is the Python checker, tools/crosscheck/checkers/group.py.
class_name ModularGeneratorTest
extends GdUnitTestSuite

const N: int = 1500
const SKILLS: Array[StringName] = [
	&"mod.remainder.find", &"mod.track.stop", &"mod.track.backward", &"mod.congruence.check", &"mod.congruence.notation",
	&"mod.add.wrap", &"mod.mul.wrap", &"group.identity.find", &"group.inverse.find", &"group.closure.verify",
	&"group.table.complete", &"group.cyclic.generate", &"div.rule.explain_3_9", &"div.rule.explain_2_5_10", &"div.rule.explain_4_8",
]

var _catalog: SkillCatalog
var _allowed: Array[StringName]


func before() -> void:
	_catalog = SkillCatalog.load_all()
	_allowed = SkillCatalog.misconception_names()


func _problems(skill_id: StringName, overrides: Dictionary = {}, count: int = N) -> Array[Problem]:
	return GeneratorChecks.make_all(_catalog.skill(skill_id), count, overrides)


func _values(problem: Problem, name: StringName) -> Array:
	var found: Array = []
	for entry: Dictionary in problem.distractors:
		if entry["misconception"] == name:
			found.append(entry["value"])
	return found


## The station after riding `steps` stops from `start`, one stop at a time (direction 1 or -1).
func _ride(n: int, start: int, steps: int, direction: int) -> int:
	var at: int = start
	for stop: int in steps:
		at += direction
		if at == n:
			at = 0
		elif at < 0:
			at = n - 1
	return at


func test_every_skill_passes_the_shared_checks() -> void:
	for skill_id: StringName in SKILLS:
		assert_array(GeneratorChecks.run(_catalog.skill(skill_id), N, _allowed)).override_failure_message(str(skill_id)).is_empty()
		assert_array(GeneratorChecks.run(_catalog.skill(skill_id), 400, _allowed, {"difficulty": -1})).override_failure_message(str(skill_id)).is_empty()
		assert_array(GeneratorChecks.run(_catalog.skill(skill_id), 200, _allowed, {"difficulty": -2})).override_failure_message(str(skill_id)).is_empty()


func test_the_same_seed_gives_the_same_problem() -> void:
	for skill_id: StringName in SKILLS:
		for seed: int in [1, 7, 99]:
			var first: Problem = GeneratorRegistry.make_problem(_catalog.skill(skill_id), seed)
			var second: Problem = GeneratorRegistry.make_problem(_catalog.skill(skill_id), seed)
			assert_str(JSON.stringify(first.to_json())).is_equal(JSON.stringify(second.to_json()))


func test_a_remainder_is_where_the_cart_stops_from_zero() -> void:
	for problem: Problem in _problems(&"mod.remainder.find"):
		var a: int = problem.prompt_params["a"]
		var n: int = problem.prompt_params["n"]
		assert_int(problem.answer).is_equal(_ride(n, 0, a, 1))
		assert_bool(a >= n and a <= 99 and n >= 2 and n <= 12).is_true()
		assert_bool(problem.answer >= 0 and problem.answer < n).is_true()


func test_track_stops_forward_and_back_wrap_onto_the_loop() -> void:
	for problem: Problem in _problems(&"mod.track.stop"):
		var p: Dictionary = problem.prompt_params
		assert_int(problem.answer).is_equal(_ride(p["n"], p["s"], p["k"], 1))
	var below_zero: int = 0
	for problem: Problem in _problems(&"mod.track.backward"):
		var p: Dictionary = problem.prompt_params
		assert_int(problem.answer).is_equal(_ride(p["n"], p["s"], p["k"], -1))
		assert_bool(problem.answer >= 0 and problem.answer < p["n"]).is_true()
		assert_bool(problem.meta.get("signed", false)).is_true()
		for wrong: Variant in _values(problem, &"negative_remainder"):
			below_zero += 1
			assert_int(wrong).is_equal(p["s"] - p["k"])
			assert_bool(wrong < 0).is_true()
	assert_int(below_zero).is_greater(N / 4) # a backward ride often goes past 0


func test_edge_cases_a_multiple_of_the_loop_ends_where_it_started() -> void:
	var skill: Skill = _catalog.skill(&"mod.track.stop")
	var found_zero_move: bool = false
	for problem: Problem in _problems(&"mod.track.stop"):
		var p: Dictionary = problem.prompt_params
		if p["k"] % p["n"] == 0:
			found_zero_move = true
			assert_int(problem.answer).is_equal(p["s"])
	assert_bool(found_zero_move).is_true()
	assert_int(skill.params["max_steps"]).is_equal(60)


func test_congruence_is_the_same_station_and_the_numbers_differ() -> void:
	var yes: int = 0
	for problem: Problem in _problems(&"mod.congruence.check"):
		var p: Dictionary = problem.prompt_params
		assert_bool(p["a"] != p["b"]).is_true()
		assert_bool(problem.answer is bool).is_true()
		assert_bool(problem.answer == (_ride(p["n"], 0, p["a"], 1) == _ride(p["n"], 0, p["b"], 1))).is_true()
		assert_int(problem.distractors.size()).is_equal(1)
		yes += 1 if problem.answer else 0
	assert_bool(yes > N / 3 and yes < N * 2 / 3).is_true()


func test_notation_cards_are_real_congruences() -> void:
	var loops: int = 0
	var stations: int = 0
	for problem: Problem in _problems(&"mod.congruence.notation"):
		var card: Dictionary = problem.visual
		assert_str(str(card["form"])).is_equal("congruence")
		assert_int(_ride(card["n"], 0, card["a"], 1)).is_equal(_ride(card["n"], 0, card["b"], 1))
		if problem.prompt_line_id == &"z10.mod.prompt_notation_loop":
			loops += 1
			assert_int(problem.answer).is_equal(card["n"])
		else:
			stations += 1
			assert_int(problem.answer).is_equal(_ride(card["n"], 0, card["a"], 1))
		assert_bool(problem.distractors.size() >= 2).is_true()
	assert_bool(loops > 0 and stations > 0).is_true()


func test_dial_sums_and_products_wrap() -> void:
	for problem: Problem in _problems(&"mod.add.wrap"):
		var p: Dictionary = problem.prompt_params
		assert_int(problem.answer).is_equal(_ride(p["n"], _ride(p["n"], 0, p["a"], 1), p["b"], 1))
		assert_int(p["m"]).is_equal(p["n"] - 1)
		if problem.representation == &"concrete":
			assert_array(problem.meta["clock_lock"]["turns"]).contains_exactly([p["a"], p["b"]])
	var wrapped: int = 0
	for problem: Problem in _problems(&"mod.mul.wrap"):
		var p: Dictionary = problem.prompt_params
		assert_int(problem.answer).is_equal(_ride(p["n"], 0, p["a"] * p["b"], 1))
		assert_bool(p["a"] * p["b"] >= p["n"]).is_true()
		wrapped += 1
		assert_array(_values(problem, &"forgot_mod_wrap")).contains_exactly([p["a"] * p["b"]])
	assert_int(wrapped).is_equal(N)


func test_the_identity_is_the_number_that_changes_nothing() -> void:
	var adds: int = 0
	var muls: int = 0
	for problem: Problem in _problems(&"group.identity.find"):
		var spec: Dictionary = problem.meta["mixing_table"]
		var n: int = spec["n"]
		var table: Array[Array] = GroupGenerator.cayley_table(n, StringName(spec["op"]))
		var found: Array[int] = []
		for e: int in n:
			var does_nothing: bool = true
			for x: int in n:
				does_nothing = does_nothing and table[e][x] == x and table[x][e] == x
			if does_nothing:
				found.append(e)
		assert_array(found).contains_exactly([problem.answer])
		adds += 1 if spec["op"] == "add" else 0
		muls += 1 if spec["op"] == "mul" else 0
	assert_bool(adds > 0 and muls > 0).is_true()


func test_cayley_tables_are_latin_squares_for_adding_and_zero_row_for_multiplying() -> void:
	for n: int in range(2, 13):
		var add: Array[Array] = GroupGenerator.cayley_table(n, &"add")
		assert_int(add.size()).is_equal(n)
		for i: int in n:
			var row_seen: Dictionary = {}
			var col_seen: Dictionary = {}
			for j: int in n:
				row_seen[add[i][j]] = true
				col_seen[add[j][i]] = true
				assert_int(add[i][j]).is_equal((i + j) % n)
			assert_int(row_seen.size()).is_equal(n) # every number once in every row...
			assert_int(col_seen.size()).is_equal(n) # ...and every column
		var mul: Array[Array] = GroupGenerator.cayley_table(n, &"mul")
		for j: int in n:
			assert_int(mul[0][j]).is_equal(0)
			assert_int(mul[1][j]).is_equal(j)


func test_undo_partners_land_on_zero() -> void:
	for problem: Problem in _problems(&"group.inverse.find"):
		var a: int = problem.prompt_params["a"]
		var n: int = problem.prompt_params["n"]
		assert_int(_ride(n, a, problem.answer, 1)).is_equal(0)
		assert_bool(problem.answer >= 1 and problem.answer < n).is_true()


func test_closure_is_true_only_for_wrapped_tables() -> void:
	var yes: int = 0
	for problem: Problem in _problems(&"group.closure.verify"):
		var picture: Dictionary = problem.visual
		var n: int = picture["n"]
		var table: Array[Array] = GroupGenerator.cayley_table(n, StringName(picture["op"]))
		var biggest: int = 0
		for a: int in n:
			for b: int in n:
				biggest = maxi(biggest, table[a][b] if picture["wrap"] else GroupGenerator.mix(a, b, StringName(picture["op"])))
		assert_bool(problem.answer).is_equal(biggest < n)
		assert_int(problem.meta["biggest"]).is_equal(biggest)
		yes += 1 if problem.answer else 0
	assert_bool(yes > N / 3 and yes < N * 2 / 3).is_true()


func test_a_table_box_is_the_wrapped_mix_of_its_row_and_column() -> void:
	for problem: Problem in _problems(&"group.table.complete"):
		var spec: Dictionary = problem.meta["table"]
		var table: Array[Array] = GroupGenerator.cayley_table(spec["n"], StringName(spec["op"]))
		assert_int(problem.answer).is_equal(table[spec["r"]][spec["c"]])
		assert_bool(problem.distractors.size() >= 2).is_true()
		assert_array(problem.visual["ring"]).contains_exactly([spec["r"], spec["c"]])


func test_a_cyclic_walk_returns_to_zero_after_n_over_gcd_jumps() -> void:
	for problem: Problem in _problems(&"group.cyclic.generate"):
		var n: int = problem.prompt_params["n"]
		var g: int = problem.prompt_params["g"]
		var jumps: int = 1
		var at: int = _ride(n, 0, g, 1)
		while at != 0:
			at = _ride(n, at, g, 1)
			jumps += 1
		assert_int(problem.answer).is_equal(jumps)


func test_divisibility_explanations_give_the_remainder_of_the_part_that_decides() -> void:
	for problem: Problem in _problems(&"div.rule.explain_3_9"):
		var a: int = problem.prompt_params["a"]
		var b: int = problem.prompt_params["b"]
		var sum: int = 0
		for ch: String in str(a):
			sum += int(ch)
		assert_int(problem.prompt_params["s"]).is_equal(sum)
		assert_int(problem.answer).is_equal(sum % b) # a number and its digit sum leave the same remainder for 3 and 9
		assert_int(problem.answer).is_equal(a % b)
	for problem: Problem in _problems(&"div.rule.explain_2_5_10"):
		var a: int = problem.prompt_params["a"]
		var b: int = problem.prompt_params["b"]
		assert_int(problem.answer).is_equal((a % 10) % b) # only the last digit counts
	for problem: Problem in _problems(&"div.rule.explain_4_8"):
		var a: int = problem.prompt_params["a"]
		var b: int = problem.prompt_params["b"]
		var keep: int = 100 if b == 4 else 1000
		assert_int(problem.answer).is_equal((a % keep) % b) # only the last two (or three) digits count
		assert_int(problem.prompt_params["k"]).is_equal(2 if b == 4 else 3)


func test_prompts_stay_in_the_skills_ranges() -> void:
	for problem: Problem in _problems(&"mod.remainder.find", {"difficulty": -2}, 400):
		assert_bool(problem.prompt_params["n"] <= 12 and problem.prompt_params["a"] <= 99).is_true()
