## Number rings for Zone 12, The Infinite Core (skills sets.integer.classify, sets.rational.classify, sets.real.classify).
## The numbers live in three nested rings: the integers (whole numbers and their opposites), inside the rational numbers
## (anything that is one integer over another), inside the real numbers (everything on the number line, including roots
## like the square root of 2 that no fraction can match). A number is written on a card (the `number_card` picture) and the
## child says which ring it belongs to. Pure: only the passed-in rng is used.
##
## Modes (params.mode):
##   integer   "Is the number on the card an integer?" Yes or no.
##   rational  "Can the number on the card be written as a fraction?" Yes or no.
##   real      "Which is the smallest ring the number fits in?" integer, rational or real.
##
## The cards are never ambiguous for a child: a fraction never reduces to a whole number, a decimal always ends (1/3 is
## written as a fraction, never as 0.333), and a root is the root of a perfect square (whose value is a whole number) or of
## a number that is not (which no fraction can match).
##
## The named mistakes:
##   negative_not_integer   said a negative number is not an integer;
##   root_never_integer     said the root of a perfect square is not a whole number;
##   fraction_is_integer    said a fraction or decimal is an integer;
##   integer_not_rational   said a whole number cannot be written as a fraction;
##   decimal_not_rational   said a decimal or fraction is not rational;
##   sqrt_always_rational   said the root of a non-square is rational;
##   picked_bigger_ring     picked a ring that holds the number but is not the smallest;
##   mixed_up_set           any other wrong yes or no about the integers.
class_name NumberSetsGenerator
extends RefCounted

const PROMPT_INTEGER: StringName = &"z12.sets.prompt_integer"
const PROMPT_RATIONAL: StringName = &"z12.sets.prompt_rational"
const PROMPT_REAL: StringName = &"z12.sets.prompt_real"
const RINGS: Array[StringName] = [&"integer", &"rational", &"real"]
const PERFECT_SQUARES: Array[int] = [4, 9, 16, 25, 36, 49, 64, 81]
const NON_SQUARES: Array[int] = [2, 3, 5, 6, 7, 8, 10, 11, 12, 13, 14, 15, 17, 18, 19, 20]
## Fractions a/b of b from 2 to 12 that stay between whole numbers: a is never a multiple of b.
const MAX_DEN: int = 12


static func generate(skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Problem:
	return _make(skill, params, rng, true)


## The smallest ring a card fits in: integer, rational or real.
static func ring_of(card: Dictionary) -> StringName:
	match str(card["form"]):
		"int":
			return &"integer"
		"frac", "decimal":
			return &"rational"
		"root":
			return &"integer" if PERFECT_SQUARES.has(int(card["a"])) else &"real"
	return &"real"


## A `number_card` picture. `lit` lights a ring (hint), `rings` draws the nested rings.
static func card(form: String, a: int, b: int = 0, scale: int = 0) -> Dictionary:
	var made: Dictionary = {"type": "number_card", "form": form, "a": a}
	if form == "frac":
		made["b"] = b
	if form == "decimal":
		made["scale"] = scale
	return made


static func _make(skill: Skill, params: Dictionary, rng: RandomNumberGenerator, with_hints: bool) -> Problem:
	var mode: String = String(params.get("mode", "real"))
	var problem: Problem = GeneratorKit.new_problem(skill, params, GeneratorKit.pick_representation(skill, params))
	var easy: bool = GeneratorKit.difficulty_of(params) < 0
	var yes_no: bool = mode != "real"
	# For yes/no skills draw the answer first so yes and no are about equally likely.
	var wants: StringName = &""
	if mode == "integer":
		wants = &"integer" if rng.randi_range(0, 1) == 0 else &"other"
	elif mode == "rational":
		wants = &"rational" if rng.randi_range(0, 2) > 0 else &"real"
	var picture: Dictionary = _pick_card(mode, wants, easy, rng)
	var ring: StringName = ring_of(picture)
	problem.visual = picture.duplicate()
	problem.meta = {}
	match mode:
		"integer":
			problem.prompt_line_id = PROMPT_INTEGER
			problem.answer = ring == &"integer"
			problem.meta = {"label_lines": GeneratorKit.yes_no_labels()}
			_integer_distractor(problem, skill, picture)
		"rational":
			problem.prompt_line_id = PROMPT_RATIONAL
			problem.answer = ring != &"real"
			problem.meta = {"label_lines": GeneratorKit.yes_no_labels()}
			_rational_distractor(problem, skill, picture)
		_:
			problem.prompt_line_id = PROMPT_REAL
			problem.answer = ring
			problem.meta = {"label_lines": {"integer": "z12.sets.ring_integer", "rational": "z12.sets.ring_rational", "real": "z12.sets.ring_real"}}
			_ring_distractors(problem, skill, picture, ring)
	problem.prompt_params = {}
	var model: Dictionary = picture.duplicate()
	model["rings"] = true
	model["lit"] = String(ring)
	if with_hints:
		var example: Problem = GeneratorKit.make_example(
			func(sub: RandomNumberGenerator) -> Problem: return _make(skill, params, sub, false), problem, rng)
		GeneratorKit.add_hints(problem, model, example, _example_line(mode, example))
	return problem


## A card for the mode. `wants` is &"integer" or &"other" (integer mode), &"rational" or &"real" (rational mode).
static func _pick_card(mode: String, wants: StringName, easy: bool, rng: RandomNumberGenerator) -> Dictionary:
	var want_ring: StringName
	match mode:
		"integer":
			want_ring = &"integer" if wants == &"integer" else (&"rational" if rng.randi_range(0, 2) > 0 else &"real")
		"rational":
			want_ring = &"real" if wants == &"real" else (&"integer" if rng.randi_range(0, 2) == 0 else &"rational")
		_:
			want_ring = RINGS[rng.randi_range(0, 2)]
	var kinds: Array[String] = []
	match want_ring:
		&"integer":
			if easy:
				kinds.assign(["int", "int", "negative"])
			else:
				kinds.assign(["int", "negative", "square"])
		&"rational":
			kinds.assign(["frac", "decimal"])
		_:
			kinds.assign(["root"])
	var kind: String = kinds[rng.randi_range(0, kinds.size() - 1)]
	match kind:
		"int":
			return card("int", rng.randi_range(0, 30))
		"negative":
			return card("int", -rng.randi_range(1, 20))
		"square":
			return card("root", PERFECT_SQUARES[rng.randi_range(0, PERFECT_SQUARES.size() - 1)])
		"frac":
			return _fraction(rng, easy)
		"decimal":
			var scale: int = 1 if easy else rng.randi_range(1, 2)
			var top: int = 9 if scale == 1 else 99
			var mantissa: int = rng.randi_range(1, top)
			if mantissa % 10 == 0:
				mantissa += 1 # a decimal never ends in a zero, and never reads 0.0
			return card("decimal", mantissa, 0, scale)
	return card("root", NON_SQUARES[rng.randi_range(0, NON_SQUARES.size() - 1)])


## A fraction that is not a whole number (the top is never a multiple of the bottom).
static func _fraction(rng: RandomNumberGenerator, easy: bool) -> Dictionary:
	var den: int = rng.randi_range(2, 5 if easy else MAX_DEN)
	var num: int = rng.randi_range(1, den * 2 - 1)
	if num % den == 0:
		num += 1
	return card("frac", num, den)


static func _integer_distractor(problem: Problem, skill: Skill, picture: Dictionary) -> void:
	var form: String = str(picture["form"])
	var name: StringName
	if bool(problem.answer):
		if form == "root":
			name = &"root_never_integer"
		elif int(picture["a"]) < 0:
			name = &"negative_not_integer"
		else:
			name = &"mixed_up_set"
	else:
		name = &"fraction_is_integer" if form in ["frac", "decimal"] else &"mixed_up_set"
	GeneratorKit.add_distractor(problem, skill, not bool(problem.answer), name)


static func _rational_distractor(problem: Problem, skill: Skill, picture: Dictionary) -> void:
	var name: StringName
	if bool(problem.answer):
		name = &"integer_not_rational" if str(picture["form"]) in ["int", "root"] else &"decimal_not_rational"
	else:
		name = &"sqrt_always_rational"
	GeneratorKit.add_distractor(problem, skill, not bool(problem.answer), name)


static func _ring_distractors(problem: Problem, skill: Skill, picture: Dictionary, ring: StringName) -> void:
	var form: String = str(picture["form"])
	for other: StringName in RINGS:
		if other == ring:
			continue
		var name: StringName = &"picked_bigger_ring"
		match ring:
			&"integer":
				if form == "root":
					name = &"root_never_integer"
				elif form == "int" and int(picture["a"]) < 0 and other == &"rational":
					name = &"negative_not_integer"
			&"rational":
				if other == &"integer":
					name = &"fraction_is_integer"
				elif form == "decimal":
					name = &"decimal_not_rational"
			_:
				name = &"sqrt_always_rational"
		GeneratorKit.add_distractor(problem, skill, other, name)


static func _example_line(mode: String, example: Problem) -> Dictionary:
	match mode:
		"integer":
			return {"line_id": &"z12.hint.example_integer_yes" if example.answer else &"z12.hint.example_integer_no", "params": {}}
		"rational":
			return {"line_id": &"z12.hint.example_rational_yes" if example.answer else &"z12.hint.example_rational_no", "params": {}}
	return {"line_id": StringName("z12.hint.example_set_" + str(example.answer)), "params": {}}
