# Mirrors scripts/adaptive/bkt.gd. Expected values are worked out by hand from the formulas in the
# Phase 1 plan, with the "default" parameters: prior 0.3, learn 0.2, guess 0.2, slip 0.1.
class_name BKTTest
extends GdUnitTestSuite

const P: Dictionary = {"prior": 0.3, "learn": 0.2, "guess": 0.2, "slip": 0.1, "hint_weight": 0.5}


func test_a_correct_answer_matches_the_hand_computed_posterior() -> void:
	# posterior = 0.3*0.9 / (0.3*0.9 + 0.7*0.2) = 0.27 / 0.41 = 0.658537; + 0.341463*0.2 = 0.726829
	assert_float(BKT.update(0.3, true, P)).is_equal_approx(0.726829, 0.000001)


func test_a_wrong_answer_matches_the_hand_computed_posterior() -> void:
	# posterior = 0.3*0.1 / (0.3*0.1 + 0.7*0.8) = 0.03 / 0.59 = 0.050847; + 0.949153*0.2 = 0.240678
	assert_float(BKT.update(0.3, false, P)).is_equal_approx(0.240678, 0.000001)


func test_three_correct_answers_in_a_row_pass_the_mastery_probability() -> void:
	# 0.3 -> 0.726829 -> 0.938334 -> 0.988485. This is why mastery also needs a second day and the
	# guessing guard: a lucky streak of three taps would otherwise be enough.
	var p: float = 0.3
	var expected: Array[float] = [0.726829, 0.938334, 0.988485]
	for value: float in expected:
		p = BKT.update(p, true, P)
		assert_float(p).is_equal_approx(value, 0.000001)
	assert_float(p).is_greater_equal(SkillRecord.MASTERY_P)


func test_a_hint_assisted_correct_answer_moves_half_way_to_the_full_update() -> void:
	# 0.3 + 0.5 * (0.726829 - 0.3) = 0.513415
	assert_float(BKT.update_with_hints(0.3, true, 2, P)).is_equal_approx(0.513415, 0.000001)
	assert_float(BKT.update_with_hints(0.3, true, 0, P)).is_equal_approx(BKT.update(0.3, true, P), 0.000001)
	assert_float(BKT.update_with_hints(0.3, false, 3, P)).is_equal_approx(BKT.update(0.3, false, P), 0.000001)


func test_the_hint_weight_comes_from_the_parameters() -> void:
	var heavier: Dictionary = P.duplicate()
	heavier["hint_weight"] = 1.0
	assert_float(BKT.update_with_hints(0.3, true, 1, heavier)).is_equal_approx(BKT.update(0.3, true, P), 0.000001)


func test_learning_always_moves_p_up_after_the_evidence() -> void:
	for p: float in [0.01, 0.2, 0.5, 0.9, 0.99]:
		assert_float(BKT.update(p, true, P)).is_greater(p)
		assert_float(BKT.update(p, false, P)).is_between(0.0, 1.0)


func test_the_guess_is_raised_to_the_chance_of_a_lucky_tap() -> void:
	assert_float(BKT.with_chance(P, 0.5)["guess"]).is_equal(0.5)
	assert_float(BKT.with_chance(P, 0.05)["guess"]).is_equal(0.2) # never lowered
	assert_float(BKT.with_chance(P, 1.0)["guess"]).is_equal(BKT.MAX_GUESS) # never certainty
	assert_float(P["guess"]).is_equal(0.2) # the input is not changed
	# A correct tap on a two-pile question is weaker evidence than the skill's guess suggests.
	assert_float(BKT.update(0.3, true, BKT.with_chance(P, 0.5))).is_less(BKT.update(0.3, true, P))


func test_the_defaults_load_from_the_curriculum_file() -> void:
	var defaults: Dictionary = BKT.load_defaults()
	var fact: Dictionary = BKT.params_for(defaults, &"fact")
	assert_float(fact["prior"]).is_equal(0.25)
	assert_int(fact["fluency_ms"]).is_equal(8000)
	assert_float(fact["hint_weight"]).is_equal(0.5)
	var fallback: Dictionary = BKT.params_for(defaults, &"no_such_type")
	assert_float(fallback["prior"]).is_equal(0.3)
	assert_bool(fallback.has("fluency_ms")).is_false()
	for type: StringName in [&"default", &"fact", &"procedure", &"concept"]:
		var params: Dictionary = BKT.params_for(defaults, type)
		for key: String in BKT.PARAM_KEYS:
			assert_float(params[key]).is_between(0.0, 1.0)
