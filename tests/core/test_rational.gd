# Mirrors scripts/core/rational.gd (P4-S29-02). The expected values are worked out by hand in each
# case (no shared code), plus a brute-force sweep: a fraction is in lowest terms when no number from
# 2 up divides both parts.
class_name RationalTest
extends GdUnitTestSuite


func _f(num: int, den: int) -> Dictionary:
	return {"num": num, "den": den}


func _lowest_by_trial(num: int, den: int) -> bool:
	for d: int in range(2, absi(den) + 1):
		if num % d == 0 and den % d == 0:
			return false
	return true


# --- gcd and lcm (delegated to MathUtil) -------------------------------------------------------


func test_gcd_cases() -> void:
	var cases: Array[Array] = [
		[12, 18, 6], [18, 12, 6], [7, 13, 1], [8, 8, 8], [0, 5, 5], [5, 0, 5], [0, 0, 0],
		[1, 99, 1], [36, 48, 12], [17, 51, 17], [100, 75, 25], [64, 48, 16],
	]
	for case: Array in cases:
		assert_int(Rational.gcd(case[0], case[1])).override_failure_message("gcd(%d, %d)" % [case[0], case[1]]).is_equal(case[2])


func test_lcm_cases() -> void:
	var cases: Array[Array] = [
		[4, 6, 12], [6, 4, 12], [3, 5, 15], [8, 12, 24], [7, 7, 7], [1, 9, 9], [0, 9, 0],
		[12, 18, 36], [9, 12, 36], [14, 15, 210], [16, 24, 48],
	]
	for case: Array in cases:
		assert_int(Rational.lcm(case[0], case[1])).override_failure_message("lcm(%d, %d)" % [case[0], case[1]]).is_equal(case[2])


func test_gcd_times_lcm_is_the_product() -> void:
	for a: int in range(1, 41):
		for b: int in range(1, 41):
			assert_int(Rational.gcd(a, b) * Rational.lcm(a, b)).is_equal(a * b)


func test_negative_inputs_are_not_a_valid_pair() -> void:
	assert_bool(Rational.is_valid_pair(3, 4)).is_true()
	assert_bool(Rational.is_valid_pair(0, 0)).is_true()
	assert_bool(Rational.is_valid_pair(-3, 4)).is_false()
	assert_bool(Rational.is_valid_pair(3, -4)).is_false()


func test_the_lcm_overflow_guard() -> void:
	assert_bool(Rational.lcm_fits(1000, 1000)).is_true()
	assert_bool(Rational.lcm_fits(0, 1 << 62)).is_true()
	assert_bool(Rational.lcm_fits(1 << 31, 1 << 30)).is_true()
	assert_bool(Rational.lcm_fits(1 << 31, 1 << 31)).is_false()
	assert_bool(Rational.lcm_fits(1 << 40, 1 << 30)).is_false()


# --- normalize -----------------------------------------------------------------------------


func test_normalize_cases() -> void:
	var cases: Array[Array] = [
		[6, 8, 3, 4], [3, 4, 3, 4], [12, 18, 2, 3], [10, 5, 2, 1], [0, 7, 0, 1], [6, -8, -3, 4],
		[-6, -8, 3, 4], [-6, 8, -3, 4], [48, 36, 4, 3], [17, 34, 1, 2], [9, 9, 1, 1],
	]
	for case: Array in cases:
		assert_dict(Rational.normalize(case[0], case[1])).override_failure_message("%d/%d" % [case[0], case[1]]).is_equal(_f(case[2], case[3]))


func test_normalize_always_gives_lowest_terms_with_a_positive_denominator() -> void:
	for den: int in range(-24, 25):
		if den == 0:
			continue
		for num: int in range(-24, 25):
			var result: Dictionary = Rational.normalize(num, den)
			assert_int(result["den"]).is_greater(0)
			assert_bool(_lowest_by_trial(result["num"], result["den"])).is_true()
			assert_int(result["num"] * den).is_equal(num * result["den"]) # same value


func test_is_canonical() -> void:
	assert_bool(Rational.is_canonical(_f(3, 4))).is_true()
	assert_bool(Rational.is_canonical(_f(0, 1))).is_true()
	assert_bool(Rational.is_canonical(_f(6, 8))).is_false()
	assert_bool(Rational.is_canonical(_f(3, -4))).is_false()
	assert_bool(Rational.is_canonical({"num": 3})).is_false()
	assert_bool(Rational.is_canonical({"a": 3, "b": 4})).is_false()
	assert_bool(Rational.is_canonical(0.75)).is_false()


# --- arithmetic and compare ------------------------------------------------------------------


func test_add_sub_mul() -> void:
	assert_dict(Rational.add(_f(1, 2), _f(1, 3))).is_equal(_f(5, 6))
	assert_dict(Rational.add(_f(1, 4), _f(1, 4))).is_equal(_f(1, 2))
	assert_dict(Rational.add(_f(2, 3), _f(1, 3))).is_equal(_f(1, 1))
	assert_dict(Rational.sub(_f(3, 4), _f(1, 4))).is_equal(_f(1, 2))
	assert_dict(Rational.sub(_f(1, 3), _f(1, 2))).is_equal(_f(-1, 6))
	assert_dict(Rational.sub(_f(2, 5), _f(2, 5))).is_equal(_f(0, 1))
	assert_dict(Rational.mul(_f(2, 3), _f(3, 4))).is_equal(_f(1, 2))
	assert_dict(Rational.mul(_f(-1, 2), _f(4, 5))).is_equal(_f(-2, 5))
	assert_dict(Rational.mul(_f(0, 1), _f(4, 5))).is_equal(_f(0, 1))


func test_compare() -> void:
	assert_int(Rational.compare(_f(1, 2), _f(2, 4))).is_equal(0)
	assert_int(Rational.compare(_f(1, 3), _f(1, 2))).is_equal(-1)
	assert_int(Rational.compare(_f(3, 4), _f(2, 3))).is_equal(1)
	assert_int(Rational.compare(_f(-1, 2), _f(1, 3))).is_equal(-1)
	assert_int(Rational.compare(_f(6, 8), _f(3, 4))).is_equal(0)
	assert_int(Rational.compare(_f(5, 1), _f(9, 2))).is_equal(1)


# --- to_decimal ------------------------------------------------------------------------------


func test_to_decimal_rounds_half_away_from_zero() -> void:
	assert_dict(Rational.to_decimal(11, 4, 2)).is_equal({"mantissa": 275, "scale": 2})
	assert_dict(Rational.to_decimal(1, 3, 2)).is_equal({"mantissa": 33, "scale": 2})
	assert_dict(Rational.to_decimal(2, 3, 2)).is_equal({"mantissa": 67, "scale": 2})
	assert_dict(Rational.to_decimal(1, 8, 2)).is_equal({"mantissa": 13, "scale": 2})
	assert_dict(Rational.to_decimal(-1, 8, 2)).is_equal({"mantissa": -13, "scale": 2})
	assert_dict(Rational.to_decimal(1, 2, 0)).is_equal({"mantissa": 1, "scale": 0})
	assert_dict(Rational.to_decimal(3, 4, 1)).is_equal({"mantissa": 8, "scale": 1})
	assert_dict(Rational.to_decimal(7, 1, 2)).is_equal({"mantissa": 700, "scale": 2})
	assert_dict(Rational.to_decimal(0, 5, 3)).is_equal({"mantissa": 0, "scale": 3})
