## Exact fractions for Phase 4 (plan "Shared data representation for Phase 4 problems"). A fraction
## is a Dictionary {num: int, den: int} kept in lowest terms with a positive denominator, so two equal
## fractions are always the same Dictionary. Never a float: a float would round 1/3.
##
## gcd and lcm come from MathUtil (Phase 2) rather than a second copy. Pure static functions: no
## nodes, no globals. The independent Python cross-check uses fractions.Fraction and math.gcd instead
## and never ports this file (CLAUDE.md rule 10).
##
## Godot note: a RefCounted class with only static functions is Godot's idiom for a stateless module;
## `class_name` registers it globally, so any script can call Rational.normalize(6, 8).
class_name Rational
extends RefCounted

## The largest product lcm() may form: well inside a 64-bit int, so nothing ever wraps around.
const SAFE_PRODUCT: int = 1 << 62


## True when a and b are whole numbers gcd and lcm take: neither is negative.
static func is_valid_pair(a: int, b: int) -> bool:
	return a >= 0 and b >= 0


## The greatest common factor of two whole numbers (gcd(0, n) is n).
static func gcd(a: int, b: int) -> int:
	assert(is_valid_pair(a, b), "Rational.gcd takes whole numbers, got %d and %d" % [a, b])
	return MathUtil.gcd(a, b)


## True when lcm(a, b) is sure to fit: a × b stays below SAFE_PRODUCT.
static func lcm_fits(a: int, b: int) -> bool:
	return a == 0 or b == 0 or absi(b) < _exact_div(SAFE_PRODUCT, absi(a)) # whole-number division rounds down: still a safe bound


## The least common multiple of two whole numbers (0 when either is 0).
static func lcm(a: int, b: int) -> int:
	assert(is_valid_pair(a, b), "Rational.lcm takes whole numbers, got %d and %d" % [a, b])
	assert(lcm_fits(a, b), "Rational.lcm: %d × %d is too big" % [a, b])
	return MathUtil.lcm(a, b)


## The fraction num/den in lowest terms with a positive denominator: normalize(6, -8) is
## {num: -3, den: 4}; normalize(0, 5) is {num: 0, den: 1}. den must not be 0.
static func normalize(num: int, den: int) -> Dictionary:
	assert(den != 0, "Rational.normalize: the denominator is 0")
	var divisor: int = MathUtil.gcd(num, den)
	var top: int = _exact_div(num, divisor)
	var bottom: int = _exact_div(den, divisor)
	if bottom < 0:
		top = -top
		bottom = -bottom
	return {"num": top, "den": bottom}


## True when `value` is a fraction in canonical form: {num, den}, whole numbers, den above 0, lowest terms.
static func is_canonical(value: Variant) -> bool:
	if not value is Dictionary or value.size() != 2 or not value.has("num") or not value.has("den"):
		return false
	if not value["num"] is int or not value["den"] is int or int(value["den"]) <= 0:
		return false
	return MathUtil.gcd(int(value["num"]), int(value["den"])) == 1


static func add(a: Dictionary, b: Dictionary) -> Dictionary:
	return normalize(int(a["num"]) * int(b["den"]) + int(b["num"]) * int(a["den"]), int(a["den"]) * int(b["den"]))


static func sub(a: Dictionary, b: Dictionary) -> Dictionary:
	return normalize(int(a["num"]) * int(b["den"]) - int(b["num"]) * int(a["den"]), int(a["den"]) * int(b["den"]))


static func mul(a: Dictionary, b: Dictionary) -> Dictionary:
	return normalize(int(a["num"]) * int(b["num"]), int(a["den"]) * int(b["den"]))


## -1, 0 or 1 as a is less than, equal to or greater than b, by cross-multiplying (never a float).
static func compare(a: Dictionary, b: Dictionary) -> int:
	var x: Dictionary = normalize(int(a["num"]), int(a["den"]))
	var y: Dictionary = normalize(int(b["num"]), int(b["den"]))
	var left: int = int(x["num"]) * int(y["den"])
	var right: int = int(y["num"]) * int(x["den"])
	if left < right:
		return -1
	return 1 if left > right else 0


## num/den as a decimal with `places` digits after the point, rounded half away from zero:
## to_decimal(1, 8, 2) is {mantissa: 13, scale: 2} (0.13), to_decimal(-1, 8, 2) is {mantissa: -13, scale: 2}.
static func to_decimal(num: int, den: int, places: int) -> Dictionary:
	assert(den != 0 and places >= 0, "Rational.to_decimal: bad fraction or places")
	var fraction: Dictionary = normalize(num, den)
	var top: int = absi(int(fraction["num"]))
	var bottom: int = int(fraction["den"])
	var scaled: int = top * _power_of_ten(places)
	var whole: int = _exact_div(scaled - scaled % bottom, bottom)
	if (scaled % bottom) * 2 >= bottom:
		whole += 1
	return {"mantissa": -whole if int(fraction["num"]) < 0 else whole, "scale": places}


static func _power_of_ten(places: int) -> int:
	var result: int = 1
	for index: int in places:
		result *= 10
	return result


## a / b for a number that b divides exactly (the plain `/` warns about integer division).
@warning_ignore("integer_division")
static func _exact_div(a: int, b: int) -> int:
	return a / b
