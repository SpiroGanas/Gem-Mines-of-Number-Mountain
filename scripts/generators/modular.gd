## Clock arithmetic for Zone 10, Clockwork Depths (skills mod.*): a cart rides a loop of n stations, 0 to n - 1, and
## the station it stops at is the remainder. "12 stops on a loop of 7" ends at station 5. The answer is always the
## non-negative remainder (posmod, never GDScript's % on a value that may be negative). Pure: only the passed-in rng
## is used.
##
## Modes (params.mode):
##   remainder   "The loop has {n} stations. The cart rides {a} stops. Where does it stop?" from station 0, or in
##               words ("Share {a} gems into groups of {n}"). The answer is a mod n, with a at least n. Concrete: the
##               circular track (meta.circular_track); pictorial: the clock_track picture; abstract: words only.
##   track       the cart starts at station s and rides k stops forward (params.direction 1) or back (-1). Concrete
##               and pictorial as above. Backward problems let the pad take a minus sign (meta.signed), so a child who
##               rides past 0 and answers below 0 gets Bolt's `negative_remainder` line.
##   congruence  Do a and b stop at the same station on a loop of n? Yes or no.
##   notation    A card "a ≡ b (mod n)": which number is the size of the loop, or which station do both land on?
##   add         Turn a dial of n marks a, then b: where does it stop? (a + b) mod n. Concrete: the clock lock.
##   mul         a times b on a dial of n marks (a × b) mod n; pictorial: the multiplication table with a box ringed.
##
## The named mistakes:
##   gave_quotient          the number of full laps, a ÷ n;
##   forgot_mod_wrap        the raw sum, product or a - n, not wrapped onto the loop;
##   off_by_one             one station too far or too short;
##   counted_start_station  counted the starting station as a stop (k - 1 stops);
##   negative_remainder     rode back past 0 and answered below 0;
##   went_forward_instead   rode forward when the cart rides back;
##   compared_quotients     said yes because the two numbers make the same number of laps;
##   compared_raw_values    said no because the numbers are not the same;
##   swapped_mod_and_value  chose one of the numbers as the size of the loop;
##   read_as_equals         chose one of the numbers as the shared station;
##   subtracted_instead     a - b on the dial instead of a + b;
##   added_instead          a + b on the dial instead of a × b.
class_name ModularGenerator
extends RefCounted

const PROMPT_REMAINDER: StringName = &"z10.mod.prompt_remainder"
const PROMPT_REMAINDER_TRACK: StringName = &"z10.mod.prompt_remainder_track"
const PROMPT_STOP: StringName = &"z10.mod.prompt_stop"
const PROMPT_BACK: StringName = &"z10.mod.prompt_back"
const PROMPT_CONGRUENT: StringName = &"z10.mod.prompt_congruent"
const PROMPT_NOTATION_LOOP: StringName = &"z10.mod.prompt_notation_loop"
const PROMPT_NOTATION_STATION: StringName = &"z10.mod.prompt_notation_station"
const PROMPT_ADD: StringName = &"z10.mod.prompt_add"
const PROMPT_MUL: StringName = &"z10.mod.prompt_mul"
## The loop and the dial have from 2 to this many stations or marks.
const MAX_STATIONS: int = 12
## The most stops a picture shows a cart riding.
const MAX_STOPS: int = 99


static func generate(skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Problem:
	return _make(skill, params, rng, true)


## A `clock_track` picture: a loop of n stations with the cart at `start`, riding `steps` stops forward
## (direction 1) or back (-1). `show_stop` marks where it stops; `also` draws a second cart that rides that many
## stops from 0 (congruence); `orbit` draws the hops of `steps` stops until the cart is back at its start.
static func clock_track(n: int, start: int, steps: int, direction: int, show_stop: bool, also: int = -1, orbit: bool = false) -> Dictionary:
	var picture: Dictionary = {"type": "clock_track", "n": n, "start": start, "steps": steps, "direction": direction, "show_stop": show_stop}
	if also >= 0:
		picture["also"] = also
	if orbit:
		picture["orbit"] = true
	return picture


static func _make(skill: Skill, params: Dictionary, rng: RandomNumberGenerator, with_hints: bool) -> Problem:
	var mode: String = String(params.get("mode", "remainder"))
	var problem: Problem = GeneratorKit.new_problem(skill, params, GeneratorKit.pick_representation(skill, params))
	var model: Dictionary
	match mode:
		"remainder":
			model = _remainder(problem, skill, params, rng)
		"track":
			model = _track(problem, skill, params, rng)
		"congruence":
			model = _congruence(problem, skill, params, rng)
		"notation":
			model = _notation(problem, skill, params, rng)
		"add":
			model = _add(problem, skill, params, rng)
		"mul":
			model = _mul(problem, skill, params, rng)
		_:
			push_error("ModularGenerator: unknown mode '%s'" % mode)
			return problem
	if with_hints:
		var example: Problem = GeneratorKit.make_example(
			func(sub: RandomNumberGenerator) -> Problem: return _make(skill, params, sub, false), problem, rng)
		GeneratorKit.add_hints(problem, model, example, _example_line(mode, example))
	return problem


## The number of stations for a problem: from params.min_n to params.max_n, eased one step at a time.
static func _stations(params: Dictionary, rng: RandomNumberGenerator) -> int:
	var low: int = int(params.get("min_n", 2))
	var high: int = GeneratorKit.eased_max(low, mini(int(params.get("max_n", MAX_STATIONS)), MAX_STATIONS), GeneratorKit.difficulty_of(params), 2)
	return rng.randi_range(low, high)


# --- remainder -----------------------------------------------------------------------------------


static func _remainder(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var n: int = _stations(params, rng)
	var low: int = maxi(int(params.get("min_a", 3)), n)
	var high: int = maxi(GeneratorKit.eased_max(low, mini(int(params.get("max_a", MAX_STOPS)), MAX_STOPS), GeneratorKit.difficulty_of(params), n), low)
	var a: int = rng.randi_range(low, high)
	var r: int = posmod(a, n)
	problem.answer = r
	problem.prompt_params = {"a": a, "n": n}
	if problem.representation == &"abstract":
		problem.prompt_line_id = PROMPT_REMAINDER
	else:
		problem.prompt_line_id = PROMPT_REMAINDER_TRACK
	if problem.representation == &"concrete":
		problem.meta = {"circular_track": {"n": n, "start": 0, "steps": a, "direction": 1}}
	elif problem.representation == &"pictorial":
		problem.visual = clock_track(n, 0, a, 1, false)
	GeneratorKit.add_distractor(problem, skill, floori(float(a) / n), &"gave_quotient")
	if a - n >= n:
		GeneratorKit.add_distractor(problem, skill, a - n, &"forgot_mod_wrap")
	GeneratorKit.add_distractor(problem, skill, r + 1 if r + 1 < n else r - 1, &"off_by_one")
	return clock_track(n, 0, a, 1, true)


# --- track ---------------------------------------------------------------------------------------


static func _track(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var direction: int = int(params.get("direction", 1))
	var n: int = _stations(params, rng)
	var low: int = int(params.get("min_steps", 1))
	var high: int = GeneratorKit.eased_max(low, mini(int(params.get("max_steps", 60)), MAX_STOPS), GeneratorKit.difficulty_of(params), n)
	var s: int = rng.randi_range(0, n - 1)
	var k: int = rng.randi_range(low, high)
	var r: int = posmod(s + direction * k, n)
	problem.answer = r
	problem.prompt_line_id = PROMPT_STOP if direction > 0 else PROMPT_BACK
	problem.prompt_params = {"n": n, "s": s, "k": k}
	if problem.representation == &"concrete":
		problem.meta = {"circular_track": {"n": n, "start": s, "steps": k, "direction": direction}}
	else:
		problem.visual = clock_track(n, s, k, direction, false)
	if direction > 0:
		if s + k >= n:
			GeneratorKit.add_distractor(problem, skill, s + k, &"forgot_mod_wrap")
		GeneratorKit.add_distractor(problem, skill, posmod(s + k - 1, n), &"counted_start_station")
	else:
		problem.meta["signed"] = true # a child may type the station below 0 (and meet negative_remainder)
		GeneratorKit.add_distractor(problem, skill, s - k, &"negative_remainder", true)
		GeneratorKit.add_distractor(problem, skill, posmod(s + k, n), &"went_forward_instead")
	return clock_track(n, s, k, direction, true)


# --- congruence ----------------------------------------------------------------------------------


## A second number b, not a, with the same remainder on the loop of n when `same`, else a different one (a
## different remainder with the same number of laps, when there is one, to catch compared_quotients).
static func _partner(a: int, n: int, low: int, high: int, same: bool, rng: RandomNumberGenerator) -> int:
	var matches: Array[int] = []
	var near: Array[int] = []
	for b: int in range(low, high + 1):
		if b == a:
			continue
		if (b % n == a % n) == same:
			matches.append(b)
			if not same and floori(float(b) / n) == floori(float(a) / n):
				near.append(b)
	var pool: Array[int] = near if not near.is_empty() and rng.randi_range(0, 99) < 50 else matches
	return pool[rng.randi_range(0, pool.size() - 1)]


static func _congruence(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var n: int = _stations(params, rng)
	var low: int = int(params.get("min_a", 0))
	var high: int = GeneratorKit.eased_max(maxi(low, 2 * n), int(params.get("max_a", 120)), GeneratorKit.difficulty_of(params), n)
	var a: int = rng.randi_range(low, high)
	var same: bool = rng.randi_range(0, 1) == 0
	var b: int = _partner(a, n, low, high, same, rng)
	problem.answer = posmod(a, n) == posmod(b, n)
	problem.prompt_line_id = PROMPT_CONGRUENT
	problem.prompt_params = {"n": n, "a": a, "b": b}
	problem.meta = {"label_lines": GeneratorKit.yes_no_labels()}
	if problem.representation == &"pictorial":
		problem.visual = clock_track(n, 0, a, 1, false, b)
	# A wrong "yes" compares laps, a wrong "no" compares the numbers themselves.
	GeneratorKit.add_distractor(problem, skill, not problem.answer, &"compared_raw_values" if problem.answer else &"compared_quotients")
	return clock_track(n, 0, a, 1, true, b)


# --- notation ------------------------------------------------------------------------------------


## The `notation` picture of a congruence card, a ≡ b (mod n).
static func congruence_card(a: int, b: int, n: int) -> Dictionary:
	return {"type": "notation", "form": "congruence", "a": a, "b": b, "n": n}


static func _notation(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var n: int = _stations(params, rng)
	var low: int = maxi(int(params.get("min_a", 0)), n + 1)
	var high: int = GeneratorKit.eased_max(low + n, int(params.get("max_a", 120)), GeneratorKit.difficulty_of(params), n)
	var a: int = rng.randi_range(low, high)
	var b: int = _partner(a, n, low, high, true, rng)
	var r: int = posmod(a, n)
	problem.visual = congruence_card(a, b, n)
	problem.prompt_params = {}
	if rng.randi_range(0, 1) == 0:
		problem.prompt_line_id = PROMPT_NOTATION_LOOP
		problem.answer = n
		GeneratorKit.add_distractor(problem, skill, a, &"swapped_mod_and_value")
		GeneratorKit.add_distractor(problem, skill, b, &"swapped_mod_and_value")
		GeneratorKit.add_distractor(problem, skill, r, &"swapped_mod_and_value")
	else:
		problem.prompt_line_id = PROMPT_NOTATION_STATION
		problem.answer = r
		GeneratorKit.add_distractor(problem, skill, a, &"read_as_equals")
		GeneratorKit.add_distractor(problem, skill, b, &"read_as_equals")
		GeneratorKit.add_distractor(problem, skill, n, &"swapped_mod_and_value")
	problem.meta["a"] = a
	problem.meta["b"] = b
	problem.meta["n"] = n
	return congruence_card(a, b, n)


# --- add and mul ---------------------------------------------------------------------------------


static func _add(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var n: int = _stations(params, rng)
	var a: int = rng.randi_range(2, n - 1)
	var b: int = rng.randi_range(n - a, n - 1) if rng.randi_range(0, 99) < 70 else rng.randi_range(1, n - a)
	var r: int = posmod(a + b, n)
	problem.answer = r
	problem.prompt_line_id = PROMPT_ADD
	problem.prompt_params = {"n": n, "m": n - 1, "a": a, "b": b}
	if problem.representation == &"concrete":
		problem.meta = {"clock_lock": {"n": n, "turns": [a, b]}}
	if a + b >= n:
		GeneratorKit.add_distractor(problem, skill, a + b, &"forgot_mod_wrap")
	GeneratorKit.add_distractor(problem, skill, posmod(a - b, n), &"subtracted_instead")
	return clock_track(n, 0, a + b, 1, true)


static func _mul(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var n: int = _stations(params, rng)
	var a: int = 2
	var b: int = 2
	for attempt: int in 20:
		a = rng.randi_range(2, n - 1)
		b = rng.randi_range(2, n - 1)
		if a * b >= n:
			break
	var r: int = posmod(a * b, n)
	problem.answer = r
	problem.prompt_line_id = PROMPT_MUL
	problem.prompt_params = {"n": n, "m": n - 1, "a": a, "b": b}
	if problem.representation == &"pictorial":
		problem.visual = GroupGenerator.cayley_picture(n, &"mul", true, [a, b], [a, b])
	if a * b >= n:
		GeneratorKit.add_distractor(problem, skill, a * b, &"forgot_mod_wrap")
	GeneratorKit.add_distractor(problem, skill, posmod(a + b, n), &"added_instead")
	return GroupGenerator.cayley_picture(n, &"mul", true, [], [a, b])


# --- hints ---------------------------------------------------------------------------------------


static func _example_line(mode: String, example: Problem) -> Dictionary:
	var p: Dictionary = example.prompt_params
	match mode:
		"remainder":
			return {"line_id": &"z10.hint.example_remainder", "params": {"a": p["a"], "n": p["n"], "q": floori(float(p["a"]) / p["n"]), "r": example.answer}}
		"track":
			var line: StringName = &"z10.hint.example_stop" if example.prompt_line_id == PROMPT_STOP else &"z10.hint.example_back"
			return {"line_id": line, "params": {"s": p["s"], "k": p["k"], "n": p["n"], "r": example.answer}}
		"congruence":
			var r: int = posmod(p["a"], p["n"])
			if example.answer:
				return {"line_id": &"z10.hint.example_congruent_yes", "params": {"a": p["a"], "b": p["b"], "r": r}}
			return {"line_id": &"z10.hint.example_congruent_no", "params": {"a": p["a"], "b": p["b"], "r": r, "t": posmod(p["b"], p["n"])}}
		"notation":
			if example.prompt_line_id == PROMPT_NOTATION_LOOP:
				return {"line_id": &"z10.hint.example_notation_loop", "params": {"n": example.meta["n"]}}
			return {"line_id": &"z10.hint.example_notation_station", "params": {"a": example.meta["a"], "b": example.meta["b"], "r": example.answer, "n": example.meta["n"]}}
		"add":
			return {"line_id": &"z10.hint.example_add", "params": {"a": p["a"], "b": p["b"], "t": int(p["a"]) + int(p["b"]), "n": p["n"], "r": example.answer}}
	return {"line_id": &"z10.hint.example_mul", "params": {"a": p["a"], "b": p["b"], "t": int(p["a"]) * int(p["b"]), "n": p["n"], "r": example.answer}}
