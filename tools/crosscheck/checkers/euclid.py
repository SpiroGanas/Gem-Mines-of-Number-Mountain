"""Independent re-derivation of the EuclidGenerator problems (Zone 11, skills euclid.*).

The machine is run with divmod; the GCF is cross-checked with math.gcd; the x of the backward run is found by trying
every number below b ÷ g. Nothing here is ported from scripts/generators/euclid.gd."""
from __future__ import annotations

import math

from .common import distractor_pairs, filtered

MAX_STEPS = 8


def rows(a: int, b: int) -> list[tuple[int, int, int, int]]:
    """(big, small, quotient, remainder) for each step until the remainder is 0."""
    result = []
    while b:
        q, r = divmod(a, b)
        result.append((a, b, q, r))
        a, b = b, r
    return result


def picture(a: int, b: int, upto: int) -> dict:
    return {"type": "euclid", "a": a, "b": b, "upto": upto}


def smallest_x(a: int, b: int) -> int:
    """The one x from 0 to b // g - 1 with a × x leaving g when divided by b."""
    g = math.gcd(a, b)
    hits = [x for x in range(b // g) if (a * x) % b == g % b]
    assert len(hits) == 1
    return hits[0]


def check(problem: dict) -> list[str]:
    mode, skill = problem["params"]["mode"], problem["params"]
    if mode == "extended":
        return _extended(problem, skill)
    p = problem["prompt_params"]
    if set(p) != {"a", "b"}:
        return ["the prompt should have {a, b}"]
    a, b = p["a"], p["b"]
    errors: list[str] = []
    steps = rows(a, b)
    if not (skill["min"] <= b < a <= skill["max"]) or not 1 <= len(steps) <= MAX_STEPS:
        errors.append(f"{a} and {b} should satisfy {skill['min']} <= b < a <= {skill['max']} and run 1 to {MAX_STEPS} steps")
    g = steps[-1][1]
    if g != math.gcd(a, b):
        errors.append(f"the machine ends at {g} but gcd({a}, {b}) is {math.gcd(a, b)}")
    if mode == "basic":
        if problem["prompt_line_id"] != "z11.euclid.prompt_gcd" or problem["answer"] != g:
            errors.append(f"the GCF of {a} and {b} is {g}, not {problem['answer']}")
        wanted = filtered(g, [("stopped_one_step_early", steps[-1][0]), ("gave_last_quotient", steps[-1][2]), ("gave_smaller", b)])
        line = "z11.hint.example_gcd"
    else:
        if problem["prompt_line_id"] != "z11.euclid.prompt_count" or problem["answer"] != len(steps):
            errors.append(f"the machine takes {len(steps)} steps, not {problem['answer']}")
        wanted = filtered(len(steps), [("off_by_one", len(steps) + 1), ("off_by_one", len(steps) - 1), ("gave_gcd_instead", g)])
        line = "z11.hint.example_count"
    if distractor_pairs(problem) != wanted:
        errors.append(f"the wrong answers should be {wanted}, got {distractor_pairs(problem)}")
    if problem["representation"] == "pictorial":
        if problem["visual"] != picture(a, b, 0):
            errors.append("a pictorial problem shows the two bars")
    elif problem["visual"]:
        errors.append("an abstract problem is words only")
    if problem["hint_steps"][1]["visual"] != picture(a, b, -1):
        errors.append("the rung 2 model should show every step")
    ex = problem["hint_steps"][2]["example"]
    ea, eb = ex["prompt_params"]["a"], ex["prompt_params"]["b"]
    egcd = rows(ea, eb)[-1][1]
    want = {"a": ea, "b": eb, "g": egcd} if mode == "basic" else {"a": ea, "b": eb, "k": len(rows(ea, eb))}
    if ex["answer_line_id"] != line or ex["answer_params"] != want:
        errors.append("the worked example should name its GCF (or its steps)")
    return errors


def _extended(problem: dict, skill: dict) -> list[str]:
    p = problem["prompt_params"]
    if set(p) != {"a", "b", "g", "m"} or problem["prompt_line_id"] != "z11.euclid.prompt_extended":
        return ["the prompt should be z11.euclid.prompt_extended with {a, b, g, m}"]
    a, b, g, m = p["a"], p["b"], p["g"], p["m"]
    errors: list[str] = []
    if a == b or not (2 <= a <= skill["max"] and 5 <= b <= skill["max"]) or g != math.gcd(a, b) or m != b // g or m < 3:
        errors.append(f"a {a}, b {b}, g {g}, m {m} should satisfy a != b, gcd, m = b ÷ g >= 3 and the ranges")
        return errors
    x = smallest_x(a, b)
    if problem["answer"] != x:
        errors.append(f"x with {a} × x leaving {g} after dividing by {b} (below {m}) is {x}, not {problem['answer']}")
    other = smallest_x(b, a)
    if problem["meta"].get("other") != other:
        errors.append("meta.other should be the answer for the other bar")
    wanted = filtered(x, [("swapped_coeffs", other), ("sign_flip", (m - x) % m), ("off_by_one", x + 1 if x + 1 < m else x - 1)])
    if distractor_pairs(problem) != wanted:
        errors.append(f"the wrong answers should be {wanted}, got {distractor_pairs(problem)}")
    big, small = max(a, b), min(a, b)
    if problem["representation"] == "pictorial":
        if problem["visual"] != picture(big, small, -1):
            errors.append("a pictorial problem shows every step of the machine")
    elif problem["visual"]:
        errors.append("an abstract problem is words only")
    if problem["hint_steps"][1]["visual"] != picture(big, small, -1):
        errors.append("the rung 2 model should show every step")
    ex = problem["hint_steps"][2]["example"]
    ep, es = ex["prompt_params"], ex["answer_params"]
    if ex["answer_line_id"] != "z11.hint.example_extended" or es != {"a": ep["a"], "x": ex["answer"], "g": ep["g"], "b": ep["b"]} or ex["answer"] != smallest_x(ep["a"], ep["b"]):
        errors.append("the worked example should show its x")
    return errors
