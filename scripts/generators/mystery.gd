## The Unsolved Mysteries of Zone 12, The Infinite Core (skills mystery.goldbach.find_pair and mystery.twin.next_pair).
## Two questions nobody has answered for every number: can every even number above 2 be written as two primes (Goldbach),
## and are there always more twin primes (two primes 2 apart)? The child works on small cases, where the answer can be
## found. Pure: only the passed-in rng is used.
##
## Modes (params.mode):
##   goldbach  "Which two primes add up to {n}?" n is even, 4 to params.max_n. The answer is the pair written "p + q"
##             (p <= q); the wrong answers are sums that are not prime pairs of n, so exactly one choice is right even
##             though some n have several pairs.
##   twin      "Find the next twin primes after {p}. What is the smaller one?" The answer is the smaller prime q of the
##             first twin pair (q, q + 2) with q > p, typed on the pad. p is 2 to params.max_p.
##
## The named mistakes:
##   used_composite    a pair that adds up to n with one number that is not prime;
##   sum_off           two primes that add up to n + 2 or n - 2;
##   gave_larger_prime the larger prime of the twin pair (named first: the cousin below can be the same number);
##   gap_not_two       the smaller of the next pair of primes that are 4 apart (cousin primes);
##   not_both_prime    a number with a prime 2 above it that is not prime itself.
## A pictorial problem shows a number line (Goldbach: to n with n marked; twins: the window from p, with p marked).
class_name MysteryGenerator
extends RefCounted

const PROMPT_GOLDBACH: StringName = &"z12.mystery.prompt_goldbach"
const PROMPT_TWIN: StringName = &"z12.mystery.prompt_twin"
const MAX_N: int = 100
const MAX_P: int = 190


static func generate(skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Problem:
	return _make(skill, params, rng, true)


## Every way to write the even number n as p + q with p <= q both prime, smallest p first.
static func goldbach_pairs(n: int) -> Array[Vector2i]:
	var pairs: Array[Vector2i] = []
	for p: int in range(2, floori(n / 2.0) + 1):
		if MathUtil.is_prime(p) and MathUtil.is_prime(n - p):
			pairs.append(Vector2i(p, n - p))
	return pairs


## The smaller prime of the first twin pair (q, q + 2) with q > p.
static func next_twin(p: int) -> int:
	var q: int = p + 1
	while not (MathUtil.is_prime(q) and MathUtil.is_prime(q + 2)):
		q += 1
	return q


static func pair_text(p: int, q: int) -> String:
	return "%d + %d" % [p, q]


static func _make(skill: Skill, params: Dictionary, rng: RandomNumberGenerator, with_hints: bool) -> Problem:
	var mode: String = String(params.get("mode", "goldbach"))
	var problem: Problem = GeneratorKit.new_problem(skill, params, GeneratorKit.pick_representation(skill, params))
	var model: Dictionary
	match mode:
		"goldbach":
			model = _goldbach(problem, skill, params, rng)
		"twin":
			model = _twin(problem, skill, params, rng)
		_:
			push_error("MysteryGenerator: unknown mode '%s'" % mode)
			return problem
	if with_hints:
		var example: Problem = GeneratorKit.make_example(
			func(sub: RandomNumberGenerator) -> Problem: return _make(skill, params, sub, false), problem, rng)
		GeneratorKit.add_hints(problem, model, example, _example_line(mode, example))
	return problem


static func _goldbach(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var high: int = GeneratorKit.eased_max(4, mini(int(params.get("max_n", MAX_N)), MAX_N), GeneratorKit.difficulty_of(params), 6)
	var low: int = maxi(int(params.get("min_n", 4)), 4)
	var n: int = rng.randi_range(floori(low / 2.0), floori(high / 2.0)) * 2
	var pairs: Array[Vector2i] = goldbach_pairs(n)
	var chosen: Vector2i = pairs[rng.randi_range(0, pairs.size() - 1)]
	problem.prompt_line_id = PROMPT_GOLDBACH
	problem.prompt_params = {"n": n}
	problem.answer = pair_text(chosen.x, chosen.y)
	problem.meta = {"pairs": _pair_texts(pairs)}
	var line: Dictionary = GeneratorKit.number_line(0, ceili(n / 10.0) * 10, 10, GeneratorKit.ints_of([n]), [])
	if problem.representation == &"pictorial":
		problem.visual = line
	# used_composite: a pair adding up to n where one number is not prime.
	var composites: Array[Vector2i] = []
	for a: int in range(1, floori(n / 2.0) + 1):
		if a != n - a and (not MathUtil.is_prime(a) or not MathUtil.is_prime(n - a)) and (MathUtil.is_prime(a) or MathUtil.is_prime(n - a)):
			composites.append(Vector2i(a, n - a))
	if not composites.is_empty():
		var pick: Vector2i = composites[rng.randi_range(0, composites.size() - 1)]
		GeneratorKit.add_distractor(problem, skill, pair_text(pick.x, pick.y), &"used_composite")
	# sum_off: two primes adding up to n + 2 or n - 2.
	var off: Array[Vector2i] = []
	for target: int in [n - 2, n + 2]:
		if target >= 4:
			for pair: Vector2i in goldbach_pairs(target) if target % 2 == 0 else ([] as Array[Vector2i]):
				off.append(pair)
	if not off.is_empty():
		var near: Vector2i = off[rng.randi_range(0, off.size() - 1)]
		GeneratorKit.add_distractor(problem, skill, pair_text(near.x, near.y), &"sum_off")
	if problem.distractors.size() < 2: # tiny n: another off pair from n + 4
		for pair: Vector2i in goldbach_pairs(n + 4):
			GeneratorKit.add_distractor(problem, skill, pair_text(pair.x, pair.y), &"sum_off")
			if problem.distractors.size() >= 2:
				break
	return line


static func _twin(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var high: int = GeneratorKit.eased_max(2, mini(int(params.get("max_p", MAX_P)), MAX_P), GeneratorKit.difficulty_of(params), 20)
	var p: int = rng.randi_range(maxi(int(params.get("min_p", 2)), 2), high)
	var q: int = next_twin(p)
	problem.prompt_line_id = PROMPT_TWIN
	problem.prompt_params = {"p": p}
	problem.answer = q
	problem.meta = {"pad_digits": 3}
	# gave_larger_prime first: when the cousin prime below is the same number (10: twins 11 and 13, cousins 13 and 17)
	# the child who answers the larger twin must hear about the larger twin, not the gap (peer review 05).
	GeneratorKit.add_distractor(problem, skill, q + 2, &"gave_larger_prime")
	# gap_not_two: the smaller prime of the next two primes that are 4 apart.
	var cousin: int = p + 1
	while not (MathUtil.is_prime(cousin) and MathUtil.is_prime(cousin + 4)):
		cousin += 1
	GeneratorKit.add_distractor(problem, skill, cousin, &"gap_not_two")
	# not_both_prime: a number above p with a prime 2 above it that is itself not prime.
	var fake: int = p + 1
	while not (fake > 1 and not MathUtil.is_prime(fake) and MathUtil.is_prime(fake + 2)):
		fake += 1
	GeneratorKit.add_distractor(problem, skill, fake, &"not_both_prime")
	var window: Vector2i = GeneratorKit.window_around(GeneratorKit.ints_of([p, q + 2]), 0, 220)
	var every: int = 10 if window.y - window.x <= 60 else 20
	if problem.representation == &"pictorial": # the picture marks only the start; the rung 2 model adds the pair
		problem.visual = GeneratorKit.number_line(window.x, window.y, every, GeneratorKit.ints_of([p]), [])
	return GeneratorKit.number_line(window.x, window.y, every, GeneratorKit.ints_of([p, q, q + 2]), [])


static func _pair_texts(pairs: Array[Vector2i]) -> Array[String]:
	var texts: Array[String] = []
	for pair: Vector2i in pairs:
		texts.append(pair_text(pair.x, pair.y))
	return texts


static func _example_line(mode: String, example: Problem) -> Dictionary:
	if mode == "twin":
		return {"line_id": &"z12.hint.example_twin", "params": {"q": example.answer, "r": int(example.answer) + 2}}
	var numbers: PackedStringArray = str(example.answer).split(" + ")
	return {"line_id": &"z12.hint.example_goldbach", "params": {"p": int(numbers[0]), "q": int(numbers[1]), "n": example.prompt_params["n"]}}
