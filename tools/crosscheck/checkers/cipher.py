"""Independent re-derivation of the CipherGenerator problems (Zone 11, skills cipher.*).

Letters are numbered by their place in the alphabet text and moved with Python's % (the GDScript uses posmod); the
undo partner of an affine multiplier comes from pow(a, -1, 26). The word list is read from the curriculum file.
Nothing here is ported from scripts/generators/cipher.gd."""
from __future__ import annotations

import json
from pathlib import Path

from .common import distractor_pairs, filtered

ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
WORDS = set(json.loads((Path(__file__).resolve().parents[3] / "curriculum" / "wordlists" / "cipher_words.json").read_text(encoding="utf-8"))["words"])


def caesar(text: str, k: int) -> str:
    return "".join(ALPHABET[(ALPHABET.index(ch) + k) % 26] for ch in text)


def stuck(text: str, k: int) -> str:
    """Each letter moved k places but stopped at the ends of the alphabet."""
    return "".join(ALPHABET[min(max(ALPHABET.index(ch) + k, 0), 25)] for ch in text)


def affine(text: str, a: int, b: int) -> str:
    return "".join(ALPHABET[(a * ALPHABET.index(ch) + b) % 26] for ch in text)


def picture(text: str, shift: int | None = None, numbers: bool = False) -> dict:
    result = {"type": "cipher", "text": text, "numbers": numbers}
    if shift is not None:
        result["shift"] = shift
    return result


def real_word_shifts(code: str) -> list[int]:
    return [s for s in range(1, 26) if caesar(code, -s) in WORDS]


def check(problem: dict) -> list[str]:
    handler = {
        "caesar_encode": _caesar, "caesar_decode": _caesar, "caesar_crack": _crack,
        "affine_encode": _affine, "affine_decode": _affine,
    }.get(problem["params"].get("mode"))
    if handler is None:
        return [f"unknown cipher mode {problem['params'].get('mode')!r}"]
    return handler(problem)


def _compare(problem: dict, candidates: list[tuple[str, object]]) -> list[str]:
    wanted = filtered(problem["answer"], candidates)
    if distractor_pairs(problem) != wanted:
        return [f"the wrong answers should be {wanted}, got {distractor_pairs(problem)}"]
    return []


def _caesar(problem: dict) -> list[str]:
    mode, skill = problem["params"]["mode"], problem["params"]
    errors: list[str] = []
    if set(problem["prompt_params"]) != {"k"}:
        return ["the prompt should have {k}"]
    k = problem["prompt_params"]["k"]
    word, coded = problem["meta"].get("word"), problem["meta"].get("coded")
    if not (isinstance(word, str) and word in WORDS and skill["min_len"] <= len(word) <= skill["max_len"]):
        errors.append(f"{word!r} should be a listed word of {skill['min_len']} to {skill['max_len']} letters")
        return errors
    if not skill["min_shift"] <= k <= skill["max_shift"]:
        errors.append(f"shift {k} is outside {skill['min_shift']}..{skill['max_shift']}")
    if coded != caesar(word, k):
        errors.append(f"{word} shifted {k} is {caesar(word, k)}, not {coded}")
    wheel = k if problem["representation"] == "concrete" else None
    if mode == "caesar_encode":
        if problem["prompt_line_id"] != "z11.cipher.prompt_encode" or problem["answer"] != caesar(word, k):
            errors.append("encoding: the answer is the word shifted forward k places")
        errors += _compare(problem, [("shifted_backward", caesar(word, -k)), ("off_by_one_shift", caesar(word, k + 1)), ("forgot_mod_wrap", stuck(word, k))])
        shown, example_line = word, "z11.hint.example_encode"
    else:
        if problem["prompt_line_id"] != "z11.cipher.prompt_decode" or problem["answer"] != word:
            errors.append("decoding: the answer is the word the code came from")
        errors += _compare(problem, [("shifted_forward", caesar(coded, k)), ("off_by_one_shift", caesar(coded, -(k + 1))), ("forgot_mod_wrap", stuck(coded, -k))])
        shown, example_line = coded, "z11.hint.example_decode"
    if problem["visual"] != picture(shown, wheel):
        errors.append("the picture is the word (or code) on cards, with the wheel when concrete")
    if problem["hint_steps"][1]["visual"] != picture(shown, k):
        errors.append("the rung 2 model should show the wheel at the shift")
    ex = problem["hint_steps"][2]["example"]
    ek, em = ex["prompt_params"]["k"], ex["answer_params"]
    ok = em.get("k") == ek and ex["answer_line_id"] == example_line
    if mode == "caesar_encode":
        ok = ok and em.get("c") == caesar(em["w"], ek) and em["c"] == ex["answer"]
    else:
        ok = ok and em.get("c") == caesar(em["w"], ek) and em["w"] == ex["answer"]
    if not ok:
        errors.append("the worked example should say how its word changes")
    return errors


def _crack(problem: dict) -> list[str]:
    errors: list[str] = []
    k, meta = problem["answer"], problem["meta"]
    code, word = meta.get("coded"), meta.get("word")
    if not (isinstance(code, str) and isinstance(word, str) and 3 <= len(word) <= problem["params"]["max_len"]):
        return errors + ["the problem names its code and word"]
    if problem["prompt_line_id"] != "z11.cipher.prompt_crack" or problem["prompt_params"] != {"len": len(word)}:
        errors.append("the prompt should be z11.cipher.prompt_crack with the word's length {len}")
    if word not in WORDS or caesar(word, k) != code:
        errors.append(f"{word} shifted {k} should make {code}")
    if real_word_shifts(code) != [k]:
        errors.append(f"exactly one shift should spell a word; these do: {real_word_shifts(code)} (answer {k})")
    values = [entry["value"] for entry in problem["distractors"]]
    if len(values) != 3 or len(set(values)) != 3:
        errors.append("a crack problem has three different wrong shifts")
    for entry in problem["distractors"]:
        v = entry["value"]
        if not (1 <= v <= 25) or v == k or caesar(code, -v) in WORDS:
            errors.append(f"wrong shift {v!r} must be 1..25, not the answer, and not spell a word")
        if entry["misconception"] == "off_by_one_shift" and abs(v - k) != 1:
            errors.append(f"off_by_one_shift {v!r} should be next to {k}")
        if entry["misconception"] == "tried_wrong_shift" and abs(v - k) == 1 and False:
            errors.append("unreachable")
    near = [v for v in (k + 1, k - 1) if 1 <= v <= 25 and caesar(code, -v) not in WORDS]
    named = [entry["value"] for entry in problem["distractors"] if entry["misconception"] == "off_by_one_shift"]
    if sorted(named) != sorted(near):
        errors.append(f"the next-door shifts {near} should be named off_by_one_shift, got {named}")
    if problem["representation"] == "concrete":
        if meta.get("cipher_wheel") != {"text": code, "max": 25} or problem["visual"]:
            errors.append("a concrete problem is the cipher wheel, with no other picture")
    elif problem["visual"] != picture(code):
        errors.append("a pictorial problem shows the code on cards")
    if problem["hint_steps"][1]["visual"] != picture(code, k):
        errors.append("the rung 2 model should show the wheel at the answer")
    ex = problem["hint_steps"][2]["example"]
    ep = ex["answer_params"]
    if ex["answer_line_id"] != "z11.hint.example_crack" or caesar(ep["w"], ex["answer"]) != ep["c"] or ep["k"] != ex["answer"]:
        errors.append("the worked example should say which shift turns its code into its word")
    return errors


def _affine(problem: dict) -> list[str]:
    mode, skill = problem["params"]["mode"], problem["params"]
    errors: list[str] = []
    if set(problem["prompt_params"]) != {"a", "b"}:
        return ["the prompt should have {a, b}"]
    a, b = problem["prompt_params"]["a"], problem["prompt_params"]["b"]
    word, coded, inverse = problem["meta"].get("word"), problem["meta"].get("coded"), problem["meta"].get("inverse")
    if not (isinstance(word, str) and word in WORDS and 3 <= len(word) <= skill["max_len"]):
        return [f"{word!r} should be a listed word of 3 to {skill['max_len']} letters"]
    if a not in skill["a_values"] or not 1 <= b <= 25:
        errors.append(f"a {a} and b {b} are outside the skill's ranges")
    if coded != affine(word, a, b) or inverse != pow(a, -1, 26):
        errors.append(f"{word} with a = {a}, b = {b} is {affine(word, a, b)}; the undo partner of {a} is {pow(a, -1, 26)}")
    if mode == "affine_encode":
        if problem["prompt_line_id"] != "z11.cipher.prompt_affine_encode" or problem["answer"] != coded:
            errors.append("encoding: the answer is a·x + b on every letter")
        candidates = [
            ("forgot_mod_wrap", "".join(ALPHABET[min(a * ALPHABET.index(ch) + b, 25)] for ch in word)),
            ("added_before_multiply", affine(caesar(word, b), a, 0)),
            ("swapped_a_and_b", affine(word, b, a)),
        ]
        shown, example_line = word, "z11.hint.example_affine_encode"
    else:
        if problem["prompt_line_id"] != "z11.cipher.prompt_affine_decode" or problem["answer"] != word:
            errors.append("decoding: the answer is the word the code came from")
        candidates = [
            ("used_a_not_inverse", affine(caesar(coded, -b), a, 0)),
            ("forgot_subtract_b", affine(coded, inverse, 0)),
            ("added_b_instead", affine(caesar(coded, b), inverse, 0)),
        ]
        shown, example_line = coded, "z11.hint.example_affine_decode"
    errors += _compare(problem, candidates)
    if problem["visual"] != picture(shown, None, True) or problem["hint_steps"][1]["visual"] != picture(shown, None, True):
        errors.append("the picture is the word (or code) on cards with its numbers")
    ex = problem["hint_steps"][2]["example"]
    ep = ex["answer_params"]
    if ex["answer_line_id"] != example_line:
        errors.append("the worked example uses the wrong line")
    elif mode == "affine_encode" and (ep["c"] != affine(ep["w"], ep["a"], ep["b"]) or ep["c"] != ex["answer"]):
        errors.append("the worked example's code should be a·x + b of its word")
    elif mode == "affine_decode" and (ep["c"] != affine(ep["w"], ep["a"], ep["b"]) or ep["i"] != pow(ep["a"], -1, 26) or ep["w"] != ex["answer"]):
        errors.append("the worked example should decode with the undo partner")
    return errors
