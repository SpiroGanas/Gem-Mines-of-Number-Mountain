## Mixing tables and groups for Zone 10, Clockwork Depths (skills group.*): the numbers 0 to n - 1 on a loop, mixed by
## adding (or multiplying) and wrapping around. A table (a Cayley table) lists every mix: row a, column b holds
## (a op b) mod n. Pure: only the passed-in rng is used.
##
## Modes (params.mode):
##   identity  Which number does nothing? 0 for adding, 1 for multiplying. The child taps it on the mixing table
##             (meta.mixing_table), where tapping a number lights its row and column.
##   inverse   Which number added to a lands on 0? n - a. (The multiplying inverse is Zone 11.)
##   closure   Is every answer in the table a number from 0 to n - 1? Yes for the wrapped table; no for the table
##             with the wrap left off, when some answer is n or more.
##   table     What goes in the ringed box? (r op c) mod n, with r and c above 1 and the raw mix at least n.
##   cyclic    Start at 0 and jump g stations each time: how many jumps until you land on 0 again? n ÷ gcd(n, g).
##
## The named mistakes:
##   picked_one_for_add    1 as the do-nothing number of adding;
##   picked_zero_for_mul   0 as the do-nothing number of multiplying;
##   picked_last_number    n - 1, the last number of the loop;
##   gave_negative_raw     -a, the number with a minus sign;
##   gave_same_value       a itself as its own undo partner;
##   gave_n_minus_one      n - 1 whatever a is;
##   missed_value_ge_n     said "yes, closed" for a table with an answer of n or more;
##   distrusted_wrap       said "no" for the wrapped table;
##   forgot_mod_wrap       the raw sum or product, not wrapped onto the loop;
##   copied_cell_above     the box above the ringed one;
##   stopped_early         one jump too few (forgot the jump that lands back on 0);
##   skipped_identity      n, as if every station were visited;
##   used_jump_size        g, the size of one jump.
class_name GroupGenerator
extends RefCounted

const PROMPT_IDENTITY_ADD: StringName = &"z10.group.prompt_identity_add"
const PROMPT_IDENTITY_MUL: StringName = &"z10.group.prompt_identity_mul"
const PROMPT_INVERSE: StringName = &"z10.group.prompt_inverse"
const PROMPT_CLOSURE_ADD: StringName = &"z10.group.prompt_closure_add"
const PROMPT_CLOSURE_MUL: StringName = &"z10.group.prompt_closure_mul"
const PROMPT_TABLE: StringName = &"z10.group.prompt_table"
const PROMPT_CYCLIC: StringName = &"z10.group.prompt_cyclic"
## The biggest table a picture draws (13 x 13 with its headers).
const MAX_TABLE: int = 12
## The biggest table the closure picture shows without wrapping (its answers go up to 2 × (n - 1) or (n - 1)²).
const MAX_RAW_TABLE: int = 9


static func generate(skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Problem:
	return _make(skill, params, rng, true)


## The full table for (Z_n, op): rows of length n, row a column b holding (a op b) mod n. op is &"add" or &"mul".
static func cayley_table(n: int, op: StringName) -> Array[Array]:
	var rows: Array[Array] = []
	for a: int in n:
		var row: Array = []
		for b: int in n:
			row.append(posmod(mix(a, b, op), n))
		rows.append(row)
	return rows


## a op b before wrapping.
static func mix(a: int, b: int, op: StringName) -> int:
	return a + b if op == &"add" else a * b


## The do-nothing number of (Z_n, op): 0 for adding, 1 for multiplying (n at least 2).
static func identity_of(op: StringName) -> int:
	return 0 if op == &"add" else 1


## True when every mix in the table, wrapped or not, is a number from 0 to n - 1.
static func is_closed(n: int, op: StringName, wrap: bool) -> bool:
	for a: int in n:
		for b: int in n:
			var value: int = posmod(mix(a, b, op), n) if wrap else mix(a, b, op)
			if value >= n:
				return false
	return true


## The `cayley` picture: the n by n table of (Z_n, op). `wrap` false leaves the raw sums and products. `blank` is a
## box [row, column] shown as "?" and `ring` a box to ring (both may be empty). `focus` "identity" lights the
## do-nothing row and column; `row` lights that row.
static func cayley_picture(n: int, op: StringName, wrap: bool, blank: Array = [], ring: Array = [], focus: String = "", row: int = -1) -> Dictionary:
	var picture: Dictionary = {"type": "cayley", "n": n, "op": String(op), "wrap": wrap}
	if not blank.is_empty():
		picture["blank"] = blank
	if not ring.is_empty():
		picture["ring"] = ring
	if focus != "":
		picture["focus"] = focus
	if row >= 0:
		picture["row"] = row
	return picture


static func _make(skill: Skill, params: Dictionary, rng: RandomNumberGenerator, with_hints: bool) -> Problem:
	var mode: String = String(params.get("mode", "identity"))
	var problem: Problem = GeneratorKit.new_problem(skill, params, GeneratorKit.pick_representation(skill, params))
	var model: Dictionary
	match mode:
		"identity":
			model = _identity(problem, skill, params, rng)
		"inverse":
			model = _inverse(problem, skill, params, rng)
		"closure":
			model = _closure(problem, skill, params, rng)
		"table":
			model = _table(problem, skill, params, rng)
		"cyclic":
			model = _cyclic(problem, skill, params, rng)
		_:
			push_error("GroupGenerator: unknown mode '%s'" % mode)
			return problem
	if with_hints:
		var example: Problem = GeneratorKit.make_example(
			func(sub: RandomNumberGenerator) -> Problem: return _make(skill, params, sub, false), problem, rng)
		GeneratorKit.add_hints(problem, model, example, _example_line(mode, example))
	return problem


static func _size(params: Dictionary, rng: RandomNumberGenerator, cap: int) -> int:
	var low: int = int(params.get("min_n", 2))
	var high: int = GeneratorKit.eased_max(low, mini(int(params.get("max_n", cap)), cap), GeneratorKit.difficulty_of(params), 2)
	return rng.randi_range(low, high)


static func _op(params: Dictionary, rng: RandomNumberGenerator) -> StringName:
	var ops: Array = params.get("ops", ["add", "mul"])
	return StringName(str(ops[rng.randi_range(0, ops.size() - 1)]))


static func _identity(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var n: int = maxi(_size(params, rng, MAX_TABLE), 3)
	var op: StringName = _op(params, rng)
	problem.answer = identity_of(op)
	problem.prompt_line_id = PROMPT_IDENTITY_ADD if op == &"add" else PROMPT_IDENTITY_MUL
	problem.prompt_params = {"n": n}
	problem.meta = {"mixing_table": {"n": n, "op": String(op)}}
	if op == &"add":
		GeneratorKit.add_distractor(problem, skill, 1, &"picked_one_for_add")
	else:
		GeneratorKit.add_distractor(problem, skill, 0, &"picked_zero_for_mul")
	GeneratorKit.add_distractor(problem, skill, n - 1, &"picked_last_number")
	return cayley_picture(n, op, true, [], [], "identity")


static func _inverse(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var n: int = maxi(_size(params, rng, MAX_TABLE), 3)
	var a: int = rng.randi_range(1, n - 1)
	problem.answer = n - a
	problem.prompt_line_id = PROMPT_INVERSE
	problem.prompt_params = {"a": a, "n": n}
	problem.meta = {"signed": true} # a child may type -a (and meet gave_negative_raw)
	if problem.representation == &"pictorial":
		problem.visual = cayley_picture(n, &"add", true, [], [], "", a)
	GeneratorKit.add_distractor(problem, skill, -a, &"gave_negative_raw", true)
	GeneratorKit.add_distractor(problem, skill, a, &"gave_same_value")
	GeneratorKit.add_distractor(problem, skill, n - 1, &"gave_n_minus_one")
	return cayley_picture(n, &"add", true, [], [], "identity", a)


static func _closure(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var op: StringName = _op(params, rng)
	var n: int = _size(params, rng, MAX_RAW_TABLE)
	if op == &"mul":
		n = maxi(n, 3) # at 2 the raw table of products (0 and 1) never leaves the loop
	var wrap: bool = rng.randi_range(0, 1) == 0
	problem.answer = is_closed(n, op, wrap)
	problem.prompt_line_id = PROMPT_CLOSURE_ADD if op == &"add" else PROMPT_CLOSURE_MUL
	problem.prompt_params = {"m": n - 1}
	var biggest: int = 0
	for a: int in n:
		for b: int in n:
			biggest = maxi(biggest, posmod(mix(a, b, op), n) if wrap else mix(a, b, op))
	problem.meta = {"label_lines": GeneratorKit.yes_no_labels(), "biggest": biggest}
	problem.visual = cayley_picture(n, op, wrap)
	GeneratorKit.add_distractor(problem, skill, not problem.answer, &"distrusted_wrap" if problem.answer else &"missed_value_ge_n")
	return problem.visual.duplicate(true)


static func _table(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var n: int = maxi(_size(params, rng, MAX_TABLE), 3)
	var op: StringName = _op(params, rng)
	var r: int = 2
	var c: int = 2
	for attempt: int in 30:
		r = rng.randi_range(2, n - 1)
		c = rng.randi_range(2, n - 1)
		if mix(r, c, op) >= n:
			break
	var table: Array[Array] = cayley_table(n, op)
	problem.answer = table[r][c]
	problem.prompt_line_id = PROMPT_TABLE
	problem.prompt_params = {}
	problem.visual = cayley_picture(n, op, true, [r, c], [r, c])
	if mix(r, c, op) >= n:
		GeneratorKit.add_distractor(problem, skill, mix(r, c, op), &"forgot_mod_wrap")
	GeneratorKit.add_distractor(problem, skill, table[r - 1][c], &"copied_cell_above")
	# The neighbour to the left as a third wrong answer. On an adding table it always equals the one above (both are
	# r + c - 1) and is dropped, so an add problem shows two or three buttons; forgot_mod_wrap always exists there.
	GeneratorKit.add_distractor(problem, skill, table[r][c - 1], &"copied_cell_above")
	problem.meta = {"table": {"n": n, "op": String(op), "r": r, "c": c}}
	return cayley_picture(n, op, true, [], [r, c])


static func _cyclic(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var n: int = maxi(_size(params, rng, MAX_TABLE), 4)
	var g: int = rng.randi_range(2, n - 1)
	var jumps: int = floori(float(n) / MathUtil.gcd(n, g))
	problem.answer = jumps
	problem.prompt_line_id = PROMPT_CYCLIC
	problem.prompt_params = {"n": n, "g": g}
	if problem.representation == &"pictorial":
		problem.visual = ModularGenerator.clock_track(n, 0, g, 1, false, -1, true)
	GeneratorKit.add_distractor(problem, skill, jumps - 1, &"stopped_early")
	GeneratorKit.add_distractor(problem, skill, n, &"skipped_identity")
	GeneratorKit.add_distractor(problem, skill, g, &"used_jump_size")
	return ModularGenerator.clock_track(n, 0, g, 1, true, -1, true)


static func _example_line(mode: String, example: Problem) -> Dictionary:
	var p: Dictionary = example.prompt_params
	match mode:
		"identity":
			var op: StringName = StringName(example.meta["mixing_table"]["op"])
			return {"line_id": &"z10.hint.example_identity_add" if op == &"add" else &"z10.hint.example_identity_mul", "params": {}}
		"inverse":
			return {"line_id": &"z10.hint.example_inverse", "params": {"a": p["a"], "b": example.answer}}
		"closure":
			if example.answer:
				return {"line_id": &"z10.hint.example_closure_yes", "params": {"m": p["m"]}}
			return {"line_id": &"z10.hint.example_closure_no", "params": {"m": p["m"], "v": example.meta["biggest"]}}
		"table":
			var spec: Dictionary = example.meta["table"]
			var line: StringName = &"z10.hint.example_table_add" if spec["op"] == "add" else &"z10.hint.example_table_mul"
			return {"line_id": line, "params": {"r": spec["r"], "c": spec["c"], "t": mix(spec["r"], spec["c"], StringName(spec["op"])), "n": spec["n"], "x": example.answer}}
	return {"line_id": &"z10.hint.example_cyclic", "params": {"g": p["g"], "n": p["n"], "j": example.answer}}
