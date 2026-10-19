"""Independent re-derivation of the ExponentGenerator and RootGenerator problems (Zone 8 exp.* and
root.square.perfect).

Powers are recomputed with Python's exact integer `**`, square roots with math.isqrt, and the
written-out calculation of a power ("3 × 3 × 3 × 3") with math.prod. Each named mistake is rebuilt
from the numbers in the problem and must appear exactly (common.filtered drops one equal to the answer
or to an earlier one, as every generator must)."""
from __future__ import annotations

import math

from .common import distractor_pairs, filtered, is_int

TOWER_FLOORS = 10


def _tower(base: int, exp: int, values: bool) -> dict:
    return {"type": "power_tower", "base": base, "exp": exp, "values": values}


def _card(base: int, exp: int) -> dict:
    return {"type": "notation", "form": "power", "base": base, "exp": exp}


def _array(n: int, outline: bool = False) -> dict:
    picture = {"type": "array", "rows": n, "cols": n}
    if outline:
        picture["outline_rows"] = True
    return picture


def _calc(op: str, terms: list[int]) -> dict:
    return {"op": op, "terms": terms}


def _expect(problem: dict, candidates: list[tuple[str, object]]) -> list[str]:
    wanted = filtered(problem["answer"], candidates)
    got = distractor_pairs(problem)
    return [] if got == wanted else [f"the wrong answers should be {wanted}, got {got}"]


def _example(problem: dict) -> dict:
    return problem["hint_steps"][2]["example"]


def check(problem: dict) -> list[str]:
    mode = problem["params"].get("mode")
    checker = {
        "repeated_mult": _repeated, "evaluate": _evaluate, "square": _square, "cube": _cube,
        "powers_of_base": _powers, "special_exponents": _special,
    }.get(mode)
    if checker is None:
        return [f"unknown exponent mode {mode!r}"]
    return checker(problem)


def _repeated(problem: dict) -> list[str]:
    b, e = problem["prompt_params"]["b"], problem["prompt_params"]["e"]
    errors = []
    if not (2 <= b <= problem["params"]["max_base"] and 2 <= e <= problem["params"]["max_exp"]):
        errors.append(f"base {b} or exponent {e} is out of range")
    answer = problem["answer"]
    if answer != _calc("mul", [b] * e) or math.prod(answer["terms"]) != b ** e:
        errors.append(f"{b} to the power {e} is {e} copies of {b} multiplied, not {answer}")
    shown = {"concrete": _tower(b, e, False), "pictorial": _tower(b, e, True), "abstract": _card(b, e)}[problem["representation"]]
    if problem["visual"] != shown:
        errors.append(f"the {problem['representation']} picture should be {shown}")
    errors += _expect(problem, [
        ("multiplied_base_by_exp", _calc("mul", [b, e])),
        ("added_base_exp_times", _calc("add", [b] * e)),
        ("swapped_base_exp", _calc("mul", [e] * b)),
        ("off_by_one_exponent", _calc("mul", [b] * (e + 1))),
    ])
    if problem["hint_steps"][1]["visual"] != _tower(b, e, True):
        errors.append("the rung 2 model should be the tower with its heights")
    ex = _example(problem)
    if ex["answer_line_id"] != "z8.hint.example_repeat" or ex["answer_params"] != ex["prompt_params"]:
        errors.append("the worked example should name its own power")
    return errors


def _evaluate(problem: dict) -> list[str]:
    b, e = problem["prompt_params"]["b"], problem["prompt_params"]["e"]
    p = problem["params"]
    errors = []
    if not (2 <= b <= p["max_base"] and 2 <= e <= p["max_exp"]):
        errors.append(f"base {b} or exponent {e} is out of range")
    if problem["answer"] != b ** e or b ** e > p["max_value"]:
        errors.append(f"{b} to the power {e} is {b ** e} (at most {p['max_value']}), not {problem['answer']}")
    if problem["representation"] == "pictorial":
        if problem["prompt_line_id"] != "z8.evaluate.prompt_tower" or problem["visual"] != _tower(b, e, False):
            errors.append("a pictorial problem shows the tower without its heights")
    elif problem["prompt_line_id"] != "z8.evaluate.prompt" or problem["visual"] != _card(b, e):
        errors.append("an abstract problem shows the power card")
    errors += _expect(problem, [
        ("multiplied_base_by_exp", b * e),
        ("off_by_one_exponent", b ** (e + 1)),
        ("off_by_one_exponent", b ** (e - 1)),
        ("swapped_base_exp", e ** b),
    ])
    ex = _example(problem)
    q = ex["answer_params"]
    if ex["answer_line_id"] != "z8.hint.example_value" or q["v"] != q["b"] ** q["e"] or ex["answer"] != q["v"]:
        errors.append("the worked example's value is wrong")
    return errors


def _square(problem: dict) -> list[str]:
    n = problem["prompt_params"]["n"]
    errors = []
    if not 2 <= n <= problem["params"]["max_n"]:
        errors.append(f"{n} is out of range")
    if problem["answer"] != n * n:
        errors.append(f"{n} squared is {n * n}, not {problem['answer']}")
    if problem["representation"] == "concrete":
        if n > 10 or problem["visual"] != _array(n) or problem["prompt_line_id"] != "z8.square.prompt_array":
            errors.append("a concrete square is an array of gems, at most 10 a side")
    elif problem["visual"] != _card(n, 2):
        errors.append("an abstract square shows n with a raised 2")
    errors += _expect(problem, [("doubled", 2 * n), ("off_by_one_square", (n + 1) ** 2), ("off_by_one_square", (n - 1) ** 2)])
    model = problem["hint_steps"][1]["visual"]
    if model != (_array(n, True) if n <= 10 else _card(n, 2)):
        errors.append("the rung 2 model should be the outlined square (or the card past 10)")
    q = _example(problem)["answer_params"]
    if q["v"] != q["n"] ** 2:
        errors.append("the worked example's square is wrong")
    return errors


def _cube(problem: dict) -> list[str]:
    n = problem["prompt_params"]["n"]
    errors = []
    if not 2 <= n <= min(problem["params"]["max_n"], 8):
        errors.append(f"{n} is out of range (a cube is drawn at most 8 blocks a side)")
    if problem["answer"] != n ** 3:
        errors.append(f"{n} cubed is {n ** 3}, not {problem['answer']}")
    shown = {"type": "cube_blocks", "n": n} if problem["representation"] == "concrete" else _card(n, 3)
    if problem["visual"] != shown:
        errors.append(f"the picture should be {shown}")
    errors += _expect(problem, [("tripled", 3 * n), ("squared_only", n * n)])
    q = _example(problem)["answer_params"]
    if q["v"] != q["n"] ** 3:
        errors.append("the worked example's cube is wrong")
    return errors


def _powers(problem: dict) -> list[str]:
    base = problem["params"]["base"]
    authored = problem["params"]["max_exp"]
    errors = []
    if problem["prompt_line_id"] == "z8.two.prompt_ride":
        n = problem["prompt_params"]["n"]
        k = problem["answer"]
        tower = problem["meta"].get("tower", {})
        floors = tower.get("floors", -1)
        if problem["representation"] != "concrete" or tower.get("base") != base or tower.get("start") != 0:
            errors.append("only concrete problems ride the elevator, from floor 0")
        if not (is_int(k) and 1 <= k <= floors <= min(authored, TOWER_FLOORS)) or base ** k != n:
            errors.append(f"floor {k} is at {base} to the power {k} meters, not {n}")
            return errors
        candidates = [("off_by_one_exponent", k + 1 if k < floors else k - 1)]
        if 0 < k < floors:
            candidates.append(("off_by_one_exponent", k - 1))
        errors += _expect(problem, candidates)
        q = _example(problem)
        if q["answer_line_id"] != "z8.hint.example_floor" or base ** q["answer_params"]["k"] != q["answer_params"]["n"]:
            errors.append("the worked example's floor is wrong")
        return errors
    b, e = problem["prompt_params"]["b"], problem["prompt_params"]["e"]
    if b != base or not 1 <= e <= min(authored, TOWER_FLOORS):
        errors.append(f"the power {b} to the {e} is out of range")
    if problem["answer"] != b ** e:
        errors.append(f"{b} to the power {e} is {b ** e}, not {problem['answer']}")
    if problem["meta"].get("pad_digits") != max(3, len(str(base ** authored))):
        errors.append("the pad should hold the digits of the largest power the skill asks for")
    if problem["visual"] != _card(b, e):
        errors.append("the power card should show the power")
    if base == 10:
        candidates = [("off_by_one_exponent", 10 ** (e + 1)), ("counted_digits_not_zeros", 10 ** (e - 1)),
                      ("multiplied_base_by_exp", 10 * e)]
    else:
        candidates = [("off_by_one_exponent", b ** (e + 1)), ("off_by_one_exponent", b ** (e - 1)),
                      ("added_two", b ** (e - 1) + 2)]
    errors += _expect(problem, candidates)
    return errors


def _special(problem: dict) -> list[str]:
    b, e = problem["prompt_params"]["b"], problem["prompt_params"]["e"]
    errors = []
    if not (2 <= b <= problem["params"]["max_base"] and e in (0, 1)):
        errors.append(f"base {b} or exponent {e} is out of range")
    expected = 1 if e == 0 else b
    if problem["answer"] != expected:
        errors.append(f"{b} to the power {e} is {expected}, not {problem['answer']}")
    first = ("zero_power_is_zero", 0) if e == 0 else ("first_power_is_one", 1)
    errors += _expect(problem, [first, ("added_base_and_exp", b + e)])
    if problem["hint_steps"][1]["visual"] != _tower(b, e, True):
        errors.append("the rung 2 model should be the tower (power 0: only the ground floor)")
    ex = _example(problem)
    line = "z8.hint.example_zero" if ex["prompt_params"]["e"] == 0 else "z8.hint.example_one"
    if ex["answer_line_id"] != line:
        errors.append(f"the worked example should use {line}")
    return errors


def check_root(problem: dict) -> list[str]:
    n = problem["prompt_params"]["n"]
    root = math.isqrt(n)
    errors = []
    if root * root != n:
        errors.append(f"{n} is not a perfect square")
        return errors
    if problem["answer"] != root or not 2 <= root <= problem["params"]["max_root"]:
        errors.append(f"the square root of {n} is {root}, not {problem['answer']}")
    if problem["representation"] == "pictorial":
        if root > 10 or problem["visual"] != _array(root) or problem["prompt_line_id"] != "z8.root.prompt_array":
            errors.append("a pictorial root is the side of a square of gems, at most 10")
    elif problem["visual"] != {"type": "notation", "form": "root", "n": n}:
        errors.append("an abstract root shows the root sign over n")
    candidates = [("halved", n // 2)] if n % 2 == 0 else []
    candidates += [("off_by_one_root", root + 1), ("off_by_one_root", root - 1)]
    errors += _expect(problem, candidates)
    q = _example(problem)["answer_params"]
    if q["r"] * q["r"] != q["n"]:
        errors.append("the worked example's root is wrong")
    return errors
