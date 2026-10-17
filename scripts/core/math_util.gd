## Whole-number maths the generators, the rare-gem rules and the factor mechanic share:
## primes, factors, prime factorization, gcd and lcm. Pure static functions: no nodes, no globals,
## and integers only (never a float in the answer), so the result is exact for every int that fits.
##
## The independent Python cross-check does not import or port this file (CLAUDE.md rule 10).
class_name MathUtil
extends RefCounted


## True when n has exactly two factors, 1 and itself. 0, 1 and negative numbers are not prime.
static func is_prime(n: int) -> bool:
	if n < 2:
		return false
	if n < 4:
		return true # 2 and 3
	if n % 2 == 0 or n % 3 == 0:
		return false
	var d: int = 5
	while d * d <= n:
		if n % d == 0 or n % (d + 2) == 0:
			return false
		d += 6
	return true


## Every positive whole number that divides n with nothing left over, smallest first.
## n below 1 has none (an empty list).
static func factors(n: int) -> Array[int]:
	var small: Array[int] = []
	var large: Array[int] = []
	var d: int = 1
	while d * d <= n:
		if n % d == 0:
			small.append(d)
			var partner: int = _exact_div(n, d)
			if partner != d:
				large.append(partner)
		d += 1
	large.reverse()
	return small + large


## The prime factors of n with repeats, smallest first: 12 gives [2, 2, 3]. 1 and below give [].
static func prime_factorization(n: int) -> Array[int]:
	var found: Array[int] = []
	var left: int = n
	var d: int = 2
	while d * d <= left:
		while left % d == 0:
			found.append(d)
			left = _exact_div(left, d)
		d += 1
	if left > 1:
		found.append(left)
	return found


## The greatest common divisor, never negative: gcd(-12, 18) is 6 and gcd(0, 5) is 5.
static func gcd(a: int, b: int) -> int:
	var x: int = absi(a)
	var y: int = absi(b)
	while y != 0:
		var held: int = x % y
		x = y
		y = held
	return x


## The least common multiple, never negative; 0 when either number is 0. It divides before it
## multiplies, so it stays exact for every result that fits an int.
static func lcm(a: int, b: int) -> int:
	if a == 0 or b == 0:
		return 0
	return absi(_exact_div(a, gcd(a, b)) * b)


## a / b for a number that b divides exactly, as an int (the plain `/` warns about integer
## division in the editor, and a float would lose digits for large values).
@warning_ignore("integer_division")
static func _exact_div(a: int, b: int) -> int:
	return a / b
