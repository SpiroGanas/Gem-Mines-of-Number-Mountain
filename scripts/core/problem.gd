## One generated problem: what is asked, the right answer, named wrong answers and the hints.
##
## Problems are plain data (no nodes) so generators stay pure and testable, and so
## to_json() can hand the exact same facts to the independent Python cross-checker.
##
## Answers use one canonical shape per kind of question:
##   int                        a count or a number
##   StringName                 a choice such as &"<", &">" or &"="
##   Array[int]                 an ordered list, e.g. [30, 4] or the blanks of a number strip
##   Dictionary                 {tens, ones}, {hundreds, tens, ones} or {rows, cols}
##   bool                       true / false (is the scale balanced? is it even?)
##   String                     a fact such as "12 - 5 = 7"
##
## Optional `meta` keys that pick or shape the answer input (AnswerPanel reads them):
##   tools          ["ten", "one"] or ["hundred", "ten", "one"]: build on the BuildBoard
##   start          {tens, ones}: pieces already in the BuildBoard tray (regrouping)
##   tap_target     "pile": tap one of the piles in the picture
##   tile_board     {tiles: Array, slots: int, ordered: bool}: drag tiles into slots. The answer
##                  is an Array of `slots` tile values; when `ordered` is false the answer (and every
##                  distractor) is sorted with Problem.sorted_values() so any order of the same
##                  tiles is the same answer.
##   array_builder  {max_rows: int, max_cols: int}: drag or tap out an array; answer {rows, cols}
##   label_lines    {label_key: line id}: answer buttons whose labels are words ("True", "Even")
##                  instead of numerals. Keys come from Problem.label_key(value).
##   array_label    "sum": an Array answer reads "30 + 4" instead of "30, 4"; "product": "2 × 2 × 3"
##   strip          [int]: the whole number strip, blanks included, when the picture is not a
##                  number line (counting by twos shows pairs); the tile board draws the strip
##                  around its slots from it. The blanks are the answer's values.
##   sieve_grid     {size, cols, precrossed: [int]}: the Sieve of Eratosthenes grid (Zone 5). The
##                  child crosses out rocks and presses Done; the answer is every crossed rock,
##                  smallest first. The precrossed rocks are crossed from the start and stay so.
##   factor_tree    {value}: build the factor tree of value by splitting pieces with the pickaxe
##                  (Zone 5); the answer is the leaves, smallest first.
## Generators may add other meta keys for their checkers (e.g. `picture`, `table`); the panel
## ignores keys it does not know.
class_name Problem
extends RefCounted

## The four hint rungs, in the order the ladder climbs them (Phase 1 plan, hint ladder).
const HINT_KINDS: Array[StringName] = [&"repeat_highlight", &"visual_model", &"worked_example", &"easier_problem"]
## gem_piles   {piles: [{hundreds, tens, ones}]}
## ten_frame   {count, frames, second?}: `count` dots, then `second` dots of another color
## number_line {min, max, labeled_every, markers, blanks, jumps?: [{from, to}]}
## balance     {left: [int], right: [int], tilt: "unknown" | "level" | "left" | "right"}: the
##             addends on each pan; "left" means the left pan is heavier (lower)
## array       {rows, cols, outline_rows?}: gems in rows and columns
## groups      {groups, size}: equal groups of gems, each in its own ring
## pairs       {count, show_pairs?}: gems lined up two by two; show_pairs rings each pair
## digits      {digits: [int], focus: "last" | "last_two" | "sum" | "sum_and_last" | "recipe",
##             recipe?: [int]}: a number's digits with the part a divisibility rule looks at lit up,
##             plus "1 + 2 + 6 = 9" under a digit sum or "= 2 × 2 × 3" under a recipe (Zone 5)
const VISUAL_TYPES: Array[StringName] = [&"gem_piles", &"ten_frame", &"number_line", &"balance", &"array", &"groups", &"pairs", &"digits"]
const TILTS: Array[String] = ["unknown", "level", "left", "right"]

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


## How many digits the answer has when it is a whole number (the chalk slate makes one box per
## digit), else 0. Derived from the answer, so it is not saved or exported.
func answer_digits() -> int:
	return str(answer).length() if answer is int and answer >= 0 else 0


## True if `given` is the right answer. Comparison is canonical: 34 and 34.0 match,
## StringName and String match, and the order of an Array matters.
func is_correct(given: Variant) -> bool:
	return same(given, answer)


## True when two answers are the same in canonical form. Values of different kinds (a number and
## a truth value, say) are never the same; Godot would raise an error comparing them with ==.
static func same(a: Variant, b: Variant) -> bool:
	var x: Variant = canonical(a)
	var y: Variant = canonical(b)
	if typeof(x) != typeof(y):
		return false
	if x is Array:
		if x.size() != y.size():
			return false
		for index: int in x.size():
			if not same(x[index], y[index]):
				return false
		return true
	if x is Dictionary:
		if x.size() != y.size():
			return false
		for key: Variant in x:
			if not y.has(key) or not same(x[key], y[key]):
				return false
		return true
	return x == y


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


## The key a value has in meta.label_lines: "true" / "false" for a bool, the text of anything else.
static func label_key(value: Variant) -> String:
	if value is bool:
		return "true" if value else "false"
	return str(canonical(value))


## The order an unordered tile answer is kept in: numbers ascending, text in code-point order.
## Generators sort with this, and the tile board sorts what the child built the same way.
static func sorted_values(values: Array) -> Array:
	var items: Array = canonical(values)
	items.sort_custom(func(x: Variant, y: Variant) -> bool:
		if typeof(x) == typeof(y):
			return x < y
		return typeof(x) < typeof(y))
	return items


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
