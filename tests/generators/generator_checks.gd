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
	errors.append_array(_meta_errors(problem, where))
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
		var value: Variant = problem.prompt_params[key]
		# Whole numbers, or (Zone 7) an exact decimal or fraction the Text table formats; never a float.
		if not value is int and not (Rational.is_decimal(value) or Rational.is_fraction(value)):
			errors.append("%s: prompt param %s is not a whole number or an exact decimal" % [where, key])
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
		if problem.same_answer(canon, problem.answer):
			errors.append("%s: distractor equals the answer (%s)" % [where, canon])
		for earlier: Variant in seen:
			if problem.same_answer(earlier, canon):
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
			var second: int = int(visual.get("second", 0))
			if visual["count"] < 0 or second < 0 or visual["count"] + second > 10 * visual["frames"]:
				errors.append("%s: count %s + %s does not fit %s frame(s)" % [where, visual["count"], second, visual["frames"]])
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
			for jump: Dictionary in visual.get("jumps", []):
				for end: String in ["from", "to"]:
					if not jump.get(end) is int or jump[end] < visual["min"] or jump[end] > visual["max"]:
						errors.append("%s: jump %s %s is off the line" % [where, end, jump.get(end)])
		&"balance":
			var sides: Array[int] = []
			for side: String in ["left", "right"]:
				var terms: Variant = visual.get(side)
				if not terms is Array or terms.is_empty() or terms.size() > 3:
					errors.append("%s: %s pan needs 1 to 3 numbers" % [where, side])
					return errors
				var total: int = 0
				for term: Variant in terms:
					if not term is int or term < 0:
						errors.append("%s: %s pan holds %s, not a whole number" % [where, side, term])
						return errors
					total += term
				sides.append(total)
			var tilt: String = str(visual.get("tilt", ""))
			if not Problem.TILTS.has(tilt):
				errors.append("%s: unknown tilt '%s'" % [where, tilt])
			elif tilt != "unknown":
				var expected: String = "level" if sides[0] == sides[1] else ("left" if sides[0] > sides[1] else "right")
				if tilt != expected:
					errors.append("%s: pans of %d and %d should tilt %s, not %s" % [where, sides[0], sides[1], expected, tilt])
		&"array":
			for key: String in ["rows", "cols"]:
				if not visual.get(key) is int or visual[key] < 1 or visual[key] > 10:
					errors.append("%s: array %s must be 1 to 10" % [where, key])
		&"groups":
			for key: String in ["groups", "size"]:
				if not visual.get(key) is int or visual[key] < 1 or visual[key] > 10:
					errors.append("%s: %s must be 1 to 10" % [where, key])
		&"pairs":
			if not visual.get("count") is int or visual["count"] < 0 or visual["count"] > 40:
				errors.append("%s: pairs count must be 0 to 40" % where)
		&"digits":
			var digits: Variant = visual.get("digits")
			if not digits is Array or digits.is_empty() or digits.size() > 4:
				errors.append("%s: digits needs 1 to 4 digits" % where)
				return errors
			for digit: Variant in digits:
				if not digit is int or digit < 0 or digit > 9:
					errors.append("%s: %s is not a digit" % [where, digit])
			if not ["last", "last_two", "sum", "sum_and_last", "recipe"].has(str(visual.get("focus", ""))):
				errors.append("%s: unknown digits focus '%s'" % [where, visual.get("focus")])
		&"lists":
			errors.append_array(_lists_errors(visual, where))
		&"gears":
			var teeth: Variant = visual.get("teeth")
			if not teeth is Array or teeth.is_empty() or teeth.size() > Problem.MAX_GEARS:
				errors.append("%s: gears needs 1 to %d gears" % [where, Problem.MAX_GEARS])
				return errors
			for count: Variant in teeth:
				if not count is int or count < Problem.GEAR_TEETH_RANGE.x or count > Problem.GEAR_TEETH_RANGE.y:
					errors.append("%s: a gear has %s teeth, not %d to %d" % [where, count, Problem.GEAR_TEETH_RANGE.x, Problem.GEAR_TEETH_RANGE.y])
			if visual.has("shaded") and (not visual["shaded"] is int or visual["shaded"] < 0 or visual["shaded"] > int(teeth[0])):
				errors.append("%s: shaded must be 0 to the first gear's teeth" % where)
		&"crystals", &"fraction_line", &"crystal_grid", &"depth_gauge", &"ore_mix":
			errors.append_array(zone7_visual_errors(visual, where))
		&"power_tower", &"notation", &"cube_blocks", &"lamps", &"lever":
			errors.append_array(zone8_visual_errors(visual, where))
	return errors


## The Zone 8 pictures (Problem.VISUAL_TYPES) must be drawable: towers of 0 to 10 floors, notation of a
## known form, cubes up to 8 a side, lamp rows that fit their places with digits below the base, levers
## with hooks 1 to 8 steps out.
static func zone8_visual_errors(visual: Dictionary, where: String) -> Array[String]:
	var errors: Array[String] = []
	match StringName(visual["type"]):
		&"power_tower":
			var base: int = int(visual.get("base", 0))
			var exp: int = int(visual.get("exp", -1))
			if base < 2 or base > ExponentGenerator.MAX_TOWER_BASE or exp < 0 or exp > ExponentGenerator.MAX_TOWER_FLOORS or not visual.get("values") is bool:
				errors.append("%s: a power tower needs base 2 to 12, 0 to 10 floors and values true or false" % where)
		&"notation":
			match str(visual.get("form", "")):
				"power":
					if int(visual.get("base", -1)) < 0 or int(visual.get("exp", -1)) < 0:
						errors.append("%s: a power needs a base and an exponent of at least 0" % where)
				"root":
					var n: int = int(visual.get("n", -1))
					var root: int = roundi(sqrt(float(maxi(n, 0))))
					if n < 1 or root * root != n:
						errors.append("%s: a root card shows only perfect squares" % where)
				"sci":
					if not Notation.is_normalized_sci({"mantissa": int(visual.get("mantissa", 0)), "scale": int(visual.get("scale", -1)), "exp": int(visual.get("exp", 0))}):
						errors.append("%s: a scientific-notation card must be normalized" % where)
				_:
					errors.append("%s: unknown notation form '%s'" % [where, visual.get("form")])
		&"cube_blocks":
			if int(visual.get("n", 0)) < 1 or int(visual.get("n", 0)) > ExponentGenerator.MAX_CUBE_SIDE:
				errors.append("%s: a cube of blocks is 1 to 8 a side" % where)
		&"lamps":
			var base: int = int(visual.get("base", 0))
			var places: int = int(visual.get("places", 0))
			var rows: Variant = visual.get("rows")
			if base < 2 or base > 10 or places < 1 or places > BaseGenerator.MAX_PLACES or not ["lamps", "dials", "digits"].has(str(visual.get("style", ""))):
				errors.append("%s: lamps need base 2 to 10, 1 to %d places and a known style" % [where, BaseGenerator.MAX_PLACES])
			elif not rows is Array or rows.is_empty() or rows.size() > 3:
				errors.append("%s: lamps show 1 to 3 rows" % where)
			else:
				for row: Variant in rows:
					if not row is Array or row.size() > places:
						errors.append("%s: a row of %s does not fit %d places" % [where, row, places])
						continue
					for digit: Variant in row:
						if int(digit) < 0 or int(digit) >= base:
							errors.append("%s: digit %s is not a base-%d digit" % [where, digit, base])
		&"lever":
			for side: String in ["left", "right"]:
				var hook: Variant = visual.get(side)
				if not hook is Dictionary or int(hook.get("d", 0)) < 1 or int(hook.get("d", 0)) > 8 or int(hook.get("w", -1)) < 0 or int(hook.get("w", -1)) > 64:
					errors.append("%s: the %s weight must hang 1 to 8 steps out and weigh 0 to 64" % [where, side])
					return errors
			var tilt: String = str(visual.get("tilt", ""))
			if not Problem.TILTS.has(tilt):
				errors.append("%s: unknown tilt '%s'" % [where, tilt])
			elif tilt != "unknown":
				var left: int = int(visual["left"]["w"]) * int(visual["left"]["d"])
				var right: int = int(visual["right"]["w"]) * int(visual["right"]["d"])
				var expected: String = "level" if left == right else ("left" if left > right else "right")
				if tilt != expected:
					errors.append("%s: moments %d and %d should tilt %s" % [where, left, right, expected])
	return errors


## A `lists` picture: a known kind, one or two rows of whole numbers, marks and lit positions that exist.
static func _lists_errors(visual: Dictionary, where: String) -> Array[String]:
	var errors: Array[String] = []
	if not Problem.LIST_KINDS.has(str(visual.get("kind", ""))):
		errors.append("%s: unknown lists kind '%s'" % [where, visual.get("kind")])
	var rows: Variant = visual.get("rows")
	if not rows is Array or rows.is_empty() or rows.size() > Problem.MAX_LIST_ROWS:
		errors.append("%s: lists needs 1 to %d rows" % [where, Problem.MAX_LIST_ROWS])
		return errors
	var shown: Array = []
	for row: Variant in rows:
		var items: Variant = row.get("items") if row is Dictionary else null
		if not row is Dictionary or not row.get("n") is int or not items is Array or items.is_empty() or items.size() > Problem.MAX_LIST_ITEMS:
			errors.append("%s: each row needs n and 1 to %d items" % [where, Problem.MAX_LIST_ITEMS])
			continue
		for item: Variant in items:
			if not item is int or item < 1:
				errors.append("%s: list item %s is not a whole number above 0" % [where, item])
		for index: Variant in row.get("lit", []):
			if not index is int or index < 0 or index >= items.size():
				errors.append("%s: lit position %s is off the row" % [where, index])
		shown.append_array(items)
	for value: Variant in visual.get("marked", []):
		if not shown.has(value):
			errors.append("%s: marked %s is in no row" % [where, value])
	return errors


## The Zone 7 pictures (Problem.VISUAL_TYPES) must be drawable: shard counts the crystal can cut, lit
## counts that fit, gauge markers on the gauge.
static func zone7_visual_errors(visual: Dictionary, where: String) -> Array[String]:
	var errors: Array[String] = []
	match StringName(visual["type"]):
		&"crystals":
			var entries: Variant = visual.get("crystals")
			if not entries is Array or entries.is_empty() or entries.size() > 2:
				errors.append("%s: crystals needs 1 or 2 crystals" % where)
				return errors
			if not ["crystal", "bar"].has(str(visual.get("shape", ""))):
				errors.append("%s: unknown crystal shape '%s'" % [where, visual.get("shape")])
			if int(visual.get("wholes", 0)) < 0 or int(visual.get("wholes", 0)) > 9:
				errors.append("%s: 0 to 9 whole crystals" % where)
			for entry: Dictionary in entries:
				var den: int = int(entry.get("den", 0))
				var lit: int = int(entry.get("lit", -1)) + int(entry.get("second", 0))
				if den < 1 or den > 24 or int(entry.get("lit", -1)) < 0 or int(entry.get("second", 0)) < 0 or lit > den:
					errors.append("%s: crystal %s does not fit (1 to 24 shards, lit within)" % [where, entry])
		&"fraction_line":
			var den: int = int(visual.get("den", 0))
			var marker: Dictionary = visual.get("marker", {})
			if den < 2 or int(visual.get("wholes", 0)) < 1 or int(visual.get("ticks", 0)) != den * int(visual.get("wholes", 0)) + 1:
				errors.append("%s: a fraction line needs den >= 2 and ticks = den * wholes + 1" % where)
			elif int(marker.get("den", 0)) != den or int(marker.get("num", -1)) < 0 or int(marker.get("num", -1)) > den * int(visual["wholes"]):
				errors.append("%s: the marker %s is not on a tick" % [where, marker])
		&"crystal_grid":
			var cells: int = int(visual.get("cells", 0))
			if cells != 10 and cells != 100:
				errors.append("%s: a crystal grid has 10 or 100 cells" % where)
			for entry: Dictionary in visual.get("grids", []):
				if int(entry.get("lit", -1)) < 0 or int(entry.get("lit", -1)) > cells or int(entry.get("wholes", -1)) < 0 or int(entry.get("wholes", -1)) > 9:
					errors.append("%s: grid %s does not fit" % [where, entry])
			if visual.get("grids", []).is_empty() or visual.get("grids", []).size() > 2:
				errors.append("%s: a crystal grid shows 1 or 2 numbers" % where)
		&"depth_gauge":
			var low: int = int(visual.get("min", 0))
			var high: int = int(visual.get("max", 0))
			if low >= 0 or high <= 0 or int(visual.get("labeled_every", 0)) < 1:
				errors.append("%s: a depth gauge runs from below 0 to above 0" % where)
			for marker: Variant in visual.get("markers", []):
				if int(marker) < low or int(marker) > high:
					errors.append("%s: marker %s is off the gauge" % [where, marker])
			for jump: Dictionary in visual.get("jumps", []):
				for end: String in ["from", "to"]:
					if not jump.get(end) is int or jump[end] < low or jump[end] > high:
						errors.append("%s: jump %s %s is off the gauge" % [where, end, jump.get(end)])
		&"ore_mix":
			var a: int = int(visual.get("a", -1))
			var b: int = int(visual.get("b", -1))
			var groups: int = int(visual.get("groups", 1))
			if a < 0 or b < 0 or a + b < 1 or a + b > 72 or groups < 1 or a % groups != 0 or b % groups != 0:
				errors.append("%s: ore mix %s does not split into its groups" % [where, visual])
	return errors


## The meta keys that shape the answer input must agree with the answer (see Problem).
static func _meta_errors(problem: Problem, where: String) -> Array[String]:
	var errors: Array[String] = []
	var meta: Dictionary = problem.meta
	if meta.has("tile_board"):
		var board: Dictionary = meta["tile_board"]
		var tiles: Array = Problem.canonical(board.get("tiles", []))
		var slots: int = int(board.get("slots", 0))
		if tiles.size() < slots or tiles.size() > 8:
			errors.append("%s: a tile board needs %d to 8 tiles, has %d" % [where, slots, tiles.size()])
		for index: int in tiles.size():
			if tiles.find(tiles[index]) != index:
				errors.append("%s: tile %s is listed twice" % [where, tiles[index]])
		var values: Array = [problem.answer]
		values.append_array(problem.distractor_values())
		for value: Variant in values:
			if not value is Array or value.size() != slots:
				errors.append("%s: tile answer %s must fill exactly %d slots" % [where, value, slots])
				continue
			var spare: Array = tiles.duplicate()
			for item: Variant in Problem.canonical(value):
				if not spare.has(item):
					errors.append("%s: %s needs a tile %s that is not on the board" % [where, value, item])
				spare.erase(item)
			if not board.get("ordered", true) and Problem.canonical(value) != Problem.sorted_values(value):
				errors.append("%s: unordered tile answer %s is not sorted" % [where, value])
	if meta.has("array_builder"):
		var limits: Dictionary = meta["array_builder"]
		var values: Array = [problem.answer]
		values.append_array(problem.distractor_values())
		for value: Variant in values:
			if not value is Dictionary or not value.has("rows") or not value.has("cols"):
				errors.append("%s: an array answer must be {rows, cols}" % where)
			elif value["rows"] < 1 or value["cols"] < 1 or value["rows"] > limits["max_rows"] or value["cols"] > limits["max_cols"]:
				errors.append("%s: %s does not fit the %dx%d builder" % [where, value, limits["max_rows"], limits["max_cols"]])
	if meta.has("sieve_grid"):
		var grid: Dictionary = meta["sieve_grid"]
		var size: int = int(grid.get("size", 0))
		var values: Array = [problem.answer]
		values.append_array(problem.distractor_values())
		for value: Variant in values:
			if not value is Array or Problem.canonical(value) != Problem.sorted_values(value):
				errors.append("%s: a sieve answer must be a sorted list, got %s" % [where, value])
				continue
			for crossed: Variant in grid.get("precrossed", []):
				if not value.has(crossed):
					errors.append("%s: %s un-crosses the precrossed rock %s" % [where, value, crossed])
			for item: Variant in value:
				if int(item) < 1 or int(item) > size:
					errors.append("%s: %s is off the %d-rock grid" % [where, item, size])
	if meta.has("factor_tree"):
		var product: int = 1
		for leaf: Variant in problem.answer:
			product *= int(leaf)
		if product != int(meta["factor_tree"]["value"]):
			errors.append("%s: the tree's leaves do not multiply to its value" % where)
	if meta.has("gear_bench"):
		var bench: Dictionary = meta["gear_bench"]
		var tray: Array = Problem.canonical(bench.get("tray", []))
		var values: Array = [problem.answer]
		values.append_array(problem.distractor_values())
		if tray.size() != values.size() or Problem.sorted_values(tray) != tray:
			errors.append("%s: the gear tray must hold the answer and every wrong gear, smallest first" % where)
		for value: Variant in values:
			if not tray.has(Problem.canonical(value)):
				errors.append("%s: gear %s is not in the tray" % [where, value])
	if meta.has("crystal"):
		var spec: Dictionary = meta["crystal"]
		var den: int = int(spec.get("den", 0))
		if den < 2 or den > FractionGenerator.MAX_TAP_SHARDS:
			errors.append("%s: a crystal to tap needs 2 to %d shards" % [where, FractionGenerator.MAX_TAP_SHARDS])
		# Lighting k of den shards gives k/den: the answer must be one of those.
		var reachable: bool = false
		for k: int in range(0, den + 1):
			reachable = reachable or problem.is_correct(Rational.normalize(k, maxi(den, 1)))
		if not reachable:
			errors.append("%s: no way to light the crystal gives the answer" % where)
	if meta.has("alloy"):
		var mixer: Dictionary = meta["alloy"]
		if not problem.answer is int or problem.answer < 0 or problem.answer > int(mixer.get("max", -1)):
			errors.append("%s: the tin hopper cannot hold the answer" % where)
	if meta.has("depth_gauge"):
		var ride: Dictionary = meta["depth_gauge"]
		if not problem.answer is int or problem.answer < int(ride["min"]) or problem.answer > int(ride["max"]) or int(ride["start"]) < int(ride["min"]) or int(ride["start"]) > int(ride["max"]):
			errors.append("%s: the cab cannot ride to the answer" % where)
	errors.append_array(_zone8_meta_errors(problem, where))
	if bool(meta.get("simplest_form", false)):
		# Judged by form (Problem.same_answer), so the answer itself must be in lowest terms.
		var answer: Variant = problem.answer
		var lowest: bool = Rational.is_canonical(answer) or (Rational.is_ratio(answer) \
			and Rational.normalize_ratio(int(answer["a"]), int(answer["b"])) == Problem.canonical(answer))
		if not lowest:
			errors.append("%s: a simplest-form answer %s is not in lowest terms" % [where, answer])
	if meta.has("label_lines"):
		var labels: Dictionary = meta["label_lines"]
		var values: Array = [problem.answer]
		values.append_array(problem.distractor_values())
		for value: Variant in values:
			var key: String = Problem.label_key(value)
			if not labels.has(key):
				errors.append("%s: no label line for answer %s" % [where, key])
			elif not Text.has_line(StringName(labels[key])):
				errors.append("%s: label line '%s' is not in the text table" % [where, labels[key]])
	return errors


## Zone 8's inputs must be able to give the answer: the vault lock and base pad hold its digits, the
## cab can stop on its floor, the lever's weight range holds it, the pad has room for its digits, and a
## {base, digits} or scientific-notation answer is canonical.
static func _zone8_meta_errors(problem: Problem, where: String) -> Array[String]:
	var errors: Array[String] = []
	var meta: Dictionary = problem.meta
	var answer: Variant = problem.answer
	if Notation.is_base_number(answer) and not Notation.is_canonical_base_number(answer):
		errors.append("%s: the answer %s is not a canonical base-%s number" % [where, answer, answer["base"]])
	if Notation.is_sci(answer) and not Notation.is_normalized_sci(answer):
		errors.append("%s: the answer %s is not normalized scientific notation" % [where, answer])
	for key: String in ["vault_lock", "base_pad"]:
		if meta.has(key):
			var spec: Dictionary = meta[key]
			if not Notation.is_base_number(answer) or int(spec["base"]) != int(answer["base"]) or answer["digits"].size() > int(spec["places"]) or int(spec["places"]) > BaseGenerator.MAX_PLACES:
				errors.append("%s: the %s cannot show the answer %s" % [where, key, answer])
	if meta.has("tower"):
		var tower: Dictionary = meta["tower"]
		if not answer is int or answer < 0 or answer > int(tower["floors"]) or int(tower["floors"]) > ExponentGenerator.MAX_TOWER_FLOORS:
			errors.append("%s: the cab cannot stop on floor %s" % [where, answer])
	if meta.has("lever"):
		if not answer is int or answer < 0 or answer > int(meta["lever"]["max"]):
			errors.append("%s: the lever cannot hold the weight %s" % [where, answer])
	if meta.has("pad_digits") and answer is int and str(answer).length() > int(meta["pad_digits"]):
		errors.append("%s: the pad has %s digits, the answer needs more" % [where, meta["pad_digits"]])
	if meta.has("sci_pad") and (not Notation.is_sci(answer) or int(answer["exp"]) > int(meta["sci_pad"]["max_exp"])):
		errors.append("%s: the scientific-notation pad cannot give %s" % [where, answer])
	return errors


static func _json_errors(problem: Problem, where: String) -> Array[String]:
	var errors: Array[String] = []
	var parsed: Variant = JsonUtil.parse_text(JSON.stringify(problem.to_json()))
	if not parsed is Dictionary:
		errors.append("%s: to_json() did not survive a JSON round trip" % where)
		return errors
	if not Problem.same(parsed["answer"], problem.answer):
		errors.append("%s: answer changed in the JSON round trip" % where)
	if parsed["seed"] != problem.seed:
		errors.append("%s: seed changed in the JSON round trip" % where)
	for key: String in ["skill_id", "seed", "representation", "prompt_line_id", "prompt_params", "answer", "answer_modes", "distractors", "visual", "hint_steps", "params", "meta"]:
		if not parsed.has(key):
			errors.append("%s: to_json() lacks '%s'" % [where, key])
	return errors
