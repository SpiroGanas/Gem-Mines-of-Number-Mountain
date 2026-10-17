"""Independent re-derivation of the AdditionGenerator problems (skills add.*).

Every number is recomputed from the exported facts only: the addends in the prompt, the skill
params and the pictures. Digits are read from decimal strings (the generator uses arithmetic), and
each wrong answer is rebuilt from the definition of its misconception. Ranges are checked against
the skill's params, which also bound the easier (difficulty below 0) problems.
"""
from __future__ import annotations

from .common import distractors_by_name

PROMPTS = {
    "facts": "z2.add.prompt_sum",
    "make_ten": "z2.add.prompt_make_ten",
    "doubles": "z2.add.prompt_sum",
    "tens": "z2.add.prompt_tens",
    "two_digit": "z2.add.prompt_sum",
    "three": "z2.add.prompt_three",
}
EXAMPLE_LINES = {"make_ten": "z2.hint.example_make_ten", "three": "z2.hint.example_add_three"}
DEFAULT_EXAMPLE_LINE = "z2.hint.example_add"


def kind_of(params: dict) -> str | None:
    """The kind of sum a skill's params ask for (the skill files' contract for mode "sums")."""
    mode = params.get("mode")
    if mode == "doubles_near":
        return "doubles"
    if mode == "tens":
        return "tens"
    if mode == "sums":
        if params.get("addends", 2) == 3:
            return "three"
        if "regroup" in params:
            return "two_digit"
        if params.get("strategy") == "make_ten":
            return "make_ten"
        return "facts"
    return None


def digits(n: int) -> tuple[int, int]:
    """(tens, ones) of a number below 100, read from its text: 7 is "07"."""
    text = f"{n:02d}"
    return int(text[0]), int(text[1])


def loose(n: int) -> dict:
    """A pile of n loose one-gems."""
    return {"hundreds": 0, "tens": 0, "ones": n}


def pile_for(n: int) -> dict:
    tens, ones = digits(n)
    return {"hundreds": 0, "tens": tens, "ones": ones}


def crossed_places(a: int, b: int) -> int | None:
    """What a child writes who puts b's ones digit in the tens column and b's tens digit in the
    ones column (34 + 25 as 86, 34 + 5 as 84). None unless both columns stay single digits and
    b's digits differ (otherwise it is not a clean, different two-digit number)."""
    a_tens, a_ones = digits(a)
    b_tens, b_ones = digits(b)
    tens, ones = a_tens + b_ones, a_ones + b_tens
    if tens > 9 or ones > 9 or b_tens == b_ones:
        return None
    return int(f"{tens}{ones}")


def swapped(n: int) -> int | None:
    """n with its two digits swapped, when that is a different two-digit number (not 44, not 40)."""
    text = str(n)
    if len(text) != 2 or text[1] == "0" or text[0] == text[1]:
        return None
    return int(text[::-1])


def check(problem: dict) -> list[str]:
    params = problem["params"]
    kind = kind_of(params)
    if kind is None:
        return [f"unknown addition mode {params.get('mode')!r}"]
    names = ("a", "b", "c") if kind == "three" else ("a", "b")
    if set(problem["prompt_params"]) != set(names):
        return [f"prompt params should be {list(names)}, got {sorted(problem['prompt_params'])}"]
    numbers = [problem["prompt_params"][name] for name in names]
    total = sum(numbers)
    errors: list[str] = []
    if problem["answer"] != total:
        errors.append(f"answer {problem['answer']} is not {' + '.join(map(str, numbers))} = {total}")
    if problem["prompt_line_id"] != PROMPTS[kind]:
        errors.append(f"wrong prompt line {problem['prompt_line_id']!r} for {kind}")
    if problem["meta"]:
        errors.append(f"unexpected meta {problem['meta']!r}")
    errors += range_errors(kind, numbers, params)
    errors += _pictures(problem, kind, numbers, total)
    allowed, required_values, required_names = _wrong_answers(kind, numbers, total, params)
    errors += distractor_errors(problem, allowed, required_values, required_names)
    errors += _example_errors(problem, kind, params)
    return errors


def range_errors(kind: str, numbers: list[int], params: dict) -> list[str]:
    """The numbers a skill may use (also applied to the worked example)."""
    errors: list[str] = []
    total = sum(numbers)
    a, b = numbers[0], numbers[1]
    if kind in ("facts", "doubles", "three", "make_ten"):
        if min(numbers) < 1:
            errors.append(f"addends {numbers} must be at least 1")
        if total > params["max_sum"]:
            errors.append(f"sum {total} is over {params['max_sum']}")
    if kind == "make_ten":
        if not 6 <= a <= 9 or not 1 <= b <= 9:
            errors.append(f"make-a-ten facts start from 6 to 9 and add a single digit, got {a} + {b}")
        if total < 11:
            errors.append(f"{a} + {b} does not cross ten")
    elif kind == "doubles":
        if abs(a - b) > 1:
            errors.append(f"{a} + {b} is neither a double nor a near double")
    elif kind == "three":
        if max(numbers) > 9:
            errors.append(f"addends {numbers} should be single digits")
    elif kind == "tens":
        if a % 10 or b % 10 or min(a, b) < 10:
            errors.append(f"{a} and {b} should both be tens (10, 20, ...)")
        if params.get("multiples_of_ten") is not True:
            errors.append("the tens skill should say multiples_of_ten")
        if total > params["max_sum"]:
            errors.append(f"sum {total} is over {params['max_sum']}")
    elif kind == "two_digit":
        if not 10 <= a <= 99 or not 1 <= b <= 99:
            errors.append(f"{a} + {b} should be a two-digit number plus a one- or two-digit number")
        ones = digits(a)[1] + digits(b)[1] if a <= 99 and b <= 99 else 0
        if params["regroup"]:
            if ones < 10:
                errors.append(f"{a} + {b} needs regrouping, but the ones make only {ones}")
            if total > params["max_sum"]:
                errors.append(f"sum {total} is over {params['max_sum']}")
        else:
            if ones > 9:
                errors.append(f"{a} + {b} should not regroup, but the ones make {ones}")
            if total > min(params["max_sum"], 99):
                errors.append(f"sum {total} regroups into a hundred or passes the limit")
    return errors


def _pictures(problem: dict, kind: str, numbers: list[int], total: int) -> list[str]:
    """The problem's picture and the rung 2 hint model."""
    errors: list[str] = []
    visual = problem["visual"]
    model = problem["hint_steps"][1]["visual"]
    a, b = numbers[0], numbers[1]
    if kind == "facts":
        if visual != {"type": "gem_piles", "piles": [loose(a), loose(b)]}:
            errors.append("the picture should be a pile of a loose gems and a pile of b")
        frames = max(1, -(-total // 10))
        if model != {"type": "ten_frame", "count": a, "second": b, "frames": frames}:
            errors.append(f"the hint model should be a ten-frame of {a} then {b} in another color")
    elif kind == "make_ten":
        if visual != {"type": "ten_frame", "count": a, "second": b, "frames": 2}:
            errors.append(f"the picture should be two ten-frames: {a} dots, then {b} in another color")
        if model.get("type") != "number_line" or model.get("jumps") != [{"from": a, "to": 10}, {"from": 10, "to": total}]:
            errors.append(f"the hint model should jump from {a} to 10, then to {total}")
        elif a not in model["markers"]:
            errors.append("the hint number line should mark where it starts")
    elif kind == "doubles":
        if visual != {"type": "gem_piles", "piles": [loose(a), loose(b)]}:
            errors.append("the picture should be a pile of a loose gems and a pile of b")
        if model != {"type": "pairs", "count": total, "show_pairs": True}:
            errors.append(f"the hint model should line up {total} gems in pairs")
    elif kind == "tens":
        if visual != {"type": "gem_piles", "piles": [{"hundreds": 0, "tens": a // 10, "ones": 0}, {"hundreds": 0, "tens": b // 10, "ones": 0}]}:
            errors.append("the picture should be two piles of ten-bars")
        jumps = [{"from": start, "to": start + 10} for start in range(a, total, 10)]
        if model.get("type") != "number_line" or model.get("jumps") != jumps:
            errors.append(f"the hint model should count on by tens from {a} to {total}")
    elif kind == "two_digit":
        addends = {"type": "gem_piles", "piles": [pile_for(a), pile_for(b)]}
        if problem["representation"] == "concrete":
            if visual != addends:
                errors.append(f"the picture should show {a} and {b} as tens and ones")
            together = {"hundreds": 0, "tens": digits(a)[0] + digits(b)[0], "ones": digits(a)[1] + digits(b)[1]}
            if model != {"type": "gem_piles", "piles": [together]}:
                errors.append("the hint model should put the tens together and the ones together")
        else:
            if visual:
                errors.append("an abstract problem has no picture")
            if model != addends:
                errors.append(f"the hint model should show {a} and {b} as tens and ones")
    elif kind == "three":
        c = numbers[2]
        if visual != {"type": "gem_piles", "piles": [loose(a), loose(b), loose(c)]}:
            errors.append("the picture should be three piles of loose gems")
        if model.get("type") != "number_line" or model.get("jumps") != [{"from": a, "to": a + b}, {"from": a + b, "to": total}]:
            errors.append(f"the hint model should jump from {a} by {b}, then by {c}")
    return errors


def _wrong_answers(kind: str, numbers: list[int], total: int, params: dict) -> tuple[dict[str, set[int]], set[int], set[str]]:
    """({misconception: the values it can give}, values that must be offered under some name,
    names that must be offered)."""
    a, b = numbers[0], numbers[1]
    if kind == "facts":
        # Counting on from a and saying "a" again as the first count lands one short.
        return {"counted_from_one": {total - 1}, "off_by_one": {total - 1, total + 1}}, {total - 1, total + 1}, {"counted_from_one"}
    if kind == "make_ten":
        # Made the ten, then kept only the ones left over.
        return {"forgot_regroup": {total - 10}, "off_by_one": {total - 1, total + 1}}, {total - 10, total - 1, total + 1}, {"forgot_regroup"}
    if kind == "doubles":
        two_off = {value for value in (total - 2, total + 2) if value >= 1}
        return {"off_by_one": {total - 1, total + 1}, "off_by_two": two_off}, {total - 1, total + 1}, {"off_by_two"}
    if kind == "tens":
        as_ones = a // 10 + b // 10  # 30 + 40 as 3 + 4
        return {"added_as_ones": {as_ones}, "decade_skip": {total - 10, total + 10}}, {as_ones, total - 10, total + 10}, {"added_as_ones"}
    if kind == "three":
        c = numbers[2]
        dropped = {a + b, b + c, a + c}
        return {"dropped_addend": dropped, "off_by_one": {total - 1, total + 1}}, dropped | {total - 1, total + 1}, {"dropped_addend", "off_by_one"}
    if params["regroup"]:
        return {"forgot_regroup": {total - 10}, "carried_twice": {total + 10}}, {total - 10, total + 10}, {"forgot_regroup", "carried_twice"}
    allowed: dict[str, set[int]] = {}
    crossed = crossed_places(a, b)
    if crossed is not None:
        allowed["added_tens_to_ones"] = {crossed}
    swap = swapped(total)
    if swap is not None:
        allowed["digit_swap"] = {swap}
    return allowed, set().union(*allowed.values()), set()


def distractor_errors(problem: dict, allowed: dict[str, set[int]], required_values: set[int], required_names: set[str]) -> list[str]:
    """Every offered wrong answer is a value its misconception really gives; nothing required is missing."""
    errors: list[str] = []
    offered = distractors_by_name(problem)
    for name, values in offered.items():
        for value in values:
            if name not in allowed:
                errors.append(f"unexpected misconception {name} (value {value})")
            elif value not in allowed[name]:
                errors.append(f"{name} value {value} should be one of {sorted(allowed[name])}")
    for name in sorted(required_names - set(offered)):
        errors.append(f"{name} is missing")
    every_value = {value for values in offered.values() for value in values}
    for value in sorted(required_values - every_value):
        givers = ", ".join(name for name, values in allowed.items() if value in values)
        errors.append(f"the wrong answer {value} ({givers}) is missing")
    return errors


def _example_errors(problem: dict, kind: str, params: dict) -> list[str]:
    """The worked example (rung 3) is a solved problem of the same kind, stated correctly."""
    example = problem["hint_steps"][2]["example"]
    names = ("a", "b", "c") if kind == "three" else ("a", "b")
    shown = example["prompt_params"]
    if set(shown) != set(names):
        return [f"the worked example's prompt params should be {list(names)}"]
    numbers = [shown[name] for name in names]
    total = sum(numbers)
    errors = [f"worked example: {error}" for error in range_errors(kind, numbers, params)]
    if example["prompt_line_id"] != problem["prompt_line_id"]:
        errors.append("the worked example asks a different kind of question")
    if example["answer"] != total:
        errors.append(f"the worked example's answer {example['answer']} is not {total}")
    line = example["answer_line_id"]
    said = example["answer_params"]
    if line != EXAMPLE_LINES.get(kind, DEFAULT_EXAMPLE_LINE):
        errors.append(f"the worked example states its answer with {line!r}")
    elif kind == "make_ten":
        ok = (said.get("a") == numbers[0] and said.get("ten") == 10 and said["a"] + said.get("fill", 0) == 10
              and said.get("fill", 0) + said.get("rest", 0) == numbers[1] and said["ten"] + said.get("rest", 0) == said.get("sum")
              and said.get("sum") == total and min(said.get("fill", 0), said.get("rest", 0)) >= 1)
        if not ok:
            errors.append(f"the make-a-ten steps {said} do not add up to {numbers[0]} + {numbers[1]} = {total}")
    elif said != dict(zip(names, numbers), sum=total):
        errors.append(f"the worked example says {said}, not {' + '.join(map(str, numbers))} = {total}")
    return errors
