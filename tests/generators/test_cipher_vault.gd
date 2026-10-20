# Mirrors scripts/generators/cipher.gd, mod_inverse.gd, euclid.gd, diophantine.gd and rsa.gd (Zone 11, Cipher
# Vault). Written test-first. Letters are moved by index arithmetic written out here, never with the generators'
# own helpers except where a round trip is the test, and every number is checked by trying all the options.
class_name CipherVaultGeneratorTest
extends GdUnitTestSuite

const N: int = 1200
const SKILLS: Array[StringName] = [
	&"cipher.caesar.encode", &"cipher.caesar.decode", &"cipher.caesar.crack", &"cipher.affine.encode", &"cipher.affine.decode",
	&"modinv.exists.decide", &"modinv.find.small", &"euclid.basic.gcd", &"euclid.steps.count", &"euclid.extended.coeffs",
	&"dioph.linear.solve", &"dioph.linear.decide", &"rsa.toy.keygen", &"rsa.toy.encrypt", &"rsa.toy.decrypt",
]
const ALPHABET: String = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"

var _catalog: SkillCatalog
var _allowed: Array[StringName]


func before() -> void:
	_catalog = SkillCatalog.load_all()
	_allowed = SkillCatalog.misconception_names()


func _problems(skill_id: StringName, overrides: Dictionary = {}, count: int = N) -> Array[Problem]:
	return GeneratorChecks.make_all(_catalog.skill(skill_id), count, overrides)


func _shift(text: String, k: int) -> String:
	var out: String = ""
	for index: int in text.length():
		out += ALPHABET[posmod(ALPHABET.find(text[index]) + k, 26)]
	return out


func test_every_skill_passes_the_shared_checks() -> void:
	for skill_id: StringName in SKILLS:
		assert_array(GeneratorChecks.run(_catalog.skill(skill_id), N, _allowed)).override_failure_message(str(skill_id)).is_empty()
		assert_array(GeneratorChecks.run(_catalog.skill(skill_id), 400, _allowed, {"difficulty": -1})).override_failure_message(str(skill_id)).is_empty()
		assert_array(GeneratorChecks.run(_catalog.skill(skill_id), 200, _allowed, {"difficulty": -2})).override_failure_message(str(skill_id)).is_empty()


func test_the_same_seed_gives_the_same_problem() -> void:
	for skill_id: StringName in SKILLS:
		for seed: int in [1, 7, 99]:
			var first: Problem = GeneratorRegistry.make_problem(_catalog.skill(skill_id), seed)
			var second: Problem = GeneratorRegistry.make_problem(_catalog.skill(skill_id), seed)
			assert_str(JSON.stringify(first.to_json())).is_equal(JSON.stringify(second.to_json()))


func test_caesar_codes_shift_every_letter_and_round_trip() -> void:
	for problem: Problem in _problems(&"cipher.caesar.encode"):
		var k: int = problem.prompt_params["k"]
		assert_str(problem.answer).is_equal(_shift(problem.meta["word"], k))
		assert_bool(CipherGenerator.is_word(problem.meta["word"])).is_true()
	for problem: Problem in _problems(&"cipher.caesar.decode"):
		var k: int = problem.prompt_params["k"]
		assert_str(_shift(problem.answer, k)).is_equal(problem.meta["coded"])
	for word: String in CipherGenerator.words():
		for k: int in range(0, 26):
			assert_str(CipherGenerator.shift_text(CipherGenerator.shift_text(word, k), -k)).is_equal(word)


func test_a_crack_problem_has_exactly_one_word_shift_and_three_wrong_shifts() -> void:
	for problem: Problem in _problems(&"cipher.caesar.crack"):
		var code: String = problem.meta["coded"]
		var spelling: Array[int] = []
		for s: int in range(1, 26):
			if CipherGenerator.is_word(_shift(code, -s)):
				spelling.append(s)
		assert_array(spelling).contains_exactly([problem.answer])
		assert_int(problem.distractors.size()).is_equal(3)
		assert_int(problem.prompt_params["len"]).is_equal(code.length())
		if problem.representation == &"concrete":
			assert_int(problem.meta["cipher_wheel"]["max"]).is_equal(25)


func test_affine_codes_use_a_multiplier_with_an_undo_partner_and_round_trip() -> void:
	var seen: Dictionary = {}
	for problem: Problem in _problems(&"cipher.affine.encode"):
		var a: int = problem.prompt_params["a"]
		var b: int = problem.prompt_params["b"]
		assert_bool(CipherGenerator.is_coprime_26(a)).is_true()
		var expected: String = ""
		for ch: String in problem.meta["word"]:
			expected += ALPHABET[(a * ALPHABET.find(ch) + b) % 26]
		assert_str(problem.answer).is_equal(expected)
		seen[a] = true
	assert_int(seen.size()).is_greater(3)
	for a: int in range(1, 26):
		if CipherGenerator.is_coprime_26(a):
			var inverse: int = CipherGenerator.inverse_26(a)
			assert_int((a * inverse) % 26).is_equal(1)
			for b: int in range(0, 26):
				for word: String in ["GEM", "ZOO", "ABC"]:
					var coded: String = CipherGenerator.affine_text(word, a, b)
					assert_str(CipherGenerator.affine_text(CipherGenerator.shift_text(coded, -b), inverse, 0)).is_equal(word)
		else:
			assert_int(CipherGenerator.inverse_26(a)).is_equal(0)
	assert_int(12).is_equal(range(1, 26).filter(func(a: int) -> bool: return CipherGenerator.is_coprime_26(a)).size())
	for problem: Problem in _problems(&"cipher.affine.decode"):
		assert_str(CipherGenerator.affine_text(problem.answer, problem.prompt_params["a"], problem.prompt_params["b"])).is_equal(problem.meta["coded"])


func test_undo_partners_exist_exactly_when_the_numbers_share_nothing() -> void:
	var yes: int = 0
	for problem: Problem in _problems(&"modinv.exists.decide"):
		var a: int = problem.prompt_params["a"]
		var n: int = problem.prompt_params["n"]
		var found: bool = false
		for x: int in range(1, n):
			found = found or (a * x) % n == 1
		assert_bool(problem.answer).is_equal(found)
		assert_bool(problem.answer).is_equal(MathUtil.gcd(a, n) == 1)
		yes += 1 if problem.answer else 0
	assert_bool(yes > N / 4 and yes < N * 3 / 4).is_true()
	for problem: Problem in _problems(&"modinv.find.small"):
		assert_int((problem.prompt_params["a"] * problem.answer) % problem.prompt_params["n"]).is_equal(1)


func test_the_euclid_machine_runs_to_the_gcf_and_back() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 5
	for index: int in 10000:
		var a: int = rng.randi_range(2, 200)
		var b: int = rng.randi_range(2, 200)
		var parts: Array[int] = EuclidGenerator.extended_gcd(a, b)
		assert_int(a * parts[1] + b * parts[2]).is_equal(parts[0])
		assert_int(parts[0]).is_equal(MathUtil.gcd(a, b))
		var steps: Array[Dictionary] = EuclidGenerator.steps(a, b)
		assert_int(steps.back()["r"]).is_equal(0)
		assert_int(steps.back()["b"]).is_equal(parts[0])
	for problem: Problem in _problems(&"euclid.basic.gcd"):
		assert_int(problem.answer).is_equal(MathUtil.gcd(problem.prompt_params["a"], problem.prompt_params["b"]))
		assert_bool(problem.prompt_params["a"] > problem.prompt_params["b"]).is_true()
	for problem: Problem in _problems(&"euclid.steps.count"):
		assert_int(problem.answer).is_equal(EuclidGenerator.steps(problem.prompt_params["a"], problem.prompt_params["b"]).size())
	for problem: Problem in _problems(&"euclid.extended.coeffs"):
		var p: Dictionary = problem.prompt_params
		var hits: Array[int] = []
		for x: int in range(0, p["m"]):
			if (p["a"] * x) % p["b"] == p["g"]:
				hits.append(x)
		assert_array(hits).contains_exactly([problem.answer])


func test_a_coin_puzzle_has_exactly_one_way_and_a_decision_matches_trying_every_count() -> void:
	for problem: Problem in _problems(&"dioph.linear.solve"):
		var p: Dictionary = problem.prompt_params
		var ways: Array = []
		for x: int in range(0, p["c"] / p["a"] + 1):
			if (p["c"] - p["a"] * x) % p["b"] == 0:
				ways.append([x, (p["c"] - p["a"] * x) / p["b"]])
		assert_array(ways).contains_exactly([problem.answer])
		assert_bool(p["c"] < MathUtil.lcm(p["a"], p["b"])).is_true()
		if problem.representation == &"concrete":
			assert_int(problem.meta["coin_puzzle"]["c"]).is_equal(p["c"])
	var yes: int = 0
	for problem: Problem in _problems(&"dioph.linear.decide"):
		var p: Dictionary = problem.prompt_params
		var payable: bool = false
		for x: int in range(0, p["c"] / p["a"] + 1):
			payable = payable or (p["c"] - p["a"] * x) % p["b"] == 0
		assert_bool(problem.answer).is_equal(payable)
		yes += 1 if problem.answer else 0
	assert_bool(yes > N / 4 and yes < N * 3 / 4).is_true()


func test_the_toy_lock_unlocks_what_it_locks() -> void:
	for p: int in [3, 5, 7, 11]:
		for q: int in [3, 5, 7, 11]:
			if p == q:
				continue
			var n: int = p * q
			var t: int = (p - 1) * (q - 1)
			for e: int in RsaGenerator.E_CHOICES:
				if e >= t or MathUtil.gcd(e, t) != 1:
					continue
				var d: int = RsaGenerator.private_key(e, t)
				assert_int((e * d) % t).is_equal(1)
				for m: int in range(0, n):
					var locked: int = RsaGenerator.pow_mod(m, e, n)
					assert_int(RsaGenerator.pow_mod(locked, d, n)).is_equal(m)
	assert_int(RsaGenerator.pow_mod(7, 3, 15)).is_equal(13)
	for problem: Problem in _problems(&"rsa.toy.encrypt"):
		var p: Dictionary = problem.prompt_params
		var raw: int = 1
		for step: int in p["e"]:
			raw = (raw * p["m"]) % p["n"]
		assert_int(problem.answer).is_equal(raw)
	for problem: Problem in _problems(&"rsa.toy.decrypt"):
		var lock: Dictionary = problem.meta["lock"]
		assert_int(RsaGenerator.pow_mod(problem.answer, lock["e"], lock["n"])).is_equal(problem.prompt_params["c"])
		assert_bool(lock["p"] <= 7 and lock["q"] <= 7).is_true()
	for problem: Problem in _problems(&"rsa.toy.keygen"):
		var lock: Dictionary = problem.meta["lock"]
		assert_bool(lock["p"] <= 11 and lock["q"] <= 11).is_true()
		assert_int(lock["t"]).is_equal((lock["p"] - 1) * (lock["q"] - 1))
		if problem.meta["ask"] == "d":
			assert_int((problem.answer * lock["e"]) % lock["t"]).is_equal(1)
