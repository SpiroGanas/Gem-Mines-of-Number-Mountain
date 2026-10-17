## One generated problem: what is asked, the right answer, named wrong answers and the hints.
##
## Problems are plain data (no nodes) so generators stay pure and testable, and so
## to_json() can hand the exact same facts to the independent Python cross-checker.
##
## Answers use one canonical shape per kind of question:
##   int                        a count or a number
##   StringName                 a choice such as &"<", &">" or &"="
##   Array[int]                 an ordered list, e.g. [30, 4] or the blanks of a number strip
##   Dictionary                 {tens, ones} or {hundreds, tens, ones}
class_name Problem
extends RefCounted

## The four hint rungs, in the order the ladder climbs them (Phase 1 plan, hint ladder).
const HINT_KINDS: Array[StringName] = [&"repeat_highlight", &"visual_model", &"worked_example", &"easier_problem"]
const VISUAL_TYPES: Array[StringName] = [&"gem_piles", &"ten_frame", &"number_line"]

var skill_id: StringName = &""
## The seed that produced this problem; the same seed always gives the same problem.
var seed: int = 0
var representation: StringName = &"concrete"
## A line id in text/lines.csv; prompt_params fills its {placeholders}.
var prompt_line_id: StringName = &""
var prompt_params: Dictionary = {}
var answer: Variant = 0
var answer_modes: Array[StringName] = []
## [{value: Variant, misconception: StringName}]: wrong answers a child with a named
## misconception would give. Never equal to the answer; no two with the same value.
var distractors: Array[Dictionary] = []
## What to draw: {type: "gem_piles" | "ten_frame" | "number_line", ...}. Empty for none.
var visual: Dictionary = {}
## One entry per rung: {kind, line_id, params, visual, ...extras}.
var hint_steps: Array[Dictionary] = []
## The generator settings this problem was made with (skill params plus overrides such as
## representation and difficulty). The cross-checker reads these.
var params: Dictionary = {}
## Facts the checker needs that are not in the prompt or the visual (which question was
## asked, a direction, a place...). Never shown to the child.
var meta: Dictionary = {}


## True if `given` is the right answer. Comparison is canonical: 34 and 34.0 match,
## StringName and String match, and the order of an Array matters.
func is_correct(given: Variant) -> bool:
	return canonical(given) == canonical(answer)


## The values of the distractors, in order.
func distractor_values() -> Array:
	var values: Array = []
	for entry: Dictionary in distractors:
		values.append(entry["value"])
	return values


## A tap-answer option list: the answer plus up to `max_distractors` wrong answers, as
## [{value, label}] for ChoiceButtons. `label_for` turns a value into the button text.
func choice_options(label_for: Callable, max_distractors: int = 3) -> Array[Dictionary]:
	var options: Array[Dictionary] = [{"value": answer, "label": label_for.call(answer)}]
	for entry: Dictionary in distractors.slice(0, max_distractors):
		options.append({"value": entry["value"], "label": label_for.call(entry["value"])})
	return options


## Exactly the shape the Python cross-checker reads (tools/crosscheck/).
func to_json() -> Dictionary:
	var shown: Array = []
	for entry: Dictionary in distractors:
		shown.append({"value": canonical(entry["value"]), "misconception": String(entry["misconception"])})
	var modes: Array = []
	for mode: StringName in answer_modes:
		modes.append(String(mode))
	return {
		"skill_id": String(skill_id),
		"seed": seed,
		"representation": String(representation),
		"prompt_line_id": String(prompt_line_id),
		"prompt_params": canonical(prompt_params),
		"answer": canonical(answer),
		"answer_modes": modes,
		"distractors": shown,
		"visual": canonical(visual),
		"hint_steps": canonical(hint_steps),
		"params": canonical(params),
		"meta": canonical(meta),
	}


## A JSON-friendly deep copy: StringName becomes String, whole floats become ints, containers are
## copied. Equal canonical values mean "the same answer".
static func canonical(value: Variant) -> Variant:
	if value is StringName:
		return String(value)
	if value is float:
		return JsonUtil.intify(value)
	if value is Dictionary:
		var copy: Dictionary = {}
		for key: Variant in value:
			copy[String(key) if key is StringName else key] = canonical(value[key])
		return copy
	if value is Array:
		var items: Array = []
		for item: Variant in value:
			items.append(canonical(item))
		return items
	return value
