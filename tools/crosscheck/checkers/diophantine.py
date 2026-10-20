"""Independent re-derivation of the DiophantineGenerator problems (Zone 11, skills dioph.*).

Every way to pay a total is found by trying every count of the first coin; "can be paid" is brute force, then
compared with the GCF rule. Nothing here is ported from scripts/generators/diophantine.gd."""
from __future__ import annotations

import math

from .common import distractor_pairs, filtered

MAX_COINS = 12
MAX_TOTAL = 250


def ways(a: int, b: int, c: int) -> list[list[int]]:
    return [[x, (c - a * x) // b] for x in range(c // a + 1) if (c - a * x) % b == 0]


def picture(a: int, b: int, c: int) -> dict:
    return {"type": "coins", "a": a, "b": b, "c": c}


def check(problem: dict) -> list[str]:
    mode, skill = problem["params"]["mode"], problem["params"]
    p = problem["prompt_params"]
    if set(p) != {"a", "b", "c"}:
        return ["the prompt should have {a, b, c}"]
    a, b, c = p["a"], p["b"], p["c"]
    errors: list[str] = []
    if a == b or not (skill["min_coin"] <= a <= skill["max_coin"] and skill["min_coin"] <= b <= skill["max_coin"]) or not 1 <= c <= MAX_TOTAL:
        errors.append(f"coins {a} and {b} and total {c} are outside the skill's ranges")
    found = ways(a, b, c)
    if mode == "solve":
        x, y = problem["answer"]
        if problem["prompt_line_id"] != "z11.dioph.prompt_solve" or found != [[x, y]] or not (1 <= x <= MAX_COINS and 1 <= y <= MAX_COINS):
            errors.append(f"the ways to pay {c} with {a} and {b} are {found}; the answer should be the only one, with 1..{MAX_COINS} of each")
        if a + b >= a * b // math.gcd(a, b):
            errors.append("the coins should have a sum below their least common multiple")
        candidates = [("swapped_counts", [y, x]), ("one_coin_too_many", [x + 1, y]), ("one_coin_too_few", [x, y - 1])]
        wanted = filtered(problem["answer"], candidates)
        if distractor_pairs(problem) != wanted:
            errors.append(f"the wrong answers should be {wanted}, got {distractor_pairs(problem)}")
        if problem["meta"].get("array_label") != "coins":
            errors.append("the answer buttons read the counts")
        if problem["representation"] == "concrete":
            if problem["meta"].get("coin_puzzle") != {"a": a, "b": b, "c": c, "max": MAX_COINS} or problem["visual"]:
                errors.append("a concrete problem is the coin puzzle, with no other picture")
        elif problem["visual"] != picture(a, b, c):
            errors.append("an abstract problem shows the coins and the total")
        if problem["hint_steps"][1]["visual"] != picture(a, b, c):
            errors.append("the rung 2 model should show the coins and the total")
        ex = problem["hint_steps"][2]["example"]
        ep, es = ex["prompt_params"], ex["answer_params"]
        ex_x, ex_y = ex["answer"]
        if ex["answer_line_id"] != "z11.hint.example_coins" or es != {"a": ep["a"], "x": ex_x, "b": ep["b"], "y": ex_y, "c": ep["c"]} or ep["a"] * ex_x + ep["b"] * ex_y != ep["c"]:
            errors.append("the worked example should pay its total exactly")
        return errors
    g = math.gcd(a, b)
    payable = bool(found)
    if problem["prompt_line_id"] != "z11.dioph.prompt_decide" or problem["answer"] is not payable:
        errors.append(f"{c} can be paid with {a} and {b}: {payable}, not {problem['answer']}")
    if payable != (c % g == 0):
        errors.append(f"the GCF rule disagrees with trying every count: {c} {g} {payable}")
    if problem["meta"].get("bound") != g * (a // g - 1) * (b // g - 1) or c <= problem["meta"]["bound"]:
        errors.append("the total should be past the bound where every multiple of the GCF can be paid")
    wrong = "doubted_big_total" if payable else "ignored_gcd_condition"
    if distractor_pairs(problem) != [(wrong, not payable)]:
        errors.append(f"the one wrong answer should be {(wrong, not payable)}")
    if problem["meta"].get("label_lines") != {"true": "ui.common.yes", "false": "ui.common.no"}:
        errors.append("the answer buttons read Yes and No")
    if problem["representation"] == "pictorial":
        if problem["visual"] != picture(a, b, c):
            errors.append("a pictorial problem shows the coins and the total")
    elif problem["visual"]:
        errors.append("an abstract problem is words only")
    if problem["hint_steps"][1]["visual"] != picture(a, b, c):
        errors.append("the rung 2 model should show the coins and the total")
    ex = problem["hint_steps"][2]["example"]
    ep, es = ex["prompt_params"], ex["answer_params"]
    eg = math.gcd(ep["a"], ep["b"])
    line = "z11.hint.example_pay_yes" if ex["answer"] else "z11.hint.example_pay_no"
    if ex["answer_line_id"] != line or es != {"c": ep["c"], "g": eg} or ex["answer"] is not (ep["c"] % eg == 0):
        errors.append("the worked example should name the GCF and whether it divides the total")
    return errors
