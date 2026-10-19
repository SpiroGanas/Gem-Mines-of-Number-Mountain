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
##   {num, den}                 a fraction in lowest terms, positive den (Zone 6 on, Rational);
##                              its answer button reads "3/4"
##   {whole, num, den}          a mixed number, num < den (Zone 7)
##   {mantissa, scale}          a decimal, mantissa / 10^scale, no trailing zeros (Zone 7)
##   {a, b}                     a ratio a : b in lowest terms, order kept (Zone 6 on); "2 : 3"
##   {base, digits}             a number in base 2 to 10, digits most significant first, no leading
##                              zero (Zone 8, Notation); its answer button reads "1101"
##   {mantissa, scale, exp}     scientific notation mantissa / 10^scale × 10^exp, normalized (Zone 8)
##   {op, terms}                a written-out calculation, op "mul" or "add": 3 × 3 × 3 × 3 (Zone 8)
## The Zone 8 shapes are judged by exact form (34 × 10⁴ is not 3.4 × 10⁵ here).
## A fraction, mixed number, decimal or ratio answer is right in any form of the same value (2/4 for
## 1/2, 0.50 for 0.5, 4 : 6 for 2 : 3) unless meta.simplest_form is true; see is_correct().
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
##   gear_bench     {driver, turns, tray: [int]}: drag a gear from the tray onto the empty axle beside
##                  the driver gear (Zone 6, GearBench); the answer is the chosen gear's teeth, and
##                  the tray holds the answer and every wrong gear.
##   crystal        {den, shaded?: int, match?: {num, den}}: tap shards of a crystal cut into den equal
##                  shards to light them, then Done (Zone 7). The answer is the lit fraction, normalized.
##                  `match` draws a second crystal with that fraction lit to copy (equivalence).
##   alloy          {a, b, given: int, max: int}: the alloy mixer (Zone 7). The recipe is a copper to b
##                  tin; `given` copper is in the hopper; the child sets the tin scoops (0..max) and
##                  presses Mix. The answer is the tin count (int).
##   depth_gauge    {min, max, start}: the depth gauge (Zone 7). The child moves the elevator cab up
##                  and down from `start` and presses Stop; the answer is the cab's level (int).
##   signed         true: the number pad gets a minus key (the answer may be below zero).
##   decimal_places int: the pad or slate takes a decimal with this many places after the point.
##   percent        true: the answer buttons read "75%" (the answer is the percent as an int).
##   pad_digits     int: the number pad takes this many digits (default 3; powers of 10 need 7) (Zone 8).
##   vault_lock     {base, places}: the vault lock (Zone 8): tap lamps (base 2) or turn dials (other bases)
##                  in `places` places, then Open. The answer is the {base, digits} the lock shows.
##   base_pad       {base, places}: the base pad, digit keys 0 to base - 1 only, for a {base, digits}
##                  answer typed in (binary sums) (Zone 8).
##   tower          {base, floors, start}: the tower elevator (Zone 8): floor k is base^k meters up; the
##                  child rides the cab and presses Stop here. The answer is the floor (int).
##   lever          {left_w, left_d, right_d, max}: the counterweight lever (Zone 8): set the right weight
##                  (0..max) with More and Less, then Balance. The answer is the weight (int).
##   sci_pad        {max_exp}: the scientific-notation pad, a first number with one place after the point
##                  and a power of 10 (Zone 8). The answer is {mantissa, scale, exp}.
##   simplest_form  true: the answer must be in lowest terms (Zone 6's simplify skills). is_correct()
##                  and GeneratorKit.add_distractor then compare by exact form, so 6/9 is a wrong
##                  answer for 2/3 (`partially_simplified`) instead of an equal one.
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
## lists       {kind: "factors" | "multiples" | "recipe", rows: [{n, items: [int], lit?: [index]}],
##             marked: [int]}: one or two rows such as "12: 1, 2, 3, 4, 6, 12" (Zone 6). Values in
##             `marked` are ringed wherever they show; `lit` rings items of one row by position (the
##             shared primes of two prime recipes). At most MAX_LIST_ITEMS items a row.
## gears       {teeth: [int], shaded?: int, marks?: bool}: one to three meshing gears of 2 to 200 teeth
##             with their tooth counts; `shaded` colors that many teeth of the first gear (simplest
##             form); `marks` draws the marked teeth that start together (Zone 6)
## The Zone 7 pictures (drawn by CrystalArt, scenes/zones/z07_crystal_shards/crystal_art.gd):
## crystals    {crystals: [{den, lit, second?}], shape: "crystal" | "bar", wholes?: int, joiner?:
##             "plus" | "versus"}: crystals (round, cut into den wedge shards) or bars (cut into den
##             strips) side by side, `lit` shards lit and `second` more lit in another color; `wholes`
##             whole crystals stand in front (mixed numbers)
## fraction_line {den, wholes, marker: {num, den}}: a number line from 0 to `wholes` with a tick at
##             every 1/den and a gem at the marker
## crystal_grid {wholes, lit, cells: 10 | 100}: `wholes` full grids, then a grid of `cells` (a ten-shard
##             strip or a 10 by 10 grid) with `lit` cells lit (tenths, hundredths, percents)
## depth_gauge {min, max, labeled_every, markers: [int], jumps?: [{from, to}]}: the vertical depth gauge,
##             0 at the mountain's base, cab markers, and an elevator move as a jump
## ore_mix     {a, b, groups?: int}: a copper ores and b tin ores (round and square lumps); `groups`
##             rings them into that many equal mixes
## The Zone 8 pictures (drawn by PowerArt, scenes/zones/z08_power_tower/power_art.gd, and the notation
## scenes in scenes/ui/math/):
## power_tower {base, exp, values: bool}: the ground floor is 1 and each of `exp` floors (0 to 10)
##             multiplies by `base` (2 to 12); with `values` each floor shows its height
## notation    {form: "power", base, exp} | {form: "root", n} | {form: "sci", mantissa, scale, exp}: the
##             math written out large (a raised exponent, a root sign, × 10 with a raised power); in
##             Explorer mode the words ("2 to the power 5") sit under it
## cube_blocks {n}: a big cube n blocks a side (1 to 8)
## lamps       {base, rows: [[digits]], places, style: "lamps" | "dials" | "digits", show_places, plus?}: one
##             to three numbers in a base, right-aligned in `places` places (1 to 8), as lit lamps, dials or
##             digit columns, each place's worth written under it; `plus` draws the rows as a sum
## lever       {left: {w, d}, right: {w, d}, tilt, products?}: weights (0 is an empty hook) at 1 to 8 steps
##             from the middle; tilt as for `balance`; `products` writes w × d under each weight
const VISUAL_TYPES: Array[StringName] = [&"gem_piles", &"ten_frame", &"number_line", &"balance", &"array", &"groups", &"pairs", &"digits", &"lists", &"gears", &"crystals", &"fraction_line", &"crystal_grid", &"depth_gauge", &"ore_mix", &"power_tower", &"notation", &"cube_blocks", &"lamps", &"lever"]
const TILTS: Array[String] = ["unknown", "level", "left", "right"]
const LIST_KINDS: Array[String] = ["factors", "multiples", "recipe"]
const MAX_LIST_ITEMS: int = 16
const MAX_LIST_ROWS: int = 2
const MAX_GEARS: int = 3
const GEAR_TEETH_RANGE: Vector2i = Vector2i(2, 200)

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


## The boxes a fraction answer needs on the slate: {num: digits, den: digits} (empty when the answer
## is not a fraction). Derived from the answer, like answer_digits().
func fraction_digits() -> Dictionary:
	if not Rational.is_fraction(answer) or int(answer["num"]) < 0:
		return {}
	return {"num": str(int(answer["num"])).length(), "den": str(int(answer["den"])).length()}


## True if `given` is the right answer. Comparison is canonical: 34 and 34.0 match,
## StringName and String match, and the order of an Array matters. A fraction, mixed number, decimal
## or ratio is right in any equal form (2/4 for 1/2) unless meta.simplest_form asks for lowest terms.
func is_correct(given: Variant) -> bool:
	return same_answer(given, answer)


## True when two answers count as the same for this problem: by exact form (same()) when
## meta.simplest_form is set, else by value (same_value()). is_correct(), the distractor
## de-duplication in GeneratorKit and the mine's mistake lookup all use it, so 6/9 stays the named
## mistake `partially_simplified` on a simplest-form problem about 2/3 instead of a right answer.
func same_answer(a: Variant, b: Variant) -> bool:
	if bool(meta.get("simplest_form", false)):
		return same(a, b)
	return same_value(a, b)


## True when two answers are equal in value: fractions, mixed numbers and decimals by their exact
## value (1/2, 2/4, 0 1/2 and 0.50 are all equal), ratios by cross-multiplying (2 : 3 and 4 : 6),
## anything else as same() does. Never through a float.
static func same_value(a: Variant, b: Variant) -> bool:
	var x: Dictionary = Rational.value_of(canonical(a))
	var y: Dictionary = Rational.value_of(canonical(b))
	if not x.is_empty() and not y.is_empty():
		return x == y
	if Rational.is_ratio(a) and Rational.is_ratio(b):
		return int(a["a"]) * int(b["b"]) == int(b["a"]) * int(a["b"]) and (int(a["a"]) == 0) == (int(b["a"]) == 0)
	return same(a, b)


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
