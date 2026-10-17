## Primes and composites for Zone 4 (skills prime.*). In the child's words a prime rock is
## "unbreakable": it has no factor pair except 1 x itself. Pure: only the passed-in rng is used.
##
## Modes (params.mode):
##   single   "Is {n} unbreakable?" Yes or no, n from 2 up to params.max (30 to 100). 1 is never asked.
##   set      "Find the {k} unbreakable rocks." Six rocks on an unordered tile board (answer: the
##            primes, smallest first).
##   pairs    The skill that first asks about 1: "How many factor pairs does {n} have?" (a number)
##            or "Look at the factor pairs of {n}. Is {n} a prime?" (yes or no, 1 included).
##
## The named mistakes (a wrong yes or no, or a wrong board, stands for one of them):
##   two_is_not_prime    said the even prime 2 breaks;
##   odd_means_prime     took an odd composite for a prime;
##   square_is_prime     took a square composite (4, 9, 25...) for a prime;
##   one_is_prime        took 1 for a prime;
##   no_check_made       any other yes or no said without looking at the factor pairs.
class_name PrimeCompositeGenerator
extends RefCounted

const PROMPT_SINGLE: StringName = &"z4.prime.prompt_single"
const PROMPT_SET: StringName = &"z4.prime.prompt_set"
const PROMPT_PAIRS_COUNT: StringName = &"z4.prime.prompt_pairs_count"
const PROMPT_PAIRS_PRIME: StringName = &"z4.prime.prompt_pairs_prime"
## The rocks on a set board.
const SET_SIZE: int = 6
## Arrays and hop lines hold at most this many rows, columns or hops.
const MAX_SIDE: int = 10


static func generate(skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Problem:
	return _make(skill, params, rng, true)


static func _make(skill: Skill, params: Dictionary, rng: RandomNumberGenerator, with_hints: bool) -> Problem:
	var mode: String = String(params.get("mode", "single"))
	var problem: Problem = GeneratorKit.new_problem(skill, params, GeneratorKit.pick_representation(skill, params))
	var model: Dictionary
	var example_line: Callable
	match mode:
		"single":
			model = _single(problem, skill, params, rng)
			example_line = _yes_no_line_of
		"set":
			model = _rock_set(problem, skill, params, rng)
			example_line = _set_line_of
		"pairs":
			model = _pairs(problem, skill, params, rng)
			example_line = _pairs_line_of
		_:
			push_error("PrimeCompositeGenerator: unknown mode '%s'" % mode)
			return problem
	if with_hints:
		var example: Problem = GeneratorKit.make_example(
			func(sub: RandomNumberGenerator) -> Problem: return _make(skill, params, sub, false), problem, rng)
		GeneratorKit.add_hints(problem, model, example, example_line.call(example))
	return problem


# --- Number helpers --------------------------------------------------------------------------


static func _is_square(n: int) -> bool:
	var root: int = roundi(sqrt(float(n)))
	return root * root == n


## The numbers from `low` to `high` that satisfy `test`.
static func _select(low: int, high: int, test: Callable) -> Array[int]:
	var found: Array[int] = []
	for n: int in range(low, high + 1):
		if test.call(n):
			found.append(n)
	return found


static func _pick(values: Array[int], rng: RandomNumberGenerator) -> int:
	return values[rng.randi_range(0, values.size() - 1)]


## n / d for a d that divides n (the plain `/` warns about integer division).
static func _partner(n: int, d: int) -> int:
	return floori(float(n) / float(d))


## The mistake behind a wrong "yes" (for a composite or 1) or a wrong "no" (for a prime).
static func _mistake_for(n: int) -> StringName:
	if n == 1:
		return &"one_is_prime"
	if MathUtil.is_prime(n):
		return &"two_is_not_prime" if n == 2 else &"no_check_made"
	if _is_square(n):
		return &"square_is_prime"
	return &"odd_means_prime" if n % 2 == 1 else &"no_check_made"


## Rung 2 for a number: a prime shows its one rectangle (a single row, or one hop that covers the
## whole line); a composite shows a rectangle, or hops of its other factor, made from its smallest
## prime factor.
static func _break_model(n: int) -> Dictionary:
	if n < 2:
		return GeneratorKit.array_picture(1, 1)
	if MathUtil.is_prime(n):
		if n <= MAX_SIDE:
			return GeneratorKit.array_picture(1, n)
		return GeneratorKit.hops_line(1, n)
	var smallest: int = MathUtil.prime_factorization(n)[0]
	var partner: int = _partner(n, smallest)
	if smallest <= MAX_SIDE and partner <= MAX_SIDE:
		return GeneratorKit.array_picture(smallest, partner, true)
	return GeneratorKit.hops_line(smallest, partner)


# --- single ----------------------------------------------------------------------------------


## Which kind of number to ask about, by roll: the even prime, an odd prime, an odd composite, a
## square composite, any other even composite. A kind with no number in range falls back to any.
static func _single(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var low: int = maxi(int(params.get("min", 2)), 2)
	var high: int = GeneratorKit.eased_max(low, int(params.get("max", 30)), GeneratorKit.difficulty_of(params), 8)
	var n: int = _number_for_roll(rng.randi_range(0, 99), low, high, rng)
	problem.prompt_line_id = PROMPT_SINGLE
	problem.prompt_params = {"n": n}
	problem.answer = MathUtil.is_prime(n)
	problem.meta = {"label_lines": GeneratorKit.yes_no_labels()}
	GeneratorKit.add_distractor(problem, skill, not problem.answer, _mistake_for(n))
	return _break_model(n)


static func _number_for_roll(roll: int, low: int, high: int, rng: RandomNumberGenerator) -> int:
	var pool: Array[int] = []
	if roll < 10 and low <= 2:
		return 2
	elif roll < 35:
		pool = _select(maxi(low, 3), high, func(n: int) -> bool: return MathUtil.is_prime(n))
	elif roll < 50:
		pool = _select(low, high, func(n: int) -> bool: return n % 2 == 1 and not MathUtil.is_prime(n) and not _is_square(n))
	elif roll < 65:
		pool = _select(low, high, func(n: int) -> bool: return not MathUtil.is_prime(n) and _is_square(n))
	else:
		pool = _select(low, high, func(n: int) -> bool: return n % 2 == 0 and n > 2 and not _is_square(n))
	if pool.is_empty():
		pool = _select(low, high, func(_n: int) -> bool: return true)
	return _pick(pool, rng)


static func _yes_no_line_of(example: Problem) -> Dictionary:
	return _example_line(example, &"z4.hint.example_prime_yes", &"z4.hint.example_prime_no")


## The worked-example line for a yes/no example: the prime's only pair, the smallest pair of a
## composite, or the line about 1.
static func _example_line(example: Problem, yes_line: StringName, no_line: StringName) -> Dictionary:
	var n: int = example.prompt_params["n"]
	if n == 1:
		return {"line_id": &"z4.prime.one_not_prime", "params": {}}
	if example.answer:
		return {"line_id": yes_line, "params": {"n": n}}
	var smallest: int = MathUtil.prime_factorization(n)[0]
	return {"line_id": no_line, "params": {"a": smallest, "b": _partner(n, smallest), "n": n}}


# --- set -------------------------------------------------------------------------------------


## Six rocks: k = 2 or 3 primes (2 is often one of them), an odd composite, a square composite and
## even composites for the rest. The answer is the primes; each wrong board puts a composite where
## a prime belongs.
static func _rock_set(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var low: int = maxi(int(params.get("min", 2)), 2)
	var high: int = GeneratorKit.eased_max(low, int(params.get("max", 30)), GeneratorKit.difficulty_of(params), 8)
	var k: int = rng.randi_range(2, 3)
	var primes: Array[int] = []
	var prime_pool: Array[int] = _select(low, high, func(n: int) -> bool: return MathUtil.is_prime(n))
	if low <= 2 and rng.randi_range(0, 3) == 0:
		primes.append(2)
		prime_pool.erase(2)
	prime_pool = GeneratorKit.shuffled_ints(prime_pool, rng)
	while primes.size() < k:
		primes.append(prime_pool.pop_back())
	var composites: Array[int] = []
	var odd: Array[int] = _select(low, high, func(n: int) -> bool: return n % 2 == 1 and not MathUtil.is_prime(n) and not _is_square(n))
	if odd.is_empty():
		odd = _select(low, high, func(n: int) -> bool: return n % 2 == 1 and not MathUtil.is_prime(n))
	var squares: Array[int] = _select(low, high, func(n: int) -> bool: return not MathUtil.is_prime(n) and _is_square(n))
	var rest: Array[int] = _select(low, high, func(n: int) -> bool: return not MathUtil.is_prime(n))
	if not odd.is_empty():
		composites.append(_pick(odd, rng))
	var fresh_squares: Array[int] = GeneratorKit.ints_of(squares.filter(func(n: int) -> bool: return not composites.has(n)))
	if not fresh_squares.is_empty():
		composites.append(_pick(fresh_squares, rng))
	rest = GeneratorKit.shuffled_ints(rest, rng)
	for candidate: int in rest:
		if composites.size() >= SET_SIZE - k:
			break
		if not composites.has(candidate):
			composites.append(candidate)
	var rocks: Array[int] = primes + composites
	primes.sort()
	problem.prompt_line_id = PROMPT_SET
	# r1 to r6 are the rocks, smallest first. The line only uses {k}; the rocks are here so two
	# boards with the same k are different problems (a worked example must not repeat the problem).
	problem.prompt_params = {"k": k}
	var ordered: Array[int] = rocks.duplicate()
	ordered.sort()
	for index: int in ordered.size():
		problem.prompt_params["r%d" % (index + 1)] = ordered[index]
	problem.answer = primes
	var odd_ones: Array[int] = GeneratorKit.ints_of(composites.filter(func(n: int) -> bool: return n % 2 == 1))
	var square_ones: Array[int] = GeneratorKit.ints_of(composites.filter(func(n: int) -> bool: return _is_square(n)))
	if not square_ones.is_empty():
		_add_swap(problem, skill, primes, _pick(square_ones, rng), rng, &"square_is_prime")
	if not odd_ones.is_empty():
		_add_swap(problem, skill, primes, _pick(odd_ones, rng), rng, &"odd_means_prime")
	if primes.has(2):
		var without_two: Array[int] = primes.duplicate()
		without_two.erase(2)
		without_two.append(_pick(composites, rng))
		without_two.sort()
		GeneratorKit.add_distractor(problem, skill, without_two, &"two_is_not_prime")
	problem.meta = {"tile_board": {"tiles": GeneratorKit.shuffled_ints(rocks, rng), "slots": k, "ordered": false}}
	return _break_model(_pick(odd_ones if not odd_ones.is_empty() else composites, rng))


## A wrong board: one of the primes (not 2 when 2 is there: that mistake has its own board) is
## replaced by `composite`.
static func _add_swap(problem: Problem, skill: Skill, primes: Array[int], composite: int, rng: RandomNumberGenerator, misconception: StringName) -> void:
	var keepable: Array[int] = GeneratorKit.ints_of(primes.filter(func(p: int) -> bool: return p != 2))
	if keepable.is_empty():
		keepable = primes.duplicate()
	var board: Array[int] = primes.duplicate()
	board.erase(_pick(keepable, rng))
	board.append(composite)
	board.sort()
	GeneratorKit.add_distractor(problem, skill, board, misconception)


static func _set_line_of(example: Problem) -> Dictionary:
	return {"line_id": &"z4.hint.example_prime_yes", "params": {"n": example.answer[0]}}


# --- pairs -----------------------------------------------------------------------------------


## Two questions about factor pairs (a pair is two numbers that multiply to n; 6 x 6 is one pair):
## how many pairs does n have (n from 2), or is n a prime (n from 1: 1 has one factor, not two).
static func _pairs(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var high: int = GeneratorKit.eased_max(4, int(params.get("max", 36)), GeneratorKit.difficulty_of(params), 6)
	if rng.randi_range(0, 1) == 0:
		var n: int = rng.randi_range(2, high)
		var pairs: int = _pair_count(n)
		problem.prompt_line_id = PROMPT_PAIRS_COUNT
		problem.prompt_params = {"n": n}
		problem.answer = pairs
		GeneratorKit.add_distractor(problem, skill, MathUtil.factors(n).size(), &"counted_factors_not_pairs")
		GeneratorKit.add_distractor(problem, skill, pairs - 1, &"missing_one_and_n")
		GeneratorKit.add_distractor(problem, skill, pairs + 1, &"off_by_one")
		return _break_model(n)
	var roll: int = rng.randi_range(0, 99)
	var m: int
	if roll < 20:
		m = 1
	elif roll < 30:
		m = 2
	else:
		m = rng.randi_range(3, high)
	problem.prompt_line_id = PROMPT_PAIRS_PRIME
	problem.prompt_params = {"n": m}
	problem.answer = MathUtil.is_prime(m)
	problem.meta = {"label_lines": GeneratorKit.yes_no_labels()}
	GeneratorKit.add_distractor(problem, skill, not problem.answer, _mistake_for(m))
	return _break_model(m)


## How many factor pairs n has (6 x 6 counts once).
static func _pair_count(n: int) -> int:
	var count: int = 0
	for d: int in MathUtil.factors(n):
		if d * d <= n:
			count += 1
	return count


static func _pairs_line_of(example: Problem) -> Dictionary:
	var n: int = example.prompt_params["n"]
	if example.prompt_line_id == PROMPT_PAIRS_COUNT:
		return {"line_id": &"z4.hint.example_pairs", "params": {"n": n, "c": example.answer}}
	return _example_line(example, &"z4.hint.example_isprime_yes", &"z4.hint.example_isprime_no")
