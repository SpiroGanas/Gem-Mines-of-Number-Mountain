"""Independent re-derivation of the BaseGenerator problems (Zone 8 base.*: binary and bases 3, 4, 5, 8).

A number in a base is read with Python's own int(text, base) and written with a hand-written
repeated-division to_base below, neither shared with the GDScript. Each named mistake is rebuilt from
the digits. Which mistakes a skill may name comes from its own `misconceptions` list in the curriculum
(policy data, never used to compute an answer)."""
from __future__ import annotations

import json
from functools import lru_cache
from pathlib import Path

from .common import distractor_pairs, filtered, is_base_number

SKILLS_DIR = Path(__file__).resolve().parents[3] / "curriculum" / "skills"
MAX_PLACES = 8


@lru_cache(maxsize=None)
def skill_names(skill_id: str) -> frozenset[str]:
    for path in SKILLS_DIR.glob("z*.json"):
        for skill in json.loads(path.read_text(encoding="utf-8"))["skills"]:
            if skill["id"] == skill_id:
                return frozenset(skill.get("misconceptions", []))
    return frozenset()


def to_base(n: int, base: int) -> list[int]:
    """n's digits in `base`, most significant first, by repeated division ([0] for zero)."""
    if n == 0:
        return [0]
    digits: list[int] = []
    while n:
        n, remainder = divmod(n, base)
        digits.insert(0, remainder)
    return digits


def read(digits: list[int], base: int) -> int:
    return int("".join(str(d) for d in digits), base)


def strip(digits: list[int]) -> list[int]:
    """Leading zeros removed ([0] if nothing is left)."""
    kept = list(digits)
    while len(kept) > 1 and kept[0] == 0:
        kept.pop(0)
    return kept or [0]


def _expect(problem: dict, candidates: list[tuple[str, object]]) -> list[str]:
    wanted = filtered(problem["answer"], candidates, set(skill_names(problem["skill_id"])))
    got = distractor_pairs(problem)
    return [] if got == wanted else [f"the wrong answers should be {wanted}, got {got}"]


def _bases(params: dict) -> list[int]:
    return list(params["bases"]) if "bases" in params else [params.get("base", 2)]


def check(problem: dict) -> list[str]:
    mode = problem["params"].get("mode")
    checker = {"to_decimal": _to_decimal, "from_decimal": _from_decimal, "add": _add}.get(mode)
    if checker is None:
        return [f"unknown base mode {mode!r}"]
    return checker(problem)


def _to_decimal(problem: dict) -> list[str]:
    picture = problem["visual"]
    base = picture.get("base")
    digits = picture["rows"][0]
    errors = []
    if base not in _bases(problem["params"]):
        errors.append(f"base {base} is not one of the skill's bases")
    most = problem["params"].get("max_bits", problem["params"].get("max_digits"))
    if not (2 <= len(digits) <= most and digits[0] != 0 and all(0 <= d < base for d in digits)):
        errors.append(f"{digits} is not a {len(digits)}-digit base-{base} number of 2 to {most} digits")
        return errors
    value = read(digits, base)
    if problem["answer"] != value:
        errors.append(f"{''.join(map(str, digits))} in base {base} is {value}, not {problem['answer']}")
    if base == 2:
        style = "lamps" if problem["representation"] == "concrete" else "digits"
        line = "z8.binary.prompt_lamps" if style == "lamps" else "z8.binary.prompt_columns"
        params = {}
    else:
        style, line, params = "dials", "z8.base.prompt_read", {"b": base}
    if picture.get("style") != style or problem["prompt_line_id"] != line or problem["prompt_params"] != params or picture.get("places") != len(digits):
        errors.append(f"the picture should be {style} with the line {line}")
    base_two = sum(d * 2 ** place for place, d in enumerate(reversed(digits)))
    errors += _expect(problem, [
        ("read_as_decimal_digits", int("".join(map(str, digits)))),
        ("reversed_bits", read(digits[::-1], base)),
        ("dropped_leading_place", read(digits[1:], base)),
        ("used_base_two", base_two),
    ])
    q = problem["hint_steps"][2]["example"]
    if q["answer_params"]["n"] != q["answer"]:
        errors.append("the worked example's number is wrong")
    return errors


def _from_decimal(problem: dict) -> list[str]:
    n = problem["prompt_params"]["n"]
    answer = problem["answer"]
    errors = []
    if not is_base_number(answer):
        return [f"{answer!r} is not a canonical number in a base"]
    base = answer["base"]
    if base not in _bases(problem["params"]) or problem["prompt_params"].get("b", 2) != base:
        errors.append(f"base {base} is not the asked base")
    if not base <= n <= problem["params"]["max_value"]:
        errors.append(f"{n} should have at least two digits in base {base} and be at most the maximum")
    if answer["digits"] != to_base(n, base) or read(answer["digits"], base) != n:
        errors.append(f"{n} in base {base} is {to_base(n, base)}, not {answer['digits']}")
    places = min(len(to_base(problem["params"]["max_value"], base)), MAX_PLACES)
    if problem["meta"].get("base_pad") != {"base": base, "places": places}:
        errors.append("the lock and pad size come from the largest number the skill asks for")
    if problem["representation"] == "concrete":
        if problem["meta"].get("vault_lock") != {"base": base, "places": places}:
            errors.append("a concrete problem is answered on the vault lock")
    elif problem["visual"].get("rows") != [[0] * places]:
        errors.append("a pictorial problem shows the unlit places")
    digits = answer["digits"]
    candidates = [("reversed_bits", {"base": base, "digits": strip(digits[::-1])})]
    if 0 in digits:
        candidates.append(("greedy_skipped_place", {"base": base, "digits": [d for d in digits if d]}))
    candidates.append(("dropped_leading_place", {"base": base, "digits": strip(digits[1:])}))
    if base != 2 and len(to_base(n, 2)) <= places:
        candidates.append(("used_base_two", {"base": base, "digits": to_base(n, 2)}))
    errors += _expect(problem, candidates)
    q = problem["hint_steps"][2]["example"]["answer_params"]
    if read([int(c) for c in str(q["s"])], q.get("b", 2)) != q["n"]:
        errors.append("the worked example's written number is wrong")
    return errors


def _add(problem: dict) -> list[str]:
    a, b = problem["meta"]["sum"]["a"], problem["meta"]["sum"]["b"]
    errors = []
    largest = 2 ** problem["params"]["max_bits"] - 1
    if not (2 <= a <= largest and 1 <= b <= largest):
        errors.append(f"{a} and {b} are out of range")
    if a & b == 0:
        errors.append("every binary sum should have a carry")
    if problem["answer"] != {"base": 2, "digits": to_base(a + b, 2)}:
        errors.append(f"{a} + {b} in binary is {to_base(a + b, 2)}, not {problem['answer']}")
    places = problem["meta"]["base_pad"]["places"]
    if problem["visual"].get("rows") != [to_base(a, 2), to_base(b, 2)] or not problem["visual"].get("plus"):
        errors.append("the picture should show both numbers as a sum")
    if not len(to_base(a + b, 2)) <= places <= MAX_PLACES:
        errors.append("the pad is too short for the sum")
    top = [0] * (places - len(to_base(a, 2))) + to_base(a, 2)
    bottom = [0] * (places - len(to_base(b, 2))) + to_base(b, 2)
    columns = strip([x + y for x, y in zip(top, bottom)])
    errors += _expect(problem, [
        ("forgot_carry", {"base": 2, "digits": to_base(a ^ b, 2)}),
        ("carried_as_decimal", {"base": 2, "digits": columns}),
    ])
    q = problem["hint_steps"][2]["example"]["answer_params"]
    if q["n"] != q["a"] + q["b"] or int(str(q["s"]), 2) != q["n"]:
        errors.append("the worked example's sum is wrong")
    return errors
