"""Independent re-derivation of the SubtractionGenerator problems (skills sub.*).

Every number is recomputed from the exported facts only (the two numbers in the prompt, the skill
params and the pictures), with digits read from decimal strings. Each wrong answer is rebuilt from
the definition of its misconception. Ranges are checked against the skill's params.
"""
from __future__ import annotations

from .addition import digits, distractor_errors, loose, pile_for, swapped

PROMPTS = {"facts": "z2.sub.prompt_diff", "tens": "z2.sub.prompt_tens", "two_digit": "z2.sub.prompt_diff"}
EXAMPLE_LINE = "z2.hint.example_sub"


def kind_of(params: dict) -> str | None:
    """The kind of difference a skill's params ask for (the skill files' contract for mode "diff")."""
    mode = params.get("mode")
    if mode == "tens":
        return "tens"
    if mode == "diff":
        return "two_digit" if "regroup" in params else "facts"
    return None


def check(problem: dict) -> list[str]:
    params = problem["params"]
    kind = kind_of(params)
    if kind is None:
        return [f"unknown subtraction mode {params.get('mode')!r}"]
    if set(problem["prompt_params"]) != {"a", "b"}:
        return [f"prompt params should be ['a', 'b'], got {sorted(problem['prompt_params'])}"]
    a, b = problem["prompt_params"]["a"], problem["prompt_params"]["b"]
    diff = a - b
    errors: list[str] = []
    if problem["answer"] != diff:
        errors.append(f"answer {problem['answer']} is not {a} - {b} = {diff}")
    if problem["prompt_line_id"] != PROMPTS[kind]:
        errors.append(f"wrong prompt line {problem['prompt_line_id']!r} for {kind}")
    if problem["meta"]:
        errors.append(f"unexpected meta {problem['meta']!r}")
    errors += range_errors(kind, a, b, params)
    errors += _pictures(problem, kind, a, b)
    errors += distractor_errors(problem, *_wrong_answers(kind, a, b, params))
    errors += _example_errors(problem, kind, params)
    return errors


def range_errors(kind: str, a: int, b: int, params: dict) -> list[str]:
    """The numbers a skill may use (also applied to the worked example)."""
    errors: list[str] = []
    if kind == "facts":
        limit = params["max"]
        lowest = 11 if limit > 10 else 2  # within 20 practices teen numbers; within 10 is its own skill
        if not lowest <= a <= limit:
            errors.append(f"{a} should be from {lowest} to {limit}")
        if not 1 <= b <= min(a, 9):
            errors.append(f"{a} - {b}: take away 1 to 9, and never more than {a}")
    elif kind == "tens":
        if a % 10 or b % 10 or b < 10:
            errors.append(f"{a} and {b} should both be tens (10, 20, ...)")
        if not b < a <= params["max"]:
            errors.append(f"{a} - {b}: b should be less than a, and a at most {params['max']}")
        if params.get("multiples_of_ten") is not True:
            errors.append("the tens skill should say multiples_of_ten")
    else:
        if not 10 <= a <= min(params["max"], 99) or not 1 <= b < a:
            errors.append(f"{a} - {b} should be a two-digit number minus a smaller number")
            return errors
        a_ones, b_ones = digits(a)[1], digits(b)[1]
        if params["regroup"] and a_ones >= b_ones:
            errors.append(f"{a} - {b} needs regrouping, but {a_ones} ones is enough to take away {b_ones}")
        if not params["regroup"] and a_ones < b_ones:
            errors.append(f"{a} - {b} should not need regrouping, but {a_ones} ones is fewer than {b_ones}")
    return errors


def _pictures(problem: dict, kind: str, a: int, b: int) -> list[str]:
    """The problem's picture and the rung 2 hint model."""
    errors: list[str] = []
    diff = a - b
    visual = problem["visual"]
    model = problem["hint_steps"][1]["visual"]
    if kind == "facts":
        if problem["representation"] == "concrete":
            if visual != {"type": "gem_piles", "piles": [loose(a)]}:
                errors.append(f"the picture should be a pile of {a} loose gems")
        elif visual != {"type": "ten_frame", "count": a, "frames": max(1, -(-a // 10))}:
            errors.append(f"the picture should be ten-frames holding {a} dots")
        through_ten = a > 10 > diff
        jumps = [{"from": a, "to": 10}, {"from": 10, "to": diff}] if through_ten else [{"from": a, "to": diff}]
        if model.get("type") != "number_line" or model.get("jumps") != jumps or model.get("markers") != [a]:
            errors.append(f"the hint model should jump back from {a} to {diff}" + (" through 10" if through_ten else ""))
    elif kind == "tens":
        if visual != {"type": "gem_piles", "piles": [{"hundreds": 0, "tens": a // 10, "ones": 0}]}:
            errors.append(f"the picture should be {a // 10} ten-bars")
        jumps = [{"from": start, "to": start - 10} for start in range(a, diff, -10)]
        if model.get("type") != "number_line" or model.get("jumps") != jumps:
            errors.append(f"the hint model should count back by tens from {a} to {diff}")
    else:
        start = {"type": "gem_piles", "piles": [pile_for(a)]}
        if problem["representation"] != "concrete":
            if visual:
                errors.append("an abstract problem has no picture")
            if model != start:
                errors.append(f"the hint model should show {a} as tens and ones")
            return errors
        if visual != start:
            errors.append(f"the picture should show {a} as tens and ones")
        a_tens, a_ones = digits(a)
        b_tens, b_ones = digits(b)
        if problem["params"]["regroup"]:
            traded = {"hundreds": 0, "tens": a_tens - 1, "ones": a_ones + 10}
            if model != {"type": "gem_piles", "piles": [traded]}:
                errors.append(f"the hint model should show {a} after trading a ten: {traded}")
        else:
            jumps = []
            after_tens = a - 10 * b_tens
            if b_tens:
                jumps.append({"from": a, "to": after_tens})
            if b_ones:
                jumps.append({"from": after_tens, "to": diff})
            if model.get("type") != "number_line" or model.get("jumps") != jumps or a not in model.get("markers", []):
                errors.append(f"the hint model should jump back from {a} by {10 * b_tens}, then by {b_ones}")
    return errors


def _wrong_answers(kind: str, a: int, b: int, params: dict) -> tuple[dict[str, set[int]], set[int], set[str]]:
    """({misconception: the values it can give}, values that must be offered under some name,
    names that must be offered)."""
    diff = a - b
    if kind == "facts":
        near = {value for value in (diff - 1, diff + 1) if value >= 0}
        return {"added_instead": {a + b}, "off_by_one": near}, near | {a + b}, {"added_instead"}
    if kind == "tens":
        as_ones = {a // 10 - b // 10, a - b // 10}  # 70 - 30 as 7 - 3, or as 70 - 3
        return {"subtracted_as_ones": as_ones}, as_ones, {"subtracted_as_ones"}
    a_tens, a_ones = digits(a)
    b_tens, b_ones = digits(b)
    if params["regroup"]:
        smaller_from_larger = 10 * abs(a_tens - b_tens) + abs(a_ones - b_ones)
        not_taken_away = diff + 10  # traded the ten for ones but left it in the tens
        return ({"smaller_from_larger": {smaller_from_larger}, "forgot_untrade": {not_taken_away}},
                {smaller_from_larger, not_taken_away}, set())
    # Without regrouping, the smaller digit from the larger is simply right, so it is never offered.
    allowed = {"added_instead": {a + b}}
    swap = swapped(diff)
    if swap is not None:
        allowed["digit_swap"] = {swap}
    return allowed, set().union(*allowed.values()), {"added_instead"}


def _example_errors(problem: dict, kind: str, params: dict) -> list[str]:
    """The worked example (rung 3) is a solved problem of the same kind, stated correctly."""
    example = problem["hint_steps"][2]["example"]
    shown = example["prompt_params"]
    if set(shown) != {"a", "b"}:
        return ["the worked example's prompt params should be ['a', 'b']"]
    a, b = shown["a"], shown["b"]
    errors = [f"worked example: {error}" for error in range_errors(kind, a, b, params)]
    if example["prompt_line_id"] != problem["prompt_line_id"]:
        errors.append("the worked example asks a different kind of question")
    if example["answer"] != a - b:
        errors.append(f"the worked example's answer {example['answer']} is not {a} - {b} = {a - b}")
    if example["answer_line_id"] != EXAMPLE_LINE or example["answer_params"] != {"a": a, "b": b, "diff": a - b}:
        errors.append(f"the worked example should say {a} - {b} = {a - b}, not {example['answer_params']}")
    return errors
