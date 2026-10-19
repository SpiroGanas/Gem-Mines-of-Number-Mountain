# Rational: exact fractions and decimals for Phase 4. Every expected value here is worked out by hand,
# and equality of fractions is checked by cross-multiplying, never through a float.
class_name RationalTest
extends GdUnitTestSuite


func test_normalize_gives_lowest_terms_with_a_positive_denominator() -> void:
	assert_dict(Rational.normalize(6, 8)).is_equal({"num": 3, "den": 4})
	assert_dict(Rational.normalize(3, -4)).is_equal({"num": -3, "den": 4})
	assert_dict(Rational.normalize(-6, -8)).is_equal({"num": 3, "den": 4})
	assert_dict(Rational.normalize(0, 7)).is_equal({"num": 0, "den": 1})
	assert_dict(Rational.normalize(12, 4)).is_equal({"num": 3, "den": 1})
	assert_dict(Rational.normalize(7, 3)).is_equal({"num": 7, "den": 3})


func test_add_sub_mul_are_exact() -> void:
	assert_dict(Rational.add({"num": 1, "den": 4}, {"num": 2, "den": 4})).is_equal({"num": 3, "den": 4})
	assert_dict(Rational.add({"num": 1, "den": 2}, {"num": 1, "den": 3})).is_equal({"num": 5, "den": 6})
	assert_dict(Rational.add({"num": 1, "den": 4}, {"num": 1, "den": 4})).is_equal({"num": 1, "den": 2})
	assert_dict(Rational.sub({"num": 1, "den": 2}, {"num": 1, "den": 3})).is_equal({"num": 1, "den": 6})
	assert_dict(Rational.sub({"num": 1, "den": 3}, {"num": 1, "den": 2})).is_equal({"num": -1, "den": 6})
	assert_dict(Rational.mul({"num": 2, "den": 3}, {"num": 3, "den": 4})).is_equal({"num": 1, "den": 2})


func test_compare_cross_multiplies() -> void:
	assert_int(Rational.compare({"num": 1, "den": 2}, {"num": 2, "den": 4})).is_equal(0)
	assert_int(Rational.compare({"num": 3, "den": 8}, {"num": 1, "den": 2})).is_equal(-1)
	assert_int(Rational.compare({"num": 2, "den": 3}, {"num": 3, "den": 5})).is_equal(1)
	assert_int(Rational.compare({"num": -1, "den": 2}, {"num": 1, "den": -3})).is_equal(-1)


func test_mixed_numbers_round_trip() -> void:
	assert_dict(Rational.from_mixed({"whole": 2, "num": 1, "den": 3})).is_equal({"num": 7, "den": 3})
	assert_dict(Rational.to_mixed(7, 3)).is_equal({"whole": 2, "num": 1, "den": 3})
	assert_dict(Rational.to_mixed(8, 4)).is_equal({"whole": 2, "num": 0, "den": 4})


func test_to_decimal_is_exact_or_empty() -> void:
	assert_dict(Rational.to_decimal(3, 4, 2)).is_equal({"mantissa": 75, "scale": 2})
	assert_dict(Rational.to_decimal(1, 2, 2)).is_equal({"mantissa": 50, "scale": 2})
	assert_dict(Rational.to_decimal(1, 3, 2)).is_empty()
	assert_dict(Rational.to_decimal(1, 8, 2)).is_empty()
	assert_dict(Rational.to_decimal(1, 8, 3)).is_equal({"mantissa": 125, "scale": 3})
	assert_int(Rational.decimal_places_of(1, 8)).is_equal(3)
	assert_int(Rational.decimal_places_of(1, 3)).is_equal(-1)


func test_decimals_normalize_compare_and_print_without_floats() -> void:
	assert_dict(Rational.normalize_decimal(50, 2)).is_equal({"mantissa": 5, "scale": 1})
	assert_dict(Rational.normalize_decimal(200, 2)).is_equal({"mantissa": 2, "scale": 0})
	assert_int(Rational.compare_decimal({"mantissa": 5, "scale": 1}, {"mantissa": 45, "scale": 2})).is_equal(1)
	assert_int(Rational.compare_decimal({"mantissa": 50, "scale": 2}, {"mantissa": 5, "scale": 1})).is_equal(0)
	assert_str(Rational.decimal_text({"mantissa": 275, "scale": 2})).is_equal("2.75")
	assert_str(Rational.decimal_text({"mantissa": 5, "scale": 2})).is_equal("0.05")
	assert_str(Rational.decimal_text({"mantissa": 3, "scale": 1})).is_equal("0.3")
	assert_str(Rational.decimal_text({"mantissa": 7, "scale": 0})).is_equal("7")
	assert_str(Rational.decimal_text({"mantissa": -15, "scale": 1})).is_equal("-1.5")
	# The classic float trap: 0.1 + 0.2 stays exactly 0.3.
	var sum: Dictionary = Rational.add(Rational.decimal_to_fraction({"mantissa": 1, "scale": 1}), Rational.decimal_to_fraction({"mantissa": 2, "scale": 1}))
	assert_dict(Rational.to_decimal(int(sum["num"]), int(sum["den"]), 1)).is_equal({"mantissa": 3, "scale": 1})


func test_ratios_reduce_and_keep_their_order() -> void:
	assert_dict(Rational.normalize_ratio(4, 6)).is_equal({"a": 2, "b": 3})
	assert_dict(Rational.normalize_ratio(6, 4)).is_equal({"a": 3, "b": 2})


func test_answers_compare_by_value() -> void:
	assert_bool(Problem.same_value({"num": 2, "den": 4}, {"num": 1, "den": 2})).is_true()
	assert_bool(Problem.same_value({"mantissa": 50, "scale": 2}, {"mantissa": 5, "scale": 1})).is_true()
	assert_bool(Problem.same_value({"whole": 0, "num": 1, "den": 2}, {"num": 1, "den": 2})).is_true()
	assert_bool(Problem.same_value({"mantissa": 5, "scale": 1}, {"num": 1, "den": 2})).is_true()
	assert_bool(Problem.same_value({"a": 4, "b": 6}, {"a": 2, "b": 3})).is_true()
	assert_bool(Problem.same_value({"a": 3, "b": 2}, {"a": 2, "b": 3})).is_false()
	assert_bool(Problem.same_value({"num": 3, "den": 8}, {"num": 1, "den": 2})).is_false()
	assert_bool(Problem.same_value(3, {"num": 3, "den": 1})).is_false() # a whole number is not a fraction answer
	assert_bool(Problem.same_value({"tens": 1, "ones": 2}, {"tens": 1, "ones": 2})).is_true()


func test_simplest_form_problems_want_lowest_terms() -> void:
	var problem: Problem = Problem.new()
	problem.answer = {"num": 1, "den": 2}
	assert_bool(problem.is_correct({"num": 2, "den": 4})).is_true()
	problem.meta = {"simplest_form": true}
	assert_bool(problem.is_correct({"num": 2, "den": 4})).is_false()
	assert_bool(problem.is_correct({"num": 1, "den": 2})).is_true()


func test_text_formats_exact_values() -> void:
	assert_str(Text.display_value(-30)).is_equal("−30")
	assert_str(Text.display_value(12)).is_equal("12")
	assert_str(Text.display_value({"mantissa": 275, "scale": 2})).is_equal("2.75")
	assert_str(Text.display_value({"mantissa": -5, "scale": 1})).is_equal("−0.5")
	assert_str(Text.display_value({"num": 3, "den": 4})).is_equal("3/4")
	assert_str(Text.display_value({"whole": 2, "num": 1, "den": 3})).is_equal("2 1/3")
	assert_str(Text.display_value({"whole": 0, "num": 1, "den": 3})).is_equal("1/3")
	assert_str(Text.display_value({"a": 2, "b": 3})).is_equal("2 : 3")
	assert_str(Text.get_line(&"z7.hint.example_depth_below", {"m": 15, "d": -15})).is_equal("15 meters below zero is −15.")
	assert_str(Text.get_line(&"z7.deccmp.prompt", {"a": {"mantissa": 5, "scale": 1}, "b": {"mantissa": 45, "scale": 2}})).is_equal("Which symbol goes between 0.5 and 0.45?")
