# Mirrors scripts/generators/proof_steps.gd, proof_builder.gd, number_sets.gd and mystery.gd (Zone 12, The Infinite Core).
# Written test-first. Primes are found here by trial division, never with the generators' own helpers, and every
# classification is spelled out from the card.
class_name InfiniteCoreGeneratorTest
extends GdUnitTestSuite

const N: int = 1200
const SKILLS: Array[StringName] = [
	&"proof.parts.identify", &"proof.order.chain", &"proof.justify.step", &"proof.euclid.infinite_primes",
	&"proof.contradiction.recognize", &"proof.sqrt2.irrational", &"sets.integer.classify", &"sets.rational.classify",
	&"sets.real.classify", &"mystery.goldbach.find_pair", &"mystery.twin.next_pair",
]
const TWIN_PAIRS_TO_230: Array[int] = [3, 5, 11, 17, 29, 41, 59, 71, 101, 107, 137, 149, 179, 191, 197, 227]

var _catalog: SkillCatalog
var _allowed: Array[StringName]


func before() -> void:
	_catalog = SkillCatalog.load_all()
	_allowed = SkillCatalog.misconception_names()


func _problems(skill_id: StringName, overrides: Dictionary = {}, count: int = N) -> Array[Problem]:
	return GeneratorChecks.make_all(_catalog.skill(skill_id), count, overrides)


func _prime(n: int) -> bool:
	if n < 2:
		return false
	for d: int in range(2, n):
		if d * d > n:
			break
		if n % d == 0:
			return false
	return true


func test_every_skill_passes_the_shared_checks() -> void:
	for skill_id: StringName in SKILLS:
		assert_array(GeneratorChecks.run(_catalog.skill(skill_id), N, _allowed)).override_failure_message(str(skill_id)).is_empty()
		assert_array(GeneratorChecks.run(_catalog.skill(skill_id), 400, _allowed, {"difficulty": -1})).override_failure_message(str(skill_id)).is_empty()
		assert_array(GeneratorChecks.run(_catalog.skill(skill_id), 200, _allowed, {"difficulty": -2})).override_failure_message(str(skill_id)).is_empty()


func test_the_same_seed_gives_the_same_problem() -> void:
	for skill_id: StringName in SKILLS:
		for seed: int in [1, 7, 99]:
			var first: Problem = GeneratorRegistry.make_problem(_catalog.skill(skill_id), seed)
			var second: Problem = GeneratorRegistry.make_problem(_catalog.skill(skill_id), seed)
			assert_str(JSON.stringify(first.to_json())).is_equal(JSON.stringify(second.to_json()))


func test_zone_12_has_its_eleven_skills_in_detail() -> void:
	assert_int(_catalog.skills_in_zone(12).size()).is_equal(11)
	for skill: Skill in _catalog.skills_in_zone(12):
		assert_bool(GeneratorRegistry.has_generator(skill.generator)).override_failure_message(String(skill.id)).is_true()


# --- Starter proofs ---------------------------------------------------------------------------------


func test_the_first_step_and_last_step_are_found_by_card_number() -> void:
	for problem: Problem in _problems(&"proof.parts.identify"):
		var cards: Array = problem.visual["cards"]
		var chain: Dictionary = _chain(problem.meta["chain"])
		var wanted_line: String = str(chain["steps"][0 if problem.meta["starts"] else chain["steps"].size() - 1]["line_id"])
		for card: Dictionary in cards:
			if int(card["n"]) == problem.answer:
				assert_str(str(card["line_id"])).is_equal(wanted_line)


func test_ordering_the_cards_by_the_answer_rebuilds_the_chain() -> void:
	for problem: Problem in _problems(&"proof.order.chain"):
		var chain: Dictionary = _chain(problem.meta["chain"])
		var by_number: Dictionary = {}
		for card: Dictionary in problem.visual["cards"]:
			by_number[int(card["n"])] = str(card["line_id"])
		for index: int in problem.answer.size():
			assert_str(by_number[problem.answer[index]]).is_equal(str(chain["steps"][index]["line_id"]))
		assert_array(problem.meta["tile_board"]["tiles"]).has_size(problem.answer.size())


func test_a_justification_matches_the_step_reason() -> void:
	for problem: Problem in _problems(&"proof.justify.step"):
		var chain: Dictionary = _chain(problem.meta["chain"])
		assert_str(str(problem.answer)).is_equal(str(chain["steps"][int(problem.prompt_params["k"]) - 1]["reason"]))


func test_exactly_one_step_clashes_with_the_first() -> void:
	for problem: Problem in _problems(&"proof.contradiction.recognize"):
		for entry: Dictionary in ProofStepsGenerator.data()["clashes"]:
			if entry["id"] == problem.meta["set"]:
				assert_int(problem.answer).is_equal(int(entry["clash"]))
		assert_bool(problem.distractors.size() >= 1).is_true()


func _chain(id: String) -> Dictionary:
	for entry: Dictionary in ProofStepsGenerator.data()["chains"]:
		if entry["id"] == id:
			return entry
	return {}


# --- Guided proofs -----------------------------------------------------------------------------------


func test_a_guided_proof_problem_is_the_proof_id() -> void:
	for problem: Problem in _problems(&"proof.euclid.infinite_primes", {}, 20):
		assert_str(str(problem.answer)).is_equal("proof.euclid.infinite_primes")
		assert_str(problem.meta["proof_builder"]["proof_id"]).is_equal("proof.euclid.infinite_primes")
		assert_array(problem.distractors).is_empty()
	for problem: Problem in _problems(&"proof.sqrt2.irrational", {}, 20):
		assert_str(str(problem.answer)).is_equal("proof.sqrt2.irrational")


# --- Number rings ---------------------------------------------------------------------------------------


func test_the_rings_of_the_plan_examples() -> void:
	assert_str(str(NumberSetsGenerator.ring_of({"form": "root", "a": 4}))).is_equal("integer")
	assert_str(str(NumberSetsGenerator.ring_of({"form": "decimal", "a": 75, "scale": 2}))).is_equal("rational")
	assert_str(str(NumberSetsGenerator.ring_of({"form": "root", "a": 2}))).is_equal("real")
	assert_str(str(NumberSetsGenerator.ring_of({"form": "int", "a": -3}))).is_equal("integer")
	assert_str(str(NumberSetsGenerator.ring_of({"form": "frac", "a": 1, "b": 3}))).is_equal("rational")


func test_every_card_is_classified_by_its_value() -> void:
	for problem: Problem in _problems(&"sets.real.classify"):
		var card: Dictionary = problem.visual
		var whole: bool = false
		match card["form"]:
			"int":
				whole = true
			"frac":
				whole = card["a"] % card["b"] == 0
			"decimal":
				whole = card["a"] % int(pow(10, card["scale"])) == 0
			"root":
				var root: int = roundi(sqrt(float(card["a"])))
				whole = root * root == card["a"]
		var rational: bool = card["form"] != "root" or whole
		var expected: String = "integer" if whole else ("rational" if rational else "real")
		assert_str(str(problem.answer)).is_equal(expected)
		assert_bool(card["form"] == "frac" and card["a"] % card["b"] == 0).is_false() # never ambiguous


func test_yes_no_ring_questions_have_both_answers() -> void:
	for skill_id: StringName in [&"sets.integer.classify", &"sets.rational.classify"]:
		var yes: int = 0
		for problem: Problem in _problems(skill_id, {}, 300):
			yes += 1 if problem.answer else 0
		assert_bool(yes > 60 and yes < 240).override_failure_message(str(skill_id)).is_true()


# --- Mysteries ---------------------------------------------------------------------------------------------


func test_every_even_number_to_100_has_a_goldbach_pair() -> void:
	for n: int in range(4, 101, 2):
		var pairs: Array[Vector2i] = MysteryGenerator.goldbach_pairs(n)
		assert_bool(pairs.size() >= 1).override_failure_message(str(n)).is_true()
		for pair: Vector2i in pairs:
			assert_bool(_prime(pair.x) and _prime(pair.y) and pair.x + pair.y == n and pair.x <= pair.y).is_true()


func test_goldbach_answers_and_wrong_answers() -> void:
	for problem: Problem in _problems(&"mystery.goldbach.find_pair"):
		var n: int = problem.prompt_params["n"]
		var parts: PackedStringArray = str(problem.answer).split(" + ")
		assert_bool(_prime(int(parts[0])) and _prime(int(parts[1])) and int(parts[0]) + int(parts[1]) == n).is_true()
		for entry: Dictionary in problem.distractors:
			var wrong: PackedStringArray = str(entry["value"]).split(" + ")
			assert_bool(_prime(int(wrong[0])) and _prime(int(wrong[1])) and int(wrong[0]) + int(wrong[1]) == n).is_false()
		assert_bool(problem.distractors.size() >= 2).is_true()


func test_the_next_twin_pair_matches_a_reference_list() -> void:
	for p: int in range(2, 191):
		var expected: int = 0
		for q: int in TWIN_PAIRS_TO_230:
			if q > p:
				expected = q
				break
		assert_int(MysteryGenerator.next_twin(p)).override_failure_message(str(p)).is_equal(expected)
	for problem: Problem in _problems(&"mystery.twin.next_pair"):
		assert_int(problem.answer).is_equal(MysteryGenerator.next_twin(problem.prompt_params["p"]))
		assert_bool(_prime(problem.answer) and _prime(problem.answer + 2)).is_true()
		# Peer review 05: the larger twin is always a named wrong answer (it used to be dropped when the cousin prime matched it).
		var names: Array[String] = []
		for wrong: Dictionary in problem.distractors:
			names.append(str(wrong["misconception"]))
		assert_array(names).contains([&"gave_larger_prime"])
		assert_str(str(problem.distractors[0]["misconception"])).is_equal("gave_larger_prime")
		assert_int(int(problem.distractors[0]["value"])).is_equal(int(problem.answer) + 2)
		# and a pictorial problem carries a number line that marks only the start (the rung 2 model adds the pair)
		assert_str(str(problem.visual.get("type", ""))).is_equal("number_line")
		assert_array(problem.visual["markers"]).contains_exactly([problem.prompt_params["p"]])
		assert_array(problem.hint_steps[1]["visual"]["markers"]).contains_exactly([problem.prompt_params["p"], problem.answer, int(problem.answer) + 2])
	var after_ten: Problem = GeneratorChecks.make_all(_catalog.skill(&"mystery.twin.next_pair"), 1, {"min_p": 10, "max_p": 10})[0]
	assert_int(after_ten.answer).is_equal(11)
	assert_int(int(after_ten.distractors[0]["value"])).is_equal(13) # the larger twin, which is also the first cousin prime
	for problem: Problem in _problems(&"mystery.goldbach.find_pair"):
		assert_str(str(problem.visual.get("type", ""))).is_equal("number_line")
		assert_array(problem.visual["markers"]).contains_exactly([problem.prompt_params["n"]])
