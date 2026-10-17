## Skip-counting problems for Zone 3 (skills skip.*): fill in the two missing numbers of a strip of
## five numbers that counts by `step` (10, 5 or 2). The strip starts on a multiple of the step (so
## the number line's labels land on its numbers) and never runs past `max`. The blanks are never the
## first or last number. The answer is the two missing numbers in strip order, dragged from tiles.
##
## Pictorial strips are drawn as a number line. A concrete strip (counting by twos) is drawn as gems
## in pairs up to the strip's last number, so each number of the strip is the count after one more
## pair; the strip itself travels in meta.strip because that picture does not show it.
## Pure: only the passed-in rng is used.
class_name SkipCountGenerator
extends RefCounted

const LENGTH: int = 5
const BLANKS: int = 2
## The easiest strips still have this many places to start, so a worked example can differ.
const FLOOR_STARTS: int = 3
const MAX_TILES: int = 8
const PROMPTS: Dictionary[int, StringName] = {
	10: &"z3.skip.prompt_by_10",
	5: &"z3.skip.prompt_by_5",
	2: &"z3.skip.prompt_by_2",
}
## meta.picture for a concrete strip: the gems shown are the strip's last number, in pairs.
const PICTURE_PAIRS: String = "pairs_up_to_last"


static func generate(skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Problem:
	return _make(skill, params, rng, true)


static func _make(skill: Skill, params: Dictionary, rng: RandomNumberGenerator, with_hints: bool) -> Problem:
	var problem: Problem = GeneratorKit.new_problem(skill, params, GeneratorKit.pick_representation(skill, params))
	var step: int = int(params.get("step", 10))
	if not PROMPTS.has(step):
		push_error("SkipCountGenerator: no prompt for counting by %d" % step)
		return problem
	var model: Dictionary = _strip(problem, skill, params, step, rng)
	if with_hints:
		var example: Problem = GeneratorKit.make_example(
			func(sub: RandomNumberGenerator) -> Problem: return _make(skill, params, sub, false), problem, rng)
		var line: Dictionary = {"line_id": &"z3.hint.example_blanks", "params": {"a": example.answer[0], "b": example.answer[1]}}
		GeneratorKit.add_hints(problem, model, example, line)
	return problem


## Five numbers counting by `step`; two interior ones are blank. Returns the hint model: the same
## strip on a number line with the first blank filled in and a hop drawn for every step.
static func _strip(problem: Problem, skill: Skill, params: Dictionary, step: int, rng: RandomNumberGenerator) -> Dictionary:
	var high: int = int(params.get("max", 120))
	var floor_span: int = mini((LENGTH - 1 + FLOOR_STARTS) * step, high)
	var top: int = GeneratorKit.eased_max(0, high, GeneratorKit.difficulty_of(params), floor_span)
	# The first number is step * k for k = 1, 2, ...; the last, step * (k + 4), stays at or below top.
	var last_k: int = maxi(floori(top / float(step)) - (LENGTH - 1), 1)
	var start: int = rng.randi_range(1, last_k) * step
	var strip: Array[int] = []
	for index: int in LENGTH:
		strip.append(start + index * step)
	var interior: Array[int] = []
	for index: int in range(1, LENGTH - 1):
		interior.append(index)
	var chosen: Array[int] = GeneratorKit.shuffled_ints(interior, rng).slice(0, BLANKS)
	chosen.sort()
	var blanks: Array[int] = []
	for index: int in chosen:
		blanks.append(strip[index])
	var last: int = strip[LENGTH - 1]

	problem.prompt_line_id = PROMPTS[step]
	problem.answer = blanks.duplicate()
	problem.meta = {"strip": strip.duplicate()}
	if problem.representation == &"concrete" and step == 2:
		problem.visual = {"type": "pairs", "count": last, "show_pairs": true}
		problem.meta["picture"] = PICTURE_PAIRS
	else:
		problem.visual = GeneratorKit.number_line(start, last, step, [], blanks.duplicate())

	# Counting by ones from the number just before each blank (the child's own number when two
	# blanks sit side by side): 10, _, _, 40, 50 becomes 10, 11, 12, 40, 50.
	var by_ones: Array[int] = []
	var before: int = strip[0]
	for index: int in range(1, LENGTH):
		var value: int = strip[index]
		if chosen.has(index):
			value = before + 1
			by_ones.append(value)
		before = value
	GeneratorKit.add_distractor(problem, skill, by_ones, &"wrong_step")
	if step == 10:
		GeneratorKit.add_distractor(problem, skill, _decade_skip(blanks, rng), &"decade_skip")
	if step == 2:
		var shifted: Array[int] = []
		for value: int in blanks:
			shifted.append(value + 1)
		GeneratorKit.add_distractor(problem, skill, shifted, &"off_by_one")

	# The tiles: the answer plus every other number a distractor needs, each once, shuffled.
	var tiles: Array[int] = blanks.duplicate()
	for entry: Dictionary in problem.distractors:
		for value: int in entry["value"]:
			if not tiles.has(value):
				tiles.append(value)
	assert(tiles.size() <= MAX_TILES, "too many tiles for the board")
	problem.meta["tile_board"] = {"tiles": GeneratorKit.shuffled_ints(tiles, rng), "slots": BLANKS, "ordered": true}

	var model: Dictionary = GeneratorKit.number_line(start, last, step, [], blanks.slice(1))
	var jumps: Array[Dictionary] = []
	for index: int in range(LENGTH - 1):
		jumps.append({"from": strip[index], "to": strip[index + 1]})
	model["jumps"] = jumps
	return model


## One blank moved by a whole ten, up or down. A move that would make both blanks the same number
## is skipped, because the tile board has one tile per number.
static func _decade_skip(blanks: Array[int], rng: RandomNumberGenerator) -> Array[int]:
	var options: Array[Array] = []
	for which: int in blanks.size():
		for delta: int in [10, -10]:
			var moved: Array[int] = blanks.duplicate()
			moved[which] += delta
			if moved[which] > 0 and moved[0] != moved[1]:
				options.append(moved)
	var picked: Array[int] = []
	picked.assign(options[rng.randi_range(0, options.size() - 1)])
	return picked
