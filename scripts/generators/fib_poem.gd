## Fib poem syllables for Zone 9, Pattern Grotto (skill fib.poem.syllables). A Fib poem has six lines
## whose syllables follow the Fibonacci numbers (params.lines: 1, 1, 2, 3, 5, 8). The problem names a
## line and its count and shows up to four lines of word tiles; the child taps the line that fits. The
## answer is that line, an Array of word ids from curriculum/poem_words.json (PoemWords); its button
## reads the words (meta.array_label "words"). Syllable counts are data counted by a person: this
## generator only adds them up. Every line has at most MAX_WORDS words so a button stays short.
## Pure: only the passed-in rng is used (the word bank is read from its file).
##
## The named mistakes:
##   wrong_line_count     a line with the count of another line of the poem;
##   counted_words        as many words as the count, but more syllables (counts of 3 or less);
##   off_by_one_syllable  one syllable more or one less.
class_name FibPoemGenerator
extends RefCounted

const DEFAULT_LINES: Array[int] = [1, 1, 2, 3, 5, 8]
const MAX_WORDS: int = 4
## The longest word in the bank (syllables).
const MAX_WORD_SYLLABLES: int = 4


static func generate(skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Problem:
	return _make(skill, params, rng, true)


static func targets_of(params: Dictionary) -> Array[int]:
	var targets: Array[int] = []
	for count: Variant in params.get("lines", DEFAULT_LINES):
		targets.append(int(count))
	return targets


static func _make(skill: Skill, params: Dictionary, rng: RandomNumberGenerator, with_hints: bool) -> Problem:
	var problem: Problem = GeneratorKit.new_problem(skill, params, GeneratorKit.pick_representation(skill, params))
	var targets: Array[int] = targets_of(params)
	# Easier problems ask about the short lines only (the first four).
	var last_line: int = targets.size() if GeneratorKit.difficulty_of(params) >= 0 else mini(4, targets.size())
	var line: int = rng.randi_range(1, last_line)
	var count: int = targets[line - 1]
	problem.prompt_line_id = &"z9.poem.prompt_single" if count == 1 else &"z9.poem.prompt"
	problem.prompt_params = {"k": line, "n": count}
	problem.answer = make_line(count, rng)
	problem.meta = {"array_label": "words"}
	var other: int = _other_count(targets, count, rng)
	GeneratorKit.add_distractor(problem, skill, make_line(other, rng), &"wrong_line_count")
	if count <= 3:
		GeneratorKit.add_distractor(problem, skill, _counted_words_line(count, rng), &"counted_words")
	GeneratorKit.add_distractor(problem, skill, make_line(count + 1, rng), &"off_by_one_syllable")
	if count > 1 and problem.distractors.size() < 3:
		GeneratorKit.add_distractor(problem, skill, make_line(count - 1, rng), &"off_by_one_syllable")
	problem.visual = poem_shape(targets, line - 1, false)
	if with_hints:
		var example: Problem = GeneratorKit.make_example(
			func(sub: RandomNumberGenerator) -> Problem: return _make(skill, params, sub, false), problem, rng)
		var p: Dictionary = example.prompt_params
		var example_line: StringName = &"z9.hint.example_poem_single" if int(p["n"]) == 1 else &"z9.hint.example_poem"
		GeneratorKit.add_hints(problem, poem_shape(targets, line - 1, true), example, {"line_id": example_line, "params": {"k": p["k"], "n": p["n"]}})
	return problem


## A `poem_shape` picture: one row of beat dots per line (`lines` counts), line `highlight` lit, and the
## counts written beside the rows when `counts` is true.
static func poem_shape(lines: Array[int], highlight: int, counts: bool) -> Dictionary:
	return {"type": "poem_shape", "lines": lines.duplicate(), "highlight": highlight, "counts": counts}


## A line of 1 to MAX_WORDS different words whose stored syllables add up to `count` (1 to 16).
static func make_line(count: int, rng: RandomNumberGenerator) -> Array[String]:
	var words: Array[String] = []
	var left: int = count
	var slots: int = MAX_WORDS
	while left > 0:
		# A size that leaves a remainder the other slots can still hold.
		var sizes: Array[int] = []
		for size: int in range(1, mini(MAX_WORD_SYLLABLES, left) + 1):
			if left - size <= MAX_WORD_SYLLABLES * (slots - 1):
				sizes.append(size)
		var size_now: int = sizes[rng.randi_range(0, sizes.size() - 1)]
		var pool: Array[String] = []
		for id: String in PoemWords.with_syllables(size_now):
			if not words.has(id):
				pool.append(id)
		words.append(pool[rng.randi_range(0, pool.size() - 1)])
		left -= size_now
		slots -= 1
	return words


## Another line's count of the same poem, different from `count` (a neighbor when the poem has one).
static func _other_count(targets: Array[int], count: int, rng: RandomNumberGenerator) -> int:
	var others: Array[int] = []
	for target: int in targets:
		if target != count and not others.has(target):
			others.append(target)
	return others[rng.randi_range(0, others.size() - 1)] if not others.is_empty() else count + 1


## `count` words (one per syllable a child who counts words expects) with one two-syllable word among
## them, so the line really has count + 1 syllables.
static func _counted_words_line(count: int, rng: RandomNumberGenerator) -> Array[String]:
	var words: Array[String] = []
	var long_at: int = rng.randi_range(0, count - 1)
	for index: int in count:
		var pool: Array[String] = []
		for id: String in PoemWords.with_syllables(2 if index == long_at else 1):
			if not words.has(id):
				pool.append(id)
		words.append(pool[rng.randi_range(0, pool.size() - 1)])
	return words
