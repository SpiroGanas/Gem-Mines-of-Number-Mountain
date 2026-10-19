## Exact powers, numbers in other bases and scientific notation for Zone 8, Power Tower (Phase 4):
## pure static functions over plain integers and the answer shapes below. No floats anywhere, so a
## value such as 3.4 × 10⁵ is always the integer 340000.
##
## Answer shapes (scripts/core/problem.gd lists them with the rest):
##   {base, digits}            a number written in base 2 to 10, digits most significant first, no
##                             leading zeros ([0] for zero). 13 in base 2 is {base: 2, digits: [1, 1, 0, 1]}.
##   {mantissa, scale, exp}    scientific notation: mantissa / 10^scale × 10^exp. 3.4 × 10⁵ is
##                             {mantissa: 34, scale: 1, exp: 5}. Normalized means 1 <= mantissa / 10^scale < 10.
##   {op, terms}               a written-out calculation: op "mul" or "add" and its terms, "3 × 3 × 3 × 3"
##                             is {op: "mul", terms: [3, 3, 3, 3]} (what a power means, Zone 8).
## None of these is a fraction or decimal for Problem.same_value, so they are compared by exact form:
## 34 × 10⁴ is a different answer from 3.4 × 10⁵ (the named mistake `mantissa_not_normalized`).
##
## Text forms (text()) use Unicode superscript digits ("2⁵", "3.4 × 10⁵") for places that can only
## show plain text, such as the parent's review packet. On the child's screens the composed notation
## scenes (scenes/ui/math/) draw raised exponents with their own Labels instead.
class_name Notation
extends RefCounted

const SUPERSCRIPTS: Array[String] = ["⁰", "¹", "²", "³", "⁴", "⁵", "⁶", "⁷", "⁸", "⁹"]
const TIMES: String = " × "
const PLUS: String = " + "
## Bases a vault lock or a base pad can show (2 to 10: every digit is one of 0 to 9).
const MIN_BASE: int = 2
const MAX_BASE: int = 10


## base^exp for exp >= 0, by repeated multiplication (exact).
static func power(base: int, exp: int) -> int:
	var value: int = 1
	for index: int in maxi(exp, 0):
		value *= base
	return value


## The digits of n >= 0 in `base`, most significant first ([0] for zero).
static func digits_in_base(n: int, base: int) -> Array[int]:
	var digits: Array[int] = []
	var rest: int = maxi(n, 0)
	if rest == 0:
		return [0] as Array[int]
	while rest > 0:
		digits.push_front(rest % base)
		rest = floori(rest / float(base))
	return digits


## The value of digits (most significant first) in `base`: each place is worth `base` times the
## place on its right.
static func value_of_digits(digits: Array, base: int) -> int:
	var value: int = 0
	for digit: Variant in digits:
		value = value * base + int(digit)
	return value


## A canonical {base, digits} for n.
static func base_number(n: int, base: int) -> Dictionary:
	return {"base": base, "digits": digits_in_base(n, base)}


## Digits with the leading zeros taken off ([0] when every digit is 0).
static func trimmed(digits: Array) -> Array[int]:
	var result: Array[int] = []
	for digit: Variant in digits:
		if result.is_empty() and int(digit) == 0:
			continue
		result.append(int(digit))
	if result.is_empty():
		result.append(0)
	return result


static func is_base_number(value: Variant) -> bool:
	return value is Dictionary and value.size() == 2 and value.has("base") and value.has("digits") and value["digits"] is Array


## True for a {base, digits} whose digits are all below its base, with no leading zero.
static func is_canonical_base_number(value: Variant) -> bool:
	if not is_base_number(value):
		return false
	var base: int = int(value["base"])
	var digits: Array = value["digits"]
	if base < MIN_BASE or base > MAX_BASE or digits.is_empty():
		return false
	for digit: Variant in digits:
		if not (digit is int or digit is float) or int(digit) < 0 or int(digit) >= base:
			return false
	return digits.size() == 1 or int(digits[0]) != 0


static func is_sci(value: Variant) -> bool:
	return value is Dictionary and value.size() == 3 and value.has("mantissa") and value.has("scale") and value.has("exp")


## {mantissa, scale, exp} for mantissa / 10^scale × 10^exp.
static func sci(mantissa: int, scale: int, exp: int) -> Dictionary:
	return {"mantissa": mantissa, "scale": scale, "exp": exp}


## True when 1 <= mantissa / 10^scale < 10 and the mantissa has no trailing zero after the point.
static func is_normalized_sci(value: Variant) -> bool:
	if not is_sci(value):
		return false
	var mantissa: int = int(value["mantissa"])
	var scale: int = int(value["scale"])
	if scale < 0 or mantissa <= 0:
		return false
	if scale > 0 and mantissa % 10 == 0:
		return false
	return mantissa >= power(10, scale) and mantissa < power(10, scale + 1)


## The whole number a scientific-notation value stands for, or -1 when it is not a whole number
## (a negative exponent that leaves digits after the point).
static func sci_value(value: Dictionary) -> int:
	var shift: int = int(value["exp"]) - int(value["scale"])
	var mantissa: int = int(value["mantissa"])
	if shift >= 0:
		return mantissa * power(10, shift)
	var divisor: int = power(10, -shift)
	return floori(mantissa / float(divisor)) if mantissa % divisor == 0 else -1


static func is_expression(value: Variant) -> bool:
	return value is Dictionary and value.size() == 2 and value.has("op") and value.has("terms") and value["terms"] is Array


## {op: "mul", terms: [b, b, ..., b]} with `count` copies of b.
static func repeated(op: String, term: int, count: int) -> Dictionary:
	var terms: Array[int] = []
	for index: int in count:
		terms.append(term)
	return {"op": op, "terms": terms}


## The value of a written-out calculation.
static func expression_value(value: Dictionary) -> int:
	var total: int = 1 if str(value["op"]) == "mul" else 0
	for term: Variant in value["terms"]:
		total = total * int(term) if str(value["op"]) == "mul" else total + int(term)
	return total


## A whole number's exponent written in superscript digits: 12 is "¹²".
static func superscript(n: int) -> String:
	var text: String = ""
	for character: String in str(absi(n)):
		text += SUPERSCRIPTS[int(character)]
	return ("⁻" + text) if n < 0 else text


## Plain text for an answer value (the review packet, labels): "3 × 3 × 3", "1101", "3.4 × 10⁵",
## "2⁵". Anything that is not a Zone 8 shape reads as Text.display_value does (via the caller).
static func text(value: Variant) -> String:
	if is_expression(value):
		var parts: PackedStringArray = PackedStringArray()
		for term: Variant in value["terms"]:
			parts.append(str(int(term)))
		return (TIMES if str(value["op"]) == "mul" else PLUS).join(parts)
	if is_base_number(value):
		var digits: String = ""
		for digit: Variant in value["digits"]:
			digits += str(int(digit))
		return digits
	if is_sci(value):
		var mantissa: String = Rational.decimal_text({"mantissa": int(value["mantissa"]), "scale": int(value["scale"])})
		return mantissa + TIMES + "10" + superscript(int(value["exp"]))
	if value is Dictionary and value.size() == 2 and value.has("base") and value.has("exp"):
		return str(int(value["base"])) + superscript(int(value["exp"]))
	return str(value)


## True for any Zone 8 answer shape text() knows.
static func is_notation(value: Variant) -> bool:
	return is_expression(value) or is_base_number(value) or is_sci(value)
