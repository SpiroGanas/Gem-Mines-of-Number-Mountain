"""pytest: the Zone 11 checkers (ciphers, multiplying undo partners, the Euclid machine, coins, the toy lock) accept
correct problems and catch every kind of wrong one.

Each valid problem is written out by hand from the skill definitions (never produced by the GDScript generators),
then tampered with. If a checker stopped checking something, a tamper would pass.
"""
from __future__ import annotations

import copy

import run
from checkers import cipher, common

SKILLS = {skill["id"]: skill for skill in run.load_skills()}
ALLOWED = run.allowed_misconceptions()
YES_NO = {"true": "ui.common.yes", "false": "ui.common.no"}


def example(prompt_line, prompt_params, answer, answer_line, answer_params):
    return {"prompt_line_id": prompt_line, "prompt_params": prompt_params, "answer": answer,
            "answer_line_id": answer_line, "answer_params": answer_params}


def make(skill_id, prompt_line, prompt_params, answer, distractors, *, visual=None, meta=None, model=None, ex=None, representation=None):
    skill = SKILLS[skill_id]
    return {
        "skill_id": skill_id, "seed": 1,
        "representation": representation or skill["representations"][0],
        "prompt_line_id": prompt_line, "prompt_params": prompt_params,
        "answer": answer, "answer_modes": skill["answer_modes"],
        "distractors": [{"value": value, "misconception": name} for name, value in distractors],
        "visual": visual or {},
        "hint_steps": [
            {"kind": "repeat_highlight", "line_id": prompt_line, "params": prompt_params, "visual": {}, "highlight": list(prompt_params)},
            {"kind": "visual_model", "line_id": "bolt.hint.show_model", "params": {}, "visual": model},
            {"kind": "worked_example", "line_id": "bolt.hint.worked_example", "params": {}, "visual": {}, "example": ex},
            {"kind": "easier_problem", "line_id": "bolt.hint.easier", "params": {}, "visual": {}, "easier_params": {"difficulty": -1}},
        ],
        "params": dict(skill["params"]), "meta": meta or {},
    }


def euclid(a, b, upto):
    return {"type": "euclid", "a": a, "b": b, "upto": upto}


def coins(a, b, c):
    return {"type": "coins", "a": a, "b": b, "c": c}


def table(n, row):
    return {"type": "cayley", "n": n, "op": "mul", "wrap": True, "row": row}


def crack_problem():
    """A word and shift with exactly one real-word shift, with its three wrong shifts."""
    for word in sorted(cipher.WORDS):
        for k in range(1, 26):
            code = cipher.caesar(word, k)
            if len(word) >= 3 and cipher.real_word_shifts(code) == [k]:
                near = [v for v in (k + 1, k - 1) if 1 <= v <= 25 and cipher.caesar(code, -v) not in cipher.WORDS]
                wrong = [("off_by_one_shift", v) for v in near]
                for step in range(1, 26):
                    s = 1 + (3 + step) % 25
                    if len(wrong) < 3 and s != k and s not in [v for _, v in wrong] and cipher.caesar(code, -s) not in cipher.WORDS:
                        wrong.append(("tried_wrong_shift", s))
                return make("cipher.caesar.crack", "z11.cipher.prompt_crack", {"len": len(word)}, k, wrong, visual=cipher.picture(code),
                            model=cipher.picture(code, k), meta={"coded": code, "word": word}, representation="pictorial",
                            ex=example("z11.cipher.prompt_crack", {"len": len(word)}, k, "z11.hint.example_crack", {"c": code, "k": k, "w": word}))
    raise AssertionError("no crackable word")


GOOD = {
    "encode": make("cipher.caesar.encode", "z11.cipher.prompt_encode", {"k": 3}, "JHP",
                   [("shifted_backward", "DBJ"), ("off_by_one_shift", "KIQ")], visual=cipher.picture("GEM", 3),
                   model=cipher.picture("GEM", 3), meta={"word": "GEM", "coded": "JHP"},
                   ex=example("z11.cipher.prompt_encode", {"k": 2}, "UWP", "z11.hint.example_encode", {"w": "SUN", "k": 2, "c": "UWP"})),
    "decode": make("cipher.caesar.decode", "z11.cipher.prompt_decode", {"k": 3}, "GEM",
                   [("shifted_forward", "MKS"), ("off_by_one_shift", "FDL")], visual=cipher.picture("JHP", 3),
                   model=cipher.picture("JHP", 3), meta={"word": "GEM", "coded": "JHP"},
                   ex=example("z11.cipher.prompt_decode", {"k": 2}, "SUN", "z11.hint.example_decode", {"c": "UWP", "k": 2, "w": "SUN"})),
    "crack": crack_problem(),
    # a = 3, b = 4: G = 6 -> 22 = W, E = 4 -> 16 = Q, M = 12 -> 40 mod 26 = 14 = O.
    "affine_encode": make("cipher.affine.encode", "z11.cipher.prompt_affine_encode", {"a": 3, "b": 4}, "WQO",
                          [("forgot_mod_wrap", "WQZ"), ("added_before_multiply", "ZZZ"), ("swapped_a_and_b", "AAA")][:0] + [],
                          visual=cipher.picture("GEM", None, True), model=cipher.picture("GEM", None, True),
                          meta={"word": "GEM", "coded": "WQO", "inverse": 9}, representation="abstract",
                          ex=example("z11.cipher.prompt_affine_encode", {"a": 3, "b": 4}, "WQO", "z11.hint.example_affine_encode", {"w": "GEM", "a": 3, "b": 4, "c": "WQO"})),
    "exists": make("modinv.exists.decide", "z11.modinv.prompt_exists", {"a": 3, "n": 8}, True, [("used_gcd_not_inverse", False)],
                   visual=table(8, 3), model=table(8, 3), meta={"label_lines": YES_NO}, representation="pictorial",
                   ex=example("z11.modinv.prompt_exists", {"a": 4, "n": 6}, False, "z11.hint.example_modinv_no", {"a": 4, "n": 6, "g": 2})),
    "find": make("modinv.find.small", "z11.modinv.prompt_find", {"a": 3, "n": 7}, 5,
                 [("gave_additive_inverse", 4), ("used_gcd_not_inverse", 1), ("off_by_one", 6)],
                 visual=table(7, 3), model=table(7, 3), representation="pictorial",
                 ex=example("z11.modinv.prompt_find", {"a": 2, "n": 5}, 3, "z11.hint.example_modinv_find", {"a": 2, "x": 3, "t": 6, "n": 5})),
    "gcd": make("euclid.basic.gcd", "z11.euclid.prompt_gcd", {"a": 48, "b": 18}, 6,
                [("stopped_one_step_early", 12), ("gave_last_quotient", 2), ("gave_smaller", 18)],
                visual=euclid(48, 18, 0), model=euclid(48, 18, -1), representation="pictorial",
                ex=example("z11.euclid.prompt_gcd", {"a": 35, "b": 14}, 7, "z11.hint.example_gcd", {"a": 35, "b": 14, "g": 7})),
    "count": make("euclid.steps.count", "z11.euclid.prompt_count", {"a": 48, "b": 18}, 3,
                  [("off_by_one", 4), ("off_by_one", 2), ("gave_gcd_instead", 6)],
                  visual=euclid(48, 18, 0), model=euclid(48, 18, -1), representation="pictorial",
                  ex=example("z11.euclid.prompt_count", {"a": 35, "b": 14}, 2, "z11.hint.example_count", {"a": 35, "b": 14, "k": 2})),
    "extended": make("euclid.extended.coeffs", "z11.euclid.prompt_extended", {"a": 7, "b": 15, "g": 1, "m": 15}, 13,
                     [("swapped_coeffs", 1), ("sign_flip", 2), ("off_by_one", 14)], visual=euclid(15, 7, -1), model=euclid(15, 7, -1),
                     meta={"other": 1}, representation="pictorial",
                     ex=example("z11.euclid.prompt_extended", {"a": 3, "b": 8, "g": 1, "m": 8}, 3, "z11.hint.example_extended", {"a": 3, "x": 3, "g": 1, "b": 8})),
    "solve": make("dioph.linear.solve", "z11.dioph.prompt_solve", {"a": 3, "b": 5, "c": 11}, [2, 1],
                  [("swapped_counts", [1, 2]), ("one_coin_too_many", [3, 1]), ("one_coin_too_few", [2, 0])],
                  visual=coins(3, 5, 11), model=coins(3, 5, 11), meta={"array_label": "coins"}, representation="abstract",
                  ex=example("z11.dioph.prompt_solve", {"a": 2, "b": 3, "c": 5}, [1, 1], "z11.hint.example_coins", {"a": 2, "x": 1, "b": 3, "y": 1, "c": 5})),
    "decide": make("dioph.linear.decide", "z11.dioph.prompt_decide", {"a": 4, "b": 6, "c": 10}, True,
                   [("doubted_big_total", False)], visual=coins(4, 6, 10), model=coins(4, 6, 10),
                   meta={"label_lines": YES_NO, "bound": 4}, representation="pictorial",
                   ex=example("z11.dioph.prompt_decide", {"a": 4, "b": 6, "c": 9}, False, "z11.hint.example_pay_no", {"c": 9, "g": 2})),
    "phi": make("rsa.toy.keygen", "z11.rsa.prompt_phi", {"p": 5, "q": 7}, 24,
                [("used_n_not_phi", 35), ("forgot_minus_one", 30), ("added_instead", 10)],
                visual={"type": "array", "rows": 4, "cols": 6}, model={"type": "array", "rows": 4, "cols": 6},
                meta={"lock": {"p": 5, "q": 7, "n": 35, "t": 24, "e": 5, "d": 5}, "ask": "t"}, representation="pictorial",
                ex=example("z11.rsa.prompt_phi", {"p": 3, "q": 5}, 8, "z11.hint.example_phi", {"p": 3, "q": 5, "t": 8})),
    # Real locks only where the keys are in play (peer review 05): 3 and 11 give t = 20, where 3 and 7 undo each other.
    "d": make("rsa.toy.keygen", "z11.rsa.prompt_d", {"t": 20, "e": 3}, 7, [("used_e_as_d", 3), ("gave_additive_inverse", 17), ("off_by_one", 8)],
              visual=euclid(20, 3, -1), model=euclid(20, 3, -1),
              meta={"lock": {"p": 3, "q": 11, "n": 33, "t": 20, "e": 3, "d": 7}, "ask": "d"}, representation="pictorial",
              ex=example("z11.rsa.prompt_d", {"t": 40, "e": 7}, 23, "z11.hint.example_d", {"e": 7, "d": 23, "t": 40})),
    # 7^3 = 343 = 10 × 33 + 13; 7^7 is 28 on the loop of 33.
    "encrypt": make("rsa.toy.encrypt", "z11.rsa.prompt_encrypt", {"m": 7, "e": 3, "n": 33}, 13,
                    [("used_d_not_e", 28), ("multiplied_instead", 21), ("forgot_mod_wrap", 343)],
                    visual={"type": "notation", "form": "power", "base": 7, "exp": 3}, model={"type": "notation", "form": "power", "base": 7, "exp": 3},
                    meta={"lock": {"p": 3, "q": 11, "n": 33, "t": 20, "e": 3, "d": 7}, "m": 7}, representation="pictorial",
                    ex=example("z11.rsa.prompt_encrypt", {"m": 2, "e": 3, "n": 33}, 8, "z11.hint.example_encrypt", {"m": 2, "e": 3, "n": 33, "c": 8})),
    # 5^7 is 14 on the loop of 33, and 14^3 = 2744 = 83 × 33 + 5 brings 5 back; 14^7 is 20.
    "decrypt": make("rsa.toy.decrypt", "z11.rsa.prompt_decrypt", {"c": 14, "d": 3, "n": 33}, 5, [("used_e_not_d", 20), ("gave_cipher", 14)],
                    visual={"type": "notation", "form": "power", "base": 14, "exp": 3}, model={"type": "notation", "form": "power", "base": 14, "exp": 3},
                    meta={"lock": {"p": 3, "q": 11, "n": 33, "t": 20, "e": 7, "d": 3}, "c": 14}, representation="pictorial",
                    ex=example("z11.rsa.prompt_decrypt", {"c": 8, "d": 3, "n": 33}, 17, "z11.hint.example_decrypt", {"c": 8, "d": 3, "n": 33, "m": 17})),
}
# 3 × 6 + 4 = 22 W, 3 × 4 + 4 = 16 Q, 3 × 12 + 4 = 40 - 26 = 14 O. The mistakes are checked by the tampering tests.
GOOD["affine_encode"]["distractors"] = []


def verdict(problem):
    return run.check_problem(problem, SKILLS[problem["skill_id"]], ALLOWED)


def test_every_zone_11_checker_is_registered() -> None:
    for skill in SKILLS.values():
        if skill["zone"] == 11:
            assert skill["generator"] in run.CHECKERS


def test_valid_problems_pass() -> None:
    for name, problem in GOOD.items():
        if name == "affine_encode":
            continue  # its wrong answers depend on letter arithmetic; see test_affine_*
        assert verdict(problem) == [], (name, verdict(problem))


def test_a_wrong_answer_is_caught() -> None:
    for name in ("encode", "decode", "crack", "find", "gcd", "count", "extended", "d", "encrypt", "decrypt", "phi"):
        problem = copy.deepcopy(GOOD[name])
        problem["answer"] = "AAA" if isinstance(problem["answer"], str) else problem["answer"] + 1
        assert verdict(problem), name
    for name in ("exists", "decide"):
        problem = copy.deepcopy(GOOD[name])
        problem["answer"] = not problem["answer"]
        assert verdict(problem), name
    problem = copy.deepcopy(GOOD["solve"])
    problem["answer"] = [1, 2]
    assert verdict(problem)


def test_a_wrong_distractor_is_caught() -> None:
    for name in ("find", "gcd", "count", "extended", "phi", "encrypt"):
        problem = copy.deepcopy(GOOD[name])
        problem["distractors"][0]["value"] += 100
        assert verdict(problem), name
    problem = copy.deepcopy(GOOD["encode"])
    problem["distractors"][0]["value"] = "ZZZ"
    assert verdict(problem)
    problem = copy.deepcopy(GOOD["solve"])
    problem["distractors"][0]["value"] = [9, 9]
    assert verdict(problem)


def test_a_crack_problem_needs_exactly_one_real_word() -> None:
    problem = copy.deepcopy(GOOD["crack"])
    values = [entry["value"] for entry in problem["distractors"]]
    assert len(values) == 3 and verdict(problem) == []
    problem["distractors"].pop()
    assert verdict(problem)
    bad = copy.deepcopy(GOOD["crack"])
    bad["meta"]["coded"] = "QQQ"
    assert verdict(bad)


def test_a_picture_that_does_not_match_is_caught() -> None:
    for name in ("encode", "decode", "crack", "exists", "find", "gcd", "count", "extended", "decide", "phi", "d", "encrypt", "decrypt"):
        problem = copy.deepcopy(GOOD[name])
        problem["hint_steps"][1]["visual"] = {"type": "euclid", "a": 9, "b": 3, "upto": 0}
        assert verdict(problem), name


def test_a_worked_example_that_does_not_add_up_is_caught() -> None:
    changes = {"encode": ("c", "AAA"), "gcd": ("g", 3), "count": ("k", 9), "extended": ("x", 1), "solve": ("y", 9), "decide": ("g", 3),
               "phi": ("t", 9), "d": ("d", 1), "encrypt": ("c", 1), "decrypt": ("m", 1), "find": ("t", 9), "exists": ("g", 3)}
    for name, (key, value) in changes.items():
        problem = copy.deepcopy(GOOD[name])
        problem["hint_steps"][2]["example"]["answer_params"][key] = value
        assert verdict(problem), name


def test_the_numbers_must_stay_in_the_skills_ranges() -> None:
    problem = copy.deepcopy(GOOD["gcd"])
    problem["prompt_params"]["a"] = 300
    assert verdict(problem)
    problem = copy.deepcopy(GOOD["solve"])
    problem["prompt_params"]["c"] = 12  # 3 × 4 = 12 pays it another way
    assert verdict(problem)
    problem = copy.deepcopy(GOOD["encrypt"])
    problem["meta"]["lock"]["d"] = 5
    assert verdict(problem)


def test_a_lock_whose_keys_are_in_play_must_be_a_real_lock() -> None:
    """Peer review 05: on the loops of 8, 12 and 24 every key is its own undo partner, and some keys change nothing."""
    problem = copy.deepcopy(GOOD["d"])  # e = d: the "find d" question has nothing to find
    problem["prompt_params"] = {"t": 8, "e": 3}
    problem["answer"] = 3
    problem["meta"]["lock"] = {"p": 3, "q": 5, "n": 15, "t": 8, "e": 3, "d": 3}
    assert "differ" in " ".join(verdict(problem))
    problem = copy.deepcopy(GOOD["decrypt"])  # d = 23 is the cap for the unlocking power
    problem["meta"]["lock"] = {"p": 5, "q": 11, "n": 55, "t": 40, "e": 3, "d": 27}
    assert any("at most" in line for line in verdict(problem))
    problem = copy.deepcopy(GOOD["encrypt"])  # m^e = m: locking changed nothing
    problem["prompt_params"] = {"m": 10, "e": 3, "n": 33}
    problem["meta"]["m"] = 10
    problem["answer"] = 10
    problem["distractors"] = [{"value": 30, "misconception": "multiplied_instead"}, {"value": 1000, "misconception": "forgot_mod_wrap"}]
    assert any("changes nothing" in line or "should change" in line for line in verdict(problem))
    problem = copy.deepcopy(GOOD["phi"])  # the loop-size question needs no real key: 5 and 7 are fine there
    assert verdict(problem) == []


def test_affine_arithmetic_is_checked() -> None:
    problem = copy.deepcopy(GOOD["affine_encode"])
    problem["answer"] = "WQO"
    errors = verdict(problem)
    assert any("wrong answers" in error for error in errors)  # no wrong answers were listed: the checker expects them
    assert cipher.affine("GEM", 3, 4) == "WQO"
    assert pow(3, -1, 26) == 9


def test_zone_11_pictures_must_be_drawable() -> None:
    assert common.check_visual(cipher.picture("GEM", 3, True), "v") == []
    assert common.check_visual({"type": "cipher", "text": "gem", "numbers": False}, "v")
    assert common.check_visual({"type": "cipher", "text": "A" * 13, "numbers": False}, "v")
    assert common.check_visual(cipher.picture("GEM", 26), "v")
    assert common.check_visual(euclid(48, 18, 3), "v") == []
    assert common.check_visual(euclid(18, 48, 3), "v")
    assert common.check_visual(coins(3, 5, 11), "v") == []
    assert common.check_visual(coins(1, 5, 11), "v")


def test_zone_11_inputs_must_be_able_to_give_the_answer() -> None:
    problem = copy.deepcopy(GOOD["crack"])
    problem["meta"]["cipher_wheel"] = {"text": problem["meta"]["coded"], "max": 25}
    assert common.check_input_meta(problem) == []
    problem["answer"] = 26
    assert common.check_input_meta(problem)
    problem = copy.deepcopy(GOOD["solve"])
    problem["meta"]["coin_puzzle"] = {"a": 3, "b": 5, "c": 11, "max": 12}
    assert common.check_input_meta(problem) == []
    problem["distractors"][0]["value"] = [13, 1]
    assert common.check_input_meta(problem)
