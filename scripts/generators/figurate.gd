## Figurate numbers for Zone 9, Pattern Grotto (skills fig.*): gems stacked into triangles and squares.
## params.mode picks the question:
##   triangular     how many gems in triangle n (rows of 1, 2, ..., n)? T(n) = n × (n + 1) / 2.
##                  Concrete: the pattern wall of triangles before it, with triangle n's gap
##                  (meta.pattern_wall); pictorial: the triangle's picture and the number pad.
##   square         how many gems in square n? n × n. Concrete only: the pattern wall of squares.
##   two_triangles  the staircases of n rows and n - 1 rows fit into an n by n square (proof without
##                  words): how many gems? n × n, from the picture.
## n runs from 2 to params.max_n (eased by difficulty). Pure: only the passed-in rng is used.
##
## The named mistakes:
##   used_square                          gave n × n for a triangle;
##   used_triangular                      gave T(n) for a square;
##   off_by_one_n                         used n - 1 or n + 1 rows;
##   added_same_triangular_twice_wrong_n  doubled the n-row staircase (n × (n + 1)) instead of fitting the
##                                        shorter one beside it.
class_name FigurateGenerator
extends RefCounted

## The pattern wall shows at most this many figures before the gap.
const WALL_SHOWN: int = 4


static func generate(skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Problem:
	return _make(skill, params, rng, true)


static func _make(skill: Skill, params: Dictionary, rng: RandomNumberGenerator, with_hints: bool) -> Problem:
	var problem: Problem = GeneratorKit.new_problem(skill, params, GeneratorKit.pick_representation(skill, params))
	# A pattern wall shows at least two figures before the gap, so a concrete n starts at 3.
	var low: int = 3 if problem.representation == &"concrete" else 2
	var n: int = rng.randi_range(low, GeneratorKit.eased_max(low, int(params.get("max_n", 12)), GeneratorKit.difficulty_of(params), 3))
	var model: Dictionary = {}
	var example_line: Callable
	match str(params.get("mode", "triangular")):
		"square":
			model = _square(problem, skill, n)
			example_line = _square_line
		"two_triangles":
			model = _two_triangles(problem, skill, n)
			example_line = _two_triangles_line
		_:
			model = _triangular(problem, skill, n)
			example_line = _triangle_line
	if with_hints:
		var example: Problem = GeneratorKit.make_example(
			func(sub: RandomNumberGenerator) -> Problem: return _make(skill, params, sub, false), problem, rng)
		GeneratorKit.add_hints(problem, model, example, example_line.call(example))
	return problem


static func triangular(n: int) -> int:
	return floori(n * (n + 1) / 2.0)


## A `figurate` picture: gems in a triangle (rows 1..n), a square (n rows of n), or two staircases
## (n rows and n - 1 rows, two colors) fitted into an n by n square.
static func figure(kind: String, n: int) -> Dictionary:
	return {"type": "figurate", "kind": kind, "n": n}


## The figure numbers before n on the pattern wall (up to WALL_SHOWN of them), then n's gap.
static func wall_indices(n: int) -> Array[int]:
	var indices: Array[int] = []
	for index: int in range(maxi(1, n - WALL_SHOWN), n + 1):
		indices.append(index)
	return indices


## The wall's picture and meta.pattern_wall: the values of `indices` with the last one blank. `value_of`
## turns an index into its figurate number.
static func _wall(problem: Problem, indices: Array[int], value_of: Callable, figure_kind: String) -> void:
	var terms: Array[int] = []
	for index: int in indices:
		terms.append(int(value_of.call(index)))
	var picture: Dictionary = SequenceGenerator.pattern(terms, [terms.size() - 1], "crystals")
	picture["figure"] = figure_kind
	picture["first_index"] = indices[0]
	problem.visual = picture
	SequenceGenerator.add_wall(problem, terms, terms.size() - 1)


static func _triangular(problem: Problem, skill: Skill, n: int) -> Dictionary:
	problem.prompt_params = {"n": n}
	problem.answer = triangular(n)
	GeneratorKit.add_distractor(problem, skill, n * n, &"used_square")
	GeneratorKit.add_distractor(problem, skill, triangular(n - 1), &"off_by_one_n")
	GeneratorKit.add_distractor(problem, skill, triangular(n + 1), &"off_by_one_n")
	if problem.representation == &"concrete":
		problem.prompt_line_id = &"z9.fig.prompt_triangle_wall"
		_wall(problem, wall_indices(n), FigurateGenerator.triangular, "triangle")
	else:
		problem.prompt_line_id = &"z9.fig.prompt_triangle"
		problem.visual = figure("triangle", n)
	return figure("triangle", n)


static func _triangle_line(example: Problem) -> Dictionary:
	var n: int = example.prompt_params["n"]
	return {"line_id": &"z9.hint.example_triangle", "params": {"n": n, "t": example.answer}}


static func _square(problem: Problem, skill: Skill, n: int) -> Dictionary:
	problem.prompt_params = {"n": n}
	problem.answer = n * n
	GeneratorKit.add_distractor(problem, skill, triangular(n), &"used_triangular")
	GeneratorKit.add_distractor(problem, skill, (n - 1) * (n - 1), &"off_by_one_n")
	GeneratorKit.add_distractor(problem, skill, (n + 1) * (n + 1), &"off_by_one_n")
	problem.prompt_line_id = &"z9.fig.prompt_square_wall"
	_wall(problem, wall_indices(n), func(index: int) -> int: return index * index, "square")
	return figure("square", n)


static func _square_line(example: Problem) -> Dictionary:
	var n: int = example.prompt_params["n"]
	return {"line_id": &"z9.hint.example_square", "params": {"n": n, "t": example.answer}}


static func _two_triangles(problem: Problem, skill: Skill, n: int) -> Dictionary:
	problem.prompt_line_id = &"z9.fig.prompt_two_triangles"
	problem.prompt_params = {"n": n, "m": n - 1}
	problem.answer = n * n
	GeneratorKit.add_distractor(problem, skill, n * (n + 1), &"added_same_triangular_twice_wrong_n")
	GeneratorKit.add_distractor(problem, skill, triangular(n), &"used_triangular")
	GeneratorKit.add_distractor(problem, skill, (n - 1) * (n - 1), &"off_by_one_n")
	var apart: Dictionary = figure("two_triangles", n)
	apart["fitted"] = false
	problem.visual = apart
	var fitted: Dictionary = figure("two_triangles", n)
	fitted["fitted"] = true
	return fitted


static func _two_triangles_line(example: Problem) -> Dictionary:
	var p: Dictionary = example.prompt_params
	return {"line_id": &"z9.hint.example_two_triangles", "params": {"n": p["n"], "m": p["m"], "t": example.answer}}
