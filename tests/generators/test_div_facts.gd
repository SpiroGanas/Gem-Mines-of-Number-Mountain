# Mirrors scripts/generators/div_facts.gd: every division is exact (the answer times the divisor is the
# number shared), the divisors and quotients stay in the skill's ranges, and each wrong answer is
# multiplied_instead (n x b) or off_by_one.
class_name DivFactsGeneratorTest
extends GdUnitTestSuite

const N: int = 2000
const SKILLS: Array[StringName] = [&"div.sharing.equal_shares", &"div.facts.by_2_5", &"div.facts.by_6_10"]

var _catalog: SkillCatalog
var _allowed: Array[StringName]


func before() -> void:
	_catalog = SkillCatalog.load_all()
	_allowed = SkillCatalog.misconception_names()


func _problems(skill_id: StringName, overrides: Dictionary = {}, count: int = N) -> Array[Problem]:
	return GeneratorChecks.make_all(_catalog.skill(skill_id), count, overrides)


## Equal shares by dealing one gem at a time into b carts: how many gems does each cart get?
func _deal(total: int, carts: int) -> int:
	var hands: Array[int] = []
	hands.resize(carts)
	hands.fill(0)
	for gem: int in total:
		hands[gem % carts] += 1
	assert_array(hands).override_failure_message("%d does not share into %d equal carts" % [total, carts]).is_equal(_all_the_same(hands))
	return hands[0]


func _all_the_same(hands: Array[int]) -> Array[int]:
	var same: Array[int] = []
	same.resize(hands.size())
	same.fill(hands[0])
	return same


func test_every_skill_passes_the_shared_checks() -> void:
	for skill_id: StringName in SKILLS:
		var skill: Skill = _catalog.skill(skill_id)
		assert_object(skill).is_not_null()
		var errors: Array[String] = GeneratorChecks.run(skill, 10000, _allowed)
		assert_array(errors).override_failure_message("\n".join(errors)).is_empty()


func test_division_is_exact_and_the_answer_is_what_each_cart_gets() -> void:
	for skill_id: StringName in SKILLS:
		for problem: Problem in _problems(skill_id):
			var total: int = problem.prompt_params["n"]
			var carts: int = problem.prompt_params["b"]
			assert_int(problem.answer).override_failure_message("%s seed %d: %d / %d" % [skill_id, problem.seed, total, carts]).is_equal(_deal(total, carts))


func test_divisors_and_quotients_stay_in_the_skills_ranges() -> void:
	var ranges: Dictionary = {
		&"div.sharing.equal_shares": [2, 5, 2, 5],
		&"div.facts.by_2_5": [2, 5, 2, 10],
		&"div.facts.by_6_10": [6, 10, 2, 10],
	}
	for skill_id: StringName in ranges:
		var seen_divisors: Dictionary = {}
		var seen_quotients: Dictionary = {}
		for problem: Problem in _problems(skill_id):
			var bounds: Array = ranges[skill_id]
			var divisor: int = problem.prompt_params["b"]
			assert_int(divisor).is_between(bounds[0], bounds[1])
			assert_int(problem.answer).is_between(bounds[2], bounds[3])
			seen_divisors[divisor] = true
			seen_quotients[problem.answer] = true
		assert_int(seen_divisors.size()).override_failure_message(String(skill_id)).is_equal(ranges[skill_id][1] - ranges[skill_id][0] + 1)
		assert_int(seen_quotients.size()).override_failure_message(String(skill_id)).is_equal(ranges[skill_id][3] - ranges[skill_id][2] + 1)


func test_the_prompt_and_picture_match_the_representation() -> void:
	for problem: Problem in _problems(&"div.facts.by_2_5"):
		var total: int = problem.prompt_params["n"]
		var carts: int = problem.prompt_params["b"]
		match problem.representation:
			&"concrete":
				assert_str(problem.prompt_line_id).is_equal("z4.div.prompt_share")
				var pile: Dictionary = problem.visual["piles"][0]
				assert_int(pile["hundreds"] * 100 + pile["tens"] * 10 + pile["ones"]).is_equal(total)
				if total <= 30:
					assert_int(pile["ones"]).is_equal(total) # small piles are drawn as single gems
			&"pictorial":
				assert_str(problem.prompt_line_id).is_equal("z4.div.prompt_fact")
				assert_dict(problem.visual).is_equal({"type": "number_line", "min": 0, "max": total, "labeled_every": carts, "markers": [total], "blanks": []})
			&"abstract":
				assert_str(problem.prompt_line_id).is_equal("z4.div.prompt_fact")
				assert_dict(problem.visual).is_empty()
	for problem: Problem in _problems(&"div.sharing.equal_shares"):
		assert_str(problem.prompt_line_id).is_equal("z4.div.prompt_share")
		assert_int(problem.prompt_params["n"]).is_less_equal(25)


func test_wrong_answers_are_the_named_mistakes() -> void:
	for skill_id: StringName in SKILLS:
		for problem: Problem in _problems(skill_id):
			var total: int = problem.prompt_params["n"]
			var carts: int = problem.prompt_params["b"]
			var quotient: int = problem.answer
			assert_array(problem.distractors).is_not_empty()
			var kinds: Dictionary = {}
			for entry: Dictionary in problem.distractors:
				var value: int = entry["value"]
				var where: String = "%s seed %d: %d / %d, %s" % [skill_id, problem.seed, total, carts, entry]
				kinds[entry["misconception"]] = true
				match String(entry["misconception"]):
					"multiplied_instead":
						assert_int(value).override_failure_message(where).is_equal(total * carts)
						assert_int(value).is_less_equal(999)
					"off_by_one":
						assert_bool(value == quotient + 1 or value == quotient - 1).override_failure_message(where).is_true()
					_:
						fail("unexpected misconception in " + where)
			assert_bool(kinds.has("off_by_one")).is_true()
			if total * carts <= 999:
				assert_bool(kinds.has("multiplied_instead")).is_true()


func test_the_hint_picture_shows_equal_carts_and_the_example_states_its_quotient() -> void:
	for problem: Problem in _problems(&"div.facts.by_6_10"):
		assert_dict(problem.hint_steps[1]["visual"]).is_equal({"type": "groups", "groups": problem.prompt_params["b"], "size": problem.answer})
		var example: Dictionary = problem.hint_steps[2]["example"]
		assert_str(example["answer_line_id"]).is_equal("z4.hint.example_div")
		assert_dict(example["answer_params"]).is_equal({"n": example["prompt_params"]["n"], "b": example["prompt_params"]["b"], "q": example["answer"]})
		assert_int(example["answer"] * example["prompt_params"]["b"]).is_equal(example["prompt_params"]["n"])


func test_easier_difficulty_lowers_the_quotient() -> void:
	var biggest: int = 0
	for problem: Problem in _problems(&"div.facts.by_2_5", {"difficulty": -2}, 1500):
		biggest = maxi(biggest, problem.answer)
	assert_int(biggest).is_less(10)
	assert_int(biggest).is_greater_equal(3)


func test_the_easiest_problems_still_pass_the_shared_checks() -> void:
	for skill_id: StringName in SKILLS:
		var errors: Array[String] = GeneratorChecks.run(_catalog.skill(skill_id), 500, _allowed, {"difficulty": -8})
		assert_array(errors).override_failure_message("\n".join(errors)).is_empty()


func test_the_same_seed_gives_the_same_problem_and_the_global_rng_is_untouched() -> void:
	var skill: Skill = _catalog.skill(&"div.facts.by_6_10")
	for seed: int in range(1, 200):
		assert_dict(GeneratorRegistry.make_problem(skill, seed).to_json()).is_equal(GeneratorRegistry.make_problem(skill, seed).to_json())
	seed(777)
	var expected: int = randi()
	seed(777)
	_problems(&"div.facts.by_6_10", {}, 300)
	assert_int(randi()).is_equal(expected)
