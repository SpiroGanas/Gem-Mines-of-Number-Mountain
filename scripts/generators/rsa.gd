## A toy lock with a public and a private key for Zone 11, Cipher Vault (skills rsa.toy.*): the RSA idea at a size a
## child can follow. Two primes p and q make n = p × q and a loop size t = (p - 1) × (q - 1). A public key e (no common
## factor with t) locks a number m as c = m^e on the loop of n; the private key d (e × d lands on 1 on the loop of t)
## unlocks it: c^d on the loop of n is m again. Primes stay small (at most 11) so every number fits on the screen.
## Powers are worked out with square-and-multiply (pow_mod), never by writing the whole power. Pure: only the
## passed-in rng is used.
##
## A lock whose keys are in play (find d, lock, unlock) is always a real lock (is_real_key): the private key differs
## from the public key (on the loops of 8, 12 and 24 every key is its own undo partner, so primes 3, 5 and 7 alone
## never make one) and locking changes some numbers (e is never 1 on the loop of lcm(p - 1, q - 1), which would make
## every m^e = m). The locked number m is one the lock changes. params.max_d (optional) caps the private key so the
## unlocking power stays small enough to work out by hand; a negative difficulty keeps the smaller exponents.
##
## Modes (params.mode):
##   keygen   a random pick of two questions about a lock: "Lock primes: {p} and {q}. Find (p - 1) × (q - 1)." (the
##            loop size t), or "The loop has {t} stations. The public key is {e}. Find d: {e} × d lands on 1." (d).
##   encrypt  "Raise {m} to the power {e}. Then wrap on a loop of {n}." The answer is c.
##   decrypt  "Raise {c} to the power {d}. Then wrap on a loop of {n}." The answer is the number that was locked.
##
## The named mistakes:
##   used_n_not_phi     n = p × q instead of (p - 1) × (q - 1);
##   forgot_minus_one   p × (q - 1), taking one off only one prime;
##   added_instead      (p - 1) + (q - 1);
##   used_e_as_d        the public key as the private key;
##   gave_additive_inverse  t - e;
##   off_by_one         d one along;
##   used_d_not_e       (encrypt) used the private key to lock;
##   multiplied_instead m × e on the loop;
##   forgot_mod_wrap    the raw power, when it is small enough to write;
##   used_e_not_d       (decrypt) used the public key to unlock;
##   gave_cipher        the locked number itself.
class_name RsaGenerator
extends RefCounted

const PROMPT_PHI: StringName = &"z11.rsa.prompt_phi"
const PROMPT_D: StringName = &"z11.rsa.prompt_d"
const PROMPT_ENCRYPT: StringName = &"z11.rsa.prompt_encrypt"
const PROMPT_DECRYPT: StringName = &"z11.rsa.prompt_decrypt"
## Public keys the lock may use, smallest first.
const E_CHOICES: Array[int] = [3, 5, 7, 11, 13, 17, 19, 23]
## A raw power is shown as a wrong answer only when it is this small.
const MAX_RAW: int = 9999


static func generate(skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Problem:
	return _make(skill, params, rng, true)


## base^exp on the loop of n by square-and-multiply: every number stays below n².
static func pow_mod(base: int, exp: int, n: int) -> int:
	var result: int = 1
	var square: int = posmod(base, n)
	var left: int = exp
	while left > 0:
		if left % 2 == 1:
			result = posmod(result * square, n)
		square = posmod(square * square, n)
		left = floori(float(left) / 2.0)
	return result


## The private key d for public key e on the loop of t: the d from 1 to t - 1 with e × d landing on 1 (0 when none).
static func private_key(e: int, t: int) -> int:
	for d: int in range(1, t):
		if posmod(e * d, t) == 1:
			return d
	return 0


## True when e is a public key worth teaching with for primes p and q: below t = (p - 1) × (q - 1) and sharing nothing
## with it but 1, with a private key that is a different number, and not 1 on the loop of lcm(p - 1, q - 1) (such an e
## leaves every number where it was: m^e = m).
static func is_real_key(e: int, p: int, q: int) -> bool:
	var t: int = (p - 1) * (q - 1)
	if e < 2 or e >= t or MathUtil.gcd(e, t) != 1:
		return false
	var d: int = private_key(e, t)
	return d != e and posmod(e, MathUtil.lcm(p - 1, q - 1)) != 1


## Every real lock (is_real_key) from these primes and public keys, p < q, the private key at most `max_d` (0: no cap),
## in a fixed order: by n, then by e.
static func real_locks(primes: Array[int], e_choices: Array[int], max_d: int = 0) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var sorted_primes: Array[int] = primes.duplicate()
	sorted_primes.sort()
	for i: int in sorted_primes.size():
		for j: int in range(i + 1, sorted_primes.size()):
			var p: int = sorted_primes[i]
			var q: int = sorted_primes[j]
			var t: int = (p - 1) * (q - 1)
			for e: int in e_choices:
				if not is_real_key(e, p, q):
					continue
				var d: int = private_key(e, t)
				if max_d > 0 and d > max_d:
					continue
				found.append({"p": p, "q": q, "n": p * q, "t": t, "e": e, "d": d})
	return found


static func _make(skill: Skill, params: Dictionary, rng: RandomNumberGenerator, with_hints: bool) -> Problem:
	var mode: String = String(params.get("mode", "keygen"))
	var problem: Problem = GeneratorKit.new_problem(skill, params, GeneratorKit.pick_representation(skill, params))
	var primes: Array[int] = GeneratorKit.ints_of(params.get("primes", [3, 5, 7, 11, 13]))
	var difficulty: int = GeneratorKit.difficulty_of(params)
	var model: Dictionary
	match mode:
		"keygen":
			var ask_t: bool = rng.randi_range(0, 1) == 0
			# The loop size needs no keys, so any two primes will do; the private key needs a real lock.
			var lock: Dictionary = _any_pair(primes, rng) if ask_t else _real_lock(primes, params, rng, difficulty, "t")
			model = _keygen(problem, skill, lock, ask_t)
		"encrypt":
			model = _encrypt(problem, skill, _real_lock(primes, params, rng, difficulty, "e"), rng, difficulty)
		"decrypt":
			model = _decrypt(problem, skill, _real_lock(primes, params, rng, difficulty, "d"), rng, difficulty)
		_:
			push_error("RsaGenerator: unknown generator mode '%s'" % mode)
			return problem
	if with_hints:
		var example: Problem = GeneratorKit.make_example(
			func(sub: RandomNumberGenerator) -> Problem: return _make(skill, params, sub, false), problem, rng)
		GeneratorKit.add_hints(problem, model, example, _example_line(mode, example))
	return problem


## Two different primes and their loop size for the "find t" question; the keys are the first that work (or a plain
## coprime pair when the primes make no real lock), since the question never uses them.
static func _any_pair(primes: Array[int], rng: RandomNumberGenerator) -> Dictionary:
	var p: int = primes[rng.randi_range(0, primes.size() - 1)]
	var q: int = p
	for attempt: int in 40:
		q = primes[rng.randi_range(0, primes.size() - 1)]
		if q != p:
			break
	if q == p:
		q = 11 if p != 11 else 3
	var low: int = mini(p, q)
	var high: int = maxi(p, q)
	var t: int = (low - 1) * (high - 1)
	var e: int = 0
	for choice: int in E_CHOICES:
		if is_real_key(choice, low, high):
			e = choice
			break
	if e == 0: # no real key for these primes: the first key that undoes at all (the question never uses it)
		for choice: int in E_CHOICES:
			if choice < t and MathUtil.gcd(choice, t) == 1:
				e = choice
				break
	if e == 0:
		e = 1
	return {"p": low, "q": high, "n": low * high, "t": t, "e": e, "d": private_key(e, t)}


## A real lock (is_real_key) from params.primes, params.e_choices and params.max_d. `measure` is what makes the lock's
## question hard ("t" the loop size, "e" the locking power, "d" the unlocking power): at a negative difficulty only the
## smaller part of the locks, by that measure, is drawn from (GeneratorKit.eased_max). Falls back to 3 and 11 with
## e = 3 (d = 7) when the params allow no real lock.
static func _real_lock(primes: Array[int], params: Dictionary, rng: RandomNumberGenerator, difficulty: int, measure: String) -> Dictionary:
	var choices: Array[Dictionary] = real_locks(primes, GeneratorKit.ints_of(params.get("e_choices", E_CHOICES)), int(params.get("max_d", 0)))
	if choices.is_empty():
		return {"p": 3, "q": 11, "n": 33, "t": 20, "e": 3, "d": 7}
	var ordered: Array[Dictionary] = _ordered_by(choices, measure)
	var count: int = GeneratorKit.eased_max(1, ordered.size(), difficulty, 1)
	return ordered[rng.randi_range(0, count - 1)].duplicate()


## The locks from smallest to largest by `measure`, then by n (a plain selection sort: the list is at most a few dozen).
static func _ordered_by(choices: Array[Dictionary], measure: String) -> Array[Dictionary]:
	var left: Array[Dictionary] = choices.duplicate()
	var ordered: Array[Dictionary] = []
	while not left.is_empty():
		var best: int = 0
		for index: int in range(1, left.size()):
			var a: Dictionary = left[index]
			var b: Dictionary = left[best]
			if int(a[measure]) < int(b[measure]) or (int(a[measure]) == int(b[measure]) and int(a["n"]) < int(b["n"])):
				best = index
		ordered.append(left[best])
		left.remove_at(best)
	return ordered


## A number from 2 to n - 1 that the lock changes (m^e is not m on the loop of n): the first such number at or after a
## random start. At a negative difficulty the numbers stay small. 2 if the lock changes nothing (never for a real lock).
static func _number_to_lock(lock: Dictionary, rng: RandomNumberGenerator, difficulty: int) -> int:
	var n: int = lock["n"]
	var e: int = lock["e"]
	var high: int = GeneratorKit.eased_max(2, n - 1, difficulty, 4)
	var start: int = rng.randi_range(2, high)
	for step: int in high - 1: # the numbers 2 to high, from the random start round
		var m: int = 2 + posmod(start - 2 + step, high - 1)
		if pow_mod(m, e, n) != m:
			return m
	for m: int in range(high + 1, n): # every small number is a fixed point: the first bigger one that is not
		if pow_mod(m, e, n) != m:
			return m
	return 2


static func _keygen(problem: Problem, skill: Skill, lock: Dictionary, ask_t: bool) -> Dictionary:
	var p: int = lock["p"]
	var q: int = lock["q"]
	var t: int = lock["t"]
	var e: int = lock["e"]
	problem.meta = {"lock": lock.duplicate()}
	var picture: Dictionary
	if ask_t:
		problem.prompt_line_id = PROMPT_PHI
		problem.prompt_params = {"p": p, "q": q}
		problem.answer = t
		problem.meta["ask"] = "t"
		GeneratorKit.add_distractor(problem, skill, p * q, &"used_n_not_phi")
		GeneratorKit.add_distractor(problem, skill, p * (q - 1), &"forgot_minus_one")
		GeneratorKit.add_distractor(problem, skill, (p - 1) + (q - 1), &"added_instead")
		picture = GeneratorKit.array_picture(p - 1, q - 1) # (p - 1) rows of (q - 1) gems
	else:
		problem.prompt_line_id = PROMPT_D
		problem.prompt_params = {"t": t, "e": e}
		problem.answer = lock["d"]
		problem.meta["ask"] = "d"
		GeneratorKit.add_distractor(problem, skill, e, &"used_e_as_d")
		GeneratorKit.add_distractor(problem, skill, t - e, &"gave_additive_inverse")
		GeneratorKit.add_distractor(problem, skill, int(lock["d"]) + 1 if int(lock["d"]) + 1 < t else int(lock["d"]) - 1, &"off_by_one")
		picture = EuclidGenerator.euclid_picture(t, e, -1)
	if problem.representation == &"pictorial":
		problem.visual = picture
	return picture


static func _encrypt(problem: Problem, skill: Skill, lock: Dictionary, rng: RandomNumberGenerator, difficulty: int) -> Dictionary:
	var n: int = lock["n"]
	var e: int = lock["e"]
	var m: int = _number_to_lock(lock, rng, difficulty)
	problem.prompt_line_id = PROMPT_ENCRYPT
	problem.prompt_params = {"m": m, "e": e, "n": n}
	problem.answer = pow_mod(m, e, n)
	problem.meta = {"lock": lock.duplicate(), "m": m}
	GeneratorKit.add_distractor(problem, skill, pow_mod(m, int(lock["d"]), n), &"used_d_not_e")
	GeneratorKit.add_distractor(problem, skill, posmod(m * e, n), &"multiplied_instead")
	var raw: int = m
	for step: int in e - 1:
		raw *= m
		if raw > MAX_RAW:
			break
	if raw <= MAX_RAW:
		GeneratorKit.add_distractor(problem, skill, raw, &"forgot_mod_wrap")
	if problem.representation == &"pictorial":
		problem.visual = {"type": "notation", "form": "power", "base": m, "exp": e}
	return {"type": "notation", "form": "power", "base": m, "exp": e}


static func _decrypt(problem: Problem, skill: Skill, lock: Dictionary, rng: RandomNumberGenerator, difficulty: int) -> Dictionary:
	var n: int = lock["n"]
	var d: int = lock["d"]
	var m: int = _number_to_lock(lock, rng, difficulty)
	var c: int = pow_mod(m, int(lock["e"]), n)
	problem.prompt_line_id = PROMPT_DECRYPT
	problem.prompt_params = {"c": c, "d": d, "n": n}
	problem.answer = m
	problem.meta = {"lock": lock.duplicate(), "c": c}
	GeneratorKit.add_distractor(problem, skill, pow_mod(c, int(lock["e"]), n), &"used_e_not_d")
	GeneratorKit.add_distractor(problem, skill, c, &"gave_cipher")
	if problem.representation == &"pictorial":
		problem.visual = {"type": "notation", "form": "power", "base": c, "exp": d}
	return {"type": "notation", "form": "power", "base": c, "exp": d}


static func _example_line(mode: String, example: Problem) -> Dictionary:
	var p: Dictionary = example.prompt_params
	match mode:
		"keygen":
			if example.meta["ask"] == "t":
				return {"line_id": &"z11.hint.example_phi", "params": {"p": p["p"], "q": p["q"], "t": example.answer}}
			return {"line_id": &"z11.hint.example_d", "params": {"e": p["e"], "d": example.answer, "t": p["t"]}}
		"encrypt":
			return {"line_id": &"z11.hint.example_encrypt", "params": {"m": p["m"], "e": p["e"], "n": p["n"], "c": example.answer}}
	return {"line_id": &"z11.hint.example_decrypt", "params": {"c": p["c"], "d": p["d"], "n": p["n"], "m": example.answer}}
