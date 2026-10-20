"""Independent re-derivation of the DivisibilityWhyGenerator problems (Zone 10, skills div.rule.explain_*).

The remainder is found by subtracting the divisor until less than it is left, and the digit sum by reading the
number's decimal text. Nothing here is ported from scripts/generators/divisibility_why.gd."""
from __future__ import annotations

from .common import distractor_pairs, filtered


def leftover(a: int, b: int) -> int:
    while a >= b:
        a -= b
    return a


def digits(a: int) -> list[int]:
    return [int(ch) for ch in str(a)]


def check(problem: dict) -> list[str]:
    mode = problem["params"].get("mode")
    if mode not in ("digit_sum", "last_digit", "last_digits"):
        return [f"unknown divisibility mode {mode!r}"]
    p, skill = problem["prompt_params"], problem["params"]
    a, b = p["a"], p["b"]
    errors: list[str] = []
    if b not in skill["bases"] or not skill["min_a"] <= a <= skill["max_a"]:
        errors.append(f"{a} ÷ {b} is outside the skill's ranges")
    ds = digits(a)
    total, last, first = sum(ds), ds[-1], ds[0]
    if problem["answer"] != leftover(a, b):
        errors.append(f"{a} ÷ {b} leaves {leftover(a, b)}, not {problem['answer']}")
    if mode == "digit_sum":
        want_keys, line, focus = {"a", "b", "s"}, "z10.div.prompt_digit_sum", "sum"
        if p.get("s") != total:
            errors.append(f"the digits of {a} add up to {total}, not {p.get('s')}")
        candidates = [("used_last_digit", leftover(last, b)), ("summed_wrong", leftover(total - last, b))]
        example_line = "z10.hint.example_digit_sum"
    elif mode == "last_digit":
        want_keys, line, focus = {"a", "b"}, "z10.div.prompt_last_digit", "last"
        candidates = [("used_first_digit", leftover(first, b)), ("used_digit_sum", leftover(total, b))]
        example_line = "z10.hint.example_last_digit"
    else:
        want_keys, line, focus = {"a", "b", "k"}, "z10.div.prompt_last_digits", "last_two" if b == 4 else "last_three"
        if p.get("k") != (2 if b == 4 else 3):
            errors.append(f"base {b} looks at {2 if b == 4 else 3} digits, not {p.get('k')}")
        candidates = [("used_last_digit_only", leftover(last, b)), ("used_digit_sum", leftover(total, b))]
        example_line = "z10.hint.example_last_digits"
    if set(p) != want_keys or problem["prompt_line_id"] != line:
        errors.append(f"the prompt should be {line} with {sorted(want_keys)}")
    wanted = filtered(problem["answer"], candidates)
    if distractor_pairs(problem) != wanted:
        errors.append(f"the wrong answers should be {wanted}, got {distractor_pairs(problem)}")
    picture = {"type": "digits", "digits": ds, "focus": focus}
    if problem["representation"] == "pictorial":
        if problem["visual"] != picture:
            errors.append("a pictorial problem shows the digits with the deciding part lit")
    elif problem["visual"]:
        errors.append("an abstract problem is words only")
    if problem["hint_steps"][1]["visual"] != picture:
        errors.append("the rung 2 model should light the deciding digits")
    ex = problem["hint_steps"][2]["example"]
    ep = ex["prompt_params"]
    if ex["answer_line_id"] != example_line or ex["answer_params"]["a"] != ep["a"] or ex["answer_params"]["r"] != leftover(ep["a"], ep["b"]):
        errors.append("the worked example should name its remainder")
    return errors
