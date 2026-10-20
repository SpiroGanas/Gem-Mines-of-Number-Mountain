"""Independent re-derivation of the ModInverseGenerator problems (Zone 11, skills modinv.*).

The undo partner is found by trying every number; "exists" is read off the multiplying row (does it hold a 1?) and
cross-checked with math.gcd. Nothing here is ported from scripts/generators/mod_inverse.gd."""
from __future__ import annotations

import math

from .common import distractor_pairs, filtered
from .modular import cayley

MAX_N = 12


def partners(a: int, n: int) -> list[int]:
    return [x for x in range(1, n) if (a * x) % n == 1]


def check(problem: dict) -> list[str]:
    mode, skill = problem["params"]["mode"], problem["params"]
    p = problem["prompt_params"]
    if set(p) != {"a", "n"}:
        return ["the prompt should have {a, n}"]
    a, n = p["a"], p["n"]
    errors: list[str] = []
    if not (max(skill["min_n"], 3) <= n <= min(skill["max_n"], MAX_N) and 2 <= a < n):
        errors.append(f"{a} on a loop of {n} is out of range")
    found = partners(a, n)
    if (len(found) > 0) != (math.gcd(a, n) == 1) or len(found) > 1:
        errors.append(f"{a} on a loop of {n}: partners {found} disagree with gcd {math.gcd(a, n)}")
    wanted_visual = cayley(n, "mul", True, row=a)
    if mode == "exists":
        if problem["prompt_line_id"] != "z11.modinv.prompt_exists" or problem["answer"] is not bool(found):
            errors.append("exists: the answer is whether row a holds a 1")
        wrong = "used_gcd_not_inverse" if problem["answer"] else "thought_always_exists"
        if distractor_pairs(problem) != [(wrong, not problem["answer"])]:
            errors.append(f"the one wrong answer should be {(wrong, not problem['answer'])}")
        if problem["meta"].get("label_lines") != {"true": "ui.common.yes", "false": "ui.common.no"}:
            errors.append("the answer buttons read Yes and No")
        ex = problem["hint_steps"][2]["example"]
        ea, en = ex["prompt_params"]["a"], ex["prompt_params"]["n"]
        line = "z11.hint.example_modinv_yes" if ex["answer"] else "z11.hint.example_modinv_no"
        if ex["answer_line_id"] != line or ex["answer_params"] != {"a": ea, "n": en, "g": math.gcd(ea, en)} or ex["answer"] is not bool(partners(ea, en)):
            errors.append("the worked example should name the GCF")
    else:
        if problem["prompt_line_id"] != "z11.modinv.prompt_find" or found != [problem["answer"]]:
            errors.append(f"the undo partner of {a} on a loop of {n} is {found}, not {problem['answer']}")
        x = problem["answer"]
        errors += _compare(problem, [("gave_additive_inverse", n - a), ("used_gcd_not_inverse", 1), ("off_by_one", x + 1 if x + 1 < n else x - 1)])
        ex = problem["hint_steps"][2]["example"]
        ea, en, ep = ex["prompt_params"]["a"], ex["prompt_params"]["n"], ex["answer_params"]
        if ex["answer_line_id"] != "z11.hint.example_modinv_find" or ep != {"a": ea, "x": ex["answer"], "t": ea * ex["answer"], "n": en} or (ea * ex["answer"]) % en != 1:
            errors.append("the worked example should show a × x landing on 1")
    if problem["representation"] == "pictorial":
        if problem["visual"] != wanted_visual:
            errors.append("a pictorial problem shows the multiplying table with row a lit")
    elif problem["visual"]:
        errors.append("an abstract problem is words only")
    if problem["hint_steps"][1]["visual"] != wanted_visual:
        errors.append("the rung 2 model should light row a of the table")
    return errors


def _compare(problem: dict, candidates: list[tuple[str, object]]) -> list[str]:
    wanted = filtered(problem["answer"], candidates)
    if distractor_pairs(problem) != wanted:
        return [f"the wrong answers should be {wanted}, got {distractor_pairs(problem)}"]
    return []
