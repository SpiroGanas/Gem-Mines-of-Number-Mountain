"""Independent re-derivation of the RsaGenerator problems (Zone 11, skills rsa.toy.*).

Powers use Python's pow(base, exp, n), the private key pow(e, -1, t) (and a brute-force search), the primes are
checked by trial division. Nothing here is ported from scripts/generators/rsa.gd."""
from __future__ import annotations

import math

from .common import distractor_pairs, filtered
from .euclid import picture as euclid_picture

MAX_RAW = 9999


def is_prime(n: int) -> bool:
    return n > 1 and all(n % d for d in range(2, math.isqrt(n) + 1))


def check_lock(lock: dict, skill: dict) -> list[str]:
    p, q, n, t, e, d = (lock.get(key) for key in ("p", "q", "n", "t", "e", "d"))
    errors: list[str] = []
    if not (isinstance(p, int) and isinstance(q, int) and p < q and is_prime(p) and is_prime(q) and p in skill["primes"] and q in skill["primes"]):
        return [f"the lock's primes {p!r} and {q!r} should be different primes from {skill['primes']}, p < q"]
    if n != p * q or t != (p - 1) * (q - 1):
        errors.append("n = p × q and t = (p - 1) × (q - 1)")
    if not (1 < e < t and math.gcd(e, t) == 1) or (e * d) % t != 1 or not 1 <= d < t or d != pow(e, -1, t):
        errors.append(f"the keys e {e} and d {d} should be undo partners on the loop of {t}")
    if "e_choices" in skill and e not in skill["e_choices"]:
        errors.append(f"e {e} should come from {skill['e_choices']}")
    return errors


def check(problem: dict) -> list[str]:
    mode, skill = problem["params"]["mode"], problem["params"]
    lock = problem["meta"].get("lock")
    if not isinstance(lock, dict):
        return ["an RSA problem names its lock in meta.lock"]
    errors = check_lock(lock, skill)
    if errors:
        return errors
    p, q, n, t, e, d = (lock[key] for key in ("p", "q", "n", "t", "e", "d"))
    pr = problem["prompt_params"]
    if mode == "keygen":
        errors += _keygen(problem, lock, pr)
    elif mode == "encrypt":
        errors += _lock_number(problem, lock, pr, encrypt=True)
    else:
        errors += _lock_number(problem, lock, pr, encrypt=False)
    return errors


def _keygen(problem: dict, lock: dict, pr: dict) -> list[str]:
    p, q, t, e, d = lock["p"], lock["q"], lock["t"], lock["e"], lock["d"]
    errors: list[str] = []
    ask = problem["meta"].get("ask")
    if ask == "t":
        if problem["prompt_line_id"] != "z11.rsa.prompt_phi" or pr != {"p": p, "q": q} or problem["answer"] != (p - 1) * (q - 1):
            errors.append("phi: the answer is (p - 1) × (q - 1)")
        wanted = filtered(problem["answer"], [("used_n_not_phi", p * q), ("forgot_minus_one", p * (q - 1)), ("added_instead", (p - 1) + (q - 1))])
        picture = {"type": "array", "rows": p - 1, "cols": q - 1}
        line = "z11.hint.example_phi"
    elif ask == "d":
        found = [x for x in range(1, t) if (e * x) % t == 1]
        if problem["prompt_line_id"] != "z11.rsa.prompt_d" or pr != {"t": t, "e": e} or found != [problem["answer"]]:
            errors.append(f"d: e × d should land on 1 on the loop of {t}; that is {found}")
        wanted = filtered(problem["answer"], [("used_e_as_d", e), ("gave_additive_inverse", t - e), ("off_by_one", d + 1 if d + 1 < t else d - 1)])
        picture = euclid_picture(t, e, -1)
        line = "z11.hint.example_d"
    else:
        return ["a key-making problem asks for t or d"]
    if distractor_pairs(problem) != wanted:
        errors.append(f"the wrong answers should be {wanted}, got {distractor_pairs(problem)}")
    if problem["representation"] == "pictorial":
        if problem["visual"] != picture:
            errors.append("a pictorial problem shows the rectangle (or the Euclid machine)")
    elif problem["visual"]:
        errors.append("an abstract problem is words only")
    if problem["hint_steps"][1]["visual"] != picture:
        errors.append("the rung 2 model should be the rectangle (or the Euclid machine)")
    ex = problem["hint_steps"][2]["example"]
    if ex["answer_line_id"] not in ("z11.hint.example_phi", "z11.hint.example_d"):
        errors.append("the worked example uses a key-making line")
    elif ex["answer_line_id"] == "z11.hint.example_phi":
        ep, es = ex["prompt_params"], ex["answer_params"]
        if es != {"p": ep["p"], "q": ep["q"], "t": ex["answer"]} or (ep["p"] - 1) * (ep["q"] - 1) != ex["answer"]:
            errors.append("the worked example should show (p - 1) × (q - 1)")
    else:
        ep, es = ex["prompt_params"], ex["answer_params"]
        if es != {"e": ep["e"], "d": ex["answer"], "t": ep["t"]} or (ep["e"] * ex["answer"]) % ep["t"] != 1:
            errors.append("the worked example should show e × d landing on 1")
    return errors


def _lock_number(problem: dict, lock: dict, pr: dict, encrypt: bool) -> list[str]:
    n, e, d = lock["n"], lock["e"], lock["d"]
    errors: list[str] = []
    if encrypt:
        m = problem["meta"].get("m")
        if problem["prompt_line_id"] != "z11.rsa.prompt_encrypt" or pr != {"m": m, "e": e, "n": n} or not (2 <= m < n) or problem["answer"] != pow(m, e, n):
            errors.append("encrypt: the answer is m^e on the loop of n")
        raw = m ** e
        candidates = [("used_d_not_e", pow(m, d, n)), ("multiplied_instead", (m * e) % n)]
        if raw <= MAX_RAW:
            candidates.append(("forgot_mod_wrap", raw))
        picture = {"type": "notation", "form": "power", "base": m, "exp": e}
        line, wanted_ex = "z11.hint.example_encrypt", lambda ep, es, ans: es == {"m": ep["m"], "e": ep["e"], "n": ep["n"], "c": ans} and pow(ep["m"], ep["e"], ep["n"]) == ans
    else:
        c = problem["meta"].get("c")
        m = problem["answer"]
        if problem["prompt_line_id"] != "z11.rsa.prompt_decrypt" or pr != {"c": c, "d": d, "n": n} or not (2 <= m < n) or m != pow(c, d, n) or c != pow(m, e, n):
            errors.append("decrypt: the answer is c^d on the loop of n, and locking it gives c back")
        candidates = [("used_e_not_d", pow(c, e, n)), ("gave_cipher", c)]
        picture = {"type": "notation", "form": "power", "base": c, "exp": d}
        line, wanted_ex = "z11.hint.example_decrypt", lambda ep, es, ans: es == {"c": ep["c"], "d": ep["d"], "n": ep["n"], "m": ans} and pow(ep["c"], ep["d"], ep["n"]) == ans
    wanted = filtered(problem["answer"], candidates)
    if distractor_pairs(problem) != wanted:
        errors.append(f"the wrong answers should be {wanted}, got {distractor_pairs(problem)}")
    if problem["representation"] == "pictorial":
        if problem["visual"] != picture:
            errors.append("a pictorial problem shows the power")
    elif problem["visual"]:
        errors.append("an abstract problem is words only")
    if problem["hint_steps"][1]["visual"] != picture:
        errors.append("the rung 2 model should show the power")
    ex = problem["hint_steps"][2]["example"]
    if ex["answer_line_id"] != line or not wanted_ex(ex["prompt_params"], ex["answer_params"], ex["answer"]):
        errors.append("the worked example should work out its power on the loop")
    return errors
