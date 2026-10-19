## Exact fractions and decimals for Phase 4 (Zone 7 and on): pure static functions over plain
## Dictionaries, never a float (docs/phases/phase-4-middle-mountain.md, "Shared data representation").
##
##   fraction  {"num": int, "den": int}        normalized: lowest terms, den > 0 (0 is {0, 1})
##   mixed     {"whole": int, "num": int, "den": int} with 0 <= num < den
##   decimal   {"mantissa": int, "scale": int}  mantissa / 10^scale; normalized: no trailing zeros
##   ratio     {"a": int, "b": int}             normalized: lowest terms (order matters)
##
## gcd and lcm come from MathUtil (Phase 2) rather than being written twice. The independent Python
## cross-check uses fractions.Fraction and decimal.Decimal and never ports this file (CLAUDE.md rule 10).
class_name Rational
extends RefCounted


## num/den in lowest terms with a positive denominator. den must not be 0.
static func normalize(num: int, den: int) -> Dictionary:
	assert(den != 0, "a fraction cannot have a zero denominator")
	if num == 0:
		return {"num": 0, "den": 1}
	var sign: int = -1 if (num < 0) != (den < 0) else 1
	var g: int = MathUtil.gcd(num, den)
	return {"num": sign * _div(absi(num), g), "den": _div(absi(den), g)}


## A fraction Dictionary rebuilt in normal form.
static func normalized(fraction: Dictionary) -> Dictionary:
	return normalize(int(fraction["num"]), int(fraction["den"]))


static func is_fraction(value: Variant) -> bool:
	return value is Dictionary and value.size() == 2 and value.has("num") and value.has("den")


static func is_mixed(value: Variant) -> bool:
	return value is Dictionary and value.size() == 3 and value.has("whole") and value.has("num") and value.has("den")


static func is_decimal(value: Variant) -> bool:
	return value is Dictionary and value.size() == 2 and value.has("mantissa") and value.has("scale")


static func is_ratio(value: Variant) -> bool:
	return value is Dictionary and value.size() == 2 and value.has("a") and value.has("b")


static func add(a: Dictionary, b: Dictionary) -> Dictionary:
	return normalize(int(a["num"]) * int(b["den"]) + int(b["num"]) * int(a["den"]), int(a["den"]) * int(b["den"]))


static func sub(a: Dictionary, b: Dictionary) -> Dictionary:
	return normalize(int(a["num"]) * int(b["den"]) - int(b["num"]) * int(a["den"]), int(a["den"]) * int(b["den"]))


static func mul(a: Dictionary, b: Dictionary) -> Dictionary:
	return normalize(int(a["num"]) * int(b["num"]), int(a["den"]) * int(b["den"]))


## -1, 0 or 1 as a is less than, equal to or greater than b (by cross-multiplying, never dividing).
static func compare(a: Dictionary, b: Dictionary) -> int:
	var x: Dictionary = normalized(a) # positive denominators, so cross-multiplying keeps the order
	var y: Dictionary = normalized(b)
	return signi(int(x["num"]) * int(y["den"]) - int(y["num"]) * int(x["den"]))


## The improper fraction a mixed number stands for: 2 1/3 is 7/3.
static func from_mixed(mixed: Dictionary) -> Dictionary:
	return normalize(int(mixed["whole"]) * int(mixed["den"]) + int(mixed["num"]), int(mixed["den"]))


## A non-negative fraction as a mixed number {whole, num, den} with num < den (den kept, not reduced):
## 7/3 is {2, 1, 3}.
@warning_ignore("integer_division")
static func to_mixed(num: int, den: int) -> Dictionary:
	assert(num >= 0 and den > 0, "to_mixed needs a non-negative fraction")
	return {"whole": num / den, "num": num % den, "den": den}


## num/den as a decimal with exactly `places` decimal places, when it is exact at that many places
## (den divides 10^places after reduction). Returns {} when it is not: the generators never ask for
## a decimal of 1/3. Integer division only: 3/4 at 2 places is {75, 2}.
static func to_decimal(num: int, den: int, places: int) -> Dictionary:
	var power: int = pow10(places)
	if (num * power) % den != 0:
		return {}
	return {"mantissa": _div(num * power, den), "scale": places}


## The fewest places at which num/den is an exact decimal (up to `max_places`), or -1.
static func decimal_places_of(num: int, den: int, max_places: int = 6) -> int:
	for places: int in range(0, max_places + 1):
		if (num * pow10(places)) % den == 0:
			return places
	return -1


## A decimal with its trailing zeros removed: 0.50 is 0.5 and 2.0 is 2.
static func normalize_decimal(mantissa: int, scale: int) -> Dictionary:
	var m: int = mantissa
	var s: int = scale
	while s > 0 and m % 10 == 0:
		m = _div(m, 10)
		s -= 1
	return {"mantissa": m, "scale": s}


## A decimal as the fraction it stands for: 0.25 is 1/4.
static func decimal_to_fraction(decimal: Dictionary) -> Dictionary:
	return normalize(int(decimal["mantissa"]), pow10(int(decimal["scale"])))


## -1, 0 or 1 comparing two decimals after aligning their scales (integers only).
static func compare_decimal(a: Dictionary, b: Dictionary) -> int:
	var scale: int = maxi(int(a["scale"]), int(b["scale"]))
	var left: int = int(a["mantissa"]) * pow10(scale - int(a["scale"]))
	var right: int = int(b["mantissa"]) * pow10(scale - int(b["scale"]))
	return signi(left - right)


## A ratio a : b in lowest terms (order kept).
static func normalize_ratio(a: int, b: int) -> Dictionary:
	var g: int = MathUtil.gcd(a, b)
	if g == 0:
		return {"a": 0, "b": 0}
	return {"a": _div(a, g), "b": _div(b, g)}


## The exact value of a fraction, mixed number or decimal as a normalized fraction; {} for anything
## else. Used to compare answers by value (Problem.same_value).
static func value_of(value: Variant) -> Dictionary:
	if is_fraction(value) and int(value["den"]) != 0:
		return normalized(value)
	if is_mixed(value) and int(value["den"]) != 0:
		return from_mixed(value)
	if is_decimal(value) and int(value["scale"]) >= 0:
		return decimal_to_fraction(value)
	return {}


## 10 to the power `places` (0 or more), as an int.
static func pow10(places: int) -> int:
	var result: int = 1
	for index: int in places:
		result *= 10
	return result


## The decimal's text with its point: {275, 2} is "2.75", {5, 2} is "0.05", {-15, 1} is "-1.5".
static func decimal_text(decimal: Dictionary) -> String:
	var mantissa: int = int(decimal["mantissa"])
	var scale: int = int(decimal["scale"])
	var digits: String = str(absi(mantissa))
	if scale > 0:
		while digits.length() <= scale:
			digits = "0" + digits
		digits = digits.substr(0, digits.length() - scale) + "." + digits.substr(digits.length() - scale)
	return ("-" if mantissa < 0 else "") + digits


static func _div(a: int, b: int) -> int:
	return MathUtil._exact_div(a, b)
