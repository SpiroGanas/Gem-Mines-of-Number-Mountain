"""Independent re-derivation of the GaussGenerator problems (Zone 9 skills gauss.sum.*).

The sum 1 + 2 + ... + n is added one number at a time, never with the formula the generator uses."""
from __future__ import annotations

from .figurate import _expect, square


def check(problem: dict) -> list[str]:
    p = problem["prompt_params"]
    n = p["n"]
    formula = problem["params"].get("require_formula", False)
    errors = []
    if (p["a"], p["b"]) != (1, 2):
        errors.append("the sum starts 1 + 2")
    low = 21 if formula else 2
    if not low <= n <= problem["params"].get("max_n", 20):
        errors.append(f"n = {n} is out of range")
    total = 0
    for number in range(1, n + 1):
        total += number
    if problem["answer"] != total:
        errors.append(f"1 + ... + {n} = {total}, not {problem['answer']}")
    wanted = {"forgot_halve": {total + total}, "used_n_squared": {square(n)}, "off_by_one_n": {total - n}}
    errors += _expect(problem, wanted)
    if formula:
        if problem["visual"] or problem["meta"].get("pad_digits") != 4 or problem["prompt_line_id"] != "z9.gauss.prompt_formula":
            errors.append("a formula problem has no picture, the formula prompt and a four-digit pad")
    elif problem["representation"] == "pictorial" and problem["visual"] != {"type": "pairing", "n": n}:
        errors.append("the pictorial problem shows the pairing picture")
    q = problem["hint_steps"][2]["example"]["answer_params"]
    if q["p"] != q["n"] + 1 or q["d"] != q["n"] * q["p"] or q["t"] + q["t"] != q["d"]:
        errors.append("the worked example's pairing is wrong")
    return errors
