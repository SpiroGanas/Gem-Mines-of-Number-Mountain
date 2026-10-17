# Mirrors scripts/core/math_util.gd. Every definition below is written out the slow, obvious way
# inside this test (trial counting, no shared code), and MathUtil is compared with it for every n
# up to 1,000 (P2-S15-03).
class_name MathUtilTest
extends GdUnitTestSuite

const LIMIT: int = 1000


# --- Brute-force definitions (the oracle) ---------------------------------------------------


## Every whole number from 1 to n that leaves no remainder, found by trying them all.
func _slow_factors(n: int) -> Array[int]:
	var found: Array[int] = []
	for d: int in range(1, n + 1):
		if n % d == 0:
			found.append(d)
	return found


## Prime means exactly two factors (so 0 and 1 are not prime).
func _slow_is_prime(n: int) -> bool:
	return _slow_factors(n).size() == 2


## Prime factors with repeats, smallest first, found by dividing out the smallest factor above 1.
func _slow_prime_factorization(n: int) -> Array[int]:
	var found: Array[int] = []
	var left: int = n
	while left > 1:
		for d: int in range(2, left + 1):
			if left % d == 0:
				found.append(d)
				left = int(left / d)
				break
	return found


## The largest number that is a factor of both.
func _slow_gcd(a: int, b: int) -> int:
	var best: int = 0
	for d: int in range(1, maxi(a, b) + 1):
		if a % d == 0 and b % d == 0:
			best = d
	return best


## The first number that is in both lists of multiples.
func _slow_lcm(a: int, b: int) -> int:
	var m: int = maxi(a, b)
	while m % a != 0 or m % b != 0:
		m += 1
	return m


# --- is_prime / factors / prime_factorization up to 1,000 -----------------------------------


func test_is_prime_matches_the_two_factor_definition_for_every_n_up_to_1000() -> void:
	var bad: Array[int] = []
	for n: int in range(1, LIMIT + 1):
		if MathUtil.is_prime(n) != _slow_is_prime(n):
			bad.append(n)
	assert_array(bad).override_failure_message("is_prime is wrong for %s" % [bad]).is_empty()


func test_is_prime_edge_cases() -> void:
	for n: int in [-7, -1, 0, 1]:
		assert_bool(MathUtil.is_prime(n)).override_failure_message(str(n)).is_false()
	for n: int in [2, 3, 5, 7, 11, 13, 97, 997]:
		assert_bool(MathUtil.is_prime(n)).override_failure_message(str(n)).is_true()
	for n: int in [4, 9, 25, 49, 91, 1000]:
		assert_bool(MathUtil.is_prime(n)).override_failure_message(str(n)).is_false()


func test_there_are_168_primes_up_to_1000() -> void:
	var count: int = 0
	for n: int in range(1, LIMIT + 1):
		if MathUtil.is_prime(n):
			count += 1
	assert_int(count).is_equal(168)


func test_factors_match_trial_division_for_every_n_up_to_1000() -> void:
	for n: int in range(1, LIMIT + 1):
		assert_array(MathUtil.factors(n)).override_failure_message("factors(%d)" % n).is_equal(_slow_factors(n))


func test_factors_edge_cases() -> void:
	assert_array(MathUtil.factors(1)).is_equal([1])
	assert_array(MathUtil.factors(2)).is_equal([1, 2])
	assert_array(MathUtil.factors(36)).is_equal([1, 2, 3, 4, 6, 9, 12, 18, 36])
	assert_array(MathUtil.factors(0)).is_empty()
	assert_array(MathUtil.factors(-12)).is_empty()


func test_prime_factorization_matches_repeated_division_for_every_n_up_to_1000() -> void:
	for n: int in range(2, LIMIT + 1):
		var expected: Array[int] = _slow_prime_factorization(n)
		assert_array(MathUtil.prime_factorization(n)).override_failure_message("prime_factorization(%d)" % n).is_equal(expected)


func test_prime_factorization_multiplies_back_and_has_only_primes() -> void:
	for n: int in range(2, LIMIT + 1):
		var product: int = 1
		for p: int in MathUtil.prime_factorization(n):
			product *= p
			assert_bool(_slow_is_prime(p)).override_failure_message("%d is not prime in %d" % [p, n]).is_true()
		assert_int(product).override_failure_message("product for %d" % n).is_equal(n)


func test_prime_factorization_edge_cases() -> void:
	assert_array(MathUtil.prime_factorization(1)).is_empty()
	assert_array(MathUtil.prime_factorization(0)).is_empty()
	assert_array(MathUtil.prime_factorization(2)).is_equal([2])
	assert_array(MathUtil.prime_factorization(72)).is_equal([2, 2, 2, 3, 3])
	assert_array(MathUtil.prime_factorization(997)).is_equal([997])
	assert_array(MathUtil.prime_factorization(1024)).is_equal([2, 2, 2, 2, 2, 2, 2, 2, 2, 2])


# --- gcd and lcm -----------------------------------------------------------------------------


func test_gcd_matches_the_largest_shared_factor_for_all_pairs_up_to_60() -> void:
	for a: int in range(1, 61):
		for b: int in range(1, 61):
			assert_int(MathUtil.gcd(a, b)).override_failure_message("gcd(%d, %d)" % [a, b]).is_equal(_slow_gcd(a, b))


func test_lcm_matches_the_first_shared_multiple_for_all_pairs_up_to_60() -> void:
	for a: int in range(1, 61):
		for b: int in range(1, 61):
			assert_int(MathUtil.lcm(a, b)).override_failure_message("lcm(%d, %d)" % [a, b]).is_equal(_slow_lcm(a, b))


func test_gcd_and_lcm_against_every_n_up_to_1000_with_a_fixed_partner() -> void:
	for n: int in range(1, LIMIT + 1):
		for partner: int in [1, 6, 12, 35]:
			assert_int(MathUtil.gcd(n, partner)).override_failure_message("gcd(%d, %d)" % [n, partner]).is_equal(_slow_gcd(n, partner))
			assert_int(MathUtil.lcm(n, partner)).override_failure_message("lcm(%d, %d)" % [n, partner]).is_equal(_slow_lcm(n, partner))


func test_gcd_and_lcm_edge_cases() -> void:
	assert_int(MathUtil.gcd(0, 5)).is_equal(5)
	assert_int(MathUtil.gcd(5, 0)).is_equal(5)
	assert_int(MathUtil.gcd(0, 0)).is_equal(0)
	assert_int(MathUtil.gcd(-12, 18)).is_equal(6)
	assert_int(MathUtil.lcm(0, 5)).is_equal(0)
	assert_int(MathUtil.lcm(4, 6)).is_equal(12)
	assert_int(MathUtil.lcm(7, 7)).is_equal(7)
	assert_int(MathUtil.lcm(-4, 6)).is_equal(12)


func test_lcm_divides_before_it_multiplies_so_large_results_stay_exact() -> void:
	var big: int = 3037000499 # a * b first would overflow a 64-bit int; a / gcd * b does not
	assert_int(MathUtil.lcm(big, big)).is_equal(big)
	assert_int(MathUtil.lcm(big, 1)).is_equal(big)
	assert_int(MathUtil.gcd(big * 2, big * 3)).is_equal(big)


func test_gcd_times_lcm_is_the_product() -> void:
	for a: int in range(1, 41):
		for b: int in range(1, 41):
			assert_int(MathUtil.gcd(a, b) * MathUtil.lcm(a, b)).is_equal(a * b)
