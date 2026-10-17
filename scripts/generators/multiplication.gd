## Early multiplication for Zone 3 (skills mult.*): repeated addition, the total of equal groups,
## the commutative property (a turned array keeps its total) and the 2, 5 and 10 times tables.
## Pure: only the passed-in rng is used.
class_name MultiplicationGenerator
extends RefCounted

## How a fact is written on an answer button, with the times sign (U+00D7): "5 × 3".
const FACT_FORMAT: String = "%d × %d"
## One prompt per number of addends, so every prompt parameter stays a whole number.
const REPEATED_PROMPTS: Dictionary[int, StringName] = {
	2: &"z3.mult.prompt_repeated_2",
	3: &"z3.mult.prompt_repeated_3",
	4: &"z3.mult.prompt_repeated_4",
	5: &"z3.mult.prompt_repeated_5",
}
## The longest repeated addition that has a prompt above.
const MAX_REPEATED_GROUPS: int = 5
const MIN_FACTOR: int = 2
## Groups pictures and arrays hold at most this many groups, gems per group, rows or columns.
const MAX_SIDE: int = 10
const COMMUTATIVE_MAX: int = 5
## A commutative problem shows the answer and this many wrong facts.
const COMMUTATIVE_WRONG: int = 3


static func generate(skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Problem:
	return _make(skill, params, rng, true)


static func _make(skill: Skill, params: Dictionary, rng: RandomNumberGenerator, with_hints: bool) -> Problem:
	var mode: String = String(params.get("mode", "facts"))
	var problem: Problem = GeneratorKit.new_problem(skill, params, GeneratorKit.pick_representation(skill, params))
	var model: Dictionary
	var example_line: Callable
	match mode:
		"repeated_add":
			model = _repeated_add(problem, skill, params, rng)
			example_line = _groups_line_of
		"equal_groups":
			model = _equal_groups(problem, skill, params, rng)
			example_line = _groups_line_of
		"commutative":
			model = _commutative(problem, skill, params, rng)
			example_line = _commutative_line_of
		"facts":
			model = _facts(problem, skill, params, rng)
			example_line = _fact_line_of
		_:
			push_error("MultiplicationGenerator: unknown mode '%s'" % mode)
			return problem
	if with_hints:
		var example: Problem = GeneratorKit.make_example(
			func(sub: RandomNumberGenerator) -> Problem: return _make(skill, params, sub, false), problem, rng)
		GeneratorKit.add_hints(problem, model, example, example_line.call(example))
	return problem


static func _groups_line_of(example: Problem) -> Dictionary:
	var groups: int = example.visual["groups"]
	var size: int = example.visual["size"]
	return {"line_id": &"z3.hint.example_groups_total", "params": {"groups": groups, "size": size, "total": example.answer}}


static func _commutative_line_of(example: Problem) -> Dictionary:
	var rows: int = example.prompt_params["rows"]
	var cols: int = example.prompt_params["cols"]
	return {"line_id": &"z3.hint.example_commutative", "params": {"rows": rows, "cols": cols, "total": rows * cols}}


static func _fact_line_of(example: Problem) -> Dictionary:
	var a: int = example.prompt_params["a"]
	var b: int = example.prompt_params["b"]
	return {"line_id": &"z3.hint.example_fact", "params": {"a": a, "b": b, "product": example.answer}}


static func _groups(groups: int, size: int) -> Dictionary:
	return {"type": "groups", "groups": groups, "size": size}


static func _array(rows: int, cols: int, outline_rows: bool = false) -> Dictionary:
	var picture: Dictionary = {"type": "array", "rows": rows, "cols": cols}
	if outline_rows:
		picture["outline_rows"] = true
	return picture


## A number line from 0 to groups * size with one hop of `size` for each group, labeled every `size`.
static func _hops(groups: int, size: int) -> Dictionary:
	var line: Dictionary = GeneratorKit.number_line(0, groups * size, size, [], [])
	var jumps: Array[Dictionary] = []
	for index: int in groups:
		jumps.append({"from": index * size, "to": (index + 1) * size})
	line["jumps"] = jumps
	return line


## "What is 4 + 4 + 4?" beside a picture of the equal groups (pictorial). The answer is the total.
static func _repeated_add(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var difficulty: int = GeneratorKit.difficulty_of(params)
	var most_groups: int = mini(int(params.get("max_groups", 5)), MAX_REPEATED_GROUPS)
	var max_groups: int = GeneratorKit.eased_max(MIN_FACTOR, most_groups, difficulty, 1)
	var max_size: int = GeneratorKit.eased_max(MIN_FACTOR, mini(int(params.get("max_size", 5)), MAX_SIDE), difficulty, 1)
	var groups: int = rng.randi_range(MIN_FACTOR, max_groups)
	var size: int = rng.randi_range(MIN_FACTOR, max_size)
	var total: int = groups * size
	problem.prompt_line_id = REPEATED_PROMPTS[groups]
	problem.prompt_params = {"n": size}
	problem.answer = total
	problem.visual = _groups(groups, size)
	GeneratorKit.add_distractor(problem, skill, groups, &"counted_groups")
	GeneratorKit.add_distractor(problem, skill, total - size, &"off_by_group")
	GeneratorKit.add_distractor(problem, skill, total + size, &"off_by_group")
	return _hops(groups, size)


## "There are {groups} groups of {size} gems. How many in all?" (concrete), total at most `max`.
static func _equal_groups(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var top: int = GeneratorKit.eased_max(MIN_FACTOR * MIN_FACTOR, int(params.get("max", 25)), GeneratorKit.difficulty_of(params), 2)
	var choices: Array[Vector2i] = []
	for groups: int in range(MIN_FACTOR, MAX_SIDE + 1):
		for size: int in range(MIN_FACTOR, MAX_SIDE + 1):
			if groups * size <= top:
				choices.append(Vector2i(groups, size))
	var pick: Vector2i = choices[rng.randi_range(0, choices.size() - 1)]
	var total: int = pick.x * pick.y
	problem.prompt_line_id = &"z3.mult.prompt_equal_groups"
	problem.prompt_params = {"groups": pick.x, "size": pick.y}
	problem.answer = total
	problem.visual = _groups(pick.x, pick.y)
	GeneratorKit.add_distractor(problem, skill, pick.x + pick.y, &"rows_plus_cols")
	GeneratorKit.add_distractor(problem, skill, pick.x, &"counted_groups")
	# Hint: the same gems lined up, one group to a row.
	return _array(pick.x, pick.y, true)


## "This array shows {rows} × {cols}. Which shows the same total?" (pictorial). The answer is the
## swapped fact "{cols} × {rows}"; each wrong fact is swapped too but has one number changed by one,
## so its total is different (rows and cols differ, so no two wrong totals match either).
static func _commutative(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var high: int = GeneratorKit.eased_max(MIN_FACTOR, mini(int(params.get("max_factor", COMMUTATIVE_MAX)), MAX_SIDE), GeneratorKit.difficulty_of(params), 1)
	var rows: int = rng.randi_range(MIN_FACTOR, high)
	var cols: int = rng.randi_range(MIN_FACTOR, high - 1)
	if cols >= rows:
		cols += 1 # uniform over the column counts that are not `rows`
	problem.prompt_line_id = &"z3.mult.prompt_commutative"
	problem.prompt_params = {"rows": rows, "cols": cols}
	problem.answer = FACT_FORMAT % [cols, rows]
	problem.visual = _array(rows, cols)
	var wrong: Array[String] = [
		FACT_FORMAT % [cols, rows + 1], FACT_FORMAT % [cols, rows - 1],
		FACT_FORMAT % [cols + 1, rows], FACT_FORMAT % [cols - 1, rows],
	]
	var order: Array[int] = GeneratorKit.shuffled_ints([0, 1, 2, 3], rng)
	for index: int in order.slice(0, COMMUTATIVE_WRONG):
		GeneratorKit.add_distractor(problem, skill, wrong[index], &"rows_cols_swapped_wrong")
	# Hint: the same array turned on its side.
	return _array(cols, rows, true)


## "What is {a} × {b}?" with one factor from the tables (2, 5, 10) and the other from 1 to
## max_factor, in either order (abstract). meta.table is the table the fact was drawn from.
static func _facts(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var tables: Array[int] = []
	for value: Variant in params.get("tables", [2, 5, 10]):
		tables.append(int(value))
	var max_factor: int = GeneratorKit.eased_max(1, mini(int(params.get("max_factor", 10)), MAX_SIDE), GeneratorKit.difficulty_of(params), 2)
	var table: int = tables[rng.randi_range(0, tables.size() - 1)]
	var other: int = rng.randi_range(1, max_factor)
	var table_first: bool = rng.randi_range(0, 1) == 0
	var a: int = table if table_first else other
	var b: int = other if table_first else table
	var product: int = a * b
	problem.prompt_line_id = &"z3.mult.prompt_fact"
	problem.prompt_params = {"a": a, "b": b}
	problem.answer = product
	problem.meta = {"table": table, "table_first": table_first}
	# One group of the table number too many or too few (never 0), and the other factor times a
	# different table's number. Taking them in turns puts both kinds among the first three buttons:
	# the first off_by_group always goes in, and a wrong_table that repeats it (5 x 1 + 5 = 10 x 1) is
	# dropped in favour of the next table.
	var both_ways: Array[int] = [product + table, product - table]
	if rng.randi_range(0, 1) == 0:
		both_ways.reverse()
	var off_by_group: Array[int] = []
	for value: int in both_ways:
		if value > 0:
			off_by_group.append(value)
	var other_tables: Array[int] = []
	for candidate: int in tables:
		if candidate != table and not other_tables.has(candidate):
			other_tables.append(candidate)
	other_tables = GeneratorKit.shuffled_ints(other_tables, rng)
	for round_index: int in maxi(off_by_group.size(), other_tables.size()):
		if round_index < off_by_group.size():
			GeneratorKit.add_distractor(problem, skill, off_by_group[round_index], &"off_by_group")
		if round_index < other_tables.size():
			GeneratorKit.add_distractor(problem, skill, other_tables[round_index] * other, &"wrong_table")
	# Hint: a groups of b.
	return _groups(a, b)
