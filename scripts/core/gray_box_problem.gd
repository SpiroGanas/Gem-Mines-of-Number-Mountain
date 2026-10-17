## Sprint 4 stand-in for the generator framework: ONE hard-coded problem type,
## pv.tens_ones.build ("build this number with ten-bars and one-gems").
## Sprint 5 replaces this with the real Problem class and the generator registry; delete this
## file then. Pure, and uses only the rng it is given, so a seed gives the same problem.
class_name GrayBoxProblem
extends RefCounted

const SKILL_ID: StringName = &"pv.tens_ones.build"
const PROMPT_LINE_ID: StringName = &"z1.dig.prompt_build_number"


## {skill_id, prompt_line_id, prompt_params: {n}, answer: {tens, ones}} for a number from 11 to 99.
static func build_number(rng: RandomNumberGenerator) -> Dictionary:
	var tens: int = rng.randi_range(1, 9)
	var ones: int = rng.randi_range(0, 9)
	if tens == 1 and ones == 0:
		ones = 1 # 10 is a single bar; keep the gray-box problems at 11 or more
	return {
		"skill_id": SKILL_ID,
		"prompt_line_id": PROMPT_LINE_ID,
		"prompt_params": {"n": tens * 10 + ones},
		"answer": {"tens": tens, "ones": ones},
	}


static func is_correct(problem: Dictionary, given: Dictionary) -> bool:
	var answer: Dictionary = problem["answer"]
	return given.get("tens", -1) == answer["tens"] and given.get("ones", -1) == answer["ones"]
