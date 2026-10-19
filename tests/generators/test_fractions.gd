# Mirrors scripts/generators/fractions.gd (Zone 7 fraction.*): every answer is re-derived here by
# counting and cross-multiplying (never with Rational or a float), and every wrong answer must name
# the mistake it stands for. Fixed seeds, so a failure is reproducible.
class_name FractionGeneratorTest
extends GdUnitTestSuite

const N: int = 2000
const SKILLS: Array[StringName] = [
	&"fraction.unit.identify", &"fraction.part.of_whole", &"fraction.number_line.place",
	&"fraction.equivalent.build", &"fraction.compare.like_den", &"fraction.compare.unlike_den",
	&"fraction.add.like_den", &"fraction.add.unlike_den", &"fraction.mixed.convert",
]

var _catalog: SkillCatalog
var _allowed: Array[StringName]


func before() -> void:
	_catalog = SkillCatalog.load_all()
	_allowed = SkillCatalog.misconception_names()


func _problems(skill_id: StringName, count: int = N, overrides: Dictionary = {}) -> Array[Problem]:
	return GeneratorChecks.make_all(_catalog.skill(skill_id), count, overrides)


## a/b equals c/d, by cross-multiplying.
func _equal(a: int, b: int, c: int, d: int) -> bool:
	return a * d == c * b


## Lowest terms by trying every divisor from the top down (no gcd helper).
@warning_ignore("integer_division")
func _lowest(num: int, den: int) -> Dictionary:
	for divisor: int in range(mini(absi(num), den), 1, -1):
		if num % divisor == 0 and den % divisor == 0:
			return {"num": num / divisor, "den": den / divisor}
	return {"num": num, "den": den}


func _distractor(problem: Problem, name: StringName) -> Variant:
	for entry: Dictionary in problem.distractors:
		if entry["misconception"] == name:
			return entry["value"]
	return null


func test_every_skill_passes_the_shared_checks() -> void:
	for skill_id: StringName in SKILLS:
		assert_array(GeneratorChecks.run(_catalog.skill(skill_id), N, _allowed)).override_failure_message(str(skill_id)).is_empty()


func test_the_easier_problems_pass_the_shared_checks_too() -> void:
	for skill_id: StringName in SKILLS:
		for difficulty: int in [-1, -2]:
			assert_array(GeneratorChecks.run(_catalog.skill(skill_id), 400, _allowed, {"difficulty": difficulty})).is_empty()


func test_the_same_seed_gives_the_same_problem() -> void:
	for skill_id: StringName in SKILLS:
		var skill: Skill = _catalog.skill(skill_id)
		for seed_value: int in [1, 77, 4096]:
			var first: String = JSON.stringify(GeneratorRegistry.make_problem(skill, seed_value).to_json())
			var second: String = JSON.stringify(GeneratorRegistry.make_problem(skill, seed_value).to_json())
			assert_str(first).is_equal(second)


func test_answers_are_in_lowest_terms_with_a_positive_denominator() -> void:
	for skill_id: StringName in SKILLS:
		for problem: Problem in _problems(skill_id, 500):
			var answer: Variant = problem.answer
			if answer is Dictionary and answer.size() == 2 and answer.has("num"):
				assert_bool(answer["den"] > 0).is_true()
				assert_dict(answer).override_failure_message("%s seed %d" % [skill_id, problem.seed]).is_equal(_lowest(answer["num"], answer["den"]))


func test_a_unit_fraction_is_one_over_the_shard_count() -> void:
	for problem: Problem in _problems(&"fraction.unit.identify"):
		var den: int = problem.prompt_params["den"]
		assert_bool(den >= 2 and den <= 12).is_true()
		assert_dict(problem.answer).is_equal({"num": 1, "den": den})
		assert_dict(_distractor(problem, &"inverted")).is_equal({"num": den, "den": 1})
		assert_dict(_distractor(problem, &"counted_shaded_as_denominator")).is_equal({"num": 1, "den": den - 1})
		assert_str(problem.visual["type"]).is_equal("crystals")
		assert_int(problem.visual["crystals"][0]["lit"]).is_equal(1)


func test_part_of_whole_lights_or_names_num_of_den() -> void:
	for problem: Problem in _problems(&"fraction.part.of_whole"):
		var shown: Dictionary = problem.meta["shown"]
		var num: int = shown["num"]
		var den: int = shown["den"]
		assert_bool(num >= 1 and num < den).is_true()
		assert_bool(_equal(problem.answer["num"], problem.answer["den"], num, den)).is_true()
		var dark: Variant = _distractor(problem, &"unshaded_count")
		if dark != null:
			assert_bool(_equal(dark["num"], dark["den"], den - num, den)).is_true()
		else:
			assert_int(2 * num).is_equal(den) # the dark shards are as many as the lit ones
		match problem.representation:
			&"concrete":
				assert_int(problem.meta["crystal"]["den"]).is_equal(den)
				assert_bool(den <= FractionGenerator.MAX_TAP_SHARDS).is_true()
				assert_dict(problem.visual).is_empty()
			&"pictorial":
				assert_int(problem.visual["crystals"][0]["lit"]).is_equal(num)
			&"abstract":
				assert_dict(problem.visual).is_empty()


func test_the_number_line_counts_gaps_not_ticks() -> void:
	for problem: Problem in _problems(&"fraction.number_line.place"):
		var line: Dictionary = problem.visual
		var den: int = line["den"]
		assert_int(line["ticks"]).is_equal(den + 1)
		assert_bool(den <= 8).is_true()
		var marker: Dictionary = line["marker"]
		assert_bool(_equal(problem.answer["num"], problem.answer["den"], marker["num"], den)).is_true()
		var ticks: Variant = _distractor(problem, &"counted_ticks_not_gaps")
		assert_bool(_equal(ticks["num"], ticks["den"], marker["num"], den + 1)).is_true()


func test_equivalent_fractions_multiply_top_and_bottom() -> void:
	var directions: Dictionary = {}
	for problem: Problem in _problems(&"fraction.equivalent.build"):
		var e: Dictionary = problem.meta["equiv"]
		var a: int = e["a"]
		var b: int = e["b"]
		var k: int = e["k"]
		assert_bool(k >= 2 and b * k <= 24).is_true()
		directions[problem.prompt_line_id] = true
		match problem.prompt_line_id:
			&"z7.equiv.prompt_match":
				assert_int(problem.meta["crystal"]["den"]).is_equal(b * k)
				assert_bool(b * k <= FractionGenerator.MAX_TAP_SHARDS).is_true()
				assert_bool(problem.is_correct({"num": a * k, "den": b * k})).is_true() # lighting a*k of b*k shards
				assert_bool(problem.is_correct({"num": a, "den": b * k})).is_false()
			&"z7.equiv.prompt_num":
				assert_int(problem.answer).is_equal(a * k)
				assert_int(_distractor(problem, &"added_to_both")).is_equal(a + b * k - b)
				assert_int(_distractor(problem, &"copied_numerator")).is_equal(a)
			&"z7.equiv.prompt_den":
				assert_int(problem.answer).is_equal(b * k)
				assert_int(_distractor(problem, &"scaled_numerator_only")).is_equal(b)
	assert_int(directions.size()).is_equal(3)


func test_comparisons_are_never_equal_and_point_the_right_way() -> void:
	for skill_id: StringName in [&"fraction.compare.like_den", &"fraction.compare.unlike_den"]:
		var like: bool = skill_id == &"fraction.compare.like_den"
		var symbols: Dictionary = {}
		for problem: Problem in _problems(skill_id):
			var p: Dictionary = problem.prompt_params
			var left: int = p["a"] * p["d"]
			var right: int = p["c"] * p["b"]
			assert_bool(left != right).override_failure_message("%s seed %d equal fractions" % [skill_id, problem.seed]).is_true()
			assert_str(String(problem.answer)).is_equal("<" if left < right else ">")
			assert_bool((p["b"] == p["d"]) == like).is_true()
			symbols[problem.answer] = true
			if like:
				assert_str(String(_distractor(problem, &"compared_denominators"))).is_equal("=")
			else:
				var by_bottom: Variant = _distractor(problem, &"bigger_denominator_bigger")
				if by_bottom != null:
					assert_str(String(by_bottom)).is_equal("<" if p["b"] < p["d"] else ">")
				assert_bool(problem.distractors.size() >= 1).is_true()
		assert_int(symbols.size()).is_equal(2)


func test_sums_are_right_and_stay_below_one_whole() -> void:
	for skill_id: StringName in [&"fraction.add.like_den", &"fraction.add.unlike_den"]:
		for problem: Problem in _problems(skill_id):
			var p: Dictionary = problem.prompt_params
			var top: int = p["a"] * p["d"] + p["c"] * p["b"]
			var bottom: int = p["b"] * p["d"]
			assert_bool(_equal(problem.answer["num"], problem.answer["den"], top, bottom)).is_true()
			assert_bool(top < bottom).override_failure_message("%s seed %d is not below one" % [skill_id, problem.seed]).is_true()
			var wrong: Variant = _distractor(problem, &"added_denominators")
			if wrong != null:
				assert_bool(_equal(wrong["num"], wrong["den"], p["a"] + p["c"], p["b"] + p["d"])).is_true()
			if skill_id == &"fraction.add.unlike_den":
				assert_bool(p["b"] != p["d"]).is_true()
				var common: int = p["b"]
				while common % p["d"] != 0:
					common += p["b"]
				assert_bool(common <= 24).is_true() # drawable: the least common denominator is at most max_den * 2


func test_like_denominator_sums_never_offer_an_equal_wrong_answer() -> void:
	# 1/4 + 1/4 = 2/4: "2/4" would be right, so forgot_simplify is never a distractor here.
	for problem: Problem in _problems(&"fraction.add.like_den"):
		for entry: Dictionary in problem.distractors:
			var value: Dictionary = entry["value"]
			assert_bool(_equal(value["num"], value["den"], problem.answer["num"], problem.answer["den"])).is_false()


func test_mixed_numbers_convert_both_ways() -> void:
	var directions: Dictionary = {}
	for problem: Problem in _problems(&"fraction.mixed.convert"):
		var m: Dictionary = problem.meta["mixed"]
		var top: int = m["whole"] * m["den"] + m["num"]
		assert_bool(m["num"] >= 1 and m["num"] < m["den"] and m["whole"] >= 1 and m["whole"] <= 5 and m["den"] <= 8).is_true()
		directions[problem.prompt_line_id] = true
		if problem.prompt_line_id == &"z7.mixed.prompt_to_improper":
			assert_bool(_equal(problem.answer["num"], problem.answer["den"], top, m["den"])).is_true()
			assert_dict(_distractor(problem, &"dropped_whole")).is_equal({"num": m["num"], "den": m["den"]})
		else:
			assert_int(problem.prompt_params["top"]).is_equal(top)
			assert_dict(problem.answer).is_equal({"whole": m["whole"], "num": m["num"], "den": m["den"]})
			assert_int(AnswerPanel.choose_input(problem)).is_equal(AnswerPanel.InputKind.CHOICES)
	assert_int(directions.size()).is_equal(2)


func test_easier_problems_use_smaller_denominators() -> void:
	var largest: int = 0
	for problem: Problem in _problems(&"fraction.unit.identify", 600, {"difficulty": -1}):
		largest = maxi(largest, problem.prompt_params["den"])
	assert_bool(largest < 12).is_true()
