## Array problems for Zone 3 (skills arr.rows_cols.*): count the gems in an array of rows and columns,
## or build an array with a given number of rows and columns on the array builder.
## Pure: only the passed-in rng is used.
class_name ArraysGenerator
extends RefCounted

## Arrays have at least two rows and two columns, so rows and columns are both worth looking at.
const MIN_SIDE: int = 2
## The array picture holds at most this many rows or columns (Problem.VISUAL_TYPES).
const MAX_SIDE: int = 10


static func generate(skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Problem:
	return _make(skill, params, rng, true)


static func _make(skill: Skill, params: Dictionary, rng: RandomNumberGenerator, with_hints: bool) -> Problem:
	var mode: String = String(params.get("mode", "count"))
	var problem: Problem = GeneratorKit.new_problem(skill, params, GeneratorKit.pick_representation(skill, params))
	var model: Dictionary
	var example_line: Callable
	match mode:
		"count":
			model = _count(problem, skill, params, rng)
			example_line = _total_line_of
		"build":
			model = _build(problem, skill, params, rng)
			example_line = _shape_line_of
		_:
			push_error("ArraysGenerator: unknown mode '%s'" % mode)
			return problem
	if with_hints:
		var example: Problem = GeneratorKit.make_example(
			func(sub: RandomNumberGenerator) -> Problem: return _make(skill, params, sub, false), problem, rng)
		GeneratorKit.add_hints(problem, model, example, example_line.call(example))
	return problem


static func _total_line_of(example: Problem) -> Dictionary:
	var rows: int = example.visual["rows"]
	var cols: int = example.visual["cols"]
	return {"line_id": &"z3.hint.example_array_total", "params": {"rows": rows, "cols": cols, "total": example.answer}}


static func _shape_line_of(example: Problem) -> Dictionary:
	return {"line_id": &"z3.hint.example_array_shape", "params": {"rows": example.answer["rows"], "cols": example.answer["cols"]}}


static func _array(rows: int, cols: int, outline_rows: bool = false) -> Dictionary:
	var picture: Dictionary = {"type": "array", "rows": rows, "cols": cols}
	if outline_rows:
		picture["outline_rows"] = true
	return picture


## The largest side for this difficulty: `authored` at difficulty 0, smaller when easier.
static func _side_limit(authored: int, difficulty: int) -> int:
	return GeneratorKit.eased_max(MIN_SIDE, mini(authored, MAX_SIDE), difficulty, 1)


## How many gems are in this array? The answer is rows x cols.
static func _count(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var difficulty: int = GeneratorKit.difficulty_of(params)
	var rows: int = rng.randi_range(MIN_SIDE, _side_limit(int(params.get("max_rows", 5)), difficulty))
	var cols: int = rng.randi_range(MIN_SIDE, _side_limit(int(params.get("max_cols", 5)), difficulty))
	var total: int = rows * cols
	problem.prompt_line_id = &"z3.arr.prompt_count"
	problem.answer = total
	problem.visual = _array(rows, cols)
	GeneratorKit.add_distractor(problem, skill, rows + cols, &"rows_plus_cols")
	GeneratorKit.add_distractor(problem, skill, total - cols, &"off_by_row")
	GeneratorKit.add_distractor(problem, skill, total + cols, &"off_by_row")
	return _array(rows, cols, true)


## Build an array with {rows} rows and {cols} columns. The rows and columns always differ, so a
## swapped array is a real mistake. The builder is the skill's full size whatever the difficulty.
static func _build(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var difficulty: int = GeneratorKit.difficulty_of(params)
	var builder_rows: int = mini(int(params.get("max_rows", 5)), MAX_SIDE)
	var builder_cols: int = mini(int(params.get("max_cols", 5)), MAX_SIDE)
	var rows_limit: int = _side_limit(builder_rows, difficulty)
	var cols_limit: int = _side_limit(builder_cols, difficulty)
	var rows: int = rng.randi_range(MIN_SIDE, rows_limit)
	var cols: int
	if rows <= cols_limit:
		cols = rng.randi_range(MIN_SIDE, cols_limit - 1)
		if cols >= rows:
			cols += 1 # uniform over the column counts that are not `rows`
	else:
		cols = rng.randi_range(MIN_SIDE, cols_limit)
	problem.prompt_line_id = &"z3.arr.prompt_build"
	problem.prompt_params = {"rows": rows, "cols": cols}
	problem.answer = {"rows": rows, "cols": cols}
	problem.meta = {"array_builder": {"max_rows": builder_rows, "max_cols": builder_cols}}
	if cols <= builder_rows and rows <= builder_cols:
		GeneratorKit.add_distractor(problem, skill, {"rows": cols, "cols": rows}, &"rows_cols_swapped")
	return _array(rows, cols, true)
