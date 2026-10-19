## Binary and other bases for Zone 8, Power Tower (skills base.*). params.base is one base (2), or
## params.bases a list to pick from (3, 4, 5, 8). params.mode picks the question:
##   to_decimal    a number written in the base, as lamps (binary, concrete), place-value columns
##                 (binary, pictorial) or dials (other bases): what number is it?  answer an int
##   from_decimal  "Light the lamps to make {n}" / "Set the dials to show {n} in base {b}" on the vault
##                 lock (concrete, meta.vault_lock), or pick it from answer buttons (pictorial)
##                 answer {base, digits}, digits most significant first, no leading zero (Notation)
##   add           two binary numbers in columns: write the sum in binary (the base pad, meta.base_pad)
##                 answer {base: 2, digits}. Every sum has at least one carry.
## The child never types a base prefix. A lock has as many places as the largest number the skill
## asks for needs, so its size never hints at the answer. Pure: only the passed-in rng is used.
##
## The named mistakes:
##   read_as_decimal_digits   1101 read as one thousand one hundred one;
##   reversed_bits            the digits read or written right to left;
##   dropped_leading_place    the first (biggest) lamp or digit left out;
##   greedy_skipped_place     the 0 of a skipped place left out (1101 for 13 becomes 111);
##   used_base_two            binary places (1, 2, 4...) used in another base;
##   forgot_carry             columns added without carrying (1 + 1 written as 0);
##   carried_as_decimal       a 2 written in a column instead of carrying (digits may be 2 here: it is
##                            what the child writes, never a right answer).
class_name BaseGenerator
extends RefCounted

## The most lamps or dials a vault lock (and a lamps picture) has.
const MAX_PLACES: int = 8


static func generate(skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Problem:
	return _make(skill, params, rng, true)


## A row (or two, added) of lamps, dials or digit columns. `rows` hold digits most significant first,
## right-aligned in `places` places; `show_places` writes each place's worth (1, 2, 4...) under it.
static func lamps(base: int, rows: Array, places: int, style: String, plus: bool = false) -> Dictionary:
	var picture: Dictionary = {"type": "lamps", "base": base, "rows": rows, "places": places, "style": style, "show_places": true}
	if plus:
		picture["plus"] = true
	return picture


## The digits as one whole number of the same digits ([1, 1, 0, 1] is 1101).
static func digits_as_int(digits: Array) -> int:
	var value: int = 0
	for digit: Variant in digits:
		value = value * 10 + int(digit)
	return value


## `digits` padded on the left with zeros to `places` digits.
static func padded(digits: Array, places: int) -> Array[int]:
	var result: Array[int] = []
	for index: int in maxi(places - digits.size(), 0):
		result.append(0)
	for digit: Variant in digits:
		result.append(int(digit))
	return result


static func _pick_base(params: Dictionary, rng: RandomNumberGenerator) -> int:
	if params.has("bases"):
		var bases: Array = params["bases"]
		return int(bases[rng.randi_range(0, bases.size() - 1)])
	return int(params.get("base", 2))


static func _add(problem: Problem, skill: Skill, value: Variant, name: StringName) -> void:
	if skill.misconceptions.has(name):
		GeneratorKit.add_distractor(problem, skill, value, name)


static func _make(skill: Skill, params: Dictionary, rng: RandomNumberGenerator, with_hints: bool) -> Problem:
	var problem: Problem = GeneratorKit.new_problem(skill, params, GeneratorKit.pick_representation(skill, params))
	var model: Dictionary = {}
	match str(params.get("mode", "to_decimal")):
		"to_decimal":
			model = _to_decimal(problem, skill, params, rng)
		"from_decimal":
			model = _from_decimal(problem, skill, params, rng)
		"add":
			model = _add_binary(problem, skill, params, rng)
	if with_hints:
		var example: Problem = GeneratorKit.make_example(
			func(sub: RandomNumberGenerator) -> Problem: return _make(skill, params, sub, false), problem, rng)
		GeneratorKit.add_hints(problem, model, example, example_line(example))
	return problem


## The line that states a worked example's answer.
static func example_line(example: Problem) -> Dictionary:
	match str(example.params.get("mode", "to_decimal")):
		"to_decimal":
			var base: int = int(example.visual["base"])
			if base == 2:
				return {"line_id": &"z8.hint.example_binary", "params": {"n": example.answer}}
			return {"line_id": &"z8.hint.example_base", "params": {"b": base, "n": example.answer}}
		"from_decimal":
			var written: int = digits_as_int(example.answer["digits"])
			var n: int = int(example.prompt_params["n"])
			if int(example.answer["base"]) == 2:
				return {"line_id": &"z8.hint.example_binary_make", "params": {"n": n, "s": written}}
			return {"line_id": &"z8.hint.example_base_make", "params": {"n": n, "b": int(example.answer["base"]), "s": written}}
	var meta: Dictionary = example.meta["sum"]
	return {"line_id": &"z8.hint.example_binary_add", "params": {
		"a": meta["a"], "b": meta["b"], "n": int(meta["a"]) + int(meta["b"]), "s": digits_as_int(example.answer["digits"])}}


static func _to_decimal(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var base: int = _pick_base(params, rng)
	var difficulty: int = GeneratorKit.difficulty_of(params)
	var most: int = int(params.get("max_bits", params.get("max_digits", 3)))
	var count: int = rng.randi_range(2, GeneratorKit.eased_max(2, most, difficulty, 1))
	var digits: Array[int] = [rng.randi_range(1, base - 1)]
	for index: int in count - 1:
		digits.append(rng.randi_range(0, base - 1))
	var value: int = Notation.value_of_digits(digits, base)
	problem.answer = value
	problem.prompt_params = {}
	var style: String = "dials"
	if base == 2:
		style = "lamps" if problem.representation == &"concrete" else "digits"
		problem.prompt_line_id = &"z8.binary.prompt_lamps" if style == "lamps" else &"z8.binary.prompt_columns"
	else:
		problem.prompt_line_id = &"z8.base.prompt_read"
		problem.prompt_params = {"b": base}
	problem.visual = lamps(base, [digits], digits.size(), style)
	var reversed: Array[int] = digits.duplicate()
	reversed.reverse()
	_add(problem, skill, digits_as_int(digits), &"read_as_decimal_digits")
	_add(problem, skill, Notation.value_of_digits(reversed, base), &"reversed_bits")
	_add(problem, skill, value - digits[0] * Notation.power(base, digits.size() - 1), &"dropped_leading_place")
	_add(problem, skill, Notation.value_of_digits(digits, 2), &"used_base_two")
	return problem.visual.duplicate(true)


static func _from_decimal(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var base: int = _pick_base(params, rng)
	var authored: int = int(params.get("max_value", 63))
	var top: int = GeneratorKit.eased_max(base, authored, GeneratorKit.difficulty_of(params), 2)
	var n: int = rng.randi_range(base, top) # at least two digits in the base
	var places: int = mini(Notation.digits_in_base(authored, base).size(), MAX_PLACES)
	var digits: Array[int] = Notation.digits_in_base(n, base)
	problem.answer = {"base": base, "digits": digits}
	problem.meta = {"base_pad": {"base": base, "places": places}}
	var style: String = "lamps" if base == 2 else "dials"
	if base == 2:
		problem.prompt_params = {"n": n}
		problem.prompt_line_id = &"z8.binary.prompt_make" if problem.representation == &"concrete" else &"z8.binary.prompt_pick"
	else:
		problem.prompt_params = {"n": n, "b": base}
		problem.prompt_line_id = &"z8.base.prompt_make" if problem.representation == &"concrete" else &"z8.base.prompt_pick"
	if problem.representation == &"concrete":
		problem.meta["vault_lock"] = {"base": base, "places": places}
	else:
		problem.visual = lamps(base, [padded([], places)], places, style)
	var reversed: Array[int] = digits.duplicate()
	reversed.reverse()
	_add(problem, skill, {"base": base, "digits": Notation.trimmed(reversed)}, &"reversed_bits")
	if digits.has(0):
		var no_zeros: Array[int] = []
		for digit: int in digits:
			if digit != 0:
				no_zeros.append(digit)
		_add(problem, skill, {"base": base, "digits": no_zeros}, &"greedy_skipped_place")
	_add(problem, skill, {"base": base, "digits": Notation.trimmed(digits.slice(1))}, &"dropped_leading_place")
	var binary: Array[int] = Notation.digits_in_base(n, 2)
	if base != 2 and binary.size() <= places:
		_add(problem, skill, {"base": base, "digits": binary}, &"used_base_two")
	return lamps(base, [padded(digits, places)], places, style)


static func _add_binary(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var bits: int = GeneratorKit.eased_max(2, int(params.get("max_bits", 5)), GeneratorKit.difficulty_of(params), 1)
	var largest: int = Notation.power(2, bits) - 1
	var a: int = rng.randi_range(2, largest)
	var b: int = rng.randi_range(1, largest)
	if a & b == 0:
		b = b | (a & -a) # share a lit place, so the sum has a carry
	var sum: int = a + b
	var digits: Array[int] = Notation.digits_in_base(sum, 2)
	var places: int = Notation.digits_in_base(largest * 2, 2).size()
	problem.prompt_line_id = &"z8.binary.prompt_add"
	problem.prompt_params = {}
	problem.answer = {"base": 2, "digits": digits}
	problem.meta = {"base_pad": {"base": 2, "places": places}, "sum": {"a": a, "b": b}}
	problem.visual = lamps(2, [Notation.digits_in_base(a, 2), Notation.digits_in_base(b, 2)], places, "digits", true)
	_add(problem, skill, {"base": 2, "digits": Notation.digits_in_base(a ^ b, 2)}, &"forgot_carry")
	# Column sums written as they are (a 2 where a carry belongs).
	var top: Array[int] = padded(Notation.digits_in_base(a, 2), places)
	var bottom: Array[int] = padded(Notation.digits_in_base(b, 2), places)
	var columns: Array[int] = []
	for index: int in places:
		columns.append(top[index] + bottom[index])
	_add(problem, skill, {"base": 2, "digits": Notation.trimmed(columns)}, &"carried_as_decimal")
	return lamps(2, [Notation.digits_in_base(a, 2), Notation.digits_in_base(b, 2), digits], places, "digits", true)
