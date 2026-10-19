# Mirrors scripts/generators/fibonacci.gd, proof.gd and fib_poem.gd (Zone 9 fib.*, proof.words.match and
# fib.poem.syllables): Fibonacci numbers are rebuilt here by adding pairs, ratios are rounded half up with
# integers, proof answers are diagrams on file, and poem lines add up to their syllable goal.
class_name FibonacciProofPoemGeneratorTest
extends GdUnitTestSuite

const N: int = 2000
const SKILLS: Array[StringName] = [
	&"fib.sequence.next_term", &"fib.sequence.missing_term", &"fib.ratio.converge",
	&"proof.words.match", &"fib.poem.syllables",
]
## F(1) to F(16), written out by hand.
const FIBONACCI: Array[int] = [1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89, 144, 233, 377, 610, 987]

var _catalog: SkillCatalog
var _allowed: Array[StringName]


func before() -> void:
	_catalog = SkillCatalog.load_all()
	_allowed = SkillCatalog.misconception_names()


func _problems(skill_id: StringName, count: int = N, overrides: Dictionary = {}) -> Array[Problem]:
	return GeneratorChecks.make_all(_catalog.skill(skill_id), count, overrides)


func _named(problem: Problem, name: StringName) -> Array:
	var values: Array = []
	for entry: Dictionary in problem.distractors:
		if entry["misconception"] == name:
			values.append(entry["value"])
	return values


func test_every_skill_passes_the_shared_checks() -> void:
	for skill_id: StringName in SKILLS:
		assert_array(GeneratorChecks.run(_catalog.skill(skill_id), N, _allowed)).override_failure_message(str(skill_id)).is_empty()
		assert_array(GeneratorChecks.run(_catalog.skill(skill_id), 300, _allowed, {"difficulty": -1})).override_failure_message(str(skill_id) + " easier").is_empty()


func test_fibonacci_numbers_are_the_known_ones() -> void:
	for index: int in range(1, 17):
		assert_int(FibGenerator.fib(index)).is_equal(FIBONACCI[index - 1])


func test_the_next_fibonacci_number_adds_the_last_two() -> void:
	for problem: Problem in _problems(&"fib.sequence.next_term"):
		var p: Dictionary = problem.prompt_params
		var start: int = FIBONACCI.find(int(p["a"]))
		assert_int(start).is_not_equal(-1)
		assert_int(int(p["c"]) + int(p["d"])).is_equal(problem.answer)
		assert_bool(FIBONACCI.slice(0, 15).has(problem.answer)).is_true() # never past F(15)
		assert_array(_named(problem, &"doubled_last")).contains_exactly([2 * int(p["d"])])
		assert_array(_named(problem, &"added_wrong_pair")).contains_exactly([int(p["b"]) + int(p["d"])])
		assert_bool(problem.meta.has("pattern_wall")).is_equal(problem.representation == &"concrete")


func test_a_missing_fibonacci_number_fits_both_neighbors() -> void:
	for problem: Problem in _problems(&"fib.sequence.missing_term"):
		var p: Dictionary = problem.prompt_params
		var row: Array = []
		for key: String in ["a", "b", "c", "d", "e"]:
			row.append(p[key] if p.has(key) else problem.answer)
		for index: int in range(2, 5):
			assert_int(int(row[index])).is_equal(int(row[index - 1]) + int(row[index - 2]))


func test_ratios_are_rounded_half_up_to_hundredths_with_whole_numbers() -> void:
	for problem: Problem in _problems(&"fib.ratio.converge"):
		var a: int = problem.prompt_params["a"]
		var b: int = problem.prompt_params["b"]
		assert_int(FIBONACCI.find(b) - FIBONACCI.find(a)).is_equal(1)
		# hundredths h is right when |100 b - h a| <= a / 2, with a tie rounding up
		var hundredths: int = int(problem.answer["mantissa"]) * Rational.pow10(2 - int(problem.answer["scale"]))
		var gap: int = 100 * b - hundredths * a
		assert_bool(2 * gap < a and 2 * gap >= -a).override_failure_message("%d/%d -> %s" % [b, a, problem.answer]).is_true()
		assert_int(int(problem.meta["decimal_places"])).is_equal(2)
	# 13 / 8 = 1.625 exactly: half up gives 1.63 (a banker's rounding would give 1.62)
	var tie: Dictionary = Rational.round_decimal(13, 8, 2)
	assert_dict(tie).is_equal({"mantissa": 163, "scale": 2})


func test_proof_answers_are_diagrams_on_file_with_fact_lines() -> void:
	var data: Dictionary = JsonUtil.parse_file(ProofGenerator.PATH)
	var ids: Array = []
	for entry: Dictionary in data["diagrams"]:
		ids.append(entry["id"])
		assert_bool(Problem.PROOF_DIAGRAMS.has(str(entry["id"]))).override_failure_message("PatternArt cannot draw " + str(entry["id"])).is_true()
		assert_bool(Text.has_line(StringName(str(entry["label_line_id"])))).is_true()
	var seen: Dictionary = {}
	for problem: Problem in _problems(&"proof.words.match"):
		assert_bool(ids.has(problem.answer)).is_true()
		seen[problem.answer] = true
		assert_int(problem.distractors.size()).is_equal(3)
		for value: Variant in problem.distractor_values():
			assert_bool(ids.has(value)).is_true()
		assert_str(str(problem.meta["proof_board"]["diagram"])).is_equal(str(problem.answer))
	assert_int(seen.size()).is_equal(ids.size())


func test_poem_lines_add_up_to_their_goal() -> void:
	var lines: Dictionary = {}
	for problem: Problem in _problems(&"fib.poem.syllables"):
		var k: int = problem.prompt_params["k"]
		var n: int = problem.prompt_params["n"]
		lines[k] = true
		assert_int(n).is_equal([1, 1, 2, 3, 5, 8][k - 1])
		assert_int(PoemWords.line_syllables(problem.answer)).is_equal(n)
		assert_int(problem.answer.size()).is_between(1, FibPoemGenerator.MAX_WORDS)
		assert_int(problem.distractors.size()).is_greater_equal(2)
		for entry: Dictionary in problem.distractors:
			var words: Array = entry["value"]
			var total: int = PoemWords.line_syllables(words)
			assert_int(total).is_not_equal(n)
			for word: Variant in words:
				assert_bool(PoemWords.has_word(str(word))).is_true()
			match entry["misconception"]:
				&"counted_words":
					assert_int(words.size()).is_equal(n)
				&"off_by_one_syllable":
					assert_int(absi(total - n)).is_equal(1)
				&"wrong_line_count":
					assert_bool([1, 2, 3, 5, 8].has(total)).is_true()
		assert_str(str(problem.meta["array_label"])).is_equal("words")
	assert_int(lines.size()).is_equal(6)


func test_the_word_bank_is_sound() -> void:
	var ids: Array[String] = PoemWords.ids()
	assert_int(ids.size()).is_greater_equal(140)
	for id: String in ids:
		assert_int(PoemWords.syllables(id)).is_between(1, FibPoemGenerator.MAX_WORD_SYLLABLES)
		assert_bool(Text.has_line(PoemWords.line_id(id))).override_failure_message(id).is_true()
	for size: int in range(1, FibPoemGenerator.MAX_WORD_SYLLABLES + 1):
		assert_int(PoemWords.with_syllables(size).size()).is_greater_equal(8)
