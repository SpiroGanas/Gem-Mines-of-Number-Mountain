## A toy lock with a public and a private key for Zone 11, Cipher Vault (skills rsa.toy.*): the RSA idea at a size a
## child can follow. Two primes p and q make n = p × q and a loop size t = (p - 1) × (q - 1). A public key e (no common
## factor with t) locks a number m as c = m^e on the loop of n; the private key d (e × d lands on 1 on the loop of t)
## unlocks it: c^d on the loop of n is m again. Primes stay small (at most 11) so every number fits on the screen.
## Powers are worked out with square-and-multiply (pow_mod), never by writing the whole power. Pure: only the
## passed-in rng is used.
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


static func _make(skill: Skill, params: Dictionary, rng: RandomNumberGenerator, with_hints: bool) -> Problem:
	var mode: String = String(params.get("mode", "keygen"))
	var problem: Problem = GeneratorKit.new_problem(skill, params, GeneratorKit.pick_representation(skill, params))
	var primes: Array[int] = GeneratorKit.ints_of(params.get("primes", [3, 5, 7, 11, 13]))
	var lock: Dictionary = _lock(primes, params, rng)
	var model: Dictionary
	match mode:
		"keygen":
			model = _keygen(problem, skill, lock, rng)
		"encrypt":
			model = _encrypt(problem, skill, lock, rng)
		"decrypt":
			model = _decrypt(problem, skill, lock, rng)
		_:
			push_error("RsaGenerator: unknown mode '%s'" % mode)
			return problem
	if with_hints:
		var example: Problem = GeneratorKit.make_example(
			func(sub: RandomNumberGenerator) -> Problem: return _make(skill, params, sub, false), problem, rng)
		GeneratorKit.add_hints(problem, model, example, _example_line(mode, example))
	return problem


## Two different primes, their n and loop size t, a public key e below t, and the private key d.
static func _lock(primes: Array[int], params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var lock: Dictionary = {}
	for attempt: int in 80:
		var p: int = primes[rng.randi_range(0, primes.size() - 1)]
		var q: int = primes[rng.randi_range(0, primes.size() - 1)]
		if p == q:
			continue
		var t: int = (p - 1) * (q - 1)
		var keys: Array[int] = []
		for e: int in GeneratorKit.ints_of(params.get("e_choices", E_CHOICES)):
			if e < t and MathUtil.gcd(e, t) == 1:
				keys.append(e)
		if keys.is_empty():
			continue
		var e: int = keys[rng.randi_range(0, keys.size() - 1)]
		lock = {"p": mini(p, q), "q": maxi(p, q), "n": p * q, "t": t, "e": e, "d": private_key(e, t)}
		return lock
	return {"p": 3, "q": 5, "n": 15, "t": 8, "e": 3, "d": 3}


static func _keygen(problem: Problem, skill: Skill, lock: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var p: int = lock["p"]
	var q: int = lock["q"]
	var t: int = lock["t"]
	var e: int = lock["e"]
	problem.meta = {"lock": lock.duplicate()}
	var picture: Dictionary
	if rng.randi_range(0, 1) == 0:
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


static func _encrypt(problem: Problem, skill: Skill, lock: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var n: int = lock["n"]
	var e: int = lock["e"]
	var m: int = rng.randi_range(2, n - 1)
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


static func _decrypt(problem: Problem, skill: Skill, lock: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var n: int = lock["n"]
	var d: int = lock["d"]
	var m: int = rng.randi_range(2, n - 1)
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
