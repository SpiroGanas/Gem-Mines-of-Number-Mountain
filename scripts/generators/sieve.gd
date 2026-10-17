## The Sieve of Eratosthenes for Zone 5 (skills sieve.*). A grid of numbered rocks from 1 to `size`
## (ten to a row); the child taps rocks to cross them out and presses Done (SieveGrid). The answer is
## every crossed-out rock when Done is pressed, smallest first. Pure: only the passed-in rng is used.
##
## Modes (params.mode):
##   multiples  "Cross out every multiple of {p}. Keep {p} itself." p from params.primes. The grid
##              shows an earlier part of the sieve already done: 1 and every multiple of a smaller
##              prime are crossed out (and stay crossed). The answer adds 2p, 3p... up to the grid's end.
##   primes     "Cross out every rock that is not a prime." The multiples of every prime up to q
##              (q from params.done) are crossed already, so what is left is 1, the squares and the
##              other composites whose smallest factor is bigger than q. The answer: 1 and every
##              composite on the grid.
##
## meta.sieve_grid = {size, cols, precrossed}: the rocks crossed before the child starts. They cannot
## be un-crossed, so every answer and every wrong board contains them.
##
## The named mistakes (a wrong board stands for one of them):
##   crossed_p_itself      crossed out a prime as well as its multiples;
##   missed_p_squared      the multiples mode without p x p (the first one not already crossed);
##   missed_last_multiple  the multiples mode without the last multiple on the grid;
##   one_is_prime          the primes mode with 1 left standing;
##   square_is_prime       the primes mode with a square (25, 49) left standing;
##   odd_means_prime       the primes mode with an odd composite (35, 77) left standing.
class_name SieveGenerator
extends RefCounted

const PROMPT_MULTIPLES: StringName = &"z5.sieve.prompt_multiples"
const PROMPT_PRIMES: StringName = &"z5.sieve.prompt_primes"
const COLUMNS: int = 10
## A hop line draws at most this many hops.
const MAX_HOPS: int = 10


static func generate(skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Problem:
	return _make(skill, params, rng, true)


static func _make(skill: Skill, params: Dictionary, rng: RandomNumberGenerator, with_hints: bool) -> Problem:
	var mode: String = String(params.get("mode", "multiples"))
	var problem: Problem = GeneratorKit.new_problem(skill, params, GeneratorKit.pick_representation(skill, params))
	var model: Dictionary
	var example_line: Callable
	match mode:
		"multiples":
			model = _multiples(problem, skill, params, rng)
			example_line = _multiples_line_of
		"primes":
			model = _primes(problem, skill, params, rng)
			example_line = _primes_line_of
		_:
			push_error("SieveGenerator: unknown mode '%s'" % mode)
			return problem
	if with_hints:
		# A primes grid differs from another only by q, so the example always takes another q.
		var example_params: Dictionary = params.duplicate(true)
		if mode == "primes" and GeneratorKit.ints_of(params.get("done", [])).size() > 1:
			var others: Array[int] = GeneratorKit.ints_of(params["done"])
			others.erase(int(problem.prompt_params["q"]))
			example_params["done"] = others
		var example: Problem = GeneratorKit.make_example(
			func(sub: RandomNumberGenerator) -> Problem: return _make(skill, example_params, sub, false), problem, rng)
		GeneratorKit.add_hints(problem, model, example, example_line.call(example))
	return problem


# --- Number helpers --------------------------------------------------------------------------


## The smallest prime factor of n (n itself for a prime; 0 for n < 2).
static func smallest_factor(n: int) -> int:
	if n < 2:
		return 0
	return MathUtil.prime_factorization(n)[0]


static func _is_composite(n: int) -> bool:
	return n >= 4 and not MathUtil.is_prime(n)


static func _sorted_with(values: Array[int], extra: int) -> Array[int]:
	var result: Array[int] = values.duplicate()
	if not result.has(extra):
		result.append(extra)
	result.sort()
	return result


static func _sorted_without(values: Array[int], gone: int) -> Array[int]:
	var result: Array[int] = values.duplicate()
	result.erase(gone)
	return result


static func _grid_meta(size: int, precrossed: Array[int]) -> Dictionary:
	return {"sieve_grid": {"size": size, "cols": COLUMNS, "precrossed": precrossed}}


# --- multiples -------------------------------------------------------------------------------


static func _multiples(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var primes: Array[int] = GeneratorKit.ints_of(params.get("primes", [2, 3, 5]))
	var p: int = primes[rng.randi_range(0, primes.size() - 1)]
	var low_rows: int = maxi(ceili(int(params.get("min_size", 30)) / 10.0), 1)
	var high_rows: int = maxi(floori(int(params.get("max_size", 50)) / 10.0), low_rows)
	high_rows = GeneratorKit.eased_max(low_rows, high_rows, GeneratorKit.difficulty_of(params), 1)
	var size: int = rng.randi_range(low_rows, high_rows) * COLUMNS
	if p * p > size:
		size = ceili(float(p * p) / COLUMNS) * COLUMNS # the grid always reaches p x p
	var precrossed: Array[int] = [1]
	var answer: Array[int] = [1]
	for n: int in range(2, size + 1):
		var smallest: int = smallest_factor(n)
		if _is_composite(n) and smallest < p:
			precrossed.append(n)
			answer.append(n)
		elif n != p and n % p == 0:
			answer.append(n)
	problem.prompt_line_id = PROMPT_MULTIPLES
	problem.prompt_params = {"p": p, "size": size}
	problem.answer = answer
	problem.meta = _grid_meta(size, precrossed)
	GeneratorKit.add_distractor(problem, skill, _sorted_with(answer, p), &"crossed_p_itself")
	GeneratorKit.add_distractor(problem, skill, _sorted_without(answer, p * p), &"missed_p_squared")
	# The last multiple the child crosses (one with a smaller prime factor was crossed already).
	var last: int = floori(float(size) / p) * p
	while smallest_factor(last) != p:
		last -= p
	if last != p * p:
		GeneratorKit.add_distractor(problem, skill, _sorted_without(answer, last), &"missed_last_multiple")
	return GeneratorKit.hops_line(mini(floori(float(size) / p), MAX_HOPS), p)


static func _multiples_line_of(example: Problem) -> Dictionary:
	var p: int = example.prompt_params["p"]
	return {"line_id": &"z5.hint.example_sieve_multiples", "params": {"p": p, "a": 2 * p, "b": 3 * p, "c": 4 * p}}


# --- primes ----------------------------------------------------------------------------------


static func _primes(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var size: int = int(params.get("size", 50))
	var done: Array[int] = GeneratorKit.ints_of(params.get("done", [2]))
	var q: int = done[rng.randi_range(0, done.size() - 1)]
	var precrossed: Array[int] = []
	var answer: Array[int] = [1]
	var squares: Array[int] = []
	var odd_ones: Array[int] = []
	for n: int in range(2, size + 1):
		if not _is_composite(n):
			continue
		answer.append(n)
		var smallest: int = smallest_factor(n)
		if smallest <= q:
			precrossed.append(n)
		elif smallest * smallest == n:
			squares.append(n)
		else:
			odd_ones.append(n)
	problem.prompt_line_id = PROMPT_PRIMES
	problem.prompt_params = {"size": size, "q": q}
	problem.answer = answer
	problem.meta = _grid_meta(size, precrossed)
	GeneratorKit.add_distractor(problem, skill, _sorted_without(answer, 1), &"one_is_prime")
	var square: int = squares.max() if not squares.is_empty() else 0
	if square > 0:
		GeneratorKit.add_distractor(problem, skill, _sorted_without(answer, square), &"square_is_prime")
	if not odd_ones.is_empty():
		GeneratorKit.add_distractor(problem, skill, _sorted_without(answer, odd_ones[rng.randi_range(0, odd_ones.size() - 1)]), &"odd_means_prime")
	var next_prime: int = q + 1
	while not MathUtil.is_prime(next_prime):
		next_prime += 1
	if next_prime <= size:
		GeneratorKit.add_distractor(problem, skill, _sorted_with(answer, next_prime), &"crossed_p_itself")
	var root: int = roundi(sqrt(float(square))) if square > 0 else 2
	return GeneratorKit.array_picture(root, root, true)


static func _primes_line_of(example: Problem) -> Dictionary:
	var q: int = example.prompt_params["q"]
	var size: int = example.prompt_params["size"]
	# The first rock the child must cross: the smallest composite whose smallest factor is above q.
	for n: int in range(4, size + 1):
		var smallest: int = smallest_factor(n)
		if _is_composite(n) and smallest > q:
			return {"line_id": &"z5.hint.example_sieve_primes", "params": {"n": n, "a": smallest, "b": floori(float(n) / smallest)}}
	return {"line_id": &"z4.prime.one_not_prime", "params": {}}
