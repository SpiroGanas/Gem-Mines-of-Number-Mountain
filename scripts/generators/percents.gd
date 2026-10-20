## Percents for Zone 7, Crystal Shards (skills percent.*): "percent" means "out of 100", so the picture
## is the 10 by 10 crystal grid. params.mode picks the question:
##   of_hundred     {p} of the 100 cells are lit: what percent is lit?  answer p
##   from_fraction  {num}/{den} of the grid is lit: what percent is that?  den comes from params.dens,
##                  every one of which divides 100, so the percent is a whole number
## The answer is the percent as an int (meta.percent puts "%" on the answer buttons). Pure: only the
## passed-in rng is used.
##
## The named mistakes:
##   counted_unlit               counted the dark cells (100 - p);
##   place_shift                 read the percent one place off (37 as 3, 5 as 50);
##   wrote_numerator_as_percent  wrote the top of the fraction as the percent (3/4 as 3%).
class_name PercentGenerator
extends RefCounted


static func generate(skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Problem:
	return _make(skill, params, rng, true)


static func _make(skill: Skill, params: Dictionary, rng: RandomNumberGenerator, with_hints: bool) -> Problem:
	var problem: Problem = GeneratorKit.new_problem(skill, params, GeneratorKit.pick_representation(skill, params))
	var percent: int = 0
	if str(params.get("mode", "of_hundred")) == "from_fraction":
		var dens: Array[int] = GeneratorKit.ints_of(params.get("dens", [2, 4, 5, 10, 20, 25, 50]))
		if GeneratorKit.difficulty_of(params) < 0:
			dens = dens.filter(func(den: int) -> bool: return den <= 10)
		var den: int = dens[rng.randi_range(0, dens.size() - 1)]
		var num: int = rng.randi_range(1, den - 1)
		percent = int(Rational.to_decimal(num, den, 2)["mantissa"])
		problem.prompt_line_id = &"z7.pctfrac.prompt"
		problem.prompt_params = {"num": num, "den": den}
		problem.answer = percent
		GeneratorKit.add_distractor(problem, skill, num, &"wrote_numerator_as_percent")
		GeneratorKit.add_distractor(problem, skill, place_shifted(percent), &"place_shift")
	else:
		var top: int = GeneratorKit.eased_max(1, 99, GeneratorKit.difficulty_of(params), 9)
		percent = rng.randi_range(1, top)
		problem.prompt_line_id = &"z7.percent.prompt"
		problem.prompt_params = {}
		problem.answer = percent
		problem.visual = DecimalGenerator.grid(100, [DecimalGenerator.grid_entry(0, percent)])
		GeneratorKit.add_distractor(problem, skill, 100 - percent, &"counted_unlit")
		GeneratorKit.add_distractor(problem, skill, place_shifted(percent), &"place_shift")
	problem.meta["percent"] = true
	if with_hints:
		var example: Problem = GeneratorKit.make_example(
			func(sub: RandomNumberGenerator) -> Problem: return _make(skill, params, sub, false), problem, rng)
		GeneratorKit.add_hints(problem, DecimalGenerator.grid(100, [DecimalGenerator.grid_entry(0, percent)]), example, _example_line(example))
	return problem


## A percent read one place off: under 10 it gains a zero (5 becomes 50); from 10 it loses its last
## digit (37 becomes 3), the way 0.37 read as 0.3 would.
static func place_shifted(percent: int) -> int:
	return percent * 10 if percent < 10 else floori(percent / 10.0)


static func _example_line(example: Problem) -> Dictionary:
	if example.prompt_line_id == &"z7.pctfrac.prompt":
		return {"line_id": &"z7.hint.example_pctfrac", "params": {"num": example.prompt_params["num"], "den": example.prompt_params["den"], "p": example.answer}}
	return {"line_id": &"z7.hint.example_percent", "params": {"p": example.answer}}
