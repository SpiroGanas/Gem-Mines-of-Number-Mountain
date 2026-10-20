## Ciphers for Zone 11, Cipher Vault (skills cipher.*): letters are numbered A = 0 to Z = 25 and moved round the loop
## of 26. A Caesar cipher shifts every letter forward by k: x becomes (x + k) mod 26. An affine cipher multiplies
## first: x becomes (a·x + b) mod 26, which can be undone only when a has a multiplying undo partner on the loop
## of 26, that is when a and 26 share no factor but 1. Words come from curriculum/wordlists/cipher_words.json.
## Pure: only the passed-in rng is used.
##
## The prompt numbers are whole numbers only, so the word itself is in the picture (a `cipher` visual) and the
## answer is a word (a String), picked from answer buttons; caesar.crack's answer is the shift (an int), found on the
## cipher wheel (concrete, meta.cipher_wheel) or picked from answer buttons.
##
## Modes (params.mode):
##   caesar_encode  "Shift every letter forward {k} places. What does the word become?"
##   caesar_decode  "Every letter was shifted forward {k} places. What was the word?"
##   caesar_crack   "The code hides a word of {len} letters. Which shift unlocks it?" Exactly one shift of 1 to 25 turns the code into
##                  a listed word, so the answer is never a matter of taste.
##   affine_encode  "Number the letters from 0. Turn each number x into {a}x + {b}. Wrap on 26. What does the word
##                  become?" Words of at most params.max_len letters, a from params.a_values.
##   affine_decode  the same cipher run backward: x = a⁻¹ × (y - b), wrapped on 26.
##
## The named mistakes:
##   shifted_backward       moved each letter the wrong way round the loop;
##   shifted_forward        (decoding) moved forward again instead of back;
##   off_by_one_shift       a shift one too large (or small);
##   tried_wrong_shift      a shift that does not spell a word;
##   forgot_mod_wrap        stopped at Z (or A) instead of going round;
##   added_before_multiply  (x + b) × a instead of a × x + b;
##   swapped_a_and_b        b × x + a;
##   used_a_not_inverse     a × (y - b) instead of a⁻¹ × (y - b);
##   forgot_subtract_b      a⁻¹ × y without taking b away first;
##   added_b_instead        a⁻¹ × (y + b), taking b the wrong way.
class_name CipherGenerator
extends RefCounted

const ALPHABET_SIZE: int = 26
const WORDS_PATH: String = "res://curriculum/wordlists/cipher_words.json"
const PROMPT_CAESAR_ENCODE: StringName = &"z11.cipher.prompt_encode"
const PROMPT_CAESAR_DECODE: StringName = &"z11.cipher.prompt_decode"
const PROMPT_CRACK: StringName = &"z11.cipher.prompt_crack"
const PROMPT_AFFINE_ENCODE: StringName = &"z11.cipher.prompt_affine_encode"
const PROMPT_AFFINE_DECODE: StringName = &"z11.cipher.prompt_affine_decode"
## A picture holds at most this many letters.
const MAX_LETTERS: int = 12

static var _words: Array[String] = []


static func generate(skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Problem:
	return _make(skill, params, rng, true)


## The word list, loaded once.
static func words() -> Array[String]:
	if _words.is_empty():
		var data: Variant = JsonUtil.parse_file(WORDS_PATH)
		for word: Variant in data["words"]:
			_words.append(String(word))
	return _words


## True for a word on the list.
static func is_word(text: String) -> bool:
	return words().has(text)


## The letters of `text` moved `shift` places forward round the loop of 26 (backward when negative). Letters are
## A-Z; anything else is kept.
static func shift_text(text: String, shift: int) -> String:
	var out: String = ""
	for index: int in text.length():
		var code: int = text.unicode_at(index) - 65
		if code < 0 or code >= ALPHABET_SIZE:
			out += text[index]
		else:
			out += char(65 + posmod(code + shift, ALPHABET_SIZE))
	return out


## Each letter x as (a·x + b) mod 26.
static func affine_text(text: String, a: int, b: int) -> String:
	var out: String = ""
	for index: int in text.length():
		var code: int = text.unicode_at(index) - 65
		if code < 0 or code >= ALPHABET_SIZE:
			out += text[index]
		else:
			out += char(65 + posmod(a * code + b, ALPHABET_SIZE))
	return out


## True when a has a multiplying undo partner on the loop of 26 (a and 26 share no factor but 1).
static func is_coprime_26(a: int) -> bool:
	return MathUtil.gcd(a, ALPHABET_SIZE) == 1


## The undo partner of a on the loop of 26, found by trying every number (0 when there is none).
static func inverse_26(a: int) -> int:
	for candidate: int in range(1, ALPHABET_SIZE):
		if posmod(a * candidate, ALPHABET_SIZE) == 1:
			return candidate
	return 0


## Every letter moved the way the picture says without wrapping: it stops at Z (or A when going back).
static func stuck_shift(text: String, shift: int) -> String:
	var out: String = ""
	for index: int in text.length():
		out += char(65 + clampi(text.unicode_at(index) - 65 + shift, 0, ALPHABET_SIZE - 1))
	return out


## The `cipher` picture: a word on cards (and its numbers when `numbers`), and the wheel set to `shift` (-1: no wheel).
static func cipher_picture(text: String, shift: int = -1, numbers: bool = false) -> Dictionary:
	var picture: Dictionary = {"type": "cipher", "text": text, "numbers": numbers}
	if shift >= 0:
		picture["shift"] = shift
	return picture


static func _make(skill: Skill, params: Dictionary, rng: RandomNumberGenerator, with_hints: bool) -> Problem:
	var mode: String = String(params.get("mode", "caesar_encode"))
	var problem: Problem = GeneratorKit.new_problem(skill, params, GeneratorKit.pick_representation(skill, params))
	var model: Dictionary
	match mode:
		"caesar_encode", "caesar_decode":
			model = _caesar(problem, skill, params, rng, mode == "caesar_decode")
		"caesar_crack":
			model = _crack(problem, skill, params, rng)
		"affine_encode", "affine_decode":
			model = _affine(problem, skill, params, rng, mode == "affine_decode")
		_:
			push_error("CipherGenerator: unknown mode '%s'" % mode)
			return problem
	if with_hints:
		var example: Problem = GeneratorKit.make_example(
			func(sub: RandomNumberGenerator) -> Problem: return _make(skill, params, sub, false), problem, rng)
		GeneratorKit.add_hints(problem, model, example, _example_line(mode, example))
	return problem


## A listed word of `low` to `high` letters.
static func _pick_word(low: int, high: int, rng: RandomNumberGenerator) -> String:
	var fits: Array[String] = []
	for word: String in words():
		if word.length() >= low and word.length() <= high:
			fits.append(word)
	return fits[rng.randi_range(0, fits.size() - 1)]


static func _caesar(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator, decoding: bool) -> Dictionary:
	var difficulty: int = GeneratorKit.difficulty_of(params)
	var max_len: int = GeneratorKit.eased_max(1, int(params.get("max_len", 6)), difficulty, 2)
	var max_shift: int = GeneratorKit.eased_max(1, int(params.get("max_shift", 25)), difficulty, 4)
	var k: int = rng.randi_range(int(params.get("min_shift", 1)), max_shift)
	var word: String = _pick_word(int(params.get("min_len", 3)), maxi(max_len, int(params.get("min_len", 3))), rng)
	var coded: String = shift_text(word, k)
	problem.prompt_params = {"k": k}
	problem.meta = {"word": word, "coded": coded}
	if decoding:
		problem.prompt_line_id = PROMPT_CAESAR_DECODE
		problem.answer = word
		problem.visual = cipher_picture(coded, k if problem.representation == &"concrete" else -1)
		GeneratorKit.add_distractor(problem, skill, shift_text(coded, k), &"shifted_forward")
		GeneratorKit.add_distractor(problem, skill, shift_text(coded, -(k + 1)), &"off_by_one_shift")
		GeneratorKit.add_distractor(problem, skill, stuck_shift(coded, -k), &"forgot_mod_wrap")
		return cipher_picture(coded, k)
	problem.prompt_line_id = PROMPT_CAESAR_ENCODE
	problem.answer = coded
	problem.visual = cipher_picture(word, k if problem.representation == &"concrete" else -1)
	GeneratorKit.add_distractor(problem, skill, shift_text(word, -k), &"shifted_backward")
	GeneratorKit.add_distractor(problem, skill, shift_text(word, k + 1), &"off_by_one_shift")
	GeneratorKit.add_distractor(problem, skill, stuck_shift(word, k), &"forgot_mod_wrap")
	return cipher_picture(word, k)


## Shifts s of 1 to 25 for which moving every letter of `code` back s places spells a listed word.
static func real_word_shifts(code: String) -> Array[int]:
	var found: Array[int] = []
	for s: int in range(1, ALPHABET_SIZE):
		if is_word(shift_text(code, -s)):
			found.append(s)
	return found


static func _crack(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var k: int = 1
	var code: String = ""
	for attempt: int in 60:
		var word: String = _pick_word(int(params.get("min_len", 3)), int(params.get("max_len", 8)), rng)
		k = rng.randi_range(1, ALPHABET_SIZE - 1)
		code = shift_text(word, k)
		if real_word_shifts(code) == [k]:
			break
	problem.answer = k
	problem.prompt_line_id = PROMPT_CRACK
	problem.prompt_params = {"len": code.length()}
	problem.meta = {"coded": code, "word": shift_text(code, -k)}
	if problem.representation == &"concrete":
		problem.meta["cipher_wheel"] = {"text": code, "max": ALPHABET_SIZE - 1}
	else:
		problem.visual = cipher_picture(code)
	for wrong: int in [k + 1, k - 1]:
		if wrong >= 1 and wrong <= ALPHABET_SIZE - 1 and not is_word(shift_text(code, -wrong)):
			GeneratorKit.add_distractor(problem, skill, wrong, &"off_by_one_shift")
	# Fill with shifts that do not spell a word (picked from the rng, then in order).
	var start: int = rng.randi_range(1, ALPHABET_SIZE - 1)
	for step: int in ALPHABET_SIZE - 1:
		if problem.distractors.size() >= 3:
			break
		var s: int = 1 + (start + step) % (ALPHABET_SIZE - 1)
		if s != k and not is_word(shift_text(code, -s)):
			GeneratorKit.add_distractor(problem, skill, s, &"tried_wrong_shift")
	return cipher_picture(code, k)


static func _affine(problem: Problem, skill: Skill, params: Dictionary, rng: RandomNumberGenerator, decoding: bool) -> Dictionary:
	var a_values: Array[int] = GeneratorKit.ints_of(params.get("a_values", [3, 5, 7, 9, 11, 15]))
	var max_len: int = GeneratorKit.eased_max(1, int(params.get("max_len", 3)), GeneratorKit.difficulty_of(params), 2)
	var a: int = a_values[rng.randi_range(0, a_values.size() - 1)]
	var b: int = rng.randi_range(1, ALPHABET_SIZE - 1)
	var word: String = _pick_word(3, maxi(max_len, 3), rng)
	var coded: String = affine_text(word, a, b)
	var inverse: int = inverse_26(a)
	problem.prompt_params = {"a": a, "b": b}
	problem.meta = {"word": word, "coded": coded, "inverse": inverse}
	if decoding:
		problem.prompt_line_id = PROMPT_AFFINE_DECODE
		problem.answer = word
		problem.visual = cipher_picture(coded, -1, true)
		GeneratorKit.add_distractor(problem, skill, affine_text(shift_text(coded, -b), a, 0), &"used_a_not_inverse")
		GeneratorKit.add_distractor(problem, skill, affine_text(coded, inverse, 0), &"forgot_subtract_b")
		GeneratorKit.add_distractor(problem, skill, affine_text(shift_text(coded, b), inverse, 0), &"added_b_instead")
		return cipher_picture(coded, -1, true)
	problem.prompt_line_id = PROMPT_AFFINE_ENCODE
	problem.answer = coded
	problem.visual = cipher_picture(word, -1, true)
	GeneratorKit.add_distractor(problem, skill, stuck_affine(word, a, b), &"forgot_mod_wrap")
	GeneratorKit.add_distractor(problem, skill, affine_text(shift_text(word, b), a, 0), &"added_before_multiply")
	GeneratorKit.add_distractor(problem, skill, affine_text(word, b, a), &"swapped_a_and_b")
	return cipher_picture(word, -1, true)


## a·x + b with the wrap forgotten: a number past 25 stays at Z.
static func stuck_affine(text: String, a: int, b: int) -> String:
	var out: String = ""
	for index: int in text.length():
		out += char(65 + mini(a * (text.unicode_at(index) - 65) + b, ALPHABET_SIZE - 1))
	return out


static func _example_line(mode: String, example: Problem) -> Dictionary:
	var p: Dictionary = example.prompt_params
	match mode:
		"caesar_encode":
			return {"line_id": &"z11.hint.example_encode", "params": {"w": example.meta["word"], "k": p["k"], "c": example.answer}}
		"caesar_decode":
			return {"line_id": &"z11.hint.example_decode", "params": {"c": example.meta["coded"], "k": p["k"], "w": example.answer}}
		"caesar_crack":
			return {"line_id": &"z11.hint.example_crack", "params": {"c": example.meta["coded"], "k": example.answer, "w": example.meta["word"]}}
		"affine_encode":
			return {"line_id": &"z11.hint.example_affine_encode", "params": {"w": example.meta["word"], "a": p["a"], "b": p["b"], "c": example.answer}}
	return {"line_id": &"z11.hint.example_affine_decode", "params": {"c": example.meta["coded"], "a": p["a"], "b": p["b"], "i": example.meta["inverse"], "w": example.answer}}
