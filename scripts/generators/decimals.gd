## Decimals for Zone 7, Crystal Shards (skills decimal.*). A ten-shard crystal shows tenths and a 10 by
## 10 crystal grid shows hundredths. params.mode picks the question:
##   tenths         {w} whole crystals and {k} lit shards of ten: what decimal is that?  answer w.k
##   hundredths     {w} whole grids and {c} lit cells of a hundred: what decimal?  answer w.cc
##   from_fraction  write {num}/{den} as a decimal; den comes from params.dens, every one of which
##                  divides 100, so the decimal is exact at two places (never 1/3)
##   compare        which symbol, < or >, goes between two decimals of up to params.max_scale places
## A decimal is {mantissa, scale} (mantissa / 10^scale) with no trailing zeros (Rational.normalize_decimal)
## and is right in any equal form (0.50 for 0.5). meta.decimal_places tells the pad or the slate how
## many boxes go after the point. Integers only: a decimal never passes through a float.
## Pure: only the passed-in rng is used.
##
## The named mistakes:
##   place_shift                 put the point one place off (2.3 as 0.23, 0.37 as 3.7, 0.75 as 7.5);
##   read_as_whole               read the digits as a whole number (2.3 as 23);
##   dropped_zero                left out the zero in the tenths place (0.05 as 0.5);
##   wrote_numerator_as_decimal  wrote the top of the fraction after the point (3/4 as 0.3);
##   longer_is_bigger            thought the decimal with more digits is bigger (0.45 > 0.5);
##   ignored_whole               compared only the digits after the point (2.3 < 1.45);
##   reversed_symbol             pointed the symbol the wrong way.
class_name DecimalGenerator
extends RefCounted

const SYMBOL_LESS: StringName = &"<"
const SYMBOL_GREATER: StringName = &">"
const RETRIES: int = 60


static func generate(skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Problem:
	return _make(skill, params, rng, true)


static func _make(skill: Skill, params: Dictionary, rng: RandomNumberGenerator, with_hints: bool) -> Problem:
	var problem: Problem = GeneratorKit.new_problem(skill, params, GeneratorKit.pick_representation(skill, params))
	var model: Dictionary = {}
	var example_line: Callable
	match str(params.get("mode", "tenths")):
		"tenths":
			model = _tenths(problem, skill, params, rng)
			example_line = _read_line
		"hundredths":
			model = _hundredths(problem, skill, params, rng)
			example_line = _read_line
		"from_fraction":
			model = _from_fraction(problem, skill, params, rng)
			example_line = _fraction_line
		"compare":
			model = _compare(problem, skill, params, rng)
			example_line = _compare_line
	if with_hints:
		var example: Problem = GeneratorKit.make_example(
			func(sub: RandomNumberGenerator) -> Problem: return _make(skill, params, sub, false), problem, rng)
		GeneratorKit.add_hints(problem, model, example, example_line.call(example))
	return problem


## mantissa / 10^scale with its trailing zeros removed (4.0 is 4).
static func decimal(mantissa: int, scale: int) -> Dictionary:
	return Rational.normalize_decimal(mantissa, scale)


## A `crystal_grid` picture: `cells` 10 (a ten-shard strip) or 100 (a 10 by 10 grid); one entry per
## number shown, {wholes, lit}.
static func grid(cells: int, entries: Array[Dictionary]) -> Dictionary:
	return {"type": "crystal_grid", "cells": cells, "grids": entries}


static func grid_entry(wholes: int, lit: int) -> Dictionary:
	return {"wholes": wholes, "lit": lit}


static func _max_whole(params: Dictionary) -> int:
	return GeneratorKit.eased_max(0, int(params.get("max_whole", 9)), GeneratorKit.difficulty_of(params), 1)


static func _tenths(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var whole: int = rng.randi_range(0, _max_whole(params))
	var tenths: int = rng.randi_range(1, 9)
	var digits: int = whole * 10 + tenths
	problem.prompt_params = {"w": whole, "k": tenths}
	problem.answer = Rational.normalize_decimal(digits, 1)
	problem.meta = {"decimal_places": 1}
	var model: Dictionary = FractionGenerator.crystals([FractionGenerator.crystal(10, tenths)], "crystal", whole)
	match problem.representation:
		&"concrete":
			problem.prompt_line_id = &"z7.tenths.prompt_crystal"
			problem.visual = model.duplicate(true)
		&"pictorial":
			problem.prompt_line_id = &"z7.tenths.prompt_grid"
			problem.visual = grid(10, [grid_entry(whole, tenths)])
		_:
			problem.prompt_line_id = &"z7.tenths.prompt_words"
	GeneratorKit.add_distractor(problem, skill, decimal(digits, 2), &"place_shift")
	GeneratorKit.add_distractor(problem, skill, decimal(digits, 0), &"read_as_whole")
	return model


static func _hundredths(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var whole: int = rng.randi_range(0, _max_whole(params))
	var cells: int = rng.randi_range(1, 99)
	var digits: int = whole * 100 + cells
	problem.prompt_params = {"w": whole, "k": cells}
	problem.answer = Rational.normalize_decimal(digits, 2)
	problem.meta = {"decimal_places": 2}
	var model: Dictionary = grid(100, [grid_entry(whole, cells)])
	if problem.representation == &"pictorial":
		problem.prompt_line_id = &"z7.hundredths.prompt_grid"
		problem.visual = model.duplicate(true)
	else:
		problem.prompt_line_id = &"z7.hundredths.prompt_words"
	GeneratorKit.add_distractor(problem, skill, decimal(digits, 1), &"place_shift")
	if cells < 10:
		GeneratorKit.add_distractor(problem, skill, decimal(whole * 10 + cells, 1), &"dropped_zero")
	GeneratorKit.add_distractor(problem, skill, decimal(digits, 0), &"read_as_whole")
	return model


static func _read_line(example: Problem) -> Dictionary:
	var line: StringName = &"z7.hint.example_tenths" if int(example.meta["decimal_places"]) == 1 else &"z7.hint.example_hundredths"
	return {"line_id": line, "params": {"w": example.prompt_params["w"], "k": example.prompt_params["k"], "d": example.answer}}


static func _from_fraction(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var dens: Array[int] = GeneratorKit.ints_of(params.get("dens", [2, 4, 5, 10, 20, 25, 50, 100]))
	if GeneratorKit.difficulty_of(params) < 0:
		dens = dens.filter(func(den: int) -> bool: return den <= 10) # halves, quarters, fifths, tenths
	var den: int = dens[rng.randi_range(0, dens.size() - 1)]
	var num: int = rng.randi_range(1, den - 1)
	var exact: Dictionary = Rational.to_decimal(num, den, 2)
	problem.prompt_line_id = &"z7.decfrac.prompt"
	problem.prompt_params = {"num": num, "den": den}
	problem.answer = Rational.normalize_decimal(int(exact["mantissa"]), 2)
	problem.meta = {"decimal_places": 2}
	var shown: Dictionary = problem.answer
	GeneratorKit.add_distractor(problem, skill, decimal(num, 1 if num < 10 else 2), &"wrote_numerator_as_decimal")
	GeneratorKit.add_distractor(problem, skill, decimal(int(shown["mantissa"]), int(shown["scale"]) - 1), &"place_shift")
	return grid(100, [grid_entry(0, int(exact["mantissa"]))])


static func _fraction_line(example: Problem) -> Dictionary:
	var num: int = example.prompt_params["num"]
	var den: int = example.prompt_params["den"]
	var hundredths: int = int(Rational.to_decimal(num, den, 2)["mantissa"])
	return {"line_id": &"z7.hint.example_decfrac", "params": {"num": num, "den": den, "k": hundredths, "d": example.answer}}


static func _compare(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var max_scale: int = clampi(int(params.get("max_scale", 2)), 1, 2)
	var whole_top: int = GeneratorKit.eased_max(0, int(params.get("max_whole", 3)), GeneratorKit.difficulty_of(params), 1)
	# Prefer a pair that invites a named mistake (longer_is_bigger, ignored_whole); 0.5 and 0.45 does.
	var a: Dictionary = decimal(5, 1)
	var b: Dictionary = decimal(45, 2)
	for attempt: int in RETRIES:
		var x: Dictionary = _random_decimal(whole_top, max_scale, rng)
		var y: Dictionary = _random_decimal(whole_top, max_scale, rng)
		if Rational.compare_decimal(x, y) != 0 and not _mistakes(x, y).has(&"reversed_symbol"):
			a = x
			b = y
			break
	var order: int = Rational.compare_decimal(a, b)
	var answer: StringName = SYMBOL_LESS if order < 0 else SYMBOL_GREATER
	problem.prompt_line_id = &"z7.deccmp.prompt"
	problem.prompt_params = {"a": a, "b": b}
	problem.answer = answer
	var mistakes: Dictionary = _mistakes(a, b)
	for name: StringName in mistakes:
		GeneratorKit.add_distractor(problem, skill, mistakes[name], name)
	var a_cells: int = int(a["mantissa"]) * Rational.pow10(2 - int(a["scale"]))
	var b_cells: int = int(b["mantissa"]) * Rational.pow10(2 - int(b["scale"]))
	var model: Dictionary = grid(100, [grid_entry(floori(a_cells / 100.0), a_cells % 100), grid_entry(floori(b_cells / 100.0), b_cells % 100)])
	if problem.representation == &"pictorial":
		problem.visual = model.duplicate(true)
	return model


## A decimal with whole part 0..whole_top and 1 or 2 places (the last digit never 0).
static func _random_decimal(whole_top: int, max_scale: int, rng: RandomNumberGenerator) -> Dictionary:
	var scale: int = rng.randi_range(1, max_scale)
	var places: int = rng.randi_range(1, Rational.pow10(scale) - 1)
	if places % 10 == 0:
		places += 1 # the last digit is never 0, so 0.50 is never shown as two places
	var whole: int = rng.randi_range(0, whole_top)
	return decimal(whole * Rational.pow10(scale) + places, scale)


## The wrong symbols the two decimals invite: {misconception: symbol}, only those that differ from the
## right one.
static func _mistakes(a: Dictionary, b: Dictionary) -> Dictionary:
	var right: int = Rational.compare_decimal(a, b)
	var mistakes: Dictionary = {}
	var by_length: int = signi(int(a["scale"]) - int(b["scale"]))
	if by_length != 0 and by_length != right:
		mistakes[&"longer_is_bigger"] = _symbol(by_length)
	var a_whole: int = floori(int(a["mantissa"]) / float(Rational.pow10(int(a["scale"]))))
	var b_whole: int = floori(int(b["mantissa"]) / float(Rational.pow10(int(b["scale"]))))
	if a_whole != b_whole:
		var a_part: Dictionary = decimal(int(a["mantissa"]) - a_whole * Rational.pow10(int(a["scale"])), int(a["scale"]))
		var b_part: Dictionary = decimal(int(b["mantissa"]) - b_whole * Rational.pow10(int(b["scale"])), int(b["scale"]))
		var by_part: int = Rational.compare_decimal(a_part, b_part)
		if by_part != 0 and by_part != right and not mistakes.values().has(_symbol(by_part)):
			mistakes[&"ignored_whole"] = _symbol(by_part)
	if mistakes.is_empty():
		mistakes[&"reversed_symbol"] = _symbol(-right)
	return mistakes


static func _symbol(order: int) -> StringName:
	return SYMBOL_LESS if order < 0 else SYMBOL_GREATER


static func _compare_line(example: Problem) -> Dictionary:
	var p: Dictionary = example.prompt_params
	return {"line_id": &"z7.hint.example_deccmp", "params": {"a": p["a"], "b": p["b"], "symbol": String(example.answer)}}
