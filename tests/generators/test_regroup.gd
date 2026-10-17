# Mirrors scripts/generators/regroup.gd. The heart of regrouping: a trade never changes the total.
class_name RegroupGeneratorTest
extends GdUnitTestSuite

const N: int = 3000

var _catalog: SkillCatalog


func before() -> void:
	_catalog = SkillCatalog.load_all()


func _problems(skill_id: StringName, overrides: Dictionary = {}, count: int = N) -> Array[Problem]:
	return GeneratorChecks.make_all(_catalog.skill(skill_id), count, overrides)


func _total(pile: Dictionary) -> int:
	return pile["tens"] * 10 + pile["ones"]


func test_trading_ten_ones_for_a_ten_keeps_the_total() -> void:
	for problem: Problem in _problems(&"pv.regroup.trade_ten"):
		var start: Dictionary = problem.meta["start"]
		assert_int(start["ones"]).is_between(10, 19)
		assert_int(start["tens"]).is_between(0, 8)
		assert_int(_total(problem.answer)).is_equal(_total(start))
		assert_int(problem.answer["tens"]).is_equal(start["tens"] + 1)
		assert_int(problem.answer["ones"]).is_between(0, 9)
		assert_dict(problem.prompt_params).is_equal({"tens": start["tens"], "ones": start["ones"]})
		assert_int(_total(problem.visual["piles"][0])).is_equal(_total(start))


func test_trading_a_ten_for_ten_ones_keeps_the_total() -> void:
	for problem: Problem in _problems(&"pv.regroup.untrade"):
		var start: Dictionary = problem.meta["start"]
		assert_int(start["tens"]).is_between(1, 9)
		assert_int(start["ones"]).is_between(0, 9)
		assert_int(_total(problem.answer)).is_equal(_total(start))
		assert_int(problem.answer["tens"]).is_equal(start["tens"] - 1)
		assert_int(problem.answer["ones"]).is_between(10, 19)


func test_the_wrong_answers_are_the_named_mistakes() -> void:
	for skill_id: StringName in [&"pv.regroup.trade_ten", &"pv.regroup.untrade"]:
		for problem: Problem in _problems(skill_id, {}, 1000):
			var start: Dictionary = problem.meta["start"]
			var names: Array = []
			for entry: Dictionary in problem.distractors:
				names.append(entry["misconception"])
				if entry["misconception"] == &"forgot_regroup":
					assert_dict(entry["value"]).is_equal(start) # no trade at all
				else:
					# A wrong trade count changes the total, which is exactly the mistake.
					assert_int(_total(entry["value"])).is_not_equal(_total(start))
			assert_bool(names.has(&"forgot_regroup")).is_true()
			assert_bool(names.has(&"traded_wrong_count")).is_true()


func test_no_distractor_has_a_negative_count() -> void:
	for skill_id: StringName in [&"pv.regroup.trade_ten", &"pv.regroup.untrade"]:
		for problem: Problem in _problems(skill_id, {}, 1000):
			for entry: Dictionary in problem.distractors:
				assert_int(entry["value"]["tens"]).is_greater_equal(0)
				assert_int(entry["value"]["ones"]).is_greater_equal(0)


func test_every_starting_pile_turns_up() -> void:
	var seen: Dictionary = {}
	for problem: Problem in _problems(&"pv.regroup.trade_ten"):
		seen["%d/%d" % [problem.meta["start"]["tens"], problem.meta["start"]["ones"]]] = true
	assert_int(seen.size()).is_equal(9 * 10) # tens 0..8 by ones 10..19
