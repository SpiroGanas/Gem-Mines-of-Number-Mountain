## Invariants every generated problem must satisfy, shared by all generator suites.
##
## problem_errors() returns a list of plain-language violations (empty means the problem is
## sound), so a 10,000-problem loop makes one assertion at the end instead of thousands.
## The rules come from CLAUDE.md ("Problem generators") and the Phase 1 plan.
class_name GeneratorChecks
extends RefCounted

const ZONE1_SEEDS: int = 10000


## Problems for `skill`, seeds 1..count, cycling through the skill's representations.
static func make_all(skill: Skill, count: int, overrides: Dictionary = {}) -> Array[Problem]:
	var problems: Array[Problem] = []
	for seed: int in range(1, count + 1):
		var merged: Dictionary = overrides.duplicate()
		if not merged.has("representation"):
			merged["representation"] = skill.representations[seed % skill.representations.size()]
		problems.append(GeneratorRegistry.make_problem(skill, seed, merged))
	return problems


## Violations in one problem, each prefixed with the skill and seed so a failure is reproducible.
static func problem_errors(problem: Problem, skill: Skill, allowed_names: Array[StringName]) -> Array[String]:
	var errors: Array[String] = []
	var where: String = "%s seed %d (%s)" % [skill.id, problem.seed, problem.representation]
	if problem.skill_id != skill.id:
		errors.append("%s: wrong skill_id %s" % [where, problem.skill_id])
	if not skill.representations.has(problem.representation):
		errors.append("%s: representation not allowed for the skill" % where)
	if problem.answer_modes != skill.answer_modes:
		errors.append("%s: answer_modes differ from the skill" % where)
	errors.append_array(_prompt_errors(problem, where))
	errors.append_array(_distractor_errors(problem, skill, allowed_names, where))
	errors.append_array(_hint_errors(problem, where))
	errors.append_array(_visual_errors(problem.visual, where + " visual"))
	if not problem.is_correct(problem.answer):
		errors.append("%s: the answer is not accepted as correct" % where)
	for entry: Dictionary in problem.distractors:
		if problem.is_correct(entry["value"]):
			errors.append("%s: distractor %s is accepted as correct" % [where, entry["value"]])
	errors.append_array(_json_errors(problem, where))
	return errors


## Runs problem_errors over `count` problems and returns at most `limit` errors.
static func run(skill: Skill, count: int, allowed_names: Array[StringName], overrides: Dictionary = {}, limit: int = 8) -> Array[String]:
	var errors: Array[String] = []
	for problem: Problem in make_all(skill, count, overrides):
		errors.append_array(problem_errors(problem, skill, allowed_names))
		if errors.size() >= limit:
			break
	return errors


static func _prompt_errors(problem: Problem, where: String) -> Array[String]:
	var errors: Array[String] = []
	if not Text.has_line(problem.prompt_line_id):
		errors.append("%s: prompt line '%s' is not in the text table" % [where, problem.prompt_line_id])
		return errors
	for name: String in Text.required_params(problem.prompt_line_id):
		if not problem.prompt_params.has(name):
			errors.append("%s: prompt '%s' needs {%s}" % [where, problem.prompt_line_id, name])
	for key: Variant in problem.prompt_params:
		if not problem.prompt_params[key] is int:
			errors.append("%s: prompt param %s is not a whole number" % [where, key])
	return errors


static func _distractor_errors(problem: Problem, skill: Skill, allowed_names: Array[StringName], where: String) -> Array[String]:
	var errors: Array[String] = []
	var seen: Array = []
	for entry: Dictionary in problem.distractors:
		if not entry.has("value") or not entry.has("misconception"):
			errors.append("%s: malformed distractor %s" % [where, entry])
			continue
		var name: StringName = entry["misconception"]
		if not allowed_names.has(name):
			errors.append("%s: unknown misconception '%s'" % [where, name])
		if not skill.misconceptions.has(name):
			errors.append("%s: misconception '%s' is not listed for the skill" % [where, name])
		var canon: Variant = Problem.canonical(entry["value"])
		if canon == Problem.canonical(problem.answer):
			errors.append("%s: distractor equals the answer (%s)" % [where, canon])
		if seen.has(canon):
			errors.append("%s: duplicate distractor value %s" % [where, canon])
		seen.append(canon)
	if problem.answer_modes.has(&"tap") and problem.distractors.is_empty():
		errors.append("%s: a tap problem needs at least one distractor" % where)
	return errors


static func _hint_errors(problem: Problem, where: String) -> Array[String]:
	var errors: Array[String] = []
	if problem.hint_steps.size() != Problem.HINT_KINDS.size():
		errors.append("%s: needs %d hint rungs, has %d" % [where, Problem.HINT_KINDS.size(), problem.hint_steps.size()])
		return errors
	for rung: int in Problem.HINT_KINDS.size():
		var step: Dictionary = problem.hint_steps[rung]
		if step["kind"] != Problem.HINT_KINDS[rung]:
			errors.append("%s: rung %d should be %s" % [where, rung + 1, Problem.HINT_KINDS[rung]])
		if not Text.has_line(step["line_id"]):
			errors.append("%s: rung %d line '%s' is not in the text table" % [where, rung + 1, step["line_id"]])
	var model: Dictionary = problem.hint_steps[1]["visual"]
	if model.is_empty():
		errors.append("%s: rung 2 has no visual model" % where)
	errors.append_array(_visual_errors(model, where + " rung 2"))
	var example: Dictionary = problem.hint_steps[2]["example"]
	if not Text.has_line(example["prompt_line_id"]) or not Text.has_line(example["answer_line_id"]):
		errors.append("%s: rung 3 example lines are not in the text table" % where)
	else:
		for name: String in Text.required_params(example["answer_line_id"]):
			if not example["answer_params"].has(name):
				errors.append("%s: rung 3 answer line needs {%s}" % [where, name])
		for name: String in Text.required_params(example["prompt_line_id"]):
			if not example["prompt_params"].has(name):
				errors.append("%s: rung 3 prompt needs {%s}" % [where, name])
	if example["prompt_line_id"] == problem.prompt_line_id and example["prompt_params"] == problem.prompt_params and problem.hint_steps[2]["visual"] == problem.visual:
		errors.append("%s: the worked example is the same problem" % where)
	var easier: Dictionary = problem.hint_steps[3]["easier_params"]
	if easier.get("difficulty") != GeneratorKit.difficulty_of(problem.params) - 1:
		errors.append("%s: rung 4 must lower difficulty by one" % where)
	return errors


static func _visual_errors(visual: Dictionary, where: String) -> Array[String]:
	var errors: Array[String] = []
	if visual.is_empty():
		return errors
	var type: StringName = visual.get("type", &"")
	if not Problem.VISUAL_TYPES.has(type):
		errors.append("%s: unknown visual type '%s'" % [where, type])
		return errors
	match type:
		&"gem_piles":
			if visual["piles"].is_empty():
				errors.append("%s: no piles" % where)
			for pile: Dictionary in visual["piles"]:
				for key: String in ["hundreds", "tens", "ones"]:
					if not pile[key] is int or pile[key] < 0:
						errors.append("%s: pile %s must be a whole number of at least 0" % [where, key])
		&"ten_frame":
			if visual["count"] < 0 or visual["count"] > 10 * visual["frames"]:
				errors.append("%s: count %s does not fit %s frame(s)" % [where, visual["count"], visual["frames"]])
		&"number_line":
			if visual["min"] >= visual["max"]:
				errors.append("%s: line min must be below max" % where)
			for marker: int in visual["markers"]:
				if marker < visual["min"] or marker > visual["max"]:
					errors.append("%s: marker %d is off the line" % [where, marker])
			for blank: int in visual["blanks"]:
				if blank < visual["min"] or blank > visual["max"]:
					errors.append("%s: blank %d is off the line" % [where, blank])
			if visual["labeled_every"] < 1:
				errors.append("%s: labeled_every must be at least 1" % where)
	return errors


static func _json_errors(problem: Problem, where: String) -> Array[String]:
	var errors: Array[String] = []
	var parsed: Variant = JsonUtil.parse_text(JSON.stringify(problem.to_json()))
	if not parsed is Dictionary:
		errors.append("%s: to_json() did not survive a JSON round trip" % where)
		return errors
	if parsed["answer"] != Problem.canonical(problem.answer):
		errors.append("%s: answer changed in the JSON round trip" % where)
	if parsed["seed"] != problem.seed:
		errors.append("%s: seed changed in the JSON round trip" % where)
	for key: String in ["skill_id", "seed", "representation", "prompt_line_id", "prompt_params", "answer", "answer_modes", "distractors", "visual", "hint_steps", "params", "meta"]:
		if not parsed.has(key):
			errors.append("%s: to_json() lacks '%s'" % [where, key])
	return errors
