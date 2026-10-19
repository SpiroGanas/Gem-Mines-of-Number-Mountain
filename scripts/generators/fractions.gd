## Fractions for Zone 7, Crystal Shards (skills fraction.*). A crystal split into equal shards is the
## picture: concrete problems show round crystals cut into wedge shards (or ask the child to light
## shards on one, meta.crystal), pictorial problems show bars cut into strips, abstract problems only
## words and numerals. params.mode picks the question:
##   unit         "The crystal has {den} equal shards. What fraction is one shard?"  answer {1, den}
##   part         light {num}/{den} of a crystal (concrete), or name the lit fraction  answer {num, den}
##   number_line  which fraction is at the gem on a 0-to-1 line with a tick every 1/den
##   equivalent   light a crystal of c shards to match a/b (concrete), or find the missing number in
##                a/b = ?/c or a/b = m/? (abstract, a whole-number answer)
##   compare      which symbol, < or >, goes between a/b and c/d (params.like_den: the same denominator)
##   add          a/b + c/d (params.like_den), the sum below one whole unless params.allow_improper
##   mixed        a mixed number as an improper fraction, or the other way (answer {whole, num, den})
## Every fraction answer is normalized by Rational.normalize (lowest terms, positive denominator) and
## is right in any equal form (Problem.is_correct), so a distractor never equals the answer in value.
## Pure: only the passed-in rng is used, never a float in an answer.
##
## The named mistakes:
##   inverted                       wrote the fraction upside down (den/num);
##   counted_shaded_as_denominator  put the other shards' count on the bottom (1/(den - 1) for 1/den);
##   unshaded_count                 counted the dark shards instead of the lit ones;
##   off_by_one_numerator           miscounted the lit shards by one;
##   counted_ticks_not_gaps         counted the tick marks (den + 1) instead of the gaps on a line;
##   added_to_both                  added the same number to top and bottom instead of multiplying;
##   scaled_numerator_only          multiplied the top but kept the bottom (missing denominator);
##   copied_numerator               kept the top number (or lit as many shards) as in the first fraction;
##   compared_denominators          like denominators, so said the fractions are equal (=);
##   reversed_symbol                pointed the symbol the wrong way;
##   bigger_denominator_bigger      thought more shards means a bigger fraction;
##   compared_numerators_only       compared the top numbers and ignored the bottoms;
##   added_denominators             added tops and bottoms (1/4 + 2/4 = 3/8);
##   added_numerators_only          added the tops and kept the larger bottom, without converting;
##   dropped_whole                  left out the whole crystals of a mixed number;
##   added_whole_to_numerator       added the wholes to the top (2 1/3 as 3/3);
##   swapped_quotient_remainder     swapped the wholes and the leftover shards (7/3 as 1 2/3).
class_name FractionGenerator
extends RefCounted

const SYMBOL_LESS: StringName = &"<"
const SYMBOL_GREATER: StringName = &">"
const SYMBOL_EQUAL: StringName = &"="
## The most shards a crystal the child taps may have: a wedge of a 12-shard crystal is still wider
## than the 64 dp touch minimum at Explorer sizes (scenes/zones/z07_crystal_shards/crystal.gd).
const MAX_TAP_SHARDS: int = 12
const RETRIES: int = 60


static func generate(skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Problem:
	return _make(skill, params, rng, true)


static func _make(skill: Skill, params: Dictionary, rng: RandomNumberGenerator, with_hints: bool) -> Problem:
	var problem: Problem = GeneratorKit.new_problem(skill, params, GeneratorKit.pick_representation(skill, params))
	var model: Dictionary = {}
	var example_line: Callable
	match str(params.get("mode", "unit")):
		"unit":
			model = _unit(problem, skill, params, rng)
			example_line = _unit_line
		"part":
			model = _part(problem, skill, params, rng)
			example_line = _part_line
		"number_line":
			model = _number_line(problem, skill, params, rng)
			example_line = _part_line
		"equivalent":
			model = _equivalent(problem, skill, params, rng)
			example_line = _equivalent_line
		"compare":
			model = _compare(problem, skill, params, rng)
			example_line = _compare_line
		"add":
			model = _add(problem, skill, params, rng)
			example_line = _add_line
		"mixed":
			model = _mixed(problem, skill, params, rng)
			example_line = _mixed_line
	if with_hints:
		var example: Problem = GeneratorKit.make_example(
			func(sub: RandomNumberGenerator) -> Problem: return _make(skill, params, sub, false), problem, rng)
		GeneratorKit.add_hints(problem, model, example, example_line.call(example))
	return problem


# --- Pictures (shared with the decimal and percent generators) ----------------------------------


## A `crystals` picture: one entry per crystal {den, lit, second?}; shape "crystal" (round, wedge
## shards) or "bar" (strips); `wholes` whole crystals in front; `joiner` "plus" or "versus".
static func crystals(entries: Array[Dictionary], shape: String, wholes: int = 0, joiner: String = "") -> Dictionary:
	var picture: Dictionary = {"type": "crystals", "shape": shape, "crystals": entries}
	if wholes > 0:
		picture["wholes"] = wholes
	if joiner != "":
		picture["joiner"] = joiner
	return picture


static func crystal(den: int, lit: int, second: int = 0) -> Dictionary:
	var entry: Dictionary = {"den": den, "lit": lit}
	if second > 0:
		entry["second"] = second
	return entry


## Crystals for concrete problems, bars for pictorial ones.
static func shape_for(representation: StringName) -> String:
	return "bar" if representation == &"pictorial" else "crystal"


## The largest denominator at this difficulty: `params[key]` as authored, eased one step at a time.
static func max_den(params: Dictionary, key: String = "max_den", fallback: int = 12) -> int:
	return GeneratorKit.eased_max(2, int(params.get(key, fallback)), GeneratorKit.difficulty_of(params), 2)


## A numerator 1..den-1 that shares no factor with den, so the fraction is already in lowest terms.
static func coprime_num(den: int, rng: RandomNumberGenerator) -> int:
	var choices: Array[int] = []
	for num: int in range(1, den):
		if MathUtil.gcd(num, den) == 1:
			choices.append(num)
	return choices[rng.randi_range(0, choices.size() - 1)]


static func fraction(num: int, den: int) -> Dictionary:
	return {"num": num, "den": den}


# --- Unit fractions ------------------------------------------------------------------------------


static func _unit(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var den: int = rng.randi_range(2, max_den(params))
	problem.prompt_line_id = &"z7.unit.prompt"
	problem.prompt_params = {"den": den}
	problem.answer = Rational.normalize(1, den)
	GeneratorKit.add_distractor(problem, skill, fraction(den, 1), &"inverted")
	GeneratorKit.add_distractor(problem, skill, fraction(1, den - 1), &"counted_shaded_as_denominator")
	var model: Dictionary = crystals([crystal(den, 1)], "crystal")
	if problem.representation != &"abstract":
		problem.visual = crystals([crystal(den, 1)], shape_for(problem.representation))
	return model


static func _unit_line(example: Problem) -> Dictionary:
	return {"line_id": &"z7.hint.example_unit", "params": {"den": example.prompt_params["den"]}}


# --- Part of a whole -----------------------------------------------------------------------------


static func _part(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var top: int = max_den(params)
	if problem.representation == &"concrete":
		top = mini(top, MAX_TAP_SHARDS)
	var den: int = rng.randi_range(2, top)
	var num: int = rng.randi_range(1, den - 1)
	problem.prompt_params = {"num": num, "den": den}
	problem.answer = Rational.normalize(num, den)
	match problem.representation:
		&"concrete":
			problem.prompt_line_id = &"z7.part.prompt_light"
			problem.meta = {"crystal": {"den": den}}
		&"pictorial":
			problem.prompt_line_id = &"z7.part.prompt_read"
			problem.prompt_params = {"den": den}
			problem.visual = crystals([crystal(den, num)], "crystal")
		_:
			problem.prompt_line_id = &"z7.part.prompt_words"
	GeneratorKit.add_distractor(problem, skill, fraction(den - num, den), &"unshaded_count")
	var miscount: int = num + 1 if num + 1 < den and (num == 1 or rng.randi_range(0, 1) == 0) else num - 1
	GeneratorKit.add_distractor(problem, skill, fraction(miscount, den), &"off_by_one_numerator")
	GeneratorKit.add_distractor(problem, skill, fraction(den, num), &"inverted")
	problem.meta["shown"] = {"num": num, "den": den}
	return crystals([crystal(den, num)], "crystal")


## "{num} of {den} equal shards is {num}/{den}." for any problem whose answer is a lit fraction.
static func _part_line(example: Problem) -> Dictionary:
	var shown: Dictionary = example.meta.get("shown", example.answer)
	return {"line_id": &"z7.hint.example_part", "params": {"num": int(shown["num"]), "den": int(shown["den"])}}


# --- Number line ---------------------------------------------------------------------------------


static func _number_line(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var den: int = rng.randi_range(2, max_den(params, "max_den", 8))
	var num: int = rng.randi_range(1, den - 1)
	problem.prompt_line_id = &"z7.line.prompt"
	problem.prompt_params = {"den": den}
	problem.answer = Rational.normalize(num, den)
	problem.visual = {"type": "fraction_line", "den": den, "wholes": 1, "ticks": den + 1, "marker": fraction(num, den)}
	problem.meta = {"shown": fraction(num, den)}
	GeneratorKit.add_distractor(problem, skill, fraction(num, den + 1), &"counted_ticks_not_gaps")
	GeneratorKit.add_distractor(problem, skill, fraction(den, num), &"inverted")
	return problem.visual.duplicate(true)


# --- Equivalent fractions ------------------------------------------------------------------------


static func _equivalent(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var top: int = max_den(params, "max_den", 24)
	if problem.representation == &"concrete":
		top = mini(top, MAX_TAP_SHARDS)
	# a/b in lowest terms, then c = b * k shards (k >= 2) on the crystal or in the second fraction.
	var b: int = rng.randi_range(2, maxi(2, floori(top / 2.0)))
	var k: int = rng.randi_range(2, maxi(2, floori(float(top) / b)))
	var a: int = coprime_num(b, rng)
	var c: int = b * k
	var m: int = a * k
	var model: Dictionary = crystals([crystal(b, a), crystal(c, m)], "crystal", 0, "versus")
	if problem.representation == &"concrete":
		problem.prompt_line_id = &"z7.equiv.prompt_match"
		problem.prompt_params = {"a": a, "b": b, "c": c}
		problem.answer = Rational.normalize(a, b)
		problem.meta = {"crystal": {"den": c, "match": fraction(a, b)}, "equiv": {"a": a, "b": b, "k": k}}
		GeneratorKit.add_distractor(problem, skill, fraction(a + c - b, c), &"added_to_both")
		GeneratorKit.add_distractor(problem, skill, fraction(a, c), &"copied_numerator")
		return model
	if rng.randi_range(0, 1) == 0:
		problem.prompt_line_id = &"z7.equiv.prompt_num"
		problem.prompt_params = {"a": a, "b": b, "c": c}
		problem.answer = m
		problem.meta = {"equiv": {"a": a, "b": b, "k": k}}
		GeneratorKit.add_distractor(problem, skill, a + c - b, &"added_to_both")
		GeneratorKit.add_distractor(problem, skill, a, &"copied_numerator")
	else:
		problem.prompt_line_id = &"z7.equiv.prompt_den"
		problem.prompt_params = {"a": a, "b": b, "m": m}
		problem.answer = c
		problem.meta = {"equiv": {"a": a, "b": b, "k": k}}
		GeneratorKit.add_distractor(problem, skill, b + m - a, &"added_to_both")
		GeneratorKit.add_distractor(problem, skill, b, &"scaled_numerator_only")
	return model


## "{a}/{b} = {m}/{c}: multiply the top and the bottom by {k}."
static func _equivalent_line(example: Problem) -> Dictionary:
	var e: Dictionary = example.meta["equiv"]
	var a: int = e["a"]
	var b: int = e["b"]
	var k: int = e["k"]
	return {"line_id": &"z7.hint.example_equiv", "params": {"a": a, "b": b, "k": k, "m": a * k, "c": b * k}}


# --- Compare -------------------------------------------------------------------------------------


static func _compare(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var like: bool = bool(params.get("like_den", true))
	var top: int = max_den(params)
	var a: int = 1
	var b: int = 2
	var c: int = 1
	var d: int = 3
	var found: bool = false
	for attempt: int in RETRIES:
		if like:
			b = rng.randi_range(3, maxi(3, top))
			d = b
			a = rng.randi_range(1, b - 1)
			c = rng.randi_range(1, b - 2)
			if c >= a:
				c += 1 # two different numerators
		else:
			b = rng.randi_range(2, top)
			d = rng.randi_range(2, top - 1)
			if d >= b:
				d += 1 # two different denominators
			a = rng.randi_range(1, b - 1)
			c = rng.randi_range(1, d - 1)
		if Rational.compare(fraction(a, b), fraction(c, d)) != 0 and (like or not _unlike_mistakes(a, b, c, d).is_empty()):
			found = true
			break
	if not found: # never reached with the authored ranges; a pair that is always valid
		a = 1
		b = 3
		c = 2 if like else 1
		d = 3 if like else 2
	var answer: StringName = SYMBOL_LESS if Rational.compare(fraction(a, b), fraction(c, d)) < 0 else SYMBOL_GREATER
	var opposite: StringName = SYMBOL_GREATER if answer == SYMBOL_LESS else SYMBOL_LESS
	problem.prompt_line_id = &"z7.compare.prompt"
	problem.prompt_params = {"a": a, "b": b, "c": c, "d": d}
	problem.answer = answer
	if like:
		GeneratorKit.add_distractor(problem, skill, SYMBOL_EQUAL, &"compared_denominators")
		GeneratorKit.add_distractor(problem, skill, opposite, &"reversed_symbol")
	else:
		var mistakes: Dictionary = _unlike_mistakes(a, b, c, d)
		for name: StringName in mistakes:
			GeneratorKit.add_distractor(problem, skill, mistakes[name], name)
		if problem.distractors.is_empty():
			GeneratorKit.add_distractor(problem, skill, opposite, &"compared_numerators_only")
	var model: Dictionary = crystals([crystal(b, a), crystal(d, c)], "bar", 0, "versus")
	if problem.representation == &"pictorial":
		problem.visual = model.duplicate(true)
	return model


## The wrong symbols an unlike-denominator comparison invites: {misconception: symbol}, only those
## that differ from the right symbol. Comparing the tops alone gives "=" when they are equal.
static func _unlike_mistakes(a: int, b: int, c: int, d: int) -> Dictionary:
	var right: int = Rational.compare(fraction(a, b), fraction(c, d))
	var mistakes: Dictionary = {}
	var by_top: int = signi(a - c)
	if by_top != right:
		mistakes[&"compared_numerators_only"] = _symbol(by_top)
	var by_bottom: int = signi(b - d)
	if by_bottom != right:
		mistakes[&"bigger_denominator_bigger"] = _symbol(by_bottom)
	return mistakes


static func _symbol(order: int) -> StringName:
	if order == 0:
		return SYMBOL_EQUAL
	return SYMBOL_LESS if order < 0 else SYMBOL_GREATER


static func _compare_line(example: Problem) -> Dictionary:
	var p: Dictionary = example.prompt_params
	var line: StringName = &"z7.hint.example_compare_like" if p["b"] == p["d"] else &"z7.hint.example_compare"
	return {"line_id": line, "params": {"a": p["a"], "b": p["b"], "c": p["c"], "d": p["d"], "symbol": String(example.answer)}}


# --- Add -----------------------------------------------------------------------------------------


static func _add(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var like: bool = bool(params.get("like_den", true))
	var improper: bool = bool(params.get("allow_improper", false))
	var top: int = max_den(params)
	var a: int = 1
	var b: int = 3
	var c: int = 1
	var d: int = 3
	var found: bool = false
	for attempt: int in RETRIES:
		if like:
			b = rng.randi_range(3, maxi(3, top))
			d = b
			a = rng.randi_range(1, b - 2)
			c = rng.randi_range(1, b - 1 - a) if not improper else rng.randi_range(1, b - 1)
		else:
			b = rng.randi_range(2, top)
			d = rng.randi_range(2, top - 1)
			if d >= b:
				d += 1
			a = rng.randi_range(1, b - 1)
			c = rng.randi_range(1, d - 1)
		var below_one: bool = Rational.compare(Rational.add(fraction(a, b), fraction(c, d)), fraction(1, 1)) < 0
		if (improper or below_one) and (like or MathUtil.lcm(b, d) <= top * 2):
			found = true
			break
	if not found: # never reached with the authored ranges; a sum that is always valid
		a = 1
		b = 3 if like else 2
		c = 1
		d = 3
	var sum: Dictionary = Rational.add(fraction(a, b), fraction(c, d))
	problem.prompt_line_id = &"z7.add.prompt"
	problem.prompt_params = {"a": a, "b": b, "c": c, "d": d}
	problem.answer = sum
	GeneratorKit.add_distractor(problem, skill, fraction(a + c, b + d), &"added_denominators")
	var model: Dictionary
	if like:
		var miscount: int = a + c + 1 if a + c + 1 < b or rng.randi_range(0, 1) == 0 else a + c - 1
		GeneratorKit.add_distractor(problem, skill, fraction(miscount, b), &"off_by_one_numerator")
		model = crystals([crystal(b, a, c)], "crystal")
		if problem.representation != &"abstract":
			problem.visual = crystals([crystal(b, a, c)], shape_for(problem.representation))
	else:
		GeneratorKit.add_distractor(problem, skill, fraction(a + c, maxi(b, d)), &"added_numerators_only")
		var common: int = MathUtil.lcm(b, d)
		model = crystals([crystal(common, a * floori(float(common) / b)), crystal(common, c * floori(float(common) / d))], "bar", 0, "plus")
		if problem.representation == &"pictorial":
			problem.visual = crystals([crystal(b, a), crystal(d, c)], "bar", 0, "plus")
	return model


static func _add_line(example: Problem) -> Dictionary:
	var p: Dictionary = example.prompt_params
	var common: int = MathUtil.lcm(p["b"], p["d"])
	var top: int = p["a"] * floori(float(common) / p["b"]) + p["c"] * floori(float(common) / p["d"])
	return {"line_id": &"z7.hint.example_add", "params": {"a": p["a"], "b": p["b"], "c": p["c"], "d": p["d"], "sum": fraction(top, common)}}


# --- Mixed numbers -------------------------------------------------------------------------------


static func _mixed(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var difficulty: int = GeneratorKit.difficulty_of(params)
	var whole: int = rng.randi_range(1, GeneratorKit.eased_max(1, int(params.get("max_whole", 5)), difficulty, 1))
	var den: int = rng.randi_range(2, max_den(params, "max_den", 8))
	var num: int = coprime_num(den, rng)
	var top: int = whole * den + num
	problem.meta = {"mixed": {"whole": whole, "num": num, "den": den}}
	if rng.randi_range(0, 1) == 0:
		problem.prompt_line_id = &"z7.mixed.prompt_to_improper"
		problem.prompt_params = {"w": whole, "num": num, "den": den}
		problem.answer = Rational.normalize(top, den)
		GeneratorKit.add_distractor(problem, skill, fraction(num, den), &"dropped_whole")
		GeneratorKit.add_distractor(problem, skill, fraction(whole + num, den), &"added_whole_to_numerator")
	else:
		problem.prompt_line_id = &"z7.mixed.prompt_to_mixed"
		problem.prompt_params = {"top": top, "den": den}
		problem.answer = {"whole": whole, "num": num, "den": den}
		GeneratorKit.add_distractor(problem, skill, {"whole": 0, "num": num, "den": den}, &"dropped_whole")
		if num != whole and whole < den:
			GeneratorKit.add_distractor(problem, skill, {"whole": num, "num": whole, "den": den}, &"swapped_quotient_remainder")
		if whole + num < den:
			GeneratorKit.add_distractor(problem, skill, {"whole": whole, "num": whole + num, "den": den}, &"added_whole_to_numerator")
	var model: Dictionary = crystals([crystal(den, num)], "crystal", whole)
	if problem.representation == &"pictorial":
		problem.visual = model.duplicate(true)
	return model


## "{w} wholes are {parts} shards. {parts} + {num} = {top}, so it is {top}/{den}."
static func _mixed_line(example: Problem) -> Dictionary:
	var m: Dictionary = example.meta["mixed"]
	var whole: int = m["whole"]
	var num: int = m["num"]
	var den: int = m["den"]
	return {"line_id": &"z7.hint.example_mixed", "params": {"w": whole, "num": num, "den": den, "top": whole * den + num, "parts": whole * den}}
